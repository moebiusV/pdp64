# Q64: the pdp64 system bus and its devices

[← pdp64 index](../README.md)

**Status: first draft, 2026-10-22.** This document gathers what the other documents already say about the bus, in one place, and lists what is still open. It
decides nothing new except where it says *decided by the author*. Each statement carries a label:

* **Established**: written in the ISA, the implementation plan or the LB64 document, with the section named.
* **Decided**: a decision of the project's author, recorded in [`errata.md`](errata.md).
* **Open**: not yet decided or not yet written.

The processor side (privilege, exceptions, interrupts, memory management, boot) is in [`pdp64-system-architecture.md`](pdp64-system-architecture.md).

The ISA documents have long said "settle it in the bus document". This is that document, begun.

## 1. Why the bus is part of the architecture

The architecture is the processor, the bus and the devices together. The instruction set is its stable core: it is the part that should not change when a
device does. ISA §16 says the devices "none of them touches the ISA", and that is a statement about dependency, so that the device side can churn without
respecifying the processor. It is not a statement that the bus is unimportant. A great deal of what makes the machine pleasant and cheap to program is on the bus
side: how a driver is written, who moves the data, what the processor is promised about ordering, what happens when an access fails. Those are specified here.

## 2. What Q64 is

*Established* (ISA §18, glossary): `Q64` is the system bus, the PDP-11 Q-bus lineage widened to 64-bit data and a 40-bit physical address. It keeps the Unibus and
Q-bus programming model, including the locked read-modify-write transaction pair `DATIP` (data in, pause) and `DATO` (data out). Lineage: Unibus, Q-bus, Q64.

*Open*: the glossary says Q64 was "defined in 11/64 revision 5". That revision is not among the documents here, so the transaction definitions (widths, bursts,
arbitration, timing) are not written anywhere in this repository. This document does not invent them.

## 3. Addressing

* *Established* (ISA §6.1, §8): the physical address is 40 bits; the virtual address is 39 bits (9 + 9 + 9 + 12), "one bit of headroom, no translation needed for
  the physical window".
* *Established* (ISA §8.3): two direct mapping windows, `DMW0` and `DMW1`, translate `PA = VA - VirtualBase + PhysicalBase` with no page-table reference. Physical memory,
  and so a device's registers and a DMA descriptor, are reachable without mapping them first. This is what a driver, a debugger and the bootstrap need.
* *Established* (ISA §16): devices are in the ordinary address space (memory-mapped). The processor has no separate I/O instructions.

## 4. Who can start a transaction

*Established*: the processor is an **initiator**. A device is a **target** (its registers) and, if it moves data itself, also an initiator (DMA). The LB64 accelerator
is the worked example: "a Q64 initiator, not merely a target" (LB64 §7). Several initiators already exist, and a DMA master and a second CPU "are different
problems with different answers, and conflating them is the usual way this goes wrong" (ISA §17).

## 5. What the processor owes the bus

*Established* (ISA §16): exactly three things, and nothing else.

1. **A memory type per page**, the `MT` field of the page-table entry (ISA §8.2):

   | `MT` | meaning |
   |---|---|
   | `00` | normal, cached, write-back |
   | `01` | normal, uncached |
   | `10` | device, strongly ordered |
   | `11` | device, weakly ordered |

   Per page, not per access, so the code doing the writing does not need to know.
2. **An ordering instruction**, `FENCE` (ISA §4.11), with a defined meaning against Q64: a driver can be sure a descriptor is visible before the doorbell write.
3. **Atomics that reach device memory** (ISA §4.11), for queues shared between the processor and a device.

## 6. Coherence and the hand-off

*Established* (ISA §17.3): between CPUs, coherence is transparent to software (snooping MSI at two to four cores). **Between the processor and a DMA device it is the
opposite:** the buffers are mapped uncached (`MT = 01`) and the hand-off is explicit, because snooping the DMA path is expensive and the access pattern is large,
infrequent and has an explicit hand-off. Two mechanisms, each where it is cheap.

*Established* (LB64 §7, ISA §16): the hand-off every device follows, with no coherence protocol:

1. The processor builds the descriptors and data in memory mapped `MT = 01`.
2. `FENCE`.
3. The processor writes the device's doorbell register.
4. The device walks the descriptors, moves the data by DMA, writes the result and a status word, and raises an interrupt.
5. The processor reads the result.

## 7. When an access fails

*Established* (ISA §7.1):

