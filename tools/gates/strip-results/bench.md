Model: one cycle for each vector instruction in a strip (a vfir one for each tap), a commit of 1 cycle for each strip, a vend 1 cycle, the strip is the greater of its compute cycles and the cycles its memory instructions hold the port (bytes / port, rounded up for each instruction), scalar instructions 1 cycle each (a vec is one of them).  Per kernel the set-up of the driver is subtracted.
47 programs ran (46 kernels `lv` and 1 hand-written); 41 of them have a vec block (40 lv, 1 hand); without a block (no vector code in the lv build, the strip cannot matter): k_put8h k_hist k_ssm k_q4dot k_gray k_clamp8.
Hand-written kernels of vec-forms (k_*.vec.s, run with the same driver): used: k_sad; assembled but dropped, the program's result differs from the lv build of the same kernel (the cause was not investigated: the listings take their own register arguments, the driver calls with the C convention): k_dctop_fill k_fmac; not assembled by the current as64 (older syntax): k_prep8.vec.s k_put8h.vec.s k_put8h.vecfir.s k_dctop_sum.vec.s k_ssm.vec.s.
Results (exit status and a hash of every global array of the driver, written to standard output) of the kernels at all 20 (strip, port, commit) settings: identical for 47 of 47 programs.

### Per kernel (port 16 bytes a cycle, commit 1): vector instructions executed, strips, model cycles in total (scalar + vector), slowdown against strip 32

