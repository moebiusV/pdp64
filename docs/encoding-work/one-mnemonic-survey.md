# One mnemonic names the operation: the survey

The owner's rule (principle H2; errata 214, R537): if the arguments make the choice obvious, the mnemonic does not say how many bytes its encoding has. One word names the operation and the assembler picks the form (two, four, six or ten bytes) from the operands. Operand-size suffixes are not lengths and stay (`movq movl movw movb`, `xadd xaddl`, `fadd fadd32 fadd16`); a different operation stays a different word.

This file is the result of phase A (the survey) and says what phase B did with each group.

## 1. How the assembler picks a form

Before the change, and still:

* The codec (`common/pdp64enc.c`, tables generated from `spec/grammars.d`) holds the forms of a mnemonic in the order of the catalogue. `as64` (`as64/asmenc.c`, `eplan`, `hw_len`) takes the first form of the mnemonic whose fields can hold the operands, in the order shorter first and then catalogue order. So the great majority of mnemonics already name the operation only: `movq` has 35 forms of 1, 2, 3 and 5 parcels, `add` and the other ALU words 1, 2 and 3, `br` and the conditional branches 1, 2 and 3, `call` 1 to 3, `push pop pushm popm clr inc ...` 1 to 3, `lea` 1 to 3, `cbCC` 2 and 3 (`cbeq cbne` also 1), `jmpi calli` 2 and 3, `movcall` 2 and 3. The register hot sixteen (4-bit fields) and the displacement and immediate widths decide; nothing is spelled.
* A symbol whose value is known only at link time: the assembler emits the shortest form that has a field of 32 bits or more and a relocation (`R_PDP64_INSN_PC`, `_BR`, `_ABS`); `as64 --relax` (the default) puts a relocation on every instruction that holds the address of a symbol, local ones too; `ld64` (`ld64/relax.c`, argument in `docs/relaxation.md`, checked by `tools/check-ld-relax.py`, `tools/check-relax.sh`) re-chooses, from the decoded mnemonic and operands, the shortest form of at least the present length that takes the value. Lengths only grow in the iteration, and the result is the least fixed point.
* Phase B adds one thing to that: the linker may now also grow `movq #symbol, rd` to the ten-byte form when the address needs more than 32 bits (it used to refuse the link, `tests/ld/high.s`), because the ten-byte form is a form of `movq` now.

