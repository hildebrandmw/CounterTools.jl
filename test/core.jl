# Now we try programming processors, running programs, etc.
@testset "Programming" begin
    # Show the native code for rdpmc
    #print(@code_native syntax=:intel debuginfo=:none CounterTools.unsafe_rdpmc(UInt(1)))

    # Record the initial state - just for the CPU we're using
    cpu = CounterTools.IndexZero(1)

    CounterTools.enablecounters(cpu)
    old_counter_state = CounterTools.CounterState(; cpus = cpu)

    # Program the CPU to record number of retired instructions.
    esr = CounterTools.CoreSelectRegister(; event = 0xC7, umask = 0x01)
    CounterTools.writemsr(cpu, CounterTools.EVENT_SELECT_MSRS[1], esr)

    # Quick test to make sure the MSR was programmed appropriately.
    @test CounterTools.readmsr(cpu, CounterTools.EVENT_SELECT_MSRS[1]) == esr.val

    # Set affinity for CPU 1
    old_affinity = CounterTools.getaffinity()
    CounterTools.setaffinity(cpu)

    # Precompile the "sum" function that we'll be testing
    A = rand(Float64, 10)
    s = sum(A)

    # Make sure the number of floating point ops is within expected
    for i in 4:8
        A = rand(Float64, 10^i)
        pre = CounterTools.unsafe_rdpmc(1)
        sum(A)
        post = CounterTools.unsafe_rdpmc(1)

        # As a heuristic, construct a little bit of a boundary around the expected
        # number of additions
        @test post - pre >= (10^i - 10)
        @test post - pre <= (10^i + 100)
    end

    # Program back the old affinity and counter state
    CounterTools.setaffinity(old_affinity)
    CounterTools.restore!(old_counter_state)
end
