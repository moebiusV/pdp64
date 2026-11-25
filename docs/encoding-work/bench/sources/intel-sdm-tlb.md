# Intel SDM: the TLB, the paging-structure caches, EPT and VPID

**Citation.** Intel 64 and IA-32 Architectures Software Developer's Manual, Combined Volumes 1, 2A, 2B, 2C, 2D, 3A, 3B, 3C, 3D and 4, Intel order number 325462-093US, September 2026 (5,364 pages).
**URL.** https://cdrdv2.intel.com/v1/dl/getContent/671200 (the full combined PDF; downloaded whole and searched with pdftotext).
**Date read.** 2026-11-25.
**Parts used.** Volume 3A chapter 5 ("Paging"), section 5.10 "Caching Translation Information", and Volume 3C chapter 31 ("VMX Support for Address Translation"), section 31.4. Page numbers are the printed Intel page numbers.

Each quotation is under 25 words and copied from the PDF text; where a sentence is longer than that, the quoted part is the start or the end of it and is marked with "...".

## What the manual says (short note)

The processor keeps two kinds of caches of the page tables: the TLB (finished translations) and the "paging-structure caches" (the upper levels of the walk). Neither is kept consistent with memory by hardware. A store to a page-table entry changes memory only; software must then run an invalidating instruction. Until it does, the processor may use the old entry, the new entry, or both. The manual lists exactly which changes need an invalidation and which do not (a not-present entry becoming present needs none, because a not-present entry is never cached). Entries may also be created speculatively. With virtualization, the hypervisor's own tables (EPT) have their own cached forms, invalidated by INVEPT, and entries are tagged per guest (VPID) and per EPT root so that they need not be flushed at every entry.

## Quotations

### 5.10 Caching Translation Information (Vol. 3A, p. 5-41): the processor does not keep the caches consistent

> "Because the processor does not ensure that the data that it caches are always consistent with the structures in memory"

(first sentence of the section; it continues "it is important for software developers to understand how and when the processor may cache such data".)

### 5.10.2.3 Details of TLB Use (Vol. 3A, p. 5-43): stale entries may be kept, and entries may be made speculatively

> "The processor may retain a TLB entry unmodified even if software subsequently modifies the relevant paging-structure entries in memory."

> "the processor may cache translations required for prefetches and for accesses that result from speculative execution ..."

(the sentence ends "... that would never actually occur in the executed code path".)

### 5.10.3.1 Caches for Paging Structures (Vol. 3A, p. 5-43 to 5-44): the same for the upper levels

> "the processor may retain it unmodified even if software subsequently modifies the corresponding PML5E in memory."

(the same sentence is given for the PML4E, PDPTE and PDE caches.) Note from the same section: the processor may create a cache entry for an upper-level entry even when no translation below it exists, so stale upper-level entries can arise without any visible translation.

### 5.10.4 Invalidation of TLBs and Paging-Structure Caches (Vol. 3A, p. 5-48): software must act

> "software should take action to invalidate any cached entries that may contain information that has since been modified."

### 5.10.4.1 Operations that Invalidate TLBs and Paging-Structure Caches (Vol. 3A, p. 5-48 to 5-49): what invalidates

The list is: INVLPG (one linear address, the current PCID; it also invalidates all paging-structure-cache entries of the current PCID); INVPCID (four types: individual address, single context, all contexts including globals, all contexts); MOV to CR0 (if it clears PG); MOV to CR3 (depends on CR4.PCIDE and bit 63 of the operand); MOV to CR4 (changing PGE, PCIDE, PAE, SMEP); a task switch that changes CR3; VMX transitions.

> "INVLPG also invalidates all entries in all paging-structure caches associated with the current PCID"

> "The processor is always free to invalidate additional entries in the TLBs and paging-structure caches."

> "page faults invalidate entries in the TLBs and paging-structure caches."

(In 5.10.4.1 the last sentence is "In addition to the instructions identified above, page faults invalidate entries ..."; a page fault that comes from a stale entry removes that entry, so the fault does not repeat.)

### 5.10.4.2 Recommended Invalidation (Vol. 3A, p. 5-49 to 5-51)

> "If software modifies a paging-structure entry that maps a page (rather than referencing another paging structure), it should execute INVLPG"

(the sentence goes on "for any linear address with a page number whose translation uses that paging-structure entry".) For an entry that points to a lower table the choices are INVLPG per page number, MOV to CR3 (if no global pages), or MOV to CR4 changing PGE. When the page size of a range changes, the manual gives the break-before-make style algorithm: clear the P flag, invalidate, then write the new entry.

### 5.10.4.3 Optional Invalidation (Vol. 3A, p. 5-51): when no invalidation is needed

> "If a paging-structure entry is modified to change the P flag from 0 to 1, no invalidation is necessary."

