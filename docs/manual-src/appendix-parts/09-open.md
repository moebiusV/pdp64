<a id="j91"></a>
### J.9.1 The conditional select and the expansions of ABS, MIN, MINU, MAX and MAXU

**Issue.** A conditional select is an instruction that picks one of two values by a condition, with no branch (x86 `CMOV`, ARM64 `CSEL`). The pdp64 has none, except the pair `MASKEQZ` and `MASKNEZ` (each tests one register against zero and gives either zero or the other operand: `rd = rc == 0 ? 0 : ra`, and the opposite), and `SET cc, rd`, which turns a flag condition into 0 or 1. The author has decided that `ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases (words the assembler expands into other instructions), not native instructions, and that the manual entry of each shows the alias (errata 98). He said he was happy for them to be aliases on top of a select ("`cmov`, `csel`, `fsel`"), but nothing yet says which select, or what each alias expands to. The flags the five words promise are fixed: `ABS` sets `N` and `Z` from the result, sets `V` when the operand is the most negative number, and leaves `C`; `MIN`, `MINU`, `MAX` and `MAXU` set `N` and `Z` from the result, clear `V` and leave `C`. Any expansion that starts with `CMP` or `SUB` overwrites `C`, and `TST` on the result restores `N` and `Z` and clears `V` but not `C`; so the real choice is to change the flags and say so, or to spend an extra instruction.

**Why it matters.** Until the expansion is fixed the entries of the five words cannot show it (section 9.7.6). Kernel code uses clamps and minimum and maximum in size computations, and a constant-time select is wanted for checking message-authentication codes and handling keys. A compiler must know whether a comparison used as a value may become a select, and an optimizer that is free to turn a select back into a branch would break the constant-time promise (J.9.2), so the ABI needs a rule. In hardware, a select that reads flags needs the flag file read by a data instruction (in an out-of-order core, renamed flags read at the select); `MASKEQZ` reads only registers. A 64-bit select is estimated at about 100 LUTs for the mask pair, and a native `ABS`, `MIN` and `MAX` at 150 to 250 LUTs. How often the words matter is measured on the compiled corpus (amd64, optimized for size): 18 `abs` sites, 5 unsigned, 171 `min` and 52 `max` in 95 files, under 0.1% of code.

**Counting convention.** `CMP`, `MOVQ`, `BIS` and `NEG` between registers are 2 bytes; `SET cc`, `MASKEQZ`, `MASKNEZ`, `BSEL` and any new select are 4 bytes. A native `MIN` is 1 instruction of 4 bytes. These are estimates to be checked against the assembler.

**Options.**

1. *A flag-reading select, `CSEL cc, ra, rb, rd`.* One new 4-byte instruction that reads `N`, `Z`, `C` and `V` and picks `ra` or `rb`. `MIN` is `CMP a,b ; CSEL lt,a,b,d` (2 instructions, 6 bytes); `ABS` is `NEG a,t ; CSEL mi,a,t,d` (2 or 3 instructions). One select also serves floating-point values, which live in the general registers. For: the natural select for a machine with flags; the shortest alias of the real options; 15 condition words fit in the 7-bit sub-opcode space of the three-register group (51 of 128 used). Against: after `CMP` the flags describe the comparison, not the result, so `N` and `Z` are wrong and `V` and `C` are the comparison's: the flag rule above breaks unless a `TST` is added (3 instructions, 8 bytes); needs a flag read on the select unit; a second select beside `MASKEQZ` multiplies entities (Ockham, the author's rule: do not multiply entities without benefit); effort in the assembler, simulator, compilers and both manuals; 250 LUTs or less (estimate).
2. *`SET` plus `MASKEQZ` and `MASKNEZ`, no new instruction.* The aliases expand over what the author already adopted (errata 85). `MIN a,b,d` is `CMP a,b ; SET lt,c ; MASKEQZ a,c,t ; MASKNEZ b,c,d ; BIS t,d` (5 instructions, 16 bytes, two scratch registers). `ABS` needs no select: `ASR a,#63,m ; XOR m,a,d ; SUB m,d` (3 instructions, about 6 bytes, `V` not set at the minimum). For: no new opcode or flag reader; one select for everything; constant time by construction; no gates. Against: 4 more instructions and 12 more bytes per `MIN` or `MAX` site (on the corpus about 890 instructions and 2.7 KB, about 0.3% of instructions, an estimate from amd64 counts); `C` is changed; the assembler needs scratch registers and nothing is reserved except `R12`, which is the linker's, so an alias that silently uses a register is a strange side effect; five hidden instructions behind one word.
3. *A register-conditioned select, `SELECT rc, ra, rb, rd`.* `rd = rc != 0 ? ra : rb`, three source registers in one instruction (the four-register 4-byte form exists: `FMADD` has four register fields). `MIN` is `CMP a,b ; SET lt,c ; SELECT c,a,b,d` (3 instructions, 10 bytes); `MASKEQZ(a,c)` is `SELECT c,a,zero`, so it replaces the two mask instructions or sits beside them. For: a constant-time select in 1 instruction instead of 3; no flag read. Against: it reopens the adoption of `MASKEQZ` (errata 85) or adds a third entity; `MIN` still costs 3 instructions and the flags of the sequence are the comparison's.
4. *Bit select, `BSEL rm, ra, rb, rd`, as the only select.* `BSEL` is decided (9.9.6, 9.20.4); this option is to use it also as the select for the aliases and drop the mask pair's role in them. `rd = (rm & ra) | (~rm & rb)`, with the mask made from the condition. `MIN` is `CMP a,b ; SET lt,c ; NEG c,m ; BSEL m,a,b,d` (4 instructions, about 14 bytes). For: nothing new, since the instruction is adopted (it is the Ch and Maj functions of SHA-2 and the constant-time swap); selects any width and bit pattern. Against: the scalar select is long, with a comparison, a `SET` and a negate before it; a four-register form.
5. *A two-operand conditional move, `CMOVcc rs, rd`.* 2 bytes, destructive, reads flags (the x86 shape). `MIN a,b,d` is `MOVQ a,d ; CMP d,b ; CMOVgt b,d` (3 instructions, 6 bytes, no scratch register). For: the smallest code of any select; the shape compilers know. Against: needs a 2-byte slot, and the last spare slot in the arithmetic group would be spent (a 2-byte form writes flags); a read-modify-write destination makes the instruction depend on the old `rd` even when it moves nothing, which out-of-order machines dislike; the flags after it are the comparison's.
6. *No select: a compare and a short branch over a move.* `MOVQ a,d ; CMP d,b ; Bgt over ; MOVQ b,d`. A core may fuse a forward branch over one instruction into a single micro-operation, so the sequence costs nothing on cores that fuse and is promised nothing on cores that do not. For: nothing new in the architecture; 3 or 4 instructions. Against: it branches on data, so `MIN`, `MAX` and `ABS` cannot stay on the list of always-constant-time instructions, which contradicts the secure core of errata 85 and the author's "no timing channel attacks"; a data-dependent branch mispredicts at a rate that depends on the data; the flags are the comparison's.

