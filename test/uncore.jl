@testset "Testing PCI" begin
    # Make sure we find busses for each socket.
    #
    # This isn't a great test but will at least allow for testing of regressions on
    # other systems.
    @test length(CounterTools.findbusses()) == 2
end

@testset "Testing PMU" begin
    # Do some experimenting with a PMU unit.
    busses = CounterTools.findbusses()

    # Get the bus for Socket 0
    bus = busses[1]

    # Open up the PCI path to this counter
    device = CounterTools.SKYLAKE_IMC_REGISTERS[1][1].device
    fn = CounterTools.SKYLAKE_IMC_REGISTERS[1][1].fn

    handle = CounterTools.PCIHandle(bus, device, fn)
    pmu = CounterTools.UncorePMU{CounterTools.IMC}(handle)

    # First things first - reset the PMU
    CounterTools.reset!(pmu)

    # Read from all registers - entries should all be zero at this point
    @test CounterTools.getunitstatus(pmu) == zero(UInt32)

    for i in 1:4
        @test iszero(CounterTools.getcontrol(pmu, i))
        @test iszero(CounterTools.getcounter(pmu, i))
    end

    # Now, we come up with an event
    # - try to program each of the counters:
    # - make sure our programming was successful
    # - make sure the counters are returning some non-zero value

    # The event we choose simply monitors DRAM read and write traffic.
    dram_reads = CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0x3)
    dram_writes = CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0xC)

    for i in 1:4
        CounterTools.setcontrol!(pmu, i, dram_reads)
        @test CounterTools.getcontrol(pmu, i) == CounterTools.value(dram_reads)

        # TODO: Simple test function
        sleep(1)
        pre = CounterTools.getcounter(pmu, i)
        @test !iszero(pre)
    end

    # Try resetting again
    CounterTools.reset!(pmu)
    for i in 1:4
        @test iszero(CounterTools.getcontrol(pmu, i))
        @test iszero(CounterTools.getcounter(pmu, i))
    end
end

@testset "Testing Misc iMC utility functions" begin
    # Test `tupleflatten`.
    a = (
        (
            (1, 2, 3),
            (4, 5, 6),
        ),
        (
            (7, 8, 9),
            (10, 11, 12),
            (13, 14, 15),
        )
    )

    b = (
        (1, 2, 3),
        (4, 5, 6),
        (7, 8, 9),
        (10, 11, 12),
        (13, 14, 15)
    )

    @test CounterTools.tupleflatten(a) == b
    @test CounterTools.aggregate(a) == reduce((x,y) -> x .+ y, b)

    # Some testing on mapleaves.
    CounterTools.mapleaves(f, X::Integer...) = f(X...)
    a2 = (
        (
            (2, 3, 4),
            (5, 6, 7),
        ),
        (
            (8, 9, 10),
            (11, 12, 13),
            (14, 15, 16),
        )
    )
    @test CounterTools.mapleaves(x -> x + 1, a) == a2

    a3 = (
        (
            (2, 4, 6),
            (8, 10, 12),
        ),
        (
            (14, 16, 18),
            (20, 22, 24),
            (26, 28, 30),
        )
    )
    @test CounterTools.mapleaves(+, a, a) == a3
end

