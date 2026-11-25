# Why almost nobody ships sequential consistency, what it costs, and what that means for the pdp64

I wrote this for the owner's questions of 2026-11-25. The first: "there is a reason sequential consistency hasn't been done before. find out what it is." Then: "we can't be slow as a dog"; "i'm willing to give up 40% speed for sequential consistency, but i suspect we won't need to"; "if heavy techniques get us to within 2% speed, I'm ecstatic"; and questions about TSO, MIPS, safety and power. I opened and read every paper and manual I cite (they are listed, with the pages I read and the quotes, in `bench/sc/SOURCES.md`). I measured what I could in the repository's own timing model (`bench/sc/`). **Every number is labelled as published (and where, and on what kind of machine), as measured by me here, or as an estimate with its assumptions.** A claim from memory carries the words "from memory, not verified" and is not used in any conclusion.

## 1. The answers on one page

**Why nobody did it.** In 1979 Lamport defined sequential consistency and, in the same two-page note, warned that it "may not be worth the price of slowing down the processors". He was right for the machines of the next fifteen years. A processor that obeys it must finish each store, which on a machine with caches means telling the other processors, before the next load may run; the Stanford DASH group put a number on it in 1990: SC could gain at best a factor of 2 over a processor that stalls on every miss, where a relaxed model could in principle gain a factor of the whole miss latency. Every vendor that wrote a reason down gave speed (or "implementation freedom", the right to build a faster weaker core later). From 1991 on, researchers showed that speculation (guess, run ahead, undo if wrong) gets most of that speed back while the software still sees SC. One shipped core did it, the MIPS R10000 of 1996. By then SPARC, x86, Alpha and POWER had written the weaker rules into the instruction set, so there were programs that depended on them, and nobody could go back.

**What it costs, on the evidence.** Published simulations of 1997 to 2009 (small out-of-order cores, scientific and database work): SC with the 1991 tricks is about 10% to 38% slower than the most relaxed models, typically 15% to 25%; TSO is in between; with heavier machinery (one kilobyte of extra state) the gap fell to 2% against the most relaxed model in the 2009 simulation. My own measurement on the pdp64's in-order timing model (eight C programs, one core): **SC costs 0.9%, 3.7% or 9.3% more run time than TSO or a relaxed model when a store that misses the cache takes 10, 30 or 100 cycles, with the store's line requested early (ownership prefetch) and no speculation at all**; the worst loops (cold copy and clear, a table insert, building a list) pay 12% to 48%. That is a single-core number: it leaves out sharing (a crude sharing knob raises 9.3% to 14% or 30% when 5% or 20% of lines are owned by another core).

**TSO** ("total store order") is the rule that one thing only may be reordered: a processor's load may run ahead of its own earlier store to a different address. It is what x86 and SPARC have, and IBM's mainframes in effect. Section 4.

**MIPS.** MIPS did not abandon the R10000 method; its designers kept it in the whole R10000 family (R12000, R14000, R16000, the same core, per a secondary source) until the line ended with SGI's Origin machines. The MIPS *architecture* never required SC: the `SYNC` instruction has been there since MIPS II (the manual says so), the 2001 manual allows both kinds of system, and the Linux kernel marks the later MIPS cores (Broadcom SB1, Cavium Octeon, NetLogic XLR and XLP, Loongson-3, BMIPS) as weakly ordered while the R10000 is not. I found no document that gives a reason for the later cores being weak, so for the reason I write "not found". Section 5.

