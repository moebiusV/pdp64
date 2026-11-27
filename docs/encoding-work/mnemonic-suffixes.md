# The width and kind of an operation as a suffix of the mnemonic (design only)

I write this for someone who knows a little PDP-11 assembly. Nothing here is built. The owner decided (errata 230, R552) that the width and kind of an operation is a dotted suffix of the mnemonic, and asked me to work out what that does to every word, to the assembler and to everything that writes assembly. I checked the grammar, the assembler and the disassembler, and I built a scratch copy of the assembler in a private directory (not in the repository) to see what lexes. No file but this one was changed.

**Correction, written after the notation was settled.** A mark on an operand is of two kinds, and this note speaks of only the first. A register mark is a suffix of a register's name and only `fcvt` takes one (`fcvt r1.f16, r2.f32`). A value mark is a suffix of a number or a symbol (`0xff.s8`, `limit.u16`): it says how many bits the value has and how to read them, it is written only where the value deviates, and it is not a width of the operation. The immediate in the examples below, written `#5`, is written `$5` now; `#5` is still read as the same thing.

## 1. The story

On the PDP-11 you wrote `MOVB` and the "B" said how much to move. Here the same idea has been written four ways in a few days: the letters `b w l q` (errata 227), the operand marks in bits `(r1).8` (errata 223, 226), the floating-point letters `f` and `d` (228), and the float marks `.f32` (229). Each was right about something and wrong about something else. The letters could not say "unsigned" for a rotate or "single" for a conversion, so marks were added. The marks could not be read at a glance (`fcvt r1.32, r2.s32`: is `.32` a float or an integer?), and a mark glued to an operand makes the lexer fight with names (`r1.8` is a perfectly good symbol today).

The owner's answer is the one the VAX and the PDP-11 would recognize as their own idea made regular: the suffix belongs to the mnemonic, because it is the operation that has a width, not the operand. A suffix is a dot, a kind letter and a width in bits:

* `.s8 .s16 .s32 .s64` and `.u8 .u16 .u32 .u64` for integers (signed, unsigned; the width in bits),
* `.f16 .f32 .f64` for floating point (`.f8` is reserved: there is no 8-bit format, and I refuse it as such),
* a bare mnemonic is the default: 64 bits (a bare floating-point word is double).

The kind letter also answers the question the marks could not: `fcvt.s32.f32` and `fcvt.f32.s32` cannot be misread, because `s` is an integer and `f` is a float. Nothing in the encoding changes: the assembler picks the opcode that exists, and the opcode words (`movb`, `aaddl`, `fadd32`, `fcvtds`) stay as the internal names of the encoding tables.

A side effect worth saying first: the whole family of errors of the operand marks cannot arise any more. There is no "mark on the destination register", no "marks that disagree across the operands of one float word", no "mark on a constant", no unmarked register beside a marked one. The suffix is on the word, so it is on every operand at once. That is the first principle (an error that cannot arise is better than one that is detected), paid for by nothing.

## 2. The rule in one paragraph, and one example of every family

The suffix is the last dotted part of the mnemonic: `mov.s8`, `fadd.f32`, `amax.u32`. Before it there may be a qualifier that is part of the word (`mov.user`, `mcpy.ur`). The operands are written as they always were; none carries a mark. Mnemonics are lower case, as now.

| Family | New | Was (letters) | Was (marks) |
|---|---|---|---|
| load signed byte | `mov.s8 (r1), r2` | `movb (r1), r2` | `mov (r1).8, r2` |
| load unsigned halfword | `mov.u16 (r1), r2` | `movzw (r1), r2` | `mov (r1).u16, r2` |
| store word | `mov.s32 r2, 4(r1)` (`mov.u32` is accepted and means the same) | `movl r2, 4(r1)` | `mov r2, 4(r1).32` |
| user load | `mov.user.s8 (r1), r2` | `movb.u (r1), r2` | `mov.u (r1).8, r2` |
| byte swap of each 32-bit long | `bswap.u32 r1, r2` (`.s32` accepted) | `bswapl r1, r2` | `bswap r1.32, r2` |
| rotate, 32 bits | `ror.s32 r1, #5, r2` | `rorl r1, #5, r2` | `ror r1.32, #5, r2` |
| atomic add, 32 bits | `aadd.s32 r1, (r2), r3` | `aaddl r1, (r2), r3` | `aadd r1, (r2).32, r3` |
| atomic maximum, unsigned, 64 bits | `amax.u64 r1, (r2), r3` | `amaxu r1, (r2), r3` | the same word |
| fadd, single | `fadd.f32 r1, r2` | `faddf r1, r2` | `fadd r1.32, r2.32` |
| fabs, single | `fabs.f32 r1, r2` | `fabsf r1, r2` | `fabs r1.32, r2` |
| fcb, single | `fcblt.f32 r1, r2, label` | `fcbltf r1, r2, label` | `fcblt r1.32, r2.32, label` |
| fcvt: signed 32-bit integer to single | `fcvt.s32.f32 r1, r2` | (no letter) | `fcvt r1.s32, r2.32` |
| fcvt: double from a signed 32-bit integer | **no such opcode** (section 4d): `fcvt.s64.f64 r1, r2` on a register that already holds the sign-extended integer | | |
| the plain 64-bit move | `mov r1, r2` (`mov.s64` and `mov.u64` accepted) | `movq r1, r2` or `mov r1, r2` | the same |

## 3. The complete mapping

Every word that carries a letter or a mark today. "Opcode word" is the word of the encoding the assembler picks (unchanged). A word in the column "Written today" is withdrawn: it becomes an unknown mnemonic, with a message that says which suffixes the word takes. The count of withdrawn words is at the end of the section.

### 3.1 Integer moves (14 words become 2 words with suffixes)

The one word `mov` loads, stores, or (between registers) sign- or zero-extends, as `movb` did. A store has no zero-extending opcode, so `.u8 .u16 .u32` on a store assemble to the plain word (decision 4b).

