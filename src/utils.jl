# Wrapper around CounterValues so subtraction automatically handles wrapping
struct CounterValue
    value::UInt64
end
value(x::CounterValue) = x.value
Base.iszero(x::CounterValue) = iszero(x.value)

function Base.:-(x::CounterValue, y::CounterValue)
    # Test if overflow happened, add a large fixed value.
    start = value(x) < value(y) ? (UInt(1) << 47) : zero(UInt64)
    return convert(Int, start + value(x) - value(y))
end

Base.show(io::IO, x::CounterValue) = print(io, "CV($(value(x)))")

#####
##### Bit maniuplation functions
#####
clearbit(x, i) = x & ~(one(x) << i)
setbit(x, i) = x | (one(x) << i)

isbitset(x, i) = !iszero(x & mask(i))

clearbits(x, i) = reduce(clearbit, i; init = x)
setbits(x, i) = reduce(setbit, i; init = x)

mask(lo::T, hi::T) where {T} = (one(lo) << (hi + 1)) - (1 << lo)
mask(i) = one(i) << i

hex(i::Integer) = string(i; base = 16)

