<a id="j91"></a>
### J.9.1 The expansions of ABS, MIN, MINU, MAX and MAXU

**Issue.** The pdp64 has no flags, so there is no conditional move that reads them. What it has for choosing between two values without a branch is `SETCC` (it compares two registers, or a register and an immediate, and writes 1 or 0), the pair `MASKEQZ` and `MASKNEZ` (each tests one register against zero and gives either zero or the other operand: `rd = rc == 0 ? 0 : ra`, and the opposite) and the bit select `BSEL`. I have decided that `ABS`, `MIN`, `MINU`, `MAX` and `MAXU` are assembler aliases (words the assembler expands into other instructions), not native instructions, and that the manual entry of each shows the alias. I said I was happy for them to be aliases on top of a select ("`cmov`, `csel`, `fsel`"), but nothing yet says which select, or what each alias expands to. None of the five writes anything but its destination.

**Why it matters.** Until the expansion is fixed the entries of the five words cannot show it (section 9.7.6). Kernel code uses clamps and minimum and maximum in size computations, and a constant-time select is wanted for checking message-authentication codes and handling keys. A compiler must know whether a comparison used as a value may become a select, and an optimizer that is free to turn a select back into a branch would break the constant-time promise (J.9.2), so the ABI needs a rule. An alias that needs scratch registers needs a rule too: nothing is reserved except `R12`, which is the linker's, and an alias that silently uses a register would be a strange side effect. How often the words matter is measured on the compiled corpus (amd64, optimized for size): 18 `abs` sites, 5 unsigned, 171 `min` and 52 `max` in 95 files, under 0.1% of code.

**Counting convention.** `MOVQ`, `BIS` and `NEG` between registers are 2 bytes; `SETCC`, `MASKEQZ`, `MASKNEZ`, `BSEL`, `CBCC` and any new select are 4 bytes. These are estimates to be checked against the assembler.

**Options.**

1. *`SETCC` plus `MASKEQZ` and `MASKNEZ`, no new instruction.* The aliases expand over what is adopted. `MIN a,b,d` is `SETLT a,b,c ; MASKEQZ a,c,t ; MASKNEZ b,c,d ; BIS t,d` (4 instructions, 14 bytes, two scratch registers). `ABS` needs no select: `ASR a,#63,m ; XOR m,a,d ; SUB m,d` (3 instructions, one scratch register). For: no new opcode; one select for everything; constant time by construction; no gates. Against: 3 more instructions and about 10 more bytes per `MIN` or `MAX` site than a native word (on the corpus a few hundred instructions, about 0.3% of instructions, an estimate from amd64 counts); the assembler needs scratch registers; four hidden instructions behind one word.
2. *A register-conditioned select, `SELECT rc, ra, rb, rd`.* `rd = rc != 0 ? ra : rb`, three source registers in one instruction (the four-register 4-byte form exists: `FMADD` has four register fields). `MIN` is `SETLT a,b,c ; SELECT c,a,b,d` (2 instructions, 8 bytes); `MASKEQZ(a,c)` is `SELECT c,a,zero`, so it replaces the two mask instructions or sits beside them. For: a constant-time select in 1 instruction instead of 3; `MIN` in two instructions and no scratch register but `c`, which may be `d`. Against: it reopens the adoption of `MASKEQZ` or adds a third entity (Ockham, my rule: do not multiply entities without benefit); a 4-byte leaf and its gates.
3. *Bit select, `BSEL rm, ra, rb, rd`, as the only select.* `BSEL` is decided (9.9.6, 9.20.4); this option is to use it also as the select for the aliases and drop the mask pair's role in them. `rd = (rm & ra) | (~rm & rb)`, with the mask made from the condition. `MIN` is `SETLT a,b,c ; NEG c,m ; BSEL m,a,b,d` (3 instructions, 10 bytes). For: nothing new, since the instruction is adopted (it is the Ch and Maj functions of SHA-2 and the constant-time swap); selects any width and bit pattern. Against: the scalar select needs a `SETCC` and a negate before it; a four-register form.
4. *No select: a compare-and-branch over a move.* `MOVQ a,d ; CBLE a,b,over ; MOVQ b,d` (`over` is the next instruction after the second move). A core may fuse a forward branch over one instruction into a single micro-operation, so the sequence costs nothing on cores that fuse and is promised nothing on cores that do not. For: nothing new in the architecture; 3 instructions, 8 bytes. Against: it branches on data, so `MIN`, `MAX` and `ABS` cannot stay on the list of always-constant-time instructions, which contradicts the decided secure core and my "no timing channel attacks"; a data-dependent branch mispredicts at a rate that depends on the data.

