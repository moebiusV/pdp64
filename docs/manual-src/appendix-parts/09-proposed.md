**9.3.9** (moved from chapter 9) `R16` to `R31` in the ABI: the compiler saves `R24` to `R31` in the callee and treats `R16` to `R23` as clobbered by a call. The ABI documents call this split a draft; it is built into the compiler and the runtime of the six large programs. *(P)*

**9.20.4** (moved from chapter 9) Under consideration: separate floating-point condition flags, software-visible translation-buffer manipulation (to pin an entry for a real-time kernel). *(P)* The floating-point condition flags and the conditional select are open items now (J.9.9, J.9.1); the translation-buffer manipulation is only a proposal: an instruction that pins one translation so that a real-time kernel's interrupt path never takes a miss.

**9.2 commentary** (moved from chapter 9) Whether the extension instruction after some narrow operations costs enough to justify 32-bit forms of add and subtract is a proposal that the compiled corpus can answer; it is the proposal of appendix A.9. *(P)*

**9.18 commentary** (moved from chapter 9) A bounds-checked `INDEX` instruction for Pascal and Ada is a possible addition. *(P)*

**9.21.3** (moved from chapter 9) Not decided in the encodings: the combination `.ud` of the two load qualifiers, the stage 2 whole-buffer hash and cipher words (`MSHA256`, `MSHA512`, `MAESCTR`), and a profile-tuned variant of the encoding (not tried). In the compiler: the use of `MOVUW`, `MOVUL` and `MOVUQ`, division by 64-bit constants, loop-invariant motion and live-range splitting. *(P)*


### The instruction entries held back from chapter 9 (moved from the dictionary of chapter 9)

The entries below were in the instruction chapter, in the section named at the end of each entry. They describe instructions that the grammar of the encoding carries and that the author has not decided: each is tagged *(P)*. (The words the author did decide, with their details pending, are back in the chapter: `BSEL`, the deferred-fault and user-qualified moves, and the AES and SHA words.) The bit layouts are in the grammars `spec/pdp64-enc.hbnf` and `spec/pdp64-32/pdp64-32.hbnf`; the charts are not reproduced.

#### MOVUSERD: User-qualified deferred-fault load

**Mnemonics:** `MOVQ.UD`, `MOVL.UD`, `MOVW.UD`, `MOVB.UD`, `MOVZL.UD`, `MOVZW.UD`, `MOVZB.UD` (section 9.6 of the instruction chapter)

**Syntax**

```
MOVQ.UD d(Rn), Rd
MOVL.UD ..., MOVW.UD ..., MOVB.UD ...
MOVZL.UD ..., MOVZW.UD ..., MOVZB.UD ...
```

**Operation**

```
Rd <- M[EA], the access being both user-qualified (MOVU) and deferred (MOVD)
```

**Flags** None written.

**Exceptions** The faults of `MOVU` and `MOVD` together.

*(P)* The combination of the two qualifiers. The repository defines each qualifier alone (items 10 and 18 of `docs/study-proposals.md`) and gives the combination no text of its own: a kernel that reads a user word without wanting to fail on it (a probe of a user pointer) is the case the combination serves, and its meaning is the composition. Loads only, base and indexed operands.

**Why it is here.** See `MOVD` and `MOVUSER`. The record gives no separate reason for the combination; it is listed because both qualifiers exist and a probe of a user pointer wants both.

#### MSHA: Hash whole blocks of memory

**Mnemonics:** `MSHA256`, `MSHA512` (section 9.11 of the instruction chapter)

**Syntax**

```
MSHA256 Rd, Rs, Rn
MSHA512 Rd, Rs, Rn
```

**Operation**

```
hash the Rn bytes (whole blocks) at (Rs) into the state at (Rd)
progress is held in Rd, Rs and Rn; an interrupt or a fault restarts the instruction where it stopped
```

**Flags** None written.

**Exceptions** Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.

*(P)* Stage 2 of the crypto proposal (`docs/crypto-secure-core.md` section 3.4): the whole-buffer form, in the manner of the s390 CPACF instructions, to be built "only after measurement"; the grammars reserve its encoding. The unit would need about 2,000 look-up tables and 1,000 flip-flops (the proposal's estimate).

**Why it is here.** Stage 2 of the crypto proposal, in the manner of the s390 CPACF instructions (`KIMD` and kin): one instruction hashes a buffer, the padding and chaining are done in hardware and so cannot be got wrong, and progress is held in registers, so a fault or an interrupt restarts it, as for `MCPY`. The estimate is 64 cycles for a 64-byte SHA-256 block against about 1,200 instructions, roughly 18 times; the cost is gates in proportion to the algorithms frozen into opcodes. The proposal says to build `MSHA256` first and the others only after measurement, and the author has not decided it.

#### MAESCTR: AES in counter mode over a buffer

**Mnemonics:** `MAESCTR`

**Syntax**

```
MAESCTR Rd, Rs, Rn, Rp
```

**Operation**

```
AES counter mode over the Rn bytes at (Rs), written at (Rd); the key, the counter and the number of rounds are in the parameter block at (Rp)
progress is held in the registers and the parameter block; an interrupt or a fault restarts the instruction where it stopped
```

**Flags** None written.

**Exceptions** As `MSHA`.

*(P)* Stage 2, as `MSHA`; the layout of the parameter block is not specified.

**Why it is here.** Stage 2, as `MSHA`; whole-buffer AES gains less (about 4 times: 0.6 against 2.6 instructions per byte), because the round instructions are already good, and the proposal puts it after `MSHA256` and `MSHA512`.
