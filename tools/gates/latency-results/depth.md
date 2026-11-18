### Depth of every block (longest path in levels: NAND2/NOT gates; ECP5 LUT4 levels, carry hops 0.1 and PFUMX/L6MUX21 0.5; Xilinx LUT6 levels, carry hops 0.1 and MUXF 0.5), strips of 32 / 16 / 8 bytes where the block is parameterised

| block | nand 32 / 16 / 8 | ltp nand 32 | ecp5 32 / 16 / 8 | ltp ecp5 32 | xc7 32 / 16 / 8 | ltp xc7 32 | multiplier primitives on the critical path (ecp5, xc7, at 32) | cells on the ecp5 path (32) |
|---|---|---:|---|---:|---|---:|---|---:|
| w_lanealu_mw | 321 / 319 / 315 | 321 | 35.7 / 35.7 / 35.3 | 100 | 119.7 / 63.7 / 35.9 | 269 | 0, 0 | 97 |
| w_lanealu_mw_noavg | 317 / 319 / 314 | 317 | 35.7 / 35.7 / 35.2 | 100 | 120.5 / 63.2 / 36.4 | 269 | 0, 0 | 97 |
| w_shiftround_mw | 164 / 163 / 166 | 164 | 19.5 / 19.5 / 18.5 | 29 | 28 / 28 / 28 | 43 | 0, 0 | 28 |
| w_shiftlane_mw | 38 / 38 / 37 | 38 | 10 / 10.5 / 10 | 14 | 8.5 / 8.5 / 8.5 | 14 | 0, 0 | 14 |
| w_narrow_both | 48 / 50 / 48 | 48 | 13.9 / 13.4 / 13.2 | 31 | 10.7 / 10.7 / 10.3 | 23 | 0, 0 | 31 |
| w_ms8x8 | 266 / 271 / 251 | 266 | 23.7 / 21.3 / 19 | 64 | 18.5 / 14.9 / 13.4 | 45 | 1, 2 | 63 |
| w_ms8x8_notree | 123 / 121 / 122 | 123 | 13.9 / 13.4 / 13.9 | 28 | 8.9 / 8.9 / 9.3 | 20 | 1, 2 | 20 |
| w_dacc_tree | 143 / 147 / 127 | 143 | 9.9 / 7.4 / 5.5 | 38 | 5.7 / 5.7 / 3.2 | 22 | 0, 0 | 38 |
| w_vacc_naive | 173 / 168 / 150 | 173 | 17.4 / 15.1 / 11.8 | 46 | 14.7 / 11.3 / 9.7 | 33 | 0, 0 | 44 |
| w_vmmacc | 532 / 274 / 145 | 532 | 177.1 / 89.1 / 45.1 | 1058 | 151 / 78.6 / 37.3 | 306 | 0, 0 | 1055 |
| w_sum_bu | 172 / 162 / 150 | 172 | 14.8 / 12.7 / 9.9 | 44 | 11.1 / 8.6 / 5.7 | 29 | 0, 0 | 44 |
| w_vsad_bu | 192 / 182 / 170 | 192 | 17.8 / 16.2 / 13.4 | 50 | 14.3 / 12.8 / 10.5 | 35 | 0, 0 | 49 |
| w_vfir_added | 69 / 69 / 69 | 69 | 4.5 / 4 / 4 | 112 | 3.8 / 3.4 / 3.4 | 137 | 0, 0 | 5 |
| w_vtbl_g16 | 13 / 13 / 9 | 13 | 4 / 4 / 2.5 | 6 | 3 / 3 / 2 | 6 | 0, 0 | 6 |
| w_vcmp_mw | 30 / 32 / 30 | 30 | 8.5 / 8 / 7.5 | 36 | 137.5 / 138.5 / 134.9 | 497 | 0, 0 | 11 |
| w_vcmp2 | 30 / 30 / 28 | 30 | 8 / 7.5 / 7 | 35 | 7.7 / 7.7 / 7.6 | 15 | 0, 0 | 10 |
| w_vbsl | 3 / 3 / 3 | 3 | 1 / 1 / 1 | 1 | 1 / 1 / 1 | 3 | 0, 0 | 1 |
| lat_cmpsel | 31 / 33 / 33 | 31 | 8.9 / 8.5 / 7.5 | 36 | 7.7 / 8.1 / 7.7 | 15 | 0, 0 | 24 |
| lat_alushift | 490 / 488 / 480 | 490 | 51.8 / 51.5 / 52.1 | 124 | 147.9 / 94.1 / 67.7 | 306 | 0, 0 | 107 |
| w_segload | 15 / 15 / 13 | 15 | 4.5 / 5 / 4 | 7 | 3.5 / 3.5 / 3 | 7 | 0, 0 | 7 |
| w_segstore | 19 / 19 / 17 | 19 | 6.5 / 6 / 5.5 | 10 | 5 / 5 / 4.5 | 9 | 0, 0 | 10 |
| w_vmem_ld | 24 / 21 / 19 | 24 | 9 / 8 / 6.5 | 13 | 6 / 6.5 / 5.5 | 10 | 0, 0 | 13 |
| w_vmem_st | 32 / 18 / 10 | 32 | 10.9 / 8 / 6.3 | 40 | 6.2 / 4.4 / 4 | 23 | 0, 0 | 37 |
| w_vregs16_r3 | 11 / 11 / 11 | 11 | 1 / 1 / 1 | 1 | 1 / 1 / 1 | 4 | 0, 0 | 1 |
| w_cvt_both | 193 / 191 / 182 | 193 | 33.1 / 30.5 / 28.1 | 66 | 17.6 / 17.5 / 17.5 | 41 | 0, 0 | 66 |
| w_fma32xn | 553 / 547 / 555 | 553 | 95.8 / 94.3 / 90.5 | 178 | 45.7 / 45.5 / 46.7 | 86 | 0, 0 | 172 |
| ms16_lo | 55 | 55 | 1 | 2 | 1 | 4 | 1, 1 | 2 |
| ms16_hi | 98 | 98 | 6.3 | 15 | 4.9 | 14 | 1, 1 | 15 |
| ms16_hi_mla | 92 | 92 | 6.3 | 15 | 5.4 | 15 | 1, 1 | 15 |
| ms16_all | 101 | 101 | 8 | 22 | 7.9 | 18 | 1, 1 | 19 |
| mul32s | 146 | 146 | 5 | 25 | 2.8 | 17 | 1, 2 | 25 |
| fma32x8 | 558 | 558 | 94.8 | 187 | 47.7 | 91 | 0, 0 | 178 |
| fma32 | 535 | 535 | 93.4 | 175 | 46.5 | 86 | 0, 0 | 166 |
| cvt_i2f | 208 | 208 | 28.2 | 61 | 17 | 40 | 0, 0 | 59 |
| cvt_f2i | 73 | 73 | 15.3 | 32 | 10.1 | 21 | 0, 0 | 32 |
| alu64 | 136 | 136 | 9.6 | 38 | 9.3 | 26 | 0, 0 | 38 |
| shift64 | 24 | 24 | 7.5 | 12 | 6.5 | 11 | 0, 0 | 10 |
| bitops64 | 85 | 85 | 12 | 18 | 133.4 | 210 | 0, 0 | 16 |
| mul64 | 221 | 221 | 10.5 | 68 | 7.2 | 39 | 1, 4 | 67 |
| div64 | 129 | 129 | 5.6 | 352 | 4.3 | 356 | 0, 0 | 34 |
| tlb32 | 24 | 24 | 7 | 10 | 8 | 17 | 0, 0 | 7 |
| ldalign | 13 | 13 | 5.5 | 8 | 3.5 | 6 | 0, 0 | 8 |
| stmerge | 11 | 11 | 3.5 | 5 | 2.5 | 5 | 0, 0 | 5 |
| clmul64 | 24 | 24 | 5.5 | 8 | 5.5 | 10 | 0, 0 | 8 |
| mul53 | 167 | 167 | 9 | 56 | 4.8 | 30 | 1, 4 | 56 |
| shr106 | 16 | 16 | 7 | 10 | 5 | 8 | 0, 0 | 10 |
| add106 | 139 | 139 | 6.6 | 53 | 4.3 | 30 | 0, 0 | 53 |
| norm106 | 140 | 140 | 18 | 26 | 21.5 | 36 | 0, 0 | 25 |

