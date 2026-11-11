Status: record, dated 2026-11-03. It describes the state and the thinking of that time. The current state is in docs/manual and docs/decisions-and-status.md; where this document disagrees, those win. Out of date: the study of a 32-register layout on top of the r20 encoding (len opcode reg low), the 234-instruction count, the opcode-layouts.html chart (history); the decided encoding is the prefix-coded pdp64 grammar, spec/pdp64/pdp64.hbnf

# The 32-register layout: does every instruction fit?

[← pdp64 index](../README.md)

For the author's annotation. This is the allocation check requested after [`register-file-options.md`](register-file-options.md). The chart of the forms of that date is [`opcode-layouts.html`](opcode-layouts.html) (history).

## Does every instruction fit the 32-register layout?

This is an allocation, not an estimate: all 234 instructions are assigned to opcode slots in the proposed layout of `register-file-options.md` section 3.4, every field is checked against the width the current ISA carries, and the byte cost of each repair is measured on the compiled corpus (841 files, 338,313 instructions, 1,083,870 code bytes, 16-register pcc output assembled by `build/as64`).

### Verdict

**No.** The layout holds every instruction, but not every form at the width it has today.

* **153 of 234 instructions fit unchanged** (same length, every field at full width): all branches `Bcc`, all of `BESC`, `MBLK`, `AESC`, the 42 non-fused `FESC` words, `ATOM`, `SYS`, `SYSX`. Their sub-opcodes are renumbered (8 bits become 5 or 10) and the counts fit.
* **81 do not fit as drawn**: 52 instructions with a memory operand (moves, `LEA`, ALU, `SOP`, `XFER`, `MESC`, `PUSHM`, `POPM`), 17 compare-and-branch instructions (`cbCC` 14, `SOB`, `BTAG`, `BNTAG`) and the 12 fused multiply-adds.
* **Opcode slots: 177 of 190 used** (one parcel 62 of 62, two parcels 61 of 64, three parcels 54 of 64). The one-parcel map is exactly full: 68 forms compete for 62 slots, so six page-2 abbreviations lose their two-byte form (734 corpus uses, 1,468 bytes).
* **Five things have no encoding in three parcels or fewer**: a 28-to-32-bit immediate (1,204 corpus sites), an absolute or PC-relative operand beyond 64 MB, a wide `cbCC` beyond 2 KB (194 sites, with one condition slot), a displacement that is not a multiple of the operand size (the tagged-pointer `MOVQ -1(R1)`), and the 5-parcel `MOVQL #imm64`.
* **Code size** on the corpus: +44,812 bytes (+4.13%) for the layout as described with my allocation; +21,816 (+2.01%) once `CALL label` and `LEA label` get branch-format opcodes; +14,966 (+1.38%) with four condition slots for `cbCC`. The estimated saving from 32 registers is about 1.0% (`spill-experiment.md`), so code size grows by 0.4% to 3%.
* **Decisions the author must make** (section 6): the unscaled displacement mode, a four-parcel length (or a pool) for large immediates, the `cbCC` condition-slot count, which six abbreviations lose their slot, the mode-field budget, the `PUSHM` window and the saved-register frame.

**What is verified, and how.** Every instruction is assigned by script to exactly one group (`fit/alloc.py`: 234 of 234, no duplicate). Every form in the tables of section 3 is checked field by field (`fit/forms.py`, output `fit/tables.md`, 22 lines flagged). The byte model reproduces the current assembler's page-2 choices exactly (0 mismatches in 61,786 page-2 uses, `fit/model.py`). **Not verified:** ATOM (its operand placement is open, errata 86, and `as64` does not assemble it); the four-byte `MESC`, `TRAPL` and `SYSX` forms (taken from the grammar, not assembled); dynamic counts (every count here is static); anything that needs 32-register code (none can be assembled).

### 1. Design levers used

