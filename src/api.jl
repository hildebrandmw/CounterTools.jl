mapleaves(f, X...) = f(X...)
mapleaves(f, X::Tuple...) = map((x...) -> mapleaves(f, x...), X...)
mapleaves(f, X::AbstractArray...) = map((x...) -> mapleaves(f, x...), X...)

#####
##### Record Type for keeping track of what we're measuring
#####

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

# Recurse down the record stack, but apply the name to whatever is returned.
function mapleaves(f, R::Record{name}...) where {name}
    return Record{name}(mapleaves(f, getproperty.(R, :data)...))
end

# Applying a difference to two subsequent records
Base.:-(a::R, b::R) where {R <: Record} = mapleaves(-, a, b)

# Aggregate across records
aggregate(f, X::Record) = aggregate(f, X.data)
aggregate(f, X::Vector{<:Record}) = reduce(f, aggregate.(f, X))
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
