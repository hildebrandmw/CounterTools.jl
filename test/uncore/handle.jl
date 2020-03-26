@testset "Testing Handle" begin
    # We test these operations on a `msr` register
    handle = CounterTools.Handle("/dev/cpu/0/msr")

    # Read the initial state of the CHA 0 control register
    location = CounterTools.IndexZero(0xE01)
    seek(handle, location)

    # Test reading and unsafe_reading
    initial_state = read(handle, UInt64)
    @test initial_state == unsafe_read(handle, UInt64, location)

    # Temporarily write a new value
    event = CounterTools.UncoreSelectRegister(event = 0x50, umask = 0x01)
    seek(handle, location)
    write(handle, event)

    @test read(handle, UInt64) == CounterTools.value(event)
    buffer = Vector{UInt8}(undef, sizeof(UInt64))
    @test unsafe_read(handle, UInt64, location; buffer = buffer) == CounterTools.value(event)

    # Write back the initial state
    seek(handle, location)
    write(handle, initial_state)
    @test read(handle, UInt64) == initial_state
    @test unsafe_read(handle, UInt64, location; buffer = buffer) == initial_state
end
