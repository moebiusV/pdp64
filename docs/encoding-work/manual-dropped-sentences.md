Status: history. Superseded by the single manual (docs/manual-src, docs/manual). Kept for the record; do not use it to learn the current design. Out of date: the review list refers to entries of the former per-encoding manuals; the sentences kept or dropped there are not a decision list: see the Appendices H to J of the manual

<!-- {% raw %} -->
# The sentences of the instruction entries that were changed for pdp64/16 and pdp64/32

[← encoding work](README.md)

The entries of the manual were written for pdp64/r20 and say, in places, how the original encoding lays an instruction out. For the manuals of pdp64/16 and pdp64/32 (`tools/manual/memberprose.py`, `isa_enc.py`) the text of every field that did so was changed: a sentence was removed, trimmed, or replaced. This is the review list: for each field, what the pdp64/r20 text said, what the prefix-coded manuals say instead, and whether the sentence carried meaning beyond the encoding (a semantic claim, a rationale, a precedent, a measurement). Where it did, the meaning was restored into the member text (`isa_enc.py`, `NOTES`, `EXC`, `STORY`), rewritten for the member's encoding. **58 fields of 44 entries.**

The words of the first column: *encoding only* (nothing but a layout, a size or an allocation of the original opcode space was lost), *restored* (the sentence had meaning and the member text has it again), *replaced* (a statement about the original encoding became a statement about the new ones), *trimmed* and *wording* (a clause or a word).

