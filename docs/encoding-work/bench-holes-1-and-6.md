# Benchmarks for two security holes: stale translations after a guest reset (hole 1) and registers left behind by a return (hole 6)

*For the owner to read. Nothing here changes the manual, the grammar, the tools, the executor, the QEMU model, the compiler back ends or a test. It answers his questions of 2026-11-25 on the two holes, with measurements. The programs and the raw results are in `docs/encoding-work/bench/holes-1-and-6/` (the index is its README.md). The earlier study, `docs/encoding-work/closing-holes-by-construction.md`, gave the options and the first gate counts; this one measures them against each other.*

*His principles, in order, are used to judge everything: safety first, then speed, then fewer instructions, then a set a programmer can keep in the head.*

*How to read the labels.* Every figure is one of three kinds. **Measured**: a program or a tool was run, and the text says which and how. **Counted**: read from a file. **Assumed**: a number chosen by me and said to be so. Nothing else is stated as a number. Gate counts are NAND2 equivalents by the repository's yosys method (a two-input NAND is 1, an inverter one half, a flip-flop 6); the scalar core is 220,000 to 310,000 of them, so 1,000 gates is about 0.4% of the core. A difference below about 10 gates is noise of the tool: the same block came out as 7,575 and 7,581 gates in two runs.

## 0. The answers on one page

**Hole 1 (a guest reset in place leaves old translations in the buffer).**