**Precedents.**

* ARM64 `CSEL`, `CSINC`, `CSINV`, `CSNEG` select by flags, and Arm's data-independent-timing guarantee lists conditional select among the instructions covered *(verified)*; the architecture's own reserved slot for a flag-based `CSEL` in the secure-core proposal *(verified)*.
* x86 `CMOVcc`, SPARC V9 `MOVcc`, s390x `LOCR`, Alpha `CMOVxx` *(unverified: general knowledge)*.
* LoongArch `maskeqz` and `masknez` and RISC-V Zicond `czero.eqz` and `czero.nez` are exactly the mask pair; RISC-V's base set has no select *(unverified: general knowledge)*. RISC-V Zbb has native `min`, `minu`, `max`, `maxu` and no `abs` *(unverified)*.
* MIPS `MOVN` and `MOVZ`, and Alpha `CMOVxx` (which tests a register against zero), are register-conditioned selects *(unverified)*.
* ARM NEON `BSL`, `BIT`, `BIF` and the x86 ternary-logic instruction `VPTERNLOG` are bit selects *(unverified)*; `BSEL` in the secure-core design *(verified)*.
* The PDP-11 and the VAX have no select and compilers emit a branch; a few high-performance RISC-V cores fuse a short forward branch with the instruction after it *(unverified: general knowledge)*.

**The author's referents.** `cmov`, `csel`, `fsel` (no source machine named): "I am interested in the cmov/csel/fsel ... am happy for abs/min/max to be aliases on top of it in the assembler". On `ABS`, `MIN` and `MAX` as opcodes: "add them. and if we have to teach the front end about abs/min/max nodes that is fine ... surely other cpus have these opcodes", and later "why do them as single opcodes instead of as an opcode that takes a flag?" Ockham's rule: "don't multiply entities without benefit" and "no weird side effects, no bumping other opcodes in a way that makes code size increase". The PDP-11 `ROL` as an alias of `ROR` ("the assembler could take rol and map it to ror"). Floats live in the general registers. "No timing channel attacks."

**The assistant's leaning.** Option 2 for the architecture: `MASKEQZ` and `MASKNEZ` stay the one select (errata 85), `ABS` expands without a select (`ASR`, `XOR`, `SUB`), and the manual says plainly that the five words change `C` and that the assembler needs a reserved temporary register. If `MIN` and `MAX` in hot loops prove to matter, Option 1 can be added later in the same sub-opcode block and the same aliases then shrink from 5 instructions to 2 without anyone rewriting source. This is the assistant's view, not a decision. It would change if a compile showed `MIN` or `MAX` inside hot loops, or if the author wants the alias as short as the native form (then Option 1 now).

**Where the body refers to it.** Sections 9.7.6, 9.20.3 and 9.21.1; and the dictionary entries of `ABS`, `MIN`, `MINU`, `MAX`, `MAXU` and `MASKEQZ`.

<a id="j92"></a>
### J.9.2 Constant-time execution: what holds while `DIT` is clear, and where `DIT` lives

