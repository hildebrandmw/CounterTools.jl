mutable struct PCIHandle
    fd::IOStream

    # Open the os file - attach a finalizer so the file is appropriately closed.
    function PCIHandle(str::String)
        handle = new(open(str; read = true, write = true))
        finalizer(close, handle)
        return handle
    end
end
Base.close(P::PCIHandle) = close(P.fd)

# Construct the PCIHandle from a group, bus, device, and offset
#
# This is largely reverse engineered from `pci.cpp` from `https://github.com/opcm/pcm`
PCIHandle(bus, device, fn) = PCIHandle(pcipath(bus, device, fn))
function pcipath(bus, device, fn)
    bus_str    = string(bus; base = 16, pad = 2)
    device_str = string(bus; base = 16, pad = 2)
    fn_str     = string(fn; base = 16, pad = 1)
    path = joinpath(
        "/proc/bus/pci", 
        bus_str, 
        "$device_str.$fn_str"
    )

    return path
end

function Base.read(P::PCIHandle, offset, ::Type{T}) where {T <: Integer}
    # Seek to the correct location in the file.
    seek(P.fd, offset) 
    return read(P.fd, T)
end

# Tools for dealing with PCI
const DRV_IS_PCI_VENDOR_ID_INTEL = 0x8086
const VENDOR_ID_MASK = 0x0000_FFFF
const DEVICE_ID_MASK = 0xFFFF_0000
const DVICE_ID_BITSHIFT = 16
const PCI_ENABLE = 0x8000_0000

pciaddr(bus, dev, fun, off) = PCI_ENABLE | 
                              ((bus & 0xFF) << 16) | 
                              ((dev & 0x1F) << 11) | 
                              ((fun & 0x07) << 8) | 
                              (off & 0xFF)

const UNC_SOCKETID_UBOX_LNID_OFFSET = 0xC0
const UNC_SOCKETID_UBOX_GID_OFFSET = 0xD4
