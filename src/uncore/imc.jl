# IMC Monitoring
mutable struct IMCMonitor{T,N}
    # We have one entry in the outer tuple for each socket.
    # Within each socket, we have one entry for each controller.
    # Within each controller, we have one entry for each channel.
    imcs::Record{:socket,T}
    events::NTuple{N, UncoreSelectRegister}
end

"""
    IMCMonitor(events::NTuple{N, UncoreSelectRegister}, socket; [program])
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
    )

    @show typeof(monitor)
    IMC_RESERVATION[] = true

    # Clean up after ourselves
    finalizer(monitor) do x
        reset!(x)
        IMC_RESERVATION[] = false
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
Base.read(monitor::IMCMonitor) = mapleaves(getallcounters, monitor)

