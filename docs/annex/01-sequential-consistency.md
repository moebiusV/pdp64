# Part 1. Memory model and atomics

## {{#annex-sequential-consistency}} Sequential consistency: no fences, and no second spelling of the atomics

**The decision.** I keep memory **sequentially consistent**: the result of any run on several cores is as if all their loads and stores happened in one order that respects each program's own order.

**The problem.** On the PDP-11 there was one processor and you never thought about this: a store you made was seen by the next load of any program, because there was only one place the loads could look. With two or more cores, each core wants to hold its stores in a small private queue (a **store buffer**) and let later loads run ahead of them, because that is faster. A core that does so shows the others its stores late and out of order. The machine is then called **weakly ordered**, and every piece of code that hands data from one core to another needs **fences**, instructions that say "finish everything before this, then continue". Forget one and the program works for months and then fails once an hour.

I took the code of OpenBSD's lock-free ring buffers on three machines. Here is the writer storing a message and then a flag, and the reader testing the flag and reading the message.

### Before and after

**Before** (Arm, then RISC-V, then x86-64: the barriers are those of OpenBSD's `membar_producer()` and `membar_consumer()`, `sys/arch/arm64`, `riscv64` and `amd64` `include/atomic.h`; assembled here with clang to count bytes):

```
        str     x1, [x2]        // data
        dmb     st              // fence: the data before the flag
        str     x3, [x4]        // flag
        ldr     x5, [x4]        // reader: flag
        dmb     ld              // fence: the flag before the data
        ldr     x6, [x2]        // reader: data
```

```
        sd      a1, 0(a2)       # RISC-V: fence w,w and fence r,r in the same places
        fence   w,w
        sd      a3, 0(a4)
        ld      a5, 0(a4)
        fence   r,r
        ld      a6, 0(a2)
```

*(Six instructions and 24 bytes on each of Arm and RISC-V, two of the six being fences; on x86-64 the two OpenBSD macros are empty, four instructions and 12 bytes, because x86 keeps stores in order, though not a store before a later load.)*

**After** (pdp64: `snippets/spsc-ring.S`, assembled and run on `sim64`; one core cannot test the order, but the code is the whole of it):

```
        mov    r4, (r1)(r3*8)      ; 1. store the data
        ...
        mov    r3, (r2)            ; 2. publish: store the new tail
        ...
        mov    (r2), r7            ; 1. load the tail
        cbeq    r6, r7, empty
        mov    (r1)(r6*8), r8      ; 2. load the data: it cannot be the old word
```

*(No fence; the two sides are ordinary loads and stores.)*

**Before, for a read-modify-write.** The same compiler turns `__atomic_fetch_add(p, 1, __ATOMIC_SEQ_CST)` into `lock xaddq %rax,(%rdi)` on x86-64 (one instruction), `li` and `amoadd.d.aqrl a0,a1,(a0)` on RISC-V (two), and on Arm a loop `ldaxr`, `add`, `stlxr`, `cbnz` with a `mov` before it (five; assembled with clang and gcc here). The suffixes `aqrl` and the `a` and `l` in `ldaxr`, `stlxr` are ordering bits: "acquire" and "release". On the pdp64 this is `aadd r1, (r3), r2` (add `r1` to the memory at `r3` and leave the old value in `r2`), four bytes, and nothing more is needed. An earlier form of our own instruction set had a second spelling of ten atomics that carried a fence inside it (a "double barrier" form); with ordered memory those twenty words duplicated the plain ones, so they are gone: **the atomics are ten operations, `LL` and `SC`, each in 4 and 8 bytes, 24 words, and no more.**

### What it enables

* **Lock-free queues and message passing with no fence**, as above: write the data, then the flag; read the flag, then the data. Seeing the flag is seeing the data.
* **Mutual exclusion without any atomic instruction.** Peterson's algorithm (two flags and a turn word, written in the 1980s) is correct on a sequentially consistent machine as it is printed, which is why textbooks could print it. On weak machines it is wrong unless fences are added.
* **Reasoning by interleaving.** A student can check a concurrent routine by writing down the order of its loads and stores and trying every interleaving; no more tables of what may be reordered.
* **A short ABI.** The calling convention says nothing about memory order, because a function cannot be given a stale value by one that returned.

### What it saves us from

* **The store-buffer test on x86.** The Linux kernel's own account (Paolo Bonzini, LWN, 5 March 2021) is that on x86 "all memory loads count as 'load-acquire', and all memory stores count as 'store-release'", yet both threads can read zero in the test where each stores to its own variable and then loads the other's; the only way around it is to flush the store buffer, "as expensive as it sounds (a few tens of clock cycles)".
* **The size of the vocabulary.** I counted the ordering vocabulary of Linux: 5,596 code lines in 855 files, plus 3,016 lines of `memory-barriers.txt`. A pdp64 program has no such vocabulary to learn or to get wrong.
* **Mixed sizes break the barriers' promise on weak machines.** Flur, Sarkar and others (POPL 2017) show that on Arm and POWER "barriers do not recover SC for mixed-size" accesses, and kernels use mixed sizes (the 8-byte compare-and-swap of Linux's `lockref` over two 4-byte fields). The pdp64 states the order per byte, so the case has an answer.
* **Alpha's `mb` inside every atomic.** OpenBSD's Alpha `atomic_setbits_ulong` is `ldq_l`, `or`, `stq_c`, `beq`, `mb`, `br`: the fence is inside each atomic because the machine needs it. Here no atomic carries one.

### What it costs

On a large out-of-order core, sequential consistency needs loads that can be replayed when another core touches the line they read; I could not measure that cost, because no such core exists yet. The first implementations are in order and pay nothing. A simple memory model does not make the atomics simple to build; it makes their meaning simple.

### What it puts off limits

A program cannot ask for a weaker order to go faster; there is no relaxed load. `FENCE` remains for one purpose, ordering accesses to devices, which are not ordinary memory.

### Where the manual states it

{{r:memory-is-sequentially-consistent}}, {{r:isa-memory-is-sequentially-consistent}}, {{r:memory-is-sequentially-consistent-per}}, {{r:abi-says-nothing-about-memory}} and {{r:atomic-group-atom-holds-cas}}.