| Entry | Field | Verdict | What was done |
|---|---|---|---|
| MOV | notes | encoding only | The two sentences removed (`len = 00`, page 2) are layouts of the original encoding. The conversion-set claim was kept, restated for the register-to-register forms (checked: the grammars have `movb`, `movzb` and the others in the register-register leaf). |
| MOVZ | notes | encoding only | The conversion-set claim kept, restated. |
| LEA | notes | encoding only | The six-byte reach of `len = 10` is a layout; the reach of each form is in its chart. |
| LEA | exc | encoding only | `len = 00` and the immediate mode: restated as "a register or an immediate is not a form". |
| MOVU | notes | layout trimmed | "in `MESC`" removed; the meaning (explicit forms for unaligned data) kept. |
| MOVU | story | rewritten | The sentence that said `MESC` carries the forms is restated without the group name; nothing lost. |
| ADD | notes | encoding only | Page-2 forms of `ADD`; the one-parcel immediate forms of pdp64/16 and /32 are in the charts. |
| SUB | notes | encoding only | Page-2 form `SUB #(8*n), SP`; the immediate forms are in the charts. |
| SHIFT | notes | encoding only | Page-2 shifts and the "two bytes" of `ASL`/`ASR`; restated as one-parcel forms (the layouts of the entry), which the grammars have (`SHI5`, `SHI3`). |
| ADDM | notes | encoding, and one unverified claim | The `MESC` sentence is a layout. Lost: "`INC`, `DEC`, `NEG`, `COM` and `CLR` on a memory operand are in `SOP`", a statement that those instructions accept a memory operand; not restored because the grammars of the prefix-coded CPUs were not checked for it (the entries of those instructions state their operand as `rm`). Replaced by the statement of errata 87 that these forms are in the ordinary memory families. |
| ADDM | story | measurement restored | The sentence on `MESC` and the opcode-map rule is a statement about the original opcode space and is dropped. The measurement (265 sites, 1.6 KB) carried meaning and is restored, said to be for the original encoding. |
| BCC | notes | claim replaced | "The branch reaches +-4 GB with no long-branch instruction" is false for the prefix-coded CPUs (each form has its own reach, and a `cbCC` that no form reaches is expanded); replaced by a pointer to the charts. |
| SOB | story | encoding only | The sentence "taken from the PDP-11, at the branch group's one free opcode" was cut to "taken from the PDP-11" (the precedent kept, the opcode allocation dropped). |
| CBCC | notes | replaced | The three encodings (`CBCC`, `CBW`, `CBRR`) and their reach are layouts of the original encoding. "No `len = 00` form" is a layout. "A target in another section is refused" is an assembler rule not verified for the new encodings and is not carried. Replaced by the account of the forms and of the expansion to `CMP` and `bCC` (errata 87 (6), 90), a new and important statement: **the expansion writes the flags**. |
| CBCC | story | measurement restored | The measurements (11,735 and 4,631 instructions) belong to the original encoding and are kept, said to be so; the remark that the opcode is the reserved `0x28` is dropped. |
| BTAG | notes | encoding only | Size and displacement width are layouts. |
| BTAG | story | layout rationale dropped | "Three bits of tag and one of sense fit the `low` nibble exactly, so parcel 1 is a full displacement" is a rationale for the original layout; the rest (the tag is free because objects are aligned; for Lisp) is kept. |
| ASL | notes | encoding only | "in two bytes". |
| ASR | notes | encoding only | "in two bytes". |
| PUSHM | notes | encoding replaced | Four bytes, mode, page 2: layouts. Replaced by the 32-bit mask (errata 87 (7)) and the one-parcel 8-bit form scaled by 256, which names `R8` to `R15` (read from the grammar). |
| PUSHM | story | rationale partly dropped | "They are in `SOP` because a 16-bit mask does not fit beside `MBLK`'s sub-opcode" is an allocation of the original opcode space and is dropped; the VAX precedent and the measurement (2,392 sites within `R8` to `R15`) are kept, restated for the one-parcel forms. |
| POPM | notes | encoding only | Four bytes, 8-bit mask on page 2. |
| PUSH | notes | encoding only | "A one-parcel instruction for a register operand"; not restated (not verified for the new encodings). |
| JMPI | notes | encoding only | "so it is four bytes at least". |
| JMPI | story | restored | The automatic filter had removed two sentences with meaning ("each two instructions and a scratch register without it", the jump-table remark); both restored in the rewritten paragraph. |
| COUNT | story | restored | The LoongArch precedent ("the model for putting them in the base") was in a sentence that also gave the opcode allocation; restored without the allocation. |
| POPCNT | story | restored | "The building block of `XNORPOP`" restored. |
| BITREV | story | restored | The LoongArch precedent restored. |
| ROR | story | restored | The reason (rotates by constants in crypto, so an immediate form is needed; the register-count form has almost no users) restored without "four-byte" and "`BESC`, not the ALU group". |
| RORI | notes | encoding only | "Four bytes: the count is in the low byte of parcel 1". |
| DSHR | notes | encoding only | "Six bytes (the count is in parcel 2)"; the precedent and the 128-bit shift sequence kept. |
| EXTB | notes | encoding replaced | "Six bytes ... `len = 10` only" is a layout; replaced by errata 87 (8): position and width are immediates and a width of 64 cannot be encoded. |
| MSCN | story | trimmed | "Both cost no opcode" removed (an allocation claim of the original encoding), "almost no hardware" kept. |
| MVAL | story | restored | "Costs no opcode" removed; the reuse of the `UTF8DEC` comparators and of the `MBLK` sequencer restored as "almost no hardware". |
| MULHU | story | restored | The filter had left a broken sentence ("It is, where arithmetic belongs"); the group placement is dropped, the `MULHSU` remark kept. |
| SET | notes | encoding only | "The `x` field of parcel 1": a layout. |
| SET | story | restored | The filter had removed the whole paragraph, a rationale and a measurement (673 `set<cc>`, about 0.4%); restored in full. |
| FDIV | notes | encoding only | "two-byte form ... so they are in `FESC`": restated as "one-parcel form". |
| FSINGLE | story | restored | The filter left "`binary32` is with the same operations"; restated. |
| FMADD | notes | encoding only | "Four register operands are available at `len = 01`"; the four operands are in the chart. |
| FMADD | story | restored | The filter left "is, because"; restated without `FESC`. |
| FRINT | notes | wording | "in the opcode" became "in the instruction". |
| CAS | notes | replaced, and a new statement | The ATOM note now says that the grammars assume the operand placement (errata 87 (4)); the other atomics have the same note. |
| SWAP | notes | see CAS |  |
| SWAP | story | trimmed | "of the `ATOM` group". |
| XADD | notes | see CAS |  |
| XADD | story | restored | The PDP-11 precedent (`DATIP`/`DATO`) was dropped with the group name; restored. |
| XAND | notes | see CAS |  |
| XAND | story | trimmed | "of `ATOM`". |
| XMAX | notes | see CAS |  |
| LLSC | notes | restored | The filter-free override first dropped the RISC-V guarantee ("a short `LL`/`SC` sequence must eventually succeed ...") and the remark on the result convention of `SC`: both semantic, both restored. |
| RET | notes | wording | "in the system escape" dropped; "not privileged, the partner of `CALL`" kept. |
| PUSHX | notes | encoding only | Four bytes and page 2. |
| PUSHX | story | encoding only | "Page 2 has the two-byte forms." |
| MFSR | notes | encoding only | "a number in parcel 1 ... four bytes"; the flush rule and the register table kept. |
| TRAP | notes | replaced | `TRAPL` and its parcel layout replaced by the fact that in the prefix-coded encodings `TRAP` and `TRAPL` are one word with an 8-bit vector (`docs/encoding-proposal.md` section 3). |
| TRAP | story | restated | The reason for `TRAPL` (the 256 vectors and the two-byte common case) is kept as the reason in the original encoding. |
| MTDP | story | restored | The filter removed the descent of `DP` from the 6502 zero page and its roles (thread pointer, per-CPU pointer): a rationale; restored, without the "12-bit displacement in four bytes". |

