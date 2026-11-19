# Audit of the sensitive instructions (decision 6.14.2)

*For the owner to review. Nothing in this document changes the manual, the grammar, the tools or any test. Facts are marked with where they were found; what was run is marked "run"; what is general knowledge, or what the code does not make clear, is marked "unverified".*

## 1. The criterion

Decision 6.14.2 says: every instruction that reveals or changes the real state of the machine either traps to the hypervisor when a guest runs it, or is harmless. This audit uses the vocabulary of Popek and Goldberg (1974, unverified: general knowledge). A **sensitive** instruction is one whose result depends on, or whose effect changes, state that belongs to the real machine and not to the program that runs it: the **real state** is the interrupt mask, the translation buffer, the caches, the timers, the core number, the control registers of the memory-management unit (MMU) and anything else that the hypervisor must own so that several guests can share one machine. Sensitive instructions come in two kinds. A **control-sensitive** one changes real state (a broadcast TLB invalidate, `HALT`). A **behaviour-sensitive** or **location-sensitive** one gives a result that differs between a real machine and a guest, because it reads real state (the core number, the mode). A **privileged** instruction is one that faults outside kernel mode. Popek and Goldberg's theorem: a machine can be virtualised by trap and emulate if every sensitive instruction is privileged, so that a guest running in a lesser mode always traps. The pdp64's owner chose a different arrangement (6.14.1 to 6.14.3): the guest kernel runs at kernel level, inside a hypervisor mode, so "privileged" no longer separates the guest from the host. The test for each item is therefore two questions: (a) if a guest kernel executes it (kernel level, privilege check passes), does it touch real state, so that hardware must either send it to the hypervisor (**trap and emulate**) or give each guest its own copy (**virtualize in hardware**)? and (b) if a guest's user program or a guest kernel executes it **without** any privilege check, can it read or depend on real state without a trap? An instruction that does neither is **harmless**.

Terms used below. **Guest-local** state is state that the hypervisor swaps at a world switch (the change from one guest to another), so that the guest sees only its own copy; an instruction that touches only guest-local state is harmless, provided the world switch really swaps it. **Stage 2** is the second table walk of 6.14.4 (guest-physical to physical). **Exit** is a guest stopping because the hypervisor must act (the exit-reason register of 6.14.3).

## 2. How the evidence was gathered

* **Code reading.** The reference executor `common/pdp64exec.c` (shared by sim64 and the QEMU target: the QEMU tree carries a generated copy in `qemu/target-pdp64/gen/pdp64exec.c`), `common/pdp64exec_enc.inc`, `common/pdp64exec_vec.inc`, and the grammar parts `spec/grammars.d/30-mn-core.hbnf`, `40-mn-system.hbnf`, `41-sysreg.hbnf`, `50-system-v1.hbnf`.
* **Running.** `build/sim64 -K` starts in kernel mode and delivers exceptions through the vector table. A small harness (section 9, listing 1) installs a vector table in which every vector goes to one handler, drops to a chosen mode with `RTI`, executes one instruction, and ends with an exit status: 255 means "executed with no exception", any other number is the vector number (3 is the privileged-instruction vector, 2 illegal instruction, 15 breakpoint, 1 for `trap #1` which enters vector 257, taken modulo 256). Every probe was run twice, with `EPSW` set to user mode and to kernel mode (the second run is the control: it shows the instruction is not simply broken). The harness was also run once under QEMU (`qemu-system-pdp64 -M pdp64-virt,kernel-mode=on`) for `tlbia`, `mfsr`, `mfcpuid`, `mfps` and `hint`: the answers were the same as sim64's. Because both use the same executor source, QEMU adds little independent evidence.
* **Not run.** There is no hypervisor mode, no second stage, no guest tag, so nothing about the guest case can be run: the "what a hypervisor would have to do" column is a design reading, not a measurement. sim64 has no MMU and QEMU's `cpuid` is never set to another value for a second core in the code that was read (unverified for a multi-core run).

Result of the runs (user mode / kernel mode; 255 = no exception):

