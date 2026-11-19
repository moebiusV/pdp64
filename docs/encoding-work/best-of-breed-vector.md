# The vector block against the best-of-breed designs (hidden state, restart, context switch)

*For the owner to read. Nothing in this document changes the manual, the grammar, the tools, the executor or any test; it was written under errata 198 (R521). Every statement about another architecture is marked **verified** (a short quote, the source, the date read: 2026-11-19) or **unverified**, and unverified statements are kept out of the conclusions. Every statement about the pdp64 cites a manual statement, an erratum, or code (`file:line`). Measurements are labelled **measured** (run here, with the stated simulator model), **counted** (from a repository file, named), or **estimate**. This document supersedes the form on the owner's desktop and takes into account the owner's answer to it (option 1: a `VCLR` names accumulators only inside the block) and the owner's note on hidden state (section 5).*

## 0. Short answer

1. **The hole is real and it is a symptom of one design choice.** The accumulator naming is hidden state that is **not saved, not visible and not derivable from the program text** when it is set by a `VCLR` outside the block. Every best-of-breed design either makes such state architectural (RISC-V vector registers and `vstart`, x86 `XSAVE` and `TILECFG.start_row`, Arm SVE registers) or **zeroes it at a defined boundary and scopes it** (Arm SME streaming mode). The pdp64 chose a third thing: hidden, unsaved, restart from the entry.
2. **The owner's option 1 (naming only inside the block) is the SME answer** and closes the naming hole *by construction*: there is no form left that can be interrupted half-made. I recommend it (decision 1).
3. **Restart from the entry has three more holes that option 1 does not touch, and that I found by reading and by running** (section 3): a block that reads and writes the same stream gives a **silent wrong result** when it restarts (**measured**: 4 of 8 lanes wrong, section 3.2); a long accumulator block can **never finish** if the interrupt period is shorter than the block (livelock) and cold pages make it cost about half the number of pages times its own length (**measured**: 4.0, 16.0 and 64.0 times at 8, 32 and 128 pages, section 5.2); and the executor today avoids both by never taking an interrupt inside a block, so the interrupt latency of such a block is its whole length (1,048,580 model cycles for a 1 MiB int8 dot written with an accumulator).
4. **How much state is there, really? Little: at most 256 bytes.** A block with accumulators has a strip of 16 bytes on every implementation (errata 175), so the state a resume would need is at most 16 accumulators of 16 bytes plus a 16-bit naming mask plus the pointers that are already registers. It does **not** grow with the width of the implementation (section 5.3). This is why a hidden register file is cheap to keep (about 12,300 NAND2 equivalents for a shadow copy, **counted**) and also why resuming saves little: the loss of restart is bounded by the block, and the block can be bounded by the program.
5. **Recommendation: amend, not bold, now** (section 4.7): option 1, plus a **hardware limit on the length of an accumulator block** (so the loss, the latency and the livelock are bounded by construction), plus **one assembler rule against a read-modify-write stream in an accumulator block**. Keep **architectural accumulator state with a dirty flag (RVV style)** as the bold alternative to adopt when the conditions of section 5.5 arise (a larger accumulator, such as a 2D tile of accumulators, or a requirement that interrupts are taken inside long accumulator blocks).
6. **What this reverses:** option 1 changes the form allowed by errata 172 and vec-isa 8.4 ("accumulators named before it"), and makes the clears of errata 186 decision 13 and errata 192 part 4 unnecessary (they may stay as defence). The block limit and the assembler rule add a rule to errata 173 to 175. Resume (the bold alternative) would reverse R500 (restart from the entry) and 6.14.9. Details in section 4 and in the decisions.

## 1. The principles applied (with their citations)

| # | principle | where it is written |
|---|---|---|
| P1 | **Security and safety first**: errors that can never arise, then errors that are easy to detect, then errors that are cheap to recover from; restart and recovery go together; an instruction does what its name says and nothing else. | manual 1.6.1 (errata 83, R323) |
| P2 | **All rules are soft**: a rule gives way when breaking it is worth more than it costs, with the cost written down. | manual 1.6.2 (R242) |
| P3 | **No strange side effects; no multiplied entities; mode bits are visible state by default.** | manual 1.6.3 |
| P4 | **Nothing specified that is safe only because the core does not speculate or reorder**, nor that an out-of-order core could do only at large cost. | manual 1.6.4 (R297) |
| P5 | **Every instruction can be restarted after a fault; exceptions are precise; no hidden instruction state except the vector block's, which restarts from its entry.** | manual 9.2.6; 9.15.1; errata 172 |
| P6 | **"Hidden state is ok if we have precise exceptions and clean restarts."** (the owner, accepted as errata 172) | errata 172; vec-isa 4.1 |
| P7 | **The most work for the fewest instructions, reasonable performance for minimal silicon, above both safety, restartability and precise exceptions.** | R455, R472, in the ledger (`decisions-and-status.md`, section 08 and R455); errata 161 |
| P8 | **The program never names the width; one binary gives bit-identical results and the same faults at 128 and 256 bits.** | errata 173 (R471, R477); vec-isa 8 |
| P9 | **No new hardware where a rule will do** (the cache rule of errata 178 was chosen on this ground); later owner choices of new hardware, such as the hypervisor mode (R495), govern where they were made. | errata 178 (R491); R495 |
| P10 | **Best of breed first, amended minimally so that the hole closes by construction; a bold change where it is a large win overall.** | errata 198 (R521); ledger section 01 |
| P11 | **The PDP-11 and VAX spirit: the VAX's hidden instruction state (the "first part done" bit) is the cautionary case; the pdp64 removes hidden state that made implementation hard.** | manual 1.4 (commentary of 1.4.7), 1.5 |

"C64 in spirit, not the hardware" (ledger section 01) is recorded as to do for the pdp64 and is not used as a ground here.

## 2. The baseline: how the best-of-breed designs solve the same problems

A note on sources. The quotes below are as returned to me by a page-fetching tool that passes pages through a summarising model; they were not read from raw page text, and where the fetch gave a paraphrase I say so. The Intel quotes are from the Intel Software Developer's Manual combined volumes (order number 325462-093US, read by `pdftotext`). The local QEMU source is QEMU 11.1.2 (`../qemu-src`, the files named). Three questions the owner asked that the sources did not settle are in section 2.5 as **unverified**.

### 2.1 RISC-V Vector extension (RVV)

