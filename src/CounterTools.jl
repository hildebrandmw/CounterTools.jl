module CounterTools

import Mmap
using Libdl
using Distributed

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

abstract type AbstractMonitor end

"""
    read(monitor) -> Record

Read from all counters currently managed by `monitor` and return the results as a
[`CounterTools.Record`](@ref).  The structure of the [`CounterTools.Record`](@ref)
usually reflects the hierarchical structure of the counters being monitored.
"""
Base.read(::T) where {T <: AbstractMonitor} = error("Cannot read from $T")

"""
    program!(monitor)

Program the PMUs managed by `monitor`. This must be called before any results returned from
`read` will be meaningful.

This method is called automatically when `monitor` was created unless the `program = false`
keyword was passed the monitor contructor function.
"""
program!(::T) where {T <: AbstractMonitor} = error("Cannot program $T")

"""
    reset!(monitor)

Set the PMUs managed by `monitor` back to their original state.

This method is called automatically when `monitor` is garbage collected unless the
`reset = false` keyword is passed to the monitor constructor function.
"""
reset!(::T) where {T <: AbstractMonitor} = error("Cannot reset $T")

include("record.jl")
include("indexzero.jl")
include("handle.jl")
include("utils.jl")
include("affinity.jl")
include("bitfield.jl")
include("core/core.jl")
include("uncore/uncore.jl")

include("group.jl")

#####
##### API Documentation
#####


end # module
