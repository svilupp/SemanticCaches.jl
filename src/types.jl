@kwdef mutable struct CachedItem
    key::String
    input_hash::UInt64
    embedding::Vector{Float32} = Float32[]
    output::Any = nothing
    created_at::DateTime = now()
end
Base.isvalid(item::CachedItem) = !isnothing(item.output)

abstract type AbstractCache end

"""
    SemanticCache

A cache that stores embeddings and uses semantic search to find the most relevant items.

Any incoming request must match `key` exactly (in `lookup`), otherwise it's not accepted.
`key` represents what user finds meaningful to be strictly matching (eg, model name, temperature, etc).


# Fields
- `items`: A vector of cached items (type `CachedItem`)
- `lookup`: A dictionary that maps keys to the indices of the items that have that key.
- `items_lock`: A lock for the items vector.
- `lookup_lock`: A lock for the lookup dictionary.
"""
@kwdef mutable struct SemanticCache <: AbstractCache
    items::Vector{CachedItem} = CachedItem[]
    lookup::Dict{String, Vector{Int}} = Dict{String, Vector{Int}}()
    items_lock::ReentrantLock = ReentrantLock()
    lookup_lock::ReentrantLock = ReentrantLock()
end

"""
    HashCache

A cache that uses string hashes to find the exactly matching items. Useful for long input strings, which cannot be embedded quickly.

Any incoming request must match `key` exactly (in `lookup`), otherwise it's not accepted.
`key` represents what user finds meaningful to be strictly matching (eg, model name, temperature, etc).

# Fields
- `items`: A vector of cached items (type `CachedItem`)
- `lookup`: A dictionary that maps keys to the indices of the items that have that key.
- `items_lock`: A lock for the items vector.
- `lookup_lock`: A lock for the lookup dictionary.
"""
@kwdef mutable struct HashCache <: AbstractCache
    items::Vector{CachedItem} = CachedItem[]
    lookup::Dict{String, Vector{Int}} = Dict{String, Vector{Int}}()
    items_lock::ReentrantLock = ReentrantLock()
    lookup_lock::ReentrantLock = ReentrantLock()
end

## Show methods
function Base.show(io::IO, cache::AbstractCache)
    print(io, "$(nameof(typeof(cache))) with $(length(cache.items)) items")
end
function Base.show(io::IO, item::CachedItem)
    has_output = !isnothing(item.output) ? "<has output>" : "<no output>"
    print(io, "CachedItem with key: $(item.key) and output: $has_output")
end

function Base.push!(cache::AbstractCache, item::CachedItem)
    ## Lock the system to not get corrupted
    lock(cache.lookup_lock)
    lock(cache.items_lock)
    ## Add to items vector
    push!(cache.items, item)
    idx = length(cache.items)
    ## Add to lookup
    if haskey(cache.lookup, item.key)
        push!(cache.lookup[item.key], idx)
    else
        cache.lookup[item.key] = [idx]
    end
    ## Unlock
    unlock(cache.items_lock)
    unlock(cache.lookup_lock)
    return cache
end

function Base.getindex(cache::AbstractCache, key::String)
    return lock(cache.lookup_lock) do
        getindex(cache.lookup, key)
    end
end
function Base.get(cache::AbstractCache, key::String, default = Int[])
    return lock(cache.lookup_lock) do
        get(cache.lookup, key, default)
    end
end
