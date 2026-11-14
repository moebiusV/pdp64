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

**Issue.** The atomic group holds `CAS`, `SWAP`, `XADD`, `XAND`, `XOR_`, `XXOR`, `XMAX`, `XMIN`, `XMAXU`, `XMINU`, `LL` and `SC`, each with a `_DB` variant that adds a barrier (9.13.1). Their semantics, ordering and the reservation monitor are decided (chapter 7). Not decided is the shape of the instruction: each names an address, an operand and a place for the old value, and `CAS` also an expected value. The grammar of the encoding takes three registers for all but `CAS` and `CASDB` (four), with the address in a register, in the order written (errata 87, assumption 4), and the text has not confirmed that. `SC` has to say where its success flag goes. And `CAS` works on 4 or 8 bytes (9.13.2): how a 4-byte and an 8-byte form are told apart is not fixed. The rule that an instruction has at most one memory operand (9.2.2) and the refusal of implicit registers (9.17.3) are decided.

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

**Where the body refers to it.** Section 9.21.3; the entries of `OVF` and `TRAPCC` in section 9.7 and 9.14.

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

**Issue.** The author approved three mechanisms "to be specified" (errata 84): a page bit that gates landing pads, so that an indirect transfer that does not land on `LPAD` faults, with the fault attributed to the branch (item 5); a page bit that says a system call may be made from this page (item 8); and a stack-limit register checked when a system call or a fault is taken (item 4). The grammar of the encoding reserves six system words, `SYSPG0` to `SYSPG5`, for these mechanisms, and the retire-stage study found that they need no opcode. What the words do, or whether they are released, is not said; the page-table entry has no bit for either page bit (the entry is full below bit 40 and the format for wide physical addresses is open, J.6.2).

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

**Where the body refers to it.** Sections 9.6.7, 9.9.7 and 9.21.3; the dictionary entries of `MOVD`, `MOVUSER`, `AESR`, `AESK` and `SHA256`.

<a id="j913"></a>
### J.9.13 Range checks on a register value: trap, sticky flag, clamp, mask or nothing

**Issue.** A range check (or bounds check) tests that a value lies in an interval: an array index `i` in `0 <= i < n`, a length that fits a buffer, a result that fits a field. Pascal, Ada, Java, Rust, Go and Swift insert one on every checked subscript; the Linux kernel has `array_index_nospec` and the bounds sanitizer of its own tests. A check is used in one of three ways, and they want different machinery. A *guard* stops the program before a bad value is used as an address, a length or a divisor: the memory-safe use. An *accumulation* lets a stretch of computation run and asks afterwards whether any step went out of range (saturating arithmetic, the overflow of a checksum loop); a flag that stays set once raised serves it, as the five IEEE flags of `FPSR` do (9.12.3: no floating-point operation traps; `FSFLAGS` reads and clears them). A *repair* replaces the bad value by a safe one: a clamp to the limits, or a mask that turns the index into zero. The author asked (errata 138) for "some instructions or easy way to do range checks on a register value, a trap on out of range, similar to overflow, or set a bit in a sticky register, exception register", worked out for coding efficiency, and whether this beats the select instructions `MIN` and `MAX`.

