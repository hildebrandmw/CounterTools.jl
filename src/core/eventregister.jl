const CSR_FIELDS = (
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

struct CoreSelectRegister
    val::UInt64
end

# This is an inner level constructor that takes the defaults from the outer level
# constructor and applies them to all keywords
function _CoreSelectRegister(; kw...)
    x = zero(UInt64)
    fields = CSR_FIELDS
    for (k, v) in pairs(kw)
        # Get the start and stop points of this bit field.
        start, stop = fields[k]

        # Mask the provided value to the requested number of bits.
        v = v & mask(0, stop - start)

        # Set the corresponding bits in `x`.
        # Since `x` is initialized to zero, we do not need to explicitly clear these bits.
        x |= (v << start)
    end
    E = CoreSelectRegister(x)
    return E
end

# Apply defaults
function CoreSelectRegister(; usr = true, os = true, en = true, kw...)
    _CoreSelectRegister(; usr = usr, os = os, en = en, kw...)
end

function Base.show(io::IO, E::CoreSelectRegister)
    print(io, "Event Select Register: ")
    for k in keys(ESR_FIELDS)
        print(io, " $k=$(string(getproperty(E, k); base = 16))")
    end
    println(io)
    return nothing
end
hex(i::CoreSelectRegister) = hex(i.val)

# Allow this to be written to an IO by forwarding to the wrapped value
Base.write(io::IO, E::CoreSelectRegister) = write(io, value(E))

# We're going to be overloading the `getproperty` methods for this type,
# so we need a way to get the full UInt64 out.
value(E::CoreSelectRegister) = getfield(E, :val)

# For convenience purposes
function Base.getproperty(E::CoreSelectRegister, name::Symbol)
    val = value(E)
    if name == :val
        return val
    else
        start, stop = ESR_FIELDS[name]
        return (val & mask(start, stop)) >> start
    end
end

