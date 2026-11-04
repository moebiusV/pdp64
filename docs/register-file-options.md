# Register file options: 32 registers, and 128-bit registers

[← pdp64 index](../README.md)

For the author's annotation. This answers two questions asked on [`crypto-secure-core.md`](crypto-secure-core.md): what 32 registers would do to the opcode layout, and what 128-bit registers would cost. Priorities are those of errata 83.

## 1. Thirty-two registers

**The layout today.** A one-parcel instruction (2 bytes) is exactly full:

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+-----+-----------------+-----------+-----------+
| len |     opcode (6)  |    reg    |    low    |
+-----+-----------------+-----------+-----------+
   2          6              4           4        = 16 bits
```

`reg` and `low` are 4-bit register fields. Page 2 (`len = 11`) has the same shape (`pdp64-isa.md` section 3.1.2). In a two-parcel memory instruction parcel 0 holds `reg` and a 4-bit mode, and parcel 1 holds a 4-bit `rm` and a 12-bit displacement.

**With 32 registers** each register field is 5 bits. A one-parcel register-to-register instruction then needs 2 + 6 + 5 + 5 = 18 bits, which is 2 more than a parcel holds. A two-parcel memory instruction needs 17 bits in parcel 0 (one over) and loses a displacement bit in parcel 1 (±1 KB instead of ±2 KB).

**Does it spill the one-parcel instructions? Yes, a lot.** In the measured corpus 46.5% of instructions are one parcel (2/4/6/8 bytes at 46.5/42.8/10.6/0.1 %, before errata 31 removed the 8-byte form; `README.md`, `pdp64-fpga-plan.md`).

| Way to make room | What it does | Cost |
|---|---|---|
| A. Shrink the opcode field to 4 bits | Frees 2 bits. | Only 16 one-parcel opcodes, against the 40 or so in use; breaks the rule that the opcode sits at the same place in every length. |
| B. One-parcel forms name only `R0` to `R15` | Registers `R16` to `R31` appear only in longer forms. | A value kept in a high register costs 2 more bytes per use; compilers would put hot values low. The least bad option (RISC-V's compressed set and Thumb do this with 8 registers). |
| C. Every register-to-register instruction becomes two parcels | Full 5-bit fields everywhere. | Average instruction length goes from about 3.3 bytes to at most about 4.2, up to +28% code size (an upper bound: not every one-parcel instruction names two registers). |
| D. 6-bit register fields in a 4-byte base format | A different ISA. | Not a modification. |

**What it would buy.** Fewer spills. The compiler output with 16 registers is already 1.03 times amd64's instruction count (amd64 has 16) and 1.04 times AArch64's (31 general registers), in 0.97 and 0.89 times the bytes (`README.md`). That puts an upper bound of a few percent on the instructions that more registers could remove, and the comparison includes other differences between the machines.

**Against the priorities.** Priority 2 (fewer instructions executed): a gain of at most a few percent. Priority 3 (encoding): a loss of 0 to 28% in bytes fetched, depending on the option. Priority 4: a register file twice the size, and a wider forwarding network in an out-of-order core. The first gain is small and the other three are costs.

**A cheap experiment before deciding.** Let the pcc back end allocate from 32 virtual registers (no encoding) and count the spill instructions it no longer emits. That gives the real upper bound on the benefit.

**Recommendation.** Stay at 16. Revisit only if the experiment shows the spills are more than a few percent of executed instructions. The reason the layout stops at 16 is not gate cost, as you said; it is that the parcel is already full, and every way of making room trades fetched bytes for a small number of spills.

**Your annotations:**


i agree we should test this with pcc and even with llvm for spills before deciding, but how is htis for an option: remove the 2 leading len bits and give them to the opcode; then have one opcode for "2 parcels" and another opcode for "3 parcels" then that still leaves room to put more opcodes in single parcel format, no?

&nbsp;

## 2. 128-bit registers

**What it means.** Each of the 16 registers holds 128 bits. Pointers and ordinary integers stay 64 bits (the data model stays LP64), so most values use half a register.

| Area | Effect |
|---|---|
| Register file | About 1,000 more flip-flops: small. |
| Datapath | The read and write ports and, in an out-of-order core, the forwarding paths double in width, which is where the area, power and timing cost falls. A 128-bit multiplier is four times a 64-bit one, so 128-bit multiply would stay a pair of 64-bit operations. |
| The rule "a register is always written in full" | A 64-bit operation must then define all 128 bits (extend the result) or the ISA grows a width dimension (another set of opcodes, or a mode). That is the problem that ended the 32-bit profile. |
| Context | State doubles: 256 bytes for the registers instead of 128 in every exception frame, signal frame, `setjmp` buffer and `PUSHM`/`POPM`. System-call entry and the context switch, both hot paths, save twice as much. |
| Memory | New 128-bit load and store (16-byte aligned) and, free of charge, a 128-bit compare-and-swap (decision P8). |
| Who benefits | `__int128`, AES (a block in one register), 128-bit atomics, bignum, GHASH. A small set of kernels. |
| Who pays | Every program, in context-switch and forwarding width. |

**What it really is.** A 16-entry SIMD register file with the vector instructions left out. Errata 59 decided against a SIMD register file, in favour of memory-mapped devices. Pairing two 64-bit registers gets the benefit where it is needed, which is what `crypto-secure-core.md` does for AES: a block in flight uses three registers.

**Against the priorities.** Priority 2: helps a few kernels, none of the general code. Priority 4: costs width everywhere. Priority 1: more state to save and clear, more to get wrong. The benefit is local and the cost is global.

**Recommendation.** Keep 16 registers of 64 bits and use register pairs for 128-bit quantities. If 128-bit atomics matter, add the double-width compare-and-swap (P8) on a register pair.

**Your annotations:**

i agree about keeping the registers 64 bits; we may expand to 32 regs. evaluate.

&nbsp;

## 3. Replies to the annotations

### 3.1 Giving the `len` bits to the opcode

**The proposal.** Remove the 2-bit `len` field, make the opcode 8 bits, and let the opcode itself say how long the instruction is (one opcode for "two parcels", another for "three"), which leaves room for many more one-parcel opcodes.

**What it does to the bits.** Moving the two `len` bits into the opcode gives `opcode(8) | reg(4) | low(4)`. The register fields stay 4 bits, so it does **not** help 32 registers: 8 + 5 + 5 is 18 again.

**What it does to opcode room.** Today a one-parcel instruction can use any of 64 page-1 opcodes with `len = 00` and any of 64 page-2 opcodes (`len = 11`), 128 in all, of which page 2 has 19 free. With the length inside the opcode there are 256 values in total, but every operation that exists in several lengths needs one opcode per length (`ADD` as register-to-register, as a short memory form, as a long memory form). The total stays about the same as today's 64 × 3 + 64, so the gain is a re-labelling and not new room. The fetch path also changes: today the length is two bits read straight into a counter; it would become a small lookup on the 8-bit opcode (a few dozen gates, but on the critical path).

**Verdict.** It trades a simple, fast length field for a lookup and gains no registers. It is not the way to 32 registers. (It could still be the way to more one-parcel opcodes, if page 2 runs out; 19 slots are free there.)

### 3.2 What 32 registers would actually take

The length information has to live somewhere, but it need not use two bits for every instruction. A **length-prefix code** (the idea behind UTF-8) spends 1 bit on the commonest case:

| Form | Layout (16-bit parcel 0) | Primary opcodes | Registers |
|---|---|---|---|
| One parcel (about 46% of instructions) | `0 | op(5) | reg(5) | low(5)` | 32 | 32 |
| Two parcels, parcel 0 | `10 | op(5) | reg(5) | mode(4)` | 32 | 32 |
| Two parcels, parcel 1 | `rm(5) | disp(11)` | | displacement ±1 KB (was ±2 KB) |
| Three parcels | `11 | op(5) | reg(5) | mode(4)`, then `rm(5) | disp(27)` | 32 | 32 |

The one-parcel instructions keep their size. The two-parcel instructions keep their size and lose one displacement bit.

**What it costs.**

1. *Half the primary opcode space.* The opcode shrinks from 6 bits to 5, so 32 top-level opcodes instead of 64. The 58 assigned today do not fit. The rarer ones move into escape groups, where each costs an extra parcel (priority 3), and branches (16 conditions) alone would take half the new map unless they move.
2. *Displacement:* 11 bits in the two-parcel forms. The corpus measurement of how many displacements need 12 bits decides whether that matters.
3. *A rewrite of the opcode map,* the grammar, `as64`, the QEMU and `sim64` decoders, the LLVM tables and every test.

**What it buys.** Fewer spills: the compiler already produces 1.04 times AArch64's instruction count with 16 registers against its 31, so the ceiling is a few percent of executed instructions.

**The measurements that decide it,** all cheap, none requiring the redesign:

1. Spills removed when pcc (and then LLVM) allocate from 32 virtual registers. This is the real ceiling on the benefit.
2. For each one-parcel mnemonic, its share of executed instructions. If 32 opcodes cover about 95%, the primary map can hold the one-parcel set.
3. The share of two-parcel memory instructions whose displacement needs 12 bits.

**Recommendation.** Do not change the encoding yet. Run the three measurements; if the first shows more than about 5% of instructions are spills, design the prefix-code map as a proposal and cost it with the second and third. Until then the ISA stays at 16 registers, which keeps open the decision to go to 32 later at the price of a rewritten map.

**Your annotations:**

&nbsp;

### 3.3 `opcode(6) | reg(5) | reg(5)`, with opcode values that mean "2 parcels" and "3 parcels"

**The layout.** Drop the `len` field. A one-parcel instruction is `opcode(6) | reg(5) | reg(5)`, which names 32 registers in 16 bits. Some of the 64 opcode values are length escapes: they mean the instruction continues into 2 or 3 parcels, with its registers in the same two fields of parcel 0.

**What the escape costs.** A longer instruction still has to say what it is. Its operation is either in the escape value itself or in a later parcel. For a memory instruction (operation 6 bits, register 5, mode 4, register 5, displacement *d*) the parcels hold 20 + *d* bits, and the escape takes 6 of parcel 0's 16 bits:

* with **one** escape value for 2-parcel instructions, the operation moves wholly into parcel 1, leaving a **6-bit displacement** (±32 bytes);
* with **16** escape values, 4 bits of the operation ride in the escape value and the displacement is **10 bits** (±512 bytes);
* with **32** escape values, it is **11 bits** (±1 KB).

Each escape value spent on a longer form is one fewer opcode for one-parcel instructions. The balance is:

| Escape values for 2-parcel forms | Displacement (2 parcels) | One-parcel opcodes left (if 8 values go to 3-parcel forms) |
|---|---|---|
| 1 | 6 bits | 55 |
| 4 | 8 bits | 52 |
| 16 | 10 bits | 40 |
| 32 | 11 bits | 24 |
| Today (`len` field, 2 bits) | 12 bits | 64 on page 1, plus 64 on page 2 |

**The length decode is cheap.** Put the escape values in aligned ranges (for instance the top three bits of the opcode choose one, two or three parcels) and the length is read from three bits of parcel 0, as it is from `len` today. No lookup table is needed.

**What it buys and costs.**

* *Buys:* 32 registers in every form, no `len` field, and a clean, uniform one-parcel format.
* *Costs:* about 2 bits of displacement in the two-parcel forms (at 16 escape values), and a one-parcel opcode set cut from 128 slots to about 40. That is the real price. The 45 defined page-2 forms exist to put the commonest operations in two bytes (`README.md`), and the one-parcel page-1 forms are about 30 more; roughly 75 forms would compete for 40 slots, and the losers become 4-byte instructions.

**It is the same trade as the prefix code of section 3.2,** reached more simply: each register bit gained costs one opcode bit and one displacement bit, wherever the length is written. The question the measurements answer is whether the spills that 32 registers remove are worth losing half the one-parcel opcodes.

**Your annotations:**

&nbsp;

### 3.4 Your design as stated: two escape opcodes

**The design.** Of the 64 opcode values, two are escapes. `ESC2` means "the real opcode is in the next parcel and this is a 2-parcel instruction"; `ESC3` means the same for 3 parcels. The escape parcel is `ESC | reg(5) | reg(5)`, so the registers sit in the same place as in a one-parcel instruction. The next parcel starts with the real 6-bit opcode, taken from its own map.

```
one parcel:     opcode(6)  reg(5) reg(5)                       62 opcodes
two parcels:    ESC2(6)    reg(5) reg(5) | opcode(6) mode(4) disp(6)      64 opcodes of its own
three parcels:  ESC3(6)    reg(5) reg(5) | opcode(6) mode(4) disp(6) | disp(16)   64 opcodes of its own
```

Counting parcels from 1, the escape is parcel 1 and the real opcode lives in parcel 2 (the author's wording); the diagram's second parcel is that parcel. The registers sit in parcel 1 at the same bit positions as in a one-parcel instruction, so the register file can be read from parcel 1 before parcel 2 has been decoded; both parcels are in the same fetch group, so the operation is known one decode step later at no extra fetch.

**What it gains.**

* 32 registers in every form.
* No `len` field, and the length is decoded from a single 6-bit comparison on parcel 0 (two values), cheaper than the range decode of section 3.3.
* Opcode room: 62 one-parcel opcodes, and the two long forms each get a **separate** 64-opcode map instead of sharing one map with the one-parcel forms. That is about 190 opcodes in all, against 63 assigned in the shared map today.

**What it costs.**

* **The displacement of a two-parcel instruction is 6 bits (±32 bytes), where today it is 12 bits (±2 KB).** A local variable or a struct field more than 32 bytes from its base needs the three-parcel form, 2 bytes longer. The three-parcel displacement is 22 bits (±2 MB), where today it is 28.
* The one-parcel set shrinks from 128 slots (page 1 and page 2) to 62.

**Where the answer lies.** Almost all the cost is the share of memory instructions whose displacement is more than 32 bytes. In the corpus 81,244 instructions use a base register, 79,954 of them in the 4-byte form (`docs/codegen-data/shapes_pdp64.csv`), so these are 22% of all instructions. If most have displacements within ±32 bytes the design is nearly free; if most are beyond, it adds 2 bytes to a fifth of the instructions. That histogram is a measurement to take from the assembled corpus.

**Measurements, updated.**

1. Spills removed by 32 virtual registers (running).
2. The displacement histogram of the base-register instructions: the share within ±32, ±128, ±512 and ±2048 bytes.
3. The share of executed one-parcel instructions by mnemonic: do 62 opcodes cover the one-parcel set?

**Your annotations:**

&nbsp;

### 3.5 The second parcel in detail, and the measured displacement overflow

**The measurement.** The 841-file corpus compiled with the 16-register pcc back end, 81,051 memory operands with a base register (the scaled-index form, 1,516 operands, is counted apart). The share whose displacement fits:

| Displacement field | Fits | Overflow to a third parcel | Added bytes (2 per overflow) | Share of code bytes |
|---|---|---|---|---|
| **6 bits, bytes, signed** (±32) | 60.3% | 32,147 | 64,294 | **+5.2%** |
| 7 bits, bytes, signed | 74.4% | 20,752 | 41,504 | +3.3% |
| **6 bits, scaled by operand size, signed** | 84.0% | 12,975 | 25,950 | **+2.1%** |
| **6 bits, scaled by operand size, unsigned** (0 to 63 × size) | 88.7% | 9,194 | 18,388 | **+1.5%** |
| 11 bits, scaled, signed | 98.7% | 1,057 | 2,114 | +0.2% |
| 12 bits, bytes, signed (today) | 98.4% | 1,294 | | |

Two facts make scaling free: **every displacement in the corpus is a multiple of its operand size** (data is naturally aligned, errata 82), and **only 221 of the 27,405 stack-pointer and frame-pointer displacements are negative**. A quad (8 bytes) at displacement 8 is stored as 1; the assembler scales it, the hardware multiplies by the size the opcode implies (1, 2, 4 or 8). The code bytes are the whole corpus's 1,244,148 bytes (`lengths_pdp64.csv`); the percentages are before any other change.

**Layout of a two-parcel memory instruction** (bit 15 first; parcel 1 is the escape, parcel 2 the real instruction):

```
parcel 1:   15..10  ESC2          6   length escape: "2 parcels, real opcode follows"
             9..5   reg           5   the data register (destination or source)
             4..0   rm            5   the base register

