# seL4 on the pdp64

[← pdp64 index](../README.md)

*What the seL4 kernel needs from a processor, what the pdp64 provides, what the pdp64 does beyond other processors, and what is and is not known about the size of the proof. State as of 2026-11-25. The facts about seL4 were read from its own pages on that day; the status of the pdp64 changes with every commit, so sections 3 and 7 are the parts to keep current.*

## 0. The summary, on one page

**What this paper claims**

1. **seL4 is a design target of the pdp64, not a port.** The pdp64 architecture was reviewed against seL4's documents, several changes were decided because of that review, and some of them are built in the simulators. **No seL4 source has been compiled for the pdp64, nothing of seL4 runs on it, and there is no silicon.** The README sentence "it supports seL4" means this and nothing more.
2. **What seL4 needs from a CPU** (section 2) is known from seL4's own documents. A good part of it the pdp64 provides by decision, and some of that is built and tested in the reference executor and in the QEMU model (section 3). The rest is open or approved but not yet built: the interrupt controller, the atomic instructions (22 words of the instruction set that the executor does not implement), the kernel root register, the invalidate by address-space number, the system-call register convention in the manual, the formal model of the instruction set, and the toolchain test.
3. **Beyond other processors** (section 4) the pdp64 has a set of rules whose purpose is to make whole classes of mistakes impossible rather than detected: exceptions that write only registers, sequentially consistent memory, every illegal encoding defined, an IOMMU that is blocked at reset and has no bypass, a tag and rules that keep translations from going stale, hidden state with discard rules, a return that clears registers, floating-point flags cleared on a context write, and a hypervisor level designed with all of these. For each, section 4 says what is built, what is only approved, and what an implementation of the architecture can be tested against (the security corpus). Several of the closing rules are **approved but not built**, and the current model **still has** the holes they close (seven holes are found by the corpus today).
4. **Faster** (section 5): what is measured is small and is not seL4. Nothing in this paper says seL4 would run faster on a pdp64.
5. **The proof** (section 6): **no reduction of the proof's size has been shown or measured, and none can be, because seL4 has not been built for the pdp64.** Section 6 says, labelled *in theory*, what could reduce what the proof must *assume or trust* about the hardware, what could make a proof *smaller*, and what costs *extra* (the formal model of the instruction set is the largest extra). The share of seL4's proof that depends on the processor is **not known**; no source gives it.

**What this paper does not claim.** It does not claim that the pdp64 is better for seL4 than Arm or RISC-V. It does not claim a smaller proof, a faster kernel, or a lower proof effort. It does not claim that a feature that exists in the model works in silicon. Every statement about another system is either checked in a primary source that is named with its address and the date read (section 8), or is marked *not verified* and is kept out of the conclusions.

**The vocabulary of status, used the same way everywhere**

| word | meaning |
|---|---|
| **decided** | written as a decision in the manual or the errata (the numbered list of decisions, `docs/errata.md`); the details may still be open. Nothing is implied about whether it is built. |
| **approved, not yet built** | the project owner approved it, on the date given; it is not in the grammar, the executor, the QEMU model or the tools. |
| **built** | present in the reference executor (one C source shared by the simulator `sim64` and the QEMU model) and/or in the QEMU model. The text says which. `sim64` has no memory-management unit and no bus, so everything about translation and devices is built in the QEMU model only. |
| **tested** | a named test program of the repository runs it and passes (`tests/sim`, `tests/qemu`), or a named probe of the security corpus. |
| **measured** | a count or a run, with its source document: gates (a synthesis count in NAND2 equivalents, one two-input NAND being 1), instructions, or cycles of a model. |
| **estimate** | a judgement, with its reason. |
| **open** | no decision. |
| ***in theory*** | argued from the design, not shown by a proof, a build or a measurement. |
| ***not verified*** | I could not confirm it in a primary source; it is not used for any conclusion. |

**Words used** (each is explained again where it first matters). A **microkernel** is an operating-system kernel cut down to what must run with full privilege (address spaces, threads, messages between them, delivery of interrupts); drivers and file systems run as ordinary programs. **seL4** is such a kernel. A **capability** is an unforgeable token naming a kernel object and the rights to it. A **formal proof** here is a machine-checked mathematical argument, in the Isabelle/HOL theorem prover, that the kernel does what its specification says. **Binary correctness** is a further proof that the machine code produced by a compiler has the behaviour of the C source. An **instruction-set model** is a precise mathematical description of what each instruction does, used by that proof. A **TLB** (translation lookaside buffer) is the processor's small cache of address translations. An **ASID** (address-space identifier) is a tag that lets the TLB hold entries of several programs at once. A **guest tag** is the same kind of tag for a guest operating system. An **IOMMU** is the unit that translates and checks the memory addresses used by devices (**DMA**, direct memory access). A **hypervisor** runs whole guest operating systems; an **exit** is the guest stopping so that the hypervisor can act. A **precise exception** is one taken so that the machine looks as if it ran one instruction at a time. A hole is closed **by construction** when the architecture makes the mistake impossible to write, as opposed to detected afterwards. The **reference executor** is the C program that defines, in executable form, what each pdp64 instruction does. The **security corpus** is the set of small test programs that look for known holes (section 4.10).

## 1. seL4 in brief, and what its proofs cover and assume

*Everything in this section was read on 2026-11-25 in the pages named in section 8 (the labels in square brackets are the short names used there), and each quoted sentence was checked mechanically against the text of the page.*

### 1.1 What it is

seL4 is a microkernel of the order of ten thousand lines of C [Manual, introduction], with a machine-checked proof written in the Isabelle/HOL theorem prover: "The formal proofs for seL4 are hosted at https://github.com/seL4/l4v. They are written in the Isabelle/HOL theorem prover." [Cfg]. Programs act only through capabilities. The kernel is event-driven with one kernel stack, and it uses "a preemptive, tickless scheduler" [Manual]. A scheduler is tickless when it sets a one-shot timer for the next event instead of taking a regular tick.

The proofs have layers [TOCS, FAQ]: functional correctness (the C code implements the abstract specification), integrity and availability (access control), confidentiality (information flow), and, on some architectures, binary correctness. On the paper's own figures (2014, the latest I could read): "480 000 lines of Isabelle proofs and specifications" [TOCS]; the whole correctness proof took "about 20 py" (person-years), of which "11 py on the seL4-specific proof" [TOCS]; and one change of the kernel interface (reply capabilities) "took about 1 py or 17% of the original proof effort to reverify" [TOCS]. These are 2014 figures; I did not find a current size of the proofs.

### 1.2 Which configurations are verified, today

From the verified-configurations page [Cfg], read 2026-11-25. "FC" is C-level functional correctness.

| configuration | what the page lists as verified |
|---|---|
| `ARM` (AArch32, ARMv7-A, kernel in EL1, no floating point, no hypervisor mode) | FC including the fast path; integrity and availability; confidentiality; "binary correctness, covering C functions that have C-level verification"; the capDL user-level initialiser |
| `ARM_HYP` (AArch32, "The seL4 kernel runs as hypervisor in EL2") | FC including the fast path |
| `AARCH64` (ARMv8-A, kernel in EL2, floating point, hypervisor mode) | FC including the fast path; integrity and availability; confidentiality; "Further properties are under development" |
| `RISCV64` (no floating point, no hypervisor mode) | "C-level functional correctness, no fast path"; integrity and availability; confidentiality |
| `X64` (Intel, floating point, "Hypervisor/VT-x mode: No") | FC, no fast path |

