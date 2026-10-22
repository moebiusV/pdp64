# DEC PDP-64

[← pdp64 index](../README.md)

**Digital Equity Collective's Pragmatic Digital Processor, 64 bit** — an update and refresh of the PDP-11 instruction set and architecture for the modern world.

**Revision 20, updated 2026-10-21 with the changes in CHANGES-SINCE-R20.md, and on 2026-10-22 with the second page.** Supersedes revision 19. The change of 2026-10-22 (errata 31) removes the fourth parcel, makes `len = 11` a second page of one-parcel instructions (§3.1.2, §4.18) and adds `CBCC` and `RORI32`; the text below describes the machine after it, and where an older figure survives it is marked as history.

The machine is **pdp64**. This document was written under the working name 11/64W; that name appears nowhere else in it except in the appendix. The text below is revision 20 with every change and decision made since applied in place, so a reader does not need a separate errata list to learn what the machine does; Appendix A lists each change in one line with its source. The original revision 20, unmodified and still under its working name, is in `docs/orig/` (`orig/11-64W-isa-r20.md`). Where a number in prose disagrees with the grammars `spec/pdp64-mnemonics.hbnf` and `spec/pdp64.hbnf.in`, the grammar is right.

**Revision 20 reallocates all sixty-four opcodes**, sorted by frequency and grouped by theme. §4.3 states the principle and §4.16 is the new map.

**The principle rests on one encoding fact.** An operation in a parcel-1 escape group can never be two bytes, because its sub-opcode lives in parcel 1 and parcel 1 only exists at `len ≥ 01`. Everything else about an escape group is identical — same modes, same displacement scaling, same operand positions. So **the only thing a top-level opcode buys is the one-parcel form**, and the question for every operation is not how important it is but whether its *common case is register-to-register*.

**Five groups demoted, and four of the five cost nothing at all:**

| Demoted | To | Cost |
|---|---|---|
| `ADDM` `SUBM` `BICM` `BISM` (was `0x20`–`0x23`) | `MESC` | none — a memory destination means `len ≥ 01` already |
| `FDIV` `FSQRT` | `FESC` | none — multi-cycle, rarely reg-reg |
| `MOD` `MODU` `MULHU` | `AESC` | none — already sub-opcodes, just in the wrong group thematically |
| `DIV` `DIVU` | `AESC` | a two-byte reg-reg divide. Accepted: compilers turn constant division into `MULH` plus a shift, so a real divide is rare |
| `ROR` | `BESC` | a two-byte register-count rotate. Accepted, and revision 16's justification for its ALU slot was simply **wrong** — crypto rotates by compile-time *constants*, which is a four-byte immediate form either way |

**One group added, `AESC` at `0x0E`**, which is net negative in opcodes: it costs one slot and lets `MOD`, `MODU` and `MULHU` leave `BESC`, where arithmetic never belonged.

**Nothing was promoted and nothing grew.** Reserved space went from **one scattered slot to eight contiguous** (`0x28`–`0x2F`), and the freed slots stay reserved rather than being filled — §1.2 rule 3.

**The layout now pays for itself in the decoder** (§4.3.1). The six parcel-1 escapes are contiguous at `0x0C`–`0x11`, so "do I read a sub-opcode from parcel 1" is one range comparison on bits 13..8 rather than six matches. The three reg-as-sub-opcode groups sit adjacent at `0x12`–`0x14`. Every other run's low bits are the operation select, wired straight to the function mux — which is §9.5's discipline made visible in the numbering rather than only in the field layout.

**Open item 2 is resolved and replaced by a rule:** a top-level opcode is for an operation whose common case is register-to-register; everything else goes to an escape group.

**Carried from revisions 18 and 19:** §1.2's decision order; `XFER` holding `JMPI`, `CALLI` and `JTAG`; §19, the position-independent-code audit — PIE is cheap here, PIE data access is *shorter* than absolute, and veneers never exist (restated for the 32-bit forms in §19.2 and §19.4 after the change of 2026-10-22); plus `DP` documented as the user-mode thread pointer (§2.2, §19.3).

Nothing else changed from revision 18, whose changelog follows.

---

**Revision 18 changelog. Superseded revision 17.**

**Revision 17 prunes.** The PDP-11 instruction set is a source, not an obligation, and several instructions were being carried for continuity rather than use. Auditing for that found one duplicate hiding a genuine hole.

**Fixed: `MULU` was a duplicate and `MULH` was missing (§4.2.2).** The low 64 bits of a two's-complement product are identical whether the operands are read as signed or unsigned, so `MUL` and `MULU` were the same instruction occupying two of sixteen ALU slots — while nothing in the architecture produced the *high* half, making 64 × 64 → 128 impossible and bignum multiplication, 128-bit fixed point and divide-by-reciprocal all unimplementable. `0x1F` is now `MULH`; `MULHU` goes to `BESC`; `MULU` is accepted as an assembler alias for `MUL`.

**Dropped: `IOT`, `EMT`, `WAIT`, `RESET` (§4.11.1).** `IOT` and `EMT` are `TRAP #n` at two particular vectors. `WAIT` is `WFE` with no second core. `RESET` is a bus-controller register write masquerading as an instruction, which §16 says is not the architecture's business. `BPT`, `RTT` and `SPL` look similarly redundant and are **kept**, each for a specific reason now written down — `BPT` must be the shortest instruction so a debugger can patch over any other, `RTT` sets `T` after the return so a debugger can step out of its own handler, and `SPL` leaves the condition codes alone where `MTPS` would not.

**Added: §4.14, assembler aliases.** `ROL rm, #n` assembles to `ROR rm, #(64−n)` — the complement is free at assembly time, so the mnemonic costs nothing to accept and there is no reason to make programmers do the arithmetic. Two rules keep this from becoming a shadow architecture: one mnemonic assembles to exactly one instruction (so `ROL rm, Rk` is rejected rather than quietly expanded), and the disassembler never prints an alias, so encodings round-trip.

No opcodes spent; one ALU slot recovered and immediately reused. Nothing else changed from revision 16, whose changelog follows.

---

**Revision 16 changelog. Superseded revision 15.**

**Revision 16 is a correction release**, prompted by the question of why the ALU group has `ROR` but not `ROL`. One rotate direction is sufficient and `ROR` is the right one to keep — §4.5.1 now gives both arguments — but the question exposed three defects:

- **`SOP` held `ASL` and `ROL`, the two left shifts**, with no `ASR` and no `ROR`, dropping two of the PDP-11's four single-operand shifts for no stated reason and contradicting the preference for right-direction shifts implicit in §4.2. `ROL` is removed and **`ASR`** takes its slot, giving the symmetric by-one pair.
- **No revision ever stated the carry semantics of any shift or rotate**, which left `ROL` ambiguous between a plain rotate and the PDP-11's rotate *through* `C`. §4.2.1 is new and states them, including the zero-count and count-≥-64 cases that x86 leaves undefined.
- **§13.5 claimed all four PDP-11 single-operand shifts were carried over unchanged.** They were not, and the rotate-through-carry difference was unrecorded. Corrected.

**Added: §4.6.4, `DSHR`** — a double-width funnel shift, x86's `SHRD` and ARM's `EXTR`. This is the right primitive for multi-precision shifting, at two instructions for any distance rather than one bit per instruction, and it is what makes rotate-through-carry unnecessary. It also subsumes `ROR` when both sources are the same register, which confirms the ordering: `DSHR` is the general operation and `ROR` is its one-register case, kept in the ALU group only for the two-byte encoding that crypto inner loops want.

No top-level opcodes spent; `DSHR` is a `BESC` sub-opcode. Nothing else changed from revision 15, whose changelog follows.

---

**Revision 15 changelog. Superseded revision 14 in full.**

**Register assignment changed.** `SP` is now `R14` and `FP` is `R13`, matching VAX; through revision 14 `SP` was `R6` as on the PDP-11. `R12` is *not* an argument pointer — VAX's `AP` serves `CALLS`/`CALLG`, which §11 rejects. §2.1 states what the change costs.

**Added**

- **§4.6.3, `CLMULL`/`CLMULH`** — carry-less multiply. Chosen over a `CRC` instruction because it is the primitive beneath every CRC polynomial, and also serves GF(2^k) erasure coding and AES-GCM. x86 and ARM each committed a CRC polynomial to their architecture; this does not.
- **§4.7.1, `MVAL`** — whole-buffer UTF-8 validation, plus **`MSCNN`**, the `SKPC` gap. Both are `MBLK` sub-opcodes costing no opcodes and almost no hardware, since they wire the §4.6.1 validity comparators to the existing block sequencer.
- **§17, symmetric multiprocessing.** The memory model is declared **sequentially consistent**, which is nearly free on a non-speculative in-order machine and saves software a permanent tax. Six `SYS` additions: `MFCPUID`, `ICINV`, `ICINVA`, `TLBSYNC`, `WFE`, `SEV`; `TLBI`/`TLBIA` are respecified as broadcasting. The absence of an I-cache invalidate through revision 14 was a hole — a Lisp runtime that compiles a function cannot work without it.
- **§18, a glossary**, because `MBLK`, `BESC`, SWAR and `Q64` were all used without ever being expanded.

**Reworked**

- **§6.1.1** now explains why the virtual address is 39 bits and not 40: 9 + 9 + 9 + 12 is what 4 KB pages and three levels produce, and reaching 40 would cost a whole extra walk level for one bit.
- **§9.7** is substantially longer, naming the two architectures that ever shipped hardware transcendentals, why neither was accurate, and the three-tier consensus that replaced them. ARM SVE's `FTMAD` is the one modern counter-example and it inverts x87's approach.
- **§9.8 is new**: why operand width, precision and rounding mode are in the instruction rather than a control register, where modern architectures differ, why they differ, and the one place the argument would reverse.
- **§11 and §14.1.1**: the "string" rejection was wrong from revision 8 and became visibly wrong at revision 13. Seven of VAX's ten character-string instructions are present; the rejection was always about `EDITPC` and packed decimal. NUL-terminated string instructions are newly and explicitly rejected, on memory-safety grounds.

**Carried from revision 14:** the `XNORPOP` rationale correction — the instruction does not serve sub-1-bit language models, because LittleBit's activations are FP16 and the inner loop is a conditional add rather than a popcount (§4.6.2).

---

**Revision 13 changelog, retained for provenance.**

---

**Revision 13 changelog. Superseded revision 12 in full.**

Revision 12 answered a wording complaint. Revision 13 answered a round of design questions, several of which found real holes. The changes were substantive.

**Restored or added**

- **§1.1, the exception rule.** Principles may be broken where the benefit is named and the mechanism that made the principle necessary is absent. Stated as a test, with the worked example below, so it does not become a licence for drift.
- **§4.6, `BESC`** — a bit and field manipulation group. `CLZ`, `CTZ`, `CLO`, `CTO`, `POPCNT`, `BSWAP`, `BITREV`, `EXTB`, `INSB`, `MOD`, `XNORPOP`, `UTF8LEN`, `UTF8DEC`, `UTF8ENC`. Revision 10's reorganization silently dropped `BSWAP`, `EXTB`/`INSB` and `MOD`; they are back, with company.
- **§4.7, `MBLK`** — block memory operations. `MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`. This is the granted exception to the one-memory-operand rule, and §7.5 is the new restart category it needs.
- **§4.8, `TAGOP`** — `BTAG` and `BNTAG`, branch on low-bit tag. Plus `JTAG` in `SOP`. These make §6.2's tagged pointers cheap to use rather than merely possible.
- **`SOB`** restored from the PDP-11, at the branch group's one free opcode. **`FMADDD`** and the rest of the FMA family added to `FESC` — their absence was the single worst gap in the floating-point set. **`ATOM`** expanded with barrier-fused variants.
- **§8.3, direct mapping windows**, taken from LoongArch. **§8.2** gains a memory-type field, whose absence would have been discovered by whoever first wrote to a framebuffer.

**Reworked**

- **§9.3** now treats the read-only-`R7` proposal seriously, and says what ARM32 paid for accepting it.
- **§9.6** gives the honest reason the parcel limit is four, which is not the reason revisions 10 through 12 gave.
- **§13** is a side-by-side comparison with the PDP-11 and VAX, at the encoding level.
- **§14** inventories the idioms lost, restored and replaced.
- **§15** records what was taken from LoongArch and what was declined.

**Dropped:** `SXT` and `SWAB` from `SOP`, both subsumed (§14.3).

Words are 16 bits. Longs are 32. Quads are 64. PDP-11 terminology throughout.

> A note on how this document is read against its companions. The implementation plan covers the FPGA build. The LB64 document covers the sub-1-bit inference accelerator, and is the worked example of §16 — a substantial Q64 device that needs no ISA change at all.

---

## 1. Design constraints

Ranked, because they conflict:

1. Low transistor count. A small ASIC or an FPGA soft core, not a superscalar.
2. Bounded fault surface — every instruction restartable with O(1) recorded state.
3. Pleasant in assembler. A PDP-11 programmer should recognize the language.
4. Good compiler target.
5. Code density.

Constraints 1 and 3 mostly agree, which is why this works at all. Where they disagree, 1 wins.

Four rules govern everything below:

> **Compatibility is conversion instructions, never mode bits.** (rev. 4)
>
> **At most one operand of any instruction may be a memory reference.** (rev. 8)
>
> **No instruction exceeds one `uint64_t`.** (rev. 10)
>
> **A register is always written in full.** (rev. 11)

### 1.1 When a rule may be broken

A principle held past the point where it costs more than it saves is an ideology, and the machines in §10 that failed did so from both directions — VAX from no principle, the pure RISCs from too much. The rule for departing from one:

> **An exception is admissible when (a) the benefit is named and concrete, (b) the cost is bounded and written down, and (c) the mechanism that made the principle necessary is absent from the exception.**

Clause (c) does the work. It is not enough that an exception be useful; the specific failure the rule was protecting against has to be structurally impossible in the exception.

The worked example is §4.7. VAX's `MOVC5` is the canonical argument for the one-memory-operand rule: it issues an unbounded number of memory references and needs hidden intermediate state plus `PSL<FPD>` to resume. The pdp64 block operations do the same job and are *not* that, because their operands come from registers and are consumed as progress. There is no hidden state to save, because the state is the registers, and they are already architectural. The mechanism is absent, so the exception is admissible. §7.5 writes down the cost.

Two rules have no exceptions, and the reason in both cases is that an exception would be invisible:

- **No mode bits.** Any exception reintroduces state that must be saved and restored across a context switch, and whose value changes the meaning of unrelated instructions. There is no bounded version of that. (The sticky floating-point status register `FPSR`, §4.10, is not an exception to this: it never changes what an instruction does, it only records what an instruction did.)
- **Natural alignment for quad accesses** (§7.4). Since §6.2 this is load-bearing for every tagged runtime, and relaxing it converts a trapped bug into silent corruption.

### 1.2 The decision order

§1.1 says when a principle may be broken. This says how to choose between two designs that both work. The tests apply in order, and an earlier one is not traded against a later one.

> **1. No strange side effects.** An instruction does what its name says and nothing else. Nothing is left in a register the mnemonic does not mention, no flag is set that the table does not list, no state persists that the next instruction can observe without asking. This is why §4.2.1 had to be written, why §9.8 refuses mode bits, and why `CALLI`'s operation order is specified in §4.9.1 rather than left to the implementation.
>
> **2. Do not displace an instruction into a longer encoding.** A new instruction may take a reserved slot. It may not evict an existing one into a form that costs more bytes, unless the evicted operation is rare enough that aggregate code size is unaffected. The test is frequency-weighted: moving something common from two bytes to four is a real regression, moving something rare is noise.
>
> **3. Occam. Do not multiply entities without benefit.** Prefer one instruction that covers three cases to three that each cover one, when they share their hardware. Prefer a sub-opcode in an existing escape group to a new top-level opcode. Prefer an assembler alias to an instruction. Count the gates and the verification surface, not just the opcodes.

**Revision 19 exists because revision 18 failed rule 2.** It evicted `COM` from `SOP` to make room for `JMPI`, taking one's complement from two bytes to four. `COM` is common enough that this was a genuine regression, and `0x0F` was reserved and available the whole time. Revision 19 puts `JMPI`, `CALLI` and `JTAG` in one group there (§4.9), restores `COM`, and leaves `SOP` with two free slots. (Those two slots were later taken by `PUSHM` and `POPM`, §4.5; `SOP` has none left.)

That grouping also satisfies rule 3 better than revision 18 did: the three instructions share one property — the next `PC` comes from the load-return path — so they share one decode comparison and one mux input instead of being three unrelated slots whose common hardware is invisible in the encoding.

**One known rule-2 exception stands.** Revision 16 displaced `ROL`-by-one out of `SOP`, making it a four-byte `ROR` alias. By the frequency test that is acceptable: rotate-by-one is rare in compiled code, the crypto uses rotate by compile-time constants other than one, and multi-precision shifting now uses `DSHR` (§4.6.4). Restoring it would recreate the left/right asymmetry §4.5.1 removed, so the two free `SOP` slots stayed free (until `PUSHM` and `POPM` needed them, §4.5) rather than being spent on `ROL` and `ROR` for symmetry's sake — which would be rule 3 violated to satisfy rule 2 on a rare operation.

---

## 2. Programmer-visible state

### 2.1 General registers

Sixteen registers, `R0`–`R15`, 64 bits each.

| Register | Role | Hardware knows? |
|---|---|---|
| `R0`–`R12` | general | no |
| `R13` / `FP` | frame pointer | **no** — ABI convention only |
| `R14` / `SP` | stack pointer | **yes** — three copies, kernel / supervisor / user, switched with the mode |
| `R15` | general | no |

**`SP` is `R14` and `FP` is `R13`, matching VAX.** Changed in revision 15; through revision 14 `SP` was `R6` as on the PDP-11.

What this costs, stated plainly: `-(SP)` and `(SP)+` still assemble and still mean push and pop, because `SP` is a register *name* and the mode syntax is unchanged. What breaks is hand-written PDP-11 code that spells the stack pointer `R6`, which now silently means an ordinary register. The assembler should warn on `-(R6)` and `(R6)+` for exactly this reason. Since binary compatibility was abandoned at revision 8 and the surviving claim is mnemonic compatibility — instruction names and operand syntax, not register numbering — this is an acceptable trade for lining up with the architecture pdp64 is actually a successor to.

**Roles the ABI assigns (version 1, `docs/abi.md`; the hardware knows none of them).** `R0`–`R5` carry arguments, and `R0` (with `R1` for a 128-bit pair) the result; `R0`–`R7` and `R12` are caller-saved; `R8`–`R11` and `R15` are callee-saved; `R12` is the linker's scratch register; `R13` is the optional frame pointer and `R14` the stack pointer. The stack pointer is a multiple of 8 at all times, because quad data accesses must be naturally aligned (§7.4); nothing is wider than a quad, so there is no 16-byte alignment. The data model is LP64 and little-endian.

Not taken from VAX: `R12` as the argument pointer. VAX's `AP` exists to serve `CALLS`/`CALLG`, which §11 rejects, so `R12` is an ordinary register here. VAX's `R15` is the `PC`; ours is general (§9.3).

**Why `SP` is in the register file and the `PC` is not.** The mode-switched copies are the *only* way `SP` differs from `R0`; it exists so that a trap arriving in user mode has a kernel stack without first having to find one, which is the PDP-11's arrangement and remains correct. Everything else about `SP` is ordinary. Critically, **writing `SP` has no control-flow consequence** — it is a data write that happens to hold a pointer, and the hazard logic treats it like any other destination. Writing the `PC` redirects execution, which makes every register write a potential branch. That asymmetry, not importance or convention, is why one is in the file and the other is not. §9.3 has the full argument.

**`R13` as the frame pointer is convention and nothing more.** No instruction, no trap and no page walk knows about `R13`. The reason to put it high rather than low is `PUSHM`/`POPM`: a prologue wants the callee-saved registers contiguous at the top of the mask so one instruction saves them, and `R13` adjacent to `R14` and `R15` is a tighter cluster than the revision 14 arrangement gave. AArch64 puts its frame pointer at `X29` for the same reason, and could have put it anywhere.

### 2.2 Special registers

| Register | Width | Notes |
|---|---|---|
| `PC` | 64 | not a GPR; reached through mode `0010` and `LEA` |
| `PSW` | 16 | N Z V C, current mode, previous mode, priority, T |
| `FPSR` | 5 | sticky floating-point exception flags (§4.10); saved with the `PSW` as part of the thread context |
| `DP` | 64 | direct page base; three copies, kernel / supervisor / user |
| `ASID` | 16 | address space identifier |
| `PTBR` | 64 | page table base |
| `DMW0`, `DMW1` | 64 | direct mapping window configuration (§8.3) |
| `EPC`, `EVA`, `ECAUSE` | 64/64/16 | exception PC, faulting address, cause |

`DP` carries forward from revision 1. In the 16-bit machine it was a memory-management feature; here it is primarily an **encoding** feature. Mode `0011` reaches global data with a 12-bit signed displacement in a two-parcel instruction, consuming no register and requiring no relocation. It is the durable form of the 6502 zero page — not "a register file in memory," which was a 1975 economy, but "the shortest address form the ISA has," which is permanent.

**`DP`'s three mode-switched copies have found two distinct jobs**, and because the copies are separate the two do not conflict:

| Copy | Role |
|---|---|
| kernel | the **per-CPU pointer** (§17.4) — every SMP kernel builds one by hand; here it is a register that already exists |
| user | the **thread pointer** (§19.3) — which makes local-exec thread-local storage `MOVQ d(DP), Rd`, one instruction and four bytes |

Neither use was designed for. `DP` was added for code density and turns out to be what both an SMP kernel and a threaded C runtime need most, in the mode where each needs it.

### 2.3 Floating point

**Floating point operates in the general registers.** There is no FP register file.

A `binary64` value occupies one register exactly. This extends the revision 4 decision that `AC0`–`AC5` *are* `F0`–`F5`, holding raw bits with the instruction deciding interpretation: `FADD R1, R2` reads them as `binary64`, `ADD R1, R2` reads them as integers, and nothing distinguishes the two at rest.

What this buys: no second register file, no second set of read ports, no transfer instructions, no separate FP context in the PCB, no split calling convention. On a small implementation the FP register file is among the largest single blocks on the die. RISC-V standardized this arrangement as Zfinx for exactly this reason.

**Consequence, stated explicitly for the ABI document:** an integer operation on a register holding a `binary64` destroys it, with no trap and no tag. Correct and intended, but it wants saying out loud rather than being discovered by whoever writes the debugger.

`binary32` values occupy the low 32 bits, sign-extended — the same convention as `MOVL`, so one rule covers narrow integers and narrow floats alike.

The calling convention follows from this and is in `docs/abi.md`: floating-point values are passed and returned in the general registers exactly as integers are, and `long double` is `double`. Floating-point exception flags are recorded in `FPSR` and never trap (§4.10). Any NaN that an arithmetic or conversion operation creates is the canonical quiet NaN (§4.10).

---

## 3. Instruction format

### 3.1 Length first

Instructions are 1 to 3 **16-bit parcels**, parcel-aligned. An instruction is therefore 2, 4 or 6 bytes. (Earlier revisions had a fourth parcel; it was removed on 2026-10-22 (errata 31) and the length code that named it now selects a second page of one-parcel instructions, §3.1.2 and §4.18. §9.6 gives the history.)

UTF-8's contribution is not that the leading unit gives the length — revision 8 had that, and the PDP-11 had it in 1970. It is that **length is the primary partition**, so payload is budgeted by what each form actually needs, rather than by carving fixed fields out of a fixed width and living with the remainder.

Every instruction, at every length:

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+-----+-----------------+-----------+-----------+
| len |      opcode     |    reg    |  mode/rm  |
+-----+-----------------+-----------+-----------+
```

**`len` is bits 15..14 of parcel 0.** `len = 00`, `01` and `10` are **page 1**: the instruction occupies 0, 1 or 2 parcels beyond parcel 0 — so 1, 2 or 3 parcels in total, which is 2, 4 or 6 bytes. **`len = 11` is page 2**: always exactly one parcel, with its own opcode map and a different layout (§3.1.2, §4.18).

For page 1, read `len` as **the number of extension parcels**, not as the total minus one. That is what the field literally is, and it is what the hardware uses: fetch parcel 0, load `len` into a down-counter, fetch that many more. No adder, no increment, no decode. The `+ 1` is an artifact of counting from parcel 0 rather than after it. For `len = 11` the count of extension parcels is zero: the fetch unit treats `11` like `00`, a one-parcel instruction, and only the decoder tells them apart.

The claim with actual content is not that the count is in the field — that is true by construction — but that **length is a function of `len` alone**:

| Architecture | Length is a function of |
|---|---|
| **pdp64** | `len`, two bits of parcel 0 |
| pdp64 rev. 9 | `len` and, at `len = 11`, the opcode (a rule this revision never breaks: the length of `len = 11` is always one parcel) |
| PDP-11 | both 6-bit mode/register specifiers of word 0 |
| x86 | prefixes, opcode, ModR/M and SIB, in sequence |
| VAX | every operand specifier, parsed in order, some requiring a memory reference first |

Each row down that table costs more front-end logic and more serialization before the next instruction's address is known. The pdp64 row is the cheapest available: two bits, straight to the counter. This is the §9.5 discipline in its purest form.

The rule has a corollary that escape opcodes must respect; see §4.14.

### 3.1.1 What lands at each length

The density argument depends on this distribution, so it is stated rather than implied. **Most instructions are not six bytes.**

| Parcels | Bytes | Contents |
|---|---|---|
| 1 | 2 | all register–register ALU and moves; the entire conversion set; `PUSH`, `POP`; single-operand ops on a register; branches within ±256 bytes; most of `SYS`; every page-2 form (§4.18): register-deferred loads and stores, `sp`-relative loads and stores, `LEA` from `SP`, `PUSHM8`/`POPM8`, frame adjustment, four-bit immediates |
| 2 | 4 | any memory operand within ±2 KB — which is every frame local and every `DP` global; 12- and 16-bit immediates; branches within ±64 KB; `SOB`; `BTAG`; `PUSHM`, `POPM`; `CBCC` (compare with a 5-bit immediate and branch within ±1024 parcels); `BESC`, `MBLK`, `FESC`, `ATOM` |
| 3 | 6 | displacements to ±128 MB; 32-bit immediates, absolutes and PC-relative offsets; branches within ±4 GB; `CBCC` with a 27-bit displacement; bitfield ops needing position and width |

Compiled code sits overwhelmingly in the first two rows. Once operands are in registers the work is one parcel apiece, and reaching a frame local or a `DP` global is two. Expected average is near three bytes per instruction — Thumb-2 territory, and better than a fixed 32-bit RISC encoding.

The `uint64_t` bound is a claim about **carriers, not about the instruction stream**. The longest instruction is now six bytes, so a 64-bit word holds any instruction with sixteen bits to spare (the rule held at eight bytes with none). The decode register holds any instruction in one word plus a two-bit valid-parcel count, and so do the assembler, the disassembler, the simulator and the compiler backend. It says nothing about what a sequence of instructions occupies in memory, and the fetch discussion in §3.2 is about the worst case rather than the common one.

Byte-granular encoding — x86's and the 6502's — remains rejected. Both were 8-bit-bus machines where a byte was the natural fetch unit. On a 64-bit datapath it buys roughly a tenth of the code size and costs a full alignment rotator plus cross-line splice logic in the front end.

### 3.1.2 Page 2: `len = 11`

`len = 11` is not a fourth length. It is a **second page of one-parcel instructions**, with the layout

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+-----+-----------------+-----------+-----------+
| 11  |      opc (6)    |    reg    |    low    |
+-----+-----------------+-----------+-----------+
```

and its own 64-entry opcode map (41 defined), given in §4.18. Every page-2 form is *exactly* an abbreviation of an existing page-1 instruction: the same result, the same flags, the same faults. The assembler chooses it when the operands fit, as it chooses any other length, and a page-2 form has no mnemonic of its own (§4.14, §4.15). Length is still a function of `len` alone: page 2 is always one parcel. What is new is one extra decision in the decoder, after the length is known, and that decision is the page select on `len = 11`.

### 3.2 Alignment and fetch

**Instructions are aligned to 2 bytes and may cross any boundary**, including 8-byte, cache-line and page boundaries. There is no padding rule and no assembler alignment obligation.

**Byte order is little-endian**, for data and for instructions: a parcel is a 16-bit little-endian unit in memory. The diagrams in this document draw each parcel with bit 15 first (§4.17).

A worst-case instruction — six bytes at offset 6 — spans two aligned quads, so the fetch path needs a two-deep parcel buffer. It needed one at four parcels and at five; the three-parcel cap does not simplify fetch. Forcing instructions inside an 8-byte window would buy that simplification, and it would cost 5–10% of code size in padding plus an alignment obligation propagated through the assembler, the linker and every hand-written stub. Not worth it. The fetch path is already among the cheapest blocks in the machine.

### 3.3 Extension parcels

**`len = 01`** — two parcels:

```
parcel 1:  rrrr dddddddddddd        rm(4), signed displacement(12)
```

