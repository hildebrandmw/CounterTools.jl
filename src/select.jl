# Types for managing event selection
abstract type AbstractEventSelect end
struct CoreSelect <: AbstractEventSelect end
struct UncoreSelect <: AbstractEventSelect end

# Bit mask ranges
function fields(::Type{CoreSelect})
    nt = (
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
    return nt
end
name(::Type{CoreSelect}) = "Core Event Select Register"
defaults(::Type{CoreSelect}) = (usr = true, os = true, en = true)

function fields(::Type{UncoreSelect})
    nt = (
        event = (0, 7),
        umask = (8, 15),
        reset = (17, 17),
        edge_detect = (18, 18),
        overflow_enable = (20, 20),
        en = (22, 22),
        invert = (23, 23),
        thresh = (24, 31),
    )
    return nt
end
name(::Type{UncoreSelect}) = "Uncore Event Select Register"
defaults(::Type{UncoreSelect}) = (en = true,)

#####
##### Select Register
#####
struct EventRegister{T <: AbstractEventSelect}
    val::UInt64
end

# Main entry point
function EventRegister{T}(kw::NamedTuple) where {T <: AbstractEventSelect}
    # Apply defaults to the provided keywords.
    kw = merge(defaults(T), kw)
    val = zero(UInt64)
    fieldpairs = fields(T)
    for (k, v) in pairs(kw)
        # Get the start and stop points of this bit field.
        start, stop = fieldpairs[k]

        # Mask the provided value to the requested number of bits.
        v = v & mask(0, stop - start)

        # Set the corresponding bits in `x`.
        # Since `x` is initialized to zero, we do not need to explicitly clear these bits.
        val |= (v << start)
    end
    register = EventRegister{T}(val)
    return register
end
# Forward keyword arguments into a named tuple
EventRegister{T}(; kw...) where {T} = EventRegister{T}((;kw...))

function Base.show(io::IO, reg::EventRegister{T}) where {T}
    print(io, name(T), ": ")
    for k in keys(fields(T))
        print(io, " $k=$(string(reg[k]; base = 16))")
    end
    println(io)
    return nothing
end
hex(i::EventRegister) = hex(i.val)

# Allow this to be written to an IO by forwarding to the wrapped value
Base.write(io::IO, reg::EventRegister) = write(io, value(reg))
Base.convert(::Type{T}, reg::EventRegister) where {T <: Integer} = convert(T, value(reg))

value(reg::EventRegister) = reg.val

# For convenience purposes
function Base.getindex(reg::EventRegister{T}, name::Symbol) where {T}
    start, stop = fields(T)[name]
    return (value(reg) & mask(start, stop)) >> start
end

#####
##### Constant Aliases
#####

const CoreSelectRegister = EventRegister{CoreSelect}
const UncoreSelectRegister = EventRegister{UncoreSelect}