| probe | user | kernel |
|---|---|---|
| `nop fence sev lpad icinva hint #0 #1 #2 #5` | 255 | 255 |
| `bpt` | 15 | 15 |
| `trap #1`, `trapl #3` | vector 257, 259 (mod 256: 1, 3) | same |
| `trapcc.eq` (Z clear), `addv r2,r2` | 255 | 255 |
| `halt wfe wait tlbia tlbsync isync pushx popx rti rtt` | 3 | ran (`halt` 255; `wfe`, `rti`, `rtt` never came back: they slept or jumped, as they should) |
| `mfsr` of each of the 13 registers, `mtsr` of each of the 10 writable ones | 3 | 255 |
| `mtsr eva`, `mtsr ecause`, `mtsr cpuid` | refused by the assembler ("read only") | not run |
| `mtdmw tlbi mtasid mfasid prober probew` | 3 | 255 |
| `spl #3` | 3 | priority becomes 3 |
| `mfps` | 255; shows mode field 3 (user) | mode field 0 |
| `mtps` (value 0x2f: flags and a priority bit) | 255; only the four flags kept (read back 15) | all of 0x2f kept (47) |
| `mtps` of a value with mode 0 | 255; mode stays 3 | mode becomes 0 |
| `mtdp r2`, `mfdp` | 255, the value is kept | same |
| `mfcpuid` | **255, returns the core number (0 here)** | same |
| `icinv r1` | 255 | 255 |
| `movq.u (r1),r3`, `movq.u r2,(r1)`, `movub (r1),r3` | 255 | 255 |
| a `vec` block with `vld`; `vclr` outside a block; `fsflags` | 255 | 255 |

## 3. The table

