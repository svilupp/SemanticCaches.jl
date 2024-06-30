using SemanticCaches
using Dates
using Test
using Aqua

@testset "SemanticCaches.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        # disable ambiguities due to upstream packages
        Aqua.test_all(SemanticCaches; ambiguities = false)
    end
    @testset "SemanticCache" begin
        include("types.jl")
        include("similarity_lookup.jl")
    end
end
