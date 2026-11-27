# The CHERI-derived pieces, judged one by one, and the size class

[← encoding work](README.md) · errata 237, R559 · measurements in `bench/sizeclass/` (and `bench/capability/`)

Written 2026-11-27. Nothing in the grammar, the executor, the tests or the manual is changed; this is a recommendation for you to accept or refuse. Every number is labelled **measured** (I ran it here), **counted** (a count over repository text or sources), **assumed**, or **unverified**.

## What I recommend

By your test (compelling benefit, or almost free, and still the principles in order):

* **Keep:** the check instructions (`ct`, `chk2`: built, and they save instructions) and the stack limit (about 750 NAND2, counted: 0.2 to 0.3 percent of the core, no opcode). The user-memory guard, the arena and the canonical-address rule are not CHERI pieces and stay.
* **Drop:** the valid-pointer tag, granule colouring, the reserved colours for uninitialised and freed memory, and the size class. None is almost free (colouring costs 3.1 percent of memory and a new path in the memory system; the tag breaks pointer-in-integer code; the size class costs 30 percent more heap, median, to give a coarse bound), and I could not show that any one is compelling.
* **Measure first:** the shadow stack (not CHERI; its price is the `setjmp` and unwinding work, and the repository has no number).

*What the drops heal and cost:* they give up the deterministic catch of an overflow into the next object and of a use after free, and fall back on what the machine already has (`malloc` junk and guard pages in OpenBSD, the check instructions where the compiler knows the length). Nothing built is lost: **none of the dropped pieces is in the grammar, the executor or the tests**; the cost of dropping is a few manual statements and records (listed below).

*What would change my answer:* a bug corpus (OpenBSD errata, say) showing that heap overflow and use after free are most of the bugs that matter and that guard pages and junking leave most of them open. That would make colouring compelling, and it is the one drop I would expect you to overrule on value, not on a number. I have no such corpus.

## (A) The inventory

"Specified" means in the grammar, the executor and tests. "Manual" means `docs/manual-src/`.

| # | piece | what it is in the pdp64 | where it came from | state today |
|---|---|---|---|---|
| 1 | valid-pointer tag ("stage 1") | one bit per register and per aligned 8-byte word of memory, set only by pointer-producing operations, cleared by an ordinary store and by DMA (`design/open-items.md` near line 1357; manual appendix A, statement `full-128-bit-cheri`) | CHERI's tag, without the bounds; errata 86 kept it, errata 237 reopened it | decided in outline; **not specified**: no word, no executor code, no test, no PTE bit, no cache bit |
| 2 | granule colouring | a 4-bit colour per 16-byte granule in a side table, and 4 colour bits in the pointer; a mismatch faults precisely (`retire-stage-candidates.md` item 1; appendix A `spare-bits-of-a-64-bit-pointer`) | Arm MTE and SPARC ADI (read for MTE in `retire-stage-candidates.md`; the rest *unverified*) | approved "to be specified" (errata 84); **not specified**; the pointer-bit rule is open (`open-items.md` J.A.1) |
| 3 | reserved colours | colour 0 = never written (a load faults, a store must cover the whole granule), colour 15 = freed (any access faults) (`retire-stage-candidates.md` item 2) | the study's own; MTE leaves colours to software | approved, **not specified**; depends on 2 |
| 4 | stack limit | a privileged limit register; an `SP` write below it faults (candidate 4); the manual's own statement is the cheaper "the hardware checks the stack pointer lies in a registered stack region when a system call or fault is taken" (`stack-limit-register-is-approved`) | Arm Cortex-M `MSPLIM`; OpenBSD's `MAP_STACK` check | approved, **not specified**; two forms exist in the texts (see the judgment) |
| 5 | check instructions | `ct<cc>`, `cteq/ctne` (trap if zero), `chk2`, the `check` trap (vector 16), the 12-byte `__bug_table` record, the directive `.chk` (`check-instructions.md`; manual entries `CT`, `CHK2`) | pcc's `-xchecks` and Linux's `BUG_ON` (errata 144, 145); **not CHERI** | **built**: 11 base words and 2 aliases in the grammar, executor, `as64`, `ld64`, LLVM (4 files), tests |
| 6 | bounds checks in software | `__chk_fail` and `__builtin_chk`; what a target without piece 5 uses | pcc | built (pcc) |
| 7 | sealed or tagged capability pointers | none exist. A sealed (immutable) page bit was rejected (appendix A, "Watchpoints, and what was rejected"); the 3-bit software tag (`JTAG`, `BTAG`, `BNTAG`) is a Lisp idiom, not a safety mechanism | CHERI sealing; Lisp | nothing to drop; `JTAG`/`BTAG`/`BNTAG` stay |
| 8 | the arena | the one run of real pages that holds the hypervisor's stage-2 tables, and the walker's refusal outside it (errata 207, 210; manual `guest-never-sees-a-stale`) | the study's own (it closes the stale-translation hole); **not capability thinking** | built |
| 9 | the shadow stack | the mirror shadow stack, "approved with its recommendations" (appendix A); candidate 6 makes the return predictor the architectural copy | Intel CET, Arm GCS, RISC-V Zicfiss (read in the Linux docs, `retire-stage-candidates.md`) | approved, **not specified** |
| 10 | landing pads and their page bit | `LPAD` marks legal indirect targets; a page bit faults a landing elsewhere | Intel IBT, Arm BTI | `LPAD` built; the page bit approved, not specified |
| 11 | the user-memory guard | the user-qualified moves and block copies; the kernel never uses a user pointer by accident | the study's own | built |
| 12 | the canonical-address rule | bits above the top translated bit must equal it, else fault `NONCANONICAL` (manual `addresses-are-canonical-39-48`, `translation-is-split`, the glossary entry "canonical address") | x86-64, RISC-V | built; it is what refuses software the use of the high bits |
| 13 | a "pointer" bit in the PTE or the data cache | **none**. The PTE has `V R W X U G A D MT` and the physical page number; all other bits must be zero (manual `page-table-entry-is-64`). The data cache has no tag bits. Pieces 1 to 3 would add them | | none exists |

