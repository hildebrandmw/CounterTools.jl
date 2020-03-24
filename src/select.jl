# Types for managing event selection
abstract type BitField end

fields(x::BitField)     = fields(typeof(x))
name(x::BitField)       = name(typeof(x))
defaults(x::BitField)   = defaults(typeof(x))
value(x::BitField)      = x.val

(::Type{T})(;kw...) where {T <: BitField} = construct(T, (;kw...))

# Main entry point
function construct(::Type{T}, kw::NamedTuple) where {T <: BitField}
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
    return T(val)
end

function Base.show(io::IO, reg::BitField)
    print(io, name(reg), ": ")
    for k in keys(fields(reg))
        print(io, " $k=$(string(reg[k]; base = 16))")
    end
    println(io)
    return nothing
end
hex(i::BitField) = hex(value(i))

# Allow this to be written to an IO by forwarding to the wrapped value
Base.write(io::IO, reg::BitField) = write(io, value(reg))
Base.convert(::Type{T}, reg::BitField) where {T <: Integer} = convert(T, value(reg))

# For convenience purposes
function Base.getindex(reg::BitField, name::Symbol)
    start, stop = fields(reg)[name]
    return (value(reg) & mask(start, stop)) >> start
end

### Core Event Select
struct CoreSelectRegister <: BitField
    val::UInt64
end

function fields(::Type{CoreSelectRegister})
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
name(::Type{CoreSelectRegister}) = "Core Event Select Register"
defaults(::Type{CoreSelectRegister}) = (usr = true, os = true, en = true)

### Uncore Select
struct UncoreSelectRegister <: BitField
    val::UInt64
end

function fields(::Type{UncoreSelectRegister})
    nt = (
        event           = (0, 7),
        umask           = (8, 15),
        reset           = (17, 17),
        edge_detect     = (18, 18),
        tid_enable      = (19, 19),      # Only applicable for CHAS
        overflow_enable = (20, 20),
        en              = (22, 22),
        invert          = (23, 23),
        thresh          = (24, 31),
    )
    return nt
end
name(::Type{UncoreSelectRegister}) = "Uncore Event Select Register"
defaults(::Type{UncoreSelectRegister}) = (en = true,)

### CHA Filter 0
struct CHAFilter0 <: BitField
    val::UInt64
end
fields(::Type{CHAFilter0}) = (
    thread_id   = (0, 2),
    core_id     = (3, 8),
    LLC_I_state = (17, 17),
    SF_S_state  = (18, 18),
    SF_E_state  = (19, 19),
    SF_H_state  = (20, 20),
    LLC_S_state = (21, 21),
    LLC_E_state = (22, 22),
    LLC_M_state = (23, 23),
    LLC_F_state = (24, 24),
)
name(::Type{CHAFilter0}) = "CHA Filter 0"
defaults(::Type{CHAFilter0}) = (
    LLC_I_state = true,
    LLC_S_state = true,
    LLC_E_state = true,
    LLC_M_state = true,
    LLC_F_state = true,
)

# ### CHA Filter 1
struct CHAFilter1 <: BitField
    val::UInt64
end

fields(::Type{CHAFilter1}) = (
    remote          = (0, 0),
    loc             = (1, 1),
    all_opc         = (3, 3),
    near_memory     = (4, 4),
    not_near_memory = (5, 5),
    op0             = (9, 18),
    opc1            = (19, 28),
    non_coherent    = (30, 30),
    isoc            = (31, 31),
)
name(::Type{CHAFilter1}) = "CHA Filter 1"
defaults(::Type{CHAFilter1}) = (
    remote          = true,
    loc             = true,
    all_opc         = true,
    near_memory     = true,
    not_near_memory = true
)

