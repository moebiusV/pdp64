# Part 4. Privilege, returns and registers

## {{#annex-rti-mask}} Return from interrupt with a register mask: the hardware clears what the kernel forgot

**The decision.** The only form of the return instruction `RTI` carries a 32-bit mask naming the registers to keep, and in the same step as the return to a less privileged mode the hardware clears every register the mask does not name.

**The problem.** On the PDP-11 the kernel ran in kernel mode and the user's programs in user mode, and `rti` (return from interrupt) popped the old program counter and status word and went back. The registers were simply left as they were. A kernel uses the registers for its own work; if it did not wipe them before returning, a user program could read whatever the kernel last left there: a pointer into the kernel, a part of a key, another process's data. On the PDP-11 this mattered little. On a machine that is attacked, it is a leak that costs one forgotten instruction to create and cannot be found by testing, because nothing fails.

Intel's processors made the idea concrete in 2018 and 2019. A mistaken load could be handed stale data from buffers inside the core, and the kernel's cure was to clear them by hand on every return to user mode. This is a real piece of OpenBSD's amd64 kernel, the end of the system call (`sys/arch/amd64/amd64/locore.S`): the kernel restores the user's registers one by one, then clears the ones it will not restore and runs `verw`, an instruction that was given a second job of emptying those buffers.

### Before and after

**Before** (OpenBSD amd64, `locore.S`, in `Xsyscall` just before `sysretq`; quoted):

```
        CODEPATCH_START
        xorl    %edi,%edi
        xorl    %esi,%esi
        xorl    %r11d,%r11d
        xorl    %eax,%eax
        xorl    %ecx,%ecx
        movw    %ds,TF_R8(%rsp)
        verw    TF_R8(%rsp)
        CODEPATCH_END(CPTAG_MDS)
```

*(Seven instructions, counted from the file. The kernel patches these in at boot only on processors that need them, so one more thing can go wrong; and the five registers are the ones this routine knows about. One it does not know about stays.)*

**After** (pdp64, `snippets/rti-syscall.S`, assembled):

```
        rti     #RTIMASK_SYSCALL        ; keep r0 and the callee-saved registers; every other register reads zero
        rti     #(RTIMASK_SYSCALL | (1<<2))     ; the same, and keep r2
```

*(One instruction, six bytes, of which four are the mask. The runnable test, `docs/encoding-work/hypervisor-text-v3-snippets/ex08-return-mask.S`, leaves a secret in `R5` and a user value in `R8`, returns with `RTI #(1<<8)`, and checks that the user finds zero and the value.)*

### What it enables

* **A system-call return in one instruction.** The result register and the registers the calling convention keeps are named once; everything else is cleared by the hardware, whatever the kernel did.
* **A mask the tools write.** The assembler and the compiler derive the mask from the same list of registers the entry code saved, so there is one source of truth; a forgotten register then reads zero, which fails loudly in the first test, instead of leaking quietly.
* **The same return for a guest.** The instruction that enters a guest takes a mask in the same way, so the hypervisor's registers never reach a guest either.
* **Vector registers and floating-point flags in the same step.** Bit 14 of the mask would name the stack pointer, which is never cleared, so I use it for "keep the vector registers"; with it clear, the vector registers and the floating-point flags are cleared too.

### What it saves us from

* **The stale-register leak class**, of which the MDS family is the loudest member (May 2019). Its first fix "only partially addressed RIDL"; researchers at mdsattacks.com wrote that "the initial mitigations ... clear the buffers by writing stale, potentially sensitive, data into these buffers" (as the repository's study records it). Here the clearing is architecture, not a patch.
* **Zenbleed** (July 2023, AMD Zen 2): a mispredicted vector instruction leaves registers holding other processes' data; the cure was a "chicken bit" that switched off an optimisation. A return that clears the vector registers does not depend on the core's cleverness.
* **Lazy floating-point restore** (June 2018): the previous process's floating-point registers stayed readable until a delayed restore trapped; Linux went to eager save and restore. Here there is nothing delayed.
* **Two designs that look better and are not**, which I measured on the repository's own kernels. A latch that remembers the last return's mask is wrong depending on when the timer ticks: in a two-process kernel, 52 of the 105 mismatching returns would have left a kernel register with the user, and the count changed from run to run (20, 52, 61, 73). Hardware that clears "every register written since entry" clears the user's own registers that the kernel put back: at 70 of 70 interrupt returns of that kernel.

### What it costs

A return is six bytes instead of two; returns run at the rate of interrupts and system calls, not in loops. The clear costs a few thousand gates (I measured +2,112 gates over a 27,593-gate register file for the mechanism, no extra depth in the register read path). A hypervisor can keep nothing in registers across a guest's run, so it stores a counter before and loads it after: one store and one load a counter, per exit.

### What it puts off limits

There is no `RTI` without a mask, so a kernel cannot return to user mode and leave a register for the user to inherit. A return to the *same* mode ignores the mask. The registers `R16` to `R23` are scratch for callers; nobody can count on them surviving a return.

### Where the manual states it

{{r:rti-mask-is-the-only}}, {{r:rti-mask-loads-the-program}}, {{r:mask-is-32-bits-bit}} and {{r:return-to-the-same-mode}}.
