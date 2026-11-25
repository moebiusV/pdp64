# The recommendations the owner accepted, judged again by the complete principles

For the reader who has been asleep for fifty years: this is a second look at a particular kind of decision. Many times I proposed something, explained it, said "I recommend this", and the owner answered "accept". The owner has said that he does not care about saving prior work and does not care whether a decision makes more work to build or to write down. He asked me to go back over every decision where he went along with me, because my recommendations may have leaned on sunk cost, on effort, on the old and shorter list of principles, or on a convenient count in place of a measurement.

I judged each accepted recommendation by the complete approved set, in its order: safety by the ladder (prevent by construction in hardware, then by idiom in software, then mitigate, then make failure and recovery cheap; hardware that encourages a software flaw is changed; making it easy and cheap to be correct), then speed measured as run time and power, then fewer instructions and fetches as proxies only, then dense encoding, then a good compiler target, then a coherent set that is pleasant in assembler. The standing constraints apply throughout: one binary on every implementation is a veto, measure rather than guess, hot-loop weight, soft rules, Occam, and prior work or the effort of a change is never a reason.

## How I counted, and the result in one paragraph

I traced 174 individual accepted recommendations: 113 from the twelve decision forms the owner answered (the virtualisation form, the audit of sensitive instructions, the IOMMU proposals, the hypervisor design, the seL4 review, the vector-clear question, the vector review, the MMU review, the security holes, the benchmark holes, the hypervisor text, and the IOMMU/interrupt/atomics form, of which the owner answered the first five questions), and 61 older ones from the decision register, the errata and the owner's own answer files. I grouped them into 37 groups that stand or fall together. Fifteen groups pass and I say why. Twenty-two groups are tainted, covering about 47 of the decisions. Taint kinds (a group can carry more than one): sunk cost, effort, "keeps what exists" or "already built" in 15 groups; a proxy such as an instruction count, a static count of appearances or a gate count, without a run-time measurement, in 8; protection by idiom where construction was possible in 5; judged only by the old, shorter principle list in 7; no principled reason found at all in none (the nearest is the five-parcel literal). Of the 22: 4 would change the architecture, 15 change a detail, 3 are documentation only. My re-judged recommendations: change 9, needs a measurement before deciding 8, keep (some with conditions or a reworded reason) 5.

A note on the owner's own record, because it matters for trust: where he disagreed with me he was nearly always right on the principles. In the virtualisation form he overrode my "start in software" recommendation on five questions in favour of hardware; on the security holes he overrode my "leave it to the kernel" on the returned registers and the floating-point flags; on the hypervisor text he overrode "reserved bits ignored" and "pending forever" in favour of refusing at once. Every one of those overrides is what the ladder says. The tainted items below are mostly cases where he had no occasion to override because I presented the cheaper or older answer as the sensible one.

## Summary table

Seriousness: **A** changes the architecture; **D** changes a detail; **T** documentation only. Taint codes: **S** sunk cost, effort or "keeps what exists"; **P** a proxy without a run-time measurement; **I** idiom where construction was possible; **O** judged by the old principle list only.

