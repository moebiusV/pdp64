Status: record, dated 2026-11-03. It describes the state and the thinking of that time. The current state is in docs/manual and docs/decisions-and-status.md; where this document disagrees, those win. Out of date: the decisions are errata 85 and 86 and the ledger; there is one CPU (the 32-register prefix-coded encoding; r20 and pdp64/16 are gone, errata 122 and 123), the bus is virtio and PCI Express (errata 95, 101), section numbers of the manual are those of the manual at the time (it was renumbered, errata 121: find a part by its title)

# Study proposals, round two: replies to the annotations

[← pdp64 index](../README.md)

For the author's annotation. This answers the questions on [`study-proposals.md`](study-proposals.md). The decisions it records are errata 85.

## 1. Does the mirror shadow stack give the protection of CHERI, and what would 128-bit capabilities cost?

**Dense and mirror, in plain words.** Both keep a second copy of each return address, so that a `RET` can compare the copy on the ordinary stack with the protected copy.

* *Dense* keeps the copies in a separate small stack of their own, found through a new pointer register. It is compact (8 bytes per call), but the pointer register must be saved and restored by `setjmp`, `longjmp`, context switches and signals, which needs two new instructions, and switching between shadow stacks needs a checked token.
* *Mirror* (approved) stores the copy at a fixed distance from the real slot, in pages only `CALL` and the kernel can write. There is no pointer register, so `setjmp`, `longjmp`, unwinding, context switches, signals and `fork` need no extra instruction at all. The price is memory: up to one extra page per stack page that holds a return address.

**The protection is not the same as CHERI's.** Each approved item guards one thing:

| Guards | Mechanism | Strength |
|---|---|---|
| Return addresses (backward edge) | Mirror shadow stack | Deterministic: an overwritten return address faults at `RET`. |
| Indirect jumps and calls (forward edge) | Landing pads on a page bit | Deterministic: a target that is not a landing pad faults. |
| Heap overflow, use after free, uninitialised reads | Granule colouring and the two reserved colours | Probabilistic: a 4-bit colour misses a collision about 1 time in 16 unless the allocator keeps neighbours different. |
| Stack overflow | Stack limit register | Deterministic. |

CHERI adds three things none of these provides: pointers cannot be forged from integers, every pointer carries exact bounds, and a pointer can be sealed to build compartments. So the answer to "if so we can reject CHERI" is **not entirely**. The mirror covers return addresses well; it does not cover forged or out-of-bounds data pointers.

**What it would cost to do the full 128 bits.** The register file is the cheap part.

| Part | Cost |
|---|---|
| Widen 16 registers from 64 to 128 bits | About 1,000 more flip-flops plus 16 tag bits and wider read and write paths: small in gates, as you say. |
| Memory | Every pointer becomes 16 bytes and 16-byte aligned. Pointer-heavy data (lists, trees) grows toward twice the size; published overheads range from a few percent to tens of percent *(from memory, not confirmed)*. |
| Caches, bus and DMA | A 1-bit tag per 16 bytes follows every line through the caches and DRAM, and Q64 (64-bit data) takes two beats per pointer. Any device write must clear the tag. |
| Instructions | Pointer loads and stores, bounds-narrowing, sealing and checking instructions: roughly a dozen. |
| The ABI | `sizeof(void*)` becomes 16 and `intptr_t` becomes 128 bits. The decision that registers are 64 bits ("one profile", ISA 6.1) is reopened. |
| Software | This is the dominant cost. The compiler, the C library, the kernel and every program that stores a pointer in an integer must change. CheriBSD (FreeBSD-derived) did this; OpenBSD has no CHERI port *(from memory, not confirmed)*. |

The hardware is cheap and the software is very expensive, the opposite of most of the features here.

**Recommendation.**

1. Reject full 128-bit CHERI.
2. Keep **stage 1 of item 3**: one valid-pointer tag per register and per 8-byte memory word. It is the one thing the approved set lacks (pointers cannot be forged), it shares its register metadata with items 10 and 11, and it costs one tag bit per 8 bytes.
3. Defer the 21-bit compressed bounds (stage 2) until the colouring measurement shows how much spatial protection the colours already give.

