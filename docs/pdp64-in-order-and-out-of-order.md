# In-order and out-of-order: the design point, what it costs and buys, and what out-of-order would need

[← pdp64 index](../README.md)

**Status: written 2026-10-22 at the author's request.** Nothing here is measured on a pdp64 implementation (there is none yet in hardware; the only implementations are the emulators). **Performance figures for other machines are from general
knowledge, were not found in a publication in the fact-check ([`fact-check-2026-10-22.md`](fact-check-2026-10-22.md)), and are marked "(not verified)".** Statements about the pdp64 are from the ISA and the other documents and are cited.

## 1. Was out-of-order ruled out?

Not as an architecture. The documents set a **design point** and say so in several places, and the design point is a small in-order machine:

* ISA §1, the ranked constraints: "1. Low transistor count. A small ASIC or an FPGA soft core, **not a superscalar**."
* ISA §17.5, what is explicitly avoided: "**Speculative execution** — not in the design point; also no Spectre-class channels", and "weak or relaxed memory ordering — nothing to gain without speculation".
* ISA §17.1: sequential consistency is "nearly free on a non-speculative in-order machine"; the table there rates its cost as "high on a speculative out-of-order core".
* The implementation plan: phase 1 is a "non-pipelined core"; the SC claim is made for "this in-order non-speculative core"; pipelining is a listed risk.

So an out-of-order pdp64 is a different microarchitecture of the same ISA, not a different ISA, and the ISA does not forbid it. What the ISA does contain is a set of decisions that are cheap in-order and expensive or awkward out-of-order (§5), and the author may want to
decide now which of them to keep. The terms, once: **in-order** (instructions begin and finish in program order, so the machine waits when one is slow), **superscalar** (several instructions per cycle), **out-of-order** (the hardware finds independent work and runs it ahead of a stalled
instruction, then commits the results in program order), **speculation** (running ahead of a branch or a possible fault before it is known to be right).

## 2. What refusing out-of-order costs in performance

Where the time goes in an in-order machine: it stalls on a load that misses the cache (it cannot start the next independent load, so no overlap of misses), it stalls a cycle or more on a load whose result is used at once, it pays the full branch penalty, and it can issue only what the compiler has put side by
side. An out-of-order core hides much of all four.

**Order of magnitude (general knowledge, not verified: no published figure was found in the fact-check).** On the same ISA and process, a small in-order core reaches roughly 2 to 3 CoreMark per MHz and an out-of-order core of the same ISA (a three-wide BOOM-class core) roughly 5 to 6 or more; on integer code a good out-of-order core commonly delivers **two to four times the
instructions per cycle** of a simple in-order one, and the gap is widest on code that misses the cache often. A factor of two to three in speed per clock is the right order of magnitude for the price of not being out-of-order, with more on memory-bound code. The FPGA plan's first core is also non-pipelined (several cycles per
instruction), a further factor before pipelining.

**What pdp64 specifically adds to the in-order bill, and what it already does about it.**

* **Instruction count matters more in-order.** An out-of-order core can run the independent extra instructions (the 12.9% register-to-register moves) in parallel; an in-order core pays a cycle for each. This is why the author's goal of reducing instruction count is correct for this design point: 334,056 instructions
  against `gcc -Os`'s 282,329 (1.18 times) is a cycle-count loss in-order, not just a code-size matter (docs/codegen-analysis.md and CHANGES-SINCE-R20.md §12).
* **There is no instruction scheduler in the compiler.** pcc does not reorder instructions to hide load-use delay. In-order, a scheduler typically recovers a noticeable share of the stalls (not verified: 5 to 15% on integer code is a recollection of the literature, not a cited figure); out-of-order hardware makes it nearly irrelevant. This is compiler work the design point creates.
* **No delay slots, no exposed pipeline** (ISA §11, the rejected list): the ISA refused MIPS's branch delay slot, so a deeper pipeline later does not change the ISA.
* **Memory operands on most instructions** (the load-op forms) give an in-order core some of what out-of-order overlap gives, since the load is part of the instruction; and the fused compare-and-branch forms remove a flag dependency and an instruction.

## 3. What refusing out-of-order buys

