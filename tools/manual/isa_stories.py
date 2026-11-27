"""The "Why it is here" paragraph of each non-common instruction: the machine the idea came from and the reason it is in the
instruction set, with the measurements that bear on it.  A common instruction (a move, an add, a branch: the instructions every
architecture has, and the PDP-11 core the machine started from) has no story and no entry here.
Where no reason is recorded, the text says so instead of supplying one."""

STORY = {
'LEA': "The PDP-11 and the VAX made the program counter a register (R7, R15). Here the program counter is kept out of the register file, because every register write would then be a potential branch, and a read-only view of it (R7 as a view of the PC) is refused, because it would fix for ever *which* PC is meant (ARM32 is stuck with `PC+8`). `LEA 0(PC), Rn` gives the capability without the commitment: the address of the instruction itself, in one instruction. The same instruction forms any address PC-relatively, which is what makes position-independent code free (section {{r:position-independent-code}}).",

'MOV': "A 64-bit constant otherwise comes from the literal pool. I accepted the literal inside the instruction in the second round of security answers: it is one instruction, and it is not counted against the three-parcel rule because it is data, not instruction. The encoding work found no use of a trailing literal worth its exception to the fetch rule, so the literal is part of a five-parcel instruction (`docs/encoding-proposal.md` section 3). The mnemonic does not say how long the instruction is: `MOV $imm, Rd` is the one word for every constant, and the assembler picks the two-, four-, six- or ten-byte form. Data at any address is read and written by the plain moves: I merged the four explicit unaligned forms `MOVUB` to `MOVUQ` into them on 2026-11-25, with a hardware guarantee in place of four opcodes: a plain load or store works at any address, and a page crossing is precise on either page and changes nothing when it faults. The alignment fault had been the one trap of an ordinary access, and it had been useful as a free tag check of tagged pointers; the explicit tag branches are the check now. ARM and x86 do the same (*unverified*); RISC-V leaves it to the implementation, which is the opposite of one binary for every core, so it is not the precedent. Copying between the kernel and the user is where kernels pay for the user-memory guard. x86 opens a window with `STAC` and closes it with `CLAC` (35 and 53 sites in the kernel-assembly corpus), and a forgotten `CLAC` on an error path is the bug class; Arm's `LDTR` and `STTR` make the access itself unprivileged (52 sites), but only for plain loads and stores. Item 18 of the study makes user access an attribute of one operand, so that no window exists to leave open and the range check of the copy routines (`addr + len` against the top of the user half) disappears into the hardware: a kernel address faults at the first byte. I accepted four of its five leanings; the fifth, keeping `PSW.UA`, `STUA` and `CLUA` beside the new qualifier, I gave up on 2026-11-25: one mechanism is enough, and it is the one that cannot be left open.",

'ADDM': "These are the read-modify-write forms with a memory destination. An instruction with a memory destination is at least four bytes anyway, so they live in `MESC` at no cost; the opcode map follows one rule, that a top-level opcode is for an operation whose common case is register to register. They cover the case where the second operand is a register, for example `BISM Rmask, flags(DP)`. The compiled corpus has 265 sites (1.6 KB), so they earn their place in the escape group but not in the opcode space.",

'MULH': "The low 64 bits of a two's-complement product are identical signed or unsigned, so a second multiply (`MUL.u64`) would duplicate `MUL`; what the architecture needs in that place is the *high* half of the product. Without it a 64 by 64 to 128-bit multiply, every bignum multiply, 128-bit fixed point and divide-by-a-constant by multiplying by the reciprocal are impossible. `MULH` is that instruction. It is also why a divide is rare in compiled code: compilers turn division by a constant into `MULH` and a shift.",


'ABS': "Integer absolute value is the counterpart of `FABS`. A mnemonic is cheap and the idiom is easy to get wrong (the most negative number has no positive twin, and a branch makes the time depend on the data), so the assembler writes the sequence and the programmer writes the word. I gave it no instruction of its own: the sequence uses only words the machine has, and the compiled corpus has too few uses of it, under 0.1% of code, to pay for an opcode.",

'MINMAX': "The integer counterparts of `FMIN` and `FMAX`, provided with `ABS`. The compare, the mask and the select that make them are words the machine has for other reasons (`SETCC`, `NEG`, `BSEL`), so they are assembler aliases and no new opcode; the sequence has no branch, which keeps the time independent of the values. The corpus has 171 uses of `MIN` and 52 of `MAX` across 95 files, under 0.1% of code in all.",

'SETCC': "A comparison used as a value, with the condition in the word's name instead of a condition register: one instruction writes 0 or 1 into a register from a comparison of two registers or of a register and a small constant, for the ten conditions that the compare-and-branch has. A comparison in the compiled corpus is a compare-and-branch nine times in ten, and the rest is this instruction. It also gives the carry of an addition without a carry flag (`ADD Rb, Ra` then `SETLO Ra, Rb, Rt`), which is why the machine has no `ADC`.",
'FCBCC': "The floating-point partner of `CBCC`: one instruction compares two registers and branches, and nothing is written. The unordered case has words of its own (`FCBUO`, `FCBOR`) because the negation of \"less than\" is not \"greater than or equal\" when an operand is a NaN, so a branch cannot be inverted by changing its condition; the greater-than words are the less-than words with the operands exchanged.",

'FSINGLE': "`binary64` has first-class opcodes because on a 64-bit machine it is the common case; `binary32` is in `FESC` with the same operations, held in the low 32 bits of a register and sign-extended like every other 32-bit value (see also the ABI). The naming rule is an `F` in front of the integer mnemonic (`FADD`) and a size suffix for the other format (`FADD.f32`).",

'FMADD': "The whole fused multiply-add family is in `FESC`, because its absence would be the single worst gap in the floating-point set: one rounding instead of two, and the inner step of dot products, polynomial evaluation and every matrix kernel. `FESC` gives it four register operands. It replaces the VAX `POLY`, which was the best answer before fused multiply-add.",

'FMADD32': "The `binary32` forms of the fused multiply-add family.",

'FSIGN': "Sign and selection operations (negate, absolute value and the like) work on the bits, do not canonicalise a NaN and raise no exception flag, so they cost almost nothing. The PowerPC 601 floating-point set has the same operations (stated from memory, not checked against a manual). No separate reason is recorded for these three.",

'FMIN': "The floating counterparts of the integer `MIN` and `MAX`. A NaN operand loses to a number and two NaNs give the canonical quiet NaN.",

'FCLASS': "Every libm function begins with this dispatch: one instruction returns which of ten kinds a value is (signalling or quiet NaN, infinity, normal, subnormal, zero, each signed), where software needs several compares and masks. It is justified by a workload, library mathematics, and not by compiled C, as the tag branches are. Nothing in the corpus emits it, because the compiler does not use it.",

'FRINT': "Rounding to an integral value in each direction (nearest even, toward zero, down, up) is in the set, and `FRINTA`, ties away from zero, serves C's `round()`, which is common in libm; it is a qualifier of the round operation and so costs no new operation.",

'FCVT': "`FCVT.f64.u64` and `FCVT.u64.f64` convert unsigned 64-bit integers to and from `binary64`. C needs both, and without them each takes a branch and several instructions. Half precision began as a GPU format (NVIDIA's `half`, 2002), spread to machine learning and image formats, and is in CPUs (x86 `F16C` and AVX-512 FP16, ARMv8.2, RISC-V `Zfh` and `Zfhmin`); this account is from memory and not checked against a manual. The architecture has the conversions only, as RISC-V's `Zfhmin` and x86's `F16C` have: a half is a storage format, normally loaded and stored with a move with the mark `.16`, converted, computed in single or double, and converted back, and a core without half-width adders, multipliers and dividers has fewer units to build and to verify. The full arithmetic (add, subtract, multiply, divide, square root, compare, classify and four fused multiply-adds, eleven words) was removed on 2026-11-25: the double rounding through `binary32` is exact for the five basic operations, so the two instructions it costs give the same results. 16-bit *integer* arithmetic is not provided: the ALU has one width ({{r:alu-has-one-width-64}}).",

'FSFLAGS': "IEEE 754 requires five status flags, and C99 `<fenv.h>` needs software access to them. The architecture has a sticky five-bit `FPSR`, laid out as RISC-V's `fflags`, written by every operation that can raise a flag and never trapping, and one swap instruction to read and write it. It is a record of what happened, not a mode, so the rule against mode bits is untouched.",



'COUNT': "`BESC` is the bit-manipulation group: bit manipulation is not an extension on a machine that does filesystem work, bignum arithmetic and the like. The counts are the VAX `FFS` and `FFC` idiom (find first set, find first clear). LoongArch is the model for putting them in the base: it has `CLO`, `CLZ`, `CTO`, `CTZ` there, which is the decisive argument for giving `BESC` a top-level opcode. The compiler emits none of them, since C has no operator for them; the corpus shows zero uses.",

'POPCNT': "One of the counts of `BESC`; it is also the building block of `XNORPOP`. A compiler needs `__builtin_popcount` to emit it, so the corpus shows no use (see `COUNT`).",

'BSWAP': "The PDP-11 `SWAB` swapped the bytes of a word; `BSWAP` generalises it to 64 bits, with word and long variants. `SWAB` is therefore subsumed, not lost ({{r:idioms-restored-lost-and-replaced}}).",

'BITREV': "Part of the `BESC` group, borrowed with the other LoongArch bit operations (`REVB`, `REVH`, `BITREV`). No workload from the corpus is recorded.",

'ROR': "One rotate direction suffices and `ROR` is the one to keep, and `ROL` is the same rotate with the count complemented, an assembler mapping (the count of `ROR` is taken modulo 64, so only a constant count maps to one instruction): the assembler takes a register or a constant after one word, as it does for the shifts, and the two-byte form carries a signed count of four bits, so that the rotate left by 1 to 8 and the rotate right by 1 to 7 are two bytes. No rotate is through carry (see `DSHR`). `ROR` is in `BESC`, not the ALU group: cryptographic code rotates by compile-time constants, so an immediate form is needed either way, and the register-count form has almost no users. A 32-bit rotate by a constant, the shape of crypto and hash inner loops, estimated together with `CBCC` at 22 KB (1.3%) of the compiled image. The result is sign-extended like the rest of the 32-bit operations, so that no instruction is needed after it. It removes 44 32-bit moves in the corpus (the demand analysis already removes nearly all of them).",


'DSHR': "A double-width funnel shift (x86 `SHRD`, ARM `EXTR`), the right primitive for multi-word shifting. Two instructions shift a 128-bit value by any distance, where rotate-through-carry takes one bit per instruction, and that is why no rotate is through carry. It also subsumes `ROR` when both sources are the same register.",

'EXTB': "Bit-field extract and insert are the VAX `EXTV`, `EXTZV` and `INSV` idiom. The compiler does not use them: the shift-pair extraction pattern occurs 151 times in 26 files of the corpus, about 600 bytes at best (0.03%), and there are four true bit-field extracts in all. They are for hand-written protocol and bit-stream code.",

'INSB': "The VAX `INSV` idiom, with `EXTB`. No use in the compiled corpus is recorded.",

'XNORPOP': "It serves binary-activation networks, Hamming distance, bitset intersection counts and counting a collector's mark bitmap. It does not serve sub-1-bit language models: their activations (in the LittleBit work) are FP16 and the inner loop is a conditional add, not a popcount. The sub-1-bit kernel is bandwidth-bound and belongs to a bus-mastering accelerator, not an opcode (chapter {{c:id01008|n}}).",

'CLMUL': "Carry-less multiply is the primitive beneath every CRC polynomial (a CRC is a carry-less multiply plus a Barrett reduction), GF(2^k) erasure codes and AES-GCM. It is chosen over a `CRC` instruction because x86 and ARM each committed a polynomial to the architecture; there are no `CRC32` or `CRC32C` words.",

'UTF8LEN': "Most of what UTF-8 needs is general bit manipulation, but the validity rules are where the bugs are, so the group has three instructions. `UTF8LEN` is the one that is nearly free: `CLO` on the leading byte, mapped to 1, 2, 3 or 4.",

'UTF8DEC': "Not for speed but for correctness: overlong forms, surrogates, values above U+10FFFF and the bytes that can never begin a sequence are each a historical security hole, each is three comparators in hardware, and software implementations get them wrong or omit them for speed (about 300 lookup tables).",

'UTF8ENC': "The encoding half of the UTF-8 pair; it refuses surrogates and values above U+10FFFF so that an encoder cannot produce what a decoder must reject.",

'MCPY': "The block operations are the one granted exception to the one-memory-operand rule (an exception to a principle is allowed where there is a clear benefit), made safe by keeping the progress in architectural registers: the VAX `MOVC5` kept it in hidden microstate, which is why it is rejected, and ARM reached the same design in 2022 with `FEAT_MOPS`. The names `MCPY`, `MMOV` and `MSET` follow the memory operations of IBM System z; `MCMP` and `MSCN` complete the set. `MCPY` replaces the PDP-11 `MOV (R1)+,(R2)+` loop, and the `rep movsb` of x86, with one restartable instruction.",

'MSET': "With a zero value it is the range-zeroing instruction, so `bzero` and the clearing of `calloc` need no separate opcode.",

'MCMP': "Seven of the VAX's ten character-string instructions are present (`MOVC3`, `CMPC3`, `LOCC` and `SKPC` among them); the rejected ones are `EDITPC` and packed decimal. `MCMP` is the `CMPC3` equivalent.",

'MSCN': "`MSCN` is `LOCC` and `memchr`; `MSCNN` fills the `SKPC` gap (the first byte that is *not* equal). Both cost no opcode and almost no hardware. With an explicit count `MSCN` gives `strnlen`, and with `MCPY` a bounded `strcpy` in two instructions. NUL-terminated string instructions (the System/z `MVST`, `SRST`, `CLST`) are rejected, because they encode an unbounded read, the largest single source of memory-safety failures in C ({{r:what-was-rejected}}).",

'MVAL': "The UTF-8 validity comparators already built for `UTF8DEC`, wired to the `MBLK` streaming sequencer already built for `MCPY`, so it costs no opcode and almost no hardware. The alternative, a SWAR loop (SIMD within a register), runs at about two to three cycles a byte and is respectable, which is why the justification is cost and not throughput.",

'SOB': "Taken from the PDP-11, at the branch group's one free opcode. The PDP-11's could only branch backward (a 6-bit unsigned displacement); this one branches either way. Against the `cbnz` idiom of other architectures it does not save bytes (`DEC` plus `BNE` is also four) but it saves an instruction issue, a cycle per iteration on a machine that does not pipeline: same size, one instruction fewer (static `dec; bne` pairs exist).",

'CBCC': "A fused compare-and-branch, estimated with the 32-bit rotate at 22 KB (1.3%) of the image. The wide-immediate form removes 11,735 instructions (3.4%) and 1,828 bytes; the register-register compare-and-branch removes 4,631 instructions (1.4%) and 142 bytes. It needs a comparator in the branch unit (548 gates of logic) and a third read port, and it is the only integer conditional branch of the machine: leaving the flags out cost @@MEASURE:manual.bytes_pct@@% @@MEASURE:manual.bytes_word@@ code and @@MEASURE:manual.insns_pct@@% @@MEASURE:manual.insns_word@@ instructions executed (section {{r:machine-has-no-condition-codes}}). `CBCC` writes nothing.",

'BTAG': "The tag branches `BTAG` and `BNTAG` and the table dispatch `JTAG` make tagged pointers cheap to use rather than merely possible: three bits of tag and one of sense fit the `low` nibble exactly, so parcel 1 is a full displacement. Because quad-aligned objects have zero in the low three bits, the tag is free; a plain access works at any address, so a stray tag is not caught by an alignment fault, and the explicit test these words make is the way to check one. The compiler for C never emits them (the corpus shows none); they are for Lisp and other tagged runtimes.",

'JTAG': "The table-dispatch partner of `BTAG`. It is legal only in the scaled-index mode, the one mode with a free register slot for the tagged value. It replaces the PDP-11 dispatch-table idiom `@(Rn)+` better, because it needs no pointer register and cannot index out of range.",

'JMPI': "Exactly one deferred reference, for control transfer only, in `XFER`: the PLT stub of every dynamically linked program (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`), each two instructions and a scratch register without it. It is admitted because it breaks none of the reasons deferred modes are removed (no register is side-effected, the reference is in the branch path and not the operand path, a fault is clean by ordering). Jump tables through `JMPI` are not smaller, because the table entries are 8 bytes against 8 for a case in a compare chain.",

'PUSHM': "The VAX procedure entry mask was the useful half of `CALLS`; `PUSHM` and `POPM` keep that half without the frame (hardware call frames ran slower than the sequence on later VAXes). They are in `SOP` because a 16-bit mask does not fit beside `MBLK`'s sub-opcode; that uses `SOP`'s last two free slots. The second page has 8-bit forms for `R8` to `R15`, because all 2,392 push sites and 2,392 pop sites in the measured corpus use a mask within `R8` to `R15`.",

'CAS': "The barrier-fused variants are taken from LoongArch's pragmatism: a lock acquire is one instruction rather than an atomic followed by a `FENCE`, and that pair is in every critical section of the system. With the other multiprocessor operations the atomics make the seventeen-operation SMP umbrella ({{r:multiprocessor-instructions-at-a-glance}}). They are defined on a reservation monitor and not on a bus lock ({{r:dma-coherence-and-the-hand-off}}).",

'SWAP': "One of the read-modify-write atomics of the `ATOM` group (see `CAS`). No separate reason is recorded for it.",

'AADD': "One of the fetch-and-operate atomics of `ATOM` (see `CAS`), in the place of the PDP-11's read-modify-write instructions, which were indivisible on the Unibus through the `DATIP`/`DATO` pair ({{r:smp-what-you-already-know}}).",

'AAND': "The fetch-and-and, or and xor atomics of `ATOM` (see `CAS`). No separate reason is recorded for them.",

'AMAX': "The fetch-and-minimum and maximum atomics, borrowed from LoongArch's richer atomic set: each is a couple of hundred lookup tables and saves a compare-and-swap retry loop.",

'LLSC': "Load-linked and store-conditional, with the reservation a monitor, because a monitor maps onto the exclusive access of AXI and of FPGA and modern memory systems, where the Unibus's locked read-modify-write (`DATIP`/`DATO`) does not scale as cores multiply. A short sequence must eventually succeed if no other initiator keeps writing the granule, the RISC-V rule.",

'NOP': "`NOP` is common and has no story; `LPAD` is the landing pad. Landing pads mark the legal targets of indirect jumps and calls so that jump-oriented attacks can be stopped at the transfer, as Intel's indirect-branch tracking and ARM's branch target identification do and OpenBSD enforces. ABI version 1 leaves them off, and the assembler provides `.lpad`; the kernel pain-points and mitigations reports record why deciding later is more expensive (appendix {{c:id03001|n}}, section {{r:page-bit-that-enforces-landing-pads}}).",

'RTI': "`RTT` looks redundant against `RTI`, and stays: it sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.",

'BPT': "`BPT` is a trap vector, but a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has; that is why it is kept although `IOT` and `EMT` are not.",

'FENCE': "The memory model is sequentially consistent, so `FENCE` is needed only for what is outside the model: devices and the framebuffer (one `FENCE` between writing a device's registers and setting its go bit, section {{r:standard-graphics-card}}) and instruction streams.",

'WFE': "`WAIT` was a PDP-11 instruction (sleep until an interrupt); `WFE` subsumes it: it sleeps until an interrupt or another core's `SEV`, and on a uniprocessor it behaves exactly as `WAIT` did. `WFE` and `SEV` belong to the multiprocessor operations ({{r:waiting-signalling-and-interrupting-another}}).",

'SEV': "The signalling half of `WFE`, so that a core waiting for a lock can sleep instead of spinning and be woken by the core that releases it.",

'TLBA': "`TLBI` and `TLBIA` broadcast, `TLBSYNC` waits for the other cores, and `ICINV` and `ICINVA` invalidate the instruction cache: a Lisp runtime that compiles a function cannot work without an instruction-cache invalidate.",

'PUSHX': "A handler that can be interrupted must save `EPC` and `EPSW` before it lowers the priority; with only `MFSR` that costs two moves and two stores (sixteen bytes) on every such kernel entry, and the same to restore. The instructions may not show up high in the instruction count, but they save bytes and cycles in a tight, very often used kernel loop.",

'ISYNC': "Taken from the out-of-order readiness review: it makes earlier writes to `PTBR`, `ASID`, `MMUCTL` and `VBR` take effect for what follows, so an in-order machine may make them immediate and a speculative one has a place to serialise. It serves the aim that the architecture is efficient on both in-order and out-of-order cores ({{r:pdp-11-made-every-addressing}}).",

'HINT': "Defined with `ISYNC`: a no-op with a byte of code, defined for `0` (plain), `1` (pause, for spin-wait loops) and `2` (speculation barrier), every other code a reserved hint that executes as a no-op so that a later machine can give it a meaning without breaking an old binary.",

'MFSR': "A paging operating system must install a page table and learn why it was entered, which needs instructions to write `PTBR` and read `EPC`, `EVA` and `ECAUSE`. One general pair reaches all of the system registers by number. The user and supervisor stack pointers are in the set because any kernel must read and write the user stack pointer to build a signal frame, copy a process or switch context.",

'SPL': "`SPL` stays although `MTPS` writes the whole status word: it sets the priority alone, leaving the trace bit and the modes as they are, so a kernel raising priority around a critical section needs no read-modify-write of the status word. It is the PDP-11 instruction of the same name.",

'TRAP': "`TRAP $n` carries an 8-bit vector number in its one parcel, so the vector range of 256 and the two-byte common case are kept together; I did not keep a second spelling for the longer vectors. `IOT` and `EMT`, which were `TRAP` at two particular vectors on the PDP-11, are not provided.",

'TLBI': "It broadcasts: a translation changed by one core must be invalidated on all of them, and `TLBSYNC` waits for it.",
'TLBIAS': "A context switch that reuses an address-space number, or a process that ends, must remove every translation of that number, not one page at a time; `TLBIAS` does it in one instruction. `TLBIGP` is for the hypervisor, which changes a second-stage entry and knows only the guest-physical page.",


'MTDP': "`DP` descends from the 6502's zero page and is kept for code density (a 12-bit displacement in four bytes); it is also the thread pointer in user mode and, in kernel mode, the per-CPU pointer that an SMP kernel wants ({{r:per-cpu-state-and-cheap-context}}). `MTDP` and `MFDP` read and write the current mode's copy.",



'ICINV': "Instruction-cache invalidation, by address (`ICINV`) and whole (`ICINVA`). The reason is the one given for `TLBA`: a runtime that compiles a function cannot work without it.",

'PROBE': "Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it, and it replaces the `nofault` global of the V7 kernel for the address-validation case.",
}