## The texts

For each field the pdp64/r20 text and the text of pdp64/16 and pdp64/32 (empty: nothing is said).

### MOV, notes

pdp64/r20: A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. At `len = 00` the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`. Page 2 abbreviates the loads and stores through `(rn)`, at small offsets from `SP` and from a register, and `MOVQ #imm, rd` with a 4-bit immediate (see the page-2 table).

pdp64/16 and /32: A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. The register-to-register forms of the sized moves are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`.

### MOVZ, notes

pdp64/r20: There is no zero-extending 64-bit move (it would be `MOVQ`). At `len = 00` these are the zero-extending half of the conversion set.

pdp64/16 and /32: There is no zero-extending 64-bit move (it would be `MOVQ`). The register-to-register forms are the zero-extending half of the conversion set.

### LEA, notes

pdp64/r20: `LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. At `len = 10` it forms any address within ±2 GB of itself PC-relatively in six bytes. The base of every PC-relative displacement is the address of the first parcel of the instruction.

pdp64/16 and /32: `LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. The base of every PC-relative displacement is the address of the first parcel of the instruction.

### LEA, exc

pdp64/r20: The operand must name memory; `len = 00` (a register) and the immediate mode are reserved. No memory access is made, so the instruction takes no memory fault. A reserved encoding aborts with the illegal-instruction vector.

pdp64/16 and /32: The operand must name memory (a register or an immediate is not a form). No memory access is made, so the instruction takes no memory fault. A reserved encoding aborts with the illegal-instruction vector.

### MOVU, notes

pdp64/r20: The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned, in `MESC`.

pdp64/16 and /32: The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned.

### MOVU, story

pdp64/r20: Data alignment is architectural on this machine (9.2.11): an ordinary quad access to an address that is not a multiple of 8 aborts, and that abort doubles as the tag check for tagged pointers; a load form that ignores low pointer bits is rejected for that reason. Packed on-disk and network structures still need unaligned access, so `MESC` carries explicit unaligned forms rather than weakening the rule for every load. No further reason is recorded for these four.

pdp64/16 and /32: Data alignment is architectural on this machine (9.2.11): an ordinary quad access to an address that is not a multiple of 8 aborts, and that abort doubles as the tag check for tagged pointers; a load form that ignores low pointer bits is rejected for that reason. Packed on-disk and network structures still need unaligned access, so the architecture has explicit unaligned forms rather than weakening the rule for every load. No further reason is recorded for these four.

### ADD, notes

pdp64/r20: All ALU operations are 64 bits, with no size field. Page 2 has `ADD #imm, rd` with a 4-bit immediate and `ADD #(8*n), SP`.

pdp64/16 and /32: All ALU operations are 64 bits, with no size field.

### SUB, notes

pdp64/r20: Page 2 has `SUB #(8*n), SP`.

pdp64/16 and /32: (nothing)

### SHIFT, notes

pdp64/r20: The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Page 2 has the three shifts by an immediate 0 to 15. `ASL` and `ASR` (in `SOP`) are the by-one forms in two bytes; rotates are in `BESC`.

pdp64/16 and /32: The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Small immediate counts have one-parcel forms (the layouts of this entry); `ASL` and `ASR` are the by-one forms; rotates are `ROR` and `RORI`.

### ADDM, notes

