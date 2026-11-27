# Sweep 2: the old decisions read again under the reworded principles

*For the owner to read. I changed no tracked file except this one, committed nothing, and decided nothing. Every "change" below is a recommendation.*

## The headline

I found **19 findings** that matter and **10 minor ones** (the table near the end). Thirteen of the 19 are notation or naming only: a spelling in the assembler or the grammar, no encoding and no meaning moves. Six touch an encoding, a rule of the machine, or need a measurement first.

The top five, in the order of the principles (safety first):

1. **Words that look like a register or a number silently become undefined symbols.** `mov pc, r1`, `mov dp, r1` and `.quad 1.5` all assemble, as loads from, or references to, global symbols named `pc`, `dp` and `1.5`. (Notation, small.)
2. **`r5-8` and `(r5)-8` look alike and mean different things.** The first is `-8(r5)`; the second is a pre-decrement of `r5` by 8. Same bytes as `-8(r5)` for the first, different bytes for the second (checked). (Notation, small.)
3. **Supervisor mode exists, is banked, and "no code uses it".** It is there because the PDP-11 had it. (Rule of the machine, medium; needs a measurement.)
4. **The `abs`, `min` and `max` aliases silently overwrite `R12`.** A hidden side effect in a word whose name says nothing about it. (Assembler only, small.)
5. **The assembler accepts a long list of other assemblers' spellings** (`db dw dd dq resb equ proc endp`, `a ! b`, `<x`, `>x`, `$expr` and more). Each one is a word the language reserves and a way to write something other than what you meant. (Notation, small to medium.)

Then, by the next principles: the software accessed and dirty bits and the 4 KB page have no recorded reason on speed (findings 6 and 7); the one-operand words `inc`, `clr`, `asl` and the rest are shorter than the same operation written with the ALU word, which breaks errata 214 (finding 8); and the destination-last rule has exceptions the precedent re-read did not find: `MFSR`, `MTSR`, `PROBER`, `PROBEW` and the block words (finding 13).

**Needing you at once:** nothing is broken that a test would catch today. But finding 1 is a safety hole of the "easy to be correct" kind, and the principles say each such hole has a test in the corpus; I found none in `tests/asm-err` (its names list no test for `pc`, `dp` or a dotted number). If you want only one thing looked at before the rest, it is that one.

## How I read, and what I did not read

