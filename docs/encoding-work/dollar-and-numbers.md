# The immediate marker `$` and the numbers: a survey (phase 1, nothing built in the tree)

I decided nothing new here and built what the owner chose after this survey: the immediate is written `$expr` everywhere in the live manual, documents and generators (the assembler still reads `#expr` as the same thing); a number is decimal or `0x`, `0o`, `0b` in lower case and a number with a leading zero is an error that names `0o`; the PDP-11 octal of the manual is written `0o...` and the C64 addresses `0x...`; the NASM suffixes, `$` and `$$` as locations are gone from the assembler and from its description. The text below is the survey as I wrote it, and is not changed.

[← pdp64 index](../../README.md)

This is the survey for errata 233 and R555. I changed no tracked file and committed nothing; this note is the only new file in the tree. Every experiment ran in a scratch copy
(`/tmp/claude-1000/-home-matthew-claude-pdp64/832cbac5-5e29-461e-9610-ca42cce0b602/scratchpad/dollar/`: `ref/` is the assembler as it is, `new/` is the assembler with the lexer changed as the owner decided).
Counts are lines found by regular expression and are marked approximate where the text is prose.

One fact about the reference: when I started, the working tree held uncommitted fcvt work; while I worked it was committed as `b16b6805`, and `git status` shows no tracked change now. The scratch `ref/` was copied from the tree after that commit, so it is the working-tree assembler and the current HEAD at once.

## 0. What I did to the lexer in the scratch copy

* `immop = ( "$" | "#" ) expr` (the same alternative; `$` is now the first spelling).
* Removed from `primary`: the NASM `$` and `$$` (rule `dollar`), and every number with a suffix (`suffnum`: `h`, `b`, `q`, `o`, `d`, `t`).
* A number that is all digits and begins with `0` and has a second digit (`077`, `08`, `00`) is a new alternative `badnum`; `as64/asmp.c` turns it into the error "a number with a leading zero: write 0o for octal".
* `as64/asmp.c`: `digit_name` lost its suffix cases; the walk reports `lex_err`.
* Nothing else. The scratch assembler passes `tools/check-as64.sh` except the four tests that exist to prove the dropped spellings (section 4.1), and the 202 test sources of the tree that assemble today assemble to the same objects.

## 1. Every construct that involves `$ # % @ .` and the numbers, today

Source: `spec/grammars.d/60-asm-syntax.hbnf`, `as64/asmp.c`, `as64/as64.c` (the evaluator), and an experiment for each row (a line assembled by `ref` and by `new`).

