<a id="jd1"></a>
### J.D.1 Stack alignment

**Issue.** The stack pointer `R14` must be kept at some multiple, so that pushes and locals land at addresses a quad (8-byte) access can use. Version 1 of the ABI says the stack pointer is a multiple of 8 at all times (D.1). The author asked: "why not 2 bytes instead of 8?" Two is the right number only when the machine pushes 16-bit words, as the PDP-11 does. Here a push, a return address and an argument slot are each 8 bytes (a call pushes the return address), and a quad access to an address that is not a multiple of 8 aborts with `ALIGN` (section 7.4 of the instruction set: natural alignment is required and "may not be relaxed"); a stack pointer at 2 modulo 8 would make the first push abort. Two would work only if quads were pushed with the explicit unaligned forms `MOVUQ`, which cost two memory accesses. The open question is which number the ABI states, and whether any function may ask for more.

**Why it matters.** In hardware, the 8-byte rule is checked by the existing `ALIGN` abort and costs no gates; a stricter rule (16) could be checked when `R14` is written or left to the first access. In the compiler, frame layout, `alloca`, variable-length arrays and spill slots must keep the alignment, and the compiler either assumes it or realigns in a prologue for types that need more. In the kernel, the exception and signal frame start on a stack of the same alignment, a context switch saves `R14` unchanged, and `setjmp` and `longjmp` restore `R14` whole and so preserve whatever alignment it has. For C, `max_align_t` is 8 here (`long double` is `double` and no type is wider than a quad), and `malloc` alignment follows it; a larger stack alignment is wanted only for a type with larger alignment (a 128-bit type or a vector, none planned). The variadic convention (D.2) pops the return address, pushes `r5` to `r0` and pushes the return address again, so the six-slot register save area (48 bytes) lies directly below the stack arguments and `va_list` is a pointer that runs on into them; a rule of 16 would break that contiguity.

**Options.**

