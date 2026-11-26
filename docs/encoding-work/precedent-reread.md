# Re-reading the recent decisions under "precedent is neutral"

*For the owner to read. Nothing here changes the manual, the grammar, the tools or a test; I wrote this one file and touched nothing else.*

You added two rules to the principles: that another architecture doing something is neither for nor against it, and that the consistency of the pdp64 itself outweighs matching other machines. I went back through everything decided since 18 November (the decision list, the decision register, the re-judging documents, the best-of-breed reviews, the hypervisor design and its text, the instruction pass, the timer design, the vector resume design, the annex, the manual chapters on the bus, the kernel, multiprocessing, vectors and the instruction set, and the generated instruction entries) and asked two questions of each choice:

1. Is the reason given for it, wholly or partly, "somebody else does it this way"? If so, does a reason on the principles stand beside it?
2. Does the choice break a habit that the pdp64 keeps everywhere else (operands, destination last, the spelling of sizes, how registers are named, how numbers are handed out)?

The short result: most of the large choices stand on merit, and the precedent was only where I found the idea. A handful copy a foreign convention at a cost to the machine's own regularity. The worst of these is a set of habits that the pdp64 keeps everywhere except in the atomic instructions and the IOMMU, because those two areas were written by copying RISC-V.

A word on the machine's own habits, because I lean on them below. Every instruction with a destination writes it last (`ADD rm, Rd`, `MAX Ra, Rb, Rd`, `FMADD Rs, Rt, Ru, Rd`, `LEA d(Rn), Rd`), as the PDP-11 did. A two-operand instruction's destination is also a source. Sizes are spelled with the PDP-11's letters (`B`, `W`, `L`, and `Q` on moves, bare for the full 8 bytes elsewhere). The three modes keep the PDP-11's numbers. System registers have short names of three to six letters. Vector numbers have one meaning: the number in `ECAUSE` is the entry in the table.

## 1. The summary table

"Rests on precedent" means: take the precedent away and I find no other reason in the record. "Partly" means a merit reason is there too but the shape taken is the precedent's shape.