| construct | what it means today | conflict with `$` as the marker, or with the new number rules | what happens to it |
|---|---|---|---|
| `$expr` | immediate (errata 139); `$5`, `$-1`, `$(3+4)`, `$x+1`, `$ 5` (a blank is allowed) | it is the marker | **kept, official** |
| `#expr` | immediate, the original spelling (MACRO-11) | none | **kept as alias** |
| `$` alone (an operand or inside an expression) | NASM and MASM: the location counter (`dq $`, `.word $-.`, `mov $, r1` is pc-relative) | conflicts: at the start of an operand `$-2` is the immediate -2, so `$` in an operand never meant "here" in a sum; two meanings of one character | **dropped**; the location counter is `.` (V7) |
| `$$` | NASM: start of the section (`times 510-($-$$) db 0`); as an operand it already reads as the immediate of `$` | conflicts | **dropped**; no spelling is left for "start of the section": a label at the start does it |
| `$FF`, `$1F`, `$D000` (Turbo Pascal and ca65 hexadecimal) | **never worked.** It is the immediate of the symbol `FF`: assembles with no error and a relocation to an undefined symbol. In `x = $FF` it is a syntax error. `$D000` is the symbol `D000` | the very conflict the owner named | nothing to take out of the lexer; **see 2.4 (a silent trap)**. `$0x1F` is the right spelling |
| `$name` for a symbol | immediate of the symbol (`mov $x, r1`) | none | kept |
| `$` inside a name | allowed after the first character (`a$b`, `x$:`, `_x$1`); not first (`$x:` is refused) | none: `$` never begins a name, so `$x` cannot be a symbol | kept (V7 does not allow it; see 5.2) |
| `%` before a register (`%r1`, `(%sp)`) | means nothing, AT&T's | none (AT&T writes `$5, %r1`) | kept (not in the owner's list) |
| `%` as the operator | modulo | none | kept |
| `%1010` (ca65 binary) | **never worked**: error "expected rbody" | would conflict with the register prefix and the modulo | nothing to take out |
| `0x1F`, `0X1F` | hexadecimal; both cases of the `x` | none | `0x` kept; **`0X` needs the owner's word** (section 6) |
| `0b101`, `0B101` | binary | none | `0b` kept; uppercase: owner |
| `0o17`, `0O17` | octal | none | `0o` kept; uppercase: owner |
| `077`, `010`, `08` | **decimal** (77, 10, 8): a silent reading that is not C's | the new rule | **an error that names `0o`** (tested: "a number with a leading zero: write 0o for octal") |
| `0` | zero | none | kept (a lone `0` is not an error) |
| `0A6h`, `0FFh`, `A6h`, `10H` | hexadecimal suffix (errata 162) | conflicts with names (`A6h`, `ch` were unusable names, errata 163) | **dropped**; `A6h`, `ch`, `deadh` become ordinary names again (tested: `A6h: nop` assembles) |
| `1010b` | the binary number, unless a numeric label 1010 is defined before it (then the label) | conflicts with the local label `Nb` | **dropped as a number**; it is only the local label (tested: with no label 1010: "undefined local label 1010b") |
| `17q`, `17o` | octal suffix | none | dropped |
| `10d`, `10t` | decimal suffix | none | dropped |
| `1f`, `1b`, `10b`, `0b` | local label forward and backward (V7 had one digit; as64 has any number of digits) | `0b` and `0b101`: the label 0 backward, and the binary prefix. The binary prefix needs a digit after it, so `0b` alone is the label and `0b1` is a number | kept; `Nb` is now only a label |
| `N:` | numeric local label (digits only) | none; `007:` is accepted as label 7-with-zeros, which the number rule does not touch (a label is not an expression) | kept |
| `3dfx`, `5$`, `0b2`, `0o8`, `1e5`, `07abc` | names (a bareword that is not a whole number is a name) | none | kept; they are silently a symbol, as before |
| `'a'`, `'\n'`, `'\x41'` | C character constant | none (`'` is not `$`) | kept (V7 writes `'a` with no closing quote: not adopted) |
| `'abcd'` | NASM's constant of up to eight characters | none | kept |
| `"text"`, `` `text\n` ``, `'text'` | strings in `.ascii`, `db` | none | kept |
| `@name`, `@0x10` | absolute mode | `@$name` is refused today (the `$x` after `@` is not an expression); `$@x` is refused | kept, as the owner said |
| `=expr` | literal pool | none | kept |
| `.` | location counter (and a name may start with `.`: `.L1`) | none | kept, now the only spelling |
| `^` | exclusive or (V7: "value of the first, type of the second") | none | kept |
| `!` | binary or-not (`a ! b` is `a \| ~b`), unary not | none | kept |
| `<x`, `>x` | unary low byte and high byte (6502) | none (V7 writes `\<` and `\>` for shifts; `<` and `>` begin strings in V7) | kept |
| `[ ]` | grouping | none | kept |
| `/`, `//`, `;` | division; comment; comment | none | kept |
| NASM statements that use the dropped forms | `times n db v` (the count may use `$`, `$$`) | `times` itself has no conflict | `times` stays, its documented use `($-$$)` goes; use `.fill`, or `.-label` |
| `db dw dd dq`, `equ`, `proc`, `endp`, `section`... | MASM and NASM statements | none | kept |
| `.encode N`, `.equ`-style `x equ 0x10` | no `$` or `#` of their own | none | kept (tested: `x equ 0x10` then `mov $x, r1` works) |
| macros | there are none (errata 164) | none | n/a |
| vector words (`vadd.w v1, v2, $5`) | the immediate of a vector word | none | tested: `$` and `#` give the same bytes in `vadd`, `vsub`, `vclr`, `cbeq`, `ror.s32`, `trap`, `rti`, `push` |

