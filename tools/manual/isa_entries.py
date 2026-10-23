"""The words of the instruction dictionary: the pages, the introductions, the page-2 descriptions, and the entries
(isa_part1.py, isa_part2.py, isa_part3.py).  The numbers are not here; tools/mkmanual.py reads them from spec/pdp64-mnemonics.hbnf."""
import isa_part1, isa_part2, isa_part3
from isa_stories import STORY

ENTRIES = isa_part1.ENTRIES + isa_part2.ENTRIES + isa_part3.ENTRIES

PAGES = [
    ('moves', 'Moves and address formation'),
    ('alu', 'Integer arithmetic and logic'),
    ('single', 'Single-operand instructions'),
    ('branches', 'Branches and indirect transfers'),
    ('bits', 'Bits, fields and text'),
    ('block', 'Block memory operations'),
    ('arith', 'Divide, remainder and selection'),
    ('fp', 'Floating point'),
    ('atomics', 'Atomics'),
    ('system', 'System instructions'),
]

PAGE_INTRO = {
    'moves': 'Moves between a register and an operand, zero-extending moves, address formation and the explicit unaligned forms. None of these writes a flag.',
    'alu': 'The ALU writes a register (or, for `ADDM` and its kin, memory) and writes all four flags uniformly: the flags are two groups, `C` and `{N, Z, V}`, and no instruction writes part of `{N, Z, V}`.',
    'single': 'The `SOP` group: one operand, the sub-opcode in the `reg` field. Includes `PUSH`, `POP`, `PUSHM`, `POPM`, `JMP` and `CALL`.',
    'branches': 'Conditional branches, `SOB`, the fused compare-and-branch family, the tag branches and the three indirect transfers.',
    'bits': 'The `BESC` group: counts, byte and bit reversal, rotates, the funnel shift, bit fields, carry-less multiply and UTF-8. Register to register; none writes a flag except the UTF-8 validity bit.',
    'block': 'The `MBLK` group: the block operations. Their progress is held in architectural registers, so a fault restarts them for free.',
    'arith': 'The `AESC` group: divide and remainder, the high unsigned product, absolute value, minimum and maximum, and `SET`.',
    'fp': 'Floating point is in the general registers; precision and rounding are in the opcode and there are no mode bits. Exception flags accumulate in `FPSR` and never trap.',
    'atomics': 'The atomic group (opcode `010001 (0x11)`). The operand placement of each form is unspecified. For the semantics see chapter 7.',
    'system': 'The system escape (opcode `010100 (0x14)`). For the modes, the entry sequence, the system registers and the translation machinery see chapter 6; for waiting, signalling and coherence see chapter 7. `STUA` and `CLUA` are described in section 6.5; they have no entry here.',
}

INDEX_INTRO = ('This is the reference part of the manual: **one entry for each instruction**, in the layout of a processor reference manual. Each entry gives its mnemonics, its syntax, its encoding (the parcel diagram and the numbers), its operation in pseudocode, the flags it writes, the exceptions it can take, and where the manual explains it. '
               'The entries are generated from `spec/pdp64-mnemonics.hbnf`, the one place where the numbers of the architecture are written, so an encoding here cannot disagree with the assembler or the simulators; the words (operation, flags, exceptions) are in `tools/manual/isa_entries.py` and are checked against the reference executor, `common/pdp64exec.c`, which `sim64` and QEMU share. '
               'The Status line of each entry says whether the executor implements the instruction.\n\n'
               '**Notation.** `Rd` is the destination register (the `reg` field of parcel 0), `Rs` the first source (`low`), `Rt` the second (`t` of parcel 1), `Ru` the third (`x`); the assembler writes the destination last. `rm` is a general operand: a register at `len = 00`, or a memory operand, an immediate or an absolute address by one of the eight addressing modes (section 9.5). `EA(rm)` is its effective address. `M[a]` is memory, `M8[a]` one byte. `sext` and `zext` sign- and zero-extend. A `len = 01` instruction is two parcels (four bytes) and a `len = 10` instruction three (six bytes); `len = 11` is page 2. `N Z V C` are the condition flags. Bit diagrams number the bits of a parcel from 15 at the left.\n\n'
               '**Cf.** lines point to the chapter that explains the matter an instruction touches: the kernel (chapter 6), the multiprocessor model (chapter 7), the bus (chapter 2).')

P2_INTRO = ('Page 2 (`len = 11`) is a second opcode map of 64 one-parcel instructions, 45 of them defined. **Every page-2 instruction is exactly the page-1 instruction it abbreviates**: the same result, the same flags and the same faults. The assembler chooses the shortest encoding, so a mnemonic still assembles to one instruction and a program can never change meaning by using a page-2 form. '
            'The opcode numbers of page 2 are independent of those of page 1. `reg` is the register (or the high part of an immediate) named first, `low` the field named second.')