| kernel | build | vec instrs (at 32) | strips 32 / 16 / 8 | cycles 32 | cycles 16 | cycles 8 | slow 16 | slow 8 | vector cycles 16/32 | memory / compute cycles at 32 | scalar share at 32 | class |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| k_sad | hand | 96 | 32 / 64 / 128 | 306 | 402 | 658 | 1.314 | 2.150 | 1.55 | 1.33 | 0.42 | between |
| k_avg8 | lv | 128 | 32 / 63 / 125 | 240 | 333 | 643 | 1.387 | 2.679 | 1.42 | 1.48 | 0.07 | between |
| k_blend | lv | 1375 | 125 / 250 / 500 | 1534 | 3034 | 6034 | 1.978 | 3.934 | 2.00 | 0.36 | 0.02 | compute-bound |
| k_bytemap | lv | 96 | 32 / 63 / 125 | 176 | 269 | 517 | 1.528 | 2.938 | 1.58 | 1.31 | 0.09 | between |
| k_clampr | lv | 250 | 125 / 250 / 500 | 512 | 762 | 1512 | 1.488 | 2.953 | 1.50 | 1.50 | 0.02 | between |
| k_cmul | lv | 567 | 63 / 125 / 250 | 846 | 1280 | 2530 | 1.513 | 2.991 | 1.53 | 1.32 | 0.03 | between |
| k_copy16 | lv | 126 | 63 / 125 / 250 | 329 | 391 | 766 | 1.188 | 2.328 | 1.20 | 1.98 | 0.05 | memory-bound at 32 |
| k_daxpy | lv | 1000 | 250 / 500 / 1000 | 1763 | 2513 | 5013 | 1.425 | 2.843 | 1.43 | 1.50 | 0.01 | between |
| k_dctop_fill | lv | 64 | 32 / 64 / 128 | 304 | 400 | 592 | 1.316 | 1.947 | 1.86 | 1.00 | 0.63 | scalar-dominated |
| k_dctop_sum | lv | 64 | 32 / 63 / 125 | 132 | 225 | 411 | 1.705 | 3.114 | 1.96 | 0.98 | 0.27 | compute-bound |
| k_ddot | lv | 1000 | 250 / 500 / 1000 | 1533 | 2533 | 5033 | 1.652 | 3.283 | 1.67 | 0.80 | 0.02 | between |
| k_dequant | lv | 500 | 125 / 250 / 500 | 641 | 1266 | 2516 | 1.975 | 3.925 | 2.00 | 0.75 | 0.02 | compute-bound |
| k_dgemv_n | lv | 2048 | 512 / 1024 / 2048 | 3537 | 5585 | 10705 | 1.579 | 3.027 | 1.66 | 0.80 | 0.12 | between |
| k_dgemv_t | lv | 2080 | 528 / 1056 / 2112 | 4386 | 5970 | 11186 | 1.361 | 2.550 | 1.43 | 1.49 | 0.16 | between |
| k_dger | lv | 2048 | 512 / 1024 / 2048 | 4299 | 5835 | 10955 | 1.357 | 2.548 | 1.42 | 1.50 | 0.16 | between |
| k_dot16 | lv | 189 | 63 / 125 / 250 | 347 | 533 | 1033 | 1.536 | 2.977 | 1.59 | 1.32 | 0.09 | between |
| k_dscal | lv | 750 | 250 / 500 / 1000 | 1261 | 2011 | 4011 | 1.595 | 3.181 | 1.60 | 1.33 | 0.01 | between |
| k_fmac | lv | 500 | 125 / 250 / 500 | 888 | 1263 | 2513 | 1.422 | 2.830 | 1.43 | 1.50 | 0.01 | between |
| k_i2f | lv | 500 | 125 / 250 / 500 | 640 | 1265 | 2515 | 1.977 | 3.930 | 2.00 | 1.00 | 0.02 | compute-bound |
| k_isum | lv | 250 | 125 / 250 / 500 | 407 | 782 | 1532 | 1.921 | 3.764 | 2.00 | 1.00 | 0.08 | compute-bound |
| k_maskblend | lv | 192 | 32 / 63 / 125 | 308 | 463 | 897 | 1.503 | 2.912 | 1.54 | 1.31 | 0.07 | between |
| k_mix16 | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_mla32 | lv | 625 | 125 / 250 / 500 | 1147 | 1522 | 3022 | 1.327 | 2.635 | 1.33 | 1.60 | 0.02 | between |
| k_mulh16 | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_prep8 | lv | 189 | 63 / 125 / 250 | 267 | 515 | 1015 | 1.929 | 3.801 | 1.98 | 0.99 | 0.05 | compute-bound |
| k_q15mul | lv | 252 | 63 / 125 / 250 | 457 | 643 | 1268 | 1.407 | 2.775 | 1.42 | 1.49 | 0.04 | between |
| k_q8blk | lv | 93 | 31 / 62 / 124 | 779 | 872 | 1120 | 1.119 | 1.438 | 1.50 | 1.33 | 0.76 | scalar-dominated |
| k_q8dot | lv | 96 | 32 / 63 / 125 | 192 | 285 | 533 | 1.484 | 2.776 | 1.58 | 1.31 | 0.17 | between |
| k_quant | lv | 500 | 125 / 250 / 500 | 638 | 1263 | 2513 | 1.980 | 3.939 | 2.00 | 0.75 | 0.02 | compute-bound |
| k_relu | lv | 375 | 125 / 250 / 500 | 642 | 1017 | 2017 | 1.584 | 3.142 | 1.60 | 1.33 | 0.02 | between |
| k_rmsnorm | lv | 375 | 125 / 250 / 500 | 7648 | 8023 | 9023 | 1.049 | 1.180 | 1.60 | 0.50 | 0.92 | scalar-dominated |
| k_sad | lv | 96 | 32 / 64 / 128 | 438 | 534 | 790 | 1.219 | 1.804 | 1.55 | 1.33 | 0.60 | scalar-dominated |
| k_sadrow | lv | 96 | 32 / 63 / 125 | 192 | 285 | 533 | 1.484 | 2.776 | 1.58 | 1.31 | 0.17 | between |
| k_saxpy | lv | 500 | 125 / 250 / 500 | 888 | 1263 | 2513 | 1.422 | 2.830 | 1.43 | 1.50 | 0.01 | between |
| k_sdot | lv | 500 | 125 / 250 / 500 | 784 | 1284 | 2534 | 1.638 | 3.232 | 1.67 | 0.80 | 0.04 | between |
| k_sgemm_nt | lv | 2048 | 512 / 1024 / 2048 | 3986 | 6034 | 11154 | 1.514 | 2.798 | 1.65 | 0.80 | 0.21 | between |
| k_softmax | lv | 64 | 32 / 64 / 128 | 3464 | 3560 | 3752 | 1.028 | 1.083 | 1.99 | 1.00 | 0.97 | scalar-dominated |
| k_split | lv | 189 | 63 / 125 / 250 | 601 | 663 | 1038 | 1.103 | 1.727 | 1.11 | 2.65 | 0.06 | memory-bound at 32 |
| k_thresh | lv | 750 | 125 / 250 / 500 | 899 | 1774 | 3524 | 1.973 | 3.920 | 2.00 | 0.67 | 0.03 | compute-bound |
| k_vtx | lv | 3000 | 125 / 250 / 500 | 3347 | 6472 | 12722 | 1.934 | 3.801 | 2.00 | 1.00 | 0.07 | compute-bound |
| k_vtxaos | lv | 576 | 32 / 63 / 125 | 653 | 1242 | 2420 | 1.902 | 3.706 | 1.97 | 0.87 | 0.07 | compute-bound |

