# Pilot notes (for the owner; not part of the annex volume)

The pilot is 14 entries, `01-` to `14-`, with the template (`00-template.md`) and the README. Nothing outside `docs/annex/` was touched; no generator and no git command was run; scratch files went to the session's scratchpad. These notes may name errata and register rows; the entries do not.

## 1. The entries, the sources, and what each cannot claim

Length: the entries run 750 to 1,050 words *including* their code blocks (about 550 to 800 words of prose), so over the 300 to 600 aim; the before-and-after blocks account for most of it. One to three snippets each.

| # | entry | sources read | verified against | not verified / left out |
|---|---|---|---|---|
| 01 | sequential consistency; no DB forms | `rejudge-timer-iommu-irq-atomics.md` F15; `kernel-pain-points.md` (rows on store-buffer test, mixed size, ordering vocabulary count); `hardware-vulnerabilities.md`; OpenBSD `sys/arch/{arm64,riscv64,amd64,alpha}/include/atomic.h` (read on this machine); manual 7 | foreign code assembled with clang 19 (Arm, RISC-V) and gcc 14 (x86), compiled from C for the fetch-add; the Alpha lines are quoted from OpenBSD (no Alpha toolchain here) | the cost on a large out-of-order core (not measurable); Peterson's algorithm is stated as textbook knowledge, not from a repository source |
| 02 | misaligned and uncached atomics | `kernel-pain-points.md` rows 735, 750, 828 to 830 (Yu cover letter 21 Nov 2019, Zijlstra, Torvalds 19 Feb 2025); `best-of-breed-iommu-irq-atomics.md` H10, H11; manual 7.4 | x86 `lock xaddl` at offset 1 from gcc 14; clang's library-call output for RISC-V and Arm (seen) | the quotations are the repository's saved copies of the lore pages; I did not refetch them |
| 03 | `RTI` with a mask | `rejudge-holes-rti-resume-hv.md` A8, A9, A12, B1, B2; `bench-rti-mask-reuse.md`; `hardware-vulnerabilities.md` MDS, Zenbleed, lazy FP rows; OpenBSD `locore.S` lines 603 to 622 | OpenBSD excerpt quoted verbatim from the file on this machine; `ex08-return-mask.S` run on sim64 (exit 0) | the dates and the "partially addressed RIDL" quote are the repository's secondary records |
| 04 | the arena | `hypervisor-text-v3.md` examples 1 and 6, 6.16.25; `rejudge-holes-rti-resume-hv.md` A1 to A7; `best-of-breed-mmu-virt.md` H1; OpenBSD `vmm_machdep.c` `vcpu_run_vmx()`; the CVE record | the CVE record fetched 2026-11-25 (`cveawg.mitre.org/api/cve/CVE-2026-99312`): the fetch returned the title line "Force an MMU reset when emulating an INIT even if paging was already disabled", published 2026-11-18T08:42:06Z, assigner Linux; the longer description was truncated by the fetch tool, so the "stale MMU context" wording is cited to the repository's earlier reading, not to my fetch | the Arm "flushes on VMID change, reuse left to software" remark is the repository's reading of QEMU's model |
| 05 | IOMMU blocked at reset | `best-of-breed-iommu-irq-atomics.md`; `hardware-vulnerabilities.md` DMA rows and Thunderclap; manual 2.11; `security-corpus.md` SEC-D01; OpenBSD `sys/dev/acpi/acpidmar.c` | OpenBSD excerpt verbatim; Thunderclap and Thunderbolt quotes from the repository (the paper was read in full in its round 6) | Intel VT-d pass-through is not claimed (the repository did not read that chapter); I did not refetch Thunderclap |
| 06 | the timer | `timer-design.md`; `rejudge-timer-iommu-irq-atomics.md` T1 to T8; `kernel-pain-points.md` (Gleixner, LWN 19 May 2010); OpenBSD `sys/arch/arm64/dev/agtimer.c` | OpenBSD excerpt verbatim | PDP-11 line-clock frequency not claimed; the x86 deadline race and RISC-V "eventually" are the repository's readings |
| 07 | no unprivileged clock | rejudge T9; `hardware-vulnerabilities.md` (Flush+Reload row, Rowhammer row with the Project Zero quote); `timer-design.md` | `probe.c` compiled with gcc 14 | the cost is the repository's model and its x86 measurement (16.8 ns against 158 ns, 120 ns); how often programs read the clock is not measured |
| 08 | level from the vector | rejudge F6; `best-of-breed-iommu-irq-atomics.md`; manual chapters 2 and 6 (RK11 `DEVTRAP(220, rkintr, br5)`, V7 `l.s` quoted there) | the PDP-11 lines are quoted from the manual's own quotations of 2.11BSD and V7, not read from those sources by me | **the PDP-11 priority-jumper misconfiguration is "from memory, not verified" in the repository; I said only that the structure permits it**; see the inconsistencies |
| 09 | guest tag | `hypervisor-text-v3.md` 6.16.22; `best-of-breed-mmu-virt.md`; OpenBSD `vmm_alloc_vpid_vcpu()` | excerpt verbatim | what happens when the 16-bit counter wraps while a guest still holds a number is not stated in the manual: I left it out |
| 10 | hypervisor translates its own | `best-of-breed-mmu-virt.md` A2, B2, H5; `sel4-fit.md` (through the study); manual 6 | the three Arm `msr` lines assembled with clang for armv8.1-a | the claim that VHE redirects register names is the repository's description of E2H; I did not read Arm's reference page for it (the mirror in `../arm-reference` holds instruction pages only) |
| 11 | vector resume | `vector-resume-design.md`; `rejudge-holes-rti-resume-hv.md` C0 to C4; `security-corpus.md` SEC-V01 to V03; manual 8 and 6 | RISC-V code written by me and assembled with clang 19 (see section 3); the pdp64 block assembled and run (`ex08-vector-sum.S`, strips 16 and 64 run, exit 0) | no real RVV kernel source was available on this machine; my RVV loop is not the best possible one |
| 12 | stricter type wins | `best-of-breed-mmu-virt.md` H6, A3; kernel-pain-points (Mosberger 2001); OpenBSD `if_em.c` | `memtype.S` assembled; OpenBSD excerpt verbatim | Arm FWB and RISC-V PBMT are the repository's readings; the rule has no statement of its own in the manual (see below) |
| 13 | first parcel | manual 9 (the corpus figures); `arch-comparison.md`; `hardware-vulnerabilities.md` JCC and F00F rows | the sizes of the five-line sequence assembled for x86-64, rv64g, rv64gc, AArch64 and pdp64 | the corpus figures are quoted from the manual; I did not rerun them |
| 14 | faulting load (corpus SEC-B17, the Meltdown rule) | `security-corpus.md`; `hardware-vulnerabilities.md` C1, Meltdown, L1TF rows; OpenBSD `locore.S` | OpenBSD excerpt verbatim; `faulting-load.S` run on sim64 -K (exit 0) | sim64 has no speculation or cache: the probe tests the architectural form only |