| # | Decision | What was accepted | Taint | Re-judged recommendation | Seriousness |
|---|---|---|---|---|---|
| 1 | Stale translations after a table edit | A small arena for the hypervisor's second-stage tables, flush at every entry otherwise; the hardware directory of walked table pages put off; stores by other cores and devices put off "until the multi-core design" | P, O, S | Needs measurement: the real working set of table pages and the cost of the kernel's own invalidate duty; lean to hardware that notices stores to table pages for both stages and for the kernel's own tables; count other cores and devices now | A |
| 2 | Strip of an accumulator block | Every block that keeps sums in registers runs 16 bytes at a time on every implementation, so a 256-bit machine runs it at half width | P, S | Needs measurement: throughput of the matrix micro-kernel and of dot products at 256 and 512 bits; look for a width-independent result without halving the width | A |
| 3 | Removal of the tile, the whole-GEMM unit and the gather | Removed on static counts of assembly, "nothing uses it" and a silicon estimate | P, S | Needs measurement: run time of inference and sparse kernels with and without them | A |
| 4 | Full capability pointers (CHERI) | Rejected mainly because the compiler, the library and the kernel would all have to change; bounds put off until colouring is measured | S | Needs measurement, and the question must be reopened on safety and run time, not on software effort | A |
| 5 | Accessed and dirty bits | Software only: a clear bit faults (at the second stage, an exit) | P, S | Needs measurement: faults per page and exits per page on a write-heavy guest; likely hardware set at the second stage | D |
| 6 | Costs of exits | Physical interrupts always exit; the guest's IOMMU unit trapped and forwarded; world switch left to software; first guest software chosen small | P | Needs measurement: cycles per interrupt, per map and unmap, per world switch | D |
| 7 | The hypervisor strap and the widths | A machine strap `HVE`; "exactly today's machine, no test changes"; widths fixed in the text and not discoverable | S, O | Change: one feature register that says what exists and how wide, before software depends on it | D |
| 8 | Reuse of guest tags | The guest reset sequence and the reuse of a tag are the hypervisor's duty | O, I | Change: a hardware generation count behind each tag | D |
| 9 | Invalidates that stay untrapped | `ICINVA`, `TLBSYNC` and unscoped invalidates untrapped; a trap bit "only if timing is a concern" | I, O | Change: build the trap bit now, set by default for a guest | D |
| 10 | Reserved mode value in the saved status word | Refused when used, "as the kernel's saved word is" | S, I | Change: refuse the write | D |
| 11 | The user-access window | `UA`, `STUA`, `CLUA` kept because the manual already said so | S | Change: retire them once the per-access `.U` form covers the copy routines; count first | D |
| 12 | Store into the stream being read in a sums block | The assembler refuses the obvious case; the aliasing case stays "unpredictable" | I, O | Change: a hardware comparison of the stream pointers at the start of the block, illegal if equal | D |
| 13 | The 256-strip bound on a sums block | A hardware bound; the program cuts the work into pieces | P, O | Needs measurement: cost of cutting against resume without a bound | D |
| 14 | Block copy and fill ordering | "A loop in ascending order for one observer", concurrent observers unchanged | S | Change: a small guarantee every implementation keeps, tested | D |
| 15 | The formal model of the kernel subset | A second, hand-written statement of what instructions do | S | Keep, with the model made a checked artefact and a plan to generate one from the other | D |
| 16 | Devices behind a switch | Require ACS, but keep the group rule as the fallback | I | Change: without ACS, refuse to assign unless the kernel overrides by an explicit act | D |
| 17 | The 64-bit literal | `MOVQL` stays five parcels (ten bytes) | S, P | Needs measurement: how often 64-bit constants execute in compiled hot code | D |
| 18 | The entry instruction `GENTER` | Placed in a reserved word because "no pattern moves and the optimiser is not re-run" | S | Keep; the true reason is that it is rare, say that | T |
| 19 | Nested virtualisation | Not in version 1, because it is a smaller design | S | Keep for version 1, with the true reason and the estimate written down | T |
| 20 | Where the text goes, and what runs first | A section in the kernel chapter to avoid renumbering; a small in-house hypervisor first | S | Keep the order of work; judge the design against a Linux-style host too; place the text where readers look | T |
| 21 | Assembler spellings | "Everything of medium effort or less"; present forms win a conflict; the rest skipped | S | Change: reopen the skipped list on readability and on the old assemblers, not on effort | D |
| 22 | Resume of a vector block | Resume in place, by a hidden record, judged by four principles | O, P | Keep with conditions: make the out-of-order rule testable; measure the real interruption cost | D |

## The arguments, one short one for each tainted item

### 1. Stale translations: the arena, and what was put off

