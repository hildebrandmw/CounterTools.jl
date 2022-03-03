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
struct IMC{T <: AbstractCPU} <: PMUType end
_unitstatus(::IMC{SkylakeServer})    = IndexZero(0xF8)
_unitcontrol(::IMC{SkylakeServer})   = IndexZero(0xF4)
_counter(::IMC{SkylakeServer}, i)    = IndexZero(0xA0 + value(i) * 0x8)
_control(::IMC{SkylakeServer}, i)    = IndexZero(0xD8 + value(i) * 0x4)
numcounters(::IMC) = 4

# For now, only read the fixed counters for IceLake servers.
# There are 4 such counters, starting at address 0x2290 and they are
# DRAM Read, DRAM Write, PM Read, and PM Write respectively
_counter(::IMC{IcelakeServer}, i) = IndexZero(0x2290 + value(i) * 0x8)

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
    # buffer::Vector{UInt8}
end
unwrap(x::IMCUncorePMU) = x.handle
pmutype(::IMCUncorePMU) = IMC{SkylakeServer}()
Base.close(x::IMCUncorePMU) = close(x.handle)

# IceLake IMC PMU
# For now - only return the free-running counters
struct IMCUncoreICX <: AbstractUncorePMU
    mmio::MMIO
end
unwrap(x::IMCUncoreICX) = x.mmio
pmutype(::IMCUncoreICX) = IMC{IcelakeServer}()
Base.close(::IMCUncoreICX) = nothing

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

unwrap(x::CHAUncorePMU) = x.handle
pmutype(::CHAUncorePMU) = CHA()
unpack(x::CHAUncorePMU) = (x.cha,)
Base.close(x::CHAUncorePMU) = close(x.handle)

#####
##### Low level accessing functions
#####

function setunitstatus!(U::AbstractUncorePMU, v)
    write(unwrap(U), convert(writetype(U), v), unitstatus(U))
end

function getunitstatus(U::AbstractUncorePMU)
    return read(unwrap(U), UInt32, unitstatus(U))
end

function setunitcontrol!(U::AbstractUncorePMU, v)
    write(unwrap(U), convert(writetype(U), v), unitcontrol(U))
end

function getunitcontrol(U::AbstractUncorePMU)
    return read(unwrap(U), UInt32, unitcontrol(U))
end

function setcontrol!(U::AbstractUncorePMU, counter, v)
    write(unwrap(U), v, control(U, counter))
end

function getcontrol(U::AbstractUncorePMU, i)
    return read(unwrap(U), UInt32, control(U, i))
end

function getcounter(U::AbstractUncorePMU, i)
    return CounterValue(read(unwrap(U), UInt64, counter(U, i)))
end

function setextra!(U::AbstractUncorePMU, i, v)
    write(unwrap(U), convert(writetype(U), v), extras(U, i))
end

function getextra(U::AbstractUncorePMU, i)
    return read(unwrap(U), UInt32, extras(U, i))
end

#####
##### Some higher level functions
#####

function getallcounters(U::AbstractUncorePMU)
    return ntuple(i -> getcounter(U, i), Val(numcounters(U)))
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
