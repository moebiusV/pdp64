## pdp64: pcc scalar code and the hand-written vec forms with and without segment loads

| kernel | what | pcc scalar: function | pcc scalar: loop for each element | with segment ops: function | in the block | without (strided): function | in the block | block operations for each element (segment / strided, 256-bit strip) |
|---|---|---:|---|---:|---:|---:|---:|---:|
| k_gray | RGBA to gray (3 of 4 fields) | 23 | 20 | 12 | 8 | 14 | 10 | 0.50 / 0.62 |
| k_split | stereo audio split (2 fields) | 16 | 13 | 7 | 3 | 8 | 4 | 0.19 / 0.25 |
| k_vtxaos | vertices of (x y z w), a matrix on 3 rows (4 fields in and out) | 73 | 70 | 19 | 15 | 24 | 20 | 1.88 / 2.50 |
| k_cmul | complex multiply (2 fields in and out) | 40 | 37 | 11 | 7 | 14 | 10 | 0.88 / 1.25 |

## What clang's vectorizers did

| kernel | AVX2 | NEON | RISC-V V | LASX |
|---|---|---|---|---|
| k_gray | vectorized: 119 instructions against 21 scalar | vectorized: 82 instructions against 18 scalar | vectorized: 70 instructions against 21 scalar | vectorized: 145 instructions against 23 scalar |
| k_split | vectorized: 93 instructions against 13 scalar | vectorized: 48 instructions against 11 scalar | vectorized: 68 instructions against 13 scalar | vectorized: 306 instructions against 14 scalar |
| k_vtxaos | vectorized: 148 instructions against 29 scalar | vectorized: 88 instructions against 35 scalar | vectorized: 104 instructions against 38 scalar | vectorized: 343 instructions against 38 scalar |
| k_cmul | vectorized: 73 instructions against 19 scalar | vectorized: 54 instructions against 19 scalar | vectorized: 69 instructions against 21 scalar | vectorized: 266 instructions against 24 scalar |
