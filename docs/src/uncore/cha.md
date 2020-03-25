# CHA Monitoring

With the Skylake and newer Intel XEON chips, each core on the has: a slice of the total LLC, a "Caching Home Agent (CHA), and a Snoop Filter.
Addresses are assigned to exactly one of these slice/CHA/SF "boxes".
Normal addresses requests are first checked to see if they are in the LLC, then the Snoop Filter is checked.
Remember that the LLC on Xeon systems is non-inclusive with the L2 cache on the processors.
The Snoop Filter is responsible for checking whether or not data is in these caches.
If data is not in the LLC or SF, then the CHA is responsible for fetching the data, usually from memory via the iMC [1].

Intel includes a set of performance counters in each of these boxes.

## Determining the available CHAs

For the current generation of Xeon chips, there can be up to 28 CHAs on each socket.
However, not all of these are in use is the number of cores is fewer.

### Finding PCI Bus address

References:

[1]: https://software.intel.com/en-us/forums/software-tuning-performance-optimization-platform-monitoring/topic/820002
