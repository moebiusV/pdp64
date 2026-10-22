# Errata and decisions against ISA r20

[← pdp64 index](../README.md)

The ISA document (`docs/11-64W/11-64W-isa-r20.md`, written under the working name 11/64W; the machine is **pdp64**) is a paper design.
Writing it down as `spec/pdp64.json` found the following. Each item says what the document says, what the spec does, and why.
Items marked **DECISION** are choices the document left open; change them in the spec and everything downstream regenerates.

1. **Opcode bits in three diagrams are stale.** §4.6, §4.7 and §4.8 draw parcel 0 with opcode `000011` (BESC, MBLK) and `001110` (TAGOP).
   The §4.16 map says `0x0C`, `0x0D`, `0x15` (`001100`, `001101`, `010101`). The spec follows §4.16, which every other section agrees with.
2. **Opcode count.** §4.16 says "fifty-six of sixty-four assigned, eight reserved". The map it prints has 12 + 6 + 4 + 13 + 4 + 16 = **55**
   assigned, the spare ALU slot `0x23`, and eight reserved at `0x28`-`0x2F` (55 + 1 + 8 = 64). `specgen.py check` asserts the real numbers.
3. **DECISION: PC-relative base.** The document says displacements are "relative to a stated point" and never states it. Spec: **the address of the
   first parcel of the instruction**, for `d(PC)` operands, `LEA`, and branches. Branch displacements count 2-byte parcels (the §4.4 reach table needs
   that). Reason: the displacement then does not depend on the length chosen for the instruction itself, so branch relaxation is monotone and
   needs no feedback loop. `LEA 0(PC),Rn` yields the address of the `LEA`.
4. **DECISION: `PUSHM`/`POPM`.** §4.7 puts them in `MBLK` with "parcel 1 is a 16-bit mask", but an `MBLK` parcel 1 carries an 8-bit sub-opcode, so the
   mask has no room at `len=01` (and §4.14 forbids deciding the parcel-0 interpretation per sub-opcode). Spec: they take the two free `SOP` slots,
   `PUSHM #mask` (slot `A`) and `POPM #mask` (slot `B`), with the mask as a 16-bit immediate (mode `0100`): four bytes, using only mechanisms that exist.
   Cost: `SOP` has no free slots left. Mask bit *n* is `Rn`; `PUSHM` stores the lowest register at the highest address.
5. **DECISION: `SYS` sub-opcode.** §4.11 says `reg` and `rm` combine into eight bits of sub-opcode, §4.3.1 says `SYS` takes its sub-opcode from the
   `reg` field, and `TRAP #n` is to be two bytes with 256 vectors, which all three cannot be. Spec: `reg` is a 4-bit **class**; `rm` is a register
   operand, a 4-bit immediate (`SPL`, `TRAP` 0-15) or, in class 0, the minor opcode of the no-operand instructions. `TRAPL #n` (class 15, `len>=1`,
   n in parcel 1) reaches vectors 0-255. `PROBER`/`PROBEW Rd,Rs` use parcel 1 for the second register.
6. **DECISION: `JTAG`.** `JTAG Rn, table` has no field for `Rn` (`reg` is the sub-opcode, `rm`/mode give the table). Spec: `JTAG` is legal only
   with mode `0001`: `JTAG d(Rb)(Rx*s)` with the scale ignored, `PC <- [Rb + d + 8*(Rx & 7)]`. `Rx` is the tagged register.
7. **DECISION: mode `0001` (scaled index) at `len>=2`.** The document gives only `len=01` (`rm4 Rx4 s2 d6`, §12 item 1 calls the 6-bit
   displacement thin). Spec: each extra parcel adds 16 displacement bits: 6 / 22 / 38. Mode `0011` (`d(DP)`) keeps the 4 bits of parcel 1 as
   padding at `len=01` (12-bit displacement as stated) and uses the same widths as base mode.
8. **DECISION: `SOB`.** `Rn` takes the `reg` field, which is the displacement byte at `len=00`, so `SOB` exists from `len=01` (consistent with
   §3.1.1, which lists it with the two-parcel forms). Displacement 16/32/48 bits, in parcels.
9. **DECISION: sub-opcode numbers.** The document names sub-opcodes and never numbers them. The numbers in the spec group related operations
   (`BESC`: counts 0x00-0x08, rotate 0x10, field 0x20, polynomial 0x30, UTF-8 0x40; `FESC` by width and kind; `ATOM` plain/`_DB` pairs).
