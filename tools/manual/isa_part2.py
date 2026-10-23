"""Dictionary entries, part 2: bits and fields, block memory, arithmetic escape, floating point."""
from isa_common import *

REGX = 'A reserved encoding aborts with the illegal-instruction vector.'
FXNOTE = 'Operand roles: `reg` is the destination `Rd`, `low` the first source `Rs`, `t` the second `Rt` and `x` the third `Ru`; the assembler writes the destination last.'
FPFLAG = 'No integer flag is written. The IEEE exception flags raised are ORed into `FPSR` (`NX` inexact, `UF` underflow, `OF` overflow, `DZ` divide by zero, `NV` invalid); nothing traps.'
SATQ = 'A NaN or an out-of-range value raises `NV` and saturates.'

ENTRIES = [
    # ---- BESC ----
    E('COUNT', 'bits', ['clz', 'ctz', 'clo', 'cto'], 'Count leading and trailing zeros and ones',
      ['CLZ Rs, Rd', 'CTZ Rs, Rd', 'CLO Rs, Rd', 'CTO Rs, Rd'],
      '''CLZ: Rd <- number of leading zero bits of Rs        (64 if Rs = 0)
CTZ: Rd <- number of trailing zero bits of Rs       (64 if Rs = 0)
CLO: Rd <- number of leading one bits of Rs         (64 if Rs = all ones)
CTO: Rd <- number of trailing one bits of Rs        (64 if Rs = all ones)''', NOFLAGS, NONE, '9.9',
      notes='`CTZ` is the VAX `FFS`. Bit manipulation is core on a machine that does filesystem and bignum work, not an extension.', xnote='Register to register only; four bytes.'),
    E('POPCNT', 'bits', ['popcnt'], 'Population count', ['POPCNT Rs, Rd'], 'Rd <- number of one bits in Rs', NOFLAGS, NONE, '9.9'),
    E('BSWAP', 'bits', ['bswap', 'bswapw', 'bswapl'], 'Byte swap',
      ['BSWAP Rs, Rd', 'BSWAPW Rs, Rd', 'BSWAPL Rs, Rd'],
      '''BSWAP : Rd <- Rs with all 8 bytes reversed
BSWAPW: Rd <- Rs with the bytes of each 16-bit word reversed
BSWAPL: Rd <- Rs with the bytes of each 32-bit long reversed''', NOFLAGS, NONE, '9.9', notes='The generalisation of the PDP-11 `SWAB` to 64 bits.'),
    E('BITREV', 'bits', ['bitrev'], 'Reverse the bits', ['BITREV Rs, Rd'], 'Rd <- Rs with bit i moved to bit 63-i', NOFLAGS, NONE, '9.9'),
    E('ROR', 'bits', ['ror'], 'Rotate right by a register count', ['ROR Ra, Rb, Rd'], 'Rd <- Ra rotated right by (Rb mod 64)', 'None written (rotates write no flags: errata 39).', NONE, '9.8',
      notes='There is no rotate left instruction: `ROL rs, #n, rd` is an assembler spelling of `RORI rs, #(64-n), rd`. No rotate is through carry; multi-word shifting uses `DSHR`.'),
    E('RORI', 'bits', ['rori'], 'Rotate right by an immediate', ['RORI Rs, #n, Rd', 'ROL Rs, #n, Rd        ; assembles to RORI Rs, #(64-n), Rd'],
      'Rd <- Rs rotated right by (n mod 64)', 'None written.', NONE, '9.8', notes='Four bytes: the count is in the low byte of parcel 1.', xnote='Parcel 1 is `sub:8 count:8`.'),
    E('RORI32', 'bits', ['rori32'], 'Rotate right by an immediate, 32 bits', ['RORI32 Rs, #n, Rd'],
      'Rd <- sext32(ror32(Rs[31:0], n mod 32))', 'None written.', NONE, '9.8', notes='The 32-bit rotate with the result sign-extended like every 32-bit result; the primitive of most hash functions and ciphers.'),
    E('DSHR', 'bits', ['dshr'], 'Double-width funnel shift right', ['DSHR Ra, Rb, #n, Rd'],
      '''t <- Ra:Rb                    ; 128 bits, Ra the high half
Rd <- (t >> n)[63:0]          ; n = 0..63''', 'None written.', NONE, '9.9',
      notes='x86 `SHRD`, ARM `EXTR`. Six bytes (the count is in parcel 2). A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.'),
    E('EXTB', 'bits', ['extb', 'extzb'], 'Extract a bit field', ['EXTB Rs, #pos, #width, Rd        ; sign-extended', 'EXTZB Rs, #pos, #width, Rd       ; zero-extended'],
      '''Rd <- ext((Rs >> pos)[width-1:0])          ; sext for EXTB, zext for EXTZB; width 0 or > 64 means 64''', 'None written.', NONE, '9.9',
      notes='Six bytes (position and width are in parcel 2), so these exist at `len = 10` only.'),
    E('INSB', 'bits', ['insb'], 'Insert a bit field', ['INSB Rs, #pos, #width, Rd'],
      '''mask <- ((1 << width) - 1) << pos
Rd <- (Rd AND NOT mask) OR ((Rs << pos) AND mask)''', 'None written.', NONE, '9.9', notes='Six bytes. `Rd` is both source and destination.'),
    E('XNORPOP', 'bits', ['xnorpop'], 'Population count of the equality of two words', ['XNORPOP Ra, Rb, Rd'],
      'Rd <- popcount(NOT (Ra XOR Rb))', 'None written.', NONE, '9.9',
      notes='For binary-activation networks, Hamming distance and bitset intersection cardinality. It does **not** serve sub-1-bit language models (book section 8.3).'),
    E('CLMUL', 'bits', ['clmull', 'clmulh'], 'Carry-less multiply', ['CLMULL Ra, Rb, Rd', 'CLMULH Ra, Rb, Rd'],
      '''p <- carry-less (polynomial over GF(2)) product of Ra and Rb      ; 128 bits
CLMULL: Rd <- p[63:0]
CLMULH: Rd <- p[127:64]''', 'None written.', NONE, '9.9',
      notes='The primitive under every CRC (with a Barrett reduction), GF(2^k) arithmetic and GCM; no polynomial is committed to the architecture.'),
    E('UTF8LEN', 'bits', ['utf8len'], 'Length of a UTF-8 sequence from its leading byte', ['UTF8LEN Rs, Rd'],
      'Rd <- length (1 to 4) implied by the leading byte Rs[7:0]; 0 if it cannot begin a valid sequence', 'None written.', NONE, '9.9'),
    E('UTF8DEC', 'bits', ['utf8dec'], 'Decode a UTF-8 sequence', ['UTF8DEC Rs, Rd'],
      '''Rs holds up to 4 bytes, leading byte in bits 7..0
Rd <- the scalar value
V  <- 1 if the sequence is not a valid encoding''',
      '`V` set for a bad continuation byte, an overlong form, a surrogate (U+D800 to U+DFFF), a value above U+10FFFF, or a leading byte of `11000000 (0xC0)`, `11000001 (0xC1)` or `11110101 (0xF5)` to `11111111 (0xFF)`; the length consumed is reported in a scratch field of the status word (details in the instruction-set text, section 4.6.1).', NONE, '9.9'),
    E('UTF8ENC', 'bits', ['utf8enc'], 'Encode a Unicode scalar value', ['UTF8ENC Rs, Rd'],
      '''Rd <- the UTF-8 bytes of the scalar value Rs, leading byte in bits 7..0
V  <- 1 if Rs is not a Unicode scalar value''', '`V` set if `Rs` is not a Unicode scalar value (a surrogate or above U+10FFFF).', NONE, '9.9'),

    # ---- MBLK ----
    E('MCPY', 'block', ['mcpy', 'mmov'], 'Copy a block of bytes',
      ['MCPY Rd, Rs, Rn        ; destination pointer, source pointer, count', 'MMOV Rd, Rs, Rn        ; correct for overlap'],
      '''MCPY:                            ; ascending; overlap is undefined
  while Rn != 0:  M8[Rd] <- M8[Rs] ; Rd <- Rd + 1 ; Rs <- Rs + 1 ; Rn <- Rn - 1
MMOV: as MCPY, but the direction is chosen from the pointers so that an overlapping copy is correct''',
      NOFLAGS, MEMX + ' The three registers are updated as work completes, so a fault leaves a consistent state and the instruction restarts from its registers.', '9.11',
      notes='The one granted exception to the one-memory-operand rule. All three registers are architectural state: on completion `Rn` is 0 and `Rd` and `Rs` point one past the end. An implementation may move more than a byte per step, so long as the register state at every point where an exception can be taken is consistent with a byte-at-a-time copy. The accesses made inside one block operation are unordered with respect to each other.',
      cf='6.8 (restart, progress faults); 7.2 (ordering of the accesses).'),
    E('MSET', 'block', ['mset'], 'Fill a block of bytes', ['MSET Rd, Rv, Rn'],
      'while Rn != 0:  M8[Rd] <- Rv[7:0] ; Rd <- Rd + 1 ; Rn <- Rn - 1', NOFLAGS, MEMX, '9.11',
      notes='`MSET` with `Rv = 0` is the range-zeroing instruction: `bzero` and the clear of `calloc` are one instruction.', cf='6.8.'),
    E('MCMP', 'block', ['mcmp'], 'Compare two blocks of bytes', ['MCMP Rd, Rs, Rn'],
      '''while Rn != 0:
    x <- M8[Rd] ; y <- M8[Rs]
    if x != y then  flags <- flags of (x - y) ; stop      ; pointers left AT the differing byte
    Rd <- Rd + 1 ; Rs <- Rs + 1 ; Rn <- Rn - 1
if equal:  N = 0, Z = 1, V = 0, C = 0''',
      'From the first differing byte as for `CMP` of the two bytes (`C` set if `x < y` unsigned, `N` and `V` from the signed difference); for equal blocks `N` = 0, `Z` = 1, `V` = 0, `C` = 0.', MEMX, '9.11',
      notes='When the instruction stops at a difference, `Rd` and `Rs` point at the differing bytes and `Rn` is the count remaining, so the position of the difference is in the registers.', cf='6.8.'),
    E('MSCN', 'block', ['mscn', 'mscnn'], 'Scan a block for a byte, or for a byte not equal to it', ['MSCN Rd, Rv, Rn', 'MSCNN Rd, Rv, Rn'],
      '''while Rn != 0:
    hit <- (M8[Rd] == Rv[7:0])             ; MSCNN: hit <- (M8[Rd] != Rv[7:0])
    if hit then  Z = 1 ; stop              ; Rd points AT the byte found
    Rd <- Rd + 1 ; Rn <- Rn - 1
not found: Z = 0''',
      '**All four flags are written** (errata 39): `Z` = 1 if the byte was found, else 0; `N`, `V` and `C` are cleared.', MEMX, '9.11',
      notes='`MSCN` is `memchr`; with an explicit count it gives `strnlen`, and composing it with `MCPY` gives a bounded `strcpy` in two instructions. There are no NUL-terminated string instructions.', cf='6.8.'),
    E('MVAL', 'block', ['mval'], 'Validate a block as UTF-8', ['MVAL Rd, Rn'],
      'scan Rn bytes at Rd; stop at the first byte that cannot be part of a valid UTF-8 sequence (the rules of UTF8DEC)',
      'On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` points at the offending sequence and `Rn` counts the bytes remaining (details in the instruction-set text, section 4.7.1).', MEMX, '9.9',
      notes='The `UTF8DEC` comparators wired to the block sequencer.', cf='6.8.'),

    # ---- AESC ----
    E('DIV', 'arith', ['div', 'divu', 'mod', 'modu'], 'Divide and remainder, signed and unsigned',
      ['DIV Ra, Rb, Rd', 'DIVU Ra, Rb, Rd', 'MOD Ra, Rb, Rd', 'MODU Ra, Rb, Rd'],
      '''if Rb = 0 then divide-by-zero abort
DIV : Rd <- Ra / Rb  (signed, rounded toward zero; INT_MIN / -1 = INT_MIN)
DIVU: Rd <- Ra / Rb  (unsigned)
MOD : Rd <- Ra mod Rb (signed, the sign of Ra; any value mod -1 = 0)
MODU: Rd <- Ra mod Rb (unsigned)''', NOFLAGS, 'Division by zero aborts with the divide-by-zero vector (cause `DIVZERO`). There is no overflow trap: `INT_MIN / -1` returns `INT_MIN`.', '9.7',
      notes='Division by a constant is a `MULH` and a shift, so a real divide is rare; this is why divide has no two-byte form.', cf='6.2 (the divide-by-zero vector).'),
    E('MULHU', 'arith', ['mulhu'], 'Multiply, high 64 bits, unsigned', ['MULHU Ra, Rb, Rd'], 'Rd <- (Ra * Rb)[127:64]    ; unsigned', NOFLAGS, NONE, '9.7',
      notes='`MULHSU` (signed by unsigned) is reserved and not committed.'),
    E('ABS', 'arith', ['abs'], 'Absolute value', ['ABS Rs, Rd'], 'Rd <- |Rs|', '`N` and `Z` from the result, `V` set if `Rs` is the most negative value (the result is then still negative), `C` unchanged.', NONE, '9.7'),
    E('MINMAX', 'arith', ['min', 'minu', 'max', 'maxu'], 'Minimum and maximum, signed and unsigned',
      ['MIN Ra, Rb, Rd', 'MINU Ra, Rb, Rd', 'MAX Ra, Rb, Rd', 'MAXU Ra, Rb, Rd'],
      '''MIN : Rd <- smaller of Ra, Rb (signed)         MINU: unsigned
MAX : Rd <- larger of Ra, Rb (signed)          MAXU: unsigned''', '`N` and `Z` from the result, `V` = 0, `C` unchanged.', NONE, '9.7'),
    E('SET', 'arith', ['set'], 'Set a register from a condition', ['SET cc, Rd        ; for example SET EQ, R1'],
      'Rd <- 1 if condition cc holds on the current flags, else 0', NOFLAGS, NONE, '9.7',
      notes='The condition is the `x` field of parcel 1, numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).'),

    # ---- FESC ----
    E('FDIV', 'fp', ['fdiv', 'fsqrt'], 'Floating divide and square root, binary64', ['FDIV Rs, Rd', 'FSQRT Rs, Rd'],
      '''FDIV : Rd <- Rd / Rs
FSQRT: Rd <- sqrt(Rs)''', FPFLAG, NONE, '9.12', xnote=FXNOTE,
      notes='`FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a two-byte form, so they are in `FESC`. The old spellings `FDIVD`, `FSQRTD` are aliases.'),
    E('FSINGLE', 'fp', ['fadd32', 'fsub32', 'fmul32', 'fdiv32', 'fsqrt32', 'fcmp32'], 'Floating arithmetic, binary32',
      ['FADD32 Rs, Rd', 'FSUB32 Rs, Rd', 'FMUL32 Rs, Rd', 'FDIV32 Rs, Rd', 'FSQRT32 Rs, Rd', 'FCMP32 Rd, Rs'],
      '''Rd <- Rd op Rs  (FADD32 FSUB32 FMUL32 FDIV32); Rd <- sqrt(Rs) (FSQRT32)
FCMP32: flags as FCMP, comparing Rd with Rs''', FPFLAG + ' `FCMP32` writes `N Z V C` as `FCMP` does.', NONE, '9.12', xnote=FXNOTE,
      notes='A `binary32` lives in the low 32 bits of a register, sign-extended to 64 like every 32-bit result. Results are correctly rounded to nearest even. The old spellings `FADDS`, `FSUBS`, ... are aliases.'),
    E('FMADD', 'fp', ['fmadd', 'fmsub', 'fnmadd', 'fnmsub'], 'Fused multiply-add, binary64',
      ['FMADD Rs, Rt, Ru, Rd', 'FMSUB Rs, Rt, Ru, Rd', 'FNMADD Rs, Rt, Ru, Rd', 'FNMSUB Rs, Rt, Ru, Rd'],
      '''FMADD : Rd <- Rs*Rt + Ru
FMSUB : Rd <- Rs*Rt - Ru
FNMADD: Rd <- -(Rs*Rt) - Ru
FNMSUB: Rd <- -(Rs*Rt) + Ru          ; each rounded once''', FPFLAG, NONE, '9.12', xnote=FXNOTE,
      notes='Four register operands are available at `len = 01`. The old spellings `FMADDD`, ... are aliases.'),
    E('FMADD32', 'fp', ['fmadd32', 'fmsub32', 'fnmadd32', 'fnmsub32'], 'Fused multiply-add, binary32',
      ['FMADD32 Rs, Rt, Ru, Rd', 'FMSUB32 ...', 'FNMADD32 ...', 'FNMSUB32 ...'], 'As FMADD, in binary32, rounded once', FPFLAG, NONE, '9.12', xnote=FXNOTE),
    E('FSIGN', 'fp', ['fneg', 'fabs', 'fcopysign'], 'Sign operations on the bits', ['FNEG Rs, Rd', 'FABS Rs, Rd', 'FCOPYSIGN Rs, Rt, Rd'],
      '''FNEG     : Rd <- Rs with the sign bit flipped
FABS     : Rd <- Rs with the sign bit cleared
FCOPYSIGN: Rd <- magnitude of Rs, sign of Rt''', 'None. These operate on the bits, do not canonicalise a NaN and raise no exception flag.', NONE, '9.12', xnote=FXNOTE),
    E('FMIN', 'fp', ['fmin', 'fmax'], 'Floating minimum and maximum, binary64', ['FMIN Rs, Rt, Rd', 'FMAX Rs, Rt, Rd'],
      '''if Rs is a NaN then Rd <- Rt ; else if Rt is a NaN then Rd <- Rs ; else Rd <- smaller (FMIN) or larger (FMAX)
if both are NaNs the result is the canonical quiet NaN''', FPFLAG, NONE, '9.12', xnote=FXNOTE, notes='The old spellings `FMIND`, `FMAXD` are aliases.'),
    E('FCLASS', 'fp', ['fclass', 'fclass32', 'fclass16'], 'Classify a floating-point value', ['FCLASS Rs, Rd', 'FCLASS32 Rs, Rd', 'FCLASS16 Rs, Rd'],
      '''Rd <- a bit vector with exactly one bit set:
bit 0 -infinity      bit 1 -normal      bit 2 -subnormal   bit 3 -zero
bit 4 +zero          bit 5 +subnormal   bit 6 +normal      bit 7 +infinity
bit 8 signalling NaN bit 9 quiet NaN''', 'None.', NONE, '9.12', xnote=FXNOTE, notes='Every libm function begins with this dispatch. The old spellings `FCLASSD`, `FCLASSS` are aliases.'),
    E('FRINT', 'fp', ['frint', 'frintz', 'frintm', 'frintp', 'frinta'], 'Round to an integral value, binary64',
      ['FRINT Rs, Rd', 'FRINTZ Rs, Rd', 'FRINTM Rs, Rd', 'FRINTP Rs, Rd', 'FRINTA Rs, Rd'],
      '''FRINT : Rd <- Rs rounded to nearest, ties to even
FRINTZ: toward zero         FRINTM: toward -infinity
FRINTP: toward +infinity    FRINTA: to nearest, ties away from zero (C round())''', FPFLAG, NONE, '9.12', xnote=FXNOTE,
      notes='The rounding mode is in the opcode, never in a mode bit. The old spellings `FRINTD`, `FRINTDZ`, ... are aliases.'),
    E('FCVT', 'fp', ['fcvtdq', 'fcvtdqu', 'fcvtqd', 'fcvtqud', 'fcvtds', 'fcvtsd', 'fcvtsl', 'fcvtls'], 'Floating conversions',
      ['FCVTDQ Rs, Rd        ; binary64 to signed quad', 'FCVTDQU Rs, Rd       ; binary64 to unsigned quad', 'FCVTQD Rs, Rd        ; signed quad to binary64', 'FCVTQUD Rs, Rd       ; unsigned quad to binary64',
       'FCVTDS Rs, Rd        ; binary64 to binary32', 'FCVTSD Rs, Rd        ; binary32 to binary64', 'FCVTSL Rs, Rd        ; binary32 to signed 32-bit integer', 'FCVTLS Rs, Rd        ; signed 32-bit integer to binary32'],
      '''float to integer: truncate toward zero, then saturate; a NaN gives the largest value
integer to float: round to nearest even''', FPFLAG + ' ' + SATQ, NONE, '9.12', xnote=FXNOTE,
      notes='Integer results are 64-bit (`FCVTDQ`, `FCVTDQU`) or 32-bit sign-extended (`FCVTSL`). Unsigned conversion of a negative value is invalid and gives 0.'),
    E('FSFLAGS', 'fp', ['fsflags'], 'Swap the floating-point exception flags', ['FSFLAGS Rs, Rd'],
      '''old <- FPSR
FPSR <- Rs[4:0]
Rd <- old''', 'None.', NONE, '9.12', xnote=FXNOTE,
      notes='`FPSR` is the sticky five-bit register (`NX` bit 0, `UF` 1, `OF` 2, `DZ` 3, `NV` 4). C99 `<fenv.h>` is built on this one instruction.'),
    E('FHALF', 'fp', ['fadd16', 'fsub16', 'fmul16', 'fdiv16', 'fsqrt16', 'fcmp16', 'fmadd16', 'fmsub16', 'fnmadd16', 'fnmsub16'], 'Floating arithmetic, binary16',
      ['FADD16 Rs, Rd', 'FSUB16 Rs, Rd', 'FMUL16 Rs, Rd', 'FDIV16 Rs, Rd', 'FSQRT16 Rs, Rd', 'FCMP16 Rd, Rs', 'FMADD16 Rs, Rt, Ru, Rd ...'],
      '''as the binary32 words, in binary16: Rd <- Rd op Rs ; the fused forms take Rs, Rt, Ru, Rd
a half lives in the low 16 bits of a register, sign-extended to 64''', FPFLAG + ' `FCMP16` writes `N Z V C` as `FCMP`.', NONE, '9.12', xnote=FXNOTE,
      notes='Results are correctly rounded to nearest even, tininess judged after rounding; a NaN result is the canonical `0x7E00`. Half `FMIN`, `FMAX`, `FRINT*`, bfloat16 and conversions to and from 64-bit integers are open items.'),
    E('FCVTH', 'fp', ['fcvtsh', 'fcvths', 'fcvtdh', 'fcvthd', 'fcvthl', 'fcvtlh'], 'Conversions to and from binary16',
      ['FCVTSH Rs, Rd        ; binary32 to half', 'FCVTHS Rs, Rd        ; half to binary32', 'FCVTDH Rs, Rd        ; binary64 to half', 'FCVTHD Rs, Rd        ; half to binary64',
       'FCVTHL Rs, Rd        ; half to signed 32-bit integer, toward zero', 'FCVTLH Rs, Rd        ; signed 32-bit integer to half'],
      '''narrowing: round to nearest even ; widening: exact
FCVTHL of a NaN or an infinity is invalid and saturates; truncating a fraction is inexact''', FPFLAG, NONE, '9.12', xnote=FXNOTE),
]