| New spelling | Written today | Opcode word | Meaning |
|---|---|---|---|
| `mov.s64`, `mov.u64` (a 64-bit move extends nothing: one word); bare `mov` is an alias of `mov.s64` | `movq`, `mov` | MOVQ | 64 bits: load, store, register move |
| `mov.s32` | `movl` | MOVL | load sign-extending; store the low 32 bits; between registers, sign-extend the low 32 |
| `mov.u32` | `movzl` (store: `movl`) | MOVZL (store: MOVL) | load zero-extending; between registers, zero-extend; a store is MOVL |
| `mov.s16` | `movw` | MOVW | as `.s32`, 16 bits |
| `mov.u16` | `movzw` (store: `movw`) | MOVZW (store: MOVW) | as `.u32`, 16 bits |
| `mov.s8` | `movb` | MOVB | as `.s32`, 8 bits |
| `mov.u8` | `movzb` (store: `movb`) | MOVZB (store: MOVB) | as `.u32`, 8 bits |
| `mov.user` and `mov.user.s64`, `.u64` | `movq.u` | MOVQ.U | the memory operand is checked as a user access (decision 4a) |
| `mov.user.s32` | `movl.u` | MOVL.U | |
| `mov.user.u32` | `movzl.u` | MOVZL.U | |
| `mov.user.s16` | `movw.u` | MOVW.U | |
| `mov.user.u16` | `movzw.u` | MOVZW.U | |
| `mov.user.s8` | `movb.u` | MOVB.U | |
| `mov.user.u8` | `movzb.u` | MOVZB.U | |

`mov.user` needs a memory operand (it is a user-memory access); between registers it is refused. A suffix on a move whose source is a constant (`mov.s8 #5, r1`, `mov.u32 =K, r1`) is refused: a constant has no width, and the move of a constant is the plain `mov`. (This is what the old note said of the marks; the reason is that a "sign-extend the low byte of 200" would be a computation the assembler does silently.)

### 3.2 Byte swap and rotate

| New | Written today | Opcode word | Notes |
|---|---|---|---|
| `bswap`, `bswap.u64`, `bswap.s64` | `bswap` | BSWAP | all 8 bytes |
| `bswap.u32` (`.s32`) | `bswapl` | BSWAPL | the bytes of each 32-bit long of the register |
| `bswap.u16` (`.s16`) | `bswapw` | BSWAPW | the bytes of each 16-bit word of the register |
| `ror`, `ror.s64`, `ror.u64` | `ror` | ROR | register or constant count (and `rol`, an alias, as now) |
| `ror.s32` | `rorl` | ROR32 | constant count only; the result is the 32-bit rotate **sign-extended** (the manual: `sext32(ror32(...))`), so only `.s32` is true: `ror.u32` is refused |

### 3.3 The atomics (24 letter words, 12 `q` spellings, `amaxu` and `aminu`: 38 words)

Ten operations, two sizes. The 4-byte atomics return the old value **sign-extended** (the manual, 7.4.6), so the only true kind for a 4-byte atomic that returns a value is `.s32`; `.u32` is refused there (decision 4b). `amax` and `amin` are the exception: the kind is the comparison (signed or unsigned). `sc` returns 0 or 1, not a value, so it takes either.

| Operation | 64-bit: new | 64-bit: written today | 32-bit: new | 32-bit: written today |
|---|---|---|---|---|
| compare and swap | `cas` (`.s64`, `.u64`) | `cas`, `casq` | `cas.s32` | `casl` |
| swap | `swap` (`.s64`, `.u64`) | `swap`, `swapq` | `swap.s32` | `swapl` |
| add | `aadd` (`.s64`, `.u64`) | `aadd`, `aaddq` | `aadd.s32` | `aaddl` |
| and | `aand` (`.s64`, `.u64`) | `aand`, `aandq` | `aand.s32` | `aandl` |
| or (bit set) | `abis` (`.s64`, `.u64`) | `abis`, `abisq` | `abis.s32` | `abisl` |
| exclusive or | `axor` (`.s64`, `.u64`) | `axor`, `axorq` | `axor.s32` | `axorl` |
| load-linked | `ll` (`.s64`, `.u64`) | `ll`, `llq` | `ll.s32` | `lll` |
| store-conditional | `sc` (`.s64`, `.u64`) | `sc`, `scq` | `sc.s32`, `sc.u32` | `scl` |
| maximum, signed | `amax`, `amax.s64` | `amax`, `amaxq` | `amax.s32` | `amaxl` |
| maximum, unsigned | `amax.u64` | `amaxu`, `amaxuq` | `amax.u32` | `amaxul` |
| minimum, signed | `amin`, `amin.s64` | `amin`, `aminq` | `amin.s32` | `aminl` |
| minimum, unsigned | `amin.u64` | `aminu`, `aminuq` | `amin.u32` | `aminul` |

8-bit and 16-bit atomics do not exist; `aadd.s16` is refused with that message, as `(r).16` is today.

### 3.4 Floating point

There is no floating-point register file: a float lives in an ordinary register, so the suffix is the only thing that says which format. One suffix covers every operand of the word.

| New (double: bare, or `.f64`) | New (single) | Written today, double | Written today, single | Opcode word of the single |
|---|---|---|---|---|
| `fadd` | `fadd.f32` | `fadd`, `faddd` | `faddf`, `fadd32` | FADD32 |
| `fsub` | `fsub.f32` | `fsub`, `fsubd` | `fsubf` | FSUB32 |
| `fmul` | `fmul.f32` | `fmul`, `fmuld` | `fmulf` | FMUL32 |
| `fdiv` | `fdiv.f32` | `fdiv`, `fdivd` | `fdivf` | FDIV32 |
| `fsqrt` | `fsqrt.f32` | `fsqrt`, `fsqrtd` | `fsqrtf` | FSQRT32 |
| `fmadd` | `fmadd.f32` | `fmadd`, `fmaddd` | `fmaddf` | FMADD32 |
| `fnmsub` | `fnmsub.f32` | `fnmsub`, `fnmsubd` | `fnmsubf` | FNMSUB32 |
| `fclass` | `fclass.f32` | `fclass`, `fclassd` | `fclassf` | FCLASS32 |
| `fabs` | `fabs.f32` | `fabs`, `fabsd` | `fabsf` | FABS32 (AND with the sign mask) |
| `fneg` | `fneg.f32` | `fneg`, `fnegd` | `fnegf` | FNEG32 (XOR with the sign mask) |
| `fcbeq fcbne fcblt fcble fcbgt fcbge fcbor fcbuo` | the same with `.f32` | the same, and `...d` | `fcbeqf` ... `fcbuof`, `...32` | FCBEQ32 ... FCBUO32 (`fcbgt`, `fcbge` are aliases that swap the registers, as now) |

