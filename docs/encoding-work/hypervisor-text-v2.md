# Proposed manual text for the hypervisor mode, second version: the story first

*For the owner to read before anything is written into the manual. Nothing here is in the manual. This replaces section 6.14 of the manual (`docs/manual-src/06-kernel.md`) and the earlier draft (`proposed-manual-text-hv.md`), which was reference text only. The owner's words of 2026-11-25 (errata 206): "lead with the story a pdp11 programmer would understand. motivate it. what is a hypervisor, who did it first, how does it work in broad brush strokes, then get into the intermediate level, then finally the fine details."*

*What the text is made of.* Three layers, in the order the owner asked. **Layer 1, the story** (section 6.14 below): the scene, what a hypervisor is, who did it first, how it works in broad strokes, why the pdp64 has one. **Layer 2, the mechanism** (6.15): nine worked examples, step by step. **Layer 3, the fine details** (6.16): the numbered statements and the tables, with *(D)* where decided, "Details to be determined" where a detail is open, and a closing list "Still open". Then the replacement for the "checked" section, and three lists for the owner.

*Numbering, and why.* Three sections, 6.14, 6.15 and 6.16, and the old 6.15 "What was checked, and what was not" becomes **6.17**. Reason: the manual's habit is a story followed by its numbered statements, and the owner wants the statements at the end; three sections let a reader stop after the first, or after the second, and the table of contents shows the three levels. Sections 6.14 and 6.15 carry no numbered statements; every statement is **6.16.N**, numbered 1 to 31 with no gap. If `tools/mkmanual.py --check` insists that every section has a numbered statement, the fallback is one section 6.14 with the three layers as run-in headings and the statements numbered 6.14.1 to 6.14.31 (then 6.15 stays "What was checked"); list 1, item A, says what changes in each case.

*Voice.* The chapter's own: the PDP-11 and V7 way first, then the pdp64 way. Layers 1 and 2 use no bare numbers: a reference to the errata or the manual is in brackets and rare, and layer 1 has none. Every claim about another system is verified (the "Checked against" block at the end gives the address, the date and one short sentence) or left out.

---

## PASTE BEGINS: section 6.14

## 6.14 Running a kernel under a kernel: virtualization

**A hypervisor is a small kernel whose programs are whole operating systems.** This section tells why anyone wants one, who built the first, and how the idea works. Section 6.15 then follows a guest operating system through nine events on the pdp64, and section 6.16 is the reference: every register, bit and rule.

**The scene.** You have one PDP-11/70 running Version 7 Unix, and it is the machine everyone uses. Three things happen in one week. A colleague wants to try a different operating system on it. You have written a new version of your own kernel and want to know whether it boots, but if it crashes it takes the machine, and everyone's work, down with it. And two customers each say they want a whole machine of their own, not an account on yours.

What do you do? The first answer is a second machine. It is the wrong answer for a plain reason: a second machine costs a second machine, and it sits idle whenever its one user is away, while the first is busy. Rooms of idle machines were exactly the situation that people building time-sharing systems wanted to leave. Creasy, who built the first system that did what this section describes, says that before it, system developers could only enjoy computer-assisted programming up to the point of trying the code, at which time "they required a dedicated hardware system, usually at night or on weekends" (Creasy 1981).

The second answer is to run the other operating system as an ordinary program under V7. This fails, and the PDP-11 shows how. A kernel is a program that does things only a kernel may do: it raises the priority in the status word to keep interrupts out of a critical section, it loads the page registers, it executes `HALT` when there is nothing more to do. Run it in user mode and the machine does one of two unhelpful things. The *PDP-11 Processor Handbook* says that outside kernel mode a `HALT` traps through location 4, which is at least a signal, but that the processor "will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation". Think about the second case. The guest kernel executes `SPL 7` to keep interrupts out of its run-queue code. The machine silently does nothing. The guest believes interrupts are held off and they are not; one arrives in the middle of the list update; the guest corrupts its own data and nobody has been told anything. The trouble is not that the guest is forbidden to do what it wants. The trouble is that the machine neither lets it nor tells anyone that it tried.

What is wanted is a layer under the kernel that sees every one of those acts, does for the guest what the instruction would have done, and keeps the guest from touching anything that is not its own.

**What a hypervisor is.** A **hypervisor** is a program that runs other operating systems, each believing that it has the whole machine to itself. The operating systems it runs are its **guests**; the real machine is the **host**; and each guest's imaginary machine is a **virtual machine**. (Popek and Goldberg's name for the same program is the *virtual machine monitor*, and their definition of the machine it makes is "an efficient, isolated duplicate of the real machine".)

**Who did it first.** IBM, in the middle of the 1960s. At the IBM Cambridge Scientific Center, then called the Systems Research and Development Center, a group led by R. J. Creasy conceived CP/CMS in 1964 for the newly announced System/360. In Creasy's words: "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." Each copy was a virtual machine controlled "like the real machine by their own operating systems". CP-40, on a System/360 Model 40 that had been modified with a device for address translation, and CMS were operational in 1966; CP-67 followed on the Model 67, which had translation built in. Creasy: "CP and CMS have seen continuous production use since 1967", and "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware".

Their way of catching the guest's privileged acts is the one this section uses. The System/360 had two states of execution, privileged and problem. Creasy: "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program. When using CP, each virtual machine program is actually executed in problem state. The effects of privileged instructions are reproduced by CP within the virtual machines." That is **trap and emulate**: the guest kernel runs in the least privileged state, so its privileged instruction traps; the hypervisor does what the instruction would have done, on a private copy of the state it keeps for that guest; and the guest goes on, not knowing that it did not do the work itself. Compare the PDP-11, where the guest's `SPL` did nothing and nobody was told.

In 1974 Popek and Goldberg, who had studied virtual machine systems, wrote down exactly when this works. Their theorem: "For any conventional third generation computer, a virtual machine monitor may be constructed if the set of sensitive instructions for that computer is a subset of the set of privileged instructions." Said in plain words: an instruction is **privileged** if it traps in user mode, and it is **sensitive** if it would let a program see or change the real machine instead of its own. If every sensitive instruction traps, the machine can be virtualized; if one sensitive instruction does not trap, the guest runs it, nothing is caught, and the illusion has a hole. They gave a machine with such an instruction: on the DEC PDP-10, `JRST 1` returns to user mode and does not trap. The PDP-11 of the scene above has the same fault in miniature, because its `SPL` is sensitive and is not caught.

A year later, at the Fifth Symposium on Operating System Principles (1975), Popek and Kline published "The PDP-11 Virtual Machine Architecture: A Case Study" (pages 97 to 105 of the proceedings). We have read its bibliographic record and nothing of its text; what we can say, from a later paper, is that Hall and Robinson call the mode-bit approach of their own VAX work "similar in concept to Popek and Kline's modifications to the PDP-11 architecture".

That later paper is from DEC itself. Hall and Robinson, "Virtualizing the VAX Architecture" (ISCA 1991), begin their abstract: "This paper describes modifications to the VAX architecture to support virtual machines. The VAX architecture contains several instructions that are sensitive but not privileged." The VAX, like the PDP-10 and the PDP-11, failed the theorem, and DEC changed the architecture to fix it. The work was a security kernel (the paper says DEC "does not sell the VAX security kernel described in this paper"); a prototype was begun in 1981 on a VAX-11/730, and the changes were afterwards implemented on the VAX-11/785 and the VAX 8800.

For decades afterwards, machines that failed the theorem were virtualized in software. The best-known case is the x86, of which Adams and Agesen (2006) say: "Until recently, the x86 architecture has not permitted classical trap-and-emulate virtualization", so monitors used binary translation of the guest's kernel code. Then the processors changed. The same paper, presented in October 2006, says "both Intel and AMD have now introduced architectural extensions to support classical virtualization"; its references name an Intel specification of April 2005 and an AMD manual of May 2005, and a later VMware paper has a table of VM-exit latencies that starts with the Intel Prescott processor, launched in the third quarter of 2005. Arm's own guide to its virtualization says: "Virtualization was introduced in Armv7-A." The RISC-V privileged specification has a chapter "'H' Extension for Hypervisor Support, Version 1.0" in its library of ratified specifications; it "virtualizes the supervisor-level architecture to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". (A **type-1** hypervisor runs directly on the machine; a **type-2** is an ordinary operating system that also runs guests.) We found no date for the Arm or the RISC-V extension in a primary source and so give none.

**How it works, in broad strokes.** Picture three layers, with the hypervisor under everything:

```
   user programs        user programs        user programs
  ---------------      ---------------      ---------------
   guest kernel A       guest kernel A       guest kernel B       <- each runs at the
                                                                      kernel level of its own
  ----------------------------------------------------------      virtual machine
   the hypervisor        (the only code that owns the machine)
  ----------------------------------------------------------
   the machine: cores, memory, devices, IOMMU
```

There are five ideas, and each is the PDP-11 idea with something added.

