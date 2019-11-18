module PerformanceCounters

using Libdl

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
const DEPSDIR = joinpath(PKGDIR, "deps")

include("lowlevel.jl")
include("eventregister.jl")
include("monitor.jl")

# Tools for dealing with setting the affinity of 
const libaffinity = joinpath(DEPSDIR, "libaffinity.so")
dlopen(libaffinity)

mutable struct Wrap
    ptr::Ptr{Cvoid}
end

function getaffinity()
    affinity = ccall(
        (:jl_get_affinity, libaffinity), 
        Ptr{Cvoid}, 
        (Int64,),
        getpid(),
    )

    wrapped = Wrap(affinity)
    finalizer(wrapped) do x
        ccall(
            (:jl_free, libaffinity),
            Cvoid,
            (Ptr{Cvoid},),
            x.ptr 
        )
    end
    return wrapped
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
