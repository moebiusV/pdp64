# Appendix A. Possible improvements not decided on yet

[← manual index](00-index.md)

**These are ideas that would make the machine better in one respect or another and that nobody has yet turned into a decision.** They come from the reports on kernel pain points, hardware vulnerabilities and OpenBSD's mitigations, and from the open items of the instruction-set text. Each is stated as a possibility, with its benefit, its cost and what other machines do, so that it can be taken up, rejected or promoted to a decision in appendix B. Nothing here is built or specified unless it says so. The same ordering principle as the rest of the book applies: code size, then easy recoverability, then speed and efficiency through fewer gates and tighter hot loops.

## A.1 Reserve a page bit that enforces landing pads

**A.1.1** The `LPAD` instruction marks a legal target of an indirect jump or call; a page bit could make the hardware fault when an indirect transfer lands anywhere else, with enforcement off in ABI version 1 and on from version 2.

*Commentary.* **Precedent.** `LPAD` already exists, and the ABI leaves landing pads off in version 1, with no switch to enforce them. **Trade-offs.** The bit costs one comparator and two bytes per address-taken function, and deciding later gets more expensive because every binary built in the meantime lacks the pads. **Benefits.** It blocks jump-oriented attacks at the transfer, with no recovery code beyond the fault handler that already exists. **Modern comparables.** Intel's indirect-branch tracking and ARM's branch target identification, both of which OpenBSD enforces by default where the hardware has them. **Impact.** *Kernel:* A landing-pad violation is a fault the handler already handles; the kernel sets the page bit at exec time. *Compiler:* The compiler emits `LPAD` at every address-taken function, two bytes each. *Hardware:* One page bit and one comparator on an indirect-transfer target.

## A.2 A page bit that says a system call may be made from here

**A.2.1** A page-table bit could let the hardware refuse a system call from any page not so marked, so that the kernel's check of where a call came from moves into the instruction.

*Commentary.* **Precedent.** OpenBSD's `msyscall` and `pinsyscalls` restrict where system calls may be issued from. **Trade-offs.** One bit and one gate; the kernel would no longer need to check the origin on every call. **Benefits.** About four instructions removed from every system call, and region pinning with no hot-path check. **Modern comparables.** No architecture surveyed has this bit; it is done by the kernel in software. **Impact.** *Kernel:* The kernel no longer checks where a system call came from on every call, which removes about four instructions from each. *Compiler:* None. *Hardware:* One page bit and one gate at the `TRAP` decode.

## A.3 A check of the stack pointer at system-call entry

**A.3.1** The hardware could check that the stack pointer lies in a region registered as a stack when a system call or a fault is taken.

*Commentary.* **Precedent.** OpenBSD checks the stack pointer against a `MAP_STACK` region on system calls and faults. **Trade-offs.** It adds a comparison to entry, which is the path the design most wants short, and gives no benefit over the kernel making the same check. **Verdict so far.** Not recommended; recorded because the question is natural. **Impact.** *Kernel:* None over the check the kernel already makes. *Compiler:* None. *Hardware:* A comparator and a region register on the entry path, which is the path the design most wants short.

## A.4 Protecting the return address

**A.4.1** The return address lives on the data stack, because `CALL` pushes it and there is no link register; there are four ways to protect it: software canaries and OpenBSD's return-address protection in the compiler, a hardware return stack, a shadow stack, and nothing.

*Commentary.* **Precedent.** x86 has the same exposure and uses stack canaries, `retguard` in OpenBSD's clang, and the shadow stacks of Intel's control-flow enforcement; ARM has pointer authentication. **Trade-offs.** A shadow stack is the strongest and brings the most recovery code (a second stack to overflow, switch and unwind), so the analysis does not recommend it by default; software detection costs a few instructions per function and no hardware. **Benefits.** Detection with little or no recovery code. **Verdict so far.** Start with the compiler; consider a hardware mechanism only if code size allows. **Impact.** *Kernel:* A shadow stack is a second stack for the kernel to manage and unwind; software detection needs only a fault handler. *Compiler:* The compiler adds a canary or a return-address check per function. *Hardware:* Software costs nothing; a hardware return stack or a shadow stack costs a second stack structure and its control.

## A.5 Tag or key bits in pointers

**A.5.1** The 25 spare bits of a 64-bit pointer (a 39-bit virtual address uses the rest) could carry a tag or a key, as a memory-tagging or pointer-authentication scheme does.

*Commentary.* **Precedent.** ARM's top-byte-ignore, pointer authentication and memory tagging. **Trade-offs.** The cost is canonical-address rules: pointers must be masked before use, and the hardware must define what a tagged pointer does. **Verdict so far.** No threat that the operating system asked for requires it; it costs gates and state, so it is not recommended now. **Impact.** *Kernel:* The kernel would have to define what a tagged pointer means across the user and kernel boundary. *Compiler:* Every pointer use needs masking, and pointer arithmetic must preserve tags. *Hardware:* Gates and state in the address path.

## A.6 An optional 48-bit address mode

**A.6.1** A fourth page-table level, switched on by a feature bit, could raise the virtual address from 39 to 48 bits.

