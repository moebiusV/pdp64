# spec/: the grammars and the tables of the encodings

> **Status (2026-11-04, integration).** The architecture family is pdp64 with the members pdp64/r20 (the original encoding), pdp64/16 and pdp64/32. The grammars in this directory are the source of truth; they were re-optimised on the new compiler's output (three-parcel `cbCC`), so a count of forms or leaves quoted in an older document must be checked against `spec/pdp64-NN/tables.md`, which is generated. Linker relaxation is the default (`as64 --no-relax`, `ld64 --no-relax` opt out). The reports and the order of events: `docs/encoding-work/README.md`.

pdp64 is a family. Its members differ in the width of the register fields and so in the instruction encoding:

| name | registers | encoding | source of truth | `-m` | `e_flags & 0xF` |
|---|---|---|---|---|---|
| pdp64/r20 | r0-r15 | the original: parcel 0 = `len:2 opc:6 reg:4 low:4` | `pdp64-mnemonics.hbnf`, `pdp64.hbnf.in` (hbnf) | `pdp64/r20` (the default; `old`, `r20`) | 0 |
| pdp64/16 | r0-r15 | prefix-coded, 4-bit register fields | `pdp64-enc.hbnf`, `pdp64-16/pdp64-16.hbnf` (hbnf) | `pdp64/16` (or `16`) | 1 |
| pdp64/32 | r0-r31 | prefix-coded, 5-bit register fields (3- and 4-bit hot tables) | `pdp64-enc.hbnf`, `pdp64-32/pdp64-32.hbnf` (hbnf) | `pdp64/32` (or `32`) | 2 |

The three coexist: the original encoding is untouched and is what every existing test checks; the assembler selects an encoding with `as64 -m`, writes it in the `e_flags` of
the object (`EF_PDP64_ENC_*` in `as64/relocs.h`), and `ld64` refuses to link objects of different encodings and writes the flag in the executable.

The design, its measurements and the reasons are in `docs/encoding-proposal.md`; the scripts that produced the tables are in `docs/codegen-data/encoding/`.

## The grammars of the new encodings

The principle of the project is that the toolchain is written from one source of truth, a set of hbnf grammars, so that the assembler, the linker, the emulator, the
compiler back end and the QEMU target cannot drift apart. pdp64/16 and pdp64/32 follow it: each is an hbnf grammar,

    spec/pdp64-enc.hbnf              what the two share: the operand shapes, the sizes of the moves' access, the numbered words of group mn-ext, and the vocabulary (its header)
    spec/pdp64-16/pdp64-16.hbnf      pdp64/16: registers, hot table, the catalogue of 208 forms, 270 leaves
    spec/pdp64-32/pdp64-32.hbnf      pdp64/32: the same for 32 registers (207 forms, 268 leaves, two hot tables)

An instruction is a bit record read from the top bit of parcel 0 (each parcel big-endian, as in `pdp64.hbnf.in`). A **leaf** is one alternative of `insn`: the prefix as a
constant (`0b0010`: 1 to 16 bits, as wide as its digits), the sub-opcode `sub:J`, and the pieces of the operands, `o2-r:4 o1-d-1:12 o1-d-2:16`, in the order of the bits; a field that
the layout splits is several pieces (`-1`, `-2`, from the top). A number of the sub-opcode that has no mnemonic is illegal (`?(sub < 30)`), a first parcel that no prefix matches is illegal.
A **form** (`form-LDU-B28 = o1:b4d28s-x1 o2:reg4`) lists the operand **shapes** of its leaves; a shape (`reg4 = r:4`, `b4d28s-x1 = base:4 d:28s`) is the operand as the assembly language
writes it, with the widths and signedness of its parts; its name carries what fields cannot say (the scale or unit of a displacement or an immediate, `sz` for "the size of the access").
The mnemonics of a leaf are the enum `sub-FORM-K = "movq" | "movl" | ...`, numbered by position. `forms = "SYS0"@0 | "SYSR" | ...` numbers the forms (the order in which the assembler
tries them), `hot3`, `hot4` are the hot-register tables, `regs` the register file, `fused` the fused instructions. The header of `pdp64-enc.hbnf` is the reference for all names.