* **A read that times out** (load or instruction fetch of nonexistent memory) is reported as an abort with `ECAUSE = BUSFAULT`, **precisely**, at the faulting
  instruction. This is a deliberate improvement on the PDP-11, where a read timeout was an unrestartable bus error and fatal to the process.
* **A posted write that times out**, uncorrectable ECC and parity errors are **machine checks**, imprecise and not restartable, the descendants of the PDP-11's
  vector 004. A `FENCE` before a probe makes even a posted write precise at a known point.
* `PROBER` and `PROBEW` (ISA §4.11) cover the address-validation case that the old `nofault` idiom served.
* `RESET` is not an instruction: "resetting the bus is a device operation and belongs in a Q64 bus-controller register" (ISA §4.11.1).

*Open*: the error-reporting registers of the bus controller, and which of these a device can raise itself.

## 8. Atomics: the blocking open item

*Established, and open* (ISA open item 4, §17.6; FPGA plan §11, risk 3; LB64 §7): the Unibus-derived `DATIP`/`DATO` locked read-modify-write is a **lock**. AXI exclusive
access, which the FPGA build's memory system uses, is a **monitor**. They are not the same primitive and the mapping between them is not clean. With one initiator
this could wait; **with a second core, or with LB64 contending for a descriptor's status word, it is blocking**. `LL`/`SC` needs a reservation that another initiator's write
invalidates. The `_DB` (barrier) variants of the atomics assert an ordering guarantee that has to mean something on the real interconnect. To be settled before any second
initiator and before the memory system is built.

## 9. The device convention

*Decided by the author* (errata 29, ISA §16): Ethernet, USB and disk devices are each presented as **eight memory-mapped registers** (eight addresses in the ordinary address
space), and **move their data by DMA**. The point is the amount of code. A driver for so small and regular an interface is trivial to write, and because the device moves
its own data the processor only sets up a transfer and carries no multitasking burden for it, so that more of the processor is left for the user and for the programs that
matter. It costs the ISA nothing: it is bus and device design, and uses only what section 5 lists.

*Open*, none of it yet written:

* the meaning and order of the eight registers (and whether USB, Ethernet and disk share one layout with different personalities, or three layouts of the same shape);
* the DMA descriptor format, and how a chain of descriptors is walked (the nearest existing example is LB64's `lb_desc` chain, LB64 §5: a `next` pointer, buffer addresses,
  sizes and a flags word, which stops at `next = 0`; it is specific to one device);
* the doorbell and the interrupt convention;
* whether the existing devices follow it. The `BLT64` blitter (FPGA plan §12) lists nine registers (`BSRC`, `BDST`, `BSPITCH`, `BDPITCH`, `BW`, `BH`, `BROP`, `BMASK`,
  `BCTL`). It predates the convention and is a graphics device, not one of the three; whether it should be made to conform is not decided.

## 10. Interrupts and the other cores

*Established* (ISA §17.4): an inter-processor interrupt path "a memory-mapped per-core register is sufficient and needs no APIC-like complexity", a boot protocol for
releasing secondary cores from reset, and a shared L2 or at least a coherent interconnect are device side and still to be built. A device raises an interrupt when its
transfer is done (section 6, step 4). *Open*: the interrupt controller, the vectors, the per-core registers.

## 11. What it costs

*Established* (FPGA plan §2): the Q64-to-AXI bridge for the FPGA build is about 600 LUTs; this is an estimate, not a measurement.

## 12. The list of open items

1. The Q64 transaction definitions (widths, bursts, arbitration, timing): from "revision 5", not in these documents.
2. Locked read-modify-write against exclusive access (section 8): blocking for SMP and for LB64.
3. The layout of the eight registers; the DMA descriptor format; the doorbell and interrupt convention (section 9).
4. Whether `BLT64` conforms to the eight-register convention (section 9).
5. The bus controller's error registers (section 7).
6. The interrupt controller, the inter-processor interrupt registers and the boot protocol for secondary cores (section 10).
7. The details of the bus as a device: address assignment, the hot-plug alert and the handling of accesses to a departed device (section 13, decided in outline by errata 49).

When the layouts are written they should be written once, as the instruction numbers are, in a grammar from which the register definitions, the driver headers and the
emulator's device models are generated.

## 13. The bus as a device: enumeration, mapping and hot-plug