±2 KB. The central win of the length-first layout: revision 8 gave 16 bits of displacement and charged a whole parcel for it; this gives 12 bits inside a parcel already being spent. Twelve bits is past the knee of the curve for frame offsets and struct offsets both, and the instruction is four bytes either way.

**`len = 10`** — three parcels:

```
parcel 1:  rrrr dddddddddddd        rm(4), displacement 27..16
parcel 2:  dddddddddddddddd         displacement 15..0
```

28-bit signed displacement, ±128 MB.

**`len = 11`** is not an extension length: it is the one-parcel second page (§3.1.2, §4.18). Through the revision before 2026-10-22 it was a four-parcel form with a 44-bit displacement and 48-bit immediates and absolutes; those forms are gone (§9.6).

**The `rm` nibble is reclaimed where it is idle.** Modes `0100` (immediate), `0101` (absolute) and `0010` (PC-relative) name no base register, so parcel 1 carries payload in all sixteen bits:

| Mode class | `len=01` | `len=10` |
|---|---|---|
| base-register modes | 12 bits | 28 bits |
| immediate / absolute / PC-relative | 16 bits | 32 bits |

At `len=10` the immediate, absolute and PC-relative payload is therefore a sign-extended 32-bit value; a symbol immediate or absolute address in a relocation is 32 bits, sign-extended. An absolute address no longer reaches the whole 39-bit canonical space in one instruction (the 48-bit form is gone); an address or a 64-bit constant outside the 32-bit range is formed PC-relatively or loaded from a constant pool (§4.1).

**The payload of every mode at every length** (the `rm` nibble is reclaimed in the modes marked):

| Mode | `len=01` | `len=10` |
|---|---|---|
| `0000` base `d(Rn)`; `0110` post-increment; `0111` pre-decrement | `rm4 d12` | d28 |
| `0001` scaled index | `rm4 Rx4 s2 d6` | d22 |
| `0010` PC-relative, `0100` immediate, `0101` absolute | d16 (`rm` reclaimed) | d32 |
| `0011` direct page `d(DP)` | `pad4 d12` | d28 |

In the scaled-index mode the extra parcel adds sixteen displacement bits to the six of `len=01`. In the direct-page mode the four bits of parcel 1 that name no register are padding, zero, so the 12-bit displacement at `len=01` is as stated and the longer width is that of the base mode. Immediates are sign-extended; displacement fields are two's complement, truncated to the width of the field. The assembler picks the smallest `len` for which every field fits, and then the page-2 form if one applies (§4.18).

**Escape opcodes (§4.6–§4.13) define their own parcel-1 layout, subject to §4.14.**

### 3.4 The one-memory-operand rule

**At most one operand may be a memory reference.** The other, where present, is a plain register.

This is x86's ModR/M idea and it is the best idea in x86, made architectural here rather than being an artifact of the encoding. In descending order of value:

- the operand sequencer handles one specifier, not two;
- at most **one** register side effect per instruction;
- the fault matrix collapses to §7.3;
- the freed bits are what pay for sixteen registers and a 12-bit displacement.

The one departure is §4.7, admitted under §1.1 and costed in §7.5.

---

## 4. Opcode map

Sixty-four opcodes at bits 13..8. **Opcode and length are orthogonal:** `ADD` means `ADD` at every length, with only the operand's reach changing. This is the property that keeps the map small.

### 4.1 Moves and conversions — `0x00`–`0x0B`

| Op | Mnemonic | Direction | Meaning |
|---|---|---|---|
| `0x00` | `MOVQ` | `reg ← rm` | 64-bit |
| `0x01` | `MOVQ` | `rm ← reg` | |
| `0x02` | `MOVL` | `reg ← rm` | 32-bit, sign-extended |
| `0x03` | `MOVL` | `rm ← reg` | |
| `0x04` | `MOVW` | `reg ← rm` | 16-bit, sign-extended |
| `0x05` | `MOVW` | `rm ← reg` | |
| `0x06` | `MOVB` | `reg ← rm` | 8-bit, sign-extended |
| `0x07` | `MOVB` | `rm ← reg` | |
| `0x08` | `MOVZL` | `reg ← rm` | 32-bit, zero-extended |
| `0x09` | `MOVZW` | `reg ← rm` | 16-bit, zero-extended |
| `0x0A` | `MOVZB` | `reg ← rm` | 8-bit, zero-extended |
| `0x0B` | `LEA` | `reg ← addr` | effective address; `len=00` reserved |

Sub-quad sizes are retained deliberately. C `int` is 32 bits in every ABI worth targeting, and ELF, timestamps, and most on-disk and wire structures are full of 32- and 16-bit fields. Without `MOVL` a struct field load becomes two `MOVW`s, a shift, and an or.

**A register is always written in full.** Narrow loads sign- or zero-extend to the full 64 bits; there is no partial-register write anywhere in the machine. This is the rule x86-64 arrived at for 32-bit writes and failed to apply to the 8- and 16-bit forms, where preserved upper bits make every narrow write a read-modify-write of an architectural register — a merge dependency, and the most expensive surviving x86 legacy.

**At `len = 00` these are the conversion set.** `MOVB R1, R2` sign-extends the low byte; `MOVZW R1, R2` zero-extends the low word. There is no `CVT` opcode group. The standing rule paying for itself: conversion instructions, never mode bits.

**The base of every PC-relative displacement is the address of the first parcel of the instruction itself** — for `d(PC)` operands (mode `0010`), for `LEA d(PC), Rn`, for `CALL d(PC)` and for all branches. A PC-relative *operand* displacement counts bytes; a *branch* displacement counts 2-byte parcels (the reach table in §4.4 needs that). The reason for the start rather than the end of the instruction is that the displacement then does not depend on the length chosen for the instruction itself: an assembler that picks `len` from the displacement would otherwise have the displacement depend on `len` and iterate, while with this rule every instruction only ever grows, so branch relaxation is monotone and terminates (§9.9).

**`LEA` is also how the `PC` is read.** `LEA 0(PC), Rn` puts the address of the `LEA` itself in a register in one instruction, four bytes, with no ambiguity about which `PC` is meant (§9.3). At `len = 10` the same instruction forms any address within ±2 GB of itself PC-relatively — six bytes, one instruction where LoongArch needs a pair (§15).

**64-bit literals** come from a PC-relative constant pool: `MOVQ d(PC), Rn`, two parcels, ±2 KB reach. This is what compilers already do for `binary64` literals, which was the case that actually wanted 64 immediate bits. Constants that fit 32 bits sign-extended are a single immediate instruction of at most three parcels; larger ones come from the pool.

**Page 2 abbreviates the common cases of this group** to one parcel: loads and stores through `(rn)`, loads and stores at small offsets from `SP` and from a register, `LEA 8*d(SP), rd`, and `MOVQ #imm, rd` with a four-bit immediate (§4.18). They are chosen by the assembler and are the same operations.

### 4.2 ALU, register destination — `0x16`–`0x23`

| Op | | Op | |
|---|---|---|---|
| `0x16` | `ADD` | `0x1D` | `AND` |
| `0x17` | `SUB` | `0x1E` | `MUL` |
| `0x18` | `BIC` | `0x1F` | `MULH` |
| `0x19` | `BIS` | `0x20` | `SHL` |
| `0x1A` | `CMP` | `0x21` | `SHR` |
| `0x1B` | `BIT` | `0x22` | `SAR` |
| `0x1C` | `XOR` | `0x23` | reserved |

Thirteen operations in fourteen slots. Slot `0x23` is the spare: the decoder treats the whole run `ADD` … `FCMP` (§4.10) as the memory-operand class, so a reserved `0x23` decodes like an ALU instruction, and execution must trap it. Decoding it cleanly is harmless and removes a special case.

`ADD`, `SUB`, `BIC`, `BIS`, `CMP` and `BIT` are the PDP-11's double-operand set, unchanged in name and meaning — with one exception, the order of `CMP`'s operands, below.

**`CMP` computes `reg − rm` and is written `CMP Rd, rm`, register first.** PDP-11 `CMP a,b` computes `a−b`. Here the destination of an ALU operation must be a register, so a literal `src,dst` reading would force every comparison of a register against an immediate or a memory operand to reverse its branch condition, and every compiler would pay for it. `CMP a,b` followed by `BLT` still reads "branch if a < b", as on the PDP-11; only which side must be a register differs. `BIT` is symmetric and unchanged. The floating-point compare is register-first in the same way (§4.10).

**Flags.** `ADD` sets `C` on a carry out. `SUB` and `CMP` set `C` on a *borrow* (the PDP-11 sense), so `BHIS`/`BCC` mean "no borrow", unsigned `≥`, and `BLO`/`BCS` mean a borrow occurred. `V` is signed overflow. `ABS`, `MIN` and `MAX` are in §4.12; shifts and rotates are in §4.2.1. `MOV` sits in §4.1 because it needs a size field. The rest are what a 64-bit machine needs and a 16-bit one did in software.

Revision 20 removed `ROR`, `DIV` and `DIVU` from this group (§4.3) and brought the shifts into it, so every member now has a frequent register-to-register case.

**ALU operations are 64 bits, always.** No size field. This eliminates byte-lane multiplexing in the ALU and, with §4.1, eliminates partial-register writes entirely. Narrow arithmetic is done wide and converted at the store, which is what compilers do anyway.

Shift counts come from `rm` — a register at `len=00`, an immediate through mode `0100`, memory otherwise. No dedicated shift-count register. x86's `CL` saves opcode bits and costs a permanent register shuffle in every hand-written loop.

#### 4.2.2 `MUL` is sign-agnostic; `MULH` replaces `MULU`

Revisions 9 through 16 had `MUL` and `MULU` here, and `MULU` was redundant: **the low 64 bits of a two's-complement product are identical whether the operands are read as signed or unsigned.** Signedness affects only the bits above the word, so one low-half multiply serves both. One of the sixteen ALU slots was spent on a duplicate.

Meanwhile nothing in the architecture produced the *high* half, which meant 64 × 64 → 128 was impossible and every bignum multiply, 128-bit fixed-point operation and divide-by-constant-via-reciprocal was unimplementable. A real hole, and the inverse of the duplicate.

Revision 17 fixes both:

| | |
|---|---|
| `MUL` | low 64 bits of the product. Sign-agnostic |
| `MULH` | high 64 bits, operands read as signed |
| `MULHU` | high 64 bits, operands read as unsigned — in `BESC` |

This is RISC-V's arrangement (`MUL`, `MULH`, `MULHU`, `MULHSU`) and it is correct for the same reason. `MULHSU` — signed times unsigned, needed when a bignum's signed top limb meets an unsigned one — is a `BESC` candidate rather than a commitment, since the only caller is a bignum library's innermost loop and it can be synthesized with one correction step.

With `MULH` present, divide-by-constant becomes multiply-by-reciprocal, which is what every compiler emits and is roughly thirty times faster than the `DIV` sequencer. `DIV` stays for the general case.

#### 4.2.1 Shift and rotate flag semantics

Stated in revision 16, having been absent from every prior revision — an omission that mattered, because it left `ROL` ambiguous between a plain rotate and a rotate through carry (§4.5.1).

| Operation | `C` | `N`, `Z` | `V` |
|---|---|---|---|
| `SHL`, `ASL` | last bit shifted out of bit 63 | from the result | cleared |
| `SHR`, `SAR`, `ASR` | last bit shifted out of bit 0 | from the result | cleared |
| `ROR`, `RORI` | bit rotated into bit 63 | from the result | cleared |
| `DSHR` | **unchanged** | from the result | cleared |

Three rules behind that table:

- **A shift count of zero changes no flag**, including `C`. This is the rule x86 gets wrong — its shifts leave flags undefined for a zero count, which is a documented hazard for anyone writing a variable shift. Here a zero count is a no-op in every respect.
- **A count of 64 or more** shifts the value entirely away: `SHL`/`SHR` give zero, `SAR` gives the sign, and `C` takes the last bit that left. The count is taken modulo nothing — it is treated as the unsigned value it is, so there is no surprise at exactly 64 the way there is on machines that mask the count to six bits. `ROR` is the exception and does take its count modulo 64, because a rotate by 64 is the identity by definition.
- **No rotate is through carry.** `ROR` is a plain 64-bit rotate; `C` receives a copy of the bit that wrapped, which is informational rather than part of the rotation. Multi-precision shifting uses `DSHR` (§4.6.4), not a carry chain, which is why `DSHR` leaves `C` alone — a funnel shift in a loop must not disturb a carry the surrounding code is maintaining.

### 4.3 How the space is allocated

Revision 20 reallocated all sixty-four opcodes. The principle is one hard encoding fact plus a frequency sort.

**The fact: an operation in a parcel-1 escape group can never be two bytes**, because its sub-opcode lives in parcel 1 and parcel 1 only exists at `len ≥ 01`. Everything else about an escape group is free — it has the same addressing modes, the same displacement scaling and the same decode position for its operands. The *only* thing a top-level opcode buys is the one-parcel form.

So the question for every operation is not "is it important" but:

> **Is its common case register-to-register?** If yes it needs a top-level opcode, because that case can be two bytes. If its common case has a memory operand, an immediate, or three registers, it is four bytes or more either way and an escape group costs it nothing.

That turns the allocation into a sort:

| Tier | What | Minimum size | Why |
|---|---|---|---|
| **1** | moves and conversions, the ALU set, `SOP`, branches, `SOB`, FP add/sub/mul/compare | **2 bytes** | register-to-register is the common case |
| **2** | `XFER`, `TAGOP` | 4 bytes | need a memory operand or a displacement regardless |
| **3** | rare arithmetic, bit manipulation, block memory, unaligned access, FMA, FP divide and square root, atomics, system control, ALU-to-memory | 4 bytes | need an immediate, a third register, or a memory destination regardless |

**Five groups were demoted in revision 20**, and in four of the five the demotion costs nothing at all because the operation could never have been two bytes:

| Demoted | To | Cost |
|---|---|---|
| `ADDM` `SUBM` `BICM` `BISM` (was `0x20`–`0x23`) | `MESC` | **none** — a memory destination means `len ≥ 01` already |
| `FDIV` `FSQRT` | `FESC` | **none** — rarely in a two-byte reg-reg form, and both are multi-cycle anyway |
| `MOD` `MODU` `MULHU` | `AESC` | **none** — they were already escape sub-opcodes, just in the thematically wrong group |
| `DIV` `DIVU` | `AESC` | two bytes on a reg-reg divide. Accepted: compilers turn division by a constant into `MULH` plus a shift, so a real divide is rare, and a 32-cycle sequencer does not notice one extra parcel of decode |
| `ROR` | `BESC` | two bytes on a register-count rotate. Accepted: revision 16 justified `ROR`'s ALU slot by crypto inner loops, but **crypto rotates by compile-time constants**, which is a four-byte immediate form either way. The justification was wrong |

**One group was added**, `AESC` at `0x0E`, and it is net negative in opcodes: it takes one slot and lets `MOD`, `MODU` and `MULHU` leave `BESC`, where arithmetic never belonged thematically.

**Nothing was promoted and nothing grew.** The nine freed slots stay reserved rather than being filled, which is §1.2 rule 3: the regroup exists to match the space to frequency, not to use it up. Reserved space went from one scattered slot to **eight contiguous** (`0x28`–`0x2F`); on 2026-10-22 `0x28` was assigned to `CBCC` (§4.4.1), leaving seven (`0x29`–`0x2F`).

#### 4.3.1 Why the layout is ordered the way it is

Opcode numbering is not arbitrary beyond the tiers, and two groupings pay for themselves in the decoder.

**The six parcel-1 escapes are contiguous at `0x0C`–`0x11`.** `BESC`, `MBLK`, `AESC`, `MESC`, `FESC` and `ATOM` are exactly the groups that require a second decode stage, so "do I need to read a sub-opcode from parcel 1" becomes a **range comparison on bits 13..8** rather than a six-way match. One comparator instead of six.

**The three reg-as-sub-opcode groups are adjacent at `0x12`–`0x14`.** `XFER`, `SOP` and `SYS` take their sub-opcode from the `reg` field, which is already wired to the register file address inputs (§9.5), so they need a mux on that path and nothing in parcel 1. Adjacent means one range compare enables that mux.

**Everything else is a contiguous run of one kind:** twelve moves, fourteen ALU slots (thirteen assigned), four FP, sixteen branch. Each run's low bits *are* the operation select, wired straight to the relevant function mux with no decode — which is the §9.5 discipline, now visible in the numbering rather than only in the field layout.

### 4.4 Branches — `0x30`–`0x3F`

Sixteen opcodes. Fifteen are conditions; `0x3F` is `SOB`. For the conditional branches no `rm` is needed, so every extension parcel is displacement, and reach scales with length automatically — the length-first property doing work no other part of the encoding has to do.

The displacement is signed and **counts 2-byte parcels from the first parcel of the branch instruction itself** (§4.1); that is what makes 8 bits reach ±256 bytes.

| `len` | Displacement bits | Reach |
|---|---|---|
| `00` | 8, in bits 7..0 | ±256 bytes |
| `01` | 16 | ±64 KB |
| `10` | 32 | ±4 GB |

(`len = 11` is page 2 and has no branches; the 48-bit form is gone, §9.6.)

| Op | | Op | |
|---|---|---|---|
| `0x30` | `BR` | `0x38` | `BCS` / `BLO` |
| `0x31` | `BNE` | `0x39` | `BGE` |
| `0x32` | `BEQ` | `0x3A` | `BLT` |
| `0x33` | `BPL` | `0x3B` | `BGT` |
| `0x34` | `BMI` | `0x3C` | `BLE` |
| `0x35` | `BVC` | `0x3D` | `BHI` |
| `0x36` | `BVS` | `0x3E` | `BLOS` |
| `0x37` | `BCC` / `BHIS` | `0x3F` | **`SOB`** |

The complete PDP-11 branch set, unchanged, reaching ±4 GB with no long-branch opcode and no trampolines. Branch relaxation in the assembler reduces to choosing a length.

**Condition numbers.** The condition of a branch is the low nibble of its opcode: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. The instruction that takes a condition as a word of its own, `SET` (§4.12), numbers them the same way.

**`SOB Rn, dst`** — subtract one from `Rn`, branch if the result is nonzero. Restored from the PDP-11, where it was `077RNN` and could only branch *backward*, its 6-bit displacement being unsigned and subtracted from the PC. Here the displacement is signed and counts parcels, so it branches either way, and `Rn` is one of sixteen rather than one of eight. `Rn` takes the `reg` field, which at `len=00` is the top of the 8-bit branch displacement, so **`SOB` exists only from `len=01`**: it is a four-byte instruction with a displacement of 16 or 32 bits, consistent with §3.1.1, which lists it among the two-parcel forms.

`SOB` does not save bytes — `DEC Rn` plus `BNE` is also four — but it saves an instruction issue, which on a non-pipelined machine is a cycle per loop iteration. It also answers the compare-and-branch question directly: a fused `CBNZ` cannot fit in one parcel here (a 4-bit register plus a useful displacement plus six bits of opcode exceeds sixteen bits), so at `len=01` it would be the same four bytes as `DEC`+`BNE` and would duplicate `SOB`. `SOB` is the version that earns its slot, because it folds the decrement in. See §14.1. (The fused compare-immediate-and-branch of §4.4.1, added on 2026-10-22, is a different case: it takes an immediate and a displacement in parcel 1 and sets the flags as `CMP` does.)

**Condition codes are retained, and every ALU operation writes all four uniformly.** x86's arrangement, where `INC` and `DEC` write some flags and not others, exists to make one obsolete instruction a byte shorter and has complicated every implementation since. `MOV` and loads write N and Z, clear V, and leave C, as on the PDP-11.

Flags are the cheap choice here. Fused compare-and-branch needs a comparator in the branch unit and a third register read port; flags need a four-bit latch. They become expensive only under register renaming, which is not this design point. LoongArch and RISC-V both chose the other way; §15 says why that does not move us.

#### 4.4.1 `CBCC` — compare immediate and branch, `0x28`

`CBCC Rd, #imm, target` computes `Rd − imm` exactly as `CMP Rd, #imm` does (the same flags are written) and then branches if the condition holds. It takes the previously reserved top-level opcode `0x28`.

```
len = 01 (4 bytes):
parcel 0:  01 101000 rd cond         cond = the branch condition number (below), in the low nibble as for SET
parcel 1:  iiiii dddddddddddd        imm(5) signed, -16 to 15;  disp(11) signed, in parcels
len = 10 (6 bytes):
parcel 1:  iiiii dddddddddddd        imm(5), disp 26..16
parcel 2:  dddddddddddddddd          disp 15..0       a 27-bit displacement
```

As for every branch the displacement counts 2-byte parcels from the first parcel of the instruction itself (§4.1): ±1024 parcels at `len = 01`. There is no `len = 00` form. The assembler picks the length as it does for `BCC`; **the immediate must fit five bits**, and the compiler emits `CBCC` only then. The mnemonics are `cbne cbeq cbpl cbmi cbvc cbvs cbcc cbcs cbge cblt cbgt cble cbhi cblos` and the aliases of the branch group; the condition names and numbers are those of `BCC` and `SET` (above). The opcode `0x28` does not obey the "low nibble of the opcode is the condition" rule of the branch group; `CBCC` has one opcode and takes its condition from parcel 0's low nibble.

### 4.5 Single-operand escape — `SOP`, `0x13`

The `reg` field is free, so it becomes a 4-bit sub-opcode. `rm` and the mode supply the single operand at any length.

| `reg` | | `reg` | |
|---|---|---|---|
| `0` | `CLR` | `8` | `ASL` |
| `1` | `COM` | `9` | `ASR` |
| `2` | `INC` | `A` | `PUSHM` |
| `3` | `DEC` | `B` | `POPM` |
| `4` | `NEG` | `C` | `JMP` |
| `5` | `TST` | `D` | `CALL` |
| `6` | `ADC` | `E` | `PUSH` |
| `7` | `SBC` | `F` | `POP` |

`ASL` and `ASR` are the by-one forms of `SHL` and `SAR` (§4.2) in a one-parcel encoding — two bytes against four. They earn that because halving and doubling are frequent; rotate-by-one is not, and revision 16 removed `ROL` from this group (§4.5.1).

Revision 18 moved `COM` out of slot 1 to make room for `JMPI`, which made one's complement four bytes instead of two. **Revision 19 reverts that**: §1.2 rule 2 forbids displacing an instruction into a longer encoding, and `COM` is common enough that the trade was wrong. `JMPI` and `CALLI` moved to `XFER` (§4.9), which also took `JTAG` out of slot `A` — so this group had two free slots rather than none. **Those two slots now hold `PUSHM` and `POPM`** (below), and the group has no free slot left.

Slots `A` and `B` were `SWAB` and `SXT` originally. `SWAB` is subsumed by `BSWAP` in `BESC`; `SXT` is subsumed by the conversion set at `len = 00`, which is strictly more general. See §14.3.

#### 4.5.1 Why one rotate direction, and why it is `ROR`

`ROL x, #n` is exactly `ROR x, #(64 − n)`, so for an **immediate** count the assembler complements the operand and emits `RORI` (the immediate-count rotate of `BESC`, §4.6) — same instruction, same four bytes, no cost whatever. Only a register-held count needs an extra `NEG`, and immediate counts dominate overwhelmingly in the code that rotates at all: SHA-256's σ and Σ functions, BLAKE2, ChaCha20, SipHash and xxHash all rotate by compile-time constants.

AArch64 reaches the same conclusion more firmly — it has **no `ROL` instruction at all**. RISC-V's Zbb extension provides `ROL` and `ROR` for register counts but only `RORI` for immediates, for precisely this reason.

Right is also the direction the hardware prefers. A funnel shifter that forms `{x, x}`, shifts right by *n* and keeps the low 64 bits yields `ROR` directly; `SHR` is the same structure with the upper half zeroed and `SAR` with it sign-filled. `SHL` is the one operation needing the shift amount complemented. Three of the four ALU shifts are the shifter's natural direction, so matching the rotate to them is consistency rather than coin-flipping.

**What revision 16 fixed.** Through revision 15 this group held `ASL` and `ROL` — the two *left* shifts — with no `ASR` and no `ROR`, which contradicted the paragraph above and dropped two of the PDP-11's four single-operand shifts for no stated reason. Worse, the specification never said whether `ROL` was a plain rotate or a rotate **through carry**. The PDP-11's `ROL` and `ROR` were 17-bit rotates through `C`, which is what makes `ASL lo` followed by `ROL hi` shift a multi-word value; a plain 64-bit rotate by one is a different instruction entirely, and §4.2's variable-count `ROR` cannot sensibly be through-carry at all. Two entries that may not have been the same operation.

**Rotate-through-carry is not the right fix.** Its only real use is multi-precision shifting one bit per instruction, and the modern primitive for that is a double-width funnel shift — x86's `SHLD`/`SHRD`, ARM's `EXTR`. A 128-bit shift by *k* becomes two instructions instead of *k* iterations. `DSHR` in `BESC` (§4.6.4) is that instruction, so `ROL`-by-one has no remaining customer and the slot is better spent on `ASR`.

`PUSH` and `POP` are one parcel and exist because §5.2 charges an extra parcel for `(Rn)+` and `-(Rn)`, and stack traffic is where those modes actually get used.

**`PUSHM #mask` (slot `A`) and `POPM #mask` (slot `B`)** save and restore a register set. The mask is a 16-bit immediate (mode `0100`), so each is four bytes, using only mechanisms that already exist. Mask bit *n* is `Rn`; `PUSHM` stores the lowest-numbered register at the highest address. They are here and not in `MBLK` because an `MBLK` parcel 1 carries an 8-bit sub-opcode, which leaves no room for a 16-bit mask at `len=01`, and §4.14 forbids deciding the interpretation of parcel 0 per sub-opcode (§9.9).

`CALL dst` pushes the return address on `SP`; `RET` pops it. §14.2 compares this with the PDP-11's `JSR`/`RTS`.

### 4.6 Bit, field and rotate escape — `BESC`, `0x0C`

```
len=01:  01 001100 dddd ssss  |  oooooooo tttt xxxx
                                  sub-op   3rd reg
len=10:  10 001100 dddd ssss  |  oooooooo tttt xxxx  |  pppppppp llllllll
                                                        position  width
```

Parcel 0's low nibble is `ssss`, a **register**, not a mode — `BESC` is register-to-register work. Sub-opcodes requiring a position and a width are encodable only at `len = 10`, per §4.14. The destination is `dddd` (`reg`), the first source `ssss` (`low`) and the second source `tttt` (parcel 1); the assembler writes the destination last (§4.17).

| Sub-op | Operation |
|---|---|
| `CLZ`, `CTZ`, `CLO`, `CTO` | count leading/trailing zeros/ones |
| `POPCNT` | population count |
| `BSWAP` | reverse all 8 bytes |
| `BSWAPW`, `BSWAPL` | reverse bytes within each word / each long |
| `BITREV` | reverse all 64 bits |
| `DSHR` | double-width funnel shift — see §4.6.4 |
| `ROR` | rotate right by a register count — moved here in r20 (§4.3) |
| `RORI` | rotate right by an immediate count: a four-byte form with the count in the low byte of parcel 1 (six bits used). `ROL Rd, Rs, #n` assembles to `RORI` with `64 − n` (§4.15) |
| `RORI32` | rotate right by an immediate count, 32 bits: the format of `RORI` (`sub:8 count:8` in parcel 1) and a four-byte instruction. `rd ← zero-extend(ror32(rs[31:0], n mod 32))`. The result is zero-extended because unsigned 32-bit values are kept zero-extended by the compiler and the rotates of hash and crypto code are unsigned; a signed rotate is `RORI32` followed by `MOVL rd, rd`. `ROL` has no 32-bit form. Added 2026-10-22 (errata 31) |
| `EXTB`, `EXTZB` | bitfield extract at position/width, sign- or zero-extended; position and width are in parcel 2, so these exist at `len ≥ 10` only |
| `INSB` | bitfield insert at position/width; `len ≥ 10` only |
| `XNORPOP` | `popcount(¬(Ra ⊕ Rb))` — see §4.6.2 |
| `CLMULL`, `CLMULH` | carry-less multiply, low and high halves — see §4.6.3 |
| `UTF8LEN`, `UTF8DEC`, `UTF8ENC` | §4.6.1 |

Revision 10's reorganization dropped `BSWAP`, `EXTB`, `INSB` and `MOD` when the extended two-operand group was folded away. Their absence was a plain bug. Bit manipulation is not an extension on a machine that does filesystem work, bignum work or garbage collection — LoongArch treats it as core, with `CLO`/`CLZ`/`CTO`/`CTZ`, `BSTRINS`/`BSTRPICK`, `BYTEPICK`, `REVB`, `REVH` and `BITREV` all in the base ISA, and that is the right call.

#### 4.6.1 UTF-8

Most of what UTF-8 needs is general bit manipulation, which the table above now provides. `UTF8LEN Rd, Rs` is the exception that is nearly free: it is `CLO` on the low byte, mapped `0→1, 2→2, 3→3, 4→4`, anything else → 0 for an invalid leading byte. A shifter and a four-entry table.