## 2. Snippets that cannot be assembled (not marked in the text)

* `snippets/timer.S`: `mfsr ... time`, `mtsr timecmp` are refused by the current `as64` ("expected a system register name and a register"). The same refusal for `docs/encoding-work/hypervisor-text-v3-snippets/ex05-timer.S`. The names are in the manual and not yet in the assembler's table.
* `snippets/arena.S`: `mtsr harena` and `mtsr hepoch` are refused in the same way. (`gtbr` assembles: `snippets/guest-tag.S` is fine.)
* Everything else assembles with `build/as64`; `spsc-ring.S`, `split-lock.S` (-K) and `faulting-load.S` (-K) also link and run on `sim64` and exit 0; `rti-syscall.S`, `level.S`, `guest-tag.S`, `hv-own-translation.S`, `resume-token.S`, `memtype.S` and `user-time.S` assemble only. `fpsr-clear.S` and `sizes.S` assemble but are not used by any entry (the first was for a corpus entry I replaced).
* Not shown in the entries for lack of a form to assemble: the IOMMU one-leaf table (entry 05) and the guest-reset case of entry 04.

## 3. How each foreign snippet was obtained

Quoted verbatim from files on this machine (OpenBSD source at `/home/matthew/claude/openbsd-src/sys`): the Alpha `atomic_setbits_ulong` and the `membar_*` macros (`arch/*/include/atomic.h`); `arch/amd64/amd64/locore.S` lines 603 to 622 and 630 to 652 (system-call return, entry 03 and 14); `vmm_machdep.c` (`vcpu_run_vmx()` near line 3974 and `vmm_alloc_vpid_vcpu()`, entries 04 and 09); `sys/dev/acpi/acpidmar.c` (`iommu_enabled()` and the "Disable IOMMU" path, entry 05); `arch/arm64/dev/agtimer.c` (entry 06); `dev/pci/if_em.c` (entry 12). The two PDP-11 lines of entry 08 are quoted from the manual's own quotation of V7 `l.s` and 2.11BSD `pdp/scb.s`; I did not find those source trees on this machine.