I read the principles, the whole of errata 207 to 236, the register rows R530 to R558 through the errata that cite them, and the four rejudge notes and `precedent-reread.md` for what they cover. For errata 1 to 206 I read the first lines of every entry (all 206) and the full text of about forty of them; the many entries that are process (the manual's style, the licence, the chapter rewrites, the boot ROM, the corrections of 2026-11-10) decide no instruction or notation and I did not read them to the end. For the register R001 to R529, which are your own messages, I filtered by the words mnemonic, syntax, spelling, alias, suffix, directive, register name and read those rows; I did not read each of the 529 rows. So a decision whose text names none of these words and whose errata line is short could have escaped me. Where I could, I checked a claim by running `build/as64` (built 27 November) and the generated dictionary, not by reading prose. Claims about other machines are marked *unverified* when they come only from the repository's own text.

The tool checks I rely on are listed at the end.

---

## The findings, ranked

Each: the decision (errata, R), what it says, what it fails, what I recommend, what it heals and costs, and the blast radius.

### Safety and "easy to be correct"

**1. Register-looking and number-looking words become silent symbols.**
*Decision:* errata 100 (the program counter is not a register; "the PDP-11 spelling kept as assembler syntax"), errata 33, 236 (R558: the three silent traps are refused). Appendix D says "`pc` and `dp` appear only as a base".
*What is so:* `mov pc, r1` and `mov dp, r3` assemble. The object has undefined global symbols `pc` and `dp`, and the instruction is a PC-relative load of memory at that symbol. `mov sp, r2` and `mov fp, r4` are real registers. `.quad 1.5` and `mov $2.5, r1` also assemble; the object has undefined symbols named `1.5` and `2.5`. (Checked: `readelf -s` on the object.) A PDP-11 or VAX programmer types `mov pc, r1` by finger memory and gets no message; a float constant has no syntax at all, so the one obvious attempt links as an unresolved reference or, worse, resolves to some other `pc`.
*Fails:* principle 1, "it is easy and cheap to be correct", and the rule that each hole has a test. Errata 236 closed three of this kind (`$r1`, old suffixed numbers, a misplaced `$`) and missed these.
*Recommend:* **change.** Refuse a bare `pc` and `dp` as an operand with a message that names `lea 0(pc), r1` and `mfdp r1`; refuse a number-shaped word with a dot (`1.5`) with a message that names the data directive of finding 15. Add three tests to `tests/asm-err`.
*Heals:* the finger-memory slip and the missing float constant. *Costs:* two reserved words (a user can no longer name a global `pc` or `dp`). *Blast:* small (a spelling in the assembler).

**2. `r5-8` against `(r5)-8`.**
*Decision:* errata 15 (R-number not cited): `-(Rn)` pre-decrements by the size, `(Rn)-d` pre-decrements by a stride, "the mirror of `(Rn)+d`". Errata 226's side finding and appendix D add `base-expr` as a synonym of `expr(base)`.
*What is so:* I assembled the four: `mov r5-8, r1` and `mov -8(r5), r1` give the same bytes (`c2cbff87`); `mov (r5)-8, r1` gives `01700850`, a pre-decrement by 8; `mov (r5)+8, r1` is a post-increment by 8. So one pair of parentheses turns a displacement into a side effect on the base register. And `(r5)-8`, read left to right, looks like a post-decrement, which the machine does not have.
*Fails:* principle 1, "no strange side effects" and "easy to be correct"; and the PDP-11 habit that the sign next to the register says when the step happens (`(R)+` after, `-(R)` before).
*Recommend:* **change.** Withdraw the `base-expr` synonym (the owner's "side finding" of errata 226 was that it should work; I would rather it be refused with a message that names `-8(r5)`). Separately, the owner may decide whether the strided pre-decrement `(r)-d` is worth keeping at all: the compilers use `-(r)` and `(r)+`, and I did not search the corpus for a strided one (*unverified*).
*Heals:* the one hazard of the addressing syntax. *Costs:* a spelling; possibly one mode of the encoding if the strided pre-decrement goes. *Blast:* small for the spelling; medium if the mode goes.

**3. Supervisor mode, kept for the PDP-11's sake.**
*Decision:* errata 36 ("current and previous mode with the PDP-11 encoding"), errata 117 (the owner asked that the rationale not be removed; the restored text says "carried from the PDP-11" and that the third bank "costs two registers and is an unresolved question"). Manual 6.2.1: "three modes, with the PDP-11's encoding: kernel 0, supervisor 1, user 3. The supervisor mode exists in the status word and in the banked registers, and no code uses it."
*Fails:* the precedent rule of errata 218 (the only reason on record is the PDP-11 had it); Occam; principle 1 (a mode is a privilege boundary that has to be right and have tests, and a state the hypervisor must also save: `ssp` is system register 7 and `gsdp` is 146).
*Recommend:* **needs a measurement, then probably remove.** Count the gates and state bits of the third bank of `R14` and `DP`, the guest copy `GSDP`, and the mode comparisons; count the tests in the security corpus that exercise mode 1 (I did not count them: *unverified* whether any do). Errata 117 itself says dropping it frees no bit, so the value 2 and the PSW layout are untouched either way. If a later system wants three levels (a capability kernel, seL4's needs are in `sel4-fit.md`), the reserved value is still there to give.
*Heals:* an untested mode and about two banked registers per core and per guest. *Costs:* the PDP-11 resemblance. *Blast:* medium (grammar of system registers, executor, QEMU, hypervisor copies, manual 6.2).

**4. `abs`, `min` and `max` clobber `R12` without saying so.**
*Decision:* errata 98 and 225 (R547): they are assembler aliases expanded over existing instructions with "the scratch register that the ABI makes available to the assembler".
*What is so:* `docs/manual/dictionary/aliases.md`: `MIN` is `SETLT Ra,Rb,R12; NEG R12; BSEL R12,Ra,Rb,Rd`; `ABS` and the unsigned variants likewise use `R12`. Appendix C says `R12` is "the scratch of the linker and of the assembler's expansions". A hand-written routine that keeps a value in `R12` and writes `min r1, r2, r3` loses it.
*Fails:* principle 1, "an instruction does what its name says and nothing else". Documented, so rung 2 of the ladder (prevent by idiom), but rung 1 is open and cheap: when `Rd` is not `Ra` or `Rb`, `Rd` can be the scratch, and `R12` is needed only when it is.
*Recommend:* **change the expansion** so that `R12` is touched only when `Rd` equals a source. I could not verify that `BSEL` reads all its inputs before it writes `Rd` (the manual's `Rd ← (Rm AND Ra) OR (NOT Rm AND Rb)` suggests it does); *unverified* until someone runs it. Alternatively keep, and add `R12` to the list of words the assembler warns about.
*Heals:* a hidden register write. *Costs:* two lines in the expander. *Blast:* small (assembler).

**5. The other-assemblers' spellings.**
*Decision:* errata 139, 162, 163, 169 (R424 to R429, R461 to R464, R473): as64 accepts AT&T, ITS, MASM, Turbo Pascal, ca65, NASM and early Unix spellings "where they do not conflict". R157 says "we don't need to copy asv7 warts".
*What is so:* appendix D lists them: `db dw dd dq resb equ proc endp`, `[ ]` for `( )`, `a ! b` (or-not, a V7 wart), the unary `<x` and `>x`, `%r1`, `$expr`, `(base,index,scale)`, `base+expr`. `.db` is refused while `db` is accepted (checked); `.asciz`, `.global`, `.section`, `.org`, `.equ`, `.set` are all refused (checked): so the superset is partial and the user cannot predict which half they get. Errata 169 had to repair one collision (`dd` against a C global).
*Fails:* principle 6 as reworded (a coherent set a programmer can keep in the head); Occam ("an alias before a new instruction" is fine, but an alias in someone else's *language* is a different cost: reserved words); R157. Under the rule of errata 232 an alias needs an official form that tools print; for most of these there is no official form on the page.
*Recommend:* **keep a short list, drop the rest.** Keep what saves typing for the readers the manual names (`$`, `//`, `equ`, perhaps `db dw dd dq` as aliases of the finding 15 directives). Drop what is a wart or a second meaning: binary `!`, unary `<` and `>`, `proc` and `endp`, `[ ]`, `%`. Errata 236 already refuses `%` before a register; appendix D still says it is accepted.
*Heals:* reserved words and silent mis-parses. *Costs:* the convenience of the readers who wanted exactly those spellings (the owner decided them; this is a re-judge, not a correction). *Blast:* small to medium (grammar `60-asm-syntax.hbnf`, tests, appendix D).

### Speed

**6. Software-managed accessed and dirty bits.**
*Decision:* errata 36 (the owner's choice, 2026-10-22: "Software (recommended)", R215); manual 6.7: "one extra fault on the first touch of each page and one on the first write", for a walker that never writes.
*Fails:* principle 2 as reworded (speed is measured run time): the reason is on merit (a read-only walker cannot corrupt a table), but the cost is a fault, and it has never been measured. The records I read give a safety reason and no run-time number.
*Recommend:* **needs a measurement.** Count first-touch faults per second of a page-faulting workload on QEMU or sim64 against an implementation that sets A and D in hardware. If the cost is under a percent, keep. If not, a hardware update that sets the bits only with a write the walker's owner permits can be proposed under "best of breed" (Arm and RISC-V both have optional hardware update: *unverified*, from the repository's own text).
*Heals/costs:* unknown until counted. *Blast:* medium if it changes (walker, executor, QEMU, kernel text).

**7. The 4 KB page and nine-bit levels.**
*Decision:* errata 96 (3, 4 or 5 levels, 39, 48, 57 bits; the owner: "3 4 and 5 is good, as long as this is discoverable"); the page size itself I found in no errata row and in no register row (I searched the errata and the register for the phrase page size and for 4 KB). Manual 6.6.1 states it as given.
*Fails:* the precedent rule: the only visible reason is that x86-64, RISC-V and others (the Sv39, Sv48, Sv57 numbers) do it. Nothing says 4 KB is better for this machine than a larger base page, and the software-managed bits of finding 6 make the page size matter more (a fault per page).
*Recommend:* **needs a measurement.** On the 26 programs and the kernel runs: translation-buffer misses, faults and the size of the page tables at 4 KB, 16 KB and 64 KB base pages. Note the OpenBSD and Debian ports expect 4 KB; "standard at the edges" counts for something, but not as a ranking by itself.
*Blast:* large if it changes; I expect keep.

### Fewer instructions, fewer fetches

**8. The one-operand words and the ALU words are two spellings of one operation, of different length.**
*Decision:* errata 214 (R537): "the mnemonic names the operation, not the length of its encoding". The survey `one-mnemonic-survey.md` listed `clr inc ...` as "one word already" because each has several forms of its own.
*What is so (checked with `as64 --stats`):* `inc r20` is 2 bytes and `add $1, r20` is 4; `asl r20` is 2 and `shl $1, r20` is 4; `clr r20` is 2 and `mov $0, r20` is 4; `com r20` is 2 and `xor $-1, r20` is 6; `dec r20` is 2 and `sub $1, r20` is 4. The survey compared each word with its own forms, not with its twin. In the old corpus `clr` is 10,558 static instructions (2.85%), `inc` 941, `asl` 640, `dec` 482, `neg` 440, `com` 383 (`docs/codegen-data/mnemonics_pdp64.csv`, pcc output, the 841-file corpus; old encoding), so compilers do use them.
*Fails:* errata 214, and principle 3 (fetches) for hand-written code, where a programmer who writes `add $1, r20` gets four bytes for no reason.
*Recommend:* **change.** Make `inc dec clr com asl asr` the short forms of `add $1`, `sub $1`, `mov $0`, `xor $-1`, `shl $1`, `sar $1` (the assembler picks, as for every other word), and keep them as accepted aliases under errata 232 (official form: the ALU spelling; compilers print the alias, as they do `inc`). `neg` has no ALU twin (see finding 10) and stays.
*Heals:* two spellings, four-byte code that should be two. *Costs:* a rule in the assembler's form choice; the disassembler prints the alias. *Blast:* small to medium (assembler, tests that name the words, manual entries).

**9. `addm`, `subm`, `bicm`, `bism`: a word per direction of the operand.**
*Decision:* errata 11 (MESC), errata 214. The survey: "left: read-modify-write of memory, a different operation from `add rs, rd`".
*What is so:* `add r1, (r2)` is refused; `addm r1, (r2)` works; `addm $1, (r2)` is refused while `inc (r2)` works; `andm` and `xorm` do not exist; `xor r1, (r2)` and `bis r1, (r2)` are refused. For `mov` the same word does the load and the store, chosen by the operand. For `add` the memory-destination form needs another word, and the set is a hole (four of the six two-operand logic and arithmetic words).
*Fails:* errata 214 (a word that differs only by an encoding), and the machine's own habit (`mov (r1), r2` and `mov r1, (r2)` are one word); principle 6.
*Recommend:* **change the spelling, measure the missing two.** `add r1, (r2)` assembles to the `addm` encoding; `addm` becomes an alias. Whether `and` and `xor` to memory earn an encoding is a count (none of the four `m` words appears in the corpus I have; so the count is zero for `addm`, and I have no number for `and`/`xor` to memory).
*Heals:* four words, one hole. *Costs:* assembler rule. *Blast:* small (spelling); medium if two words are added.

**10. One-operand words work in place only; the two-operand ones copy.**
*Decision:* the PDP-11's single-operand group (errata 1 to 11 on `SOP`), kept; instruction-pass C12 (the three-register ALU) is "open until measured" (errata 217).
*What is so:* `neg r1`, `com r1`, `inc r1` and the others take one register; `neg r1, r2` and `inc r1, r2` are refused (checked). `clz r1, r2`, `popcnt r1, r2`, `bswap r1, r2`, `fneg r1, r2`, `fabs r1, r2` and `fsqrt r1, r2` take a source and a destination. So `neg` needs a `mov` first when the source must survive; `clz` does not. The precedent re-read quotes 13.1% of the corpus as register moves.
*Fails:* principle 3 (an instruction pair where one would do), and the rule that the machine is regular (principle 6).
*Recommend:* **needs a measurement**, together with C12. Count `mov rs, rd` followed by `neg`, `com`, `inc`, `dec` on the same `rd` in the compiled corpus. If it is common, `neg rs, rd` and its relatives take two registers with the in-place form a case of equal registers; if not, leave it and state in the manual that the single-operand words are in place.
*Blast:* medium (encoding).

**11. Two-operand and three-operand shapes, and the order they read in.**
*Decision:* errata 98, 217 (C12 open), 231 (4).
*What is so (checked):* `mulh r1, r2` is two-operand, `mulh.u64 r1, r2, r3` is three-operand, and `mulh.u64 r1, r2` is refused; `mul.u64 r1, r2, r3` is refused; `div` and `mod` exist only as `div ra, rb, rd`; `min` and `max` only three-operand. Floating point: `fadd fsub fmul fdiv fsqrt` are two-operand, `fmin fmax fcopysign` three-operand (`fmin r1, r2` is refused), `fmadd` four. The reading order differs too: `sub rm, rd` is `rd - rm` (the PDP-11's order, the destination is also the left operand), while `div ra, rb, rd` is `ra / rb`, and `ror $3, r1` puts the count first but `ror r1, $3, r2` puts it second.
*Fails:* principle 6 (coherent set) and 3. The split follows which encoding group the word landed in, not what the word does, and a signed word and its `.u64` twin are in different shapes, which makes the one-suffix-set of errata 230 to 231 false at the operand.
*Recommend:* **decide the reading rule now, before C12.** My suggestion: keep the two-operand form as the PDP-11 meant it (`op rm, rd` is `rd = rd op rm`), and make every three-operand form read `ra op rb -> rd`, and say so in the manual's notation paragraph; and give `mulh.u64` the same shape as `mulh` (two-operand) or give both the three-operand shape. The count of C12 then picks the shape for the whole family.
*Blast:* medium to large (it is the encoding of the integer ALU).

**12. `mfps`, `mtps`, `mfdp`, `mtdp`: four words in the two-byte slots.**
*Decision:* errata 32 (`mfsr`, `mtsr`), 217 C6 (merged `mfcpuid`, `mtasid`, `mfasid` into them) left these four.
*What is so:* each has a two-byte `SYSR` slot (`110000010` prefix); the same thing is `mfsr r1, <psw>` in four bytes, except that `psw` and `dp` are not system registers (`41-sysreg.hbnf` has no such name).
*Fails:* principle 4 only if they are rare; "hot-loop weight": they are privileged words in kernel entry and context-switch paths, not in loops. The pcc corpus has none (system words are zero there).
*Recommend:* **needs a measurement** of how often a kernel on the QEMU model executes them (a boot and a make); if a small number, make them aliases of `mfsr`/`mtsr` with `psw` and `dp` as register names and give the slots to something frequent.
*Blast:* medium (encoding; the kernel text).

### The coherent set (notation and naming)

**13. The destination is written last, except where it is not.**
*Decision:* the manual's own rule (9, notation): "the assembler writes the destination last"; errata 219 (B) fixed the atomics. Errata 32 spelled `mfsr rd, name` and `mtsr name, rs` and nothing re-judged them.
*What is so:* `MFSR Rd, name` writes the destination first; `MTSR name, Rs` writes the destination (the system register) first; `PROBER Rd, Rs` and `PROBEW Rd, Rs` write it first; the block words `MCPY Rd, Rs, Rn`, `MMOV`, `MSET Rd, Rv, Rn`, `MCMP`, `MSCN`, `MSCNN`, `MVAL Rd, Rn` and `MCPY.UR/UW` put the destination pointer first, in the order of C's `memcpy`; The assembler enforces the order, and refuses `mfsr ptbr, r1` with a message (checked), so it is a rule with exceptions, not a silent hazard. The precedent re-read found only the atomics.
*Fails:* errata 218 (the consistency of the architecture outranks copying; the order is VAX `PROBER` and a memcpy habit) and principle 6.
*Recommend:* **change `mfsr`, `mtsr`, `probe` now** (`mfsr name, rd`, `mtsr rs, name`, `prober rs, rd`) because they are not block words and nothing but a name is at stake; for the block words, **owner to decide** between "memory destination is still a destination, write it last" (`mcpy rs, rd, rn`) and "a block word is its own family, say so in the manual".
*Heals:* the last exceptions to the one rule a PDP-11 reader learns first. *Costs:* every kernel line that uses `mfsr`/`mtsr` (51 occurrences of `mfsr` and `mtsr` in the manual chapters). *Blast:* small for the spelling (assembler operand roles, tests, manual text); the encoding does not move.

**14. The unsigned conditions are PDP-11 flag words for a machine with no flags.**
*Decision:* errata 231 (5), R553; `mnemonic-suffixes.md` table: "they are conditions with the PDP-11's names (`BHI BLOS BHIS BLO BCC BCS`); `cblo` is the carry-set branch every PDP-11 reader knows". Errata 220 (R543) removed the flags after that wording.
*What is so:* the unsigned relations are spelled `cbhi cblos cbhis cblo cbcc cbcs` (plus `sethi setlos sethis setlo setcc setcs` and `cthi ctlos cthis ctlo ctcc ctcs`): six words for four relations, three of them for two (`cbcc`, `cbhis`, and `hs` in the condition table for "unsigned greater or equal"). `cbhs` is refused while `cbhis` works (checked). Everything else with a signedness is a suffix: `div.u64 min.u64 max.u64 mulh.u64 amax.u64 mul.u64`, and as64 refuses `cblt.u64` ("cblt takes no width or kind suffix").
*Fails:* errata 218 and 232 (the one suffix set; a suffix only where the operation deviates); the reason on record is precedent, and what it names (the carry) is gone.
*Recommend:* **change.** Official words: `cblt cble cbgt cbge` for the signed norm (the bare word is the `.s64` alias) and `cblt.u64 cble.u64 cbgt.u64 cbge.u64` for the deviation; `cbhi cblos cbhis cblo cbcc cbcs` become accepted aliases (finger memory is the point of notation precedent, so keep them) and compilers print the short alias or the suffix form, whichever the owner prefers; the same for `set` and `ct`. `hs` appears nowhere in a mnemonic and can go.
*Heals:* six words become four plus aliases, and the rule has no exception. *Costs:* the PDP-11 reader's `BHI`; kept as an alias, not lost. *Blast:* small (grammar, assembler, tests); the compilers' printers.

**15. Data directives keep the old width words; no float data.**
*Decision:* the directives `.byte .word .long .quad` (appendix D: "the ISA's PDP-11 terminology"); errata 227's README sentence ("a word is 16 bits"); errata 230 withdrew the letters from instructions and left them here. `db dw dd dq` as NASM aliases (errata 162).
*What is so:* `.u32 1`, `.s32 1`, `.f64 1.5` are refused (checked); `.float`, `.double`, `.half`, `.int`, `.short`, `.asciz`, `.zero`, `.balign` are all refused. There is no way to write a floating-point constant other than its bits (`.quad 0x3ff8000000000000`), and `1.5` is the silent symbol of finding 1.
*Fails:* errata 230 (width and kind are a dotted suffix); principle 6.
*Recommend:* **change.** Official data directives `.u8 .u16 .u32 .u64`, `.s8` and so on (kind does not change the stored bits; accept both) and `.f16 .f32 .f64` taking a decimal float; the old four and `db dw dd dq` stay as aliases. This also gives pcc and LLVM a printed form for a float constant.
*Heals:* the missing float constants and an exception to the notation. *Costs:* directive names `.u32` etc. are reserved (errata 236 already reserves the dotted names). *Blast:* small (grammar, assembler).

**16. The vector words keep lane letters, in three places for "unsigned".**
*Decision:* errata 226 (C) and 231 (9): "the vector words follow the pattern later". 359 words.
*What is so:* lanes are `.b .w .l .q` (8, 16, 32, 64-bit integers) and `.f .d` (single and double), where scalar code says `.s8 .s16 .s32 .s64 .f32 .f64`. Unsigned is written three ways: after the word (`vmaxu.b vminu.w vabdu.b vcgtu.l vmulhu.w`), after the lane (`vld.bu vacc.bu.l vmaxacc.lu vsad.bu`), and with `su` for "saturating unsigned" (`vaddsu.b vsubsu.l`), which a reader will take for "signed times unsigned" (`vdotsu.b`, `vdacc.bsu`). `l` means 32 bits here and `q` 64, the opposite of what a reader who has met `.s32` would guess. Also `addv`, `subv`, `mulv` (overflow-checked scalar) share a letter with the `v` prefix of vectors.
*Fails:* errata 230, 232; principle 6.
*Recommend:* **change, as already decided; and fix the unsigned position in the same pass.** Lane suffix is `.s8 ... .u64 .f32 .f64` in the same place as the scalar one, official; the old letter forms as aliases for a time. `addv` and its two could be `add.chk` or stay; mnemonics are cheap.
*Heals:* two vocabularies. *Costs:* a one-time rename of 359 words in the grammar, the generators and the vec tests. *Blast:* medium (all generated tables, LLVM `.td`, the vec corpus), no encoding moves.

**17. Words whose kind means nothing: which spelling is official?**
*Decision:* errata 231 (2) and (3).
*What is so:* stores and `sc.s32`/`sc.u32` accept both, and `aliases.md` makes `SC.u32` an alias of `SC.s32` but `BSWAP.s32` an alias of `BSWAP.u32` and `BSWAP.s16` of `BSWAP.u16`. So the official kind letter is `s` for `sc` and `u` for `bswap`. Stores print by the opcode word, which is also arbitrary.
*Fails:* errata 232 (one official spelling, stated by a rule).
*Recommend:* **change.** One rule: where the kind means nothing, the official spelling is `.u`, since it promises no extension. (`ror.s32` and the 4-byte atomics that return a value stay `.s32` because the hardware does sign-extend.)
*Blast:* small.

**18. Name collisions: `ct`, `pop`, `v`.**
*What is so:* `ctz` and `cto` (count trailing zeros and ones) sit beside the `ct` family (`cteq ctlt ... `, compare and trap); `popcnt` and `pop`, `popm`, `popret`, `popx` (stack); `v` is the vector prefix and the overflow-checked word suffix (`addv`). I ran `ctz r1, r2` and `ctlt r1, r2`: both assemble, as different things, which is fine for the parser and not for the reader. The prefix `set*` is a condition write and `sev` an event, which is close but fine.
*Fails:* principle 6; "mnemonics are cheap". *Recommend:* **owner to decide**; the cheapest change is on the machine's own side: the compare-and-trap family becomes `trapCC` (or `tCC`) rather than `ctCC`; `ctz`, `clz`, `popcnt` are other architectures' names and notation precedent says keep them. *Blast:* small (a family of ten words).

**19. `@name` means something else than on the PDP-11, and errata 100 no longer holds.**
*Decision:* errata 100 ("the PDP-11 spelling `MOV @#addr, R0` is kept as assembler syntax"); errata 233 (3) (R555): "the absolute mode stays `@name`, which the owner likes".
*What is so:* `mov @#0x100, r1` is refused (checked), so errata 100's sentence is false; `mov @x, r1` is an absolute load. On the PDP-11 `@x` is relative deferred (the word at the address stored at `x`). A PDP-11 reader who types `mov @x, r1` gets a different instruction and no message.
*Fails:* the notation rule as written in the principles (precedent matters where finger memory is, and here it points the other way); the check is silent, not refused.
*Recommend:* **keep** (the owner chose this knowingly), **but** say it in the first paragraph of the operand modes of appendix D with the PDP-11 meaning beside it, correct errata 100's sentence by a new row (the register is append-only), and consider refusing `@name` of a symbol that is not absolute with the hint. *Blast:* small.

---

## The minor findings

| # | Decision | What | Principle or rule | Recommendation | Blast |
|---|---|---|---|---|---|
| m1 | R137, errata (the registers) | `sp` is `r14` and `fp` is `r13` "to match the VAX". The only reason on record is precedent. Names carry no hardware cost; the number 14 is fixed in the `RTI` mask (bit 14) and the hot-register table. | precedent, notation | keep | none |
| m2 | errata 50, 51 | GPT around the BSD disk label, label at sector 1, "follow the majority" of OpenBSD's architecture headers (seven of nine). A count of precedents is the reason. | standard at the edges | keep; the edge is the OpenBSD port | none |
| m3 | errata 36, manual 9.14 | `RTT` is named for the PDP-11's, but here it "sets the trace bit after the return"; the entry says it "looks redundant against `RTI`". Whether the PDP-11's `RTT` means the same is *unverified*. A second opcode for one bit; the mask of `RTI` could carry it. | Occam, coherent set | needs a decision | small |
| m4 | errata 33, appendix D | `=expr` is the literal pool, and `sym = expr` is assignment. Same sign, two meanings, different positions; refused wrongly gives a message. | notation | keep, note in appendix D | none |
| m5 | errata 100 | `JMPI` and `CALLI`: the suffix `i` means indirect; errata 232's own comparison treats `i` as immediate. | notation (consistency) | keep (they are a different operation); say so in the entry | none |
| m6 | `30-mn-core.hbnf`, `tables.md` | The encoding words are still `movq movl movzb fneg32 bswapw ror32 mulu abs` and the generated `spec/pdp64/tables.md` prints them, while the surface is `mn-surface`. Two vocabularies in the "one source" files; a reader of the table meets words the assembler refuses (`movq` is "unknown mnemonic", checked). | one source of truth | change (the table prints the surface word) | small |
| m7 | appendix D | Two sentences are stale against decisions already taken: `%r1` "means nothing" (errata 236 refuses it) and "`fcblt.f32 ... the same as the mark .32 on both registers`" (errata 230 withdrew the marks). | one source | change when the other agents' edits land | small |
| m8 | errata 220 (staged) | Unsigned compare-and-branch reaches 1 to 6 KB and the signed 40 KB or more; staged to be fixed with long forms. Already in the record. | dense encoding | keep the stage; finish it | medium |
| m9 | errata 217 C5 | `NOP` and `HINT #0` are the same instruction. | Occam | keep, `nop` is the alias | none |
| m10 | errata 25, 14 | `fcbgt` and `fcbge` are the registers exchanged: the only words that are an alias with different operand roles. | errata 232 | keep; state it in the entry | none |

## What I skipped, and why

I skipped the items `precedent-reread.md` (errata 218 and 219) already judged: the IOMMU register map (A), the atomic operand order (B, taken in errata 219), the compare-and-swap result register (C), the memory-type numbering (D, taken), the hypervisor register names (E), the exit codes (F, taken), the atomic mnemonics (G, taken), the atomic word set (H), the size spelling (I, settled by errata 223 to 232), the register named `CPUID` (J), and the fifteen KEEP rows. I also skipped what `rejudge-accepted-recommendations.md`, `rejudge-decided-items.md`, `rejudge-holes-rti-resume-hv.md` and `rejudge-timer-iommu-irq-atomics.md` cover (the timer, the IOMMU, the interrupt level, the atomics, `RTI` with a mask, the vector resume, the hypervisor mode). Where I touched a neighbour of one of those I said so.

I did not judge the entries that decide no instruction or notation: the manual's style and structure (errata 53 to 71, 103 to 127), the licence, the boot route, the corrections rows, and the milestones. Nor the vector family's design (errata 161 to 176) beyond its spelling.

I did not check the following, and say so: whether the security corpus has a test for supervisor mode (finding 3); the corpus count of a strided pre-decrement (finding 2); the gate counts of finding 3; the page-fault cost of finding 6; the corpus counts for findings 9, 10, 12. Anything said about the PDP-11, VAX, x86, Arm or RISC-V comes from the repository's own text and is *unverified* unless marked otherwise; I did not fetch a primary source.

## The checks I ran

All with `build/as64` as of 27 November and the generated `docs/manual/dictionary/`: the spellings accepted and refused (`movq`, `cbhs`, `cblt.u64`, `rorl`, `fadd32`, `.u32`, `.f64`, `.asciz`, `.global`, `.db`, `db`), the operand shapes of about eighty words, the byte length of the one-operand words against the ALU spellings (`--stats`), the bytes of `r5-8`, `-8(r5)`, `(r5)-8`, `(r5)+8` (extracted from the ELF `.text`), the undefined symbols for `pc`, `dp`, `1.5` and `2.5` (`readelf -s`), the destination order of every syntax line of manual 9 (a script over the code blocks), and the static counts in `docs/codegen-data/mnemonics_pdp64.csv`.
