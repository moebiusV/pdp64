### A.4 Protecting the return address (moved from appendix A)

**A.4.1** There are four ways to protect the return address: software canaries and OpenBSD's return-address protection in the compiler, a hardware return stack, a shadow stack, and nothing. *(P)* The mirror shadow stack is approved (errata 85, study item 6); the others are the alternatives that were weighed.

*Commentary.* **Trade-offs.** A shadow stack is the strongest and brings the most recovery code (a second stack to overflow, switch and unwind), so the analysis did not recommend it by default; software detection costs a few instructions per function and no hardware. **Verdict** (the assistant's, before the decision). Start with the compiler; consider a hardware mechanism only if code size allows. **Benefits.** Detection with little or no recovery code. **Impact.** *Compiler:* The compiler adds a canary or a return-address check per function. *Hardware:* Software costs nothing; a hardware return stack costs a second stack structure and its control.

### A.9 Thirty-two-bit forms of add, subtract and shift (moved from appendix A)

**A.9.1** If the extension instructions the compiler emits after narrow arithmetic are more than a few percent of the code, 32-bit forms of the common operations in one-parcel leaves would remove them.

*Commentary.* **Precedent.** AArch64's `W` forms and RISC-V's `ADDW` family. **Trade-offs.** A second set of leaves in the table against extension instructions in the compiled code; the overhead has never been measured over the whole corpus. **Verdict.** Measure first; it is one script over the compiled corpus. **Impact.** *Kernel:* None. *Compiler:* The compiler stops emitting an extension after common 32-bit operations. *Hardware:* A second set of opcodes in the page-2 map and a little ALU decode.

### A.10 Packed-lane instructions in the integer registers (moved from appendix A)

**A.10.1** A small set of lane operations (add, subtract, saturating add, compare, minimum, maximum, average, sum of absolute differences, shuffle on 8, 16 and 32-bit lanes) in the existing registers could speed up string, codec and image loops.

*Commentary.* **Precedent.** Alpha's motion-video instructions and PA-RISC's multimedia instructions did exactly this, in integer registers. **Trade-offs.** It adds no state and little hardware, but it is 64 bits wide so the gain per instruction is modest, and compilers use it poorly. **Verdict.** Collect the evidence first: the compiler corpus was built at a size setting that hides how much vectorisable code there is (appendix B, S1). **Impact.** *Kernel:* String and checksum routines get faster. *Compiler:* Vectorisation into integer lanes is weak, so the library routines would be hand-written. *Hardware:* A lane-aware ALU: little extra hardware and no new state.

### A.12 Smaller possibilities (moved from appendix A)

* **`MULHSU`** (the high half of a signed-by-unsigned product, for a signed top limb meeting an unsigned one) is reserved in the arithmetic escape; it is one correction step in software and has one caller, a bignum library's innermost loop.
* **Hardware page zeroing**, and **guard-page states in the page-table entry that do not consume translation-buffer entries**, would make the allocator hardening of OpenBSD's `malloc` cheaper.
* **A mixed leaf size for the kernel's text** is needed if the kernel is to be write-xor-execute with one-gigabyte leaf pages.

*Commentary.* **Trade-offs.** None of these is ranked above the decisions in appendix B; the first four sections of this appendix (landing pads, the system-call page bit, the stack check and return-address protection) are the ones OpenBSD's developers have shown the most interest in. (Hardware watchpoints are approved and the sealed page bit and `pledge` mask are rejected: A.10.)