* **Used:** the two escapes `ESC2`/`ESC3` with separate 64-entry maps; displacement scaled by operand size (not for `LEA`, `JMP`, `CALL`, `MOVU*`, or PC-relative); the one-parcel stack form `opcode(6) reg(5) entry(5)` with 32 entries; the stack-implicit two-parcel mode with an 11-bit scaled field; reuse of the `rm` bits for modes that name no base register (11 bits at two parcels, 27 at three); the condition kept in the second parcel for the compare-and-branch family.
* **Not used:** four opcode banks for the stack form (128 entries). Each bank multiplies four slots by four, which needs 12 more one-parcel slots. The only candidates are the ten fixed-offset abbreviations (5,984 uses, 11,968 bytes, 1.1%), which cost more than the banks save (0.55%, `register-file-options.md` section 4.2). Not used: the 3-bit mode field, because the mode table already needs 13 modes (section 5, issue 6).
* **Added by this allocation** (not in the author's notes): a group opcode whose sub-opcode sits in the first register field (`SOP`, `XFER`, `SYS`), a 10-bit sub-opcode for two-register escapes, a 5-bit sub-opcode beside the third register for three-register escapes, a branch format for `CALL label`, and four short-branch slots.

### 2. Inventory of operand shapes

The grammar (`spec/pdp64.hbnf.in`) gives the fields; `as64` was run on every word with the shapes of `layouts/probe.py` (26 memory shapes, register, immediate, count and label shapes) and the encodings confirmed. Lengths are today's, in parcels.

| Group | Instructions | Operand shapes today (length in parcels) |
|---|---|---|
| Moves, `MOVZ` | 7 | reg,reg (1); `(Rn)` etc. and small SP offsets (1, page 2); d(Rn) rm4 d12 (2, 3); index rm4 rx4 s2 d6 (2, 3); PC-relative, immediate, absolute d16/d32 (2, 3); d(DP) d12/d28; post/pre-decrement stride d12/d28; `MOVQ #imm4` (1) |
| `LEA` | 1 | the memory shapes without reg,reg; `lea 8*d(SP)` d 0 to 15 (1, page 2) |
| ALU, FP ALU | 17 | reg,reg (1); every memory shape (2, 3); `#imm4` for ADD, AND, BIS, XOR; counts 0 to 15 for SHL, SHR, SAR; `ADD/SUB #8n,SP` n to 255 (1, page 2) |
| `SOP` | 14 | `reg` = 4-bit sub-opcode, `low` = register (1) or mode (2, 3) |
| `PUSHM`, `POPM` | 2 | 16-bit mask in the immediate mode (2); mask of R8 to R15 in `reg:low` (1, page 2) |
| `XFER` | 3 | sub-opcode in `reg`; `JTAG` only in the scaled-index mode (2, 3) |
| `Bcc` | 15 | 8-bit displacement in `reg:low` (1); 16 (2); 32 (3), in parcels |
| `cbCC` | 14 | reg, imm5, 11-bit displacement (2); reg, reg, cond4, 12-bit displacement (2); wide: imm16 and disp16 (3 only); long: 27 and 28 bits (3) |
| `SOB`, `BTAG`, `BNTAG` | 3 | reg, 16-bit (2) or 32-bit (3) displacement; `BTAG` also sense1 and tag3 |
| `BESC` | 22 | 2-reg (12), 3-reg (4), `RORI`/`RORI32` count8 (2), bit-field with pos8 width8 in the third parcel (4) |
| `MBLK` | 7 | 3-reg `rd,rs,rn` (6), `MVAL rd,rn` |
| `AESC` | 11 | 3-reg (9), `ABS` 2-reg, `SET cc,rd` (cond4 in `x`) |
| `FESC` | 54 | 2-reg (39), 3-reg (3), 4-reg fused multiply-add (12) |
| `ATOM` | 22 | `reg`, `low`, `t`, `x`: four register fields; placement not fixed |
| `MESC` | 8 | sub4 rm4 disp8 (2), disp24 (3); 8 loads/stores and 4 read-modify-write forms |
| `SYS` | 30 | 13 no-operand minors; 12 classes with reg or imm4 (`TRAP #n`, `SPL #n`); `PROBER`/`PROBEW` rd in parcel 2; `TRAPL` n8; `MFSR`/`MTSR` sr8 r4 |
| `SYSX` | 4 | sub8 and a pad byte (2); page-2 abbreviations (1) |

### 3. The allocation

Notation: **a** and **b** are the two 5-bit fields of the first parcel (bits 9..5 and 4..0). In the tables **P1, P2, P3** are the first, second and third parcels. A "slot" is one of the 64 six-bit opcode values of a map. Where one slot holds many instructions the sub-opcode position is given. Corpus uses are static counts of the one-parcel forms the current assembler emits.

#### 3.1 One parcel: `opcode(6) a(5) b(5)`, 62 slots, all used

| Slots | Form | Fields | Instructions | Static corpus uses |
|---|---|---|---|---|
| 7 | reg,reg moves: `MOVQ MOVL MOVW MOVB MOVZL MOVZW MOVZB` | a=rd, b=rs | 7 | 55,082 |
| 17 | reg,reg ALU and FP ALU | a=rd, b=rs | 17 | 16,609 |
| 1 | `SOP` register | a = sub-opcode (5 bits, 14 used), b = register | 14 | 27,770 |
| 1 | `SYS` | a = class (5 bits), b = register, 5-bit immediate or minor. Absorbs `PUSHX POPX ISYNC` and `HINT n` (n 0 to 31) as classes 16 and up | 29 (25 + 4) | 8,071 |
| 4 | `Bcc`, 15 conditions | slot = cond[3:2]; bits 9..8 = cond[1:0]; bits 7..0 = displacement in parcels (today's reach) | 15 | 18,102 |
| 7 | `LD/ST (Rn)`: `MOVQ ld/st`, `MOVL ld/st`, `MOVB ld/st`, `MOVZB ld` | a=reg, b=rn | (moves) | 12,368 |
| 5 | stack form: `MOVQ ld`, `MOVQ st`, `MOVL ld`, `MOVL st`, `LEA` | a=reg, b = entry (0 to 31, unsigned, scaled by 8, 4, 4, 4, 8): reach 248 and 124 bytes | (moves, `LEA`) | 20,308 |
| 10 | fixed-offset: `ldq.d1` to `d4`, `stq.d1`, `d2`, `ldl.d1` to `d4` | a=reg, b=rn, offset in the opcode | (moves) | 5,984 |
| 2 | `PUSHM`/`POPM` window | a:b = 10-bit mask (today 8) | 2 | 4,836 |
| 2 | `ADD/SUB #8n,SP` | a:b = n (10 bits; today 8) | (ALU) | 3,586 |
| 3 | `MOVQ #imm`, `AND #imm`, `ADD #imm` | a=rd, b = signed 5-bit immediate (today 4) | (moves, ALU) | 9,809 |
| 3 | `SHL/SHR/SAR #n` | a=rd, b = count 0 to 31 (today 0 to 15) | (ALU) | 4,161 |
| **62** | | | all 85 instructions that have a one-parcel form today keep one | |

**Slots lost.** The page-1 and page-2 maps hold 24 + 1 + 1 + 4 + 38 = 68 forms (page 2 has 45 opcodes: the three two-bank stack pairs merge into three slots, giving 5 stack slots with `stq.sp` and `lea.sp`; the four `SYSX` words move into `SYS`). Six are dropped, lowest static use first: `ld.w` 29, `bis.i` 84, `xor.i` 92, `st.w` 104, `ldz.l` 156, `ldz.w` 269 (734 uses, 1,468 bytes; **the choice rests on static counts**, which under-weight floating point and kernel code).

**What must not be trimmed.** The 24 reg,reg forms, `SOP`, `SYS`: a two-parcel memory instruction has no register-direct mode, so an instruction that loses its one-parcel register form has no encoding at all.

#### 3.2 Two parcels: `ESC2 a b | P2`, 61 of 64 slots

| Slots | Group | P2 layout | Instructions | Sub-opcode |
|---|---|---|---|---|
| 12 | moves: 8 `MOV` ld/st, 3 `MOVZ`, `LEA` | `opcode(6) mode(4) disp(6)`; a=reg, b=rm | 8 | the opcode |
| 17 | ALU, FP ALU | same | 17 | the opcode |
| 1 | `SOP` memory | same, a = sub-opcode (5 bits), b = rm | 14 | P1 a |
| 1 | `XFER` | same, a = sub-opcode | 3 | P1 a |
| 12 | `MESC`: `MOVU{B,W,L,Q}` ld/st, `ADDM SUBM BICM BISM` | same; displacement 6 bits, unscaled | 8 | the opcode |
| 1 | `R2` two-register escapes | `opcode(6) sub(10)`; a=rd, b=rs | 54 (12 `BESC`, `MVAL`, `ABS`, `SET`, 39 `FESC`) | P2[9:0], about 60 used |
| 2 | `R3` three-register escapes | `opcode(6) rb(5) sub(5)` | 22 (4 `BESC`, 6 `MBLK`, 9 `AESC`, 3 `FESC`) | P2[4:0]; 32 per slot |
| 1 | `RRI`: `RORI`, `RORI32` | `opcode(6) count(6) sub(4)` | 2 | P2[3:0] |
| 1 | `BSEL` (candidate) | `opcode(6) rb(5) rc(5)` | 0 | the opcode |
| 3 | `ATOM`: `CAS`, `CASDB` (4 registers), 20 others (3 registers) | `opcode(6) rb(5) rc(5)`; `opcode(6) rb(5) sub(5)` | 22 | the opcode / P2[4:0] |
| 1 | `Bcc` | `opcode(6) cond(4) disp[5:0]`; displacement = P1[9:0]:P2[5:0], 16 bits | 15 | |
| 1 | `cbCC` register,imm5 | a=rd, b=imm5, cond(4), disp 6 bits | 14 | |
| 1 | `cbCC` register,register | a=ra, b=rb, cond(4), disp 6 bits | 14 | |
| 1 | `SOB` | a=reg, displacement = b:P2[9:0], 15 bits | 1 | |
| 2 | `BTAG`, `BNTAG` (sense in the opcode) | a=reg, b[4:2]=tag, displacement = b[1:0]:P2[9:0], 12 bits | 2 | |
| 1 | `CALL label` (branch format, new) | displacement = P1[9:0]:P2[9:0], 20 bits in parcels | 0 new | |
| 1 | `PUSHM`/`POPM` (dedicated, new) | mask = a:b:P2[8:0] (19 bits), P2[9] = direction | 2 | |
| 1 | `SYS2A`: `MFSR`, `MTSR`, `TRAPL` | `opcode(6) kind(2) arg(8)`: arg = system register or vector; a=reg | 3 | P2[9:8] |
| 1 | `SYS2B`: `PROBER`, `PROBEW`, `SYSX` words | `opcode(6) sub(10)`; a,b = registers, n or cc | 6 | P2[9:0] |
| **61** | | | 205 instructions have a two-parcel form today; 193 keep it, the 12 fused multiply-add words move to three parcels | |

Free: 3. The 12 fused multiply-add words do not fit here (they would need 12 more slots, 73 in all); they go to three parcels (below).

#### 3.3 Three parcels: `ESC3 a b | P2 | P3`, 54 of 64 slots

| Slots | Group | Layout | Instructions |
|---|---|---|---|
| 12 | moves, `LEA` | `opcode(6) mode(4) disp[21:16]`; P3 = disp[15:0]: 22 bits, scaled | 8 |
| 17 | ALU, FP ALU | same | 17 |
| 2 | `SOP`, `XFER` | same; sub-opcode in P1 a | 17 |
| 12 | `MESC` | same | 8 |
| 1 | `BF3`: `DSHR EXTB EXTZB INSB` | `opcode(6) rb(5) sub(5)`; P3 = pos(8) width(8) | 4 |
| 1 | `R4`: 12 fused multiply-add, `MAESCTR` (candidate) | P2 `opcode(6) rb(5) rc(5)`; P3 = sub-opcode (16 bits) | 12 |
| 1 | `Bcc` | cond(4) in P2[9:6]; displacement = P1[9:0]:P2[5:0]:P3, 32 bits | 15 |
| 1 | `cbCC` imm5 | displacement = P2[5:0]:P3, 22 bits | 14 |
| 1 | `cbCC` reg,reg | displacement 22 bits | 14 |
| 1 | `cbCC` wide | imm16 = P3, displacement = b:P2[5:0], 11 bits | 14 |
| 1 | `SOB` | displacement = b:P2[9:0]:P3, 31 bits | 1 |
| 2 | `BTAG`, `BNTAG` | displacement 28 bits | 2 |
| 1 | `CALL label` | 36 bits in parcels | 0 new |
| 1 | `PUSHM`/`POPM` | mask = 35 bits (32 needed) | 2 |
| **54** | | 10 free | 86 instructions have a three-parcel form today and keep it; the 12 fused multiply-add words gain one | 

**Total: 62 + 61 + 54 = 177 slots of 190.** An instruction with several forms occupies a slot per form; a group opcode with a sub-opcode field is counted once.

#### 3.4 Field check: the 22 lines that do not fit

All other fields of all forms in `fit/tables.md` fit (registers 5 bits, `RORI` count 6 bits, `BF3` position and width 16 bits, `DSHR` count, `MFSR` register 8 bits, `TRAPL` vector 8 bits, `HINT` n, sub-opcodes by count). Widths below are the current width (need) and the proposed (have). "Scaled" means the field counts entries of the operand size.

| Form | Parcels | Field | Need | Have | Effective reach |
|---|---|---|---|---|---|
| `d(Rn)` | 2 | disp | 12 bytes | 6, scaled, signed | -32 to 31 entries (quad: -256 to 248 bytes) |
| `d(Rn)` | 3 | disp | 28 | 22, scaled | ±2M entries |
| `d(SP)` implied | 2 | disp | 12 | 11, scaled | ±1,024 entries (quad ±8 KB) |
| `d(PC)` | 2 | disp (bytes) | 16 | 11 | ±1 KB (was ±32 KB) |
| `#imm`, `@abs` | 2 | payload | 16 | 11 | ±1,024 (was ±32,768) |
| PC-relative, `#imm`, `@abs` | 3 | payload | 32 | 27 | ±64 M (was ±2 G) |
| `d(DP)` | 2, 3 | disp | 12, 28 | 11, 27 scaled | fits scaled (quad ±8 KB) |
| `(Rn)(Rx*s)` | 2 | disp | 6 | 0 | no displacement; 3 parcels give 16 bits (was 22) |
| `(Rn)+`, `-(Rn)` | 2 | stride | 12 | 6 | ±32 (was ±2,048) |
| `MESC` | 2 | disp (unaligned: unscaled) | 8 | 6 | ±32 bytes (was ±128) |
| `cbCC` imm5 | 2, 3 | disp (parcels) | 11, 27 | 6, 22 | ±32 parcels (was ±1,024); ±2M |
| `cbCC` reg,reg | 2, 3 | disp (parcels) | 12, 28 | 6, 22 | ±32 (was ±2,048) |
| `cbCC` wide | 3 | disp (parcels) | 16 | 11 | ±1,024 (was ±32,768) |
| `SOB` | 2, 3 | disp (parcels) | 16, 32 | 15, 31 | one bit short |
| `BTAG`/`BNTAG` | 2, 3 | disp (parcels) | 16, 32 | 12, 28 | ±2,048 parcels (was ±32,768) |

### 4. Misfits and the cost of repairing each

Byte figures are from `fit/model.py` on the 1,083,870-byte corpus. The model charges the length the new layout would give each instruction, using the actual operand values and the actual distance to every local label.

| # | Misfit | Corpus sites | Repair | Bytes |
|---|---|---|---|---|
| 1 | 6-bit scaled base displacement (+ index with displacement 897 sites, stride) | 6,707 base + 897 index | the third parcel; the stack forms already absorb 99% of SP traffic | +10,906 +942 |
| 2 | One-parcel slots (68 forms, 62 slots) | 734 | six abbreviations become two-parcel | +1,468 |
| 3 | One-parcel forms that gain (immediate 5 bits, stack 32 entries, shift 31, `ADD/SUB SP` 10 bits) | 3,574 | none needed | -7,148 |
| 4 | PC-relative 16 to 11 bits: `call label` (11,795 local), `lea label` (7,388) | 19,183 | `CALL label` as a 20-bit branch-format opcode, `LEA label` as a 15-bit dedicated opcode | +20,658 unrepaired; -3,790 and +1,452 repaired (net -2,338) |
| 5 | Immediates 16 to 11 bits at two parcels | 4,432 | three parcels | +6,120 |
| 6 | Immediates beyond 27 bits (`CMP` 390, `AND` 310, `ADD` 292, `MOVQ` 113, ...) | 1,204 | no three-parcel form; four parcels or a pool | +2,408 at four parcels |
| 7 | `cbCC`: 6-bit displacement with one condition slot | 32,386 | 2 slots (7-bit) / 4 (8) / 7 (9) / 14 (10) in two and three parcels | +9,390 / +5,302 / +2,540 / +1,014 / +224 |
| 8 | `cbCC` wide: 11-bit displacement (194 sites beyond ±2 KB at one slot, 58 at two, 8 at four) | 11,604 | `CMP` and `Bcc` (two instructions), or 4+ slots | 8 bytes each |
| 9 | `Bcc` short form at 10 bits instead of 8 | 20,275 | 15 slots instead of 4 | -3,106 (11 more slots) |
| 10 | Fused multiply-add: 4 registers, no sub-opcode room | 0 in the corpus | three parcels (one slot for 12) | +2 per use |
| 11 | `PUSHM`/`POPM` 16-bit mask to 32 registers | 4,836 | window of 10 bits (one parcel), 19 (two), 35 (three) | 0 inside the window |
| 12 | `SOB`, `BTAG`, `BNTAG` | 0 in the corpus | accept the shorter reach, or one more parcel | 0 measured |
| 13 | Unscaled displacement (tag adjust `-1`, `7`) | 0 in the corpus (no tags in pcc) | an unscaled mode (6 bits, ±32 bytes) | 0 measured |
| 14 | `MOVQL #imm64`, five parcels | 49 per 373,635 instructions at present | two-parcel opcode with four literal parcels, 12 bytes (10 today) | +2 per use |

**Rolled up** (one run of the model, same corpus):

| Variant | Added bytes | Share |
|---|---|---|
| Layout as described, my allocation, one `cbCC` condition slot | +44,812 | +4.13% |
| plus `CALL label` and `LEA label` opcodes | +21,816 | +2.01% |
| plus two condition slots for `cbCC` | +17,728 | +1.64% |
| plus four condition slots | +14,966 | +1.38% |
| plus fourteen condition slots | +12,650 | +1.17% |
| only the memory-operand part (items 1, 2, 3) | +6,236 | +0.58% |
| immediates (items 5, 6) | +8,528 | +0.79% |

The memory result agrees with `register-file-options.md` section 4.2 (+0.85% with the 128-entry stack form, +1.4% with 32 entries) once the wider one-parcel immediate and stack reach are counted. The two items the author's notes do not cost are the PC-relative reach (item 4: +1.9% unrepaired) and the immediates (item 5 and 6: +0.8%).

### 5. Design issues the layout leaves open

Status: **ADDRESSED** (decided by something in this allocation), **PARTLY** (a mechanism exists, a decision is missing), **OPEN** (the author must decide).

| # | Issue | Status | What is needed |
|---|---|---|---|
| 1 | The one-parcel map is full (62 of 62), so no future one-parcel form fits and six abbreviations lose their slot | PARTLY | Choose the six by executed counts (`sim64` on the six programs), not static; floating point is under-weighted in the corpus. |
| 2 | A two-parcel memory instruction has no register-direct mode, so the 24 reg,reg forms, `SOP` and `SYS` must keep their one-parcel slots | ADDRESSED | Recorded as a constraint on trimming; a `reg` mode would cost one of the three spare modes. |
| 3 | Tagged pointers: `MOVQ -1(R1)` and `7(R1)` are not multiples of 8, so a scaled displacement cannot encode them; the alignment-abort tag check of ISA 6.2 depends on the bias being in the displacement | OPEN | An unscaled-byte base mode (6 bits, ±32 bytes; three parcels give 22). Without it every tagged access needs an extra `ADD`. |
| 4 | Scale depends on the operation: `LEA`, `JMP`/`CALL`, `MOVU*` unscaled; `SOP`/`XFER` share one opcode so the scale comes from the sub-opcode in `a` | PARTLY | Decode rule: scale = f(opcode, `a` for the two group opcodes). |
| 5 | Scaled-index mode has no displacement at two parcels (897 of 11,654 sites need one); `JTAG d(Rb)` loses its 6 bits | PARTLY | Accept three parcels for the displaced forms (+942 bytes). |
| 6 | Mode field is oversubscribed: 13 modes needed (base, base-unscaled, index x4, PC, imm, abs, DP, post, pre, SP) leaves 3 spare; the `.U` variants (base, post, pre, index x4 = 7) and the deferred loads need at least 5 | OPEN | Index scale as {size, 1} (92% and 7% of uses; 84 other) saves two modes; put `.U` into opcodes (11 slots, only 3 free at two parcels); or move the kernel-only forms to three parcels. |
| 7 | PC-relative reach: ISA 19.2 and 19.4 say PIE code is no longer and there are no veneers below 4 GB; now ±1 KB at two parcels and ±64 MB at three | PARTLY | `CALL label` (20-bit parcels at two, 36 at three) and `LEA label` (15-bit) recover the common cases; reach to 2 GB for data and `lea` needs a decision (a pool, a relocation with range check, or scaling by 2 for code only). |
| 8 | Immediates: 11 bits at two parcels, 27 at three; 1,204 corpus immediates (1.8%) need 28 to 32 bits | OPEN | A four-parcel length, a trailing-literal form (errata 85 "the same trick for 32-bit immediates"), or a pool load. |
| 9 | `@abs` is 11 or 27 bits; devices at 32-bit addresses are out of reach | OPEN | Same decision as 8. |
| 10 | `cbCC` reach against slots: 1 slot gives ±32 parcels (80% of immediate branches, 88% of register branches fit in two parcels); 4 slots give ±128 (92%, 98%) | OPEN | Choose the slot count. Data in section 4, item 7. |
| 11 | Wide `cbCC` (16-bit immediate): displacement 11 bits at one condition slot, 194 sites unreachable | PARTLY | 2 or more slots, or an assembler fall-back to `CMP` and `Bcc` (against ISA 4.14, "one mnemonic, one instruction"). |
| 12 | Short branches: 4 slots reproduce today's 8 bits; 15 slots give 10 bits (96.4% of `BR`) | PARTLY | 11 slots buy 3,106 bytes (0.29%). |
| 13 | `SOB` one bit short; `BTAG`/`BNTAG` reach ±2,048 parcels | PARTLY | Accept; none used in the corpus. |
| 14 | Fused multiply-add, `BSEL`, `MAESCTR`: four registers leave no sub-opcode room; 12 slots would overflow the two-parcel map | PARTLY | Three parcels (+2 bytes per use) or fewer fused forms. |
| 15 | `PUSHM`/`POPM` 16-bit mask; 32 registers need 32 bits; the p2 mask covers 8 registers | PARTLY | Window of 10, 19 and 35 bits by length; the callee-saved set must fit the one-parcel window or each prologue costs 6 bytes. Needs the ABI decision (issue 17). |
| 16 | `EPSW` masks: `PMASK`, `SMASK`, `VMASK` are 3 x 16 bits in bits 63..16 beside the 16-bit `PSW`; 32 registers need 3 x 32 = 96 bits | OPEN | `EPSW` plus a second word; `PUSHX` frame 16 bytes becomes 32; `POPX` likewise. Or keep the masks to R0 to R15. |
| 17 | ABI split of R16 to R31 (callee-saved or not), argument registers, the linker scratch `R12`, the `PUSHM` window | OPEN | Decide with the allocator experiment (callee-saved saves rose 23,476 to 26,442 with 32 registers). `SP` = `R14` and `FP` = `R13` stay, the 5-bit field covers them: **ADDRESSED**; the three banked stack pointers are named by `MFSR` register numbers and do not change: **ADDRESSED**. |
| 18 | Exception and context frames double (128 to 256 bytes of registers) | OPEN | Entry code, signal frames, `setjmp` buffers, `PUSHM` of all. |
| 19 | Early register read: the register file is read from P1 before P2 is decoded, but bits of `a` and `b` are sub-opcodes (`SOP`, `XFER`, `SYS`), displacement (modes without a base), a condition (`SET`) or an immediate; reading them as registers can raise a false poison or secret-taint check (errata 86 item 11 requires no false positives) and false dependencies | OPEN | Rule: no architectural effect from a register read until P2 is decoded; renaming and taint checks follow decode. |
| 20 | Fetch-time classification: today the opcode is in the first parcel; for two- and three-parcel instructions it is in P2, so a branch is recognised one parcel later | PARTLY | One-parcel branches (88% of `BR`) are visible at once; the two-parcel branch predecode needs P2 in the same fetch group. |
| 21 | Assembler relaxation: lengths must only grow. Scaling is safe for constant offsets (stack, base) but a PC-relative displacement to a label is not constant, so scaling it by the operand size would be non-monotone | PARTLY | PC-relative stays in bytes (or parcels for branches); the linker checks divisibility of scaled relocations. |
| 22 | Page 2: 45 opcodes become 38 slots (32 kept); 19 reserved page-2 slots disappear; `common/p2.c` and the `check-p2` test change | ADDRESSED | Section 3.1. |
| 23 | Short-branch reach in parcels (8 bits today, 10 available) | ADDRESSED | Section 3.1. |
| 24 | The 12-bit and ±2 KB statements in `pdp64-isa.md` (3.1.1, 3.3, 5, 6.2, 19.2, 19.4, DP description), `abi.md` and the opcode chart | OPEN | Text and the chart generator. |
| 25 | `ATOM` operand placement (errata 86): fits as 4 registers (`CAS`, `CASDB`) and 3 registers, no placement chosen | OPEN | Fix it; user-qualified atomics follow. |
| 26 | `MESC`: 12 slots in each of two maps, displacement 8 to 6 bits unscaled, none used in the corpus | PARTLY | Candidate to fold into a mode or to three parcels only. |
| 27 | `SET cc,rd` uses `b` as the condition: breaks ISA 4.14's second rule (fixed per escape opcode) | PARTLY | Give `SET` its own two-parcel slot (3 free). |
| 28 | Candidates: `MASKEQZ`, `MASKNEZ`, `ADDV`, `SUBV`, `MULV`, `AES*`, `SHA*` fit as `R3`/`R2`/`RRI` (10 sub-opcodes fill `R3`'s first slot: 22 + 10 = 32; the second slot is free); AES state "any two registers" needs no pairing | ADDRESSED | `TRAPCC` is four bytes (`SYS2B`), not the two-byte page-2 form proposed (no free one-parcel slot). |
| 29 | Granule colouring and reserved-colour instructions | OPEN | No instruction is specified; nothing to place yet. |
| 30 | `MOVQL #imm64` and the three-parcel cap (errata 31): the cap exists to keep length a function of the first parcel; a trailing literal needs the P2 opcode to know its length. 5 parcels is not expressible (`ESC2`, `ESC3` only) | OPEN | Two-parcel opcode with four literal parcels (6 parcels, 12 bytes). It is the only instruction that breaks the cap; issue 8 would add the 32-bit immediates. |
| 31 | `TRAP #n` now 0 to 31 in two bytes (was 0 to 15); `SPL #n` 0 to 7; `HINT n` 0 to 31 in two bytes | ADDRESSED | The assembler picks. |
| 32 | `SYS` page bits, `STUA`, `CLUA` | ADDRESSED | `SYS` classes 17 and up, `SYS2B` sub-opcodes. |
| 33 | Tools that change | OPEN | `spec/pdp64.hbnf.in`, `pdp64-mnemonics.hbnf` (all sub-opcode numbers), `tools/mkgrammar.py`, `check-drift.py`, `as64` (relaxation, field widths, scaled relocations), `ld64` (new relocations with range and divisibility checks), `common/pdp64exec.c`, `p2.c`, `sim64`, QEMU, `gen-llvm-td.py` and the LLVM tables, every test in `tests/`, `docs/opcode-layouts.html`. |
| 34 | Dynamic evidence: every byte figure is static; the 4.3% executed-instruction saving of 32 registers is an estimate (`dynamic-spill-estimate.md`) | PARTLY | Re-run the six programs once 32-register code assembles. |

### 6. Minimal decisions for the author

1. **An unscaled-byte mode** (issue 3), or give up bias-in-displacement tagging.
2. **A way to carry 28-to-32-bit immediates, absolutes and 2 GB PC-relative reach** (issues 7, 8, 9, 30): a four-parcel length, a trailing literal, or a pool plus range-checked relocations.
3. **The `cbCC` condition-slot count** (issue 10): 1, 2, 4, 7 or 14 (+9,390 to +224 bytes).
4. **Which six one-parcel abbreviations lose their slot** (issue 1), decided from executed counts.
5. **The mode-field budget** (issue 6).
6. **The saved-register frame** (issues 15, 16, 17, 18): the `PUSHM` window, the `EPSW` masks and the `PUSHX` size.
7. **Whether the 12 fused multiply-add words, `BSEL` and `MAESCTR` live in three parcels** (issue 14).

Everything else in section 3 stands as allocated, with the fields and slot counts shown.

