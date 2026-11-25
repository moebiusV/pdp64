# Should RTI reuse the mask that GENTER set? A measurement

*For the owner to read. Nothing here changes the manual, the grammar, the tools, the executor, the QEMU model, the compilers or a test. It answers the question of 2026-11-25: "how often would rti use the same mask as genter? what if rti just reused what its corresponding genter set? just curious. bench it." The programs and raw results are in `docs/encoding-work/bench/rti-mask-reuse/` (the index is in the last section). It builds on `docs/encoding-work/bench-holes-1-and-6.md`, part B, and uses the same gate method (NAND2 equivalents by yosys; a flip-flop is 6).*

*How to read the labels.* **Measured**: a program or tool was run (the QEMU model executed the programs one instruction at a time and logged the program counter; the rest is computed from that log). **Counted**: read from a file. **Assumed**: chosen by me and said so. A difference below about 10 gates is noise of the tool.

## 0. The answer in a few lines

* **How often is an RTI's mask the same as the GENTER's?** In the code that exists, almost never, and the sample is small. Only one program, `tests/qemu/hv-first.S`, has a return to a lesser mode inside a guest's run: two of them (the guest kernel starts its user program; the user's one system call returns). The start return needs "nothing" and the first GENTER also passes "nothing", so with the careful way of choosing masks they are **equal for 1 of 2**; with the other way (all registers except those the code dirtied) **0 of 2**. Against the GENTER just before the return (a hypercall re-entry) **0 of 2** both ways. The reason is not bad luck: a system call return keeps "the result and the callee-saved registers", a hypercall re-entry keeps "everything the hypervisor's handler did not dirty". They are facts known to different code.
* **A mask latched by the last return (any kind of latch) is equal to the next return's mask often when one kind of return dominates, and that is exactly when it does not matter.** In a two-process kernel I wrote for this (651 returns to user mode, 92% of them system calls) a single latch already holds the right mask for 84% of returns, or 99% if the kernel restores everything. In the hypervisor tests the re-entry after a hypercall finds its mask in 74 of 77 cases, but all of those come from one GENTER instruction whose mask never changes.
* **Instructions: none saved, none added.** `RTI #mask` already costs no extra instruction. What a latch can save is **4 bytes** at each return site that is sure to find its mask (2 of 4 sites in the careful mini-kernel, 0 of 4 with one latch in the two-process kernel, 3 of 4 with one latch per kind of return). Switching a per-process or per-guest latch costs 4 instructions per switch (about 1% of the instructions of the two-process run).
* **Gates (measured):** the decided design (mask in the instruction) is **+2,112** over today's register file (27,593). A single latch on top of it adds **+192** (set only by GENTER), **+378** (long form sets, short form reuses), **+572** if it can be read and written by `MFSR`/`MTSR` for a switch, and **+1,269** for one latch per kind of return; a latch per nesting level adds +692, +1,304, +2,642 for 2, 4, 8 levels. The longest path stays at 17 levels in every case measured.
* **Risk: it is the "silent stale mask" the earlier study rejected, and worse in one way.** With a latch, the mask of a return depends on which return happened last, and in a kernel that is decided by when the timer ticks. In the two-process kernel, if every system call return used the short form, **52 of the 105 returns that find the wrong mask would leave a kernel register in the user's hands and 14 would clear a register the user is about to read** (the leak count was 20, 52, 61, 73 in four runs: the timer is not deterministic). A register-spelling bug is the kernel forgetting to write it; this one needs no mistake by the programmer.
* **Recommendation: keep `RTI #mask` and `GENTER #mask` with the mask in the instruction. Do not build a latch.** The one thing worth taking from the idea is smaller: allow a plain two-byte `RTI` for returns to the **same** mode only (116 of the 767 `RTI`s of the two-process run were such returns, and they ignore the mask), and make a plain `RTI` that would go to a lesser mode an illegal instruction. A finding that matters more than the question: **all six hypervisor programs keep a value of their own in a register across a guest's run** (counters in `r10` to `r12`, a resume address in `r20`, a device address in `r13`); a `GENTER` whose mask clears registers destroys them, so these programs must move such values to memory (section 4.4).

## 1. What was measured and how

### 1.1 The programs, the trace and the masks

