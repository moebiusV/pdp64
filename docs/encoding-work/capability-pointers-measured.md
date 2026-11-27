# Full capability pointers (CHERI style), judged on measured memory and run time

[← encoding work](README.md) · errata 210, item 4 · measurements in `bench/capability/` (read its README first)

Written 2026-11-27. Nothing in the grammar, the manual or the ABI is changed; this is a recommendation.

## What I recommend

**Do not make every pointer a 128-bit capability in version 1. Keep stage 1 (the valid-pointer tag, granule colouring, the stack limit, the check instructions) and stay open to a later capability or bounds-in-the-pointer step.** On what I could measure, a 16-byte pointer costs **4 to 38 percent more data memory** (pointer-rich programs most), **about 12 percent more run time on pointer-chasing code that fits the caches and about 40 percent when it does not** (measured on a host, size only), and the published Morello figures are **6 to 15 percent on SPECint 2006** with a modelled 2 to 3 percent for a better core. The extra instructions are few (about 1.3 percent). What it buys is deterministic bounds on every pointer, which colouring gives only 15 times in 16 and the check instructions give only where the compiler knows the array's size.

*What it heals:* every buffer overflow through a pointer, by construction, in unmodified C, plus the compartment idea. *What we lose:* a quarter more data and a tenth to a third more time on pointer code, the LP64 ABI (a pointer no longer fits `long`), and a second register width in the core.

I would **change this** if you rank deterministic spatial safety above those costs (it is a value call, not a measurement: the first principle puts safety first, and my numbers say the price is real, not that it is too high), or if the next steps below show the price is smaller on this core. The question I would put to you is the first, in two lines: *is a certain bounds check on every pointer worth about a quarter more data and a tenth or more of run time on pointer-heavy code?*

## What was decided before, and why it is reopened

Errata 86 (2026-11-03) rejected full 128-bit CHERI and kept stage 1: a valid-pointer tag per register and per 8-byte word ("a tag bit per 16-byte granule" in `retire-stage-candidates.md` item 3, with bounds deferred, A.5.2). The reason I gave was software effort, which is never a reason (errata 209); the costs I named (memory growth, pointer size) were "from memory, not confirmed". This note measures them.

## (a) Memory growth: how much of memory is pointers

No OpenBSD or Debian userland binary for the pdp64 exists on this computer, and the pdp64 programs of the repository are small tests. So I measured proxies that share the pdp64's data model (LP64, 8-byte pointers). **Every figure here is a proxy; I say which.**

