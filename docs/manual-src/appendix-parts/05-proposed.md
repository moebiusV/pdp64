**5.3.2** (moved from chapter 5) A device's windows start on page boundaries and are whole pages. *(P)*

**5.10.2** (moved from chapter 5) A device addresses physical memory directly and the driver gives it physical addresses; until an address-translation unit for devices exists, every device must be able to address all of memory. *(P)*

**5.13.1** (moved from chapter 5) Because a device's windows are whole pages, a driver can run in user space with only those pages and its buffers mapped. *(P)*

**5.13.2** (moved from chapter 5) Until devices have an address-translation unit, a user-space driver can instruct its device to write anywhere in memory, so it is as trusted as the device. *(P)*

*In user space* (moved from 5.13). Microkernels and exokernels run drivers as ordinary programs where the hardware lets one device be mapped to one process (*unverified*); the PDP-11's Unibus gave every device a fixed address and no protection. Windows of whole pages make that possible here (5.13.1), and the IOMMU is what would make it safe: until it exists, a user-space driver is as trusted as its device (5.13.2). Linux `VFIO` and `UIO` and the DPDK libraries are the same idea and rely on an I/O translation unit (*unverified*). **Trade-offs.** A driver in user space can be tested, restarted and replaced without taking the kernel with it; its cost is a crossing for each request and the trust above. The whole-page rule also costs address space and no memory, and lets the kernel give one device to one protection domain.

**5.14** (moved from chapter 5) A virtio driver could be exercised before the machine has them by compiling its logic for the host and running it against a software model of a virtqueue. *(P)*

**5.5.4** (moved from chapter 5, the second half) A device that sets its needs-reset bit, or that stops answering, is reset and its queues reprogrammed, and the driver resubmits the chains that are not in the used ring. *(P for the resubmission rule)*

**5.11.2** (moved from chapter 5) A device that is reset leaves its queues in memory untouched; the driver reprograms the queue registers and resubmits the chains that are not in the used ring. *(P)*

**5.11.4** (moved from chapter 5) Requests are repeatable where possible (reads, writes of the same data, sends, buffer posts), so that resending an unfinished chain is safe; a request that must not run twice is tracked by its class driver, which can tell "never started" from "started, outcome unknown" only by the request's own status. *(P)*

### 5.7 Illustrations of a console and a timer (moved from chapter 5)

These illustrate the fixed devices of the open entry J.5.1; they decide nothing.

A complete tiny console driver for a KL11-style console at a fixed address, an illustration (a virtio-console version would replace the three register writes with a transmit-queue post and keep the shape):

```
# fixed address in the present machine (0x8000001000)
CON = MAP_CONSOLE
RXCS = 0;  RXDB = 8;  TXCS = 16;  TXDB = 24  # four 64-bit registers
READY = 1 << 7;  IE = 1 << 6                 # as the KL11's bits
ring txq, rxq                                # circular byte buffers: the clist's job

# vectors 33, 34: con_rxint, con_txint (6.3.3)
con_attach():
    # receive interrupts on; transmit off for now
    mmio_write64(CON + RXCS, IE)

# the boot code and a panic: no queue, no interrupt
con_putc_polled(c):
    while (mmio_read64(CON + TXCS) & READY) == 0: spin
    mmio_write64(CON + TXDB, c)

con_write(buf, n):                           # from the tty layer, as cnstart's caller
    s = spl4()                               # keep con_txint out while txq changes
    for c in buf[0..n): put(txq, c)
    # interrupts while IE is set: starts output
    mmio_write64(CON + TXCS, IE)
    splx(s)

con_txint():                                 # vector 34, level 4
    if empty(txq): mmio_write64(CON + TXCS, 0)       # nothing left: interrupt off
    else:          mmio_write64(CON + TXDB, get(txq))

con_rxint():                                 # vector 33, level 4
    tty_input(mmio_read64(CON + RXDB))       # reading RXDB clears READY
```

A timer tick handler for a fixed counter-and-compare timer: the interrupt stays asserted while the counter is at or above the compare register, so the handler moves the compare register forward by one period. An illustration:

```
timer_attach():
    mmio_write64(TIMER + COMPARE, mmio_read64(TIMER + COUNTER) + PERIOD)
    mmio_write64(TIMER + CONTROL, ENABLE)    # bit 0

timer_intr():                                # vector 32, level 6
    # drops the request
    mmio_write64(TIMER + COMPARE, mmio_read64(TIMER + COMPARE) + PERIOD)
    hardclock()                              # ticks++, due callouts, accounting
```

*Commentary.* **Chain.** PDP-11: the KL11 console has a receive and a transmit CSR with READY and IE bits and interrupts at BR4 on vectors 060 and 064; the KW11-L line clock interrupts at line frequency at BR6 on vector 0100 and `hardclock` runs on each tick; both are at fixed addresses and need no probe (`cons.c`, `scb.s`, read). VAX: an interval timer in processor registers and a console processor (*unverified*). The PC: a UART at a legacy port and a programmable timer, then per-core timers; the ARM and RISC-V systems of today describe their UART and timer to the kernel in a device tree (*unverified*; OpenBSD has the `sys/dev/fdt` bus, read, and a virtio-over-memory-mapped-registers transport `virtio_mmio.c` for machines that have a device tree and no PCI). **Trade-offs.** A fixed console works before the bus does and costs a second device model; a virtio console is one model and cannot print before the queue is set up, unless the emergency write serves; a timer in the core removes a device and a lock and adds system registers, a counter distribution and an architectural definition. **Impact.** *Kernel:* the console must work before enumeration for the boot ROM and the panic path; the timer must work before any driver. *Compiler:* none for the console and entropy; a timer in system registers adds `MTSR` and `MFSR` numbers. *Hardware:* a fixed UART or timer is a few registers; a virtio console is a queue engine; an entropy source is a physical circuit whose quality the standard would promise.
