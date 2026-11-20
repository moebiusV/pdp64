# Resume for the vector block: the design, measured

*For the owner to read. Nothing here changes the manual, the grammar, a tool, the executor, a test or a recorded decision. This is the second version: you asked for a real benchmark (speed and gates) and for plain words instead of strings of numbered references. Every figure is labelled **measured** (run in a scratch copy of the simulator, never in the repository), **synthesised** (counted by yosys with the repository's own method), **counted** (read from a repository file), **estimate** (my judgement) or **unverified**. What I say about other architectures is "as checked" in `best-of-breed-vector.md` (sections 2.1 to 2.5), where the quotes and dates are; I added nothing new about them.*

## 0. The answer, in plain words

**What "resume where possible" means.** When a fault or an interrupt stops a vector block in the middle, and the machine then goes straight back to that same block in that same program, the block carries on at the strip where it stopped, with its running sums intact. In every other case (another program ran in between, a guest was swapped, anything else touched the vector unit, the code changed) the sums are thrown away and the block starts again from its first strip, exactly as today. So resume only ever makes things faster; it never changes an answer.

**Your questions, answered from runs.** The "256 bytes" are the accumulators (at most 16 registers of 16 bytes). In my recommended design they **never move**: they stay in the vector unit's registers. What is added is a small record (the address of the block, a tag saying whose it is, a one-use token, and the entry and current values of up to four registers) of 680 flip-flops.

* **Faster or slower at run time?** Faster, by a lot, wherever a block is interrupted, and **not slower when nothing interrupts it** (measured: the warm figures are identical to today's, 667, 2,587, 10,267 vector cycles for the micro-kernel at K = 64, 256, 1,024). With page faults (each page's first touch faults once), today's restart multiplies the block's time by 2 (K = 64) up to 25 (K = 4,096), and by 256 for a long dot product. Resume brings that to **1.01 to 1.02** (including a cost I charged of 8 cycles for each interruption, an assumption). With a timer tick every 10,000 cycles (100 MHz at 10 kHz), today's restart makes the micro-kernel 3% to 13% slower at K = 64 to 256 and **never finishes** at K = 1,024 and above; resume costs **0.09%**.
* **Gates: add or remove?** Today's hidden record (a copy of the address and naming of the block that is running, plus the naming register) is **1,544 NAND2 equivalents** (synthesised). Resume in place with all its checks is **9,081**: it **adds 7,537** (2.7% of the vector unit's 278,959 at 256 bits). Restart with a bound **removes about 700** if the assembler does the checks, or **adds about 375** if the hardware does them. Architectural state with OS save and restore (B) **adds about 11,300**. Section 3 gives each.
* **What it loses.** Resume loses one thing: it cannot carry a block across a switch to another program; then the block restarts (the measured "restart" column is exactly what a program switched out in the middle of an accumulator block pays). Section 3 says what each design loses in words.

**Recommendation: unchanged, resume in place (A).** Judged by your four principles in order: **safety**: A keeps nothing visible and nothing that survives a change of program, so nothing can leak, and the restart that remains is always correct; B is as safe but leaves 36 words of state for the OS to save correctly, and bounded restart is the safest of all (nothing survives an exception) but it is the thing you chose against; **speed**: A and B are within 2% of the warm run in every fault and tick case measured, bounded restart is 1.6 to 2.5 times slower on cold micro-kernel runs and up to 27% slower at 10 kHz ticks, and today's restart is far worse; **fewer instructions**: A adds none (no change to the encoding, so no new run of the encoding optimiser), B adds none if the state is reached through system-register numbers; **a set a programmer can hold in their head**: A is invisible to a program and to a kernel that never heard of it, B adds a state window, a status field and a trap that every kernel must handle. A costs 7.5k gates more than today, B 3.8k more than A.

## 1. How I judge, and what I read

Your principles, in order: **safety**, **speed**, **fewer instructions** (not necessarily a smaller set), and last, once those are met, **a coherent set a programmer can keep in their head** like the PDP-11's. The rule of errata 200 (every security hole and information bleed is prevented and has a test in the assembler corpus) and the rule of errata 198 (start from the best designs of others, amend minimally so that holes close by construction) stay. I read the previous review, the vector chapter of the manual and its design pages, the executor (`common/pdp64exec_vec.inc`, `common/pdp64exec.c`), the hypervisor design, the audit of sensitive instructions and the existing tests.

What the best designs do (as checked there): RISC-V keeps the resume position in a register and the OS saves the vector registers only when a status field says they changed ("dirty"); x86 keeps the progress of its long instructions in ordinary registers and lets the OS skip state that is still in its initial form; Arm SME clears its state at the edge of a mode. None of them keeps progress in hidden state the OS cannot save. Design A is therefore a departure, and it is acceptable only because the restart is always there as a fallback and nothing outside the block can read the hidden state.

## 2. What resume means, exactly

**Words.** A *block* is `vec Rs, Re` ... `vend`: the instructions between run once for each *strip* (a 16-byte piece of the first stream when the block has accumulators). An *accumulator* is a hidden register that keeps its value from strip to strip, made by `vclr`. A strip's registers, stores and accumulator updates are committed together or not at all (the accesses are all checked before the strip runs). An *exception* is any entry to a handler: a fault, a physical or virtual interrupt, a trap, an exit to the hypervisor. A *context* is who the access is made for: guest tag, address-space number, mode, and whether the hypervisor is running.

**Suspend.** If an exception stops an accumulator block after at least one strip was committed, and the block changes at most four registers, the hardware keeps the accumulators where they are and writes the *resume record*: the address of the `vec`, the tag of the context, the values the block's changed registers had at entry and have now, and a one-use *token* (a number the hardware makes up). The handler is shown the **entry** values of the registers (as today), the address of the `vec` in `EPC`, and the token in the upper half of `EPSW` (`HEPSW` for an exit). If no strip was committed, or the block is bigger than the record, no record is written and the sums are zeroed: the block will start again.

**Resume** happens only if all of these hold at the return: it is `RTI`, `RTT` or `GENTER` and carries the record's token; it returns to the address of the `vec`; the context has the record's tag; the registers the block changes still hold the entry values (so an operating system that edited one has abandoned the block, and the block starts again from the edited values); the body has the same number of changed registers. Then the registers get their saved current values, the `vclr` is skipped, and the block goes on at the next strip. The record is used up.

**Discard (the sums are zeroed and the record dies, before anything else can use them)** on: any vector instruction that is not a resume; any write to `ASID`, `PTBR`, `MMUCTL` or `GTBR` (whatever value); `GENTER` into another guest; `ICINV`, `ICINVA`, `TLBI`, `TLBIA`; a return that presents the token but fails a check; a machine check; a later suspension (a new record replaces the old one, and a suspension of the same context that writes none kills the old record); reset; and the sums are zeroed at `vend` as well.

**Why a context switch discards even if the other program never used the vector unit.** If it did not, a program could learn whether another program used the vector unit (its own block would resume or restart depending on it; between two guests that is a covert channel). So the discard does not depend on what the other did. The price is the restart after a switch.

## 3. The four designs, measured and counted

The four designs you asked about:

* **Today: restart from the entry, no bound.** An interrupted accumulator block starts again at its first strip; the hardware keeps a small hidden record of the block's address and naming.
* **Restart with a bound.** Same restart, but a block may cover at most 256 strips (4 KiB of its first stream); the program cuts a longer job into blocks and adds the partial results (the micro-kernel already adds into C). No record at all.
* **A: resume in place** (my design above).
* **B: architectural state.** The accumulators, the block address and a status are system state that the OS saves when a status field says "changed" and restores later; the first use of the unit by another context traps so the OS can swap. Nothing is ever restarted.

### 3.1 Speed (measured)

