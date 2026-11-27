# Appendix A. Improvements beyond the PDP-11

[← manual index](00-index.md)

**These are improvements that I have approved, each with its benefit, its cost and what other machines do.** They come from the reports on kernel pain points, hardware vulnerabilities and OpenBSD's mitigations. Most are approved "to be specified": the decision is made and the specification is not written. The same ordering principle as the rest of the manual applies: code size, then easy recoverability, then speed and efficiency through fewer gates and tighter hot loops.

## A.1 A page bit that enforces landing pads

**A.1.1** The `LPAD` instruction marks a legal target of an indirect jump or call; a page bit makes the hardware fault when an indirect transfer lands anywhere else, with the fault attributed to the branch.

**A.1.2** A page bit that gates landing pads is approved, to be specified.

*Commentary.* **Precedent.** `LPAD` already exists, and the ABI leaves landing pads off in version 1, with no switch to enforce them. **Trade-offs.** The bit costs one comparator and two bytes per address-taken function. **Benefits.** It blocks jump-oriented attacks at the transfer, with no recovery code beyond the fault handler that already exists. **Modern comparables.** Intel's indirect-branch tracking and ARM's branch target identification, both of which OpenBSD enforces by default where the hardware has them. **Impact.** *Kernel:* A landing-pad violation is a fault the handler already handles; the kernel sets the page bit at exec time. *Compiler:* The compiler emits `LPAD` at every address-taken function, two bytes each. *Hardware:* One page bit and one comparator on an indirect-transfer target.

## A.2 A page bit that says a system call may be made from here

**A.2.1** A page-table bit lets the hardware refuse a system call from any page not so marked, so that the kernel's check of where a call came from moves into the instruction.

**A.2.2** A page bit for system-call entry (the `SYS` page bit) is approved, to be specified.

*Commentary.* **Precedent.** OpenBSD's `msyscall` and `pinsyscalls` restrict where system calls may be issued from. **Trade-offs.** One bit and one gate; the kernel no longer needs to check the origin on every call. **Benefits.** About four instructions removed from every system call, and region pinning with no hot-path check. **Modern comparables.** No architecture surveyed has this bit; it is done by the kernel in software. **Impact.** *Kernel:* The kernel no longer checks where a system call came from on every call, which removes about four instructions from each. *Compiler:* None. *Hardware:* One page bit and one gate at the `TRAP` decode.

## A.3 A check of the stack pointer at system-call entry

**A.3.1** The hardware checks that the stack pointer lies in a region registered as a stack when a system call or a fault is taken.

**A.3.2** A privileged stack-limit register holds the registered stack region, and the hardware compares the stack pointer with it once, at system-call and fault entry; a write to the stack pointer is not checked.

*Commentary.* **Precedent.** OpenBSD checks the stack pointer against a `MAP_STACK` region on system calls and faults. **Trade-offs.** It adds a comparison to entry, which is the path the design most wants short, and nothing to the path of an ordinary write to the stack pointer. **Impact.** *Kernel:* The kernel's own check moves into the hardware. *Compiler:* None. *Hardware:* A comparator and a region register on the entry path.

## A.4 Protecting the return address

**A.4.1** The return address lives on the data stack, because `CALL` pushes it and there is no link register.

**A.4.2** The mirror shadow stack is approved with its recommendations.

*Commentary.* **Precedent.** x86 has the same exposure; Intel's control-flow enforcement has a shadow stack, and OpenBSD's clang has `retguard`. **Benefits.** Detection of a changed return address with little or no recovery code. **Impact.** *Kernel:* A shadow stack is a second stack for the kernel to manage and unwind. *Compiler:* none beyond the setjmp path. *Hardware:* A second stack structure and its control.

## A.5 Colours in pointers

**A.5.1** A pointer carries a 4-bit colour in bits 63 to 60, and every 16-byte granule of coloured memory carries a 4-bit colour; the hardware compares the two on every access to a coloured page and a difference is a precise fault (6.8.1, 6.8.7). Translation ignores bits 63 to 60, and the bits from 59 down to the top translated bit must still repeat that bit (9.2.10, 6.8.5).

