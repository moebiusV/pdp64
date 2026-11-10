"""Dictionary entries, part 4: the instructions that only the prefix-coded CPUs (pdp64/16 and pdp64/32) have, the 70 words of group mn-ext of
spec/pdp64-enc.hbnf.  The encodings are not here: the entry shows the bit-layout charts that tools/mkmanual.py generates from the grammars.
Each entry says in its notes how firm its text is, with the manual's tags: (D) decided by the author, (P) proposed and not decided, (S) a stub."""
from isa_common import *

ONLY = ('16', '32')
CHECKV = ('The check vector is number 16 (`CHECK`) in `docs/study-proposals.md` item 9 and in the reference executor; `spec/pdp64-system.hbnf` has no vector of that name '
          'yet, so the number is *(P)*.')


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
      '9.10',
      notes='*(D)* One of the four fused pairs of errata 87: `MOVQ Rs, Rd` followed by `CALL target`, in one instruction. The target is a pc-relative field in parcels, measured from the first parcel of the fused instruction (errata 87, assumption 9); the instruction is two parcels (a 16-bit field) or three (a 32-bit field), and the linker grows it from its shortest form like a `CALL` (`docs/relaxation.md`). **The assembler never fuses**: the compiler writes `MOVCALL` where it wants it. An instruction that writes two registers (`Rd` and the stack pointer) and stores to memory is a two-micro-operation instruction for an out-of-order core (errata 87).',
      cf='9.5 (the pc-relative operand and the relaxation), 6.4 (restart after a fault).'),
    X('POPRET', 'branches', ['popret'], 'Pop a register and return', ['POPRET Rd'],
      '''Rd <- M[SP] ; SP <- SP + 8
PC <- M[SP] ; SP <- SP + 8''', NOFLAGS, MEMX, '9.10',
      notes='*(D)* `POP Rd` followed by `RET`, fused (errata 87). The register is the one the function restores last, usually a callee-saved register or the frame pointer. One parcel of 16 bits at pdp64/16 with the register in a 4-bit field; at pdp64/32 the 5-bit field makes the prefix one bit shorter.'),
    X('POPMRET', 'branches', ['popmret'], 'Pop several registers and return', ['POPMRET #mask'],
      '''for each bit i set in mask, highest register first:
    Ri <- M[SP] ; SP <- SP + 8
PC <- M[SP] ; SP <- SP + 8''', NOFLAGS, MEMX + ' A fault after some registers have been popped leaves them popped: the instruction restarts whole and pops them again, which is idempotent because the stack pointer is restored with the rest of the state at the start of the instruction.', '9.10',
      notes='*(D)* `POPM #mask` followed by `RET`, fused (errata 87): the epilogue of every function that saved registers with `PUSHM`. The mask is an 8-bit field scaled by 256, so the instruction names `R8` to `R15`; any other set of registers is `POPM` and `RET`. One parcel.'),
    X('MOV2', 'moves', ['mov2'], 'Two register moves', ['MOV2 Ra, Rb, Rc, Rd'],
      '''Rb <- Ra
Rd <- Rc           ; in this order''', NOFLAGS, NONE, '9.6',
      notes='*(D)* `MOVQ Ra, Rb` followed by `MOVQ Rc, Rd`, fused (errata 87). The four operands are 3-bit fields: only the eight hot registers (`R0 R1 R8 R2 SP R3 R9 R10`, the ABI table of the encoding) can be named, and the instruction takes one sixteenth of the first-parcel space, which is why the pdp64/16 and pdp64/32 grammars give it a prefix of four bits. If `Rb` is `Rc` the second move reads the new value, as two instructions would.',
      cf='Appendix D (the hot-register tables).'),
    # ---- selects
    X('MASK', 'alu', ['maskeqz', 'masknez'], 'Mask by a condition register', ['MASKEQZ Ra, Rc, Rd', 'MASKNEZ Ra, Rc, Rd'],
      '''MASKEQZ: Rd <- (Rc == 0) ? 0 : Ra
MASKNEZ: Rd <- (Rc != 0) ? 0 : Ra''', NOFLAGS, NONE, '9.7',
      notes='*(D)* Errata 85: the branch-free select is adopted. `Rc` is tested whole, all 64 bits, so any non-zero value is true; no flag is read or written, and the latency is fixed. `Rd` may be `Ra` or `Rc`. A constant-time select `d = c ? a : b` is `MASKEQZ a, c, t`, `MASKNEZ b, c, d`, `BIS t, d`. The semantics are those of LoongArch `maskeqz` and `masknez` and of RISC-V Zicond (the crypto proposal states this from memory). A flag-reading `CSEL` is not in the set (reserved, recommended only if the compiler work shows selects on comparisons matter).',
      cf='9.7 (SET), docs/crypto-secure-core.md section 2.'),
    X('BSEL', 'bits', ['bsel'], 'Bitwise select', ['BSEL Rm, Ra, Rb, Rd'],
      '''Rd <- (Rm AND Ra) OR (NOT Rm AND Rb)       ; bit by bit''', NOFLAGS, NONE, '9.9',
      notes='*(P)* In the crypto proposal (`docs/crypto-secure-core.md` section 3.2), marked "adopt" there and not separately confirmed by the author; the reference executor implements it. `Ch(e, f, g)` of SHA-2 is `BSEL e, f, g`; `Maj(a, b, c)` is `BSEL (a XOR b), c, b`; a mask-controlled swap of two registers is two `BSEL`. Three sources and a destination: the four register fields of the three-operand group.'),
    X('MOVQL', 'moves', ['movql'], 'Move a 64-bit literal', ['MOVQL #imm64, Rd'], 'Rd <- imm64', NOFLAGS, NONE, '9.6',
      notes='*(D)* Errata 85: `MOVQL #imm64, Rd` is accepted, and breaking the three-parcel rule for it is acceptable because a 64-bit literal is not counted as part of the instruction. The instruction is five parcels, ten bytes: the literal is inside the instruction, so the length is still known from parcel 0 and the fetch has no exception for a trailing literal (`docs/encoding-proposal.md` section 3). The assembler uses it for a `MOVQ #imm, Rd` that fits no `MOVQ` form (errata 87, assumption 6).'),
    # ---- checked arithmetic
    X('OVF', 'alu', ['addv', 'subv', 'mulv'], 'Add, subtract and multiply, trapping on signed overflow', ['ADDV Rs, Rd', 'SUBV Rs, Rd', 'MULV Rs, Rd'],
      '''t <- Rd op Rs                 ; op is +, - or ×, on signed 64-bit values
if t does not fit in 64 bits then abort at this instruction (vector CHECK), Rd unwritten
else Rd <- t''', 'None written.', 'Aborts with the `CHECK` vector on signed overflow, with `EPC` at the instruction and the destination unwritten; a blind restart faults again unless the handler changed an operand.', '9.7',
      notes='*(D)* Errata 85: `TRAPCC` with the fused `ADDV`, `SUBV` and `MULV` forms. The tables of the grammars hold the two-register form (`Rd <- Rd op Rs`, like `ADD`, `SUB`, `MUL`) and no immediate or memory form; `docs/study-proposals.md` item 9 writes a three-register form (`Rd <- Ra op Rb`), which no table has *(P)*. ' + CHECKV,
      cf='9.14 (TRAPCC), docs/study-proposals.md item 9.'),
    X('TRAPCC', 'system', ['trapcc.ne', 'trapcc.eq', 'trapcc.pl', 'trapcc.mi', 'trapcc.vc', 'trapcc.vs', 'trapcc.cc', 'trapcc.cs', 'trapcc.ge', 'trapcc.lt', 'trapcc.gt', 'trapcc.le', 'trapcc.hi', 'trapcc.los'],
      'Trap on condition', ['TRAPCC.cc          ; one word for each of the 14 conditions: TRAPCC.EQ, TRAPCC.VS, TRAPCC.HI ...'],
      '''if condition cc holds on the flags then take the CHECK trap
    EPC <- address of the next instruction ; EVA <- address of this instruction''', NOFLAGS,
      'The `CHECK` trap, when the condition holds. A *trap*, not an abort: the instruction completes, `EPC` is the next instruction, and `RTI` resumes after the check.', '9.14',
      notes='*(D)* Errata 85 and 86: `TRAPCC` is a trap and not an abort, there is no compare-and-trap form, and the fused `ADDV`, `SUBV` and `MULV` carry the register-only cases. There is one word for each of the 14 conditions, in two bytes with no operand: the condition numbers are those of the branches (`ne` 1 ... `los` 14; `al` is not a word). After `ADD` the check for signed overflow is `TRAPCC.VS` (`docs/study-proposals.md` item 9 calls it `ADD; TRAPV`). `EVA` is the address of the `TRAPCC` itself, the one trap that defines it, so a handler need not decode backwards from `EPC`. ' + CHECKV + ' The reference executor takes a trap that fires outside the kernel as the end of the program.',
      cf='6.4 (traps and aborts), docs/study-proposals.md item 9.'),
    # ---- deferred and user-qualified moves
    X('MOVD', 'moves', ['movq.d', 'movl.d', 'movw.d', 'movb.d', 'movzl.d', 'movzw.d', 'movzb.d'], 'Deferred-fault load', ['MOVQ.D d(Rn), Rd', 'MOVL.D ..., MOVW.D ..., MOVB.D ...', 'MOVZL.D ..., MOVZW.D ..., MOVZB.D ...'],
      '''Rd <- M[EA]                     ; as the load without .D, when the access succeeds
when the access faults: the fault is precise as always; the kernel's handler repairs the cause and restarts,
    or, if the access is invalid, marks Rd as poisoned in the saved state and goes on at the next instruction''',
      NOFLAGS, 'The ordinary faults of a load (page fault, protection fault, alignment fault, bus error), precise; what the handler does with them is the difference.', '9.6',
      notes='*(P)* The deferred-fault load is item 10 of `docs/study-proposals.md` (the poison bit); the author accepted its three leanings (errata 86: the fault is taken at the instruction that writes the flags from a poisoned source; the kernel decides a deferred load\'s fault; the kernel dispatcher, not the hardware, tests the argument registers for poison), but the poison bit itself is a proposal, so the semantics above are *(P)*. The proposal spells the load `MOVQ.S`; the grammars spell it `.D`. Base and indexed operands only (a mode that needs a base register needs `LEA` first). **Not implemented** in the reference executor: it traps as an unimplemented instruction.',
      cf='6.4, docs/study-proposals.md item 10.'),
    X('MOVUSER', 'moves', ['movq.u', 'movl.u', 'movw.u', 'movb.u', 'movzl.u', 'movzw.u', 'movzb.u'], 'User-qualified load and store', ['MOVQ.U d(Rn), Rd', 'MOVQ.U Rs, d(Rn)', 'MOVL.U ..., MOVW.U ..., MOVB.U ...', 'MOVZL.U ..., MOVZW.U ..., MOVZB.U ...    ; loads only'],
      '''the access of MOVQ, MOVL, MOVW, MOVB and MOVZ* with the operand checked as a user-mode access:
the page must be present, have U = 1, and permit R (a load) or W (a store); a kernel page takes the protection abort
whatever PSW.UA says''', NOFLAGS,
      'The faults of the access, as a user-mode access. In user mode the encoding is a privileged-instruction abort.', '9.6',
      notes='*(P)* Item 18 of `docs/study-proposals.md`: user access is an attribute of one memory operand, so it cannot outlive the instruction, cannot leak across an interrupt, and `RTI` re-executes the instruction with the attribute. The author accepted the five leanings (errata 86): a fixup table in place of `pcb_onfault`, the `.U` spelling, keeping `PSW.UA`, `STUA` and `CLUA` until the OpenBSD port confirms, `ECAUSE` bit 15 to say that the access was user-qualified, and the atomics taking the user form once the operand placement of `ATOM` is fixed. The proposal is not specified in full, so the text is *(P)*. (Not to be confused with `MOVU`, the unaligned move.) The reference executor runs a `.U` move as a plain move, because it has no MMU in that mode.',
      cf='6.10 (the user-memory guard), docs/study-proposals.md item 18.'),
    X('MOVUSERD', 'moves', ['movq.ud', 'movl.ud', 'movw.ud', 'movb.ud', 'movzl.ud', 'movzw.ud', 'movzb.ud'], 'User-qualified deferred-fault load', ['MOVQ.UD d(Rn), Rd', 'MOVL.UD ..., MOVW.UD ..., MOVB.UD ...', 'MOVZL.UD ..., MOVZW.UD ..., MOVZB.UD ...'],
      '''Rd <- M[EA], the access being both user-qualified (MOVU) and deferred (MOVD)''', NOFLAGS, 'The faults of `MOVU` and `MOVD` together.', '9.6',
      notes='*(P)* The combination of the two qualifiers. The repository defines each qualifier alone (items 10 and 18 of `docs/study-proposals.md`) and gives the combination no text of its own: a kernel that reads a user word without wanting to fail on it (a probe of a user pointer) is the case the combination serves, and its meaning is the composition. Loads only, base and indexed operands. **Not implemented** in the reference executor.'),
    # ---- AES
    X('AESR', 'bits', ['aeses', 'aesesm', 'aesds', 'aesdsm'], 'AES round on a 128-bit block in two registers', ['AESES Ra, Rb, Rd', 'AESESM Ra, Rb, Rd', 'AESDS Ra, Rb, Rd', 'AESDSM Ra, Rb, Rd'],
      '''the 16 bytes of the block are Rb:Ra (Ra holds bytes 0 to 7, columns 0 and 1; Rb bytes 8 to 15)
AESES  : ShiftRows, then SubBytes
AESESM : ShiftRows, SubBytes, then MixColumns
AESDS  : inverse ShiftRows, then inverse SubBytes
AESDSM : inverse ShiftRows, inverse SubBytes, then inverse MixColumns
Rd <- the 8 bytes of the new state that belong to columns 0 and 1; with Ra and Rb exchanged, columns 2 and 3''', NOFLAGS, NONE, '9.9',
      notes='*(P)* `docs/crypto-secure-core.md` section 3.2; the author approved the secure-core design and the select instructions (errata 86) and has not yet answered sections 3 to 5 of that document. Any two registers hold a block (no even-odd pairing): a round on one block is `AESESM Ra, Rb, T` and `AESESM Rb, Ra, Rb`, with the round key XORed by `XOR` with a memory operand. The latency is fixed and the instruction reads and writes no memory, so it has no cache-timing channel; the architecture does not say whether the S-box is a table inside the unit or a circuit. The definitions are those of FIPS 197 and must be checked against it before the text is final. **Not implemented** in the reference executor.',
      cf='docs/crypto-secure-core.md section 3.'),
    X('AESK', 'bits', ['aesks1', 'aesks2', 'aesim'], 'AES key schedule steps', ['AESKS1 Rs, #n, Rd', 'AESKS2 Ra, Rb, Rd', 'AESIM Rs, Rd'],
      '''AESKS1: Rd <- (SubWord(RotWord(Rs[63:32])) XOR rcon(n)), replicated in both halves   ; n = 10: no round constant (AES-256)
AESKS2: Rd[31:0] <- Ra[31:0] XOR Rb[63:32] ; Rd[63:32] <- Ra[63:32] XOR Rd[31:0]
AESIM : Rd <- InvMixColumns of the two columns in Rs         ; for the decryption key schedule''', NOFLAGS, NONE, '9.9',
      notes='*(P)* As `AESR`: `docs/crypto-secure-core.md` section 3.2, awaiting the author\'s answer. The key schedule of AES-128 takes three instructions per round. **Not implemented** in the reference executor.'),
    # ---- SHA
    X('SHA256', 'bits', ['sha256sig0', 'sha256sig1', 'sha256sum0', 'sha256sum1'], 'The SHA-256 functions', ['SHA256SIG0 Rs, Rd', 'SHA256SIG1 Rs, Rd', 'SHA256SUM0 Rs, Rd', 'SHA256SUM1 Rs, Rd'],
      '''on the low 32 bits x of Rs; the result is in the low 32 bits of Rd, the upper bits zero
SIG0: ror(x,7)  XOR ror(x,18) XOR shr(x,3)
SIG1: ror(x,17) XOR ror(x,19) XOR shr(x,10)
SUM0: ror(x,2)  XOR ror(x,13) XOR ror(x,22)
SUM1: ror(x,6)  XOR ror(x,11) XOR ror(x,25)''', NOFLAGS, NONE, '9.9',
      notes='*(P)* `docs/crypto-secure-core.md` section 3.2, awaiting the author\'s answer. The result is zero-extended there; every other 32-bit result of the machine is sign-extended (`RORI32`), so the choice is open. Rotations and three-input exclusive ors, one cycle in hardware, no data-dependent timing. **Not implemented** in the reference executor.'),
    X('SHA512', 'bits', ['sha512sig0', 'sha512sig1', 'sha512sum0', 'sha512sum1'], 'The SHA-512 functions', ['SHA512SIG0 Rs, Rd', 'SHA512SIG1 Rs, Rd', 'SHA512SUM0 Rs, Rd', 'SHA512SUM1 Rs, Rd'],
      '''on the 64 bits x of Rs
SIG0: ror(x,1)  XOR ror(x,8)  XOR shr(x,7)
SIG1: ror(x,19) XOR ror(x,61) XOR shr(x,6)
SUM0: ror(x,28) XOR ror(x,34) XOR ror(x,39)
SUM1: ror(x,14) XOR ror(x,18) XOR ror(x,41)''', NOFLAGS, NONE, '9.9',
      notes='*(P)* As `SHA256`. **Not implemented** in the reference executor.'),
    X('MSHA', 'block', ['msha256', 'msha512'], 'Hash whole blocks of memory', ['MSHA256 Rd, Rs, Rn', 'MSHA512 Rd, Rs, Rn'],
      '''hash the Rn bytes (whole blocks) at (Rs) into the state at (Rd)
progress is held in Rd, Rs and Rn; an interrupt or a fault restarts the instruction where it stopped''', NOFLAGS, MEMX, '9.11',
      notes='*(P)* Stage 2 of the crypto proposal (`docs/crypto-secure-core.md` section 3.4): the whole-buffer form, in the manner of the s390 CPACF instructions, to be built "only after measurement"; the grammars reserve its encoding. The unit would need about 2,000 look-up tables and 1,000 flip-flops (the proposal\'s estimate). **Not implemented** in the reference executor.'),
    X('MAESCTR', 'block', ['maesctr'], 'AES in counter mode over a buffer', ['MAESCTR Rd, Rs, Rn, Rp'],
      '''AES counter mode over the Rn bytes at (Rs), written at (Rd); the key, the counter and the number of rounds are in the parameter block at (Rp)
progress is held in the registers and the parameter block; an interrupt or a fault restarts the instruction where it stopped''', NOFLAGS, MEMX, '9.11',
      notes='*(P)* Stage 2, as `MSHA`; the layout of the parameter block is not specified. **Not implemented** in the reference executor.'),
    X('SYSPG', 'system', ['syspg0', 'syspg1', 'syspg2', 'syspg3', 'syspg4', 'syspg5'], 'Reserved system words', ['SYSPG0 ... SYSPG5'],
      '''none: the six words are reserved''', NOFLAGS, 'Not specified. The reference executor traps them as unimplemented instructions.', '9.14',
      notes='*(S)* Placeholders. The grammars reserve six system words for the page-bit mechanisms that the author approved to be specified (errata 84: landing pads gated by a page bit, the `SYS` page bit), which `docs/retire-stage-candidates.md` describes as needing no opcode; no text of the repository gives these words a meaning, and software must not use them.'),
]
