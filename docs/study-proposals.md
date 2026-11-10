# Study proposals: shadow stack, checked arithmetic, poison, taint, strict domain, self-closing user access, 64-bit capabilities

[← pdp64 index](../README.md)

For the author's annotation. Items 6, 9, 10, 11, 12 and 18 are those of `retire-stage-candidates.md`; the capability question is its item 3. Each section gives a concrete design scored against the definitive priority list (errata 83): **P1** security and safety, **P2** opcode choice (fewer instructions executed), **P3** encoding, **P4** speed and power (gate count), **P5** compiler target, **P6** assembler. The design is out-of-order ready; the first in-order core pays almost nothing for any of it.

**Sourcing.** Facts about pdp64 are from the repository (paths given). Facts about OpenBSD marked *(read)* are from `<work>/kernel-src/openbsd`. Everything else outside the repository is *(from memory, not confirmed)*. No performance number for another machine was read for this text; none is quoted as fact.

## Common ground: where the new state lives

Six of the seven sections need a little new state and a few encodings. They are collected here so that the sections can refer to them and so that no two sections claim the same slot. Every number is a proposal; the grammar (`spec/pdp64-mnemonics.hbnf`) is where numbers are finally written.

**Per-register metadata, saved for free.** `EPSW` is stored by `PUSHX` as a full 8-byte word (ISA 4.11) but only the 16-bit `PSW` is defined in it. The remaining 48 bits are three 16-bit masks, one bit per register `R0` to `R15`: **PMASK** (bits 31..16, poisoned, item 10), **SMASK** (47..32, secret, item 11), **VMASK** (63..48, valid pointer, item 3). The live copies are three 16-bit registers (three bits per physical register in an out-of-order core). Exception and interrupt entry moves the live masks into `EPSW` and clears them, so a handler can save registers with ordinary stores without tripping a poison or secret check; `RTI` restores them. Context switch, `PUSHX`/`POPX`, signal frames and `fork` carry the masks with no new instruction, because the word is already saved. This is the author's "a bit in a saved register is free", used three times. `PSW` bits 12 (`UA`, decided) and 13 (`DIT`, proposed in architecture-recommendations R-8) are taken; bits 14 and 15 become **FP** and **FS**, the poison and secret flags of the condition codes (items 10, 11).

**Per-domain control.** One new system register **DOMCTL** (`MFSR`/`MTSR` register number to be chosen; the 8-bit number space has room, ISA 4.11), written by the kernel with `PTBR` and `ASID` at a context switch: `USTRICT`, `KSTRICT` (item 12), `SSU`, `SSK` (item 6), `PTRREQ` (item 3). Not exception-saved: it is a property of the address space, like `PTBR`.

**Page-table entry.** The entry defines bits 0..9 and 12..39 (system architecture, page-table entry); bits 10, 11 and 40..63 must be zero. The proposals ask for: `SS` (shadow page, item 6), `SEC` (secret page, item 11), `NS` (no speculative forwarding, item 12), `NOTAG` (no side-band, item 3). Together with `SYS` (item 8) and the landing-pad bit (item 5) that is six bits; bits 10, 11 and 40 upward are enough. Allocation to be chosen.

**Fault vectors.** Vectors 16 to 31 are reserved. Proposed: 16 `CHECK` (item 9), 17 `POISON` (10), 18 `SECRET` (11), 19 `SHADOW` (6), 20 `NOTPTR`/bounds (3).

**Free encoding space actually found** (ISA 4.4 to 4.18): `SYSX` (class 0, minor 15) sub-opcodes 0 to 5 are used (`PUSHX`, `POPX`, `ISYNC`, `HINT`, `STUA`, `CLUA`), 6 to 255 are free; page 2 has `0x0F` and `0x2E` to `0x3F` reserved (19 slots), and a page-2 form must abbreviate a page-1 instruction (ISA 4.18); `AESC` uses sub-opcodes 0 to 4, `0x08`, `0x10` to `0x13`, `0x20`, so about 240 are free and the layout gives three registers plus a condition nibble; `MESC` has 4 spare of 16 sub-opcodes; `MBLK` has 7 of 256 sub-opcodes and a 4-bit `flags` field in parcel 1 whose bits are not assigned (ISA 4.7 diagram, grammar line 137); addressing modes `1000` to `1111` are reserved (ISA 5); top-level `0x23` and `0x2B` to `0x2F` are reserved and the ISA reserves them for register-to-register common cases (ISA 4.3, 12.2), so none is requested. `SOP` and `SYS` classes are full.

## Item 3 (the author's question). Capabilities with 64-bit pointers

**Question.** Can the CHERI idea (unforgeable, bounded pointers) be had with 64-bit pointers by attaching flags to each register outside the 64 usable bits, instead of doubling every pointer to 128 bits?

**Proposal.** Yes in part, and the part is useful. Split CHERI into three guarantees and price each separately.

1. **Provenance (a valid-pointer tag).** One tag bit **V** per register (VMASK, above) and one per naturally aligned 8-byte word of memory (a side band like ECC, or a carve-out table with a tag cache). Only pointer-producing operations set V; any ordinary store that overlaps any byte of a word clears that word's V. Natural alignment (errata 82) is what makes a per-8-byte tag exact: an aligned quad store covers exactly one tag, a narrower store clears it, and only the explicit unaligned forms (`MOVUQ`) straddle two tags and clear both. An integer written over a pointer can no longer be dereferenced, jumped to or returned through.
2. **Bounds in the 21 spare bits.** Item 1 (approved) puts a 4-bit colour in bits 63..60 and leaves bits 59..39 as 21 sign bits. For a V-tagged value those 21 bits become a compressed-bounds field, so the pointer stays 64 bits. Proposed split: exponent `E` 5 bits, bottom `B` 7 bits, top `T` 7 bits, 2 spare. Bounds are `[base, top)` with granularity `2^E` and a 7-bit mantissa, as in CHERI Concentrate *(from memory, not confirmed)* but with a 7-bit instead of a 14-bit mantissa. Consequence for the allocator: an object up to 128 bytes has exact bounds; a larger object of size `S` has its base and top rounded to `2^E` with `2^E >= S/128`, so padding is at most about 1/64 of the size (1.6%) and alignment is at most `S/128` (a 64 KB object 512-byte aligned; `malloc` already page-aligns what it takes from `mmap`). Stack arrays and globals whose address escapes need the same alignment from the compiler and linker, which is the cost that the CHERI LLVM port pays too *(from memory, not confirmed)*. The pure low-fat variant (size class and bounds implicit in the address, Duck and Yap) needs no field at all but fixes bounds at a power-of-two block, so internal waste averages about a quarter *(from memory, not confirmed)* and the 512 GB address space must be carved into per-class regions; the compressed field is the better use of 21 free bits.
3. **Not obtainable in 64 bits: exact, arbitrary bounds; permissions and object types in the pointer; sealing.** These need about 64 more bits per pointer *in memory*. A register half can hold them (16 more 64-bit halves is a doubled register file, cheap in gates as the author says); a pointer spilled to the stack or stored in a struct cannot, without a second 8 bytes per pointer, which is CHERI-128 again, or a table keyed by the pointer's location, which is Intel MPX.

**Instructions.** All new instructions are register-to-register and rare, so they live in escape groups (ISA 4.3). Mnemonics and numbers are allocation to be chosen.