Dead code in `as64/as64.c` and `as64/asmir.h` if this is built: `XN_SECT` (`$$`), `sect_sym[]` and the `.$$N` symbols (`as64.c` lines 183, 329, 1123), `XN_BINLBL` (the binary-or-label rule). `XN_DOT` stays (`.`).

## 2. The ambiguity risks of `$`, each tested in the scratch assembler

2.1. **`$` in a name.** `$` is a name character after the first (`a$b`), never the first. So `$x` is never a symbol and always the immediate of `x`: no ambiguity. A name that *starts* with `$` has to be written in double quotes (`"$x"`), as any odd name. I recommend keeping `$` inside names: a C name with `$` (a GNU extension) has to come through, and it costs nothing. One consequence: `r1,$5` is fine (comma), but `a$5` is one name, so no one may write an immediate right after a name without a separator, which no one does.

2.2. **`$` before a register.** `$r1` is a syntax error (a register is not an expression). `$sp` and `$fp` are not errors: they are the immediate of a *symbol named* `sp` (a relocation), because `sp` and `fp` are not caught by the "r followed by digits" rule in `symbol`. This is the same today with `#sp`. I would make `$sp`, `$fp`, `$pc` errors ("a register is not a constant"); owner's decision, small.

2.3. **`$` before an expression.** `$-1`, `$(a+b)`, `$x+1`, `$.+4`, `$'a'`, `$0x1f` are all the immediate of that expression. `$ 5` with a blank is the same. `$$` is no longer anything. `4+$5` or `.byte 1, $2` is an error (an immediate marker has no place in a sum or in data): the message is now the generic "expected ... found $"; I would give it its own text.

2.4. **The silent trap.** `$FF`, `$D000`, `$0FFh`, `$A6h`, `$10q`, `$10d` all assemble **without an error**: each is the immediate of a symbol of that name, an undefined symbol that `as64` makes external and only the linker refuses. This was already true of `$FF` and `#FF`; dropping the `h q d` suffixes widens it (`#0FFh` was a number, now it is a symbol). I recommend two refusals with a message in the lexer: a bareword that is digits followed by hex digits and `h`/`H` ("write 0xFF"), and a bareword `[0-7]+[qQoO]`, `[0-9]+[dDtT]` (it is a name only if it has a letter that cannot be a suffix, so these are the old numbers). `$FF` itself cannot be told from a symbol `FF`; the linker's "undefined symbol FF" has to do, and the manual says so.

2.5. **`cbCC rd, $imm, label`.** Same bytes as `#imm` (tested with `$5`, `$-5`). A symbol as the second operand (`cbeq r3, $x, 1f`) is refused by the form, as with `#`.

2.6. **`.byte` and `.word`.** An immediate has no place in data. `.byte $` and `.byte $$` were errors ("a symbol only in .long and .quad") and now are syntax errors; `.word .-x` is the way to a distance (tested).

2.7. **`.encode`, `.equ`, macros.** `.encode 3` then `mov $5, r1` is the same as `#5`. `x equ 0x10`, `x = 0x10`, `.if x` and `$x` work. `x = $FF` is a syntax error before and after. There are no macros. In a `.S` file (the C preprocessor) the marker matters, see 4.6.

2.8. **Hex digits in `0x` numbers.** `0xb`, `0x1b` are hexadecimal in `ref` and in `new` (the `0x` prefix is taken before the local-label rule). `1b` is a label reference, `0x1b` is 27. With the suffixes gone, a local label can no longer be taken for a binary number, which is the one overlap errata 162 had to settle by "a defined label wins"; that rule disappears.

2.9. **Vector prefix `vec` and the vector words.** The vector instructions take `$imm` exactly as `#imm` (tested: `vadd.w v1, v2, $5`, `vsub.w v1, v1, $-1`). `vecinsn` is written before `instruction` in the grammar and reads its immediates through the same `immop`: nothing to change there. `$` before `v0` is a syntax error, as `#v0`.

2.10. **Leading zero and the local labels.** The number rule is on expressions, not on labels: `007:`, `01f` still parse (as the numeric label 7 and the forward reference to label 1). I suggest to leave them. `00` is an error like `08`.