Related but not pointer safety, so not judged here: the secret-taint lane (`SECRET`; `open-items.md` near line 1356), which would share the tag side band with piece 1.

## (B) The judgment, piece by piece

Principles in order: safety by the ladder (prevent in hardware, then by idiom, then mitigate, then cheap recovery), speed measured, fewer instructions, density, compiler target, coherent set; the one-binary rule and no hidden state across exceptions hold throughout.

**Gate counts (measured, `bench/sizeclass/blocks.v`, the repository's flow: yosys, abc to NAND2, an inverter 0.5, a flip-flop 6).** The scalar core is 219,000 to 308,000 NAND2 (`vec-gates.md`, measured earlier). A behavioural model of the logic only: no timing, no wiring, no memory arrays.

| block | NAND2 | flip-flops | gate levels |
|---|---:|---:|---:|
| stack limit: 57-bit comparator on the new `SP` plus a 57-bit limit register | 406 + 57 x 6 = **748** | 57 | 22 (comparator) |
| size-class check on one effective address (57 bits) | **475** a port | 0 | 21 |
| colour check, 4 bits, with the two reserved colours | **34** a port | 0 | 9 |
| a 1-bit tag lane in a 32-register file (3 read ports, 1 write) | 507 + 32 x 6 = **700** | 32 | not measured |

The tag lane figure is only the registers; the propagation through the ALU, the memory side band and the tag cache are not counted.

### 1. The valid-pointer tag: DROP

*Heals:* a pointer forged from an integer write (an attacker's arithmetic value used as an address). It does not stop reuse of a valid pointer, and gives no bound.
*Costs:*
* **Memory:** 1 bit in 64, 1.6 percent (counted, from the repository's own figure), as an ECC-like side band or a tag table with a cache.
* **Registers:** a 65th bit in every register and in every saved context and exception frame (hidden state that must be saved, or the principle "no hidden state across exceptions" is broken); about 700 NAND2 for the lane alone (measured).
* **Every path that moves memory** must carry or clear tags: `MCPY`, paging out and in, DMA, copy-on-write.
* **Software:** the tag is lost wherever a pointer passes through an integer. Over the 225 OpenBSD sources I compiled, the unoptimised IR has **333 pointer-integer casts** (322 `ptrtoint`, 11 `inttoptr`; 1.1 per 1000 IR instructions, counted, a proxy for source casts) and **4,233 pointer equality compares**. The ports (OpenBSD, Debian) would each need these found and judged; `uintptr_t` arithmetic is the common case. I did not scan Debian.

Not compelling (no bounds, forging is one hole among several) and not free (every item above). The principle "it is easy and cheap to be correct" fails: the safe code would be the code that avoids integers. **What would change it:** bounds in the pointer (the capability step, now declined).
*Blast radius of dropping:* manual appendix A (statement `full-128-bit-cheri`), `open-items.md` (the tag bullet and the shared side band in the taint items), `retire-stage-candidates.md` item 3, errata 84, 86 and 237, the matching register entries. Grammar, executor, tests: none.

### 2. Granule colouring: DROP (the one a value call could overrule)

*Heals:* an overflow into the next object, and a pointer forged from a neighbour's address; with piece 3, use after free. Deterministic for neighbours that differ, **one miss in sixteen** for a random colour collision (counted: 4 bits).
*Costs:*
* **Memory:** 4 bits per 16 bytes, **3.125 percent** (counted), plus a tag cache; the extra memory traffic is not measured (no model in `sim64`).
* **Hardware:** a 4-bit comparator per port is tiny (34 NAND2, measured); the cost is the side-band path, the tag cache and the coherence of tags (not counted).
* **The pointer-bit rule** (J.A.1): either the canonical rule is relaxed so that software may set high bits (a security loss in itself: today software cannot hide tags there), or the colour travels outside the pointer.
* **Allocator work (counted from my traces):** one colour write per 16 bytes at `malloc` and again at `free`. The mean allocation I traced is 52 to 19,274 bytes (sort aside), i.e. about 3 to 1,200 granules per allocation (with a block-colour word, one instruction; **assumed**).
* **Stack objects:** colouring them is a per-call cost; I did not count it.
* **Time:** not measured; there is no pdp64 run or model.

Neither compelling by a number (no bug corpus) nor almost free. By the ladder it is rung 1, and it is what Arm ships (MTE, read in the repository's study, not by me). If you rank deterministic neighbour-overflow and use-after-free detection above 3 percent of memory and a new memory path, keep it; my reading of R559 is to drop.
*Blast radius:* manual appendix A (`spare-bits-of-a-64-bit-pointer`, `full-128-bit-cheri`), glossary unaffected, `open-items.md` J.A.1 and the colour bullets, `retire-stage-candidates.md` items 1 and 2, errata 84, 237, the register entries. Grammar, executor, tests: none.

### 3. The reserved colours: DROP with 2

They need 2, and add a hazard of their own: colour 0 makes a store smaller than a granule into fresh memory a fault, so the allocator must zero with `MSET`. The candidate itself says to measure how often compiled code does that first (`retire-stage-candidates.md` item 2); no one has. Blast radius as 2.

### 4. The stack limit: KEEP, with one choice for you

*Heals:* a stack that grows past its end, a large frame that jumps a guard page (Stack Clash), a stack pivot below the limit. Rung 1 (hardware, every `SP` write).
*Costs:* **748 NAND2** (measured; 0.24 to 0.34 percent of the core), one 57-bit register in the thread context, **zero opcodes** (`MTSR`/`MFSR` slot), no pointer bits, no ABI change, no memory. Almost free by your test.
*Two cautions, from my reading of the candidate:* it checks the **lower** bound only, so a pivot to an address above the limit passes (the candidate's "pivot to a heap address" holds only when the heap lies below the stack); and a user-level stack switch (coroutines, `swapcontext`, green threads) would fault unless the kernel sets the limit by a call.
*The choice:* two forms are in the texts, the per-instruction `SLIM` of candidate 4 and the manual's check at system-call and fault entry. The second is cheaper still and is what OpenBSD does in software, but it does not stop a long computation that pivots and never calls the kernel. I would take the per-instruction form if you accept the coroutine call; otherwise the entry check.
*Blast radius of a drop:* appendix A statement `stack-limit-register-is-approved`, candidate 4, errata 84. Nothing built.

### 5. The check instructions: KEEP

Not CHERI, and the reason is instructions, not safety alone. Counted: 6,923 compiler checks in the corpus, every bound a constant; today's call-and-stub is 7.0 instructions and 26.2 bytes a check, the instruction is 1 and 4: the checked build's growth falls from +16.6 percent of instructions to +2.3 percent (`check-instructions.md`, the figures of errata 147, *not* measured with the instruction in a core). Cost: about 72 first-parcel patterns (0.11 percent, estimated by that note); the comparator is the `cb` one already there. It is rung 2 (an idiom the compiler uses) and only where the length is known: it does not bound a pointer from `malloc`.
*Blast radius if dropped* (the large one): 11 base words and 2 aliases in `spec/grammars.d` and `spec/facts/core.toml`, the executor (`common/pdp64exec_enc.inc`, `pdp64exec_corehdefs.inc`), `as64` (expansion, `.chk`, `.bugrec`), `ld64` (`__bug_table`), LLVM (4 files), tests (`tests/sim/checks.s`, `tests/asm/checks.s`, `tests/ld/chk1.s`, `chk2.s`, `tests/enc/vectors.txt`, `sys-check.S`), manual entries `CT` and `CHK2`, errata 144 to 152.

### 6. Software bounds checks: KEEP (they are the same item; they are what a target without 5 uses).

### 7. Sealed pointers, compartments: nothing exists; nothing to drop.

### 8. The arena: not part of this judgment, and I would not touch it. It closes the stale-translation hole in hardware (errata 207, 210), is built and tested, and no capability idea is in it.

### 9. The shadow stack: MEASURE FIRST

Not CHERI. Rung 1 for the return address, but the candidate's own cost is "the OS work", `setjmp`/`longjmp`, signals, threads and unwinding, and it records that OpenBSD's analysis rejected it for that (`retire-stage-candidates.md` item 6; my reading of that file, not a primary source). The repository has no count of the `setjmp` path. **What to measure:** the instructions of the shadow-aware `setjmp`, `longjmp` and unwind in the ports; you already asked for the `setjmp` path to be one instruction. I take no side until that number exists.

### 10 to 13: unchanged

The landing-pad page bit is cheap by the manual's own words (one comparator, one bit, two bytes a function; I did not measure it) and is a code-pointer check, not a capability idea; judge it separately. The user-memory guard and the canonical rule stay. There is no pointer bit in the PTE or the cache today, and dropping 1 to 3 keeps it so.

## (C) The size class

### What it would be (minimal)

* **Field:** bits 63 to 57 of the pointer, 7 bits, at every address width (the width is 39, 48 or 57 bits and one binary runs on all, so only the 7 bits that exist at the widest width can be used: the "25 spare bits" are 25 only at three levels; at five levels they are 7). 0 means unchecked, so every existing pointer, the kernel's and the stack's, works unchanged; 1 to 63 means "a slot of 2^c bytes, aligned to 2^c". 7 bits is also what Kwon et al.'s hardware low-fat pointers use (bits 57 to 63, size 2^B; read in Duck and Yap's related-work text).
* **Who sets it:** the allocator, with existing instructions: `clz`, a subtract, a shift and an `or`, **4 instructions at `malloc`** and **2 at `free`** to strip it (`shl`, `shr`; counted by writing them out, *assumed* to be the best sequence). A stack object whose address escapes needs a constant `or` (2 instructions, *assumed*): see the counts.
* **The rule that changes:** translation ignores bits 63 to 57; bits 56 down to the top translated bit must still equal it. Today the whole of 63 down to bit 38 must (manual `translation-is-split`, kernel pseudo-code `fault NONCANONICAL`); the half-select bit does not move.
* **What the hardware checks, and where it cannot:** a check on the access itself cannot see an overflow, because the neighbouring slot carries the same class. The hardware check that works is **relative to a base**: at address generation, the base register's class `c` and the effective address must lie in the same aligned 2^c block, `((EA xor base) >> c) == 0` (475 NAND2 a port, 21 gate levels after the address, measured; it can run beside the translation and fault at retire, *assumed*), and on the block operations (`MCPY`, `MSET`, ...) the first and last byte of the block. That catches `a[i]`, `p->f` and `memcpy(dst, src, n)` when the base is the object pointer. **It does not catch a pointer that walks:** after `p = p + 1` many times, `p` itself is in the next slot and a `0(p)` access passes. A check on pointer arithmetic needs the arithmetic marked (an instruction for pointer add), which is a new instruction and breaks the one-past-the-end pointer unless every request is padded by a byte. This is the same finding as the published software low-fat scheme, which instruments loads and stores **and** pointer arithmetic that escapes (Duck and Yap, CC 2016, section 4.2, read), and reports overheads from 13 percent (all optimisations, writes only) to 95 percent (base) on SPEC 2006 (read in the paper; their own x86 software).
* **Pointers in integers:** the class travels in the integer, so a round trip through `long` keeps it, which colour bits and tags cannot. But relational compares of pointers of different classes order by class first (178 relational and 4,233 equality compares in the unoptimised IR of the 225 files, counted), `%p` prints the class bits, and a hash of an address changes. Equality is safe only if every pointer to an object carries the same class, which fails where one path strips it.

### Measured

**Share of heap allocations covered, and the over-allocation** (measured, `bench/sizeclass/trace.py` over traces of 18 host programs made by `mtrace.c`, an LD_PRELOAD tracer, glibc, x86-64 LP64; programs: sort, sed, diff, grep, two awk runs, perl, python, sqlite, tar, two git runs, make, a clang and a gcc compile of OpenBSD sources, ls, find, ssh; **the host's `malloc`, not OpenBSD's, and not a pdp64 run: `../cruntime` has no allocator and no pdp64 program in the repository uses `malloc`**; Python's own small-object allocator does not call `malloc` and is not in its trace). Every allocation can be given a power-of-two slot, so coverage is 100 percent of requests; what matters is the bytes:

| rule | slot bytes over the baseline (round up to 16), at the peak of live memory | range over the 18 programs |
|---|---:|---:|
| `pow2`: next power of two | **median 1.30**, mean 1.39 | 1.04 (sort) to 1.86 (sqlite, find) |
| `pow2pg`: as `pow2` below 4 KB, and from a page up only the object's pages are mapped (the slot's tail is unmapped, as the published scheme does) | **median 1.12**, mean 1.18 | 1.00 to 1.86 |
| `pow2p1`: next power of two of size+1, so the one-past-the-end address stays inside | about 1.5 to 1.9 on small-object programs (sed 1.75, make 1.82) | not summarised |
| `q4`: four classes a doubling (a general allocator, for reference; **not** usable by the same-slot check) | about 1.02 to 1.18 | |

So a power-of-two class costs **a third more heap, median**, up to 1.9 times, or 12 percent more if large objects are page-granular; the published software scheme gets 3 percent by using multiples of 16 below 8 KB, which needs a division or a multiply per base (their section 5), not our XOR; with powers of two they report 11 percent on SPEC 2006 (read).

**The slack, i.e. how far an overflow can go unseen** (measured, same traces): the slot minus the request. Median over the 18 programs: **52 percent of allocations have slack of 0 to 15 bytes**, 27 percent 16 to 63, 2.7 percent 64 to 255; but **60 percent of the bytes** (median) sit in allocations of a page or more, where the slack is 4 KB or more unless the tail is unmapped (then the bound is the page). An allocator that places each object at the **end** of its slot (aligned to 16) makes the upward window under 16 bytes for every size; the downward window is then the slack. This is my idea; I did not measure it beyond the arithmetic.

**Stack objects** (counted, 225 OpenBSD source files, LLVM IR at `-O2`; `bench/sizeclass/sizeir.py`): 2,640 stack objects; **2,576 whose address escapes with a size known at compile time** (4 of dynamic size), 12.2 per 1000 IR instructions. 56 percent are 8 bytes or less, 62 percent 16 or less, 94 percent 1 KB or less. **974 (38 percent) are over 16 bytes**, 4.6 per 1000 IR instructions, in 391 of 2,151 functions (18 percent). A power-of-two slot, aligned to its size, would add **17 percent to the bytes** of those objects (962,113 to 1,121,440) and **needs dynamic stack realignment** in those functions (a frame pointer and an `and` on `sp`; the cost not counted). Counted instructions: 2 each (assumed), about **0.9 percent more instructions** (2 x 4.6 per 1000), against 1.3 percent for one `CSetBounds` each in the capability note. Only 43 percent of the 434 allocator calls have a constant size.

**Time:** not measured. There is no pdp64 core, and `sim64`'s timing model has no check. The hardware check is off the access path in my assumption; the software cost of the compiler marking pointer arithmetic is the published 13 to 95 percent, on another machine and another scheme.

### What it catches, against colouring alone

| bug | size class (base-relative check) | colouring | the check instructions |
|---|---|---|---|
| index or offset past the object, by more than the slack, through the object pointer | **yes, deterministic** | yes, 15 in 16 for a far jump; certain only for the neighbouring granule | only where the compiler knows the length |
| `memcpy` or block operation past the end | yes, by more than the slack (block check) | yes, per granule | no |
| a pointer that walks past the end (`strcpy` loops, `*p++`) | **no**, unless pointer arithmetic is checked | yes | no |
| overflow within the slack | no | no inside a granule | no |
| use after free | **no** | yes (with reserved colours), 15 in 16 | no |
| forged pointer | no | no | no |

The class catches only the far overflow through the base; pcc's checks already cover that form whenever the compiler knows the length (all 6,923 sites in the corpus are of that kind). The case it adds beyond the check instructions is a `malloc`'d buffer indexed past its end, or a `memcpy` through it. I did not measure how often real bugs are of that form; no bug corpus exists here.

### Recommendation on the size class: DROP

By your test: the hardware is almost free (475 NAND2 a port, 0.15 percent of the core, measured), but the whole is not: **a third more heap (median), page-aligned stack frames in 18 percent of functions, a changed canonical rule, a field that shows in every pointer and compare, and a blind spot for walking pointers and for use after free.** It is a coarse bound that costs real memory and closes less than colouring does. It is also not compelling: it adds to the check instructions only the unknown-length buffer, and only for far overflows.

*What would change my answer:* (1) colouring dropped **and** a bug corpus showing far overflows of `malloc`'d buffers are common, in which case I would revisit the size class with end-of-slot placement and `q4`-like classes plus a multiply (the published way), measured on an OpenBSD `malloc` trace; (2) an allocator that already has power-of-two slots (so the memory is already spent); or (3) a pointer-add instruction that checks the class and a measured cost below a few percent.

## What I could not measure, and what I assumed

* No pdp64 binary, `malloc` or program exists in the repository that allocates, so every allocation figure is a host replay (glibc, x86-64) of programs that are not the ports; the stack and cast counts are static counts over OpenBSD sources compiled for x86-64 (LP64), the same proxy as the capability note.
* No run-time figure for colouring, the tag, the class or the stack limit: `sim64` has no model of them. Gate counts are behavioural models, no timing or wiring; the tag lane counts registers only; the tag cache and side band are not counted.
* The instruction counts for setting and stripping the class (4, 2, 2) are my sequences, **assumed**.
* No bug corpus, so the fraction of real bugs each piece closes is not measured, and I take no side on it.
* **Precedent, only what I read:** Duck and Yap, "Heap Bounds Protection with Low Fat Pointers", CC 2016 (the PDF, read: size classes, checks on access and on arithmetic, 3 percent and 11 percent memory, 13 to 95 percent time); the abstract of Kwon et al., "Low-Fat Pointers", CCS 2013, at ic.ese.upenn.edu/abstracts/fatptr_ccs2013.html (64-bit word, 46-bit address space, 3 percent worst-case memory, about 1,100 6-input LUTs on a Virtex 6, reported 0 percent run-time overhead). I did not read that paper's body. Delta pointers, Baggy Bounds' own paper, Arm MTE's specification and SPARC ADI: *unverified* by me.

## What needs your decision

1. **Colouring and its reserved colours:** drop (my reading of R559) or keep on value. This is the only real value call.
2. **The valid-pointer tag:** drop, confirmed? It is the piece with the widest blast radius for the ports if kept.
3. **The stack limit:** keep, and which form: the per-instruction register, or the check at entry.
4. **The shadow stack:** agree to measure the `setjmp`/unwind path before judging.
5. **The size class:** drop, as above; nothing is lost that is built.
