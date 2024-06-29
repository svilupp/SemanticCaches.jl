using SemanticCaches
using Test
using Aqua

@testset "SemanticCaches.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(SemanticCaches)
    end
    @testset "SemanticCache" begin
        include("types.jl")
        include("similarity_lookup.jl")
    end
end
