# Arm Architecture Reference Manual (DDI 0487): TLB maintenance, break-before-make, stage 2

**Citations (two issues were read in full text).**
1. Arm Architecture Reference Manual, Armv8, for A-profile architecture, ARM DDI 0487G.b (ID072021), July 2021 (8,696 pages). URL: https://kib.kiev.ua/x86docs/ARM/ARMARMv8/DDI0487G_b_armv8_arm.pdf (a public mirror of Arm's PDF). Section D5.10 "TLB maintenance requirements and the TLB maintenance instructions", and the instruction page C5.5.77.
2. ARM Architecture Reference Manual, ARMv8, for ARMv8-A architecture profile, ARM DDI 0487C.a (ID121917), printed 19 December 2017 (6,666 pages). URL: https://www.cs.princeton.edu/courses/archive/spr19/cos217/reading/ArmArchitectureReferenceManual.pdf . Section D4.10 (same subject; the stage-2 invalidation rules and the TLBI syntax are quoted from here because they read the same in both issues).

**Date read.** 2026-11-25.
**Not obtained.** The current issue (L.b or later) of DDI 0487: Arm's site (developer.arm.com, now redirecting to support.arm.com) builds its pages by script and gave no PDF link; the three Arm "documentation-service" files found by search were only "Known issues" documents. So the text below is from 2021 and 2017. The newer issues rename FEAT_BBM to FEAT_BBML0/1/2 as separate features according to a 2026 QEMU patch title and the Linux "arm64: Add BBM Level 2 cpu feature" patches that turned up in a search; I did not read Arm's newer text, so that renaming is **could not verify** from Arm's own document.

## What the manual says (short note)

Arm says that translation caches are "separate" from the data caches and do not have to react to stores of the data: a store to a table entry changes nothing in the TLB. Software must invalidate by VMID or ASID or address after changing an entry. For some changes (memory type, cacheability, output address, block size) it must follow "break-before-make": make the old entry invalid, wait, invalidate the TLB everywhere, wait, then write the new entry; otherwise two entries for one address may exist at once and the result can break coherence and ordering. A walker is "a separate observer", so even the store to the table is only guaranteed to be seen by it after a DSB. A TLB invalidation is only guaranteed finished after a DSB and (for the executing processor) a context-synchronization event (an ISB is one). For stage 2 there is an invalidate-by-guest-physical-address (IPA) instruction, but it only reaches caches that hold stage-2 information alone, so the manual gives a three-instruction recipe to clear the combined entries too. From Armv8.4 the optional feature FEAT_BBM lets a processor promise that changing the block size is safe without the full dance (levels 1 and 2).

## Quotations (G.b unless marked C.a)

### D5.10 (G.b p. D5-2816): the translation caches are not kept coherent with data writes

> "that are distinct from the data caches in that they are not required to be invalidated as the result of writes of the data."

(the sentence begins "Such entries might be held in intermediate TLB caching structures that are used during a translation table walk and".)

### D5.10 (G.b p. D5-2817): what software must do

> "Whenever translation tables entries associated with a particular VMID or ASID are changed, the corresponding entries must be invalidated from the TLB"

(the sentence goes on "to ensure that these changes are visible to subsequent execution, including speculative execution". The word "speculative" matters: the processor may use stale entries speculatively until the invalidation.)

> "Because a TLB never holds any translation table entry that generates a Translation fault"

(the sentence goes on: a change from a faulting entry to a non-faulting one "does not require any TLB invalidation", but a context-synchronization event is needed for instruction fetches. Same rule as Intel's "P flag 0 to 1".)

### D5.10.1 Using break-before-make (G.b p. D5-2818)

> "the architecture requires the use of a break-before-make sequence when changing translation table entries"

(the sentence goes on "whenever multiple threads of execution can use the same translation tables and the change involves any of": a change of memory type, of cacheability, of the output address (under conditions), of the block size, or creating a global entry over non-global ones.)

The three steps, in the manual's words:

> "Replace the old translation table entry with an invalid entry, and execute a DSB instruction."

> "Invalidate the translation table entry with a broadcast TLB invalidation instruction, and execute a DSB instruction to ensure the completion of that invalidation."

> "Write the new translation table entry, and execute a DSB instruction to ensure that the new entry is visible."

The reason given: "This sequence ensures that at no time are both the old and new entries simultaneously visible to different threads of execution".

### Support levels for changing block size (FEAT_BBM, G.b p. D5-2818 to D5-2819)

Level 0:

> "Software must use break-before-make to avoid breaking coherency, ordering guarantees or uniprocessor semantics"

Level 1: software may use the level 0 way "or software can use the nT block translation entry" (a flag in the entry that makes it fault while the change is made).

Level 2:

> "Software can use the level 0 or level 1 approach and, in addition, changing block size does not break coherency"

> "multiple translation entries might exist within the TLB for the same input address."

(Level 2 may therefore give "Conflict aborts"; the abort goes to EL2 when stage 2 is on, and TLBI VMALLS12E1 or TLBI ALLE1 clears the conflicting entries.) In the feature list: "This feature is mandatory in Armv8.4 implementations." (FEAT_BBM entry.)

### Ordering and completion (G.b p. D5-2831 to D5-2833; C.a p. D4-2218 to D4-2219)

> "a translation table walk is considered to be a separate observer"

> "is only guaranteed to be observable after the execution of a DSB instruction by the PE that executed the store"

(a store to the tables is meant: the manual says the walker may observe such a store at any time after it is executed, but is only guaranteed to see it after the DSB.)

> "after the execution of DSB by the PEx followed by a Context synchronization event"

(G.b: a TLB invalidation is guaranteed finished for the executing processor only after that pair; a DSB alone finishes it for other processors.)

> "A DSB ISH is sufficient to ensure completion of TLB maintenance instructions that apply to PEs in the same Inner Shareable domain."

("PE" is Arm's word for a processor; "Inner Shareable domain" is the group of processors that share memory coherently; "IS" at the end of an instruction name means the invalidation is broadcast to that group.)

### Stage 2: what an invalidation reaches (C.a p. D4-2207 to D4-2210, D4-2216)

> "It is not required to apply to caching structures that combine stage 1 and stage 2 translation table entries."

(a stage-2-only invalidation, such as IPAS2E1, does not have to remove combined entries.)

> "following code is sufficient to invalidate all cached copies of the stage 2 translation of the IPA held in Xt"

(the manual's code is `TLBI IPAS2E1, Xt` then `DSB` then `TLBI VMALLE1`; "for the current VMID", with the broadcast forms for the broadcast case.)

> "VMALLS12 All stage 1 and stage 2 translations used at EL1 with the current VMID, if appropriate."

(the TLBI VMALLS12E1IS instruction; the page C5.5.77 of G.b says the "IS" form applies to every processor in the Inner Shareable domain.)

## Things searched for and not found

* Any statement that a store to a table entry invalidates a TLB entry: none; the text says the opposite (first quotation).
* A hardware mechanism that tracks which table pages were walked: none in the manual. (Hardware update of the access and dirty flags, FEAT_HAFDBS, is described, but it changes entries; it does not invalidate anything.)
