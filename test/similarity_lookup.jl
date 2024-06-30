
@testset "similarity_lookup" begin
    # Test 1: Basic similarity lookup with SemanticCache
    cache = SemanticCache()
    item = cache("key1", "fuzzy_input"; min_similarity = 0.95)
    @test !isvalid(item) # Expecting a cache miss since the cache is empty

    # Test 2: Adding and retrieving an item from SemanticCache
    cache = SemanticCache()
    item = cache("key1", "fuzzy_input"; min_similarity = 0.95)
    if !isvalid(item)
        item.output = "expensive result"
        push!(cache, item)
    end
    item = cache("key1", "fuzzy_input"; min_similarity = 0.95)
    @test isvalid(item) && item.output == "expensive result" # Expecting a cache hit

    # Test 3: Similarity threshold in SemanticCache
    cache = SemanticCache()
    item = cache("key1", "this is my input"; min_similarity = 0.95)
    if !isvalid(item)
        item.output = "expensive result"
        push!(cache, item)
    end
    item = cache("key1", "very different text"; min_similarity = 0.95)
    @test !isvalid(item) # Expecting a cache miss due to low similarity

    # Test 4: Basic similarity lookup with HashCache
    cache = HashCache()
    item = cache("key1", "fuzzy_input")
    @test !isvalid(item) # Expecting a cache miss since the cache is empty

    # Test 5: Adding and retrieving an item from HashCache
    cache = HashCache()
    item = cache("key1", "fuzzy_input")
    if !isvalid(item)
        item.output = "expensive result"
        push!(cache, item)
    end
    item = cache("key1", "fuzzy_input")
    @test isvalid(item) && item.output == "expensive result" # Expecting a cache hit

    # Test 6: Exact match requirement in HashCache
    cache = HashCache()
    item = cache("key1", "fuzzy_input")
    if !isvalid(item)
        item.output = "expensive result"
        push!(cache, item)
    end
    item = cache("key1", "different_input")
    @test !isvalid(item) # Expecting a cache miss due to different input hash
end
