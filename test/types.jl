
@testset "CachedItem,SemanticCache" begin
    # Test 1: Create a CachedItem and check its fields
    item = CachedItem(; key = "key1", input_hash = hash("input1"))
    @test item.key == "key1" # Check key field
    @test item.input_hash == hash("input1") # Check input field
    @test isnothing(item.output) # Check output field is nothing initially
    @test item.created_at <= now() # Check created_at field is a DateTime
    @test isvalid(item) == false

    # Test 2: Create a SemanticCache and check its initial state
    cache = SemanticCache()
    @test length(cache.items) == 0 # Check items vector is empty
    @test length(cache.lookup) == 0 # Check lookup dictionary is empty

    # Test 3: Add a CachedItem to SemanticCache and check its state
    push!(cache, item)
    @test length(cache.items) == 1 # Check items vector has one item
    @test haskey(cache.lookup, "key1") # Check lookup dictionary has the key
    @test cache.lookup["key1"] == [1] # Check lookup dictionary points to the correct index

    # Test 4: Retrieve an item from SemanticCache using getindex
    idxs = cache["key1"]
    @test idxs == [1] # Check the retrieved index is correct

    # Test 5: Retrieve an item from SemanticCache using get
    idxs = get(cache, "key1")
    @test idxs == [1] # Check the retrieved index is correct

    # Test 6: Add another CachedItem with the same key and check the state
    item2 = CachedItem(; key = "key1", input_hash = hash("input2"))
    push!(cache, item2)
    @test length(cache.items) == 2 # Check items vector has two items
    @test cache.lookup["key1"] == [1, 2] # Check lookup dictionary points to both indices

    # Test 7: Add a CachedItem with a different key and check the state
    item3 = CachedItem(; key = "key2", input_hash = hash("input3"))
    push!(cache, item3)
    @test length(cache.items) == 3 # Check items vector has three items
    @test haskey(cache.lookup, "key2") # Check lookup dictionary has the new key
    @test cache.lookup["key2"] == [3] # Check lookup dictionary points to the correct index

    # Test 8: Retrieve an item with a non-existent key using getindex
    @test_throws KeyError cache["non_existent_key"]

    # Test 9: Retrieve an item with a non-existent key using get
    idxs = get(cache, "non_existent_key")
    @test idxs == Int64[] # Check the retrieved index is an empty array

    # Test 10: Ensure thread safety by adding items concurrently
    Threads.@threads for i in 1:100
        item = CachedItem(; key = "key$i", input_hash = hash("input$i"))
        push!(cache, item)
    end
    @test length(cache.items) == 103 # Check items vector has 103 items
    for i in 1:100
        @test haskey(cache.lookup, "key$i") # Check lookup dictionary has the new keys
    end

    ## Show methods
    # Test 1: Show an empty SemanticCache
    sem_cache = SemanticCache()
    io = IOBuffer()
    show(io, sem_cache)
    @test String(take!(io)) == "SemanticCache with 0 items" # Check the output for an empty SemanticCache

    # Test 2: Show a SemanticCache with one item
    item = CachedItem(; key = "key1", input_hash = hash("input1"))
    push!(sem_cache, item)
    io = IOBuffer()
    show(io, sem_cache)
    @test String(take!(io)) == "SemanticCache with 1 items" # Check the output for a SemanticCache with one item

    # Test 3: Show a SemanticCache with multiple items
    item2 = CachedItem(; key = "key2", input_hash = hash("input2"))
    push!(sem_cache, item2)
    io = IOBuffer()
    show(io, sem_cache)
    @test String(take!(io)) == "SemanticCache with 2 items" # Check the output for a SemanticCache with multiple items

    # Test 4: CachedItem
    io = IOBuffer()
    show(io, item)
    @test String(take!(io)) ==
          "CachedItem with key: key1 and output: <no output>"
    # with output
    item.output = "output1"
    show(io, item)
    @test String(take!(io)) ==
          "CachedItem with key: key1 and output: <has output>"
end

@testset "HashCache" begin
    # Test 1: Create a HashCache and check its initial state
    hash_cache = HashCache()
    @test length(hash_cache.items) == 0 # Check items vector is empty
    @test length(hash_cache.lookup) == 0 # Check lookup dictionary is empty

    # Test 2: Add a CachedItem to HashCache and check its state
    item = CachedItem(; key = "key1", input_hash = hash("input1"))
    push!(hash_cache, item)
    @test length(hash_cache.items) == 1 # Check items vector has one item
    @test haskey(hash_cache.lookup, "key1") # Check lookup dictionary has the key
    @test hash_cache.lookup["key1"] == [1] # Check lookup dictionary points to the correct index

    # Test 3: Retrieve an item from HashCache using getindex
    idxs = hash_cache["key1"]
    @test idxs == [1] # Check the retrieved index is correct

    # Test 4: Retrieve an item from HashCache using get
    idxs = get(hash_cache, "key1")
    @test idxs == [1] # Check the retrieved index is correct

    # Test 5: Add another CachedItem with the same key and check the state
    item2 = CachedItem(; key = "key1", input_hash = hash("input2"))
    push!(hash_cache, item2)
    @test length(hash_cache.items) == 2 # Check items vector has two items
    @test hash_cache.lookup["key1"] == [1, 2] # Check lookup dictionary points to both indices

    # Test 6: Add a CachedItem with a different key and check the state
    item3 = CachedItem(; key = "key2", input_hash = hash("input3"))
    push!(hash_cache, item3)
    @test length(hash_cache.items) == 3 # Check items vector has three items
    @test haskey(hash_cache.lookup, "key2") # Check lookup dictionary has the new key
    @test hash_cache.lookup["key2"] == [3] # Check lookup dictionary points to the correct index

    # Test 7: Retrieve an item with a non-existent key using getindex
    @test_throws KeyError hash_cache["non_existent_key"]

    # Test 8: Retrieve an item with a non-existent key using get
    idxs = get(hash_cache, "non_existent_key")
    @test idxs == Int64[] # Check the retrieved index is an empty array

    # Test 9: Ensure thread safety by adding items concurrently
    Threads.@threads for i in 1:100
        item = CachedItem(; key = "key$i", input_hash = hash("input$i"))
        push!(hash_cache, item)
    end
    @test length(hash_cache.items) == 103 # Check items vector has 103 items
    for i in 1:100
        @test haskey(hash_cache.lookup, "key$i") # Check lookup dictionary has the new keys
    end

    ## Show methods
    # Test 4: Show an empty HashCache
    hash_cache = HashCache()
    io = IOBuffer()
    show(io, hash_cache)
    @test String(take!(io)) == "HashCache with 0 items" # Check the output for an empty HashCache

    # Test 5: Show a HashCache with one item
    item3 = CachedItem(; key = "key3", input_hash = hash("input3"))
    push!(hash_cache, item3)
    io = IOBuffer()
    show(io, hash_cache)
    @test String(take!(io)) == "HashCache with 1 items" # Check the output for a HashCache with one item

    # Test 6: Show a HashCache with multiple items
    item4 = CachedItem(; key = "key4", input_hash = hash("input4"))
    push!(hash_cache, item4)
    io = IOBuffer()
    show(io, hash_cache)
    @test String(take!(io)) == "HashCache with 2 items" # Check the output for a HashCache with multiple items
end