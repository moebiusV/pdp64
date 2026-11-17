| target | files ok | scalar instructions | vector instructions | ratio | scalar bytes | vector bytes | vectorized loops (vf avg) | SLP |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| x86_64-avx2 | 15 | 42,706 | 60,407 | 1.414 | 167,314 | 260,484 | 180 (13.7) | 50 |
| aarch64 | 15 | 32,361 | 47,030 | 1.453 | 129,444 | 188,120 | 173 (10.3) | 40 |
| riscv64-v | 15 | 45,407 | 56,334 | 1.241 | 133,728 | 172,138 | 12 (6.0) | 45 |
| loongarch64-lasx | 15 | 41,301 | 58,661 | 1.420 | 165,204 | 234,644 | 169 (8.9) | 31 |

Loops the vectorizer looked at and left (x86-64 AVX2 and AArch64 together): vectorized 353, not vectorized 492.

Why loops were left (the reasons the vectorizer gave, counted once per file and target): instruction cannot be vectorized 24; value that could not be identified as reduction is used outs 24; cannot identify array bounds 20; Cannot vectorize uncountable loop 19; call instruction cannot be vectorized 16; could not determine number of loop iterations 15; Cannot vectorize potentially faulting early exit loop 4; Control flow cannot be substituted for a select 4

x86_64-avx2: 185 vectorized loop bodies in the IR: map 120, reduce 29, masked 26, shuffle 10
  map       120 bodies; element operations per iteration: median 4, max 24; loads 2.9, stores 1.4 on average
  reduce     29 bodies; element operations per iteration: median 4, max 32; loads 3.6, stores 0.7 on average
  shuffle    10 bodies; element operations per iteration: median 17, max 76; loads 5.7, stores 2.8 on average
  masked     26 bodies; element operations per iteration: median 9, max 20; loads 4.3, stores 1.3 on average

aarch64: 182 vectorized loop bodies in the IR: map 115, masked 31, reduce 26, shuffle 10
  map       115 bodies; element operations per iteration: median 4, max 24; loads 2.9, stores 1.0 on average
  reduce     26 bodies; element operations per iteration: median 2, max 24; loads 2.6, stores 0.5 on average
  shuffle    10 bodies; element operations per iteration: median 17, max 36; loads 4.7, stores 1.8 on average
  masked     31 bodies; element operations per iteration: median 8, max 19; loads 4.1, stores 1.4 on average
