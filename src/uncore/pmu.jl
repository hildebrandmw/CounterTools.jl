abstract type PMUType end
struct IMC <: PMUType end

# Register offsets by pmutype
unitstatus(::Type{IMC})    = 0xF8
unitcontrol(::Type{IMC})   = 0xF4

counter(::Type{IMC}, i::IndexZero) = 0xA0 + value(i) * 0x8
control(::Type{IMC}, i::IndexZero) = 0xD8 + value(i) * 0x4

counter(::Type{T}, i::Integer) where {T} = counter(T, indexzero(i))
control(::Type{T}, i::Integer) where {T} = control(T, indexzero(i))

struct UncorePMU{T <: PMUType}
    # A handle to the underlying
    handle::PCIHandle

    # Pre-allocated buffer for reading new counter values.
    # We return counter values as a tuple for even better performance.
    buffer::Vector{UInt8}
end

UncorePMU{T}(handle::PCIHandle) where {T} = UncorePMU{T}(handle, zeros(UInt8, 24))

#####
##### Low level accessing functions
#####

function setunitstatus!(U::UncorePMU{T}, v) where {T}
    seek(U.handle, unitstatus(T))
    write(U.handle, convert(UInt32, v))
end

function getunitstatus(U::UncorePMU{T}) where {T}
    seek(U.handle, unitstatus(T))
    return read(U.handle, UInt32)
end

function setunitcontrol!(U::UncorePMU{T}, v) where {T}
    seek(U.handle, unitcontrol(T))
    write(U.handle, convert(UInt32, v))
end

function getunitcontrol(U::UncorePMU{T}) where {T}
    seek(U.handle, unitcontrol(T))
    return read(U.handle, UInt32)
end

function setcontrol!(U::UncorePMU{T}, counter, v) where {T}
    seek(U.handle, control(T, counter))
    write(U.handle, convert(UInt32, v))
end

function getcontrol(U::UncorePMU{T}, i) where {T}
    seek(U.handle, control(T, i))
    return read(U.handle, UInt32)
end

function getcounter(U::UncorePMU{T}, i) where {T}
    seek(U.handle, counter(T, i))
    return CounterValue(read(U.handle, UInt64))
end

#####
##### Some higher level functions
#####

function getallcounters(U::UncorePMU{T}) where {T}
    seek(U.handle, counter(T, 0))
    # Read all four counters into the pre-allocated buffer
    readbytes!(U.handle, U.buffer, 4 * 8; all = false)
    # Reinterpret the buffer to construct a tuple of CounterValues
    buffer = reinterpret(UInt64, U.buffer)

    # TODO: Kind of a hack for now explicitly unrolling all of this.
    return CounterValue.((
        buffer[1],
        buffer[2],
        buffer[3],
        buffer[4],
    ))
end

function reset!(U)
    # Write to the unit control to clear all counters and control registers
    val = setbits(zero(UInt32), (0, 1, 8, 16, 17))
    setunitcontrol!(U, val)
end
