# Appendix A. Improvements beyond the PDP-11

[← manual index](00-index.md)

**These are improvements that the author has approved, each with its benefit, its cost and what other machines do.** They come from the reports on kernel pain points, hardware vulnerabilities and OpenBSD's mitigations. Most are approved "to be specified": the decision is made and the specification is not written, and what is not yet specified is listed in [appendix J](appendix-j-open.md). The same ordering principle as the rest of the manual applies: code size, then easy recoverability, then speed and efficiency through fewer gates and tighter hot loops. Ideas that nobody has decided are in [appendix H](appendix-h-proposed.md), and what has been put off is in [appendix I](appendix-i-deferred.md).

## A.1 A page bit that enforces landing pads

**A.1.1** The `LPAD` instruction marks a legal target of an indirect jump or call; a page bit makes the hardware fault when an indirect transfer lands anywhere else, with the fault attributed to the branch.

**A.1.2** A page bit that gates landing pads is approved, to be specified (errata 84, item 5). *(D)* Open: how the bit is specified and what the six reserved system words become ([J.9.6](appendix-j-open.md#j96)), and when enforcement is turned on in the ABI ([J.D.2](appendix-j-open.md#jd2)).

*Commentary.* **Precedent.** `LPAD` already exists, and the ABI leaves landing pads off in version 1, with no switch to enforce them. **Trade-offs.** The bit costs one comparator and two bytes per address-taken function. **Benefits.** It blocks jump-oriented attacks at the transfer, with no recovery code beyond the fault handler that already exists. **Modern comparables.** Intel's indirect-branch tracking and ARM's branch target identification, both of which OpenBSD enforces by default where the hardware has them. **Impact.** *Kernel:* A landing-pad violation is a fault the handler already handles; the kernel sets the page bit at exec time. *Compiler:* The compiler emits `LPAD` at every address-taken function, two bytes each. *Hardware:* One page bit and one comparator on an indirect-transfer target.

## A.2 A page bit that says a system call may be made from here

**A.2.1** A page-table bit lets the hardware refuse a system call from any page not so marked, so that the kernel's check of where a call came from moves into the instruction.

**A.2.2** A page bit for system-call entry (the `SYS` page bit) is approved, to be specified (errata 84, item 8). *(D)* Open: its specification ([J.9.6](appendix-j-open.md#j96)).

*Commentary.* **Precedent.** OpenBSD's `msyscall` and `pinsyscalls` restrict where system calls may be issued from. **Trade-offs.** One bit and one gate; the kernel no longer needs to check the origin on every call. **Benefits.** About four instructions removed from every system call, and region pinning with no hot-path check. **Modern comparables.** No architecture surveyed has this bit; it is done by the kernel in software. **Impact.** *Kernel:* The kernel no longer checks where a system call came from on every call, which removes about four instructions from each. *Compiler:* None. *Hardware:* One page bit and one gate at the `TRAP` decode.

## A.3 A check of the stack pointer at system-call entry

**A.3.1** The hardware checks that the stack pointer lies in a region registered as a stack when a system call or a fault is taken.

**A.3.2** A stack-limit register is approved, to be specified (errata 84, item 4). *(D)* Open: its specification ([J.9.6](appendix-j-open.md#j96)).

*Commentary.* **Precedent.** OpenBSD checks the stack pointer against a `MAP_STACK` region on system calls and faults. **Trade-offs.** It adds a comparison to entry, which is the path the design most wants short. **Impact.** *Kernel:* The kernel's own check moves into the hardware. *Compiler:* None. *Hardware:* A comparator and a region register on the entry path.

## A.4 Protecting the return address

**A.4.1** The return address lives on the data stack, because `CALL` pushes it and there is no link register.

**A.4.2** The mirror shadow stack is approved with its recommendations (errata 85, study item 6). *(D)*

*Commentary.* **Precedent.** x86 has the same exposure; Intel's control-flow enforcement has a shadow stack, and OpenBSD's clang has `retguard`. **Benefits.** Detection of a changed return address with little or no recovery code. **Impact.** *Kernel:* A shadow stack is a second stack for the kernel to manage and unwind. *Compiler:* none beyond the setjmp path. *Hardware:* A second stack structure and its control.

## A.5 Tag or key bits in pointers

**A.5.1** The 25 spare bits of a 64-bit pointer (a 39-bit virtual address, the three-level form, uses the rest; 48 and 57 bits leave fewer) can carry a colour, as a memory-tagging scheme does.

**A.5.2** Full 128-bit CHERI is rejected, and a valid-pointer tag per register and per 8-byte word (stage 1) is kept (errata 86, study item 3); granule colouring and reserved colours for uninitialised and freed memory are approved, to be specified (errata 84, items 1 and 2). *(D)* Open: they spend pointer bits that the canonical-address rule refuses to software, so that rule must be restated ([J.A.1](appendix-j-open.md#ja1)).

*Commentary.* **Precedent.** ARM's top-byte-ignore, pointer authentication and memory tagging. **Trade-offs.** The cost is canonical-address rules: pointers must be masked before use, and the hardware must define what a tagged pointer does. **Impact.** *Kernel:* The kernel defines what a tagged pointer means across the user and kernel boundary. *Compiler:* Every pointer use needs masking, and pointer arithmetic must preserve tags. *Hardware:* Gates and state in the address path.

## A.6 A physical address wider than 40 bits

**A.6.1** The physical address is 40 to 64 bits (errata 102, *(D)*), which lets petabytes of memory and device windows be mapped; the present page-table entry holds the physical page number in bits 12 to 39 and keeps bits 40 to 63 zero, so the entry format has to grow its page number into them or change. Open: the entry format ([J.6.2](appendix-j-open.md#j62)).

*Commentary.* **Trade-offs.** The author's reason is that mapping petabytes needs those bits (errata 97). The cost is a wider page number in the entry, in every translation-buffer entry and in every bus address; the benefit is room for devices and memory in one address space without a decoding bit. **Modern comparables.** x86-64 and AArch64 define physical addresses of up to 52 bits and RISC-V up to 56 (stated from memory, not confirmed in the sources read). **Impact.** *Kernel:* a wider entry and a physical-address width to discover. *Compiler:* none. *Hardware:* more bits in the walker, the translation buffer and the bus.

## A.7 A second page-table base register

**A.7.1** A second page-table base, `KTBR`, translates the upper half of the address space, so that a kernel and a user program run with different tables without flushing (6.9.1; the author accepted the split, errata 71). *(D)*

*Commentary.* **Precedent.** The cost of separating kernel and user page tables on x86 after Meltdown was about 5% typical and about 30% in the worst case in the developers' own estimates, and the tagged translation buffers (PCID) made it tolerable. **Benefits.** The isolation is in the hardware from the start. **Modern comparables.** AArch64 has two translation-table base registers, one for each half of the address space. **Impact.** *Kernel:* The kernel switches one base register at the privilege change instead of managing a shared table. *Compiler:* None. *Hardware:* A second base register and a rule choosing which half uses which.

## A.8 The user-memory guard instructions

**A.8.1** `PSW.UA`, `STUA` and `CLUA` stay in the architecture until the OpenBSD port confirms the user-qualified moves (6.10.4, 9.6.7); the author accepted this with the five leanings of the study of user access (errata 86, item 18). *(D)* Details to be determined.

## A.9 Streaming block operations

Open: whether the block operations have a form that does not fill the data cache ([J.9.8](appendix-j-open.md#j98)).

## A.10 Watchpoints, and what was rejected

**A.10.1** Precise hardware watchpoints are approved, to be specified (errata 84, item 16). *(D)* Open: the debug registers and how a watchpoint is reported ([J.6.11](appendix-j-open.md#j611)).

**A.10.2** Three other retire-stage items are approved, to be specified (errata 84): predictor and cache-way isolation by address-space number, both parts (item 13: "smp is immediate, so don't defer"); the residue check of the results of the arithmetic unit (item 14); and precise reporting of ECC and parity errors (item 15), with the restart contract of item 17. *(D)* Details to be determined.

**A.10.3** A user-visible transactional region is rejected (errata 84, item 19), and so are a sealed (immutable) page bit and a hardware mask for `pledge`, which have no benefit over the kernel doing the checks. *(D)*