`UTF8DEC` and `UTF8ENC` earn their place for a different reason — not speed, but that the **validity rules are where the bugs are**:

```
UTF8DEC Rd, Rs    ; Rs holds up to 4 bytes, leading byte in bits 7..0
                  ; Rd ← scalar value; N ← length consumed in bits 2..0 of PSW scratch
                  ; V ← set if the sequence is not a valid encoding
UTF8ENC Rd, Rs    ; Rs holds a scalar value; Rd ← packed bytes, leading byte in bits 7..0
                  ; V ← set if Rs is not a Unicode scalar value
```

`V` is set for any of:

- a continuation byte not matching `(b & 0xC0) == 0x80`;
- an **overlong** encoding — a 2-byte form below U+0080, a 3-byte below U+0800, a 4-byte below U+10000;
- a **surrogate**, U+D800 through U+DFFF, which is not a scalar value;
- a value above U+10FFFF;
- a leading byte of `0xC0`, `0xC1`, or `0xF5`–`0xFF`, which can never begin a valid sequence.

Every one of those is a historical security hole, and every one is three comparators. Software implementations get them wrong or omit them for speed; an instruction cannot. Cost is roughly 300 LUTs of comparator and mux, estimated in the implementation plan.

#### 4.6.2 `XNORPOP`

When **both** operands of an inner product are binary (±1), it reduces exactly to

```
dot(a, b) = n − 2 · popcount(a ⊕ b)
```

which is the XNOR-net kernel. `XNORPOP Rd, Ra, Rb` computes `popcount(¬(Ra ⊕ Rb))` — the same quantity with the complement folded in, so the caller needs no `COM` — handling 64 elements at a time and replacing `XOR`, `COM` and `POPCNT`. It is cheap because `POPCNT`'s adder tree is already being built for its own sake.

Its uses are binary-activation networks, Hamming distance, bitset intersection cardinality, and counting a garbage collector's mark bitmap. Those justify the sub-opcode on their own.

> **Correction to revision 13.** Revision 13 presented `XNORPOP` as the instruction that serves sub-1-bit quantized language models. That was wrong, and the error was in assuming the activations are binary. In Samsung's LittleBit and LittleBit-2 — the sub-1-bit formats this was aimed at — the *weights* are ±1 but the **activations are FP16**, so the inner loop is not a popcount. It is a conditional add or subtract of a real value under a one-bit control, which is why the authors call the method MatMul-free: there are no multiplies in the contraction, but there is no popcount either. `XNORPOP` does not serve that kernel.

**The scalar ISA should not try to serve it.** The LittleBit kernel is two binary-factor contractions with an on-chip rank-r intermediate, and its op count equals its weight-bit count exactly, so it is bandwidth-bound with no arithmetic intensity to exploit. It wants a bus-mastering accelerator with its own DMA and hundreds of sign-flip-accumulate lanes, which is the Q64 coprocessor model adopted in revision 5 from Chuck Moore's designs. The LB64 document specifies one. Nothing in that design needs an ISA opcode — see §16.

`EXTB`, `BITREV` and `BSWAP` remain useful for packing and unpacking such formats when that is done on the scalar core, which is a host-side activity rather than an inner loop.

#### 4.6.3 `CLMUL`, and why not `CRC` (considered, added, withdrawn)

`CLMULL`/`CLMULH Rd, Ra, Rb` compute the low and high 64 bits of the 128-bit carry-less product of `Ra` and `Rb` — polynomial multiplication over GF(2), which is an AND-XOR tree with no carry propagation and therefore *cheaper* than an ordinary multiplier of the same width.

This is deliberately chosen over a `CRC` instruction. x86 (SSE4.2 `CRC32`) and ARM (`CRC32B/H/W/X`) both committed a polynomial to the architecture — x86 chose CRC-32C/Castagnoli, ARM chose the Ethernet CRC-32 — and a program needing the other one gets no help. Carry-less multiply is the *primitive beneath* all of them: any CRC of any polynomial reduces to `CLMUL` plus a Barrett reduction, and the same instruction serves GF(2^k) arithmetic for Reed–Solomon erasure coding and the GF(2^128) multiply at the heart of AES-GCM.

**`CRC32` and `CRC32C` instructions (four widths each) were asked for after this section was written, added as eight `BESC` words (sub-opcodes `0x34`–`0x3B`), and then withdrawn at the user's decision: with carry-less multiply there is no need for either.** The choice above stands, and `0x34`–`0x3B` are free again.

One instruction, no polynomial baked in, three unrelated users. The VAX `CRC` instruction that §11 rejects was table-driven and committed to one polynomial per table; this is the better answer to the same need.

Carry-less multiply also shows up in the hash functions a Lisp runtime wants for `sxhash` and in Rabin fingerprinting for content-defined chunking — both plausible on a machine that already has `filsys` and `9Pfrank` in its world.

#### 4.6.4 `DSHR` — the funnel shift

`DSHR Rd, Ra, Rb, #n` forms the 128-bit concatenation `Ra:Rb`, shifts it right by *n*, and writes the low 64 bits to `Rd`. Three registers and an immediate, so it needs the position field and is encodable only at `len = 10` (§4.14) — six bytes. In the encoding `low` is `Ra`, `t` is `Rb`, and the shift count is the `pos` field of parcel 2.

This is x86's `SHRD` and ARM's `EXTR`, and it is the general tool for everything that rotate-through-carry served one bit at a time:

```
        ; shift the 128-bit value hi:lo left by k
        DSHR    hi, hi, lo, #(64-k)
        SHL     lo, #k
```

Two instructions for any *k*, against *k* iterations of shift-and-rotate-through-carry. It also covers 128-bit rotates, extraction of a 64-bit field straddling a word boundary — which is what a bit-stream reader does on every symbol — and, with both sources the same register, `DSHR Rd, Rn, Rn, #n` **is** a rotate right by *n*. That last identity is the useful check that `DSHR` is the right primitive and `ROR` is its one-register special case. (Revision 20 moved `ROR` out of the ALU group into `BESC` (§4.3), since crypto rotates by constants and the immediate form is four bytes either way.)

### 4.7 Block memory escape — `MBLK` (memory block), `0x0D`

```
len=01:  01 001101 dddd ssss  |  oooooooo nnnn ffff
         Rd (dest)  ^Rs(src)     sub-op   Rn   flags
```

The granted exception to §3.4, admitted under §1.1. `reg` is the destination pointer, `low` the source pointer and parcel 1's `nnnn` the count: `MCPY Rd, Rs, Rn` is *destination pointer, source pointer, count*. For `MVAL Rd, Rn` the `low` field is unused.

| Sub-op | Operation |
|---|---|
| `MCPY Rd, Rs, Rn` | copy `Rn` bytes from `(Rs)` to `(Rd)`, ascending. Overlap undefined. |
| `MMOV Rd, Rs, Rn` | as `MCPY`, but correct for overlap — direction chosen from the pointers |
| `MSET Rd, Rv, Rn` | fill `Rn` bytes at `(Rd)` with the low byte of `Rv` |
| `MCMP Rd, Rs, Rn` | compare `Rn` bytes; flags from the first difference |
| `MSCN Rd, Rv, Rn` | scan `Rn` bytes at `(Rd)` for the low byte of `Rv` |
| `MSCNN Rd, Rv, Rn` | scan for the first byte **not** equal to the low byte of `Rv` |
| `MVAL Rd, Rn` | validate `Rn` bytes as UTF-8 — see §4.7.1 |

