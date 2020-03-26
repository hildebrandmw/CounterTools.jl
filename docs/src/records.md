# Record

Counter values and intermediate counter deltas are stored as [`CounterTools.Record`](@ref)s.
This data structure can model the hierarchical layout of performance counters in a way that is not particularly mind-bending to deal with.

Working with [`CounterTools.Record`](@ref)s is pretty easy.
Records wrap either Tuples or Arrays, and have a name:
```jldoctest record
julia> using CounterTools

julia> record_1 = CounterTools.Record{:A}((1, 1))
A Record with 2 entries:
   Int64

A: (1, 1)
```
Records can be indexed:
```jldoctest record
julia> record_1[1]
1
```
Records can be nested
```jldoctest record
julia> record_2 = CounterTools.Record{:A}((1,2))
A Record with 2 entries:
   Int64

A: (1, 2)

julia> record = CounterTools.Record{:top}((record_1, record_2))
Top Record with 2 entries:
   A Record with 2 entries:
      Int64

Top:
   A: (1, 1)
   A: (1, 2)
```
Of course, nested records can be indexed as well
```jldoctest record
julia> record[2][2]
2
```
Records can be subtracted from one another
The resulting Record has the same structure as the original records
```jldoctest record
julia> record - record
Top Record with 2 entries:
   A Record with 2 entries:
      Int64

Top:
   A: (0, 0)
   A: (0, 0)
```
All the leaf entries can be summed together using `CounterTools.aggregate`
```jldoctest record
julia> CounterTools.aggregate(record)
(2, 3)
```
If you want to apply a function to all of the leaf elements of a record, use [`CounterTools.mapleaves`](@ref)
```jldoctest record
julia> CounterTools.mapleaves(x -> 2x, record)
Top Record with 2 entries:
   A Record with 2 entries:
      Int64

Top:
   A: (2, 2)
   A: (2, 4)
```

## Common Usage

Commonly, `Records` will be collected as a vector and the leaf elements of `Records` will be [`CounterTools.CounterValue`](@ref).
The easiest way to take counter differences and aggregate is use the following:
```jldoctest record
julia> records = [record for _ in 1:10];

julia> CounterTools.aggregate.(diff(records))
9-element Array{Tuple{Int64,Int64},1}:
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
 (0, 0)
```

## Record Docstrings

```@docs
CounterTools.Record
CounterTools.aggregate
CounterTools.mapleaves
CounterTools.CounterValue
```
