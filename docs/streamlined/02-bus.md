# 2. The bus

[← streamlined index](00-index.md)

**The processor reaches the world through one bus, Q64, on which every device is a handful of memory locations, the bus itself is a device that says what is plugged into it, and every transfer of data is a descriptor in memory that a device carries out and marks done.** This chapter states what the processor owes the bus, how the bus enumerates and maps devices and tells the processor when one comes or goes. How a driver talks to a device, the eight-register layout and the default devices are in chapter 5. Where the design is decided it is tagged *(D)*; where it is the author's proposal not yet settled it is *(P)*. Interrupts and modes are chapter 6, and the other cores are chapter 7. The full discussion is in [`../pdp64-q64-bus.md`](../pdp64-q64-bus.md); the options still open are in [`../decisions-pending.md`](../decisions-pending.md) (R1 to R8, Q10).

## 2.1 Q64 and the address space

**2.1.1** Q64 is the system bus: the Q-bus of the PDP-11 widened to 64-bit data and a 40-bit physical address. *(D)*

**2.1.2** Devices live in the ordinary address space; the processor has no input or output instructions. *(D)*

**2.1.3** Each device occupies its own 4 KB page of physical address space, so that one device can be mapped to one protection domain. *(P)*

**2.1.4** Every page has a memory type: normal cached, normal uncached, device strongly ordered, or device weakly ordered. *(D)*

**2.1.5** The detailed transactions of Q64 (widths, bursts, arbitration, timing) are not yet defined; the proposal is to take AXI as the transport and to treat Q64 as the programming model on top of it. *(P, decision R4)*

**2.1.6** The top bit of the 40-bit physical address could select the space: set, the access goes to a device; clear, it goes to memory. Memory would then be 512 GB and device space 512 GB, with one bit and no range comparison deciding where an access goes. This is the VAX's arrangement (below). *(D, the author, 2026-10-22, errata 60; decision P19)*

*Commentary.* **Precedent.** The PDP-11's Unibus put every device in the address space at a fixed location, which is why a PDP-11 driver is an ordinary program; the Q-bus did the same with multiplexed lines. **Trade-offs.** The memory type is per page, not per access, so the code that writes a device register need not know that it is a device; the price is one page per device, which wastes address space but not memory. Using AXI as the transport saves a bridge between two protocols (estimated at about 600 lookup tables on the FPGA) and loses the Unibus's locked read-modify-write as a native bus transaction. **Improvements.** A 40-bit physical address puts devices and memory in one terabyte, with room for every device to sit in its own page. **Benefits.** An uncached, strongly ordered page needs no special instruction to reach a register. **Modern comparables.** RISC-V and ARM systems use memory-mapped devices on AXI or TileLink; x86 keeps both port I/O and memory-mapped devices. **Impact.** *Kernel:* Devices are pages in the kernel's address map, found by the bus controller. *Compiler:* Nothing special. *Hardware:* Address decode is by page; the transport is AXI if the proposal is accepted.

