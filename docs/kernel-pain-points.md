# What hurts kernel developers: tight loops, pain points and workarounds in the current Linux and BSD kernels, compared with pdp64

[← pdp64 index](../README.md)

**Part II of the kernel assembly survey ([`kernel-asm-survey.md`](kernel-asm-survey.md)).** Part I counts the instructions a kernel hand-writes; this part asks why: which paths run so often that cycles and bytes matter, which hardware behaviours cost kernel developers the most effort, what they do about them, and how the pdp64 system design stands against each.

**Status: Phase 1 complete; Phase 2 (the lists) started.** Phase 1 reads only local sources: the current Linux, FreeBSD, NetBSD and OpenBSD source trees (shallow, sparse checkouts under `~/claude/kernel-src`, the commits named in Appendix B), the Linux `Documentation/` tree, the BSD section 9 manual pages, the old Unix sources in `~/claude/facetlang/unixtree`, and the pdp64 documents. Everything that needs history (when a pain started, how it changed over thirty years, what the mailing lists argued about) or the web (papers, articles, mailing-list archives) is **not done**: it is Phase 2, listed in Appendix C with the status "not yet". Statements from memory are labelled *unverified* and are not used as evidence.

**Evidence labels used throughout.** **[G] guarantee**: a manual, standard or the developers' own documentation states it. **[P] practice**: the current kernel code, a Kconfig help text or a count over the code shows it. **[S] secondary**: an article or wiki (none yet; Phase 2). **[U] unverified**: from memory, to be fetched. Every number says how it was measured, in the text or in Appendix B.

**The author's principles, in order, are the yardstick** (decisions-pending, Part 0): (a) code size, (b) easy recoverability, meaning fewer possible errors and less recovery code, (c) speed and efficiency through fewer gates and tighter hot loops. Verdicts: **DESIGNED AWAY** (the problem cannot arise), **MITIGATED BY DESIGN** (it arises in a smaller or cheaper form), **SAME PROBLEM**, **WORSE**, **UNKNOWN** (not yet defined, or depends on an open decision). Decision identifiers (P1 to P16, Q1 to Q15, R1 to R8, S1 to S6) point to [`decisions-pending.md`](decisions-pending.md); E-numbers to [`errata.md`](errata.md).

## Contents