## 3. The list of dropped spellings, for the owner

The count columns are lines in tracked files (approximate for prose): **S** test sources and sources of the tree that assemble, **G** generators and tools, **M** the manual (`docs/manual-src`, `tools/manual`, and the generated `docs/manual`), **D** other documents.

| spelling | example | from | S | G | M | D |
|---|---|---|---|---|---|---|
| `$` as the location counter | `dq $`, `.word $-.` | NASM, MASM | 1 (`tests/asm-equiv/nasm.new.s`) | `as64.c` | appendix D, 1 | `docs/asm-syntax.md`, errata 162 |
| `$$` start of section | `times 64-($-$$) db 0` | NASM | 1 (same file) | `as64.c` (3 lines) | appendix D (same line) | `docs/asm-syntax.md` |
| hexadecimal suffix `h` | `0FFh`, `0A6h`, `A6h` | NASM, MASM | 6 lines in 2 files (`nasm.new.s`, `nasm-numbers.new.s`); 1 refusal test `asm-err/number-label.s` | 0 | 0 | the same in `asm-syntax.md`, errata 162 and 163, R462 |
| binary suffix `b` | `1010b`, `101b` | NASM, MASM | 5 lines in the same 2 files (the label uses `1b`, `10b` are not touched) | 0 | 0 | the same |
| octal suffix `q`, `o` | `17q`, `377q` | NASM | 2 lines (`nasm-numbers.new.s`, `nasm.new.s`) | 0 | 0 | same |
| decimal suffix `d`, `t` | `10d`, `255d` | NASM | 2 lines | 0 | 0 | same |
| `$FF` hexadecimal | `$FF`, `$D000` | Turbo Pascal, ca65, 6502 | 0 (never worked) | 0 | 0 | the C64 chapters use `$D000` in prose for C64 addresses (about 10 lines in `docs/manual-src/03-graphics.md`, `docs/c64-devices-from-chat.md`, `tools/manual/gfxfigs.py`): these describe the C64 and are not assembler text; the owner decides if they stay |
| `%1010` binary | `%1010` | ca65 | 0 (never worked) | 0 | 0 | 0 |
| a leading zero as octal, or silently as decimal | `010`, `077`, `0377` | C, V7 `as` (octal by default) | **0** in every `.s`, `.S`, `.inc` and generator | 0 | see below | see below |
| uppercase prefixes `0X 0B 0O` | `0X1F` | C | 0 | 0 | 0 | 0 (owner: drop or keep) |

The leading-zero numbers that do exist are PDP-11 octal in prose and figures, never assembler input: `docs/manual-src` (67 occurrences in 8 files: `0177560`, `0177400`, `0220`, `0377`, the interrupt-vector tables), `tools/manual/*.py` (10 in 7: `bootfigs.py`, `busfigs.py` `drvfigs.py`, `introfigs.py`, `kernfigs.py`: `0757777`, `012120`, `0224`), `docs/annex` (21 in 5: the vector table with `/ 060 console keyboard`), `docs/*.md` (222 in 23), `docs/design` (23 in 10), `docs/encoding-work/*.md` (242 in 36). All are the PDP-11's own octal; the owner says if they become `0o177560` in the manual (I think the manual should: a reader copies them) or stay as history.

Also, of other spellings the owner has not named, that stay: `%reg`, `<x >x`, `!`, `[ ]`, `equ`, `db dw dd dq`, `proc/endp`, `times`, `section`, `'abcd'`. Their use in sources today: `%reg` 8 lines, `@name` 2, `'c'` 3, `<`/`>` 1, `!` 1, `[ ]` 14, `equ` 2, `db dw dd dq` 5, `times` 2, `section` 7.

## 4. The blast radius of `#` to `$`

### 4.1 What breaks in the scratch assembler with the lexer alone

