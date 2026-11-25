## {{#annex-no-clock}} No unprivileged clock: a user program learns the time by asking

**The decision.** No instruction that a user program can run reads a clock, a counter or the number of the core it is on; the time comes from a system call, and the counter register is for the kernel.

**The problem.** A **cache** is a small fast memory that keeps copies of recently used words; a read of a word that is in it is quick and a read of one that is not is slow. That difference of a hundred nanoseconds or so carries information. A spy program can empty a line of the cache, wait while a victim runs, read the line again and time the read: if it was quick, the victim touched that line. This family of attacks (**Flush+Reload**, **Prime+Probe**, **Evict+Time**, 2005 to 2014) needs three things: a cache shared between the spy and the victim, a way to evict a line, and a clock fine enough to see the difference. Most machines hand the third to everybody. On x86, `rdtsc` reads the processor's time-stamp counter from user mode; the kernel may forbid it with a control bit, and Arm and RISC-V have the same arrangement, with the kernel allowed to let user programs read the full-resolution counter.

I should be plain about what removing the clock buys. A program can make its own clock by a thread on another core that counts as fast as it can, so coarsening a clock is a brake and not a wall. What I buy is a default that is safe without the kernel remembering anything, one defined way to ask the time, and a place where the kernel, which decides what is shared between programs, can also decide how fine the answer is.

### Before and after

**Before** (x86-64; the timing step of a Flush+Reload probe, written in C with the compiler's intrinsics and compiled here with gcc 14; the file is `snippets/foreign/probe.c`):

```
reload_time:
        clflush (%rdi)          # evict the line
        rdtscp                  # read the clock: unprivileged
        ...
        movzbl  (%rdi), %eax    # reload the line
        rdtscp                  # read the clock again
        ...
        subq    %rsi, %rax      # the difference tells quick from slow
```

*(Two unprivileged clock reads and one unprivileged cache-flush instruction. The flush instruction is the second half of the attack: Project Zero (9 March 2015) found that on x86 `clflush` "can't be intercepted or disabled, even using VMX"; "ARM doesn't have an unprivileged cache-flush instruction".)*

**After** (pdp64, `snippets/user-time.S`, assembled; the call number 7 is the example's own):

```
        movq    #7, r0
        trap    #0                      ; r0 comes back holding the time
```

*(Two instructions, four bytes. There is nothing to put in the place of `rdtscp`.)*

### What it enables

* **A kernel that decides.** If a later version gives programs a fast clock, it will be a hardware-rounded read, switched off at reset and coarsest by default, so a kernel that forgets to configure it is still safe.
* **A guest that cannot see the real time.** The guest's `TIME` is the real counter minus an offset, and a guest has no way to read the real counter.
* **Time-independent results.** A program that must not leak (a cipher) can be run knowing that no one in user mode could take its measurements with a hardware clock.

### What it saves us from

* The part of **Flush+Reload and Prime+Probe** that is a user-readable fine clock (the repository's catalogue lists the family as needing "a precise timer"), together with the privileged cache flush that the attack also wanted.
* **A clock page that goes stale.** One alternative is a page that the kernel updates "when it runs", for user programs to read. In a kernel with no periodic tick, a program that spins on that page until a deadline sees time standing still until the kernel next runs, and may never leave the loop. I withdrew the idea for that reason: a clock must advance for correctness, not only for timing channels.
* **An unreliable counter.** Thomas Gleixner (LWN, 19 May 2010) on the x86 counter: system-management interrupts adjust it to hide themselves, cores differ by boot offsets, sockets drift with temperature. One counter defined by the architecture, for the whole machine, that never goes back, has none of that.

### What it costs

A system call for each reading. I measured on a six-core x86-64 desktop (Linux 6.12) that the kernel-assisted user read of the clock takes 16.8 ns against 158 ns for the same call as a real system call, a factor of 9.4, and Linux added the user-readable path for that reason. In the repository's cycle model a read from a kernel-kept word costs 1 cycle and a trap costs the model's trap parameter plus one (21, 101 or 301 cycles for settings of 20, 100 and 300); the model's trap is a parameter, not a measurement of a kernel. How often real programs read the clock, which is what decides, I did not measure. A program that stamps every request (a database, a network server) will feel it.

### What it puts off limits

No `rdtsc` and no `rdtime`. A timing loop in user mode, a profiler that counts cycles, a benchmark that wants the counter: all ask the kernel, or run in kernel mode.

### Where the manual states it

{{r:every-instruction-that-reveals-or}}, with {{r:timer-is-two-system-registers}}.
