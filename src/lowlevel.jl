# Bit maniuplation functions
clearbit(x, i) = x & ~(1 << i)
setbit(x, i) = x | (1 << i)

clearbits(x, i) = reduce(clearbit, i; init = x)
setbits(x, i) = reduce(setbit, i; init = x)

mask(lo, hi) = (1 << (hi + 1)) - (1 << lo)
mask(i) = 1 << i

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
    0xc8,
    0xc9,
)

msrpath(cpu::Integer) = "/dev/cpu/$cpu/msr"
function readmsr(cpu::Integer, register::Integer)
    # Path to the kernel interface for MSRs
    path = msrpath(cpu)

    # We seek to the register and read a 64 bit int
    val = open(path) do f
        seek(f, register)
        return read(f, Int64)
    end
    return val
end

function writemsr(cpu, register::Integer, value::Integer)
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
    val = readmsr(0, IA32_PERF_GLOBAL_CTRL_MSR) 

    # Clear bits 32, 33, and 34 since these correspond to the fixed function registers.
    val = clearbits(val, (32, 33, 34)) 

    # The number of set bits is the number of programmable counters.
    return count_ones(val) 
end

# Write 1's to the performance counter locations.
enablecounters(cpu) = writemsr(cpu, IA32_PERF_GLOBAL_CTRL_MSR, 0x00000007000000ff)

"""
rdpmc(i::Integer)

Read the contents of performance counter `i`.
If `i` is between 0 and 3, a programable counter is read.
If `i` is in 2^30, 2^30+1, or 2^30 + 2, a fixed function counter is read.

This function is unsafe since reading from an illegal value will recklessly segfault.
"""
function rdpmc(i::Integer)
    Base.@_inline_meta
    # This is reverse engineered from `ref.cpp` in the `ref/` directory.
    val = Base.llvmcall(
        raw"""
        %val = call { i32, i32 } asm sideeffect "rdpmc", "={ax},={dx},{cx},~{dirflag},~{fpsr},~{flags}"(i32 %0)
        %low = extractvalue { i32, i32 } %val, 0
        %high = extractvalue{ i32, i32 } %val, 1

        %low_64 = zext i32 %low to i64
        %high_64 = zext i32 %high to i64

        %shift_high_64 = shl i64 %high_64, 32
        %result = or i64 %low_64, %shift_high_64
        ret i64 %result
        """,
        Int64,
        Tuple{Int32},
        convert(Int32, i)
    )
    return val
end
