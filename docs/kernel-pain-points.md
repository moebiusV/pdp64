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
| Speculation family (`spectre-family`) | 496 (77) | 349 | 119 | 52 | 35 | `arch/x86` 407 of Linux's; OpenBSD `arch/x86` 110 |
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

**Evidence of size.** `Documentation/admin-guide/hw-vuln/` has 19 files and 4,164 lines; the index lists 17 separate vulnerabilities [P, counted: `ls`, `cat | wc -l`]. `arch/x86/kernel/cpu/bugs.c` has 3,830 lines, `arch/x86/lib/retpoline.S` 474, arm64's `proton-pack.c` 1,213 and `cpu_errata.c` 1,088 [P]. The x86 tree defines 45 `X86_BUG_*` flags and a 58-row model blacklist; `arch/x86/Kconfig` has 24 `MITIGATION_*` options; `kernel-parameters.txt` has 177 lines mentioning mitigations, one command-line knob per vulnerability [P, counted]. The `hw-vuln` documents state the problem in the developers' words: Spectre "exploit branch prediction and speculative execution on modern CPUs to read memory, possibly bypassing access controls" (`spectre.rst`) [G]; "iTLB multihit is an erratum" that can end in "an unrecoverable CPU lockup" (`multihit.rst`) [G]; most of the mitigations "are identical for all" variants of MDS so the kernel "treats them as a single vulnerability" (`mds.rst`, paraphrase) [G]. Per kernel, `spectre-family` vocabulary: Linux 496 code lines (407 under `arch/x86`), OpenBSD 119 (110 under `arch/x86`), NetBSD 52, FreeBSD 35 [P, counted].

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

**Errata as a phenomenon.** Counted in section 2. Further measures: `Documentation/arch/arm64/silicon-errata.rst` is a table of 176 rows; by its first column ARM 103, Qualcomm 9, Cavium 9, HiSilicon 7, NVIDIA 6, Microsoft 5, Ampere 5, Rockchip 2, NXP 2, Broadcom 2, one each for Renesas, Marvell, Fujitsu, Altera [P, counted with `awk` on the first column]. The preface of that file, by Will Deacon: "It is an unfortunate fact of life that hardware is often produced with so-called 'errata'" and classifies them A (no workaround), B (acceptable workaround) and C (minor) [G]. The `microcode` directory is 3,839 lines [P]. **pdp64:** no silicon, so no errata record; the readiness posture (precise restart, no hidden state, no mode bits) reduces the number of places to be wrong, and P4 (feature and identification registers) gives the kernel a way to learn which chip it is on. Verdict **UNKNOWN**, honestly: the first FPGA will produce the first list.

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

**Phase 2 is only started.** Evidence below is **[S] secondary** (LWN articles, read from saved copies before lwn.net blocked further requests) or a **listing** (lore.kernel.org search result pages: subjects, authors and dates, without the message bodies). The message bodies behind the listed threads are the primary evidence and are queued in Appendix C. Counts and costs are the developers' or the articles', not mine.

