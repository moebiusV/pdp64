# The design of the hypervisor mode

*For the owner to review. Nothing in this document changes the manual, the grammar, the tools, the executor, the QEMU model or any test. Every name, number and field width below is a **proposal** and says so; the owner's earlier decisions (manual 6.14.1 to 6.14.14, errata 181 and 186, the IOMMU statements 2.11.1 to 2.11.11) are the input and are not argued again. A fact is marked **verified: FILE** when I read it in that file, and **unverified: general knowledge** when it is from memory. Files of the repository are named from its top; files of the QEMU v11.1.2 source are named from the top of that tree (`target/arm/...`, `target/riscv/...`, `target/i386/...`). Costs are qualitative; a size that appears is arithmetic from a proposal, not a measurement, and is labelled an estimate.*

## 0. How to read this, and the words used

The decisions of 6.14 fix the shape: a hypervisor mode above the kernel, kept outside the status word; a trap-control register and an exit-reason register; exception registers of the hypervisor's own; two-stage translation with a second root and a guest tag; virtual interrupts and a virtual timer offset in hardware; a hypercall that is a range of `TRAP #n`. They do not say which registers exist, what numbers they have, what is written when, or which instructions are new. This document says that, section by section, with options, and ends (section 10) with a numbered list of decisions, each with a recommendation, to be answered "accept / change / not decided".

Words, defined at first use and collected here.

