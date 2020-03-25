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
Base.write(P::Handle, v) = write(P.fd, v)
Base.seek(P::Handle, offset) = seek(P.fd, offset)

# Wrapping the `pread` calls is MUCH faster because it only requires a single
# transition into kernel code.
function Base.unsafe_read(
        P::Handle,
        ::Type{T},
        offset;
        buffer = Vector{UInt8}(undef, sizeof(T))
    ) where {T}

    # Make a direct `pread` call
    nb = ccall(
        :pread,
        Csize_t,
        (Cint, Ptr{Cvoid}, Csize_t, Cint),
        fd(P.fd),
        buffer,
        sizeof(T),
        offset
    )

    return first(reinterpret(T, buffer))
end

