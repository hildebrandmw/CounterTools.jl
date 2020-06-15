# Utility methods for aggregating Select Registers together based on the limited number
# of counters available.
#
# This will allow a suite of counter values to be setup and will automatically keep
# iterating until all counters have been configured.
#
# If it becomes relevant, this will have to be refactored to be aware if we're targeting
# IMC/CHA etc because the rules vary slightly.

numconcurrent(x::T) where {T} = numconcurrent(T)
function numconcurrent(::Type{T}) where {T}
    error("Number of Concurrent Counters not defined for type $T")
end

numconcurrent(::Type{CoreSelectRegister}) = numcounters()

# Uncore PMUs fixed at 4 concurrent events.
# This logic gets more complicated when we throw on CHA Filters and the restriction that
# only a subset of the PMU counters can take some events - but for now we won't worry
# about that.
numconcurrent(::Type{UncoreSelectRegister}) = 4

"""
    group(x) -> itr

Return an iterator `itr` that partitions a collection of Selection Registers in a way
that matches the underlying capability of the hardware.
"""
group(x) = Iterators.partition(x, numconcurrent(eltype(x)))