Assembled or compiled here (files in `snippets/foreign/`): with Debian clang 19.1.7 for AArch64, RISC-V (`rv64g`, `rv64gc`, `rv64gcv`) and x86-64, sizes read with `llvm-size-19` and `readelf`: `mp-aarch64.s`, `mp-riscv64.s`, `mp-x86.s` (24, 24 and 12 bytes), `rvv-sum.s` (42 bytes, written by me), `el.s` (12 bytes, with `-march=armv8.1-a` for `ttbr0_el12`), `sizes-*.s`; with gcc 14.2 and clang for the C: `fetchadd.c` (`lock xaddq`, `lock xaddl %eax,1(%rdi)`, `amoadd.d.aqrl`, `ldaxr`/`stlxr` loop) and `probe.c` (`clflush`, `rdtscp`). The C of `fetchadd.c` and `probe.c`, and the assembly of the `mp-*` and `sizes-*` files and of `rvv-sum.s`, I wrote; the compiled output and the byte counts are real. The `../llvm-build-22` build has only the pdp64 target, so it could not be used for other machines.

Not available: Alpha, VAX, PDP-10, 6502, Z80, S/360 assemblers (clang has `systemz`, `m68k`, `mips`, `ppc`, `sparc`, `avr`, `msp430` targets, which I did not need). I used no foreign snippet that I could not check; the PDP-11 text in entry 08 is quoted as a quotation.

## 4. Things I found inconsistent while writing