*Decided by the author* (errata 49, 2026-10-22): **the bus is itself a device with its own set of eight memory-mapped registers.** Through it the processor can **detect what is on the bus** and **ask the bus to map a device to a particular address range**, and **the bus must alert the processor when a device enters or leaves**. The rest of this section is the proposal for how, in the same form as `decisions-pending.md`. Facts about other systems are marked *(not confirmed in the sources read)* unless the text says they were read in the source trees on this machine.

**Why it is good.** The devices are already uniform (section 9: eight registers each); a bus that is one more such device means one driver skeleton for everything, and the kernel needs only **one fixed address**, the bus controller's, to find all the rest. It also removes most of the boot hand-off (`boot.md`, B3): the boot-information block need not list devices, because the kernel can ask.

### What other systems do

* **VAX and Unibus (read in source, 4.3BSD).** The VAX scanned its interconnects: `probenexi()` in `vax/autoconf.c` walks the nexus slots and reads each slot's control and status register, whose type field says what is plugged in; `probe_Abus()` uses `badaddr()` to test whether an adapter answers at all. The Unibus had no enumeration: devices sat at addresses set by switches and the kernel's configuration file said where to look, with `badaddr()` probes to see whether they were present. Nothing told the kernel when a device appeared or disappeared; the machine was powered down.
* **PCI and PCI Express** *(not confirmed in the sources read)*: a configuration space per device, read through an index and data pair or a memory window; the operating system sizes each device's address windows by writing all ones to the base-address registers and reading back, then assigns addresses; bridges extend the tree. Hot-plug is signalled by a slot-status interrupt (presence-detect changed) and handled by a driver such as Linux's `pciehp`. **A removed device's reads come back as all ones**, so every driver has to know to treat all-ones as a possible error; this is a well-known source of recovery code.
* **USB** *(not confirmed)*: a hub reports port changes through a status-change interrupt endpoint; the host enumerates a new device and assigns it an address; hot-plug is the normal case.
* **Zorro II/III AutoConfig on the Amiga and NuBus** *(not confirmed)*: AutoConfig lets each board appear at a fixed configuration address, the operating system reads its identity and size and tells it where to live, and then the next board answers; NuBus gave each slot a fixed share of the address space and a declaration ROM. VME used geographic addressing. These are the closest relatives of "the bus maps a device where the processor asks".
* **Device tree and ACPI** *(not confirmed)*: static descriptions written by someone; ACPI adds hot-plug notifications and eject methods.

### The proposal: the bus controller's eight registers

One device at a fixed physical address (the QEMU virt machine already puts devices in their own 4 KB pages from `0x10000000`). Eight 64-bit registers, using the uniform layout of decision R5 (ID first):

| # | Register | What it does |
|---|---|---|
| 0 | `ID` | read: device type (bus controller), version, number of slots |
| 1 | `CONTROL` | enable the event interrupt, rescan the bus, reset the bus |
| 2 | `STATUS` | event pending, event queue overflowed, busy |
| 3 | `SLOT` | write: select a slot (an index) |
| 4 | `INFO` | read: for the selected slot, present or not, device type and version, size of its register window, the interrupt level it asks for |
| 5 | `MAPADDR` | write: the physical address at which the selected device's window should appear; read back what was assigned |
| 6 | `MAPCTL` | enable or disable the mapping; request an orderly eject |
| 7 | `EVENT` | read: take the next event (arrival, departure or fault, and the slot), zero if none; write to acknowledge |

Reading all slots is a loop of `SLOT` and `INFO`; mapping is `SLOT`, `MAPADDR`, `MAPCTL`. Two points on the layout: (1) a device's eight registers take 64 bytes, but the mapping is made at **page granularity** (4 KB), one device to a page, so the MMU can give a device to a user-space driver or protect it, and the QEMU virt map already does this; (2) the first thing every device shows is the `ID` register, so the enumeration of the bus and the identification of a device use the same read.

### Decision N1: how a device's address is assigned

**The need.** Each device must appear somewhere in the 40-bit physical address space without clashing with another.

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **The bus assigns from a pool: the processor writes the address (or asks the bus to pick one) to `MAPADDR`, the bus programs the device's window** (the AutoConfig and PCI base-address model) | no fixed addresses; any number of devices; hot-plug works | a little logic in the bus controller per slot |
| 2 | **Fixed address per slot** (slot *n* at the base plus *n* times 4 KB; the NuBus model) | no assignment step at all; the simplest hardware; the address identifies the slot | a limit on slots, a fixed map, and a device that moves slots changes address |
| 3 | **Fixed by switches or jumpers** (Unibus) | no logic | manual; no hot-plug; no discovery |
| 4 | **Static table from the boot loader or a device tree** | no hardware logic | no discovery or hot-plug; a table to maintain |
| 5 | **Self-assigned by the device at power-up** (each device picks and announces an address) | no central logic | collisions to resolve; a protocol to design |

