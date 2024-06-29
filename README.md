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
using SemanticCaches

sem_cache = SemanticCache()
item = sem_cache("key1", "say hi!"; verbose = 1)
if !isvalid(item)
    @info "cache miss!"
    item.output = "expensive result X"
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
        if req.method == "POST" && cache_key !== nothing
            body = JSON3.read(copy(req.body))
            input = join([m["content"] for m in body["messages"]], " ")
            @info "Check if we can cache this request ($(length(input)) chars)"
            active_cache = length(input) > 5000 ? HASH_CACHE : SEM_CACHE
            item = active_cache("key1", input; verbose=1)
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



## Roadmap

[ ] Time-based cache validity 