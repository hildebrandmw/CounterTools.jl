# Struct for programming and collecting counter values.
mutable struct Monitor{T}
    # Collection of CPUs for which to collect data.
    cpus::T
    events::Vector{EventSelectRegister}     
    isrunning::Bool

    function Monitor(cpus::T, events) where {T}
        # Make sure nothing crazy's going down!!
        if length(events) > numcounters()
            errmsg = """
            Number of Hardware Events must be less than or equal the number of programmable 
            performance counters.

            On your CPU, this number is $ncounters.
            """
            throw(ArgumentError(errmsg))
        end

        # Get the original state of the hardware performance counters.
        monitor = new{T}(
            cpus, 
            events, 
            false
        )

        finalizer(cleanup!, monitor)
        return monitor
    end
end

function program!(M::Monitor)
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

function Base.read(M::Monitor)
    # Get the old affinity for this 
    affinity = getaffinity()
    pid = getpid()
    results = map(M.cpus) do cpu
        # Set the affinity to this CPU
        setaffinity(pid, indexzero(cpu))

        # Read the events
        return map(1:length(M.events)) do i
            unsafe_rdpmc(indexzero(i))
        end
    end

    # Reset the affinity.
    setaffinity(affinity)
    return results
end

# function Base.read(M::Monitor)
#     return map(1:length(M.events)) do i
#         return map(M.cpus) do cpu
#             readcounter(cpu, i)
#         end
#     end
# end

function cleanup!(M::Monitor)
    for cpu in M.cpus
        for i in 1:length(M.events)
            program(cpu, i, EventSelectRegister())
        end
    end
    M.isrunning = false
    return nothing
end

function test()
    events = [
        EventSelectRegister(event = 0xD0, umask = 0x81, usr = true, os = true, en = true)
    ]

    cores = 1:20
    return Monitor(cores, events)
end