**Precedents.**

* ARM64 `CSEL`, `CSINC`, `CSINV`, `CSNEG` select by flags, and Arm's data-independent-timing guarantee lists conditional select among the instructions covered *(verified)*. x86 `CMOVcc`, SPARC V9 `MOVcc`, s390x `LOCR`, Alpha `CMOVxx` *(unverified: general knowledge)*; all of them read flags or a register, and the pdp64 has no flags.
* LoongArch `maskeqz` and `masknez` and RISC-V Zicond `czero.eqz` and `czero.nez` are exactly the mask pair; RISC-V's base set has no select *(unverified: general knowledge)*. RISC-V Zbb has native `min`, `minu`, `max`, `maxu` and no `abs` *(unverified)*.
* MIPS `MOVN` and `MOVZ`, and Alpha `CMOVxx` (which tests a register against zero), are register-conditioned selects *(unverified)*.
* ARM NEON `BSL`, `BIT`, `BIF` and the x86 ternary-logic instruction `VPTERNLOG` are bit selects *(unverified)*; `BSEL` in the secure-core design *(verified)*.
* The PDP-11 and the VAX have no select and compilers emit a branch; a few high-performance RISC-V cores fuse a short forward branch with the instruction after it *(unverified: general knowledge)*.

**My referents.** `cmov`, `csel`, `fsel` (no source machine named): "I am interested in the cmov/csel/fsel ... am happy for abs/min/max to be aliases on top of it in the assembler". On `ABS`, `MIN` and `MAX` as opcodes: "add them. and if we have to teach the front end about abs/min/max nodes that is fine ... surely other cpus have these opcodes". Ockham's rule: "don't multiply entities without benefit" and "no weird side effects, no bumping other opcodes in a way that makes code size increase". The PDP-11 `ROL` as an alias of `ROR` ("the assembler could take rol and map it to ror"). Floats live in the general registers. "No timing channel attacks."

**My leaning.** Option 1 for the architecture: `MASKEQZ` and `MASKNEZ` stay the one select, `ABS` expands without a select (`ASR`, `XOR`, `SUB`), and the manual says plainly that the assembler needs reserved temporary registers. If `MIN` and `MAX` in hot loops prove to matter, option 2 can be added later in the same sub-opcode block and the same aliases then shrink from 4 instructions to 2 without anyone rewriting source. This is my view, not a decision. It would change if a compile showed `MIN` or `MAX` inside hot loops.

**Where the body refers to it.** Sections 9.7.6, 9.20.3 and 9.21.1; and the dictionary entries of `ABS`, `MIN`, `MINU`, `MAX`, `MAXU` and `MASKEQZ`.

<a id="j92"></a>
### J.9.2 Constant-time execution: what holds while `DIT` is clear, and where `DIT` lives

**Issue.** A timing channel is a leak of secret data through how long an instruction takes, when the time depends on the operand values. "Constant-time" means that the architecture promises that an instruction takes the same time whatever the data (data-independent timing, the property that cryptographic code needs). It is necessary but not sufficient: a secret-dependent branch, address or table index still leaks through the branch predictor and the cache. I want "a constant time flag or something so instructions always take an equal amount of time no matter the input"; on 2026-11-04 I decided that add and divide need not take the same time as each other, "only they are timing independent of their data", and that "for non-sensitive things, constant time isn't a priority". Two things are decided. Section 9.3.7 states a bit `DIT` in the status word, set by the program, that promises data-independent timing while it is set (I took the contract of the architecture recommendations; a mode bit that is saved with the status word is what I called a freebie). And it was decided that at least one secure core has every timing channel removed. Two things are open. **First, what is promised while `DIT` is clear:** nothing, a published list of instructions that never vary, or every integer instruction. **Second, the position of the bit:** bit 12 of the 16-bit status word is `UA`, bits 13 to 15 are free and read as zero, and the saved status word of an exception frame carries whichever bit is chosen.

**Why it matters.** The fast paths (an early exit from divide, from the block scan `MSCN`, from a multiplier) are gates and speed, and a fixed-latency multiplier is smaller than an early-out one. A core must be able to disable each fast path while `DIT` is set. The compiler must not reorder, replace or turn into branches the instructions that are promised to be constant-time, and the manual must list them; no instruction timing is stated in the instruction set today. Measured on 827 compiled files (370,115 instructions): divide 149 (0.040%), block copy 154, floating-point divide 10, multiply 2,204 (0.595%), `MSCN` none. A fixed worst-case divide is estimated to slow a whole program by about 1% (assuming 64 cycles worst and 30 average; an estimate, not run time data). The position of the bit fixes the format of the saved status word that the kernel, the debugger and the signal frame share.

