# Errata and decisions against ISA r20

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
    says only "not correctly rounded", so two implementations would return different bits); and no document names a user (ISA 1.2 rule 3). Sub-opcodes
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
