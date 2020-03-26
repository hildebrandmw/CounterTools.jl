# Monitors

The process of setting up and reading from various performance montoring counters is delegated to various `Monitor` types.
These monitors are:

- [`CounterTools.CoreMonitor`](@ref): Collects Core level counters.
These counters work on a CPU level granularity and can capture information such as number of retiretired instructions, number of floating point instrucitons, L1/L2 accesses etc.

- [`CounterTools.IMCMonitor`](@ref): Manages counters on the Integrated Memory Controller (iMC).
This can record events such as number of DRAM reads and writes.

- [`CounterTools.CHAMonitor`](@ref): Manages counters for the Caching Home Agents (CHA) in the system.
This can record events such as number of L3 hits and misses.

## Monitor API

After creations, all monitors have the same simple API.
The most common method will be [`read`](@ref), which will read from all of the PMUs currently controlled by the monitor and return the raw counters values in a [`CounterTools.Record`](@ref).
See the [`CounterTools.Record`](@ref) documentation for details on working with that data structure.

Two additional methods specified by each Monitor are [`CounterTools.program!`](@ref) and [`CounterTools.reset!`](@ref).
These methods configure the PMUs and reset the PMUs to their default state respectively.
Normally, you will not have to call these methods directly since programming is usually done during monitor creation and [`CounterTools.reset!`](@ref) is automatically called when the Monitor is garbage collected.

A simple usage of this would look like:
```julia
monitor = # create monitor

# Read once from the counters
first = read(monitor)

# Read again from the coutners
second = read(monitor)

# Automatically compute the counter deltas
deltas = second - first

# Aggregate all deltas
CounterTools.aggregate(deltas)
```
Additionally, if you are working with multiple samples, the following can serve as a template for your code.
```
monitor = # create monitor
data = map(1:10) do i
    sleep(0.1)
    read(monitor)
end

# `data` is a `Vector{<:Record}`
# To compute the counter difference across all samples, we can call Julia's `diff` function:
deltas = diff(data)

# Finally, we can aggregate each diff.
CounterTools.aggregate.(deltas)
```

!!! note
    Raw counter values will be wrapped in a [`CounterTools.CounterValue`](@ref) type that will automatically detect and correct for counter overflow when subtracting counter values.

## Monitor Documentation

### Monitors
```@docs
CounterTools.CoreMonitor
CounterTools.IMCMonitor
CounterTools.CHAMonitor
```

### API
```@docs
Base.read(::CounterTools.AbstractMonitor)
CounterTools.program!
CounterTools.reset!
```

## Select Registers

```@docs
CounterTools.CoreSelectRegister
CounterTools.UncoreSelectRegister
CounterTools.CHAFilter0
CounterTools.CHAFilter1
```

