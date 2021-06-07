# Record the current counter state.
#
# Useful for recording what the state of the CPU counters is before running any experiments
# so we can restore the state when we are dont.
struct CoreMSRProgramming
    fixed::Int
    programmable::Vector{Int}
end

struct CounterState
    # Maps a CPU to the raw bits of the counter state.
    state::Dict{IndexZero{Int}, CoreMSRProgramming}
end

function CounterState(; cpus = 1:numcpus(), counters = 1:numcounters())
    state = Dict{IndexZero{Int},CoreMSRProgramming}()

    # Collect the counter states for all cpus
    ncounters = numcounters()
    buffer = Vector{UInt8}(undef, sizeof(Int))

    for cpu in cpus

        # Open the MSR forlder for this CPU
        handle = Handle(msrpath(cpu))

        # Read the fixed-counter state
        fixed = unsafe_read(handle, Int, IA32_FIXED_CTR_CTRL_MSR; buffer = buffer)

        # Read the programmable counter states
        programmable = Int64[]
        for i in 1:numcounters()
            register = EVENT_SELECT_MSRS[i]
            push!(programmable, unsafe_read(handle, Int, register; buffer = buffer))
        end
        close(handle)
        state[indexzero(cpu)] = CoreMSRProgramming(fixed, programmable)
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

    for (cpu, programming) in state
        writemsr(cpu, IA32_FIXED_CTR_CTRL_MSR, programming.fixed)
        writemsr.(Ref(cpu), registers, programming.programmable)
    end
    return nothing
end
