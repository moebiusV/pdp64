# Part 3. Interrupts and the timer

## {{#annex-timer-deadline}} The timer as one absolute deadline, where zero means never and the interrupt is a level

**The decision.** Time is a counter that only counts up and cannot be written (`TIME`), and one register per core holds an absolute deadline (`TIMECMP`); while the counter is at or past a deadline that is not zero, the core's timer line is asserted as a level, and a deadline of zero means never.

**The problem.** The PDP-11's line clock (the KW11-L) interrupted at a fixed rate, whether anybody wanted it or not; the kernel's `hardclock()` counted ticks to keep the time and to decide when to switch processes. A modern kernel does not want to wake a sleeping machine sixty or a thousand times a second, so it asks a timer for a single interrupt at the moment of its next need. How the timer is asked decides how many ways there are to ask wrongly.

Arm gives a compare register (absolute) and also a down-counter (relative); the kernel chooses. OpenBSD's Arm driver (`sys/arch/arm64/dev/agtimer.c`) uses the relative one: it works out how many cycles away the deadline is, clamps it so that it fits in 32 bits (at 10 MHz that is about 214 seconds), writes it, and executes a barrier. A separate control register has an enable bit and an interrupt-mask bit, so there are three things to set in the right order.

### Before and after

**Before** (OpenBSD arm64, `agtimer.c`; quoted):

```
static inline int
agtimer_set_ctrl(uint32_t val)
{
        __asm volatile("msr CNTV_CTL_EL0, %x0" :: "r" (val));
        __asm volatile("isb" ::: "memory");
        return (0);
}

static inline int
agtimer_set_tval(uint32_t val)
{
        __asm volatile("msr CNTV_TVAL_EL0, %x0" :: "r" (val));
        __asm volatile("isb" ::: "memory");
        return (0);
}

void
agtimer_rearm(void *cookie, uint64_t nsecs)
{
        ...
        if (nsecs > sc->sc_nsec_max)
                nsecs = sc->sc_nsec_max;
        cycles = (nsecs * sc->sc_nsec_cycle_ratio) >> 32;
        if (cycles > INT32_MAX)
                cycles = INT32_MAX;
        agtimer_set_tval(cycles);
}
```

*(The control register has an enable bit and an interrupt-mask bit; the counter's frequency is read from a register that firmware has to fill in, so the conversion needs a ratio. To fire at once the driver writes a relative value of zero.)*

**After** (pdp64, `snippets/timer.S`; the register names `TIME` and `TIMECMP` are not yet known to the assembler, see the pilot notes):

```
        mfsr    r1, time                ; arm from now: read, add, write
        add     $100000, r1             ; 100000 ticks of 100 ns is 10 ms
        mtsr    timecmp, r1
tick:   mfsr    r1, timecmp             ; a periodic tick: the old deadline plus the period
        add     $100000, r1
        mtsr    timecmp, r1
        mov    $0, r1                  ; nothing to wait for: zero means never
        mtsr    timecmp, r1
```

*(Three instructions to arm, one write to re-arm or disarm. No control register, no mask bit, no barrier: a write takes effect before the next instruction.)*

### What it enables

* **A tickless kernel**: the core sleeps until its one next deadline, and the kernel writes zero when there is nothing to wait for.
* **A periodic tick without drift**: the handler adds the period to the *old* deadline, so lateness does not accumulate. There is no periodic mode to mis-handle (a second tick before the first was taken).
* **A level that cannot be lost.** While the counter is past a non-zero deadline, the line stays asserted until software writes a later deadline or zero. A masked interrupt is delayed, not lost.
* **Zeroed memory is safe.** A freshly allocated context, a cleared save area, a guest whose registers the hypervisor zeroes: loading zero into the deadline means never. Had all-ones meant never, loading zero would have meant "long ago" and the timer would have fired at once and again until rewritten.
* **A guest's own clock**: the guest reads the real counter minus an offset the hypervisor sets, and has its own deadline; the interrupt line is a level too, the same as the real one, so the same handler runs on bare metal and in a guest.

### What it saves us from

* **The many timers of the PC.** Thomas Gleixner, Linux's timekeeping maintainer (LWN, 19 May 2010): "I'm unfortunately forced to deal with the 500+ different variants of borked timers and that makes me very reluctant to believe anything what chip/board/bios vendors promise." A counter defined by the architecture has no variants.
* **The frequency told by firmware** (Arm's frequency register, which firmware has to fill in, and for which Linux has a workaround binding) and the 32-bit relative range above.
* **The race of a changed deadline.** The study of the x86 deadline register records that an edge interrupt can still be delivered once for a deadline that was just changed; RISC-V's rule allows a spurious interrupt after re-arming. Here an interrupt is never taken for a deadline the write removed.
* **The interrupt storm of a level that is never cleared** (the "nobody cared" case in the Linux kernel pain points): the storm here would be a handler that does not write a later deadline, and the handler is the kernel's one place that does.

### What it costs

The comparator is 565 gates and 28 gate levels deep (counted with the repository's synthesis method; a 64-bit subtract is 131 levels, and every core already finishes that in a cycle). Arming from nothing is three instructions where a relative write would be one; they run once per scheduling event, not in a loop.

### What it puts off limits

No periodic mode, no relative write, no write to the counter, no second clock. The counter ticks at a fixed 10 MHz (a tick is 100 ns); a program that wanted a finer tick must count its own work.

### Where the manual states it

{{r:timer-is-two-system-registers}}.
