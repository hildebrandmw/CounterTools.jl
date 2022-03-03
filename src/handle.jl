# PCI Utility Functions
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

function pcipath(group, bus, device, fn)
    iszzero(group) && return pcipath(bus, device, fn)
    error("Cannot deal with non-zero PCI Groups yet")
end

#####
##### PCI Handles
#####

abstract type AbstractPCIHandle end
mutable struct Handle <: AbstractPCIHandle
    fd::IOStream

    # Open the os file - attach a finalizer so the file is appropriately closed.
    function Handle(str::String; read = true, write = true)
        handle = new(open(str; read = read, write = write))
        finalizer(close, handle)
        return handle
    end
end
Base.close(P::Handle) = close(P.fd)

# Construct the Handle from a group, bus, device, and offset
#
# This is largely reverse engineered from `pci.cpp` from `https://github.com/opcm/pcm`
Handle(args::Integer...) = Handle(pcipath(args...))
#Base.read(P::Handle, ::Type{T}) where {T <: Integer} = Base.read(P.fd, T)
# Base.write(P::Handle, v) = write(P.fd, v)
Base.seek(P::Handle, offset::IndexZero) = seek(P.fd, value(offset))

# function Base.read(h::Handle, ::Type{T}, offset::IndexZero) where {T <: Integer}
#     return Base.unsafe_read(h, T, offset)
# end

function Base.write(h::Handle, v, offset::IndexZero)
    seek(h, offset)
    return write(h.fd, v)
end

# Wrapping the `pread` calls is MUCH faster because it only requires a single
# transition into kernel code.
function Base.read(P::Handle, ::Type{T}, offset::IndexZero) where {T}
    # Make a direct `pread` call
    object = Ref{T}()
    nb = ccall(
        :pread,
        Csize_t,
        (Cint, Ptr{Cvoid}, Csize_t, Cint),
        fd(P.fd),
        object,
        sizeof(T),
        value(offset)
    )

    return object[]
end

