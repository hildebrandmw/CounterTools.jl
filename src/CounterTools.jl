module CounterTools

using Libdl

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

include("lowlevel.jl")
include("pci.jl")
include("context.jl")

include("eventregister.jl")
include("monitor.jl")

# Tools for dealing with setting the affinity of
const libaffinity = joinpath(DEPSDIR, "libaffinity.so")
dlopen(libaffinity)

# When we get the current affinity from the `C` code, we're receiving a `C` allocated object
# which needs to be freed at some point.
#
# We wrap the returned pointer in this `Wrap` mutable struct and attach a finalizer which
# calls `free` on the pointer.
mutable struct Wrap
    ptr::Ptr{Cvoid}
end

free(W::Wrap) = ccall((:jl_free, libaffinity), Cvoid, (Ptr{Cvoid},), W.ptr)

function getaffinity()
    affinity = ccall((:jl_get_affinity, libaffinity), Ptr{Cvoid}, (Int64,), getpid())

    # Stop the memory leak!
    wrap = Wrap(affinity)
    finalizer(free, wrap)
    return wrap
end

setaffinity(pid, cpu::Integer) = ccall((:jl_set_affinity, libaffinity), Cvoid, (Int64, Int64,), pid, cpu)
setaffinity(pid, cpu::IndexZero) = setaffinity(pid, value(cpu))
setaffinity(wrap::Wrap) = ccall((:jl_reset_affinity, libaffinity), Cvoid, (Ptr{Cvoid},), wrap.ptr)

function program(cpu, counter, event, umask)
    # Construct the event select register contents for this event and umask
    #
    # usr = true: Allow capturing of counters in user mode
    # os = true: Allow capturing of counters in privileged mode
    # en = true: Actually enable the counters
    reg = EventSelectRegister(;
        event = event,
        umask = umask,
        usr = true,
        os = true,
        en = true,
    )

    return program(cpu, counter, reg)
end

function program(cpu, counter, reg::EventSelectRegister)
    writemsr(
        cpu,
        EVENT_SELECT_MSRS[counter],
        reg,
    )

    val = readmsr(indexzero(cpu), EVENT_SELECT_MSRS[counter])
    return nothing
end

end # module