*What I recommended and why.* After the benchmarks I recommended the arena (the hypervisor keeps its second-stage tables in one pool; the hardware refuses a walk outside the pool; a store into the pool or a "tables changed" flag throws away the guest's translations at the next entry), flush at every entry when no arena is set, and "no for now" to the directory. The reasons I gave: about 1,300 gates against 8,300 to 16,800 gates per buffer for the directory (3% to 6% of a core, up to twice that for two buffers), and a collapse of the directory when the working set exceeds its slots (19,400 walks of 20,000 requests, measured on a synthetic working set). On stores by other cores and devices I recommended "when the multi-core design is written; until then one core".

*Where it is tainted.* Three places. The gate count decided it, and gate count is the last of the things the principles care about; safety by construction is first. The arena closes the hole only for the hypervisor's second stage and only if the hypervisor puts its tables in the pool; it leaves the kernel's own tables, where the duty to invalidate after an edit is the commonest forgotten duty in operating systems. The owner's own first idea was exactly "hardware that notices stores to page table pages and discards", and he called it the safest design. And "until then one core" is a design that is safe only because there is one core, which the one-binary veto does not allow. The benchmark of the directory used a synthetic working set, not a kernel's.

*Evidence.* The arena is "exactly as good as correct software" in the benchmark (it removes the duty to remember, not the cost of flushing); in 15 of 20 discards of the test the flush was a false alarm, so the arena pays run time for coarseness. Published exit costs are 376 to 1,300 cycles, and the flush at every entry costs about 48 cycles on a small guest.

*Re-judgement.* Needs measurement: the number of table pages a real kernel and a real guest touch (that sets the directory's size and tells whether the cliff is real), and the run time of the invalidate calls a kernel makes today. My leaning, on the ladder: hardware that notices stores to table pages, for the second stage and the first and the kernel's own. A cheaper way to build it, which I have not checked and offer as an idea: the design already has granule colouring (a small tag on each piece of memory, checked by the hardware); a reserved colour for "this page is a translation table" would let a store from an ordinary access discard the matching translations without a separate directory. Other cores and devices must be counted in the design from the start, with the IOMMU never letting a device write a table page. Seriousness A, because it decides whether every kernel keeps the duty.

### 2. The sixteen-byte strip of a block that keeps sums

*What I recommended and why.* So that the program never names the width and one binary gives bit-identical answers on 128 and 256 bits, a block with accumulators runs 16 bytes at a time everywhere. I chose it over a fixed 32-byte tile (which would double the register file of the small machine: 61,578 against 30,869 NAND2 for the registers). I said such blocks are "ranked last" because no compiled kernel makes one.

*Where it is tainted.* "Nothing compiled uses it" is a statement about how rarely the form appears, and the principles say a loop is judged by how often it executes times what it saves. An accumulator block is the matrix multiply micro-kernel, the hottest loop in the language-model inference the owner has named as a goal. The cost is stated in the record: 32 multiply-adds a strip against 64 at 256 bits, that is half the machine's width in the one place it matters. Gates (the reason against the alternative) are the lowest-ranked consideration.

*Evidence.* The record's own cost line; the register file figures above; the compiler's inability to make such blocks is a fact about the compiler, not about the loop.

*Re-judgement.* Needs measurement: run time of the micro-kernel and of dot products on 128-, 256- and 512-bit models with the fixed strip, with a fixed tree order for the final sum that lets the strip vary, and with the 32-byte tile. The aim is a result that does not depend on width without halving the width. The one-binary veto stands; it says the result must not depend on width, not that the width must be the smallest one. Seriousness A (performance of the headline kernel and the shape of the block).

### 3. Removing the tile, the whole-GEMM unit and the gather

*What I recommended and why.* In the survey of vector instructions I recommended removing `gemm.f`, the tile, the gather, the unused lane variants and all but one width word, adding 18 words; the owner said "I accept all your recommendations and leanings". Reasons: static counts of instructions in real assembly (gather 0.0 to 0.3% everywhere but one library, the tile in three architectures used "by linear-algebra libraries only"), "clang vectorizes none", and a silicon estimate falling from about 1.4 to 2.0 million NAND2 to 0.22 to 0.30 million. The 16-entry table lookup replaced the gather.

*Where it is tainted.* A static count of appearances in assembly is not an execution count; a compiler's inability to use a feature is not a verdict on the feature; and the silicon estimate is last in the order. The owner had said that the vector work exists as a "gpu-lite" for inference on machines without a large GPU, and the tile is how Arm, Intel and IBM make that fast. The table lookup handles 16 entries; a 256-entry byte table (a cipher S-box, a character class table, a quantisation table of the larger kind) has no replacement. Old ideas deserve a look: scatter and gather were the heart of the 1970s vector machines.

*Re-judgement.* Needs measurement: tokens per second of a small quantised model, and the run time of a histogram and an embedding lookup, with and without a tile and a gather, on the cycle model. I would not restore them before that; I also would not call the question closed. Seriousness A.

### 4. Full capability pointers

*What I recommended and why.* Reject 128-bit capability pointers, keep a valid-pointer tag per register and per 8-byte word, defer bounds. I gave as the dominant cost "the software": the compiler, the C library, the kernel and every program that stores a pointer in an integer must change. The owner wrote "I accept your recommendation".

*Where it is tainted.* That is effort, and effort is never a reason. The other reasons (memory growth, a changed pointer size) are run-time and ABI costs that can be measured, and the document marks them "from memory, not confirmed". What capabilities give is the top rung of the ladder (bounds and unforgeable pointers by construction), where colouring misses one collision in sixteen.

*Re-judgement.* Needs measurement and a fresh study: published overheads on pointer-heavy code, memory growth with 16-byte pointers against compressed 64-bit forms, the fraction of memory-safety bugs each protection closes, and the effect on the ABI and the single 64-bit profile. Recommendation: reopen; no decision until measured. Seriousness A.

### 5. Software accessed and dirty bits

*What I recommended and why.* Software: a clear accessed bit, or a clear dirty bit on a write, faults, and at the second stage that fault is an exit. The principled reason: the walker never writes memory, so a walk cannot fault on a write, cannot need an atomic read-modify-write, and a speculative walk has no architectural effect. A second reason I gave was that this is how 3BSD paged on the VAX, which the fact-check says I did not verify.

*Where it is tainted.* Prior practice is no reason, and the speed cost (one extra fault the first touch of each page and one more on its first write; at the second stage a full exit of hundreds of cycles) was never measured. Arm and RISC-V both added hardware update for this reason.

*Re-judgement.* Needs measurement: faults per page, and exits per page, on a write-heavy guest. A hardware update that only sets a bit, at retirement, with an atomic OR, has no speculation problem. Keep for stage 1 until measured; for stage 2 I expect hardware set bits to win. Seriousness D.

### 6. Costs of exits that were never measured

*What I recommended and why.* A physical interrupt always exits to the hypervisor whatever the guest's priority (so a guest cannot hold off the timer): sound on safety. The guest's IOMMU unit is virtual and every command and fault is trapped (smallest design). The world switch is left to software ("nothing hidden is saved"). The first guest software is a small in-house hypervisor (months, not years).

*Where it is tainted.* Safety decided each, and I never counted what they cost: a device handed to a guest takes an exit per interrupt; every map and unmap of a buffer takes an exit and a forward. Speed is the second principle and is measured by run time.

*Re-judgement.* Needs measurement: cycles per interrupt for an assigned device, per map and unmap through the trap, and per world switch, on the model that exists. Keep the safety rules; if the cost is high, the answer is a cheaper injection or a hardware ring, not dropping the rule. Seriousness D.

### 7. The hypervisor strap and the widths

*What I recommended and why.* A strap `HVE`; with it clear "the machine is today's machine, no existing program or test changes"; the second-stage address width and number of levels fixed in the text and not discoverable; the hypervisor registers numbered before any feature register exists.

*Where it is tainted.* "No existing test changes" is a reason from prior work. A strap is a way for the same binary to meet two different machines; the veto asks that sizes and features be discoverable at run time.

*Re-judgement.* Change: one read-only feature register stating what is present and how wide (levels, address width, tag width), before software relies on the new parts. Seriousness D.

### 8. Reuse of guest tags

*What I recommended and why.* The guest tag is the hypervisor's to reuse, and the reset sequence of the IOMMU (discard old entries before a tag is reused) is written as "the hypervisor's duty". Reason: the old rule that no new hardware is wanted where a rule will do.

*Where it is tainted.* That rule was on the old list and the ladder reverses it: a duty software can forget is a defect of the hardware.

*Re-judgement.* Change: a hardware generation count kept behind each tag in the processor and in the IOMMU, so a reused tag cannot see old entries; the guest-entry flush decided later already closes the processor's side. Seriousness D.

### 9. Invalidates left untrapped

*What I recommended and why.* `ICINVA`, `TLBSYNC` and unscoped invalidates stay unprivileged and untrapped ("harmless to data; a JIT needs them"); a trap bit is added "only if timing between guests is a concern". The unprivileged `ISYNC` also makes some executors flush everything.

*Where it is tainted.* It is mitigation where construction was one gate away, and it was judged on the old principle that no new hardware is wanted where a rule will do. An unprivileged instruction that can flush the whole translation buffer is a way for one guest to slow another and to read timing.

*Re-judgement.* Change: build the trap bit now, one gate each, set by default for a guest; define `ISYNC` as the instruction-stream fence only. Seriousness D.

### 10. Reserved mode value refused "when used"

*What I recommended and why.* A saved status word with the reserved mode value is refused at the entry or the return and not at the write, because "it matches how the kernel's saved status word is treated, and keeps a world switch from faulting".

*Where it is tainted.* Matching what exists is not a reason. The owner decided the two neighbouring points the other way (refuse a write of a one to an unused bit; refuse a virtual line vector below 32 at once), which is the ladder's reasoning: catch the error where it is made. The worry about a world switch is empty: a saved image only ever holds values that were legal when written.

*Re-judgement.* Change: refuse the write. Seriousness D.

### 11. The user-access window

*What I recommended and why.* The question was whether `UA`, `STUA` and `CLUA` exist, because the manual said so and the grammar did not. I decided, on delegation, that they do ("as the manual says"), citing what x86, Arm and RISC-V have; the owner later accepted keeping `UA` and `.U` in the seL4 form.

*Where it is tainted.* Keeping what the manual already said. An open window is a duty to close it on every error path; the per-access `.U` form closes by construction and the earlier review leaned towards a window that closes itself.

*Re-judgement.* Change: retire the window and its two opcodes (freeing a status bit) once `.U` covers the copy routines. Needs a count: instructions in the copy-in and copy-out routines with the window against `.U`. Seriousness D.

### 12. A store into the stream being read

*What I recommended and why.* In a block with sums, the assembler refuses a store whose pointer register is a load's pointer; the aliasing case "stays unpredictable". This closes the common case of a silent wrong answer (measured: 4 of 8 lanes wrong). Reasoned under "no new hardware where a rule will do".

*Where it is tainted.* Idiom, where hardware construction was possible, and the leftover case is the class that silently gives wrong answers. Comparing the stream pointers at the start of the block costs a handful of gates.

*Re-judgement.* Change: hardware compares the pointer registers at the start of the block and makes equal pointers an illegal instruction; the assembler refusal stays as a courtesy. Seriousness D.

### 13. The 256-strip bound

*What I recommended and why.* A sums block may cover at most 256 strips; a longer region faults before any work and the program cuts it and adds into the result. Cost measured on one case: +0.8% of vector cycles for a 1,024-long micro-kernel, plus setup instructions that were not in that figure.

*Where it is tainted.* One case measured, the instruction cost left out, and the bound was designed when restart was the plan (it limited livelock and lost work). The owner then chose resume, which removes much of that reason. 256 is "an illustration" the owner was to tune.

*Re-judgement.* Needs measurement: a long dot product cut into blocks with the setup instructions counted, against resume without a bound, including the case of a switch to another program. Seriousness D.

### 14. Block copy and fill

*What I recommended and why.* A sentence that for a single observer a block copy is a loop in ascending order with progress in registers, so that seL4 can model it; concurrent observers unchanged ("unordered").

*Where it is tainted.* The reason is convenience of the proof; and an architecture that is silent for concurrent observers is safe only if cores behave alike, against the veto.

*Re-judgement.* Change: a small guarantee that every implementation keeps (what may tear, in what order stores become visible), with a test. Seriousness D.

### 15. The formal model

*What I recommended and why.* Build a model of the kernel subset in the formal language Sail, with the decoder generated from the grammar, and accept that "nothing written by hand twice" bends for the semantics "until the executor can be generated from the model". The owner accepted, noting that rules are directional.

*Where it is tainted.* The reason is effort: the executor cannot be generated yet. The principle says one generated source of truth, so a second hand-written semantics will drift.

*Re-judgement.* Keep, as a checked artefact: run it against the executor on every change, and state the plan to generate one from the other. Seriousness D.

### 16. Devices behind a switch

*What I recommended and why.* Require ACS (the switch sends every request upward through the IOMMU) for assignment; keep the group rule (devices that can talk to each other are assigned together) as the fallback on older boards. The owner added that a switch might need to be a slave IOMMU.

*Where it is tainted.* The fallback is an idiom the kernel must apply every time; the strict option (refuse to assign a device behind a switch without ACS) was listed and given up for convenience.

*Re-judgement.* Change: without ACS, refuse to assign, unless the kernel overrides with an explicit act that is logged. Seriousness D.

### 17. The 64-bit literal

*What I recommended and why.* I pointed out that the manual described `MOVQL` as five parcels, ten bytes; the owner accepted it. The reason was that the manual already said so and that a literal is not counted in the three-parcel rule.

*Where it is tainted.* "The manual already says so" is prior work; I found no measurement of how often a 64-bit constant executes, nor of the fetch cost against a pc-relative load of the constant.

*Re-judgement.* Needs measurement: executed 64-bit constants in compiled kernels and hot loops, fetched bytes, against a 2-parcel load from a literal pool. Seriousness D.

### 18. `GENTER` in a reserved word

*What I recommended and why.* Place `GENTER` by renaming a reserved system word, so "no pattern moves and the optimiser is not re-run".

*Where it is tainted.* Not re-running the optimiser is an effort reason. The conclusion survives on a better ground: `GENTER` executes at world switches, rare against hot loops, so its length does not matter.

*Re-judgement.* Keep; reword the reason. Documentation only.

### 19. Nested virtualisation

*What I recommended and why.* Not in version 1, a guest's use of a hypervisor register exits; reasons "removes a bug class for now; smaller design".

*Where it is tainted.* "Smaller design" is effort. The owner asked for a real estimate and the nested-virtualisation estimate answered: software nesting needs no new gates, hardware nesting 0.2% to 5-10% of a core. Laptops and cloud guests need it.

*Re-judgement.* Keep for version 1 with the estimate as the stated reason, and keep the exit-as-illegal-instruction rule so a later nested hypervisor can be emulated. Documentation only.

### 20. Where the text goes, and what runs first

*What I recommended and why.* Virtualisation went into the kernel chapter because a new chapter would renumber later chapters and their citations; the first guest software is a small in-house hypervisor on the model ("months, not years").

*Where it is tainted.* Both are effort reasons. The hypervisor that runs first shapes the design (it is why "untranslated hypervisor" first looked right, before the VHE-style host replaced it).

*Re-judgement.* Keep the order of work, but test the design against a Linux-style host as well; place the text where readers look. Documentation only.

### 21. Assembler spellings

*What I recommended and why.* The owner accepted "everything you listed as medium effort or less" and to skip the rest, with the rule that where a new spelling would change a present form the present form stays.

*Where it is tainted.* Effort and "keeps what exists" are the two named non-reasons. The skipped list is not in the records; I cannot judge it.

*Re-judgement.* Change: reopen the skipped list and judge each on readability for the old assemblers (principle 6 and the standard at the edges). Seriousness D, in the tools only.

### 22. Resume of a vector block

*What I recommended and why.* Resume in place by a hidden record (680 flip-flops, one-use token, entry and current values of up to four registers), judged "by your four principles in order". It adds about 7,537 gates (2.7% of the vector unit) and measured within 1% to 2% of an uninterrupted run, against restart's 2 to 25 times with faults; the interruption cost of eight cycles was assumed.

*Where it is tainted.* Judged by the old four; the ladder's last rung asks for restart without hidden state and the veto asks that nothing be safe only because a core is in order. The design says an out-of-order core "must not use old sums before the checks pass", which no simulator can test.

*Re-judgement.* Keep with two conditions: make the out-of-order rule testable on a cycle model, and measure the real cost of an interruption. If the rule cannot be made testable it becomes architectural and the decision changes. Seriousness D.

## Accepted recommendations that hold up well

* **The mask on the return from the kernel, with flash clear, no stash, no mask register.** Measured: no instructions, 2,112 gates, 59% to 73% of compiled functions leave a stray register. A residual duty remains (the kernel names what it restored); there is no cheaper hardware that can tell a restore from a computation.
* **The same mask on `GENTER`, and the callee-saved set written into the ABI.** It closes the hypervisor's leftover registers and settles a real disagreement between two compilers.
* **Floating-point flags cleared when the address-space number, the guest register or the table base is written.** Seven gates, no cycles.
* **Flush at every guest entry by default; walker refuses a table outside the arena; the flush bit dropped; a guest never sees a stale translation of a changed table.** The safe thing happens when nobody did anything.
* **The IOMMU rules:** blocked at reset, no bypass, fail closed, reserved bits zero, refusals reported, device interrupts through a per-device table, the RISC-V layout copied where we match, the precise weaker promise for "forget this mapping", the per-core interrupt page.
* **A device may not write system registers or a peer unless the kernel allows it.**
* **The audit's core answers:** `MFCPUID` privileged, the hypervisor mode kept outside the status word, `HALT` always exits, hypercalls as a routed range of `TRAP`, separate exception registers for the hypervisor, probes through both stages.
* **A `VCLR` only inside the block.** No hidden state crosses an exception for it, and it is simplest to verify. (The reason "no code uses the old form" is weak, but the safety reason stands alone.)
* **An interrupt or exit taken at a strip boundary, and a handler may use vector blocks.**
* **The stricter memory type of the two stages wins; the platform map in place of a space bit; invalidate by address-space number; invalidate by guest-physical page as its own mnemonic; the hypervisor level translating as Arm's does; the virtual timer in system registers.** Each follows the best of breed and closes a hole or removes a duty.
* **The check instructions as a family** and **keeping checks out of a proven kernel.** The second needs the boundary written down (what the proof states, what it assumes of the hardware).
* **Linker relaxation by default and a stack aligned to 8.** Smaller code and fewer fetches, argued from the encoding.
* **Registers for exception entry.** Entry cannot fault, so a bad stack cannot become a double fault. A residual risk is that a second exception before the two registers are saved overwrites them; the kernel runs at priority 7 until saved, which is a duty. It is worth a measurement of a two-deep hardware save against the roughly four instructions per entry.
* **The small hypervisor text points:** bit 0 of the virtual lines reads zero, the hypervisor executes everything, the timer's alarm fires once, no virtual line while the hypervisor runs, a fault fetching a trap's vector retries the instruction, the vector table page-aligned, `TRAP` and `TRAPL`.
* **The wake rule of `WFE`, the trap-control defaults (`WFE` and `SEV` trapped), and no user-readable clock until a trap bit exists.** One note on the last: a clock read by an ordinary load from a mapped page costs no system call, so the cost of a system call per time reading, for games and databases, should be measured before the rule is made permanent.

## What I could not check

* **The skipped assembler spellings** (item 21): the list is in the conversation, not in the records.
* **The early security round** (retire-stage items, secure core, random pool, poison and secret-taint leanings): the owner annotated these himself, and I read the CHERI part only; I did not trace the reasons of the others.
* **The reasons behind several older small choices** (error on odd alignment after data, the flag behaviour of rotates and `ASL`, the base of the system-call numbering of the seL4 convention): I found no recorded reason beyond what the documents say, and no sign that effort decided them, but I did not verify them against the compilers.
* **The last sixteen questions of the IOMMU, interrupt and atomics form**, from the sixth on: the file records answers to the first five only, so those are not accepted decisions and I did not judge them.
* **Every figure I quote** is the figure in the review document it came from (gates synthesised, cycles measured on the model, estimates labelled as such); I re-measured none of them, and the working-set benchmark of the directory I take as synthetic as its own author said.
* **The run-time measurements named above** (items 1, 2, 3, 4, 5, 6, 13, 17, 22) do not exist yet; where I lean, I lean on the ladder, not on a number.
* **My idea of a reserved colour for translation-table pages** (item 1) is mine, unchecked against how the colouring hardware is specified.

## Index: each item and its record

| # | Records and documents |
|---|---|
| 1 | R530, errata 207; `docs/encoding-work/bench-holes-1-and-6.md`, `closing-holes-by-construction.md`; R527 / errata 204 (owner's question on a directory) |
| 2 | R477, R480, errata 173, 175; `docs/encoding-work/vec-strip.md` |
| 3 | R474, errata 170; `docs/encoding-work/vec-survey.md`, `vec-silicon.md` |
| 4 | errata 86; `docs/study-round2.md` section 1 |
| 5 | errata 36, R215; `docs/pdp64-system-design.md` D8; R518 decision 12 (errata 195); `best-of-breed-mmu-virt.md` row 4 |
| 6 | R509 decision 1 (errata 186); R510 decision 9 (errata 187); R518 decision 20 (errata 195); form of errata 181 question 9 |
| 7 | R518 decisions 1, 4, 11 (errata 195) |
| 8 | R510 decision 8 (errata 187); R518 decision 19; R501 |
| 9 | R509 decision 7 (errata 186) |
| 10 | R528 point 10 (errata 205) |
| 11 | R513 (errata 190); R522 decision 13 (errata 199); errata 86 |
| 12 | R525 vector decision 3 (errata 202); `best-of-breed-vector.md` |
| 13 | R525 vector decision 2; R527 item 9 (errata 204); `vector-resume-design.md` |
| 14 | R522 decision 9 (errata 199) |
| 15 | R522 decision 5 (errata 199) |
| 16 | winless form "IOMMU, interrupts and atomics: the decisions, in plain words", question 4 (answered; not yet in the register) |
| 17 | R508, errata 185; errata 85 |
| 18 | R518 decisions 14 and 15 (errata 195) |
| 19 | R499 (errata 181); R518 decision 21; R522 decision 8; `nested-virtualization-estimate.md` |
| 20 | R505 (errata 182); form of errata 181 questions 9 and 10 |
| 21 | R424 to R429, errata 139 |
| 22 | R523 (errata 200); R527 item 9 (errata 204); `vector-resume-design.md`; `rejudge-decided-items.md` item 1 |
