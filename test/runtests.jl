using CounterTools
using Test

@testset "Low Level Utils" begin
    # clear bit
    for i in 0:63
        @test CounterTools.clearbit(typemax(UInt64), i) == typemax(UInt64) - UInt64(2)^i
    end

    # Set bit
    for i in 0:63
        @test CounterTools.setbit(UInt64(0), i) == UInt64(2)^(i)
    end

    # clear and set bits
    @test CounterTools.clearbits(typemax(UInt64), 0:63) == zero(UInt64)
    @test CounterTools.setbits(zero(UInt64), 0:63) == typemax(UInt64)

    @test CounterTools.mask(2,4) == (1 << 2) + (1 << 3) + (1 << 4)
end

# Test writing and reading MSRs
@testset "MSRs" begin
    # Get the current state of counters on CPU 2
    #
    # Avoid CPU 1 (IndexZero(0)) because we're messing with the counter settings.
    # CPU 1 often has a watchdog timer ...
    cpu = CounterTools.IndexZero(1)
    ctrl = CounterTools.IA32_PERF_GLOBAL_CTRL_MSR

    initial_state = CounterTools.readmsr(cpu, ctrl)

    CounterTools.disablecounters(cpu)
    @test CounterTools.readmsr(cpu, ctrl) == 0

    # Enable the counters
    CounterTools.enablecounters(cpu)
    config = 0x0000000700000000 | (CounterTools.mask(CounterTools.numcounters()) - 1)
    @test CounterTools.readmsr(cpu, ctrl) == config

    CounterTools.writemsr(cpu, ctrl, initial_state)
end

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
