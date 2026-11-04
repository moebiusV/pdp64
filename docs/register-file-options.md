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