Class: **P** = privileged (faults outside kernel mode), **S** = sensitive and unprivileged, **H** = harmless. "Hypervisor action" is one of **trap** (trap and emulate: the guest's execution exits to the hypervisor), **hw** (virtualize in hardware: the machine keeps a per-guest copy or scopes the effect to the guest), **swap** (guest-local state that the hypervisor saves and restores at a world switch, no trap needed), or **none**. Executor line numbers are in `common/pdp64exec.c`; `priv()` is defined at lines 339 to 342 and raises vector 3 (`VECTOR_PRIVILEGED`) when the mode is not kernel.

### 3.1 System instructions

| instruction | class | evidence | what a hypervisor would have to do |
|---|---|---|---|
| `NOP`, `LPAD`, `FENCE` | H | no check, executor line 540; run 255 | none. `FENCE` orders memory only. |
| `SEV` | S (minor) | no check, line 540; run 255. On one core it does nothing; on a machine it wakes `WFE` on other cores (manual 7.10.1) | A guest's `SEV` could wake a core that belongs to another guest or to the hypervisor. A wake-up that finds nothing to do is allowed if software always re-tests after `WFE` (7.10.2's idle loop does; unverified that the manual states it for every use). Treat as harmless if the event is scoped to the guest's own cores, else a covert channel (unverified how much). Decision 6. |
| `HINT #0..#255` | H | `pdp64exec.c:493`, before `priv()`; run 255 for 0, 1, 2, 5 | none. `HINT #1` (pause) is the natural "spin-loop exit" event of section 5. |
| `BPT` | H (a trap into the guest's own kernel) | line 481 to 483 enters vector 15; run 15 | none, but a debugger needs it routable (section 5). |
| `TRAP #n`, `TRAPL #n` | H | lines 553 to 558, no check; run: vectors 257 and 259 | none: the guest's own system call goes to the guest kernel (6.14.3). **There is no instruction by which a guest asks the hypervisor for a service** (a hypercall); decision 5. |
| `TRAPCC.cc`, `ADDV/SUBV/MULV` overflow | H | `common/pdp64exec_enc.inc` lines 327 to 335 (vector 16, "check"); run 255 when not taken | none: guest-local exceptions. |
| `RET` | H | line 479, no check | none. |
| `RTI`, `RTT` | P | `priv()` at line 485; run user 3. They load the real PSW from `EPSW` | swap: `EPC`/`EPSW` are guest-local while a guest runs. The mode and priority fields they load must be the guest's (section 3.3). |
| `HALT` | P | line 480: `if (!C->standin) priv();` then `E->halt()`. In a plain `sim64` run (no `-K`) the stand-in makes `HALT` legal in every mode: that is a test convenience, not the architecture. Run with `-K`: user 3 | **trap, always.** A real `HALT` stops the whole machine (in the executor, `E->halt` stops the host program). A guest that halts must be a guest that stops. |
| `WFE` (`WAIT` is the assembler alias, `40-mn-system.hbnf:10, 16`) | P | `priv()` line 509, sets `C->wait`; run user 3, kernel: sleeps | **trap** (default) so that an idle guest gives the core back; a hypervisor that does not trap it lets a guest sleep the real core. 7.10.2 makes `WFE` wake on a pending interrupt even if masked: with virtual interrupts the wake rule must name virtual ones too. |
| `SPL #n` | P | line 552; run user 3, kernel priority 3 | The priority is the real interrupt mask (the machine takes an interrupt when its level exceeds the PSW priority, `pdp64_interrupt`, line 780). **hw**: the guest's priority masks only virtual interrupts; real interrupts go to the hypervisor whatever the guest's priority (decision 1). Trapping `SPL` would cost a trap for every critical section in the guest kernel. |
| `TLBI rN`, `TLBIA` | P | lines 566 and 510; run user 3 | These are **broadcast to every core** (6.8.3). **hw** with the guest tag of 6.14.4 (invalidates only entries of the guest's tag, on the cores that run the guest); **trap** until the tag exists. Without scoping a guest can flush every other guest's translations: not a leak but a performance and timing attack (unverified how bad). |
| `TLBSYNC` | P | line 511 (does nothing on one core); run user 3 | Waits for every core's invalidate to finish. harmless if scoped; a guest could be made to wait on another guest's slow core (timing). **hw**: completion of the guest's own broadcasts. |
| `MTASID`, `MFASID` | P | lines 567 and 568; run user 3. `MTASID` also flushes everything in the executor (stricter than the rule of 6.8.4) | **hw**: the guest tag keeps one guest's address-space numbers from meeting another's (6.14.4); swap the value. |
| `MTDMW` | P | line 569, stores in `DMW0` only ("v1: storage only"); run user 3 | Today harmless (stored, no effect). When a direct-mapping window takes effect it maps real physical memory around the page tables: **trap** or force it through stage 2. Decision 8. |
| `MFCPUID Rd` | **S** | **no `priv()`**, line 561; run: user 255 (returns the core number) | Returns the real core number to any program. A guest's virtual core number differs and changes when the hypervisor moves the guest. **hw**: return a per-guest value that the hypervisor sets; or make the instruction privileged. Decision 2. The manual never lists it as privileged or unprivileged (6.2.5, 6.2.6 omit it). |
| `ICINV rN`, `ICINVA` | S (minor) | line 570 and line 540, no check; run 255. Manual 7.9.2: deliberately unprivileged (a JIT needs them) | Cache maintenance is by address: only the guest's own cache lines matter for correctness. An invalidate-all by a guest costs other guests time (a timing channel, a denial of service) but changes no one's data: harmless for correctness. **none** (or **hw** to scope `ICINVA`). A guest's addresses go through both stages. |
| `ISYNC` | P | `pdp64exec.c:494` (`priv()` after the `HINT` test), lines 495 to 499; run user 3 | Orders the core's own earlier writes. harmless for a guest: **none**. (Oddity found: `ICINV` takes effect only after an `ISYNC`, 7.9.3, and `ISYNC` is privileged, so a user JIT cannot synchronise: an inconsistency in the manual, not a virtualization point; unverified whether it is intended.) |
| `PUSHX`, `POPX` | P | line 494 to 508; run user 3 | They move `EPC` and `EPSW` to and from the kernel stack; guest-local: **swap**. A stage-2 fault on the stack access is an exit. |
| `PROBER`, `PROBEW` | P | line 562 to 565; run user 3. It asks the translation unit (`E->probe`) with the previous mode | **hw**: must test both stages. If stage 2 has no entry the guest cannot be told "no" (a valid buffer would give a false `EFAULT`): the right behaviour is an exit so the hypervisor can fill stage 2 and run the probe again. Decision 11. |
| `MTPS` | **S** | line 544 to 550, no check: in user mode it silently writes only the flags; in kernel mode every writable bit; run as in section 2 | In a guest at kernel level it writes the guest's PSW: harmless except the priority field (see `SPL`) and the mode fields (section 3.3). The silent drop of the other bits in user mode is the classic Popek-and-Goldberg failure (an instruction that behaves differently outside privileged mode instead of trapping), but it only matters for the case "guest kernel in user mode", which the design avoids. |
| `MFPS` | **S** | line 551, no check; run: user sees mode field 3 | Reads the whole PSW, including current mode, previous mode, priority. harmless **only if** the guest's PSW holds the guest's values and the hypervisor mode is never visible in it (decision 3). |
| `MTDP`, `MFDP` | H | lines 559 and 560, no check; run: value kept | The direct-page register (a base register) has one copy per mode (6.2.4): guest-local, **swap**. |
| `MFSR Rd, name` / `MTSR name, Rs` | P | lines 512 to 539, `priv()` at 514; run: all 13 names user 3, kernel 255 | Depends on the register: section 3.2. Any number not assigned (13 to 255): `die("illegal instruction")` at line 531 (read, not run). |

### 3.2 System registers (the 13 numbers of `41-sysreg.hbnf`)

Every register is reached only by `MFSR` and `MTSR`, which are privileged (run), so **no system register is readable from user mode**. For a guest kernel the question is whether the access is to the guest's copy.

| register | class | evidence | hypervisor action |
|---|---|---|---|
| 0 `PTBR` | P | executor lines 515 and 534; write flushes the translation buffer | **swap**; holds a guest-physical address, so the table walk of stage 1 goes through stage 2 (6.14.4). A write that changes it is 6.8.4(b) for the guest tag. |
| 1 `EPC`, 2 `EVA`, 3 `ECAUSE`, 8 `EPSW` | P | lines 516 to 518, 524; `EVA`, `ECAUSE` read-only (`41-sysreg.hbnf:20`) | **swap**: the hardware writes them on every exception (`enter`, lines 345 to 357). The hypervisor needs its own separate set for the exceptions that exit the guest, or a guest exception inside a handler of the hypervisor would overwrite them (decision 10). |
| 4 `DMW0`, 5 `DMW1` | P | lines 519, 520 (stored, no effect) | as `MTDMW` above. |
| 6 `USP`, 7 `SSP` | P | lines 522, 523 | **swap**. |
| 9 `VBR` | P | line 525; entry reads `VBR + 8 * vector` as a **physical** address with no translation (`enter`, line 347, 6.3.3) | **swap**, but the vector fetch of a guest must go through stage 2, or a guest can point `VBR` anywhere in real memory and have the contents loaded into its program counter. Decision 9. |
| 10 `MMUCTL` | P | line 526; bit 0 enable; a change of bit 0 flushes | **swap**; the guest turns its own stage 1 on and off; stage 2 stays on (the rule 6.8.5 for the guest tag). |
| 11 `ASID` | P | line 527 | **hw** (guest tag) and **swap**. |
| 12 `CPUID` | P | line 528; read-only | Real core number: **hw** per-guest value (same as `MFCPUID`, decision 2). |
| 13 to 255 | (none assigned) | line 531, `die` | A guest's access to a number that is a hypervisor control must exit (6.14.7, no nesting); to an unassigned number, decision 12. |

### 3.3 The status word (`50-system-v1.hbnf:9 to 24`; executor `pdp64_set_psw`, lines 750 to 762)

| bit or field | class | evidence | hypervisor action |
|---|---|---|---|
| `C V Z N` (bits 0 to 3) | H | user-writable | none. |
| `T` trace (bit 4) | H | `RTT` sets it (line 488); `MTPS` in user mode cannot | none (guest-local); a hypervisor debugger might want to single-step a guest (section 5). |
| `PRI` (bits 5 to 7) | **S** | `SPL`, `MTPS` write it; `pdp64_interrupt` (line 780) compares with it | See `SPL`. **hw** (virtual priority). |
| `MODE` (8 and 9), `PREV` (10 and 11) | S | `MFPS` reads them in every mode; value 2 is reserved (`psw_bad`, line 335); `enter` sets them (line 353) | If the hypervisor mode is added as a value of this field (the only free value is 2, which 6.2 says is illegal), a guest's `MFPS` would reveal it. Keep the hypervisor mode **outside** the readable PSW (decision 3). |
| bit 12 `UA` (user-access guard, manual 6.2.2, 6.10.1) | not implemented | `PSW_VALID` (`common/pdp64exec.h:10`) has no bit 12; the grammar's `psw` rule has no `ua`; `stua` and `clua` do not assemble (run) although the manual and `docs/pdp64-isa.md:489` list them | Cannot be classified: it does not exist in the grammar or the executor. If it does, it is guest-local: harmless. Decision 12. |
| `DIT` (data-independent timing, an ARM bit, unverified) | does not exist | no such bit in the grammar | nothing to do; named in the request, so recorded. |
| bits 13 to 15 | reserved, read as zero | `50-system-v1.hbnf:18` | none. |

### 3.4 The other instruction groups

| item | class | evidence | hypervisor action |
|---|---|---|---|
| user-qualified moves `MOVQ.U`, `.L`, `.W`, `.B`, `MOVZ?.U` (seven words, 6.10.4) | H today; **unclear** | `common/pdp64exec_enc.inc:32 to 34` give them the table entry of the ordinary move: in the reference executor they are ordinary moves (as `docs/sim64.md` says); run 255. Unprivileged by design. The manual says they access memory "with user privilege" | Harmless for a guest if "user privilege" means "the guest's user privilege" through both stages. No real state is read. Not to be confused with `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ`, which are the **unaligned** moves (`30-mn-core.hbnf:266`). |
| `LL`, `SC`, the atomic family (`CAS`, `SWAP`, `XADD`...) | not implemented | `common/pdp64exec_enc.inc:98` (all `H_UNIMPL`) | Unaudited. Rule needed: an `LL` reservation must not survive a world switch (unverified that the manual says so). |
| floating point, `FSFLAGS` | H | state `fpsr` is per core; `FSFLAGS` run 255 | **swap** `fpsr`. |
| vector unit (`vec ... vend`, `vclr`, `v0..v15`) | H; one open point | no privilege check anywhere in `pdp64exec_vec.inc` (read); `v0..v15` are hidden and not saved at a context switch (`vec-isa.md` section 1); run: a block run in the kernel left `0x55` in `v3`, and a user block that stored `v3` without loading it stored zero (listing 2: the executor zeroes non-accumulator registers at the start of each strip, `pdp64exec_vec.inc:8`); `vclr` outside a block runs in user mode and sets `C->vacc`, the naming of the accumulators, which stays until the next block (the hole of errata 175) | No real machine state is read, **but** hidden state can cross a world switch: 6.14.9 already says the proof is owed. This audit supplies the observation that registers do not leak data in the executor and that the naming (`C->vacc`) does persist. Decision 13. There is no "vector unit enabled" bit, so a hypervisor cannot trap first use (no lazy switching); not needed while the state is hidden. |
| `PUSHM/POPM`, `MCPY/MMOV/MSET/MCMP/MSCN`, loads, stores, arithmetic, branches, the `CT/CHK2` checks | H | no system state; faults are guest-local exceptions | none. Stage-2 faults on their memory accesses are exits. |
| the `TIMER` and `CONSOLE` devices | not instructions | physical addresses in device space, `50-system-v1.hbnf:91 to 99` | Reached only by a load or store to a mapped page. A guest reaches them through stage 2 (6.14.4) or a virtual timer (6.14.5). **No instruction reads a clock or a cycle counter**; a program can time itself only with a loop. |

## 4. Does the pdp64 satisfy Popek and Goldberg as it stands?

**No, not as written, though the gaps are few and small.** "As it stands" has two readings.

*Reading A: the machine as it is today (no hypervisor mode), a guest kernel run in user mode.* The sensitive instructions that do not trap are these:

1. **`MFCPUID`** returns the real core number to any program (location-sensitive: it reads, and changes nothing). This is a real leak, confirmed by running it in user mode. It is the one the owner named in 6.14.2.
2. **`MFPS`** returns the real mode, previous mode and priority to a user program: a guest kernel in user mode would read "user" and learn it is not on the bare machine (behaviour-sensitive).
3. **`MTPS`** in user mode silently writes only the flags and gives no fault, so a guest kernel that sets the priority or the mode through it does nothing and is not told (the classic silent failure).
4. **`SEV`** signals other cores with no check (weak: see decision 6).
5. **`ICINV` / `ICINVA`** act on the real instruction cache with no check (by design; harmless to correctness).

No other instruction in the table is sensitive and unprivileged: in particular **no system register is user-readable**, there is **no user-readable counter or timer instruction**, `HINT` and `FENCE` have no architectural effect, and the vector unit exposes no real state.

*Reading B: with the owner's design (guest kernel at kernel level in a hypervisor mode).* Items 2 and 3 disappear if the hypervisor mode is not readable in the PSW. Item 1 remains and must be fixed. The privileged instructions that touch real state and are **not yet** safe at kernel level are the ones of section 3.1 marked trap or hw: `HALT`, `WFE`, `SPL`/`MTPS` priority, `TLBI`, `TLBIA`, `TLBSYNC`, `MTDMW`, the `CPUID` register, the `VBR` fetch and the `PTBR` walk (both read real physical memory without a second stage), and `PROBER`/`PROBEW`. The machine as written has no way to make any of them trap, so it fails the criterion today by construction; the design of 6.14.3 is exactly what is missing.

Also found, in passing, in the manual and the code: **(i)** the manual (6.2.5, 6.10.1, `docs/pdp64-isa.md:489`) lists `STUA`, `CLUA` and the `UA` bit; the grammar and the executor have none of them. **(ii)** 6.2.5 and 6.2.6 do not mention `MFCPUID` at all; the executor leaves it unprivileged. **(iii)** The same fact (the core number) is privileged through `MFSR CPUID` and unprivileged through `MFCPUID`. **(iv)** Reading an unassigned system register or loading mode 2 stops the executor with `die` (line 531 and line 486) instead of raising a vector (these paths were read, not run: unverified whether `die` becomes the illegal-instruction exception in every build).

## 5. Events the trap-control register must be able to route

One bit each; "default" is the recommendation for a minimal first hypervisor.

| # | event | default | why |
|---|---|---|---|
| 1 | `HALT` | trap, **not maskable** | stopping the machine is not a guest's to do |
| 2 | `WFE` / `WAIT` | trap | idle guest gives the core back |
| 3 | `HINT #1` (pause) | optional | spin-loop exit, to give the core to a guest that holds the lock (unverified: how much this matters) |
| 4 | `SEV` | optional | only if events cross guests |
| 5 | `SPL`, `MTPS` priority change | not trapped (virtual priority in hardware) | frequent; bit only for a hypervisor that has no virtual priority |
| 6 | `TLBI` | trap until the guest tag exists, then hw | |
| 7 | `TLBIA` | same | |
| 8 | `TLBSYNC` | same | |
| 9 | `MTASID`, `MFASID`, `MTSR ASID` | trap until the guest tag exists | |
| 10 | write to `PTBR` | optional (shadow tables / debugging) | |
| 11 | write to `MMUCTL` | optional | |
| 12 | write to `VBR` | optional | |
| 13 | `MTDMW`, `MTSR DMW0/1` | trap | once the windows take effect |
| 14 | `MFCPUID`, `MFSR CPUID` | hw (virtual value) | trap bit as the fallback |
| 15 | `ICINV`, `ICINVA` | not trapped | a bit to catch `ICINVA` if timing matters |
| 16 | `ISYNC` | not trapped | |
| 17 | `PROBER`/`PROBEW` with a stage-2 miss | exit | |
| 18 | `MFSR`/`MTSR` of a hypervisor-control register | exit (always) | 6.14.7, no nesting |
| 19 | `MFSR`/`MTSR` of an unassigned number (13 to 255) | exit or illegal (decision 12) | |
| 20 | `BPT` | optional | debugger |
| 21 | `TRAP #n` for chosen n (a hypercall range) | optional | decision 5 |
| 22 | `RTT` / trace bit set | optional | single step |
| 23 | illegal instruction, privileged-instruction exception | not trapped (guest's own) | the guest kernel handles them |
| 24 | stage-2 page fault, protection fault, vector-fetch fault, machine check | exit (always) | the guest cannot handle these |
| 25 | physical interrupt (timer, console, any device line) | exit (always, whatever the guest priority) | decision 1 |
| 26 | guest reset (`RESET` vector 0) | exit | 6.14.8 |
| 27 | interrupt window (guest lowers its priority while a virtual interrupt is pending) | hw | 6.14.5 |

## 6. What the manual would need to say

1. **A classification, 6.14.2:** replace "an audit is to be made" with the table of section 3 (the part that survives the owner's decisions) and state the rule once: *an instruction is harmless, hw, swap or trap; there is no fifth case*.
2. **6.2.5 and 6.2.6:** add `MFCPUID` to one of the lists, and either implement `STUA` and `CLUA` or remove them from 6.2.5 (decision 12).
3. **6.2.2 and 6.5:** state that the hypervisor mode and the guest tag are not visible in the PSW or in any guest-readable register.
4. **6.14.3:** list the trap-control bits (section 5), the exit reasons, and which system registers are guest-resident and swapped (section 3.2).
5. **6.3.3:** say that when a guest takes an exception, the vector fetch address is a guest-physical address and goes through stage 2, and what happens if stage 2 has no entry.
6. **6.3.7, 6.14.5:** say how real interrupts and the guest's priority relate (decision 1).
7. **7.10:** say what `WFE` and `SEV` mean in a guest.
8. **6.14.9:** the world switch also clears an `LL` reservation and the naming of the vector accumulators (decision 13).
9. **A table of every state register that a world switch must save,** in step with 6.14.8: all 13 system registers, the three banked `R14` and `DP` pairs, `fpsr`, the flags, the pending-event state of `WFE`, the vector accumulator naming, the cached translations tagged to the guest.

## 7. Decisions for the owner, each with a recommendation

1. **Where does a real interrupt go, and what does a guest's priority mask?** *Recommendation:* a physical interrupt always exits to the hypervisor, whatever the guest's `PRI`; the guest's `PRI`, `SPL` and `MTPS` mask only **virtual** interrupts (6.14.5), by hardware (no trap on `SPL`). Without this a guest can raise its priority to 7 and keep the hypervisor's timer tick from ever arriving: a guest owns the core. This is the most important item of the audit.
2. **`MFCPUID`.** *Recommendation:* make it privileged (7.8 uses it once, at start, in the kernel; per-CPU data otherwise comes from `DP`), and give each guest a hypervisor-set virtual core number that `MFCPUID` and `MFSR CPUID` return when a guest runs. Fallback: keep it unprivileged and virtualise the value; the leak then disappears either way. If any user program needs the core number, the kernel can put it in `DP` data.
3. **Where is the hypervisor mode kept?** *Recommendation:* outside the PSW (a separate state bit) and not in the current-mode field; the reserved mode value 2 stays reserved. Then `MFPS`, `MTPS`, `RTI` and `EPSW` need no change and the guest cannot see it.
4. **`HALT`.** *Recommendation:* always exits; no trap-control bit can turn it off.
5. **A hypercall.** There is no instruction for a guest to ask the hypervisor for a service. *Recommendation:* route a range of `TRAP #n` numbers to the hypervisor by a trap-control mask (no new opcode), unless the owner wants a dedicated instruction.
6. **`SEV` and `WFE`.** *Recommendation:* scope `SEV` to the cores of the guest by the hypervisor; `WFE` traps by default and may be untrapped for a guest that owns a core. State in 7.10 that `WFE` may return without any event and software must re-test (the idle loop of 7.10.2 already does).
7. **`ICINV`/`ICINVA`.** *Recommendation:* leave unprivileged and untrapped (harmless to data; a JIT needs them). Add a bit that traps `ICINVA` only if timing between guests is a concern. Separately, resolve the `ICINV`-needs-`ISYNC`-but-`ISYNC`-is-privileged oddity (section 3.1).
8. **`MTDMW`, `DMW0/1`.** *Recommendation:* trap (hypervisor emulates) when a window takes effect; until then they are harmless. Alternatively define a window as a guest-physical range under stage 2; trap is simpler.
9. **The vector fetch and the page-table walk of a guest.** *Recommendation:* both go through stage 2 (a guest-physical `VBR` and `PTBR`); a stage-2 miss on either is an exit, not a machine check, because a guest cannot handle it.
10. **The hypervisor's own exception registers.** *Recommendation:* a separate set (`HEPC`, `HEPSW`, `HEVA`, `HCAUSE`, and a guest-physical fault address), because `enter` overwrites `EPC`, `EPSW`, `EVA`, `ECAUSE` (executor lines 345 to 357) and those four are the guest's while a guest runs.
11. **`PROBER`/`PROBEW` in a guest.** *Recommendation:* they test both stages; a stage-2 miss exits so the probe re-runs after the hypervisor fills it (a false "no" would make the guest report `EFAULT` for a valid buffer).
12. **Unimplemented and inconsistent items.** *Recommendation:* (a) before the hypervisor design, decide whether `UA`, `STUA`, `CLUA` exist (the manual and the grammar disagree); (b) list `MFCPUID` in 6.2.5 or 6.2.6 once decision 2 is made; (c) in a guest, `MFSR`/`MTSR` of a hypervisor-control register exits (6.14.7) and of an unassigned number raises illegal-instruction in the guest (an exit for an unassigned number would let the hypervisor invent registers, which breaks the rule that the architecture owns the numbers).
13. **Hidden state across a world switch (6.14.9).** *Recommendation:* make the rule architectural and mechanical, not a proof obligation: a world switch (and every exception entry) clears the naming of the vector accumulators and any `LL` reservation. This closes errata 175 at the cost of one clear. The runs here show only that registers do not leak data, not that nothing hidden is observable.
14. **Keep the machine free of user-readable clocks.** *Recommendation:* state in 6.14.2 that no unprivileged instruction reads a clock, a counter or the core identity; if one is ever added it must have a trap-control bit.

## 8. What could not be verified

* No guest, hypervisor mode, trap-control register, second stage or guest tag exists, so every "hypervisor action" is a design reading and was not run.
* The QEMU run used the same executor source as sim64 and one core; `MFCPUID` on a multi-core QEMU was not run, and no code assigns a non-zero `cpuid` in the code that was read (unverified).
* `die()` paths (unassigned system register, reserved mode, line 486 and line 531) were read, not run; whether they surface as the illegal-instruction exception in every host is unverified.
* The vector unit was audited by reading the executor for privilege checks (none) and by one run (listing 2); the full state, including the accumulator naming across an exception, was not tested.
* Atomics, the crypto words and `MVAL` are not implemented in the executor and could not be run.
* Everything said about x86, ARM or RISC-V bits and Popek and Goldberg is general knowledge and *unverified*; the hint-pause exit (event 3) and the size of the denial-of-service effects of unscoped `TLBIA`/`ICINVA`/`SEV` are *unverified*.
* The `SEV` text of 7.10 was only skimmed: that software must re-test after `WFE` is stated for the idle loop; whether it is promised for every use is unverified.

## 9. Listings

### Listing 1: the harness (one instruction per run)

Save as a template, replace the line `@@PROBE@@` with the instruction and `@@VTAB@@` with 512 lines `.quad h_gen` (except line 457, number 456, which is `.quad h_end`: `trap #200` ends the run), assemble with `as64 --no-relax`, link with `ld64`, and run `sim64 -K`; the exit status is as in section 2. Change `#0x300` to `#0` to run the probe in kernel mode. The assembler has no `.rept`, so the table is made by a shell loop (`for n in $(seq 0 511)`).

```
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1			; every vector goes to h_gen, except trap #200 (vector 456), which ends the run
	lea	ustack_top, r1
	mtsr	usp, r1
	lea	kstack_top, sp
	lea	user, r1
	mtsr	epc, r1
	movq	#0x300, r1		; EPSW: mode user (3), previous mode kernel, priority 0; #0 runs the probe in kernel mode
	mtsr	epsw, r1
	rti
user:
	lea	buf, r1			; r1 = a valid address, r2 = a value, r3 = 0
	movq	#0x1234, r2
	movq	#0, r3
	movq	#255, r8		; 255 = "no exception"; the handler puts the vector number in r8
	movq	#255, r0
	lea	resume, r4		; the handler resumes here
	@@PROBE@@
resume:
	movq	r8, r0
	trap	#200			; ends: halt in kernel mode, status r0
h_gen:	mfsr	r8, ecause
	mtsr	epc, r4
	rti
h_end:	halt
	.align	8
vtab:
@@VTAB@@
buf:	.space	256
ustack:	.space	256
ustack_top:
kstack:	.space	256
kstack_top:
```

Probes used: `tlbia`, `mfsr r3, ptbr` (and each other register name), `mtsr ptbr, r3`, `mfcpuid r3`, `mfps r8`, `mtps r5`, `spl #3`, `hint #1`, `trap #1`, `icinv r1`, `prober r3, r1`, `movq.u (r1), r3`, `fsflags r6, r7`, and the others of section 2.

### Listing 2: does a vector register leak across a mode change?

The kernel runs a block that loads `v3` from 16 bytes of `0x55`, then `RTI`s to user mode, which runs a block that stores `v3` without writing it; the first stored byte is the exit status. Observed: 0 (no leak in the executor). The control, in which the user block loads `v3` first, gives 85 (0x55), so the test does measure something. Prologue and table as in listing 1; the two blocks:

```
	; kernel:
	lea	src, r1
	lea	16(r1), r4
	vec	r1, r4
	vld.l	v3, (r1)+
	vend
	; user (exit status = the first byte stored):
	lea	buf, r1
	lea	16(r1), r4
	vec	r1, r4
	vst.l	v3, (r1)+
	vend
	lea	buf, r1
	movzb	(r1), r0
```