Selection rule, as written in appendix D of the manual: the assembler writes the shortest form of the operands (the first form in the table's order, shorter first, whose fields hold them); an operand that is not a constant at assembly time takes the form that has a relocation and the linker chooses; and `.encode N` (below) forces a minimum length.

## 2. The groups

"Obvious" means: the operands decide (a constant that fits a field, registers in the hot sixteen, a distance), and every form the operands fit does the same thing. The equivalence is checked, not argued: `tests/forms/check_forms.py` (`tools/check-forms.sh`, in `check-all.sh`) assembles 668 instruction and flag-state cases, 314 of which have more than one encoding, as the shortest form and with `.encode 1`, `.encode 2` and `.encode 3`, runs each under `sim64 -r`, and compares every register, the status word and the memory the instruction reaches: 0 differ. The instructions are the ALU group with register, memory and immediate sources, shifts, the sized and zero-extending moves (register, `d(Rn)`, `(Rn)+`, `-(Rn)`, indexed, immediate, literal pool), `lea`, the single-operand group on registers and memory, `push pop pushm popm`, `add #n, sp`, `bCC`, `cbCC` (immediate, register, against zero), `br jmp sob call`, and the rare words (`rori clz popcnt bswap div min cteq ctne cthi`). The flag invariant (`tests/flaginv.c`, errata 39) already says that no form writes part of N, Z, V.

Static counts are from the 841-file corpus of `docs/codegen-data/mnemonics_pdp64.csv` (370,000 instructions; 159,568 of two bytes, 169,184 of four, 41,314 of six). They are of pcc output, so system words are 0 there.

| Group | Spellings | How the assembler picked | What the operands decide | Result |
|---|---|---|---|---|
| Moves and the ALU | `movq movl movw movb movz*`, `add sub and bis bic xor cmp bit mul mulh shl shr sar`, `fadd...` | by operands (first fit, shortest) | hot registers, displacement, immediate (3 to 32 bits), pc distance | one word already; interchangeable (checked). `movq` 93,024 static (25%) |
| **MOVQL** | `movql #imm64, rd` and `movq #imm, rd` | by the spelling: the assembler turned a `movq` whose constant no form held into `movql` | the constant (the ten-byte form only when no shorter form holds it) | **changed**: `movql` is not a word; the leaf is the form `MOVQ64` of the word `movq`, bits unchanged. 44 of 9,955 static instructions need a constant beyond 32 bits in a compiler's output; 0 of 6,471,858 executed in 26 programs |
| **TRAP / TRAPL** | `trap #n`, `trapl #n` | by the spelling | none: both were one parcel with an 8-bit vector (the grammar had merged them; the manual still said 0 to 15 and four bytes) | **changed**: one word `trap #n`, n 0 to 255, two bytes. The slot of `trapl` in the leaf stays as a second encoding of `trap` (see 4) |
| **JMP label / BR** | `jmp label`, `br label` | by the spelling (`jmp` 2 or 3 parcels, `br` 1, 2 or 3 parcels; same field widths, same flags, no flags written, same timing class `BK_JMP_D`) | the distance | **changed**: `jmp label` (a bare pc-relative operand) is assembled as `br label`; `jmp` with a register, memory or absolute operand stays `jmp`. 646 static `jmp` (0.17%); on the 26 programs of `tests/c` and `tests/c-new`, 5 sites, 10 bytes of 16,568 |
| Conditional branches | `bCC`, `br` | by operands (distance) | the distance | one word already; the linker relaxes |
| Compare and branch | `cbCC rd, #imm\|rb, label` | by operands (immediate size, distance); when no form reaches (a far or external target, a wide immediate, an operand pair no form holds) the assembler writes `cmp` and `bCC` | immediate and distance | one word already, **but the fallback is not interchangeable**: `cbCC` writes no flags, `cmp` and `bCC` write them. Left as it is (it is documented in appendix D); see 3 |
| `sob` | `sob rn, label` | by distance | | one word already. Not the same as `dec rn` and `bne`: `sob` writes no flags |
| `call`, `calli`, `jmpi`, `jtag` | | by operands | | one word each already. `jmpi` and `calli` load the target from memory: different operations from `jmp` and `call` |
| `push pop pushm popm clr inc ...`, `add #n, sp`, `lea` | | by operands | register, immediate, displacement | one word already; interchangeable (checked). `push` 2,894, `pushm` 2,393, `lea` 42,258 static |
| Moves with a qualifier | `movq.u movq.d movq.ud` and the other sizes | one word per qualifier | | **left**: the qualifier is a different operation (user privilege; deferred fault), not a length |
| Unaligned moves | `movub movuw movul movuq` | | | **left**: different alignment rule |
| Memory-destination ALU | `addm subm bicm bism` | | | **left**: read-modify-write of memory, a different operation from `add rs, rd` |
| Atomics | `cas casl xadd xaddl ...`, `ll lll` | suffix `l` = 4 bytes | | **left**: an operand size, not an encoding length (the db forms were already removed) |
| Fused pairs | `movcall`, `popret`, `popmret`, `mov2` | never chosen by the assembler (the compiler fuses: counts in the pdp64/16 corpus movcall 10,785, mov2 4,045, popret 2,601, popmret 2,261) | | **left**: two operations in one instruction, with one fault boundary (a fault in the second half restarts both); `movcall rs, rd, label` already has its 2- and 3-parcel forms under the one word |
| Vector blocks | `vec`, `vec2`, `vskip`, `vld.b ...` | | | **left**: `vec2` has four registers and its own rules (a 2D block); the dotted suffixes are lane types |
| Rotates | `ror rs, rt, rd`, `rori rs, #n, rd`, `rol rs, #n, rd`, `rori32` | by the spelling | the kind of the count operand (a register or a constant); both forms are two parcels | **left**: not a length, so outside the rule as written; same operation, and `shl shr sar` already take a register or a constant under one word. Recommendation: `ror` takes either and `rori` goes (`rori32` stays: the 32-bit width is a different operation; `rol` is `rori` with the count 64 - n, the same question as `rori`). One question for the owner |
| Translation-buffer words | `tlbi tlbia tlbias tlbigp tlbsync icinv icinva` | one word each | | **left**: each removes something different |
| Floating-point words | `fadd faddd fadd32 fadds fadd16 ...` | | | **left**: sizes and aliases, not lengths |
| Aliases | `bhis blo cbhis cblo cthis ctlo mulu wait` | aliases of another word | | **left**: the same encoding under a name of habit, not lengths |

## 3. Where two encodings are not interchangeable

* `cbCC` against `cmp` and `bCC` (the assembler's automatic fallback). The fallback writes N, Z, V and C, and executes two instructions. pcc and the LLVM back end form a `cbCC` only where the flags are dead, so compiled code is unaffected; hand-written code may not be. This is the one place where one word hides a semantic difference. Recommendation: leave it as the owner decided before, or make the assembler warn when it expands.
* `sob` against `dec` and `bne`, `lea sym` against `movq #sym` (pc-relative against absolute), `movq =K` (a memory load from the pool) against `movq #K` (the immediate in the instruction): different operations; they are different words and stay different.
* The fused words and the `.u .d .ud` moves, as in the table.

Nothing else was found: every other multi-form word passed the run-time comparison above.

## 4. What was changed, and what remains

Changed (phase B):

* `movql` and `trapl` are not words. The assembler answers with the replacement (`as64/as64.c`, `removed_atomic_hint`): `trapl is not an instruction: one word names the operation and the assembler chooses its length from the operands; write trap #n (n from 0 to 255, two bytes)`; likewise `movql` (`tests/asm-err/trapl`, `movql`).
* `jmp label` is `br label` (`as64/asmenc.c`, `eplan`).
* `.encode N` (below); the encoding tests that needed `movql` use it (`tests/sim/gen_newops.py`).
* Grammar: `spec/grammars.d/20-enc-forms.hbnf` (form `MOVQL` is `MOVQ64` and its word is `movq`; `SYSI` lists `trap` twice), `40-mn-system.hbnf` (`trapl` removed), `80-mn-ext.hbnf` (`movql` removed), `60-asm-syntax.hbnf` (directive `encode`); `spec/facts/core.toml` (`[trapl]`, `[movql]` removed; `H_MOVQL` is gone from the executor: `movq` with a ten-byte immediate runs as every other `movq`).
* The disassembler `tools/encdis.c` prints `movq #imm, rd` and `trap #n` (the word names the operation); `-a -r` writes source that `as64` turns back into the same bytes, with `.encode N` where the form is not the shortest. `tools/check-roundtrip-dis.sh`: every test program (155) is reproduced byte for byte from its disassembly.

`.encode N` forces a form: from the directive on, every instruction is assembled in the shortest form of N parcels or more that takes its operands; `.encode 0`, or `.encode` alone, is the shortest form again (N from 0 to 5). An object that uses it is marked as one the linker does not shorten. It is in appendix D of the manual. The choice of a number of parcels (and not `short` or `long`) is because the forms are 1, 2, 3 and 5 parcels, and a test names the one it wants.

Not freed, on purpose: the second slot of `trap` in the leaf `SYSI` (256 first-parcel patterns) decodes as `trap`; the assembler never writes it. Removing it frees the patterns but moves `hint` from slot 3 to slot 2 (a change of one bit in the encoding of `hint`, which the tests and the hypervisor snippets use), so I left the bits as they are. The pc-relative forms of `jmp` (`CALL2_16/j`, and half of `CALLF`) are the same case: they are second encodings of `br`. Both can be freed whenever the owner wants the bits of `hint` changed; nothing else depends on it.

## 5. Size effects

| Change | Effect |
|---|---|
| `movql` | none: the ten-byte form is used for exactly the constants that used it; the sources that spelled `movql` for a constant that fits a shorter form (`-1`) now spell `.encode 5` to keep the test of the long form |
| `trapl` | the same instruction in the same two bytes; the bytes of a `trap` change from the old `trapl` slot to the `trap` slot (`7ac8` becomes `79c8` for `#200`) |
| `jmp label` | 0 to 2 bytes each: `tests/asm/modes.s` 64 to 62 bytes; `tests/sim/hv-exits.S` same size, other bits; the 26 compiled programs 16,568 to 16,558 |
| `movq #symbol` beyond 32 bits | a link that was refused now succeeds with the ten-byte form |