**Options** (for what holds while `DIT` is clear).

1. *Nothing: `DIT` is the only promise.* Every instruction may have fast paths, and code that needs constant time sets the bit. For: nothing more to specify; fast paths stay for normal code. Against: software forgets to set it, and a default of "insecure" is the one that a 2026 kernel post calls unacceptable; an out-of-order core has to hold the promise through the whole pipeline and not only in the arithmetic unit.
2. *A published core list that is always constant-time, with `DIT` for the rest.* The architecture lists the instructions that always take data-independent time (add, subtract, logic, shifts and rotates, `MUL`, `MULH`, `MULHU`, `CLMUL`, `POPCNT`, `CLZ`, `BSWAP`, `BITREV`, `SETCC`, `MASKEQZ`, `MASKNEZ`, and the expansions of `ABS`, `MIN` and `MAX` once J.9.1 fixes them); `DIV`, `MOD`, floating point, `MCMP`, `MSCN`, `MSCNN` and `MVAL` need the bit. For: the common case is free, the rare instructions are covered when asked, and software may rely on the list on every core; a fixed multiplier needs fewer gates. Against: two things to specify and test; the list must be kept as instructions are added; any expansion in J.9.1 that branches on data is off it.
3. *Every integer instruction always constant-time, a prohibition list, `DIT` for floating point and the scanners only.* `DIV` always takes its worst-case time. For: the simplest to specify and verify; fewest gates in the fast-path logic. Against: an average divide is slower (about 1% over a program, and loops that divide on every iteration weigh many times more); `MSCN` loses its early exit; it contradicts "not a priority" for non-sensitive code.
4. *The promise on a class of core.* The strong promise lives on the decided secure class (identified by a class register; `DIT` reads 1 and is fixed on it; every instruction fixed-latency, caches private, speculation absent). On general cores `DIT` is a promise of the instructions in the list of option 2, and a core says in a feature register what it cannot hold. For: the strongest guarantee where it is needed, covering the cache and the bus that a mode bit cannot reach; the general cores stay fast. Against: a second core design to build and verify; general cores that run secrets have no promise beyond the list.

**The position.** Bit 13, the next free bit above `UA`, keeps the used bits together; bit 15 leaves 13 and 14 for later. For bit 13: no gap in the status word, and the save and restore is one mask. Against: a later mode bit that the kernel wants next to `UA` will not have the place.

**Precedents.**

* Arm's `DIT` bit in the processor state, which Linux on arm64 enables in the kernel "to be cautious" *(verified)*.
* Intel's `DOITM`, with the vendor saying it does not recommend enabling it globally and kernel posts (July 2026) saying it is best left on *(verified)*.
* RISC-V scalar crypto extension Zkt: an implementer declares a subset of instructions with latency independent of the data values, a promise and not a mode *(verified)*.
* x86 before `DOITM`: Intel published a guidance list and later found that AES-NI and `ADD` and `XOR` varied on later parts, so the drift is the precedent against a list that is only published *(verified)*.
* The repository's own secure class, with `DIT` reading 1 and fixed on it, a class register, a reserved bus slot and a private window *(verified)*.
* Small cryptographic microcontrollers with a fixed-cycle multiplier and divider, such as the Cortex-M0+ with its single-cycle multiplier option *(unverified: general knowledge)*.

**My referents.** The failures to avoid: "no hammer-row, no spectre, no timing channel attacks; there should be constant time flag or something so instructions always take an equal amount of time no matter the input". On cost: "I wonder how much that would slow a processor down ... for non-sensitive things, constant time isn't a priority". "Mode bits are case by case, but in general should be visible, not hidden state. putting modes in bits that are saved anyway sounds like a freebie." Cryptography on separate devices on the PCI bus, "so they can pay the price of constant time computation".

**My leaning.** Option 2 with the secure class of option 4 as the strong form, the published list written into the manual now, `DIT` saved with the status word and the compiler treating the list as untouchable; and bit 13. This is my view, not a decision. It would change if a cycle measurement showed divide in hot loops (option 2 stays, option 3 is dropped), or if hardware cannot cheaply disable a fast path (the instruction goes off the list).

