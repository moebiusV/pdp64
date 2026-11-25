# The holes, the return mask, the vector resume and the hypervisor text, judged again by the complete principles

*For you to read. Nothing here changes the manual, the grammar, the tools, the executor, the QEMU model or a test. I read the approved list of principles first and judged every decision below by it, in its order: safety by the ladder (prevent by construction in hardware, then by idiom in software, then mitigate, then make failure and recovery cheap), including "make the safe way the easy and cheap way" and "hardware that encourages software flaws is changed"; then speed as measured run time and power; then fewer instructions and fetches (proxies only); dense encoding; the compiler; and last, a coherent set a programmer can hold in the head. Over all of it: one binary on every implementation (a veto), measure, do not guess, hot-loop weight, soft rules, Occam, and the rule that prior work and the effort of a change are never a reason. Method: best of breed first, including old ideas; learn from the past's flaws; one generated source of truth; standard at the edges; verify before stating.*

*Labels: **measured** (a program or tool was run for this document; the programs and results are in `docs/encoding-work/bench/rejudge-holes-resume/`, with a README), **counted** (read from an earlier study's file), **assumed** (my number, said so). Gate counts are NAND2 equivalents by the repository's yosys method (a flip-flop is 6); 1,000 gates is about 0.4% of the scalar core. A difference under about 10 gates is noise. I did not re-run the earlier studies' hypervisor traces; their figures are cited as counted.*

## 0. The answer on one page

I judged 50 decisions: the 12 of the two-holes study, the 5 of the mask-reuse study, the 10 resume details together with the question of the hidden record, the 11 contradictions of the hypervisor text, and the 19 flagged items of the earlier audit (several of which are the same decisions again; I say so).

**Changed: 17.** Seven are in the first four groups (A5, B2, C4, C14, C15, D1, D4) and ten are audit items (E3, E7, E10, E11, E12, E13, E14, E16, E18, E19). Three of the seven reverse or sharpen a decision you accepted or left open, and they are the ones to read first:

1. **Stores by other cores and devices (hole 1, decision 5): yes, they count, and now.** Not "when the multi-core design is written". A rule that is true only while there is one core is the veto of one binary on every implementation. I give a cheap way that needs no wiring between cores (an epoch word in memory) and measured gates.
2. **The short two-byte `RTI` for returns to the same mode: no.** My earlier answer was "yes if the encoding has room". It is a rare instruction (a hot loop never executes it) and two-byte slots belong to frequent ones. There is then simply no plain `RTI` that returns to a lesser mode; the question whether a plain one must become illegal answers itself.
3. **The resume token: a keyed permutation of a per-guest counter, with the entropy source named as a dependency.** And **resume is written into the architecture as an optional accelerator**, which is what justifies a hidden record against the last rung of the ladder (section C0).

**Not changed, but the reasoning is new:** the directory of walked table pages (still "no for now": the arena closes the hypervisor's hole completely, and the directory's real argument is the guest's own tables, which I priced), and the prevention of the stale register after a return (the mask stays; the hardware that tracks what the kernel wrote cannot work by itself, which I measured; a hardware design in which a restored register carries its mark in the saved frame comes close and needs one more measurement, section A8).

**Needs a measurement I could not make:** 7 items, listed in section F. None of them blocks a recommendation; each has a firm answer and the measurement that would reverse it.

## Plain-words tables

### A. The two holes (stale translations after a guest reset; registers left behind by a return)

| # | decision | options | recommendation | changed? | deciding principle |
|---|---|---|---|---|---|
| A1 | The arena and its flag close the stale-translation hole | arena; flush at every entry; directory; nothing | arena, first version | stands | safety rung 1 (the hypervisor cannot forget); gates 0.5% of the core |
| A2 | Also the directory of walked table pages (OPEN) | arena only; arena plus directory | arena only for now; the directory waits for a measured kernel working set | same answer; reasoning new | safety first, but "cheaply": 6% to 13% of the core and a cliff measured |
| A3 | Flush at every entry when no arena is set | default flush; default no flush | default flush | stands | the easy way is the safe way |
| A4 | The walker refuses a table outside the arena | refuse; allow | refuse | stands | construction, not discipline |
| A5 | Stores by other cores and devices (OPEN) | range test on every core; an epoch word; only one core | yes, they count, now; devices never write the arena; epoch word for cores | **changed** | one binary (veto); construction |
| A6 | Declare no stale translation is ever seen after a stage-2 change; rewrite two checks | declare; keep old behaviour | declare | stands | safety; test must pass |
| A7 | Drop the flush bit | drop; keep | drop | stands | hardware that encourages flaws |
| A8 | `RTI #mask` is the only return to a lesser mode, hardware clears the rest | mask; hardware tracks writes; mark travels with the saved value; stash | keep the mask; no plain `RTI` to a lesser mode exists; default mask from the ABI; one more measurement on marks | stands, with additions | safety (loud failures), run time, one binary |
| A9 | The mask is not a system register | mask in instruction; register | instruction | stands | run time (2 instructions); silent stale mask |
| A10 | Flash clear, not lazy clear | flash; lazy | flash | stands | run time (lazy adds 2 levels on the register read) |
| A11 | No hardware stash | stash; none | none | stands | hidden state; nesting depth differs per machine (veto) |
| A12 | Same mask on `GENTER`; write the callee-saved set into the ABI | as stated | as stated; the hypervisor keeps nothing in registers across a guest | stands | construction; one source of truth |

### B. Should `RTI` reuse the mask of the `GENTER`?

| # | decision | recommendation | changed? | principle |
|---|---|---|---|---|
| B1 | Mask in the instruction, no latch | keep | stands | a silent, timing-dependent bug is unacceptable (52 leaks measured) |
| B2 | A plain two-byte `RTI` for the same mode only; a plain `RTI` to a lesser mode illegal | no short form at all; the mask form is the only `RTI` | **changed** | dense encoding (rare instruction longer), Occam |
| B3 | One latch per kind of return | no | stands | extra state, one more duty |
| B4 | A guest's `RTI` does not use the mask of the `GENTER` | agree | stands | facts known to different code |
| B5 | The hypervisor keeps nothing in registers across `GENTER`; change the test programs | yes | stands | construction |

### C. Vector resume

| # | decision | recommendation | changed? | principle |
|---|---|---|---|---|
| C0 | A hidden record across exceptions, against the last rung | justified, on five stated conditions; write "resume is optional" into the architecture | stands, **with a new rule** | rung (d) restart without hidden state; veto; measured run time |
| C3 | How many changed registers a resumable block may have | four | stands | measured: 16 of 16 repository accumulator blocks change 3 or fewer |
| C4 | The token | 32 bits in the saved status; a keyed permutation of a per-guest counter; the entropy source named as a dependency | **changed** | construction; no covert channel |
| C5 | What discards progress | as listed | stands | no covert channel |
| C6 | Zero the sums at `vend` and every discard | yes | stands | no strange side effect |
| C7 | Refuse an in-place accumulator block, main loop only | yes, in hardware at `vec` | stands (measured: no existing block is hit) | construction |
| C9 | Interrupts at strip boundaries | yes; a requirement, not a test convenience | stands, **firmer** | safety (a user cannot hold off the kernel) |
| C11 | Refusals are exceptions, not simulator aborts | yes | stands | precise exceptions |
| C13 | State saved by the OS, later | later, but only while the 256-strip bound stays | stands, with a stated dependency | speed measured; kernel duty avoided |
| C14 | What a handler sees in the pointers | leave; the strip size is declared discoverable, not hidden | **changed** (decided) | veto allows "discoverable" |
| C15 | The manual text | yes, with three statements added | **changed** (additions) | verify; one source |

### D. The eleven contradictions and ambiguities of the hypervisor text

| # | question | recommendation | changed? | principle |
|---|---|---|---|---|
| D1 | The hypervisor level against the older register rules | the hypervisor's ordinary register names mean its own registers; the guest's are reached by explicit names; the fourth bank and six aliases go | **changed** (a reversal) | best of breed (verified: both comparators), Occam, coherence |
| D2 | Platform map as a third term of the memory category | yes: the strictest of three | answered | construction |
| D3 | A guest access to an address no device answers | the same rule as a table read: an exit that the hypervisor can handle; a device that is there and fails is a machine check | answered | one binary; recovery |
| D4 | The two-page stage-2 root | one page like every other root; the width is discoverable | **changed** | Occam, one binary |
| D5 | The flush flag | none; the text says so | stands | decided |
| D6 | `TRAP` and `TRAPL` ranges | `TRAP` 0 to 15 (two bytes), `TRAPL` to 255; fix chapter 6, not the grammar | answered | one source of truth |
| D7 | A third exit flag `NODEV` | a value of the cause, not a flag, if the cause field has room | answered | Occam |
| D8 | Sources without recorded addresses | state nothing from them until each has an address | stands | verify before stating |
| D9 | The date of CP-40 | do not print a year for "in use"; I checked: see D9 | answered | verify |
| D10 | Resume against the manual | text follows C15 | answered | one source |
| D11 | "A group led by Creasy" | use the source's own words | answered | verify |

### E. The audit items flagged "change" or "needs measurement"

| # | item | firm recommendation | measured here? |
|---|---|---|---|
| E1 | Hidden record across exceptions | keep (C0); out-of-order rule becomes an architectural rule with a probe; the record dies, never moves, between cores | argued |
| E2 | The kernel names the registers to keep | = A8 | measured (tracking) |
| E3 | Timing and speculation "not testable here" | add a second tier of probes on a cycle model; write what a faster core may not leak | no |
| E4 | Hypervisor hardware chosen before gate and cycle counts | measure the nested walker and the exit; does not reverse the decision | not made |
| E5 | A physical interrupt always exits | keep the rule; the cheaper injection is a later routing, not a change of rule | not made |
| E6 | Stage-2 accessed and dirty bits in software | keep software (one binary); measure exits per page | not made |
| E7 | Reuse of a guest tag | the hardware allocates the number; width fixed at 16 | measured (gates) |
| E8 | Virtual IOMMU unit trapped | keep for version 1; measure map and unmap | not made |
| E9 | The arena and stores it does not see | = A5 | measured (gates) |
| E10 | Bus error by what the bus says | classify by the platform map | argued |
| E11 | What is present must be discoverable | one feature register first | argued |
| E12 | User `ISYNC` flushes nothing | it is the instruction-stream fence in every mode | argued |
| E13 | Block operations "unordered" | a small guarantee: each aligned unit written whole, at most once | argued |
| E14 | Trap bits for timing left to later | build them now, default set for a guest | argued |
| E15 | `MOVQL` is five parcels | keep | measured |
| E16 | What the flash clear covers | add the vector registers and the floating-point flags; probes | measured (gates) |
| E17 | No check instructions in the verified kernel | keep; write the boundary | not asked |
| E18 | Hand-kept counts in chapter 9 | generate | checked |
| E19 | Text left behind | change; confirmed still present | checked |

## A. The two holes

### A1, A3, A4, A6, A7: the arena, the default, the refusal, the declaration, the flush bit

These stand, and under the full list they stand more firmly than before. The ladder asks for prevention by construction in hardware where it is cheap. Flushing at every entry when no arena is set is exactly that: the hypervisor cannot forget, because it is not asked. The fast path is opted into by setting an arena, and the walker refusing a table outside it keeps the opt-in honest. The arena's hardware is one range comparator and a flag, about 1,300 gates for the core (counted; the comparator alone I re-measured at 1,072). The price of the safe default was measured earlier: 48 cycles per entry on the first hypervisor test, 3.7% to 12.8% of the published null-hypercall round trips of other machines (376 to 1,300 cycles); nothing is lost where the hypervisor already flushed. The flush bit closes nothing by itself and adds a thing to forget: it is one of the cases the principle "hardware that encourages software flaws is changed" already names, so it stays dropped. Declaring that a guest never sees a stale translation fails the two old checks that asserted the opposite; they are tests of a bug, and they are rewritten.

Past flaws dodged: the stale-translation bugs of hypervisors that leave the flush to software are the class this closes. What it repeats: the flush at entry costs what a software flush costs; no worse.

### A2. The directory of walked table pages (open): my answer is no for now

You answered "do it" next to a recommendation of "no for now". I cannot tell which you meant, so I judged it again.

*What the directory buys.* Two things. (1) Speed after a stage-2 edit: measured earlier, in a synthetic churn, 631 walks against 4,724 when the directory fits (87% fewer), and equal to the arena on the repository's hypervisor tests (1.2 against 2.8 extra cycles per entry on the stress test, 0 on the first test). (2) The table edit itself is the flush for every table page, including the guest's own and a native kernel's own. This second one is the real safety argument, and I weigh it more than the earlier study did: forgetting the invalidate after editing a page-table entry is the oldest kernel bug (a page unmapped, freed, reused, and still reachable through a stale entry).

*What it costs.* Measured: 8,300 to 16,800 gates for one translation buffer sized to the 7 to 11 pages the tests walk, so 6% to 13% of the core with two buffers; a compare of every store of every core against the slots (power); and a cliff: when the slots are fewer than the table pages that live translations depend on, the guest walked on 19,400 of 20,000 requests. A buffer of 32 entries over R regions needs about 2R+5 pages, so 16 slots serve R of 5 or fewer and a kernel with more address regions falls off the cliff. Run time is rung two, but the cliff is a measured collapse.

*Against the ladder.* The arena plus the default flush already closes the **hypervisor's** hole completely (rung one). For the guest's and the native kernel's own tables the cheap rungs are available and the directory is not cheap: the idiom (one `set_pte` routine that invalidates, and a corpus probe that finds a store to a table page without an invalidate) is rung two at no gates. I would take the directory only if a measurement of a real kernel shows its table-page working set fits a small slot count. **The deciding measurement:** distinct page-table pages live in the translation buffer under a real kernel workload, with its table-edit rate. The repository has no kernel that runs a real workload, so I cannot make it. Same answer as before, new reasons; the speed argument is weaker than the earlier study made it, the own-tables argument is stronger and still loses on cost and cliff.

### A5. Stores by other cores and devices (open): yes, now

You answered "the other way" with no comment, which I read as "do not wait for the multi-core design". Either reading leads to the same recommendation on the principles.

The earlier answer was "yes, when the multi-core design is written; until then one core". That fails the veto: nothing may be safe only because a machine has one core. The rule has to be written now, and it has to be implementable without the wiring the earlier study left uncosted.

*Devices.* The IOMMU never lets a device write an arena page, as it already refuses a device write to system registers. That is rung one: no store by a device can reach the arena, so nothing has to watch for it. Cost: one more range comparator on the IOMMU's translated write address. **Measured: 376 gates.**

*Other cores.* Two ways:

* Every core runs the range test on every other core's stores that reach the shared memory, and any hit sets its flag. **Measured: 376 gates for each remote core's store port, per core**, so for 16 cores 5,640 gates in each core, plus wiring.
* **An epoch word.** The hypervisor level keeps one 64-bit word in the arena (its address is a register). The storing core's own comparator notes that it stored into the arena and, at its next entry into a guest or at a barrier, increments the word with one atomic add. An entering core loads the word and compares it with the value it kept from its last flush; different means discard everything. No wiring between cores: ordinary cache coherence carries the word. **Measured: 747 gates on the entering core, 404 for the increment, independent of the number of cores.** Run time: one load at each entry (assumed 3 cycles, the repository's timing model, against a round trip of 376 to 1,300 cycles: 0.2% to 0.8%); the earlier trace shows the flag set at 3 of 79 entries on the first hypervisor test, so at most 3 atomic adds per 79 entries.

I recommend the epoch word: it is rung one for stores by other cores (the flaw "the hypervisor edited a table on core 0 and a guest on core 1 kept an old translation" is closed by the entry check), it grows with nothing, and it works the same on an in-order or an out-of-order core. The visibility rule is the one every shootdown has: an edit takes effect for another core when the editing core publishes it (its next entry or barrier). That is stated as the architecture's rule, so the hypervisor cannot "forget" a broadcast; there is none to forget. A probe for each: a device write to an arena page is refused and counted; a store on one core is seen at the entry of another. Changed from the earlier answer: yes.

### A8. The return mask: does it still stand, and should construction replace the idiom?

*Where the idiom is.* The clearing itself is by construction: the hardware clears every register whose mask bit is zero, in the return. What is idiom is the **naming**: the kernel (or its compiler) says which registers hold user values. Your question is whether hardware can know it, by tracking which registers the kernel wrote.

*I measured it.* I traced the repository's mini-kernel, the two-process kernel and the hypervisor test on the QEMU model with the register values, and simulated two designs at every return to a lesser mode (`tags.py`; one bit per register, set when the kernel is entered, cleared by any write).

* **T0, pure "written since entry"**: hardware clears every register the kernel wrote. It cannot tell the kernel's scratch value from the user's value the kernel saved and put back. **Measured: it clears the restored user registers at 4 of 4 interrupt and fault returns of the mini-kernel and at 70 of 70 in the two-process kernel**, and at 654 of 672 returns of the two-process kernel it wipes registers the resumed code reads (most system calls in that toy are preempted, so most pass through a restore). A kernel that saves and restores, which every interrupt handler must, is destroyed by it. It cannot be the design. Gates **+224** over the mask design (29,929 against 29,705).
* **T1, the mark travels with the value**: a `PUSHM` stores each register's bit beside the value; a `POPM` sets the bit from the stored one; any other write clears it. Measured on the same traces: **0 wrong of 8 returns in the mini-kernel; in the two-process kernel 1 leak and 6 returns losing a register the resumed code reads, of 672**, and the leak is the first start of the second process, which receives the registers of the first because nothing resets the bits at a context switch. So T1 needs a rule (a write of the address-space number or table base resets the bits, as in the resume design) and I could not explain the six losses (my model matches saved frames by stack address and may be at fault). Gates **+352** over the mask design (30,057), no extra logic depth (17 levels), a bit per register of hidden state, and one extra word in every saved frame.

*What T1 would give.* The failure direction flips: forgetting to mark a restore gives a cleared register (loud, found by the first test), and leaking needs an explicit act. No constant to compute, no stale-mask class, and a plain return always. That is attractive under "make the safe way the easy way". Against it: hidden per-core state with a reset rule (rung four does not like hidden state), a frame format change, and the restore must be a `POPM`, not ordinary loads (a kernel that copies a trap frame with ordinary loads clears everything). The earlier study measured a marker-bit file at +3,178 gates in a different arrangement; the gate difference between T1 and the mask is small (352).

*My answer.* **The mask stands** (it is accepted, it has no hidden state, and its easy error, a mask that is too small, is loud). I add three things that cost nothing in hardware:

1. There is **no plain `RTI` that returns to a lesser mode**: the only form is `RTI #mask`, so a return cannot skip the clear (B2 gives the reason for not adding a short form).
2. **The easy way is made the safe way in the tools.** The assembler and the compiler derive the mask from the same list the entry stub saved (one source of truth), and the default mask for a system-call return is the ABI's: the result and the callee-saved registers. A forgotten register is then a loud loss, never a quiet leak. A kernel that writes `RTI #-1` is writing the one spelling that leaks; the assembler warns on a mask of all ones at a return from a handler that wrote registers.
3. **Needs measurement: T1 against the mask**, built in the QEMU model and run on the three traces plus a two-guest hypervisor with a reset rule at context writes. If it shows 0 wrong on all of them, it is the better design on rung one, and I would recommend it. I did not finish it, so I do not.

*Vector and floating-point state (the same return).* The mask names 32 bits for `R0` to `R31`, and `R14` (the banked stack pointer) is never cleared, so **mask bit 14 names no register and is free**. I recommend it means "keep the vector registers"; zero (the easy spelling) clears them, and also clears the floating-point sticky flags, which are not in the saved status word. Gates, measured on a 16-register, 256-bit file: the clear costs **no more than the write multiplexer already has (the tool reports -1,013, which I read as zero)**; the scalar file cost +2,112 for 2,048 flip-flops, so up to about 4,000 is the safe upper bound. Whichever, it is under 1.5% of the vector unit. A probe for each class (a handler that leaves a value in a vector register, in the floating-point flags, in a general register) exits with the value if it survives.

Past flaws dodged: leaving the previous privilege level's register contents visible after a return (a class of information bleeds) by construction rather than by remembering. What it repeats: nothing the other architectures' studies list.

### A9, A10, A11, A12

* **A9, the mask in a system register: no.** Run time: two instructions at every return whose mask differs from the last (counted: 588 and 584 instructions over the corpus against 0). Safety: if the register keeps its value it is the silent stale mask; if it resets, it is the immediate mask with extra steps. 192 more gates.
* **A10, flash, not lazy.** Measured: flash adds no level to the register read path (17), lazy adds two (19); the register read is on every instruction's path, so run time decides, and lazy also keeps one hidden bit per register.
* **A11, no stash.** +18,497 gates for one level, +36,961 for two, +71,789 for four (counted, re-measured: 46,105 against 27,593). It needs one stash per nesting level, and the depth the machine nests is not the same on every implementation, which is the veto; it is also hidden state a context switch must handle.
* **A12, the same mask on `GENTER`, the ABI named.** Stands, with a finding from the mask-reuse study: all six hypervisor test programs keep a counter, a resume address or a device address in a register across the guest's run. Under the mask those are cleared, which is the point (the guest must not read them) and the cost is one store before and one load after for each, per exit, to the hypervisor's per-core structure (assumed 1 cycle each; 3 registers on the first test: 6 cycles of a round trip of 376 or more, under 2%). The ABI must say that `R16` to `R23` are caller-saved scratch: the LLVM back end leaves values there in 7 of 292 functions (counted) and a hand-written clear of `R1` to `R7` and `R12` would leak them.

## B. The mask-reuse study

**B1, no latch, stands.** The measurement (52 returns of 105 mismatches leaking a kernel register, 20 to 73 across four runs, because it depends where the timer ticks) is a bug that no test can pin down, and "hardware that encourages software flaws" is exactly this.

**B2, the short `RTI` for the same mode: changed to no.** Counted: 116 of the 767 `RTI`s of the two-process run return to the same mode, 464 bytes of fetch in a run of 20,715 instructions. That is a rare instruction by the principle of dense encoding (rare ones longer): it executes at the rate of interrupts, never in a hot loop. A two-byte form takes space from frequent forms and costs a decode check on the mode and a second encoding (Occam). The by-construction half, that nothing returns to a lesser mode without a mask, is kept by there being **one** `RTI`, the mask form; on a return to the same mode the mask is ignored. Earlier answer: yes if the encoding has room. The deciding measurement, if you want the short form back, is what the encoding optimiser charges the frequent forms for the slot; I did not run it.

**B3, B4:** stand. **B5, the hypervisor keeps nothing in registers across `GENTER`:** stands, and follows from the mask on `GENTER` (A12).

## C. Vector resume

### C0. Can a hidden resume record across exceptions be justified against the last rung?

The last rung says: minimise the cost of failure and recovery: precise exceptions, restart without hidden state. A resume record is hidden state across an exception. My answer is yes, under five conditions, all of which the design meets except one that is not yet written:

1. **Restart never needs it.** The handler is shown the entry values and `EPC` at the `vec`; a block started again from there is correct without any hidden state. The record accelerates; it never carries correctness. (Meets it.)
2. **Any implementation may discard it at any instant, and a program may not depend on resuming.** A core with no record at all is a conforming core. This is what the veto needs (a small core and a wide core may differ). **Not yet written in the architecture; I add it** (C15). With the accepted 256-strip bound, a core with no record still makes progress, so condition 2 is not an empty promise.
3. **It changes nothing a program can read except time and the token.** The accumulators are never visible; the handler sees entry values. (Meets it; the token and the time are the two new observables.)
4. **It dies at every context boundary by rule, not by a kernel's duty.** Tag, discard on context writes, discard on any other use of the unit. (Meets it.)
5. **Resume gives the same result as restart.** The strips run in the same order with 16-byte strips, so the floating-point sums are the same. The one exception is that a block is not atomic against other writers (the earlier strips saw the old memory); the manual already says so.

It is in the family of a translation buffer or a cache: invisible performance state with a safe fallback. The alternatives, measured earlier on the repository's own kernels: restart with the bound and no record, which meets the last rung literally and is smaller by 703 gates, costs 1.6 to 2.5 times on a cold micro-kernel, up to +27% at a 10 kHz tick, and under page faults 1.5 to 1.8 times; resume in place stays within 2% of an uninterrupted run (counted; I reproduced the warm baselines exactly with `latency.py`: 667, 10,267, 40,987, 262,148 and 1,048,580 cycles). The OS-saved state (design B) satisfies the rung even more literally but needs a kernel duty (a trap when it forgets: loud, rung three, where resume in place is rung one: the kernel cannot break it), 3,800 gates more, and a status field. Both are safe, so speed (rung two) decides, and resume in place wins. Past flaws dodged: the lazy-state bugs of kernels that forgot to save a coprocessor's state are impossible, because the kernel has nothing to save. What it repeats: the cost is gates (7,537, counted).

### C3. How many changed registers: four, and now measured

I scanned the repository's vector blocks. Of 60 blocks in the form kernels, 1 has accumulators, and it changes 2 registers (the micro-kernel). Adding the 15 accumulator blocks of the tests and the resume study's kernels, the 16 accumulator blocks change: 1 register (1 block), 2 (9 blocks), 3 (6 blocks). **None changes more than 3.** A limit of two would restart 6 of 16 (37%); four covers all with margin; the blocks without accumulators change up to 6, but they need no record (they resume by their pointers). Each extra register costs about 1,000 gates (counted). Stands.

### C4. The token: changed

The token ties a resume to the right suspension. Its job is integrity of one context's own frames (the tag and the discards already prevent any cross-context use). I changed two things.

* **It must be a keyed permutation of a counter, not any scrambler.** A permutation never repeats until the counter wraps, so uniqueness is by construction, not by the word "negligible". 32 bits wrap after 4 billion suspensions of one guest, 11.9 hours at 100,000 suspensions a second (assumed rate); a stale frame has to survive that and match the block address, tag and entry registers. I state it as a bound of 2^32 suspensions and do not call it a proof. A 48-bit token would need more than the free upper half of the saved status word; a second saved word would be the exact alternative.
* **The key must not be a global secret from a source that does not exist.** The manual leaves the entropy source open (a physical source behind the pool is undecided). Until it is decided, the per-guest key has to be loaded by the hypervisor at each `GENTER`; if no key is given, the count leaks a little between guests. I state that rather than call it closed. Measured (a sample four-round network, `gates.v`): **32-bit permuted token 1,997 gates; 48-bit 2,967; a plain 32-bit counter 331.** That is about 1% of the vector unit's 278,959, higher than the earlier "about 1,000".

### C5, C6, C7, C11: stand

C5, the discard rules, are what make the record safe across contexts; no stack of saved blocks (a stack is more hidden state and a bigger leak surface). C6, zeroing at `vend` and every discard, costs nothing measurable (it reuses the strip-start zeroing, assumed). C7: **measured, the in-place refusal at `vec` stops none of the 16 accumulator blocks I could find** (1,078 gates, counted); the 9 blocks without accumulators that store through a register they load through are allowed. The refusal is prevention by construction of a silent wrong answer (4 of 8 values wrong, measured earlier), and it covers the main loop only because the epilogue is one atomic strip. C11: a program must not be able to stop a simulator; every refusal is a precise exception.

### C9. Interrupts at strip boundaries: stands, and firmer

I argued this as a convenience for tests. It is a safety requirement. Measured under `sim64 -V`: an uninterrupted int8 dot product of 1 MiB is **1,048,580 cycles (10.5 ms at 100 MHz)**, a float dot of 262,144 elements 262,148 cycles (2.6 ms), the micro-kernel at K = 4,096 40,987 (0.41 ms). Blocks without accumulators have no bound at all, so a user program that starts one over a gigabyte (about 10 seconds at the same rate by the same scaling, assumed) could hold off the timer on its core. A user program must not be able to hold off the kernel; the interrupt waits one strip, not one block. The simulators get the poll and the "interrupt after N strips" option, and the probe runs on every implementation.

### C13. State saved by the OS, later

Stands, with a dependency I had not stated: it holds only while the 256-strip bound stays. After a context switch a block restarts; at a 1 kHz switch (100,000 cycles at 100 MHz) the counted restart ratio is 1.05 for the micro-kernel at K = 1,024 and 1.21 at K = 4,096, and a long float dot never finishes (bounded: 1.007). With the bound that is acceptable and design B waits; without it, B would be needed.

### C14. The pointers: decided

I had left this "not decided". The pointer a handler reads in an ordinary block shows where the current strip started, a multiple of the machine's strip. The veto says sizes must be discoverable or invisible; it does not say invisible. So I decide: leave it (exact in-place resume of ordinary blocks needs it), and **the strip size is declared discoverable** in the feature register (E11). It is a property of the machine, not of another context, so it bleeds nothing between contexts. Showing multiples of 16 bytes or entry values would cost a restart of ordinary blocks.

### C15. The manual text

Yes, written after you have read it and checked with the book check. Three statements are added to the ones named: (1) resume is optional and a program may not depend on it (C0 condition 2); (2) the token is the only new visible value and its bound; (3) the strip size is discoverable. The manual still says the old thing in two places (6.14.9: restart from the entry and a clear of the naming at every entry and return; 9.2.6: no hidden instruction state except a restart; the `GENTER` entry in 9.14 repeats the clear). I checked: all three are still there.

## D. The hypervisor text

**D1. Hypervisor level against the older rules: the hypervisor's own register names mean its own registers.** Both comparators the repository verified let the host operating system run at the hypervisor level with its ordinary names: Arm's E2H runs a host kernel at EL2, and RISC-V's HS mode is an ordinary kernel with translation and separately named guest registers. The accepted pdp64 rule (at `H` = 1 the system registers reach the guest's, with a fourth bank and six aliases) is an invention with no comparator. On best of breed, Occam (one bank and six aliases fewer), coherence (the hypervisor is a kernel), and the compiler/OS target (an unmodified kernel runs there), I recommend the reversal. Prior work and the effort are not reasons. I did not measure it; the deciding measurement is the gates of the duplicated registers, which I expect to be small.

