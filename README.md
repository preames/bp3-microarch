# bp3-microarch

Exploration of the microarchitecture on the banana pi 3

The source in this repo is a not terrible interesting, it's simply a set
of simple scripts for generating and managing simply assembly test
programs for exploring micro architectural proposerties of the banana
pi 3.  This code is intended for *exploration*, there are much better
frameworks available for a true exhaustive search.  See e.g. microprobe
or llvm-exegensis.

## Usage

Onetime setup:
```
mkdir bin
```

On each campaign run:
```
rm *.s bin/*.out
python campaigns/vlse_LMUL_x_SEW_throughput/generate.py
make -j5
./run.sh > raw.out
```

WARNING: If you're cross building and copying to a separate run environment, make sure you kill the out binaries in both places.

## Basic Exploration (vadd.vv)

### Prior knowledge

From existing sources, I believe the vector core to be an in-order SIMD-style design with an execution width of 128 and a VLEN of 256.  See https://camel-cdr.github.io/rvv-bench-results/bpi_f3/index.html.  I am unsure if the processor is multi-issue, or possibly supports chaining in some cases.

### vadd_vv_m4_e64_x_VL

This campaign is about assessing runtime sensativity to VL.  Specifically, for a given fixed LMUL and SEW, does changing the immediat to a vsetivli change runtime behavior?

Conclusion: No impact (as you'd hope).  Interesting bit is that the range of immediates include the weird VLMAX to 2*VLMAX case in the specification, so while we can't tell which VL it picks (from this test), we can at least see it doesn't impact throughtput.


### vadd_vv_LMUL_x_SEW_throughput

This is a throughput test with 5 repeating independent operations with no common source or destination registers.  Does not include m8 due to inability to keep 7 values live at once.  Is 5 enough?  Appears to be from the data, but might be worth checking explicitly at a later point

|     | mf8 | mf4 | mf2 | m1 | m2 | m4 | m8  |
|-----|-----|-----|-----|----|----|----|-----|
| e8  |  1  |  1  |  1  | 1  | 2  | 4  | n/a |
| e16 | err |  1  |  1  | 1  | 2  | 4  | n/a |
| e32 | err | err |  1  | 1  | 2  | 4  | n/a |
| e64 | err | err | err | 1  | 2  | 4  | n/a |

Observations:
* We appear to half the throughput as we move from m1 to m2 to m4.  I don't have m8 data here, but given the latency data (below), that trend probably continues.  Nothing particularly suprising here.
* Interestingly, we *don't* see a difference between mf2 and m1.  This is slightly surprising given we expect to have a DLEN=VLEN/2.  
* SEW has no impact on throughput for this instruction.
* The errors in fractional LMUL are unexpected and deserve further investigation.


### vadd_vv_LMUL_x_SEW_latency

A series of 1000 operations chained through the first operand.  We'd expect this to highlight the operation latency, and possiblity some interesting aspects of how LMUL is handled.

|     | mf8 | mf4 | mf2 | m1 | m2 | m4 |  m8  |
|-----|-----|-----|-----|----|----|----|------|
| e8  | 4   |  4  |  4  | 4  | 4  | 5  | 7.5  |
| e16 | err |  4  |  4  | 4  | 4  | 5  | 7.5  |
| e32 | err | err |  4  | 4  | 4  | 5  | 7.5  |
| e64 | err | err | err | 4  | 4  | 5  | 7.5  |

Observations:

* Primitive integer vector add appears to take 4 cycles.  (Easiest to see for e8 < m1.)
* LMUL appears to issue idependent operations with latencies increasing in a pipelined manner.  However, I have not been able to explain the exact numbers for m2, m4, and m8.  There's something go on there I don't fully understand.

## Memory Operations

### vle64_m4_x_VL, vlse_m4_x_VL, vlseg2e64_m4_x_VL

Does the VL impact the runtime performance of vle64.v (unit strided load), vlse64.v (strided load), vlseg2e64.v (unit strided segment load NF=2)?  It would be suprising for it to have any impact on vle64.v given what we know of the hardware.  The other two are less clear from prior knowledge as reasonable implementations could be VL dependent.

For vle64.v, this measurement appears a lot more noisy than the vadd.vv check for VL sensativity, but it appears there's no obvious pattern in VL impacting throughput.  The m4 operation averages ~8 cycles per instruction regardless of VL.  vlse64.v appears to again have no impact on runtime.  The m4 operation averages ~16 cycles per instruction regardless of VL.

The segmented version is currently crashing and needs further investigation.


## Raw Template

|     | mf8 | mf4 | mf2 | m1 | m2 | m4 | m8 |
|-----|-----|-----|-----|----|----|----|----|
| e8  |     |     |     |    |    |    |    |
| e16 |     |     |     |    |    |    |    |
| e32 |     |     |     |    |    |    |    |
| e64 |     |     |     |    |    |    |    |

