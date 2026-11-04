# spec/: the grammars and the tables of the encodings

pdp64 is a family. Its members differ in the width of the register fields and so in the instruction encoding:

| name | registers | encoding | source of truth | `-m` | `e_flags & 0xF` |
|---|---|---|---|---|---|
| pdp64/r20 | r0-r15 | the original: parcel 0 = `len:2 opc:6 reg:4 low:4` | `pdp64-mnemonics.hbnf`, `pdp64.hbnf.in` (hbnf) | `pdp64/r20` (the default; `old`, `r20`) | 0 |
| pdp64/16 | r0-r15 | prefix-coded, 4-bit register fields | `pdp64-16/forms.json` | `pdp64/16` (or `16`) | 1 |
| pdp64/32 | r0-r31 | prefix-coded, 5-bit register fields (3- and 4-bit hot tables) | `pdp64-32/forms.json` | `pdp64/32` (or `32`) | 2 |

The three coexist: the original encoding is untouched and is what every existing test checks; the assembler selects an encoding with `as64 -m`, writes it in the `e_flags` of
the object (`EF_PDP64_ENC_*` in `as64/relocs.h`), and `ld64` refuses to link objects of different encodings and writes the flag in the executable.

The design, its measurements and the reasons are in `docs/encoding-proposal.md`; the scripts that produced the tables are in `docs/codegen-data/encoding/`.

## Why a table and not hbnf for the new encodings

