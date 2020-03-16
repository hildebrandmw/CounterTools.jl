# Usage

## Example

Suppose we wanted to measure the number of floating point instructions executed by Julia's BLAS library for a matrix multiply.
Note - right off the bat, we don't know for sure which class of AVX instructions the pre-built BLAS libraries use (i.e. 128, 256, or 512 bit)

First, we start Julia under `numactl`.
I'm running on a system with 2 sockets, each socket has 24 physical CPUs, 48 hyperthreaded logical CPUs.
A note on numbering:
* CPU numbers 0 to 23 represent distinct physical cores on socket 0.
* CPU numbers 24-47 represent distinct physical cores on socket 1.
* CPU numbers 48-71 represent hyperthreaded cores on socket 0.
    That is, CPU 48 and CPU 0 refer to the SAME physical CPU, but different hyper threads.
* CPU numbers 72-95 are hyperthreaded cores on socket 1.

By default, Julia uses 8 threads for its BLAS library, so the start command is
```
sudo numactl --physcpubind=24-31 --membind=1 <path/to/julia>
```
Now, in Julia:
```julia
using CounterTools

# Select the Events we wish to monitor.
# Event numbers and umasks can be found at:
#   https://download.01.org/perfmon
#
# Since we don't know (yet) what instructions are used by Julia's BLAS library, we
# include events for
#
#   - Scalar Floating Point
#   - 128b packed
#   - 256b packed
#   - 512b packed
#
# NOTE: Since hyper threading is enabled, we only have 4 programmable counters available
# for use.
# Trying to use more will generate an error.
events = (
    CounterTools.EventSelectRegister(event = 0xC7, umask = 0x01),   # scalar
    CounterTools.EventSelectRegister(event = 0xC7, umask = 0x04),   # 128b
    CounterTools.EventSelectRegister(event = 0xC7, umask = 0x10),   # 256b
    CounterTools.EventSelectRegister(event = 0xC7, umask = 0x40),   # 512b
)

# Next, we initialize our arrays and force JIT compilation of the code
A = rand(Float64, 5000, 5000)
B = rand(Float64, 5000, 5000)
A * B

# Now, initialize a CoreMonitor to watch core-level counters
#
# This will program the CPU's counters and begin running.
#
# Since we've restricted the number of CPUs using `numactl`, we choose to only monitor
# that subset of CPUs
#
# Note that since Julia is Index 1, the CPU range is 25:32 instead of 24:31.
monitor = CounterTools.CoreMonitor(25:32, events)

# We can read the current values from the monitor using `read`:
read(monitor)

# Note that the elements of the result are of type `CounterTools.CoreCounterValue`
# This is because the counter registers on the CPU are 48-bits wide and thus are
# likely to overflow at some point.
#
# The type `CounterTools.CoreCounterValue` implements a little extra functionality that
# detects when overlap occurs and automatically corrects for it.
#
# Since counters just collect raw counts, this allows for a stream of raw counter values
# to be collected and then differences to be taken to obtain deltas.

# Now we actually do some monitoring
pre = read(monitor)
A * B
post = read(monitor)
deltas = map((x, y) -> x .- y, post, pre)

display(deltas)
# 8-element Array{NTuple{4,Int64},1}:
#  (0, 0, 7615200000, 0)
#  (0, 0, 7314600000, 0)
#  (0, 0, 8016000000, 0)
#  (0, 0, 8016000000, 0)
#  (0, 0, 8016000000, 0)
#  (0, 0, 8016000000, 0)
#  (0, 0, 7615200000, 0)
#  (4529, 0, 8016000000, 0)
```

### Discussion of Results

Lets break down what the results mean.
First, each entry in the outer array represents the counter results for one CPU in the CPUs we were gathering metrics on.
That is, the first entry is CPU 24, the second is CPU 25 etc.
The entries themselves correspond to counter deltas for each counter in `events`.
Thus, the first entry is for scalar double-precision floating point operations, the second is for 128b, the third is for 256b, and the fourth is 512b.
We observe that JULIA's blas library must use AVX-256 instructions.

Now, does the count make sense?
Well, lets count up the total number of operations:
```julia
total_avx_256 = sum(x -> x[3], deltas)

# Multiply by 4 because each AVX-256 instruction operates on 4 Float64s.
display(4 * total_avx_256)
# 250500000000
```

Now, we approximate the total number of expected operations on the 5000x5000 matrices.
```
total_expected = 5000^3 * 2
display(total_expected)
# 250000000000
```
Note that we multiply by 2 because the multiply-add required for matrix multiplication counts
as 2 operations.

We see that the numbers line up pretty well!