### Summary at port 16, commit 1 (geometric mean and worst case of cycles(strip) / cycles(32) over the kernels with a block)

| set | kernels | geomean 16 | geomean 8 | worst 16 | worst 8 |
|---|---:|---:|---:|---|---|
| all with a block | 41 | 1.504 | 2.757 | k_quant 1.980 | k_quant 3.939 |
| lv only | 40 | 1.509 | 2.774 | k_quant 1.980 | k_quant 3.939 |
| hand-written only | 1 | 1.314 | 2.150 | k_sad 1.314 | k_sad 2.150 |
| not scalar-dominated | 36 | 1.562 | 3.014 | k_quant 1.980 | k_quant 3.939 |
| compute-bound | 10 | 1.926 | 3.775 | k_quant 1.980 | k_quant 3.939 |
| memory-bound at 32 | 2 | 1.145 | 2.005 | k_copy16 1.188 | k_copy16 2.328 |
| between | 24 | 1.469 | 2.838 | k_ddot 1.652 | k_ddot 3.283 |
| scalar-dominated | 5 | 1.141 | 1.452 | k_dctop_fill 1.316 | k_dctop_fill 1.947 |

Class (at port 16): compute-bound = the vector cycles double at both halvings (ratio 1.9 or more); memory-bound at 32 = the vector cycles hardly change from 32 to 16 (1.2 or less: a commit cost of 1 a strip is the allowance); between = the rest; scalar-dominated = more than half of the cycles at strip 32 are scalar instructions.

### Memory-bound or compute-bound, by port and by step (of the 36 kernels with a block that are not scalar-dominated at strip 32; the vector cycles when the strip halves: unchanged = ratio 1.2 or less, doubles = 1.9 or more)

| port | 32 to 16: unchanged / between / doubles | 16 to 8: unchanged / between / doubles | 64 to 32 (the vector cycles when the strip doubles back): unchanged / between / doubles |
|---:|---|---|---|
| 8 | 31 / 4 / 1 | 2 / 20 / 14 | 35 / 0 / 1 |
| 16 | 2 / 24 / 10 | 0 / 1 / 35 | 26 / 9 / 1 |
| 32 | 0 / 6 / 30 | 0 / 0 / 36 | 2 / 24 / 10 |

### Sensitivity: geometric mean (and worst) slowdown against strip 32 of the same port and commit, over the 41 kernels with a block

| port (bytes a cycle) | commit | strip 16 | strip 8 | strip 64 (cycles against strip 32: below 1 is faster) |
|---:|---:|---|---|---|
| 8 | 1 | 1.139 (worst 1.978) | 1.783 (worst 3.934) | 0.941 (fastest 0.515) |
| 16 | 0 | 1.431 (worst 1.976) | 2.590 (worst 3.928) | 0.928 (fastest 0.516) |
| 16 | 1 | 1.504 (worst 1.980) | 2.757 (worst 3.939) | 0.869 (fastest 0.515) |
| 16 | 2 | 1.556 (worst 1.983) | 2.879 (worst 3.949) | 0.827 (fastest 0.514) |
| 32 | 1 | 1.746 (worst 1.990) | 3.218 (worst 3.969) | 0.690 (fastest 0.514) |