**Issue.** A timing channel is a leak of secret data through how long an instruction takes, when the time depends on the operand values. "Constant-time" means that the architecture promises that an instruction takes the same time whatever the data (data-independent timing, the property that cryptographic code needs). It is necessary but not sufficient: a secret-dependent branch, address or table index still leaks through the branch predictor and the cache. The author wants "a constant time flag or something so instructions always take an equal amount of time no matter the input"; on 2026-11-04 he decided that add and divide need not take the same time as each other, "only they are timing independent of their data", and that "for non-sensitive things, constant time isn't a priority". Two things are decided. Section 9.3.7 states a bit `DIT` in the status word, set by the program, that promises data-independent timing while it is set (the author took the contract of the architecture recommendations, errata 71; a mode bit that is saved with the status word is what he called a freebie, errata 83). And errata 85 decided that at least one secure core has every timing channel removed. Two things are open. **First, what is promised while `DIT` is clear:** nothing, a published list of instructions that never vary, or every integer instruction. **Second, the position of the bit:** bit 12 of the 16-bit status word is `UA`, bits 13 to 15 are free and read as zero, and the saved status word of an exception frame carries whichever bit is chosen.

**Why it matters.** The fast paths (an early exit from divide, from the block scan `MSCN`, from a multiplier) are gates and speed, and a fixed-latency multiplier is smaller than an early-out one. A core must be able to disable each fast path while `DIT` is set. The compiler must not reorder, replace or turn into branches the instructions that are promised to be constant-time, and the manual must list them; no instruction timing is stated in the instruction set today. Measured on 827 compiled files (370,115 instructions): divide 149 (0.040%), block copy 154, floating-point divide 10, multiply 2,204 (0.595%), `MSCN` none. A fixed worst-case divide is estimated to slow a whole program by about 1% (assuming 64 cycles worst and 30 average; an estimate, not run time data). The position of the bit fixes the format of the saved status word that the kernel, the debugger and the signal frame share.

**Options** (for what holds while `DIT` is clear).

1. *Nothing: `DIT` is the only promise.* Every instruction may have fast paths, and code that needs constant time sets the bit. For: nothing more to specify; fast paths stay for normal code. Against: software forgets to set it, and a default of "insecure" is the one that a 2026 kernel post calls unacceptable; an out-of-order core has to hold the promise through the whole pipeline and not only in the arithmetic unit.
2. *A published core list that is always constant-time, with `DIT` for the rest.* The architecture lists the instructions that always take data-independent time (add, subtract, logic, shifts and rotates, `MUL`, `MULH`, `MULHU`, `CLMUL`, `POPCNT`, `CLZ`, `BSWAP`, `BITREV`, `SET`, `MASKEQZ`, `MASKNEZ`, and the expansions of `ABS`, `MIN` and `MAX` once J.9.1 fixes them); `DIV`, `MOD`, floating point, `MCMP`, `MSCN`, `MSCNN` and `MVAL` need the bit. For: the common case is free, the rare instructions are covered when asked, and software may rely on the list on every core; a fixed multiplier needs fewer gates. Against: two things to specify and test; the list must be kept as instructions are added; any expansion in J.9.1 that branches on data is off it.
3. *Every integer instruction always constant-time, a prohibition list, `DIT` for floating point and the scanners only.* `DIV` always takes its worst-case time. For: the simplest to specify and verify; fewest gates in the fast-path logic. Against: an average divide is slower (about 1% over a program, and loops that divide on every iteration weigh many times more); `MSCN` loses its early exit; it contradicts "not a priority" for non-sensitive code.
4. *The promise on a class of core.* The strong promise lives on the secure class of errata 85 (identified by a class register; `DIT` reads 1 and is fixed on it; every instruction fixed-latency, caches private, speculation absent). On general cores `DIT` is a promise of the instructions in the list of option 2, and a core says in a feature register what it cannot hold. For: the strongest guarantee where it is needed, covering the cache and the bus that a mode bit cannot reach; the general cores stay fast. Against: a second core design to build and verify; general cores that run secrets have no promise beyond the list.

**The position.** Bit 13, the next free bit above `UA`, keeps the used bits together; bit 15 leaves 13 and 14 for later. For bit 13: no gap in the status word, and the save and restore is one mask. Against: a later mode bit that the kernel wants next to `UA` will not have the place.

**Precedents.**

* Arm's `DIT` bit in the processor state, which Linux on arm64 enables in the kernel "to be cautious" *(verified)*.
* Intel's `DOITM`, with the vendor saying it does not recommend enabling it globally and kernel posts (July 2026) saying it is best left on *(verified)*.
* RISC-V scalar crypto extension Zkt: an implementer declares a subset of instructions with latency independent of the data values, a promise and not a mode *(verified)*.
* x86 before `DOITM`: Intel published a guidance list and later found that AES-NI and `ADD` and `XOR` varied on later parts, so the drift is the precedent against a list that is only published *(verified)*.
* The repository's own secure class, with `DIT` reading 1 and fixed on it, a class register, a reserved bus slot and a private window *(verified)*.
* Small cryptographic microcontrollers with a fixed-cycle multiplier and divider, such as the Cortex-M0+ with its single-cycle multiplier option *(unverified: general knowledge)*.

