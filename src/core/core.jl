# Code for dealing with Core level counters.
include("lowlevel.jl")
include("utils.jl")

# This is the high level API for core monitoring
mutable struct CoreMonitor{T,N,U} <: AbstractMonitor
    # Collection of CPUs for which to collect data.
    cpus::T

    # The events that we are collecting
    events::NTuple{N, CoreSelectRegister}
    fixed_events::U

    # For cleaning up after ourselves
    initial_state::CounterState
    initial_affinity::PtrWrap
    isrunning::Bool
end

"""
    CoreMonitor(events, cpus; program = true)

Construct a `CoreMonitor` monitoring `events` on `cpus`.
Arguments `events` should be a `Tuple` of [`CounterTools.CoreSelectRegister`](@ref) and
`cpus` is any iterable collection of CPU indices.

If `program == true`, then also program the performance counters to on each CPU.
"""
function CoreMonitor(
        events::NTuple{N, CoreSelectRegister},
        cpus::T;
        fixed_events = nothing,
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

    # Validate the fixed events
    if fixed_events !== nothing
        if !isa(fixed_events, NTuple{U, FixedCounter} where {U})
            errmsg = """
                Keyword argument `fixed_events` must either be `nothing` or a tuple of
                `FixedCounter` enums.
            """
            throw(ArgumentError(errmsg))
        end
    else
        fixed_events = ()
    end

    # Build up the initial values list to save this for later.
    initial_state = CounterState(;cpus = cpus)
    initial_affinity = getaffinity()

    # Get the original state of the hardware performance counters.
    monitor = CoreMonitor{T,N,typeof(fixed_events)}(
        cpus,
        events,
        fixed_events,
        initial_state,
        initial_affinity,
        false
    )

    finalizer(reset!, monitor)
    program && program!(monitor)
    return monitor
end

function program(cpu, counter, reg::CoreSelectRegister)
    writemsr(cpu, EVENT_SELECT_MSRS[counter], reg)
    return nothing
end

# When programming fixed counters, we need to set the enable bits in IA32_FIXED_CTR_CTRL_MSR
function program(cpu, event::FixedCounter)
    bitmask = UInt(0x3) << (4 * Int(event))
    v = readmsr(cpu, IA32_FIXED_CTR_CTRL_MSR)
    writemsr(cpu, IA32_FIXED_CTR_CTRL_MSR, v | bitmask)
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

        for event in M.fixed_events
            program(cpu, event)
        end
    end
    M.isrunning = true
    return nothing
end

function Base.read(M::CoreMonitor{T, N}) where {T, N}
    pid = getpid()
    results = map(M.cpus) do cpu
        # Set the affinity to this CPU
        setaffinity(pid, cpu)

        # Read fixed and programmable events.
        fixed = map(unsafe_rdpmc, M.fixed_events)
        programmable = ntuple(i -> unsafe_rdpmc(i), Val{N}())

        # Return all counter values.
        return Record{:cpu}((fixed..., programmable...))
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