Two remarks. (a) The FAQ says more about RISC-V than the page does: "for 64-bit RISC-V there are functional-correctness proofs to binary code as well as security proofs" [FAQ]; and "For 64-bit Arm v8 and x86 there are functional-correctness proofs to C code" [FAQ]. The build file of the RISC-V verified configuration sets `KernelBinaryVerificationBuild` ON and that of AArch64 does not [Build]. I read these together as: binary correctness exists for AArch32 and for RISC-V 64-bit; the configurations page does not list it for RISC-V. (b) The page says "no fast path" for RISC-V, while the build file sets `KernelFastpath` ON [Build]. The two sources disagree; I report both and use neither for a conclusion. The fast path is seL4's hand-optimised route for the commonest message exchange; it is an extra proof, which a first port can omit.

Newer results (the news page [News]): on 2026-06-29 "Functional correctness proof for MCS seL4 completed on RISC-V" (MCS is the mixed-criticality extension: scheduling contexts and time budgets), to be ported to AArch64; on 2026-08-24 "seL4 security proofs now complete on AArch64".

### 1.3 What is not covered

* **Address translation for devices.** "none of our verified configurations take into account address translation for devices (System MMU or IOMMU)" [Cfg]; the same sentence lists the debug, profiling and printing interfaces and the start-up of the kernel at boot as not covered. The verified AArch64 build sets the System MMU option OFF [Build].
* **More than one core.** Every verified build file I read sets one core (`KernelMaxNumNodes` "1") [Build, RISC-V and AArch64, read today]. The FAQ: "The SMP kernel uses a big-lock approach", that is, one lock around the whole kernel, and "Verification of the multicore kernel is in progress for static multikernel configurations" [FAQ]. A multikernel runs a separate kernel image on each core. The roadmap schedules it: "Project scheduled to complete Q3/28" [Roadmap]. I found no source that schedules a proof of the big-lock kernel.
* **Timing channels.** "the confidentiality proof makes no guarantees about the absence of covert timing channels" [FAQ].
* **Hypervisor mode on RISC-V and x86.** The verified hypervisor configurations are the two Arm ones (above).

### 1.4 What the proofs assume about the hardware

From the page "What the Proofs Assume" [Assume], and the paper [TOCS]. This list is what a hardware design can change.

| assumption | what the sources say |
|---|---|
| **Assembly code is correct.** | "about 340 lines of ARM assembly in our case", "mainly entry to and exit from the kernel, as well as direct hardware accesses"; for the proof the code is assumed correct. [Assume] |
| **The hardware works as the model says**, and the model is small. | The proof "abstracts from cache consistency, cache colouring and TLB" management and assumes these are done correctly in that assembly [Assume]. The paper: "For the parts that we do not model, such as the TLB, we leave the corresponding type unspecified"; "we still assume correctness of TLB and cache flushing operations as well as the correctness of machine interface functions implemented in handwritten assembly" [TOCS]. The machine interface is a short list of operations (set the root of the address space, set the hardware ASID, invalidate the TLB, by ASID or by address, clean and invalidate caches, read the fault registers, `getActiveIRQ`, `maskInterrupt`, and a few more) [TOCS]. |
| **Virtual memory is the weakest assumption.** | "you have to trust us that we got all necessary conditions and that we got them right" [Assume]. The reason: "all kernel reads and writes are performed through a constant one-to-one virtual memory window which the kernel establishes in every address space", and "We make this consistency argument only informally; our model does not oblige us to prove it." [TOCS] |
| **DMA is off.** | "the proof assumes that DMA is off" [FAQ]; "we assume that the CPU and MMU are the only devices that access memory directly" [Assume]. |
| **Boot code is outside.** | "about 1,200 lines of the code base" [Assume]. |
| **One core.** | "we focus on uniprocessor support where the degree of interleaving of execution and nondeterminism can be controlled" [TOCS]; "Proofs about concurrent programs are hard, much harder than proofs about sequential programs." [TOCS] |
| **The instruction-set model** (binary proof only). | On Arm the proof uses a model in the HOL4 prover that "has been extensively validated by comparing its behaviour to that of real hardware" [TOCS]. The privileged and machine-interface instructions are not in that model; they are inside the assumed assembly layer [TOCS, as checked in `docs/encoding-work/sel4-fit.md`]. |

The same page says these assumptions are not fundamental: "In theory, it is possible to eliminate all of them" [Assume]. And, for the virtual-memory part, "there is potential for human error" [Assume].

## 2. What a CPU must provide for seL4

From seL4's own documents only. Where the documents are silent the cell says so. "Required" means the kernel cannot be built without it; "needed for a configuration" means only a configuration uses it.

| need | what the documents say | source |
|---|---|---|
| **Two privilege levels**, a small entry and exit | The entry and exit assembly is small (340 lines on Arm). | [Assume] |
| **A user register context** and fault information | The RISC-V context is 31 general registers plus four saved values: the cause, the status, the faulting address of the instruction and the next one (`SCAUSE`, `SSTATUS`, `FaultIP`, `NextIP`). | [Build, register header] |
| **A system-call register convention** | On RISC-V: the capability address in `a0`, the message information in `a1`, four message registers `a2` to `a5`, the system-call number in `a7`. "the first few message registers are implemented using physical CPU registers" and the rest live in a memory region called the IPC buffer. The MCS configuration adds two more registers. | [Build, register header and the system-call header]; [Manual] |
| **Page tables** | Each architecture defines its own paging objects. On RISC-V 64: "PageTables are indexed by 9 bits of virtual address", and "currently seL4 only supports exactly three levels of paging structures". Page tables are made from untyped memory, so their sizes are powers of two. | [Manual]; [Build] |
| **A constant kernel window** | The kernel reaches its own memory through the same one-to-one window in every address space (above). | [TOCS] |
| **ASIDs and TLB maintenance** | The machine interface has invalidate-all, invalidate-by-ASID and invalidate-by-address. In the hypervisor configurations the 8-bit VMID is used as the ASID: "an ASID limit of 256 for all threads, until 16-bit VMIDs are supported", after which ASIDs are reused "with the associated cache flushing and slowdowns". | [TOCS]; [Manual] |
| **Cache maintenance** | Clean and invalidate operations by address and range. | [TOCS] |
| **Interrupts and a timer** | "The kernel also expects drivers for" the timer, the serial device, the interrupt controller and, if built with it, the IOMMU. seL4 also reads the memory layout and the timer from a device tree. The machine interface needs a way to ask which interrupt is active (`getActiveIRQ`) and to mask one (`maskInterrupt`). The scheduler is tickless. | [Port]; [TOCS]; [Manual] |
| **Atomics and a memory model** | Needed for the multicore kernel only (big lock); that kernel is not verified. The documents give no instruction list. | [FAQ] |
| **An IOMMU** | Needed for a configuration only; "none of our verified configurations take into account" it. | [Cfg] |
| **A hypervisor mode** | Needed for a configuration only (Arm). On Arm the kernel runs in the hypervisor mode and uses the second translation stage and VMIDs. | [Cfg]; [Manual] |
| **An instruction-set model** | Needed for the binary proof only. | [TOCS, Assume] |
| **A compiler** | The verified builds use GCC at `-O2`, with function cloning off and, on RISC-V, the compiler's built-in count-leading-zeros and count-trailing-zeros not used. Where binary correctness exists, "the compiler does not have to be trusted" because its output is checked [FAQ]; the checking tool was built around GCC output [TOCS, as checked in `docs/encoding-work/sel4-fit.md`]. | [Build]; [FAQ] |

**What the documents do not say.** The porting page covers a new *platform* of an existing architecture ("This section covers porting seL4 to a new ARM or RISC-V platform" [Port]); the roadmap speaks of "Reducing the need for verification experts for new platform ports" [Roadmap]. I found no seL4 document that describes a port to a new *instruction-set architecture*, and the TOCS paper contains no statement of what one costs. Everything this paper says about the cost of a new architecture is therefore inference, and is labelled so.

