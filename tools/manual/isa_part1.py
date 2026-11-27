"""Dictionary entries, part 1: moves, the ALU, branches, single-operand and transfer instructions."""
from isa_common import *

ENTRIES = [
    E('MOV', 'moves', ['movq', 'movl', 'movw', 'movb', 'movzl', 'movzw', 'movzb', 'movq.u', 'movl.u', 'movw.u', 'movb.u', 'movzl.u', 'movzw.u', 'movzb.u'], 'Move, load and store (64, 32, 16 and 8 bits)',
      ['MOV rm, Rd        ; load 64 bits (MOV is MOV.s64)', 'MOV Rs, rm        ; store 64 bits', 'MOV $imm, Rd      ; a constant of any size', 'MOV.s32, MOV.s16, MOV.s8 rm, Rd   ; 32, 16 and 8 bits, a load sign-extends; MOV.s32 Rs, rm and the others store the low bits',
       'MOV.u32, MOV.u16, MOV.u8 rm, Rd   ; loads that zero-extend (as a store the same word as MOV.s32, MOV.s16, MOV.s8)', 'MOV.s64, MOV.u64    ; the explicit spellings of MOV',
       'MOV.s8 Rs, Rd        ; with registers: sign-extend the low byte of Rs (MOV.u8: zero-extend it)', 'MOV.user, MOV.user.s32, MOV.user.s16, MOV.user.s8, MOV.user.u32, MOV.user.u16, MOV.user.u8    ; the same with the memory operand checked as a user-mode access'],
      '''size = 8 (MOV), 4 (MOV.s32), 2 (MOV.s16) or 1 (MOV.s8) bytes
load :  Rd <- sext(M[EA(rm)], size)          ; MOV.U*: Rd <- zext(M[EA(rm)], size); len = 00: Rd <- sext(Rs[8*size-1:0]) (MOV.U*: zext)
store:  M[EA(rm)] <- Rs[8*size-1:0]
MOV.user: as MOV, with the memory operand checked as a user-mode access: the page must be present, have U = 1,
        and permit R (a load) or W (a store); a kernel page takes the protection abort''',
      NOFLAGS, MEMX,
      notes='The width and the kind are a suffix of the word: `.s8`, `.s16`, `.s32` and `.s64` are signed, `.u8`, `.u16`, `.u32` and `.u64` unsigned, the number is in bits, and a bare `MOV` is `MOV.s64`; the machine\'s word is 16 bits, as the PDP-11\'s was. The suffix is the width and kind of the one move, not a different operation, and it is on every operand at once: `MOV.s8 (R1), R2` loads a byte and sign-extends it, and the same word with a register source converts. A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. `.u` zero-extends and exists for loads and for a register source; a store does not extend, so `MOV.u8 Rs, (Rn)` is accepted and is the store `MOV.s8 Rs, (Rn)`, and there is no 64-bit extension, so `MOV.u64` is `MOV`. A suffix on a move of a constant is refused, for a constant has no width. The address may be any address: a load or store that is not aligned to its size works ({{r:plain-access-at-any-address}}), which is how a packed structure or a network header is read. With a register operand the same opcodes are the conversion set: `MOV.s8 Rs, Rd` sign-extends the low byte of `Rs` into `Rd`, and `MOV.u8` zero-extends it. `MOV $imm, Rd` is one word for every size of constant: the assembler writes the two-, four- or six-byte form that holds it, and the ten-byte form (five parcels) when the constant needs 64 bits; the literal is inside the instruction, so the length is still known from parcel 0, and breaking the three-parcel rule for it is acceptable because a 64-bit literal is not counted as part of the instruction (`docs/encoding-proposal.md` section 3). `MOV.user` is the user-qualified move: user access is an attribute of one memory operand, so it cannot outlive the instruction, cannot leak across an interrupt, and `RTI` re-executes the instruction with the attribute. A kernel-mode data access to a user page that is not made with `MOV.user` is always a protection fault; in user mode `MOV.user` is a privileged-instruction abort, and its faults are those of the access as a user-mode access, with bit 15 of `ECAUSE` set to say that the access was user-qualified. A `.user` move needs a memory operand: between registers it is refused. The qualifier says whose access it is, not how wide, so it stands before the kind and the width, `MOV.user.u16`.',
      cf='{{r:page-table-entry}} for the memory type that decides whether the access is cached; {{r:faults-and-restart-what-precise-means}} for what a faulting access leaves behind; {{r:user-memory-guard-and-system-calls}} (the user-memory guard).'),
    E('LEA', 'moves', ['lea'], 'Load effective address',
      ['LEA d(Rn), Rd', 'LEA d(PC), Rd', 'LEA d(Rn)(Rx*s), Rd'],
      '''Rd <- EA(rm)          ; no memory access''',
      NOFLAGS, 'The operand must name memory; `len = 00` (a register) and the immediate mode are reserved. No memory access is made, so the instruction takes no memory fault. ' + ILL,
      notes='`LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. At `len = 10` it forms any address within ±2 GB of itself PC-relatively in six bytes. The base of every PC-relative displacement is the address of the first parcel of the instruction.'),
    E('ADD', 'alu', ['add'], 'Add', ['ADD rm, Rd'], 'Rd <- Rd + rm', NOFLAGS, MEMX,
      notes='All ALU operations are 64 bits, with no size field.'),
    E('SUB', 'alu', ['sub'], 'Subtract', ['SUB rm, Rd'], 'Rd <- Rd - rm', NOFLAGS, MEMX,
      notes=''),
    E('BIC', 'alu', ['bic'], 'Bit clear', ['BIC rm, Rd'], 'Rd <- Rd AND NOT rm', NOFLAGS, MEMX, notes='The assembler also accepts `BIC $imm, rm` as `AND $~imm, rm`.'),
    E('BIS', 'alu', ['bis'], 'Bit set (inclusive or)', ['BIS rm, Rd'], 'Rd <- Rd OR rm', NOFLAGS, MEMX),
    E('XOR', 'alu', ['xor'], 'Exclusive or', ['XOR rm, Rd'], 'Rd <- Rd XOR rm', NOFLAGS, MEMX),
    E('AND', 'alu', ['and'], 'And', ['AND rm, Rd'], 'Rd <- Rd AND rm', NOFLAGS, MEMX),
    E('MUL', 'alu', ['mul'], 'Multiply, low 64 bits', ['MUL rm, Rd'], 'Rd <- (Rd * rm)[63:0]         ; sign-agnostic', NOFLAGS, MEMX,
      notes="The low 64 bits of a two's-complement product are the same whether the operands are read as signed or unsigned, so there is one low-half multiply. The mnemonic `MUL.u64` is an alias of `MUL`. The high half is `MULH` (signed) and `MULH.u64` (unsigned)."),
    E('MULH', 'alu', ['mulh', 'mulhu'], 'Multiply, high 64 bits, signed and unsigned', ['MULH rm, Rd', 'MULH.u64 Ra, Rb, Rd      ; the unsigned high half (MULH.s64 is MULH)'], '''MULH:     Rd <- (sext(Rd) * sext(rm))[127:64]
MULH.u64: Rd <- (Ra * Rb)[127:64]        ; unsigned''', NOFLAGS, MEMX,
      notes='With `MULH`, division by a constant is a multiply by a reciprocal and a shift, which is what compilers emit. The kind is a suffix of the one word: `MULH.u64` is the unsigned high half, a three-register instruction of the arithmetic escape, and the bare `MULH` is the signed one. `MULHSU`, signed times unsigned for a bignum\'s top limb, is not an instruction: it is built from `MULH` with one correction.'),
    E('SHIFT', 'alu', ['shl', 'shr', 'sar'], 'Shift left, shift right logical, shift right arithmetic', ['SHL rm, Rd', 'SHR rm, Rd', 'SAR rm, Rd'],
      '''n <- rm                                 ; the count: a register, an immediate, or memory
SHL: Rd <- (n >= 64) ? 0 : Rd << n
SHR: Rd <- (n >= 64) ? 0 : Rd >>u n
SAR: Rd <- (n >= 64) ? (Rd < 0 ? -1 : 0) : Rd >>s n''',
      NOFLAGS, MEMX,
      notes='The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. `ASL` and `ASR` (in `SOP`) are the by-one forms in two bytes; rotates are in `BESC`.'),
    E('FADD', 'fp', ['fadd', 'fsub', 'fmul'], 'Floating add, subtract and multiply, binary64',
      ['FADD rm, Rd', 'FSUB rm, Rd', 'FMUL rm, Rd'], '''Rd <- Rd + rm   (FADD)
Rd <- Rd - rm   (FSUB)
Rd <- Rd * rm   (FMUL)       ; IEEE 754 binary64, round to nearest even''',
      'The IEEE exception flags raised are ORed into `FPSR`; no instruction traps.', MEMX + ' Floating-point exceptions never trap.',
      notes='Floating-point values live in the general registers; there is no separate register file and no mode bit. A NaN result is the canonical quiet NaN `0x7FF8000000000000`.'),
    E('ADDM', 'alu', ['addm', 'subm', 'bicm', 'bism'], 'ALU operation with a memory destination',
      ['ADDM Rs, rm', 'SUBM Rs, rm', 'BICM Rs, rm', 'BISM Rs, rm'],
      '''ADDM: M[EA] <- M[EA] + Rs
SUBM: M[EA] <- M[EA] - Rs
BICM: M[EA] <- M[EA] AND NOT Rs
BISM: M[EA] <- M[EA] OR Rs''',
      'As for `ADD`, `SUB`, `BIC` and `BIS`.', MEMX + ' Write permission is checked during the read access, so the write cannot fault after the read has succeeded.',
      notes='Parcel 0\'s low nibble is a mode, as in the ordinary memory format, so these are `MESC` forms with a memory destination (`len >= 01`). `INC`, `DEC`, `NEG`, `COM` and `CLR` on a memory operand are in `SOP`.'),

    E('BR', 'branches', ['br'], 'Branch',
      ['BR target'],
      '''PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None; a branch to an unmapped or non-executable address faults on the fetch of the target.',
      notes='The only branch that tests nothing: every conditional branch is a compare-and-branch (`CBCC`, `FCBCC`) or `SOB` or `BTAG`. The displacement counts 2-byte parcels; two bytes reach 1 KB, four bytes 64 KB, six bytes 16 MB, and the assembler chooses. `JMP label` is `BR label`.',
      cf='{{r:kernel-system-instructions-exceptions}} for `TRAP`, `RTI` and `RTT`.'),
    E('SOB', 'branches', ['sob'], 'Subtract one and branch', ['SOB Rn, target'],
      '''Rn <- Rn - 1
if Rn != 0 then PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None.', notes='From the PDP-11, where it could branch only backward; here the signed displacement goes either way. Four bytes at least.'),
    E('CBCC', 'branches', ['cbne', 'cbeq', 'cbcc', 'cbcs', 'cbge', 'cblt', 'cbgt', 'cble', 'cbhi', 'cblos'], 'Compare and branch on condition',
      ['CBLT Ra, Rb, target        ; two registers: branch if Ra < Rb (signed); the same for each condition',
       'CBLT Ra, $imm, target      ; a register and a signed immediate of at most 16 bits',
       'CBEQ Ra, $0, target        ; a register against zero: two bytes (CBEQ and CBNE)'],
      '''if (Ra compares by cc with (imm or Rb)) then PC <- address of this instruction + 2 * disp''',
      'None written.', 'None.',
      notes='The assembler chooses the shortest form that holds the operands and the distance. A register against zero (`CBEQ`, `CBNE`) is two bytes with a reach of 32 bytes; a register against zero, against a small immediate or against another register is four bytes (reaches from 256 bytes to 16 KB, by the widths of the immediate and of the register fields and by the condition); six bytes hold a 12-bit immediate with a reach of 64 KB, a 16-bit immediate with a reach of 4 KB, or two registers, any of the thirty-two, with a reach of 16 MB, for each of the ten conditions alike. There are ten conditions, the signed and unsigned orderings and equality; the machine has no condition codes, so there is no "plus", "minus" or "overflow" branch: a decision about a comparison is made by `CBGE` and `CBLT`, which cannot be wrong when a subtraction would overflow. A constant of more than 16 bits is loaded into a register first. A target that no form reaches (beyond 16 MB, or in another object file) is assembled as the opposite `cbCC` that branches over a `BR` to the target. `CBHIS` is `CBCC` and `CBLO` is `CBCS`. The letters `CC` of the family name stand for a condition; the mnemonic `CBCC` is the one condition higher-or-the-same (the PDP-11 name `BCC`, carry clear, with no carry kept).'),
    E('FCBCC', 'branches', ['fcbeq', 'fcbne', 'fcblt', 'fcble', 'fcbuo', 'fcbor', 'fcbeq32', 'fcbne32', 'fcblt32', 'fcble32', 'fcbuo32', 'fcbor32'],
      'Floating-point compare and branch', ['FCBLT Ra, Rb, target', 'FCBEQ Ra, Rb, target ... and the rest', 'FCBLT.f32 Ra, Rb, target    ; binary32; the bare FCBLT (or FCBLT.f64) is the double'],
      '''x <- Ra as binary64 (binary32 with the suffix .f32) ; y <- Rb the same
unordered <- x or y is a NaN
FCBEQ: taken if not unordered and x = y         FCBNE: taken if unordered or x != y
FCBLT: taken if not unordered and x < y         FCBLE: taken if not unordered and x <= y
FCBUO: taken if unordered                        FCBOR: taken if not unordered
if taken then PC <- address of this instruction + 2 * disp''',
      'None written. A signaling NaN operand sets the invalid flag of `FPSR`; a quiet one does not.', 'None.',
      notes='The two operands are registers; there is no immediate. `FCBGT` and `FCBGE` are assembler spellings: `FCBGT Ra, Rb, t` is `FCBLT Rb, Ra, t` and `FCBGE Ra, Rb, t` is `FCBLE Rb, Ra, t`, exact because a NaN makes both false. A comparison with a NaN is false for equal, less, less-or-equal, greater and greater-or-equal, and true for not-equal; the negation of a `FCBLT` is not `FCBGE` but a test that is true for the unordered case as well, which is why the unordered test has a word of its own. Four bytes for registers of the hot set with a target within 1,024 bytes, six bytes otherwise (a target within 4 MB); a farther target is refused. With the suffix `.f32` (`FCBLT.f32`) the comparison reads the low four bytes of each register as a binary32.'),
    E('BTAG', 'branches', ['btag', 'bntag'], 'Branch on pointer tag', ['BTAG Rn, $tag, target', 'BNTAG Rn, $tag, target'],
      '''BTAG : if (Rn & 111₂) == tag then PC <- address of this instruction + 2 * disp
BNTAG: if (Rn & 111₂) != tag then PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None.', notes='For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). Four bytes at least; the displacement is 16 bits (32 at `len = 10`). A pointer with the wrong tag is not caught by a fault, because a plain access works at any address ({{r:plain-access-at-any-address}}); the shortest correct check and access with a tag `T` and a field at offset `k` is `BNTAG Rn, $T, slow` followed by `MOV k-T(Rn), Rd` ({{r:a-mis-tagged-pointer-is-not-a-fault}}).'),

    E('CLR', 'single', ['clr'], 'Clear', ['CLR rm'], 'rm <- 0', NOFLAGS, MEMX),
    E('COM', 'single', ['com'], 'Complement', ['COM rm'], 'rm <- NOT rm', NOFLAGS, MEMX, notes='A two-byte instruction for a register operand.'),
    E('INC', 'single', ['inc'], 'Increment', ['INC rm'], 'rm <- rm + 1', NOFLAGS, MEMX),
    E('DEC', 'single', ['dec'], 'Decrement', ['DEC rm'], 'rm <- rm - 1', NOFLAGS, MEMX),
    E('NEG', 'single', ['neg'], 'Negate', ['NEG rm'], 'rm <- 0 - rm', NOFLAGS, MEMX),
    E('ASL', 'single', ['asl'], 'Arithmetic shift left by one', ['ASL rm'], 'C <- rm[63] ; rm <- rm << 1',
      NOFLAGS, MEMX, notes='The by-one form of `SHL` in two bytes.'),
    E('ASR', 'single', ['asr'], 'Arithmetic shift right by one', ['ASR rm'], 'C <- rm[0] ; rm <- rm >>s 1',
      NOFLAGS, MEMX, notes='The by-one form of `SAR` in two bytes.'),
    E('PUSHM', 'single', ['pushm'], 'Push registers by mask', ['PUSHM $mask        ; a 16-bit immediate, bit n is Rn'],
      '''for n = 0 to 15, if mask bit n:
    SP <- SP - 8 ; M[SP] <- Rn''',
      NOFLAGS, MEMX + ' A mask that includes `R14` (`SP`) is reserved.',
      notes='Four bytes (mode `0100`, immediate). The registers are pushed in ascending order, so `POPM` with the same mask restores them.', cf='{{r:faults-and-restart-what-precise-means}} for the restart rule.'),
    E('POPM', 'single', ['popm'], 'Pop registers by mask', ['POPM $mask'],
      '''for n = 15 down to 0, if mask bit n:
    Rn <- M[SP] ; SP <- SP + 8''',
      NOFLAGS, MEMX, notes='The mirror of `PUSHM`.'),
    E('JMP', 'single', ['jmp'], 'Jump', ['JMP rm        ; a register, or an address by any memory mode'],
      'PC <- (register operand) ? Rm : EA(rm)', NOFLAGS, 'A jump to an unmapped or non-executable address faults on the fetch of the target.',
      notes='A switch is a `CBHIS` against the limit, to the default, and a `JMP` through a scaled index. `JMP label` is `BR label`: the assembler writes the branch, which reaches as far and has a one-parcel form besides.'),
    E('CALL', 'single', ['call'], 'Call', ['CALL rm'],
      '''t <- (register operand) ? Rm : EA(rm)
SP <- SP - 8 ; M[SP] <- address of the next instruction
PC <- t''', NOFLAGS, MEMX, notes='The return address is on the data stack where every unwinder and debugger expects it. `RET` pops it.'),
    E('PUSH', 'single', ['push'], 'Push', ['PUSH rm'], 'v <- rm ; SP <- SP - 8 ; M[SP] <- v', NOFLAGS, MEMX, notes='A one-parcel instruction for a register operand.'),
    E('POP', 'single', ['pop'], 'Pop', ['POP rm'], 'v <- M[SP] ; SP <- SP + 8 ; rm <- v', NOFLAGS, MEMX),

    E('JMPI', 'branches', ['jmpi', 'calli'], 'Jump and call through memory',
      ['JMPI rm        ; PC <- M[EA]', 'CALLI rm       ; push the return address, then PC <- M[EA]'],
      '''JMPI : PC <- M[EA(rm)]
CALLI: t <- M[EA(rm)] ; SP <- SP - 8 ; M[SP] <- address of the next instruction ; PC <- t''',
      NOFLAGS, MEMX + ' For `CALLI` the order is specified: load the target, then push, then transfer; a fault on the load leaves nothing changed.',
      notes='The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand, so it is four bytes at least.'),
    E('JTAG', 'branches', ['jtag'], 'Jump through a tag table', ['JTAG d(Rb)(Rx*s)'],
      'PC <- M[Rb + d + 8 * (Rx & 111₂)]', NOFLAGS, MEMX,
      notes='Legal only with the scaled-index mode (`0001`). Dispatches on the low three bits of a tagged pointer through a table of eight entries; the 3-bit tag cannot index out of range.'),
]
