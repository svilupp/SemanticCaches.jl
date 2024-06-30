# SemanticCaches 
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://svilupp.github.io/SemanticCaches.jl/dev/) 
[![Build Status](https://github.com/svilupp/SemanticCaches.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/svilupp/SemanticCaches.jl/actions/workflows/CI.yml?query=branch%3Amain) 
[![Coverage](https://codecov.io/gh/svilupp/SemanticCaches.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/svilupp/SemanticCaches.jl) 
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

SemanticCaches.jl is a very hacky implementation of a semantic cache for AI applications to save time and money with repeated requests.
It's not particularly fast, because we're trying to prevent API calls that can take even 20 seconds.

Note that we're using a tiny BERT model with a maximum chunk size of 512 tokens to provide fast local embeddings running on a CPU.
For longer sentences, we split them in several chunks and consider their average embedding, but use it carefully! The latency can sky rocket and become worse than simply calling the original API.

## Installation
To install SemanticCaches.jl, simply add this repository (package is not yet registered).

```julia
using Pkg
Pkg.add("https://github.com/svilupp/SemanticCaches.jl")
```

## Quick Start Guide

```julia
ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
using SemanticCaches

sem_cache = SemanticCache()
# First argument: the key must always match exactly, eg, model, temperature, etc
# Second argument: the input text to be compared with the cache, can be fuzzy matched
item = sem_cache("key1", "say hi!"; verbose = 1) # notice the verbose flag it can 0,1,2 for different level of detail
if !isvalid(item)
    @info "cache miss!"
    item.output = "expensive result X"
    # Save the result to the cache for future reference
    push!(sem_cache, item)
end

# If practice, long texts may take too long to embed even with our tiny model
# so let's not compare anything above 2000 tokens =~ 5000 characters (threshold of c. 100ms)

hash_cache = HashCache()
input = "say hi"
input = "say hi "^1000

active_cache = length(input) > 5000 ? hash_cache : sem_cache
item = active_cache("key1", input; verbose = 1)

if !isvalid(item)
    @info "cache miss!"
    item.output = "expensive result X"
    push!(active_cache, item)
end
```

## How it Works

The primary objective of building this package was to cache expensive API calls to GenAI models.

The system offers exact matching (faster, `HashCache`) and semantic similarity lookup (slower, `SemanticCache`) of STRING inputs.
In addition, all requests are first compared on a “cache key”, which presents a key that must always match exactly for requests to be considered interchangeable (eg, same model, same provider, same temperature, etc). 
You need to choose the appropriate cache key and input depending on your use case. This default choice for the cache key should be the model name.

What happens when you call the cache (provide `cache_key` and `string_input`)?
- All cached outputs are stored in a vector `cache.items`.
- When we receive a request, the `cache_key` is looked up to find indices of the corresponding items in `items`. If `cache_key` is not found, we return `CachedItem` with an empty `output` field (ie, `isvalid(item) == false`).
- We embed the `string_input` using a tiny BERT model and normalize the embeddings (to make it easier to compare the cosine distance later).
- We then compare the cosine distance with the embeddings of the cached items.
- If the cosine distance is higher than `min_similarity` threshold, we return the cached item (The output can be found in the field `item.output`).

If we haven't found any cached item, we return `CachedItem` with an empty `output` field (ie, `isvalid(item) == false`).
Once you calculate the response and save it in `item.output`, you can push the item to the cache by calling `push!(cache, item)`.

## Suitable Use Cases

- This package is great if you know you will have a smaller volume of requests (eg, <10k per session or machine).
- It’s ideal to reduce the costs of running your evals, because even when you change your RAG pipeline configuration many of the calls will be repeated and can take advantage of caching.
- Lastly, this package can be really useful for demos and small user applications, where you can know some of the system inputs upfront, so you can cache them and show incredible response times!
- This package is NOT suitable for production systems with hundreds of thousands of requests and remember that this is a very basic cache that you need to manually invalidate over time!

## Advanced Usage

### Caching HTTP Requests

Based on your knowledge of the API calls made, you need determine the: 1) cache key (separate store of cached items, eg, different models or temperatures) and 2) how to unpack the HTTP request into a string (eg, unwrap and join the formatted message contents for OpenAI API).

Here's a brief outline of how you can use SemanticCaches.jl with [PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl).

```julia
using PromptingTools
using SemanticCaches
using HTTP

## Define the new caching mechanism as a layer for HTTP
## See documentation [here](https://juliaweb.github.io/HTTP.jl/stable/client/#Quick-Examples)
module MyCache

using HTTP, JSON3
using SemanticCaches

const SEM_CACHE = SemanticCache()
const HASH_CACHE = HashCache()

function cache_layer(handler)
    return function (req; cache_key::Union{AbstractString,Nothing}=nothing, kw...)
        # only apply the cache layer if the user passed `cache_key`
        # we could also use the contents of the payload, eg, `cache_key = get(body, "model", "unknown")`
        if req.method == "POST" && cache_key !== nothing
            body = JSON3.read(copy(req.body))
            if occursin("v1/chat/completions", req.target)
                ## We're in chat completion endpoint
                input = join([m["content"] for m in body["messages"]], " ")
            elseif occursin("v1/embeddings", req.target)
                ## We're in embedding endpoint
                input = body["input"]
            else
                ## Skip, unknown API
                return handler(req; kw...)
            end
            ## Check the cache
            @info "Check if we can cache this request ($(length(input)) chars)"
            active_cache = length(input) > 5000 ? HASH_CACHE : SEM_CACHE
            item = active_cache("key1", input; verbose=2) # change verbosity to 0 to disable detailed logs
            if !isvalid(item)
                @info "Cache miss! Pinging the API"
                # pass the request along to the next layer by calling `cache_layer` arg `handler`
                resp = handler(req; kw...)
                item.output = resp
                # Let's remember it for the next time
                push!(active_cache, item)
            end
            ## Return the calculated or cached result
            return item.output
        end
        # pass the request along to the next layer by calling `cache_layer` arg `handler`
        # also pass along the trailing keyword args `kw...`
        return handler(req; kw...)
    end
end

# Create a new client with the auth layer added
HTTP.@client [cache_layer]

end # module


# Let's push the layer globally in all HTTP.jl requests
HTTP.pushlayer!(MyCache.cache_layer)
# HTTP.poplayer!() # to remove it later

# Let's call the API
@time msg = aigenerate("What is the meaning of life?"; http_kwargs=(; cache_key="key1"))

# The first call will be slow as usual, but any subsequent call should be pretty quick - try it a few times!
```

You can also use it for embeddings, eg, 
```julia
@time msg = aiembed("how is it going?"; http_kwargs=(; cache_key="key2")) # 0.7s
@time msg = aiembed("how is it going?"; http_kwargs=(; cache_key="key2")) # 0.02s

# Even with a tiny difference (no question mark), it still picks the right cache
@time msg = aiembed("how is it going"; http_kwargs=(; cache_key="key2")) # 0.02s
```

You can remove the cache layer by calling `HTTP.poplayer!()` (and add it again if you made some changes).

You can probe the cache by calling `MyCache.SEM_CACHE` (eg, `MyCache.SEM_CACHE.items[1]`).

## Frequently Asked Questions

**How is the performance?**

The majority of time will be spent in 1) tiny embeddings (for large texts, eg, thousands of tokens) and in calculating cosine similarity (for large caches, eg, over 10k items).

For reference, embedding smaller texts like questions to embed takes only a few milliseconds. Embedding 2000 tokens can take anywhere from 50-100ms.

When it comes to the caching system, there are many locks to avoid faults, but the overhead is still negligible - I ran experiments with 100k sequential insertions and the time per item was only a few milliseconds (dominated by the cosine similarity). If your bottleneck is in the cosine similarity calculation (c. 4ms for 100k items), consider moving vectors into a matrix for continuous memory and/or use Boolean embeddings with Hamming distance (XOR operator, c. order of magnitude speed up).

All in all, the system is faster than necessary for normal workloads with thousands of cached items. You’re more likely to have GC and memory problems if your payloads are big (consider swapping to disk) than to face compute bounds. Remember that the motivation is to prevent API calls that take anywhere between 1-20 seconds!

**How to measure the time it takes to do X?**

Have a look at the example snippets below - time whichever part of it you’re interested in.
```julia

sem_cache = SemanticCache()
# First argument: the key must always match exactly, eg, model, temperature, etc
# Second argument: the input text to be compared with the cache, can be fuzzy matched
item = sem_cache("key1", "say hi!"; verbose = 1) # notice the verbose flag it can 0,1,2 for different level of detail
if !isvalid(item)
    @info "cache miss!"
    item.output = "expensive result X"
    # Save the result to the cache for future reference
    push!(sem_cache, item)
end
```

Embedding only (to tune the `min_similarity` threshold or to time the embedding)
```julia
using SemanticCaches.FlashRank: embed
using SemanticCaches: EMBEDDER

@time res = embed(EMBEDDER, "say hi")
#   0.000903 seconds (104 allocations: 19.273 KiB)
# see res.elapsed or res.embeddings

# long inputs (split into several chunks and then combining the embeddings)
@time embed(EMBEDDER, "say hi "^1000)
#   0.032148 seconds (8.11 k allocations: 662.656 KiB)
```

**How to set the `min_similarity` threshold?**

You can set the `min_similarity` threshold by adding the kwarg `active_cache("key1", input; verbose=2, min_similarity=0.95)`.

The default is 0.95, which is a very high threshold. For practical purposes, I'd recommend ~0.9. If you're expecting some typos, you can go even a bit lower (eg, 0.85).

> [!WARNING] 
> Be careful with similarity thresholds. It's hard to embed super short sequences well! You might want to adjust the threshold depending on the length of the input.
> Always test them with your inputs!!

If you want to calculate the cosine similarity, remember to `normalize` the embeddings first or divide the dot product by the norms.
```julia
using SemanticCaches.LinearAlgebra: normalize, norm, dot
cosine_similarity = dot(r1.embeddings, r2.embeddings) / (norm(r1.embeddings) * norm(r2.embeddings))
# remember that 1 is the best similarity, -1 is the exact opposite
```

You can compare different inputs to determine the best threshold for your use cases
```julia
emb1 = embed(EMBEDDER, "How is it going?") |> x -> vec(x.embeddings) |> normalize
emb2 = embed(EMBEDDER, "How is it goin'?") |> x -> vec(x.embeddings) |> normalize
dot(emb1, emb2) # 0.944

emb1 = embed(EMBEDDER, "How is it going?") |> x -> vec(x.embeddings) |> normalize
emb2 = embed(EMBEDDER, "How is it goin'") |> x -> vec(x.embeddings) |> normalize
dot(emb1, emb2) # 0.920
```

**How to debug it?**

Enable verbose logging by adding the kwarg `verbose = 2`, eg, `item = active_cache("key1", input; verbose=2)`.

## Roadmap

[ ] Time-based cache validity
[ ] Speed up the embedding process / consider pre-processing the inputs
[ ] Native integration with PromptingTools and the API schemas