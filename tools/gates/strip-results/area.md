## Check: the parameterised blocks at 256 bits against the existing ones

`ref` is the module of vec2.v, vec3.v, mem2.v or fp2.v synthesised again by this run (strip-synth.sh, the commands of gates2.sh and fpga.sh); `w_` is the parameterised module of vecw.v at SNB = 32; `committed` is the study's file (vec-silicon-blocks.tsv, fpga-blocks.tsv).  NAND2 equivalents with flip-flops at 6; LUT4 and LUT6 as the flows give them (for the register file the distributed RAM sites are added: see the header of strip-total.py).  diff = w_ against ref.

| block | NAND2 ref | NAND2 w_ | diff | NAND2 committed | LUT4 ref | LUT4 w_ | diff | LUT4 committed | LUT6 ref | LUT6 w_ | diff | LUT6 committed | DSP ecp5 ref / w_ | DSP xc7 ref / w_ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| fma32x8 | 85,534 | 85,534 | +0.0% | 86,650 | 24,845 | 25,362 | +2.1% | 26,862 | 9,149 | 8,999 | -1.6% | 10,386 | 32 / 32 | 16 / 16 |
| cvt_both8 | 16,025 | 16,007 | -0.1% | 15,847 | 5,634 | 5,634 | +0.0% | 5,466 | 3,917 | 3,878 | -1.0% | 3,834 | 0 / 0 | 0 / 0 |
| ms8x8 | 87,660 | 87,737 | +0.1% | 85,516 | 7,491 | 7,491 | +0.0% | 7,531 | 4,684 | 4,713 | +0.6% | 4,580 | 64 / 64 | 64 / 64 |
| ms8x8_notree | 83,844 | 83,659 | -0.2% | 81,722 | 6,141 | 6,140 | -0.0% | 6,130 | 4,354 | 4,226 | -2.9% | 9,508 | 64 / 64 | 64 / 64 |
| lanealu_mw | 19,782 | 19,618 | -0.8% | 19,782 | 5,232 | 5,225 | -0.1% | 5,232 | 3,150 | 3,280 | +4.1% | 6,556 | 0 / 0 | 0 / 0 |
| lanealu_mw_noavg | 18,275 | 18,189 | -0.5% | 18,275 | 5,066 | 5,075 | +0.2% | 5,066 | 2,904 | 2,900 | -0.1% | 5,900 | 0 / 0 | 0 / 0 |
| shiftround_mw | 11,582 | 11,582 | +0.0% | 11,582 | 6,821 | 6,821 | +0.0% | 6,821 | 3,899 | 3,899 | +0.0% | 7,748 | 0 / 0 | 0 / 0 |
| shiftlane_mw | 9,430 | 9,423 | -0.1% | 9,430 | 6,291 | 6,291 | +0.0% | 6,291 | 3,313 | 3,348 | +1.1% | 6,710 | 0 / 0 | 0 / 0 |
| segload | 9,856 | 9,854 | -0.0% | 9,856 | 9,888 | 9,888 | +0.0% | 9,888 | 3,419 | 3,438 | +0.6% | 3,419 | 0 / 0 | 0 / 0 |
| segstore | 13,418 | 13,418 | +0.0% | 13,418 | 10,881 | 10,881 | +0.0% | 10,881 | 3,640 | 3,640 | +0.0% | 3,640 | 0 / 0 | 0 / 0 |
| vacc_naive | 9,875 | 9,875 | +0.0% | 9,875 | 2,474 | 2,474 | +0.0% | 2,474 | 1,848 | 1,848 | +0.0% | 1,848 | 0 / 0 | 0 / 0 |
| vmmacc | 10,702 | 10,702 | +0.0% | 10,702 | 5,119 | 5,119 | +0.0% | 5,119 | 2,323 | 2,325 | +0.1% | 2,323 | 0 / 0 | 0 / 0 |
| narrow_both | 8,629 | 8,498 | -1.5% | 8,629 | 5,773 | 5,773 | +0.0% | 5,773 | 2,588 | 2,586 | -0.1% | 5,168 | 0 / 0 | 0 / 0 |
| vfir_added | 12,360 | 12,336 | -0.2% | 12,386 | 2,303 | 2,303 | +0.0% | 2,303 | 2,786 | 2,785 | -0.0% | 2,857 | 0 / 0 | 0 / 0 |
| dacc_tree | 3,734 | 3,509 | -6.0% | 3,734 | 792 | 763 | -3.7% | 792 | 610 | 662 | +8.5% | 610 | 0 / 0 | 0 / 0 |
| sum32_bu | 2,670 | 2,670 | +0.0% | 2,670 | 718 | 718 | +0.0% | 718 | 575 | 575 | +0.0% | 575 | 0 / 0 | 0 / 0 |
| vsad_bu | 7,921 | 7,921 | +0.0% | 7,921 | 2,461 | 2,461 | +0.0% | 2,461 | 1,385 | 1,385 | +0.0% | 1,385 | 0 / 0 | 0 / 0 |
| vtbl_g16 | 12,736 | 12,736 | +0.0% | 12,736 | 5,376 | 5,376 | +0.0% | 5,376 | 1,643 | 1,615 | -1.7% | 1,643 | 0 / 0 | 0 / 0 |
| vcmp_mw | 2,905 | 2,917 | +0.4% | 2,905 | 1,368 | 1,368 | +0.0% | 1,368 | 90,071 | 90,008 | -0.1% | 89,804 | 0 / 0 | 0 / 0 |
| vbsl | 896 | 896 | +0.0% | 896 | 256 | 256 | +0.0% | 256 | 256 | 256 | +0.0% | 256 | 0 / 0 | 0 / 0 |
| vregs16_r3 | 61,578 | 61,578 | +0.0% | 61,578 | 768 | 768 | +0.0% | 0 | 512 | 512 | +0.0% | 0 | 0 / 0 | 0 / 0 |
| vmem_ld | 9,379 | 9,379 | +0.0% | 9,531 | 4,614 | 4,614 | +0.0% | 4,614 | 1,964 | 1,964 | +0.0% | 2,084 | 0 / 0 | 0 / 0 |
| vmem_st | 5,534 | 5,534 | +0.0% | 5,534 | 2,571 | 2,571 | +0.0% | 2,571 | 1,297 | 1,297 | +0.0% | 1,297 | 0 / 0 | 0 / 0 |

