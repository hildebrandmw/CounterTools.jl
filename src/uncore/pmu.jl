abstract type PMUType end

pmutype(::T) where {T} = error("`pmutype` not defined for arguments of type $T")

# Defaults
_unitstatus(x::PMUType, i...)  = error("`unitstatus` undefined for $(typeof(x))")
_unitcontrol(x::PMUType, i...) = error("`unitcontrol` undefined for $(typeof(x))")
_counter(x::PMUType, i...)     = error("`counter` undefined for $(typeof(x))")
_control(x::PMUType, i...)     = error("`control` undefined for $(typeof(x))")
_extras(x::PMUType, i...)      = error("`extras` undefined for $(typeof(x))")

writetype(x::PMUType) = UInt32

numcounters(x::PMUType)        = error("`numcounters` undefined for $(typeof(x))")
numbytes(x::PMUType) = sizeof(UInt64) * numcounters(x)

unpack(x) = ()
unitstatus(x, i...)     = _unitstatus(pmutype(x), indexzero.((unpack(x)..., i...))...)
unitcontrol(x, i...)    = _unitcontrol(pmutype(x), indexzero.((unpack(x)..., i...))...)
counter(x, i...)        = _counter(pmutype(x), indexzero.((unpack(x)..., i...))...)
control(x, i...)        = _control(pmutype(x), indexzero.((unpack(x)..., i...))...)
extras(x, i...)         = _extras(pmutype(x), indexzero.((unpack(x)..., i...))...)
writetype(x) = writetype(pmutype(x))

numcounters(x) = numcounters(pmutype(x))
numbytes(x) = numbytes(pmutype(x))

### Integrated Memory Controller
struct IMC <: PMUType end
_unitstatus(::IMC)    = IndexZero(0xF8)
_unitcontrol(::IMC)   = IndexZero(0xF4)
_counter(::IMC, i)    = IndexZero(0xA0 + value(i) * 0x8)
_control(::IMC, i)    = IndexZero(0xD8 + value(i) * 0x4)
numcounters(::IMC) = 4

### CHA Counters
struct CHA <: PMUType end
_unitstatus(::CHA, i)   = IndexZero(0xE07 + value(i) * 0x10)
_unitcontrol(::CHA, i)  = IndexZero(0xE00 + value(i) * 0x10)
_counter(::CHA, cha, i) = IndexZero(0xE08 + value(cha) * 0x10 + value(i))
_control(::CHA, cha, i) = IndexZero(0xE01 + value(cha) * 0x10 + value(i))
_extras(x::CHA, cha, i) = IndexZero(0xE05 + value(cha) * 0x10 + value(i))
writetype(::CHA) = UInt64
numcounters(::CHA) = 4

# Customize for various types Specialize
abstract type AbstractUncorePMU end

##### IMC Uncore PMU
# PMU implementation for monitoring the integrated memory controller
struct IMCUncorePMU <: AbstractUncorePMU
    # A handle to the underlying
    handle::Handle

    # Pre-allocated buffer for reading new counter values.
    # We return counter values as a tuple for even better performance.
    buffer::Vector{UInt8}
end
IMCUncorePMU(handle::Handle) = IMCUncorePMU(handle, zeros(UInt8, numbytes(IMC())))
pmutype(::IMCUncorePMU) = IMC()
Base.close(x::IMCUncorePMU) = close(x.handle)

##### CHA Uncore PMU
# PMU implementation for monitoring the CHA
struct CHAUncorePMU <: AbstractUncorePMU
    # We hold on to a single handle for the MSR path, shared by all PMUs
    handle::Handle
    # The number of this CHA
    cha::IndexZero{Int}
    buffer::Vector{UInt8}

    # Allow passing a buffer, or manually create one
    function CHAUncorePMU(
            handle::Handle,
            cha,
            buffer = zeros(UInt8, numbytes(CHA()))
        )
        resize!(buffer, numbytes(CHA()))

        return new(handle, indexzero(cha), buffer)
    end
end

pmutype(::CHAUncorePMU) = CHA()
unpack(x::CHAUncorePMU) = (x.cha,)
Base.close(x::CHAUncorePMU) = close(x.handle)

#####
##### Low level accessing functions
#####

function setunitstatus!(U::AbstractUncorePMU, v)
    seek(U.handle, unitstatus(U))
    write(U.handle, convert(writetype(U), v))
end

function getunitstatus(U::AbstractUncorePMU)
    seek(U.handle, unitstatus(U))
    return read(U.handle, UInt32)
end

function setunitcontrol!(U::AbstractUncorePMU, v)
    seek(U.handle, unitcontrol(U))
    write(U.handle, convert(writetype(U), v))
end

function getunitcontrol(U::AbstractUncorePMU)
    seek(U.handle, unitcontrol(U))
    return read(U.handle, UInt32)
end

function setcontrol!(U::AbstractUncorePMU, counter, v)
    seek(U.handle, control(U, counter))
    write(U.handle, convert(writetype(U), v))
end

function getcontrol(U::AbstractUncorePMU, i)
    seek(U.handle, control(U, i))
    return read(U.handle, UInt32)
end

function getcounter(U::AbstractUncorePMU, i)
    seek(U.handle, counter(U, i))
    return CounterValue(read(U.handle, UInt64))
end

function setextra!(U::AbstractUncorePMU, i, v)
    seek(U.handle, extras(U, i))
    write(U.handle, convert(writetype(U), v))
end

function getextra(U::AbstractUncorePMU, i)
    seek(U.handle, extras(U, i))
    return read(U.handle, UInt32)
end

#####
##### Some higher level functions
#####

function getallcounters(U::AbstractUncorePMU)
    # Need to seek and read since MSR based registers don't automatically progress
    # the position in the system file.
    a = unsafe_read(U.handle, UInt64, counter(U, 1); buffer = U.buffer)
    b = unsafe_read(U.handle, UInt64, counter(U, 2); buffer = U.buffer)
    c = unsafe_read(U.handle, UInt64, counter(U, 3); buffer = U.buffer)
    d = unsafe_read(U.handle, UInt64, counter(U, 4); buffer = U.buffer)
    return CounterValue.((a, b, c, d))
end

function reset!(U::AbstractUncorePMU)
    # Write to the unit control to clear all counters and control registers
    val = setbits(zero(writetype(U)), (0, 1, 8, 16, 17))
    setunitcontrol!(U, val)
end

function enable!(U::AbstractUncorePMU)
    val = setbits(zero(writetype(U)), (16, 17))
    setunitcontrol!(U, val)
end