* **Guest, host, hypervisor.** A **guest** is a whole operating system running as if it owned the machine; the **hypervisor** is the small kernel that runs the guests; the **host** is the real machine (6.14).
* **Exit.** The guest stops and the hypervisor runs, because something happened that the hypervisor must see (a physical interrupt, a trapped instruction, a fault in the second stage). **Entry** is the opposite. A **world switch** is an exit followed by the entry of another guest.
* **Stage 1, stage 2.** Stage 1 is the guest's own page tables (guest-virtual address to **guest-physical address**, the address the guest thinks is memory). Stage 2 is the hypervisor's tables (guest-physical to real physical address) (6.14.4).
* **Translation buffer (TLB).** The processor's cache of translations (6.8). **Guest tag**: a number kept with each entry that says which guest made it, so one guest's entries can be removed without the rest. (ARM calls it VMID, RISC-V's second stage has a similar number, x86 has VPID; see section 8.)
* **Trap-control register.** A register that says which events a guest's execution sends to the hypervisor.
* **Abort, trap, interrupt** have the meaning of 6.3: an **abort** stops an instruction before it changes anything; a **trap** is an instruction that succeeds and then enters; an **interrupt** is taken between instructions.
* **H** is the name I use for the new state bit of 6.14.3 (section 1).

Files that were read for this document: manual 6.2, 6.3, 6.5, 6.8, 6.12 to 6.14 (`docs/manual-src/06-kernel.md`), 2.11 (`docs/manual-src/02-*.md`), 7.10, `docs/encoding-work/sensitive-instructions-audit.md` and `iommu-proposals.md`, errata 178, 181, 185, 186, 188 and 190 (`docs/errata.md`), `spec/grammars.d/40-mn-system.hbnf`, `41-sysreg.hbnf`, `50-system-v1.hbnf`, `20-enc-forms.hbnf`, `spec/pdp64/tables.md`, `spec/facts/core.toml`, `common/pdp64exec.c` and `.h`, and in `qemu/target-pdp64/` the files `cpu.h`, `cpu.c`, `mmu.c`, and in `qemu/hw-pdp64/` `timer.c`; and in the QEMU source the ARM, RISC-V and x86 files named in section 8.

## 1. The state

### 1.1 How the hypervisor mode is represented

**What is decided.** 6.14.3: the hypervisor mode is a separate state bit, not a value of the current-mode field; the reserved mode value 2 stays reserved; `MFPS`, `MTPS`, `RTI` and `EPSW` do not change; a guest cannot see the mode.

**What I propose.**

* **One state bit, `H`**, inside the core, not in the status word and not in any register a program can read. `H = 1`: the hypervisor is running. `H = 0`: anything else (a guest, or, on a machine with no hypervisor, the ordinary kernel and its programs).
* **A machine configuration bit, `HVE` (hypervisor present).** It is not a register and no program can change it; it is a property of the machine (a strap on a chip, a machine option in QEMU, section 6). `HVE = 0` is the machine as it is today: `H` is always 0, every hypervisor register and the new instruction are illegal instructions, nothing below applies, and no existing program or test changes. `HVE = 1`: `H` is 1 at reset, so the first software to run is the hypervisor (or firmware that starts it); it runs a guest by the instruction of section 4. A native operating system on an `HVE = 1` machine is simply a guest.
* **How a guest-running core and a hypervisor-running core are told apart:** by `H`, which only the hardware changes: an exit sets it, the entry instruction clears it. Nothing else can.
* **What `MFPS`, `RTI` and `EPSW` see:** the same fields as today, with the same meaning. In a guest, the status word is the guest's own; `RTI` in a guest loads the guest's `EPC` and `EPSW` and stays a guest instruction; `EPSW` holds only a guest status word. The hypervisor's saved status word is in `HEPSW` (1.4), which has the status-word layout and the same reserved-mode check (a value with mode 2 is an illegal instruction, as 6.2 says for the status word).

**Options and the case for and against.**

* *Option A (recommended): a separate state bit, `H = 1` above kernel level, with its own exception registers (the owner's decision, made concrete).* For: it is what 6.14.3 says; the guest's exception registers are never overwritten by an exit (the reason decision 10 of the audit gave); nothing in the status word changes. Against: a second set of exception registers and a banked stack pointer (1.4, 1.12); the hypervisor cannot be written as an ordinary kernel with a few extra registers.
* *Option B: the hypervisor is the ordinary kernel with a "guest running" bit `V` (RISC-V's way: its HS-mode is the supervisor mode with virtualization off, and the guest is `V = 1`).* For: the host operating system and the hypervisor are the same program, so a type-2 hypervisor (an ordinary kernel that also runs guests) needs no mode change; no new set of exception registers, because the hardware swaps the registers by `V`. Against: either the 13 system registers are duplicated in hardware, one set for `V = 0` and one for `V = 1` (RISC-V keeps separate `vsepc`, `vsstatus` and so on; **verified: `target/riscv/cpu.h`**, which has `vsstatus`, and `tcg/csr.c`, which has `hvip`, `htimedelta`), or the hypervisor, being a kernel, overwrites the guest's `EPC` at its own first exception. It also contradicts the owner's decision (hypervisor mode above the kernel, own registers). I do not recommend it; it is listed because it is the main precedent that differs.
* *Option C: put the hypervisor mode in the status word (mode value 2).* Rejected by the owner's decision, and by the audit: `MFPS` would show it.

**Precedent.** ARM has a separate level above the kernel with its own `ELR_EL2`, `SPSR_EL2`, `ESR_EL2` and `HPFAR_EL2` (**verified: `target/arm/helper.c`**, register definitions at the lines of `ELR_EL2`, `SPSR_EL2`, `ESR_EL2`, `HPFAR_EL2`; `target/arm/cpu.h` has `elr_el[4]`, `hpfar_el2`): Option A is that design. RISC-V: Option B (**verified** as above). x86 uses a separate "root" and "non-root" state with a control structure in memory (VMX) or a control block (SVM): **verified for SVM: `target/i386/tcg/system/svm_helper.c`** has `helper_vmrun`, which reads the guest's `asid` and `nested_cr3` from the control block in memory; the VMX details are **unverified: general knowledge** (QEMU's TCG does not implement VMX; `target/i386/cpu.h` has only the capability bits `MSR_VMX_EPT_INVVPID` and the like).

**Cost.** One flip-flop for `H`, one configuration bit, a few gates on the exception-entry path to choose the register set. No change in the status word, so no change in `MFPS`, `MTPS`, `RTI`, the executor's `PSW_VALID` or the generated status-word constants.

### 1.2 What `H = 1` means for translation, exceptions and interrupts

Four rules, each a place the decisions did not reach (decision 2 of section 10).

1. **The hypervisor runs untranslated in version 1.** At `H = 1` every address is physical, whatever `MMUCTL`, `PTBR` and `GTBR` hold. *For:* the hypervisor is small and has no user programs (6.14.10); it needs no third set of translation registers; it cannot be hurt by a guest-controlled `MMUCTL`. *Against:* it cannot be protected from its own stray pointers by translation, and a hypervisor that also runs ordinary programs (the KVM arrangement) cannot be built. *Way out later:* a hypervisor translation base is one more register in the block of 1.3 and a third translation regime; nothing in the rest of this design prevents it.
2. **Exceptions and interrupts taken at `H = 1`** (the hypervisor's own faults, a physical interrupt, a `TRAP` it executes) use the hypervisor's registers and vector base (`HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HVBR`), exactly as 6.3 says for the kernel with those names. They never touch `EPC`, `EPSW`, `EVA` or `ECAUSE`, which are the guest's saved registers while the hypervisor runs.
3. **At `H = 1`, `RTI`, `RTT`, `PUSHX` and `POPX` name `HEPC` and `HEPSW`** instead of `EPC` and `EPSW`. So the hypervisor saves and restores its own exception state with the same instructions a kernel uses (6.3.4). `MFSR` and `MTSR` of `EPC` and `EPSW` at `H = 1` still reach the guest's registers (they are the things a world switch moves).
4. **Priority.** The hypervisor's priority is the priority field of the status word while `H = 1`. An exit sets it to 7 (as every entry does, 6.3.2); the hypervisor lowers it with `SPL` after it has saved `HEPC` and `HEPSW`, as a kernel does.

### 1.3 The new system registers and their numbers

**How many numbers are free.** The system registers are numbers 0 to 12 (**verified: `spec/grammars.d/41-sysreg.hbnf`**: `ptbr` 0, `epc` 1, `eva` 2, `ecause` 3, `dmw0` 4, `dmw1` 5, `usp` 6, `ssp` 7, `epsw` 8, `vbr` 9, `mmuctl` 10, `asid` 11, `cpuid` 12). The manual says the number is 8 bits, so 13 to 255 are free: 243 numbers (6.5.1 and its commentary). The instruction itself has 12 bits for the number (**verified: `spec/pdp64/tables.md`**, the `MFSR` and `MTSR` rows: `op2.imm=p1[11:0]`), so up to 4,096 could be encoded; I assume the manual's 8 bits and do not use the rest.

**Proposal: a block for the hypervisor starting at 128 (hexadecimal 80).** Numbers 13 to 127 stay free for registers of the kernel (so a future kernel register does not need the hypervisor block); 128 to 255 are the hypervisor's. The hardware test "is this a hypervisor register" is then one bit of the number, which is what rule 6.14.7 and audit decision 12(c) need: *a guest's `MFSR` or `MTSR` of a number that is a hypervisor register exits; of an unassigned number it raises the illegal-instruction exception in the guest.* To keep that rule exact the hardware decodes the assigned numbers (not the whole upper half), so an unassigned number in the upper half is illegal in a guest too. No number below clashes with 0 to 12.

| Number | Name | Reads and writes | Width in use | What it holds |
|---|---|---|---|---|
| 128 | `HTRAP` | read, write | 24 bits | trap-control (1.5) |
| 129 | `HEXITR` | read only | 10 bits | exit reason (1.6) |
| 130 | `HEPC` | read, write | 64 | hypervisor exception program counter |
| 131 | `HEPSW` | read, write | 16 (status-word layout) | the status word saved at an exit; the one `GENTER` loads |
| 132 | `HEVA` | read only | 64 | guest-virtual address of the access that caused the exit |
| 133 | `HCAUSE` | read only | 9 | the vector number of the exit (the same numbering as `ECAUSE`, 6.3.6) |
| 134 | `HGPA` | read only | 40 | guest-physical address that stage 2 could not translate |
| 135 | `HINSN` | read only | 32 | the first two parcels of the instruction that caused the exit |
| 136 | `HVBR` | read, write | 64 (a page) | base of the hypervisor's vector table |
| 137 | `GTBR` | read, write | 64 | stage-2 root, stage-2 enable and guest tag (1.7) |
| 138 | `VIRQ` | read, write | 8 | virtual interrupt lines, pending (1.8) |
| 139 | `VIVEC` | read, write | 56 | the vector number of each virtual line (1.8) |
| 140 | `VTOFF` | read, write | 64 | virtual timer offset (1.9) |
| 141 | `VCPUID` | read, write | 16 | the guest's virtual core number (1.10) |
| 142 | `GEVA` | read, write | 64 | write alias of the guest's `EVA` (1.11) |
| 143 | `GECAUSE` | read, write | 64 | write alias of the guest's `ECAUSE` (1.11) |
| 144 | `GKSP` | read, write | 64 | the guest's kernel-bank `R14` (1.11) |
| 145 | `GKDP` | read, write | 64 | the guest's kernel-bank `DP` |
| 146 | `GSDP` | read, write | 64 | the guest's supervisor-bank `DP` |
| 147 | `GUDP` | read, write | 64 | the guest's user-bank `DP` |

That is 20 registers (numbers 128 to 147); 108 numbers of the block (148 to 255) stay free. Everything here is access at `H = 1` only; at `H = 0` an access exits (code 18, 1.6), and on `HVE = 0` it is illegal. Only `HGPA`, `HEVA`, `HEXITR`, `HCAUSE` and `HINSN` are read only (the assembler would refuse a write, as `41-sysreg.hbnf` does for `eva`, `ecause` and `cpuid`).

### 1.4 The hypervisor's exception registers (decision 10 of the audit)

`HEPC`, `HEPSW`, `HEVA`, `HCAUSE` and the guest-physical fault address `HGPA`, as decided, plus two I propose to add and argue here.

* **`HINSN`: the instruction bits.** An exit for a trapped instruction (`MTSR PTBR, R5`, `MFCPUID R3`) leaves the hypervisor needing to know the instruction, to find the register operand and the system-register number. Without the bits the hypervisor must read them from guest memory at `HEPC`, which is a guest-virtual address: it would have to walk the guest's tables in software, which is what hardware two-stage translation was chosen to avoid. All system instructions and every system-register move are one or two parcels (**verified: `spec/pdp64/tables.md`**: the system leaves are one parcel, `MFSR` and `MTSR` two), so the first 32 bits hold the whole instruction. The same register serves a stage-2 fault on a load or store: it tells the hypervisor which register and size to emulate when the access is to an emulated device. *Precedent:* RISC-V's `htinst` does this (**verified: `target/riscv/cpu.h`** has `htinst`; **`target/riscv/tcg/cpu_helper.c`** writes `env->htinst = tinst` at the trap entry, next to `env->htval = htval`); ARM puts the faulting instruction's register and size in the syndrome of `ESR_EL2` (the field names `EC_DATAABORT` and the syndrome helpers are in **`target/arm/syndrome.h`**, **verified**; that the syndrome carries the register and size is **unverified: general knowledge**). *Cost:* 32 bits of register and a copy of the fetched parcels. *If refused:* the hypervisor reads the instruction itself; stage 2 of the instruction fetch gives the guest-physical address only if the guest's translation was walked, so the hypervisor needs a software guest walker.
* **`HVBR`: the hypervisor's vector base.** The decisions list four exception registers and none for where the hypervisor's handlers are. Entry needs the handler's address, and the guest's `VBR` is the guest's. A register like `VBR`, read at a physical address (`HVBR + 8 * HCAUSE`, the same 8-byte entries) re-uses the entry machinery (1.6).
* **`HEPC` for an exit follows the rule of 6.3.1:** the address of the instruction for an abort (a stage-2 fault, an instruction that was not executed) and the address of the next instruction for a trap and for an interrupt. A trapped system instruction is a trap: the hypervisor emulates it, and the guest resumes at `HEPC` with no skipping code. `HINSN` gives the instruction it emulates.

### 1.5 The trap-control register `HTRAP`

One bit for each event of section 5 of the audit that is to be routable. A set bit sends that event to the hypervisor as an exit; a clear bit leaves it to the guest (and, where the audit says "hw", to the hardware's per-guest form). The privilege check of the guest comes first: an instruction that the guest's own mode may not execute (`WFE` in a guest's user mode) raises the *guest's* privileged-instruction exception (vector 3 in the guest) and never reaches `HTRAP`; only an instruction that would succeed in the guest is a candidate for an exit.

| Bit | Name | Event (the audit's numbering) | Reset value | When set |
|---|---|---|---|---|
| 0 | `WFE` | `WFE`/`WAIT` (2) | **1** | idle guest gives the core back (6.14.12: trap by default) |
| 1 | `SEV` | `SEV` (4) | **1** | the hypervisor scopes the event to the guest's cores (6.14.12) |
| 2 | `PAUSE` | `HINT #1` (3) | 0 | a spinning guest yields the core |
| 3 | `PRIO` | `SPL`, `MTPS` priority change (5) | 0 | only for a hypervisor that does not use the virtual priority of 1.8 |
| 4 | `TLBI` | `TLBI` (6) | 0 | hardware scopes it to the guest's tag when clear |
| 5 | `TLBIA` | `TLBIA` (7) | 0 | as above |
| 6 | `TLBSYNC` | `TLBSYNC` (8) | 0 | as above |
| 7 | `ASID` | `MTASID`, `MFASID`, `MTSR`/`MFSR ASID` (9) | 0 | the tag keeps the numbers apart when clear |
| 8 | `PTBR` | write to `PTBR` (10) | 0 | shadow tables or debugging |
| 9 | `MMUCTL` | write to `MMUCTL` (11) | 0 | debugging |
| 10 | `VBR` | write to `VBR` (12) | 0 | debugging |
| 11 | `CPUID` | `MFCPUID`, `MFSR CPUID` (14) | 0 | the fallback for the virtual core number of 1.10 |
| 12 | `ICINV` | `ICINV`, `ICINVA` (15) | 0 | only if timing between guests is a concern (6.14.13) |
| 13 | `BPT` | `BPT` (20) | 0 | a debugger in the hypervisor |
| 14 | `STEP` | exit after each guest instruction (22) | 0 | single step a guest |
| 15 | | reserved | 0 | |
| 16 to 23 | `TRAPMASK` | `TRAP #n` blocks (21) | 0 | see below |

Bit 15 and bits 24 to 63 are reserved. **Reserved bits** read as zero; a write of a one to a reserved bit is an illegal instruction (so software can probe for a bit that a later version defines, and an old version never silently ignores a request to trap something). 
**Events that have no bit, because they always exit** (they are not the guest's to handle, or no guest could do it): `HALT` (6.14.12, audit 1); `MTDMW`, `MTSR DMW0`, `MTSR DMW1` and the reads `MFSR DMW0/1` (6.14.14; a window takes effect over real physical memory, so a bit to switch the exit off would be a hole); `PROBER` and `PROBEW` with a stage-2 miss (6.14.4); any use of a hypervisor register or of `GENTER` (6.14.7); every stage-2 fault, a stage-2 miss on the vector fetch or the page-table walk, and a machine check (6.14.4, audit 24); every physical interrupt (6.14.5, audit 25). **Events that are not exits, because they are the guest's own:** illegal instruction, privileged instruction, page faults and protection faults of stage 1, `TRAPCC`, overflow checks, `TRAP #n` outside the routed range, a system-register number that is unassigned (audit 19, 23). `ISYNC` (audit 16) has no bit: it is unprivileged (errata 190) and harmless. **Audit rows 26 and 27** are not events at all: see 2.6 (a guest reset is an operation the hypervisor performs) and 1.9 (the interrupt window is done by the hardware's virtual-line rule).

**The hypercall (6.14.12).** `TRAP #n` for n from 0 to 255 is routed by the 8-bit `TRAPMASK`: bit k of the mask routes the thirty-two numbers 32k to 32k + 31. A routed `TRAP` is a trap (the instruction succeeds; `HEPC` is the next instruction), takes the hypervisor's vector `256 + n` (the numbering of 6.3.6, so the hypervisor's table has one entry per hypercall number), and sets `HEXITR` to 17. It is routed at *any* guest mode (a hypercall from a guest user program is the hypervisor's to allow, as a system call is the kernel's). *Options:* a mask of 8 blocks (proposed, simplest hardware: three bits of the number select one mask bit); a lower bound (`n >= N`: one 8-bit field plus a comparator, but only a top range); a 256-bit map (four registers: the most freedom, the most state). Reset value of the mask is 0: no `TRAP` is routed and every `TRAP` is the guest's own system call. No opcode (6.14.12).

**Reset values.** On a machine reset, `WFE` and `SEV` are 1 and everything else 0. *Why not all ones ("fail closed"):* the hardware-virtualised forms (scoped invalidate, virtual priority, virtual core number) are the design, and they are safe with the bit clear; the two instructions that are *not* safe without a hypervisor action are `WFE` (a guest could sleep the real core) and `SEV` (it could wake a core that belongs to another guest), which the decisions already make trapped by default.

### 1.6 The exit-reason register `HEXITR`

A code of 8 bits in bits 7:0, and two flag bits. `HCAUSE` says *where it goes* (the vector); `HEXITR` says *why it stopped*, in finer detail than the vector, and is what the hypervisor's exit handler dispatches on. They are not the same information: for example a trapped `MTSR PTBR` and a trapped `MFCPUID` have the same vector (17, below) and different reasons.

| Code | Reason | `HCAUSE` (vector) | `HEPC` is |
|---|---|---|---|
| 0 | the event was taken at `H = 1` (the hypervisor's own), not an exit | its vector | per 6.3.1 |
| 1 | physical interrupt | the line's vector (32 to 63, 64 to 255 when message-signalled) | next instruction |
| 2 | `HALT` | 17 | next |
| 3 | `WFE` | 17 | next |
| 4 | `SEV` | 17 | next |
| 5 | `HINT #1` | 17 | next |
| 6 | `SPL` or `MTPS` priority | 17 | next |
| 7 | `TLBI`, `TLBIA` or `TLBSYNC` | 17 | next |
| 8 | address-space register (`MTASID`, `MFASID`, `ASID` by `MFSR`/`MTSR`) | 17 | next |
| 9 | write to `PTBR` | 17 | next |
| 10 | write to `MMUCTL` | 17 | next |
| 11 | write to `VBR` | 17 | next |
| 12 | direct-mapping window (`MTDMW`, `DMW0`, `DMW1`) | 17 | next |
| 13 | core number (`MFCPUID`, `MFSR CPUID`) | 17 | next |
| 14 | `ICINV` or `ICINVA` | 17 | next |
| 15 | `BPT` | 17 | next |
| 16 | single step | 17 | next |
| 17 | hypercall (`TRAP #n` routed) | 256 + n | next |
| 18 | hypervisor register or `GENTER` used by a guest | 17 | next |
| 19 | stage-2 fault: the entry is invalid | 18 (instruction fetch), 19 (load), 20 (store) | the instruction (it is retried) |
| 20 | stage-2 fault: the entry refuses the access (permission, reserved bits, accessed or dirty clear) | 18, 19, 20 | the instruction |
| 21 | machine check in a guest (a bus error on a guest's real access) | 1 | the instruction |

**Flag bits:** bit 8 `WALK`: the failing stage-2 access was a read of a guest page-table entry, so `HGPA` is the guest-physical address of that entry and `HEVA` is the address the guest was trying to reach. Bit 9 `VEC`: it was the guest's vector fetch (6.14.4), so `HGPA` is `VBR + 8 * vector` of the guest. A `PROBER` or `PROBEW` with a stage-2 miss is code 19 or 20 with `HINSN` showing the probe.

**Four new vector numbers** are proposed, taken from the reserved range 17 to 31 of 6.3.6 (the hypervisor's table only; no guest table is ever indexed by them): **17** instruction exit, **18** guest-physical instruction fault, **19** guest-physical load fault, **20** guest-physical store fault, the names parallel to vectors 6, 7 and 8. They would be added to `spec/grammars.d/50-system-v1.hbnf` (owner's approval; I do not edit it).

*Options for how the exit enters the hypervisor:* (a) through a table at `HVBR + 8 * HCAUSE` (proposed: the same 8-byte fetch the kernel's entry uses, a physical interrupt takes its natural vector, a hypercall its `256 + n`, a stage-2 fault its own); (b) through one entry address, the handler dispatching on `HEXITR` (RISC-V `stvec` in direct mode is one entry address, **unverified: general knowledge**; ARM has a table indexed by the kind of exception, **unverified**). (a) re-uses what exists and gives a hypercall its own entry for free; (b) saves a page and the new vector numbers but adds a second fetch rule. I recommend (a). `HEXITR` and `HCAUSE` are then both needed, as the decisions say.

### 1.7 Stage-2 root, guest tag and the format of stage 2: `GTBR`

**One register for both** (the decision says a "second table root and a guest tag in the translation buffer"; I propose to keep them in one register so that a single write changes both):

| Bits | Field | Meaning |
|---|---|---|
| 0 | `S2EN` | stage 2 on; 0 means guest-physical = physical |
| 39:12 | root | physical page number of the stage-2 root (28 bits, the same field as the page number of a page-table entry, 6.7) |
| 63:48 | `GTAG` | the guest tag (16 bits) |
| the rest | | zero |

*Why one register:* if the root and the tag were two registers, between the two writes the core would hold the new root with the old tag, and an entry made then would be filed under the old tag with the wrong root: the stale-entry error of errata 178 for guests. One write cannot be half done. *Precedent:* ARM's `VTTBR_EL2` holds the root address and the VMID in one register, the VMID in bits 63:48 (**verified: `target/arm/helper.c`**, `vttbr_write`: `extract64(raw_read(env, ri) ^ value, 48, 16)`, which flushes the guests' translations when the VMID changes); RISC-V's `hgatp` is one register with the mode, the root and a VMID (**verified: `target/riscv/cpu_bits.h` defines `CSR_HGATP`; `tcg/csr.c` has `write_hgatp`; the width of its VMID field I did not find, unverified**).

**The width of the guest tag: 16 bits.** *Justification:* (1) the address-space number is 16 bits (6.8: 65,536 numbers) and the IOMMU proposals reached the same figure for the unit's tag, "the same number space and width as the processor's" (2.11.8, and iommu-proposals.md section 5); (2) ARM's `VTTBR_EL2` has a 16-bit field (**verified** above); (3) 65,536 guests per machine is far beyond the number a first hypervisor runs, and a hypervisor that runs fewer re-uses numbers with an invalidate, as the kernel does with ASIDs (6.8). *A narrower tag* (8 bits) would make the translation-buffer entry smaller by 8 bits and limit to 255 guests; it saves little and then the IOMMU's tag in the device entry (32 bytes, room) would differ from it. **Tag 0 is the host** (2.11.8): entries made while `HVE = 0`, or with `S2EN = 0` by a host-owned guest, have tag 0.

**The format of stage 2 (proposal, for the owner to confirm).**

* The stage-2 entry is the page-table entry of 6.7 (V, R, W, X, A, D, memory type, page number; large pages at the upper levels), with **U and G required zero** (a set bit is a stage-2 fault, "refused"), because stage 2 knows no privilege levels. The walker never writes a table (6.8.1), so stage 2's accessed and dirty bits are **software-managed** too: a clear A, or a clear D on a write, is an exit (code 20), which gives the hypervisor dirty-page tracking for free.
* **Levels and span:** three levels of 512 entries (the machine's, `levels` 3 in `50-system-v1.hbnf`), a 39-bit span; but a guest-physical address has 40 bits (the machine's physical address has 40 bits and bit 39 is the *space bit*, errata 60, **verified: `qemu/target-pdp64/mmu.c`** `pdp64_pte_space_ok` and the grammar's `pa-bits` 40). I propose the stage-2 **root is two consecutive pages (1,024 entries)**, so the whole 40-bit guest-physical space, including bit 39, is covered: the lower half is the guest's memory, the upper half its device space, which the hypervisor leaves invalid (every touch exits) or maps to a host page. (ARM allows a concatenated root for the same reason; that is **unverified: general knowledge**.) The alternative is a fourth level, which lengthens every nested walk.
* **Memory type and the space bit:** stage 1's check (the type must agree with the space bit of the output address, errata 65) applies to the guest-physical address stage 1 produces; stage 2's own type is the one used for the real access. Combining the two types (ARM combines them; **unverified: general knowledge**) is left to the hypervisor: it must give a page the type its stage-1 mapping implies. (This is the one point on which I could not read a precedent: a decision for later, not now.)
* **Permissions** are the intersection of both stages; **the page size of a combined entry is the smaller of the two** (a stage-1 2 MB page over stage-2 4 KB pages gives 4 KB entries in the buffer: an unavoidable cost of two stages; unverified as a statement about any particular processor).
* **The walk (6.14.4 and the count there):** with *n* guest levels and *m* stage-2 levels a miss needs *nm + n + m* table entries read: **15** for 3 and 3, against 3 for one stage (the 6.14 text, from Bhargava et al.; consistent with `(n+1)(m+1) - 1`). Each guest table pointer is a guest-physical address and goes through stage 2 before it is read; the final guest-physical address goes through it once more. A guest with its translation off (`MMUCTL` bit 0 clear) walks stage 2 only: *m* reads.

**The translation buffer.** Each entry is keyed by (`GTAG`, address-space number, guest-virtual page, global bit) and holds the final physical page and the permissions of both stages. At `H = 0` the buffer uses the tag in `GTBR`; at `H = 1` nothing is translated and no entry is made. A hit needs the tag to match; the global bit of stage 1 means "global within this tag". Rules for removing entries:

* *(G-a)* A **guest's own** `TLBI`, `TLBIA`, `TLBSYNC` and `MTASID` (when not trapped) act on entries of its own tag only, on every core (the broadcast of 6.8.3 carries the tag). A guest can no longer flush another guest's entries.
* *(G-b)* **The rules of 6.8.4 and 6.8.5 apply per tag**: a write at `H = 0` to `MMUCTL`, `PTBR` or `ASID` acts on the guest's tag; a write at `H = 1` acts on the tag in `GTBR`. Because no entry is ever *made* at `H = 1`, a world switch that rewrites the guest's registers with the values it had cannot meet a stale entry.
* *(G-c, new)* **A write to `GTBR` that changes the root or `S2EN` discards every entry of the tag it is writing.** (The analogue of 6.8.4(b): an entry walked from an old stage-2 root is never used under a new one with the same tag.) A write that changes only the tag discards nothing: entries are keyed by the tag. *Cost:* a compare at the write.
* *(G-d)* **At `H = 1`, `TLBIA` discards the entries of the tag in `GTBR`; `TLBI rN` discards the entry of the guest-virtual page in `rN` for the guest's address-space number (the one in the `ASID` register, which at an exit still holds the guest's) and the guest's global entries, again for the tag in `GTBR`.** This is the "guest-tagged invalidate"; it needs no new mnemonic (section 3). A change to a stage-2 entry that was valid is followed by `TLBIA` for the guest and `TLBSYNC`; a finer invalidate by guest-physical page is an optimisation for a later version.
* An implementation may discard more (6.8.4): the QEMU model will (section 6).

*What it costs:* 16 bits and a comparator per buffer entry, and the nested walker; the walker is the large part (the IOMMU document makes the same point for its unit).

### 1.8 Virtual interrupts: `VIRQ` and `VIVEC` (6.14.5)

**The rule that is decided:** a physical interrupt always exits; a guest's priority masks only virtual interrupts; `SPL` does not trap; virtual interrupt lines are in hardware and fitted to the eight priority levels of 6.3.

**Options for the virtual lines** (the question the decisions left open: "a register, how it is injected and acknowledged, the priority interplay, the vector numbering").

* **V1 (recommended): one line for each priority level, seven lines (levels 1 to 7; level 0 is "no interrupt").** `VIRQ` bit *L* is "line *L* pending". `VIVEC` has a field of 8 bits for each of the seven lines (line 1 in bits 7:0, line 2 in bits 15:8, and so on to line 7 in bits 55:48) that holds the *vector number* the guest takes for that line; 32 to 255 are legal (the interrupt range 32 to 63 and the message-signalled range 64 to 255 of 6.3.6). The hypervisor writes `VIRQ` to inject (a read-modify-write or a plain write); the hardware **clears the bit when it delivers** the interrupt. *Delivery:* between two instructions of a guest, if the highest pending line *L* is greater than the guest's priority field, the core takes a guest exception entry with that vector (the entry of 6.3, written to the guest's `EPC`, `EPSW`, `EVA` (0), `ECAUSE`, the guest's `VBR`), and clears bit *L*. *Acknowledge:* there is none to do, the delivery clears the bit (an edge: the hypervisor raises it again when its virtual device still has a request). *Interplay with the physical interrupt:* at the same boundary a physical interrupt exits first. *The interrupt window* (audit row 27: a guest lowers its priority while a virtual interrupt is pending) needs no event: the hardware compares at every boundary, so the interrupt is taken the instant the priority allows it. *Cost:* 7 bits + 56 bits of state per guest and a priority comparator on 7 lines (the same comparator as the physical case). *For:* one register to inject; the guest's `SPL` works with no exit; nothing to acknowledge. *Against:* two devices at one level share a line and a vector register field: the hypervisor must queue the second and raise it again after the first is delivered. It learns when the first is delivered only at the next exit; since version 1's virtual devices are all trapped (6.14.6) the guest's driver touches a virtual device register to service the first, which exits, so the hypervisor has the chance. (An optional exit on "virtual interrupt delivered" is not proposed; it can be a later `HTRAP` bit.)
* **V2: one line for each vector 32 to 63** (a 32-bit pending register, the existing numbering of the physical lines) **with a level for each vector** (32 fields of 3 bits: 96 bits, a second register). *For:* the vector is fixed by the line, as the physical timer is vector 32. *Against:* more state; the level table duplicates what the device decides; no message-signalled vectors 64 to 255.
* **V3: one injection slot** (a valid bit, a level and a vector: the x86 way, an "event injection" field of the control block; **unverified: general knowledge**; the field exists in the SVM control block that `svm_helper.c` reads, **`target/i386/tcg/system/svm_helper.c`**, but I did not read the field's use). *For:* one register of about 16 bits, the smallest. *Against:* one interrupt at a time, so the hypervisor needs an exit when the guest becomes able to take the next (the window event, with its own exit code and the hypervisor tracking the guest's priority); the cost moves from hardware to exits.
* **V4: the ARM and RISC-V way, a few lines with a fixed meaning** (RISC-V `hvip` holds the lines "virtual supervisor software, timer, external": **verified: `target/riscv/cpu_bits.h`** `MIP_VSSIP`, `MIP_VSTIP`, `MIP_VSEIP` and **`target/riscv/tcg/csr.c`** `hvip_writable_mask`; ARM's `HCR_EL2` has `VI` and `VF` bits, "virtual IRQ" and "virtual FIQ" pending, **verified: `target/arm/cpu.h`** `HCR_VI`, `HCR_VF`, and `target/arm/helper.c` calls `arm_cpu_update_virq`). *For:* proven. *Against:* the priority levels of the pdp64 are eight and are the design's own mechanism (6.3.7); a fixed 3-line set would not fit the eight-level scheme (a guest's `SPL #5` should mask level 4 and below and let level 6 through, which three lines cannot do).

*Recommendation:* V1. **Physical interrupts at `H = 0`:** the core takes an exit for any asserted physical line, whatever the guest's priority (6.14.5), with `HEXITR` 1 and `HCAUSE` the line's vector, and `HEPC` the address of the next instruction (an interrupt is taken between instructions). **Physical interrupts at `H = 1`:** taken if their level is above the hypervisor's own priority, exactly as today. **`WFE` in a guest** (when it is not trapped): ends for a pending *virtual* line even if masked (the rule of 7.10.2, extended to the virtual lines), and a physical interrupt exits.

### 1.9 The virtual timer offset: `VTOFF` (6.14.5)

**The difficulty, stated plainly.** The decision says "a timer that the hypervisor offsets from the real one, in hardware". The machine's timer (the one in `qemu/hw-pdp64/timer.c`, **verified**: a 64-bit counter, a 64-bit compare and a control register at three offsets of a device page, interrupt at level 6, vector 32, `50-system-v1.hbnf`) is a **device read by an ordinary load**. There is no instruction that reads a clock (6.14.2 and audit decision 14), so unlike ARM or RISC-V there is no register in which to apply an offset: ARM's virtual counter is the physical count minus `CNTVOFF_EL2` (**verified: `target/arm/helper.c`**, `gt_indirect_access_timer_offset` returns `env->cp15.cntvoff_el2` for the virtual timer) and RISC-V's `time` read adds `htimedelta` when a guest runs (**verified: `target/riscv/tcg/csr.c`**, `read_time`: `delta = env->virt_enabled ? env->htimedelta : 0`); both are system-register reads. A guest on the pdp64 reads the counter by loading from the timer's page. The device is one for the whole machine, so it cannot know which guest is asking.

**Options.**

* **T1: no hardware offset; the hypervisor traps the guest's accesses to the timer page** (the page is invalid in stage 2; each load of the counter is an exit; the hypervisor returns the counter minus its own offset and sets a real timer for the guest's compare). *For:* nothing new in hardware. *Against:* a stage-2 fault for every time read: a guest kernel reads the time often (every scheduling tick and many system calls); it contradicts "in hardware".
* **T2 (recommended): a core-local virtual timer page.** Each core presents a second timer page, with the same three registers (counter, compare, control), whose counter reads *real counter minus `VTOFF`*, whose compare and enable are the guest's, and whose expiry raises *virtual line 6* (the line of the timer's level, 6.3.7) by setting `VIRQ` bit 6 itself (the vector is the hypervisor's `VIVEC` field for line 6). The hypervisor maps this page into the guest's stage 2 at the guest-physical address where the guest expects its timer. A load of the counter then costs no exit and no hypervisor software. The hypervisor's own timer is the existing physical timer page (used at `H = 1`, level 6, vector 32, as now). *For:* it is the ARM design carried over to a machine with no clock instruction (ARM's virtual timer expires into the hypervisor's interrupt controller and is injected; it is not a direct line, **unverified: general knowledge**, so this is a step further than ARM). *Against:* a core-local device page: the same physical address must reach different hardware on different cores (the usual arrangement for a private peripheral, **unverified: general knowledge**), and the model and the platform need to say where the page is (J.2.1 is open; I propose no address). *Cost:* a 64-bit subtractor, a 64-bit comparator, a 64-bit compare register and an enable bit for each core (an estimate of the order of 200 bits of state and one adder and one comparator, not a gate count).
* **T3: pass the guest tag with every device access and have the timer device keep an offset for each tag.** *Against:* a table in a shared device and a bus attribute that no part of the design has. Not recommended.

`VTOFF` is the 64-bit value subtracted (modulo 2^64) from the real counter; at `H = 1` the physical timer page reads the real counter unmodified. The model's timer runs at 10 MHz (`timer-clock hz`, `50-system-v1.hbnf`, **verified**).

### 1.10 The virtual core number: `VCPUID` (6.14.11, audit decision 2)

`MFCPUID` and `MFSR CPUID` return `VCPUID` when `H = 0` and the real core number when `H = 1`; both are privileged (6.14.11 and 6.2.5; the privilege check precedes the trap-control check, 1.5). `VCPUID` is 16 bits and is set by the hypervisor. The `CPUID` bit of `HTRAP` is the fallback (the hypervisor that does not want to maintain the register traps and returns the value itself). No new decision beyond the number 141.

### 1.11 What the hypervisor must be able to reach: the four guest registers the existing numbers do not give

Reading the executor (**verified: `common/pdp64exec.c`**, the `MFSR`/`MTSR` switch, and `common/pdp64exec.h`) exposed two gaps in the existing 13 registers that a world switch needs filled:

1. **`EVA` and `ECAUSE` are read only** (`41-sysreg.hbnf`, `sysreg-ro`; the executor refuses a write with an illegal-instruction abort). A hypervisor that preempts a guest between its exception entry and its first handler instructions must put `EVA` and `ECAUSE` back when it resumes the guest, or the guest's handler would read other values. I propose two write aliases in the hypervisor block, **`GEVA` (142) and `GECAUSE` (143)**, that read and write the same storage as the guest's `EVA` and `ECAUSE`. *Alternative:* make `EVA` and `ECAUSE` writable at `H = 1`: no new numbers, but the assembler, which knows only the names, cannot tell that a write is legal in one mode and not in another (the grammar's `sysreg-ro` is static), so the aliases keep the grammar rule intact.
2. **Three `R14` and three `DP` registers exist (one pair for each mode, `spbank[3]` and `dpbank[3]`), and the existing numbers reach only `USP` and `SSP` (the stack pointers of the user and supervisor banks)**: the kernel bank's `R14` and all three `DP` values have no system register (the existing instructions `MTDP`/`MFDP` name only the current mode's `DP`, and the executor says "the current mode's slot is stale"). At an exit the hardware switches to the hypervisor's own bank (1.12), which saves the guest's live pair in its slot; the hypervisor then needs to read and write all six. I propose four registers: **`GKSP` (144), `GKDP` (145), `GSDP` (146), `GUDP` (147)**, the guest's kernel `R14` and the `DP` of the kernel, supervisor and user banks. `USP` and `SSP` stay as they are.

### 1.12 The hypervisor's own registers: a fourth bank of `R14` and `DP`

At an exit the 29 or so general registers of the guest are all still in the register file, and the first instruction of the exit handler needs a register that is not the guest's. ARM has a separate stack pointer for its hypervisor level for this reason (`SP_EL2`; **unverified: general knowledge**, the field `banked_spsr` and `elr_el[4]` of `target/arm/cpu.h` show the banking of the exception registers, **verified**), and RISC-V swaps one scratch CSR (`sscratch`, **unverified**). I propose **a fourth bank of `R14` and `DP` for `H = 1`**: an exit switches to it, `GENTER` switches back, and nothing is saved by software to get a first register. The hypervisor's `DP` is its per-core structure (the use 6.2 gives the kernel's `DP`), `R14` its stack. *Cost:* two 64-bit registers, and one more value in the bank selector of `pdp64_set_psw` (`bank()`, which today knows three). *Alternative:* no bank, and one dedicated system register `HSCRATCH` that the first instruction swaps with a general register (RISC-V's way, unverified): saves 64 bits of the bank and costs one more number and a longer handler entry. I recommend the bank.

## 2. The entry and exit sequences, step by step

The state to be saved is listed at the end of this section (2.7). In the steps, "write" means the hardware writes the register in the same step as the others; the order is the order of the exception entry of 6.3 (the vector word is read *before* any register is written, which is how the executor's `enter()` does it, **verified: `common/pdp64exec.c`**: it calls `vecread` first and writes `epc`, `epsw`, `eva`, `ecause` after; so a failed fetch changes nothing).

### 2.1 (a) A trap of a guest: the exit

An exit is caused by an event of 1.6 while `H = 0`. For an abort-kind event the instruction is undone first (the executor already restores registers from its snapshot for an abort: `pdp64_exception` copies `c->snap` back when `c->snap_valid` and the instruction was not a block operation in progress, **verified**). Then:

1. Decide the exit reason code (`HEXITR`) and the vector (`HCAUSE`).
2. Read the 64-bit word at the physical address `HVBR + 8 * HCAUSE`; a bus error here is a machine check at `H = 1` (the hypervisor's failure).
3. Write `HEPC` := the address of the instruction (abort kinds) or of the next instruction (trap kinds and interrupts) (1.4).
4. Write `HEPSW` := the complete status word of the guest at that moment: flags, trace, priority, the two mode fields, and the user-memory guard bit.
5. Write `HEVA` := the guest-virtual address of the access, for a stage-2 fault or a trapped access; else 0.
6. Write `HGPA` := the guest-physical address, for a stage-2 fault; else 0.
7. Write `HINSN` := the first 32 bits of the instruction, for an exit caused by an instruction; else 0.
8. Write `HEXITR` (code and flags) and `HCAUSE`.
9. Set `H := 1`. Set the status word: current mode kernel, previous mode the guest's current mode, priority 7, trace 0, flags 0, guard 0 (as 6.3.2). The `R14` and `DP` of the guest's current mode are put in their slots and the hypervisor's bank is loaded (1.12).
10. Clear the naming of the vector accumulators and any `LL` reservation, and discard the hidden state of a vector block that was in progress (decision 13 of the audit and 6.14.9; the second part is what `pdp64_exception` does today, **verified**). **Not duplicated here:** the clear is another agent's work (section 7).
11. `PC := the word read in step 2`.

**Not written:** `EPC`, `EPSW`, `EVA`, `ECAUSE`, `PTBR`, `VBR`, `MMUCTL`, `ASID`, `USP`, `SSP`, `DMW0`, `DMW1`, any general register, `fpsr`: they are the guest's and stay as they were. **Not done:** no translation-buffer operation (the entries are tagged); no change of `GTBR`. The guest cannot observe that it was stopped.

### 2.2 (b) Entry into a guest

The hypervisor, at `H = 1` and priority 7, prepares the state and executes the one new instruction, `GENTER` (section 3). The prepared state is the list of 2.7 (the 12 writable system registers through `MTSR` and the `GEVA`/`GECAUSE`, `GKSP` and the others; the general registers; `fpsr`; then `HTRAP`, `GTBR`, `VIRQ`, `VIVEC`, `VTOFF`, `VCPUID`; then `HEPC` and `HEPSW`, the guest's resume point). `GENTER` does, as one step:

1. If `H = 0` (a guest executed it): this is an exit, code 18; if `HVE = 0`: illegal instruction (section 3).
2. If the value in `HEPSW` has the reserved mode 2 in either mode field: illegal instruction at `H = 1`; the instruction changes nothing (the same check as `RTI`, 6.2).
3. Take the effect of every earlier write to `PTBR`, `MMUCTL`, `ASID`, `VBR`, `GTBR`, `HTRAP` as an `ISYNC` does (6.5.2): `GENTER` includes an `ISYNC`, because the next instruction runs under all of them.
4. `PSW := HEPSW` (flags, trace, priority, modes, guard); the hypervisor's `R14` and `DP` are put in the H bank; the guest's pair for its current mode is loaded.
5. `PC := HEPC`. `H := 0`.

Nothing else. In particular no translation-buffer entry is removed (G-c applies if `GTBR` was written). If a virtual line is pending and above the guest's priority, it is taken at the boundary before the first guest instruction.

### 2.3 (c) A physical interrupt while a guest runs

A physical line is asserted and `H = 0`. At the next boundary between instructions (the guest's priority does not matter, 6.14.5) the core takes an exit with code 1, `HCAUSE` the vector of the highest line (the rule of `pdp64_irq_best` in the model: highest level, then lowest vector; **verified: `qemu/target-pdp64/cpu.h`**), `HEPC` the address of the instruction not yet run, `HEVA = HGPA = HINSN = 0`, and the steps 2.1 (2) to (11). The line stays asserted until the hypervisor (or its handler of the device) clears it at the device, as today. The hypervisor, now at priority 7 and `H = 1`, may service the device, inject a virtual interrupt (2.4), and `GENTER`.

### 2.4 (d) A virtual interrupt injection

At `H = 1` the hypervisor sets bit *L* of `VIRQ` (`MFSR`, or, `MTSR`) and sets the vector in `VIVEC` field *L*. It then enters (or resumes) the guest. The hardware, at a boundary with `H = 0`, finds line *L* above the guest's priority (and no physical interrupt asserted): it clears `VIRQ` bit *L* and does the **guest's** ordinary exception entry (6.3): the vector word at the guest's `VBR + 8 * vector` read through stage 2 (a stage-2 miss on it is an exit of code 19 or 20 with `VEC` set, with `HEPC` the instruction not yet run and *nothing changed*: the hypervisor fills stage 2, and the guest comes back and takes the interrupt); then `EPC` := the next instruction, `EPSW` := the status word, `EVA` := 0, `ECAUSE` := the vector; the new status word is kernel mode, previous mode the old mode, priority 7, trace and flags and guard clear; the guest's `R14` and `DP` switch to the kernel bank; the accumulator naming and any `LL` reservation are cleared (6.14.9, every exception entry); `PC` := the word read. No exit, no hypervisor code runs, `H` stays 0.

### 2.5 (e) A second-stage fault

The guest's access (instruction fetch, load, store, read of a guest page-table entry in a stage-1 walk, the vector fetch of an exception entry, or the memory test of `PROBER`/`PROBEW`) reaches a stage-2 entry that is invalid or refuses it. The instruction is undone (an abort). Exit as 2.1 with: code 19 (invalid) or 20 (refused); `HCAUSE` 18, 19 or 20 (fetch, load, store); `HEPC` the faulting instruction; `HEVA` the guest-virtual address the guest was reaching; `HGPA` the guest-physical address that failed (for the walk, the table entry's address and flag `WALK`; for the vector fetch `VBR + 8 * vector` and flag `VEC`); `HINSN` the instruction. The hypervisor installs or corrects the stage-2 entry (setting A and, for a write, D), issues `TLBIA` for the guest if the entry was valid before and `TLBSYNC`, and enters; the guest retries the instruction and, unless it faults again, never knows. A stage-2 fault inside an *exception entry* of the guest (for example the store that pushes `PUSHX`'s two words to the guest's stack) is the same: the instruction is undone.

### 2.6 (f) A guest reset

There is **no hardware event** for a guest reset (the audit's row 26 is not an event of the hardware): vector 0 of 6.3 is the machine's reset and nothing in the instruction set resets a guest. A guest asks for a reset the way it asks for anything else the hypervisor owns, by a hypercall or by a touch of a virtual device, both of which exit. **The reset is an operation the hypervisor performs, in this order** (the order matters; it is the order of the guest reset sequence of the IOMMU proposals, written for the processor):

1. Stop the guest's cores (an exit on each; an inter-processor interrupt for a core that is running it).
2. For each device assigned to the guest, block it and invalidate the unit's translations for the guest tag (2.11.8, iommu-proposals.md section 5), and wait for the unit's `sync`.
3. Write `GTBR` for the guest with the *new* root (G-c discards its entries if the root changed), or `TLBIA` at `H = 1` with the tag in `GTBR` (G-d) and `TLBSYNC`; then write `MMUCTL` as 0 (if the guest's bit 0 was 1, rule 6.8.4(a) discards the tag's entries again: a second guard).
4. Write every system register and every other piece of state to the value of section 3 of this document.
5. Zero the general registers and `fpsr`, set `HEPSW` to the reset status word of section 3 and `HEPC` to the guest's reset entry, and `GENTER`.

Only after step 3 may the tag be used by another guest. *Why the hardware does not do it:* the hypervisor owns the policy (what the guest's memory is after a reset), and the hardware cannot know that a set of register writes means "reset". The two hardware guards G-b and G-c make steps 3 and 4 safe even if the hypervisor forgets the `TLBIA` when the root changes.

### 2.7 What is saved by whom at a world switch

**By the hardware, at an exit (and loaded by it at an entry):** the guest's program counter (`HEPC`), the guest's status word (`HEPSW`, which holds the four flags, the trace bit, the priority, both mode fields and the guard), and the switch of the `R14` and `DP` of the current mode into the H bank and back. Nothing else.

**By the hypervisor, in software, at every world switch** (a first-year student's list: everything of the guest that lives in the core and that the next guest must not see or inherit):

| What | How the hypervisor reaches it |
|---|---|
| the 12 writable system registers of 6.5: `PTBR`, `EPC`, `EVA`, `ECAUSE`, `DMW0`, `DMW1`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID` (`CPUID` is the virtual number, 1.10) | `MFSR`/`MTSR`; `EVA` and `ECAUSE` written through `GEVA`, `GECAUSE` |
| the three banked `R14` and `DP` pairs: `R14` of user and supervisor (`USP`, `SSP`), `R14` of kernel (`GKSP`); `DP` of kernel, supervisor and user (`GKDP`, `GSDP`, `GUDP`) | `MFSR`/`MTSR` |
| the general registers other than `R14` | ordinary stores and loads |
| `fpsr` | `FSFLAGS`, an unprivileged instruction (**verified: the audit's run of `fsflags`**) |
| the guest's virtual state: `HTRAP`, `GTBR`, `VIRQ`, `VIVEC`, `VTOFF`, `VCPUID`, and the registers of the virtual timer page | `MFSR`/`MTSR` and the page |
| the translations tagged to the guest | **nothing is saved**: they stay in the buffer under the tag; the hypervisor invalidates them (G-d) when it reassigns the tag or changes stage 2 |
| the vector block's naming of accumulators | **not saved**: cleared by the hardware (6.14.9, the decision of errata 186 No. 13) |
| any `LL` reservation | **not saved**: cleared by the hardware (same) |
| the state of a pending `WFE` | **none exists**: 7.10 defines no event flag (read: 7.10.1 and 7.10.2), and the executor keeps one `wait` flag that an exit clears. If a latched event flag is ever added it becomes world-switch state |
| the hidden vector registers `v0` to `v15` | **not saved** (6.14.9: a block restarts from its entry and a strip starts with its registers zero) |

## 3. The instructions

### 3.1 The list

| Mnemonic | Operands | Meaning | Privileged to the hypervisor mode | Encoding |
|---|---|---|---|---|
| `GENTER` | none | enter a guest: 2.2 | yes: legal only at `H = 1`; at `H = 0` an exit, code 18; on `HVE = 0` an illegal instruction | one parcel, one of the four reserved system words that are left, `syspg2` to `syspg5` (3.3) |

That is **one new mnemonic**. The other two the owner anticipated are not needed, for these reasons:

* **No guest-return instruction.** A guest never leaves by an instruction of its own: exits are caused by events (trapped instructions, the hypercall by `TRAP #n`, interrupts, faults) and the hardware performs them (2.1). An instruction named `GRET` would only be a second way to cause an exit, which `TRAP` in the routed range already is (6.14.12: "no opcode of its own"). The hypervisor's *own* return from its own exception is `RTI` at `H = 1` (1.2).
* **No guest-tagged invalidate.** `TLBI rN` and `TLBIA` at `H = 1` act on the tag in `GTBR` (rule G-d), and at `H = 0` on the guest's own tag (G-a). `TLBSYNC` waits for the broadcast to finish as before. The tag is a register, not an operand, so the invalidate needs no new operand and no new word. (The cost: before invalidating guest B's entries the hypervisor writes `GTBR` with B's tag, which is a register write it does anyway at a world switch. A hypervisor that does many cross-guest invalidates would like an operand; the argument against is that no such invalidate exists in version 1: the hypervisor only invalidates the guest whose stage 2 it is editing, whose tag it has just set.)
* **No instruction to read guest memory through the guest's tables.** The hypervisor runs untranslated (1.2) and gets the instruction in `HINSN`, and the guest-physical address in `HGPA`; for a software walk of stage 2 it reads physical memory. RISC-V has instructions for this (`hlv.*`, `hsv.*`: **verified: `target/riscv/insn32.decode`**, the `hlv_b` ... `hsv_b` lines) and `hfence.gvma` for the invalidate by guest (**verified**, the same file); a pdp64 version would be a later addition if the software walk turns out to be too slow.

### 3.2 Options for the entry

* **E1 (recommended): `GENTER`, a new mnemonic**, in a reserved slot. Clear, grep-able, a unit of its own to test.
* **E2: no new mnemonic; `RTI` at `H = 1` enters the guest when a control bit is set** (the bit would be in a register such as `HEPSW`'s bit 15 or a separate `HCTL`; RISC-V's `sret` does this with the `SPV` bit of `hstatus`: **verified: `target/riscv/tcg/op_helper.c`**, `helper_sret` reads `HSTATUS_SPV`, clears it and enters the guest). *For:* no instruction at all. *Against:* `RTI` then has two meanings chosen by a hidden bit, which is how `MFPS` and `RTI` stop being simple (6.14.3's whole point was that they did not change); a stray `RTI` that finds the bit set enters a guest. Not recommended.
* **E3: a `GENTER` with a register operand** that names a block of guest state in memory to load (the x86 SVM way: `VMRUN` loads from a control block in memory, **verified: `helper_vmrun` in `target/i386/tcg/system/svm_helper.c`**). *For:* one instruction loads the lot. *Against:* it is a hardware loop over every register (a long, interruptible, restartable instruction; the pdp64 has some, `MCPY` and its kin, but a new one in the privileged group is a heavy price); the register-file `MTSR` sequence already does it and a hypervisor can reorder it. Not recommended.

### 3.3 Encoding impact: do the instructions fit without a new prefix leaf and without moving any encoding?

**Yes, for `GENTER`, if one of the four reserved system words that are left is renamed.** Evidence, all from `spec/pdp64/tables.md`, `spec/grammars.d/20-enc-forms.hbnf`, `spec/facts/core.toml` and `docs/errata.md` (185):

* The no-operand, one-parcel system words are in two leaves: `SYS0` with an 11-bit prefix and 32 sub-opcodes (30 assigned when this was first written: `nop rti rtt ret halt bpt fence wfe sev lpad tlbia tlbsync icinva pushx popx isync` and the fourteen `trapcc.cc`; two were then reserved, `syspg0` and `syspg1`, and **the implementation of `UA` (errata 192) has since taken both for `stua` and `clua`**, so that leaf is now full), and a second `SYS0` leaf with a 14-bit prefix and four sub-opcodes, `syspg2` to `syspg5`.
* **`syspg2` to `syspg5` are four reserved system words** (there were six: `syspg0` and `syspg1` are now `stua` and `clua`) with no meaning: the executor treats them as unimplemented instructions (`spec/facts/core.toml`: `exec = "H_UNIMPL"`), the manual's instruction dictionary said "the six words are reserved" when there were six, and the repository text says "no text of the repository gives these words a meaning, and software must not use them" (`tools/manual/isa_part4.py`, the `SYSPG` entry, **verified**). They were set aside for the page-bit mechanisms of errata 84 (items 5 and 8), which the retire-stage record says "need no opcode" (`docs/retire-stage-candidates.md`, **verified**: "zero opcodes").
* **So `GENTER` takes `syspg2`:** a rename in the facts file, the grammar's sub-opcode list (`20-enc-forms.hbnf`, `sub-SYS0-2`, the word in the same position) and the mnemonic list of `80-mn-ext.hbnf`, keeping its sub-opcode value (0 in the leaf of four). The bit pattern of every instruction is unchanged; no leaf is added; the optimiser is not re-run. *Condition:* I did not run the generator, so "no pattern moves" is a reading, to be confirmed by regenerating the tables and comparing the files (a plain diff would show one changed mnemonic and nothing else).
* The unassigned first-parcel patterns are one contiguous block of **926** (`spec/pdp64/tables.md` summed by me: 65,536 minus the patterns of the 240 leaves; this equals errata 185's count), beginning at the pattern `0xFC62`. As aligned groups, it holds blocks of 512 (7-bit prefix `1111111`), 256 (8-bit, `11111101`), 128 (9-bit, `111111001`), 16, 8, 4 and 2 patterns. So **if `syspg2` were not available** a new leaf for a no-operand word (a 15-bit prefix with one bit of sub-opcode, 2 patterns) fits *inside the free block without moving any existing pattern*; but adding a leaf is a change to the grammar's leaf list and, in this repository, a run of the generator (and of the optimiser, if the leaf order is the optimiser's), which the owner says renumbers every opcode. **If three or more mnemonics were wanted** (the guest-return and a tagged invalidate, were they chosen), the four reserved words that are left (`syspg2` to `syspg5`, in a four-way leaf) would still hold up to three more of them with no new leaf: `GENTER`, a guest-return and a tagged `TLBI` variant that takes no operand (the tag from `GTBR`) fit the no-operand form; one that takes a register operand would need a leaf of the `SYSR` kind, and all `SYSR` leaves are full (8 and 2 sub-opcodes, all assigned) and would need the free block and a generator run.
* **System-register numbers 128 to 147** are not an encoding change: the instruction carries a 12-bit number and the grammar names them (`41-sysreg.hbnf`): a new entry in the `sysreg` list (and the read-only list for five of them). The operand fields of the instruction are not touched.
* **New vector numbers 17 to 20** are a change to the enumeration in `50-system-v1.hbnf` (an enumeration, not an instruction pattern).

**Summary:** the design fits **without a new prefix leaf and without moving any encoding**, using one reserved system word. The only things that would force a re-run of the optimiser are a new mnemonic with a register operand in the system group, or the choice of a new leaf.

### 3.4 The existing instructions that change meaning at `H = 1` or `H = 0` (no new encoding)

| Instruction | At `H = 1` | At `H = 0` |
|---|---|---|
| `RTI`, `RTT`, `PUSHX`, `POPX` | name `HEPC`, `HEPSW` | name `EPC`, `EPSW` (the guest's, as today) |
| `MFSR`, `MTSR` of 0 to 12 | the guest's saved register | the guest's own register |
| `MFSR`, `MTSR` of 128 to 147 | the hypervisor register | an exit, code 18 (a guest cannot use one: 6.14.7) |
| `MFSR`, `MTSR` of 13 to 127 and 148 to 255 | illegal instruction | illegal instruction in the guest |
| `MFCPUID`, `MFSR CPUID` | the real number | `VCPUID` |
| `TLBI`, `TLBIA` | for the tag in `GTBR` | for the guest's own tag |
| `HALT`, `WFE`, `SEV`, `HINT #1`, `ICINV`, `BPT`, `SPL`/`MTPS`, `TRAP` | as a kernel | the exit or the hardware form of 1.5 and 1.6 |

## 4. The state of every system register after a guest reset (6.14.8)

Two columns: the reset of the **machine** (what a core holds after power-on) and the state in which the hypervisor **puts a guest** by a guest reset (2.6). Where the manual or the model already says the value, the source is named; where it does not, the value is mine, a proposal, and says so. The guest-register rows follow the model's reset (**verified: `qemu/target-pdp64/cpu.c`**: `memset` of the state to zero, then `MODE_KERNEL << PSW_MODE | MODE_KERNEL << PSW_PREV | 7 << PSW_PRI`) and 6.12.1 (kernel mode, priority 7, translation off, guard clear, `VBR` zero).

| Register | Machine reset | State of a guest after a guest reset | Source |
|---|---|---|---|
| status word | kernel mode, previous mode kernel, priority 7, trace 0, flags 0, guard 0 | the same | 6.12.1, `cpu.c` |
| `PC` | the platform's reset entry | the guest's reset entry, `HEPC` | proposal |
| 0 `PTBR` | 0 | 0 | `cpu.c` memset |
| 1 `EPC` | 0 | 0 | same |
| 2 `EVA` | 0 | 0 (via `GEVA`) | same |
| 3 `ECAUSE` | 0, which is the reset vector's number (6.3.6) | 0 (via `GECAUSE`) | same |
| 4, 5 `DMW0`, `DMW1` | 0 | 0 | same |
| 6, 7 `USP`, `SSP` | 0 | 0 | same |
| 8 `EPSW` | 0 | 0 | same |
| 9 `VBR` | 0 | 0 | 6.12.1 |
| 10 `MMUCTL` | 0 (translation off) | 0 | 6.12.1, 6.8.2 |
| 11 `ASID` | 0 | 0 | `cpu.c` memset |
| 12 `CPUID` | the core number | `VCPUID`, the hypervisor's value | 6.14.11 |
| `R14` of the kernel bank | the platform's initial stack | the hypervisor's value per its boot protocol | `cpu.c` (QEMU sets it to the top of RAM) |
| the other banked `R14` and the three `DP` | 0 | 0 | memset |
| general registers other than `R14` | 0 | **zero, by the hypervisor**: a guest must not read another guest's data | memset; proposal |
| `fpsr` | 0 | 0 | memset |
| naming of the vector accumulators, any `LL` reservation | cleared | cleared | 6.14.9 |
| cached translations of the guest's tag | none | **none** (G-b, G-c and the sequence of 2.6) | 6.8.5 |
| 128 `HTRAP` | `WFE` and `SEV` set, the rest 0 | the hypervisor's policy: not changed by a guest reset | 1.5 |
| 129 to 135 `HEXITR`, `HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN` | 0 | not defined (the next exit writes them); `HEPC`, `HEPSW` set by the hypervisor as the resume point | proposal |
| 136 `HVBR` | 0 | not a guest's | proposal |
| 137 `GTBR` | 0 (`S2EN` clear, tag 0) | the guest's root, `S2EN` set, its tag; written before the entry | proposal |
| 138, 139 `VIRQ`, `VIVEC` | 0 | 0 (no virtual interrupt pending) | proposal |
| 140 `VTOFF` | 0 | the hypervisor's value | proposal |
| the virtual timer page's registers | counter runs, compare 0, enable clear | compare 0, enable clear | the model's timer (`timer_reset`, which I read only to the extent of its structure: unverified) |
| 141 `VCPUID` | 0 | the guest's virtual core number | proposal |
| 142 to 147 | 0 | 0 | proposal |

"The same as a machine reset" is a rule I would state once: *a guest after a guest reset is a machine after a machine reset, except that the hypervisor's registers keep the hypervisor's values and `CPUID` returns the virtual number.* The table is to be kept in step as registers are added (6.14.8), and the test of section 6 compares a guest's registers after a reset with it row by row.

## 5. The IOMMU's part (2.11 and decision 8 of that document)

* The guest tag in the device entry and in the unit's cached-translation key has **the same 16 bits** as `GTAG` and the same meaning (tag 0 is the host); 2.11.8 asks for the width and this document gives it.
* Level B of the unit (guest-physical to physical) and stage 2 of the processor are written by the same hypervisor and *may* share the same tables: one tag, one root. iommu-proposals.md left that as an unasked question (its decision 14); I note it and propose nothing (the format of stage 2 above, "the PTE of 6.7 with U and G zero", is compatible with the unit's leaf, which requires X, U, G and the memory type zero: **verified: 2.11.4**; stage 2 for the processor needs X and the memory type, so the two would differ in those bits).
* The guest reset sequence of 2.6 steps 2 and 3 is the processor side of the sequence the unit's proposal wrote; the hardware guards (G-b, G-c) and the unit's blocking guard are the same idea on both sides.

## 6. The second stage in the QEMU model and in sim64

### 6.1 What the QEMU model does today (**verified: `qemu/target-pdp64/mmu.c`, `cpu.h`, `cpu.c`**)

One walker (`pdp64_mmu_translate`): a three-level walk of the table at `PTBR`, reading each entry with `address_space_ldq_le` from physical memory; it never writes (A and D software-managed); it checks V and reserved bits, the leaf, alignment of a large page, the memory type against the space bit, the rights of the mode, and A and D; it returns the physical page, the rights and the size, which `tlb_fill` installs in QEMU's own translation cache. There are three QEMU MMU indices (physical, kernel, other). QEMU's cache has no address-space number: the executor's `tlb` hook flushes it entirely on a write to `PTBR`, `ASID`, `MMUCTL` and at `ISYNC` (errata 178). Interrupts: `irq_lines` is 32 bits (bit *n* is vector 32 + *n*), `pdp64_irq_best` picks the highest level then lowest vector, and `pdp64_take_interrupt` enters if the level exceeds the priority.

### 6.2 What the second stage needs

**The walker (`mmu.c`).** A function `pdp64_s2_translate(env, guest_physical_address, access, &pa, &rights, &size, &fault)` that walks the stage-2 table (the root at `GTBR` bits 39:12, two root pages, three levels), with the same checks as the stage-1 walker (V, reserved bits, U and G zero, leaf, alignment, A and D, memory type) and the rights R, W, X of the access. The stage-1 walker then calls it **once for each table-entry read** (the entry's address is guest-physical) and **once for the output**: with *n* = 3 and *m* = 3 that is the 15 reads of 6.14 (3 stage-1 entries plus 3 × 3 stage-2 entries for those plus 3 for the output, counted as `nm + n + m`). When `S2EN` is clear the walker is as today. When the guest's translation is off but stage 2 is on, the guest address goes to stage 2 only. The result's size is the smaller of the two leaves and its rights the intersection.

**MMU indices.** Three more (guest, translation off, stage 2 only; guest kernel; guest user), so QEMU's own cache keeps the guests' entries apart from the hypervisor's. `pdp64_mmu_idx_mode` picks them from `H`, `GTBR.S2EN` and `MMUCTL`.

**The guest tag.** QEMU's cache has no tags and need not: a change of `GTAG` or of the stage-2 root flushes the three guest indices (ARM's model does this on a change of VMID, **verified: `target/arm/helper.c` `vttbr_write`**: `tlb_flush_by_mmuidx` with the indices of the guest). That is "more than the rule asks" and allowed. **To make a stale translation observable** (the purpose of errata 178's test), the model needs the *architectural* cache of translations that is keyed by (tag, ASID, page), kept beside QEMU's own and flushed only as the architecture says, so a hypervisor that forgot the `TLBIA` is caught: the model of the IOMMU proposals asks for the same ("a model cache so that a missing invalidate is observable"). This is the largest piece of the QEMU work and the most valuable one for the owner's concern. *Unverified:* that QEMU's per-CPU address-space facilities can present a core-local virtual-timer page at one physical address to every core; I did not read them.

**The stage-2 fault record.** On a stage-2 failure the walker must give the executor: which kind (invalid, refused), whether the access was a walk read or a vector fetch, the guest-physical address, and the guest-virtual address. The executor's host interface (`struct pdp64_env`: `raise(vector, eva)` and `vecread`) carries a vector and one address, so it must grow: a field of the core state set by the host before `raise` (`hgpa`, the exit flags) and a result code from `vecread` that tells a bus error from a stage-2 miss.

**Interrupts.** `pdp64_cpu_exec_interrupt` and `pdp64_take_interrupt` get the two rules of 1.8: at `H = 0` any asserted physical line exits whatever the priority; the virtual lines are compared with the guest's priority and delivered as a guest exception. `cpu_interrupt` must be raised when a virtual line becomes deliverable as well as when `irq_lines` is non-zero.

### 6.3 What the executor (`common/pdp64exec.c`, shared by sim64 and QEMU) needs

* New fields of `struct pdp64_cpu`: `h`, `hve`, the registers of 1.3 (`htrap`, `hexitr`, `hepc`, `hepsw`, `heva`, `hcause`, `hgpa`, `hinsn`, `hvbr`, `gtbr`, `virq`, `vivec`, `vtoff`, `vcpuid`), and `spbank[4]`, `dpbank[4]` (the executor's `bank()` knows three; `pdp64_set_psw` switches banks on a change of the *mode*, so a change of `H` needs the same switch).
* `enter()` becomes two: the guest's (as today) and the exit's (2.1), chosen by `H` and the event; `pdp64_exception` and `pdp64_interrupt` choose.
* One check after each existing `priv()` of a trappable instruction: `gtrap(HTRAP_bit, code)` that does nothing at `H = 1` and, at `H = 0`, raises the exit if the bit is set (and, for the always-exit events, unconditionally). The privilege check stays first (1.5).
* `MFSR`/`MTSR`: the new numbers, with the rules of 3.4. The existing `die("illegal instruction", 0)` for an unassigned number (read, not run, in the audit) is the path a guest takes for an unassigned number.
* `GENTER`: a new case in the system group (the sub-opcode of `syspg2`).
* The hooks `tlb`, `probe`, `check`, `fetch`, `vecread` take the tag and a stage flag where needed; `PROBER`/`PROBEW` test both stages and exit on a stage-2 miss.

### 6.4 What sim64 can and cannot do

**Verified: sim64 has no MMU and no translation buffer** (errata 178: "`h_tlb` does nothing, translation is always off"), so it cannot test anything of stage 2, of the guest tag or of their invalidation. It *can* test everything that does not need translation: the `H` bit, `GENTER`, the exits and the registers they write, the trap-control bits, the hypercall mask, the virtual lines and their priority rule, `VCPUID`, the reset table, `HVE = 0` leaving everything as it is. A sim64 option (like `-K`) would set `HVE`. *Unverified:* whether sim64 has a timer or an interrupt source to test physical-interrupt exits (the audit's harness used `-K` and `trap`/`halt` only); I did not read sim64.

### 6.5 The order of the work, in steps that each can be tested

0. **Prerequisites that another agent is doing** (section 7): `ISYNC` unprivileged, `MFCPUID` privileged, `UA`/`STUA`/`CLUA`, the clear of the accumulator naming at exception entry; the grammar and constants for the new numbers, vectors and codes (**needs the owner's approval of this document first**).
1. **The `H` bit, the registers of 1.3, `GENTER`, the exit and `HVE`** (no stage 2, no virtual interrupts, `S2EN` clear): on sim64 and QEMU. Test: a hypervisor at `H = 1` enters a loop guest; the guest does `HALT` and the hypervisor sees code 2, `HEPC`, `HEPSW`, `HCAUSE` 17, with the guest's `EPC` unchanged; `HVE = 0` makes every new register illegal and every existing test unchanged.
2. **`HTRAP`: every bit, the always-exit events, privilege first, hypercall mask, hypervisor-register use by a guest exits, unassigned number illegal in the guest.** Test: one guest program for each row of 1.5 and 1.6, comparing `HEXITR`, `HCAUSE`, `HEPC` and `HINSN` with a table.
3. **Physical interrupt exit, virtual lines, `WFE` wake, `VCPUID`, the virtual timer page, the world-switch clear.** QEMU (the timer and an interrupt source exist there). Test: the guest at priority 7 still exits for the physical timer; the guest at priority 5 takes line 6 and not line 4; the guest's `SPL` never exits.
4. **Stage 2, identity then not, the nested walk, stage-2 faults and the record, the vector fetch and the page-table walk through stage 2, `PROBER`/`PROBEW` both stages.** QEMU only. Test: the faults of 2.5 with `HGPA`/`HEVA` checked; the walk count by a counter in the model (15 reads for a cold 3 and 3 miss).
5. **The guest tag and the architectural cache, G-a to G-d.** QEMU only. Tests in the style of `tests/qemu/mmu-flush.S` (**verified**, named in errata 178): a stage-2 entry changed behind the cache with and without the `TLBIA`, a guest `TLBIA` that must not remove another guest's entry, a tag re-used without the invalidate; and the scratch-edit non-vacuity check errata 178 used (remove the flush and see the test fail).
6. **The reset table**, row by row, after a guest reset sequence (2.6); a mutation test that skips step 3.
7. **The first software**, below.

### 6.6 The first software: a small hypervisor of our own and one guest kernel (6.14.10)

*An outline, not a design.* Run as `qemu-system-pdp64 -M pdp64-virt,kernel-mode=on,hypervisor=on` (**the machine option `hypervisor` is my proposal**; the existing options are `kernel-mode` and the others of `qemu/README.md`, **verified**).

* **The hypervisor** (assembler, a few hundred lines, `tests/qemu/hv-*.S` as a name proposal): boots at `H = 1`, physical; sets `HVBR` and a vector table with entries 1, 17 to 20, 32, 256 + n; builds the stage-2 tables for the guest's RAM (a non-identity offset on purpose, so a confusion between guest-physical and physical addresses is a failure) and the console page left invalid in stage 2 (every guest console access exits and the hypervisor does the real write: this is the first test of the stage-2 data fault, `HINSN` and `HGPA`); installs `HTRAP` (`WFE` set, hypercall mask bit for the numbers 224 to 255); sets `GTBR`, `VCPUID` 1 and the first guest's registers from section 4; `GENTER`. Its exit handler saves the guest's registers (2.7) and dispatches on `HEXITR`: 1 (physical timer: inject line 6), 3 (`WFE`: switch to the idle path), 2 (`HALT`: stop with the guest's `r0` as the status), 17 (hypercall: a service number), 19 and 20 (map or emulate), 18 (a nesting attempt: inject the illegal-instruction exception into the guest).
* **The guest kernel:** the existing `tests/qemu/mini-kernel.S` (**verified: it exists**) as the first guest, then a second guest kernel in the same file to test a world switch. The guest does what a kernel does: sets `VBR` and turns its own translation on (a stage-1 walk through stage 2), takes the virtual timer's line 6 interrupt, `SPL`s, makes a `TRAP #1` system call to its own user program (which must *not* exit), reads `MFCPUID` (the virtual number), idles in `WFE` (exit), calls the hypervisor by `TRAP #224`, and ends with `HALT`.
* **The tests it makes:** the output of the two guests on the console, the order of exits (a sequence the test file compares with the expected), a guest that tries `MTDMW` and a hypervisor register (exits), two guests with the same guest-virtual address and different contents (the tag), and the reset of one guest while the other keeps running.

## 7. The audit's open facts that bear on this

* **LL/SC and the atomics are not in the executor** (audit section 8, `common/pdp64exec_enc.inc` marks them `H_UNIMPL`): an `LL` reservation cannot be cleared at a world switch because it does not exist yet. The rule is decided (6.14.9, errata 186 No. 13); the first test of it can only be written when `LL` runs. Until then the step "clear any `LL` reservation" (2.1 step 10) is untestable and I mark it so.
* **sim64 has no MMU** (6.4): stage 2 and the guest tag are QEMU-only.
* **`UA`, `STUA`, `CLUA`, `ISYNC` unprivileged, `MFCPUID` privileged, and the clear of the accumulator naming at exception entry** are being implemented by another agent (errata 190 states them; the executor still shows `priv()` before `ISYNC` and no bit 12 in `PSW_VALID`, **verified** by reading `common/pdp64exec.c` and `.h` now, which may therefore be out of date when this is read). This document **refers to them and does not duplicate them**: the exit saves and clears the guard bit as part of the status word (2.1 step 4 and 9), and the clear of the naming is step 10; neither needs more than the other agent's work.
* **A multi-core `MFCPUID` was not run** in the audit, and no code that was read gives a second core a non-zero `cpuid` (audit section 8): the virtual number is therefore tested on a one-core machine only until a multi-core model exists.
* **The `SEV` text of 7.10** was skimmed in the audit; I read 7.10.1 and 7.10.2 for this document and found no latched event flag, so a `WFE` has no pending state to save (2.7). If a flag is ever added, it is world-switch state.
* The statement of 6.14.9 that the hidden vector state is not saved stands (R500, errata 188); the decision to clear the naming adds to it.

## 8. Precedents, in one place, with how I know them

| Claim | Status |
|---|---|
| ARM has `HCR_EL2` bits `VM`, `IMO`, `VF`, `VI`, `TWI`, `TWE`, `TSC`, `TVM`, `TGE`, `HCD` | **verified: `target/arm/cpu.h`** (the `#define HCR_*` lines) |
| ARM has `ELR_EL2`, `ESR_EL2`, `SPSR_EL2`, `VTTBR_EL2`, `HPFAR_EL2`, `CNTVOFF_EL2`, `HCR_EL2` as registers | **verified: `target/arm/helper.c`** |
| `HPFAR_EL2` gets the guest-physical address of a stage-2 fault (`extract64(fi->s2addr, 12, 47) << 4`) | **verified: `target/arm/tcg/tlb_helper.c`** |
| A change of the VMID (bits 63:48 of `VTTBR_EL2`) flushes the guests' translations | **verified: `target/arm/helper.c`, `vttbr_write`** |
| `WFE`/`WFI` trap to the hypervisor under `HCR_EL2.TWE`/`TWI` | **verified: `target/arm/tcg/op_helper.c`, `check_wfx_trap`** |
| Physical interrupts are routed to the hypervisor by `HCR_EL2.IMO` | **verified: `target/arm/helper.c`** (the uses of `HCR_IMO`) |
| The virtual counter is the physical count minus `CNTVOFF_EL2` | **verified: `target/arm/helper.c`, `gt_indirect_access_timer_offset`** |
| RISC-V has `hstatus` bits `SPV` and `GVA`, `hedeleg`, `hideleg`, `hvip` (with `VSSIP`, `VSTIP`, `VSEIP`), `htval`, `htinst`, `htimedelta`, `vsstatus`, `hgatp`; guest page faults, a "virtual instruction" fault; `hlv`, `hsv`, `hfence.gvma` | **verified: `target/riscv/cpu.h`, `cpu_bits.h`, `tcg/csr.c`, `insn32.decode`, `tcg/cpu_helper.c`** |
| RISC-V enters the guest by `sret` when `hstatus.SPV` is set | **verified: `target/riscv/tcg/op_helper.c`, `helper_sret`** |
| RISC-V's `time` read adds `htimedelta` for a guest | **verified: `target/riscv/tcg/csr.c`, `read_time`** |
| RISC-V sets `htval` and `htinst` when it enters the trap handler | **verified: `target/riscv/tcg/cpu_helper.c`** |
| The width of RISC-V's VMID field in `hgatp` | **unverified** (not found in what I read) |
| x86 SVM has `VMRUN`, an ASID and a nested-page-table root, read by the instruction from a control block in memory; `VMMCALL` exists | **verified: `target/i386/tcg/system/svm_helper.c`** (`helper_vmrun`, `asid`, `nested_cr3`, `helper_vmmcall`) |
| x86 VMX: the exit-reason field, the EPT pointer, VPID, `VMLAUNCH`/`VMRESUME` | **unverified: general knowledge** (only capability bits in `target/i386/cpu.h` were seen) |
| ARM's `ERET` returns to the lower level named by the saved `SPSR_EL2`; ARM concatenated stage-2 root tables; ARM combines memory types; ARM's virtual timer interrupt is injected via an interrupt controller | **unverified: general knowledge** |
| The two-stage walk count *nm + n + m*, 15 for 3 and 3 | **repository: 6.14** (Bhargava et al., checked there by the owner's earlier work); the same as the `(n+1)(m+1) - 1` of the IOMMU proposals |

I did **not** read: x86's `target/i386` virtual-interrupt injection fields in use, any ARM interrupt-controller (GIC) virtual interface, RISC-V's AIA, or any real machine's documentation; every statement above about how real hardware performs, or what a gate or flip-flop count would be, is unverified or an estimate.

## 9. What it costs, together (qualitative; estimates labelled)

* **State:** about 20 new system registers; by my list the new control state is of the order of 600 bits per core (HTRAP 24, HEXITR 10, HEPC 64, HEPSW 16, HEVA 64, HCAUSE 9, HGPA 40, HINSN 32, HVBR about 28 to 64, GTBR 45, VIRQ 7, VIVEC 56, VTOFF 64, VCPUID 16, plus the virtual timer's compare and enable, about 70; the four `G*` registers and the two aliases re-use storage that exists) and the H bank of two 64-bit registers, and 16 bits for each entry of the translation buffer. These are an **estimate** from the proposal, not a gate count; the method of `docs/encoding-work/vec-gates.md` can count them once the owner chooses.
* **Logic:** the exit and entry paths (the second register set and the bank selector), a few gates on each trappable instruction (a bit test), the priority comparator for virtual lines, a subtractor and a comparator for the virtual timer, the tag compare in the buffer, and above all **the nested walker** (the largest item, as it is in the IOMMU unit).
* **Instruction set:** one mnemonic in an existing reserved slot; no change in any bit pattern if the reading of 3.3 is right.
* **Kernel and hypervisor software:** the world-switch routine of 2.7, the reset sequence of 2.6, the stage-2 management; a guest kernel needs no change at all, which is the point of having done it in hardware.
* **Verification:** the stale-translation hazard doubles; hence the architectural cache of 6.2 and the non-vacuity tests of 6.5.
* **Time:** I give no estimate worth giving.

## 10. Decisions for the owner, each with a recommendation

Each is a single question, to be answered *accept / change / not decided*. They are ordered so that a later one depends on an earlier one; a "change" at an early number can change later ones, and I say where.

1. **How is the hypervisor mode kept, and how does a machine start?** *Recommend:* **accept.** A separate state bit `H` inside the core, not in the status word; a machine configuration bit `HVE`; with `HVE = 0` the machine is today's machine (all new registers and `GENTER` are illegal instructions, no existing test changes); with `HVE = 1` the core starts at `H = 1` and a native operating system is a guest. *The alternative* is Option B of 1.1 (a guest-running bit and a duplicated register set), which contradicts 6.14.3.
2. **What does `H = 1` mean for translation and exceptions?** *Recommend:* **accept** the four rules of 1.2: untranslated in version 1, own exception registers and own vector base, `RTI`/`RTT`/`PUSHX`/`POPX` name `HEPC`/`HEPSW`, priority 7 at an exit. *If changed* to a translated hypervisor, a hypervisor translation base and a third walk are added (1.2).
3. **A fourth bank of `R14` and `DP` for the hypervisor?** *Recommend:* **accept** (1.12). Alternative: a scratch register swapped by the first instruction.
4. **The register block.** *Recommend:* **accept** the numbers 128 to 147 and the names and widths of the table in 1.3, with 13 to 127 left for the kernel and 148 to 255 free; a guest's use of an assigned hypervisor register exits and of an unassigned number is illegal in the guest. The decision includes the two additions the owner did not list, `HINSN` and `HVBR`, argued in 1.4.
5. **The write aliases and the guest's banked registers.** *Recommend:* **accept** `GEVA`, `GECAUSE`, `GKSP`, `GKDP`, `GSDP`, `GUDP` (1.11). They exist because `EVA`, `ECAUSE` are read only and no register reaches the kernel `R14` or any `DP`; without them a world switch cannot restore a guest.
6. **How does an exit enter the hypervisor, and which vector numbers?** *Recommend:* **accept** a table at `HVBR + 8 * HCAUSE`, with vectors 17 (instruction exit), 18, 19, 20 (guest-physical instruction, load and store faults) from the reserved range of 6.3.6. The alternative is one entry address that dispatches on `HEXITR`.
7. **The exit-reason codes.** *Recommend:* **accept** the list of 1.6 (codes 0 to 21 and the flags `WALK` and `VEC`), `HEPC` after the instruction for traps and at it for aborts.
8. **The trap-control bits.** *Recommend:* **accept** the table of 1.5: bits 0 to 14, reserved bits illegal to write, reset value with `WFE` and `SEV` set and the rest clear, and the list of events that always exit and have no bit (`HALT`, the direct-mapping windows, hypervisor registers, stage-2 faults, machine checks, physical interrupts).
9. **The hypercall mask.** *Recommend:* **accept** an 8-bit `TRAPMASK`, bit *k* routing `TRAP #n` for n from 32k to 32k + 31, any guest mode, reset 0. Alternatives: a lower bound, or a 256-bit map.
10. **The order of checks.** *Recommend:* **accept**: the guest's own privilege check first (a guest user's `WFE` raises the guest's vector 3), then the trap-control bit.
11. **The second-stage root and the guest tag.** *Recommend:* **accept** one register `GTBR` (`S2EN`, root, a **16-bit tag**), tag 0 the host, shared in width and number space with the IOMMU (2.11.8). *Changing* the width changes the IOMMU device entry too.
12. **The format of stage 2.** *Recommend:* **accept**: the page-table entry of 6.7 with U and G zero, software-managed A and D (a clear A or D is an exit), three levels with a **two-page root** to cover the 40-bit guest-physical space, rights intersected, the combined page the smaller. *Open sub-point for later:* how the two memory types combine (I read no precedent).
13. **Invalidation and the guest tag.** *Recommend:* **accept** rules G-a to G-d of 1.7: a guest's invalidates act on its own tag; 6.8.4 and 6.8.5 apply per tag; a write to `GTBR` that changes the root or `S2EN` discards the tag's entries; at `H = 1` `TLBI` and `TLBIA` act on the tag in `GTBR`. **No new instruction for a tagged invalidate.**
14. **The entry instruction.** *Recommend:* **accept** one new mnemonic, `GENTER`, no operand, privileged to `H = 1`, includes an `ISYNC`, in the reserved system word `syspg2`; **no guest-return instruction**. (The name is mine; the owner may rename it. Using a reserved word needs the owner's agreement that the six words are free: they were set aside for mechanisms that need no opcode.) *If refused,* a new leaf in the free block of 926 patterns is possible but is a grammar change and a generator run.
15. **Do the new instructions fit without moving any encoding?** This is a statement and a question: *I recommend you accept* that `GENTER` is placed by renaming `syspg2`, that no pattern moves and that the optimiser is not re-run, subject to the confirmation by regenerating the tables (3.3), which I did not do. Say "change" if you would rather keep all six words reserved.
16. **Virtual interrupts.** *Recommend:* **accept** V1: seven lines, one for each priority level 1 to 7, a pending register `VIRQ` set by the hypervisor and cleared by the hardware at delivery, a vector field for each line in `VIVEC`; a physical interrupt exits first; the guest's `SPL` masks only these; `WFE` wakes on a virtual line. Alternatives V2, V3, V4 (1.8).
17. **The virtual timer.** *Recommend:* **accept** T2: `VTOFF` and a core-local virtual timer page that reads *real counter minus `VTOFF`* and raises virtual line 6; the page's address is for the platform decision (J.2.1). If refused, the timer is emulated by exits (T1), which gives up "in hardware".
18. **The virtual core number.** *Recommend:* **accept** `VCPUID`, returned by `MFCPUID` and `MFSR CPUID` at `H = 0`, with the `CPUID` bit of `HTRAP` as the fallback.
19. **Guest reset.** *Recommend:* **accept** that a guest reset is an operation of the hypervisor, in the order of 2.6, with no hardware event, and the table of section 4 as 6.14.8's table (machine reset and guest reset columns).
20. **What the hypervisor saves at a world switch.** *Recommend:* **accept** the table of 2.7: the hardware saves only the guest's `PC`, status word and the `R14`/`DP` switch; everything else is the hypervisor's, nothing hidden is saved, the clears of 6.14.9 are the hardware's.
21. **Nesting.** *Recommend:* **accept** that any guest use of a hypervisor register or of `GENTER` exits with code 18 and the hypervisor makes it look to the guest like an illegal instruction in version 1 (so a later nested hypervisor can be emulated by the same exit).
22. **The first software and the machine option.** *Recommend:* **accept** the outline of 6.6, the machine option `hypervisor=on`, the existing `mini-kernel.S` as the first guest, and the order of steps 0 to 7 of 6.5 (steps 1 to 3 testable on sim64 as well as QEMU; stage 2 and the tag on QEMU only).
23. **The architectural translation cache in the QEMU model.** *Recommend:* **accept** that the model keeps a cache keyed by (tag, address-space number, page) that is flushed only as the architecture says, beside QEMU's own, so that a missing invalidate is a failing test (the lesson of errata 178 and the proposal of the IOMMU document), even though it is the largest single piece of the model work.

## 11. What was checked, and what was not

**Read in the repository:** the files named at the end of section 0, in the parts that bear on this design; the executor's exception entry, status-word code and the `MFSR`/`MTSR` switch; the QEMU model's `cpu.h`, `cpu.c`, `mmu.c` and `timer.c` (the timer only to its structure and register list). **Computed by me:** the free-pattern count of 926 and its decomposition from `spec/pdp64/tables.md` (the count matches errata 185). **Read in the QEMU v11.1.2 source:** the files and symbols named in section 8, by search for the names, not end to end.

**Not run:** nothing. I ran no QEMU, no `sim64`, no generator and no test; the statement that `GENTER` moves no encoding (3.3) is a reading and is to be confirmed by regenerating. **Not verified and said so in the text:** VMX details, RISC-V's VMID width, ARM's concatenated roots, memory-type combining, ARM's `ERET` details, how real processors implement a private timer page and a core-local page, whether QEMU's per-CPU address spaces can provide it, whether sim64 has an interrupt source, what the executor looked like when the other agent's work is merged. **Not claimed:** any gate count, any time, any benefit measured, any behaviour of real hardware.