Blocks where w_ at 256 bits differs from ref by more than 3% in NAND2, LUT4 or LUT6: dacc_tree 8.5%, lanealu_mw 4.1%.

## Every block at the three strips

NAND2 equivalents (flip-flops at 6), then ECP5 LUT4 (distributed RAM at 4 LUT4 a DPR16X4), Xilinx xc7 LUT6 (RAM32M at 4 sites), the multipliers MULT18X18D / DSP48E1.  Ratio: the block at 128 (64) bits over the block at 256 bits.

| block | NAND2 256 | 128 | 64 | ratio 128 | ratio 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 | MULT18 256 / 128 / 64 | DSP48 256 / 128 / 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| vector register file, 16 x strip, 3 read, 1 write | 61,578 | 30,869 | 15,409 | 0.50 | 0.25 | 768 | 384 | 192 | 512 | 256 | 128 | 0 / 0 / 0 | 0 / 0 / 0 |
| lane ALU, all widths (with avg) | 19,618 | 9,923 | 4,811 | 0.51 | 0.25 | 5,225 | 2,671 | 1,323 | 3,280 | 1,581 | 807 | 0 / 0 / 0 | 0 / 0 / 0 |
| shifts with rounding | 11,582 | 5,797 | 2,982 | 0.50 | 0.26 | 6,821 | 3,364 | 1,944 | 3,899 | 1,955 | 988 | 0 / 0 / 0 | 0 / 0 / 0 |
| narrowing store with rounding shift | 8,498 | 4,233 | 2,144 | 0.50 | 0.25 | 5,773 | 2,938 | 1,462 | 2,586 | 1,300 | 638 | 0 / 0 / 0 | 0 / 0 / 0 |
| array of 8 x 8 products with the vdacc tree | 87,737 | 43,726 | 22,140 | 0.50 | 0.25 | 7,491 | 3,655 | 1,759 | 4,713 | 2,247 | 1,132 | 64 / 32 / 16 | 64 / 32 / 16 |
|   (the array without the tree) | 83,659 | 41,860 | 21,209 | 0.50 | 0.25 | 6,140 | 3,140 | 1,543 | 4,226 | 2,172 | 1,100 | 64 / 32 / 16 | 64 / 32 / 16 |
|   (the vdacc tree alone) | 3,509 | 1,665 | 1,093 | 0.47 | 0.31 | 763 | 351 | 191 | 662 | 314 | 127 | 0 / 0 / 0 | 0 / 0 / 0 |
| vacc, one tree per source type | 9,875 | 4,842 | 2,335 | 0.49 | 0.24 | 2,474 | 1,060 | 487 | 1,848 | 775 | 323 | 0 / 0 / 0 | 0 / 0 / 0 |
| vmaxacc, vminacc | 10,702 | 4,961 | 2,269 | 0.46 | 0.21 | 5,119 | 2,513 | 1,220 | 2,325 | 1,257 | 538 | 0 / 0 / 0 | 0 / 0 / 0 |
| sum of the bytes (the tree of vsad / vacc.bu) | 2,670 | 1,459 | 845 | 0.55 | 0.32 | 718 | 368 | 187 | 575 | 286 | 108 | 0 / 0 / 0 | 0 / 0 / 0 |
| vsad.bu standalone | 7,921 | 4,087 | 2,141 | 0.52 | 0.27 | 2,461 | 1,187 | 595 | 1,385 | 677 | 340 | 0 / 0 / 0 | 0 / 0 / 0 |
| vtbl.b (register form) | 12,736 | 6,368 | 1,472 | 0.50 | 0.12 | 5,376 | 2,688 | 456 | 1,615 | 807 | 192 | 0 / 0 / 0 | 0 / 0 / 0 |
| compare (vceq, vcgt, vcgtu), study form | 2,917 | 1,448 | 725 | 0.50 | 0.25 | 1,368 | 797 | 440 | 90,008 | 45,514 | 22,633 | 0 / 0 / 0 | 0 / 0 / 0 |
| compare, fixed comparators (no dynamic shift) | 2,953 | 1,477 | 742 | 0.50 | 0.25 | 1,391 | 781 | 360 | 626 | 317 | 159 | 0 / 0 / 0 | 0 / 0 / 0 |
| vbsl | 896 | 448 | 224 | 0.50 | 0.25 | 256 | 128 | 64 | 256 | 128 | 64 | 0 / 0 / 0 | 0 / 0 / 0 |
| conversions vcvt.f.l, vcvt.l.f, SNB/4 lanes each | 16,007 | 8,053 | 3,972 | 0.50 | 0.25 | 5,634 | 2,955 | 1,356 | 3,878 | 1,774 | 959 | 0 / 0 / 0 | 0 / 0 / 0 |
| vfir (without the 112 halo flip-flops) | 12,336 | 6,599 | 3,768 | 0.53 | 0.31 | 2,303 | 1,214 | 719 | 2,785 | 1,092 | 567 | 0 / 0 / 0 | 0 / 0 / 0 |
| segment load (de-interleave) | 9,854 | 4,072 | 1,276 | 0.41 | 0.13 | 9,888 | 2,971 | 1,962 | 3,438 | 1,262 | 420 | 0 / 0 / 0 | 0 / 0 / 0 |
| segment store (interleave) | 13,418 | 6,297 | 2,053 | 0.47 | 0.15 | 10,881 | 5,898 | 1,559 | 3,640 | 1,723 | 539 | 0 / 0 / 0 | 0 / 0 / 0 |
| load alignment with widening | 9,379 | 3,689 | 1,348 | 0.39 | 0.14 | 4,614 | 1,902 | 501 | 1,964 | 743 | 316 | 0 / 0 / 0 | 0 / 0 / 0 |
| store merge | 5,534 | 2,214 | 814 | 0.40 | 0.15 | 2,571 | 1,030 | 362 | 1,297 | 496 | 239 | 0 / 0 / 0 | 0 / 0 / 0 |
| floating-point multiply-add lanes (SNB/4) | 85,534 | 42,671 | 21,305 | 0.50 | 0.25 | 25,362 | 13,218 | 6,563 | 8,999 | 4,537 | 2,090 | 32 / 16 / 8 | 16 / 8 / 4 |
## The wave-1 vector unit, by unit

