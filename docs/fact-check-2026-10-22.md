# Fact-check of statements about the outside world, 2026-10-22

[← pdp64 index](../README.md)

Status: partial. Claims about other machines, systems and standards were compared with a source where one could be read. Sources used: the QEMU source (`../qemu-src`, for RISC-V, x86, ARM, MIPS and SPARC definitions), the LLVM 21.1.8 source (`../llvm-project`), the 32V headers (`../corpora/32v-include`), and pages from Wikipedia and openbsd.org. Not read: uops.info, the Caldera licence PDF, any architecture manual (Intel SDM, Arm ARM, RISC-V specifications, PDP-11 and VAX handbooks), any paper (Babaoglu and Joy, Figueroa) and any performance publication. Verdict words: confirmed (a source seen supports it), wrong (it was wrong or overstated; the documents state the supported version), unsupported (not supported by anything read; the documents say so), could not verify (nothing seen either way; the documents mark it). QEMU is an emulator written from the manuals, so a match there is strong evidence for a bit position or a constant but not a quotation of the specification.

## 1. History: 3BSD, 32V, compilers, licences

| Claim | Where | Verdict | Source and supporting text | In the documents |
|---|---|---|---|---|
| 3BSD (1979) is the first Berkeley release with virtual memory, on the VAX, from 32V, by Babaoglu and Joy | design discussion; system-architecture §12 | confirmed | Wikipedia *Berkeley Software Distribution*: "The kernel of 32V was largely rewritten to include Berkeley graduate student Özalp Babaoğlu's virtual memory implementation ... released as 3BSD at the end of 1979"; Wikipedia *UNIX/32V*: "A virtual memory system was added at Berkeley by Bill Joy and Özalp Babaoğlu ... 3BSD in 1979". ("First Berkeley release with" is implied: 1BSD and 2BSD were PDP-11 releases; not separately sourced.) | the text cites these |
| 32V swaps whole processes and does not demand-page | design discussion; errata 30 | confirmed | `corpora/32v-include/sys/proc.h` (`p_swaddr`, `p_swsize`, `SSWAP`, `SSPART`, no paging fields); Wikipedia *UNIX/32V*: "released without virtual memory paging, retaining only the swapping architecture of Seventh Edition" | errata 30 carries the note |
| VAX has a hardware modify bit and no reference bit; 3BSD emulated reference bits in software | system-design D8; system-architecture §12 | could not verify | no source read (VAX architecture handbook and the Babaoglu and Joy paper not fetched) | marked "not checked" |
| Paper title "Converting a swap-based system to do paging in an architecture lacking page-referenced bits", SOSP 1981 | design discussion | could not verify | not looked up | stated as "from memory, not looked up" |
| GCC did not exist until 1987 | design discussion | confirmed | Wikipedia *GNU Compiler Collection*: "GCC was first released March 22, 1987"; "GCC 1.0 ... in 1987" | cited in §12 |
| 32V, 3BSD, 4BSD were built with Johnson's pcc | design discussion; system-architecture §12 | unsupported | Wikipedia *Ancient UNIX*: V7 "pcc augmenting Dennis Ritchie's C compiler". No source seen says which compiler built 32V or 3BSD (pcc is the only plausible one before 1987) | the document says so |
| Berkeley moved to GCC "around 4.4BSD or after" | design discussion | could not verify | Wikipedia GCC says only "Most BSD family operating systems also switched to GCC shortly after its release" (about the free BSDs, not the CSRG) | not in any document |
| The January 2002 Caldera licence covers the early AT&T sources (PDP-11 and 32V) | design discussion; system-architecture §12 | confirmed | Wikipedia *Ancient UNIX*: "in January 2002, Caldera International ... relicensed ... several versions under the four-clause BSD license, up to and including Version 7 Unix (UNIX/32V)" | the text states this |
| ... whether it covers 3BSD or other BSDs; the licence of the 3BSD sources | design discussion | could not verify | nothing seen says the 2002 grant covers 3BSD; the licence PDF (tuhs.org/Archive/Caldera-license.pdf) was not read; the 3BSD archive page was not read | document says "not shown to cover 3BSD" and lists it as open |
| Where the sources are (tuhs.org, CSRG archives) | design discussion | could not verify | not read | document says the TUHS archive holds the 2002-licensed systems (per Wikipedia only for those) |