1. **The level of an interrupt.** The decision (every interrupt's level is its vector number divided by 32; eight levels of 32 vectors) is not stated in `docs/manual-src`, and the manual says the timer is "vector 32 at level 6" and the console "level 4" (vectors 33, 34); 32 divided by 32 is 1. The guest's virtual lines also each carry a vector of their own (`VIVEC`). No code implements the rule. The entry states the rule and avoids naming the timer's vector, and the owner needs to decide what the timer's level is.
2. **The stricter memory type.** The rule that the stricter of the two stages counts, (the larger memory type code is the stricter: cached 0, uncached 1, device weak 2, device strong 3), has no statement of its own in the manual (it appears as one clause of the atomics statement), and the executor's walker carries no type (the QEMU `mmu.c` comment says so). The entry cites the statements that exist.
3. **The guest tag counter.** What the hardware does when its 16-bit counter wraps while a guest still holds the number it hands out is not stated; two live guests with one tag would share translations.
4. **The security-corpus index is stale against the manual.** Its rows SEC-B14 (guest reset in place), SEC-V01 to V03 (the vector record) are FOUND, and SEC-M10 says the hypervisor has no translation of its own; the manual now states the arena rule, the record keyed by context, and a hypervisor level with its own translation.
5. **The assembler lags the manual**: `TIME`, `TIMECMP`, `HARENA` and `HEPOCH` are refused (section 2); the hypervisor-snippets README lists `ex05-timer.S` as "assembled" and it is not.
6. **The tokens.** The request names `{{st:name}}` and `{{h:name}}`; `docs/manual-src/README.md` defines `{{r:name}}` (and `{{u:name}}` for links); I used `{{r:...}}` and said in the README that the syntax will be updated.
7. **The Intel IOMMU pass-through** is "unverified" in the repository's study; I claimed it for Arm and RISC-V only.
8. **The CVE fetch** returned only the title line (section 1, entry 04).

## 5. Estimate for the whole annex

Counts. `docs/decision-register.md` has 536 rows: 304 decisions (285 of them current), 107 rationales, 102 context rows and 23 questions. About 70 of the decisions are about the manual, the book, the repository or the process, and about 70 more are about assistant behaviour, other projects or minor spellings; neither belongs in the annex. `docs/errata.md` has 140 entries headed DECISION, DECISIONS or DECISION (the owner's or the assistant's): 136 of them carry architecture decisions, and most repeat or detail a register row. A keyword classification of the 148 current architecture decision rows I could place gives the proportions of the table below (the classification is crude: a row can belong to two parts). Many decisions travel together (one entry told the arena, the epoch word and the device refusal), and a good entry is a pattern, not a row. So I estimate by pattern.

| part | decision rows (rough) | estimated entries | agent-hours (1 to 1.5 per entry: sources 30%, foreign snippets 40%, writing and checking 30%) |
|---|---|---|---|
| 1 memory model and atomics | 25 | 20 | 25 |
| 2 translation and the TLB | 12 + hypervisor translation rows | 18 | 22 |
| 3 interrupts and the timer | 5 + timer and interrupt rows inside others | 14 | 17 |
| 4 privilege, returns and registers | 15 | 22 | 27 |
| 5 virtualization and the IOMMU | 4 + the 26 virtualization answers and IOMMU rows inside errata | 26 | 33 |
| 6 vector blocks and resume | 30 | 20 | 25 |
| 7 encoding and the instruction set | 24 | 30 | 35 |
| 8 the security corpus | 4 + 81 holes in 7 classes | 24 (one per group of holes) | 28 |
| 9 the toolchain and the ports | 29 | 16 | 18 |
| **total** | | **about 190** | **about 230** |

The time per entry is my estimate from this pilot, where I spent most of the effort on verifying foreign snippets and on finding the real quotation; I did not time each entry. With nine agents in parallel, one per part, and the owner's review in between, I would plan four to six working days elapsed; the parts with most foreign material (4, 5 and 7) take the longest, and part 9 the least. Part 8 needs the corpus index brought up to date first (inconsistency 4).

## 6. What would help the next pass

* A short list of verified foreign sources per part, built once (OpenBSD files, the repository's studies), so the agents do not look for them again.
* The assembler knowing `TIME`, `TIMECMP`, `HARENA`, `HEPOCH` (and `GTOKEN`, `GTIMECMP`), so the after-snippets all assemble.
* A decision on inconsistency 1.

## 4. Entry 15 (granule colours)

Sources read: `../openbsd-src/lib/libc/stdlib/malloc.c` (`$OpenBSD: malloc.c,v 1.303 2026/11/13 07:13:50 otto Exp $`): `malloc_bytes`, `free_bytes`, `find_chunknum` (the "double free" test is the bitmap bit), `MALLOC_DELAYED_CHUNK_MASK`, `chunk_canaries`, junk fill; and the semantics in the phase A decisions note. Snippets: `colour-slab-before.S` (my rewrite in pdp64 assembler of the slab chunk, shortened, adapted from that file, not verbatim), `colour-slab-after.S`, `colour-slab-use.S`, `colour-neighbours.S` (mine). All four assemble with `build/as64` (plain and relaxed). **None was run**: the executor does not implement the colour words yet (they trap as unimplemented), so the sequence in the text (colours 2 and 3, the overflow, the stale pointer, the double free) is the specified behaviour, worked by hand, not an observed one. Counts in the entry are from the assembled code and `encdis -a -r`: before 15 and 16 instructions (alloc, free paths), 90 bytes; after 27 and 26, 184 bytes. Left out for lack of a source read here: any statement about Arm MTE, SPARC ADI or other machines' tagging. Not checked: the slab routines' logic beyond reading (no run); the first-use page set-up (colour 15 on the whole page, zero first words) is not shown.
