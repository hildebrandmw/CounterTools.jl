# IMC Monitoring
mutable struct IMCMonitor{T,N} <: AbstractMonitor
    # We have one entry in the outer tuple for each socket.
    # Within each socket, we have one entry for each controller.
    # Within each controller, we have one entry for each channel.
    imcs::Record{:socket,T}
    events::NTuple{N, UncoreSelectRegister}
    cleaned::Bool
end

"""
    IMCMonitor(events, socket; [program = true])

Monitor the Integrated Memory Controller (IMC) for `events` on a **single**
selected CPU `socket`. This can gather information such as number of DRAM read and write
operations.  Argument `event` should be a `Tuple` of [`CounterTools.UncoreSelectRegister`](@ref)
and `socket` should be either an `Integer` or `IndexZero`.
"""
function IMCMonitor(events::NTuple{N, UncoreSelectRegister}, socket; program = true) where {N}

    # Check to see if we already have an active monitor.
    if IMC_RESERVATION[]
        error("An active IMC Monitor already exists!")
    end

    # Get the mapping from socket to bus
    socket_to_bus = findbusses()

    # Memory Controllers
    imcs = ntuple(2) do controller
        # Channels
        return ntuple(3) do channel
            # Get the path for this particular device
            bus = socket_to_bus[socket]
            device = SKYLAKE_IMC_REGISTERS[controller][channel].device
            fn = SKYLAKE_IMC_REGISTERS[controller][channel].fn

            # Construct a monitor
            handle = Handle(bus, device, fn)
            pmu = IMCUncorePMU(handle)
            reset!(pmu)
            return Record{:channel}((pmu,))
        end |> Record{:imc}
    end |> Record{:socket}

    monitor = IMCMonitor(
        imcs,
        events,
        false,
    )

    IMC_RESERVATION[] = true

    # Clean up after ourselves
    finalizer(monitor) do x
        x.cleaned || cleanup(monitor)
    end

    program && program!(monitor)
    return monitor
end

const IMC_RESERVATION = Ref{Bool}(false)

# Extend `mapleaves` to broadcast across the IMCMonitor
mapleaves(f, monitor::IMCMonitor) = mapleaves(f, monitor.imcs)
program!(monitor::IMCMonitor) = mapleaves(x -> program(x, monitor.events), monitor)
function program(x::IMCUncorePMU, events)
    for (i, evt) in enumerate(events)
        setcontrol!(x, i, evt)
    end
    enable!(x)
    return nothing
end

reset!(monitor::IMCMonitor) = mapleaves(reset!, monitor)
function Base.read(monitor::IMCMonitor{T,N}) where {T,N}
    monitor.cleaned && error("Trying to measure a cleaned IMC Monitor")
    return mapleaves(getallcounters, monitor)
end

function cleanup(monitor::IMCMonitor)
    reset!(monitor)
    IMC_RESERVATION[] = false
    monitor.cleaned = true
    return nothing
end

