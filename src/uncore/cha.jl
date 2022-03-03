# CHA Monitoring
mutable struct CHAMonitor{T,N} <: AbstractMonitor
    # Collection of CHAUncorePMU
    pmus::Record{:CHA,Vector{T}}
    cha_numbers::Vector{IndexZero{Int}}

    # The CPU that we're
    # using for the MSR reading.
    cpu::IndexZero{Int}
    events::NTuple{N, UncoreSelectRegister}

    # The filters for the CHA events
    filter0::CHAFilter0
    filter1::CHAFilter1
end

"""
    CHAMonitor(events, socket, cpu; [program = true], [filter0], [filter1])

Monitor the Caching Home Agent counters for `events` on a **single** selected CPU `socket`.
This can gather information such as number of L3 hits and misses.
Argument `event` should be a `Tuple` of [`CounterTools.UncoreSelectRegister`](@ref) and
`socket` should be either an `Integer` or `IndexZero`.
Further, `cpu` is the CPU that will be actually reading the counters.
For best performance, `cpu` should be located on `socket`.

Filters
=======

The CHA Performance Monitoring Units allow counters to be filtered in various ways such
as issuing Core or Thread ID, request opcode etc.

These can be passed via the `filter0` and `filter1` keyword arguments and correspond to the
CHA filters 0 and 1 repectively.

Note: `filter0` should be a [`CounterTools.CHAFilter0`](@ref) and `filter1` should be a
[`CounterTools.CHAFilter1`](@ref).
"""
function CHAMonitor(
        events,
        socket,
        cpu;
        program = true,
        filter0::CHAFilter0 = CHAFilter0(),
        filter1::CHAFilter1 = CHAFilter1(),
    )

    # Convert the cpu into an IndexZero
    cpu = indexzero(cpu)

    # I used to look at just a subset of the available CHAs, but that seems to misconfigure
    # the last counters.
    #
    # Instead, just running them all seems to do the trick as the kernel/CPU simply
    # returns "0" for reads to MSRS that are out of range.
    cha_numbers = IndexZero.(0:27)

    # Now, we open up a MSR file to the given CPU
    handle = Handle(msrpath(cpu))

    # Construct the CHA PMUs
    #
    # Make a single buffer for all CHA PMUs
    buffer = zeros(UInt8, numbytes(CHA()))
    pmus = map(cha_numbers) do cha
        pmu = CHAUncorePMU(handle, cha, buffer)
        reset!(pmu)
        return pmu
    end |> Record{:CHA}

    monitor = CHAMonitor(
        pmus,
        cha_numbers,
        cpu,
        events,
        filter0,
        filter1
    )

    finalizer(reset!, monitor)
    program && program!(monitor)
    return monitor
end

mapleaves(f, monitor::CHAMonitor) = mapleaves(f, monitor.pmus)

function program!(monitor::CHAMonitor)
    f = x -> program(x, monitor.events, monitor.filter0, monitor.filter1)
    mapleaves(f, monitor)
    return nothing
end

function program(x::CHAUncorePMU, events, filter0, filter1)
    # Apply the filters
    setextra!(x, IndexZero(0), filter0)
    setextra!(x, IndexZero(1), filter1)

    # Program the counters
    for (i, evt) in enumerate(events)
        setcontrol!(x, i, evt)
    end

    # Enable the counters
    enable!(x)
end

reset!(monitor::CHAMonitor) = mapleaves(reset!, monitor)
Base.read(monitor::CHAMonitor) = mapleaves(getallcounters, monitor)

# TODO: Hack for now - find busses by socket for the CAPID 6 register,
# which provides a bitmask for what CHAs are available.
#
# NOTE: The documentation implies that there is a correlation between bit locations
# and the CHA numbers that are available.
#
# However, direct testing and the note found:
# https://lore.kernel.org/patchwork/patch/893681/
#
# Implies that only the number of set bits counts.
function cha_masks(socket = nothing)
    bus_numbers = 0:255
    device = 30
    fn = 3

    socket_to_mask = UInt32[]
    for bus in bus_numbers
        path = pcipath(bus, device, fn)
        ispath(path) || continue

        pci = Handle(path)
        #  check that the vendor is Intel
        #seek(pci, 0)
        (read(pci, UInt32, IndexZero(0)) & VENDOR_ID_MASK) == DRV_IS_PCI_VENDOR_ID_INTEL || continue

        #seek(pci, 0x9C)
        value = read(pci, UInt32, IndexZero(0x9C))
        push!(socket_to_number, value)
    end
    return isnothing(socket) ? socket_to_number : socket_to_number[socket]
end

