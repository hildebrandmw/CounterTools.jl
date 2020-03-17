include("eventselect.jl")
include("pci.jl")
include("pmu.jl")
include("imc.jl")

# At the moment, we use PCM as the backend for Uncore monitoring.

# Parameterize over
#
# Number of Sockets
# Number of memory controllers per socket
# Number of memory channels per socket
# struct UncoreMonitor{S,IMC,CH}
#     monitor::PCM.UncoreMemoryMonitor
# end
