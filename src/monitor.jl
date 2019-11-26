# Struct for programming and collecting counter values.
"""
Monitor Core events.
"""
mutable struct CoreMonitor{T, N}
    # Collection of CPUs for which to collect data.
    cpus::T
    events::NTuple{N, EventSelectRegister}

    # Dictionary containing the initial state of the core counters.
    #
    # Used to reset upon cleanup.
    # Maps a (CPU,Counter Number) to the original value.
    initial_state::Dict{Tuple{Int,Int},Int}
    isrunning::Bool

    """
        CoreMonitor(cpus, events::NTuple{N, EventSelectRegister}; program = true) where {N}

    Construct a `CoreMonitor` monitoring `events` on `cpus`.
    If `program == true`, then also program the performance counters to on each CPU.
    Otherwise, the system is left unprogrammed and the user must later call `program!` on 
    the `CoreMonitor`.
    """
    function CoreMonitor(
            cpus::T, 
            events::NTuple{N, EventSelectRegister};
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
        initial_state = Dict{Tuple{Int, Int}, Int}()
        for cpu in cpus
            for i in 1:N
                initial_state[(cpu, i)] = readmsr(cpu, EVENT_SELECT_MSRS[i])
            end
        end

        # Get the original state of the hardware performance counters.
        monitor = new{T,N}(
            cpus,
            events,
            initial_state,
            false
        )

        finalizer(cleanup!, monitor)
        program && program!(M)
        return monitor
    end
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
    # Get the old affinity for this
    affinity = getaffinity()
    pid = getpid()
    results = map(M.cpus) do cpu
        # Set the affinity to this CPU
        setaffinity(pid, indexzero(cpu))

        # Read the events
        return ntuple(i -> unsafe_rdpmc(indexzero(i)), N)
    end

    # Reset the affinity.
    #
    # NOTE: `affinity` holds a pointer to a `C` allocated struct.
    # It is wrapped in a `Wrap` object that will call `free` when Garbage Collected -
    # preventing a memory leak (hopefully)
    setaffinity(affinity)
    return results
end

function cleanup!(M::CoreMonitor)
    # Set all the counters back to their original state.
    for cpu in M.cpus
        for i in 1:length(M.events)
            program(cpu, i, EventSelectRegister(M.initial_state[(cpu, i)]))
        end
    end
    M.isrunning = false
    return nothing
end

function test()
    events = (
        EventSelectRegister(event = 0xD0, umask = 0x81, usr = true, os = true, en = true),
        EventSelectRegister(event = 0xD0, umask = 0x80, usr = true, os = true, en = true),
    )

    cores = 1:20
    return CoreMonitor(cores, events)
end
