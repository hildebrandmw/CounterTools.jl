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
    m = CounterTools.mask(2, 4)
    @test CounterTools.isbitset(m, 2) == true
    @test CounterTools.isbitset(m, 3) == true
    @test CounterTools.isbitset(m, 4) == true
    @test CounterTools.isbitset(m, 1) == false
    @test CounterTools.isbitset(m, 5) == false
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

