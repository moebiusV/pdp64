"""Dictionary entries, part 1: moves, the ALU, branches, single-operand and transfer instructions."""
from isa_common import *

ENTRIES = [
    E('MOV', 'moves', ['movq', 'movl', 'movw', 'movb'], 'Move, load and store (64, 32, 16 and 8 bits)',
      ['MOVQ rm, Rd        ; load', 'MOVQ Rs, rm        ; store', 'MOVL, MOVW, MOVB likewise'],
      '''size = 8 (MOVQ), 4 (MOVL), 2 (MOVW) or 1 (MOVB) bytes
load :  Rd <- sext(M[EA(rm)], size)          ; len = 00: Rd <- sext(Rs[8*size-1:0])
store:  M[EA(rm)] <- Rs[8*size-1:0]          ; len = 00: Rd <- sext(Rs[8*size-1:0])''',
      NOFLAGS + ' (Errata 39: moves, loads and stores write no flags.)', MEMX, '9.6',
      notes='A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. At `len = 00` the same opcodes are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`. Page 2 abbreviates the loads and stores through `(rn)`, at small offsets from `SP` and from a register, and `MOVQ #imm, rd` with a 4-bit immediate (see the page-2 table).',
      cf='6.4 for the memory type that decides whether the access is cached; 6.8 for what a faulting access leaves behind.'),
    E('MOVZ', 'moves', ['movzl', 'movzw', 'movzb'], 'Move zero-extended (32, 16 and 8 bits)',
      ['MOVZL rm, Rd', 'MOVZW rm, Rd', 'MOVZB rm, Rd'],
      '''Rd <- zext(M[EA(rm)], size)      ; len = 00: Rd <- zext(Rs[8*size-1:0])''',
      NOFLAGS, MEMX, '9.6', notes='There is no zero-extending 64-bit move (it would be `MOVQ`). At `len = 00` these are the zero-extending half of the conversion set.'),
    E('LEA', 'moves', ['lea'], 'Load effective address',
      ['LEA d(Rn), Rd', 'LEA d(PC), Rd', 'LEA d(Rn)(Rx*s), Rd'],
      '''Rd <- EA(rm)          ; no memory access''',
      NOFLAGS, 'The operand must name memory; `len = 00` (a register) and the immediate mode are reserved. No memory access is made, so the instruction takes no memory fault. ' + ILL, '9.6',
      notes='`LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. At `len = 10` it forms any address within ±2 GB of itself PC-relatively in six bytes. The base of every PC-relative displacement is the address of the first parcel of the instruction.'),
    E('MOVU', 'moves', ['movub', 'movuw', 'movul', 'movuq'], 'Unaligned load and store',
      ['MOVUQ rm, Rd        ; load, any alignment', 'MOVUQ Rs, rm        ; store, any alignment', 'MOVUW, MOVUL, MOVUB likewise'],
      '''size = 1, 2, 4 or 8 bytes
load :  Rd <- sext(M[EA(rm)], size)            ; the access may cross an alignment boundary
store:  M[EA(rm)] <- Rs[8*size-1:0]''',
      NOFLAGS, 'Page and protection faults and bus errors as for any memory operand; **no alignment fault**.', '9.6',
      notes='The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned, in `MESC`.',
      cf='6.4, 6.8.'),

    E('ADD', 'alu', ['add'], 'Add', ['ADD rm, Rd'], 'Rd <- Rd + rm', NZVC_ADD, MEMX, '9.7',
      notes='All ALU operations are 64 bits, with no size field. Page 2 has `ADD #imm, rd` with a 4-bit immediate and `ADD #(8*n), SP`.'),
    E('SUB', 'alu', ['sub'], 'Subtract', ['SUB rm, Rd'], 'Rd <- Rd - rm', NZVC_SUB, MEMX, '9.7',
      notes='Page 2 has `SUB #(8*n), SP`.'),
    E('CMP', 'alu', ['cmp'], 'Compare', ['CMP Rd, rm        ; register first'], 'tmp <- Rd - rm         ; the result is discarded', NZVC_SUB, MEMX, '9.7',
      notes='**The operands are in the order register, then the other operand**, the reverse of the PDP-11 `CMP src,dst`: `CMP Rd, rm` computes `Rd - rm`, so a compare of a register against an immediate or memory operand does not reverse its branch condition. After `CMP`, `BHIS`/`BCC` mean unsigned `>=` (no borrow) and `BLO`/`BCS` mean a borrow occurred.'),
    E('BIC', 'alu', ['bic'], 'Bit clear', ['BIC rm, Rd'], 'Rd <- Rd AND NOT rm', NZ0, MEMX, '9.8', notes='The assembler also accepts `BIC #imm, rm` as `AND #~imm, rm`.'),
    E('BIS', 'alu', ['bis'], 'Bit set (inclusive or)', ['BIS rm, Rd'], 'Rd <- Rd OR rm', NZ0, MEMX, '9.8'),
    E('BIT', 'alu', ['bit'], 'Bit test', ['BIT rm, Rd'], 'tmp <- Rd AND rm         ; the result is discarded', NZ0, MEMX, '9.8'),
    E('XOR', 'alu', ['xor'], 'Exclusive or', ['XOR rm, Rd'], 'Rd <- Rd XOR rm', NZ0, MEMX, '9.8'),
    E('AND', 'alu', ['and'], 'And', ['AND rm, Rd'], 'Rd <- Rd AND rm', NZ0, MEMX, '9.8'),
    E('MUL', 'alu', ['mul'], 'Multiply, low 64 bits', ['MUL rm, Rd'], 'Rd <- (Rd * rm)[63:0]         ; sign-agnostic', '`N` and `Z` from the result, `V` set when the signed 128-bit product does not fit in 64 bits, `C` unchanged.', MEMX, '9.7',
      notes="The low 64 bits of a two's-complement product are the same whether the operands are read as signed or unsigned, so there is one low-half multiply. The old mnemonic `MULU` is an alias of `MUL`. The high half is `MULH` (signed) and `MULHU` (unsigned)."),
    E('MULH', 'alu', ['mulh'], 'Multiply, high 64 bits, signed', ['MULH rm, Rd'], 'Rd <- (sext(Rd) * sext(rm))[127:64]', '`N` and `Z` from the result, `V` cleared, `C` unchanged.', MEMX, '9.7',
      notes='With `MULH`, division by a constant is a multiply by a reciprocal and a shift, which is what compilers emit.'),
    E('SHIFT', 'alu', ['shl', 'shr', 'sar'], 'Shift left, shift right logical, shift right arithmetic', ['SHL rm, Rd', 'SHR rm, Rd', 'SAR rm, Rd'],
      '''n <- rm                                 ; the count: a register, an immediate, or memory
SHL: Rd <- (n >= 64) ? 0 : Rd << n
SHR: Rd <- (n >= 64) ? 0 : Rd >>u n
SAR: Rd <- (n >= 64) ? (Rd < 0 ? -1 : 0) : Rd >>s n''',
      '`N` and `Z` from the result, `V` cleared, `C` the last bit shifted out (bit 63 for `SHL`, bit 0 for `SHR` and `SAR`). **The same flags are written for every count**: a count of zero gives `N` and `Z` from the unchanged operand, `V` = 0 and `C` = 0 (errata 39).', MEMX, '9.8',
      notes='The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Page 2 has the three shifts by an immediate 0 to 15. `ASL` and `ASR` (in `SOP`) are the by-one forms in two bytes; rotates are in `BESC`.'),
    E('FADD', 'fp', ['fadd', 'fsub', 'fmul'], 'Floating add, subtract and multiply, binary64',
      ['FADD rm, Rd', 'FSUB rm, Rd', 'FMUL rm, Rd'], '''Rd <- Rd + rm   (FADD)
Rd <- Rd - rm   (FSUB)
Rd <- Rd * rm   (FMUL)       ; IEEE 754 binary64, round to nearest even''',
      NOFLAGS + ' The five IEEE exception flags are ORed into `FPSR`; no instruction traps.', MEMX + ' Floating-point exceptions never trap.', '9.12',
      notes='Floating-point values live in the general registers; there is no separate register file and no mode bit. A NaN result is the canonical quiet NaN `0x7FF8000000000000`. The old spellings `FADDD`, `FSUBD`, `FMULD` are aliases.'),
    E('FCMP', 'fp', ['fcmp'], 'Floating compare, binary64', ['FCMP Rd, rm        ; register first'],
      '''N <- Rd < rm ; Z <- Rd == rm ; V <- unordered ; C <- 0''',
      '`N` set if `Rd < rm`, `Z` if equal, `V` if the operands are unordered (either is a NaN), `C` cleared. A signalling NaN raises `NV` in `FPSR`.', MEMX, '9.12',
      notes='The signed branches do not yet treat the unordered case cleanly (`BLT` after an unordered compare takes `N xor V` = 1); this is an open item of the instruction set.'),
    E('ADDM', 'alu', ['addm', 'subm', 'bicm', 'bism'], 'ALU operation with a memory destination',
      ['ADDM Rs, rm', 'SUBM Rs, rm', 'BICM Rs, rm', 'BISM Rs, rm'],
      '''ADDM: M[EA] <- M[EA] + Rs
SUBM: M[EA] <- M[EA] - Rs
BICM: M[EA] <- M[EA] AND NOT Rs
BISM: M[EA] <- M[EA] OR Rs''',
      'As for `ADD`, `SUB`, `BIC` and `BIS`.', MEMX + ' Write permission is checked during the read access, so the write cannot fault after the read has succeeded.', '9.6',
      notes='Parcel 0\'s low nibble is a mode, as in the ordinary memory format, so these are `MESC` forms with a memory destination (`len >= 01`). `INC`, `DEC`, `NEG`, `COM` and `CLR` on a memory operand are in `SOP`.'),

    E('BCC', 'branches', ['br', 'bne', 'beq', 'bpl', 'bmi', 'bvc', 'bvs', 'bcc', 'bcs', 'bge', 'blt', 'bgt', 'ble', 'bhi', 'blos'], 'Branch on condition',
      ['BR target', 'BNE target', 'BEQ target ... and the rest'],
      '''if cond(c) then PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None; a branch to an unmapped or non-executable address faults on the fetch of the target.', '9.10',
      notes='Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the branch reaches ±4 GB with no long-branch instruction.',
      cf='6.7 for `TRAP`, `RTI` and `RTT`.'),
    E('SOB', 'branches', ['sob'], 'Subtract one and branch', ['SOB Rn, target'],
      '''Rn <- Rn - 1
if Rn != 0 then PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None.', '9.10', notes='Restored from the PDP-11, where it could branch only backward; here the signed displacement goes either way. Four bytes at least.'),
    E('CBCC', 'branches', ['cbne', 'cbeq', 'cbpl', 'cbmi', 'cbvc', 'cbvs', 'cbcc', 'cbcs', 'cbge', 'cblt', 'cbgt', 'cble', 'cbhi', 'cblos'], 'Compare and branch on condition',
      ['CBNE Rd, #imm, target', 'CBEQ Ra, Rb, target ... and the rest'],
      '''tmp <- Rd - (imm or Rb)         ; as CMP, for the decision only
if cond(c) on that comparison then PC <- address of this instruction + 2 * disp''',
      '**None written** (errata 39): the instruction computes the comparison for its own decision and leaves `N Z V C` as they were.', 'None.', '9.10',
      notes='Three encodings, chosen by the assembler: `CBCC` (`101000 (0x28)`, a 5-bit signed immediate -16 to 15, a displacement of ±1024 parcels at four bytes or 27 bits at six), `CBW` (`101001 (0x29)`, a 16-bit immediate and a 16-bit displacement, six bytes) and `CBRR` (`101010 (0x2A)`, two registers, ±2,048 parcels at four bytes or 28 bits at six). There is no `len = 00` form. A target in another section is refused.'),
    E('BTAG', 'branches', ['btag', 'bntag'], 'Branch on pointer tag', ['BTAG Rn, #tag, target', 'BNTAG Rn, #tag, target'],
      '''BTAG : if (Rn & 7) == tag then PC <- address of this instruction + 2 * disp
BNTAG: if (Rn & 7) != tag then PC <- address of this instruction + 2 * disp''',
      NOFLAGS, 'None.', '9.10', notes='For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). Four bytes at least; the displacement is 16 bits (32 at `len = 10`).'),

    E('CLR', 'single', ['clr'], 'Clear', ['CLR rm'], 'rm <- 0', '`N` = 0, `Z` = 1, `V` = 0, `C` = 0.', MEMX, '9.8'),
    E('COM', 'single', ['com'], 'Complement', ['COM rm'], 'rm <- NOT rm', '`N` and `Z` from the result, `V` = 0, `C` = 1 (the PDP-11 rule).', MEMX, '9.8', notes='A two-byte instruction for a register operand.'),
    E('INC', 'single', ['inc'], 'Increment', ['INC rm'], 'rm <- rm + 1', '`N`, `Z` and `V` as for `ADD`; `C` **unchanged**.', MEMX, '9.7'),
    E('DEC', 'single', ['dec'], 'Decrement', ['DEC rm'], 'rm <- rm - 1', '`N`, `Z` and `V` as for `SUB`; `C` **unchanged**.', MEMX, '9.7'),
    E('NEG', 'single', ['neg'], 'Negate', ['NEG rm'], 'rm <- 0 - rm', NZVC_SUB + ' (`C` = 1 unless the operand was 0.)', MEMX, '9.7'),
    E('TST', 'single', ['tst'], 'Test', ['TST rm'], 'set flags from rm; nothing is written', '`N` and `Z` from the operand, `V` = 0, `C` = 0.', MEMX, '9.8'),
    E('ADC', 'single', ['adc'], 'Add carry', ['ADC rm'], 'rm <- rm + C', NZVC_ADD, MEMX, '9.7', notes='With `ADD`, multi-word addition.'),
    E('SBC', 'single', ['sbc'], 'Subtract carry', ['SBC rm'], 'rm <- rm - C', NZVC_SUB, MEMX, '9.7'),
    E('ASL', 'single', ['asl'], 'Arithmetic shift left by one', ['ASL rm'], 'C <- rm[63] ; rm <- rm << 1',
      '`N` and `Z` from the result, `C` the bit shifted out of bit 63, `V` = `N` xor `C` (set if the sign changed: the PDP-11 rule).', MEMX, '9.8', notes='The by-one form of `SHL` in two bytes.'),
    E('ASR', 'single', ['asr'], 'Arithmetic shift right by one', ['ASR rm'], 'C <- rm[0] ; rm <- rm >>s 1',
      '`N` and `Z` from the result, `C` the bit shifted out of bit 0, `V` = 0.', MEMX, '9.8', notes='The by-one form of `SAR` in two bytes.'),
    E('PUSHM', 'single', ['pushm'], 'Push registers by mask', ['PUSHM #mask        ; a 16-bit immediate, bit n is Rn'],
      '''for n = 0 to 15, if mask bit n:
    SP <- SP - 8 ; M[SP] <- Rn''',
      NOFLAGS, MEMX + ' A mask that includes `R14` (`SP`) is reserved.', '9.11',
      notes='Four bytes (mode `0100`, immediate). The registers are pushed in ascending order, so `POPM` with the same mask restores them. Page 2 has an 8-bit mask for `R8` to `R15`.', cf='6.8 for the restart rule.'),
    E('POPM', 'single', ['popm'], 'Pop registers by mask', ['POPM #mask'],
      '''for n = 15 down to 0, if mask bit n:
    Rn <- M[SP] ; SP <- SP + 8''',
      NOFLAGS, MEMX, '9.11', notes='The mirror of `PUSHM`; four bytes, with an 8-bit-mask form on page 2.'),
    E('JMP', 'single', ['jmp'], 'Jump', ['JMP rm        ; a register, or an address by any memory mode'],
      'PC <- (register operand) ? Rm : EA(rm)', NOFLAGS, 'A jump to an unmapped or non-executable address faults on the fetch of the target.', '9.10',
      notes='A switch is a `CMP` against the limit, a `BHIS` to the default and a `JMP` through a scaled index.'),
    E('CALL', 'single', ['call'], 'Call', ['CALL rm'],
      '''t <- (register operand) ? Rm : EA(rm)
SP <- SP - 8 ; M[SP] <- address of the next instruction
PC <- t''', NOFLAGS, MEMX, '9.10', notes='The return address is on the data stack where every unwinder and debugger expects it. `RET` pops it.'),
    E('PUSH', 'single', ['push'], 'Push', ['PUSH rm'], 'v <- rm ; SP <- SP - 8 ; M[SP] <- v', NOFLAGS, MEMX, '9.11', notes='A one-parcel instruction for a register operand.'),
    E('POP', 'single', ['pop'], 'Pop', ['POP rm'], 'v <- M[SP] ; SP <- SP + 8 ; rm <- v', NOFLAGS, MEMX, '9.11'),

    E('JMPI', 'branches', ['jmpi', 'calli'], 'Jump and call through memory',
      ['JMPI rm        ; PC <- M[EA]', 'CALLI rm       ; push the return address, then PC <- M[EA]'],
      '''JMPI : PC <- M[EA(rm)]
CALLI: t <- M[EA(rm)] ; SP <- SP - 8 ; M[SP] <- address of the next instruction ; PC <- t''',
      NOFLAGS, MEMX + ' For `CALLI` the order is specified: load the target, then push, then transfer; a fault on the load leaves nothing changed.', '9.10, 9.16',
      notes='The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand, so it is four bytes at least.'),
    E('JTAG', 'branches', ['jtag'], 'Jump through a tag table', ['JTAG d(Rb)(Rx*s)'],
      'PC <- M[Rb + d + 8 * (Rx & 7)]', NOFLAGS, MEMX, '9.10',
      notes='Legal only with the scaled-index mode (`0001`). Dispatches on the low three bits of a tagged pointer through a table of eight entries; the 3-bit tag cannot index out of range.'),
]