**How.** I copied the simulator and its executor into a scratch folder, built resume into the copy (about 60 changed lines, Appendix F), and ran the repository's own programs (the micro-kernel, and the dot products and 2D block of the previous review's appendix) under `sim64 -V` model-1 vector cycles, with and without page faults (`-x`). **The executor never takes an interrupt inside a block, so I added a scratch hook that injects one after any strip once the vector-cycle count passes the next tick, at 12 phases of the tick; I say so plainly: it is a hook in my copy, not an interrupt line, and it counts vector cycles only (not the handler's own time, which is the same in every design).** Design B was **counted, not built**: it runs as resume with no per-interruption cost in the same context, and a separate column adds the counted cost of saving and restoring the state at a switch (16 accumulators of 16 bytes at 8 bytes a cycle, plus the pointers: 40 cycles for the micro-kernel, 14 for a dot). Every run was checked: the exit status (a fold of the result) equals the uninterrupted run's in **1,632 tick runs and 34 page-fault runs with data, 0 differences** (the 108 stops are the runs that did not finish, listed as "never"). The baseline reproduces the previous review's measured numbers exactly (1,311, 6,433, 71,731 cold; 667, 2,587, 10,267 warm), which shows the scratch copy is the same machine. The raw tables are Appendix C.

**Warm, no interruption.** Resume and restart are identical: 667 / 2,587 / 10,267 / 40,987 cycles for K = 64 / 256 / 1,024 / 4,096. The bound adds the cost of cutting: K = 1,024 costs 10,348 (+0.8%), K = 4,096 costs 41,392 (+1.0%), the dots +0.1% to +0.6% (measured).

**Page faults** (ratio to the warm run; first touch of every page faults once; the handler is one `rti`):

| program | restart (today) | restart, bounded | A resume | B in place |
|---|---:|---:|---:|---:|
| micro-kernel K = 64 | 1.97 | 1.97 | 1.016 | 1.004 |
| K = 256 | 2.49 | 2.49 | 1.008 | 1.002 |
| K = 1,024 | 6.99 | 1.76 | 1.010 | 1.001 |
| K = 4,096 | 24.99 | 1.57 | 1.010 | 1.001 |
| float dot with accumulator, 16,384 elements | 16.0 | 1.006 | 1.017 | 1.002 |
| the same, 262,144 elements | 256 | 1.006 | 1.018 | 1.002 |
| int8 dot with accumulator, 1 MiB | 256 | 1.001 | 1.004 | 1.000 |
| the programs without an accumulator and the 2D block | 1.00 to 1.01 in every design | | | |

**Timer ticks** (expected ratio over a random phase; "never" = no finish within 6 times its length; T in vector cycles, 10,000 = 100 MHz at 10 kHz, 100,000 = 100 MHz at 1 kHz, 1,000,000 = 100 MHz at 100 Hz; the full table with 1 GHz is Appendix C.2):

| program | T | restart (today) | bounded | A | B in place | B at every tick a switch |
|---|---:|---:|---:|---:|---:|---:|
| micro-kernel K = 256 | 10,000 | 1.130 | 1.130 | 1.0009 | 1.0001 | 1.0041 |
| K = 1,024 | 10,000 | never | 1.172 | 1.0009 | 1.0001 | 1.0040 |
| K = 1,024 | 100,000 | 1.051 | 1.021 | 1.0001 | 1.0000 | 1.0004 |
| K = 4,096 | 100,000 | 1.205 | 1.019 | 1.0001 | 1.0000 | 1.0004 |
| float dot accumulator, 262,144 | 100,000 | never | 1.007 | 1.0001 | 1.0000 | 1.0001 |
| int8 dot accumulator, 1 MiB | 1,000,000 | never | 1.003 | 1.0000 | 1.0000 | 1.0000 |

(The 0.09% of A at T = 10,000 is my assumed 8 cycles for each interruption: 8 cycles in 10,000. Change the assumption and the figure moves in proportion; the count of interruptions is in the tables.)

**What these numbers show.** (1) Today's restart is the loss: the quadratic cost of cold pages and "never finishes" under a fast tick. (2) A bound removes the livelock and most of the cold-page loss for dots but not for the micro-kernel (1.6 to 2.5 times) and costs about 1% warm. (3) A and B are both within 2% everywhere measured; B is 0.1% to 1.7% better only because I charged A 8 cycles for each interruption and B none. (4) **A at a context switch is the restart column** (it restarts), and B at a switch is the last column: so the difference between A and B is the restart after a switch against 14 to 40 cycles of save and restore. For a block much shorter than a time slice, that is a trade of a few cycles against a few hundred, and it only matters if the machine switches programs inside a block often.

### 3.2 Gates (synthesised)

**Method.** The repository's: write the block in Verilog, `yosys` synthesises it, `abc` maps it to NAND2 gates and inverters; a block counts as NAND2 plus half an inverter, and a flip-flop is counted apart and as 6 NAND2 equivalents in totals (`tools/gates/gates.sh`, `vec-gates.md`; I used the script unchanged on a new file). The Verilog is Appendix D. **Synthesised:** the record with its binding (tag, token, address, entry and current values compared and written back one register at a time through the register file's existing ports), the keyed token generator, the admission checks (one base register used for both a load and a store; at most four changed registers), the bound's comparator, today's record, and design B's state, read path and write path. **Not synthesised (counted by hand or left out):** the suspend and resume control sequences, the plumbing of the token into `EPSW`, the zeroing of the accumulators on a discard (it reuses the circuit that zeroes registers at the start of every strip, so I counted it as no new gates, which is an assumption), the interrupt poll, timing, and wiring.

| block | NAND2 logic | flip-flops | total NAND2 equivalents |
|---|---:|---:|---:|
| today's record and naming register | 476 | 178 | 1,544 |
| naming register alone (option 1 keeps this) | 34 | 16 | 130 |
| A: resume record and binding (four registers) | 3,517 | 726 | 7,873 |
| the admission checks (in-place refusal, count of changed registers) | 484 | 99 | 1,078 |
| the bound's comparator (256 strips) | 711 | 0 | 711 |
| B: state and trap (owner tag, status, block address) | 315 | 101 | 921 |
| B: read path to 34 words | 5,551 | 0 | 5,551 |
| B: write path into the accumulators | 6,235 | 0 | 6,235 |

My earlier estimates were 8,100 for A and 13,400 for B and "tens of gates" for the bound: the synthesis says A's record is 7,873 (the estimate was close) but the bound's comparator is 711, not tens, and I had left out the admission checks (1,078). B comes out lower, 12,707 with its state.

### 3.3 Add or remove, faster or slower, what is lost

Total for each design (including the naming register that option 1 keeps), against today's 1,544:

| design | gates | against today | run time | what is lost, in words |
|---|---:|---:|---|---|
| **today: restart, no bound** | 1,544 | 0 | the baseline; slow under faults (2 to 256 times) and never finishes under fast ticks | every interruption throws away the sums; long blocks can starve; a block that reads what it writes can compute a wrong answer silently |
| **restart + bound, assembler checks only** | 841 | **minus 703** | warm +0.1% to +1.0%; cold micro-kernel 1.6 to 2.5 times; 10 kHz tick up to +27%; no livelock | nothing visible survives an exception (safest and smallest); the program must cut long jobs; the floating-point sum order follows the cuts; the checks rely on the assembler, so a hand-made program could bypass them |
| **restart + bound, hardware checks** | 1,919 | **plus 375** | the same | the same, with the checks enforced by the machine |
| **A: resume in place** | 9,081 | **plus 7,537** | warm identical; faults and ticks within 2% of warm; **faster** than today by 1.0x to 250x as above | resume does not cross a switch to another program (that block restarts); one hidden record in each core (a small state to get right, hence the checks of section 5); the in-place refusal and the bound's cousin remain to protect the restart fallback |
| **B: architectural state** | 12,837 | **plus 11,293** | faults and ticks within 0.5% of warm; a dirty switch costs 14 to 40 cycles each way (counted) | simplicity: a state window of about 36 words, a status field and a new trap that every kernel and the hypervisor must handle correctly; an OS that forgets to save is stopped by the trap, not silently wrong |

**One more fact about speed:** with A, a block that is never interrupted is exactly as fast as today (the checks overlap the decoding of the block, an assumption); the only cost is the 8 cycles I charged for each interruption.

## 4. The state a block holds

| thing | visible to programs? | where it lives | size | thrown away when |
|---|---|---|---|---|
| the pointers and the scalar results the block updates | yes: ordinary registers. For a block with no `vclr` they show progress (as today); for an accumulator block the handler sees the **entry** values | the register file; the record keeps entry and current values of up to four of them | 512 flip-flops | at the resume; at any discard |
| the strip number | no, not kept: it is the pointers' distance from their entry | derived | 0 | |
| the accumulators | no: hidden | the hidden vector registers, where they already are; at most 16 of 16 bytes (256 bytes); the size does not grow with the machine's strip | 0 new | at any discard and at `vend` |
| which registers are accumulators (the naming) | no | **derived from the text of the block** (option 1: `vclr` is only legal inside a block), so it is not state | 0 | |
| the record: valid, armed, token, tag, block address | no: hidden; the token is also in the upper half of `EPSW` | the vector unit, one in each core | 136 flip-flops + the token counter and its key | the discard list of section 2 |
| the stores of a strip not yet made | no | held until the strip commits, and not at all if it faults | 0 | |
| the epilogue position (after `vfin`) | no, not kept: "the pointer reached the end and the record is valid" | derived: the loop does no strip and runs the epilogue once | 0 | |
| a 2D block's row counter and gap pointers | yes: ordinary registers advanced with the strip that ends a row; a 2D block has no accumulators | the register file | 0 hidden | nothing to throw away |

The five rules the hardware keeps: **one owner** (one record in a core; a newer one replaces it); **no read without a proof** (a hidden register is zero, or freshly cleared by its `vclr`, or resumed under the rule above); **resume only by return** (the record is used only by the `vec` that runs right after a return that presented the token); **restart is always available** (the handler is shown entry values, so a thrown-away record means a clean restart); **strips are atomic** (a strip commits everything or nothing, and an exception is taken only between strips). The last is why no copy of the accumulators is needed; a real core must take interrupts only at a strip boundary.

**Option 1 and this design.** You answered the `VCLR` question with option 1: `VCLR` names accumulators only inside the block. The design relies on it: outside a block `vclr` is an illegal instruction (and the assembler refuses it), so the form that could be interrupted half-made does not exist and the naming is never state. The clears of the naming at exception entry, return and world switch (the closing rule added after errata 172) therefore go, and the discard rules above say what happens to the sums instead. The clear of any `LL` reservation stays.

**A block with only `vfin` or `vfmab` (no `vclr`)** keeps its 16-byte strip but keeps nothing between strips, so it is an ordinary block: it resumes by its pointers (today it restarts needlessly).

