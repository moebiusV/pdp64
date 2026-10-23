# 2. The bus

[← streamlined index](00-index.md)

**The processor reaches the world through one bus, Q64, on which every device is a handful of memory locations, the bus itself is a device that says what is plugged into it, and every transfer of data is a descriptor in memory that a device carries out and marks done.** This chapter states what the processor owes the bus, how the bus enumerates and maps devices and tells the processor when one comes or goes. How a driver talks to a device, the eight-register layout and the default devices are in chapter 5. Where the design is decided it is tagged *(D)*; where it is the author's proposal not yet settled it is *(P)*. Interrupts and modes are chapter 4, and the other cores are chapter 6. The full discussion is in [`../pdp64-q64-bus.md`](../pdp64-q64-bus.md); the options still open are in [`../decisions-pending.md`](../decisions-pending.md) (R1 to R8, Q10).

## 2.1 Q64 and the address space

**2.1.1** Q64 is the system bus: the Q-bus of the PDP-11 widened to 64-bit data and a 40-bit physical address. *(D)*

**2.1.2** Devices live in the ordinary address space; the processor has no input or output instructions. *(D)*

**2.1.3** Each device occupies its own 4 KB page of physical address space, so that one device can be mapped to one protection domain. *(P)*

**2.1.4** Every page has a memory type: normal cached, normal uncached, device strongly ordered, or device weakly ordered. *(D)*

**2.1.5** The detailed transactions of Q64 (widths, bursts, arbitration, timing) are not yet defined; the proposal is to take AXI as the transport and to treat Q64 as the programming model on top of it. *(P, decision R4)*

*Commentary.* **Precedent.** The PDP-11's Unibus put every device in the address space at a fixed location, which is why a PDP-11 driver is an ordinary program; the Q-bus did the same with multiplexed lines. **Trade-offs.** The memory type is per page, not per access, so the code that writes a device register need not know that it is a device; the price is one page per device, which wastes address space but not memory. Using AXI as the transport saves a bridge between two protocols (estimated at about 600 lookup tables on the FPGA) and loses the Unibus's locked read-modify-write as a native bus transaction. **Improvements.** A 40-bit physical address puts devices and memory in one terabyte, with room for every device to sit in its own page. **Benefits.** An uncached, strongly ordered page needs no special instruction to reach a register. **Modern comparables.** RISC-V and ARM systems use memory-mapped devices on AXI or TileLink; x86 keeps both port I/O and memory-mapped devices.

## 2.2 What the processor owes the bus

**2.2.1** The processor owes the bus exactly three things: a memory type per page, a `FENCE` instruction whose meaning against Q64 is defined, and atomics that can reach device memory. *(D)*

**2.2.2** A driver can be sure a descriptor is visible before it writes the doorbell: it builds the descriptor, executes `FENCE`, and writes the doorbell register. *(D)*

*Commentary.* **Precedent.** The PDP-11 needed none of this because there was one processor and no cache. **Trade-offs.** Three obligations is the whole contract, which keeps the device side free to change without respecifying the processor. **Benefits.** A device and a driver can be written against these three promises without knowing the processor's pipeline. **Modern comparables.** ARM's device-memory types and `DMB`/`DSB`, and RISC-V's `FENCE` with I/O bits, play the same roles.

## 2.3 When an access fails

**2.3.1** A read or instruction fetch of non-existent memory is a precise abort with cause `BUSFAULT`, at the faulting instruction. *(D)*

**2.3.2** A posted write that times out, and an uncorrectable memory error, are machine checks: imprecise and not restartable. A `FENCE` before a probe makes even a posted write precise at a known point. *(D)*

**2.3.3** `PROBER` and `PROBEW` test whether an address can be read or written without faulting. *(D)*

**2.3.4** Resetting the bus is a write to a register of the bus controller, not an instruction. *(D)*

*Commentary.* **Precedent.** A PDP-11 read timeout was an unrestartable bus error, fatal to the process; the `nofault` idiom of V6 and V7 existed to probe for devices without dying. **Improvements.** The read timeout became a precise, restartable abort, and `PROBE` replaces the idiom. **Benefits.** A driver that probes for a device handles a missing one in a few lines of ordinary fault-handling code, which is the recoverability principle at work. **Modern comparables.** x86 machine checks and ARM's `SError` correspond to the imprecise class; PCI returns all ones for a read of a removed device, which every driver must then learn to distrust, and the pdp64 avoids that convention.