@testset "Testing iMC Monitor" begin
    # Monitor DRAM reads and writes
    dram_reads = CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0x3)
    dram_writes = CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0xC)

    events = (
        dram_reads,
        dram_writes,
        dram_writes,
        dram_reads,
    )

    # Construct a iMC Monitor
    monitor = CounterTools.IMCMonitor(events)

    # Test that creating another monitor throws an error
    @test_throws ErrorException CounterTools.IMCMonitor(events)

    # Compile the reading test program.
    ntimes = 10
    array_size = 10^7
    compile_test_program("read.cpp", ntimes = ntimes, array_size = array_size)

    pre = read(monitor)
    # NOTE: This is running on numanode zero, so we'll look at the results
    # from Socket 0 for testing purposes
    run_test_program("read.cpp")
    post = read(monitor)

    # Reset the monitor so we don't clobber anything on subsequent runs.
    CounterTools.reset!(monitor)

    # Accumulate and diff
    socket_aggregates = CounterTools.aggregate.(CounterTools.counterdiff(post, pre))
    socket_0 = first(socket_aggregates)

    # Compute the expected amount of read traffic.
    # Remeber that the iMC counters count in transactions and that each transaction
    # is 64 bytes
    expected_read_bytes =  array_size * 64 * ntimes
    expected_read_actions = div(expected_read_bytes, 64)

    # We write to the array once to initialize it, so compute the expected number
    # of read actions as well.
    expected_write_bytes = array_size * 64 * 2
    expected_write_actions = div(expected_write_bytes, 64)

    @show socket_0
    @show expected_read_actions
    @show expected_write_actions

    # The number of DRAM reads measured should strictly be greater than the minimum,
    # especially since we exceed the size of the L3 cache
    @test socket_0[1] >= expected_read_actions
    @test socket_0[1] <= 1.2 * expected_read_actions
    @test socket_0[4] >= expected_read_actions
    @test socket_0[4] <= 1.2 * expected_read_actions

    # The number of write actions should be well less than half the number of read actions.
    #
    # The lower and upper bounds are mainly derived from heuristics
    @test socket_0[2] >= 0.8 * expected_write_actions
    @test socket_0[2] <= 1.2 * expected_write_actions
    @test socket_0[3] >= 0.8 * expected_write_actions
    @test socket_0[3] <= 1.2 * expected_write_actions

    ##### Write Test
    compile_test_program("write.cpp", ntimes = ntimes, array_size = array_size)
    CounterTools.program!(monitor)

    pre = read(monitor)
    run_test_program("write.cpp")
    post = read(monitor)
    CounterTools.reset!(monitor)

    # Accumulate and diff
    socket_aggregates = CounterTools.aggregate.(CounterTools.counterdiff(post, pre))
    socket_0 = first(socket_aggregates)

    # We write to the array once to initialize it, so compute the expected number
    # of read actions as well.
    expected_write_bytes = array_size * 64 * ntimes
    expected_write_actions = div(expected_write_bytes, 64)

    # In this case, we don't have a really good handle on the number of expected read
    # actions, so lets just set it for 1/5th the number of write actions

    @show socket_0
    @show expected_read_actions
    @show expected_write_actions

    @test socket_0[1] <= expected_write_actions / 5
    @test socket_0[4] <= expected_write_actions / 5

    @test socket_0[2] >= expected_write_actions
    @test socket_0[2] <= 1.2 * expected_write_actions
    @test socket_0[3] >= expected_write_actions
    @test socket_0[3] <= 1.2 * expected_write_actions

    #####
    ##### STREAM
    #####

    # Finally, lets run our modified version of the STREAM benchmark
    compile_test_program("STREAM.cpp", ntimes = ntimes, array_size = array_size)
    CounterTools.program!(monitor)

    pre = read(monitor)
    run_test_program("STREAM.cpp")
    post = read(monitor)
    CounterTools.reset!(monitor)

    socket_aggregates = CounterTools.aggregate.(CounterTools.counterdiff(post, pre))
    socket_0 = first(socket_aggregates)

    # Expect 5 times through the array for both read and write
    expected_read_bytes =  5 * array_size * 64 * ntimes
    expected_read_actions = div(expected_read_bytes, 64)
    expected_write_actions = expected_read_actions

    # Reads
    @test socket_0[1] >= expected_read_actions
    @test socket_0[1] <= 1.2 * expected_read_actions
    @test socket_0[4] >= expected_read_actions
    @test socket_0[4] <= 1.2 * expected_read_actions

    # Writes
    @test socket_0[2] >= expected_write_actions
    @test socket_0[2] <= 1.2 * expected_write_actions
    @test socket_0[3] >= expected_write_actions
    @test socket_0[3] <= 1.2 * expected_write_actions
end