**D2.** The strictest of the stage-1, stage-2 and platform categories. It costs a comparison and closes a guest mapping device memory as ordinary memory.

**D3.** A guest access to an address the platform map says no device answers behaves as the table read does: an exit the hypervisor can handle; a device that is there and answers with an error is a machine check. The same program on two interconnects must get the same result.

**D4.** One page, like every root, with the width discoverable, and a level added when more is needed. The reason for two pages (bit 39) is gone, and a special case multiplies entities.

**D5.** No flush flag; stands.

**D6.** The manual's own entry for `TRAP` says `n` is 0 to 15 in two bytes and `TRAPL` reaches 255. The grammar is the source of truth, so chapter 6 is corrected to it.

**D7.** A value of the cause, not a new flag, if the cause field has room; Occam.

**D8, D11.** Nothing from a source without an address is printed; the creator's own words are used for the origin of CP/CMS.

**D9.** I searched. Secondary sources give CP-40 development beginning in mid 1965, the first production use in January 1967, and the conversion of CP-40 and CMS to the S/360-67 beginning in September 1966. So a year of 1966 for CP-40 is doubtful. I recommend printing "conceived 1964, in use 1967" only after reading the creator's paper itself (a PDF copy is at lass.cs.umass.edu), and otherwise printing no year. I did not read the paper.

