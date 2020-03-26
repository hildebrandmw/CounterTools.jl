# Julia is Base 1 - but the CPU sets are index zero.
#
# This `IndexZero` type provides explicit description when we are in a base zero realm.

"""
    IndexZero

Specify that the value contained should be interpreted as starting at zero (0).

For example,
```julia
convert(CounterTools.IndexZero, 1) == CounterTools.IndexZero(0)
```
"""
struct IndexZero{T <: Integer}
    val::T
end

"""
    value(x::IndexZero)

Return the Integer value of `x`.
"""
value(B::IndexZero) = B.val

Base.convert(::Type{<:IndexZero}, x::Integer) = indexzero(x)

indexzero(i::T) where {T <: Integer} = IndexZero(i - one(T))
indexzero(i::IndexZero) = i

Base.getindex(A::AbstractArray, i::IndexZero) = A[value(i) + 1]
Base.getindex(A::Tuple, i::IndexZero) = A[value(i) + 1]
Base.getindex(A::Record, i::IndexZero) = A[value(i) + 1]

# Implement the Iterator Interface
Base.iterate(x::IndexZero) = (x, nothing)
Base.iterate(x::IndexZero, ::Nothing) = nothing
Base.length(::IndexZero) = 1

const INDEX_TYPES = Union{Integer, IndexZero}