**What the full design already has.** Each of these was read in the grammar and in chapter 9.
- `CBCC` (9.10.4), compare and branch, writes no flags: one parcel against zero for `CBEQ` and `CBNE`; two parcels against an immediate or a second register. The unsigned test `i >= n` is `CBHIS i, n, fail`, and because a negative index is a huge unsigned number, one unsigned compare checks `0 <= i < n`.
- `TRAPCC.cc` (9.14): fourteen words, one parcel each, no operand; trap if the flag condition holds; the vector is open (J.6.10, J.9.4). `CMP i, n` followed by `TRAPCC.cc` is the same check as a trap. Errata 85 decided `TRAPCC` as a trap, with the fused `ADDV`, `SUBV` and `MULV` (abort on signed overflow, J.9.4), and recorded "no compare-and-trap form" (the study's reason: four bytes for what `CMP; TRAPCC` does in four).
- `SET cc, Rd`, `MASKEQZ` and `MASKNEZ` (9.20.4) and `BSEL`, all decided; `MIN`, `MINU`, `MAX`, `MAXU` and `ABS` are assembler aliases whose expansion is open (9.7.6, J.9.1).
- Not present: an instruction that raises an error from a range, a sticky bit for ranges, a clamp.
- Proposed, not decided: a bounds-checked `INDEX` for Pascal and Ada (9.18 commentary, `docs/pdp64-isa.md`, the VAX `INDEX`); option 3 below would replace it.

**Why it matters.** Memory safety by bounds check is the commonest security check in compiled code, and each language that makes it the default puts it in front of every access. Its price in instructions, bytes and speed is paid at every subscript, so a design that saves one instruction per check is felt in the whole program. The opcodes it takes belong in the encoding that the optimiser will be run on after the open items are settled.

**The analysis (the assistant's reasoning, not a decision).**
- *Guard.* The bad index must not reach the load, so execution must stop or divert before it. A trap or a branch does that. A sticky bit does not: execution continues with the bad index, and the load that follows it has already happened. The floating-point analogy holds for pure computation, where a not-a-number (NaN) never becomes an address; an integer that fails a range check is exactly the value that does.
- *Accumulation.* Here a sticky bit is right: no branch in the inner loop, one test after the loop, as with the floating-point flags. It is a check of a computation, not a guard of an access.
- *Repair by clamp* (`MIN` then `MAX`) hides the bug: a wrong index silently becomes the nearest limit, and the program reads the wrong element and goes on. It also puts one or two dependent operations on the critical path of every access, because the loaded address is computed from the clamped value, whereas a never-taken guard is predicted and adds an issue slot and no latency (the second statement is general knowledge of branch prediction, unverified for this machine).
- *Repair by mask to zero* is the Spectre-style index hardening of the kernel: `array_index_nospec` yields `index & mask`, where the mask is all ones when `index < size` and zero otherwise, computed with no branch so that a mis-speculated branch cannot be steered past it (`include/linux/nospec.h`; the x86 form is `cmp; sbb`, `arch/x86/include/asm/barrier.h`; both read on this machine). It is a defence against speculation, used after an ordinary bounds check, and not a substitute for one. `MASKEQZ` and `MASKNEZ` already give it.

**Counts from the current grammar** (sizes from the encoding of the grammar, registers among the hot ones unless said; the access `movq (r3)(r1*8),r4` is one instruction of 4 bytes and is not counted). Added per checked access:
- `cbhis r1, r2, fail`: 1 instruction, 4 bytes; flags untouched; 4 bytes for `r17, r18`; with an immediate bound of 100, 4 bytes for `r1` and 6 bytes for `r17`. `fail` is one stub shared by the function (it loses the source line).
- `cmp r1, r2` and `trapcc.cc`: 2 instructions, 4 bytes (6 bytes for `r17, r18` or for `cmp r1, #100`); writes the flags; no stub; the location comes from a table of check sites mapped from `EVA`, which is the address of the `TRAPCC` (study item 9).
- Range `lo <= i < hi`: `lea -100(r1), r5` and `cbhis r5, #50, fail`: 2 instructions, 8 bytes, flags untouched, one scratch register; with `movq`, `sub` and `cbhis`: 3 instructions, 10 bytes.
- Mask to zero: `cmp r1, r2`, `set lo, r5`, `maskeqz`: 3 instructions, 10 bytes; or `cmp`, `clr`, `sbc`, `and`, the x86 idiom: 4 instructions, 8 bytes (`SBC` subtracts the carry, 9.7.4; the mask is all ones when the compare borrows). Both write the flags.
- Clamp to `[lo, hi]` with the aliases of J.9.1, option 2 (`MIN` is 5 instructions and 16 bytes there): 10 instructions, 32 bytes, with a dependency chain of 8 or more. With the flag-reading select of J.9.1, option 1 (estimates from J.9.1's convention, not assembled): 4 instructions, 12 bytes.
- New options: `CHK` (below) 1 instruction, 4 bytes (a one-parcel form, 2 bytes, only in the hot registers); `RANGE` (sticky) 1 instruction, 4 bytes per check, and once per block a read of the sticky word (4 bytes, a word of the shape of `FSFLAGS`) and a branch on zero (2 bytes), 2 instructions and 6 bytes (the last two are estimates from existing shapes).
- The compiler's emission. A branch to a stub keeps the failing site (the stub loads the source location and calls the panic routine: about 3 instructions and 12 to 16 bytes a site if per-site; estimate), and costs a branch-predictor entry. A trap needs the table of check sites and the handler's search of it (a binary search of a sorted table, as exception tables work; general knowledge), and costs no code at the site.

**Opcode cost.** A leaf with prefix length `L` takes `2^(16-L)` of the 65,536 first-parcel patterns (`docs/encoding-work/optimizer.md`; the lengths are in `spec/pdp64/tables.md`). Existing leaves of the same shape give the prices. `CBCC` register-register, the leaf `CBR8/c`: prefix 12, 16 patterns for its four conditions, 4 each (`CBR8H/c`, prefix 14: 1 each). The register-register group `R2` (prefix 12: 16 patterns) holds 67 words in a 10-bit sub-opcode, so a new two-register word in it takes no pattern; `R3` (three registers, prefix 10: 64 patterns) holds 51 of 128. `R4` (four registers) is full: its 4-bit sub-opcode has 16 words. A one-parcel form with two 4-bit hot registers and no sub-opcode, as in the `RRF` leaves, has prefix 8 and costs 256 patterns (0.39%) for the one word. A register and a 12-bit immediate, the shape of `CMI12/a` (`CMP`), is prefix 15: 2 patterns (1 with a hot register, `CMI12H/a`). Two immediates and a register, 5 + 16 + 16 bits in three parcels: prefix 11, 32 patterns.

**Options.**

1. *Nothing new: `CBCC` and `TRAPCC`, with the aliases.* 0 patterns. For: the guard is already one instruction (`cbhis`, 4 bytes, flags untouched) or two (`cmp; trapcc`, 4 bytes); nothing to specify or verify; errata 85 recorded no compare-and-trap form. Against: `CBHIS` needs a stub; `CMP; TRAPCC` writes the flags and is two instructions; there is no sticky form, so an accumulation costs a branch per step; the clamp is 10 instructions.
2. *A compare-and-trap `CHK rs, rb` (unsigned, register or 12-bit immediate bound), with its own vector.* 0 patterns in the `R2` shape (4 bytes), 256 for a one-parcel hot form (2 bytes), 2 for the immediate form. For: one instruction in place of two; flags untouched, so it can sit between a compare and its branch; the compare runs in the branch unit's comparator (inference). Against: errata 85 decided the other way, and in the usual case it saves an instruction and no bytes (4 against 4); only the one-parcel form saves bytes, and that spends 0.39% of the code space on one word; one more vector. Precedents: 68000 `CHK` (an emulator's decoder has it, `target/m68k/translate.c`, verified), PowerPC `tw`, `twi`, `td`, `tdi` (`target/ppc/insn32.decode` of the same source, verified), MIPS `TLT`, `TGEU` and the other trap-compares (`target/mips/tcg/micromips_translate.c.inc`, verified), SPARC `Tcc` (`target/sparc/insns.decode`, verified), x86 `BOUND`, which is illegal in 64-bit mode (the decoder marks it so, `target/i386/tcg/decode-new.c.inc`, verified); the VAX `INDEX` *(unverified)*.
3. *A two-bound `CHK2 rs, rlo, rhi`.* 0 patterns in the `R3` shape (4 bytes, 1 instruction against 8 bytes and 2); 32 for a form with two immediates. For: the Pascal and Ada subscript with a lower bound other than zero is one instruction; replaces the `INDEX` of the proposals. Against: in C, Rust and Go the lower bound is zero and the unsigned compare of option 1 already does it; three register fields; the same reversal of errata 85. Precedents: 68020 `CHK2` and `CMP2` (the emulator source gates `chk2` on the 68020 feature, `target/m68k/translate.c`, verified), x86 `BOUND` (verified, above), VAX `INDEX` *(unverified)*.
4. *A sticky range flag: `RANGE rs, rlo, rhi` sets a bit in a status register that is read and cleared like `FSFLAGS`, with the rule that it guards computation only.* 0 patterns (`R3` and `R2` words), plus a system register or a bit in `FPSR` (details open). For: no branch in an inner loop; one test after the block; the model the floating-point flags already use. Against: execution goes on with the bad value, so a use as an address is not stopped (the rule must be enforced by the compiler); a new piece of saved state; the compiler must place the test, and a lost test is a silent error. Precedents: the ARM `Q` flag (`QF` in `target/arm/cpu.h`, `PSR_Q_BIT` in `arch/arm/include/uapi/asm/ptrace.h`, verified), the PowerPC summary-overflow bit `XER[SO]` (`XER_SO`, `target/ppc/cpu.h`, verified), the MIPS DSP control register (`DSPControl` in `target/mips/cpu.h`, verified to exist; the flag field *unverified*), the x86 `MXCSR` sticky flags (`mxcsr` in `target/i386/cpu.h`, verified to exist; the flag meanings *unverified*) and the IEEE 754 flags *(unverified)*.
5. *Clamp and mask forms: a `CLAMP rd, lo, hi` or the aliases.* 0 patterns in the `R3` shape. For: the repair is wanted where a value must be forced into range (a colour component, a volume); constant time (J.9.2). Against: hides the bug when used as a check; one or two dependent operations on every use; the select instructions already serve (J.9.1, which decides how `MIN` and `MAX` expand, and the cost of the alias above: 10 instructions and 32 bytes against 4 and 12 with a flag-reading select). The mask needs nothing new (3 instructions, 10 bytes, or 4 and 8). Precedent: `array_index_nospec` (verified, above).
6. *One instruction with a mode in its sub-opcode: trap, sticky, mask, clamp.* 0 patterns (four words in `R3`, or one name in the assembler over four words). For: one mnemonic to learn; the compiler picks the use. Against: four behaviours under one name; a mode that lives in a register instead of the sub-opcode would be state that changes what the instruction does, which is the strange side effect the author has refused (J.9.12); the same flag and trap questions as options 2 and 4.

**The author's referents.** "new design features from another linux kernel developer: make some instructions or easy way to do range checks on a register value, a trap on out of range, similar to overflow, or set a bit in a sticky register, exception register, etc. same thing as on floating point math when you have nan/inf etc, you don't trap you set bits in a status register. figure out what is most efficient from a coding point of view. would this be more efficient than using the cse select min/max functions?" (errata 138); errata 84 item 9 (overflow-trapping arithmetic, "leaning yes") and errata 85 (`TRAPCC` a trap, no compare-and-trap form); errata 98 (`MIN` and `MAX` are aliases).

**The answer to the author's last question** (the assistant's reasoning, with the counts above). As a check, a guard (`CBHIS` or `CMP; TRAPCC`) is more efficient than a clamp: it is 1 or 2 instructions and 4 bytes against 4 to 10 instructions and 12 to 32 bytes, and it is off the critical path. As a computed repair, `MIN` and `MAX` stay, with the cost J.9.1 sets.

**The assistant's leaning.** Options 1 and 4 together: keep `CBHIS` and `TRAPCC` for guards, and add the sticky `RANGE` only for accumulation, if a compiler wants it; do not add the compare-and-trap of options 2 and 3 without a measurement of sanitiser-built code, since they save an instruction and no bytes. This is the assistant's view, not a decision.

**Where the body refers to it.** Section 9.7.7 and section 9.21.1.

<a id="j914"></a>
### J.9.14 Provenance and taint tags: input taint of the Perl kind, tag bits in RAM

**Issue.** Perl's taint mode marks data that comes from outside the program (the command line, the environment, files, the network) as *tainted*. Operations propagate the mark: a string built from a tainted string is tainted. Using a tainted value in a dangerous place (`exec`, `open` for writing, `system`, `eval`, a database query) is an error, unless the program *launders* the value, which in Perl means extracting it with a pattern the programmer has checked. The author asked (errata 138) for "perl taint mode, bits for each word in ram, to mark where the bytes came from, tagging", whether the design has something like it, and (errata 138) how hard it would be with the current opcodes. This item answers both and asks whether to add an input-taint (integrity) lane and a tag per word of memory.

**What is decided already, and what is not.** Decided, read in `docs/study-proposals.md`, errata 84, 85 and 86, `docs/retire-stage-candidates.md` and the manual:
- *Poison* (study item 10; errata 84 and 86): a bit per register, set by a failed deferred load, propagated by OR through register operations, a fault when a poisoned register writes the flags, is a base, an index or the data of a store; saved in `EPSW`. It marks failure, not origin. Details open (J.9.12).
- *Secret taint* (study item 11; errata 84, 85, 86: the leanings followed, "no false positives, precise and deterministic"): a bit per register (`SMASK`), set by `SECRET` or a load from a `SEC` page, propagated by OR, cleared only by `DECLASSIFY`; with `DIT` on, a secret register used as an address, a branch condition, a jump target, the length of a block operation or a divisor faults. Memory: stage 1 faults a store of a secret register to a page that is not `SEC`, so the taint of memory is page-level; stage 2, a bit per 8-byte word, shares the side band of the tag below. It is a confidentiality check, with timing sinks.
- *Valid-pointer tag* (study item 3, stage 1, kept in errata 86): a bit per register and per naturally aligned 8-byte word of memory (a side band like ECC, or a tag table with a cache; 1 bit per 8 bytes is 1.6% of memory), set only by pointer-producing operations, cleared by an ordinary store and by a DMA write.
- *Granule colouring and the reserved colours* (errata 84, items 1 and 2: "do it, no delay", to be specified; the pointer-bit rule is open, J.A.1): a colour in the pointer and in the memory granule, compared on an access; it does not propagate through operations.
- The `NS` and `SEC` page bits (errata 86), independent of each other, and `PROBER` and `PROBEW`, which tell a program whether an address is readable or writable in the previous mode (6.2.5, 6.10).
- Not present: an *integrity* taint for untrusted input, propagated through loads, stores and ALU operations, with a policy at the sinks. The `EPSW` masks are 16 bits a lane (study); with 32 registers each lane is 32 bits (`docs/layout-fit-analysis.md`, item 16, open).

**Why it matters.** Injection (a command, a path, a format string, a query built from input) is the commonest class of software vulnerability, and an application cannot easily check it everywhere. A hardware tag would make the check systematic, at a cost in state, in opcodes and in the context switch, and at the risk that, as with every dynamic taint system, a precise propagation rule is either too weak (missed flows) or too strong (false alarms).

**How hard is this with the current opcodes** (the assistant's analysis, labelled; counts from the encoding of the grammar).

(a) *In an interpreter or a language runtime, as Perl does it: no architecture is needed.* Perl keeps the mark in the value: a scalar has taint magic (`PERL_MAGIC_taint`, `SvTAINTED`, `sv.h`, `mg_vtable.h`) and a global `PL_tainted` says that the operation in progress touched tainted data; the sinks call `TAINT_PROPER`, which croaks (`perl.h`; all read in the Perl headers on this machine). The pdp64 runs this as any machine does.

(b) *A compiler-inserted shadow memory scheme (LLVM `DataFlowSanitizer` style) on the current opcodes.* A shadow byte for each byte of memory (or for each 8 bytes) lives at a fixed offset from the data. Per memory access: with a shadow byte for each byte, one extra instruction, `movzb (r9)(r1*1), r5` for a load and `movb r5, (r9)(r1*1)` for a store, 4 bytes each (the scaled-index form with a dedicated base register `r9`); a shadow byte for each 8 bytes needs the shift as well: `movq r1, r5`, `shr #3, r5` and the load or store: 3 extra instructions and 8 bytes. Per ALU operation: the OR of the two shadows, `bis`, 2 bytes, if the shadows are kept in a parallel register set; the machine has 32 registers, so a parallel set is not available, and either shadows are spilled or they are packed into one mask register and moved with `EXTZB` and `INSB` (6 bytes each, 9.9.2), which makes one ALU operation 4 instructions and 20 bytes (two `EXTZB`, one `BIS`, one `INSB`). Per sink: a test of the shadow and a branch (`cbne`, 2 to 4 bytes). The block operations `MCPY` and `MSET` copy and clear shadow ranges in bulk. A bit shadow needs the atomic `XOR_` (fetch-or) of the `ATOM` group (4 bytes) for a store, because two threads share a shadow byte; byte shadows need none. *Cost, an estimate:* in a mix of about 30% loads and stores and 40% ALU operations, the added instructions are about 0.3 x 1 to 3 plus 0.4 x 4 per original instruction, 2 to 3 more instructions for each one, and a slowdown of 2 to 4 times and a memory cost of 100% (byte shadow) or 12.5% (an 8-to-1 shadow); that matches the general experience of published dynamic taint tools (libdft, DFSan, TaintCheck) *(unverified: general knowledge)*. *What it takes (an estimate):* a compiler pass (LLVM already has the framework; about 20 to 40 agent-hours to run on this target), a runtime for the shadow region and the wrappers of the C library functions that move data (about 10 to 20 agent-hours), and kernel support for the shadow pages and for the system calls as sinks (about 10 to 20 agent-hours), 40 to 80 agent-hours in all, assuming the LLVM port exists first (errata 137); no new instruction.

(c) *A kernel-enforced coarse scheme with the page bits that exist.* A page class for input buffers, and `PROBER` and `PROBEW` to test the pages of the arguments of a system call. 0 opcodes; page granularity, so a tainted page taints everything on it (false alarms); a copy from a tainted page to a clean one escapes unless laundered; cheap, weak.

(d) *Colours as provenance.* A colour for "from outside". The colour check compares the pointer's colour with the memory's and does not propagate; and no instruction reads a colour yet (items 1 and 2 are to be specified), so it needs that first. It tells where a buffer came from, not what a value computed from it is.

(e) *The secret-taint lane for integrity.* The same propagation rule with different sinks (system call arguments, `exec` paths), by a second set of masks or a mode flag. Possible; but the secrecy sinks are timing sinks, and the integrity sinks are system calls and addresses of the kernel, so the enforcement logic differs and the lane is not reusable as it is.

(f) *A full hardware scheme.* A fourth lane per register beside poison, secret and valid-pointer (32 bits more in a saved word at 32 registers), a tag bit per word of memory shared with the pointer tag (2 bits per 8 bytes: 3.1% of memory), a tag cache, `TAINT` and `UNTAINT` words in the shape of `SECRET` and `DECLASSIFY` (2 words, 0 patterns in `R2`, with a sink mask in `EPSW` or in a system register), tag-set on input by the I/O memory-management unit or the memory controller for device writes, and the context-switch state. At the heavy end, programmable metadata hardware (a rule cache that applies a software policy to each instruction, the Draper PUMP and SDMP *(unverified)*) replaces the fixed rule. Opcode cost: 2 to 4 words in `R2` (free), a sink-mask register (a system register number), and no new prefix leaf. Gates: an OR gate per lane per ALU result (the propagation), a tag-cache port, and a comparator at each sink (estimates, general knowledge).

**Options.**

1. *None in hardware: runtime taint as in Perl, and a compiler shadow scheme on the current opcodes.* 0 patterns. For: nothing to specify, verify or save; works now; the 40 to 80 agent-hour estimate above. Against: the 2 to 4 times slowdown and the memory cost make it a testing tool and not an always-on defence; no protection against code outside the compiled program.
2. *Page-level taint with the page bits and the probe instruction.* 0 patterns, kernel work only. For: cheap; the kernel can refuse a tainted page as a system call argument. Against: page granularity; false alarms; copies need laundering; weak.
3. *Provenance by colour.* 0 patterns beyond what items 1 and 2 already take, plus one instruction to read a colour. For: reuses a decided mechanism. Against: it does not propagate, so it marks buffers and not values; needs the colour specification first.
4. *A fourth lane (untrusted) beside poison, secret and valid-pointer, with per-word memory tags shared with the pointer tag.* 2 to 4 words in `R2` (0 patterns); the saved word grows by a lane; the tag side band doubles to 2 bits per 8 bytes. For: Perl's model for compiled code at the cost of one OR per ALU result; deterministic like the secret lane; shared tag storage. Against: more state in the context switch and the exception frame; DMA and device writes must set tags; a policy at the sinks needs the kernel and compiler to agree; the over-tainting problems of every dynamic taint system; it widens the memory path.
5. *The full programmable metadata unit.* Words: a handful; gates: large. For: any policy, including integrity, secrecy and colour, in one mechanism. Against: heaviest in gates and verification; the research hardware that has it is not in a product *(unverified)*.
6. *Taint only for secrecy, as item 11: no integrity taint.* 0 patterns. For: nothing more to specify; matches the decisions; the kernel and the language runtimes keep the integrity checks they have. Against: no hardware help for injection.

**Precedents.** Perl's own implementation (verified in `perl.h`, `sv.h` and `mg_vtable.h` of the installed headers). OpenBSD `pledge` and `unveil` as the policy alternative: they restrict what a process may do, not where a value came from (`sys/kern/kern_pledge.c`, `kern_unveil.c` exist in the OpenBSD tree on this machine; verified). The Linux kernel's "tainted" flags (`TAINT_*` in `include/linux/panic.h`, read) are a different thing: they record that the kernel as a whole has run in an unsupported state (a proprietary module, a forced module, an out-of-spec CPU), not the origin of data. Unverified, from general knowledge: SPARC M7 Application Data Integrity, ARM Memory Tagging Extension, the CHERI tag bit, the Intel iAPX 432, Burroughs and Lisp-machine tagged memory, the dynamic information-flow tracking papers of Suh and others (2004), RIFLE, Raksha, FlexiTaint, and the libdft, DFSan and TaintCheck software tools.

**The author's referents.** "also perl taint mode, bits for each word in ram, to mark where the bytes came from, tagging.... do we have something like that already?" and "so right now, tell me how hard this would be to do with current opcodes (as per the full design), the taint thing as in perl" (errata 138); errata 84 items 3, 10 and 11, errata 85 and 86 (the poison, secret and valid-pointer lanes decided in outline).

**The assistant's leaning.** Option 1 now, because the machine can run it today and the estimate is 40 to 80 agent-hours; keep options 4 and 6 open until the poison and secret lanes (J.9.12) are specified, since a fourth lane shares their design and the tag side band; do not take option 5. This item asks whether to add an input-taint lane and per-word tags; the mechanisms of poison, secret taint, the valid-pointer tag, colours and the page bits stand as decided. This is the assistant's view, not a decision.

**Where the body refers to it.** Section 6.4.4 and section 9.21.1.