### Per kernel at the other ports (cycles at strip 32, slowdown at strip 16 and 8 against strip 32), commit 1

| kernel | build | cycles 32 (port 8) | slow 16 | slow 8 | cycles 32 (port 32) | slow 16 | slow 8 |
|---|---|---:|---:|---:|---:|---:|---:|
| k_sad | hand | 434 | 1.074 | 1.516 | 274 | 1.467 | 2.401 |
| k_avg8 | lv | 426 | 1.073 | 1.509 | 178 | 1.871 | 3.612 |
| k_blend | lv | 1534 | 1.978 | 3.934 | 1534 | 1.978 | 3.934 |
| k_bytemap | lv | 300 | 1.103 | 1.723 | 145 | 1.855 | 3.566 |
| k_clampr | lv | 762 | 1.328 | 1.984 | 387 | 1.969 | 3.907 |
| k_cmul | lv | 1593 | 1.039 | 1.588 | 660 | 1.939 | 3.833 |
| k_copy16 | lv | 579 | 1.107 | 1.323 | 205 | 1.907 | 3.737 |
| k_daxpy | lv | 3263 | 1.077 | 1.536 | 1263 | 1.990 | 3.969 |
| k_dctop_fill | lv | 368 | 1.087 | 1.609 | 304 | 1.316 | 1.947 |
| k_dctop_sum | lv | 194 | 1.160 | 2.119 | 132 | 1.705 | 3.114 |
| k_ddot | lv | 2283 | 1.110 | 2.205 | 1533 | 1.652 | 3.283 |
| k_dequant | lv | 766 | 1.653 | 3.285 | 641 | 1.975 | 3.925 |
| k_dgemv_n | lv | 5073 | 1.101 | 2.110 | 3537 | 1.579 | 3.027 |
| k_dgemv_t | lv | 7490 | 1.070 | 1.493 | 3362 | 1.776 | 3.327 |
| k_dger | lv | 7371 | 1.069 | 1.486 | 3275 | 1.782 | 3.345 |
| k_dot16 | lv | 596 | 1.104 | 1.733 | 285 | 1.870 | 3.625 |
| k_dscal | lv | 2261 | 1.111 | 1.774 | 1011 | 1.989 | 3.967 |
| k_fmac | lv | 1638 | 1.076 | 1.534 | 638 | 1.980 | 3.939 |
| k_i2f | lv | 1140 | 1.110 | 2.206 | 640 | 1.977 | 3.930 |
| k_isum | lv | 657 | 1.190 | 2.332 | 407 | 1.921 | 3.764 |
| k_maskblend | lv | 556 | 1.056 | 1.613 | 246 | 1.882 | 3.646 |
| k_mix16 | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_mla32 | lv | 2147 | 1.058 | 1.408 | 772 | 1.972 | 3.915 |
| k_mulh16 | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_prep8 | lv | 453 | 1.137 | 2.241 | 267 | 1.929 | 3.801 |
| k_q15mul | lv | 831 | 1.075 | 1.526 | 333 | 1.931 | 3.808 |
| k_q8blk | lv | 903 | 1.034 | 1.240 | 748 | 1.166 | 1.497 |
| k_q8dot | lv | 316 | 1.098 | 1.687 | 161 | 1.770 | 3.311 |
| k_quant | lv | 763 | 1.655 | 3.294 | 638 | 1.980 | 3.939 |
| k_relu | lv | 1142 | 1.109 | 1.766 | 517 | 1.967 | 3.901 |
| k_rmsnorm | lv | 7648 | 1.049 | 1.180 | 7648 | 1.049 | 1.180 |
| k_sad | lv | 566 | 1.057 | 1.396 | 406 | 1.315 | 1.946 |
| k_sadrow | lv | 316 | 1.098 | 1.687 | 161 | 1.770 | 3.311 |
| k_saxpy | lv | 1638 | 1.076 | 1.534 | 638 | 1.980 | 3.939 |
| k_sdot | lv | 1159 | 1.108 | 2.186 | 784 | 1.638 | 3.232 |
| k_sgemm_nt | lv | 5522 | 1.093 | 2.020 | 3986 | 1.514 | 2.798 |
| k_softmax | lv | 3528 | 1.009 | 1.063 | 3464 | 1.028 | 1.083 |
| k_split | lv | 1101 | 1.056 | 1.170 | 352 | 1.528 | 2.949 |
| k_thresh | lv | 1149 | 1.544 | 3.067 | 899 | 1.973 | 3.920 |
| k_vtx | lv | 6347 | 1.020 | 2.004 | 3347 | 1.934 | 3.801 |
| k_vtxaos | lv | 1087 | 1.143 | 2.226 | 653 | 1.902 | 3.706 |

