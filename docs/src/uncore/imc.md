# Integrated Memory Controller (iMC) Monitoring Example

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
Observe that we're now using [`CounterTools.UncoreSelectRegister`](@ref) instead of [`CounterTools.CoreSelectRegister`](@ref).
This is because the bit fields of the Uncore selection registers are slightly different than the Core selection registers.
Note that construction of a [`CounterTools.IMCMonitor`](@ref) **requires** `CounterTools.UncoreSelectRegisters`.

With that, lets instantiate a [`CounterTools.IMCMonitor`](@ref)!
Note that we have to pass which socket we want to monitor.
Since we've restricted Julia to running on socket 0 using `numactl`, this is the socket we pass to `IMCMonitor`.
We wrap it in a [`CounterTools.IndexZero`](@ref) to indicate that we really do want a literal 0.
We could have just as easily passed the integer `1` to achieve the same result.
```julia
monitor = CounterTools.IMCMonitor(events, CounterTools.IndexZero(0))
```
This automates the process of programming and starting the iMC performance counters.
We can now collect data from the counters:
```julia
data = read(monitor)
display(data)

# Socket Record with 2 entries:
#    Imc Record with 3 entries:
#       Channel Record with 4 entries:
#          CounterTools.CounterValue
#
# Socket:
#    Imc:
#       Channel: (CV(873907), CV(437771), CV(0), CV(0))
#       Channel: (CV(877335), CV(438516), CV(0), CV(0))
#       Channel: (CV(872746), CV(438298), CV(0), CV(0))
#    Imc:
#       Channel: (CV(865708), CV(432371), CV(0), CV(0))
#       Channel: (CV(866270), CV(430789), CV(0), CV(0))
#       Channel: (CV(867648), CV(431401), CV(0), CV(0))
```
Lets tease out what's going on here.
The top level is a `Record{:socket}`, which contains the counter results for our socket of interest.
Each socket has two Integrated Memory Controllers, which are modeled by the `Record{:imc}` inside the outermost record.
Furthermore, each IMC has three Channels, which are the three `Record{:channel}` inside each IMC.
Finally, each channel has four counters, which correspond to the entries in the `Record{:channel}`.

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
aggregate = CounterTools.aggregate(post - pre)
# (1491562, 250617, 0, 0)
```
Wow! That's much cleaner.
This helpful command essentially adds the counter values for all the channels across each socket and returns the sum.
We observe that Socket 0 (the one we're running Julia on) has a large number of reads (the first entry in the Tuple)
Lets calculate the corresponding number of bytes read
```julia
bytes_read = aggregate[1] * 64
# 95459968

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
CounterTools.aggregate(max, post - pre)
# (252053, 42442, 0, 0)
```
