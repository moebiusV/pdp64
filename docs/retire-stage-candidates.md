Status: record, dated 2026-11-03. It describes the state and the thinking of that time. The current state is in docs/manual and docs/decisions-and-status.md; where this document disagrees, those win. Out of date: the nineteen candidates were decided in errata 84 (what is adopted is in the manual and the ledger; Appendix H and I hold the rest); opcode and encoding details given here are not authoritative, the generated tables are. there is one CPU (the 32-register prefix-coded encoding; r20 and pdp64/16 are gone, errata 122 and 123), the bus is virtio and PCI Express (errata 95, 101), section numbers of the manual are those of the manual at the time (it was renumbered, errata 121: find a part by its title)

# Candidate features that precise exceptions and out-of-order execution make cheap

[← pdp64 index](../README.md)

For the author's annotation. The standing constraint is that the design is out-of-order ready from the beginning (errata 38, priority-lists list 3); first implementations may be in order. Each candidate is scored against the author's priority list: **P1** security and safety (an error that can never arise; else easy to detect; else cheap to recover from; no strange side effects), **P2** opcode choice (fewer instructions and fetches), **P3** encoding (density), **P4** speed and power (gate count), **P5** compiler target, **P6** assembler.

**Terms, once.** *Retire* (the stage where the oldest instruction in flight becomes architectural: its register write and its faults take effect, in program order). *Reorder buffer, ROB* (the in-order list of instructions in flight; each entry can carry a pending fault). *Precise exception* (the machine state is exactly as if every older instruction finished and no younger one started). *Speculation* (running ahead on a guess, undoing it if wrong). *Granule* (the unit of memory that shares one tag). *Colour* (a small number attached to a pointer and to a granule; the access is allowed only if they match).

**Sourcing.** Facts about pdp64 come from the repo (paths given). Facts marked *(read: path)* come from the local kernel trees. Every other external fact is *(from memory, not confirmed)*; where a paragraph contains several, the marker is written once at the end of the sentence group it covers. No web page was fetched. Numbers for external systems are omitted unless read.

**Two observations that run through every entry.**

1. A check that sits beside the retire stage costs a comparator and one pending-fault field per ROB entry, not a pipeline stage. The repo already needs that field: loads already raise `BUSFAULT` precisely (ISA 7.1), and register side effects of the one memory operand are already buffered to retirement (ISA 7.2).
2. A check that guards *data* is different from a check that guards *state*. If the loaded value reaches a dependent instruction before the check completes, a speculative attacker can use the value. Hardware-vulnerabilities rules C1 and C16 forbid that. So a check at retire is cheap only when its answer arrives with the data (tag stored in the same cache line) or when it guards something that has no data to leak (a branch target, a stack pointer, an arithmetic flag). Entries say which case applies.

## Summary table

| # | Name | Group | Verdict | Priority served |
|---|---|---|---|---|
| 1 | Granule colouring, checked at retire | Memory safety | Study | P1 |
| 2 | Reserved colours: uninitialised and freed | Memory safety | Study | P1 |
| 3 | Capability bit (pointer validity tag) | Memory safety | Defer | P1 |
| 4 | Stack limit register, checked at retire | Memory safety | Study | P1 |
| 5 | Landing pads, page-gated, fault attributed to the branch | Control flow | Adopt | P1 |
| 6 | The return predictor as the shadow stack | Control flow | Study | P1, P4 |
| 7 | Return-address authentication (PAC) | Control flow | Defer | P1 |
| 8 | `SYS` page bit (system call only from marked pages) | Control flow | Adopt | P1, P2 |
| 9 | Overflow-trapping arithmetic (`TRAPV`, trapping forms) | Arithmetic | Study | P1, P2 |
| 10 | Architectural poison bit per register | Arithmetic and data | Defer | P1 |
| 11 | Secret taint with `DIT` enforcement | Arithmetic and data | Study | P1 |
| 12 | Retire-gated visibility (a "strict" domain) | Speculation | Study | P1 |
| 13 | Predictor and cache-way isolation by ASID | Speculation | Adopt (predictors); Defer (ways) | P1 |
| 14 | Residue check of ALU results at retire | Glitches | Study | P1 |
| 15 | Precise ECC and parity reporting for reads | RAS | Adopt | P1 |
| 16 | Precise hardware watchpoints at retire | Debug | Adopt | P1, P6 |
| 17 | The restart contract (blind restart, restartable system calls) | Recovery | Adopt | P1 |
| 18 | `UA` window that closes itself | Privilege boundary | Study | P1 |
| 19 | User-visible transactional region | Recovery | Reject | P1 |

## Memory safety

**1. Granule colouring, checked at retire.**

**What it does.** Every 16-byte granule of tagged memory carries a 4-bit colour in a side table; the top bits of a pointer carry a colour; a load or store faults precisely if they differ. The allocator colours a block on `malloc` and recolours it on `free`, so an overflow into a neighbour, a stale pointer and a pointer forged from a neighbour's address all fault. The 39-bit canonical rule (ISA 6.1.1) leaves bits 39..63 equal to bit 38, so the colour cannot live in the pointer without a rule change; see Cost.

**Where it runs.** Memory system, with the tag read from the same cache line as the data (the tag array is part of the line), and the compare in the load/store unit. The mismatch flag is recorded in the ROB entry and raised at retire.

**Why precise exceptions or OoO make it cheap.** The tag arrives with the data, so no extra latency is added on a hit. On a miss the tag is fetched with the line. A mismatch is just another pending fault in the ROB entry, the same path as a page fault. A store checks the tag at address generation and only writes the store buffer; the buffered store is discarded if the entry faults. In order, the same check costs a stall on tag-cache misses; out of order, the miss is hidden.

