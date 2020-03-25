@testset "Testing Record API" begin
    # Test some basic `mapleaves` functionality
    mapleaves = CounterTools.mapleaves
    aggregate = CounterTools.aggregate
    Record = CounterTools.Record

    x = 1
    f = x -> 2x
    @test mapleaves(f, 1) == 2
    @test mapleaves(f, (1,2,3)) == (2, 4, 6)
    @test mapleaves(f, ((1, 2), (3, 4))) == ((2, 4), (6, 8))
    @test mapleaves(f, ([1, 2], [3, 4])) == ([2, 4], [6, 8])

    # Test `aggregate` of non-record types
    @test aggregate(1) == 1
    @test aggregate((1,2,3)) == (1,2,3)
    @test aggregate([1,2,3]) == 6
    @test aggregate(((1,2), (3,4), (5,6))) == (9,12)
    @test aggregate([(1,2), (3,4), (5,6)]) == (9,12)

    @test aggregate((x,y) -> max.(x, y), ((10,2), (3,4), (5,6))) == (10,6)

    # Start building some records
    a = Record{:A}((1,2,3))
    @test CounterTools.name(a) == :A
    @test CounterTools.hassubrecord(a) == false
    @test a[1] == 1
    @test a[2] == 2
    @test a[3] == 3

    # mapleaves
    b = mapleaves(f, a)
    @test isa(b, Record)
    @test CounterTools.name(b) == :A
    @test b.data == (2,4,6)

    # Test subtraction
    c = b - a
    @test isa(c, Record)
    @test CounterTools.name(b) == :A
    @test c.data == (1,2,3)

    # Single record aggregation
    @test CounterTools.aggregate(a) == (1,2,3)

    # Dump to devnull to make sure this shows
    show(devnull, a)

    ##### Test over a vector
    data = [
        (1,2,3),
        (4,5,6),
        (7,8,9),
    ]
    a = Record{:A}(data)
    @test CounterTools.aggregate(a) == (12,15,18)

    ##### Work with recursive data structures now
    a = Record{:A}((
        (1,2,3),
        (4,5,6),
    ))

    b = Record{:A}((
        (7,8,9),
        (10,11,12),
    ))

    c = Record{:B}((a,b))

    # Try mapleaves
    d = mapleaves(f, c)
    @test isa(d, Record)
    @test CounterTools.name(d) == :B
    @test CounterTools.hassubrecord(d) == true
    @test isa(d[1], Record)
    @test CounterTools.name(d[1]) == :A

    @test length(d) == 2
    @test length(d[1]) == 2

    @test d[1][1] == (2,4,6)
    @test d[1][2] == (8,10,12)
    @test d[2][1] == (14,16,18)
    @test d[2][2] == (20,22,24)

    e = d - c
    @test e == c
    @test CounterTools.aggregate(e) == (1,2,3) .+ (4,5,6) .+ (7,8,9) .+ (10,11,12)
    @test CounterTools.aggregate(d) == 2 .* CounterTools.aggregate(e)
    show(devnull, e)
end