**The author's referents.** The failures to avoid: "no hammer-row, no spectre, no timing channel attacks; there should be constant time flag or something so instructions always take an equal amount of time no matter the input". On cost: "I wonder how much that would slow a processor down ... for non-sensitive things, constant time isn't a priority". "Mode bits are case by case, but in general should be visible, not hidden state. putting modes in bits that are saved anyway sounds like a freebie." Cryptography on separate devices on the PCI bus, "so they can pay the price of constant time computation".

**The assistant's leaning.** Option 2 with the secure class of option 4 as the strong form, the published list written into the manual now, `DIT` saved with the status word and the compiler treating the list as untouchable; and bit 13. This is the assistant's view, not a decision. It would change if a cycle measurement showed divide in hot loops (option 2 stays, option 3 is dropped), or if hardware cannot cheaply disable a fast path (the instruction goes off the list).

**Where the body refers to it.** Sections 9.3.7 and 9.21.1.

<a id="j93"></a>
### J.9.3 The atomic group: where the operands go, and the size of `CAS`

**Issue.** The atomic group holds `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU`, `XMINU`, `LL` and `SC`, each with a `_DB` variant that adds a barrier (9.13.1). Their semantics, ordering and the reservation monitor are decided (chapter 7). Not decided is the shape of the instruction: each names an address, an operand and a place for the old value, and `CAS` also an expected value. The grammars of the prefix-coded encodings take three registers for all but `CAS` and `CASDB` (four), with the address in a register, in the order written (errata 87, assumption 4), and the text has not confirmed that. `SC` has to say where its success flag goes. And `CAS` works on 4 or 8 bytes (9.13.2): how a 4-byte and an 8-byte form are told apart is not fixed. The rule that an instruction has at most one memory operand (9.2.2) and the refusal of implicit registers (9.17.3) are decided.

**Why it matters.** The assembler syntax, the compiler's lock and reference-count sequences, the operating system's lock code and every disassembler depend on the order of the operands, and a mistake is a lock that corrupts memory and not a fault.

**Options** (the placement).

1. *Address in a register, three registers, a separate destination; four for `CAS`.* `XADD Ra, Rb, Rd`: the old word at `(Ra)` goes to `Rd`, and `Rb` is added. `CAS` names expected, new, address and the destination of the old value. For: no operand is destroyed; one leaf shape for the group; the assumption of the grammars. Against: `CAS` needs a four-register leaf, which is six bytes.
2. *Three registers throughout; the expected value is also the destination of `CAS`.* `CAS Rd, Rb, (Ra)`: `Rd` holds the expected value and receives the old value. For: three registers for every member of the group; the form of RISC-V's `AMOCAS` and of ARM's `CAS`. Against: the expected value is destroyed, so a retry loop reloads it; one more rule to remember.
3. *Two registers, destructive.* `XADD (Ra), Rd`: `Rd` is the operand and receives the old value. For: the shortest form, two or four bytes; the shape of x86's `XADD`. Against: `CAS` has no room for four values without an implicit register (refused, 9.17.3); the operand is destroyed.
4. *The address as the ordinary memory operand `rm`.* For: reuses the addressing forms of the rest of the instruction set; the same shape as `ADDM`. Against: allows modes with side effects (auto-increment) that an atomic must refuse, and the forms are longer.

**The size of `CAS`** (4 or 8 bytes). (a) *Two words, `CASL` and `CASQ`*, spelled like `MOVL` and `MOVQ`: For: the size is in the mnemonic, as for the moves; Against: two sub-opcodes, and the `_DB` variants double again. (b) *A size bit in the sub-opcode or leaf*, one mnemonic with a suffix: For: one entry; Against: the assembler must carry the suffix, which no other instruction of the group does. (c) *`CAS` is always 8 bytes, and a 4-byte compare-and-swap is a `CAS` of an aligned pair that includes the neighbour*: For: nothing to encode; Against: it makes a 4-byte lock word a 8-byte critical value, and the span-two-fields case of 9.13.2 would have to be written differently.

**Precedents.** RISC-V `AMO` instructions take `rd, rs2, (rs1)` and `AMOCAS` takes the expected value in `rd` *(unverified: general knowledge)*; ARM64 `LDADD` and `CAS` take the compare value in a register that is overwritten with the old value *(unverified)*; x86 `LOCK XADD` is destructive and `CMPXCHG` has the accumulator as an implicit operand *(unverified)*; the VAX interlocked instructions (`BBSSI`, `ADAWI`, `INSQHI`) use memory operands *(unverified)*.

**The author's referents.** "Only one memory operand per instruction" and no implicit registers as rules of the instruction set (9.2.2, 9.17.3); the author has not spoken on the order of the operands.

**The assistant's leaning.** Option 1, which is what the grammars already assume, with the size as two words (a). This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.13.2 and 9.21.1; the atomic entries of section 9.13.

<a id="j94"></a>
### J.9.4 The checked arithmetic: the number of the `CHECK` vector and the register form

**Issue.** `ADDV`, `SUBV` and `MULV` abort at the instruction, with `EPC` at it and the destination unwritten, when the signed result does not fit in 64 bits; `TRAPCC` takes the same `CHECK` vector as a trap (errata 85). Two things are not fixed. The vector table has no vector of that name: numbers 16 to 31 are free between `bpt` (15) and the interrupt base (32). And the grammars give the two-register form (`Rd <- Rd op Rs`, like `ADD`), where the reason for the fused forms was one non-destructive instruction in place of `ADD` and `TRAPCC`, which a three-register form (`Rd <- Ra op Rb`) serves.

