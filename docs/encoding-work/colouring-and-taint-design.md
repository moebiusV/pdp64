# Colouring, use after free, double free and taint: the design, with measurements

[← encoding work](README.md) · errata 239, R561 · measurements in `bench/colouring/` (read the first lines of each file; results in `bench/colouring/results/`)

Written 2026-11-27. Nothing in the grammar, the executor, the assembler, the tests or the manual is changed. This is a recommendation and a set of measurements for you to judge. Every number is labelled **measured** (I ran it here), **counted** (a count over repository text or sources), **assumed** (my model, no hardware), or **unverified**. There is no pdp64 core, no pdp64 `malloc` and no cache model in `sim64`; what I built is a model and I say so each time.

## What I recommend

1. **One hardware, two allocator policies.** The memory carries 4 bits per 16-byte granule; the pointer carries the same 4 bits in bits 63 to 60; a load or store faults if they differ. Colour 0 means "uncoloured memory", colour 15 means "freed" and faults on every access made with an ordinary pointer. This is the colouring you approved, with the freed colour; the uninitialised colour, the valid-pointer tag and the size class stay dropped.
2. **The allocator, not a lottery, chooses the colours.** In a slab (OpenBSD's `malloc` is slab based: I read it) slot *i* gets colour *parity(i)* plus a per-slot generation: neighbours differ by construction, a reused slot differs from its last occupant for six reuses, a freed slot is colour 15. This closes overflow into a neighbouring slot, use after free and double free **precisely** (no random draw) except for what is listed under "what stays a lottery". Large objects (over 2,048 bytes) take no colours: they are whole pages with a guard page, unmapped on free.
3. **Cost: 3.125 percent of memory (counted), no red zones, no quarantine required, about 1 to 3 percent of run time** without stack colouring (assumed from measured counts; the upper bound I can defend is 8 percent), and 1 to 6 percent more if the compiler also colours stack objects (assumed). This is far inside the 40 percent you would accept.
4. **Your "one bit is enough" is true for the two bugs you named, at a different price.** One poison bit per granule (0.78 percent of memory) with no bits in the pointer catches double free and use after free **while the memory is free**, and with a poisoned granule between objects a linear overflow. To close use after free **after the memory is reused** it needs the allocator never to reuse a slot while its page is live and never to reuse a drained page's address: measured, **+4 percent memory median (up to +22 percent, 2.5 times on one tiny program) and +6.5 percent for the red zones**, and address space that is spent (see section 4). If you would rather leave the canonical-address rule and the pointer untouched, this is the design to take, and the 4-bit hardware runs it as a special case.
5. **Taint (J.9.1): drop the per-word lane; keep the page-level `SEC` class** that is already decided. The word lane would add 0.78 to 1.56 percent of memory to the same side band and heals nothing a secret stack and secret heap pages do not heal. Details in section 6.

*What you must decide* (full list at the end): four pointer bits (the 4-bit design) against none (the 1-bit design, +11 percent memory median); whether the compiler colours stack objects; whether the allocator is allowed to burn address space; whether the word lane of taint is wanted.

## The answer in plain words

* **Use after free** is closed in two steps. While the memory is free its colour is 15, so every access through the old pointer faults, always. After the memory is reused the old pointer carries the old colour and the new object a new one. If the allocator picks the new colour *different from the old one* the fault is certain for the next reuse; a rotation of six generations keeps it certain through six reuses. Measured, **94 percent of slot reuses (median over 18 programs) are the first to sixth reuse of that slot, and 99.75 percent are within thirteen**. A stale pointer more than six reuses old is the lottery that remains (one in twelve).
* **Double free** faults when `free` touches the chunk through the stale pointer (the chunk is colour 15, the pointer is colour *c*), or when `free` reads the colour (`LDCOL`) and compares. Both work while the chunk is free; after reuse the stale colour differs from the new one for six reuses. So **yes in every design that has a freed state, and in all five designs below while the chunk is free**.
* **Overflow into the next object** is certain if the neighbour has a different colour. A slab makes that true by construction (parity of the slot number); a general allocator makes it true by looking at both neighbours and choosing a third colour (14 colours, at most 3 excluded: it always succeeds). With only two colours it fails when the gap sits between an A and a B (shown below); a poisoned granule between objects fixes that.
* **What no colouring catches:** an overflow inside the last 16-byte granule of an object (slack), a read that does not leave the granule, a forged pointer whose guessed colour is right.

## 1. Where the colour travels

### (a) Four bits in the pointer's high bits (my choice)

*What the machine does.* Today every address must repeat its top translated bit in all the bits above it (manual `addresses-are-canonical-39-48`, kernel pseudo-code `fault NONCANONICAL`). The minimal rule change: **bits 63 to 60 are the colour field; bits 59 down to the top translated bit must still equal it; translation reads only the bits below the top translated bit and so never sees the field.** At every width (39, 48 or 57 bits) the field fits: at 57 bits the top translated bit is 56 and bits 59 to 57 still repeat it. Arm does the same job with top-byte-ignore (bits 63 to 56 ignored, the tag in 59 to 56); I put the field at 63 to 60 because the half-select here is the top translated bit, not bit 63 (precedent for Arm: read earlier in `retire-stage-candidates.md`, item 1, from the Linux documentation; not re-read).

*The property that software cannot hide data in pointers* survives, except in these four bits: the canonical comparator still refuses a non-canonical bit 59 and below, and only the colour check reads bits 63 to 60. **Gate count (measured, `colour.v`, the repository's flow, NAND2): the canonical check is 101 before and 77 after** (the four bits are not compared), the 4-bit colour comparator with the freed rule is **24 a port**, 8 bits are 54, 2 bits are 9, the 1-bit poison check of one granule is 2 and of five granules (an unaligned 64-byte access) is 10. A behavioural model: no timing, no wiring, no arrays.

*What happens to a pointer with a non-zero colour:*

| use | result |
|---|---|
| load, store, atomic, block operation | colour checked against the granule(s) touched; a block operation checks each granule it touches |
| equality `p == q` | compares the whole word, so two pointers to the same address with different colours differ. Pointers to one object share its colour. This is a feature (a recycled address compares unequal to the stale pointer). 4,233 equality compares in the 225 OpenBSD files (counted) |
| relational `p < q` | compares the whole word; wrong across objects of different colours. The compiler emits a 60-bit compare for pointers: one extra `EXTR`-class instruction or a `cmp` form that ignores the field; 178 relational compares in 307,826 unoptimised IR instructions, 0.058 percent (counted). The comparator itself is *smaller* on 60 bits (432 against 458 NAND2, measured) |
| `p - q` | same object: exact. Different colours: the difference carries the colour difference in its top nibble; C makes that undefined already |
| array index, `p + i` | unchanged; a carry from bit 59 into the field needs the pointer to be at the very top of the address space, already an error |
| `long`, `uintptr_t` round trip | **colour kept**, because the field is inside the 64 bits. Code that masks a pointer (`& 0xFFFFFFFF`, NaN-boxing that assumes bits 63 to 48 are zero, a hash) loses or sees the colour. 333 pointer-integer casts in the 225 files (322 `ptrtoint`, 11 `inttoptr`, counted, a proxy); I did not scan Debian |
| kernel: `copyin` and `copyout` | the user-qualified move uses the user's pointer with its colour: the kernel faults exactly where the user would; the kernel can return EFAULT for a freed buffer |
| kernel: explicit range tests | `uaddr < VM_MAXUSER_ADDRESS` fails for a coloured pointer unless the colour is stripped first: 19 uses in `kern` and `uvm` (counted, `openbsd-src/sys`), and the address-taking system calls (`mmap`, `munmap`, `mprotect`, `madvise`, `mlock`, `minherit`, `msync`, `mquery`: counted by name) strip it. `PROBER` and `PROBEW` check the colour like an access |
| `setjmp`/`longjmp`, signals | the registers keep their 64 bits, colour included. A `longjmp` that leaves frames whose objects were coloured must clear those colours (one block operation on the abandoned stack range: one instruction). A signal frame saves the pointer with its colour; the fault syndrome gives the pointer colour and the memory colour (precise exception, no hidden state) |
| one binary | nothing differs across implementations; the tag memory is architectural |

*What it heals:* every cell of section 4. *What we lose:* the field in the pointer, the strip in a handful of kernel places, and the discipline that C code does not mask pointers.

### (b) The colour held outside the pointer: rejected

* *A register-side field* (a colour per base register, set by `LDCOL`): lost whenever a pointer is spilled or stored; to keep it the colour must be stored beside the pointer. That is a 16-byte pointer, which the capability note measured at **4 to 38 percent more data memory** (measured, resident data of five programs) for 4 bits of information.
* *A colour per page in the page table:* free of pointer bits, but a page of 16-byte objects holds hundreds of them; coarse colouring cannot tell neighbours apart. It does suit large objects (section 3).

### (c) Two options of my own

* **The colour in the low four bits of an aligned pointer:** objects are 16-byte aligned, so those bits are zero. But a pointer to byte 3 of an object needs them; rejected.
* **No colour in the pointer at all: the 1-bit poison** (design 2 below). The check is on the granule touched, so no pointer bit is needed and the canonical rule is untouched. This is the one real alternative and it is costed in section 4.

## 2. The side table

### Where the 4-bit colours live

| place | memory cost (counted) | traffic | verdict |
|---|---|---|---|
| a side band in every cache line and in DRAM (ECC-style, as MTE does on Arm hardware that has it) | 3.125 percent of RAM in extra DRAM width (a board with spare ECC bits); 16 bits in each 64-byte cache line | none extra | best if the board has the bits; **unverified** for the target boards |
| a **carve-out region of RAM** at 1/32 of the data, with the tag bits carried in the cache lines and a **tag cache** behind the last-level cache | 3.125 percent of RAM; 128 MB for 4 GB | measured below: 2.4 to 4.3 percent more DRAM bytes, streaming programs | **my choice**; works on any board |
| in the page table, per page | 0 extra bytes (a 4-bit field per PTE: no room, see below) | none | too coarse for small objects |

*PTE room:* the entry uses bits 0 to 9 and the physical page number from bit 12 to 51; every other bit must be zero (manual `page-table-entry-is-64`). **One new bit, bit 10, "coloured" (C),** fits and is enough: a page with C clear is uncoloured memory (every granule colour 0, a pointer of colour 0 passes; no tag lookup at all). It also lets stack, globals and DMA buffers be left alone.

*The hardware that gets the colour:* the tag bits ride in the data cache lines (16 bits a 64-byte line, 3.1 percent more cache SRAM, **assumed** line size 64: the manual says the line size is open, J.7.2). A line fill from a coloured page reads its 16 bits from the **tag cache**; a tag-cache line is 32 bytes and covers 1 KB of data.

### Interaction with the memory system

* **Coherence, sequential consistency.** The colours of a line are part of the line. A colour write is a write: it needs the line in the modified state (an invalidate if the line is shared), so a core that next reads or writes that granule sees the new colour, and a colour write is ordered with data stores in the store buffer like any store. A colour write that went straight to the tag cache while another core held the line shared would break sequential consistency; the rule is: **a colour write first takes ownership of the line**. Cost: one invalidate per 64-byte line coloured when the line is shared; none otherwise (counted by lines below). The three-state snooping protocol of the manual needs no new state.
* **Atomics.** The 4-bit write is a masked write inside the owned line; atomic by ownership.
* **DMA and the IOMMU.** A device carries no colour: it writes data, never colour. The tag region must be unreachable by every mapping, as the arena is: **the walker and the IOMMU refuse it, and the tag memory is not in the address map a device sees**. DMA buffers are uncached and in uncoloured pages (C clear), so the hand-off of the manual is unchanged; if a coloured page is mapped uncached, every access consults the tag cache at the memory controller (the "per-access" rows below: 99.7 percent hit). A device can still overwrite any granule its IOMMU mapping allows; colouring does not close that, the IOMMU does.
* **Hypervisor, stage 2.** Colours belong to the host physical granule, so stage 2 needs no change except that the final C bit is the guest's and the hypervisor's together. Moving, paging out, snapshotting or migrating a page must save and restore its tags (128 bytes for a 4 KB page, counted): two privileged block operations (read the tags of a page, write them). **Handing a page to another guest must clear its tags**, or the colour pattern of the old owner's objects leaks (an information bleed, to get a test).
* **Reset of memory.** `MSET` writes data, not colour; the zero-a-page path of a kernel clears tags too (one block operation).

### Measured: the traffic and the tag-cache hit rate (`bench/colouring/memsim.c`)

*What this is.* A model, driven by the real load and store addresses of programs of this repository: `as64` (assembling a 446 KB and a 1.2 MB source of the build tree), compiled by `clang -fsanitize=thread -c` so that every memory access of the program calls my hook (no valgrind is installed; the tsan instrumentation gives an exact address stream of the program's own non-register accesses, not of libc internals). Host x86-64, LP64, glibc `malloc` (interposed so that the allocator's colour writes are counted). Two data caches modelled at once (256 KB and 1 MB, 8-way, 64-byte lines, one unified level, so L1 hits are not removed and the miss counts are for a unified cache of that size); a tag cache of 4 to 64 KB, 4-way, 32-byte lines each covering 1 KB. **Not a pdp64 run. The pdp64 programs of the repository are too small to use** (the `sim64` test programs make about 11,000 accesses and have no heap).

| run | accesses | heap share | LLC 256 KB miss rate | tag cache 4 KB | 8 KB | 16 KB | 32 KB | 64 KB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `as64` small input, heap only coloured: extra DRAM bytes over data bytes | 70.8 M | 33% | 1.87% | **3.16%** | 3.12% | 3.08% | 3.04% | 2.92% |
| same, everything coloured (heap, stack, globals) | | | | 4.26% | 4.23% | 4.20% | 4.14% | 4.05% |
| `as64` large input, heap only | 1,004.6 M | 46% | 1.02% | | | | 2.38% | 2.35% |
| same, everything coloured | | | | | | | 3.37% | 3.35% |
| tag cache consulted on **every** coloured access (no tag bits in the data caches): hit rate, heap only | 23.4 M lookups | | | 99.66% | 99.66% | 99.66% | 99.66% | 99.66% |

*Reading it.* The extra traffic is about the memory cost itself (3.125 percent) because these programs stream through memory: each fresh kilobyte of data brings one tag line. The hit rate does not change with size from 4 to 64 KB for the same reason: a program that walks memory in order needs a tag line only for a moment. **This is the friendly case.** The unfriendly case is arithmetic, not measurement: a program that follows pointers at random through a heap larger than the tag cache's reach (a 64 KB tag cache reaches 2 MB of data) misses the tag cache on nearly every data miss and reads 32 tag bytes for each 64 data bytes: **up to +50 percent DRAM traffic on such a miss stream (counted by arithmetic, not measured)**. That is why I would give the tag cache a larger reach than 64 KB if the first core has the area, and why the side band in the data path (first row of the table) is better where the board allows it.

*Extra cycles (assumed, my model).* The check is a comparator on the access path: **0 extra instructions**. A load or store that hits the data cache already holds the colour: **0 extra cycles**. A data miss whose tag is in the tag cache: **0 extra** (the tag-cache read is issued in parallel with the fill). A data miss whose tag misses: the tag address is computable from the physical address, so the two fetches can overlap: **0 to about 150 extra cycles** (150 is my assumed DRAM latency). Counted from the runs: the tag-cache reads are 0.057 to 0.14 percent of all accesses (573 K of 1,004 M; 100 K of 71.6 M, 32 KB). At 0.3 accesses per instruction and one instruction a cycle (assumed) the worst case, nothing overlapped, is **2.6 to 6.3 percent**; overlapped it is near zero.

## 3. Allocator work and the stack

### Heap, measured (`bench/colouring/alloc.py`, over the 18 malloc traces of `bench/sizeclass`; host glibc, the first 3 M records of each; not an OpenBSD run)

| quantity | median over 18 programs | range |
|---|---:|---:|
| granule writes in allocations of a page or more (a guard page and no colours would remove them) | **86%** of all colour-write granules | 0.4% to 100% |
| allocations whose size is not a multiple of 16 | **72.6%** | 3% to 99% |
| mean slack in the last granule, per allocation | 5.75 bytes | 0.2 to 10.7 |
| slack as a share of requested bytes (the overflow or over-read that colouring cannot see) | **0.69%** | 0% to 12.6% |
| allocations that have a live neighbour within 32 bytes (the rule "colour different from both neighbours" matters) | **94.7%** | 64% to 100% |
| allocations that land on an address freed before | 47% | 1.5% to 99% |

*Colour writes:* `as64` large input: 254 K mallocs, **13.2 M granule writes, 3.48 M 64-byte lines, 254 K block operations** in 0.83 s of native run (host). With one block operation per allocation and one cycle a line (assumed) that is 3.5 M cycles in about 2.5 G: **0.14 percent**. With one instruction per granule it is 13.2 M instructions against 992 M memory accesses, 1.3 percent. I propose the block operation.

*The colour-aware malloc, in plain words (assumed instruction counts).* In a slab: the slot number is known; the colour is `(generation << 1) | (slot & 1)`; the generation is kept in the first word of the freed slot (the allocator reaches freed memory with a colour-15 pointer); `malloc` reads it, increments it (1 to 6), sets the colours of the slot with one `MCOL`, returns the pointer with the colour inserted: about **5 instructions more than today**. `free` reads the colour (`LDCOL`), compares it with the pointer's, faults or aborts if different (this is the double-free check), stores the generation, sets colour 15 with `MCOL`: about **5 instructions**. In a general allocator (no slabs): `LDCOL` both neighbours, choose a colour from 1 to 14 different from both and from the old colour: about 8 instructions.

*Two colours can fail:* with colours A and B only, a gap between a live A and a live B has no free choice (the new object must differ from both). A poisoned granule between objects (design 3 below) removes the case; so does a slab, where slot parity fixes the alternation.

### The stack

*Counted* (`bench/sizeclass/sizeir.py`, 225 OpenBSD files, LLVM IR at -O2): 2,576 escaping stack objects of known size in 806 of 2,151 functions (**37 percent of functions**; 3.2 objects each); 391 functions (18 percent) hold one over 16 bytes. *Measured, a different proxy* (`as64` under the tsan hook, calls that touched any stack-resident object): **64 to 72 percent of calls**; this includes arrays and structs that are not address-taken, so it is an upper bound on frames that must be coloured.

*Cost per call (assumed sequences):* one colour for a whole frame, set at entry and cleared at exit: 2 instructions on 37 percent of calls = **0.74 instructions a call** (1.3 to 1.4 at the 64 to 72 percent proxy). One colour per object: 2 per object, 3.2 objects per affected function = **2.4 a call** (4.1 to 4.6 at the proxy). `as64` makes 59 M calls in 0.83 s (measured counts; 72 M calls a second) and, at an assumed 40 to 80 instructions a call, the per-frame form costs **about 1 to 2 percent and the per-object form 3 to 6 percent** on this call-dense program. Per-frame colour does not see an overflow between two objects of one frame; per-object does. I would make stack colouring a compiler option, off by default, as LLVM does for MTE's stack mode (the option name `-fsanitize=memtag-stack` is from my memory, **unverified**).

## 4. Use after free, double free and overflow: how strongly, and at what price

You asked for these to be closed precisely and for what each strengthening costs. Five designs, then what each buys. All measured numbers are from the traces; the slab model `bench/colouring/slab.py` replays the requests of the 18 traces through a model of OpenBSD's `malloc` (read, `lib/libc/stdlib/malloc.c`: chunks of multiples of 16 bytes up to `MALLOC_MAXCHUNK`, half a page, one page per bucket with the free bitmap kept in a separate `struct chunk_info`, a random free slot of the first page with room, a delay of 16 random slots before reuse, `chunk_canaries` for pad bytes, `malloc_freeunmap` available to protect freed pages). It is a model; the real `malloc` is not run.

### The five designs

| | 1. 4-bit random colour (the lottery) | 2. **1 bit** poison per granule | 3. 2 bits: colour A, colour B, poisoned | 4. 1-bit poison **plus** address retirement | 5. **slot parity** + freed state (+ generation, 4-bit hardware) |
|---|---|---|---|---|---|
| bits in memory per granule | 4 (3.125%) | 1 (0.78%) | 2 (1.56%) | 1 (0.78%) | 4 (3.125%) or 2 without generation |
| bits in the pointer | 4 | **0** | 1 | **0** | 4 (or 1) |
| red zone | none | 16 bytes between objects (see below) | none in a slab; one poisoned granule where A and B meet | 16 bytes | none (parity separates neighbours) |
| **overflow into the neighbour** | by chance: 13 in 14 (the allocator avoids the two neighbours, so certain when it looks) | **certain** if it crosses the red zone linearly; **missed** if the index skips the red zone | certain in a slab; certain elsewhere only with the poisoned granule | as 2 | **certain** into the adjacent slot; a skip of two slots matches parity and is caught only by the generation, by chance (about 5 in 6) |
| **use after free, while free** | certain (colour 15) | certain | certain | certain | certain |
| **use after reuse** | by chance, 13 in 14 or certain for the next reuse if the allocator avoids the old colour | **missed** (the granule is valid again) | certain for the first reuse; the stale pointer from two reuses back matches | **certain** if no slot of a live page and no drained page's address is ever reused: measured below | certain for six reuses, then 1 in 12 |
| **double free** | caught while free; after reuse 13 in 14 | caught while free (the second `free` touches a poisoned granule); after reuse missed | as 1 with certainty for the first reuse | **caught**, always (the poison stays; the address is never reused) | caught while free; after reuse certain for six reuses |
| forged pointer from a neighbour's address | chance | missed | chance | missed | chance |
| inside the last granule | missed | missed | missed | missed | missed |

### What each strengthening costs (measured on the traces, the slab model)

| strengthening | memory | time and other cost |
|---|---|---|
| the 4-bit side band (designs 1 and 5) | 3.125% of RAM (counted) | section 2: 2.4 to 4.3% more DRAM bytes (measured, streaming) |
| the 8-bit colour field (255 in 256) | **6.25%** of RAM (counted) | comparator 54 NAND2 against 24 (measured); the field needs 8 pointer bits, but at 57-bit addresses only bits 63 to 57 (7 bits) lie above the top translated bit (56), so 8 bits do not fit at every width. I do not recommend it |
| the 1-bit side band (designs 2 and 4) | 0.78% (counted) | comparator 2 NAND2 |
| red zone, one 16-byte granule between slab chunks | **median +6.5% footprint** over the model baseline, 75th percentile +16%, maximum +30% (measured, `slab.py`) | none |
| a quarantine of freed bytes equal to 10% of live bytes | **median +7% (maximum +10%)** at the peak (measured, `alloc.py`, FIFO of frees) | delays reuse; the window it makes is not a time but a volume |
| the same at 25% of live bytes | median +9% (maximum +25%) | |
| the same at 100% of live bytes | median **+38%** (maximum +100%) | |
| a count-based quarantine of 256 frees | median +19% of the model's footprint, 75th percentile +53%, **maximum 4 times** (tiny programs) | do not use a count |
| **one-time slots**: a freed chunk's slot is not reused while its slab page holds a live chunk; the page's address is retired when the page drains | **median +4% footprint, 75th percentile +8%, maximum +22%; five of 18 programs 1.4 to 2.5 times** (`sed` 2.5, `grep` 1.7, `ls` 1.8, `make` 1.6, `tar` 2.0: small, allocation-heavy programs) | the address and unmap costs below |
| generation colours (design 5) | none beyond the 4 bits: the generation is the colour | 5 instructions at `malloc`, 5 at `free` (assumed) |

*The stale-colour repeat, measured:* of the slot reuses in the slab model, **46 percent (median) are the first reuse of the slot, 94 percent are within six, 99.75 percent within thirteen**; so a design with two colours is wrong on the second and later reuses (54 percent of reuses, median) for a stale pointer from two generations back, while a six-generation colour is wrong on 6 percent of reuses (median) and then only for a pointer more than six reuses old.

### Address retirement (design 4) in numbers

*How the freed memory is reused in the slab model* (measured, median over 18 programs): of freed small chunks, **74 percent have their slot reused while the page still holds a live chunk, 8 percent have their page drained first, 11 percent are still free at the end of the trace** (range of the first number 1 to 99.6 percent). **So retiring a drained page's address alone closes only a minority of small objects: this is the small-object problem.** It is the reason design 4 includes the one-time slots in the table above. Large objects (over 2,048 bytes) are always whole pages and are unmapped on free.

*Address space spent* (measured in the slab model with one-time slots; the traces have no clock, so the rates divide by the native run time of the same program that I measured separately; both host figures, and short bursts):

| program | retired address | unmaps | native run | rate |
|---|---:|---:|---:|---|
| `git log` (3 M records) | 3,180 MB | 204 K | 2.56 s | 1.2 GB/s, 80 K unmaps/s |
| `find` | 650 MB | 99.8 K | 1.26 s | 0.5 GB/s, 79 K/s |
| `sed` | 303 MB | 74 K | 0.078 s | 3.9 GB/s, 950 K/s |
| `gawk` (awk) | 10.9 MB | 1.9 K | 0.39 s | 28 MB/s, 4.8 K/s |
| `sort` | 2,071 MB | 24 | 0.34 s | 6.2 GB/s (a few huge arrays) |

*Time until the space wraps* (counted, at 1.2 GB/s, the middle row): the 39-bit space (512 GB) in **7 minutes**, the 48-bit space (256 TB) in **2.5 days**, the 57-bit space (128 PB) in **3.4 years**. A long-running program does not sustain a burst rate, but the 39-bit form cannot hold this design and the 48-bit form is a guarantee of days. When the space wraps the allocator must start reusing the oldest retired addresses, and a stale pointer older than a whole wrap is again the lottery.

*Page-table and TLB churn:* unmaps 5 K to 950 K a second in the table (host); each is a system call and, on a multiprocessor, a broadcast `TLBI`. At 2 to 5 microseconds each (assumed) `sed` would spend more time unmapping than it does now computing (950 K a second times 3 microseconds is 2.8 s of work in each second). The allocator must batch: retire addresses by a run of 64 or more pages in one `munmap`, keeping the poisoned pages mapped no-access in between (assumed; 64 divides the rates by 64: 15 K a second for `sed`).

*Precedent for this idea, and what I could and could not verify.* The idea of never handing out the same address twice, so that a stale pointer faults in translation and no colour is needed, is called **one-time allocation** in the literature. I searched on 2026-11-27 and read only the search summaries, not the papers: **FFmalloc** (Wickman et al., USENIX Security 2021, "Preventing Use-After-Free Attacks with Fast Forward Allocation", [usenix.org](https://www.usenix.org/conference/usenixsecurity21/presentation/wickman)) is summarised there as a one-time allocator that returns each virtual address once and reports blocking all tested use-after-free attacks at moderate overhead, with speed, memory and fragmentation named as the challenges; **Oscar** (Dang, Maniatis, Wagner, USENIX Security 2017, [usenix.org](https://www.usenix.org/conference/usenixsecurity17/technical-sessions/presentation/dang)) gives each object its own virtual alias page and makes it inaccessible on free; a later dissertation by Dang is summarised as moving to several objects per page with a quarantine for freed objects on pages that still have live neighbours. **I reached my slab-level form (one-time slots, poison, retire the drained page) by my own reasoning before searching; I have not verified that the papers' mechanisms or numbers are what I describe, nor their overhead figures, and I quote none.** `malloc_freeunmap` in OpenBSD's `malloc.c` (read) already protects or unmaps freed pages, which is a coarse form of the same idea.

### The guard word

A poisoned or colour-15 granule between objects costs **16 bytes an object**. In the slab model it is **+6.5 percent footprint, median** (75th percentile +16 percent, maximum +30 percent; table above). With parity colouring it is not needed for neighbours (they differ by construction), so design 5 spends nothing on it. A guard word is needed for design 2, for design 3 where A meets B, and between large objects (a guard page is the same thing at page size: 4 KB, cheap because large objects are whole pages anyway).

### Slot-parity colouring (design 5): exactly what it cannot do

* **Reuse of the same slot has the same parity,** so the stale pointer matches unless the freed state, the generation or retirement closes it. With the freed state alone (colour 15) it is closed *until reuse*; with the generation, for six reuses. In the slab model **74 percent of freed small chunks (median) are reused in a live page**, so reuse is the normal case, not the exception: the generation is what makes the design worth having.
* **A skipped slot:** an index that jumps two slots lands on the same parity. Caught by the generation by chance only.
* **Allocators that are not slab based:** a glibc-style allocator (boundary tags, best fit) has no slot index; there the neighbour search of section 3 does the job, with 14 colours always possible. 94.7 percent of its allocations have a live neighbour in range (measured), so the search runs almost every time.
* **Objects larger than a slab class** (over 2,048 bytes): whole pages, guard page, unmapped on free; no colour; use after free is a translation fault always.
* **Packing three states in fewer bits:** parity colours A and B plus freed make three states. Two bits hold it with a spare. Packing five granules into 8 bits (3 to the power 5 is 243, 1.6 bits a granule) saves 0.31 percentage points of memory (1.56 to 1.25 percent, counted) and costs a divider or a 256-entry table in the tag path and a read-modify-write of the byte for every single-granule colour write. **Not worth it.**
* **Interaction with double free,** each design: see the table (row "double free").

## 5. The freed colour and the uninitialised colour

* **How `free` colours the object.** `free(p)` reads the colour of the first granule (`LDCOL`); if it differs from the pointer's colour it is a double free or a wild pointer and the allocator aborts; then one `MCOL` sets the whole chunk to 15 and the generation is kept in the chunk's first word, reached through a colour-15 pointer that only the allocator builds. A second `free(p)` hits colour 15 either at the `LDCOL` compare or at its first store.
* **Is quarantine needed?** Not for correctness if the generation colour is used: a reused slot has a new colour. Quarantine adds to the window in which the colour is 15 (certain fault for any stale pointer, whatever its age); its cost is the table above (+7 percent at 10 percent of live bytes, median). I would offer it as a policy (an environment option), not require it.
* **What remains for the allocator:** slot parity and generation (slab), neighbour search (non-slab), the guard page for large objects, the generation word, the double-free check, and the strip of the colour in the pointer returned to code that masks pointers.
* **The uninitialised colour stays dropped.** A program that wants uninitialised reads caught uses what it has now: OpenBSD `malloc` fills fresh chunks with junk (`junk_free`, `validate_junk`, read), `calloc` for data it must have zero, and the compiler's `-ftrivial-auto-var-init` for the stack (a compiler option; I did not check that the pcc has it, **unverified**).

## 6. Taint bits (J.9.1)

*What the open item has, read now.* A secret lane is decided: a bit per register (`SMASK`), set by `SECRET` or a load from a `SEC` page, propagated by OR, cleared only by `DECLASSIFY`; stage 1 faults a store of a secret register to a page that is not `SEC`; stage 2 would be a bit per 8-byte word of memory. An *integrity* taint (Perl's kind, injection) does not exist, and J.9.1 leans to option 1 (no hardware, a compiler shadow scheme at 2 to 4 times slowdown; **an estimate from general knowledge in that item, unverified**).

*The property a word lane would give, exactly:* **a secret-tagged value cannot be written to a place whose tag says non-secret, and a secret word cannot be read into an unmarked register or sent to a device**, wherever the word lives, not only on `SEC` pages. *What stage 1 already gives:* the same, for pages marked `SEC`, with no side band at all. The difference is a secret that lives on an ordinary stack frame or in an ordinary heap chunk. With a secret stack and a secret heap (the compiler spills secret values to a `SEC` stack; `malloc_secret` returns `SEC` pages) stage 1 is as precise: a copy to a non-`SEC` page faults.

*What the word lane costs:* **0.78 percent (a bit per 16 bytes) or 1.56 percent (a bit per 8 bytes) of memory (counted)**, in the same tag path. If it shares the colour side band it adds no second lookup and no second tag cache: with a 4-bit colour per 16 bytes and one taint bit per 8 bytes the side band is 6 bits per 16 bytes, **4.69 percent in all** (3.91 percent with one taint bit per 16 bytes); the tag cache line holds 48 bytes for 1 KB instead of 32, so the extra DRAM traffic of section 2 grows by about half (2.4 to 4.3 percent becomes about 3.6 to 6.5 percent; counted, not measured). **Every store writes the lane** (taint of the register, usually 0), so a store to a word whose tag is set clears it: no extra access when the line is cached (the lane rides in the line), a tag fetch when not. Device writes and `MSET` must clear it. A 65th lane bit joins every saved context (the secret lane in registers is decided, so that part is paid).

*Setting and clearing:* `SECRET` and `DECLASSIFY` exist for registers; memory lane bits are set by a store of a secret register and cleared by a store of a non-secret one; `MCPY` propagates; no new instruction.

**Recommendation on the word lane: DROP now (and measure only if a program needs it).** What it heals beyond stage 1 is the convenience of leaving secrets on an ordinary stack; its price is a new side band beside the colours, a store that always writes a tag bit, and a clearing duty for every device and block operation, for a property the `SEC` page class already gives for the places where secrets belong. **Integrity taint: DROP in hardware** (J.9.1 option 1 stands); it needs a policy at sinks that the kernel and compiler must agree on and has the false-alarm problem the item names.

## 7. The recommendation in full

**Layout.**

| | |
|---|---|
| where the colour travels | pointer bits 63 to 60; the canonical rule becomes "bits 59 to the top translated bit repeat it"; translation ignores the field |
| memory colour | 4 bits per 16-byte granule; 0 uncoloured, 15 freed; allocatable 1 to 14 (generation 1 to 6 in bits 3 to 1, slot parity in bit 0; values 2 to 13) |
| where it lives | tag bits in each data cache line (16 bits per 64-byte line, assumed); a tag region of 1/32 of RAM as a hardware carve-out behind a **tag cache of 32 KB, 4-way, 32-byte lines** (assumed; the streaming programs I measured do not distinguish 4 from 64 KB, the random case wants reach) |
| page attribute | one new PTE bit (bit 10, "coloured"); stage 2 ANDs it |
| tag memory protection | not mappable by any translation or device; the walker and the IOMMU refuse it |
| total memory | **3.125 percent** (counted), no red zones, no quarantine; 4.69 percent if the word taint lane were added |
| time | allocator colour writes 0.14 to 1.3 percent; tag-cache misses 0 to 6 percent, nearer 0 when overlapped; stack colouring 1 to 6 percent if enabled; **about 1 to 3 percent without the stack, at most about 12 percent with every worst case together (all assumed from the measured counts)**. The pointer compare mask and the strip in the kernel cost instructions in a few thousand places, not a measured amount |

**What stays a lottery or a miss in it** (stated plainly): a stale pointer more than six reuses of the same slot old (1 in 12; about 6 percent of slot reuses are seventh or later, measured); an index that skips a whole slot (by chance); the last-granule slack (median 72.6 percent of allocations have it, mean 5.75 bytes, 0.69 percent of requested bytes, measured) and any over-read inside a granule; a forged pointer that guesses the colour (1 in 12 per try); a device write through the IOMMU; non-slab large objects past their guard page by more than a page.

**The cheaper-hardware alternative.** The 1-bit poison: 0.78 percent of memory, 2 NAND2 a port, **no bits in the pointer and no change to the canonical rule or the ABI**. With red zones (+6.5 percent median), one-time slots (+4 percent median, up to +22 percent and 2.5 times on small programs) and retirement of drained addresses (days of 48-bit space, or years of 57-bit), it closes use after free and double free **for ever until the address space wraps**, which the 4-bit design closes for six reuses. That is **about +11 percent memory (median, counted by adding the measured medians), more address space, a heavier unmap load (batched)** against the 4-bit design's **3.1 percent**. I take the 4-bit design because it is cheaper in memory, catches the neighbour that a red zone does not (skipping), and contains the 1-bit design: an allocator that gives every live object colour 1 and every freed chunk colour 15 *is* a 1-bit poison, so a high-assurance process can ask for the strict policy on the same hardware. If you rank leaving the pointer and ABI untouched above 8 points of memory, take the 1-bit design instead.

**The words (names only; no encoding is allocated; I did not read the free-slot tables).** The existing forms that do part of the work:

* `MFSR`/`MTSR` could carry a privileged "tag region base" and "colour fault syndrome" register; the page attribute is a PTE bit (no word).
* Insert the colour into a pointer and strip it: an assembler alias of the existing field-insert and field-extract (`INSB`, `EXTZB`, `EXTR` exist; I did not check that their field widths reach bit 60: **unverified**), so **no new word** for `COLOUR` (insert) and `STRIPCOL` (extract the low 60 bits, sign-extended).
* New, user level, because the allocator runs at user level: **`LDCOL rd, (ea)`** reads the 4-bit colour of the granule at `ea`; **`MCOL`**, a block operation in the family of `MCPY`, `MMOV` and `MSET` (destination pointer, colour, count of bytes, progress kept in its registers, restartable): sets the colours of every granule in the range, taking ownership of each line first; **`STCOL (ea), rs`** for one granule (an assembler alias of a one-granule `MCOL`, so no word of its own).
* Privileged, for the hypervisor and the page allocator: **`MCOLRD`** and **`MCOLWR`** (read and write the tags of a page to and from memory, 128 bytes for 4 KB) and a clear of the tags of a page (the same `MCOL` with colour 0 on a privileged range). Three or four words in all. Whether they fit the free `R2` patterns I do not know; J.9.1 counted 2 to 4 words in `R2` at 0 patterns for the taint words, which is the nearest evidence **(from that item, unverified here)**.

**A draft of the manual statements** (first person, as the manual will state them):

* **{{#memory-has-a-colour}}** I give every 16-byte granule of coloured memory a 4-bit colour, and I give every pointer into it the same 4 bits in bits 63 to 60. A load or store whose pointer colour differs from the colour of a granule it touches takes a colour fault before it changes anything.
* **{{#colour-0-and-15}}** Colour 0 is uncoloured memory, and a pointer of colour 0 reaches only it. Colour 15 is freed memory: no pointer I give out has colour 15, so every access to it by an ordinary pointer faults.
* **{{#page-is-coloured}}** A page is coloured when its entry has the coloured bit set. The caches carry the colours with each line, and the colours of a line change only when the core holds the line for writing, so the colour of a granule is as coherent and as sequentially consistent as its data.
* **{{#translation-ignores-the-colour}}** Translation ignores bits 63 to 60. The bits from 59 down to the top translated bit must still repeat it, or the address is refused as non-canonical. I put nothing else in a pointer.
* **{{#ldcol-and-mcol}}** `LDCOL` reads a granule's colour. `MCOL` sets the colours of a range of granules, and like the other block operations it keeps its progress in its registers and can stop and restart.
* **{{#colour-fault-is-precise}}** A colour fault is precise. It reports the pointer's colour and the granule's, and the address.
* **{{#devices-carry-no-colour}}** A device carries no colour. It writes data and leaves colours alone, and no mapping of any device or core reaches the memory that holds the colours.
* **{{#moving-a-page-moves-colours}}** A hypervisor or kernel that moves, saves or hands on a page moves its colours with it with `MCOLRD` and `MCOLWR`, and clears them when it gives the page to another owner.

(The manual's own voice for the reasons and the history goes in the annex, not here.)

**What is open, for you to decide**

1. **Four pointer bits (my choice) or none (the 1-bit poison, +11 percent memory median).** This is the value call of this note.
2. **Stack colouring:** on by default, a compiler option (my choice), or never. 1 to 6 percent of time on call-dense code.
3. **Address space:** if the 1-bit design or the strict policy is wanted, the system must accept spending 1.2 GB a second at the burst rates measured, and the 39-bit form cannot hold it.
4. **How many generations:** six with 4 bits (my choice); 8 bits give 255 colours but do not fit above bit 56 at 57-bit addresses.
5. **The word lane of taint:** drop (my choice) or build, at +0.78 to +1.56 percent of memory.
6. **The tag store:** a side band in DRAM (if the board has the bits) or a carve-out (my choice); the first core's tag cache size (reach).
7. **The kernel's strip** at the address-taking system calls and the 19 range tests (counted): accept, as they are about thirty places.
8. **The line size** (J.7.2) is assumed to be 64 bytes throughout; the numbers move with it.

## What I could not measure, and what I assumed

* No pdp64 binary uses `malloc` and the repository's `sim64` programs are about 11,000 accesses: every traffic figure is a **host model** (`as64` instrumented with clang's thread-sanitizer hooks, glibc, x86-64) of two assembler runs; only two programs, both streaming through memory. A pointer-chasing program would show the tag cache's size, and I have only the arithmetic for it (+50 percent worst case).
* The allocation figures are replays of host traces (glibc, the first 2.5 to 3 M records of each, 18 programs, no clock) through a **model** of OpenBSD's `malloc`, not the real one. Run times used for rates are separate native runs of the same programs (short, bursty).
* Cycle costs of the check (0 extra on a hit) and of a tag miss (0 to 150) are my model; there is no cache model in `sim64`. Instruction counts for `malloc`, `free`, `MCOL` and the stack are my sequences, not compiled code.
* The stack fraction is a proxy: 37 percent of functions with an escaping object (static, counted) and 64 to 72 percent of calls touching a stack-resident object (dynamic, a looser proxy).
* The gate counts are behavioural models of the logic only; the tag cache and side band are counted as SRAM (a 32 KB tag cache is 256 Kbit of data plus tags), not gates.
* I read the OpenBSD `malloc.c` (structure, constants, delayed chunks, canaries, `freeunmap`), the manual statements and the open items. I did **not** read Arm's MTE specification or SPARC ADI documentation again for this note, nor the FFmalloc, Oscar or other papers (search summaries only). Not verified: that any board's DRAM has spare bits; the Arm MTE detail beyond what `retire-stage-candidates.md` records; the exact option names of LLVM's stack-tagging.
* I did not measure which fraction of real bugs these designs catch (no bug corpus), and no uninitialised-memory design is judged beyond the one sentence in section 5.

*Files:* `bench/colouring/memsim.c` (the traffic model), `alloc.py` and `results/alloc.txt` (allocator work on the traces), `slab.py` and `results/slab.txt` (the slab model: reuse, red zone, quarantine, one-time slots, retired address), `colour.v`, `gates.sh` and `results/gates.tsv` (gate counts), `results/summary.txt` (the medians quoted).