| point | what RVV does | evidence |
|---|---|---|
| vectors are architectural | "The vector extension adds 32 architectural vector registers, `v0`-`v31` to the base scalar RISC-V ISA." | **verified**, RISC-V vector spec (archive: riscv-v-spec, `v-spec.adoc`, "Vector Registers"), read 2026-11-19 |
| the resume index | "All vector instructions are defined to begin execution with the element number given in the `vstart` CSR" and "to reset the `vstart` CSR to zero at the end of execution." | **verified**, same spec, "Vector Start Index CSR vstart", read 2026-11-19 |
| who sets it | "Normally, `vstart` is only written by hardware on a trap on a vector instruction." and execution resumes "at which execution should resume after a resumable trap is handled." | **verified**, current unprivileged spec (v20260120, docs.riscv.org `v-st-ext.html`), read 2026-11-19 |
| partial progress lives in | the architectural `vstart` plus the architectural vector registers and memory the instruction had already written. QEMU: the element loop is `for (i = env->vstart; i < evl; env->vstart = ++i, ...)`, so `vstart` is the progress at every element | QEMU `target/riscv/tcg/vector_helper.c:256`; `vector_internals.h:28-33` (`VSTART_CHECK_EARLY_EXIT`) |
| instructions that cannot resume | "Vector reduction operations raise an illegal-instruction exception if `vstart` is non-zero." QEMU's `viota` comment: "An illegal instruction exception is raised if vstart is non-zero." (a reduction has hidden partial sums: RVV **refuses** to resume it, rather than hide state) | **verified**, current spec; QEMU `tcg/insn_trans/trans_rvv.c.inc:3455` |
| lazy context switch | `mstatus.VS` has Off, Initial, Clean, Dirty: "When the status is Dirty, the corresponding state has potentially been modified since the last context save." and "During a context save, the responsible privileged code need only write out the corresponding state if its status is Dirty." (Off raising illegal-instruction and the return to Clean after a save came back as paraphrase: **unverified as exact text**) | **verified**, privileged spec v20260120 (`machine.html`, "Extension Context Status in mstatus Register"), read 2026-11-19. QEMU: `mark_vs_dirty` ORs the field into `mstatus` on every vector instruction (`tcg/translate.c:718`); states in `cpu.h:146-149` |
| whole-register moves | "These instructions are intended to be used to save and restore vector registers" | **verified**, archive spec, "Vector Load/Store Whole Register Instructions" |
| reduction order | ordered sum "must sum the floating-point values in element order, starting with the scalar in `vs1[0]`"; the unordered sum "provides an implementation more freedom in performing the reduction", but must be deterministic for a given `vtype` and `vl`. (The words "implementation-defined order" were not found: unverified as a phrase.) QEMU implements both through the same macro (`tcg/vector_helper.c:5199-5207`), that is, both in element order | **verified**, both specs |
| first-fault | "If element 0 raises an exception, `vl` is not modified, and the trap is taken." (only element 0 may trap) | **verified**, archive spec, "Unit-stride Fault-Only-First Loads" |
| OS side | the Linux page for the RISC-V vector interface says nothing about lazy save or `sstatus.VS`; only that vector registers are clobbered by system calls | **verified** (the absence), kernel documentation `arch/riscv/vector`, read 2026-11-19; the kernel source was not read: **unverified** |

So RVV: the state is the program's (registers and `vstart`), the trap leaves a resume index, an instruction with hidden partial results (a reduction) is simply not resumable mid-way, and the OS avoids the cost of saving by a dirty flag.

### 2.2 Arm SVE, SVE2 and SME