## 3. What the pdp64 provides, and what had to be added for seL4

*Status as of 2026-11-25, from `docs/implementation-status.md`, the grammar (`spec/`), the executor (`common/`), and the test lists, read that day. The pdp64's own documents are the manual (`docs/manual-src`), the errata (`docs/errata.md`) and the ledger (`docs/decisions-and-status.md`). The QEMU model and the LLVM back end are in sibling repositories.*

### 3.1 Requirement by requirement

| seL4 needs | the pdp64's answer | status | tested by |
|---|---|---|---|
| Two levels and a small entry/exit | Modes kernel 0, supervisor 1 (unused), user 3; the stack pointer and the direct-page register `DP` have one copy per mode, so entry needs no stack switch; privileged instructions fault outside kernel mode. `DP` is the per-core pointer in the kernel and the thread pointer in user mode. (manual 6.2) | decided; built (executor, so `sim64` and QEMU) | `sys-user`, `hv-switch`; corpus SEC-P01 to P08, SEC-B01 |
| Exception entry | Writes only registers (`EPC`, `EPSW`, `EVA`, `ECAUSE`), then reads one word of the vector table; priority 7 on every entry; nothing is pushed. `RTI` returns. (6.3) | decided; built | `sys-exc`; SEC-B02 (`sec-eva-stale`) |
| Precise, restartable faults; fault address and cause | Four fault families; the register update of auto-increment modes is held until retirement; a faulting instruction changes nothing. (6.4) | decided; built | `mmu-precise`, `sec-restart-scalar`; SEC-R01 |
| User context | 32 general registers; floating point is done in them; `FPSR` and `DP` are the other state; hidden state exists only inside a vector block (below). | decided; built | |
| **System-call convention** | `TRAP #n` enters vector 256 + n, so the system-call number needs no register; capability address `R0`, message information `R1`, message registers `R2` to `R5`, `R6` and `R7` for the two MCS registers; the IPC-buffer address in the user `DP`. Arithmetic: the six argument registers of the pdp64 ABI exactly hold seL4's capability, message information and four message registers. | **approved, not yet built** (accepted 2026-11-19; not yet written into the manual) | none (no kernel exists) |
| Page tables of the RISC-V 64-bit shape | Three, four or five levels of nine bits over 4 KB pages; a 64-bit entry; one entry shape at every level; the walker only reads. Three levels is the shape seL4 has verified on RISC-V 64. The entry layout differs (the page number is at bit 12 here and bit 10 in RISC-V), so this is the same tree and not the same entry. (6.6, 6.7) | decided; built in the QEMU walker for three levels only; `sim64` has none | `mmu-basic`, `mmu-large`, `mmu-faults`, `mmu-matrix-user`, `mmu-matrix-kernel` |
| **A constant kernel window** | The address space is split by its top bit: the lower half is walked from `PTBR` (one per address space), the upper half from a second root `KTBR` (one for the whole system, the kernel's); user mode never walks the upper half; a mode change flushes nothing. The kernel window of seL4's weakest assumption becomes a fact of the hardware. (6.9.1) | decided; the register number 13 and a one-page root **approved, not yet built** (2026-11-19); not in the executor or the model | SEC-M09 is marked "not applicable: the second root is not built" |
| User-memory guard | A status bit `UA` and the instructions `STUA`, `CLUA`: with it clear, a kernel-mode data access to a user page faults. seL4 does not need it; it does no harm. (6.10) | decided; built (executor, QEMU walker; no effect in `sim64`) | `mmu-ua`, `ua-psw`; SEC-M01 |
| ASIDs and the TLB | A 16-bit address-space number tags each TLB entry; writing `PTBR` and `ASID` together flushes nothing; `TLBI` (one page, current address space) and `TLBIA` (all), both broadcast, and `TLBSYNC`; stated flush rules at writes of `MMUCTL`, `PTBR`, `ASID` and at reset; the walker never writes a page table; accessed and dirty bits are kept by software. (6.8) | decided; built in the QEMU model (stricter than the rule: it discards every entry at a write) | `mmu-flush`, `mmu-tlb`, `mmu-ad`; SEC-B10, B11 |
| **Invalidate by ASID** | A new instruction `TLBIAS`: drop one address space's entries without flushing the rest, and the invalidate of one page of another address space. seL4's machine interface has `invalidateHWASID` and `invalidateMVA`; seL4 reuses ASIDs. Without it, the kernel can only flush everything, or write `ASID`, invalidate and write it back. | **approved, not yet built** (2026-11-25) | none |
| Caches | Data caches coherent between cores; DMA uncached; no data-cache maintenance instruction; `ICINV`, `ICINVA` and `ISYNC` for instructions, all three unprivileged. The cache part of seL4's assumption list shrinks to the instruction cache (*in theory*). (7.6) | decided; the model has no caches | none |
| Interrupts, timer | Eight priority levels; 512 vectors; the timer on level 6 (tickless main cores). In the QEMU machine the timer (64-bit counter and compare) and the console are fixed wires. **There is no interrupt-controller programming model**: nothing says which interrupt is pending, how to mask one, or how to acknowledge it. The first design is proposed (`docs/encoding-work/best-of-breed-iommu-irq-atomics.md`); not decided. A per-core timer is open. | wires: built; controller: **open** | `timer`, `con-tx`, `mini-kernel` |
| Atomics and the memory model | Sequential consistency; `LL`/`SC`, `CAS`, `SWAP`, `XADD` and the others are single-copy atomic (7.4, 7.5). The grammar has the 22 words; **the executor does not implement them** (they trap as unimplemented); the operand layout is an open item; the owner accepted on 2026-11-19 to fix the layout and implement them with litmus tests before a second core exists. | decided; **approved to finish, not yet built** | `unimpl-cas`, `unimpl-xadd`, `unimpl-ll` check that they trap |
| IOMMU | One unit; a table of 512 device entries each pointing to a page of 128 entries; blocked at reset; no bypass; fail closed. | decided; built in the QEMU model with a PCI Express host bridge and a DMA test function; none in `sim64` | `iommu-blocked`, `iommu-refuse`, `iommu-map`, `iommu-stale`, `iommu-nested`, `iommu-enum`, `pcie-dmatest`; SEC-D02 to D05 |
| Hypervisor level | A separate state bit `H`; 20 system registers (128 to 147); `GENTER`; exits by a vector table; two translation stages with a 16-bit guest tag; seven virtual interrupt lines and a virtual timer. The level is to be **Arm VHE-style at once**: a kernel at the hypervisor level has its own translation and uses the ordinary registers. | the first design: decided and built (executor, `sim64` without stage 2, QEMU); VHE-style: **approved, not yet built** (2026-11-25) | `hv-off`, `hv-first`, `hv-stage2`, `hv-timer`, `hv-vtimer`, `hv-exits`, `hv-regs`, `hv-switch`, `hv-irq` |
| A device tree, a boot loader | seL4 reads memory and the timer from a device tree and needs a loader [Port]. The pdp64 has no boot ROM and no device tree; the memory map is provisional, and a platform map is approved. | **open** | none |
| An instruction-set model | None. The grammar fixes the encoding and can generate a decoder; the meaning is the C executor, which delegates memory, translation and interrupts to a host. **46 of the 286 base words are not implemented** in it (below). | **open** | none |
| A compiler | pcc (working; its C test programs run on the simulator and on QEMU, as recorded in `handoff.md`) and an LLVM back end (stages 1 to 2b); the LLVM back end is to become the standard compiler. Neither has been tried on seL4's source. The check instructions (run-time checks) will **not** be emitted in the verified kernel: "that's the whole point of proof" (the owner, 2026-11-25). | compilers: built; seL4 build: **not tried** (*not verified* that seL4 builds with either) | |

### 3.2 The 46 words the executor does not implement

`spec/facts/core.toml` marks 46 of the 286 base words as not implemented (`exec = "H_UNIMPL"`); the executor traps them as unimplemented instructions. Three are reserved system words, unassigned on purpose. The other 43 are: 22 atomic words (the 20 read-modify-write words, `LL` and `SC`, including the `_DB` forms); 18 cryptographic words (15 scalar AES and SHA words and 3 block words); and `utf8dec`, `utf8enc`, `mval`. No recorded decision leaves them out: it is a to-do, and on 2026-11-25 the owner decided "finish all". Only the 22 atomics bear on seL4 (and only for several cores).

### 3.3 What was added or changed because of seL4

The review of the pdp64 against seL4 is `docs/encoding-work/sel4-fit.md` (read 2026-11-19; its seL4 facts are re-checked in this paper, section 1). The owner's answers are errata 199 and 204. In order:

| change | origin | state |
|---|---|---|
| seL4 is a design target ("seL4 is already done for arm and riscv; yes we definitely will want seL4 for pdp64") | errata 199 | decided; **which configuration comes first is not decided** |
| Finish the atomics, with litmus tests, before a second core | review R2 | approved to finish, not built |
| A formal model of the kernel-relevant subset of the instruction set; the rule "nothing written by hand twice" may bend for it | review R4 | accepted, not started |
| Finish the 46 words | review R3, answer of 2026-11-25 | decided, not built |
| The system-call convention | review R6 | approved, not built, not in the manual |
| `KTBR` as system register 13, and "the kernel maps itself at its physical address first" | review R10 | approved, not built |
| `TLBIAS` | review R5 | approved 2026-11-25, not built |
| The hypervisor level has its own translation, guest tag at least 16 bits (the 256-ASID limit above is the reason a narrow tag hurts seL4 as a hypervisor) | review R8, then the VHE-style decision of 2026-11-25 | approved, not built |
| Block operations (`MCPY` and the others): for one observer a loop in ascending order with progress in the registers | review R9 | accepted, not written |
| The wording of manual 9.2.6 (no hidden instruction state, except in a vector block) | review R11 | done in the manual |
| Check instructions not emitted in the verified kernel | review item 14 | decided 2026-11-25 |
| Interrupt controller (smallest useful form) | review R1 | **not decided** |
| "The translation is never stale" as one architectural sentence | review R5b | proposed, not recorded as decided |

Features the review found already in the design and kept (`UA`, split root, sequential consistency, IOMMU blocked at reset, registers-only entry) were decided before the review (for example errata 43 for the guard and errata 71 for the split root); the review gave them a seL4 reading and did not cause them.

## 4. What the pdp64 does beyond other processors

*Each item has the same parts: the problem in plain words; what Arm, RISC-V and x86 do; what the pdp64 does; whether it closes the hole by construction; the evidence; the effect on seL4; the cost; and the status. What I say about other processors is "as checked" in the project's reviews, which quote their sources with the date read (2026-11-19) and which I did not re-read for this paper; it is not used for any conclusion about seL4. The security corpus is described in 4.10; its probes are named by their row (SEC-...). "Found" means the probe finds the hole in the current implementation.*

*The method that produced these items is the owner's principle (errata 198, 204): start from what other architectures do, change as little as possible so the hole closes by construction, and take a bold change where it is "a big juicy easy win", provided the compilers can follow.*

### 4.1 Exceptions that write only registers, and are precise

* **Problem.** An exception that pushes state on a stack can itself fault (the stack page may be missing), and a faulting instruction that has half changed a register cannot be restarted. The PDP-11 needed a journal register and a kernel routine to undo it (manual 6.4).
* **Other processors.** The review lists the same family of registers for Arm (`ELR`, `SPSR`, `ESR`, `FAR`) and RISC-V (`sepc`, `sstatus`, `scause`, `stval`); the statement that they are the same family is marked *not verified* there, only the registers' existence in QEMU's source is checked.
* **The pdp64.** Entry writes four registers and reads one word; priority 7 on every entry; auto-increment updates are held until the instruction retires; a block operation keeps its progress in registers.
* **By construction?** Entry cannot fault because it writes only registers; only the one-word vector fetch can fail, and that is a machine check by decision.
* **Evidence.** Tested; corpus SEC-R01 and SEC-B02 pass (`sec-restart-scalar`, `mmu-precise`, `sec-eva-stale`). Built and tested in the executor only; no silicon, so no claim about an out-of-order implementation.
* **Effect on seL4.** *In theory:* the entry code has fewer cases (one cannot fault in the middle), so the assumed assembly can be short. The count of instructions for entry and exit is **an estimate** ("4 to 5 entry, 4 exit", a paper estimate in `docs/kernel-pain-points.md`, against 45 to 70 for the RISC kernels it surveyed), not a measurement; the cost of the entry and of `RTI` themselves is not modelled anywhere in the repository.
* **Cost.** In the implementation, not the kernel: an out-of-order core needs a buffer that holds results until retirement (manual 6.4).

### 4.2 Sequentially consistent memory

* **Problem.** On a machine with several cores, if the hardware may reorder memory accesses, every proof about shared memory must reason about the reorderings, and the kernel needs barriers in the right places.
* **Other processors.** As checked in `docs/encoding-work/best-of-breed-iommu-irq-atomics.md`: "Armv8-A implements a weakly-ordered memory architecture" (Arm's guide); RISC-V's memory model is RVWMO, weak with explicit annotations; x86 is total store order: "Reads may be reordered with older writes to different locations but not with older writes to the same location." (Intel manual).
* **The pdp64.** "Memory is sequentially consistent: the result is as if all cores' accesses happened in one order that respects each program's order." (manual 7.5.1). A store buffer is allowed only if a load cannot pass an older store to another address (7.5.2). The one exception is the order of accesses inside a block operation (7.5.8).
* **By construction?** Yes, as a rule of the architecture; but see the evidence.
* **Evidence.** None built: the executor and the models run one core, and the litmus tests that would check an implementation (the four classic patterns) are owed. The rule is decided, not shown.
* **Effect on seL4.** None today: every verified build is single-core, and the roadmap's multicore proof is for multikernels [FAQ, Roadmap]. *In theory:* any future proof of a kernel whose cores share memory would not need a weak-memory model; this is the largest possible gain and lies in the future, for a proof that is not on seL4's roadmap as far as I read.
* **Cost.** On a core that speculates, loads that were wrongly ahead of stores must be replayed (7.7.3); the first implementations do not speculate (7.5.4). The cost on an out-of-order core is **not measured**.

### 4.3 Every illegal encoding is defined

* **Problem.** If an instruction word has no defined meaning, a formal model has a gap (the binary proof's tool "will reject any behaviour in the binary that is not exhibited by the semantic representation of the C program" [TOCS, as checked in `sel4-fit.md`]), and a wild jump can run something unplanned.
* **Other processors.** I did not read how Arm, RISC-V and x86 treat unassigned encodings. *Not verified.*
* **The pdp64.** The length of every instruction is fixed by its first 16 bits; every first word, sub-opcode, register-table index, reserved status-word bit, reserved page-table bit and reserved system-register number that no instruction uses is an illegal-instruction or page fault, never a no-op and never undefined (manual 9.1.5; reserved `HINT` numbers are defined no-ops). The words of the grammar that the executor does not yet implement trap as unimplemented instructions, not as nothing.
* **By construction?** Yes for the decoder: it is total. The manual (9.1.5, 3,278 illegal first words) and errata 160 (one in 65,536 after the renumbering) disagree on the count; the generated grammar and the executor are the authority, and a formal model must be generated from them, not from prose.
* **Evidence.** SEC-U01 (the whole table of first words is run through the executor), SEC-U02 (unimplemented words stop), SEC-U03 (reserved bits) pass. The reservation list for a model is the grammar.
* **Effect on seL4.** *In theory:* one case fewer in the binary proof (no "undefined instruction" to model). The model must still be written (section 6.3).
* **Cost.** None in gates measured; none in cycles.

### 4.4 The IOMMU blocked at reset, with no bypass; DMA cannot reach system registers

* **Problem.** A device that can write any memory (DMA) can overwrite the kernel. seL4's proof "assumes that DMA is off" [FAQ].
* **Other processors.** As checked in `best-of-breed-iommu-irq-atomics.md`: the RISC-V IOMMU's reset mode "must be either Off or Bare" and is "recommended to be Off", and "All IOMMUs must support Off and Bare mode" where Bare means "No translation or protection. All inbound memory accesses are passed through."; the Arm System MMU: "An implementation can reset this field to 1, in order to implement a default deny policy on reset", and a stream may bypass by configuration; Intel has an abort mode and a pass-through.
* **The pdp64.** One unit, **blocked at reset**, **no bypass mode at all** (a device that must see physical addresses gets a one-leaf table), reserved bits must be zero or the device is refused, a bad table fails closed (a refused read is answered with an error completion, a refused write is dropped and counted, never all ones, never a machine check), no translation requests in version 1 (manual 2.11). The owner's rule of 2026-11-25 adds that a device must not reach the system's register pages or another device's registers by default.
* **By construction?** The first part, yes: before the kernel writes a table, no device reaches memory. The second part, **not yet**: the corpus **finds** that in the current model a device whose table maps a device address onto the timer's compare register writes it by DMA (SEC-D01, `sec-dma-devspace`); the fix is approved, with a platform map, and not built.
* **Evidence.** Tested in QEMU: `iommu-blocked`, `iommu-refuse`, `iommu-map`, `iommu-stale`, `iommu-nested`, `pcie-dmatest`; SEC-D02 to D05 pass; SEC-D01 found. Not testable in the model: requests in flight when a mapping is withdrawn (the model's bus is synchronous). No gate count of the unit exists.
* **Effect on seL4.** *In theory:* "DMA is off" is true at boot by hardware, and it stays true for every device the kernel has not mapped. Once a driver maps a device, DMA is on, and seL4 has no verified model of any IOMMU on any architecture [Cfg]: the assumption comes back for that device. So this is a safer default and a smaller thing to trust at boot, not a smaller proof, and a proof of seL4's use of the unit would be a new piece of work of unknown size.
* **Cost.** The kernel must write a table before a DMA device works; the hypervisor-visible second level costs a virtual unit (decided).

### 4.5 The kernel's own root, the tag, and rules that keep translations from going stale

* **Problem.** A TLB entry can outlive the page-table entry it came from. If it does, a program can still reach a page the kernel took away: the stale-translation bug. seL4's proof leaves the TLB outside its model and assumes correct flushing in assembly [Assume, TOCS].
* **Other processors.** As checked in `docs/encoding-work/closing-holes-by-construction.md` (sources read 2026-11-19): RISC-V leaves it to software: "SFENCE.VMA is also used by higher privilege levels to synchronize page table writes and the address translation hardware."; AMD's control block for entering a guest has a TLB-control field that the hypervisor sets (a switch, so forgetting is still possible); Arm's Linux KVM bumps a software generation counter of guest identifiers when they run out. A research design (HATRIC, ISCA 2017) tags each cached translation with where it came from so that cache coherence kills it; I read only its abstract, so *not verified* beyond that. **As far as the review read, every product leaves it to software; none closes it by construction.**
* **The pdp64.** (a) The address space is split in two: the kernel's half is walked from a separate root and user mode never walks it, so "the constant window in every address space" is a hardware fact (manual 6.9.1; approved, not built). (b) TLB entries carry the address-space number, the half, and the guest tag; stated rules discard entries at the writes of `MMUCTL`, `PTBR`, `ASID` and at reset; the walker never writes. (c) `TLBIAS` (approved, not built). (d) For guests, the owner asked for a rule that the hypervisor cannot forget. Two designs are studied: an **arena**, where the hypervisor keeps its second-stage tables in one pool the hardware knows, and a store into the pool, or any write of a guest's translation registers, makes the next guest entry discard that guest's translations (the walker refuses a table outside the pool); and a **directory** of pages that were walked as tables, any store into which discards the entries made from it. Both close the hole fully for second-stage tables; the directory also covers the kernel's own tables and restricts nothing; the arena limits the hypervisor's allocator and covers only stage 2.
* **By construction?** Yes for both designs, **when built**. The current model does not have either: a guest reset that only rewrites stage 2 and enters the guest again leaves the guest's cached translations (SEC-B14, `sec-hv-reset-inplace`, found; writing `MMUCTL` as 0 first discards them and passes, SEC-B13).
* **Evidence.** *Measured, gates* (`closing-holes-by-construction.md`, synthesis count): the arena, about 1,300 gates for the core (0.5% of the 220,000 to 310,000 of a scalar core), of which 1,165 were counted (the two range comparators and one buffer's clear input) and the rest estimated; the directory, 6,030 gates (8 entries, one store port) to 28,757 (32 entries, two ports) per core; a 16-bit guest tag in a 32-entry buffer, +8,799. *Measured, table reads:* on the repository's four hypervisor programs, the plain safe rule "discard at every guest entry" adds 16.0 table reads per entry on the test with 79 entries (about 48 cycles at an *estimated* 3 cycles a read), which about doubles that test's round trip; the arena adds none on all four. The cycle price of a table read is an assumption, and the programs are tests, not workloads. SEC-B10, B11, B12 pass; SEC-M09 not applicable (not built).
* **Effect on seL4.** *In theory:* the weakest assumption of the seL4 proof could become a property that an implementation can be tested for, instead of an argument made "only informally": the kernel window (split root), the tag (no stale entries by rule), the invalidate by ASID (what the machine interface lists). Whether that shrinks the proof depends on whether a pdp64 proof's machine model would include these rules; today's model leaves the TLB unspecified.
* **Cost.** The gates above; the arena's allocator limit; the directory's false discards when it is full; a new instruction.

### 4.6 No hidden state that can leak: resume, with discard rules

* **Problem.** The pdp64's vector blocks keep running sums in hidden registers. If an interrupt stops a block, either the sums are lost (the block restarts and a long block may never finish) or they are kept in state that another program could see or inherit. Hidden state is also something a formal model must contain. (The kernel does not need vector blocks; this matters to the user programs and to the model.)
* **Other processors.** As checked in `docs/encoding-work/best-of-breed-vector.md` and `vector-resume-design.md`: RISC-V keeps the resume position in a register and has the operating system save vector state only when a status field says it changed; x86 keeps the progress of long instructions in ordinary registers; Arm's matrix extension clears its state at a mode edge. None keeps progress in hidden state the operating system cannot save.
* **The pdp64.** Decided: a block **resumes in place** where possible. A small record (the block's address, a tag naming the context, a one-use token, the entry and current values of up to four registers) is written when an exception stops a block; the block resumes only if the return carries the token, goes to the same address, in the same context, with the same registers. **Anything else discards the sums**: any other vector instruction, any write of `ASID`, `PTBR`, `MMUCTL` or `GTBR`, an entry into another guest, a cache invalidate, a failed check, reset. So resume only ever makes things faster; it never changes an answer, and one context cannot learn whether another used the vector unit. The answer given on 2026-11-25 to the owner's question is that each guest should have its own key for the token, so that counts of suspensions do not leak; that is not yet a recorded decision. A block is limited to 256 strips; a naming made by `VCLR` is valid only inside the block (approved 2026-11-25). Also built already: every exception entry and return clears the naming of the vector accumulators.
* **By construction?** The rules are written so that nothing crosses a context; they are **approved, not built**. The current implementation has three holes of the vector block, all found by the corpus (SEC-V01, V02, V03: an exception between `VCLR` and `VEC` changes the result; an accumulator block that updates memory in place repeats stores after a fault, 4 of 8 lanes came out 2 instead of 1; a record is found by address, not by context).
* **Evidence.** *Measured in a scratch copy of the simulator, not in the repository:* with page faults a restart multiplies a block's time by 2 to 25 (and a long dot product by 256); resume brings it to 1.01 to 1.02, with an *assumed* cost of 8 cycles per interruption; under a timer tick every 10,000 cycles a restart never finishes a long block and resume costs 0.09%. *Synthesised:* resume adds 7,537 gates (2.7% of the vector unit's 278,959); today's hidden record is 1,544. SEC-B06 and B08 pass.
* **Effect on seL4.** None for a kernel that never executes a vector instruction. *In theory:* the model of a pdp64 would need the record, or a build rule that the verified kernel contains no vector block (a natural rule, like the rule for the check instructions; **not decided**).
* **Cost.** The gates above; an interrupted block cannot survive a switch to another program (it restarts).

### 4.7 The clear of registers on a return

* **Problem.** A kernel uses registers as scratch. If it returns to a program without overwriting them, the program reads kernel pointers (which defeats address randomisation) or fragments of secrets. On the pdp64 only the stack pointer and `DP` are banked per mode, so this is a real hole in a careless or compiled kernel.
* **Other processors.** As checked in the study: OpenBSD's amd64 return path reloads the registers from the trap frame (source read 2026-11-19); the PDP-11/45 had a second register set (Wikipedia, read 2026-11-19). The study found no processor whose hardware does this by construction.
* **The pdp64.** `RTI #mask`: a return that carries a mask of the registers to keep; when it goes to a less privileged mode, hardware clears the others in the same cycle. There is no return without a mask. A kernel that returns with all ones makes an explicit, visible claim; one that forgets a register gives the program a zero where it needed a value, which fails at once and not secretly. Approved 2026-11-25; the owner leans to "whichever is most efficient in compiled code, fewest instructions overall", to be benchmarked.
* **By construction?** Yes, when built. **The current implementation has the hole** (SEC-B04, `sec-regs-carry`, found).
* **Evidence.** *Measured, gates:* +2,112 (7.7% of a register file counted in the same coding style as 27,593); a lazy variant +1,147. *Measured, instructions* on an 8-instruction null system call (`sim64 -K -t`): the same safety by software costs +5 instructions (clear `R1` to `R5`), +8, or +24 (clear every caller-saved register), against +2 for save and restore with `PUSHM`/`POPM`. Cycles are estimated one per instruction.
* **Effect on seL4.** *In theory:* "the kernel returns to the program with only the registers it names" moves from assumed assembly to a hardware rule. For seL4 the gain may be small: seL4 restores the whole user context of the thread it returns to (my reading of its design; *not verified* in its code), so the rule protects a careless kernel more than seL4.
* **Cost.** Four bytes at each return site; the gates above.

### 4.8 Floating-point flags cleared on a context write

* **Problem.** The five sticky flags of IEEE 754 arithmetic (invalid operation, divide by zero, overflow, underflow, inexact) stay set until cleared; if they carry from one process to the next, one process sees another's flags: a small leak and a wrong error report.
* **Other processors.** Not read. *Not verified.*
* **The pdp64.** They are cleared when `ASID`, `PTBR` or the guest register is written; the kernel restores the incoming process's flags, as it already does. Approved 2026-11-25.
* **By construction?** Yes across address spaces (threads of one process share flags). **The current implementation has the hole** (SEC-B05, found).
* **Evidence.** *Measured:* +5 to +7 gates, no cycles.
* **Effect on seL4.** Only for configurations with floating point (AArch64 and x64 are listed with it, RISC-V is not [Cfg]). *In theory:* one register fewer that a context switch must handle correctly.
* **Cost.** Seven gates.

### 4.9 The hypervisor design

* **Problem.** A hypervisor must make every instruction that reveals or changes the real machine either exit to it or be harmless, and must keep a guest's two stages of translation and its tag correct.
* **Other processors.** As checked in `best-of-breed-mmu-virt.md`: Arm has a separate level (EL2) with its own registers and, with the VHE feature, lets a host kernel run there ("E2H: Controls whether VHE is enabled."); across two translation stages, "The MMU does this by selecting the stage that is more restrictive."; RISC-V has a hypervisor-extended supervisor mode with duplicated guest registers; x86 has a root mode (its second stage, EPT, was not verified).
* **The pdp64.** A state bit `H` outside the status word (so a guest cannot see it); a strap `HVE` (with it clear the machine is exactly the machine without a hypervisor, checked by the test `hv-off`); a trap-control register, an exit-reason register and exception registers of the hypervisor's own; a table of exits; two stages with a 16-bit guest tag; seven virtual interrupt lines and a virtual timer; a 16-bit virtual core number (`MFCPUID` is privileged). The audit of sensitive instructions (14 decisions, accepted) is the reason each instruction exits or is harmless. Approved 2026-11-25: the level is VHE-style at once, "so kernels don't need to be split in two"; the memory type of the two stages: the stricter wins.
* **By construction?** The audit covers instruction by instruction; a corpus probe exists for each class (SEC-P05 to P08, P11, B03, B07, M06, M07 pass). Nested hypervisors are not supported in version 1 by decision; software nesting would need almost no new gates (one trap-control bit; an *estimate* of 45 to 105 person-days of work).
* **Evidence.** Built and tested in the executor, `sim64` (without stage 2) and QEMU (with stage 2): `hv-off`, `hv-first`, `hv-stage2`, `hv-timer`, `hv-vtimer`, `hv-exits`, `hv-regs`, `hv-switch`, `hv-irq`. *Estimate:* about 600 bits of new state per core. The cost of an exit and an entry has **no measurement**; the studies assume 20 cycles each.
* **Effect on seL4.** None for the first configuration. seL4's verified hypervisor configurations are the two Arm ones, with the kernel itself in the hypervisor mode [Cfg]; a VHE-style pdp64 level is where an seL4-as-hypervisor port would run its kernel. *In theory:* with `HVE` clear none of this enters the model of the non-hypervisor configuration beyond instructions that are illegal. The 16-bit tag lifts the 256-address-space limit that seL4's Arm hypervisor configuration has with 8-bit tags [Manual].
* **Cost.** The state above; a 16-bit tag costs +8,799 gates per 32-entry TLB (measured); the exits and the world switch are software the hypervisor writes.

### 4.10 The security corpus: a way to test an implementation for the holes

* **What it is.** 68 holes and information bleeds indexed in `docs/security-corpus.md`; for each, a small assembly program (a *probe*) that exits 0 if the implementation does not have the hole and otherwise with the number of the first failed check, and a control that shows the probe can fail. As recorded on 2026-11-19: 42 pass, 7 are found, 19 are not applicable in the model (timing, caches, speculation, power, and the features not built). Each passing probe was run against a scratch copy of the model broken the way the hole would break it, and failed: the corpus records that.
* **Run on 2026-11-25** for this paper (`tools/check-sec.sh`): the same seven holes are found, none fixed, none broken: the registers after a return (SEC-B04), the floating-point flags (SEC-B05), the three vector-block holes (SEC-V01 to V03), DMA onto a device register (SEC-D01), and the guest reset in place (SEC-B14). The owner decided on 2026-11-25 that all seven are to be fixed.
* **Other processors.** I know of no counterpart; I did not search. *Not verified.*
* **Effect on seL4.** None on the proof. *In theory:* seL4's proof assumes the hardware "working as the formal model predicts" [Assume]; an implementation of the architecture (an FPGA, a core) can be run against the corpus, so the assumption about holes becomes testable for the classes the corpus covers. Passing is a necessary check, not a proof.
* **Cost.** The probes are small programs; running them needs only the simulators.

## 5. Faster: what is measured and what is not

The owner's rule is that nothing is called faster unless it is measured. The measured facts that bear on seL4, all small:

* **A null system call** (user program, `TRAP`, a handler of 8 instructions, `RTI`) is 8 instructions in the handler (a count on `sim64 -K -t`). The same handler with the registers cleared by software costs 13, 16 or 32 instructions (4.7). This is a toy handler, not seL4. The *entry and exit themselves* are not modelled: `sim64`'s timing model refuses kernel mode, and the repository has no cycle count for entering an exception or for `RTI`.
* **The estimate** that entry costs "4 to 5 instructions" and exit 4 (against 45 to 70 on the RISC kernels surveyed) is a paper estimate in `docs/kernel-pain-points.md`. It is **not** a measurement and is not used for any claim here.
* **The hypervisor:** table reads per guest entry for three rules, counted on four test programs (4.5); the cost of an exit is an assumption.
* **Vector blocks:** restart against resume under faults and ticks (4.6), measured in a scratch simulator with a model of the vector unit; not seL4.
* **Gates:** the figures in section 4; all counted with one synthesis method on small models, each against a baseline written in the same style. No core has been synthesised.

**Not measured, and so not claimed:** any seL4 benchmark; the IPC fast path; context switch; interrupt latency; TLB miss cost; the cost of `TLBIAS` against flushing everything; the size of seL4 compiled for the pdp64; and anything about silicon. For scale only: the TOCS paper's Table I lists the seL4 fast path at 220 to 234 cycles at `-O2` on a 532 MHz ARM1136 [TOCS]. There is no pdp64 number to set beside it.

## 6. The proof

### 6.1 What is known

* The seL4 proof is large (480,000 lines of Isabelle in 2014) and costly (about 20 person-years, 11 of them seL4-specific) [TOCS]. One interface change cost 17% of the original effort [TOCS].
* The TOCS paper contains **no statement** of the cost of a new architecture, and no document I read describes a port to a new instruction-set architecture (section 2).
* **The share of the proof that depends on the architecture is not known.** No source gives it. So how much an instruction-set design could save is unknown. Everything below is *in theory*.

### 6.2 What could shrink what the proof must assume or trust (*in theory*)

For each, the seL4 assumption (section 1.4), the pdp64 mechanism, what would have to be true, and the state.

| seL4 assumption | the pdp64 mechanism | what must be true for the saving | state |
|---|---|---|---|
| Virtual memory: an informal argument about the kernel window | A separate kernel root that user mode never walks; entries tagged by half; no stale entry by rule or by the arena or directory | The rules are in a formal model of the machine, and the hardware obeys them (the corpus can test the second) | decided; root and arena or directory approved or studied, **not built** |
| TLB and cache management correct in assembly | A tag; flush rules; read-only walker; coherent data caches; `TLBIAS` | As above; the model includes the tag and rules | partly built (the QEMU model); `TLBIAS` not built |
| "DMA is off" | IOMMU blocked at reset, no bypass | A model of the unit would be needed to go beyond "off at boot"; it is a new proof | built in QEMU; the register-page rule not built |
| The 340-line entry and exit assembly is correct | Registers-only entry; `RTI #mask`; banked stack pointer and `DP` | The pdp64's assembly is shorter; **its length is unknown** until written | `RTI #mask` approved, not built |
| One core only | Sequentially consistent memory | A multicore proof exists to use it; none is scheduled for the big-lock kernel | decided; no multicore model |
| The instruction-set model (binary proof) has gaps for unspecified behaviour | Every illegal encoding defined; no partial-register writes; precise exceptions | A model is written | decided; the model is **not started** |

These reduce what must be **trusted or assumed**. None of them is shown to reduce the **size** of the proof. A smaller trusted base is not a smaller proof: the proof's machine model would have to be *larger* to include a rule that is now an assumption outside the model, and its size cost is unknown.

### 6.3 What could make a proof smaller or easier (*in theory*) and what could make it larger

*Smaller or easier, in theory:*

* **Reuse.** The page-table tree has the shape of the RISC-V 64-bit configuration that seL4 has verified (three levels of nine bits over 4 KB pages); the abstract specification's address-space objects might map directly (my inference; *not verified*). Reuse shortens the work; it does not shrink the proof.
* **A short machine layer.** Entry writes only registers and the return can clear by construction; there may be fewer cases in the machine-interface specification.
* **Fewer cases in the binary proof** from a total decoder and no hidden scalar state.
* **A build with nothing the proof does not cover:** no vector blocks and no check instructions (decided for the checks), no floating point at first, one core, no hypervisor, no IOMMU. This is the same shape as seL4's verified RISC-V 64-bit configuration [Cfg, Build].

*Larger, or extra cost:*

* **The formal model of the instruction set.** seL4's binary proof relies on a machine-readable model validated against real hardware [TOCS]. The pdp64 has none: the executor is a C program that delegates memory, translation and interrupts to a host, and 46 words are not implemented. Its translation walker is in the QEMU model only. A formal model of the kernel-relevant subset (decoder generated from the grammar, semantics written in a specification language such as Sail, tested against the executor) was accepted 2026-11-19 and not started. It is the largest extra, and there is **no validation against silicon**, which is what seL4's Arm model had; and the two simulators share one executor source, so they are not independent witnesses. The cost is **not estimated** here.
* **The machine layer and the architecture-specific proofs.** A new set of machine-interface operations with their specifications (section 6.4), the architecture-specific parts of the specification and of the C-level proof (address spaces, ASID pools, interrupts), written by someone expert in the seL4 proofs. I infer (it is not stated in the sources) that this is a large part of a port; the only effort figures are the 2014 ones.
* **The toolchain.** The checking tool was built around GCC output [TOCS, as checked in `sel4-fit.md`]. A pdp64 build uses pcc or LLVM; whether the tool copes with their output is **not known**.
* **Features that enter the model if a configuration uses them:** the interrupt controller (the machine interface needs `getActiveIRQ` and `maskInterrupt`), the hypervisor level, the IOMMU, hidden vector state.
* **A model that is a moving target:** the form counts of the manual and the grammar disagree; a formal model must be generated from the grammar.

### 6.4 What a pdp64 port would need (the machine interface)

seL4's machine interface on Arm [TOCS] and my reading of the pdp64 counterpart. This mapping is my analysis, not seL4's.

| seL4 operation | pdp64 counterpart (my reading) | state |
|---|---|---|
| `configureTimer`, `resetTimer` | the timer's compare register | wires built in QEMU; per-core form open |
| `setCurrentPD` | write `PTBR`, then `ISYNC` | built |
| `setHardwareASID` | write `ASID` | built |
| `invalidateTLB` | `TLBIA` | built |
| `invalidateHWASID` | `TLBIAS` | approved, not built |
| `invalidateMVA` | `TLBI` (current space); another space's page needs `TLBIAS`-like form | built in part |
| cache clean and invalidate | not needed for data (coherent, DMA uncached); `ICINV`, `ICINVA`, `ISYNC` | decided |
| `clearExMonitor` | clear of the `LL` reservation at exception entry and return (decided) | `LL` not built |
| `getIFSR`, `getDFSR`, `getFAR` | `ECAUSE`, `EVA` | built |
| `getActiveIRQ`, `maskInterrupt` | the interrupt controller | **open** |

A port needs, in order: the formal model of the kernel-relevant subset; the executor made complete for that subset; the machine-interface specification and its proof for the pdp64; the architecture-specific specification and C-level proof; an seL4 source tree for the pdp64 (boot, interrupt controller driver, timer, device tree); the toolchain; and, for binary correctness, the validation tool adapted to the pdp64's compilers.

## 7. What is left to do before seL4 can be built for the pdp64

With the owner's decisions so far. None of this is scheduled by this paper.

1. **The configuration to start with.** The recommendation of the review: one core, kernel in the plain kernel mode, no hypervisor, no IOMMU, no floating point, no fast path, which is the shape of seL4's verified RISC-V configuration [Cfg]. **The owner has not decided which configuration comes first** (errata 199).
2. **The interrupt controller.** Open. The review's proposal: a per-core interrupt page, a read-only "highest pending" register readable at priority 7, per-vector mask and acknowledge, an inter-core interrupt, a per-core timer. Not decided.
3. **The atomics and the other 43 words.** Approved ("finish them"); not built. The litmus tests come before a second core.
4. **The executor made total** for the kernel-relevant subset, with the translation walk in the shared core (it is in the QEMU model only) and bit-exact floating point (the executor uses the host's arithmetic). Recommended; not started.
5. **The formal model** (section 6.3). Accepted; not started.
6. **The approved changes**: the system-call convention, `KTBR`, `TLBIAS`, `RTI #mask`, the floating-point flag clear, the stricter memory type, the platform map, resume with the 256-strip bound, the VHE-style hypervisor level, and fixing the seven holes of the corpus. All approved on 2026-11-19 or 2026-11-25; **none is built**; the manual is to be changed with them.
7. **The toolchain** on seL4's source: an LLVM build, with pcc as a cross-check, at `-O2`, function cloning off, no built-in count-leading-zeros, no floating point, no checks; and a look at what the compiler emits for block operations. Not tried.
8. **Boot and platform**: a device tree and loader convention, the memory map (provisional today).
9. **Validation**: nothing is validated against silicon; the corpus tests the architecture's rules, not a chip.

## 8. References, and what could not be checked

### 8.1 Sources read, with the date

All read on **2026-11-25** with a plain HTTP client (generic user agent), one page at a time and at least ten seconds apart; no captcha and no block was met. Each quoted sentence in sections 1 to 6 was checked mechanically against the text of the page (a line break or a hyphen at a line end in a PDF is the only difference allowed).

| label | address |
|---|---|
| [Cfg] | https://docs.sel4.systems/projects/sel4/verified-configurations.html |
| [FAQ] | https://sel4.systems/About/FAQ.html |
| [Assume] | https://sel4.systems/Verification/assumptions.html |
| [Roadmap] | https://sel4.systems/roadmap.html |
| [News] | https://sel4.systems/news/2026.html |
| [TOCS] | Klein et al., "Comprehensive Formal Verification of an OS Microkernel", ACM Transactions on Computer Systems 32(1), 2014: https://trustworthy.systems/publications/nicta_full_text/7371.pdf |
| [Manual] | the seL4 Reference Manual, version 17.0.0, 30 October 2026: https://sel4.systems/Info/Docs/seL4-manual-latest.pdf |
| [Port] | https://docs.sel4.systems/projects/sel4/porting.html |
| [Build] | the seL4 sources, master branch: `configs/include/RISCV64_verified_include.cmake` and `AARCH64_verified_include.cmake`; `include/arch/riscv/arch/machine/registerset.h`; `src/arch/riscv/machine/registerset.c`; `libsel4/arch_include/riscv/sel4/arch/syscalls.h` (all under https://raw.githubusercontent.com/seL4/seL4/master/) |

Facts about other processors (Arm, RISC-V, x86, the IOMMUs, KVM, OpenBSD, HATRIC) are "as checked" in these project documents, each of which names its source and the date read (2026-11-19): `docs/encoding-work/best-of-breed-mmu-virt.md`, `best-of-breed-iommu-irq-atomics.md`, `best-of-breed-vector.md`, `closing-holes-by-construction.md`, `vector-resume-design.md`. They were **not re-read** for this paper. The seL4 review is `docs/encoding-work/sel4-fit.md`.

The project's own sources: the manual (`docs/manual-src/`, chapters 2, 6, 7, 9, appendices D and J), the errata (`docs/errata.md`, entries 159, 178 and 181 to 204), `docs/implementation-status.md`, the security corpus (`docs/security-corpus.md`, run on 2026-11-25), `docs/owner-questions.md`, `docs/encoding-work/hypervisor-design.md`, `iommu-proposals.md`, `nested-virtualization-estimate.md`, `sensitive-instructions-audit.md`, the benchmark record (`docs/encoding-work/bench/`), `handoff.md`, the grammar (`spec/`) and facts files (`spec/facts/core.toml`), and the executor (`common/`).

### 8.2 What changed from the earlier review, on re-reading

* The verified-configurations page lists the AArch64 configuration as running the kernel in EL2 with the hypervisor mode, and the FAQ now says binary-code proofs exist for 64-bit RISC-V. The earlier review (2026-11-19) had left the RISC-V binary proof unresolved; the FAQ settles it.
* The review counted 48 unimplemented words on 2026-11-19; the facts file now marks 46 (counted again today). Three reserved words have become `stua`, `clua` and `genter` since; I did not trace the remaining difference of one.

### 8.3 Not verified, and kept out of the conclusions

* Whether seL4's source builds with pcc or with clang for the pdp64.
* Whether seL4's kernel accesses user memory, or maps pages with the accessed and dirty bits set, in the way this paper assumes it could. I did not read that code.
* Whether seL4 restores the whole user context of the thread it returns to (4.7).
* Which language a validated model of the pdp64 for seL4's binary tool would use; seL4's own models for Arm and RISC-V are in other tools (the white paper names a RISC-V model in L3: as checked in `sel4-fit.md`, not re-read today), and whether a Sail model could feed the tool was not found in any source.
* How Arm, RISC-V and x86 treat unassigned encodings and floating-point flags; whether a counterpart of the corpus exists.
* The statement that Arm and RISC-V exception entry is "the same family" as the pdp64's (the review marks it unverified).
* The conflict between [Cfg] ("no fast path" for RISC-V) and the RISC-V build file (`KernelFastpath` ON); and between [Cfg] (no binary correctness listed for RISC-V) and [FAQ].
* The current size of seL4's proofs; the share that depends on the architecture; the cost of a port to a new instruction-set architecture.
* The ARM build files were read on 2026-11-19, not on 2026-11-25; the one-core setting was re-checked today for RISC-V and AArch64 only.
* Every pdp64 gate count is from a synthesis of a small model written for a study, not from a built core; a cycle count for an exit, an entry or a table read is an assumption. No core has been synthesised and no silicon exists.

### 8.4 The claims marked *in theory*

Each of these is argued from the design, not shown: that the cache part of the assumption list shrinks to the instruction cache (3.1); that registers-only entry shortens the assumed assembly (4.1); that sequential consistency removes weak-memory reasoning from a future multicore proof (4.2); that a total decoder removes a case from the binary proof (4.3); that "DMA is off" is true at boot by hardware (4.4); that the weakest virtual-memory assumption could become a testable property (4.5); that the model of a pdp64 would need the vector record or a build rule (4.6); that `RTI #mask` moves a duty from assembly to hardware (4.7); that the hypervisor features do not enter the model with the strap clear (4.9); that the corpus makes the hole assumption testable (4.10); and every row of section 6.2 and the "smaller or easier" list of 6.3.