P2 = {
    'ld.q': ('`MOVQ` load through `(rn)`', '`rd`', '`rn`', '`MOVQ (rn), rd`'),
    'st.q': ('`MOVQ` store through `(rn)`', '`rs`', '`rn`', '`MOVQ rs, (rn)`'),
    'ld.l': ('`MOVL` load through `(rn)`', '`rd`', '`rn`', '`MOVL (rn), rd`'),
    'st.l': ('`MOVL` store through `(rn)`', '`rs`', '`rn`', '`MOVL rs, (rn)`'),
    'ld.w': ('`MOVW` load through `(rn)`', '`rd`', '`rn`', '`MOVW (rn), rd`'),
    'st.w': ('`MOVW` store through `(rn)`', '`rs`', '`rn`', '`MOVW rs, (rn)`'),
    'ld.b': ('`MOVB` load through `(rn)`', '`rd`', '`rn`', '`MOVB (rn), rd`'),
    'st.b': ('`MOVB` store through `(rn)`', '`rs`', '`rn`', '`MOVB rs, (rn)`'),
    'ldz.l': ('`MOVZL` load through `(rn)`', '`rd`', '`rn`', '`MOVZL (rn), rd`'),
    'ldz.w': ('`MOVZW` load through `(rn)`', '`rd`', '`rn`', '`MOVZW (rn), rd`'),
    'ldz.b': ('`MOVZB` load through `(rn)`', '`rd`', '`rn`', '`MOVZB (rn), rd`'),
    'lea.sp': ('`LEA 8*d(SP), rd`', '`rd`', '`d` (0 to 15)', '`LEA 8*d(SP), rd`'),
    'ldq.sp0': ('`MOVQ` load from `SP`, offset `8*low`, 0 to 120', '`rd`', 'offset / 8', '`MOVQ d(SP), rd`'),
    'ldq.sp1': ('`MOVQ` load from `SP`, offset `8*(16+low)`, 128 to 248', '`rd`', 'offset / 8 - 16', '`MOVQ d(SP), rd`'),
    'stq.sp': ('`MOVQ` store to `SP`, offset `8*low`, 0 to 120', '`rs`', 'offset / 8', '`MOVQ rs, d(SP)`'),
    'ldl.sp0': ('`MOVL` load from `SP`, offset `4*low`, 0 to 60', '`rd`', 'offset / 4', '`MOVL d(SP), rd`'),
    'ldl.sp1': ('`MOVL` load from `SP`, offset `4*(16+low)`, 64 to 124', '`rd`', 'offset / 4 - 16', '`MOVL d(SP), rd`'),
    'stl.sp0': ('`MOVL` store to `SP`, offset `4*low`, 0 to 60', '`rs`', 'offset / 4', '`MOVL rs, d(SP)`'),
    'stl.sp1': ('`MOVL` store to `SP`, offset `4*(16+low)`, 64 to 124', '`rs`', 'offset / 4 - 16', '`MOVL rs, d(SP)`'),
    'ldq.d1': ('`MOVQ` load from `rn` at offset 8', '`rd`', '`rn`', '`MOVQ 8(rn), rd`'),
    'ldq.d2': ('`MOVQ` load from `rn` at offset 16', '`rd`', '`rn`', '`MOVQ 16(rn), rd`'),
    'ldq.d3': ('`MOVQ` load from `rn` at offset 24', '`rd`', '`rn`', '`MOVQ 24(rn), rd`'),
    'ldq.d4': ('`MOVQ` load from `rn` at offset 32', '`rd`', '`rn`', '`MOVQ 32(rn), rd`'),
    'stq.d1': ('`MOVQ` store to `rn` at offset 8', '`rs`', '`rn`', '`MOVQ rs, 8(rn)`'),
    'stq.d2': ('`MOVQ` store to `rn` at offset 16', '`rs`', '`rn`', '`MOVQ rs, 16(rn)`'),
    'ldl.d1': ('`MOVL` load from `rn` at offset 4', '`rd`', '`rn`', '`MOVL 4(rn), rd`'),
    'ldl.d2': ('`MOVL` load from `rn` at offset 8', '`rd`', '`rn`', '`MOVL 8(rn), rd`'),
    'ldl.d3': ('`MOVL` load from `rn` at offset 12', '`rd`', '`rn`', '`MOVL 12(rn), rd`'),
    'ldl.d4': ('`MOVL` load from `rn` at offset 16', '`rd`', '`rn`', '`MOVL 16(rn), rd`'),
    'pushm8': ('push the registers `R8` to `R15` named by the 8-bit mask `reg:low` (bit i is `R(8+i)`)', 'mask high', 'mask low', '`PUSHM #(mask << 8)`'),
    'popm8': ('pop the registers named by the mask, as `pushm8`', 'mask high', 'mask low', '`POPM #(mask << 8)`'),
    'sub.sp': ('`SUB #(8*n), SP`, `n = reg:low` (0 to 255)', 'n high', 'n low', '`SUB #(8*n), SP`'),
    'add.sp': ('`ADD #(8*n), SP`, `n = reg:low`', 'n high', 'n low', '`ADD #(8*n), SP`'),
    'movq.i': ('`MOVQ #imm, rd`, `imm` sign-extended 4 bits (-8 to 7)', '`rd`', 'imm', '`MOVQ #imm, rd`'),
    'shl.i': ('`SHL` by `low` (0 to 15)', '`rd`', 'count', '`SHL #n, rd`'),
    'shr.i': ('`SHR` by `low` (0 to 15)', '`rd`', 'count', '`SHR #n, rd`'),
    'sar.i': ('`SAR` by `low` (0 to 15)', '`rd`', 'count', '`SAR #n, rd`'),
    'and.i': ('`AND` with a 4-bit sign-extended immediate', '`rd`', 'imm', '`AND #imm, rd`'),
    'bis.i': ('`BIS` with a 4-bit sign-extended immediate', '`rd`', 'imm', '`BIS #imm, rd`'),
    'xor.i': ('`XOR` with a 4-bit sign-extended immediate', '`rd`', 'imm', '`XOR #imm, rd`'),
    'add.i': ('`ADD` with a 4-bit sign-extended immediate', '`rd`', 'imm', '`ADD #imm, rd`'),
    'pushx': ('`PUSHX` (`reg` and `low` zero)', '0', '0', '`SYSX` sub-opcode 0'),
    'popx': ('`POPX` (`reg` and `low` zero)', '0', '0', '`SYSX` sub-opcode 1'),
    'isync': ('`ISYNC` (`reg` and `low` zero)', '0', '0', '`SYSX` sub-opcode 2'),
    'hint': ('`HINT #n`, `n = reg:low` (0 to 255)', 'n high', 'n low', '`SYSX` sub-opcode 3'),
}

