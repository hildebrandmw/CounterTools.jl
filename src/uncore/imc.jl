# IMC Monitoring
mutable struct IMCMonitor{T,N}
    # We have one entry in the outer tuple for each socket.
    # Within each socket, we have one entry for each controller.
    # Within each controller, we have one entry for each channel.
    sockets::Record{:socket,T}
    events::NTuple{N, UncoreSelectRegister}
end

function IMCMonitor(events::NTuple{N, UncoreSelectRegister}; program = true) where {N}
    # Check to see if we already have an active monitor.
    if IMC_RESERVATION[]
        error("An active IMC Monitor already exists!")
    end

    # Get the mapping from socket to bus
    socket_to_bus = findbusses()

    # For now, just hardcode number of sockets, memory channels, etc.
    sockets = ntuple(2) do socket
        # Memory Controllers
        return ntuple(2) do controller
            # Channels
            return ntuple(3) do channel
                # Get the path for this particular device
                bus = socket_to_bus[socket]
                device = SKYLAKE_IMC_REGISTERS[controller][channel].device
                fn = SKYLAKE_IMC_REGISTERS[controller][channel].fn

                # Construct a monitor
                handle = PCIHandle(bus, device, fn)
                pmu = UncorePMU{IMC}(handle)
                reset!(pmu)
                return pmu
            end |> Record{:channel}
        end |> Record{:imc}
    end |> Record{:socket}

    monitor = IMCMonitor(
        sockets,
        events,
    )
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

# Tool for recursively traveling over all the PMUs
# NOTE: This first definition is pretty much magic :)
mapleaves(f, monitor::IMCMonitor) = mapleaves(f, monitor.sockets)

program!(monitor::IMCMonitor) = mapleaves(x -> _program(x, monitor.events), monitor.sockets)
function _program(x::UncorePMU, events)
    for (i, evt) in enumerate(events)
        setcontrol!(x, i, evt)
    end
    return nothing
end

reset!(monitor::IMCMonitor) = mapleaves(reset!, monitor)
Base.read(monitor::IMCMonitor) = mapleaves(getallcounters, monitor)

