# The decisions taken since 2026-11-18, judged again by the approved principles

I read every decision taken since 2026-11-18 (virtualisation, the audit of sensitive instructions, the IOMMU, the hypervisor mode, the vector resume, the security corpus and its holes, the seL4 fit, the benchmarks of the holes) and the documents they rest on. I judged each against the full list as the owner approved it: safety by the ladder (prevent by construction in hardware, prevent by idiom in software, mitigate side effects, minimise the cost of failure and recovery), every hole tested, one binary on every implementation, measure rather than guess, speed as measured run time above fewer instructions, and the rest in order.

Work already done, tests that already exist and effort were never reasons for or against anything below.

Most of the decisions hold up. I found 19 that are in tension, 2 of them serious enough to change the architecture. The short list of the strong passes is after the table of flags, so that the audit is seen to be fair.

## Summary table

Seriousness: **A** would change the architecture; **D** would change a detail; **T** documentation only.

| # | Decision | Principle in tension | Seriousness | Recommendation |
|---|---|---|---|---|
| 1 | A vector block resumes where possible, from a hidden record kept across an exception | the ladder's last rung (restart without hidden state); one binary on every implementation (an out-of-order core's rule is untestable); measure | A | keep, with conditions: make the out-of-order rule testable, measure the real cost of an interruption |
| 2 | `RTI #mask` and `GENTER #mask`: the kernel names the registers to keep; the hardware clears the rest | hardware, not discipline (the mask is still the kernel's duty); measured run time | A | needs measurement: hardware that remembers which registers were written, against the mask; adopt now the rule that a plain `RTI` to a lesser mode is illegal |
| 3 | Timing, caches, speculation and out-of-order behaviour are "not testable here"; confidentiality "adequate" because first cores are in order | all holes tested; one binary on every implementation | D | change: add a second tier of tests that run on a cycle model and on any real core, and say in the architecture what a faster core may not leak |
| 4 | Hypervisor mode, second stage, virtual lines and timer chosen as hardware before any gate or cycle count; the world switch left to software with "no estimate" | measure, do not guess; speed as run time | D | needs measurement: gates of the nested walker, cycles of an exit and a world switch, before the details are fixed |
| 5 | A physical interrupt always exits to the hypervisor, whatever the guest does | speed as run time (cost never measured) | D | needs measurement: cost per interrupt for a device handed to a guest; keep the rule, find the cheaper way to inject |
| 6 | Stage-2 accessed and dirty bits are software: a clear bit is an exit | speed as run time; best of breed (others do it in hardware) | D | needs measurement: exits per page on a write-heavy guest; likely change to hardware set bits |
| 7 | The guest tag is reused by the hypervisor, and the reset sequence in the IOMMU is "the hypervisor's duty"; tag width "at least 16 bits" in one place and 16 in another | hardware, not discipline; one binary (width) | D | change: a hardware generation count behind each tag, so a reused tag cannot see old entries; one fixed width |
| 8 | In version 1 the guest's IOMMU unit is virtual: every command and fault is trapped and forwarded | speed as run time | D | needs measurement: cost of a map and an unmap through the trap; keep for version 1 if small |
| 9 | The arena catches stores into stage-2 tables; whether stores by other cores and devices count is undecided | safety ladder rung 1; all holes tested | D | change: yes, they count; devices may never write arena pages (IOMMU refuses by default); test it |
| 10 | A bus error while reading a stage-2 table: "no device answered" is an invalid entry, "a device answered with an error" is a machine check | one binary on every implementation | D | change: classify by what the platform map says the address is, not by what a bus happens to do |
| 11 | Machine strap `HVE`; address width and number of levels "not discoverable"; hypervisor registers numbered before a feature register exists | one binary on every implementation | D | change: one feature register that says what is present and how wide, before any software relies on the new parts |
| 12 | `ISYNC` is unprivileged and "flushes nothing" in user mode | one binary (an out-of-order core must still synchronise fetch) | D | change the wording: it is the instruction-stream fence in every mode; test the program-generates-code sequence |
| 13 | Block operations (`MCPY`, `MSET`): a loop in ascending order for one observer, "unordered" for concurrent observers | one binary on every implementation | D | change to a small guarantee every implementation must keep (what may tear), or needs measurement of its cost |
| 14 | `ICINVA`, `TLBSYNC` and unscoped invalidates left untrapped, a trap bit "only if timing is a concern" | the ladder (mitigate side effects); hardware, not discipline | D | change: build the trap bit now (one gate each), default set for a guest |
| 15 | `MOVQL` stays five parcels (ten bytes) | frequency-weighted encoding; measure | D | needs measurement: how often 64-bit constants are executed in compiled kernels and hot loops |
| 16 | The flash clear names registers r0 to r31 | all holes tested; hardware, not discipline | D | needs checking: vector registers, floating-point registers and hidden state must be covered or proved clear; one probe for each class |
| 17 | Check instructions are not emitted in the verified kernel | safety ladder; one binary | T | keep; write down the boundary (what the proof states, what it assumes of the hardware) |
| 18 | Counts of leaves and forms in chapter 9 are hand text | one source of truth, generated | T | change: generate them |
| 19 | Text left from decisions since replaced (restart-only in 6.14.9; "hypervisor untranslated in version 1") | one source of truth | T | change: bring the text into step with the decisions that replaced it |

## Decisions that pass strongly

* **The default of the arena: flush at every guest entry when no arena is set.** The safe thing is what happens when nobody did anything, and the fast path has to be asked for. That is prevention by construction, and the benchmark showed the cost of the safe default (a few cycles against hundreds for an exit).
* **`RTI #mask` over a latched mask, and no hardware stash.** The measurement found that a latched mask would leak by timer luck, and the design was chosen against it with numbers (instructions, gates, longest path). It is the method working.
* **Floating-point flags cleared when the address-space number, guest register or table base is written.** Seven gates, no cycles, and a careless kernel cannot leak. It is exactly "hardware, not discipline".
* **IOMMU: no bypass mode, blocked at reset, fail closed on a bad table, a refused write dropped and counted, reserved bits must be zero.** Every hole closes by construction, and the model has a test for each.
* **A device may not write the registers of another device or of the timer by default.** The right owner of the question (the IOMMU) closes it for every device.
* **`GENTER` took a reserved system word, and `UA`, `STUA`, `CLUA` took two more.** No new leaf, no pattern moved, checked against the regenerated tables. Occam, and measured rather than assumed.
* **`ISYNC` unprivileged**, on the evidence of what Arm and RISC-V do, read in their own sources.
* **The corpus rule, with the proof that a probe can fail.** Each passing probe was run against a deliberately broken copy of the model. That is what makes "tested" mean something.
* **With `HVE` clear the machine is exactly today's machine,** and the 20 new registers are checked to be illegal there.
* **The old behaviour was thrown away at once** when the benchmark showed two checks asserted a stale translation. No sunk cost.
* **The 711-gate bound on an accumulator block** was measured, and the earlier estimate of "tens of gates" was corrected in the open.

## The flagged items, one short argument each

### 1. Resume keeps hidden state across an exception

*The decision:* "resume where possible", a hardware record (block address, context tag, one-use token, entry and current values of up to four registers) kept across a fault or an interrupt; the accumulators themselves never move.

*Principle:* the ladder's last rung asks for restart without hidden state. Resume has some. The design makes it safe by construction (the token, the tag, the discard on any other vector instruction, any write of a table base, a switch of guest), and it is faster by a large factor wherever blocks are interrupted: measured warm cost is identical, and a block that restarts under page faults takes two to 25 times longer. So it passes on safety by construction and on measured speed. Two things stay open.

The first is that the design says an out-of-order core "must not use old sums before the checks pass", and calls it "a requirement, not testable in the simulators". Under the veto of one binary on every implementation, nothing may be safe only because a core is in order, and a rule that cannot be tested is a hole waiting for the first fast core. The second is that the cost of an interruption (eight cycles) was assumed, not measured, and the record is one per core, so what happens when a block is interrupted and the context moves to another core, possibly with a different vector width, must be stated (the record must die, never move).

*Seriousness:* it changes the architecture only if the answer to the first point is "cannot be tested". I judge it can be made testable.

*Recommendation:* keep. State the out-of-order rule as an architectural rule (no result of a block's strip is used before its checks pass, whatever the width), put it in the corpus as a probe that runs on the cycle model, and measure the interruption cost on the synthesised unit.

### 2. The kernel names the registers to keep on return

*The decision:* "`RTI #mask` is the only return to a lesser mode, the hardware clearing the registers outside the mask", and the same on `GENTER`.

*Principle:* hardware, not discipline. The owner's words were "i love protecting us from careless kernels". But a kernel that passes a mask of all ones is not protected, and the measurement itself found that 59% to 73% of compiled functions leave at least one register the kernel neither sets nor restores. The mask has to be computed by the kernel or its compiler: that is prevention by idiom, the second rung, where the first rung may be available. Hardware that remembers which registers were written since entry (one bit each) could clear exactly the registers the kernel dirtied and did not restore, with nothing to compute and nothing to forget. The benchmark measured a lazy clear-on-read bit at about 1,150 gates but two levels more on the longest path, and a stash at 18,000 gates and more; it did not measure a written-since-entry vector, which is a different thing and needs its own count of gates, levels and the cost of keeping it right across nested exceptions (it is hidden state again).

Run time also needs care: the decision rests on the instruction count of the return sequence ("0 extra instructions"), which is a proxy, and the cycles came from a surrogate. The cost of the flash clear in a real pipeline, in order and out of order, has not been measured.

*Seriousness:* it would change the architecture (the form of `RTI` and `GENTER`), which is why I want the measurement before the encoding is fixed.

*Recommendation:* needs measurement: gates, levels, cycles and the nesting rule for written-since-entry tracking, against the mask. Adopt at once the one rule that costs nothing: a plain `RTI` to a lesser mode is illegal, so a return cannot silently skip the clear.

### 3. What is not tested, and the reliance on in-order cores

*The decision:* 19 of the 68 holes are marked not applicable (timing, caches, speculation, one core, things not built) and the seL4 fit calls confidentiality "adequate" because "the first implementations have no speculation".

*Principle:* every hole prevented and each tested; one binary on every implementation, where nothing is safe only because a core is in order. "Not applicable because the model has none" is honest, but it means the corpus does not yet test the holes a faster core would create.

*Recommendation:* change. Keep the corpus as it is and add a second tier: probes that run on a cycle-accurate model and on real silicon, for timing, speculation and cache channels, listed as required before a faster core ships. And write down in the architecture what a faster core may not leak (a faulting load yields no data, a discarded strip leaves no trace), so the veto is a rule and not a hope. *Seriousness:* detail.

### 4. Hypervisor hardware chosen before it was measured

*The decision:* hypervisor mode, a second translation stage, seven virtual interrupt lines and a core-local virtual timer, assigned devices through the IOMMU, all as hardware; the world switch left to software, with the design saying "I give no estimate worth giving". The owner chose these against the recommendation to stage them, and the record says "sizes to be measured once the designs exist".

*Principle:* measure, do not guess; speed as run time. The reasoning for hardware is good (protection wins when cheap), but the design itself calls the nested walker "the largest item", and nobody has counted it. The same goes for a world switch that saves about 30 registers and 12 system registers by software, and for exits whose cycle count was never taken (only published figures of other machines were quoted).

*Recommendation:* needs measurement: gates of the nested walker and the tag compare; cycles of an exit and of a world switch on the model, as a count of instructions with an assumed cost, then on the synthesised core. The answer fixes details (a hardware save of a few registers may pay), it does not reverse the decision. *Seriousness:* detail.

### 5. Physical interrupts always exit

*The decision:* "a physical interrupt always exits to the hypervisor, whatever the guest's `PRI`".

*Principle:* speed as run time. The rule is right for safety (the guest can never hold off the hypervisor), but for a device handed to one guest it makes every interrupt of that device cost an exit and an injection, and nothing was measured.

*Recommendation:* needs measurement: cost per interrupt on the test hypervisor, with a timer and a device. Keep the rule; if the cost is large, the remedy is to let the interrupt unit route a device's interrupt straight to a virtual line for that guest, a change that keeps the hypervisor in control. *Seriousness:* detail.

### 6. Stage-2 accessed and dirty bits in software

*The decision:* "software-managed accessed and dirty bits" in stage 2; a clear bit is an exit.

*Principle:* speed as run time, and best of breed (the large machines have moved this to hardware). Every first write to a page by the guest, once dirty tracking is on, becomes an exit of hundreds of cycles.

*Recommendation:* needs measurement: exits per page on a write-heavy guest on the test hypervisor. My expectation, which the measurement should confirm or refuse, is a change to hardware that sets the bit when the entry says so, with the exit kept for the case when it may not. *Seriousness:* detail.

### 7. Reuse of a guest tag, and the reset as a duty

*The decision:* the guest tag is a 16-bit number the hypervisor assigns; "the guest reset sequence ... is the hypervisor's duty"; the seL4 review says "guest tag at least 16 bits", the hypervisor design says 16.

*Principle:* hardware, not discipline: a hypervisor that reuses a tag and forgets to invalidate lets the next guest hit the old guest's entries, in the processor's buffer and in the IOMMU's. Also one binary: "at least" is a width that varies.

*Recommendation:* change. Put a generation count behind each tag in hardware (the owner asked for "a sequential token for each guest"): a reused tag is a new generation, and an entry of an older generation never hits. The width is fixed at 16 bits, the same in the processor and the IOMMU, and the text says so in one place. *Seriousness:* detail.

### 8. The guest's IOMMU unit is virtual and trapped

*The decision:* "in version 1 the guest's unit is virtual and trapped, the hypervisor forwards commands and faults".

*Principle:* speed as run time. For a device that maps and unmaps often (a network card with a map for each packet) a trap on every command may dominate.

*Recommendation:* needs measurement: cost of one map and one unmap through the trap against the cost of the transfer itself. Keep for version 1 if small; the design already leaves room for a later hardware ring. *Seriousness:* detail.

### 9. The arena and the stores it does not see

*The decision:* the arena and its flag close the stale-translation hole; the question of stores by other cores and devices was "asked again, because the answer is ambiguous".

*Principle:* prevent by construction; all holes tested. If a device or another core can store into a stage-2 table and the flag does not see it, the hole is open, and the corpus today has one core and a synchronous bus, so it would never show.

*Recommendation:* change. Stores by other cores and by devices set the flag too, and by default no device may write an arena page (the IOMMU refuses, as it already refuses device pages). Add a probe for each. *Seriousness:* detail.

### 10. The stage-2 table bus error split by what the bus says

*The decision:* "split 19 and 21 by what the bus says": no device answered gives an invalid entry, a device that answered with an error gives a machine check.

*Principle:* one binary on every implementation. What a bus does with an address nobody owns (time out, return an error, return all ones) belongs to the interconnect, so the same program would get a different exit code on two machines.

*Recommendation:* change. The hardware knows from the platform map which ranges are memory and which are devices; classify by that, so the answer depends on the address and not on the fabric. A pointer to nowhere is an invalid entry; a failure of a device that is there is a machine check. *Seriousness:* detail.

### 11. What is present and how wide must be discoverable

*The decision:* `HVE` is "a strap on a chip" that no program can change (an instruction is illegal on one machine and an exit on another); the physical address width and the levels are "not discoverable"; the hypervisor registers take numbers 128 to 147 with no feature register yet.

*Principle:* one binary on every implementation: sizes and widths discoverable at run time or invisible.

*Recommendation:* change. One feature register, before software relies on any of the new parts, that says: hypervisor present, address width, levels, tag width, line count. Software then tests instead of trapping. *Seriousness:* detail (the open item for the widths already exists; this says it must close first).

### 12. User `ISYNC` flushes nothing

*The decision:* `ISYNC` has no privilege check; in user mode it "flushes nothing (it has nothing to publish)".

*Principle:* one binary. On a simple core that is true. On an out-of-order core a program that writes code, invalidates and then executes `ISYNC` needs the fetch stream refetched, so the instruction must do something in every mode.

*Recommendation:* change the wording and the tests: it is the instruction-stream fence in every mode, and a probe runs the write, `ICINV`, `ISYNC`, jump sequence of a program that generates code. *Seriousness:* detail.

### 13. The order inside a block operation

*The decision:* for a single observer a block operation is a loop in ascending order; for concurrent observers the order stays "unordered".

*Principle:* one binary. Two implementations (one with a wide engine) may leave different intermediate states visible to another core or a device. The verified kernel avoids the instructions, but other programs will not.

*Recommendation:* needs measurement: what a guarantee costs (for example each aligned 8-byte unit is written whole and at most once, with no order promised). A guarantee of that size is cheap and every implementation can keep it; "unordered" with no limit is not something a program can be written against. *Seriousness:* detail.

### 14. Timing channels left to a later bit

*The decision:* `ICINV` and `ICINVA` untrapped, "a bit that traps `ICINVA` only if timing between guests is a concern"; the cost of unscoped `TLBIA` and `TLBSYNC` marked unverified.

*Principle:* the ladder (mitigate side effects), hardware, not discipline. A one-gate bit that nobody sets is exactly the discipline the owner wants to avoid, and "if a concern" waits for the attack.

*Recommendation:* change. Build the trap bits now; the hypervisor's default sets them, a guest that owns a core clears them. Measure the cost of one unscoped invalidate on the neighbour. *Seriousness:* detail.

### 15. `MOVQL` is five parcels

*The decision:* "`MOVQL` stays five parcels", ten bytes with a 64-bit constant.

*Principle:* frequency-weighted encoding, measured: executions times savings, with hot loops weighted. The count of patterns it takes (32 of 65,536) is measured; its use is not.

*Recommendation:* needs measurement: in compiled kernels and hot loops, how many `MOVQL` are executed and how often a shorter form (a literal pool load, a two-step build) would have done. If rare in hot loops, keep. *Seriousness:* detail.

### 16. What the flash clear covers

*The decision:* the flash clear removes the kernel's values from the registers outside the mask.

*Principle:* all holes tested; hardware, not discipline. In the documents I read, the measurement and the probes are about r0 to r31, `R14`, `DP` and the floating-point flags. I did not find a statement that the vector registers, the floating-point registers or the hidden vector record are covered by the same return.

*Recommendation:* needs checking, and a probe for each register class that exits with the kernel's value if it survives. If any class is not covered by the clear, cover it. *Seriousness:* detail.

### 17. No check instructions in the verified kernel

*The decision:* "the check instructions are not emitted in the verified kernel": "checks are for what we can't prove".

*Principle:* safety by the ladder, and one binary. It is a sound use of proof, but the proof is of the C source plus a model of the hardware, and the checks cover exactly what the model leaves out (a device that writes where it should not, a faulty memory, an implementation that differs from the model).

*Recommendation:* keep, and write down the boundary: which properties the proof states and what it assumes of the machine, so that "not emitted" is a statement of the proof and not of habit. *Seriousness:* documentation.

### 18. Hand-kept counts in the manual

*The decision:* the counts of forms, leaves and mnemonics in chapter 9 stay hand text; the correction of the day found them wrong and said it "is not met" by the rule that every number is stated once and generated.

*Principle:* one source of truth, generated.

*Recommendation:* change: generate them from the grammar tables, as the other facts now are. *Seriousness:* documentation.

### 19. Text left behind by decisions since replaced

*The decision:* the manual's account of the vector block still says restart from the entry only, and the hypervisor design still says the hypervisor level is untranslated in version 1; both were replaced (resume, and a hypervisor level that translates like the others).

*Principle:* one source of truth: the text is a copy that has drifted.

*Recommendation:* change: bring the text into step with the decisions, and list each replaced decision as replaced where it is read. *Seriousness:* documentation.

## Index: each flagged item and its record

| # | Errata | Decision-register rows | Design documents |
|---|---|---|---|
| 1 | 172, 173, 186 (13), 188, 200, 202, 204 (9) | R500, R509, R511, R523, R525, R527 | vector-resume-design.md |
| 2 | 204 (10), 207 (8) to (12) | R527, R530 | bench-holes-1-and-6.md, bench-rti-mask-reuse.md |
| 3 | 199, 201 | R522, R524 | security-corpus.md, sel4-fit.md |
| 4 | 181 (2 to 5), 195, 196 | R495 to R498, R518, R519 | hypervisor-design.md |
| 5 | 186 (1) | R509 | sensitive-instructions-audit.md |
| 6 | 195 | R518 | hypervisor-design.md |
| 7 | 187 (8), 199 (8) | R510, R522 | iommu-proposals.md, hypervisor-design.md, sel4-fit.md |
| 8 | 187 (9) | R510 | iommu-proposals.md |
| 9 | 203, 204 (12), 207 (1) to (5) | R526, R527, R530 | bench-holes-1-and-6.md |
| 10 | 205, 206 | R528, R529 | hypervisor-design.md |
| 11 | 195, 196 | R518, R519 | hypervisor-design.md, sel4-fit.md |
| 12 | 190, 192 | R513, R515 | sensitive-instructions-audit.md |
| 13 | 199 (9) | R522 | sel4-fit.md |
| 14 | 186 (7) | R509 | sensitive-instructions-audit.md |
| 15 | 185 | R508 | |
| 16 | 204 (10, 11), 207 (10) | R527, R530 | bench-holes-1-and-6.md |
| 17 | 204 (8) | R527 | sel4-fit.md |
| 18 | 193 | R516 | |
| 19 | 188, 193, 195, 200, 204 (2) | R511, R516, R518, R523, R527 | hypervisor-design.md |