## 2.4 Coherence and the hand-off

**2.4.1** Between processors the data caches are coherent without any software action, by snooping with three states (modified, shared, invalid), for two to four cores. *(D)*

**2.4.2** Between a processor and a DMA device they are not: buffers are mapped uncached and the hand-off is explicit. *(D)*

**2.4.3** The hand-off is five steps: the processor builds the descriptors and data in uncached memory, executes `FENCE`, writes the device's doorbell register; the device walks the descriptors, moves the data by DMA, writes the result and a status word, and raises an interrupt; the processor reads the result. *(D)*

*Commentary.* **Precedent.** The 11/70's cache watched Unibus writes so that DMA appeared coherent; the VAX's Unibus adapter had buffered data paths that a driver had to purge. **Trade-offs.** Snooping the DMA path is expensive and DMA transfers are large, infrequent and have an explicit hand-off, so two mechanisms are used, each where it is cheap; the cost is that the processor reads received data from uncached memory, which is slow, and a cache-maintenance instruction would remove it for a non-coherent device that may come later. **Benefits.** No driver can forget a cache clean or invalidate, because there is none to forget. **Modern comparables.** x86 DMA is coherent; ARM and MIPS systems with non-coherent DMA need a DMA-mapping layer in the kernel to place cache maintenance correctly.

## 2.5 Atomics on the bus

**2.5.1** The atomics are defined on a monitor: a load-linked takes a reservation, a write by any initiator clears it, and a store-conditional succeeds only if it is intact; the Unibus's `DATIP`/`DATO` locked pair is not an architectural primitive. *(D, errata 45)*

**2.5.2** A device that writes memory shared with a core takes part by clearing reservations. *(D)*

*Commentary.* **Precedent.** The PDP-11's locked read-modify-write and the VAX's interlocked instructions are bus locks. **Trade-offs.** A lock is simple and a bottleneck as cores multiply; a monitor maps onto AXI's exclusive access and the memory systems of FPGAs and modern chips, at the cost of forward-progress rules. **Modern comparables.** RISC-V `LR`/`SC`, AArch64's exclusive loads and stores, and the large-system atomics that perform the operation at the memory.

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

*Commentary.* **Precedent.** The VAX scanned its interconnect: `probenexi()` in 4.3BSD reads each nexus slot's status register, whose type field says what is plugged in; the Unibus had no enumeration at all, with devices at switch-set addresses and `badaddr()` probes, and nothing told the kernel when a device left. PCI sizes each device's windows by writing all ones to its base registers and assigns addresses; Amiga AutoConfig lets each board announce itself at a fixed address and be told where to live; NuBus gave each slot a fixed share of the address space. **Trade-offs.** A fixed page per slot needs no assignment step and limits the slot count; assignment on demand supports any layout at a few gates of logic per slot. **Improvements.** On a surprise removal PCI returns all ones, so every driver must treat all ones as a possible error; the pdp64 uses the precise bus fault the instruction set already defines, so the driver has a single recovery path. The queue's overflow rule makes boot and recovery the same code. **Benefits.** The kernel needs one fixed address, the bus controller's, to find every device, and the hand-off at boot shrinks to memory, cores and that address. **Modern comparables.** PCI Express enumerates through configuration space with hot-plug signalled by a slot-status interrupt; USB hubs report port changes through a status-change endpoint; NVMe and `virtio` keep their queues in host memory and re-queue them after a reset.

## 2.7 Still open

The bus chapter's open items, each with five options in the decisions document: the transport (R4), the interrupt controller and routing (R1), starting the other cores and inter-processor interrupts (R2, B2), coherence beyond four cores (R3), the register layout and descriptor details (R5; chapter 5), DMA addressing and protection (R6), errors raised by devices (R7), virtualization (R8), and whether to use `virtio` devices in the emulator to reach an OpenBSD login sooner (Q10 and the roadmap).
