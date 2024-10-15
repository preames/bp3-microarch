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
* The errors in fractional LMUL are due to this part of the specification:
  > For a given supported fractional LMUL setting, implementations must support SEW settings between SEWMIN and LMUL * ELEN, inclusive.

  I.e. With +v SEWMIN=8 and ELEN=64, so at mf8 the only supported SEW is e8.


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
| e8  | ~1.00 | ~1.01 | ~1.00 | ~1.99 | ~3.97 | ~7.88 | ~15.20 |
| e16 | nan   | ~1.00 | ~1.00 | ~1.99 | ~3.97 | ~7.89 | ~15.66 |
| e32 | nan   | nan   | ~1.00 | ~1.99 | ~3.96 | ~7.83 | ~15.65 |
| e64 | nan   | nan   | nan   | ~1.99 | ~3.97 | ~7.89 | ~15.66 |

Observation:
* More or less linear scaling as LMUL increases
* Here we see something we *didn't* see in vadd.vv tests; specifically a difference between mf2 and m1.  It looks like the memory fetch width is VLEN/2 here.

### vlse_LMUL_x_SEW_throughput

Investigating reciprocal throughput for strided loads.  There is significant variation from run to run here, the two tables represent two runs immediately back to back.

|     | mf8   | mf4   | mf2    | m1     | m2     | m4     | m8      |
|:----|:------|:------|:-------|:-------|:-------|:-------|:--------|
| e8  | ~3.91 | ~7.86 | ~14.11 | ~30.70 | ~59.59 | ~86.76 | ~200.06 |
| e16 | nan   | ~3.96 | ~7.87  | ~15.14 | ~30.69 | ~59.62 | ~89.30  |
| e32 | nan   | nan   | ~3.96  | ~7.87  | ~15.58 | ~30.73 | ~59.54  |
| e64 | nan   | nan   | nan    | ~3.96  | ~7.83  | ~15.44 | ~30.45  |


|     | mf8   | mf4   | mf2    | m1     | m2     | m4     | m8      |
|:----|:------|:------|:-------|:-------|:-------|:-------|:--------|
| e8  | ~3.96 | ~7.87 | ~14.79 | ~30.48 | ~59.32 | ~91.86 | ~202.49 |
| e16 | nan   | ~3.96 | ~7.86  | ~15.55 | ~28.97 | ~58.53 | ~83.55  |
| e32 | nan   | nan   | ~3.90  | ~7.78  | ~15.55 | ~27.61 | ~59.63  |
| e64 | nan   | nan   | nan    | ~3.95  | ~7.87  | ~14.11 | ~30.38  |

Observations:

* Results seem to scale by LMUL for all LMULs (including fractional ones).  
* These are done with a constant stride of 16 bytes (not elements).  As such, these are accessing significantly more memory than the corresponding entries in the vle tables.  At SEW=64 this is 2x, at SEW=e8 this is 16x.
* Because of the constant stride, the memory accesses overlap in the same cache lines with relatively high frequency, and the hardware *may* be optimizing that case.  

Here's two runs with a constant stride of 160 bytes.  This should be long enough that each access lands in it's own cache line (for most reasonable cache structures).

|     | mf8   | mf4   | mf2    | m1     | m2     | m4      | m8      |
|:----|:------|:------|:-------|:-------|:-------|:--------|:--------|
| e8  | ~3.96 | ~7.47 | ~14.54 | ~27.23 | ~39.34 | ~518.41 | ~501.33 |
| e16 | nan   | ~3.95 | ~7.31  | ~15.28 | ~28.51 | ~58.56  | ~413.34 |
| e32 | nan   | nan   | ~3.93  | ~7.87  | ~15.60 | ~30.03  | ~50.31  |
| e64 | nan   | nan   | nan    | ~3.96  | ~7.79  | ~12.49  | ~27.62  |

|     | mf8   | mf4   | mf2    | m1     | m2     | m4      | m8      |
|:----|:------|:------|:-------|:-------|:-------|:--------|:--------|
| e8  | ~3.96 | ~7.87 | ~14.72 | ~30.68 | ~59.62 | ~261.31 | ~864.76 |
| e16 | nan   | ~3.89 | ~7.47  | ~15.62 | ~27.12 | ~49.02  | ~458.83 |
| e32 | nan   | nan   | ~3.96  | ~7.84  | ~13.79 | ~28.94  | ~51.91  |
| e64 | nan   | nan   | nan    | ~3.96  | ~7.83  | ~15.61  | ~27.41  |