(`PUSHM` and `POPM` are not here: a 16-bit mask does not fit beside `MBLK`'s sub-opcode, and they are in `SOP`, §4.5.)

**Semantics, stated as a loop because that is exactly what it is.** For `MCPY`:

```
while Rn ≠ 0:
    byte at (Rd) ← byte at (Rs)
    Rd ← Rd + 1;  Rs ← Rs + 1;  Rn ← Rn − 1
```

All three registers are updated as work completes. On completion `Rn` is 0 and `Rd`, `Rs` point one past the end. `MCMP` and `MSCN` stop early and leave the pointers at the byte that stopped them, so they give both the result and the position — which is what `memcmp`, `strcmp`, `memchr` and `strchr` all actually need.

**Why this is not VAX `MOVC5`.** `MOVC5` takes its operands from general specifiers, which may themselves be memory, and its architectural definition requires the original operand values to survive the instruction. That forces hidden intermediate state and `PSL<FPD>` to resume from the middle. These instructions take their operands from registers and *consume them as progress*. There is no hidden state because the state is the registers, and the registers are already saved and restored by every context switch that exists. §1.1 clause (c): the mechanism is absent.

This is the same design ARM reached in 2022 with `FEAT_MOPS`, whose specification says the registers "are updated to reflect the bytes that were actually set before the fault, so progress is not lost," and the same one IBM reached decades earlier with System/360's `MVCL` and `MVCLE`, which are interruptible with progress in the register pair. ARM splits each operation into a prologue, main and epilogue instruction so that implementations may choose their own block size; that complication is unnecessary here, because §7.5 gets the same freedom from a weaker statement.

**Implementations may move more than a byte per step.** The architectural requirement is only that at every point where an exception can be taken, the register state is *consistent with* byte-at-a-time progress. A 64-byte-per-cycle engine satisfies this by only becoming interruptible at block boundaries and updating all three registers atomically with each block. Nothing in the architecture reveals the block size.

**`MSET` with `Rv = 0` is the range-zeroing instruction**, so `bzero` and `calloc`'s clear are one instruction. This was the specific thing worth having and it needs no separate opcode.

#### 4.7.1 `MVAL` — whole-buffer UTF-8 validation

`MVAL Rd, Rn` scans `Rn` bytes at `(Rd)` and stops at the first byte that cannot be part of a valid UTF-8 sequence, by the rules of §4.6.1. On completion `Rn` is 0 and the buffer is valid; otherwise `Rd` addresses the offending byte and `Rn` holds the bytes remaining, so the caller gets the offset for free.

**It costs no opcode and almost no hardware.** `MVAL` is the §4.6.1 validity comparators — already built for `UTF8DEC` — wired to the `MBLK` streaming sequencer, already built for `MCPY`. `MBLK` has 256 sub-opcodes with seven now used. The instruction is a connection between two existing blocks.

Whether it is used often enough is the fair question, and the answer is not throughput. The alternative is a SWAR loop (see the glossary) at roughly two to three cycles per byte, which is respectable; `MVAL` at a byte per cycle is comparable and at eight bytes per cycle is better, but that is not the argument. The argument is the same one §4.6.1 makes for the per-character case: **every program that accepts text from outside itself must validate it, and the validity rules are the part software omits for speed or gets wrong.** A terminal emulator, a JSON or XML parser, a filesystem with UTF-8 names, an HTTP server, anything reading a file someone else wrote. An instruction that cannot be wrong, for an operation performed on every input, at the cost of a wire between two existing units, is an easy yes.

`MVAL` is also the natural place for the other whole-buffer text operations if they are ever wanted — case folding, normalization quick-checks, transcoding — all of which are sub-opcodes in the same group reusing the same sequencer.

### 4.8 Tag branch — `TAGOP`, `0x15`

```
len=01:  01 010101 nnnn sttt  |  dddddddddddddddd
         Rn tested  ^  ^tag      16-bit displacement
                    sense
```

`reg` is the tested register; `low` holds the sense (one bit, `BTAG` = 0, `BNTAG` = 1) in its high bit and the tag (three bits) below it. Like `SOB`, these exist from `len=01`: four bytes at least.

| Variant | Operation |
|---|---|
| `BTAG Rn, #tag, dst` | branch if `(Rn & 7) == tag` |
| `BNTAG Rn, #tag, dst` | branch if `(Rn & 7) ≠ tag` |

Three bits of tag and one of sense fit the nibble exactly, so parcel 1 is a full displacement and reach scales with `len` as in §4.4. See §6.3 for why this and `JTAG` exist.

### 4.9 Transfer escape — `XFER`, `0x12`

Three instructions that all take their target *from memory* rather than computing it. The `reg` field is the sub-opcode; `rm` and the mode give the address at any length.

| `reg` | | Operation |
|---|---|---|
| `0` | `JMPI dst` | `PC ← [EA]` |
| `1` | `CALLI dst` | push the return address, then `PC ← [EA]` |
| `2` | `JTAG d(Rb)(Rx*s)` | `PC ← [Rb + d + 8 × (Rx & 7)]` — tag dispatch, §6.3 |
| `3`–`F` | | reserved |

`JMPI`, `CALLI` and `JTAG` need a memory operand, so each is four bytes at least. **`JTAG` is legal only with the scaled-index mode (`0001`)**: `reg` is its sub-opcode and the mode and `rm` give the table address, so no field is left to name the tagged register — except that this mode already carries a base *and* an index register. The index register `Rx` is the tagged register, the scale is ignored (the stride is always 8), and `Rb + d` is the table's address (§9.9).

**Grouping them is the point.** All three need exactly one thing the rest of the machine does not: the next `PC` sourced from the load-return path instead of from the address generator. That is one mux input and one decode comparison when they share an opcode, against three scattered decode cases when they do not. Revision 18 had `JMPI` and `CALLI` in `SOP` and `JTAG` in `SOP` as three unrelated slots, with the property they share invisible in the encoding. One group is fewer entities, less verification surface, and marginally fewer gates — §1.2 rule 3.

It also costs nothing to put them here. `0x0F` was reserved; nothing was displaced, no instruction grew, and `JTAG` is the same four bytes at `len=01` as it was in `SOP` because in both encodings the `reg` field is the sub-opcode and the mode plus parcel 1 give the address.

#### 4.9.1 One deferred reference, admitted

§5.2 removed every deferred addressing mode, and nine revisions treated that as settled. `XFER` reintroduces exactly one deferred reference, for control transfer only, and §1.1's test is what admits it.

**The benefit.** Four patterns that are two instructions and a scratch register without it, and one instruction without one:

```
        ; PLT stub, dynamic linking
        JMPI    got_slot(PC)            ; was: MOVQ got_slot(PC),Rt ; JMP (Rt)

        ; virtual method dispatch
        CALLI   vtbl_off(Robj)          ; was: MOVQ vtbl_off(Robj),Rt ; CALL (Rt)

        ; call through a function pointer in a struct
        CALLI   handler(Rdev)

        ; tail call through a jump table
        JMPI    (Rtab)(Ridx*8)
```

Every cross-module call in dynamically linked code goes through the first; every virtual call in an object system or a CLOS-style dispatcher is the second.

**Why clause (c) of §1.1 is satisfied.** §5.2's objection was specific: *a fault can occur mid-specifier, after a register has already been side-effected, at an address that itself came from a load that may also have faulted.* Taking those in turn:

- **No register is side-effected.** `JMPI` and `JTAG` write no register at all, so there is nothing to undo and §7.2's journal is untouched.
- **The deferred reference is in the branch path, not the operand path.** The operand sequencer still handles at most one memory specifier, so §3.4 holds unchanged.
- **The fault is clean by ordering.** If the target load faults, nothing has happened: `PC` still addresses the instruction, no register has changed, and `RTI` re-executes it. An ordinary abort, not a restart problem.

`CALLI` writes `SP`, so its order is **specified: load the target, then push, then transfer.** A fault on the load leaves nothing changed; a fault on the push is an ordinary `-(SP)` fault handled by §7.2's buffer-and-commit. The reverse order would leave a return address on the stack for a call that never happened, and is forbidden.

The mechanism the rule protected against is structurally absent, which is the test. What remains is one extra memory reference in the branch path — a cycle on a non-pipelined machine, a load-to-branch dependency on a pipelined one, which is what the two-instruction sequence costs anyway.

**§7.3's fault matrix gains one row**, for this group and no other.

### 4.10 Floating point — `0x24`–`0x27`, `FESC` at `0x10`

`binary64` gets first-class opcodes, since on a 64-bit machine it is the common case:

| Op | | Op | |
|---|---|---|---|
| `0x24` | `FADD` | `0x26` | `FMUL` |
| `0x25` | `FSUB` | `0x27` | `FCMP` |

**Spelling.** A floating-point operation is the integer operation with an `f` in front (`FADD`, `FSUB`, `FMUL`, `FDIV`, `FSQRT`, `FMADD`, `FABS`, `FMIN`, `FMAX`, `FCMP`, `FCLASS`, `FRINT`…). The default width is `binary64`, the machine's native float; any other width is a **decimal suffix in bits**: `FADD` is `binary64`, `FADD32` is `binary32`, and `FADD16` is `binary16` (half precision, below). The rounding variants of `FRINT` are one letter (`FRINTZ`, `FRINTM`, `FRINTP`, `FRINTA`, below). The older spellings (`FADDD`, `FADDS`, `FMIND`, `FRINTDZ` …) are assembler aliases for the new ones under the rule of §4.15; the disassembler never prints them.

Four, not six. `FDIV` and `FSQRT` moved to `FESC` in revision 20 (§4.3): both are multi-cycle sequencer operations that rarely appear in a two-byte register-to-register form, so the extra parcel of decode is free against their latency.

**`FCMP rd, rm` is register-first, like `CMP`**: it computes `rd − rm` (§4.2). It sets `N` if `rd < rm`, `Z` if they are equal, `V` if they are unordered, and clears `C`. The signed branches do not yet separate "unordered" cleanly (`BLT` after an unordered compare takes `N xor V` = 1); that is open item 7 of §12.

`FESC` at `0x10` has parcel 1 carrying an 8-bit sub-opcode plus two more register fields — so four register operands are available at `len = 01`. **Operand roles:** parcel 0's `reg` is the destination, `low` the first source, parcel 1's `t` the second source and `x` the third. The assembler writes the destination last.

- **Divide and square root**: `FDIV`, `FSQRT`, and the `binary32` forms `FDIV32`, `FSQRT32`. `FDIV rs, rd` is `rd ← rd / rs`, and `FDIV32` likewise.
- **Fused multiply-add**: `FMADD rs, rt, ru, rd` = `rs·rt + ru`; `FMSUB` = `rs·rt − ru`; `FNMADD` = `−(rs·rt) − ru`; `FNMSUB` = `−(rs·rt) + ru`; each rounded once; and the `binary32` forms (`FMADD32`…). *See §9.7 — their absence through revision 12 was the worst gap in the floating-point set.*
- **`binary32`**: `FADD32`, `FSUB32`, `FMUL32`, `FDIV32`, `FSQRT32`, `FCMP32`.
- **Sign and selection**: `FNEG`, `FABS`, `FCOPYSIGN rs, rt, rd` (the magnitude of `rs` and the sign of `rt`), `FMIN`, `FMAX`. `FNEG`, `FABS` and `FCOPYSIGN` work on the bits and do not canonicalize a NaN.
- **Classification**: `FCLASS`, `FCLASS32` — a bit vector distinguishing signaling NaN, quiet NaN, ±infinity, ±normal, ±subnormal, ±zero. Every libm function begins with this dispatch.
- **Rounding to integral**: `FRINT` (to nearest, ties to even), `FRINTZ` (toward zero), `FRINTM` (toward −∞), `FRINTP` (toward +∞) and `FRINTA` (to nearest, ties away from zero, for C's `round()`). `FRINTA` is one more qualifier of the round operation and adds no operation.
- **Conversions**: `FCVTDQ` and `FCVTQD` (`binary64` to and from signed quad), `FCVTDS` and `FCVTSD` (between `binary64` and `binary32`), `FCVTSL` and `FCVTLS` (the `binary32`/long pair), and the unsigned 64-bit pair `FCVTDQU` (`binary64` to unsigned quad, truncating; an out-of-range value or NaN raises `NV` and saturates to 0 or 2⁶⁴ − 1) and `FCVTQUD` (unsigned quad to `binary64`, rounding to nearest even). C needs both unsigned conversions; without them each is a compare, a branch and several instructions.
- **`binary16` (half precision)**: seventeen `FESC` words in the block `0x50`–`0x65`, which was free: `FADD16`, `FSUB16`, `FMUL16`, `FDIV16`, `FSQRT16`, `FCMP16` (`0x50`–`0x55`); `FMADD16`, `FMSUB16`, `FNMADD16`, `FNMSUB16` (`0x58`–`0x5B`); `FCLASS16` (`0x5C`); and the conversions `FCVTSH` (`binary32` to half), `FCVTHS`, `FCVTDH` (`binary64` to half), `FCVTHD`, `FCVTHL` (half to int32, toward zero) and `FCVTLH` (`0x60`–`0x65`). Operand roles are those of the `binary32` words (`FCMP16 rd, rs` is register-first; the fused forms take `rs, rt, ru, rd`). A half lives in the low 16 bits of a register, sign-extended to 64 as a `binary32` is. Results are correctly rounded to nearest even; the flags of §4.10.1 are raised by the rounding, tininess judged after rounding. A half-to-int32 conversion of a NaN or an infinity is invalid and saturates; truncating a fraction is inexact. A NaN result is the canonical `0x7E00`. The set is the `binary32` set minus what a half has little use for (`FMIN`, `FMAX`, `FRINT*`, `FNEG`, `FABS`, `FCOPYSIGN` can be done on the bits or after a conversion), so the decode and hardware are the existing ones with a different width, and the conversions to and from both wider formats and int32 are the part machine-learning code needs most. Left open: half `FMIN`/`FMAX`/`FRINT*`, `FNEG16`/`FABS16`, conversions to and from int64 and unsigned, and bfloat16 (a different format: 8 exponent bits, 7 fraction bits) (§12).
- **`FSFLAGS`**, below.

**Dropped: the reciprocal and reciprocal-square-root estimates (`FRECPED`, `FRSQRTED`), which earlier text listed here as Newton–Raphson seeds.** `FESC` sub-opcodes `0x40` and `0x41` were free again after they were removed (`0x40` has since been taken by `FSFLAGS`). §9.9 gives the reason.

#### 4.10.1 Exception flags: `FPSR` and `FSFLAGS`

IEEE 754 requires five status flags — invalid operation, division by zero, overflow, underflow, inexact — and C99 `<fenv.h>` needs software access to them. Revision 20 mentioned none of this. The machine has a sticky five-bit register, **`FPSR`**, laid out as RISC-V's `fflags`:

| Bit | Flag | Meaning |
|---|---|---|
| 0 | `NX` | inexact |
| 1 | `UF` | underflow |
| 2 | `OF` | overflow |
| 3 | `DZ` | divide by zero |
| 4 | `NV` | invalid operation |

Every floating-point operation that can raise one of these ORs it into `FPSR` and **never traps**. One instruction reads and writes the register: `FSFLAGS rs, rd` (`FESC` sub-opcode `0x40`) does `rd ← FPSR; FPSR ← rs & 31`. A clear is a swap with zero, a test-and-clear is a swap with zero, a set is a swap with the bits. `FPSR` is part of the thread context and is saved with the `PSW`. It is not a mode: it never changes what an instruction does, only records what an instruction did, so §1's "no mode bits" is untouched. Details: tininess is detected after rounding; a comparison (`FCMP`, `FCMP32`, `FMIN`, `FMAX`) raises `NV` only for a signaling NaN, not for a quiet one.

#### 4.10.2 NaN results are canonical

Every arithmetic or conversion result that is a NaN is the **canonical quiet NaN** — `0x7FF8000000000000` for `binary64`, `0x7FC00000` for `binary32`, `0x7E00` for `binary16` — whatever the operands carried: there is no payload propagation (the RISC-V rule). Without a rule the result would depend on the host that ran an emulator (x86 makes a negative NaN for 0/0), and hardware must do the same for results to match the reference emulator.

**There are no rounding-mode or precision mode bits.** Precision is in the opcode; rounding mode is in the opcode wherever it is not round-to-nearest-even. Revision 4 killed `FPS.FD/FL/FT` on the grounds that whether `ADD` means single or double must not be invisible state you save and restore. The rule holds, and §15 notes that this leaves us diverging from LoongArch, RISC-V, ARM and x86 alike. **One gap in the rule is open:** IEEE 754 also requires directed rounding (toward +∞, −∞, zero) for the arithmetic operations, and the opcode list has no such variants except the `FRINT*` family. See §12 item 13.

**There are no transcendental instructions**, and this is deliberate rather than an omission; §9.7 has the argument.

### 4.11 System and atomic escapes — `SYS` at `0x14`, `ATOM` at `0x11`

`SYS` at `0x14`: `RTI`, `RTT`, `RET`, `HALT`, `MTPS`, `MFPS`, `SPL`, `TRAP #n`, `TRAPL #n`, `BPT`, `TLBI`, `TLBIA`, `TLBSYNC`, `MTASID`, `MFASID`, `MTDP`, `MFDP`, `MTDMW`, `MFSR`, `MTSR`, `MFCPUID`, `ICINV`, `ICINVA`, `FENCE`, `WFE`, `SEV`, `LPAD`, `PROBER`, `PROBEW`, `NOP`.

**Its layout.** The `reg` field is a 4-bit **class**. The `rm` field (`low`) is a register operand, a 4-bit immediate (`SPL`, `TRAP` 0–15) or, in class 0, the minor opcode of the instructions that take no operand. (Earlier text said `reg` and `rm` combined into eight bits of sub-opcode, §4.3.1 that `SYS` takes its sub-opcode from `reg` alone, and §4.11.1 that `TRAP #n` is two bytes with 256 vectors; the three cannot all hold, §9.9.)

| Class (`reg`) | Instruction | Class (`reg`) | Instruction |
|---|---|---|---|
| `0` | no operand; minor in `rm` | `8` | `MTDP` |
| `1` | `MTPS` | `9` | `MFDP` |
| `2` | `MFPS` | `10` | `MTDMW` |
| `3` | `SPL #n` | `11` | `MFCPUID` |
| `4` | `TRAP #n` | `12` | `ICINV` |
| `5` | `TLBI` | `13` | `PROBER` |
| `6` | `MTASID` | `14` | `PROBEW` |
| `7` | `MFASID` | `15` | `TRAPL #n` |

Class 0 minors: `0` `NOP`, `1` `RTI`, `2` `RTT`, `3` `RET`, `4` `HALT`, `5` `BPT`, `6` `FENCE`, `7` `WFE`, `8` `SEV`, `9` `LPAD`, `10` `TLBIA`, `11` `TLBSYNC`, `12` `ICINVA`, `13` `MFSR`, `14` `MTSR`; `15` is free. Where the operand is a register or a 4-bit number the instruction is two bytes. The classes that need a second operand are four bytes: `PROBER` and `PROBEW` carry the second register in parcel 1, and `TRAPL` carries its vector number in parcel 1.

**`TRAP #n` is split.** `TRAP #n` for `n < 16` is two bytes (class 4, `n` in the `rm` nibble). `TRAPL #n` (class 15, `len ≥ 01`, `n` in the high byte of parcel 1) reaches vectors 0–255 in four bytes. The assembler picks. This keeps both aims — 256 vectors, and the common case in two bytes — at the cost of a second mnemonic.

**`MFSR rd, name` and `MTSR name, rs`** (2026-10-22, errata 32) read and write a **system register** chosen by name. Both are privileged (an abort outside kernel mode, §7.1) and four bytes: parcel 0 `01 SYS 0 minor`, parcel 1 `sr:8 r:4 pad:4`. The registers: `ptbr` 0 (page-table base), `epc` 1 (exception program counter), `eva` 2 (faulting address, read only), `ecause` 3 (cause, read only), `dmw0` 4 and `dmw1` 5 (the direct mapping windows, §8.3), `usp` 6 and `ssp` 7 (the user and supervisor stack pointers, whose copies `R14` does not name outside their mode). A write to a read-only register, or a number that is not assigned, is an illegal-instruction abort. The reason there is one general pair: all sixteen classes were taken, and eight bits of register number leave room for the registers still to come (a vector base, a timer compare, an interrupt mask). What `epc`, `eva` and `ecause` contain is defined with the exception entry sequence, which is not yet written ([`pdp64-system-architecture.md`](pdp64-system-architecture.md) §4).

#### 4.11.1 Four PDP-11 instructions dropped in revision 17

`IOT`, `EMT`, `WAIT` and `RESET` are gone. All four were carried forward out of sentiment rather than need.

**`IOT` and `EMT` are `TRAP #n` under other names.** On the PDP-11 they were separate one-word opcodes because the frequently-used trap vectors deserved short encodings — `EMT` was RT-11's system-call entry, `IOT` some monitors'. `TRAP #n` and `TRAPL #n` here reach 256 vectors (two bytes for the first sixteen), so a dedicated opcode for two particular values of *n* buys nothing. The vectors themselves remain; only the aliases are gone.

**`WAIT` is subsumed by `WFE`.** `WAIT` sleeps until an interrupt; `WFE` sleeps until an interrupt *or* another core's `SEV`. On a uniprocessor there is no `SEV`, so `WFE` behaves exactly as `WAIT` did. Revision 15 kept both and gave the reason as PDP-11 continuity, which is not a reason. The assembler still accepts `WAIT` as an alias for `WFE` (§4.15).

**`RESET` asserted the Unibus `INIT` line.** Resetting the bus is a device operation and belongs in a Q64 bus-controller register, not in the instruction set — §16 says the architecture owes devices a memory type, an ordering instruction and atomics, and nothing else. A privileged instruction whose entire semantics are "poke the interconnect" is bus policy smuggled into the ISA.

**`BPT` stays, and for a specific reason.** It is also just a trap vector, but a debugger patches it over an existing instruction, so it must be *the shortest instruction the machine has* or it cannot overwrite a two-byte one. At `len = 00` in `SYS` it is exactly two bytes, which is the minimum. That is a structural requirement `TRAP #n` happens to satisfy too, but `BPT` makes it explicit and conventional.

Likewise `RTT` stays despite looking redundant against `RTI`: it sets the `T` bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler instead of trapping immediately on the first instruction back. A subtle distinction with a real user.

And `SPL` stays despite `MTPS` writing the whole `PSW`: it sets the priority field alone, leaving the condition codes untouched. A kernel raising priority around a critical section must not clobber flags, and with only `MTPS` that would be a read-modify-write.

**`PROBER` / `PROBEW Rd, Rs`** — test whether the address in `Rs` (the `rm` field) is readable (writable) in the current previous-mode, without faulting. `Rd` (named in parcel 1) ← 0 or 1. Taken from VAX, where `PROBER`/`PROBEW` let a system service validate a user-supplied address before touching it. This replaces the `nofault` global hack that V6 and V7 `trap.c` need (§7.1) for the address-validation case, leaving `nofault` for genuine hardware probing.

`ATOM` at `0x11`. Each operation has a plain form and a `_DB` form that folds a full barrier in:

| Sub-op | Operation |
|---|---|
| `CAS`, `CASDB` | compare and swap |
| `SWAP`, `SWAPDB` | exchange |
| `XADD`, `XADDDB` | fetch and add |
| `XAND`, `XOR_`, `XXOR` + `_DB` | fetch and and/or/xor |
| `XMAX`, `XMIN`, `XMAXU`, `XMINU` + `_DB` | fetch and min/max |
| `LL`, `SC` | load-linked, store-conditional |

The barrier-fused variants are LoongArch's pragmatism (§15): a lock acquire is one instruction rather than an atomic followed by a `FENCE`, which matters because that pair is in every critical section in the system. The `LL`/`SC` pair is retained for the operations `CAS` cannot express — multi-word updates and the ABA-sensitive cases.

### 4.12 Arithmetic escape — `AESC`, `0x0E`

The arithmetic that is rare enough not to need a two-byte form. Parcel 0's low nibble is a **register**, as in `BESC`.

| Sub-op | Operation |
|---|---|
| `DIV`, `DIVU` | quotient, signed and unsigned |
| `MOD`, `MODU` | remainder, signed and unsigned |
| `MULHU` | high 64 bits of an unsigned product (§4.2.2) |
| `MULHSU` | high 64 bits of signed × unsigned — reserved, see below |
| `ABS Rs, Rd` | absolute value |
| `MIN`, `MINU`, `MAX`, `MAXU Ra, Rb, Rd` | minimum and maximum; the `U` forms compare unsigned |
| `SET cc, Rd` | `Rd ← 1` if the condition holds, `0` if not |

`ABS`, `MIN`, `MAX` (sub-opcodes `0x08`, `0x10`–`0x13`) are the integer counterparts of `FABS`, `FMIN` and `FMAX`, so by the folding rule (integer versus float, and signed versus unsigned, are qualifiers) they add no operation. Flags: `ABS` sets `N` and `Z` from the result and `V` when the operand is the most negative number (whose absolute value is itself, the result wrapping), and leaves `C`; `MIN` and `MAX` set `N` and `Z` from the result, clear `V` and leave `C`. The hardware reuses the negate path and the compare of `SUB`/`CMP` with a 64-bit select (estimated at 150–250 LUTs).

**`SET cc, Rd`** (sub-opcode `0x20`) is the first instruction written with a condition word: `SET EQ, R1`. The condition is the `x` field of parcel 1, numbered as the low nibble of the branch opcodes (§4.4); `SET` changes no flag. The condition words are reserved only in that position — a label may still be called `eq` or `lt`.

New in revision 20, and **net negative in opcodes**: it costs one slot and lets `MOD`, `MODU` and `MULHU` leave `BESC`, where arithmetic never belonged thematically. `DIV` and `DIVU` arrive from the ALU group.

Demoting divide is the one place in the regroup that costs a real two-byte form (§4.3), and it is affordable for a specific reason: **compilers turn division by a constant into `MULH` plus a shift**, which is why `MULH` stays in the ALU group while `DIV` does not. A genuine runtime-variable divide is rare, and a 32-cycle non-restoring sequencer does not notice one extra parcel of decode.

`MULHSU` — signed times unsigned — is needed only where a bignum's signed top limb meets an unsigned one. It stays reserved rather than committed, since it can be synthesized with one correction step and the only caller is a bignum library's innermost loop.

### 4.13 Memory escape — `MESC`, `0x0F`

Operations on memory that are not plain moves. Parcel 0's low nibble is a **mode**, as in the ordinary memory format, so parcel 1 is `subop(4) rm(4) disp(8)` — sixteen sub-opcodes and a ±128-byte displacement at `len=01`, widening to 8 / 24 / 40 bits at `len` 01 / 10 / 11. Only the modes whose payload fits that way are legal: base, direct page, post-increment, pre-decrement, PC-relative and absolute. The scaled-index mode is not available in `MESC`, for want of room for `Rx` and the scale.

| Sub-ops | Operation |
|---|---|
| `MOVUB` `MOVUW` `MOVUL` `MOVUQ`, both directions (8) | the explicit unaligned data forms (§7.4) |
| `ADDM` `SUBM` `BICM` `BISM` (4) | `rm ← rm op reg`, read-modify-write on memory |
| 4 spare | |

The four read-modify-write forms were top-level opcodes `0x20`–`0x23` through revision 19 and **lose nothing by being here**: a memory destination means `len ≥ 01` regardless, so they were never two bytes. §4.3 has the general argument.

Write permission is checked during the read access, so the write cannot fault after the read has succeeded — §7.3's row 3 stays zero.

Note what is *not* here, because `SOP` (§4.5) already covers it: `CLR`, `INC`, `DEC`, `NEG` and `COM` on a memory operand are single-operand forms needing no source register, so `INC counter(DP)` is four bytes through `SOP`. `MESC`'s four add the case where the operand comes from a register — `BISM Rmask, flags(DP)` — which `SOP` cannot express.

### 4.14 The escape parcel budget

`BESC`, `MBLK`, `AESC`, `MESC`, `FESC` and `ATOM` each define their own parcel-1 layout, which is what makes them useful and is also the one place the §3.1 length rule could be broken from the inside.

> **Rule.** No escape sub-opcode may consume more extension parcels than `len` declares. A sub-opcode whose operands require *n* extension parcels is encodable only at `len ≥ n`.

`BESC`'s bitfield operations are the worked example: `EXTB`, `EXTZB` and `INSB` need a position and a width beyond the three register fields (and `DSHR` a shift count), so they exist only at `len = 10` and are reserved at `len = 01`.

Nothing structural enforces this. A sub-opcode added later that wants two extension parcels at `len = 01` would leave the fetch length and the decoder's operand expectations silently disagreeing — the fetch unit advances by one extension parcel, the decoder reads two, and the machine executes garbage with no fault raised. It is the only way to make length-from-`len` false, and it would be found in silicon rather than in review.

A second rule, from the same hazard: **whether parcel 0's low nibble is a mode or a register is fixed per escape opcode, not per sub-opcode.** `MESC` reads it as a mode; `BESC`, `MBLK` and `AESC` read it as a register. The six parcel-1 escapes are contiguous at `0x0C`–`0x11` so this distinction is a range compare (§4.3.1). Mixing the two interpretations inside one escape group would make operand decode depend on the sub-opcode in parcel 1, which defeats the point of a fixed-position decode.

Both are small, combinational, and provable; see the implementation plan.

A third rule, from the second page (§4.18): **page 2 has no extension parcels, so nothing in it can break the length rule.** A page-2 instruction is exactly one parcel whatever its opcode; its fields are in parcel 0 and the opcode of §4.18 is independent of the opcode of page 1.

### 4.15 Assembler aliases

Some mnemonics assemble to another instruction rather than to one of their own. These are an assembler table, generated from the same machine-readable specification as the encoder (see the implementation plan), not architecture — but they are part of what "mnemonic compatibility" means in §1, so they belong in the spec.

| Written | Assembles to | Restriction |
|---|---|---|
| `ROL rs, #n, rd` | `RORI rs, #(64−n), rd` | immediate only — see below |
| `BIC #imm, rm` | `AND #~imm, rm` | either spelling accepted; same instruction (not yet implemented by the assembler) |
| `MULU` | `MUL` | sign-agnostic low half (§4.2.2); the old mnemonic is accepted |
| `WAIT` | `WFE` | §4.11.1 |
| `BHIS` / `BCC`, `BLO` / `BCS` | one condition each | already in §4.4 |
| `CBNE` … `CBLOS` and the aliases of the branch group | `CBCC` with the condition of the same name | §4.4.1; a mnemonic, not an alias, in the sense of the next paragraph: one line, one instruction |
| `FADDD`, `FSUBD`, `FMULD`, `FCMPD`, `FDIVD`, `FSQRTD` | `FADD`, `FSUB`, `FMUL`, `FCMP`, `FDIV`, `FSQRT` | the old `binary64` spellings (§4.10) |
| `FADDS`, `FSUBS`, `FMULS`, `FDIVS`, `FSQRTS`, `FCMPS` | `FADD32` … `FCMP32` | the old `binary32` spellings |
| `FMADDD` `FMSUBD` `FNMADDD` `FNMSUBD`; `FMADDS` … `FNMSUBS` | `FMADD` `FMSUB` `FNMADD` `FNMSUB`; `FMADD32` … `FNMSUB32` | |
| `FMIND`, `FMAXD`, `FCLASSD`, `FCLASSS` | `FMIN`, `FMAX`, `FCLASS`, `FCLASS32` | |
| `FRINTD`, `FRINTDZ`, `FRINTDM`, `FRINTDP`, `FRINTDA` | `FRINT`, `FRINTZ`, `FRINTM`, `FRINTP`, `FRINTA` | |

`IOT` and `EMT` were once listed here as aliases of `TRAP #n` at their historical vectors. The instructions were gone in revision 17 and the aliases, which were never implemented, are dropped (§4.11.1).

**Aliases follow one rule:** a word numbered `0x100` above another word of its group stands for that word — one mnemonic, one instruction. The 29 old floating-point spellings and `BHIS`, `BLO`, `MULU` and `WAIT` all use it, and `ROL` uses it with the count complemented. Conversions (`FCVTDQ` …) and the integer widths (`MOVQ`, `MOVL`, `MOVW`, `MOVB`) keep their spellings until a way of writing a width on an integer operation is chosen.

**Two rules keep aliases from becoming a second, undocumented architecture.**

*One mnemonic assembles to one instruction.* `ROL rs, #n, rd` works because the complement is computed at assembly time and the result is a single `RORI`. `ROL` with a register count is **rejected**, with an error naming the two-instruction sequence (`NEG Rk` then `ROR`), rather than quietly emitting two instructions. Anyone counting cycles or sizing a branch displacement must be able to trust that one line of assembly is one instruction, and an assembler that silently expands macros under ordinary mnemonics destroys that.

*The page-2 forms are not mnemonics.* `MOVQ (R3), R1` assembles to the one-parcel page-2 load when the operands fit (§4.18) and to the long form when they do not; there is no `MOVQ2` and no way to ask for either. A mnemonic still assembles to exactly one instruction, and the assembler chooses its length, as it does for branches. The disassembler prints the long-form mnemonic for a page-2 instruction, so reassembling the text reproduces the same one-parcel encoding.

*The disassembler never prints an alias.* `RORI rs, #57, rd` disassembles as `RORI rs, #57, rd`, not as `ROL rs, #7, rd`, so assembling and disassembling round-trips to the same encoding. A disassembler that guesses which spelling the author used is a disassembler whose output cannot be reassembled reliably.

### 4.16 Map summary

Reallocated in revision 20, sorted by tier (§4.3) and grouped by theme.

```
                                                        min
0x00-0x0B   MOV     moves, conversions, LEA              2    §4.1
0x0C        BESC    bit, field, rotate, UTF-8            4    §4.6   ─┐
0x0D        MBLK    block memory                         4    §4.7    │ parcel-1
0x0E        AESC    divide, remainder, abs/min/max, SET  4    §4.12   │ escapes,
0x0F        MESC    unaligned, ALU-to-memory             4    §4.13   │ contiguous
0x10        FESC    FMA, binary32, div, sqrt, classify   4    §4.10   │
0x11        ATOM    atomics, with and without barrier    4    §4.11  ─┘
0x12        XFER    JMPI, CALLI, JTAG                    4    §4.9   ─┐ reg field
0x13        SOP     single-operand, JMP, CALL, PUSH/POP  2    §4.5    │ is the
0x14        SYS     system control, PROBE, SMP           2    §4.11  ─┘ (SYS: class)
0x15        TAGOP   BTAG, BNTAG                          4    §4.8
0x16-0x22   ALU     register destination (13)            2    §4.2
0x23        ────    spare ALU slot (decodes, traps)      ─    §4.2
0x24-0x27   FP      FADD FSUB FMUL FCMP                  2    §4.10
0x28        CBCC    compare immediate and branch         4    §4.4.1
0x29-0x2F   ────    reserved (7)                         ─
0x30-0x3E   Bcc     conditional branches (15)            2    §4.4
0x3F        SOB     subtract one and branch              4    §4.4
```

(The `min` column is the shortest form of the group's common case; `SOB`, `CBCC`, and `PUSHM`/`POPM` in `SOP`, exist only from `len=01`.) This is **page 1**, the map of `len = 00`, `01` and `10`. `len = 11` selects page 2, a separate 64-entry map in §4.18.

**Fifty-six of sixty-four assigned (12 moves and `LEA`, 6 escapes, 4 of `XFER`/`SOP`/`SYS`/`TAGOP`, 13 ALU, 4 FP, `CBCC`, 16 branch), one spare ALU slot (`0x23`), and seven reserved (`0x29`–`0x2F`)** — 56 + 1 + 7 = 64. Reserved went from one scattered slot at revision 19 to eight contiguous at revision 20, and to seven when `CBCC` took `0x28` on 2026-10-22. (Before that change the count was fifty-five assigned and eight reserved; a text of revision 20 once said "fifty-six assigned" before `CBCC` existed, which the map it printed did not add up to.) Besides the reserved slots there are no spare `SOP` slots, four spare `MESC` sub-opcodes, thirteen spare `XFER` sub-opcodes, and roughly 240 in each parcel-1 escape group.

Three properties of the layout, all from §4.3.1:

- **`0x0C`–`0x11` is the parcel-1 escape range.** "Do I read a sub-opcode from parcel 1" is one comparison on bits 13..8, not six matches.
- **`0x12`–`0x14` take their sub-opcode from the `reg` field**, which is already wired to the register file address inputs, so one range compare enables that mux.
- **Every other run's low bits are the operation select**, wired straight to the relevant function mux — twelve moves, fourteen ALU slots, four FP, sixteen branch.

The reserved block stays reserved, except for the one slot `CBCC` took. §12.2's discipline applies to it: a top-level slot is for an operation whose common case is register-to-register, and everything else goes to an escape group.

### 4.17 Encoding conventions: numbers, operand roles, byte order

Revision 20 named the sub-operations of every escape group and numbered none of them, and left unstated which field of an escape instruction is the destination and which a source. These are fixed here. **The numbers are written once, in `spec/pdp64-mnemonics.hbnf`; if this text and that grammar disagree the grammar is right.**

**Sub-opcode numbering.** Related operations share a range.

| Group | Numbering |
|---|---|
| `BESC` | counts `0x00`–`0x08` (`CLZ`, `CTZ`, `CLO`, `CTO`, `POPCNT`, `BSWAP`, `BSWAPW`, `BSWAPL`, `BITREV`); rotate `0x10` (`ROR`), `0x11` (`RORI`), `0x12` (`RORI32`); field and funnel `0x20` (`DSHR`), `0x21`–`0x23` (`EXTB`, `EXTZB`, `INSB`); polynomial and popcount `0x30`–`0x32` (`XNORPOP`, `CLMULL`, `CLMULH`); UTF-8 `0x40`–`0x42` (`UTF8LEN`, `UTF8DEC`, `UTF8ENC`) |
| `MBLK` | `MCPY`, `MMOV`, `MSET`, `MCMP`, `MSCN`, `MSCNN`, `MVAL` = `0`–`6` |
| `AESC` | `DIV` 0, `DIVU` 1, `MOD` 2, `MODU` 3, `MULHU` 4, `ABS` `0x08`, `MIN` `0x10`, `MINU` `0x11`, `MAX` `0x12`, `MAXU` `0x13`, `SET` `0x20` |
| `MESC` | the loads `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ` are 0, 2, 4, 6 and the store form is the load number + 1, as for the moves; `ADDM`, `SUBM`, `BICM`, `BISM` = 8–11 |
| `FESC` | by kind: divide and square root (`0x00`, `0x01`), the `binary32` forms (`0x08`–`0x0D`), the fused multiply-add family (`0x10`–`0x13`, and `0x18`–`0x1B` for `binary32`), sign and selection (`0x20`–`0x24`), classify (`0x28`, `0x29`), round (`0x30`–`0x34`), convert (`0x38`–`0x3F`), `FSFLAGS` `0x40`, `binary16` arithmetic `0x50`–`0x5C` and conversions `0x60`–`0x65` |
| `ATOM` | plain then barrier-fused (`_DB`) pairs, then `LL` `0x20` and `SC` `0x21` |
| `SOP` | `reg` = 0–15 as in §4.5 |
| `SYS` | class and minor numbers as in §4.11 |

At the top level the moves are `0x00`–`0x0B` with the store form always the load opcode + 1; the ALU is `0x16`–`0x22` and the FP four `0x24`–`0x27`; `CBCC` is `0x28` and the branches are `0x30`–`0x3E` with `SOB` `0x3F`. The six parcel-1 escapes are contiguous at `0x0C`–`0x11`, `XFER`, `SOP` and `SYS` adjacent at `0x12`–`0x14` (§4.3.1), and the sixteen branch slots are `0x30`–`0x3F`.

**Which field is which.** For `BESC`, `AESC` and `MBLK` the assembler writes the destination **last**: `op rs, rd`, `op ra, rb, rd`. In the encoding, parcel 0's `reg` is `rd`, `low` is the first source and parcel 1's `t` is the second source. `MBLK` is the exception: `MCPY rd, rs, rn` is *destination pointer, source pointer, count*, with `reg` = destination pointer, `low` = source pointer and `t` = count. `FESC` has a third source in `x` (§4.10). `DSHR ra, rb, #n, rd` takes `low` = `ra`, `t` = `rb` and the count in `pos` of parcel 2; `EXTB`/`EXTZB`/`INSB rs, #pos, #width, rd` take `pos` and `width` from parcel 2. The one assembler exception to destination-last is `CMP`, register first (§4.2).

**Minimum lengths.** `LEA` and `XFER` (`JMPI`, `CALLI`, `JTAG`) are four bytes (they need a memory operand); `SOB`, `BTAG` and `BNTAG` four bytes; `PUSHM` and `POPM` four bytes; `CBCC` four bytes (six for the long displacement); every `BESC` (including `RORI32`), `AESC` and `MBLK` form four bytes; every page-2 form two bytes (§4.18); `DSHR`, `EXTB`, `EXTZB` and `INSB` six bytes (§4.14).

**Byte and bit order.** Data is **little-endian**, which revision 20 never stated. Instruction parcels are 16-bit little-endian units in memory. The diagrams in this document, and the grammar that is the machine-readable form of them, number bits most significant first: a parcel's bit 15 is the first bit of its record.

### 4.18 Page 2: the one-parcel abbreviations — `len = 11`

Added 2026-10-22 (errata 31). Where the fourth parcel used to be, `len = 11` now selects a second page of **one-parcel** instructions, in the layout of §3.1.2:

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+-----+-----------------+-----------+-----------+
| 11  |      opc (6)    |    reg    |    low    |
+-----+-----------------+-----------+-----------+
```

`opc` is a 64-entry opcode map of its own; **41 entries are defined**. `reg` is the register named first in the table, `low` the field named second. The opcode numbers of page 2 are independent of those of page 1: `0x28` of page 2 is `XOR #imm, rd`, while `0x28` of page 1 is `CBCC` (§4.4.1).

**The rule for every page-2 form: it is *exactly* the operation of the page-1 instruction it abbreviates** — the same result, the same flags, the same faults. An assembler that picks the shortest encoding therefore can never change what a program does. A mnemonic still assembles to exactly one instruction (§4.15): the assembler chooses the length, as it does for branches, and the page-2 forms have no mnemonics of their own. Implementations may decode a page-2 form to the long form it abbreviates and execute it with the same logic, so that the semantics are written once.

| Opcode | Instruction | `reg` | `low` | Long form it abbreviates |
|---|---|---|---|---|
| `0x00` `0x02` `0x04` `0x06` | `MOVQ`, `MOVL`, `MOVW`, `MOVB` load: `rd ← M[(rn)]`, sign-extended | `rd` | `rn` | `MOV (rn), rd` (base mode, displacement 0) |
| `0x01` `0x03` `0x05` `0x07` | `MOVQ`, `MOVL`, `MOVW`, `MOVB` store: `M[(rn)] ← rs` | `rs` | `rn` | the same, store |
| `0x08` `0x09` `0x0A` | `MOVZL`, `MOVZW`, `MOVZB` load from `(rn)` | `rd` | `rn` | `MOVZ (rn), rd` |
| `0x0B` | `LEA 8*d(SP), rd` | `rd` | `d` (0 to 15) | `LEA 8*d(SP), rd` |
| `0x0C` `0x0D` | `MOVQ` load from `SP`: offset `8 * ((opc & 1) * 16 + low)`, 0 to 248 | `rd` | offset, low 4 bits | `MOVQ d(SP), rd` |
| `0x0E` | `MOVQ` store to `SP`: offset `8 * low`, 0 to 120 | `rs` | offset | `MOVQ rs, d(SP)` |
| `0x10` `0x11` | `MOVL` load from `SP`: offset `4 * ((opc & 1) * 16 + low)`, 0 to 124 | `rd` | offset, low 4 bits | `MOVL d(SP), rd` |
| `0x12` `0x13` | `MOVL` store to `SP`: offset `4 * ((opc & 1) * 16 + low)`, 0 to 124 | `rs` | offset, low 4 bits | `MOVL rs, d(SP)` |
| `0x14` to `0x17` | `MOVQ` load from `rn` at offset `8 * (1 + (opc & 3))`, i.e. 8, 16, 24, 32 | `rd` | `rn` | `MOVQ d(rn), rd` |
| `0x18` `0x19` | `MOVQ` store to `rn` at offset `8 * (1 + (opc & 1))`, i.e. 8, 16 | `rs` | `rn` | `MOVQ rs, d(rn)` |
| `0x1A` to `0x1D` | `MOVL` load from `rn` at offset `4 * (1 + (opc - 0x1A))`, i.e. 4, 8, 12, 16 for `0x1A`, `0x1B`, `0x1C`, `0x1D` | `rd` | `rn` | `MOVL d(rn), rd` |
| `0x1E` | push registers `R8` to `R15` named by the 8-bit mask `reg:low` (bit *i* is `R(8+i)`) | mask high | mask low | `PUSHM #(mask << 8)` |
| `0x1F` | pop registers, the mask as for `0x1E` | mask high | mask low | `POPM #(mask << 8)` |
| `0x20` | `SUB #(8*n), SP`, `n = reg:low` (0 to 255) | n high | n low | `SUB #(8*n), SP` |
| `0x21` | `ADD #(8*n), SP` | n high | n low | `ADD #(8*n), SP` |
| `0x22` | `MOVQ #imm, rd`, `imm` sign-extended 4 bits (-8 to 7) | `rd` | imm | `MOVQ #imm, rd` |
| `0x23` `0x24` `0x25` | `SHL`, `SHR`, `SAR` by `low` (0 to 15) | `rd` | count | `SHL #n, rd` etc. |
| `0x26` `0x27` `0x28` | `AND`, `BIS`, `XOR` with `imm` sign-extended 4 bits | `rd` | imm | `AND #imm, rd` etc. |
| `0x29` | `ADD #imm, rd`, `imm` sign-extended 4 bits | `rd` | imm | `ADD #imm, rd` |

Notes on the table.

- `0x0C` gives offsets 0 to 120 and `0x0D` offsets 128 to 248 in steps of 8, the low four bits of the offset being `low`. In the same way `0x10`/`0x11` and `0x12`/`0x13` use the opcode's low bit as bit 4 of the offset field.
- The mask of `0x1E` and `0x1F` covers `R8` to `R15` only: all 2,392 push and 2,392 pop sites in the measured corpus used a mask within `R8` to `R15`. The long forms take a 16-bit mask (§4.5) and are unchanged.
- `MOVQ` stores to `SP` have the single opcode `0x0E` (offsets 0 to 120), and `0x0F` is reserved; `MOVL` stores to `SP` have two, `0x12` and `0x13`. Of the stores at `d(rn)` only `MOVQ` has a page-2 form (`0x18`, `0x19`).

**Reserved in page 2:** every opcode not listed — `0x0F` and `0x2A` to `0x3F`, 23 of the 64. **A reserved page-2 opcode is an illegal-instruction abort** (§7.3), as a reserved page-1 opcode is. The reserved entries are for later abbreviations under the same rule; §1.2 rule 3 applies to them as it does to the reserved block of §4.16.

**What the page is worth.** The decision and its reasons are in §9.9 and the history in §9.6. The estimated saving, static counts on the 827-file fair corpus compiled with the optimizing flags (a measurement of the final output of 2026-10-22, 1,672,166 bytes of image): 59,354 sites and 118.6 KB, 7.1% of the image, at two bytes per site. `CBCC` adds 6,390 sites (12.8 KB, 0.8%) and `RORI32` 896 sites (9.0 KB, 0.5%): all together 66,640 sites, 140.4 KB, 8.4%. The estimates are static, the families do not overlap but the interaction of one saving with another was not checked, and the offset and immediate ranges were chosen from the histograms of the same corpus, so the figure is optimistic for other programs.

## 5. Addressing modes

Four bits, in parcel 0 bits 3..0, present only at `len ≥ 01` and only for opcodes that take a mode (§4.14).

| Mode | Syntax | Parcel 1 | Effect |
|---|---|---|---|
| `0000` | `d(Rn)` | `rm(4) d(12)` | base + displacement; `d=0` gives `(Rn)` |
| `0001` | `d(Rn)(Rx*s)` | `rm(4) Rx(4) s(2) d(6)` | scaled index, `s ∈ {1,2,4,8}` |
| `0010` | `d(PC)` | `d(16)` | PC-relative; the base is the first parcel of the instruction, `d` counts bytes (§4.1) |
| `0011` | `d(DP)` | `pad(4) d(12)` | direct page; the four bits that name no register are padding, zero |
| `0100` | `#imm` | `imm(16)` | immediate, sign-extended |
| `0101` | `@abs` | `a(16)` | absolute, sign-extended |
| `0110` | `(Rn)+d` | `rm(4) d(12)` | post-increment by `d` |
| `0111` | `-(Rn)` or `(Rn)-d` | `rm(4) d(12)` | pre-decrement by the operand size (`-(Rn)`) or by `d` (`(Rn)-d`) |
| `1000`–`1111` | | | reserved |

At `len = 10` the payload widens per §3.3; the mode meanings are unchanged. Modes `0010`, `0100` and `0101` reclaim the `rm` nibble and reach 32 bits at `len = 10` (they reached 48 at a `len = 11` that no longer exists). The scaled-index mode gains sixteen displacement bits in the extra parcel (6 / 22).

**Pre-decrement syntax.** Revision 20 wrote mode `0111` as `-d(Rn)`, which is also exactly how a negative base displacement is written. Here `-(Rn)` pre-decrements by the operand size and `(Rn)-d` by an explicit stride, the mirror of `(Rn)+d`; **`-d(Rn)` is always base + displacement**, never a pre-decrement.

### 5.1 Strided autoincrement

Modes `0110` and `0111` have no other use for the displacement field, so it becomes the step. The assembler writes `(Rn)+` and `-(Rn)` for the operand-size default and `(Rn)+8` or `(Rn)-16` for an explicit stride.

This costs nothing. The undo journal (§7.2) records a delta, and a variable delta is the same width as a fixed one — `MMR1` on the PDP-11 recorded an *amount* for precisely this reason. What it buys is strided array traversal in one instruction and a decrementing loop over an array of structures without a separate `ADD`.

### 5.2 What was removed

**Every deferred mode**: `@(Rn)+`, `@-(Rn)`, `@X(Rn)`. On the PDP-11 these were not separate modes at all — the low bit of the 3-bit mode field *was* the deferred bit, so every mode came in a direct and an indirect flavour for free. Elegant, and the single most expensive thing in the encoding, because a deferred mode issues a **second memory reference inside operand evaluation**. That is precisely the machinery that makes VAX costly: a fault can occur mid-specifier, after a register has already been side-effected, at an address that itself came from a load that may also have faulted.

Removing them means operand evaluation performs at most one memory access, address generation is a single adder pass rather than load-then-add, and the undo journal is one entry. The saved bit went into a fourth mode bit, which is why there are eight modes defined and eight in reserve rather than eight total.

The form that mattered, `@#addr`, returns properly as mode `0101`. The dispatch-table idiom that `@(Rn)+` served is covered better by `JTAG` (§6.3). §14.2 covers the rest.

**One case did matter, and revision 18 restored it.** Indirect control transfer through a memory location — the PLT stub of every dynamically linked program and the vtable dispatch of every object system — was two instructions and a scratch register without a deferred form. The `XFER` group (§4.9) is that one case, admitted because no register is written before the deferred load, so the restart problem that motivated this whole removal is structurally absent. The general modes stay gone.

**Zero-cost `(Rn)+` and `-(Rn)`.** Under revision 8 these were one parcel; here all memory addressing is two. The regression is paid off by `PUSH`, `POP`, `PUSHM` and `POPM` at one parcel, which is where those modes were actually being used. General array walking pays one extra parcel, which is the right charge, since the displacement forms usually beat it anyway.

---

## 6. Width, modes, and pointer representation

### 6.1 The three width rules

1. **Registers are 64 bits. There is no other profile.** No prefix, no long mode, no operand-size override. x86's `REX` is a decode tax paid on every instruction of a 64-bit program to retain a 16-bit ancestor nobody runs.
2. **Sizes appear on loads, stores and conversions only** (§4.1), with sign or zero extension in the opcode. The ALU has one width.
3. **Addresses are canonical** — see §6.1.1.

#### 6.1.1 What "39-bit canonical" means

Thirty-nine bits of virtual address is 512 GB, and it is not an arbitrary number: it is what the page table in §8.2 indexes. Three levels of nine bits each, plus a twelve-bit page offset, is 9 + 9 + 9 + 12 = 39. Nine bits per level is itself forced — 2⁹ entries × 8 bytes per entry is exactly one 4 KB page, so every table is one page and the walker never needs a table that straddles.

**Why 39 and not 40, when Q64's physical address is 40 bits.** The one extra bit has nowhere to come from:

| Geometry | VA bits | Cost of getting there |
|---|---|---|
| 4 KB pages, 3 levels | **39** | the chosen point |
| 4 KB pages, 4 levels | 48 | a fourth memory reference on every TLB miss, and another level of tables to allocate |
| 4 KB pages, 3 levels + a 2-entry top | 40 | an entire extra walk level to buy one bit — the worst trade on the table |
| 8 KB pages, 3 levels | 43 | 8 KB pages waste memory on small objects; Alpha made this choice |
| 16 KB pages, 3 levels | 47 | worse internal fragmentation again; ARM offers it |

Forty is simply not a number this page geometry produces, and reaching it would mean paying a full walk level for one bit of address.

**That leaves VA one bit narrower than PA, which is normal and harmless here.** It means the kernel cannot map all of a fully-populated 1 TB physical space into one address space simultaneously; it maps a window instead, which is what every kernel does anyway. x86-64 and AArch64 both ship configurations where PA exceeds VA for the same reason. Against the 1 GB of a DE10-Nano, or 16 GB of a larger board, 512 GB of virtual space is between 32× and 512× the physical memory, so the asymmetry is unobservable.

And by §6.1.1's canonical rule, moving to a four-level table and 48 bits later breaks no program — which is the migration x86-64 cannot make cleanly, because its software did stash things in the high bits.

**Canonical** means bits 63..39 must all equal bit 38; the 64-bit address must be the sign extension of a 39-bit value. Two regions are usable:

```
0x0000_0000_0000_0000 .. 0x0000_003F_FFFF_FFFF    low half,  user
0xFFFF_FFC0_0000_0000 .. 0xFFFF_FFFF_FFFF_FFFF    high half, kernel
```

Anything between the two aborts with `ECAUSE = NONCANON`. This is the same arrangement as AArch64 in its three-level 4 KB configuration — what Linux calls `VA_BITS=39` — and the same rule as x86-64 at 48 bits.

Two benefits, one immediate and one deferred. Immediately, every address adder, TLB tag and comparator carries 39 bits instead of 64. Deferred: software cannot stash tags in the high bits, because an address with anything up there faults rather than working by accident. A later revision can go to a four-level table and 48 bits without breaking any program, which is exactly the migration x86-64 is currently unable to make cleanly because software did stash things up there.

Against Q64's 40-bit physical address, 39 bits of virtual is the right pairing: one bit of headroom, no translation needed for the physical window (§8.3).

### 6.2 Low pointer bits are reserved to software

The natural-alignment rule of §7.4 means any object containing a quad field — every cons cell, every boxed float, every vector header — is allocated on an 8-byte boundary. Bits 2..0 of a pointer to such an object are therefore always zero, and available.

> **Contract.** Bits 2..0 of a quad-aligned object pointer are permanently reserved to software. The architecture will never assign meaning to them, and no future revision may claim one.

This is the Lisp machine lowtag, obtained from allocator discipline rather than from tag hardware. Sixteen-byte allocation, which most collectors want anyway, yields a fourth bit.

Note the source. Two-byte *instruction* alignment (§3.2) frees bit 0 on code pointers only; nothing in the ISA constrains where a `char*` may point. The three bits above come from the data-alignment requirement, not from the instruction encoding.

**The displacement field absorbs the tag.** Untagging costs no instruction and no cycle, because the offset the instruction was going to carry anyway is simply biased:

```
        ; R1 holds a cons pointer, lowtag = 1
        MOVQ    -1(R1), R2      ; car
        MOVQ    7(R1), R3       ; cdr
```

Both are two parcels. Different tags are different constants folded into a 12-bit signed field. `JMP -k(Rn)` works identically for tagged function pointers, since `JMP` targets the effective address.

**The alignment abort is the tag check.** Dereferencing a tagged pointer without biasing the displacement produces `ECAUSE = ALIGN` rather than a value read one to seven bytes off. This is tag checking on every quad access at no cost: no comparator, no tag bits in the datapath or the TLB, and no hardware that knows what a tag is.

Hardware tag checking on dereference — the actual Lisp machine feature — is not provided. It costs a comparator, tag bits in the datapath and a trap path, to buy what the above already gives approximately for free. Nor is there a load form that ignores the low bits: that would delete the alignment fault, which *is* the tag check, and convert a corrupted tag from a trap into silent corruption.

**Why bit 0 is safe here and is not on ARM.** ARM has 2-byte instruction alignment too, and spent bit 0 on Thumb interworking: `BX` with bit 0 set switches instruction sets. Software can never reclaim it. That mistake is foreclosed here by the founding rule — compatibility is conversion instructions, never mode bits — which rules out an interworking bit before it can be proposed.

The asymmetry with §6.1 rule 3 is deliberate. Low bits are earned by allocator discipline and granted to software permanently. High bits are architecturally refused, so the address space can be widened later without breaking every runtime that got greedy.

### 6.3 Instructions that make tagged pointers cheap

§6.2 makes tagged pointers *possible* at no cost. Three additions make them *cheap*, which is a different claim. Taking a plausible lowtag assignment — fixnum 0, cons 1, symbol 2, closure 3, string 4, vector 5, flonum 6, other 7 — here is what a runtime actually does all day:

| Operation | Without | With |
|---|---|---|
| extract tag | `AND #7, Rn` → `Rt` | same, 4 bytes |
| test one type | `AND #7`, `CMP Rt, #tag`, `BEQ` — 3 instructions | **`BTAG Rn, #1, cons_case`** — 1 instruction, 4 bytes |
| dispatch on type | bounds check, scale, load, jump — 4 instructions | **`JTAG typetab(Rb)(Rn*8)`** (§4.9; the scale is ignored, `Rn` is the tagged register) — 1 instruction |
| `car` | bias the displacement | `MOVQ -1(R1), R2` — already free |
| fixnum arithmetic | untag, add, retag | `ADD` — already free, tag 0 |
| fixnum overflow | compare against bounds | `BVS` — already free |
| type error on deref | explicit check | `ECAUSE = ALIGN` — already free |

**`BTAG`/`BNTAG`** (§4.8) is a 3-bit comparison on the low bits of a register plus a branch — perhaps 20 LUTs, since the comparator is three XORs and an AND, and the branch path already exists. It collapses the commonest three-instruction sequence in a dynamically typed runtime to one.

**`JTAG`** (§4.9) is the eight-way dispatch at the top of `eval`, at the top of the garbage collector's scan loop, and at the top of every `print`, `equal` and `hash`. It is also what the PDP-11's `@(Rn)+` was really used for, done properly: one instruction, no pointer to maintain, bounds-safe because three bits cannot index outside eight entries.

Setting **fixnum to tag 0** is what makes the rest fall out: tagged fixnums add and subtract directly with no untagging, `V` reports overflow, and `BTAG Rn, #0` is the fixnum test. This is SBCL's arrangement and it is the right one.

What is deliberately *not* provided: a fused allocation instruction, and a store with a built-in GC write barrier. Both would bake a particular allocator or collector design into the architecture, and both are three or four ordinary instructions. The line is that the architecture supports tagging without knowing what the tags mean.

---

## 7. Faults and restart

This section is why the rest of the design looks the way it does.

### 7.1 Four categories

| Category | Instruction | PC on entry | Restartable |
|---|---|---|---|
| **Trap** | completes | next instruction | n/a |
| **Abort** | annulled, no architectural effect | the faulting instruction | yes, by `RTI` |
| **Progress** | partially complete, progress in registers | the faulting instruction | yes, by `RTI` — §7.5 |
| **Machine check** | indeterminate | best effort in `EPC` | no |

Traps: `TRAP #n`, `TRAPL #n`, `BPT`, the T-bit, enabled arithmetic traps. Floating-point exceptions are not among them: they set a flag in `FPSR` and never trap (§4.10.1).

Aborts: page not present, protection violation, non-canonical address, misalignment, reserved instruction, privileged instruction in user mode, divide by zero, landing-pad violation.

Progress: the `MBLK` operations of §4.7, and nothing else.

Machine checks: Q64 timeout on a posted write, uncorrectable ECC, parity. These are the descendants of the PDP-11's vector 004 bus error and, like it, are not restartable. The `nofault` idiom from V6/V7 `trap.c` — set the global, do the probe, longjmp out of the handler instead of panicking — remains the correct kernel-side pattern for hardware probing, though `PROBER`/`PROBEW` (§4.11) now covers the address-validation case properly.

**Loads and instruction fetches never produce machine checks for nonexistent memory.** A Q64 read timeout is reported as an abort with `ECAUSE = BUSFAULT`, precisely, at the faulting instruction. A deliberate improvement on the PDP-11, where a read timeout was an unrestartable bus error and therefore fatal to the process. Only posted writes remain imprecise, and a `FENCE` before a probe makes even those precise at a known point.

### 7.2 The undo journal

The PDP-11 recorded autoincrement and autodecrement side effects in `MMR1` — two entries, each a 5-bit signed amount and a 3-bit register number — captured `MMR2` at every instruction fetch, and left the *undo* to software: read the journal, reverse the deltas, restart at `MMR2`. An excellent trade in 1972. A shift register and a latch, against VAX's per-instruction saved microstate and the `PSL<FPD>` machinery.

Two entries sufficed because a PDP-11 instruction has at most two specifiers, each performing at most one register side effect. The journal was **bounded by the encoding**. VAX had no such bound, which is exactly why it needed resumable microstate instead.

The one-memory-operand rule makes the bound tighter. Only `rm` may be a memory mode, so an ordinary instruction performs **at most one** register side effect — even with the strided modes of §5.1, where the delta is larger but there is still only one. One entry is small enough that it should not be exposed to software at all:

> **Rule.** The register update from mode `0110` or `0111` is buffered and committed at instruction retirement. An abort discards the buffer. Software observes a precise exception at an instruction with no partial effects, and the handler repairs the mapping and executes `RTI`.

No `MMR1`. No undo protocol. No errata about journal overflow.

### 7.3 The fault matrix

Every faulting reference an ordinary instruction can make, exhaustively:

| # | Reference | Max faults | Notes |
|---|---|---|---|
| 1 | instruction fetch | 2 | at most 3 parcels = 6 bytes at 2-byte alignment, spanning at most 2 pages (unchanged by the removal of the fourth parcel; a page-2 instruction is one parcel) |
| 2 | operand read | 2 | at most 8 bytes; 2 pages only via the explicit unaligned forms |
| 3 | operand write | 0 | by construction |
| 4 | branch target load | 2 | the `XFER` group only (§4.9.1); no register is written before it, so a fault here is a clean abort |

Row 3 is zero because for any read-modify-write — `ADDM` and its group, or a single-operand op with a memory destination — **write permission is checked during the read access**. If the page is absent or read-only, the abort happens before any state changes. If the read succeeds, the write cannot fault.

That is the entire restart problem for ordinary instructions, closed, on one page. The `MBLK` group is the exception and has its own rule.

### 7.4 Data alignment

Natural alignment is **required** for word, long and quad *data* accesses. Misalignment aborts with `ECAUSE = ALIGN`.

This removes the unaligned path entirely: no rotator on the load return, no dual-access sequencer, no cross-line splice. For cases that genuinely need it — packed on-disk structures, network headers, the kind of thing `filsys` deals with constantly — `MESC` (§4.13) provides explicit `MOVU*` forms that perform the two accesses in a defined order and restart by the same rules.

The capability is an instruction, not a mode bit that changes what every other instruction means.

Two adjacent points, both load-bearing elsewhere:

- This is **data** alignment only. Instructions are parcel-aligned and unconstrained beyond that (§3.2). The two rules are independent and neither implies the other.
- The quad-alignment requirement is what makes §6.2 work, and the `ALIGN` abort is the specified tag-mismatch signal. **This rule may not be relaxed to permit unaligned quad accesses** (§1.1). Doing so would silently break every tagged runtime built on the architecture, which is a far larger cost than the rotator and dual-access sequencer it would save.

Byte accesses are unconstrained, so the `MBLK` operations of §4.7 have no alignment requirement at all.

### 7.5 Progress-restartable instructions

The `MBLK` group of §4.7 cannot satisfy §7.3. It makes an unbounded number of memory references and updates three registers. Its restart rule instead:

> **Rule.** An `MBLK` instruction is interruptible. At every point at which an exception may be taken, `Rd`, `Rs`/`Rv` and `Rn` hold state consistent with byte-at-a-time progress through the operation, and all remaining work is described by those registers. `PC` addresses the `MBLK` instruction itself. An abort or interrupt is taken with that state committed; `RTI` resumes the operation with no special handling, because re-executing the instruction with the updated registers *is* resumption.

What this costs, written down as §1.1(b) requires:

- **The fault count is unbounded.** An `MCPY` of 1 MB may take 256 page faults. Each one is individually precise and individually cheap; there is no accumulation.
- **Three registers are written**, not one, so the §7.2 buffer-and-commit arrangement does not apply. `MBLK` commits directly and must commit all three atomically with respect to interruption.
- **The source registers are destroyed.** A caller that needs the original pointers must keep copies. This is the price of having no hidden state, and it is a one-line note in the ABI rather than a hardware cost.
- **Worst-case latency is not bounded by the instruction.** This is the realtime concern, and it is why the rule says *interruptible* rather than *atomic*: the maximum interrupt latency is the implementation's block size, not the operation's length. An implementation claiming a latency bound must state its `MBLK` block granularity. See §12.5.

In exchange: `memcpy`, `memmove`, `memset`, `bzero`, `memcmp`, `memchr` and `strchr` are each one instruction, the implementation may run them at full memory bandwidth, and none of them needs a loop in software or a hidden microstate register in hardware.

---

## 8. Memory management

### 8.1 What survives from the 8722

The 16-bit 11/64 took two ideas from the C128 MMU: **map sets**, four shadow copies of the whole relocation register file selected by one store to `MAPSEL`, giving a constant-time context switch; and **`MMCOM`**, an explicit common region immune to remapping in every map set and every mode, making the map switch safe by construction rather than by care.

Neither survives literally — four shadow copies of a page table over a 39-bit address space is not a thing. Both survive functionally, in strictly better form:

| 16-bit 11/64 | pdp64 | Property preserved |
|---|---|---|
| four map sets, `MAPSEL` | **ASID**, 16 bits, `MTASID` | constant-time context switch: one store, zero flushes |
| `MMCOM` common region | **`G` bit** per page table entry | kernel text, vectors and trap stubs immune to address-space change, by architecture |

The realtime property that motivated map sets — a bounded, constant-cost context switch, belonging on the list with priority inheritance and preemption points — is preserved exactly. The `G` bit does what `MMCOM` did: entries so marked ignore the ASID and survive every switch, so the code performing the switch cannot unmap itself.

### 8.2 Translation

Three-level, 4 KB pages, 9 + 9 + 9 + 12 = 39-bit VA (§6.1.1). Large-page leaves at level 1 (2 MB) and level 2 (1 GB) to preserve TLB reach. Hardware table walker.

A software-refilled TLB (MIPS R2000, Alpha PALcode) removes the walker state machine entirely and saves perhaps three to five thousand transistors. With a three-level table the miss handler runs often enough and long enough that the walker pays for itself; on a two-level table it would not.

Page table entry attributes:

| Field | Width | Meaning |
|---|---|---|
| `V` | 1 | valid |
| `R` `W` `X` | 3 | read, write, execute permission |
| `U` | 1 | user-accessible |
| `G` | 1 | global — ignores `ASID` (§8.1) |
| `A` `D` | 2 | accessed, dirty |
| **`MT`** | **2** | **memory type — new in revision 13** |

`MT` values: `00` normal cached write-back, `01` normal uncached, `10` device strongly-ordered, `11` device weakly-ordered.

Revision 12 had no memory-type field, which would have been discovered by whoever first mapped a framebuffer and found their writes sitting in the D-cache. A framebuffer written by the CPU and scanned out by a raster engine, or filled by a blitter and read back by the CPU, needs either an uncached mapping or explicit flushes — and uncached-by-attribute is the right answer, because it is per-page rather than per-access and needs no cooperation from the code doing the writing. The four values are ARM's memory types and LoongArch's `DMW` cache attributes, reduced to the set that is actually distinguishable on a machine of this size.

### 8.3 Direct mapping windows

Two windows, `DMW0` and `DMW1`, each configured with a virtual base, a size and an `MT`. An address falling in a window translates as

```
PA = VA − VirtualBase + PhysicalBase
```

with no page table reference, no TLB entry consumed and no walk. Permission is kernel-only.

This is LoongArch's `CSR.DMWn`, whose rule is simply `VA = PA + FixedOffset`, and it is the better-designed descendant of MIPS's `KSEG0`. Three reasons it belongs here:

1. **The kernel stops taking TLB misses on its own text and data.** For a machine whose realtime story rests on bounded worst-case paths (§12.5), removing the page walker from the kernel's own execution is worth more than its cost, which is one comparator pair and one adder.
2. **Physical memory is reachable without mapping it**, which is what a driver writing a DMA descriptor, a debugger reading a page frame, and a bootstrap before the page tables exist all need.
3. **Early boot becomes trivial.** The machine comes up with `DMW0` covering physical memory, so there is no chicken-and-egg problem in setting up the first page table.

`G`-bit entries and `DMW` overlap in purpose but not in kind: `G` keeps a *mapped* page present across address-space changes, `DMW` removes a region from mapping altogether. The kernel wants both — `DMW` for its static text and physical access, `G` for the vectors and trap stubs that must remain at fixed virtual addresses with ordinary permissions.

---

## 9. Rationale for the contested decisions

### 9.1 Sixteen registers, not eight

The 6502 has three architectural registers and compensates with zero page. Correct in 1975, when a register bit cost roughly a logic gate and 256 bytes of static RAM was cheaper than eight more registers.

Not correct now. A 16 × 64-bit file with two read ports and one write port is a few thousand transistors — among the cheapest structures on the die, and far cheaper than the spill traffic eight registers would generate. The register file was never where the transistors went. Control was.

What does transfer from the 6502 is the direct page as a **density** mechanism, which is why mode `0011` exists.

### 9.2 One memory operand

§3.4 and §7.3. The load-bearing decision of the whole design, and §4.7 is its one admitted exception.

### 9.3 The PC is not a register, and `R7` is not a read-only view of it

`R7`-as-`PC` is the prettiest thing in the PDP-11, and giving it up is the most painful choice here. Immediate, PC-relative and absolute addressing all fall out of ordinary modes applied to an ordinary register, with no dedicated encoding at all.

**The cost of a writable PC in the register file:**

- The general write port can target the PC, so **every register write is a potential branch**. Nothing may be committed to the register file before it is known that the instruction did not redirect control, which pulls branch resolution to writeback and puts the next-PC mux downstream of the whole datapath.
- Hazard logic must compare every destination against `R7` on every instruction.
- Every specifier decode must special-case `R7` to route the PC into the address adder rather than reading the file.
- Exception reporting must distinguish the PC as an operand from the PC as the instruction pointer.

Tolerable on a non-pipelined machine, a persistent tax beyond. ARM32 carried it; AArch64 dropped it.

**The read-only proposal, taken seriously.** If `R7` merely *read* as the PC and writes to it were reserved, almost all of that cost disappears: reading needs only a mux on the register read path, since the PC is already a flop in the fetch unit. No write hazard, no branch-on-write. It is a real proposal and it is cheap.

It is still the wrong trade, for a reason that has nothing to do with cost. **Reading the PC forces a definitional commitment about *which* PC.** ARM32 answered "the address of this instruction plus eight," because the original three-stage pipeline had already advanced the PC twice by the time the register file was read. That answer is permanent. It leaks a 1985 pipeline depth into the architecture forever, every implementation since has had to reproduce it, and ARM's own documentation lists it among the architecture's warts. It is the same error class as branch delay slots, which §11 rejects for the same reason: an implementation detail promoted to an architectural promise.

There is no answer that avoids the commitment. "Address of this instruction" means the fetch unit must retain it past decode. "Address of the next instruction" means the value depends on the instruction's own length, so `MOVQ R7, R0` and `MOVQ R7, -8(SP)` yield different numbers. Either way a number is now specified forever.

And the capability is already present without the commitment:

```
        LEA     0(PC), R0       ; one instruction, four bytes
```

Mode `0010`'s displacement is defined relative to a stated point — the address of the first parcel of the instruction (§4.1) — so `LEA 0(PC), R0` has one meaning (the address of the `LEA` itself) and the architecture never has to say what "reading R7" would produce. At `len = 10` the same instruction forms any address within ±2 GB of itself PC-relatively, which is a strictly larger capability than a readable PC register offers.

So: `R7` is a general register, the PC is reached through mode `0010` and `LEA`, and the **syntax** is preserved — `MOV #5, R0`, `MOV foo(PC), R0` and `MOV @#addr, R0` all assemble. What is lost is encoding elegance; what is gained is a clean register file, a clean hazard story, one more general register, and no number specified in perpetuity. The requirement was mnemonic compatibility, not binary compatibility, and this is where that distinction earns its keep.

**Everyone modern agrees.** AArch64: `PC` is not a GPR, read via `ADR`/`ADRP`. LoongArch64: `PC` is not a GPR, read via `PCADDI`, `PCADDU12I`, `PCADDU18I` and `PCALAU12I`. RISC-V: not a GPR, read via `AUIPC`. The convergence is not fashion; it is four independent teams finding the same hazard.

LoongArch needs *four* such instructions because its fixed 32-bit encoding carries only twenty bits of immediate, so a full address takes a pair. Our variable-length encoding does it in one instruction at `len = 10` for any address within ±2 GB (before 2026-10-22, at `len = 11`, for the whole canonical space). That is the clearest single case where variable-length beats fixed-width, and it is worth noting that the property came free from the §3.1 length rule rather than being designed for.

### 9.4 Length as the primary field

Four consequences, all cheap:

- The opcode sits at a fixed position in every form, so the function mux is wired rather than decoded.
- **Length is a function of `len` alone** — two bits straight into the fetch down-counter, with no case analysis anywhere in hardware or in tooling (§3.1).
- Displacement scales with length automatically, giving branches four reaches from fifteen opcodes with no long-branch instruction and no trampolines.
- Any instruction fits one `uint64_t`, in the decode register and in every tool that has to carry one. Instructions in memory are 2, 4 or 6 bytes (§3.1.1; 2, 4, 6 or 8 before 2026-10-22).

### 9.5 Decode as wires, not ROM

The 6502's real lesson is not the small register file. It is that decode is a PLA and a timing generator with no microcode ROM anywhere, because in 1975 a ROM bit was expensive relative to random logic.

The corresponding discipline: **lay out the map so the bits are the control signals.**

- Bits 15..14 are the fetch extension-parcel count. No decode. (The value 11 counts as zero extension parcels and selects page 2 in the decoder, §3.1.2.)
- Bits 13..8 drive the function mux directly, at the same position in every form.
- Bits 7..4 and 3..0 go straight to the register file address inputs.
- Bits 3..0 at `len ≥ 01` drive the address-generation sequencer directly.

Every bit wired instead of decoded is microcode that never gets built. Together with one memory operand and no deferred modes, this is where the transistor budget actually comes from — not from having fewer instructions, but from having a decode that is mostly wire.

The escape groups are the place this discipline is weakest: `BESC`, `MBLK`, `FESC`, `ATOM` and `SYS` all require a second decode stage on parcel 1. That is acceptable precisely because none of them is on the critical path — the common instructions are all in the directly-decoded space — but §4.14 exists to keep the weakness contained.

### 9.6 Why the parcel limit is three, and what `len = 11` is

**History (revisions 10 to 20).** Revisions 10 through 12 gave the reason for a limit of four parcels as "an instruction must fit a `uint64_t`," which is a true and useful property but is not why four was the number. The honest answer was simpler: **`len` is two bits, and two bits encode exactly four lengths.**

Going to five would have cost one of:

- **A third `len` bit**, taking the opcode field from six bits to five. Thirty-two top-level opcodes instead of sixty-four, when §4.16 had already assigned fifty-five and reserved nine more. Not available.
- **An opcode-dependent case at `len = 11`**, which is exactly what revision 9 had and revision 10 removed. That gives back the length rule of §3.1 — the single cheapest thing in the front end.

And the only customer for a fifth parcel was a full 64-bit immediate, which was already served two ways: 48 bits in one instruction at `len = 11` (covering every address in the canonical space and nearly every integer constant), and a PC-relative constant pool at two parcels for the rest, which is what compilers emit for `binary64` literals anyway. So the limit was where the length field put it, the fifth parcel's only use was covered, and the `uint64_t` property was a pleasant consequence rather than the reason.

**What changed (2026-10-22, errata 31).** The measurement of the compiled code showed that the fourth parcel, the one the argument above defended, was almost never used: **only 49 of 373,635 compiled instructions (0.013%) needed the eight-byte form.** The length code `11` was therefore the most valuable unused encoding in the machine. The limit is now **three parcels** (six bytes), and `len = 11` is a **second page of one-parcel instructions** (§3.1.2, §4.18).

This does not break the rule that length is a function of `len` alone — the point of the paragraph above about revision 9. Page 2 is always exactly one parcel; what depends on the value `11` is the *opcode map*, not the length. The fetch unit loads the down-counter with zero for `11` as for `00`, and the decoder reads the six opcode bits against page 1 or page 2 according to `len`. The cost is one level of decode after the length is known, which the ISA's own test (§1.2, rule 3, Occam) has to justify against its gate count; the case for it is in §9.9. The `uint64_t` property is unchanged in kind and stronger in degree: any instruction is now six bytes.

### 9.7 No transcendentals, and the FMA gap

**The ALU does not implement `sin`, `cos`, `tan`, `atan2`, `exp`, `log` or `pow`, and should not.**

#### 9.7.1 Which architectures had them, and how accurate they were

Two mainstream architectures ever put a transcendental function set in hardware, both in the early 1980s, and **neither was accurate**:

| Architecture | Set | Fate |
|---|---|---|
| **x87** (8087, 1980 →) | `FSIN`, `FCOS`, `FSINCOS`, `FPTAN`, `FPATAN`, `F2XM1`, `FYL2X`, `FYL2XP1` | still present for binary compatibility; avoided by every libm including Intel's own |
| **Motorola 68881/68882** (1984) | a *larger* set — `FSIN`, `FCOS`, `FTAN`, `FASIN`, `FACOS`, `FATAN`, `FSINH`…`FTANH`, `FETOX`, `FLOGN`, `FLOG2`, `FLOG10`, `FTENTOX`, `FTWOTOX` | **removed in the 68040**, which traps them to software |

The 68040 is the clearest verdict available: Motorola built the most complete transcendental set any microprocessor ever had, then deleted it one generation later and spent the area elsewhere.

**Why none of them is accurate.** `FSIN` accepts arguments up to 2⁶³ but reduces them modulo π using an internal **66-bit** value of π. Intel's own support staff give this as the explanation for `FSIN` disagreeing with a correct implementation, and direct callers to compiler libm routines that do full Payne–Hanek reduction instead. The failure is structural, not a bug:

- To reduce a double with a large exponent you need π to roughly 1100 bits. Sixty-six is not close, and the error grows with the argument.
- Near multiples of π/2 the reduction cancels catastrophically, so the few arguments where sine is most sensitive are the ones computed worst.
- No hardware is going to store a thousand bits of π for one instruction.

**And correct rounding is not generally achievable in fixed time.** The Table Maker's Dilemma: deciding how to round sin(x) to the nearest double requires computing enough extra bits to break the tie, and the number required is not bounded a priori. Proving tight bounds took the crlibm and CORE-MATH projects decades, function by function. Hardware cannot run an unbounded loop, which is why IEEE-754 lists these in clause 9 as *recommended* operations rather than required ones, and why conformance pressure never arrived.

**Software also won on speed**, which is what settled it. A microcoded `FSIN` was fifty to several hundred cycles and could not be pipelined. A polynomial chain of FMAs is twenty to forty cycles and pipelines perfectly on anything with more than one FP unit. Hardware lost to software on its own terms.

#### 9.7.2 What a modern architecture provides instead

The consensus that emerged is three tiers, and it is worth naming because it is the reason §4.10 looks the way it does:

1. **The CPU provides the primitives**: FMA, correctly-rounded `FSQRT`, classification, round-to-integral, min/max, and (on most architectures, though not here — see §9.9) low-precision reciprocal and rsqrt *estimates* as Newton–Raphson seeds. Itanium was the purest expression — no divide and no sqrt instruction at all, only `frcpa` and `frsqrta`, with software doing the iteration, and its libm was among the fastest and most accurate of its era.
2. **A GPU or accelerator provides fast approximate versions** at a few ulp, because graphics and neural-network activations do not need more. This is where the LB64 companion document puts `exp` and `rsqrt`, and §6.2 of that document explains why that is a consequence of this rule rather than an exception to it.
3. **Software provides correctly-rounded versions** when they are needed.

**The one modern exception is instructive.** ARM's SVE added `FTMAD`, `FTSMUL` and `FTSSEL` — trigonometric *helper* instructions. `FTMAD` multiplies by an absolute value and adds a Taylor coefficient selected by a 3-bit immediate and the operand's sign bit, with sine and cosine series terms built into the instruction, and its coefficients are documented as accurate for −π/4 < x ≤ π/4. So ARM put the **polynomial** in hardware and left **argument reduction** to software — precisely inverting what x87 attempted. If pdp64 ever adds trigonometric support, that is the shape it should take, and it would be `FESC` sub-opcodes rather than new instructions.

**One historical idea worth recording.** VAX had `POLY`/`POLYD`/`POLYG`/`POLYH`: evaluate a polynomial by Horner's method from a coefficient table, in one instruction, plus `EMOD` for argument reduction. DEC concluded the right hardware primitive was polynomial *evaluation* rather than the functions themselves — one step more general than FMA, and arguably the best answer anyone gave before FMA existed. With FMA present, `POLY` is a three-instruction loop, so it is not worth an opcode; but it would be a natural `MBLK`-family member if measurement ever said otherwise.

#### 9.7.3 The gap the question exposed

What libm actually wants from hardware is a short list, and revision 12 was missing the most important item on it:

What libm actually wants from hardware is a short list, and revision 12 was missing the most important item on it:

| Need | Why | Status |
|---|---|---|
| **FMA** | Horner's method with a fused multiply-add is both faster and *more accurate* than separate operations, because the intermediate product is not rounded. Every polynomial kernel in every libm is a chain of FMAs. | **added in r13**, §4.10 |
| correctly-rounded `FSQRT` | required by IEEE-754; cannot be synthesized accurately | present since r9 |
| `FCLASS` | every libm function opens with a dispatch on NaN / infinity / zero / subnormal | added in r13 |
| `FRINT`, `FMIN`, `FMAX`, `FCOPYSIGN` | argument reduction and the special cases | added in r13 |
| reciprocal and rsqrt *estimates* | Newton–Raphson seeds; explicitly not correctly rounded | added in r13, **dropped after r20** (§9.9) |

So the answer to "does the ALU support the standard trig operations" is no, deliberately — but the question exposed that the one floating-point instruction that genuinely matters was absent. **FMA's omission through revision 12 was the worst gap in the specification**, worse than the dropped `BSWAP`, because every numerical kernel and every libm function is built from it and there is no good software substitute.

### 9.8 Width and mode in the instruction, not in a register

The founding rule — compatibility is conversion instructions, never mode bits — says that anything which changes what an instruction *means* belongs in the instruction. Operand size is in the opcode (§4.1), floating-point precision is in the opcode, rounding mode is in the opcode (§4.10). Nothing is in a control register.

**Operand size in the opcode is not unusual.** ARM has `LDRB`/`LDRH`/`LDR`, RISC-V has `LB`/`LH`/`LW`/`LD`, MIPS the same; x86 uses prefixes, which is encoding rather than state. On that axis pdp64 is conventional.

**Where modern architectures do use hidden state, and why:**

| Hidden state | Where | Why they did it |
|---|---|---|
| **FP rounding mode** — `FPCR`, `FCSR`, `MXCSR`, and the PDP-11's own `FPS` | ARM, RISC-V, x86, LoongArch, POWER — **universal** | IEEE-754 and C's `fesetround` define rounding as a *dynamic* property of the environment. Hardware followed the language standard. Encoding five modes on every FP opcode also costs bits a fixed-width encoding does not have |
| **FP precision** — x87's control-word precision field, the PDP-11's `FPS.FD` | x87, FP11 | same bit pressure, one generation earlier |
| **Vector element width and length** — `vtype`, `vl` | **RISC-V Vector** | the strongest case of the four. With 32 fixed bits, encoding element width × length × masking × operation would exhaust the opcode space. And `vl` buys *vector-length-agnostic binaries*: one executable runs correctly on a 128-bit and a 512-bit implementation. You cannot get that property from an opcode at all |
| **Instruction set mode** — ARM32's `T` bit | ARM32 | a transitional compatibility mechanism; §6.2 shows what it permanently cost |

So the honest statement is not that everyone else uses hidden state for operand width — most do not — but that **everyone else uses it for floating-point rounding, and RISC-V Vector uses it for element width, and both have real reasons.**

**Why pdp64 does not, in three parts.**

*We have encoding room where they do not.* Every argument above reduces to bit pressure under a fixed-width encoding. §3.1's length-first variable encoding means a rounding-mode variant costs a `FESC` sub-opcode, and `FESC` has 256 of those with about forty used. Sub-opcodes are the cheapest resource in the machine (`FESC` now uses fifty-four). The architectures that chose mode registers were not careless; they were out of bits.

*Hidden state is invisible coupling, and the failure mode is remote.* A mode register is state that must be saved and restored at every context switch, and a library that sets it and fails to restore it changes the behaviour of unrelated code elsewhere in the process. The canonical case is a DLL setting x87 precision to 24 bits and silently altering every floating-point result in the program — real, famous, and extremely hard to diagnose, because the symptom appears in code that is correct. An opcode cannot do that.

*It destroys interleaving.* Revision 4's original reason: with the format in the opcode, FP11-compatible code and IEEE code coexist in one process with nothing to switch. The same argument covers rounding. A function needing round-toward-zero and a function needing round-to-nearest can be inlined into each other, interleaved by a scheduler, or called in a loop, with no save-restore pair and no correctness hazard. With a mode register, every such boundary needs a barrier, and the compiler must assume the worst at every opaque call.

And the realtime argument from §8.1 applies: mode state is more context to save, on the critical path of every switch.

**What this costs, named rather than waved away.** C's `fesetround` and `fegetround` specify a *dynamic* rounding mode, and pdp64 has no register to put it in. A conforming implementation must keep the mode in thread-local storage and have the few routines that honour it dispatch on it — a branch, in code that is rare and already slow. This is a real incompatibility with a letter of the C standard and it is accepted knowingly: almost all code sets round-to-nearest once and never changes it, and the code that does change it is doing interval arithmetic or error analysis and can afford a branch. (The *exception flags* of `fenv.h` are a different matter: state the program only reads and clears, provided as the sticky `FPSR` of §4.10.1. The rounding half is not settled: the directed-rounding variants IEEE 754 requires for arithmetic do not exist yet, §12 item 13.)

**One place the argument would reverse.** If pdp64 ever acquires a vector unit, RISC-V's `vl` argument applies in full: vector-length-agnostic binaries are a property no opcode can provide, and they matter more as implementations diverge. That choice should be made on its own terms when it arises, not foreclosed here. The LB64 companion argues the vector unit should be a Q64 device rather than a CPU extension, which sidesteps the question — but it sidesteps rather than answers it.

### 9.9 Decisions made after revision 20, and why

Writing the encoding down as something a machine could check, and then building an assembler, linker, emulator and compiler back end for it, turned up the following. Each entry says what was decided and why; Appendix A lists them with their sources.

**The PC base is the first parcel of the instruction.** Revision 20 argued at length that reading the PC forces a commitment about *which* PC, and then said only that a displacement is "relative to a stated point". The point is now stated (§4.1). Starting from the instruction rather than its end means the displacement does not depend on the length chosen for the instruction itself. An assembler that picks `len` from the displacement would otherwise iterate, with the displacement depending on `len`; with this rule every instruction only grows, relaxation is monotone, and it terminates. Branch displacements count parcels because the §4.4 reach table needs that.

**`CMP` is register-first** (§4.2). A literal PDP-11 `src,dst` meaning would make every comparison of a register against an immediate or a memory operand reverse its branch condition; the encoding computes `reg − rm`, and `CMP a,b` followed by `BLT` still means "branch if a < b".

**`C` is a borrow on subtract** (§4.2), the PDP-11 sense, so `BHIS`/`BCC` mean "no borrow", unsigned `≥`.

**`PUSHM`/`POPM` moved to `SOP`** (§4.5). The `MBLK` parcel 1 has an 8-bit sub-opcode, so a 16-bit mask has no room at `len=01`, and §4.14 forbids deciding the parcel-0 interpretation per sub-opcode. `SOP` had exactly two free slots, the mask as a 16-bit immediate needs no new mechanism, and the instruction stays four bytes. The cost is that `SOP` has no free slot left.

**`SYS` is a class and a minor** (§4.11). Three statements in revision 20 (eight bits of sub-opcode from `reg` and `rm`; sub-opcode from `reg` alone; a two-byte `TRAP #n` with 256 vectors) cannot all hold. The 4-bit class with `rm` as operand keeps the two-byte common case, and `TRAPL` reaches the rest of the 256 vectors at four bytes.

**`JTAG` is legal only in the scaled-index mode** (§4.9): the mode that already carries a base and an index register is the only one with a free register slot for the tagged value.

**Scaled index widens at `len ≥ 2`; `MESC` has a fixed parcel 1; `SOB` exists from `len=01`; `RORI` is its own instruction** (§3.3, §4.13, §4.4, §4.6). Revision 20 gave the scaled-index mode only at `len=01` and itself called its 6-bit displacement thin; each extra parcel now adds sixteen bits. `SOB`'s register takes the field that is the branch displacement at `len=00`. Register-count and immediate-count rotates are different encodings (the count sits in the low byte of parcel 1), so they get different sub-opcodes and names.

**Pre-decrement is `-(Rn)` or `(Rn)-d`** (§5), because `-d(Rn)` is how a negative base displacement is already written.

**`FRECPED` and `FRSQRTED` were dropped.** The machine has `FDIV`, `FSQRT` and the fused multiply-add family, so a software Newton loop buys speed only if the hardware divide is slow, which this design does not chase. Each estimate needs a table in hardware and an exact specification — ARM and RISC-V pin down the algorithm and the table, while this document said only "not correctly rounded", so two implementations would return different bits for the same program. And no document names a user (§1.2 rule 3).

**Floating-point exception flags were added** (§4.10.1) because IEEE 754 requires five status flags and C99 `<fenv.h>` needs software access to them. They are a sticky register that is written by operations and read by one swap instruction, never trap, and are not a mode (§1.1).

**Unsigned 64-bit conversions and `FRINTA`** (§4.10) because C needs them: without `FCVTDQU`/`FCVTQUD` each unsigned conversion is a compare, a branch and several instructions, and `FRINTA` is C's `round()`; both are qualifiers of existing operations.

**Integer `ABS`, `MIN`, `MAX`, `MINU`, `MAXU` and `SET cc, rd`** (§4.12) were added at the user's request. The first group are the integer counterparts of the float operations and by the folding rule add no operation. `SET` removes about six bytes per site that would otherwise be compare, branch, two moves and a jump, about 0.4% of code on the measured corpus (§14.4).

**Half precision** (§4.10) was added at the user's request as a third width in the same spelling rule, with the `binary32` set minus what a half has little use for.

**One spelling rule for floating point, and one alias rule** (§4.10, §4.15): `FADD` is `binary64`, a decimal suffix in bits names any other width, and the old spellings are aliases, so that the same operation is not spelled three ways.

**NaN results are canonical** (§4.10.2). Without a rule the bits of a NaN would depend on the host that ran an emulator; the RISC-V rule (no payload propagation) is adopted and hardware must match.

**CRC instructions were considered and rejected** (§4.6.3, §11): carry-less multiply already covers every polynomial.

**The fourth parcel is removed and `len = 11` becomes a second page of one-parcel instructions; `CBCC` and `RORI32` are added** (§3.1.2, §4.4.1, §4.6, §4.18; errata 31, the author's decision, 2026-10-22). *Why:* only 49 of 373,635 compiled instructions (0.013%) needed the fourth parcel, while the one-parcel abbreviations are estimated to save about 118 KB (7%) of a 1.67 MB image and the two new instructions 22 KB (1.3%) (static counts on the 827-file corpus, §4.18). The options considered were to keep four parcels, to reserve `len = 11`, and to use it for a second page; the second page was chosen with an explicit map (and further candidates were searched for before it was fixed). The register-deferred form of *every* memory-operand opcode was considered as the content of the page and rejected in favour of the explicit map (§11). *The rule that keeps it safe:* every page-2 form is exactly the operation of its long form, with the same flags, result and faults, so an assembler that chooses the shortest encoding never changes what a program does. *Costs:* the immediate, absolute, PC-relative and branch fields shrink from 48 to 32 bits, the base-register displacement from 44 to 28 bits (the scaled-index displacement from 38 to 22 bits), so an address outside the 32-bit range is formed PC-relatively or from a constant pool; and the decoder gains a page select after `len`. The fused compare-and-branch is `CBCC` in the formerly reserved `0x28`; `RORI32` is a `BESC` sub-opcode with `RORI`'s format. The measurements that did not become instructions: `LEA 1(Rx), Rx` occurs 7,852 times (and `LEA -1(Rx), Rx` 395) where the two-byte `INC` and `DEC` exist, and 36,555 six-byte external `CALL` and `LEA sym` forms need linker relaxation, not an encoding.

---

## 10. Historical comparison

Measured devices, for calibration:

| Device | Year | Process | Transistors | What it was |
|---|---|---|---|---|
| MOS 6502 | 1975 | 8 µm NMOS | ~3,500 | 8-bit, PLA decode, zero page |
| DEC T-11 | 1981 | 5 µm NMOS | 12,000 | complete PDP-11 integer core, no MMU, no FP |
| ARM1 | 1985 | 3 µm CMOS | ~25,000 | 32-bit RISC, no MMU, no FP |
| Intel 8086 | 1978 | 3 µm NMOS | ~29,000 | 16-bit, segmented, ModR/M |
| Motorola 68000 | 1979 | 3.5 µm NMOS | ~68,000 | 32-bit CISC; **could not restart instructions** |
| MIPS R2000 | 1986 | 2 µm CMOS | ~110,000 | 32-bit RISC, software-refill TLB |
| DEC J-11 | 1983 | 4 µm CMOS | ~120,000 (40K + 80K) | full PDP-11/70: MMU, split I/D, microcoded FP |
| MicroVAX 78032 | 1984 | 3 µm NMOS | 125,000 | **subset** VAX: 175 of 304 instructions, no FP |
| MicroVAX 78132 | 1984 | 3 µm NMOS | 32,141 | the FPU the 78032 did not contain |
| Intel 80386 | 1985 | 1.5 µm CMOS | ~275,000 | 32-bit, paging, segmentation |

The pair that settles the argument is J-11 against 78032. A complete PDP-11/70 — memory management, split instruction and data space, supervisor mode, microcoded FP11 floating point — cost about 120,000 CMOS transistors. A VAX with packed decimal, character strings and H-float amputated and left to macrocode emulation, and with no floating point on the die at all, cost 125,000 NMOS transistors. CMOS runs roughly twice the device count of NMOS for equivalent logic, so like-for-like the full PDP-11 lands near half the subset VAX.

Two cautionary entries. **The 68000 is very nearly this machine** — PDP-11-derived orthogonality, widened, no decimal or string instructions — and it could not support demand paging, because a bus error left unrecoverable internal state with no resume path. The 68010 retrofitted a fix by dumping microstate to the stack for `RTE`. That fix is expensive and ugly precisely because it was retrofitted; §7 is architectural from the first draft, and that is the whole difference. **The NS32000** was a deliberate single-chip VAX-alike with a fully orthogonal memory-to-memory model, and it paid for that orthogonality in both silicon bugs and cycles per instruction.

### Estimated budget

Not measured. A sanity check on the design point, for a non-pipelined or short-pipeline implementation in a modern process.

| Block | Transistors | Change from r12 |
|---|---|---|
| register file, 16 × 64, 2R1W | ~6,000 | |
| ALU, shifter, address adder | ~15,000 | |
| decode and sequencer | ~6,500 | +1,000 — escape sub-decode |
| bit unit: popcount tree, CLZ/CTZ, bitfield | ~3,500 | **new** — `BESC` |
| block move sequencer | ~1,500 | **new** — `MBLK` |
| UTF-8 decode and validity | ~1,200 | **new** |
| TLB, 32 entries, walker, DMW compare | ~19,000 | +1,000 — `DMW` |
| FPU with FMA, classify, min/max | ~34,000 | +9,000 — the FMA datapath |
| control, PSW, exception, undo buffer | ~5,500 | +500 — progress category |
| **total, excluding caches** | **~92,000** | from ~74,500 |

Still a 64-bit machine with floating point and memory management below the 78032's 125,000, which had neither. The FMA datapath is the largest single addition and the least negotiable (§9.7). The bit unit and the UTF-8 decoder together cost less than 5% of the die and remove the three most common software workarounds.

---

## 11. Explicitly rejected

| Rejected | Source | Reason |
|---|---|---|
| **general memory-to-memory operands** | PDP-11, VAX | doubles the operand path, the register side-effect count and the fault matrix. The useful cases are all loops; §4.7 serves them with progress in architectural registers instead |
| deferred addressing modes, as general operand forms | PDP-11, VAX | second memory reference inside operand evaluation. *`JMPI`/`CALLI` (§4.9.1) are the one admitted exception — deferred transfer only, where no register is written before the load* |
| unbounded instructions with hidden microstate (`MOVC5`, `EDITPC`) | VAX | requires resumable microstate. Note the distinction from §4.7, which is unbounded *without* hidden state |
| packed decimal arithmetic and `EDITPC` | VAX, PDP-11 CIS | `EDITPC` is a bytecode interpreter in microcode. DEC needed a separate control chip for the PDP-11 CIS and shipped none. *Note: the VAX **character-string** group is largely implemented, not rejected — see §14.1* |
| `CRC` with a committed polynomial; `CRC32`/`CRC32C` instructions | VAX, x86 SSE4.2, ARMv8 | `CLMUL` is the primitive beneath every CRC and also serves GF(2^k) and GCM, without baking a polynomial into the architecture (§4.6.3). Eight `CRC32`/`CRC32C` words were added after revision 20 and then withdrawn: "we have carryless mul, no need for either crc" |
| `FRECPED`, `FRSQRTED` (reciprocal and rsqrt estimates) | ARM, RISC-V, Itanium | `FDIV`, `FSQRT` and FMA exist, so Newton loops pay only if hardware divide is slow; each needs a hardware table and an exact specification, which "not correctly rounded" is not; no document names a user (§9.9) |
| `CMP` with the PDP-11's literal `src,dst` operand order | PDP-11 | every compare of a register against an immediate or memory operand would reverse its branch condition (§4.2) |
| `-d(Rn)` as the pre-decrement syntax | revision 20 | it is already a negative base displacement; `-(Rn)` and `(Rn)-d` are used (§5) |
| `PUSHM`/`POPM` in `MBLK` | revision 20 | a 16-bit mask leaves no room beside an 8-bit sub-opcode at `len=01` (§4.5) |
| NaN payload propagation | IEEE 754 implementations | results would depend on the host or implementation; every NaN result is the canonical quiet NaN (§4.10.2) |
| `POLY` polynomial evaluation | VAX | the best pre-FMA answer, and superseded by FMA: a three-instruction loop (§9.7.2) |
| `MULU` as a distinct low-half multiply | PDP-11 EIS, VAX | the low 64 bits of a two's-complement product are identical signed or unsigned; one slot held a duplicate while the high half was missing entirely (§4.2.2) |
| `IOT`, `EMT` (also as assembler aliases) | PDP-11 | `TRAP #n` and `TRAPL #n` reach 256 vectors; a dedicated opcode for two particular values of *n* buys nothing (§4.11.1). The aliases were never implemented and are dropped |
| `WAIT` | PDP-11 | subsumed by `WFE`, which waits for an interrupt *or* an inter-core event (§4.11.1) |
| `RESET` | PDP-11 | resetting the bus is a device register write, not an instruction. §16 says what the architecture owes devices, and bus policy is not on the list (§4.11.1) |
| `ROL` as an instruction | PDP-11 | one rotate direction suffices; `ROL #n` is an assembler alias for `ROR #(64−n)` at no cost (§4.5.1, §4.15) |
| **NUL-terminated string instructions** | System/z `MVST`, `SRST`, `CLST` | they encode an unbounded read, which is the single most prolific source of memory-safety failures in C. `MSCN` with an explicit maximum gives `strnlen`, and composing it with `MCPY` gives a bounded `strcpy` in two instructions with the length known in between — which is the safer idiom anyway (§14.2) |
| hardware call frames (`CALLS`/`CALLG`) | VAX | slower than the equivalent sequence on later VAXen; `PUSHM`/`POPM` keeps the useful part |
| multiple float formats | VAX | one IEEE pair |
| **transcendental instructions** | x87 | slow, and inaccurate for large arguments in a way software cannot repair (§9.7) |
| PC in the general register file | PDP-11, ARM32 | every register write becomes a potential branch |
| **read-only `PC` view of `R7`** | ARM32 | cheap in hardware, but forces a permanent definitional commitment about *which* PC — ARM32's `PC+8`. `LEA 0(PC), Rn` has the capability without it (§9.3) |
| preserved partial-register writes | x86 (`AH`/`AL`) | merge dependency on every narrow write. *The objection is to preserving upper bits, not to naming sub-widths. x86-64 fixed this for 32-bit writes by zero-extending and left it broken for 8- and 16-bit; §4.1 applies the fix uniformly* |
| `REX` and operand-size prefixes | x86 | decode tax on every instruction; a mode bit in disguise |
| segmentation | x86 | solved by paging |
| non-uniform flag writes | x86 | `INC` not writing carry, to save one byte |
| implicit registers for multiply, divide, shift count | x86 | saves opcode bits, costs a permanent shuffle in every compiler and every hand-written loop |
| x87 register stack | x86 | |
| byte-granular instruction fetch | x86, 6502 | alignment rotator in the front end for ~10% density |
| decimal mode | 6502 | mode bit; same error class as `FPS.FD/FL/FT` |
| accumulator-centric register set | 6502 | 1975 economics |
| separate FP register file | most | largest single block saved on a small implementation |
| 32-bit profile | — | one architecture; `MOVL` retains 32-bit data, which is what was actually needed |
| five-parcel instructions | — | `len` is two bits and two bits hold four lengths; the fifth parcel's only customer is already served (§9.6). Since 2026-10-22 the limit is three parcels and the value `11` is a second page (§9.6) |
| a register-deferred form of every memory-operand opcode, as the content of page 2 | considered with errata 31 | the page would repeat the whole memory-operand class for one addressing mode; the explicit map of §4.18 holds the abbreviations that the measured code uses, with room for more (§9.9) |
| a fourth parcel or a 48-bit immediate/absolute form | revisions 9–20 | 49 of 373,635 compiled instructions (0.013%) used it (§9.6, §9.9) |
| 8-byte instruction alignment | — | 5–10% padding plus an alignment obligation through assembler, linker and every hand-written stub, for a fetch path that is already cheap |
| `MOVT` / `MOVK` top-half insert | AArch64 | the constant pool covers 64-bit literals without a partial-write instruction to reconcile against §4.1 |
| hardware tag checking on dereference | Lisp machines | a comparator, tag bits in the datapath and a trap path, to buy what §6.2 and §7.4 already give approximately free |
| a load form that ignores low pointer bits | — | deletes the alignment fault, which *is* the tag check; turns a corrupted tag into silent corruption |
| fused allocation; store-with-write-barrier | Lisp machines, JVMs | bakes a specific allocator or collector into the architecture, for three or four ordinary instructions |
| an instruction-set-switch bit in pointers | ARM Thumb `BX` | permanently consumes bit 0, which §6.2 grants to software |
| self-synchronizing encoding | UTF-8 | a marker bit in every parcel is 6.25% of the encoding space and caps immediates at 15 bits per parcel. Landing pads (§12.3) get the security property for one opcode |
| `R0` hardwired to zero | LoongArch, MIPS, RISC-V, Alpha | costs a sixteenth of the register file to save instructions we already have — `CLR` is one parcel and `TST` is one parcel. Worth it at 32 registers, not at 16 |
| fused compare-and-branch replacing flags | LoongArch, RISC-V | a comparator in the branch unit and a third read port, versus a four-bit latch. `SOB` covers the loop case that motivates it |
| a scalar instruction for sub-1-bit model inference | LittleBit, BitNet-class models | the kernel is bandwidth-bound with its op count equal to its weight-bit count, so it wants a bus-mastering accelerator with its own DMA, not an opcode (§4.6.2) |
| branch delay slots | MIPS | exposes one implementation's pipeline depth forever — the same error as ARM32's `PC+8` |
| register windows | SPARC | spill/fill traps, and it fixes the wrong problem |
| software-refilled TLB | MIPS, Alpha | genuinely cheaper; rejected on miss-cost grounds with a three-level table |

---

## 12. Open items

1. **Scaled index displacement — partly resolved (§3.3, §9.9).** At `len = 10` the displacement now widens to 22 bits (it was 22 and 38 before the fourth parcel was removed, §9.9), so indexed access with a real displacement costs three parcels, the first of the two options below. The 6-bit displacement at `len=01` remains thin. Original text: Mode `0001` spends six bits of parcel 1 on `Rx` and scale, leaving a 6-bit displacement — ±32 bytes, thin for the array-of-structs case it exists to serve. Either accept that indexed access with a real displacement costs three parcels, or drop scale to a single bit (×1 / ×8) and reclaim one.

2. **Reserved opcode discipline — eased by revision 20, and now written down.** The regroup (§4.3) freed eight contiguous top-level slots by demoting five groups that could never have used a two-byte form anyway, so the space went from one scattered reserve to eight (seven since `CBCC` took `0x28`, §4.4.1). The rule that replaces this item: **a top-level opcode is for an operation whose common case is register-to-register**, because that is the only thing a top-level slot buys over an escape sub-opcode (§4.3). Everything else goes to an escape group, which has ~240 free sub-opcodes each. Revisions 15 through 19 each spent zero or one top-level slot under informal versions of this rule; it is now explicit.

3. **Landing pads — still open; ABI version 1 has them off** (`abi.md`; the assembler provides `.lpad`). `LPAD` is allocated in `SYS`. Requiring indirect branches and returns to land on one — the `ENDBR64` / ARM `BTI` / RISC-V `LPAD` approach — costs one opcode and one comparison in the branch unit and removes the return-oriented gadget class. Mandatory now, or optional-then-mandatory, is the decision, and it gets more expensive the longer it waits. Two interactions: a tagged function pointer reached by `JMP -k(Rn)` must still land on an `LPAD`, so the tag bias and the landing-pad check are independent and both apply; and `JTAG` (§4.9) is an indirect branch through a table, so every entry in a `JTAG` table must be a landing pad.

4. **Atomics against Q64.** The Unibus-derived `DATIP`/`DATO` locked read-modify-write is a *lock*; AXI exclusive access is a *monitor*. They are not the same primitive and the mapping is not clean. Settle in the [bus document](pdp64-q64-bus.md) before the memory system is built, not during it. The `_DB` barrier variants added in §4.11 make this more pressing, since they assert an ordering guarantee that has to mean something on the actual interconnect.

5. **Worst-case instruction latency.** Ordinary instructions are bounded: at most 6 bytes of fetch across two pages, one memory operand across two pages, nothing unbounded. `MBLK` is explicitly not bounded by the instruction (§7.5), so an implementation claiming an interrupt-latency figure must state its block granularity. Until both numbers exist, the realtime claims from earlier revisions rest on an argument rather than a bound.

6. **Measured length distribution — measured once, see §14.4.** The first compiler's output on the fair corpus has instruction lengths of 2 / 4 / 6 / 8 bytes = 46.5 / 42.8 / 10.6 / 0.1 %, 3.30 bytes on average (measured before the second page, which removes the eight-byte form and gives the short `d(sp)` forms of §4.18). A short `d(sp)` form was not measured at the time. Original text: §3.1.1 asserts that compiled code sits mostly at one and two parcels, averaging near three bytes. That is an argument, not a measurement, and it should be checked against real object code as soon as an assembler exists. If two-parcel forms dominate more heavily than expected, the case for spending a reserved slot on a single-parcel `d6(SP)` or `d6(DP)` form gets much stronger. VAX's short-literal modes are the comparison to beat: `MOVL #5, R0` is three bytes on a VAX and four here, because VAX packs a 6-bit literal into the specifier byte itself.

7. **Floating-point condition flags — behaviour fixed, problem open.** `FCMP` sets `N` if a<b, `Z` if a==b, `V` if unordered and clears `C` (§4.10), but the signed branches do not yet treat unordered cleanly (`BLT` after an unordered compare takes `N xor V` = 1). Original text: `FCMPD` writes the integer `PSW` flags, which serializes FP compares against integer work and makes two independent FP comparisons dependent on one resource. LoongArch provides eight separate one-bit `FCC` registers for exactly this reason. Adding even two FP condition bits to `PSW` would help, at the cost of two more bits to save and restore. Not yet decided.

8. **`MBLK` and the cache.** A one-megabyte `MCPY` will evict the entire D-cache for data that is never read again. Every real `memcpy` implementation on a machine with non-temporal stores uses them for exactly this reason. Either `MBLK` needs a non-temporal variant, or the `MT` field needs a streaming value, or the implementation must decide by length — and the third option is a performance cliff with no architectural visibility, which is the worst of the three. The LB64 companion's §12.1 profile gives the context: an inference workload moves 45 MB per token through a cache of a few kilobytes, so for that case the answer is already a streaming `MT` value rather than a non-temporal opcode.

9. **UTF-8 scope — resolved in revision 15.** `MVAL` is committed (§4.7.1). What remains open is whether `MOVTC`-style table-translated streaming belongs in `MBLK` at all, given that a per-byte table lookup is the one thing that would stop the group running at a quad per cycle (§14.1.1).

10. **Rounding mode and `fesetround`.** §9.8 accepts that C's dynamic rounding mode has no register to live in, and that a conforming libm must keep it in thread-local storage and dispatch. That is a real incompatibility with the letter of the C standard. It should be confirmed with whoever writes the libm port rather than asserted here, because the alternative — a mode register that opcodes override — would be a mode bit by another name and §1.1 forbids it.

11. **Memory model verification.** §17.1 declares sequential consistency. A declaration is not an implementation, and SC is easy to violate accidentally through a store buffer that forwards incorrectly or a cache that reorders its fills. Litmus testing against the published SC test suites belongs in the implementation plan's verification section before a second core exists, not after.

12. **Core count and the coherence choice.** §17.3 picks snooping MSI on the grounds that two to four cores is the target. If the target is eight or more, that is the wrong protocol and the decision should be revisited before the cache is built rather than retrofitted.

Items added since revision 20:

13. **Directed rounding for arithmetic.** IEEE 754 requires rounding toward +∞, −∞ and zero, as well as to nearest, for add, subtract, multiply, divide, square root, fused multiply-add and the conversions. §9.8 says the mode lives in the opcode, but there are no such opcodes except `FRINT*`. Options: (a) a 2-bit static rounding field in the instruction (the `FESC` two-register forms have a free nibble; the four top-level operations have none); (b) a rounding-mode register, which §1.1 forbids and item 10 already worries about; (c) three more opcodes per operation. Needs a decision.

14. **Half precision — resolved, with leftovers.** `binary16` was added (§4.10). Still open: half `FMIN`/`FMAX`/`FRINT*`, `FNEG16`/`FABS16`, conversions to and from int64 and unsigned, and bfloat16. The cost estimates made before the decision (conversions 500–1,000 LUTs, full arithmetic 2,000–3,500) are unmeasured.

15. **Conditional select.** `SET cc, rd` was added (§4.12). A conditional select (`CMOV`/`CSEL`) is size-neutral and pays only in speed, by removing a misprediction; one integer select would also serve floating point, since values live in the general registers. On hold until there is a speed model to justify it (§14.4).

16. **ABI questions of §19.5.** Decided in ABI version 1: `R12` is the linker scratch register, and calls to imports go through `CALLI got(PC)`. Open: lazy versus eager binding, the red zone (none in version 1), and mandatory landing pads (item 3).

17. **Compiler-side wishes** recorded by the first back end: a short `d(sp)` form, and linker relaxation of the 35,000 six-byte cross-section `call`/`lea` (§14.4). Sized integer arithmetic was considered and **decided against** (CHANGES §14, errata 28): integer arithmetic stays 64-bit; narrow values are extended by the sized moves. Also open: whether an operand-role table should move into the mnemonic grammar, and a way of writing a width on an integer operation.

18. **The fourth parcel, and what to do with the length code `11` — RESOLVED (decided 2026-10-22, errata 31).** Only 49 of 373,635 compiled instructions (0.013%) needed the eight-byte form, which existed only because the two-bit `len` field has four values (§9.6). The fourth parcel is removed and `len = 11` is a second page of 64 one-parcel opcodes, 41 of them defined, each an exact abbreviation of an existing instruction (§4.18); `CBCC` (§4.4.1) and `RORI32` (§4.6) were added with it. The full map and the rule that keeps it safe are in §4.18; the reasons are in §9.9; the specification and the estimates are in [`CHANGES-SINCE-R20.md`](CHANGES-SINCE-R20.md) §12. Still open from the same measurement: peephole use of `INC`/`DEC` for `LEA ±1(Rx), Rx` and linker relaxation of the external `CALL` and `LEA sym` (item 17).

---

## 13. Side by side: PDP-11, VAX, pdp64

### 13.1 Architecture

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Word | 16 bits | 32 bits | 64 bits |
| General registers | 8 (`R0`–`R7`) | 16 (`R0`–`R15`) | 16 (`R0`–`R15`) |
| PC | `R7`, fully writable | `R15`, fully writable | **not a register** |
| SP | `R6`, per-mode copies | `R14`, per-mode copies | **`R14`**, per-mode copies |
| FP | software convention | `R13`, used by `CALLS`/`CALLG` | **`R13`**, software convention |
| AP | — | `R12`, for `CALLS`/`CALLG` | none — `R12` is general |
| Virtual address | 16 bits (18/22 physical) | 32 bits | 39 bits (40 physical) |
| Instruction count | ~70 base, plus EIS/FIS/FP11/CIS options | 304 | 56 assigned top-level opcodes in page 1 and 41 defined opcodes in page 2; TODO-COUNT instructions in TODO-COUNT mnemonic words (the rest are aliases); TODO-COUNT operations once width, precision and similar qualifiers are folded |
| Instruction length | 1–3 words (2–6 bytes) | 1 to over 50 bytes | 1–3 parcels (2–6 bytes), plus a one-parcel second page |
| Operands per instruction | 1 or 2 | 0 to 6 | 1 or 2, plus 3 for `MBLK` |
| Memory operands per instruction | up to 2 | up to 6 | **1** |
| Addressing modes | 8 | 16 | 8 defined, 8 reserved |
| Condition codes | N Z V C | N Z V C | N Z V C |
| Floating point | FP11 option, separate `AC0`–`AC5` | in the base, separate `F` registers | in the base, **in the GPRs** |
| FP formats | F, D | F, D, G, H | `binary16`, `binary32`, `binary64` |
| Mode bits affecting semantics | `FPS.FD/FL/FT` | `PSL` rounding, `FPD` | **none** |

### 13.2 Encoding, double-operand

**PDP-11** — one word, plus 0–2 extension words:

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+--+--------+-----------------+-----------------+
| b|   op   |   src specifier |  dst specifier  |
+--+--------+-----------------+-----------------+
```

Bit 15 is the byte flag, bits 14..12 the opcode, and each specifier is 3 bits of mode plus 3 bits of register. Seven double-operand instructions exist, and the encoding is *exactly* full: `MOV`=01, `CMP`=02, `BIT`=03, `BIC`=04, `BIS`=05, `ADD`=06 — and `SUB`=16, which is `ADD` with bit 15 set, because `ADD` had no byte form and the bit was free. That is the cleverness and the cramp in one place.

**VAX** — one or two opcode bytes, then one specifier byte per operand, each with 0–8 bytes of extension:

```
byte 0:    opcode                  (FD prefix selects a second opcode byte)
byte 1:    mmmm rrrr               specifier 1: 4-bit mode, 4-bit register
           [0-8 bytes extension]
byte n:    mmmm rrrr               specifier 2
           [0-8 bytes extension]
```

Modes `0`–`3` pack a 6-bit literal into the specifier byte itself, so `MOVL #5, R0` is three bytes. Mode `4` is *index*, a prefix that wraps the following specifier. Modes `9`, `B`, `D`, `F` are deferred — a memory read during operand evaluation. Length is not a function of any fixed field.

**pdp64** — one parcel, plus 0–2 extension parcels (or, at `len = 11`, a one-parcel instruction of the second page, §4.18):

```
 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
+-----+-----------------+-----------+-----------+
| len |      opcode     |    reg    |  mode/rm  |
+-----+-----------------+-----------+-----------+
```

Six bits of opcode, four of register, four of mode. At `len = 00` the low nibble is a second register; at `len ≥ 01` it is a mode and the register comes from parcel 1.

### 13.3 Operand specifiers

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Specifier width | 6 bits | 8 bits + 0–8 extension | 4 bits mode + 4 bits register |
| Mode field | 3 bits | 4 bits | 4 bits |
| Register field | 3 bits | 4 bits | 4 bits, in parcel 1 |
| Deferred forms | **free** — low bit of mode is the indirect bit | 7 of 16 modes | **none** |
| Literals in the specifier | no | yes, 6-bit, modes 0–3 | no |
| Index as a prefix | no | yes, mode 4, wraps another specifier | no — one mode, `0001` |
| Register side effects | up to 2 per instruction | unbounded | 1, or 3 for `MBLK` |

The PDP-11's indirect bit is the detail worth dwelling on. Making the low bit of the mode field mean "deferred" gave eight modes for the price of four designs, and it is genuinely beautiful. It is also the single most expensive thing in the encoding, because it made half the modes issue a memory reference during operand evaluation. pdp64 deletes the deferred forms and spends the saved bit on a fourth mode bit — same width, eight live modes with eight in reserve, and no second memory reference anywhere.

### 13.4 The front end

| | PDP-11 | VAX | pdp64 |
|---|---|---|---|
| Length known from | both specifiers of word 0 | nothing fixed; sequential parse | bits 15..14 |
| Memory refs during operand eval | up to 4 | unbounded | **1** |
| Restart mechanism | `MMR0`/`MMR1`/`MMR2`, software undo | `PSL<FPD>` + per-instruction microstate | hardware buffer, committed at retire |
| Restart state size | 2 journal entries + PC | implementation-defined, large | 1 buffered register write |
| Worst-case instruction | `MOV @X(R1), @Y(R2)` — 6 bytes, 4 memory refs | `MOVC5` — unbounded refs, resumable microstate | 6 bytes, 1 operand ref; `MBLK` with register progress |

### 13.5 Instruction-level correspondence

| PDP-11 | VAX | pdp64 | Note |
|---|---|---|---|
| `MOV` / `MOVB` | `MOVL` / `MOVB` / `MOVW` / `MOVQ` | `MOVQ`/`MOVL`/`MOVW`/`MOVB` + `MOVZ*` | size in the opcode; explicit extension |
| `ADD` `SUB` `BIC` `BIS` `CMP` `BIT` | same, plus sizes | same names, 64-bit only | unchanged mnemonics |
| `XOR` (register source only) | `XORL` etc. | `XOR`, full modes | generalized |
| `MUL` `DIV` `ASH` `ASHC` (EIS option) | in the base | `MUL` `MULH` `SHL` `SHR` `SAR`; `DIV` `DIVU` `MOD` `MODU` `MULHU` in `AESC` | in the base |
| `CLR` `COM` `INC` `DEC` `NEG` `TST` `ADC` `SBC` | same | `SOP`, §4.5 | unchanged |
| `JMP @X(Rn)` (mode 7) | mode `9`/`B`/`D`/`F` deferred specifiers | **`JMPI`** `CALLI` in `XFER` (§4.9) | deferred *transfer* retained; deferred *operands* not |
| `ASL` `ASR` (by one) | `ASHL` with a count | `SOP`, §4.5 | unchanged |
| `ROL` `ROR` (by one, **through carry**) | `ROTL` with a count | `ROR` / `RORI` in `BESC`; `DSHR` for multi-precision | not through carry — §4.5.1 |
| `SWAB` | `ROTL` | `BSWAP` in `BESC` | generalized to 64 bits |
| `SXT` | `CVTBL` etc. | conversion set at `len=00` | subsumed |
| `SOB` (backward only) | `SOBGEQ` `SOBGTR` `AOBLEQ` `AOBLSS` `ACB` | **`SOB`**, both directions | restored, §4.4 |
| `JSR Rn, dst` / `RTS Rn` | `CALLS` / `CALLG` / `RET` | `CALL` / `RET`, `PUSHM` / `POPM` in `SOP` | §14.2, §4.5 |
| `MARK` | — | — | dropped by DEC too |
| `TRAP` `EMT` `IOT` `BPT` | `CHMK` etc. | `TRAP` `TRAPL` `BPT` in `SYS` | `EMT`/`IOT` are `TRAP #n` (§4.11.1) |
| `SEC` `CLC` `SCC` `CCC` | `BISPSW` `BICPSW` | `MTPS` | consolidated |
| `MFPI` `MTPI` `MFPD` `MTPD` | `PROBER` `PROBEW` | `PROBER` `PROBEW` | VAX's form is better |
| — | `EDITPC` `MOVC5` `CMPC5` `MOVTC` `LOCC` `SKPC` `MATCHC` | `MCPY` `MMOV` `MSET` `MCMP` `MSCN` | same jobs, register progress (§7.5) |
| — | `INSV` `EXTV` `EXTZV` `FFS` `FFC` | `INSB` `EXTB` `EXTZB` `CTZ` `CLZ` in `BESC` | §4.6 |
| — | `CASEB` `CASEW` `CASEL` | **`JTAG`** for 8-way tag dispatch; bounds-check + table otherwise | §6.3 |
| — | `INDEX` (with bounds check) | mode `0001`, no bounds check | §14.2 |
| — | `INSQHI` `REMQHI` interlocked queues | `CAS`, `LL`/`SC` | §14.2 |
| — | `POLY` `CRC` | — | rejected |
| — | packed decimal group | — | rejected |
| — | — | `BTAG` `BNTAG` `JTAG` | new, §6.3 |
| — | — | `POPCNT` `XNORPOP` `BITREV` | new, §4.6 |
| — | — | `UTF8LEN` `UTF8DEC` `UTF8ENC` | new, §4.6.1 |
| — | — | `FMADD` family, `FCLASS`, `FSFLAGS`, `binary16` | new, §4.10 |
| — | — | `ABS` `MIN` `MAX` `MINU` `MAXU` `SET` | new, §4.12 |
| — | — | `_DB` atomics | new, §4.11 |

---

## 14. Idioms: lost, restored, replaced

### 14.1 Restored

| Idiom | Source | Here |
|---|---|---|
| **Subtract one and branch** | PDP-11 `SOB`, VAX `SOBGEQ`/`AOBLSS`/`ACB` | `SOB`, §4.4. The PDP-11's could only go backward; this one goes either way with four reaches |
| **Probe an address without faulting** | VAX `PROBER`/`PROBEW` | `PROBER`/`PROBEW`, §4.11. Replaces the `nofault` global for the address-validation case |
| **Bitfield extract and insert** | VAX `EXTV`/`EXTZV`/`INSV` | `EXTB`/`EXTZB`/`INSB`, §4.6 — dropped by accident in revision 10 |
| **Find first set / clear** | VAX `FFS`/`FFC` | `CTZ`/`CLZ`, §4.6 |
| **Byte swap** | PDP-11 `SWAB` | `BSWAP`, §4.6, generalized to 64 bits with word and long variants |
| **Block move, fill, compare, scan** | VAX `MOVC3`/`MOVC5`/`CMPC3`/`LOCC`/`SKPC`, System/360 `MVCL` | `MCPY`/`MMOV`/`MSET`/`MCMP`/`MSCN`/`MSCNN`, §4.7 — with the progress in registers, which is what VAX got wrong |
| **Register save mask** | VAX procedure entry mask | `PUSHM`/`POPM`, §4.5 — the useful half of `CALLS` without the frame |
| **Carry-less multiply** | — (modern: x86 `PCLMULQDQ`, ARM `PMULL`) | `CLMULL`/`CLMULH`, §4.6.3 — the primitive VAX's `CRC` should have been |

#### 14.1.1 What "string instructions" meant, and how much of it we have

Revisions 8 through 14 listed "string" among the rejected VAX features, which became wrong the moment revision 13 added `MBLK` and was never corrected. Setting it straight, since the terminology is confusing.

**VAX and PDP-11 CIS "strings" are counted byte strings** — a length and an address, passed as separate operands or as a descriptor. They have nothing to do with C's NUL-terminated convention, which post-dates both. Every one of these instructions takes an explicit length:

| VAX | What it does | pdp64 |
|---|---|---|
| `MOVC3` | move *len* bytes | **`MCPY`** |
| `MOVC5` | move with fill byte and truncation | `MCPY` + `MSET`, two instructions |
| `CMPC3`, `CMPC5` | compare *len* bytes | **`MCMP`** |
| `LOCC` | locate a byte — `memchr` | **`MSCN`** |
| `SKPC` | skip a byte — first byte *not* equal | **`MSCNN`**, added in r15 |
| `MOVTC` | move translated through a 256-byte table | **absent** — see below |
| `SCANC`, `SPANC` | scan using a table and a mask | **absent** |
| `MATCHC` | substring search — `strstr` | **absent** |
| `CRC` | table-driven CRC | `CLMUL` instead (§4.6.3) |
| `EDITPC` | packed-decimal to character under a bytecode program | **rejected**, §11 |

So seven of the ten are present or better, and the rejection was always about `EDITPC` and the packed-decimal group rather than about character strings. §11 now says so.

**And `UTF8DEC`/`UTF8ENC`/`MVAL` are string instructions in the same tradition**, serving an encoding that did not exist in 1977. `MVAL` in particular is precisely the shape of `SCANC`: stream a buffer, stop at the first byte failing a predicate, leave the pointer there.

**The three still missing, and whether they matter.** `MOVTC` — table-translated move — is the most defensible: charset conversion, case folding and `tr` all want it, and the 256-byte table can live on chip. It is absent because a table lookup per byte breaks the streaming model that lets `MBLK` move a quad per cycle, so it would be the one slow member of a fast group. `SCANC`/`SPANC` are `MOVTC`'s predicate form with the same problem. `MATCHC` is a naive O(n·m) substring search, which is the wrong algorithm to put in silicon. All three are `MBLK` sub-opcodes if measurement ever justifies them; none is justified now.

### 14.2 Deliberately lost, with what replaces them

**Memory-to-memory `MOV`.** `MOV (R1)+, (R2)+` in a loop was the PDP-11 copy idiom and it is gone. The replacement is better rather than merely adequate: `MCPY` is one instruction instead of a loop body, the implementation may move 64 bytes per cycle while the architecture says bytes, and restart is free. What is genuinely lost is the *general* case — a single move between two arbitrary computed addresses, which now takes a load and a store. Two instructions, one extra register. Accepted.

**`@(Rn)+` and the dispatch-table idiom.** Autoincrement-deferred walked a table of pointers, which made it the natural way to write an interpreter's dispatch and a driver's jump table. Replaced two ways: `JTAG` (§4.9) for the tag-dispatch case, which is better because it needs no pointer register and cannot index out of range; and `MOVQ (Rn)+, Rt` followed by `JMP (Rt)` for the general case, which is two instructions where the PDP-11 had one. The threaded-code interpreter loop is the specific thing that got worse, and it is worth knowing that is the cost.

**`JSR Rn, dst` / `RTS Rn`.** The PDP-11's call was richer than ours, and the difference is worth stating precisely. `JSR Rn, dst` computes the effective address, pushes the *old contents of `Rn`* onto the stack, puts the PC into `Rn`, and jumps. `RTS Rn` moves `Rn` to the PC and pops the saved value back into `Rn`.

So the return address lived in a register of the caller's choosing, not on the stack. Three things fell out of that:

1. **`JSR PC, dst`** was the degenerate case — push PC, jump — and that is exactly our `CALL`. Most code used this.
2. **Arguments inline after the call.** With the return address in `Rn`, the callee read its arguments with `(Rn)+` and returned past them. Compact, and the ancestor of VAX's `CALLG`. Gone, and not missed: it defeats every debugger, every unwinder and every calling convention written since.
3. **Cheap coroutines.** `JSR R5, other` from one routine and `JSR R5, back` from the other swap control with the linkage in a register rather than on a stack. Genuinely elegant, genuinely gone. The replacement is an explicit stack switch, which is more instructions and more honest.

What our `CALL`/`RET` gains: no register burned, no push-and-shuffle of the old register value, and the return address exactly where every ABI, unwinder, profiler and debugger expects it. And it is the form that can be protected — §12.3's landing pads and a shadow stack are both meaningless if the return address can live in any register the caller picked.

**VAX `CASEB`/`CASEW`/`CASEL`.** A bounds-checked, table-driven multiway dispatch in one instruction — genuinely good for a `switch` statement. Here a general `switch` is a `CMP` against the limit, a `BHIS` to the default, and a `JMP` through a scaled index: three or four instructions. `JTAG` covers the 8-way tag case in one. The general case is a real regression and a candidate for `0x0F` if measurement supports it.

**VAX `INDEX`.** Array index with bounds checking in one instruction, which is what Pascal and Ada want on every subscript. Mode `0001` gives the scaling but no check. A bounds-checked variant is a plausible future `BESC` member; noted rather than designed.

**Byte and word ALU operations.** `BISB`, `BICB`, `ADDB` have no equivalent — the ALU is 64-bit only (§4.2). A byte-wide read-modify-write on memory becomes `MOVZB`, the operation, then `MOVB` back: three instructions where the PDP-11 had one. This is the most frequently felt loss in hand-written code and it is the direct price of having no partial-register writes and no byte-lane muxing in the ALU. §4.13's `BISM` and `BICM` cover the quad case.

**Condition-code operate instructions.** `SEC`, `CLC`, `SEV`, `CCC` set and cleared individual flags in one word. `MTPS` writes the whole `PSW`. Minor, mentioned for completeness.

### 14.3 Subsumed, so not losses

- **`SXT`** set the destination to 0 or −1 from `N`. The conversion set at `len = 00` (§4.1) is strictly more general — `MOVB R1, R2` sign-extends any width from any register — so `SXT` was redundant and is dropped from `SOP`.
- **`SWAB`** swapped the bytes of a word. `BSWAP` in `BESC` does 64 bits, with `BSWAPW` and `BSWAPL` for the narrower cases.
- **`MARK`** was the PDP-11's stack-cleanup helper for the inline-argument convention. DEC's own T-11 omitted it as "little-used," and the convention it served is gone (§14.2).
- **`ASH`/`ASHC`** shifted by a variable count. `SHL`/`SHR`/`SAR` take the count from `rm`, which includes a register.
- **`MFPI`/`MTPI`/`MFPD`/`MTPD`** moved data between address spaces for the kernel. `PROBER`/`PROBEW` plus ordinary loads under the previous-mode bits is the better arrangement, and it is VAX's.
- **`MULU`** was never distinct from `MUL`; §4.2.2 explains why, and `MULH` now occupies the slot. The mnemonic is accepted as an alias.
- **`IOT` and `EMT`** are `TRAP #n` at two particular vectors. **`WAIT`** is `WFE` on a machine with one core. **`RESET`** is a bus-controller register write. All four dropped in revision 17 (§4.11.1).
- **`ROL`** survives as an assembler alias rather than an instruction (§4.15), which is the form the operation actually deserved.

### 14.4 What the measurements say about the instructions added and not added

The figures behind the post-revision-20 decisions. Method: the "fair corpus" is the 841 files of the benchmark set (bearssl, c-testsuite, chibicc, cjson, gcc-torture, lua, lz4, mbedtls, zlib) that the aarch64, amd64 and i386 builds of the project's C compiler all compile.

- **`SET`, and conditional selection.** gcc `-Os` for amd64 emits 284,641 instructions on the corpus, 11.0% conditional branches, 783 `cmov` and 673 `set<cc>`. A `set cc, rd` removes about six bytes per site, about 0.4% of code. A select is size-neutral and pays only in speed. `SET` was added; the select is on hold. The compiler cannot yet use `SET`: pass 1 turns a comparison used as a value into branches before the back end sees it.
- **Integer `ABS`, `MIN`, `MAX`.** `ABS` at 18 sites and `ABSU` at 5, `MIN` at 171 and `MAX` at 52, across 95 files. The measured gain is under 0.1% of code; the case is clarity and the idiom, not size.
- **Bit-fields (`EXTB`, `EXTZB`, `INSB`).** The shift-pair extraction pattern occurs 151 times in 26 files, about 600 bytes at best (0.03%); the compiler does not use the instructions.
- **Auto-increment.** Of 10,547 `lea n(rX),rX` only 437 have a dereference through the same register next to them (about 0.1%); the compiler does not emit the modes. They remain for hand-written code and the string and block idioms.
- **Code generated by the first compiler**, before the second page of §4.18 (fair corpus, optimized flags): 405,744 instructions and 1,762,610 bytes, 1.03 times amd64 and 1.04 times aarch64 in instructions, 0.97 and 0.89 times in bytes; instruction lengths 2 / 4 / 6 / 8 bytes = 46.5 / 42.8 / 10.6 / 0.1 %, 3.30 bytes on average. Costs the ISA could remove: about 35,000 six-byte cross-section `call` and `lea`; memory operands that are quad only, so `movl` is 10% of all instructions; no 32-bit arithmetic, so a wrap-correct `int` costs 4.1% of instructions and 1.9% of bytes; a short `d(sp)` form (not measured).
- **The second page, `CBCC` and `RORI32`** (errata 31, decided 2026-10-22). Static counts on the 827-file fair corpus compiled with the optimizing flags (370,115 instructions, 1,672,166 bytes of image at the time), two bytes saved per site: page 2 59,354 sites, 118.6 KB (7.1%); `CBCC` with an immediate in -16 to 15 6,390 sites, 12.8 KB (0.8%); `RORI32` 896 sites, 9.0 KB (0.5%); all together 66,640 sites, 140.4 KB (8.4%). The per-family counts are in the specification, CHANGES-SINCE-R20.md §12. The compiler also emits `LEA 1(Rx), Rx` 7,852 times and `LEA -1(Rx), Rx` 395 times where `INC` and `DEC` exist (about 16 KB, 1.0%), and the 36,555 six-byte external `CALL` and `LEA sym` forms (4.4%) need linker relaxation, not an encoding. These are estimates from the assembly output, not measurements of the new encoding.

---

## 15. What was taken from LoongArch, and what was not

LoongArch64 is worth studying here because it is the most recent clean-room ISA designed without an ideological commitment — it borrowed from MIPS, from RISC-V and from ARM as each had the better answer, which is exactly the posture §1.1 adopts.

### 15.1 Adopted

| Idea | LoongArch form | Here |
|---|---|---|
| **Bit manipulation is core, not an extension** | `CLO`/`CLZ`/`CTO`/`CTZ`, `BSTRINS`/`BSTRPICK`, `BYTEPICK`, `REVB`/`REVH`/`BITREV`, all in the base ISA | `BESC`, §4.6. This was the decisive argument for giving it a top-level opcode rather than leaving the functions scattered or absent |
| **Atomics with the barrier folded in** | `AMSWAP`, `AMADD`, `AMAND`, `AMOR`, `AMXOR`, `AMMAX`, `AMMIN`, each with a `_DB` variant | `ATOM`, §4.11. A lock acquire is one instruction rather than an atomic plus a `FENCE`, and that pair is in every critical section in the system |
| **Direct mapping windows** | `CSR.DMWn`, `VA = PA + FixedOffset`, with cache attributes selected by high VA bits | §8.3. The kernel stops taking TLB misses on its own text, physical memory is reachable without mapping, and early boot has no chicken-and-egg |
| **Memory type as a page attribute** | `DMW` cache attributes: strongly-ordered uncached, coherent cached, weakly-ordered uncached | `MT` field, §8.2 |
| **A richer atomic set than the minimum** | fetch-and-min/max as well as add/and/or/xor | §4.11. Each is a couple of hundred LUTs and saves a `CAS` retry loop |

### 15.2 Declined, with the reason

| Idea | Why not |
|---|---|
| **`R0` hardwired to zero** | At 32 registers, losing one to get `MOVQ R0, Rd` as clear and `SUB R0, Rn` as negate is a good trade. At 16 it is a sixteenth of the file, and `CLR` and `NEG` are already one parcel each. The trade reverses with register count |
| **No condition codes; compare-and-branch instead** | A comparator in the branch unit plus a third register read port, versus a four-bit latch (§4.4). LoongArch can afford it because its fixed 32-bit encoding has room for two register fields and a displacement in one instruction; ours would need two parcels, which is the same size as `CMP`+`B`. `SOB` covers the loop case that motivates the idiom |
| **`FCSR` with a rounding-mode field** | LoongArch kept the mode bits, as did RISC-V, ARM and x86. We are the outlier and remain so: the founding rule (§1.1) forbids invisible state that changes what other instructions mean, and rounding mode is the textbook case. The cost is more opcodes in `FESC`, which is the cheapest thing we have |
| **Four PC-relative address-formation instructions** | `PCADDI`, `PCADDU12I`, `PCADDU18I` and `PCALAU12I` exist because a fixed 32-bit encoding carries twenty bits of immediate, so building a full address takes a pair. `LEA d(PC), Rn` at `len = 10` carries 32 bits in one instruction (§4.1). This is the clearest case where variable-length beats fixed-width, and the property came free from §3.1 |
| **32 general registers** | Doubles the register file and costs a bit in every register field — which this encoding does not have to spend. Sixteen is where the one-memory-operand rule (§3.4) left room |
| **Separate vector register files (LSX, LASX)** | A second wide register file is the thing §2.3 specifically avoided, and it would bring wide load/store paths entangled with §7.4's alignment rules plus a large opcode demand on a map already at 55 of 64. Wide data-parallel work goes in a Q64 coprocessor with its own memory, which needs **no opcodes at all** — revision 5's model, and the LB64 document is the worked case |

### 15.3 Under consideration

- **Separate FP condition flags.** LoongArch's eight one-bit `FCC` registers solve a real problem that §12.7 records.
- **Software-visible TLB manipulation.** LoongArch has both a hardware walker *and* `TLBSRCH`, `TLBRD`, `TLBWR`, `TLBFILL` — so the kernel can manage entries directly when it knows better. We have only `TLBI`/`TLBIA`. Being able to pin an entry is useful for a realtime kernel, and worth one `SYS` sub-opcode.
- **`MASKEQZ`/`MASKNEZ`.** Conditional-move primitives that avoid a branch. With flags available, `CMOV` would be the natural form, and the branch-free-select case matters for constant-time cryptographic code where it is not optional. `SET cc, rd` (§4.12) was added; a select is on hold (§12 item 15).

---

## 16. What the architecture owes devices

Graphics, networking, storage and the C64-derived devices of revisions 6 and 7 are all Q64 devices, and **none of them touches the ISA**. That separation is deliberate and worth stating, because it is what lets the device side churn without respecifying the processor.

What the ISA owes them is exactly three things:

1. **A memory type per page** (`MT`, §8.2), so a framebuffer can be mapped uncached and a command queue weakly ordered, without the code doing the writing having to know.
2. **An ordering instruction** (`FENCE`, §4.11) with a defined meaning against Q64, so a driver can be sure a descriptor is visible before a doorbell write is.
3. **Atomics that reach device memory** (§4.11), for queues shared between the processor and a device.

**Device interface convention (a design decision of the project's author; layouts not yet specified).** Network (Ethernet), USB and disk devices are each presented to the processor as **eight memory-mapped registers**, that is, eight addresses in the ordinary address space, and they move their data by **DMA**. The reason is the amount of code: with so small and regular an interface a driver is trivial to write, and because the device moves its own data the processor only sets up a transfer and does not carry a multitasking burden for it, so that more of the processor is left for the user and for the programs that matter. This costs the ISA nothing: it is bus and device design, and it uses only the three things above (the memory type of the register page, `FENCE` before a doorbell write, atomics for shared queues). The register layouts, the DMA descriptor format and the interrupt convention are still to be written; when they are, they belong in a companion document and, like the instruction numbers, should be written once and generated.

Everything else — blitters, raster engines, command FIFOs, whether there is a GPU at all — is bus and device design, and belongs in the companion documents rather than here:

- **the implementation plan**, §12, for the display path: `BLT64`, the Blit model, framebuffer budgets, and why an off-the-shelf GPU is not reachable;
- **the bus document** ([`pdp64-q64-bus.md`](pdp64-q64-bus.md)), for Q64 itself, the device convention and the open items about the bus, including open item 4;
- **the LB64 document**, for the sub-1-bit inference accelerator — which is the worked proof of this section, being a substantial bus-mastering device that needed **no ISA change at all**, and whose §14 works out what happens if the compute moves into the memory.

---

## 17. Symmetric multiprocessing

Added in revision 15. Multiple Q64 initiators already exist — the LB64 accelerator is one — but a DMA master and a second CPU are different problems with different answers, and conflating them is the usual way this goes wrong.

### 17.1 The memory model is the whole question

Instructions are the easy part. The hard part is what a program is promised about the order in which another core sees its writes, and the choice is close to irreversible: software written against a weak model runs on a strong machine, but not the reverse.

| Model | Used by | Cost to implement | Cost to software |
|---|---|---|---|
| **Sequential consistency** | almost nobody, commercially | high on a speculative out-of-order core | **none** |
| TSO | x86, SPARC | store buffer with load forwarding | modest — store-load reordering only |
| Weak / relaxed | ARM, POWER, RISC-V RVWMO | cheapest in hardware | **high, and permanent** |

> **pdp64 is sequentially consistent.** Stated here, once, and not revisited.

This is the most valuable decision in the section and on this machine it is nearly free, which is the point. A weak memory model is a tax paid by every piece of concurrent software ever written for the architecture, levied so that an aggressively speculative out-of-order core can reorder memory operations. **pdp64 is in-order and non-speculative** (§1 constraint 1), so there is no reordering to permit and nothing to buy with the weakness.

A store buffer is still allowed, and wanted, for write latency hiding: SC survives it provided loads snoop the buffer and stores drain in program order. The cost is that a store miss stalls later stores, which on two to four cores behind a shared L2 is acceptable.

What the industry learned the hard way is worth stating as the reason this is not a close call. ARM's memory model took roughly a decade to formalize, academic papers are still finding corners in vendor implementations, and the C11/C++11 memory model exists in large part to paper over the differences between weak architectures. None of that complexity buys anything on a machine that does not speculate. Being small is the advantage here.

**And two whole classes of problem simply do not arise.** Non-speculative execution means no Spectre- or Meltdown-class speculative side channels. And §7.4's alignment requirement means every access is naturally atomic within its own size — misaligned atomicity is a genuine nightmare on x86 and ARM, and pdp64 gets it free from a rule adopted for the datapath's sake and already paying for lowtags (§6.2). That is the third return on one decision.

### 17.2 What the ISA needs — six additions

| Instruction | Purpose |
|---|---|
| `MFCPUID Rd` | which core am I. Required for per-CPU data structures; there is no way to synthesize it |
| `ICINV Rd` / `ICINVA` | invalidate an instruction-cache line, or all of it |
| `TLBSYNC` | wait for a broadcast `TLBI` to complete everywhere |
| `WFE` | wait for event — sleep until another core signals |
| `SEV` | send event — wake cores waiting in `WFE` |
| — | `TLBI` and `TLBIA` are respecified as **broadcasting** to all cores |

Short notes on the three non-obvious ones.

**`ICINV` exists because instruction caches are not coherent with data caches**, on this machine or on ARM or POWER. Making them coherent costs a snoop port on the I-cache for a case that almost never happens. But "almost never" is not never: a JIT, a trampoline, a loaded module, and a Lisp runtime compiling a function all write instructions as data and then execute them. Without `ICINV` they are unimplementable, and revision 14 had no such instruction — a straightforward hole on a machine whose §6.3 goes out of its way to support Lisp runtimes.

**Broadcast `TLBI` rather than software shootdown.** When one core unmaps a page, the others' TLBs must be invalidated. x86 does this with an inter-processor interrupt and a software handshake, which is slow and intricate. ARMv8 made `TLBI` broadcast by default, and for two to four cores that is both simpler in hardware and far faster. `TLBSYNC` is the completion barrier, because a broadcast that you cannot wait for is useless.

**`WFE`/`SEV` rather than a spin hint.** x86's `PAUSE` tells a spinning core to back off; ARM's `WFE` lets it actually stop until `SEV` or an interrupt arrives. The latter is better on an FPGA, where a spinning core is consuming memory bandwidth the other cores want. `WAIT` is accepted as an assembler alias for `WFE` (§4.15), which serves as the uniprocessor idle.

The atomics of §4.11 are already sufficient — `CAS`, `LL`/`SC`, the fetch-and-op family, and the `_DB` barrier-fused forms. Nothing more is needed there, and `_DB` was taken from LoongArch precisely because a lock acquire should be one instruction.

### 17.3 Cache coherence is a cache question, not an ISA question

For two to four cores on one FPGA: **snooping MSI.** Three states, a snoop port on each D-cache, perhaps 500 LUTs and a state machine. MESI adds an Exclusive state to avoid a bus transaction when writing a clean line held by nobody else; at this core count the benefit is small and the state machine is meaningfully larger. Directory-based coherence scales further and is not needed below about eight cores.

The important property is that **coherence is transparent to software**. Software-managed coherence — explicit flush and invalidate around every shared access — is cheaper in hardware and is where concurrency bugs go to live, because every missing flush is a race that reproduces once a week. The ISA owes nothing to a transparent coherence protocol, which is the correct division.

**Device DMA is the opposite case and gets the opposite answer.** LB64 writing results the CPU has cached is also a coherence problem, but snooping the DMA path is expensive and the access pattern is known: large, infrequent, with an explicit handoff. Mapping those buffers `MT = 01` uncached (§8.2) and fencing at the doorbell costs nothing and is already how the LB64 document specifies it. So: transparent coherence between CPUs, explicit uncached mapping for accelerators. Two mechanisms, each where it is cheap.

### 17.4 What falls out for free, and what must be built

Already present without having been designed for it:

- **`DP` is the per-CPU pointer.** The direct page register has three mode-switched copies (§2.2), so in kernel mode it can address the per-CPU structure, and mode `0011` reaches it with a 12-bit displacement in one four-byte instruction. A fast per-CPU base is something every SMP kernel builds by hand; here it is a register that already exists for an unrelated reason.
- **`ASID`** (§8.1) already makes the context switch constant-time, which matters more with more cores competing for the TLB.
- **`G`-bit entries and `DMW`** (§8.3) keep the kernel's own mappings out of the shootdown path entirely, since a global or window-mapped page is never invalidated by an address-space change.

Still to be built, device-side rather than in the ISA: an inter-processor interrupt path (a memory-mapped per-core register is sufficient and needs no APIC-like complexity), a boot protocol for releasing secondary cores from reset, and a shared L2 or at minimum a coherent interconnect.

### 17.5 Explicitly avoided

| Avoided | Reason |
|---|---|
| **Weak or relaxed memory ordering** | §17.1. Nothing to gain without speculation, and the cost to software is permanent |
| **Speculative execution** | not in the design point; also no Spectre-class channels |
| **Hardware transactional memory** | Intel TSX produced a decade of errata and side channels for a feature few programs used. `CAS` and `LL`/`SC` suffice |
| **Software-managed cache coherence between CPUs** | cheaper in hardware, and the bugs are races that reproduce weekly |
| **Coherent instruction caches** | a snoop port for a rare event; `ICINV` makes the rare event expressible instead |
| **IPI-based TLB shootdown as the primary mechanism** | broadcast `TLBI` is simpler and faster below eight cores. IPIs remain for scheduling |
| **A memory-model-dependent ABI** | with SC there is nothing for the ABI to say about ordering, which is the point |

### 17.6 The blocking dependency

Open item 4 — `DATIP`/`DATO` as a bus lock against AXI exclusive access as a monitor — has been deferrable through fourteen revisions because there has only ever been one initiator. **With SMP it is blocking.** Two cores contending for the same lock word, or a core and LB64 contending for a descriptor's status field, is exactly the case where a lock and a monitor behave differently, and `LL`/`SC` needs a reservation that another core's write invalidates. Settle it in the bus document before any second core exists.

---

## 18. Glossary

Terms this document uses without defining them, collected because several were introduced in a changelog bullet and never expanded.

| Term | Meaning |
|---|---|
| **parcel** | a 16-bit unit of instruction encoding. Instructions are 1–3 parcels (§3.1) |
| **`len`** | bits 15..14 of parcel 0: the number of *extension* parcels for `00`, `01` and `10`; the value `11` selects page 2 (§3.1) |
| **page 2** | the second opcode map, selected by `len = 11`: 64 entries of one-parcel instructions, 41 defined, each an exact abbreviation of a page-1 instruction (§3.1.2, §4.18). Page 1 is the map of `len = 00`, `01` and `10` (§4.16) |
| **`CBCC`** | **c**ompare-immediate-and-**b**ranch on **c**ondition — opcode `0x28`, the fused compare and branch (§4.4.1) |
| **`RORI32`** | rotate right by an immediate, 32-bit, zero-extended result — a `BESC` sub-opcode (§4.6) |
| **`BESC`** | **b**it **esc**ape — opcode `0x0C`, bit, field and rotate manipulation (§4.6) |
| **`MBLK`** | **m**emory **bl**oc**k** — opcode `0x0D`, the block memory operations (§4.7) |
| **`MESC`** | **m**emory **esc**ape — opcode `0x0F`, unaligned access and ALU-to-memory (§4.13) |
| **`FESC`** | **f**loating-point **esc**ape — opcode `0x10`, FMA, `binary16`, `binary32`, divide, square root, classify, convert (§4.10) |
| **`AESC`** | **a**rithmetic **esc**ape — opcode `0x0E`, divide, remainder, high multiply, abs/min/max, `SET` (§4.12) |
| **`FPSR`** | the sticky five-bit floating-point exception flag register, read and written by `FSFLAGS` (§4.10.1) |
| **`XFER`** | transfer escape — opcode `0x12`, `JMPI`, `CALLI`, `JTAG` (§4.9) |
| **`TAGOP`** | opcode `0x15`, the tag-branch group (§4.8) |
| **`SOP`** | single-operand escape — opcode `0x13` (§4.5) |
| **`ATOM`** | opcode `0x11`, atomics with and without barrier (§4.11) |
| **`SYS`** | opcode `0x14`, system control (§4.11) |
| **`Q64`** | the system bus: the PDP-11 Q-bus lineage widened to 64-bit data and 40-bit addressing, defined in 11/64 revision 5. It keeps the Unibus and Q-bus programming model, including `DATIP`/`DATO` locked read-modify-write. Unibus → Q-bus → Q64 |
| **`DATIP` / `DATO`** | Unibus and Q-bus transaction types: data-in-pause and data-out, which together form a locked read-modify-write. Carried into Q64; see §17.6 |
| **`DMW`** | direct mapping window — a region translated as `PA = VA − base + physbase` with no page table reference (§8.3) |
| **`ASID`** | address space identifier, tagging TLB entries so a context switch flushes nothing (§8.1) |
| **`MT`** | memory type, a two-bit page attribute selecting cached, uncached or device ordering (§8.2) |
| **`lowtag`** | a type tag stored in the low bits of a pointer, available because quad-aligned objects have zero there (§6.2) |
| **SWAR** | **S**IMD **W**ithin **A** **R**egister: using one wide scalar register as several narrow lanes through masking and carry-aware arithmetic. The classic case is finding a zero byte in a 64-bit word with `(x − 0x0101010101010101) & ~x & 0x8080808080808080`. It is how byte-parallel work is done without a vector unit, and §4.6's bit operations plus 64-bit registers make it effective here. The reference is Warren's *Hacker's Delight*; glibc's `strlen` is the canonical production example |
| **block floating point** | representing a vector as integer mantissas sharing one exponent. Used by the LB64 accelerator to make fixed-point accumulation exact, and the reason it needs no floating-point adders |
| **Payne–Hanek** | the argument-reduction algorithm that computes x mod π/2 to full precision for large x, using as many bits of π as the exponent requires. The thing hardware transcendentals cannot do (§9.7.1) |
| **Table Maker's Dilemma** | that correctly rounding a transcendental function may require unboundedly many intermediate bits to resolve a near-tie, so no fixed-time circuit can guarantee it (§9.7.1) |
| **ulp** | unit in the last place: the spacing between adjacent representable floating-point numbers, the unit in which rounding error is measured |

---

## 19. Position-independent code

Short answer: **yes, and cheaply — the architecture is in the x86-64 and AArch64 class rather than the i386 class.** Revision 18 closed the one gap. Working through it is worthwhile because PIE exercises precisely the features revisions 8 and 9 pruned.

### 19.1 The requirements, checked

| Requirement | Mechanism | Cost |
|---|---|---|
| intra-module branches | PC-relative by construction (§4.4) | native, 2–6 bytes |
| intra-module calls | `CALL d(PC)` | one instruction |
| module-local data | mode `0010`, `d(PC)` | one instruction |
| address formation | `LEA d(PC), Rn`, 32-bit at `len=10` | one instruction |
| **GOT access** | `MOVQ got_slot(PC), Rd` | **one instruction, no GOT register** |
| **PLT stub** | `JMPI got_slot(PC)` | **one instruction, no scratch register** (§4.9.1) |
| TLS, local-exec | `MOVQ d(DP), Rd` (§19.3) | one instruction |
| load-time relocations | loader concern | unaffected |

**The decisive item is the GOT.** On i386, PIE reserved `%ebx` — one of eight registers — to hold the GOT base, and every function prologue had to establish it. That is why i386 PIE cost a measurable few percent in both size and speed. x86-64 fixed it with RIP-relative addressing: the GOT entry is reached directly from the program counter, so no register is reserved and no prologue code is needed.

**pdp64 has had that since revision 9**, because mode `0010` is an ordinary addressing mode available to every instruction rather than a special case. `MOVQ got_slot(PC), Rd` loads an imported symbol's address in one four-byte instruction. No GOT pointer, no prologue, no reserved register.

### 19.2 PIE code can be *smaller* than non-PIE here

This inverts the usual expectation for small displacements and follows from §3.3's displacement scaling.

| Access to a global | Encoding | Bytes |
|---|---|---|
| non-PIE, absolute | mode `0101`, 32-bit absolute at `len=10` | **6** |
| PIE, PC-relative, within ±32 KB | mode `0010` at `len=01` (16-bit byte displacement) | **4** |
| PIE, PC-relative, within ±2 GB | mode `0010` at `len=10` (32-bit byte displacement) | **6** |

(Before 2026-10-22 the absolute form was the 48-bit `len=11` form, eight bytes, and PIE access was two to four bytes shorter than absolute. With the fourth parcel gone the absolute form is a sign-extended 32-bit address, six bytes, or four bytes if the address fits 16 bits sign-extended. The comparison with `len=01` is now the one that matters: **PC-relative access within ±32 KB is four bytes, and no longer than absolute at any distance.**)

An absolute address reaches only what a sign-extended 32-bit (or 16-bit) value can hold; PC-relative access within ±2 GB needs no more bytes than that. **Position-independent data access is never longer than absolute**, per access, and is two bytes shorter within ±32 KB: still the opposite of the i386 experience, and still a consequence of having chosen a variable-length encoding.

### 19.3 Thread-local storage

`DP` in user mode is the thread pointer (§2.2), which makes the common TLS model one instruction:

```
        MOVQ    tls_offset(DP), R0      ; local-exec TLS, 4 bytes
```

That is as good as AArch64's `TPIDR_EL0` form and better than x86-64's, which needs a segment prefix. The other TLS models — initial-exec, local-dynamic, general-dynamic — need GOT entries and in the dynamic cases a `__tls_get_addr` call, exactly as elsewhere; nothing in the ISA makes them harder.

The pleasing part is that `DP` was not designed for this. It entered at revision 1 as the 6502 zero page's descendant, kept for code density, and its mode-switched copies turn out to be what a threaded runtime wants in user mode and what an SMP kernel wants in kernel mode.

### 19.4 No veneers below 4 GB

A conditional or unconditional branch at `len=10` reaches ±4 GB (§4.4); before 2026-10-22 `len=11` reached the whole canonical address space. AArch64's `BL` spans ±128 MB and large binaries therefore need linker-inserted veneers; ARM32's ±32 MB made them routine. **pdp64 needs none below a binary of 4 GB**, so branch-range veneer insertion — a persistent source of linker complexity and of surprising code growth — simply does not exist as a problem.

The assembler's branch relaxation reduces to choosing a length, and the linker's to the same.

### 19.5 What the ABI had to decide

The ISA is sufficient; three ABI questions were left open here and belong in the ABI document, `abi.md` (version 1), whose answers are noted below.

1. **A designated linker-scratch register — decided: `R12` (ABI version 1, `abi.md`).** ARM32 reserves `R12`/`IP` and AArch64 `X16`/`X17` for veneers and PLT sequences. Pressure here is much lower — §19.4 removes veneers for any binary below 4 GB and §4.9.1's `JMPI` removes the PLT's need for one — but linkers want a scratch register for lazy-binding resolver sequences and for `-fno-plt` call sites. `R12` is the natural choice, both because it is the highest register with no other role and because the number happens to match ARM32's convention.
2. **Lazy versus eager binding** (still open; `abi.md` is silent). `JMPI got(PC)` makes a PLT stub one instruction, so the argument for lazy binding — avoiding resolver work for uncalled functions — is weaker than usual, while full RELRO with eager binding gets a security benefit. Worth measuring startup cost before choosing.
3. **Whether `-fno-plt` should be the default** (ABI version 1 calls imports through `CALLI got(PC)`, i.e. without a PLT stub). Calling through `CALLI got(PC)` at the call site skips the PLT stub's extra transfer entirely, at the cost of a GOT load per call site rather than per function. One instruction either way, so this is a cache-behaviour question, not an instruction-count one.

### 19.6 Summary

Nothing about position-independent code is expensive on this architecture, and one aspect of it is cheaper than the position-dependent alternative. The three things that make it so were all adopted for unrelated reasons:

- **PC-relative addressing as an ordinary mode** (§5), adopted because `R7`-as-`PC` was given up and the forms had to go somewhere — which turned out to be strictly better than a dedicated GOT register.
- **Variable-length encoding** (§3.1), adopted for density, which makes a short PC-relative displacement cheaper than a long absolute address.
- **`DP`** (§2.2), adopted for code density in 1970s terms, which is the thread pointer.

The one thing that was genuinely missing — indirect transfer through memory, for PLT stubs and vtables — was a casualty of removing deferred modes in §5.2 and is restored in §4.9.1 as a contained exception.

---

## Appendix A. Changes from revision 20

Revision 20 as received was written under the working name 11/64W; the original is unmodified in `docs/orig/` (`orig/11-64W-isa-r20.md`). Every change since is below, with its source: *E* is the item number in `errata.md`, *C* the section of `CHANGES-SINCE-R20.md`. Where the grammar (`spec/pdp64-mnemonics.hbnf`, `spec/pdp64.hbnf.in`) and prose differ, the grammar governs.

| Change | Where here | Source |
|---|---|---|
| The machine is named pdp64 (working name 11/64W) | whole document | E12, C intro |
| Opcode bits of the BESC, MBLK, TAGOP diagrams corrected to `001100`, `001101`, `010101` | §4.6, §4.7, §4.8 | E1, C2.1 |
| Opcode count corrected: 55 assigned, spare ALU slot `0x23`, 8 reserved `0x28`–`0x2F` (not 56). Superseded on 2026-10-22: `0x28` is `CBCC`, so 56 assigned and 7 reserved `0x29`–`0x2F` (next lines) | §4.16, §4.2, §9.6 | E2, C2.1 |
| PC-relative base is the first parcel of the instruction; operand displacement in bytes, branch displacement in parcels | §4.1, §4.4, §5, §9.3 | E3, C4.1 |
| `PUSHM`/`POPM` moved from `MBLK` to `SOP` slots `A`/`B`, mask a 16-bit immediate | §4.5, §4.7 | E4, C3.2 |
| `SYS` split into a 4-bit class and a minor; `TRAPL #n` added (class 15) for vectors 0–255 | §4.11 | E5, C4.4 |
| `PROBER`/`PROBEW` take the second register in parcel 1 | §4.11 | E5, C3.3 |
| `JTAG` legal only in scaled-index mode, `Rx` tagged, scale ignored | §4.9, §6.3 | E6 |
| Scaled-index mode widens to 6 / 22 / 38 bits (6 / 22 after E31); direct-page padding at `len=01` | §3.3, §5 | E7, C4.2 |
| `SOB` exists from `len=01` with 16/32/48-bit displacement in parcels (16/32 after E31) | §4.4 | E8 |
| Sub-opcode numbers assigned and operand roles fixed | §4.17 | E9, C4.3, C4.5 |
| `RORI` added; `ROL #n` assembles to `RORI` with `64 − n`; `DSHR`, `EXTB`, `EXTZB`, `INSB` need parcel 2 | §4.6, §4.15 | E10 |
| `MESC` parcel 1 is `sub4 rm4 disp8`, widening 8/24/40; no scaled-index mode | §4.13 | E11 |
| `CMP` computes `reg − rm`, written register-first | §4.2 | E13 |
| Flags: `C` is a borrow on subtract and compare; `ADD` sets `C` on carry; `FCMP` flags `N`/`Z`/`V`, `C` cleared | §4.2, §4.10 | E14 |
| Pre-decrement is `-(Rn)` or `(Rn)-d`; `-d(Rn)` is always base + displacement | §5 | E15 |
| `FRECPED`, `FRSQRTED` dropped | §4.10, §9.9, §11 | E16 |
| Floating-point exception flags: sticky `FPSR`, `FSFLAGS` (`FESC` `0x40`), never trap | §2.2, §4.10.1 | E17 |
| `FCVTDQU`, `FCVTQUD` added | §4.10 | E18 |
| `FRINTDA` (now `FRINTA`) added | §4.10 | E19 |
| `CRC32`/`CRC32C` considered, added, withdrawn; `CLMUL` stands | §4.6.3, §11 | E20 |
| `FCMP` is register-first | §4.10 | E21 |
| `FESC` operand roles; FMA, divide and copysign semantics | §4.10 | E22 |
| Integer `ABS`, `MIN`, `MINU`, `MAX`, `MAXU` added | §4.12 | E23, C3.4 |
| Floating-point spelling: `FADD` is `binary64`, a bit-width suffix names other widths; old spellings are aliases under one rule | §4.10, §4.15 | E24, C3.5 |
| `SET cc, rd` added | §4.12, §4.4 | E25 |
| NaN results are the canonical quiet NaN | §4.10.2 | E26 |
| `binary16` added: seventeen `FESC` words `0x50`–`0x65` | §4.10 | E27 |
| `IOT`/`EMT` aliases dropped; `WAIT` is an alias of `WFE` | §4.15, §4.11.1 | C3.1, C3.5 |
| Little-endian data and parcels stated | §3.2, §4.17 | C2.2, C4.6 |
| Minimum instruction lengths stated | §4.17 | C4.7 |
| ABI roles of the registers and the data model (LP64, stack alignment 8) | §2.1, §2.3, §19.5 | C5, `abi.md` |
| Counts: 247 mnemonic words, 213 instructions, 93 operations (before the second page; the counts after it are TODO-COUNT mnemonic words, TODO-COUNT instructions, TODO-COUNT operations) | §13.1 | C1, E27 |
| Fourth parcel removed: instructions are 1, 2 or 3 parcels (2, 4 or 6 bytes); immediate, absolute, PC-relative and branch payloads 16 or 32 bits, base and direct-page displacement 12 or 28, scaled-index 6 or 22 | §3.1, §3.3, §4.4, §5, §7.3, §9.6, §19 | E31, C12 |
| `len = 11` is page 2: 64-entry map of one-parcel exact abbreviations, 41 defined, 23 reserved (illegal-instruction abort) | §3.1.2, §4.18 | E31, C12 |
| `CBCC` (compare immediate and branch) takes top-level opcode `0x28`: 56 assigned, 7 reserved `0x29`–`0x2F` | §4.4.1, §4.16 | E31, C12 |
| `RORI32` added as a `BESC` sub-opcode | §4.6 | E31, C12 |
| Page-2 forms are not mnemonics; `CBCC` mnemonics `CBNE` … `CBLOS` | §4.15 | E31, C12 |
| Open item 18 resolved; §9.6 rewritten, decision recorded in §9.9; rejected alternatives in §11 | §9.6, §9.9, §11, §12 | E31, C12 |
| Open items resolved or added (directed rounding, select, bfloat16 …) | §12 | C12, C14 |