*Measured, resident data of running programs* (a stopped process's writable memory, 8-byte words that point into a mapped region; a null pointer looks like zero, so this is a **lower bound**; `ptrscan.py`; a pointer doubling from 8 to 16 bytes adds 8 bytes per pointer word, so the growth is the pointer fraction, before padding):

| program (host, Linux x86-64) | resident data | pointer words |
|---|---:|---:|
| C++ compile (clang) | 48 MiB | 38% |
| Python, 300,000 objects and dictionaries | 141 MiB | 37% |
| Perl, a hash and records | 151 MiB | 34% |
| gawk, two arrays | 189 MiB | 13% |
| SQLite, 600,000-row table | 15 MiB | 3.7% |

*Counted, static, the OpenBSD sources* (225 files of `ssh`, `make`, `less`, `sort`, `sed`, `diff`, `pax`, `ed`, `libc` stdlib compiled to LLVM IR for x86-64; `ptrir.py`): **37% of loads and 27% of stores are of a pointer** (48% and 31% weighted by LLVM's static block frequency, a stand-in for execution count, not a measurement). Structure layouts with 16-byte aligned pointers grow **25 percent when weighted by how often the code uses each type** (6% unweighted; `make` 100%, `sed` 84%, `ssh` 24%, `sort` 25%). These are static counts and a proxy, not an execution profile.

The cache cost, *measured on the host* (AMD Ryzen 5 7600, L2 1 MiB a core, L3 32 MiB; `ptrgrow.c`; only the SIZE of the pointer is modelled: each pointer slot is 16 bytes aligned, a load is still 8 bytes; two runs, pinned core; the run time of the 16-byte build divided by the 8-byte one):

| workload (nodes) | 2^10 to 2^16 | 2^17 to 2^23 | worst single size |
|---|---:|---:|---:|
| tree lookup | 1.12 | 1.39 | 2.03 (2^20, the L2 edge, noisy) |
| shuffled list walk | 1.11 | 1.22 | 2.41 (2^20) |
| chained hash | 1.01 | 1.07 | 1.51 (2^19 to 2^20) |
| control, 32-bit indices, no pointers | 0.98 | about 1.0 | 1.37 (2^23, one noisy run) |

A node of two pointers and two words grows from 32 to 48 bytes (1.5 times), of one pointer and two words from 24 to 32 (1.33 times); the run time follows the footprint where the structure crosses a cache size.

## (b) Instructions and run time of the bounds work

*Counted*, same IR: **2,614 stack objects whose address escapes in 2,151 functions** (1.2 a function), against 199,486 IR instructions: setting bounds on them would add **about 1.3 percent** instructions, one `CSetBounds` each, and only if the compiler narrows every escaping object (an assumption; sub-object bounds for address-taken fields would add more, which I did not count). 18,211 uses of a global's address (`ptr @name`): a capability from the linker's table replaces the PC-relative address, one instruction for one, with bounds set at link time. 700 calls of the allocators: the bounds are set inside `malloc`, once an allocation, a few instructions on top of a function that costs far more. Loads and stores of a pointer become 16-byte accesses: no extra instruction, but 16 bytes of cache and bus. The check is free in the access (it is part of the load or store).

*Published, not mine (the Morello pages, read on 2026-11-27):* on the Morello FPGA, SPECint 2006 (training input) pure-capability code ran **15.17 percent** slower in geometric mean, 7.72 percent after removing a data-dependent check, 6.28 percent with a larger store queue, and a model that only widens the pointer footprint (called P128) gave **2.2 to 3.2 percent** ([Initial measured performance results on Morello](https://ctsrd-cheri.github.io/morello-early-performance-results/headline-results/initial-measured-performance.html)). A different snapshot of the same living report (Cambridge UCAM-CL-TR-986) is quoted in search results as 28.01 percent falling to 5.70 percent and 1.8 to 3.0 percent for P128: *unverified* (I could not open the report's text, the numbers differ from the page above, and I take the page). A 2025 characterisation on Morello's counters ([Sweet or Sour CHERI](https://eprints.whiterose.ac.uk/id/eprint/231424/1/iiswc25_cheri_workload_characterisation_on_cheribsd_morello.pdf)) is reported to find that much of the cost is in pointer footprint and store-queue pressure; I did not read its tables, so *unverified*. The tag memory costs about 1 bit in 128 (0.78 percent, *counted*); the tag cache's extra DRAM traffic is reported below 5 percent for the vast majority of applications ([Efficient Tagged Memory](https://www.cl.cam.ac.uk/research/security/ctsrd/pdfs/20171108-iccd-tags.pdf), ICCD 2017; the abstract's figure, *unverified in the body*).

*Assumed:* the pdp64's core would behave like Morello's improved core, not its first one, so the run-time cost is **between the model (2 to 3 percent, store queue and cache sized for capabilities) and the first-core figure (15 percent)**, with my host figures (12 to 40 percent on pure pointer chasing, which is the worst case, not a SPEC mean) as the upper edge. A pdp64 core is in order with a small register file; I cannot say where in that range it falls without building it.

## (c) What the holes already closed leave to capabilities

By the ladder (prevent by construction in hardware first):

| hole | already closed by | would capabilities add? |
|---|---|---|
| a guest's stale translation of a changed second-stage table | the arena and the walker's refusal outside it (errata 207, 210) | no |
| kernel use of a user pointer by mistake | the user-memory guard, `STUA`/`CLUA`, user moves | no (a capability could carry "user" permission; the guard already does) |
| a corrupted return address | the shadow stack (the return predictor as one, candidate 6) | no |
| a stack overflowing into another | the stack limit register (candidate 4) | little |
| forging a pointer from an integer | the valid-pointer tag per word (stage 1) | no: the tag exists |
| an index past a known array | the check instructions (6,923 checks in the pcc corpus, all against an array's compile-time length) | covers also unknown lengths |
| an overflow through a pointer whose bound the compiler does not know (a buffer from `malloc`, a pointer passed to `memcpy`) | granule colouring: adjacent granules differ, **one collision in sixteen** misses | **yes: this is what a capability adds, deterministically** |
| use after free | the reserved colour of freed memory (same one-in-sixteen) | needs revocation on top; a capability alone does not close it |
| overflow inside one granule or one object | nothing | only with sub-object bounds (a compiler choice with ABI cost) |
| compartments in one address space | nothing | yes, but not a goal now |

So capabilities add one real thing: **a certain bound on pointers the compiler cannot bound**. The Microsoft security analysis of 2019 vulnerabilities is quoted as finding that CHERI would deterministically mitigate at least two thirds of them (the MSRC blog of October 2020, [Security analysis of CHERI ISA](https://msrc.microsoft.com/blog/2020/10/security-analysis-of-cheri-isa); I could not read its body, *unverified*), and a later MSRC post is quoted as about 43 percent for spatial safety alone, which fits what the table shows. I did **not** measure the fraction of memory-safety bugs that colouring plus checks already close; that needs a bug corpus (OpenBSD's errata, say) and I have none here.

## (d) The one-binary rule, the ABI, the compilers, the ports

* **One binary:** a capability machine runs one binary on every implementation, as now; the cost is on every implementation (tags, 128-bit registers), including the smallest. If the pdp64 kept 64-bit pointers for old code (CHERI's hybrid), there would be two ABIs, which the constraint does not forbid but my coherence principle dislikes.
* **ABI:** LP64 today (the manual's appendix C: pointers 8 bytes). A pure-capability ABI makes `sizeof(void*)` 16, and a pointer no longer fits `long`, `uintptr_t` becomes a capability type; code that stores a pointer in an integer (a hash of an address, a tagged pointer, `ptrdiff_t` arithmetic across objects) needs a change. I did not count such sites in OpenBSD or Debian (that is a different measurement, a source scan for casts); I do not claim a number.
* **Compilers:** pcc, our LLVM back end and gcc would each need a capability pointer type, bounds at allocation sites, and a pointer-aware `memcpy`. I did not check what LLVM 22.1.6 contains for this; it is not in the back end here.
* **Ports:** the OpenBSD kernel and libc have an assembler layer and allocators (`malloc`, the kernel's pools) that would become the bounds-setting points. Effort is not a reason; the ABI break is judged above.
* **Registers:** the registers are shared by integers, floating point and pointers (`docs/principles.md`, one register class), so a capability register is a full 128-bit register or the machine needs a second register file; either is a hardware cost I did not count in gates (assumed: the register file doubles).

## Judged by the principles, in order

1. *Safety:* capabilities win on the one row above, and are not needed on the others; the existing guards already take the cheap rungs.
2. *Speed and power:* the measured price is real (memory +4 to +38 percent, time +12 to +40 percent on pointer code, +2 to +15 percent on mixed code by the published numbers); principle 2 says to look for the mechanism that keeps the cost small.
3. *Fewer instructions:* +1.3 percent, small.
4. *Density:* the code is no denser; the data is 25 percent bigger.
5. *Compiler target:* worse, every compiler changes.
6. *Coherence:* a second pointer kind in the core.

## The cheaper step to measure next (not done)

Keep 8-byte pointers and put a **size class in the spare high bits** (25 bits at three translation levels, `design/open-items.md` J.A.1, where colours already live): a load or store compares the address against a power-of-two-aligned slot, as low-fat pointers do (a published idea, *unverified here*). It keeps the ABI and the memory, loses exactness for non-power-of-two objects, and could be checked in the same corpus. I have not designed or measured it; it is the best-of-breed candidate that "closes the hole by construction" with no memory growth.

## What would change my recommendation

* A measured capability overhead on this core design below about 3 percent and a pointer growth the pdp64 workload tolerates (for example, if the target programs are the first four in the table above rather than the first three).
* A bug corpus showing colouring plus checks leaves a large share of the real bugs open.
* You ranking certainty of bounds above the memory and time, which is your call.

## What I could not measure, and why

No pdp64 pointer-width build of any compiler exists; no OpenBSD or Debian binary for the pdp64 exists; no capability hardware is on this computer. So: pointer fractions are proxies (host processes, static IR of OpenBSD sources), run time is a host measurement of footprint only and a published number for the rest, the fraction of memory-safety bugs each protection closes is not measured, and the register-file cost is assumed.