* **The programs.** `tests/qemu/mini-kernel.S` (one process, system call, page fault, timer); `tests/qemu/hv-first.S` (a hypervisor, a guest kernel, a user program: 79 `GENTER`, a system call, a timer interrupt, hypercalls); `hv-timer.S`, `hv-vtimer.S`, `hv-stage2.S` (38 `GENTER`; the guests are small probes), `sec-hv-reset-mmuctl.S`, and `tests/sec-open/qemu/sec-hv-reset-inplace.S`. **No program in the repository switches between processes**, so I wrote one: `bench/rti-mask-reuse/asm/twoproc.S` (a copy of the mini-kernel's boot and handlers, two user processes that each make 300 system calls and keep a counter in `r8` and a checksum in `r9`, a timer that switches processes with a kernel stack each, one process started fresh by `RTI`). It runs to the end with status 0 and its checksums are right.
* **The trace (measured).** `tools/run_trace.sh` runs each program on the QEMU model with one instruction per block and logs every program counter. `tools/events.py` reads the log and finds every executed `RTI`, `GENTER`, `TRAP` and `HALT` and the instruction that ran next (where the guest or the user resumes).
* **Which registers must survive (measured plus computed).** `tools/prog.py` reads each instruction's registers and computes, for every point, the set of registers the code that follows reads before it writes them (static liveness over the whole program, with a call returning to every return point, a trap reading its argument registers, and a system call writing `r0`). Called **O**. For a return that resumes at a known point, O is the exact set that has to survive; nothing else would be missed if it were cleared. O is an oracle: the kernel does not know where an interrupt will land.
* **Which registers hold the kernel's or hypervisor's own values (measured plus computed).** `tools/analyse.py` follows the trace: for a return to user mode, every register the kernel code wrote since the last user instruction, minus those put back by `POPM`; at a process switch also the registers still holding the other process's values; for `GENTER`, every register the hypervisor wrote since the guest last ran. Called the **dirty** set. A register in the dirty set that stays in the mask is a leak; a register in O that is left out is a loss.
* **The masks a programmer would write, two ways (assumed rules, applied to the measured sets).**
  **K1**, "the complement of what the code dirtied": all registers except the dirty set (`r0` kept at a system call, it is the result).
  **K2**, "the convention": a system call keeps `r0` and the callee-saved registers (`r8` to `r11`, `r13`, `r15`, `r24` to `r31`); a fresh start (user program, new guest) keeps nothing; an interrupt, a fault or a re-entry after an exit keeps the K1 mask. K2 also assumes the kernel has dropped its `PUSHM`/`POPM` of `r1` to `r5` around system calls because the return now clears them, so its dirty set at a system call is everything the handler wrote.
  Both are constants of the return site, which is what the decided design makes them. `RTI #mask`, the mask register and any latch do not exist in the simulator or the model, so no mask was run: the programs run as they are and the masks are computed from the trace.

### 1.2 The two designs, said precisely

**B, decided: `RTI #mask` and `GENTER #mask`.** The mask is in the instruction (six bytes). On a return to a lesser mode the hardware clears every register whose bit is zero in the same step; a return to the same mode clears nothing. No state. Whatever the programmer writes is exactly what is used at that return.

**A, reuse: `RTI` with no immediate (two bytes).** The hardware holds a 32-bit **latch** L. A short `RTI` clears by L. What sets L is the question, so I measured three ways of setting it:

* **A1, the owner's literal idea.** Only `GENTER #mask` writes L; every `RTI` in that guest's run uses it. (A kernel with no hypervisor under it has no `GENTER`; L then holds its reset value, which I tried as "keep all" and as "keep none".)
* **A2, "the last return sets it".** A long `RTI #mask` uses its immediate and also stores it in L; `GENTER #mask` also stores it; a short `RTI` uses L. This is the idea with the least that can be said against it.
* **A3, one latch for each kind of return** (start, system call, fault or interrupt, `GENTER`), set by the long form of its kind and then left alone. I add it because it is what A2 has to become to work, and because it is the "mask in a system register" spelling of the earlier study with four registers.

**Where the latch lives, and why.** I measured one latch for the core, one for each level (the code that runs `GENTER`, the code that runs `RTI`), one per process (saved and restored at a switch), and one per kind of return. A latch **per nesting level** has nothing to do: a return to the same mode neither reads nor writes the latch, so a nested interrupt never touches it; the latch per level behaves exactly like the single latch in every trace, by construction, and costs more (section 3). A latch **per process or per guest** is the natural place for "what its corresponding `GENTER` set", and it must be saved at an exit or a switch: `MFSR` and a store, then a load and `MTSR`, **4 instructions per switch**, and a new system-register number. It does not remove the hazard (section 4.2), because what breaks a latch is the order of returns **inside** one process, not the switch between two. I therefore take **A3 as the fair best case of A**, and A2 with one core latch as the plain case.

**"Equal" means** for a return: the mask the site would carry under B (K1 or K2) is the value in the latch just before it. A **hit** is that. A **miss** under A1 is a wrong mask; under A2 and A3 it costs nothing in instructions (the long form is the decided instruction) but the site cannot be a short form. The first use of a latch finds nothing in it; I count that as "cold" and assume a boot-time setting covers it.

## 2. What has to survive at each return, in the code that exists

(Every table row is measured; the sets are O and the dirty set of section 1.1.)

**Native kernel, `mini-kernel.S` (8 returns to user).** System call `write` (3): O is `{}` (the user writes `r1`, `r2` before it reads them); the handler dirties only `r0`, the result, because `PUSHM`/`POPM` put back `r1` to `r5`. Page fault (1): O is `{r3,r5}`, the registers of the store that is run again; nothing dirty. Timer (3): O is `{r4}` or `{}`, depending on where the user loop was interrupted; nothing dirty. Start (1): O is `{}`; dirty `{r1,r2,r3,r13}`. K1 masks: all registers for the call, the fault and the timer (the kernel restores everything), start clears `r1` to `r3` and `r13`. K2: system call returns with the convention mask.

**Two-process kernel, `twoproc.S` (651 returns to user and 116 returns to the same mode).** System call (598): O is `{r8,r9}` (callee-saved by the convention, as it should be). Timer return to user (51): O is `{r8,r9}`, `{r1,r8,r9}` or `{r1,r2,r8,r9}`, so a real kernel must return all registers (its handler saves `r0` to `r9`). Start (2). 161 of the 651 returns go to a different process than the one that last ran in user mode (51 timer returns, 109 system calls that were interrupted and resumed after the other process ran, and one start). A return after a switch needs the **incoming** process's registers: restored from its stack, so the mask is "all", and the registers of the process that ran last must be either restored or cleared: in the first start of process B they are not (`r0`, `r1`, `r2`, `r8`, `r9` still hold process A's values): mask zero is what closes that.