The tests of the tree, run with the scratch `new` assembler (`tools/check-as64.sh`): only four fail, all of them the tests of the dropped spellings: `tests/asm-equiv/nasm.new.s`, `tests/asm-equiv/nasm-numbers.new.s` (to delete or rewrite), `tests/asm-err/number-assign.s` and `number-label.s` (they prove "`A6h` is a number, so it cannot be a label": the opposite is now true). `tests/asmsyntax.c` passes unchanged. A sweep of every tracked `.s` and `.S` (preprocessed) that assembles today (202 files, `docs/encoding-work` historic ones excluded: 135 do not assemble even today, they use withdrawn words such as `movq`) gives byte-identical objects with `new`: no test source holds a leading zero, a suffix number or a `$` location.

### 4.2 Lines that write the `#` immediate today (approximate; every one stays accepted, every example is rewritten)

| place | lines | files | how it is made |
|---|---|---|---|
| `tests/sim/*.s`, `*.S` | 28,088 | 92 | `.s` generated by `gen_*.py` and checked in (e.g. `fma-negate.s` 36,571 lines, `absminmax.s` 19,369, `nocc.s` 12,655) |
| `tests/qemu/*.S`, `*.inc` | 17,219 | 38 | hand-written and `gen_hv_stage2.py` |
| `tests/sec-open`, `tests/sec` | 110 + 67 (py) | 5 + 2 | `gen_sec.py`, `secgen.py` |
| `tests/asm`, `asm-equiv`, `asm-err` | 86, 63, 32 | 15, 12, 32 | hand-written; `.words` expectations are bytes and do not change |
| `tests/relax`, `ld`, `timing`, `forms`, `enc`, `asmsyntax.c` | 8+4, 3, 3, 6, 1, 2 | | `gen_relax.py`, `check_timing.py`, `check_forms.py`; `tests/enc/vectors.txt` uses its own `I:5` text, not the marker |
| generators in `tests/sim/gen_*.py` | 104 | 13 | the format strings (`'\tmovq\t#%d, r0'`) |
| `tools/` (generators, checks, `archcmp.py`, `arch-compare/*.py`, `strip-equiv.py`, `check-drift-enc.py`) | about 100 | 20 | text built and text parsed: `archcmp.py` tests `startswith('#')` and matches `#(-?...)` about 16 times; `arch-compare/vecwin.py`, `checksites.py` read the marker from compiler output |
| `tools/encopt` | `profile.weights` 1,016 lines; `corpusfix.py`, `weightsfile.py` | | written from `encdis` output; the weights file is data and is rewritten by its own generator |
| `common/`, `as64/`, `ld64/`, `sim64/` | 4, 11, 5, 8 | | messages and comments ("write @n or #n", "take #mask") |
| `tools/encdis.c` | 3 print sites (lines 31, 51, 89) | 1 | the disassembler: `printf("#%lld")` becomes `"$%lld"` |
| `spec/` | `spec/facts/vec.toml` 18, `spec/README.md` 5, comments in `spec/grammars.d/*.hbnf` | | the facts file feeds the manual's vector entries |
| `docs/manual-src` | 104 | 8 | hand-written (note: its `{{#name}}` tokens contain `#`, the script must skip them) |
| `tools/manual/isa_*.py`, `mkmanual.py`, `gfxfigs`... | about 40 | 9 | the generated entries and the dictionary text |
| `docs/manual` (generated) | about 120 | | comes from the two lines above: never edited by hand; `docs/manual/dictionary/aliases.md` has 4 (`FNEG.F32`, `FABS.F32`, `ABS`, `ROL`) |
| `docs/annex` | 61 (`snippets/*.S`, `.md`) | | hand-written |
| `docs/*.md`, `docs/design`, `docs/codegen-data` | about 350 + 33 | | `docs/pdp64-isa.md`, `docs/asm-syntax.md`, `docs/annex`, `docs/design` |
| `docs/encoding-work` | 3,723 | many | historic bench sources (`.s`, 3,174 lines, most do not assemble now) and notes; I would not touch the historic sources, only the notes that are the current description |
| `README.md` | 0 | | |
| **outside this repository** | | | |
| `../pcc/arch/pdp64` | `local2.c` 16 lines, `peep.h` 43, `table.c` 2 (`ror32 AL,#ZQ,A1` and the xor) | 3 | text printed (`"#%lld"`, `printf("#" CONFMT)`) **and tested by character**: `peep.h` and `local2.c` have about 19 tests of `op[0][0] == '#'`, `strcmp(op, "#0")` and `startswith`, so the peephole must change in step with the printer |
| `../llvm-pdp64/target/PDP64` | `PDP64InstrInfo.td` 13 asm strings (`" #$i, $rd"`), `PDP64VecLoop.cpp` 4, README 6 | 3 | in TableGen **`$` is the operand marker** (`$rd`, `$i`): a literal `$` is written `$$`, so `"$$$i, $rd"`. The tests (`tests/*.ll`) check no asm text (their `#0` are attribute groups). `target/frozen-M1` holds an old `AsmParser`; the live tree has none, so what `llvm-mc` accepts is **unverified**, the statement in `asm-syntax.md` is old |