**Why it matters.** The vector number is the index of the handler in the table that the kernel writes; software that handles an overflow (a language runtime that promotes an integer to a bignum) names it. The register form decides how long the instruction is and whether a copy is needed before it.

**Options** (the vector).

1. *Vector 16, the first free number.* For: keeps the fault group together; matches the number the study used. Against: a later fault of the same group has no number before the interrupt base without a gap rule.
2. *A number at the top of the free range (31).* For: leaves 16 to 30 for faults not yet defined. Against: an arbitrary number that the first reader will ask about.
3. *No new vector: a `TRAP`-range number.* The overflow enters as `TRAP #n` would. For: no hardware vector to define. Against: the hardware has to synthesise a system call for a fault, and a handler cannot tell an overflow from a real `TRAP`.

**Options** (the form).

4. *Two registers, destructive (the grammars).* For: the shape of `ADD`; two parcels. Against: the operand is destroyed, so a check that needs the old value copies it first.
5. *Three registers.* For: non-destructive; the reason the fused forms exist. Against: a longer leaf (three register fields), where `ADD` and `TRAPCC` is four plus two bytes.
6. *Both.* For: the compiler chooses. Against: two leaves for one idea.

**Precedents.** x86 `INTO` traps on the overflow flag and is not in 64-bit mode; MIPS `ADD` and `ADDI` trap on signed overflow while `ADDU` does not; the VAX has an integer-overflow trap enabled by a bit in the status word *(all unverified: general knowledge)*.

**The author's referents.** Errata 85: `TRAPCC` is a trap and not an abort, and the fused `ADDV`, `SUBV` and `MULV` carry the register-only cases; errata 84 item 9, "overflow-trapping arithmetic (leaning yes)".

**The assistant's leaning.** Vector 16 and the three-register form, because the fused forms were accepted as the non-destructive case. This is the assistant's view, not a decision.

**Where the body refers to it.** [[r20: Section 9.21]][[16 32: Section 9.21.3]]; the entries of `OVF` and `TRAPCC` in section 9.7 and 9.14.

<a id="j95"></a>
### J.9.5 Addressing-mode gaps: the scaled-index displacement and a store through `d(DP)`

**Issue.** The scaled-index mode `d(Rn)(Rx*s)` exists for the array of structures. Its shortest form (two parcels) has a displacement of 6 or 8 bits, so ±32 to ±128 bytes before it takes three parcels and a 22-bit displacement (9.5.1). The mode `d(DP)`, the direct page that serves the thread pointer and the per-CPU pointer, has a load form of six bytes and no store form in the grammars (9.3.5).

**Why it matters.** Code that walks an array of records touches fields beyond 32 bytes and pays two more bytes for each; a thread-local store needs a separate address computation.

**Options.**

1. *Leave both as they are.* For: nothing changes; the three-parcel forms exist. Against: the cost is paid in the hot loop of the array of structures and in every thread-local store.
2. *Reduce the scale to one bit (x1 or x8) and give the bit to the displacement.* For: one more bit of displacement. Against: the scales 2 and 4, which index 16- and 32-bit arrays, are lost; the compiler's best case (`bs_ec`'s inner loop, 31% fewer instructions) uses the scaled index.
3. *Add a two-parcel scaled-index leaf with hot registers for the base and the index.* The register fields shrink, so the displacement grows. For: serves the common case with the registers the allocator prefers. Against: a prefix spent on one leaf; a compiler rule for which registers qualify.
4. *Add a store form through `d(DP)`, six bytes, one word for each size.* For: symmetrical with the load; one instruction for a thread-local store. Against: spends prefix space on a form that the compiler may use rarely.
5. *Add two-parcel `d(DP)` forms with a 12-bit displacement for loads and stores.* For: most thread-local and per-CPU blocks are small; four bytes instead of six. Against: the 28-bit load form still stands beside it.

**Precedents.** x86 scaled index with a 32-bit displacement; AArch64 scaled register offset with no displacement and an unsigned scaled 12-bit offset; the VAX index mode that follows any other mode *(all unverified: general knowledge)*. The 6502's zero page is the ancestor of `DP` *(stated in chapter 9)*.

**The author's referents.** The PDP-11 as the base ("update and refresh of the pdp-11 instruction set and architecture"); Ockham's rule: "don't multiply entities without benefit".

**The assistant's leaning.** Option 1 until a compiled corpus shows how many array accesses lie beyond 32 bytes. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.5.3 and 9.21.1.

<a id="j96"></a>
### J.9.6 The page-bit mechanisms and the six reserved system words

**Issue.** The author approved three mechanisms "to be specified" (errata 84): a page bit that gates landing pads, so that an indirect transfer that does not land on `LPAD` faults, with the fault attributed to the branch (item 5); a page bit that says a system call may be made from this page (item 8); and a stack-limit register checked when a system call or a fault is taken (item 4). The grammars of the prefix-coded encodings reserve six system words, `SYSPG0` to `SYSPG5`, for these mechanisms, and the retire-stage study found that they need no opcode. What the words do, or whether they are released, is not said; the page-table entry has no bit for either page bit (the entry is full below bit 40 and the format for wide physical addresses is open, J.6.2).

