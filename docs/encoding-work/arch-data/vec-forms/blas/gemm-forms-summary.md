## pdp64: pcc scalar code and the hand-written vec forms (BLAS of cugpt and cngpt)

| kernel | pcc scalar: function instructions | pcc scalar: inner loop per multiply-add or element | vec form: function | in the block | block operations per element (256-bit strip: 4 doubles) |
|---|---:|---|---:|---:|---:|
| k_ddot | 10 | 5 | 10 | 4 | 1.00 |
| k_daxpy | 10 | 7 | 8 | 4 | 1.00 |
| k_dscal | 8 | 5 | 7 | 3 | 0.75 |
| k_dgemv_n | 17 | 8 | 13 | 4 | 1.00 |
| k_dgemv_t | 23 | 4, 10 | 15 | 7 | 1.75 |
| k_dger | 20 | 13 | 12 | 4 | 1.00 |

### `sgemm`, the linear layer of cngpt (Y = X . W^T), four forms

| form | instructions of the function | in the block | multiply-adds per strip of the block (VL = 8 floats) | block operations per multiply-add |
|---|---:|---:|---:|---:|
| pcc scalar (the triple loop) | 28 | inner loop 12 | 1 | 12 per multiply-add |
| 1. dot product for each output (`vec` over K) | 20 | 4 | 8 | 0.500 |
| 2. register-blocked micro-kernel (8 accumulators, broadcast multiply-add) | 48 | 9 | 64 | 0.141 |
| 3. micro-kernel with a hidden tile and an outer-product instruction | 14 | 3 | 64 | 0.047 |
| 4. the whole GEMM as one `lb64` instruction | 17 | (the unit) | all | 0 (a fixed 17 instructions of set-up for any size) |

### Compiled by clang (the BLAS loops, -Ofast)