**Precedent.** ARM MTE: 4-bit allocation tag per 16-byte granule, logical tag from pointer bits 59-56, synchronous, asynchronous and asymmetric reporting (read: `linux/Documentation/arch/arm64/memory-tagging-extension.rst`); the allocation tag is set to 0 when a `PROT_MTE` page is first mapped, and the flag cannot be cleared by `mprotect` (read, same file). Asynchronous mode reports no faulting address (read, same file), which is the cost of leaving the check off the retire path. SPARC ADI (Silicon Secured Memory): 4-bit version per 64-byte line, in Solaris and Linux on M7/S7 and later; the line size was coarse for small objects *(from memory, not confirmed)*. Speculative probing of MTE tag results through a timing channel was published in 2024 (TikTag) *(from memory, not confirmed)*; hardware-vulnerabilities C16 already requires "no timing oracle to a failed check".

**Novelty.** Exists as MTE and ADI. What no shipping CPU is known to combine: a colour check that is always synchronous and precise (MTE offers it but defaults to asynchronous for speed) with the restart contract of item 17, so a handler can repair and resume. Not confirmed.

**Cost.** 4 bits per 16 bytes of memory, a 3.1% overhead, in an ECC-style side band or a carve-out. One 4-bit comparator per memory port. A pointer-colour field: either a rule change to the canonical check (bits 63..60 hold colour, bits 59..39 still equal bit 38, so 25 high bits become 21 sign bits plus 4 colour bits), or a colour kept in a register beside the pointer. `MBLK` operations check per line, not per byte. New instructions: set-colour, get-colour (two `SYSX` words or `MESC` sub-opcodes). OS work: `malloc` colours blocks, `free` recolours, the kernel colours its own allocator (`pool(9)`).

**Fit with the priorities.** P1: turns silent heap corruption into a precise fault: detection plus cheap recovery. P4: a comparator and 3% memory. Conflict: it spends high pointer bits the ISA refused to software ("high bits are architecturally refused", ISA 6.2), and the openbsd-mitigations.md verdict on idea 8 was "not now". The new fact is the OoO retire path, which removes the stall that made it unattractive.

**OpenBSD fit.** `malloc(3)` already randomises, junks and delays reuse of freed chunks (openbsd-mitigations.md 2.11), so colouring turns its probabilistic detection into a deterministic one. OpenBSD's arm64 code detects PAC in `cpu.c` (read: `openbsd/sys/arch/arm64/arm64/cpu.c`); whether it uses MTE was not found in the sources read.

**Verdict: Study.** The tag compare is cheap; the open question is the pointer-bit trade, which needs the measurement in "What to measure first".
i like it, do it. approved. no delay.


**2. Reserved colours: uninitialised and freed.**

**What it does.** Two colours are architectural. Colour 0 means "never written since allocation": a load faults, a store to it succeeds only if the store is to the full granule and then recolours it to the owner's colour. Colour 15 means "freed, quarantined": any access faults. A freshly allocated page reads as a trapping value, so uninitialised reads of the Heartbleed and stack-residue kind cannot return old data.

**Where it runs.** Memory system, as item 1; the recolour on store is a tag write beside the data write.

**Why precise exceptions or OoO make it cheap.** A load that hits colour 0 is a pending fault in its ROB entry; no handler runs unless the load retires, so wrong-path loads of uninitialised memory cost nothing. Partial stores to colour 0 are the cost: a store smaller than the granule must either read-modify-write the granule (an extra memory read, so the "uninitialised" state needs the line) or fault. The honest rule is to fault, and have the allocator zero with `MSET`, which writes whole granules and recolours them.

**Precedent.** Uninitialised-read detection exists as software: MemorySanitizer, Valgrind memcheck *(from memory, not confirmed)*. Hardware poisoning of memory contents exists in ECC "poison" bits that carry an uncorrectable-error mark to the consumer *(from memory, not confirmed)*. Itanium's NaT bit marks uninitialised registers *(from memory, not confirmed)*. Tagged memories (Burroughs B5000 family, Lisp machines) trapped on tag mismatch in hardware *(from memory, not confirmed)*. No shipping CPU found that offers "unwritten" and "freed" as architecturally reserved colours of a general memory-colouring scheme.

**Novelty.** Reserved colours with defined meaning: no shipping CPU known to do this. MTE leaves colour assignment wholly to software, and its colour 0 is the ordinary untagged colour (read: MTE doc above). Not confirmed.

**Cost.** Zero extra storage beyond item 1; two opcodes' worth of semantics (the rule that a store may clear colour 0). Kernel work: the page allocator hands out pages coloured 0; `MSET` or `bzero` of a page recolours it, which makes the existing "zero at allocation" step the initialisation step. Cost to `MSET`: it writes tags with data.

**Fit with the priorities.** P1 strongly: uninitialised reads and use-after-free become errors that cannot return data. P2: `MSET` already exists, so no new instruction. Conflict: copy-on-write and `fork` must copy colours with data.

**OpenBSD fit.** `free()` junking and `freezero`, `malloc_conceal` (openbsd-mitigations.md 2.11) get a hardware form; kernel `explicit_bzero` is unchanged.

**Verdict: Study.** Depends on item 1; the measurement is how often compiled code writes less than a granule into fresh memory.

approved. do it.

**3. Capability bit (pointer validity tag).**