**Where the body refers to it.** Sections 9.3.7 and 9.21.1.

<a id="j93"></a>
### J.9.3 Addressing-mode gaps: the scaled-index displacement and a store through `d(DP)`

**Issue.** The scaled-index mode `d(Rn)(Rx*s)` exists for the array of structures. Its shortest form (two parcels) has a displacement of 6 or 8 bits, so ±32 to ±128 bytes before it takes three parcels and a 22-bit displacement (9.5.1). The mode `d(DP)`, the direct page that serves the thread pointer and the per-CPU pointer, has a load form of six bytes and no store form in the grammars (9.3.5).

**Why it matters.** Code that walks an array of records touches fields beyond 32 bytes and pays two more bytes for each; a thread-local store needs a separate address computation.

**Options.**

1. *Leave both as they are.* For: nothing changes; the three-parcel forms exist. Against: the cost is paid in the hot loop of the array of structures and in every thread-local store.
2. *Reduce the scale to one bit (x1 or x8) and give the bit to the displacement.* For: one more bit of displacement. Against: the scales 2 and 4, which index 16- and 32-bit arrays, are lost; the compiler's best case (`bs_ec`'s inner loop, 31% fewer instructions) uses the scaled index.
3. *Add a two-parcel scaled-index leaf with hot registers for the base and the index.* The register fields shrink, so the displacement grows. For: serves the common case with the registers the allocator prefers. Against: a prefix spent on one leaf; a compiler rule for which registers qualify.
4. *Add a store form through `d(DP)`, six bytes, one word for each size.* For: symmetrical with the load; one instruction for a thread-local store. Against: spends prefix space on a form that the compiler may use rarely.
5. *Add two-parcel `d(DP)` forms with a 12-bit displacement for loads and stores.* For: most thread-local and per-CPU blocks are small; four bytes instead of six. Against: the 28-bit load form still stands beside it.

**Precedents.** x86 scaled index with a 32-bit displacement; AArch64 scaled register offset with no displacement and an unsigned scaled 12-bit offset; the VAX index mode that follows any other mode *(all unverified: general knowledge)*. The 6502's zero page is the ancestor of `DP` *(stated in chapter 9)*.

**My referents.** The PDP-11 as the base ("update and refresh of the pdp-11 instruction set and architecture"); Ockham's rule: "don't multiply entities without benefit".

**My leaning.** Option 1 until a compiled corpus shows how many array accesses lie beyond 32 bytes. This is my view, not a decision.

**Where the body refers to it.** Sections 9.5.3 and 9.21.1.

<a id="j94"></a>
### J.9.4 The page-bit mechanisms and the stack-limit register

**Issue.** I approved three mechanisms "to be specified": a page bit that gates landing pads, so that an indirect transfer that does not land on `LPAD` faults, with the fault attributed to the branch (item 5); a page bit that says a system call may be made from this page (item 8); and a stack-limit register checked when a system call or a fault is taken (item 4). The retire-stage study found that they need no opcode, and the instruction set has no word reserved for them. The page-table entry has no bit for either page bit (the entry is full below bit 40 and the format for wide physical addresses is open, J.6.1).

**Why it matters.** The bits and registers must be in the page-table entry and the system-register list before the kernel and the linker are written.

**Options.**

1. *No opcodes: enable bits in a system register and enforcement bits in the page-table entry.* For: nothing to execute; matches the retire-stage study. Against: needs two page-table bits, which compete with the wide-physical-address format.
2. *One system word for each mechanism.* A privileged word sets or clears the mechanism for the current address space. For: explicit, and a privileged instruction is easy to trap. Against: a new opcode for each, and a mode that an instruction changes (the rule of 9.2.5 is that modes are visible state).
3. *A page-attribute instruction that sets bits of the entry for an address.* For: the kernel need not walk the table to change an attribute. Against: an instruction with a translation-buffer side effect, and the format of the entry must have room.

**Precedents.** Intel's indirect-branch tracking is enabled by a bit in a model-specific register and ends a branch on a missing `ENDBR`; ARM's branch-target identification is a page attribute in the translation-table entry *(both unverified: general knowledge)*; OpenBSD's `msyscall` and `pinsyscalls` check where a system call comes from in software, and OpenBSD enforces landing pads by default where the hardware has them (appendix A, from the reports).

**My referents.** "Do it, no delay" for the colours of memory; landing pads gated by a page bit, "with the fault attributed to the branch"; "minimize recovery code".

