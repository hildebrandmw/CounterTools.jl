function mysum(x)
    s = zero(eltype(x))
    for i in x
        s += i
    end
    return s
end

@testset "Testing CHA" begin
    # First, we build our events
    events = (
        # TOR_INSERTS.IA_MISS
        CounterTools.UncoreSelectRegister(event = 0x35, umask = 0x21),
        # TOR_INSERTS.IA_HIT
        CounterTools.UncoreSelectRegister(event = 0x35, umask = 0x11),
        # TOR_INSERTS.ALL_IA
        CounterTools.UncoreSelectRegister(event = 0x35, umask = 0x31),
    )

    # We need to configure the filter
    filter1 = CounterTools.CHAFilter1(
        opc1 = 0x25A,   # LLC Prefetch Read
        opc0 = 0x202,   # Demand Data Read
        not_near_memory = true,
        near_memory = true,
        all_opc = false,
        loc = true,
        remote = false,
    )

    # Instantiate the monitor
    cpu = CounterTools.IndexZero(1)
    socket = CounterTools.IndexZero(0)

    monitor = CounterTools.CHAMonitor(
        cpu,
        socket,
        events;
        filter1 = filter1
    )

    old_affinity = CounterTools.getaffinity()

    # Set our affinity to the selected CPU
    CounterTools.setaffinity(cpu)

    # Create a little array that is bigger than the L2 cache, but smaller than the L3
    # cache.
    #
    # Choose a size of 6 MB
    sizes = [
        6_000_000,
        8_000_000,
        10_000_000,
    ]

    for sz in sizes
        A = rand(Float32, div(sz, sizeof(Float32)))

        # Warm up "sum"
        mysum(A)
        iterations = 1000

        # Take counters before and after taking the sum.
        # Since our array fits within the L3 cache, we expect to see amlost all cache hits
        pre = read(monitor)
        y = zero(eltype(A))
        for _ in 1:iterations
            y += mysum(A)
        end
        post = read(monitor)

        # Show y to avoid the loop getting optimized out
        @show y
        diff = CounterTools.aggregate(post - pre)

        # Make sure the number of read hits is what we expect
        #
        # Divide the size of the array by 64 to adjust for cache-line size
        expected_read_hits = sizeof(A) / 64 * iterations
        @test diff[2] > 0.95 * expected_read_hits
        @test diff[2] < 1.05 * expected_read_hits

        # Make sure the miss rate is less than 10%
        @test diff[1] / diff[2] < 0.1
    end

    sizes = [
        500_000_000,
        1000_000_000,
        2000_000_000,
    ]

    for sz in sizes
        A = rand(Float32, div(sz, sizeof(Float32)))

        # Warm up "sum"
        mysum(A)
        iterations = 20

        # Take counters before and after taking the sum.
        # Since our array fits within the L3 cache, we expect to see amlost all cache hits
        pre = read(monitor)
        y = zero(eltype(A))
        for _ in 1:iterations
            y += mysum(A)
        end
        post = read(monitor)

        # Show y to avoid the loop getting optimized out
        @show y
        diff = CounterTools.aggregate(post - pre)

        # Make sure the number of read hits is what we expect
        #
        # Divide the size of the array by 64 to adjust for cache-line size
        expected_read_misses = sizeof(A) / 64 * iterations
        @test diff[1] > 0.9 * expected_read_misses

        # Make sure the miss rate is less than 10%
        @test diff[1] / diff[3] > 0.9

        println("Miss Rate: ", diff[1] / diff[3])
    end

    # Now, iterate through arrays that are way bigger than the L3 cache.
    # Make sure we get mostly misses and have a high miss rate

    # Restore the old affinity
    CounterTools.setaffinity(old_affinity)
end