pdp64/r20: Parcel 0's low nibble is a mode, as in the ordinary memory format, so these are `MESC` forms with a memory destination (`len >= 01`). `INC`, `DEC`, `NEG`, `COM` and `CLR` on a memory operand are in `SOP`.

pdp64/16 and /32: The forms with a memory destination are in the ordinary memory families of the encoding, with every addressing form (errata 87).

### ADDM, story

pdp64/r20: These are the read-modify-write forms with a memory destination. An instruction with a memory destination is at least four bytes anyway, so they live in `MESC` at no cost; the opcode map follows one rule, that a top-level opcode is for an operation whose common case is register to register. They cover the case where the second operand is a register, for example `BISM Rmask, flags(DP)`. The compiled corpus has 265 sites (1.6 KB), so they earn their place in the escape group but not in the opcode space.

pdp64/16 and /32: These are the read-modify-write forms with a memory destination. They cover the case where the second operand is a register, for example `BISM Rmask, flags(DP)`. The compiled corpus has 265 sites (1.6 KB) for them, measured for the original encoding, which is why they are not worth an opcode of their own there.

### BCC, notes

pdp64/r20: Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the branch reaches ±4 GB with no long-branch instruction.

pdp64/16 and /32: Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the reach of each form is in its chart.

### SOB, story

pdp64/r20: Taken from the PDP-11, at the branch group's one free opcode. The PDP-11's could only branch backward (a 6-bit unsigned displacement); this one branches either way. Against the `cbnz` idiom of other architectures it does not save bytes (`DEC` plus `BNE` is also four) but it saves an instruction issue, a cycle per iteration on a machine that does not pipeline: same size, one instruction fewer (static `dec; bne` pairs exist).

pdp64/16 and /32: Taken from the PDP-11. The PDP-11's could only branch backward (a 6-bit unsigned displacement); this one branches either way. Against the `cbnz` idiom of other architectures it does not save bytes (`DEC` plus `BNE` is also four in the original encoding) but it saves an instruction issue, a cycle per iteration on a machine that does not pipeline: same size, one instruction fewer (static `dec; bne` pairs exist).

### CBCC, notes

pdp64/r20: Three encodings, chosen by the assembler: `CBCC` (`101000 (0x28)`, a 5-bit signed immediate -16 to 15, a displacement of ±1024 parcels at four bytes or 27 bits at six), `CBW` (`101001 (0x29)`, a 16-bit immediate and a 16-bit displacement, six bytes) and `CBRR` (`101010 (0x2A)`, two registers, ±2,048 parcels at four bytes or 28 bits at six). There is no `len = 00` form. A target in another section is refused.

pdp64/16 and /32: The family has several forms for each condition (the layouts of this entry): the second operand is a register or an immediate of some width, and the reach differs. A `cbCC` that no form reaches is assembled by `as64` as `CMP` and `bCC`, which **writes the flags** (errata 87, assumption 6; the integration measured 4 such sites in 34,387 for pdp64/16 and 17 in 34,524 for pdp64/32, errata 90).

### CBCC, story

pdp64/r20: A fused compare-and-branch in the reserved opcode `101000 (0x28)`, estimated with `RORI32` at 22 KB (1.3%) of the image. The wide-immediate `CBCC` removes 11,735 instructions (3.4%) and 1,828 bytes; `CBRR`, the register-register compare-and-branch, removes 4,631 instructions (1.4%) and 142 bytes. It is not a replacement for flags: LoongArch and RISC-V chose fused compare-and-branch instead of flags, and this architecture declines that (9.20) because it needs a comparator in the branch unit and a third read port; here the fused form is added beside the flags. `CBCC` writes no flags.

pdp64/16 and /32: A fused compare-and-branch, estimated with `RORI32` at 22 KB (1.3%) of the image of the original encoding. There the wide-immediate form removes 11,735 instructions (3.4%) and 1,828 bytes, and the register-register compare-and-branch removes 4,631 instructions (1.4%) and 142 bytes. It is not a replacement for flags: LoongArch and RISC-V chose fused compare-and-branch instead of flags, and this architecture declines that (9.20) because it needs a comparator in the branch unit and a third read port; here the fused form is added beside the flags. `CBCC` writes no flags.

### BTAG, notes

pdp64/r20: For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). Four bytes at least; the displacement is 16 bits (32 at `len = 10`).