*First, the guest believes it owns the machine.* A V7 kernel starts, finds its memory and its devices and begins to run. A guest kernel does the same, except that what it finds has been set up for it: a range of memory that it believes begins at address zero, a status word, a set of devices, a clock. It cannot tell that it is a guest, because everything it can look at is an accurate picture of a machine, only not the real one.

*Second, every privileged act is caught.* When the guest kernel executes an instruction that would change the real machine, the machine stops the guest and enters the hypervisor. This stop is called an **exit** (the guest "exits" to the hypervisor). The hypervisor looks at why, does for the guest what the instruction would have done, on the private copy of the registers it keeps for the guest (the same idea as the PS and the page registers that V7 keeps in a process's `user` structure for each user program, one level up), and then re-enters the guest. As in Creasy's CP, the guest's own user programs run at full speed and without any exit; only the kernel's privileged acts cost a trip through the hypervisor.

*Third, the guest's memory is translated twice.* On the PDP-11 the KT11 turns a program's addresses into memory addresses through eight page registers. A guest kernel on a pdp64 fills its own page tables with what it believes are physical addresses; those are called **guest-physical** addresses. The hypervisor has a second set of page tables that turn a guest-physical address into a real one. The first translation is the **first stage** (stage 1) and the second the **second stage** (stage 2). Because a guest can only reach memory that its stage 2 maps, one guest cannot touch another's memory, nor the hypervisor's.

*Fourth, interrupts and the clock are made up.* A real device interrupt always goes to the hypervisor first, whatever the guest's priority. What the guest sees are **virtual interrupts**: lines that the hypervisor raises when its virtual device has something to say, and a virtual clock that counts from a starting point the hypervisor chooses. The guest's `SPL` works on these in hardware, so the guest's priority keeps its meaning and costs no exit.

*Fifth, devices are shared or handed over.* A guest's disk can be a file that the hypervisor reads and writes on the guest's behalf (shared, and every command is trapped), or a real device given to the guest, whose DMA is then confined by the IOMMU (the unit between devices and memory that translates a device's addresses the way the KT11 translates a program's) to the guest's own memory.

**Why the pdp64 has one.** The reasons are those of the table below, plus two of our own. The first is **seL4**, the verified microkernel, which we mean the pdp64 to run; seL4 can run as a hypervisor. The second is **safety**, the first of the four principles (safety, speed, fewer instructions, and last a set small enough to keep in the head): a machine that divides itself into isolated parts, in hardware, is the pdp64's safety idea applied to whole operating systems.

Each row of the table is stated in the documentation of the product named.

| where | what runs | why virtualization |
|---|---|---|
| **A rented server** (the cloud) | many customers' virtual machines on one physical server | AWS says that virtualization "allows very large servers to be subdivided for simultaneous use as multiple instances (VMs)", and that its hypervisor uses "hardware virtualization features of the server processor" |
| **A laptop or desktop** | Linux under WSL 2 on Windows; Docker Desktop on a Mac | WSL 2 "uses virtualization technology to run a Linux kernel inside of a lightweight utility virtual machine" (Microsoft); "Current versions of Docker Desktop use the Apple Virtualization framework by default" (Docker) |
| **A phone** | a protected virtual machine (pVM) beside Android | the Android Virtualization Framework "provides secure and private execution environments for executing code"; "even if the host is compromised, the host doesn't have access to a pVM's memory"; "pKVM is the standard hypervisor for running pVMs" |
| **An embedded system on one chip** | operating systems of different kinds side by side | the QNX Hypervisor lets you "consolidate multiple, diverse operating systems onto a single System-on-a-Chip (SoC)" |
| **A developer or a test farm** | a job in a fresh virtual machine | "With the exception of single-CPU runners, each GitHub-hosted runner is a new virtual machine (VM) hosted by GitHub" |

**What it means not to have hardware support.** A machine that does not trap every sensitive act can host guests only in software, and it is slow where the hardware would be fast. In the monitors of that kind, "VMMs typically construct shadow page tables in which to run the guest" (Adams and Agesen): copies of the guest's page tables that the hardware really walks, kept in step "by tracing the guest's own". The guest's page-table writes are then each a trap, and in VMware's software monitor "an extra privilege transition" made a guest system call cost "approximately 2000 more cycles than a native system call". The systems in the table above lean on hardware: the Linux x86 `KVM` option is for a processor "equipped with virtualization extensions", and OpenBSD's `vmm(4)` "requires at least one CPU with hardware-assisted virtualization capabilities". The pdp64 therefore builds the support in from the first version: every privileged act traps, memory is translated in two stages by the hardware walker, and interrupts and the timer are virtualized in hardware.

**What it costs.** The design adds a state bit and some registers, a second table root and a guest tag in the translation buffer, and virtual interrupt lines and a virtual timer. The scalar core was estimated at 220,000 to 310,000 gates and the vector block at 195,000 to 280,000 (`docs/encoding-work/vec-gates.md`, 2026-11-17); the pieces of virtualization we have counted one at a time in the design notes, and the totals are not yet added. A miss in the translation buffer under two stages needs, in the worst case, nm + n + m page-table entry references for n levels in the guest's tables and m in the second stage (Bhargava, Serebrin, Spadini and Manne 2008): 15 for three levels at each stage, against 3 for one stage.

## PASTE ENDS: section 6.14

---

## PASTE BEGINS: section 6.15

## 6.15 A guest, step by step: nine events

The examples follow one guest kernel, which we call G, running under one hypervisor, on one core. The code is **an illustration written for this chapter**, adapted from our first hypervisor test (it is real code that runs on the QEMU target, shortened); the registers and the instruction `GENTER` are the ones that section 6.16 defines. Each example says what the hardware does, what the hypervisor does, and what the guest sees.

**Example 1. The life of a guest.** When a machine with a hypervisor starts, the hypervisor runs first, at the hypervisor level, with its own vector table and on physical addresses (this is the state bit `H` of 6.16: "`H` = 1 means the hypervisor is running"). A native operating system on such a machine is simply a guest. The hypervisor has four things to do before the first guest instruction.

It builds the guest's second-stage tables: a three-level tree of the same page-table entries as 6.7, mapping guest-physical memory to real memory. It writes the register `GTBR` with the root of that tree, a switch that turns stage 2 on, and a 16-bit **guest tag**, a number that every translation made for this guest will carry, so that the translation buffer can hold several guests at once and each is invalidated on its own. It writes the trap-control register `HTRAP`, the list of events that must exit (which of the guest's privileged acts it wants to see; example 2 says which are on by default). And it writes where the guest starts, into `HEPC` (the hypervisor's "exception program counter": where the guest resumes) and `HEPSW` (the guest's starting status word).

```
        lea     htab, r1
        mtsr    hvbr, r1            ; where the hypervisor's own vector table is
        lea     hroot, r1           ; the guest's stage-2 root ...
        movq    =(1<<GTBR_S2EN | 5<<GTBR_TAG), r2
        bis     r2, r1              ; ... with stage 2 on and the guest tag 5
        mtsr    gtbr, r1
        movq    =(1<<HTRAP_WFE | 1<<HTRAP_PTBR), r1
        mtsr    htrap, r1           ; exit on WFE and on writes of PTBR
        lea     guest_entry, r1
        mtsr    hepc, r1
        movq    #0, r1
        mtsr    hepsw, r1           ; kernel mode, priority 0
        genter                      ; the guest starts
```

`GENTER` ("guest enter") is the one new instruction. It is to the hypervisor what `RTI` is to a kernel returning to a user program: it loads the status word from `HEPSW` and the program counter from `HEPC`, switches to the guest's own stack pointer and thread pointer, and clears the state bit. From the next instruction on, G is running at the kernel level of its own machine, and what it executes is executed by the real processor, not by the hypervisor. Nothing slows it down. G does not know that a second stage of translation is between it and memory.

**Example 2. A guest kernel does something privileged.** G is idle. Like a V7 kernel with nothing to run, it executes the instruction that waits for an event, `WFE`. On a real kernel this puts the core to sleep. Under a hypervisor the core is the hypervisor's to share.

What the hardware does, in order. It checks that the instruction is allowed in G's own mode, as it would for any kernel; G is at kernel level, so yes. It looks in `HTRAP`: the bit for `WFE` is set (it is set at reset), so this instruction is one that exits. The hardware records the guest's state in the hypervisor's registers: `HEPC` gets the address of the instruction after the `WFE` (the exit is a trap, so the instruction counts as done); `HEPSW` gets the guest's whole status word; `HEXITR`, the **exit-reason register**, gets the code for `WFE`. It sets the state bit, switches the stack pointer to the hypervisor's, sets the priority to 7, and reads a one-word entry from the hypervisor's own vector table. The hypervisor's handler is running; the guest has not been told.

The hypervisor reads `HEXITR` to see why. It saves nothing for the guest that the hardware has not, except what it is about to change. For `WFE` the answer is: this virtual core has nothing to do, so mark it idle and run another guest; or, if nothing else is runnable, put the real core to sleep. When the guest has a virtual interrupt pending, the hypervisor enters it again with `GENTER`, and G resumes after its `WFE`, as if it had slept.