> "may appear to execute before an earlier write to that paging-structure entry"

(the sentence begins "The read of a paging-structure entry in translating an address being used to fetch an instruction" and ends "if there is no serializing instruction between the write and the instruction fetch".)

> "Note that the invalidating instructions identified in Section 5.10.4.1 are all serializing instructions."

Changing R/W 0 to 1, U/S 0 to 1 or XD 1 to 0 without invalidation may give a "spurious" page fault, at most once for each address, "but no other adverse behavior".

### 5.10.4.4 Delayed Invalidation (Vol. 3A, p. 5-52): what happens between the store and the invalidation

> "the processor may use translations based on either the old value or the new value of the paging-structure entry."

(the sentence begins "between the modification of a paging-structure entry and execution of the invalidation instruction ...".) Also in this section: if a P flag is changed from 1 to 0 "an access ... may or may not cause a page-fault exception", and the page frames freed must not be reallocated until the invalidation is done, because of speculative execution.

### 5.10.5 Propagation of Paging-Structure Changes to Multiple Processors (Vol. 3A, p. 5-52 to 5-53)

> "TLB shootdown can be done using memory-based semaphores and/or interprocessor interrupts (IPI)."

> "Software must be prepared to deal with reads, instruction fetches, and prefetch requests to the affected linear-address range"

(the sentence ends "... that are a result of speculative execution that would never actually occur in the executed code path".) Other processors' TLBs are not reached by the store; each must be told.

### 5.11.1 VMX Transitions (Vol. 3A, p. 5-53/5-54)

> "VMX transitions invalidate the TLBs and paging-structure caches based on certain control settings."

### 31.4.3 Invalidating Cached Translation Information (Vol. 3C, p. 31-22): with EPT

> "may result in inconsistencies between those structures and the mappings cached by a logical processor."

(the sentence begins "Software modifications of paging structures (including EPT paging structures ...)".)

### 31.4.3.1 Operations that Invalidate Cached Mappings (Vol. 3C, p. 31-22 to 31-24)

> "If the “enable VPID” VM-execution control is 0, VM entries and VM exits invalidate linear mappings and combined mappings associated with VPID 0000H"

(the sentence goes on "(for all PCIDs)". With "enable VPID" set to 1 there is no such invalidation: see 31.4.3.2.)

> "Execution of the INVEPT instruction invalidates guest-physical mappings and combined mappings."

> "Two INVEPT types are currently defined:"

The two types are single-context (all mappings of one EPT root) and all-context. There is no type that names an address: INVEPT cannot invalidate one guest-physical page. (INVVPID has an individual-address type, but it names a linear address.)

### 31.4.3.2 Operations that Need Not Invalidate Cached Mappings (Vol. 3C, p. 31-24)

> "VMX transitions are not required to invalidate any guest-physical mappings."

> "A logical processor may invalidate any cached mappings at any time."

### 31.4.3.4 Guidelines for Use of the INVEPT Instruction (Vol. 3C, p. 31-25 to 31-26)

> "Software should use the INVEPT instruction with the “single-context” INVEPT type after making any of the following changes to an EPT paging-structure entry"

The listed changes: a privilege bit 2:0 changed from 1 to 0; the physical address in bits 51:12 changed; the accessed flag cleared (if EPT accessed/dirty flags are enabled); bit 7 changed in an EPT PDPTE or PDE; memory-type bits changed in the last-level entry; the dirty flag cleared. Also needed before a VM entry that switches between EPTP values with different accessed/dirty enabling or different walk length but the same root address.

> "it is not necessary to execute INVEPT following modification of an EPT paging-structure entry that had been not present or misconfigured."

(the sentence begins "Because a logical processor does not cache any information derived from EPT paging-structure entries that are not present ... or misconfigured ...".) Changing a privilege bit from 0 to 1 may give a spurious EPT violation if INVEPT is skipped, and the violation itself invalidates the mappings, so it does not repeat.

> "information from an EPT paging-structure entry may be cached on logical processors other than the one that modifies that entry."

(the sentence begins "In a system containing more than one logical processor, software must account for the fact that ...".)

## Things searched for and not found

* Any statement that the processor snoops stores to paging structures and invalidates its TLB: none. (Searched section 5.10 and chapter 31 for "snoop", "coherent" and "consistent".)
* Any figure for VM-entry or VM-exit latency in cycles: none in the manual (searched the whole text for "latency", "cycles" near "VM exit" and "VM entry").
* Intel's "Remote Action Request" feature: the manual lists model-specific registers named MSR_RAR_CONTROL and MSR_RAR_ACTION_VECTOR_BASE (Volume 4), but I found no descriptive text for it in this edition; I do not claim what it does. It is in any case a way to *send* invalidations to other processors, not a store-snooping mechanism (inference from the names; could not verify).