10. **DECISION: `BESC` rotate by immediate.** `RORI Rd,Rs,#n` is a four-byte form with the count in the low six bits of parcel 1; `ROL Rd,Rs,#n`
    assembles to `RORI` with `64-n` (§4.15). `DSHR`, `EXTB`, `EXTZB`, `INSB` need the third parcel (position, width) and exist at `len>=2` only.
11. **DECISION: `MESC` parcel 1.** `sub4 rm4 disp8` at `len=01` (§4.13); displacement widens 8 / 24 / 40. Only modes whose payload fits that
    way are legal (`base`, `dp`, `postinc`, `predec`, `pcrel`, `abs`); the scaled-index mode is not available in `MESC`.
12. **The machine's name** is pdp64. The documents say 11/64W; they are kept unmodified under `docs/`.
13. **DECISION: `CMP` operand order.** PDP-11 `CMP a,b` computes `a-b`; here the destination must be a register, so a literal `src,dst` meaning
    would force every compare of a register against an immediate or a memory operand to reverse its branch condition. Spec: the encoding computes
    **`reg - rm`**, and the assembler writes it `CMP Rd, rm` (register first). `CMP a,b` followed by `BLT` still reads "branch if a < b", as on the
    PDP-11; only which side must be a register differs. `BIT` is symmetric.
14. **DECISION: flags.** Subtraction and `CMP` set `C` on a borrow (PDP-11 sense, so `BHIS`/`BCC` mean "no borrow", unsigned `>=`). `ADD` sets `C` on a
    carry out. `V` is signed overflow. `FCMPD` sets `N` if a<b, `Z` if a==b, `V` if unordered, `C` cleared (open item 7 in the ISA: the branch
    conditions do not yet separate "unordered" cleanly).
15. **DECISION: pre-decrement syntax.** §5 writes mode `0111` as `-d(Rn)`, which is also how a negative base displacement is written. Spec:
    `-(Rn)` pre-decrements by the operand size, `(Rn)-d` by an explicit stride (the mirror of `(Rn)+d`); `-d(Rn)` is always base+displacement.
16. **DECISION: `FRECPED` and `FRSQRTED` dropped.** ISA 4.10 lists reciprocal and reciprocal-square-root estimates "for Newton-Raphson". The machine has
    `FDIVD`, `FSQRTD` and the fused multiply-add family, so a software Newton loop buys speed only if the hardware divide is slow, which this
    design does not chase; each estimate needs a table in hardware and an exact specification (ARM and RISC-V pin down the algorithm and table, the ISA
    says only "not correctly rounded", so two implementations would return different bits; *fact-check 2026-10-22: in RISC-V the pinned-down estimate exists only in the vector extension, `vfrec7`/`vfrsqrt7`, see `target/riscv/tcg/vector_helper.c` in QEMU, not in the scalar F/D extensions*); and no document names a user (ISA 1.2 rule 3). Sub-opcodes
    `0x40` and `0x41` of `FESC` are free again. The ISA text in `docs/11-64W/` is left as written.
17. **DECISION (added at the user's request): floating-point exception flags.** The ISA never mentions them (a search for flags, `fenv`, "inexact", "sticky" finds
    nothing), and IEEE 754 requires five status flags (invalid operation, division by zero, overflow, underflow, inexact) and C99 `<fenv.h>` needs software
    access to them. Added: a sticky **FPSR**, five bits laid out as RISC-V's `fflags` (bit 0 NX inexact, 1 UF underflow, 2 OF overflow, 3 DZ divide by zero,
    4 NV invalid). Every floating-point operation that can raise one ORs it into FPSR and **never traps**. One operation reads and writes it,
    `FSFLAGS rs, rd` (`FESC` sub-opcode `0x40`): `rd <- FPSR; FPSR <- rs & 31`, so clear is a swap with zero, test-and-clear a swap with zero, set a swap
    with the bits. FPSR is part of the thread context (saved with the PSW). It is not a mode: it never changes what an instruction does, only records
    what it did (ISA 1.1 "no mode bits" is untouched). Quiet-NaN comparisons raise NV only for signaling NaNs (`FCMP*`, `FMIND`, `FMAXD`). Tininess is detected after
    rounding. **Still open, found while doing this: IEEE 754 also requires directed rounding (toward +inf, -inf, zero) for the arithmetic operations, and §9.8 puts
    the mode "in the opcode wherever it is not round-to-nearest-even" but the opcode list has no such variants except `FRINT*`. See CHANGES-SINCE-R20.md section 12.**
