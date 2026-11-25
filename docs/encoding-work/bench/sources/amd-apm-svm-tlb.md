# AMD64 Architecture Programmer's Manual: the TLB, SVM and nested paging

**Citation.** AMD64 Architecture Programmer's Manual, Volume 2: System Programming, publication 24593, revision 3.46, October 2026 (891 pages).
**URL.** https://kib.kiev.ua/x86docs/AMD/AMD64/24593_APM_v2-r3.46.pdf (a public mirror of AMD's publication; AMD's own site, www.amd.com, could not be reached from here, and docs.amd.com gave an error, so the mirror was used).
**Date read.** 2026-11-25.
**Parts used.** Section 5.5 "Translation-Lookaside Buffer (TLB)" (about p. 159 to 161), section 15.16 "TLB Control" (p. 551 to 553), the EFER description (TCE bit, INVLPGB).

## What the manual says (short note)

AMD says plainly that the TLB is not kept coherent with page-table stores and that hardware does not snoop for them; software must invalidate. For virtual machines, each TLB entry carries an address-space number (ASID) that names the guest or the nested table, and the control block the hypervisor fills in before `VMRUN` has a field (TLB_CONTROL) that asks the hardware to flush at the moment of entry: nothing, everything, this guest, or this guest's non-global entries. After the hypervisor edits a nested page table and goes back to the same guest, AMD tells it to use the flush-this-guest command. There is no instruction to invalidate one nested translation by guest-physical address. AMD also has `INVLPGB`, which invalidates on all processors from one instruction (software still issues it).

## Quotations

### 5.5 Translation-Lookaside Buffer (about p. 159)

> "hardware snooping of TLBs during memory-reference cycles is not performed."

(the sentence begins "A change to any paging data-structure entry is not automatically reflected in the TLB, and ...".)

> "Software must invalidate the TLB entry of a modified translation-table entry so that the change is reflected in subsequent address translations."

### 15.16 TLB Control (p. 551 to 552)

> "TLB entries are tagged with Address Space Identifier (ASID) bits to distinguish different guest virtual address spaces"

(the sentence continues "when shadow page tables are used, or different guest physical address spaces when nested page tables are used".)

Table 15-9 (TLB Control Byte Encodings) gives: 00h "Do not flush"; 01h "Flush entire TLB (Should be used only on legacy hardware.)"; 03h "Flush this guest's TLB entries"; 07h "Flush this guest's non-global TLB entries". The last two are optional (CPUID FlushByAsid).

> "and intends to return to the same ASID, it should use either TLB command 011b or 001b."

(the sentence begins "If a hypervisor modifies a nested page table by decreasing permission levels, clearing present bits, or changing address translations". 011b is 03h and 001b is 01h of Table 15-9.)

### 15.16.2 Invalidate Page, Alternate ASID (p. 552)

> "it does not provide a means to invalidate a nested translation by guest physical address."

(about INVLPGA, which takes a guest virtual address and an ASID.)

### EFER, TCE bit (Translation Cache Extension)

> "For software using INVLPGB to broadcast TLB invalidations"

(the sentence goes on "the invalidations are controlled by the EFER.TCE value on the processor executing the INVLPGB instruction". The manual page for the INVLPGB instruction itself is in Volume 3, which was not read; so what INVLPGB exactly does is taken from this one sentence and its name only.)

## Things searched for and not found

* A figure for the time of VMRUN or #VMEXIT: none in Volume 2 (searched "latency" and "cycles" near VMRUN/VMEXIT).
* Any statement that nested-page-table stores invalidate TLB entries by themselves: none; the opposite is stated above.