| Area | What the in-order design point gains |
|---|---|
| **Error handling: precise exceptions** | Free. Instructions complete in program order, so when one faults, everything before it has completed and nothing after has started: the abort leaves no state to undo (ISA §7.2). An out-of-order core needs a reorder buffer or checkpoints to recover the same architectural state. |
| **Error handling: no speculative state** | There is no wrong-path execution to squash, no rollback of rename tables, no wrong-path TLB fill, no wrong-path cache pollution. Every one of those is a source of subtle bugs in a speculative core. |
| **Security** | No Spectre or Meltdown class of speculative side channels (ISA §17.1, §17.5). No barrier instruction, retpoline, kernel/user page-table split or mitigation controls are needed. |
| **Memory model** | Sequential consistency is nearly free (ISA §17.1). On an out-of-order core it is expensive: loads run early and must be replayed if another processor writes the line before they commit, which is exactly why weak models exist. Keeping SC saves every program from a permanent tax; weakening it later would be nearly irreversible. |
| **Opcodes** | No speculation barrier, no prefetch or branch-hint instructions, no acquire/release variants, no conditional-move solely to avoid mispredicts, no mitigation mode bits. The ISA reserves none for these. |
| **Silicon** | The plan's whole integer core with MMU, no FPU, is about 7,600 LUTs and the complete core about 16,000 (docs/pdp64-fpga-plan.md §2), of which the control, status-word, exception and undo-buffer logic is about 450 LUTs (the ISA's transistor table puts it at about 5,500 transistors). An out-of-order core of the same ISA adds a rename table and a physical register file with many ports, a reorder buffer, issue queues with wakeup and select, a load/store queue with address matching, branch and return predictors, checkpoints, a wider fetch and decode, and several execution units. Published out-of-order cores of this class are several times to an order of magnitude larger than in-order cores of the same ISA (not verified). |
| **Verification** | Every feature interacts with speculation (page faults, atomics, `FENCE`, self-modifying code, the trace bit); in-order, most of those interactions do not exist. |
| **Power and timing** | No wakeup-and-select loop and no content-addressable queues to limit the clock. |

## 4. What supporting out-of-order would need

**Already compatible.** (1) Precise exceptions at the architectural level map directly onto a reorder buffer: the abort that leaves no effect (ISA §7.2) is what an out-of-order core produces at commit. (2) The floating-point flags are sticky and never trap (ISA §4.10.1), so
they need no precise recovery. (3) Exception entry writes only registers, at commit (System v1), so nothing is in flight to unwind. (4) Page-2 forms are exact abbreviations of page-1 forms: one decode, no special cases. (5) The length of an instruction is in its first two bits, so finding instruction boundaries in a
fetch block is a short chain, much easier than on x86. (6) No delay slots. (7) The page-table walker never writes (System v1, software accessed and dirty bits), so a wrong-path walk has **no architectural effect**: with hardware-set accessed bits, a speculative load of a page the program never touches would set its accessed bit.

**Awkward, and worth deciding now.**

1. **Partial flag updates.** The `N Z V C` flags are written by most arithmetic instructions, and the ISA says a shift or rotate by a count of 0 **changes no flag, not even `C`** (ISA §4.2.1: "a shift count of zero changes no flag"; there are tests for it). A flag that is sometimes written and sometimes left alone forces the
   out-of-order machine to merge the old value into the result (an extra micro-operation or a read of the old flag on every shift), which is a known cost of variable-count shifts on x86 (not verified: the figure of three micro-operations for `SHL r,CL` on Intel could not be confirmed from uops.info or the optimization manual). Making the shift always write the flags, or always not, would remove it at no cost to an in-order core. *This is the one place where an
   in-order convenience would hurt a later out-of-order core, and it is cheap to change now.* The flags themselves need renaming like a register; the fused compare-and-branch forms (`cbCC`) avoid creating the dependency at all.
