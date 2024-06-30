# # Example how to use caching with PromptingTools.jl

# ## Setup
using PromptingTools
using SemanticCaches
using HTTP

# ## Create Cache Layer
## Define the new caching mechanism as a layer for HTTP
## See documentation [here](https://juliaweb.github.io/HTTP.jl/stable/client/#Quick-Examples)
module MyCache

using HTTP, JSON3
using SemanticCaches

const SEM_CACHE = SemanticCache()
const HASH_CACHE = HashCache()

function cache_layer(handler)
    return function (req; cache_key::Union{AbstractString, Nothing} = nothing, kw...)
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
            item = active_cache("key1", input; verbose = 2) # change verbosity to 0 to disable detailed logs
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

# ## Profit
# Let's call the API
@time msg = aigenerate("What is the meaning of life?"; http_kwargs = (; cache_key = "key1"))

# The first call will be slow as usual, but any subsequent call should be pretty quick - try it a few times!

# You can also use it for embeddings, eg, 
@time msg = aiembed("how is it going?"; http_kwargs = (; cache_key = "key2")) # 0.7s
@time msg = aiembed("how is it going?"; http_kwargs = (; cache_key = "key2")) # 0.02s

# Even with a tiny difference (no question mark), it still picks the right cache
@time msg = aiembed("how is it going"; http_kwargs = (; cache_key = "key2")) # 0.02s