**Your annotations:**

i accept your recommendation.

&nbsp;

## 2. Trap and abort

Both are exceptions. The difference is whether the instruction that raised it is finished.

* An **abort** is a fault in the middle of an instruction: the instruction did not complete, `EPC` is that instruction, and `RTI` runs it again. Page faults, alignment and protection faults are aborts.
* A **trap** completes the instruction first: `EPC` is the next instruction, and `RTI` carries on after it. `TRAP #n`, `BPT` and interrupts behave this way.

For `TRAPCC` as a trap, a handler that returns carries on after the check; as an abort, it would re-execute the check and re-test the flags. A check has nothing to retry, and its handler normally terminates the program or unwinds, so **trap** is the right choice, as proposed. The decision is recorded in errata 85.

**Your annotations:**

good, it is a trap not an abort


&nbsp;

## 3. Item 10, the choices compressed

Poison is a bit on a register meaning "this value came from a failed operation; using it is an error". Three choices remain.

| # | Choice | Options | Lean |
|---|---|---|---|
| a | A comparison of a poisoned value | (1) set a "flag poison" bit so the later branch faults; (2) fault immediately at the instruction that writes the flags | **2.** One fewer state bit and the fault comes one instruction earlier. |
| b | Who decides a deferred load's fault | (1) the kernel's fault handler decides: repair and restart, or mark the destination register poisoned; (2) the hardware marks guard pages and the null page in the page table and poisons without trapping | **1.** About ten lines of kernel code and no hardware beyond the bit; (2) can follow as an optimisation. |
| c | Whether `TRAP #n` checks the argument registers | (1) hardware checks `R0` to `R5`; (2) the kernel's dispatcher tests the saved poison mask itself (two instructions) | **2.** Stale poison in unused argument registers would cause false faults under (1). |

**Your annotations:**

&nbsp;

your recommendations accepted.


## 4. Item 12: the `NS` page bit and item 11's `SEC` page

Two different page bits do two different jobs.

* **`SEC`** (item 11) marks a page whose contents are secret. Data loaded from it carries the secret-taint, and constant-time checks fault if it is used as an address, a branch condition or a variable-time operand.
* **`NS`** (item 12, "no speculative forwarding") is about speculation: a load from an `NS` page does not hand its data to any dependent instruction until the load is certain to retire, so a mispredicted path cannot leak it by any channel.

A key page wants both. But they stand alone: `NS` is useful on pages that are not secret in the taint sense (data across a sandbox boundary, say), and `SEC` is useful on a secure in-order core where nothing speculates. **Lean: keep them independent** (fewer coupled states, fewer surprises). The operating system sets both on a concealed mapping (`MAP_CONCEAL`).

**Your annotations:**

agree, keep independant.


&nbsp;

## 5. Item 18, the open choices in one line each

| # | Choice | In one line | Lean |
|---|---|---|---|
| 1 | Recovery: option A or B | A keeps OpenBSD's way (the copy routine stores a recovery address in the thread block before copying); B has no stored pointer: the fault handler finds the failing instruction in a read-only table of recovery addresses, so `copyin` is 3 instructions. | **B** (less code, less to set up and undo). |
| 2 | Spelling `.U` | The suffix that says "access this one operand as user", e.g. `MOVQ.U (R0), R3`. | Keep `.U`. |
| 3 | Keep `PSW.UA`, `STUA`, `CLUA` | The old open-window mechanism becomes unused by the base system. | Keep until the OpenBSD port proves the new scheme, then retire them (frees a status bit and two opcodes). |
| 4 | `ECAUSE` bit 15 | The hardware marks aborts that came from a user-qualified access, so the handler knows without looking. | **Yes** (a bit and a few gates). |
| 5 | Atomics take the user form | A futex on a user word needs a user-qualified atomic. | **Yes**, once the operand placement of `ATOM` is fixed. |

**Your annotations:**

i agree to your recommendations


&nbsp;
