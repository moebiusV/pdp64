# DEC PDP-64 — SoC FPGA Implementation Plan

[← pdp64 index](../README.md)

**DEC PDP-64: Digital Equity Collective's Pragmatic Digital Processor, 64 bit.** (11/64W was the working name under which this document was written.)

**Companion to the ISA, [`pdp64-isa.md`](pdp64-isa.md), originally written against revision 20.** Brought up to date with the changes since revision 20 (see "Updates since revision 20" and "Changes since revision 20" at the end; the authority for those changes is [`../CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md)). Kept separate rather than folded in, because the ISA is meant to outlive any particular FPGA and this document is expected to churn. Fold it in if you'd rather have one artifact.

---

## 1. Target selection

The pdp64 has always assumed a SoC FPGA — fabric plus hard ARM cores. That was the right instinct and it matters more than it looks, for a reason that has nothing to do with the finished machine: **the hard cores are the bring-up harness.** See §6.

Verify current availability and pricing before ordering; the Cyclone V generation in particular is old enough that supply is uneven.

| Board | Device | Fabric | Hard CPU | Notes |
|---|---|---|---|---|
| **Terasic DE10-Nano** | Cyclone V SE 5CSEBA6 | ~110K LE (~41K ALM) | dual Cortex-A9 | 1 GB DDR3 on HPS, HDMI via ADV7513, MiSTer ecosystem |
| Digilent Zybo Z7-20 | Zynq 7020 | 53K LUT, 220 DSP | dual Cortex-A9 | HDMI in *and* out, good Vivado support |
| AMD Kria KV260 | Zynq UltraScale+ ZU5EV | ~117K LUT | quad A53 | much faster fabric, DisplayPort not HDMI |
| ULX3S | Lattice ECP5-85F | 84K LUT | none | fully open toolchain, no hard CPU — loses §6 entirely |

**Start on the DE10-Nano.** Not because it is the best part — it is the slowest of the four — but because the MiSTer ecosystem has already solved the problems that are not your problems: HDMI output and scaling, USB input, SD card, SDRAM daughterboard, and a body of working C64 core work that the VIC-64X and SID-64X from revisions 6 and 7 can be measured against. Every hour spent writing an HDMI transmitter is an hour not spent on the CPU.

**Move to the Zybo Z7-20 or a KV260 when timing closure becomes the limiting factor**, which it will (§3). Keep the RTL vendor-neutral from day one — no vendor primitives outside a thin `tech/` directory holding the register file, block RAM and DSP wrappers. That directory is the entire porting cost, and it should stay under 500 lines.

The ECP5 option is worth keeping in view because the fully open Yosys/nextpnr flow makes the whole thing reproducible without vendor licences, which matters if this is ever meant to be built by anyone else. But it has no hard CPU, and giving up §6 in phase 1 is a large loss for a benefit that only arrives at the end.

---

## 2. Resource budget

Estimates, not measurements, at roughly ±40%. Given in 6-input LUTs; Cyclone V ALMs are approximately 2 LUT-equivalents each.

| Block | LUTs | DSP | BRAM | Notes |
|---|---|---|---|---|
| register file, 16 × 64, 2R1W | ~250 | — | — | LUTRAM, duplicated for the second read port. **Not BRAM** — BRAM adds a cycle of latency on the critical path |
| ALU, 64-bit, with flags | ~600 | — | — | adder on the carry chain |
| barrel shifter, 64-bit | ~450 | — | — | 6 stages of 64 muxes; second-largest combinational block |
| address generation | ~150 | — | — | shared with the §5.1 stride adder |
| multiplier, iterative | ~200 | 2–4 | — | see below |
| divider, radix-4 non-restoring | ~400 | — | — | 32 cycles, sequential |
| decode and sequencer | ~400 | — | — | mostly wires, by ISA §9.5 |
| escape sub-decode | ~200 | — | — | parcel 1 of `BESC`/`MBLK`/`FESC`/`ATOM`/`SYS` |
| popcount tree, 64-bit | ~300 | — | — | serves `POPCNT`, `XNORPOP`, GC mark counting |
| CLZ / CTZ / CLO / CTO | ~250 | — | — | priority encoders, shared |
| bitfield extract / insert | ~350 | — | — | two shifters and a mask generator |
| byte / bit reverse | ~120 | — | — | pure wiring plus muxes |
| UTF-8 decode, encode, validity | ~400 | — | — | see below |
| carry-less multiply, 64×64 | ~900 | — | — | `CLMUL`; AND-XOR tree, no carries (ISA §4.6.3) |
| funnel shifter, 128→64 | ~350 | — | — | `DSHR`; shares the barrel shifter's mux tree (ISA §4.6.4) |
| tag compare and dispatch | ~120 | — | — | `BTAG`, `JTAG`; three XORs and the existing branch path (ISA §6.3) |
| indirect-transfer PC mux | ~80 | — | — | `XFER` — next PC from the load-return path (ISA §4.9) |
| SMP: `MFCPUID`, `ICINV`, `TLBSYNC`, `WFE`/`SEV` | ~400 | — | — | ISA §17.2; excludes the coherence protocol below |
| block move sequencer | ~300 | — | — | three counters and a byte-lane select; `MBLK` |
| TLB, 4-way set-associative, 64 entries | ~600 | — | 2 | see below |
| page table walker | ~250 | — | — | small FSM |
| direct mapping window compare | ~100 | — | — | two range comparators and an adder; ISA §8.3 |
| control, PSW, exception, undo buffer | ~450 | — | — | |
| **integer core, MMU, no FPU** | **~7,620** | 2–4 | 2 | |
| FPU, binary32 + binary64, with FMA | ~7,000 | 8–12 | — | **do not write this** — see §9. Revision-20 estimate; the FP exception flags (`FPSR`), `FRINTDA` and the unsigned conversions are not in it (see "Updates since revision 20") |
| L1 I-cache, 8 KB | ~300 | — | 4 | |
| L1 D-cache, 8 KB | ~500 | — | 4 | |
| Q64 bridge to AXI | ~600 | — | 1 | |
| **complete core** | **~16,020** | 10–16 | 11 | |
| snooping MSI coherence, per core | ~600 | — | 1 | ISA §17.3; multi-core builds only |

ISA revision 13 added about 2,000 LUTs of integer logic and 1,500 plus a few DSPs of FPU; revisions 15 through 20 added about 1,850 more, almost all of it `CLMUL`'s AND-XOR tree. The running total is roughly 50% above the revision 12 core and still comfortable on every board in §1: about 16,000 LUTs is near 15% of a DE10-Nano's logic, so a coherent pair fits with room for the peripherals.

Three notes on the new blocks:

**The popcount tree is the shared structure.** `POPCNT`, `XNORPOP` and a garbage collector's mark-bitmap scan all want the same 64-input adder tree, and `CLZ`/`CTZ`/`CLO`/`CTO` want a priority encoder over the same operand. Build one bit unit with a shared input mux rather than four independent functions, or you will pay for the tree twice.

**UTF-8 validity is where the LUTs go**, not the decode. Extracting the code point from one to four bytes is shifts and ors. The expensive part is the five simultaneous validity tests of ISA §4.6.1 — overlong, surrogate, out of range, bad continuation, impossible leading byte — and that is the part worth having in hardware, because it is the part software gets wrong.

**The block move sequencer is small because the architecture made it small.** It is three down/up counters and a byte-lane selector, with no hidden state register, because ISA §7.5 puts the progress in the architectural registers. Had the specification followed VAX's `MOVC5` instead, this line would read 1,500 LUTs plus a microstate save path plus a resume FSM.

The CPU fits everywhere on the list with room to spare. **BRAM, not LUTs, is the scarce resource**, and it will be consumed by the VIC-64X framebuffer and the caches, not by the processor.

Two places where the FPGA target should override the paper design:

**The TLB.** §8.2 assumed a 32-entry fully-associative TLB, and the transistor estimate in §10 of the ISA reflects that. On FPGA a fully-associative CAM is expensive and slow — 32 parallel 27-bit comparators, all of them on the address path. Build a 4-way set-associative TLB in BRAM instead: more entries, fewer LUTs, and it fits the cycle. This is an implementation choice with no architectural visibility, which is exactly the kind of thing §8.2 should not have prescribed.

**The multiplier.** A full combinational 64×64 needs roughly 9 DSP blocks on Cyclone V (27×27) or ~16 on Artix-7 (25×18), and it will not close timing in one cycle on either. Build it iteratively: 2–4 DSPs, 4–8 cycles, with a busy signal. `MUL` is not on the critical path of anything that matters, and burning a fifth of the DSPs on the board for it is a poor trade against the FPU — which, now that FMA is in the base ISA, needs its own 53×53 multiplier and will want 6–9 DSPs of its own.

**The block move width.** ISA §7.5 lets the implementation move as many bytes per step as it likes, provided the registers are consistent with byte-at-a-time progress at every interruptible point. On the DE10-Nano the natural step is the 64-bit datapath width — one quad per cycle — which makes `MCPY` run at roughly cache bandwidth with no extra logic. Do **not** be tempted into a wider burst engine in phase 1: the architectural freedom is there to be used later, and a wide engine is the kind of thing that gets the interrupt-latency bound wrong.

---

## 3. Clock frequency — the honest number

Earlier revisions carried a figure of 250 MHz. That was for the 16-bit machine and it was optimistic even there. Realistic expectations for pdp64:

| Device | Expected `Fmax` |
|---|---|
| Cyclone V (DE10-Nano) | 50–80 MHz |
| Artix-7 / Zynq 7020, -1 speed | 90–130 MHz |
| UltraScale+ (KV260) | 180–250 MHz |

The critical path is almost certainly **register read → address adder → TLB lookup → cache tag compare → way select**. The alternative candidate is ALU → flag generation → branch condition → next-PC mux.

Two structural facts help. The one-memory-operand rule (§3.4) means there is one AGU, not two, and no second operand path to multiplex. And the absence of deferred modes means address generation is a single adder pass, never load-then-add — which on FPGA is the difference between one cycle and a stall.

Two things to do about the path when it binds:

- **Virtually-indexed, physically-tagged L1.** With 4 KB pages and a way size no larger than 4 KB, index bits come entirely from the page offset, so TLB lookup and cache indexing run in parallel and there is no aliasing to police. This removes the TLB from the serial path and is the single highest-value microarchitectural decision on this list.
- **Split branch resolution from the ALU.** Flags are cheap in transistors (§4.4 of the ISA) but they are a serialization point on FPGA, where a 64-bit carry chain is slow. A dedicated comparator for branch conditions, running in parallel with the ALU rather than downstream of it, buys a stage.

Do not chase frequency in phase 1. A correct 40 MHz machine is worth more than a fast broken one, and the DE10-Nano at 60 MHz is already fifty times a PDP-11/70.

---

## 4. The grammar is the source of truth

**This is the highest-leverage decision in the project and it must be made before any RTL exists.** (The first version of this plan proposed an S-expression, then a JSON, machine-readable spec. A JSON spec was built and then retired; the source of truth is now a set of hbnf grammars. See below.)

Write the encoding as a machine-readable specification and generate everything downstream from it. The consumers this plan wants are:

- assembler mnemonic and encoding tables
- disassembler
- instruction set simulator decode
- RTL decode constants and the `casez` patterns
- the constrained random instruction generator (§7)
- the opcode map tables in the ISA document itself

The failure mode this prevents is the one every hand-built ISA project hits: the assembler, the simulator and the RTL drift, and you spend weeks debugging a "hardware bug" that is a disagreement about bit 11. RISC-V maintains `riscv-opcodes` for exactly this reason; ARM publishes its architecture as a machine-readable specification for the same reason.

**What was actually built (CHANGES-SINCE-R20.md §8).** The source is a set of [hbnf](https://github.com/moebiusV/hbnf) grammars in `spec/`, and the rule is that each fact is written in exactly one place:

| Fact | Written in | Consumed by |
|---|---|---|
| every opcode, sub-opcode, group opcode, addressing-mode number, store opcode, alias and register number | `spec/pdp64-mnemonics.hbnf` (enum rules; the only place the numbers are written) | the assembly parser, the bit-format grammar (via `tools/mkgrammar.py`), a generated C header of named constants, the drift test |
| instruction bit layout | `spec/pdp64.hbnf.in` (a template: numbers come in by name) | the generated decoder and encoder (hbnf `parse_bytes` / `emit_bytes`) |
| assembly syntax | `spec/pdp64-asm.hbnf` | the generated text parser |
| ELF record layouts | `spec/elf.hbnf` | the generated record writer (later `ld64`'s reader) |

`tools/mkgrammar.py` reads the enum rules and writes the bit-format grammar (the template with every name replaced by its number) and the generated headers of named constants. `tools/check-drift.py` assembles one instruction for every mnemonic the assembler can encode, reads the encoding back and compares it with the number in the grammar, and checks the opcode map (55 assigned opcodes; only `0x23` and `0x28`–`0x2F` free; escapes contiguous; branches `0x30`–`0x3F`). Displacement widths and field sizes are not copied into C: the assembler measures them by asking the generated encoder how many bits it accepts.

The earlier hand-written JSON spec (`spec/pdp64.json`, `tools/specgen.py`) repeated the opcode map, and when `FRECPED`/`FRSQRTED` were dropped it was the one file that had to be edited by hand — the failure the grammar is meant to prevent — so it was retired and is gone.

Not yet derived from the grammars: the *roles* of the fields for each mnemonic, the default stride of post-increment/pre-decrement, and which shapes the escape groups take still live in C and are shared with the emulator; the drift test guards the numbers but not these conventions (CHANGES §8; moving an operand-role table into the mnemonic file is recommended there). CHANGES does not say that RTL constants or a constrained random generator are produced from the grammars; those remain plan items.

The pdp64 encoding is unusually friendly to this. Length comes from `len` alone with no cases, the opcode sits at bits 13..8 in every form, and the register fields are at fixed positions. The generator is a few hundred lines, not a few thousand — and that cheapness is itself an argument that §9.5's "decode as wires" discipline was correct, since a decode that is easy to generate is a decode that is easy to synthesize flat.

An excerpt of the real source, in place of the S-expression sketch this section used to carry (the literal's number is its encoding; `fadd` is binary64, `fadd32` binary32, the old `faddd` an alias numbered 0x100 above):

```
mn-alu = "add"@0b010110
       | "sub"@0b010111
       ...
       | "fadd"@0b100100
       | "fcmp"@0b100111
        | "faddd"@0x124
```

Generate the RTL constants, not the RTL. Hand-write the datapath.

---

## 5. Phase plan

Each phase ends with a demonstrable artifact and a regression suite that later phases must not break.

| Phase | Deliverable | Gate |
|---|---|---|
| **0. Spec and tools** | machine-readable encoding (now the hbnf grammars, §4), assembler, disassembler, ISS with trace output | assembler and disassembler round-trip every encodable instruction. Status: the grammars, `as64`, `ld64` and `sim64` (user mode, `-t` trace) exist; the sources do not mention a disassembler or the lockstep trace comparison |
| **1. Integer core** | non-pipelined core, BRAM memory, no MMU, no FP, no cache. Includes the `BESC` bit unit and the `TAGOP`/`JTAG` paths — both are pure combinational logic and belong with the ALU | 10⁶ random instruction sequences trace-match the ISS |
| **2. Exceptions** | the full ISA §7 fault model, including the §7.5 progress category and the `MBLK` group | every row of the §7.3 fault matrix, injected at every instruction form, restarts exactly; every `MBLK` operation interrupted at every byte offset resumes correctly |
| **3. MMU** | TLB, walker, ASID, `G` bit, `MT` attribute, `DMW` windows | a page-fault handler demand-pages a running program; an uncached mapping bypasses the D-cache |
| **4. Memory system** | I- and D-cache, Q64-to-AXI bridge, HPS DDR | phase 1–3 regressions pass against real memory; `MCPY` sustains the expected bandwidth |
| **5. Floating point** | binary32, binary64, FMA | Berkeley TestFloat clean, including `mulAdd` |
| **6. Software** | a kernel that boots | a V7-descended system reaches a shell |
| **7. Peripherals** | Q64 devices, `BLT64`, VIC-64X, SID-64X | ISA revisions 6 and 7, plus §12 below |
| **8. SMP, optional** | second core, snooping MSI, broadcast `TLBI`, IPI path | two cores pass the litmus tests of §7 item 7; a kernel schedules on both |

**`MBLK` moves into phase 2, not phase 1.** The block move instructions are trivial to implement and impossible to get right without the exception model, because their entire specification is about what state is visible when an exception arrives. Building them in phase 1 means building them twice.

**Phase 8 is genuinely optional and genuinely last.** ISA §17 specifies sequential consistency, which is nearly free on this in-order non-speculative core — but "nearly free" is a claim about the design, not about an implementation, and §7 item 7 is how it gets checked. Nothing in phases 0–7 depends on it.

**Position-independent code needs nothing from the hardware** (ISA §19), but it does need the toolchain: PC-relative relocations in the assembler at phase 0, and a dynamic linker at phase 6. Worth knowing early because ISA §19.5 leaves three ABI questions open that the linker author has to answer.

**The UTF-8 unit can slip to phase 5 or later.** It is self-contained, it has a published conformance suite (the Unicode consortium's, plus Markus Kuhn's stress test), and nothing else depends on it. It is the one block that can be deferred without rework.

**Phase 2 is not optional and does not move.** §7 of the ISA exists because the 68000 retrofitted its fault model and the retrofit was ugly and expensive. Building the core first and the exception model second reproduces exactly that mistake in a project that was specifically designed to avoid it. Precise faults are a property of how the datapath commits state, and they are cheap to design in and dreadful to add.

The one-memory-operand rule makes phase 2 tractable in a way it is not on most CISC machines: the undo buffer is a single entry, the fault matrix is three rows, and row 3 is provably empty. Test that this is actually true before building anything on top of it.

**Phase 6 before phase 7.** The temptation will be to build the VIC first, because it is the visible fun part and the C64 work is already done. Resist it. A machine that boots a kernel to a serial console is a platform; a machine that draws sprites but cannot take a page fault is a demo.

---

## 6. Bring-up architecture — the HPS is the harness

This is why the SoC FPGA choice matters, and it is worth designing deliberately rather than falling into.

The hard ARM cores should carry, from phase 1:

- **The console and the loader.** A shared BRAM mailbox plus the lightweight HPS-to-FPGA bridge. The soft core has no ROM and no serial port for a long time; the HPS writes memory, releases reset, and reads a trace buffer.
- **The debug interface.** Halt, single-step, read and write the register file and `PSW`, set a PC breakpoint. Perhaps 200 LUTs mapped into the control bridge. Build this in phase 1, not phase 4 — it pays for itself within a week.
- **DDR, so you never write a memory controller.** The FPGA-to-SDRAM ports let the soft core reach the HPS's 1 GB DDR3 through the hard controller. This removes an entire subsystem from the schedule.
- **Lockstep co-simulation on hardware.** Run the ISS on the HPS, step the RTL core, compare architectural state every instruction. This is the workhorse of phase 1 and it is thousands of times faster than RTL simulation — the difference between a hundred thousand instructions overnight and a hundred million before lunch.

That last item is the real argument for the SoC part. It converts verification from a simulation problem into a runtime problem.

---

## 7. Verification

Ranked by value per hour:

1. **Trace comparison against the ISS.** Every architectural state change, every instruction. This finds nearly everything.
2. **Constrained random generation from the spec.** Because §4 gives a machine-readable encoding, the generator is nearly free: emit random valid instructions, weighted toward the boundaries — displacement extremes, mode 7 forms, `len` transitions, `R6` and `R14` as ordinary registers.
3. **Directed fault tests.** Enumerate the ISA §7.3 matrix. For every instruction form, fault the first fetch parcel, the second, the operand read at both page halves, and the RMW permission check. Assert exact restart. This is the suite that justifies the design and it is worth writing by hand.

   **The `MBLK` suite is separate and larger.** For each of `MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`: interrupt the operation at every byte offset from 0 to twice the implementation's block size, and after each interrupt assert that the three registers describe exactly the remaining work and that resumption completes correctly. Then do the same with a page fault rather than an interrupt, at each page boundary the operation crosses. Then do `MMOV` with every overlap relationship — source below destination, above, exactly equal, partially overlapping by one byte and by one block. This is where the §7.5 exception will break if it breaks.
4. **Formal, on the invariants that are actually load-bearing.** Four properties are small, combinational, and provable with SymbiYosys:
   - **no escape sub-opcode consumes more extension parcels than `len` declares** (ISA §4.14). This is the one that has a real failure mode: `BESC`, `MBLK`, `AESC`, `MESC`, `FESC` and `ATOM` each define their own parcel-1 layout, so a sub-opcode added later that wants two extension parcels at `len = 01` would leave the fetch unit and the decoder disagreeing about where the instruction ends, with no fault raised. `BESC`'s bitfield operations are already in this position legitimately — they exist only at `len = 10`. Prove it over the generated encoding table in §4, and re-run it on every spec change. "Length is `len + 1`" is *not* this property and is not worth proving — it is true by construction;
   - **whether parcel 0's low nibble is a mode or a register is fixed per escape opcode**, not per sub-opcode (ISA §4.14). `MESC` reads it as a mode; `BESC`, `MBLK` and `AESC` read it as a register. ISA §4.3.1 keeps the six parcel-1 escapes contiguous at `0x0C`–`0x11` so the distinction is a range compare. If that ever became sub-opcode-dependent, operand decode would depend on parcel 1, which defeats fixed-position decode;
   - **no ordinary instruction produces more than one register side effect.** The `MBLK` group is the stated exception and must be excluded from the property by opcode, not by accident;
   - the write of a read-modify-write cannot fault given that the read succeeded.

   These are the assumptions the whole restart argument rests on. Proving them is a day's work and removes an entire category of late surprise.
5. **Tag interaction.** ISA §6.2 makes the alignment abort a load-bearing runtime invariant. Test that a mis-biased tagged dereference always aborts, at every tag value and every access size; that `BTAG`/`BNTAG` agree with `AND #7` plus `CMP` for all eight tags and all sixteen registers; and that a `JTAG` through a table of eight landing pads reaches the right one for each tag value.
6. **Berkeley TestFloat** for phase 5, including the `mulAdd` tests for FMA. Do not hand-roll FP tests.
7. **Memory-model litmus tests**, once a second core exists. ISA §17.1 declares sequential consistency, and SC is easy to violate by accident — a store buffer that forwards wrongly, a cache that reorders its fills. Run the standard SC litmus suites (the `litmus7`/`herd7` family) against two cores before any lock-based software is trusted. ISA open item 11 records this as unverified.
8. **UTF-8 conformance.** Markus Kuhn's UTF-8 decoder stress test plus the Unicode consortium's conformance data. The validity cases of ISA §4.6.1 are the point of the instruction, so test them individually: each overlong form at each length, each surrogate boundary, U+10FFFF and U+110000, and every impossible leading byte.

---

## 8. Where the ISA helps and where it hurts on FPGA

**Helps.** One AGU. Single-pass address generation. Length known from parcel 0, so the fetch buffer is a two-deep shift register with no feedback. No unaligned data path — the single largest block of logic that is simply absent. No partial-register writes, so no byte-enable muxing on the register file write port. Decode is `casez` on six fixed-position bits, which synthesizes flat. `BESC`'s bit functions are wiring and mux trees, which is what fabric is made of. The `MBLK` group needs no microstate register (ISA §7.5), so it adds counters rather than a save/restore path.

**Hurts.** The 64-bit carry chain is slow on Cyclone V and gates `Fmax` more than it would in silicon. The barrel shifter is a large mux tree that does not map to anything special. Flags serialize branch resolution behind the ALU (§3), and now `FCMP` (formerly `FCMPD`; the old spelling is an alias) serializes against them too — ISA §12.7 records this as open, and it is still open (CHANGES-SINCE-R20.md §2.3). The strided autoincrement of ISA §5.1 puts a second wide adder on the register writeback path, though it can share the AGU adder if the writeback is one cycle behind. And `MBLK` writes three registers per step, which either needs a second write port or forces the step to take as many cycles as it has registers to update — take the latter in phase 2 and revisit only if measurement demands it.

Nothing here argues for changing the ISA. It argues for where the pipeline registers go.

---

## 9. Build versus buy

**Buy the FPU.** Use Berkeley HardFloat — BSD-licensed, Chisel-generated but ships as usable Verilog, and it is what Rocket and CVA6 use. It is IEEE-754 correct, TestFloat-verified, and writing an equivalent from scratch is three to four months that produce a worse result. Wrap it to the ISA §4.10 opcode set and to the shared-register-file convention of ISA §2.3. Two things the wrapper must also supply, both added after revision 20: the sticky `FPSR` exception flags (five bits, never trapping, read and written by `FSFLAGS`) and canonical-NaN results (`0x7FF8000000000000`, binary32 `0x7FC00000`, no payload propagation; errata 26, decided in `sim64`) — hardware must produce the same bits as `sim64`. Directed rounding for arithmetic is undecided (CHANGES-SINCE-R20.md §12), so what to ask of HardFloat's rounding-mode input is open.

HardFloat's `mulAddRecFN` is the FMA module, so the one FP instruction that genuinely matters (ISA §9.7) comes for free with the decision to buy rather than build. That is worth noting as a reason the decision is not close: implementing a correctly-rounded fused multiply-add from scratch, with one rounding over the full 106-bit intermediate product, is the hardest single block in the machine.

**Buy the HDMI and scaler** on the DE10-Nano by using the MiSTer framework, at least until phase 7.

**Build the CPU, the MMU and the memory system.** These are the project.

**Language:** SystemVerilog for the datapath, with decode tables generated per §4. Vendor timing reports, formal tools and simulators all work best with it, and timing closure debugging is where you will spend the painful hours. Amaranth or Chisel would generate more elegantly but put a layer between you and the timing report, which is the wrong trade for a project whose hard part is `Fmax` and correctness rather than parameterization.

---

## 10. Schedule

For one experienced engineer working seriously part-time. Wide error bars, and phases 2 and 3 are the ones that historically double.

| Phase | Estimate | Change from r11 plan |
|---|---|---|
| 0. Spec and tools | 5–9 weeks | +1, larger encoding |
| 1. Integer core | 9–14 weeks | +1–2, the bit unit and tag ops |
| 2. Exceptions | 6–11 weeks | +2–3, the `MBLK` progress category and its test suite |
| 3. MMU | 7–11 weeks | +1, `MT` and `DMW` |
| 4. Memory system | 4–8 weeks | |
| 5. Floating point (integrating HardFloat) | 4–7 weeks | +1, FMA and the classify/min/max set |
| 6. Kernel bring-up | 8–16 weeks | |
| **to a booting system with FP** | **~10–19 months** | |

Revision 13 added roughly a month and a half. Most of it is phase 2, and most of *that* is the `MBLK` verification suite in §7 rather than the hardware, which is three counters. That ratio is the right one and is what §1.1(b) of the ISA means by a bounded, written-down cost.

Phase 6 is the widest because it is not really a hardware phase. It is a compiler backend, a libc, and a port — and the compiler backend is the item most likely to be underestimated, since Facet and the existing V7 translation work will both want to target this and neither currently has a code generator for it. *(Update: a pcc back end now exists, `arch/pdp64` in moebiusV/pcc, and compiled C runs under `sim64`; see risk 1.)*

---

## 11. Risks, in order

1. **The compiler backend.** *(Update: partly retired. A pcc back end for pdp64 now exists and compiled C runs under `sim64`; CHANGES-SINCE-R20.md §14 reports, on the 841-file fair corpus, 1.03 times amd64 and 1.04 times aarch64 in instructions and 0.97 and 0.89 times in bytes, with instruction lengths 2/4/6/8 bytes at 46.5/42.8/10.6/0.1 %. That answers the measured-length-distribution half of the question below; the scaled-index displacement width (ISA open item 1) is not addressed by the sources. The text below is the original risk.)* Phase 6 assumes one exists. Nothing in phases 0–5 produces it, and no schedule line above covers writing it. Decide early whether the target is LLVM, a Facet backend, or a small self-hosted generator, because the answer changes the ISA's ABI document and bears directly on ISA open items 1 and 6 — the scaled-index displacement width and the measured length distribution are both questions only a code generator can answer.
2. **Timing closure on Cyclone V.** If the design lands at 35 MHz rather than 60, the fix is architectural — pipeline stages — and pipelining a machine with memory operands and precise faults is not a small change. Mitigate by leaving pipeline register boundaries in the RTL from phase 1, even when unused.
3. **Q64 exclusive access over AXI.** Open item 4 of the spec. The Unibus-derived `DATIP`/`DATO` locked read-modify-write is a *lock*; AXI exclusive access is a *monitor*. They are not the same primitive and the mapping is not clean. This needs settling before phase 4, not during it — and ISA revision 13's `_DB` barrier-fused atomics raise the stakes, because they assert an ordering guarantee that has to mean something on the actual interconnect.
4. **BRAM exhaustion at phase 7.** The caches, the TLB, the VIC-64X framebuffer, the `BLT64` scratch and the SID-64X voice state all want BRAM, and the DE10-Nano has about 5.5 Mb. Budget it before building the VIC, not after. §12 has the framebuffer numbers.
5. **`MBLK` cache pollution.** ISA open item 8. A large `MCPY` will evict the entire D-cache for data that is never read again. On an 8 KB cache this shows up immediately. The architectural fix is a non-temporal variant or a streaming `MT` value; the non-fix is deciding by length in the implementation, which is a performance cliff with no architectural visibility. Decide in phase 4, when the cache exists and the effect is measurable.
6. **Scope.** Revisions 1 through 7 specified a considerable amount of machine, and revisions 13 through 20 added five instruction groups. The gate for phase 7 should be that phase 6 boots, and that gate should be defended.

---

## 12. Graphics: the Blit terminal, and the GPU question

ISA §16 states the separation: graphics is Q64 device work and touches the processor only through the memory-type attribute, `FENCE`, and atomics. What follows is the device side.

### 12.1 The answer about a standard GPU

**Electrically possible, practically hopeless.** The path is real — a Zynq UltraScale+ has a hard PCIe root complex, so a Q64-to-PCIe bridge would let an off-the-shelf card enumerate. What makes it hopeless is everything after enumeration. A modern discrete GPU needs PCIe configuration space, BAR mapping, MSI-X interrupt delivery, an IOMMU or at minimum scatter-gather DMA with pinned pages, a firmware blob loaded at init, power and clock sequencing, and a command submission model that is documented for exactly none of the vendors in a form you could implement against. The Linux driver for one of these is six figures of lines, and most of its knowledge is not in any specification.

You would spend the project's entire remaining budget writing a driver for hardware whose programming model you have to reverse-engineer, in order to run a graphics stack that does not exist on this machine. Say no clearly and early.

The Cyclone V and Zynq 7020 do not have the hard PCIe to make even the electrical part straightforward, so on the phase 1 board the question does not arise.

### 12.2 What is right instead: `BLT64`

Pike's Blit had the correct architecture for this machine and it is worth copying directly: a framebuffer in the address space, plus a bitblt engine that does rectangle copies with raster operations. That is the whole of it, and it is what made the Blit, the Amiga and every 1980s windowing system fast enough to be pleasant.

`BLT64` as a Q64 device:

| Register | Purpose |
|---|---|
| `BSRC`, `BDST` | source and destination base addresses |
| `BSPITCH`, `BDPITCH` | row strides in bytes |
| `BW`, `BH` | rectangle width and height |
| `BROP` | raster operation — the 16 binary ops of source against destination, plus the common ternary ones |
| `BMASK` | bit mask or transparent colour |
| `BCTL` | direction, go, busy, interrupt-on-done |

Rough cost: 1,500 LUTs plus a line buffer, and it is almost entirely address arithmetic. It covers scrolling a terminal, moving a window, drawing a font glyph, filling a rectangle and XOR-ing a cursor — which is the complete working set of a text-and-windows machine, and the thing a CPU is worst at.

Two notes on how it meets the processor:

- **Map the framebuffer with `MT = 01`** (normal uncached) or the CPU's writes will sit in the D-cache while the raster engine scans out stale memory. This is the hole that ISA revision 13's `MT` field closed, and it is the specific bug that would otherwise have been found at 2 a.m. in phase 7.
- **A `FENCE` between writing the `BLT64` registers and setting the go bit**, and the device's done-interrupt on the other side. The ordering guarantee ISA §16 owes devices is exactly this one.

`MCPY` is not a substitute. It is a one-dimensional byte move; a blit is two-dimensional with a stride and a raster op, and it runs concurrently with the processor rather than occupying it.

### 12.3 Framebuffer budget

The BRAM question from §11 risk 4, concretely. On the DE10-Nano's ~5.5 Mb:

| Mode | Bytes | Fits in BRAM? |
|---|---|---|
| 80×25 text, 2 bytes per cell | 4 KB | trivially |
| 640×480, 8-bit colour | 300 KB | no — 2.4 Mb, about half the device |
| 1280×720, 8-bit | 900 KB | no |
| 1920×1080, 32-bit | 8.3 MB | no |

So anything above a text console or a small bitmap lives in HPS DDR, reached through the FPGA-to-SDRAM ports, with BRAM used as a scanout line buffer of a few KB. That is also how the MiSTer cores do it, which means the pattern is already proven on this exact board. Budget BRAM for caches, the TLB and line buffers; budget DDR for pixels.

### 12.4 If 3D or compute is wanted later

Not a GPU. A small array of fabric cores with local memory, fed by a command FIFO from Q64 — which is the dedicated-hardware-per-function model from ISA revision 5, the one taken from Chuck Moore's GA144 and MuP21. Each core does one thing with its own memory and is fed work rather than sharing an address space.

That model also absorbs the other coprocessor the ISA defers to it: ISA §4.6.2 declines the ternary 2-bit dot product on the grounds that wide data-parallel work belongs off the scalar core. The same FIFO-fed array serves both, and building it for one workload gets the other for free.

The honest sequence is: `BLT64` in phase 7, because it makes the machine usable; the array later, if there is a workload that needs it. A 2D blitter is a known quantity with a forty-year track record. A home-grown shader array is a research project, and it should be labelled one.

---

## Updates since revision 20

Resource estimates in §2 are **unchanged and were not recomputed**; they are revision-20 figures. The list below says what the later changes plausibly affect. Everything here is unmeasured unless marked otherwise. Source: [`../CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md).

- **Two instructions dropped** (`FRECPED`, `FRSQRTED`; errata 16): the estimate lookup tables never need to be built. The revision-20 FPU line carried no separate figure for them, so no number changes. The CRC instructions (added, then withdrawn; errata 20) never entered the budget.
- **FP exception flags** (`FPSR`, `FSFLAGS`; errata 17): a five-bit sticky register that is part of the thread context and is OR-ed by every FP operation. It adds state to the FPU and the context switch path and a read/write port; CHANGES gives no LUT figure. Unmeasured.
- **`FRINTDA`, `FCVTDQU`, `FCVTQUD`** (errata 18, 19): extra rounding and conversion cases in the FPU. No figure in the sources. Unmeasured.
- **NaN results are canonical** (errata 26): small extra logic on FP result paths; no figure. Unmeasured.
- **`ABS`, `MIN`, `MINU`, `MAX`, `MAXU`** (errata 23): errata 23 estimates 150-250 LUTs, reusing the negate path and the compare of `SUB`/`CMP` with a 64-bit select. This is an estimate, not a measurement, and it is not in the §2 table.
- **`SET cc, rd`** (errata 25): one `AESC` sub-opcode that turns the branch-condition logic into a register write. No figure; it is not in §2. Unmeasured.
- **`PUSHM`/`POPM` moved to `SOP`; `TRAP`/`TRAPL` split; `SYS` classes; `RORI`** (errata 4, 5, 10): decode changes in the `SOP`, `SYS` and `BESC` groups. The decoder structure of §2 ("mostly wires") is the thing to re-check; no figure.
- **Half precision (`binary16`)**: proposed, not decided. CHANGES §14 gives estimates, not measurements: conversion only about 500-1,000 LUTs, full arithmetic about 2,000-3,500 LUTs. Neither is in the §2 table.
- **Directed rounding for FP arithmetic**: undecided (CHANGES §12). Depending on the option chosen (a static rounding field, a mode register, or more opcodes) the FPU decode or the opcode map changes. No figure.
- **Opcode map counts**: 55 assigned opcodes, the spare ALU slot `0x23` and eight reserved (`0x28`-`0x2F`), not the 56 + 8 of ISA r20 §4.16 (errata 2). This changes no LUT figure; it matters for the spare-slot arithmetic.
- **Measured instruction lengths** (CHANGES §14): the compiler-side findings feed the fetch-buffer and cache assumptions of §3 and §8, but the sources give no hardware figure.

---

## Changes since revision 20

This document was copied from [`orig/11-64W-fpga-plan.md`](orig/11-64W-fpga-plan.md), written under the working name 11/64W against ISA revision 20. The original is unmodified in `docs/11-64W/`. Full list, with reasons: [`../CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md); decisions numbered in [`../errata.md`](errata.md). Changes in this document:

- Renamed to pdp64 (DEC PDP-64); cross-references point at `pdp64-isa.md` and `pdp64-lb64-accelerator.md`. (errata 12)
- §4: the machine-readable S-expression/JSON spec is replaced by hbnf grammars in `spec/`, generated by `tools/mkgrammar.py` and checked by `tools/check-drift.py`; the JSON spec was retired. (CHANGES §8)
- Phase 0 and risk 1: `as64`, `ld64`, `sim64` and a pcc back end now exist; fair-corpus measurements in CHANGES §14.
- §3, §9: `FCMPD` is `FCMP` (old spelling kept as alias); FP exception flags and canonical NaNs added to the FPU wrapper requirements. (errata 17, 24, 26)
- Dropped instructions `FRECPED`/`FRSQRTED` (errata 16) and the withdrawn CRC instructions (errata 20); added `FSFLAGS`, `FCVTDQU`, `FCVTQUD`, `FRINTDA`, `SET`, `ABS`/`MIN`/`MINU`/`MAX`/`MAXU` (errata 17, 18, 19, 25, 23). Opcode count corrected to 55 assigned (errata 2).
- "Updates since revision 20" lists what these plausibly affect in §2; no estimate was recomputed.