### Strips of 64 bytes (the speed-up over 32 at port 16, commit 1)

| kernel | build | cycles 32 | cycles 64 | speed-up |
|---|---|---:|---:|---:|
| k_sad | hand | 306 | 290 | 1.055 |
| k_avg8 | lv | 240 | 223 | 1.076 |
| k_blend | lv | 1534 | 790 | 1.942 |
| k_bytemap | lv | 176 | 159 | 1.107 |
| k_clampr | lv | 512 | 388 | 1.320 |
| k_cmul | lv | 846 | 815 | 1.038 |
| k_copy16 | lv | 329 | 298 | 1.104 |
| k_daxpy | lv | 1763 | 1638 | 1.076 |
| k_dctop_fill | lv | 304 | 288 | 1.056 |
| k_dctop_sum | lv | 132 | 115 | 1.148 |
| k_ddot | lv | 1533 | 1158 | 1.324 |
| k_dequant | lv | 641 | 393 | 1.631 |
| k_dgemv_n | lv | 3537 | 2769 | 1.277 |
| k_dgemv_t | lv | 4386 | 4122 | 1.064 |
| k_dger | lv | 4299 | 4043 | 1.063 |
| k_dot16 | lv | 347 | 316 | 1.098 |
| k_dscal | lv | 1261 | 1136 | 1.110 |
| k_fmac | lv | 888 | 826 | 1.075 |
| k_i2f | lv | 640 | 578 | 1.107 |
| k_isum | lv | 407 | 345 | 1.180 |
| k_maskblend | lv | 308 | 290 | 1.062 |
| k_mix16 | lv | 457 | 426 | 1.073 |
| k_mla32 | lv | 1147 | 1085 | 1.057 |
| k_mulh16 | lv | 457 | 426 | 1.073 |
| k_prep8 | lv | 267 | 236 | 1.131 |
| k_q15mul | lv | 457 | 426 | 1.073 |
| k_q8blk | lv | 779 | 779 | 1.000 |
| k_q8dot | lv | 192 | 175 | 1.097 |
| k_quant | lv | 638 | 390 | 1.636 |
| k_relu | lv | 642 | 580 | 1.107 |
| k_rmsnorm | lv | 7648 | 7462 | 1.025 |
| k_sad | lv | 438 | 422 | 1.038 |
| k_sadrow | lv | 192 | 175 | 1.097 |
| k_saxpy | lv | 888 | 826 | 1.075 |
| k_sdot | lv | 784 | 598 | 1.311 |
| k_sgemm_nt | lv | 3986 | 3218 | 1.239 |
| k_softmax | lv | 3464 | 3448 | 1.005 |
| k_split | lv | 601 | 570 | 1.054 |
| k_thresh | lv | 899 | 589 | 1.526 |
| k_vtx | lv | 3347 | 3285 | 1.019 |
| k_vtxaos | lv | 653 | 561 | 1.164 |
