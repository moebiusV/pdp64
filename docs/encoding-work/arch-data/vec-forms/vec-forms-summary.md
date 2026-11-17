## pdp64: pcc scalar code and the hand-written vec forms

| kernel | pcc scalar: function instructions | pcc scalar: inner loop instructions (per element) | vec form: instructions of the function | of them in the vec block | block operations per element (256-bit strip) |
|---|---:|---|---:|---:|---:|
| k_prep8 | 8 | 5 | 7 | 3 | 0.19 |
| k_put8h | 51 | 48 | 31 | 19 | 2.38 |
| k_dctop_sum | 21 | 4, 6 | 9 | 1 | 0.03 |
| k_dctop_fill | 11 | 3 | 9 | 1 | 0.03 |
| k_fmac | 10 | 7 | 8 | 4 | 0.50 |
| k_sad | 26 | 7 | 18 | 4 | 0.25 |
| k_hist | 26 | 24 | 11 | 8 | 2.00 |
| k_ssm | 33 | 19 | 18 | 12 | 1.50 |
| k_put8h, form B (sliding window `vfir`) | 51 | 48 | 17 | 5 | 0.62 |

## Compiled by clang: the vectorized build and the scalar build, per instruction set

Instructions of the whole function (every path), instructions of the main loop, the vectorization width x interleave count that the compiler reports, and the main loop per element. The float kernels are at -Ofast, the others at -O3.