**D10.** The text follows C15.

## E. The audit items

The cross-references (E1 = C0, E2 = A8, E9 = A5) are above. The rest:

* **E3.** Change: add a second tier of probes that run on a cycle-accurate model and on any real core (timing, speculation, cache channels) and write what a faster core may not leak (a faulting load yields no data; a discarded strip leaves no trace). Without it the veto is a hope.
* **E4, E5, E6, E8: needs measurement, not made.** I could not make them: the repository has no cycle model of an exit, an entry or a nested walk, and the only exit costs are other machines' published figures. Firm recommendations anyway. E4: measure the nested walker's gates and the exit's cycles; this fixes details, it does not reverse the decision. E5: keep the rule that a physical interrupt always exits (safety, the guest can never hold off the hypervisor); if the injection cost matters, route a device's interrupt to a virtual line for its guest, which keeps the hypervisor in control. E6: keep accessed and dirty bits in software for version 1. The verified fact against changing it is that RISC-V made hardware update optional (Svade against Svadu), and an optional behaviour is exactly the one-binary hazard: every implementation must do one or the other. The cost is an exit per first write to a page, roughly 376 to 1,300 cycles against the 512 cycles of copying a 4 KiB page at 8 bytes a cycle (assumed). The deciding measurement is exits per page on a write-heavy guest. E8: keep the trapped virtual IOMMU for version 1; measure one map and one unmap through the trap against the transfer.
* **E7.** Change: the hypervisor never chooses a tag number; a hardware allocator hands one out and flushes everything when the 16-bit counter wraps, so a reused number is a new generation by construction, in the processor and the IOMMU alike. Measured: **182 gates.** Width fixed at 16 in one place.
* **E10, E11, E12, E13, E14.** E10: classify by what the platform map says the address is, not by what a bus does (the same as D3). E11: one feature register, before any software relies on a new part: hypervisor present, address width, levels, tag width, line count, strip size. E12: `ISYNC` is the instruction-stream fence in every mode, and a probe runs the write, invalidate, `ISYNC`, jump sequence of a program that generates code. E13: a small guarantee every implementation can keep: each aligned unit is written whole and at most once, no order promised; it costs nothing in an ascending loop (the executor's), and a wide engine can keep it. E14: build the trap bits now, default set for a guest; they are one gate each.
* **E15, `MOVQL`: keep five parcels. Measured:** over the 26 C test programs compiled by the repository's compiler and run under `sim64 -t`, **0 `MOVQL` executed in 6,471,858 instructions**; statically 44 of 9,955 instructions of the 586 compiled corpus functions (0.44%) need more than 32 bits, with 24 distinct constants. A hot loop hoists a loop-invariant constant into a register, so the ten bytes are paid once. The measurement that would reverse it is a hot loop that rebuilds a 64-bit constant every iteration; none appears in these programs, and they are tests, not workloads.
* **E16.** Covered in A8: the mask is extended by bit 14 to the vector registers and the floating-point flags, with a probe for each class. The checked fact: no document or executor text says the return clears either today, and the return mask does not exist in either simulator yet.
* **E17.** Keep; the boundary (what the proof states, what it assumes of the machine) is to be written down.
* **E18.** Change: the forms-and-leaves counts of chapter 9 (182 forms in 240 leaves; 32, 138 and 69 of the three lengths; the 54 added words) are hand text; they come from the grammar and are generated.
* **E19.** Change: confirmed present, in 6.14.9, 9.2.6 and the `GENTER` entry (C15).

## F. What I could not measure

1. **The table-page working set of a real kernel** (A2): no real kernel in the repository.
2. **Tags against the mask, finished** (A8): my trace model leaves six unexplained losses; the proper test is to build it in the model.
3. **The pdp64's exit, entry and world-switch cost** (E4, E5, E6, E8): not modelled anywhere; only other machines' published figures exist.
4. **Whether the machine has a random source at reset** (C4): the manual says it is open.
5. **The encoding optimiser's price for a short `RTI`** (B2): not run.
6. **A hypervisor with two guests alternating, and any second core** (A5): the traces have one core; the epoch word is costed and argued, not run.
7. **The register-banking gates of D1**: small, not measured.

## What is in the measurement directory

`docs/encoding-work/bench/rejudge-holes-resume/` (about 100 KB; the README lists each file): `gates.v` and `run_gates.sh` (gates), `tags.py` and `run_traces.sh` (the tracking designs on the traces; the traces themselves are made again, not kept), `vecscan.py` (changed registers and in-place stores per vector block), `latency.py` (block lengths under `sim64 -V`), `movql.sh` (executed and static `MOVQL`), with the saved results beside them.
