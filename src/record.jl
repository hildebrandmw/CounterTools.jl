mapleaves(f::F, X...) where {F} = f(X...)
mapleaves(f::F, X::NTuple{N,T}...) where {F,N,T} = ntuple(i -> mapleaves(f, _getindex(X, i)...), Val(N))
mapleaves(f::F, X::AbstractArray...) where {F} = map((x...) -> mapleaves(f, x...), X...)

_getindex(X::NTuple{K,NTuple{N,T}}, i) where {K,N,T} = ntuple(j -> X[j][i], Val(K))

#####
##### Record Type for keeping track of what we're measuring
#####

"""
    Record{name}(data::T) where {T <: Union{Vector, NTuple}}

Create a named `Record` around `data`.
The elements of `data` may themselves be `Record`s, resulting in a hierarchical data structure.
"""
struct Record{name,T <: Union{Vector, NTuple}}
    data::T
end
Record{name}(data::T) where {name,T} = Record{name,T}(data)

name(R::Record{N}) where {N} = N

# Check if there are records below this record.
hassubrecord(R::Record) = eltype(R.data) <: Record

Base.getindex(R::Record, i...) = R.data[i...]
Base.length(R::Record) = length(R.data)

Base.iterate(R::Record) = iterate(R.data)
Base.iterate(R::Record, s) = iterate(R.data, s)

denest(x) = x
denest(x::Tuple{Tuple}) = denest(first(x))

# Recurse down the record stack, but apply the name to whatever is returned.
"""
    mapleaves(f, record::Record) -> Record

Apply `f` to each leaf element of `record`.
This will recursively descend through hierarchies of `Records` and only apply `f` to scalars.

The returned result will have the same hierarchical structure as `record`
"""
function mapleaves(f, R::Record{name}...) where {name}
    return Record{name}(denest(mapleaves(f, _getdata(R...)...)))
end

_getdata(x::Record, y::Record...) = (x.data, _getdata(y...)...)
_getdata() = ()

# Applying a difference to two subsequent records
Base.:-(a::R, b::R) where {R <: Record} = mapleaves(-, a, b)
Base.:+(a::R, b::R) where {R <: Record} = mapleaves(+, a, b)
mapleaves(f) = (x...) -> mapleaves(f, x...)

# Aggregate across records
"""
    aggregate(record::Record)
    aggregate(f, record::Record)

Reduce over all the leaf (terminal) elements of `record`, applying `f` as the reduction function.
If `f` is not supplied, it will defult to `(x,y) -> x .+ y`.
"""
aggregate(f, X::Record) = aggregate(f, X.data)
aggregate(f, X::Vector) = reduce(f, aggregate.(f, X))
aggregate(f, X::NTuple{N,<:Record}) where {N} = reduce(f, aggregate.(f, X))
aggregate(f, X::NTuple{N,<:NTuple}) where {N} = reduce(f, aggregate.(f, X))
aggregate(f, X) = X

# Default
aggregate(X) = aggregate((x,y) -> x .+ y, X)

#####
##### Pretty Printing
#####

titleize(x) = titlecase(replace(String(x), "_" => " "))
function Base.show(io::IO, R::Record, pre = "")
    println(io, pre, titleize(name(R)), " Record with $(length(R)) entries:")
    post = pre * "   "
    if hassubrecord(R)
        show(io, first(R.data), post)
    else
        print(io, post, eltype(R.data))
    end

    # Only show contents from the top level
    if isempty(pre)
        println(io)
        println(io)
        showcontents(io, R)
    end
end

function showcontents(io::IO, R::Record, pre = "")
    post = pre * "   "
    print(io, pre, titleize(name(R)), ": ")
    if hassubrecord(R)
        print(io, "\n")
        showcontents.(Ref(io), R.data, post)
    else
        println(io, R.data)
    end
end