| Pain | What was said | Who, when | Source | Label | pdp64 |
|---|---|---|---|---|---|
| Cost of separating kernel and user page tables | The kernel is kept mapped in every process because unmapping it "would make the system run considerably slower" (no TLB flush at each crossing); a similar 4G/4G scheme of 2003 was shipped by some distributors and was dropped for its cost; the new patches "add a few hundred cycles to a syscall or interrupt", "single-digit regressions", "5% is a good round number" | the KAISER authors' patch description as quoted by LWN, 15 Nov 2017 | LWN 738975 | [S] | the exposure of chapter 4 |
| The cost estimate when merged | "a measurable run-time cost, estimated at about 5%"; a flag to turn the mechanism off on unaffected CPUs | LWN, 20 Dec 2017 | LWN 741878 | [S] | chapter 4 |
| The cost in the worst case | page-table isolation "overheads of 30% or more reported for some specific workloads"; a per-process switch was under discussion; retpolines merged in the 4.15 release candidates, with an open question about the return-stack buffer on Skylake | LWN, 15 Jan 2018 | LWN 744287 | [S] | chapter 4 |
| Spectre variant 1 cannot be found by looking | Torvalds on the `nospec` macros: he asked for "a sane way to determine when they should be needed"; speculation can run for "180 or so simple instructions" so the check and the use may be far apart | Linus Torvalds and others as quoted by LWN, 5 Jan 2018 | LWN 743265 | [S] | chapter 4: a non-speculating core has no such code to find |
| Reaction to the hardware vendor | Torvalds asked that mitigations be written with "not all CPU's are crap" in mind, i.e. that they switch off on unaffected processors | LWN, 9 Jan 2018 | LWN 743363 | [S] | feature registers (P4) are what let software do that |
| Spinlock cache-line bouncing | The simple lock makes every waiter hit one word; an MCS lock moves each waiter to its own per-CPU structure; the queued lock adds a "pending" bit for the two-waiter case; its author's benchmarks "regressed a little" on some workloads and gained 1 to 2% on others | Tim Chen, Waiman Long, Peter Zijlstra, as reported by LWN, 11 Mar 2014 | LWN 590243 | [S] | chapter 6, row 25 |
| Barrier clean-up in the tree | Will Deacon's series (June to July 2020) removes `smp_read_barrier_depends()` from the whole tree and replaces its Alpha uses with `smp_[r]mb()`; later the documentation of the remaining behaviour was still being written (2023) | listing only | lore.kernel.org search `smp_read_barrier_depends` | listing | chapter 6: the Alpha story is still alive in the archives 25 years later |
| Weak-ordering documentation burden | in 2022 to 2023 other projects (QEMU, perfbook, virtio tools) were still writing patches "explain effect of smp_read_barrier_depends() on modern architectures" | listing only | same search | listing | chapter 6 |
| TLB tags | Andy Lutomirski's `x86/mm: PCID and INVPCID` series: RFC of 13 patches on 8 Jan 2016 (with replies from Linus Torvalds the same day), a version 5 on 25 Jul 2017 | listing only | lore.kernel.org search `x86/mm: PCID` | listing | chapter 5 |
| Kernel user-access guard code is still tuned | `x86/smap` helper rewrites by Josh Poimboeuf (14 Mar 2025, with comments from Andrew Cooper and Uros Bizjak) and a "Fix the smap_save() asm" thread (15 to 17 Sep 2020, Borislav Petkov, Peter Zijlstra, Andy Lutomirski) | listing only | lore search `x86, smap` | listing | chapter 9: the guard has a code-generation cost of its own |
| Eager FPU switching | The Xen hypervisor project is moving to "always use eager-fpu" (Ross Lagerwall, Mar 2026, with Andrew Cooper), after an earlier series (Mar 2024); not Linux | listing only | lore search `eager FPU` | listing | chapter 8: the lazy approach has been abandoned even by the last holdouts |

**Not reached** (Appendix C): the message bodies; the BSD archives (lists.freebsd.org, mail-index.netbsd.org, marc.info); LWN beyond the six pages above (blocked); the papers.

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
| 1 | **The single page-table base and kernel mapped in every address space, if the core ever speculates** (E38 keeps that door open) | (b), (c) | a PTI-style switch on every entry and exit: Linux measures it as a `cr3` write of "on the order of a hundred cycles" at each; the design cost is a second base register now, versus a mitigation later | chapter 4; D6 |
| 2 | **Software accessed and dirty bits** | (c) | an extra fault per first touch and per first write of each page; Linux's arm64 default is hardware management to avoid it. Offsetting benefit: less recovery code, no walker writes | chapter 5; Q2 |
| 3 | **Uncached DMA buffers** | (c) | CPU reads of received data go to the bus; needs P6 the day a non-coherent bus master exists | chapter 7; P6, R5, R6 |
| 4 | **Machine check halts** | (b) in the broad sense | one uncorrectable memory error stops the system; Linux spends 7,111 lines on x86 alone to avoid that | chapter 13 |
| 5 | **Fault recovery in the copy routines has no mechanism yet** (exception table, `nofault` or probe) | (b) | the one place the kernel must have recovery code and the documents are silent | chapter 9 |
| 6 | **TLB invalidation granularity**: one page or all, no by-ASID, no range | (c) | N broadcasts to tear down a mapping; rollover handling | chapter 5; P5 |
| 7 | **Cross-modifying code and page-size changes have no rules** | (b) | iTLB-multihit-class and patching races | chapters 4, 12; E39 item 7 |
| 8 | **Lock scalability beyond 2 to 4 cores, interrupt controller, IPIs, virtualization, hardware breakpoints, performance counters** | all | not yet faced | R1, R2, R3, R8, P16 |
| 9 | **39-bit address space**: KASLR and ASLR entropy | security, not a principle | fewer bits to randomise | chapters 5, 12 |

