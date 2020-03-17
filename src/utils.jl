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
