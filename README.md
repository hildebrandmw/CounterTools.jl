# CounterTools

| **Documentation** | **Status** |
|:---:|:---:|
[![][docs-latest-img]][docs-latest-url] | [![][travis-img]][travis-url] |

## Make CPU MSR (Model Specific Registers) available

CounterTools uses CPU MSRs in `/dev/cpu/` to configure the performance counters.
By default, these are not available for reading or writing.
These can be made available using
```sh
sudo modprobe msr
```


## Allowing the `rdpmc` instruction.

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
[docs-latest-url]: https://hildebrandmw.github.io/CounterTools.jl/

[travis-img]: https://travis-ci.com/hildebrandmw/CounterTools.jl.svg?branch=master
[travis-url]: https://travis-ci.org/hildebrandmw/CounterTools.jl
