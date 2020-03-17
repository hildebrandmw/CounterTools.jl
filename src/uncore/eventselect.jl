const USR_FIELDS = (
    event = (0, 7),
    umask = (8, 15),
    reset = (17, 17),
    edge_detect = (18, 18),
    overflow_enable = (20, 20),
    en = (22, 22),
    invert = (23, 23),
    thresh = (24, 31),
)

struct UncoreSelectRegister
    val::UInt64
end

# This is an inner level constructor that takes the defaults from the outer level
# constructor and applies them to all keywords
function _UncoreSelectRegister(; kw...)
    x = zero(UInt64)
    fields = USR_FIELDS
    for (k, v) in pairs(kw)
        # Get the start and stop points of this bit field.
        start, stop = fields[k]

        # Mask the provided value to the requested number of bits.
        v = v & mask(0, stop - start)

        # Set the corresponding bits in `x`.
        # Since `x` is initialized to zero, we do not need to explicitly clear these bits.
        x |= (v << start)
    end
    E = UncoreSelectRegister(x)
    return E
end

# Apply defaults
function UncoreSelectRegister(; en = true, kw...)
    _UncoreSelectRegister(; en = en, kw...)
end

function Base.show(io::IO, E::UncoreSelectRegister)
    print(io, "Uncore Select Register: ")
    for k in keys(USR_FIELDS)
        print(io, " $k=$(string(getproperty(E, k); base = 16))")
    end
    println(io)
    return nothing
end
hex(i::UncoreSelectRegister) = hex(i.val)

# Allow this to be written to an IO by forwarding to the wrapped value
Base.write(io::IO, E::UncoreSelectRegister) = write(io, value(E))
Base.convert(::Type{UInt32}, E::UncoreSelectRegister) = convert(UInt32, value(E))

# We're going to be overloading the `getproperty` methods for this type,
# so we need a way to get the full UInt64 out.
value(E::UncoreSelectRegister) = getfield(E, :val)

# For convenience purposes
function Base.getproperty(E::UncoreSelectRegister, name::Symbol)
    val = value(E)
    if name == :val
        return val
    else
        start, stop = USR_FIELDS[name]
        return (val & mask(start, stop)) >> start
    end
end