## 5. The holes, each closed by construction, each with its test

For each: what could go wrong, how the design stops it, and the test (names in section 7).

1. **State leaking from one context to another** (user to user, user to kernel, kernel to user, guest to guest, guest to hypervisor, hypervisor to guest). *Stopped by:* the record carries the tag (mode, address-space number, guest tag, hypervisor bit) and a return must match it; **every** change of context (a write of `ASID`, `PTBR`, `MMUCTL`, `GTBR`, a `GENTER` into another guest) throws the record away and zeroes the sums, whatever the other did; any other use of the vector unit zeroes the sums first; no register is ever read that was not zeroed, cleared by its `vclr`, or resumed. Reset needs only the record's valid bit clear. *Tests:* LK-1 to LK-9.
2. **The naming left by a handler's `VCLR`.** *Stopped by:* `VCLR` outside a block is illegal; the naming is derived from the block's text. *Tests:* NM-1 to NM-3.
3. **Old state resumed in the wrong block.** Today's hidden copy is two file-level variables keyed by the address of the `vec` alone: not per core, per program or per guest (found by reading). *Stopped by:* deleting them; the new record needs the token (made up at the suspension, and found only in the frame the hardware wrote), the address, the tag, the unedited entry registers and an unchanged body, and is used up by the resume. Specific cases: same code in another process (tag differs, and the `ASID` write threw it away); a block abandoned by `longjmp` and entered again (nothing presented the token, so the next `vec` finds it unarmed and discards); a new instance stopped before its first strip (a suspension of the same context that writes no record kills the old one); a frame moved to another core and back (the token belongs to one record in one core); a forked frame (another address space); changed code (`ICINV` discards). *Honest limit:* the token is 32 bits from a per-core counter, so a false match needs a frame that survived 4 billion suspensions of one core and also matched the address, tag and entry registers; I call it negligible, not by construction (decision 4 gives the 64-bit alternative). *Tests:* ST-1 to ST-7.
4. **A block that reads and writes the same memory** (restart repeats stores already made: measured earlier, 4 of 8 lanes wrong, silently). *Stopped by:* resume never repeats a store that committed with a strip; for the fallback restart, the machine refuses at `vec`, before any work, a block with accumulators whose main loop stores through the same base register it loads through. Two different registers that alias are "unpredictable", as the manual already says. **A correction to the previous review:** its rule would also refuse the micro-kernel, whose epilogue loads and stores the same register by design (C += accumulators); the epilogue is one atomic strip, all its accesses checked first and its stores made together, so a restart cannot see half of it. The rule must cover the main loop only. *Tests:* IP-1 to IP-3.
5. **A fault in the epilogue.** *Stopped by:* the epilogue is atomic; resume runs it again once, without repeating the main loop (restart repeated everything: measured 7 times the warm time for the micro-kernel at K = 1,024). *Test:* EP-1.
6. **Nested exceptions in a handler that uses the vector unit.** *Rule:* one level; the handler's first vector instruction discards the interrupted block's sums, so that block restarts at its return; the handler's own block can resume if it is interrupted. No stack, no shadow copy of the accumulators (the 12,288 NAND2 the previous review counted for one). *Tests:* NE-1 to NE-3.
7. **The hypervisor.** A physical interrupt in the middle of a guest's block always exits; the exit is a suspension with the guest's tag and the token in `HEPSW`; if the hypervisor does not touch the vector unit or `GTBR` and enters the same guest, the block resumes; a stage-2 miss (cold guest memory) is the same, and is where resume saves most because every miss would otherwise restart the block; a virtual interrupt at a strip boundary is the guest's own entry and its `RTI` resumes. A changed `HEPC` or token means restart. The hypervisor design's step "clear the naming" becomes "write the record". *Tests:* HV-1 to HV-5.
8. **What an exception record or `PROBE` reveals.** The registers a handler sees are the entry values; `EPC`, `EVA`, `ECAUSE`, `HEVA`, `HGPA`, `HINSN` are exactly what they are today and do not depend on the hidden record. The token is new information: a plain counter would tell a guest kernel how many suspensions the core made, including other guests': so the token is the counter through a keyed scrambler. *If the machine has no random key at reset the key is fixed and this channel is not closed* (I did not check for a source). *Tests:* IN-1 to IN-3.
9. **The strip stays invisible.** An accumulator block's strip is 16 bytes everywhere, so a resume is at the same element at every width. One old limit is not closed and not made worse: for a block without accumulators the pointer a handler reads at a fault is the start of the implementation's strip, so a handler can tell the strip (the manual calls these pointers "opaque"; the test checks only a relation). Interrupts inside such blocks would show it the same way (decision 14). *Test:* SI-1.
10. **Time and other channels.** Out of scope, stated: timing (a block's duration shows whether something discarded its record, which a program's own clock already shows because a context write is the cause; it does not show what the other context did); caches; power; speculation (an out-of-order core must not use old sums before the checks pass: a requirement, not testable in the simulators); the simulator's counters. **In scope and closed:** the token's count, the discard that does not depend on the other context, the sums zeroed at `vend`.
11. **A register read that was never written** reads zero: non-accumulators are zeroed at each strip start; an accumulator is zeroed by its `vclr`; an **empty** block's epilogue reads zero (**measured**: after a block left `0x5a5a5a5a` sums, an empty-range block with `vclr`, `vfin` and an epilogue store of the accumulator stored 0; Appendix G). *Tests:* UN-1, UN-2.
12. **Others found.** A bus error or machine check after a strip's addresses were checked is not restartable: the state is discarded and the block does not resume (UN-3). A block is not atomic against other writers of memory (the strips already done saw the old content), as with any multi-step instruction.

## 6. What changes in the executor, the tests and the manual

**Executor.** In `common/pdp64exec_vec.inc`: delete the file-level `vrun_*`/`vrst_*` variables and their uses; at `vec`, compute the changed registers, run the refusals, and resume or discard; narrow "hidden" to "the body has a `vclr`"; count strips done; after each strip, ask the host whether an interrupt is deliverable (a new `irq_poll`) and, if so, stop early with `PC` at the `vec`; zero the sums at `vend`; make a stand-alone `vclr` illegal. In `common/pdp64exec.c`: `pdp64_exception` (the suspend), `enter`, `enter_h`, `hexit`, `genter` (remove the naming clears; put the token in `EPSW`/`HEPSW`), `RTI`/`RTT` (read the token; the cast to 32 bits already drops the upper half, and the reserved-mode check looks only at the low bits: **verified by reading**), and the writes of `ASID`, `PTBR`, `MMUCTL`, `GTBR`, `TLBI`, `TLBIA`, `ICINV`, `ICINVA` (discard). A host switch to turn resume off (so the same tests run both ways) and an option to take an interrupt after N strips. **The QEMU target shares the executor; its poll for a pending interrupt inside the running helper I did not read: unknown effort, my guess one to two days.** `as64`: refuse `vclr` outside a block and the same read-and-write base register. The grammar and the encoding do not change: **no new instruction, no new run of the encoding optimiser.**

**Tests that exist and change.** `vec-restart.S` (56 kernels, 912 scenarios): drop the kernel "`vclr` before the block" and the handler that names accumulators; keep everything else, run it with resume off and with it on, expect the same results. `vec-clear.S`: becomes "`vclr` outside a block is illegal" and "a handler's `vclr` traps". `hv-switch.S` and its generator: the naming-clear checks become the guest-to-guest and hypervisor-to-guest leak tests.

**Manual and records.** Rewrite, after you have seen the text: 6.14.9 (it still says a block "restarts from its entry" and that every entry and return clears the naming), 9.2.6 (it says the only hidden instruction state "restarts from the entry"), the vector design page (the items on restart, on naming before the block, on "hidden state restarts clean"), the hypervisor design (the clear step and two table rows), the audit's vector row and its decision about the clear. Run `tools/mkbook.sh --check` with every manual change; a skipped check is not a pass. **Recorded decisions this changes, in words:** the choice to restart from the entry (made on your answer in the virtualisation form, then reaffirmed in the correction), by your own new decision; the allowance for naming before the block (your option 1); the rule that every entry, return and world switch clears the naming (replaced by tag and discard; the `LL` clear stays).

**Order of work (each step testable).** (1) Option 1 and the refusals, no resume: old suite passes minus two kernels. (2) The record and resume for faults, switchable. (3) The discard rules with the mutation tests. (4) The token, the tag and the hypervisor cases. (5) The interrupt poll. (6) QEMU. (7) Manual text after you have seen it. (8) Later, if wanted: the bound, or B. **Effort, estimate:** about 10 to 15 person-days with tests; B about 6 to 10 more.

## 7. The tests for the security corpus

Assembly programs for `sim64` and the QEMU machine, to be written by another agent. A **witness** tells a resume from a restart by the program's own means: the fault handler unmaps a page the block already read each time it handles a fault; a restart reads that page again and faults again, a resume does not; the handler counts its faults. "ref" means the result of the same block run with no exception.

