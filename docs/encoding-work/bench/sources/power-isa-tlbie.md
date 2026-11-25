# Power ISA (IBM POWER): tlbie, ptesync and translation table updates

**Citation.** OpenPOWER Foundation, Power ISA Version 3.1C (the page of releases lists it as 2024-05-26; the page headers of the file say "v3.1C-rc3 99a1cac - 2023-06-22"), Book III, chapter 6 "Storage Control", section 6.10 "Translation Table Update Synchronization Requirements" and 6.10.1 "Translation Table Updates" (p. 1187 to 1189 of the file's 1,459 pages).
**URL.** https://openpower.foundation/specifications/isa/ lists it; the file is https://files.openpowerfoundation.org/s/AKX2KtLkwCXxEaC (1,495 PDF pages).
**Date read.** 2026-11-25.

## What it says (short note)

Power says outright that the TLB is a non-coherent cache and gives the exact instruction sequence the operating system or hypervisor must use after editing an entry: the store(s), `tlbie` (invalidate by address and by guest number, broadcast), `eieio`, `tlbsync` (wait for all processors), `ptesync` (a full barrier), and then a context-synchronizing instruction before the new entry is used. It allows the invalidation to lag behind the entry change for permission downgrades and for clearing the change bit, and says that hardware may be walking the tables at any time while software edits them. Two valid overlapping translations with different page sizes or attributes are forbidden.

## Quotations

> "TLBs are non-coherent caches of the HTABs and Radix Trees."

> "TLB entries must be invalidated explicitly with one of the TLB Invalidate instructions."

(6.10.1. "HTAB" is the hashed page table and "Radix Tree" the multi-level table of POWER; a guest's and the hypervisor's are told apart by the guest number, LPID.)

> "The most basic sequence that will achieve proper system synchronization for PTE updates is the following."

(the sequence is: the `tlbie` instruction(s) with the same LPID, `eieio`, `tlbsync`, `ptesync`; "Operating system and hypervisor software that updates Page Table Entries should use this sequence.")

> "All of the sequences require a context synchronizing operation after the sequence if the new contents of the translation table are to be used"

(the sentence goes on "for address translations associated with subsequent instructions".)

> "The translation cache invalidation may lag the PTE change indefinitely and be done in bulk."

(said of access-authority downgrades and of setting Change bits to zero.)

> "Unsynchronized lookups in the Page, Segment, and when HR=0, Process Tables continue even while they are being modified."

> "software must not have two or more valid overlapping translations at any level of the translation process with different page or segment sizes"

(the same rule as Arm's break-before-make for block size; one translation "must be marked invalid in the translation table and invalidated from any caches prior to instating the second".)

## Things searched for and not found

* Any statement that a store to a translation table invalidates a TLB entry: none.
* The text of the `tlbie` instruction page itself was not read (only the update-sequence section); so the exact set of `tlbie` variants (by address, by guest, by process) is not stated here.