* *Do the arena and the directory both close the hole fully?* Yes for what each one watches, and only under conditions, listed in section A3. The **arena** (the hypervisor keeps all its stage-2 tables in one contiguous pool; a store into the pool, or a write of a guest's translation register, discards the guest's translations at the next entry) closes the hole for the hypervisor's tables and for a reset. It does not watch the guest's own page tables, and it needs a store by another core or a device to reach its comparator. The **directory** (hardware remembers which pages it has read as page tables and discards the translations made from a page when anything stores to it) closes the hole for every table page of both stages, including the guest's own tables, **if** it is large enough to hold every table page that a cached translation depends on, **and** if it discards those translations when it has to forget a page. It is safe when too small, but then it stops caching: in the worse case measured here it walked on 19,400 of 20,000 requests.
* *Directory against arena, measured on the repository's hypervisor tests* (full table: section A5): the arena costs about 1,300 gates for the core and the directory 8,300 to 16,800 gates for one translation buffer when sized to the 7 to 11 table pages these programs walk (more than six times as much). Cycles: the two cost the same on `hv-first` (nothing lost: the tests flush where the hypervisor needed to anyway), and on `hv-stage2` the arena adds 2.8 cycles per entry over today's unsafe behaviour, the directory 1.2, and flushing at every entry 3.3 (assumed 3 cycles per table read); against the published null-hypercall round trips of 376 to 1,300 cycles (section A4) flushing at every entry on `hv-first` is 3.7% to 12.8% of the round trip. The directory beats the arena clearly only in the churn trace (section A6): with 21 table pages and a stage-2 edit before every tenth entry, the directory with 32 slots needed 631 walks, the arena 4,724, the correct software 4,724.
* *Recommendation:* the arena first (cheap, closes the hypervisor's hole, loses nothing on an exit that changed nothing), with discard-at-every-entry as the default when no arena is set. Keep the directory as a later option; take it only with an overflow rule and a size taken from a measured working set (decisions 1 to 3).
* *A finding that changes tests:* two checks of `tests/qemu/hv-stage2.S` assert that a stale translation **is** observable after a stage-2 change without a flush. Under the arena, the directory or discard-at-every-entry those checks fail by design and must be rewritten (decision 6).

**Hole 6 (registers hold the kernel's values after a return).**

* *Where the hole is when a kernel restores user registers:* only in the registers the kernel neither restores nor sets as the result. Compiled code leaves such registers constantly: measured over 294 functions compiled by the portable C compiler (pcc), 176 (59%) leave at least one such register and the worst leaves 8; over 292 functions compiled by the LLVM back end, 215 (73%) and the worst 15. The repository's own hand-written handlers leave 1 to 6 (section B2).
* *Instructions in the return path, for each spelling* (measured per system call under `sim64 -K -t`, section B4): the kernel clears the registers by hand: one instruction per register, 0 to 12 in the cases measured (mean 1.4 for pcc and 1.8 for LLVM over the corpus; 8 or 16 if the kernel clears the whole convention blindly); restore from a saved frame: 2 instructions and 2 words per register moved; `RTI` with an immediate mask: **0 extra instructions**; the mask taken from a system register: **2 per return**, or 0 only when every return of the kernel shares one mask.
* *Which needs the fewest instructions overall in compiled code:* the immediate mask, because the mask is a constant of the return site (which registers hold user values at that return is known when the code is written) and costs nothing at run time, while a register costs a load and a write at every return whose mask differs from the last.
* *Gates (measured):* flash clear with the mask from the instruction **+2,112**; mask from a system register **+2,304**; one-shot mask register **+2,329**; lazy clear-on-read bit **+1,147**, but 2 more levels of logic on the longest path (17 to 19, measured; flash adds none); stash and restore in hardware **+18,497 for one level of nesting, +36,961 for two, +71,789 for four**, and it cannot be right without a stash per nesting level, and one more piece of hidden state for the kernel to save at a context switch.
* *Recommendation:* `RTI #mask` with the flash clear (decisions 8 to 12). Not the stash; not the register spelling.

## Part A. Hole 1: stale translations after a guest reset in place

### A1. The hole, in words for a PDP-11 programmer

A PDP-11 maps addresses through eight page registers per mode: the mapping is always in registers. The pdp64 keeps its page tables in memory, and to avoid reading them at every access it keeps a small cache of finished translations: the **translation buffer** (TLB). A **walk** is the hardware reading the table entries in memory to make one translation. A guest has two sets of tables: its own (stage 1: the guest's virtual address to the guest's idea of physical memory) and the hypervisor's (stage 2: that address to real memory). A walk through both is **nested**: each stage-1 table entry is itself found through stage 2. The manual's count for a walk with three levels in each stage is 15 table reads (n·m + n + m with n = m = 3); with stage 2 alone it is 3. Each cached translation carries a 16-bit **guest tag** so that several guests can share the buffer. `GENTER` is the instruction by which the hypervisor enters a guest (like `RTI` into it); the guest returns to the hypervisor by an **exit**.

The hole: if the hypervisor rewrites a stage-2 entry, or reuses the same stage-2 root for a freshly reset guest, and enters the guest again, the guest can still read the **old** page through a cached translation. Today the cache is discarded only by software (`TLBIA`, `TLBI`, a write of the page-table base, the address-space number or the memory-management control register, or a write of the guest register that changes the root or the enable bit), so a hypervisor that forgets leaks the old contents. The corpus probe `tests/sec-open/qemu/sec-hv-reset-inplace.S` finds it: its hypervisor rewrites stage 2 and enters again without a flush, and the probe exits with status 202 (the stale read is seen). Measured here: it makes 4 guest translation requests, 2 are served from the cache, and 1 of those is stale.

### A2. The four ways, each in a few words

**Flush at every entry.** *What:* hardware discards the guest's translations at every `GENTER`. *Closes:* all of it, for every cause (the hypervisor cannot forget: it is not asked). *Loses:* every translation the guest had built, at every exit, even an exit for one console character. Gates measured: +4 (noise; one OR gate).

**The flush bit.** *What:* a bit in the guest register: a write with the bit set discards the translations of the tag written, even when the root did not change. *Closes:* nothing by itself: it makes the correct reset one instruction, but the hypervisor can still leave the bit clear, as the probe's hypervisor leaves out the flush today. *Loses:* one bit of the register. Gates measured: +6 (noise). In the replay it behaves exactly as today (the bit is set where the program already flushes) and the hole stays.

**The arena and the "tables changed" flag.** *What:* the hypervisor tells the hardware one contiguous range of real pages, the **arena**; every stage-2 table must lie inside it and the walker refuses (an exit with its own cause) a stage-2 table outside it. A store into the arena, by anything the hardware can see, and every write of a guest's translation register at the hypervisor level (even with the same value), set one flag; `GENTER` discards every guest translation if the flag is set, and clears the flag. With no arena set the flag is always set: the safe default is discard at every entry, and the fast path is opted into. *Closes:* stale stage-2 entries, a reused root, a reset (a reset must write those registers, or it is not a reset). *Loses:* the hypervisor's allocator must draw its stage-2 tables from one pool; every store into the pool, including setting up a new table, costs one flush at the next entry; the guest's own tables are not watched. Gates measured: the two range comparators on two store ports and the refusal test 1,072; plus a clear-all input to each translation buffer, +93 each, plus the flag: about 1,300 for the core's two buffers (+1,145 measured for one buffer with everything).

**The directory of walked table pages.** *What:* a small associative store holds the pages the walker has read as tables (either stage). Each cached translation carries a mark for each directory slot it was made from. A store to a page in the directory discards exactly the translations marked with its slot. When a page must be forgotten to make room, the translations marked with its slot are discarded too (they must be: the hardware would no longer be watching the page they depend on). *Closes:* the table edit itself is the flush: no instruction, no register, no flag; for stage 2 and for the guest's own stage-1 tables. *Loses:* gates (below), two store ports (the core's and the other source), a rule for a full directory, and false discards at the grain of a page (a page holds 512 entries; a store to any of them discards everything made from that page). Gates measured: section A5.

### A3. Do they close the hole fully? The conditions, stated precisely

**The arena closes the hole for stage 2 if all of these hold:**

1. *Every stage-2 table really lies inside the arena.* The hardware enforces it: a stage-2 walk that reads an entry outside the arena exits with its own cause, so a hypervisor cannot slip a table outside. In every trace here the arena was taken as the smallest range covering the stage-2 table pages walked (hv-first: 6 pages, all of them table pages; hv-stage2: a range of 8 pages for 6 table pages; the probes: 7 for 3). A page inside the range that is not a table is a false alarm when stored to.
2. *Every store into the arena is seen.* The core's own stores are seen by the comparators; this includes the hypervisor's stores (they are the usual writers), and a guest's stores too, if the hypervisor ever maps the arena into a guest (the comparison is on the real address after translation). A store by **another core** must reach this core's comparator: on a multi-core machine every core runs the same range test on the stores that reach the shared memory, and any hit sets the flag of every core. That wiring is not in the gate count and is not built. A store by **a device** (DMA) is covered either by the same comparator on the device's write path, or, cheaper and by construction, by the IOMMU never allowing a device to write the arena. Neither is traced: the hypervisor tests have one core and no DMA into tables (the repository's IOMMU tests are separate).
3. *The flag is checked after the stores are visible.* The entry already publishes the earlier writes (a `GENTER` has the effect of `ISYNC`, `PDP64_TLB_SYNC` in the executor), so a store still in flight cannot slip past the check.
4. *The flush is ordered against walks in flight.* A walker read that began before the store but fills after the flush would put an old translation back. The flush at the entry must wait for earlier walks to finish or abandon them (the verification study cites Intel's manual for the same hazard; the model installs only completed walks, so the replay cannot show it).
5. *The hypervisor writes a translation register for a reset.* The write sets the flag even when the value is unchanged. This also covers a reset that rewrites the guest's own memory without touching stage 2: a reset has to write the guest's registers.
6. *What it leaves open:* a guest's own stage-1 tables, which live in guest memory outside the arena. A hypervisor that edits that memory while the guest is stopped, without a reset and without a register write, leaves translations made from the old stage-1 tables. That is the hypervisor changing the guest's tables behind its back; no architecture protects a guest from it, but the directory would.

**The directory closes the hole for every table page if all of these hold:**

1. *A store by the core into a directory page* discards the translations marked with it. Measured in the replay: 0 stale translations were served under it in every program, against 8 in `hv-stage2` and 1 in the probe today.
2. *A store by another core or a device* must reach the directory's second port: the same snoop wiring as the arena needs, but a full associative compare of every observed store, not a range test (this is why two ports are costed). It is not traced.
3. *Capacity.* The directory must hold every table page that any live translation was made from. When it is full and a new page must be watched, it has two safe choices, both measured: (a) forget the least recently walked page **and discard the translations marked with it**, or (b) discard every translation and start again. Forgetting a page without discarding what depends on it is the one unsafe choice, and the model never does it. Sizing: one nested walk of three levels in each stage touches at most 7 distinct pages when the stage-1 tables sit together (root, middle and leaf of each stage, and the stage-2 leaf for the data page), so a directory smaller than 7 cannot cache even one translation; a translation buffer of 32 entries spread over R regions of 2 MiB depends on about 2R + 5 pages (section A6).
4. *Stage-1 tables are reached through stage 2.* The directory records the **real** page of every entry read, after stage 2: for a stage-1 entry that is the real page that holds it, and a store to it by the guest (translated by stage 2) hits that page. The stage-2 entries read to find that page are directory pages of the same translation, so remapping the page holding a stage-1 table discards the translations too.
5. *A walk in flight when a store arrives* must be discarded rather than installed (the model installs only completed walks).
6. *False discards.* A store to any word of a watched page discards every translation made from the page: measured in the replay, of 17 discards by the directory in `hv-stage2` 8 were true (a word they had read was stored to) and 9 false. The cure, tracking at the grain of an entry or a cache line instead of a page, costs more gates and was not built.

**Discard at every entry** closes all of it for the price of the table reads that follow (section A4); the flush bit closes nothing by itself.

### A4. The measurement: a trace of the real programs, replayed under each rule

**How it was made (measured).** I copied the QEMU target's sources (`qemu-pdp64`, the authoritative copy) to a scratch directory, built a scratch model there with a hook (the patch is kept: `part-a/scratch-trace-hook.patch`), and ran the repository's hypervisor programs on it. The hook writes one line for: each entry into a guest and each exit; each translation request of a guest (its guest tag, address-space number, page, kind of access, whether the model's cache served it, and the real address of every table entry a walk read, stage 1 or stage 2); each store the machine makes, with its real address after translation; each cache operation of the architecture (`TLBI`, `TLBIA`, the register writes that discard); and each write of a translation register by the hypervisor. The installed model and every repository were not touched. The scratch model passed the same output check as the installed one (`hv-first` printed exactly the text of `tests/qemu/hv-first.out`; the programs exited with their expected status: the probe with 202).

Programs traced: `tests/qemu/hv-first.S` (a guest kernel that prints through hypercalls, takes a stage-2 fault and a virtual timer tick, enters user mode), `tests/qemu/hv-stage2.S` (the stress test of stage 2, tags and resets), `tests/qemu/hv-timer.S`, `tests/qemu/hv-vtimer.S`, the two reset probes. The mini-kernel has no hypervisor and no guest, so it appears only in part B.

**The replay (assumed model, stated).** `part-a/replay.py` plays the lines under each rule with the same rules for what discards what. A hit needs the same guest tag, address-space number, mode and page, and the rights needed. Today's rule is validated: its walk count equals the walk count of the model in all six programs (15, 72, 0, 0, 2 and 4). A translation counts as **truly stale** when a table word it was made from has been stored to since; a discard is **false** when none was. Limits, as in the earlier study: only first touches of a page after an entry are seen (the host's own buffer is emptied at each `GENTER`, so uses within a run are not logged), so every figure is a lower bound for all rules alike; the programs are tests, not workloads; no program has a second core or DMA into tables. Table reads are counted two ways: **logged** (a leaf of 2 MiB or 1 GiB ends a walk early) and **full depth** (the manual's 15, or 3 for stage 2 alone), the number the earlier study used. Cycles are assumed 3 per table read (the load-use latency of the repository's timing model); the cost of an exit and of an entry are not measured for the pdp64, so they are taken from the published figures collected in `docs/encoding-work/table-coherence-verified.md` (below).

**Results** (hardware buffer unbounded, like the model's own cache of 256; the same with a 32-entry buffer is in `part-a/results/recorded.txt` and is identical for these programs). Columns: walks, table reads logged / at full depth, stale translations served, discards by the rule (true + false), and the program's own flushes.

| program (entries; guest requests; table pages walked) | rule | walks | reads | at full depth | stale served | rule discards (true + false) | program's own |
|---|---|---:|---:|---:|---:|---:|---:|
| `hv-first` (79; 114; 7) | today | 15 | 63 | 165 | 0 | 0 | 6 |
| | flush at every entry | 113 | 502 | 1,431 | 0 | 0 + 105 | 5 |
| | arena | 15 | 63 | 165 | 0 | 0 | 6 |
| | directory | 15 | 63 | 165 | 0 | 0 | 6 |
| `hv-stage2` (38; 86; 11) | today | 72 | 215 | 312 | **8** | 0 | 55 |
| | flush at every entry | 86 | 251 | 354 | 0 | 5 + 17 | 50 |
| | arena | 84 | 246 | 348 | 0 | 5 + 15 | 50 |
| | directory | 77 | 230 | 327 | 0 | 8 + 9 | 45 |
| `sec-hv-reset-inplace` (2; 4; 3) | today | 2 | 5 | 6 | **1** | 0 | 0 |
| | flush at every entry | 4 | 10 | 12 | 0 | 1 + 1 | 0 |
| | arena | 4 | 10 | 12 | 0 | 1 + 1 | 0 |
| | directory | 3 | 8 | 9 | 0 | 1 + 0 | 0 |
| `sec-hv-reset-mmuctl` (2; 4; 3) | all four | 4 | 10 | 12 | 0 | 0 to 1 + 0 | 1 to 2 |

`hv-timer` and `hv-vtimer` make one entry and no guest translation: all rules are equal (0). The flush bit equals today in every program.

What the table says. In `hv-first` the arena and the directory lose **nothing** against today: the hypervisor's stage-2 edit there is followed by a flush it already performs, and the stores of the hypervisor into the arena (11 of 1,184 stores hit a walked table page) coincide with those flushes (the flag flushed at 3 entries, all with nothing to discard). Flushing at every entry makes the walks go from 15 to 113 (7.5 times). In `hv-stage2` the 8 stale translations of today are not a bug: the test deliberately checks that a stale translation is observable after a stage-2 change without a flush (the checks on stale translations after a stage-2 change and after a change of tag; its generator says so in its header). Every safe rule must remove them, so its extra walks are the **price of safety**, not an overhead. In the probe the directory keeps the translation of the page that was not changed and discards only the one that was; the arena and the flush at every entry discard both.

**Cycles.** Cycles for a rule = (entries) × (X + Y) + r × (table reads), with X the cost of an exit, Y the cost of an entry and r the cost of a table read; the first term is the same under every rule (the flag test and the directory compare add no cycle: assumed, they run beside the entry), so the rules differ only in the reads. The verification study `docs/encoding-work/table-coherence-verified.md` now exists (it appeared while this one was being written) and replaces the earlier assumed 20 + 20 for an exit and an entry: the published null-hypercall round trips T (an exit, a minimal hypervisor, an entry) are 376 cycles (Xen on Arm, the hypervisor in its own level, only the general registers saved), 546 to 739 (RISC-V, an FPGA model), 1,228 to 1,300 (Xen and KVM on x86, 2015), and the hardware part alone on x86 is 761 to 784. These are other machines' figures, not the pdp64's; I use T = 376, 739 and 1,300, and r = 3 (the repository's timing model; that study also shows r = 10 and 30, which I give for the largest case). Extra cycles against today, per entry, from the full-depth reads (r = 3):

| program | flush at every entry | arena | directory |
|---|---:|---:|---:|
| `hv-first` | 3 × 1,266 / 79 = 48.1 | 0 | 0 |
| `hv-stage2` | 3 × 42 / 38 = 3.3 | 3 × 36 / 38 = 2.8 | 3 × 15 / 38 = 1.2 |
| probe (per entry) | 3 × 6 / 2 = 9 | 9 | 3 × 3 / 2 = 4.5 |

With the logged reads the figures are, for `hv-first`, 3 × 439 / 79 = 16.7 for flush at every entry and 0 for the other two; for `hv-stage2`, 2.8 for flush at every entry (3 × 36 / 38), 2.4 for the arena (3 × 31 / 38) and 1.2 for the directory (3 × 15 / 38): the ordering does not change. As a share of T (an extra 48.1 cycles per entry for flush at every entry in `hv-first`): 12.8% of 376, 6.5% of 739, 3.7% of 1,300; with r = 10 the extra is 160 cycles, 43% / 22% / 12%, and with r = 30 it is 481 cycles, 128% / 65% / 37%. For `hv-stage2` the three rules cost 0.3% to 0.9% of a 376-cycle round trip (3.3, 2.8 and 1.2 cycles). So, against measured exit costs, flushing at every entry is a few percent to an eighth of a hypercall that changed nothing, **not** the doubling the earlier study computed from its assumed 20 + 20; the speed argument for the arena is weaker than the earlier study made it, and the argument that remains is safety: the hypervisor cannot forget.

### A5. The gates (measured, repository method)

The references were reproduced first. The translation buffer of 32 entries without a tag came to 7,575 logic and 2,048 flip-flops (the record has 7,589 and 2,048; the earlier study 7,581); the buffer with a 16-bit tag and an invalidate by tag 28,664 in total; the arena's comparators 1,072 and the clear-all input +101 (earlier +93); the directory of the earlier study (which discards by guest tag, too coarse) 6,030 for 8 slots on one store port and 12,112 for 16 (earlier 6,030 and 12,120). The script is `gates/run_gates.sh`; the models are `gates/h1b.v` (new) and `gates/h1.v` (earlier).

The directory the way hardware would have to build it (new model, `gates/h1b.v`): D slots of {valid, 28-bit page number}; each of the 32 buffer entries holds a D-bit mark of the slots it depends on; a store compares its page with all slots and discards every entry marked with a hit slot; a walker read of a page not in the directory takes the next slot round robin, discarding what depended on the old one. Totals include the whole buffer; the increase is against the tagged buffer (28,667).

| design (one translation buffer) | gates | increase | longest path, levels |
|---|---:|---:|---:|
| tagged buffer, today | 28,667 | 0 | 26 |
| flush at every entry | 28,893 | +4 (noise) | not measured |
| flush bit | 28,895 | +6 (noise) | not measured |
| arena, flag, refusal and clear-all (the whole proposal) | 29,812 | **+1,145** | 26 |
| directory, 8 slots, 1 store port | 35,991 | +7,324 | |
| directory, 16 slots, 1 store port | 43,226 | +14,559 | |
| directory, 8 slots, 2 store ports | 37,002 | +8,335 | |
| directory, 16 slots, 2 store ports | 45,470 | +16,803 | 38 |
| directory, 32 slots, 2 store ports | 62,243 | +33,576 | |
| directory, 64 slots, 2 store ports | 95,724 | +67,057 | |

Sized to the working set measured: the peak number of table pages live at once was 7 in `hv-first`, 6 in `hv-stage2` (11 distinct over the whole run) and 3 in the probes, so 8 slots suffice for `hv-first` (+8,335 for two ports) and 16 for `hv-stage2` with room (+16,803). The core has two buffers (instruction and data): the compare and the allocation part of the directory is shared and the marks are per buffer, so the core's figure lies between one and two times the table, about 6% to 13% of the core for 16 slots and two ports, against the arena's 0.5%. The longest path through the directory is 12 levels deeper than through the tagged buffer (behavioural depth by yosys `ltp`, not timing); the arena's is no deeper.

### A6. The worse case: a guest that churns its stage-2 tables (synthetic, measured on the generated trace)

`part-a/synth.py` generates a guest that touches 20 pages per entry out of 48 pages spread over R regions of 2 MiB (R stage-1 and R stage-2 leaf table pages, about 2R + 5 table pages in all), 1,000 entries, a translation buffer of 64 entries, full nested walks of 15 reads; before every K-th entry the hypervisor stores one word into the stage-2 leaf page of a random region (K = 0: never). "Correct software" is the hypervisor executing `TLBIA` after every edit, the baseline any safe rule is trying to beat.

| R (table pages) | K | correct software: walks | arena: walks | directory 8 / 16 / 32 / 64 slots: walks | stale uses with no flush at all |
|---|---|---:|---:|---|---:|
| 4 (13) | 10 | 4,625 | 4,625 | 19,412 / **1,213** / 1,213 / 1,213 | 843 |
| 8 (21) | 10 | 4,724 | 4,724 | 19,510 / 15,397 / **631** / 631 | 0 |
| 8 (21) | never | 48 | 48 | 19,504 / 15,353 / **48** / 48 | 0 |
| 16 (33) | 10 | 4,724 | 4,724 | 19,535 / 16,880 / 3,176 / **315** | 0 |
| 16 (33) | 1 | 16,488 | 16,488 | 19,537 / 16,917 / 4,398 / 2,682 | 571 |
| 64 (71) | 10 | 4,724 | 4,724 | 19,568 / 17,727 / 13,502 / 3,080 | 0 |

The full table (R = 4, 8, 16, 32, 64; K = 1, 10, 100, never) is `part-a/results/synthetic.txt`. Findings.

* The arena is **exactly as good as correct software** here, because a stage-2 edit makes it flush everything, as the software would: it removes the hypervisor's duty to remember (the stale uses with no flush at all, last column, show what forgetting costs: up to 2,855 stale translations served), not the cost of flushing.
* The directory is far better **when it fits**: R = 8, K = 10: 631 walks against 4,724, an 87% reduction.
* The directory has a **cliff**. When the slots are fewer than the table pages the live translations depend on, nearly every request walks (19,500 of 20,000), and the guest runs slower than under correct software (16,488 in the K = 1 row) because each walk evicts pages that other translations needed. The two rules for a full directory give the same collapse (at R = 8, K = 10 with 8 slots: discard what depended on the evicted page, 19,510 walks; discard everything on overflow, 19,403). The first is safe; it is not fast. A directory therefore needs a size taken from a measured working set, which the repository does not have for a real kernel: the hypervisor tests walk 7 and 11 pages, a kernel with a few hundred mapped pages in several regions needs many more.
* With R = 64 and 71 table pages, 64 slots keep only part of the benefit (3,080 walks against 4,724 for correct software at K = 10).

### A7. Recommendation for hole 1, in plain words

Safety: the arena and the directory both close the hole fully for what they watch; flush at every entry closes it for everything; the flush bit closes nothing. Speed: the arena equals today's cost on an exit that changed nothing and the correct software's cost after an edit; the directory beats it only when it fits; flushing at every entry costs 48 cycles per entry on a guest that makes hypercalls, 3.7% to 12.8% of a published round trip. Fewer instructions: all of them need none (the arena replaces the `TLBIA` after each edit; today's hypervisor spends one). A coherent set: the arena is one range and one flag a programmer can state in two sentences; the directory is a cache whose size is a hidden performance cliff.

**Adopt the arena, with flush at every entry as the default when no arena is set.** Keep the directory as a possible later addition for the multi-core design, where it could also replace the broadcast `TLBI`. What the verification study found about others supports this: no shipping architecture watches stores to tables (all require software to invalidate), Intel and AMD do not flush at every entry (they tag entries and flush when the hypervisor says so, as our flag does), and the one published hardware design that does watch the stores (HATRIC) uses small co-tags and the cache-coherence traffic instead of a content-addressed directory, which is a multi-core design.

## Part B. Hole 6: the kernel's registers after a return

### B1. Where the hole is, precisely

On a return from the kernel to the user, a register holds one of four things: (a) the user's own value, restored by the kernel from its saved copy; (b) the result of the call (`R0`; `R1` for a pair); (c) a callee-saved register that the compiled code preserved (a value the user's own compiler expects to survive, like `R2` to `R4` in PDP-11 C code); (d) **anything else: a value the kernel computed for its own purposes and did not overwrite**. Only (d) is the hole. If a kernel restores every register it used, or the compiler's convention says the register is dead and the kernel zeroed it, there is none. It exists because a **caller-saved** register (one a called routine may destroy) is not restored by the callee: compiled code leaves dead values in them as a matter of course, and the user's next instruction can read them. Two things make it worse than it looks. The compilers disagree on the convention (below). And hand-written paths restore some registers and not others (section B2).

### B2. Measuring it

**Method (measured).** Static: `part-b/regs_static.py` reads the assembly of each function and lists the registers written in it and in the functions of the same file that it calls; the **dirty** set is those, minus `R0` (the result), the stack pointer and the callee-saved registers (`R8` to `R11`, the frame pointer `R13`, `R15`, `R24` to `R31`, the LLVM back end's list). It is path-insensitive: a register written on any path counts, so it is an upper bound for one return. A call outside the file counts as writing `R0` to `R7` and `R12`. Dynamic: `part-b/regs_dynamic.py` assembles a driver that sets `R6` to `R13` and `R15` to `R31` to distinct poison values, sets the arguments, saves all registers, calls the function, saves them again and runs the image under `sim64`; a register that changed and is not `R0` or callee-saved is a register the function left holding a value of its own. No callee-saved register changed in any run (no violation of the convention).

**The corpus.** The 26 C programs of `tests/c` and `tests/c-new` and a new file of syscall-like handlers written for this study (`part-b/c/kern.c`: a null call, a process-table read, a copy-in and a copy-out with a range check, a descriptor-table lookup with a reference count, a hash lookup, the internet checksum, a bitwise CRC-32, one ChaCha20 block, and a dispatcher that calls them). Each was compiled with **pcc** (`build/pcc/ccom`) and with the **LLVM back end** (the host's clang `-O1` to IR with the target dropped, then `llc -mtriple=pdp64-unknown-elf -O2`, as the back end's own `check.sh` does); the assembly of both is kept in `part-b/asm/`.

| group, compiler | functions | leave at least one | mean | median | worst |
|---|---:|---:|---:|---:|---:|
| tests/c, pcc | 42 | 9 (21%) | 0.4 | 0 | 3 |
| tests/c, LLVM | 41 | 35 (85%) | 1.3 | 1 | 5 |
| tests/c-new, pcc | 241 | 159 (65%) | 1.6 | 1 | 8 |
| tests/c-new, LLVM | 241 | 172 (71%) | 1.8 | 1 | 15 |
| kernel-like `kern.c`, pcc | 11 | 8 (72%) | 2.1 | 1 | 4 |
| kernel-like `kern.c`, LLVM | 10 | 8 (80%) | 4.1 | 3.5 | 15 |
| all, pcc | 294 | 176 (59%) | 1.4 | 1 | 8 |
| all, LLVM | 292 | 215 (73%) | 1.8 | 1 | 15 |

Dynamic (one path each): the 14 calls of the kernel-like functions leave a dirty register in 9 runs (pcc, mean 1.2, worst 4) and 11 runs (LLVM, mean 2.2, worst 12); the 26 programs' `test()` calls leave one in 22 (pcc, mean 3.2, worst 6) and 20 (LLVM, mean 3.2, worst 15). Full lists: `part-b/results/corpus-summary.txt`, `dyn-kern.json`, `dyn-corpus.json`.

**The two compilers disagree about the convention.** The LLVM back end uses `R16` to `R23` freely as caller-saved scratch (7 of 292 functions leave values there; ChaCha leaves all eight), and saves `R24` to `R31` as callee-saved; pcc never touches `R16` to `R31`. The ABI document leaves `R16` to `R31` "not yet assigned". A kernel that clears "the ABI's caller-saved registers" by hand (`R1` to `R7`, `R12`: 8 instructions) therefore **leaks** whatever LLVM-compiled kernel code left in `R16` to `R23`, silently; the hardware clear cannot leak whatever the compiler's convention, and a mask that names too little only costs the user a value, loudly.

**The repository's own hand-written return paths** (`part-b/handwritten.py`, same method; "left" is written and not pushed and popped back):

| path | instructions | registers written | restored | left |
|---|---:|---|---|---|
| mini-kernel: system call `write` (`tests/qemu/mini-kernel.S`) | 20 | r0 to r5 | r1 to r5 (`pushm`/`popm`) | r0 (the result: intended) |
| mini-kernel: page fault | 24 | r1 to r3 | r1 to r3 | none |
| mini-kernel: timer interrupt | 10 | r1, r2 | r1, r2 | none |
| guest kernel (`tests/qemu/hv-first.S`): system call `write` | 6 | r0 to r2 | none | r0 (result), r1 (a pointer that ended inside the user's buffer), r2 |
| guest kernel: timer interrupt | 7 | r20, r21 | none | r20 (**the kernel's device address**), r21 (a counter): the user's own r20 and r21 are also destroyed |
| hypervisor: hypercall (print a character) | 11 | r10, r20, r21, r22 | none | all four (r22 is the console's real address; r10 a counter the hypervisor keeps in a register the guest also uses) |
| hypervisor: emulated write of the page-table base | 9 | r11, r20 | none | r11, r20 |
| hypervisor: stage-2 fault, demand map | 27 | r12, r20 to r24 | none | six (the table entry address, real pointers) |

So the mini-kernel, written with care, leaks nothing and pays for it in `pushm`/`popm` (2 instructions and 10 words on every `write`, 2 and 6 on a fault); the later hand-written paths leave kernel and hypervisor pointers in registers the user or the guest can read. That is the shape of the hole: not a bug in one handler but the absence of anything that makes the careful style the only possible style.

### B3. The four spellings, each in a few words

What the mask must name. At a return the hardware keeps the registers that **hold user values** and clears the rest. For a path whose handler modified a known set D the mask is simply the complement of D, a constant of the return site. For a system call, where the convention makes the argument registers dead, the mask is the result and the callee-saved registers (a constant of the whole kernel). A return to the **same** mode (a nested interrupt) clears nothing. A mask can keep or hide a value; it cannot bring back a value the kernel destroyed: an interrupt handler that clobbers a register the user was using must still save and restore it, and the mask then names it as the user's.

**(1) The kernel clears by hand.** *What:* one `CLR` (2 bytes) for each register dirtied, before `RTI`. *Closes:* only on the paths where the author counted correctly, under the convention of the compiler actually used; nothing checks. *Loses:* instructions on every return: 0 to 12 in the cases measured below, 8 or 16 if the kernel clears the convention blindly.

**(2) `RTI` with an immediate mask** (the owner approved `RTI #mask`: six bytes instead of two). *What:* the hardware clears every register whose bit is zero in the mask, in the return itself; there is no return to a lesser mode without a mask. *Closes:* by construction, whatever the compiler or the author forgot: a mask that is too small gives the user zeros where it should have given values, which the first test shows (a loud failure, not a quiet leak). *Loses:* four bytes per return site; the old unmasked `RTI` to a lesser mode; and **no instructions**.

**(3) The mask taken from a system register the kernel sets** (the owner's "according to a setting the kernel sets"). *What:* `MTSR` writes a 32-bit register, `RTI` uses it. *Closes:* the same, provided the register is right at every return. *Loses:* a load of the mask (an immediate move or a literal load) and the `MTSR`: 2 instructions at every return whose mask differs from the previous one. A mini-kernel has three distinct returns (system call, fault, interrupt): each must write its own. If the register is cleared by every return to "clear everything" it is safe by default and every return that keeps registers (all interrupts) pays 2; if it keeps its last value it saves instructions where paths repeat, and the forgotten-update bug returns, silently, as the previous return's mask.

**(4) Return and restore from a saved frame (today).** *What:* `PUSHM` at the entry and `POPM` at the return for every register the handler dirties. *Closes:* only for the registers listed; it is what the mini-kernel does. *Loses:* 2 instructions and, for k registers, 2k words of memory traffic at every return. By instruction count it beats a hand clear from k = 3 registers on (2 against k), by cycles it never did in the cases measured (+17 against +12 for the 12 registers of the ChaCha call, +4 against +1 for one register), because the pushes and pops cost a cycle a register.

**Stash and restore in hardware** (the owner's other idea). *Reading used (stated, since the sentence has two readings):* at every entry from a lesser mode the hardware copies the registers into a hidden stash; a return puts the copy back into every register whose mask bit is zero, and leaves the registers in the mask as the kernel left them. (The other reading, putting aside the **kernel's** values to give back at the next entry, buys the kernel nothing it can use and was not costed.) *Closes:* the same hole, and it also spares the kernel its `PUSHM`/`POPM`. *Whether it can be right:* only with one stash per level of nesting: an interrupt that preempts a system call enters again and would overwrite a one-deep stash, so the depth must be the number of priority levels the machine nests (7 below the highest). And the stash is **hidden state that belongs to a thread**: a context switch must save it and restore it, which needs new instructions to read and write it (the same objection that led to resume in place for the vector unit), or the next process gets the previous process's user values. *Loses:* state: 31 registers × 8 bytes = 248 bytes a level; gates in section B5.

**Flash clear and lazy clear.** *Flash:* every flip-flop of the register has a clear input and the return pulses the ones whose mask bit is zero. *Lazy:* one bit per register meaning "reads as zero until written"; the return sets the bits and a write clears its bit. The lazy version is smaller but every register read passes through one more gate.

### B4. Instruction counts and cycles, measured on the system-call path

`part-b/syscall_bench.py` builds, for each of six kernel-like calls and each compiler, a program in which a user loop makes 1,000 system calls to a handler that calls the compiled function and returns with `RTI`, in five variants of the return path. The set cleared or restored is the one measured dynamically for that call (section B2). `sim64 -K -t` prints one line per instruction executed: the instruction counts below are the line counts (total per call, whole loop). **The timing model of `sim64` refuses kernel mode** (`--timing does not work with -K`), so cycles could not be measured for the real path; as the nearest measurement, the same handler body was run as an ordinary function (`CALL`/`RET` instead of `TRAP`/`RTI`) under `--timing`, which gives pipeline cycles for everything except the cost of the exception entry and of `RTI`, which the repository does not model at all. `RTI #mask` and the mask register do not exist in the simulator or the model, so they were not run: the mask-in-the-instruction variant is the lazy one (the same instructions), and the register variant adds two stand-in instructions (a load of the constant and a move).

Extra instructions (and extra cycles) against the lazy kernel, per system call:

| compiler, call | registers left | lazy: instructions (cycles) | (1) clear | (2) immediate mask | (3) register | (4) frame |
|---|---|---:|---:|---:|---:|---:|
| pcc, null call | none | 6.0 (16) | 0 (0) | 0 | +2 (+3) | 0 |
| pcc, descriptor lookup | none | 14.0 (26) | 0 (0) | 0 | +2 (+2) | 0 |
| pcc, checksum of 100 bytes | r1, r2 | 416 (535) | +2 (+2) | 0 | +2 (+3) | +2 (+2) |
| pcc, copy-in of 64 bytes | r1 | 282 (433) | +1 (+1) | 0 | +2 (+2) | +2 (+4) |
| pcc, CRC-32 of 100 bytes | r2 to r5 | 7,913 (10,328) | +4 (+4) | 0 | +2 (+3) | +2 (+2) |
| pcc, ChaCha block | r1 | 3,735 (5,750) | +1 (+1) | 0 | +2 (+2) | +2 (+4) |
| LLVM, null call | none | 6.0 (16) | 0 (0) | 0 | +2 (+3) | 0 |
| LLVM, descriptor lookup | r2 | 18.0 (28) | +1 (+1) | 0 | +2 (+2) | +2 (+4) |
| LLVM, checksum of 100 bytes | r1, r2 | 415 (530) | +2 (+2) | 0 | +2 (+3) | +2 (+2) |
| LLVM, copy-in of 64 bytes | r3 | 275 (417) | +1 (+1) | 0 | +2 (+2) | +2 (+4) |
| LLVM, CRC-32 of 100 bytes | r2 to r6 | 8,613 (10,524) | +5 (+5) | 0 | +2 (+3) | +2 (+3) |
| LLVM, ChaCha block | r1, r2, r6, r7, r16 to r23 (12) | 2,520 (2,620) | **+12 (+12)** | 0 | +2 (+2) | +2 (**+17**) |

(A call that leaves nothing needs no clear and no restore; the table shows the cost of the spelling with what each call actually left.) Over the whole corpus of section B2 the static totals are, for all 294 pcc functions and all 292 LLVM functions: clears 414 and 521 instructions, frame restore 352 and 430 instructions (2 for each function that leaves something), register mask 588 and 584 (2 for each function), immediate mask **0**. A kernel that clears the convention blindly spends 8 instructions on every return for pcc, 16 for LLVM.

**Which needs the fewest instructions overall in compiled code: the immediate mask**, and the reason is in the table: it is the only spelling whose cost does not depend on what the code did. Clearing by hand costs the count of registers dirtied (a function of the compiler and the code, up to 12 here, 15 in a corpus function); the frame costs 2 instructions plus the traffic and its cycles grow with the number of registers (17 extra cycles for the 12 registers of the ChaCha call); the register costs 2 at every return whose mask differs from the last. A mask given in the instruction is a constant that the assembler or the compiler writes from what it knows, at no run-time cost. By cycles the order is the same, with the proviso that the exception entry and `RTI` themselves are not modelled.

**Hand-written paths of section B2 under each spelling.** The mini-kernel `write` could drop its `pushm` and `popm` (2 instructions, 10 words) with the mask "result and callee-saved"; its fault and timer returns keep their save and restore (the user's values are live) and the mask names them (the complement of what was dirtied, so nothing). The guest kernel's system call returns with r1 and r2 cleared for free instead of two `CLR`; its timer handler **must** gain a `pushm`/`popm` of r20 and r21 whatever the mask (the mask hides the kernel's values, it does not restore the user's), and the hypervisor's paths clear 2 to 6 registers free instead of 2 to 6 `CLR`.

### B5. The gates (measured, repository method, same way of writing both sides)

Register file of 32 registers × 64 bits, 3 read ports, 1 write port (`gates/h6.v` and `gates/h6b.v`). The base reproduces the earlier study (27,593); the earlier flash +2,112, lazy +1,147, marker bits +3,178 and second register set (+39,102 here, +39,112 earlier) were reproduced.

| design | gates | increase | % of core (at 265,000) | longest path, levels |
|---|---:|---:|---:|---:|
| register file today | 27,593 | 0 | 0 | 17 |
| (2) flash clear, mask from the instruction | 29,705 | **+2,112** | 0.8% | 17 |
| (3) flash clear, mask from a system register | 29,897 | +2,304 | 0.9% | 17 |
| (3) the same, one-shot (reset by every return) | 29,922 | +2,329 | 0.9% | |
| lazy clear (one bit a register), mask from the instruction | 28,740 | **+1,147** | 0.4% | 19 |
| a marker bit per register (the owner's earlier taint idea) | 30,771 | +3,178 | 1.2% | |
| stash of all 31 registers, one level | 46,090 | +18,497 | 7% | 17 |
| stash, two levels | 64,554 | +36,961 | 14% | |
| stash, four levels | 99,382 | +71,789 | 27% | |
| stash of the 16 caller-saved registers only, one level | 37,905 | +10,312 | 3.9% | |
| second register set for the kernel | 66,695 | +39,102 | 15% | |

Flash against lazy: flash costs 965 gates more (0.4% of the core) and adds no level on the longest path; lazy adds 2 levels (17 to 19, behavioural depth by yosys, not timing; whether the register read is on the critical path of the pipeline was not examined). The immediate mask adds no flip-flop of its own beyond the instruction's field; the register spelling adds 32. The mask in the instruction is also wired from the decoder: the 32 mask bits must travel with the `RTI` to the point where the clear happens, which the model takes as an input and does not cost.

### B6. Recommendation for hole 6, in plain words

Safety: spellings (2) and (3) and the stash close the hole by construction; (1) and (4) leave it where the author forgets or the compiler's convention differs (shown: `R16` to `R23`). Speed: (2) has no run-time cost; (3) two instructions per return; the stash saves the kernel's `PUSHM`/`POPM` but its state and its nesting problem are the price. Fewer instructions: (2), zero. A coherent set: (2) is one rule, "a return to a lesser mode says what the user may see", checked by the hardware; (3) adds a register to remember; the stash adds hidden state.

**Adopt `RTI #mask` with the flash clear.** The mask is the complement of what the handler dirtied, or, for a system call, the result and the callee-saved registers. Write the callee-saved set into the ABI document (it is today partly "not yet assigned"). Apply the same mask to `GENTER` so the hypervisor's registers are not visible to a guest (the hypervisor paths above leave 2 to 6).

## What I could not do, and what is assumed

* **The pdp64's own exit and entry cost.** The verification study gives published figures of other machines (376 to 1,300 cycles for a null hypercall); nobody has measured the pdp64's, which depends on how much state `GENTER` and an exit switch. The per-rule figures are therefore given as a share of T, with r = 3 assumed for a table read (and 10, 30 for the largest case).
* **Other cores and DMA.** The hypervisor tests have one core and no DMA into tables: the conditions on stores by other cores and devices (A3) are argued, not traced; the wiring they need is in neither gate count.
* **The tests are small.** 79 and 38 entries, 7 and 11 table pages: a real kernel's working set, which fixes the directory's size and the arena's false alarms, is not measured. Only first touches after an entry are traced (a lower bound for every rule alike).
* **Hole 6 has no hardware to run.** `RTI #mask`, the mask register and the stash do not exist in `sim64` or the QEMU model; their instruction counts are counts of the sequences, and the cycles are from the surrogate (the body run as a function under the timing model), which does not include the exception entry or `RTI`. The timing model refuses kernel mode.
* **Static counts are path-insensitive** (an upper bound), and the dynamic ones are one path each; the 26 `test()` programs often fold to constants, so many of their dynamic counts are small.
* **The dependency-bitmap directory is my own model**, built because the earlier model discarded by guest tag; it is synthesised but never run as hardware. The depth figures are behavioural.
* **The stash has two readings** and only one was costed; the choice is stated in B3.
* **Not verified against other architectures this time:** nothing in this study rests on another architecture's behaviour; the earlier study's verified quotations stand.

## Decisions for the owner

1. **Close hole 1 with the arena and its flag as the first version?** *Closes:* stale translations after any store by the core into the hypervisor's stage-2 tables or any write of a guest's translation register, so a reset in place cannot leave old translations (conditions in A3). *We lose:* about 1,300 gates (0.5% of the core), the hypervisor's freedom to allocate stage-2 tables anywhere, and one flush after every edit (15 of 20 discards in `hv-stage2` were false alarms). *Recommendation:* yes.
2. **Build the directory of walked table pages instead, or as well?** *Closes:* the same, plus the guest's own tables, and it drops the flush after an edit when the guest's working set fits. *We lose:* 8,300 to 16,800 gates per buffer for 7 to 11 pages (3% to 6% of the core for one buffer, up to twice that for two), a store port for other cores and devices, false discards at the grain of a page, and a performance cliff when the working set exceeds the slots (19,400 walks of 20,000 requests measured). *Recommendation:* no for now; revisit with the multi-core design and a measured kernel working set.
3. **Is flush at every entry the default whenever no arena is set?** *Closes:* the hole completely for a hypervisor that has not opted into the fast path. *We lose:* about 48 cycles per entry on `hv-first` (assumed 3 cycles per table read): 3.7% to 12.8% of a published null-hypercall round trip. *Recommendation:* yes.
4. **Must the walker refuse a stage-2 table outside the arena?** *Closes:* a table that the arena does not watch. *We lose:* a hypervisor that keeps tables in two places must use the default instead. *Recommendation:* yes.
5. **Stores by other cores and devices: a range test on the stores that reach the shared memory, and the IOMMU never lets a device write the arena?** *Closes:* the multi-core and DMA gaps of the arena. *We lose:* wiring on every core (not yet costed) and a rule for the IOMMU. *Recommendation:* yes, when the multi-core design is written; until then one core.
6. **Declare that a guest never sees a stale translation of a changed stage-2 table, and rewrite the two checks of `tests/qemu/hv-stage2.S` that assert the opposite?** *Closes:* the observable hole. *We lose:* those two checks as written (8 stale translations in the trace) and the ability to test the old behaviour. *Recommendation:* yes.
7. **Drop the flush bit in the guest register?** *Closes:* nothing; it adds a way to forget. *We lose:* one bit of the register. *Recommendation:* drop it.
8. **Make `RTI #mask` the only return to a lesser mode, the mask naming the registers that hold user values, hardware clearing the rest in the return?** *Closes:* the registers-after-a-return hole by construction (59% to 73% of compiled functions leave at least one register). *We lose:* four bytes at each return site, the old unmasked `RTI` to a lesser mode, 2,112 gates (0.8% of the core), and zero instructions. *Recommendation:* yes.
9. **Spell the mask as a system register instead?** *Closes:* the same. *We lose:* 2 instructions at every return whose mask differs from the last, 192 more gates, and a silent stale-mask bug if the register keeps its value. *Recommendation:* no; use it only if the six-byte form cannot be encoded, and then make it one-shot (reset to clear-all by every return).
10. **Flash clear or lazy clear?** *Closes:* the same. *We lose:* flash 965 gates more than lazy; lazy adds 2 levels of logic to the register-read path (17 to 19 measured). *Recommendation:* flash.
11. **Build the hardware stash and restore?** *Closes:* the same hole and saves the kernel's `PUSHM`/`POPM`. *We lose:* 18,497 gates a level and 248 bytes of hidden state a level, a stash per nesting level (up to 7), and new instructions so that a context switch can save it. *Recommendation:* no.
12. **Apply the same mask to `GENTER`, and write the callee-saved set (`R8` to `R11`, `R13`, `R15`, `R24` to `R31`) and the status of `R16` to `R23` into the ABI?** *Closes:* the hypervisor's registers visible to a guest (the hypervisor paths in `hv-first.S` leave 2 to 6), and the disagreement between pcc and LLVM about what is scratch. *We lose:* four bytes in the hypervisor's entry code and a paragraph of the ABI. *Recommendation:* yes.
