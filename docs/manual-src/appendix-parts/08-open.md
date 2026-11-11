<a id="j81"></a>
### J.8.1 The operations and the number formats of the vector device

**Issue.** The decision (errata 59; chapter 8, 8.3 and 8.4) is that wide data-parallel work goes to memory-mapped devices driven by descriptors, and that the array languages APL and K map their whole-array primitives onto them. What has not been chosen is the operation set of such a device and the number formats it handles, and how a program finds out. The processor itself has only `binary64`, `binary32` and `binary16` (8.6.1). A neural-network layer wants bfloat16 (a 16-bit format with the exponent range of the 32-bit one), 8-bit integers accumulated in 32 bits, binary weights and 8-bit floating point; an array language wants element-wise arithmetic and comparison, selection, reductions, scans, gather and scatter, compress (`where`) and index generation over integer, floating-point and bit-array types.

**Why it matters.** The operation set decides what an array-language interpreter can hand to the device and what stays on the processor, and so whether the device repays its setup at all. The formats decide whether a model that is published in one of them runs. A library has to choose among devices, so the device must say what it can do.

**Options.**

1. *A small fixed set of element-wise, reduce, scan and gather operations on the integer and `binary` formats.* For: simple to build and to verify; covers the array primitives. Against: the machine-learning formats are left out.
2. *Option 1 plus the formats of the field today (bfloat16, 8-bit integers, 8-bit floating point).* For: serves inference as well as arrays. Against: the field changes its formats every few years; a fixed list is soon stale.
3. *Operations and formats named by the device itself in its identification block and feature bits, so a library asks.* For: a new device brings new formats without a change of the architecture; one driver skeleton. Against: a library must cope with devices of different capability.
4. *One operation set per device kind.* An inference engine, an array engine and a graphics engine each define their own. For: each is small. Against: the same element-wise units are built three times.
5. *Nothing in the architecture.* Each device defines its own operations and the driver knows them. For: nothing to decide. Against: no portable array-language runtime.

**Precedents.** x86 put half precision, bfloat16 and the `VNNI` dot products into the instruction set; ARM has `BF16`, `SDOT` and matrix extensions *(unverified: from memory)*. ARM's Ethos and Mali engines and Google's TPU are devices with their own formats *(unverified)*. The kdb+ and K interpreters use AVX2 on x86 *(unverified)*; array-language compilers for GPUs (Futhark, Co-dfns) offload in the same way *(unverified)*. The PDP-11's attached array processors took library calls with a fixed function list *(verified by one brochure)*.

**The author's referents.** "mmap device arm style route"; APL and K "easier to support and more efficient"; "just optimize inference whether in cpu or gpu whatever makes most sense".

**The assistant's leaning.** Option 3: the formats are descriptor fields and the device names what it does, so the processor's instruction set does not have to change when a format does.

**Where the body refers to it.** Statements 8.5.5 and 8.6.2.

<a id="j82"></a>
### J.8.2 The descriptor of a vector device and the virtio descriptor

**Issue.** Chapter 5 uses virtio queues for the standard devices (5.4.2); a virtio descriptor is 16 bytes and names one buffer (a 64-bit address, a 32-bit length, flags), and descriptors chain with the `NEXT` flag. The descriptor that a vector device needs (an operation, several array addresses with lengths and strides, formats, a chain) is larger. The two must be reconciled, or the vector device uses a form of its own.

**Why it matters.** If a vector device does not fit the virtio queue, it needs a ring engine, a driver skeleton and a protection story of its own, which is the cost that the ring was meant to avoid. Chains (one descriptor following another with no processor in between) are how a layer of a network or a sequence of array primitives is expressed.

**Options.**

1. *The virtio descriptor points at a device-defined work block, which can chain.* The ring carries pointers to work blocks. For: one ring for every device; the work block can be any size. Against: one more memory fetch for the work block; the work block is in the device's own format.
2. *A larger descriptor for every device.* For: no indirection. Against: wastes ring space for devices that need little; departs from virtio.
3. *Extension descriptors chained after the virtio one.* For: the common case stays 16 bytes. Against: a device must walk the chain to find its operands.
4. *A ring of its own for vector devices.* For: fits the workload. Against: a second ring engine and a second driver skeleton.