*Commentary on 2.1.6.* **Precedent.** The VAX-11/780 divided its physical address space in two: memory in the low half and the I/O space above `0x20000000` (the 4.3BSD kernel's `NEX780`), which holds one 8 KB window (`NEXSIZE`) per adaptor slot, with the Unibus adapters' device registers reached in a space of their own beyond it; the bit that is set for the whole of I/O space is the one the hardware decodes first (read in the 4.3BSD `nexus.h`, which also records the 8600's, 8200's and MicroVAX's different bases, so the VAX itself kept changing the map from model to model, which the pdp64's single fixed bit would avoid); the PDP-11 put its devices in a fixed page at the top of the address space (a V7 driver's pointer to its registers is a constant in that page). **Trade-offs.** One bit makes the first routing decision in the bus fabric trivial and makes two classes of bug detectable: a page-table entry that maps a normal cached page onto device space, or a device page onto memory, can be a fault because the entry's memory type and the address bit disagree; and the bus controller can refuse a device's DMA into device space, so that no device can write another's registers, which is a free partial protection until devices have a translation unit. The cost is a change to the address map (the emulator's timer and console move into the upper half) and, if the bit were a forty-first, one more bit in every translation-buffer entry and every bus address. The reading of "bit 40" that costs nothing is the top bit of the existing 40-bit address (bit 39 counting from zero), because the page-table entry already holds physical page numbers up to that bit and DRAM then fills exactly 39 bits, the width of a virtual address. **Benefits.** Fewer gates in decode, and fewer ways to get a device mapping wrong. **Modern comparables.** Most systems split the map by address ranges chosen by the platform; the VAX and the PDP-11 used a fixed region; x86 has a separate port space. **Impact.** *Kernel:* a device mapping that is cached by mistake is a fault, not a silent bug, and a driver cannot be given a DMA address that reaches registers. *Compiler:* none. *Hardware:* a one-bit decode at the head of the fabric and a consistency check in the page-table walk.

## 2.2 What the processor owes the bus

**2.2.1** The processor owes the bus exactly three things: a memory type per page, a `FENCE` instruction whose meaning against Q64 is defined, and atomics that can reach device memory. *(D)*

**2.2.2** A driver can be sure a descriptor is visible before it writes the doorbell: it builds the descriptor, executes `FENCE`, and writes the doorbell register. *(D)*

*Commentary.* **Precedent.** The PDP-11 needed none of this because there was one processor and no cache. **Trade-offs.** Three obligations is the whole contract, which keeps the device side free to change without respecifying the processor. **Benefits.** A device and a driver can be written against these three promises without knowing the processor's pipeline. **Modern comparables.** ARM's device-memory types and `DMB`/`DSB`, and RISC-V's `FENCE` with I/O bits, play the same roles. **Impact.** *Kernel:* One `FENCE` before the doorbell is the whole ordering rule. *Compiler:* `FENCE` is an intrinsic. *Hardware:* The memory type is two bits per page-table entry and the bus honours it.

## 2.3 When an access fails

**2.3.1** A read or instruction fetch of non-existent memory is a precise abort with cause `BUSFAULT`, at the faulting instruction. *(D)*

**2.3.2** A posted write that times out, and an uncorrectable memory error, are machine checks: imprecise and not restartable. A `FENCE` before a probe makes even a posted write precise at a known point. *(D)*

**2.3.3** `PROBER` and `PROBEW` test whether an address can be read or written without faulting. *(D)*

**2.3.4** Resetting the bus is a write to a register of the bus controller, not an instruction. *(D)*

*Commentary.* **Precedent.** A PDP-11 read timeout was an unrestartable bus error, fatal to the process; the `nofault` idiom of V6 and V7 existed to probe for devices without dying. **Improvements.** The read timeout became a precise, restartable abort, and `PROBE` replaces the idiom. **Benefits.** A driver that probes for a device handles a missing one in a few lines of ordinary fault-handling code, which is the recoverability principle at work. **Modern comparables.** x86 machine checks and ARM's `SError` correspond to the imprecise class; PCI returns all ones for a read of a removed device, which every driver must then learn to distrust, and the pdp64 avoids that convention. **Impact.** *Kernel:* A driver probes a missing device in a few lines of ordinary fault handling. *Compiler:* None. *Hardware:* A timeout counter in the bridge and a way to make a read abort precise.

## 2.4 Coherence and the hand-off

**2.4.1** Between processors the data caches are coherent without any software action, by snooping with three states (modified, shared, invalid), for two to four cores. *(D)*

**2.4.2** Between a processor and a DMA device they are not: buffers are mapped uncached and the hand-off is explicit. *(D)*

**2.4.3** The hand-off is five steps: the processor builds the descriptors and data in uncached memory, executes `FENCE`, writes the device's doorbell register; the device walks the descriptors, moves the data by DMA, writes the result and a status word, and raises an interrupt; the processor reads the result. *(D)*

*Commentary.* **Precedent.** The 11/70's cache watched Unibus writes so that DMA appeared coherent; the VAX's Unibus adapter had buffered data paths that a driver had to purge. **Trade-offs.** Snooping the DMA path is expensive and DMA transfers are large, infrequent and have an explicit hand-off, so two mechanisms are used, each where it is cheap; the cost is that the processor reads received data from uncached memory, which is slow, and a cache-maintenance instruction would remove it for a non-coherent device that may come later. **Benefits.** No driver can forget a cache clean or invalidate, because there is none to forget. **Modern comparables.** x86 DMA is coherent; ARM and MIPS systems with non-coherent DMA need a DMA-mapping layer in the kernel to place cache maintenance correctly. **Impact.** *Kernel:* Uncached DMA buffers mean no driver cache code. *Compiler:* None. *Hardware:* A snoop port on each data cache for core coherence only; no snoop port for DMA.

## 2.5 Atomics on the bus

**2.5.1** The atomics are defined on a monitor: a load-linked takes a reservation, a write by any initiator clears it, and a store-conditional succeeds only if it is intact; the Unibus's `DATIP`/`DATO` locked pair is not an architectural primitive. *(D, errata 45)*

**2.5.2** A device that writes memory shared with a core takes part by clearing reservations. *(D)*

*Commentary.* **Precedent.** The PDP-11's locked read-modify-write and the VAX's interlocked instructions are bus locks. **Trade-offs.** A lock is simple and a bottleneck as cores multiply; a monitor maps onto AXI's exclusive access and the memory systems of FPGAs and modern chips, at the cost of forward-progress rules. **Modern comparables.** RISC-V `LR`/`SC`, AArch64's exclusive loads and stores, and the large-system atomics that perform the operation at the memory. **Impact.** *Kernel:* Lock words and lock-free structures use the atomics of chapter 7. *Compiler:* C11 atomics lower to them. *Hardware:* A reservation monitor and an exclusive access, not a bus lock.

## 2.6 The bus as a device

**2.6.1** The bus controller is itself a device with eight memory-mapped registers, through which the processor detects what is on the bus and asks it to map a device to an address range. *(D, errata 49)*

**2.6.2** The bus alerts the processor when a device enters or leaves. *(D, errata 49)*

| Offset | Register | Meaning |
|---|---|---|
| `0x00` | `ID` | bus controller, version, number of slots |
| `0x08` | `CONTROL` | enable events, rescan, reset the bus |
| `0x10` | `STATUS` | event pending, queue overflowed, busy |
| `0x18` | `SLOT` | select a slot |
| `0x20` | `INFO` | for the selected slot: present, type, version, window size, interrupt level |
| `0x28` | `MAPADDR` | the address at which the device's window appears |
| `0x30` | `MAPCTL` | enable the mapping; request an orderly eject |
| `0x38` | `EVENT` | next event (arrival, departure, fault) and its slot; zero if none |

**2.6.3** Each slot starts at a fixed 4 KB page; `MAPADDR` is for devices that need a particular address or size. *(P, decision N1)*

**2.6.4** An arrival or departure puts an event in a small queue and raises an interrupt; if the queue overflows a flag says events were lost and the driver rescans the bus, which is also what it does at boot. *(P, decision N2)*

**2.6.5** When a device leaves, its slot is marked absent at once: a read of its window is a precise bus fault, a posted write is dropped and counted, and its in-flight bus transactions are aborted. *(P, decision N3)*

**2.6.6** The queued work of a departed device stays in memory untouched, so the driver can read, save, resend or fail it. *(P, the author's suggestion)*

**2.6.7** A device on Q64 may itself be a bus: a bridge presents the devices behind it as slots with the same registers as the bus controller, so any bus (PCI Express, USB, SATA, a legacy bus) can be connected to Q64 and its devices enumerated, to any depth, as USB devices are enumerated over a PCI Express bus. *(D, the author, 2026-10-23, errata 67)*

**2.6.8** The kernel's enumeration is therefore one recursive walk: it reads a bus controller's slots, and a slot of the type "bus" is another bus controller to read. How a slot says it is a bus, how an arrival or departure behind a bridge is reported, and how the windows behind a bridge are mapped into device space are not yet specified. *(S)*

*Commentary.* **Precedent.** The VAX scanned its interconnect: `probenexi()` in 4.3BSD reads each nexus slot's status register, whose type field says what is plugged in; the Unibus had no enumeration at all, with devices at switch-set addresses and `badaddr()` probes, and nothing told the kernel when a device left. PCI sizes each device's windows by writing all ones to its base registers and assigns addresses; Amiga AutoConfig lets each board announce itself at a fixed address and be told where to live; NuBus gave each slot a fixed share of the address space. **Trade-offs.** A fixed page per slot needs no assignment step and limits the slot count; assignment on demand supports any layout at a few gates of logic per slot. **Improvements.** On a surprise removal PCI returns all ones, so every driver must treat all ones as a possible error; the pdp64 uses the precise bus fault the instruction set already defines, so the driver has a single recovery path. The queue's overflow rule makes boot and recovery the same code. **Benefits.** The kernel needs one fixed address, the bus controller's, to find every device, and the hand-off at boot shrinks to memory, cores and that address. **Modern comparables.** PCI Express enumerates through configuration space with hot-plug signalled by a slot-status interrupt; USB hubs report port changes through a status-change endpoint; NVMe and `virtio` keep their queues in host memory and re-queue them after a reset. **Impact.** *Kernel:* Enumeration is one loop over the slots; hot-plug is an interrupt and a queue the kernel drains. *Compiler:* None. *Hardware:* A slot register, an information register, an event queue of about eight entries and one presence bit per slot.

*Commentary on 2.6.7 and 2.6.8.* **Precedent.** The VAX did this: the Unibus hung off the VAX-11/780's interconnect through a Unibus adapter, a device on the nexus whose own registers include a table of map registers for DMA and whose Unibus memory (the devices' registers) appears in a window of its own (`UMEM780(i)` in `vaxuba/ubareg.h`, 4.3BSD); `unifind()` in `vax/autoconf.c` probes the devices behind each adapter. PCI-to-PCI bridges nest buses, a USB host controller (itself a PCI Express function) enumerates a tree of hubs and devices, and Thunderbolt tunnels PCI Express over a cable. **Trade-offs.** Each level adds a mapping of windows and a hop of latency, and a departure deep in the tree must be reported to a driver that does not know the path; the cure for the first is that a bridge's windows are ordinary device space (half the 40-bit address space is device space, section 2.1.6), and for the second that every bridge uses the same event register. **Improvements.** A new bus costs one bridge device and no change to the processor, the kernel's walk or the driver model, which is how the design stays small as buses change (the chapter 5 convention for storage, USB, network and display is the same pattern one level down). **Benefits.** Any bus a board offers is connected by a bridge; the PCI Express graphics card of section 3.5 is one such bridge. **Modern comparables.** PCI Express switches and bridges, USB hubs, Thunderbolt, CXL, and the device-tree and ACPI descriptions of nested buses. **Impact.** *Kernel:* one recursive enumeration routine and one hot-plug path for every bus. *Compiler:* none. *Hardware:* a bridge is a device with the standard registers plus a window translation, built once per bus type.

## 2.7 Still open

The bus chapter's open items, each with five options in the decisions document: the transport (R4), the interrupt controller and routing (R1), starting the other cores and inter-processor interrupts (R2, B2), coherence beyond four cores (R3), the register layout and descriptor details (R5; chapter 5), DMA addressing and protection (R6), errors raised by devices (R7), virtualization (R8), and whether to use `virtio` devices in the emulator to reach an OpenBSD login sooner (Q10 and the roadmap).
