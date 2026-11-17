## pdp64: pcc scalar code and the hand-written vec form

| kernel | use | pcc scalar: function | pcc scalar: loop for each element | vec form: function | in the vec block | block operations for each element (256-bit strip) |
|---|---|---:|---|---:|---:|---:|
| k_q8dot | LLM: the int8 dot product of a quantized layer | 11 | 6 | 10 | 4 | 0.25 |
| k_q4dot | LLM: the 4-bit weights of a quantized layer (two weights a byte) | 21 | 16 | 18 | 11 | 0.69 |
| k_rmsnorm | LLM: a normalization (a reduction, then a map) | 31 | 5, 8 | 20 | 8 | 1.00 |
| k_softmax | LLM: attention scores (max, exp, sum, scale) | 30 | 5, 6, 8 | 23 | 10 | 1.25 |
| k_blend | games: alpha blending of 8-bit channels | 21 | 18 | 17 | 12 | 0.75 |
| k_mix16 | games: audio mixing, saturating 16-bit add | 14 | 11 | 8 | 4 | 0.25 |
| k_vtx | games: a 4x4 matrix on vertices (three output rows) | 60 | 57 | 34 | 18 | 2.25 |

## What clang's vectorizers did (the whole function; "vectorized" if the compiler reported a vector loop)

| kernel | AVX2 | AVX-512 | NEON | RISC-V V | LASX |
|---|---|---|---|---|---|
| k_q8dot | vectorized: 41 instructions against 16 scalar | vectorized: 68 instructions against 16 scalar | vectorized: 71 instructions against 13 scalar | vectorized: 49 instructions against 12 scalar | vectorized: 54 instructions against 17 scalar |
| k_q4dot | vectorized: 63 instructions against 25 scalar | vectorized: 99 instructions against 25 scalar | vectorized: 129 instructions against 23 scalar | vectorized: 66 instructions against 22 scalar | vectorized: 71 instructions against 26 scalar |
| k_rmsnorm | vectorized: 82 instructions against 29 scalar | vectorized: 130 instructions against 29 scalar | vectorized: 76 instructions against 27 scalar | vectorized: 104 instructions against 31 scalar | vectorized: 96 instructions against 35 scalar |
| k_softmax | vectorized: 160 instructions against 47 scalar | vectorized: 300 instructions against 47 scalar | vectorized: 128 instructions against 41 scalar | vectorized: 203 instructions against 50 scalar | vectorized: 224 instructions against 55 scalar |
| k_blend | vectorized: 142 instructions against 24 scalar | vectorized: 138 instructions against 24 scalar | vectorized: 132 instructions against 16 scalar | vectorized: 80 instructions against 19 scalar | vectorized: 604 instructions against 22 scalar |
| k_mix16 | vectorized: 65 instructions against 18 scalar | vectorized: 65 instructions against 18 scalar | vectorized: 45 instructions against 16 scalar | vectorized: 65 instructions against 24 scalar | vectorized: 91 instructions against 26 scalar |
| k_vtx | vectorized: 192 instructions against 35 scalar | vectorized: 249 instructions against 35 scalar | vectorized: 168 instructions against 36 scalar | vectorized: 198 instructions against 44 scalar | vectorized: 169 instructions against 46 scalar |