**Precedents.** Rings of descriptors with ownership bits are how the DEUNA Ethernet controller of 4.3BSD worked (`if_de.c`, chapter 5) and how virtio works *(verified in chapter 5)*; the PDP-11's RK11 had no chain, one transfer in the registers at a time (chapter 5, 5.1); virtio's indirect descriptors point to a table of further descriptors *(verified in the repository's sources)*; NVMe commands point to lists of data pages *(unverified)*.

**The author's referents.** None named beyond "descriptors".

**The assistant's leaning.** Option 1, which keeps the one ring.

**Where the body refers to it.** Statement 8.4.4.

<a id="j83"></a>
### J.8.3 Packed integer lanes in the ordinary registers

**Issue.** The processor has no vector register file (8.3.1). A smaller question remains: whether a handful of instructions should treat a 64-bit integer register as packed bytes, halves or words (add, compare, minimum, and select per lane), so that string, memory and hash routines run several lanes at a time without a vector register. The statement as first written: packed-lane operations in the ordinary integer registers are not part of the decision; they remain a possibility to be settled by measurement. *(P)*

**Why it matters.** The opcode map has room for few new words; the compiler would need to recognise the loops; and the answer is a measurement that nobody has made. Library routines such as `memchr` and `strlen` gain most from it.

**Options.**

1. *None.* For: no opcodes spent; the processor stays small. Against: byte-at-a-time string loops.
2. *A few packed instructions for bytes, halves and words (add, compare to a mask, minimum and maximum).* For: serves string and memory routines. Against: opcodes; ABI and assembler work; a width fixed at 64 bits.
3. *Only a zero-byte test and a population count.* For: smallest set that speeds `strlen` and `memchr` and is already close to `POPCNT`. Against: leaves the rest.
4. *Packed lanes on the device only.* For: nothing in the processor. Against: setup cost is too high for short strings.

**Precedents.** MMX, SSE and NEON began as packed lanes in existing registers on x86 and ARM *(unverified)*; RISC-V's base set has none and its `Zbb` extension has `orc.b`, which marks zero bytes *(unverified)*; the PDP-11 had none.

**The author's referents.** "the simd/avax stuff" as the thing to settle by the device route.

**The assistant's leaning.** Decide by measurement: compile the corpus at higher optimisation and count the loops that would be vectorised, measure the share of time in memory and string routines, and estimate the block-RAM cost, before any opcode is spent.

**Where the body refers to it.** Statement 8.3.4.

<a id="j84"></a>
### J.8.4 The first accelerator

**Issue.** The decision (8.4) says that wide work goes to accelerator devices and not what the first one is. The author's words give two pointers that do not agree. On 2026-10-20 (R136) he asked what "a gpu ... optimized purely for samsung's littlebit-2 encoding" would look like, which points to a device for one family of binary-weight language models. On 2026-10-23 (R278) he wrote that "if we can plug a regular card into the bus, why not", and on 2026-11-04 (R315) that "for now we will have a standard pcie set of audio/video devices", which points to the standard devices of chapter 5 and no accelerator of the pdp64's own. A first accelerator needs a transport (J.8.2), a set of operations and formats (J.8.1) and a driver.

**Why it matters.** The first accelerator sets the first descriptor format, which every later one will copy. A device that is built for one model family is fast on it and idle on the rest. Until one is chosen, "inference on the device" (8.5.1) has no device.

**Options.**

1. *An inference engine for binary-weight models.* A device that evaluates the layers of one family of models with adders and sign flips and no multipliers, driven by chains of descriptors (H.8, the LB64 design). For: the strongest fit to the workload the author named; small in logic, set by memory bandwidth. Against: one model family, so a change in the field strands it; no help to the array languages.
2. *A general vector engine.* Element-wise arithmetic, reductions, scans and gather over the integer and floating-point formats (J.8.1, options 1 and 2), driven by descriptors. For: serves the array languages, graphics work and inference. Against: not specialised, so slower than option 1 on the one model; a larger design.
3. *Both, in that order or the other.* For: each answers one of the author's two uses. Against: two descriptor formats unless J.8.2 settles one.
4. *A standard PCI Express card, and nothing of the pdp64's own.* The accelerator is whatever card a driver exists for (a GPU or a neural-network engine of the field), reached through the bus of chapter 2. For: no hardware to design; matches "if we can plug a regular card into the bus, why not". Against: such cards have their own command formats, not virtio, so the driver skeleton of chapter 5 does not serve them; the machine's own inference story is a library for someone else's device.
5. *None until the transport is settled.* For: nothing built on an unsettled descriptor. Against: no accelerator to measure the decision against.

**Precedents.** Attached array processors on PDP-11 hosts (8.1) took library calls and a fixed function list *(unverified here)*; ARM systems attach Ethos and Mali engines as memory-mapped devices *(unverified)*; Google's TPU is a PCI Express card *(unverified)*.

**The author's referents.** "what would a gpu look like that is optimized purely for samsung's littlebit-2 encoding" (R136, thread 533 message 51); "if we can plug a regular card into the bus, why not?" (R278); "for now we will have a standard pcie set of audio/video devices" (R315); "just optimize inference whether in cpu or gpu whatever makes most sense" (R139).

**Where the body refers to it.** Statement 8.4.5.
