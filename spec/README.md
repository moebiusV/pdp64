# spec/: the grammars and the tables of the encoding

The pdp64 has one CPU: 32 registers (`r0`-`r31`) and a prefix-coded instruction encoding (the author, 2026-11-10, errata 122). Two earlier iterations of the design, an encoding with sixteen registers in which parcel 0 is `len:2 opc:6 reg:4 low:4` (pdp64/r20) and a prefix-coded one with sixteen registers (pdp64/16), were built and measured against it and superseded; their grammars, tools and tests are in the git tags `pre-single-cpu` and `pre-code-removal`, and the measured comparison is in `docs/encoding-work/`.

The opcodes, prefixes and field positions may still change once the open items are decided and the encoding optimiser is run again; the grammars are then updated, and everything generated from them (the assembler tables, the tables of chapter 9 of the manual, the headers of the compiler) is regenerated. No document states these numbers in prose: they point to the generated tables.

| file | what it is |
|---|---|
| `pdp64/pdp64.hbnf` | the encoding: registers, the hot-register tables, the catalogue of 207 forms and 268 leaves (the source of truth of every bit position) |
| `pdp64-enc.hbnf` | its vocabulary: the operand shapes, the sizes of the moves' access, the numbered words of group `mn-ext` |
| `pdp64-mnemonics.hbnf` | every number: the words of the instructions, their numbering by group and sub-opcode (the numbers the executor and the manual use), the registers, conditions and system registers |
| `pdp64-asm.hbnf` | the syntax of the assembly language |
| `pdp64-system.hbnf` | System v1: the status word, the vectors, the page-table entry, the devices |
| `elf.hbnf` | the records of the ELF object file |

The object files and executables carry `EF_PDP64_ISA` (2) in the low four bits of `e_flags` (`as64/relocs.h`); `ld64` and `sim64` refuse a file that names another instruction set (the earlier iterations used 0 and 1).

The design, its measurements and the reasons are in `docs/encoding-proposal.md`; the scripts that produced the tables are in `docs/codegen-data/encoding/`.

## The grammars of the new encodings

The principle of the project is that the toolchain is written from one source of truth, a set of hbnf grammars, so that the assembler, the linker, the emulator, the
compiler back end and the QEMU target cannot drift apart. the encoding follows it: it is an hbnf grammar,

    spec/pdp64-enc.hbnf              the operand shapes, the sizes of the moves' access, the numbered words of group mn-ext, and the vocabulary (its header)
    spec/pdp64/pdp64.hbnf            the registers, the hot tables, the catalogue of 207 forms, 268 leaves

An instruction is a bit record read from the top bit of parcel 0 (each parcel big-endian). A **leaf** is one alternative of `insn`: the prefix as a
constant (`0b0010`: 1 to 16 bits, as wide as its digits), the sub-opcode `sub:J`, and the pieces of the operands, `o2-r:4 o1-d-1:12 o1-d-2:16`, in the order of the bits; a field that
the layout splits is several pieces (`-1`, `-2`, from the top). A number of the sub-opcode that has no mnemonic is illegal (`?(sub < 30)`), a first parcel that no prefix matches is illegal.
A **form** (`form-LDU-B28 = o1:b4d28s-x1 o2:reg4`) lists the operand **shapes** of its leaves; a shape (`reg4 = r:4`, `b4d28s-x1 = base:4 d:28s`) is the operand as the assembly language
writes it, with the widths and signedness of its parts; its name carries what fields cannot say (the scale or unit of a displacement or an immediate, `sz` for "the size of the access").
The mnemonics of a leaf are the enum `sub-FORM-K = "movq" | "movl" | ...`, numbered by position. `forms = "SYS0"@0 | "SYSR" | ...` numbers the forms (the order in which the assembler
tries them), `hot3`, `hot4` are the hot-register tables, `regs` the register file, `fused` the fused instructions. The header of `pdp64-enc.hbnf` is the reference for all names.