The double-only words (`fmin fmax fcopysign frint frintz frintm frintp frinta`) accept `.f64` as an explicit spelling (one rule: every floating-point word accepts `.f64`), and refuse `.f32` with "no single-precision form". `.f16` is refused on every word except `fcvt` ("no half-precision arithmetic"); `.f8` is refused as "no such format". `fsflags` has no precision. Words withdrawn: 10 f-letter + 10 d-letter + 8 + 8 compare-and-branch letter words = 36, with the two conversion letter words `fcvtdf fcvtfd` below.

### 3.5 Conversions: `fcvt` (14 opcode words, plus the two letter words)

The suffix pair is **source, then destination**, in the order of the operands (decision 4d). A bare `fcvt` is refused (it names two formats). All 14 forms:

| New | Written today (marks) | Opcode word |
|---|---|---|
| `fcvt.f64.s64 r1, r2` | `fcvt r1.64, r2` | FCVTDQ |
| `fcvt.f64.u64` | `fcvt r1.64, r2.u64` | FCVTDQU |
| `fcvt.s64.f64` | `fcvt r1, r2.64` | FCVTQD |
| `fcvt.u64.f64` | `fcvt r1.u64, r2.64` | FCVTQUD |
| `fcvt.f64.f32` | `fcvtdf`, `fcvt r1.64, r2.32` | FCVTDS |
| `fcvt.f32.f64` | `fcvtfd`, `fcvt r1.32, r2.64` | FCVTSD |
| `fcvt.f32.s32` | `fcvt r1.32, r2.s32` | FCVTSL |
| `fcvt.s32.f32` | `fcvt r1.s32, r2.32` | FCVTLS |
| `fcvt.f32.f16` | `fcvt r1.32, r2.16` | FCVTSH |
| `fcvt.f16.f32` | `fcvt r1.16, r2.32` | FCVTHS |
| `fcvt.f64.f16` | `fcvt r1.64, r2.16` | FCVTDH |
| `fcvt.f16.f64` | `fcvt r1.16, r2.64` | FCVTHD |
| `fcvt.f16.s32` | `fcvt r1.16, r2.s32` | FCVTHL |
| `fcvt.s32.f16` | `fcvt r1.s32, r2.16` | FCVTLH |

The owner's decision on aliases (errata 232) adds three short spellings, accepted and printed for the integer-to-float conversion of equal width: `fcvt.s64` is `fcvt.s64.f64`, `fcvt.u64` is `fcvt.u64.f64`, `fcvt.s32` is `fcvt.s32.f32`; the two-suffix forms stay official and stay accepted, no other conversion has a short form, and a bare `fcvt` is still refused (its message lists the short forms). Every other pair is refused with a plain message that says it does not exist. Two that a reader will expect and that **have no opcode**: a 32-bit integer to or from a double (`fcvt.s32.f64`, `fcvt.f64.s32`) and any unsigned 32-bit integer (`fcvt.u32.f32`). I did not invent them (Occam: no word without a benefit that the existing ones do not already give): a 32-bit result is always held sign-extended in its 64-bit register, so `fcvt.s64.f64` already converts a 32-bit signed value to a double; an unsigned 32-bit value is zero-extended first with `mov.u32 r1, r1`. An integer-to-integer conversion is a `mov` (`mov.s8 r1, r2`, `mov.u32 r1, r2`); `fcvt.s32.s64` is refused and the message says so.

**Correction.** The two-suffix words of this section are withdrawn, and so are the decisions of this section that rest on them (the words with two dotted suffixes are unknown mnemonics now). A mnemonic carries one suffix, and a conversion has two formats, so where one suffix is not enough I write the formats on the operands, directly after a register, the source first and the destination last: `fcvt r1.f16, r2.f32` converts the half in `r1` to a single in `r2`. Read the table above with each `fcvt.A.B r1, r2` as `fcvt r1.A, r2.B`: `fcvt r1.f64, r2.s64` is a double to a signed integer, `fcvt r1.s64, r2.f64` a signed integer to a double, `fcvt r1.s32, r2.f32` a signed 32-bit integer to a single, and so on for the fourteen; the table of the manual's entry for `FCVT` lists them all. The three short forms stay, with their meaning (`fcvt.s64 r1, r2` is `fcvt r1.s64, r2.f64`, `fcvt.u64 r1, r2` is `fcvt r1.u64, r2.f64`, `fcvt.s32 r1, r2` is `fcvt r1.s32, r2.f32`), and the disassembler, pcc and LLVM print the short form where it applies and the operand form otherwise. An operand mark is `.s8 .u8 .s16 .u16 .s32 .u32 .s64 .u64 .f16 .f32 .f64`, written after a register name and nowhere else (a name such as `buf.f32` or a label `x.s8:` is a name), and only `fcvt` takes one; both operands carry a mark, and a short form with marks, a bare `fcvt r1, r2` and a float suffix alone (`fcvt.f64 r1, r2`) are refused. The pairs with no instruction, a 32-bit integer and a double, anything unsigned 32-bit, a 64-bit integer and a single, an 8-bit integer, are refused with the two-instruction way in the message. The assembler reads the mark as a small step of the operand parser, a token of the grammar made of a register and its mark, not as a pass over the text.

### 3.6 Signedness variants (the words that become a kind suffix of one word)