pdp64/16 and /32: For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). The displacement is signed and counts parcels.

### BTAG, story

pdp64/r20: The tag branches `BTAG` and `BNTAG` and the table dispatch `JTAG` make tagged pointers cheap to use rather than merely possible: three bits of tag and one of sense fit the `low` nibble exactly, so parcel 1 is a full displacement. Because quad-aligned objects have zero in the low three bits, the tag is free, and an unaligned access is a fault. The compiler for C never emits them (the corpus shows none); they are for Lisp and other tagged runtimes.

pdp64/16 and /32: The tag branches `BTAG` and `BNTAG` and the table dispatch `JTAG` make tagged pointers cheap to use rather than merely possible. Because quad-aligned objects have zero in the low three bits, the tag is free, and an unaligned access is a fault. The compiler for C never emits them (the corpus shows none); they are for Lisp and other tagged runtimes.

### ASL, notes

pdp64/r20: The by-one form of `SHL` in two bytes.

pdp64/16 and /32: The by-one form of `SHL`.

### ASR, notes

pdp64/r20: The by-one form of `SAR` in two bytes.

pdp64/16 and /32: The by-one form of `SAR`.

### PUSHM, notes

pdp64/r20: Four bytes (mode `0100`, immediate). The registers are pushed in ascending order, so `POPM` with the same mask restores them. Page 2 has an 8-bit mask for `R8` to `R15`.

pdp64/16 and /32: The registers are pushed in ascending order, so `POPM` with the same mask restores them. The mask is the low 32 bits of the number (errata 87, assumption 7); the one-parcel form takes an 8-bit mask scaled by 256, which names `R8` to `R15`.

### PUSHM, story

pdp64/r20: The VAX procedure entry mask was the useful half of `CALLS`; `PUSHM` and `POPM` keep that half without the frame (hardware call frames ran slower than the sequence on later VAXes). They are in `SOP` because a 16-bit mask does not fit beside `MBLK`'s sub-opcode; that uses `SOP`'s last two free slots. The second page has 8-bit forms for `R8` to `R15`, because all 2,392 push sites and 2,392 pop sites in the measured corpus use a mask within `R8` to `R15`.

pdp64/16 and /32: The VAX procedure entry mask was the useful half of `CALLS`; `PUSHM` and `POPM` keep that half without the frame (hardware call frames ran slower than the sequence on later VAXes). The one-parcel forms take an 8-bit mask for `R8` to `R15`, because all 2,392 push sites and 2,392 pop sites in the measured corpus use a mask within `R8` to `R15`.

### POPM, notes

pdp64/r20: The mirror of `PUSHM`; four bytes, with an 8-bit-mask form on page 2.

pdp64/16 and /32: The mirror of `PUSHM`.

### PUSH, notes

pdp64/r20: A one-parcel instruction for a register operand.

pdp64/16 and /32: (nothing)

### JMPI, notes

pdp64/r20: The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand, so it is four bytes at least.

pdp64/16 and /32: The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand.

### JMPI, story

pdp64/r20: Exactly one deferred reference, for control transfer only, in `XFER`: the PLT stub of every dynamically linked program (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`), each two instructions and a scratch register without it. It is admitted because it breaks none of the reasons deferred modes are removed (no register is side-effected, the reference is in the branch path and not the operand path, a fault is clean by ordering). Jump tables through `JMPI` are not smaller, because the table entries are 8 bytes against 8 for a case in a compare chain.

pdp64/16 and /32: Exactly one deferred reference, for control transfer only: the PLT stub of every dynamically linked program (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`), each two instructions and a scratch register without it. It is admitted because it breaks none of the reasons deferred modes are removed (no register is side-effected, the reference is in the branch path and not the operand path, a fault is clean by ordering). Jump tables through `JMPI` are not smaller than a compare chain, because a table entry is 8 bytes and a case in a compare chain is also 8.

### COUNT, story

pdp64/r20: `BESC` is the bit-manipulation group: bit manipulation is not an extension on a machine that does filesystem work, bignum arithmetic and the like. The counts are the VAX `FFS` and `FFC` idiom (find first set, find first clear). LoongArch is the model for putting them in the base: it has `CLO`, `CLZ`, `CTO`, `CTZ` there, which is the decisive argument for giving `BESC` a top-level opcode. The compiler emits none of them, since C has no operator for them; the corpus shows zero uses.