levels of the xc7 flow for `w_vcmp_mw` are an artefact of the study's own form of the compare (a dynamic shift: it maps to 90,000 LUT6, vec-strip.md section 3); `w_vcmp2` is the fixed-comparator form that the class uses.

### The classes: the blocks, the depth at strip 32 (and 16, 8 where it differs), and the latency in cycles under the assumed delays

| class | what | blocks (mode) | NAND2 levels 32 / 16 / 8 | LUT4 levels 32 / 16 / 8 | DSP on path (ecp5) | LUT6 levels 32 | fpga-lo | **fpga** | fpga-hi | asic-lo | **asic** | asic-hi | fpga / asic at strip 16 | at strip 8 |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| alu | lane ALU add sub logic min max abs average, saturating | w_lanealu_mw (local) | 315 | 35.3 | 0 | 35.9 | 3 | **4** | 5 | 18 | **37** | 79 | 4 / 37 | 4 / 37 |
| cmp | vceq vcgt vcgtu | w_vcmp2 (local) | 28 | 7 | 0 | 7.6 | 1 | **1** | 1 | 2 | **4** | 7 | 1 / 4 | 1 / 4 |
| bsl | vbsl | w_vbsl (local) | 3 | 1 | 0 | 1 | 1 | **1** | 1 | 1 | **1** | 1 | 1 / 1 | 1 / 1 |
| shift | vshl vshr vsar and the rounding vsarr vshrr | w_shiftround_mw (local) | 166 | 18.5 | 0 | 28 | 2 | **2** | 3 | 10 | **20** | 42 | 2 / 20 | 2 / 20 |
| narrow | the narrowing of vsts (rounding shift, saturation) | w_narrow_both (local) | 48 | 13.2 | 0 | 10.3 | 1 | **2** | 2 | 3 | **6** | 12 | 2 / 6 | 2 / 6 |
| mul8 | vmul.b and the 8 x 8 products of vdot.b | w_ms8x8_notree (local) | 122 | 13.9 | 1 | 9.3 | 2 | **4** | 5 | 7 | **15** | 31 | 4 / 15 | 4 / 15 |
| mul16 | vmul.w (low half) | ms16_lo (fixed) | 55 | 1 | 1 | 1 | 2 | **3** | 4 | 4 | **7** | 14 | 3 / 7 | 3 / 7 |
| mulh16 | vmulh vmulhu vmulhr vmla on halfwords | ms16_hi_mla (fixed) | 92 | 6.3 | 1 | 5.4 | 2 | **3** | 4 | 6 | **11** | 23 | 3 / 11 | 3 / 11 |
| mul32 | vmul.l and 32-bit multiplies | mul32s (fixed) | 146 | 5 | 1 | 2.8 | 2 | **3** | 4 | 9 | **17** | 37 | 3 / 17 | 3 / 17 |
| mul64 | vmul.q: the scalar 64 x 64 multiplier as the lane multiplier | mul64 (fixed) | 221 | 10.5 | 1 | 7.2 | 2 | **4** | 5 | 13 | **26** | 56 | 4 / 26 | 4 / 26 |
| dot | vdot vdotu vdotsu (the larger of the byte and the halfword form) | w_ms8x8_notree (local), ms16_all (fixed) | 122 | 13.9 | 1 | 9.3 | 2 | **4** | 5 | 7 | **15** | 31 | 4 / 15 | 4 / 15 |
| dacc | vdacc: products, then the reduction tree into a scalar | w_ms8x8 (wide) | 266 / 271 / 251 | 23.7 / 21.3 / 19 | 1 | 18.5 | 3 | **5** | 7 | 15 | **31** | 67 | 5 / 32 | 4 / 29 |
| sad | vsad.bu | w_vsad_bu (wide) | 192 / 182 / 170 | 17.8 / 16.2 / 13.4 | 0 | 14.3 | 2 | **2** | 3 | 11 | **23** | 48 | 2 / 21 | 2 / 20 |
| acc | vacc | w_vacc_naive (wide), w_sum_bu (wide) | 173 / 168 / 150 | 17.4 / 15.1 / 11.8 | 0 | 14.7 | 2 | **2** | 3 | 10 | **20** | 44 | 2 / 20 | 2 / 18 |
| mmacc | vmaxacc vminacc | w_vmmacc (wide) | 532 / 274 / 145 | 177.1 / 89.1 / 45.1 | 0 | 151 | 12 | **18** | 24 | 30 | **62** | 133 | 9 / 32 | 5 / 17 |
| fir | vfir: one tap = a 16-bit multiply and the add of the window (ESTIMATE: the sum of the two blocks) | ms16_lo (fixed), w_vfir_added (wide) | 124 | 5.5 / 5 / 5 | 1 | 4.8 | 2 | **3** | 4 | 7 | **15** | 31 | 3 / 15 | 3 / 15 |
| tbl | vtbl | w_vtbl_g16 (wide) | 13 / 13 / 9 | 4 / 4 / 2.5 | 0 | 3 | 1 | **1** | 1 | 1 | **2** | 4 | 1 / 2 | 1 / 2 |
| lseg | vlseg2..4 de-interleave (after the load alignment) | w_segload (wide) | 15 / 15 / 13 | 4.5 / 5 / 4 | 0 | 3.5 | 1 | **1** | 1 | 1 | **2** | 4 | 1 / 2 | 1 / 2 |
| sseg | vsseg2..4 interleave (before the store merge) | w_segstore (wide) | 19 / 19 / 17 | 6.5 / 6 / 5.5 | 0 | 5 | 1 | **1** | 1 | 2 | **3** | 5 | 1 / 3 | 1 / 2 |
| cvt | vcvt between 32-bit integers and binary32 | w_cvt_both (local) | 182 | 28.1 | 0 | 17.5 | 2 | **3** | 4 | 11 | **21** | 46 | 3 / 21 | 3 / 21 |
| fma | binary32 add sub mul fma (one lane of fma32x8) | fma32 (fixed) | 535 | 93.4 | 0 | 46.5 | 6 | **10** | 13 | 30 | **62** | 134 | 10 / 62 | 10 / 62 |
| fma64 | binary64 add sub mul fma (ESTIMATE: the sum of the four blocks of core.v; not a synthesised block) | mul53 (fixed), shr106 (fixed), add106 (fixed), norm106 (fixed) | 462 | 40.6 | 1 | 35.6 | 4 | **6** | 9 | 26 | **54** | 116 | 6 / 54 | 6 / 54 |
| ld | load alignment and widening, after the memory's own latency (vmemlat) | w_vmem_ld (wide) | 24 / 21 / 19 | 9 / 8 / 6.5 | 0 | 6 | 0 | **0** | 1 | 1 | **2** | 5 | 0 / 2 | 0 / 2 |
| st | store merge | w_vmem_st (wide) | 32 / 18 / 10 | 10.9 / 8 / 6.3 | 0 | 6.2 | 0 | **1** | 1 | 1 | **3** | 7 | 0 / 2 | 0 / 1 |
| misc | vclr, vlen: a register write | - | 0 | 0 | 0 | 0 | 1 | **1** | 1 | 1 | **1** | 1 | 1 / 1 | 1 / 1 |

