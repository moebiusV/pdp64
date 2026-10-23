# DEC PDP-64 — SoC FPGA Implementation Plan

[← pdp64 index](../README.md)

**DEC PDP-64: Digital Equity Collective's Pragmatic Digital Processor, 64 bit.**

**Companion to the ISA, [`pdp64-isa.md`](pdp64-isa.md).** Kept separate from the ISA because the ISA is meant to outlive any particular FPGA and this document is expected to churn.

---

## 1. Target selection

The pdp64 assumes a SoC FPGA: fabric plus hard ARM cores. The hard cores matter for a reason that has nothing to do with the finished machine: **they are the bring-up harness.** See §6.

Verify current availability and pricing before ordering; the Cyclone V generation in particular is old enough that supply is uneven.

| Board | Device | Fabric | Hard CPU | Notes |
|---|---|---|---|---|
| **Terasic DE10-Nano** | Cyclone V SE 5CSEBA6 | ~110K LE (~41K ALM) | dual Cortex-A9 | 1 GB DDR3 on HPS, HDMI via ADV7513, MiSTer ecosystem |
| Digilent Zybo Z7-20 | Zynq 7020 | 53K LUT, 220 DSP | dual Cortex-A9 | HDMI in *and* out, good Vivado support |
| AMD Kria KV260 | Zynq UltraScale+ ZU5EV | ~117K LUT | quad A53 | much faster fabric, DisplayPort not HDMI |
| ULX3S | Lattice ECP5-85F | 84K LUT | none | fully open toolchain, no hard CPU — loses §6 entirely |

**Start on the DE10-Nano.** It is the slowest of the four, but the MiSTer ecosystem has already solved the problems that are not the CPU's: HDMI output and scaling, USB input, SD card, SDRAM daughterboard, and a body of working C64 core work that the VIC-64X and SID-64X can be measured against. Every hour spent writing an HDMI transmitter is an hour not spent on the CPU.

**Move to the Zybo Z7-20 or a KV260 when timing closure becomes the limiting factor** (§3). Keep the RTL vendor-neutral from day one — no vendor primitives outside a thin `tech/` directory holding the register file, block RAM and DSP wrappers. That directory is the entire porting cost, and it should stay under 500 lines.

The ECP5 option stays in view because the fully open Yosys/nextpnr flow makes the whole design reproducible without vendor licences, which matters if anyone else is to build it. It has no hard CPU, and giving up §6 in phase 1 is a large loss for a benefit that only arrives at the end.

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
| FPU, binary32 + binary64, with FMA | ~7,000 | 8–12 | — | **do not write this** — see §9. The estimate does not include the FP exception flags (`FPSR`), `FRINTDA` or the unsigned conversions (see "Resource notes for later additions") |
| L1 I-cache, 8 KB | ~300 | — | 4 | |
| L1 D-cache, 8 KB | ~500 | — | 4 | |
| Q64 bridge to AXI | ~600 | — | 1 | |
| **complete core** | **~16,020** | 10–16 | 11 | |
| snooping MSI coherence, per core | ~600 | — | 1 | ISA §17.3; multi-core builds only |

The total is comfortable on every board in §1: about 16,000 LUTs is near 15% of a DE10-Nano's logic, so a coherent pair fits with room for the peripherals. `CLMUL`'s AND-XOR tree is the largest of the bit-manipulation blocks.

Three notes on the bit-manipulation, UTF-8 and block-move blocks:

**The popcount tree is the shared structure.** `POPCNT`, `XNORPOP` and a garbage collector's mark-bitmap scan all want the same 64-input adder tree, and `CLZ`/`CTZ`/`CLO`/`CTO` want a priority encoder over the same operand. Build one bit unit with a shared input mux rather than four independent functions, or the tree is paid for twice.

**UTF-8 validity is where the LUTs go**, not the decode. Extracting the code point from one to four bytes is shifts and ors. The expensive part is the five simultaneous validity tests of ISA §4.6.1 — overlong, surrogate, out of range, bad continuation, impossible leading byte — and that is the part worth having in hardware, because it is the part software gets wrong.

**The block move sequencer is small because the architecture keeps it small.** It is three down/up counters and a byte-lane selector, with no hidden state register, because ISA §7.5 puts the progress in the architectural registers. A design following VAX's `MOVC5` would need about 1,500 LUTs plus a microstate save path plus a resume FSM.