hbnf bit rules (`spec/pdp64.hbnf.in`) describe a record as a sequence of fields read from the most significant bit, with the length of an instruction decided by a few fields
of parcel 0. The prefix-coded encodings have a prefix of 1 to 16 bits whose length depends on its value (281 leaves in pdp64/16, 255 in pdp64/32), the register fields at the
*low* end of parcel 0, and displacements that continue in later parcels, in several places split in two. It is expressible in hbnf only by writing one alternative per leaf with
its fields cut into pieces, a union of hundreds of body shapes, and the consumer would still need a table (leaf to operand) to say what the pieces mean. So the new encodings
keep the project's principle, one source of truth per encoding from which everything is generated or checked, with a different source:

    spec/pdp64-NN/forms.json  --tools/mkenc.py-->  build/pdp64-NN-tab.c      the C tables of the codec (common/pdp64enc.c)
                                                    build/x/*                  the assembly grammar of as64 (spec/ grammar + the new words + r16-r31)
                                                    spec/pdp64-NN/tables.md    the leaves, for people (checked by `mkenc.py --check`)

`forms.json` holds the forms (operand specs, mnemonics) and the leaves (prefix, sub-opcode bits, the bit positions of every field). It is *written by the optimiser*
(`docs/codegen-data/encoding/export_forms.py`: `solve.py` with the four fused pairs forced in), not by hand, and it is checked by `tools/check-enc.py`, which lays the same
forms out again with the Python model (`enc.py`) and requires the same prefixes and bit positions, then compares the C codec with the model on boundary vectors of every
mnemonic of every form. `tools/mkenc.py` verifies, independently of the optimiser, that the prefixes are a prefix code, that each leaf covers its 16n bits exactly once and that
no first parcel decodes to two leaves.

The mnemonics are those of the original grammar (aliases included) plus the words only the new encodings have, which `mkenc.py` collects into the group `mn-ext`
of the grammar as64 reads (`build/x/pdp64-mnemonics.hbnf`): `maskeqz masknez bsel aeses aesesm aesds aesdsm aesks1 aesks2 aesim sha256* sha512* msha256 msha512 maesctr addv subv mulv
movql trapcc.<cc> syspg0-5`, the user-qualified moves `movq.u movq.d movq.ud ...`, and the fused `movcall popmret popret mov2`. In `-m pdp64/r20` they are refused.

## The model in two paragraphs

An instruction is one to five 16-bit parcels (little-endian in memory); its length is a function of parcel 0 alone. The top bits of parcel 0 are a prefix of 1 to 16 bits
that selects a *leaf*: a group of mnemonics with one form (operand shapes and field widths); a sub-opcode field inside the leaf (binary-aligned) selects the mnemonic.
Register fields start at bit 0 of parcel 0 and go up (the last register operand lowest), displacements and immediates fill the rest, the widest field last, so in the later parcels.
No bit is padding: an unused sub-opcode, or a hot-register index beyond the table, decodes as an illegal instruction. 5.0% of the first-parcel patterns (3,277 of 65,536) are unassigned
and illegal in both.

The assembler picks, for each instruction, the first form in the table's order (shorter first, then the order of `forms.json`) whose fields can hold the operands, and relaxes
(lengths only grow; every distance is measured on the layout of the previous pass, which is the iteration of the model). A branch, call or `d(PC)` operand is measured in bytes
from the first parcel of the instruction; the field counts parcels for branches and calls (unit 2) and bytes for the memory forms (unit 1). An unresolved symbol needs a form with a field
of 32 bits or more and a relocation; the relocation types are those of `as64/relocs.h`, the linker finds the field through the codec.

## Operand notation and the choices the tables imply

* `(r)+` and `-(r)` without a stride write stride 0, which means the size of the access (8 outside the moves); `(r)+8` writes 8.
* `pushm`, `popm`, `popmret` take a register mask; a mask is the low 32 bits of the number (so `#-16740608` is a mask of r31...); in pdp64/16 only bits 0-15 exist.
* `set cc, rd`: 4 bytes (`SETF`). `trap #n`, `trapl #n`, `spl #n`, `hint #n`: one parcel with an 8-bit number. `trapcc.<cc>`: one parcel, no operand.
* ATOM (assumed, section 3.2 of the proposal): three registers (`xadd`... `ll`, `sc`) and four (`cas`, `casdb`), the memory address in a register, operands in the order written. The roles of the registers
  are the ISA's to fix; the encoding only fixes where they sit.
* `cbCC` for which no form reaches (a far target, a wide immediate, an external label) is assembled as `cmp` + `bCC`. **This writes the flags**, which `cbCC` does not.
* `movq #imm, rd` whose constant fits no `movq` form is assembled as `movql`, a ten-byte instruction with the 64-bit immediate.
* The 22 meaningless shapes the original assembler accepts (`clr/com/inc/dec/neg/tst/adc/sbc/asl/asr/jmp/call/pop/jmpi/calli #imm`, `movq/movl/movw/movb r,#imm`, `lea #imm,r`, `sob r,#imm`, ...) are refused.
* The assembler never fuses. The fused instructions are ordinary mnemonics with operands: `movcall rs, rd, label` (`movq rs,rd ; call label`, the target measured from the first parcel of the fused instruction),
  `popmret #mask`, `popret rd`, `mov2 ra, rb, rc, rd` (`movq ra,rb ; movq rc,rd`, all four in the hot-8 table). Choosing them is the compiler's job.
* `extb/extzb/insb` have 6-bit position and width: a width of 64 is refused. The MESC words (`movub... bism`) exist only in the 3-parcel memory forms (the optimiser selected no narrower one: no use in the corpus).

## The hot-register tables (part of the ABI, docs/abi.md)

A 3-bit register field in a one-parcel form is an index, not a register number. pdp64/16: `r0 r1 r8 r2 sp r3 r9 r10` (90.8% of the register uses of the corpus).
pdp64/32 also has 4-bit fields: `r0 r1 r8 r2 sp r3 r9 r10 r11 r4 r15 r5 r24 r25 r26 r6` (`r24`-`r26` are the callee-saved registers of the 32-register compile);
its 3-bit table is the same as pdp64/16's. A different register allocation changes the sizes, not the correctness. `mov2` needs all four registers in the 3-bit table.

## Commands

    tools/mkenc.py [--md] [--check]      generate the tables (build/), rewrite or check spec/pdp64-NN/tables.md
    as64 -m pdp64/16|pdp64/32|pdp64/r20 [-o obj] file.s [--stats] [--dump-lens file]
    tools/check-enc.sh                   mkenc --check, codec against the model, drift test of every mnemonic
    python3 docs/codegen-data/encoding/export_forms.py 16|32 out.json       rerun the optimiser (needs the corpus)
    python3 docs/codegen-data/encoding/asm_vs_model.py 16|32 outdir          real assembler against the model on the corpus (needs the corpus)

Not part of this phase: relaxation of external calls and `lea` by the linker (the encoding is ready for it: a 4-byte `call` reaches +-2 MB), the simulator, the compiler.