pdp64/16 and /32: Bit manipulation is not an extension on a machine that does filesystem work, bignum arithmetic and the like. The counts are the VAX `FFS` and `FFC` idiom (find first set, find first clear), and LoongArch, which has `CLO`, `CLZ`, `CTO` and `CTZ` in its base, is the model for putting them there. The compiler emits none of them, since C has no operator for them; the corpus shows zero uses.

### POPCNT, story

pdp64/r20: One of the counts of `BESC`; it is also the building block of `XNORPOP`. A compiler needs `__builtin_popcount` to emit it, so the corpus shows no use (see `COUNT`).

pdp64/16 and /32: One of the counts; it is also the building block of `XNORPOP`. A compiler needs `__builtin_popcount` to emit it, so the corpus shows no use (see `COUNT`).

### BITREV, story

pdp64/r20: Part of the `BESC` group, borrowed with the other LoongArch bit operations (`REVB`, `REVH`, `BITREV`). No workload from the corpus is recorded.

pdp64/16 and /32: Borrowed with the other LoongArch bit operations (`REVB`, `REVH`, `BITREV`). No workload from the corpus is recorded.

### ROR, story

pdp64/r20: One rotate direction suffices and `ROR` is the one to keep: `ROL x, #n` is exactly `ROR x, #(64-n)`, and a funnel shifter yields `ROR` directly. No rotate is through carry (see `DSHR`). `ROR` is in `BESC`, not the ALU group: cryptographic code rotates by compile-time constants, so a four-byte immediate form is needed either way, and the register-count form has almost no users. Rotates write no flags.

pdp64/16 and /32: One rotate direction suffices and `ROR` is the one to keep: `ROL x, #n` is exactly `ROR x, #(64-n)`, and a funnel shifter yields `ROR` directly. No rotate is through carry (see `DSHR`). `ROR` is a bit operation and not an ALU operation: cryptographic code rotates by compile-time constants, so an immediate form is needed either way, and the register-count form has almost no users. Rotates write no flags.

### RORI, notes

pdp64/r20: Four bytes: the count is in the low byte of parcel 1.

pdp64/16 and /32: (nothing)

### DSHR, notes

pdp64/r20: x86 `SHRD`, ARM `EXTR`. Six bytes (the count is in parcel 2). A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.

pdp64/16 and /32: x86 `SHRD`, ARM `EXTR`. A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.

### EXTB, notes

pdp64/r20: Six bytes (position and width are in parcel 2), so these exist at `len = 10` only.

pdp64/16 and /32: Position and width are immediate operands; a width of 64 cannot be encoded (errata 87, assumption 8).

### MSCN, story

pdp64/r20: `MSCN` is `LOCC` and `memchr`; `MSCNN` fills the `SKPC` gap (the first byte that is *not* equal). Both cost no opcode and almost no hardware. With an explicit count `MSCN` gives `strnlen`, and with `MCPY` a bounded `strcpy` in two instructions. NUL-terminated string instructions (the System/z `MVST`, `SRST`, `CLST`) are rejected, because they encode an unbounded read, the largest single source of memory-safety failures in C (9.17).

pdp64/16 and /32: `MSCN` is `LOCC` and `memchr`; `MSCNN` fills the `SKPC` gap (the first byte that is *not* equal). Both cost almost no hardware. With an explicit count `MSCN` gives `strnlen`, and with `MCPY` a bounded `strcpy` in two instructions. NUL-terminated string instructions (the System/z `MVST`, `SRST`, `CLST`) are rejected, because they encode an unbounded read, the largest single source of memory-safety failures in C (9.17).

### MVAL, story

pdp64/r20: The UTF-8 validity comparators already built for `UTF8DEC`, wired to the `MBLK` streaming sequencer already built for `MCPY`, so it costs no opcode and almost no hardware. The alternative, a SWAR loop (SIMD within a register), runs at about two to three cycles a byte and is respectable, which is why the justification is cost and not throughput.

pdp64/16 and /32: The UTF-8 validity comparators already built for `UTF8DEC`, wired to the streaming sequencer already built for `MCPY`, so it costs almost no hardware. The alternative, a SWAR loop (SIMD within a register), runs at about two to three cycles a byte and is respectable, which is why the justification is cost and not throughput.