**Hypervisor and guest, `hv-first.S`.** The guest kernel's `GENTER` sites (four) and the two guest returns:

| site | executions | what the guest reads next (O) | what the hypervisor dirtied | K1 mask | K2 mask |
|---|---:|---|---|---|---|
| `GENTER` first entry | 1 | `{}` | `r0..r3, r10..r12` | all but those | none |
| `GENTER` after a hypercall | 76 | `{r1}` (60), `{r1,r2}` (16) | `r10, r20, r21, r22` | all but those | same |
| `GENTER` after the emulated write of the page-table base | 1 | `{}` | `r11, r20` | all but those | same |
| `GENTER` that runs the faulting store again | 1 | `{r1,r13}` | `r12, r20..r24` | all but those | same |
| `RTI` start of the user program | 1 | `{}` | `r0..r3` | all but those | none |
| `RTI` after the user's `write` | 1 | `{r0}` (the exit status) | `r0, r1, r2` | all but `r1,r2` | convention |

The other hypervisor programs: in `hv-stage2.S` the 38 `GENTER` resume probes that read `{}` (28 times), `{r13}` (5), `{r2,r13}` (2), `{r1,r2}` (2), `{r20}` (1); a guest `HALT` is an exit and needs nothing. `hv-timer.S` and `hv-vtimer.S` have one `GENTER` each (O `{r1}` and `{}`: the first guest reads a register nobody set). Their `RTI`s return to the same level.

