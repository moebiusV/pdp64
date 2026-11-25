# RISC-V privileged architecture: SFENCE.VMA, HFENCE.GVMA, Svinval, Svadu

**Citation.** RISC-V Instruction Set Manual, Volume II: Privileged Architecture, source files of the manual's "main" branch on GitHub: `src/priv/supervisor.adoc` (Supervisor-Level ISA, Version 1.13), `src/priv/hypervisor.adoc` ("H" extension), `src/priv/svinval.adoc`, `src/priv/svadu.adoc`. URL: https://raw.githubusercontent.com/riscv/riscv-isa-manual/main/src/priv/ followed by the file name.
**Date read.** 2026-11-25 (the main branch of that day). The published edition dated 2026-01-20, which the repository's study cites, appeared in a search as https://docs.riscv.org/reference/isa/v20260120/priv/hypervisor.html ; the text here was read from the source files, not from that page.

## What it says (short note)

RISC-V has no coherence between page-table stores and the translation cache either. `SFENCE.VMA` is the software tool: it orders earlier stores before later table reads by the hardware walker and invalidates the cache, for the executing hart (processor thread) only; other harts must be told by software. The hardware may start a walk speculatively at any time, so the cache may fill with any entry reachable from the tables. `HFENCE.GVMA` invalidates by guest-physical address and guest number (VMID) for the hypervisor's second-stage tables, and the manual itself notes that doing it by address needs a tag with the guest-physical address on every entry, "which is costly", so the common technique is to flush the whole guest. `Svinval` only splits the fence into smaller steps that batch better; `Svadu` lets hardware set the accessed and dirty bits in entries; neither makes the cache coherent.

## Quotations

### supervisor.adoc, section "Supervisor Memory-Management Fence Instruction"

> "SFENCE.VMA is also used by higher privilege levels to synchronize page table writes and the address translation hardware."

> "these implicit references are ordinarily not ordered with respect to explicit loads and stores."

(about the walker's reads and writes of the tables; the sentence begins "Instruction execution causes implicit reads and writes to these data structures; however,".)

> "Executing an SFENCE.VMA instruction guarantees that any previous stores already visible to the current RISC-V hart are ordered before certain implicit references"

> "SFENCE.VMA orders only the local hart’s implicit references to the memory-management data structures."

(and the note after it: other harts "must be notified separately when the memory-management data structures have been modified".)

### supervisor.adoc, section on the address-translation algorithm

> "Implementations may also execute the address-translation algorithm speculatively at any time, for any virtual address"

(the sentence goes on "as long as satp is active".)

> "at any time, all page table entries reachable by executing the algorithm may be loaded into the address-translation cache."

### hypervisor.adoc, HFENCE.GVMA

> "Selectively flushing entries in this fashion requires tagging them with the guest physical address, which is costly"

> "a common technique is to flush all entries that match the HFENCE.GVMA’s VMID argument, regardless of the address argument."

### svinval.adoc

> "The Svinval extension splits SFENCE.VMA, HFENCE.VVMA, and HFENCE.GVMA instructions into finer-grained invalidation and ordering operations"

(the sentence ends "that can be more efficiently batched or pipelined on certain classes of high-performance implementation".)

### svadu.adoc

> "The Svadu extension adds support and CSR controls for hardware updating of PTE A/D bits."

## Things searched for and not found

* Any extension that watches stores to page tables: none in the four files; the fences above are the whole mechanism. (Vendor extensions that I did not read could exist: **could not verify**.)
