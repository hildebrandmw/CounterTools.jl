# IMC Monitoring
mutable struct IMCMonitor{S, C, CH, N}
    # We have one entry in the outer tuple for each socket.
    # Within each socket, we have one entry for each controller.
    # Within each controller, we have one entry for each channel.
    pmus::NTuple{S, NTuple{C, NTuple{CH, UncorePMU{IMC}}}}
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
    pmus = ntuple(2) do socket
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
            end
        end
    end

    monitor = IMCMonitor(
        pmus,
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
mapleaves(f, X::Tuple...) = map((x...) -> mapleaves(f, x...), X...)
mapleaves(f, monitor::IMCMonitor) = mapleaves(f, monitor.pmus)
mapleaves(f, X::UncorePMU) = f(X)
mapleaves(f, X::CounterValue, Y::CounterValue) = f(X, Y)

program!(monitor::IMCMonitor) = mapleaves(x -> _program(x, monitor.events), monitor)
function _program(x::UncorePMU, events)
    for (i, evt) in enumerate(events)
        setcontrol!(x, i, evt)
    end
    return nothing
end

reset!(monitor::IMCMonitor) = mapleaves(reset!, monitor)
Base.read(monitor::IMCMonitor) = mapleaves(getallcounters, monitor)

counterdiff(a, b) = mapleaves(-, a, b)
aggregate(f, x) = reduce(f, tupleflatten(x))
aggregate(x) = aggregate((a,b) -> a .+ b, x)

# Rekduction magic to convert the nested tuple into just a flat tuple
tupleflatten(x::Tuple) = _tupleflatten(x...)
tupleflatten(x::NTuple{N,T}) where {N,T <: Integer} = (x,)
_tupleflatten(x::Tuple, y::Tuple...) = (tupleflatten(x)..., _tupleflatten(y...)...)
_tupleflatten() = ()
