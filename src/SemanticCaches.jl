module SemanticCaches

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
    EMBEDDER = EmbedderModel(:tiny_embed)
end

end
