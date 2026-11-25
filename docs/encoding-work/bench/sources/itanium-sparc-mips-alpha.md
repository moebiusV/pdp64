# Four other architectures: Itanium, SPARC V9, MIPS, Alpha

Each is a short extract of what the architecture manual says about the translation cache and the tables. All read on 2026-11-25. For none of them did I find hardware that watches stores to tables; what each says is below.

## Itanium

**Citation.** Intel Itanium Architecture Software Developer's Manual, Volume 2: System Architecture, Revision 2.1, October 2002, document 245318-004 (535 pages). Section 4.1.1.2 "Translation Cache (TC)" and section 4.1.5 "Virtual Hash Page Table (VHPT)".
**URL.** https://www.ece.lsu.edu/ee4720/doc/itanium-arch-2.1-v2.pdf (a university-hosted copy of Intel's PDF). (A later revision, 2.3 of 2010, exists; not read.)

Note: the Itanium TLB is filled by software (`itc.d`, `itc.i`) and, optionally, by a hardware walker of a software-built table, the VHPT. Purging is by instruction (`ptc.l` local, `ptc.g` and `ptc.ga` on all processors "in a TLB coherence domain").

> "The processor does not ensure the TLBs are coherent with the VHPT memory image."

(section 4.1.5, after "The processor does not manage the VHPT or perform any writes into the table. Software is responsible for ... invalidation due to purges and coherency in a multiprocessor system.")

> "Software must handle the case where a purge does not propagate to all processors in a multiprocessor system."

(section 4.1.1.2: a global purge reaches "at least the processors on the same local bus"; "Propagation between multiple TLB coherence domains is platform dependent.")

## SPARC V9

**Citation.** The SPARC Architecture Manual, Version 9 (SPARC International), Appendix F "SPARC-V9 MMU Requirements (Informative)", section F.7 "MMU Demap Operation", about p. 288. (Edition date not read from the file; the manual is the 1994 specification, from memory, not verified.)
**URL.** https://www.ece.lsu.edu/ee4720/samv9.pdf (a university-hosted copy).

Note: the V9 text leaves the MMU to the implementation; the appendix on it is "informative only", not part of the specification.

> "The SPARC-V9 MMU must provide a mechanism for privileged software to invalidate some or all of the virtual-to-physical address translations."

I did not find a sentence about stores to tables and the translation cache in this appendix (the text of F.7 is that one sentence). The Oracle and Fujitsu implementation manuals (UltraSPARC Architecture 2007; SPARC64 extensions) could not be read: oracle.com answered "403" to an automated fetch and I did not retry; the Fujitsu files appeared in a search but I did not open them. So what SPARC implementations do beyond this (the demap operations, the software-managed translation storage buffer) is **could not verify**.

## MIPS

**Citation.** MIPS Architecture For Programmers, Volume III: MIPS32 / microMIPS32 Privileged Resource Architecture, document MD00090, Revision 6.02, 10 July 2015, section 4.12 "Hardware Page Table Walker" (p. 52 to 55).
**URL.** https://www.ece.lsu.edu/ee4720/doc/mips32-r6-3.pdf (a university-hosted copy).

Note: classic MIPS has no page-table hardware; a "TLB Refill" exception is handled in software, which writes the TLB entry with `TLBWI` or `TLBWR`; software and nothing else decides what the TLB holds.

> "Hardware acceleration for page table walking is an optional feature in the architecture."

> "The mechanism can be used to replace the software handler for the TLB Refill condition."

(and "This hardware mechanism is only used for this fast-path handler".) In this revision I searched the whole volume for "coheren", "stale" and "software must" and found no rule that stores to the tables are noticed by the TLB; so the page-table walker is a refill accelerator, with the TLB still managed by software (**none found**, not a proof of absence).

## Alpha

**Citation.** Alpha Architecture Reference Manual, Fourth Edition, Compaq Computer Corporation, January 2002, Volume I section 5.3 "Translation Buffers and Virtual Caches" (p. 5-4).
**URL.** https://csclub.uwaterloo.ca/~pbarfuss/alpha_arch_ref.pdf (a copy of the manual that Compaq published).

Note: the Alpha TLB is filled by PALcode (privileged firmware routines) that walks the tables in software (from memory; the lines read name PALcode only as the means of clearing).

> "Whenever a non-software field of a valid page table entry (PTE) is modified, copies of that PTE must be made coherent."

(the next sentence begins "PALcode mechanisms are available to clear all TBs, both DTB and ITB entries for a given VA" and lists the other forms: either one alone, or all entries with the address-space-match bit clear. "TB" is Alpha's name for the TLB.)