```
hx:     mfsr    r20, hexitr          ; why did the guest stop?
        cbeq    r20, #XCODE_WFE, h_idle
        cbeq    r20, #XCODE_HALT, h_halt
        ...
h_idle: ; mark guest 5 idle, run someone else, or sleep; later:
        genter
```

Two points are worth stopping on. The first is that some privileged acts of G do **not** exit. If G writes its page-table base register, `PTBR`, with the bit for `PTBR` in `HTRAP` clear, the write is simply G's own: the guest's page tables are walked by the hardware, and the hypervisor is not involved. (A machine that has no second stage must trap every such write and keep shadow copies of the guest's tables; section 6.14 gave the cost.) The bit exists so that a hypervisor that wants to see the writes (to count them, or to emulate something) can ask. The second point is that a few things always exit and cannot be turned off, because no guest could handle them: `HALT` is the first. A guest that executes `HALT` means "stop this machine". The hypervisor decides what that means: stop the guest, or power the virtual machine down, or reset it.

**Example 3. A hypercall.** Sometimes G wants something from the hypervisor on purpose: to print a character through the hypervisor's console, to ask for more memory, to tell the hypervisor "this page is free". This is a **hypercall**, the analogue of a system call one level up: as `TRAP #n` is the system call from a user program to a kernel, so a `TRAP` can be the call from a guest kernel to the hypervisor. There is no new instruction. The hypervisor sets a mask in `HTRAP` that routes a range of `TRAP` numbers to itself: bit k of the 8-bit mask routes the thirty-two numbers 32k to 32k + 31.

Say bit 1 is set and G executes `TRAPL #40`. Number 40 is in 32 to 63, so the trap does not go to G's own vector table; it exits. The instruction is complete, so `HEPC` is the next instruction; the exit-reason register says "hypercall"; and the hypervisor's vector is 256 + 40, so the hypervisor's table has one entry for each hypercall number, as the kernel's has one for each system call. The arguments are in registers, as for a system call. The hypervisor does the work, puts the result in `R0`, and executes `GENTER`. G's own system calls, which are `TRAP` numbers outside the routed range, never leave the guest: a user program of G that makes a system call enters G's kernel directly, as on a machine with no hypervisor.

**Example 4. A guest page fault, and a second-stage fault.** Here the two stages show. The page-table entries and the walk are those of 6.6 and 6.7: three levels of nine bits over 4 KB pages. Say G, with translation on, loads from the guest-virtual address `0x403A58`.

Cut it into its fields. Address bits 38 to 30 are 0, so the top-level index is 0. Bits 29 to 21: `0x403A58 >> 21` is 2, so the next index is 2. Bits 20 to 12: `(0x403A58 >> 12) & 0x1FF` is `0x403 & 0x1FF`, which is 3, so the last index is 3. The offset in the page is `0xA58`. G's own tables, which it keeps in what it believes is physical memory, end in an entry for page 3 that says: the page is at guest-physical page `0x123`. So the guest-physical address is `0x123A58`. That is the answer of stage 1.

Stage 2 takes `0x123A58`, cuts it the same way, and walks the hypervisor's tables. Say they say guest-physical page `0x123` is at real page `0x8F7`. The real address is `0x8F7A58`, and the load happens there. The translation buffer remembers the whole result (guest-virtual page `0x403` for guest tag 5 goes to real page `0x8F7`) so the next load from that page costs nothing. A miss costs more than in a one-stage machine, because each of G's own table entries is itself at a guest-physical address that needs stage 2: three entries at three levels each, plus the last step, make 15 table reads against 3.

Now two things can go wrong, and the hardware tells them apart.

*If G's own entry for page 3 is not valid,* it is G's fault, and only G's. The hardware takes the page fault in the guest: G's `EPC`, `EVA` and `ECAUSE` are written, and G's own kernel handles it, as a V7 kernel handles a page fault in `trap()`. No exit, no hypervisor, no instruction run. This is why a guest's ordinary virtual memory costs the hypervisor nothing.

*If G's entry is fine but the hypervisor's stage 2 has no entry for guest-physical page `0x123`,* it is the hypervisor's matter: G believes the memory exists. The hardware makes an exit. It writes `HEPC` with the instruction itself (it did not complete, so it will be run again), `HEVA` with the guest-virtual address `0x403A58`, and `HGPA`, the **guest-physical fault address**, with `0x123A58`. The reason register says "second-stage fault, entry invalid". The hypervisor can now do its job: find a real page, write the stage-2 entry, tell the hardware (with the invalidate that 6.16 says is needed if the entry was valid before), and `GENTER`. G runs the same load again; this time it succeeds. G has no idea that anything happened; that is the whole of "demand paging for a guest". If the hypervisor decides that G has no right to that page, it can instead inject a fault into G, or stop G.

**Example 5. A timer tick for the guest, and a device interrupt.** A V7 kernel has the line clock at vector 0100 at priority 6; each tick enters `trap()` and calls `clock()`. G needs the same: a clock that ticks. Three pieces make it.

The hypervisor offers G a **virtual timer**: the guest reads a counter that is the real counter minus an offset the hypervisor chose (so the guest's time starts where the hypervisor says), and arms a comparator; when the counter reaches the comparator's value, the hardware raises **virtual interrupt line 6**, the line for the clock's priority. The hypervisor has, besides, the real timer, which keeps running at the hypervisor level: its expiry is a physical interrupt, and it is how the hypervisor itself gets control to schedule guests.

A **virtual interrupt line** is one bit in the register `VIRQ`, set by the hypervisor (for a device it emulates) or by the timer hardware. There are seven, one for each priority from 1 to 7. Between two instructions of G, if the highest pending line is above the priority in G's status word, the hardware makes G's own exception entry, with the vector number the hypervisor put in `VIVEC` for that line, and clears the line's bit. This is the entry of 6.3, run inside the guest, with no exit: `EPC`, `EPSW` and `ECAUSE` are written, the priority goes to 7, and G's handler runs. G's `SPL` and `MTPS` work against these lines in hardware, so G's idea of "interrupts held off" is true and cheap.

A **physical** interrupt is different. An RK11 completing a transfer asserts its line; whatever G's priority is, the interrupt goes to the hypervisor first (an exit, with the reason "physical interrupt" and the line's vector). The hypervisor decides whom it is for. If it is for the hypervisor's own driver, it handles it. If it is for G's virtual disk, it completes the virtual transfer, sets the right bit in `VIRQ`, and enters G; G sees an interrupt, as if its own RK11 had finished. Each physical line stays asserted until the hypervisor clears it at the device, so none is lost.

**Example 6. A guest reset, and why stale translations must not survive.** A guest sometimes needs to be reset: it asks (by a hypercall, or by touching a virtual device) and the hypervisor does it. A reset must make the guest's machine the machine of reset: all registers to the values of a table, memory as the hypervisor chooses, translation off. There is a trap here, and it is a real one.

The translation buffer holds finished translations tagged with the guest's tag. If the hypervisor resets the guest and reuses its tag and its stage-2 root, while the buffer still holds translations made before, the new guest can read the old guest's memory through them. The Linux KVM bug of 2026 (CVE-2026-99312) is of this kind: when KVM emulated an INIT for a nested guest with paging off, it ran the outer guest "with a stale MMU context". The rule, stated in 6.8.5, is: **whatever resets the translation state of a core or a guest must discard its cached translations, in the same step**.

On the pdp64 the hypervisor's reset sequence is therefore written down in order (6.16), and the first thing it does is stop the guest's cores and invalidate by tag; only after that may the tag be given to another guest.

**Example 7. What the hypervisor itself runs on.** The hypervisor is a program too: it has code, data, a stack, and it may have bugs, so it too needs protection from stray pointers. The hypervisor level follows the Arm VHE style from the start: it has a translation regime of its own, so that an ordinary kernel (with its usual page tables) can itself run at the hypervisor level, and a kernel does not have to be split in two halves, one that runs at the kernel level and one that runs above. ("VHE" is Arm's name for the same arrangement; Arm's guide says that without it "most of the Host OS is at EL1, with some stub code running in EL2", an arrangement it calls "inefficient, because it may involve additional context switching".) In the pdp64 the hypervisor level has a page-table base of its own (the design's name for it is `HPTBR`), with tag 0, which is the host's. What is left to define is which of the kernel's translation registers get a copy at the hypervisor level, how their names are redirected there, and what that does to the rules about registers while the hypervisor runs; 6.16 says exactly which statements wait for that definition. Until it is defined, a small hypervisor like the first one of the project may leave its translation off and run on physical addresses.

**Example 8. What is saved and what is cleared at the entry and the exit.** When G exits and the hypervisor enters, the hardware saves very little: G's program counter in `HEPC`, G's status word in `HEPSW`, and the facts about the exit (`HEXITR`, `HEVA`, `HGPA`, `HINSN`: the first words of the instruction that caused it). It switches the stack pointer and the thread pointer to the hypervisor's own, so that the first instruction of the handler has a register that is not G's. Everything else that is G's stays where it was: the registers `PTBR`, `VBR`, `EPC` are G's and the hypervisor must save them if it is going to run another guest (it does so with `MFSR`, like a V7 kernel saving a process's PS). This is deliberate: an exit that does not need to touch G's state is as short as the machine can make it.

What the hardware clears is what could leak. At every exit, and at `GENTER`, the naming of the vector accumulators and any `LL` reservation are cleared, so that what one guest left behind is not found by another. Both `RTI` and `GENTER` carry a **mask**: `RTI #mask` returns with a mask of registers that are to keep their values, and the hardware clears every other register in the same step as the return to a less privileged mode. A kernel that forgets to clear a register it used gives the user program a zero, never a secret. The same mask is on `GENTER`, so that a hypervisor cannot hand G a register of another guest by forgetting.

A vector block interrupted by an exit follows the resume rule: if the same guest is entered again at once with the token the hardware gave at the exit, the block carries on at the strip where it stopped; in every other case (another guest entered, a translation register written) its partial sums are discarded and it starts again from its first strip. Resume is only ever faster, and never changes an answer (6.16.28).

**Example 9. What is not in version 1.** G is a kernel; it cannot be a hypervisor in turn. The first version has **no nested guests**: if G touches any hypervisor register or executes `GENTER`, it exits with the reason "hypervisor register used by a guest", and the hypervisor may make it look to G like an illegal instruction. The reason is the cost and the risk: nested virtualization is known to need many more exits per guest operation (the estimate is in `nested-virtualization-estimate.md`), and a stale-translation bug of the kind of example 6 happened in the nested case. The rule is stated so that it can be lifted without changing the meaning of anything else.

## PASTE ENDS: section 6.15

---

## PASTE BEGINS: section 6.16

## 6.16 The hypervisor mode: the rules

Everything of 6.14 and 6.15 is here as numbered statements and tables.

### State and registers

**6.16.1** Virtualization is part of the architecture: a hypervisor can run guest operating systems, each at the kernel level of its own machine.

**6.16.2** Every instruction that reveals or changes the real state of the machine either traps to the hypervisor when a guest runs it, or is harmless. No unprivileged instruction reads a clock, a counter or the identity of the core; if one is ever added it has a trap-control bit. No system register is readable outside kernel mode.

**6.16.3** The hypervisor mode is one state bit, **`H`**, inside the core, not in the status word and not in any register a program can read. `H` = 1 means the hypervisor is running; `H` = 0 means anything else. Only the hardware changes `H`: an exit sets it and `GENTER` clears it. The reserved mode value 2 stays reserved, so `MFPS`, `MTPS`, `RTI` and `EPSW` do not change and a guest cannot see the mode. Whether the machine has a hypervisor is a property of the machine, the **strap `HVE`**, which no program can change. With `HVE` = 0 the machine is the machine of chapters 1 to 9 without this section: `H` is always 0, every register of 6.16.7 and `GENTER` is an illegal instruction. With `HVE` = 1, `H` is 1 at reset, so the first software to run is the hypervisor (or firmware that starts it).

**6.16.4** While `H` = 1: *(a)* an exception, a trap or an interrupt that the hypervisor takes uses the hypervisor's registers and vector base (`HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HVBR`) and sets `HEXITR` to 0, and never touches `EPC`, `EPSW`, `EVA` or `ECAUSE`; *(b)* `RTI`, `RTT`, `PUSHX` and `POPX` name `HEPC` and `HEPSW` in place of `EPC` and `EPSW`; *(c)* the priority is the priority field of the status word, which an exit sets to 7 and the hypervisor lowers with `SPL` after it has saved `HEPC` and `HEPSW`; *(d)* every privileged instruction is allowed, whatever the mode field says; *(e)* no virtual interrupt line is delivered; a physical interrupt is taken, as in 6.3, if its level is above the hypervisor's priority; *(f)* a reserved mode value in `HEPSW` is refused with an illegal instruction when it is used, by `GENTER`, `RTI` or `RTT`, not when it is written.

**6.16.5** The hypervisor level translates its own addresses, in the Arm VHE style, from the first version, so that its kernel needs no split. It has its own translation regime: one page-table base (the design's name is `HPTBR`) with the tag of the host, 0, one stage only, and an enable; a guest's translation-buffer entry never answers a hypervisor access.

**6.16.6** There is a fourth copy of `R14` and of `DP`, the hypervisor's own, so that the first instruction of an exit handler has a register that is not the guest's. An exit puts the live `R14` and `DP` of the guest's current mode in their places and switches to the hypervisor's copy; `GENTER` switches back to the copies of the guest's current mode. After a machine reset the kernel stack register is set by the boot protocol of the platform (chapter 4).

**6.16.7** The registers of the hypervisor are system registers (6.5) numbered 128 to 147; they are reached only at `H` = 1. A guest's `MFSR` or `MTSR` of an assigned number exits with exit code 18, after the guest's own privilege check (6.16.9); on a machine with `HVE` = 0 it is an illegal instruction; an unassigned number is an illegal instruction. The five registers marked read only refuse a write with an illegal instruction. In every register **a write of a one to a bit that is not in use is refused** with an illegal instruction, and such a bit reads as zero. After a machine reset every register is zero except `HTRAP`, which has `WFE` and `SEV` set. `HVBR` is **page aligned**: a write with a nonzero low twelve bits is refused.

| Number | Name | Width in use | Access | What it holds |
|---|---|---|---|---|
| 128 | `HTRAP` | 24 bits | read, write | trap control (6.16.8) |
| 129 | `HEXITR` | 11 bits | read only | exit reason: code in bits 7 to 0, flags in bits 10 to 8 (6.16.14) |
| 130 | `HEPC` | 64 | read, write | the guest's program counter at an exit; where `GENTER` resumes |
| 131 | `HEPSW` | status word | read, write | the guest's status word at an exit; the one `GENTER` loads |
| 132 | `HEVA` | 64 | read only | the guest-virtual address of the access that caused the exit, else 0 |
| 133 | `HCAUSE` | 9 bits | read only | the vector number of the exit (6.16.15) |
| 134 | `HGPA` | 40 bits | read only | the guest-physical address that stage 2 could not translate, else 0 |
| 135 | `HINSN` | 32 bits | read only | the first two parcels of the instruction that caused the exit, else 0 |
| 136 | `HVBR` | 64 | read, write | base of the hypervisor's vector table (page aligned) |
| 137 | `GTBR` | 64 | read, write | stage-2 enable, root and guest tag (6.16.20) |
| 138 | `VIRQ` | 8 bits | read, write | virtual interrupt lines, pending; bit 0 reads zero (6.16.24) |
| 139 | `VIVEC` | 56 bits | read, write | the vector number of each virtual line (6.16.24) |
| 140 | `VTOFF` | 64 | read, write | virtual timer offset (6.16.25) |
| 141 | `VCPUID` | 16 bits | read, write | the guest's virtual core number (6.16.13) |
| 142 | `GEVA` | 64 | read, write | write alias of the guest's `EVA` |
| 143 | `GECAUSE` | 64 | read, write | write alias of the guest's `ECAUSE` |
| 144 | `GKSP` | 64 | read, write | the guest's `R14` of the kernel mode |
| 145 | `GKDP` | 64 | read, write | the guest's `DP` of the kernel mode |
| 146 | `GSDP` | 64 | read, write | the guest's `DP` of the supervisor mode |
| 147 | `GUDP` | 64 | read, write | the guest's `DP` of the user mode |

`EVA` and `ECAUSE` are read only (6.5), and no existing register reaches the kernel-mode `R14` or any `DP`, so the hypervisor restores a guest's `EVA` and `ECAUSE` through `GEVA` and `GECAUSE` and its banked registers through `GKSP`, `GKDP`, `GSDP` and `GUDP`. `HINSN` lets the hypervisor emulate a trapped instruction without reading guest memory through the guest's tables.

### Trap control

**6.16.8** `HTRAP` is the trap-control register. A set bit sends its event to the hypervisor as an exit; a clear bit leaves the event to the guest, or to a form of the hardware scoped to the guest. Bit 15 and bits 24 to 63 are reserved (6.16.7).

| Bit | Name | The event (exit code of 6.16.14) | When the bit is clear | Reset |
|---|---|---|---|---|
| 0 | `WFE` | `WFE` (3) | the guest sleeps | 1 |
| 1 | `SEV` | `SEV` (4) | `SEV` is the guest's | 1 |
| 2 | `PAUSE` | `HINT #1` (5) | a no-op | 0 |
| 3 | `PRIO` | `SPL` and a changing `MTPS` (6) | the priority is the guest's virtual priority | 0 |
| 4 | `TLBI` | `TLBI` (7) | the invalidate acts on the guest's own tag (6.16.22) | 0 |
| 5 | `TLBIA` | `TLBIA` (7) | as above | 0 |
| 6 | `TLBSYNC` | `TLBSYNC` (7) | as above | 0 |
| 7 | `ASID` | `MTASID`, `MFASID`, `MTSR` and `MFSR` of `ASID` (8) | the tag keeps the numbers apart | 0 |
| 8 | `PTBR` | a write to `PTBR` (9) | the guest's own register | 0 |
| 9 | `MMUCTL` | a write to `MMUCTL` (10) | the guest's own register | 0 |
| 10 | `VBR` | a write to `VBR` (11) | the guest's own register | 0 |
| 11 | `CPUID` | `MFCPUID`, `MFSR CPUID` (13) | `VCPUID` is returned (6.16.13) | 0 |
| 12 | `ICINV` | `ICINV`, `ICINVA` (14) | they execute (6.16.11) | 0 |
| 13 | `BPT` | `BPT` (15) | the guest's own breakpoint exception | 0 |
| 14 | `STEP` | an exit after each guest instruction (16) | none | 0 |
| 15 | | reserved | | 0 |
| 16 to 23 | `TRAPMASK` | `TRAP #n` and `TRAPL #n`, bit k for the numbers 32k to 32k + 31 (17) | the guest's own system call (6.16.10) | 0 |



**6.16.9** Some events have no bit in `HTRAP`. These **always exit**: `HALT` (6.16.10); `MTDMW` and `MTSR` and `MFSR` of `DMW0` and `DMW1` (6.16.12); `PROBER` and `PROBEW` that meet a stage-2 miss (6.16.19); any use of a hypervisor register or of `GENTER` (6.16.27); every stage-2 fault, a stage-2 miss on the vector fetch or the page-table walk, and a machine check (6.16.21); and every physical interrupt (6.16.23). These are **the guest's own** and never exit: an illegal instruction, a privileged instruction, the page faults and protection faults of stage 1, `TRAPCC` and the overflow checks, `TRAP #n` outside the routed range, an unassigned system-register number, and `ISYNC`. The guest's own privilege check comes first: an instruction that the guest's current mode may not execute (`WFE` in a guest's user mode) raises the guest's privileged-instruction exception, vector 3 in the guest, and never reaches `HTRAP`.

**6.16.10** `HALT` always exits (exit code 2). A range of `TRAP #n` and `TRAPL #n` numbers is routed to the hypervisor by the 8-bit **hypercall mask** in bits 16 to 23 of `HTRAP`: bit k routes the numbers 32k to 32k + 31. That is the hypercall; it has no opcode of its own. A routed `TRAP` is a trap: the instruction completes, `HEPC` is the next instruction, the exit code is 17, and the vector in `HCAUSE` is 256 + n. It is routed at any guest mode. The mask is zero at reset. `WFE` traps by default and may be untrapped for a guest that owns a core; `SEV` traps by default so that the hypervisor limits it to the cores of the guest.

**6.16.11** `ICINV` and `ICINVA` stay unprivileged and untrapped: they do not touch data, and a program that generates code needs them. The bit `ICINV` of `HTRAP` traps them, and is set only if timing between guests is a concern.

**6.16.12** `MTDMW` and the direct-mapping windows `DMW0` and `DMW1` always exit (exit code 12) when a window takes effect: `MTDMW`, and `MTSR` and `MFSR` of `DMW0` and `DMW1`. A window takes effect over real physical memory, so no bit turns the exit off.

**6.16.13** `MFCPUID` is privileged. Each guest has a virtual core number, set by the hypervisor in `VCPUID` (16 bits). When a guest runs, `MFCPUID` and `MFSR CPUID` return `VCPUID`; at `H` = 1 they return the real core number. If the `CPUID` bit of `HTRAP` is set they exit instead (exit code 13).

### Exits, entry and what is saved

**6.16.14** `HEXITR` says why the guest stopped, finer than the vector. The code is in bits 7 to 0 and three flags are in bits 10 to 8. `HEPC` is the address of the next instruction for a trap and an interrupt, and the address of the instruction for a fault (it is run again).

| Code | Reason | `HCAUSE` (vector) | `HEPC` is |
|---|---|---|---|
| 0 | an event taken at `H` = 1 (the hypervisor's own, not an exit) | its vector | as in 6.3.1 |
| 1 | physical interrupt | the line's vector (32 to 63; 64 to 255 when message-signalled) | next instruction |
| 2 | `HALT` | 17 | next |
| 3 | `WFE` | 17 | next |
| 4 | `SEV` | 17 | next |
| 5 | `HINT #1` | 17 | next |
| 6 | `SPL` or `MTPS` priority change | 17 | next |
| 7 | `TLBI`, `TLBIA` or `TLBSYNC` | 17 | next |
| 8 | address-space register (`MTASID`, `MFASID`, `ASID` by `MFSR` or `MTSR`) | 17 | next |
| 9 | write to `PTBR` | 17 | next |
| 10 | write to `MMUCTL` | 17 | next |
| 11 | write to `VBR` | 17 | next |
| 12 | direct-mapping window | 17 | next |
| 13 | core number | 17 | next |
| 14 | `ICINV` or `ICINVA` | 17 | next |
| 15 | `BPT` | 17 | next |
| 16 | single step | 17 | next |
| 17 | hypercall (`TRAP` or `TRAPL` routed) | 256 + n | next |
| 18 | hypervisor register or `GENTER` used by a guest | 17 | next |
| 19 | stage-2 fault: the entry is invalid; **or** a read of a stage-2 table that **no device answered** (flag `NODEV`) | 18 (instruction fetch), 19 (load), 20 (store) | the instruction |
| 20 | stage-2 fault: the entry refuses the access (permission, a reserved bit set, accessed or dirty clear) | 18, 19, 20 | the instruction |
| 21 | machine check in a guest: a bus error on a guest's real access, **or a read of a stage-2 table that a device answered with an error** | 1 | the instruction |

The split of a bus error on a stage-2 table read is by what the bus says: no device answered at the address, the entry points at nothing, which is an invalid entry (code 19, flag `NODEV`); a device answered with an error, which is a machine check (code 21). Flags: bit 8 `WALK`: the failing access was the read of a guest page-table entry, so `HGPA` is the guest-physical address of that entry and `HEVA` the address the guest was trying to reach; bit 9 `VEC`: it was the guest's vector fetch, so `HGPA` is the guest's `VBR + 8 * vector`; bit 10 `NODEV`: the failing stage-2 table read found no device.

**6.16.15** An exit enters the hypervisor through a **vector table** of 8-byte entries at the physical address `HVBR + 8 * HCAUSE` (read through the hypervisor's own translation when it is on, 6.16.5), the same fetch as the kernel's (6.3.3). The vectors are:

| Vector | Meaning |
|---|---|
| 17 | an exit for an instruction (all codes 2 to 16 and 18) |
| 18 | guest-physical instruction fault (a stage-2 fault on an instruction fetch) |
| 19 | guest-physical load fault |
| 20 | guest-physical store fault |

**6.16.16** `GENTER` enters a guest. Before it the hypervisor, at `H` = 1, loads the guest's state (6.16.18) and writes `HEPC` and `HEPSW`. `GENTER` includes an `ISYNC` (6.5.2), loads the status word from `HEPSW`, switches `R14` and `DP` to the copies of the guest's current mode, loads the program counter from `HEPC` and clears `H`. **It carries the same mask as `RTI`** (`GENTER #mask`): the registers whose bits are zero are cleared in the same step. If a virtual interrupt line is pending and above the guest's priority, it is taken at the boundary before the first guest instruction.

**6.16.17** An exit is made in this order. *(1)* An event that aborts an instruction is undone (6.4). *(2)* The reason and the vector are decided and the word at `HVBR + 8 * HCAUSE` is read; a bus error here is a machine check of the hypervisor and nothing has been changed. *(3)* `HEPC` is written with the address of the instruction (an abort) or of the next instruction (a trap or an interrupt); `HEPSW` with the guest's whole status word; `HEVA`, `HGPA` and `HINSN` as the table of 6.16.14 and 6.16.7 say, else 0; `HEXITR` and `HCAUSE`. *(4)* `H` is set. The status word is made as in 6.3.2: the current mode kernel, the previous mode the guest's current mode, priority 7, the trace bit, the flags and the guard clear. The guest's `R14` and `DP` of its current mode are kept in their places and the hypervisor's copies are loaded. *(5)* The naming of the vector accumulators and any `LL` reservation are cleared, and the vector block's resume record is made as 6.16.28 says. *(6)* The program counter is the word read in step 2. Not written: `EPC`, `EPSW`, `EVA`, `ECAUSE`, `PTBR`, `VBR`, `MMUCTL`, `ASID`, `USP`, `SSP`, `DMW0`, `DMW1`, the general registers and the floating-point status; they are the guest's. Not done: no translation-buffer entry is removed and `GTBR` is not changed. A stage-2 fault on the vector fetch of the instruction's own entry (`TRAP`, `BPT`, a check trap) is an exit with `HEPC` at the instruction: it is retried.

**6.16.18** At a world switch (an exit followed by the entry of a guest) the hardware saves and loads only the guest's program counter, its status word and the switch of `R14` and `DP`. The hypervisor saves and loads the rest in software:

| What | How the hypervisor reaches it |
|---|---|
| `PTBR`, `EPC`, `EVA`, `ECAUSE`, `DMW0`, `DMW1`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID` | `MFSR` and `MTSR`; `EVA` and `ECAUSE` are written through `GEVA` and `GECAUSE` |
| `R14` of the kernel mode and `DP` of the three modes | `GKSP`, `GKDP`, `GSDP`, `GUDP` |
| the general registers other than `R14` | ordinary loads and stores |
| the floating-point status | `FSFLAGS`, an unprivileged instruction |
| `HTRAP`, `GTBR`, `VIRQ`, `VIVEC`, `VTOFF`, `VCPUID` and the timer registers of 6.16.25 | `MFSR` and `MTSR` |

### Translation in two stages

**6.16.19** Translation of a guest's memory is in two stages in hardware: the guest's page tables (**stage 1**) turn a guest-virtual address into a guest-physical address, and a second set of tables (**stage 2**), with a second root, turns that into a physical address (6.16.20). A guest tag in each translation-buffer entry lets one guest's entries be invalidated without the rest (6.16.22); a fault in the second stage is an exit that reports the guest-physical address. The vector fetch and the page-table walk of a guest go through the second stage too, and a second-stage miss on either is an exit, not a machine check. `PROBER` and `PROBEW` in a guest test both stages; a second-stage miss exits (code 19 or 20) and the probe runs again after the hypervisor has filled it; a stage-1 miss gives the probe's ordinary answer.

**6.16.20** `GTBR` holds the whole of stage 2's identity in one register, so that one write changes the root and the tag together. Bit 0 is `S2EN` (stage 2 on; with it clear the guest-physical address equals the physical address); bits 39 to 12 are the physical page number of the stage-2 root; bits 63 to 48 are the **guest tag**, 16 bits, 0 being the host; the other bits are refused (6.16.7). A **stage-2 entry** is the page-table entry of 6.7 with `U` and `G` required to be zero; a set `U` or `G` is a refused entry. Stage 2 has three levels of 512 entries over a root of two consecutive pages, so that it covers the 40-bit guest-physical space. The accessed and dirty bits of stage 2 are managed by software like stage 1's (6.8.1): a clear `A`, or a clear `D` on a write, is a refused entry, code 20, which gives the hypervisor dirty-page tracking. The permissions of an access are those of both stages together, the size of the page that the buffer holds is the smaller of the two, and **the stricter memory category of the two stages wins**: the order, strictest first, is device strongly ordered, device weakly ordered, uncached, cached. Which physical ranges are devices is given by the **platform map** of device ranges, which replaces the old device bit of the address.

| Bits of `GTBR` | Field | Meaning |
|---|---|---|
| 0 | `S2EN` | stage 2 on |
| 39 to 12 | root | physical page number of the stage-2 root |
| 63 to 48 | `GTAG` | the guest tag; 0 is the host |
| the rest | | zero (a write of a one is refused) |

**6.16.21** What stage 2 does for each access of a guest. A guest page-table entry that stage 1 reads has a guest-physical address, which goes through stage 2 before it is read, and so does the final guest-physical address; with n levels in stage 1 and m in stage 2 a miss reads nm + n + m entries (15 for three and three), and a guest with its translation off walks stage 2 only. A stage-2 entry that is invalid or refuses the access is an exit: code 19 or 20, with `HCAUSE` 18, 19 or 20 for an instruction fetch, a load or a store; `HEPC` is the faulting instruction, `HEVA` the guest-virtual address, `HGPA` the guest-physical address that failed (for a table read, the address of the entry and the flag `WALK`; for the vector fetch, the guest's `VBR + 8 * vector` and the flag `VEC`) and `HINSN` the instruction. The hypervisor fills or corrects the entry, sets `A` and, for a write, `D`, invalidates for the guest if the entry was valid before (6.16.22), and enters; the guest runs the instruction again. The same holds for a miss inside an exception entry of the guest: the instruction is undone. On the vector fetch of a guest's exception or interrupt, a miss exits with nothing changed, so that the guest takes the exception after the fill; a virtual line stays pending.

**6.16.22** Each translation-buffer entry is keyed by the guest tag, the address-space number, the guest-virtual page and the global bit, and holds the final physical page and the permissions of both stages. A hit needs the tag to match, and the global bit means global within the tag. While a guest runs the buffer uses the tag in `GTBR`. An invalidate acts as follows. *(a)* A guest's own `TLBI`, `TLBIA`, `TLBSYNC` and `MTASID`, when not trapped, act on entries of its own tag only, on every core. *(b)* The rules of 6.8.4 and 6.8.5 apply per tag. *(c)* A write to `GTBR` that changes the root or `S2EN` discards every entry of the tag it writes; a write that changes only the tag discards nothing. *(d)* **`TLBIAS`** (invalidate by address-space number) exists: it invalidates every entry of an address-space number, in the issuer's tag, on every core, waited for by `TLBSYNC`. *(e)* **An invalidate by guest-physical page is a separate mnemonic**, used by the hypervisor after a change to a stage-2 entry; the hypervisor's `TLBI` of the guest-virtual form is not used for that. A change to a stage-2 entry that was valid is followed by an invalidate for the guest and `TLBSYNC`. As in 6.8.4 an implementation may discard more than these rules require, and no program may depend on an entry surviving.

### Interrupts, timer, devices, nesting

**6.16.23** A physical interrupt always exits (exit code 1), whatever the guest's priority; the vector of the highest line (the highest level, then the lowest vector number) is in `HCAUSE` and the next instruction in `HEPC`; the line stays asserted until the hypervisor clears it at the device.

**6.16.24** A guest sees seven **virtual interrupt lines**, one for each priority level 1 to 7. `VIRQ` bit L, for L from 1 to 7, says line L is pending; bit 0 reads zero. `VIVEC` has a field of 8 bits for each line (line 1 in bits 7 to 0, line 7 in bits 55 to 48) that holds the vector number the guest takes; **a write that puts a vector below 32 in a field is refused at once**. The hypervisor injects an interrupt by setting the bit of the line. Between two instructions of a guest, if no physical interrupt is asserted and the highest pending line L is above the priority in the guest's status word, the core makes the guest's own exception entry (6.3) with the vector of the line: the vector word is read at the guest's `VBR + 8 * vector` through stage 2, `EPC` is the next instruction, `EPSW` the old status word, `EVA` 0, `ECAUSE` the vector, the new status word is kernel mode with priority 7, and the hardware **clears the bit of the line**. No exit is made. A guest's `SPL` and `MTPS` never exit (unless `PRIO` of `HTRAP` is set). A physical interrupt at the same boundary exits first. `WFE` in a guest ends when a virtual line is pending, even if the priority masks it (7.10.2).

**6.16.25** The guest has a **virtual timer**: a counter that is the real counter minus the offset `VTOFF`, and an alarm that sets virtual line 6 when it expires; the alarm **fires once each time it is armed**. The hypervisor's own timer is the real one, at level 6 and vector 32 as in 6.3.6, and keeps running while a guest runs. No unprivileged instruction reads a clock (6.16.2).

**6.16.26** A device can be assigned to a guest through the IOMMU of 2.11. In version 1 the guest's unit is virtual and trapped: the hypervisor forwards the guest's commands and faults, and there is no guest-visible hardware ring.

**6.16.27** There is no nested virtualization in version 1: a guest's use of any hypervisor register or of `GENTER` exits with code 18, after the guest's own privilege check, and the hypervisor may make it look like an illegal instruction.

### Vector blocks, reset, first software

**6.16.28** A vector block that an exception or an exit interrupts **resumes where possible**. The hardware keeps one hidden **resume record** for each core: the address of the block's `VEC`, the tag of the context (guest tag, address-space number, mode, and whether the hypervisor is running), the entry and current values of the changed registers, and a one-use token. The block resumes at the strip where it stopped only if the return carries the record's token, goes to the address of the `VEC`, has the record's context, and finds the changed registers at their entry values. The record is discarded, and the block starts again from its first strip, on: any vector instruction that is not a resume; a write to `ASID`, `PTBR`, `MMUCTL` or `GTBR`; `GENTER` into another guest; `ICINV`, `ICINVA`, `TLBI`, `TLBIA`; a return that presents the token but fails a check; a machine check; a later suspension; reset. A block covers at most **256 strips**; a longer job is cut into blocks. `VCLR` outside a block is refused: **`VCLR` is valid only inside a block**. A world switch, every exception entry and every return clear the naming of the vector accumulators and any `LL` reservation.

**6.16.29** The table gives, for every register and for the state that is not in a register, what a core holds after a machine reset and what the hypervisor puts a guest in by a guest reset. A guest after a guest reset is a machine after a machine reset, except that the hypervisor's registers keep the hypervisor's values and `CPUID` returns the guest's virtual core number.

| Register | After a machine reset | After a guest reset |
|---|---|---|
| status word | kernel mode, previous mode kernel, priority 7, trace 0, flags 0, guard 0 | the same |
| `PC` | the platform's reset entry | the guest's reset entry, in `HEPC` |
| 0 `PTBR`, 1 `EPC`, 2 `EVA`, 3 `ECAUSE`, 4, 5 `DMW0`, `DMW1`, 6, 7 `USP`, `SSP`, 8 `EPSW`, 9 `VBR`, 10 `MMUCTL`, 11 `ASID` | 0 (translation off) | 0 (`EVA` and `ECAUSE` through `GEVA` and `GECAUSE`) |
| 12 `CPUID` | the core number | `VCPUID` |
| `R14` of the kernel mode | set by the platform's boot protocol (chapter 4) | set by the hypervisor's boot protocol |
| the other `R14` copies and the three `DP` | 0 | 0 |
| the general registers other than `R14` | 0 | zero, set by the hypervisor |
| the floating-point status | 0 | 0 |
| the naming of the vector accumulators, any `LL` reservation, the resume record | cleared | cleared |
| cached translations of the guest's tag | none | none |
| 128 `HTRAP` | `WFE` and `SEV` set, the rest 0 | the hypervisor's policy |
| 129 to 135 `HEXITR`, `HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN` | 0 | not defined; `HEPC` and `HEPSW` are the resume point |
| 136 `HVBR` | 0 | not a guest's |
| 137 `GTBR` | 0 | the guest's root, `S2EN` set, its tag |
| 138, 139 `VIRQ`, `VIVEC` | 0 | 0 |
| 140 `VTOFF` | 0 | the hypervisor's value |
| the timer | the counter runs, the alarm is not armed | not armed |
| 141 `VCPUID` | 0 | the guest's virtual core number |
| 142 to 147 | 0 | 0 |

The floating-point flags are cleared when the address-space number, the guest register `GTBR` or the page-table base is written.

**6.16.30** There is no hardware event for a guest reset: no instruction resets a guest. A guest asks for a reset by a hypercall or by touching a virtual device, and both exit. The reset is an operation of the hypervisor, in this order. *(1)* Stop the guest's cores. *(2)* For each device assigned to the guest, block it and invalidate the unit's translations for the guest tag (2.11.8), and wait for the unit. *(3)* Write `GTBR` with the new root, or invalidate the tag and `TLBSYNC`; then write `MMUCTL` as 0. *(4)* Write every system register and every other piece of state to the value of the table of 6.16.29. *(5)* Zero the general registers and the floating-point status, set `HEPSW` to the reset status word and `HEPC` to the guest's reset entry, and execute `GENTER`. Only after step 3 may the tag be used by another guest.

**6.16.31** The first software to use all of this is a small hypervisor of our own, on the QEMU target, with one guest kernel; it is not Linux and not KVM.


## PASTE ENDS: section 6.16

---

## PASTE BEGINS: the bullet for section 6.17 (the old 6.15 "What was checked, and what was not"), replacing the bullet "Checked in 6.14"

* **Checked in 6.14 to 6.16** (every sentence quoted was found in the document named, on the date given; quotations are under 25 words):

  * R. J. Creasy, "The Origin of the VM/370 Time-Sharing System", *IBM Journal of Research and Development* 25(5), September 1981, pages 483 to 490. https://lass.cs.umass.edu/~shenoy/courses/fall07/papers/vm370.pdf, read 2026-11-25. "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." "they required a dedicated hardware system, usually at night or on weekends". "CP and CMS have seen continuous production use since 1967." "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware." "The CP/CMS system was conceived in 1964 as a second-generation time-sharing system for the newly announced IBM System/360." The 1966 date of CP-40 and CMS is read from the printed page, where the text extraction misreads the digit; the group is said to be at "the IBM Systems Research and Development Center in the mid-1960s", now the IBM Scientific Center in Cambridge, Massachusetts. "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program."
  * G. J. Popek and R. P. Goldberg, "Formal requirements for virtualizable third generation architectures", *Communications of the ACM* 17(7), July 1974, pages 412 to 421. https://course.ece.cmu.edu/~ece845/docs/p412-popek.pdf, read 2026-11-25. "A virtual machine is taken to be an efficient, isolated duplicate of the real machine." Theorem 1 as quoted in 6.14. "Another example of a control sensitive instruction is JRST 1, on the DEC PDP-10, which is a return to user mode." The key words of the paper include "hypervisor, virtual machine monitor".
  * G. J. Popek and C. S. Kline, "The PDP-11 Virtual Machine Architecture: A Case Study", *Proceedings of the Fifth Symposium on Operating System Principles*, ACM, 1975, pages 97 to 105, doi 10.1145/800213.806527. https://bibtex.github.io/SOSP-1975-PopekK.html, read 2026-11-25: **the bibliographic record only; the text of the paper was not read.**
  * J. S. Hall and P. T. Robinson, "Virtualizing the VAX Architecture", ISCA 1991, page 380 onward (the printed page image was read; the address of the copy was not recorded when it was read on 2026-11-19: to be added). "The VAX architecture contains several instructions that are sensitive but not privileged." "Work on a prototype was begun in 1981 with these goals". "Work was begun using a VAX-11/730." "Digital Equipment Corporation does not sell the VAX security kernel described in this paper." Page 383: "This mode-bit approach is similar in concept to Popek and Kline's modifications to the PDP-11 architecture" (read from a text extraction of the paper, not the page image).
  * K. Adams and O. Agesen, "A comparison of software and hardware techniques for x86 virtualization", ASPLOS 2006 (October 2006). Copy read 2026-11-19 and again 2026-11-25. "Until recently, the x86 architecture has not permitted classical trap-and-emulate virtualization." "both Intel and AMD have now introduced architectural extensions to support classical virtualization". "IBM's System 370 architecture introduced interpretive execution, a hardware execution mode for running guest operating systems." Its references: Intel Virtualization Technology specification, April 2005; AMD "Pacifica" manual, May 2005. The shadow-page-table and system-call sentences of 6.14 were found on 2026-11-19.
  * O. Agesen, J. Mattson, R. Rugina, J. Sheldon, "Software Techniques for Avoiding Hardware Virtualization Exits", USENIX ATC 2012. https://usenix.org/system/files/conference/atc12/atc12-final158.pdf, read 2026-11-25 (note `bench/sources/vm-exit-cycles.md`): Table 1 starts with Intel Prescott, launch date 3Q2005.
  * Arm, "Armv8-A virtualization", Doc ID 102142, Issue 01, 2019 (read 2026-11-19 as a saved PDF; web address not recorded). "Virtualization was introduced in Armv7-A." "This means that most of the Host OS is at EL1, with some stub code running in EL2". "This arrangement can be inefficient, because it may involve additional context switching."
  * RISC-V, privileged architecture, chapter 14.1 '"H" Extension for Hypervisor Support, Version 1.0', in the Ratified Specifications Library, v20260120. https://docs.riscv.org/reference/isa/v20260120/priv/hypervisor.html, read 2026-11-25. "to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". No ratification date was found on the page.
  * *PDP-11 Processor Handbook*, 1979 edition (read 2026-11-19): `HALT` traps outside kernel mode; outside kernel mode "the processor will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation".
  * CVE-2026-99312 (Linux kernel, KVM x86), published 2026-11-18. https://cveawg.mitre.org/api/cve/CVE-2026-99312, read 2026-11-25: "an INIT while L2 is running with CR0.PG=0 will result in KVM running L1 with a stale MMU context".
  * R. Bhargava, B. Serebrin, F. Spadini and S. Manne, ASPLOS 2008 (nm + n + m); the AWS Nitro System security design whitepaper; Microsoft Learn on WSL 2; the Docker Desktop for Mac FAQ; the Android Virtualization Framework page of source.android.com; the QNX operating system and virtualization page; the GitHub documentation of GitHub-hosted runners; the Linux `arch/x86/kvm/Kconfig`; the OpenBSD `vmm(4)` manual page: read on 2026-11-19; their web addresses are not recorded in the manual: to be added.
  * *Not checked, and so not stated:* the date of the PDP-11's announcement; the content of Popek and Kline's paper; the dates of the Arm and RISC-V virtualization extensions; the first use of the word "hypervisor"; industrial controllers as a use; the Android Emulator's use of a hypervisor; the certification of the QNX hypervisor; the name or the operating systems of other PDP-11 systems (the scene of 6.14 names none for that reason); the date of IBM's interpretive-execution mode; seL4's use as a hypervisor (said only because the owner said it).

## PASTE ENDS

---

# The three lists for the owner

## List 1. Every sentence of the current manual that this text replaces, or that becomes wrong

**A. Which numbers change.** *Three sections:* the new 6.14, 6.15 and 6.16 replace the current 6.14; the current 6.15 becomes **6.17**; the citations of 6.15 and 6.14 elsewhere change as listed. *One section (fallback):* the statements are 6.14.1 to 6.14.31, the current 6.15 stays, and the citations below change to the 6.14.N numbers of the same statements.

**B. The current 6.14.** All of it is replaced: the introduction ("What you already know", "Who needs it today", "What it means not to have it", "What it costs") by sections 6.14 and 6.15, and the statements 6.14.1 to 6.14.14 by 6.16. Mapping, old to new: 6.14.1 to 6.16.1; 6.14.2 to 6.16.2; 6.14.3 to 6.16.3 and 6.16.7; 6.14.4 to 6.16.19; 6.14.5 to 6.16.23 and 6.16.24; 6.14.6 to 6.16.26; 6.14.7 to 6.16.27; 6.14.8 to 6.16.29 and 6.16.30; 6.14.9 to 6.16.28; 6.14.10 to 6.16.31; 6.14.11 to 6.16.13; 6.14.12 to 6.16.10; 6.14.13 to 6.16.11; 6.14.14 to 6.16.12.

**C. Sentences elsewhere that name the old numbers or are now wrong:**

1. `06-kernel.md`, line 5: "listed in section 6.14" becomes "listed in section 6.17"; line 7: "(section 6.15)" becomes "(section 6.17)".
2. `06-kernel.md`, 6.1, "User mode may not execute `halt`, `reset`, `wait` or change the priority (*unverified*)": the handbook (read) says `HALT` traps and `RESET` and `SPL` are ignored outside kernel mode. Replace by that, still marking `wait` unverified.
3. `06-kernel.md`, 6.8.5: "or of a guest if the machine ever runs guests" becomes "or of a guest"; "(for a guest see 6.14.8, ...)" becomes "(for a guest see 6.16.22 and 6.16.30, ...)".
4. `06-kernel.md`, 6.8.3 (the `TLBI` text): add that an invalidate by address-space number, `TLBIAS`, exists and that a broadcast carries the issuer's tag; J.6.8, which left the invalidate by ASID open, is now decided for `TLBIAS`.
5. `06-kernel.md`, 6.2.5 (the privileged list): add `GENTER`, and "At `H` = 1 all are allowed (6.16.4)".
6. `06-kernel.md`, 6.3.6 table: the row 17 to 31 "reserved" becomes 17 to 20 "exits to the hypervisor" and 21 to 31 "reserved".
7. `06-kernel.md`, 6.3.7: add that in a guest only the virtual lines are masked by the priority (6.16.23).
8. `06-kernel.md`, 6.5.1: the registers 128 to 147 (and `HPTBR` and `GTIMECMP`, when numbered); the count "243 unused" in the Lineage changes.
9. `06-kernel.md`, 6.12.1: add that with `HVE` the core starts with `H` = 1. 6.13.1, 6.13.3, 6.13.6: add the hypervisor mode, the registers at `H` = 1 and `GENTER`.
10. `06-kernel.md`, **6.13.2 and 6.10.2** say `TRAP` and `TRAPL` both have n up to 255 in two bytes; the older draft said `TRAP` is 0 to 15. Settle before the hypercall example is final (list 3, item 6).
11. `06-kernel.md`, `RTI`: the owner approved `RTI #mask` (errata 204): 6.3.5, 6.13.2 and the `RTI` entry of chapter 9 describe an `RTI` without a mask and become wrong when the mask is written in; the plain `RTI` to a less privileged mode does not exist.
12. **`06-kernel.md` 6.14.9 and `09-isa.md` 9.2.6**: "restarts from the entry of the block" and "no hidden instruction state, except ... restarts from the entry" become wrong: resume is decided (errata 200, 204). 9.2.6 should say that the hidden record exists, is invisible to a program, and is discarded as 6.16.28 says. `implementation-status.md` (the 6.14.9 bullet) is stale in the same way.
13. `02-bus.md`, 2.11.8: "(6.14.4)" becomes "(6.16.22)"; 2.11.2's "(6.14.…)" becomes "(6.16.26)". The sentence "Details to be determined: the width" is wrong: the width is 16 bits (errata 195).
14. `07-smp.md`, 7.10.2: add the virtual lines (6.16.24).
15. `appendix-parts/b-proposed.md`, B.2.11.1: "the statements of 6.14" becomes "the statements of 6.16".
16. `appendix-parts/06-open.md`, J.6.9 (supervisor mode): options 3 and 6 (use it for a hypervisor) are moot because the hypervisor is a state bit (6.16.3). J.6.8: `TLBIAS` decided. J.2.1: add the platform map and the timer. The earlier proposal J.6.13 (memory types) is **not needed**: the stricter category wins.
17. `appendix-b-glossary.md`: add hypervisor, guest, host, exit, hypercall, world switch, stage 1, stage 2, guest tag, `H`, `HVE`, `GENTER`.
18. `tools/mkmanual.py` (lines about 332 and 364: generated text "(6.14, errata 195, 196)"), `tools/manual/isa_part3.py` (notes citing 6.14 and 6.14.11), `tools/manual/kernfigs.py` (comments citing 6.14): the citations change to 6.16 and 6.16.13.
19. `docs/manual-src/06-kernel.md`, the 6.15 bullets: "Unverified" keeps "which instructions the PDP-11 forbade in user mode" only for `WAIT` and the others; the "Checked in 6.14" bullet is replaced by the block above.

## List 2. The figures I propose (the scripts are `tools/manual/*figs.py`; I made none)

1. **The layers.** Three bands: user programs, guest kernels at their own kernel level, the hypervisor; the PDP-11/V7 stack beside it for comparison (kernel under users) and the pdp64 with a hypervisor under two kernels.
2. **A timeline of the history:** 1964 CP/CMS conceived, 1966 CP-40, 1967 production, 1972 VM/370, 1974 Popek and Goldberg, 1975 Popek and Kline, 1981 the VAX prototype, 1991 Hall and Robinson, 2005 to 2006 x86 extensions; Arm and RISC-V shown with no date.
3. **The life of a guest:** a loop of two states, hypervisor and guest, with `GENTER` going in and an exit coming out, and what the hypervisor does in between.
4. **The exit:** the registers written (`HEPC`, `HEPSW`, `HEVA`, `HGPA`, `HINSN`, `HEXITR`, `HCAUSE`) and the vector fetch, in the style of the figure of 6.3.
5. **Which events exit and which stay with the guest:** two columns (always exit; trap-control bit; guest's own), with `WFE`, `HALT`, `PTBR`, `TRAP`, a page fault as examples.
6. **The two-stage walk with the numbers of example 4:** `0x403A58` cut into 0, 2, 3, `0xA58`, the guest-physical `0x123A58`, the real `0x8F7A58`, the stage-2 walk of each guest table entry, and the two kinds of fault in two colours.
7. **A virtual interrupt and a physical one:** timelines, with the priority comparison.
8. **The hypervisor level's translation (VHE style)**, once 6.16.5 is defined: which registers exist at which level.

## List 3. Contradictions and ambiguities the owner must settle

1. **VHE against the older rules.** The accepted design says that at `H` = 1 `MFSR` of `EPC` and `EPSW` reach the guest's registers, that there is a fourth bank of `R14` and `DP`, and that the aliases `GEVA`, `GECAUSE`, `GKSP`, `GKDP`, `GSDP`, `GUDP` exist because of it. An Arm VHE-style level in which an ordinary kernel runs at `H` = 1 with the ordinary register names changes all three (the review calls it a bigger reversal than the one-register regime). I kept the old rules and marked them as waiting (6.16.4, 6.16.5, 6.16.6). The owner should confirm that the register aliases stay, or choose a duplicate of each register at the hypervisor level.
2. **The platform map and the memory category.** "The stricter category of the two stages wins" and "the platform map replaces the device bit" are both approved; whether the platform's category for the physical address is a third term in the comparison (the review's option (a)) was not answered. I stated only the first.
3. **Bus errors on a guest's own access.** The owner's split covers the read of a stage-2 table. Whether a guest's data access to an address that no device answers is a machine check (21), as before, or also an invalid entry (19) is not covered.
4. **The two-page stage-2 root.** The earlier reason was that it covers bit 39, the device-space bit; that bit is gone. The root is two pages for a 40-bit guest-physical space; should it stay, or be one page of 39 bits?
5. **The flush flag.** The owner asked in answers02 whether the flush bit guarantees coherence; `owner-questions.md` says it guarantees nothing alone and that the benchmark study recommends dropping it. The text therefore does not mention a flush flag as decided; item 1 of "Still open" holds the choice.
6. **`TRAP` and `TRAPL`.** 6.10.2 and 6.13.2 give both n up to 255; the earlier notes say `TRAP` 0 to 15. The example of 6.15 uses `TRAPL #40` to be safe.
7. **A third exit flag.** The table of `HEXITR` grows from 10 to 11 bits for the flag `NODEV`; its name and place are my proposal.
8. **Sources whose addresses were not recorded** in the manual: the seven product documents and Arm's guide and the Hall and Robinson copy. The manual's rule is that a checked fact has an address; they need it, or a new reading.
9. **The date of the 1966 CP-40.** The extracted text of Creasy's page prints "1%6" (a scanning error); I read 1966 from the sentence (CP-40 and CP-67 "at about the same time"; the paper's own text says CP/CMS was conceived in 1964 and in use since 1967). If the owner wants a second source for 1966, one is needed.
10. **Resume against 9.2.6.** The decision (resume) and the manual's two statements are inconsistent now (list 1, item 12); the manual needs the design's record text before it can be corrected exactly, and the design's token field in `EPSW` has not been through the owner.
11. **The status of CP/CMS's origin.** The story says "a group led by R. J. Creasy"; Creasy's text says the system was "designed and built by the author and his group". I wrote it in that form; confirm.