| Mnemonic | Operands | Semantics | Bytes |
|---|---|---|---|
| `PDERIVE` | `Rs, Rn, Rd` | `Rd` = `Rs` with bounds narrowed to `[Rs.addr, Rs.addr + Rn)`, rounded outward to the representable grid but clamped inside `Rs`'s bounds; V=1 only if `Rs` is V; else fault `NOTPTR` | 4 (`BESC`) |
| `PSTRIP` | `Rs, Rd` | `Rd` = sign extension of address bits 38..0, V=0 (pointer to integer) | 4 (`BESC`) |
| `PGETBASE`, `PGETLEN` | `Rs, Rd` | decode bounds into integers | 4 (`BESC`) |
| `PMAKE` | `Rs, Rd` | privileged: set V on `Rd` (kernel returning an `mmap` result, the dynamic linker through a root pointer the kernel provides at `exec`) | 4 (`SYSX`) |

Existing instructions change meaning only for V-tagged operands: `ADD`/`SUB`/`LEA` with one V operand and one integer leave the metadata untouched and add to the 39-bit address field (the result stays V only while the address is within the representable region, else V is cleared); `AND` with a small mask (alignment) likewise; all other ALU operations clear V and treat the register as a 64-bit integer; `CMP` between a V operand and anything compares the sign-extended 39-bit addresses, so two views of one object compare equal; `MOVQ` and `PUSH`/`POP`/`PUSHM`/`POPM`/`CAS`/`SWAP` (quad transfers) copy V between register and memory word; every narrower store, `MSET`, and every device or DMA write clears the word's V; `MCPY`/`MMOV` copy V when source, destination and count are all multiples of 8 and aligned, else they clear it. Dereference, jump and call through a V-tagged register checks the address against the decoded bounds at address generation (a pending fault in the reorder-buffer entry, raised at retire, `ECAUSE` 20).

**Tag clearing on DMA and device writes.** Two ways. (i) The memory controller clears the side-band bit of every 8-byte word that a non-core initiator writes, which needs a read-modify-write on the tag table or a tag cache at the controller. (ii) The simpler rule: pages given to devices (and all device-typed pages) are `NOTAG` pages, loads from them return V=0 and a pointer store into one faults. The IOMMU already gives each device a domain (F25), so (ii) costs one page bit and no controller logic. Swap-out and core files must save or drop the tag bits; a page-in restores them; the kernel's `copyout` of a pointer array (`argv`) builds pointers with `PMAKE`.

**Which CHERI guarantees are lost.** (a) *Monotonic derivation* survives (`PDERIVE` never widens) but only to the representable grid; `uintptr_t` round trips through an integer clear V, so software that hides pointers in integers (XOR lists, hash of address, tag-and-mask) must keep them as pointers or be re-derived by the kernel. (b) *Sealing and object types*: lost, no bits for them. (c) *Permissions per pointer*: lost; page permissions (`R`, `W`, `X`) remain and are checked as today. (d) *Provenance of exact sub-object bounds* (`sizeof` of a field smaller than the grid at large `S`): rounded outward, so a field inside a 64 KB object is not individually bounded below 512 bytes. (e) *Revocation*: kept. With V tags in memory and bounds in the pointer, a sweep can find every pointer into a freed region (CHERI revocation, Cornucopia *(from memory, not confirmed)*); together with items 1 and 2 (colour and "freed" colour) that gives temporal safety without a sweep for the common case.

**The canonical-address rule (ISA 6.1.1, 6.2).** Today an address whose bits 63..39 differ from bit 38 aborts with `NONCANON`, and 6.2 says high bits are "architecturally refused" to software. With item 1 the rule is already 63..60 colour, 59..39 equal to bit 38. New rule: *if the address register's V bit is 0 the 59..39 bits must equal bit 38, as now; if V is 1 they are the bounds field and the effective address is the sign extension of bits 38..0.* The benefit of the old rule, that no program can stash its own data up there, is kept for every integer and every untagged pointer, and extended: a program cannot forge the field because it cannot set V. What is spent is the old rule's second benefit, a free path to a 4-level, 48-bit address space: widening later leaves 12 spare bits and breaks the bounds field. The field should carry a version in the feature register, and the widening becomes an ABI version change.

**Faults and recovery.** `NOTPTR` (a V=0 register used as an address while `DOMCTL.PTRREQ` is set) and bounds violations are precise aborts; `EVA` holds the offending address; a handler can fix up and `RTI`, but the normal action is to kill the process. `PTRREQ` is per address space and off for ABI 1, so existing binaries run unchanged and mixed binaries are possible: the check is a domain switch, not a mode that changes what any instruction means.

**Cost.** Gates: 3 bits per physical register, a 39-bit decode-and-compare per address-generation unit (roughly two adders plus a comparator), a tag path in the data cache (1 bit per 8 bytes, 1.6% of memory, 8 bits per 64-byte line). Memory: 1.6% (V) and unchanged pointer size, against a doubled pointer for CHERI-128. Opcodes: five escape sub-opcodes, no top-level opcode. OS: `mmap` returns V pointers; the dynamic linker and `malloc` use `PDERIVE`; `pmap` stores tag bits at swap; a handful of kernel sites use `PMAKE`. ABI 2.

**Precedent and what went wrong.** CHERI and Arm Morello: 128-bit capabilities, hidden tag; software that stores pointers in integers breaks; porting cost is mostly pointer size *(from memory, not confirmed)*. CHERI-64 exists for 32-bit address spaces (32-bit address plus 32 bits of metadata) *(from memory, not confirmed)*: this proposal is the same idea at 39 plus 25. Intel MPX failed for the reasons listed in the candidate document: four bounds registers, a two-level bounds table keyed by the pointer's location, non-atomic update of pointer and bounds under threads, stale bounds when unaware code moved the pointer, and a large slowdown; GCC and Linux removed support *(from memory, not confirmed)*. The in-pointer field avoids all of those because the bounds travel with the pointer through every store, copy and atomic.

**Fit with the priorities.** P1 high: forged and corrupted pointers cannot be used (V), out-of-bounds access is detected at the access, and V gives a return-address check for free (item 6, below). P3 good (no change to instruction encoding beyond escapes). P4 moderate (the tag path and bounds decode). P5 cost: the compiler and linker must align escaping objects; `uintptr_t` discipline. P6 neutral.

