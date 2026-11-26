# Part 8. The security corpus

## {{#annex-faulting-load}} A load that faults delivers no data: the Meltdown rule, checked by a probe

**The decision.** A load that takes a fault delivers nothing: its destination register keeps its old value, and no later instruction can use a value that the failed access produced; the security corpus holds a small program that checks this and exits with status 0 only if the machine does as the rule says.

**The problem.** Programs run in **user mode** and the kernel in **kernel mode**, and the kernel's memory is protected from the programs: a load of a kernel address from user mode takes a fault. On a machine that guesses ahead (**speculative execution**: it runs instructions before it knows they should run, to save time) the check may come late. In January 2018 it was found that on most Intel processors, and some Arm, Power and IBM z cores, the load returned its data to the instructions after it, which ran and left a trace in the cache, before the check caught up and raised the fault. The fault came; the trace stayed. A program could read any kernel byte by timing which cache line was warm. This was **Meltdown** (CVE-2017-5754), found independently by three teams, in the repository's catalogue.

The cure that had to be applied to existing machines was to stop having the kernel's memory in the user program's address space at all: **page-table isolation**, which means a switch of the page-table base register at every system call, every interrupt and every return. That is an expensive cure, in code and in time. Dave Hansen's cover letter for the Linux version (31 October 2017) said "a few hundred cycles" per system call or interrupt, "5% ... typical" and "roughly 30%" in the worst case; Linux's own `pti.rst` says a base-register write is "on the order of a hundred cycles" at each entry and exit. OpenBSD, NetBSD and FreeBSD each added it within 11 weeks.

### Before and after

**Before** (OpenBSD amd64, `sys/arch/amd64/amd64/locore.S`, the end of `Xsyscall_meltdown`; quoted):

```
        movq    %rax,CPUVAR(SCRATCH)
        movq    CPUVAR(USER_CR3),%rax
        PCID_SET_REUSE_NOP
        movq    %rax,%cr3
Xsyscall_trampback:
        ...
        swapgs
        sysretq
```

*(The kernel's tables are dropped from the user's view by writing the page-table base register on every return to user mode; the same dance is repeated at every entry. A second copy of the code that lives in a page that both views map, `KUTEXT_PAGE`, is needed to run it. It is a patch on a flaw of the hardware.)*

**After** (pdp64, `snippets/faulting-load.S`; it runs on `sim64 -K` and exits 0):

```
        movq    =0x1111, r4                     ; the old value of the destination
        movq    =0x0100000000000000, r5         ; an address with nothing behind it
        movq    (r5), r4                        ; faults; r4 must keep 0x1111
...
hbf:    movq    =0x1111, r6
        cbne    r4, r6, hbad                    ; the handler finds r4 unchanged
        movq    #0, r0
        halt
```

*(Seven instructions in all. This is a minimal probe of my own for the rule; the corpus's own probes, `sec-restart-scalar` and the others, check more.)*

### What it enables

* **A kernel that does not hide itself.** There is no need for a separate page table for user mode with a trampoline that both views map.
* **A rule that an implementation can be tested against.** Each probe of the security corpus exits 0 if the implementation does *not* have the hole, and with the number of the failed check otherwise; every passing probe was shown able to fail by breaking a scratch copy of the model the way the hole would break it (for `sec-restart-scalar`, by not restoring the register file after a fault: the probe then fails at check 10).
* **A rule for any later, faster core.** The privilege, permission and valid-bit checks must finish before any value derived from the access is visible to a dependent instruction; a not-present or reserved-bit entry produces no data. That is the checklist rule the catalogue writes for any implementation, and it is the same rule as "every instruction can be restarted after a fault, and exceptions are precise".

### What it saves us from

* **Meltdown** and the **permission-check-after-the-data** family: Foreshadow (the L1 terminal fault, in which a not-present entry still let the cache supply data), and the buffer-sampling family (RIDL, Fallout, ZombieLoad), where stale data inside the core is forwarded to a load that is going to fault.
* **The patch's own cost** above: a page-table switch at every entry and exit.
* **The not-present entry that is not empty**: the L1TF cure was "PTE inversion", writing unmapped entries so that their address bits point at memory that does not exist. A walker that never forwards data from an invalid entry needs no such convention.

### What it costs

The first implementations are in order and do not speculate, so the rule costs them nothing, and I cannot say what it costs a speculating core, which does not exist yet. The model that the probe runs on (`sim64`) has no cache and no speculation: the probe tests the architectural form of the rule (no data, a precise fault), and cannot test timing. The corpus says so in its own index of what cannot be tested.

### What it puts off limits

No design that forwards a load's data early and checks late. No hardware shortcut that returns something from an entry that is not valid.

### Where the manual states it

{{r:every-instruction-can-be-restarted}}; the probes are listed in `docs/security-corpus.md` as SEC-B17 (this one) and its neighbours.