| # | Decision | Where | Rests on precedent? | Consistent with the pdp64? | Recommendation |
|---|---|---|---|---|---|
| A | The IOMMU takes RISC-V's register map, queue discipline, command names and capability bits "for everything we have in common" | best-of-breed-iommu-irq-atomics.md (proposal A1); rejudge-timer-iommu-irq-atomics.md (F1: "Copy where we agree") | Partly: the merit is "an independent model to test against"; the shape is copied | No: the accepted IOMMU registers are the pdp64's own device pattern (ID, CONTROL, STATUS, RING_BASE, RING_SIZE, DOORBELL, IRQ, DEVICE) | RE-JUDGE |
| B | Atomics write the destination first: `XADD Rd, Rs, (Ra)`, `CAS Rd, Rs, (Ra)`, `LL Rd, (Ra)`, `SC Rd, Rs, (Ra)` | best-of-breed-iommu-irq-atomics.md (C1, "Operand layout from the baseline"); manual 9.13 | Rests on it: RISC-V's `rd, rs2, (rs1)` order | No: the manual's own rule is destination last | CHANGE |
| C | A store-conditional and a compare-and-swap report in a register (`SC`: 0 success, 1 failure); "Flags: None" | manual 9.13; best-of-breed (C1: "RISC-V's meaning") | Partly: the register result is RISC-V's; the C loop argument is merit | Weak: the machine reports every other test through the flags | RE-JUDGE |
| D | Memory-type codes 0 cached, 1 uncached, 2 device strongly ordered, 3 device weakly ordered; "the stricter wins, in the order strong, weak, uncached, cached" | best-of-breed-mmu-virt.md (A3); annex 12; manual 6.7 | The rule stands on merit; the numbering and the vocabulary come from Arm | No: the code order is not the order of strictness (2 is stricter than 3), so "stricter" is a table, not a comparison; one decision text calls type 3 "write-combining" | CHANGE |
| E | Hypervisor register names: `HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `GTBR`, `GTIMECMP`, `VIRQ`, stage 1 and stage 2 | hypervisor-design.md 1.3; manual 6.14 | Partly (the shapes follow Arm's `ELR_EL2`, `HPFAR_EL2`, `VTTBR_EL2` and RISC-V's `hgatp`) | No: `GTBR` (the stage-2 root) and `GPTBR` (the guest's page-table root) differ by one letter; `HEPC` is "the guest's PC at an exit" although the rule says a `G` in front means the guest's copy; `ECAUSE` becomes `HCAUSE` but `EPC` becomes `HEPC` | RE-JUDGE |
| F | Exit codes in `HEXITR` 0 to 23, and vectors 17 to 20 for the exits | hypervisor-design.md 1.6 and decision 6; manual 6.14 | No; this is my own finding | No: code 17 means a hypercall and vector 17 means an exit; code 18 means a guest used a hypervisor register and vector 18 a guest-physical instruction fault; both numbers are read by the same handler | CHANGE |
| G | Atomic mnemonics: `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`; the 4-byte word has an `L` after the name (`XOR_L`, `LLL`, `SCL`) | manual 9.13.1; best-of-breed (the atomics table) | Rests on it: the names are RISC-V's `amoadd`, `amoand`, `amoor`, `amoxor` with an `X` in front | No: the machine's own name for inclusive or is `BIS`; `XOR_` reads as the exclusive or `XOR`; `XXOR` is the real exclusive or | CHANGE |
| H | The set of atomic words is "the baseline's set": ten operations including `XXOR`, `XMAX`, `XMIN`, `XMAXU`, `XMINU` | instruction-pass.md (C18: "the best-of-breed study chose the RISC-V list. Keep") | Rests on it: the count says exclusive or is 0.05% of locked instructions and no count exists for max and min | Consistent but each word is an arithmetic path in the memory system | RE-JUDGE |
| I | The 32-bit form of floating and rotate words is spelled `32` (`FADD32`, `ROR32`); the integer words use `L`; the conversions use `S` for single (`FCVTSD`) | manual 9.9, 9.15; grammar `30-mn-core.hbnf` | Unclear: I could not find the reason | No: three spellings of "the 4-byte one" | RE-JUDGE |
| J | The system register `CPUID` holds the core number; `FEATURES` holds what the machine has | manual 6.5; instruction pass (merge into `MFSR`) | Yes in the name, which is x86's | No: on x86 `CPUID` is the instruction that tells features; here the same word means something else | RE-JUDGE |
| K1 | The timer is two system registers, absolute deadline, zero means never, level interrupt, one shared read-only counter | timer-design.md; rejudge T1 to T8 | No: each option has its merit line; "like Arm and RISC-V" is a side remark | Yes | KEEP |
| K2 | The interrupt level is the vector number divided by 32 | rejudge F6; annex 08 | The idea is x86's; the reason is measured (14,800 gates and 672 state bits saved) | Yes: it also makes the seven virtual lines the seven groups | KEEP |
| K3 | The hypervisor level runs an ordinary kernel with its own registers, "Arm style at once" | the owner's answer of 25 November (his words: "so kernels don't need to be split in two"); annex 10 | No: the reason is that kernels need not be split | Yes | KEEP |
| K4 | The hypervisor is a hidden state bit `H`, not mode value 2 | hypervisor-design.md 1.1 | No: "a guest cannot see the mode" | Yes: mode 2 stays illegal | KEEP |
| K5 | A guest's and the hypervisor's memory types: the stricter wins; no override bit | annex 12 | The idea is Arm's; the reason is that nothing the guest writes can loosen the hypervisor's protection | Yes (see D for the numbering) | KEEP |
| K6 | The constrained `LL`/`SC` loop (16 instructions, registers only, forward branches) | manual 7.4 | "I take the rule that RISC-V gives" but then enforced by hardware: the reservation is lost at the first instruction that breaks the shape | Yes | KEEP |
| K7 | Atomics on 4 and 8 bytes only; a misaligned or uncached atomic is a precise fault | rejudge F10 to F12 | No: measured (95% of value-returning atomics are 4 bytes) and the split-lock flaw | Yes | KEEP |
| K8 | Sequential consistency kept | rejudge F15; annex 01 | No | Yes | KEEP |
| K9 | `TLBIAS`; a 16-bit guest tag shared with the IOMMU; `GENTER` as one mnemonic | best-of-breed-mmu-virt.md A1, A10 | The ideas are Arm's and RISC-V's; the reasons are by-construction | Yes: the tag is the pdp64's word, not VMID | KEEP |
| K10 | `WFE`, `SEV`, `ISYNC`, `FENCE`, `HINT` named as Arm and RISC-V name them; the PDP-11 `WAIT` alias is dropped | instruction-pass.md C5 | Names only | The PDP-11 name is gone; mnemonics are cheap | KEEP (see note) |
| K11 | `ror` and `rol` are one operation by assembler mapping | owner's decision | No | Yes | KEEP |
| K12 | A device-register misaligned access is a precise fault; normal memory allows it | owner's decision | No | Yes: consistent with the atomics | KEEP |
| K13 | A per-device interrupt table in the IOMMU | rejudge F2 | The idea is AMD's; the reason is that a device with no entry raises nothing | Yes | KEEP |
| K14 | The 128-byte reservation block, no register to report it | rejudge F14 | The size equals RISC-V's Za128rs; the reason is "pad to 128 and stop" | Yes | KEEP |
| K15 | `.U` as a dot qualifier (`MOVL.U`, `MCPY.UR`) | instruction pass C9 | The idea is Arm's `LDTR`; the reason is that the window closes itself | The only dot in the mnemonics | KEEP |

Counts: 10 items to act on (4 CHANGE, 6 RE-JUDGE) and 15 KEEP.

## 2. The arguments, in order of how much the architecture would change

### A. The IOMMU takes RISC-V's layout (RE-JUDGE)

*What was decided.* "Take the RISC-V IOMMU's register map, queue discipline, command names and capability bits for everything we have in common, and keep our three deviations as a written list." The re-judging kept it: "Copy where we agree; deviations listed ... best of breed, and an independent model to test against."

*Why it rests on precedent, partly.* The one reason that is not precedent is real: a second implementation of the shared parts is the cheapest way to find our own bugs. But look at what is shared. The pdp64's unit has its own leaf entry (RISC-V's would not do), its own blocked-at-reset, no bypass, its own per-device interrupt table, commands in order. What is left to share is the names of registers and the shape of the two queues. An independent model checks a register map only if the registers behave the same, and they will not once the deviations are in.

*What it breaks.* The decision the owner had accepted before the best-of-breed review fixed the register block as the first eight registers of the pdp64's common device pattern: ID, CONTROL, STATUS, RING_BASE, RING_SIZE, DOORBELL, IRQ, DEVICE, 64 bits wide at 8-byte spacing, the same shape as every other pdp64 device with a ring. A driver writer who knows the console, the entropy source or the DMA test device knows these eight. The RISC-V map (its device-directory pointer, its command-queue base and head and tail, its fault-queue registers, at its offsets and widths) replaces that with a second pattern used by exactly one device. The kernel's driver for the IOMMU is the one driver that would not look like the others.

*Question to ask.* Which would I rather have, a driver that looks like all the others, or a register map a foreign model can run unchanged? And does the foreign model, once the deviations are in, still run unchanged?

*Alternative.* Keep the pdp64 pattern. Take from RISC-V the ideas, judged on merit, and keep them in our own names: a capability register (`CAPS`, already there), a command ring and a fault ring with head and tail, a rule that a command's completion is a sync. The independent model is then written to the pdp64's map, as the QEMU model is already; the test value is a second implementation of the rules (in-order commands, refusal and fault records), not of the offsets.

### B. Atomics write the destination first (CHANGE)

*What was decided.* "Operand layout from the baseline: three register fields for every atomic; `CAS` takes the expected value in `rd` and returns the old value in `rd`. `XADD Rd, Rs, (Ra)` ..." (the manual's `CAS Rd, Rs, (Ra)`, `LL Rd, (Ra)`, `SC Rd, Rs, (Ra)`).

*What stands and what does not.* The three-register shape stands on merit: one leaf, and on a failed `CAS` the old value lands where the C library wants the new expected value. The order of the operands rests on RISC-V (`rd, rs2, (rs1)`) alone. The manual's own rule, stated in the chapter on the instruction set and the assembler appendix, is that a multi-register instruction writes its destination last. The atomics are the only family that breaks it. A student who has just learned `ADD src, dst` meets `XADD dst, src, (addr)` and reverses.

*Consistency detail.* Putting `Rd` last costs nothing, and `CAS` fits the pdp64's own idiom better than it fits RISC-V's, because on a two-operand machine "the destination is also a source" is how `ADD` already works:

```
        ; today                         ; in the machine's own order