| unit | NAND2 256 | 128 | 64 | LUT4 256 | 128 | 64 | LUT6 256 | 128 | 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| registers 16 x strip | 61,578 | 30,869 | 15,409 | 768 | 384 | 192 | 512 | 256 | 128 |
| lane ALU | 19,618 | 9,923 | 4,811 | 5,225 | 2,671 | 1,323 | 3,280 | 1,581 | 807 |
| shifts with rounding | 11,582 | 5,797 | 2,982 | 6,821 | 3,364 | 1,944 | 3,899 | 1,955 | 988 |
| multiplier array + vdacc tree | 87,737 | 43,726 | 22,140 | 7,491 | 3,655 | 1,759 | 4,713 | 2,247 | 1,132 |
| vsad (estimate: 8 NAND2 and 8 LUT a byte) | 800 | 400 | 200 | 256 | 128 | 64 | 256 | 128 | 64 |
| reductions (vacc, vmaxacc, vminacc) | 20,577 | 9,803 | 4,604 | 7,593 | 3,573 | 1,707 | 4,173 | 2,032 | 861 |
| narrowing store | 8,498 | 4,233 | 2,144 | 5,773 | 2,938 | 1,462 | 2,586 | 1,300 | 638 |
| vfir (+ 112 halo flip-flops) | 13,008 | 7,271 | 4,440 | 2,303 | 1,214 | 719 | 2,785 | 1,092 | 567 |
| segment load and store | 23,272 | 10,369 | 3,329 | 20,769 | 8,869 | 3,521 | 7,078 | 2,985 | 959 |
| vtbl.b | 12,736 | 6,368 | 1,472 | 5,376 | 2,688 | 456 | 1,615 | 807 | 192 |
| load alignment and store merge | 14,913 | 5,903 | 2,162 | 7,185 | 2,932 | 863 | 3,261 | 1,239 | 555 |
| strip control (4 adders + estimate; not scaled) | 4,640 | 4,640 | 4,640 | 756 | 756 | 756 | 756 | 756 | 756 |
| (wave 2) compare, select (vcmp_mw for NAND2 and ECP5, vcmp2 for Xilinx) + vbsl | 3,813 | 1,896 | 949 | 1,624 | 925 | 504 | 882 | 445 | 223 |
| (wave 2) conversions | 16,007 | 8,053 | 3,972 | 5,634 | 2,955 | 1,356 | 3,878 | 1,774 | 959 |

