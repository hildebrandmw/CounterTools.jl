# Julia is Base 1 - but the CPU sets are index zero.
#
# This `IndexZero` type provides explicit description when we are in a base zero realm.
struct IndexZero{T <: Integer}
    val::T
end
value(B::IndexZero) = B.val

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

