struct MapLeaves{F}
    f::F
end
MapLeaves(f::MapLeaves) = f

struct MapLeavesIndex{F,Args}
    f::F
    args::Args
end

MapLeavesIndex(f::MapLeaves{F}, args::Args) where {F,Args} =
    MapLeavesIndex{F,Args}(f.f, args)
MapLeaves(f::MapLeavesIndex{F}) where {F} = MapLeaves{F}(f.f)

(f::MapLeavesIndex)(i::Integer) = MapLeaves(f)(getindex.(f.args, i)...)
(f::MapLeaves)(x...) = f.f(x...)
@generated function (f::MapLeaves)(x::Vararg{NTuple{N,T},K}) where {N,T,K}
    getters = map(Base.OneTo(N)) do i
        exprs = [:(x[$j][$i]) for j in Base.OneTo(K)]
        return :(f($(exprs...)))
    end
    return :(($(getters...),))
end
(f::MapLeaves)(x::AbstractArray...) = map(f, x...)

mapleaves(f::F, x...) where {F} = MapLeaves(f)(x...)

#####
##### Record Type for keeping track of what we're measuring
#####

"""
    Record{name}(data::T) where {T <: Union{Vector, NTuple}}

Create a named `Record` around `data`.
The elements of `data` may themselves be `Record`s, resulting in a hierarchical data structure.
"""
struct Record{name,T<:Union{Vector,NTuple}}
    data::T
end
Record{name}(data::T) where {name,T} = Record{name,T}(data)
Record{name}(data::Tuple{Tuple}) where {name} = Record{name}(data[1])

name(::Record{N}) where {N} = N

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
@generated function (f::MapLeaves)(R::Vararg{Record{name},N}) where {name,N}
    getters = [:(R[$i].data) for i in Base.OneTo(N)]
    return :(Record{name}(f($(getters...))))
end

# Applying a difference to two subsequent records
Base.:-(a::R, b::R) where {R<:Record} = mapleaves(-, a, b)
Base.:+(a::R, b::R) where {R<:Record} = mapleaves(+, a, b)
mapleaves(f) = (x...) -> mapleaves(f, x...)

# Aggregate across records
struct Aggregate{F}
    f::F
end

(f::Aggregate)(x) = x
(f::Aggregate)(x, y) = f.f.(x, y)
(f::Aggregate)(x::Record) = f(x.data)
const AggregateRecurseTypes =
    Union{AbstractVector,NTuple{<:Any,<:Record},NTuple{<:Any,<:NTuple}}
(f::Aggregate)(x::AggregateRecurseTypes) = reduce(f, map(f, x))

"""
    aggregate(record::Record)
    aggregate(f, record::Record)

Reduce over all the leaf (terminal) elements of `record`, applying `f` as the reduction function.
If `f` is not supplied, it will defult to `(x,y) -> x .+ y`.
"""
aggregate(f::F, x) where {F} = Aggregate{F}(f)(x)
aggregate(x) = aggregate(+, x)
#broadcast_add(x, y) = x .+ y

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
