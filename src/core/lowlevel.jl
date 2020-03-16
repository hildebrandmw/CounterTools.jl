# Bit maniuplation functions
clearbit(x, i) = x & ~(1 << i)
setbit(x, i) = x | (1 << i)

clearbits(x, i) = reduce(clearbit, i; init = x)
setbits(x, i) = reduce(setbit, i; init = x)

mask(lo, hi) = (1 << (hi + 1)) - (1 << lo)
mask(i) = 1 << i

hex(i::Integer) = string(i; base = 16)

# Global enable of performance counters
#
# See: Section 18.2 (Architectural Performance Monitoring) of Volume 3 of the Software Developer's Guide, as well as in Chapter 35
const IA32_PERF_GLOBAL_CTRL_MSR = UInt(0x38f)
const IA32_FIXED_CTR_CTRL_MSR = UInt(0x38D)

# MSR for programming programable performance counters.
# Indexed by counter number.
const EVENT_SELECT_MSRS = (
    0x186,
    0x187,
    0x188,
    0x189,
    0x18a,
    0x18b,
    0x18c,
    0x18d,
)

# MSRs for reading the contents of performance counters.
# Indexed by counter number.
const PMC_MSRS = (
    0xc1,
    0xc2,
    0xc3,
    0xc4,
    0xc6,
    0xc7,
    0xc9,
    0xc9,
)

msrpath(cpu::IndexZero) = "/dev/cpu/$(value(cpu))/msr"
msrpath(cpu::Integer) = msrpath(indexzero(cpu))
function readmsr(cpu::INDEX_TYPES, register::Integer)
    # Path to the kernel interface for MSRs
    path = msrpath(cpu)

    # We seek to the register and read a 64 bit int
    val = open(path) do f
        seek(f, register)
        return read(f, Int64)
    end
    return val
end

function writemsr(cpu::INDEX_TYPES, register::Integer, value)
    path = msrpath(cpu)
    open(path; write = true) do f
        seek(f, register)
        write(f, value)
    end
    return nothing
end

"""
Return the number of programable performance counters on your CPU.
"""
function numcounters()
    # Read from the global control register - use CPU 0 because it always exists
    val = readmsr(IndexZero(0), IA32_PERF_GLOBAL_CTRL_MSR)

    # Clear bits 32, 33, and 34 since these correspond to the fixed function registers.
    val = clearbits(val, (32, 33, 34))

    # The number of set bits is the number of programmable counters.
    return count_ones(val)
end
const NUMCOUNTERS = numcounters()

# TODO: This is a hack at the moment.
#
# Read /dev/cpu.
# There is one entry per cpu, plus a "microcode" directory.
# We subtract 1 for the "microcode" directory to get the number of CPUs.
numcpus() = length(readdir("/dev/cpu")) - 1

# Write 1's to the performance counter locations.
function enablecounters(cpu)
    config = 0x0000000700000000 | (mask(NUMCOUNTERS)-1)
    writemsr(cpu, IA32_PERF_GLOBAL_CTRL_MSR, config)
end
disablecounters(cpu) = writemsr(cpu, IA32_PERF_GLOBAL_CTRL_MSR, zero(UInt64))

#####
##### Reading from Counters
#####

# Wrapper around CounterValues so subtraction automatically handles wrapping
struct CoreCounterValue
    value::UInt64
end
value(x::CoreCounterValue) = x.value

function Base.:-(x::CoreCounterValue, y::CoreCounterValue)
    # Test if overflow happened, add a large fixed value.
    start = value(x) < value(y) ? (UInt(1) << 47) : zero(UInt64)
    return convert(Int, start + value(x) - value(y))
end

# This path goes through MSRs and is expected to be much much slower than the rdpmc
# based instructions.
readcounter(cpu, counter::INDEX_TYPES) = CoreCounterValue(readmsr(cpu, PMC_MSRS[counter]))

"""
unsafe_rdpmc(i::Integer)

Read the contents of performance counter `i`.
If `i` is between 0 and 3, a programable counter is read.
If `i` is in 2^30, 2^30+1, or 2^30 + 2, a fixed function counter is read.

This function is unsafe since reading from an illegal value will recklessly segfault.
"""
function unsafe_rdpmc(i::INDEX_TYPES)
    high, low = unsafe_partial_rdpmc(i)
    return CoreCounterValue((widen(high) << 32) | low)
end

unsafe_partial_rdpmc(i::Integer) = unsafe_partial_rdpmc(indexzero(i))
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

