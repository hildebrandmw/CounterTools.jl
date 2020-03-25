module CounterTools

using Libdl
using Distributed

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

include("record.jl")
include("indexzero.jl")
include("utils.jl")
include("affinity.jl")
include("bitfield.jl")
include("core/core.jl")
include("uncore/uncore.jl")

end # module