*Commentary.* **Trade-offs.** The user half of the 39-bit space is 38 bits, which gives address-space randomisation far less entropy than the 47 bits of amd64; the price of fixing it is a longer walk on every miss. **Benefits.** Entropy and a bigger address space for a database or a memory-mapped file. **Modern comparables.** x86-64 and AArch64 have four levels (and x86-64 five); RISC-V offers three, four and five by feature. **Impact.** *Kernel:* A mode for the kernel to switch on, with a fourth-level table to allocate and walk. *Compiler:* None beyond pointer size, which does not change. *Hardware:* A fourth walker level and a longer walk on every miss.

## A.7 A second page-table base register

**A.7.1** A second page-table base for the kernel half of the address space would let a kernel and a user program run with different tables without flushing, if a speculative core ever needs the isolation.

*Commentary.* **Precedent.** The cost of separating kernel and user page tables on x86 after Meltdown was about 5% typical and about 30% in the worst case in the developers' own estimates, and the tagged translation buffers (PCID) made it tolerable. **Trade-offs.** The current single base is correct and free on a core that does not speculate; the second base register costs a register and a rule, and the question is whether to pay it before the need exists. **Benefits.** The isolation is in the hardware from the start. **Modern comparables.** AArch64 has two translation-table base registers, one for each half of the address space. **Impact.** *Kernel:* The kernel switches one base register at the privilege change instead of managing a shared table. *Compiler:* None. *Hardware:* A second base register and a rule choosing which half uses which.

## A.8 Two-byte forms of the user-memory guard instructions

**A.8.1** `STUA` and `CLUA` could have one-parcel page-2 forms, saving four bytes per user-copy routine.

*Commentary.* **Trade-offs.** It uses two of the 19 reserved page-2 slots, which is not worth it until a kernel exists to count the copy routines. **Benefits.** Smaller and faster user copies. **Verdict so far.** Hold the slots and decide when the kernel exists. **Impact.** *Kernel:* Each user copy routine is four bytes smaller. *Compiler:* None. *Hardware:* Two reserved page-2 slots used.

## A.9 Thirty-two-bit forms of add, subtract and shift

**A.9.1** If the extension instructions the compiler emits after narrow arithmetic are more than a few percent of the code, 32-bit forms of the common operations on page 2 would remove them.

*Commentary.* **Precedent.** AArch64's `W` forms and RISC-V's `ADDW` family. **Trade-offs.** A second set of opcodes in the page-2 map against extension instructions in the compiled code; the overhead has never been measured over the whole corpus. **Verdict so far.** Measure first; it is one script over the compiled corpus. **Impact.** *Kernel:* None. *Compiler:* The compiler stops emitting an extension after common 32-bit operations. *Hardware:* A second set of opcodes in the page-2 map and a little ALU decode.

## A.10 Packed-lane instructions in the integer registers

**A.10.1** A small set of lane operations (add, subtract, saturating add, compare, minimum, maximum, average, sum of absolute differences, shuffle on 8, 16 and 32-bit lanes) in the existing registers could speed up string, codec and image loops.

*Commentary.* **Precedent.** Alpha's motion-video instructions and PA-RISC's multimedia instructions did exactly this, in integer registers. **Trade-offs.** It adds no state and little hardware, but it is 64 bits wide so the gain per instruction is modest, and compilers use it poorly. **Verdict so far.** Collect the evidence first: the compiler corpus was built at a size setting that hides how much vectorisable code there is (appendix B, S1). **Impact.** *Kernel:* String and checksum routines get faster. *Compiler:* Vectorisation into integer lanes is weak, so the library routines would be hand-written. *Hardware:* A lane-aware ALU: little extra hardware and no new state.

## A.11 Streaming and non-temporal block operations

**A.11.1** A large `MCPY` evicts the whole data cache for data never read again; a non-temporal variant or a streaming memory type would avoid it.

*Commentary.* **Precedent.** x86 has non-temporal stores; ARM has non-temporal load and store pairs. **Trade-offs.** It shows immediately on an 8 KB cache; the fix is an opcode or a memory type, the non-fix is to leave the cache alone. **Verdict so far.** Open since the instruction-set text's open items; decide when the memory system is built. **Impact.** *Kernel:* Large copies would not evict the kernel's working set. *Compiler:* `memcpy` would choose the streaming form above a size. *Hardware:* A non-temporal write path in the cache.

## A.12 Smaller possibilities

* **`MULHSU`** (the high half of a signed-by-unsigned product, for a signed top limb meeting an unsigned one) is reserved in the arithmetic escape; it is one correction step in software and has one caller, a bignum library's innermost loop.
* **Hardware page zeroing**, and **guard-page states in the page-table entry that do not consume translation-buffer entries**, would make the allocator hardening of OpenBSD's `malloc` cheaper; nobody has asked.
* **A mixed leaf size for the kernel's text** is needed if the kernel is to be write-xor-execute with one-gigabyte leaf pages.
* **Hardware breakpoints and debug registers** are not designed; a debugger today has only the breakpoint instruction and the trace bit.
* **A sealed (immutable) page bit and a hardware mask for `pledge`** have no benefit over the kernel doing the checks, and are recorded to be rejected.

*Commentary.* **Trade-offs.** None of these is ranked above the decisions in appendix B; the first four sections of this appendix (landing pads, the system-call page bit, the stack check and return-address protection) are the ones OpenBSD's developers have shown the most interest in.
