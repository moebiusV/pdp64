"""Dictionary entries, part 4: the instructions that only the prefix-coded encoding has, the 70 words of group mn-ext of
spec/grammars.d/22-enc-vocabulary.hbnf.  The encodings are not here: the entry shows the bit-layout charts that tools/mkmanual.py generates from the grammars.
An entry whose notes open with (P), a proposal that I have not accepted, or (S), a stub, is held back by isa_entries.HELD and is not printed in the manual; the entries of decided instructions are tagged (D)."""
from isa_common import *

ONLY = ('16', '32')


def X(*a, **k):
    e = E(*a, **k)
    e['only'] = ONLY
    return e


ENTRIES = [
    # ---- the four fused pairs
    X('MOVCALL', 'branches', ['movcall'], 'Move a register and call', ['MOVCALL Rs, Rd, target'],
      '''Rd <- Rs
SP <- SP - 8 ; M[SP] <- address of the next instruction
PC <- target''', NOFLAGS,
      'The store of the return address can fault (the memory faults of `CALL`): the instruction restarts whole, because the first half reads a register that the second half does not change.',
      notes='One of the four fused pairs: `MOVQ Rs, Rd` followed by `CALL target`, in one instruction. The target is a pc-relative field in parcels, measured from the first parcel of the fused instruction; the instruction is two parcels (a 16-bit field) or three (a 32-bit field), and the linker grows it from its shortest form like a `CALL` (`docs/relaxation.md`). **The assembler never fuses**: the compiler writes `MOVCALL` where it wants it. An instruction that writes two registers (`Rd` and the stack pointer) and stores to memory is a two-micro-operation instruction for an out-of-order core.',
      cf='{{r:addressing-modes}} (the pc-relative operand and the relaxation), {{r:faults-and-restart-what-precise-means}} (restart after a fault).'),
    X('POPRET', 'branches', ['popret'], 'Pop a register and return', ['POPRET Rd'],
      '''Rd <- M[SP] ; SP <- SP + 8
PC <- M[SP] ; SP <- SP + 8''', NOFLAGS, MEMX,
      notes='`POP Rd` followed by `RET`, fused. The register is the one the function restores last, usually a callee-saved register or the frame pointer. One parcel of 16 bits, with the register in a 5-bit field.'),
    X('POPMRET', 'branches', ['popmret'], 'Pop several registers and return', ['POPMRET #mask'],
      '''for each bit i set in mask, highest register first:
    Ri <- M[SP] ; SP <- SP + 8
PC <- M[SP] ; SP <- SP + 8''', NOFLAGS, MEMX + ' A fault after some registers have been popped leaves them popped: the instruction restarts whole and pops them again, which is idempotent because the stack pointer is restored with the rest of the state at the start of the instruction.',
      notes='`POPM #mask` followed by `RET`, fused: the epilogue of every function that saved registers with `PUSHM`. The mask is an 8-bit field scaled by 256, so the instruction names `R8` to `R15`; any other set of registers is `POPM` and `RET`. One parcel.'),
    X('MOV2', 'moves', ['mov2'], 'Two register moves', ['MOV2 Ra, Rb, Rc, Rd'],
      '''Rb <- Ra
Rd <- Rc           ; in this order''', NOFLAGS, NONE,
      notes='`MOVQ Ra, Rb` followed by `MOVQ Rc, Rd`, fused. The four operands are 3-bit fields: only the eight hot registers (`R0 R1 R8 R2 SP R3 R9 R10`, the ABI table of the encoding) can be named, and the instruction takes one sixteenth of the first-parcel space, which is why the grammar gives it a prefix of four bits. If `Rb` is `Rc` the second move reads the new value, as two instructions would.',
      cf='Appendix {{c:id03004|n}} (the hot-register tables).'),
    # ---- selects
    X('MASK', 'alu', ['maskeqz', 'masknez'], 'Mask by a condition register', ['MASKEQZ Ra, Rc, Rd', 'MASKNEZ Ra, Rc, Rd'],
      '''MASKEQZ: Rd <- (Rc == 0) ? 0 : Ra
MASKNEZ: Rd <- (Rc != 0) ? 0 : Ra''', NOFLAGS, NONE,
      notes='The branch-free select is adopted. `Rc` is tested whole, all 64 bits, so any non-zero value is true; no flag is read or written, and the latency is fixed. `Rd` may be `Ra` or `Rc`. A constant-time select `d = c ? a : b` is `MASKEQZ a, c, t`, `MASKNEZ b, c, d`, `BIS t, d`. The semantics are those of LoongArch `maskeqz` and `masknez` and of RISC-V Zicond (the crypto study states this from memory).',
      cf='{{r:integer-arithmetic}} (SET), docs/crypto-secure-core.md section 2.'),
    X('BSEL', 'bits', ['bsel'], 'Bitwise select', ['BSEL Rm, Ra, Rb, Rd'],
      '''Rd <- (Rm AND Ra) OR (NOT Rm AND Rb)       ; bit by bit''', NOFLAGS, NONE,
      notes='One of the select instructions of the secure-core design, which I approved (the select instructions "looks good"); it is one of the stage 1 words of `docs/crypto-secure-core.md` section 3. `Ch(e, f, g)` of SHA-2 is `BSEL e, f, g`; `Maj(a, b, c)` is `BSEL (a XOR b), c, b`; a mask-controlled swap of two registers is two `BSEL`. Three sources and a destination: the four register fields of the three-operand group.'),
    # ---- checked arithmetic
    X('OVF', 'alu', ['addv', 'subv', 'mulv'], 'Add, subtract and multiply, trapping on signed overflow', ['ADDV Rs, Rd', 'SUBV Rs, Rd', 'MULV Rs, Rd'],
      '''t <- Rd op Rs                 ; op is +, - or ×, on signed 64-bit values
if t does not fit in 64 bits then abort at this instruction (vector CHECK), Rd unwritten
else Rd <- t''', 'None written.', 'Aborts with the `CHECK` vector on signed overflow, with `EPC` at the instruction and the destination unwritten; a blind restart faults again unless the handler changed an operand.',
      notes='The fused add, subtract and multiply that check for overflow. The tables of the grammars hold the two-register form (`Rd <- Rd op Rs`, like `ADD`, `SUB`, `MUL`) and no immediate or memory form.',
      cf='{{r:isa-system-instructions-exceptions}} (the check words), docs/study-proposals.md item 9.'),
    X('CT', 'system', ['ctcc', 'ctcs', 'cthi', 'ctlos', 'cteq', 'ctne', 'ctge', 'ctlt', 'ctgt', 'ctle', 'ctpl', 'ctmi', 'ctvc', 'ctvs'],
      'Compare and trap', ['CT<cc> Rs, Rb', 'CT<cc> Rs, #imm12   ; CTCC, CTHI, CTEQ, CTNE only', 'CTEQ Rs  /  CTNE Rs   ; trap if zero, if not zero'],
      '''if Rs compared with the bound satisfies the condition cc then take the CHECK trap
    EPC <- address of this instruction''', NOFLAGS,
      'The `CHECK` trap (vector 16), when the condition holds. A fault: the instruction is annulled and `EPC` is its own address, so that the handler finds the site in the table of check sites (`__bug_table`) by address.',
      notes='The compare-and-trap of the run-time checks. The condition names are those of `CB<cc>`; `CTHIS` is `CTCC` and `CTLO` is `CTCS` as assembler aliases. `CTCC Ri, #n` traps when `Ri >= n` as an unsigned number, which is the check of an array index of length `n` (a negative index is a large unsigned number). The immediate form has 12 bits, zero-extended, for `CTCC`, `CTHI`, `CTEQ` and `CTNE`; the register form has all fourteen. `CTEQ Rs` and `CTNE Rs` with no bound are the trap-if-zero of the null check and the trap-if-not-zero of `BUG_ON`, one parcel. No flag is read or written. For every one the assembler writes a record into the section `__bug_table` (the 12-byte `struct bug_entry` of Linux with relative pointers: the address of the instruction, the file, the line, the flags with the kind of check in bits 5 to 7) from the directive `.chk KIND, "file", LINE`. The encodings are the prefix optimiser\'s.',
      cf='{{r:isa-system-instructions-exceptions}} (the check words), docs/encoding-work/check-instructions.md.'),
    X('CHK2', 'system', ['chk2'], 'Two-bound check', ['CHK2 Rs, Rlo, Rhi'],
      '''if not (Rlo <= Rs < Rhi), signed, then take the CHECK trap
    EPC <- address of this instruction''', NOFLAGS,
      'The `CHECK` trap (vector 16), unless the value is in the half-open range.',
      notes='The two-bound check, for an index whose lower bound is not zero (the Pascal and Ada subscript, a slice, `for i in lo..hi`). Signed, half-open (`Rlo <= Rs < Rhi`, as pcc\'s `__builtin_chk2` means); the bounds are registers. No flag is read or written; the record in `__bug_table` is as for `CT`.',
      cf='docs/encoding-work/check-instructions.md.'),
    # ---- user-qualified moves
    X('MOVUSER', 'moves', ['movq.u', 'movl.u', 'movw.u', 'movb.u', 'movzl.u', 'movzw.u', 'movzb.u'], 'User-qualified load and store', ['MOVQ.U d(Rn), Rd', 'MOVQ.U Rs, d(Rn)', 'MOVL.U ..., MOVW.U ..., MOVB.U ...', 'MOVZL.U ..., MOVZW.U ..., MOVZB.U ...    ; loads only'],
      '''the access of MOVQ, MOVL, MOVW, MOVB and MOVZ* with the operand checked as a user-mode access:
the page must be present, have U = 1, and permit R (a load) or W (a store); a kernel page takes the protection abort''', NOFLAGS,
      'The faults of the access, as a user-mode access. In user mode the encoding is a privileged-instruction abort.',
      notes='Item 18 of `docs/study-proposals.md`: user access is an attribute of one memory operand, so it cannot outlive the instruction, cannot leak across an interrupt, and `RTI` re-executes the instruction with the attribute. I accepted four of the five leanings: a fixup table in place of `pcb_onfault`, the `.U` spelling, `ECAUSE` bit 15 to say that the access was user-qualified, and the atomics taking the user form once the operand placement of `ATOM` is fixed; the fifth, keeping a status bit and two instructions beside `.U`, is gone, because one mechanism that cannot be left open is enough. A kernel-mode data access to a user page that is not `.U` is always a protection fault.',
      cf='{{r:user-memory-guard-and-system-calls}} (the user-memory guard), docs/study-proposals.md item 18.'),
    X('MCPYU', 'block', ['mcpy.ur', 'mcpy.uw'], 'User-qualified block copy', ['MCPY.UR Rd, Rs, Rn      ; the bytes read are user memory (copy-in)', 'MCPY.UW Rd, Rs, Rn      ; the bytes written are user memory (copy-out)'],
      '''as MCPY, with the accesses of one side checked as user-mode accesses:
MCPY.UR: each byte is read with the privilege of user mode (the page must be present, have U = 1 and permit R) and written as any kernel access is
MCPY.UW: each byte is read as any kernel access is and written with the privilege of user mode (the page must have U = 1 and permit W)''', NOFLAGS,
      'The faults of the accesses; a fault on the user side has bit 15 of `ECAUSE` set, as a `.U` move does. A plain `MCPY` of a user page is a protection fault.',
      notes='The block copy of a copy-in (`MCPY.UR`) and of a copy-out (`MCPY.UW`): the user-memory guard is always on, and these two words are how a kernel block-copies to or from user memory. The registers are updated as for `MCPY`, so a fault leaves them at the byte that failed. There is no form with both sides user (a copy from a user page to a user page is not a kernel job) and none for `MMOV`, `MSET` and `MCMP`: a fill of user memory is a copy from a zero buffer.',
      cf='{{r:user-memory-guard-and-system-calls}} (the user-memory guard).'),
    # ---- AES
    X('AESR', 'bits', ['aeses', 'aesesm', 'aesds', 'aesdsm'], 'AES round on a 128-bit block in two registers', ['AESES Ra, Rb, Rd', 'AESESM Ra, Rb, Rd', 'AESDS Ra, Rb, Rd', 'AESDSM Ra, Rb, Rd'],
      '''the 16 bytes of the block are Rb:Ra (Ra holds bytes 0 to 7, columns 0 and 1; Rb bytes 8 to 15)
AESES  : ShiftRows, then SubBytes
AESESM : ShiftRows, SubBytes, then MixColumns
AESDS  : inverse ShiftRows, then inverse SubBytes
AESDSM : inverse ShiftRows, inverse SubBytes, then inverse MixColumns
Rd <- the 8 bytes of the new state that belong to columns 0 and 1; with Ra and Rb exchanged, columns 2 and 3''', NOFLAGS, NONE,
      notes='I asked for constant-time AES and SHA instructions "or whichever opcodes would speed up and enable aes and sha" for the secure core and approved its design; the words are those of `docs/crypto-secure-core.md` section 3.2. Any two registers hold a block (no even-odd pairing): a round on one block is `AESESM Ra, Rb, T` and `AESESM Rb, Ra, Rb`, with the round key XORed by `XOR` with a memory operand. The latency is fixed and the instruction reads and writes no memory, so it has no cache-timing channel. The definitions are those of FIPS 197.',
      cf='docs/crypto-secure-core.md section 3.'),
    X('AESK', 'bits', ['aesks1', 'aesks2', 'aesim'], 'AES key schedule steps', ['AESKS1 Rs, #n, Rd', 'AESKS2 Ra, Rb, Rd', 'AESIM Rs, Rd'],
      '''AESKS1: Rd <- (SubWord(RotWord(Rs[63:32])) XOR rcon(n)), replicated in both halves   ; n = 10: no round constant (AES-256)
AESKS2: Rd[31:0] <- Ra[31:0] XOR Rb[63:32] ; Rd[63:32] <- Ra[63:32] XOR Rd[31:0]
AESIM : Rd <- InvMixColumns of the two columns in Rs         ; for the decryption key schedule''', NOFLAGS, NONE,
      notes='As `AESR`. The key schedule of AES-128 takes three instructions per round.'),
    # ---- SHA
    X('SHA256', 'bits', ['sha256sig0', 'sha256sig1', 'sha256sum0', 'sha256sum1'], 'The SHA-256 functions', ['SHA256SIG0 Rs, Rd', 'SHA256SIG1 Rs, Rd', 'SHA256SUM0 Rs, Rd', 'SHA256SUM1 Rs, Rd'],
      '''on the low 32 bits x of Rs; the result is in the low 32 bits of Rd, the upper bits zero
SIG0: ror(x,7)  XOR ror(x,18) XOR shr(x,3)
SIG1: ror(x,17) XOR ror(x,19) XOR shr(x,10)
SUM0: ror(x,2)  XOR ror(x,13) XOR ror(x,22)
SUM1: ror(x,6)  XOR ror(x,11) XOR ror(x,25)''', NOFLAGS, NONE,
      notes='As `AESR`. Rotations and three-input exclusive ors, one cycle in hardware, no data-dependent timing.'),
    X('SHA512', 'bits', ['sha512sig0', 'sha512sig1', 'sha512sum0', 'sha512sum1'], 'The SHA-512 functions', ['SHA512SIG0 Rs, Rd', 'SHA512SIG1 Rs, Rd', 'SHA512SUM0 Rs, Rd', 'SHA512SUM1 Rs, Rd'],
      '''on the 64 bits x of Rs
SIG0: ror(x,1)  XOR ror(x,8)  XOR shr(x,7)
SIG1: ror(x,19) XOR ror(x,61) XOR shr(x,6)
SUM0: ror(x,28) XOR ror(x,34) XOR ror(x,39)
SUM1: ror(x,14) XOR ror(x,18) XOR ror(x,41)''', NOFLAGS, NONE,
      notes='As `SHA256`. The definitions are those of FIPS 180-4.'),
    X('MSHA', 'block', ['msha256', 'msha512'], 'Hash whole blocks of memory', ['MSHA256 Rd, Rs, Rn', 'MSHA512 Rd, Rs, Rn'],
      '''hash the Rn bytes (whole blocks) at (Rs) into the state at (Rd)
progress is held in Rd, Rs and Rn; an interrupt or a fault restarts the instruction where it stopped''', NOFLAGS, MEMX,
      notes='*(P)* Stage 2 of the crypto proposal (`docs/crypto-secure-core.md` section 3.4): the whole-buffer form, in the manner of the s390 CPACF instructions, to be built "only after measurement"; the grammars reserve its encoding. The unit would need about 2,000 look-up tables and 1,000 flip-flops (the proposal\'s estimate). **Not implemented** in the reference executor.'),
    X('MAESCTR', 'block', ['maesctr'], 'AES in counter mode over a buffer', ['MAESCTR Rd, Rs, Rn, Rp'],
      '''AES counter mode over the Rn bytes at (Rs), written at (Rd); the key, the counter and the number of rounds are in the parameter block at (Rp)
progress is held in the registers and the parameter block; an interrupt or a fault restarts the instruction where it stopped''', NOFLAGS, MEMX,
      notes='*(P)* Stage 2, as `MSHA`; the layout of the parameter block is not specified. **Not implemented** in the reference executor.'),
]
