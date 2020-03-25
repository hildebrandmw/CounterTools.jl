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

# TODO: This is a hack at the moment.
#
# Read /dev/cpu.
# There is one entry per cpu, plus a "microcode" directory.
# We subtract 1 for the "microcode" directory to get the number of CPUs.
numcpus() = length(readdir("/dev/cpu")) - 1

# Write 1's to the performance counter locations.
function enablecounters(cpu)
    config = 0x0000000700000000 | (mask(numcounters())-1)
    writemsr(cpu, IA32_PERF_GLOBAL_CTRL_MSR, config)
end
disablecounters(cpu) = writemsr(cpu, IA32_PERF_GLOBAL_CTRL_MSR, zero(UInt64))