parcel 2:   15..10  opcode        6   the real operation, from the 2-parcel map
             9..6   mode          4   addressing mode (table below)
             5..0   disp          6   displacement, scaled by the operand size
```

The three-parcel form is the same two parcels followed by a third that extends the displacement: `parcel 2 [5..0]` is the high 6 bits and `parcel 3` the low 16, so 22 bits (scaled: ±2 M entries).

**What each mode does with the fields.**

| Mode | Meaning | `rm` | `disp` field |
|---|---|---|---|
| `0000` | `d(Rn)` base plus displacement | base | 6-bit displacement |
| `0001` to `0100` | scaled index `(Rn)(Rx*s)`, one mode per scale 1, 2, 4, 8 | base | index register `Rx` in `disp[5..1]`, `disp[0]` unused (no displacement; a displacement needs the 3-parcel form) |
| `0101` | `d(PC)` PC-relative | **unused** | `disp` plus the 5 `rm` bits: 11 bits |
| `0110` | immediate | **unused** | 11 bits |
| `0111` | absolute | **unused** | 11 bits |
| `1000` | `d(DP)` direct page | **unused** | 11 bits |
| `1001` | `(Rn)+` post-increment, stride in `disp` | base | stride |
| `1010` | `-(Rn)` pre-decrement, stride in `disp` | base | stride |
| `1011` | `d(SP)` stack-relative | **unused** (SP implied) | 11 bits |
| `1100` to `1111` | reserved: user-qualified forms (item 18), deferred loads (item 10) | | |

The mode numbering is a proposal; the present map (ISA section 5) puts base at 0, scaled index at 1, PC-relative at 2, direct page at 3, immediate at 4, absolute at 5, post-increment at 6, pre-decrement at 7 and reserves 8 to 15.

**Ways to stop the overflow, each from the table above.**

1. **Scale the displacement by the operand size.** 6 bits then reach 63 entries: 88.7% instead of 60.3% (+1.5% code instead of +5.2%). Costs a 2-bit size decode from the opcode (already known) and a shifter on the address adder. Free in data (all multiples).
2. **Make the stack-pointer form implicit.** 27,405 of the 81,051 operands (34%) are relative to SP or FP. A mode that fixes the base to SP frees the 5 `rm` bits for an 11-bit displacement: scaled, that reaches 99.7% of those. One extra mode (`1011`), no extra opcode.
3. **Reuse the `rm` bits where there is no base register.** PC-relative, immediate, absolute and direct-page modes name no register, so their 11-bit displacement uses the `rm` field as well. The register file is not read for them, so reading registers early from parcel 1 loses nothing.
4. **Narrow the mode field.** The user-qualified and deferred-load variants (modes 8 to 15) could become opcodes in the 2-parcel map instead of modes, leaving 8 modes in 3 bits and giving the displacement a 7th bit.
5. **Pick a signed or unsigned displacement per base.** Unsigned for SP-relative (almost never negative), signed for other bases (negative offsets are common in structure walks).

Taken together (1 and 2), the overflow falls to about 1% of the memory operands: the 32 registers cost about 0.2% of the code in displacement overflow. The unresolved cost is then the one-parcel opcode room (62 against today's 128 slots), which the third measurement answers, and the spills the second measurement removes.

**Your annotations:**

&nbsp;

## 4. Results of the measurements

### 4.1 Spills removed by 32 registers ([`spill-experiment.md`](spill-experiment.md))

pcc with 32 registers (static counts, 841 files, the new registers are used):

| | 16 registers | 32 registers | Change |
|---|---|---|---|
| Instructions | 338,313 | 333,872 | **−4,441 (−1.31%)** |
| Stack-pointer and frame-pointer loads and stores | 23,962 | 15,683 | **−8,279 (−35%)** |
| `movq reg,reg` | 46,197 | 50,477 | +4,280 |
| Callee-saved registers saved | 23,476 | 26,442 | +2,966 |

A 24-register machine gets 84% of the instruction saving (−1.11%). The effect is concentrated: zlib −3.3%, bearssl −3.0%, lz4 −3.0%, lua −1.6%, mbedtls −1.1%, and the large straight-line test programs near zero. The saving is small in instructions because the registers that replace the spills cost register moves and more callee-saved saves; the saving in **memory accesses** is larger, because the stack accesses removed are a third of all of them. Limits: static not executed counts; the result depends on pcc's allocator, and a better allocator (LLVM's, once it generates code) spills less at 16 registers and would gain less; no distinction between spills and named locals.

### 4.2 What the encoding would cost, against the actual instruction lengths

The baseline has 55.4% of instructions in 2 bytes, 29.0% in 4 and 15.6% in 6, and **86% of frame loads and 83% of stores are already 2-byte forms** (a one-parcel stack-relative form exists). The design of §3.4 as first drawn would lose those. Modelled over the 71,289 instructions with a base-register operand (21% of all instructions), assuming the 1,083,870 bytes of the baseline:

| Design | Added code bytes |
|---|---|
| §3.4 as drawn: only `(Rn)` is one parcel, displacement 6 bits unscaled | **+10.5%** |
| plus scaling, a one-parcel stack form `opcode(6) reg(5) disp(5)` (32 entries) and an 11-bit stack-implicit two-parcel mode | +1.4% |
| a one-parcel stack form that reaches 128 entries (four opcode banks, about 32 of the 62 one-parcel opcodes) | +0.85% |
| the same with a 7-bit two-parcel displacement (narrower mode field) | +0.46% |

Against that stands the saving the experiment estimates: about −1.0% in bytes (a rough estimate: it assumes the removed instructions are 2-byte forms that fit the new encoding).

**Reading.** On code size, 32 registers are about break-even at best (−1.0% saved, +0.5% to +0.9% spent) and spend most of the one-parcel opcode room. What they remove is memory traffic: roughly a third of the stack loads and stores. Whether that matters turns on the executed counts, which these static counts do not give.

**Recommendation.** Stay at 16 registers now. Revisit if (a) executed-instruction counts from `sim64` on benchmark programs show the frame traffic is a larger share in hot loops than the static count, or (b) LLVM's allocator, when it generates code, shows a different picture. Neither needs a change to the encoding to measure: both can use the 32-register assembly text.

**Your annotations:**

&nbsp;

### 4.3 Executed counts under `sim64` ([`dynamic-spill-estimate.md`](dynamic-spill-estimate.md))

Six large programs ran under an instrumented copy of `sim64` with the 16-register pcc, each producing output identical to a host `gcc` build: lz4, zlib, Lua 5.4.7 running a script, and three BearSSL kernels (hashes; AES, ChaCha20-Poly1305, GHASH; curve25519 and P-256). They execute 755.8 million instructions. The 32-register code cannot be assembled, so the saving is **estimated** by weighting the static per-function difference by how often each function ran.

| | Static (841 files) | Executed (six programs) |
|---|---|---|
| Stack loads and stores, share of instructions | 7.1% | **10.1%** |
| Register moves | 13.7% | 7.1% |
| Instructions removed by 32 registers | 1.31% | **4.3%** (2.1% to 6.5% per program; 4.9% by the uniform estimator) |
| Stack loads and stores removed | 35% | **about 55%** (bounds 31% to 72%) |
| Executed length mix, 2 / 4 / 6 bytes | 55 / 29 / 16 | 54 / 35 / 11 (3.13 bytes per instruction) |

The saving is concentrated in hot loops (zlib `longest_match`, the LZ4HC match finder, `luaV_execute`, the Montgomery multiply), where 32 registers remove almost all the stack traffic.

**How far to trust it.** The estimator was tested on a change that can be run: removing two callee-saved registers (11 allocatable) and predicting the 11-to-16 saving. Measured 7.75%, predicted 9.17%; per program the prediction was off by −32% to +54%, and the measured value always fell inside the bounds. Read 4.3% as good to about ±50%. Loop depth of the removed instructions is not identified, the byte saving is not estimated, and the result depends on pcc's allocator.

**Reading against the priorities.** Priority 2 (fewer instructions executed, so fewer fetches and fewer memory accesses) now favours 32 registers: roughly 4% fewer executed instructions and half the stack traffic, against a static code growth of +0.5% to +0.9% in the best encoding (§4.2). The static and dynamic pictures differ because the instructions removed sit in hot loops while the displacement overflow falls on cold code. Neither is final: the 32-register code has not been run, and the allocator is pcc's.

**Your annotations:**

&nbsp;

## 5. Trailing literals: a 16, 32, 48 or 64-bit field after the instruction, not counted in its parcels

**The proposal (the author's).** An immediate of 16, 32, 48 or 64 bits sits immediately after the instruction and is not counted in the parcels the instruction takes. The instruction proper stays 1 to 3 parcels; a literal of 1, 2, 3 or 4 parcels follows.

**One way to lay it out.** For an instruction with an immediate source and a register destination the second 5-bit register field of the one-parcel format is free:

```
opcode(6) | rd(5) | s(1) c(4)
```

* `s = 0`: `c` is an inline immediate, 0 to 15, and the instruction is one parcel (2 bytes), as today's 4-bit immediates.
* `s = 1`: `c`'s low 2 bits give the literal size (16, 32, 48 or 64 bits) and the literal follows: 4, 6, 8 or 10 bytes in all.

No extra opcodes are needed: every immediate-taking instruction (53 of the 234) uses the same field. `MOVQ #imm64, Rd` is the same instruction with the 64-bit size.