How the grammar parts carry the marker: the encoding parts (`spec/grammars.d/20..57`) carry it **only in comments** (`k-imm0 ... #0`, `rti #mask`); the shapes are named `I`, `K` and the like, and `tests/enc/generated.sha256` hashes the encoding tables and the mnemonic headers, which do not hold it, so it does not change. The marker is a rule of its own in `60-asm-syntax.hbnf` (`immop`), the one place where the lexer decides. `tools/gen-llvm-td.py` writes `PDP64GenLayout.td` with the marker in comments only. The manual's form charts (`docs/manual/figures/w/*/NN.svg`) show no marker (0 found).

### 4.3 Number rewrites

* Leading zero: **0** in assembler input anywhere. Nothing to rewrite in tests, generators, `docs/annex` snippets or tools. The PDP-11 octal of the prose: see section 3.
* `h`, `b`, `q`, `d` suffixes: only the two NASM tests (about 13 lines); both are deleted or rewritten with `0x`, `0b`, `0o` (the equivalence reference file already uses the C forms).
* `$FF`: 0.
* `0x` hexadecimal: 27,946 lines (kept); `0b`: 0 uses in sources; `0o`: 0 uses in sources.

### 4.4 The plan

1. **The lexer in a scratch build first** (done, section 0). Remaining for the real change: the three refusals of 2.2 and 2.4, a message for a `$` that is out of place, the removal of the dead code, the grammar comments, the four tests above.
2. **A conversion script** (written and tried in the scratch: `dollar/conv_s.py`): in assembler text, `#` becomes `$` when it follows a blank, comma, `(`, `[`, or the start of an operand and is followed by a digit, sign, `(`, letter, `.`, quote; it leaves cpp directives (`#include`, `#define`...), comments and `{{#name}}` and `](#anchor)` alone. Applied to every tracked `tests/**/*.s,.S,.inc` and `docs/annex/snippets`, 168 of them assemble (the rest needed my preprocessor include paths): 165 byte-identical objects, the 3 others differ only by the source file name that `__bug_table` holds (`tests/asm/checks.s` against `conv/tests/asm/checks.s`).
   Generators are converted by hand-checked regex on their format strings, then regenerated and compared with the converted `.s`; docs, manual-src and `tools/manual` by the same script with the prose rules (inline code and fenced blocks only).
3. **The byte gate** against the current working-tree assembler output in a scratch copy: assemble the original tree and the converted tree **at the same relative paths** (the object holds the file name), compare the objects, the `.words` files and `.bytes`, and run `tools/check-all.sh` on the converted copy. Because the reference is the committed tree (`b16b6805`) there are no uncommitted changes to track; if the owner has more by then, the reference is the copy of the working tree taken first.
4. **Order**: lexer and its tests; `encdis.c`; pcc and LLVM printers (and the pcc peephole in step); the converter over tests and generators; the byte gate; then the manual sources, the generators of the manual, `mkmanual.py`, `mkbook --check` (the book PDF changes), and the documents. Errata 233 and R555 get their "what was done" last.
5. **Risks.**
   * (a) The pcc peephole tests the character `#` by hand in about 19 places: a missed one makes a silent change of the generated code, not an error. The gate is `tools/pdp64test-all.sh` and the corpus compare before and after (bytes of `.text`).
   * (b) TableGen's `$`: the `.td` strings need `$$`; a wrong one prints `$i` as text or fails the build.
   * (c) The silent symbols of 2.4.
   * (d) `archcmp.py` and `arch-compare` parse `#`; they would produce wrong tables, not errors, if the compilers print `$` and they are not changed.
   * (e) A `.S` source can use `$5` in a macro where `#5` would be stringified by the preprocessor (`#define LOAD(n) mov #n, r1` gives `mov "5", r1`: tested). So `$` is the better marker in `.S` files; no source of the tree has such a macro.
   * (f) The generated `docs/manual` and the book change in many places; `mkmanual.py --check` and the book check have to pass, and none may be left "skipped".
   * (g) The historic sources of `docs/encoding-work` stay with `#` (still accepted); I would not rewrite history.