Everything is generated from these files; nothing is written by hand twice:

    spec/pdp64-enc.hbnf, spec/pdp64-NN/pdp64-NN.hbnf
        --hbnf-->        parse_bits / emit_bits   the decoder of the encoding as hbnf writes it (tests/enc/hbdec.c checks the codec against it, see below)
        --tools/mkenc.py (reading the grammar through tools/encgram.py)-->
                         build/pdp64-NN-tab.c      the C tables of the codec (common/pdp64enc.c): forms, leaves, bit runs, mnemonics
                         build/pdp64-NN-hbfields.h the accessor that reads the raw fields out of hbnf's record (for the check)
                         build/x/*                 the assembly grammar of as64 (spec/ grammar + the new words + the registers r16-r31), the name tables
                         spec/pdp64-NN/tables.md   the leaves, for people (checked by `mkenc.py --check`)

What hbnf itself generates, and what it cannot. hbnf (the commit in `tools/build-hbnf.sh`, `dd34982` when this was written, with no local patch) reads these grammars as they are: bit fields of any width,
constants as prefixes, `name:N` widths, signed `s`, enum numbers, `?(expr)` checks, `bits(0)` for an operand with no bits, alternatives of 270 leaves. It generates from them a complete
decoder and encoder (`parse_bits`, `emit_bits`), which is what `tests/enc/hbdec.c` compares with the codec. What no hbnf template produces is the *table* the codec runs on (leaves, runs of
bits, the candidate forms of each mnemonic, in the order the assembler tries them): that is a small program, `tools/mkenc.py`, which reads the grammar (`tools/encgram.py`: the subset of
hbnf the grammars use, with every consistency check it can make: each leaf covers its 16n bits once, each field has the width its shape says, the mnemonic counts fit the sub-opcode bits,
the catalogue is dense, `insn` lists every leaf) and nothing else. No data file stands beside the grammar. hbnf has two gaps that the grammars work around (neither blocks anything; see
`docs/errata.md`, entry 89, for the upstream proposal): a rule name cannot hold a dot or slash, so the optimiser's form names (`LDI12/a`) are kept as literals of the catalogue and the rule
names are their spelling with `-`; and a grammar that mixes bit rules with string-enum rules is read as bits only if its first rule is a bit rule (`insn` is the first rule), and a bit rule
needs a field to count as one (`insn = leaf:( ... )`).

The optimiser (`docs/codegen-data/encoding/`) stays as the independent oracle: `tools/check-enc.py` lays the grammar's forms out again with the Python model (`enc.py`) and requires the
same prefixes and bit positions as the table, then compares the C codec with the model on boundary vectors of every mnemonic of every form. It is also the design tool that writes a
new grammar (`export_forms.py` calls `write_hbnf.py`); a grammar can equally be edited by hand. `tools/mkenc.py` verifies, independently of the optimiser, that the prefixes are a prefix
code, that each leaf covers its 16n bits exactly once and that no first parcel decodes to two leaves.

## Changing an encoding (the workflow)

1. Edit the grammar: by hand (`spec/pdp64-NN/pdp64-NN.hbnf`: a new leaf is a `leaf-FORM-K` rule with its prefix, fields and `sub-FORM-K` list, added to `insn`; a new form is a `form-` rule, a
   number in the catalogue and its leaves; the words and shapes shared by both are in `spec/pdp64-enc.hbnf`), or with the optimiser, on the output of the compiler for each encoding (a directory of the `.s` files of the 841-file corpus, `ccom -m pdp64/16` and `-m pdp64/32`):

       PDP64_CORPUS_DIR_NEW16=DIR16 PDP64_CORPUS_DIR_NEW32=DIR32 python3 docs/codegen-data/encoding/export_forms.py OUTDIR \
           --tag16 new16 --tag32 new32 --rounds 2 --lam 2 --keep-hot --refine 6 --cb3

   writes complete grammars to OUTDIR (`--rounds`: the distances are those of the previous round's layout; `--lam`: what a `cmp` + `bCC` costs beyond its bytes, in bytes; `--keep-hot`: the hot-register tables of the
   grammars in `spec/` are kept, they are the ABI; `--cb3`: offer three-parcel `cbCC`); compare with `diff -ru spec OUTDIR` and copy what is wanted (the three `.hbnf` files; `pdp64-enc.hbnf` changes with the shapes the forms use).
   Without options it reproduces the original study's grammars from its corpus. `cbreach.py`, `cbforms.py` and `distances.py` (same directory) report how many `cbCC` need the pair and why, the `cbCC` forms and the
   distances of the pc-relative operands; `reopt.py` runs one configuration for an ablation.
2. `tools/mkenc.py --md` rewrites the tables of `spec/pdp64-NN/tables.md`.
3. `tools/check-grammar-enc.sh` fails, naming the generated files that changed; after reading the differences, `tools/check-grammar-enc.sh --update` records them in `tests/enc/generated.sha256`.
   The same script runs hbnf on both grammars (syntax, references, widths), compares hbnf's decoder with the codec built from the new tables on 262,144 parcel sequences per encoding,
   and checks tables.md. If the leaves do not form a prefix code, or a field has the wrong width, `mkenc.py` or `encgram.py` say which rule.
4. `tools/check-enc.sh` (the codec against the Python model, the drift of every mnemonic through the assembler), then `tools/check-all.sh`. The vectors and assembler corpora derived from the
   forms (`tests/enc/vectors-NN.txt`, the ld64 and assembler tests) are rewritten by `docs/codegen-data/encoding/mk_vectors.py`, `mk_asm_tests.py`, `mk_ld_tests.py` (they read the grammar through `encgram`)
   and checked in (run all three after a change: the tests record nothing by hand, but their expected words are the model's); `asm_vs_model.py` (needs the corpus and `as64 --dump-lens` of each file) compares the real
   assembler with the model. What the checks record of the grammars is derived from them (the number of forms, leaves and unassigned first parcels is not written down anywhere); what stays written down is the ABI:
   the hot-register tables (`tools/check-drift-enc.py`).
5. Anything that depends on a layout (a compiler back end, QEMU, a disassembler) is generated from the same tables or the same grammar; if it is not, that is the bug.

The mnemonics are those of the original grammar (aliases included) plus the words only the new encodings have, which the rule `mn-ext` of `pdp64-enc.hbnf` lists (`mkenc.py` checks the list against the words the leaves use) as the group `mn-ext`
of the grammar as64 reads (`build/x/pdp64-mnemonics.hbnf`): `maskeqz masknez bsel aeses aesesm aesds aesdsm aesks1 aesks2 aesim sha256* sha512* msha256 msha512 maesctr addv subv mulv
movql trapcc.<cc> syspg0-5`, the user-qualified moves `movq.u movq.d movq.ud ...`, and the fused `movcall popmret popret mov2`. In `-m pdp64/r20` they are refused.

## The model in two paragraphs

An instruction is one to five 16-bit parcels (little-endian in memory); its length is a function of parcel 0 alone. The top bits of parcel 0 are a prefix of 1 to 16 bits
that selects a *leaf*: a group of mnemonics with one form (operand shapes and field widths); a sub-opcode field inside the leaf (binary-aligned) selects the mnemonic.
Register fields start at bit 0 of parcel 0 and go up (the last register operand lowest), displacements and immediates fill the rest, the widest field last, so in the later parcels.
No bit is padding: an unused sub-opcode, or a hot-register index beyond the table, decodes as an illegal instruction. 5.0% of the first-parcel patterns (3,277 of 65,536 in pdp64/16, 3,278 in pdp64/32) are unassigned
and illegal.

The assembler picks, for each instruction, the first form in the table's order (shorter first, then the order of the catalogue `forms`) whose fields can hold the operands, and relaxes
(lengths only grow; every distance is measured on the layout of the previous pass, which is the iteration of the model). A branch, call or `d(PC)` operand is measured in bytes
from the first parcel of the instruction; the field counts parcels for branches and calls (unit 2) and bytes for the memory forms (unit 1). An unresolved symbol needs a form with a field
of 32 bits or more and a relocation; the relocation types are those of `as64/relocs.h`, the linker finds the field through the codec.

## Operand notation and the choices the tables imply

* `(r)+` and `-(r)` without a stride write stride 0, which means the size of the access (8 outside the moves); `(r)+8` writes 8.
* `pushm`, `popm`, `popmret` take a register mask; a mask is the low 32 bits of the number (so `#-16740608` is a mask of r31...); in pdp64/16 only bits 0-15 exist.
* `set cc, rd`: 4 bytes (`SETF`). `trap #n`, `trapl #n`, `spl #n`, `hint #n`: one parcel with an 8-bit number. `trapcc.<cc>`: one parcel, no operand.
* ATOM (assumed, section 3.2 of the proposal): three registers (`xadd`... `ll`, `sc`) and four (`cas`, `casdb`), the memory address in a register, operands in the order written. The roles of the registers
  are the ISA's to fix; the encoding only fixes where they sit.
* `cbCC` for which no form reaches (an external label, an operand pair no form holds) is assembled as `cmp` + `bCC`. **This writes the flags**, which `cbCC` does not (the compiler forms a `cbCC` only where the flags are dead), and it
  executes two instructions for one. There are three lengths of `cbCC`: one parcel (compare with 0, a pc field of 4 to 7 bits), two (an immediate of 3 to 10 bits, or two registers, with a pc field of 8 to 14 bits) and three (a 16-bit immediate with a
  12-bit pc field, an 8-bit immediate with a 20-bit pc field, two registers with a 24-bit pc field: a target up to 4 KB, 2 MB, 32 MB away). The pc field counts parcels. On the 841-file corpus of the compiler (`pcc-enc` abacdf17) 4 of
  34,387 sites (pdp64/16) and 17 of 34,524 (pdp64/32) still need the pair (`docs/encoding-proposal.md`, section 12, which also says why a two-parcel `cbCC` could not carry them).
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

    tools/mkenc.py [--md] [--check]      generate the tables (build/) from the grammars, rewrite or check spec/pdp64-NN/tables.md
    tools/check-grammar-enc.sh [--update]  hbnf accepts the grammars; regenerate everything and compare with the checked-in files; hbnf's decoder against the codec
    as64 -m pdp64/16|pdp64/32|pdp64/r20 [-o obj] file.s [--stats] [--dump-lens file] [--no-relax]
    ld64 [--no-relax] [--stats] [--dump-map file] [-M] [-o out] objects...       (relaxation objects are relaxed; docs/relaxation.md)
    tools/check-relax.sh [--mutate]      relaxation: generated program relaxed and not, decoder-based check of every relaxed image, mutants of ld64
    tools/check-enc.sh                   mkenc --check, codec against the model, drift test of every mnemonic (and check-grammar-enc.sh)
    python3 docs/codegen-data/encoding/export_forms.py OUTDIR     rerun the optimiser: writes the grammars (needs the corpus)
    python3 docs/codegen-data/encoding/asm_vs_model.py 16|32 outdir          real assembler against the model on the corpus (needs the corpus)

## Linker relaxation

`as64` marks an object (by default for pdp64/16 and pdp64/32; `--no-relax` gives the plain object) (`e_flags` 0x10, `EF_PDP64_RELAX`; 0x20, `EF_PDP64_NOADJ_TEXT`, if its `.text` holds a distance that is not a relocation) and gives every
instruction that holds the address of a symbol a relocation, local symbols too, and every padding of `.text` an `R_PDP64_ALIGN` (type 6; addend = padding bytes << 32 | alignment).
`ld64` then picks, for each such instruction, the shortest form of the codec that reaches, after laying the sections out, and moves everything behind it (the lengths
only grow from the shortest form, so the iteration ends; paddings are recomputed from the positions).  The reach of the forms is in the tables (`call`: 4 bytes up to
+-1 MiB, `lea` and pc-relative loads: 4 bytes up to +-32 KiB, branches 2 bytes up to 64 to 512 bytes, 4 bytes +-64 KiB; the proposal's "+-2 MB" for `call` was twice the
reach of the 20-bit field counted in parcels).  Objects made with `--no-relax` are linked as before; `ld64 --no-relax` links relaxation objects exactly as the assembler
laid them out.  Details, the argument that it ends and is right, what it cannot do, the checks and the measurements: `docs/relaxation.md`.

Not part of this phase: the simulator.


## The manual's charts

`spec/pdp64-layout.hbnf` names the fields of pdp64/r20 for the bit-layout charts of the manual (what `reg` and `low` are for in each class of instruction); the fields themselves are the bit rules of `spec/pdp64.hbnf.in`. The charts of pdp64/16 and pdp64/32 need nothing beyond their grammars. `tools/mkmanual.py` draws them (`tools/manual/layouts.py`); a change to a field in a grammar changes the chart, and `tools/mkmanual.py --check` fails until the manuals are regenerated.
