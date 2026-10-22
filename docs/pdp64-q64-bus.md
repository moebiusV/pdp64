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

When the layouts are written they should be written once, as the instruction numbers are, in a grammar from which the register definitions, the driver headers and the
emulator's device models are generated.

## Sources

The ISA ([`pdp64-isa.md`](pdp64-isa.md)): §6.1.1, §7.1, §8.2, §8.3, §16, §17.3, §17.4, §17.6, §18 and open item 4. The implementation plan
([`pdp64-fpga-plan.md`](pdp64-fpga-plan.md)): §2, §11 (risk 3) and §12. The accelerator ([`pdp64-lb64-accelerator.md`](pdp64-lb64-accelerator.md)): §5 and §7. Decisions:
[`errata.md`](errata.md) item 29.