This result seems roughly consistent with a memory system which can issue one 128 bit load per cycle, and is issuing one load per element.  Though I do not understand the high variance, in particular the fact that sometimes the result seems to take less than one cycle per element (when each element should it's own load).


### vlseg_LMUL_x_SEW_throughput

How does vlseg NF vary with NF, LMUL, and SEW?  From above, we strongly suspect that it does not vary with respect to VL.

| NF2 | mf8   | mf4   | mf2   | m1     | m2     | m4     |   m8 |
|:----|:------|:------|:------|:-------|:-------|:-------|-----:|
| e8  | ~4.93 | ~4.84 | ~5.93 | ~11.77 | ~20.92 | ~38.02 |  nan |
| e16 | nan   | ~4.95 | ~5.93 | ~11.79 | ~23.13 | ~44.81 |  nan |
| e32 | nan   | nan   | ~5.93 | ~11.77 | ~21.11 | ~45.58 |  nan |
| e64 | nan   | nan   | nan   | ~11.77 | ~20.05 | ~39.23 |  nan |

| NF3 | mf8   | mf4   | mf2   | m1     | m2     |   m4 |   m8 |
|:----|:------|:------|:------|:-------|:-------|-----:|-----:|
| e8  | ~6.82 | ~7.89 | ~9.82 | ~19.04 | ~31.95 |  nan |  nan |
| e16 | nan   | ~7.89 | ~9.82 | ~18.75 | ~36.14 |  nan |  nan |
| e32 | nan   | nan   | ~9.82 | ~18.86 | ~36.38 |  nan |  nan |
| e64 | nan   | nan   | nan   | ~17.58 | ~34.57 |  nan |  nan |

| NF4 | mf8   | mf4   | mf2    | m1     | m2     |   m4 |   m8 |
|:----|:------|:------|:-------|:-------|:-------|-----:|-----:|
| e8  | ~8.87 | ~9.84 | ~11.78 | ~23.27 | ~45.58 |  nan |  nan |
| e16 | nan   | ~9.82 | ~11.79 | ~23.21 | ~45.44 |  nan |  nan |
| e32 | nan   | nan   | ~11.75 | ~20.35 | ~45.51 |  nan |  nan |
| e64 | nan   | nan   | nan    | ~23.25 | ~45.62 |  nan |  nan |

| NF5 | mf8    | mf4    | mf2    | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:-------|:--------|-----:|-----:|-----:|
| e8  | ~19.50 | ~38.22 | ~72.89 | ~137.19 |  nan |  nan |  nan |
| e16 | nan    | ~19.49 | ~38.11 | ~73.68  |  nan |  nan |  nan |
| e32 | nan    | nan    | ~19.43 | ~38.25  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan    | ~19.45  |  nan |  nan |  nan |

| NF6 | mf8    | mf4    | mf2    | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:-------|:--------|-----:|-----:|-----:|
| e8  | ~23.25 | ~45.50 | ~86.21 | ~160.46 |  nan |  nan |  nan |
| e16 | nan    | ~23.27 | ~44.49 | ~87.08  |  nan |  nan |  nan |
| e32 | nan    | nan    | ~23.28 | ~45.54  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan    | ~23.29  |  nan |  nan |  nan |

| NF7 | mf8    | mf4    | mf2    | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:-------|:--------|-----:|-----:|-----:|
| e8  | ~27.06 | ~52.61 | ~74.48 | ~181.47 |  nan |  nan |  nan |
| e16 | nan    | ~27.06 | ~45.61 | ~100.49 |  nan |  nan |  nan |
| e32 | nan    | nan    | ~23.64 | ~51.89  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan    | ~22.87  |  nan |  nan |  nan |

| NF8 | mf8    | mf4    | mf2     | m1      |   m2 |   m4 |   m8 |
|:----|:-------|:-------|:--------|:--------|-----:|-----:|-----:|
| e8  | ~30.82 | ~59.74 | ~108.35 | ~201.51 |  nan |  nan |  nan |
| e16 | nan    | ~29.02 | ~54.41  | ~86.09  |  nan |  nan |  nan |
| e32 | nan    | nan    | ~26.47  | ~57.84  |  nan |  nan |  nan |
| e64 | nan    | nan    | nan     | ~30.09  |  nan |  nan |  nan |

Observation:
* It looks like there's some kind of change between NF2-4 and NF5-8.  The later appear to scale roughly with VLMAX (i.e. the distinct number of segments).  The NF2, NF3, and NF4 cases are clearly different.  I'm guessing these are done as a single wide load followed by a couple of special shuffles.
* Given the apparent difference in implementations, I went back and ran a VL sweep at both {e64, NF8, m1} and {e8, NF8, m1} to confirm there was no VL sensativity there either.  There's a ton of variability in the later one particular, but no obvious VL relevant pattern.
