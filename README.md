# CounterTools

| **Documentation** | **Status** |
|:---:|:---:|
[![][docs-latest-img]][docs-latest-url] | [![][travis-img]][travis-url] |

A Julia package for configuring and reading Intel x86 performance counters with a Linux-based operating system.

## Installation

This is not a registerd Julia package.
To install, use
```julia
julia> using Pkg

julia> pkg"add https://github.com/hildebrandmw/CounterTools.jl"
```

## Example

Lets compute the number of FLOPS of Julia's matrix multiply BLAS function!

```julia
julia> using CounterTools
```
We need to build up a tuple of events to monitor on the performance counters.

These events are selected using an 8-bit event code and an 8-bit umask
See https://download.01.com/perfmon for event codes.
```julia
julia> events = (
    # FP_ARITH_INST_RETIRED.SCALAR_DOUBLE
    CounterTools.CoreSelectRegister(event = 0xC7, umask = 0x01),
    # FP_ARITH_INST_RETIRED.128B_PACKED_DOUBLE
    CounterTools.CoreSelectRegister(event = 0xC7, umask = 0x04),
    # FP_ARITH_INST_RETIRED.256B_PACKED_DOUBLE
    CounterTools.CoreSelectRegister(event = 0xC7, umask = 0x10),
    # FP_ARITH_INST_RETIRED.512B_PACKED_DOUBLE
    CounterTools.CoreSelectRegister(event = 0xC7, umask = 0x40),
);
```
With this list of events, we can construct a `CounterTools.CoreMonitor`, which programs the counters for the CPU cores.
The `CounterTools.CoreMonitor` takes two arguments: the list of events previously created, and a list of CPUs to monitor.
Here, we just monitor all of the CPUs on the system.
```julia
julia> ncpus = parse(Int, read(`nproc`, String));

julia> monitor = CounterTools.CoreMonitor(events, 1:ncpus);
```
Calling `read` on `monitor` will read all programmed events from all CPUs:
```
julia> read(monitor)
Cpu Set Record with 96 entries:
   Cpu Record with 4 entries:
      CounterTools.CounterValue

Cpu Set:
   Cpu: (CV(0), CV(0), CV(0), CV(65535))
   Cpu: (CV(1537), CV(0), CV(0), CV(0))
   Cpu: (CV(1), CV(0), CV(0), CV(0))
   Cpu: (CV(708), CV(0), CV(0), CV(0))
    ...
```
This represents the results from each event from each CPU.
Now, lets use this to measure the number of FLOPS Julia's BLAS library gets.
```julia
julia> function getflops(monitor, f, args...)
            # Read counter state before and after program execution
            pre = read(monitor)
            runtime = @elapsed f(args...)
            post = read(monitor)

            # Get the difference in counter values and aggregate across all cores
            aggregate = CounterTools.aggregate(post - pre)

            # Number of FLOPS depends on the instruction used.
            num_flops = aggregate[1] + 2 * aggregate[2] + 4 * aggregate[3] + 8 * aggregate[4]
            return num_flops / runtime
        end

julia> A = rand(Float64, 10000, 10000);

julia> B = rand(Float64, 10000, 10000);

# Run this once to trigger compilation
julia> getflops(monitor, *, A, B)

# Measure flops
julia> for i in 1:10
           println(getflops(monitor, *, A, B))
       end
1.7153487282457816e11
2.007237750137387e11
2.3070828931343286e11
2.670292793307479e11
2.4751763301444284e11
2.7341301460956998e11
3.085682663983478e11
2.8075861009707574e11
2.278768136919852e11
2.7046256290000647e11
```
Remember, this is only running with the default 8 threads, is not setup with NUMA etc.
However, this still corresponds to about 28 GFLOPS/CPU.

## Setup

Linux requires some setup to make performance counters available.

### Make CPU MSR (Model Specific Registers) available

CounterTools uses CPU MSRs in `/dev/cpu/` to configure the performance counters.
By default, these are not available for reading or writing.
These can be made available using
```sh
sudo modprobe msr
```

### Allowing the `rdpmc` instruction.

To allow the `rdpmc` instruction that is responsible for reading the performance counters, it may be necessary to run
```sh
echo 2 > /sys/devices/cpu/rdpmc
```
This will enable counters to be read in user mode.

Note that this command will have to be run under `sudo`.
One way to do that is:
```sh
sudo sh -c "echo 2 > /sys/devices/cpu/rdpmc"
```

[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://hildebrandmw.github.io/CounterTools.jl/dev/

[travis-img]: https://travis-ci.com/hildebrandmw/CounterTools.jl.svg?branch=master
[travis-url]: https://travis-ci.com/github/hildebrandmw/CounterTools.jl