**What it fixes** (items from [`layout-fit-analysis.md`](layout-fit-analysis.md) section 4):

| Misfit | Today's repair | With trailing literals |
|---|---|---|
| 5. Immediates 16 to 11 bits at two parcels (4,432 sites) | three parcels, +6,120 bytes | 4 bytes, as today: the 16-bit literal is one parcel after a one-parcel base. **0** |
| 6. Immediates beyond 27 bits (1,204 sites) | no form; four parcels, +2,408 | the 32 or 48-bit size: 6 or 8 bytes, as the four-parcel repair, but a regular mechanism |
| 14. `MOVQL #imm64` | five parcels, impossible with only `ESC2`/`ESC3` | the 64-bit size, 10 bytes, no new opcode |
| 4. PC-relative reach (19,183 sites, +20,658 unrepaired) | dedicated opcodes for `CALL label` and `LEA label` | a 16 or 32-bit trailing displacement after a one-parcel base: reach ±64 KB or ±8 GB (in parcels), 4 or 6 bytes |

The same mechanism can carry an absolute address (32, 48 or 64 bits) and a long displacement for a memory operand or a branch.

**What it does not fix.** The 6-bit base displacement in the two-parcel memory form (items 1; +10,906 and +942 bytes) unless that displacement too moves into a trailing field, the mode-field budget, the `PUSHM`/saved-state masks and the `cbCC` condition slots (the condition has no room in a base parcel with a register, a 5-bit immediate and no field for a 4-bit condition unless it rides in the trailing field).

**What it costs.**

1. *Longest instruction:* a three-parcel base plus a four-parcel literal is 14 bytes. A 12-byte instruction at a 2-byte offset can span three aligned quads, so the fetch buffer is three deep instead of two.
2. *Where the length is known.* For a one-parcel base the size code is in parcel 0, so the length is known at once. For a two-parcel base whose mode and size code are in the second parcel, the length is known one parcel later. Keeping the size code in the escape parcel (extra escape values) avoids that at a cost in escape slots.
3. *The "no instruction exceeds a `uint64_t`" rule* (already waived for `MOVQL`) is waived for every literal-bearing instruction; errata 31's cap applies to the instruction proper.
4. *A literal can be reached by jumping into the middle of an instruction.* Landing pads (candidate 5) are the defence, as for `MOVQL`.

**Verdict.** It repairs the immediates, the 64-bit constant and the PC-relative reach with one regular mechanism and no extra opcodes, which are most of the cost items that the layout check found beyond the memory displacement. It does not by itself close the layout. The byte effect has not been run through the allocation model.

**Your annotations:**

&nbsp;
