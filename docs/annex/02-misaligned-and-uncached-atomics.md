## {{#annex-misaligned-atomics}} A precise fault on a misaligned or uncached atomic: no split lock

**The decision.** An atomic instruction on a word that is not aligned to its size, or on memory that is not ordinary cached memory, does nothing except raise a precise fault.

**The problem.** An **atomic** is an instruction that reads a word, changes it and writes it back as one indivisible step, so that two cores adding one to the same counter always end at plus two. A **cache line** is the block of memory (64 bytes on most machines) that a core's cache holds as one unit, and an atomic is cheap when its word lies inside one line, because the core can keep that line to itself for the length of the step. If the word is **misaligned** (a 4-byte word at an address ending in 1, say) it can straddle two lines, and the core can no longer keep both. On x86 the instruction still works: the processor locks the **whole memory bus** for the duration. Intel's own kernel patch series (Fenghua Yu, 21 November 2019, `[PATCH v10 0/6]` on lore.kernel.org) says such an access "takes over 1000 extra cycles compared to an atomic access within one cache line", degrades "the whole system because during split lock the instruction holds bus lock and prohibits any other memory access on the bus", and that "some real time environments cannot meet deadlines if the processor is handling split locks". It is an unprivileged denial of service: any program, in any virtual machine, can stop every other core.

The fix on x86 was a detection feature that raises an exception on a split lock. Peter Zijlstra's review of the same series (21 and 22 November 2019) records what followed: the feature "cannot be virtualized", the firmware was never exposed to it, and the processor's scope for the control register "was found 58 days ago" after version 1, "so that is ~485 days wasted because we didn't know how the hardware actually worked". His measurement on his own desktop was "a grant total of, _ZERO_ split lock usage" (the words as he typed them): "sane architectures have never allowed unaligned atomics in the first place, this means that sane software won't have any".

The second half is the uncached case. A page can be marked as not cacheable (a frame buffer, a buffer a device writes) or as a device's registers. An atomic there cannot be done by the core alone; it would have to be done by the device or the bus, and if the machine does it as a read followed by a write, another agent can slip in between. Linus Torvalds said of emulating an unaligned load-locked on the Alpha that it "is not truly atomic wrt concurrent aligned non-trapping operations" and "If the kernel does an unaligned ld_l/st_c, that's a fundamental kernel bug. Don't emulate it." (lore.kernel.org, 19 February 2025).

### Before and after

**Before** (x86-64; the C is `__atomic_fetch_add` on a member of a packed structure, assembled here with gcc):

```
        movl    $1, %eax
        lock addl %eax, 1(%rdi)     # a 4-byte atomic at an odd address: accepted
```

*(Two instructions. The CPU accepts it, and on some parts locks the bus. The same C on RISC-V and Arm is compiled by clang into a call of a library routine, `__atomic_compare_exchange`, which is not atomic hardware at all.)*

**After** (pdp64, `snippets/split-lock.S`, run on `sim64 -K`):

```
        lea     buf+2, r3               ; a 4-byte word at an address that is 2 mod 4
        movq    #1, r2
        aadd    r2, (r3).32, r1         ; never runs half: the misalignment fault
...
hmis:   mfsr    r5, eva                 ; the address that was refused
```

*(`aadd` with the mark `.32` is a four-byte atomic. The program ends in the handler with `EVA` holding the refused address and nothing in memory touched.)*

### What it enables

* **A fixed worst case for every atomic.** An atomic is one access to one word in one cache line, so the real-time analysis of a lock, a counter or a queue never contains "unless it splits".
* **A trap that is a bug report.** The fault says: this program has a misaligned lock word. It is found the first time it runs, on any core, in any guest, instead of in a field failure.
* **Atomics that need no emulation.** The kernel never has to emulate an atomic that a core refused.
* **A lock word anywhere in ordinary memory**: a spin lock (`CAS` to take it, an ordinary store to release it) works unchanged in a kernel, a user program or a guest.

### What it saves us from

* The **x86 split lock** above: a bus lock held by user code, with a detection feature that could not be virtualized.
* The **unaligned load-locked** emulation of Alpha, which Torvalds calls "a fundamental kernel bug".
* **Half an atomic on device memory.** A read of a device register can have a side effect (reading a status word clears it); an atomic that read it and then wrote it would do both halves with a stranger in between. A refusal, with nothing changed, is the only safe answer.

### What it costs

One check at the memory-type lookup that the translation already does, and a comparison of the low address bits against the size. I counted no gates for it beyond that.

### What it puts off limits

A packed structure cannot hold a word that an atomic touches; the compiler aligns it or the programmer pads it. An atomic on a frame buffer, a DMA buffer or a device's registers cannot be written; a lock word lives in ordinary memory.

### Where the manual states it

{{r:atomic-word-must-be-naturally}} and {{r:atomic-memory-must-be-ordinary}}.