The CPU fits everywhere on the list with room to spare. **BRAM, not LUTs, is the scarce resource**, and it will be consumed by the VIC-64X framebuffer and the caches, not by the processor.

Three places where the FPGA target differs from the transistor-level design of the ISA:

**The TLB.** The transistor estimate in ISA §10 assumes a 32-entry fully-associative TLB. On FPGA a fully-associative CAM is expensive and slow — 32 parallel 27-bit comparators, all of them on the address path. Build a 4-way set-associative TLB in BRAM instead: more entries, fewer LUTs, and it fits the cycle. This is an implementation choice with no architectural visibility.

**The multiplier.** A full combinational 64×64 needs roughly 9 DSP blocks on Cyclone V (27×27) or ~16 on Artix-7 (25×18), and it will not close timing in one cycle on either. Build it iteratively: 2–4 DSPs, 4–8 cycles, with a busy signal. `MUL` is not on the critical path of anything that matters, and spending a fifth of the DSPs on the board for it is a poor trade against the FPU, which, with FMA in the base ISA, needs its own 53×53 multiplier and wants 6–9 DSPs.

**The block move width.** ISA §7.5 lets the implementation move as many bytes per step as it likes, provided the registers are consistent with byte-at-a-time progress at every interruptible point. On the DE10-Nano the natural step is the 64-bit datapath width — one quad per cycle — which makes `MCPY` run at roughly cache bandwidth with no extra logic. Do not build a wider burst engine in phase 1: the architectural freedom is there to be used later, and a wide engine is easy to get wrong against the interrupt-latency bound.

---

## 3. Clock frequency

Expected `Fmax` for pdp64:

| Device | Expected `Fmax` |
|---|---|
| Cyclone V (DE10-Nano) | 50–80 MHz |
| Artix-7 / Zynq 7020, -1 speed | 90–130 MHz |
| UltraScale+ (KV260) | 180–250 MHz |

The critical path is expected to be **register read → address adder → TLB lookup → cache tag compare → way select**. The alternative candidate is ALU → flag generation → branch condition → next-PC mux.

Two structural facts help. The one-memory-operand rule (§3.4) means there is one AGU, not two, and no second operand path to multiplex. And the absence of deferred modes means address generation is a single adder pass, never load-then-add — which on FPGA is the difference between one cycle and a stall.

Two things to do about the path when it binds:

- **Virtually-indexed, physically-tagged L1.** With 4 KB pages and a way size no larger than 4 KB, index bits come entirely from the page offset, so TLB lookup and cache indexing run in parallel and there is no aliasing to police. This removes the TLB from the serial path and is the single highest-value microarchitectural decision on this list.
- **Split branch resolution from the ALU.** Flags are cheap in transistors (§4.4 of the ISA) but they are a serialization point on FPGA, where a 64-bit carry chain is slow. A dedicated comparator for branch conditions, running in parallel with the ALU rather than downstream of it, buys a stage.

Do not chase frequency in phase 1. A correct 40 MHz machine is worth more than a fast broken one, and the DE10-Nano at 60 MHz is already fifty times a PDP-11/70.

---

## 4. The grammar is the source of truth