1. *8 at all times, checked by the quad `ALIGN` abort (the present ABI).* For: the smallest number that every push and spill obeys; no padding beyond rounding frames to 8; a violation is caught by the first quad access. Against: a future 128-bit type or vector needs a declared realignment (option 6) or an ABI version change.
2. *2 (what the author asked).* The stack pointer is a multiple of 2, so a byte-sized local is not rounded to 8. For: saves on average 4 bytes per frame on a machine with little memory (the PDP-11's reason); matches the 2-byte parcel of instructions. Against: pushes of quads would land at misaligned addresses and abort, so each push becomes two accesses (`MOVUQ`) or the compiler rounds every frame anyway and nothing is saved; `PUSHM`, `CALL` and exception entry would be unaligned stores; the pointer-tag trick of the instruction set depends on quad alignment; any frame with a quad local needs rounding.
3. *4 (long alignment).* For: a halfway number that matches `int`; no padding for a frame of 32-bit data only. Against: the same problem as option 2 for every quad push; the save area stays 8-aligned only by luck; any quad local needs 8, so there is no gain.
4. *16 at all times.* The usual hardware-friendly number. For: room for a 128-bit pair (`R0:R1`) and future vectors without an ABI change; the same as the three most used ABIs, so ported code and compilers assume it. Against: on average 8 bytes of padding per frame and about one extra instruction in some prologues; the variadic save area plus the return address needs 8 padding bytes to keep `va_list` contiguous, so D.2 would change; every exception frame must round; a stronger constraint than the one the author called horrible.
5. *8 at all times, 16 at calls only.* The caller guarantees 16 when it executes the call; the callee may move the stack pointer by pushes. For: only functions that use a 16-aligned object pay; leaf frames keep 8-byte steps. Against: a callee cannot know the alignment at an arbitrary point unless it tracks the parity of its own pushes; interrupt and signal handlers have no guarantee; hand-written assembly is harder; it adds a rule hidden in the parity of the stack pointer.
6. *8 is the ABI, and a function that needs more declares it.* Its prologue realigns the stack pointer and keeps the old one in the frame pointer. For: pay only where needed; no ABI version change when a wider type arrives; `longjmp` is still correct because it restores `R14` whole. Against: makes `R13`, optional today, mandatory in those functions; breaks `alloca` and unwinding unless the unwinder knows; a compiler feature used only once something wider exists.

**Precedents.**

* The ABI of version 1 itself: 8 at all times *(verified)*.
* The PDP-11 kept the stack pointer even (a word) and trapped on an odd one *(unverified: general knowledge)*; the VAX stack pointer is longword-aligned by convention *(unverified)*.
* 32-bit ARM before its EABI and early i386 ABIs used 4 *(unverified)*.
* x86-64 System V: 16 at the call instruction, 8 after the return address is pushed; AArch64 AAPCS64: 16, enforced by hardware at stack-pointer-based accesses if enabled; RISC-V psABI: 16 *(all unverified: general knowledge)*.
* gcc `-mstackrealign` and `__attribute__((force_align_arg_pointer))`, with the `AND SP,#-16` prologue *(unverified)*.

**The author's referents.** The PDP-11 as the base ("update and refresh of the pdp-11 instruction set and architecture", "upgrade it to 32/64 bit keeping nice properties"). On alignment: "only 2 byte memory alignment; don't put 8 byte memory alignment constraints that would be horrible", and later "align 64 bit values the natural way; as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits". "Stack alignment why not 2 bytes instead of 8?" The VAX-11 register roles ("SP is R14 and FP is R13 to match it"). Ockham: "don't multiply entities without benefit".

**The assistant's leaning.** Option 1, keeping 8, and answering the author's question in the ABI text: 2 would be right only if a push were a 16-bit word, and every push here is a quad while a misaligned quad access aborts. Option 6 is reserved for the first type that needs more. This is the assistant's view, not a decision. It would change if a 128-bit type, a vector or a 128-bit `long double` enters the language ABI, or if unmodified third-party code that assumes 16 is to run.

**Where the body refers to it.** Sections D.1 and D.4.2.

<a id="jd2"></a>
### J.D.2 Binding, landing pads and the PLT stub after version 1

**Issue.** Three matters of the ABI are version 1 decisions with a question behind them. *Landing pads:* `LPAD` marks a legal target of an indirect jump or call; version 1 leaves enforcement off and the assembler provides `.lpad`; the author approved a page bit that enforces them (errata 84, item 5). When enforcement is mandatory, and whether it is optional first, is not decided: a tagged function pointer reached by `JMP -k(Rn)` must still land on an `LPAD`, and `JTAG`, which jumps through a table, would need a pad at each entry. *Binding:* imports are called through `CALLI got_slot(PC)` with no PLT stub (decided, 9.16.2). Lazy binding (resolving a symbol on its first call) needs something that runs on the first call and knows which symbol it is; eager binding resolves every import when the program loads. Which one is open. *The PLT stub beyond version 1:* whether imports are always called without a stub.

**Why it matters.** Every binary built before landing pads become mandatory lacks the pads, so the later the decision the more binaries break; a linker, a loader and a compiler must agree on the binding rule; the page-bit mechanism of J.9.6 enforces whatever is chosen.

**Options** (landing pads).

1. *Mandatory from version 1.* For: no binary ever lacks the pads. Against: two bytes at every address-taken function and indirect call target, now, before the hardware enforces anything.
2. *Optional in version 1, mandatory in version 2, enforced per page by the page bit.* For: the ABI version number exists for this; a binary opts in. Against: binaries built in the meantime must be rebuilt.
3. *Optional for ever, enforced only for the pages that carry the bit.* For: no flag day. Against: a binary that does not opt in is unprotected, and the attack surface is the part that does not.

**Options** (binding).

4. *Eager binding only.* All imports resolved at load, the table made read-only afterwards. For: no resolver in the program; the table is read-only after load. Against: the load time grows with the number of imports.
5. *Lazy binding by a stub per import.* The table entry points at a stub that identifies the symbol and calls the resolver. For: fast start. Against: reintroduces the stub that the one-instruction call avoids, and a writable table.
6. *Lazy binding through a resolver that finds the symbol from the return address.* For: no per-import stub. Against: the resolver must decode the call site; the table stays writable.

**Precedents.** Intel's indirect-branch tracking and ARM's branch target identification are enforced by OpenBSD where the hardware has them (appendix A); `ld.so` with `LD_BIND_NOW` and `-z now` against lazy binding, and RELRO, which makes the table read-only after load *(unverified: general knowledge)*; the i386 position-independent executable that kept a register for the table base (9.16 commentary).

**The author's referents.** Landing pads gated by a page bit, "with the fault attributed to the branch" (errata 84); "minimize recovery code".

**The assistant's leaning.** Option 2 for landing pads, and eager binding with a read-only table (option 4), because the call is then one instruction with no stub and there is no writable table to attack. This is the assistant's view, not a decision.

**Where the body refers to it.** Sections 9.16.6, 9.21.1, A.1.2, D.1 and D.4.2.