### MULHU, story

pdp64/r20: The unsigned partner of `MULH`, for the same reason (the high half of the product). It is in `AESC`, where arithmetic belongs. `MULHSU`, signed times unsigned for a bignum's top limb, is reserved because it can be built from `MULH` with one correction.

pdp64/16 and /32: The unsigned partner of `MULH`, for the same reason (the high half of the product). `MULHSU`, signed times unsigned for a bignum's top limb, is reserved because it can be built from `MULH` with one correction.

### SET, notes

pdp64/r20: The condition is the `x` field of parcel 1, numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).

pdp64/16 and /32: The condition is numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).

### SET, story

pdp64/r20: The first instruction written with a condition word: one instruction, `SET cc, Rd`, rather than one opcode per condition, with the condition in a field numbered like the low nibble of the branch opcodes. It turns a comparison used as a value into 0 or 1 without a branch. gcc `-Os` for amd64 emits 673 `set<cc>` on the corpus, and `SET` would remove about six bytes per site, around 0.4% of code; the compiler's first pass turns such a comparison into branches before its second pass sees it, so the saving is not reached in compiled code.

pdp64/16 and /32: The first instruction written with a condition word: one instruction, `SET cc, Rd`, rather than one opcode per condition, with the condition numbered like the low nibble of the branch opcodes. It turns a comparison used as a value into 0 or 1 without a branch. gcc `-Os` for amd64 emits 673 `set<cc>` on the corpus, and `SET` would remove about six bytes per site, around 0.4% of code; the compiler's first pass turns such a comparison into branches before its second pass sees it, so the saving is not reached in compiled code.

### FDIV, notes

pdp64/r20: `FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a two-byte form, so they are in `FESC`. The alternative spellings `FDIVD`, `FSQRTD` are aliases.

pdp64/16 and /32: `FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a one-parcel form. The alternative spellings `FDIVD`, `FSQRTD` are aliases.

### FSINGLE, story

pdp64/r20: `binary64` has first-class opcodes because on a 64-bit machine it is the common case; `binary32` is in `FESC` with the same operations, held in the low 32 bits of a register and sign-extended like every other 32-bit value (see also the ABI). The naming rule is an `F` in front of the integer mnemonic (`FADD`) and a size suffix for the other formats (`FADD16`); the older spellings (`FADDS` and so on) are aliases.

pdp64/16 and /32: `binary64` has first-class opcodes because on a 64-bit machine it is the common case; `binary32` has the same operations, held in the low 32 bits of a register and sign-extended like every other 32-bit value (see also the ABI). The naming rule is an `F` in front of the integer mnemonic (`FADD`) and a size suffix for the other formats (`FADD16`); the older spellings (`FADDS` and so on) are aliases.

### FMADD, notes

pdp64/r20: Four register operands are available at `len = 01`. The alternative spellings `FMADDD`, ... are aliases.

pdp64/16 and /32: The alternative spellings `FMADDD`, ... are aliases.

### FMADD, story

pdp64/r20: The whole fused multiply-add family is in `FESC`, because its absence would be the single worst gap in the floating-point set: one rounding instead of two, and the inner step of dot products, polynomial evaluation and every matrix kernel. `FESC` gives it four register operands. It replaces the VAX `POLY`, which was the best answer before fused multiply-add.

pdp64/16 and /32: The whole fused multiply-add family is in the instruction set because its absence would be the single worst gap in the floating-point set: one rounding instead of two, and the inner step of dot products, polynomial evaluation and every matrix kernel. It has four register operands. It replaces the VAX `POLY`, which was the best answer before fused multiply-add.

### FRINT, notes

pdp64/r20: The rounding mode is in the opcode, never in a mode bit. The alternative spellings `FRINTD`, `FRINTDZ`, ... are aliases.

pdp64/16 and /32: The rounding mode is in the instruction, never in a mode bit. The alternative spellings `FRINTD`, `FRINTDZ`, ... are aliases.

### CAS, notes

pdp64/r20: The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

pdp64/16 and /32: The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group.

### SWAP, notes

pdp64/r20: The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

pdp64/16 and /32: The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group.

### SWAP, story

pdp64/r20: One of the read-modify-write atomics of the `ATOM` group (see `CAS`). No separate reason is recorded for it.

pdp64/16 and /32: One of the read-modify-write atomics (see `CAS`). No separate reason is recorded for it.

