47 programs ran (46 `lv`, 1 hand-written: k_sad; dropped as strip-bench does: k_dctop_fill k_fmac); 41 have a vec block; without: k_put8h k_hist k_ssm k_q4dot k_gray k_clamp8.
280 runs a program over 280 configurations. Results (exit status and a hash of every global array) identical over all configurations: 47 of 47 programs; identical to a run without -V (no model): 47 of 47.

### Per kernel, strip 32, port 16, commit 1: cycles in model 1 and model 2 (fpga and asic table, vpipe 1, vmemlat 4)

| kernel | build | strips | vec instrs | scalar | model 1 total | model 2 fpga | ratio | model 2 asic | ratio | fpga, vpipe 2 | fpga, vpipe 4 | hidden-acc blocks | scalar-dep blocks | mix (instrs at strip 32, classes with 5% or more of the block's instructions) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| k_sad | hand | 32 | 96 | 130 | 306 | 466 | 1.523 | 1202 | 3.928 | 434 | 434 | 0 | 0 | ld 64 sad 32 |
| k_avg8 | lv | 32 | 128 | 17 | 240 | 463 | 1.929 | 1647 | 6.862 | 432 | 432 | 0 | 0 | ld 64 alu 32 st 32 |
| k_blend | lv | 125 | 1375 | 33 | 1534 | 3159 | 2.059 | 19909 | 12.978 | 3035 | 3035 | 0 | 0 | alu 375 ld 375 shift 250 mul32 250 st 125 |
| k_bytemap | lv | 32 | 96 | 16 | 176 | 399 | 2.267 | 1583 | 8.994 | 368 | 368 | 0 | 0 | alu 32 ld 32 st 32 |
| k_clampr | lv | 125 | 250 | 11 | 512 | 1137 | 2.221 | 2137 | 4.174 | 765 | 765 | 0 | 0 | ld 125 st 125 |
| k_cmul | lv | 63 | 567 | 29 | 846 | 3363 | 3.975 | 15711 | 18.571 | 3239 | 3239 | 0 | 0 | fma 252 alu 126 lseg 126 sseg 63 |
| k_copy16 | lv | 63 | 126 | 15 | 329 | 518 | 1.574 | 770 | 2.340 | 456 | 456 | 0 | 0 | ld 63 st 63 |
| k_daxpy | lv | 250 | 1000 | 12 | 1763 | 4013 | 2.276 | 17013 | 9.650 | 3764 | 3764 | 0 | 0 | ld 500 fma64 250 st 250 |
| k_dctop_fill | lv | 32 | 64 | 192 | 304 | 432 | 1.421 | 1552 | 5.105 | 400 | 400 | 0 | 0 | alu 32 st 32 |
| k_dctop_sum | lv | 32 | 64 | 35 | 132 | 291 | 2.205 | 931 | 7.053 | 229 | 229 | 0 | 0 | acc 32 ld 32 |
| k_ddot | lv | 250 | 1000 | 32 | 1283 | 4033 | 3.143 | 21033 | 16.394 | 3535 | 3535 | 0 | 0 | ld 500 acc 250 fma64 250 |
| k_dequant | lv | 125 | 500 | 15 | 641 | 2516 | 3.925 | 11766 | 18.356 | 2392 | 2392 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_dgemv_n | lv | 512 | 2048 | 433 | 3025 | 8657 | 2.862 | 43473 | 14.371 | 7697 | 7697 | 0 | 0 | ld 1024 acc 512 fma64 512 |
| k_dgemv_t | lv | 528 | 2080 | 721 | 4386 | 9058 | 2.065 | 36242 | 8.263 | 8548 | 8548 | 0 | 0 | ld 1024 st 528 fma64 512 |
| k_dger | lv | 512 | 2048 | 683 | 4299 | 8907 | 2.072 | 35531 | 8.265 | 8427 | 8427 | 0 | 0 | ld 1024 fma64 512 st 512 |
| k_dot16 | lv | 63 | 189 | 32 | 347 | 850 | 2.450 | 2614 | 7.533 | 540 | 540 | 0 | 0 | ld 126 dacc 63 |
| k_dscal | lv | 250 | 750 | 10 | 1261 | 3511 | 2.784 | 16511 | 13.094 | 3262 | 3262 | 0 | 0 | fma64 250 ld 250 st 250 |
| k_fmac | lv | 125 | 500 | 12 | 888 | 2513 | 2.830 | 9513 | 10.713 | 2389 | 2389 | 0 | 0 | ld 250 fma 125 st 125 |
| k_i2f | lv | 125 | 500 | 14 | 640 | 2640 | 4.125 | 11890 | 18.578 | 2516 | 2516 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_isum | lv | 125 | 250 | 31 | 407 | 1032 | 2.536 | 3532 | 8.678 | 784 | 784 | 0 | 0 | acc 125 ld 125 |
| k_maskblend | lv | 32 | 192 | 21 | 308 | 466 | 1.513 | 690 | 2.240 | 435 | 435 | 0 | 0 | ld 96 cmp 32 bsl 32 st 32 |
| k_mix16 | lv | 63 | 252 | 17 | 457 | 897 | 1.963 | 3228 | 7.063 | 835 | 835 | 0 | 0 | ld 126 alu 63 st 63 |
| k_mla32 | lv | 125 | 625 | 21 | 1147 | 1897 | 1.654 | 4147 | 3.616 | 1773 | 1773 | 0 | 0 | ld 375 mul32 125 st 125 |
| k_mulh16 | lv | 63 | 252 | 17 | 457 | 834 | 1.825 | 1590 | 3.479 | 772 | 772 | 0 | 0 | ld 126 mulh16 63 st 63 |
| k_prep8 | lv | 63 | 189 | 14 | 267 | 581 | 2.176 | 1967 | 7.367 | 519 | 519 | 0 | 0 | shift 63 ld 63 st 63 |
| k_q15mul | lv | 63 | 252 | 17 | 457 | 834 | 1.825 | 1590 | 3.479 | 772 | 772 | 0 | 0 | ld 126 mulh16 63 st 63 |
| k_q8blk | lv | 31 | 93 | 593 | 779 | 1027 | 1.318 | 1895 | 2.433 | 1027 | 1027 | 0 | 0 | ld 62 dacc 31 |
| k_q8dot | lv | 32 | 96 | 32 | 192 | 447 | 2.328 | 1343 | 6.995 | 292 | 292 | 0 | 0 | ld 64 dacc 32 |
| k_quant | lv | 125 | 500 | 12 | 638 | 2763 | 4.331 | 12513 | 19.613 | 2391 | 2391 | 0 | 0 | cvt 125 fma 125 ld 125 st 125 |
| k_relu | lv | 125 | 375 | 16 | 642 | 1517 | 2.363 | 6142 | 9.567 | 1393 | 1393 | 0 | 0 | alu 125 ld 125 st 125 |
| k_rmsnorm | lv | 125 | 375 | 7022 | 7523 | 9273 | 1.233 | 18273 | 2.429 | 9025 | 9025 | 0 | 0 | acc 125 fma 125 ld 125 |
| k_sad | lv | 32 | 96 | 262 | 438 | 598 | 1.365 | 1334 | 3.046 | 566 | 566 | 0 | 0 | ld 64 sad 32 |
| k_sadrow | lv | 32 | 96 | 32 | 192 | 351 | 1.828 | 1087 | 5.661 | 289 | 289 | 0 | 0 | ld 64 sad 32 |
| k_saxpy | lv | 125 | 500 | 12 | 888 | 2513 | 2.830 | 9513 | 10.713 | 2389 | 2389 | 0 | 0 | ld 250 fma 125 st 125 |
| k_sdot | lv | 125 | 500 | 33 | 659 | 2534 | 3.845 | 11534 | 17.502 | 2286 | 2286 | 0 | 0 | ld 250 acc 125 fma 125 |
| k_sgemm_nt | lv | 512 | 2048 | 850 | 3474 | 11154 | 3.211 | 48018 | 13.822 | 10258 | 10258 | 0 | 0 | ld 1024 acc 512 fma 512 |
| k_softmax | lv | 32 | 64 | 3367 | 3464 | 4136 | 1.194 | 5608 | 1.619 | 3758 | 3578 | 0 | 0 | mmacc 32 ld 32 |
| k_split | lv | 63 | 189 | 37 | 601 | 853 | 1.419 | 1168 | 1.943 | 791 | 791 | 0 | 0 | st 126 lseg 63 |
| k_thresh | lv | 125 | 750 | 23 | 899 | 1649 | 1.834 | 2399 | 2.669 | 1525 | 1525 | 0 | 0 | ld 375 cmp 125 bsl 125 st 125 |
| k_vtx | lv | 125 | 3000 | 221 | 3347 | 18722 | 5.594 | 97722 | 29.197 | 18598 | 18598 | 0 | 0 | fma 1500 ld 1125 st 375 |
| k_vtxaos | lv | 32 | 576 | 44 | 653 | 4161 | 6.372 | 22081 | 33.815 | 4099 | 4099 | 0 | 0 | fma 384 alu 128 lseg 32 sseg 32 |

### Geometric mean of model 2 / model 1 cycles over the 41 kernels with a block, strip 32, port 16 (worst case in brackets)

| table | vmemlat | vpipe 1 | vpipe 2 | vpipe 4 |
|---|---:|---|---|---|
| fpga | 2 | 1.996 (k_vtxaos 6.274; best 1.176) | 1.750 (k_vtxaos 6.179; best 1.003) | 1.748 (k_vtxaos 6.179; best 1.003) |
| fpga | 4 | 2.289 (k_vtxaos 6.372; best 1.194) | 2.054 (k_vtxaos 6.277; best 1.085) | 2.052 (k_vtxaos 6.277; best 1.033) |
| fpga | 8 | 2.851 (k_vtxaos 6.568; best 1.231) | 2.627 (k_vtxaos 6.473; best 1.105) | 2.625 (k_vtxaos 6.473; best 1.070) |
| asic | 2 | 6.858 (k_vtxaos 33.717; best 1.600) | 5.612 (k_vtxaos 33.432; best 1.288) | 5.172 (k_vtxaos 33.432; best 1.135) |
| asic | 4 | 7.206 (k_vtxaos 33.815; best 1.619) | 5.937 (k_vtxaos 33.530; best 1.298) | 5.542 (k_vtxaos 33.530; best 1.141) |
| asic | 8 | 7.866 (k_vtxaos 34.011; best 1.656) | 6.565 (k_vtxaos 33.726; best 1.318) | 6.293 (k_vtxaos 33.726; best 1.154) |

### Slowdown of a narrower strip against strip 32 (cycles(strip) / cycles(32), same port and parameters): geometric mean (worst kernel)

| model | table | vpipe | vmemlat | port | strip 16 | strip 8 |
|---|---|---:|---:|---:|---|---|
| 1 | - | - | - | 8 | 1.139 (k_blend 1.978) | 1.783 (k_blend 3.934) |
| 2 | fpga | 1 | 4 | 8 | 1.414 (k_blend 1.989) | 2.379 (k_blend 3.968) |
| 2 | fpga | 4 | 4 | 8 | 1.423 (k_blend 1.988) | 2.252 (k_blend 3.965) |
| 2 | asic | 1 | 4 | 8 | 1.715 (k_blend 1.986) | 3.053 (k_blend 3.945) |
| 2 | asic | 4 | 4 | 8 | 1.635 (k_blend 1.998) | 2.866 (k_blend 3.994) |
| 1 | - | - | - | 16 | 1.528 (k_quant 1.980) | 2.802 (k_quant 3.939) |
| 2 | fpga | 1 | 2 | 16 | 1.539 (k_blend 1.989) | 2.864 (k_blend 3.966) |
| 2 | fpga | 1 | 4 | 16 | 1.595 (k_blend 1.989) | 2.993 (k_blend 3.968) |
| 2 | fpga | 1 | 8 | 16 | 1.668 (k_thresh 1.991) | 3.160 (k_thresh 3.973) |
| 2 | fpga | 4 | 4 | 16 | 1.553 (k_blend 1.988) | 2.898 (k_blend 3.965) |
| 2 | asic | 1 | 2 | 16 | 1.771 (k_blend 1.986) | 3.305 (k_blend 3.944) |
| 2 | asic | 1 | 4 | 16 | 1.786 (k_blend 1.986) | 3.348 (k_blend 3.945) |
| 2 | asic | 1 | 8 | 16 | 1.807 (k_blend 1.986) | 3.413 (k_blend 3.946) |
| 2 | asic | 4 | 4 | 16 | 1.730 (k_blend 1.998) | 3.248 (k_blend 3.994) |
| 1 | - | - | - | 32 | 1.775 (k_daxpy 1.990) | 3.271 (k_daxpy 3.969) |
| 2 | fpga | 1 | 4 | 32 | 1.832 (k_dscal 1.996) | 3.454 (k_dscal 3.989) |
| 2 | fpga | 4 | 4 | 32 | 1.817 (k_dscal 1.996) | 3.408 (k_dscal 3.987) |
| 2 | asic | 1 | 4 | 32 | 1.875 (k_dot16 2.021) | 3.524 (k_vtx 3.983) |
| 2 | asic | 4 | 4 | 32 | 1.845 (k_dscal 1.999) | 3.473 (k_dscal 3.997) |

### Memory-bound or compute-bound (the vector cycles when the strip halves from 32 to 16: unchanged = ratio 1.2 or less, doubles = 1.9 or more), kernels with a block that are not scalar-dominated at strip 32 in model 1

36 kernels. | model | port | unchanged / between / doubles |
|---|---:|---|
| model 1 | 8 | 31 / 4 / 1 |
| model 2, fpga, vpipe 1 | 8 | 3 / 32 / 1 |
| model 2, fpga, vpipe 4 | 8 | 1 / 34 / 1 |
| model 2, asic, vpipe 1 | 8 | 0 / 27 / 9 |
| model 2, asic, vpipe 4 | 8 | 1 / 29 / 6 |
| model 1 | 16 | 2 / 20 / 14 |
| model 2, fpga, vpipe 1 | 16 | 0 / 34 / 2 |
| model 2, fpga, vpipe 4 | 16 | 0 / 34 / 2 |
| model 2, asic, vpipe 1 | 16 | 0 / 21 / 15 |
| model 2, asic, vpipe 4 | 16 | 0 / 16 / 20 |
| model 1 | 32 | 0 / 2 / 34 |
| model 2, fpga, vpipe 1 | 32 | 0 / 4 / 32 |
| model 2, fpga, vpipe 4 | 32 | 0 / 3 / 33 |
| model 2, asic, vpipe 1 | 32 | 0 / 9 / 27 |
| model 2, asic, vpipe 4 | 32 | 0 / 4 / 32 |

### Sensitivity to the latency table: geometric mean of model 2 / model 1 over the kernels with a block, port 16, vpipe 1, vmemlat 4

| table | strip 8 | strip 16 | strip 32 |
|---|---|---|---|
| unit | 1.572 | 1.555 | 1.526 |
| fpga-lo | 2.069 | 2.038 | 1.939 |
| fpga | 2.445 | 2.389 | 2.289 |
| fpga-hi | 2.749 | 2.913 | 2.706 |
| asic-lo | 5.106 | 4.942 | 4.320 |
| asic | 8.612 | 8.421 | 7.206 |
| asic-hi | 16.280 | 16.146 | 13.575 |

Sanity check (model 2 with the unit table, 16 strips in flight, memory latency 1, strip 32, port 16) against model 1: geometric mean of model 2 / model 1 = 1.038, range 0.758 to 1.669 over the 41 kernels.

### Class sensitivity: one class set to latency 1 (ld, st: 0), all else as the table; geometric mean of cycles / cycles with the table, and the largest single-kernel gain; kernels that use the class; port 16, vpipe 1, vmemlat 4

| class | instrs run (all kernels, strip 32) | kernels using it | fpga strip 32: geomean (best kernel) | fpga strip 16 | asic strip 32 | asic strip 16 |
|---|---:|---:|---|---|---|---|
| alu | 929 | 9 | 0.9609 (k_relu 0.753) | 0.9504 (k_dctop_fill 0.676) | 0.8386 (k_dctop_fill 0.258) | 0.8122 (k_dctop_fill 0.168) |
| cmp | 157 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9964 (k_maskblend 0.861) | 0.9951 (k_maskblend 0.817) |
| bsl | 157 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) |
| shift | 313 | 2 | 0.9952 (k_prep8 0.892) | 0.9948 (k_prep8 0.877) | 0.9709 (k_prep8 0.391) | 0.9680 (k_prep8 0.348) |
| narrow | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mul8 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mul16 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| mulh16 | 126 | 2 | 0.9920 (k_mulh16 0.849) | 0.9893 (k_mulh16 0.803) | 0.9757 (k_mulh16 0.604) | 0.9692 (k_mulh16 0.527) |
| mul32 | 375 | 2 | 0.9924 (k_blend 0.842) | 0.9910 (k_mla32 0.820) | 0.9787 (k_mla32 0.518) | 0.9743 (k_mla32 0.430) |
| mul64 | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| dot | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| dacc | 126 | 3 | 0.9803 (k_dot16 0.704) | 0.9741 (k_dot16 0.645) | 0.9246 (k_dot16 0.277) | 0.9096 (k_dot16 0.230) |
| sad | 96 | 3 | 0.9946 (k_sadrow 0.909) | 0.9924 (k_sadrow 0.883) | 0.9369 (k_sadrow 0.352) | 0.9279 (k_sadrow 0.323) |
| acc | 1681 | 7 | 0.9883 (k_isum 0.879) | 0.9862 (k_isum 0.860) | 0.9231 (k_isum 0.328) | 0.9171 (k_isum 0.300) |
| mmacc | 32 | 1 | 0.9966 (k_softmax 0.868) | 0.9969 (k_softmax 0.880) | 0.9896 (k_softmax 0.652) | 0.9900 (k_softmax 0.662) |
| fir | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| tbl | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
| lseg | 221 | 3 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9985 (k_split 0.946) | 0.9980 (k_split 0.925) |
| sseg | 95 | 2 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9997 (k_cmul 0.992) | 0.9997 (k_cmul 0.992) |
| cvt | 375 | 3 | 0.9927 (k_dequant 0.901) | 0.9921 (k_i2f 0.895) | 0.9831 (k_dequant 0.788) | 0.9826 (k_i2f 0.783) |
| fma | 3523 | 11 | 0.8456 (k_vtxaos 0.323) | 0.8183 (k_vtxaos 0.271) | 0.6977 (k_vtx 0.091) | 0.6751 (k_vtx 0.074) |
| fma64 | 2286 | 6 | 0.9476 (k_dscal 0.644) | 0.9343 (k_dscal 0.584) | 0.8242 (k_dscal 0.198) | 0.8029 (k_dscal 0.159) |
| ld | 10425 | 37 | 1.0000 (k_avg8 1.000) | 1.0000 (k_avg8 1.000) | 0.9518 (k_thresh 0.792) | 0.9441 (k_thresh 0.779) |
| st | 3734 | 25 | 0.9606 (k_copy16 0.880) | 1.0000 (k_avg8 1.000) | 0.9512 (k_copy16 0.756) | 0.9786 (k_clampr 0.867) |
| misc | 0 | 0 | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) | 1.0000 (-) |