* [1. The short version](#1-the-short-version)
* [2. How much of a kernel exists to work around hardware: the counts](#2-how-much-of-a-kernel-exists-to-work-around-hardware-the-counts)
* [3. Entering and leaving the kernel](#3-entering-and-leaving-the-kernel)
* [4. Speculation: the security tax](#4-speculation-the-security-tax)
* [5. Address translation: the TLB, page tables, accessed and dirty bits](#5-address-translation-the-tlb-page-tables-accessed-and-dirty-bits)
* [6. Memory ordering, atomics and locks](#6-memory-ordering-atomics-and-locks)
* [7. Caches, DMA and device memory](#7-caches-dma-and-device-memory)
* [8. Machine state: floating point, vectors, per-CPU data, context switch](#8-machine-state-floating-point-vectors-per-cpu-data-context-switch)
* [9. User memory, faults and exception tables](#9-user-memory-faults-and-exception-tables)
* [10. Interrupts, timers, time and idle](#10-interrupts-timers-time-and-idle)
* [11. Alignment, byte order, word size and compatibility](#11-alignment-byte-order-word-size-and-compatibility)
* [12. Patching running code, tracing and hardening](#12-patching-running-code-tracing-and-hardening)
* [13. Machine checks, errata as a phenomenon, virtualization, fast paths](#13-machine-checks-errata-as-a-phenomenon-virtualization-fast-paths)
* [14. The PDP-11 and VAX era, from the old sources](#14-the-pdp-11-and-vax-era-from-the-old-sources)
* [14A. What the developers say: list posts and articles read so far](#14a-what-the-developers-say-list-posts-and-articles-read-so-far)
* [14B. Round 2: developer statements by area](#14b-round-2-developer-statements-by-area)
* [14C. How many sources, by area](#14c-how-many-sources-by-area)
* [14D. Round 3: developer statements, chosen threads and primary papers](#14d-round-3-developer-statements-chosen-threads-and-primary-papers)
* [15. What this means for pdp64](#15-what-this-means-for-pdp64)
* [16. What this does not show](#16-what-this-does-not-show)
* [Appendix A: the pain-point catalogue](#appendix-a-the-pain-point-catalogue)
* [Appendix B: the counts, the method and the commands](#appendix-b-the-counts-the-method-and-the-commands)
* [Appendix C: Phase 2, the reading list and the plan](#appendix-c-phase-2-the-reading-list-and-the-plan)

## 1. The short version

Read the current Linux tree for what hurts and the picture is consistent. **Three costs dominate**, and pdp64's design touches each in a different way.

1. **The cost of crossing the privilege boundary and of the state kept across it.** Linux's x86-64 entry code is a long list of defences: a page-table switch (a `mov` to `cr3` "on the order of a hundred cycles" at every entry and exit, in the developers' words, `Documentation/arch/x86/pti.rst`, [G]), a `swapgs` that "must nest perfectly" (`Documentation/arch/x86/entry_64.rst`, [G]), register clearing, speculation barriers. pdp64's entry writes no memory and has no speculation, so it escapes most of this today (estimated 4 to 5 instructions against 45 to 70, survey section 8, a paper estimate). **The exposure is the future out-of-order core and the single page-table base**: the whole defence exists because the kernel is mapped in every user address space, which is exactly what pdp64 does (system design D6).
2. **Everything caused by hardware that reorders, caches and speculates.** Barriers, memory-ordering documentation, cache-maintenance hooks, DMA bounce buffers, RCU, per-architecture TLB flush rules. In the current Linux tree the vocabulary of ordering (`smp_mb`, `READ_ONCE`, and relatives) matches **5,596 lines of code in 855 files** and 743 lines of documentation; `Documentation/memory-barriers.txt` is 3,016 lines [P, counted]. pdp64 is sequentially consistent, in-order and cache-coherent between CPUs, so almost all of it **does not arise** (ISA 17.1); the cost is moved onto the implementer of any future fast core (readiness review, section 6.10).
3. **Everything caused by hardware that is defective or inconsistent between vendors.** 110 Kconfig options named *ERRATUM* or *ERRATA* under `arch/` (64 arm64, 32 arm, 14 riscv) [P, counted]; 45 x86 bug flags and 58 rows of an x86 vulnerability blacklist; 19 files and 4,164 lines of `hw-vuln` documentation; a 3,830-line `bugs.c` that only chooses mitigations. No design avoids this for a real chip. What a design can do is to have fewer features to be wrong about, and a way to learn what the chip is (P4), a recovery path that is short (principle b), and honesty that this is not yet tested: **pdp64 has no silicon, so it has no errata, which is not the same as having none.**

**Where pdp64 is exposed** (detail in section 15): software-managed accessed and dirty bits (an extra fault on first touch of every page, Q2); one page-table base for both halves with no speculation defence if the core ever speculates; broadcast `TLBI` per page with no range or by-ASID form until P5; machine checks that halt instead of recovering; a 39-bit address space; no defined cross-modifying-code rule; interrupt controller, IPIs, DMA protection and virtualization not yet defined (R1, R2, R6, R8); cache aliasing and non-coherent DMA not yet faced.

## 2. How much of a kernel exists to work around hardware: the counts

The unit of evidence is *how much of the current kernel exists to work around this*. Two kinds of measure, both **[P]** (practice: the code itself) and both described exactly in Appendix B.

**Structural measures**: a named file, table or option set, counted with one command each. The most telling are in this table.

| Measure | Tree | Value | Unit |
|---|---|---:|---|
| Kconfig options named *ERRATUM/ERRATA anywhere under arch | linux | 110 | options |
| Kconfig options named *ERRATUM/ERRATA in arch/arm64/Kconfig | linux | 64 | options |
| X86_BUG_* bug flags defined | linux | 45 | flags |
| CPU model rows in the vulnerability blacklist (VULNBL_*) | linux | 58 | rows |
| MITIGATION_* Kconfig options in arch/x86/Kconfig | linux | 24 | options |
| files in Documentation/admin-guide/hw-vuln | linux | 19 | files |
| lines in Documentation/admin-guide/hw-vuln | linux | 4,164 | lines |
| lines of arch/x86/kernel/cpu/bugs.c (mitigation selection) | linux | 3,830 | lines |
| lines of arch/arm64/kernel/proton-pack.c (Spectre/BHB mitigations) | linux | 1,213 | lines |
| lines of arch/arm64/kernel/cpu_errata.c | linux | 1,088 | lines |
| lines of Documentation/memory-barriers.txt | linux | 3,016 | lines |
| lines under Documentation/RCU | linux | 36,824 | lines |
| lines under Documentation/locking | linux | 4,554 | lines |
| lines of C in arch/x86/kernel/fpu | linux | 4,364 | lines |
| lines in arch/x86/entry (assembly and C) | linux | 4,239 | lines |
| lines of C in arch/x86/kernel/cpu/mce (machine checks) | linux | 7,111 | lines |
| exception-table annotations in arch/x86 (_ASM_EXTABLE*, EX_TYPE_*) | linux | 260 | lines |
| files named *cache* or *tlb* under arch/*/mm and arch/*/kernel | linux | 80 | files |
| lines in those files | linux | 26,826 | lines |
| files under arch/*/include and arch/*/mm mentioning flush_tlb_ | linux | 189 | files |
| files under arch mentioning flush_dcache_page, flush_cache_, flush_icache_ | linux | 131 | files |
| READ_ONCE/WRITE_ONCE uses in kernel and mm | linux | 2,128 | lines |
| smp_mb/rmb/wmb/load_acquire/store_release uses in kernel, mm and arch | linux | 1,146 | lines |
| this_cpu_/__this_cpu_/per_cpu( uses in kernel, mm, arch | linux | 3,225 | lines |
| lines of C in kernel/sched | linux | 56,661 | lines |
| lines of C in mm | linux | 193,507 | lines |

**Vocabulary counts**: each category is a regular expression (Appendix B lists them all) run with `grep -rPIc` over every file of each tree, summed by architecture directory or subsystem and by file kind (code, documentation, Kconfig). The counts are lines that match, not occurrences, and a regular expression measures vocabulary, not truth: "race" matches a comment about a race; "tlb" matches every line of a TLB flush helper. They show where the words concentrate. Linux (91 sparse directories: all of `arch/` for eleven architectures, plus `mm`, `kernel`, `Documentation`, `include/linux`, `lib`, `block`, `net/core`, `virt`, `drivers/irqchip`, `drivers/iommu`), commit `7be4bc52`. **The `drivers` area is almost absent**, so categories dominated by drivers (DMA, interrupts, virtualization) are undercounts.

| Pain family (categories in Appendix B) | Linux code lines (files) | Linux doc lines | OpenBSD | NetBSD | FreeBSD | Reading |
|---|---:|---:|---:|---:|---:|---|
| Ordering and barriers (`barrier-ordering`) | 5,596 (855) | 743 | 56 | 159 | 21 | Linux names its ordering primitives in text; the BSD kernels use a smaller vocabulary (`membar_*`, `atomic_*`) that this expression barely matches, so the BSD figures are not comparable |
| RCU | 3,958 (559) | 2,406 | 0 | 0 | 1 | A Linux-specific technique; OpenBSD and FreeBSD have an SMR facility with its own names |
| TLB (`tlb`) | 3,133 (604) | 276 | 402 | 1,206 | 533 | Present everywhere; NetBSD's `pmap` carries most |
| Page tables | 11,543 (849) | 780 | 353 | 480 | 913 | The largest single vocabulary |
| Cache coherence and aliasing | 1,260 (372) | 277 | 213 | 544 | 163 | `arch/mips` 352, `arch/arm` 272, `arch/sparc` 135 in Linux; `arch/x86` only 47 |
| DMA (`dma`) | 8,696 (760) | 5,860 | 869 | 1,485 | 1,233 | Drivers excluded from the sample; documentation alone is 5,860 lines |
| FPU, vector and SIMD state | 2,977 (542) | 310 | 781 | 1,330 | 1,039 | `arch/x86` 1,155 of Linux's |
| User-memory access (`uaccess`) | 3,213 (825) | 111 | 19 | 28 | 163 | `kernel` 682, `arch/x86` 486, `arch/sparc` 269 in Linux |
| Speculation family (`spectre-family`) | 496 (77) | 345 | 119 | 52 | 33 | `arch/x86` 407 of Linux's; OpenBSD `arch/x86` 110 |
| Entry trampolines and PTI (`kpti-entry`) | 455 (164) | 124 | 149 | 187 | 157 | `arch/x86` 310 in Linux |
| Errata / workaround / quirk | 396 / 270 / 400 | 142 / 186 / 270 | 74 / 30 / 10 | 108 / 64 / 16 | 143 / 75 / 62 | Linux also has 250 Kconfig lines naming errata |
| Alignment | 1,807 (472) | 175 | 450 | 292 | 244 | Mostly the `get_unaligned` helpers in `include` and `lib` |
| Byte order | 1,793 (520) | 976 | 133 | 248 | 188 | |
| Compatibility (32-bit) | 591 (309) | 167 | 88 | 448 | 406 | |
| Patching and tracing | 2,867 (608) | 737 | 24 | 348 | 30 | Linux's dynamic tracing is the heavy user of runtime code patching |
| Machine check and poison | 1,366 (309) | 602 | 154 | 232 | 95 | `arch/x86` 515, `arch/powerpc` 264 in Linux |
| Markers `XXX` `FIXME` `HACK` | 719 | 133 | 1,607 | 2,979 | 986 | Case-sensitive; BSD code is more candid about its own debts |

How measured: `grep -rPIc` per category per tree, summed over files of kind code (`.c .h .S .s .rs`), documentation (`Documentation/`, `share/man`, `.rst .txt .md .9`) or Kconfig; the full per-category tables are in Appendix B and the CSV `docs/codegen-data/kernelpain/counts.csv`. **[P]**

**The shape across architectures.** Lines matching *errata*, *workaround*, *quirk* or *hardware is broken* per 1,000 lines of code under each architecture directory (Linux): x86 0.8, arm64 0.7, arm 0.5, powerpc 0.4, mips 0.3, alpha 0.2, sparc 0.2, riscv 0.1, m68k 0.1, s390 and loongarch 0.0 (Appendix B has the counts). FreeBSD: arm64 0.7, x86 0.5, arm 0.4. The architectures with the most vendors and the most aggressive microarchitectures carry the most; the mainframe architecture (s390, one vendor, hardware-complete specification) and the youngest (loongarch, riscv in this tree) carry almost none. The reading is not that x86 is worse designed: it is that a single architecture implemented by several vendors over decades, with hidden microarchitectural state, produces a long tail of exceptions. A small in-order, single-implementer machine is at the quiet end of this table by construction, and loses that position the day a second implementation or a speculative core exists. **[P for the counts; the reading is inference]**

## 3. Entering and leaving the kernel

**What it is.** A system call, a fault or an interrupt changes privilege, switches stacks, saves registers, finds the handler and later undoes it all. It is the most frequently executed path in any kernel that serves programs, and the one most changed by the security defences of 2018 onward. Survey section 8 counts the instructions: 40 to 70 on entry for the register-at-a-time machines, 6 to 12 for machines with a multiple-register save.

**Who feels it, with evidence.**

| Pain | Evidence | Label |
|---|---|---|
| Switching page tables at every entry and exit | `pti.rst`: moves to `cr3` "on the order of a hundred cycles", "required at every entry and exit"; two page-table sets per process, an order-1 page directory (4 KB more per process), a 2 MB aligned per-CPU entry area | [G] developers' doc |
| A missed switch must crash visibly | `pti.rst`: the user half of the kernel tables has the no-execute bit set at the top level "so that any missed kernel->user CR3 switch will immediately crash" | [G] |
| The kernel-pointer register swap is fragile | `entry_64.rst`: `swapgs` "must nest perfectly and only in single depth"; the cheap test of "which mode am I in" reads the saved code segment, the "expensive (paranoid) way" reads a model-specific register | [G] |
| Entry code must not be instrumented | `core-api/entry.rst`: entry and exit code before RCU "starts watching" must carry `noinstr`; a breakpoint in the breakpoint entry would overwrite the debug registers | [G] |
| Entry is a cost centre in numbers | `lines-x86-entry` 4,239 lines; `kpti-entry` vocabulary 455 code lines in Linux (310 in `arch/x86`), 149 in OpenBSD, 187 in NetBSD, 157 in FreeBSD | [P, counted] |

**Usual workaround.** Trampolines mapped in both page-table sets; PCID/ASID tags so the switch need not flush; defer the user-side flush to exit; clear registers on entry so that stale values cannot be used by speculation; `swapgs` plus a per-CPU base. **Hot instruction sequence:** save of 15 general registers, clearing of the same, a `cr3` write, the privileged return (`iretq` or `sysretq`), `swapgs`.

**Architectures.** x86-64: hardware pushes a frame on a stack chosen by the task-state segment, software pushes the rest; a separate `syscall` path. AArch64, RISC-V, MIPS, PowerPC: registers hold the old state, software saves everything else one register at a time. m68k, VAX, s390: multiple-register save in one instruction.

**pdp64.** Entry writes no memory (Q1, System v1): `EPC`, `EPSW`, `EVA`, `ECAUSE`; vector fetch from `VBR + 8 * vector`; priority 7 on every entry (E40); `pushx`/`popx` save the exception state in one instruction each (E37); `pushm`/`popm` save registers in one; banked `R14` and `DP` remove the scratch-register problem. No `swapgs` problem (the per-CPU pointer is the kernel's own `DP`, ISA 17.4). No page-table switch today because the machine does not speculate.

| Pain | pdp64 verdict | Why, and where it shows up (principles) |
|---|---|---|
| Register-save length | **MITIGATED BY DESIGN** | 4 to 5 instructions entry, 4 exit (paper estimate, survey 8); wins (a) code size and (c) hot path |
| `swapgs`-style kernel base | **DESIGNED AWAY** | banked `DP`; wins (b): no "which mode" test, no paranoid path |
| Entry can fault (bad kernel stack, double fault) | **DESIGNED AWAY** | entry writes only registers; wins (b): no recovery code for a failed push. Cost: a second exception before the save overwrites `EPC`/`EPSW`, closed by priority 7 (E40) but **not covered: an exception in the handler's own first instructions** (the entry code and kernel stack must be pinned) |
| Fast system call past the vector fetch | **SAME PROBLEM** (small) | one 8-byte table fetch per exception, `TRAP #n` through vector 256 + n (D3); x86's `syscall` avoids a memory fetch |
| Page-table switch for isolation | **UNKNOWN** | not needed now; see chapter 4 |
| Nested exceptions in the handler | **MITIGATED** | the handler runs at priority 7 until the 2-instruction save; recovery code is the discipline itself (E40, E37) |

## 4. Speculation: the security tax

**What it is.** Out-of-order, speculating processors leak data through caches and buffers. From 2018 the kernel has had to defend itself against code that it did not write and cannot see: Spectre variants 1 and 2, Meltdown, speculative store bypass, L1 terminal fault, microarchitectural data sampling, TSX asynchronous abort, retbleed, and a long tail.

**Evidence of size.** `Documentation/admin-guide/hw-vuln/` has 19 files and 4,164 lines; the index lists 17 separate vulnerabilities [P, counted: `ls`, `cat | wc -l`]. `arch/x86/kernel/cpu/bugs.c` has 3,830 lines, `arch/x86/lib/retpoline.S` 474, arm64's `proton-pack.c` 1,213 and `cpu_errata.c` 1,088 [P]. The x86 tree defines 45 `X86_BUG_*` flags and a 58-row model blacklist; `arch/x86/Kconfig` has 24 `MITIGATION_*` options; `kernel-parameters.txt` has 177 lines mentioning mitigations, one command-line knob per vulnerability [P, counted]. The `hw-vuln` documents state the problem in the developers' words: Spectre "exploit branch prediction and speculative execution on modern CPUs to read memory, possibly bypassing access controls" (`spectre.rst`) [G]; "iTLB multihit is an erratum" that can end in "an unrecoverable CPU lockup" (`multihit.rst`) [G]; most of the mitigations "are identical for all" variants of MDS so the kernel "treats them as a single vulnerability" (`mds.rst`, paraphrase) [G]. Per kernel, `spectre-family` vocabulary: Linux 496 code lines (407 under `arch/x86`), OpenBSD 119 (110 under `arch/x86`), NetBSD 52, FreeBSD 33 [P, counted].

**The full catalogue of these flaws, with the rule that prevents each one on pdp64, is in [`hardware-vulnerabilities.md`](hardware-vulnerabilities.md) (rules C1 to C16).**

**Usual mitigation.** Page-table isolation; retpolines or indirect-branch-restricted speculation; barriers after bounds checks (`lfence`, `csdb`); flushing the L1 data cache on VM entry; `verw` to clear buffers; disabling simultaneous multithreading; microcode updates; and a boot-time selection logic that picks among them per CPU model. **Hot sequences:** `lfence`/speculation barrier, `cr3` write, `verw`, `wrmsr` to the speculation-control register, indirect branches replaced by call/return thunks.

**Architectures.** x86 and AArch64 carry the bulk; PowerPC and s390 have flush and barrier hooks (Linux `arch/powerpc` 5, `arch/s390` 4 matching code lines); MIPS, SPARC, RISC-V, m68k, Alpha have little (counted).

**pdp64.** The ISA text says explicitly that a non-speculative design has no Spectre- or Meltdown-class channels (ISA 17.1, 17.5; system design D6) [G for the design; the claim about other designs is unverified]. HINT #2 is a defined speculation barrier (E39), and `jtag`/landing pads (vector 14) give a forward-edge control-flow check by design.

| Pain | Verdict | Why |
|---|---|---|
| All speculative side channels | **DESIGNED AWAY** (today) | in-order, non-speculative (Q6, E38). Wins (a), (b): none of the 4,164 documentation lines, no per-model blacklist, no mitigation selection logic |
| The same, **on the out-of-order core the architecture is kept ready for** | **SAME PROBLEM / WORSE** | E38 keeps the door open; D6 states the cost: one page-table base, kernel mapped in every address space, "no separate-tables defence". Linux's PTI exists because of precisely this layout. The `UA` guard (E43) stops accidental kernel access to user memory, not speculative leaks. **Recommendation:** decide before an out-of-order core exists whether `PTBR` gets a second base for the kernel half (the AArch64 `TTBR0`/`TTBR1` split), which costs a register and one address-bit test and would make a PTI-like split free of the 100-cycle switch |
| Page-size change with live translation (iTLB multihit) | **UNKNOWN** | no rule yet that a mapping change from 4 KB to 2 MB must go through `TLBI` first; "page table entry changes visible only after `TLBI`" is in E39 (7) as architecture text still to be written |
| Debug of what the processor will not say (microcode, feature bits) | **UNKNOWN** | feature registers are P4 |

## 5. Address translation: the TLB, page tables, accessed and dirty bits

**What it is.** A translation cache (TLB) that must be kept consistent with page tables the kernel edits, on every core. Costs: flushing too much; flushing too little (a stale mapping is a security hole); telling other cores; walking tables on a miss; and, where hardware does not set the "accessed" and "dirty" bits itself, taking a fault to do it.

**Evidence.**

| Pain | Evidence | Label |
|---|---|---|
| Flush all versus flush one page has no right answer | `arch/x86/tlb.rst`: "There is essentially no 'right' point to choose" between a full flush and per-page `invlpg`; the code picks by a ceiling, `tlb_single_page_flush_ceiling` = 33 pages (`arch/x86/mm/tlb.c`) | [G] and [P] |
| Address-space tags make switches cheaper but not free | `pti.rst`: with PCID "the context switch code must flush both the user and kernel entries"; the user flush is deferred to exit | [G] |
| Every architecture has its own cache and TLB files | 80 files and 26,826 lines under `arch/*/mm` and `arch/*/kernel` named `*cache*` or `*tlb*`; 189 files under `arch/` mention `flush_tlb_` | [P, counted] |
| Remote invalidation is a protocol | Linux: `shootdown` vocabulary is small (28 code lines) because the kernel hides it behind `flush_tlb_*`; NetBSD `pmap` spells it out (65) and FreeBSD (41); OpenBSD (29) | [P, counted] |
| Software-managed A/D bits cost a fault | `arch/arm64/Kconfig`: `ARM64_HW_AFDBM` "hardware updates of the Access and Dirty page flags" exists to avoid "an access flag fault", default `y`; the RISC-V tree distinguishes the two behaviours | [P] |
| Page tables are the largest vocabulary | `pagetable` 11,543 Linux code lines in 849 files; `arch_pgtable_helpers.rst`, `page_tables.rst`, `split_page_table_lock.rst` exist because walking and locking page tables is a problem in its own right | [P, counted] |
| Huge pages and NUMA balancing | `huge-pages` 1,276 code lines and 842 doc lines; `mm/huge_memory.c` is 5,202 lines | [P, counted] |
| The 3BSD era had the same problem | `3BSD/usr/src/sys/sys/vmpage.c`: the clock hand runs "simulating the missing hardware reference bit" | [P, primary source] |

**Workarounds.** Choose single-page or full flush by a threshold; batch invalidations (`mmu_gather`, 1,701 lines with `mmu_notifier`); skip cores that have never run the address space (`mm_cpumask`, `cachetlb.rst`); tag entries with ASIDs/PCIDs; use huge pages to reduce misses; let hardware set A and D where available and fall back on a fault where not. **Hot sequences:** `invlpg`/`tlbi` by address, `invpcid`, `cr3` write, inter-processor interrupt and acknowledgement (x86), `dsb ish; tlbi ...is; dsb ish` (AArch64), `sfence.vma` plus a software shootdown (RISC-V).

**pdp64.**

| Pain | Verdict | Why (principle) |
|---|---|---|
| Remote shootdown by interprocessor interrupt | **DESIGNED AWAY** | `TLBI`/`TLBIA` broadcast, `TLBSYNC` waits (ISA 17.2, D10); wins (b): no shootdown handler, no per-CPU pending list, no IPI deadlock cases. Caveat: unproven until a second core exists (R3, P11) |
| Context switch flush | **DESIGNED AWAY** | 16-bit ASID, one store (ISA 8.1); `G` pages keep kernel text across switches |
| PCID-versus-PTI interaction | **DESIGNED AWAY** (today) | no PTI |
| Flush a range | **SAME PROBLEM** | only `TLBI rN` (one page) and `TLBIA` exist; a 33-page-ceiling policy and a loop of broadcasts are needed. A range or by-ASID form is P5 (medium priority); on a large mapping teardown the cost is N broadcasts. Hot-path length (c) |
| ASID rollover | **SAME PROBLEM** | policy is the kernel's, instruction semantics must be exact; `TLBIA` works until the first rollover (P5) |
| Accessed and dirty bits | **WORSE** on speed, **MITIGATED** on recovery code | Q2 chose software management: "the walker never writes memory" so the walker has no atomic read-modify-write, no fault on a write during a walk. Cost (c): one extra fault on first touch of each page and one more on first write; Linux's own default on arm64 is hardware management (`ARM64_HW_AFDBM`, default `y`) precisely to avoid that. Benefit (b): no page-table atomics, no "walker raced the kernel" cases. 3BSD did exactly this on the VAX (vmpage.c). Open: hardware management as an option (system design section 5, idea 4) |
| Page-table walk cost | **MITIGATED BY DESIGN** | three levels, three fetches per miss, 2 MB and 1 GB leaves (D6) |
| Address-space size and ASLR entropy | **WORSE** | 39 bits (512 GB) against 48; same shape as RISC-V Sv39 and AArch64's 39-bit mode, which Linux supports; less ASLR entropy [S/U for Linux's choice of the 39-bit mode] |
| Direct map, large kernel mapping | **MITIGATED** | 1 GB leaves; `DMW` format deferred (E44, P10) |
| Stale translation after a table edit | **UNKNOWN** | needs the "visible only after `TLBI`" rule written into the ISA (E39 item 7) |
| Huge-page splits, NUMA balancing | **UNKNOWN** | no NUMA; the page-size-change rule above |

## 6. Memory ordering, atomics and locks

**What it is.** On a multiprocessor, the order in which one core's writes become visible to another is not the order of the program unless the architecture says so. Weak models let the hardware reorder for speed and make every piece of concurrent software state its needs with barriers. Locks themselves have evolved because the simplest lock (test and set on one word) makes every waiting core hammer one cache line and gives no fairness.

**Evidence.**

| Pain | Evidence | Label |
|---|---|---|
| Barriers fill the kernel | `barrier-ordering` 5,596 code lines in 855 files (`kernel` 2,180, `include` 656, `net` 581, `mm` 536, `arch/x86` 301); `smp_*` barrier uses in `kernel`, `mm`, `arch`: 1,146; `READ_ONCE/WRITE_ONCE` uses in `kernel`, `mm`: 2,128 | [P, counted] |
| The model needs a book | `Documentation/memory-barriers.txt` 3,016 lines; `Documentation/RCU` about 36,800 lines; `Documentation/locking` 4,554 lines | [P, counted] |
| One architecture defined the rules | memory-barriers.txt: "The DEC Alpha CPU is one of the most relaxed CPUs there is" and "The Alpha defines the Linux kernel's memory model"; `READ_ONCE()` emits a barrier on Alpha | [G] |
| The same story from the RCU side | `RCU/Design/Requirements`: a "late-1990s meeting with the DEC Alpha architects" at which it took "a good hour" to convince them "any sort of barrier would ever be needed" | [G] |
| Lock evolution | `kernel/locking/qspinlock.c`: "Queued spinlock", built on an MCS lock; `spinlock-family` 1,464 code lines; `locking/spinlocks.rst`: the irq-disabling variants are "fairly slow", disabling interrupts is "a single instruction on a x86, but it's an expensive one" | [P], [G] |
| Atomics without hardware support | `Documentation/arch/arm/vlocks.rst`: voting locks for CPUs "which are otherwise non-coherent, in situations where the hardware provides no other mechanism"; `swp_emulation.rst`: the deprecated `SWP` is trapped and emulated with `LDREX/STREX`; `kernel_user_helpers.rst`: kernel-provided user code for "unimplemented native feature and/or instructions" | [G] |
| Split-lock atomics | `arch/x86/buslock.rst`: a bus lock "is typically thousands of cycles slower than an atomic operation within a cache line" and "brings the whole system to its knees" | [G] |
| Lock correctness tooling | `lockdep` 410 code lines; `deadlock` 591; `race` 1,108 code lines | [P, counted] |

**Workarounds.** `READ_ONCE`/`WRITE_ONCE`, acquire and release pairs, `rcu_dereference`, ticket and queued locks, per-CPU data and RCU to avoid sharing at all, lock-dependency checkers, forbidding or detecting split atomics. **Hot sequences:** `lock`-prefixed read-modify-write, `xchg`, `cmpxchg`; `ldxr/stxr` loops or the large-system-extensions `cas`/`swp`/`ldadd`; `lr/sc` loops; `dmb ish`, `fence`, `sync`, `membar`; `pause`/`wfe` in the spin; `mfence`/`lfence`.

**pdp64.** Sequentially consistent (ISA 17.1, Q5); naturally aligned accesses atomic within their size; `CAS`, `SWAP`, fetch-and-op, `LL`/`SC`, barrier-fused `_DB` forms; atomics defined on a monitor, with a constrained-sequence forward-progress rule (E45, P11); `WFE`/`SEV` wait instead of spinning (wake rule P1); `FENCE` only for device memory.

| Pain | Verdict | Why (principle) |
|---|---|---|
| Weak-ordering barriers and the documentation they need | **DESIGNED AWAY** | wins (a) and (b) most visibly: no `smp_*` family, no `rcu_dereference` barrier, no Alpha case, no ordering bugs that "reproduce once a week" (ISA 17.3). The 5,596-line vocabulary does not exist. Cost moves into hardware: a future out-of-order core "with replay" (readiness 6.10, 7) |
| Misaligned and split-lock atomics | **DESIGNED AWAY** | alignment is required (ISA 7.4); no bus-lock-on-split case |
| LL/SC livelock and fairness | **MITIGATED BY DESIGN** | constrained-sequence guarantee in E45; unmeasured, and only when a second initiator exists |
| Lock fairness and cache-line bouncing (ticket, queued) | **SAME PROBLEM** | a test-and-set lock bounces a line between cores regardless of memory model; 2 to 4 cores snooping MSI (ISA 17.3) keep it small; beyond that R3 (coherence scaling) and queued locks return |
| Atomics for devices (doorbells, descriptors) | **UNKNOWN** | monitor semantics defined (E45) but the Q64 bus mapping is R4/P11 |
| Spin-wait hint | **MITIGATED** | `HINT #1` pause and `WFE`; the lost-wake race of the idle loop is P1 |
| RCU, per-CPU, lockless techniques | **SAME PROBLEM, easier** | a software discipline on any memory model, but with SC the proofs are shorter and the dependency-ordering rule disappears |
| Double-width CAS for lock-free lists | **UNKNOWN** | P8 (not adding now) |

## 7. Caches, DMA and device memory

**What it is.** Caches that do not know about devices, or about each other's virtual aliases, or about instruction fetches; and device registers where order and count of accesses matter.

**Evidence.**

| Pain | Evidence | Label |
|---|---|---|
| Cache maintenance interfaces per architecture | `core-api/cachetlb.rst`: "The biggest problem is that of virtual aliasing in the data cache"; you have it if the D-cache "is virtually indexed, is larger in size than PAGE_SIZE, and does not prevent multiple cache lines for the same physical address". `cache-coherence` vocabulary: `arch/mips` 352, `arch/arm` 272, `arch/sparc` 135, `arch/powerpc` 119, `arch/arm64` 87, `arch/x86` 47 (code lines). 131 files under `arch/` mention `flush_dcache_page`, `flush_cache_*` or `flush_icache_*` | [G], [P, counted] |
| DMA API size | `core-api/dma-api.rst`, `dma-api-howto.rst`, `swiotlb.rst`: `dma` vocabulary 5,860 documentation lines in Linux; Part II of dma-api is "Non-coherent DMA allocations"; the howto: on non-coherent platforms the markers "ensure the minimal DMA alignment" | [G], [P, counted] |
| ARM alignment and aliasing | `arch-arm-lines-vivt-alias` 179 lines in `arch/arm` mentioning aliasing, VIVT or VIPT | [P, counted] |
| Instruction caches not coherent | `riscv/cmodx.rst`: "Instruction storage and the instruction cache (icache) are not guaranteed to be synchronized", software must use `fence.i` | [G] |
| Write buffers, delay slots | `write-buffer-delay-slot` Linux 196 code lines: `arch/arm` 78, `arch/mips` 67 | [P, counted] |
| MMIO ordering | `mmio-ordering` 1,609 code lines (drivers excluded from sample); 5 Kconfig lines | [P, counted] |
| 3BSD/VAX era | `3BSD/usr/src/sys/sys/uba.c`: "Allocate as many contiguous UBA mapping registers" and a buffered data path (BDP) flag: DMA through an address-mapping unit with its own purge rules | [P, primary source] |

**Workarounds.** `flush_dcache_page`-style hooks called by generic code at the right moments; page colouring or forced alignment to defeat aliasing; uncached mappings for DMA buffers; bounce buffers when a device cannot reach the address; `dma_sync_*`/`bus_dmamap_sync` calls around transfers; write-combining flags; read-back of a device register to flush a posted write; I-cache invalidation after writing code. **Hot sequences:** cache-line clean/invalidate by address loops (`dc civac`, `clflush`, `cache` ops on MIPS), `dsb`, `sync`, `membar`, a final read of a status register.

**pdp64.** Coherent between CPUs by snooping (ISA 17.3); DMA buffers mapped uncached (`MT = 01`) with a `FENCE` at the doorbell; `MT` values for strongly and weakly ordered device memory; `ICINV`/`ICINVA` for instruction writes; no data-cache maintenance by address yet (P6, reserve only); devices are eight registers plus DMA (Q10, R5); DMA protection and addressing undefined (R6).

| Pain | Verdict | Why (principle) |
|---|---|---|
| CPU-to-CPU cache coherence in software | **DESIGNED AWAY** | transparent hardware coherence; wins (b) |
| Data-cache maintenance hooks for DMA | **DESIGNED AWAY for now** | uncached DMA mapping means the 131-file family of hooks is not needed; wins (a), (b). **Costs (c):** every CPU access to a DMA buffer goes to the bus at bus speed, so a driver that parses a received packet pays for each load; this is the argument for P6 (cache clean/invalidate by address) when a non-coherent master appears |
| Virtual-cache aliasing | **UNKNOWN** | the ISA says "a cache question, not an ISA question"; the rule that avoids all of it is simple (cache index bits within the 12-bit page offset, or a physically tagged cache) and should be written down as an implementation requirement |
| Doorbell and MMIO ordering | **MITIGATED BY DESIGN** | strongly ordered device type, SC for normal memory, `FENCE` before the doorbell; no `wmb`/`mmiowb` zoo |
| Instruction cache after writing code | **SAME PROBLEM** | `ICINV` plus `ISYNC` (E39); cross-modifying code on another core has no rule yet (readiness 6.11) |
| IOMMU, bounce buffers | **UNKNOWN** | R6; without an I/O translation unit, a device that addresses only 32 bits forces bounce buffers (`swiotlb`-like) on a 40-bit physical machine |
| Posted-write errors | **WORSE for recovery** | only posted writes are imprecise; `FENCE` before a probe makes them precise (ISA 7.1); error reporting R7 |

## 8. Machine state: floating point, vectors, per-CPU data, context switch

**Evidence.** `core-api/floating-point.rst`: kernel code "is normally prohibited from using floating-point (FP) registers", a rule that "reduces system call overhead, because the kernel does not need to save and restore the userspace floating-point register state"; when a driver needs it, FP code is isolated in its own translation unit and bracketed, because "compilers sometimes use FP registers to optimize inlined memcpy" [G]. `arch/x86/xstate.rst`: the size of the save area differs by CPU, so "the size of signal stacks is dynamic, not static" and a compiled-in 2 KB "is too small for new CPU features" [G]. `lines-x86-fpu` 4,364 lines; `fpu-vector-state` vocabulary 2,977 Linux code lines (x86 1,155, MIPS 376, arm64 211, arm 203, LoongArch 203) and 1,039 to 1,330 in FreeBSD and NetBSD [P, counted]. `this_cpu_ops.rst`: per-CPU operations avoid "the lock prefix and the associated latency penalty"; 3,225 uses of `this_cpu_`/`per_cpu(`/`raw_cpu_` in `kernel`, `mm`, `arch` [P, counted].

**Workaround.** Lazy then eager save of FP state; extensible save-area enumeration; kernel-mode FP regions; per-CPU data through a segment or thread register, with a trick (`swapgs`, a reserved register, a scratch CSR) to get at it from the entry code.

**pdp64.** Floating point lives in the general registers (ISA 2.3); there is no separate state; the kernel's `DP` is the per-CPU pointer (ISA 17.4); a switch is about 9 instructions (survey 8, paper estimate); ASID makes the address-space part one store.

| Pain | Verdict | Why |
|---|---|---|
| Lazy/eager FPU save, `xsave` sizing, signal-frame growth, kernel-FP regions | **DESIGNED AWAY** | wins (a) and (b); the 4,364-line x86 FPU directory has no analogue. **Reversible by S1 to S4:** if a vector extension is added with its own registers, this whole family returns (S4 asks exactly this) |
| Per-CPU access cost | **DESIGNED AWAY** | `DP` in one instruction; no lock prefix, no segment base |
| Floating-point exceptions as traps | **DESIGNED AWAY** | flags only, never trap (ISA 4.10.1) |
| Register-window or large register file spill | **DESIGNED AWAY** | sixteen registers, no windows |
| Context-switch length | **MITIGATED BY DESIGN** | about 9 instructions against 13 to 86 (survey 8) |

## 9. User memory, faults and exception tables

**What it is.** A system call must read and write memory whose address a user chose. Checking every address first costs too much, so kernels access it and recover from the fault. Modern defences add a guard that forbids kernel access to user pages except inside the copy routine.

**Evidence.** `arch/x86/exception-tables.rst`: the old `verify_area` "used up a considerable amount of time" in "kernel profiling tests", so "Linus decided to let the virtual memory hardware" do the test, with a fixup table of instruction addresses [G]. `extable-uses-x86` 260 lines; `uaccess` vocabulary 3,213 Linux code lines in 825 files, FreeBSD 163, NetBSD 28, OpenBSD 19 [P, counted]. The guard instructions (x86 `stac`/`clac` 88 uses, AArch64 PAN, RISC-V `SUM`) are in survey 4.9 and 7.

**Workaround.** Fault-and-fixup tables; `access_ok` range check; SMAP/PAN/SUM guards toggled around copies; special user-access instructions (AArch64 `ldtr/sttr`, SPARC alternate-space loads, PDP-11 `mfpi/mtpi`); copy loops tuned (`rep movsb` features). **Hot sequence:** the copy itself, bracketed by two guard toggles and one table entry per faulting instruction.

**pdp64.** `UA` guard bit in the `PSW` with `stua`/`clua`, cleared on entry (E43, P2); `PROBER`/`PROBEW`; restartable `MCPY`-family copies whose progress is in registers (ISA 7.5); aborts that have "no architectural effect" (ISA 7.2); the old V7 `nofault` idiom (survey, system architecture 11).

| Pain | Verdict | Why |
|---|---|---|
| Kernel dereferences a user pointer by mistake | **MITIGATED BY DESIGN** | `UA` (E43); previously the open weak point D11 |
| Recovering from a fault in the middle of a copy | **MITIGATED BY DESIGN** | a block copy that faults reports how far it got in its registers, so the recovery code is "return the count"; wins (b). **Not yet defined:** how the fault handler finds the recovery address (an exception table like Linux's 260 lines, or the V7 `nofault` global, or a per-kernel `PROBER` pre-check): this is the one piece of recovery machinery the kernel will need and the documents do not say |
| String copy from user (`strncpy_from_user`) | **MITIGATED** | byte-scan instruction `mscn`, block copy; unmeasured |
| Cost of toggling the guard per copy | **SAME PROBLEM** | two instructions per copy (survey 7, item 2) |
| Fault count in a copy | **MITIGATED BY DESIGN** | a 1 MB `MCPY` can take 256 precise faults (ISA 7.5); no accumulation |
| Interrupt latency during a long copy | **MITIGATED** | interruptible at the implementation's block size (ISA 7.5); a latency bound must state it |

## 10. Interrupts, timers, time and idle

**Evidence.** `interrupts` vocabulary 4,787 Linux code lines (x86 2,077, drivers 883 in a drivers-poor sample) and 3,118 documentation lines; `timers-tick` 1,946; `idle-power` 1,168 code and 1,637 doc lines; `timekeeping` 1,903; `y2038-time` 485 [P, counted]. The kernel's per-architecture irq-chip drivers live in `drivers/irqchip` (in the sample). The developers' own text on locks and interrupts: disabling interrupts is "a single instruction on a x86, but it's an expensive one - and on other architectures it can be worse" (`locking/spinlocks.rst`) [G].

**Pains.** Interrupt latency (long critical sections, long block operations); interrupt storms and spurious interrupts; end-of-interrupt cost and controller programming (APIC, GIC); routing and balancing; message-signalled interrupts; the periodic tick versus tickless idle; timer data structures; idle-loop lost wake-ups; a reliable, cheap, monotonic clock readable from user space (the `vdso` and the `tsc`, `clocksource` family); the 2038 limit of 32-bit `time_t`.

**Hot sequences:** `sti; hlt` (the one-instruction shadow that closes the lost-wake race), `wfi`, `mwait`, the EOI write, `rdtsc`/`rdtscp`, `cntvct`/`rdtime`.

**pdp64.** Eight priority levels in the `PSW` (Q4, D5); priority 7 on entry (E40); timer with a 64-bit counter and compare; no interrupt controller defined (R1), no IPIs (R2); `WFE` idle (P1); an unprivileged time counter proposed (P3); LP64 so time is 64 bits natively.

| Pain | Verdict | Why |
|---|---|---|
| Interrupt-controller programming and EOI cost | **UNKNOWN** | R1; the PDP-11 model needs no EOI but also has no per-source masking in the processor |
| Interrupt latency, long critical sections | **MITIGATED BY DESIGN** | `SPL` is one instruction; `MCPY` is interruptible; the cost is the discipline of priority 7 until the save |
| Lost wake-up in the idle loop | **UNKNOWN (decision P1)** | the V7 source has the same loop (section 14); text needed |
| Spurious/storm handling | **SAME PROBLEM** | a device property, R7 |
| Cheap clock read from user mode | **UNKNOWN (P3)** | without `RDTIME`, `clock_gettime` is a system call |
| 2038 | **DESIGNED AWAY** | 64-bit time on a 64-bit machine; OpenBSD already uses 64-bit `time_t` on all ports (unverified here; check in Phase 2) [U] |
| Timer wheel versus high-resolution timers | **SAME PROBLEM** | a software structure; compare register 64 bits wide helps |
| Tick-less operation | **SAME PROBLEM** | compare register is programmable per event, so it is possible; policy is the kernel's |

## 11. Alignment, byte order, word size and compatibility

**Evidence.** `core-api/unaligned-memory-access.rst`: "Linux runs on a wide variety of architectures which have varying behaviour" and explains why code must not assume unaligned access works. `arch/arm/mem_alignment.rst`: the alignment trap fixes up misaligned accesses "at a high performance cost. It better be rare" and "Too many problems popped up because of unnoticed misaligned memory access in kernel code" [G]. `alignment` vocabulary 1,807 Linux code lines (mostly `include` 896 and `lib` 190: the `get_unaligned` helpers), 450 in OpenBSD [P, counted]. `endian` 1,793 Linux, 976 doc lines; `compat-32bit` 591 Linux, 448 NetBSD [P, counted].

**Workarounds.** Accessor helpers for packed network and disk structures; trap-and-fix-up handlers; endian conversion macros everywhere; a compatibility layer (system-call translation, structure conversion) for 32-bit programs on 64-bit kernels, each with its own security history.

**pdp64.** Natural alignment required, with explicit unaligned `MOVU*` forms (ISA 7.4, 4.13); little-endian only; LP64 only, no 32-bit mode; byte-swap instructions exist.

| Pain | Verdict | Why |
|---|---|---|
| Hardware unaligned handling and its trap path | **DESIGNED AWAY** | no rotator, no fix-up handler; wins (a), (b). The cost: legacy code with sloppy casts aborts. OpenBSD already runs on strict-alignment ports (the OpenBSD tree has alpha, sparc64, hppa, m88k, arm, riscv64 directories), so the code base tolerates it [P] |
| Packed-structure access | **MITIGATED** | `MOVU*` pair, same helper approach as Linux |
| Mixed endianness | **DESIGNED AWAY** | little only; the 976 lines of endian documentation have no analogue |
| 32-bit compatibility layer | **DESIGNED AWAY** | no 32-bit user mode: the `compat` vocabulary (591 Linux code lines) is not needed; costs: no old binaries. There are none |
| 32-bit to 64-bit transitions in the ABI | **MITIGATED** | LP64 from day one; `long double` decision E46 keeps an ABI-version door |

## 12. Patching running code, tracing and hardening

**Evidence.** `tracing-patching` vocabulary 2,867 Linux code lines in 608 files (`kernel` 1,093, `arch/x86` 468); `alt-instr-x86` 177 lines of `ALTERNATIVE` use; `static-key-uses` 725 [P, counted]. `trace/kprobes.rst`: a probe replaces an instruction with a breakpoint (`int3` on x86); the optimiser "calls stop_machine()" to replace it by a jump [G]. `riscv/cmodx.rst`: a function call is two instructions, "it is impossible to patch 2 instructions and expect that a concurrent read-side executes them without a race condition", so the code was changed to patch one atomically and "get rid of stop_machine()" [G]. `hardening` vocabulary 1,709 Linux code lines (KASLR, CFI, shadow stack, stack protector, KASAN, usercopy checks) [P, counted].

**Workaround.** A one-byte breakpoint written first, then the rest, then the first byte (x86 `int3` protocol); `stop_machine` on architectures that cannot do better; boot-time instruction patching to select the right sequence for the CPU found (`ALTERNATIVE`); static keys; W^X, KASLR, CFI, shadow stacks, pointer authentication, branch-target landing pads.

**pdp64.** `BPT` is two bytes, "the shortest instruction so it can overwrite any other" (system architecture 11); `ICINV`, `ISYNC`; separate `R`/`W`/`X` bits; kernel never executes user pages; landing pads (`jtag`, vector 14); PIE is cheap (ISA 19); no shadow stack or pointer authentication.

| Pain | Verdict | Why |
|---|---|---|
| Patching a multi-instruction sequence atomically | **MITIGATED BY DESIGN** | a two-byte parcel store is the unit; patch by planting `BPT` first (wins b); but a 4- or 6-byte call still needs the plant-patch-restore protocol |
| Patching while other cores execute | **UNKNOWN** | no cross-modifying-code rule (readiness 6.11, AWKWARD); `ICINV` then `ISYNC` on each core is the likely rule and costs an IPI-like step |
| Boot-time alternatives (`ALTERNATIVE`) | **DESIGNED AWAY** (mostly) | one ISA, few variants; P4 feature registers if variants appear |
| Forward-edge control-flow integrity | **DESIGNED AWAY** | landing pad check in the ISA (vector 14); the AArch64 BTI equivalent exists by design |
| Backward-edge (shadow stack, PAC) | **SAME PROBLEM** | not provided; ROP defences would be software or a later addition |
| KASLR entropy | **WORSE** | 39-bit address space |
| W^X | **MITIGATED BY DESIGN** | permission bits, kernel cannot execute `U` pages |
| Hardware breakpoints and watchpoints | **UNKNOWN** | open item (system architecture 11); the `T` bit single-steps |

## 13. Machine checks, errata as a phenomenon, virtualization, fast paths

**Machine checks and poison.** `machine-check-poison` vocabulary: Linux 1,366 code lines (`arch/x86` 515, `arch/powerpc` 264, `mm` 137), 602 doc lines; `lines-x86-mce` 7,111 lines; `mm/hwpoison.rst`, `memory_failure` [P, counted]. Linux invests a great deal in surviving an uncorrectable memory error by killing the one process that owns the page. **pdp64:** machine checks are not restartable and halt the machine (ISA 7.1, system architecture 11): principle (b) is satisfied in the narrow sense that there is no recovery code, and failed in the broad sense that one bad DRAM line takes the system down. Verdict **WORSE for availability, DESIGNED AWAY for code**; reporting beyond halt is an open item.

**Errata as a phenomenon.** Counted in section 2; the security-relevant ones are catalogued in [`hardware-vulnerabilities.md`](hardware-vulnerabilities.md). Further measures: `Documentation/arch/arm64/silicon-errata.rst` is a table of 176 rows; by its first column ARM 103, Qualcomm 9, Cavium 9, HiSilicon 7, NVIDIA 6, Microsoft 5, Ampere 5, Rockchip 2, NXP 2, Broadcom 2, one each for Renesas, Marvell, Fujitsu, Altera [P, counted with `awk` on the first column]. The preface of that file, by Will Deacon: "It is an unfortunate fact of life that hardware is often produced with so-called 'errata'" and classifies them A (no workaround), B (acceptable workaround) and C (minor) [G]. The `microcode` directory is 3,839 lines [P]. **pdp64:** no silicon, so no errata record; the readiness posture (precise restart, no hidden state, no mode bits) reduces the number of places to be wrong, and P4 (feature and identification registers) gives the kernel a way to learn which chip it is on. Verdict **UNKNOWN**, honestly: the first FPGA will produce the first list.

**Virtualization.** `virtualization` vocabulary: Linux 14,741 code lines in 713 files (`arch/*/kvm` and `virt` are in the sample), 2,024 doc lines; the L1 flush on VM entry and nested paging are the costs named in `l1tf.rst`. **pdp64:** none planned (R8); supervisor mode is unused. Verdict **UNKNOWN**; note that a nested page table doubles the walk length (up to 15 memory fetches with three levels each, derived arithmetically, not measured) and that the existing Sv39 shape was chosen partly to keep this small.

**Storage and network fast paths.** `net-storage-fastpath` vocabulary 1,462 code lines (batching, polling, zero copy, XDP, `io_uring`), 881 doc lines. The recurring techniques are batching, polling instead of interrupts, descriptor rings with producer and consumer indices, and avoiding copies. **pdp64:** devices are eight registers plus DMA descriptors (Q10, R5); the memory model is SC so a ring needs no barriers; the block instructions are the copy; no hardware offload is assumed. Verdict **MITIGATED BY DESIGN** for the ring ordering, **UNKNOWN** for the descriptor layout.

**Power management.** `idle-power` 1,168 code lines; `cpuidle`, `mwait`, `wfi`, frequency scaling. **pdp64:** `WFE` only; no idle states, no frequency control; deep power management is outside the processor (R-series) and unspecified. Verdict **UNKNOWN**.

## 14. The PDP-11 and VAX era, from the old sources

These are first-hand, from `~/claude/facetlang/unixtree`, and show that several pains are old ones that pdp64 was built to avoid. All **[P, primary source]**.

| Source | What it shows | Pain | pdp64 |
|---|---|---|---|
| `V7/usr/sys/sys/trap.c` comment | "This relies on the ability of the hardware to restart a half executed instruction. On the 11/40 this is not the case and the routine backup/l40.s may fail", the example being a double pre-decrement compare | Instructions that cannot be restarted after a fault | **DESIGNED AWAY** (ISA 7.2, 7.3: aborts have no architectural effect; at most one register side effect) |
| `V7/usr/sys/40/m40.s` `backup` | a routine labelled "hard part", "simulate the ssr2 register missing on 11/40", which decodes the faulting instruction to undo its side effects | Software undo of a half-executed instruction | **DESIGNED AWAY**: the largest block of recovery code in V7's machine-dependent file has no counterpart |
| `V7/usr/sys/40/m40.s` `nofault` | a global that routes an expected bus error back to the caller | The only recovery mechanism for probing hardware and user memory | Kept as the pattern (system architecture 11); an exception table is the alternative |
| `V7/usr/sys/40/m40.s` `idle` | the idle routine lowers the priority and executes `wait` | Whether an interrupt can arrive between the priority drop and `wait` | P1 |
| `V7/usr/sys/sys/slp.c` | `spl6()` ... `splx(s)` around every queue manipulation | The interrupt-priority discipline: every shared structure touched at interrupt level is bracketed | **SAME PROBLEM**, same tools (Q4); Linux's `spinlocks.rst` records the cost of the modern descendant |
| `3BSD/usr/src/sys/sys/vmpage.c` | page daemon "simulating the missing hardware reference bit" | Software accessed bit on the VAX | **SAME PROBLEM** by choice (Q2): the first paging Unix did what System v1 does |
| `3BSD/usr/src/sys/sys/uba.c` | allocating "contiguous UBA mapping registers", buffered data path flag | DMA through a mapping unit with purge rules | R6 |
| `3BSD/usr/src/sys/h/pte.h` | the page-table entry carries a hardware modify bit, a software "swap modified" bit and fill-on-demand state | Where software state hides in the entry | pdp64's entry has no software bits (all other bits must be zero, or a page fault); the kernel keeps its own state elsewhere |

## 14A. What the developers say: list posts and articles read so far

**Phase 2 is under way, not finished.** Evidence labels: **[D] developer statement** (a post on a mailing list, a cover letter or a commit message, read in full from the archive page; this is primary evidence of pain), **[S] secondary** (an LWN article, read from a saved copy before lwn.net blocked further requests), **listing** (a lore.kernel.org search-result page: subjects, authors and dates without bodies). Quoted phrases are short; the costs are the developers', not mine. Each row's URL is in Appendix C.

| Pain | What was said | Who, when | Source | Label | Chapter and pdp64 |
|---|---|---|---|---|---|
| Cost of separating kernel and user page tables | KAISER "makes syscalls and interrupts slower"; the CR3 writes alone "add a few hundred cycles to a syscall or interrupt"; "5% is a good round number for what is typical"; worst case "roughly 30%" on a loopback networking test; PCIDs make syscalls "roughly 2x faster than without it"; the author disputes the paper's "0.28%" overhead figure | Dave Hansen (Intel), KAISER cover letter v1, 31 Oct 2017 | lore `20171031223146.6B47C861@viggo.jf.intel.com` | [D] | ch. 4: pdp64's single base would owe this tax on a speculating core |
| The same, as the article saw it | the kernel stays mapped to avoid TLB flushes at each crossing; the 2003 "4G/4G" scheme cost too much; estimates "about 5%" (Dec 2017), "30% or more" for some workloads (Jan 2018) | LWN, 15 Nov 2017, 20 Dec 2017, 15 Jan 2018 | LWN 738975, 741878, 744287 | [S] | ch. 4 |
| TLB tags: what they buy | PCID "saves around 100ns on cross-process context switches", "a little over a 10% speedup" because "we suck at context switches in general"; "most of the time is spent in the scheduler, not in arch code"; INVPCID "seems slower than just manipulating CR3 carefully" | Andy Lutomirski, RFC cover letter, 8 Jan 2016 | lore `cover.1452294700.git.luto@kernel.org` | [D] | ch. 5: ASIDs help, but the switch is dominated by software |
| PCID hardware is not what it looks like | the hardware PCID is hashed: "doesn't actually have as many bits in the pcid as there are in cr3" | Linus Torvalds, same thread, 8 Jan 2016 | lore `CA+55aFxmc83...` | [D] | ch. 5: pdp64's 16-bit ASID must be real or documented as hashed |
| Speculation across privilege domains | "A *competent* CPU engineer would fix this by making sure speculation doesn't happen across protection domains"; mitigations must be switchable for CPUs that do not need them | Linus Torvalds, 3 Jan 2018 | lore `CA+55aFzCocoK...` (thread "Avoid speculative indirect calls in kernel") | [D] | ch. 4: pdp64 does not speculate; if a core ever does, this is the requirement |
| NetBSD's answer | "Separate Virtual Space": unmaps most of the kernel in user mode; a boot option, a plan to enable it only on Intel, a run-time sysctl to turn it off; the author could not confirm the mitigation because two Meltdown proofs of concept did not run on his CPU | Maxime Villard, tech-kern, 21 Jan 2018 | mail-index.netbsd.org `tech-kern/2018/01/21/msg023000.html` | [D] | ch. 4 |
| Speculation is worse where protection is weak | "the spectre variant 2 situation is a lot worse for: speculative CPU, weak memory protection"; no NX bit on default i386 NetBSD and MIPS's unmapped kernel segment are named; Loongson's kernel entry runs a short chain of calls to clear the branch-target buffer | maya, tech-kern, 19 Jan 2018 | `tech-kern/2018/01/19/msg022992.html`, `msg022993.html` | [D] | ch. 4: pdp64 has execute permission and the kernel may not execute user pages |
| Microcode changes the instruction set under the kernel | microcode "can remove and add instructions and other features", so it must be loaded before the CPUs are identified | Patrick Wildt, openbsd-tech, 31 Jan 2018 | marc.info `m=151743333628424` | [D] | ch. 13: feature registers (P4) must be read after any update |
| Lazy FPU state | "The result is rather messy": two code paths, only one tested often; setting the task-switched bit is "far slower" than saving and restoring the full state, because stores to `CR0.TS` serialize | Andy Lutomirski, commit 58122bf1d856 (seen in the 4.4 backport of 14 Jun 2018, original 2016) | lore `20180614132724.737334115@linuxfoundation.org` | [D] | ch. 8: no FPU state in pdp64 (S4 would reopen it) |
| The Alpha ordering story | after the barrier had been folded into `READ_ONCE()`, `smp_read_barrier_depends()` still "limps on" with "the sinister hope of attracting innocent new users"; the 2019 series removes it from documentation, comments and the memory model, and the 2020 series (v3, 19 patches, "Allow architectures to override __READ_ONCE()") makes Alpha's `READ_ONCE()` carry the barrier | Will Deacon, 8 Nov 2019 and 10 Jul 2020 | lore `20191108170120.22331-1-will@kernel.org`, `20200710165203.31284-1-will@kernel.org` | [D] | ch. 6: 25 years after the DEC meeting, one architecture's weakness still costs patches |
| Ticket locks do not scale | OpenBSD's big kernel lock is a ticket lock, which "don't scale as there is a centralized place getting constantly read", plus false sharing of the per-CPU state (8 CPUs per cache line); an Anderson-style lock gave +155% (2.3 to 5.9 million operations per second) on an `fstat` loop | Mateusz Guzik, openbsd-tech, 21 Dec 2025 | marc.info `m=176631121132731` | [D] | ch. 6: pdp64's lock choice is open (R3); the cost is real even on a small count of cores |
| Spinlock design in the Linux case | MCS locks move waiters to private cache lines; `qspinlock` adds a pending bit; benchmark results "regressed a little" on some loads, gained 1 to 2% on others | Tim Chen, Waiman Long, Peter Zijlstra via LWN, 11 Mar 2014 | LWN 590243 (the Mar 2014 patch threads are listed, not read) | [S] | ch. 6 |
| Hardware accessed/dirty updating arrived with trouble | on an early platform "the only way to get a usable userspace is disabling CONFIG_ARM64_HW_AFDBM" | Julien Grall (report), Will Deacon (reply), 10 Sep 2015 | lore `20150910153812.GG22439@arm.com` | [D] | ch. 5: supports Q2 on recoverability: software management cannot be broken by the chip |
| The same ambiguity on RISC-V | when neither `Svade` nor `Svadu` is advertised, assuming Svade "is harmless on real Svadu hardware, while assuming Svadu on real Svade hardware risks an unhandled page fault"; both present: Svade wins | Xen/RISC-V review, 23 Sep 2026 | lore `1425dafc-9737-4776-aa65-5b0e5635e9f5@gmail.com` | [D] | ch. 5: software A/D is the safe default; a hardware option needs a feature register (P4) |
| LL/SC livelock was a real erratum | the ARC kernel panics at boot on an SMP configuration with atomics but without the "llock/scond livelock workaround" for a named silicon erratum (STAR 9000923308) | Vineet Gupta, commit 4d0cb15fccd1 (4.4 backport, 25 Jul 2016) | lore `20160725203523.360826166@linuxfoundation.org` | [D] | ch. 6: E45's forward-progress rule must be backed by the monitor design |
| 2038 is a long clean-up | 23 patches "cleanups for the y2038 work": the old `time_t`, `timeval`, `timespec` types "often lead to y2038-unsafe code" even after conversion | Arnd Bergmann, 8 Nov 2019 | lore `20191108210236.1296047-1-arnd@arndb.de` | [D] | ch. 10: 64-bit time from the start |
| Page-table isolation, as committed | FreeBSD "PTI for amd64" (first version, a "workaround" for Meltdown), 17 Jan 2018; NetBSD "unmap the kernel from userland in SVS", 21 Jan 2018; OpenBSD "Meltdown: implement user/kernel page table separation", 21 Feb 2018: three kernels, one month apart, the same mechanism | commits `bd50262f705c` (FreeBSD), `03db57fb7f3c` (NetBSD), `b767b017801a` (OpenBSD) | commit message | [D] | ch. 4: found by `git log`, Appendix B.7 |
| Remote TLB flushes keep needing rework | arm64 batched and deferred shootdown (2023): "On x86, batched and deferred tlb shootdown has lead to 90% performance increase"; NetBSD "Fix an IPI deadlock scenario that resulted in a TLB shootdown timeout" (2021); OpenBSD "rework how tlb shootdown information is sent between cpus", avoiding a mutex (Dec 2025) | commits `43b3dfdd0455` (Linux, 17 Jul 2023), `11f804663155` (NetBSD, 3 Apr 2021), `3ee248caefed` (OpenBSD, 4 Dec 2025) | commit message | [D] | ch. 5: broadcast `TLBI` removes this class; the 90% figure is the developers' |
| A missing barrier is found years later | KVM on PowerPC needed `smp_mb()` around a host IPI flag, found on a 2-socket Power9 with 128 hardware threads | commit `3a83f677a6ee`, 11 Sep 2019 | commit message | [D] | ch. 6: an SC machine cannot have this bug |
| Address-space tags and nested paging | a KVM fix: Windows guests saw memory corruption (and blue screens) until a flush by guest virtual address became a full ASID flush when nested paging is on (Red Hat reports) | commit `26505e1b5b54`, 23 Jul 2026 | commit message | [D] | ch. 5, 13: TLB invalidation semantics are still producing bugs in 2026 |
| System-call return can fault in the kernel | "SYSRET to a noncanonical address will blow up on Intel CPUs"; Linux "needs to prevent this" (selftest, Dec 2016) | commit `660602140103`, 26 Dec 2016 | commit message | [D] | ch. 3: in pdp64 `RTI` loads `EPC` and the non-canonical check is an ordinary abort, but where that abort is taken and on which stack is not stated (UNKNOWN) |
| A vendor chicken bit | FreeBSD "AMD Zen2: Zenbleed chicken bit mitigation", applied only to bare-metal Zen2 | commit `ebaea1bcd2eb`, 11 Sep 2023 | commit message | [D] | ch. 4, 13: mitigations that turn off a hardware feature through an undocumented bit |
| TLB shootdown by interrupt does not scale | on a 48-CPU, 4-node machine the vanilla kernel "was interrupted roughly 900K times per second" by flush IPIs against 180K with one IPI per CPU and a full flush; readers ran 24.4% faster with 29% less system CPU time; the architecture must guarantee that a write through a stale clean entry faults | Mel Gorman (SUSE), `[PATCH 2/4] mm: Send one IPI per CPU to TLB flush all entries after unmapping pages`, 6 Jul 2015 (measured by the author on vm-scalability) | lore `1436189996-7220-3-git-send-email-mgorman@suse.de` | [D] | ch. 5: broadcast `TLBI` with `TLBSYNC` removes the IPI; pdp64 must keep the clean-page write-fault guarantee, which software-managed D bits give |
| A software user-access guard is a big patch | emulating PAN on cores without it by switching `TTBR0_EL1` took 26 files, 437 insertions and 98 deletions, including every copy routine and the entry code | Catalin Marinas, `[PATCH v4 0/8] arm64: Privileged Access Never using TTBR0_EL1 switching`, 28 Oct 2016 | lore `1477675636-3957-1-git-send-email-catalin.marinas@arm.com` | [D] | ch. 9: pdp64's `UA` bit (errata 43) needs none of this |
| Cache maintenance for non-coherent DMA arrived late on RISC-V | the Zicbom instructions were ratified in Nov 2021; the kernel patch of Jul 2022 adds 208 lines in 11 files and an alternative-patching mechanism "with empty instructions", and "assume the platform being coherent by default so that non-coherent devices need to get marked accordingly by firmware" | Heiko Stuebner, 6-7 Jul 2022 | lore `20220706231536.2041855-4-heiko@sntech.de` | [D] | ch. 7: supports reserving data-cache maintenance (P6) and coherent-by-default |
| Memory initialisation as a security feature | `init_on_alloc` and `init_on_free`: the allocators zero memory "aimed at preventing possible information leaks"; no opt-out for heap users because "there's not enough evidence that doing so can speed up real-life cases" | Alexander Potapenko (Google), 28 Jun 2019 | lore `20190628093131.199499-1-glider@google.com` | [D] | ch. 12; pdp64 `MSET` is one instruction (openbsd-mitigations 2.11) |
| Vector state grows with each extension | the AMX guest series (Dec 2021) adds permission checks, a `uabi_size` and dynamically enabled FPU features to the save-area code | Thomas Gleixner, 14 Dec 2021 | lore `877dc7tj30.ffs@tglx` | [D] | ch. 8: pdp64's no-state design would be reopened by S1-S4 |
| SMT is "fundamentally broken" | "shares resources between the two cpu instances and those shared resources lack security differentiators"; Intel "doing a terrible job by not publically documenting what operating systems must do"; OpenBSD will not use hyperthreading, and will not backport errata for 6.2 and 6.3 because it is "taking too much manpower" | Theo de Raadt, 23 Aug 2018 | marc.info `m=153504937925732` | [D] | `hardware-vulnerabilities.md` C6, C13 |
| How OpenBSD's mitigations compose | pinsyscalls, retguard, ASLR, relinking: with retguard "you can only return into the stack of functions. You cannot jump into the middle" | Theo de Raadt, 29 Oct 2025 | marc.info `m=176175324400465` | [D] | `openbsd-mitigations.md` 2.6, 2.9 |
| Data in the code segment defeats the mitigations | OpenSSL assembly places tables containing the byte `0xC3` (a `ret`) in text: "Nearly 20 years behind the time"; Theo regards the alibi "it was a cache optimisation" as obsolete on any processor "less than 10 years old" | Theo de Raadt, 30 Jan 2023 | marc.info `m=167511454301227` | [D] | pdp64: no data in text (xonly pool rule) |
| Mitigation exceptions are per CPU model | a user asks why OpenBSD applies Meltdown mitigation on an in-order Atom; Philip Guenther points to the dmesg `cpu0:` family and model lines: the exceptions are a table in `replacemeltdown()` | Philip Guenther, 19 Jul 2025 | marc.info `m=175289708829074` | [D] | C13: feature bits instead of models |
| The user-access guard needed new instructions | "To make the performance of manipulating that flag acceptable, there are two new instructions, STAC and CLAC"; the series touches the syscall entry, `copy_user`, `getuser`, `putuser`, `futex`, `xsave` and others, and adds the AC flag to the syscall entry mask | H. Peter Anvin (Intel), `x86, smap` series 8/11 and 9/11, 21 Sep 2012 | lore `1348256595-29119-9-git-send-email-hpa@linux.intel.com` | [D] | ch. 9: `stua`/`clua` cost two instructions per copy, the same trade |
| Fair spinlocks were argued over for months | Nick Piggin's `x86: FIFO ticket spinlocks` (1 Nov 2007) drew a 29-message thread with Linus Torvalds, Ingo Molnar, Rik van Riel and others about lock unfairness on multi-socket machines; the later lockless queue lock followed in 2014 (LWN 590243 above) | listing and one reply read | lore `20071101140146.GA26879@wotan.suse.de`, Torvalds reply `alpine.LFD.0.999.0711020950250...` | listing | ch. 6 |
| Alpha still handled in RCU in 2008 | an RFC to skip `smp_read_barrier_depends()` in `rcu_dereference` when the pointer is NULL, answered by Paul McKenney and Peter Zijlstra (21 Jun 2008) | listing only | lore `485CCFB9.9050208@cn.fujitsu.com` | listing | ch. 6 |
| Barrier documentation lingers | QEMU, perfbook, virtio tools patches in 2022 to 2023 still handling `smp_read_barrier_depends()` | listing only | lore search | listing | ch. 6 |
| The user-access guard is still being tuned | `x86/smap` helper rewrites (Poimboeuf, 14 Mar 2025, with Andrew Cooper) and a "Fix the smap_save() asm" thread (Sep 2020) | listing only | lore search `x86, smap` | listing | ch. 9 |
| Eager FPU in Xen | "x86: Always use eager-fpu" (Mar 2026) | listing only | lore search | listing | ch. 8 |

**Not reached** (Appendix C): the BSD archives beyond the three NetBSD, OpenBSD and failed FreeBSD pages above (lists.freebsd.org answered 404 for an old-style URL and 503 once; marc.info's body search returned only month listings); LWN beyond the pages above (blocked); the papers; the lists before 2001 (none of the archives visited go back that far for these topics).

## 14B. Round 2: developer statements by area

Round 2 read about 200 further pages from lore.kernel.org, marc.info, mail-index.netbsd.org and reference sites with a sequential fetcher (one request at a time, 12 to 45 seconds apart; it stops on any block page). **Honest count:** many hits are successive versions of one patch series (v21, v22, v23 of the same vDSO patch; v3, v4, v5 of the same cover letter), so the number of *distinct threads or documents* is smaller than the number of pages; the index with every URL, its query, its date and its author is `docs/codegen-data/kernelpain/round2-index.tsv`, and the counts per area are in section 14C. The table lists the statements that carry a cost, a decision or an admission of difficulty; routine patch mail is in the index only. Labels: **[D]** developer statement (URL in the index and Appendix C), **[S]** secondary.

### Entering the kernel, speculation mitigations and their costs

| Pain | What was said | Who, when | Source (lore message-id unless noted) | Label | pdp64 |
|---|---|---|---|---|---|
| The fast system-call path stopped paying | "The SYSCALL64 fast path was a nice, if small, optimization back in the good old days when syscalls were actually reasonably fast. Now we have PTI to slow everything down, and indirect branches are verboten ... Just get rid of the fast path. The slow path is barely slower." | Andy Lutomirski, patch quoted in Ingo Molnar's review, 28 Jan 2018 | `[kernel-hardening] Re: [PATCH 1/3] x86/entry/64: Remove the SYSCALL64 fast path` | [D] | ch. 3: pdp64 has no fast path past the vector fetch (D3); the x86 history says that is the right call once entry has defences |
| Mitigation code must not itself speculate | "we must not speculate across the IBRS/IBPB MSR writes otherwise that would totally defeat the point"; an LFENCE in the else-clause "makes the primitives unconditionally expensive"; the series adds objtool checks for retpoline and for `static_cpu_has` | Peter Zijlstra, `[PATCH 00/35] jump_label, objtool, IBRS and IBPB`, 18 Jan 2018 | `...` (index doc0007) | [D] | ch. 4: mitigation code size includes the tools that verify it |
| Firmware is outside the retpoline | "Retpoline means the kernel is safe because it has no indirect branches. But firmware isn't, so use IBRS for firmware calls"; the author refuses to touch `hpwdt.c`, which "is taking spinlocks and calling into firmware code, from an NMI handler" | David Woodhouse, `[PATCH v2 1/4] x86/speculation: Use IBRS if available before calling into firmware`, 14 Feb 2018 | doc0019 | [D] | ch. 13 boot: firmware calls need a rule (P7) |
| Spectre v1 cannot be found by looking; masking beats fences | rule from Linus Torvalds quoted in the series: "find all 'stac' users, and use address masking if those users already integrate the limit check, and lfence they don't"; `get_user` converted to masking, `__get_user` still fences | Dan Williams, `[PATCH v4 00/10] prevent bounds-check bypass via speculative execution`, 18 Jan 2018 | doc0022 | [D] | ch. 4, hardware-vulnerabilities C4 |
| Per-task controls cost an ABI | `PR_SPEC_INDIRECT_BRANCH` per-task STIBP/IBPB via `prctl`; the series "Remedy the STIBP/IBPB overhead" removes the ptrace check in the always-IBPB case: "substantial overhead for dubious value now that the default is conditional" | Thomas Gleixner, V2 00/28, 25 Nov 2018 | doc0008, doc0009 | [D] | ch. 4 |
| The 2018 decision against IBRS | "Back in the good old spectre v2 days (2018) we decided to not use IBRS. In hindsight this might have been the wrong decision because it did not force people to come up with alternative approaches"; "As IBRS is a performance horror show ... We both unsurprisingly hate the result with a passion"; the call depth tracking costs "about 1.8MB call thunk memory and 2MB btree memory" on a server, a 16-byte thunk per function, and "a massive ITLB miss rate" before 2 MB mapping | Thomas Gleixner, `[patch 00/38] x86/retbleed: Call depth tracking mitigation`, 17 Jul 2022 | doc0027; FIO numbers by Tim Chen, doc0028 | [D] | ch. 4: a 38-patch software substitute for a return predictor; pdp64's rule C2 |
| The cost of fixing returns | "The main point of this series is patch 4 to remove one taken branch from every function return" | Andrew Cooper, `[PATCH 0/4] x86/srso: Reduce overhead of the mitigation`, 21 Aug 2023 | doc0032 | [D] | ch. 4: every `ret` on AMD Zen 1-4 pays for SRSO |
| Reporting "mitigated" while vulnerable | "The SRSO default safe-ret mitigation is reported as 'mitigated' even if microcode hasn't been updated. That's wrong" (23-patch fix series) | Josh Poimboeuf, 25 Aug 2023 | doc0030, doc0031 | [D] | hardware-vulnerabilities C13: the chip should say what it is |
| Arm needed the same fixes in 32-bit | "A couple of bug fixes and tweaks for the ARM version of the Spectre BHB mitigations": enable for Cortex-A15, fix a loop sequence for Thumb2, local DSB | Ard Biesheuvel, 28 Mar 2022 | doc0035 | [D] | ch. 4 |
| Too many knobs | "While many users may not be intimately familiar with the details of these CPU vulnerabilities ... unneeded mitigations may be disabled, allowing users to recoup more performance"; command line `mitigations=auto;no_user_kernel,...` | David Kaplan (AMD), `[PATCH v6 00/21] Attack vector controls (part 2)`, 7 Jul 2025 | doc0040 | [D] | ch. 4: 24 `MITIGATION_` options and 177 parameter lines counted in section 2 are the cost |
| L1 terminal fault: what it cost | "The fix is easy, and the performance cost is almost zero" (inverting the bits of a not-present page-table entry); the L1 cache flush on every guest entry "could approach a 50% performance hit" where entries are common; disabling SMT is, "in a virtual sense", removing half the processors; the mitigations "were worked out under strict embargo" | LWN, `Meltdown strikes back: the L1 terminal fault vulnerability`, 14 Aug 2018, read through an archived copy | LWN article 762570 (copy in `browse-output`, 38,244 characters) | [S] | hardware-vulnerabilities L1TF row; ch. 4 |
| Hypervisor-side advisories | Xen Security Advisories 263 (speculative store bypass, May 2018), 435 (gather data sampling, Aug 2023), 456 (native branch history injection, Apr 2024) | Xen security team | doc0020, doc0033, doc0034 | [D] | hardware-vulnerabilities |

### Locks, atomics, RCU, compilers

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Fair queue locks took nine versions | queue read/write lock: "Remove support for unfair lock, so only fair qrwlock will be provided" (v6 to v7); v9 on 14 Jan 2014 uses `smp_load_acquire`/`smp_store_release` and `atomic_t` | Waiman Long, `qrwlock: Introducing a queue read/write lock implementation` v7-v9, Nov 2013 to Jan 2014 | doc0057-0059 | [D] | ch. 6 |
| Expedited RCU is a trade | "highly experimental patches ... It is not clear whether this is a useful tradeoff"; asked to remove expedited grace periods entirely: "The fast-boot guys are probably going to complain, along with the networking guys" | Paul McKenney, 30 Jun and 2 Jul 2015 | doc0042, doc0043 | [D] | ch. 6 |
| Grace-period cost is felt in ordinary programs | "wireshark startup runs through a great many grace periods ... those 3-jiffy time periods add up" | Paul McKenney, 6 Sep 2012 | doc0045 | [D] | ch. 6 |
| A barrier optimisation reverted for failing tests | revert of "Decrease memory-barrier usage based on semi-formal proof": "there are rcutorture test failures with the revert" | Paul McKenney, 25 May 2011 | doc0047 | [D] | ch. 6: even proved barrier removals need torture tests |
| The compiler broke the ordering primitive | "ACCESS_ONCE does not work reliably on non-scalar types. For example gcc 4.6 and 4.7 might remove the volatile tag for such accesses during the SRA (scalar replacement of aggregates) step" | Christian Borntraeger (IBM), `kernel: Provide READ_ONCE and ASSIGN_ONCE`, 3 and 11 Dec 2014, pull request 18 Dec | doc0051-0053 | [D] | ch. 6: a compiler can undo ordering that hardware gives |
| A low-power wait on a reservation | RISC-V `Zawrs`: `wrs.nto`/`wrs.sto` "allow the hart to enter a low-power state while waiting on a store to a memory location"; used for spinlocks and for an idle thread | Andrew Jones, 26 Apr 2024; Xu Lu, Jun and Sep 2024 | doc0054-0056 | [D] | pdp64's `WFE`/`SEV` (P1) |

### Memory management and TLB

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Nobody could explain the TLB flush heuristic | "I know we've come full-circle here back to a tunable, but this new one is *WAY* simpler. I challenge anyone to describe in one sentence how the old one worked" | Dave Hansen, `x86: mm: new tunable for single vs full TLB flush`, Apr to Jul 2014 | doc0060-0062 | [D] | ch. 5: the 33-page ceiling |
| Generic range tracking was needed to share TLB code | "In order to convert various architectures to generic tlb we need to provide some extra infrastructure to track the range of the flushed page tables" (ia64, arm, sh) | Peter Zijlstra, `mm: Provide generic range tracking and flushing`, Mar 2011 and Jun 2012 | doc0069-0071 | [D] | ch. 5 |
| Hardware range flush arrived late | `TLBI RANGE` for Arm v8.4 merged into arm64 on 15 Jul 2020 (three patches, by Zhenyu Ye of Huawei); RISC-V `svinval` used in place of `sfence.vma` by `local_flush_tlb_page*`, v5 on 23 Jun 2023 | Catalin Marinas; Mayuresh Chitale | doc0063-0067 | [D] | ch. 5: P5 (by-ASID / range) |
| Automatic NUMA balancing grew to 63 patches | "Weighing in at 63 patches makes the term 'basic' in the series title a misnomer"; the series "reduces overhead of automatic balancing through scan rate reduction and the avoidance of TLB flushes" | Mel Gorman, V7 (50 patches) to V9 (63), Sep to Oct 2013 | doc0075-0077 | [D] | ch. 5: no NUMA in pdp64 |
| The mmap lock is a measurable fraction of cycles | `mmap_read_lock` + `unlock` "is about 0.5% of cycles" in a TCP zero-copy receive; per-VMA locks bring it to "< 0.1%"; applications with ~100 threads launch "up to 20%" faster; "~75% of SPF benefits" with less complexity; the series reached v4 with 33 patches after an RFC in Sep 2022 | Suren Baghdasaryan (Google), 27 Feb 2023 | doc0078-0080 | [D] | ch. 5 |
| Transparent huge pages entangle other subsystems | memcg accounting broke when a huge page was split ("pc->mem_cgroup and pc->flags of tail pages are not set"); KVM needed its own THP support | Daisuke Nishimura, Jun 2010; Andrea Arcangeli, Jul and Dec 2010 | doc0072-0074 | [D] | ch. 5 |

### DMA, caches, devices, time, interrupts, machine checks, hardening

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Cache maintenance for only some devices | "All the cache maintenance is already stubbed out when not enabled, but merging the two allows us to nicely handle the case where cache maintenance is required for some devices, but not others" | Christoph Hellwig, `dma-mapping: merge direct and noncoherent ops`, Sep 2018 (a patch touching `arch/arc`, `arm`, `c6x`, `mips` ...) | doc0082, doc0083 | [D] | ch. 7: R5/R6 |
| 32-bit compatibility inflates a vDSO | the 32-bit vDSO time patch "Due the nature of the kernel headers and the LP64 compiler where the size of a long and a pointer differs against a 32 bit compiler, there is some type hacking necessary for optimal performance"; the series went through 23 versions | Stefani Seibold, v21-v23, Mar 2014 | doc0127-0129 | [D] | ch. 11: pdp64 has no 32-bit mode |
| Dynamic ticks must not slow the off case | "priority is given to optimize the full dynticks off-case in order to let distros enable this feature without suffering from significant performance regressions" | Frederic Weisbecker, Jul 2013 | doc0097 | [D] | ch. 10 |
| The timer wheel was reworked four times in a month | `timer: Refactor the timer wheel` V1 13 Jun, V2 17 Jun, V3 24 Jun, V4 4 Jul 2016; 22 patches, touching `block/genhd.c`, `drivers/usb/host/xhci.c`, `mce.c` and others | Thomas Gleixner | doc0099-0101 | [D] | ch. 10 |
| Spurious interrupts are device quirks | "sdio: add quirk for spurious SDIO IRQ"; the kernel has a whole facility for lost and spurious IRQs, documented in a 74-line comment added in 2010 | Chris Ball, Nicolas Pitre, 1 Jun 2011; Tejun Heo, 13 Jun 2010 | doc0102-0104 | [D] | ch. 10: R7 (device error reporting) |
| Recovery from memory errors depends on the model | "Each Xeon includes a number of capability registers in PCI space that describe some features not enumerated by CPUID. Use these to determine that we are running on a model that can recover from machine checks"; the quirk then broke parallel builds | Tony Luck, 30 Aug 2016; Prarit Bhargava, 21 Nov 2016 | doc0111, doc0112 | [D] | hardware-vulnerabilities C13, P4 |
| Indirect-call checking is a whole-tree change | Clang CFI for x86-64: "the compiler injects a runtime check before each indirect function call"; the remaining patches "change function declarations to use opaque types, fix type mismatch issues ... and disable CFI where it can't be used"; v5 of 15 patches in Oct 2021 | Sami Tolvanen (Google) | doc0114-0116 | [D] | openbsd-mitigations 2.10 |
| Arm BTI took ten versions | `Branch Target Identification` support: v8 27 Feb 2020, v9 11 Mar, v10 16 Mar 2020 (13 patches) | Mark Brown | doc0117-0119 | [D] | openbsd-mitigations 2.10 |
| A full stack protector cost too much for a distribution | "We've noticed in Fedora that this has introduced noticable overhead on some functions, including those which don't even have any on-stack variables ... The overhead as it stands right now means this whole option is unusable for a distro kernel without reverting the above commit" | Dave Jones (Red Hat), 15 Oct 2009 | doc0120 | [D] | openbsd-mitigations 2.9 |
| Stack protector and per-CPU data share a register | on 32-bit x86, `%fs` is the per-CPU base, `%gs` unused by the kernel but used by user TLS: the canary needed a segment | Tejun Heo, 9 Feb 2009 | doc0121 | [D] | ch. 8: pdp64's banked `DP` removes the conflict |
| KASLR broke other features | "Bugs have been reported around kdump, kexec, and some netboot situations that didn't work when KASLR was enabled" (a 21-patch cleanup) | Kees Cook, 14 Apr 2016 | doc0123 | [D] | openbsd-mitigations 2.2 |
| SMAP is not free | "it seems that x86 SMAP has some performance problems too" | Kees Cook, 5 Apr 2016 (MIPS KASLR thread) | doc0125 | [D] | ch. 9: `stua`/`clua` cost |
| y2038 is still being converted | "y2038: IPC system call conversion", v4 16 patches, 25 Apr 2018 | Arnd Bergmann | doc0126 | [D] | ch. 10 |

### OpenBSD lists (marc.info), Round 2

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| A mitigation had a publication race | "Even if that's considered fine, there is a transition period where the table is just being installed. The code needs correct memory fences on both sides to make sure this works as expected" (the `pinsyscalls(2)` table); Kettenis agrees there is "a potential race between threads" if a custom `ld.so` creates threads first | Mateusz Guzik, Mark Kettenis, Theo de Raadt, 23 Feb to 2 Mar 2025 | marc.info `m=...` (index doc0160) | [D] | the class of bug an SC machine does not have |
| Zero pages when you use them | "pre-zeroing pages is probably a waste of time. At least on modern CPUs ... if we zero the page when we allocate it, the data is very likely still in the cache when we touch it"; Pieuchot proposes `rep stosb` for page zeroing "to greatly reduce the amount of CPU cycles spent zeroing pages" | Mark Kettenis, Martin Pieuchot, Claudio Jeker, 22 Dec 2025 | index doc0154-0159 | [D] | openbsd-mitigations: `MSET` at allocation is the right form; a page-zeroing engine is not |
| Random relinking wants many object files | "Random relinking is better if a program has more .o files. Which would argue for splitting code up into more .c files" | Theo de Raadt, 5 and 7 Jun 2026 | index doc0166, doc0167 | [D] | KARL on pdp64 |
| The giant lock is being unpicked, system call by system call | "Diff below pushes the kernel lock around namei() and vn_stat" (unlocking `stat(2)`) | Martin Pieuchot, 6 Jan 2025 | index doc0169 | [D] | ch. 6: 2025, and the kernel lock still exists |
| Why system calls are pinned | "Inside the kernel, we know the system call # and the address of the syscall instruction"; the changes "attempt to disrupt methodologies commonly used in attacks. I make no claim these changes stop all methods ... requiring specific entry points increases the fragility and difficulty. Another benefit is that it requires unique methodology for OpenBSD" | Theo de Raadt, `pinning all system calls`, 8 Dec 2023 | marc.info `m=170205367232026` (index doc0225) | [D] | openbsd-mitigations 2.6: on pdp64 both facts are in registers at entry (`ECAUSE`, `EPC`) |
| Execute-only text breaks software that reads its own `.text` | "On OpenBSD .text segments are mapped execute only. If your hardware support X-only it will crash immediately, on systems without X-only support the vm fault handler does the check ... You need to put data into the .data or .rodata section. End of story."; Philip Guenther: it has been "30+ years since .rodata instead of .text has been the section for read-only data" | Claudio Jeker, Philip Guenther, 27-28 Jul 2024, `failure to read huge .text section` | index doc0264, doc0265 | [D] | **direct evidence for the pdp64 literal-pool exposure** (openbsd-mitigations 2.3, idea 1): pools in `.text` crash under OpenBSD's policy |
| The OS checks microcode versions | OpenBSD ships Intel and AMD microcode packages and added a check of minimum microcode versions (AMD patch level `a0011de`, minimum `a0011d9`, Oct 2025); Intel security releases (INTEL-SA-01083, -01396) are tracked in the release notes | Alexander Bluhm, Jonathan Gray, Stuart Henderson, Oct 2025 and Feb 2026 | index doc0230-0232 | [D] | hardware-vulnerabilities C13: a chip that reports its own state removes this table |
| Hybrid cores | "This simple rule does not apply to more modern CPUs, which can have [different cores]"; the dmesg cache lines differ between P and E cores | Otto Moerbeek, Stuart Henderson, 8 Jun 2024, `cpu cores` | index doc0257, doc0258 | [D] | pdp64: identical cores; P4 describes them anyway |
| `xonly` on amd64 needed testers | "xonly on amd64: testing wanted" | Theo de Raadt, 15 Jan 2023 | marc.info `m=167374666324119` (the page returned 504 once; not read) | listing | openbsd-mitigations 2.3 |

### IOMMU, bounce buffers, scheduler and atomics API (round 2, continued)

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Changing IOMMU mappings can cost more than copying | for small DMA, "memcpy can be significantly faster"; with bounce buffers fio on a passed-through NVMe drive under virtio-iommu (i5-10210U) rose "2.8x, 4.7x, 3.6x, and 3.6x" for 4k to 128k blocks and time in `iommu_dma_unmap` fell "97%, 94%, 90%, and 87%"; "virtio-iommu and vfio_iommu_type1 both have big locks that significantly limit multithreaded DMA performance" | David Stevens (Chromium), `[PATCH v2 0/9] Add dynamic iommu backed bounce buffers`, 6 Aug 2021; measured by the author | doc0202 | [D] | ch. 7: R6; an I/O translation unit has a cost that a bounce copy can beat |
| Bounce buffers are needed again for security | AMD SEV: "the guest RAM is mostly encrypted and all emulated DMA has to happen to/from the SWIOTLB aperture"; a `virtio-blk` limit of the bounce-buffer size had to be fixed | Joerg Roedel, 10 Jan 2019; Alexey Kardashevskiy (IBM pseries secure guests), 7 May 2019 | doc0199, doc0200 | [D] | ch. 7 |
| IOVA caching | "For streaming DMA mappings involving an IOMMU and whose IOVA len regularly exceeds the IOVA rcache upper limit ... performance can be reduced" | John Garry (Huawei), 14 Jul 2021 | doc0203 | [D] | ch. 7 |
| Non-coherent IOMMU path was heavy | "taking a round-trip through iommu_iova_to_phys() is a pretty heavyweight way to get an address we can trivially compute from the page we already have" | Robin Murphy (Arm), 12 Sep 2018 | doc0204 | [D] | ch. 7 |
| Atomics API too large to keep consistent by hand | the atomic headers are generated by script "to ensure that the various atomic APIs remain consistent, reducing the risk of human error" | Mark Rutland (Arm), 4 Sep 2018 | doc0190 | [D] | ch. 6: pdp64's atomics set is small and uniform |
| The scheduler's group hierarchy costs on every wakeup | "the CPU controller uses hierarchical runqueues ... This increases a fairly large amount of overhead for workloads that do a lot of wakeups a second, especially given that the default systemd hierarchy is 2 or 3 levels deep" | Rik van Riel, 6 Sep 2019 | doc0196 | [D] | not hardware |
| EEVDF replaces CFS | "now it fully replaces CFS"; the author measured a "max delta ... ~44 bits" in the virtual-runtime average | Peter Zijlstra, 28 Mar and 31 May 2023 | doc0194, doc0195 | [D] | not hardware |
| Function-granular KASLR is cheap at boot | "rearranges your kernel code at load time on a per-function level granularity, with only around a second added to boot time" | Kristen Accardi (Intel), 23 Sep 2020 | doc0221 | [D] | openbsd-mitigations 2.8: OpenBSD relinks whole objects at every boot |

### Boot, firmware and bring-up (cross-reference: [`boot.md`](boot.md))

The pain at boot is not in the processor but in what surrounds it: firmware tables that are wrong, vendors who need a quirk each, and the sequence that starts the other cores. The author's boot design is [`boot.md`](boot.md) (errata 47 to 51); this section records what the lists say about the failure modes it must avoid. Findings:

| Pain | What was said | Who, when | Source | Label | Consequence for boot.md |
|---|---|---|---|---|---|
| A quirk per machine, found by test-and-wait | an ACPI embedded-controller quirk for one laptop: "the debugging model is test result --> patch --> 1-2 weeks + result --> patch ... over and over, which makes it difficult to root cause" | Feng Tang (Intel), 9 Oct 2012 | doc0206 | [D] | a boot interface with fewer vendor tables has fewer quirks to find |
| Broken BIOSes | "ACPI: Quirk to make SMBus objects work on IBM machines with broken BIOSes": the reviewer asks to push a long-pending patch before rc3 | Jean Delvare, 5 Jan 2010 | doc0207 | [D] | |
| Old firmware and new firmware at once | "I hope to have a solution that works for both old buggy firmware and the future improved firmware" (X-Gene PCIe ECAM quirk, ACPI nodes `PNP0C02` missing from tables) | Duc Dang (APM), 1 Dec 2016 | doc0205 | [D] | |
| The firmware and the kernel disagree about the interrupt mode | "When kernel doesn't support X2APIC but BIOS has enabled X2APIC, system may panic or hang without useful messages"; the fix is to "panic with a clear message" | Jiang Liu (Intel), 7 Jan 2015 | doc0210 | [D] | a handoff of one defined state (reset-state rules, ISA 9) avoids the mismatch |
| The memory map from firmware is not trusted | "x86/e820: put !E820_TYPE_RAM regions into memblock.reserved" | Naoya Horiguchi (NEC), 15 Jun 2018 | doc0215 | [D] | the memory-size handoff is a boot.md item |
| Starting the other cores is a polling loop | after the INIT/SIPI/SIPI sequence the boot processor "polls for up to 10 seconds"; on a 4-core desktop each core comes up in "305, 404, 405 usec" and removing a `udelay(100)` saves about 100 us in 2 of 3 cases | Len Brown (Intel), 16 Aug 2015 | doc0211 | [D] | the secondary-core release (ISA 17.4 "still to be built") should be an event (`SEV`), not a polling delay |
| An Arm spin table needs a reserved word | "As Documentation/arm64/booting.txt says, the cpu-release-addr location should be reserved"; boot loader U-Boot gained "better and more generic spin-table support" in 2016 | Masahiro Yamada, Tom Rini, Jun to Jul 2016 | doc0212-0214 | [D] | R2 inter-processor interrupt / core release |
| A Xen security feature versus 32-bit guests | "SMAP ... is not compatible with 32-bit PV guests which aren't aware/prepared"; "correct behavior is more relevant than performance. Hence I think we should bite the bullet"; on AMD "unable to selectively trap CR4 bit modifications ... a significant performance hit" | Jan Beulich, 17 Mar and 3 May 2016; Igor Druzhinin, 16 Jan 2020 | doc0218-0220 | [D] | a guard bit in the `PSW` (UA) needs no trapped control register |

**Reading.** Boot pain is mostly one of three things: (1) a table from firmware that is wrong (ACPI, e820, device tree), costing a quirk each; (2) a state handed to the kernel that the kernel does not expect (x2APIC on, SMAP off); (3) a start sequence that polls. [`boot.md`](boot.md) answers (1) and (2) by construction if it defines the exact machine state at handoff and the memory map format; (3) by making secondary start an event. This document does not edit `boot.md`.

### NetBSD tech-kern (mail-index.netbsd.org), round 2

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| The measured cost of SVS (NetBSD's page-table isolation) | "build.sh should be a good benchmark since it generates many kernel<->user transitions ... Without SVS: 4min 13sec; With SVS: 4min 20sec. Which makes a 2,7% overhead. That's a pretty good result on my CPU, but I suspect it will be more expensive on older CPUs - which, I heard, are slower at flushing caches"; SVS is disabled at boot when the CPU is not Intel, and can be turned off at run time but "you can't re-enable SVS once you've disabled it" | Maxime Villard, `Enabling SVS by default`, 22 Feb 2018 (measured on an Intel Core i5, `./build.sh -j 4 kernel=GENERIC`) | `tech-kern/2018/02/22/msg023134.html` | [D] | ch. 4: one measured number, 2.7%, on a build; compare Hansen's 5% typical |
| A TLB shootdown for every file-system block | "FFS triggers a pathologic case. I/O transfer maps and then unmaps each block into kernel pmap ... This triggers TLB shootdown IPIs for each FS block"; options: lazily invalidate the kernel pmap (avoid IPIs to idle CPUs), run the idle thread in its own address space (rejected: "would add a lot of overhead into the idle routine, it would require at least an address space switch"), or avoid mapping through the kernel map ("Hard") | Jaromir Dolecek, `Fixing excessive shootdowns during FFS read (kern/53124)`, 24 Mar 2018 | `tech-kern/2018/03/25/msg023247.html` | [D] | ch. 5: broadcast `TLBI` still costs one broadcast per unmap, but no interrupt on idle cores and no idle-thread special case |
| A compiler change as the Spectre answer | NetBSD 8 gained the GCC `-mindirect-branch` family from the openSUSE patch: "Builds working amd64 kernel (*without new mitigations*!); Need: ... Decide which spectre mitigation to use; ... Also, modules!" | maya, `gcc spectre stuff for netbsd-8`, 12 Mar 2018 | `tech-kern/2018/03/12/msg023177.html` | [D] | ch. 4 |

### Linux lists before 2005 (lkml.iu.edu archive) and FreeBSD, round 2

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| An SMP kernel on one CPU pays for its locks | "You cannot avoid significant slowdown with SMP kernel on UP machines due to extra locking needed"; the alternative argued was one kernel image for mixed fleets ("dual PPros or PIIs on over 4000 desktops") | Martin Mares, 1 Jun 1998 (thread `Compatible with i386/UP but optimised for i686/SMP`) | `lkml.iu.edu/hypermail/linux/kernel/9806.0/0040.html` (doc0297), `0044.html` (doc0299) | [D] | ch. 6: pdp64's first kernel is uniprocessor; a build without SMP locking is the baseline |
| The 2.4 virtual-memory system could be hung by one program | "I can hang the computer practically in no time" with a short program on a clean 2.4.0-test9, while on 2.2 the same program just exhausts memory and the offending process is killed; the thread drew Rik van Riel's VM throughput patches in 2001 | David Weinehall, 4 Oct 2000; Rik van Riel, 1 Mar 2001 | `0010.0/0561.html` (doc0303), `0103.0/0058.html` (doc0308) | [D] | ch. 5 |
| The O(1) scheduler could live-lock on a test | the patch makes children "start with a smaller sleep_avg" because "the child processes inheriting the favorable sleep_avg ... caused the problem with waitpid06"; Oct 2002 | thread `O(1) Scheduler (tuning problem/live-lock)` | `0210.0` (doc0315) | [D] | not hardware |
| Cache-control instructions are slow and the MTRR code is wrong under SMP and hyperthreading | "the trace shows that the first one is 300 usecs, the second and third one is 150 usecs each, so it's not exactly cheap"; the only way he sees to guarantee zero cache effects is to catch all CPUs, disable interrupts and caches, flush, set the MTRRs on every CPU, re-enable and continue, "SMP-synchronized at every point"; "I believe the MTRR code is quite incorrectly coded as-is" | Ingo Molnar, voluntary preemption thread, Sep 2004 | `0409.0` (doc0328) | [D] | ch. 7: pdp64 has `MT` in the entry, not a system-wide MTRR set; no per-core variable-range registers to keep synchronised |
| The TLB context and the page-table lock were one invariant | "True on sparc64 as well where the page table lock is what synchronizes TLB context allocation for a process. While the lock is held, we know that the TLB context cannot change ... flush_tlb_page() is always called with the page table lock held" | David S. Miller, 1 Sep 2004 (page fault scalability patch) | `0409.0` (doc0327) | [D] | ch. 5: ASID allocation and `TLBI` ordering are kernel rules that should be written down (P5) |
| Secrets in non-cacheable memory as a Spectre countermeasure | keep sensitive data in non-cacheable memory: "you take a performance hit storing things in non-cacheable locations", but it is "almost certainly going to be less than the projected 30-50% performance hit from other mitigations" | Eric McCorkle, `A more general possible meltdown/spectre countermeasure`, freebsd-security, 4 Jan 2018 | `lists.freebsd.org/pipermail/freebsd-arch/2018-January/018807.html` (doc0283) | [D] | ~~pdp64's `MT = 01` page attribute gives this with no new mechanism~~ **Corrected in 14D:** Losh called the idea "fatally flawed", and ZombieLoad showed uncacheable data still leaks through the line-fill buffer; `MT = 01` is not a countermeasure |

## 14C. How many sources, by area

Counts for round 2 (pages fetched since the first document commit), made by `/tmp`-resident scripts from `docs/codegen-data/kernelpain/round2-index.tsv`. "Pages" counts every fetched page; "distinct" counts distinct normalized titles, so v3, v4 and v5 of one cover letter count once; "cited" means the page is referenced in section 14B or an Appendix A.2 row; "failed" are 5xx or block pages (not counted as sources).

| Area | Pages | Distinct threads (non-failed) | Cited in 14B | Routine or context | Failed |
|---|---:|---:|---:|---:|---:|
| speculation and entry | 46 | 36 | 15 | 31 | 0 |
| locks, atomics, RCU | 18 | 13 | 12 | 6 | 0 |
| constant time | 18 | 12 | 2 | 16 | 0 |
| TLB, MM, scheduler | 36 | 22 | 25 | 11 | 0 |
| DMA and IOMMU | 10 | 9 | 5 | 5 | 0 |
| time, interrupts, y2038 | 19 | 16 | 11 | 8 | 0 |
| machine check | 6 | 4 | 2 | 4 | 0 |
| hardening and uaccess | 18 | 13 | 14 | 4 | 0 |
| constant-time and reference pages | 8 | 1 | 0 | 8 | 0 |
| OpenBSD lists (marc.info) | 81 | 47 | 18 | 56 | 7 |
| boot and firmware | 13 | 13 | 9 | 4 | 0 |
| NetBSD lists | 5 | 5 | 3 | 2 | 0 |
| Linux lists before 2005 | 39 | 35 | 7 | 32 | 0 |
| LWN archived copies (Wayback) | 8 | 8 | 0 | 8 | 0 |
| FreeBSD lists | 12 | 4 | 1 | 11 | 0 |
| **Total** | **337** | **238** | **124** | **206** | **7** |

**Against the target of 150 additional primary sources.** The count of *pages* fetched is above 150; the count of *distinct threads or documents* is lower, and the count of those that contain a developer statement about cost, pain or a decision (rows in 14B and A.2, each citing one or more threads) is the figure that matters; it is 80 (the rows of 14B, counted by `grep`). The automated selection took the first one to three distinct hits per query, which gave many routine patches (version bumps, `Re:` replies without content). Returns diminish for **automated lore queries** (about one hit in three carries a statement); they do not diminish for **chosen threads** (a cover letter or a reply by a named maintainer), which is what the remaining queue should be: the unread items in `RESUME.md`. The areas with the thinnest coverage are: the BSD lists before 2018 (FreeBSD and NetBSD month indexes are reachable now), Linux before 2005 (reachable through `lkml.iu.edu`, only a few pages read), the papers and talks, and LWN (blocked; 8 archived copies read).

## 14D. Round 3: developer statements, chosen threads and primary papers

Round 3 (23 Oct 2026, about two hours) followed the queue of `RESUME.md` in order, with **chosen threads** instead of automated queries: 21 LWN articles through Wayback Machine copies, FreeBSD `pipermail` threads, two more `lkml.iu.edu` slices, the named lore threads (Gleixner's PTI series cover, the Skylake RSB thread, RISC-V Zacas, the arm64 TLB range series, the transparent-huge-page benchmark), NetBSD `tech-kern`, one OpenBSD post, and the project pages and papers for Meltdown, Spectre, Foreshadow, RIDL, ZombieLoad, Retbleed, Downfall and Rowhammer. Every quotation below was copied from a page text saved and read in this round (the page cache is `/tmp/claude-1000/corpus3/doc0001..doc0098.txt`; the index with URL, area, query, author, date and kind is `docs/codegen-data/kernelpain/round3-index.tsv`). Labels: **[D]** developer statement, **[S]** secondary (an LWN article reporting developers), **[P]** primary paper or project page by the people who found or fixed the flaw. Where only part of a thread was read, the row says so.

**Pace, honestly.** The browser fetched one page at a time. The first two Wayback requests of the round (LWN 768418 and 774743) were sent 29 seconds apart, under the 60-second floor for archive.org; the coordinator stopped the run, a mechanical guard (`politewait.py`) was put in front of every fetch, and all later archive.org requests were at least 65 seconds apart (the log in `/tmp/claude-1000/r3.log` shows "last request 65 s ago" or more for each). No 429, 503, captcha or block page was met in this round (the fetcher stops on any; the index column `kind` has 5 `failed` rows: two 404s, one mistyped fetch with an empty URL, and two lore searches with no results).

### Hardware flaws in the developers' and discoverers' own words

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| The architecture said nothing about what speculation may leak | "there is currently no way to know whether a particular code construction is, or is not, safe across today's processors - much less future designs"; "long-term solutions will require that instruction set architectures be updated to include clear guidance about the security properties of the processor"; serializing instructions "constrain speculative execution because the results of speculatively executed instructions are discarded", which "is different from ensuring that speculative execution will not occur or leak information"; the behaviour of `lfence`/`mfence` "with respect to speculative execution is not defined" (a footnote: Intel "indicated that the definition of lfence will be revised to specify that it blocks speculative execution") | Kocher, Genkin, Gruss et al., Spectre paper, arXiv 1801.01203 (Jan 2018; sections 7 and 8) | `ar5iv.labs.arxiv.org/html/1801.01203` (doc0062) | [P] | hardware-vulnerabilities C13: the ISA document must state what a mispredicted path may leave behind; pdp64 states "no speculation" |
| Where the check sits in the pipeline is the whole bug | Meltdown is "some form of race condition between the fetch of a memory address and the corresponding permission check"; serializing the two "involves a significant overhead to every memory fetch"; the authors propose "a hard split of user space and kernel space ... a new hard-split bit in a CPU control register" so that "the privilege level can be directly derived from the virtual address without any further lookups. We expect the performance impacts of such a solution to be minimal"; and "There is no documentation whether such a fix requires the development of completely new hardware, or can be fixed using a microcode update" | Lipp, Schwarz, Gruss et al., Meltdown paper, arXiv 1801.01207 (Jan 2018; section 7) | `ar5iv.labs.arxiv.org/html/1801.01207` (doc0061) | [P] | the discoverers' proposal is privilege derived from the address alone; whether pdp64's address layout gives that should be checked and written down (open question); keep the check before the data returns (rule C1) |
| KAISER left pointers behind | "several privileged memory locations are required to be mapped in user space ... Even though these memory locations do not contain any secrets ... they might still contain pointers. Leaking one pointer can be enough to again break KASLR" | Meltdown paper, sec. 7.2 | doc0061 | [P] | the entry stub of an implementation that unmaps the kernel must itself hold no kernel pointer (new rule suggestion C17) |
| Flushing the L1 is not enough; the fix needs a new flush | "We have not found an instruction sequence that reliably prevents leakage across protection boundaries. Even flushing the entire L1 data cache (using MSR_IA32_FLUSH_CMD) and issuing as many dummy loads as there are fill-buffer entries ('load stuffing') is not sufficient ... to fully mitigate the leakage, we require a microcode update which provides a method to flush the line-fill buffer"; "disabling hyperthreading or co-scheduling are not fully effective as mitigation" because the leak also works "across protection boundaries on a single logical core" | Schwarz et al., ZombieLoad paper, arXiv 1905.05726 (embargo ended 14 May 2019) | `ar5iv.labs.arxiv.org/html/1905.05726` (doc0063) | [P] | C5: every buffer that holds data across a privilege change needs a defined clear |
| Uncacheable memory is not a defence | PoC "leaking uncacheable-typed memory locations from a concurrent hyperthread" sent to Intel on 28 Mar 2018; "every memory load from the page circumvents all cache levels and directly travels from the main memory to the fill buffer", and the leak still appears; "Memory accesses to uncacheable memory regions, and non-temporal moves all go through the LFB"; the same works "for Foreshadow (Meltdown-P), undermining the completeness of L1-flush-based mitigations" | ZombieLoad paper | doc0063 | [P] | see the correction at the end of this section: the `MT = 01` attribute is not a Spectre or Meltdown countermeasure |
| The first MDS fix was incomplete and the embargo process failed | RIDL authors submitted proofs of concept on 29 Sep 2018 and "received no technical feedback"; "we only got a complete picture on Intel's MDS disclosure plan on May 10, 2019, just 4 days before public disclosure ... Intel's fixes did not fully mitigate the vulnerabilities we had reported"; on 13 May 2019 Intel asked for "a new last-minute embargo until Nov 12, 2019"; "The initial mitigations against MDS clear the buffers by writing stale, potentially sensitive, data into these buffers"; L1D eviction sampling (CVE-2020-0549) "would bypass their latest VERW mitigation"; "Ironically, 9th-generation CPUs are more vulnerable to some of our attacks compared to older generation hardware"; "If we can no longer trust our hardware, the foundation on which we build all security solutions is crumbling away" | VUSec (Ridl, Fallout), pages updated to Jan 2020 | `mdsattacks.com` (doc0067) | [P] | C13, C14: publish what leaves state; test the fix against the discoverers' own proofs |
| Foreshadow went around the previous mitigations | "The mitigations against Meltdown and Spectre are not effective against Foreshadow and Foreshadow-NG"; "Foreshadow is effective against systems deploying Kernel Page Table Isolation (KPTI), which stops Meltdown attacks"; the enclave attack works "even in the case where the code of the affected enclave is 'perfect'"; "Foreshadow and Foreshadow-NG require mitigations at the both software and microcode level"; first notified to Intel on 3 Jan 2018 (KU Leuven) and 23 Jan 2018 (second team); Intel's list of affected parts for the next-generation variant is 2nd to 8th generation Core and Xeon 3400 to Scalable | KU Leuven, Technion, Michigan, Adelaide teams (project page; notifications 3 and 23 Jan 2018) | `foreshadowattack.eu` (doc0066) | [P] | one hole after another through the same structure (the L1) is the pattern; C5, C9 |
| A vector instruction leaked the register file | "the Gather instruction ... leaks the content of the internal vector register file during speculative execution" on Intel Core 6th (Skylake) to 11th (Tiger Lake) generation, "At least nine years" of exposure; the mitigation microcode "blocks transient results of gather instructions"; "According to Intel, some workloads may experience up to 50% overhead"; turning the mitigation off is "a bad idea" because "modern CPUs rely on vector registers to optimize common operations, such as copying memory and switching register content"; "Manufacturers must design shared memory units with extra care to prevent data from leaking across different security domains and invest more in security validation and testing"; embargo "Almost one year" (reported 24 Aug 2022) | Daniel Moghimi, Downfall page (talks 9 and 11 Aug 2023) | `downfall.page` (doc0065) | [P] | any gather or scatter pdp64 adds must have an architectural statement about its internal state (C14) |
| Returns predicted like indirect branches; the fix cost 14% to 39% | "Mitigating Retbleed in the Linux kernel required a substantial effort, involving changes to 68 files, 1783 new lines and 387 removed lines ... we have measured between 14% and 39% overhead with the AMD and Intel patches respectively"; "returns were deemed impractical to exploit, and concerns were brushed off"; on Intel returns act like indirect jumps when the return stack buffer underflows ("over a thousand of such conditions that can be triggered by a system call"); on AMD "returns will behave like an indirect branch regardless of the state of their Return Address Stack"; AMD "phantom jumps" (CVE-2022-23825) predict a branch "even in the absence of any corresponding branch instruction"; "Return instructions are essentially indirect jumps fused with a pop from the stack. Because they are similar it makes sense to treat them as such from the microarchitecture's perspective" | Wikner and Razavi (ETH Zurich), Retbleed page, 2022 | `comsec.ethz.ch/research/microarch/retbleed/` (doc0064) | [P] | pdp64 has no return predictor today; if one is added, return and indirect target predictors must be separate and tagged (C2) |
| Rowhammer: the instruction that made it possible could not be turned off | "CLFLUSH is usable from unprivileged code ... surprising, because the number of legitimate uses for it outside of a kernel or device driver is probably very small. For comparison, ARM doesn't have an unprivileged cache-flush instruction"; "kernels can't disable CLFLUSH for normal userland code. Currently, CLFLUSH can't be intercepted or disabled, even using VMX ... There might be a case for changing the x86 architecture to allow CLFLUSH to be intercepted. From a security engineering point of view, removing unnecessary attack surface is good practice"; "NaCl assumes that the hardware behaves correctly. It assumes that memory locations don't change without being written to!"; a bit flip in a page-table entry gave kernel privileges, and the exploit needed `/proc/PID/pagemap` or huge pages to find physically adjacent rows; a BIOS update that appeared to fix the laptop still flipped bits after "almost 40 minutes"; LPDDR4 specifies Targeted Row Refresh and a Maximum Activate Count; "We don't know for sure how many machines are vulnerable to this attack, or how many existing vulnerable machines are fixable" | Mark Seaborn and Thomas Dullien, Project Zero, 9 Mar 2015 | `googleprojectzero.blogspot.com/2015/03/exploiting-dram-rowhammer-bug-to-gain.html` (doc0068) | [P] | hardware-vulnerabilities 3.5: an unprivileged cache-flush instruction should not exist (suggestion); ECC on page-table pages is a further suggestion |
| The OS asked for an architectural bit, not a model list | When Arjan van de Ven proposed RSB stuffing "if we're on a SKL *or* as a guest in a VM", Linus Torvalds answered: "wouldn't it be even better to extend on the current cpuid model, and actually have some real architectural bits in there. Maybe it could be a bit in that IA32_ARCH_CAPABILITIES MSR. Say, add a bit #2 that says 'ret falls back on BTB'. Then that bit basically becomes the 'Skylake bit'" | Torvalds, 29 Jan 2018 | lore `CA+55aFyrKudn2QKe4D==BZCCQDqqfDzQZ6i8PR8-AfAufTtGFQ@mail.gmail.com` (doc0084) | [D] | P4 feature registers, C13: capability bits for every hardware behaviour, never "model X" |
| The Skylake return fix was acknowledged as partial | commit message: "On Skylake+ the problem is slightly different, and an *underflow* of the RSB may cause errant branch predictions to occur. So there it's not so much overwrite, as *filling* the RSB ... This is only a partial solution for Skylake+ since there are many other conditions which may result in the RSB becoming empty. The full solution on Skylake+ is to use IBRS"; the code lists five Intel models by hand in `is_skylake_era()` | David Woodhouse, committed by Gleixner, 14 Jan 2018 | lore `tip-c995efd5a740d9cbafbf58bde4973e8b50b4d761@git.kernel.org` (doc0039) | [D] | the same C2 / P4 point; the model list is what a capability bit replaces |
| Maintainers refused the knobs | Andi Kleen: "Missing an option to turn this off." David Woodhouse: "Deliberately so. You can already boot with 'spectre_v2=off' to turn off the mitigations. We are not intending to permit all the bullshit micro-management of IBRS=3/IBPB=2/RSB=π nonsense ... You *do* have the source code, if you really want to make changes. Don't." (This is the opposite of the 24 `MITIGATION_` options counted in section 2 and of Kaplan's 2025 attack-vector controls in 14B.) | Kleen 14 Jan 2018; Woodhouse 15 Jan 2018 | lore `20180115000554.GA7844@tassilo.jf.intel.com` (doc0040), `1516011195.22147.132.camel@infradead.org` (doc0041) | [D] | fewer modes is the design goal |
| A guess about what the CPU does on RSB underflow | David Laight: "Do we have a guarantee that all cpu actually detect the related RSB underflow? It wouldn't surprise me if at least some cpu just let it wrap ... Potentially this leaks a kernel address to userspace." Woodhouse: "Yeah, KASLR is dead unless we do a full IBPB before *every* VMLAUNCH or return to userspace anyway, isn't it?" Arjan van de Ven (Intel): "KASLR pretty much died in May this year to be honest with the KAISER paper (if not before then)"; Kees Cook: "KASLR was always on shaky ground for local attacks. For pure remote attacks, it's still useful." | Laight, Woodhouse, van de Ven and Cook, 15 Jan 2018 | lore `1516027166.22147.183.camel@infradead.org` (doc0042), `db67ffe2-ee2b-2295-de8e-a1738c661c6e@linux.intel.com` (doc0094), `CAGXu5jK=-9oQPPxtjU0wKRyae2W=M2TP4zJaY3RwcrRvQ1Efnw@mail.gmail.com` (doc0095) | [D] | kernel developers were reasoning about undocumented hardware behaviour; C13 |
| Hotplug of CPUs with different models | "I'm not convinced we handle the case of hotplug CPU's with different CPU models correctly. In fact, I'd be very surprised it it worked in the general case." | Torvalds, 19 Feb 2018 (reply to Alan Cox on enhanced IBRS) | lore `CA+55aFzm7zLd5BPtpp9MYMuP8We55bMd7noeLPrXiKfDynO6JA@mail.gmail.com` (doc0083) | [D] | uniform cores (no mixed-model SMP) in pdp64's first system |
| The page-table isolation series | Gleixner's cover (136+ messages in the thread): the new name was chosen after "Several people including Linus requested to change the KAISER name"; "AMD confirmed that there is no issue with that [read-only TSS in the user-visible mapping]. It would be nice to get confirmation from Intel as well"; "allmod/yes config builds fail right now because the fixmap grows too large and breaks the EFI assumptions"; "Handle native vsyscalls. Right now the patch set supports only emulation, but it should be possible to support native as well. Nothing urgent, I'd rather prefer to kill them completely"; "The mail threads are horribly scattered so I might have missed something." Torvalds: "The problem, of course, is how *subtle* all the interactions are, and how one missed 'oh, the CPU also needs this' makes for some really nasty breakage ... And yes, paravirtualization is evil." Lutomirski: "KPTI will make it possible to avoid global IPI broadcasts on kernel flushes as we discussed, incorrectly, two years ago at LPC" | Gleixner 4 Dec 2017; Torvalds 4 Dec 2017; Lutomirski 5 Dec 2017 | lore `20171204140706.296109558@linutronix.de` (doc0033), `CA+55aFzd87ug...` (doc0035), `CALCETrWHV06Pzqun...` (doc0037) | [D] | ch. 3, ch. 4; every x86 mandatory mapping into the user view is one more fact the OS must know ("the CPU also needs this") |
| PTI lost the global bit, and getting it back was measured | Hansen: "During the switch over to PTI, we seem to have lost our ability to have GLOBAL mappings." Atom without PCIDs, `lseek` microbenchmark: 6,077,741 lseeks/s baseline, 7,528,609 with 88 global lines (+23.9%), 8,433,111 with 94 (+38.8%); Skylake with PCID: 15,783,951 to 16,054,688 (+1.71%); kernel compile 186.951 s to 185.756 s (-0.64%). Torvalds: "the devil is in the details", "the performance numbers certainly speak for themselves, even if the big changes are from that Atom microserver" | Dave Hansen, `[PATCH 00/11] [v4] Use global pages with PTI`, 3 Apr 2018 | lore `20180404010946.6186729B@viggo.jf.intel.com` (doc0086), `CA+55aFxYunj-s2N60Q2Y63TsrhJKwqLa=-GJPMb6--RA_ud6Fw@mail.gmail.com` (doc0085) | [D] | ch. 5, P5: where a CPU has no ASID tags, shared kernel mappings with a global bit recover up to 38.8% of a system-call loop; pdp64's 16-bit ASID avoids the case |

### LWN articles read through Wayback copies (21)

All are **[S]**; the quotations are developers' words as printed by LWN. Authors' names: Corbet unless noted.

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Cache flush on error returns as a Spectre net | Alan Cox: "The current process of trying to find them all with smatch and the like is a game of whack-a-mole that will go on for a long long time." Andy Lutomirski: "Adding ~1600 cycles plus the slowdown due to the fact that the cache got flushed to a code path that we hope isn't hot to mitigate one particular means of exploiting potential bugs seems a bit dubious to me." LWN: Cox said the cost was "pretty much zero" but "no hard numbers have been posted" | Kristen Carlson Accardi's patch; LWN 15 Oct 2018 | LWN 768418 (doc0001) | [S] | ch. 4 |
| Retpolines hurt and four software remedies appeared | "Essentially we're doing indirect branch prediction in software because the hardware can't be trusted to get it right; this is sad." (Edward Cree); Jesper Dangaard Brouer on the DMA-mapping layer: "my XDP performance is back" after Hellwig's direct-call test; Nadav Amit's self-patching "relpolines": 10% gain on an nginx benchmark and 2% even with retpolines off | LWN 14 Dec 2018 | LWN 774743 (doc0002) | [S] | ch. 4: pdp64 has no predictor, so there is nothing to replace in software today |
| `swapgs` is a speculation gadget | Poimboeuf in the mitigation patch: "It's difficult to audit for this gadget in all the handlers, so while there are no known instances of it, it's entirely possible that it exists somewhere (or could be introduced in the future). Without tooling to analyze all such code paths, consider it vulnerable."; the fix puts `LFENCE` on the paths that decide whether to run `SWAPGS`; the pull request called it "the performance deterioration department"; Corbet: "slowing down the system to defend against attacks that may or may not be practical" | LWN 8 Aug 2019 (CVE-2019-1125) | LWN 795637 (doc0003) | [S] | ch. 3: check in the system architecture how the per-CPU base is found on entry; the lesson is that an entry-time swap decided by a branch is a gadget |
| Spinlock fairness took a new lock | Nick Piggin: "On an 8 core (2 socket) Opteron, spinlock unfairness is extremely noticable, with a userspace test having a difference of up to 2x runtime per thread, and some threads are starved or 'unfairly' granted the lock up to 1 000 000 (!) times." Byte-sized tickets limit the system to 256 CPUs; 16-bit tickets when more are configured | LWN 6 Feb 2008 | LWN 267968 (doc0004) | [S] | ch. 6: a fair lock needs a fetch-and-add (pdp64 has `XADD`, ISA section 4.11) |
| Ticket locks bounce the data line too | Rik van Riel's microbenchmark was slowed "by a factor of two" with one contender and "by as much as a factor of ten" with many (Corbet's wording); the backoff constants 50 and 2.7 "were determined empirically"; Michel Lespinasse: "I haven't figured out an automatic way to find the most appropriate spinlock_delay system tunable" | LWN 3 Jan 2013 | LWN 531254 (doc0005) | [S] | ch. 6: lock word and protected data should not share a line |
| NUMA hand-off for queued locks took 14 revisions | the NUMA-aware qspinlock "has been through 14 revisions since it was first posted in January 2019"; benefit "approaching a factor of two for ridiculously heavily contended loads"; a 10 ms (1 to 100 ms) timeout prevents starvation of other nodes; "shuffle reduction" runs the queue sorting on 1 in 128 acquisitions | LWN 12 Apr 2021 | LWN 852138 (doc0006) | [S] | no NUMA in pdp64's first system |
| TLB documentation and counters were missing | Mel Gorman: "On the PPC64 architecture, there is no automatic means of determining the number of TLB slots"; `perf` "is not currently able to map certain TLB events, such as the number of cycles spent walking a page table. It is technically possible to specify a raw event ID to perf, but figuring out the raw ID is error-prone and tricky to verify"; "A detailed examination of the hardware specification may yield an estimate for the cost of a TLB miss, but it is time-consuming and documentation is not always sufficient" | LWN 23 Mar 2010 | LWN 379748 (doc0007) | [S] | P4, P5: a feature register states TLB geometry and a counter counts walk cycles |
| TLB flushes need ranges | Aneesh Kumar: "there needs to be an easier way to flush a range of TLB entries"; Arcangeli: reverse-map lists with kernel same-page merging "can grow toward one million entries"; the KVM notifier sends IPIs because shadow page tables keep no hardware accessed bit (LWN's paraphrase) | LWN 27 Apr 2016 (LSFMM) | LWN 684934 (doc0008) | [S] | P5: range invalidate; a hardware accessed bit (suggestion) |
| The address-space lock | Gorman: replacing `mmap_sem` would be "the big kernel lock all over again"; Dave Hansen (paraphrase): `mmap_sem` "is a heavyweight lock, even when just acquired for reading. It bounces its reference count around the system, creating a lot of cache misses"; in 2022: "Even if the lock itself is not contended, the constant cache-line bouncing hurts performance"; per-VMA locks reach "about 75%" of the speculative-fault gain with less complexity (Baghdasaryan: "Still, with lower complexity this approach might be more desirable") | LWN 8 May 2019; 5 Sep 2022 | LWN 787629 (doc0009), 906852 (doc0010) | [S] | ch. 5: a uniprocessor first kernel has no such lock |
| The TSC cannot be trusted | Thomas Gleixner: "the stupid hardware is not reliable whether it has some 'I claim to be reliable tag' on it or not"; "I'm unfortunately forced to deal with the 500+ different variants of borked timers and that makes me very reluctant to believe anything what chip/board/bios vendors promise. It's not the one time hot stove experience, it's the constant exposure to the never ending supply of hot stoves"; system-management interrupts adjust the counter to hide themselves, cores differ by boot offsets and hotplug, sockets drift with temperature (Jake Edge's summary of Gleixner's list); Arjan van de Ven: "friends don't let friends use rdtsc in application code"; Ingo Molnar: "You could win the argument by coming up with a patch that changes gettimeofday to make use of the TSC in a reliable manner. I really mean it - and it might be possible - but we have not found it yet." | LWN 19 May 2010 | LWN 388188 (doc0011) | [S] | ch. 10: a counter with one defined frequency that never stops and is not adjusted by firmware (suggestion) |
| Time on 32-bit systems | "there are 32-bit systems being deployed now that can be expected to have lifetimes of 24 years or longer" | LWN 21 May 2014 | LWN 599580 (doc0013) | [S] | 64-bit time from the start (ch. 11) |
| ARM DMA needed its own API | ARM and one other architecture each had an allocator the generic code lacked (write-combining buffers; mapping a coherent buffer into user space); "Prior to this work, IOMMU awareness had been built into specific drivers directly. But that caused opposition at review time"; only two DMA attributes existed and one (`DMA_ATTR_WRITE_BARRIER`) had a single user | LWN 16 Nov 2011 | LWN 467509 (doc0014) | [S] | ch. 7 |
| Network headers and DMA disagree on alignment | the two-byte `skb_reserve(skb, 2)` idiom aligns the IP header, but "A number of modern architectures ... have no real problem with unaligned memory accesses ... Unfortunately, the DMA engines in a number of systems do have trouble working with unaligned addresses"; fix: a named constant, `NET_IP_ALIGN` | LWN 15 Jun 2004 | LWN 89597 (doc0015) | [S] | ch. 11: Ethernet's 14-byte header against an aligned machine; suggestion: DMA buffers naturally aligned |
| An atomic across two cache lines locks the whole bus | "Intel's choice was to lock the whole memory bus to solve the coherency problem ... The split lock blocks not only the CPU performing the access, but also all others in the system"; Fenghua Yu in the cover letter: "To date the designers have been unable to deploy these solutions as they have no way to prevent the 'untrusted' user code from generating split lock and bus lock to block the hard real time code to access memory during bus locking"; detection by alignment-check exception arrived only with Tremont, earlier parts had "only an event counter"; a split lock caused by firmware hangs the system because the developers "were afraid that otherwise the firmware would never be fixed" | LWN 7 Jun 2019 (Marta Rybczynska) | LWN 790464 (doc0016) | [S] | ch. 6, 11: pdp64 atomics should trap when misaligned (suggestion) |
| A CPU freeze from user mode through the FPU | corrupted x87 state set an exception flag; the deferred exception was delivered on the next floating-point instruction, which was the kernel's `fwait` in signal return; the trap handler restored the same corrupt state and the loop never ended; fix: "clears any pending exceptions before executing fwait" | LWN 15 Jun 2004 | LWN 89586 (doc0017) | [S] | ch. 8: deferred (imprecise) FP exceptions plus lazy FP state |
| Poisoned memory is reported late | "the offending instruction and process cannot be determined due to delays between the data error consumption and execution of the poison handler"; so containment is per page, huge pages "fail since reverse mapping is not supported", and a page-flag bit was needed; "Faulty hardware that supports data poisoning is not easy to come by", so a fault injector was written | LWN 26 Aug 2009 (Jon Ashburn) | LWN 348886 (doc0018) | [S] | ch. 13: precise machine-check with the faulting address  |
| Shadow stacks need a page-table encoding | "the x86 architecture does not include a 'this is a shadow-stack page' bit"; the hardware reads write-disabled plus dirty as a shadow-stack page, "a bit of a hack", the same combination Linux used for copy-on-write, so the series added a `_PAGE_COW` software bit; 35 non-trivial patches; the earlier version reached v30; the `arch_prctl` interface was "abandoned for being strange" after binaries had been built for it; Gleixner: "We can't break CRIU systems with a kernel upgrade" | LWN 21 Feb 2022 | LWN 885220 (doc0019); earlier LWN 758245 (doc0020, 25 Jun 2018): shadow stack pages "read-only but dirty", retpolines "look a lot like a ROP attack; they will not work when a shadow stack is in use" | [S] | ch. 12: if pdp64 adds a return-address stack, give it its own page-type bit, not a reused combination |
| Store-to-load ordering needs a flush | "on x86 processors, all memory loads count as 'load-acquire', and all memory stores count as 'store-release'", yet both threads can read zero in the store-buffering test; "The only way around these problems is to flush the store buffer entirely between the store and the load. This is as expensive as it sounds (a few tens of clock cycles)" | Paolo Bonzini, LWN 5 Mar 2021 | LWN 847481 (doc0021) | [S] | ch. 6: pdp64 declares sequential consistency (ISA section 17.1), which pays this price once, in the store path of an implementation |

### Memory management, atomics and ISA interaction (lore.kernel.org)

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| A new instruction needs a new assembler | Catalin Marinas dropped the arm64 range-invalidate patches (applied 10 Jul, dropped 13 Jul 2020, merged 15 Jul): "They need a check on whether binutils supports the new 'tlbi rva*' instructions, otherwise the build mail fail"; "we don't pass -Wa,-march=armv8.4-a to gas"; "A safer bet may be to simply encode the instructions by hand" with `__emit_inst`. Zhenyu Ye's cover: "ARMv8.4-TLBI provides TLBI invalidation instruction that apply to a range of input addresses." The v2 cover letter (doc0090) contains no timings and only a diffstat (4 files, 124 insertions, 30 deletions; `tlbflush.h` alone grew by 138 lines changed); the search listing shows postings RFC v3 (5 May 2020), RFC v4 (1 Jun), RFC v5 (8 Jul), v1 (9 Jul) and v2 (10 Jul) | Marinas, 13 Jul 2020 | lore `20200713165903.GD15829@gaia` (doc0048) | [D] | suggestion: every new opcode lands in the assembler, simulator and kernel in one change |
| RISC-V has no 8-bit or 16-bit atomic and no compare-and-swap in the base | Ghiti's cover: the series adds `[cmp]xchgXX()` "using Zacas and Zabha extensions and finally uses those newly introduced macros to add support for qspinlocks: note that this implementation of qspinlocks satisfies the forward progress guarantee"; the patch uses a boot-time `ALTERNATIVE` between an LR/SC loop and `amocas`; Andrea Parri notes the fully ordered `cmpxchg` has two legal mappings: `amocas.w.rl` followed by `fence rw,rw`, or "the alternative and currently more common mapping for 'fully-ordered AMO sequences', aka amocas.w.aqrl" | Alexandre Ghiti, 28 May 2024; Parri, 28 May 2024 | lore `20240528151052.313031-1-alexghiti@rivosinc.com` (doc0045), `ZlYff9x12FICHoP0@andrea` (doc0046) | [D] | ch. 6: pdp64 has `CAS` and `XADD` in the base ISA (section 4.11), under sequential consistency (section 17.1) |
| Without huge pages, the TLB cost is measurable even on a build | Andrea Arcangeli, kernel build with `make -j32` on a 24-way host: THP always 83.86 s, THP never 87.26 s ("slowdown 4.06%"); data-TLB-load misses 2,982,343,758 against 4,425,816,093; in a KVM guest with EPT off and THP never both sides "slowdown 260.15%" (302.006 s), with EPT on and THP never 24.81%; "the total KVM virtualization slowdown ... is only 1.54%" when both sides use huge pages. The patch series was posted as "Transparent Hugepage Support #17" through "#33", 33 numbered revisions in 2010 | Arcangeli, 3 Aug 2010 | lore `20100803160131.GI6071@random.random` (doc0050); series list doc0049 | [D] | ch. 5: variable page sizes and nested translation hardware decide whether virtualization is usable at all |
| The "accessed" bit and TLB flush on S/390 | Ulrich Weigand (IBM): "The only semantically correct implementation on S/390 is to completely flush the TLB"; the efficient `ipte` "requires that the *original* PTE is still present in the page table when ipte is performed", so he asks to merge "pte modification followed by a flush_tlb_page" into one architecture routine (`ptep_invalidate`, `ptep_establish`); he also finds that the aging path "does currently *not* flush the TLB when it clears the accessed bit ... otherwise the accessed bit might not be re-set by future accesses" | Weigand, 1 Jan 2001 | `lkml.iu.edu/hypermail/linux/kernel/0101.0/0076.html` (doc0030) | [D] | P5: invalidate-by-entry that takes the new entry value in one instruction (`TLBI` with write) |
| The unaligned access that did not work | Linus Torvalds: "The cost of telling the CPU over and over again to 'please allow user space accesses' is horrendously high, so doing the whole user_access_begin()/end() just _once_ per dirent is a big deal"; his readdir optimisation broke alpha and sparc64 booting; "on alpha, it's not just that unaligned user accesses were slow, they didn't actually _work_"; a trivial `getresuid()` with an unaligned pointer into an unpopulated mapping produced an oops on alpha ("the unaligned trap handler gets an exception on the emulation code") and he asks "architecture maintainers to try the above trivial program" | Torvalds, 6 Oct 2019 | lore `CAHk-=wiGqnJc6obUGSAsP8YCFEb_ZhD2Zfz-aWxdS_E_R_1xVw@mail.gmail.com` (doc0076) | [D] | ch. 9, 11: trapping and emulating misaligned user accesses in the kernel is a bug source; pdp64 decides one policy (trap or support) in hardware |
| Emulated unaligned load-locked is not atomic | on Maciej Rozycki's alpha patch: "I don't care deeply because I do think alpha is dead"; the emulation "is not truly atomic wrt concurrent aligned non-trapping operations ... I think this is fundamental and non-fixable, because the stc is done as two operations"; "If the kernel does an unaligned ld_l/st_c, that's a fundamental kernel bug. Don't emulate it."; "A *real* ldl/stc will fail not just when the exact bytes are different, but when somebody has touched the same cacheline" | Torvalds, 19 Feb 2025 | lore `CAHk-=wgBZk1FFOyiTKLnz4jNe-eZtYsrztcYRRXZZxF8evk1Rw@mail.gmail.com` (doc0073) | [D] | ch. 6, 11: misaligned `LL/SC` or `CAS` traps; no emulation |
| Dependent loads need a barrier only on Alpha | Lai Jiangshan proposed skipping `smp_read_barrier_depends()` in `rcu_dereference` when the pointer is NULL because "memory barrier is expensive". Peter Zijlstra: "I suspect this optimization is invalid in the case where the loaded value is used as an offset (either pointer or array index)". Paul McKenney: "In that case, zero is a perfectly valid array index and requires a memory barrier on Alpha. Given that the smp_read_barrier_depends() primitive is very nearly (but not quite) a no-op on non-Alpha machines, it will also be necessary to carefully check the generated code to make sure that we are not slowing down the common non-Alpha machines to help out the very rare Alpha machines." An earlier similar check for `rcu_assign_pointer()` could not be made to handle "all the cases currently in the Linux kernel, even when we introduced a special-case primitive for array indexes ... we did not prove it impossible, but rather decided that it was consuming more time and energy than was warranted" | Lai Jiangshan, Zijlstra, McKenney, 21 Jun 2008 | lore `485CCFB9.9050208@cn.fujitsu.com` (doc0092, doc0093) | [D] | ch. 6: pdp64's memory model is sequentially consistent (section 17.1); no dependent-load barrier exists to forget |
| Generic code cannot assume unaligned access | Linus: "I guess unaligned READ_ONCE() code really shouldn't exist in generic code anyway, since some architectures will fail any unaligned access. But those architectures tend to not get a lot of testing (they are a dying breed - good riddance), so 'shouldn't exist' doesn't necessarily equate to really not existing."; Nathan Chancellor: the change that made `READ_ONCE` use acquire loads under LTO on arm64 broke one place, the EFI TPM event log (commit `d3f450533bbc`) | Torvalds and Chancellor, 26 Mar 2025 | lore `CAHk-=wgJRECUF-7yt9pNxW_bc=4nJcxn5H3duW_HefY3pKwZag@mail.gmail.com` (doc0074) | [D] | ch. 6, 11 |

### Linux, FreeBSD, NetBSD and OpenBSD lists

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| A remote-TLB window breaks lock-protected reads | Elliott Rabe (Dell) after a long hunt for "elusive, slight memory corruptions": "Before this remote TLB invalidation has completed, other CPUs are free to act on either the old OR new page characteristics. If other threads are alive and using contents of the faulting page on other CPUs, bad things can occur"; "This seemingly violates the guarantees provided by the locking primitives and can result in subtle memory corruption symptoms"; his work-around, a two-stage page-table update, "is goofy, and from an efficiency standpoint it is obviously undesirable". Konstantin Belousov's first answer asks for a test and argues that a user-mode lock held by the writer keeps the reader out until the shootdown IPI has been delivered. (Only the first message and the opening of the second were read; the end of the thread was not.) | Rabe and Belousov, freebsd-hackers, 10 Feb 2018 | `lists.freebsd.org/pipermail/freebsd-hackers/2018-February/052226.html` (doc0026), `052230.html` (doc0027) | [D] | ch. 5: the architecture must say when a TLB invalidation has taken effect on every core (a defined completion point, e.g. `DSB`-like), or pdp64 needs it only if multi-core |
| Uncached memory as a Spectre fix, rejected by a FreeBSD kernel developer | Warner Losh: "I think this is fatally flawed. The side channel is the cache. Not the data at risk. Any mapped memory, cached or not, can be used to influence the cache. Storing stuff in uncached memory won't affect the side channel one bit"; the attacks "boil down to tricking the processor, at elevated privs, to doing something like a = foo[offset]; where foo + offset are designed to communicate information by populating a cache line"; second message: "I've seen no indication that a cache miss would defeat these attacks in the public and non-public data I've looked at". Eric McCorkle's reply claimed that uncached loads "force address translation to happen first, which detects faults and blocks the meltdown attack" | Losh and McCorkle, freebsd-hackers, 5 Jan 2018 | `lists.freebsd.org/pipermail/freebsd-hackers/2018-January/052096.html`, `052101.html` (doc0023, doc0024) | [D] | corrects 14B (see below) |
| The CPU selection is a compiler taint | Linus Torvalds, quoted in a reply: "Some of the issues end up just becoming compiler flags, which means that anything that uses C is 'tainted' by the processor choice"; Tim Wright: with the wrong processor type the kernel "may not even be able to complain" | Williams, Torvalds, Wright, Dec 2000 to 1 Jan 2001 | `lkml.iu.edu/hypermail/linux/kernel/0101.0/0086.html` (doc0029) | [D] | ch. 11: one pdp64 ISA level (no `-march` zoo) |
| `ioremap()` had no defined memory type | David Mosberger (HP): "I thought that ioremap() was being deprecated in favor of ioremap_nocache() because the former does not clearly define what kind of memory attribute will be used to access the mapped memory (cached, write-through cached, write-coalescing, etc)"; drivers such as `eepro100` spin on an `ioremap`ped read even though the region is not marked prefetchable, and "On an x86, what prevents these reads from being cached?" Alan Cox: "On x86 ioremap will give mappings appropriate to the object you map - which means by default it wil give uncached mappings. The PCI hardware will do intelligent things in certain cases such as write merging" | Mosberger, 3 Oct 2001; Cox, 4 Oct 2001 | `lkml.iu.edu/hypermail/linux/kernel/0110.0/0681.html`, `0878.html` (doc0081, doc0080) | [D] | ch. 7: the memory type is a page attribute stated by the mapper (`MT`), never inferred |
| Generic DMA indirection costs code | David S. Miller on a DMA-mapping API for Alpha: "This means device->ops->dma_*(), a level of indirection I wish terribly that we could avoid. If a driver is PCI or SBUS only it should not eat this overhead ... Doing all of this generic crap is nice for writing generic drivers, but terrible for what the generated code will look like. This kind of stuff tends to silently accumulate, and it's really hard to delete once it's there." (The 2018 retpoline cost of exactly this indirection is the LWN 774743 row above.) | Miller, 1 May 2003 | `lkml.iu.edu/hypermail/linux/kernel/0305.0/0201.html` (doc0097) | [D] | ch. 7: one DMA model, no ops table |
| The state-save area has no fixed layout | Michal Gorny, debugger support: "we can't rely on fixed offsets in XSAVE area (courtesy of CPUID data from AVX512 CPU)"; "The XSAVE area is dynamically sized, with controllable extensions to include. We need to perform a bunch of CPUID calls to determine the appropriate buffer size and offsets/sizes of individual data components inside it. The exact offsets depend on the processor in question"; for the raw interface used by Linux and FreeBSD, "both of those implementations did not account for providing component offsets via API, and so require userland to establish them manually by CPUID. This isn't going to work well for storing XSAVE data in coredumps." (The 15 replies were not read.) | Gorny, NetBSD tech-kern, 28 May 2019 | `mail-index.netbsd.org/tech-kern/2019/05/28/msg025062.html` (doc0053) | [D] | ch. 8: a fixed context layout, versioned, in the ISA document |
| Safe default for SMT | Theo de Raadt: "You can read up on the micro-architectural risks of the specific cpu you have, and your usage pattern, and make your own decision. I have machines where I enable it, but a safe default is the right choice for us to make." (OpenBSD runs with `hw.smt=0`; a user with 8 logical CPUs found 4 online) | de Raadt, openbsd-misc, 1 Feb 2023 | `marc.info/?l=openbsd-misc&m=167523371830534&w=1` (doc0071) | [D] | no SMT (C6) |
| Hardware quirks of 2001 | `lkml` Oct 2001: a user asks whether VIA says it is "OK to reprogram bit 55.1 of the host bridge, to fix the K7 optimizations" and reports lost-interrupt errors with the VIA IDE driver; thin, kept as a record of the pattern, not as a developer statement | Roberto Jung Drebes, 2 Oct 2001 | `lkml.iu.edu/hypermail/linux/kernel/0110.0/0436.html` (doc0078) | [D, thin] | boot.md |

### What round 3 changes in earlier text

* **Correction of a row in 14B.** The row "Secrets in non-cacheable memory as a Spectre countermeasure" (Eric McCorkle, freebsd-security, 4 Jan 2018) ended with "pdp64's `MT = 01` page attribute gives this with no new mechanism". Round 3 read the replies: Warner Losh answered the next day that the idea is "fatally flawed" (above), and the ZombieLoad paper later showed that data read from an uncacheable page still passes through the line-fill buffer and leaks. The `MT = 01` attribute is a device-memory attribute, **not** a Spectre or Meltdown countermeasure; the sentence in 14B should be read with this correction.
* **Hardware-vulnerabilities section 7 and 8.** The papers named as "to be fetched" in section 8 have now been read for Meltdown, Spectre, ZombieLoad, Foreshadow (project page), RIDL (project page), Retbleed (project page), Downfall (project page) and the Rowhammer exploit post; see the addition at the end of `hardware-vulnerabilities.md`.

### Counts for round 3

Computed from `round3-index.tsv` (host and `kind` columns) and from the rows above (final figures after the last fetches).

| Source type | Pages fetched | Pages marked "cited statement" |
|---|---:|---:|
| LWN articles (Wayback copies, 2019 and 2023 captures) | 21 | 19 (the timer-wheel and 2038 articles are routine for this study) |
| lore.kernel.org (messages, plus search and index pages) | 38 | 23 (the other 15 are search listings, a flat thread view, or messages read for context only) |
| lists.freebsd.org | 6 | 3 (the other 3 are thread indexes or a second message of one thread) |
| lkml.iu.edu | 11 | 5 (3 indexes; 3 posts read as context) |
| mail-index.netbsd.org | 9 | 1 (the rest are indexes, two 404s and an empty fetch) |
| marc.info (OpenBSD) | 4 | 1 (3 are search or month listings) |
| Papers and project pages (ar5iv x3, ETH, downfall.page, foreshadowattack.eu, mdsattacks.com, Project Zero) | 8 | 8 |
| **Total** | **98** (plus one fetch with no address) | **60** |

* **Pages fetched: 98** (97 plus one fetch that carried no address because of a mistake in my driver). Failed or empty: 5 (two 404s, that empty fetch, two lore searches with no results). Context pages (indexes, search listings, replies without content): 33.
* **Distinct threads or documents with a quoted statement:** 51 table rows above, each one pain; several rows combine more than one page (the PTI series cover and two replies, the Skylake RSB commit and five replies, the arm64 series, the RCU-on-Alpha thread). The number of separate quotations is higher than 51 (a row often has two to six), but they were **not counted one by one**, and no figure for "statements" is claimed beyond the 51 rows.
* **LWN rows are second-hand ([S]).** The 17 hardware-flaw rows are from first-hand papers, project pages or kernel mailing lists ([P] or [D]).
* This is **not 150**, and round 3 did not try to reach 150 by adding routine pages.

### Not done in round 3

* Not reached: KAISER's own paper, Hertzbleed and GoFetch (read from their project pages in round 2), the original Rowhammer paper by Kim et al. (the Project Zero post was read instead), Theo's slides and Bluhm's slides (PDF only), more NetBSD `port-vax`/`port-alpha`/`tech-smp` (the list indexes held little; the one thread tried returned an empty link set), FreeBSD months before 2018, the arm64 range-invalidate cover-letter timings, the full Skylake RSB thread beyond five messages, the per-process KPTI discussion, vDSO/TSC and MSI/GIC posts. They remain in `RESUME.md`.
* Unverified: anything in the statements above beyond the saved text. The rows say "paraphrase" where the source is a paraphrase by LWN.

## 15. What this means for pdp64

Ranked by the author's three principles. "Shows up as" says where the item appears in a kernel: recovery code (error paths and fix-ups), hot-path length (instructions on a path that runs constantly), or code size.

**Where the design wins (the pain does not arise).**

| Rank | What | Principle | Shows up as | Evidence in this document |
|---|---|---|---|---|
| 1 | Sequential consistency and natural alignment: no barrier vocabulary, no Alpha case, no split-lock atomics, no unaligned fix-up | (a), (b) | code size and recovery code: the ordering vocabulary is 5,596 Linux code lines in 855 files plus 3,016 lines of `memory-barriers.txt`; the alignment trap handler and `get_unaligned` family | chapters 6, 11 |
| 2 | Registers-only exception entry, banked `SP`/`DP`, `pushx`/`pushm`: entry cannot fault, no `swapgs`-like trick, 4 to 5 instruction entry | (b), (c) | hot-path length (45 to 70 instructions on RISC and x86) and recovery code (the paranoid entry path, the double-fault path) | chapter 3 |
| 3 | No FPU or vector state, no 32-bit mode, one byte order: lazy-FPU, `xsave`, signal-frame sizing, compat layer, endian helpers | (a), (b) | code size: `arch/x86/kernel/fpu` 4,364 lines, `compat` 591 code lines | chapters 8, 11 |
| 4 | Precise, restartable faults with no architectural effect, bounded fault matrix: no `backup()` | (b) | recovery code: V7's decode-the-instruction routine, ARM-style abort fix-ups | chapter 14 |
| 5 | Broadcast `TLBI` with `TLBSYNC`, ASIDs, `G` pages: no shootdown protocol, no switch flush | (b), (c) | recovery code (shootdown races) and hot-path length (switch) | chapter 5 |
| 6 | No speculation: none of the 4,164 lines of `hw-vuln` documents, no model blacklist | (a), (b) | code size and boot-time selection logic | chapter 4 |
| 7 | Coherent CPUs, uncached DMA mapping: no cache-maintenance hooks for DMA | (a), (b) | code size: 131 files mention the flush family | chapter 7 |

**Where it is exposed, ranked by what I think it will cost.**

| Rank | Exposure | Principle hurt | Shows up as | Pointer |
|---|---|---|---|---|
| 1 | **The single page-table base and kernel mapped in every address space, if the core ever speculates** (E38 keeps that door open) | (b), (c) | a PTI-style switch on every entry and exit: Linux's own documentation puts a `cr3` write at "on the order of a hundred cycles" at each entry and exit, and the engineer who wrote the patches reported "a few hundred cycles" per syscall or interrupt, about 5% typical and about 30% worst case (Hansen, 31 Oct 2017, section 14A, [D]); the design cost is a second base register now, versus a mitigation later | chapter 4; D6 |
| 2 | **Software accessed and dirty bits** | (c) | an extra fault per first touch and per first write of each page; Linux's arm64 default is hardware management to avoid it. Offsetting benefit: less recovery code, no walker writes | chapter 5; Q2 |
| 3 | **Uncached DMA buffers** | (c) | CPU reads of received data go to the bus; needs P6 the day a non-coherent bus master exists | chapter 7; P6, R5, R6 |
| 4 | **Machine check halts** | (b) in the broad sense | one uncorrectable memory error stops the system; Linux spends 7,111 lines on x86 alone to avoid that | chapter 13 |
| 5 | **Fault recovery in the copy routines has no mechanism yet** (exception table, `nofault` or probe) | (b) | the one place the kernel must have recovery code and the documents are silent | chapter 9 |
| 6 | **TLB invalidation granularity**: one page or all, no by-ASID, no range | (c) | N broadcasts to tear down a mapping; rollover handling | chapter 5; P5 |
| 7 | **Cross-modifying code and page-size changes have no rules** | (b) | iTLB-multihit-class and patching races | chapters 4, 12; E39 item 7 |
| 8 | **Lock scalability beyond 2 to 4 cores, interrupt controller, IPIs, virtualization, hardware breakpoints, performance counters** | all | not yet faced | R1, R2, R3, R8, P16 |
| 9 | **39-bit address space**: KASLR and ASLR entropy | security, not a principle | fewer bits to randomise | chapters 5, 12 |

**See also:** the rules that keep pdp64 free of the speculation and side-channel flaws are in [`hardware-vulnerabilities.md`](hardware-vulnerabilities.md); OpenBSD's mitigations against pdp64, with the improvements an OpenBSD developer would want, are in [`openbsd-mitigations.md`](openbsd-mitigations.md).

**Candidate actions suggested by the evidence** (none is decided; each cites the decision that would carry it): write the "visible only after `TLBI`" and the page-size-change rules into the ISA (E39 item 7) before any second core; decide whether a second page-table base is cheap enough to reserve now (chapter 4); state the cache-index-in-page-offset requirement for any future data cache; decide the fault-fixup mechanism for copies (chapter 9), because it is the only mandatory recovery code; keep P5 (by-ASID invalidate) and P1 (wake rule) on the list; keep hardware A/D management as a later option behind a feature register (P4) so that software can stay faulting-only if desired.

## 16. What this does not show

* **What we did to lwn.net.** The browser queue database records 68 completed lwn.net directives between 13:02 and 14:20 on 2026-10-22; 4 of them (13:02 to 13:03) belong to an earlier verification run and **64 are mine, from 14:07:07 to 14:20:40, 49 of them after the author's 14:10 pause** (they had been queued as one batch before the pause reached me, which was the wrong way to queue). Only 6 articles and the Kernel index returned real pages; the others returned the site's \"Blocked due to excessive requests\" page or failed after the browser window was closed. After the block, no request went to lwn.net; the LWN citations in this document are from those seven pages.
* **Message counts have false positives, and here is the biggest one found.** A first run of the commit-message mining matched `spectre` in laptop speaker-quirk commits (HP Spectre) and `mds` in PowerPC MDS evaluation-board commits; the expressions were tightened and the mining re-run (Appendix B.4, B.7). Other categories keep known noise (`mitigation` includes thermal mitigation, `poison` includes slab poisoning, `dma` includes graphics buffers). Treat counts as where words concentrate.
* **The history is partly missing.** The kernel.org `history.git` URL (meant for 1991 to 2005) holds the same 2005 to 2010 commits as the main repository and only 31 earlier ones, so Linux before 2005 has no commit-message data; the BSDs begin in 1993 to 1995. The mailing-list reading is a sample of about twenty primary pages, chosen by me, not a survey of thirty years of lists.
* **Round 2 is a sample chosen by queries, not a survey.** About 340 pages were fetched (319 unique URLs; the index is `round2-index.tsv`), selected as the first one to three distinct hits per query, so routine mail is included (206 of the pages are marked routine or context, 7 are failed pages). The statements in 14B and A.2 are those I read and judged to carry a cost, a decision or an admission; threads I did not read may contradict them. Some replies are quotations of others; the table names the author of the page that was read.
* **LWN was read only through archived copies.** Eight LWN articles came through the Wayback Machine (several of the archived 2024 captures were LWN's own "Blocked due to excessive requests" page, so an earlier year was used); the others in Appendix C are not fetched. Direct requests to lwn.net were never repeated after the block. archive.org returned 429 once on 22 October after about three requests and was paced at 45 to 60 seconds afterwards.
* **Old mailing lists are barely touched.** marc.info's search shows only the 30 newest hits, so it cannot reach mail before 2005; `lkml.iu.edu` (the Indiana University hypermail archive, 1996 to 2005) works, and 36 pages from twelve slices of it were read, chosen by subject keywords; they hold few statements about hardware cost. Nothing was read from the 1990s lists of the BSDs.
* **The OpenBSD list search is noisy.** marc.info body search returns recent mails that quote `dmesg` lines (so "meltdown" finds unrelated bug reports); 56 of the 81 OpenBSD pages are routine. The useful OpenBSD posts were found by following links from known ones.
* **Counts are vocabulary, not pain.** A word that appears often in current code or commit messages shows where developers talk about a thing, not how much it costs. "Race" and "deadlock" appear where fixes happened and where comments warn. The BSD kernels use different names for the same things (`membar_*`, `atomic_*`, `pmap_*`, `smr`), so cross-kernel comparisons of the barrier and RCU rows are not like-for-like.
* **The sample is partial.** The Linux sample has 91 directories: all `arch/` for eleven architectures, but `drivers` only for `irqchip` and `iommu`, and no `fs`. Categories dominated by drivers (DMA, interrupts, virtualization, MMIO) are undercounts. The BSD trees contain `sys/kern`, `sys/vm` or `uvm`, `sys/sys` and the listed architecture directories. Line counts use regular expressions over text, with no parsing; comments and code are not separated.
* **Current sources hide the past.** A workaround for hardware nobody sells any more has usually been deleted; the current tree shows pains still alive, not the ones that shaped design. The history is Phase 2 (commit messages, lists, articles).
* **No performance was measured.** All costs quoted are the developers' (documentation statements and, in Phase 2, list posts) or are path-length estimates from the survey; none was measured by me.
* **pdp64 verdicts are from documents.** There is no silicon, no SMP, no DMA devices, no interrupt controller and no kernel yet; "DESIGNED AWAY" means "cannot arise given the documented design", and several of those rest on the machine remaining in-order and non-speculative.
* **Memory is not evidence.** Items from memory (papers, who said what, dates) are marked unverified and listed in Appendix C until fetched.

## Appendix A: the pain-point catalogue

Columns: category; pain point; era (as far as the local evidence says, otherwise *from memory, unverified*); evidence with label; usual workaround; architectures that feel it most; pdp64 status; verdict. Decision identifiers refer to [`decisions-pending.md`](decisions-pending.md).

| # | Category | Pain point | Era | Evidence | Workaround | Architectures | pdp64 status | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | Entry | Page-table switch at every kernel entry and exit | 2018 on (unverified; Meltdown) | `pti.rst` "on the order of a hundred cycles" [G] | PCID, trampolines, deferred user flush | x86, some arm64 | one base, no PTI now | UNKNOWN (SAME PROBLEM if speculative) |
| 2 | Entry | Kernel base register swap (`swapgs`) must nest perfectly | x86-64 era | `entry_64.rst` [G] | cheap/expensive mode tests | x86-64 | banked `DP` | DESIGNED AWAY |
| 3 | Entry | Entry code must not be traced or breakpointed | 2010s (unverified) | `core-api/entry.rst` `noinstr` [G] | special sections | all | none needed | MITIGATED BY DESIGN |
| 4 | Entry | Register save/restore length | always | survey 8 (estimated) | multiple-register save | RISC, x86 | 4 to 5 instructions | MITIGATED BY DESIGN |
| 5 | Entry | Entry can fault (bad stack, double fault) | x86 | system design D1 [G] | task-state-segment stacks, IST | x86 | register-only entry | DESIGNED AWAY |
| 6 | Entry | Second exception overwrites saved state | PDP-era | E40 [G] | priority 7 on entry | pdp64 | decided | MITIGATED BY DESIGN |
| 7 | Speculation | Spectre v1/v2, Meltdown, SSB, L1TF, MDS, TAA, retbleed, SRSO ... | 2018 on (unverified) | `hw-vuln` 19 files, 4,164 lines; `bugs.c` 3,830 lines [P] | retpoline, IBRS, barriers, buffer clears, flushes | x86, arm64 | no speculation | DESIGNED AWAY (today) |
| 8 | Speculation | iTLB multihit on page-size change | 2019 (unverified) | `multihit.rst` [G] | no huge executable pages in guests | Intel | no rule yet | UNKNOWN |
| 9 | Speculation | Per-model vulnerability tables | 2018 on | 58-row blacklist, 45 bug flags [P] | CPU-model matching, `ARCH_CAPABILITIES` | x86 | feature registers P4 | UNKNOWN |
| 10 | TLB | Flush one page or all: no right threshold | long-standing | `tlb.rst`, ceiling 33 [G][P] | heuristic ceiling | x86 | `TLBI`/`TLBIA` | SAME PROBLEM (P5) |
| 11 | TLB | Remote shootdown by interprocessor interrupt | SMP era | `cachetlb.rst` [G]; NetBSD `pmap` code [P] | batching, `mm_cpumask` | x86, riscv | broadcast `TLBI` | DESIGNED AWAY |
| 12 | TLB | Context-switch flushes without tags; tag rollover | 1990s on | `pti.rst` PCID [G] | ASID/PCID | most | 16-bit ASID | MITIGATED BY DESIGN |
| 13 | TLB | Software-managed refill (MIPS, SPARC, PA-RISC) | RISC era | `tlb-refill` 146 Linux lines [P] | refill handlers in assembly | MIPS, others | hardware walker | DESIGNED AWAY |
| 14 | MM | Software accessed/dirty bits cost a fault | VAX era to now | 3BSD `vmpage.c` [P]; `ARM64_HW_AFDBM` [P] | hardware A/D where present | arm64, riscv | software A/D (Q2) | WORSE (c), better (b) |
| 15 | MM | Page-table walk cost, depth | always | `pagetable` 11,543 lines [P] | huge pages, caches of walks | x86, arm64 | 3 levels | MITIGATED BY DESIGN |
| 16 | MM | Huge pages, NUMA balancing | 2010s (unverified) | `mm/huge_memory.c` 5,202 lines [P] | THP, migration | x86 | 2 MB/1 GB leaves; no NUMA | UNKNOWN |
| 17 | MM | `mmap` lock contention | 2010s (unverified) | `mmap_lock` vocabulary 451 lines [P] | per-VMA locks | Linux | not faced | UNKNOWN |
| 18 | MM | Address-space size and ASLR entropy | 2000s on | design D6 [G] | five-level paging | all | 39 bits | WORSE |
| 19 | Ordering | Weak memory models need barriers | 1990s on | `memory-barriers.txt` 3,016 lines; 5,596 code lines [P] | `smp_*`, `READ_ONCE` | arm, power, riscv, alpha | SC | DESIGNED AWAY |
| 20 | Ordering | Alpha dependent-load reordering | late 1990s | `RCU/Design/Requirements`, `memory-barriers.txt` [G] | `rcu_dereference`, barrier in `READ_ONCE` | alpha | none | DESIGNED AWAY |
| 21 | Ordering | MMIO/doorbell ordering, write combining | 1990s on | `mmio-ordering` 1,609 lines [P] | `wmb`, `mmiowb`, readback | all | `FENCE`, strongly ordered `MT` | MITIGATED BY DESIGN |
| 22 | Atomics | LL/SC livelock, reservation granule | RISC era | E45 [G] | constrained sequences | arm, mips, power, riscv | forward-progress rule | MITIGATED BY DESIGN |
| 23 | Atomics | Split-lock atomics freeze the bus | 2010s (unverified) | `buslock.rst` [G] | detect and kill | x86 | aligned only | DESIGNED AWAY |
| 24 | Atomics | No atomic instruction on old CPUs | 1990s | `swp_emulation.rst`, `kernel_user_helpers.rst`, `vlocks.rst` [G] | emulation, kernel helpers | arm | has atomics | DESIGNED AWAY |
| 25 | Locks | Test-and-set to ticket to queued locks | 2000s to 2010s (unverified) | `qspinlock.c` [P]; 1,464 lines [P] | MCS queues | x86, all | not yet faced | UNKNOWN (R3) |
| 26 | Locks | Lock-order and race debugging | always | `lockdep` 410 lines [P] | lockdep | all | none | SAME PROBLEM |
| 27 | Locks | Interrupt disable cost | always | `spinlocks.rst` [G] | irq-free lock variants | x86 and others | `SPL` | MITIGATED BY DESIGN |
| 28 | RCU | Reader-side cost and ordering | 1990s on | `Documentation/RCU` 36,800 lines [P] | RCU | all | SC makes simpler | SAME PROBLEM, easier |
| 29 | Cache | Virtual-cache aliasing | 1990s RISC | `cachetlb.rst` [G]; mips 352, arm 272 lines [P] | flush hooks, colouring | arm, mips, sparc, parisc | undefined | UNKNOWN |
| 30 | Cache | I-cache coherence after code writes | always | `cmodx.rst` [G] | `fence.i`, `ic ivau` | riscv, arm, power | `ICINV`+`ISYNC` | SAME PROBLEM |
| 31 | Cache/DMA | Non-coherent DMA | 1990s on | `dma-api.rst` Part II [G] | sync calls, uncached, bounce | arm, mips, riscv | uncached DMA mapping | DESIGNED AWAY (for now) |
| 32 | DMA | Device cannot address all memory | 1990s on | `swiotlb.rst` [G] | bounce buffers, IOMMU | x86, arm | R6 | UNKNOWN |
| 33 | DMA | Mapping registers and buffered data paths | VAX era | 3BSD `uba.c` [P] | map-register allocation | VAX | none | UNKNOWN (R6) |
| 34 | State | FPU lazy/eager save, `xsave` sizing | 1990s to 2018 | `xstate.rst`, `floating-point.rst` [G] | eager save | x86, arm | no FPU state | DESIGNED AWAY (S4 risk) |
| 35 | State | Per-CPU data access | SMP era | `this_cpu_ops.rst` [G]; 3,225 uses [P] | segment/thread register | all | `DP` | DESIGNED AWAY |
| 36 | User memory | Kernel reads user memory by mistake | 2010s | survey 7, D11 | SMAP/PAN/SUM | x86, arm64, riscv | `UA` (E43) | MITIGATED BY DESIGN |
| 37 | User memory | Faults inside copy routines | always | `exception-tables.rst` [G]; 260 uses [P] | fixup tables | all | progress in registers; mechanism undefined | UNKNOWN |
| 38 | Interrupts | Controller programming, EOI, routing, MSI | always | `interrupts` 4,787 lines [P] | APIC/GIC drivers | x86, arm | R1 | UNKNOWN |
| 39 | Interrupts | Lost wake-up in idle loop | PDP era | V7 `m40.s` `idle` [P] | `sti;hlt` shadow, `wfi` rules | all | P1 | UNKNOWN |
| 40 | Time | Cheap reliable clock from user mode | 2000s | `timekeeping` 1,903 lines [P] | vDSO, TSC | x86, arm | P3 | UNKNOWN |
| 41 | Time | 32-bit `time_t` | 2010s | `y2038` 485 lines [P] | 64-bit time ABI | 32-bit | 64-bit | DESIGNED AWAY |
| 42 | Bytes | Unaligned access | always | `unaligned-memory-access.rst`, `mem_alignment.rst` [G] | accessors, traps | arm, mips, sparc, alpha | required, `MOVU*` | DESIGNED AWAY |
| 43 | Bytes | Endianness | always | 1,793 lines + 976 doc lines [P] | conversion macros | mixed-endian | little only | DESIGNED AWAY |
| 44 | Bytes | 32-bit compatibility layer | 2000s | `compat` 591 lines [P] | translation layer | x86, arm64, mips | none | DESIGNED AWAY |
| 45 | Patching | Atomic patch of multi-instruction calls | 2000s on | `cmodx.rst`, `kprobes.rst` [G] | breakpoint protocol, `stop_machine` | riscv, x86 | `BPT` 2 bytes | MITIGATED BY DESIGN |
| 46 | Patching | Cross-modifying code on other cores | always | readiness 6.11 [G] | IPI + sync | all | no rule | UNKNOWN |
| 47 | Hardening | CFI, shadow stack, PAC, KASLR | 2010s | `hardening` 1,709 lines [P] | compiler + hardware | x86, arm64 | landing pad only | MITIGATED (forward), SAME (backward) |
| 48 | Hardware | Silicon errata | always | 110 Kconfig errata options; 145 errata rows [P] | workaround per core | arm64, arm, x86 | no silicon | UNKNOWN |
| 49 | Hardware | Uncorrectable memory errors | 2000s | `mce` 7,111 lines [P] | poison, kill the owner | x86, power | halt | WORSE |
| 50 | Virt | Nested paging walk, VM entry flushes | 2000s | `l1tf.rst` [G] | huge pages, flush control | x86, arm64 | none | UNKNOWN (R8) |
| 51 | Fast paths | Batching, polling, zero copy | 2000s on | `net-storage-fastpath` 1,462 lines [P] | NAPI, rings | all | R5 | UNKNOWN |
| 52 | Power | Idle states, tick | 2000s | `idle-power` 1,168 lines [P] | cpuidle, NO_HZ | all | `WFE` | UNKNOWN |
| 53 | Debug | Hardware breakpoints, tracing | always | `tracing-patching` 2,867 lines [P] | debug registers | all | `T` bit, `BPT` | UNKNOWN |

Eras marked unverified are from memory and are Phase 2 questions (lists and LWN dated posts).


### A.2 Additions from round 2

Same columns as the table above. Evidence is in section 14B (statements) and `docs/codegen-data/kernelpain/round2-index.tsv`.

| # | Category | Pain point | Era | Evidence | Workaround | Architectures | pdp64 status | Verdict |
|---|---|---|---|---|---|---|---|---|
| 54 | Entry | A fast system-call path stops paying once entry has defences | 2018 | Lutomirski, 28 Jan 2018: "Just get rid of the fast path. The slow path is barely slower." [D] | remove it | x86-64 | no fast path past the vector fetch (D3) | MITIGATED BY DESIGN |
| 55 | Speculation | The mitigation code must not itself speculate (IBRS/IBPB writes) | 2018 | Zijlstra, 18 Jan 2018 [D] | static keys, objtool checks, no `lfence` in the off path | x86 | no speculation | DESIGNED AWAY (today) |
| 56 | Speculation | A software substitute for a return predictor: call-depth tracking | 2022 | Gleixner, 17 Jul 2022: 1.8 MB thunks, 16 bytes per function, ITLB misses [D] | patch every call | Intel Skylake-class | no return predictor | DESIGNED AWAY (today) |
| 57 | Speculation | Mitigation selection and reporting become their own subsystem | 2018 to 2025 | Kaplan 2025 (attack vector controls), Poimboeuf 2023 (SRSO reported "mitigated" wrongly) [D] | command-line knobs, sysfs reports | x86 | feature registers (P4) | UNKNOWN |
| 58 | Speculation | Firmware calls are outside the compiler mitigation | 2018 | Woodhouse, 14 Feb 2018 [D] | IBRS around firmware calls | x86 | firmware-call convention (P7) | UNKNOWN |
| 59 | TLB | Nobody can explain the flush heuristic | 2014 | Hansen, 2014 [D] | a ceiling tunable | x86 | `TLBI`/`TLBIA` | SAME PROBLEM (P5) |
| 60 | TLB | Remote flush interrupts: 900K per second against 180K | 2015 | Gorman, 6 Jul 2015, measured [D] | batch, full flush | all SMP | broadcast `TLBI` | DESIGNED AWAY (the interrupt) |
| 61 | TLB | A shootdown for every file-system block | 2018 | Dolecek, 24 Mar 2018 [D] | lazy kernel pmap | NetBSD | broadcast per unmap | MITIGATED BY DESIGN |
| 62 | TLB | Address-space tags are hashed and the switch is scheduler-bound | 2016 | Lutomirski and Torvalds, 8 Jan 2016 [D] | PCID | x86 | 16-bit ASID | MITIGATED BY DESIGN |
| 63 | MM | The mmap lock is 0.5% of cycles in one hot path | 2023 | Baghdasaryan, 27 Feb 2023 [D] | per-VMA locks | Linux | not faced | UNKNOWN |
| 64 | MM | NUMA balancing needed 63 patches | 2013 | Gorman, 2013 [D] | scan-rate reduction | NUMA | no NUMA | DESIGNED AWAY |
| 65 | Locks | A fair queued read/write lock took nine versions | 2013 to 2014 | Long [D] | qrwlock | all SMP | not faced | UNKNOWN (R3) |
| 66 | RCU | Expedited grace periods trade latency for CPU cost | 2015 | McKenney, 30 Jun 2015: "not clear whether this is a useful tradeoff" [D] | normal vs expedited | all | SC makes it easier | SAME PROBLEM |
| 67 | Compiler | The compiler broke the ordering primitive | 2014 | Borntraeger, 2014 [D] | `READ_ONCE` | all | SC does not stop the compiler | SAME PROBLEM |
| 68 | Locks | A mitigation (`pinsyscalls`) had a publication race | 2025 | Guzik, 23 Feb 2025 [D] | memory fences | OpenBSD | SC | DESIGNED AWAY |
| 69 | DMA | IOMMU map/unmap can cost more than a copy | 2021 | Stevens, 6 Aug 2021: 2.8x to 4.7x with bounce buffers [D] | bounce pools | virtualized x86 | R6 | UNKNOWN |
| 70 | DMA | Encrypted guests need bounce buffers | 2019 | Roedel, 10 Jan 2019 [D] | SWIOTLB | AMD SEV, IBM | none | UNKNOWN |
| 71 | MM | Pre-zeroed pages lose to zeroing at allocation | 2025 | Kettenis, 22 Dec 2025 [D] | `rep stosb` at allocation | amd64 | `MSET` | MITIGATED BY DESIGN |
| 72 | Hardening | Full stack protector cost too much for a distribution | 2009 | Jones, 15 Oct 2009 [D] | strong/selective protector | x86 | return address on data stack | SAME PROBLEM |
| 73 | Hardening | KASLR broke kdump, kexec, netboot | 2016 | Cook, 14 Apr 2016 [D] | cleanup series | x86 | PC-relative kernel | UNKNOWN |
| 74 | Hardening | The user-access guard has a measured cost and a code-generation cost | 2012, 2016, 2025 | HPA 2012, Cook 2016, Poimboeuf 2025 [D] | `stac`/`clac` | x86 | `stua`/`clua` | MITIGATED BY DESIGN |
| 75 | Hardening | Execute-only text breaks code that reads its own `.text` | 2024 | Jeker and Guenther, Jul 2024 [D] | `.rodata` | OpenBSD | literal pool in `.text` (errata 33) | WORSE (exposure) |
| 76 | Boot | A firmware quirk per machine, found by test and wait | 2010 to 2016 | Delvare 2010, Tang 2012, Dang 2016 [D] | quirk tables | x86, Arm | boot.md | UNKNOWN |
| 77 | Boot | BIOS and kernel disagree about the interrupt mode | 2015 | Liu, 7 Jan 2015 [D] | panic with a message | x86 | one defined handoff state | UNKNOWN |
| 78 | Boot | Starting the other cores is a polling loop | 2015 | Brown, 16 Aug 2015: about 305 to 405 us per core [D] | remove the delay | x86 | `SEV` release (ISA 17.4) | MITIGATED BY DESIGN |
| 79 | Time | A 32-bit vDSO needed 23 versions of type hacking | 2014 | Seibold [D] | compat types | x86 | LP64 only | DESIGNED AWAY |
| 80 | Time | Constant-time is off by default on Intel and cost is unpublished | 2022 to 2026 | Biggers 2023, Cooper 2026 [D]; Intel guidance [G] | DOITM always on | x86 | `DIT` bit in `PSW` (P17) | UNKNOWN |
| 81 | Hardware | The OS must check minimum microcode versions | 2025 | Bluhm, Gray, Oct 2025 [D] | microcode packages | x86 | feature registers | UNKNOWN |
| 82 | Hardware | Recovery from memory errors depends on the exact CPU model | 2016 | Luck, 30 Aug 2016 [D] | PCI quirk tables | Intel Xeon | feature registers (P4) | UNKNOWN |

### A.3 Additions from round 3

Same columns. Evidence is in section 14D and `docs/codegen-data/kernelpain/round3-index.tsv`.

| # | Category | Pain point | Era | Evidence | Workaround | Architectures | pdp64 status | Verdict |
|---|---|---|---|---|---|---|---|---|
| 83 | Speculation | The ISA did not say what a mispredicted path may leave behind, so no code could be proved safe | 2018 | Kocher et al., Spectre paper sec. 7-8: "there is currently no way to know whether a particular code construction is, or is not, safe" [P] | fences, masking, retpoline | x86, Arm, others | no speculation; C13 states it | DESIGNED AWAY (today) |
| 84 | Speculation | A serializing instruction whose speculation behaviour was undefined (`lfence`) | 2018 | Spectre paper; Intel to revise `lfence` [P] | revised definition | x86 | no speculation | DESIGNED AWAY (today) |
| 85 | Permission | Permission check after the data returns (Meltdown); authors propose privilege derived from the address | 2018 | Meltdown paper sec. 7 [P] | page-table isolation | Intel | check before data (C1) | UNKNOWN (address layout to be checked) |
| 86 | Buffers | Fill buffers leak across privilege changes; L1 flush plus load stuffing not enough | 2019 | ZombieLoad sec. on mitigations [P] | microcode buffer clear, `VERW` | Intel | no buffers; C5 | DESIGNED AWAY (today) |
| 87 | Buffers | Uncacheable memory still leaks through the fill buffer | 2018-2019 | ZombieLoad; Losh, 5 Jan 2018 [P][D] | none | Intel | `MT = 01` is not a defence | SAME PROBLEM |
| 88 | Process | The MDS fix was incomplete and the embargo was extended at the last minute | 2018-2020 | VUSec, mdsattacks.com [P] | second and third microcode | Intel | publish state that leaves a privilege boundary (C13) | UNKNOWN |
| 89 | Speculation | Foreshadow bypassed KPTI, retpoline, IBRS, STIBP and IBPB | 2018 | foreshadowattack.eu [P] | L1 flush on VM entry, microcode | Intel | no L1-resident forwarding | DESIGNED AWAY (today) |
| 90 | Vector | Gather leaks the vector register file; up to 50% overhead for the fix | 2022-2023 | downfall.page [P] | microcode blocking gather results | Intel 6th-11th gen | no gather in the documented base; C14 | UNKNOWN |
| 91 | Returns | Returns predicted as indirect branches; Retbleed fix 14% to 39%, 68 files | 2022 | comsec.ethz.ch Retbleed [P] | IBRS, call-depth tracking (14B) | AMD Zen 1-2, Intel Core 6-8 | no return predictor today (C2) | DESIGNED AWAY (today) |
| 92 | Memory | Unprivileged `CLFLUSH` cannot be intercepted; Rowhammer exploit with page-table bit flips | 2015 | Project Zero, 9 Mar 2015 [P] | NaCl validator change, refresh rate | x86-64 | no unprivileged flush (suggestion) | UNKNOWN |
| 93 | ISA | The OS had to ask for an architectural capability bit instead of keeping a model list | 2018 | Torvalds, 29 Jan 2018 [D]; Woodhouse commit, 14 Jan 2018: `is_skylake_era()` [D] | list of five models | Intel | feature registers (P4) | UNKNOWN |
| 94 | Policy | Refusal of tunables vs the many-knob outcome | 2018 | Woodhouse, 15 Jan 2018 [D] | `spectre_v2=off` only | x86 | fewer modes | UNKNOWN |
| 95 | MM | Shared kernel mappings lost the global bit under PTI; +38.8% on an Atom without PCID | 2018 | Hansen, 3 Apr 2018 [D] | `_PAGE_GLOBAL` for entry text | x86 | 16-bit ASID | MITIGATED BY DESIGN |
| 96 | MM | Remote TLB shootdown window violates lock-protected reads in practice | 2018 | Rabe, freebsd-hackers, 10 Feb 2018 [D] | two-stage pmap update | x86-64 | single-core first system | DESIGNED AWAY (today) |
| 97 | MM | THP and EPT: a kernel build is 4% slower without huge pages and 260% slower in a guest without nested paging | 2010 | Arcangeli, 3 Aug 2010 [D] | THP, EPT | x86 | no virtualization | DESIGNED AWAY (today) |
| 98 | ISA | A new instruction needs binutils support; the series was applied, dropped and merged in five days | 2020 | Marinas, 13 Jul 2020 [D] | hand-encoded instruction macros (proposed) | arm64 | assembler ships with the ISA | MITIGATED BY DESIGN |
| 99 | Atomics | RISC-V qspinlock needed the Zacas (compare-and-swap) and Zabha (byte and halfword atomics) extensions, so the base lacked them (inferred from the series) | 2024 | Ghiti, 28 May 2024 [D] | LR/SC loops | RISC-V | `CAS`, `XADD` in base | MITIGATED BY DESIGN |
| 100 | Atomics | Atomic across two cache lines locks the whole bus | 2019 | Yu, split-lock cover letter via LWN [S] | #AC on split lock | x86 | misaligned atomic should trap (suggestion) | UNKNOWN |
| 101 | Atomics | Emulated unaligned `LL/SC` cannot be atomic | 2025 | Torvalds, 19 Feb 2025 [D] | do not emulate in the kernel | Alpha | trap, no emulation (suggestion) | UNKNOWN |
| 102 | Alignment | Unaligned user pointers did not work on Alpha and sparc64; trap handler faulted | 2019 | Torvalds, 6 Oct 2019 [D] | fix the arch handlers | Alpha, sparc64 | one policy in hardware | UNKNOWN |
| 103 | Time | The TSC is not reliable: SMI adjustments, cross-core offsets, thermal drift; 500+ timer variants | 2010 | Gleixner, via LWN 19 May 2010 [S] | trap and emulate `RDTSC` proposals | x86 | one defined counter (suggestion) | UNKNOWN |
| 104 | State | XSAVE area has no fixed layout; CPUID needed to find offsets | 2019 | Gorny, 28 May 2019 [D] | versioned normalised struct | x86 | fixed layout (suggestion) | UNKNOWN |
| 105 | Policy | SMT off by default as the safe choice | 2023 | de Raadt, 1 Feb 2023 [D] | `hw.smt=0` | x86 | no SMT (C6) | DESIGNED AWAY |
| 106 | MM | A page-table bit combination used by Linux for COW was claimed by hardware for shadow stacks | 2022 | LWN 21 Feb 2022 [S] | `_PAGE_COW` software bit | x86 | give new page types their own bit (suggestion) | UNKNOWN |
| 107 | Memory type | `ioremap()` memory type undefined, drivers relied on x86 defaults | 2001 | Mosberger, 3 Oct 2001 [D] | `ioremap_nocache` | ia64 vs x86 | `MT` attribute set by the mapper | MITIGATED BY DESIGN |
| 108 | Machine check | Poison errors reported after the faulting instruction and process are unknowable | 2009 | LWN 26 Aug 2009 [S] | page-level containment | x86 | precise machine check (suggestion) | UNKNOWN |
| 109 | Ordering | Dependent loads need a barrier only on Alpha; an array index of 0 defeats the NULL shortcut | 2008 | McKenney, 21 Jun 2008 [D] | `smp_read_barrier_depends` in `rcu_dereference` | Alpha | sequentially consistent by declaration (ISA 17.1) | DESIGNED AWAY (by declaration) |
| 110 | DMA | A generic DMA ops table is overhead that "silently accumulates" | 2003 | Miller, 1 May 2003 [D] | direct pci_*/sbus_* calls | all | one DMA model (suggestion) | UNKNOWN |


## Appendix B: the counts, the method and the commands

### B.1 The trees used (measurement 1: the current sources)

Shallow, sparse checkouts under `~/claude/kernel-src` (not in this repository), read in place. Which directories are present is recorded in `docs/codegen-data/kernelpain/trees.csv` (`python3 tools/kernelpain.py trees`).

| Tree | Commit | Date | Sparse directories |
|---|---|---|---:|
| linux | `7be4bc52fd9e0e55dc9a2e0232b89427d2c4b614` | 2026-10-21 | 91 |
| freebsd | `3200a274272d28cf6d2385a8ea46959f313866de` | 2026-10-22 | 12 |
| netbsd | `cdcd52a8183344cabc6a4296b4bbe7e7c5fd3cdc` | 2026-10-21 | 32 |
| openbsd | `2114d7b7c8fbfd8d285dd7b5b5eb44e1f6b70f55` | 2026-10-22 | 18 |

Directories added for this study, one tree at a time: Linux `Documentation mm kernel include/linux include/asm-generic block net/core drivers/irqchip drivers/iommu virt lib`; the BSDs `sys/kern`, `sys/vm` or `sys/uvm`, `sys/sys`, `share/man/man9`.

### B.2 The method

`python3 tools/kernelpain.py grep` runs, for every category in B.4 and every tree, `nice -n 10 grep -rPIc [-i] --exclude-dir=.git -e <regex> .` in the tree root. Each output line is a file and the number of its lines that match. A file's area is its architecture directory (`arch/<family>`, with `i386`, `x86_64`, `amd64` merged into `x86`, `ppc`/`ppc64` into `powerpc`, `sparc64` into `sparc`, and so on, table `ARCH_FAMILY` in the script) or its top-level subsystem directory; its kind is `doc` (under `Documentation/`, in a `man` directory, or ending `.rst .txt .md .9`), `kconfig` (name starting `Kconfig`) or `code` (`.c .h .S .s .rs .asm .inc`). Line counts of code per area come from reading every such file (`totals.csv`). Output: `counts.csv` (tree, category, area, kind, files, lines) and `totals.csv`. `python3 tools/kernelpain.py structural` runs the named commands of B.3. `python3 tools/kernelpain.py report` prints the tables of B.5.

### B.3 Structural measures, with the exact command for each

All measured on the trees of B.1; the value is what the command printed on 2026-10-22. **[P]**

| Id | Tree | What | Value | Exact command (run in the tree root) |
|---|---|---|---:|---|
| `kconfig-erratum-arm64` | linux | Kconfig options named *ERRATUM/ERRATA in arch/arm64/Kconfig | 64 | `grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/arm64/Kconfig` |
| `kconfig-erratum-arm` | linux | Kconfig options named *ERRATUM/ERRATA in arch/arm (Kconfig and mm/Kconfig) | 32 | `grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/arm/Kconfig arch/arm/mm/Kconfig \| awk -F: '{s+=$NF} END{print s}'` |
| `kconfig-erratum-riscv` | linux | Kconfig options named *ERRATUM/ERRATA in arch/riscv/Kconfig.errata | 14 | `grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/riscv/Kconfig.errata` |
| `kconfig-erratum-all-arch` | linux | Kconfig options named *ERRATUM/ERRATA anywhere under arch | 110 | `grep -rh '^config .*ERRATUM\\|^config .*ERRATA' arch --include='Kconfig*' \| wc -l` |
| `x86-bug-flags` | linux | X86_BUG_* bug flags defined | 45 | `grep -c 'define X86_BUG_' arch/x86/include/asm/cpufeatures.h` |
| `x86-vuln-blacklist` | linux | CPU model rows in the vulnerability blacklist (VULNBL_*) | 58 | `grep -cE '^\s*VULNBL_' arch/x86/kernel/cpu/common.c` |
| `x86-bugs-c-lines` | linux | lines of arch/x86/kernel/cpu/bugs.c (mitigation selection) | 3830 | `wc -l < arch/x86/kernel/cpu/bugs.c` |
| `x86-mitigation-kconfig` | linux | MITIGATION_* Kconfig options in arch/x86/Kconfig | 24 | `grep -c 'config MITIGATION_' arch/x86/Kconfig` |
| `hw-vuln-docs` | linux | files in Documentation/admin-guide/hw-vuln | 19 | `ls Documentation/admin-guide/hw-vuln \| wc -l` |
| `hw-vuln-doc-lines` | linux | lines in Documentation/admin-guide/hw-vuln | 4164 | `cat Documentation/admin-guide/hw-vuln/*.rst \| wc -l` |
| `arm64-errata-kconfig` | linux | ARM64_ERRATUM_* Kconfig options | 41 | `grep -c 'config ARM64_ERRATUM_' arch/arm64/Kconfig` |
| `arm64-workaround-caps` | linux | ARM64_WORKAROUND_* capabilities in the capability table | 41 | `grep -cE '^WORKAROUND_' arch/arm64/tools/cpucaps` |
| `arm64-silicon-errata-rows` | linux | rows of Documentation/arch/arm64/silicon-errata.rst naming an erratum | 145 | `grep -cE '^\\| [A-Za-z].*(#\|ID\|errata\|Erratum\|[0-9]{5,})' Documentation/arch/arm64/silicon-errata.rst` |
| `memory-barriers-lines` | linux | lines of Documentation/memory-barriers.txt | 3016 | `wc -l < Documentation/memory-barriers.txt` |
| `rcu-doc-lines` | linux | lines under Documentation/RCU | 36824 | `find Documentation/RCU -type f \| xargs cat \| wc -l` |
| `locking-doc-lines` | linux | lines under Documentation/locking | 4554 | `find Documentation/locking -type f \| xargs cat \| wc -l` |
| `kernel-parameters-mitigation-lines` | linux | lines of kernel-parameters.txt mentioning mitigat/spectre/retbleed/l1tf/mds | 177 | `grep -ciE 'mitigat\|spectre\|retbleed\|l1tf\|mds\|srbds\|ssb' Documentation/admin-guide/kernel-parameters.txt` |
| `extable-uses-x86` | linux | exception-table annotations in arch/x86 (_ASM_EXTABLE*, EX_TYPE_*) | 260 | `grep -rhE '_ASM_EXTABLE\|EX_TYPE_' arch/x86 \| wc -l` |
| `arch-flush-tlb-defs` | linux | files under arch/*/include and arch/*/mm mentioning flush_tlb_ | 189 | `grep -rlE 'flush_tlb_' arch \| wc -l` |
| `arch-cache-flush-defs` | linux | files under arch mentioning flush_dcache_page, flush_cache_, flush_icache_ | 131 | `grep -rlE 'flush_dcache_page\|flush_cache_(mm\|range\|page)\|flush_icache_' arch \| wc -l` |
| `arm-lines-vivt-alias` | linux | lines in arch/arm mentioning aliasing/VIVT/VIPT | 179 | `grep -rciE 'aliasing\|vivt\|vipt' arch/arm \| awk -F: '{s+=$NF} END{print s}'` |
| `this-cpu-uses` | linux | this_cpu_/__this_cpu_/per_cpu( uses in kernel, mm, arch | 3225 | `grep -rhE 'this_cpu_\|per_cpu\(\|raw_cpu_' kernel mm arch \| wc -l` |
| `rcu-api-uses` | linux | rcu_read_lock/rcu_dereference/call_rcu uses in kernel and mm | 2113 | `grep -rhE 'rcu_read_lock\|rcu_dereference\|call_rcu\|synchronize_rcu' kernel mm \| wc -l` |
| `readonce-uses` | linux | READ_ONCE/WRITE_ONCE uses in kernel and mm | 2128 | `grep -rhE 'READ_ONCE\|WRITE_ONCE' kernel mm \| wc -l` |
| `smp-barrier-uses` | linux | smp_mb/rmb/wmb/load_acquire/store_release uses in kernel, mm and arch | 1146 | `grep -rhE 'smp_(mb\|rmb\|wmb\|load_acquire\|store_release)' kernel mm arch \| wc -l` |
| `spinlock-uses` | linux | spin_lock* calls in kernel and mm | 1965 | `grep -rhE 'spin_lock' kernel mm \| wc -l` |
| `alt-instr-x86` | linux | ALTERNATIVE/alternative_ uses in arch/x86 (boot-time patching) | 177 | `grep -rhE 'ALTERNATIVE\|alternative_' arch/x86 \| wc -l` |
| `static-key-uses` | linux | static_branch_/DEFINE_STATIC_KEY uses in kernel, mm, arch | 725 | `grep -rhE 'static_branch_\|DEFINE_STATIC_KEY' kernel mm arch \| wc -l` |
| `compat-lines` | linux | lines mentioning compat_ in kernel and mm | 539 | `grep -rhE 'compat_\|COMPAT' kernel mm \| wc -l` |
| `lines-kernel-rcu` | linux | lines of C in kernel/rcu | 26786 | `cat kernel/rcu/*.c kernel/rcu/*.h \| wc -l` |
| `lines-kernel-locking` | linux | lines of C in kernel/locking | 21181 | `cat kernel/locking/*.c kernel/locking/*.h \| wc -l` |
| `lines-kernel-sched` | linux | lines of C in kernel/sched | 56661 | `cat kernel/sched/*.c kernel/sched/*.h \| wc -l` |
| `lines-x86-fpu` | linux | lines of C in arch/x86/kernel/fpu | 4364 | `cat arch/x86/kernel/fpu/*.c \| wc -l` |
| `lines-x86-entry` | linux | lines in arch/x86/entry (assembly and C) | 4239 | `cat arch/x86/entry/*.S arch/x86/entry/*.c \| wc -l` |
| `lines-x86-microcode` | linux | lines of C in arch/x86/kernel/cpu/microcode | 3839 | `cat arch/x86/kernel/cpu/microcode/*.c \| wc -l` |
| `lines-x86-mce` | linux | lines of C in arch/x86/kernel/cpu/mce (machine checks) | 7111 | `cat arch/x86/kernel/cpu/mce/*.c \| wc -l` |
| `lines-x86-retpoline` | linux | lines of arch/x86/lib/retpoline.S | 474 | `wc -l < arch/x86/lib/retpoline.S` |
| `lines-mm-total` | linux | lines of C in mm | 193507 | `cat mm/*.c \| wc -l` |
| `lines-mm-huge-memory` | linux | lines of mm/huge_memory.c (transparent huge pages) | 5202 | `wc -l < mm/huge_memory.c` |
| `lines-mm-tlb-ops` | linux | lines of mm/mmu_gather.c and mm/mmu_notifier.c | 1701 | `cat mm/mmu_gather.c mm/mmu_notifier.c \| wc -l` |
| `files-arch-cache-tlb` | linux | files named *cache* or *tlb* under arch/*/mm and arch/*/kernel | 80 | `find arch -path '*/mm/*' -o -path '*/kernel/*' \| grep -iE '(cache\|tlb)[^/]*\.(c\|S)$' \| wc -l` |
| `lines-arch-cache-tlb` | linux | lines in those files | 26826 | `find arch -path '*/mm/*' -o -path '*/kernel/*' \| grep -iE '(cache\|tlb)[^/]*\.(c\|S)$' \| xargs cat \| wc -l` |
| `lines-arm64-cpu-errata` | linux | lines of arch/arm64/kernel/cpu_errata.c | 1088 | `wc -l < arch/arm64/kernel/cpu_errata.c` |
| `lines-arm64-proton-spectre` | linux | lines of arch/arm64/kernel/proton-pack.c (Spectre/BHB mitigations) | 1213 | `wc -l < arch/arm64/kernel/proton-pack.c` |
| `lines-bsd-openbsd-pmap-amd64` | openbsd | lines of sys/arch/amd64/amd64/pmap.c | 3482 | `wc -l < sys/arch/amd64/amd64/pmap.c` |
| `lines-freebsd-pmap-amd64` | freebsd | lines of sys/amd64/amd64/pmap.c | 12372 | `wc -l < sys/amd64/amd64/pmap.c` |
| `lines-netbsd-pmap-x86` | netbsd | lines of sys/arch/x86/x86/pmap.c | 6924 | `wc -l < sys/arch/x86/x86/pmap.c` |
| `fb-cpu-features-bugs` | freebsd | lines in x86 cpu setup mentioning errata/workaround | 103 | `grep -rhiE 'errat\|workaround' sys/x86 sys/amd64 \| wc -l` |
| `fb-arm64-errata` | freebsd | lines in sys/arm64 mentioning errat/workaround | 199 | `grep -rhiE 'errat\|workaround' sys/arm64 \| wc -l` |
| `nb-errata` | netbsd | lines under sys/arch mentioning errat/workaround | 330 | `grep -rhiE 'errat\|workaround' sys/arch \| wc -l` |
| `ob-errata` | openbsd | lines under sys/arch mentioning errat/workaround | 261 | `grep -rhiE 'errat\|workaround' sys/arch \| wc -l` |
| `ob-mitigation` | openbsd | lines under sys/arch mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf | 232 | `grep -rhiE 'mitigat\|spectre\|meltdown\|retpoline\|\bmds\b\|l1tf\|retbleed' sys/arch \| wc -l` |
| `fb-mitigation` | freebsd | lines in sys/x86 sys/amd64 sys/arm64 mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf | 68 | `grep -rhiE 'mitigat\|spectre\|meltdown\|retpoline\|\bmds\b\|l1tf\|retbleed' sys/x86 sys/amd64 sys/arm64 \| wc -l` |
| `nb-mitigation` | netbsd | lines under sys/arch mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf | 293 | `grep -rhiE 'mitigat\|spectre\|meltdown\|retpoline\|\bmds\b\|l1tf\|retbleed' sys/arch \| wc -l` |

### B.4 The category expressions

| Category | Regular expression (PCRE, case-insensitive unless noted) |
|---|---|
| errata | `\berrat(?:um\|a)\b` |
| workaround | `\bwork-?arounds?\b` |
| quirk | `\bquirks?\b` |
| mitigation | `\bmitigat(?:e\|es\|ed\|ion\|ions\|ing)\b` |
| spectre-family | `\b(?:spectre(?!\s+(?:x360\|x2\|xt\|13\|15\|envy\|laptop\|speaker))\|meltdown\|retpolines?\|ibrs\|ibpb\|stibp\|ssbd\|retbleed\|zenbleed\|srso\|spec_ctrl\|speculative store bypass\|branch history injection\|gather data sampling\|rfds)\b` |
| mds-l1tf-taa | `(?:microarchitectural data sampling\|\bmds_[a-z_]+\|\bmds (?:mitigation\|vulnerab\w*\|clear\w*\|buffer\w*)\|\bl1tf\b\|l1 terminal fault\|foreshadow\|zombieload\|\btaa\b\|tsx async abort\|\bsrbds\b\|mmio stale data)` |
| speculation-any | `\bspeculat(?:ion\|ive\|ively\|e)\b` |
| kpti-entry | `\b(?:kpti\|pti\|page[- ]table isolation\|kaiser\|syscall entry\|sysenter\|sysret\|swapgs\|vsyscall\|entry trampoline\|entry code\|int 0x80\|ia32 syscall)\b` |
| hardening | `(?:kaslr\|aslr\|clang cfi\|kcfi\|fineibt\|control.flow integrity\|bti\|cet\|shadow stack\|stack protector\|stackprotector\|stack canary\|pointer authentication\|stack clash\|vmap stack\|init_on_alloc\|usercopy\|kasan\|kfence\|memory tagging\|rodata\|w\^x\|set_memory_ro\|fortify_source)\b` |
| barrier-ordering | `\b(?:memory barriers?\|smp_mb\|smp_rmb\|smp_wmb\|smp_read_barrier_depends\|read_barrier_depends\|dma_wmb\|dma_rmb\|memory ordering\|memory-ordering\|acquire/release\|load-acquire\|store-release\|READ_ONCE\|WRITE_ONCE\|mmiowb)\b` |
| race | `\bra(?:ce\|ces\|cy)\b(?! condition in the tracing)` |
| deadlock | `\b(?:deadlocks?\|livelocks?\|lockup\|lock-up\|hung task)\b` |
| lockdep | `\blockdep\b` |
| spinlock-family | `\b(?:spinlocks?\|ticket lock\|qspinlock\|queued spinlock\|mcs lock\|rwlocks?\|seqlocks?\|big kernel lock\|bkl\|lock_kernel\|lock contention\|lock scalability)\b` |
| rcu | `\b(?:rcu\|srcu\|call_rcu\|synchronize_rcu\|read-copy)\b` |
| atomics-llsc | `\b(?:cmpxchg\|ll/sc\|load-linked\|store-conditional\|ldrex\|strex\|lr/sc\|test_and_set\|atomic_cmpxchg\|compare-and-swap\|compare and swap)\b` |
| percpu | `\b(?:per-cpu\|percpu\|this_cpu\|cpu-local)\b` |
| tlb | `\b(?:tlbs?\|translation lookaside\|invlpg\|tlb flush)\b` |
| shootdown | `\b(?:shootdowns?\|shoot-downs?\|flush_tlb_others\|tlb flush ipi)\b` |
| asid-pcid | `\b(?:asids?\|invpcid\|vmids?)\b\|\bpcid\b(?!\s*header)` |
| pagetable | `\b(?:page tables?\|pgd\|pmd\|pud\|p4d\|five-level\|5-level paging\|4-level paging\|page walk\|page-walk\|pgtable)\b` |
| accessed-dirty | `\b(?:accessed bit\|dirty bit\|young bit\|referenced bit\|pte_young\|pte_dirty\|pte_mkyoung\|access flag\|soft-dirty\|software dirty\|dirty bit management\|hardware dirty\|hw dirty\|reference bit)\b` |
| huge-pages | `\b(?:transparent huge\|thp\|hugepages?\|huge pages?\|hugetlb)\b` |
| numa | `\b(?:numa\|mempolicy\|numa balancing)\b` |
| cow-fork-mmaplock | `\b(?:copy-on-write\|dup_mmap\|mmap_sem\|mmap_lock\|mmap lock\|per-vma lock\|vma lock)\b` |
| cache-coherence | `\b(?:cache coheren\w*\|cache alias\w*\|cache flush\w*\|cache invalidat\w*\|cache maintenance\|dcache\|icache\|d-cache\|i-cache\|non-?coherent\|vipt\|vivt\|writeback cache\|write-back cache\|cache line bounc\w*\|false sharing)\b` |
| dma | `\b(?:dma\|swiotlb\|dma-mapping\|iommu\|bounce buffers?)\b` |
| mmio-ordering | `\b(?:write[- ]combin\w*\|posted writes?\|mmiowb\|readl_relaxed\|writel_relaxed\|doorbell\|wmb\(\))` |
| write-buffer-delay-slot | `\b(?:write buffer\|store buffer\|delay slots?\|branch delay)\b` |
| tlb-refill | `\b(?:tlb refill\|tlb miss\|tlb exception\|tlb handler\|tlb load)\b` |
| fpu-vector-state | `\b(?:fpu\|xsave\w*\|xrstor\w*\|lazy fpu\|eager fpu\|fxsave\|avx\d*\|simd\|neon\|sve\|altivec\|vfp\|vector state\|floating[- ]point state)\b` |
| alignment | `\b(?:unaligned\|misaligned\|alignment fault\|alignment exception\|get_unaligned\|put_unaligned\|packed struct\|__packed)\b` |
| endian | `\b(?:endian\w*\|byte-?order\|byteswap\w*\|cpu_to_le\w*\|le32_to_cpu\|be32_to_cpu)\b` |
| compat-32bit | `\b(?:compat\|ia32 emulation\|compat_ioctl\|ilp32\|x32\|31-bit\|32-bit compat\w*)\b` |
| y2038-time | `\b(?:y2038\|year 2038\|time_t\|timespec64\|64-bit time\|2038)\b` |
| timekeeping | `\b(?:vdso\|tsc\|clocksource\|timekeeping\|clock_gettime\|hpet\|time stamp counter\|monotonic clock)\b` |
| interrupts | `\b(?:interrupt latency\|irq latency\|irq storm\|interrupt storm\|spurious (?:irq\|interrupt)\w*\|eoi\|msi-x\|msi\|irq affinity\|apic\|gic\|plic\|ipi\|ipis)\b` |
| timers-tick | `\b(?:nohz\|tickless\|dynticks\|hrtimer\|timer wheel\|timer interrupt\|tick broadcast\|jiffies)\b` |
| idle-power | `\b(?:cpuidle\|mwait\|hlt\|wfi\|c-state\|c-states\|cpufreq\|runtime pm\|power domain\|suspend to ram\|hibernat\w*)\b` |
| virtualization | `\b(?:kvm\|nested virtualization\|nested paging\|vmexit\|vm exit\|hypercalls?\|paravirt\w*\|stage-2\|virtio\|xen)\b` |
| uaccess | `\b(?:copy_from_user\|copy_to_user\|uaccess\|smap\|smep\|get_user\|put_user\|strncpy_from_user\|exception tables?\|__ex_table\|stac\|clac)\b` |
| tracing-patching | `\b(?:ftrace\|kprobes?\|uprobes?\|text_poke\|int3\|jump labels?\|static keys?\|static calls?\|self-modifying\|kgdb\|hw_breakpoint\|hardware breakpoint\|single-step\w*)\b` |
| machine-check-poison | `\b(?:machine checks?\|mce\|hwpoison\|memory failure\|poisoned\|poison\|uncorrectable\|edac\|ecc error\w*)\b` |
| net-storage-fastpath | `\b(?:napi\|xdp\|zero-copy\|zerocopy\|busy[- ]poll\w*\|io_uring\|af_xdp\|gro\|tso\|batching\|lockless\|lock-free)\b` |
| marker-xxx-fixme-hack | `\b(?:XXX\|FIXME\|HACK\|KLUDGE)\b` | (case-sensitive)
| hardware-is-broken | `\b(?:(?:hardware\|cpu\|chip\|silicon\|firmware\|bios\|hw) (?:bug\|bugs\|quirk\|erratum\|errata\|brokenness)\|broken (?:hardware\|hw\|firmware\|bios\|cpus?)\|buggy (?:hardware\|hw\|cpus?\|firmware\|bios\|devices?))\b` |

### B.5 The per-category and per-architecture tables (the "table dump")

Counts are matching lines (not occurrences). "code lines" and "code files" are in files of kind code, "doc lines" and "kconfig lines" in the other kinds. The per-architecture tables give lines per 1,000 lines of code under that directory (the denominator counts only the sparse sample). Source: `docs/codegen-data/kernelpain/counts.csv`, `totals.csv`.


### linux: matching lines per category, by kind (all areas)

| category | code lines | code files | doc lines | kconfig lines |
|---|---:|---:|---:|---:|
| errata | 396 | 158 | 142 | 250 |
| workaround | 270 | 174 | 186 | 155 |
| quirk | 400 | 127 | 270 | 13 |
| mitigation | 380 | 94 | 770 | 60 |
| spectre-family | 496 | 77 | 345 | 38 |
| mds-l1tf-taa | 157 | 18 | 168 | 14 |
| speculation-any | 345 | 137 | 209 | 48 |
| kpti-entry | 455 | 164 | 124 | 27 |
| barrier-ordering | 5596 | 855 | 743 | 9 |
| race | 1108 | 443 | 304 | 47 |
| deadlock | 591 | 237 | 325 | 53 |
| lockdep | 410 | 174 | 147 | 21 |
| spinlock-family | 1464 | 697 | 371 | 35 |
| rcu | 3958 | 559 | 2406 | 111 |
| atomics-llsc | 499 | 230 | 103 | 7 |
| percpu | 1953 | 651 | 416 | 29 |
| tlb | 3133 | 604 | 276 | 67 |
| shootdown | 28 | 18 | 3 | 1 |
| asid-pcid | 1262 | 154 | 59 | 14 |
| pagetable | 11543 | 849 | 780 | 85 |
| accessed-dirty | 447 | 116 | 54 | 15 |
| huge-pages | 1276 | 246 | 842 | 34 |
| numa | 1000 | 231 | 418 | 105 |
| cow-fork-mmaplock | 451 | 101 | 97 | 1 |
| cache-coherence | 1260 | 372 | 277 | 46 |
| dma | 8696 | 760 | 5860 | 229 |
| mmio-ordering | 1609 | 276 | 325 | 5 |
| write-buffer-delay-slot | 196 | 105 | 25 | 15 |
| tlb-refill | 146 | 53 | 14 | 1 |
| fpu-vector-state | 2977 | 542 | 310 | 74 |
| alignment | 1807 | 472 | 175 | 59 |
| endian | 1793 | 520 | 976 | 35 |
| compat-32bit | 591 | 309 | 167 | 56 |
| y2038-time | 485 | 100 | 72 | 2 |
| timekeeping | 1903 | 462 | 380 | 37 |
| interrupts | 4787 | 616 | 3118 | 63 |
| timers-tick | 1946 | 391 | 301 | 28 |
| idle-power | 1168 | 257 | 1637 | 51 |
| virtualization | 14741 | 713 | 2024 | 226 |
| uaccess | 3213 | 825 | 111 | 4 |
| tracing-patching | 2867 | 608 | 737 | 133 |
| machine-check-poison | 1366 | 309 | 602 | 25 |
| net-storage-fastpath | 1462 | 222 | 881 | 10 |
| marker-xxx-fixme-hack | 719 | 379 | 133 | 1 |
| hardware-is-broken | 105 | 81 | 69 | 20 |

### linux: errata+workaround+quirk+hardware-is-broken code lines per architecture

| area | code lines | errata | workaround | quirk | hw-broken | per 1000 code lines |
|---|---:|---:|---:|---:|---:|---:|
| arch/x86 | 353474 | 120 | 62 | 55 | 41 | 0.8 |
| arch/powerpc | 276120 | 30 | 50 | 5 | 14 | 0.4 |
| arch/mips | 187846 | 35 | 25 | 0 | 1 | 0.3 |
| arch/arm64 | 173596 | 87 | 28 | 3 | 5 | 0.7 |
| arch/arm | 125813 | 30 | 20 | 5 | 2 | 0.5 |
| arch/m68k | 125375 | 10 | 4 | 0 | 2 | 0.1 |
| arch/sparc | 114872 | 7 | 13 | 1 | 4 | 0.2 |
| arch/s390 | 102388 | 0 | 1 | 0 | 1 | 0.0 |
| arch/riscv | 61381 | 5 | 2 | 0 | 0 | 0.1 |
| arch/alpha | 54723 | 0 | 6 | 1 | 3 | 0.2 |
| arch/loongarch | 45447 | 0 | 1 | 0 | 0 | 0.0 |

### freebsd: matching lines per category, by kind (all areas)

| category | code lines | code files | doc lines | kconfig lines |
|---|---:|---:|---:|---:|
| errata | 143 | 37 | 1 | 0 |
| workaround | 75 | 53 | 1 | 0 |
| quirk | 62 | 21 | 22 | 0 |
| mitigation | 47 | 13 | 0 | 0 |
| spectre-family | 33 | 12 | 0 | 0 |
| mds-l1tf-taa | 129 | 9 | 0 | 0 |
| speculation-any | 54 | 31 | 1 | 0 |
| kpti-entry | 157 | 29 | 0 | 0 |
| barrier-ordering | 21 | 16 | 8 | 0 |
| race | 220 | 98 | 20 | 0 |
| deadlock | 107 | 57 | 17 | 0 |
| spinlock-family | 537 | 144 | 82 | 0 |
| rcu | 1 | 1 | 0 | 0 |
| atomics-llsc | 51 | 14 | 4 | 0 |
| percpu | 198 | 91 | 39 | 0 |
| tlb | 533 | 87 | 3 | 0 |
| shootdown | 41 | 17 | 1 | 0 |
| asid-pcid | 297 | 36 | 0 | 0 |
| pagetable | 913 | 119 | 7 | 0 |
| accessed-dirty | 92 | 23 | 2 | 0 |
| huge-pages | 6 | 2 | 0 | 0 |
| numa | 122 | 43 | 26 | 0 |
| cow-fork-mmaplock | 27 | 14 | 8 | 0 |
| cache-coherence | 163 | 53 | 5 | 0 |
| dma | 1233 | 170 | 129 | 0 |
| mmio-ordering | 51 | 22 | 2 | 0 |
| write-buffer-delay-slot | 26 | 11 | 0 | 0 |
| tlb-refill | 36 | 8 | 0 | 0 |
| fpu-vector-state | 1039 | 150 | 19 | 0 |
| alignment | 244 | 95 | 4 | 0 |
| endian | 188 | 100 | 62 | 0 |
| compat-32bit | 406 | 124 | 10 | 0 |
| y2038-time | 92 | 32 | 4 | 0 |
| timekeeping | 273 | 89 | 4 | 0 |
| interrupts | 1588 | 170 | 51 | 0 |
| timers-tick | 20 | 14 | 3 | 0 |
| idle-power | 170 | 67 | 0 | 0 |
| virtualization | 565 | 74 | 9 | 0 |
| uaccess | 163 | 18 | 0 | 0 |
| tracing-patching | 30 | 20 | 1 | 0 |
| machine-check-poison | 95 | 34 | 0 | 0 |
| net-storage-fastpath | 55 | 28 | 10 | 0 |
| marker-xxx-fixme-hack | 986 | 449 | 7 | 0 |
| hardware-is-broken | 29 | 24 | 1 | 0 |

### freebsd: errata+workaround+quirk+hardware-is-broken code lines per architecture

| area | code lines | errata | workaround | quirk | hw-broken | per 1000 code lines |
|---|---:|---:|---:|---:|---:|---:|
| arch/x86 | 226091 | 59 | 26 | 19 | 17 | 0.5 |
| arch/arm | 178432 | 18 | 18 | 31 | 4 | 0.4 |
| arch/arm64 | 129165 | 66 | 15 | 5 | 7 | 0.7 |
| arch/powerpc | 106145 | 0 | 3 | 5 | 1 | 0.1 |
| arch/riscv | 39575 | 0 | 1 | 1 | 0 | 0.1 |

### netbsd: matching lines per category, by kind (all areas)

| category | code lines | code files | doc lines | kconfig lines |
|---|---:|---:|---:|---:|
| errata | 108 | 40 | 0 | 0 |
| workaround | 64 | 48 | 1 | 0 |
| quirk | 16 | 16 | 5 | 0 |
| mitigation | 36 | 5 | 0 | 0 |
| spectre-family | 52 | 10 | 0 | 0 |
| mds-l1tf-taa | 83 | 4 | 0 | 0 |
| speculation-any | 40 | 19 | 6 | 0 |
| kpti-entry | 187 | 36 | 1 | 0 |
| barrier-ordering | 159 | 55 | 26 | 0 |
| race | 70 | 51 | 3 | 0 |
| deadlock | 67 | 42 | 10 | 0 |
| spinlock-family | 90 | 62 | 33 | 0 |
| atomics-llsc | 57 | 29 | 7 | 0 |
| percpu | 249 | 89 | 53 | 0 |
| tlb | 1206 | 213 | 5 | 0 |
| shootdown | 65 | 17 | 1 | 0 |
| asid-pcid | 412 | 55 | 0 | 0 |
| pagetable | 480 | 117 | 4 | 0 |
| accessed-dirty | 54 | 29 | 2 | 0 |
| numa | 24 | 12 | 0 | 0 |
| cow-fork-mmaplock | 33 | 17 | 11 | 0 |
| cache-coherence | 544 | 128 | 6 | 0 |
| dma | 1485 | 231 | 180 | 0 |
| mmio-ordering | 11 | 9 | 4 | 0 |
| write-buffer-delay-slot | 230 | 54 | 2 | 0 |
| tlb-refill | 65 | 22 | 0 | 0 |
| fpu-vector-state | 1330 | 246 | 6 | 0 |
| alignment | 292 | 111 | 1 | 0 |
| endian | 248 | 135 | 48 | 0 |
| compat-32bit | 448 | 202 | 34 | 0 |
| y2038-time | 98 | 31 | 12 | 0 |
| timekeeping | 114 | 33 | 22 | 0 |
| interrupts | 686 | 149 | 65 | 0 |
| timers-tick | 30 | 21 | 1 | 0 |
| idle-power | 102 | 46 | 19 | 0 |
| virtualization | 344 | 81 | 23 | 0 |
| uaccess | 28 | 12 | 0 | 0 |
| tracing-patching | 348 | 105 | 4 | 0 |
| machine-check-poison | 232 | 106 | 0 | 0 |
| net-storage-fastpath | 45 | 22 | 8 | 0 |
| marker-xxx-fixme-hack | 2979 | 929 | 23 | 0 |
| hardware-is-broken | 26 | 22 | 0 | 0 |

### netbsd: errata+workaround+quirk+hardware-is-broken code lines per architecture

| area | code lines | errata | workaround | quirk | hw-broken | per 1000 code lines |
|---|---:|---:|---:|---:|---:|---:|
| arch/x86 | 161321 | 48 | 23 | 4 | 6 | 0.5 |
| arch/sparc | 159269 | 2 | 8 | 2 | 4 | 0.1 |
| arch/m68k | 144058 | 7 | 1 | 0 | 0 | 0.1 |
| arch/powerpc | 77264 | 17 | 8 | 0 | 0 | 0.3 |
| arch/alpha | 70269 | 0 | 1 | 1 | 4 | 0.1 |
| arch/parisc | 65230 | 3 | 0 | 1 | 2 | 0.1 |
| arch/arm | 64290 | 26 | 17 | 2 | 0 | 0.7 |
| arch/vax | 52916 | 0 | 1 | 0 | 2 | 0.1 |
| arch/mips | 52041 | 2 | 2 | 2 | 7 | 0.2 |
| arch/riscv | 31531 | 0 | 0 | 1 | 0 | 0.0 |
| arch/arm64 | 31290 | 3 | 0 | 0 | 1 | 0.1 |

### openbsd: matching lines per category, by kind (all areas)

| category | code lines | code files | doc lines | kconfig lines |
|---|---:|---:|---:|---:|
| errata | 74 | 24 | 0 | 0 |
| workaround | 30 | 23 | 0 | 0 |
| quirk | 10 | 7 | 0 | 0 |
| mitigation | 26 | 9 | 1 | 0 |
| spectre-family | 119 | 20 | 0 | 0 |
| mds-l1tf-taa | 68 | 5 | 0 | 0 |
| speculation-any | 44 | 21 | 0 | 0 |
| kpti-entry | 149 | 18 | 1 | 0 |
| barrier-ordering | 56 | 21 | 8 | 0 |
| race | 37 | 32 | 1 | 0 |
| deadlock | 40 | 20 | 5 | 0 |
| spinlock-family | 247 | 91 | 31 | 0 |
| atomics-llsc | 26 | 5 | 2 | 0 |
| percpu | 60 | 47 | 4 | 0 |
| tlb | 402 | 102 | 0 | 0 |
| shootdown | 29 | 13 | 0 | 0 |
| asid-pcid | 138 | 25 | 0 | 0 |
| pagetable | 353 | 90 | 2 | 0 |
| accessed-dirty | 21 | 11 | 0 | 0 |
| numa | 1 | 1 | 0 | 0 |
| cow-fork-mmaplock | 16 | 7 | 4 | 0 |
| cache-coherence | 213 | 59 | 0 | 0 |
| dma | 869 | 133 | 94 | 0 |
| mmio-ordering | 20 | 15 | 0 | 0 |
| write-buffer-delay-slot | 75 | 21 | 2 | 0 |
| tlb-refill | 20 | 14 | 0 | 0 |
| fpu-vector-state | 781 | 177 | 1 | 0 |
| alignment | 450 | 95 | 3 | 0 |
| endian | 133 | 53 | 14 | 0 |
| compat-32bit | 88 | 34 | 0 | 0 |
| y2038-time | 102 | 47 | 6 | 0 |
| timekeeping | 73 | 21 | 3 | 0 |
| interrupts | 529 | 118 | 5 | 0 |
| timers-tick | 10 | 8 | 1 | 0 |
| idle-power | 1097 | 89 | 2 | 0 |
| virtualization | 67 | 34 | 1 | 0 |
| uaccess | 19 | 8 | 0 | 0 |
| tracing-patching | 24 | 16 | 0 | 0 |
| machine-check-poison | 154 | 52 | 6 | 0 |
| net-storage-fastpath | 3 | 3 | 1 | 0 |
| marker-xxx-fixme-hack | 1607 | 556 | 8 | 0 |
| hardware-is-broken | 9 | 9 | 0 | 0 |

### openbsd: errata+workaround+quirk+hardware-is-broken code lines per architecture

| area | code lines | errata | workaround | quirk | hw-broken | per 1000 code lines |
|---|---:|---:|---:|---:|---:|---:|
| arch/x86 | 147798 | 49 | 20 | 6 | 4 | 0.5 |
| arch/sparc | 84840 | 2 | 1 | 0 | 0 | 0.0 |
| arch/arm64 | 61632 | 7 | 2 | 4 | 0 | 0.2 |
| arch/arm | 54921 | 1 | 0 | 0 | 0 | 0.0 |
| arch/alpha | 54470 | 0 | 2 | 0 | 4 | 0.1 |
| arch/parisc | 46962 | 3 | 0 | 0 | 1 | 0.1 |
| arch/riscv | 35619 | 1 | 0 | 0 | 0 | 0.0 |
| arch/powerpc | 31773 | 0 | 0 | 0 | 0 | 0.0 |
| arch/mips | 18586 | 0 | 0 | 0 | 0 | 0.0 |
| arch/m88k | 18579 | 11 | 3 | 0 | 0 | 0.8 |


### B.6 Measurement 2: commit messages on treeless bare clones

`tools/kernelpain-msgs.sh` clones one repository at a time with `git clone --bare --filter=tree:0 --single-branch <url>` (commits only: no trees, no blobs, no checkout), runs `git log --no-merges --date=format:%Y-%m-%d --format=<hash, date, subject, body>` with no path arguments, classifies each message with the B.4 expressions, writes CSV files `docs/codegen-data/kernelpain/msgs-<repo>-*.csv`, and deletes the clone. Per-subsystem and per-architecture counts come from the subject prefix (the text before the first colon, for example `x86/mm`, `arm64`, `mm`), per-year counts from the commit date. The results are summarised in B.7 when they exist.

Four repositories were mined on 2026-10-22 with `tools/kernelpain-msgs.sh linux freebsd netbsd openbsd` (treeless bare clones, deleted afterwards): Linux (torvalds/linux, 1,377,457 non-merge commits from 2005, head `a1c2b1da93f5`), FreeBSD (309,283 from 1993, head `775e421dc38f`), NetBSD (317,170 from 1993, head `5b0e0d599751`) and OpenBSD (248,109 from 1995, head `d962f40cd0b4`). The exact `git log` command and head hash of each is in `docs/codegen-data/kernelpain/msgs-<repo>-meta.csv`. The counts say how often a pain word appears in a commit's subject or message; they do not say how much pain there was (section 16). Known noise: before 2018 nothing in `spectre-family` should match (the laptop-speaker commits were removed by the second run); `mds-l1tf-taa` still matches Ceph's "mds" (metadata server) and Staging drivers, so its counts are inflated and only its trend is usable.

**What the shape shows** (per 1000 non-merge commits of the period, from the tables below. Linux's `-1999` and `2000-04` columns hold 2 and 32 commits and are meaningless; the first usable Linux period is 2005-09. The BSDs begin in 1993 to 1995):

* **Hardware-defect words are flat; mitigation and hardening words grew.** In Linux `errata` stays at 1.4 to 1.8, `workaround` at 5.7 to 6.2 and `quirk` at 5.5 to 8.2 across 2005 to 2026, while `mitigation` rises from 0.4 to 2.3 and `hardening` from 0.9-1.5 to 10.9. FreeBSD shows the same: `mitigation` 0.1 to 1.7, `hardening` 0.2 to 4.9. The cost of hardware imperfection did not fall; the new cost is defence.
* **Concurrency words grew most.** `rcu` 4.6 to 9.9, `atomics-llsc` 1.4 to 5.6, `barrier-ordering` 1.4 to 3.7, `percpu` 4.1 to 5.2 in Linux; `spinlock-family` fell from 9.8 to 5.9 (the move from locks to lock-free and RCU); OpenBSD's `spinlock-family` rose from 0.5 to 3.1 and its `interrupts` from 0.1 to 3.4 in the same years as its multiprocessor work.
* **Speculation is a 2018 event.** `spectre-family` is zero until 2015-19 and 1.2 to 1.3 per thousand after; its first Linux match is a retpoline commit of 11 Jan 2018 (`2641f08bb7fc`). `kpti-entry` goes 1.3 to 4.0. The BSDs show the same jump in the same period (2015-19: FreeBSD 0.6, NetBSD 0.8, OpenBSD 1.0, Linux 1.3), then a fall in 2020-26 to 0.1 to 0.6 against Linux's 1.2.
* **Things that faded:** `tlb-refill` (software-refilled TLBs) 0.4 to 0.1, `endian` 7.0 to 3.0 in Linux, `write-buffer-delay-slot` flat at 0.3, `compat-32bit` 3.9 to 2.5, and `y2038-time` peaks in 2015-19 (1.8) after the conversion started.
* **A BSD-specific growth:** FreeBSD's `compat-32bit` rose from 2.0 to 10.9 per thousand (32-bit and Linux emulation layers), NetBSD's from 3.4 to 7.7, OpenBSD's stayed 1 to 3: a compatibility layer is a cost that keeps growing where it exists.
* **Things that grew with scale:** `huge-pages` 1.9 to 5.0, `net-storage-fastpath` 4.4 to 16.5, `virtualization` 19 to 33, `fpu-vector-state` 1.8 to 3.3-3.9.
* **Where the quirk and workaround words concentrate by subject prefix** (second table of each repository): device subsystems, not CPU architectures. In Linux the highest rates are `alsa` 71, `hid` 58, `acpi` 32, `pci` 32 and `mmc` 26 per 1000 commits, against `x86` 11, `arm64` 8 and `arm` 6. The pain of "the hardware does not follow its specification" is mostly in the long tail of peripherals.


#### linux: 1377457 non-merge commits, head `a1c2b1da93f5f612aa7a33190c4900c98e51f6da` (2026-10-22), https://github.com/torvalds/linux

Commits whose subject or message matches the category, per 1000 non-merge commits of the period (message mining, any match).

| category | -1999 | 2000-04 | 2005-09 | 2010-14 | 2015-19 | 2020-26 | total |
|---|---:|---:|---:|---:|---:|---:|---:|
| (all commits) | 2 | 32 | 170081 | 294493 | 366720 | 546124 | 1377457 |
| errata | 0.0 | 0.0 | 1.4 | 1.5 | 1.8 | 1.5 | 2131 |
| workaround | 0.0 | 0.0 | 6.0 | 5.7 | 6.0 | 6.2 | 8307 |
| quirk | 0.0 | 0.0 | 6.4 | 5.5 | 5.9 | 8.2 | 9335 |
| mitigation | 0.0 | 0.0 | 0.4 | 0.4 | 1.3 | 2.3 | 1895 |
| spectre-family | 0.0 | 0.0 | 0.0 | 0.0 | 1.3 | 1.2 | 1107 |
| mds-l1tf-taa | 0.0 | 0.0 | 0.0 | 0.1 | 0.3 | 0.2 | 239 |
| speculation-any | 0.0 | 0.0 | 0.3 | 0.3 | 1.4 | 1.0 | 1185 |
| kpti-entry | 0.0 | 0.0 | 1.3 | 1.0 | 2.8 | 4.0 | 3733 |
| barrier-ordering | 0.0 | 0.0 | 1.4 | 1.4 | 2.8 | 3.7 | 3646 |
| race | 0.0 | 0.0 | 13.3 | 12.9 | 12.6 | 14.9 | 18804 |
| deadlock | 0.0 | 0.0 | 6.7 | 6.6 | 6.3 | 6.7 | 9041 |
| lockdep | 0.0 | 0.0 | 4.9 | 3.3 | 3.7 | 4.4 | 5587 |
| spinlock-family | 0.0 | 0.0 | 9.8 | 7.5 | 6.0 | 5.9 | 9301 |
| rcu | 0.0 | 0.0 | 4.6 | 8.6 | 8.6 | 9.9 | 11875 |
| atomics-llsc | 0.0 | 0.0 | 1.4 | 4.5 | 4.4 | 5.6 | 6241 |
| percpu | 0.0 | 0.0 | 4.1 | 3.8 | 3.6 | 5.2 | 5947 |
| tlb | 0.0 | 0.0 | 3.5 | 2.6 | 2.9 | 3.1 | 4132 |
| shootdown | 0.0 | 0.0 | 0.2 | 0.1 | 0.1 | 0.1 | 140 |
| asid-pcid | 0.0 | 0.0 | 0.2 | 0.4 | 0.8 | 0.9 | 943 |
| pagetable | 0.0 | 31.2 | 4.5 | 5.1 | 8.3 | 8.3 | 9872 |
| accessed-dirty | 0.0 | 0.0 | 0.4 | 0.3 | 0.3 | 0.5 | 533 |
| huge-pages | 0.0 | 0.0 | 1.9 | 2.8 | 3.4 | 5.0 | 5154 |
| numa | 0.0 | 0.0 | 3.7 | 3.1 | 2.3 | 2.7 | 3851 |
| cow-fork-mmaplock | 0.0 | 0.0 | 1.0 | 0.8 | 0.9 | 1.1 | 1306 |
| cache-coherence | 0.0 | 0.0 | 3.1 | 2.4 | 2.2 | 2.2 | 3263 |
| dma | 0.0 | 31.2 | 22.1 | 23.4 | 26.0 | 24.8 | 33779 |
| mmio-ordering | 0.0 | 0.0 | 0.8 | 1.1 | 1.9 | 1.8 | 2139 |
| write-buffer-delay-slot | 0.0 | 0.0 | 0.3 | 0.3 | 0.3 | 0.3 | 422 |
| tlb-refill | 0.0 | 0.0 | 0.4 | 0.3 | 0.2 | 0.1 | 286 |
| fpu-vector-state | 0.0 | 0.0 | 1.8 | 1.8 | 3.9 | 3.3 | 4071 |
| alignment | 0.0 | 0.0 | 2.0 | 1.8 | 1.9 | 2.3 | 2846 |
| endian | 0.0 | 0.0 | 7.0 | 5.1 | 5.2 | 3.0 | 6266 |
| compat-32bit | 0.0 | 0.0 | 3.9 | 2.8 | 3.3 | 2.5 | 4075 |
| y2038-time | 0.0 | 0.0 | 0.1 | 0.2 | 1.8 | 0.3 | 905 |
| timekeeping | 0.0 | 0.0 | 5.2 | 4.7 | 5.5 | 4.5 | 6715 |
| interrupts | 0.0 | 31.2 | 10.7 | 8.2 | 9.1 | 8.4 | 12151 |
| timers-tick | 0.0 | 0.0 | 4.7 | 3.1 | 3.2 | 3.6 | 4870 |
| idle-power | 0.0 | 0.0 | 6.8 | 11.5 | 11.0 | 11.0 | 14632 |
| virtualization | 0.0 | 0.0 | 19.3 | 25.6 | 25.3 | 33.1 | 38185 |
| uaccess | 0.0 | 0.0 | 2.8 | 2.3 | 2.6 | 2.8 | 3608 |
| tracing-patching | 0.0 | 0.0 | 8.6 | 6.4 | 6.1 | 6.7 | 9237 |
| machine-check-poison | 0.0 | 0.0 | 4.6 | 3.0 | 4.0 | 3.7 | 5167 |
| net-storage-fastpath | 0.0 | 0.0 | 4.4 | 3.9 | 7.6 | 16.5 | 13691 |
| marker-xxx-fixme-hack | 0.0 | 0.0 | 1.2 | 0.7 | 0.8 | 0.8 | 1130 |
| hardware-is-broken | 0.0 | 31.2 | 1.4 | 1.2 | 0.9 | 0.8 | 1344 |

##### linux: subject prefixes with the most commits whose SUBJECT matches errata, workaround or quirk

| prefix | subject matches | all commits with this prefix | per 1000 |
|---|---:|---:|---:|
| drm | 1126 | 119855 | 9.4 |
| alsa | 1119 | 15747 | 71.1 |
| usb | 395 | 22179 | 17.8 |
| asoc | 370 | 33286 | 11.1 |
| hid | 311 | 5395 | 57.6 |
| arm | 303 | 49324 | 6.1 |
| pci | 285 | 9061 | 31.5 |
| x86 | 268 | 23424 | 11.4 |
| arm64 | 247 | 31882 | 7.7 |
| acpi | 197 | 6244 | 31.6 |
| mmc | 193 | 7341 | 26.3 |
| net | 159 | 48850 | 3.3 |
| input | 99 | 7372 | 13.4 |

#### freebsd: 309283 non-merge commits, head `775e421dc38f18fa6b7fdc7b214a013cca44b58b` (2026-10-22), https://github.com/freebsd/freebsd-src

Commits whose subject or message matches the category, per 1000 non-merge commits of the period (message mining, any match).

| category | -1999 | 2000-04 | 2005-09 | 2010-14 | 2015-19 | 2020-26 | total |
|---|---:|---:|---:|---:|---:|---:|---:|
| (all commits) | 43867 | 65814 | 42607 | 44147 | 52235 | 60613 | 309283 |
| errata | 0.1 | 1.5 | 0.8 | 1.3 | 1.3 | 1.3 | 343 |
| workaround | 3.0 | 4.0 | 5.7 | 6.9 | 6.5 | 5.7 | 1622 |
| quirk | 1.6 | 2.1 | 4.1 | 3.1 | 2.6 | 2.7 | 819 |
| mitigation | 0.1 | 0.2 | 0.4 | 0.6 | 1.2 | 1.7 | 229 |
| spectre-family | 0.0 | 0.0 | 0.0 | 0.0 | 0.6 | 0.1 | 39 |
| mds-l1tf-taa | 0.0 | 0.0 | 0.0 | 0.0 | 0.3 | 0.0 | 20 |
| speculation-any | 0.1 | 0.2 | 0.4 | 0.1 | 0.7 | 0.6 | 103 |
| kpti-entry | 0.1 | 0.2 | 0.3 | 0.4 | 0.9 | 0.4 | 118 |
| barrier-ordering | 0.0 | 0.5 | 0.8 | 0.9 | 0.7 | 0.5 | 172 |
| race | 3.4 | 5.9 | 10.9 | 9.3 | 9.5 | 9.8 | 2499 |
| deadlock | 2.0 | 2.2 | 3.8 | 5.0 | 3.6 | 2.6 | 957 |
| lockdep | 0.0 | 0.0 | 0.0 | 0.0 | 0.3 | 0.3 | 35 |
| spinlock-family | 0.3 | 1.2 | 4.4 | 2.6 | 2.7 | 2.2 | 665 |
| rcu | 0.0 | 0.0 | 0.0 | 0.0 | 0.4 | 0.5 | 48 |
| atomics-llsc | 0.0 | 0.1 | 0.0 | 0.2 | 0.2 | 0.1 | 40 |
| percpu | 0.4 | 1.1 | 2.1 | 1.9 | 1.8 | 1.8 | 465 |
| tlb | 0.5 | 1.5 | 1.2 | 2.7 | 2.0 | 1.2 | 462 |
| shootdown | 0.1 | 0.4 | 0.2 | 0.3 | 0.4 | 0.2 | 82 |
| asid-pcid | 0.0 | 0.0 | 0.0 | 0.2 | 0.6 | 0.2 | 56 |
| pagetable | 1.3 | 0.8 | 1.3 | 2.3 | 2.5 | 2.7 | 564 |
| accessed-dirty | 0.0 | 0.0 | 0.1 | 0.3 | 0.2 | 0.2 | 40 |
| numa | 0.0 | 0.0 | 0.1 | 0.3 | 1.8 | 1.4 | 193 |
| cow-fork-mmaplock | 0.0 | 0.2 | 0.1 | 0.2 | 0.2 | 0.2 | 55 |
| cache-coherence | 0.1 | 0.4 | 0.8 | 1.4 | 1.6 | 1.0 | 267 |
| dma | 3.6 | 3.2 | 6.8 | 7.6 | 5.7 | 6.5 | 1695 |
| mmio-ordering | 0.1 | 0.2 | 0.3 | 0.6 | 1.0 | 1.0 | 165 |
| write-buffer-delay-slot | 0.0 | 0.0 | 0.2 | 0.2 | 0.2 | 0.1 | 34 |
| fpu-vector-state | 0.8 | 1.1 | 1.0 | 2.7 | 3.1 | 4.9 | 727 |
| alignment | 0.6 | 1.1 | 1.4 | 1.1 | 1.4 | 1.7 | 384 |
| endian | 0.6 | 2.2 | 3.9 | 3.9 | 2.8 | 3.7 | 880 |
| compat-32bit | 2.0 | 2.7 | 4.4 | 6.2 | 6.5 | 10.9 | 1723 |
| y2038-time | 1.0 | 0.9 | 0.7 | 0.8 | 0.7 | 0.9 | 257 |
| timekeeping | 0.9 | 0.5 | 1.4 | 2.6 | 1.9 | 2.7 | 510 |
| interrupts | 1.3 | 3.1 | 6.3 | 6.9 | 6.2 | 5.2 | 1469 |
| timers-tick | 0.0 | 0.1 | 0.2 | 0.5 | 0.3 | 0.4 | 73 |
| idle-power | 0.1 | 0.2 | 1.4 | 1.1 | 0.9 | 0.7 | 213 |
| virtualization | 0.8 | 0.8 | 2.8 | 7.9 | 5.5 | 6.8 | 1253 |
| uaccess | 0.0 | 0.1 | 0.3 | 0.5 | 0.4 | 0.2 | 73 |
| tracing-patching | 0.3 | 0.3 | 0.8 | 0.7 | 0.9 | 0.8 | 200 |
| machine-check-poison | 0.2 | 0.6 | 0.5 | 1.0 | 0.7 | 0.9 | 202 |
| net-storage-fastpath | 0.0 | 0.4 | 2.3 | 3.1 | 2.6 | 3.4 | 609 |
| marker-xxx-fixme-hack | 1.6 | 2.6 | 2.1 | 1.1 | 0.6 | 0.8 | 462 |
| hardware-is-broken | 0.3 | 0.3 | 1.2 | 1.0 | 0.7 | 0.4 | 186 |

##### freebsd: subject prefixes with the most commits whose SUBJECT matches errata, workaround or quirk

| prefix | subject matches | all commits with this prefix | per 1000 |
|---|---:|---:|---:|
| arm64 | 19 | 966 | 19.7 |
| new errata | 17 | n/a | n/a |
| usb | 17 | 87 | 195.4 |
| ntb | 9 | 83 | 108.4 |
| acpi | 7 | 121 | 57.9 |
| mfp4 | 6 | 443 | 13.5 |
| cam | 4 | 187 | 21.4 |
| nvme | 4 | 247 | 16.2 |
| umass | 4 | n/a | n/a |
| new errata item | 3 | n/a | n/a |
| new release | 3 | n/a | n/a |
| sdhci_fsl_fdt | 3 | n/a | n/a |
| new release notes | 3 | 381 | 7.9 |

#### netbsd: 317170 non-merge commits, head `5b0e0d5997518246c017c6577adcb59be12d0a79` (2026-10-22), https://github.com/NetBSD/src

Commits whose subject or message matches the category, per 1000 non-merge commits of the period (message mining, any match).

| category | -1999 | 2000-04 | 2005-09 | 2010-14 | 2015-19 | 2020-26 | total |
|---|---:|---:|---:|---:|---:|---:|---:|
| (all commits) | 58778 | 73915 | 54078 | 45729 | 40193 | 44477 | 317170 |
| errata | 0.0 | 0.3 | 0.3 | 0.3 | 0.9 | 0.7 | 111 |
| workaround | 1.7 | 2.3 | 3.7 | 3.2 | 4.3 | 4.2 | 982 |
| quirk | 1.2 | 2.3 | 1.4 | 1.1 | 0.9 | 1.5 | 479 |
| mitigation | 0.0 | 0.1 | 0.1 | 0.2 | 1.4 | 0.9 | 123 |
| spectre-family | 0.0 | 0.0 | 0.0 | 0.0 | 0.8 | 0.2 | 41 |
| speculation-any | 0.0 | 0.0 | 0.0 | 0.1 | 0.3 | 0.1 | 23 |
| kpti-entry | 0.1 | 0.2 | 0.2 | 0.3 | 0.4 | 0.2 | 68 |
| barrier-ordering | 0.1 | 0.1 | 0.6 | 0.1 | 0.4 | 1.7 | 141 |
| race | 1.4 | 1.5 | 2.8 | 3.1 | 4.3 | 5.7 | 915 |
| deadlock | 0.6 | 0.8 | 2.0 | 1.1 | 1.8 | 2.5 | 432 |
| spinlock-family | 0.1 | 0.4 | 1.6 | 0.5 | 0.7 | 1.0 | 221 |
| rcu | 0.0 | 0.0 | 0.0 | 0.0 | 0.2 | 0.5 | 29 |
| atomics-llsc | 0.1 | 0.1 | 0.2 | 0.3 | 0.1 | 0.2 | 44 |
| percpu | 0.4 | 0.3 | 1.3 | 1.0 | 1.3 | 1.5 | 280 |
| tlb | 1.1 | 1.5 | 1.2 | 1.7 | 1.1 | 1.5 | 433 |
| shootdown | 0.1 | 0.1 | 0.2 | 0.2 | 0.1 | 0.3 | 46 |
| asid-pcid | 0.2 | 0.2 | 0.0 | 0.3 | 0.4 | 0.4 | 72 |
| pagetable | 1.4 | 0.7 | 0.3 | 0.6 | 0.6 | 0.6 | 228 |
| cow-fork-mmaplock | 0.0 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 20 |
| cache-coherence | 0.9 | 1.3 | 0.8 | 1.0 | 1.3 | 0.9 | 330 |
| dma | 7.7 | 5.0 | 3.3 | 3.5 | 3.3 | 4.6 | 1502 |
| mmio-ordering | 0.0 | 0.0 | 0.0 | 0.1 | 0.2 | 0.3 | 32 |
| write-buffer-delay-slot | 0.4 | 0.4 | 0.4 | 0.1 | 0.1 | 0.4 | 100 |
| tlb-refill | 0.1 | 0.2 | 0.1 | 0.2 | 0.1 | 0.1 | 41 |
| fpu-vector-state | 1.5 | 1.9 | 0.9 | 3.9 | 2.7 | 3.4 | 717 |
| alignment | 0.6 | 0.9 | 1.1 | 1.0 | 0.9 | 2.2 | 338 |
| endian | 3.0 | 4.3 | 2.8 | 2.8 | 2.7 | 5.6 | 1130 |
| compat-32bit | 3.4 | 3.3 | 6.7 | 5.7 | 7.5 | 7.7 | 1708 |
| y2038-time | 0.6 | 0.3 | 1.8 | 1.4 | 0.6 | 0.9 | 290 |
| timekeeping | 0.1 | 0.1 | 0.9 | 0.9 | 0.4 | 1.0 | 167 |
| interrupts | 0.4 | 1.0 | 1.3 | 1.7 | 5.2 | 3.2 | 598 |
| timers-tick | 0.1 | 0.1 | 0.1 | 0.2 | 0.1 | 0.2 | 33 |
| idle-power | 0.0 | 0.0 | 0.2 | 0.5 | 0.6 | 0.4 | 75 |
| virtualization | 0.7 | 0.6 | 5.4 | 6.3 | 7.3 | 6.5 | 1252 |
| uaccess | 0.1 | 0.0 | 0.0 | 0.1 | 0.5 | 0.3 | 41 |
| tracing-patching | 1.9 | 1.0 | 0.5 | 0.2 | 0.7 | 0.7 | 283 |
| machine-check-poison | 0.5 | 0.5 | 0.2 | 0.3 | 0.2 | 0.2 | 114 |
| net-storage-fastpath | 0.0 | 0.1 | 0.4 | 0.3 | 0.5 | 0.7 | 91 |
| marker-xxx-fixme-hack | 8.3 | 13.8 | 14.1 | 15.4 | 20.7 | 20.1 | 4695 |
| hardware-is-broken | 0.3 | 0.2 | 0.2 | 0.2 | 0.1 | 0.3 | 73 |

##### netbsd: subject prefixes with the most commits whose SUBJECT matches errata, workaround or quirk

| prefix | subject matches | all commits with this prefix | per 1000 |
|---|---:|---:|---:|
| x86 | 6 | 131 | 45.8 |
| pr | 5 | 2402 | 2.1 |
| bind | 3 | 16 | 187.5 |

#### openbsd: 248109 non-merge commits, head `d962f40cd0b4b974405c3cac59ec7417040c0533` (2026-10-22), https://github.com/openbsd/src

Commits whose subject or message matches the category, per 1000 non-merge commits of the period (message mining, any match).

| category | -1999 | 2000-04 | 2005-09 | 2010-14 | 2015-19 | 2020-26 | total |
|---|---:|---:|---:|---:|---:|---:|---:|
| (all commits) | 24652 | 48083 | 48293 | 36230 | 44992 | 45859 | 248109 |
| errata | 0.1 | 0.2 | 0.6 | 0.8 | 0.5 | 0.9 | 132 |
| workaround | 2.0 | 2.5 | 3.4 | 3.6 | 2.6 | 4.3 | 782 |
| quirk | 1.3 | 0.8 | 1.6 | 1.5 | 1.9 | 2.8 | 416 |
| mitigation | 0.0 | 0.0 | 0.5 | 0.6 | 1.1 | 1.4 | 159 |
| spectre-family | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 0.6 | 75 |
| speculation-any | 0.0 | 0.0 | 0.0 | 0.1 | 0.4 | 0.6 | 51 |
| barrier-ordering | 0.0 | 0.0 | 0.0 | 0.1 | 0.6 | 0.7 | 68 |
| race | 2.9 | 2.8 | 2.6 | 3.5 | 3.5 | 4.8 | 839 |
| deadlock | 0.3 | 0.4 | 0.9 | 1.0 | 1.3 | 1.2 | 222 |
| spinlock-family | 0.5 | 0.1 | 1.2 | 1.0 | 1.5 | 3.1 | 324 |
| percpu | 0.0 | 0.0 | 0.2 | 0.5 | 0.9 | 1.4 | 133 |
| tlb | 0.2 | 0.7 | 1.0 | 1.0 | 0.8 | 1.2 | 220 |
| shootdown | 0.0 | 0.1 | 0.2 | 0.2 | 0.1 | 0.2 | 33 |
| asid-pcid | 0.0 | 0.0 | 0.0 | 0.2 | 0.5 | 0.9 | 69 |
| pagetable | 0.2 | 0.4 | 0.3 | 0.6 | 0.7 | 0.9 | 130 |
| cache-coherence | 0.4 | 0.6 | 0.7 | 0.7 | 0.5 | 0.7 | 145 |
| dma | 2.4 | 2.7 | 4.9 | 3.6 | 3.2 | 5.0 | 928 |
| mmio-ordering | 0.0 | 0.0 | 0.0 | 0.2 | 0.4 | 0.6 | 54 |
| write-buffer-delay-slot | 0.0 | 0.1 | 0.2 | 0.3 | 0.1 | 0.2 | 41 |
| fpu-vector-state | 0.3 | 1.2 | 1.2 | 1.6 | 1.5 | 1.8 | 330 |
| alignment | 0.5 | 0.8 | 0.9 | 0.8 | 0.6 | 1.0 | 197 |
| endian | 2.3 | 2.5 | 2.8 | 2.3 | 1.3 | 1.4 | 514 |
| compat-32bit | 2.0 | 1.1 | 1.3 | 2.7 | 2.2 | 1.4 | 422 |
| y2038-time | 0.7 | 0.4 | 0.2 | 4.2 | 0.9 | 1.0 | 283 |
| timekeeping | 0.4 | 0.2 | 0.4 | 0.6 | 1.4 | 1.4 | 186 |
| interrupts | 0.1 | 0.4 | 1.8 | 2.9 | 2.7 | 3.4 | 494 |
| idle-power | 0.0 | 0.0 | 0.1 | 4.0 | 1.3 | 2.8 | 339 |
| virtualization | 0.5 | 0.8 | 0.6 | 1.0 | 3.4 | 2.9 | 402 |
| uaccess | 0.1 | 0.0 | 0.0 | 0.2 | 0.2 | 0.1 | 22 |
| tracing-patching | 0.2 | 0.4 | 0.2 | 0.2 | 0.4 | 0.1 | 63 |
| machine-check-poison | 0.0 | 0.1 | 0.3 | 0.4 | 0.3 | 0.1 | 52 |
| net-storage-fastpath | 0.0 | 0.0 | 0.1 | 0.2 | 0.2 | 2.2 | 125 |
| marker-xxx-fixme-hack | 2.9 | 2.0 | 1.3 | 1.7 | 1.1 | 1.2 | 397 |
| hardware-is-broken | 0.2 | 0.1 | 0.5 | 0.3 | 0.2 | 0.5 | 70 |

##### openbsd: subject prefixes with the most commits whose SUBJECT matches errata, workaround or quirk

| prefix | subject matches | all commits with this prefix | per 1000 |
|---|---:|---:|---:|
| drm | 99 | 3098 | 32.0 |
| sys | 7 | 191 | 36.6 |
| workaround | 3 | 3 | 1000.0 |


## Appendix C: Phase 2, the reading list and the plan

### C.1 Status

Fetched, round 1: the local documents listed in B.1, the old Unix sources of chapter 14 (read in place), 7 LWN pages (before the block), about 30 lore.kernel.org search-result pages, 24 list messages in full, 4 archive indexes and 12 reference pages (the table below). **Round 2: about 340 further pages (319 unique URLs), every one listed with its query, date, author and whether it is cited in `docs/codegen-data/kernelpain/round2-index.tsv`; counts by area are in section 14C.** **Not yet fetched** (the resume list is `docs/codegen-data/kernelpain/RESUME.md`): the rest of the mailing-list archives, the other LWN articles (blocked), the papers and talks. Items from memory are titles and authors only and are **unverified** until fetched.

Reading list with status (also `docs/codegen-data/kernelpain/reading-list.tsv`; round 2 pages are in `round2-index.tsv`). Fetched pages are saved in `~/claude/browse-output` (outside the repository).

| Source | Date | Status | Note |
|---|---|---|---|
| [KAISER: hiding the kernel from user space](https://lwn.net/Articles/738975/) | 2017-11-15 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [The current state of kernel page-table isolation](https://lwn.net/Articles/741878/) | 2017-12-20 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [Addressing Meltdown and Spectre in the kernel](https://lwn.net/Articles/743265/) | 2018-01-05 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [A look at the handling of Meltdown and Spectre](https://lwn.net/Articles/743363/) | 2018-01-09 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [Meltdown/Spectre mitigation for 4.15 and beyond](https://lwn.net/Articles/744287/) | 2018-01-15 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [MCS locks and qspinlocks](https://lwn.net/Articles/590243/) | 2014-03-11 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [LWN Kernel index (titles only; used to choose articles)](https://lwn.net/Kernel/Index/) |  | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [What is RCU, Fundamentally?](https://lwn.net/Articles/262464/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/262464/ |
| [Validating Memory Barriers and Atomic Instructions](https://lwn.net/Articles/470681/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/470681/ |
| [Memory barriers for TSO architectures](https://lwn.net/Articles/576486/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/576486/ |
| [Lockless patterns: full memory barriers](https://lwn.net/Articles/847481/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Lockless patterns: relaxed access and partial memory barriers](https://lwn.net/Articles/846700/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/846700/ |
| [Safer speculation-free user-space access](https://lwn.net/Articles/1042711/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/1042711/ |
| [The strange story of the ARM Meltdown-fix backport](https://lwn.net/Articles/749217/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2019/https://lwn.net/Articles/749217/ |
| [The impact of page-table isolation on I/O performance](https://lwn.net/Articles/752587/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/752587/ |
| [Meltdown strikes back: the L1 terminal fault vulnerability](https://lwn.net/Articles/762570/) |  | fetched through an archived copy (Wayback Machine) 2026-10-23 | archived copy: https://web.archive.org/web/2024/https://lwn.net/Articles/762570/ |
| [Fighting Spectre with cache flushes](https://lwn.net/Articles/768418/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Relief for retpoline pain](https://lwn.net/Articles/774743/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Grand Schemozzle: Spectre continues to haunt](https://lwn.net/Articles/795637/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Ticket spinlocks](https://lwn.net/Articles/267968/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Improving ticket spinlocks](https://lwn.net/Articles/531254/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [NUMA-aware qspinlocks](https://lwn.net/Articles/852138/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Huge pages part 5: A deeper look at TLBs and costs](https://lwn.net/Articles/379748/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [TLB flush optimization](https://lwn.net/Articles/684934/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [How to get rid of mmap_sem](https://lwn.net/Articles/787629/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Concurrent page-fault handling with per-VMA locks](https://lwn.net/Articles/906852/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [The trouble with the TSC](https://lwn.net/Articles/388188/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Reinventing the timer wheel](https://lwn.net/Articles/646950/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [2038 is closer than it seems](https://lwn.net/Articles/599580/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Reworking the DMA mapping code (especially on ARM)](https://lwn.net/Articles/467509/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [On the alignment of IP packets](https://lwn.net/Articles/89597/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Detecting and handling split locks](https://lwn.net/Articles/790464/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [A nasty FPU bug](https://lwn.net/Articles/89586/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [HWPOISON](https://lwn.net/Articles/348886/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Shadow stacks for user space](https://lwn.net/Articles/885220/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Kernel support for control-flow enforcement](https://lwn.net/Articles/758245/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [KAISER cr3 overhead - search results](https://lore.kernel.org/all/?q=KAISER+cr3+overhead) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:KAISER unmap most of the kernel from userspace - search results](https://lore.kernel.org/all/?q=s%3AKAISER+unmap+most+of+the+kernel+from+userspace) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"smp_read_barrier_depends" - search results](https://lore.kernel.org/all/?q=s%3A%22smp_read_barrier_depends%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"eager FPU" - search results](https://lore.kernel.org/all/?q=s%3A%22eager+FPU%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"x86, smap" - search results](https://lore.kernel.org/all/?q=s%3A%22x86%2C+smap%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"x86/mm: PCID" - search results](https://lore.kernel.org/all/?q=s%3A%22x86%2Fmm%3A+PCID%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"qspinlock" s:"PATCH v" - search results](https://lore.kernel.org/all/?q=s%3A%22qspinlock%22+s%3A%22PATCH+v%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [s:"mm: per-VMA" - search results](https://lore.kernel.org/all/?q=s%3A%22mm%3A+per-VMA%22) |  | fetched 2026-10-22 | lore search results page (subjects, authors, dates only) |
| [Re: [RFC 00/13] x86/mm: PCID and INVPCID (Linus Torvalds)](https://lore.kernel.org/all/CA+55aFxpGj2koqmcFF9JWzBeheF9473Ka516shwbuhfjVpgxrg@mail.gmail.com/) | 2016-01-08 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |
| [[PATCH v5 0/2] x86/mm: PCID](https://lore.kernel.org/all/cover.1500957502.git.luto@kernel.org/) | 2017-07-25 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |
| [[PATCH 00/23] KAISER: unmap most of the kernel from userspace page tables (Dave Hansen)](https://lore.kernel.org/all/20171031223146.6B47C861@viggo.jf.intel.com/) | 2017-10-31 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [[RFC 00/13] x86/mm: PCID and INVPCID (Andy Lutomirski)](https://lore.kernel.org/all/cover.1452294700.git.luto@kernel.org/) | 2016-01-08 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Re: [RFC 00/13] x86/mm: PCID and INVPCID (Linus Torvalds)](https://lore.kernel.org/all/CA+55aFxmc83LRHRSAsnydpqy4Y-K2V9RvRCU+dhV-kWzu2Gvpg@mail.gmail.com/) | 2016-01-08 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Re: Avoid speculative indirect calls in kernel (Linus Torvalds)](https://lore.kernel.org/all/CA+55aFzCocoK+4kxAUEhaxxba4RTv3ewBmhiZ8Osc9iDkBtCEQ@mail.gmail.com/) | 2018-01-03 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Remove smp_read_barrier_depends (Will Deacon, v1 cover)](https://lore.kernel.org/lkml/20191108170120.22331-1-will@kernel.org/) | 2019-11-08 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [[PATCH 00/18] Allow architectures to override __READ_ONCE() (v3 cover)](https://lore.kernel.org/all/20200710165203.31284-1-will@kernel.org/) | 2020-07-10 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [x86/fpu: Default eagerfpu=on on all CPUs (commit 58122bf1d856, 4.4 backport)](https://lore.kernel.org/all/20180614132724.737334115@linuxfoundation.org/) | 2018-06-14 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [arm64: hardware updates of access and dirty pte bits (thread)](https://lore.kernel.org/all/20150910153812.GG22439@arm.com/) | 2015-09-10 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [ARCv2: Check for LL-SC livelock only if LLSC is enabled (4.4 backport)](https://lore.kernel.org/all/20160725203523.360826166@linuxfoundation.org/) | 2016-07-25 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Re: [PATCH v2 1/6] xen/riscv: fix Svade/Svadu A/D bit handling](https://lore.kernel.org/all/1425dafc-9737-4776-aa65-5b0e5635e9f5@gmail.com/) | 2026-09-23 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [[PATCH 00/23] y2038 cleanups (Arnd Bergmann)](https://lore.kernel.org/all/20191108210236.1296047-1-arnd@arndb.de/) | 2019-11-08 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Current state of SVS and Meltdown (Maxime Villard)](https://mail-index.netbsd.org/tech-kern/2018/01/21/msg023000.html) | 2018-01-21 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Spectre on non-amd64 (maya)](https://mail-index.netbsd.org/tech-kern/2018/01/19/msg022992.html) | 2018-01-19 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Re: Spectre on non-amd64 (maya)](https://mail-index.netbsd.org/tech-kern/2018/01/19/msg022993.html) | 2018-01-19 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [tech-kern thread index, January 2018](https://mail-index.netbsd.org/tech-kern/2018/01/thread1.html) | 2018-01 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [[POC] performance loss due to inefficiency of kernel lock implementation (Mateusz Guzik)](https://marc.info/?l=openbsd-tech&m=176631121132731&w=2) | 2025-12-21 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [Re: amd64: much earlier Intel microcode loading (Patrick Wildt)](https://marc.info/?l=openbsd-tech&m=151743333628424&w=2) | 2018-01-31 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [openbsd-tech January 2018 listing (page 1)](https://marc.info/?l=openbsd-tech&r=1&w=2&b=201801) | 2018-01 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [freebsd-arch archive index](https://lists.freebsd.org/archives/freebsd-arch/index.html) | 2026-10 | fetched 2026-10-22 | [D] developer statement or index page, read in full |
| [freebsd-arch January 2018](https://lists.freebsd.org/archives/freebsd-arch/2018-January/subject.html) | 2018-01 | attempt failed: 503 Backend fetch failed (one try); old-style URL gave 404 | retry later |
| [Disable SMT/Hyperthreading in all Intel BIOSes (Theo de Raadt)](https://marc.info/?l=openbsd-tech&m=153504937925732&w=2) | 2018-08-23 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Re: System calls cookie, a security mitigation idea (Theo de Raadt)](https://marc.info/?l=openbsd-tech&m=176175324400465&w=2) | 2025-10-29 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Re: Does openssl know about ROP? (Theo de Raadt)](https://marc.info/?l=openbsd-tech&m=167511454301227&w=2) | 2023-01-30 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Re: Incorrect Meltdown/Spectre mitigation exceptions for AMD64 (Philip Guenther)](https://marc.info/?l=openbsd-tech&m=175289708829074&w=2) | 2025-07-19 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [proposed www pages with advice on cpu extensions](https://marc.info/?l=openbsd-tech&m=172099472920406&w=2) | 2024-07-14 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [mm: Send one IPI per CPU to TLB flush all entries after unmapping pages (Mel Gorman)](https://lore.kernel.org/all/1436189996-7220-3-git-send-email-mgorman@suse.de/) | 2015-07-06 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [arm64: Privileged Access Never using TTBR0_EL1 switching v4 (Catalin Marinas)](https://lore.kernel.org/all/1477675636-3957-1-git-send-email-catalin.marinas@arm.com/) | 2016-10-28 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [riscv: Add support for non-coherent devices using zicbom (Heiko Stuebner)](https://lore.kernel.org/all/20220706231536.2041855-4-heiko@sntech.de/) | 2022-07-06 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [add init_on_alloc/init_on_free boot options v10 (Alexander Potapenko)](https://lore.kernel.org/all/20190628093131.199499-1-glider@google.com/) | 2019-06-28 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Re: [patch 0/6] x86/fpu: Preparatory changes for guest AMX support (Thomas Gleixner)](https://lore.kernel.org/all/877dc7tj30.ffs@tglx/) | 2021-12-14 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [x86/speculation: Add prctl() control for indirect branch speculation (Gleixner)](https://lore.kernel.org/all/20181125185005.866780996@linutronix.de/) | 2018-11-25 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [(partial) Spectre v2 mitigation without IBRS on Skylake (Jan Beulich)](https://lore.kernel.org/all/5A93E52002000078001AB99C@prv-mh.provo.novell.com/) | 2018-02-26 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Transient execution CPU vulnerability (Wikipedia, pointer)](https://en.wikipedia.org/wiki/Transient_execution_CPU_vulnerability) | 2026-10 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Row hammer (Wikipedia, pointer)](https://en.wikipedia.org/wiki/Row_hammer) | 2026-10 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Meltdown and Spectre (authors' site)](https://meltdownattack.com/) | 2018 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [OpenBSD innovations](https://www.openbsd.org/innovations.html) | 2026-10 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [mimmutable(2)](https://man.openbsd.org/mimmutable.2) | 7.3 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [pinsyscalls(2)](https://man.openbsd.org/pinsyscalls.2) | 7.5 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [pledge(2) (fetched, not yet quoted)](https://man.openbsd.org/pledge.2) |  | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [unveil(2) (fetched, not yet quoted)](https://man.openbsd.org/unveil.2) |  | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [OpenBSD papers index](https://www.openbsd.org/papers/) | 2026-10 | fetched 2026-10-22 | [D]/[G]/[S] read in full |
| [Theo de Raadt, Mitigations and other real Security Features (slides)](https://www.openbsd.org/papers/bsdtw.pdf) |  | fetched, no text extractable (PDF or image slides) | retry by another route |
| [Alexander Bluhm, OpenBSD Attack Mitigations (slides)](https://www.openbsd.org/papers/eurobsdcon2023-bluhm-mitigations.pdf) |  | fetched, no text extractable (PDF or image slides) | retry by another route |
| [Theo de Raadt, Security Mitigation Techniques: An update after 10 years (image slides)](https://www.openbsd.org/papers/ru13-deraadt) |  | fetched, no text extractable (PDF or image slides) | retry by another route |
| [Google search (result was an AI summary; used only to find the primary post)](https://www.google.com/search?q=OpenBSD+disable+SMT+hyperthreading) |  | fetched, weak secondary | not cited as evidence |
| [x86, smap: Add STAC and CLAC instructions (H. Peter Anvin)](https://lore.kernel.org/all/1348256595-29119-9-git-send-email-hpa@linux.intel.com/) | 2012-09-21 | fetched 2026-10-22 | [D] read in full |
| [[patch 0/4] ticket spinlocks for x86 (Nick Piggin)](https://lore.kernel.org/all/20071101140146.GA26879@wotan.suse.de/) | 2007-11-01 | fetched 2026-10-22 | [D] read in full |
| [Re: x86: FIFO ticket spinlocks (Linus Torvalds)](https://lore.kernel.org/all/alpine.LFD.0.999.0711020950250.3342@woody.linux-foundation.org/) | 2007-11-02 | fetched 2026-10-22 | [D] read in full |
| [[RFC PATCH] rcu,alpha: avoid smp_read_barrier_depends in rcu_dereference when pointer==NUL](https://lore.kernel.org/all/485CCFB9.9050208@cn.fujitsu.com/) | 2008-06-21 | not fetched (URL from a search listing) | to read: McKenney's answer |


### C.2 The plan, in priority order

The mailing lists are the main source (the author's wording: all kernel and operating-system development lists of the past thirty years). For each pain point: what it is, who felt it and when, the workaround, the hot instruction sequence, what a developer said it cost.

| Priority | Source and query | Expected to teach | Status |
|---|---|---|---|
| 1 | lore.kernel.org search: `PTI`, `KAISER`, `retpoline`, `Meltdown`, `swapgs`, 2017 and 2018 (LKML, x86) | the cost developers measured for entry and exit mitigations, who objected | partly done: Hansen's KAISER cover letter, Torvalds on speculation, Lutomirski on PCID read; the 2017-18 patch threads on `swapgs`/entry, `IBRS` costs and the per-process switch not yet | 
| 2 | lore.kernel.org: Paul McKenney and Will Deacon on `memory-barriers`, `Alpha`, `READ_ONCE`, `dependency ordering`, `smp_read_barrier_depends` removal (linux-arch, LKML) | the ordering pain in the architects' words | not yet |
| 3 | lore.kernel.org: Linus Torvalds on `ticket spinlock`, `qspinlock`, `cmpxchg`, `LL/SC`, `unaligned`, `lazy FPU`, `LazyFP`, `SMAP` | design-level objections and costs | not yet |
| 4 | LWN.net kernel index and articles: KPTI, TLB flushing, per-VMA locks, THP, NUMA balancing, qspinlock, `NO_HZ`, y2038, CFI, shadow stacks | dated secondary accounts with measurements | not yet |
| 5 | lore.kernel.org: linux-arm-kernel, linux-riscv: `Svade`, `Svadu`, `FEAT_HAFDBS`, `TLBI range`, `PAN`, `BTI`, `swiotlb`, `non-coherent DMA` | architectural pains of the weakly ordered and non-coherent machines | not yet |
| 6 | marc.info: OpenBSD `tech@`, `misc@`: Theo de Raadt, Mark Kettenis, Philip Guenther on Meltdown/Spectre, `SMAP`, `retguard`, `pmap`, `W^X`, `pledge` | the BSD view; the OpenBSD port burden for a new architecture | not yet |
| 7 | mail-index.netbsd.org `tech-kern`, `tech-smp`, `port-vax`, `port-alpha`: pmap, TLB shootdown, cache aliasing, `bus_dma` | per-port MD pain | not yet |
| 8 | lists.freebsd.org `arch`, `current`, `hackers`: `PCID`, `ULE`, `busdma`, `pmap`, Meltdown | FreeBSD's costs and decisions | not yet |
| 9 | Papers and talks (all unverified until fetched): Lipp et al. *Meltdown* (2018); Kocher et al. *Spectre Attacks* (2018); Drepper *What Every Programmer Should Know About Memory* (2007); McKenney *Is Parallel Programming Hard* and *Memory Barriers: a Hardware View*; Gruss et al. *KASLR is Dead: Long Live KASLR* (2017, the KAISER paper); Corbet LWN pieces | secondary summaries with numbers | not yet |
| 10 | Commit-message counts (B.6) | the shape of the pain over time and per subsystem | in progress (see B.7) |