| New | Written today | Opcode word |
|---|---|---|
| `div`, `div.s64` / `div.u64` | `div` / `divu` | DIV / DIVU |
| `mod`, `mod.s64` / `mod.u64` | `mod` / `modu` | MOD / MODU |
| `mulh`, `mulh.s64` / `mulh.u64` | `mulh` / `mulhu` | MULH / MULHU |
| `mul`, `mul.s64`, `mul.u64` | `mul`, `mulu` (an alias of `mul`) | MUL (the low half is the same for either kind) |
| `min`, `min.s64` / `min.u64` | `min` / `minu` (aliases: the sequence SETLT, NEG, BSEL; SETLO...) | the sequences as now |
| `max`, `max.s64` / `max.u64` | `max` / `maxu` | |
| `amax`, `amin`, with `.u64`, `.u32` | `amaxu`, `aminu`, `amaxul`, `aminul` | in 3.3 |
| `fcvt.f64.u64`, `fcvt.u64.f64` | `fcvtdqu`, `fcvtqud` | in 3.5 |

`div.u32` and the like do not exist (no 32-bit divide): refused, and the message says "convert with `mov.u32` first".

### 3.7 Words that carry a letter or a width in their name and **stay**

| Word(s) | Why it stays |
|---|---|
| `shr` against `sar`, `asl`, `asr` | different operations (logical against arithmetic shift), not one operation in two kinds; there are no 32-bit shifts |
| `cbeq cbne cblt cble cbgt cbge`, `cbhi cblos cbhis cblo cbcc cbcs`; the `set` and `ct` families with the same conditions | the unsigned relations are conditions, with the PDP-11's names (`BHI`, `BLOS`, `BHIS`, `BLO`, `BCC`, `BCS`); decision 4c |
| `extb extzb insb` | B is "bit field", not "byte"; the width is an operand (an immediate), so no suffix has anything to say |
| `lea`, `push pop pushm popm popret popmret` | an address and 64-bit stack words: no width |
| `clz ctz clo cto popcnt bitrev xnorpop clmull clmulh utf8len utf8dec utf8enc dshr` | 64 bits only: no sibling in another width |
| `addm subm bicm bism` | the read-modify-write on memory: 64 bits only (the same sub-opcode field as `movq movl movw movb` of the store forms, but no sized sibling exists). If sized siblings are ever added, `addm.s32` is the spelling |
| `addv subv mulv` | signed-overflow-checking, 64 bits |
| `mcpy mmov mset mcmp mscn mscnn mval`, `mcpy.ur`, `mcpy.uw` | bytes counted by a register; the user qualifier `.ur` `.uw` does not collide (no digit after `.u`) |
| `mov2`, `movcall` | fused words, 64 bits |
| `fmin fmax fcopysign frint*`, `fsflags` | double only; the suffix `.f64` is accepted on them, nothing else |
| the 359 vector words (`vadd.b`, `vld.b.l`, `vcvt.f.l` ...) | out of scope, as the owner left them: their dotted letters name lanes (`b w l q d f`, `bu`), not an operand. They could later become `.s8 .s16 .s32 .s64 .u8 .f32 .f64` by the same pattern (`vadd.f` would be `vadd.f32`, `vld.b.l` would be `vld.s8.s32`); until then a reader meets `vadd.f` (single lanes) beside `fadd.f32`, and `vadd.d` (double lanes) beside a scalar that no longer has a `d` |
| `movsb` | does not exist |

Count. Words withdrawn (they become unknown): 7 integer move words, 7 user move words, `bswapw bswapl rorl`, 12 atomic `l` words and 12 `q` words, `amaxu aminu`, `divu modu mulhu mulu minu maxu`, 36 floating-point letter words, `fcvtdf fcvtfd`: **87 words**. (`ror32` and the other opcode words are already not words of the assembly language.) Spellings accepted instead: **129 new words** in the grammar, generated from one table (16 for `mov`, 8 and a bare one for `mov.user`, 6 for `bswap`, 3 for `ror`, 33 for the atomics, 44 for the floating-point words, 12 for the variants of `div mod mulh mul min max`, 14 for `fcvt`; the bare words that exist already are not counted). The 87 old words and the 129 new ones are not a one-for-one swap because the new table also accepts the explicit 64-bit spellings (one extra accepted spelling per word costs nothing). `movq` is among the 87.

## 4. The decisions the owner left to me

### 4a. The user-memory qualifier

It was `.u` (`movb.u`, `movzw.u`), and is now confusable with the kind `.uX` (`mov.u8`). A reader sees `.u` followed by digits as a kind and by nothing as a qualifier, and a typing slip (`mov.u (r1), r2`) would be a quiet error today if `.u` stayed accepted.

| Candidate | Looks like | Lexer | Against it |
|---|---|---|---|
| `mov.user.s8 (r1), r2` | a word that says what it is | a whole word like `mcpy.ur`; no digit, so no clash with `.uX` | longer by 3 characters on a rare word (kernel copy-in and copy-out) |
| `mov.s8.usr (r1), r2` | shorter | fine | `usr` is a directory name, not a word; qualifier after the suffix, so "the suffix is the last part" fails |
| `umov.s8 (r1), r2` | a new word | a new mnemonic | a new entity (Occam), and the family `mov` splits in two |
| keep `mov.u8.u` | | | the exact confusion the owner named |

**Recommendation: `.user`, written before the kind suffix: `mov.user.s8`, `mov.user.u16`, `mov.user` (64 bits).** Reasons: (1) one rule for the lexer, the assembler and the disassembler: the kind suffix is the last dotted part, and what is before it (`mov.user`, `mcpy.ur`) is the word; (2) the plain word is self-explanatory to the first-year student; (3) it cannot be confused with `.u` + digits, and the bare `.u` is withdrawn so that a leftover `movb.u` is an unknown word, not a mis-read one. I checked it in the scratch assembler: `mov.user.s8` lexes as one whole-word mnemonic, and `mov.u` is not a word. `mcpy.ur` and `mcpy.uw` keep their names (they do not collide); I note that "ur" and "user" are two spellings of one idea and offer `mcpy.user.r` and `mcpy.user.w` only if the owner wants the two matched. I did not recommend it: it would rename two words for looks.

### 4b. Stores and the words where the kind means nothing

The facts I found in the manual change the question. The kind letter says one of two things: how a value is **widened into the 64-bit register** (loads, register conversions, and what a 4-byte atomic or a 32-bit rotate leaves in its destination) or **how two values are compared** (`amax`, `div`). Where neither happens (a store, a byte swap within lanes, the 64-bit forms where nothing is widened), the kind means nothing. Where the register receives a sign-extended result, only `.s32` is true: the 4-byte atomics return the old value sign-extended (7.4.6) and `ror.s32` is `sext32(ror32(...))`. A `.u32` there would promise a zero-extension the hardware does not do, and a program that trusted it would compare a sign-extended 3,000,000,000 as negative.

