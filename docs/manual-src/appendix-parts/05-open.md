<a id="j51"></a>
### J.5.1 The console, the timer and the entropy source

**Issue.** What is decided is in 5.7.1 and 5.7.2: the main and secure cores take no periodic tick, and the entropy pool is one shared pool that assists the operating system's generator. What is open is the form of the console, of the timer that serves a tickless machine, and of the way the pool is reached and fed. Every standard device of the pdp64 is a virtio device, found by PCI Express enumeration, and three things the machine cannot do without are still unassigned: the **console** (the channel for text in and out, for boot messages and for the last words of a crashing kernel), the **timer** (a source of ticks or one-shot interrupts, and a counter that tells the time) and a **source of random numbers**. Virtio defines a console device and an entropy device (a device that hands out random bytes). It defines no standard timer; a real-time-clock device has been proposed (unverified). A timer can instead live in the processor, as a counter and a compare register in the system registers (the ARM generic timer and the RISC-V `time` register with its compare extension are built this way), or in a small memory-mapped block (a counter and a compare register at a fixed address, as the RISC-V machine timer and the PC's HPET are). On entropy the author has said that he is "not sure random number in hardware is a good idea", and the decided shape of the pool (errata 85, now statement 5.7.2) is one pool shared by all cores, with no per-process pool, no version register and no updatable firmware: it assists the operating system's own generator, which feeds it and draws from it.

**Why it matters.** The console must work before enumeration: the boot ROM, a kernel panic and a machine whose bus is broken all need it. The timer must work before any driver has run. A virtio console needs a queue that the boot code has set up; a fixed UART (universal asynchronous receiver-transmitter: a simple serial port with a data register and a status register) needs two registers. OpenBSD's random-number generator must work from its first call. A timer in the system registers adds registers, and possibly a `RDTIME` instruction, to the instruction set and ABI; a memory-mapped timer adds nothing to either. A fixed UART or timer costs tens of gates, a virtio console costs a queue engine, an entropy source is a physical circuit (ring oscillators and a conditioner) whose quality the standard would be promising, and per-core comparators grow with the core count. Section 5.7, the vector table of 6.3.6 and the boot hand-off of chapter 4 wait on the answer.

**Options.**

