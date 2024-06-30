module SemanticCaches

## Cowboy mode to solve CI failures in auto-merge
## Always set download true if not set otherwise
get!(ENV, "DATADEPS_ALWAYS_ACCEPT", "true")

using HTTP
using LinearAlgebra
using Dates
using Statistics: mean
using FlashRank
using FlashRank: EmbedderModel

global EMBEDDER::Union{Nothing,EmbedderModel} = nothing

export SemanticCache, CachedItem, HashCache
include("types.jl")

include("similarity_lookup.jl")

function __init__()
    ## Initialize the embedding model
    global EMBEDDER
    ## If we are in the CI, auto-download
    if haskey(ENV,"CI")
        ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
    end
    EMBEDDER = try
        EmbedderModel(:tiny_embed)
    catch e
        # Probably a CI issue!
        @warn "Error in DataDeps: $e"
    end
end

end
