## {{#annex-hypervisor-own-translation}} The hypervisor level translates its own addresses, the way Arm's host extension does

**The decision.** At the hypervisor level the ordinary registers (`PTBR`, `ASID`, `MMUCTL`, `VBR`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `R14`, `DP`) mean the hypervisor's own, so an ordinary pdp64 kernel can run there unmodified, with its own page tables, tag 0 and one stage.

**The problem.** A hypervisor is a program, with a stack, data and bugs. If it runs on real addresses with no translation, a stray pointer in it (a guest-controlled index used as an offset, a freed buffer used again) is not caught: it writes whatever is at that real address, perhaps another guest's page. And a hypervisor that has no translation of its own cannot be an ordinary operating system: a **host** kernel, one that is a full operating system and also runs guests, would need two halves, one running at the kernel level and one above it.

Arm met this in two steps. Its hypervisor level (EL2) first had registers of its own, different from the kernel's (`ttbr0_el2` where a kernel writes `ttbr0_el1`), and no address-space numbers; the repository's reading of Arm's guide quotes "The EL0/1 virtual address space also supports Address Space Identifiers (ASID), but EL2 does not." and "Translations for the EL2 and EL3 translation regimes are not tagged with a VMID". The **Virtualization Host Extensions** (VHE; the bit `E2H` turns it on, "Controls whether VHE is enabled") then made a kernel that runs at EL2 write the same register names as before; the hardware redirects them. RISC-V's hypervisor-extended mode (HS) takes the other road: the host is the ordinary kernel with translation.

### Before and after

**Before** (Arm; assembled here with clang `-target aarch64 -march=armv8.1-a`; the three lines are `snippets/foreign/el.s`):

```
        msr     ttbr0_el1, x0           // what an operating system's code writes
        msr     ttbr0_el2, x0           // the same code, running at the hypervisor level
        msr     ttbr0_el12, x0          // a host kernel reaching the guest's table
```

*(Three register names for one idea; without VHE the code of the host kernel must be written twice, or recompiled for the higher level. 12 bytes.)*

**After** (pdp64, `snippets/hv-own-translation.S`, assembled):

```
        lea     hproot, r1
        mtsr    ptbr, r1                ; the hypervisor's own table root
        movq    #1, r2
        mtsr    mmuctl, r2              ; its own translation on (one stage, tag 0)
        isync
```

*(The code is the kernel's code: at `H` = 1 the names mean the hypervisor's registers. The guest's registers are separate ones, in the numbers 128 to 164.)*

### What it enables

* **A host kernel unmodified.** An ordinary pdp64 kernel, with its handlers, its page tables and its `RTI`, runs at the hypervisor level, and its guests run below it. One operating system can be both.
* **A protected hypervisor.** A stray pointer in it faults like a stray pointer in a kernel. A guest's translation entry never answers a hypervisor access.
* **Existing verified kernels.** The seL4 microkernel, whose proofs cover a configuration at the hypervisor level on Arm only (the repository's note), has a place to run.
* **A choice.** A hypervisor that leaves `MMUCTL` clear runs on real addresses and pays for no tables, as a small hypervisor may want.

### What it saves us from

* **An unprotected hypervisor** with a flat view of memory: a bug in it is a bug in every guest. The corpus has a probe for it ("the hypervisor has no translation regime of its own, so a stray pointer of the hypervisor is not caught"), and the design closes it.
* **The split host kernel** of the first Arm hypervisors.
* **A third translation regime**, with its own table-walk rules, for the hypervisor alone: the regime here is the ordinary one.

### What it costs

The page-table walk for the hypervisor's own misses, and its tag 0 entries in the translation buffer. A state bit and a handful of registers, a second root and a guest tag in the buffer: the study put each at a fraction of a percent to about one percent of the scalar core. The second walk of a guest costs `n*m + n + m` reads for `n` levels in the guest's tables and `m` in the second stage: 15 for three and three, against 3 for one stage.

### What it puts off limits

A guest cannot host guests. Its use of a hypervisor register is an exit, and nested virtualization is not in this version.

### Where the manual states it

{{r:hypervisor-level-translates-its-own}} and {{r:while-h-is-1-hypervisor-registers}}.
