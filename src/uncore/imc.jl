# IMC Monitoring
mutable struct IMCMonitor{S, C, CH, N}
    # We have one entry in the outer tuple for each socket.
    # Within each socket, we have one entry for each controller.
    # Within each controller, we have one entry for each channel.
    pmus::NTuple{S, NTuple{C, NTuple{CH, UncorePMU{IMC}}}}
    events::NTuple{N, UncoreSelectRegister}
end

function IMCMonitor(events::NTuple{N, UncoreSelectRegister}; program = true) where {N}
    # Get the mapping from socket to bus
    socket_to_bus = findbusses()

    # For now, just hardcode number of sockets, memory channels, etc.
    pmus = ntuple(2) do socket
        # Memory Controllers
        return ntuple(2) do controller
            # Channels
            return ntuple(3) do channel
                # Get the path for this particular device
                bus = socket_to_bus[socket]
                device = SKYLAKE_IMC_REGISTES[controller][channel].device
                fn = SKYLAKE_IMC_REGISTES[controller][channel].fn

                # Construct a monitor
                handle = PCIHandle(bus, device, fn)
                pmu = UncorePMU{IMC}(handle)
                reset!(pmu)
                return pmu
            end
        end
    end

    monitor = IMCMonitor(
        pmus,
        events,
    )

    # Clean up after ourselves
    finalizer(reset!, monitor)

    program && program!(monitor)
    return monitor
end

# Tool for recursively traveling over all the PMUs
mapleaves(f, monitor::IMCMonitor) = mapleaves(f, monitor.pmus)
mapleaves(f, X::Tuple) = map(x -> mapleaves(f, x), X)
mapleaves(f, X::UncorePMU) = f(X)

program!(monitor::IMCMonitor) = mapleaves(x -> _program(x, monitor.events), monitor)
function _program(x::UncorePMU, events)
    for (i, evt) in enumerate(events)
        setcontrol!(x, i, evt)
    end
    return nothing
end

reset!(monitor::IMCMonitor) = mapleaves(reset!, monitor)
Base.read(monitor::IMCMonitor) = mapleaves(getallcounters, monitor)
