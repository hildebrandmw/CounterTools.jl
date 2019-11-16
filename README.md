# PerformanceCounters

## Allowing the `rdpmc` instruction.

To allow the `rdpmc` instruction that is responsible for reading the performance counters,
it may be necessary to run
```sh
echo 2 > /sys/devices/cpu/rdpmc
```
This will enable counters to be read in user mode.
