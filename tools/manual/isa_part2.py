"""Dictionary entries, part 2: bits and fields, block memory, arithmetic escape, floating point."""
from isa_common import *

REGX = 'A reserved encoding aborts with the illegal-instruction vector.'
FXNOTE = 'Operand roles: `reg` is the destination `Rd`, `low` the first source `Rs`, `t` the second `Rt` and `x` the third `Ru`; the assembler writes the destination last.'
FPFLAG = 'The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.'
SATQ = 'A NaN or an out-of-range value raises `NV` and saturates.'

ENTRIES = [
    # ---- BESC ----
    E('COUNT', 'bits', ['clz', 'ctz', 'clo', 'cto'], 'Count leading and trailing zeros and ones',
      ['CLZ Rs, Rd', 'CTZ Rs, Rd', 'CLO Rs, Rd', 'CTO Rs, Rd'],
      '''CLZ: Rd <- number of leading zero bits of Rs        (64 if Rs = 0)
CTZ: Rd <- number of trailing zero bits of Rs       (64 if Rs = 0)
CLO: Rd <- number of leading one bits of Rs         (64 if Rs = all ones)
CTO: Rd <- number of trailing one bits of Rs        (64 if Rs = all ones)''', NOFLAGS, NONE,
      notes='`CTZ` is the VAX `FFS`. Bit manipulation is core on a machine that does filesystem and bignum work, not an extension.', xnote='Register to register only; four bytes.'),
    E('POPCNT', 'bits', ['popcnt'], 'Population count', ['POPCNT Rs, Rd'], 'Rd <- number of one bits in Rs', NOFLAGS, NONE),
    E('BSWAP', 'bits', ['bswap', 'bswapw', 'bswapl'], 'Byte swap',
      ['BSWAP Rs, Rd', 'BSWAPW Rs, Rd', 'BSWAPL Rs, Rd'],
      '''BSWAP : Rd <- Rs with all 8 bytes reversed
BSWAPW: Rd <- Rs with the bytes of each 16-bit word reversed
BSWAPL: Rd <- Rs with the bytes of each 32-bit long reversed''', NOFLAGS, NONE, notes='The generalisation of the PDP-11 `SWAB` to 64 bits.'),
    E('BITREV', 'bits', ['bitrev'], 'Reverse the bits', ['BITREV Rs, Rd'], 'Rd <- Rs with bit i moved to bit 63-i', NOFLAGS, NONE),
    E('ROR', 'bits', ['ror', 'rol'], 'Rotate right by a register or a constant', ['ROR Ra, Rb, Rd', 'ROR Rs, #n, Rd', 'ROR #n, Rd', 'ROL Rs, #n, Rd', 'ROL #n, Rd'], 'Rd <- Ra rotated right by (Rb mod 64), or by (n mod 64) with a constant; ROL rotates left by the constant (an assembler mapping)', 'None written (rotates write no flags).', NONE,
      notes='One word names the operation, as `SHL`, `SHR` and `SAR` do: the assembler takes a register or a constant for the count and picks the form: two bytes for `ROR #n, Rd` (the register is both source and destination and is one of r0 to r15, and the count is from -8 to 7, a signed count of four bits, so a negative count rotates left), four bytes for any other. `ROL` is an assembler mapping, not an instruction: a rotate left by n is a rotate right by 64 - n, so `ROL Rs, #n, Rd` assembles to `ROR Rs, #(64-n), Rd` and `ROL #n, Rd` to `ROR #(64-n), Rd`, in the two-byte form when the count of the right rotation fits it (a rotate left by 1 to 8) and in the four-byte form otherwise; the disassembler prints `ROR`, with a negative count for the short form. `ROL` takes a constant only: the count of `ROR` is taken modulo 64, so a rotate left by a register count is `ROR` by the negated register, which the program makes with `NEG` (a mapping is one instruction, and the assembler does not invent a scratch register). There is no `ROL32`: `ROR32` by 32 minus n is the same rotation. No rotate is through carry; multi-word shifting uses `DSHR`.', xnote='With a constant count parcel 1 is `rs:5 count:6 rd:5`; the two-byte form is `100011 11 count:4 rd:4`.'),
    E('ROR32', 'bits', ['ror32'], 'Rotate right by a constant, 32 bits', ['ROR32 Rs, #n, Rd'],
      'Rd <- sext32(ror32(Rs[31:0], n mod 32))', 'None written.', NONE, notes='The 32-bit rotate with the result sign-extended like every 32-bit result; the primitive of most hash functions and ciphers.'),
    E('DSHR', 'bits', ['dshr'], 'Double-width funnel shift right', ['DSHR Ra, Rb, #n, Rd'],
      '''t <- Ra:Rb                    ; 128 bits, Ra the high half
Rd <- (t >> n)[63:0]          ; n = 0..63''', 'None written.', NONE,
      notes='x86 `SHRD`, ARM `EXTR`. Six bytes (the count is in parcel 2). A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.'),
    E('EXTB', 'bits', ['extb', 'extzb'], 'Extract a bit field', ['EXTB Rs, #pos, #width, Rd        ; sign-extended', 'EXTZB Rs, #pos, #width, Rd       ; zero-extended'],
      '''Rd <- ext((Rs >> pos)[width-1:0])          ; sext for EXTB, zext for EXTZB; width 0 or > 64 means 64''', 'None written.', NONE,
      notes='Six bytes (position and width are in parcel 2), so these exist at `len = 10` only.'),
    E('INSB', 'bits', ['insb'], 'Insert a bit field', ['INSB Rs, #pos, #width, Rd'],
      '''mask <- ((1 << width) - 1) << pos
Rd <- (Rd AND NOT mask) OR ((Rs << pos) AND mask)''', 'None written.', NONE, notes='Six bytes. `Rd` is both source and destination.'),
    E('XNORPOP', 'bits', ['xnorpop'], 'Population count of the equality of two words', ['XNORPOP Ra, Rb, Rd'],
      'Rd <- popcount(NOT (Ra XOR Rb))', 'None written.', NONE,
      notes='For binary-activation networks, Hamming distance and bitset intersection cardinality. It does **not** serve sub-1-bit language models (section {{r:inference-array-languages-and-the-bit}}).'),
    E('CLMUL', 'bits', ['clmull', 'clmulh'], 'Carry-less multiply', ['CLMULL Ra, Rb, Rd', 'CLMULH Ra, Rb, Rd'],
      '''p <- carry-less (polynomial over GF(2)) product of Ra and Rb      ; 128 bits
CLMULL: Rd <- p[63:0]
CLMULH: Rd <- p[127:64]''', 'None written.', NONE,
      notes='The primitive under every CRC (with a Barrett reduction), GF(2^k) arithmetic and GCM; no polynomial is committed to the architecture.'),
    E('UTF8LEN', 'bits', ['utf8len'], 'Length of a UTF-8 sequence from its leading byte', ['UTF8LEN Rs, Rd'],
      'Rd <- length (1 to 4) implied by the leading byte Rs[7:0]; 0 if it cannot begin a valid sequence', 'None written.', NONE),
    E('UTF8DEC', 'bits', ['utf8dec'], 'Decode a UTF-8 sequence', ['UTF8DEC Rs, Rd'],
      '''Rs holds up to 4 bytes, leading byte in bits 7..0
Rd <- the scalar value
If the sequence is not a valid encoding, Rd <- -1''',
      'None written. An invalid sequence (a bad continuation byte, an overlong form, a surrogate (U+D800 to U+DFFF), a value above U+10FFFF, or a leading byte of `11000000 (0xC0)`, `11000001 (0xC1)` or `11110101 (0xF5)` to `11111111 (0xFF)`) gives all ones in `Rd`, which is not a scalar value; the length of a valid sequence is `UTF8LEN` of its leading byte.', NONE),
    E('UTF8ENC', 'bits', ['utf8enc'], 'Encode a Unicode scalar value', ['UTF8ENC Rs, Rd'],
      '''Rd <- the UTF-8 bytes of the scalar value Rs, leading byte in bits 7..0
If Rs is not a Unicode scalar value, Rd <- -1''', 'None written. A surrogate or a value above U+10FFFF gives all ones in `Rd`, which no valid encoding is.', NONE),

    # ---- MBLK ----
    E('MCPY', 'block', ['mcpy', 'mmov'], 'Copy a block of bytes',
      ['MCPY Rd, Rs, Rn        ; destination pointer, source pointer, count', 'MMOV Rd, Rs, Rn        ; correct for overlap'],
      '''MCPY:                            ; ascending; overlap is undefined
  while Rn != 0:  M8[Rd] <- M8[Rs] ; Rd <- Rd + 1 ; Rs <- Rs + 1 ; Rn <- Rn - 1
MMOV: as MCPY, but the direction is chosen from the pointers so that an overlapping copy is correct''',
      NOFLAGS, MEMX + ' The three registers are updated as work completes, so a fault leaves a consistent state and the instruction restarts from its registers.',
      notes='The one granted exception to the one-memory-operand rule. All three registers are architectural state: on completion `Rn` is 0 and `Rd` and `Rs` point one past the end. An implementation may move more than a byte per step, so long as the register state at every point where an exception can be taken is consistent with a byte-at-a-time copy. The accesses made inside one block operation are unordered with respect to each other.',
      cf='{{r:faults-and-restart-what-precise-means}} (restart, progress faults); {{r:memory-ordering-from-sequential-consistency}} (ordering of the accesses).'),
    E('MSET', 'block', ['mset'], 'Fill a block of bytes', ['MSET Rd, Rv, Rn'],
      'while Rn != 0:  M8[Rd] <- Rv[7:0] ; Rd <- Rd + 1 ; Rn <- Rn - 1', NOFLAGS, MEMX,
      notes='`MSET` with `Rv = 0` is the range-zeroing instruction: `bzero` and the clear of `calloc` are one instruction.', cf='{{r:faults-and-restart-what-precise-means}}.'),
    E('MCMP', 'block', ['mcmp'], 'Compare two blocks of bytes', ['MCMP Rd, Rs, Rn'],
      '''while Rn != 0:
    x <- M8[Rd] ; y <- M8[Rs]
    if x != y then stop                               ; pointers left AT the differing byte, Rn the count remaining
    Rd <- Rd + 1 ; Rs <- Rs + 1 ; Rn <- Rn - 1
if equal:  Rn = 0''',
      NOFLAGS, MEMX,
      notes='The report is in the registers: when the blocks are equal `Rn` is 0; when the instruction stops at a difference `Rn` is not 0 and `Rd` and `Rs` point at the differing bytes, so the position of the difference is known and the order of the two bytes is two loads and a compare-and-branch (or `SETLO`) away.', cf='{{r:faults-and-restart-what-precise-means}}.'),
    E('MSCN', 'block', ['mscn', 'mscnn'], 'Scan a block for a byte, or for a byte not equal to it', ['MSCN Rd, Rv, Rn', 'MSCNN Rd, Rv, Rn'],
      '''while Rn != 0:
    hit <- (M8[Rd] == Rv[7:0])             ; MSCNN: hit <- (M8[Rd] != Rv[7:0])
    if hit then stop                       ; Rd points AT the byte found, Rn the count remaining
    Rd <- Rd + 1 ; Rn <- Rn - 1
not found: Rn = 0''',
      NOFLAGS, MEMX,
      notes='The report is in the registers: `Rn` is 0 when no byte was found and not 0 when one was, with `Rd` at it. `MSCN` is `memchr`; with an explicit count it gives `strnlen`, and composing it with `MCPY` gives a bounded `strcpy` in two instructions. There are no NUL-terminated string instructions.', cf='{{r:faults-and-restart-what-precise-means}}.'),
    E('MVAL', 'block', ['mval'], 'Validate a block as UTF-8', ['MVAL Rd, Rn'],
      'scan Rn bytes at Rd; stop at the first byte that cannot be part of a valid UTF-8 sequence (the rules of UTF8DEC)',
      'On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` points at the offending sequence and `Rn` counts the bytes remaining (details in the instruction-set text, section {{r:reset-only-core-0-runs}}).', MEMX,
      notes='The `UTF8DEC` comparators wired to the block sequencer.', cf='{{r:faults-and-restart-what-precise-means}}.'),

    # ---- AESC ----
    E('DIV', 'arith', ['div', 'divu', 'mod', 'modu'], 'Divide and remainder, signed and unsigned',
      ['DIV Ra, Rb, Rd', 'DIVU Ra, Rb, Rd', 'MOD Ra, Rb, Rd', 'MODU Ra, Rb, Rd'],
      '''if Rb = 0 then divide-by-zero abort
DIV : Rd <- Ra / Rb  (signed, rounded toward zero; INT_MIN / -1 = INT_MIN)
DIVU: Rd <- Ra / Rb  (unsigned)
MOD : Rd <- Ra mod Rb (signed, the sign of Ra; any value mod -1 = 0)
MODU: Rd <- Ra mod Rb (unsigned)''', NOFLAGS, 'Division by zero aborts with the divide-by-zero vector (cause `DIVZERO`). There is no overflow trap: `INT_MIN / -1` returns `INT_MIN`.',
      notes='Division by a constant is a `MULH` and a shift, so a real divide is rare; this is why divide has no two-byte form.', cf='{{r:exceptions-interrupts-and-traps}} (the divide-by-zero vector).'),
    E('MULHU', 'arith', ['mulhu'], 'Multiply, high 64 bits, unsigned', ['MULHU Ra, Rb, Rd'], 'Rd <- (Ra * Rb)[127:64]    ; unsigned', NOFLAGS, NONE,
      ),
    E('ABS', 'arith', ['abs'], 'Absolute value (assembler alias)', ['ABS Rs, Rd'], 'Rd <- |Rs|    ; the most negative number stays itself', 'Those of the instructions it expands to.', NONE,
      alias="`ABS` is an assembler alias: it assembles to `MOVQ Rs, R12`, `SAR #63, R12`, `MOVQ Rs, Rd` (left out when `Rd` is `Rs`), `XOR R12, Rd` and `SUB R12, Rd`. `R12`, after `SAR`, holds all ones for a negative `Rs` and zero otherwise; exclusive-or with it complements a negative number and subtracting it adds one, so a negative number becomes its negation, a positive one is unchanged, and the most negative number, which has no positive twin, comes back as itself. The sequence has no branch, so no data makes it slow or leaves a trace in the branch predictor. The assembler writes `R12`, which is caller-saved, and no flag exists, so nothing else changes; `R12` cannot be an operand of `ABS`, and the assembler refuses it."),
    E('MINMAX', 'arith', ['min', 'minu', 'max', 'maxu'], 'Minimum and maximum, signed and unsigned (assembler aliases)',
      ['MIN Ra, Rb, Rd', 'MINU Ra, Rb, Rd', 'MAX Ra, Rb, Rd', 'MAXU Ra, Rb, Rd'],
      '''MIN : Rd <- smaller of Ra, Rb (signed)         MINU: unsigned
MAX : Rd <- larger of Ra, Rb (signed)          MAXU: unsigned''', 'Those of the instructions they expand to.', NONE,
      alias="`MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases: each assembles to a compare into `R12`, `NEG R12` and `BSEL R12, Ra, Rb, Rd`; the compare is `SETLT Ra, Rb, R12` for `MIN`, `SETLO Ra, Rb, R12` for `MINU`, `SETGT Ra, Rb, R12` for `MAX` and `SETHI Ra, Rb, R12` for `MAXU`. The comparison gives one or zero, `NEG` makes it all ones or zero, and `BSEL` takes `Ra` where the mask has ones and `Rb` where it has zeros, so `Rd` is `Ra` when the comparison holds and `Rb` otherwise. Every source is read before `Rd` is written, so `Rd` may be `Ra` or `Rb`, and `Ra` may be `Rb`. The sequence has no branch: it takes the same time for every value. The assembler writes `R12`, which is caller-saved, and no flag exists, so nothing else changes; `R12` cannot be an operand of these words, and the assembler refuses it. `MIN` and `MINU` differ on a negative number, which is a large unsigned one."),
    E('SETCC', 'arith', ['seteq', 'setne', 'setlt', 'setle', 'setgt', 'setge', 'setcs', 'setcc', 'sethi', 'setlos'], 'Compare into a register', ['SETLT Ra, Rb, Rd', 'SETEQ Ra, #imm, Rd ... and the rest'],
      'Rd <- 1 if the comparison of Ra with Rb (or with the signed immediate) holds, else 0', NOFLAGS, 'None.',
      notes='The conditions are equal, not equal, the signed less, less-or-equal, greater and greater-or-equal, and the unsigned lower (`SETCS`, also `SETLO`), higher-or-the-same (`SETCC`, also `SETHIS`), higher and lower-or-the-same, as the compare-and-branch words have them. `SETLT Ra, Rb, Rd` is `Rd <- (Ra < Rb)`, the first operand the left of the comparison. The immediate is an 8-bit signed number, sign-extended to 64 bits before the comparison, for the unsigned conditions as well; a wider constant is loaded into a register first. The destination may be one of the sources; they are read before it is written. Four bytes. A carry out of an addition is `ADD Rb, Ra` then `SETLO Ra, Rb, Rt`: the sum is lower than an addend exactly when the addition carried.'),

    # ---- FESC ----
    E('FDIV', 'fp', ['fdiv', 'fsqrt'], 'Floating divide and square root, binary64', ['FDIV Rs, Rd', 'FSQRT Rs, Rd'],
      '''FDIV : Rd <- Rd / Rs
FSQRT: Rd <- sqrt(Rs)''', FPFLAG, NONE, xnote=FXNOTE,
      notes='`FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a two-byte form, so they are in `FESC`.'),
    E('FSINGLE', 'fp', ['fadd32', 'fsub32', 'fmul32', 'fdiv32', 'fsqrt32'], 'Floating arithmetic, binary32',
      ['FADD32 Rs, Rd', 'FSUB32 Rs, Rd', 'FMUL32 Rs, Rd', 'FDIV32 Rs, Rd', 'FSQRT32 Rs, Rd'],
      '''Rd <- Rd op Rs  (FADD32 FSUB32 FMUL32 FDIV32); Rd <- sqrt(Rs) (FSQRT32)''', FPFLAG, NONE, xnote=FXNOTE,
      notes='A `binary32` lives in the low 32 bits of a register, sign-extended to 64 like every 32-bit result. Results are correctly rounded to nearest even.'),
    E('FMADD', 'fp', ['fmadd', 'fnmsub'], 'Fused multiply-add, binary64',
      ['FMADD Rs, Rt, Ru, Rd', 'FNMSUB Rs, Rt, Ru, Rd'],
      '''FMADD : Rd <- Rs*Rt + Ru
FNMSUB: Rd <- -(Rs*Rt) + Ru          ; each rounded once''', FPFLAG, NONE, xnote=FXNOTE,
      notes='Four register operands are available at `len = 01`. The two other signs are these two with the addend negated by `FNEG`, which is exact and raises nothing: `Rs*Rt - Ru` is `FMADD` of `Rs`, `Rt` and the negated `Ru`, and `-(Rs*Rt) - Ru` is `FNMSUB` of the same three; the result, its rounding and its flags are exactly those of an operation that subtracts. `-(Rs*Rt) - Ru` is not the negated `FMADD`: when the exact sum is zero the two have different signs of zero.'),
    E('FMADD32', 'fp', ['fmadd32', 'fnmsub32'], 'Fused multiply-add, binary32',
      ['FMADD32 Rs, Rt, Ru, Rd', 'FNMSUB32 Rs, Rt, Ru, Rd'], 'As FMADD and FNMSUB, in binary32, rounded once', FPFLAG, NONE, xnote=FXNOTE,
      notes='The sign of a `binary32` is flipped exactly by `FNEG32`, which is `XOR #-2147483648` and raises no exception flag.'),
    E('FSIGN', 'fp', ['fneg', 'fabs', 'fcopysign', 'fneg32', 'fabs32'], 'Sign operations on the bits', ['FNEG Rs, Rd', 'FABS Rs, Rd', 'FCOPYSIGN Rs, Rt, Rd', 'FNEG32 Rs, Rd', 'FABS32 Rs, Rd'],
      '''FNEG     : Rd <- Rs with the sign bit flipped
FABS     : Rd <- Rs with the sign bit cleared
FCOPYSIGN: Rd <- magnitude of Rs, sign of Rt
FNEG32   : Rd <- Rs with the sign of the binary32 flipped    (XOR #-2147483648, Rd)
FABS32   : Rd <- Rs with the sign of the binary32 cleared    (AND #0x7FFFFFFF, Rd)''',
      'None for the three native words: they operate on the bits, do not canonicalise a NaN and raise no exception flag. `FNEG32` and `FABS32` are the instructions they stand for and raise none either.', NONE, xnote=FXNOTE,
      notes='`FNEG32` and `FABS32` are assembler mappings of the sign operations of a `binary32`, not native instructions: `FNEG32 Rs, Rd` assembles to `XOR #-2147483648, Rd` and `FABS32 Rs, Rd` to `AND #0x7FFFFFFF, Rd`, each preceded by `MOVQ Rs, Rd` when the two registers differ. A `binary32` lives in a register sign-extended to 64 bits, so its sign is bits 63 to 31 together and the constant that changes it is `0xFFFFFFFF80000000`; the result is again a sign-extended `binary32`, flipped or cleared exactly (a NaN and a zero included), and nothing is raised. The sign of a `binary64` is the single bit 63, which is why `FNEG` and `FABS` are native; the sign of a sign-extended `binary32` is spread over bits 63 to 31, so no single native instruction changes it and the two mappings are an `XOR` and an `AND` with a constant. There is no `FCOPYSIGN32`: its `binary32` form is several instructions on the bits (and the sign must be extended to 64 bits again), more than a mapping should hide.'),
    E('FMIN', 'fp', ['fmin', 'fmax'], 'Floating minimum and maximum, binary64', ['FMIN Rs, Rt, Rd', 'FMAX Rs, Rt, Rd'],
      '''if Rs is a NaN then Rd <- Rt ; else if Rt is a NaN then Rd <- Rs ; else Rd <- smaller (FMIN) or larger (FMAX)
if both are NaNs the result is the canonical quiet NaN''', FPFLAG, NONE, xnote=FXNOTE, notes=''),
    E('FCLASS', 'fp', ['fclass', 'fclass32'], 'Classify a floating-point value', ['FCLASS Rs, Rd', 'FCLASS32 Rs, Rd'],
      '''Rd <- a bit vector with exactly one bit set:
bit 0 -infinity      bit 1 -normal      bit 2 -subnormal   bit 3 -zero
bit 4 +zero          bit 5 +subnormal   bit 6 +normal      bit 7 +infinity
bit 8 signalling NaN bit 9 quiet NaN''', 'None.', NONE, xnote=FXNOTE, notes='Every libm function begins with this dispatch.'),
    E('FRINT', 'fp', ['frint', 'frintz', 'frintm', 'frintp', 'frinta'], 'Round to an integral value, binary64',
      ['FRINT Rs, Rd', 'FRINTZ Rs, Rd', 'FRINTM Rs, Rd', 'FRINTP Rs, Rd', 'FRINTA Rs, Rd'],
      '''FRINT : Rd <- Rs rounded to nearest, ties to even
FRINTZ: toward zero         FRINTM: toward -infinity
FRINTP: toward +infinity    FRINTA: to nearest, ties away from zero (C round())''', FPFLAG, NONE, xnote=FXNOTE,
      notes='The rounding mode is in the opcode, never in a mode bit.'),
    E('FCVT', 'fp', ['fcvtdq', 'fcvtdqu', 'fcvtqd', 'fcvtqud', 'fcvtds', 'fcvtsd', 'fcvtsl', 'fcvtls'], 'Floating conversions',
      ['FCVTDQ Rs, Rd        ; binary64 to signed quad', 'FCVTDQU Rs, Rd       ; binary64 to unsigned quad', 'FCVTQD Rs, Rd        ; signed quad to binary64', 'FCVTQUD Rs, Rd       ; unsigned quad to binary64',
       'FCVTDS Rs, Rd        ; binary64 to binary32', 'FCVTSD Rs, Rd        ; binary32 to binary64', 'FCVTSL Rs, Rd        ; binary32 to signed 32-bit integer', 'FCVTLS Rs, Rd        ; signed 32-bit integer to binary32'],
      '''float to integer: truncate toward zero, then saturate; a NaN gives the largest value
integer to float: round to nearest even''', FPFLAG + ' ' + SATQ, NONE, xnote=FXNOTE,
      notes='Integer results are 64-bit (`FCVTDQ`, `FCVTDQU`) or 32-bit sign-extended (`FCVTSL`). Unsigned conversion of a negative value is invalid and gives 0.'),
    E('FSFLAGS', 'fp', ['fsflags'], 'Swap the floating-point exception flags', ['FSFLAGS Rs, Rd'],
      '''old <- FPSR
FPSR <- Rs[4:0]
Rd <- old''', 'None.', NONE, xnote=FXNOTE,
      notes='`FPSR` is the sticky five-bit register (`NX` bit 0, `UF` 1, `OF` 2, `DZ` 3, `NV` 4). C99 `<fenv.h>` is built on this one instruction.'),
    E('FCVTH', 'fp', ['fcvtsh', 'fcvths', 'fcvtdh', 'fcvthd', 'fcvthl', 'fcvtlh'], 'Conversions to and from binary16',
      ['FCVTSH Rs, Rd        ; binary32 to half', 'FCVTHS Rs, Rd        ; half to binary32', 'FCVTDH Rs, Rd        ; binary64 to half', 'FCVTHD Rs, Rd        ; half to binary64',
       'FCVTHL Rs, Rd        ; half to signed 32-bit integer, toward zero', 'FCVTLH Rs, Rd        ; signed 32-bit integer to half'],
      '''narrowing: round to nearest even ; widening: exact
FCVTHL of a NaN or an infinity is invalid and saturates; truncating a fraction is inexact''', FPFLAG, NONE, xnote=FXNOTE,
      notes='`binary16` is a storage format: a half lives in the low 16 bits of a register, sign-extended to 64, is loaded and stored with `MOVW`, and has these six conversions and no arithmetic. Every half is exact in `binary32`, so an operation on halves is made by widening (`FCVTHS`), operating in `binary32` and narrowing (`FCVTSH`) once; for add, subtract, multiply, divide and square root that gives the correctly rounded half, because a `binary32` has at least 2 × 11 + 2 bits of significand. A fused multiply-add of halves is not a case of this: widen to `binary64` and the sum may be rounded before it is narrowed. A NaN narrowed to a half is the canonical `0x7E00`; tininess is judged after rounding.'),
]
