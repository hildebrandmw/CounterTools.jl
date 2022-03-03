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
    IMCMonitor(events, socket; [program = true, finalize = true])

Monitor the Integrated Memory Controller (IMC) for `events` on a **single**
selected CPU `socket`. This can gather information such as number of DRAM read and write
operations.  Argument `event` should be a `Tuple` of [`CounterTools.UncoreSelectRegister`](@ref)
and `socket` should be either an `Integer` or `IndexZero`.

If `finalize = true` is passed, a finalizer will be attached to the `IMCMonitor` to clean
up the hardware counter's state.
"""
function IMCMonitor(
        events::NTuple{N, UncoreSelectRegister},
        socket;
        program = true,
        finalize = true,
    ) where {N}
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
    finalize && finalizer(cleanup, monitor)

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
    if !monitor.cleaned
        # Close any open PCI file handles
        reset!(monitor)
        IMC_RESERVATION[] = false
        mapleaves(close, monitor)
        monitor.cleaned = true
    end
    return nothing
end

#####
##### IceLake Monitor
#####

# MMIO_BASE found at Bus U0, Device 0, Function 1, offset D0h.
const ICX_IMC_MMIO_BASE_OFFSET = 0xd0
const ICX_IMC_MMIO_BASE_MASK = 0x1FFFFFFF

# MEM0_BAR found at Bus U0, Device 0, Function 1, offset D8h.
const ICX_IMC_MMIO_MEM0_OFFSET = 0xd8
const ICX_IMC_MMIO_MEM_STRIDE = 0x04
const ICX_IMC_MMIO_MEM_MASK = 0x7FF

# Each IMC has two channels. But there is addressing for three. Need to
# determine which two channels are active on the system.
# The offset starts from 0x22800 with stride 0x4000
#
const ICX_IMC_MMIO_CHN_OFFSET = 0x22800
const ICX_IMC_MMIO_CHN_STRIDE = 0x4000
# /* IMC MMIO size*/
const ICX_IMC_MMIO_SIZE = 0x4000

const SERVER_UBOX0_REGISTER_DEV_ADDR = 0
const SERVER_UBOX0_REGISTER_FUNC_ADDR = 1


struct IMCMonitorICXFixed{T} <: AbstractMonitor
    imcs::Record{:socket,T}
end

function Base.show(io::IO, monitor::IMCMonitorICXFixed{T}) where {T}
    print(io, "IMCMonitorICXFixed{", T, "}()")
end

function IMCMonitorICXFixed(socket::IndexZero)
    # Check to see if we already have an active monitor.
    if IMC_RESERVATION[]
        error("An active IMC Monitor already exists!")
    end

    socket_to_bus = findbusses(;
        device = SERVER_UBOX0_REGISTER_DEV_ADDR,
        fn = SERVER_UBOX0_REGISTER_FUNC_ADDR,
        device_ids = (0x3451,),
    )
    bus = socket_to_bus[socket]

    handle = Handle(bus, SERVER_UBOX0_REGISTER_DEV_ADDR, SERVER_UBOX0_REGISTER_FUNC_ADDR)
    mmio_base = read(handle, UInt32, IndexZero(ICX_IMC_MMIO_BASE_OFFSET))
    imcs = ntuple(4) do controller
        position = IndexZero(ICX_IMC_MMIO_MEM0_OFFSET + ICX_IMC_MMIO_MEM_STRIDE * (controller - 1))
        offset = read(handle, UInt32, position)
        address = |(
            (mmio_base & ICX_IMC_MMIO_BASE_MASK) << 23,
            (offset & ICX_IMC_MMIO_MEM_MASK) << 12,
        )
        mmio = MMIO(IndexZero(address), ICX_IMC_MMIO_SIZE)
        pmu = IMCUncoreICX(mmio)
        return Record{:channel}((pmu,))
    end |> Record{:socket}

    return IMCMonitorICXFixed(imcs)
end

# Implementation
mapleaves(f::F, monitor::IMCMonitorICXFixed) where {F} = mapleaves(f, monitor.imcs)
function Base.read(monitor::IMCMonitorICXFixed)
    return mapleaves(getallcounters, monitor)
end
