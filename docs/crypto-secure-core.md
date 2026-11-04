# The secure core class and the cryptographic instructions

[← pdp64 index](../README.md)

For the author's annotation. This follows the author's decisions on `security-round2.md` section 2: the branch-free select is in; at least one core is secure, with every timing channel removed, cache lines private, and no timer tick where none is required (the later annotation); constant-time AES and SHA instructions, "or whichever opcodes would speed up and enable aes and sha"; any protection that costs nothing on the other cores goes on them too. The proposals are scored against the definitive list (errata 83): **1** security and safety (an error that cannot arise; else easy to detect; else cheap to recover from; no strange side effects), **2** opcode choice (fewer instructions executed; coalescing is good), **3** opcode encoding (dense; rare means longer), **4** speed and power (low gate count), **5** compiler target, **6** assembler; beside them out-of-order readiness, the soft-rule test, hot-loop weight and Occam.

**Sourcing.** Facts about pdp64 come from the repository, with paths. *Local* means read in `../kernel-src` (sparse trees: no `arch/*/crypto` directory exists in the Linux tree, and OpenBSD's `sys/crypto` is absent; what is there is `sys/arch/amd64/amd64/aesni.c`, `aes_intel.S`, `sys/arch/arm64/arm64/cryptox.c` and `cpu.c`, and Linux `Documentation/arch/riscv/hwprobe.rst` and `Documentation/devicetree/bindings/riscv/extensions.yaml`). Everything else outside the repository is marked *(from memory, not confirmed)*. No web page was fetched. Cycle counts, gate counts and instruction counts are **estimates** and are labelled as such.

**Reading the author's sentence "all instructions take the same length of time".** Read here as: the time of every instruction depends only on the instruction (opcode and length), never on its operand values or addresses. It is not read as "`ADD` takes as long as `DIV`": the mix of instructions a program executes is fixed by its control flow, which software keeps independent of secrets, so padding every instruction to the slowest would cost speed and remove no leak. If the author meant the literal reading, say so. *Confirmed by the author:* `ADD` and `DIV` need not take the same time as each other; each takes a time independent of its data.

## Summary of the instructions

| Mnemonic | Meaning | Bytes | Stage |
|---|---|---|---|
| `MASKEQZ ra, rc, rd` | `rd ← 0` if `rc = 0`, else `ra`; no flags | 4 (`AESC` `0x21`) | 1 |
| `MASKNEZ ra, rc, rd` | `rd ← 0` if `rc ≠ 0`, else `ra`; no flags | 4 (`AESC` `0x22`) | 1 |
| `BSEL rm, ra, rb, rd` | bitwise select: `rd ← (rm & ra) \| (~rm & rb)` | 4 (`BESC` `0x33`) | 1 |
| `AESES`, `AESESM ra, rb, rd` | AES encryption half-round on a 128-bit state held in `ra`:`rb`: ShiftRows and SubBytes (the `M` form adds MixColumns); writes the low 64 bits of the new state | 4 (`BESC` `0x50`, `0x51`) | 1 |
| `AESDS`, `AESDSM ra, rb, rd` | the decryption half-round (inverse ShiftRows, inverse SubBytes; `M` adds inverse MixColumns) | 4 (`0x52`, `0x53`) | 1 |
| `AESKS1 rs, #n, rd` | key expansion step 1: SubWord of the rotated top word of `rs`, xor round constant `n` | 4 (`0x54`) | 1 |
| `AESKS2 ra, rb, rd` | key expansion step 2: the two xor-chained words | 4 (`0x55`) | 1 |
| `AESIM rs, rd` | InvMixColumns of a round-key half, for the decryption key schedule | 4 (`0x56`) | 1 |
| `SHA256SIG0`, `SIG1`, `SUM0`, `SUM1 rs, rd` | the four SHA-256 rotate-xor functions on a 32-bit word | 4 (`0x60`-`0x63`) | 1 |
| `SHA512SIG0`, `SIG1`, `SUM0`, `SUM1 rs, rd` | the four SHA-512 functions on a 64-bit word | 4 (`0x68`-`0x6B`) | 1 |
| `MSHA256`, `MSHA512 Rd, Rs, Rn` | hash `Rn` bytes (whole blocks) at `(Rs)` into the state at `(Rd)`; interruptible, restartable | 4 (`MBLK` `0x20`, `0x21`) | 2 |
| `MAESCTR Rd, Rs, Rn, Rp` | AES counter-mode over `Rn` bytes, parameter block at `(Rp)` | 4 (`MBLK` `0x22`) | 2 |
| `MKECCAK Rd` | Keccak-f[1600] on the 200-byte state at `(Rd)` | 4 (`MBLK` `0x23`) | 2, if wanted |
| `CSEL cc, ra, rb, rd` | select by condition flags | 4 (`AESC` `0x23`) | not recommended now |
| `BREV8`, `XORROR32` | bit reverse within bytes; xor then 32-bit rotate | 4 | not recommended |

Allocation: the sub-opcodes above were checked against `docs/pdp64-isa.md` section 4.17 and `spec/pdp64-mnemonics.hbnf` (`AESC` uses 0-4, `0x08`, `0x10`-`0x13`, `0x20`; `BESC` uses `0x00`-`0x08`, `0x10`-`0x12`, `0x20`-`0x23`, `0x30`-`0x32`, `0x40`-`0x42`; `MBLK` uses 0-6) and are free. The numbers are a proposal; the grammar is the authority. No top-level opcode is used, so the page-1 map of section 4.16 is unchanged.

## 1. The secure core class

**What it is.** A *core class* (a statement, readable in the per-core identification register of manual 7.8.4, of what kind of core this is) named *secure*. A secure core has the same instruction set as every other core. What differs is a set of promises about time, memory and isolation, listed below. It is a fourth dedicated core beside graphics, network and audio (errata 76), scheduled by affinity.

**The promise.** For a core of the secure class, the number of cycles an instruction takes, and the number of cycles any other core can observe it perturb, is a function of the opcode, the length field and (for block instructions) the count register, and of nothing else: not operand values, not addresses, not the state of any cache or predictor, not what other cores are doing. Software remains responsible for the other half: it must not branch on a secret, index with a secret, or take a secret-dependent count. The hardware promise removes the leaks software cannot remove.

### 1.1 Fixed latency, group by group

| Group | Normally data-dependent because | Rule on the secure class |
|---|---|---|
| `ADD`, `SUB`, logic, `MOV`, `LEA`, `SET`, `MIN`, `MAX`, `ABS`, `BSWAP`, `BITREV`, `CLZ`, `CTZ`, `POPCNT`, `CLMULL`, `CLMULH`, `MASKEQZ`, `BSEL` | nothing (fixed-depth logic) | one latency each, published |
| `MUL`, `MULH`, `MULHU` | early-out on small operands (BearSSL: ARM9 and the 80486 have it, `hardware-vulnerabilities.md:142`) | no early exit; one latency for all operands. A fixed multiplier needs fewer gates than an early-out one, so this holds on every core |
| `DIV`, `DIVU`, `MOD`, `MODU` | the sequencer stops when the quotient is exhausted | always runs the full iteration count; latency is the worst case. Cost is nothing measurable: divide is 0.04% of compiled instructions (149 of 370,115) |
| `SHL`, `SHR`, `SAR`, `ROR` by register count | an iterative shifter takes count cycles | barrel shifter, or fixed latency |
| `FADD`, `FMUL`, `FMADD` and `binary32`/`binary16` forms | subnormal operands take a slow path | no assists, no microcode: subnormals at the normal latency |
| `FDIV`, `FSQRT`, conversions | iterative | worst-case latency always |
| `MCPY`, `MMOV`, `MSET` | length (inevitable) | time is a function of `Rn` only; the length must not be secret |
| `MCMP`, `MSCN`, `MSCNN`, `MVAL` | early exit at the first difference, match or error | no early exit: the whole `Rn` is always scanned. The architectural result is unchanged (flags and pointers still show the first difference or match); only the time is. `MCMP` then is a `timingsafe_bcmp` in one instruction |
| conditional branches | taken costs a bubble, not-taken does not | both outcomes cost the taken latency; no predictor exists, so there is no misprediction |
| loads, stores | cache hit or miss, TLB miss, page walk, bank conflict | section 1.2 |
| atomics (`CAS`, `LL`/`SC`, fetch-and-op) | coherence state, contention | only inside the private window (below); outside it they abort. Inside it no other initiator exists, so the latency is that of a load plus store |
| aborts (page fault, alignment, divide by zero) | a handler runs | not part of the promise: a fault caused by a secret is a leak whatever the hardware does. The secure class has no demand paging (section 1.3), so a fault is a bug and kills the secure process |
| interrupts | arrival time is external | section 1.5 |
| the crypto set (section 3) | a table S-box in a cache would leak | fixed latency by construction (section 3.3) |

The latency of each group, in cycles, is a property of one implementation (read from the feature registers, `C13`), not of the architecture. The architecture promises constancy, not a number.

### 1.2 Memory: scratchpad or constant-time cache

The author's wording is "all cache fetches take same length of time" and "all cache lines private". There are two ways to deliver the first, and they are not equal.

**Option A: a private cache whose every access takes the worst-case time.** A hit that is slowed to the miss time leaks nothing, but it is then not a cache: the core runs at memory speed (roughly a hundred cycles per access, an estimate) and the line fill still crosses the shared bus, where it meets other cores (section 1.6). It also needs the lines to be flushed at every domain switch. It is correct and useless.

**Option B: a tightly coupled memory (TCM, a block of on-chip SRAM wired to the core with a fixed access time and no tags).** There is no hit or miss: every access to it takes the same time, for every address and every data value, by construction. No line is shared because there are no lines; nothing in it is visible on the bus, so no snoop, no coherence traffic, no prefetcher and no replacement state exist to leak. The price is size (an implementation figure; 64 KiB to 256 KiB is plausible, an estimate) and that software moves data in and out explicitly.

**Recommendation: B, as the architecture's promise.** Concretely:

- The secure core has a **private window**: a contiguous range of the address space backed by the TCM, mapped by a direct-mapping window (ISA section 8.3), so translation is an add and a bounds check, with no TLB state. Its size is in the class register.
- Secret-bearing data (keys, round keys, state, intermediate values, tables a secret indexes) lives in the window. Loads and stores to the window take one fixed latency, any address.
- Loads and stores outside the window are not supported on the secure class; they abort with a new cause (`ECAUSE = SECWIN`). Data crosses the boundary only with `MBLK` (`MCPY`, `MMOV`), whose time is a function of the count and a published per-block constant (section 1.6). A hash input or ciphertext buffer is copied in, processed, copied out.
- Instruction fetch comes from the window or from a private instruction memory of fixed latency. Code is public by assumption, so a miss in a private instruction cache would leak only the control flow, which software keeps secret-independent; it may be a real cache if the author prefers, with the interrupt and flush rules of section 1.5. The simplest conformant design fetches from the window.
- Option A is kept as a permitted implementation of the same promise for a larger window, never as the recommendation.

The cost of B is that a secure core is a crypto engine, not a general-purpose core: a process that wants 100 MB of secret-indexed working set does not fit. That is acceptable because the use is keys and cipher state, which is kilobytes.

### 1.3 Translation and page walks

On the secure class: the TLB is small, fully associative, tagged by ASID, and **locked**: entries are loaded by the kernel at setup and not replaced. A miss is an abort (`ECAUSE = SECTLB`), never a hardware walk. So there is no walk time, no walker cache footprint (AnC, `hardware-vulnerabilities.md:83`) and no replacement state. The direct-mapping window of section 1.2 needs no TLB at all. There is no demand paging, no copy-on-write, and no `TLBI` broadcast latency inside the promise.

### 1.4 DIT, SMT, speculation, power

- `PSW.DIT` reads as 1 and cannot be cleared on the secure class (the bit is the ordinary one of manual 9.3.7; here it is constant). Because section 1.1 makes every instruction fixed-latency anyway, `DIT` has nothing left to gate; the bit exists so that the same code runs on other cores with the same meaning.
- No SMT. In order. No speculation, no predictors, no prefetcher (rules C1 to C6, C8 hold by absence).
- Frequency and voltage are fixed while the core runs a secure process (rule C10, Hertzbleed, `hardware-vulnerabilities.md:243,298`): the core's clock does not scale with load or temperature; the platform may gate it entirely (idle) but not modulate it.
- The reading of `RDTIME` is allowed and exact; the core's own process may time itself. A timer is a danger only to a victim, and the victim's observers are on other cores (section 1.6).
- Power analysis and electromagnetic emission are not timing channels and are out of the promise (section 5).

### 1.5 Interrupts and the kernel's duties

The secure core takes no periodic timer tick: if an instruction can take the same time whatever its operands without one, nothing needs introducing (the author's rule: no timing interrupts, ticks or hertz where they are not required). It is stopped or preempted by an inter-processor interrupt from a general core (the doorbell and the stop-and-drain register of manual 7.8.4), and any other interrupt it takes. The rules below bind the handler of every such interrupt:

1. **The interrupt handler touches no secure state.** It reads and writes no address in the private window other than its own stack and per-core structure, which sit in a reserved part of the window. It does not read the interrupted process's registers or memory except to save them to that stack.
2. **Its duration does not depend on secure state.** It runs with the same fixed-latency instructions and no secret-dependent branch, so each interrupt adds the same number of cycles. The total time of a computation is then its fixed work plus a fixed cost per interrupt taken; the arrival of an interrupt is chosen by another core, so it carries no secret.
3. **No scheduling decision uses secure state.** The secure core runs one secure domain at a time; the interrupt's job is accounting and preemption, not choosing among secret-dependent alternatives. A runaway computation is stopped by the doorbell, not by a tick.
4. **A domain switch zeroizes.** Before another domain runs, hardware clears the window (a class-control write starts a clear engine that runs at the TCM's width per cycle, so a 256 KiB window at 64 bytes per cycle takes 4096 cycles, an estimate) and the kernel clears the sixteen registers. Nothing of the previous domain's keys survives in a register or in SRAM.
5. **Interrupt latency** is bounded and public: an interrupt is taken at the next instruction boundary, or at the next block boundary of an `MBLK`. The worst case is the longest fixed latency (a divide) or the block time, both published (ISA section 12 item 5 asks for exactly this figure). The moment of arrival is external and carries no secret.

### 1.6 Contention on shared structures

A secret leaks if its owner's timing depends on what other cores do, or the other cores' timing depends on the owner's secrets. The shared structures are the bus, the shared second-level cache and the DRAM controller.

- **Inside the window there is no sharing**: the TCM is not on the bus.
- **At the boundary** (`MBLK` between window and main memory) the transfer takes a time that is a function of `Rn` and a published constant per block. To make that true when other cores are saturating the bus, the interconnect gives the secure core a **reserved slot** (time-division multiplexing: a fixed slot per period, unused slots idle or returned to others without delaying the owner's next slot) whose length covers the worst DRAM case, row conflict and refresh included. This is a property of the interconnect, written in the bus document (`pdp64-q64-bus.md`); the processor promise cannot be kept without it.
- The secure core's data never enters a shared L2: the window is not cacheable by others and the secure core's `MBLK` transfers bypass L2 allocation.
- **DMA**: no device may address the TCM (it has no bus address). If an implementation backs the window with DRAM instead, the IOMMU domain of the window must deny every initiator and the memory controller must exclude it from scrubbing reads of others.

### 1.7 Class register, selection and keys

**Fields of the class register** (read-only, manual 7.8.4; numbering to be chosen): `CLASS` (general, graphics, network, audio, secure); `INORDER`; `SPEC` (speculates: 0 on secure); `PRIVATE` (no cache line is shared with another core); `FIXLAT` (the section 1.1 promise holds with `DIT` forced); `WINDOW` size in KiB; feature bits `AES`, `SHA256`, `SHA512`, `SELECT`, and for stage 2 `MBLKCRYPTO`, `KECCAK`; and a second read-only block with the latency in cycles of each group (`ALU`, `MUL`, `DIV`, `LOAD`, `BRANCH`, `AES`, `SHA`, `MBLKBLOCK`).

**How firmware selects the class.** In iteration one the class of a core is fixed by what was built (a small in-order core of the same ISA, `security-round2.md` section 2: switching a large out-of-order core into a faithful in-order mode is a second design to verify). For an implementation whose cores can be configured, the per-core configuration register in the interrupt and start controller is writable only while the core is held in reset (manual 7.8.1), and locks when the start register is written. The controller compares the request with the core's capability field and refuses to start on a mismatch, with a status bit the firmware reads: a wrong configuration is detected, not run. The class never changes while the core runs; changing it is stop-and-drain (7.8.4), reset, zeroize, reconfigure.

**Keys: lifetime and zeroization.** Keys enter the window from the process that owns them, over the kernel's key-store path or by derivation inside the window, and never cross a bus afterwards. They are cleared (a) by hardware at every domain switch, reset, `HALT`, stop-and-drain and machine check; (b) by software with `MSET` of zero over the key area, which unlike a C `memset` cannot be removed by an optimizer. Linux has `Documentation/crypto/libcrypto-zeroization.rst` locally (unread); the issue it names, compilers dropping dead stores to keys, does not arise for `MSET` *(from the file name, not confirmed)*.

### 1.8 What is architecture and what is implementation

| Architecture (promise, testable by the conformance suite of section 5) | One implementation (may differ) |
|---|---|
| each instruction's latency is independent of operand values and addresses (class register `FIXLAT`) | the number of cycles |
| load/store latency in the window is independent of address | the TCM size and technology |
| `MCMP`, `MSCN`, `MSCNN`, `MVAL` scan all `Rn` bytes; block time depends on `Rn` only | the block size and per-block cycles |
| accesses outside the window abort; atomics outside abort | whether the window is SRAM or locked DRAM |
| `DIT` reads 1; no speculation, no SMT, no data-dependent prefetch | the pipeline; whether there is a private instruction cache |
| window cleared on domain switch, reset, halt, machine check | the clear engine's width and speed |
| TLB locked, miss aborts | its size |
| completion time of window-memory `MBLK` independent of other cores | the slot period |

### 1.9 Protections that cost nothing on the other cores, and those that do not

The author's rule: any of these that can run on the other cores without a performance penalty, should. Applied to `retire-stage-candidates.md` (items as approved by the author: 1, 2, 4, 5, 8, 13, 14, 15, 16, 17) and to `hardware-vulnerabilities.md`:

| Item | Everywhere | Secure only | Reason |
|---|---|---|---|
| 5 Landing pads, page-gated | yes | | one comparison in the branch unit; no speed cost |
| 8 `SYS` only from marked pages | yes | | a page-table bit checked at retire |
| 13 Predictor isolation by ASID, one flush instruction | yes | (absent) | a few bits per predictor entry (the file's own estimate); the secure core has no predictor |
| 13 Cache-way masks per ASID | yes (the author: "smp is immediate, so don't defer") | | one register per domain |
| 1, 2 Granule colouring and reserved colours | yes | | checked at retire; hits and misses unchanged |
| 4 Stack limit register | yes | | one comparator |
| 15 Precise ECC and parity reporting | yes | | RAS path only |
| 16 Precise watchpoints at retire | yes | | |
| 17 The restart contract | yes | | a property of the design, not of silicon |
| 14 Residue check of ALU results at retire | optional on others | **yes** | glitch and fault attacks on a cipher (differential fault analysis on AES) make it worth its gates here; on other cores it is an area cost, so it is their implementer's choice |
| Fixed-latency multiplier | yes | | smaller than an early-out one (P17 text) |
| `DIT` bit in `PSW` | yes (gates fast paths of divide and block scans, off the hot path) | constant 1 | one bit, saved with the `PSW` |
| Crypto set and select with a fixed-latency promise (rule C7) | yes | | section 4 |
| Data-dependent prefetch or value prediction off while `DIT` | yes | absent | rule C8 |
| Timer granularity (C14) | yes | exact | |
| No early forwarding, no shared microarchitectural buffers (C1, C5) | yes | | already so in order; required of an out-of-order core |
| Private TCM window, locked TLB, reserved bus slot, hardware clear, fixed frequency, forced `DIT`, no demand paging | | **yes** | each costs performance, area or flexibility |
| 12 Retire-gated visibility ("strict" domain) | a per-domain bit on out-of-order cores | constant (nothing speculates) | the author leans toward it; costs only to domains that ask |

**Impact.** *Kernel:* one affinity rule and a domain-switch routine; the interrupt handler obeys five rules; no periodic tick. *Compiler:* nothing; secure code is written with intrinsics and checked by the harness. *Hardware:* the secure core is a small in-order core plus an SRAM block, a clear engine and a bus slot; no new mechanism on the other cores beyond a bit and some comparators.

**Your annotations:**

if we can make an instruction run in equal time regardless of its args, without tics, then we should. if we don't have to introduce timing interrupts, ticks, or hertz, then we shouldn't.
i like your design. approved.


&nbsp;

## 2. The select instruction

**Existing state.** `SET cc, rd` (`AESC` `0x20`) turns a condition into 0 or 1. A conditional select is on hold in `pdp64-isa.md` section 12 item 15 and section 15.3, and `hardware-vulnerabilities.md:111,115` writes as if `MASKEQZ` existed. `FESC` `0x20`-`0x24` are floating-point sign and selection operations, not integer selects. No instruction duplicates what follows.

**Choice: `MASKEQZ` and `MASKNEZ`, three registers, in `AESC`.**

```
MASKEQZ ra, rc, rd     ; rd <- (rc == 0) ? 0 : ra       AESC 0x21
MASKNEZ ra, rc, rd     ; rd <- (rc != 0) ? 0 : ra       AESC 0x22
```

`rc` is tested whole (all 64 bits), so any nonzero value is true; no flags are read or written. Fields: `reg` = `rd`, `low` = `ra`, parcel 1 `t` = `rc`; four bytes. `rd` may equal `ra` or `rc`. Semantics are those of LoongArch `maskeqz`/`masknez` and RISC-V Zicond `czero.eqz`/`czero.nez` *(from memory, not confirmed; Linux's `extensions.yaml` lists Zicond as "conditional arithmetic and conditional-select/move operations", local)*. Latency fixed, one cycle; in the published constant-time set.

**Why this form and not a flag-reading `CSEL`, per the priorities.**

- *Priority 1:* it reads no flag, so there is no flag dependence to analyze, and the secret condition is an ordinary register operand. No new hidden state.
- *Priority 2:* a select costs three instructions (`MASKEQZ`, `MASKNEZ`, `BIS`) against `CMP` plus `CSEL` (two) when the condition comes from a compare. The difference is two instructions only at sites that select on a comparison, 783 `cmov` in 284,641 instructions (0.28%, ISA section 14.4). The case for the pair is the constant-time idiom, where the condition is already a register (a bit, a borrow, a mask).
- *Priority 3:* both are rare, so four bytes is right. A two-byte form would need the spare ALU slot `0x23` and would write flags; not worth the last spare slot for a crypto-only instruction.
- *Priority 4:* two AND-gates per bit and a 64-input zero detect. About 100 LUTs (estimate).
- *Occam:* the author confirmed the pair; `CSEL` is a third entity. It is reserved (`AESC` `0x23`) and recommended only if the compiler work shows selects on comparisons matter more than the 0.28%.

**Sequences** (assembler: source first, destination last; `BIS` is OR, `BIC` is and-not).

Constant-time select, `d = c ? a : b`: 3 instructions, 10 bytes.

```
MASKEQZ  a, c, t        ; t = c ? a : 0
MASKNEZ  b, c, d        ; d = c ? 0 : b
BIS      t, d           ; d = t | d
```

Constant-time compare, `d = (a == b)` or `(a < b)` unsigned, as 0 or 1: 2 instructions, 6 bytes. `CMP` takes the register first and `SET` reads the flags it wrote; both are fixed latency.

```
CMP  a, b ;  SET eq, d      ; d = (a == b)
CMP  a, b ;  SET lo, d      ; d = (a < b) unsigned (C is borrow)
```

Select on a compare, `d = (a < b) ? x : y`: 5 instructions (`CMP`, `SET lo,t`, `MASKEQZ x,t,u`, `MASKNEZ y,t,d`, `BIS u,d`).

Constant-time conditional swap of two registers on a boolean `c`: 5 instructions, 12 bytes, no temporary beyond `t`.

```
MOVQ  a, t ; XOR b, t       ; t = a ^ b
MASKEQZ t, c, t             ; t = c ? t : 0
XOR   t, a ; XOR t, b       ; a, b swapped when c
```

With `BSEL` (section 3.2) and a mask `m = 0 - c` computed once, the swap is two `BSEL` plus a move (or two with register renaming in an unrolled loop): the X25519 ladder swaps ten limbs per step, 50 instructions with the `MASKEQZ` form against about 25 with `BSEL`. This is the case for `BSEL`.

Constant-time buffer equality for secrets: `MCMP` on the secure class (or any core with `DIT` set) is one instruction; the portable loop is `MOVQ (R0)+,t; XOR (R1)+,t; BIS t,acc` per 8 bytes then `TST acc; SET ne`. OpenBSD's `timingsafe_bcmp` is the same loop (`sys/lib/libkern/timingsafe_bcmp.c`, local).

**Cost, one line each.** Opcode space: two `AESC` sub-opcodes of about 240 free. Flags: none. Compiler: the back end's select lowering stays branches until a `CSEL` or a pass exists; the intrinsics `__builtin_maskeqz` style are the only users in stage 1.

**Impact.** *Kernel:* a constant-time compare and select for MAC checks and key handling with no branch. *Compiler:* a back end must not turn the sequence back into a branch (a rule in `abi.md`: the optimizer treats `MASKEQZ` as opaque). *Hardware:* about 100 LUTs, one cycle.

**Your annotations:**

looks good.

&nbsp;

## 3. The cryptographic instructions

### 3.1 Precedent and what it teaches

- **RISC-V scalar cryptography** *(from memory, not confirmed; the extension names and bit positions are local in `hwprobe.rst`: ZBKB, ZKND, ZKNE, ZKNH, ZKSED, ZKSH, ZKT)*: `aes64es`, `aes64esm`, `aes64ds`, `aes64dsm` (a 128-bit state in two registers, one instruction per 64-bit half of the output), `aes64ks1i`, `aes64ks2`, `aes64im`; `sha256sig0/1`, `sha256sum0/1`, `sha512sig0/1`, `sha512sum0/1`; Zbkb (`pack`, `rev8`, `brev8`, `zip`), Zbkx (`xperm`); and **Zkt**, a published list of instructions guaranteed data-independent latency (the extensions.yaml entry: "data independent execution latency", local). The design goal was that **AES and SHA run on the general registers, with no vector unit**. That matches pdp64 exactly (errata 59: no vector register file).
- **x86** AES-NI (`AESENC` does a whole round on a 128-bit register), PCLMULQDQ, SHA-NI, VAES *(from memory)*. **ARM** `AESE`/`AESMC`, `SHA256H`, `PMULL`, and with SHA3 `EOR3`, `RAX1`, `XAR`, `BCAX` *(from memory; OpenBSD `arm64/cpu.c:913-939` prints the SHA3, SHA2 and SHA512 feature levels, local)*. All use vector registers.
- **s390 CPACF** *(from memory)*: `KM`, `KMC`, `KIMD`, `KLMD`, `KMAC` are long instructions: a function code selects the algorithm, a parameter block in memory holds key and chaining value, source and destination are address-and-length register pairs, the instruction processes what it can and sets condition code 3 for "re-execute". This is the `MBLK` design (progress in registers, `RTI` resumes, ISA section 7.5).
- **What OpenBSD gained.** `aesni.c` and `cryptox.c` (ARMv8, `aes_v8_*` routines) exist so libcrypto and IPsec use the CPU's AES instead of tables; OpenBSD removed PCI crypto cards (commit 0a828ff4, `security-proposals.md` section 2). Both drivers wrap their crypto in `fpu_kernel_enter()` / `fpu_kernel_exit()` (`cryptox.c:174-177,421-430`; `aesni.c:209-222`, local) because the instructions use vector registers whose user state must be saved. **Scalar-register crypto needs no such bracket**: on pdp64 a kernel AES loop saves nothing and is preemptible with the ordinary register save. This is a real saving over x86 and ARM and the reason RISC-V chose scalar.

### 3.2 The minimal set (stage 1), instruction by instruction

All stage-1 instructions are four bytes, one destination register, no flags written, a fixed latency, in `BESC` (register-to-register, destination in `reg`, sources in `low` and `t`, a third register or a 4-bit immediate in `x`). One destination keeps them out-of-order ready (no instruction writes two registers).

**AES state.** A 128-bit block is held in **any two registers** `ra` (bytes 0-7, columns 0 and 1) and `rb` (bytes 8-15, columns 2 and 3); no even/odd pairing is required, because the three-register format names them. A round on one block is two instructions, `AESESM ra, rb, t` (new low half) and `AESESM rb, ra, rb` (new high half), which leave the new state in `t`:`rb`; unrolled, the roles alternate, so there are no register moves. A block in flight costs **three registers** (two state, one temporary). The round key is xored in by `XOR` with a memory operand (`XOR 16(R5), t`), which is also one instruction.

| Instruction | Semantics | Priorities (1 2 3 4 5 6) | Score |
|---|---|---|---|
| `AESES`, `AESESM ra, rb, rd` | take the 16 bytes `rb:ra`, apply ShiftRows, SubBytes (and MixColumns for `M`), write the 8 bytes belonging to columns 0 and 1; swapped operands give columns 2 and 3 | + + 0 0 0 0 | adopt |
| `AESDS`, `AESDSM` | the inverses (equivalent inverse cipher) | + + 0 0 0 0 | adopt |
| `AESKS1 rs, #n, rd` | `rd ← (SubWord(RotWord(rs[63:32])) xor rcon(n)) replicated in both halves`; `n` in `x` (0-10; 10 means no round constant, for AES-256) | + + 0 0 0 0 | adopt |
| `AESKS2 ra, rb, rd` | `rd[31:0] ← ra[31:0] xor rb[63:32]`; `rd[63:32] ← ra[63:32] xor rd[31:0]` | + + 0 0 0 0 | adopt |
| `AESIM rs, rd` | InvMixColumns of two columns (a round-key half) | + 0 0 0 0 0 | adopt |
| `SHA256SIG0/1 rs, rd` | σ0, σ1 of the low 32 bits of `rs`: `ror7 xor ror18 xor shr3`; `ror17 xor ror19 xor shr10`; result in the low 32 bits, upper bits zero | + + 0 0 0 0 | adopt |
| `SHA256SUM0/1 rs, rd` | Σ0, Σ1: `ror2 xor ror13 xor ror22`; `ror6 xor ror11 xor ror25` | + + 0 0 0 0 | adopt |
| `SHA512SIG0/1`, `SUM0/1 rs, rd` | the four 64-bit functions (σ0 `ror1 xor ror8 xor shr7`; σ1 `ror19 xor ror61 xor shr6`; Σ0 `ror28 xor ror34 xor ror39`; Σ1 `ror14 xor ror18 xor ror41`) | + + 0 0 0 0 | adopt |
| `BSEL rm, ra, rb, rd` | `rd ← (rm & ra) \| (~rm & rb)`, bitwise: `Ch(e,f,g)` is `BSEL e, f, g`; `Maj(a,b,c)` is `BSEL (a^b), c, b`; a masked blend; a mask-controlled swap | + + 0 0 + 0 | adopt |

Notes on each, because the author will annotate:

- The constants above are the FIPS 180-4 and FIPS 197 definitions and must be checked against the standard before the specification is written; the RISC-V instruction semantics, the S-box and rcon are *(from memory, not confirmed)*.
- `AESKS1`/`AESKS2` keep the key schedule at three instructions per round for AES-128 (about 30 for the whole schedule, 18 more `AESIM` for decryption), once per key.
- `BSEL` is three-source plus destination, so it needs the four register fields that `BESC` parcel 1 provides (`t` and `x`), as `FESC` does for fused multiply-add. It is bit-select (ARM `BSL`, x86 ternary-logic) and is used beyond crypto: MD5 and SHA-1 round functions, blending, bit insertion. If the author wants fewer entities than the minimum, `BSEL` is the one to drop: SHA-256 gets 2x without it (below) and the swap costs 5 instead of 2.
- **The S-box is not a table in memory.** See section 3.3.

**Counts: the software sequence with today's instructions against the new ones** (all estimates; "software" is the best constant-time sequence: bitsliced for AES, shifts and xors for SHA).

| Operation (per block) | Existing instructions only | Stage 1 | Notes |
|---|---|---|---|
| AES-128 encrypt, 16 bytes | about 1,000 (bitsliced, from BearSSL `ct64` at 92 MB/s scaled to 3 GHz, IPC about 3; rough) | 42 (2 initial `XOR`, 9 rounds of 2 `AESESM` and 2 `XOR`, a final round of 2 `AESES` and 2 `XOR`) | about 20x to 25x fewer instructions |
| AES-128 decrypt | about 1,000 | 42, plus 18 `AESIM` once per key | |
| AES-128 key expansion | about 150 | about 30 | once per key |
| SHA-256, 64 bytes | about 2,500 (about 25 per round and 18 per schedule round) | about 1,200 (13 per round, 8 per schedule round, with `BSEL`); about 1,500 without `BSEL` | about 2x |
| SHA-512, 128 bytes | about 3,100 | about 1,500 | about 2x |
| GHASH, 16 bytes | about 40 with `CLMUL` (4 words bit-reflected: `BSWAP` of each input word, three `CLMUL` pairs, a one-bit shift, two-fold reduction); about 800 without | no change | `CLMUL` already present |
| ChaCha20, 64 bytes | about 1,000 to 1,500 (12 per quarter-round, 80 quarter-rounds, plus spills: 16 words of state, 13 usable registers) | no change | |
| Poly1305, 16 bytes | about 60 (radix 2^44, 9 products of `MUL`+`MULHU`, `ADD`+`ADC` to accumulate) | no change | |
| X25519 | about 400,000 (255 ladder steps, `MUL`/`MULHU`/`ADD`/`ADC`) | with `BSEL` swaps, about 6,000 fewer (25 per limb pair saved, ten limb swaps per step) | dominated by the multiplier |

The AES row is the one that matters: constant-time software AES is the case the author named, and the table is the reason. The SHA rows are modest: **the primitives remove half the work, not nineteen twentieths**, because a round still needs the adds and the register traffic. Stage 2 addresses that.

### 3.3 Why these are constant-time

An AES S-box is the inversion in GF(2^8) followed by an affine map. In hardware it is either (a) a read-only table inside the functional unit, or (b) a combinational circuit over the composite field GF((2^4)^2) (Canright, and the Boyar-Peralta circuits of about a hundred gates *(from memory, not confirmed)*). Both take a fixed time for every input: **the cache-timing problem of table AES is that the table lives in the memory hierarchy, where a hit and a miss differ; a table inside the unit has no such state**. The architecture does not say which; it says the latency is fixed and the unit has no data-dependent control. Eight S-boxes per `AESES` (two columns), the MixColumns xor network, and the inverse variants share the inversion; estimated at 1,000 to 1,500 LUTs for the whole AES group, or 3,000 gates (estimate, unmeasured). `SHA*` functions are rotations and three-input xors: about 130 LUTs for the four 32-bit functions and 260 for the four 64-bit ones (estimate), one cycle. `BSEL` and `MASK*`: bitwise logic.

### 3.4 Decisions the author asked for

**GCM: `CLMUL` or a dedicated `GHASH`.** `CLMUL` only. A GF(2^128) multiply takes two 128-bit inputs and writes one: six 64-bit register operands, which the scalar format cannot carry in one instruction without a two-destination write or a hidden accumulator. The existing pair makes a block about 40 instructions (estimate), 2.5 per byte, and deferring the reduction over four blocks (precomputed powers of the hash key) lowers it again. `BREV8` (bit reverse within bytes, Zbkb's `brev8`) would save two instructions per 16 bytes; not worth a sub-opcode (Occam).

**One round on a register pair, or a whole buffer?** Both, in order. The pair-round (stage 1) is small, algorithm-neutral (CBC, CTR, GCM, XTS, CCM and any odd mode are loops around it), usable by user code on any core and preemptible with ordinary state. The whole-buffer form (stage 2, `MBLK` `0x20`-`0x3F`, CPACF in spirit) is the better answer to priorities 1 and 2: one instruction per buffer, the mode (counter increment, chaining, SHA padding) is done in hardware and so cannot be got wrong, and it is restartable with progress in the registers like `MCPY`. It costs gates in proportion to the number of algorithms frozen into opcodes (an estimate: a SHA-256 compression unit about 2,000 LUTs and 1,000 flip-flops; an AES-CTR engine about 3,000 LUTs), and priority 4 prefers stage 1. The SHA row of the table shows the difference: whole-buffer SHA-256 at one round per cycle is about 64 cycles per 64 bytes against about 1,200 instructions (estimate), roughly 18x; AES gains less, about 4x (0.6 against 2.6 instructions per byte), because stage 1 is already good. **So: stage 1 now; stage 2 `MSHA256` first, then `MSHA512`, then `MAESCTR`, only after measurement** (`roadmap.md`, "What to measure first"). Stage 2 operands: `MSHA256 Rd, Rs, Rn` (state at `(Rd)`, data at `(Rs)`, `Rn` bytes, a multiple of 64; `Rs` and `Rn` advance as blocks complete; the caller does the padding, which is a few instructions); `MAESCTR Rd, Rs, Rn, Rp` with the fourth register (the `MBLK` flags nibble) pointing at a parameter block of round count, round keys and counter, as CPACF's register 1 does. On the secure class their time is a function of `Rn` only, by section 1.1.

**SHA-3 and Keccak.** Not in stage 1. The permutation has 25 lanes of 64 bits against 13 usable registers, so a software round spills (estimated 200 instructions per round, 4,800 per permutation, 35 per byte at the 136-byte rate); it is naturally constant-time (add-free, rotate and xor and and-not), so correctness needs no instruction, only speed does. ARM has it in vector form; RISC-V scalar does not. The right form here is the stage-2 `MKECCAK Rd`, a whole permutation on the 200-byte state in memory, 24 rounds in about 24 to 30 cycles (estimate), roughly 150x. Wanted when ML-KEM or ML-DSA are *(from memory)* hash-bound; not before. Reserve `MBLK` `0x23`.

**ChaCha20.** Existing instructions suffice: `ADD`, `XOR` and `RORI32` (the rotate is already there for exactly this, ISA section 4.5.1, and sign-extends its result, which is harmless because the next add and xor use the low 32 bits). A quarter-round is 12 instructions. A fused `XORROR32 rd, ra, rb, #n` (xor, then rotate) would cut it to 8 and the count to 20 or so, 33%; it needs a 5-bit immediate beside three registers, so a 6-byte form. The cost is spills, not the rotate, and ChaCha20 is already faster than constant-time AES in software (`hardware-vulnerabilities.md:141`). **Not recommended.**

**Poly1305 and X25519.** What exists: `MUL` (low 64 bits), `MULH`/`MULHU` (high 64 bits), `ADD` setting `C`, and `ADC`/`SBC` (`SOP` slots 6 and 7: `ADC rd` adds the carry into `rd`). A 64x64 to 128 product is `MUL` and `MULHU`; accumulating it into a 128-bit pair is `ADD lo` then `ADC hi`, four instructions per product. Nothing is missing. **Two checks the specification owes:** `MUL`, `MULH` and `MULHU` must write no flags (or at least not `C`), or an `ADD`/`ADC` pair cannot straddle a multiply; and on the secure class they must be fixed-latency (section 1.1), because an early-out multiplier on secret limbs is the classic leak. A fused multiply-accumulate-high (`rd ← high(ra*rb) + rc + C`) would save one instruction in four (x86's `MULX`/`ADCX` and ARM's `UMADDL` in spirit); it needs a fourth register and a second output, so no. A constant-time modular reduction helper: not warranted; the Mersenne-like primes of the two curves reduce with shifts and one multiply by 19, and Barrett or Montgomery reductions use `MULHU`.

**Recommended minimal set.** Stage 1: `MASKEQZ`, `MASKNEZ`, `BSEL`, the seven AES instructions and the eight SHA instructions: 18 sub-opcodes, 72 bytes of encoding, no top-level opcode, about 1,500 to 2,000 LUTs (estimate). Without `BSEL`: 17. Stage 2, by measurement: `MSHA256`, `MSHA512`, `MAESCTR`, `MKECCAK`.

**Impact.** *Kernel:* AES for disk and IPsec and SHA for the random generator without the vector-state save of `fpu_kernel_enter`; ChaCha20 stays software. *Compiler:* intrinsics only; the register allocator is not involved (the AES blocks are written in assembly or intrinsics with explicit register naming; three registers per block in flight; two blocks interleaved to cover the latency use six, leaving seven). *Hardware:* a few thousand LUTs; the S-box and the S-box inverse are the largest part.

**Your annotations:**


did we carefully examine how the opcode layout is impacted if we had 32 registers instead of 16? would it spill a bunch of the single parcel instructions?
what impact if we do 128 bit registers instead of 64 bit?


&nbsp;

## 4. What the other cores get

The instruction set is one: every core, secure or not, executes every instruction in the summary table. The secure class adds only the timing promise and the private window (section 1).

**Does the crypto set need the fixed-latency promise on the general cores?** Yes. RISC-V does the same: Zkt names the Zk instructions as data-independent on every core that claims Zkt. The reasons here: (1) it costs nothing: AES, SHA, `MASK*` and `BSEL` are combinational with no data-dependent control, and a fixed-latency multiplier is smaller than an early-out one; (2) a user program on a general core that uses `AESES` for its own key expects it not to leak; (3) the published list (rule C7) is useful to every program and to the compiler, which must not reorder or replace instructions in the list. The list on every core: `ADD`, `SUB`, logic, shifts and rotates, `MUL`, `MULH`, `MULHU`, `CLMUL`, `POPCNT`, `CLZ` family, `BSWAP`, `BITREV`, `SET`, `MIN`, `MAX`, `ABS`, `MASKEQZ`, `MASKNEZ`, `BSEL`, the AES and SHA instructions. What the list leaves to `DIT` (and to the secure class): `DIV`, `MOD`, floating point, `MCMP`, `MSCN`, `MSCNN`, `MVAL`, stage-2 block crypto.

**Out-of-order cores.** The promise is on instruction latency from issue, not on the time between dispatch and retire: a larger core may overlap instructions, and the guarantee is that no data-dependent stall or replay is added. Rule 10 of `architecture-recommendations.md` already requires an out-of-order core to honour `DIT`. Loads on a general core stay as cached as before: the promise for loads is only on the secure class.

**What a general core does when software needs more than the list.** It sets `DIT`; for secrets in tables it uses the secure core by affinity; a program with secrets and no secure core available uses the instructions above (AES and SHA need no table) and `MASKEQZ`/`BSEL` for control.

**Impact.** *Kernel:* one set of crypto routines for all cores, plus a faster path where the secure core exists. *Compiler:* the same intrinsics. *Hardware:* no extra gates on the general cores for the promise.

**Your annotations:**

&nbsp;

## 5. Conformance

**What a suite tests, and where it runs.**

1. **Function** (sim64, QEMU, RTL): known-answer tests for every new instruction (FIPS 197 AES vectors, FIPS 180 SHA vectors, the NIST test vectors for modes, RFC test vectors for ChaCha20-Poly1305, GCM and X25519), round-trip encrypt/decrypt over random keys, `MASKEQZ`/`MASKNEZ`/`BSEL` truth tables with boundary operands, every `AESKS1` round number. Runs on the reference emulator now; this is the part `sim64` can do today. `sim64` has no cycle model (`sim64.md`).
2. **Timing** (RTL simulation and FPGA; a cycle-accurate model in `sim64` for the harness itself, option to be added): a program run on the secure core, in kernel mode with a doorbell interrupt injected at random times, that for every instruction I in the constant-time set and every operand class pair measures the cycles of a chain of 100 repetitions, bracketed by `RDTIME` and `ISYNC`, repeated 10,000 times.
   - *Operand classes:* zero, one, all ones, the most negative number, powers of two, every leading-zero count 0 to 63, every shift count 0 to 64 and above, random, subnormal and special floating-point values; for `AESES` and `SHA*`, random against fixed inputs; for `MBLK`, buffers equal at the first byte, at the last, never; `MCMP`/`MSCN` with the difference at each position.
   - *Memory:* every address of the window, strided, repeated, and with the cache or lines of the other cores warm and cold; the TLB hit and miss cases abort rather than vary.
   - *Pass criterion:* **exact equality**. The core is deterministic, so the minimum and maximum of the deltas must be equal; with interrupts injected, the deltas take only the values `C` and `C + H`, where `H` is the published handler length, and the count of `C + H` equals the number of interrupts injected. A statistical test is unnecessary (and weaker); where a part is not cycle-exact (a general core's loads), a fixed-versus-random Welch t-test in the style of dudect *(from memory, not confirmed)* over a whole routine is the fallback.
3. **Interference**: the same program while the other cores run a bus saturator, a cache thrasher, a DRAM row-conflict generator and an inter-processor-interrupt storm. Pass: the secure core's deltas are unchanged, bit for bit.
4. **Structural check on the RTL** (formal or by simulation with data tainting): no operand-data signal is in the fan-in of any control signal (stall, valid, early-out, counter load, mux select) of a unit in the constant-time set. This catches a leak the timing test would miss for an operand pair it did not try. It is the method that makes "constant by construction" checkable.
5. **Isolation**: after a domain switch the window reads zero, the registers are zero; a device write to the window address range faults at the IOMMU or does not reach it; accesses outside the window abort with `SECWIN`.

**What a test cannot show.**

- The absence of a channel nobody listed: a test proves the listed instructions and listed resources are constant, not that no other shared resource exists. The structural check and the architecture's short list of shared structures (section 1.6) are the defence.
- Power, electromagnetic emission, acoustic and fault-injection attacks. Not timing channels. The residue check (candidate 14) helps against faults; nothing in this document stops power analysis.
- Effects below the cycle counter's resolution (a data-dependent half-cycle in an asynchronous or multi-clock design) and effects that appear only at one temperature or voltage; Hertzbleed is covered only by fixing the frequency, which is a configuration the test can read but not prove.
- A software leak: a secret branch or secret index in a program on a conforming core. The hardware passes and the program leaks. A tool that checks programs (a taint analysis of the assembly) is a separate piece of work.
- Implementation-only properties (section 1.8, right column) are not tested for a number, only for constancy.

**Impact.** *Kernel:* a boot self-test of the secure core compares measured and published latencies and refuses to schedule on a mismatch (detection, priority 1). *Compiler:* none. *Hardware:* a cycle counter readable in the window and the structural check in the verification plan.

**Your annotations:**

&nbsp;
