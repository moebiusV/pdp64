The numbers in this fragment are labels: they are those of chapter 7 before its rewrite (errata 127 gives the map), not those of the body, and a citation of one of them reads "H.7, 7.8.1".

### 7.8 Starting and signalling the other cores (moved from chapter 7)

**7.8.1** (moved from chapter 7) The controller holds every core but core 0 in reset; a write to a per-core start register gives a core an entry address and an argument and releases it into kernel mode at priority 7, with its number in `r0`. *(P)* The same proposal is statement 4.7.1 of the boot chapter (its fragment is the one to read for the start protocol, the pseudocode and the figure); it is entered here as well because chapter 7 stated it independently.

**7.8.2** (the mechanism, moved from chapter 7) An inter-processor interrupt is a write to a per-core register in the interrupt controller; no APIC-like machinery is needed. *(P)* (That one core can interrupt another is decided, 7.10.4 of the body; how interrupts reach a core is open: [J.6.3](appendix-j-open.md#j63).)

**7.8.3** (moved from chapter 7) The routing of device interrupts to cores, and a shared second-level cache or a coherent interconnect, are device-side and unspecified. *(P)* (The routing of interrupts is the open item [J.6.3](appendix-j-open.md#j63); the cache and the interconnect are implementation choices that the architecture does not fix.)

*Commentary on 7.8.1 to 7.8.3 (moved from chapter 7).* **Precedent.** An x86 core wakes in 16-bit real mode and has to be walked through three modes by a trampoline (1,528 lines of start-up code and 1,258 of real-mode code in Linux); arm64 uses a firmware call in 124 lines or a spin table in 127; RISC-V 108 or 58; the VAX's console processor started the others. **Benefits.** A core can start in its normal mode at any address, so the whole protocol is one register write. **Modern comparables.** x86's INIT and START-UP interrupts, ARM's PSCI, RISC-V's hart-start call. **Impact.** *Kernel:* Starting a core is one register write, and a stuck core is reset by another. *Compiler:* None. *Hardware:* A start register and a reset-hold per core in the controller.

### 7.9 A kernel's view (moved from chapter 7)

**7.9.1** (the first clause, moved from chapter 7) The kernel starts a core by writing its start register. *(P)*

**7.9.4** (the last clause, moved from chapter 7) It wakes an idle core with an inter-processor interrupt. *(P)*

### 7.2 and 7.11 Commentary (moved from chapter 7)

*Total store order as the retreat.* If a large out-of-order core is ever built, total store order is the least painful retreat from sequential consistency (from the commentary of 7.2). The decision is reversible in the direction that matters: total store order can be the retreat for a large core (from the commentary of 7.11). *(P)* The smp-decisions record leans to writing the retreat down now as a one-way, announced switch for the whole machine, with no per-core or per-page weaker mode.
