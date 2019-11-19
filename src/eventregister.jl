
struct EventSelectRegister
    val::UInt64

    # Make a slightly more convenient keyword constructor.
    function EventSelectRegister(; kw...)
        x = zero(UInt64)
        fields = _fields()
        for (k, v) in pairs(kw)
            # Get the start and stop points of this bit field.
            start, stop = fields[k]

            # Mask the provided value to the requested number of bits.
            v = v & mask(0, stop - start)

            # Set the corresponding bits in `x`.
            # Since `x` is initialized to zero, we do not need to explicitly clear these bits.
            x |= (v << start)
        end
        E = new(x)
        return E
    end
end

_fields() = (
    event = (0, 7),
    umask = (8, 15),
    usr   = (16, 16),
    os    = (17, 17),
    e     = (18, 18),
    pc    = (19, 19),
    int   = (20, 20),
    en    = (22, 22),
    inv   = (23, 23),
    cmask = (24, 31),
)
_fields(name) = _fields()[name]

function Base.show(io::IO, E::EventSelectRegister)
    print(io, "Event Select Register: ")
    for k in keys(_fields())
        print(io, " $k=$(string(getproperty(E, k); base = 16))")
    end
    println(io)
    return nothing
end
hex(i::EventSelectRegister) = hex(i.val)

# Allow this to be written to an IO by forwarding to the wrapped value
Base.write(io::IO, E::EventSelectRegister) = write(io, value(E))

# We're going to be overloading the `getproperty` and `setproperty` methods for this type,
# so we need a way to get the full UInt64 out.
value(E::EventSelectRegister) = getfield(E, :val)

# For convenience purposes
function Base.getproperty(E::EventSelectRegister, name::Symbol)
    val = value(E)
    if name == :val
        return val
    else
        start, stop = _fields(name)
        return (val & mask(start, stop)) >> start
    end
end

