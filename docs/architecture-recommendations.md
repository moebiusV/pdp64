# Architecture recommendations from the pain-point research (first pass)

*Written 2026-10-23, while round 6 of the research was running. Proposals only: nothing in the ISA, the spec, the tools or the manual has been changed, and nothing here is decided. Each item is for the author to accept, change or veto; an accepted item becomes an erratum and a decision in Appendix B.*

**Basis.** Chapter 0 and the tables of [`kernel-pain-points.md`](kernel-pain-points.md) (rows cited as "0.x #n" for chapter 0, "A.n row" for the catalogue), [`hardware-vulnerabilities.md`](hardware-vulnerabilities.md) (rules N1-N11, "HV"), [`openbsd-mitigations.md`](openbsd-mitigations.md), and the current manual and [`decisions-pending.md`](decisions-pending.md) (P1-P19, Q1-Q15, R1-R8, S1-S6). **Not yet applied:** round 6 is re-verifying items in those documents; a recommendation that rests on an item the ledger later corrects must be re-read. **What I checked against the manual for this pass:** the opcode-space layout (9.1), the privilege list (6.1.5, 6.1.6), the system-instruction list, the instruction groups in the by-mnemonic dictionary, the pending-decision table. **What I did not re-read:** the full text of each instruction entry, the vector chapter 8, and the simulator and QEMU sources; where a recommendation depends on them it says so.

