# Part 6. Vector blocks and resume

## {{#annex-vector-resume}} Vector blocks resume where they were interrupted, optionally, from a hidden record with a keyed token

**The decision.** When an exception or an exit interrupts a vector block, the hardware may keep one hidden **resume record** and carry on at the strip where the block stopped; a core that keeps no record is a conforming core, no program may depend on resuming, and a one-use token in the saved status word ties a resume to the suspension that made it.

**The problem.** A **vector** instruction works on many numbers at once (a row of 16-bit words, say) and a **vector block** is the pdp64's way of working on a whole array with one short piece of code: `VEC` names a pointer and an end, and the instructions up to `VEND` run once for each **strip**, a piece of the array a few words wide that the hardware handles together. A running total can be kept in a hidden **accumulator**.

Now an interrupt arrives after the third strip. The accumulator holds twelve words' sum; the pointer has moved on. What happens to that work? The PDP-11 never had the question. The machines that did have it chose between three answers. The program can **restart** the block from its first strip, throwing away the three strips done (correct, and hopeless if a page fault comes every strip: the block never ends). The operating system can **save the vector state** at every interrupt and put it back (correct, and the state grows with every generation: Linux's x86 floating-point and vector state is the clearest case, with a lazy restore that leaked the previous process's registers, June 2018). Or the program can be written as a **strip-mined loop**, where the program itself re-reads the remaining count each time round, so that the loop's variables hold the progress.

### Before and after

**Before** (RISC-V vectors; a strip-mined sum of `n` 16-bit words; written by me and assembled here with clang `-march=rv64gcv`, `snippets/foreign/rvv-sum.s`):

```
        li      t2, 0
loop:   vsetvli t0, a1, e16, m1, ta, ma
        vle16.v v8, (a0)
        vsetvli zero, t0, e32, m2, ta, ma
        vzext.vf2 v12, v8
        vmv.s.x v16, zero
        vredsum.vs v16, v12, v16
        vmv.x.s t3, v16
        add     t2, t2, t3
        sub     a1, a1, t0
        slli    t0, t0, 1
        add     a0, a0, t0
        bnez    a1, loop
```

*(13 instructions, 42 bytes. The program works out the strip each time round, sums each strip separately, and adds it to a scalar. The progress is in the program's own registers, so an interrupt can strike anywhere; the cost is that the program carries the loop, and the reduction runs once for each strip.)*

**After** (pdp64, `docs/encoding-work/hypervisor-text-v3-snippets/ex08-vector-sum.S`, which runs on `sim64` and gives the same sum with strips of 16, 32 and 64 bytes):

```
        vec     r1, r4                  ; the block: the body runs once for each strip
        vclr.l  v4, #1                  ; the accumulator starts at zero (only inside the block)
        vld.w.l v0, (r1)+               ; four 16-bit words widened to 32 bits; the pointer advances
        vadd.l  v4, v4, v0              ; the running sum, by lane
        vfin                            ; the epilogue: once, after the last strip
        vacc.l.q r12, v4                ; add the lanes into R12
        vend
```

*(Seven instructions, 28 bytes counted by assembling the block alone. The strip is invisible to the program.)*

A handler that wants the block to start again rather than resume clears the token (`snippets/resume-token.S`, assembled): it reads `EPSW`, shifts the upper half away, writes it back and returns.

### What it enables

* **Short loops that do not know the strip.** The same program runs on a core with a 16-byte strip and one with a 64-byte strip, with the same answer, because the accumulator is hidden.
* **No kernel duty.** The handler sees the entry values of the registers and the address of the `VEC`; returning to it restarts the block correctly with no state saved. Resuming is an acceleration that costs the kernel nothing.
* **Progress under pressure.** Restart with no record costs 1.6 to 2.5 times on a cold micro-kernel, up to +27% with a 10 kHz timer, and 1.5 to 1.8 times under page faults (my measurements on the repository's own kernels); resume stays within 2% of an uninterrupted run. And a block is limited to 256 strips, so even a core with no record makes progress.

### What it saves us from

* **The lazy-state leak.** A kernel that forgot to save a coprocessor's state, or restored it lazily, leaked it (the lazy floating-point restore, June 2018, fixed in Linux by eager save and restore). Here the kernel has nothing to save, because the accumulators are never visible.
* **Hidden state found by the wrong key.** Three holes of my own first design were found by the security corpus before this text was settled: an exception between `VCLR` and `VEC` changed the answer; an in-place block was wrong after a page fault because the first strip's work was done twice (4 of 8 lanes held 2 instead of 1); and a record found by the address of the `VEC` alone gave a second context, running the same code at the same address, the first context's accumulators. The rules now say the record is found by address *and* context and dies at every context boundary.
* **A stale or forged record**, by the token: a keyed permutation of a counter, so it does not repeat within 2^32 suspensions (11.9 hours at 100,000 suspensions a second, assumed rate) and shows a guest nothing of other guests' suspensions.

### What it costs

Gates: the record is 7,537 gates (counted), the 32-bit permuted token 1,997 (a plain counter would be 331): together 9,534 gates, about 3.4 percent of the vector unit's 278,959; a core with no record costs none of that and is slower on interrupted blocks. A block that changes more than four registers has no record (none of 16 accumulator blocks I scanned changed more than three).

### What it puts off limits

A program cannot rely on resuming, cannot read the accumulators, and cannot use `VCLR` outside a block. A block whose main loop stores through the register it loads through, with accumulators, is refused at the `VEC`. A block is not atomic against other writers of memory.

### Where the manual states it

{{r:vector-block-that-an-exception}} and {{r:every-instruction-can-be-restarted}}.