| id | what | expected |
|---|---|---|
| RS-1 | accumulator dot over pages; faults in the first, middle and last strip; witness | result = ref; faults = pages |
| RS-2 | the micro-kernel with a cold C tile (fault in the epilogue) | result = ref; no panel page faulted twice |
| RS-3 | the same with an interrupt after N strips | result = ref |
| RS-4 | what a handler sees: `EPC` = the `vec`, entry values, exact `EVA`/`ECAUSE` | as the existing restart test |
| RS-5 | every program here with resume switched off | same result, the witness shows more faults |
| RS-6 | a block that changes more than four registers | result = ref; restart |
| RS-7 | a scalar reduction target in an accumulator block | result = ref |
| RS-8 | the `vclr` is not run again on resume | sums continue |
| RS-9 | a one-strip block; a short last strip | result = ref |
| LK-1 | process P stopped with sentinel sums; a write of `ASID`; Q runs the same code at the same address fresh | Q's result = Q's ref; then P's = ref |
| LK-2 | Q reads accumulators it never wrote | zero |
| LK-3 | the handler's block reads unwritten registers | zero; P's result = ref |
| LK-4 | a kernel block interrupted, the handler returns to user mode, the user block reads unwritten registers | zero; kernel result = ref later |
| LK-5 | guest 1 stopped by an exit; hypervisor enters guest 2 (other tag, same `ASID`, same code and registers); then guest 1 | each result = its ref |
| LK-6 | a hypervisor block after a guest exit reads unwritten registers | zero |
| LK-7 | a hypervisor block with sentinel sums, then `GENTER`; the guest reads unwritten registers | zero |
| LK-8 | after `vend`, the next block reads unwritten registers | zero |
| LK-9 | the empty-range epilogue (Appendix G) | zero |
| NM-1 | `vclr` outside a block: user, kernel, guest | illegal instruction; assembler refuses |
| NM-2 | a handler's `vclr` | the handler traps; the block is unaffected |
| NM-3 | `vclr` in a 2D block | illegal instruction (not a simulator abort) |
| ST-1 | stopped block; handler returns to another address of the same context, which re-enters the `vec` with other data | fresh result, no old sums |
| ST-2 | the same, and the fresh call is interrupted before its first strip | result = ref |
| ST-3 | handler zeroes the token | result = ref; restart |
| ST-4 | handler edits a pointer in the frame | block runs from the edited values |
| ST-5 | handler rewrites an instruction and runs `ICINV` | result of the new text |
| ST-6 | two cores: frame moved to core 1, stopped there with no record, returned to core 0 | result = ref; old record unused |
| ST-7 | frame copied to another `ASID` | copy restarts; result = ref |
| IP-1 | read-and-write block with a `vclr` (the measured example) | illegal at `vec`; nothing done |
| IP-2 | block storing running sums each strip, faulting in the middle | no store repeated (witness on the destination) |
| IP-3 | read-and-write block with no `vclr`, across faults | result = ref |
| EP-1 | fault in the epilogue | stores made once |
| NE-1/2/3 | handler runs its own block / its own block faults / does not touch the unit | all results = ref; witness: outer restarts, inner resumes, outer resumes |
| HV-1 | physical interrupt, same guest re-entered | resume; result = ref |
| HV-2 | virtual interrupt at a strip boundary | resume |
| HV-3 | stage-2 fault; `HGPA`/`HEVA` exact | resume; exact |
| HV-4 | guests swapped, or the same `GTBR` rewritten | restart; result = ref |
| HV-5 | hypervisor changes `HEPC` | restart |
| IN-1 | `EPC`/`EVA`/`ECAUSE`/`HEVA`/`HGPA`/`HINSN` at strips 16, 32, 64, resume on and off | identical |
| IN-2 | `PROBER`/`PROBEW` in the handler | unchanged |
| IN-3 | tokens read by guest 1 while guest 2 suspends 0, 1, 5 times between | differences do not depend on the count |
| SI-1 | every test not needing an interrupt, at strips 16, 32, 64 | same results |
| UN-1/2/3 | unwritten register in all directions / an epilogue reading an unnamed register / a bus error after the checks | zero / zero / discard, machine check |

**Mutations** (each must fail some test): no discard at the `ASID` write; no zeroing at a discard; no tag check; no token check; no one-use; no entry-register check; no discard at a same-tag suspension; the epilogue not zeroing; the in-place refusal also on the epilogue (the micro-kernel then fails); the old clear at entry kept; a plain counter as the token.

## 8. Findings outside the question

* The previous review's in-place rule must exclude the epilogue (item 4 of section 5).
* A block with `vfin` or `vfmab` and no `vclr` is called hidden today and restarts for no reason.
* The strip is visible to a handler through the pointers of a block without accumulators (item 9).
* Some refusals in the block are simulator aborts (`die`), not exceptions; two concern accumulators in a 2D block.
* The executor never takes an interrupt inside a block, so no test can today exercise a resume by interrupt.
* The previous review's "tens of gates" for the bound was wrong (711 synthesised).

## 9. What is measured, what is not

**Measured:** the benchmark tables (scratch copy, injected interrupts, page faults, 1,666 timing runs, of which 1,632 with ticks, and 34 page-fault runs with real data; every finished run gave the same result as the uninterrupted run); the empty-block epilogue reading zero. **Synthesised:** the gate counts of section 3.2 (a sample implementation of each block; not timing, not wiring). **Counted:** the cost of design B at a switch, and the record's bit count. **Assumed:** 8 cycles for each interruption in A (4 to write the record and 4 to check and load it, going through the register file's existing ports; with the 4-register record that is the right order, but I did not build the control); the zeroing at a discard costing no new gates; the admission checks overlapping the block's decode; a tick as a single injection after a strip; model-1 cycles at the default port; vector cycles only (scalar set-up and the handler's time excluded, equal in all designs).
**Not verified:** B was not built, only counted; the QEMU poll; whether the upper half of `EPSW` is free in the manual (free in the executor); whether the machine has a random key at reset; a two-core test environment; real interrupt rates and how often a real scheduler switches inside a block; other architectures beyond the earlier review.

## 10. Decisions for the owner

Each is a question; answer accept, change or not decided. For each: what it closes, what we lose, my recommendation.