**What it does.** One tag bit per 16-byte granule marks "this granule holds a valid pointer"; ordinary stores clear it, only a capability store sets it, so pointers cannot be forged by integer writes. With a bounds field this is CHERI.

**Where it runs.** Memory system and decode; the bounds check is at address generation.

**Why precise exceptions or OoO make it cheap.** The bounds compare is off the critical path and its failure is a pending fault. The tag bit is cleared by any store; that clear is a tag write beside the data write.

**Precedent.** CHERI and Arm Morello: 128-bit capabilities with a hidden tag bit; Morello silicon exists and CheriBSD runs on it; porting costs were mostly pointer-size and ABI work, and software that stores pointers in integers breaks *(from memory, not confirmed)*. Intel MPX (bounds registers and a bounds table) was removed from GCC and Linux because of its cost, poor multi-thread behaviour and little use *(from memory, not confirmed)*. The Mondrian memory protection design added per-word permissions in a trie *(from memory, not confirmed)*.

**Novelty.** Exists as CHERI. No new claim.

**Cost.** A 128-bit pointer doubles the pointer size and breaks the "registers are 64 bits, one profile" rule (ISA 6.1 rule 1); this reopens the register file, the ABI and every `MOVQ` of a pointer. The 1 bit per 16 bytes is cheap; the register width is not.

**Fit with the priorities.** P1: highest memory-safety ceiling. P3 and P4: against it, as it doubles pointer traffic. P2: more fetches.

**OpenBSD fit.** OpenBSD has no CHERI port; CheriBSD is FreeBSD-derived *(from memory, not confirmed)*.

**Verdict: Defer.** Items 1 and 2 give most of the practical detection at far smaller cost; revisit only if the author wants provable spatial safety and accepts 128-bit pointers.

can we do this with 64 bit pointers instead of 128 bit? if each register has flags or modes attached outside the official 64 usable bits, couldn't we do this cheri thing that way too?

**4. Stack limit register, checked at retire.**

**What it does.** A privileged register `SLIM` holds the lowest address the stack pointer may take; any instruction that writes `SP` (`CALL`, `PUSH`, `LEA -N(SP),SP`, `SUB`) faults precisely if the new `SP` is below it. A stack overflow and a stack pivot to a heap address both fault at the instruction that moved `SP`, before any store goes to the bad address.

**Where it runs.** Execute (the comparator on the `SP` write) with the fault recorded at retire.

**Why precise exceptions or OoO make it cheap.** The compare is one 39-bit comparator on the one register that is written at retire; because writes to `SP` are in-order at retire, the check sees the architectural `SP`, not a speculative one. In an out-of-order core, a stack engine tracks `SP` adjustments in decode; the limit can be checked there against the tracked value, off the execute path.

**Precedent.** The MIPS and RISC-V ABIs have no such register; Windows and Linux use guard pages *(from memory, not confirmed)*. OpenBSD checks the stack pointer against a `MAP_STACK` region at system call and fault (openbsd-mitigations.md 2.5). Hardware stack-limit registers exist in ARM Cortex-M (`MSPLIM`, `PSPLIM`) *(from memory, not confirmed)*. Segment limits on x86-32 are the ancestor.

**Novelty.** Exists on Cortex-M. For a general-purpose 64-bit MMU machine with an OS: not confirmed.

**Cost.** One 64-bit register in thread context (saved with `PSW`), one comparator, and two `SYS` words (`MTSR`/`MFSR` register numbers already provide a slot: ISA 4.11, "register numbers 13 to 255"), so zero new opcodes. Dynamic `alloca` frames are covered.

**Fit with the priorities.** P1: removes the "stack pivot with the syscall check missed" class and the guard-page-skipping large frame (Stack Clash). P4: one comparator. The earlier verdict (openbsd-mitigations.md idea 10) was "not worth it" because the check at system call is enough; that held for an in-order machine with no retire-stage field. It does not cover the unprivileged case of a long computation that pivots and never calls the kernel.

**OpenBSD fit.** Replaces the `MAP_STACK` check at syscall with a per-instruction one; the kernel would load `SLIM` at thread switch.

**Verdict: Study.** Cheap, but the author already rejected one form; reconsider only with the numbers from "What to measure first".

approved. do it.

## Control flow

**5. Landing pads, page-gated, with the fault attributed to the branch.**

**What it does.** `LPAD` already exists (SYS class 0 minor 9). With the page bit "landing pads required" set on the target page (openbsd-mitigations.md idea 3), an indirect `JMP`, `CALL` or `JTAG` whose target is not an `LPAD` faults. The fault is reported at the *branch* (EPC = the branch, EVA = the target), not at the target.