*What the PDP-11 and VAX did:* switches and probes on the Unibus; fixed nexus slots read by the kernel on the VAX (read in source). *Recommendation:* **option 2 as the starting point (a fixed 4 KB page per slot) with option 1 available for devices that need a particular address or size**: the fixed page makes every device findable by slot number with nothing to program, which is the least code (principles 1 and 2) and the fewest gates (3), and the `MAPADDR` register costs only a few gates when needed for a larger window. *If nothing is decided:* option 2.

### Decision N2: the alert when a device enters or leaves

**The need.** The author's requirement: the bus must tell the processor when a device enters or leaves.

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **An interrupt at a fixed level plus a small queue of events in the `EVENT` register; if the queue overflows a flag says "events were lost, rescan"** | one mechanism; the kernel's handler pops events until zero; the overflow case reuses the rescan that boot already does, so **there is a single recovery path** | a small queue in the controller (eight entries is enough) |
| 2 | **A per-slot "changed" bit register, level-triggered** (the PCI Express slot-status model) | no queue to overflow; simple | the handler reads every slot's bit to find the change; no record of arrival versus departure order |
| 3 | **Events written as messages into a ring in memory by the bus controller** (DMA) | scales to many slots and rapid change | a ring, head and tail pointers and an address to configure: more machinery |
| 4 | **Polling only: the kernel rescans the bus periodically** | no hardware | latency; wastes time; the kernel needs a timer loop |
| 5 | **No hot-plug: enumerate at boot, reboot to change** (the PDP-11 and early VAX) | nothing | not what the author asked for |

*Recommendation:* **option 1.** It meets the requirement with one small queue, and its overflow rule makes boot and recovery the same code (principle 2: fewer paths). *Cost to build:* the queue and the interrupt in the controller, a QEMU model, a handler in the kernel.

### Decision N3: what happens to accesses when a device leaves

**The need.** A device can be removed while the processor or the device is mid-transaction. The system must not hang or return garbage silently.

| # | Option | Gains | Costs |
|---|---|---|---|
| 1 | **The bus marks the slot absent at once: a read of a departed device's window raises the precise bus fault the ISA already defines (section 7, `BUSFAULT`), a posted write to it is dropped and counted, a DMA descriptor from it is dropped, and a departure event is queued** | one rule; no all-ones convention to know about; the fault handler already exists; a driver's recovery code is "the access faulted: detach" | the controller must track presence per slot (one bit) |
| 2 | **Return all ones on reads from a departed device** (the PCI behaviour) | no fault path in the processor | every driver must check for all ones; a real value of all ones is ambiguous; much recovery code |
| 3 | **Let accesses time out** (the bus waits, then faults) | no presence tracking | a long delay per access; a hung bus for the timeout |
| 4 | **Orderly eject only: a request in `MAPCTL`, the device quiesces, then a departure event** | the cleanest for planned removal | does not cover surprise removal; needs option 1 beside it |
| 5 | **Machine check on any access to an absent device** | the simplest rule | the whole system halts (decision on machine checks, pain-points report) |

*Recommendation:* **option 1 with option 4 beside it for planned removal.** It uses the precise bus fault the ISA already has, so a driver needs one recovery path (detach on fault or on the departure event) and no special value to test, against the all-ones convention of PCI that every driver must know (principle 2). Cost: one presence bit per slot and the fault rule in the specification.

### Effects on the other documents

* **Boot (`boot.md`, B3):** the hand-off can shrink to memory ranges, core count, the address of the bus controller and the slot numbers of the boot device and console; the kernel enumerates the rest (option 4 of B3, self-describing devices, becomes the natural choice).
* **Interrupts (decision R1):** each slot's `INFO` carries the interrupt level the device asks for; routing to cores is still R1.
* **Device layout (decision R5):** the bus controller is the first device that follows it.

## Sources

The ISA ([`pdp64-isa.md`](pdp64-isa.md)): §6.1.1, §7.1, §8.2, §8.3, §16, §17.3, §17.4, §17.6, §18 and open item 4. The implementation plan
([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)): §2, §11 (risk 3) and §12. The accelerator ([`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md)): §5 and §7. Decisions:
[`errata.md`](errata.md) item 29.