**Staged path.** *Stage 0 (now, costs nothing):* reserve VMASK in `EPSW`, the `NOTAG` page bit, vector 20, and write the canonical-address rule as above without enabling it. *Stage 1:* V tag in registers and memory; no bounds; `PTRREQ` for new binaries. This alone gives pointer integrity (a hardware analogue of item 7's PAC, deterministic instead of probabilistic) and the return-address check. *Stage 2:* the bounds field with colour; allocator and linker rules. *Stage 3:* revocation sweeps. **Recommended minimal design:** stage 1 with the field layout reserved, stage 2 decided after the allocator measurement below. **Measurement:** in the compiled corpus count objects (stack, global, `malloc` call sizes from a traced run of lua and BearSSL) above 128 bytes whose size is not a multiple of the grid, to get the real padding cost; count `ptrtoint`/`inttoptr` sites to size the `uintptr_t` problem.

**Open choices for the author.** Mantissa width versus colour bits (7+7 with a 4-bit colour as above, or drop the colour from V pointers and use 9+9). Whether `CMP` of pointers compares addresses only (proposed). Whether the 25 bits are used in full or 9 are held back for a 48-bit address space. Whether stage 1 is wanted before stage 2.

**Your annotations:**

what would it cost for us to do the full 128 bits? if we just widen our 16 registers then that is ok.

## Item 6. The return predictor as the shadow stack

**Question.** How is the shadow stack made so that `setjmp`, `longjmp`, C++ unwinding, a coroutine or context switch, signal return and `fork` cost the fewest instructions and no recovery code?

**Proposal.** The real problem of CET, GCS and Zicfiss is that the shadow stack has its *own pointer*, a second register that every operation that moves the stack must also move. Remove the register. **Mirror shadow stack:** the shadow copy of the return address stored at data-stack address `A` lives at the fixed alias `A xor 2^37` (bit 37 of the virtual address flipped; the result is canonical in both halves). `CALL` and `CALLI` push as now and also store the return address at the alias of the slot just written; `RET` pops as now, loads the alias of the slot, and faults if the two words differ. Because the shadow location is a function of the data-stack slot, anything that moves `SP` (`longjmp`, unwinding, a stack switch, a signal, `fork`) moves the shadow with it, and **no shadow repair exists at all**: zero instructions in `setjmp`, zero in `longjmp`, zero in a context switch.

Rules that make it safe:
- *Alias pages* carry the `SS` page type: readable by ordinary loads (unwinders and debuggers can walk the mirror), writable only by `CALL`/`CALLI` and, in kernel mode, by the kernel's signal and exec code. An ordinary store faults (protection, vector 11). An attacker with an arbitrary integer-write primitive can overwrite the data-stack return slot but not its alias, so `RET` faults.
- *Stack pivot.* `RET` with `SP` pointing outside a stack arena finds no `SS` page at the alias and faults; the same holds for `CALL`. OpenBSD already requires that the stack pointer lie in a `MAP_STACK` mapping at faults and system calls (read: `uvm/uvm_map.c` "Stack must be in a MAP_STACK entry"), so allocating the alias with the stack is the same rule.
- *Arena constraint.* Stacks live in the half of the user space with bit 37 clear (128 GB); the alias is the other half. The kernel allocates the alias pages lazily: a `CALL` that stores to an absent alias page takes an ordinary store page fault, the handler maps a zero `SS` page and `RTI` re-executes the `CALL` (restartable, precise).
- *Enable.* `DOMCTL.SSU` / `SSK` per address space. Off for ABI 1; with it on, `CALL`/`RET` through a page without an alias fault. No per-thread state, no mode that changes any other instruction.
- *Stale entries.* Aliases of dead frames keep old values. A pivot of `SP` onto a stale slot could return to an earlier valid return site; that needs a stack-pointer-control primitive, stronger than the overwrite the check defends. Option: `RET` also zeroes the alias after a successful compare (one more store to a line just read), making each entry use-once; off by default (power), a `DOMCTL` bit if the author wants it.
- *Predictor role.* The return-address stack stays microarchitectural; it supplies the predicted target. At execute the loaded word and the alias word are compared; **a mismatch never redirects fetch to the loaded value** (the attacker's address is not fetched even speculatively, which also meets rule C16), the fault is pending in the reorder-buffer entry and raised at retire.

**Instructions.** None new for the mirror. The semantic change is to existing `CALL` (`SOP` `D`), `CALLI` (`XFER` 1) and `RET` (`SYS` minor 3). Stage 2 only: `SSSTORE Ra, Rv` (privileged `SYSX` sub-opcode, 4 bytes) writes `Rv` to the alias of `Ra`, for the kernel's signal frame and first-run thread frame.

**Sequences.** `R0` holds the buffer. The jump buffer holds `PC`, `SP`, `R8`-`R11`, `R13`, `R15` (8 words; `R12` is caller-saved).

```
setjmp: MOVQ  (SP), R1          ; return address              2   page-2 load
        LEA   8(SP), R2         ; SP after the return         2   page-2 LEA
        MOVQ  R1, (R0)          ;                             2
        MOVQ  R2, 8(R0)         ;                             2
        MOVQ  R8, 16(R0)        ; ... R9, R10, R11, R13, R15  4 each (6 stores, 24 bytes)
        CLR   R0                ;                             2
        RET                     ;                             2   alias checked as for any return
                                ; shadow stack: 0 instructions
longjmp: MOVQ (R0), R2          ; PC                          2   R0 = buf, R1 = value
         MOVQ 8(R0), SP         ; SP; the shadow follows      4
         MOVQ 16(R0), R8        ; ... six loads               4 each
         TST  R1                ;                             2
         BNE  1f                ;                             2
         MOVQ #1, R1            ;                             2
1:       MOVQ R1, R0            ;                             2
         JMP  (R2)              ; indirect jump, not a RET    2   target has an LPAD (compiler inserts one after a call to a returns-twice function)
                                ; shadow stack: 0 instructions
swtch:  PUSHM #0xAF             ; R8-R11,R13,R15 (page-2 PUSHM8) 2   R0 = &old_sp, R1 = &new_sp
        MOVQ  SP, (R0)          ;                             2
        MOVQ  (R1), SP          ;                             4   new stack, new shadow
        POPM  #0xAF             ;                             2
        RET                     ; resumes the other context   2   its alias was written when it called swtch
```
A brand-new context starts with `CALL entry` from a small stub on the new stack, so its first return slot is written by hardware and no forged frame is needed. C++ unwinding: the unwinder sets `SP` to the target frame and `JMP`s to the landing pad; nothing else. Signal return: the kernel writes the frame (the alias of the trampoline return slot by the stage-2 `SSSTORE` or by kernel-mode store to a user `SS` page) and `sigreturn` restores registers from the frame as now. `fork` and `rfork` copy both halves.

**The dense alternative, for comparison.** A separate shadow stack with a pointer `SSP` (a 64-bit register in the saved context) is 8 bytes per call instead of one alias page per stack page, which costs 4 to 8 times less memory and cache. To keep `setjmp` at one instruction it needs two `MESC` sub-opcodes (2 of the 4 spare): `SSSAVE m` stores `SSP` to the buffer, `SSREST m` loads it with the checks *new SSP >= current SSP, 8-aligned, inside the same shadow region*. `longjmp`'s repair is then one instruction. Switching between shadow stacks (a coroutine switch) still needs a validated token on the target (the Intel design, *from memory, not confirmed*), which is the recovery code the mirror avoids, and unwinding by more than one frame needs the same instruction. It is the fallback if the mirror's memory or cache cost measures badly.

**Faults and recovery.** Mismatch, a missing alias page at `RET`, or a store to an `SS` page: precise abort, vector 19 (`SHADOW`) or 11; `EPC` is the `RET`, `EVA` the loaded (attacker) address. The handler kills the process. A blind restart re-faults, which is correct: nothing repairs a forged slot. The alias is architectural; the return-address stack, early compare and prefetch of the alias line are implementation choices.

**Cost.** Gates: one address-bit flip, a 64-bit equality compare (about 100 to 150 gates), one more store per `CALL` and one more load per `RET` (same count as the dense design, spread over twice the lines). Bits: one system-register field, one page bit. Memory: up to one alias page per stack page that holds a return slot (stack pages are a small share of memory; the dense design avoids this). OS: allocate the alias with each `MAP_STACK`, an alias-fill fault path (a few lines), signal frames, `ptrace` pokes into a stack slot update the alias (debugger-injected calls). Opcodes: none. **Measurement:** dynamic `CALL`+`RET` count (static `call` is 31,620 of 370,115 instructions in the corpus, ooo-readiness 6.14 counts `calli`), stack footprint of the long runs, L1 hit rate of the alias line in the `sim64` cache model once it has one.

**Precedent and what went wrong.** Intel CET, Arm GCS and RISC-V Zicfiss all keep a separate shadow-stack pointer and need operating-system work for `setjmp`/`longjmp`, signals, threads and stack switching (read: `linux/Documentation/arch/arm64/gcs.rst`, `x86/shstk.rst`, the retire-stage candidate document). OpenBSD's analysis called a shadow stack the largest source of recovery code (openbsd-mitigations.md idea 4, option B). The mirror removes the cause (a second pointer); the price moved to memory.

**Fit with the priorities.** P1: strongest return protection, and the only one here with no recovery code, so it meets "cheap to recover" by having nothing to recover. P2: `setjmp`, `longjmp`, switch gain no instruction. P4: a compare and a second line touched per call; the in-order core pays one extra cycle per `CALL` and `RET`. P5: nothing to emit. P6: nothing.

**Open choices for the author.** Mirror (recommended) or dense. Use-once zeroing at `RET`. `SSK` for the kernel stacks too (recommended: the same mechanism). Bit 37 versus a configurable offset register. Whether item 3's V tag replaces the mirror: with stage 1 of item 3 a return slot written by an integer store has V=0 and `RET` can fault on V=0 with no alias memory at all, at the price of tag memory and with the weaker guarantee that a copied valid pointer is accepted.


i approve the mirror, didn't understand what dense did differently.  i acccept your recommendations; does this give the same protections as cheri? if so, we can reject the cheri stuff unless any of it can provide benefit without significant cost.

**Your annotations:**

## Item 9. Overflow-trapping arithmetic

**Question.** Which checked forms, what encoding, and what fault, so that clang `-ftrapv`, `__builtin_*_overflow`, Rust, Swift and Ada checks cost the fewest instructions?

**Proposal.** One general instruction first, fused forms only if measured. The ISA already lists "enabled arithmetic traps" among the traps (ISA 7.1) and defines `V` as signed overflow (ISA 4.2), `C` as carry (add) or borrow (subtract), and `MUL` sets `V` when the signed product does not fit (manual `MUL`, flags; `C` unchanged).

| Mnemonic | Operands | Semantics | Bytes |
|---|---|---|---|
| `TRAPCC` | `cc` | if condition `cc` holds on the current flags, take trap `CHECK`; else nothing. `cc` numbered as the branch low nibble (ISA 4.4). Assembler aliases `TRAPV` (= `TRAPCC vs`), `TRAPC` (`cs`), `TRAPLT`, `TRAPHIS` and so on | 4 (`SYSX` sub-opcode 6, `cc` in the pad byte); 2 (page-2 `0x2E`, `cc` in `low`) |
| `ADDV`, `SUBV`, `MULV` | `Ra, Rb, Rd` | stage 2: `Rd` = `Ra` op `Rb`; if signed overflow, no register written, trap `CHECK` as an abort at the instruction | 4 (`AESC`, three sub-opcodes in the free range above `0x20`) |

`TRAPCC` fits the page-2 rule (it abbreviates a `SYSX` word exactly, as `PUSHX` and `HINT` do) and uses one of 19 free page-2 slots and one of 250 free `SYSX` sub-opcodes. It composes with every operand shape of `ADD`, `SUB`, `MUL`, `ADDM`, `NEG`, `INC`, `DEC`, `ASL`: `ADD #1, 8(R2); TRAPV` is 4 + 2 bytes and the add keeps its immediate and memory forms, which the register-only `AESC` fused forms cannot. It also checks things that are not overflow: `CMP R1, R2; TRAPHIS` is a bounds check with no branch and no out-of-line stub (Ada index checks, Java-style array checks, Rust slice indexing), and unsigned overflow (`ADD; TRAPC`). Where the fused three-register form wins (one instruction, non-destructive), a front end can fuse `ADD`+`TRAPCC` into one micro-operation; that is the coalescing the author wants without a new opcode. Fused `ADDV`/`SUBV`/`MULV` are stage 2, decided by the measurement.

**The fault.** A `TRAPCC` that fires takes a *trap* (ISA 7.1 category: completes, `EPC` = next instruction), vector 16 (`CHECK`), `EVA` = the address of the `TRAPCC` itself (the one case where a trap defines `EVA`, so the handler need not decode backwards from `EPC`). Restartable: `RTI` resumes after the check, so a handler that promotes a fixnum to a bignum (Lisp, Smalltalk) can repair the register and continue. The fused forms are aborts: `EPC` at the instruction, destination unwritten, so a blind restart re-faults unless the handler changed an operand. Precise in both: the condition comes from the flags written by older instructions, and in an out-of-order core the overflow travels in the reorder-buffer entry with the result, so a mis-speculated overflow never traps.

**Sequences.**

```
; C: long c = a + b;   clang -ftrapv        a in R1, b in R2
        MOVQ  R1, R0
        ADD   R2, R0                   ; sets V
        TRAPV                          ; 2 bytes, no handler code at the site
; Rust u64 checked add, overflow panics
        ADD   R2, R1
        TRAPC                          ; the panic location comes from a PC table, not from the instruction
; signed multiply
        MUL   R2, R1                   ; V set when the product does not fit
        TRAPV
; array bound   (R2 index, R3 length)
        CMP   R2, R3
        TRAPHIS                        ; trap if index >= length unsigned
```

**How compilers use it.** LLVM `llvm.sadd.with.overflow`, `ssub`, `smul` (clang `-ftrapv`, `-fsanitize=signed-integer-overflow -fsanitize-trap=...`, Rust debug overflow checks, Swift's default checked arithmetic) lower to the arithmetic instruction plus `TRAPCC vs` when the failure block only traps; unsigned variants use `cs`. Languages that must raise an exception (Ada `Constraint_Error`, Rust with a message) map the trap in the runtime's signal handler: OpenBSD i386, hppa and sparc64 already deliver integer-overflow traps as `SIGFPE` with `FPE_INTOVF` (read: `arch/i386/i386/trap.c`, `hppa/hppa/trap.c`, `sparc64/sparc64/trap.c`), and a message is looked up from the faulting `EVA`. Unsigned multiply overflow is not in the flags (`C` is unchanged by `MUL`): either define `C` for `MUL` as unsigned overflow (the multiplier already forms the high half for `MULH`) or use `MULHU` plus a test; this is an open choice below.

**Cost.** One AND gate and a mux on the flag select; one `SYSX` sub-opcode, one page-2 slot, one vector. No new state, no mode. ABI: none; `TRAPV` is emitted only by compilers asked for checks.

**Measurement that decides.** The corpus count of `BVS`/`BVC` is 0 (`instructions_used.csv` says the overflow builtins are not implemented), so it cannot size the use. Compile the same corpora with `-ftrapv` and `-fsanitize=signed-integer-overflow -fsanitize-trap=signed-integer-overflow` (and Rust's `overflow-checks`) and count (a) checked sites per 1000 instructions, (b) dynamic instructions and bytes with `ADD; TRAPV` against `ADD; BVS stub` (6 bytes plus a shared stub) in `sim64`. `TRAPCC` is justified if (b) shows a saving, which it does by construction (2 bytes against 4 to 6, one instruction against two); the number decides only whether `ADDV`/`SUBV`/`MULV` also earn `AESC` slots. In the gcc and clang `-Os` x86 reference lists `jo` is outside the 40 most frequent mnemonics (below 0.12%), so default builds use almost none; sanitiser builds are the target.

**Precedent and what went wrong.** MIPS `ADD` traps but compilers used `ADDU` everywhere, so it went unused; RISC-V left trapping arithmetic out citing the cheap branch; x86 `INTO` was removed in 64-bit mode; Alpha `ADDQ/V` and VAX integer-overflow enable exist *(all from memory, not confirmed)*. The lesson in the candidate document stands: the instruction survives only if a compiler's default or a major sanitiser uses it. This design avoids the MIPS trap by not making the arithmetic itself trap (no flavour of every `ADD`) and by being a conditional trap that costs two bytes and also replaces bounds-check branches.

**Fit with the priorities.** P1: overflow becomes a precise fault at a known address instead of a wrong answer. P2: fewer instructions and bytes than `BVS` plus a stub. P3: 2 bytes for a rare instruction. P4: negligible. P5: matches sanitiser output. P6: `TRAPV` reads naturally.

**Open choices for the author.** `TRAPCC` alone, or with the stage-2 fused forms. `C` of `MUL` (unsigned overflow, breaking "unchanged"). Whether a fired `TRAPCC` is a trap (recommended) or an abort. Whether `CBCC`-style fused compare-and-trap is wanted (not proposed: four bytes for what `CMP; TRAPCC` does in 4).

**Your annotations:**

with the fused forms. no need for cbcc style. how are trap and abort different?

## Item 10. Architectural poison bit per register

**Question.** What produces poison, what consumes it, where does it fault, how is it saved, and what does it buy over a precise trap?

**Proposal.** A third metadata bit per register (**P**, in PMASK) meaning "this value is the result of a failed operation; using it is an error". The author's remark holds: three bits per register, a handful of OR gates and a 16-bit saved word are small next to what the out-of-order core already tracks (ready bits, fault bits, the flags). The design below keeps poison inside a function body and makes its behaviour a rule.

**Producers (minimal set).**
1. `POISONCC cc, Rd` (`AESC`, next to `SET`; `cc` in `x`): if the condition holds, set P on `Rd` (the value is unchanged). `ADD R2,R1; POISONVS R1` is checked arithmetic whose failure surfaces where the value is *used*, so a chain `x = a+b; y = x*c; z = y-d` has one fault point instead of three `TRAPV`.
2. Deferred-fault loads: modes `1010` (`d(Rn)`) and `1011` (scaled index) on the seven load opcodes (`MOVQ`/`MOVL`/`MOVW`/`MOVB`/`MOVZ*`; the other opcodes treat these modes as illegal). Assembler spelling `MOVQ.S`. The load takes an ordinary precise fault on any translation, protection, alignment, non-canonical or bus failure, as always. The difference is who decides: the **kernel's fault handler**, on a fault from a deferred load, either repairs the cause and restarts (demand paging, copy on write) or, if the access is invalid, sets P in the saved `PMASK` for the destination register and advances `EPC`, instead of signalling the process. Hardware needs nothing beyond the bit; the policy has no corner cases to specify and no recovery code in the program. (Stage 2: a page bit marking guard pages and the null page lets hardware set P without trapping.)
3. Not producers: division by zero stays an abort (a sanitiser wants it at the source); alignment faults of ordinary loads stay aborts.

**Consumers and propagation (the whole rule).**
- *Data operations* (ALU, `MOV`, `LEA`, shifts, `SET`, `MULH`): the result's P is the OR of the P bits of the register sources. A memory source contributes nothing (memory carries no poison).
- *Writing the flags* from a poisoned source sets `PSW.FP`; a flag write from clean sources clears it. `SET cc` and the `AESC` selects propagate `FP` into the result.
- *Faults at use, vector 17 (`POISON`):* a poisoned register (or `FP`) as (a) a base or index of any load, store, atomic or `MBLK` pointer; (b) the data of a store, `PUSH`, `PUSHM` or atomic (so poison cannot be written to memory and lost); (c) the condition of a branch: any conditional branch with `FP` set, `CBCC`/`CBRR`/`SOB` with a poisoned register; (d) the target of `JMP`, `CALL` and `RET`. `EVA` holds the mask of poisoned source registers.
- *Not a fault:* `TRAP #n` (the kernel reads the poison mask from the saved `EPSW` and checks the argument registers of the call it is about to service: two instructions in the dispatcher, no hardware guess about which registers are arguments), `ISP Rs, Rd` (`AESC`: `Rd` = 1 if `Rs` is poisoned, else 0; a clean result; it is how recovery code tests), writing a register from a clean source (`CLR`, immediates, loads), and any instruction that does not read the poisoned register.

**Saving.** Poison does not go to memory. Registers poisoned in a trap frame travel in `EPSW` bits 31..16, so a context switch, a signal and `fork` cost no instruction. The ABI rule that keeps ordinary spills trivial: **callee-saved registers (`R8`-`R11`, `R13`, `R15`) are never poisoned at a call or return**, so `PUSHM`/`POPM`, `setjmp` and thread switches never see poison; poison may live in caller-saved registers across a call as an argument, and the callee faults at the first use that stores it. A compiler that must spill a poisoned value resolves it first (`ISP` and branch, or `TRAPCC`-style check). A memory-side poison bit (one per 8 bytes, as in item 3) is the alternative; it turns poison into pervasive data-flow tracking with DMA and cache cost and is not proposed for item 10 alone.

**Faults and recovery.** Abort at the consumer; `EPC` is the consumer, so `RTI` re-executes it; a handler that wants to continue clears the bit in `EPSW`'s `PMASK` (after substituting a value) and returns. A debugger sees the producer by walking back. The producing instruction never faults, so mis-speculated poison costs nothing: a poisoned value that does not retire raises no fault.

**What it buys over a precise trap.** (i) Hoisting a load above its guard (if-conversion, loop-invariant motion, software pipelining) without recovery code: the load either gives a value or poison, and a use of poison is the same fault the guard would have prevented. (ii) One fault point for a checked chain (fewer instructions, P2). (iii) A deterministic Spectre v1 form: a deferred bounds-checked address computation yields poison, not a branch the predictor can train, and speculation has nothing to forward (rule C1). (iv) Safe over-read in word-at-a-time loops (largely covered here by `MSCN`/`MCMP`, so small). (v) Fail-closed: a poisoned pointer cannot be dereferenced, a poisoned length cannot reach `MCPY`. The author's reasoning that an out-of-order core hoists loads dynamically is right for speed; the gain is safety and instruction count, not speed.

**Cost.** One bit per physical register, one OR per result, one check per address-generation and branch port; 16 bits of architectural state in `EPSW`, one bit in `PSW`. Opcodes: 2 `AESC` sub-opcodes, 4 reserved mode values; no top-level opcode. ABI: the callee-saved rule above. OS: the fault handler's deferral policy (about ten lines), the syscall dispatcher's mask test. First in-order core: a 16-bit register and OR gates, no precision issue.

**Precedent and what went wrong.** Itanium NaT bits: speculative loads `ld.s` produced a NaT; `chk.s` branched to compiler-generated recovery code; NaT bits spilled with `st8.spill`/`ld8.fill` through a collection register `UNAT`; any non-speculative use of a NaT took a "NaT consumption" fault *(all from memory, not confirmed)*. What went wrong: recovery blocks made code larger and compilers hard to write; hardware deferral of translation misses turned recoverable faults into NaT and then into double work; the spill/fill register complicated context switch and calling conventions. This design differs on all three: recovery is the kernel's (no `chk` blocks), deferral policy is software so nothing is turned into poison that the kernel could have repaired, and poison never reaches memory so there is no `UNAT`. IEEE NaN is the floating-point form, and the Mill's "not a result" is the nearest design *(from memory, not confirmed)*.

**Fit with the priorities.** P1: an error cannot be silently used. P2: fewer instructions for checked chains and no guard branches. P3: 2 sub-opcodes. P4: tiny. P5: modest, needs a compiler pass; the ABI rule is simple. P6: neutral.

**Open choices for the author.** Faulting on flag writes from poisoned sources instead of the `FP` bit (fewer states, fewer chains). Whether the deferred-load policy lives in the kernel (proposed) or hardware. Whether `TRAP #n` itself checks `R0`-`R5` (rejected: stale poison in unused argument registers would be a false fault).

**Your annotations:**

not sure how to make those choices. compress it down a bit so i can understand the choices and ramifications.

## Item 11. Secret taint with `DIT` enforcement

**Question.** How can the hardware verify constant-time code with no false positives, precisely and deterministically?

**Proposal.** Define *secret* operationally, so that the check is a rule, not a heuristic.

- **Introduction (only by declaration).** A register becomes secret (bit **S** in SMASK) only by `SECRET Rd` (`AESC`) or by a load from a page with the `SEC` bit. Nothing is guessed. `malloc` can mark key material (`MAP_CONCEAL` already exists in OpenBSD for "omit from dumps", read: `sys/mman.h`; the same flag can set `SEC`).
- **Propagation (one rule).** The result of every register-to-register operation, `LEA`, move and flag write has S equal to the OR of the S bits of its register sources. `CLR`, immediates and loads from non-`SEC` pages produce S=0. No other rule exists.
- **Removal (only by declaration).** `DECLASSIFY Rd` (`AESC`) clears S: the programmer states the value is now public (the final verdict of a MAC comparison is the usual case). Each site is one grep.
- **Enforcement.** With `PSW.DIT` = 1, a faulting use is a secret register (or `FS`) used as: (a) the base or index of a load, store, atomic or `MBLK` pointer; (b) the condition of a conditional branch (`FS`, or the register of `CBCC`/`CBRR`/`SOB`); (c) the target of `JMP`/`CALL`/`RET`; (d) the length of an `MBLK` operation (the duration is the length); (e) the divisor of `DIV`/`DIVU`/`MOD`/`MODU` (a zero divisor aborts, which is data-dependent control flow). Vector 18 (`SECRET`), precise abort at the use, `EPC` at the use, `EVA` the mask of secret sources.
- **`DIT` also fixes timing.** With `DIT` = 1 the divide and `MBLK` sequencers, `MUL`, shifts by register count and floating point run in fixed time (R-8; hardware-vulnerabilities section 4). Secret *data* operands of those are then safe by construction and are not faults; only the uses in the list above are, because they are channels no latency setting can hide. This is what removes the false-positive class: the hardware never faults on something it has already made constant-time.

**The theorem (for a run that retires without a `SECRET` fault, `DIT` on, `DIT`-honouring hardware).** The sequence of program counters, effective addresses, `MBLK` lengths, and zero-divisor outcomes does not depend on the values of the secret inputs. *Proof sketch:* by induction on retired instructions; every quantity in the sequence is a function of register values only through the uses (a) to (e), each of which faults if its register has S=1; and by the propagation rule every value that is a function of a secret input has S=1, except through memory. The memory exception is closed by the second rule below.

**Memory (the two stages).** *Stage 1:* a store of a secret register to a page that is not `SEC` faults (a secret may not leave registers except into a secret page), so the theorem holds. A constant-time routine with register pressure keeps spill slots on a `SEC` page (a per-thread secret scratch page reached through a base register or `d(DP)`). Everything loaded from the `SEC` page is secret, so *scratch must be dedicated to secrets*; that is a software rule, and it is why stage 1 is limited. *Stage 2:* a secret bit per 8-byte word in the same side band as item 3's V tag; stores copy S into memory, loads copy it back, so spills anywhere keep exact labels and the stage-1 store rule becomes unnecessary; DMA writes clear S. This is the one place where items 3 and 11 share hardware.

**What this cannot catch (false negatives), and why that is acceptable.**
1. A secret the programmer never declared (the label is the declaration; undeclared secrets are an audit problem, as today). `SECRET` and `SEC` pages make the declarations visible and few.
2. Channels that are not branches, addresses, lengths or divisors: port contention, frequency scaling (Hertzbleed, rule C10), cache state shared with another domain (rule C9), speculative leaks (item 12 and rule C1), data-dependent hardware that `DIT` fails to cover (an implementation bug that no software check sees).
3. Secrets that cross a store before stage 2 and are reloaded as public: forbidden by the stage-1 store fault, not silently lost.
4. Information flow through the *absence* of a fault or through traps other than the divisor (every trap is an address, branch or divisor use or not secret-dependent).

It is acceptable because the check is one-sided and exact on what it covers: it never rejects a program for something outside the list, never accepts a program that executes a listed use on a secret, and every fault is the same fault on every implementation.

**On the author's objection.** Faults happen only on syntactic dependence, which is predictable from the instruction stream alone: independent of caches, speculation, predictors, timing and the particular chip. A wrong-path branch on a secret never retires and never faults. The one case that some would call a false positive is a value that carries the secret syntactically but not in fact (`x = s & 0` then used as an index): it faults, deterministically, and the programmer writes `CLR` or `DECLASSIFY`. That is a design choice for exactness over precision of intent, and the corpus measurement below shows how often it occurs.

**Instructions.** `SECRET Rd`, `DECLASSIFY Rd`, both `AESC` (4 bytes, rare); the `SEC` page bit; `PSW.DIT`; `PSW.FS`.

**Sequences (constant-time conditional select, branchless; `R1` = secret condition 0/1, `R2` `R3` operands).**

```
        SECRET   R1              ; declared once, e.g. after loading the key into R1 from a SEC page
        NEG      R1              ; mask = 0 or all ones: S propagates
        MOVQ     R2, R4          ; R4 = a
        XOR      R3, R4          ; R4 = a ^ b            S(R4) = S(R2)|S(R3)
        AND      R1, R4          ;                        S = 1
        XOR      R3, R4          ; selected value, still secret
        ...
        DECLASSIFY R4            ; the programmer publishes the result
        TST      R4
        BNE      reject          ; legal now: FS = 0
; AES by table lookup:  MOVB  table(R5), R6   with S(R5) = 1  ->  SECRET fault at the load,
; exactly the S-box timing leak the rule exists to catch.
```

**Context switch and sharing.** SMASK is bits 47..32 of `EPSW`, saved with the trap frame at no cost; `FS` is `PSW` bit 15. `DIT` is `PSW` bit 13, set by user mode through `MTPS` (a user may only harden itself); exception entry clears it for the kernel handler unless `DOMCTL` says the kernel runs `DIT` (R-8 leaves this open). Poison (item 10), secret (this item) and valid-pointer (item 3) are three parallel one-bit labels per register and use the same save mechanism, the same two-instruction access in the kernel, and parallel wiring in the out-of-order core; none shares a bit, because the three have different faulting uses. A poisoned or secret register in one mask never affects the other.

**Cost.** Three bits per physical register in all, an OR per result, comparators on the address, branch and divisor uses (shared with items 10 and 3), 16 bits of saved state, two `AESC` sub-opcodes, one `PSW` bit, one page bit, one vector. Compiler: a `secret` qualifier or an attribute on key-holding functions, plus a spill-slot rule; libraries (`libressl`, BearSSL) can be checked by running their constant-time paths with `DIT` on.

**Measurement.** In `sim64`, a software model of exactly these rules (measurement 7 of the candidate list, now exact): run BearSSL's constant-time AES, ChaCha20 and `br_ec_c25519` with the key declared secret; the output is the number of faulting sites (each is a real leak or a needed `DECLASSIFY`), the spill count of secret values (how often stage 1's scratch page is needed on 16 registers) and the number of `s & 0`-style syntactic cases (the author's false-positive class).

**Precedent and what went wrong.** Arm `DIT`, Intel `DOITM`, RISC-V `Zkt` declare timing-safe instruction sets but check nothing; taint tracking is academic (STT, SPT, dynamic information-flow tracking hardware) *(from memory, not confirmed)*. Dynamic taint systems generally fail on over-tainting through implicit flows and memory, which is why the declaration-only introduction and the closed-world rule above are chosen.

**Fit with the priorities.** P1: a hardware-verified class of timing leaks, deterministic. P2: none. P3: rare instructions are 4 bytes. P4: small. P5: needs a qualifier. P6: neutral.

**Open choices for the author.** Stage 1 only, or stage 2 with item 3's side band. Whether `RET` and indirect-jump targets belong in the list (proposed: yes). Whether the kernel runs with `DIT` on. Whether `DECLASSIFY` is user-mode (proposed) or restricted by `DOMCTL`.

**Your annotations:**

i follow your leanings on these open choices.


## Item 12. Retire-gated visibility (a strict domain)

**Question.** What is gated, how is the domain chosen, what does it cost and how does it compose with predictor isolation?

**Proposal.** One architectural promise and two selectors.

**The promise.** In a strict domain, *no instruction that has not reached the visibility point (all older branches and faults resolved) changes any state shared across domains or observable by timing*: no cache fill, no replacement-state update, no TLB fill, no prefetch, no predictor or return-stack update. Data forwarding to dependent instructions is *not* restricted, because a dependent that would leak is itself a load, branch or prefetch, and each of those is gated by the same promise; a wrong-path chain never reaches the point, so it never becomes visible. Loads that hit are allowed to complete (their replacement update is deferred); loads that miss wait.

**Selectors.**
- *Per domain:* `DOMCTL.USTRICT` and `KSTRICT`, loaded by the kernel at a context switch together with `ASID`; the effective bit is chosen by the current mode, so exception entry needs no saved state. User mode may set `USTRICT` (a program asks to be protected); clearing it is a kernel operation. This is the `pledge`-style policy hook (a process that has called `pledge` or a sandbox runs strict).
- *Per page:* PTE bit `NS` ("no speculative forwarding"): a load from an `NS` page does not forward its data to any dependent until the load is non-speculative, whatever the domain. Secrets live on few pages (`MAP_CONCEAL` mappings; item 11's `SEC` pages). A speculative read of an `NS` page then cannot leak by any channel, including contention, and the cost falls only on loads from those pages. This is the cheaper and sharper tool for secrets; the domain bit is the broad one for untrusted code.

**What an implementation may do.** Any mechanism that keeps the promise: delay misses (delay-on-miss), buffer speculative fills in a separate structure and install at the point (InvisiSpec style), or run without speculation (legal, slow) *(designs from memory, not confirmed)*. A feature register reports whether the bit is honoured; software must not treat a core that ignores it as safe.

**Interplay with item 13.** Item 13 (predictor entries tagged by ASID and privilege, one clear instruction) stops an attacker *training* a victim's predictor; item 12 stops the victim's own speculation from *leaving a trace*. Spectre v2 needs both halves (poison the target, observe the fill); with 13 alone the victim's own mis-speculation can still leak, and with 12 alone another domain can still steer the victim. A strict domain therefore also implies that its predictors are updated only at retire and that on entry to a strict domain the kernel executes the item 13 clear. Neither stops contention channels (rule C5 and C6, no SMT between domains).

**Cost.** One system-register field, one page bit, gating logic in the cache fill and TLB fill paths, and a retire-pointer (the oldest unresolved branch) already present for precise exceptions. Performance cost falls only on strict domains and `NS` pages: *from memory, not confirmed*, the published delay and invisibility designs report slowdowns from a few percent to a few tens of percent depending on the threat model and workload; plan for 5 to 30 percent in a strict domain and zero elsewhere. Cost rises with branch-dense, miss-dense code (pointer chasing), falls for code that fits in L1. No pdp64 out-of-order model exists yet; the number cannot be measured until one does (`sim64` is in order).

**First in-order implementation.** Nothing. A non-pipelined, non-speculative core has no instruction that changes shared state before it is non-speculative, so the promise holds trivially; `DOMCTL` bits read as written; the feature register says "honoured, trivially". A pipelined in-order core with branch prediction must still check its instruction prefetch and any data prefetcher against the promise before claiming it.

**Faults and recovery.** None; no new exception. The domain bit is visible state (readable), saved with the address space.

**Precedent and what went wrong.** Delay-On-Miss, InvisiSpec, STT and related designs are academic; industry ships point fixes (IBRS, IBPB, SSBD, `LFENCE`) *(from memory, not confirmed)*. Known weakness of the academic line: speculative-interference attacks that use contention rather than state (Behnia et al.) *(from memory, not confirmed)*, which is why the promise is stated about state and the `NS` page tool exists as the stronger guard. Rule C4 asks for exactly an architectural per-domain switch.

**Fit with the priorities.** P1 strong against Spectre-class leaks; this is a "cannot arise" property in the strict domain. P2 none. P3 free (no encoding). P4 cost paid only where asked. P5 none; the compiler needs no change. P6 none.

**Open choices for the author.** Both selectors (proposed) or domain only. Whether the kernel runs strict by default (`KSTRICT`; OpenBSD style says yes). Whether `NS` implies the item 11 `SEC` semantics or stays independent.

**Your annotations:**

both. yes strict default. not sure about ns item 11, tell me more.


## Item 18. A user-access window that closes itself

**Question.** What is the exact self-closing form of `UA`, its encoding, its faults, and the kernel sequences?

**Existing mechanism (errata 43; ISA 4.11).** `PSW` bit 12 `UA`. With `UA` = 0 a kernel-mode data access (load, store, atomic, `MBLK` operand) to a page whose `U` bit is set takes the page permission abort; with `UA` = 1 it succeeds. `STUA` and `CLUA` (`SYSX` sub-opcodes 4 and 5, 4 bytes, privileged) set and clear it; entry clears it; `EPSW` keeps the old value; `RTI` restores it. `PROBER`/`PROBEW` ignore it. Today's copy routine is `STUA; MCPY; CLUA` plus the range check and the fault path's `CLUA`, and the window stays open across the whole kernel-side bookkeeping between the two.

**Proposal.** The tightest self-closing form is no window at all: **user access is an attribute of one memory operand.** The attribute travels with the instruction (in the reorder-buffer entry), so it cannot outlive it, cannot leak across an interrupt, and an `RTI` re-executes the instruction with the attribute attached.

1. *Scalar operands.* Addressing mode bit 3. Modes `1000`, `1001`, `1110`, `1111` are the user-access variants of base `d(Rn)`, scaled index, post-increment and pre-decrement (the reserved range is `1000` to `1111`, ISA 5; `1010`, `1011` are asked for by item 10, `1100`, `1101` stay reserved). Any instruction that has a memory operand (`MOVQ`, `MOVL`, `MOVW`, `MOVB`, `MOVZ*`, ALU with a memory source, `MESC`, atomics if their operand is a mode) accesses that operand with **user privilege**. Assembler: the `.U` suffix, `MOVQ.U (R0), R3`; the spelling is the author's.
2. *Block operands.* `MBLK` gets the `flags` nibble in parcel 1 (unassigned today): bit 0 = destination is a user address, bit 1 = source is a user address. Assembler aliases `MCPYIN Rd, Rs, Rn` (= `MCPY` with source user), `MCPYOUT`, `MSETU` (= `MSET`, destination user), `MCMPU`. `MMOV` and `MCPY` may take both bits (user to user; no kernel use). Other bits stay free for the streaming value of ISA open item 8.
3. *What "user privilege" means.* The access is checked as a user-mode access: the page must be present, have `U` = 1, and permit `R` (loads) or `W` (stores) as for user mode; a kernel page (`U` = 0) or any address in the kernel half takes a protection abort even if `UA` = 1, and the walker need not touch the kernel half (the architecture-recommendations walk rule: "in user mode the upper half is not walked at all"). It overrides `UA` for that operand only; with `UA` = 0 (the reset and entry value) the guard stays closed for every other access.
4. *Privilege.* Legal only in kernel and supervisor mode; in user mode the encoding is a privileged-instruction abort (vector 3), not a silent alias.

**Consequence: the range check disappears.** Today copy routines compare `addr + len` against `VM_MAXUSER_ADDRESS` and test the wrap (read: `arch/amd64/amd64/copy.S` `_copyin`, `arch/arm64/arm64/copy.S` `copyin`: `adds; b.cs; tst`). Here the hardware does it: a kernel address faults at the first byte, a copy that runs past the top of the user half crosses into non-canonical addresses and takes `NONCANON`, and a wrap past `2^64` cannot happen first. Every failure is a precise abort, with no TOCTOU between check and use.

**Sequences.**

```
; int copyin(const void *uaddr, void *kaddr, size_t len)    R0 = uaddr, R1 = kaddr, R2 = len
copyin: LEA     cf(PC), R3              ; 4   handler
        MOVQ    CURPCB(DP), R4          ; 4   kernel DP is the per-CPU pointer
        MOVQ    R3, PCB_ONFAULT(R4)     ; 4
        MCPYIN  R1, R0, R2              ; 4   source user; kernel destination keeps the guard
        CLR     PCB_ONFAULT(R4)         ; 4
        CLR     R0                      ; 2
        RET                             ; 2   7 instructions, 24 bytes, no STUA/CLUA, no range check
cf:     MOVQ    CURPCB(DP), R4
        CLR     PCB_ONFAULT(R4)
        MOVQ    #EFAULT, R0
        RET
; int copyin32(const void *uaddr, void *kaddr)
copyin32: ...; MOVL.U (R0), R3 ; MOVL R3, (R1) ; the alignment check of the arm64 routine is the ALIGN abort
; copyout is MCPYOUT R1, R0, R2 with R0 = kernel source, R1 = user destination
```
Option B, no `pcb_onfault` at all: because user-qualified instructions are the only kernel instructions allowed to fault on a user address, the trap handler can look `EPC` up in a table of fixup addresses in read-only kernel text and resume at the fixup. `copyin` becomes `MCPYIN; CLR R0; RET` (3 instructions) with the fixup `MOVQ #EFAULT, R0; RET`. OpenBSD's amd64 trap code already checks that `pcb_onfault` is one of a table of valid handlers (read: `amd64/trap.c`, `__nofault_start`), so a table is consistent with it. Hardware may set `ECAUSE` bit 15 (`UQ`) on an abort whose faulting access was user-qualified, so a fault on a user address from an unqualified instruction is a kernel bug the handler can name.

**Faults and recovery.** Abort, `EPC` at the instruction, `EVA` the user address, `ECAUSE` the ordinary cause (7, 8 page fault; 10, 11 protection; 4 `ALIGN`; 5 `NONCANON`; 13 `BUSFAULT`) with `UQ`. A not-present page that the kernel can fill (`uvm_fault`, copy on write) is resolved by the handler and `RTI` re-executes the instruction. **Composition with `MBLK` restarts (ISA 7.5):** progress is in `Rd`, `Rs`, `Rn`; `PC` addresses the `MBLK`; the attribute is part of the instruction word, so a resumption after a page fault, a timer interrupt or a preemption is the same instruction with the same attribute, and nothing needs saving. A copy that fails partway leaves the bytes copied in the kernel buffer and `Rn` = bytes left, which `uiomove`-style callers can use. Nothing in the `PSW` changes, so error paths need no `CLUA` and entry-clears-`UA` is unneeded by this path.

**Cost.** Gates: one mode decode bit and one mux in the privilege input of the permission check (about a dozen gates), one `U`-check bit in the memory request. Opcodes: none; four reserved mode values and two `flags` bits. ABI: none. OS: the copy routines get shorter; `ptrace`/`kcopy` unchanged. `STUA`/`CLUA` and `PSW.UA` become unused by the base system; keep them as decided (errata 43) until the port confirms, then the author may retire the bit (one fewer window, one `PSW` bit and two `SYSX` words freed).

**Measurement (kernel assembly corpus, `docs/codegen-data/kernelasm`).** `classified.csv` already counts the sites: x86 `stac` 35 and `clac` 53; arm64 unprivileged accesses 52 (`ldtr` 17, `sttr` 16, `ldtrb` 7, `sttrb` 6, `ldtrh` 3, `sttrh` 3); arm (32-bit) `ldrt`/`strt` family 453. OpenBSD's `amd64/copy.S` has 4 `SMAP_STAC` and 4 `SMAP_CLAC` (grep) and its `_copyin` is about 30 instruction lines; `arm64/copy.S` `copyin` about 35 including retguard and the range check. The deciding counts: (a) instructions between each `stac`/`clac` pair and how many are non-user accesses (every one is a wider window than the per-operand form needs); (b) range-check instructions per routine that become redundant; (c) sites in the whole kernel tree, not only `copy.S`, that open a window around more than one access (`user_access_begin`-style batches); if (c) is empty the window form has no remaining user.

**Precedent and what went wrong.** x86 SMAP with `STAC`/`CLAC` is the window model: forgotten `CLAC` on an error path is the bug class, bounded in practice by clearing on entry; Linux and OpenBSD both patch `stac`/`clac` into no-operations at boot on CPUs without SMAP (read: openbsd `codepatch`, `SMAP_STAC`). Arm PAN with `LDTR`/`STTR` is the per-operand model, and OpenBSD's arm64 `copyin` uses it (read: `arm64/copy.S`); the weakness of Arm's version is that the unprivileged forms exist only for plain loads and stores, so block copies are a loop of pairs. SPARC `lda`/`sta` address spaces and m68k `moves` are older per-operand forms *(from memory, not confirmed)*. A prefix instruction that applies to the next one was considered and rejected: it is hidden state across an instruction boundary, and an interrupt between the two would need the state saved.

**Fit with the priorities.** P1: smaller than any window (a bad kernel pointer in the destination cannot reach user memory, a user pointer in the destination operand faults, a kernel address as source faults), and nothing to forget. P2: three instructions fewer per copy (`STUA`, `CLUA`, range check) and, with option B, three more. P3: no new opcode. P4: a dozen gates. P5: nothing for compilers. P6: `MCPYIN` reads better than a flag nibble.

**Open choices for the author.** Option A (`pcb_onfault`) or B (fixup table). The `.U` spelling. Whether to keep `PSW.UA` and `STUA`/`CLUA` after the port. Whether `ECAUSE` bit 15 is wanted. Whether atomics (futex on user words) take the mode variant, which waits on the operand placement of `ATOM` (not fixed in the text).

**Your annotations:**

tell me more, i don't know enough to answer those open choices. summarize each on one line.