### XADD, notes

pdp64/r20: The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

pdp64/16 and /32: The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group.

### XADD, story

pdp64/r20: One of the fetch-and-operate atomics of `ATOM` (see `CAS`), in the place of the PDP-11's read-modify-write instructions, which were indivisible on the Unibus through the `DATIP`/`DATO` pair (7.1).

pdp64/16 and /32: One of the fetch-and-operate atomics (see `CAS`), in the place of the PDP-11's read-modify-write instructions, which were indivisible on the Unibus through the `DATIP`/`DATO` pair (7.1).

### XAND, notes

pdp64/r20: The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

pdp64/16 and /32: The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group.

### XAND, story

pdp64/r20: The fetch-and-and, or and xor atomics of `ATOM` (see `CAS`). No separate reason is recorded for them.

pdp64/16 and /32: The fetch-and-and, or and xor atomics (see `CAS`). No separate reason is recorded for them.

### XMAX, notes

pdp64/r20: The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.

pdp64/16 and /32: The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group.

### LLSC, notes

pdp64/r20: A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles. The result convention shown for `SC` is the usual one and is unspecified.

pdp64/16 and /32: A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement (errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. The reference executor does not implement the group. The result convention shown for `SC` is the usual one and is unspecified.

### RET, notes

pdp64/r20: Not privileged, though it is in the system escape: it is the two-byte partner of `CALL`.

pdp64/16 and /32: Not privileged: it is the partner of `CALL`.

### PUSHX, notes

pdp64/r20: Four bytes (the `SYSX` escape, sub-opcodes 0 and 1) and two bytes on page 2. For a handler that wants to be interrupted: it can save the exception state and lower the priority.

pdp64/16 and /32: For a handler that wants to be interrupted: it can save the exception state and lower the priority.

### PUSHX, story

pdp64/r20: A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority; with only `MFSR` that costs two moves and two stores (sixteen bytes) on every such kernel entry, and the same to restore. The instructions may not show up high in the instruction count, but they save bytes and cycles in a tight, very often used kernel loop. Page 2 has the two-byte forms.

pdp64/16 and /32: A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority; with only `MFSR` that costs two moves and two stores (sixteen bytes) on every such kernel entry, and the same to restore. The instructions may not show up high in the instruction count, but they save bytes and cycles in a tight, very often used kernel loop.

### MFSR, notes

pdp64/r20: The register is chosen by name (a number in parcel 1); the instruction is four bytes. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.  {{SYSREGS}}

pdp64/16 and /32: The register is chosen by name. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.  {{SYSREGS}}

### TRAP, notes

pdp64/r20: The replacement for the PDP-11 `IOT` and `EMT`. `TRAPL` reaches the vectors 0 to 255 with `n` in the high byte of parcel 1.

pdp64/16 and /32: The replacement for the PDP-11 `IOT` and `EMT`. In these encodings `TRAP` and `TRAPL` are one word with an 8-bit vector number (`docs/encoding-proposal.md`).

### TRAP, story

pdp64/r20: `TRAPL` exists so that the vector range of 256 and the two-byte common case can both be kept: `TRAP #n` for `n` below 16 is two bytes and the long form reaches 256. `IOT` and `EMT`, which were `TRAP` at two particular vectors on the PDP-11, are not provided.

pdp64/16 and /32: In the original encoding `TRAPL` existed so that the vector range of 256 and the two-byte common case could both be kept (`TRAP #n` for `n` below 16 is two bytes, and the long form reaches 256); here one word carries an 8-bit vector number. `IOT` and `EMT`, which were `TRAP` at two particular vectors on the PDP-11, are not provided.

### MTDP, story

pdp64/r20: `DP` descends from the 6502's zero page and is kept for code density (a 12-bit displacement in four bytes); it is also the thread pointer in user mode and, in kernel mode, the per-CPU pointer that an SMP kernel wants (7.4). `MTDP` and `MFDP` read and write the current mode's copy.

pdp64/16 and /32: `DP` descends from the 6502's zero page and is kept for code density (a short displacement from `DP`); it is also the thread pointer in user mode and, in kernel mode, the per-CPU pointer that an SMP kernel wants (7.4). `MTDP` and `MFDP` read and write the current mode's copy.

<!-- {% endraw %} -->
