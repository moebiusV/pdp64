"""The words of the instruction dictionary: the introductions and the entries
(isa_part1.py to isa_part4.py).  The numbers are not here; tools/mkmanual.py reads them from spec/grammars.d."""
import isa_part1, isa_part2, isa_part3, isa_part4, isa_vec
from isa_stories import STORY
import isa_stories_ext
STORY = dict(STORY, **isa_stories_ext.STORY)

ENTRIES = isa_part1.ENTRIES + isa_part2.ENTRIES + isa_part3.ENTRIES + isa_part4.ENTRIES + isa_vec.ENTRIES	# isa_vec: the vec, tile and GEMM family, all held (P) until benchmarked

# The manual is about the architecture as it is to be.  An entry whose notes open with the tag (P), a proposal I have not
# accepted, or (S), a stub, is not emitted into the body or the reference tables; its text lives in docs/manual-src/appendix-parts/09-proposed.md
# (and 09-open.md for a stub).  An instruction I asked for or accepted is decided even when its details are not worked out: its entry is
# tagged (D) and it is not held.  Only the words I did not decide are held: MOVUSERD (a combination of two decided
# qualifiers that no text of mine or of the study defines), MSHA and MAESCTR (stage 2 of the crypto study, "only after measurement"), SYSPG0-5
# (placeholders).  The entry stays in this file so that the grammar's words keep their descriptions.
HELD = {}
for _e in ENTRIES:
    _n = _e['notes'].lstrip()
    if _n.startswith('*(P)*'):
        HELD[_e['id']] = 'proposed'
    elif _n.startswith('*(S)*'):
        HELD[_e['id']] = 'open'
HELD_NAMES = {_n for _e in ENTRIES if _e['id'] in HELD for _n in _e['names']}

# The introductions of the reference part: the notation of the entries, and the index.
NOTATION_ENC = ("**The instructions.** Every instruction has an entry in the section of its group, laid out as in a processor reference manual: its mnemonics, its syntax, its encoding (the chart of its layout and the list of all its layouts, "
                "each with a chart of its own), its operation in pseudocode, the flags it writes, the exceptions it can take, and where the manual explains the matter it touches (*Cf.*). Every instruction, the atomic and the system instructions included, "
                "has its official entry below (sections {{r:atomics-and-ordering}} and {{r:isa-system-instructions-exceptions}} for those two groups); the chapters on the kernel and on several processors give the reasons, and an entry may point back to them for a fuller explanation. "
                "In the pseudocode, ← is assignment, = and ≠ compare, × and ÷ multiply and divide, and `M[a]` is memory at address `a`. Numbers that are encodings (prefixes, sub-opcodes, field values) are written in binary. "
                "Masks are binary too, with a subscript 2 to mark the base (`Rn & 111₂` keeps the low three bits). The layouts are generated from the grammars of the encodings, `spec/grammars.d/22-enc-vocabulary.hbnf` and the grammar of the CPU, "
                "so a chart here cannot disagree with the assembler, the linker or the simulator. The aliases, the constants, the lists of the mnemonics and the bit layouts of every opcode are in the [reference tables](dictionary/index.md).\n\n"
                "**The stories.** An instruction that is not common (the PDP-11 core and the operations every architecture has carry none) is followed by *Why it is here*: the machine the idea came from and the reason it was chosen, with the measurements that bear on it. "
                "Where no reason is recorded, the paragraph says so. The documents behind the paragraphs are listed in [appendix {{c:id03006|n}}](appendix-e-evidence.md).\n\n"
                "**Notation.** `Rd` is the destination register, `Rs` the first source, `Rt` the second, `Ru` the third; the assembler writes the destination last, and the operands of a chart are numbered `op1`, `op2`, ... in the order of the assembly syntax. "
                "`rm` is a general operand: a register, or a memory operand, an immediate, a pc-relative or an absolute address, by the addressing forms that the layouts of the instruction give (section {{r:addressing-modes}}). `EA(rm)` is its effective address. "
                "`M[a]` is memory, `M8[a]` one byte. `sext` and `zext` sign- and zero-extend. `N Z V C` are the condition flags. In the charts the bits of a parcel are numbered from 15 at the left, a shaded box is a fixed value, and a white box is a field that varies.")

INDEX_INTRO_ENC = ("This is the reference part of the manual: **one entry for each instruction**, in the layout of a processor reference manual. Each entry gives its mnemonics, its syntax, its encoding (a chart of its layout, and the list of all its layouts), its operation in pseudocode, "
                   "the flags it writes, the exceptions it can take, and where the manual explains it. The charts, the hot-register tables and the operand widths are generated from the grammars of the encoding (`spec/grammars.d/22-enc-vocabulary.hbnf` and the grammar of the CPU), "
                   "the one place where the encoding is written, so a layout here cannot disagree with the assembler or the simulators.\n\n"
                   "**Notation.** `Rd` is the destination register, `Rs` the first source, `Rt` the second, `Ru` the third; the assembler writes the destination last. `rm` is a general operand. `EA(rm)` is its effective address. `M[a]` is memory, `M8[a]` one byte. "
                   "`sext` and `zext` sign- and zero-extend. `N Z V C` are the condition flags. Bit charts number the bits of a parcel from 15 at the left.\n\n"
                   "**Cf.** lines point to the chapter that explains the matter an instruction touches: the kernel (chapter {{c:id01006|n}}), the multiprocessor model (chapter {{c:id01007|n}}), the bus (chapter {{c:id01002|n}}).")