retry:  MOVQ  R5, R1                    retry:  MOVQ  R5, R1
        CAS   R1, R2, (R3)                      CAS   R2, (R3), R1     ; R1: expected in, old out
```

*Change.* Spell them `XADD Rs, (Ra), Rd`, `CAS Rs, (Ra), Rd`, `SC Rs, (Ra), Rd`, `LL (Ra), Rd`. Only the assembler syntax and the numbering of the operands in the charts change; the encoding fields can stay where they are.

### C. The result of a compare-and-swap and a store-conditional (RE-JUDGE)

*What was decided.* `SC` reports in `Rd` (0 for success, 1 for failure) "RISC-V's meaning, verified"; the flags are untouched.

*Reason.* Partly precedent, partly the loop. The loop argument is sound for the compare-and-swap's old value. But every other instruction on this machine that has a yes-or-no answer gives it in the flags (`CMP`, `TST`, `FCMP`, `ADDV`), and the branch is one instruction. x86 reports a compare-and-swap through its zero flag; that is no reason to do so, but the saving is real: today a retry loop has to keep a second copy of the expected value in order to compare it afterwards.

```
        ; today                                  ; with Z set on success
retry:  MOVQ  R5, R1                             retry:  MOVQ  R5, R1
        CAS   R1, R2, (R3)                               CAS   R2, (R3), R1
        CMP   R5, R1                                     BNE   retry
        BNE   retry