Everything is generated from these files; nothing is written by hand twice:

    spec/pdp64-enc.hbnf, spec/pdp64/pdp64.hbnf
        --hbnf-->        parse_bits / emit_bits   the decoder of the encoding as hbnf writes it (tests/enc/hbdec.c checks the codec against it, see below)
        --tools/mkenc.py (reading the grammar through tools/encgram.py)-->
                         build/pdp64-tab.c         the C tables of the codec (common/pdp64enc.c): forms, leaves, bit runs, mnemonics
                         build/pdp64-hbfields.h    the accessor that reads the raw fields out of hbnf's record (for the check)
                         build/x/*                 the assembly grammar of as64 (spec/ grammar + the new words + the registers r16-r31), the name tables
                         spec/pdp64/tables.md      the leaves, for people (checked by `mkenc.py --check`)

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

1. Edit the grammar: by hand (`spec/pdp64/pdp64.hbnf`: a new leaf is a `leaf-FORM-K` rule with its prefix, fields and `sub-FORM-K` list, added to `insn`; a new form is a `form-` rule, a
   number in the catalogue and its leaves; the shapes are in `spec/pdp64-enc.hbnf`), or with the encoding optimiser, which reads the compiler's assembly for the 841-file corpus and writes complete grammars (`tools/encopt`; its translation from the Python original to C, with optimal algorithms, is a work item, and it is to be run again once the decisions that affect the opcodes are made and the mnemonics are settled; see `handoff.md`, the order of work). The Python scripts of the two-grammar period in `docs/codegen-data/encoding/` are the original and are history: those that read two grammars by tag run from the git tag `pre-code-removal` (`docs/codegen-data/encoding/README.md`). Compare a new grammar with `diff -ru spec OUTDIR` and copy what is wanted (the grammar `pdp64/pdp64.hbnf`; `pdp64-enc.hbnf` changes with the shapes the forms use). The hot-register tables of the grammar are the ABI and are kept unless the author decides otherwise.
2. `tools/mkenc.py --md` rewrites the tables of `spec/pdp64/tables.md`.
3. `tools/check-grammar-enc.sh` fails, naming the generated files that changed; after reading the differences, `tools/check-grammar-enc.sh --update` records them in `tests/enc/generated.sha256`.
   The same script runs hbnf on the grammar (syntax, references, widths), compares hbnf's decoder with the codec built from the new tables on 262,144 parcel sequences,
   and checks tables.md. If the leaves do not form a prefix code, or a field has the wrong width, `mkenc.py` or `encgram.py` say which rule.
4. `tools/check-enc.sh` (the codec against the Python model, the drift of every mnemonic through the assembler), then `tools/check-all.sh`. The vectors and assembler corpora derived from the
   forms (`tests/enc/vectors.txt`, the ld64 and assembler tests `tests/ld`, `tests/asm`) are rewritten by `docs/codegen-data/encoding/mk_vectors.py`, `mk_asm_tests.py`, `mk_ld_tests.py` (they read the grammar through `encgram`)
   and checked in (run all three after a change: the tests record nothing by hand, but their expected words are the model's); `asm_vs_model.py` (needs the corpus and `as64 --dump-lens` of each file) compares the real
   assembler with the model. What the checks record of the grammars is derived from them (the number of forms, leaves and unassigned first parcels is not written down anywhere); what stays written down is the ABI:
   the hot-register tables (`tools/check-drift-enc.py`).
5. Anything that depends on a layout (a compiler back end, QEMU, a disassembler) is generated from the same tables or the same grammar; if it is not, that is the bug.

The mnemonics are those of the original grammar (aliases included) plus the words only the new encodings have, which the rule `mn-ext` of `pdp64-enc.hbnf` lists (`mkenc.py` checks the list against the words the leaves use) as the group `mn-ext`
of the grammar as64 reads (`build/x/pdp64-mnemonics.hbnf`): `maskeqz masknez bsel aeses aesesm aesds aesdsm aesks1 aesks2 aesim sha256* sha512* msha256 msha512 maesctr addv subv mulv
movql trapcc.<cc> syspg0-5`, the user-qualified moves `movq.u movq.d movq.ud ...`, and the fused `movcall popmret popret mov2`. They have no number in the original numbering of `pdp64-mnemonics.hbnf`.

## The model in two paragraphs

An instruction is one to five 16-bit parcels (little-endian in memory); its length is a function of parcel 0 alone. The top bits of parcel 0 are a prefix of 1 to 16 bits
that selects a *leaf*: a group of mnemonics with one form (operand shapes and field widths); a sub-opcode field inside the leaf (binary-aligned) selects the mnemonic.
Register fields start at bit 0 of parcel 0 and go up (the last register operand lowest), displacements and immediates fill the rest, the widest field last, so in the later parcels.
No bit is padding: an unused sub-opcode, or a hot-register index beyond the table, decodes as an illegal instruction. The first-parcel patterns that match no prefix are illegal instructions (the count is in `tables.md` and manual 9.1.5).

The assembler picks, for each instruction, the first form in the table's order (shorter first, then the order of the catalogue `forms`) whose fields can hold the operands, and relaxes
(lengths only grow; every distance is measured on the layout of the previous pass, which is the iteration of the model). A branch, call or `d(PC)` operand is measured in bytes
from the first parcel of the instruction; the field counts parcels for branches and calls (unit 2) and bytes for the memory forms (unit 1). An unresolved symbol needs a form with a field
of 32 bits or more and a relocation; the relocation types are those of `as64/relocs.h`, the linker finds the field through the codec.

## Operand notation and the choices the tables imply

* `(r)+` and `-(r)` without a stride write stride 0, which means the size of the access (8 outside the moves); `(r)+8` writes 8.
* `pushm`, `popm`, `popmret` take a register mask; a mask is the low 32 bits of the number (so `#-16740608` is a mask of r31...).
* `set cc, rd`: 4 bytes (`SETF`). `trap #n`, `trapl #n`, `spl #n`, `hint #n`: one parcel with an 8-bit number. `trapcc.<cc>`: one parcel, no operand.
* ATOM (assumed, section 3.2 of the proposal): three registers (`xadd`... `ll`, `sc`) and four (`cas`, `casdb`), the memory address in a register, operands in the order written. The roles of the registers
  are the ISA's to fix; the encoding only fixes where they sit.
* `cbCC` for which no form reaches (an external label, an operand pair no form holds) is assembled as `cmp` + `bCC`. **This writes the flags**, which `cbCC` does not (the compiler forms a `cbCC` only where the flags are dead), and it
  executes two instructions for one. There are three lengths of `cbCC`: one parcel (compare with 0, a pc field of 4 to 7 bits), two (an immediate of 3 to 10 bits, or two registers, with a pc field of 8 to 14 bits) and three (a 16-bit immediate with a
  12-bit pc field, an 8-bit immediate with a 20-bit pc field, two registers with a 24-bit pc field: a target up to 4 KB, 2 MB, 32 MB away). The pc field counts parcels. On the 841-file corpus of the compiler (`pcc-enc` abacdf17) 17 of
  34,524 sites still need the pair (`docs/encoding-proposal.md`, section 12, which also says why a two-parcel `cbCC` could not carry them).
* `movq #imm, rd` whose constant fits no `movq` form is assembled as `movql`, a ten-byte instruction with the 64-bit immediate.
* The 22 meaningless shapes the original assembler accepts (`clr/com/inc/dec/neg/tst/adc/sbc/asl/asr/jmp/call/pop/jmpi/calli #imm`, `movq/movl/movw/movb r,#imm`, `lea #imm,r`, `sob r,#imm`, ...) are refused.
* The assembler never fuses. The fused instructions are ordinary mnemonics with operands: `movcall rs, rd, label` (`movq rs,rd ; call label`, the target measured from the first parcel of the fused instruction),
  `popmret #mask`, `popret rd`, `mov2 ra, rb, rc, rd` (`movq ra,rb ; movq rc,rd`, all four in the hot-8 table). Choosing them is the compiler's job.
* `extb/extzb/insb` have 6-bit position and width: a width of 64 is refused. The MESC words (`movub... bism`) exist only in the 3-parcel memory forms (the optimiser selected no narrower one: no use in the corpus).

## The hot-register tables (part of the ABI, docs/abi.md)

A 3-bit register field in a one-parcel form is an index, not a register number: `r0 r1 r8 r2 sp r3 r9 r10`.
There are also 4-bit fields: `r0 r1 r8 r2 sp r3 r9 r10 r11 r4 r15 r5 r24 r25 r26 r6` (`r24`-`r26` are hot registers; their roles are in the ABI, appendix D);
A different register allocation changes the sizes, not the correctness. `mov2` needs all four registers in the 3-bit table.

## Commands

    tools/mkenc.py [--md] [--check]      generate the tables (build/) from the grammars, rewrite or check spec/pdp64/tables.md
    tools/check-grammar-enc.sh [--update]  hbnf accepts the grammars; regenerate everything and compare with the checked-in files; hbnf's decoder against the codec
    as64 [-o obj] file.s [--stats] [--dump-lens file] [--no-relax]
    ld64 [--no-relax] [--stats] [--dump-map file] [-M] [-o out] objects...       (relaxation objects are relaxed; docs/relaxation.md)
    tools/check-relax.sh [--mutate]      relaxation: generated program relaxed and not, decoder-based check of every relaxed image, mutants of ld64
    tools/check-enc.sh                   mkenc --check, codec against the model, drift test of every mnemonic (and check-grammar-enc.sh)
    tools/encopt                        the encoding optimiser (see its README; to be run again after the open items are decided)

## Linker relaxation

`as64` marks an object (by default; `--no-relax` gives the plain object) (`e_flags` 0x10, `EF_PDP64_RELAX`; 0x20, `EF_PDP64_NOADJ_TEXT`, if its `.text` holds a distance that is not a relocation) and gives every
instruction that holds the address of a symbol a relocation, local symbols too, and every padding of `.text` an `R_PDP64_ALIGN` (type 6; addend = padding bytes << 32 | alignment).
`ld64` then picks, for each such instruction, the shortest form of the codec that reaches, after laying the sections out, and moves everything behind it (the lengths
only grow from the shortest form, so the iteration ends; paddings are recomputed from the positions).  The reach of the forms is in the tables (the reach of each form is in `spec/pdp64/tables.md` and the manual's dictionary; manual 9.5.5 states the reach of the four-byte `call`, `lea` and branch forms).  Objects made with `--no-relax` are linked as before; `ld64 --no-relax` links relaxation objects exactly as the assembler
laid them out.  Details, the argument that it ends and is right, what it cannot do, the checks and the measurements: `docs/relaxation.md`.


## The manual's charts

`tools/mkmanual.py` draws the bit-layout charts of the manual from the grammar (`tools/manual/layouts.py`); a change to a field in the grammar changes the chart, and `tools/mkmanual.py --check` fails until the manual is regenerated.