**A.5.2** Colour 0 is uncoloured memory and colour 15 is freed memory (6.8.2); there is no colour for uninitialised memory, no valid-pointer tag, no size class and no taint bit per word. Full 128-bit CHERI is rejected: a register carries no bit beyond its 64, no hardware bound travels with a pointer, and bounds are checked by software and by the check instructions (`CT`, `CHK2`). The per-word lane of taint and the taint for integrity are not part of the architecture; the page-level class for secrets, the `SEC` page, stays.

*Commentary.* **Precedent.** ARM's top-byte-ignore, pointer authentication and memory tagging put a tag in the high bits of a pointer and in the memory; SPARC's application data integrity does the same with a colour; CHERI doubles every pointer *(unverified: general knowledge)*. **Trade-offs.** A colour catches an overflow into the next block, a use after free and a double free at the instruction that makes them, for one thirty-second of the memory and a comparator on the address path; it gives up the pointer that is plain 64 bits of address: code that masks a pointer, hides data in the high bits or compares pointers to different objects must keep or strip the colour on purpose (`COLSTRIP`), and an overflow inside the last granule of a block, a read that stays in its granule and a guessed colour are not caught. A pointer that passes through an integer keeps its colour, because the colour is inside the 64 bits. **Impact.** *Kernel:* the page allocator clears the colours of a page it hands out and saves them with the page when it moves it; the system calls that take an address strip the colour (6.8.12). *Compiler:* pointer comparison across objects strips first; the option to colour stack objects is the compiler's. *Hardware:* a 4-bit comparator on the address path, a side band of one thirty-second of the memory with a cache of colours, and one page-table bit.

## A.6 A physical address wider than 40 bits

**A.6.1** The physical address is 40 to 64 bits (my decision), which lets petabytes of memory and device windows be mapped; the present page-table entry holds the physical page number in bits 12 to 39 and keeps bits 40 to 63 zero, so the entry format has to grow its page number into them or change.

*Commentary.* **Trade-offs.** My reason is that mapping petabytes needs those bits. The cost is a wider page number in the entry, in every translation-buffer entry and in every bus address; the benefit is room for devices and memory in one address space without a decoding bit. **Modern comparables.** x86-64 and AArch64 define physical addresses of up to 52 bits and RISC-V up to 56 (stated from memory, not confirmed in the sources read). **Impact.** *Kernel:* a wider entry and a physical-address width to discover. *Compiler:* none. *Hardware:* more bits in the walker, the translation buffer and the bus.

## A.7 A second page-table base register

**A.7.1** A second page-table base, `KTBR`, translates the upper half of the address space, so that a kernel and a user program run with different tables without flushing (6.10.1; I accepted the split).

*Commentary.* **Precedent.** The cost of separating kernel and user page tables on x86 after Meltdown was about 5% typical and about 30% in the worst case in the developers' own estimates, and the tagged translation buffers (PCID) made it tolerable. **Benefits.** The isolation is in the hardware from the start. **Modern comparables.** AArch64 has two translation-table base registers, one for each half of the address space. **Impact.** *Kernel:* The kernel switches one base register at the privilege change instead of managing a shared table. *Compiler:* None. *Hardware:* A second base register and a rule choosing which half uses which.

## A.8 The user-memory guard

**A.8.1** The user-memory guard has one mechanism: the user-qualified accesses (6.11.4, 9.6.9), the moves and the two sides of the block copy; there is no status bit and there are no instructions to open and close it.

## A.9 Streaming block operations

## A.10 Watchpoints, and what was rejected

**A.10.1** Precise hardware watchpoints are approved, to be specified.

**A.10.2** Three other retire-stage items are approved, to be specified: predictor and cache-way isolation by address-space number, both parts (item 13: "smp is immediate, so don't defer"); the residue check of the results of the arithmetic unit (item 14); and precise reporting of ECC and parity errors (item 15), with the restart contract of item 17.

**A.10.3** A user-visible transactional region is rejected, and so are a sealed (immutable) page bit and a hardware mask for `pledge`, which have no benefit over the kernel doing the checks.
