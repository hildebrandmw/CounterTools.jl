abstract type AbstractArchitecture end

# Uncore monitoring is different between `Core` and the various `Xeon Scalables`.
struct Core <: AbstractArchitecture
struct Xeon <: AbstractArchitecture end

#####
##### Core specific monitoring.
#####

# # Names and offsets of `Core` imc events
# # Add 0x5000 + BAR to get the correct offset.
# const CORE_IMC_COUNTERS = (
#     dram_gt_requests = 0x40,
#     dram_ia_requests = 0x44,
#     dram_io_requests = 0x48,
#     dram_data_reads  = 0x50,
#     dram_data_write  = 0x54,
# )
#
# imc_events(::Core) = keys(CORE_IMC_COUNTERS)
#
# # Reference Uncore monitoring manuals for `Core` architecture.
# function getbar(::Core)
#     bar = open(pcipath(0, 0, 0)) do f
#         seek(f, 0x48)
#         return read(f, Int64)
#     end
# end