**Compiled code, as a system-call body (counted from the earlier study's assembly, `tools/corpus_masks.py`).** For each function the K1 mask is all registers except those it can leave dirty. Over 294 functions compiled by pcc there are 25 different masks (40% leave nothing dirty); over 292 compiled by the LLVM back end, 25 as well (26% leave nothing). If the calls came in random order the chance that a one-slot latch already holds the next function's mask is **21%** (pcc) and **16%** (LLVM). The K2 mask is one for all of them.

## 3. Instructions, bytes and gates

### 3.1 Per scenario (instructions are counted from the real sequences; cycles were not measured, nothing models `RTI`)

| scenario | design B (decided) | design A, one latch | design A3, a latch per kind |
|---|---|---|---|
| **System call return** (598 in the two-process run; 3 in the mini-kernel) | 6 bytes at the site; **0** extra instructions | short form (2 bytes) when the latch holds the convention mask: 546 of 598 under K2, 597 of 598 under K1; no site is safe at every execution (static saving **0** of 24 bytes) | hit at 597 of 598; 3 of 4 sites safe: **12 of 24** bytes |
| **Interrupt or fault return** (51 timer returns; 1 fault) | 6 bytes; 0 | K2: **0 of 51** hits (each follows a system call return and finds the convention mask); K1: 50 of 51 | 50 of 51 |
| **Return after a context switch** (161 of the 651) | 6 bytes; 0 extra instructions (the mask is "all", and the registers come from the stack) | per-process latch: **+4 instructions per switch** (51 switches in the run: 204 instructions, 1.0% of the run's 20,715); the hits are the same as the core latch (546 of 651 under K2; of the 161 returns after a switch, 109 under K2 and 159 under K1) | no save: the latches are constants of the kernel |
| **`GENTER` to a guest** (start) | 6 bytes (the decided form); the mask is "nothing the hypervisor did not mean to pass" | the same instruction in all designs (a start never finds its mask) | same |
| **Exit and re-enter loop** (`hv-first`: 76 hypercall exits, 1 page-table-base exit, 1 stage-2 fault) | one `GENTER` site per handler: 6 bytes each, 4 sites, 24 bytes; 0 extra instructions | 74 of 77 re-entries find the mask, but they are all one site; a short form there saves 4 bytes in the whole program | same |
| **Nested interrupts** (116 returns to the same mode in the two-process run, 15% of its 767 `RTI`s; 1 to 2 in the hypervisor tests) | 6 bytes each (the mask is in the instruction and ignored); 0 | 2 bytes each (a short form that ignores the latch); the latch is neither read nor written | same |

The dynamic bytes are not a fair measure of A: a program must choose the short or the long form **for each site**, not for each execution, and a site that hits at 546 of 598 executions cannot be a short form. A short form is safe only at a site where every execution, in any interleaving, finds its mask. The tools count such sites by the trace (an upper bound, since a trace shows only the interleavings that happened).

### 3.2 How often a latch finds its mask, by workload (measured)

| program | returns | one latch, K1 | one latch, K2 | per kind, K2 |
|---|---:|---:|---:|---:|
| `mini-kernel` | 8 (3 system calls, 3 timer, 1 fault, 1 start) | 6 (75%) | 2 (25%) | 4 (50%) |
| `twoproc` | 651 (598 system calls, 51 timer, 2 starts) | 647 (99.4%) | 546 (83.9%) | 648 (99.5%) |
| `hv-first` | 81 (79 `GENTER`, 2 `RTI`) | 72 (88.9%) | 72 (88.9%) | 74 (91.4%) |
| `hv-stage2` | 38 `GENTER` | 10 (26%) | 12 (32%) | 12 (32%) |

A run-to-run caution: the timer is wall-clock, so the two-process run gives 614 to 672 returns and 20 to 72 timer returns (`results/twoproc-runs.txt`); the saved run is the one the tables use.

### 3.3 Gates (measured, the repository's method, same register file of 32 x 64 bits as the earlier study)

| design | gates | over design B | over today (27,593) | longest path |
|---|---:|---:|---:|---:|
| register file today | 27,593 | | 0 | 17 |
| **B: mask in the instruction (decided)** | 29,705 | 0 | **+2,112** | 17 |
| A1: one latch, `GENTER` writes it | 29,897 | +192 | +2,304 | 17 |
| A2: short or long form, one latch | 30,083 | +378 | +2,490 | 17 |
| A2 with the latch readable and writable as a system register | 30,277 | +572 | +2,684 | |
| A2 with two latches (level) | 30,282 | +577 | +2,689 | |
| A2 with a latch per nesting level, 2 | 30,397 | +692 | +2,804 | |
| A2 per nesting level, 4 | 31,009 | +1,304 | +3,416 | 17 |
| A2 per nesting level, 8 | 32,347 | +2,642 | +4,754 | |
| A3: a latch for each of 4 kinds | 30,974 | +1,269 | +3,381 | |

Everything is under 1.3% of the scalar core (265,000 at the middle of the 220,000 to 310,000 range). The latch is not expensive; it simply buys no instruction. The immediate also costs a wire from the decoder (32 mask bits travelling with the instruction), which the model takes as an input and which neither design counts.

## 4. Safety: what a stale mask lets through

### 4.1 What a wrong mask does, in plain words

A mask that keeps too much (a bit set where the register holds the kernel's value) is a **leak**: the user reads a kernel pointer. A mask that keeps too little is a **loss**: the user's value is replaced by zero. B cannot do either by accident: the programmer writes the mask for the return in front of him. A short `RTI` uses whatever the last return left, so the mask the code **assumes** is not the mask the hardware **has** whenever something else returned in between. I counted what would happen at every return that finds the wrong mask, if the short form were used there.

### 4.2 Measured, one core latch (design A2), at the returns that miss

| program | misses | would leak a register | would clear a live register |
|---|---:|---:|---:|
| `mini-kernel`, K1 | 2 of 8 | 0 | 0 |
| `mini-kernel`, K2 | 6 of 8 | 2 | 2 |
| `twoproc`, K1 | 4 of 651 | 1 | 1 |
| `twoproc`, K2 | 105 of 651 | **52** | **14** |
| `hv-first`, K1 | 9 of 81 | 8 | 3 |
| `hv-first`, K2 | 9 of 81 | 6 | 3 |
| `hv-stage2`, K1 | 28 of 38 | 14 | 0 |
| `hv-stage2`, K2 | 26 of 38 | 8 | 3 |

The mechanism in the two-process kernel is the one that cannot be tested into submission: the user is interrupted between its last system call return (latch holds the convention mask) and its next system call. The timer's return, a long form, stores "all" in the latch. The next system call returns with a short form and gets "all": the handler's `r1` to `r5` go to the user. Nothing in the kernel's code changed; a timer tick did it, and a different tick count (20 to 72 timer returns in four runs) gives a different number of leaks. A latch per process gives 51 leaks and 15 losses against 52 and 14 (the same mechanism, inside one process); per nesting level cannot help (the interrupt is not nested, it arrives in user mode).

### 4.3 The owner's literal idea (A1), measured on the code that exists

The latch is set only by `GENTER`, and a guest kernel's `RTI`s use it. In `hv-first`, **2 of 2** guest returns get a mask different from the one they need, and both leak a register (the latch left by the last hypercall re-entry is "everything but `r10, r20, r21, r22`", which keeps the guest kernel's `r0` to `r3` visible to its own user at the start, and `r1` and `r2` after the system call). A native kernel with no `GENTER` has only the reset value: "keep all" leaks in 594 of the 651 returns of the two-process kernel under K2 (the system call handler's registers); "keep none" destroys a live value in 649 of 651 (every process loses `r8` and `r9`). A1 is correct only when the hypervisor's mask for a guest happens to be the guest kernel's mask for its user, which is the two facts of section 0 again.

### 4.4 A finding about `GENTER #mask` itself (counted from the trace, applies to design B too)

In a hypervisor written like the existing tests, registers keep **the hypervisor's own values across the guest's run**. A mask names the registers that hold the guest's values; the hardware clears the rest, **including the hypervisor's own**. The number of `GENTER`s after which the hypervisor reads a register it wrote before the guest ran (and the guest did not write):

| program | `GENTER`s | registers the hypervisor keeps across the run |
|---|---:|---|
| `hv-first` | 79 | `r10, r11, r12` (hypercall, page-table-base and stage-2 counters) in 78, `r12` in 1 |
| `hv-stage2` | 38 | `r20`, the address the exit handler jumps back to, in all 38 |
| `hv-timer` | 1 | `r13` (timer address) and `r20` |
| `hv-vtimer` | 1 | `r12` |
| `sec-hv-reset-inplace` | 2 | `r20` |
| `sec-hv-reset-mmuctl` | 2 | `r20` |

These programs rely on the guest not using those registers. Under `GENTER #mask` the values must live in memory (the hypervisor's banked `DP` points at a per-core structure for exactly this): one store before and one load after for each, per exit. The cost is the same for B and A; it is the price of the decision, and the test programs must change with it.

## What I could not do

* **Run the masks.** `RTI #mask`, `GENTER #mask` and any latch do not exist in `sim64` or the QEMU model. The programs ran as they are; the masks are computed (rules K1 and K2) from the measured sets. Cycles were not measured: the model has no timing for `RTI` or `GENTER`, and the timing model of `sim64` refuses kernel mode.
* **A real kernel or hypervisor.** The programs are small, the guests of `hv-stage2` and the reset probes are probes, and `hv-first` has one guest. There is **no trace of two guests alternating** or of a hypervisor that restores a guest's whole register image at every exit; for that case the mask is "all" at every re-entry, a latch would hit every time, and the instruction count and the hazard are by hand: no instruction changes, and the saving is 4 bytes at each re-entry site. The only workload with processes is the one I wrote.
* **Only two returns sit inside a guest's run** (`hv-first`), so "how often equal" for RTI against GENTER is 1 of 2 or 0 of 2: it is an existence statement for the reasons given, not a frequency.
* **Liveness is static and over-approximates** (a call returns to every return point; an indirect jump ends the path), and the oracle O is not a mask any kernel can write for an interrupt. A `HALT` in a guest is taken as an exit that needs nothing; a trap reads the argument registers a handler is documented to read.
* **The two ways of writing masks (K1, K2) are my rules**, not a kernel's. The system call mask is the convention of the ABI draft; `r16` to `r23` are treated as caller-saved scratch that the mask clears.
* **The two-process kernel is a toy** (two processes, no page faults, user processes that use few registers; it saves only `r0` to `r9` at a switch, enough for what they use). Its timer is wall-clock: the counts vary between runs as stated in 3.2.
* **The gate models are behavioural and synthesised, never run as hardware**; the depth is the tool's, not timing. I did not model the plain two-byte `RTI` for the same mode (a decode check, a few gates).
* **The question has two readings** and I measured both: "RTI in a guest reuses the mask of the `GENTER` that started the run" (A1) and "RTI reuses the mask of the last return of any kind" (A2, A3). A third reading, an `RTI` that reuses the mask of the **exception entry** that started this kernel visit, is the same as A3 with the hardware choosing the kind: same hits, same gates, same objection.

## Decisions for the owner

1. **Keep the mask in the instruction for `RTI` and `GENTER` (no latch)?** *Closes:* a stale-mask bug that no test can pin down, because it depends on where a timer tick falls (52 leaks in one run of the two-process kernel, 20 to 73 across four). *We lose:* four bytes at a return site that a short form could have saved: 0 of 4 sites with one latch in the two-process kernel, 2 of 4 in the careful mini-kernel, 3 of 4 with one latch per kind of return, and no instructions either way. *Recommendation:* yes, keep it.
2. **Allow a plain two-byte `RTI` for returns to the same mode only, and make a plain `RTI` that would go to a lesser mode an illegal instruction?** *Closes:* nothing about safety (a return to a lesser mode still needs a mask by construction); it keeps the rule "there is no way back to the user that does not say what the user may see". *We lose:* a decode check on the status word's mode (not costed) and a second encoding of `RTI`. It saves 4 bytes at each nested return: 116 of the two-process run's 767 `RTI`s (15%), 464 bytes of fetch in that run. *Recommendation:* yes if the encoding has room, otherwise skip: it is small.
3. **If a short form is wanted anyway, one latch per kind of return, set once at boot?** *Closes:* the hazard of the single latch (0 leaks in the two-process run: the latches are constants). *We lose:* it is the earlier study's "mask from a system register" spelling with four registers: 1,269 gates, a system-register number for each, and one more thing for a kernel to keep right (a kernel with two different system-call masks breaks it). *Recommendation:* no.
4. **Do not make a guest's `RTI` use the mask of the `GENTER` that started it (A1).** *Closes:* a hypervisor's choice of mask deciding what a guest kernel's user may see (2 of 2 returns in `hv-first` would leak). *We lose:* nothing that exists. *Recommendation:* agree.
5. **Write down that the hypervisor keeps nothing in registers across `GENTER`, and change the test programs that do?** *Closes:* the hypervisor's own counters, resume addresses and device addresses being cleared by its own entry mask (all 6 programs rely on them surviving). *We lose:* one store and one load for each such value at each exit (3 registers in `hv-first`, 1 in `hv-stage2`, per exit), and the banked `DP` becomes the hypervisor's per-core pointer by rule. *Recommendation:* yes; this follows from the decided `GENTER #mask`, whatever is done about the latch.

## The files

`docs/encoding-work/bench/rti-mask-reuse/`: `asm/twoproc.S` (the two-process kernel); `tools/` (`sites.py`, `run_trace.sh`, `events.py`: the trace; `prog.py`: instructions, registers and liveness; `analyse.py`: the sets at each return; `replay.py`: the designs played against the returns; `corpus_masks.py`; `summary.py`); `gates/latch.v`, `gates/run_gates.sh`, `gates/count.sh` (the models and the method); `run_all.sh` (regenerates everything); `results/` (`summary.txt` is every figure of this study; `events-*.tsv` one line per executed return with the sets and masks; `replay.json`; `gates-results.txt`; `corpus-masks.txt`; `twoproc-runs.txt`). The traces themselves (about 30 MB) are not kept: `run_all.sh` makes them again.