| point | what Arm does | evidence |
|---|---|---|
| the registers | Z, P and FFR are architectural. The Linux interface: "All other bits of Z0..Z31, and all of P0..P15 and FFR become zero on return from a syscall." (bits [127:0] of Z are preserved like V0..V31) | **verified**, kernel documentation `arch/arm64/sve`, read 2026-11-19 |
| partial progress | no `vstart`: the progress of a first-fault or non-fault load lives in an **architectural predicate, FFR**: "Initialise the first-fault register (FFR) to all true prior to a sequence of first-fault or non-fault loads." (a mirror of Arm's instruction pages, not developer.arm.com); a faulting element clears its FFR bit and all later ones. QEMU: "Fault on byte I. All bits in FFR from I are cleared." | **verified** for the first quote (mirror); QEMU `target/arm/tcg/sve_helper.c:6638`. `WRFFR` of a non-monotonic value is UNPREDICTABLE (mirror, **verified** as quoted) |
| "instructions restart whole" | I found no primary statement of it | **unverified**; kept out of conclusions |
| SME streaming mode | "A new mode, streaming mode, in which a subset of the normal FPSIMD and SVE features are available." | **verified**, kernel documentation `arch/arm64/sme` |
| entering and leaving streaming mode zeroes the vector state | Arm's blog on SME: "all of these registers are set to zero" (the referent is Z0-Z31 and P0-P15). The same is in the **local QEMU source**: a change of `PSTATE.SM` calls `arm_reset_sve_state`, and `PSTATE.ZA` zeroes ZA on enable ("SetPSTATE_ZA zeros on enable and disable") | blog **verified** (secondary); QEMU `target/arm/helper.c:4896-4920` (`aarch64_set_svcr`), `target/arm/tcg/sme_helper.c:42` |
| ZA, the matrix state | "When PSTATE.ZA is changed from 0 to 1 all bits in ZA are cleared." | **verified**, kernel documentation `arch/arm64/sme`, appendix A.1 |
| lazy save of ZA | the software ABI: "Point TPIDR2_EL0 to BLK. At this point ZA becomes dormant."; "TPIDR2_EL0 is null if the call committed the lazy save."; on entry to an exception handler "TPIDR2_EL0 is null" must hold. The fetch found **no hardware trap on a non-null `TPIDR2_EL0`**: dormancy is a software convention of the ABI (so the owner's brief that an access to a dormant ZA traps is **not supported by what I read**) | **verified**, Arm ABI `aapcs64.rst` (first 200,000 characters read), read 2026-11-19 |
| OS side | "On syscall PSTATE.ZA is preserved"; "On syscall PSTATE.SM will be cleared"; what the kernel saves at a context switch is not stated in the pages read | **verified** / **unverified** as marked |

So Arm: SVE state is architectural and not resumable inside an instruction in the way RVV is (progress is an architectural predicate for the loads that need it); SME **scopes** the big state (ZA) in a mode with an explicit enter and exit that zero it, and keeps a **software** lazy-save protocol on top.

### 2.3 x86: AVX-512, AMX, XSAVE

| point | what x86 does | evidence |
|---|---|---|
| state components | "State component 17 is used for the 64-byte TILECFG register" and "State component 18 is used for the 8192 bytes of tile data (TILEDATA state)." QEMU: `XSaveXTILEDATA` is 0x2000 bytes | **verified**, Intel SDM vol. 1 ch. 13.1; QEMU `target/i386/cpu.h:1880-1901` |
| init optimisation | "If XINUSE[i] = 0, state component i is known to be in its initial configuration; otherwise XINUSE[i] = 1." and `XSAVEOPT`, `XSAVEC`, `XSAVES` "avoid writing data for any state component known to be in its initial configuration". Support is optional ("XINUSE[i] is always 1" if not supported). QEMU copies a component only "if the component has non-init state (bit set in XSTATE_BV)" | **verified**, SDM vol. 1 13.6; QEMU `target/i386/xsave_helper.c:372` |
| AMX init state | "AMX state is in its initial configuration if the TILECFG register is zero and all tile data are zero." `TILERELEASE` "sets TILES_CONFIGURED = 0 and initializes (zeroes) TILEDATA." | **verified**, SDM vol. 1 13.6, AMX chapter |
| progress of a tile load or store | "Tile instructions are restartable ... the instructions store information in the TILECFG.start_row register." "TILECFG.start_row indicates the row that should be used for restart". `TMUL` (the multiply) is **not** restartable: "The TMUL instruction set is not sensitive to the TILECFG.start_row value" because it has no memory operand and so no restartable fault | **verified**, SDM AMX chapter 19.1.4. **The multiply-accumulate on the tiles has no resume point: it never faults mid-way** |
| trap on first use | "When XFD is enabled for a state component, any instruction that would access that state component does not execute and instead generates a device-not-available exception (#NM)." The kernel: "The first use of an instruction related to a dynamically enabled feature is trapped by the kernel" and "the handler allocates a larger xstate buffer for the task so the large state can be context switched." | **verified**, SDM vol. 1 13.14; kernel documentation `arch/x86/xstate` (this page does not itself name XFD or #NM) |
| `REP` strings | progress is architectural: "If the interrupt arrives between iterations of a REP-prefixed string instruction, the processor first updates state as follows: RIP is loaded to reference the string instruction; RCX, RSI, and RDI are updated as appropriate to reflect the iterations completed" | **verified**, SDM vol. 3A, interrupt chapter footnote |
| gather | "This instruction can be suspended by an exception if at least one element is already gathered" and the destination and mask are "partially updated; those elements that have been gathered are placed into the destination register and have their mask bits set to zero." The **mask register is the resume state** | **verified**, SDM vol. 2, `VPGATHER` |
| masked loads | "For some instructions with a memory operand, memory faults are suppressed for elements with a mask bit of 0." | **verified**, SDM vol. 1, opmask section |

So x86: every resumable instruction keeps its progress in an **architectural** register (RCX/RSI/RDI, the mask, `TILECFG.start_row`); the one instruction with a large hidden-looking accumulation, the tile multiply, **cannot fault in the middle**; the big state is skipped at a context switch while in its initial state (XINUSE), and the first use of the biggest component traps so that the OS allocates lazily.

### 2.4 What each does about our four questions

| question | RVV | Arm SVE / SME | x86 AVX-512 / AMX |
|---|---|---|---|
| where partial progress lives across a trap | architectural `vstart` and registers | SVE: whole instruction, FFR for first-fault loads (progress is a predicate). SME: ZA is architectural | `RCX/RSI/RDI`, the mask, `TILECFG.start_row`; tile multiply cannot fault midway |
| who saves what at a context switch | the OS, vector registers only if `VS` is Dirty | the OS saves Z/P/FFR; for ZA the ABI has a software lazy save; SMSTART and SMSTOP zero | the OS with `XSAVE`, skipping components in their initial state (`XINUSE`); the tile component is allocated at first use (`XFD`) |
| how a program names or initialises accumulators | there are no named accumulators: an accumulator is an ordinary register; reductions refuse to resume (`vstart` non-zero is illegal) | an accumulator is a Z register or a ZA tile; entering streaming mode and enabling ZA **zero** them | an accumulator is a tile register; `LDTILECFG` and `TILERELEASE` return tiles to the zero state |
| what the OS sees | all of it | all of it (ZA through the ABI and the kernel) | all of it |

### 2.5 What I could not verify

* A primary Arm statement that SVE instructions restart whole (no `vstart`): not found. `LDNF1` semantics from a primary source: not found. Whether `SMSTART` and `SMSTOP` zero the vector registers in the Arm Architecture Reference Manual itself (the pseudocode of `MSR (immediate)`): not read; the evidence is the Arm blog and the QEMU model.
* What the Linux kernels for RISC-V and Arm save at a context switch (source files not read).
* An `mstatus.VS` "Off" paraphrase and the return to Clean after a save are only paraphrase.
* The word "implementation-defined" for the RVV unordered sum was not found as a phrase.

## 3. Our current design against that baseline

The design points, then the table, then the holes found.

### 3.1 The table

| design point | what we do | what the baseline does | deviation | justification by our principles |
|---|---|---|---|---|
| **hidden registers `v0` to `v15`** | not architectural, not saved at a world switch (R435); zero at the start of each strip except accumulators (`pdp64exec_vec.inc:827`; vec-isa 1) | RVV, SVE: architectural; AMX: architectural (XSAVE component 18) | **deviates** | P7 (minimal silicon, no second register file for the OS to save) and P6; sound **only because** nothing but the accumulators survives a strip |
| **naming by `vclr`** (the registers that keep their values from strip to strip) | the naming is a 16-bit mask `C->vacc` (`pdp64exec.h:47`) set by `VCLR` (`pdp64exec_vec.inc:580-581`); a `VCLR` may be outside the block | no equivalent: RVV and SVE have no named accumulators; SME zeroes and scopes | **deviates; no justification** (the form has no benefit that a `VCLR` inside the block lacks; the only kernel uses it inside, `k_sgemm_nt.ukr.s:19`) | none |
| **restart from the entry** | an interrupted hidden block restarts from its entry with the naming restored from a hidden copy (`pdp64exec_vec.inc:817-821`, `925-934`); registers restored from the snapshot (`pdp64exec.c:952-958`), accumulators zeroed (`pdp64exec.c:946-950`) | RVV, x86 `REP`, gather, `AMX` loads: **resume** from an architectural index | **deviates** | P6 and P7 (no `vstart` register, no save area). It satisfies P5 only for idempotent blocks (3.2) |
| **strip invisibility** | one binary gives the same results and faults at 16, 32, 64 bytes (errata 173; vec-isa 8) | RVV makes `vl` visible and the program names the width through `vset{i}vl{i}`; SVE has a vector-length-agnostic style with visible `VL`. (Both from general knowledge of the specs, **unverified here**; the quotes of 2.1 cover `vl` as architectural.) | **deviates, deliberately** | P8 |
| **the 16-byte strip of a block with accumulators** | a block that names accumulators or holds a `vfmab` has a strip of exactly 16 bytes (errata 175; `pdp64exec_vec.inc:936-940`) | no equivalent (RVV reductions are not resumable; SME tile is a visible size) | **deviates**; it is what makes the accumulator state small and the program's own | P8 and P7 |
| **`vfin` and the epilogue** | one more strip after the last, atomic, a fault in it restarts the whole block (errata 175; `pdp64exec_vec.inc:991-1001`) | x86 tile multiply is atomic (no memory operand); AMX stores are resumable | **deviates mildly**: the epilogue touches memory (it loads C) and a fault there repeats the whole block (3.3) | P5 weakly |
| **the clear at exception entry and return** | `C->vacc = 0` at every entry and at `RTI`/`RTT` (`pdp64exec.c:418`, `435`, `616`; errata 192 part 4) | SME: **zero at a defined mode boundary**, not at an arbitrary interrupt; Linux: Z/P become zero on a syscall return | **deviates**: it clears at an *arbitrary* point (an interrupt between `VCLR` and `VEC`) | P1 requires it not to be silent; the clear is the right idea at the wrong boundary (3.1.1 below) |
| **the world-switch clear** | `hexit` clears the naming (`pdp64exec.c:364`) and any `LL` reservation (none exists yet) (errata 186, decision 13) | SME zero; XSAVE saves | consistent with the baseline's *zeroing* branch, but the hidden copy `vrun_*`/`vrst_*` is **not cleared** (3.5) | P1 |
| **the hypervisor mode (errata 195, 196)** | a physical interrupt always exits (errata 186 decision 1); vector state is the guest's but unsaved; a world switch clears naming | AMX under virtualisation: XSAVE per guest; RVV: `VS` per VS-mode | **gap**: the hidden copy is a file-level static, not per core and not per guest (3.5) | P1, P5 |
| **interrupt in a block** | none is taken: "the block runs whole" (`pdp64exec_vec.inc:4`) | RVV, x86: taken between elements/iterations, resume | **deviates, and the hardware cannot copy it**: a real core must either defer (latency = the block) or restart (livelock) | P1 (a bounded latency is a safety property), P4 |
| **canonical sum order** | chunks of 16 bytes chained through the register (errata 174; vec-isa 8.5) | RVV: ordered (element order) or unordered (implementation, deterministic per `vl`) | **deviates**: a third order | P8; costs no silicon (**counted**, vec-isa 8.5 table: 9,416 / 18,466 / 36,750 NAND2 at 128 / 256 / 512 bits) |
| **2D block** | all state in registers, restarts at the faulting strip of the faulting row; no accumulators (errata 176) | AMX tile loads: `start_row`; RVV: none | no deviation: this is the baseline's style (progress in the program's registers) | P5 |

#### 3.1.1 Why the clear is at the wrong boundary

SME zeroes at `SMSTART`/`SMSTOP`, instructions the program executes. We clear at an interrupt, which the program did not choose. An interrupt between `VCLR` and `VEC` is a boundary no program can see or avoid, so the clear turns a correct program into a wrong one without a word.

### 3.2 Hole A: the accumulator naming across an exception (the open question)

*What happens.* `VCLR v0,#8` sets the mask. An interrupt is taken before `VEC`; `enter()` clears the mask (`pdp64exec.c:418`); the handler returns; `VEC` runs with an empty mask: the registers are ordinary, zeroed at each strip start (`pdp64exec_vec.inc:827`), and the strip is the implementation's, not 16 bytes (`pdp64exec_vec.inc:936-940`). No fault, no flag, a wrong result. Shown by `tests/sim/vec-clear.S` check 2 (errata 192 found (a)).

*Cause in the design.* The naming is **state that lives between two instructions and is neither architectural nor re-derivable**. (Errata 172 first found the opposite problem, a naming that was never cleared, and fixed it by a hidden copy; decision 13 then fixed the leak by clearing; each patch moved the hole.)

*How the baseline closes it by construction.* SME: the zeroed state exists only inside a mode that the program enters and leaves explicitly. RVV: there is no named state at all. Either way **no state exists between two ordinary instructions that an interrupt could lose.**

### 3.3 Hole B: restart from the entry repeats stores of strips already committed (a block that reads and writes the same stream)

*Measured here (scratch program, listing in Appendix A.1, simulator `sim64 -K -x`, which makes the first access to each page fault once):* the block `vclr.l v4,#1; vld.l v0,0(r1); vadd.l v1,v0,#1; vadd.l v4,v4,v1; vst.l v1,(r1)+` over 32 bytes of zeros across a page boundary should leave every lane 1. Without the `vclr` (a non-hidden block) it did (0 lanes wrong). **With the `vclr` (a hidden block) 4 of 8 lanes were 2**: the first strip stored, the second strip faulted, the block restarted from its entry and added 1 to the first strip again, **silently**. (**Measured**: exit status 4.)

*This is the case errata 172 itself named*: "Restarting from the entry is wrong for any block that writes memory it also reads (`a[i] += 1`: the strips before the fault are done twice)". Errata 172 then made the rule that only accumulator blocks restart from the entry, but never excluded an accumulator block that updates memory in place; the manual's "bounded if the program bounds the block" (vec-isa 4.1) is about cost, not about this. The tests do not cover it: `tests/sim/gen_vec_restart.py` has an in-place kernel (`kern('in place: a[i] += 1', ..., inplace=True)`, line 397) that is **not** hidden, and hidden kernels that store only to separate destinations.

*Cause.* Restart from the entry is correct only for **idempotent** blocks, and the architecture (vec-isa 1: "a store and a load of the same element mean read, then write") explicitly allows non-idempotent ones.

*Baseline.* RVV, `REP`, gather and `TILELOAD` **resume**: nothing already done is done again, so idempotence is not needed. The one x86 operation with hidden accumulation, the tile multiply, has **no memory operand and cannot fault midway**.

### 3.4 Hole C: unbounded loss, livelock and latency of a hidden block

*Facts.* A hidden block restarts from its entry on every exception (`pdp64exec.c:946-950`, `pdp64exec_vec.inc:950`) and is run whole in the executor (`pdp64exec_vec.inc:4`). So on real hardware that takes an interrupt inside a block: if the block is longer than the interval between interrupts it **never completes** (section 5.2 table); and a page fault inside it costs the whole run so far; a fault in the **epilogue** (which loads C) repeats the whole block (the last access of the block is the first to find a cold C page: the micro-kernel at K = 1024 over cold pages was **measured** at 7 times its warm length, section 5.2).

*Cause.* The loss is proportional to the length of the block, and **nothing bounds the length of a block**: vec-isa 4.2 ("the most strips of one block") is still open.

*Baseline.* Resuming designs lose nothing; x86 `REP MOVS` and gather lose at most one element or one iteration.

### 3.5 Hole D: the hidden copy is a global and the clear misses it

`vrun_pc`, `vrst_pc`, `vrun_acc`, `vrst_acc`, `vrun_valid`, `vrst_valid` are file-level statics (`pdp64exec_vec.inc:819-821`), not part of the per-core structure and not cleared by `enter()`, `RTI` or `hexit` (decision 13 clears `C->vacc` only: `pdp64exec.c:364`, `418`, `616`). A restart is recognised **by the address of the `vec`** (`vrst_pc == start`, `pdp64exec_vec.inc:930`), not by the context: so a block aborted in one process (or one guest, or on one core of a multi-core build, where the static is shared) leaves a record that the next `vec` **at the same virtual address in another context** takes as its own restart and applies the old naming and zeroing. With shared library code at the same address (the ordinary case) the record is plausibly the same code's own; but it is not *derived from* the running context, and with the clear-at-entry it can differ from what a `VCLR` before this `VEC` made. This was found **by reading; not run** (the executor has one core and no second context in the vector tests: `hv-switch.S` exercises the naming clear, not a stale record). Marked as a hole of kind "state not scoped to a context" (P1).

### 3.6 Smaller findings

* **Interaction of the clear and the restart.** The restart restores the naming from `vrst_acc` and zeroes the accumulators (`pdp64exec_vec.inc:930-935`), so a *faulting* block survives the clear; an *interrupted-before-the-vec* block does not (hole A). The two mechanisms (the hidden copy and the clear) exist to undo each other.
* **`vfin` with an empty accumulator set** makes a block an accumulator block (`pdp64exec_vec.inc:936`); harmless.
* **The `vec2` refusal** is a `die()` (`pdp64exec_vec.inc:920`): an accumulator named before a 2D block aborts the program rather than raising a precise exception: **by reading**; a `die` is a simulator abort, whether it surfaces as an exception on every host is unverified (the audit made the same remark, `sensitive-instructions-audit.md` section 8).

## 4. The proposals

### 4.1 Amendment 1: the naming exists only inside the block (the owner's option 1)

*Change of semantics:* `VCLR` is legal only between `VEC` and `VEND`; elsewhere it is an illegal-instruction exception in the machine and a refusal in the assembler. Naming is then *derived from the block's own text* every time the block starts or restarts; there is no state between instructions and no hidden copy to keep.

*How it closes the hole by construction:* the form that could be interrupted half-made does not exist; the baseline analogue is SME (state only inside a mode the program brackets) and RVV (no such state).

*What changes (**estimate** of effort, small):* executor: remove the "named before" path (`hidden = C->vacc != 0`, `pdp64exec_vec.inc:936`), the `vrun_acc`/`vrst_acc` naming copy (the restart then recomputes the naming from the body; the address-keyed record `vrst_pc` is no longer needed at all, which also closes hole D), the `vec2: accumulators are named before` check (`:920`), and make `VCLR` outside a block raise illegal-instruction (`:580`); the clears at entry, return and world switch (`pdp64exec.c:364`, `418`, `435`, `616`) become redundant defence and may stay or go. `as64`: refuse `VCLR` outside a block (a new check next to `vec_typecheck`); the grammar is unchanged. LLVM tables: unchanged (the pass emits no accumulators). Tests: `vec-clear.S` becomes "a `VCLR` outside a block is illegal"; `gen_vec_restart.py` loses the kernel "hidden: vclr before the block" (line 399) and clob 4; `hv-switch.S` and `gen_hv.py` tests of the naming clear across a world switch (lines 333, 349, 359 and 304-312) are rewritten to test the same property by the new rule; `tests/asm-err` gets the refusal. Manual: vec-isa 4.1, 8.4 ("or `vclr` named registers before it"), 6.14.9 (one clause), 9.2.6. Hand kernels: **none** (the micro-kernel's `vclr` is inside, `k_sgemm_nt.ukr.s:19`). QEMU copy: the shared executor. Silicon: **less** (no hidden naming copy), no new hardware.

*Reverses:* the allowance of errata 172 and vec-isa 8.4 for naming before the block; makes errata 186 decision 13 and errata 192 part 4 vestigial (not wrong). Put as decision 1.

### 4.2 Amendment 2: bound the accumulator block by construction

*Change:* a block with accumulators may cover at most NMAX strips of its first stream; if `(Re - Rs)` is longer, `VEC` raises an exception **before any work** (precise, nothing done; the same kind of check as the alignment check of a strip). The program cuts a longer region into several blocks; the micro-kernel already adds its result to C in the epilogue, so cutting K is free in semantics (the sum order is then the program's own, which is the point of errata 173).

*Closes by construction:* the loss of a restart, the interrupt latency of the block and the livelock are all bounded by NMAX strips; no accumulator block can be so long that an ordinary tick never lets it finish; the page-fault cost is bounded to the pages of NMAX strips.

*Cost.* **Measured:** the micro-kernel costs 27 + 10 K model cycles (K = 64: 667; 256: 2,587; 1,024: 10,267; 4,096: 40,987). Cutting K = 1,024 into four blocks of 256 costs 4 x 2,587 = 10,348 against 10,267: **+0.8%** in vector cycles, plus 3 more calls of 11 setup instructions (scalar, **not** in that figure). **Estimate:** a compare of the region length with a constant at `VEC` (tens of gates), one new cause or reuse of the illegal-instruction exception. NMAX = 256 strips (4 KiB of the first stream at the 16-byte strip) is an **illustration** that the owner may change: with it the longest accumulator block is about 2.6 thousand cycles (10 K, K = 256), 2.6% of a 1 kHz tick at 100 MHz (section 5.2).

*What changes:* executor (the check at `vec`, `pdp64exec_vec.inc:936`), as64 (nothing, unless the count is a constant), manual (vec-isa 4.2 stops being open; 8.4), tests (a block of NMAX + 1 strips faults; one of NMAX runs), micro-kernel call sites (a loop of blocks in the caller). *Does not reverse any decision*; it closes the open item of vec-isa 4.2. Decision 2.

### 4.3 Amendment 3: an accumulator block may not read and write the same stream

*Change:* in a block with accumulators (a `vclr`, a `vfin` or a `vfmab`), `as64` refuses a store whose pointer register is the pointer register of a load. This makes the common case of hole B impossible to write. Aliasing through two different registers is the existing "overlapping streams are unpredictable" class (vec-isa 8.8), which the language rule cannot catch; the residual hole stays and is the same as today's for overlaps.

*Cost:* a check in `vec_typecheck`; **tests** (an asm-err test; `tests/sim/gen_vec_restart.py` adds a hidden in-place kernel that must be refused); manual (one sentence in 8.4). *Does not reverse a decision* (errata 175 said "nothing to refuse"; this adds one thing to refuse). The residual aliasing hole is removed only by resume (4.5). Decision 3.

### 4.4 Amendment 4: scope the hidden copy to the context

Under amendment 1 the address-keyed record is deleted (hole D closes). If amendment 1 is not taken, the record must at least be part of the per-core state and cleared at a world switch and a context switch: **estimate** small, in `pdp64exec.h` and `pdp64exec.c`.

### 4.5 Bold alternative A: architectural accumulator state with a dirty flag (RVV style), and resume

*What it is.* The 16 accumulators (16 bytes each), their 16-bit naming mask, and a status field (Off / Initial / Clean / Dirty, as `mstatus.VS`: **verified** in 2.1) become architectural: an exception inside an accumulator block saves nothing in a hidden place; the block's pointers are committed per strip (as for non-hidden blocks today, `C->progress = !hidden`) and the accumulators are **kept** (not zeroed, `pdp64exec.c:946-950` removed), and `RTI` resumes at the strip. The kernel saves them at a context switch only if the status is Dirty; two new instructions (or a system-register window) move the 256 bytes. `vfin`'s epilogue stays atomic.

*Win.* No re-execution: hole B closes by construction (nothing committed is repeated), hole C closes (the loss of an interrupt is at most one strip), the block need not be bounded, hole A and D close (the naming is saved with the context). It is the **best-of-breed** answer (RVV, x86 `start_row`, gather masks).

*Cost.* **Counted:** the state is 16 x 16 B = 256 B plus a 16-bit mask (section 5.3); at 8 bytes a cycle, 32 cycles to save and 32 to restore, only when Dirty (section 5.3 for the figures). **Estimate:** a shadow copy for a handler that uses vector code of its own costs about 12,300 NAND2 (2,048 flip-flops at 6, **counted** by the repository's rule, `vec-silicon.md` section 1) without the muxes. New architecture: a status field (in the PSW, which exists and is saved anyway: P3), the two instructions, the `VS` rules for a hypervisor (a guest's accumulators are the guest's), OS code, tests. It **reverses** R500 (restart from the entry), errata 172 and 173's "hidden state restarts clean", and 6.14.9, and contradicts P9 unless the owner takes it as a new decision like R495.

### 4.6 Bold alternative B: SME-style explicit state, "the block is the streaming mode"

*What it is.* State a block's accumulators exist only for the block (this is amendment 1 stated as the rule), **and** the hardware zeroes the accumulators at `VEC` and at `VEND` (as SME zeroes at `SMSTART` and `SMSTOP`), and an exception inside the block discards the block's accumulators and restarts from the entry — which is today's R500 — **but only for blocks that satisfy the idempotence rule** (amendments 2 and 3). It is amendments 1 to 3 seen as one design, and it is the cheapest: no state is saved, none is visible, none can be in the wrong place. Its price is that long accumulations are cut by the program (4.2), as an x86 program already cuts a large GEMM into tile-sized multiplies that do not fault midway.

### 4.7 Recommendation

**Amend (1 + 2 + 3 + 4 together), which is alternative B.** It closes by construction hole A, hole D, the livelock and latency of hole C; closes the common case of hole B and leaves the aliasing case in the class the manual already calls unpredictable; costs less silicon than today, no new hardware (P9), no change to the 16-byte strip or the canonical sum. **Adopt alternative A (resume with a dirty flag)** when one of the conditions of section 5.5 arises. If the owner prefers to follow the baseline exactly now, A is the answer, at the cost listed.

## 5. Hidden state across an exception: when it is safe, what resuming saves, what it costs

*The owner's questions:* "this rule of no hidden state crosses an exception... are there cases where it is safe if it does? if something has a lot of state, wouldn't resume give a real savings? bench this. hidden register files etc, what is their cost?"

### 5.1 (a) When is it safe for state to survive an exception?

State that survives an exception is safe when **all four** hold:

1. **No observation.** It cannot be read or influence a result except through architectural state.
2. **Rebuildable.** It is determined by architectural state plus a progress count, so the hardware could rebuild it, **or** it is only a cache that can be dropped at any instant without changing any result.
3. **Contexted.** It is saved and restored with the context, so it never crosses to **another** context (another process, another guest, another core).
4. **Nest-proof.** A nested exception, or a world switch, cannot make it leak or be lost silently.

The baseline cases (all **verified** in section 2): RVV `vstart` is architectural and is the progress count; x86 `REP` keeps progress in `RCX/RSI/RDI` (architectural); a gather keeps it in the mask register; an AMX tile load in `TILECFG.start_row`; an SVE first-fault load in FFR; a reduction in RVV refuses to resume so it **has no surviving hidden state at all**; ZA in SME is architectural and its lazy save is a software convention (a hidden copy is not used); AMX tile data is a XSAVE component. In every case the state that survives is architectural or does not survive.

For **our** block:

| hidden item | safe across an exception? | why |
|---|---|---|
| registers other than accumulators | **yes, trivially**: zero at the start of each strip (`pdp64exec_vec.inc:827`), so nothing crosses a strip, let alone an exception | rule 1, 2 |
| the pointers and reduction registers | **yes**: ordinary registers (vec-isa 4.4, 8.6) | architectural |
| the strip width | **yes**: invisible (errata 173) | rule 1 |
| a hidden copy that is **only a cache** of what the program text implies (the naming derived from the body) | **yes** (amendment 1): droppable at any time with the same result | rule 2 |
| the accumulator **values** of a block in flight | **safe if saved with the context** (rule 3) and resumed from a strip boundary; **today they are discarded and the block repeats**, which is safe only for idempotent blocks (hole B) | rules 2, 3 |
| the accumulator **naming set outside the block** | **not safe**: it changes how the *next* block behaves, is not derivable from any program text at the point of the interrupt, and is cleared or kept by a rule the program cannot see (hole A) | rules 1, 2 |
| the address-keyed hidden record | **not safe** as it stands: it is not scoped to a context (hole D) | rule 3 |

### 5.2 (b) Benchmark: restart from the entry against resume

**What is measured, plainly.** All cycle figures are `sim64 -V` model 1 (a strip costs the larger of the instructions it issues and the time its loads and stores hold a 16-byte port, plus 1 for commit; `docs/sim64.md`, the `-V` section) at the default port of 16 bytes a cycle. They are **model cycles of the vector unit only**; scalar set-up is not included. Clock rates are **assumptions** taken from the repository's own range (`vec-latency.md` section 2: an FPGA at 100 MHz, an ASIC-ish at 1 to 2 GHz; I use 100 MHz and 1 GHz). Tick rates are 100 Hz, 1 kHz, 10 kHz as the owner asked. **The executor never takes an interrupt inside a block, so the tick losses below are computed from the measured block lengths by formula; the page-fault losses are measured** (the simulator counts the strips a restarted block runs again). Programs: Appendix A.

**Block lengths (measured, model cycles).**

| block | accumulators? | size | cycles |
|---|---|---|---|
| GEMM micro-kernel (the repository's `k_sgemm_nt.ukr.s`, K steps, 8 x 4 tile) | yes (`vclr`, `vfmab`) | K = 64 / 256 / 1,024 / 4,096 | 667 / 2,587 / 10,267 / 40,987 (= 27 + 10 K) |
| float dot, `vmul.f` + `vacc.f` (no accumulator) | no | 1,024 / 16,384 / 262,144 elements | 769 / 12,289 / 196,609 |
| the same dot with a `vclr` accumulator and `vfin` | yes | the same | 1,028 / 16,388 / 262,148 |
| int8 dot, `k_q8dot` (`vdacc.b`) | no | 4,096 / 65,536 / 1,048,576 bytes | 641 / 10,241 / 163,841 |
| the same with a `vdot.b` accumulator | yes | the same | 4,100 / 65,540 / 1,048,580 |
| 2D block, `k_avg.vec2d.s` | **cannot** (a 2D block refuses accumulators) | 16 x 16 / 64 x 64 / 256 x 256 | 100 / 964 / 14,596 |
| a long reduction: the float dot above (`vacc.f`) | no | as above | as above |

Note how the accumulator form is **slower** than the non-accumulator form (16 bytes a strip against 32: 1,028 against 769, and 4,100 against 641 for int8): the 16-byte rule costs speed, and only the blocks that name accumulators lose; the compiler emits none (`llvm/vector-usage.md`, via vec-isa 2: the micro-kernel is the only hand-written user).

**Blocks without accumulators lose nothing on a restart**: they restart at the strip (`C->progress`, `pdp64exec_vec.inc:950`). **Measured** with the first access to each page faulting once, over 8 cold pages: the float dot (no accumulator) 3,081 cycles against 3,073 warm (+8, one commit for each fault: no work repeated); at 16,384 elements 12,321 against 12,289 warm (+32).

**Loss of restart from the entry on page faults (measured).** Every page's first access faults once, the handler returns:

| block | pages touched | warm cycles | cycles with the faults | ratio |
|---|---|---|---|---|
| micro-kernel K = 64 | about 3 | 667 | 1,311 | 1.97 |
| micro-kernel K = 256 | about 4 | 2,587 | 6,433 | 2.49 |
| micro-kernel K = 1,024 | about 13 | 10,267 | 71,731 | 6.99 |
| float dot, accumulator form, 4,096 elements | 8 | 4,100 | 16,402 | 4.00 |
| float dot, accumulator form, 16,384 elements | 32 | 16,388 | 262,210 | 16.00 |
| float dot, accumulator form, 65,536 elements | 128 | 65,540 | 4,194,562 | 64.00 |

The pattern is **loss = about half the pages times the block length** (the k-th fault repeats the work done up to it: L x (P - 1) / 2 in total), quadratic in the size of a cold block. A resuming design repeats nothing: the cost would be the ratio-1.00 line (as the non-accumulator dot, whose ratio is 1.003). Cold start-up is the common case for demand paging, so **this is the largest real loss**, larger than the ticks.

**Loss at a timer tick (computed from the measured lengths; the executor does not take ticks inside a block).** Let L be the block length in cycles, T the tick period in cycles (clock / tick rate), the phase of the block random. If L < T the block is hit with probability L/T, loses on average L/2 when hit, so the expected extra work is **L / (2T)** of the block; for random arrivals (a Poisson process) the factor is (e^(L/T) - 1) / (L/T). If **L >= T the block never completes** (handler time ignored, which would make it worse). Selected results (full table in Appendix B):

| block (cycles) | 100 MHz, 100 Hz | 100 MHz, 1 kHz | 100 MHz, 10 kHz | 1 GHz, 1 kHz | 1 GHz, 10 kHz |
|---|---|---|---|---|---|
| micro-kernel K = 256 (2,587) | 0.13% | 1.29% | 12.9% | 0.13% | 1.29% |
| micro-kernel K = 1,024 (10,267) | 0.51% | 5.1% | **never completes** (L/T = 1.03) | 0.51% | 5.1% |
| micro-kernel K = 4,096 (40,987) | 2.0% | 20.5% | never | 2.0% | 20.5% |
| float dot, accumulator, 262,144 elements (262,148) | 13.1% | never | never | 13.1% | never |
| int8 dot, accumulator, 1 MiB (1,048,580) | never | never | never | never | never |

(Both rows and columns repeat because a block of L cycles at 1 GHz and 1 kHz has the same L/T as a block at 100 MHz and 100 Hz.)

**Worst case.** An unbounded block under a periodic tick shorter than the block: never completes (livelock). The executor hides this by running the block whole, which makes the **interrupt latency equal to the block length**: 1,048,580 model cycles for the 1 MiB int8 accumulator dot, that is 10.5 ms at 100 MHz and 1.05 ms at 1 GHz (**computed**).

**Can the program bound a block?** Yes, and at +0.8% (4.2). The existing micro-kernel's epilogue already adds into C, so the cut is free in meaning.

**The exposure of the real kernels (counted, not measured here).** Accumulator blocks: only `k_sgemm_nt.ukr.s` among the hand-written kernels of `arch-data/vec-forms` (grep for `vclr`, `vfmab`, `vfin`); no compiled kernel makes one (vec-isa 2 table, "selected by the compiler"). K is the caller's choice; K of a few hundred is an **estimate** from the usual cache blocking of GEMM libraries (general knowledge, **unverified** here), which gives 2.6 to 10 thousand cycles: 2.6 to 10% of a 1 kHz tick at 100 MHz, 0.26 to 1% at 1 GHz. Non-accumulator blocks (the 31 compiled and the hand kernels) can be very long but lose nothing.

**What resume would save.** Per interrupt, on average L/2 cycles for the idempotent hidden blocks (the formula), and for each cold page the length of the work so far; it would cost 32 + 32 cycles per interrupt in which an accumulator block is in flight (5.3), so break-even is a block of about 128 cycles. **For the only real user, the micro-kernel, the saving per tick is 1.3 thousand cycles at K = 256 (L/2), against a cost of 16 + 16 for its 8 accumulators (128 B at 8 bytes a cycle); with a bound of 256 strips, the saving is a few percent of the block and the program has no need of it.** The saving is real for long unbounded accumulator blocks, which nobody writes today.

### 5.3 (c) What hidden register files cost

**State that a resume needs (counted from the architecture's own rules).** A block with accumulators has a 16-byte strip on every implementation (errata 175; vec-isa 8.4), the registers that are not accumulators are zero at every strip start, and the pointers and the scalar results are ordinary registers committed with the strip. So the hidden state of a block in flight is: **the accumulators (at most 16 x 16 B = 256 B), the 16-bit naming mask, and nothing else; it does not grow with the strip width.**

| item | bytes | cycles at 8 B/cycle (save; the restore is the same) | source |
|---|---|---|---|
| the micro-kernel's 8 accumulators | 128 | 16 | counted (`k_sgemm_nt.ukr.s`) |
| all 16 accumulators (the most a block can name) | 256 | 32 | counted |
| the whole file if it were architectural, strip 16 B / 32 B / 64 B | 256 / 512 / 1,024 | 32 / 64 / 128 | counted (16 registers x strip; sim64 allocates 64 B each) |
| the scalar register file, for scale | 256 (32 x 8 B) | 32 | manual 1.3 table row on registers |

At 16 bytes a cycle (the vector port of the models) halve every cycle figure. **Assumption**: 8 bytes per cycle for a store, the owner's figure; the repository's vector models use a 16-byte port (`docs/sim64.md`).

**Gates (counted from the repository's own measurements; flip-flops at 6 NAND2 equivalents, `vec-silicon.md` section 1).**

| item | NAND2 equivalents | share of the vector unit (278,959 at 256 bits, wave 1: `vec-strip.md`, "wave 1 at 256 bits is 278,959") | source |
|---|---|---|---|
| the hidden register file, 16 x 256 bits, 3 read, 1 write | 61,578 (37,002 logic + 4,096 flip-flops) | 22.1% (computed) | `vec-silicon.md` (the row of the 16 x 256 register file and the line under the table) |
| the same at 16 x 128 bits | 30,869 | (half) | `vec-strip.md` table, row of the register file |
| the same at 16 x 64 bits | 15,409 | (quarter) | same |
| a **flip-flop shadow of the accumulators only** (16 x 128 bit = 2,048 flip-flops) | 12,288 (2,048 x 6, no muxes) | 4.4% (computed) | counted by the flip-flop rule; muxes **estimate**, not counted |
| a flip-flop shadow of the whole file at 256 bits (4,096 flip-flops) | 24,576 | 8.8% (computed) | same |
| for scale: the scalar core | 219,324 to 307,618 | | `vec-silicon.md` (the paragraph on the scalar core, "219,324 to 307,618") |

A shadow file for **nested exceptions** (an interrupt handler that uses the vector unit while an accumulator block is in flight) would be the second copy of the accumulators: the 12,288 above. The alternative to a shadow is to **save the accumulators into memory** (an ordinary store sequence at 32 cycles) at no gates; and, much cheaper than both, **a handler that uses the vector unit is itself a block that names only its own accumulators and ends before it returns**: under amendment 1 it cannot damage the interrupted block's naming; whether it damages its **values** (registers v0 to v15 that the interrupted block's accumulators live in) is the open question of nested exceptions in the hidden design: today a handler's block overwrites v0 to v15 and the restart from the entry is what makes that harmless. **This is a real argument for restart from the entry**: it is the reason hidden state needs no shadow file. Resume would need either the shadow, or the save to memory, **or** a rule that exception handlers may not use accumulators.

**Context switch, making the state architectural.** Only an accumulator block in flight has anything to save, so under the Dirty flag of alternative A: **a switch away from a process that is not inside an accumulator block costs nothing; one that is inside costs 16 to 32 cycles to save and the same to restore** (counted above). Without the flag the cost is on every switch (32 to 128 cycles for the whole file, at the table's widths), which RVV avoids by `VS` and SME by explicit zero and a software lazy save. **Measured:** nothing; **estimate** by the table.

### 5.4 Which hidden state is safe and which is not, for the block, again

Safe: a hidden copy that is a cache (droppable), registers zero at each strip, the strip width. Not safe: a naming set outside the block (changes the next block's behaviour; hole A); the address-keyed record (not scoped to a context; hole D); accumulator **values** discarded with a re-execution that repeats committed stores (hole B).

### 5.5 (d) The conclusion in the principle's terms

*When is resume worth a hidden or architectural progress state?* When **any** of these holds: (i) the accumulator grows beyond a few hundred bytes (a 2D tile of accumulators like SME's ZA, 8 KB of tile data in AMX, **verified** in 2.3 and 2.2): the loss and the save then both grow, and x86 answers with `start_row`, `XINUSE` and a lazy allocation; (ii) a requirement that interrupts, or a hypervisor exit, are taken inside long accumulator blocks with a small latency and no program cut; (iii) a need to run accumulator blocks that read and write the same memory. None holds for the pdp64 today: the accumulator is at most 256 B, the only user is the micro-kernel, and the program can cut.

*Which design closes the naming hole by construction and keeps the savings?* The **baseline** answer is alternative A: the state is the program's (an architectural progress, here the already-architectural pointers committed per strip, and architectural accumulators saved when Dirty), the naming is part of that state, so the hole cannot arise; the saving is the whole loss of 5.2. The **minimal** answer is amendment 1 plus the bound (alternative B): the hole cannot arise, and the loss is bounded to a small fixed block, so "the savings" of resuming are the bounded few percent of 5.2 and not worth a state.

*My recommendation now:* B (amendments 1 to 4). *Does the answer change the owner's option 1?* It **complements** it: option 1 closes the naming hole and removes the hidden copy; the bound closes the loss, the latency and the livelock, which option 1 alone leaves; the assembler rule closes the common case of hole B. The owner's note that hidden state may be safe is right in the cases of 5.1; the amendments keep exactly those.

## 6. Decisions for the owner, each with a recommendation

Each can be answered **accept**, **change** or **not decided**.

1. **A `VCLR` names accumulators only inside the block (the owner's option 1).** *Recommendation:* accept: `VCLR` outside a block is an illegal instruction and a refusal in `as64`; the naming is derived from the block's text at every start and restart; the hidden copy `vrun_*`/`vrst_*` goes (closes holes A and D). **Reverses** the allowance of errata 172 and vec-isa 8.4 for naming before the block, and leaves the clears of errata 186 decision 13 and errata 192 part 4 vestigial.
2. **Bound the accumulator block by hardware.** *Recommendation:* accept: a block with accumulators may cover at most NMAX strips (256 as an illustration, 4 KiB of the first stream); a longer region raises an exception at `VEC`, before any work; the program cuts and adds into C (the micro-kernel already does). Costs +0.8% of vector cycles on the measured K = 1,024 case and a compare at `VEC`; closes the open item of vec-isa 4.2; reverses nothing. What should NMAX be? *Recommendation:* 256, to be tuned by the owner.
3. **No read-modify-write of one stream in an accumulator block.** *Recommendation:* accept: `as64` refuses a store whose pointer register is a load's in a block with accumulators; the aliasing case stays "unpredictable" (vec-isa 8.8). Closes the common case of hole B (measured: 4 of 8 lanes wrong, silently). Adds to errata 173 to 175; reverses nothing.
4. **Keep restart from the entry (R500) for accumulator blocks, now that they are bounded and idempotent by rule.** *Recommendation:* accept (do not adopt resume now). Adopt architectural accumulator state with a dirty flag (alternative A) if the conditions of 5.5 arise: the accumulator grows beyond a few hundred bytes, interrupts must be taken inside long accumulator blocks, or in-place accumulator blocks are needed. Adopting A **would reverse** R500, errata 172 and 173 on restart, and 6.14.9; the owner may choose it now to follow the baseline exactly (cost: a status field, two instructions, 32 + 32 cycles per switch from an accumulator block in flight, 12,288 NAND2 for a shadow or a save to memory; section 5.3).
5. **Make a handler that uses the vector unit safe by a rule.** *Recommendation:* state in 6.14.9 that an exception handler may use vector blocks (they are bounded, and the block it interrupted restarts from its entry), and that the hardware keeps no vector state between blocks. This is what makes a shadow file unnecessary. Reverses nothing.
6. **Interrupt latency in a block.** *Recommendation:* state in vec-isa 4 that a real implementation takes an interrupt or exit at a strip boundary inside any block (non-accumulator blocks resume at the strip, accumulator blocks restart); the executor's "runs whole" is a simplification of the model, not an architecture rule. The executors then need an option to take an interrupt inside a block, to test the restart (today **no test can**: the hole of the executor, 3.4). Reverses nothing; changes `vec-isa.md` 4.4's note.
7. **Scope the hypervisor path.** *Recommendation:* with decision 1 nothing is left to scope; without it, the hidden copy must become per core and be cleared at a world switch and at a context switch (hole D). Make the test of this (`hv-switch.S`) cover a stale record.
8. **Say in the manual why the baseline resumes and we restart.** *Recommendation:* one paragraph in 6.14.9 or vec-isa 4.1: "RVV, x86 and Arm keep the progress of an instruction in architectural state; the pdp64 keeps none for a block and instead bounds the block and restarts it, because the state is at most 256 bytes, the strip is the program's, and the block is idempotent by rule". (The owner sees the text first: the memory note forbids writing it unasked.) Reverses nothing.

## 7. What could not be verified

* Section 2.5 lists the baseline points not found in a primary source (SVE restart whole, `LDNF1`, the zeroing in the Arm Architecture Reference Manual, the Linux context-switch code, the RVV `VS` Off paraphrase). The quotes were returned by a summarising fetch tool, not read from raw pages: treat each as "as reported".
* **Hole D (the stale hidden record in another context) was found by reading, not run.**
* **Interrupts inside a block were not run**: the executor never takes one (`pdp64exec_vec.inc:4`), so the tick losses of 5.2 are computed from measured block lengths, with stated assumptions (clock rates, random phase, handler time ignored). Page-fault losses were measured with `sim64 -K -x` (each page faults once).
* Cycle counts are model 1 at the default port and commit; model 2 (latencies) was not run. Scalar set-up is not in them.
* The shadow-file gates exclude the multiplexers; they are the repository's flip-flop count only. A latch or custom array would be smaller (`vec-silicon.md`: 47,295 with latches for the 256-bit file).
* The assumption that real GEMM blocks use K of a few hundred is general knowledge and **unverified** here.
* The QEMU copy of the executor was not run on these scratch programs; sim64 shares the source (`common/pdp64exec_vec.inc`).

## Appendix A. The benchmark programs (scratch, not in the repository)

All were assembled with `as64`, linked with `ld64` and run with `sim64 -V` (and `-K -x LO:HI` for the page-fault runs). The micro-kernel is the repository's `docs/encoding-work/arch-data/vec-forms/blas/k_sgemm_nt.ukr.s` unchanged (label renamed). The driver is: `lea` the panels, `movq #K,r3`, `movq #64,r4`, `call k`, `halt`.

### A.1 The in-place accumulator block (hole B)

```
	vec	r1, r3			; r1 = 0x800ff0 (16 bytes on one page, 16 on the next), r3 = r1 + 32
	vclr.l	v4, #1			; present: a hidden block; deleted: an ordinary block
	vld.l	v0, 0(r1)
	vadd.l	v1, v0, #1
	vadd.l	v4, v4, v1		; present only with the vclr
	vst.l	v1, (r1)+
	vend
	; count the lanes of the 8 that differ from 1; the fault handler is `rti`; run with -K -x 0x800000:0x802000
```
Result: ordinary block 0 lanes wrong (exit status 0); hidden block 4 lanes wrong (exit status 4).

### A.2 The accumulator forms of the dot products

```
; float dot, accumulator form (r0 = x, r1 = y, r2 = n)
k:	clr	r4
	lea	(r0)(r2*4),r3
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
k:	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v4,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v4,v0,v1
	vfin
	vacc.l.q	r4,v4
	vend
	movq	r4,r0
	ret
```
The non-accumulator forms are the repository's `k_q8dot.vec.s` and the float dot `vmul.f v0,v0,v1; vacc.f r4,v0`; the 2D block is `tiles/k_avg.vec2d.s`.

### A.3 The cold-page runs

The same programs with the data at absolute addresses in a window (`movq #0x800000,r0`, `0x900000`, `0xa00000`) and `sim64 -K -x 0x800000:0xb00000`; the vector table has the load-fault and store-fault vectors (7 and 8) pointing at a handler that is a single `rti`. The "warm" figure is the same block run with the data in the ordinary program memory (no faults). The run of the accumulator dot at 65,536 elements takes minutes in the simulator (4.2 million repeated cycles).

## Appendix B. The raw numbers

**Block lengths (model 1, strip 32, port 16, commit 1; vector cycles):** micro-kernel K 16: 187; 64: 667; 256: 2,587; 1,024: 10,267; 4,096: 40,987. Float dot (no accumulator): 1,024: 769; 16,384: 12,289; 262,144: 196,609. Float dot (accumulator): 1,028; 16,388; 262,148. int8 dot (`vdacc.b`): 4,096: 641; 65,536: 10,241; 1,048,576: 163,841. int8 dot (`vdot.b` accumulator): 4,100; 65,540; 1,048,580. 2D block `k_avg`: 16 x 16: 100; 64 x 64: 964; 256 x 256: 14,596.

**Cold pages (vector cycles with every page's first access faulting once):** micro-kernel K 64: 1,311; 256: 6,433; 1,024: 71,731. Accumulator dot: 4,096 elements: 16,402; 16,384: 262,210; 65,536: 4,194,562. Non-accumulator dot: 4,096: 3,081 (warm 3,073); 16,384: 12,321 (warm 12,289).

**Tick table, L / T and the expected extra work L / (2T) (computed; "never" is L >= T):**

| clock, tick | T (cycles) | K = 64 (667) | K = 256 (2,587) | K = 1,024 (10,267) | K = 4,096 (40,987) | float dot acc. 262,148 | int8 dot acc. 1,048,580 |
|---|---|---|---|---|---|---|---|
| 100 MHz, 100 Hz | 1,000,000 | 0.03% | 0.13% | 0.51% | 2.05% | 13.1% | never (L/T 1.05) |
| 100 MHz, 1 kHz | 100,000 | 0.33% | 1.29% | 5.13% | 20.5% | never | never |
| 100 MHz, 10 kHz | 10,000 | 3.33% | 12.9% | never (1.03) | never | never | never |
| 1 GHz, 100 Hz | 10,000,000 | 0.00% | 0.01% | 0.05% | 0.20% | 1.31% | 5.24% |
| 1 GHz, 1 kHz | 1,000,000 | 0.03% | 0.13% | 0.51% | 2.05% | 13.1% | never (1.05) |
| 1 GHz, 10 kHz | 100,000 | 0.33% | 1.29% | 5.13% | 20.5% | never | never |

The Poisson factor, (e^x - 1) / x - 1 with x = L / T, differs from L / (2T) by at most 3.1 percentage points in this table (K = 4,096: 20.5% against 23.6%).

**Sources of the gate counts:** `vec-silicon.md` (the 16 x 256 register file 61,578, with 4,096 flip-flops; the 219,324 to 307,618 scalar core), `vec-strip.md` (the 16 x 128 and 16 x 64 files, 30,869 and 15,409; the 278,959 of wave 1 at 256 bits), vec-isa 8.5 (the sum options). Computed here: 4,096 x 6 = 24,576; 2,048 x 6 = 12,288; 61,578 / 278,959 = 22.1%; 12,288 / 278,959 = 4.4%; 24,576 / 278,959 = 8.8%.
