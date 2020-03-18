# Integrated Memory Controller (iMC) Monitoring

CounterTools allows for programming and reading from the performance counters within the iMC.
This is primarily done through the [`CounterTools.IMCMonitor`](@ref) data type.
We'll provide a quick usage summary below for those just looking to get started, and then include some more details later.

## Example

For this example, we will show how to monitor DRAM read and write bandwidth on a 2-socket Cascade Lake Xeon server.
Before we get started, we need to know the `event` and `umask` codes for these events.
For the CLX microarchitecture, this can be found at the following link: <https://download.01.org/perfmon/CLX/> (look in the `uncore` JSON file).
We are looking for the events `"UNC_M_CAS_COUNT.RD` and `UNC_M_CAS_COUNT.WR`, both with event number `0x3` and umasks `0x3` and `0xC` respectively.
These counters record the number of read or write actions performed by the memory controller, where each action involves 64 Bytes of data.
Thus, to get the actual bandwidth, you must multiply whatever count number you get by 64.

Lets get started.

First, start up a Julia session.
For the purposes of this demo, we will use `numactl` to constrain Julia to NUMA node 0 - just to make sure that we're recording the correct information.
```sh
sudo numactl --cpunodebind=0 --membind=0 <path/to/julia>
```
Now, within Julia, we start the `CounterTools` package and set-up our events
```julia
using CounterTools
events = (
    CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0x3),
    CounterTools.UncoreSelectRegister(; event = 0x4, umask = 0xC),
)
```
Observe that we're now using [`CounterTools.UncoreSelectRegisters`](@ref) instead of [`CounterTools.CoreSelectRegisters`](@ref).
This is because the bit fields of the Uncore selection registers are slightly different than the Core selection registers.
Note that construction of a [`IMCMonitor`](@ref) **requires** `CounterTools.UncoreSelectRegisters`.

With that, lets instantiate a `IMCMonitor`!
```julia
monitor = CounterTools.IMCMonitor(events)
```
This automates the process of programming and starting the iMC performance counters.
We can now collect data from the counters:
```julia
data = read(monitor)
display(data)
```
**WHOA**: What the heck is going on??
What is returned by reading data is a somewhat gnarly nested `Tuple`, but there is a method to this madness.
I'm running this on a 2-socket system, so we have performance counter data for each socket.
This is the **outermost** tuple of the returned data.
```julia
# Performance Counters for Socket 0
data[1]
# Performance Counters for Socket 1
data[2]
```
Next, each socket has two memory controllers.
This is the next level of hierarchy:
```julia
# Socket 0, iMC 0
data[1][1]
# Socket 0, iMC 1
data[1][2]
```
Each iMC has 3 channels.
This is the **next** level of hierarchy:
```julia
# Socket 0, iMC 0, Channel 0
data[1][1][1]
# Socket 0, iMC 0, Channel 1
data[1][1][2]
# Socket 0, iMC 0, Channel 2
data[1][1][3]
```
Finally, each iMC channel has 4 programmable counters.
This is the **last** level of hierarchy, represented as a 4-tuple of [`CounterValue`](@ref)s
The counter values in this last tuple correspond elementwise to the original events used to construct the `IMCMonitor`.
So, `data[1][1][1][1]` is the **counter value** of DRAM reads for channel 0, iMC 0, Socket 0.
Similarly, `data[1][1][1][2]` is the value for DRAM writes.
Since we didn't program counters 2 or 3 (speaking in index zero terms), those values are simply 0.

Now, this can be a lot to take in.
Fortunately, we have some helpful tool!
First, remember that we generally look for a **difference** between subsequent samples.
Here's an example of using some of the tools to make that happen:
```julia
# Create a largish array. Precompile "sum" function
A = rand(Float64, 10^7); sum(A);

# Sample counters before and after performing an operation that reads the array
pre = read(monitor);
sum(A);
post = read(monitor);

# Now, we aggregate counters across sockets
aggregate = CounterTools.aggregate.(CounterTools.counterdiff(post, pre))
# (
#    (1474725, 118291, 0, 0),   # <- Aggregate for Socket 0
#    (136433, 113153, 0, 0)     # <- Aggregate for Socket 1
# )
```
Wow! That's much cleaner.
This helpful command essentially adds the counter values for all the channels across each socket and returns the sum.
We observe that Socket 0 (the one we're running Julia on) has a large number of reads (the first entry in the Tuple)
Lets calculate the corresponding number of bytes read
```julia
bytes_read = aggregate[1][1] * 64
# 94382400

sizeof(A)
# 80000000
```
We see a nice correlation here between the monitored number of bytes read and the number of bytes we'd expect to see!
Note that there is more traffic on the system than just the reading of the array.
For example, other processes on the system are generating DRAM traffic.
Plus, our own process is doing things like reading code from DRAM.

**NOTE**: Summing across all channels is not always what you want to do.
It's easy to make changes.
If, for example, you want to take the maximum across each channel (I'm not sure at the moment why you'd want to, but lets say that you do).
It's as simple as
```julia
CounterTools.aggregate(max, CounterTools.counterdiff(post, pre))
# ((247148, 20058, 0, 0), (23139, 19558, 0, 0))
```