2. **Memory-operand instructions and read-modify-write** (`add mem,reg`, `addm`, `push`, `pop`, `call`, `ret`, `pushm`/`popm`, `pushx`/`popx`, `mcpy`) split into several micro-operations (load, operate, store); the block operations are progress-restartable (ISA §7.5), which fits micro-operation recovery if progress is written at commit.
3. **Auto-increment modes** change a base register as a side effect of a memory access; the ISA buffers the update until retirement (ISA §7.2), which suits renaming, and the compiler hardly emits them.
4. **Sequential consistency** needs speculative loads with invalidation snooping and replay, or conservative issue. The cost is known and bounded, but it is the largest single piece of memory-system logic and it is not optional once SC is promised.
5. **Atomics** (`CAS`, `LL`/`SC`, the `_DB` forms) must execute non-speculatively at commit; the `LL`/`SC` reservation has to survive speculation correctly. And as ever the atomics on the bus (lock against monitor, the open item in [`pdp64-q64-bus.md`](pdp64-q64-bus.md)) are a separate decision.
6. **Self-modifying code and `ICINV`**: a store to code in flight needs a pipeline flush; the ISA already makes the instruction cache non-coherent, which keeps this to the explicit instruction.
7. **Speculation and security** would need what the ISA now avoids: a **speculation barrier** instruction, probably separate page tables for kernel and user (the machine has one `PTBR`, so the kernel is mapped in every address space), and mitigation controls. Controls such as those on x86 are **mode bits**, which the ISA's rule forbids (ISA §1.1);
   a speculative pdp64 would have to mitigate by design and not by switches.
8. **The trace bit and `RTT`** (single step) force a flush per instruction; the interrupt-priority model takes interrupts at commit.
9. **Prediction.** A call pushes the return address on the stack, which a return-address predictor handles in the usual way; `calli`, `jmpi`, `jtag` and `RTI` are indirect transfers; landing pads (`LPAD`, still open) interact with speculative indirect branches.
10. **A wider fetch of two-byte-aligned variable-length parcels** needs the instruction boundaries of several instructions per cycle; the length-first layout helps, and page 2's one-parcel forms make short instructions common (about 56% of compiled instructions are two bytes), which raises the number of instructions per fetch block that must be found.

**What an out-of-order pdp64 would probably add to the ISA:** a speculation barrier; possibly a conditional select (`csel`), which the compiled-code analysis found size-neutral but which on an out-of-order machine avoids mispredicted branches (the decision on a select was deferred "until there is a speed model", and this is where one comes from); possibly prefetch hints. None is needed
today. Nothing that is in the ISA now would have to be removed except, ideally, the partial flag update of item 1.

## 5. Summary

| | In-order, as designed | Out-of-order |
|---|---|---|
| Speed per clock | baseline | roughly 2 to 4 times (not verified) |
| Area | about 16,000 LUTs in the plan | several times to ten times (not verified) |
| Precise exceptions | free | reorder buffer or checkpoints |
| Memory model | sequential consistency nearly free | SC costly (replay), or weaken it (hard to undo) |
| Speculative side channels | none | present; mitigations; barrier instruction; maybe split page tables |
| Opcodes for speculation or ordering | none needed | a barrier, perhaps a select, prefetch |
| Verification | smaller | much larger |
| Compiler | needs a scheduler to approach its potential | scheduling matters little |
| What to change now to keep the door open | partial flag update of shifts (item 1) | |

**A choice for the author, not made here:** one ISA with two implementations, as ARM and RISC-V do (a small in-order core for the FPGA and embedded targets, a larger out-of-order core if ever wanted), is possible with the ISA as it is; the cost of keeping that door open today is the shift-flag clean-up
and the discipline of not putting mode bits or speculation-visible behaviour into the architecture.

## 6. Sources and caveats

ISA §1, §1.1, §4.2.1, §7.2, §7.5, §11, §17.1, §17.5 ([`pdp64-isa.md`](pdp64-isa.md)); the implementation plan §2 and the phase list ([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)); [`pdp64-system-design.md`](pdp64-system-design.md); [`codegen-analysis.md`](codegen-analysis.md). The figures about other cores and about out-of-order
costs are from general knowledge, not measured, and no publication confirming them was found in the fact-check. One related fact was checked: Arm's own list of cores unaffected by Spectre includes the in-order Cortex-A53, A55, A32, A7 and A5, and lists the out-of-order A15, A57, A72, A73, A75 as affected (Wikipedia, *Spectre (security vulnerability)*), which supports "no speculation, no Spectre-class channel" but note that those in-order cores do predict branches.