**Why it matters.** The bits and registers must be in the page-table entry and the system-register list before the kernel and the linker are written, and software must be told not to use the six words until they mean something.

**Options.**

1. *No opcodes: enable bits in a system register and enforcement bits in the page-table entry.* The words stay reserved and abort as illegal. For: nothing to execute; matches the retire-stage study. Against: needs two page-table bits, which compete with the wide-physical-address format.
2. *One system word for each mechanism.* `SYSPG0` and the others set or clear the mechanism for the current address space. For: explicit, and a privileged instruction is easy to trap. Against: a mode that an instruction changes (the rule of 9.2.5 is that modes are visible state).
3. *A page-attribute instruction that sets bits of the entry for an address.* For: the kernel need not walk the table to change an attribute. Against: an instruction with a translation-buffer side effect, and the format of the entry must have room.
4. *Release the six words.* For: the opcode space is freed. Against: the mechanisms approved by the author are still to be specified.

**Precedents.** Intel's indirect-branch tracking is enabled by a bit in a model-specific register and ends a branch on a missing `ENDBR`; ARM's branch-target identification is a page attribute in the translation-table entry *(both unverified: general knowledge)*; OpenBSD's `msyscall` and `pinsyscalls` check where a system call comes from in software, and OpenBSD enforces landing pads by default where the hardware has them (appendix A, from the reports).

**The author's referents.** "Do it, no delay" for the colours of memory; landing pads gated by a page bit, "with the fault attributed to the branch"; "minimize recovery code".

**The assistant's leaning.** Option 1, since the study found no opcode is needed, and the words released only when the mechanisms are specified. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.21.1, A.1.2, A.2.2 and A.3.2. The schedule of landing pads in the ABI is J.D.2.

<a id="j97"></a>
### J.9.7 The worst-case latency of the block operations