**My leaning.** Option 1, since the study found no opcode is needed. This is my view, not a decision.

**Where the body refers to it.** Sections 9.21.1, A.1.2, A.2.2 and A.3.2. The schedule of landing pads in the ABI is J.D.2.

<a id="j95"></a>
### J.9.5 The worst-case latency of the block operations

**Issue.** An ordinary instruction is bounded: at most six bytes of fetch across two pages and one memory operand across two pages. A block operation (`MCPY`, `MSET`, `MCMP`, `MSCN` and the rest, 9.11.3 is not bounded by its definition; it keeps its progress in registers and may be interrupted between steps, and an implementation may move more than a byte per step provided the registers are consistent where an exception can be taken (9.11.5). So an interrupt-latency figure depends on the step.

**Why it matters.** A claim of real-time response rests on a bound. Until the step is stated, the claim is an argument and not a number.

**Options.**

1. *No architectural bound: each implementation states its granularity.* For: freedom to move a line or a page at a time. Against: software cannot rely on a latency.
2. *An architectural maximum between interrupt checks (one cache line, 64 bytes).* For: a bound that holds on every core. Against: ties a fast engine to a small step.
3. *An architectural maximum of one page between checks (4 KiB).* For: the largest unit with a single translation; bulk engines work at full speed. Against: tens of microseconds of latency on a slow memory.
4. *A feature register that reports the granularity.* For: software reads the figure. Against: it is information and not a promise.

**Precedents.** x86 `REP MOVS` is interruptible between iterations and its progress is in registers; ARM's `FEAT_MOPS` leaves the progress in registers; the VAX `MOVC` kept a first-part-done bit in the status word *(all unverified: general knowledge)*.

**My referents.** The VAX `MOVC5` as the argument against hidden state (9.11); the registers as the only progress.

**My leaning.** Options 1 and 4 together: no bound in the architecture, the granularity reported in a register. This is my view, not a decision.

**Where the body refers to it.** Sections 9.11.5 and 9.21.1.

<a id="j96"></a>
### J.9.6 The block operations and the data cache

**Issue.** A one-megabyte `MCPY` evicts the whole data cache for data that is never read again; it shows at once on a cache of 8 KiB. Every real `memcpy` on a machine with non-temporal stores uses them for this reason. An inference workload that moves tens of megabytes through a cache of a few kilobytes is the extreme case.

**Why it matters.** The kernel's working set is what a large copy destroys; and the fix is an opcode, a memory type or a rule inside the core, and only the first two are visible to software.

**Options.**

1. *Do nothing: leave the cache alone.* For: no new opcode or memory-type value. Against: the eviction is real.
2. *A non-temporal variant of the block operations.* For: the program says that the data will not be read again. Against: a new sub-opcode and a rule that the data may not be cached.
3. *A streaming value of the memory-type field of the page-table entry.* For: no opcode; a buffer is declared streaming once, and every access to it, by the block operations or not, follows. Against: the kernel must set it per mapping; a wrong type slows ordinary access.
4. *The implementation decides by length.* For: invisible to software. Against: a performance cliff with no architectural visibility, the worst of the options.

**Precedents.** x86 non-temporal stores (`MOVNT*`) and fast-string moves that avoid the cache above a threshold; ARM non-temporal load and store pairs *(all unverified: general knowledge)*.

**My referents.** The memory type as a page attribute (adopted from LoongArch, 9.20.2).

**My leaning.** Option 3, because the streaming workload is known by buffer, not by instruction. This is my view, not a decision.

**Where the body refers to it.** Sections 9.11.5, 9.21.1 and A.9.

<a id="j97"></a>
### J.9.7 Directed rounding

**Issue.** IEEE 754 requires rounding toward positive infinity, toward negative infinity and toward zero, as well as to nearest, for add, subtract, multiply, divide, square root, fused multiply-add and the conversions. The manual decides that there is no rounding-mode register or bit and that the rounding is in the opcode wherever it is not nearest-even (9.12.5); but no arithmetic opcode takes a rounding mode, only the `FRINT` family does. A conforming C library keeps the dynamic mode of `fesetround` in thread-local storage and dispatches on it.

**Why it matters.** Interval arithmetic and the C99 `<fenv.h>` conformance depend on directed rounding.

**Options.**

1. *None: software emulates the modes.* For: nothing to add; the library's dispatch is the present answer. Against: it is slow, and the letter of the C standard is not met by hardware.
2. *A two-bit static rounding field in the instruction.* The `FESC` two-register forms have a free nibble; the four top-level operations have none. For: the mode is in the opcode as 9.12.5 says. Against: only the escape forms can carry it.
3. *Extra opcodes for the six core operations* (add, subtract, multiply, divide, square root, fused multiply-add) *in each of the three directions.* For: no field. Against: eighteen opcodes.

**Precedents.** RISC-V's floating-point instructions carry a static rounding-mode field with a dynamic value; ARM has a rounding-mode field in `FPCR`; x86 `AVX-512` has embedded rounding control *(all unverified: general knowledge)*.

**My referents.** "No rounding-mode or precision mode bits" (9.12.5), the rule that a mode bit is by default visible state set by an instruction that names it (9.2.5).

**My leaning.** Option 1 until a libm port asks. This is my view, not a decision.

**Where the body refers to it.** Sections 9.12.6 and 9.21.1.

<a id="j98"></a>
### J.9.8 The coherence protocol beyond four cores, and the verification of the memory model

**Issue.** The memory model is sequentially consistent (9.2.8, decided), and the machine has at least four cores with sixteen or more as the preferred ceiling that no decision may preclude. The protocol chosen for two to four cores is snooping (invalidation by watching a shared bus, the simplest protocol); at eight or more cores a snooping bus is the wrong protocol, and the one for sixteen is not chosen. Separately, a declaration of sequential consistency is not an implementation: it is easy to violate by a store buffer that forwards wrongly or a cache that reorders fills, and the litmus tests of the published suites must be run before a second core exists.

**Why it matters.** The cache and its protocol must be chosen before the cache is built, not retrofitted; the litmus testing is a verification task that belongs in the plan before silicon.

**Options** (the protocol).

1. *Snooping up to four cores, and the ceiling is four.* For: the smallest design. Against: contradicts the decided sixteen.
2. *Snoop filters or a directory per cache slice.* For: scales to sixteen and beyond; the usual answer. Against: a large structure and a protocol with many states.
3. *Clusters of four that snoop, joined by a directory.* For: small clusters stay simple. Against: two protocols to verify.
4. *Software coherence between clusters.* For: cheap in hardware. Against: fragile, and it breaks the sequentially consistent model across clusters.

**Precedents.** x86 snoop filters and directories across sockets, ARM coherent interconnects *(unverified: general knowledge)*.

**My referents.** "yeah let's have 4 cores minimum, 16 or more preferred".

**My leaning.** Option 3 or option 2, decided before the cache is designed; the litmus tests run on the model first. This is my view, not a decision.

**Where the body refers to it.** Section 9.21.1.

<a id="j99"></a>
### J.9.9 Provenance and taint tags: input taint of the Perl kind, tag bits in RAM

**Issue.** Perl's taint mode marks data that comes from outside the program (the command line, the environment, files, the network) as *tainted*. Operations propagate the mark: a string built from a tainted string is tainted. Using a tainted value in a dangerous place (`exec`, `open` for writing, `system`, `eval`, a database query) is an error, unless the program *launders* the value, which in Perl means extracting it with a pattern the programmer has checked. I asked for "perl taint mode, bits for each word in ram, to mark where the bytes came from, tagging", whether the design has something like it, and how hard it would be with the current opcodes. This item answers both and asks whether to add an input-taint (integrity) lane and a tag per word of memory.

**What is decided already, and what is not.** Decided, read in `docs/study-proposals.md`, `docs/retire-stage-candidates.md` and the manual:
- *Secret taint* (study item 11, 86: the leanings followed, "no false positives, precise and deterministic"): a bit per register (`SMASK`), set by `SECRET` or a load from a `SEC` page, propagated by OR, cleared only by `DECLASSIFY`; with `DIT` on, a secret register used as an address, a branch condition, a jump target, the length of a block operation or a divisor faults. Memory: stage 1 faults a store of a secret register to a page that is not `SEC`, so the taint of memory is page-level; stage 2, a bit per 8-byte word, shares the side band of the tag below. It is a confidentiality check, with timing sinks.
- *Valid-pointer tag* (study item 3, stage 1, kept): a bit per register and per naturally aligned 8-byte word of memory (a side band like ECC, or a tag table with a cache; 1 bit per 8 bytes is 1.6% of memory), set only by pointer-producing operations, cleared by an ordinary store and by a DMA write.
- *Granule colouring and the reserved colours* (items 1 and 2: "do it, no delay", to be specified; the pointer-bit rule is open, J.A.1): a colour in the pointer and in the memory granule, compared on an access; it does not propagate through operations.
- The `NS` and `SEC` page bits, independent of each other, and `PROBER` and `PROBEW`, which tell a program whether an address is readable or writable in the previous mode (6.2.5, 6.10).
- Not present: an *integrity* taint for untrusted input, propagated through loads, stores and ALU operations, with a policy at the sinks. The `EPSW` masks are 16 bits a lane (study); with 32 registers each lane is 32 bits (`docs/layout-fit-analysis.md`, item 16, open).

**Why it matters.** Injection (a command, a path, a format string, a query built from input) is the commonest class of software vulnerability, and an application cannot easily check it everywhere. A hardware tag would make the check systematic, at a cost in state, in opcodes and in the context switch, and at the risk that, as with every dynamic taint system, a precise propagation rule is either too weak (missed flows) or too strong (false alarms).

**How hard is this with the current opcodes** (my analysis, labelled; counts from the encoding of the grammar).

(a) *In an interpreter or a language runtime, as Perl does it: no architecture is needed.* Perl keeps the mark in the value: a scalar has taint magic (`PERL_MAGIC_taint`, `SvTAINTED`, `sv.h`, `mg_vtable.h`) and a global `PL_tainted` says that the operation in progress touched tainted data; the sinks call `TAINT_PROPER`, which croaks (`perl.h`; all read in the Perl headers on this machine). The pdp64 runs this as any machine does.

(b) *A compiler-inserted shadow memory scheme (LLVM `DataFlowSanitizer` style) on the current opcodes.* A shadow byte for each byte of memory (or for each 8 bytes) lives at a fixed offset from the data. Per memory access: with a shadow byte for each byte, one extra instruction, `movzb (r9)(r1*1), r5` for a load and `movb r5, (r9)(r1*1)` for a store, 4 bytes each (the scaled-index form with a dedicated base register `r9`); a shadow byte for each 8 bytes needs the shift as well: `movq r1, r5`, `shr #3, r5` and the load or store: 3 extra instructions and 8 bytes. Per ALU operation: the OR of the two shadows, `bis`, 2 bytes, if the shadows are kept in a parallel register set; the machine has 32 registers, so a parallel set is not available, and either shadows are spilled or they are packed into one mask register and moved with `EXTZB` and `INSB` (6 bytes each, 9.9.2), which makes one ALU operation 4 instructions and 20 bytes (two `EXTZB`, one `BIS`, one `INSB`). Per sink: a test of the shadow and a branch (`cbne`, 2 to 4 bytes). The block operations `MCPY` and `MSET` copy and clear shadow ranges in bulk. A bit shadow needs the atomic `XOR_` (fetch-or) of the `ATOM` group (4 bytes) for a store, because two threads share a shadow byte; byte shadows need none. *Cost, an estimate:* in a mix of about 30% loads and stores and 40% ALU operations, the added instructions are about 0.3 x 1 to 3 plus 0.4 x 4 per original instruction, 2 to 3 more instructions for each one, and a slowdown of 2 to 4 times and a memory cost of 100% (byte shadow) or 12.5% (an 8-to-1 shadow); that matches the general experience of published dynamic taint tools (libdft, DFSan, TaintCheck) *(unverified: general knowledge)*. *What it takes (an estimate):* a compiler pass (LLVM already has the framework; about 20 to 40 agent-hours to run on this target), a runtime for the shadow region and the wrappers of the C library functions that move data (about 10 to 20 agent-hours), and kernel support for the shadow pages and for the system calls as sinks (about 10 to 20 agent-hours), 40 to 80 agent-hours in all, assuming the LLVM port exists first; no new instruction.

(c) *A kernel-enforced coarse scheme with the page bits that exist.* A page class for input buffers, and `PROBER` and `PROBEW` to test the pages of the arguments of a system call. 0 opcodes; page granularity, so a tainted page taints everything on it (false alarms); a copy from a tainted page to a clean one escapes unless laundered; cheap, weak.

(d) *Colours as provenance.* A colour for "from outside". The colour check compares the pointer's colour with the memory's and does not propagate; and no instruction reads a colour yet (items 1 and 2 are to be specified), so it needs that first. It tells where a buffer came from, not what a value computed from it is.

(e) *The secret-taint lane for integrity.* The same propagation rule with different sinks (system call arguments, `exec` paths), by a second set of masks or a mode flag. Possible; but the secrecy sinks are timing sinks, and the integrity sinks are system calls and addresses of the kernel, so the enforcement logic differs and the lane is not reusable as it is.

(f) *A full hardware scheme.* A fourth lane per register beside secret and valid-pointer (32 bits more in a saved word at 32 registers), a tag bit per word of memory shared with the pointer tag (2 bits per 8 bytes: 3.1% of memory), a tag cache, `TAINT` and `UNTAINT` words in the shape of `SECRET` and `DECLASSIFY` (2 words, 0 patterns in `R2`, with a sink mask in `EPSW` or in a system register), tag-set on input by the I/O memory-management unit or the memory controller for device writes, and the context-switch state. At the heavy end, programmable metadata hardware (a rule cache that applies a software policy to each instruction, the Draper PUMP and SDMP *(unverified)*) replaces the fixed rule. Opcode cost: 2 to 4 words in `R2` (free), a sink-mask register (a system register number), and no new prefix leaf. Gates: an OR gate per lane per ALU result (the propagation), a tag-cache port, and a comparator at each sink (estimates, general knowledge).

**Options.**

1. *None in hardware: runtime taint as in Perl, and a compiler shadow scheme on the current opcodes.* 0 patterns. For: nothing to specify, verify or save; works now; the 40 to 80 agent-hour estimate above. Against: the 2 to 4 times slowdown and the memory cost make it a testing tool and not an always-on defence; no protection against code outside the compiled program.
2. *Page-level taint with the page bits and the probe instruction.* 0 patterns, kernel work only. For: cheap; the kernel can refuse a tainted page as a system call argument. Against: page granularity; false alarms; copies need laundering; weak.
3. *Provenance by colour.* 0 patterns beyond what items 1 and 2 already take, plus one instruction to read a colour. For: reuses a decided mechanism. Against: it does not propagate, so it marks buffers and not values; needs the colour specification first.
4. *A fourth lane (untrusted) beside secret and valid-pointer, with per-word memory tags shared with the pointer tag.* 2 to 4 words in `R2` (0 patterns); the saved word grows by a lane; the tag side band doubles to 2 bits per 8 bytes. For: Perl's model for compiled code at the cost of one OR per ALU result; deterministic like the secret lane; shared tag storage. Against: more state in the context switch and the exception frame; DMA and device writes must set tags; a policy at the sinks needs the kernel and compiler to agree; the over-tainting problems of every dynamic taint system; it widens the memory path.
5. *The full programmable metadata unit.* Words: a handful; gates: large. For: any policy, including integrity, secrecy and colour, in one mechanism. Against: heaviest in gates and verification; the research hardware that has it is not in a product *(unverified)*.
6. *Taint only for secrecy, as item 11: no integrity taint.* 0 patterns. For: nothing more to specify; matches the decisions; the kernel and the language runtimes keep the integrity checks they have. Against: no hardware help for injection.

**Precedents.** Perl's own implementation (verified in `perl.h`, `sv.h` and `mg_vtable.h` of the installed headers). OpenBSD `pledge` and `unveil` as the policy alternative: they restrict what a process may do, not where a value came from (`sys/kern/kern_pledge.c`, `kern_unveil.c` exist in the OpenBSD tree on this machine; verified). The Linux kernel's "tainted" flags (`TAINT_*` in `include/linux/panic.h`, read) are a different thing: they record that the kernel as a whole has run in an unsupported state (a proprietary module, a forced module, an out-of-spec CPU), not the origin of data. Unverified, from general knowledge: SPARC M7 Application Data Integrity, ARM Memory Tagging Extension, the CHERI tag bit, the Intel iAPX 432, Burroughs and Lisp-machine tagged memory, the dynamic information-flow tracking papers of Suh and others (2004), RIFLE, Raksha, FlexiTaint, and the libdft, DFSan and TaintCheck software tools.

**My referents.** "also perl taint mode, bits for each word in ram, to mark where the bytes came from, tagging.... do we have something like that already?" and "so right now, tell me how hard this would be to do with current opcodes (as per the full design), the taint thing as in perl", and the decisions that followed (the secret and valid-pointer lanes decided in outline).

**My leaning.** Option 1 now, because the machine can run it today and the estimate is 40 to 80 agent-hours; keep options 4 and 6 open until the secret lane is specified, since a fourth lane shares its design and the tag side band; do not take option 5. This item asks whether to add an input-taint lane and per-word tags; the mechanisms of secret taint, the valid-pointer tag, colours and the page bits stand as decided. This is my view, not a decision.

**Where the body refers to it.** Section 6.4.4 and section 9.21.1.