## 2. OpenBSD and LLVM

| Claim | Where | Verdict | Source and supporting text | Change |
|---|---|---|---|---|
| OpenBSD's base system is built with clang | system-architecture §14 | wrong | OpenBSD 6.4 release page (openbsd.org/64.html), outside components: "LLVM/Clang 6.0.0 (+ patches)" and "GCC 4.2.1 (+ patches) and 3.3.6 (+ patches)"; Wikipedia *OpenBSD*: "As of OpenBSD 6.3, either Clang 5.0.1, GCC 4.2.1 or GCC 3.3.6 is shipped, depending on the platform". Which ports use which was not established (the pages give versions, not the mapping, and are from 2018) | clang on some ports, in-tree GCC on others |
| RETGUARD is implemented per architecture in OpenBSD's LLVM | design discussion | confirmed | openbsd.org/innovations.html: "Implemented for amd64 and arm64 ... in OpenBSD 6.4, for mips64 in OpenBSD 6.7, and powerpc/powerpc64 in OpenBSD 6.9" | stated in §14 |
| W^X; PIE by default | system-architecture §14 | confirmed | innovations.html: "Strictly enforced by default since OpenBSD 6.0"; PIE "enabled globally by default" since 5.3 | cited |
| arm64 and riscv64 are supported ports; new ports cross-compiled and QEMU first | design discussion | partly confirmed | openbsd.org/plat.html lists arm64 and riscv64 as officially supported ("the architecture can self-compile itself"). The bring-up method (cross-compiling, QEMU) was not read | platform fact cited; method not stated in any document |
| OpenBSD requires SMP; enables SMAP on amd64; MD parts (locore, pmap, machdep, FDT/ACPI, boot loader) | design discussion; system-design D11 | could not verify | SMAP did not appear on the pages read | marked "not checked" |
| In-tree targets M68k, MSP430, AVR | system-architecture §14 | wrong | `llvm/CMakeLists.txt` 21.1.8: `LLVM_ALL_TARGETS` includes AVR and MSP430; M68k is in `LLVM_ALL_EXPERIMENTAL_TARGETS` (with ARC, CSKY, DirectX, Xtensa) | M68k is described as experimental |
| M68k appeared in LLVM release N | design discussion | could not verify | the release notes of 15, 16 and 17 contain no mention of it | not claimed |
| `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD` exists | design discussion | confirmed | `llvm/CMakeLists.txt` lines 546 to 561 | none |
| RISC-V selects compressed forms by a CompressPat mechanism (RISCVCompressInstEmitter) | design discussion | wrong (name) | `llvm/lib/Target/RISCV/RISCVInstrInfoC.td` uses `CompressPat`; the generator is `llvm/utils/TableGen/CompressInstEmitter.cpp` ("a tablegen-driven CompressPat based Instruction Compression mechanism") and the RISC-V CMake line is `-gen-compress-inst-emitter`. `RISCVCompressInstEmitter` is not in 21.1.8 | the document uses the current name |
| LLVM supports RISC-V Zfinx and Zdinx | design discussion; system-architecture §14 | confirmed | `RISCVFeatures.td`: `FeatureStdExtZfinx` ("'Zfinx' (Float in Integer)"), `FeatureStdExtZdinx` | cited |

