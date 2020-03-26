# Record the current counter state.
#
# Useful for recording what the state of the CPU counters is before running any experiments
# so we can restore the state when we are dont.
struct CounterState
    # Maps a tuple (CPU,Counter) to the raw bits of the counter state.
    state::Dict{IndexZero{Int},Vector{Int}}
end

function CounterState(; cpus = 1:numcpus(), counters = 1:numcounters())
    state = Dict{IndexZero{Int},Vector{Int}}()

    # Collect the counter states for all cpus
    ncounters = numcounters()
    buffer = Vector{UInt8}(undef, sizeof(Int))
    for cpu in cpus
        vec = Int64[]
        handle = Handle(msrpath(cpu))
        for i in 1:numcounters()
            register = EVENT_SELECT_MSRS[i]
            push!(vec, unsafe_read(handle, Int, register; buffer = buffer))
        end
        close(handle)
        state[indexzero(cpu)] = vec
    end

    return CounterState(state)
end

"""
    restore!(cs::CounterState)

Restore the current CPU to the state recorded in `cs`.
"""
function restore!(CS::CounterState)
    state = CS.state
    registers = EVENT_SELECT_MSRS[1:numcounters()]

    for (cpu, values) in state
        writemsr.(Ref(cpu), registers, values)
    end
    return nothing
end