**This is the highest-leverage decision in the project and it is made before any RTL exists.** The source of truth is a set of [hbnf](https://github.com/moebiusV/hbnf) grammars (see below).

The encoding is a machine-readable specification, and everything downstream is generated from it. The consumers are:

- assembler mnemonic and encoding tables
- disassembler
- instruction set simulator decode
- RTL decode constants and the `casez` patterns
- the constrained random instruction generator (§7)
- the opcode map tables in the ISA document itself

The failure mode this prevents is the one every hand-built ISA project hits: the assembler, the simulator and the RTL drift, and weeks go into debugging a "hardware bug" that is a disagreement about bit 11. RISC-V maintains `riscv-opcodes` for exactly this reason; ARM publishes its architecture as a machine-readable specification for the same reason.

**Source files.** The grammars are in `spec/`, and each fact is written in exactly one place:

| Fact | Written in | Consumed by |
|---|---|---|
| every opcode, sub-opcode, group opcode, addressing-mode number, store opcode, alias and register number | `spec/pdp64-mnemonics.hbnf` (enum rules; the only place the numbers are written) | the assembly parser, the bit-format grammar (via `tools/mkgrammar.py`), a generated C header of named constants, the drift test |
| instruction bit layout | `spec/pdp64.hbnf.in` (a template: numbers come in by name) | the generated decoder and encoder (hbnf `parse_bytes` / `emit_bytes`) |
| assembly syntax | `spec/pdp64-asm.hbnf` | the generated text parser |
| ELF record layouts | `spec/elf.hbnf` | the generated record writer (later `ld64`'s reader) |

`tools/mkgrammar.py` reads the enum rules and writes the bit-format grammar (the template with every name replaced by its number) and the generated headers of named constants. `tools/check-drift.py` assembles one instruction for every mnemonic the assembler can encode, reads the encoding back and compares it with the number in the grammar, and checks the opcode map (58 assigned opcodes; only `0x23` and `0x2B`–`0x2F` free; escapes contiguous; branches `0x30`–`0x3F`). Displacement widths and field sizes are not copied into C: the assembler measures them by asking the generated encoder how many bits it accepts.

Not yet derived from the grammars: the roles of the fields for each mnemonic, the default stride of post-increment/pre-decrement, and which shapes the escape groups take. These live in C and are shared with the emulator; the drift test guards the numbers but not these conventions. Moving an operand-role table into the mnemonic file is the recommended next step. RTL constants and a constrained random generator are not yet produced from the grammars; they remain plan items.

The pdp64 encoding suits this approach. Length comes from `len` alone with no cases, the opcode sits at bits 13..8 in every form, and the register fields are at fixed positions. The generator is a few hundred lines, not a few thousand, and a decode that is easy to generate is a decode that is easy to synthesize flat, which is the point of ISA §9.5's "decode as wires" discipline.

An excerpt of the source (the literal's number is its encoding; `fadd` is binary64, `fadd32` binary32, and `faddd` an alias numbered 0x100 above):

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
| **0. Spec and tools** | machine-readable encoding (the hbnf grammars, §4), assembler, disassembler, ISS with trace output | assembler and disassembler round-trip every encodable instruction. Status: the grammars, `as64`, `ld64` and `sim64` (user mode, `-t` trace) exist; the disassembler and the lockstep trace comparison do not |
| **1. Integer core** | non-pipelined core, BRAM memory, no MMU, no FP, no cache. Includes the `BESC` bit unit and the `TAGOP`/`JTAG` paths — both are pure combinational logic and belong with the ALU | 10⁶ random instruction sequences trace-match the ISS |
| **2. Exceptions** | the full ISA §7 fault model, including the §7.5 progress category and the `MBLK` group | every row of the §7.3 fault matrix, injected at every instruction form, restarts exactly; every `MBLK` operation interrupted at every byte offset resumes correctly |
| **3. MMU** | TLB, walker, ASID, `G` bit, `MT` attribute, `DMW` windows | a page-fault handler demand-pages a running program; an uncached mapping bypasses the D-cache |
| **4. Memory system** | I- and D-cache, Q64-to-AXI bridge, HPS DDR | phase 1–3 regressions pass against real memory; `MCPY` sustains the expected bandwidth |
| **5. Floating point** | binary32, binary64, FMA | Berkeley TestFloat clean, including `mulAdd` |
| **6. Software** | a kernel that boots | a V7-descended system reaches a shell |
| **7. Peripherals** | Q64 devices, `BLT64`, VIC-64X, SID-64X | the VIC-64X and SID-64X specifications, plus §12 below |
| **8. SMP, optional** | second core, snooping MSI, broadcast `TLBI`, IPI path | two cores pass the litmus tests of §7 item 7; a kernel schedules on both |

**`MBLK` belongs to phase 2, not phase 1.** The block move instructions are trivial to implement and impossible to get right without the exception model, because their entire specification is about what state is visible when an exception arrives. Building them in phase 1 means building them twice.

**Phase 8 is optional and last.** ISA §17 specifies sequential consistency, which is nearly free on this in-order non-speculative core. "Nearly free" is a claim about the design, not about an implementation, and §7 item 7 is how it gets checked. Nothing in phases 0–7 depends on it.

**Position-independent code needs nothing from the hardware** (ISA §19), but it does need the toolchain: PC-relative relocations in the assembler at phase 0, and a dynamic linker at phase 6. ISA §19.5 leaves three ABI questions open that the linker author has to answer.

**The UTF-8 unit can slip to phase 5 or later.** It is self-contained, it has a published conformance suite (the Unicode consortium's, plus Markus Kuhn's stress test), and nothing else depends on it. It is the one block that can be deferred without rework.

**Phase 2 is not optional and does not move.** ISA §7 exists because the 68000 retrofitted its fault model and the retrofit was ugly and expensive. Building the core first and the exception model second reproduces that mistake. Precise faults are a property of how the datapath commits state, and they are cheap to design in and dreadful to add.

The one-memory-operand rule makes phase 2 tractable in a way it is not on most CISC machines: the undo buffer is a single entry, the fault matrix is three rows, and row 3 is provably empty. Test that this holds before building anything on top of it.

**Phase 6 comes before phase 7.** The VIC is the visible part, and the C64 work is already done, but a machine that boots a kernel to a serial console is a platform, and a machine that draws sprites but cannot take a page fault is a demo.

---

## 6. Bring-up architecture — the HPS is the harness

The SoC FPGA choice exists for this section.

The hard ARM cores should carry, from phase 1:

- **The console and the loader.** A shared BRAM mailbox plus the lightweight HPS-to-FPGA bridge. The soft core has no ROM and no serial port for a long time; the HPS writes memory, releases reset, and reads a trace buffer.
- **The debug interface.** Halt, single-step, read and write the register file and `PSW`, set a PC breakpoint. About 200 LUTs mapped into the control bridge. Build it in phase 1, not phase 4.
- **DDR, so no memory controller is written.** The FPGA-to-SDRAM ports let the soft core reach the HPS's 1 GB DDR3 through the hard controller. This removes an entire subsystem from the schedule.
- **Lockstep co-simulation on hardware.** Run the ISS on the HPS, step the RTL core, compare architectural state every instruction. This is the workhorse of phase 1 and it is thousands of times faster than RTL simulation — the difference between a hundred thousand instructions overnight and a hundred million before lunch.

The last item is the main argument for the SoC part: it converts verification from a simulation problem into a runtime problem.

---

## 7. Verification

Ranked by value per hour:

1. **Trace comparison against the ISS.** Every architectural state change, every instruction. This finds nearly everything.
2. **Constrained random generation from the spec.** Because §4 gives a machine-readable encoding, the generator is nearly free: emit random valid instructions, weighted toward the boundaries — displacement extremes, mode 7 forms, `len` transitions, `R6` and `R14` as ordinary registers.
3. **Directed fault tests.** Enumerate the ISA §7.3 matrix. For every instruction form, fault the first fetch parcel, the second, the operand read at both page halves, and the RMW permission check. Assert exact restart. This is the suite that justifies the design and it is worth writing by hand.

   **The `MBLK` suite is separate and larger.** For each of `MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`: interrupt the operation at every byte offset from 0 to twice the implementation's block size, and after each interrupt assert that the three registers describe exactly the remaining work and that resumption completes correctly. Then do the same with a page fault rather than an interrupt, at each page boundary the operation crosses. Then do `MMOV` with every overlap relationship — source below destination, above, exactly equal, partially overlapping by one byte and by one block. This is where the §7.5 exception will break if it breaks.
4. **Formal, on the load-bearing invariants.** Four properties are small, combinational, and provable with SymbiYosys:
   - **no escape sub-opcode consumes more extension parcels than `len` declares** (ISA §4.14). This is the one that has a real failure mode: `BESC`, `MBLK`, `AESC`, `MESC`, `FESC` and `ATOM` each define their own parcel-1 layout, so a sub-opcode that wants two extension parcels at `len = 01` would leave the fetch unit and the decoder disagreeing about where the instruction ends, with no fault raised. `BESC`'s bitfield operations are in this position legitimately: they exist only at `len = 10`. Prove it over the generated encoding table in §4, and re-run it on every spec change. "Length is `len + 1`" is not this property and is not worth proving, because it is true by construction;
   - **whether parcel 0's low nibble is a mode or a register is fixed per escape opcode**, not per sub-opcode (ISA §4.14). `MESC` reads it as a mode; `BESC`, `MBLK` and `AESC` read it as a register. ISA §4.3.1 keeps the six parcel-1 escapes contiguous at `0x0C`–`0x11` so the distinction is a range compare. If that ever became sub-opcode-dependent, operand decode would depend on parcel 1, which defeats fixed-position decode;
   - **no ordinary instruction produces more than one register side effect.** The `MBLK` group is the stated exception and must be excluded from the property by opcode, not by accident;
   - the write of a read-modify-write cannot fault given that the read succeeded.

   These are the assumptions the whole restart argument rests on. Proving them is a day's work.
5. **Tag interaction.** ISA §6.2 makes the alignment abort a load-bearing runtime invariant. Test that a mis-biased tagged dereference always aborts, at every tag value and every access size; that `BTAG`/`BNTAG` agree with `AND #7` plus `CMP` for all eight tags and all sixteen registers; and that a `JTAG` through a table of eight landing pads reaches the right one for each tag value.
6. **Berkeley TestFloat** for phase 5, including the `mulAdd` tests for FMA. Hand-written FP tests are not a substitute.
7. **Memory-model litmus tests**, once a second core exists. ISA §17.1 declares sequential consistency, and SC is easy to violate by accident — a store buffer that forwards wrongly, a cache that reorders its fills. Run the standard SC litmus suites (the `litmus7`/`herd7` family) against two cores before any lock-based software is trusted. ISA open item 11 records this as unverified.
8. **UTF-8 conformance.** Markus Kuhn's UTF-8 decoder stress test plus the Unicode consortium's conformance data. The validity cases of ISA §4.6.1 are the point of the instruction, so test them individually: each overlong form at each length, each surrogate boundary, U+10FFFF and U+110000, and every impossible leading byte.

---

## 8. Where the ISA helps and where it hurts on FPGA

**Helps.** One AGU. Single-pass address generation. Length known from parcel 0, so the fetch buffer is a two-deep shift register with no feedback. No unaligned data path, the single largest block of logic that is absent. No partial-register writes, so no byte-enable muxing on the register file write port. Decode is `casez` on six fixed-position bits, which synthesizes flat. `BESC`'s bit functions are wiring and mux trees, which is what fabric is made of. The `MBLK` group needs no microstate register (ISA §7.5), so it adds counters rather than a save/restore path.

**Hurts.** The 64-bit carry chain is slow on Cyclone V and gates `Fmax` more than it would in silicon. The barrel shifter is a large mux tree that does not map to anything special. Flags serialize branch resolution behind the ALU (§3), and `FCMP` serializes against them too; ISA §12.7 records this as open. The strided autoincrement of ISA §5.1 puts a second wide adder on the register writeback path, though it can share the AGU adder if the writeback is one cycle behind. And `MBLK` writes three registers per step, which either needs a second write port or forces the step to take as many cycles as it has registers to update — take the latter in phase 2 and revisit only if measurement demands it.

Nothing here argues for changing the ISA; it determines where the pipeline registers go.

---

## 9. Build versus buy

**Buy the FPU.** Use Berkeley HardFloat: BSD-licensed, Chisel-generated but shipped as usable Verilog, and used by Rocket and CVA6. It is IEEE-754 correct and TestFloat-verified, and writing an equivalent from scratch takes three to four months and produces a worse result. Wrap it to the ISA §4.10 opcode set and to the shared-register-file convention of ISA §2.3. The wrapper must also supply the sticky `FPSR` exception flags (five bits, never trapping, read and written by `FSFLAGS`) and canonical-NaN results (`0x7FF8000000000000`, binary32 `0x7FC00000`, no payload propagation); hardware must produce the same bits as `sim64`. Directed rounding for arithmetic is undecided, so what to ask of HardFloat's rounding-mode input is open.

HardFloat's `mulAddRecFN` is the FMA module, so the one FP instruction that genuinely matters (ISA §9.7) comes with the decision to buy rather than build. Implementing a correctly-rounded fused multiply-add from scratch, with one rounding over the full 106-bit intermediate product, is the hardest single block in the machine, so the decision is not close.

**Buy the HDMI and scaler** on the DE10-Nano by using the MiSTer framework, at least until phase 7.

**Build the CPU, the MMU and the memory system.** These are the project.

**Language:** SystemVerilog for the datapath, with decode tables generated per §4. Vendor timing reports, formal tools and simulators all work best with it, and timing closure debugging is where you will spend the painful hours. Amaranth or Chisel would put a layer between the designer and the timing report, which is the wrong trade for a project whose hard part is `Fmax` and correctness rather than parameterization.

---

## 10. Schedule

For one experienced engineer working seriously part-time. Wide error bars, and phases 2 and 3 are the ones that historically double.

| Phase | Estimate | Notes |
|---|---|---|
| 0. Spec and tools | 5–9 weeks | larger encoding |
| 1. Integer core | 9–14 weeks | the bit unit and tag ops |
| 2. Exceptions | 6–11 weeks | the `MBLK` progress category and its test suite |
| 3. MMU | 7–11 weeks | `MT` and `DMW` |
| 4. Memory system | 4–8 weeks | |
| 5. Floating point (integrating HardFloat) | 4–7 weeks | FMA and the classify/min/max set |
| 6. Kernel bring-up | 8–16 weeks | |
| **to a booting system with FP** | **~10–19 months** | |

Most of the phase 2 estimate is the `MBLK` verification suite in §7 rather than the hardware, which is three counters. That ratio is what ISA §1.1(b) means by a bounded, written-down cost.

Phase 6 is the widest because it is not really a hardware phase. It is a compiler backend, a libc, and a port — and the compiler backend is the item most likely to be underestimated. A [pcc](https://github.com/moebiusV/pcc) back end exists (`arch/pdp64` in moebiusV/pcc), and compiled C runs under `sim64`; see risk 1. Facet and the V7 translation work will both want to target the machine and have no code generator for it.

---

## 11. Risks, in order

1. **The compiler backend.** A pcc back end for pdp64 exists and compiled C runs under `sim64`. On the 841-file fair corpus it produces 1.03 times amd64 and 1.04 times aarch64 in instructions and 0.97 and 0.89 times in bytes, with instruction lengths 2/4/6/8 bytes at 46.5/42.8/10.6/0.1 %. That answers the measured-length-distribution question; the scaled-index displacement width (ISA open item 1) is still open. Phase 6 needs a production compiler. Nothing in phases 0–5 produces one, and no schedule line above covers writing it. The target (LLVM, a Facet backend, or a small self-hosted generator) changes the ISA's ABI document and bears on ISA open items 1 and 6, the scaled-index displacement width and the measured length distribution, which only a code generator can answer.
2. **Timing closure on Cyclone V.** If the design lands at 35 MHz rather than 60, the fix is architectural — pipeline stages — and pipelining a machine with memory operands and precise faults is not a small change. Mitigate by leaving pipeline register boundaries in the RTL from phase 1, even when unused.
3. **Q64 exclusive access over AXI.** Open item 4 of the spec. The Unibus-derived `DATIP`/`DATO` locked read-modify-write is a *lock*; AXI exclusive access is a *monitor*. They are not the same primitive and the mapping is not clean. This needs settling before phase 4, not during it. The `_DB` barrier-fused atomics raise the stakes, because they assert an ordering guarantee that has to mean something on the actual interconnect.
4. **BRAM exhaustion at phase 7.** The caches, the TLB, the VIC-64X framebuffer, the `BLT64` scratch and the SID-64X voice state all want BRAM, and the DE10-Nano has about 5.5 Mb. Budget it before building the VIC, not after. §12 has the framebuffer numbers.
5. **`MBLK` cache pollution.** ISA open item 8. A large `MCPY` will evict the entire D-cache for data that is never read again. On an 8 KB cache this shows up immediately. The architectural fix is a non-temporal variant or a streaming `MT` value; the non-fix is deciding by length in the implementation, which is a performance cliff with no architectural visibility. Decide in phase 4, when the cache exists and the effect is measurable.
6. **Scope.** The specification covers a considerable amount of machine, including five instruction groups beyond the base set. The gate for phase 7 is that phase 6 boots, and that gate should be defended.

---

## 12. Graphics: the Blit terminal, and the GPU question

ISA §16 states the separation: graphics is Q64 device work and touches the processor only through the memory-type attribute, `FENCE`, and atomics. What follows is the device side.

### 12.1 The answer about a standard GPU

**Electrically possible, practically hopeless.** A Zynq UltraScale+ has a hard PCIe root complex, so a Q64-to-PCIe bridge would let an off-the-shelf card enumerate. Everything after enumeration is the obstacle. A modern discrete GPU needs PCIe configuration space, BAR mapping, MSI-X interrupt delivery, an IOMMU or at minimum scatter-gather DMA with pinned pages, a firmware blob loaded at init, power and clock sequencing, and a command submission model that none of the vendors document in a form that can be implemented against. The Linux driver for one of these is six figures of lines, and most of its knowledge is not in any specification.

The project's entire remaining budget would go into a driver for hardware whose programming model has to be reverse-engineered, in order to run a graphics stack that does not exist on this machine. The answer is no, and it should be given early.

The Cyclone V and Zynq 7020 do not have the hard PCIe to make even the electrical part straightforward, so on the phase 1 board the question does not arise.

### 12.2 What is right instead: `BLT64`

Pike's Blit has the right architecture for this machine: a framebuffer in the address space, plus a bitblt engine that does rectangle copies with raster operations. That pairing made the Blit, the Amiga and every 1980s windowing system fast enough to be pleasant.

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

- **Map the framebuffer with `MT = 01`** (normal uncached) or the CPU's writes will sit in the D-cache while the raster engine scans out stale memory. The `MT` field of the ISA exists to prevent this bug.
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

So anything above a text console or a small bitmap lives in HPS DDR, reached through the FPGA-to-SDRAM ports, with BRAM used as a scanout line buffer of a few KB. The MiSTer cores do the same, so the pattern is proven on this board. Budget BRAM for caches, the TLB and line buffers; budget DDR for pixels.

### 12.4 If 3D or compute is wanted later

Not a GPU. A small array of fabric cores with local memory, fed by a command FIFO from Q64 — which is the dedicated-hardware-per-function model taken from Chuck Moore's GA144 and MuP21. Each core does one thing with its own memory and is fed work rather than sharing an address space.

That model also absorbs the other coprocessor the ISA defers to it: ISA §4.6.2 declines the ternary 2-bit dot product on the grounds that wide data-parallel work belongs off the scalar core. The same FIFO-fed array serves both, and building it for one workload provides the other.

The sequence is: `BLT64` in phase 7, because it makes the machine usable; the array later, if there is a workload that needs it. A 2D blitter is a known quantity with a forty-year track record. A home-grown shader array is a research project.

---

## Resource notes for later additions

The estimates in §2 do not include the items below. All figures are estimates; none is a measurement.

- **FP exception flags** (`FPSR`, `FSFLAGS`): a five-bit sticky register that is part of the thread context and is OR-ed by every FP operation. It adds state to the FPU and the context switch path and a read/write port. No LUT figure.
- **`FRINTDA`, `FCVTDQU`, `FCVTQUD`**: extra rounding and conversion cases in the FPU. No LUT figure.
- **Canonical NaN results**: small extra logic on FP result paths. No LUT figure.
- **`ABS`, `MIN`, `MINU`, `MAX`, `MAXU`**: 150-250 LUTs, reusing the negate path and the compare of `SUB`/`CMP` with a 64-bit select. Not in the §2 table.
- **`SET cc, rd`**: one `AESC` sub-opcode that turns the branch-condition logic into a register write. Not in §2; no LUT figure.
- **`SOP`, `SYS` and `BESC` decode** (`PUSHM`/`POPM` in `SOP`, the `TRAP`/`TRAPL` split, `SYS` classes, `RORI`): the decoder structure of §2 ("mostly wires") is the thing to re-check; no figure.
- **Half precision (`binary16`)**: proposed, not decided. Conversion only is about 500-1,000 LUTs and full arithmetic about 2,000-3,500 LUTs. Neither is in the §2 table.
- **Directed rounding for FP arithmetic**: undecided. Depending on the option chosen (a static rounding field, a mode register, or more opcodes) the FPU decode or the opcode map changes. No figure.
- **Opcode map**: page 1 has 58 assigned opcodes, with `0x23` the spare ALU slot and `0x2B`-`0x2F` reserved (`0x28`-`0x2A` are the `CBCC` forms), plus the second page of ISA §4.18 (45 of 64 defined). The decoder gains a page select after `len`. No LUT figure; the counts matter for spare-slot arithmetic.
- **Measured instruction lengths**: the compiler-side findings in risk 1 feed the fetch-buffer and cache assumptions of §3 and §8; no hardware figure.
