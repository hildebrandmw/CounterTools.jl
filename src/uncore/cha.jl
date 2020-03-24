# CHA Monitoring
mutable struct CHAMonitor{T,N}
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

function CHAMonitor(
        cpu,
        socket,
        events;
        program = true,
        filter0 = CHAFilter0(),
        filter1 = CHAFilter1(),
    )

    # Convert the cpu into an IndexZero
    cpu = indexzero(cpu)

    # Get the CHA number masks for this socket.
    # Convert this into a vector.
    cha_mask_for_socket = cha_masks()[socket]
    cha_numbers = [IndexZero(i) for i in 0:27 if isbitset(cha_mask_for_socket, i)]

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
function cha_masks()
    bus_numbers = 0:255
    device = 30
    fn = 3

    masks = UInt32[]
    for bus in bus_numbers
        path = pcipath(bus, device, fn)
        ispath(path) || continue

        pci = Handle(path)
        #  check that the vendor is Intel
        seek(pci, 0)
        (read(pci, UInt32) & VENDOR_ID_MASK) == DRV_IS_PCI_VENDOR_ID_INTEL || continue

        seek(pci, 0x9C)
        value = read(pci, UInt32)
        push!(masks, value)
    end
    return masks
end

