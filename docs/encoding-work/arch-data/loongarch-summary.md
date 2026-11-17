
### files both compiled (840)

| configuration | instructions | instruction bytes | insn ratio | bytes ratio | .text bytes | padding instructions |
|---|---:|---:|---:|---:|---:|---:|
| pdp64 (pcc) | 296,059 | 964,086 | 1.000 | 1.000 | 1,197,016 | 0 |
| clang LoongArch64 -O1 | 393,895 | 1,575,580 | 1.330 | 1.634 | 1,692,704 | 29,281 |
| clang LoongArch64 -O2 | 563,559 | 2,254,236 | 1.904 | 2.338 | 2,360,828 | 26,648 |
| clang LoongArch64 -O3 | 772,692 | 3,090,768 | 2.610 | 3.206 | 3,189,864 | 24,774 |
| clang LoongArch64 -Os | 362,924 | 1,451,696 | 1.226 | 1.506 | 1,451,696 | 0 |
| clang LoongArch64 -O2, bounds checks as traps | 566,322 | 2,265,288 | 1.913 | 2.350 | 2,371,512 | 26,556 |
| clang LoongArch64 -Os, bounds checks as traps | 365,193 | 1,460,772 | 1.234 | 1.515 | 1,460,772 | 0 |

### the same without file 611 (839)

| configuration | instructions | instruction bytes | insn ratio | bytes ratio | .text bytes | padding instructions |
|---|---:|---:|---:|---:|---:|---:|
| pdp64 (pcc) | 230,521 | 705,970 | 1.000 | 1.000 | 938,900 | 0 |
| clang LoongArch64 -O1 | 316,209 | 1,264,836 | 1.372 | 1.792 | 1,330,704 | 16,467 |
| clang LoongArch64 -O2 | 329,725 | 1,318,900 | 1.430 | 1.868 | 1,382,636 | 15,934 |
| clang LoongArch64 -O3 | 378,026 | 1,512,104 | 1.640 | 2.142 | 1,577,432 | 16,332 |
| clang LoongArch64 -Os | 279,678 | 1,118,712 | 1.213 | 1.585 | 1,118,712 | 0 |
| clang LoongArch64 -O2, bounds checks as traps | 332,488 | 1,329,952 | 1.442 | 1.884 | 1,393,320 | 15,842 |
| clang LoongArch64 -Os, bounds checks as traps | 281,883 | 1,127,532 | 1.223 | 1.597 | 1,127,532 | 0 |

- bounds checks as traps, -O2: +2,763 instructions (+0.49%), +11,052 bytes (+0.49%) on 840 files

- bounds checks as traps, -Os: +2,269 instructions (+0.63%), +9,076 bytes (+0.63%) on 840 files

### Most used instructions, clang -Os (363,347 instructions, 250 mnemonics)

| mnemonic | count | share |
|---|---:|---:|
| `addi.d` | 42,306 | 11.6% |
| `move` | 41,525 | 11.4% |
| `ld.d` | 35,688 | 9.8% |
| `ori` | 30,958 | 8.5% |
| `st.d` | 25,535 | 7.0% |
| `pcaddu18i` | 22,412 | 6.2% |
| `jirl` | 21,932 | 6.0% |
| `bne` | 14,902 | 4.1% |
| `pcalau12i` | 12,006 | 3.3% |
| `add.d` | 10,975 | 3.0% |
| `b` | 7,100 | 2.0% |
| `beqz` | 6,662 | 1.8% |
| `ld.bu` | 6,426 | 1.8% |
| `ret` | 6,106 | 1.7% |
| `ld.w` | 5,411 | 1.5% |
| `bnez` | 4,265 | 1.2% |
| `ldx.bu` | 4,042 | 1.1% |
| `st.w` | 3,765 | 1.0% |
| `addi.w` | 3,501 | 1.0% |
| `lu12i.w` | 3,146 | 0.9% |

The bound-check instructions: `asrtle.d` 0, `asrtgt.d` 0, `ldgt.b` 0, `ldgt.w` 0, `ldgt.d` 0, `ldle.b` 0, `ldle.w` 0, `ldle.d` 0, `stgt.w` 0, `stgt.d` 0, `stle.w` 0, `stle.d` 0 (the plain and the sanitized build alike).

What the checks add, -Os (instructions): `amswap.w` +508, `ori` +483, `bltu` +412, `move` +172, `beq` +158, `ld.d` +136. The trap itself is `amswap.w $zero, $ra, $zero`, an illegal encoding LLVM uses for `ubsantrap`: 508 of them, one per check. Each check costs 4.5 instructions on average.