18. **Unsigned 64-bit conversions (added).** `FCVTDQU` (double to unsigned quad, truncating; out of range or NaN raises NV and saturates to 0 or 2^64-1) and `FCVTQUD`
    (unsigned quad to double, rounding to nearest even). C needs both; without them each is a compare, a branch and several instructions.
19. **Round half away from zero (added).** `FRINTDA` joins `FRINTD` (nearest even), `FRINTDZ`, `FRINTDM`, `FRINTDP`, for C's `round()`. A qualifier of the round
    operation, so no new operation.
20. **CRC instructions: considered, added, then withdrawn (the user's decision).** The user first asked for `CRC32` and `CRC32C` instructions (four widths each) in
    addition to carry-less multiply, then withdrew them: "we have carryless mul, no need for either crc". The ISA's own choice in 4.6.3 therefore stands:
    `CLMULL`/`CLMULH` are the primitive beneath every CRC polynomial (a CRC is a carry-less multiply plus a Barrett reduction), GF(2^k) erasure codes and
    GCM, with no polynomial committed to the architecture. `BESC` sub-opcodes `0x34`-`0x3B` are free.
21. **`FCMPD`/`FCMPS` are register-first like `CMP`.** The ISA does not say which operand is the register for the floating-point compares. They follow errata 13:
    `FCMPD rd, rm` computes `rd - rm`. (The assembler had treated `FCMPD` like the other ALU operations until now.)
22. **`FESC` operand roles.** `reg` = destination, `low` = first source, `t` = second source, `x` = third source (the fused multiply-add family has four registers;
    ISA 4.10). `fmadd rs, rt, ru, rd` = `rs*rt + ru`; `fmsub` = `rs*rt - ru`; `fnmadd` = `-(rs*rt) - ru`; `fnmsub` = `-(rs*rt) + ru`, each rounded once.
    `fdivd rs, rd` is `rd <- rd / rs` and the `s` forms likewise; `fcopysign rs, rt, rd` takes the magnitude of `rs` and the sign of `rt`.
23. **Integer `ABS`, `MIN`, `MAX`, `MINU`, `MAXU` (added at the user's request).** `AESC` sub-opcodes `0x08` (`abs rs, rd`) and `0x10`-`0x13` (`min`, `minu`, `max`, `maxu`
    `ra, rb, rd`; the `u` forms compare unsigned). They are the integer counterparts of `FABS`, `FMIND` and `FMAXD`, so by the folding rule (integer vs float and signed vs
    unsigned are qualifiers) they add no operation. Flags: `abs` sets N and Z from the result and V when the operand is the most negative number (whose absolute value is
    itself, the result wrapping), C unchanged; `min` and `max` set N and Z from the result, clear V, leave C. Hardware: reuse the negate path and the compare of
    `SUB`/`CMP` with a 64-bit select (est. 150-250 LUTs). Teaching the compiler the idioms (`x<0?-x:x`, `a<b?a:b`) is a shared front-end change that helps every target.
24. **DECISION: floating-point spelling and the alias rule (the user's).** Floating-point operations are the integer operation with an `f` in front (`fadd`, `fsub`,
    `fmul`, `fdiv`, `fsqrt`, `fmadd`, `fabs`, `fmin`, `fmax`, `fcmp`, `fclass`, `frint`...), and a width other than the default is a **decimal suffix in bits**:
    `fadd` is binary64 (the machine's native float), `fadd32` binary32, `fadd16` binary16 when half-precision arrives. The rounding variants are one letter:
    `frint` (nearest even), `frintz`, `frintm`, `frintp`, `frinta`. The old spellings (`faddd`, `fadds`, `fmind`, `frintdz`...) stay as aliases. **Aliases are now
    one rule**: a word numbered 0x100 above another word of its group stands for that word (one mnemonic, one instruction, ISA 4.15); `rol` also complements its
    count. The same pass moved `bhis`, `blo`, `mulu` and `wait` to the rule. Conversions (`fcvtdq`...) and the integer widths (`movq`, `movl`, `movw`, `movb`) keep
    their spellings until the user chooses how to write a width on an integer operation.
25. **`SET cc, rd` (added; the first instruction written with a condition word).** `set eq, r1` writes 1 to `r1` if the condition holds and 0 if not. One `AESC`
    sub-opcode (`0x20`); the condition is the `x` field of parcel 1, numbered like the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, `pl` 3, `mi` 4,
    `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14; the drift test checks that numbering against the branches). Flags
    are not changed. The condition words are reserved only in that position: a label may still be called `eq` or `lt`.
26. **NaN results are canonical (decided in `sim64`).** The ISA is silent on the bits of a NaN that an operation creates. Every arithmetic or conversion
    result that is a NaN is the canonical quiet NaN (`0x7FF8000000000000`, binary32 `0x7FC00000`), whatever the operands carried: no payload propagation
    (the RISC-V rule). `FNEG`, `FABS` and `FCOPYSIGN` work on the bits and do not canonicalize. Without the rule the result would depend on the host that ran
    the emulator (x86 makes a negative NaN for 0/0). Hardware must do the same for results to match `sim64`.
28. **DECISION (the user's): integer arithmetic stays 64-bit; there are no sized ALU operations.** The question was whether a descendant of the PDP-11 should
    have native 16-bit (and 32-bit, 8-bit) integer arithmetic. The answer is no: registers are always written in full (ISA 4.2: narrow loads sign- or zero-extend),
    `movb movw movl` sign-extend and `movzb movzw movzl` zero-extend, from a register, memory or an immediate, and every arithmetic and compare instruction works on
    all 64 bits. A narrow value is held extended, and the compiler extends again where a result can leave the range (a C `int` is kept sign-extended).
    *Measured cost of this choice* (pdp64 pcc, 841-file fair corpus, 405,744 instructions): a re-extension `movl r,r` after an operation that can leave the range,
    17,580 (4.3% of instructions; 49% follow `lea` used as an add, 16% `add`, 14% `shl`, 8% `mul`); a narrow load immediately consumed by an ALU or compare
    instruction, 8,451 pairs (2.1%), of which only 146 have a register as the other operand and a dead loaded value, that is, would fuse into a sized memory
    operand (the large group, 4,356 `movzb`+`cmp reg,#imm`, cannot fuse under the one-memory-operand rule either). *Why not:* a width needs bits the encoding does not
    have (the opcode space has 8 reserved slots and every ALU slot but one is assigned; the mode and register fields are full); a prefix costs two bytes per use and
    makes decode restartable in two parts; and the gain is bounded by the numbers above. Signed `int` overflow is undefined in C, so the re-extensions after signed
    operations are the compiler's conservative default and can be dropped (`-mnowrap`: 388,919 instructions, 0.99 times amd64); unsigned 32-bit wrap needs the
    extension. Tests: `tests/sim/extend.s` (every width, source and boundary, partial stores, flags) and `tests/c/extend.c` (the same in C; it returns 1 under host gcc too).
29. **DECISION (the author's): devices are eight memory-mapped registers plus DMA.** Ethernet, USB and disk devices are each eight memory-mapped registers (eight
    addresses in the ordinary address space) and move their data by DMA. *Why:* a driver for so small and regular an interface is trivial to write, which removes driver
    code, and the device carries its own data so the processor only sets up a transfer and has no multitasking burden from it: more of the processor is left for the
    user and the programs that matter (the third layer of the optimization described in the README: gate count, code count, the system around the processor).
    *Where it sits:* ISA section 16 already makes every device a bus device that does not touch the ISA, and already owes devices what DMA needs from the processor
    side (a memory type per page, `FENCE` before a doorbell write, atomics for shared queues); this adds a convention for the device side and changes no instruction.
    *Open:* the register layouts, the DMA descriptor format, the interrupt and doorbell conventions, and whether other devices follow the same shape; none are written yet.
30. **DECISION (the author's plan): the first operating system is a port of Unix/32V; an OpenBSD port follows if an LLVM back end is easy enough.** *Why 32V:* it is V7 already
    ported to a 32-bit paged machine (the VAX-11/780) with the portable C compiler, so it is closer to the pdp64 than V7 on the PDP-11. (The author's belief was that 32V already demand-pages; the headers show
    that it swaps whole processes and uses the VAX page tables for relocation, and that demand paging came with 3BSD. The pdp64's MMU supports demand paging, so it can be added afterwards.) *Why it matters
    for the design:* the first system sets a short list of what the system architecture must define first: the exception entry sequence, a way to write `PTBR`, interrupt priorities, a clock, a console and a disk
    ([`pdp64-system-architecture.md`](pdp64-system-architecture.md) sections 12 to 14). *Open:* the kernel sources are not in the repositories; the LP64 and a.out-versus-ELF decisions; the LLVM estimate; everything
    in the system architecture document's open list.
    *Fact-check 2026-10-22:* the 32V claim is confirmed by Wikipedia (*UNIX/32V*: "released without virtual memory paging, retaining only the swapping architecture of Seventh Edition"; paging added at Berkeley by Bill Joy and Ozalp Babaoglu, released as 3BSD in 1979). The 2002 Caldera licence covers early Unix up to and including 32V (Wikipedia, *Ancient UNIX*); it is not shown to cover 3BSD. See `fact-check-2026-10-22.md`.
31. **DECISION (the author's): the fourth parcel is removed, and `len = 11` becomes a second page of one-parcel instructions; two further instructions are added.** The full map is in
    [`CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md) section 12 ("Decided design: the second page"). In short: instructions are 1, 2 or 3 parcels (2, 4 or 6 bytes); `len = 11` is one parcel in the layout
    `11 opc:6 reg:4 low:4` with its own 64-entry opcode map, holding register-deferred loads and stores, `lea` and quad/long loads and stores at small offsets from `sp`, quad and long loads and stores at small
    offsets from a register, frame adjustment and register-save instructions, and four-bit-immediate forms of the common operations. A fused compare-and-branch (`cbCC`, in the reserved top-level
    opcode `0x28`) and a 32-bit rotate by a constant (`rori32`, a `BESC` sub-opcode) are added. *Why:* only 49 of 373,635 compiled instructions (0.013%) needed the fourth parcel; the one-parcel
    forms are estimated at about 118 KB (7%) and the two instructions at 22 KB (1.3%) of a 1.67 MB image (static counts on the 827-file corpus; section 12). *Rule kept:* every page-2 form is exactly the operation of
    its long form (the same flags, the same result), so an assembler that chooses the shortest encoding never changes what a program does. *Costs:* the immediate, absolute, PC-relative and branch fields shrink from 48
    to 32 bits and the base-register displacement from 44 to 28 bits. *Alternatives considered:* keep four parcels; reserve `len = 11`; the register-deferred form of every memory-operand opcode (rejected in favour of the explicit map).
32. **Added: system-register moves `MFSR` and `MTSR` (the missing instructions of a paging operating system).** The ISA names the registers `PTBR`, `EPC`, `EVA` and `ECAUSE` (§2.2) but had no
    instruction to write the first or read the others, and no `MFDMW`; a kernel could not install a page table or learn why it was entered. Two instructions, **`mfsr rd,name`** and **`mtsr name,rs`**, in the
    `SYS` group as class-0 minors **13** and **14** (the last free minors were 13 to 15), four bytes: parcel 0 `01 SYS 0 minor`, parcel 1 `sr:8 r:4 pad:4` (`sr` the system-register number, `r` the general register, `pad` zero). The
    registers they reach, by name (an enumeration in `spec/pdp64-mnemonics.hbnf`, like the condition words of `set`): **`ptbr` 0** (read/write), **`epc` 1** (read/write), **`eva` 2** (read only), **`ecause` 3** (read
    only), **`dmw0` 4** and **`dmw1` 5** (read/write), **`usp` 6** and **`ssp` 7** (the user and supervisor stack pointers, read/write; added because any kernel must read and write the user stack pointer to build a
    signal frame, copy a process or switch context, and `R14` only names the current mode's copy). Writing a read-only register, or an unassigned number, is an illegal-instruction abort. Both instructions are **privileged**: executed outside kernel mode
    they abort with the privileged-instruction cause (§7.1). *Why one general pair and not more `MTxx`/`MFxx` words:* all sixteen `SYS` classes are in use; a general move costs two minors and leaves 8-bit register numbers
    for future registers (a vector base, a timer compare, an interrupt mask) without touching the `SYS` layout again. *Open, unchanged:* what `epc`, `eva` and `ecause` contain (the exception entry sequence is not yet designed; the system
    architecture document §4), the semantics of `ptbr` beyond "the base of the current page table", and which of `MTDMW`'s two windows an operand selects (`dmw0` and `dmw1` through `mtsr` are the unambiguous way; `MTDMW` is kept).
    The emulator models only a kernel/user flag for these instructions (`sim64 -k` runs in kernel mode), not the full privileged state.
33. **DECISION (the author's): wide constants are loaded from a literal pool, written with an explicit `=`; nothing is pooled silently.** An immediate wider than the signed 32-bit field (the fourth parcel is gone, errata 31)
    cannot be an operand. Two ways to supply it were considered: the compiler builds its own pool, or the assembler offers sugar. The author chose sugar, **provided it is obviously sugar**: `movq =K, rd` (ARM's `ldr =value`)
    assembles to one PC-relative load of a pooled 8-byte literal, in `.text`, flushed at the end of the section or at `.pool`; a bare too-wide `#K` is an error that points to `=K`. The first implementation of errata 31 pooled
    silently, which contradicted "one mnemonic assembles to one instruction" (ISA §4.14); the explicit `=` keeps the instruction single and the sugar visible. Allowed on the quad memory-source forms (`movq`, `push`, the ALU group,
    the floating-point ALU ops); refused for sized moves, shifts, stores, `lea` and relocatable symbols. The compiler emits `=K` for constants that do not fit.
34. **DECISION (the author's): `rori32` sign-extends, and `cbCC` gets a wide-immediate form.** (1) **`rori32 rs,#n,rd`** now gives `rd <- sign-extend( ror32( rs[31:0], n mod 32 ) )`, like `movl` and every other
    32-bit result: errata 31 had made it zero-extend, which forced the compiler (that keeps unsigned 32-bit values sign-extended, errata 28) to add a `movl` after each rotate that is not followed by code reading only the low 32 bits.
    (2) **A wide-immediate `cbCC`**: the same mnemonics, a new encoding in the reserved top-level opcode **`0x29`**, six bytes only (`len = 10`): parcel 0 `10 0x29 rd cond`, parcel 1 `imm:16` (signed, -32768 to 32767),
    parcel 2 `disp:16` (signed, in parcels from the first parcel of the instruction, +-32,768 parcels = +-64 KB). It compares `rd` with the sign-extended immediate exactly as `cmp rd,#imm` does and branches on the condition. The
    assembler chooses, for one `cbCC`, the shortest of three encodings: the four-byte form (`imm5`, `disp11`, opcode `0x28`), the six-byte wide form (`imm16`, `disp16`, opcode `0x29`), and the six-byte long form (`imm5`, `disp27`, opcode `0x28`
    at `len = 10`): the long form has the longest reach, the wide form the widest immediate. An immediate outside 16 bits, or a wide immediate whose target is beyond 64 KB, is an error ("use cmp and bCC"); the compiler therefore emits the
    wide form only for functions whose size is bounded below 64 KB. *Why:* 11,821 `cmp reg,imm` (immediates such as 255 and 47) were left unfused after the first `cbCC` (CHANGES §12). *What it will and will not do, stated before
    building:* a `cmp reg,imm16` (4 bytes) and its branch (2 bytes) are 6 bytes, as is the wide `cbCC`, so **it saves an instruction, not bytes** (about 11,800 instructions, 3.4%), except where the branch was four bytes. *Cost:* one of the seven
    reserved top-level opcodes (six remain: `0x2A` to `0x2F`).
35. **DECISION (the author's): a register-register compare-and-branch.** `cbCC ra,rb,label` (the same mnemonics as the immediate forms; the operand kind chooses the encoding, as for `add rs,rd` and `add #imm,rd`) compares
    `ra - rb` exactly as `cmp ra,rb` does (the same flags are written) and branches if the condition holds. New top-level opcode **`0x2A`** (five reserved remain: `0x2B` to `0x2F`). Format: parcel 0 `len 0x2A ra rb` (`reg` = `ra`, `low` = `rb`);
    at `len = 01` (4 bytes) parcel 1 is `cond:4 disp:12` (signed, in parcels from the first parcel of the instruction: +-2,048 parcels, +-4 KB); at `len = 10` (6 bytes) parcel 1 is `cond:4 disp-high:12` and parcel 2 `disp-low:16`, a 28-bit
    displacement (+-128 M parcels), so a compiler needs no function-size limit. The condition numbers are those of `bCC`, `set` and the other `cbCC` forms. The assembler chooses the shorter length that reaches; a target in another section is refused, as
    for the immediate forms. *Why:* the compiled corpus has 4,714 `cmp reg,reg ; bCC` pairs (1.4% of instructions) left after the immediate forms (CHANGES section 12). *What it will do, stated before building:* the pair is `cmp` (2 bytes) plus `bCC`
    (2 bytes, or 4 when far), the fused form is 4 bytes (6 when the target is farther than 4 KB), so it saves **one instruction per pair, and bytes only where the branch was four bytes** (at most about 9 KB, probably a few KB). The `cmp reg,mem ; bCC` pairs cannot use it (the memory operand has no room); the count of 5,356 first written here was wrong, the real count is 611.
36. **ACCEPTED 2026-10-22 (the author chose: register-based exception entry with `EPC` and `EPSW`; software-managed accessed and dirty bits; the whole of System v1 in the first QEMU cut): System v1, the design the QEMU memory-management unit and privileged mode, and a first kernel, are built against.** Written in
    [`pdp64-system-architecture.md`](pdp64-system-architecture.md) section 15: the PSW layout (flags `C V Z N` in bits 0 to 3, `T`, a 3-bit priority, current and previous mode with the PDP-11 encoding), the exception entry sequence (registers only: `EPC`, a new `EPSW`,
    `EVA`, `ECAUSE`; the new PC from the table at `VBR + 8*vector`; `RTI` returns), the vector numbering (`ECAUSE` = vector; traps at 256 + n), the page-table entry (flags in the low bits, the physical page number in place at bits 12 to 39), permissions, software-managed accessed and dirty bits,
    an `MMUCTL` enable bit, `TLBI` by address, three new system registers for `mfsr`/`mtsr` (`epsw` 8, `vbr` 9, `mmuctl` 10, plus `asid` 11 and `cpuid` 12), the list of privileged instructions, eight interrupt levels, a timer and a console device in the virt machine. *Status:* accepted as the design to implement; the author may still change any part of it after seeing it work. *Not in v1:* the direct mapping windows `DMW0` and `DMW1` have no defined register format yet, so in v1 they are stored by `mfsr`/`mtsr` and have no
    translation effect (kernels use ordinary page tables, for instance 1 GB leaf pages); the supervisor mode exists in the PSW and the banked registers but nothing uses it.

30a. **REVISED 2026-10-22 (the author): the first operating system is a port of 3BSD, not Unix/32V.** The reason: the 32V headers show that it swaps whole processes, and 3BSD (Unix/32V plus Berkeley's demand-paged virtual memory) already pages, so the port starts from the system that has the paging. The
    plan otherwise stands (errata 30, [`pdp64-system-architecture.md`](pdp64-system-architecture.md) section 12). *Unverified, to check when the sources are fetched:* that 3BSD was built with the portable C compiler, that its sources are available to the project and under what licence, and the details of its software emulation of reference bits.
37. **DECISION (the author's): `pushx` and `popx`, saving and restoring the exception state in one instruction each.** A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority (System v1,
    errata 36); with only `mfsr` that costs two moves and two stores (four instructions, sixteen bytes) on every such kernel entry, and the same to restore. **`pushx`**: `SP <- SP - 16; M[SP] <- EPSW (zero-extended); M[SP + 8] <- EPC`, using the stack pointer of the
    current mode (in a kernel handler, the kernel stack). **`popx`**: `EPSW <- M[SP] (low 16 bits); EPC <- M[SP + 8]; SP <- SP + 16`. Both are privileged (vector 3 outside kernel mode) and write no flags. *Restart:* an abort leaves no architectural effect: the instruction checks both words
    (writable for `pushx`, readable for `popx`) before it stores or loads either, because a 16-byte aligned-to-8 push can straddle a page boundary, and updates `SP` only after both accesses; a misaligned `SP` is the misaligned-access abort. *Encoding:* the long form is a new escape in the `SYS` group, class 0 minor **15** (the last free minor),
    called **`SYSX`**, four bytes: parcel 1 is `sub:8 pad:8`, `sub` 0 = `pushx`, 1 = `popx`, any other `sub` or a non-zero `pad` is an illegal instruction; the two-byte forms are **page-2 opcodes `0x2A` (`pushx`) and `0x2B` (`popx`)**, exact abbreviations of the long forms with `reg` and `low` zero (a non-zero field is an illegal
    instruction), so the assembler writes two bytes. `SYSX` also gives the `SYS` group room for further system instructions without taking another class. Page 2 now has 43 of its 64 opcodes defined and 21 reserved. *Why:* about 12 bytes and 3 instructions saved on every nested kernel entry and exit (the cost identified in
    [`pdp64-system-design.md`](pdp64-system-design.md) D1); entry stays register-only, so it still cannot fault.
38. **DECISION (the author's): the FPGA and ASIC implementations are in-order; the architecture is to be kept ready for a large-scale out-of-order design.** The first implementations are the small in-order, non-speculative cores of the implementation plan. The ISA must not
    contain anything that would make a later wide out-of-order implementation (rename, reorder buffer, speculation, a sequentially consistent memory system with replay) impossible or needlessly slow, and decisions that cost an in-order core nothing but would cost an out-of-order core a great deal are to be made now. The
    readiness review is in [`pdp64-ooo-readiness.md`](pdp64-ooo-readiness.md); the design point, costs and gains are in [`pdp64-in-order-and-out-of-order.md`](pdp64-in-order-and-out-of-order.md). Concrete first candidate: the partial flag updates (a shift or rotate by a register count of zero leaves every flag
    unchanged, ISA 4.2.1; `inc`, `dec`, logic operations and moves leave `C` unchanged).
39. **DECISION (the author's): flag cleanup for out-of-order readiness, `ISYNC` and `HINT`.** From the readiness review ([`pdp64-ooo-readiness.md`](pdp64-ooo-readiness.md); the author adopted four of its five proposals on 2026-10-22). *The invariant:* the flags are **two groups, `C` and `{N, Z, V}`**;
    no instruction writes part of `{N, Z, V}` or writes it conditionally. *Changes:* (1) **`cbCC` (all three forms and the register form) writes no flags**: it computes `rd - operand` for its own decision and leaves `N Z V C` as they were. (2) **Moves, loads and stores write no flags**: `movq movl movw movb`, `movzl movzw movzb`, and the store forms (and their page-2
    abbreviations); `lea`, `set` already write none. (3) **`shl`, `shr`, `sar` write the same flags for every count**, including a count of zero (which gives `N` and `Z` from the unchanged operand, `V` = 0, `C` = 0), so there is no data-dependent flag write; this replaces "a count of zero changes no flag" (ISA 4.2.1). (4) **`mscn` and `mscnn` write all four flags**: `Z` as now (set when the byte was found), `N`, `V`
    and `C` cleared. (5) **`ISYNC`**: an instruction that makes earlier writes to `PTBR`, `ASID`, `MMUCTL`, `VBR` and earlier `ICINV`s take effect for the instructions that follow it; the architecture now promises the effect only after the next `ISYNC` (an in-order implementation may make it immediate; software must not rely on that);
    long form `SYSX` sub-opcode 2 (four bytes), page-2 abbreviation **`0x2C`** (two bytes). (6) **`HINT #n`** (`n` 0 to 255, no architectural effect): `SYSX` sub-opcode 3 with `n` in the `pad` byte (four bytes), page-2 abbreviation **`0x2D`** with `n` = `reg:low`; defined codes `0` plain no-op hint, `1` pause (spin-wait), `2` speculation barrier; every other code is a reserved
    hint that executes as a no-op (forward compatible; software shall not use it). (7) The **architecture-text items** of the review (section 2 of `pdp64-ooo-readiness.md`): rules for `LL`/`SC`/`ATOM` (reservation, forward progress, operands, what `_DB` adds under sequential consistency), no speculative loads from device pages and no side-effecting instruction fetch from them, `mcpy`/`mmov`/`mset`
    internal accesses unordered with respect to each other, `pushm` with `r14` in the mask and auto-modify with data register equal to base reserved, page-table entry changes visible only after `TLBI`; to be written into the ISA text. *Decided afterwards (the author, 2026-10-22):* **rotates (`ror rori rori32`) and `dshr` write no flags; `asl` keeps the PDP-11 rule `V = N xor C`** (all four flags written, every time). The core already does this; the ISA text (4.2.1) is corrected to match. *Costs, stated before building:* moves, loads and stores no longer set the flags that the compiler's `tst`-elision relied on: at most about 0.77% in code size (2 to 4 bytes at roughly 2,900 sites; no extra instructions); `cbCC` no longer provides flags to a following branch, so the compiler can fuse only where the flags are dead afterwards; tests that read flags after moves, `cbCC` and shifts by zero need rewriting.
40. **DECISION (the author's): exception and interrupt entry sets the priority to 7.** Found by the System v1 implementation review (2026-10-22): section 15 kept the old priority on exception entry, so a trap or fault from user mode at priority 0 could be interrupted by the timer before the handler's first `spl #7`, and the interrupt's entry would overwrite `EPC` and `EPSW`. A window of one instruction. *Alternative considered and
    rejected:* defer interrupts for one instruction after entry (an interrupt shadow): it needs hidden state, depends on the handler's first instruction being `spl #7`, and complicates a pipeline that tracks instructions out of order. *Decision:* the new `PSW` priority is **7 on every entry**, exceptions and interrupts alike (the review found the same hole for an interrupt: a higher-level interrupt could preempt a
    lower-level handler before it saved `EPC` and `EPSW`; the author's decision named exceptions, and I extended it to interrupts for that reason; narrowing it back is a one-line change). The handler lowers the priority with `SPL` when it is ready; the previous priority is in `EPSW` and `RTI` restores it. Cost: one `SPL` in a handler that wants to be interruptible, and one less in a handler that began with `spl #7` (all of them). *Not covered:* an exception in the handler's own first instructions; the entry code and the kernel stack must be pinned (section 15). *Throwback:* the PDP-11 loaded the new `PSW` from the vector, with priority 7 conventional for traps (from memory, unverified). Core, QEMU and the `sys-*` tests change accordingly.
