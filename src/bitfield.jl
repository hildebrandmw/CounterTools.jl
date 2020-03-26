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
"""
    CoreSelectRegister(; kw...)

Construct a bitmask for programming `Core` level counters.

Keywords
========
- `event::UInt`: Select the event to be counted. Default: `0x00`
- `umask::Uint`: Select the subevent to be counted within the selected event. Default: `0x00`
- `usr::Bool`: Specifies the counter should be active when the processor is operating at
    privilege modes 1, 2, and 3. Default: `true`.
- `os::Bool`: Specifies the counter should be active when the processor is operating at
    privilege mode 0. Default: `true`.
- `e::Bool`: Edge detect. Default: `false`.
- `en::Bool`: Enable the counter. Default: `true`.
- `inv::Bool`: When set, inverts the counter-mask (CMASK) comparison, so that both greater
    than or equal to and less than comparisons can be made (0: greater than or equal; 1:
    less than). Note if counter-mask is programmed to zero, INV flag is ignored. Default: `false`.
- `cmask::Bool`: When this field is not zero, a logical processor compares this mask to the
    events count of the detected microarchitectural condition during a single cycle. If the
    event count is greater than or equal to this mask, the counter is incremented by one.
    Otherwise the counter is not incremented.

    This mask is intended for software to characterize microarchitectural conditions that
    can count multiple occurrences per cycle (for example, two or more instructions retired
    per clock; or bus queue occupations). If the counter-mask field is 0, then the counter
    is incremented each cycle by the event count associated with multiple occurrences.
"""
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
        #pc    = (19, 19), # not implemented on Skylake+
        #int   = (20, 20), # not worrying about this
        en    = (22, 22),
        inv   = (23, 23),
        cmask = (24, 31),
    )
    return nt
end
name(::Type{CoreSelectRegister}) = "Core Event Select Register"
defaults(::Type{CoreSelectRegister}) = (usr = true, os = true, en = true)

### Uncore Select
"""
    UncoreSelectRegister(; kw...)

Construct a bitmask for programming `Uncore` level counters.

Keywords
========

- `event::UInt`: Select event to be counted. Default: `0x00`
- `umask::UInt`: Select subevents to be counted within the selected event. Default: `0x00`
- `reset::Bool`: When set to 1, the corresponding counter will be cleared to 0. Default: `false`
- `edge_detact::Bool`: When set to 1, rather than measuring the event in each cycle it is
    active, the corresponding counter will increment when a 0 to 1 transition (i.e. rising edge)
    is detected.

    When 0, the counter will increment in each cycle that the event is asserted.

    NOTE: `edge_detect` is in series following `thresh`, Due to this, the `thresh` field
    must be set to a non-0 value. For events that increment by no more than 1 per cycle,
    set `thresh` to 0x1. Default: `false`.
- `overflow_enable::Bool`: When this bit is set to 1 and the corresponding counter overflows,
    an overflow message is sent to the UBox’s global logic. The message identifies the unit
    that sent it. Default: `false`.
- `en::Bool`: Local Counter Enable. Default: `true`.
- `invert::Bool`: Invert comparison against Threshold.

    0 - comparison will be ‘is event increment >= threshold?’.

    1 - comparison is inverted - ‘is event increment < threshold?’

    e.g. for a 64-entry queue, if SW wanted to know how many cycles the queue had fewer
    than 4 entries, SW should set the threshold to 4 and set the invert bit to 1.
    Default: `false`.
- `thresh::UInt`: Threshold is used, along with the invert bit, to compare against the
    counter’s incoming increment value. i.e. the value that will be added to the counter.

    For events that increment by more than 1 per cycle, if the threshold is set to a value
    greater than 1, the data register will accumulate instances in which the event
    increment is >= threshold. Default: `0x00`.
"""
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
"""
    CHAFilter0(; kw...)
"""
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
"""
    CHAFilter1(; kw...)
"""
struct CHAFilter1 <: BitField
    val::UInt64
end

fields(::Type{CHAFilter1}) = (
    remote          = (0, 0),
    loc             = (1, 1),
    all_opc         = (3, 3),
    near_memory     = (4, 4),
    not_near_memory = (5, 5),
    opc0            = (9, 18),
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