Parameters (ASSUMED): fpga-lo: ecp5 levels, 0.6 ns a level, clock 10 ns, 0.5 ns register overhead a stage, 1 cycles a multiplier primitive; fpga: ecp5 levels, 0.9 ns a level, clock 10 ns, 0.75 ns register overhead a stage, 2 cycles a multiplier primitive; fpga-hi: ecp5 levels, 1.2 ns a level, clock 10 ns, 1 ns register overhead a stage, 3 cycles a multiplier primitive; asic-lo: nand levels, 0.05 ns a level, clock 1 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive; asic: nand levels, 0.075 ns a level, clock 0.75 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive; asic-hi: nand levels, 0.1 ns a level, clock 0.5 ns, 0.1 ns register overhead a stage, 0 cycles a multiplier primitive.

### The scalar core's long operations (not used by sim64: both models count 1 cycle a scalar instruction): depth and latency in the same conversion, mid assumptions

| block | what | NAND2 levels | LUT4 levels | DSP on path (ecp5) | LUT6 levels | fpga cycles | asic cycles |
|---|---|---:|---:|---:|---:|---:|---:|
| alu64 | scalar ALU | 136 | 9.6 | 0 | 9.3 | 1 | 16 |
| shift64 | scalar shifts | 24 | 7.5 | 0 | 6.5 | 1 | 3 |
| bitops64 | bit counts and reversal | 85 | 12 | 0 | 133.4 | 2 | 10 |
| mul64 | scalar 64 x 64 multiplier | 221 | 10.5 | 1 | 7.2 | 4 | 26 |
| div64 | one iteration of the divider (64 iterations, 1 quotient bit each: 64 cycles when one iteration fits a cycle) | 129 | 5.6 | 0 | 4.3 | 1 | 15 |
| tlb32 | translation buffer match and read | 24 | 7 | 0 | 8 | 1 | 3 |
| ldalign | scalar load alignment | 13 | 5.5 | 0 | 3.5 | 1 | 2 |
| stmerge | scalar store merge | 11 | 3.5 | 0 | 2.5 | 1 | 2 |
| clmul64 | carry-less multiply | 24 | 5.5 | 0 | 5.5 | 1 | 3 |
| fma32 (scalar) | scalar binary32 fma | 535 | 93.4 | 0 | 46.5 | 10 | 62 |
| mul53 | double-precision multiplier 53 x 53 | 167 | 9 | 1 | 4.8 | 3 | 20 |
