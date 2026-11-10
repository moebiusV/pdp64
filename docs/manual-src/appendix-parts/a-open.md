<a id="ja1"></a>
### J.A.1 The canonical-address rule and the pointer bits that colours spend

**Issue.** A virtual address is canonical when its bits above the translated width repeat the top translated bit (39, 48 or 57 bits of address, 9.2.10); a non-canonical address aborts. A 64-bit pointer therefore has 25 spare bits with three levels of page table, fewer with four or five, and the rule today refuses software any use of them. The author approved granule colouring and reserved colours for uninitialised and freed memory (errata 84, items 1 and 2), and "to be specified": a colour travels in the pointer, so the hardware, not software, must define and check those bits.

**Why it matters.** The rule is stated in the architecture, in the kernel's address-space layout, in the compiler's pointer arithmetic and in the debugger; a colour that software may set changes all four. The tag trick of the instruction set (a pointer tag in the low three bits, checked by the quad alignment abort) is a separate use and is not affected.

**Options.**

1. *Keep the canonical rule; colours live outside the pointer.* The colour of a granule is a table in memory, indexed by address, and a check compares the table entry against a colour register. For: the rule stands; no pointer bits spent. Against: a table lookup on every access that is checked; more memory traffic.
2. *The colour travels in a fixed field of the spare bits, ignored by translation and checked by the hardware.* For: no table; the check is a compare. Against: every pointer use must mask (the hardware, as on ARM, can ignore the field in the address path); the canonical rule is restated; the field shrinks with each level of page table added.
3. *The colour field depends on the translation width.* Three levels leave the 25-bit field, five levels fewer, and the width is read from a register (J.6.1). For: uses what each configuration has. Against: software that depends on the field must read the width first.
4. *Choose the field with the page-table level, once: the smallest field that every configuration has.* For: one rule. Against: wastes the extra bits of the narrow configurations.

**Precedents.** ARM's top-byte-ignore, pointer authentication and the memory tagging extension *(unverified: general knowledge)*; SPARC's application data integrity colours the pointer and the memory *(unverified)*; the study of item 3 of the retire-stage candidates, which considered the same bits for a capability bit *(verified: docs/retire-stage-candidates.md, cited in errata 84)*.

**The author's referents.** "Do it, no delay" for granule colouring; the capability bit "asked whether it can be done with 64-bit pointers and flags outside the 64 usable bits" (errata 84, item 3).

**The assistant's leaning.** Option 3, because the width is read anyway for the address space (J.6.1). This is the assistant's view, not a decision.

**Where the body refers to it.** Section A.5.2.