## 3. RISC-V

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| PTE flags V R W X U G A D in bits 0..7, PPN from bit 10, PBMT at 62:61, N at 63 | system-design D6, D7 | confirmed | QEMU `target/riscv/cpu_bits.h`: `PTE_V 0x001` ... `PTE_D 0x080`, `PTE_PBMT 0x6000000000000000`, `PTE_N 0x8000...`, `PTE_PPN_SHIFT 10` | none |
| Sv39 is satp MODE 8 | system-design | confirmed | `cpu_bits.h`: `VM_1_10_SV39 8`, `SATP64_MODE 0xF000000000000000` (Bare = 0 is the absence of a mode; not separately seen) | none |
| Svade and Svadu exist | system-design D8 | confirmed | `target/riscv/cpu.c`: `ISA_EXT_DATA_ENTRY(svade ...)`, `(svadu ...)` | none |
| fflags layout NX=0 UF=1 OF=2 DZ=3 NV=4 | errata 17 | confirmed | `cpu_bits.h`: `FPEXC_NX 0x01, UF 0x02, OF 0x04, DZ 0x08, NV 0x10` | none |
| canonical NaN for half precision is 0x7e00; NaNs are not propagated | errata 26; `pdp64exec.c` `d2h` | confirmed | QEMU `target/riscv/tcg/translate.c`: `0xffffffffffff7e00` (NaN-boxed); `cpu.c`: `set_default_nan_mode(1, ...)` | none |
| tininess is detected after rounding (RISC-V; errata 17 states it as pdp64's choice) | errata 17 | could not verify for RISC-V | QEMU sets after-rounding for ARM's AArch32 standard mode (`vfp_helper.c`) but no RISC-V setting was found; the RISC-V specification was not read. The pdp64 rule is a decision, independent of this | none |
| `sfence.vma`, SUM in sstatus, stvec modes, scause/sepc/stval | system-design D2, D10, D11 | could not verify | not looked up in the privileged specification (QEMU implements them; not grepped) | none |
| RISC-V pins down a reciprocal-estimate table | errata 16 | wrong | only in the vector extension (`vfrec7`, `vfrsqrt7`; QEMU `vector_helper.c` `frec7`); scalar F/D have none | errata 16 carries the note |
| Linux on RISC-V without hardware A/D takes extra faults | system-design D8 | could not verify | not looked up | none (it follows from Svade, which QEMU documents as a fault) |

## 4. AArch64 and ARM32

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| ARM32 has SRS and RFE | design discussion | confirmed | QEMU `target/arm/tcg/translate.c`: `gen_srs` "SRS (Store Return State)", `gen_rfe` | none |
| VBAR_ELx vector table, 16 entries 0x80 apart (4 sources x 4 types) | system-design D2 | confirmed | QEMU `target/arm/helper.c` (exception entry): `addr += 0x200` / `0x400` / `0x600` per source group, `addr += 0x80` per type | none |
| ELR_ELx/SPSR_ELx, TTBR0/TTBR1, MAIR, PAN, FEAT_HAFDBS | system-design D1, D6, D8 | partly confirmed | QEMU has `MAIR_EL1`, `E10_1_PAN` MMU indexes, "FEAT_HAFDBS has made changes, update the PTE" (`ptw.c`); ELR/SPSR/TTBR names not grepped | none |
| Linux AArch64 uses VA_BITS=39 with 3 levels on 4 KB pages as a configuration | system-architecture §7; system-design D6 | could not verify | Linux Kconfig not read | worded as "from memory" |
| 4 KB granule with 3 levels gives 39 bits | system-design D6 | consistent | arithmetic: 12 + 3 x 9 = 39; the Arm ARM was not read | none |

## 5. x86-64

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| PTE bits: P=0, RW=1, U=2, A=5, D=6, PS=7, G=8, NX=63 | system-design D7, D8 | confirmed | QEMU `target/i386/cpu.h` `PG_PRESENT_BIT 0 ... PG_ACCESSED_BIT 5, PG_DIRTY_BIT 6, PG_PSE_BIT 7, PG_GLOBAL_BIT 8, PG_NX_BIT 63` | none |
| 5-level paging optional | system-design D6 | confirmed | `cpu.h`: `CR4_LA57_MASK (1U << 12)` | none |
| PCID exists (CR4.PCIDE, INVPCID); "12 bits" | system-design D10 (ASID comparison) | partly | `CR4_PCIDE_MASK`, `CPUID_7_0_EBX_INVPCID` exist; the 12-bit width was not seen | the documents do not state the width |
| x86 makes a negative NaN for 0/0 | errata 26 | confirmed | `target/i386/tcg/fpu_helper.c`: `set_float_default_nan_pattern(0b11000000, ...)` (sign bit set) | none |
| IDT 256 gates; interrupt entry pushes SS, RSP, RFLAGS, CS, RIP, error code; TSS RSP0/IST; SYSCALL via STAR/LSTAR not touching the stack; SMAP/SMEP, STAC/CLAC; PA bits 12..51 | system-design D1, D2, D3, D6, D11 | could not verify | Intel SDM not read | marked "from memory" in §6 of system-design |
| On Intel, `SHL r,CL` takes three micro-operations because of flag merging | in-order doc §4 item 1; (ooo-readiness) | could not verify | the uops.info table page was not read; Agner Fog and the optimization manual not read | marked "not verified" |

## 6. MIPS, SPARC, POWER

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| MIPS general exception vector is at offset 0x180 | system-design D2 | confirmed (offset) | QEMU `target/mips/tcg/system/tlb_helper.c`: `offset = 0x180;` (the TLB refill offset 0 and the base 0x80000000 for the 32-bit case were not separately seen) | none |
| MIPS has EPC, Cause, BadVAddr, ERET; KSEG0/KSEG1 | system-design D1 | partly | `CP0_EPC` and a KSeg0 comment (`cpu.c`) seen; the rest not grepped | none |
| SPARC trap table: TBR, entries of 16 bytes | design discussion | confirmed | QEMU `target/sparc/int32_helper.c`: `env->tbr = (env->tbr & TBR_BASE_MASK) \| (intno << 4)`; 256 entries (8-bit trap type) not seen | none |
| POWER SRR0/SRR1 | system-design D1 | could not verify | not looked up | none |

## 7. PDP-11 and VAX

All of the following are from memory of the PDP-11/70 and VAX handbooks and could not be verified (no scan was read): PDP-11 vectors of two words, new PC and PSW pushed on the new mode's stack, modes 00/01/11, priority in bits 7:5, MMR0/MMR1/MMR2 and the MMR1 journal, MFPI/MTPI, eight PAR/PDR pairs per mode, BR4 to BR7; VAX System Control Block, four modes, IPL 0 to 31, CHMK/CHME/CHMS/CHMU, REI, P0/P1/system regions with base and length registers, FPD. The VAX "MAPEN" register name and "about 300 words, 120 operations for VAX; about 60 for the PDP-11" (CHANGES-SINCE-R20 §13) are likewise unchecked; the latter is marked so. Suggested sources: bitsavers.org PDP-11/70 Processor Handbook and VAX Architecture Handbook.

## 8. IEEE 754 and binary16

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| binary16: 1/5/10, max 65504, min subnormal 2^-24, min normal 2^-14 | errata 27; `pdp64exec.c` | confirmed | Wikipedia *Half-precision floating-point format*: "±65,504"; "The minimum strictly positive (subnormal) value is 2−24 ≈ 5.96 × 10−8. The minimum positive normal value is 2−14"; "exponent uses 5 bits"; "only 10 bits of the significand appear in the memory format but the total precision is 11 bits" | none |
| bfloat16 is 1/8/7 | design discussion | confirmed | same page: "the top 16 bits of a 32-bit float (8 exponent and 7 mantissa bits) called a bfloat16" | none |
| binary32 about 7 decimal digits, binary64 15 to 16 | design discussion | could not verify | not looked up (standard figures) | none |
| A double result rounded to binary16 is correctly rounded for + - x / sqrt because 53 >= 2 x 11 + 2 (Figueroa) | `pdp64exec.c` comment (lines 185-188) | could not verify | the theorem (Figueroa, "When is double rounding innocuous?", ACM SIGNUM Newsletter 30(3), 1995: innocuous when p' >= 2p + 2) is quoted from memory; 53 >= 24 holds, and the multiplication/addition exactness argument in the comment (22-bit products are exact in 53 bits) is sound by arithmetic. The code is also exercised by the tests, which is evidence, not proof | the source comment does not cite Figueroa |
| FMA does not have the property, so 128-bit integers are used | `pdp64exec.c` | could not verify (the claim); the code is a design choice | follows from the exact-sum argument; no source | none |
| Tininess after rounding | errata 17 | decision, see section 3 | | none |

## 9. Performance statements

| Claim | Where | Verdict | Source | In the documents |
|---|---|---|---|---|
| small in-order cores give about 2 to 3 CoreMark/MHz, three-wide out-of-order cores 5 to 6 or more | in-order doc §2 | could not verify | the Wikipedia BOOM page has no CoreMark figure; no SiFive or EEMBC score was fetched | marked "not verified" |
| good out-of-order cores give 2 to 4 times the IPC of simple in-order cores | in-order doc §2, §5 | could not verify | none found | marked |
| compiler scheduling recovers 5 to 15% on in-order integer code | in-order doc §2 | could not verify | none found | marked |
| out-of-order cores are several times to ten times the area of in-order cores of the same ISA | in-order doc §3, §5 | could not verify | none found | marked |
| a non-speculative in-order core has no Spectre-class channels | in-order doc; ISA §17 | confirmed in the large, with a caveat | Wikipedia *Spectre*: Arm's "Immune hardware" list includes Cortex-A53, A55, A32, A7, A5; affected: A8, A9, A15, A17, A57, A72, A73, A75, R7, R8; "higher-performance CPUs tend to have intensive speculative execution, making them vulnerable". Cortex-A8 (in-order, from memory) is on the affected list, so "in-order" alone is not the criterion; speculation is. The pdp64 text says "non-speculative", which is the right word | the caveat is stated |

## 10. The original ISA text (`docs/orig/`)

| Claim | Verdict | Source |
|---|---|---|
| "x86 chose CRC-32C for SSE4.2 CRC32 and ARM chose the Ethernet CRC-32 (CRC32 instructions)" | wrong in part | Wikipedia *Cyclic redundancy check*: "CRC-32C computation is implemented in hardware as an operation (CRC32) of SSE4.2 ... ARM AArch64 architecture also provides hardware acceleration for both CRC-32 and CRC-32C operations." ARM provides both polynomials, not only the Ethernet one. The x86 half is correct. (Reported only; the text of `docs/orig/` is kept as written.) |
| "ARM's memory model took roughly a decade to formalize" | could not verify | not looked up (reported only) |

## 11. What the facts call into question

* Nothing found contradicts a design decision. The PTE layout, the vector table geometry and the fflags layout agree with what the documents say other machines do.
* The operating-system plan is OpenBSD first and UNIX/32V as the fallback. The licence of the 3BSD sources is not established by anything read; only the 32V fallback is covered by the 2002 licence, so the plan does not depend on 3BSD.
* The out-of-order document's quantitative arguments (2 to 4 times speed, up to ten times area) have no cited basis; the qualitative arguments (precise exceptions, flag merging, SC cost) do not depend on them.
* The software accessed and dirty bit choice is justified partly by "how 3BSD paged on the VAX"; that rests on the unverified reference-bit claim. The design merits (a walker that never writes) stand without it.

## 12. Still to do (needs a browser or the manuals)

URLs to fetch: bitsavers PDP-11/70 handbook and VAX Architecture Handbook; the Babaoglu and Joy SOSP 1981 paper (ACM DL); tuhs.org/Archive/Distributions/UCB/3BSD and the Caldera licence; RISC-V privileged specification (riscv.org); Intel SDM vol. 3; Arm ARM (DDI 0487); uops.info `SHL_R64_CL` page; Agner Fog `instruction_tables.pdf`; Rocket and BOOM papers and EEMBC CoreMark scores; Figueroa 1995; the OpenBSD `arch/*/conf` or `Makefile.inc` files for the compiler per port.
