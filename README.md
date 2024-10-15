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

This campaign is about assessing runtime sensitivity to VL.  Specifically, for a given fixed LMUL and SEW, does changing the immediate to a vsetivli change runtime behavior?

Conclusion: No impact (as you'd hope).  Interesting bit is that the range of immediates include the weird VLMAX to 2*VLMAX case in the specification, so while we can't tell which VL it picks (from this test), we can at least see it doesn't impact throughput.


### vadd_vv_LMUL_x_SEW_throughput

This is a throughput test with 5 repeating independent operations with no common source or destination registers.  Does not include m8 due to inability to keep 7 values live at once.  Is 5 enough?  Appears to be from the data, but might be worth checking explicitly at a later point

|     | mf8 | mf4 | mf2 | m1 | m2 | m4 | m8  |
|-----|-----|-----|-----|----|----|----|-----|
| e8  |  1  |  1  |  1  | 1  | 2  | 4  | n/a |
| e16 | err |  1  |  1  | 1  | 2  | 4  | n/a |
| e32 | err | err |  1  | 1  | 2  | 4  | n/a |
| e64 | err | err | err | 1  | 2  | 4  | n/a |

Observations:
* We appear to half the throughput as we move from m1 to m2 to m4.  I don't have m8 data here, but given the latency data (below), that trend probably continues.  Nothing particularly surprising here.
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
* LMUL appears to issue independent operations with latencies increasing in a pipelined manner.  However, I have not been able to explain the exact numbers for m2, m4, and m8.  There's something go on there I don't fully understand.

## Register Movement

### vmvNr_throughput, vmvNr_latency

|       | 1/thpt | latency |
|-------|--------|---------|
| vmv1r |  2     |   3     |
| vmv2r |  4     |   4     |
| vmv4r |  8     |   8     |
| vmv8r |  16    |   16    |

### vmvNr_special_cases

vmv1r_self -- With a latency of 4, shows that self moves (which should be nops) aren't eliminated.

vmv1r_dest_dep -- With a latency of 4, shows that vmv1r has an execution dependence on the destination register.  This is slightly surprising as this instructions semantics doesn't depend on the prior value of the destination.

Weirdly, both of these take 4 cycles on average, not 3 as measured by the latency test above.  I ran another variant of the latency test (vmv1r_latency_alternating.s) with a slightly different structure.  It really does look like both of these cases are *slower* than a normal vmv1r, and thus the troughput numbers above probably shouldn't be trusted for these cases either.

## dependence-on-dest

The specification has a very special case where when VL=0 the result of most vector instructions must be the prior value of the destination register.  In particular, this applies even when the instruction is tail agnostic.  Tail agnostic otherwise allows all elements past VL to be set to -1 unconditionally, but has an exception when VL=0.

The tests in this campaign exercise the VL=0 case (to check for potential slowdown in this special case), confirm chaining through the destination does force delay, and then try out all of the reasonable sounding dependency breaking idioms.

In short, the BP3 does respect the dependency on the prior value of the destination register, handles VL=0 at full throughput, and has no identified dependency breaking idiom.

## Memory Operations

### vle64_m4_x_VL, vlse_m4_x_VL, vlseg2e64_m4_x_VL

Does the VL impact the runtime performance of vle64.v (unit strided load), vlse64.v (strided load), vlseg2e64.v (unit strided segment load NF=2)?  It would be surprising for it to have any impact on vle64.v given what we know of the hardware.  The other two are less clear from prior knowledge as reasonable implementations could be VL dependent.

For vle64.v, this measurement appears a lot more noisy than the vadd.vv check for VL sensitivity, but it appears there's no obvious pattern in VL impacting throughput.  The m4 operation averages ~8 cycles per instruction regardless of VL.  vlse64.v appears to again have no impact on runtime.  The m4 operation averages ~16 cycles per instruction regardless of VL.

For vlseg2e64.v, we again have a bunch of noise, but I see no obvious pattern which indicates any kind of VL sensitivity.  The results vary from about 38 cycles to about 45 cycles.

So, overall, there's no indication of VL sensitivity in these runs.  It looks like these have a fixed cost at m4 (and thus probably a fixed cost at each individual LMUL.) 

### vle_LMUL_x_SEW_throughput

Investigating reciprocal throughput for unit strided loads.

Note: I used 4-wide independent chains and included V0 in the destination list.  I don't think this matters, but it does introduce a couple uninvestigated variables.  The results seem plausible, so I think this is probably okay.

|     | mf8   | mf4   | mf2   | m1    | m2    | m4    | m8     |
|:----|:------|:------|:------|:------|:------|:------|:-------|
| e8  | ~1.00 | ~1.00 | ~1.00 | ~2.00 | ~3.97 | ~7.90 | ~15.75 |
| e16 | nan   | ~1.00 | ~1.00 | ~1.99 | ~3.97 | ~7.91 | ~15.72 |
| e32 | nan   | nan   | ~1.00 | ~1.99 | ~3.97 | ~7.91 | ~15.74 |
| e64 | nan   | nan   | nan   | ~1.99 | ~3.97 | ~7.91 | ~15.74 |

Observation:
* More or less linear scaling as LMUL increases
* Here we see something we *didn't* see in vadd.vv tests; specifically a difference between mf2 and m1.  It looks like the memory fetch width is VLEN/2 here.

### vlse_LMUL_x_SEW_throughput

Investigating reciprocal throughput for strided loads.

|     | mf8   | mf4   | mf2    | m1     | m2     | m4      | m8      |
|:----|:------|:------|:-------|:-------|:-------|:--------|:--------|
| e8  | ~3.97 | ~7.89 | ~15.70 | ~30.83 | ~59.95 | ~116.91 | ~217.52 |
| e16 | nan   | ~3.96 | ~7.87  | ~15.65 | ~31.06 | ~60.78  | ~115.26 |
| e32 | nan   | nan   | ~3.96  | ~7.89  | ~15.69 | ~31.06  | ~60.81  |
| e64 | nan   | nan   | nan    | ~3.96  | ~7.89  | ~15.65  | ~30.99  |

Observations:

* Results seem to scale by LMUL for all LMULs (including fractional ones).  
* These are done with a constant stride of 16 bytes (not elements).  As such, these are accessing significantly more memory than the corresponding entries in the vle tables.  At SEW=64 this is 2x, at SEW=e8 this is 16x.
* Because of the constant stride, the memory accesses overlap in the same cache lines with relatively high frequency, and the hardware *may* be optimizing that case.  

Here's two runs with a constant stride of 160 bytes.  This should be long enough that each access lands in it's own cache line (for most reasonable cache structures).

|     | mf8   | mf4   | mf2    | m1     | m2     | m4      | m8       |
|:----|:------|:------|:-------|:-------|:-------|:--------|:---------|
| e8  | ~3.96 | ~7.89 | ~15.70 | ~31.03 | ~60.90 | ~653.86 | ~1204.30 |
| e16 | nan   | ~3.96 | ~7.90  | ~15.65 | ~31.03 | ~60.03  | ~668.94  |
| e32 | nan   | nan   | ~3.96  | ~7.89  | ~15.70 | ~30.82  | ~60.91   |
| e64 | nan   | nan   | nan    | ~3.96  | ~7.89  | ~15.70  | ~31.02   |

|     | mf8   | mf4   | mf2    | m1     | m2     | m4      | m8       |
|:----|:------|:------|:-------|:-------|:-------|:--------|:---------|
| e8  | ~3.96 | ~7.90 | ~15.64 | ~30.58 | ~60.85 | ~631.87 | ~1168.03 |
| e16 | nan   | ~3.97 | ~7.90  | ~15.65 | ~31.05 | ~59.94  | ~732.29  |
| e32 | nan   | nan   | ~3.96  | ~7.89  | ~15.70 | ~31.04  | ~60.64   |
| e64 | nan   | nan   | nan    | ~3.97  | ~7.89  | ~15.69  | ~30.84   |

This result seems roughly consistent with a memory system which can issue one 128 bit load per cycle, and is issuing one load per element.  Though I do not understand the high variance, in particular the fact that sometimes the result seems to take less than one cycle per element (when each element should it's own load).


### vlseg_LMUL_x_SEW_throughput

How does vlseg NF vary with NF, LMUL, and SEW?  From above, we strongly suspect that it does not vary with respect to VL.

| NF2 | mf8   | mf4   | mf2   | m1     | m2     | m4     |   m8 |
|:----|:------|:------|:------|:-------|:-------|:-------|-----:|
| e8  | ~4.95 | ~4.95 | ~5.94 | ~11.79 | ~23.28 | ~45.76 |  nan |
| e16 | nan   | ~4.95 | ~5.94 | ~11.82 | ~23.37 | ~46.16 |  nan |
| e32 | nan   | nan   | ~5.94 | ~11.81 | ~23.24 | ~45.92 |  nan |
| e64 | nan   | nan   | nan   | ~11.83 | ~23.34 | ~46.23 |  nan |

| NF3 | mf8   | mf4   | mf2   | m1     | m2     |   m4 |   m8 |
|:----|:------|:------|:------|:-------|:-------|-----:|-----:|
| e8  | ~6.93 | ~7.90 | ~9.86 | ~19.59 | ~38.71 |  nan |  nan |
| e16 | nan   | ~7.90 | ~9.87 | ~19.59 | ~38.09 |  nan |  nan |
| e32 | nan   | nan   | ~9.87 | ~19.48 | ~38.69 |  nan |  nan |
| e64 | nan   | nan   | nan   | ~17.61 | ~34.33 |  nan |  nan |

| NF4 | mf8   | mf4   | mf2    | m1     | m2     |   m4 |   m8 |
|:----|:------|:------|:-------|:-------|:-------|-----:|-----:|
| e8  | ~8.89 | ~9.88 | ~11.82 | ~23.40 | ~45.78 |  nan |  nan |
| e16 | nan   | ~9.83 | ~11.81 | ~23.45 | ~45.83 |  nan |  nan |
| e32 | nan   | nan   | ~11.82 | ~23.48 | ~45.84 |  nan |  nan |
| e64 | nan   | nan   | nan    | ~23.45 | ~45.89 |  nan |  nan |

| NF5 | mf8    | mf4    | mf2    | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:-------|:--------|-----:|-----:|-----:|
| e8  | ~19.61 | ~38.54 | ~75.33 | ~143.13 |  nan |  nan |  nan |
| e16 | nan    | ~19.62 | ~38.67 | ~74.74  |  nan |  nan |  nan |
| e32 | nan    | nan    | ~19.61 | ~38.57  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan    | ~19.56  |  nan |  nan |  nan |

| NF6 | mf8    | mf4    | mf2    | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:-------|:--------|-----:|-----:|-----:|
| e8  | ~23.42 | ~45.46 | ~89.43 | ~166.19 |  nan |  nan |  nan |
| e16 | nan    | ~23.45 | ~45.96 | ~88.50  |  nan |  nan |  nan |
| e32 | nan    | nan    | ~23.39 | ~46.17  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan    | ~23.24  |  nan |  nan |  nan |

| NF7 | mf8    | mf4    | mf2     | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:--------|:--------|-----:|-----:|-----:|
| e8  | ~27.20 | ~53.34 | ~102.10 | ~188.91 |  nan |  nan |  nan |
| e16 | nan    | ~27.24 | ~52.94  | ~101.70 |  nan |  nan |  nan |
| e32 | nan    | nan    | ~27.16  | ~53.17  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan     | ~27.26  |  nan |  nan |  nan |

| NF8 | mf8    | mf4    | mf2     | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:--------|:--------|-----:|-----:|-----:|
| e8  | ~30.97 | ~60.45 | ~114.86 | ~207.97 |  nan |  nan |  nan |
| e16 | nan    | ~31.00 | ~60.67  | ~115.57 |  nan |  nan |  nan |
| e32 | nan    | nan    | ~30.98  | ~60.48  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan     | ~31.01  |  nan |  nan |  nan |

Observation:
* It looks like there's some kind of change between NF2-4 and NF5-8.  The later appear to scale roughly with VLMAX (i.e. the distinct number of segments).  The NF2, NF3, and NF4 cases are clearly different.  I'm guessing these are done as a single wide load followed by a couple of special shuffles.
* Given the apparent difference in implementations, I went back and ran a VL sweep at both {e64, NF8, m1} and {e8, NF8, m1} to confirm there was no VL sensativity there either.  There's a ton of variability in the later one particular, but no obvious VL relevant pattern.