| kernel | target | function: vector build | function: scalar build | main loop | width x interleave | main loop instructions per element |
|---|---|---:|---:|---:|---|---:|
| k_prep8 | x86-avx2 | 55 | 12 | 7 | 16 x 1 | 0.44 |
| k_prep8 | x86-avx512 | 54 | 12 | 6 | 32 x 1 | 0.19 |
| k_prep8 | aarch64-neon | 53 | 9 | 6 | 16 x 1 | 0.38 |
| k_prep8 | aarch64-sve | 57 | 9 | 6 | 16 x 1 | 0.38 |
| k_prep8 | riscv-v | 47 | 10 | 6 | scalable x8 (interleave 1) | scalable: 6 per strip of VL elements (x8) |
| k_prep8 | loongarch-lasx | 39 | 12 | 9 | 8 x 1 | 1.12 |
| k_put8h | x86-avx2 | 264 | 55 | 114 | 32 x 1 | 3.56 |
| k_put8h | x86-avx512 | 251 | 51 | 115 | 64 x 1 | 1.80 |
| k_put8h | aarch64-neon | 155 | 39 | 61 | 8 x 1 | 7.62 |
| k_put8h | aarch64-sve | 122 | 39 | 53 | scalable x8 (interleave 1) | scalable: 53 per strip of VL elements (x8) |
| k_put8h | riscv-v | 220 | 58 | 85 | scalable x16 (interleave 1) | scalable: 85 per strip of VL elements (x16) |
| k_put8h | loongarch-lasx | 176 | 49 | 50 | 4 x 1 | 12.50 |
| k_dctop_sum | x86-avx2 | 38 | 15 | 5 | 8 x 1 | 0.62 |
| k_dctop_sum | x86-avx512 | 63 | 15 | 5 | 16 x 1 | 0.31 |
| k_dctop_sum | aarch64-neon | 63 | 12 | 9 | 16 x 1 | 0.56 |
| k_dctop_sum | aarch64-sve | 59 | 12 | 5 | 16 x 1 | 0.31 |
| k_dctop_sum | riscv-v | 54 | 19 | 6 | scalable x4 (interleave 1) | scalable: 6 per strip of VL elements (x4) |
| k_dctop_sum | loongarch-lasx | 44 | 12 | 8 | 4 x 1 | 2.00 |
| k_dctop_fill | x86-avx2 | 28 | 28 | 7 | - | 7 (not vectorized) |
| k_dctop_fill | x86-avx512 | 28 | 28 | 7 | - | 7 (not vectorized) |
| k_dctop_fill | aarch64-neon | 26 | 26 | 1 | - | 1 (not vectorized) |
| k_dctop_fill | aarch64-sve | 26 | 26 | 1 | - | 1 (not vectorized) |
| k_dctop_fill | riscv-v | 30 | 30 | 2 | - | 2 (not vectorized) |
| k_dctop_fill | loongarch-lasx | 32 | 32 | 8 | - | 8 (not vectorized) |
| k_fmac | x86-avx2 | 43 | 12 | 6 | 8 x 1 | 0.75 |
| k_fmac | x86-avx512 | 60 | 12 | 6 | 16 x 1 | 0.38 |
| k_fmac | aarch64-neon | 37 | 10 | 6 | 4 x 1 | 1.50 |
| k_fmac | aarch64-sve | 43 | 10 | 7 | scalable x4 (interleave 1) | scalable: 7 per strip of VL elements (x4) |
| k_fmac | riscv-v | 49 | 11 | 7 | scalable x4 (interleave 1) | scalable: 7 per strip of VL elements (x4) |
| k_fmac | loongarch-lasx | 38 | 13 | 8 | 8 x 1 | 1.00 |
| k_sad | x86-avx2 | 69 | 36 | 11 | 8 x 1 | 1.38 |
| k_sad | x86-avx512 | 97 | 36 | 11 | 16 x 1 | 0.69 |
| k_sad | aarch64-neon | 79 | 24 | 12 | 16 x 1 | 0.75 |
| k_sad | aarch64-sve | 84 | 24 | 12 | 16 x 1 | 0.75 |
| k_sad | riscv-v | 89 | 29 | 12 | scalable x4 (interleave 1) | scalable: 12 per strip of VL elements (x4) |
| k_sad | loongarch-lasx | 60 | 27 | 10 | 4 x 1 | 2.50 |
| k_hist | x86-avx2 | 18 | 21 | 11 | - | 14 (not vectorized) |
| k_hist | x86-avx512 | 18 | 21 | 11 | - | 14 (not vectorized) |
| k_hist | aarch64-neon | 21 | 23 | 11 | - | 13 (not vectorized) |
| k_hist | aarch64-sve | 21 | 23 | 11 | - | 13 (not vectorized) |
| k_hist | riscv-v | 25 | 27 | 16 | - | 19 (not vectorized) |
| k_hist | loongarch-lasx | 28 | 28 | 19 | - | 19 (not vectorized) |
| k_ssm | x86-avx2 | 152 | 46 | 54 | 8 x 1 | 6.75 |
| k_ssm | x86-avx512 | 256 | 46 | 98 | 16 x 1 | 6.12 |
| k_ssm | aarch64-neon | 124 | 40 | 1 | 4 x 1 | (loop not found: it holds calls) |
| k_ssm | aarch64-sve | 124 | 40 | 1 | 4 x 1 | (loop not found: it holds calls) |
| k_ssm | riscv-v | 198 | 53 | 2 | 4 x 1 | (loop not found: it holds calls) |
| k_ssm | loongarch-lasx | 208 | 56 | 89 | 8 x 1 | 11.12 |

## Hand-written assembly, the same functions

| ISA | function | instructions | bytes |
|---|---|---:|---:|
| x86 | ff_vector_fmac_scalar_sse | 22 | 96 |
| x86 | ff_vector_fmac_scalar_avx | 14 | 64 |
| x86 | ff_vector_fmac_scalar_fma3 | 15 | 80 |
| a64 | ff_vector_fmac_scalar_neon | 16 | 56 |
| rv | ff_vector_fmac_scalar_rvv | 12 | 44 |
| x86 | ff_pixelutils_sad_16x16_sse2 | 81 | 336 |
| x86 | ff_pixelutils_sad_a_16x16_sse2 | 65 | 272 |
| x86 | ff_pixelutils_sad_32x32_avx2 | 27 | 129 |
| a64 | ff_pixelutils_sad16_neon | 28 | 100 |
| a64 | ff_pixelutils_sad32_neon | 37 | 148 |
| x86 | _dav1d_ipred_dc_top_8bpc_avx2 | 16 | 64 |
| x86 | _dav1d_ipred_dc_top_8bpc_avx512icl | 16 | 80 |
| x86 | _dav1d_ipred_dc_top_8bpc_ssse3 | 15 | 64 |
| a64 | dav1d_ipred_dc_top_8bpc_neon | 77 | 308 |
| rv | dav1d_ipred_dc_top_8bpc_rvv | 9 | 20 |
