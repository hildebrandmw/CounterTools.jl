abstract type AbstractCPU end
struct SkylakeServer <: AbstractCPU end
struct IcelakeServer <: AbstractCPU end

# Wrapper around CounterValues so subtraction automatically handles wrapping
"""
    CounterValue(x::UInt)

A raw value returned from a performance counter.
This type will automatically detect and correct for counter roll-over.

```julia
julia> a = CounterTools.CounterValue(0x0)
CV(0)

julia> b = CounterTools.CounterValue(0x1)
CV(1)

julia> b - a
1

julia> UInt(a - b)
0x00007fffffffffff
```
"""
struct CounterValue
    value::UInt64
end
value(x::CounterValue) = x.value
Base.iszero(x::CounterValue) = iszero(x.value)

function Base.:-(x::CounterValue, y::CounterValue)
    # Test if overflow happend and correct for it.
    start = (value(x) < value(y)) ? (UInt(1) << 48) : zero(UInt)
    return signed(start + value(x) - value(y))
end

Base.show(io::IO, x::CounterValue) = print(io, "CV($(value(x)))")

#####
##### Bit maniuplation functions
#####

clearbit(x, i) = x & ~(one(x) << i)
setbit(x, i) = x | (one(x) << i)

isbitset(x, i) = !iszero(x & mask(i))

clearbits(x, i) = reduce(clearbit, i; init = x)
setbits(x, i) = reduce(setbit, i; init = x)

mask(lo::T, hi::T) where {T} = (one(lo) << (hi + 1)) - (1 << lo)
mask(i) = one(i) << i

hex(i::Integer) = string(i; base = 16)

#####
##### MSR Utilities
#####

msrpath(cpu::IndexZero) = "/dev/cpu/$(value(cpu))/msr"
msrpath(cpu::Integer) = msrpath(indexzero(cpu))
function readmsr(cpu, register)
    # Path to the kernel interface for MSRs
    path = msrpath(cpu)

    # We seek to the register and read a 64 bit int
    val = open(path) do f
        seek(f, value(indexzero(register)))
        return read(f, Int64)
    end
    return val
end

function writemsr(cpu::INDEX_TYPES, register, v)
    path = msrpath(cpu)
    open(path; write = true) do f
        seek(f, value(indexzero(register)))
        write(f, v)
    end
    return nothing
end

#####
##### Reading from Counters
#####

# Fixed counter values.
@enum FixedCounter::Int64 begin
    RetiredInstructions = 0
    ClockUnhaltedThread = 1
    ClockUnhaltedCore = 2
end

# This path goes through MSRs and is expected to be much much slower than the rdpmc
# based instructions.
readcounter(cpu, counter::INDEX_TYPES) = CounterValue(readmsr(cpu, PMC_MSRS[counter]))

"""
unsafe_rdpmc(i::Integer)

Read the contents of performance counter `i`.
If `i` is between 0 and 3, a programable counter is read.
If `i` is in 2^30, 2^30+1, or 2^30 + 2, a fixed function counter is read.

This function is unsafe since reading from an illegal value will recklessly segfault.
"""
function unsafe_rdpmc(i::Union{Integer,IndexZero,FixedCounter})
    high, low = unsafe_partial_rdpmc(i)
    return CounterValue((widen(high) << 32) | low)
end

unsafe_partial_rdpmc(i::Integer) = unsafe_partial_rdpmc(indexzero(i))
unsafe_partial_rdpmc(i::FixedCounter) = unsafe_partial_rdpmc(IndexZero(2^30 + Int64(i)))

function unsafe_partial_rdpmc(i::IndexZero)
    Base.@_inline_meta
    # This is reverse engineered from `ref.cpp` in the `ref/` directory and from Julia's
    # Tuple constructing syntax.
    #
    # The Tuple constructing syntax can be queried using
    # ```
    # f(a, b) = (a, b)
    # @code_llvm f(UInt32(0), UInt32(0))
    # ```
    val = Base.llvmcall(
        raw"""
        %val = call { i32, i32 } asm sideeffect "rdpmc", "={ax},={dx},{cx},~{dirflag},~{fpsr},~{flags}"(i32 %0)
        %low = extractvalue { i32, i32 } %val, 0
        %high = extractvalue { i32, i32 } %val, 1

        %.arr.0 = insertvalue [2 x i32] undef, i32 %high, 0
        %.arr.1 = insertvalue [2 x i32] %.arr.0, i32 %low, 1
        ret [2 x i32] %.arr.1
        """,
        Tuple{UInt32, UInt32},
        Tuple{Int32},
        convert(Int32, value(i))
    )
    return val
end

#####
##### MMIO
#####

struct MMIO
    mmap::Vector{UInt8}
end
Base.pointer(::Type{T}, mmio::MMIO) where {T} = Ptr{T}(pointer(mmio.mmap))

function MMIO(address::IndexZero, len; path = "/dev/mem", read = true, write = false)
    mmap = open(path; read, write) do io
        return Mmap.mmap(io, Vector{UInt8}, (len,), value(address); grow = false)
    end
    return MMIO(mmap)
end

# Very important to mark this function as `@noinline` to prevent compiler optimizations
# from breaking what the memory mapped hardware actually wants to do.
#
# The big danger is the compiler merging multie 32-bit or 64-bit loads/stores into a vector
# load/store, which the MMIO is not happy with.
@noinline function Base.read(mmio::MMIO, ::Type{T}, offset::IndexZero) where {T}
    return Base.unsafe_load(pointer(T, mmio) + value(offset))
end

@noinline function Base.write(mmio::MMIO, v::T, offset::IndexZero) where {T}
    return Base.unsafe_store!(pointer(T, mmio) + value(offset), v)
end