1. **Do vector blocks resume in place after a return to the same block of the same program, and restart in every other case?** Closes: the loss of today's restart (2 to 256 times under faults, never finishing under fast ticks, a fault in the epilogue repeating everything). Loses: 7,537 gates more than today, a small hidden record in each core to get right, and no resume across a switch to another program. *Recommend: accept (A).* The alternative (B) adds 3.8k more gates and visible state for the OS to save, to win back the switch case.
2. **Does `VCLR` stay legal only inside a block (your option 1), and do the old clears of the naming go?** Closes: the naming left by a handler, and the state that could be interrupted half-made. Loses: nothing a program uses (the only user has its `vclr` inside); the clears of errata 186 and 192 for the naming go, the `LL` clear stays. *Recommend: accept.*
3. **How many changed registers may a resumable block have?** Closes: an unbounded record. Loses: a block that changes more than the limit restarts. *Recommend: four (the micro-kernel needs two; the unit has four pointer adders); each extra register costs about 1,000 gates.*
4. **Does the token go in the upper half of `EPSW`/`HEPSW` (32 bits, a core's counter through a keyed scrambler)?** Closes: a stale record resumed after a frame moved between cores, and the count of suspensions leaking between guests. Loses: about 1,000 gates; if there is no random key at reset the count still leaks a little; the token is unique to 4 billion suspensions, not forever (a 64-bit separate register would be). *Recommend: accept.*
5. **Does a context write (`ASID`, `PTBR`, `MMUCTL`, `GTBR`), a `GENTER` into another guest, `ICINV`/`TLBI`, any other use of the vector unit, a machine check or reset throw the sums away, with no stack of saved blocks?** Closes: every cross-context leak and the covert channel of "did the other program use the unit". Loses: a block restarts after a switch even if the other program never touched the unit; a handler that uses the unit makes the block it interrupted restart. *Recommend: accept.*
6. **Are the sums zeroed at `vend` as well as at every discard?** Closes: a future instruction or fault that reads a register after the block. Loses: nothing measurable (reuses the strip-start zeroing). *Recommend: accept.*
7. **Does the machine refuse, at `vec`, a block with a `vclr` whose main loop stores through a register it also loads through (the epilogue excluded)?** Closes: the silent wrong answer when a restart repeats stores (measured 4 of 8 lanes wrong). Loses: 1,078 gates with the count check, and a block that uses one base register for a source and a destination at different offsets must use two registers. *Recommend: accept; this corrects the earlier version, which would have refused the micro-kernel.*
8. **Do we also keep a bound on the accumulator block (256 strips) as a safety net for the restart case?** Closes: two programs that are switched in every slice and both run long accumulator blocks, restarting every time, and any block longer than a slice never finishing. Loses: 711 gates, about 1% warm cost, and the program has to cut long jobs (the sum order follows the cuts). *Recommend: accept the bound, because A restarts after every switch; if you prefer to rely on resume alone, that livelock stays possible.*
9. **Does a real core take an interrupt or exit at a strip boundary inside any block, and do the simulators get a poll and an "interrupt after N strips" option?** Closes: no test today can interrupt a block, and a real core cannot make an interrupt wait for a whole long block. Loses: the simulator's simplification ("an interrupt waits for the block") goes; a one-to-two day job in the QEMU target (my guess). *Recommend: accept.*
10. **Is a block with `vfin` or `vfmab` but no `vclr` an ordinary block that resumes by its pointers?** Closes: needless restarts. Loses: nothing. *Recommend: accept.*
11. **Do the refusals for a `vclr` or an accumulator in a 2D block, and similar, become exceptions instead of simulator aborts?** Closes: a program stopping the simulator instead of taking a precise exception. Loses: nothing. *Recommend: accept for the two accumulator cases.*
12. **Is the corpus a standing requirement, written into `tests/sim` and `tests/qemu` with the names above, with an index file listing each test, the hole it detects and the mutation that fails it?** Closes: "the architecture prevents it but nothing checks". Loses: about 40 tests of work. *Recommend: accept.*
13. **Do we leave state save and restore by the OS (B) for later, building it only if resume across a switch matters, or the accumulator grows past a few hundred bytes?** Closes: visible state, a new trap and OS code now. Loses: resume across a switch (the restart column). A is a subset of B, so nothing a program sees changes if B is added. *Recommend: accept.*
14. **Do we leave the pointer a handler reads for a block without accumulators as it is (it shows the strip start)?** The alternatives are to show multiples of 16 bytes (costly), or entry values for every interrupted block (loses the correct in-place resume of ordinary blocks). *Recommend: not decided; leave it and record it as a known limit.*
15. **The manual text for 6.14.9 and 9.2.6, written only after you have read it, and checked with `mkbook.sh --check`; it must say what resumes and what restarts, that the OS never interprets a block's registers (and if it edits them the block restarts from the edited values), and that a block is not atomic against other writers.** *Recommend: accept.*

## Appendix A. How the benchmark was made

* **Where.** All work was in a scratch copy of the repository's `common/` and `sim64/` (plus its generated tables); the repository was not touched. The copy builds with the repository's own recipe (`tools/mk-exec-tm.py`, then `gcc` on `sim64.c`).
* **What I added to the copy** (Appendix F is the diff): a record (valid, address, entry and current values of the changed registers, strips done); a suspend step in `pdp64_exception` and a resume step at `vec`; a switch `SR_MODE` (0 today's restart, 1 resume); a cost `SR_COST` charged half at a suspension and half at a resume; a **tick hook** (`SR_T`, `SR_PHASE`): after any strip, when the model's vector-cycle count passes the next tick, the hook suspends the block as an interrupt would and calls the executor's own `enter` for vector 32, whose handler is one `rti`; a stop (`SR_LIMIT`) for a block that does not finish within 6 times its length; and in `sim64.c` a way to run with the `-x` window warm (`SR_WARM`) and to re-arm the faults after the data was initialised (a store to the last word of the window).
* **What the hook is not.** It is not an interrupt controller or a real timer: it fires on vector-cycle counts only, after a strip commits, and the handler's cycles are not counted. It is the first time any interrupt is taken inside a block in this repository.
* **The 12 phases.** For a tick period T and block length L: if T is at most 2 L, 12 evenly spaced phases over [0, T); otherwise 12 over [0, L) weighted by L/T (the chance the block is hit). The expected ratio is that average. `never` means the block ran past 6 L (the restart that cannot finish).
* **Checks.** Each program ends by folding its result (C tile, dot result, 2D output) into the exit status. Tick runs and fault runs of every design equal the uninterrupted run's (floating-point programs compare against the same cutting: a bounded float program sums in a different order from the unbounded one, as the program chose).
* **Design B** was not built. Its in-context columns are resume with no cost; its switch column adds the counted save and restore (8 bytes a cycle: 16 accumulators of 16 bytes is 2 cycles each, plus the changed registers, the block address and a flag, both ways: 40 cycles for the 8 accumulators of the micro-kernel, 14 for the one-accumulator dots).

## Appendix B. The programs

The micro-kernel is the repository's `docs/encoding-work/arch-data/vec-forms/blas/k_sgemm_nt.ukr.s` unchanged; the 2D block is `tiles/k_avg.vec2d.s` unchanged; the data are at absolute addresses 0x800000, 0x900000, 0xb00000 in the `-x` window. The dot products:

```
; float dot, accumulator form (r0 = x, r1 = y, r2 = n; r4 holds the sum)
k:	lea	(r0)(r2*4),r3
	vec	r0,r3
	vclr.f	v4,#1
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vfma.f	v4,v0,v1
	vfin
	vacc.f	r4,v4
	vend
	ret
; int8 dot, accumulator form
k:	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v4,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v4,v0,v1
	vfin
	vacc.l.q	r4,v4
	vend
	ret
; float dot, no accumulator
k:	lea	(r0)(r2*4),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vmul.f	v0,v0,v1
	vacc.f	r4,v0
	vend
	ret
```
The int8 dot without an accumulator is the repository's `k_q8dot.vec.s`. The driver sets `vbr` to a table whose entries all point at `rti`, loads the registers, calls the kernel and halts. The **bounded** versions call the same kernel for chunks of 256 strips (K steps for the micro-kernel, 1,024 floats or 4,096 bytes for the dots) with `r4` cleared once outside (the micro-kernel adds into C itself). With data checks the driver first fills the arrays with floats in [1, 2) from a small generator and ends with an exclusive-or fold of the result into the exit status.

### C.1 Page faults (every page's first touch faults once; the handler is one `rti`)

Vector cycles, then the ratio to the warm uninterrupted unbounded run of the same program (warm cycles in the first column). "Bounded" is the program cut into blocks of 256 strips (its own warm run is longer by the cut: 0.3 to 1.0%, so its ratio has that floor). "Susp" is the number of suspensions that resume kept.

| program | warm | restart (today) | restart, bounded | A resume (8 cycles a suspension) | susp | B in place (no cost counted) |
|---|---:|---:|---:|---:|---:|---:|
| ukr 64 | 667 | 1,311 (1.97) | 1,311 (1.966) | 678 (1.016) | 1 | 670 (1.004) |
| ukr 256 | 2,587 | 6,433 (2.49) | 6,433 (2.487) | 2,607 (1.008) | 2 | 2,591 (1.002) |
| ukr 1024 | 10,267 | 71,731 (6.99) | 18,046 (1.758) | 10,368 (1.010) | 11 | 10,280 (1.001) |
| ukr 4096 | 40,987 | 1,024,123 (24.99) | 64,498 (1.574) | 41,412 (1.010) | 47 | 41,036 (1.001) |
| fdotacc 4096 | 4,100 | 16,402 (4.00) | 4,120 (1.005) | 4,156 (1.014) | 6 | 4,108 (1.002) |
| fdotacc 16384 | 16,388 | 262,210 (16.00) | 16,480 (1.006) | 16,660 (1.017) | 30 | 16,420 (1.002) |
| fdotacc 262144 | 262,148 | 67,109,890 (256.00) | 263,680 (1.006) | 266,740 (1.018) | 510 | 262,660 (1.002) |
| i8acc 4096 | 4,100 | 4,102 (1.00) | 4,102 (1.000) | 4,102 (1.000) | 0 | 4,102 (1.000) |
| i8acc 65536 | 65,540 | 1,048,642 (16.00) | 65,632 (1.001) | 65,812 (1.004) | 30 | 65,572 (1.000) |
| i8acc 1048576 | 1,048,580 | 268,436,482 (256.00) | 1,050,112 (1.001) | 1,053,172 (1.004) | 510 | 1,049,092 (1.000) |
| fdot 262144 (no accumulator) | 196,609 | 197,121 (1.00) | same | same | | same |
| i8dot 1048576 (no accumulator) | 163,841 | 164,353 (1.00) | same | same | | same |
| avg 64 (no accumulator) | 964 | 976 (1.01) | same | same | | same |
| avg 256 (no accumulator) | 14,596 | 14,788 (1.01) | same | same | | same |

### C.2 Timer ticks (an interrupt injected after a strip when the vector-cycle count passes the next tick)

Expected ratio to the warm unbounded run for a random phase of the tick against the block (12 phases; a block shorter than the tick is weighted by its chance of being hit). `never` = the block did not finish within 6 times its length for every phase tried. T is the tick period in vector cycles: 10,000 is 100 MHz at 10 kHz (or 1 GHz at 100 kHz), 100,000 is 100 MHz at 1 kHz (1 GHz at 10 kHz), 1,000,000 is 100 MHz at 100 Hz (1 GHz at 1 kHz), 10,000,000 is 1 GHz at 100 Hz. "B + switch" adds the counted cost of saving and restoring the state at every tick as if each tick were a context switch (40 cycles for the micro-kernel, 14 for the dots); A at every tick being a context switch is the restart column.

| program | T | restart (today) | restart, bounded | A resume | B in place | B + switch |
|---|---:|---:|---:|---:|---:|---:|
| ukr 64 | 10,000 | 1.0338 | 1.0338 | 1.0009 | 1.0001 | 1.0041 |
| ukr 64 | 100,000 | 1.0034 | 1.0034 | 1.0001 | 1.0000 | 1.0004 |
| ukr 64 | 1,000,000 | 1.0003 | 1.0003 | 1.0000 | 1.0000 | 1.0000 |
| ukr 64 | 10,000,000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| ukr 256 | 10,000 | 1.1298 | 1.1298 | 1.0009 | 1.0001 | 1.0041 |
| ukr 256 | 100,000 | 1.0130 | 1.0130 | 1.0001 | 1.0000 | 1.0004 |
| ukr 256 | 1,000,000 | 1.0013 | 1.0013 | 1.0000 | 1.0000 | 1.0000 |
| ukr 256 | 10,000,000 | 1.0001 | 1.0001 | 1.0000 | 1.0000 | 1.0000 |
| ukr 1024 | 10,000 | never | 1.1718 | 1.0009 | 1.0001 | 1.0040 |
| ukr 1024 | 100,000 | 1.0514 | 1.0210 | 1.0001 | 1.0000 | 1.0004 |
| ukr 1024 | 1,000,000 | 1.0051 | 1.0092 | 1.0000 | 1.0000 | 1.0000 |
| ukr 1024 | 10,000,000 | 1.0005 | 1.0080 | 1.0000 | 1.0000 | 1.0000 |
| ukr 4096 | 10,000 | never | 1.2695 | 1.0009 | 1.0001 | 1.0041 |
| ukr 4096 | 100,000 | 1.2050 | 1.0187 | 1.0001 | 1.0000 | 1.0004 |
| ukr 4096 | 1,000,000 | 1.0205 | 1.0108 | 1.0000 | 1.0000 | 1.0000 |
| ukr 4096 | 10,000,000 | 1.0020 | 1.0100 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 4096 | 10,000 | 1.2051 | 1.0546 | 1.0009 | 1.0001 | 1.0015 |
| fdotacc 4096 | 100,000 | 1.0205 | 1.0081 | 1.0001 | 1.0000 | 1.0001 |
| fdotacc 4096 | 1,000,000 | 1.0021 | 1.0034 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 4096 | 10,000,000 | 1.0002 | 1.0030 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 16384 | 10,000 | never | 1.0660 | 1.0009 | 1.0001 | 1.0015 |
| fdotacc 16384 | 100,000 | 1.0819 | 1.0071 | 1.0001 | 1.0000 | 1.0002 |
| fdotacc 16384 | 1,000,000 | 1.0082 | 1.0040 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 16384 | 10,000,000 | 1.0008 | 1.0037 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 262144 | 10,000 | never | 1.0839 | 1.0009 | 1.0001 | 1.0015 |
| fdotacc 262144 | 100,000 | never | 1.0072 | 1.0001 | 1.0000 | 1.0001 |
| fdotacc 262144 | 1,000,000 | 1.1311 | 1.0042 | 1.0000 | 1.0000 | 1.0000 |
| fdotacc 262144 | 10,000,000 | 1.0131 | 1.0039 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 4096 | 10,000 | 1.2051 | 1.2051 | 1.0009 | 1.0001 | 1.0015 |
| i8acc 4096 | 100,000 | 1.0205 | 1.0205 | 1.0001 | 1.0000 | 1.0001 |
| i8acc 4096 | 1,000,000 | 1.0021 | 1.0021 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 4096 | 10,000,000 | 1.0002 | 1.0002 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 65536 | 10,000 | never | 1.2180 | 1.0009 | 1.0001 | 1.0015 |
| i8acc 65536 | 100,000 | 1.3391 | 1.0063 | 1.0001 | 1.0000 | 1.0002 |
| i8acc 65536 | 1,000,000 | 1.0328 | 1.0023 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 65536 | 10,000,000 | 1.0033 | 1.0011 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 1048576 | 10,000 | never | 1.2205 | 1.0009 | 1.0001 | 1.0015 |
| i8acc 1048576 | 100,000 | never | 1.0165 | 1.0001 | 1.0000 | 1.0002 |
| i8acc 1048576 | 1,000,000 | never | 1.0030 | 1.0000 | 1.0000 | 1.0000 |
| i8acc 1048576 | 10,000,000 | 1.0524 | 1.0011 | 1.0000 | 1.0000 | 1.0000 |

The programs without an accumulator (float dot with `vmul`/`vacc`, int8 dot with `vdacc`, the 2D block) were run at every T under the same hook: their ratio is between 1.0000 and 1.0004 in every design, because they resume at the strip in all of them.

## Appendix D. The Verilog that was synthesised

Method as `tools/gates/gates.sh` (unchanged script, new file): `yosys` `synth -flatten`, `abc -g NAND`, count NAND2 plus half the inverters, flip-flops apart. Written to be counted, not used.

```verilog
// Blocks of the resume study (docs/encoding-work/vector-resume-design.md, appendix), written to be counted, not to be used; same method as tools/gates/blocks.v

// ---- today: the hidden copy vrun/vrst and the naming register (common/pdp64exec_vec.inc:819-821, 927-935, 1004; pdp64exec.c:364,418,435,616)
module today(input clk, input rst, input vec_start, input [63:0] start, input hidden, input blk_end, input clear_ev,
             input set_clr, input [15:0] clr_bits,
             output reg [15:0] vacc, output restore);
  reg [63:0] vrun_pc, vrst_pc; reg [15:0] vrun_acc, vrst_acc; reg vrun_valid, vrst_valid;
  assign restore = vec_start & vrst_valid & (vrst_pc == start);
  always @(posedge clk) begin
    if (rst) begin vrun_valid <= 0; vrst_valid <= 0; vacc <= 0; end
    else begin
      if (vec_start) begin
        if (vrun_valid) begin vrst_pc <= vrun_pc; vrst_acc <= vrun_acc; vrst_valid <= 1; end
        vrun_valid <= 0;
        if (vrst_valid & (vrst_pc == start)) begin vacc <= vrst_acc; vrst_valid <= 0; end
        if (hidden) begin vrun_valid <= 1; vrun_pc <= start; vrun_acc <= vacc; end
      end
      if (set_clr) vacc <= vacc | clr_bits;
      if (blk_end) begin vacc <= 0; vrun_valid <= 0; end
      if (clear_ev) vacc <= 0;
    end
  end
endmodule

// ---- the naming register alone (what option 1 keeps: a variable of the running block)
module naming(input clk, input rst, input set_clr, input [15:0] clr_bits, input blk_end, output reg [15:0] vacc);
  always @(posedge clk) if (rst | blk_end) vacc <= 0; else if (set_clr) vacc <= vacc | clr_bits;
endmodule

// ---- A: the resume record with its binding (NW = 4 entries; E compare and P write-back one entry at a time through the existing register-file ports)
module rrec(input clk, input rst,
            input susp, input [63:0] s_pc, input [34:0] s_tag, input [63:0] s_E, input [63:0] s_P, input [1:0] s_idx, input [2:0] s_n,
            input ret, input [31:0] r_tok, input [63:0] r_pc, input [34:0] c_tag,
            input chk_start, input [1:0] chk_idx, input [63:0] rd_val,
            input ev_vecuse, input ev_ctxwrite, input ev_genter_other, input ev_icinv, input ev_mcheck, input retire_other,
            input [47:0] key_in, input key_load,
            output [31:0] tok_out, output [63:0] P_out, output resume_ok, output armed_o, output valid_o);
  reg valid, armed, ok; reg [31:0] tok, cnt; reg [47:0] key; reg [63:0] pc; reg [34:0] tag; reg [2:0] n;
  reg [63:0] E0, E1, E2, E3, P0, P1, P2, P3;
  // the token: the counter through a keyed 3-round Feistel network on 16-bit halves
  wire [15:0] l0 = cnt[31:16], r0 = cnt[15:0];
  wire [15:0] f0 = (r0 + key[15:0]) ^ {r0[10:0], r0[15:11]};
  wire [15:0] l1 = r0, r1 = l0 ^ f0;
  wire [15:0] f1 = (r1 + key[31:16]) ^ {r1[10:0], r1[15:11]};
  wire [15:0] l2 = r1, r2 = l1 ^ f1;
  wire [15:0] f2 = (r2 + key[47:32]) ^ {r2[10:0], r2[15:11]};
  wire [15:0] l3 = r2, r3 = l2 ^ f2;
  wire [31:0] newtok = {l3, r3};
  assign tok_out = tok;
  wire match = valid & ret & (r_tok == tok) & (r_pc == pc) & (c_tag == tag);
  wire [63:0] Esel = chk_idx == 0 ? E0 : chk_idx == 1 ? E1 : chk_idx == 2 ? E2 : E3;
  assign P_out = chk_idx == 0 ? P0 : chk_idx == 1 ? P1 : chk_idx == 2 ? P2 : P3;
  assign resume_ok = armed & ok;
  assign armed_o = armed; assign valid_o = valid;
  wire kill = ev_vecuse | ev_ctxwrite | ev_genter_other | ev_icinv | ev_mcheck;
  always @(posedge clk) begin
    if (key_load) key <= key_in;
    if (rst | kill) begin valid <= 0; armed <= 0; end
    else begin
      if (susp) begin valid <= 1; armed <= 0; pc <= s_pc; tag <= s_tag; n <= s_n; tok <= newtok; cnt <= cnt + 1; ok <= 1;
        case (s_idx) 0: begin E0 <= s_E; P0 <= s_P; end 1: begin E1 <= s_E; P1 <= s_P; end 2: begin E2 <= s_E; P2 <= s_P; end default: begin E3 <= s_E; P3 <= s_P; end endcase end
      if (match) armed <= 1;
      else if (ret & valid) valid <= 0;   // a return that does not match leaves the record unless it presents the token (simplified: discard)
      if (retire_other) armed <= 0;
      if (chk_start) ok <= 1;
      else if (armed & (rd_val != Esel)) ok <= 0;
    end
  end
endmodule

// ---- the admission checks at vec (decode of the body, one instruction a cycle): the written-register count against NW, and a load and a store with one base register
module admit(input clk, input clear, input valid_i, input is_load, input is_store, input [4:0] base, input is_written, input [4:0] wreg,
             output inplace, output too_many);
  reg [31:0] ldset, stset, wmask; reg [2:0] cnt;
  wire [31:0] dbase = 32'd1 << base, dw = 32'd1 << wreg;
  assign inplace = |(ldset & stset);
  assign too_many = cnt > 4;
  always @(posedge clk) begin
    if (clear) begin ldset <= 0; stset <= 0; wmask <= 0; cnt <= 0; end
    else if (valid_i) begin
      if (is_load) ldset <= ldset | dbase;
      if (is_store) stset <= stset | dbase;
      if (is_written & ~wmask[wreg]) begin wmask <= wmask | dw; if (cnt != 7) cnt <= cnt + 1; end
    end
  end
endmodule

// ---- the block bound: the first stream's length against NMAX = 256 strips (unit = bytes of one element step, up to 255)
module nmax(input [63:0] rs, input [63:0] re, input [7:0] unit, output over);
  wire [63:0] d = re - rs;
  assign over = d > {48'b0, unit, 8'b0};
endmodule

// ---- B: architectural state (the OS saves it): owner tag, status, the address of the vec, the read path of 36 words, the write path into the accumulators
module bstate(input clk, input rst, input susp, input [63:0] s_pc, input [34:0] s_tag, input [34:0] c_tag, input vecuse, input sw_write, input [63:0] wd,
              input restore_clean, output trap, output reg [63:0] pc, output reg [1:0] status);
  reg [34:0] tag;
  // status: 0 off, 1 initial, 2 clean, 3 dirty
  wire foreign = vecuse & (c_tag != tag);
  assign trap = foreign & (status != 0);
  always @(posedge clk) begin
    if (rst) status <= 0;
    else begin
      if (susp) begin pc <= s_pc; tag <= s_tag; status <= 3; end
      if (sw_write) begin status <= 3; tag <= c_tag; end
      if (restore_clean) status <= 2;
    end
  end
endmodule
module bread(input [255:0] w0, input [255:0] w1, input [255:0] w2, input [255:0] w3, input [255:0] w4, input [255:0] w5, input [255:0] w6, input [255:0] w7,
             input [255:0] w8, input [63:0] pcw, input [63:0] stw, input [5:0] sel, output reg [63:0] y);
  // 32 accumulator words (8 x 256 bits here = 32 words of 64), then pc and status: 34 words
  wire [63:0] a [0:33];
  genvar i;
  generate for (i = 0; i < 4; i = i + 1) begin : g
    assign a[i] = w0[64*i +: 64]; assign a[4+i] = w1[64*i +: 64]; assign a[8+i] = w2[64*i +: 64]; assign a[12+i] = w3[64*i +: 64];
    assign a[16+i] = w4[64*i +: 64]; assign a[20+i] = w5[64*i +: 64]; assign a[24+i] = w6[64*i +: 64]; assign a[28+i] = w7[64*i +: 64];
  end endgenerate
  assign a[32] = pcw; assign a[33] = stw;
  always @* y = (sel < 34) ? a[sel] : 64'b0;
endmodule
// the write path: each of the 16 accumulator registers (128 bits: the least strip) gets a second source (the system register word) and an enable
module bwrite(input [2047:0] wd_normal, input [63:0] sw_word, input [5:0] sel, input sw_we, input [2047:0] q_old, output [2047:0] d_new);
  genvar i;
  generate for (i = 0; i < 32; i = i + 1) begin : g
    wire hit = sw_we & (sel == i);
    assign d_new[64*i +: 64] = hit ? sw_word : wd_normal[64*i +: 64];
  end endgenerate
endmodule
```

## Appendix E. The synthesis output

```
module     NAND2 logic   flip-flops   NAND2 equivalents (logic + 6 per flip-flop)
today          476          178          1,544
naming          34           16            130
rrec         3,517          726          7,873
admit          484           99          1,078
nmax           711            0            711
bstate         315          101            921
bread        5,551            0          5,551
bwrite       6,235            0          6,235
```
Notes. (1) `rrec` is the record for four changed registers: 726 flip-flops are the token (32), the counter (32), the key (48), the address (64), the tag (35), valid, armed and check bits, and the entry and current values (512). The comparison of the entry values and the write-back of the current values go through a 4-to-1 multiplexer and one 64-bit comparator, **one register at a time through the register file's existing ports** (an assumption about the register file; four extra read ports would cost far more). (2) A flip-flop with an enable is counted as a flip-flop, as the repository's method does; the enable is not expanded into multiplexers. (3) Each further changed register costs about 1,000 (128 flip-flops at 6 plus a share of the multiplexers; computed, not separately synthesised). (4) `bread` and `bwrite` model design B's window of 34 words read and 2,048 accumulator bits written.

## Appendix F. The change to the scratch copy (not the repository)

Unified diff of the four files, long comment lines cut.

```diff
@@ -57,6 +57,11 @@
 	uint64_t v2n[VC_N];				/* the vector instructions run, by class */
 	int vrow, vrow_set;				/* the 2D block (vec2, errata 176): the model's cost of the row advance, cycles a row (used if vrow_set; default 1: an ASSUMPTION, vec-2d.md) */
 	uint64_t vrows, vskips, v2blocks;		/* rows run, vskip words decoded, vec2 blocks run */
+	/* SCRATCH (resume study): the record and the benchmark hooks */
+	int sr_cfg, sr_mode;			/* mode 0: today's restart; 1: resume in place */
+	int sr_valid; uint64_t sr_pc; uint32_t sr_wmask; uint64_t sr_E[32], sr_P[32]; long sr_k;
+	long sr_done; uint32_t sr_curw; uint16_t sr_curnam; uint64_t sr_curpc; int sr_cur;
+	uint64_t sr_cost, sr_T, sr_next, sr_limit, sr_nsusp, sr_nres, sr_nrestart, sr_overhead; int sr_nw;
 	struct { uint64_t r[32], pc, dp, fpsr; int fN, fZ, fV, fC; } snap;	/* the state at the start of the instruction, for precise aborts (kept only when deliver is on) */
 };
 
@@ -945,9 +945,8 @@
 	uint64_t epc = c->pc;
 	uint32_t insn = c->snap_valid ? c->cur_insn : 0;				/* a fault in the translation of the fetch (before the instruction began) has no instruction to show */
 	C = c; E = e;
-	if (c->vhidden) {									/* a block with hidden accumulation: it restarts from its entry, the accumulators discarded (hidden state is not saved: R435) */
-		for (int v = 0; v < 16; v++) if (c->vacc >> v & 1) memset(c->vr[v], 0, sizeof c->vr[v]);
-		c->vhidden = 0;
+	if (c->vhidden) {
+		sr_suspend();c->vhidden = 0;
 	}
 	if (c->snap_valid) {
 		if (!c->progress) {							/* an abort leaves no trace: the registers (the (rN)+ and -(rN) updates among them) are as before */
@@ -842,6 +842,33 @@
 	C->vrows++;
 }
 
+
+/* SCRATCH (resume study) */
+static void sr_config(void)
+{
+	if (C->sr_cfg) return;
+	C->sr_cfg = 1;
+	const char *e;
+	C->sr_mode = (e = getenv("SR_MODE")) ? atoi(e) : 0;
+	C->sr_cost = (e = getenv("SR_COST")) ? strtoull(e, 0, 10) : 0;
+	C->sr_T = (e = getenv("SR_T")) ? strtoull(e, 0, 10) : 0;
+	C->sr_next = C->sr_T; if ((e = getenv("SR_PHASE"))) C->sr_next = strtoull(e, 0, 10);
+	C->sr_limit = (e = getenv("SR_LIMIT")) ? strtoull(e, 0, 10) : 0;
+	C->sr_nw = (e = getenv("SR_NW")) ? atoi(e) : 4;
+}
+/* called when an exception interrupts a running hidden block (regs are the committed progress; snap is the entry) */
+static void sr_suspend(void)
+{
+	C->sr_valid = 0;
+	if (C->sr_mode == 1 && C->sr_done >= 1 && __builtin_popcount(C->sr_curw) <= C->sr_nw) {
+		C->sr_valid = 1; C->sr_pc = C->sr_curpc; C->sr_wmask = C->sr_curw; C->sr_k = C->sr_done;
+		for (int i = 0; i < 32; i++) { C->sr_E[i] = C->snap.r[i]; C->sr_P[i] = C->r[i]; }
+		C->vcycles += C->sr_cost / 2; C->sr_overhead += C->sr_cost / 2; C->sr_nsusp++;
+	} else {
+		C->sr_nrestart++;
+		for (int v = 0; v < 16; v++) if (C->vacc >> v & 1) memset(C->vr[v], 0, sizeof C->vr[v]);
+	}
+}
 static void vec_run(const struct einsn *vin, uint64_t start, int nvec)
 {
 	struct vdec body[VMAXBODY];
@@ -919,12 +946,33 @@
 		if (wr & rd) die("vec2: Rw and the registers of the vskip declarations are read only: the block writes one of them", 0);
 		if (C->vacc) die("vec2: accumulators are named before the block", 0);
 	}
+	sr_config();
+	int sr_resumed = 0, sr_hasclr = 0; uint32_t sr_w = 0; uint16_t sr_nam = 0;
+	for (int i = 0; i < nb; i++) {
+		const struct vinfo *vi = body[i].vi;
+		if (vi->op == VO_CLR) { sr_hasclr = 1; for (int j = 0; j < (int)body[i].in.op[1].v && ((body[i].in.op[0].r + j) & 15) == body[i].in.op[0].r + j; j++) sr_nam |= (uint16_t)1 << (body[i].in.op[0].r + 
+		for (int k = 0; k < 4; k++) if (body[i].in.op[k].k == EK_PI) sr_w |= 1u << (body[i].in.op[k].r & 31);
+		if (vi->op == VO_ACC || vi->op == VO_MAXACC || vi->op == VO_MINACC || vi->op == VO_DACC || vi->op == VO_SAD) sr_w |= 1u << (body[i].in.op[0].r & 31);
+	}
+	C->sr_curw = sr_w; C->sr_curnam = sr_nam; C->sr_curpc = start; C->sr_done = 0; C->sr_cur = sr_hasclr;
+	if (C->sr_mode == 1 && sr_hasclr && C->sr_valid) {
+		int ok = C->sr_pc == start && C->sr_wmask == sr_w;
+		for (int i = 0; ok && i < 32; i++) if ((sr_w >> i & 1) && RG[i] != C->sr_E[i]) ok = 0;
+		if (ok) {
+			for (int i = 0; i < 32; i++) if (sr_w >> i & 1) RG[i] = C->sr_P[i];
+			C->vacc = sr_nam; C->sr_done = C->sr_k; sr_resumed = 1; C->sr_nres++;
+			C->vcycles += C->sr_cost / 2; C->sr_overhead += C->sr_cost / 2;
+			vrun_valid = 0; vrst_valid = 0;
+		} else for (int v = 0; v < 16; v++) if (sr_nam >> v & 1) memset(VR(v), 0, VBYTES);
+		C->sr_valid = 0;
+	}
 	C->vblocks++;
 	if (found_end) C->vcycles++;						/* the model: the vend (the vec is one of the scalar instructions) */
 	if (two) { C->v2blocks++; C->vskips += (uint64_t)nskip; C->vcycles += (uint64_t)nskip; }	/* and each vskip, a decode slot like the vend (an assumption: vec-2d.md) */
 	/* hidden accumulation (a vclr in the block, an accumulator named before it, a vfin): hidden state is not saved at a context switch (R435), so an abort
 	   restarts the block from its entry and discards the accumulators (vec-isa.md 4.1, the second option).  Otherwise the pointers are the progress and the block
 	   goes on from the strip it stopped at. */
+	if (!sr_resumed) {
 	if (vrun_valid) { vrst_pc = vrun_pc; vrst_acc = vrun_acc; vrst_valid = 1; }	/* a hidden block that did not end was aborted by a fault: its hidden copy is kept for the restart */
 	vrun_valid = 0;
 	if (vrst_valid && vrst_pc == start) {			/* the restart of an aborted hidden block: the naming of its accumulators is part of the hardware's copy made at the vec, so a handler that ran vector code of
@@ -933,6 +981,7 @@
 		for (int v = 0; v < 16; v++) if (C->vacc >> v & 1) memset(VR(v), 0, VBYTES);
 		vrst_valid = 0;
 	}
+	}
 	int hidden = C->vacc != 0 || fin >= 0;
 	for (int i = 0; i < nb; i++) if (body[i].vi->op == VO_CLR) hidden = 1;
 	/* the strip of a block with accumulators or a vfmab is 16 bytes on every implementation (errata 173, vec-isa.md section 8): an accumulator's lanes, and the number of strips a (Ra)+ of vfmab moves
@@ -968,7 +1017,7 @@
 		uint64_t rem = (end - cur) / unit;
 		if (rem == 0) break;
 		x->nact = rem < (uint64_t)vl ? (int)rem : vl;
-		x->first = strip == 0;
+		x->first = strip == 0 && !sr_resumed;
 		vstrip_run(x, body, nmain, e0);
 		x->cyc_c = x->cyc_m = 0;
 		for (int i = 0; i < nmain; i++) { x->mb = 0; vop(x, body[i].vi, &body[i].in); m2mb[i] = x->mb; }
@@ -984,6 +1033,19 @@
 			if (C->vm2) { VM2.slot += (uint64_t)VROW; VM2.end += (uint64_t)VROW; VM2.comp[strip & 15] += (uint64_t)VROW; C->v2cycles += (uint64_t)VROW; }
 		}
 		vec_commit(x);
+		C->sr_done++;
+		if (C->sr_T && C->vcycles >= C->sr_next) {
+			while (C->sr_next <= C->vcycles) C->sr_next += C->sr_T;
+			if (C->sr_limit && C->vcycles > C->sr_limit) { fprintf(stderr, "SR: LIVELOCK vcycles %llu\n", (unsigned long long)C->vcycles); exit(99); }
+			if (hidden) {
+				sr_suspend();
+				memcpy(C->r, C->snap.r, sizeof C->r);
+				C->vhidden = 0;
+			} else C->sr_nsusp++;
+			C->progress = 0;
+			enter(32, start, 0);
+			return;
+		}
 		if (!two && RG[rs] == cur) die("vec: the pointer register does not move", 0);
 		if (strip > (1L << 26)) die("vec: runaway block", 0);
 	}
@@ -127,6 +127,7 @@
 {
 	uint8_t *p = pgget(a);
 	if (!p) memfault(VECTOR_BUSFAULT, "access to unmapped memory", a);
+	if (xarmed && write && a == xhi - 8) { memset(xarmed, 1, (xhi - xlo) / PG); xarmed[(a - xlo) / PG] = 0; }
 	if (xarmed && a >= xlo && a < xhi && xarmed[(a - xlo) / PG]) { xarmed[(a - xlo) / PG] = 0; memfault(write ? VECTOR_SFAULT : VECTOR_LFAULT, "first access to a -x page", a); }
 	return p + (a & (PG - 1));
 }
@@ -279,6 +280,7 @@
 
 static void vec_write(void)
 {
+	fprintf(stderr, "SR: vector_cycles %llu strips %llu susp %llu resumed %llu restarts %llu overhead %llu\n", (unsigned long long)cpu.vcycles, (unsigned long long)cpu.vstrips, (unsigned long long)cpu.s
 	fprintf(stderr, "sim64: vec blocks %llu strips %llu ops %llu elems %llu\n", (unsigned long long)cpu.vblocks, (unsigned long long)cpu.vstrips, (unsigned long long)cpu.vops, (unsigned long long)cpu.ve
 	/* the cycle model (docs/sim64.md): scalar instructions started (the vec of a block is one of them) are one cycle each; the vector cycles are the vends and, for each strip, the greater of
 	   its compute and memory-port cycles plus the commit cost.  `steps` is the number of instructions completed before the one that ended the program */
@@ -373,7 +375,7 @@
 		else if (!strcmp(argv[i], "-x") && i + 1 < argc) {
 			unsigned long long lo, hi;
 			if (sscanf(argv[++i], "%lli:%lli", (long long *)&lo, (long long *)&hi) != 2 || lo % PG || hi % PG || hi <= lo) { fprintf(stderr, "sim64: -x LO:HI (page aligned)\n"); return 2; }
-			xlo = lo; xhi = hi; xarmed = malloc((xhi - xlo) / PG); memset(xarmed, 1, (xhi - xlo) / PG); addregion(xlo, xhi);
+			xlo = lo; xhi = hi; xarmed = malloc((xhi - xlo) / PG); memset(xarmed, getenv("SR_WARM") ? 0 : 1, (xhi - xlo) / PG); addregion(xlo, xhi);
 		}
 		else if (!strcmp(argv[i], "-n") && i + 1 < argc) maxsteps = atol(argv[++i]);
 		else if (!strcmp(argv[i], "-P") && i + 1 < argc) profile_path = argv[++i];
```

## Appendix G. The probe of the empty block

Assembled with `as64`, linked with `ld64`, run with `sim64`. Block 1 leaves sums of `0x5a5a5a5a` in `v0`; block 2 is an empty region (`r1` = `r5`) with `vclr.l v0,#1`, a load, an add, `vfin`, `vst.l v0,(r3)`, `vend`; the destination held `0x77777777` beforehand. Result: the destination is 0 (exit status 0).

```
	vec	r1, r5		; block 1: a strip over src
	vclr.l	v0, #1
	vld.l	v8, (r1)+
	vadd.l	v0, v0, v8
	vend
	lea	src, r1		; block 2: empty region
	lea	src, r5
	lea	dst, r3
	vec	r1, r5
	vclr.l	v0, #1
	vld.l	v8, (r1)+
	vadd.l	v0, v0, v8
	vfin
	vst.l	v0, (r3)
	vend
	movl	dst, r0		; exit status = 0
```
