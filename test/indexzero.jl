@testset "Testing IndexZero" begin
    IndexZero = CounterTools.IndexZero
    x = CounterTools.IndexZero(0)
    @test CounterTools.value(x) == 0

    # `Integers` should have 1 subtracted from them.
    # `IndexZero`s should just pass through
    y = CounterTools.indexzero(1)
    z = CounterTools.indexzero(x)
    @test CounterTools.value(y) == 0
    @test y == z

    A = [1,2,3]
    B = (1,2,3)
    @test A[y] == A[1]
    @test B[y] == B[1]

    # Iterator interface
    @test collect(y) == [y]
end