1. *Fixed console and timer, virtio-rng for entropy.* A UART-style console and a counter-and-compare timer sit at fixed addresses, found by a small device tree or by the boot-information block; entropy comes from virtio-rng in front of a physical source. For: both fixed devices work without enumeration or a queue, so the boot ROM and the panic path stay tiny; only entropy needs a virtio driver. Against: the manual then has two device models, and "virtio across the board" (the author's words) may not have meant that; one timer shared by all cores forces a lock or per-core windows; wired interrupt lines from the fixed devices need the converter of J.6.3.
2. *Timer in the core, fixed UART, virtio-rng.* A shared constant-rate counter and a per-core one-shot compare register, written with `MTSR` and read with `RDTIME`; a minimal fixed UART for boot and panic; entropy by virtio-rng. For: the timer cannot fire on the wrong core, tickless operation is one write, the secure core simply never writes its compare, and the kernel interface is what OpenBSD's clock-interrupt code needs (read the counter, set a one-shot compare, take the interrupt). Against: it adds system registers and probably `RDTIME` to the instruction set (with the side-channel switch that goes with it); the counter must reach many cores with a stated bound on skew; the architecture, not only the platform, now defines the timer; `RDTIME` needs an ordering rule for out-of-order cores; the UART is still a non-virtio device.
3. *Everything enumerated.* The console is virtio-console, found by enumeration (the boot ROM carries a small polled virtio driver, or a console private to the ROM); entropy is virtio-rng; the timer is in the core as in option 2. For: the strictest reading of "virtio across the board"; one transport driver and one enumeration walk serve console, entropy, disk, network, graphics and audio; OpenBSD already has drivers for both devices. Against: the console cannot work before the bus does, so when the queue, the IOMMU mapping or the root complex is wrong nothing prints, and the earliest boot is hardest to debug where debugging is most needed; a panic path that first needs a descriptor in uncached memory and a doorbell is longer than a store to a data register; a queue engine in hardware just for text.
4. *The absorb-and-squeeze pool as a fixed device.* A write mixes into a pool of 256 or 512 bytes and a read returns fresh randomness; one device shared by all cores, no version register, no firmware; console and timer as in option 1 or 2. For: it is the author's own proposal, accepted in errata 85 ("a read with a known and wanted effect is not a strange side effect"); it feeds the operating system's generator without replacing it; the hardware is a small pool and a mixer. Against: it would break if OpenBSD changed its randomness algorithm (the author's own remark); a read with an effect on shared state is a known hazard (the shared-buffer leaks of 2020 in x86 processors); the device is neither virtio nor standard and needs a PCI Express function or a fixed window; the author's doubt argues against putting more in silicon than a physical source.
5. *No entropy hardware.* OpenBSD's generator is used as it is: it gathers timing from interrupts, disk, network and clock, and starts from a seed file written at the last shutdown, with a flag that says whether the seed was good; no virtio-rng; console and timer as in option 1 or 2. For: it answers the author's doubt with no hardware to trust, costs no gates and is the smallest design; OpenBSD's design assumes weak seeding and copes with it. Against: the first boot with no good seed is weak, and so is a clone of a virtual disk (the seed repeats); main cores are tickless by the author's rule, so fewer timer interrupts feed the generator; address-space randomisation spends entropy, and the address space is small.
6. *Virtio-console, with its emergency write for boot and panic.* The console is virtio-console, found by enumeration; the boot ROM and the panic path use the feature `EMERG_WRITE` (feature bit 2), which lets a driver print one character by storing it in the `emerg_wr` field of the device configuration (offset 8), with no queue, no descriptor, no memory buffer and no IOMMU entry; the ordinary tty driver uses the queues. For: it keeps the console a virtio device and the panic path a store; the field is in the standard; OpenBSD's `viocon` and QEMU already carry the device. Against: the store is to a mapped window found by enumeration and not to a fixed address, so the boot ROM still needs the bus walk and the capability search before it can print; OpenBSD's `viocon.c` does not use `EMERG_WRITE`, so the panic path would be new kernel code; a device or emulator that does not offer the feature leaves no way to print.

![The console and the timer as the options stand](figures/drv-console-timer.svg)

**Precedents.** QEMU's `virt` machines for ARM and RISC-V place a UART at a fixed address, and on RISC-V a core-local timer, both described to the kernel by a device tree (a data structure the firmware passes to say what the machine contains), with virtio devices beside them *(unverified)*. The RISC-V `stimecmp` register (the supervisor timer compare register, with the Sstc extension) is written directly where present, and by a firmware call where it is not *(verified: OpenBSD riscv64 `clock.c`, lines 63 to 70)*; OpenBSD's whole riscv64 clock backend is 175 lines *(verified)*. The ARM generic timer has a shared system counter and a per-core compare *(unverified)*. x86's TSC-deadline mode (a per-core one-shot compare against the time-stamp counter) depends on an invariant counter, and the Linux maintainers' own remark on it is that "the stupid hardware is not reliable" *(verified: quoted in the repository)*. Firecracker and QEMU's microvm use virtio for the console where no UART is wanted *(unverified)*. OpenBSD has `viocon` and `viornd` drivers; `viornd` asks for 16 bytes at boot and then every 15 seconds *(verified by a fetched listing only)*. OpenBSD's generator absorbs events into a pool and draws ChaCha20 output from it *(verified)*; on machines with no hardware generator it runs the software path with a seed file read by the boot loader *(verified)*. Intel `rdrand` and `rdseed` and the AArch64 `RNDR` register are hardware sources that OpenBSD reads and mixes *(verified: source files of the local tree)*; RISC-V's Zkr extension provides a `seed` register of raw bits for the operating system to condition *(unverified)*. What virtio provides *(verified: the Linux headers, QEMU and OpenBSD sources read)*: console is device type 3, port 0 has a receive and a transmit queue (queues 0 and 1 in QEMU's `virtio-serial-bus.c`, with further control queues when `MULTIPORT` is negotiated), the configuration holds `cols`, `rows`, `max_nr_ports` and `emerg_wr`, and QEMU passes the low byte written to `emerg_wr` to the port; OpenBSD's `viocon.c` (617 lines) drives the queues through the tty layer and asks only for `SIZE`. Entropy is device type 4 with one queue: the driver posts a device-writable buffer and the device fills it with random bytes (QEMU `virtio-rng.c`, 8 entries); OpenBSD's `viornd.c` (201 lines) passes each word to `enqueue_randomness`, so the device feeds the kernel's generator, the shape of errata 85. Timer: the identifier list has `VIRTIO_ID_CLOCK` (17) and `virtio_rtc.h` defines a clock-reading request, a cross-timestamp request and an alarm (`VIRTIO_RTC_F_ALARM`, `SET_ALARM`), and QEMU has a `vhost-user-rtc` device; whether a periodic tick or a one-shot compare could be served by it is not stated by any file read. The PDP-11 had a KL11 console (a receive and a transmit register, BR4, vectors 060 and 064) and a KW11-L line clock (BR6, vector 0100) at fixed addresses with no probe *(verified: 2.11BSD `cons.c`, `scb.s`)*.

**The author's referents.** "forget the native 8 register devices. gone. virtio across the board." (chosen); for the boot console, the PDP-11's "load 512 byte block 0 then jmp 0" (considered). He named no console, timer or entropy system from elsewhere.

**The assistant's leaning.** Entropy: option 5 with virtio-rng as an optional device, no instruction and no register, and the pool of option 4 left for the author to revive only if virtio-rng proves too slow. Timer: option 2, a counter and compare in the core. Console: a minimal fixed UART kept for the boot ROM and the panic path, with virtio-console optional for ordinary use. The reason is that the earliest boot and the panic path are the author's first priority (errors must be easy to detect), and a data register that the boot ROM can write in one store works before any queue exists; the timer in the core removes a device and a lock and matches the tickless rule; the entropy doubt is respected by keeping any physical source behind virtio-rng and mixing it, never using it alone. A decision that no non-virtio device is allowed would favour option 3, at the price of a harder first boot; a need for a hardware key-generation source in the secure core would add a seed register of raw bits.

**Where the body refers to it.** Sections 5.7.1 and 5.7.2.

<a id="j52"></a>
### J.5.2 The features that the pdp64 accepts

**Issue.** Before any queue runs, a virtio driver reads the features the device offers and writes back the subset it accepts, and the device confirms it (5.4.4). The version-1 feature is required. Everything else is a choice that the architecture has not made: which features a driver accepts for the disk (flush, block size, segment limits, read-only), the network card, the display and the sound device, whether the platform declares that device addresses go through the IOMMU (`VIRTIO_F_ACCESS_PLATFORM`, feature 33) and whether it declares that the platform orders memory accesses by its own rules (the platform-ordering feature, `VIRTIO_F_ORDER_PLATFORM`, feature 36, *unverified*).

**Why it matters.** The features fix what a device may do to memory and in what order: with `ACCESS_PLATFORM` the descriptor holds a device address that the IOMMU of 2.11 translates, and without it the device is told to use physical addresses and the IOMMU has nothing to do. The ordering feature decides whether the `FENCE` of 5.3.5 and the device-side order of 5.10.3 are enough. The choice also decides how much of each virtio device the first operating system's drivers must handle.

**Options.**

1. *The minimum.* Version 1 and the features a device class cannot work without; nothing else. For: the smallest driver, the least to test, the fewest paths in hardware. Against: no flush on the disk means a write that is not known to be on the medium; no segment limit means a driver that must discover failure by an error.
2. *The set that OpenBSD's drivers already ask for.* `vioblk` asks for `RO`, `NOTIFY_ON_EMPTY`, `SIZE_MAX`, `SEG_MAX` and `FLUSH` *(verified: `vioblk.c`)*, and the other class drivers ask for their own. For: the first operating system needs no change; the devices of QEMU already offer them. Against: the set is another system's habit and not a pdp64 decision; it changes with that system.
3. *The minimum plus the platform features.* Declare `ACCESS_PLATFORM` always, so that every device address is translated, and the ordering feature, so that the order is the platform's. For: matches the IOMMU on by default (errata 85) and the one fence rule; a device that cannot work this way is refused at the handshake. Against: a device or emulator that does not offer the features cannot be used; the IOMMU must exist before the first driver runs.
4. *Option 2 plus the throughput features.* Indirect descriptors (one descriptor pointing at a table of descriptors), the event index (the device and driver tell each other when to interrupt or notify) and the packed ring (the newer queue layout of version 1.1, *unverified*). For: fewer doorbells and interrupts, longer chains. Against: more states for the driver and for the hardware queue engine to model; the packed ring is a different queue format, so all descriptors, rings and the ordering rules of chapter 2 would have two forms.

**Precedents.** Linux and OpenBSD accept a subset and ignore the rest; OpenBSD's `virtio_negotiate_features` masks what the driver does not know *(verified in `virtio.c`: the source read; the exact masking was not checked)*. `ACCESS_PLATFORM` is how a guest with an IOMMU or a secure enclave tells the device to use the platform's address translation *(unverified)*.

**The author's referents.** "forget the native 8 register devices. gone. virtio across the board" (errata 95); "we will support all the virtio devices in silicon (the ones it makes sense to support, that is)" (message 592:13).

**The assistant's leaning.** Option 3 for the platform features, and the set of option 2 for each class (they are what the first operating system needs anyway), with indirect descriptors left out until a measurement asks for them.

**Where the body refers to it.** Sections 5.4.4 and 5.10.3.

<a id="j53"></a>
### J.5.3 Firmware for a virtio device

**Issue.** A device that contains a small processor may need a program, firmware, loaded into it before it works. A PDP-11 peripheral needed none. On a PC the driver reads a file at attach time (OpenBSD's `loadfirmware` reads `/etc/firmware/<name>`; 19 files under `sys/dev/pci` call it, counted). Virtio has no firmware operation: a search of all 29 `virtio_*.h` files and of QEMU's `hw/virtio` finds none, and each device class defines its own set of requests, so a firmware download would be a request that no class has. The pdp64 has set one precedent: the entropy pool has "no updatable firmware" (errata 85).

**Why it matters.** A network card or a GPU built as a virtio function may need its program before the first request, and the standard gives no way to send it. Whatever is chosen must leave a device the boot depends on (the disk, and the console if it is a device) free of it, since the root file system is not yet readable when the boot device is started.

**Options.**

1. *A firmware request in each class.* Each device class defines a request type that carries an image through a queue. For: uses the transport that exists; the image is checked by the device. Against: not in the standard, so every device and every class driver differs; a QEMU model needs it too.
2. *A firmware-loader device.* A separate device type, enumerated beside the function it serves, that takes the image. For: one mechanism for all classes; a device that needs nothing is not affected. Against: a new device type outside the standard; two functions to pair.
3. *A window in the device's own space.* The driver writes the image into a window of one of the function's base-address registers, as PCI devices do today. For: independent of virtio; any PCI Express function can use it. Against: every device defines its own window and command sequence; the "same driver for every device" aim of virtio is lost for those devices.
4. *No downloadable firmware.* The pdp64's standard devices carry their own program in ROM or flash; a device that needs a download is not a standard device and has its own driver. For: no mechanism to define; matches the entropy pool's rule. Against: a device that is cheap because it has no flash cannot be a standard device; an update means new hardware.

**Precedents.** PC practice: a file per device, a loader in the kernel (`loadfirmware(9)` in OpenBSD, `firmload(9)` in NetBSD) and a separate package of files *(verified for OpenBSD: `dev/firmload.c`)*; Linux's `request_firmware` is the same idea *(unverified)*. The PDP-11 had none *(verified: 4.1)*.

**The author's referents.** None named for firmware; the entropy pool "no updatable firmware" (errata 85).

**The assistant's leaning.** Option 4 for the standard devices, with option 3 left to the drivers of devices that are not standard.

**Where the body refers to it.** Section 5.12.

<a id="j54"></a>
### J.5.4 Failure, reset and departure: what happens to the queued work

**Issue.** A virtio device can fail in three ways that matter to its driver: it reports a failed request through the status byte, it sets its needs-reset bit or stops answering, or it leaves the bus (hot-plug is decided; see 2.4). In the last two the chains in the queue were handed to a device that will not finish them. What is decided is that a departed device's work is left in memory, "so it can be read, saved, resent" (message 1889:2641; 2.4.5 and 5.5.5). What is not worked out is the rule: when the driver resubmits the chains that are not in the used ring, when it fails them, and whether another core takes them over. A request that must not run twice (a write to a device that took it and died, a send) cannot simply be resent.

**Why it matters.** Every class driver has a recovery routine, and the disk driver's behaviour decides whether a file system sees an error or a delay. The kernel's rule decides whether a driver has a detach routine at all (the OpenBSD `vioblk` has none) and who reads a departed device's rings.

**Options.**

1. *Fail every queued request.* After a reset or a departure the driver completes each outstanding request with an error and starts afresh. For: simple; no request is run twice; it is what OpenBSD's `vioblk_reset` does. Against: a transient hiccup becomes an I/O error for the file system; the author's wish that the work be resent is not met.
2. *Resubmit the chains that are not in the used ring.* The driver compares the available ring with the used ring, reprograms the queue and posts the unfinished chains again. For: the author's stated purpose; no error for a stall. Against: a request that already ran, or ran partly, runs twice; the driver of OpenBSD zeroes the ring memory on reinitialisation, so the chains would have to be copied out first.
3. *Resubmit only repeatable requests.* Reads, writes of the same data, sends and buffer posts are resent; any other request is failed. The class driver knows which is which. For: safe by construction; each class decides. Against: a class driver can tell "never started" from "started, outcome unknown" only by the request's own status, so some requests must fail even when they never ran.
4. *Hand the queue to another core.* The core that handles the departure event may not be the one that owns the queue; the unfinished work is handed over with the chains and their buffers. For: fits a machine of many cores and a secure core; the author's reference to a hand-over. Against: more kernel machinery; a rule is needed for what the old core may still touch.
5. *Leave it to each class driver.* The kernel gives a reset and a departure event; each driver chooses one of the above. For: a disk and a network card have different needs (a lost frame is harmless, a lost write is not). Against: no common routine, as many recoveries as classes.

**Precedents.** OpenBSD's `vioblk_reset` stops the device, completes what finished and fails every other request; its re-initialisation zeroes the ring memory and restarts both indices at 0, and `vioblk` has `{ sizeof(softc), vioblk_match, vioblk_attach, NULL }` as its `cfattach`, so it has no detach routine *(verified: `vioblk.c`, `virtio.c`)*. The VAX's `ubareset` resets the adapter and calls every driver's reset routine, so that each re-issues what was pending: resending, driver by driver *(verified: 4.3BSD `vaxuba/uba.c`)*. NVMe and virtio drivers in other systems requeue outstanding requests after a reset *(unverified)*. Linux's driver model has `probe` and `remove` *(unverified)*. Whether the virtio specification requires the ring indices to restart after a reset *(unverified: the specification is not on this computer)*.

**The author's referents.** "so it can be read, saved, resent" (message 1889:2641); the precise bus fault for a departed device (2.4.9, 2.9.1).

**The assistant's leaning.** Option 3 as the kernel's common routine, with a class driver free to be stricter (option 5 above it): the file system sees no error for a repeatable request, and no request runs twice.

**Where the body refers to it.** Sections 5.5.4, 5.5.5 and 5.11.2.

<a id="j55"></a>
### J.5.5 The fence in C

**Issue.** A driver must execute `FENCE` between the last write that the device will read and the write that notifies the device (5.3.5, 5.4.3). The instruction exists. Nothing in the C language names it, and the compiler has no intrinsic (a built-in function that the compiler turns into an instruction) for it. A driver can call a function written in assembly, but then the fence is a call, with the call's cost and the compiler's assumption that registers may be changed.

**Why it matters.** Every driver of the chapter, and every lock and queue of the kernel that shares memory with a device, executes this fence on its fast path. The answer is part of the compiler and of the ABI (appendix D), and the OpenBSD port needs a spelling for its own memory-barrier macros.

**Options.**

1. *An intrinsic.* A built-in such as `__builtin_pdp64_fence()` that the compiler turns into the instruction and treats as a barrier against reordering. For: one instruction, no call, the compiler knows it is a barrier. Against: a new name that only this compiler knows; the LLVM back end needs it as well.
2. *Inline assembly.* The driver writes `asm volatile("fence" ::: "memory")`. For: needs nothing new in the compiler. Against: every driver repeats it; the compiler that has no inline assembly cannot build it.
3. *A function in assembly.* A leaf function in the runtime library. For: works with any compiler. Against: a call on every doorbell; the compiler must assume everything changed.
4. *The C11 fences.* `atomic_thread_fence` and the release and acquire orderings, mapped by the compiler to `FENCE` as needed. For: standard C; portable drivers. Against: the C11 orderings describe threads and not a device, and a mapping that is too weak or too strong is a bug that no test shows.
5. *The platform's barrier macros.* The operating system defines `membar_producer`-style macros in a header, built on one of the above. For: what OpenBSD code expects. Against: it answers only the spelling, and not how the compiler treats the fence.

**Precedents.** Linux defines `mb()`, `wmb()` and `rmb()` per architecture, and OpenBSD `membar_producer()` and `membar_consumer()` *(unverified)*. The compiler's name table (`arch/pdp64/pdp64-names.h` of the pcc tree) knows the mnemonic and nothing else *(verified: read)*.

**The author's referents.** None named; the one fence rule of the bus chapter (2.8).

**The assistant's leaning.** Option 1, with option 5 on top of it for the operating system: it is the only spelling that costs nothing at run time and that the compiler can reason about.

**Where the body refers to it.** Section 5.13.1.

<a id="j56"></a>
### J.5.6 Which virtio devices are built in silicon, and syntactic sugar for devices

**Issue.** On 2026-11-09 the author wrote that "we will support all the virtio devices in silicon (the ones it makes sense to support, that is)", and asked what "syntactic sugar" (notation that makes a thing easier to write, not new opcodes) could make devices easier to use "like the 12 register + dma thing" (message 592:13). Both are decided in principle (statement 5.2.1). Two details are not. The standard devices are fixed (block, network, graphics, audio: errata 79, 101); virtio has others (console, entropy, balloon, SCSI, file system, socket, input) and it is not settled which count as "it makes sense". And it is not settled what the sugar is.

**Why it matters.** The list decides what the hardware contains and what OpenBSD drivers are used. The sugar decides how short a driver is, and whether the instruction set or only the assembler and the compiler change.

**Options.**

1. *Only the four standard devices.* Block, network, graphics and audio; everything else is an ordinary PCI Express device with its own driver. For: the least silicon. Against: the console and the entropy source of J.5.1 would have to be in this list or outside virtio.
2. *The four plus the console and the entropy source.* For: the machine can boot and run with virtio alone; both have OpenBSD drivers (`viocon`, `viornd`). Against: the console's form is itself open (J.5.1).
3. *Every device that QEMU and OpenBSD both have.* That adds the balloon (`viomb`) and SCSI (`vioscsi`). For: free drivers. Against: silicon for devices that few uses need.
4. *Sugar: assembler macros.* The post, fence and notify sequence of 5.4.3 as one macro, and the reap loop as another. For: no change to the instruction set, no change to the compiler. Against: only assembly programmers benefit.
5. *Sugar: a C header of inline functions.* `post` and `reap` of chapter 2 as inline functions over the intrinsic of J.5.5. For: C drivers become short; no hardware. Against: depends on J.5.5.
6. *Sugar in the device: helper registers.* The bus chapter allows "helper registers" for convenience (2.3.4); for example a doorbell that also performs the fence. For: the driver's sequence shortens. Against: not in the standard, so a driver that uses it works on the pdp64 only.

**Precedents.** The RK11's register set (a command register and a go bit) was the "12 register + dma" style the author refers to *(verified: 5.1)*. virtio drivers share `virtio_enqueue` and `virtio_alloc_vq` helpers in OpenBSD *(verified: `virtio.c`)*.

**The author's referents.** "like the 12 register + dma thing" (message 592:13).

**The assistant's leaning.** Option 2 for the list, and options 4 and 5 together for the sugar.

**Where the body refers to it.** Section 5.2.1.

<a id="j57"></a>
### J.5.7 USB: the controller interface and the class drivers

**Issue.** USB is a standard device of the pdp64 (statement 5.8.3: the author, 2026-08-29 and 2026-11-03, "modern usb keyboard, mouse, and nvme hard drive", "pcie and nvme and usb"): a host controller that is a PCI Express function, with the operating system's USB stack enumerating what is plugged in. Two details are not worked out. The first is the controller interface, the register and memory layout that the driver programs. The one that PCI Express USB controllers have is xHCI (extensible host controller interface): the controller runs the protocol in hardware, the driver gives it lists of transfer descriptors in memory and reads an event ring, the same pattern as a virtqueue with formats of its own. The second is which class drivers are needed: the author's uses are a keyboard and a mouse (the human interface device class) and a hard drive (mass storage); that a USB-to-Ethernet adapter appears to the host as a network class device is *unverified*.

**Why it matters.** The controller interface decides the one USB driver that the kernel carries and what the hardware and the emulator model must provide; the class drivers decide whether the machine has a keyboard and a mouse at first boot.

**Options.**

1. *xHCI only.* One controller interface, a small compliance-tested subset of it. For: what real USB 3 controllers on PCI Express present; one driver. Against: a large and complex interface (many registers, rings and contexts); no older USB 1 or 2 controller works.
2. *xHCI plus a simpler controller interface for the first board.* For: a smaller first driver. Against: two drivers; a second model for the emulator.
3. *A pdp64 controller that is a virtio device.* For: "virtio across the board". Against: the virtio device types read here list no USB host controller *(unverified: not searched for)*; a bridge to real USB hardware is still needed.

**Precedents.** NVMe and xHCI both command through queues in memory *(unverified: general knowledge)*. OpenBSD drives PCI Express USB controllers through its `xhci` driver *(unverified here)*.

**The author's referents.** USB enumerated over PCI Express as the model of a bus attached to a bus ("just as usb is unuerated over a pcie bus", message 1889:2941); "modern usb keyboard, mouse, and nvme hard drive. usb hard drive too" (message 531:0). He named no controller interface.

**The assistant's leaning.** Option 1: xHCI only, as the repository's earlier lean (decisions-pending F9) said.

**Where the body refers to it.** Section 5.8.3.