Rule (one rule for all words):

1. **Where the kind has no effect, either letter is accepted.** That covers stores of 8, 16 and 32 bits, `bswap` at 16, 32, 64, the explicit 64-bit forms of everything, and `sc`. The bytes are the same.
2. **Where the destination register receives an extended value, only the true kind is accepted:** `.s32` for the 4-byte atomics that return a value (`cas swap aadd aand abis axor ll`) and for `ror`; the loads and register conversions take both kinds (they differ), and `amax`, `amin` take both (the comparison differs). The false one is refused with a message that says the old value comes back sign-extended and what to write (`.s32`, then `mov.u32 r, r` if you want it zero-extended).
3. **The disassembler prints the spelling of the opcode word, one to one:** `movb`, `movw`, `movl` print `.s8 .s16 .s32` (in the store form too), `movzb movzw movzl` print `.u8 .u16 .u32`, `aaddl` prints `aadd.s32`, `amaxul` prints `amax.u32`, `bswapw` and `bswapl` print `.u16 .u32` (a kind with no meaning gets `.u`, "just bits"), and the 64-bit words print bare.

I weighed the owner's two readings. "`.u` is just bits" is right for the words where nothing is widened (that is why `bswap` prints `.u`), but it is wrong for a store, where the opcode is `MOVB`, the same word as the sign-extending load: printing `.u8` for a store of MOVB and `.s8` for the load of MOVB would make one opcode word two spellings, and every tool (the disassembler, the LLVM printer, pcc's renaming pass) would have to look at the operands again, which is precisely the code this change deletes. One word, one spelling is what makes pcc's pass a plain word rename. Both letters are accepted on input so that nobody has to remember which. Alternative, if the owner prefers `.u` for stores: the cost is a direction test in the three printers, and a listing in which `movb` prints two ways.

**One thing I cannot decide for the owner (it needs a hardware or semantics choice, and it is not in this change): `amax.u32` and `amin.u32` compare unsigned but still return the old value sign-extended.** A reader of `.u32` expects a zero-extended result. I recommend the manual says it in one sentence next to the table of 4.3 and that nothing else is done now; making `amaxul` and `aminul` return the zero-extended old value is a one-line semantic change in the simulator, QEMU and the manual, with no change of encoding, and the owner can order it separately.

### 4c. The signedness variants: which become suffixes

Rule: **a signedness suffix is a variant of the same operation; a different operation keeps its own name.** The test I applied is the owner's: can I say "the same operation, on an operand of the other kind"? Division, remainder, the high half of a product, the maximum and the minimum, the atomic maximum and minimum, and the conversions to and from an unsigned integer all pass; they become `div.u64`, `mod.u64`, `mulh.u64`, `min.u64`, `max.u64`, `amax.u64`, `amin.u64`, `fcvt.f64.u64` (list in 3.6). `mulu` is not even a different instruction (the low half of a product is the same for both kinds): the word is withdrawn and `mul.u64` is accepted as an explicit spelling of `mul`.

What stays, each for a reason I can say in a sentence:

| Word | Why |
|---|---|
| `shr` against `sar` | logical shift and arithmetic shift are different operations (what enters on the left differs); the PDP-11's own names are `ASR` and `ASL`. `shr.u64` and `shr.s64` would hide that |
| `cbhi cblos cbhis cblo`, `cbcc cbcs` (and `sethi`, `setlos`, `sethis`, `setlo`, `setcc`, `setcs`, `cthi`, `ctlos`, `cthis`, `ctlo`, `ctcc`, `ctcs`) | these are the unsigned relations. They are conditions, the vocabulary of the PDP-11 (`BHI`, `BLOS`, `BHIS`, `BLO`, `BCC`, `BCS`); `cblo` is not "`cblt` on another kind", it is the carry-set branch every PDP-11 reader knows |
| `extb` against `extzb`, `insb` | the width of a bit field is an operand, so there is no X to write: `extb.s64` would carry a 64 that says nothing |
| `movzb` and its relatives | not kept: they are `.u8`; the load that zero-extends is the same move with the other kind |

The edge, and I say plainly that it is a judgment call: one could also write the conditions as suffixes (`cblt.u64` for `cblo`). I recommend against it for three reasons: the six carry and unsigned names are the PDP-11's and the principle of least astonishment in notation (precedent matters for notation, principles, "Precedent is neutral" but notation is the stated exception) says keep them; a compare-and-branch has no width, so the suffix would always be `.64` and carry only the relation, which a condition name already does; and `cbcc` and `cbcs` (carry clear, carry set) have no signed twin, so the pattern would not even cover the family. The alternative costs 12 + 12 + 12 words renamed in the tests (cb: 77 uses in 17 files) and the manual, for no new information.

### 4d. `fcvt`, the two-kind suffix