**Candidate actions suggested by the evidence** (none is decided; each cites the decision that would carry it): write the "visible only after `TLBI`" and the page-size-change rules into the ISA (E39 item 7) before any second core; decide whether a second page-table base is cheap enough to reserve now (chapter 4); state the cache-index-in-page-offset requirement for any future data cache; decide the fault-fixup mechanism for copies (chapter 9), because it is the only mandatory recovery code; keep P5 (by-ASID invalidate) and P1 (wake rule) on the list; keep hardware A/D management as a later option behind a feature register (P4) so that software can stay faulting-only if desired.

## 16. What this does not show

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

*Not yet available (clones in progress).*

## Appendix C: Phase 2, the reading list and the plan

### C.1 Status

Fetched: the local documents listed in B.1 and the old Unix sources of chapter 14 (read in place). **Not yet fetched** (everything below): the mailing-list archives, LWN articles, talks and papers. Items from memory are titles and authors only and are **unverified** until fetched.

Reading list with status (also `docs/codegen-data/kernelpain/reading-list.tsv`).

| Source | Date | Status | Note |
|---|---|---|---|
| [KAISER: hiding the kernel from user space](https://lwn.net/Articles/738975/) | 2017-11-15 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [The current state of kernel page-table isolation](https://lwn.net/Articles/741878/) | 2017-12-20 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [Addressing Meltdown and Spectre in the kernel](https://lwn.net/Articles/743265/) | 2018-01-05 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [A look at the handling of Meltdown and Spectre](https://lwn.net/Articles/743363/) | 2018-01-09 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [Meltdown/Spectre mitigation for 4.15 and beyond](https://lwn.net/Articles/744287/) | 2018-01-15 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [MCS locks and qspinlocks](https://lwn.net/Articles/590243/) | 2014-03-11 | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [LWN Kernel index (titles only; used to choose articles)](https://lwn.net/Kernel/Index/) |  | fetched 2026-10-22 | LWN, secondary; read from the saved copy |
| [What is RCU, Fundamentally?](https://lwn.net/Articles/262464/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Validating Memory Barriers and Atomic Instructions](https://lwn.net/Articles/470681/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Memory barriers for TSO architectures](https://lwn.net/Articles/576486/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Lockless patterns: full memory barriers](https://lwn.net/Articles/847481/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Lockless patterns: relaxed access and partial memory barriers](https://lwn.net/Articles/846700/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Safer speculation-free user-space access](https://lwn.net/Articles/1042711/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [The strange story of the ARM Meltdown-fix backport](https://lwn.net/Articles/749217/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [The impact of page-table isolation on I/O performance](https://lwn.net/Articles/752587/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
| [Meltdown strikes back: the L1 terminal fault vulnerability](https://lwn.net/Articles/762570/) |  | not fetched: lwn.net blocked us (spam protection); only if the author allows | find the primary lore.kernel.org thread the article describes and cite that |
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
| [[RFC 00/13] x86/mm: PCID and INVPCID (Andy Lutomirski)](https://lore.kernel.org/all/cover.1452294700.git.luto@kernel.org/) | 2016-01-08 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |
| [Re: [RFC 00/13] x86/mm: PCID and INVPCID (Linus Torvalds)](https://lore.kernel.org/all/CA+55aFxmc83LRHRSAsnydpqy4Y-K2V9RvRCU+dhV-kWzu2Gvpg@mail.gmail.com/) | 2016-01-08 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |
| [Re: [RFC 00/13] x86/mm: PCID and INVPCID (Linus Torvalds)](https://lore.kernel.org/all/CA+55aFxpGj2koqmcFF9JWzBeheF9473Ka516shwbuhfjVpgxrg@mail.gmail.com/) | 2016-01-08 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |
| [[PATCH v5 0/2] x86/mm: PCID](https://lore.kernel.org/all/cover.1500957502.git.luto@kernel.org/) | 2017-07-25 | not fetched (URL captured from a search result) | to read: cost arguments for PCID and the TLB flush design |


### C.2 The plan, in priority order

The mailing lists are the main source (the author's wording: all kernel and operating-system development lists of the past thirty years). For each pain point: what it is, who felt it and when, the workaround, the hot instruction sequence, what a developer said it cost.

| Priority | Source and query | Expected to teach | Status |
|---|---|---|---|
| 1 | lore.kernel.org search: `PTI`, `KAISER`, `retpoline`, `Meltdown`, `swapgs`, 2017 and 2018 (LKML, x86) | the cost developers measured for entry and exit mitigations, who objected | not yet |
| 2 | lore.kernel.org: Paul McKenney and Will Deacon on `memory-barriers`, `Alpha`, `READ_ONCE`, `dependency ordering`, `smp_read_barrier_depends` removal (linux-arch, LKML) | the ordering pain in the architects' words | not yet |
| 3 | lore.kernel.org: Linus Torvalds on `ticket spinlock`, `qspinlock`, `cmpxchg`, `LL/SC`, `unaligned`, `lazy FPU`, `LazyFP`, `SMAP` | design-level objections and costs | not yet |
| 4 | LWN.net kernel index and articles: KPTI, TLB flushing, per-VMA locks, THP, NUMA balancing, qspinlock, `NO_HZ`, y2038, CFI, shadow stacks | dated secondary accounts with measurements | not yet |
| 5 | lore.kernel.org: linux-arm-kernel, linux-riscv: `Svade`, `Svadu`, `FEAT_HAFDBS`, `TLBI range`, `PAN`, `BTI`, `swiotlb`, `non-coherent DMA` | architectural pains of the weakly ordered and non-coherent machines | not yet |
| 6 | marc.info: OpenBSD `tech@`, `misc@`: Theo de Raadt, Mark Kettenis, Philip Guenther on Meltdown/Spectre, `SMAP`, `retguard`, `pmap`, `W^X`, `pledge` | the BSD view; the OpenBSD port burden for a new architecture | not yet |
| 7 | mail-index.netbsd.org `tech-kern`, `tech-smp`, `port-vax`, `port-alpha`: pmap, TLB shootdown, cache aliasing, `bus_dma` | per-port MD pain | not yet |
| 8 | lists.freebsd.org `arch`, `current`, `hackers`: `PCID`, `ULE`, `busdma`, `pmap`, Meltdown | FreeBSD's costs and decisions | not yet |
| 9 | Papers and talks (all unverified until fetched): Lipp et al. *Meltdown* (2018); Kocher et al. *Spectre Attacks* (2018); Drepper *What Every Programmer Should Know About Memory* (2007); McKenney *Is Parallel Programming Hard* and *Memory Barriers: a Hardware View*; Gruss et al. *KASLR is Dead: Long Live KASLR* (2017, the KAISER paper); Corbet LWN pieces | secondary summaries with numbers | not yet |
| 10 | Commit-message counts (B.6) | the shape of the pain over time and per subsystem | in progress (see B.7) |