NOTATION = ("**The instructions.** Every instruction has an entry in the section of its group, laid out as in a processor reference manual: its mnemonics, its syntax, its encoding (a drawing of the parcels and the numbers), its operation in pseudocode, the flags it writes, the exceptions it can take, and where the manual explains the matter it touches (*Cf.*). Every instruction, the atomic and the system instructions included, has its official entry in this chapter (sections 9.13 and 9.14 for those two groups); the chapters on the kernel and on several processors give the reasons, and an entry may point back to them for a fuller explanation. In the pseudocode, \u2190 is assignment, = and \u2260 compare, \u00d7 and \u00f7 multiply and divide, and `M[a]` is memory at address `a`. Numbers that are encodings (opcodes, sub-opcodes, field values) are written in binary with the hexadecimal value in brackets behind, as `010011 (0x13)`. Masks are binary too, with a subscript 2 to mark the base (`Rn & 111\u2082` keeps the low three bits). "
            "The entries are generated from `spec/pdp64-mnemonics.hbnf`, the one place where the numbers of the architecture are written, so an encoding here cannot disagree with the assembler or the simulators; the words (operation, flags, exceptions) are checked against the reference executor, `common/pdp64exec.c`, which `sim64` and QEMU share, and the Status line of each entry says whether the executor implements the instruction. "
            "The one-parcel second page, the aliases, the constants and the lists of the mnemonics and the opcodes are in the [reference tables](dictionary/index.md).\n\n"
            "**The stories.** An instruction that is not common (the PDP-11 core and the operations every architecture has carry none) is followed by *Why it is here*: the machine the idea came from and the reason it was chosen, with the measurements that bear on it. Where no reason is recorded, the paragraph says so. The documents behind the paragraphs are listed in [appendix F](appendix-f-evidence.md).\n\n**Notation.** `Rd` is the destination register (the `reg` field of parcel 0), `Rs` the first source (`low`), `Rt` the second (`t` of parcel 1), `Ru` the third (`x`); the assembler writes the destination last. `rm` is a general operand: a register at `len = 00`, or a memory operand, an immediate or an absolute address by one of the eight addressing modes (section 9.5). `EA(rm)` is its effective address. `M[a]` is memory, `M8[a]` one byte. `sext` and `zext` sign- and zero-extend. A `len = 01` instruction is two parcels (four bytes) and a `len = 10` instruction three (six bytes); `len = 11` is page 2. `N Z V C` are the condition flags. In the drawings the bits of a parcel are numbered from 15 at the left, a shaded box is a fixed value, and a white box is a field that varies.")

P2_STORY = ("Instructions are at most six bytes: an eight-byte form would serve 48-bit immediates and 44-bit displacements, and only 49 of 373,635 compiled instructions (0.013%) would use it. The length code `11` is therefore a second page of one-parcel instructions, each an exact abbreviation of a long form, chosen from the forms the compiler emits most. The estimate from static counts on the 827-file corpus is about 118 KB, 7% of the 1.67 MB image. The rule that keeps the page honest: a page-2 instruction has the same result, flags and faults as the long form it abbreviates, so the assembler choosing the shortest encoding can never change what a program does.")
