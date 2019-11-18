mutable struct EventSelectRegister
    val::UInt64

    # Make a slightly more convenient keyword constructor.
    function EventSelectRegister(; kw...)
        E = new(zero(UInt64))
        for (k, v) in pairs(kw)
            setproperty!(E, k, v)
        end
        return E
    end
end

function Base.show(io::IO, E::EventSelectRegister)
    print(io, "Event Select Register: ")
    for k in keys(entries(E))
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

entries(::EventSelectRegister) = (
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

# For convenience purposes
function Base.getproperty(E::EventSelectRegister, name::Symbol)
    val = value(E)
    if name == :val
        return val
    else
        start, stop = entries(E)[name]
        return (val & mask(start, stop)) >> start
    end
end

function Base.setproperty!(E::EventSelectRegister, name::Symbol, x::Integer)
    val = value(E)
    if name == :val
        setfield!(E, :val, x)
    else
        start, stop = entries(E)[name]
        # Clear the original bits
        val = val & ~mask(start, stop)
        # Mask the setting value
        x = x & mask(0, stop - start) 
        # Set these bits
        val = val | (x << start)
        setfield!(E, :val, val)
    end
    return x
end