```

One instruction fewer on every compare-and-swap loop is a direct hit on the principle of fewer instructions executed. `SC` would likewise set Z when it stored.

*Caution.* The instruction pass has an open experiment (whether the flags should exist at all, with compare-and-branch only). If the flags go, the register result is the answer. So the question is open rather than a defect; I recommend settling it together with that experiment, and not leaving "the same as RISC-V" as the reason.

### D. The memory-type codes (CHANGE)

*What was decided.* Types are 0 cached, 1 uncached, 2 device strongly ordered, 3 device weakly ordered. Across the two stages "the stricter of the two is used", "in the order device strongly ordered, device weakly ordered, uncached, cached". The review noted in passing that this "is a four-by-four table, not a `max`" because "the order of the two-bit code" is not the order of strictness.

*Reason.* The rule stands on merit. The numbering and the vocabulary are Arm's ("strongly ordered", "device", "normal"; the manual itself says the source is Arm's memory types and LoongArch's cache attributes). Nobody chose the numbers for this rule; they were there first.

*Inconsistency.* The pdp64 can have the comparison for free if the codes run in the order of strictness. A combine of two codes is then a single maximum on two bits. As it stands the hardware has a lookup the rule did not need, and the number 2 (strong) is stricter than 3 (weak) while 1 is stricter than 0, so a reader guesses wrongly.

*Change.* Renumber so that strictness rises with the code: cached 0, uncached 1, device weakly ordered 2, device strongly ordered 3. Also settle the words: the latest decision text says "write-combining memory" where the manual says "device weakly ordered"; use the manual's word, or rename the type, but one of them everywhere.

### E. The hypervisor register names (RE-JUDGE)

*What was decided.* The hypervisor block (numbers 128 to 148) and the guest copies (149 to 162), named "the guest's register name with a `G` in front".

*Reason.* The shapes follow Arm's and RISC-V's hypervisor registers; I found no reason on the principles for any particular name.

*Inconsistencies I can show.*

* `GTBR` is the stage-2 root and tag. `GPTBR` is the guest's copy of `PTBR`. They differ by one letter, they are both translation roots, and writing the wrong one is not caught: it is a valid register. This is exactly the silent slip the principles want closed by construction.
* The rule is "a `G` in front means the guest's copy". `HEPC`, `HEPSW`, `HEVA` hold the guest's state at an exit, yet they begin with `H`. The guest's own `EPC` is `GEPC`. So the guest's program counter at an exit is `HEPC` and the guest kernel's saved one is `GEPC`.
* `ECAUSE` becomes `HCAUSE` (the `E` is dropped) but `EPC` becomes `HEPC` (the `E` is kept).
* The two-stage vocabulary (stage 1, stage 2, exit, VHE) is Arm's; the pdp64 already coined its own word for the tag (guest tag, not VMID) and could do the same for the stages.

*Question.* Which letters say what, once and for all? One alternative: `H` means set by the hardware at an exit; `G` means a guest's copy of the kernel register of the same name; `S2` means stage 2. Then the stage-2 root is `S2TBR` or `S2ROOT`, the guest page-table root stays `GPTBR`, the exit registers are `HPC`, `HPSW`, `HVA`, `HCAUSE`. Nothing about the behaviour changes; only the names, in the grammar, which everything else is generated from.

### F. Exit codes and vector numbers share numbers (CHANGE)

*What was decided.* `HEXITR` holds a code 0 to 23; `HCAUSE` holds the vector (17 to 20 for exits). The tables in the manual list both, with code 17 a hypercall and code 18 a guest touching a hypervisor register, while vector 17 is "exit for an instruction" and vector 18 a stage-2 instruction fault.

*Reason.* This is not precedent. The code list was made as it was written down and the vector range was taken from the free numbers. It is here because the principle of consistency applies: everywhere else on the machine one number has one meaning, and the handler that prints "cause 18, code 18" has said nothing.

*Change.* Give the codes a numbering that cannot be mistaken for the vectors (for example begin them at 32, or letter-name them), or, better, fold them into one: the exit's vector number in `HCAUSE` already says which class, and `HEXITR` needs only the detail that the vector does not (which `HTRAP` bit, which sub-case).

### G. The atomic mnemonics (CHANGE)

*What was decided.* `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU`, `XMINU`; the 4-byte forms add an `L`: `XADDL`, `XOR_L`, `LLL`, `SCL`.

*Reason.* They are RISC-V's `amoadd`, `amoand`, `amoor`, `amoxor`, `amomax` with the prefix changed. The underscore exists only because `XOR` was taken by the plain exclusive or.

*Inconsistency.* The pdp64 calls inclusive or `BIS` and clear-bits `BIC`, as the PDP-11 did. In the atomics, inclusive or is `XOR_` and exclusive or `XXOR`: a reader who sees `XOR_` thinks exclusive or, and the two are the commonest source of a wrong-instruction bug in the family. `LLL` and `SCL` are three letters of L and a suffix.

*Change.* Name by the machine's own words: `XBIS` for fetch and or, `XAND` and `XXOR` as they are. Keep `L` for the 4-byte size, as `MOVL` does. `LLL` is awkward but names the pair `LL`/`LLL` consistently with `CAS`/`CASL`; I leave it, and mention it only so you can decide.

### H. The set of atomic words (RE-JUDGE)

*What was decided.* The instruction pass checked the atomics and said "the repository's best-of-breed study chose the RISC-V list. Keep; nothing to merge."

*Reason.* The census of 37,566 locked instructions in the kernel modules supports fetch-and-or (7,822), fetch-and-add (7,602), and (5,022), bit set, reset and complement (5,899) and compare-and-swap (1,970). It says exclusive or is 20 (0.05%), and for max and min it says nothing, because x86 has no such instruction: the reason for those four words is that RISC-V has them.

*Question.* What does each of the five unsupported words buy that the compare-and-swap loop does not? A sub-opcode costs little, but each is an arithmetic path in the memory system and a thing to test with the mixed-size and fault rules, and the principle of Occam asks for a benefit. I do not claim they should go; I claim the benefit has not been stated. Measure the kernel survey for a clamp on a shared counter (the case for max), and decide on that.

### I. The spelling of "the 4-byte form" (RE-JUDGE)

Integer words use `L` (`MOVL`, `BSWAPL`, `CASL`, `XADDL`). Floating-point words use `32` (`FADD32`, `FABS32`), the rotate uses `ROR32`, and the conversions use `S` (`FCVTSD`) where `D` means double and `L` means a 4-byte integer. I could not find the reason for any of these in the record, so I cannot say whether precedent chose them (`32` is how other ISAs name a single-precision operation in assembler; `S` is RISC-V's `.s`). The pdp64's own letter is `L` for four bytes, but `L` after a floating word reads "long" and suggests an integer. The question to ask: should a size in this machine always be one letter that means bytes (`B`, `W`, `L`, `Q`) or bits, and not both? If bits, then `MOVL` is the odd one; if letters, then `FADD32` is. The decision belongs to the owner, and the answer should be written next to the PDP-11 habit it keeps.

### J. The register named `CPUID` (RE-JUDGE)

On x86 `CPUID` is the instruction that reports features. Here `CPUID` is the number of the core and the features are in `FEATURES`. A programmer who has used x86 expects the opposite. The word `CORE` or `COREID` says what it holds. The change is a name in the system-register grammar; the hypervisor's virtual core number `VCPUID` follows it (`VCOREID`).

## 3. Precedent used well

These are the places where another architecture was where I found an idea, and the idea was then judged on the principles, kept, changed or refused. They are the balance to the list above.

* **The hypervisor level that runs an ordinary kernel.** Arm's E2H was the idea. The reason recorded is the owner's: "so kernels don't need to be split in two", and the annex then shows what Arm did first (a split kernel with no address-space numbers) as the thing to avoid.
* **The stricter memory type wins.** Arm's rule, taken; Arm's override bit, refused as a second mode with its own hole.
* **The timer.** Arm's relative down-counter and its frequency register, and the x86 edge interrupt, were each refused for a stated flaw (a clamp, a firmware duty, a lost interrupt); the absolute one-shot deadline with zero meaning never is the pdp64's own, with the guest offset applied inside the core.
* **The level from the vector.** x86 and RISC-V's interrupt file derive priority from the number; the pdp64 took it only after measuring that it saves 14,800 gates and 672 bits of state and closes a mismatch between vector and level.
* **The constrained loop.** RISC-V gives a promise of eventual success under a syntactic shape; the pdp64 took the shape and added what RISC-V lacks: the hardware loses the reservation at the first instruction that breaks the shape.
* **The split-lock and the mixed-size flaws.** The annex pages are precedent as a source of mistakes. Each becomes a rule and a test (misaligned atomics fault, mixed sizes have a rule).
* **Sequential consistency.** Every weaker model on the market was studied and refused; the reason is that ordering errors cannot arise.
* **The vector resume.** RVV's architectural state and SME's explicit state were both read; the choice was made by measuring restart against resume, with a bound.
* **The three-register integer ALU (instruction pass).** The idea is the RISC machines'; the decision is deferred until the pairs "move then operate" are counted in the compilers' output (13.1% of the corpus is register moves).
* **Removing `WAIT`.** The PDP-11 name was dropped because the manual said the PDP-11 `WAIT` is refused and an alias that meant a different instruction is a trap for the reader; that is the consistency principle at work, using the pdp64's own history.
* **Virtual lines by priority.** Seven virtual interrupt lines, one per level, is the PDP-11's priority scheme carried into the guest, not a foreign convention.

## 4. What I could not check

* **The 345 KB design notes (`docs/design/open-items.md`, `proposed.md`, `evolution.md`).** I searched them for the precedent phrases and read none of them end to end; a decision there may rest on precedent without my having seen it.
* **The decision register in full.** I read the decision list for 181 to 218 and the documents named in your request, and followed the register only where the list pointed. The decisions of 19 November before the best-of-breed round (the virtualisation form, the audit of sensitive instructions) I took from the list and the hypervisor design, not from each register entry.
* **The generated entries and the tools.** `tools/manual/isa_part1.py` and `isa_part2.py` I did not read. The generated dictionary and instruction chapter still show forms that have been decided away (for example `MOVQ.U`), so the manual I read was one step behind the decisions; the atomic entries still describe "barrier-fused variants taken from LoongArch's pragmatism", a reason that no longer applies since those variants were removed.
* **Whether the IOMMU adoption (A) has been applied.** The grammar and the manual still show the pdp64's own map, so I judged the decision as recorded, not an implementation.
* **The reason for the size spellings (I) and the `H` prefix (E).** I found no record of why; I may be wrong that precedent chose them.
* **Every claim about another machine.** I did not fetch a primary source; where I wrote what Arm, RISC-V or x86 do, I took it from the repository's own documents that say they verified it.
* **Run-time effect.** The suggested changes to the atomics (C) and the memory-type codes (D) have gate and instruction-count consequences I estimated by reading, not measured.

## 5. Index to the records

| Item | Decision list | Register | Documents |
|---|---|---|---|
| A | errata 187, 198, 210 | R510, R521, R533 | best-of-breed-iommu-irq-atomics.md (A1), rejudge-timer-iommu-irq-atomics.md (F1, F20) |
| B, C, G | errata 198, 210, 211, 213 | R521, R533, R534, R536 | best-of-breed-iommu-irq-atomics.md (C1, C2), rejudge (F8) |
| D | errata 204, 218 | R527, R541 | best-of-breed-mmu-virt.md (A3), annex 12 |
| E | errata 195, 211 | R518, R534 | hypervisor-design.md 1.3, hypervisor-text-v3.md |
| F | errata 195 | R518 | hypervisor-design.md 1.6 |
| H | errata 217 | R540 | instruction-pass.md (C18) |
| I | not recorded | not recorded | grammar `30-mn-core.hbnf`, manual 9.9 |
| J | errata 217 | R540 | instruction-pass.md (C6) |
| K1, K2 | errata 210 | R533 | timer-design.md, rejudge T1 to T8 and F6, annex 06 and 08 |
| K3, K4, K9 | errata 195, 204 | R518, R527 | hypervisor-design.md 1.1, annex 09 and 10 |
| K5 | errata 204 | R527 | annex 12 |
| K6, K7, K8, K14 | errata 210, 211, 216 | R533, R534, R539 | rejudge F10 to F15, annex 01 and 02 |
| K10 | errata 217 | R540 | instruction-pass.md (C5) |
| K11, K12 | errata 218 | R541 | the owner's decision |
| K13 | errata 210 | R533 | rejudge F2 |
| K15 | errata 217 | R540 | instruction-pass.md (C9) |
