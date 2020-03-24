mutable struct Handle
    fd::IOStream

    # Open the os file - attach a finalizer so the file is appropriately closed.
    function Handle(str::String)
        handle = new(open(str; read = true, write = true))
        finalizer(close, handle)
        return handle
    end
end
Base.close(P::Handle) = close(P.fd)

# Construct the Handle from a group, bus, device, and offset
#
# This is largely reverse engineered from `pci.cpp` from `https://github.com/opcm/pcm`
Handle(bus, device, fn) = Handle(pcipath(bus, device, fn))
function pcipath(bus, device, fn)
    bus_str    = string(bus; base = 16, pad = 2)
    device_str = string(device; base = 16, pad = 2)
    fn_str     = string(fn; base = 16, pad = 1)
    path = joinpath(
        "/proc/bus/pci",
        bus_str,
        "$device_str.$fn_str"
    )

    return path
end

Base.read(P::Handle, ::Type{T}) where {T <: Integer} = read(P.fd, T)
Base.read(P::Handle, nb::Integer) = read(P.fd, nb)
Base.readbytes!(P::Handle, x...; kw...) = readbytes!(P.fd, x...; kw...)
Base.write(P::Handle, v) = write(P.fd, v)
Base.seek(P::Handle, offset) = seek(P.fd, offset)

# Tools for dealing with PCI
const DRV_IS_PCI_VENDOR_ID_INTEL = 0x8086
const VENDOR_ID_MASK = 0x0000_FFFF
const DEVICE_ID_MASK = 0xFFFF_0000
const DEVICE_ID_BITSHIFT = 16
const PCI_ENABLE = 0x8000_0000

# These are found in uncore performance monitoring guide
# Under: "Uncore Performance Monitoring State in PCICFG space"
# Device and Function IDS for Skylake based IMCs
const SKYLAKE_IMC_REGISTERS = (
    # IMC 0 - Channels 0, 1, 2
    ((device = 10, fn = 2), (device = 10, fn = 6), (device = 11, fn = 2)),
    # IMC 1 - Channels 0, 1, 2
    ((device = 12, fn = 2), (device = 12, fn = 6), (device = 13, fn = 2)),
)

const IMC_DEVICE_IDS = (0x2042, 0x2046, 0x204A)

# This is taken from the PCM code
#
# TODO: Dynamically find number of sockets
#
# The general idea is that we know the device and function numbers of IMC devices
# Furthermore, we know the device IDS
#
# So, we enumerate all of the PCI busses until
#   1. We find a valid path
#   2. We read the vendor ID and device ID from the device
#       - Vendor ID must match Intel (0x8086)
#       - Device ID must match one of the iMC device IDS
#
# When we've found this, we've found the bus for the socket.
#
# NOTE: I'm assuming that lower bus numbers correspond to lower sockets.
# This appears consistent with what's happening in PCM.
#
# NOTE: There's a lot of business with PCI group numbers.
# I'm ignoring that for now because we only have group 0 on our system.
#
# TODO: We can abstract this for different architectures using dispatch, but I'm not
# too worried about that at the moment.
function findbusses()
    socket_to_bus = UInt[]

    bus_numbers = 0:255
    device = first(first(SKYLAKE_IMC_REGISTERS)).device
    fn = first(first(SKYLAKE_IMC_REGISTERS)).fn

    for bus in bus_numbers
        # Check to see if the path exists
        path = pcipath(bus, device, fn)
        ispath(path) || continue

        pci = Handle(path)

        # Read the first value from the bus - compare against vendor
        seek(pci, 0)
        value = read(pci, UInt32)
        vendor_id = value & VENDOR_ID_MASK
        device_id = (value & DEVICE_ID_MASK) >> DEVICE_ID_BITSHIFT

        # Check if this is run by Intel
        vendor_id == DRV_IS_PCI_VENDOR_ID_INTEL || continue
        in(device_id, IMC_DEVICE_IDS) || continue
        push!(socket_to_bus, bus)

        close(pci)
    end

    return socket_to_bus
end
