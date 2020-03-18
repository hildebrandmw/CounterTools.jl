module CounterTools

using Libdl

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

include("api.jl")
include("indexzero.jl")
include("utils.jl")
include("affinity.jl")
include("select.jl")
include("core/core.jl")
include("uncore/uncore.jl")

end # module
