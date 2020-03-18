# Code for dealing with Core level counters.
include("lowlevel.jl")
include("utils.jl")

# This is the high level API for core monitoring
mutable struct CoreMonitor{T,N}
    # Collection of CPUs for which to collect data.
    cpus::T

    # The events that we are collecting
    events::NTuple{N, CoreSelectRegister}

    # For cleaning up after ourselves
    initial_state::CounterState
    initial_affinity::PtrWrap
    isrunning::Bool

    """
        CoreMonitor(cpus, events::NTuple{N, CoreSelectRegister}; program = true) where {N}

    Construct a `CoreMonitor` monitoring `events` on `cpus`.
    If `program == true`, then also program the performance counters to on each CPU.
    Otherwise, the system is left unprogrammed and the user must later call `program!` on
    the `CoreMonitor`.
    """
    function CoreMonitor(
            cpus::T,
            events::NTuple{N, CoreSelectRegister};
            program = true
        ) where {T, N}

        # Make sure nothing crazy's going down!!
        if length(events) > numcounters()
            errmsg = """
            Number of Hardware Events must be less than or equal the number of programmable
            performance counters.

            On your CPU, this number is $ncounters.
            """
            throw(ArgumentError(errmsg))
        end

        # Build up the initial values list to save this for later.
        initial_state = CounterState(;cpus = cpus)
        initial_affinity = getaffinity()

        # Get the original state of the hardware performance counters.
        monitor = new{T,N}(
            cpus,
            events,
            initial_state,
            initial_affinity,
            false
        )

        finalizer(reset!, monitor)
        program && program!(monitor)
        return monitor
    end
end

function program(cpu, counter, reg::CoreSelectRegister)
    writemsr(cpu, EVENT_SELECT_MSRS[counter], reg)
    return nothing
end

function program!(M::CoreMonitor)
    for cpu in M.cpus
        # Enable counters on this cpu
        enablecounters(cpu)

        # Program each of the events to the CPU
        for (i, event) in enumerate(M.events)
            program(cpu, i, event)
        end
    end
    M.isrunning = true
    return nothing
end

"""
    read(M::CoreMonitor) -> Vector{<:Tuple}

Read all events from all CPUs in `M`.
The result is a vector, indexed by CPU.
The elements of the vector are tuples, positionally correlated with events in `M`.
"""
function Base.read(M::CoreMonitor{T, N}) where {T, N}
    pid = getpid()
    results = map(M.cpus) do cpu
        # Set the affinity to this CPU
        setaffinity(pid, cpu)

        # Read the events
        return Record{:cpu}(ntuple(i -> unsafe_rdpmc(i), N))
    end |> Record{:cpu_set}

    # Reset the affinity.
    setaffinity(M.initial_affinity)
    return results
end

function reset!(M::CoreMonitor)
    # Set all the counters back to their original state.
    restore!(M.initial_state)
    M.isrunning = false
    return nothing
end