## Totals and the saving against the 256-bit strip

Flip-flops are inside the NAND2 count (6 each); in the FPGA columns they are listed apart (LUT4 and LUT6 are logic and distributed RAM only).  The registers are 16 x strip bits of distributed RAM with 3 read ports (a copy of the array for each port) in both FPGA flows: no block RAM.

| configuration | strip | NAND2 eq | saving | ECP5 LUT4 | saving | ECP5 FF | MULT18X18D | xc7 LUT6 | saving | xc7 FF | DSP48E1 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| wave 1, 16 integer lanes at 256 bits (8 at 64) | 256 bit | 278,959 | - | 70,316 | - | 624 | 64 | 34,914 | - | 624 | 64 |
|  | 128 bit | 139,302 | 50% | 33,172 | 53% | 368 | 32 | 16,378 | 53% | 368 | 32 |
|  | 64 bit | 68,333 | 76% | 14,766 | 79% | 240 | 16 | 7,647 | 78% | 240 | 16 |
| wave 1 and 2 | 256 bit | 298,779 | - | 77,574 | - | 624 | 64 | 39,674 | - | 624 | 64 |
|  | 128 bit | 149,251 | 50% | 37,052 | 52% | 368 | 32 | 18,597 | 53% | 368 | 32 |
|  | 64 bit | 73,254 | 75% | 16,626 | 79% | 240 | 16 | 8,829 | 78% | 240 | 16 |
| wave 1 and 2 with floating-point lanes | 256 bit | 384,313 | - | 102,936 | - | 624 | 96 | 48,673 | - | 624 | 80 |
|  | 128 bit | 191,922 | 50% | 50,270 | 51% | 368 | 48 | 23,134 | 52% | 368 | 40 |
|  | 64 bit | 94,559 | 75% | 23,189 | 77% | 240 | 24 | 10,919 | 78% | 240 | 20 |

The lane count follows the strip (the lane names refer to the 256-bit strip): at 128 bits 8 halfword lanes, 4 word lanes, 8 byte-product halfword lanes of the array (a vdot.b strip is 4 lanes of 4 products), 2 floating-point lanes; at 64 bits 4 halfword lanes, 2 word lanes, 1 doubleword lane, 2 floating-point lanes.
Floating-point lane count: 256 bit 8 fma32 lanes, 128 bit 4 fma32 lanes, 64 bit 2 fma32 lanes.

## Fit in the FPGA parts (wave 1 and 2 with floating-point lanes; the vector unit alone, not the scalar core, not the memory system)

| strip | ECP5-85F: 84k LUT4, 156 18x18 | Artix-7 100T: 63k LUT6, 240 DSP48 | Artix-7 200T: 134k LUT6, 740 DSP48 |
|---|---|---|---|
| 256 bit | 123% of the LUT4, 96 of 156 multipliers (without fp lanes: 92%, 64) | 77% of the LUT6, 80 of 240 DSP (without fp lanes: 63%, 64) | 36% of the LUT6, 80 of 740 DSP (without fp lanes: 30%) |
| 128 bit | 60% of the LUT4, 48 of 156 multipliers (without fp lanes: 44%, 32) | 37% of the LUT6, 40 of 240 DSP (without fp lanes: 30%, 32) | 17% of the LUT6, 40 of 740 DSP (without fp lanes: 14%) |
| 64 bit | 28% of the LUT4, 24 of 156 multipliers (without fp lanes: 20%, 16) | 17% of the LUT6, 20 of 240 DSP (without fp lanes: 14%, 16) | 8% of the LUT6, 20 of 740 DSP (without fp lanes: 7%) |
