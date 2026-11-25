# IBM z/Architecture Principles of Operation: the TLB, IPTE, IDTE, CSP

**Citation.** IBM, z/Architecture Principles of Operation, SA22-7832-11, Twelfth Edition, September 2017 (1,902 pages).
**URL.** https://publibfi.boulder.ibm.com/epubs/pdf/dz9zr011.pdf (IBM's own publications server; downloaded whole and searched).
**Date read.** 2026-11-25. Page numbers are IBM's printed numbers (chapter-page). A newer edition may exist; this is the newest the search found.
**Parts used.** Chapter 3 "Translation-Lookaside Buffer" (p. 3-62 to 3-67), chapter 10 instructions INVALIDATE PAGE TABLE ENTRY (IPTE, p. 10-37 to 10-40), INVALIDATE DAT TABLE ENTRY (IDTE, just before IPTE), COMPARE AND SWAP AND PURGE (CSP, p. 10-21 and following).

## What the manual says (short note)

IBM calls the cache "TLB" too, and says that changing a table entry in storage "does not necessarily have an immediate effect": there is no automatic coherence. Entries may also be made ahead of need, even in speculative execution. After a change the TLB may hold the old value, the new value, or both, and which one is used is "unpredictable". But IBM gives the program single instructions that do the whole job, for all processors at once: IPTE sets the invalid bit of a page-table entry and clears the matching entries from the TLBs of every processor in the configuration (or only the local one, if the program says so); IDTE does the same for region and segment table entries, or for a whole address space; CSP purges whole TLBs on all processors. The model may clear more than asked, and programs must not depend on clearing less. So z/Architecture is the closest of the architectures read: the "edit" and the "flush" are one instruction. It is still an instruction, not a plain store; a plain store to a table entry gets no such help.

## Quotations

### Translation-Lookaside Buffer (chapter 3, p. 3-62 to 3-63)

> "A modification of the contents of a table entry in real or absolute storage does not necessarily have an immediate effect"

(item 1 of the list of what the TLB changes; the sentence ends "if any, on the translation".)

> "In a multiple-CPU configuration, each CPU has its own TLB."

> "the CPU may form TLB entries in anticipation of future storage references or as a result of the speculative execution of instructions."

(under "Formation of TLB Entries", p. 3-64/3-65.)

### Modification of Translation Tables (p. 3-67)

> "the TLB may contain both the old and the new values, and it is unpredictable whether the old or new value is selected"

(the sentence begins "until the TLB is cleared of entries that qualify for substitution for that entry,"; the text before it says unpredictable results may occur, and that the use of the new value may begin between instructions or in the middle of one.)

The clearing rules listed there: all entries are cleared by PURGE TLB, SET PREFIX and CPU reset; some or all entries of all TLBs by COMPARE AND SWAP AND PURGE:

> "Selected entries are cleared from all TLBs in the configuration by the execution of COMPARE AND REPLACE DAT TABLE ENTRY"

(the sentence goes on "..., INVALIDATE DAT TABLE ENTRY or INVALIDATE PAGE TABLE ENTRY by any of the CPUs in the configuration", unless the local-TLB-clearing facility and the local-clearing bit are used.) And "Some or all TLB entries may be cleared at times other than those required by the preceding rules."

### INVALIDATE PAGE TABLE ENTRY (IPTE, p. 10-37 to 10-39)

> "The page-invalid bit of this page-table entry is set to one."

> "this CPU signals all CPUs in the configuration to clear selected entries from their TLBs."

(the sentence begins "If no exceptions are recognized, this CPU clears selected entries from its TLB. Then if the local-TLB-clearing facility is not installed, or if ... LC bit in the M4 field is zero,".) With the IPTE-range facility one execution invalidates 1 to 256 consecutive entries and can be interrupted and resumed. The instruction is not complete on the executing CPU until the other CPUs have completed their storage accesses that used the old translation (item 3 of the completion rules).

### INVALIDATE DAT TABLE ENTRY (IDTE), programming note 1

> "the program should not take advantage of any properties obtained by a less selective clearing on a particular model"

(the note says that models may clear more entries than the minimum, even every entry.)

### COMPARE AND SWAP AND PURGE (CSP), operation

> "The purging operation applies to ART-lookaside buffers (ALBs) and translation-lookaside buffers (TLBs) in all CPUs in the configuration."

### Where the guest (interpretive execution, SIE) is described

> "The interpretive-execution facility is described in the publication IBM 370-XA Interpretive Execution, SA22-7095."

(Preface, list of other publications, note 9. The Principles of Operation does not describe how the TLB works for a guest; see ibm-sie-guest-tlb.md.)

## Things searched for and not found

* Any text in this edition on guest TLB entries, SIE or "interpretive" TLB handling: none (searched "TLB" near "guest", "host", "interpretive", "SIE").
* A promise that the TLB is coherent with storage: none; the first quotation says the reverse.