**Judging rule** (the author's principles, in order): (1) code size, (2) easy recoverability (less recovery code), (3) speed through fewer gates and tighter hot loops; all soft (errata 42). Each item gives its effect on those, whether it breaks ABI v1, and what it touches (assembler `as64`, linker, simulator `sim64`, QEMU target, LLVM back end, manual). Opcode space: 58 of 64 first-page opcodes assigned, one ALU slot spare, five reserved (9.1.6); 45 of 64 second-page slots defined.

**Classes.** ADD (new opcode, mode, bit or register), DROP, CHANGE (semantics or wording), SPEC (a rule the text lacks, no new hardware), LEAVE (a pain point the design already avoids or should keep avoiding, listed so it is not re-argued).

---

## 1. Summary

| # | Class | Recommendation | Pain points | Already pending as | Size / ABI |
|---|---|---|---|---|---|
| 1 | SPEC | Write down an NMI rule (none, or a non-maskable level that cannot be unmasked by `RTI` of an inner frame) | 0.1 #8 | new | no code; no ABI |
| 2 | SPEC | Kernel-stack rule: guard page at the bottom of each stack; stack-overflow exception class | 0.1 #7 | new | none |
| 3 | CHANGE | `WFE` wakes on a pending interrupt even when masked | 0.4 (idle loops) | P1 | none |
| 4 | ADD | `RDTIME` (unprivileged counter read) and a fixed rule that one counter is monotonic and constant-rate | 0.4 #3, #6 | P3 | one instruction; saves a system call per clock read |
| 5 | ADD | Read-only feature and identification system registers (`MFSR` 13+) | 0.3 #3 | P4 | none in the common path |
| 6 | ADD | `TLBIASID` | 0.1 #4 | P5 | one system instruction |
| 7 | SPEC | Consistency fault for MT/device-space mismatch (already proposed) and a rule that device pages are never speculatively read | 0.5 #4, 0.7 | errata 65 (proposed), errata 39 item 7 | none |
| 8 | ADD | `DIT` bit in the `PSW` (data-independent timing) | 0.7 #3 | P17 | one bit; removes need for software constant-time divides |
| 9 | CHANGE | BLT64: reset bit, error status, defined result for queued work, optional start-at-vblank | 0.6 #3, #5 | new | device only |
| 10 | CHANGE | Video device: latch mode and base address together at vblank; underrun status; fixed bus priority | 0.6 #3, #4, #6 | new | device only |
| 11 | SPEC | Bus bridge (2.6.7) must forward the event register, error aborts and enumeration; write the rules | 0.5 #3, #5 | errata 67 | none |
| 12 | SPEC | I/O translation unit before any DMA device is trusted (R6) with descriptors carrying no kernel pointers | 0.5 #1, #2 | R6, N8 | none |
| 13 | CHANGE | Device-space clear-on-free or tagged device memory (GPU/BLT memory reuse) | 0.6 #11 | N9 | device only |
| 14 | SPEC | Atomic instruction operand placement written down; decide whether failing-CAS loops need an ownership hint | 0.2 #2 | N7, 7.12 | none or one hint |
| 15 | SPEC | Out-of-order safety rules, section 3.2: the rules that make today's in-order safeties hold for an out-of-order core | 0.7 | HV C and N rules | text, one `HINT` value, one control bit |
| 15a | ADD | Split translation: `KTBR`, top address bit selects the root, upper half not walked in user mode (section 3.1; the safe form of D6) | 0.1 #1 | D6 reopened | one system register, one TLB tag bit |
| 16 | LEAVE | Sequential consistency (Q5), no register windows, no 32-bit mode, aligned quad accesses, no SMM-like mode, no vsyscall page | 0.1 #11-13, 0.2 #1, 0.3 #2, 0.4 #7 | settled | none |
| 17 | DROP? | Candidates to drop or defer: `MESC` unaligned `MOVU*`, UTF-8 instructions, `MVAL`, `FCLASS32`, `XNORPOP`, `CLMULH/L` | not pain-point driven | none | frees second-page space; see section 4 |

---

## 2. The recommendations, with reasons

### R-1. An NMI rule (SPEC)
**Pain.** x86 NMI nesting: IRET ends the masking, a fault inside the handler re-enables NMIs, a second NMI overwrites the fixed stack (Rostedt, LWN 7 Mar 2012; 0.1 #8). **State of the manual.** Exception entry sets priority 7 (6.2.2); eight levels, no controller (Q4); there is no non-maskable interrupt statement that I found. **Recommendation.** Say in the kernel chapter whether pdp64 has an NMI. If not (my recommendation: none in the first system; the watchdog and debug cases use priority-7 maskable interrupts plus a bus-fault machine check), state that no instruction other than `RTI`/`RTT` lowers priority below the entry level, so nesting cannot arise from a return. If an NMI is wanted later, it must have its own entry state and its own stack. **Cost.** Text only. **Principle.** Recoverability: one less nested-state machine in the kernel.

### R-2. Kernel stack rule (SPEC)
**Pain.** Silent stack overflow; 16 KB stacks; virtually mapped stacks cost about 1.5 µs per `clone()` (0.1 #7; Corbet, LWN 692208). **State.** `R14` is banked per mode (6.1.4); no guard-page or overflow-fault rule. **Recommendation.** Define a stack-overflow abort class: an access that faults on a page marked guard in the page table, delivered on a separate emergency stack (a system register) so the handler can run. The page table already has room for a flag (the exact PTE bit layout is in 6.8.4; I did not check for a spare bit). **Cost.** One system register and one PTE flag, or just text if the kernel builds guards from an invalid PTE and a double-fault stack. **Principle.** Recoverability; code size (kernel needs no stack-depth checks).

### R-3. `WFE` wake rule (CHANGE, P1)
**Pain.** Idle-loop lost wake-ups when priority is 7 on entry and `WFE` waits only for an interrupt that is *taken*. **Recommendation.** As pending in P1: wake when an interrupt is pending even if masked (AArch64/RISC-V `wfi` behaviour). The pain-point research adds nothing against it. **Cost.** None; one rule in the simulator and QEMU.

### R-4. Unprivileged counter (ADD, P3)
**Pain.** The TSC cannot be trusted (Gleixner), a watchdog needs a second counter to trust it (0.4 #3, #6), clock reads through a system call or vDSO cost (Seibold, vDSO). **Recommendation.** Accept P3 (`RDTIME rd`) **together with** an architectural statement that the counter is monotonic, constant-rate and the same on every core; the research is clear that the damage came from counters without that promise. Add the privileged control to trap or disable user reads (for the timing-channel work in P17 and Hertzbleed, 0.7 #3). **Cost.** One instruction (size: saves a call sequence at every use). Does not break ABI v1.

### R-5. Feature registers (ADD, P4)
**Pain.** Errata proliferation and per-chip quirks (0.3 #3: 110 Kconfig errata options, 45 x86 bug flags); the kernel needs a way to identify the chip (P4). **Recommendation.** Accept P4. Add that every optional feature has one read-only bit, and that a *missing* bit means "not present", never "ask the chip another way". **Cost.** None in code size.

### R-6. `TLBIASID` (ADD, P5)
**Pain.** TLB flush cost and shootdowns (0.1 #4). **Recommendation.** Accept P5. It makes context switches cheaper and is one instruction in the system group (which has room, 9.1.4). **Check needed.** The by-opcode dictionary should confirm a free SYS sub-opcode; I did not.

### R-7. Device-space rules (SPEC)
**Pain.** MMIO ordering and speculation into device pages (0.5 #4; HV). **Recommendation.** Keep errata 39 item 7 (no speculative loads from device pages) and write it into the ISA text, which the handoff says is still to be done; keep the consistency fault of errata 65 if the author does not veto it (it turns a mismatch between bit 39 and the memory type into a precise abort instead of silent misbehaviour). **Cost.** Text, one check in the page walker.

### R-8. A `DIT` bit (ADD, P17)
**Pain.** Constant-time code undermined by hardware (0.7 #3); no vendor cost figures for DIT/DOITM were found; BearSSL software constant-time at 0.32 to 0.54 times the speed (round 4). **Recommendation.** Proposal P17 option 3: a core set (add, logic, shift by register, multiply, the memory instructions) always constant-time, and a `DIT` bit in the `PSW` that also forces divide, `mscn`, `mcmp` and floating point to data-independent timing. **Cost.** One `PSW` bit; hardware cost small in an in-order design. **Open.** Whether `PSW` has a free bit and whether `MTPS` from user mode may set it (a user must be able to turn it on for its own cryptographic code; the kernel need not).

### R-9. BLT64 (CHANGE)
**Pain.** GPU hangs and resets with no error path (0.6 #5; `drm-uapi.rst`); tearing and the cost of both ways to synchronise a blit (Packard 2013; 0.6 #3). **Recommendation.** BLT64 (3.1.4) gets: a reset bit; an error status register; a defined result for queued work after a reset or fault (completed, discarded or failed, recorded in the ring entry so the driver can resend it; compare 2.6.6); a timeout; and, optionally, a "start at vblank" flag per command. **Cost.** Device registers only; no ISA change. The register budget is eight (Q10): BLT64's list needs checking.

### R-10. Video device latch and underrun (CHANGE)
**Pain.** Mode and base address must change together (cursor and planes not synchronised until atomic mode setting, Vetter 2015); scan-out FIFO underrun (i915, 2014); EDID and transmitter state (0.6 #3, #4, #6). **Recommendation.** In 3.3 and 3.4: mode and base address latch together at vblank; an underrun status bit and counter; the video master has fixed top priority on the bus; the transmitter's state is owned by the video device and survives suspend (compare the ADV7511 stale hot-plug status, Das, 22 Apr 2026). The 3.3.1 wording "set up once" should be replaced. **Cost.** Device only.

### R-11. Bridge rules (SPEC, errata 67)
**Pain.** Event reporting and errors behind nested buses (0.5 #3, #5); the VAX Unibus adapter's reset path (0.5 #7). **Recommendation.** Resolve 2.6.8: a slot's type says "bus"; a bridge relays events with the path (slot numbers from the root); an abort or machine check from behind a bridge carries the faulting slot path; a departing bridge marks every slot behind it absent at once (2.6.5). **Cost.** Text and device registers.

### R-12. DMA protection (SPEC, R6/N8)
**Pain.** Devices as DMA masters (Thunderclap; 0.5 #2) and devices that cannot reach all memory (0.5 #1). **Recommendation.** Keep R6 open but fix two rules now, because they cost nothing: (a) a descriptor never holds a kernel pointer, only an offset into a region the kernel registered, (b) DMA into device space is refused by the bus (not yet implemented in QEMU). **Cost.** Text.

### R-13. Device-memory reuse (CHANGE, N9)
**Pain.** LeftoverLocals and GPU memory leaks (0.6 #11). **Recommendation.** The video and BLT devices clear a buffer on reassignment, or the bus offers a "clear on release" bit in the slot's mapping. **Cost.** Device only.

### R-14. Atomics (SPEC, N7)
**Pain.** Failing compare-and-swap loops (Marvell, ~25 retries; arm64 lockref thread; 0.2 #2). **State.** Chapter 7.12 defines `CAS`, `LL/SC`, `XADD` and others; the handoff lists operand placement as unspecified. **Recommendation.** First write the operand placement into 7.12. Then consider N7 (a load-for-ownership hint): it is a `HINT` encoding (HINT already exists), so it costs no opcode. **Cost.** Text; one `HINT` value.

### R-15. Keep avoiding (LEAVE)
The research supports keeping: sequential consistency (0.2 #1, Alpha dependent-load barrier, `memory-barriers.txt` 3,016 lines); no register windows (0.1 #12); no 32-bit mode (0.1 #11); aligned quad accesses with a defined fault (0.1 #13); no SMM-like mode (0.3 #2, inferred from the manual's silence); no fixed-address user entry page (0.4 #7); a physically tagged cache requirement (0.1 #6, OPEN in the manual, should be written as an implementation requirement). These are cheap to keep and expensive to retrofit.

---

## 3. Safe for out-of-order cores: decisions that in-order hardware makes safe by accident

**The author's rule (2026-10-23):** "although the first implementations will be in-order, we have to make the decision safe for out of order implementations." So a decision that is safe today only because the core does not speculate is not safe: it must be written in a form that holds for an out-of-order core, while the in-order core stays as cheap as it is. This replaces my earlier suggestion to record the kernel-mapping risk and decide nothing.

### 3.1 Kernel mapped in every user address space (D6): recommended design

**Pain.** Meltdown: user code speculatively reads kernel memory through translations that are present but permission-denied; PTI split the page tables and cost NetBSD 2.7% on a build, LWN "about 5%" and "30% or more" for some loads, and Hansen's global-mapping numbers show the price of flushing without tags (0.1 #1). The Meltdown paper's own suggestion was a hard split of the address space (inferred from the paper as cited in the research; the paper itself was not re-read).

**Recommendation (ADD, ABI-neutral for user code).** Make the split architectural, so no software trick and no trampoline is needed:
1. Two translation roots: `PTBR` (lower half, per process, as now) and a new `KTBR` (upper half, kernel, one per system).
2. The top bit of the virtual address selects the root. In **user mode the upper half is not walked at all**: an access to it takes a translation fault without consulting any page table, so there is nothing present-but-denied for speculation to forward. In **kernel mode both halves are walked**, so `copyin`/`copyout` and the user-access guard (errata 43, `UA`) keep working with no root switch, which is where PTI loses time.
3. Exception entry changes mode in hardware (Q1), so it also changes which halves are walked; the entry code needs no trampoline page mapped in user space. Only the vector table address must be reachable on entry; it lives in the upper half.
4. TLB entries carry the half bit alongside the ASID; a mode change flushes nothing. `TLBIASID` (P5) applies to the lower half; the upper half needs only `TLBIA` or a by-address form.
5. Cost: one system register, a comparison on one address bit, one TLB tag bit. The in-order FPGA pays almost nothing; an out-of-order core gets Meltdown-class isolation for free.

**To check before accepting (not done):** the manual's virtual address layout (39 bits, 6.8.4) and its canonical-address rule; the manual states that canonical virtual addresses cannot name device space (P19, errata 60), so the half selection must be shown to compose with that; the mini-kernel's device leaf at `0xC0000000`; and the effect on the QEMU `mmu.c` walker, `sim64`, the kernel-side ABI notes and any LLVM kernel code model. **Not covered by this change:** Spectre-class leaks inside one half (section 3.2, rules 1 to 4); the same protection for supervisor-to-user direction is the `UA` guard.

### 3.2 Other in-order-only safeties: write the out-of-order rule now

Each row names what in-order hardware gives today, the rule that must be in the ISA text so an out-of-order core cannot break it, and the pain-point source. Mapping is by topic to hardware-vulnerabilities.md rules C1-C16 and N1-N11; I did not re-read each rule for this pass.

| # | Safe today because | Rule to write now | Source |
|---|---|---|---|
| 1 | No speculative execution past a branch | A conforming core may speculate, but **no data from a load whose permission check has not completed may reach a dependent instruction** (Meltdown, Foreshadow, MDS: the pain was that forwarding preceded the check; 0.7 #1) | 0.7 #1, HV |
| 2 | No branch predictor state | **Predictor state is tagged by mode and address space, or cleared by an architectural operation, at a mode change and at `MTASID`**; the architecture defines that operation (a `HINT` value) so a kernel can request it (Spectre v2, Retbleed: 14% to 39% overhead of the software fix, 0.7 #1) | 0.7 #1, HV |
| 3 | No speculative store bypass | An out-of-order core may bypass; the architecture provides a per-process way to forbid it (a `PSW` or system-register bit, or the same bit as `DIT`) and defines that memory-ordering instructions (`FENCE`) stop speculation past them (Spectre v4; 0.7 #1) | 0.7 #1, HV |
| 4 | No indirect-branch speculation target ambiguity | Tag-dispatch and indirect jumps (`JTAG`, `JMPI`, `CALLI`, `BTAG`) must not speculate to a target outside the tagged region (inferred from the research on indirect-branch attacks; this is a pdp64-specific instruction case, so it needs the author) | HV, ISA 9.10 |
| 5 | No speculative load from device pages | Already rule errata 39 item 7: keep it, and state it as **must not**, not "does not" | 0.5 #4 |
| 6 | Sequential consistency by simplicity (Q5) | Keep SC as the architectural model; an out-of-order core implements it with speculation and replay at some cost, and any later weakening is an ABI-version change (Alpha and ARM lessons, 0.2 #1). State this in 7.11 | 0.2 #1 |
| 7 | Accessed and dirty bits managed in software (Q2) | Fine for out-of-order cores: write that a core must not set them speculatively | 0.1 #5 |
| 8 | No data-cache flush by address from user mode (P6 reserved, nothing built) | When built (non-coherent DMA only), make it **privileged**, not user-visible: unprivileged `CLFLUSH` is what made Rowhammer practical (HV 3.5; 0.7 #2). Note `ICINV`/`ICINVA` are user-visible for JITs (6.1.6): they flush instructions only, but must not leak timing; state it | 0.7 #2 |
| 9 | Unprivileged timers absent (P3 not yet built) | `RDTIME` (R-4) gets a privileged **trap/disable control** and a coarse-resolution mode, because high-resolution user timers are the measuring instrument for every cache-timing attack (Hertzbleed; 0.7 #3) | 0.7 #3 |
| 10 | Timing of divide, `mscn`, `mcmp`, floating point is fixed by the in-order pipeline | `DIT` (R-8) defines data-independent timing for these; an out-of-order core must honour it even when it would otherwise early-exit | 0.7 #3 |
| 11 | Faults are precise because everything retires in order | State that exceptions are precise architecturally (they are, 6.8) and that a faulting load's data may not be used by later speculative instructions (same as rule 1) | 6.8 |
| 12 | Page-table walks do not race with stores | Page-table walks may be speculative on an out-of-order core; `ISYNC`/`TLBI` ordering rules (6.3.2) must say the **walker only sees stores that are before the `TLBI`/`ISYNC`**, as already written for `PTBR`; extend to the A/D rule | 6.3.2, 7.5 |

**What this costs the in-order core.** Rule 2 and rule 3 add a `HINT` encoding and a control bit; rules 1, 4 to 7 and 11 to 12 are text; rules 8 to 10 are bits that exist anyway. Section 3.1 adds one register and a tag bit. None adds an instruction to the common path.

**What I could not settle.** Whether an out-of-order core can honestly implement rules 1 and 3 at the clock rates the author expects; the cost figures the sources give are all for x86 and ARM mitigations, not for a design that had them from the start (the research found no measured cost for a clean-sheet design). That is a design-space question for a microarchitect, not something the sources answer.

## 4. Candidates to drop or defer (DROP?)

This section is **not driven by pain points**; the research does not show these instructions hurting anyone. It is here because the author asked for "dropping opcodes or modes" and these are the ones the handoff already lists as unimplemented or doubtful. Judge by principle 1 (code size) and by whether a compiler would ever emit them.

| Instruction(s) | Why a candidate | What the pain-point research says | Recommendation |
|---|---|---|---|
| `MOVU*` (MESC unaligned access) | quad accesses are naturally aligned by design (9.2.11); unaligned `MOVU*` exist for byte-oriented data | alignment faults are a long-run pain (0.1 #13); Alpha shows the cost of no unaligned access, x86 the cost of allowing it everywhere | LEAVE: they are explicit and opt-in |
| `UTF8DEC/ENC/LEN` | not implemented in `common/pdp64exec.c` | nothing | defer (reserve the encodings) unless a compiler/libc use is shown |
| `MVAL` | not implemented | nothing | defer, decide with the block-memory group |
| `FCLASS32` | not implemented | nothing | implement or drop with the rest of the half/single classify group |
| `XNORPOP`, `CLMULH/L` | in BESC | nothing | LEAVE if used by checksums/crypto kernels; otherwise defer |
| `MESC` generally, `ATOM` | listed as not implemented in the executor | atomics: see R-14 | implement; they are needed by the SMP chapter |

I did not measure how often any of these appears in the corpus or in the OpenBSD sources; that needs the compiler corpus (`tools/corpus.py`) and is the right next step before dropping anything.

---

## 5. What to do next

1. The author accepts, changes or vetoes each item. Accepted items go to errata and Appendix B.
2. Implementation, in this order (smallest first, each its own commit): text-only items (R-1, R-2, R-7, R-11, R-12, R-14); `WFE` (R-3); `RDTIME` and feature registers (R-4, R-5); `TLBIASID` (R-6); `DIT` (R-8); device changes (R-9, R-10, R-13) with the graphics chapter; the DROP? list only after a usage measurement.
3. Re-read this document against the round-6 ledger (`codegen-data/kernelpain/verification-ledger.tsv`) when round 6 finishes, and change any item whose basis was corrected.