Order: **source, then destination, in the order of the operands** (the manual's rule is that the destination is last): `fcvt.s32.f32 r1, r2` reads "from signed 32 to single; r1 in, r2 out". The PDP-11's `LDCDF` (double to float) and the VAX's `CVTLD` (long to double) name source then destination, and their operands follow the same order, so the precedent is the right one here. RISC-V is the exception, because its operands are destination first (`fcvt.d.w rd, rs`): the suffix order follows the operand order there as well, so the principle (suffixes in operand order) is the common ground, not a copy of either. The old letter words were already source first (`fcvtdf`: from d to f), so this keeps the letters' order: nothing is read backwards. A confusion risk I considered: someone may read `fcvt.f64.s32` as "to f64 from s32". The kind letters (`f`, `s`, `u`) are what make the two readings differ, and a wrong guess gives an error, not a wrong instruction, because the combination `f64`-from-`s32` has no opcode (3.5): the wrong reading never assembles by luck. The 14 forms are listed in 3.5. Conversions with a float on one side and an integer on the other go in both directions through the same word; integer to integer is `mov`; no conversion needs the bit-field words.

### 4e. The default and the explicit 64 bits

Recommendation (adopted by the owner: see the end of this section): **yes, accept the explicit 64-bit spelling wherever the word has other widths or kinds**: `mov.s64`, `mov.u64`, `fadd.f64`, `aadd.s64`, `aadd.u64`, `bswap.u64`, `ror.s64`, `div.s64`, `mul.u64`. Reasons: a generated program says `fadd.f64` or `mov.s64` without a special case for 64; the owner's rule "bare is the default" stays true (the disassembler prints bare); one more accepted spelling costs a row. Words that have no other width are not given an explicit 64 (`add.s64` is unknown, as `add.u32` is: the suffix exists where there is something to choose, no more).

**Decided by the owner (his words: "if we have mov.s64 why do we need movq? and mov becomes alias for mov.s64"): `movq` is not kept.** It is a plain unknown mnemonic after the change, with no hint (the message does not suggest `mov`). The explicit 64-bit move is `mov.s64`, `mov.u64` is the same word, and bare `mov` is an alias of `mov.s64`. I generalize it as one rule, which the tables in section 3 already follow: **a bare word that has a default width is an alias of its explicit 64-bit spelling**: `mov` = `mov.s64`, `aadd` = `aadd.s64`, `fadd` = `fadd.f64`, `div` = `div.s64`, `amax` = `amax.s64`, `bswap` = `bswap.s64`, `ror` = `ror.s64`. The canonical kind of the explicit 64-bit spelling is `.s` (the owner's own choice for `mov`; for the words where the kind means nothing, section 4b accepts both letters, and I take `.s` so that the alias is the same letter everywhere and the bare word of the signed variants, `div`, `amax`, `min`, is the signed one). `.u64` is accepted beside it and means the same where nothing is extended or compared, and is the unsigned variant where something is (`div.u64`, `amax.u64`). A word with no other width or kind has no explicit 64-bit spelling (`add.s64` is unknown).

What `movq` costs in blast radius, counted by search (the word `movq` as a whole word, any case):

| Where | Files | Lines |
|---|---|---|
| test sources (`tests/`) | 191 | 67,787 (`tests/sim` 106 files and 50,439 lines, `tests/qemu` 38 and 16,818, `tests/sec-open` 5 and 244, `tests/asm-equiv` 13 and 76, `tests/asm` 10 and 50, `tests/sec` 2 and 75, `tests/enc` 1 and 25, `tests/forms` 1 and 18, `tests/asm-err` 9, `tests/timing` 11, `tests/relax` 3, `tests/ld` 3) |
| manual chapters and dictionary (`docs/manual/*.md`) | 10 | 191 |
| manual figures (generated svg) | 43 | (regenerated) |
| annex (`docs/annex`) | 26 | 77 |
| other documents under `docs` (design notes, history included) | 63 | 968 (most are history under `docs/encoding-work` that I would leave) |
| manual generators (`tools/manual/*.py`) | 8 | 17 |
| tools, all (`tools/`) | 34 | 121 (py, sh, c) |
| `spec` (grammar parts, `tables.md`) | 10 | |
| `as64` | | 6 |

Almost all of the test lines are three generated programs (`tests/sim/fma-negate.s` 18,836, `absminmax.s` 11,695, `nocc.s` 5,147) and the memory-management matrix (`mmu-matrix-*.S`, about 12,000). Because bare `mov` already assembles to MOVQ, the conversion is the mechanical replacement of the word `movq` by `mov` (the converter writes the bare word; the explicit spelling is for people and generators who want it). The word `movq` stays in the encoding tables as the name of opcode 0; it is only withdrawn as a spelling.

**How the disassembler prints the 64-bit move: I pick the bare `mov`** (and bare `aadd`, `fadd`, `div` for every 64-bit word). Reasons: (1) bare is what the owner types and what 99 per cent of a listing is, so the explicit form would put `.s64` on most lines of every listing and bury the one line in a thousand that has a narrower width: the suffix is the thing worth seeing, so it should appear only when it is there; (2) the bare word and the explicit one are one word by the alias rule, so the round trip (which compares bytes) loses nothing; (3) one word, one printed spelling stays true, the spelling being the bare one for the 64-bit word. The case for the explicit form is real for generated code, where `mov.s64` is clearer than a default the reader must remember; so the writers of assembly (pcc's rename table, LLVM's instruction strings) may emit either, and I recommend they emit the bare word too, for one spelling in every tool. If the owner prefers explicit output in the compilers only, it is one column in the generated rename table and costs nothing in the language.

### 4f. The lexer

I took a scratch copy of the repository in a private directory, removed the mark layer, and added the new spellings as words of the grammar the way `mcpy.ur` is today. The findings:

1. **The old mark layer would eat the new suffix.** `mark_prescan()` (as64/asmp.c) turns a dot followed by `8 16 32 64`, with an optional `u` or `s`, into a control character wherever the dot is not preceded by a blank. In `mov.s8` the dot is preceded by `v`, so `.s8` would be taken as a mark. The layer must go in the same change (it goes anyway).
2. **Removing it fixes two things that are broken today.** A label `x.s8:` is a parse error today (I ran it); a symbol `buf.u8`, `foo.16`, `retw.u16` becomes a mark. After removal both are plain names again. (The tests contain symbols such as `tmplw.32` and `retw.u16`: 71 and 14 uses.) The note on the marks, "a name that ends in a mark must be quoted", is no longer true, which retires its decision F.
3. **A suffixed word must be a whole word of the grammar.** hbnf's word scanner counts `.` as a name character, so `mov` is not matched as the front of `mov.s8`, and a rule "base, dot, kind" cannot be written. The words are enumerated, like `mcpy.ur` and the 359 vector words; the table of 129 words is generated from one table by tools/mkgrammar.py. With them in the grammar the assembler parsed `mov.s8`, `mov.user.s8`, `fcvt.s32.f32`, `amax.u32`, `fadd.f32` as mnemonics (the scratch assembler then said "this instruction does not exist" only because I had not written the map).
4. **Unknown suffixes give a bad message today.** `mov.s9 (r1), r2`, `fadd.f8 r1, r2`, `mov.s8.x (r1), r2` do not parse as an instruction; they parse as a datum label (`label = symbol &dkword` accepts a name before `db`) and fail at the `(` with "expected `:`, `=` or `equ` ... found (". For the refusals the owner asked for (`.f8` "no such format", `aadd.s16` "no 16-bit atomic") this is not good enough. Fix (no change to the language): when a line fails to parse and its first word is a known mnemonic with a dotted tail, as64 says "`mov`: no suffix `.s9`; the kinds are `.s8 .u8 ...`". This is a diagnostic on the error path only, not a lexer layer. Refusals that need a clear text (`.f8`, a 16-bit atomic) are best made words of a refused list in the same table so they parse and are refused by name.
5. **Directives and local labels:** the directives are `.chk .encode .fill .pool .text .data .bss .globl .comm .byte .word .long .quad .even .align .space .ascii .lpad .if .else .endif .bugrec`; none is `s8 u8 f32` and so on, and a directive starts a statement, so `.s8` there is an error as today (I ran `.u8 1`, `.f32`, `.s16 1`: errors, no meaning). Local labels (`1:`, `1f`, `1b`) start with a digit and are operands; `mov.s8 1f, r2` lexes as the word and the operand.
6. **The existing dotted words:** `mcpy.ur`, `mcpy.uw`, the seven `...u` words (withdrawn) and `.encode` have no digit after `.u`, so they cannot be read as a kind. `mov.user` is a new word of that kind.
7. **The vector lane suffixes:** `vadd.f` (float lanes) is a whole word; `vadd.f32` is not a word and is an error today and after (I ran both: `vadd.f v1, v2, v3` assembles, `vadd.f32 v1, v2, v3` is a parse error). A whole-word keyword is not a prefix of a longer word, so `.f` does not capture `.f32`. No conflict. The cosmetic one is in 3.7.
8. **Case:** mnemonics are lower case only, as today (`MOV.S8` is not a word), and nothing here changes it.
9. **Operands:** with the mark layer gone, `(r1)+.s8` is a stride error and `r1.s8` is a symbol, as `r1.8` was before the marks. Nothing silently becomes valid.

## 5. The blast radius and the plan

The operand marks are withdrawn, so the whole mark layer is deleted. It is the largest part of the work and the part that gets simpler.

**Deleted:**

* `as64/asmp.c`: `mark_prescan()`, `MARKCH`, `idc_byte()`, the mark reading in `operand()` (about 30 lines); `as64/asmir.h`: the fields `mark mwidth msign`.
* `spec/grammars.d/60-asm-syntax.hbnf`: the rules `mark marksign marknum` and the `[ mark ]` of `operand` (6 lines).
* `as64/asmenc.c`: `marks_resolve()` and its helpers `mark_text()`, `is_memop()` (about 150 lines of checks about which operand carries which mark); replaced by a lookup from the spelling to the opcode word with about eight refusals (a constant operand, `.user` without memory, a width the word does not have, `.u32` on a returning atomic, ...), about 40 lines.
* `spec/grammars.d/61-asm-marks.hbnf` (48 lines): replaced by one table of suffix rows (spelling, opcode word, the form it applies to, and the spelling the disassembler prints).
* `tools/marks.py` (155 lines): `spell()` and `unspell()` operate on operand marks; they become a word-to-spelling table (about 30 lines). `tools/mkgrammar.py` loses `marks_rows`, `marks_letters`, `marks_header`, `marks_pcc_header` (about 55 lines) and gains one generator of the words and the two tables.
* `tools/encdis.c`: `row_of`, `shown`, `fmtc`, `marks_of` and their calls (about 60 lines): the disassembler prints the spelling of the word and no marks on operands.

**Moved:** the map is one grammar table. It spells the words with their suffixes: one row per spelling, written once, from which tools/mkgrammar.py writes the assembler's words and its map, the disassembler's table, pcc's rename table and the dictionary of the manual.

**The disassembler** (`tools/encdis.c`, `-a` round-trip mode): a one-column table from opcode word to canonical spelling (rule 3 of 4b); every operand printer loses its mark code. The round trip compares bytes, so the spelling it prints need not be the one the source used.

**LLVM** (`../llvm-pdp64`): `target/PDP64/gen/PDP64GenMnemonics.td` and `target/frozen-M1/PDP64/gen/PDP64InstrDefs.td` are generated by `tools/gen-llvm-td.py` (66 and 51 lines name a word; the generator's mark handling, about 15 lines, goes), `PDP64InstrInfo.td` 4 lines by hand, the checks and benchmark scripts 6 lines each, `README.md` 7. LLVM's assembler accepts dotted mnemonics (RISC-V's `fcvt.d.w` is one), so the strings are written as they are. About 120 definitions re-spelled, none re-numbered.

**pcc** (`../pcc/arch/pdp64`): its internal text uses the opcode words (`movb`, `fadd32`, `fcvtds`; `table.c` and `peep.h` match them as text: 59 lines in `peep.h`, 2 in `table.c`, 2 in `local2.c`, 4 in `code.c`), so none of those changes. The spell pass `pdp64_spell()` and its helpers `spell_line()`, `spell_isreg()` in `code.c` (about 130 lines that find the registers and put a mark on each) becomes a plain rename of the first word of each line through a generated table (about 25 lines), because the new spelling does not depend on the operands. `pdp64-marks.h` (38 lines, generated) becomes the word table; `pdp64-names.h` (85 lines) is regenerated; `test/pdp64test.sh` has 6 lines.

**QEMU:** only generated tables name the words, and they are generated from the encoding, not from the spelling: nothing by hand.

**The tests** (source files that contain a withdrawn word or a mark; counted by search):

| Directory | Files with a letter word, a `.u` word or a mark | And with the bare `movq` as well |
|---|---|---|
| `tests/sim` | 43 | 106 |
| `tests/asm-err` | 43 | 50 |
| `tests/asm` | 11 | 15 |
| `tests/qemu` | 9 | 38 |
| `tests/asm-equiv` | 8 | 18 |
| `tests/sec-open` | 2 | 5 |
| `tests/enc`, `tests/forms` | 1 and 1 | 1 and 1 |
| `tests/ld`, `tests/sec`, `tests/relax`, `tests/timing` | 0 | 2, 2, 2 and 1 |
| **Total** | **118** | **241** |

Of the 118, 36 `tests/asm-err` sources are about marks and their `.err` expected messages are rewritten (about 8 kinds of mark error disappear; about 12 new refusals each need a test: the principle of a test for every hole). The other 82 convert mechanically: the converter is the composition of the existing `marks.unspell()` (turns a mark form into the opcode word) and the new word-to-spelling table, so no operand parsing is rewritten. Verification before the swap: assemble each source with the old and the new assembler and require identical object bytes (the build already keeps such pairs in `asm-equiv`); then the suites (sim64, QEMU, LLVM, round trip) as before.

**The manual and the annex:** 12 of the 21 chapter files in `docs/manual` mention a withdrawn word or a mark (`09-isa.md` has 357 such lines; `07-smp.md`, `06-kernel.md`, `03-graphics.md`, `appendix-b-glossary.md`, `appendix-c-abi.md`, `appendix-d-assembler.md`), of which 4 are the generated dictionary pages (`dictionary/aliases.md`, `index.md`, `by-encoding.md`, `by-mnemonic.md`); 262 of the generated figures (`figures/w/*/NN.svg` and the intro figures) show a word and are regenerated by the 9 generator scripts under `tools/manual` that name one. So: **12 manual files to change (8 by hand), 262 generated figures, 9 generator scripts**. Outside the manual: `docs/asm-syntax.md` (the "Width letters and marks" section is rewritten), 54 other documents under `docs` (12 in `docs/annex`) and 28 design notes in `docs/encoding-work` and `docs/orig` that are history and I would not touch; `spec/pdp64/tables.md` and 13 files under `spec`; 35 files under `tools`. **In all, 118 test sources (241 with `movq`), 12 manual files, 262 figures, 9 generators, about 55 other documents, 35 tool files.** Every manual change needs `mkbook --check` and the result must not say "skipped".

**Order (build alongside, verify, then swap):** (1) the owner decides the points in section 7; (2) write the suffix table and the generator beside the old table, build a second assembler (`build/as64.new`); (3) run the converter on copies of the tests and compare object bytes against the old assembler; (4) the new refusal tests; (5) `encdis`, then pcc's table and LLVM's strings; (6) the manual and annex, regenerate the figures, `mkbook --check`; (7) swap: replace the assembler, delete the mark layer and the old table, and only then remove the old files. Nothing is deleted before the new assembler has assembled everything to the same bytes.

## 6. Risks and my recommendation

Risks, in order of weight:

1. **A suffix invites spellings that have no opcode** (`div.u32`, `aadd.s16`, `fcvt.s32.f64`, `add.u32`). They are refused, not guessed, so there is no silent miscompile, but a programmer will hit them, and the messages have to say what to write. The `fcvt` pair `s32`/`f64` is the one a C programmer will hit first (a 32-bit `int` to `double`); 3.5 gives the two-instruction path and I recommend the manual shows it.
2. **The sign-extended results** (the 4-byte atomics, `ror.s32`) against what `.u32` suggests (4b). The refusal closes it for `cas aadd ...`; `amax.u32` is the open edge.
3. **Two spellings per store and per 64-bit word** (`.s` and `.u` accepted) and one printed: a diff of a listing against a source can differ in a suffix that means nothing. I accept this for the benefit of one rule.
4. **The notation has changed four times in a day.** Errata 227 to 230 are each a reversal of the one before. The cost is not the code (the mark layer is a net deletion) but the tests, the manual and three other repositories moving in step. I recommend one atomic change after the owner has read this note, with the converter and the old-against-new byte comparison as the gate, so that nothing is half-spelled.
5. **The unknown-word message** (4f.4): worth doing in the same change.
6. **Vector words keep lane letters** (3.7): a visible inconsistency for as long as they do, and a reader will ask. The pattern fits them, and a later change is mechanical.

Recommendation: **do it, as one change, with these choices:** `.user` before the kind (4a); one rule for kinds that mean nothing, both letters accepted, the opcode word's spelling printed, `.s32` only where the register gets a sign-extended result (4b); `div mod mulh mul min max amax amin` take `.s64`/`.u64`, and conditions, shifts and bit-field words stay (4c); `fcvt.SRC.DST` in operand order with the 14 forms and no invented ones (4d); explicit 64-bit spellings accepted, `movq` an unknown word (4e). It makes the language smaller (the mark layer and its 8 kinds of error go), it keeps the PDP-11 habit that the word carries the width, and it answers the one ambiguity (`.32`) that the marks could not.

## 7. What needs the owner's decision

1. `.user` as the spelling of the user qualifier, before the kind (4a); and whether `mcpy.ur` and `mcpy.uw` are renamed to match (my answer: no).
2. Stores and kind-free words: accept both letters and print the spelling of the opcode word (my recommendation), or print `.u` for stores and kind-free words (4b).
3. `.u32` refused on the 4-byte atomics that return a value and on `ror` (my recommendation), or accepted as a synonym that promises a zero-extension the hardware does not do.
4. `amax.u32` and `amin.u32`: leave the sign-extended old value and say so in the manual (my recommendation now), or change the semantics so the old value is zero-extended (a separate decision).
5. The conditions (`cbhi cblo cbcc ...`) and `shr`/`sar` stay as words, not suffixes (4c).
6. `fcvt.s32.f64` and `fcvt.f64.s32` have no opcode: leave them refused and show the two-instruction path (my recommendation), or add them as assembler aliases for a short sequence (an alias exists for `abs`, `min`, `max`).
7. Decided by the owner, for the record: `movq` is unknown and bare words are aliases of their explicit 64-bit spelling (4e). Open: the disassembler prints the bare word (my recommendation) or the explicit `mov.s64`; and the compilers emit bare (my recommendation) or explicit.
8. Explicit `.f64` accepted on the double-only floating-point words (`fmin fmax fcopysign frint*`), and `.s64` and `.u64` on `mul`, `bswap` and `ror`: yes, as one rule (4e).
9. Whether the vector words should follow the pattern later (`vadd.f` to `vadd.f32`, `vld.b.l` to `vld.s8.s32`); I would decide it after this change has been used.