6. **Recommendation.** Do it in the order above; keep `#` accepted forever (it costs one token in `immop`); rewrite every example in the live tree to `$` by script and gate by bytes; make the three refusals (a register after `$`, the old suffixed numbers, a misplaced `$`) because every one of them otherwise ends as an undefined symbol that only the linker sees; leave the history alone.

## 5. What V7 says, and the manual of the pdp64 today

### 5.1 V7 `as`: read, not remembered

I read the memo from <https://wolfram.schneider.org/bsd/7thEdManVol2/assembler/assembler.pdf> (28 KB, groff, text extracted with `pdftotext`; the saved copy is in the session's tool-results). It is "Assembler Reference Manual" by **Dennis M. Ritchie** (Bell Laboratories memorandum, the UNIX Programmer's Manual, Seventh Edition, Volume 2; the date line says 1997 because the file was re-typeset). Quotations are short, with the section.

| fact | the text | section |
|---|---|---|
| immediate is `$` and absolute is `*$` | "except that ``*'' has been substituted for ``@'' and ``$'' for ``#''; the UNIX typing conventions make ``@'' and ``#'' rather inconvenient." The table has `$ expr`, mode 27, and `* $ expr`, mode 37. "To force a non-relative reference, the form ``*$expr'' can be used" | 8.2, address modes |
| a bare expression is pc-relative | "addresses consisting of an unadorned expression are assembled as pc-relative references" | 8.2 |
| the location counter | "One special symbol, ``.'', is the location counter." | 4 |
| the relocation counter | "The symbol ``..'' is the relocation counter." | 9.1 |
| comments | "The character ``/'' introduces a comment, which extends through the end of the line" | 2.6 |
| division | "``\/'' division (note that plain ``/'' starts a comment)" | 6.1 |
| numbers are octal | "An octal constant consists of a sequence of digits; ``8'' and ``9'' are taken to have octal value 10 and 11." **There is no leading-zero rule and no `0x`:** the digits alone are octal | 2.3 |
| decimal | "A decimal constant consists of a sequence of digits terminated by a decimal point ``.''" | 2.3 |
| characters | `'` followed by one character (no closing quote); `"` followed by two | 2.3 |
| names | "alphanumeric characters (including period, underscore, and tilde as alphanumeric) of which the first may not be numeric. Only the first eight characters are significant." **`$` is not a name character** | 2.1 |
| local labels | "a digit followed by ``f'' or ``b''"; "A numeric label consists of a digit 0 to 9 followed by a colon" (one digit) | 2.2, 5.1 |
| registers | "The symbols r0 ... r5, fr0 ... fr5, sp, pc are predefined as register symbols"; no `%` prefix in this memo | 6.2 |
| operators | `+ - * \/ & | \> \< % ! ^` and a blank (as `+`); "All operators have equal precedence, and expressions are evaluated strictly left to right"; `%` is **modulo**; `!` is or-not; grouping is `[ ]`, "Round parentheses are reserved for address modes" | 6, 6.1 |
| strings | `<` text `>` | 5.5 |

Two things are **unverified** and I did not claim them: the V6 assembler's spelling of the same (the owner's chat says V6 also wrote `$`; this memo is the V7 one), and the DEC `#` and `@` of PAL-11R and MACRO-11 (the memo says only "the syntax ... is identical to that in DEC assemblers, except ...", which shows DEC wrote `#` and `@`, and that is all I can read).

