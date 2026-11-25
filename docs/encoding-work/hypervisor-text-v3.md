# Proposed manual text for the hypervisor mode, third version

*For the owner to read before anything is written into the manual. Nothing here is in the manual. This replaces section 6.14 of the manual (`docs/manual-src/06-kernel.md`) and the second version (`hypervisor-text-v2.md`). It keeps the structure the owner approved: the story first (6.14), eleven worked examples (6.15), the rules last (6.16), and the old 6.15 "What was checked, and what was not" renumbered 6.17.*

*The snippets of assembler in the text were assembled with `as64`, and those that can run were run on `sim64`; the sources, the command lines and the results are in `docs/encoding-work/hypervisor-text-v3-snippets/` (its README lists the lines that do not assemble yet).*

*What changed from version 2 is the content, not the shape: every statement now follows the decisions taken since (the complete principles, the re-judged recommendations, the answers of 2026-11-25), the reader is a first-year computer science student of the 1970s who has learned some PDP-11 assembly and has met ITS or TOPS-10 but not necessarily Unix (so every simple term is defined once, at first use, in a sentence or two), and every claim about another system that does not have a recorded address is gone (the three lists at the end say which, so each can come back when its address is recorded). The paste blocks contain no references to errata or decision rows, no status marks, no undecided matters. The preface and the three lists are for the owner and are not pasted.*

*Numbering.* Sections 6.14, 6.15 and 6.16 carry the text; 6.14 and 6.15 carry no numbered statements; every statement is **6.16.N**, numbered 1 to 35 with no gap. The old 6.15 becomes 6.17. If the book check insists that every section has a numbered statement, the fallback is one section 6.14 with the three layers as run-in headings and the statements numbered 6.14.1 to 6.14.35; list 1, item A, says what changes then.

---

## PASTE BEGINS: section 6.14

## 6.14 Running a kernel under a kernel: virtualization

**A hypervisor is a small kernel whose programs are whole operating systems.** This section tells why anyone wants one, who built the first, and how the idea works. Section 6.15 follows a guest operating system through eleven events on the pdp64, and section 6.16 is the reference: every register, bit and rule.

**The scene.** You have one PDP-11/70 running Version 7 Unix, and it is the machine everyone uses. (A *kernel* is the part of an operating system that runs in the processor's most privileged state, *kernel mode*, and does what ordinary programs may not: it handles the devices, shares the processor among programs, and decides what memory each program may touch. On the PDP-11 the mode is two bits of the processor status word, the PS.) Three things happen in one week. A colleague wants to try a different operating system on it. You have written a new version of your own kernel and want to know whether it boots, but if it crashes it takes the machine, and everyone's work, down with it. And two customers each say they want a whole machine of their own, not an account on yours.

What do you do? The first answer is a second machine. It costs a second machine, and it sits idle whenever its one user is away while the first is busy. People building time-sharing systems wanted to leave exactly that situation. Creasy, who built the first system that did what this section describes, says that before it, system developers could only enjoy computer-assisted programming up to the point of trying the code, at which time "they required a dedicated hardware system, usually at night or on weekends" (Creasy 1981).

The second answer is to run the other operating system as an ordinary program under V7. This fails, and the PDP-11 shows how. A kernel does things only a kernel may do. These are the **privileged instructions**: instructions that the processor refuses, or ignores, outside kernel mode. A kernel raises the priority in the PS to keep interrupts out of a critical section (an *interrupt* is a signal from a device that makes the processor stop what it is doing and enter the kernel, and the *priority* says which devices may do that now); it loads the page registers of the KT11, the memory-management unit (a *page table*, here eight pairs of page-address and page-descriptor registers, says which real memory each piece of an *address space*, the set of addresses a program can use, refers to); it executes `HALT` when there is nothing more to do. Run it in user mode and the machine does one of two unhelpful things. The *PDP-11 Processor Handbook* says that outside kernel mode a `HALT` is a **trap** (an instruction that stops itself and enters the kernel through a vector, here location 4), which is at least a signal, but that the processor "will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation". Think about the second case. The guest kernel executes `SPL 7` to keep interrupts out of its run-queue code. The machine silently does nothing. The guest believes interrupts are held off and they are not; one arrives in the middle of the list update; the guest corrupts its own data and nobody has been told anything. The trouble is not that the guest is forbidden to do what it wants. The trouble is that the machine neither lets it nor tells anyone that it tried.

```
        ; a PDP-11 kernel, run in user mode under V7 (PDP-11 assembler)
        spl     7              ; "keep interrupts out of the run queue": in user mode, silently nothing
        mov     (r1), r2       ; take the first entry off the queue ...
        mov     (r2), (r1)     ; ... an interrupt between these two instructions corrupts the queue
```

What is wanted is a layer under the kernel that sees every one of those acts, does for the guest what the instruction would have done, and keeps the guest from touching anything that is not its own. Here is the same `SPL` on the pdp64, run by a guest kernel under a hypervisor that asked to see it. The instruction exits; the handler of the hypervisor (the **exit handler**) does what `SPL` would have done, which is to put the priority in the guest's saved status word, and enters the guest again. The guest's next `MFPS` shows the priority it asked for. (`MFSR` and `MTSR` move a value between a general register and a numbered system register; `HEXITR` and `HEPSW` are two of the hypervisor's; the `#0` after `GENTER` is explained in 6.15, example 1.)

```
guest:  spl     #7              ; the guest's instruction: it exits instead of being ignored
        mfps    r5              ; later: the guest sees priority 7
...
hx:     mfsr    r20, hexitr     ; the hypervisor's handler: why did the guest stop?
        cbeq    r20, #XCODE_PRIO, h_prio
...
h_prio: mfsr    r21, hepsw      ; the guest's status word, saved by the hardware at the exit
        movq    =(7<<PSW_PRI), r22
        bis     r22, r21        ; do what SPL #7 would have done
        mtsr    hepsw, r21
        genter  #0              ; enter the guest again, just after its SPL
```

**What a hypervisor is.** A **hypervisor** is a program that runs other operating systems, each believing that it has the whole machine to itself. The operating systems it runs are its **guests**; the real machine is the **host**; and each guest's imaginary machine is a **virtual machine**. (Popek and Goldberg's name for the same program is the *virtual machine monitor*, and their definition of the machine it makes is "an efficient, isolated duplicate of the real machine".)

**Who did it first.** IBM, in the middle of the 1960s. Creasy writes that the system was designed and built by him and his group at the IBM Systems Research and Development Center in the mid-1960s (the center is now the IBM Scientific Center in Cambridge, Massachusetts); CP/CMS was conceived in 1964 for the newly announced System/360. In his words: "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." Each copy was a virtual machine controlled "like the real machine by their own operating systems". CP-40, on a System/360 Model 40 that had been modified with a device for address translation, and CMS were the first; CP-67 followed on the Model 67, which had translation built in. Creasy says of the product: "CP and CMS have seen continuous production use since 1967", and "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware".

Their way of catching the guest's privileged acts is the one this section uses. The System/360 had two states of execution, privileged and problem. Creasy: "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program. When using CP, each virtual machine program is actually executed in problem state. The effects of privileged instructions are reproduced by CP within the virtual machines." That is **trap and emulate**: the guest kernel runs in the least privileged state, so its privileged instruction traps; the hypervisor does what the instruction would have done, on a private copy of the state it keeps for that guest; and the guest goes on, not knowing that it did not do the work itself. Compare the PDP-11, where the guest's `SPL` did nothing and nobody was told.

In 1974 Popek and Goldberg, who had studied virtual machine systems, wrote down exactly when this works. Their theorem: "For any conventional third generation computer, a virtual machine monitor may be constructed if the set of sensitive instructions for that computer is a subset of the set of privileged instructions." Said in plain words: an instruction is **privileged** if it traps in user mode, and it is **sensitive** if it would let a program see or change the real machine instead of its own. If every sensitive instruction traps, the machine can be virtualized; if one sensitive instruction does not trap, the guest runs it, nothing is caught, and the illusion has a hole. They gave a machine with such an instruction: on the DEC PDP-10, `JRST 1` returns to user mode and does not trap. The PDP-11 of the scene above has the same fault in miniature, because its `SPL` is sensitive and is not caught.

A year later, at the Fifth Symposium on Operating System Principles (1975), Popek and Kline published "The PDP-11 Virtual Machine Architecture: A Case Study" (pages 97 to 105 of the proceedings). We have read its bibliographic record and nothing of its text.

Machines that failed the theorem could be virtualized only by software tricks, which cost speed. Then processors were changed to pass it: a table of the costs of VM exits in a 2012 paper by Agesen, Mattson, Rugina and Sheldon begins with the Intel Prescott processor, launched in the third quarter of 2005. The RISC-V privileged specification has a chapter "'H' Extension for Hypervisor Support, Version 1.0" in its library of ratified specifications; it "virtualizes the supervisor-level architecture to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". (A **type-1** hypervisor runs directly on the machine; a **type-2** is an ordinary operating system that also runs guests.) We found no date for the RISC-V extension in a primary source and so give none. The pdp64 builds the support in from the first version, so that no sensitive instruction escapes.

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

*Second, every privileged act is caught.* When the guest kernel executes an instruction that would change the real machine, the machine stops the guest and enters the hypervisor. This stop is called an **exit** (the guest "exits" to the hypervisor); it is the machine's `trap()` entry one level up. The hypervisor looks at why, does for the guest what the instruction would have done, on the private copy of the registers it keeps for the guest (the same idea as the PS and the page registers that V7 keeps in a process's `user` structure so that `swtch()`, the routine that switches the processor from one process to another, can restore them: this is a **context switch**, one level up), and then re-enters the guest. As in Creasy's CP, the guest's own user programs run at full speed and without any exit; only the kernel's privileged acts cost a trip through the hypervisor.

*Third, the guest's memory is translated twice.* On the PDP-11 the KT11 turns a program's addresses into memory addresses through the page registers. A guest kernel on a pdp64 fills its own page tables with what it believes are physical addresses; those are called **guest-physical** addresses. The hypervisor has a second set of page tables that turn a guest-physical address into a real one. The first translation is the **first stage** (stage 1) and the second the **second stage** (stage 2). Because a guest can only reach memory that its stage 2 maps, one guest cannot touch another's memory, nor the hypervisor's. The processor keeps recent translations in a small fast memory, the **translation buffer** (the TLB, the translation lookaside buffer; the KT11 has no such buffer, and a *cache* is any such small fast memory that holds a copy of something slower), and every entry in it is labelled with a **tag** saying which guest made it, so that one guest's entries can be thrown away without the others'.

*Fourth, interrupts and the clock are made up.* A real device interrupt always goes to the hypervisor first, whatever the guest's priority. What the guest sees are **virtual interrupts**: lines that the hypervisor raises when its virtual device has something to say, and a virtual clock that counts from a starting point the hypervisor chooses. The guest's `SPL` works on these in hardware, so the guest's priority keeps its meaning and costs no exit.