**Issue.** An ordinary instruction is bounded: at most six bytes of fetch across two pages and one memory operand across two pages. A block operation (`MCPY`, `MSET`, `MCMP`, `MSCN` and the rest, 9.11.3 is not bounded by its definition; it keeps its progress in registers and may be interrupted between steps, and an implementation may move more than a byte per step provided the registers are consistent where an exception can be taken (9.11.5). So an interrupt-latency figure depends on the step.

**Why it matters.** A claim of real-time response rests on a bound. Until the step is stated, the claim is an argument and not a number.

**Options.**

1. *No architectural bound: each implementation states its granularity.* For: freedom to move a line or a page at a time. Against: software cannot rely on a latency.
2. *An architectural maximum between interrupt checks (one cache line, 64 bytes).* For: a bound that holds on every core. Against: ties a fast engine to a small step.
3. *An architectural maximum of one page between checks (4 KiB).* For: the largest unit with a single translation; bulk engines work at full speed. Against: tens of microseconds of latency on a slow memory.
4. *A feature register that reports the granularity.* For: software reads the figure. Against: it is information and not a promise.

**Precedents.** x86 `REP MOVS` is interruptible between iterations and its progress is in registers; ARM's `FEAT_MOPS` leaves the progress in registers; the VAX `MOVC` kept a first-part-done bit in the status word *(all unverified: general knowledge)*.

**The author's referents.** The VAX `MOVC5` as the argument against hidden state (9.11); the registers as the only progress.

**The assistant's leaning.** Options 1 and 4 together: no bound in the architecture, the granularity reported in a register. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.11.5 and 9.21.1.

<a id="j98"></a>
### J.9.8 The block operations and the data cache

**Issue.** A one-megabyte `MCPY` evicts the whole data cache for data that is never read again; it shows at once on a cache of 8 KiB. Every real `memcpy` on a machine with non-temporal stores uses them for this reason. An inference workload that moves tens of megabytes through a cache of a few kilobytes is the extreme case.

**Why it matters.** The kernel's working set is what a large copy destroys; and the fix is an opcode, a memory type or a rule inside the core, and only the first two are visible to software.

**Options.**

1. *Do nothing: leave the cache alone.* For: no new opcode or memory-type value. Against: the eviction is real.
2. *A non-temporal variant of the block operations.* For: the program says that the data will not be read again. Against: a new sub-opcode and a rule that the data may not be cached.
3. *A streaming value of the memory-type field of the page-table entry.* For: no opcode; a buffer is declared streaming once, and every access to it, by the block operations or not, follows. Against: the kernel must set it per mapping; a wrong type slows ordinary access.
4. *The implementation decides by length.* For: invisible to software. Against: a performance cliff with no architectural visibility, the worst of the options.

**Precedents.** x86 non-temporal stores (`MOVNT*`) and fast-string moves that avoid the cache above a threshold; ARM non-temporal load and store pairs *(all unverified: general knowledge)*.

**The author's referents.** The memory type as a page attribute (adopted from LoongArch, 9.20.2).

**The assistant's leaning.** Option 3, because the streaming workload is known by buffer, not by instruction. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.11.5, 9.21.1 and A.9.

<a id="j99"></a>
### J.9.9 The floating-point condition flags

**Issue.** `FCMP` writes the integer flags: `N` if the first operand is less than the second, `Z` if they are equal, `V` if they are unordered (either is a NaN), `C` cleared. The signed branches do not treat the unordered case as false: `BLT` after an unordered compare takes `N xor V`, which is 1. The compiler must therefore avoid `BLT` and `BLE` for floating point. A reading of the flag rules by the assistant, not checked against the compiler: `BGT` (`Z` clear and `N` equal to `V`) and `BGE` (`N` equal to `V`) are false for an unordered pair, so `a < b` can be tested as `b > a` with the operands swapped, `a <= b` as `b >= a`, `a == b` with `BEQ` and `a != b` with `BNE`; the swap needs the second operand in a register. A second problem is that `FCMP` writes the one set of integer flags, so two independent floating-point comparisons depend on the same resource and floating-point compares serialise against integer work.

**Why it matters.** The compiler's rules for `<` and `<=` on floating point; the number of flag copies an out-of-order core must rename; the status word that is saved and restored.

**Options.**

1. *Keep the integer flags and the swap rule.* For: no change; the existing branches suffice. Against: the swap needs a register for the second operand; the shared flags stay a dependence.
2. *Two floating-point condition bits in the status word.* For: separates floating-point compares from integer flags. Against: two more bits to save and restore, and a second set of branches or a condition mapping.
3. *Eight one-bit condition registers (LoongArch `FCC`).* For: many independent comparisons. Against: new state to save at a context switch.
4. *A compare that writes 0 or 1 into a general register (RISC-V `feq`, `flt`, `fle`).* For: no flags at all; the result feeds the one-parcel compare-and-branch against zero; fits floating point in the general registers. Against: a compare and a branch are two instructions, as `FCMP` and a branch are now.
5. *A fused floating-point compare-and-branch.* For: one instruction; no flags. Against: a leaf with two registers and a displacement, six bytes in the common case.

**Precedents.** LoongArch has eight `FCC` registers *(stated in the instruction-set text; unverified here)*; RISC-V's floating-point comparisons write an integer register *(unverified: general knowledge)*; ARM64 sets `NZCV` from `FCMP` so that unordered makes the ordered conditions false *(unverified: general knowledge)*.

**The author's referents.** "Floating point is done in the general registers" (9.2.7); the rule that no instruction writes part of `{N, Z, V}` (9.3.4).

**The assistant's leaning.** Option 1 now, as it costs nothing, with option 4 the one to take if the flag dependence is measured to matter. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.12.6, 9.20.3 and 9.21.1; the entry of `FCMP`.

<a id="j910"></a>
### J.9.10 Directed rounding and the remaining half-precision operations

**Issue.** *Directed rounding.* IEEE 754 requires rounding toward positive infinity, toward negative infinity and toward zero, as well as to nearest, for add, subtract, multiply, divide, square root, fused multiply-add and the conversions. The manual decides that there is no rounding-mode register or bit and that the rounding is in the opcode wherever it is not nearest-even (9.12.5); but no arithmetic opcode takes a rounding mode, only the `FRINT` family does. A conforming C library keeps the dynamic mode of `fesetround` in thread-local storage and dispatches on it. *Half precision.* `binary16` has seventeen operations and conversions; the maximum and minimum, the roundings, negation and absolute value of half, conversions to and from 64-bit integers, and `bfloat16` are not defined. The costs are unmeasured (conversions 500 to 1,000 lookup tables, full arithmetic 2,000 to 3,500).

**Why it matters.** Interval arithmetic and the C99 `<fenv.h>` conformance depend on directed rounding; machine-learning code on `bfloat16`.

**Options** (directed rounding).

1. *None: software emulates the modes.* For: nothing to add; the library's dispatch is the present answer. Against: it is slow, and the letter of the C standard is not met by hardware.
2. *A two-bit static rounding field in the instruction.* The `FESC` two-register forms have a free nibble; the four top-level operations have none. For: the mode is in the opcode as 9.12.5 says. Against: only the escape forms can carry it.
3. *Extra opcodes for the six core operations* (add, subtract, multiply, divide, square root, fused multiply-add) *in each of the three directions.* For: no field. Against: eighteen opcodes.

**Options** (half precision).

4. *Nothing more: the existing conversions and arithmetic.* For: no cost. Against: the library does the rest through `binary32`.
5. *The missing half operations except `bfloat16`.* For: a complete `binary16` set. Against: tables for a format little used outside machine learning.
6. *Add `bfloat16` conversions, or the arithmetic as well.* For: the machine-learning format. Against: another format, and the accelerator of chapter 8 does the volume work.

**Precedents.** RISC-V's floating-point instructions carry a static rounding-mode field with a dynamic value; ARM has a rounding-mode field in `FPCR`; x86 `AVX-512` has embedded rounding control; ARM and x86 have `bfloat16` conversions and dot products *(all unverified: general knowledge)*.

**The author's referents.** "No rounding-mode or precision mode bits" (9.12.5), the rule that a mode bit is by default visible state set by an instruction that names it (9.2.5).

**The assistant's leaning.** Option 1 for directed rounding until a libm port asks, and option 4 for half precision. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.12.6 and 9.21.1; the entry of the half-precision conversions.

<a id="j911"></a>
### J.9.11 The coherence protocol beyond four cores, and the verification of the memory model

**Issue.** The memory model is sequentially consistent (9.2.8, decided), and the machine has at least four cores with sixteen or more as the preferred ceiling that no decision may preclude (errata 92). The protocol chosen for two to four cores is snooping (invalidation by watching a shared bus, the simplest protocol); at eight or more cores a snooping bus is the wrong protocol, and the one for sixteen is not chosen. Separately, a declaration of sequential consistency is not an implementation: it is easy to violate by a store buffer that forwards wrongly or a cache that reorders fills, and the litmus tests of the published suites must be run before a second core exists.

**Why it matters.** The cache and its protocol must be chosen before the cache is built, not retrofitted; the litmus testing is a verification task that belongs in the plan before silicon.

**Options** (the protocol).

1. *Snooping up to four cores, and the ceiling is four.* For: the smallest design. Against: contradicts the sixteen of errata 92.
2. *Snoop filters or a directory per cache slice.* For: scales to sixteen and beyond; the usual answer. Against: a large structure and a protocol with many states.
3. *Clusters of four that snoop, joined by a directory.* For: small clusters stay simple. Against: two protocols to verify.
4. *Software coherence between clusters.* For: cheap in hardware. Against: fragile, and it breaks the sequentially consistent model across clusters.

**Precedents.** x86 snoop filters and directories across sockets, ARM coherent interconnects *(unverified: general knowledge)*.

**The author's referents.** "yeah let's have 4 cores minimum, 16 or more preferred" (errata 92).

**The assistant's leaning.** Option 3 or option 2, decided before the cache is designed; the litmus tests run on the model first. This is the assistant's view, not a decision.

**Where the body refers to it.** Section 9.21.1.

<a id="j912"></a>
### J.9.12 The poison bit, the user-qualified moves and the cryptographic words: what is not yet specified

**Issue.** The author decided these instructions and left their details: the deferred-fault and user-qualified loads and stores (`.D` and `.U`: the three leanings of item 10 and the five of item 18 of `docs/study-proposals.md`, accepted in errata 86), the AES and SHA words of the secure core (errata 85: "or whichever opcodes would speed up and enable aes and sha"; the design approved in errata 86), and `BSEL`. What is not written down: where the poison of a deferred load lives and how it travels (the author leans to a poison bit per register, errata 84 item 10, and the study does not say how it is saved and restored, or how it moves through a store); the full text of the user-qualified moves (the operand placement of the atomics that take the `.U` form, errata 86, waits on that of `ATOM`, J.9.3); whether `STUA` and `CLUA` remain once the port confirms the qualified moves (the author kept them until then); whether the result of `SHA256SIG0` and its kin is zero-extended, as the crypto study has it, or sign-extended like every other 32-bit result of the machine; and the check of the AES and SHA definitions against FIPS 197 and FIPS 180-4.

**Why it matters.** The kernel's copy routines, the dispatcher's test of argument registers for poison, the compiler's hoisting of loads and the crypto library each depend on the exact semantics; an instruction in the grammar whose behaviour differs between the manual, the assembler and the hardware is a security bug of the kind the priority list puts first.

**Options** (the result of the 32-bit SHA words).

1. *Zero-extended (the study).* For: the value is a hash word, not a signed number, and a following 64-bit add of two such words does not need a mask. Against: it breaks the rule that every 32-bit result is sign-extended, so a compiler special-cases the words.
2. *Sign-extended, like `RORI32`.* For: one rule for every 32-bit result. Against: a 32-bit hash word that is later used as a 64-bit unsigned value needs `MOVZL` first.

**Options** (the poison of a deferred load).

3. *A poison bit beside each register, saved with it.* For: precise and deterministic, as the author asked of the taint item ("no false positives"); the register file is small. Against: a bit for each register in the context switch and the exception frame; a store of a poisoned register must fault or carry it.
4. *A reserved value in the register.* For: no new state. Against: the value cannot be a data value any more; a data-dependent condition that the author refused (a strange side effect).

**Precedents.** RISC-V's scalar cryptography extension (`aes64es`, `sha256sig0`, the zero-extended 32-bit result) and the Itanium deferred-exception token (`NaT`) with `ld.s`, which is exactly a poison bit per register *(unverified: general knowledge)*; Arm's `LDTR` and `STTR` for the user-qualified access *(unverified)*.

**The author's referents.** "Constant-time AES and SHA instructions" for the secure core (errata 85); "i like your design. approved." and, of the select instructions, "looks good" (errata 86); of item 10, the three leanings accepted; of item 18, the five leanings accepted; of the secure core, "no timing channel attacks".

**The assistant's leaning.** Option 1, because the study chose it and the words feed 32-bit additions in any case, and option 3, because the author already leans to it (errata 84, item 10). This is the assistant's view, not a decision.

**Where the body refers to it.** [[r20: Section 9.21]][[16 32: Sections 9.6.7, 9.9.7 and 9.21.3]]; the dictionary entries of `MOVD`, `MOVUSER`, `AESR`, `AESK` and `SHA256`.