| kernel | target | function: vector build | function: scalar build | main loop | width x interleave | main loop instructions per element |
|---|---|---:|---:|---:|---|---:|
| k_ddot | x86-avx2 | 38 | 14 | 5 | 4 x 1 | 1.25 |
| k_ddot | x86-avx512 | 40 | 14 | 5 | 8 x 1 | 0.62 |
| k_ddot | aarch64-neon | 33 | 10 | 5 | 2 x 1 | 2.50 |
| k_ddot | aarch64-sve | 38 | 10 | 6 | scalable x2 (interleave 1) | scalable: 6 per strip of VL elements (x2) |
| k_ddot | riscv-v | 46 | 13 | 6 | scalable x2 (interleave 1) | scalable: 6 per strip of VL elements (x2) |
| k_ddot | loongarch-lasx | 48 | 12 | 7 | 4 x 1 | 1.75 |
| k_daxpy | x86-avx2 | 43 | 12 | 6 | 4 x 1 | 1.50 |
| k_daxpy | x86-avx512 | 43 | 12 | 6 | 8 x 1 | 0.75 |
| k_daxpy | aarch64-neon | 37 | 10 | 6 | 2 x 1 | 3.00 |
| k_daxpy | aarch64-sve | 46 | 10 | 7 | scalable x2 (interleave 1) | scalable: 7 per strip of VL elements (x2) |
| k_daxpy | riscv-v | 49 | 11 | 7 | scalable x2 (interleave 1) | scalable: 7 per strip of VL elements (x2) |
| k_daxpy | loongarch-lasx | 38 | 13 | 8 | 4 x 1 | 2.00 |
| k_dscal | x86-avx2 | 31 | 11 | 5 | 4 x 1 | 1.25 |
| k_dscal | x86-avx512 | 31 | 11 | 5 | 8 x 1 | 0.62 |
| k_dscal | aarch64-neon | 25 | 9 | 5 | 2 x 1 | 2.50 |
| k_dscal | aarch64-sve | 32 | 9 | 6 | scalable x2 (interleave 1) | scalable: 6 per strip of VL elements (x2) |
| k_dscal | riscv-v | 35 | 9 | 5 | scalable x2 (interleave 1) | scalable: 5 per strip of VL elements (x2) |
| k_dscal | loongarch-lasx | 31 | 11 | 6 | 4 x 1 | 1.50 |
| k_dgemv_n | x86-avx2 | 62 | 29 | 5 | 4 x 1 | 1.25 |
| k_dgemv_n | x86-avx512 | 65 | 29 | 5 | 8 x 1 | 0.62 |
| k_dgemv_n | aarch64-neon | 46 | 28 | 6 | 2 x 1 | 3.00 |
| k_dgemv_n | aarch64-sve | 50 | 28 | 6 | scalable x2 (interleave 1) | scalable: 6 per strip of VL elements (x2) |
| k_dgemv_n | riscv-v | 67 | 31 | 6 | scalable x2 (interleave 1) | scalable: 6 per strip of VL elements (x2) |
| k_dgemv_n | loongarch-lasx | 66 | 31 | 7 | 4 x 1 | 1.75 |
| k_dgemv_t | x86-avx2 | 89 | 41 | 7 | 4 x 1 | 1.75 |
| k_dgemv_t | x86-avx512 | 89 | 41 | 7 | 8 x 1 | 0.88 |
| k_dgemv_t | aarch64-neon | 72 | 42 | 8 | 2 x 1 | 4.00 |
| k_dgemv_t | aarch64-sve | 80 | 42 | 8 | scalable x2 (interleave 1) | scalable: 8 per strip of VL elements (x2) |
| k_dgemv_t | riscv-v | 107 | 51 | 8 | scalable x2 (interleave 1) | scalable: 8 per strip of VL elements (x2) |
| k_dgemv_t | loongarch-lasx | 86 | 50 | 8 | 4 x 1 | 2.00 |
| k_dger | x86-avx2 | 77 | 25 | 7 | 4 x 1 | 1.75 |
| k_dger | x86-avx512 | 77 | 25 | 7 | 8 x 1 | 0.88 |
| k_dger | aarch64-neon | 53 | 23 | 8 | 2 x 1 | 4.00 |
| k_dger | aarch64-sve | 61 | 23 | 8 | scalable x2 (interleave 1) | scalable: 8 per strip of VL elements (x2) |
| k_dger | riscv-v | 84 | 24 | 8 | scalable x2 (interleave 1) | scalable: 8 per strip of VL elements (x2) |
| k_dger | loongarch-lasx | 58 | 25 | 8 | 4 x 1 | 2.00 |
| k_sgemm_nt | x86-avx2 | 95 | 55 | 16 | 8 x 1 | 2.00 |
| k_sgemm_nt | x86-avx512 | 126 | 55 | 17 | 16 x 1 | 1.06 |
| k_sgemm_nt | aarch64-neon | 60 | 40 | 14 | 4 x 1 | 3.50 |
| k_sgemm_nt | aarch64-sve | 63 | 40 | 14 | scalable x4 (interleave 1) | scalable: 14 per strip of VL elements (x4) |
| k_sgemm_nt | riscv-v | 93 | 40 | 15 | scalable x4 (interleave 1) | scalable: 15 per strip of VL elements (x4) |
| k_sgemm_nt | loongarch-lasx | 75 | 39 | 13 | 8 x 1 | 1.62 |

### OpenBLAS: the main loop of its single-precision GEMM kernel, per instruction set

| ISA | loop |
|---|---|
| haswell | loop 387 instructions, 192 FMA (50%), 128 loads; 1536 multiply-adds per iteration at 8 lanes; 0.252 instructions per multiply-add |
| neon | loop 114 instructions, 64 FMA (56%), 24 loads; 256 multiply-adds per iteration at 4 lanes; 0.445 instructions per multiply-add |
| sve | loop 166 instructions, 64 FMA (39%), 72 loads; multiply-adds per iteration = 64 x VL; instructions per multiply-add = 2.594 / VL |
| lasx | loop 243 instructions, 128 FMA (53%), 80 loads; 1024 multiply-adds per iteration at 8 lanes; 0.237 instructions per multiply-add |
| rvv | loop 69 instructions, 30 FMA (43%), 21 loads; 240 multiply-adds per iteration at 8 lanes; 0.287 instructions per multiply-add |
