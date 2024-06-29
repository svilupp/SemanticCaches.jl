module SemanticCaches

using HTTP
using LinearAlgebra
using Dates
using Statistics: mean
using FlashRank
using FlashRank: EmbedderModel

global EMBEDDER::EmbedderModel = EmbedderModel(:tiny_embed)

export SemanticCache, CachedItem, HashCache
include("types.jl")

include("similarity_lookup.jl")

function __init__()
    ## Initialize the embedding model
    global EMBEDDER
    EMBEDDER = EmbedderModel(:tiny_embed)
end

end