**Where it runs.** Decode of the target instruction (is it `LPAD`?) and retire of the branch (the branch retires only after its target's first instruction has been decoded and confirmed).

**Why precise exceptions or OoO make it cheap.** The branch unit already waits for the target to resolve; decode of the first target instruction gives the answer; the branch's ROB entry takes the fault. No hidden "expect a pad next" state is held between instructions, which closes a real hole: a page fault on the target fetch followed by a restart at the target would otherwise lose the expectation and skip the check. With the fault on the branch, `RTI` re-executes the branch and rechecks.

**Precedent.** Intel IBT (`ENDBR64`) and ARM BTI; RISC-V Zicfilp (an `LPAD` instruction; the doc exists locally at `linux/Documentation/arch/riscv/zicfilp.rst` and was not read in detail). x86 reports the control-protection fault at the target instruction *(from memory, not confirmed)*. Intel CET has `ENDBR` as a NOP on old CPUs, as pdp64's `LPAD` can be.

**Novelty.** Landing pads exist. Attributing the fault to the branch and making restart re-arm the check: no shipping CPU known to specify that; not confirmed. The forensics gain is real: the handler learns which branch was hijacked, not only where it went.

**Cost.** 1 translation bit, one comparison in decode, 2 bytes per address-taken function (openbsd-mitigations.md 2.10). Already priced in docs; ABI version 2 switches it on.

**Fit with the priorities.** P1 strong; P3 slight cost (2 bytes per pad); P4 negligible.

**OpenBSD fit.** Directly: OpenBSD enforces BTI/IBT by default with a linker opt-out (openbsd-mitigations.md 2.10; the arm64 disassembler in the tree knows `bti` variants: `openbsd/sys/arch/arm64/arm64/disasm.c`, read).

**Verdict: Adopt.** Reserve the page bit now, specify the fault at the branch, switch on in ABI 2.

approved. do it.

**6. The return predictor as the shadow stack.**

**What it does.** An out-of-order core carries a return-address stack (a hardware stack of predicted return targets). Make it architectural: `CALL` pushes the return address on the data stack as now and also on a per-thread protected shadow page via the predictor's spill path; `RET` compares the loaded address with the shadow top. One comparison serves both purposes: a mismatch between prediction and the loaded address is caught at execute anyway; here a mismatch with the shadow is a precise fault instead of a silent redirect.

**Where it runs.** Retire (the compare of the loaded return address with the architectural shadow entry).

**Why precise exceptions or OoO make it cheap.** The predictor already needs a retire-time repair copy of its stack to recover from a mispredicted path, and it already compares predicted and actual targets. Checking an architectural copy adds a protected-page spill and a fault, not a comparator.

**Precedent.** Intel CET shadow stack and ARM GCS: `BL` pushes `PC` on a separate stack; `RET` compares; the stack pointer register is read-only to ordinary instructions (read: `linux/Documentation/arch/arm64/gcs.rst`, `x86/shstk.rst`). RISC-V Zicfiss: `sspush`, `sspopchk`, raising a software-check exception (read: `riscv/zicfiss.rst`). All three need OS work for `setjmp`/`longjmp`, signals, threads and stack switching (read: gcs.rst "instructions for switching between guarded control stacks"). OpenBSD's analysis here rejected it as the largest source of recovery code (openbsd-mitigations.md idea 4, option B).

**Novelty.** Using the return predictor's own repair stack as the architectural shadow: no shipping CPU known; not confirmed.

**Cost.** One shadow-stack-pointer register in context, a page type "shadow" in the page table entry, spill and fill on overflow, and the OS work above. The OS work is the real price.

**Fit with the priorities.** P1: strongest return protection. Conflict with P1's "cheap to recover": `longjmp`, C++ exceptions and `rfork` need shadow-aware code. P4: no extra comparator.

**OpenBSD fit.** OpenBSD chose retguard in software and has no shadow stack on amd64 *(from memory, not confirmed)*; it would use this only if `longjmp` and unwinding cost nothing.

**Verdict: Study.** The cost is the recovery code; look only if the `setjmp` path can be made one instruction.

definitely study how to do this in a way that minimizes recovery code; find ways to make the setjmp path one instruction.

**7. Return-address authentication (PAC).**

**What it does.** `CALL` signs the return address with a keyed hash placed in the unused high bits; `RET` verifies. The 25 spare bits (bits 39..63) hold a code.

**Where it runs.** Execute, with verification at retire.

**Why precise exceptions or OoO make it cheap.** Verification can sit off the critical path because the `RET` target is predicted; the check resolves while the predicted path runs, then faults at retire.

**Precedent.** ARM PAC: five keys, a keyed MAC over pointer, a modifier and key, stored in high pointer bits, 7 bits wide at a 48-bit virtual address (read: `linux/Documentation/arch/arm64/pointer-authentication.rst`). Brute-force guessing of PAC bits through speculation (PACMAN) was published in 2022 *(from memory, not confirmed)*. OpenBSD's tree detects PAC support at boot (read: `openbsd/sys/arch/arm64/arm64/cpu.c`).

**Novelty.** Exists.

**Cost.** Hundreds of gates for a keyed hash, key registers in context (openbsd-mitigations.md idea 8), pointer width 25 bits at 39-bit VA gives a wide code but it also deletes the canonical check.

**Fit with the priorities.** P1: moderate; probabilistic, not deterministic. The author's wording favours "an error that can never arise", which a keyed code is not.

**OpenBSD fit.** Plausible, as on arm64.

**Verdict: Defer.** Items 5 and 6 are deterministic and cheaper.

agreed. defer.

**8. `SYS` page bit (system call only from marked pages).**

**What it does.** The page-table entry gets one bit; a `TRAP` or `SYSCALL` executed from an unmarked page faults at decode. The kernel marks `libc` text; shellcode, JIT pages and writable pages cannot make system calls (openbsd-mitigations.md idea 2).

**Where it runs.** Decode, with the fault raised at retire.

**Why precise exceptions or OoO make it cheap.** The `TRAP` is already a serialising instruction; the check is a one-gate AND with the page attribute of the fetch, available from the instruction TLB entry that fetch already holds.

**Precedent.** OpenBSD `msyscall(2)` (removed) and `pinsyscalls(2)`, kernel-checked tables of permitted call sites (openbsd-mitigations.md 2.6). Linux `syscall user dispatch` and seccomp are software *(from memory, not confirmed)*. Hardware page-level syscall permission: no shipping CPU known; not confirmed.

**Novelty.** No shipping CPU known to enforce this in the page table. Not confirmed.

**Cost.** 1 PTE bit (reserved bit 10 or 11 today), 1 gate, 0 opcodes; saves about 4 instructions per call by the repo's estimate.

**Fit with the priorities.** P1 and P2 (shorter syscall path). Region granularity is weaker than OpenBSD's exact pinning and layers with it.

**OpenBSD fit.** Matches `pinsyscalls` as a coarse first filter.

**Verdict: Adopt.**

agree. do it.

## Arithmetic and data

**9. Overflow-trapping arithmetic (`TRAPV`, trapping forms).**

**What it does.** Today `ADD` sets `V` and `BVS` branches (ISA 6.3 table). Add `TRAPV`, a two-byte instruction that raises a precise trap if `V` is set, or a trapping `ADD`/`SUB`/`MUL` family in `AESC`. The compiler emits checked arithmetic for Rust, Swift, C# and overflow-sanitised C at one added parcel.

**Where it runs.** Execute (the existing `V` computation); the trap is taken at retire.

**Why precise exceptions or OoO make it cheap.** The overflow bit is produced with the result and travels in the ROB entry; the trap is raised only if the instruction retires. A mis-speculated overflow never traps. No flag-hazard work: the trapping form reads no old flag.

**Precedent.** MIPS `ADD` traps; compilers used `ADDU` everywhere, so it went unused *(from memory, not confirmed)*. RISC-V omitted trapping arithmetic deliberately, citing the extra branch as cheap *(from memory, not confirmed)*. x86 `INTO` was removed in 64-bit mode *(from memory, not confirmed)*. The lesson is that the instruction survives only if the ABI and the compiler's default use it.

**Novelty.** Exists historically (MIPS, Alpha `ADDQ/V`, VAX integer-overflow trap enable). Nothing new.

**Cost.** One AND gate per ALU; one opcode (`TRAPV`, page-2 abbreviation) or one `AESC` sub-opcode group. 68.2% of compiled instructions write flags (ooo-readiness.md section 1), and the flag-write plan there (moves write none) keeps `V` meaningful only after arithmetic, which suits `TRAPV`.

**Fit with the priorities.** P1: overflow becomes a trap instead of a wrong answer. P2: `ADD; TRAPV` is two instructions, the same count as `ADD; BVS` but 2 bytes shorter (no displacement) and with no handler code at each site. P5: matches sanitiser output.

**OpenBSD fit.** Used by sanitised builds; not by the base system by default.

**Verdict: Study.** Count the `BVS` sites in the corpus first.

study, but i'm leaning to yes, do it.


**10. Architectural poison bit per register.**

**What it does.** A 65th bit per register marks "this value came from a failed operation"; the failure is deferred and raised only if the poisoned value is used (stored, branched on, or used as an address). It moves the fault from creation to use.

**Where it runs.** Execute and retire.

**Why precise exceptions or OoO make it cheap.** An out-of-order core already holds this state microarchitecturally: a load that will fault carries its fault in the ROB entry and its dependents inherit it, and the fault is raised only at retire. Exposing it to software costs the part the hardware does not already do: saving and restoring the bit across calls and context switches.

**Precedent.** Itanium NaT bits on general registers with a spill register for the bits (`UNAT`), used by speculative loads `ld.s`; the NaT bit made context-switch and spill code larger *(from memory, not confirmed)*. IEEE NaN is the floating-point form. Speculative-load tokens are also in the Mill design *(from memory, not confirmed)*.

**Novelty.** Exists (Itanium). Nothing new.

**Cost.** 1 bit per register in the physical register file; every save/restore of a register needs a companion bit or a poison collection register; every ABI save path changes (callee-save in `PUSHM`). Benefit is for compilers that hoist loads over checks, which an out-of-order core does by itself.

**Fit with the priorities.** P1 conflict: adds a new state that must be saved, a "strange side effect" on every register move. P5 gain is small on an OoO core.

**OpenBSD fit.** None.

**Verdict: Defer.**

study this more, i'm leaning to yes on this, the extra bit on each register shouldn't be a big deal since other things are already doing it right? our register file is small enough it shouldn't be a big deal, only reason we aren't doing 32 registers is opcode layout, not gate cost.

**11. Secret taint with `DIT` enforcement.**

**What it does.** Extends the `DIT` bit decided in architecture-recommendations.md R-8. A register or load can be marked secret (`TAINT`/`UNTAINT` forms); taint propagates through ALU results; a *branch condition*, a *memory address* or a *variable-latency instruction operand* that is tainted raises a precise fault in a domain with `DIT` set. Constant-time code is verified by the hardware instead of by audit.

**Where it runs.** Decode and execute (the taint bit travels with the physical register); fault at retire.

**Why precise exceptions or OoO make it cheap.** Out-of-order cores already track per-physical-register ready bits and flags; a taint bit is one more bit per physical register with an OR on the destination. Because the fault is raised at retire, wrong-path branches on tainted data do not fault, and the retire-gated visibility of item 12 keeps them from leaking. Taint tracking in speculative-execution research uses the same ROB position ("visibility point"), STT *(from memory, not confirmed)*.

**Precedent.** ARM `DIT`, Intel `DOITM` and RISC-V `Zkt` declare a set of instructions with data-independent latency; none enforces that software used only those *(from memory, not confirmed)*. Hardware taint tracking is academic (Dover/CHERI-adjacent tagged architectures, STT/SPT for speculation) *(from memory, not confirmed)*.

**Novelty.** No shipping CPU known to fault on a secret-dependent branch or address in hardware. Not confirmed.

**Cost.** 1 bit per physical register plus 1 in the saved context (the bit in a saved register is free by the author's rule); a taint-source instruction; propagation logic of a few OR gates per ALU. Compiler: needs a `secret` qualifier or a library that marks keys; false faults if taint propagates into a table index that is not actually secret-dependent.

**Fit with the priorities.** P1 strong (timing channels detected, not merely hoped away); P5 cost (a qualifier). The `hardware-vulnerabilities.md` section 4 list of variable-latency instructions is the work item.

**OpenBSD fit.** `libcrypto`/`libressl` constant-time code could be verified; OpenBSD has no taint qualifier today *(not confirmed in the sources read)*.

**Verdict: Study.** Highest novelty on the list; the main risk is false positives.

study; i don't like false positives. that isn't precise or deterministic. otherwise it sounds fantastic.

## Speculation and side channels

**12. Retire-gated visibility (a "strict" domain).**

**What it does.** A domain marked strict (a bit in the saved context, chosen by `pledge`-like policy) changes no shared microarchitectural state (cache replacement, prefetcher, predictor, TLB fill) until the instruction that caused it is non-speculative, i.e. until all older branches and faults have resolved. Loads that miss wait for the "visibility point".

**Where it runs.** Memory system, gated by the ROB's oldest-unresolved-branch pointer.

**Why precise exceptions or OoO make it cheap.** The ROB already knows when an instruction can no longer be squashed. A bit selects between "act now" and "act at the visibility point". Hits still forward; only fills and replacements are deferred. In an in-order core the bit is a constant (nothing is speculative past a load).

**Precedent.** Delay-On-Miss, InvisiSpec, STT and related academic designs *(from memory, not confirmed)*; their reported slowdowns varied widely by workload and are not repeated here. Industry ships only point fixes: IBRS/IBPB, SSBD, `LFENCE` serialisation. The hardware-vulnerabilities.md rule C4 asks for "an architectural per-domain switch that can disable all speculation for a domain".

**Novelty.** No shipping CPU known with an architectural per-domain switch for retire-gated visibility. Not confirmed.

**Cost.** One context bit; control logic at the cache fill path; performance cost only to strict domains. The bit is saved in the PSW (free by the author's rule); it is visible state, as the author prefers.

**Fit with the priorities.** P1 strong against Spectre-class leaks; P4 cost is paid only by domains that ask. Conflict with P4 for crypto and browser-style code.

**OpenBSD fit.** Fits OpenBSD's per-process policy style (SMT off, mitigations by default); the kernel could run strict.

**Verdict: Study.**

study, but i like the sound of it. leaning toward it.

**13. Predictor and cache-way isolation by ASID.**

**What it does.** Branch predictor entries (direction, target, return, history) carry the ASID and privilege level; an entry made by one domain is invisible to another. One instruction, a `HINT` kind, clears all predictor state. For caches, an optional way mask per ASID partitions L2/L3 ways between domains.

**Where it runs.** Fetch (predictor tag compare) and the cache replacement logic.

**Why precise exceptions or OoO make it cheap.** The predictor tag is only a few bits per entry; a wrong entry costs a misprediction, caught by the retire-time verification that every predictor already has. The `HINT` clear is a no-op on a core with no predictor.

**Precedent.** x86 `IBPB`, eIBRS and ARM `CSV2` isolate or flush predictors; branch history injection (2022) showed that history needed isolation too, and Linux needed 3,830 lines in `bugs.c` to choose among mitigations (hardware-vulnerabilities.md section 3). Cache-way partitioning: Intel CAT, ARM MPAM *(from memory, not confirmed; `linux/Documentation/arch/arm64/mpam.rst` exists locally, unread)*.

**Novelty.** Exists as separate mechanisms. A predictor that is born tagged and a single architectural flush: partly shipping; not confirmed.

**Cost.** ASID bits (16) are too wide; hash to 4 to 8 bits per entry. One `HINT` kind. Way masks: one register per domain.

**Fit with the priorities.** P1 strong; P4 a few bits per predictor entry. Rule C2 in hardware-vulnerabilities.md.

**OpenBSD fit.** Removes the need for OpenBSD's per-model `codepatch` mitigation selection (openbsd-mitigations.md section 7, item 5).

**Verdict: Adopt (predictors); Defer (way masks until SMP).**

agree, adopt. smp is immediate, so don't defer.

## Glitches and RAS

**14. Residue check of ALU results at retire.**

**What it does.** Each ALU result is checked against a small residue (value mod 3, two bits) computed independently from the operands' residues; a mismatch raises a precise fault `ECAUSE = RESIDUE` and the instruction is re-executed. Voltage glitching (Plundervolt, CLKscrew) and soft errors in adders and multipliers are caught.

**Where it runs.** Execute (the small residue unit runs beside the adder) and retire (the compare).

**Why precise exceptions or OoO make it cheap.** The residue is carried in the ROB and compared at retire, off the critical path. The faulting instruction has not yet become architectural, so the fix is to re-run it: the retire stage already supports that for load replay (ooo-readiness.md 6.10).

**Precedent.** IBM mainframes (z990 onwards) execute instructions in duplicated pipelines and compare before retire, with instruction retry from a checkpointed state; POWER6 used residue checking on arithmetic *(from memory, not confirmed)*. Lockstep cores are standard in automotive (ARM Cortex-R, Infineon AURIX) *(from memory, not confirmed)*. None of these is in a general-purpose 64-bit CPU aimed at an open OS and a security threat model.

**Novelty.** Exists on mainframes and automotive. Pairing it with the `ECAUSE` restart protocol of item 17 in a general-purpose small core: not confirmed.

**Cost.** 2 bits per register (residue), a mod-3 reducer and a small mod-3 adder/multiplier beside each ALU; roughly 5 to 10% of ALU area is the usual figure quoted for residue codes *(from memory, not confirmed)*. A multiplier check is cheap, a shifter or logical-op check is not (residue is not preserved).

**Fit with the priorities.** P1: error "easy to detect and cheap to recover from" for transient faults. P4: gates, paid by a ROB bit and a residue unit. Conflict with low gate count on the small FPGA core, so it is an optional implementation feature, with the `ECAUSE` value reserved architecturally.

**OpenBSD fit.** The kernel reports and ignores; nothing to change.

**Verdict: Study.**

do it. i like it.


**15. Precise ECC and parity reporting for reads.**

**What it does.** An uncorrectable ECC error on a *read* is reported as a precise abort `ECAUSE = ECCFAULT` at the reading instruction, with the physical address in `EVA`, exactly as `BUSFAULT` already is for a read timeout (ISA 7.1). A corrected error is logged and the load completes. Only posted writes and background scrub remain imprecise machine checks (ISA 7.1 already says this about posted writes). Parity on the PC, the TLB and the register file reports the same way.

**Where it runs.** Memory system and retire.

**Why precise exceptions or OoO make it cheap.** The load carries its error flag in its ROB entry; a poisoned line returned by the memory system is a fault only if the load retires. An error on a wrong-path load is silently dropped, where a conventional machine would take a machine check for a load that never mattered. This is the practical benefit of precise exceptions.

**Precedent.** Intel machine-check architecture classifies recoverable errors as "action required" or "action optional" and some are delivered precisely *(from memory, not confirmed)*. ARM RAS Extension defines synchronous and asynchronous error exceptions and a poison mark carried with data *(from memory, not confirmed)*. The Linux `memory_failure` path kills the process using the poisoned page *(from memory, not confirmed)*.

**Novelty.** Exists. The specific contract "every read error is precise; only posted write errors are imprecise" is a one-line rule that costs the hardware nothing and removes the `MCE` decode burden from the OS.

**Cost.** One `ECAUSE` value; the memory system must carry a poison flag with each returned beat. OS work is in the page-poison path.

**Fit with the priorities.** P1: detect precisely, recover by killing or remapping one page. No conflict.

**OpenBSD fit.** OpenBSD's `mca`-style handling is minimal *(not confirmed in the sources read)*; a precise abort fits the existing signal path.

**Verdict: Adopt.**

agree, do it.

## Debug and recovery

**16. Precise hardware watchpoints at retire.**

**What it does.** Two to four address-range comparators raise a precise trap when a retiring load or store touches the range. Used for debuggers, for kernel guard words (a canary beside a critical structure) and for detecting a write to a read-mostly structure.

**Where it runs.** Retire (the address is already in the ROB entry from the load/store unit).

**Why precise exceptions or OoO make it cheap.** The compare happens at retire against the stored address, so wrong-path accesses never trigger it and the trap is precise by construction. In an in-order core, the compare is at the memory stage and the trap is already precise.

**Precedent.** x86 debug registers DR0-DR3 and ARM debug watchpoints *(from memory, not confirmed)*. ARM reports some watchpoints after the instruction completes with the address in a register *(from memory, not confirmed)*. RISC-V Sdtrig *(from memory, not confirmed)*.

**Novelty.** Exists. The security use (kernel canary guard) is not new.

**Cost.** Per comparator: two 39-bit registers (base, limit) and flags; context-saved if per-thread. A few hundred gates for four.

**Fit with the priorities.** P1: a cheap way to catch a stray write. P6: `ptrace` and debuggers pleasant.

**OpenBSD fit.** `ptrace` and `ddb(4)` can use it.

**Verdict: Adopt.**

agree, do it.

**17. The restart contract (blind restart, restartable system calls).**

**What it does.** State as architecture: every abort and progress exception leaves `EPC` at the instruction to re-execute, and `RTI` with `EPC` unchanged is always correct, with no handler knowledge of what the instruction was. A system call interrupted by a signal returns to the `TRAP` instruction itself, so a restart is `RTI`; a call that must not restart sets the result register and advances `EPC`. `EPC`, `EPSW`, `EVA`, `ECAUSE` are written once, at retire, atomically, so there is no window in which they are half updated.

**Where it runs.** Retire.

**Why precise exceptions or OoO make it cheap.** Exceptions are taken only at retire, in order, one at a time; there is nothing to un-speculate. The register side effect of the one memory operand is buffered to retire (ISA 7.2), so there is nothing to undo. This is the property the other items depend on.

**Precedent.** Linux restarts system calls by rewinding the saved PC by the call instruction's length (`ERESTARTSYS` family) *(from memory, not confirmed)*; the PDP-11 `MMR1`/`MMR2` protocol required the handler to undo side effects (ISA 7.2). x86 `RIP` points to the faulting instruction for faults.

**Novelty.** None; a consistent statement of what exists.

**Cost.** Zero gates. Text in ISA 7; the OS work is the signal-return path.

**Fit with the priorities.** P1: "restart and recovery go together" is this contract. P3 none.

**OpenBSD fit.** Simplifies `userret` and `ERESTART` handling.

**Verdict: Adopt.**

agree, do it

**18. `UA` window that closes itself.**

**What it does.** `UA` (errata 43) is a `PSW` bit that stays set until `clua`. Add a one-access form: an instruction prefix or `copyin`/`copyout` forms that open `UA` for exactly one memory operand and close it at retire. A kernel bug between `stua` and `clua` cannot reach user memory.

**Where it runs.** Decode (the bit is an operand attribute of the instruction), retire.

**Why precise exceptions or OoO make it cheap.** The permission travels in the ROB entry with the instruction, so there is no architectural window to leak across an interrupt or fault: `UA` is already cleared on exception entry (errata 43). Out of order, a mode bit changed by an instruction in flight is awkward (it serialises); a per-instruction attribute is not.

**Precedent.** x86 SMAP with `STAC`/`CLAC` windows; ARM PAN with unprivileged `LDTR`/`STTR` forms that perform one access as user *(from memory, not confirmed)*. The `LDTR` form is the per-instruction model.

**Novelty.** Exists on ARM. Nothing new.

**Cost.** Page-2 or `MESC` forms for load/store as user; one gate. Removes the `stua`/`clua` pair around every copy loop (two instructions).

**Fit with the priorities.** P1: shrinks the window to one access. P2: fewer instructions per copy. Possible conflict: the 4-byte `MBLK` copy forms would need a user-side variant.

**OpenBSD fit.** `copyin`, `copyout` and `copyinstr` assembly (`openbsd/sys/arch/arm64/arm64/copy.S`, present) would use it.

**Verdict: Study.**

study, but i'm leaning toward it. i want a solid proposal.

**19. User-visible transactional region.**

**What it does.** `BEGIN`/`COMMIT` in user mode makes a short region atomic using the ROB and store buffer as the checkpoint.

**Where it runs.** Retire and cache.

**Why precise exceptions or OoO make it cheap.** The ROB already holds a rollback point; extending it is cheap on paper.

**Precedent.** Intel TSX shipped, was repeatedly disabled by microcode and later removed on many parts because of a transactional-asynchronous-abort data leak (TAA) and other flaws *(from memory, not confirmed)*. IBM POWER8/9 HTM and z/Architecture TX exist *(from memory, not confirmed)*. The repo excludes it (ISA 17.5).

**Novelty.** Exists.

**Cost.** Capacity aborts, a fallback path in every user of it, and a new speculative window that C1 and C5 in hardware-vulnerabilities.md would have to cover.

**Fit with the priorities.** P1 conflict: more recovery code and a new leak class.

**OpenBSD fit.** OpenBSD disabled TSX on affected parts *(from memory, not confirmed)*.

**Verdict: Reject.** Recorded so the question is not reopened without cause.

agree. reject.

## Combinations no one ships

1. **Colour plus reserved colours plus precise restart (items 1, 2, 17).** Allocation colours, an "unwritten" colour and a "freed" colour, all faulting synchronously and precisely, with a handler that can fix and resume. MTE ships the first piece, asynchronous by default; the others are software tools. The story: every heap error is a deterministic fault at the offending instruction, and `malloc` zeroing is initialisation.
2. **Landing pad at the branch plus the return predictor as shadow (items 5, 6).** Forward-edge and back-edge control flow checked by comparators the front end already needs, with a fault that names the offending branch. No shipping CPU is known to attribute the fault to the source.
3. **Secret taint plus retire-gated visibility plus `DIT` (items 11, 12 and R-8).** Constant-time code verified by the hardware, with the speculative window closed for domains that ask. Both halves exist as research; the pairing in an architecture with a defined per-domain bit is not known to ship.
4. **Precise reads everywhere (items 15, 14, 17).** ECC and parity errors, residue mismatches and bus faults all arrive as precise, restartable aborts; only posted writes are imprecise. The OS needs one error path.
5. **Syscall page bit plus landing pads plus execute-only (items 8, 5, and openbsd-mitigations.md idea 1).** Three one-bit page attributes that together give a W^X, pinned-syscall, pad-gated user space, with zero opcodes.

## What to measure first

All with `sim64` (`<repo>/sim64/`, `tests/sim/`) and the compiled corpus in `docs/codegen-data` (BearSSL, c-testsuite and others; `totals.csv` lists the corpora).


sim64 is nice, but we should get the qemu backend working too.

1. **`BVS`/`BVC` sites and `ADD`/`SUB`/`MUL` followed by them (item 9).** Count them per corpus. If under 1% of instructions, `TRAPV` is not worth an opcode.
2. **Stores smaller than 16 bytes into fresh `malloc` memory, and `MSET`/`bzero` coverage (items 1, 2).** The share of first-touch stores that would fault under the "colour 0" rule.
3. **Indirect `JMP`, `CALLI`, `JTAG` targets: how many are address-taken functions (item 5).** The corpus shows `calli` 451 and `jmp` 658 of 336,408 instructions (ooo-readiness.md 6.14); count the distinct targets and so the `LPAD` byte cost.
4. **`CALL`/`RET` pairing in the corpus and in kernel code (item 6).** Count `longjmp`, exception unwinding and stack switching sites; each is shadow-stack recovery code.
5. **Largest `SP` adjustment and maximum depth (item 4).** Frames larger than a page would skip a guard page; a limit register helps only if they exist.
6. **`stua`/`clua` pairs per copy routine in the kernel assembly corpus (item 18)** under `docs/codegen-data/kernelasm`.

once qemu and sim64 are working, and we do the openbsd port, we can test each choice individually for performance. and we will. put that on the roadmap.

7. **Variable-latency instruction use with operands that are tainted (item 11):** run BearSSL under a software taint model in `sim64` and count false positives.