*Fifth, devices are shared or handed over.* A guest's disk can be a file that the hypervisor reads and writes on the guest's behalf (shared, and every command is trapped), or a real device given to the guest, whose DMA (a device's own reads and writes of memory, with no processor in between) is then confined by the IOMMU (the unit between devices and memory that translates a device's addresses the way the KT11 translates a program's) to the guest's own memory.

**Why the pdp64 has one.** Two reasons of our own. The first is **seL4**, the verified microkernel, which we mean the pdp64 to run, and to run as a hypervisor. The second is **safety**, the first of the principles (safety, speed, fewer instructions, and last a set small enough to keep in the head): a machine that divides itself into isolated parts, in hardware, is the pdp64's safety idea applied to whole operating systems.

**What it means not to have hardware support.** A machine that does not trap every sensitive act can host guests only by keeping, for each guest, a copy of the guest's page tables that the hardware really walks, and by making every write of the guest to its own tables a trap so that the copy stays in step. Every guest page-table write then costs an exit. With two stages in hardware, the guest's page tables are walked by the hardware as they are, and the hypervisor is not involved. The pdp64 therefore builds the support in from the first version: every privileged act traps, memory is translated in two stages by the hardware walker, and interrupts and the timer are virtualized in hardware.

**What it costs.** A state bit and some registers, a second table root and a guest tag in the translation buffer, virtual interrupt lines, a virtual timer, a small range comparator for the hypervisor's tables, and a tag allocator. Each of these is a fraction of a percent to about one percent of the scalar core, and the total, counted piece by piece, is a few percent. The price in time is the second walk: a miss in the translation buffer under two stages needs, in the worst case, nm + n + m page-table entry reads for n levels in the guest's tables and m in the second stage, which is one less than (n + 1)(m + 1): 15 for three levels at each stage, against 3 for one stage.

## PASTE ENDS: section 6.14

---

## PASTE BEGINS: section 6.15

## 6.15 A guest, step by step: eleven events

The examples follow one guest kernel, which we call G, running under one hypervisor, on one core. The code is **an illustration written for this chapter**, in pdp64 assembler (with a few lines of PDP-11 assembler where the story needs them, marked as such); the registers and the instruction `GENTER` are the ones that section 6.16 defines. Lines marked with an ellipsis `...` stand for code that the example does not need to show. Each example says what the hardware does, what the hypervisor does, and what the guest sees.

**Example 1. The life of a guest.** When a machine with a hypervisor starts, the hypervisor runs first, at the hypervisor level, with its own vector table (the table of handler addresses that the machine consults when it takes a trap or an interrupt) and on physical addresses (this is the state bit `H` of 6.16: "`H` = 1 means the hypervisor is running"). A native operating system on such a machine is simply a guest. The hypervisor has four things to do before the first guest instruction.

It builds the guest's second-stage tables: a three-level tree of the same page-table entries as 6.7, mapping guest-physical memory to real memory, with a root that is one page. It writes the register `GTBR` with the root of that tree and a switch that turns stage 2 on, and asks the hardware for a **guest tag**, a number that every translation made for this guest will carry. The hypervisor never chooses the number: the hardware hands one out, and throws away everything it holds under that number as it does so. It tells the hardware where it keeps its stage-2 tables, by `HARENA` (the **arena**: one contiguous run of real pages, so that the hardware can notice when the tables change; example 6 says why), and where the word lives that tells the other cores that they changed, by `HEPOCH`. It writes the trap-control register `HTRAP`, the list of events that must exit (which of the guest's privileged acts it wants to see; example 2 says which are on after reset). And it writes where the guest starts, into `HEPC` (where the guest resumes) and `HEPSW` (the guest's starting status word).

```
        lea     arena, r1
        shr     #12, r1             ; the number of the first page of the arena ...
        shl     #28, r1             ; ... goes in bits 55 to 28 of HARENA ...
        bis     #16, r1             ; ... and the number of pages, 16, in bits 27 to 0
        mtsr    harena, r1          ; the one run of pages that holds every stage-2 table
        lea     hepoch_word, r1
        mtsr    hepoch, r1          ; the epoch word, inside the arena
        lea     hroot, r1           ; the guest's stage-2 root (one page) ...
        movq    =(1<<GTBR_S2EN | 1<<GTBR_NEW), r2
        bis     r2, r1              ; ... stage 2 on, and a fresh tag from the hardware
        mtsr    gtbr, r1
        movq    =(1<<HTRAP_WFE | 1<<HTRAP_PTBR), r1
        mtsr    htrap, r1           ; exit on WFE and on writes of PTBR
        lea     guest_entry, r1
        mtsr    hepc, r1
        movq    #0, r1
        mtsr    hepsw, r1           ; kernel mode, priority 0
        genter  #0                  ; the guest starts; no register of the hypervisor is kept
```

`GENTER` ("guest enter") is the one new instruction. It is to the hypervisor what `RTI` is to a kernel returning to a user program: it loads the status word from `HEPSW` and the program counter from `HEPC`, makes the guest's own registers the live ones, and clears the state bit. Like `RTI` it carries a **mask**, here `#0`, that names the registers that keep their values; the hardware clears every other register in the same step. So the guest starts with every register zero and finds nothing of the hypervisor's. From the next instruction on, G is running at the kernel level of its own machine, and what it executes is executed by the real processor, not by the hypervisor. Nothing slows it down. G does not know that a second stage of translation is between it and memory.

**Example 2. A guest kernel does something privileged.** G is idle. Like a V7 kernel with nothing to run, it executes the instruction that waits for an event, `WFE`. On a real kernel this puts the core to sleep. Under a hypervisor the core is the hypervisor's to share.

What the hardware does, in order. It checks that the instruction is allowed in G's own mode, as it would for any kernel; G is at kernel level, so yes. It looks in `HTRAP`: the bit for `WFE` is set (it is set at reset), so this instruction is one that exits. The hardware records the guest's state in the hypervisor's registers: `HEPC` gets the address of the instruction after the `WFE` (the exit is a trap, so the instruction counts as done); `HEPSW` gets the guest's whole status word; `HEXITR`, the **exit-reason register**, gets the code for `WFE`. It sets the state bit, sets the priority to 7, and reads a one-word entry from the hypervisor's own vector table. The hypervisor's handler is running; the guest has not been told. Every general register still holds the guest's value; the hypervisor level has its own `R14` and `DP`, so the handler's first instructions can store the guest's registers through `DP` without first having to find a free register.

The hypervisor reads `HEXITR` to see why. For `WFE` the answer is: this virtual core has nothing to do, so mark it idle and run another guest; or, if nothing else is runnable, put the real core to sleep. When the guest has a virtual interrupt pending, the hypervisor enters it again with `GENTER`, and G resumes after its `WFE`, as if it had slept.

```
guest:  wfe                     ; the guest is idle
        halt                    ; (the guest stops when it wakes: HALT always exits)
...
hx:     mfdp    r19             ; DP, the hypervisor's own: its per-core structure
        ; (here the handler would store the guest's r0 to r31 through r19)
        mfsr    r20, hexitr     ; why did the guest stop?
        cbeq    r20, #XCODE_WFE, h_wfe
        cbeq    r20, #XCODE_HALT, h_halt
...
h_wfe:  lea     guest+2, r21    ; HEPC is the instruction after the WFE (one parcel, 2 bytes)
        mfsr    r22, hepc
        cbeq    r21, r22, 1f    ; ... as it must be
        ...
1:      ; mark guest 5 idle, run someone else, or sleep; later, reload the guest's registers, then:
        genter  #0              ; the mask names every register just reloaded; here none
```

The hypervisor keeps nothing in registers across `GENTER`: whatever it needs after the exit it stores in its own per-core structure before it enters and loads again when it comes back, which is one store and one load a value, per exit.

Two points are worth stopping on. The first is that some privileged acts of G do **not** exit. If G writes its page-table base register, `PTBR`, with the bit for `PTBR` in `HTRAP` clear, the write is simply G's own: the guest's page tables are walked by the hardware, and the hypervisor is not involved. (A machine that has no second stage must trap every such write and keep shadow copies of the guest's tables; section 6.14 told why.) The bit exists so that a hypervisor that wants to see the writes (to count them, or to emulate something) can ask. The second point is that a few things always exit and cannot be turned off, because no guest could handle them: `HALT` is the first. A guest that executes `HALT` means "stop this machine". The hypervisor decides what that means: stop the guest, or power the virtual machine down, or reset it.

A third group are events that the guest could use to *time* its neighbours. Processors have since been built to run ahead of themselves (they start the next instructions before the earlier ones are known to be needed, which is **speculation**) and to keep copies of recent data in caches; as a result how long an operation takes depends on what other programs did a moment before, and a program can learn another's secrets by timing its own operations, without reading a byte of the other's memory. This is a **side channel**. An instruction that invalidates all the translations or all the instruction cache of a core takes a time that depends on how much the neighbours had cached, so the bits for `ICINV`, `TLBIA` and `TLBSYNC` are set after reset (the hypervisor sees every one), and a hypervisor that gives a guest a core of its own, with no neighbours to learn from, clears them:

```
        mfsr    r1, htrap
        movq    =((1<<HTRAP_ICINV)|(1<<HTRAP_TLBIA)|(1<<HTRAP_TLBSYNC)), r2
        bic     r2, r1          ; this guest owns its core: its invalidates are its own
        mtsr    htrap, r1
```

**Example 3. A hypercall.** Sometimes G wants something from the hypervisor on purpose: to print a character through the hypervisor's console, to ask for more memory, to tell the hypervisor "this page is free". This is a **hypercall**, the analogue of a system call one level up. (A *system call* is how a user program asks its kernel for a service: it executes a trap instruction, `TRAP #n` here, `trap` and `sys` on the PDP-11, and the kernel looks at `n` to see what is wanted.) As `TRAP #n` is the system call from a user program to a kernel, so a `TRAP` can be the call from a guest kernel to the hypervisor. There is no new instruction. The hypervisor sets a mask in `HTRAP` that routes a range of `TRAP` numbers to itself: bit k of the 8-bit mask routes the thirty-two numbers 32k to 32k + 31. (`TRAP` itself takes a number from 0 to 15; `TRAPL`, the long form, takes a number up to 255. The hypercalls in this example use `TRAPL`.)

Say bit 1 is set and G executes `TRAPL #40`. Number 40 is in 32 to 63, so the trap does not go to G's own vector table; it exits. The instruction is complete, so `HEPC` is the next instruction; the exit-reason register says "hypercall"; and the hypervisor's vector is 256 + 40, so the hypervisor's table has one entry for each hypercall number, as the kernel's has one for each system call. The arguments are in registers, as for a system call. The hypervisor does the work, puts the result in `R0`, reloads the registers it saved, and executes `GENTER` with a mask that names them. The pieces, in assembler:

```
        movq    =(2<<HTRAP_MASK), r1    ; the hypervisor: bit 1 of the 8-bit mask (bits 16 to 23 of HTRAP)
        mtsr    htrap, r1
...
guest:  movq    #65, r0         ; the guest: the argument, the character 'A'
        trapl   #40             ; the hypercall; it exits instead of entering the guest's own vector table
...
hcall:  mfsr    r20, hexitr     ; the hypervisor: reason 17, a hypercall
        mfsr    r20, hcause     ; the vector: VECTOR_TRAP_BASE + 40, that is 256 + 40
        ...                     ; r0 still holds the guest's argument
        movq    #0, r0          ; the result
        genter  #1              ; the mask keeps R0 (bit 0) and clears every other register
```

G's own system calls, which are `TRAP` numbers outside the routed range, never leave the guest: a user program of G that makes a system call enters G's kernel directly, as on a machine with no hypervisor.

**Example 4. A guest page fault, and a second-stage fault.** Here the two stages show. The page-table entries and the walk are those of 6.6 and 6.7: three levels of nine bits over 4 KB pages. Say G, with translation on, loads from the guest-virtual address `0x403A58`.

Cut it into its fields. Address bits 38 to 30 are 0, so the top-level index is 0. Bits 29 to 21: `0x403A58 >> 21` is 2, so the next index is 2. Bits 20 to 12: `(0x403A58 >> 12) & 0x1FF` is `0x403 & 0x1FF`, which is 3, so the last index is 3. The offset in the page is `0xA58`. G's own tables, which it keeps in what it believes is physical memory, end in an entry for page 3 that says: the page is at guest-physical page `0x123`. So the guest-physical address is `0x123A58`. That is the answer of stage 1.

Stage 2 takes `0x123A58`, cuts it the same way, and walks the hypervisor's tables. Say they say guest-physical page `0x123` is at real page `0x8F7`. The real address is `0x8F7A58`, and the load happens there. The translation buffer remembers the whole result (guest-virtual page `0x403` for the guest's tag goes to real page `0x8F7`) so the next load from that page costs nothing. A miss costs more than in a one-stage machine, because each of G's own table entries is itself at a guest-physical address that needs stage 2: three entries at three levels each, plus the last step, make 15 table reads against 3.

Now two things can go wrong, and the hardware tells them apart.

*If G's own entry for page 3 is not valid,* it is G's fault, and only G's. The hardware takes the page fault in the guest: G's `EPC`, `EVA` and `ECAUSE` are written, and G's own kernel handles it, as a V7 kernel handles a page fault in `trap()`. No exit, no hypervisor, no instruction run. This is why a guest's ordinary virtual memory costs the hypervisor nothing.

*If G's entry is fine but the hypervisor's stage 2 has no entry for guest-physical page `0x123`,* it is the hypervisor's matter: G believes the memory exists. The hardware makes an exit. It writes `HEPC` with the instruction itself (it did not complete, so it will be run again), `HEVA` with the guest-virtual address `0x403A58`, and `HGPA`, the **guest-physical fault address**, with `0x123A58`. The reason register says "second-stage fault, entry invalid". The hypervisor can now do its job: find a real page, write the stage-2 entry, and `GENTER`. G runs the same load again; this time it succeeds. G has no idea that anything happened; that is the whole of "demand paging for a guest". If the hypervisor decides that G has no right to that page, it can instead inject a fault into G, or stop G.

Here is the hypervisor's side of the demand fill, in assembler. The stage-2 entry is the last-level entry of the page-table format of 6.7: the real address with the flag bits in its low bits. The store goes to a table that lies inside the hypervisor's arena (example 6 says why that matters), and the `GENTER` is the same as before.

```
        mfsr    r21, hgpa               ; 0x123A58, the guest-physical address that failed
        movq    =0xfffffffff000, r22
        and     r21, r22                ; its page, 0x123000
        shr     #12, r22
        movq    =0x1ff, r23
        and     r23, r22                ; 0x123 & 0x1ff: the index in the last-level table
        shl     #3, r22                 ; 8 bytes to an entry
        lea     s2leaf, r24             ; the last-level stage-2 table, inside the arena
        add     r24, r22
        movq    =(0x8f7000|LEAF), r23   ; real page 0x8F7, readable, writable, executable
        movq    r23, (r22)              ; the entry; a store into the arena
        genter  #0                      ; the guest runs the load again
```

A second guest, G2, might use the same guest-virtual address `0x403A58`, and its own stage 2 might put its guest-physical page `0x123` at real page `0x5B2`. The translation buffer must hold both results at once and must never answer one guest with the other's: that is what the **tag** is for. Every entry in the buffer is keyed by the tag of the guest that made it as well as by the address; while G runs, the processor looks up `0x403` under G's tag and finds `0x8F7`; while G2 runs it looks up the same address under G2's tag and finds `0x5B2`. Without a tag, every change of guest would have to throw the whole buffer away, which is what the KT11's users did at each change of process (a PDP-11 reloads its page registers at a context switch) and which makes a guest switch cost a burst of misses. With the tag, a guest's entries can stay in the buffer while other guests run, and the hypervisor can throw away one guest's entries without touching the rest.

There is a third case, which the hardware also tells apart. If the stage-2 entry is valid but points at a physical address where, by the platform's map of memory and devices, nothing answers, it is still the hypervisor's matter, and the exit says "no device answers" instead of "entry invalid"; the hypervisor handles it the same way. If a device does answer and answers with an error, the guest has not made a mistake of mapping but met a failure of the machine, and that is a machine check in the guest.

**Example 5. A timer tick for the guest, and a device interrupt.** A V7 kernel has the line clock at vector 0100 at priority 6; each tick enters `trap()` and calls `clock()`. G needs the same: a clock that ticks. The pdp64 gives a kernel its clock in two system registers: `MFSR TIME` reads a counter that counts at 10 MHz and cannot be written, and `MTSR TIMECMP` writes a **deadline**, an absolute counter value; while the counter is at or past a deadline that is not zero, the timer's interrupt line is asserted (level 6, vector 32). A deadline of zero means "never", which is also the value after reset. The line is a **level**: it stays asserted until the kernel writes a later deadline, as the line of the PDP-11's KW11-L stays set until the program clears it.

G uses the same two registers, with the same handler as on bare metal, and three pieces make a clock of them. The hypervisor offers G a **virtual timer**: when G reads `TIME` it gets the real counter minus an offset the hypervisor chose in `VTOFF` (so the guest's time starts where the hypervisor says); when G writes `TIMECMP` it writes its own comparator, and while the guest's counter is at or past that deadline the hardware holds **virtual interrupt line 6** asserted, the line for the clock's priority. Like the real timer's it is a level, so a handler that forgets to write the next deadline behaves in the guest as it does on bare metal, and a deadline that had passed when the hypervisor reloaded the guest's registers simply fires at once. The hypervisor has, besides, the real timer, which keeps running at the hypervisor level: the same two names reach it there, its expiry is a physical interrupt, and it is how the hypervisor itself gets control to schedule guests. The hypervisor loads and saves the guest's deadline with `GTIMECMP`.

```
        mfsr    r1, time        ; the guest's time: the real counter minus VTOFF
        add     #3000, r1       ; 3000 counts from now: 300 microseconds at 10 MHz
        mtsr    timecmp, r1     ; the guest's own deadline; no exit
...
        movq    #0, r1
        mtsr    timecmp, r1     ; zero means never: the handler's way to stop the clock
```

```
; in the guest, a tick 3000 counts ahead; no exit happens
        mfsr    r1, time            ; the guest's time: the real counter minus VTOFF
        add     #3000, r1
        mtsr    timecmp, r1         ; the guest's own deadline
```

A **virtual interrupt line** is one bit in the register `VIRQ`, set by the hypervisor (for a device it emulates) or held by the timer hardware. There are seven, one for each priority from 1 to 7. Between two instructions of G, if the highest pending line is above the priority in G's status word, the hardware makes G's own exception entry, with the vector number the hypervisor put in `VIVEC` for that line. This is the entry of 6.3, run inside the guest, with no exit: `EPC`, `EPSW` and `ECAUSE` are written, the priority goes to 7, and G's handler runs. The bit that the hypervisor set is cleared by the delivery; line 6's timer part follows the comparator. G's `SPL` and `MTPS` work against these lines in hardware, so G's idea of "interrupts held off" is true and cheap. Here is the whole thing in assembler (the hypervisor's side, then the guest's), and it runs:

```
        movq    #(1<<6), r1
        mtsr    virq, r1                ; hypervisor: line 6 is pending
        movq    =(0x60<<40), r1         ; line 6 is the field in bits 47 to 40 of VIVEC: vector 0x60
        mtsr    vivec, r1
        movq    =((MODE_KERNEL<<PSW_MODE)|(MODE_KERNEL<<PSW_PREV)|(7<<PSW_PRI)), r1
        mtsr    hepsw, r1               ; the guest starts at priority 7 ...
        genter  #0
guest:  nop                             ; ... and the pending line is held off
        spl     #0                      ; the priority drops: the guest's own exception entry
        nop                             ; follows at once, to the handler at vector 0x60; no exit
```

A **physical** interrupt is different. An RK11 completing a transfer asserts its line; whatever G's priority is, the interrupt goes to the hypervisor first (an exit, with the reason "physical interrupt" and the line's vector). The hypervisor decides whom it is for. If it is for the hypervisor's own driver, it handles it. If it is for G's virtual disk, it completes the virtual transfer, sets the right bit in `VIRQ`, and enters G; G sees an interrupt, as if its own RK11 had finished. Each physical line stays asserted until the hypervisor clears it at the device, so none is lost. 

Two more newcomers belong here. A **message-signalled interrupt** is an interrupt that a device raises not on a wire (as the RK11 does, on a priority line) but by writing a word to a particular address, the interrupt page; the word says which vector. The PDP-11 kept the pending request inside the device as a level on a line, so the processor stored nothing; a written message is consumed by the write, so the interrupt controller in the processor keeps a pending bit for each vector until the kernel takes it. A card with many queues, one for each core, can raise its own vector for each core. The risk is the one every device that writes memory has: it could write anywhere. A device that does DMA (reads and writes memory by itself) is confined by the **IOMMU**, the unit between devices and memory that translates a device's addresses as the KT11 translates a program's, with a table for each device. Say the hypervisor gave G a real network card. G's driver gives the card a buffer at the guest-physical address `0x123000`. The card puts that address on the bus; the IOMMU finds the card's table, which carries G's tag, walks G's stage 2, and the write lands at real page `0x8F7`. A card that tries a guest-physical address that G has no mapping for finds the entry invalid: the write is refused and counted, and nothing is written. The same table gives the card its interrupt: the message the card writes carries an index, the IOMMU looks it up in that card's own table of vectors, and a card with no entry raises nothing, so a card cannot forge an interrupt for a vector that is not its. The IOMMU also refuses a write by any card to a system register or to an arena page.

**Example 6. A guest reset, and why stale translations must not survive.** A guest sometimes needs to be reset: it asks (by a hypercall, or by touching a virtual device) and the hypervisor does it. A reset must make the guest's machine the machine of reset: all registers to the values of a table, memory as the hypervisor chooses, translation off. There is a trap here, and it is a real one.

The translation buffer holds finished translations tagged with the guest's tag. If the hypervisor changes a stage-2 table, or resets the guest and reuses its root, while the buffer still holds translations made before, the guest can read memory that is no longer its own through them. The Linux KVM bug of 2026 (CVE-2026-99312) is of this kind: when KVM emulated an INIT for a nested guest with paging off, it ran the outer guest "with a stale MMU context". The rule, stated in 6.8.5, is: **whatever resets the translation state of a core or a guest must discard its cached translations, in the same step**.

On the pdp64 the hypervisor is not asked to remember. The hardware watches the arena: any store by this core into the one run of pages that holds the stage-2 tables, and any write of a guest's translation register, sets a flag, and `GENTER` throws away every translation of the guest and clears the flag. Until a hypervisor tells the hardware where its arena is, the flag is always set: every entry throws away everything, which is slow and safe, and the fast path has to be asked for. The hardware also refuses to walk a stage-2 table that lies outside the arena, so the hypervisor cannot slip a table past the watch. A device can never write the arena (the IOMMU refuses). Another core is told by the epoch word: when a core has stored into the arena, it adds one to the epoch word in memory at its next entry into a guest or its next `FENCE`; a core entering a guest reads the word and, if it differs from the value it kept at its last flush, throws everything away. No wire runs between cores; the ordinary coherence of memory carries the word. There is no flush bit on `GENTER`, because a bit that the hypervisor can forget to set closes nothing.

The reset sequence is written down in order (6.16.34), and the first thing it does is stop the guest's cores; the hardware does the rest, and the tag is never given to another guest while entries of the old one could exist.

**Example 7. What the hypervisor itself runs on.** The hypervisor is a program too: it has code, data, a stack, and it may have bugs, so it too needs protection from stray pointers. The hypervisor level is built so that an ordinary kernel can itself run there, unmodified. ("VHE" is Arm's name for the same arrangement, a *virtualization host extension*; it keeps a kernel from having to be split in two halves, one that runs at the kernel level and one that runs above.) At the hypervisor level the ordinary register names mean the hypervisor level's own registers: `PTBR`, `MMUCTL`, `ASID`, `VBR`, `EPC`, `EPSW`, `EVA`, `ECAUSE`, `R14` and `DP` are the hypervisor's, so a kernel's handlers, its page tables and its `RTI` work there as they do at the kernel level. The tag of everything translated at the hypervisor level is 0, the host's, and there is one stage only. The guest's registers are reached by explicit names, each the guest's register name with a `G` in front, as a V7 kernel reaches a user's registers with `mfpi` and `mtpi` (the instructions that move a word between the kernel and the memory of the previous mode) and not by the plain names.

```
; at the hypervisor level: the plain names are the hypervisor's own, the G names the guest's
        mfdp    r20             ; DP: the hypervisor's own per-core structure
        mfsr    r1, gptbr       ; the guest's PTBR ...
        movq    r1, (r20)       ; ... into the structure
        mfsr    r1, gvbr
        movq    r1, 8(r20)
        mfsr    r1, gkdp        ; the guest's kernel-mode DP
        movq    r1, 16(r20)
        mtsr    ptbr, r2        ; the hypervisor's own table base: not the guest's
```

A small hypervisor, like the first one of the project, may leave its own translation off and run on physical addresses.

**Example 8. What is saved and what is cleared at the entry and the exit.** When G exits and the hypervisor enters, the hardware saves very little: G's program counter in `HEPC`, G's status word in `HEPSW`, and the facts about the exit (`HEXITR`, `HEVA`, `HGPA`, `HINSN`: the first words of the instruction that caused it). It makes the plain register names mean the hypervisor level's own, so that the first instruction of the handler has a register that is not G's. Everything else that is G's stays where it was: the registers `PTBR`, `VBR`, `EPC` are G's and the hypervisor reaches them by `MFSR` with their explicit names if it is going to run another guest (as a V7 kernel saves a process's PS). This is deliberate: an exit that does not need to touch G's state is as short as the machine can make it.

What the hardware clears is what could leak. At every exit and at `GENTER`, and at every exception entry and return, any `LL` reservation (the marker that `LL` and `SC`, load-linked and store-conditional, use to build an atomic update) is cleared, so that what one guest left behind is not found by another. `RTI` and `GENTER` both carry a **mask**: `RTI #mask` is the only form of `RTI`, and the mask names the registers that are to keep their values; the hardware clears every other register in the same step as the return to a less privileged mode. A kernel that forgets to name a register it used gives the user program a zero, never a secret. Mask bit 14 names the vector registers and the floating-point flags together (register 14 is the stack pointer, which is never cleared, so its bit was free); a mask with that bit clear clears them. The same mask is on `GENTER`, so that a hypervisor cannot hand G a register of another guest by forgetting. Here a kernel leaves a secret in `R5` and a user value in `R8`, and returns to user mode naming only `R8` (bit 8); the user program finds `R5` zero and `R8` intact, and this runs:

```
        movq    =0x1234, r5             ; the kernel's secret
        movq    =0x77, r8               ; a value the kernel restored for the user
        rti     #(1<<8)                 ; keep R8; every other register is cleared in the same step
user:   cbeq    r5, #0, 1f              ; the secret is gone
```

The mask is written in the instruction, not kept in a register, so that no stale mask can survive from an earlier return.

A **vector block** is the pdp64's way of working on a whole array with one short piece of code, and it is the newest idea here, so here is an example. The `VEC` instruction begins the block, names a pointer and an end, and repeats the instructions up to `VEND` once for each **strip**, a piece of a few words that the hardware handles together (the strip is 16 bytes in a block that keeps a sum, so four 32-bit lanes). This block adds up 21 words of 16 bits. The running sum lives in a hidden **accumulator**, `v4`, which `VCLR` zeroes; `VFIN` starts the epilogue, which runs once, after the last strip, and adds the lanes into `R12`.

```
        lea     wsrc, r1                ; 21 words of 16 bits
        movq    #21, r2
        lea     (r1)(r2*2), r4          ; the end pointer
        movq    #0, r12
        vec     r1, r4                  ; the block: the body runs once for each strip
        vclr.l  v4, #1                  ; the accumulator starts at zero (only legal inside the block)
        vld.w.l v0, (r1)+               ; four 16-bit words widened to 32 bits; the pointer advances
        vadd.l  v4, v4, v0              ; the running sum, by lane
        vfin                            ; the epilogue, once
        vacc.l.q r12, v4                ; add the lanes into R12
        vend
```

Run on a machine whose strip is 16, 32 or 64 bytes, this block gives the same sum as adding the words one at a time: the strip is invisible to a program that keeps its sums in accumulators. Now an interrupt arrives, or a guest exits, after the block has done three strips. The accumulator `v4` holds the sum of twelve words; the pointer `R1` has advanced by 24 bytes. The handler is shown the **entry** values (`R1` at the start of the block) and the address of the `VEC`, so that if it simply returns to that address the block starts again from its first strip and is correct: restarting never needs any hidden state. But restarting throws away the three strips, and a block that is interrupted often (a page fault on each page of a large array, a timer tick every few thousand cycles) might never finish. So the hardware keeps, for each core, one hidden **resume record**: the address of the `VEC`, whose context it is (guest tag, address-space number, mode), the entry and the current values of the registers the block changes, and a one-use **token**, a number the hardware makes up and puts in the saved status word, so that only the code that returns with that saved word can resume it. If the same context returns to the same `VEC` with the token and the entry values unchanged, the block carries on at strip four with its sum intact. In every other case (another guest entered, a translation register written, any other vector instruction run, the token missing) the record is discarded and the block starts again from its first strip: resume is only ever faster, and never changes an answer. Because a program must not be able to hold off the kernel for as long as a block takes, an interrupt is taken between two strips, never inside one; and because the record is a hidden thing, the token is made so that a guest cannot learn from it how many times other guests were suspended (6.16.31).

**Example 9. What is not in version 1.** G is a kernel; it cannot be a hypervisor in turn. The first version has **no nested guests**: if G touches any hypervisor register or executes `GENTER`, it exits with the reason "hypervisor register used by a guest", and the hypervisor may make it look to G like an illegal instruction. The reason is the cost: nested virtualization in software needs no new gates but many exits for each guest operation, and in hardware it would take from a fraction of a percent to several percent of a core; and a stale-translation bug of the kind of example 6 happened in the nested case. The rule is stated so that it can be lifted without changing the meaning of anything else.

**Example 10. Two programs, one word: the atomic instructions.** So far the guest and the hypervisor have kept to their own memory. Sooner or later they share a word: a count of the characters waiting in a console buffer that the guest fills and the hypervisor empties, a lock on that buffer, a ticket number. A kernel on the PDP-11 kept shared data safe by raising the processor's priority (`SPL`, 6.3) so that no interrupt could come between two of its instructions; there was one processor, so that was enough. A machine with a hypervisor, or with a second core, has two ways in which that is not enough, and the first of them needs no second core at all.

Take the plain way to add one to a counter in memory:

```
        movq    (r3), r1        ; read the counter
        add     #1, r1          ; add one
        movq    r1, (r3)        ; write it back
```

Say G runs these three instructions, and after the first one its time slice ends and the hypervisor takes an exit. The hypervisor, which shares the counter, adds one to it and later gives G the core again. G's `R1` still holds the old value, G adds one to that and writes it: the hypervisor's addition is lost, and nothing has gone wrong that anyone could see. A second core would do the same between any two of the three instructions. What is wanted is an **atomic** operation (from the Greek for "that cannot be cut"): one that every other core, every other guest and the hypervisor see either complete or not started, never half done. The PDP-11's `INC` on a memory word had this property against an interrupt, because an interrupt can only come between instructions; the pdp64 gives it to a whole family.

**The family.** There are ten operations, each with a plain form and a form with `DB` at the end, and a pair that works together: `CAS` (compare and swap), `SWAP`, `XADD` (fetch and add), `XAND`, `XOR_`, `XXOR` (fetch and the bit operation), `XMAX`, `XMIN`, `XMAXU`, `XMINU` (fetch and the larger or the smaller, signed and unsigned), and `LL` and `SC` (load-linked and store-conditional, below). The `DB` form folds in a **barrier**: an instruction that makes the core finish its earlier memory accesses before it begins the later ones. Example 11 says why, on this machine, a barrier changes nothing between ordinary accesses; the `DB` form is there so that taking a lock is one instruction.

The rules are few, and each exists so that an atomic can never be half done:

* Every one of them has three register fields, as `XADD Rd, Rs, (Ra)`: the address is in `Ra`, with no offset (the parentheses hold a register and nothing else), the old value of the memory word comes back in `Rd`, and `Rs` is the operand. `CAS Rd, Rs, (Ra)` has the **expected** value in `Rd` and the new value in `Rs`, and it puts the old value into `Rd`: one register is used for the expected value going in and the old value coming out. If the old value is the expected one, the swap happened.
* The size is 4 bytes or 8 bytes. The examples here use the 8-byte form.
* The word must be naturally aligned (an 8-byte word at an address that is a multiple of 8). An atomic on a word that is not aligned takes a **precise fault**: the fault happens before the instruction has changed anything, and the saved program counter is the instruction itself.
* The memory must be ordinary cached memory. An atomic, or an `LL` or `SC`, on uncached memory or on a device's registers also takes a precise fault. The reason is that the machine can make an operation atomic only where it controls the whole path, in the cache; on a device register the choice is a fault, never an operation that is silently not atomic.

**A lock taken and released.** The simplest use of `CAS` is a **spin lock**: a word that is 0 when free and 1 when held, taken by a loop that tries until it succeeds (it "spins"). To take it, the program says: "if the word is 0 make it 1, and tell me what it was". If what it was is 0 the lock is mine; if not, someone else has it and I try again.

```
take:   movq    #0, r1                  ; expected: the lock is free
        movq    #1, r2                  ; new: held
        casdb   r1, r2, (r3)            ; one step; r3 holds the address of the lock; r1 is now the old value
        cbeq    r1, #0, held            ; the old value was 0: the lock is mine
        hint    #1                      ; it was 1: tell the core this is a wait ...
        br      take                    ; ... and try again
held:   ...                             ; the work on the shared data
        movq    #0, r1
        movq    r1, (r3)                ; the release is an ordinary store
```

Taking the lock is one instruction, and the release is an ordinary store because, as example 11 shows, an ordinary store is seen by the other cores in order. The loop sets `R1` again on every try because `CASDB` has overwritten it with the old value, which was 1, and the expected value must be 0 once more.

**A counter.** With `XADD` the counter of the beginning is one instruction, and what it returns is the old value, which is useful: if two programs each add one to the same word, they get two different numbers back, so it also hands out ticket numbers.

```
        lea     count, r3
        movq    #1, r2
        xadd    r1, r2, (r3)            ; one step: r1 is the number I took, the counter is one more
```

**The pair `LL` and `SC`.** Not every update is one of the ten. A counter that must stop at a limit cannot be a fetch and add: the program must read it, compare, and write only if it is still what it read. `LL` reads the word and puts a **reservation** on it, a mark that the core keeps; `SC` writes the new value only if the mark is still there, and says whether it did, by a register that is 0 when the word was written and not 0 when it was not. A write to the marked memory by another core, or by a device, clears the mark, and so does anything that ends the guest's turn: the reservation is cleared at every exit, at `GENTER`, and at every exception entry and return (example 8), so that a guest cannot leave a mark for another to find. A program therefore never assumes that its `SC` works: it asks and, if it fails, it begins again from the `LL`.

```
        movq    #100, r5                ; the limit
retry:  ll      r1, (r3)                ; read the word and take the reservation
        cbeq    r1, r5, full            ; at the limit: leave without writing
        movq    r1, r6
        add     #1, r6                  ; the new value, in a register
        sc      r4, r6, (r3)            ; write it only if no one wrote the marked memory since the LL
        cbne    r4, #0, retry           ; r4 is not 0: the SC did not write; start again
```

Such a loop could, in principle, fail for ever if two cores keep clearing each other's marks. To forbid this the machine makes a promise for the loop of one shape, called a **constrained loop**: from the `LL` to the `SC` there are at most 16 instructions; between them only instructions that work on registers (no loads, no stores, no backward branches); and the `SC` is to the same address as the `LL`. For a loop of that shape, the machine promises that it succeeds sooner or later unless someone else keeps writing the marked memory. The loop above is of that shape (its only branch before the `SC` is a forward one). The marked memory is the aligned block of 128 bytes that holds the word: the hardware may track less (a piece of 8 bytes), never more, and a mark that is cleared by a neighbour's write only costs the loop another try. A program that wants no such cost keeps each word that it protects in a block of its own, as the snippet does by placing the counter on a 128-byte boundary and leaving the rest of the block empty. The weakness of `CAS` is that it compares values: a word that went from A to B and back to A looks as if no one had touched it, though the structure that it points to may have changed (the **ABA problem**), while an `SC` fails if anyone wrote the marked memory, even with the same value.

**Why a hypervisor cares.** First, a guest's atomic is an ordinary instruction on memory, so it does not exit by itself: it is atomic against the hypervisor and against every other guest and core, because the memory system makes it so and does not ask who is calling. The hypervisor can therefore keep a word that a guest also changes (the count of the console buffer, a flag in a ring of requests) and know that a guest cannot leave it half done, because an exit or an interrupt can come only between instructions and never inside one. Second, a fault is precise: if G's atomic touches a page that the hypervisor has not yet mapped (example 4), nothing has changed when the exit comes, and when the hypervisor has filled the entry and gives the core back, the instruction begins again whole. Third, a fault on uncached memory or on a device is a fault and not a silent loss: the hypervisor cannot be led into trusting a lock word that the machine did not keep atomic. Fourth, because the reservation is cleared at each exit and each `GENTER`, no mark that one level left is ever found by the other. Last, the reports of other machines show that the retry costs something where the memory system is slow: an engineer at a maker of Arm servers reported about 25 retries of one compare-and-swap with 28 threads working on the same file, and a Linux developer's comment on it was that a failing compare-and-swap loop means that the cache coherency is bad. This is a reason to keep a contended word to a few programs, which is a rule of the programmer's, and not a flaw of the instruction.

**Example 11. What one core sees of another: the memory model.** The atomics of example 10 make one operation indivisible. A different question is what a program sees of the *order* of another's plain loads and stores. Take the commonest exchange there is, **message passing**: one program writes some data and then sets a flag to say "ready"; another waits for the flag and then reads the data. The guest and the hypervisor of the examples do exactly this when G fills a request and the hypervisor looks at it, and so do a driver and a device. On the PDP-11 the order was simple: there was one processor, it did one access after another, and a program saw its own memory as it had written it. Here are the two sides on the pdp64; the first is G's and the second the hypervisor's, after G's hypercall has stopped it:

```
guest:  movq    #42, r1
        movq    r1, (r3)                ; first the data ...
        movq    #1, r1
        movq    r1, (r4)                ; ... then the flag: "the data is ready"
        trapl   #40                     ; tell the hypervisor to look

hcall:  movq    (r4), r1                ; first the flag ...
        cbne    r1, #1, hbad            ; not set: nothing to read yet
        movq    (r3), r2                ; ... then the data
        cbeq    r2, #42, 1f             ; the flag was set, so the data is the new data, never the old
```

Here the reader looks after G's hypercall has stopped G, so the order is plain. What matters is what the architecture promises when the two run at the same time, on two cores: **the pdp64 keeps sequential consistency.** A **memory model** is the promise a machine makes about which values a load may return when other cores are writing; **sequential consistency** (SC) is the simplest promise there is: the result is as if the loads and stores of all the cores had been done one at a time, in one order, with each core's own accesses in its own program order. Under that promise, if the reader sees the flag it sees the data, with no instruction between the reader's two loads and none between the writer's two stores. The program above needs no **fence** (an instruction that tells the core to finish its earlier accesses before it begins the later ones; the same thing as the barrier of example 10). That is why the lock of example 10 is released with an ordinary store.

**Why other machines need fences.** A fast core does not want to wait for slow memory, and so it does three things. It puts a store into a small queue, a **store buffer**, and goes on without waiting for it to reach memory. It may begin a load before an earlier store has been seen by the others. And its caches may bring two related pieces of memory up to date at different times. A single core hides all of this from its own program, which always sees its own stores. Another core cannot be given that privilege for free, and on a machine that allows these things it can see the data store and the flag store in the wrong order: the flag is set and the data is still old. The machines differ in how much they allow. The x86 allows the store buffer and little else: its manual says that reads may be reordered with older writes to different locations, but not with older writes to the same location. Arm's manual calls its model weakly ordered, and RISC-V's default is a weak model too (RISC-V also defines a stronger variant that exists to carry over programs written for the x86). The DEC Alpha was the extreme: the Linux kernel's documentation calls it "one of the most relaxed CPUs there is", and says that some versions have a split data cache that can update two related lines at separate times, so that a program which has just read a pointer to new data can still read the old data through it. So the kernel needs a barrier even between loading a pointer and loading through it, and, since it has to run on the Alpha, it says that the Alpha defines the Linux kernel's memory barrier model: outside the code of one particular machine, the kernel must assume the most relaxed case. The same document notes that even a guest kernel built to run on one processor can be affected, because it shares memory with a host that has several.

What a program on such a machine pays is a fence at every place where order matters, put by the programmer who must find each place, and an error is not a crash on the first run: it is a flag seen before its data, once in a long while, with a timing that no test repeats. This is what a weak model asks of every kernel, driver and compiler, and it is what the pdp64 does not ask.

**What SC does not do, and what it costs.** It orders the accesses; it does not make a sequence of them indivisible. The three-instruction counter of example 10 is still wrong under SC, as the example showed on one core: SC says what order the accesses are seen in, and the atomics make the sequence one access. The two ideas are used together. The cost of SC is paid by the designer of the hardware: a very fast core that runs loads early must check afterwards, and redo any load that another core got in between. The first pdp64 cores are simple and in order and have nothing to gain from a weaker promise, and a program written for the strong promise runs on a weaker machine only with fences added, so the choice is made once, in the strong direction.

**A device is another core that sees memory.** A disk or a network card reads and writes memory by itself (this is **DMA**, direct memory access); to the program it is one more writer, and it can be shown the memory in the wrong order for the same reasons. The pdp64 puts a unit between devices and memory, the **IOMMU** (input-output memory management unit): it translates the addresses a device uses, by tables that the kernel writes, and refuses any access that the tables do not allow. Three rules make the order right by construction:

* The unit reads its tables **coherently**: it reads them through the same path as the cores, so that an entry the kernel has just written is the entry the unit finds, and the kernel does not have to remember to push a changed line out of its cache first. (A fence orders a core's stores; it does not write a modified line out of the core's cache.)
* The kernel tells the unit that a mapping has changed by an **invalidate command** (the commands are: invalidate a device, a domain, a guest, or everything, and a sync), because the unit keeps copies of the translations it has used, just as the processor does in its translation buffer. The unit executes its commands in the order they are given, so that a missing fence cannot make an invalidate run before the store it was meant to follow; the RISC-V unit studied for this design may execute its commands out of order and says that software must place a fence. The command to invalidate a device does not finish until that device's requests already in flight are finished or refused. To reset a guest, the hypervisor blocks the guest's devices, invalidates its translations, and only then resets (example 6).
* A device never writes the arena (example 1), the hypervisor's own tables: the unit refuses it. And the memory that devices write, the DMA buffers, is uncached, so the atomics of example 10, which fault on uncached memory, can never be used on a word that a device is writing; a lock word is always in ordinary memory.

In order, then, with G handing a buffer to a device: G writes the data (plain stores, no fence); the hypervisor (or G's kernel, through it) writes the table entry that lets the device reach the buffer, the unit reads it coherently, and a command to the unit makes it forget any old copy; the device then reads the buffer. On a weak machine with a unit that reads its tables through a cache of its own, each of those steps has a place where a fence or a cache flush has to be remembered. Here none has to be.

## PASTE ENDS: section 6.15

---

## PASTE BEGINS: section 6.16

## 6.16 The hypervisor mode: the rules

Everything of 6.14 and 6.15 is here as numbered statements and tables.

### State and registers

**6.16.1** Virtualization is part of the architecture: a hypervisor can run guest operating systems, each at the kernel level of its own machine.

**6.16.2** Every instruction that reveals or changes the real state of the machine either traps to the hypervisor when a guest runs it, or is harmless. No unprivileged instruction reads a clock, a counter or the identity of the core, and there is no page that the kernel keeps up to date for a user program to read the time from: a user program learns the time by a system call. No system register is readable outside kernel mode.

**6.16.3** The hypervisor mode is one state bit, **`H`**, inside the core, not in the status word and not in any register a program can read. `H` = 1 means the hypervisor is running; `H` = 0 means anything else. Only the hardware changes `H`: an exit sets it and `GENTER` clears it. The reserved mode value 2 stays reserved, so `MFPS`, `MTPS`, `RTI` and `EPSW` do not change and a guest cannot see the mode. Whether the machine has a hypervisor is a property of the machine, the **strap `HVE`**, which no program can change, and which `FEATURES` reports (6.16.8). With `HVE` = 0 the machine is the machine of chapters 1 to 9 without this section: `H` is always 0, every register of 6.16.7 and `GENTER` is an illegal instruction. With `HVE` = 1, `H` is 1 at reset, so the first software to run is the hypervisor (or firmware that starts it).

**6.16.4** While `H` = 1 the hypervisor level is a kernel of its own, and the ordinary register names are its own: *(a)* the numbers 0 to 11 of 6.5 (`PTBR`, `EPC`, `EVA`, `ECAUSE`, `DMW0`, `DMW1`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID`), `R14` and `DP` name the hypervisor level's own registers, and `CPUID` (number 12) returns the real core number; *(b)* an exception, a trap or an interrupt taken at `H` = 1 is entered as in 6.3, with those registers, and `RTI`, `RTT`, `PUSHX` and `POPX` use them as they do for any kernel; the exit registers (`HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN`, `HEXITR`) are never touched by an event taken at `H` = 1, which sets `HEXITR` to 0; *(c)* the priority is the priority field of the status word, which an exit sets to 7 and the hypervisor lowers with `SPL` after it has saved what it needs; *(d)* every privileged instruction is allowed, whatever the mode field says; *(e)* no virtual interrupt line is delivered; a physical interrupt is taken, as in 6.3, if its level is above the hypervisor's priority; *(f)* a reserved mode value in `HEPSW` is refused with an illegal instruction when it is written. At `H` = 0 the same numbers and names are the guest's.

**6.16.5** The hypervisor level translates its own addresses with its own registers (6.16.4): its page-table base, address-space number and translation control are the ordinary `PTBR`, `ASID` and `MMUCTL` at `H` = 1, its tag is 0 (the host's), and it has one stage only. A guest's translation-buffer entry never answers a hypervisor access. A hypervisor that leaves `MMUCTL` clear runs on physical addresses.

**6.16.6** The hypervisor reaches the guest's copy of every register that 6.16.4 renames through an explicit name, the guest's register name with a `G` in front, defined at `H` = 1 only (6.16.7); a guest's own use of these numbers exits (6.16.30). An exit changes none of the guest's registers in hardware: it writes `HEPC`, `HEPSW` and the facts of the exit and makes the names of 6.16.4 mean the hypervisor level's own, so the first instruction of the handler has `R14` and `DP` that are not the guest's. After a machine reset the kernel stack register is set by the boot protocol of the platform (chapter 4). The hypervisor keeps no value in a general register across `GENTER` (6.16.18).

**6.16.7** The registers of the hypervisor are system registers (6.5) numbered 128 to 164; they are reached only at `H` = 1. A guest's `MFSR` or `MTSR` of an assigned number exits with exit code 18, after the guest's own privilege check (6.16.10); on a machine with `HVE` = 0 it is an illegal instruction; an unassigned number (136, 145 to 147, and 165 to 255) is an illegal instruction. The registers marked read only refuse a write with an illegal instruction. In every register **a write of a one to a bit that is not in use is refused** with an illegal instruction, and such a bit reads as zero. After a machine reset every register is zero except `HTRAP` (6.16.9).

| Number | Name | Width in use | Access | What it holds |
|---|---|---|---|---|
| 128 | `HTRAP` | 24 bits | read, write | trap control (6.16.9) |
| 129 | `HEXITR` | 10 bits | read only | exit reason: code in bits 7 to 0, flags in bits 9 and 8 (6.16.15) |
| 130 | `HEPC` | 64 | read, write | the guest's program counter at an exit; where `GENTER` resumes |
| 131 | `HEPSW` | status word, and a token in bits 63 to 32 | read, write | the guest's status word at an exit; the one `GENTER` loads; the token of 6.16.31 |
| 132 | `HEVA` | 64 | read only | the guest-virtual address of the access that caused the exit, else 0 |
| 133 | `HCAUSE` | 9 bits | read only | the vector number of the exit (6.16.16) |
| 134 | `HGPA` | 39 bits | read only | the guest-physical address that stage 2 could not translate, else 0 |
| 135 | `HINSN` | 32 bits | read only | the first two parcels of the instruction that caused the exit, else 0 |
| 137 | `GTBR` | 64 | read, write | stage-2 enable, root and guest tag (6.16.22) |
| 138 | `VIRQ` | 8 bits | read, write | virtual interrupt lines, pending; bit 0 reads zero (6.16.27) |
| 139 | `VIVEC` | 56 bits | read, write | the vector number of each virtual line (6.16.27) |
| 140 | `VTOFF` | 64 | read, write | virtual timer offset (6.16.28) |
| 141 | `VCPUID` | 16 bits | read, write | the guest's virtual core number (6.16.14) |
| 142 | `HARENA` | 56 bits | read, write | the arena of stage-2 tables (6.16.25) |
| 143 | `HEPOCH` | 40 bits | read, write | the real address of the epoch word (6.16.25) |
| 144 | `GTOKEN` | 64 | read, write | the guest's token key and counter (6.16.31) |
| 148 | `GTIMECMP` | 64 | read, write | the guest's timer deadline (6.16.28) |
| 149 to 164 | `GPTBR`, `GEPC`, `GEVA`, `GECAUSE`, `GDMW0`, `GDMW1`, `GUSP`, `GSSP`, `GEPSW`, `GVBR`, `GMMUCTL`, `GASID`, `GKSP`, `GKDP`, `GSDP`, `GUDP` | 64 (`GEPSW`: status word) | read, write | the guest's copy of the registers 0 to 11 of 6.5, of `R14` of the kernel mode, and of `DP` of the kernel, supervisor and user modes |

The guest's registers of the last row are written in this order of numbers: 149 `GPTBR`, 150 `GEPC`, 151 `GEVA`, 152 `GECAUSE`, 153 `GDMW0`, 154 `GDMW1`, 155 `GUSP`, 156 `GSSP`, 157 `GEPSW`, 158 `GVBR`, 159 `GMMUCTL`, 160 `GASID`, 161 `GKSP`, 162 `GKDP`, 163 `GSDP`, 164 `GUDP`. `GEVA` and `GECAUSE` are writable, though `EVA` and `ECAUSE` are not, because they are the stored values that a world switch must put back. `HINSN` lets the hypervisor emulate a trapped instruction without reading guest memory through the guest's tables.

**6.16.8** One read-only system register, **`FEATURES`** (number 32), says what the machine has, so that software tests instead of trapping or guessing; it is readable at every level, and in a guest the field `HV` reads zero and the other fields are the machine's.

| Bits | Field | Meaning |
|---|---|---|
| 0 | `HV` | the hypervisor is present (`HVE`) |
| 7 to 1 | `PABITS` | the width of a physical address in bits (40) |
| 11 to 8 | `LEVELS` | the number of translation levels (3) |
| 15 to 12 | `TAGBITS` | the width of a guest tag in bits, divided by 4 (4, that is 16 bits) |
| 19 to 16 | `VLINES` | the number of virtual interrupt lines (7) |
| 23 to 20 | `STRIP` | the base-2 logarithm of the vector strip in bytes (the strip of an ordinary block; 6.16.31) |
| the rest | | zero |

### Trap control

**6.16.9** `HTRAP` is the trap-control register. A set bit sends its event to the hypervisor as an exit; a clear bit leaves the event to the guest, or to a form of the hardware scoped to the guest. Bit 15 and bits 24 to 63 are reserved (6.16.7). After a machine reset the bits `WFE`, `SEV`, `TLBIA`, `TLBSYNC` and `ICINV` are set and the rest are clear, so that a guest which has not been given a core of its own can neither sleep the core, wake another guest's core, nor time its neighbours by an invalidate; a hypervisor that gives a guest a core of its own clears them.

| Bit | Name | The event (exit code of 6.16.15) | When the bit is clear | Reset |
|---|---|---|---|---|
| 0 | `WFE` | `WFE` (3) | the guest sleeps | 1 |
| 1 | `SEV` | `SEV` (4) | `SEV` is the guest's | 1 |
| 2 | `PAUSE` | `HINT #1` (5) | a no-op | 0 |
| 3 | `PRIO` | `SPL` and a changing `MTPS` (6) | the priority is the guest's virtual priority | 0 |
| 4 | `TLBI` | `TLBI` (7) | the invalidate acts on the guest's own tag (6.16.24) | 0 |
| 5 | `TLBIA` | `TLBIA` (7) | as above | 1 |
| 6 | `TLBSYNC` | `TLBSYNC` (7) | as above | 1 |
| 7 | `ASID` | `MTASID`, `MFASID`, `MTSR` and `MFSR` of `ASID` (8) | the tag keeps the numbers apart | 0 |
| 8 | `PTBR` | a write to `PTBR` (9) | the guest's own register | 0 |
| 9 | `MMUCTL` | a write to `MMUCTL` (10) | the guest's own register | 0 |
| 10 | `VBR` | a write to `VBR` (11) | the guest's own register | 0 |
| 11 | `CPUID` | `MFCPUID`, `MFSR CPUID` (13) | `VCPUID` is returned (6.16.14) | 0 |
| 12 | `ICINV` | `ICINV`, `ICINVA` (14) | they execute (6.16.12) | 1 |
| 13 | `BPT` | `BPT` (15) | the guest's own breakpoint exception | 0 |
| 14 | `STEP` | an exit after each guest instruction (16) | none | 0 |
| 15 | | reserved | | 0 |
| 16 to 23 | `TRAPMASK` | `TRAP #n` and `TRAPL #n`, bit k for the numbers 32k to 32k + 31 (17) | the guest's own system call (6.16.11) | 0 |

**6.16.10** Some events have no bit in `HTRAP`. These **always exit**: `HALT` (6.16.11); `MTDMW` and `MTSR` and `MFSR` of `DMW0` and `DMW1` (6.16.13); `PROBER` and `PROBEW` that meet a stage-2 miss (6.16.21); any use of a hypervisor register or of `GENTER` (6.16.30); every stage-2 fault, a stage-2 miss on the vector fetch or the page-table walk, and a machine check (6.16.23); and every physical interrupt (6.16.26). These are **the guest's own** and never exit: an illegal instruction, a privileged instruction, the page faults and protection faults of stage 1, `TRAPCC` and the overflow checks, `TRAP #n` outside the routed range, an unassigned system-register number, and `ISYNC`. The guest's own privilege check comes first: an instruction that the guest's current mode may not execute (`WFE` in a guest's user mode) raises the guest's privileged-instruction exception, vector 3 in the guest, and never reaches `HTRAP`.

**6.16.11** `HALT` always exits (exit code 2). A range of `TRAP #n` and `TRAPL #n` numbers is routed to the hypervisor by the 8-bit **hypercall mask** in bits 16 to 23 of `HTRAP`: bit k routes the numbers 32k to 32k + 31. That is the hypercall; it has no opcode of its own. A routed `TRAP` is a trap: the instruction completes, `HEPC` is the next instruction, the exit code is 17, and the vector in `HCAUSE` is 256 + n. It is routed at any guest mode. The mask is zero at reset. `WFE` traps by default and may be untrapped for a guest that owns a core; `SEV` traps by default so that the hypervisor limits it to the cores of the guest.

**6.16.12** `ICINV` and `ICINVA`, and the unscoped `TLBIA` and `TLBSYNC`, trap by default for a guest (6.16.9) because the time they take shows what the other guests are doing. The bits can be cleared for a guest that owns its core. `ICINV` and `ICINVA` are unprivileged and do not touch data, and a program that generates code needs them.

**6.16.13** `MTDMW` and the direct-mapping windows `DMW0` and `DMW1` always exit (exit code 12) when a window takes effect: `MTDMW`, and `MTSR` and `MFSR` of `DMW0` and `DMW1` of a guest. A window takes effect over real physical memory, so no bit turns the exit off.

**6.16.14** `MFCPUID` is privileged. Each guest has a virtual core number, set by the hypervisor in `VCPUID` (16 bits). When a guest runs, `MFCPUID` and `MFSR CPUID` return `VCPUID`; at `H` = 1 they return the real core number. If the `CPUID` bit of `HTRAP` is set they exit instead (exit code 13).

### Exits, entry and what is saved

**6.16.15** `HEXITR` says why the guest stopped, finer than the vector. The code is in bits 7 to 0 and two flags are in bits 9 and 8. `HEPC` is the address of the next instruction for a trap and an interrupt, and the address of the instruction for a fault (it is run again).

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
| 19 | stage-2 fault: the entry is invalid | 18 (instruction fetch), 19 (load), 20 (store) | the instruction |
| 20 | stage-2 fault: the entry refuses the access (permission, a reserved bit set, accessed or dirty clear) | 18, 19, 20 | the instruction |
| 21 | machine check in a guest: a device answered a guest's real access, or a read of a stage-2 table, with an error | 1 | the instruction |
| 22 | stage-2 fault: the address is one that, by the platform map, no device answers (a table entry that points at nothing, or a guest's access to nothing) | 18, 19, 20 | the instruction |
| 23 | stage-2 fault: a stage-2 table lies outside the arena (6.16.25) | 18, 19, 20 | the instruction |

Flags: bit 8 `WALK`: the failing access was the read of a guest page-table entry, so `HGPA` is the guest-physical address of that entry and `HEVA` the address the guest was trying to reach; bit 9 `VEC`: it was the guest's vector fetch, so `HGPA` is the guest's `VBR + 8 * vector`.

**6.16.16** An exit enters the hypervisor through a **vector table** of 8-byte entries at the address `VBR + 8 * HCAUSE`, where `VBR` is the hypervisor level's own (6.16.4) and the table is read through the hypervisor's own translation when it is on (6.16.5): the same fetch as the kernel's (6.3.3). The vectors are:

| Vector | Meaning |
|---|---|
| 17 | an exit for an instruction (all codes 2 to 16 and 18) |
| 18 | guest-physical instruction fault (a stage-2 fault on an instruction fetch) |
| 19 | guest-physical load fault |
| 20 | guest-physical store fault |

**6.16.17** `GENTER` enters a guest. Before it the hypervisor, at `H` = 1, loads the guest's state (6.16.20) and writes `HEPC` and `HEPSW`. `GENTER` includes an `ISYNC` (6.5.2), discards the guest's cached translations if the arena's flag or the epoch word says so (6.16.25), loads the status word from `HEPSW`, makes the guest's registers the live ones, loads the program counter from `HEPC`, clears `H`, and clears every register that its mask does not name (6.16.18). If a virtual interrupt line is pending and above the guest's priority, it is taken at the boundary before the first guest instruction. There is no operand that asks for a flush: the hardware decides.

**6.16.18** **`RTI #mask` is the only form of `RTI`, and `GENTER #mask` is the only form of `GENTER`.** The mask has one bit for each of `R0` to `R31`; a register whose bit is one keeps its value, and the hardware clears every other register in the same step as the return to a less privileged mode (or the entry of a guest). `R14`, the banked stack pointer, is never cleared, so its bit is free and means: **keep the vector registers**; with it zero, the vector registers (the hidden accumulators included) and the floating-point sticky flags are cleared too. A return to the same mode ignores the mask. `RTT` returns and sets the trace bit after, and takes the mask as `RTI` does. The mask is in the instruction; no system register holds it. The hypervisor keeps nothing in registers across `GENTER`; the callee-saved set of the ABI (chapter 3) says which registers a handler returning to a program must name, and `R16` to `R23` are caller-saved scratch.

**6.16.19** An exit is made in this order. *(1)* An event that aborts an instruction is undone (6.4). *(2)* The reason and the vector are decided and the word at `VBR + 8 * HCAUSE` is read; a bus error here is a machine check of the hypervisor and nothing has been changed. *(3)* `HEPC` is written with the address of the instruction (an abort) or of the next instruction (a trap or an interrupt); `HEPSW` with the guest's whole status word, and with the token of 6.16.31 in its upper half when a block was suspended; `HEVA`, `HGPA` and `HINSN` as the table of 6.16.15 and 6.16.7 say, else 0; `HEXITR` and `HCAUSE`. *(4)* `H` is set. The status word is made as in 6.3.2: the current mode kernel, the previous mode the guest's current mode, priority 7, the trace bit, the flags and the guard clear. The names of 6.16.4 mean the hypervisor level's own registers. *(5)* Any `LL` reservation is cleared, and the vector block's resume record is made as 6.16.31 says. *(6)* The program counter is the word read in step 2. Not written: any register of the guest, and no general register. Not done: no translation-buffer entry is removed and `GTBR` is not changed. A stage-2 fault on the vector fetch of the instruction's own entry (`TRAP`, `BPT`, a check trap) is an exit with `HEPC` at the instruction: it is retried.

**6.16.20** At a world switch (an exit followed by the entry of a guest) the hardware saves and loads only the guest's program counter and its status word. The hypervisor saves and loads the rest in software:

| What | How the hypervisor reaches it |
|---|---|
| `PTBR`, `EPC`, `EVA`, `ECAUSE`, `DMW0`, `DMW1`, `USP`, `SSP`, `EPSW`, `VBR`, `MMUCTL`, `ASID` | `MFSR` and `MTSR` of `GPTBR` to `GASID` |
| `R14` of the kernel mode and `DP` of the three modes | `GKSP`, `GKDP`, `GSDP`, `GUDP` |
| the general registers other than `R14` | ordinary loads and stores, and `GENTER #mask` naming the ones loaded |
| the floating-point status | `FSFLAGS`, an unprivileged instruction |
| `HTRAP`, `GTBR`, `VIRQ`, `VIVEC`, `VTOFF`, `VCPUID`, `GTIMECMP`, `GTOKEN` | `MFSR` and `MTSR` |

### Translation in two stages

**6.16.21** Translation of a guest's memory is in two stages in hardware: the guest's page tables (**stage 1**) turn a guest-virtual address into a guest-physical address, and a second set of tables (**stage 2**), with a second root, turns that into a physical address (6.16.22). A guest tag in each translation-buffer entry lets one guest's entries be invalidated without the rest (6.16.24); a fault in the second stage is an exit that reports the guest-physical address. The vector fetch and the page-table walk of a guest go through the second stage too, and a second-stage miss on either is an exit, not a machine check. `PROBER` and `PROBEW` in a guest test both stages; a second-stage miss exits (code 19 or 20) and the probe runs again after the hypervisor has filled it; a stage-1 miss gives the probe's ordinary answer.

**6.16.22** `GTBR` holds the whole of stage 2's identity in one register, so that one write changes the root and the tag together. Bit 0 is `S2EN` (stage 2 on; with it clear the guest-physical address equals the physical address); bit 1 is `NEW`, which a write sets to ask the hardware for a fresh tag and which reads as zero; bits 39 to 12 are the physical page number of the stage-2 root; bits 63 to 48 are the **guest tag**, 16 bits, 0 being the host; the other bits are refused (6.16.7). **The guest tag is allocated by the hardware**: a write with `NEW` set puts into the tag field the next number of a 16-bit counter, after discarding every entry that carries that number in the translation buffer and in the IOMMU, so that a number handed out again is a new generation by construction; a write without `NEW` whose tag field is neither 0 nor a number the hardware has handed out is refused. The width is 16 bits everywhere (`TAGBITS` of 6.16.8). A **stage-2 entry** is the page-table entry of 6.7 with `U` and `G` required to be zero; a set `U` or `G` is a refused entry. Stage 2 has three levels of 512 entries over a root of **one page**, as every root has, so that it covers the 39-bit guest-physical space; `LEVELS` and `PABITS` of 6.16.8 tell software how many levels and how wide a machine has. The accessed and dirty bits of stage 2 are managed by software like stage 1's (6.8.1): a clear `A`, or a clear `D` on a write, is a refused entry, code 20, which gives the hypervisor dirty-page tracking. The permissions of an access are those of both stages together, the size of the page that the buffer holds is the smaller of the two, and **the stricter memory category wins**: the category of an access is the strictest of three terms, the category of the stage-1 entry, that of the stage-2 entry, and the category that the **platform map** gives the physical address; the order, strictest first, is device strongly ordered, device weakly ordered, uncached, cached. The platform map of device ranges replaces the old device bit of the address.

| Bits of `GTBR` | Field | Meaning |
|---|---|---|
| 0 | `S2EN` | stage 2 on |
| 1 | `NEW` | write: allocate a fresh tag |
| 39 to 12 | root | physical page number of the stage-2 root |
| 63 to 48 | `GTAG` | the guest tag; 0 is the host |
| the rest | | zero (a write of a one is refused) |

**6.16.23** What stage 2 does for each access of a guest. A guest page-table entry that stage 1 reads has a guest-physical address, which goes through stage 2 before it is read, and so does the final guest-physical address; with n levels in stage 1 and m in stage 2 a miss reads nm + n + m entries (15 for three and three), and a guest with its translation off walks stage 2 only. A stage-2 entry that is invalid or refuses the access is an exit: code 19 or 20, with `HCAUSE` 18, 19 or 20 for an instruction fetch, a load or a store; `HEPC` is the faulting instruction, `HEVA` the guest-virtual address, `HGPA` the guest-physical address that failed (for a table read, the address of the entry and the flag `WALK`; for the vector fetch, the guest's `VBR + 8 * vector` and the flag `VEC`) and `HINSN` the instruction. The hypervisor fills or corrects the entry, sets `A` and, for a write, `D`, and enters; the guest runs the instruction again. The same holds for a miss inside an exception entry of the guest: the instruction is undone. On the vector fetch of a guest's exception or interrupt, a miss exits with nothing changed, so that the guest takes the exception after the fill; a virtual line stays pending. **A bus error on a stage-2 table read or on a guest's access is split by what the platform map says about the address, not by what the bus does:** if the map says that no device answers there, it is an exit the hypervisor can handle (code 22; for a table read, the entry points at nothing, which is an invalid entry); if a device is there and answers with an error, it is a machine check (code 21). The same program on two interconnects gets the same exit.

**6.16.24** Each translation-buffer entry is keyed by the guest tag, the address-space number, the guest-virtual page and the global bit, and holds the final physical page and the permissions of both stages. A hit needs the tag to match, and the global bit means global within the tag. While a guest runs the buffer uses the tag in `GTBR`. An invalidate acts as follows. *(a)* A guest's own `TLBI`, `TLBIA`, `TLBSYNC` and `MTASID`, when not trapped, act on entries of its own tag only, on every core. *(b)* The rules of 6.8.4 and 6.8.5 apply per tag. *(c)* A write to `GTBR` that changes the root or `S2EN` discards every entry of the tag it writes; a write that changes only the tag discards nothing. *(d)* **`TLBIAS`** (invalidate by address-space number) exists: it invalidates every entry of an address-space number, in the issuer's tag, on every core, waited for by `TLBSYNC`. *(e)* **An invalidate by guest-physical page, `TLBIGPA`, is a separate mnemonic**, used by the hypervisor after a change to a stage-2 entry; the hypervisor's `TLBI` of the guest-virtual form is not used for that. A change to a stage-2 entry that was valid is followed by an invalidate for the guest and `TLBSYNC`. As in 6.8.4 an implementation may discard more than these rules require, and no program may depend on an entry surviving.

**6.16.25** **A guest never sees a stale translation of a changed stage-2 table**, and the hypervisor is not asked to remember how that is kept. *(a)* The hypervisor tells the hardware its **arena** by `HARENA`: one contiguous run of real pages, the first page number in bits 55 to 28 and the number of pages in bits 27 to 0; zero means no arena. Every stage-2 table must lie inside the arena, and a stage-2 walk that reads an entry outside it is an exit with code 23. *(b)* A store by this core into the arena, and every write of a guest's translation register at `H` = 1 (`GTBR`, `GPTBR`, `GASID`, `GMMUCTL`), even with the same value, sets a flag; `GENTER` discards every cached translation of the guest, and clears the flag, if it is set. *(c)* **When no arena is set the flag is always set**: every guest entry discards the guest's translations, so the safe thing is what happens when nobody did anything, and the fast path is asked for by setting an arena. There is no flush bit. *(d)* **A device never writes the arena**: the IOMMU refuses a device write to an arena page, as it refuses a device write to a system register, and counts it. *(e)* **Other cores are covered by an epoch word in memory**: `HEPOCH` holds the real address, inside the arena, of a 64-bit word; a core that has stored into the arena adds one to it with one atomic add at its next guest entry or its next `FENCE`; a core entering a guest loads the word and, if it differs from the value that core kept at its last discard, discards every cached translation of the guest and keeps the new value. An edit of a stage-2 table therefore takes effect for another core when the editing core publishes it, at its next entry or barrier; a guest already running on another core keeps the translations it has until it exits, and the hypervisor stops it sooner with an interrupt, which always exits (6.16.26).

### Interrupts, timer, devices, nesting

**6.16.26** A physical interrupt always exits (exit code 1), whatever the guest's priority; the vector of the highest line (the highest level, then the lowest vector number) is in `HCAUSE` and the next instruction in `HEPC`; the line stays asserted until the hypervisor clears it at the device.

**6.16.27** A guest sees seven **virtual interrupt lines**, one for each priority level 1 to 7. `VIRQ` bit L, for L from 1 to 7, says line L is pending; bit 0 reads zero. `VIVEC` has a field of 8 bits for each line (line 1 in bits 7 to 0, line 7 in bits 55 to 48) that holds the vector number the guest takes; **a write that puts a vector below 32 in a field is refused at once with an illegal instruction**. The hypervisor injects an interrupt by setting the bit of the line. Between two instructions of a guest, if no physical interrupt is asserted and the highest pending line L is above the priority in the guest's status word, the core makes the guest's own exception entry (6.3) with the vector of the line: the vector word is read at the guest's `VBR + 8 * vector` through stage 2, `EPC` is the next instruction, `EPSW` the old status word, `EVA` 0, `ECAUSE` the vector, the new status word is kernel mode with priority 7, and the hardware **clears the bit of the line** (for line 6 only the bit that the hypervisor set; the timer's part follows the comparator, 6.16.28). No exit is made. A guest's `SPL` and `MTPS` never exit (unless `PRIO` of `HTRAP` is set). A physical interrupt at the same boundary exits first. `WFE` in a guest ends when a virtual line is pending, even if the priority masks it (7.10.2).

**6.16.28** The timer is two system registers, **`TIME`** (number 16, read only) and **`TIMECMP`** (number 17). `TIME` is one 64-bit counter for the machine, which counts at a fixed 10 MHz, cannot be written, and never goes back: a read that begins after another core's read has finished is not smaller. `TIMECMP` is the core's deadline, an absolute counter value; **zero means never**, and it is zero after a machine reset. While `TIME` is at or past a deadline that is not zero, the core's timer line is asserted, as a **level**, at level 6, vector 32; software clears it by writing a later deadline or zero. A write to `TIMECMP` takes effect before the next instruction, so an interrupt is never taken for a deadline that the write removed. There is no periodic mode: a periodic tick is the handler adding the period to the old deadline. At the hypervisor level the two names reach the real counter and the real comparator, which keeps running while a guest runs. In a guest `TIME` is the real counter minus `VTOFF` (a register of 64 bits), and `TIMECMP` is the guest's own comparator; while the guest's counter is at or past a deadline that is not zero, **virtual line 6 is asserted as a level**, in addition to the bit of `VIRQ` that the hypervisor may set. A guest has no way to read the real counter. The hypervisor loads the guest's deadline before `GENTER` and saves it after an exit through `GTIMECMP` (number 148), which is zero after a machine reset and after a guest reset; while the hypervisor runs, the guest's comparator keeps running and a virtual line is not delivered until the next entry, and a hypervisor that does not want that writes zero. With `HVE` = 0, `GTIMECMP` is an illegal instruction and `VTOFF` counts as 0. No unprivileged instruction reads the counter (6.16.2).

**6.16.29** A device can be assigned to a guest through the IOMMU of 2.11. In version 1 the guest's unit is virtual and trapped: the hypervisor forwards the guest's commands and faults, and there is no guest-visible hardware ring. The interrupt controller's side for a core is system registers, readable and writable at the kernel level only; the interrupt page exists for devices only, is reached through the IOMMU's per-device table, and **refuses any access from a core**. A guest's version of the controller is the seven virtual lines of 6.16.27.

**6.16.30** There is no nested virtualization in version 1: a guest's use of any hypervisor register or of `GENTER` exits with code 18, after the guest's own privilege check, and the hypervisor may make it look like an illegal instruction.

### Vector blocks, instruction guarantees, reset, first software

**6.16.31** A vector block that an exception or an exit interrupts **resumes where possible, and resume is optional**: an implementation that keeps no record is a conforming implementation, and no program may depend on resuming. The hardware keeps one hidden **resume record** for each core: the address of the block's `VEC`, the tag of the context (guest tag, address-space number, mode, and whether the hypervisor is running), the entry and current values of the changed registers, and a one-use **token**. A block that changes more than **four** registers has no record and starts again. The handler is shown the entry values of the registers, `EPC` at the `VEC`, and the token in bits 63 to 32 of `EPSW` (`HEPSW` for an exit). The block resumes at the strip where it stopped only if the return carries the record's token, goes to the address of the `VEC`, has the record's context, and finds the changed registers at their entry values. The record is discarded, and the block starts again from its first strip, with its sums zero, on: any vector instruction that is not a resume; a write to `ASID`, `PTBR`, `MMUCTL` or `GTBR`; `GENTER` into another guest; `ICINV`, `ICINVA`, `TLBI`, `TLBIA`, `TLBIAS`; a return that presents the token but fails a check; a machine check; a later suspension; reset. The record stays on its core and dies, never moves, if the context moves to another. The **token** is a keyed permutation of a counter that the hardware keeps for each guest, 32 bits wide, so that it does not repeat within 2^32 suspensions of one guest and shows a guest nothing of other guests' suspensions; the hypervisor loads the guest's key and counter by `GTOKEN` with the rest of the guest's state. A block covers at most **256 strips**; a longer job is cut into blocks. An interrupt or an exit is taken at a **strip boundary**, never inside a strip; a strip commits all its stores or none. `VCLR` outside a block is refused: **`VCLR` is valid only inside a block**. A block with accumulators whose main loop stores through the register that it loads through is refused at the `VEC`, before any work. The size of the strip is not hidden: `STRIP` of `FEATURES` gives it. A block is not atomic against other writers of memory.

**6.16.32** Four more guarantees that a guest and a native kernel share. *(a)* **`ISYNC` is the instruction-stream fence in every mode**, unprivileged: a program that writes code, invalidates with `ICINV` and executes `ISYNC` runs the new code. *(b)* A block operation (`MCPY`, `MSET`) writes **each aligned 8-byte unit whole and at most once**, and no order is promised to a second observer. *(c)* The floating-point flags are cleared when the address-space number, the guest register `GTBR` or the page-table base is written. *(d)* Every hole and information bleed this section closes has a test in the assembler corpus.

**6.16.33** The table gives, for every register and for the state that is not in a register, what a core holds after a machine reset and what the hypervisor puts a guest in by a guest reset. A guest after a guest reset is a machine after a machine reset, except that the hypervisor's registers keep the hypervisor's values and `CPUID` returns the guest's virtual core number.

| Register | After a machine reset | After a guest reset |
|---|---|---|
| status word | kernel mode, previous mode kernel, priority 7, trace 0, flags 0, guard 0 | the same |
| `PC` | the platform's reset entry | the guest's reset entry, in `HEPC` |
| 0 `PTBR`, 1 `EPC`, 2 `EVA`, 3 `ECAUSE`, 4, 5 `DMW0`, `DMW1`, 6, 7 `USP`, `SSP`, 8 `EPSW`, 9 `VBR`, 10 `MMUCTL`, 11 `ASID` | 0 (translation off) | 0 (through `GPTBR` to `GASID`) |
| 12 `CPUID` | the core number | `VCPUID` |
| `R14` of the kernel mode | set by the platform's boot protocol (chapter 4) | set by the hypervisor's boot protocol |
| the other `R14` copies and the three `DP` | 0 | 0 |
| the general registers other than `R14`; the vector registers | 0 | zero, set by the hypervisor |
| the floating-point status | 0 | 0 |
| any `LL` reservation, the resume record | cleared | cleared |
| cached translations of the guest's tag | none | none |
| 128 `HTRAP` | `WFE`, `SEV`, `TLBIA`, `TLBSYNC` and `ICINV` set, the rest 0 | the hypervisor's policy |
| 129 to 135 `HEXITR`, `HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, `HGPA`, `HINSN` | 0 | not defined; `HEPC` and `HEPSW` are the resume point |
| 137 `GTBR` | 0 | the guest's root, `S2EN` set, its tag |
| 138, 139 `VIRQ`, `VIVEC` | 0 | 0 |
| 140 `VTOFF` | 0 | the hypervisor's value |
| 142, 143 `HARENA`, `HEPOCH` | 0 | not a guest's |
| 144 `GTOKEN` | 0 | the hypervisor's value |
| 16 `TIME` | counts from 0 | the guest's counter starts where `VTOFF` puts it |
| 17 `TIMECMP`, 148 `GTIMECMP` | 0 (never) | 0 (never) |
| 141 `VCPUID` | 0 | the guest's virtual core number |
| 149 to 164 | 0 | 0 |

**6.16.34** There is no hardware event for a guest reset: no instruction resets a guest. A guest asks for a reset by a hypercall or by touching a virtual device, and both exit. The reset is an operation of the hypervisor, in this order. *(1)* Stop the guest's cores. *(2)* For each device assigned to the guest, block it and invalidate the unit's translations for the guest tag (2.11.8), and wait for the unit. *(3)* Write `GTBR` with the new root (the hardware discards the old translations, 6.16.24 and 6.16.25), then write the guest's `MMUCTL` as 0. *(4)* Write every system register and every other piece of state to the value of the table of 6.16.33. *(5)* Zero the general registers and the floating-point status, set `HEPSW` to the reset status word and `HEPC` to the guest's reset entry, and execute `GENTER` with the mask of the registers it loaded. The hardware, not this sequence, keeps the old guest's translations from the new one.

**6.16.35** The first software to use all of this is a small hypervisor of our own, on the QEMU target, with one guest kernel; it is not Linux and not KVM. It is written in assembler, in one file with the guest kernel; it boots at `H` = 1 on physical addresses, builds its own vector table and its stage 2, routes a range of `TRAP` numbers to itself for the guest's console output, gives the guest a virtual core number, a virtual timer and a virtual line for it, and enters the guest. The guest builds its own page tables and turns translation on, touches a page that stage 2 does not map yet (the hypervisor maps it and the instruction runs again), takes its timer interrupt, runs a user program that makes a system call that must not exit, and stops with `HALT`; the hypervisor handles every exit.

## PASTE ENDS: section 6.16

---

## PASTE BEGINS: the bullet for section 6.17 (the old 6.15 "What was checked, and what was not"), replacing the bullet "Checked in 6.14"

* **Checked in 6.14 to 6.16** (every sentence quoted was found in the document named, on the date given; quotations are under 25 words):

  * R. J. Creasy, "The Origin of the VM/370 Time-Sharing System", *IBM Journal of Research and Development* 25(5), September 1981, pages 483 to 490. https://lass.cs.umass.edu/~shenoy/courses/fall07/papers/vm370.pdf, read 2026-11-25. "CP is an operating system that uses a computing machine to simulate multiple copies of the machine itself." "they required a dedicated hardware system, usually at night or on weekends". "CP and CMS have seen continuous production use since 1967." "VM/370 became available in 1972 for the IBM System/370 computer family whose members all included virtual memory hardware." "The CP/CMS system was conceived in 1964 as a second-generation time-sharing system for the newly announced IBM System/360." The system was designed and built by Creasy and his group at "the IBM Systems Research and Development Center in the mid-1960s", now the IBM Scientific Center in Cambridge, Massachusetts. The text extraction of the page that dates CP-40 and CMS misreads a digit, so no year is printed for them. "As they are encountered in problem state, the machine blocks their execution and transfers control to a designated program."
  * G. J. Popek and R. P. Goldberg, "Formal requirements for virtualizable third generation architectures", *Communications of the ACM* 17(7), July 1974, pages 412 to 421. https://course.ece.cmu.edu/~ece845/docs/p412-popek.pdf, read 2026-11-25. "A virtual machine is taken to be an efficient, isolated duplicate of the real machine." Theorem 1 as quoted in 6.14. "Another example of a control sensitive instruction is JRST 1, on the DEC PDP-10, which is a return to user mode." The key words of the paper include "hypervisor, virtual machine monitor".
  * G. J. Popek and C. S. Kline, "The PDP-11 Virtual Machine Architecture: A Case Study", *Proceedings of the Fifth Symposium on Operating System Principles*, ACM, 1975, pages 97 to 105, doi 10.1145/800213.806527. https://bibtex.github.io/SOSP-1975-PopekK.html, read 2026-11-25: **the bibliographic record only; the text of the paper was not read.**
  * O. Agesen, J. Mattson, R. Rugina, J. Sheldon, "Software Techniques for Avoiding Hardware Virtualization Exits", USENIX ATC 2012. https://usenix.org/system/files/conference/atc12/atc12-final158.pdf, read 2026-11-25: Table 1 starts with Intel Prescott, launch date 3Q2005.
  * RISC-V, privileged architecture, chapter 14.1 '"H" Extension for Hypervisor Support, Version 1.0', in the Ratified Specifications Library, v20260120. https://docs.riscv.org/reference/isa/v20260120/priv/hypervisor.html, read 2026-11-25. "to support the efficient hosting of guest operating systems atop a type-1 or type-2 hypervisor". No ratification date was found on the page.
  * *PDP-11 Processor Handbook*, 1979 edition (read 2026-11-19): `HALT` traps outside kernel mode; outside kernel mode "the processor will ignore the 'RESET' and 'SPL' (Set Priority Level) instructions, and will execute No Operation".
  * CVE-2026-99312 (Linux kernel, KVM x86), published 2026-11-18. https://cveawg.mitre.org/api/cve/CVE-2026-99312, read 2026-11-25: "an INIT while L2 is running with CR0.PG=0 will result in KVM running L1 with a stale MMU context".
  * *Not checked, and so not stated:* the date of the PDP-11's announcement; the content of Popek and Kline's paper; the dates of CP-40, CMS and of the RISC-V and Arm virtualization extensions; the first use of the word "hypervisor"; the virtualization of the VAX, of the x86 before 2005, and of Arm; present industrial uses; the name or the operating systems of other PDP-11 systems (the scene of 6.14 names none for that reason); the date of IBM's interpretive-execution mode; seL4's use as a hypervisor (said only as the aim of this project).

## PASTE ENDS

---

# The three lists for the owner

## List 1. Every sentence of the current manual that this text replaces, or that becomes wrong

**A. Which numbers change.** *Three sections:* the new 6.14, 6.15 and 6.16 replace the current 6.14; the current 6.15 becomes **6.17**; the citations of 6.15 and 6.14 elsewhere change as listed. *One section (fallback):* the statements are 6.14.1 to 6.14.35, the current 6.15 stays, and the citations below change to the 6.14.N numbers of the same statements.

**B. The current 6.14.** All of it is replaced: the introduction ("What you already know", "Who needs it today", "What it means not to have it", "What it costs") by sections 6.14 and 6.15, and the statements 6.14.1 to 6.14.14 by 6.16. The "Who needs it today" table is gone (the product documents it quotes have no recorded address, list 3 item 8). Map, old to new: 6.14.1 to 6.16.1; 6.14.2 to 6.16.2 and 6.16.28; 6.14.3 to 6.16.3, 6.16.4, 6.16.5, 6.16.6, 6.16.7 and 6.16.8; 6.14.4 to 6.16.21 to 6.16.25; 6.14.5 to 6.16.26, 6.16.27 and 6.16.28; 6.14.6 to 6.16.29; 6.14.7 to 6.16.30; 6.14.8 to 6.16.33 and 6.16.34; 6.14.9 to 6.16.31 (and the clears at exit and entry to 6.16.18 and 6.16.19); 6.14.10 to 6.16.35; 6.14.11 to 6.16.14; 6.14.12 to 6.16.11; 6.14.13 to 6.16.12; 6.14.14 to 6.16.13. New statements with no old one: 6.16.9, 6.16.10, 6.16.15 to 6.16.20 (the traps, exits, entry and mask), 6.16.32.

**C. Sentences elsewhere that name the old numbers or are now wrong:**

1. `06-kernel.md`, line 5: "listed in section 6.14" becomes "listed in section 6.17"; line 7: "(section 6.15)" becomes "(section 6.17)".
2. `06-kernel.md`, 6.1, "User mode may not execute `halt`, `reset`, `wait` or change the priority (*unverified*)": the handbook (read) says `HALT` traps and `RESET` and `SPL` are ignored outside kernel mode. Replace by that, still marking `wait` unverified.
3. `06-kernel.md`, 6.8.5: "or of a guest if the machine ever runs guests" becomes "or of a guest"; "(for a guest see 6.14.8, ...)" becomes "(for a guest see 6.16.24, 6.16.25 and 6.16.34, ...)".
4. `06-kernel.md`, 6.8.3 (the `TLBI` text): add `TLBIAS` (invalidate by address-space number) and `TLBIGPA`, and that a broadcast carries the issuer's tag; J.6.8 is decided for `TLBIAS`.
5. `06-kernel.md`, 6.2.5 (the privileged list): add `GENTER`, and "At `H` = 1 all are allowed (6.16.4)".
6. `06-kernel.md`, 6.3.5 and 6.13.2 (`RTI`, `RTT`), and the `RTI` entry of chapter 9: they describe an `RTI` without a mask and become wrong. There is only `RTI #mask` (and `RTT #mask`), the mask has bit 14 for the vector registers and the floating-point flags, and a return to the same mode ignores it (6.16.18).
7. `06-kernel.md`, 6.3.6 table: the row 17 to 31 "reserved" becomes 17 to 20 "exits to the hypervisor" and 21 to 31 "reserved".
8. `06-kernel.md`, 6.3.7: add that in a guest only the virtual lines are masked by the priority (6.16.26, 6.16.27).
9. `06-kernel.md`, 6.5.1: the registers 128 to 144 and 148 to 164 (and `FEATURES` 32, `TIME` 16, `TIMECMP` 17 and the interrupt controller's group); the count "243 unused" in the Lineage changes. Also: `MFSR` is privileged and no register is readable outside kernel mode.
10. `06-kernel.md`, 6.12.1: add that with `HVE` the core starts with `H` = 1. 6.13.1, 6.13.3, 6.13.6: add the hypervisor mode, the names at `H` = 1 and `GENTER`.
11. `06-kernel.md`, **6.13.2 and 6.10.2** say `TRAP` and `TRAPL` both have n up to 255 in two bytes; the grammar says `TRAP` is 0 to 15 in two bytes and `TRAPL` reaches 255. The grammar is the source of truth: chapter 6 must be corrected to it (example 3 of 6.15 uses it).
12. **`06-kernel.md` 6.14.9 and `09-isa.md` 9.2.6, and the `GENTER` entry of 9.14**: "restarts from the entry of the block", "no hidden instruction state, except ... restarts from the entry", and the clear of the naming of the accumulators at every entry, return and world switch become wrong. 9.2.6 should say that the hidden record exists, is invisible to a program except for the token and the time, is optional, and is discarded as 6.16.31 says; the naming is no longer state (`VCLR` is valid only inside a block). `implementation-status.md` (the 6.14.9 bullet) is stale in the same way.
13. `02-bus.md`, 2.11.8: "(6.14.4)" becomes "(6.16.24)"; 2.11.2's "(6.14.…)" becomes "(6.16.29)". "Details to be determined: the width" is wrong: the width is 16 bits, allocated by the hardware (6.16.22). 2.11 also gains: the IOMMU refuses a device write to an arena page, and discards by tag when the hardware hands a tag out.
14. `07-smp.md`, 7.10.2: add the virtual lines (6.16.27); and the interrupt controller's core side in system registers, the page for devices only.
15. `appendix-parts/b-proposed.md`, B.2.11.1: "the statements of 6.14" becomes "the statements of 6.16".
16. `appendix-parts/06-open.md`, J.6.9 (supervisor mode): options 3 and 6 are moot because the hypervisor is a state bit (6.16.3). J.6.8: `TLBIAS` decided. J.2.1: the platform map and the timer registers (the core-local timer page is gone). The earlier proposal J.6.13 (memory types) is not needed.
17. `appendix-b-glossary.md`: add hypervisor, guest, host, exit, hypercall, world switch, stage 1, stage 2, guest tag, arena, epoch word, `H`, `HVE`, `GENTER`.
18. `tools/mkmanual.py` (lines about 332 and 364: generated text "(6.14, errata 195, 196)"), `tools/manual/isa_part3.py` (notes citing 6.14 and 6.14.11), `tools/manual/kernfigs.py` (comments citing 6.14): the citations change to 6.16 and 6.16.14.
19. `docs/manual-src/06-kernel.md`, the 6.15 bullets: "Unverified" keeps "which instructions the PDP-11 forbade in user mode" only for `WAIT` and the others; the "Checked in 6.14" bullet is replaced by the block above.
20. The timer and interrupt text of chapters 2, 5 (5.7.1) and 7 that describes the timer as a device page (a counter, a compare and a control register at three offsets), a user-readable time page, or the interrupt controller's per-core page as readable by cores: they become the system registers `TIME`, `TIMECMP` and the registers of the controller, with the page for devices only. Chapter 9: the counts of forms and leaves are hand text and are to be generated.

## List 2. The figures I propose (the scripts are `tools/manual/*figs.py`; I made none)

1. **The layers.** Three bands: user programs, guest kernels at their own kernel level, the hypervisor; the PDP-11/V7 stack beside it for comparison and the pdp64 with a hypervisor under two kernels.
2. **A timeline of the history:** 1964 CP/CMS conceived, 1967 production use of CP and CMS, 1972 VM/370, 1974 Popek and Goldberg, 1975 Popek and Kline, 2005 the Prescott processor; RISC-V shown with no date.
3. **The life of a guest:** a loop of two states, hypervisor and guest, with `GENTER #mask` going in and an exit coming out, and what the hypervisor does in between.
4. **The exit:** the registers written (`HEPC`, `HEPSW`, `HEVA`, `HGPA`, `HINSN`, `HEXITR`, `HCAUSE`) and the vector fetch at the hypervisor's own `VBR`, in the style of the figure of 6.3.
5. **Which events exit and which stay with the guest:** two columns (always exit; trap-control bit; guest's own), with `WFE`, `HALT`, `PTBR`, `TRAP`, a page fault as examples.
6. **The two-stage walk with the numbers of example 4:** `0x403A58` cut into 0, 2, 3, `0xA58`, the guest-physical `0x123A58`, the real `0x8F7A58`, the stage-2 walk of each guest table entry, and the three kinds of fault (invalid entry, no device, device error) in three colours.
7. **A virtual interrupt and a physical one:** timelines, with the priority comparison; and the level of line 6 against the deadline.
8. **The names at the two levels:** a table of which register a name reaches at `H` = 0 and at `H` = 1, with the `G` names (example 7).
9. **The arena and the epoch word:** the hypervisor's tables in one run of pages, a store setting the flag, the epoch word added by one core and read by another at entry.
10. **A vector block interrupted and resumed:** strips, the record, the token, and the discards.

## List 3. Contradictions, ambiguities and held-back matters the owner must settle

1. **"No fourth bank of `R14` and `DP`" against "the ordinary names mean the hypervisor level's own".** The two cannot both hold literally: if `R14` and `DP` at `H` = 1 are the hypervisor level's own registers, there is storage for them besides the guest's. I wrote the second (6.16.4, 6.16.6): what goes is the special rule that switched a bank at exit and entry, and the six aliases; the guest's `R14` and `DP` are reached by `GKSP`, `GKDP`, `GSDP`, `GUDP`. If the owner meant that the hypervisor level has no stack register of its own, the first instruction of an exit handler has no free register and a scratch register swapped by it (the earlier alternative) must come back.
2. **"The guest's registers are reached by explicit names" and "the six aliases go".** An explicit name for every guest register is a set of aliases again. I defined sixteen (`GPTBR` to `GUDP`, numbers 149 to 164: the twelve registers of 6.5 other than `CPUID`, and the four of the banks) and dropped the old six aliases and the vector-base register `HVBR`, because the hypervisor's `VBR` is now its own. The names, the numbers and the choice to have a copy of all twelve at the hypervisor level (including `USP`, `SSP`, `DMW0`, `DMW1`) are mine; the old numbers 136 and 145 to 147 are left unassigned. The first hypervisor test (`tests/qemu/hv-first.S`) uses `HVBR` and writes the guest's `PTBR` by the plain name at `H` = 1: it must be rewritten.
3. **The tag allocator's interface and liveness.** The decision is only "allocated by the hardware, 16 bits, a counter that flushes when it wraps". I made the allocation a bit `NEW` of `GTBR`, and said a hand-out first discards every entry of the number. A guest that stays alive across a whole turn of the counter (65,536 allocations) can be given the same number as a newer guest; the 182-gate design has no live bitmap. How the hardware avoids that is not decided: say what it does (refuse a new allocation, or re-tag the old guest at its next entry).
4. **The interface of the other new registers.** `HARENA` (field layout), `HEPOCH`, `GTOKEN` (key and counter) and `FEATURES` (number 32, the fields and their places) are my proposals; the decisions give only what they hold. `TLBIGPA` is my name for "a separate mnemonic". The decision on the token says only "keyed per guest"; where the key comes from (a random source at reset) is open, so a machine without one leaks a little through the count, which the text does not claim to close.
5. **Exit codes 22 and 23.** "A value of the cause, not a flag" for the no-device case gave code 22; the arena refusal ("its own cause") gave 23. Numbers are mine. The decision says a no-device answer is "an invalid entry"; I kept code 19 for an entry that is itself invalid and code 22 for an entry that points at nothing, which the exit tells apart.
6. **The default trap bits.** "Build the trap bits now, default set for a guest" does not name which. I set `TLBIA`, `TLBSYNC` and `ICINV` with `WFE` and `SEV` (6.16.9), the unscoped invalidates and the `ICINVA`, `TLBSYNC` of the audit; `TLBI` by address stays clear because it is scoped to the guest's tag.
7. **`RTT`.** The decision names `RTI #mask` only. I wrote that `RTT` takes the mask the same way (6.16.18); the grammar has to say so.
8. **Statements withheld because the source has no recorded address** (the decision is to state nothing from a source until it has one; each can return with its sentence when the address is recorded): Hall and Robinson, "Virtualizing the VAX Architecture" (ISCA 1991: the VAX has sensitive instructions that are not privileged; the security kernel; the 1981 prototype on a VAX-11/730; DEC's remark on Popek and Kline); Adams and Agesen, ASPLOS 2006 ("Until recently, the x86 architecture has not permitted classical trap-and-emulate virtualization"; the shadow page tables; the 2000 more cycles for a guest system call; the Intel and AMD references of 2005); Arm, "Armv8-A virtualization" (introduced in Armv7-A; the host kernel at EL1 with stub code at EL2); Bhargava, Serebrin, Spadini and Manne, ASPLOS 2008 (nm + n + m: I now give it as arithmetic, with no citation); the AWS, Microsoft, Docker, Android, QNX and GitHub documents of the table of present uses, the Linux KVM Kconfig and the OpenBSD `vmm(4)` page. The `HVE` strap and the 2005 and 2006 dates of the x86 story depend on them.
9. **The CP-40 date.** The checked source gives 1964 (conceived) and "continuous production use since 1967" for CP and CMS; its page that dates CP-40 prints a misread digit, and secondary sources place CP-40's first production use in January 1967 and its development from mid 1965. The text prints only the source's words.
10. **Timer: what is left as the current rule without being marked.** No unprivileged clock and no kernel-updated page are stated. The question of a hardware-rounded user read (register 18 reserved) is left out because it waits on a measurement of how often real programs read the clock; likewise the stage-2 accessed and dirty bits stay in software and the guest's IOMMU unit stays trapped (both wait for measurements, both are stated as the rule).
11. **The first-hypervisor facts.** `tests/qemu/hv-first.S` has a two-page stage-2 root (bit 39 for device space), the virtual timer as a mapped page, `HVBR`, plain `RTI` and `GENTER` without a mask, and a hypervisor that keeps counters in registers across `GENTER`; every one of these now contradicts the text, so 6.16.35 states only what stays true of it (one file, boots at `H` = 1 untranslated, `TRAP #224` for console output, demand-filled stage 2, virtual timer, the user system call that does not exit, `HALT`).
12. **Examples 10 and 11: the spelling of the size of an atomic.** The decisions give the sizes (4 and 8 bytes, the width in the sub-opcode) and the three-register layout but not how the assembler writes the size; the examples use the bare names for the 8-byte form. The constrained loop's bound of 16 instructions is the RISC-V figure, taken with "the constrained loop"; the decision names the loop, and the figure should be stated in the manual.
13. **Examples 10 and 11: the snippets of the atomics.** They are written in the decided three-register spelling; they are listed in the snippets README as not yet assemblable. Example 11's message-passing snippet runs on one core (the reader after the writer).