**Safety.** Yes, SC removes one whole class of bugs: the missing-barrier bug. Two real ones are documented below (a DPDK lock and a Huawei product lock, found by a tool in 2021; the Linux kernel's own ARM64 ordering fixes), and every other ISA I counted carries from 2 to about 180 ordering spellings that pdp64 code does not need. SC does **not** remove the bugs that dominate real concurrent programs: forgetting a lock, or assuming an order that nothing enforces, which a 2008 study found in 97% of the non-deadlock bugs it examined and which happen on an SC machine too. Section 7.

**Power.** On the in-order core SC adds three gates; ownership prefetch (a table of lines asked for) adds 2.8 thousand NAND2-equivalents, about 1% of the scalar core, and about 0.1 milliwatt in my simple model. An out-of-order core needs a load queue that is searched on each invalidation: 18 to 36 thousand equivalents for 32 to 64 entries (7% to 14% of the in-order core) costing 0.3 to 0.6 mW in my model and 2.5 to 6 mW by published CACTI energies; TSO needs the same queue. The one-kilobyte heavy technique adds 33 to 65 thousand equivalents and 0.6 to 1.1 mW. All of this is an estimate. Section 8.

**Recommendation.** Keep sequential consistency as the architecture. First implementation: the in-order core with a store buffer and ownership prefetch and no speculation (expected cost on my programs 1% to 9%, inside the owner's 40% and mostly inside his tolerance for the database figures). Later out-of-order cores: the R10000 method first (published 10% to 25% behind the most relaxed models); the heavy technique only if a measurement says the gap matters. If the measured margin cannot be kept, change the **architectural** model to TSO and nothing weaker; one binary still runs everywhere. Section 10.

## 2. The words

**Store buffer.** A small queue inside a processor. When the processor stores a word, the word waits in the queue and the processor carries on; the queue pushes it out to the cache later. It exists because a store that misses the cache can take a hundred cycles, and nothing needs to wait for it.

**Speculation.** Guessing and running ahead: executing instructions before it is known that they should run, keeping a way to undo them, and undoing them if the guess was wrong. A mispredicted branch is the familiar case.

**Coherence.** The hardware rule that keeps every processor's cached copies of a line of memory from disagreeing. To write a line a processor first gets **ownership**: every other cache throws its copy away (an **invalidation**) and says so.

**Litmus test.** A tiny two-processor program with one interesting outcome, used to find out which orderings a machine allows.

**Sequential consistency (SC).** The result of any run is as if all the loads and stores of all the processors happened one at a time, in one order, and each processor's own accesses appear in that order the way its program wrote them. On the PDP-11 you never thought about this: there was one processor and one place to look.

**CAM and NAND2 equivalent.** A CAM (content-addressable memory) is a table that compares a key against every entry at once, as an associative register file would; it is the structure that checks an incoming invalidation against all the loads in flight. A NAND2 equivalent is the repository's unit of circuit size: one two-input NAND gate (a flip-flop counts as six).

**Fence.** An instruction that means "everything before this is finished before anything after it starts". A weakly ordered machine needs fences wherever one processor hands data to another.

## 3. The story

### 3.1 Lamport's note (1979)

Leslie Lamport's note, "How to Make a Multiprocessor Computer That Correctly Executes Multiprocess Programs" (IEEE Transactions on Computers, September 1979, two pages, written in 1977), starts from a processor that runs its own instructions in a different order from the program's (which is fine for one processor) and asks what a machine of several must do for programs to be correct. His answer is the definition above. His example is the two-flag mutual exclusion protocol: each process sets its own flag, then tests the other's.

```
process 1:  a := 1;  if b = 0 then (critical section)
process 2:  b := 1;  if a = 0 then (critical section)
```

If the processor may run the test before the store, both can enter. He shows two ways to break it (a processor that does not issue requests in program order; memory modules that serve their queue out of order) and two requirements that fix them: each processor issues its requests in program order, and each memory module serves requests in one first-in first-out order. And then, on the last page: "For some applications, achieving sequential consistency may not be worth the price of slowing down the processors." and "verifying their correctness becomes a monumental task" for protocols designed without it. Both sides of this whole report are in those two pages.

### 3.2 The reason the weaker models were built (1990)

The Stanford DASH group's paper (Gharachorloo, Lenoski, Laudon, Gibbons, Gupta and Hennessy, ISCA 1990) is where release consistency, the weak model that it introduces, comes from. Its argument is a bound. Take a base processor that stalls on every cache miss. Then SC can at best gain a factor of 2, and processor consistency (the model with a store buffer) a factor of 3, over that base, by buffering stores behind computation; while a relaxed model can pipeline many misses at once and gain a factor near the miss latency divided by the time between two issues of misses. With a miss latency of a hundred cycles, 2 against many tens: that is the whole case for weak models, and for a processor that does not look ahead it is correct.

### 3.3 Speculation changed the bargain (1991 to 1999)

The same Stanford group's next paper (ICPP 1991) gave the two tricks: **ask for ownership of a store's line as soon as the store's address is known** (a hardware prefetch), and **let a load run early and undo it if the line it read is invalidated before the load would legally have run** (speculative load). Their abstract says that with the pair "the performance of different consistency models is equalized". The Adve and Gharachorloo tutorial (1995) notes that the undo "is suitable for dynamically scheduled processors since much of the roll back machinery is already present to deal with branch mispredictions." Mark Hill, who had advocated relaxed models, changed sides in 1998 ("Multiprocessors Should Support Simple Memory-Consistency Models", IEEE Computer, August 1998) and wrote that the future gap "will be in the range of 20 percent or less". Section 6 gives all the numbers.

### 3.4 Who shipped what, and the reasons their own documents give

| Who | Model | When | Reason the document gives | Source (opened) |
|---|---|---|---|---|
| MIPS R10000 (SGI) | SC, out of order | Apr 1996 | "Although execution is out of order, the processor still provides sequential memory consistency and precise exception handling." Stores are performed only at graduation, in program order; loads run early and are undone on an outside invalidation | Yeager, IEEE Micro, April 1996; R10000 User's Manual 1.1, section 1.5 |
| HP PA-RISC 1.1 | strongly ordered ("accesses appear to software to be done in program order") | manual of Feb 1994 | no reason given; it is stated as the rule | PA-RISC 1.1 manual, third edition, "Ordering of Accesses" |
| HP PA-RISC 2.0 | strongly ordered, ordered, or weakly ordered, chosen per page and per access | manual copyright 1995 | no reason given. A `,O` suffix on loads and stores and an O bit in the status word and in each translation entry choose the mode | PA-RISC 2.0 manual, appendix G |
| MIPS architecture | SC or weaker, implementation's choice | `SYNC` since MIPS II (year from memory, not verified); manual of 2001 | "Many MIPS-based multiprocessor systems are strongly ordered or have a mode in which they operate as strongly ordered" | MIPS64 Volume II 0.95, SYNC; MIPS32 Release 6.06 (Dec 2016) adds `SYNC_ACQUIRE`, `SYNC_RELEASE`, `SYNC_RMB`, `SYNC_WMB`, `SYNC_MB` |
| SPARC V9 | TSO required, PSO and RMO optional; SC "is not a SPARC-V9 memory model" | manual copyright 1994 | "A machine that implements sequential consistency may deliver lower performance than an equivalent machine that implements a weaker model." And "the weaker memory models offer a performance advantage" | SPARC V9 manual, memory-model chapter and appendix J.2 |
| Alpha | weakest of the major models | handbook 1992; reference manual 4th edition Jan 2002 | a sequence of reads and writes "may be arbitrarily reordered by an implementation"; this "allows implementations to use multibank caches, bypassed write buffers, write merging, pipelined writes" | Alpha Architecture Handbook (1992) and Reference Manual (2002) |
| IBM POWER | weak | Book II version 2.02, Jan 2005 | "The storage model for the ordering of storage accesses is weakly consistent."; it "provides an opportunity for improved performance over a model that has stronger consistency rules" | Power ISA Book II 2.02, section 1.7.1 |
| IBM 370 and z | store may not precede a later load's fetch (TSO in effect) | Principles of Operation, 13th edition, Sept 2019 | no reason; the rule is stated: a store "does not necessarily precede storage-operand fetches specified by conceptually subsequent instructions" | z/Architecture POP, "Relation between Operand Accesses" |
| Intel x86 | TSO ("processor ordered with store-buffer forwarding") | SDM order number 253668-093US | no reason; the rule: "Reads may be reordered with older writes to different locations but not with older writes to the same location." And a warning: "Intel does not guarantee that future processors will support this model." | Intel SDM volume 3A |
| x86 as formalised | x86-TSO | July 2010 | the vendor text was ambiguous; real machines "use sophisticated techniques to achieve high performance: store buffers" | Sewell et al., CACM 2010 |
| Arm | weak, made multicopy atomic in ARMv8 | POPL Jan 2018 | dropped the weaker part because "the potential hardware performance benefits of non-MCA do not justify the ensuing complexity of implementation, validation and reasoning"; the freedom had been wanted "rather than specific microarchitectural designs" | Pulte et al., POPL 2018 |
| RISC-V | RVWMO (weak), optional Ztso (TSO) | specification of 2026 | RVWMO "is designed to provide flexibility for architects to build high-performance scalable designs while simultaneously supporting a tractable programming model"; Ztso exists "to facilitate the porting of code originally written for the x86 or SPARC architectures" | RISC-V manual, RVWMO and Ztso chapters |
| C and C++ | SC only for programs without data races | PLDI 2008 | "we give sequentially consistent semantics to programs that do not contain data races" | Boehm and Adve, PLDI 2008 |

Three things stand out. First, **the reasons written down are speed and "implementation freedom"**; the Arm paper is candid that the freedom was wanted "rather than specific microarchitectural designs", and then gave part of it back. Second, **the weak architectures all allow a stronger core**: SPARC says TSO "or a more strongly ordered model, for example, Sequential Consistency"; HP's CPUs ran fully ordered under an architecture that permitted reordering (from a 2005 magazine article, a secondary source). That is the compatibility mechanism the pdp64's veto needs, and it is old. Third, **HP went the other way in 1995**: the PA-RISC 1.1 manual says strongly ordered; 2.0 added weak ordering as an option.

## 4. TSO: what it is

Two processors, memory starts at zero.

```
processor A:  store X := 1        processor B:  store Y := 1
              load  r0 := Y                     load  r1 := X
```

Under SC, at least one of the loads sees the 1: one of the two stores happened first. Under **TSO**, both loads may return 0. Each processor put its store in its own store buffer and ran the load while the store was still waiting, so each read the old value of the other's variable. TSO allows exactly this and, as SPARC V9 puts it in rules, otherwise "loads are blocking and ordered with respect to earlier loads", "stores are ordered with respect to stores", and "atomic load-stores are ordered with respect to loads and stores". So the single reordering is **store then load** (to different addresses); stores stay in order, loads stay in order.

I ran this test on the host (an AMD Ryzen, which is TSO): without a fence both loads saw 0 in 35,063 of 2,000,000 runs; with a full fence in none. Peterson's and Dekker's mutual exclusion are the textbook programs that break, and they are exactly Lamport's 1979 example.

**Who defined it.** The model is called "Total Store Order" in SPARC (the V9 manual says it "must be provided for compatibility with existing SPARC-V8 programs", and V8 is from about 1990, from memory, not verified); Hill's 1998 article lists "IBM 370, Intel Pentium Pro, and Sun's Total Store Order" as the class that relaxes only the write-to-read order; Sewell and colleagues gave x86 a precise statement in 2010; RISC-V gives it as the Ztso extension. **Which machines:** x86, SPARC (Solaris used it by default), the IBM mainframes in effect, and any RISC-V core that implements Ztso.

What TSO needs from a program: nothing, except where a program relies on store-then-load order (Dekker, Peterson, some lock-free publish-and-check patterns, a sequence-lock reader), where it needs a full fence or an atomic read-modify-write. The Linux kernel's account is that the fix is "a few tens of clock cycles" (Bonzini, LWN, 2021, quoted in the annex entry on sequential consistency; not re-opened here).

## 5. MIPS, and what became of the R10000 method

**What the R10000 did.** The MIPS R10000 manual (version 1.1, section 1.5) describes it: "The R10000 processor behaves as if strong ordering is implemented, although it does not actually execute all memory operations in strict program order." Stores "remain pending until the store instruction is ready to graduate", so they happen in program order; "cached load operations may occur in any order, subject to memory dependencies on pending store instructions"; and "whenever a primary data cache block is invalidated due to an external coherency request, its index is compared with all outstanding load instructions": if a completed load matches, the pipeline is flushed back to that load and it runs again. Yeager's paper adds that forward progress is guaranteed because the oldest instruction always completes. The manual even gives the store-buffering test above as its definition of "strongly ordered".

**Did MIPS abandon it?** I found no document in which MIPS or SGI abandoned it.
* It stayed in the family. The R12000, R14000 and R16000 are the same core with refinements ("The essentials of the MIPS R1x000 series of processors have not changed since the introduction of the first in this family": a secondary source; I could not obtain the R12000 to R16000 manuals).
* The MIPS *architecture* never made SC a rule. `SYNC` is marked as present since MIPS II; the 2001 manual says "The MIPS architecture also permits implementation of MP systems that are not strongly ordered". Release 6 (2016) adds five weaker `SYNC` types (acquire, release, read, write, full) as optional.
* The later MIPS implementations are weak. In the Linux 4.8 kernel's MIPS configuration, `WEAK_ORDERING` is selected by Loongson-3, Broadcom SB1, Cavium Octeon, BMIPS, NetLogic XLR and XLP, and MIPS's coherent multiprocessing system; the R10000 does not select it. So the R10000 stayed the strongly ordered one while newer MIPS designs from other vendors were weak.
* **A stated reason for the later cores being weak: not found.** A reason why the R1x000 line itself ended: not found in any document I could open (from memory, not verified: SGI moved its high-end machines to Itanium).

**HP.** The PA-8000 (1996) is named by Hill and by Gniady et al. among the cores that already use the speculative techniques. Under PA-RISC 2.0 the manual lets software choose.

## 6. Measured costs

Every published figure here is a **simulation** except where I say so. "Gap" is the extra run time of SC against the model named, with SC given the speculation the paper allows unless I say otherwise.

| Source (opened) | Year | Machine and workload | Result | What SC used |
|---|---|---|---|---|
| Ranganathan, Pai, Adve, SPAA | 1997 | 4-issue out-of-order core, window 64; six scientific programs | with a 64-entry history buffer "speculative retirement" brings SC "to within 11%" of PC (TSO class) in all programs; PC still 15% or more faster than SC in 2 of 6, RC more than 15% in 2 of 6 | store prefetch, speculative loads, a history buffer |
| Hill 1998 quoting the above | 1997 | same | PC 0.8 to 23.6% and RC 0.0 to 37.2% faster than SC; averaged 11% and 20% | store prefetch, speculative loads |
| Ranganathan, Gharachorloo, Adve, Barroso, WRL 98/11 | Oct 1998 | 4 nodes, 4-way issue, window 32 to 64; Oracle, transactions and decision support | SC within **10% and 15%** of RC; without the tricks RC beat SC by 28% and 46% | prefetch and speculative loads |
| Gniady, Falsafi, Vijaykumar, ISCA | May 1999 | 8-node shared memory, 300 MHz, 4-issue, window 64; six programs | RC **18% faster on average, 38% at most** than plain SC; SC++ (512-entry history queue and 64-entry table) matches RC | prefetch, speculative loads; SC++ adds stores passing stores |
| Adve, Pai, Ranganathan, Proc. IEEE | March 1999 | the same group's survey | the best SC and RC differ by 24% and 28% (MP3D, Radix); doubling the window gives 16% and 19%; early store prefetches can hurt | |
| InvisiFence, ISCA | June 2009 | SPARC, 4x4 torus of nodes; Apache, Zeus, Oracle, DB2, Barnes, Ocean | **TSO beats SC by 24%** on average, RMO beats TSO by 8%; InvisiFence in SC mode beats conventional SC by 36%, TSO by 9%, RMO by 2% | conventional SC already had in-window speculative loads and store prefetch |
| BulkSC, ISCA | 2007 | 8-core chip, one directory; SPLASH-2, SPECjbb, SPECweb | BulkSC about as fast as RC; traffic 5% to 13% above RC | chunks that commit as units |
| Hechtman and Sorin, ISCA | 2013 | GPU-like throughput processors | "sequential consistency achieves performance comparable to weaker consistency models"; the CPU gap is described as "around 10% to 40%" and narrowed "to 10-15%" by speculation | simple SC |
| **Mine: pdp64 in-order timing model** | Nov 2026 | eight C programs, 21.8 M instructions, one core, store-miss latency 10, 30, 100 cycles | below | no speculation |
| **Mine: x86 host** | Nov 2026 | a store then a load of another word, 100 million times, AMD Ryzen 5 7600 | no fence 0.41 ns; `lock addl` 1.4 ns; `mfence` 12.3 ns; with the store missing the cache 6.5 ns, 12.4 ns, 135 ns | a TSO machine with a fence: a different machine, not the pdp64 |

**How much slower than the alternatives? A number and its range.**
* With the 1991 tricks only: SC is **10% to 38% slower than the most relaxed model on simulated 1997 to 1999 cores**; 10% to 15% on database work, 18% to 24% on scientific work, up to 38% on one sorting program.
* TSO is in between: TSO took 11 of the 20 points of gain on the scientific set and about three quarters of the gain on the 2009 server set. So the step from SC to TSO is about 10% to 24% in these simulations, and from TSO to the most relaxed model is about 8%.
* With the heavy techniques: **2% from the most relaxed model** (InvisiFence, 2009) or "comparable" (BulkSC, SC++).
* The owner's two thresholds are therefore: 40% is above every figure in these sources except the worst single program; 2% has been reached in one simulation with about a kilobyte of extra state.

**Caveats that matter.** The simulated cores are small (windows of 32 to 64 instructions, 4-wide, 1997 to 2009); a modern core has a window of several hundred and a memory latency that is much larger in instruction slots, which pushes the gap up (Hill's warning) and the larger window pushes it down (his other point, and the survey's result). I found no figure from a 2020s core and none for area or power in a modern process. The workloads differ: scientific code has more overlap for a relaxed core to exploit than database code does (Hill says so). Store prefetching can hurt (the 1997 and 1999 papers both say so): a line asked for too early may be taken away again before it is used.

### 6.1 My measurement on the pdp64 in-order model

I added a store-buffer model to `sim64`'s trace-driven timing model (the patch and everything below are in `bench/sc/`). Three memory models: relaxed (stores finish in parallel, loads never wait), TSO (stores finish in order, loads pass them), SC (like TSO, and a load waits until every older store has finished, unless it reads a word a buffered store holds, which is forwarded). Two ways of getting ownership: when the store reaches the head of the buffer (misses add up) or when the store issues (ownership prefetch; misses overlap). The model charges the stall to the instruction stream as an in-order core would suffer it. The eight programs are mine (a quicksort, a hash table, a cold loop copy and clear, a matrix multiply, SHA-256, a small LZ77 compressor, a shuffled linked list, a histogram), because the earlier study's zlib and crypto images were not on this machine. Run time of all eight together, as a percentage longer than the relaxed model; buffer of 8 entries; 16 KB data cache:

| store-miss latency | TSO, no prefetch | TSO, prefetch | SC, no prefetch | SC, prefetch |
|---|---|---|---|---|
| 10 cycles | 0.1% | 0.0% | 1.2% | **0.9%** |
| 30 cycles | 2.8% | 0.0% | 6.5% | **3.7%** |
| 100 cycles | 14.9% | 0.1% | 21.0% | **9.3%** |

Per program, SC with prefetch, at 30 and 100 cycles: copy 26% and 48%; hash 12% and 20%; list 12% and 17%; sort 2% and 6%; lz 0.6% and 2.7%; matmul 0.2% and 1%; sha and hist 0%. A 2-entry buffer raises TSO and SC alike (at 30 cycles: TSO 2.6%, SC 4.5%, with prefetch): the buffer size matters as much as the model. A 64 KB cache changes the figures by up to 4 points. With a crude sharing knob (5% or 20% of lines owned by another core at each store) SC against TSO becomes 5.4% or 11.1% at 30 cycles and 14.1% or 30.1% at 100.

What this shows. **Ownership prefetch is what makes TSO free here** (0.0% to 0.2% against relaxed) **and it takes SC from 21% to 9% at 100 cycles.** The remaining SC cost is the wait of a load behind a store that is still getting ownership. It falls on loops that write cold memory and then read something else, and nowhere else. It is an upper bound for an in-order core without speculation: a core that lets the load go and holds back only the commit of what follows would cost no more than TSO in this single-core model, and then SC's cost is the rate of replays on a real shared workload, which I cannot measure here.

What it does not show. It is one core, so it leaves out the invalidation misses of real sharing except through the crude knob; my programs are not a standard suite; the compiled `memcpy` and `memset` of the pdp64 are block instructions (`mcpy`, `mset`) that the model does not charge to the buffer, so the `copy` program, which uses a C loop, is a worse case than most real copying.

## 7. Does sequential consistency improve safety and correctness?

**Yes for one class, and I can say which; no for the class that dominates.**

**What SC removes: the missing-barrier bug.** The evidence of real ones:
* The Linux kernel's memory-model paper (Alglave, Maranget, McKenney, Parri, Stern, ASPLOS 2018) says its formal model "has already resolved ambiguities and helped fix bugs": fixes to code "incorrectly relying on fully ordered lock-unlock pairs" and to "code where ARM64 needed stronger ordering from combinations of locking and fences".
* A verification tool run by Huawei (VSync, 2021) found "a bug in the MCS lock of the current DPDK version (v20.05)", a missing release barrier that makes a thread hang forever, and in an internal product "a missing acq barrier that causes serious data corruption problems", reproduced on real hardware and introduced "by porting x86 code to ARM". The authors expect "similar bugs are going to become more and more common".
* The x86 case shows the weakest remaining form of the problem even at the strongest common model: the store-buffering test above, with its fence of tens of cycles.
On an SC machine none of these bugs can occur, because there is no order to get wrong; the rule is one sentence.

**What SC does not remove.** The Lu, Park, Seo and Zhou study (ASPLOS 2008, 105 real bugs from MySQL, Apache, Mozilla and OpenOffice) found that "Almost all (97%) of the examined non-deadlock bugs belong to one of the two simple bug patterns: atomicity-violation or order-violation", and that 32% were order violations (the program assumes thread B runs after thread A and nothing enforces it). These are logic errors that happen on an SC machine. The study does not discuss memory models at all, so **I cannot tell what share of concurrency bugs are weak-ordering bugs**; I found no census of that. I looked: the one candidate (a 2026 study of 58 ordering bugs in the Linux kernel and open-source servers) I could not obtain, and I do not cite it. So the honest statement is: SC closes a class that is real, documented in kernels and lock libraries, and of unknown size, and leaves the larger class untouched.

**Verification.** The seL4 microkernel's multicore lock proof (Colvin et al., 2024) is done in two steps: first assuming "lines of code are executed in the order specified (sequential consistency)", then a separate section for the weak-memory effects, with fences. SC removes the second step. I did not verify any claim about the state of the multicore seL4 proof beyond that paper.

**The vocabulary other ISAs carry, which pdp64 does not.** Counted from the documents I opened (the Arm count is from the A64 instruction pages mirrored on this machine; "spellings" are separate assembler mnemonics):

| ISA | ordering instructions and bits, as the documents list them |
|---|---|
| x86 | 3 memory-ordering instructions (MFENCE, LFENCE, SFENCE), the LOCK prefix and the implicitly locked XCHG, 4 unprivileged and 12 privileged serializing instructions (SDM 3A) |
| Arm A64 | DMB, DSB, ISB, SB (and CSDB, ESB, TSB, GCSB, DGH); 32 acquire/release or exclusive-pair load and store spellings; 140 atomic-instruction spellings with acquire, release or both; the barrier option fields |
| RISC-V | FENCE (with predecessor and successor sets), FENCE.TSO; `aq` and `rl` bits on every atomic instruction; the Zalasr extension's load-acquire and store-release instructions |
| POWER (v2.02) | sync (with lwsync and ptesync as forms), eieio, isync |
| Alpha | MB, WMB (and TRAPB, EXCB for exceptions) |
| SPARC V9 | MEMBAR with 7 mask bits (#LoadLoad, #StoreLoad, #LoadStore, #StoreStore, #Lookaside, #MemIssue, #Sync), the deprecated STBAR |
| IBM z | BCR 15,0 and (fast form) BCR 14,0; serialization is also built into compare-and-swap, test-and-set, STORE CLOCK, SUPERVISOR CALL and every I/O instruction |
| MIPS | SYNC, with 7 stype codes in Release 6 (0, 4, 0x10 to 0x14) |
| PA-RISC 2.0 | SYNC, SYNCDMA, the `,O` completer, the PSW O bit and the translation O and U bits |
| **pdp64** | **`FENCE`, for device accesses only; the atomics are `LL`, `SC` and their 24 words and carry no ordering bits** |

That is the "reduces our instruction set size" the owner asked about: from 2 to about 180 ordering spellings in the other ISAs to one, and the memory-ordering parts of the compiler's and the kernel's vocabulary go with it. A C++ `seq_cst` atomic store is an ordinary store on SC hardware (from memory, not verified here: it needs a locked instruction or fence on x86 and a special store or fence on Arm).

**One thing SC does not give the compiler.** The compiler is not slowed by SC hardware: C and C++ already promise SC only to programs without data races, so the compiler may keep reordering ordinary accesses; the Adve and Gharachorloo tutorial lists "code motion, register allocation, and common sub-expression elimination" as what a *language* with SC semantics would forbid, and C++ chose not to. What hardware SC does is let a plain store do the work of an atomic.

## 8. The hardware techniques, their published results, and gates and power

### 8.1 The techniques

| Technique | Published result | What it costs in hardware | Source |
|---|---|---|---|
| Plain SC: finish each access before the next | the baseline; "prohibitively slow" with long remote latency | none | Gniady 1999 |
| **Store buffer drained only where needed**: a load passes buffered stores only if their lines are owned, otherwise waits | no published number for an in-order core; mine: 4% to 9% at 30 and 100 cycles with prefetch | a stall term (3 gates) | my model |
| **Ownership prefetch** when the store's address is known | in the 1998 database study, "some benefits" alone; mine: takes SC from 21% to 9% at 100 cycles | a table of lines asked for (2.8 k gates for 4 entries) | Gharachorloo, Gupta, Hennessy 1991; WRL 98/11 |
| **Speculative loads with snoop replay** (the R10000 method) | SC time cut 26% (transactions) and 37% (decision support): within 10% and 15% of RC; 18% average gap left on scientific work | a load queue searched on each invalidation (18 to 36 k gates for 32 to 64 entries), the pipeline able to restart at a load | Yeager 1996; WRL 98/11; Gniady 1999 |
| **Speculative retirement with a history buffer** | SC within 11% of PC in all six programs | a 64-entry history buffer | Ranganathan, Pai, Adve 1997 |
| **SC++** (stores also pass stores) | matches RC in all six programs with a 512-entry history queue | large associative structures coupled to the reorder buffer and register files: the BulkSC authors' criticism | Gniady 1999; BulkSC 2007 |
| **InvisiFence** (post-retirement speculation tracked per cache block) | SC mode within 2% of RMO; 9% faster than conventional TSO | "approximately one kilobyte of additional state"; 33 to 65 k gates by my count | Blundell, Martin, Wenisch 2009; my model |
| **BulkSC** (chunks that commit atomically) | about as fast as RC | address signatures and a commit arbiter | Ceze et al. 2007 |

A point I found in Cain and Lipasti (ISCA 2004) that favours SC: "Snooping load queues in sequentially consistent systems are simpler in this respect": a load in an SC machine need not search the load queue when it issues, which a weak machine's queue must do (to keep two loads of the same address in order). A TSO machine also needs the snooping queue, because TSO orders load against load.

### 8.2 Gates (my count, by the repository's method)

I modelled each structure in Verilog (`bench/sc/gates/sc_blocks.v`) and counted NAND2 equivalents with yosys the way `tools/gates` does (a flip-flop counts as 6). The baseline is the repository's scalar in-order core: 219 thousand to 308 thousand equivalents (middle 263 thousand), no caches, no branch predictor.

| Structure | NAND2 equivalents | share of the in-order core (263 k) | needed by |
|---|---|---|---|
| store buffer, 8 entries, with forwarding compare | 12.3 k (4 entries 6.5 k; 16 entries 26.2 k) | 4.7% | TSO and SC alike |
| SC's stall term | **3** | 0.001% | SC |
| ownership prefetch table, 4 entries | 2.8 k (8 entries 5.7 k) | 1.1% | TSO (to avoid full-buffer stalls) and SC |
| load queue with snoop compare, 32 / 64 / 128 entries | 17.8 k / 36.2 k / 73.5 k | 6.8% / 13.7% / 28% | out-of-order, TSO and SC alike |
| post-retirement speculation, model (checkpoint, 2 bits per line of a 512-line cache, flash clear) | 32.7 k | 12% | InvisiFence-class SC |
| the same with the paper's "about one kilobyte" of flops | about 63 k | 24% | |

So the in-order SC increment over TSO is three gates. On an out-of-order core SC adds no new structure over TSO; what changes is that load-queue entries must live until older stores are performed, so the queue is bigger for the same window (I did not size that). The heavy technique costs a further 12% to 24% of an in-order core, which is a small share of an out-of-order core.

### 8.3 Power (an estimate, with its assumptions)

Model: dynamic power = gates x activity x capacitance x V squared x frequency. **Assumed, not measured:** 1 femtofarad per NAND2 equivalent including wires, 0.9 volt, 1 GHz, an activity of 0.15 for the baseline logic, 0.025 for a CAM compare at 0.05 invalidations per cycle, 0.02 for clock-gated state (`bench/sc/gates/power.py`). The baseline in-order core comes to 32 mW of logic (no caches, which dominate real chips).

| Structure | model power | share of baseline logic | published cross-check |
|---|---|---|---|
| SC's stall term | 0 | 0% | |
| ownership prefetch table (4 entries) | 0.11 mW | 0.4% | |
| store buffer 8 entries (TSO and SC) | 1.1 mW | 3.4% | |
| load queue snoop CAM, 32 entries | 0.32 mW | 1.0% | CACTI 3.2, 0.09 micron: 0.05 nJ a search, 2.5 mW at 0.05 searches a cycle and 1 GHz |
| load queue snoop CAM, 64 entries | 0.59 mW | 1.8% | 0.12 nJ a search, 6.0 mW |
| load queue snoop CAM, 128 entries | 1.13 mW | 3.5% | 0.22 nJ a search, 11.0 mW |
| post-retirement speculation, model / with 1 KB | 0.64 / 1.14 mW | 2.0% / 3.6% | |

The published figures are those of Cain and Lipasti's Table 2 (CACTI 3.2, 0.09 micron, two read and two write ports); multiplied by my assumed search rate and clock they are 8 to 10 times my gate model for the CAM, because a real CAM's match lines are large and a gate count does not see them. The CACTI numbers are at an old process: a newer one scales them down by an amount I cannot cite. **My honest range for the 64-entry snoop queue is 0.6 to 6 mW, which is 2% to 19% of the in-order core's logic power**, and every one of these figures is good to a factor of three. Replays (loads run twice after an invalidation) burn energy that is not counted; Gniady et al. say "well-behaved applications incur infrequent rollbacks", which I did not test.

**Answer to "how much more power do the gates draw":** on the in-order core, SC over TSO: nothing measurable (the prefetch table, which TSO wants too, is 0.4%). On an out-of-order core: the snooped load queue (which TSO needs as well) is the main item, 1% to 19% of an in-order core's logic power depending on the CAM model; the heavy technique adds 2% to 4% more. The extra gates are small beside the caches and the register file.

## 9. The owner's hunch: fewer instructions beats fewer fetches

My data bears on one narrow part of it. Across the eight programs (3.2 bytes an instruction), cutting instruction fetch from 16 bytes a cycle to 4 lengthens the run time by 0.9% on a 1-issue in-order core and by 4.2% on a 2-issue core; fetch starvation is zero at 8 bytes a cycle for every program; the cycles per instruction (1.86 on average for 1-issue) come from loads, cache misses and mispredicted branches. So on a narrow in-order core the run time follows the instruction count and the stalls, not the bytes fetched, which agrees with the hunch for that class of core. As to "so less speculation is needed": the SC cost with no speculation at all was 3.7% at a 30-cycle store miss, which does agree that a first in-order core does not need speculation to keep SC cheap. I do not claim more: the model is a toy, the programs are mine, and it says nothing about wide out-of-order cores.

## 10. What I recommend, against the owner's thresholds

The owner's rule: up to 40% loss is acceptable for the safety gain; within 2% is cause for joy; TSO is an accepted fallback.

| Tier | What | Cost to speed (evidence) | Gates and power | Verdict |
|---|---|---|---|---|
| **A. SC, no speculation, in-order core** | store buffer, ownership prefetch, loads wait for older stores | mine: 0.9%, 3.7%, 9.3% at 10, 30, 100 cycles; worst loops 12% to 48%; up to about 14% to 30% with 5% to 20% shared stores in my crude knob | +3 gates over TSO; +0.4% of core power for the prefetch table | **the right first implementation**; inside 40% everywhere I measured; inside 10% on average |
| **B. SC with the R10000 method, out-of-order** | speculative loads with snoop replay, stores at graduation, ownership prefetch | published: 10% to 25% behind the most relaxed models, 24% behind TSO in the 2009 simulation | a 32 to 64-entry snoop queue, 7% to 14% of the in-order core, shared with TSO | the **right second step**; inside 40%; not within 2% |
| **C. SC with a heavy technique** | post-retirement speculation (InvisiFence), or chunks (BulkSC) | published: within 2% of RMO in simulation (2009) | 12% to 24% of an in-order core in gates, 2% to 4% in power | the **only tier that reaches the owner's 2%**, on evidence from one simulation; build it only if a measurement of tier B says the gap matters |
| **Fallback: TSO as the architecture** | the one reordering allowed: store then load | published: TSO is about 8% slower than RMO and 24% faster than conventional SC in 2009; mine: TSO with prefetch 0.0% to 0.2% against relaxed | the same store buffer; saves the stall term | accepted by the owner; on my numbers it would save up to 9% of run time at a 100-cycle store miss and lose the whole-class safety; **not worth it on current evidence** |

**My recommendation.**
1. **Keep sequential consistency as the architecture.** The speed cost is bounded and measured (tier A) and inside the owner's 40%; the safety gain is a documented class of bugs; the ordering vocabulary falls from tens or hundreds of spellings to one.
2. **First implementation: tier A.** It needs no speculation. Build it with ownership prefetch from the start, because without it the cost at a 100-cycle store miss doubles (21% against 9%).
3. **Later out-of-order cores: tier B first, tier C only on a measurement.** The compatibility veto holds in both: an out-of-order core that is faster by being weaker must still show SC to software, which is exactly what the R10000 did.
4. **The margin I propose, for the owner to correct:** SC is kept while the measured run time of the same core run as TSO is no more than 10% faster on an in-order core and no more than 5% faster on an out-of-order core (the in-order figure is a third of the owner's 40%; the other, a little above the 2% he would celebrate, is where the best published scheme ends up). If a pdp64 core cannot stay within 40% of the most relaxed model on the benchmark set, or within these margins of TSO, **change the architectural model to TSO, not to anything weaker**: SPARC V9 and RISC-V's Ztso show how one binary runs on every implementation when the architecture states the weaker model and cores may be stronger. Do it before software depends on SC, and on a measurement, not on this report alone.
5. **Devices and DMA.** SC is a promise about the cores' cacheable memory. The Alpha manual does not promise it to devices ("The order of accesses by those agents is not completely specified in this document", with a few guarantees that hold everywhere); the pdp64 should do the same: `FENCE` for devices, coherent table walks for the IOMMU, and stated completion rules. Every interconnect must make a store visible to all other cores at one moment (the property Arm adopted in 2018 and POWER lacks).

**What measurement decides it next.**
1. Extend the timing model with the coherence traffic that is missing (a two-core trace with ownership transfers) and replace the `sup` knob with a measured sharing rate; the model of `bench/sc/` is the start.
2. Run the same eight programs, plus the earlier study's zlib, crypto and sort images when they are rebuilt, under tier A and the TSO fallback at the real store-miss latency of the first implementation.
3. Run the standard litmus suites (`litmus7`, `herd7`) on two cores of the first implementation before any lock-based software is trusted.
4. For tier B and C, a many-core simulator with a protocol: none exists in the repository; the papers used RSIM, SESC and Flexus.

## 11. What I could not verify, or did not do

* **Lamport 1979:** read in full (as images); the year the note was written (1977) is from its own "manuscript received" line.
* **Not found:** a documented reason why the later MIPS cores are weakly ordered, and why the R10000 line ended; a reason, in the PA-RISC 2.0 manual, for adding weak ordering; a census of weak-ordering bugs as a share of concurrency bugs. A 2026 study of 58 ordering bugs exists (found by search); I could not obtain the file.
* **From memory, not verified:** the year of SPARC V8's TSO (about 1990); the year `SYNC` appeared (MIPS II, about 1989 to 1990; the manual marks it "MIPS32 (MIPS II)" but gives no year); that SGI's Origin line left MIPS for Itanium; that a C++ `seq_cst` store needs a locked instruction on x86 and a special store or fence on Arm.
* **Secondary sources, flagged as such:** the R12000 to R16000 being the same core (a computer-architecture notes page); PA-RISC CPUs running fully ordered (McKenney, Linux Journal, 2005). I could not open the R10000 manual version 2.0 or the HP/SGI documents on those later chips.
* **POWER:** I read Book II of version 2.02 (2005); I could not download version 3.0 or 3.1, so I do not say what newer versions add (the `sync` variants of 3.1 I only know from a mailing-list patch, which I did not open).
* **Counts of the Arm ordering spellings** come from a mirror of Arm's A64 instruction pages whose author says it closes on 4 December 2026; the RISC-V count of A-extension instructions is not given because the instruction table was not in the text I could read.
* **Nothing from a modern core:** every published SC-versus-relaxed gap is from a simulation of 1997 to 2009 with small windows; I found no measurement on a 2020s core and no published area or power figure in a modern process for SC against TSO. My x86 numbers are one AMD Zen 4 core, one thread pinned, and show only the shape of the cost.
* **My own bench** is one core, eight programs of my own, a store-miss latency that is a parameter, and a stall rule that is an upper bound; it has no coherence traffic except a crude knob; qemu-pdp64 gives no timing and was not used. The power numbers are an estimate under stated constants, good to a factor of three.
* **Whether any vendor shipped post-retirement speculation for SC:** I did not find one; I did not search each vendor.
