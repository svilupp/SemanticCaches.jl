function similarity(cache::AbstractCache, indices::Vector{Int}, embedding::Any)
    return lock(cache.items_lock) do
        similarity(cache, cache.items, indices, embedding)
    end
end

"""
    similarity(cache::SemanticCache, items::Vector{CachedItem},
        indices::Vector{Int}, embedding::Vector{Float32})

Finds the most similar item in the cache to the given embedding. Search is done via cosine similarity (dot product).

# Arguments

- `cache::SemanticCache`: The cache to search in.
- `items::Vector{CachedItem}`: The items to search in.
- `indices::Vector{Int}`: The indices of the items to search in.
- `embedding::Vector{Float32}`: The embedding to search for.

# Returns

A tuple `(max_sim, max_idx)` where
- `max_sim`: The maximum similarity.
- `max_idx`: The index of the most similar item.

# Notes

- The return item is not guaranteed to be very similar, you need to check if the similarity is high enough.
- We assume that embeddings are normalized to have L2 norm 1, so Cosine similarity is the same as dot product.

"""
function similarity(cache::SemanticCache, items::Vector{CachedItem},
        indices::Vector{Int}, embedding::Vector{Float32})
    isempty(indices) && return Float32[]
    len = length(items)
    @assert len>=maximum(indices) "all `indices` must be less than or equal to the length of `items`"
    @assert 0<=minimum(indices) "all `indices` must be greater than or equal to 0"
    ## Find the highest and check if it's above the threshold
    max_sim = -1
    max_idx = 0
    @inbounds for i in indices
        sim = dot(items[i].embedding, embedding)
        if sim > max_sim
            max_sim = sim
            max_idx = i
        end
    end
    return (max_sim, max_idx)
end

"""
    (cache::SemanticCache)(
        key::String, fuzzy_input::String; verbose::Integer = 0, min_similarity::Real = 0.95)

Finds the item that EXACTLY matches the provided cache `key` and is the most similar given its embedding. Similarity must be at least `min_similarity`. 
Search is done via cosine similarity (dot product).

# Arguments

- `key::String`: The key to match exactly.
- `fuzzy_input::String`: The input to embed and compare to the cache.
- `verbose::Integer = 0`: The verbosity level.
- `min_similarity::Real = 0.95`: The minimum similarity.

# Returns
A `CachedItem`:
- If the similarity is above `min_similarity`, the `output` field is set to the cached output.
- If the similarity is below `min_similarity`, the `output` field is set to `nothing`.

You can validate if an item has been found by checking if `output` is not `nothing` or simply `isvalid(item)`.

# Example
```julia
cache = SemanticCache()
item = cache("key1", "fuzzy_input"; min_similarity=0.95)

## add it to cache if new
if !isvalid(item)
    # calculate the expensive output
    output = expensive_calculation()
    item.output = output
    ## add it to cache
    push!(cache, item)
end

# If you ask again, it will be faster because it's in the cache
item = cache("key1", "fuzzy_input"; min_similarity=0.95)
```
"""
function (cache::SemanticCache)(
        key::String, fuzzy_input::String; verbose::Integer = 0, min_similarity::Real = 0.95)
    indices = get(cache, key, Int[])
    (verbose >= 2) && @info "Candidates for $(key): $(length(indices)) items"
    ## Embed and Normalize
    emb_result = FlashRank.embed(EMBEDDER, fuzzy_input; split_instead_trunc = true)
    embedding = if size(emb_result.embeddings, 2) > 1
        mean(emb_result.embeddings; dims = 2) |> vec |> normalize
    else
        emb_result.embeddings |> vec |> normalize
    end
    (verbose >= 2) && @info "Embedding computed in $(round(emb_result.elapsed, digits=3))s"
    hash_ = hash(fuzzy_input)
    isempty(indices) && return CachedItem(; input_hash = hash_, embedding, key)
    ## Calculate similarity
    max_sim, max_idx = similarity(cache, indices, embedding)
    ## Find the highest and check if it's above the threshold
    output = max_sim >= min_similarity ? cache.items[max_idx].output : nothing
    (verbose >= 1) &&
        @info (isnothing(output) ?
               "No cache match found (max. sim: $(round(max_sim, digits=3)))" :
               "Match found (max. sim: $(round(max_sim, digits=3)))")
    ##
    return CachedItem(; input_hash = hash_, embedding, key, output)
end

"""
    similarity(cache::HashCache, items::Vector{CachedItem},
        indices::Vector{Int}, hash::UInt64)

Finds the items with the exact hash as `hash`.
"""
function similarity(cache::HashCache, items::Vector{CachedItem},
        indices::Vector{Int}, hash::UInt64)
    isempty(indices) && return Float32[]
    len = length(items)
    @assert len>=maximum(indices) "all `indices` must be less than or equal to the length of `items`"
    @assert 0<=minimum(indices) "all `indices` must be greater than or equal to 0"
    ## Find the highest and check if it's above the threshold
    max_sim = -1
    max_idx = 0
    @inbounds for i in indices
        sim = items[i].input_hash == hash
        if sim
            ## find the first match and stop
            max_sim = sim
            max_idx = i
            break
        end
    end
    return (max_sim, max_idx)
end

"""
    (cache::HashCache)(key::String, fuzzy_input::String; verbose::Integer = 0, min_similarity::Real = 1.0)

Finds the item that EXACTLY matches the provided cache `key` and EXACTLY matches the hash of `fuzzy_input`.

# Arguments

- `key::String`: The key to match exactly.
- `fuzzy_input::String`: The input to compare the hash of.
- `verbose::Integer = 0`: The verbosity level.
- `min_similarity::Real = 1.0`: The minimum similarity (we expect exact match defined as 1.0).

# Returns
A `CachedItem`:
- If an exact match is found, the `output` field is set to the cached output.
- If no exact match is found, the `output` field is set to `nothing`.

You can validate if an item has been found by checking if `output` is not `nothing` or simply `isvalid(item)`.

# Example
```julia
cache = HashCache()
item = cache("key1", "fuzzy_input")

## add it to cache if new
if !isvalid(item)
    # calculate the expensive output
    output = expensive_calculation()
    item.output = output
    ## add it to cache
    push!(cache, item)
end

# If you ask again, it will be faster because it's in the cache
item = cache("key1", "fuzzy_input")
```
"""
function (cache::HashCache)(
        key::String, fuzzy_input::String; verbose::Integer = 0, min_similarity::Real = 1.0)
    indices = get(cache, key, Int[])
    (verbose >= 2) && @info "Candidates for $(key): $(length(indices)) items"
    hash_ = hash(fuzzy_input) # fake embedding
    isempty(indices) && return CachedItem(; input_hash = hash_, key)
    ## Calculate similarity
    max_sim, max_idx = similarity(cache, indices, hash_)
    ## Find the highest and check if it's above the threshold
    output = max_sim >= min_similarity ? cache.items[max_idx].output : nothing
    (verbose >= 1) &&
        @info (isnothing(output) ? "No cache match found" : "Match found")
    ##
    return CachedItem(; input_hash = hash_, key, output)
end