Consequences for the owner's list: V7 has **no `0x`, no `0b`, no `0o`, no leading-zero octal as a mark** (octal is the default); so the new number rules are C's, not V7's, as errata 233 says ("V7 forms of everything else are not adopted"). The owner's "a leading zero is an error" is neither V7 nor C. V7's `$` is only an operand marker, and `.` is the only location: both fit the decision. V7 does not allow `$` in a name; as64 does, and nothing conflicts.

### 5.2 What the manual says today, and the lines to change

`docs/manual-src/appendix-d-assembler.md` (generated copy `docs/manual/appendix-d-assembler.md`) and `docs/asm-syntax.md` (the same text, kept in step):

* Line 16 of the appendix, "**Numbers and characters** are C's: decimal by default (`010` is ten), `0x`, `0b` or `0o` when asked for": the `010` is ten sentence reverses: a leading zero is an error that names `0o`.
* Line 20, "**Other spellings**": "`$expr` is an immediate, like `#expr`" reverses (`$` is the official one, `#` the alias); the `$name stays AT&T's immediate` note in the NASM paragraph of `docs/asm-syntax.md` goes.
* The NASM paragraph of `docs/asm-syntax.md` (the numbers with a suffix, `$` and `$$`, "A valid number is never a name (errata 163)", "The one overlap that stays") is replaced: the suffixes, `$` and `$$` are gone, `times` has no `$`.
* Line 11 (names are letters, digits, `_`, `.`, `$`; "`3`, `0x3d`, `0b101`, `0o17` are numbers"; "what stays unusable as a bare name is ... a valid number (`ch`, `deadh`)"): the `ch`, `deadh` clause goes; `$` in a name stays.
* The `#imm` and `#K` statements in the compare-and-branch, `ror.s32`, literal-pool ("use `#imm`") and "One word names the operation" bullets (`mov #imm, rd`, `trap #n`) and the operand-mode list (`#expr`): all become `$`.
* The "What it leaves out of V7 `as`" paragraph: it says "octal numbers by default"; add the leading-zero error, and that `$` as a location and the NASM suffixes are not there.
* `docs/manual-src/09-isa.md` and the generated `09-isa.md` carry the marker in form names and tables (`MOV #imm, Rd`, the addressing-mode table row `#imm`, section 9.4 and 9.6); `tools/manual/isa_part1..4.py`, `isa_enc.py`, `isa_stories.py`, `mkmanual.py` produce them.
* The dictionary: `docs/manual/dictionary/aliases.md` lines 11, 12, 13, 20 (`#-2147483648`, `#0x7FFFFFFF`, `SAR #63`, `#n`, `#(64-n)`) and `constants.md` line 66 (`TRAP #n`). `by-mnemonic.md`, `by-encoding.md` and the form charts carry no marker.
* `docs/manual-src/06-kernel.md` (83 lines) holds the most examples of the manual.
* Also: `docs/pdp64-isa.md`, `docs/annex/*`, `README.md` (none), `spec/README.md` (5 lines).

## 6. What needs the owner's decision

1. **The three refusals** of section 2 (a register after `$`; the old suffixed numbers `0FFh`, `17q`, `10d` named with their replacement; a `$` out of place). I recommend all three.
2. **Uppercase prefixes** `0X`, `0B`, `0O`: kept today, never used. C accepts `0X` and `0B`; `0O` looks like `00`. I recommend only lowercase.
3. **`$$` (start of the section)** has no replacement. The NASM `times 510-($-$$) db 0` is the use. I recommend none: write a label.
4. **PDP-11 octal in the manual prose and figures** (about 70 lines in `docs/manual-src`, 10 in `tools/manual`, more in the notes): rewrite to `0o` or keep as the PDP-11's own notation.
5. **The C64 `$D000` in prose** (about 10 lines): keep as the C64's notation, or rewrite to `0xD000`.
6. **`%` before a register** stays (AT&T writes `$5, %r1`); not in the owner's list, so I leave it.
7. **The historic sources** of `docs/encoding-work` stay with `#`.
8. **`$` inside a name** stays (V7 has none; costs nothing).
9. **The pcc peephole and LLVM `$$`** are outside this repository: the owner says whether phase 2 changes those repositories too.
