# A complete instruction encoding for pdp64, 16 and 32 registers: designed, round-tripped, measured

[← pdp64 index](../README.md)

For the author's annotation. Follows [`layout-size-variants.md`](layout-size-variants.md).

The scripts, form tables, logs and results are in [`codegen-data/encoding/`](codegen-data/encoding/) (script names below are relative to it). The scripts read the compiled corpus and the executed profile from the measurement work directories (the 16- and 32-register assembly of the 841 files, and the six-program `sim64` profile); their paths are absolute and must be adjusted to rerun them.

**Update (2026-11-04):** sections 0-11 are the study on the old compiler's output, and pdp64/32 as measured in them reached too little with `cbCC`. Section 12 repeats it on the output of the new compiler (`pcc-enc`) and gives the grammars now in `spec/`: pdp64/16 944,600 and pdp64/32 976,000 bytes on the corpus, `cbCC` substitutions 328 -> 4 and 866 -> 17, pdp64/32 still +3.3% in fetched bytes and in size against pdp64/16 (-5.9% instructions).

## 0. Answer in one page

* **Today's encoding is not near-optimal for 16 registers.** A prefix-coded redesign that keeps 16-bit little-endian parcels, natural alignment, one memory operand and the length known from parcel 0 gives **1,013,598 bytes against 1,083,870 (-6.48%)** on the 841-file 16-register corpus, and **2.822 bytes fetched per executed instruction against 3.129 (-9.8%)** on the six profiled programs. Both sized on the compile the scheme was built for, with a verified encode/decode round trip (338,616 hardware instructions, 0 mismatches, also at the byte level). The earlier "flat 6-bit opcode + escape" layout was the wrong comparison: it fixed the opcode width, which is what costs bytes.
* **32 registers (5-bit fields) also beat today's encoding on the 16-register code**, but lose to the 16-register variant of the same scheme: static **1,040,280 (-4.02% vs today's 16-register 1,083,870; +2.6% vs the new 16-register scheme)**; dynamic (estimate) **2.980 per instruction, +5.6% vs the new 16-register scheme**, or **2.879 (+2.0%)** if eight register-register mnemonics also get a 5-bit one-parcel form (A32r, round-trip verified). 32 registers execute about 4.9% fewer instructions; the bytes saved by fewer instructions do not repay the wider fields, neither in static size nor in fetch. Details and the ±50% caveat in section 6.
* **Optional fused pairs** (`movq r,r ; call`, `popm ; ret`, `pop r ; ret`, a double register move) take the 16-register static size to **979,192 (-9.66%)** and the 32-register to 1,007,172 (-7.08% vs today's 16-register); they need a decision from the author (section 9).
* **Exactness.** Exact: static sizes (each variant sized with real branch relaxation on its own corpus, with a decoder that returns the original instruction for every one of them), the 16-register dynamic figure for the schemes trained without the profile. Estimates: every 32-register dynamic figure (function-weighted estimator of `frag-dyn.md`, never run); the in-sample "dynamic-tuned" schemes B16/C16 (leave-one-out says they do **not** generalise, section 6.3).

## 1. Method (what was built)

`enc.py` is a generic framework. A **form** is `(parcels n, mnemonic list, operand specs)`; its **leaf prefix length** is `L = 16n - (operand bits + sub-opcode bits)`. Every bit of an instruction is prefix, sub-opcode or operand: **there are no pad or reserved bits anywhere**, so there is no encodable-but-illegal pattern inside a form (an unused sub-opcode or an unused register-table entry traps as illegal). A set of leaves is a prefix code iff Kraft's inequality holds (`sum 2^-L <= 1`; Kraft's sum is the fraction of the 65,536 first-parcel patterns used). `scheme.py` selects, per instruction, the shortest form that fits, relaxes branches and PC-relative reaches against real label distances (the machinery of `fit/` that reproduces today's 1,083,870 exactly: `cur.py` is that model and reproduces it here), packs the bits, and decodes.

`solve.py` chooses which optional forms to include: greedy by *bytes saved per unit of code space* over whole (form, mnemonic-class) leaves, with five exponents of the ratio tried (`alphas`), against a budget of 95% of code space (5% kept free). The optimiser is a heuristic: removing candidates sometimes improves the result (A32 without the 4-bit hot variants in two-parcel families is 0.8% smaller than A32 with them, section 7), so **differences under about 1% between variants are optimiser noise**.

Design rules, all enforced by the code:
* Prefix at the top of parcel 0 (1 to 16 bits), the mnemonic selector (binary-aligned groups) next, **register fields from bit 0 of parcel 0 upward** (last register operand at `p0[3:0]`, the one before at `p0[7:4]`; 5-bit fields at `[4:0]`, `[9:5]`), displacements and immediates in the remaining bits, widest field last (so in later parcels).
* **Length is a function of parcel 0 alone** (1, 2, 3 or 5 parcels). No second-parcel length dependence exists.
* Registers that are rarely used have no 1-parcel form with a full field: "hot" register tables (3-bit field = the 8 most used registers; in the 32-register variant a 4-bit field = the 16 most used) let a 1-parcel instruction carry a displacement; everything else falls to 2 parcels.
* Rare instructions share a few wide groups with a sub-opcode field in the later parcel (`R2`, `R3`, `R4`, `RRI`, `BFx/BFy`, `SYS0`, ...), at 2^-12 of the code space each or less.

Two reach policies for **unresolved external references** (calls and `lea sym` to symbols in other files; 20,413 + 12,807 = 33,220 references, 9.8% of all instructions):
* `max` (primary, the one the 1,083,870 baseline uses): the assembler does not know the distance, so it must use a form whose field reaches 32 bits of byte offset (a 3-parcel form, 6 bytes), as today.
* `near`: a linker that relaxes would use the shortest form; every external is sized as distance 0. Reported for both encodings (today's under `near`: 1,014,098), because a relaxing linker helps today's encoding by the same 69,772 bytes.

## 2. Entropy bound (`entropy.py`)

Symbol = (mnemonic, operand-kind tuple); registers by order-0 entropy per role (destination, source, base, index); numbers by bit-length class given the mnemonic plus uniform mantissa; external references as 32 bits.

| 16-register corpus, bits per instruction | |
|---|---|
| H(mnemonic, operand shape) (163 distinct) | 5.100 |
| registers | 3.672 |
| number class | 1.929 |
| number mantissa | 3.232 |
| external payload (`max`) | 3.290 |
| **total, externals free (`near`)** | **13.934 bits = 1.742 B/instr = 589,253 B** |
| **total, externals 32-bit (`max`)** | **17.224 bits = 2.153 B/instr = 728,397 B** |
| same model, each instruction rounded up to whole parcels | 1,057,626 B |

32-register corpus: 5.076 + 4.003 + 1.883 + 3.204 = 14.165 bits (591,170 B near, 730,318 B max, 1,058,252 B parcel-rounded).

What this says: (a) a bit-packed code would reach 728 KB; the scheme at 1,013,598 is 39% above that and **almost all of the gap is parcel granularity** (the average ideal length is 17.2 bits, so most instructions round to 16 or 32); (b) the order-0 parcel-rounded model (1,057,626) is **not a lower bound** for real schemes: the new encoding beats it by 4% because it uses correlations between fields (sp base implies an unsigned scaled displacement, the mnemonic implies the immediate range) that an independent-fields model ignores. So the room left inside the 16-bit-parcel constraint is unknown but is small compared with the 28% that only sub-parcel granularity could recover. 32 registers add 0.23 bit per instruction to the bound (+1.7% bits, but 1.3% fewer instructions: +0.3% bytes in an ideal code); the real cost is much larger (section 6).

## 3. The scheme

Full tables, one row per leaf (parcels, form, prefix length, prefix bits, mnemonics, bit positions of every field), generated from the objects that were tested:
* `tables-A16.md` (278 leaves, 215 forms), `tables-A32.md` (335 / 267), `tables-A32r.md`, `tables-B16.md`, `tables-C16.md`, `tables-C32.md`; family summaries `families-A16.md`, `families-A32.md`.

Variants (the names used throughout):

| name | registers | objective | fusion | what it is |
|---|---|---|---|---|
| **A16** | 16 (4-bit) | static bytes of the 16-register corpus only | none | the primary 16-register scheme (honest out of sample for the profile) |
| B16 | 16 | static + 3x profile weight | none | in-sample for the profile (section 6.3) |
| C16 | 16 | as B16 | `movcall`, `popmret`, `popret`, `mov2` | optional fused instructions |
| **A32** | 32 (5-bit; 4-bit/3-bit hot tables) | static, 32-register corpus | none | the primary 32-register scheme |
| A32r | 32 | as A32 + a 5-bit 1-parcel register-register form for 8 mnemonics | none | A32 tuned for crypto-style code |
| C32 | 32 | as A32 | the same four fusions | |

### 3.1 Structure of A16 (what the tables contain)

Code space (fraction of first-parcel patterns), 5.0% free, 3,277 patterns (3,283 in A32) trap as illegal instruction; assigned by length: 38,500 patterns are 1-parcel, 20,093 2-parcel, 3,650 3-parcel, 16 five-parcel (A32: 26,468 / 21,913 / 13,840 / 32). Largest families in A16 (rows marked `~` aggregate several generated families and are rounded; exact figures per family are in `enc/families-A16.md`, per leaf in `enc/tables-A16.md`):

| family | forms | (form, mnemonic) pairs | code space | layout of the form |
|---|---|---|---|---|
| register-register (24 mnemonics: 7 moves, 15 ALU incl. `bit`, `cmp`, `fcmp`) | 1 | 24 | 0.0938 | 4 or 5-bit prefix, `rs=p0[7:4]`, `rd=p0[3:0]` |
| compare-with-zero and branch, 1 parcel (`cbeq`, `cbne`; 6/5/4-bit parcel offset) | 3 | 6 | 0.1094 | prefix, `disp=p0[10:4]`, `r=p0[3:0]` |
| compare-with-immediate and branch, 2 parcels (several widths) | ~19 | ~60 | ~0.25 | `r=p0[3:0]`, `imm=p0[7:4]+p1[15:12]` (8-bit), `disp=p1[11:0]` etc. |
| `movq #imm,r`, `add/sub/and #imm`, shifts, 1 parcel | 8 | 21 | 0.11 | imm 3 to 7 bits at `p0[10:4]`, `r=p0[3:0]` |
| hot-register load/store with 1-3-bit scaled offset (3-bit register fields) | 6 | 18 | 0.07 | `d=p0[8:6]`, `base=p0[5:3]`, `r=p0[2:0]` |
| `sp`-relative 4/5/6-bit scaled offset, `lea sp` | 7 | 16 | 0.07 | `d=p0[8:4]`, `r=p0[3:0]` |
| short branch (6-9 bit parcel offset) | 7 | 21 | 0.04 | `disp=p0[5:0]..[8:0]` |
| 2-parcel base+displacement (signed/unsigned, scaled/unscaled, 4-22 bit) | ~40 | ~120 | 0.03 | `r=p0[3:0]`, `base=p1[15:12]`, `d=p1[11:0]` ... |
| 2-parcel scaled index | ~16 | ~50 | 0.01 | `r=p0[3:0]`, `base,idx,scale,d` in `p1` |
| 2-parcel PC-relative / absolute / immediate, `call`, `br` with 12-28 bit field | ~60 | ~160 | 0.02 | `field=p1[15:0]` (+ `p0[3:0]` for the widest) |
| rare groups `R2` (68 mnemonics), `R3` (52), `R4` (16), `RRI` (4), `BFx`, `BFy`, `SYS0` (36), `SYSR`, `SYSI` (8-bit `trap`/`trapl`/`spl`/`hint` merged), `MFSR`/`MTSR` (12-bit register number) | | | 0.03 | `r*` in `p0[7:0]` and `p1`, sub-opcode field `x` |
| 3-parcel fallbacks (28-bit displacement, 22-bit index, 32-bit PC/abs/imm, `call`/`br` 32-bit parcel offset, `push`/`pushm` 32-bit) | ~20 | ~250 | 0.04 | everything fits, every instruction has one |
| `MOVQL #imm64,rd` | 1 | 1 | 2^-12 | 5 parcels: `rd=p0[3:0]`, `imm=p1..p4` (10 bytes) |
| user-qualified `.u`, deferred `.d`/`.ud` loads, `.u` stores (base and index modes) | 6 | 63 | 0.01 | |

Free: 5.0% of first-parcel space unassigned, plus unused sub-opcodes in the rare groups (`R2` has 68 of 4,096, `R3` 52 of 256, `R4` exactly 16 of 16 — **no spare sub-opcode in `R4`**; widen it before adding a fused multiply-add or a fourth `BSEL` variant).

### 3.2 What is assigned where, for the instructions the author named

Every mnemonic/shape of the assembler probe set (`layouts/probe.json`, 234 words, 1,873 source lines) is encoded except 113 lines of 22 shapes, all meaningless combinations that today's encoder accepts and this one refuses (a result, not a loss): `clr/com/inc/dec/neg/tst/adc/sbc/asl/asr/jmp/call/pop/jmpi/calli #imm` (store to or jump through an immediate), `movq/movl/movw/movb r,#imm`, `lea #imm,r`, `sob r,#imm` (probe artefact) and `trapl r` (probe artefact; `TRAPL #n` is the 8-bit `SYSI`). `push #imm` is kept (meaningful, 2 or 3 parcels).

| item | encoding |
|---|---|
| 22 ATOM words | `R3` (3-register; `xadd`... `ll`, `sc`) and `R4` (`cas`, `casdb`): operand placement assumed three or four registers, the memory address in a register, because the author's own text says the placement is not yet fixed |
| 8 MESC words (`movub/uw/ul/uq`, `addm/subm/bicm/bism`) | in the ordinary memory families (load list and store list), so they get all modes and all widths, not the 8-bit disp of today |
| `TRAPL` | `SYSI`, 8-bit vector, 2 bytes (the `TRAP`/`TRAPL` split disappears) |
| `MASKEQZ`, `MASKNEZ`, `AES*`, `SHA*`, `MSHA*`, `MAESCTR`, `BSEL` | `R2`/`R3`/`R4`/`RRI` (`AESKS1 rs,#n,rd` is `RRI`) |
| `TRAPCC` | 14 mnemonics `trapcc.<cond>` in `SYS0`, 2 bytes, no operand (handler vector fixed by the architecture; if it needs a vector, `SYSI`) |
| `ADDV`/`SUBV`/`MULV` | `R2` (register-register only; no immediate or memory form) |
| `MOVQL #imm64` | 5 parcels (10 bytes): the 64-bit literal counted inside the instruction here, so the fetch rule is "length known from parcel 0" without a "trailing literal" exception |
| `.U`, deferred loads | base and index modes only; other modes need a base register (`lea`) |
| landing pad, SYS page bit | `lpad` in `SYS0`; six `syspgN` placeholders |

## 4. Prefix-free / decodable (`proof.py: decodability`, run in `final.py`)

* **No leaf prefix is a prefix of another**: 0 clashes among all 278 leaves of A16 (335 of A32), checked pairwise independently of the table fill.
* **Every one of the 65,536 first-parcel patterns decodes to at most one leaf with a definite length** (the 65,536-entry table is built with an assertion that no cell is written twice): A16 62,259 patterns assigned + 3,277 unassigned (illegal) = 65,536; A32 62,253 + 3,283.
* Each leaf's placement covers **all 16n bits exactly once** (assertion in `decodability`); there is no second-parcel pattern on which the length depends.
* Length function cost: the minimum cover of "length of parcel 0" after merging sibling prefixes is **129 product terms in A16 (29 for 1 parcel, 64 for 2, 35 for 3, 1 for 5)** and 151 in A32, instead of the 2 gates of today's `len` field. This is the price of the variable prefix.

## 5. Round-trip proof (`scheme.py: roundtrip`, `bytes_rt.py`, `proof.py`)

| check | A16 | A32 | A32r | C16 | C32 |
|---|---|---|---|---|---|
| assembly instructions in the corpus | 338,313 | 333,872 | 333,872 | 338,313 (321,102 after fusing) | 333,872 (316,904) |
| hardware instructions encoded then decoded | 338,616 | 334,487 | 334,564 | 321,102 | 316,904 |
| mismatches / illegal decodes / stream-length errors | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| shapes that could not be encoded | none | none | none | none | none |
| `cbCC` that no single form reaches (assembled as `cmp` + `bCC`) | 303 sites | 615 | | | |
| generated boundary tests (min, max, 0, +-1 of every field of every form and mnemonic, plus 10 random combinations) | 16,275 cases, 215 forms, 0 failures | 19,192, 267 forms, 0 | 17,512, 0 | 15,000, 0 | 16,450, 0 |

* The decoder returns, for every instruction, the same mnemonic and operands (registers, immediates, displacements, PC-relative distances after relaxation, scale, strides). Unresolved externals are given a pseudo-value of the required reach for the test. A16 was also encoded to a little-endian **byte** string and decoded from bytes: 338,616 instructions, 1,013,598 bytes, 0 failures.
* The boundary tests cover the shapes that the corpus does not contain (the 22 ATOM words, the 8 MESC words, TRAPL, `MOVQL`, the new instructions, `.u`/`.d`, `jtag`, `pushx`/`popx`, `mfsr`/`mtsr`, direct-page `d(DP)`): each is a mnemonic of some form and each form is exercised.
* **What the round trip does not prove**: semantics (that `popmret` pops then returns; that the hot-register tables name the registers the ABI wants) and the assembler text for forms that do not exist today (`movcall`, `mov2`, `popret`, `popmret`, `trapcc.*`). The 32-register compile was never assembled or run.

## 6. Measured sizes

### 6.1 Static (bytes of instructions; branches relaxed against real distances)

Today's encoding: 1,083,870 bytes (16-register corpus, 3.204 B/instruction, 338,313 instructions). For the 32-register corpus the baseline has two readings: **the same 16-register code under today's encoding (1,083,870, the one that is encodable)** and the 32-register code under today's rules with the register fields ignored (1,076,780, hypothetical, shown to isolate the encoding from the compiler).

| scheme | `max` policy | vs today's 16-reg (1,083,870) | `near` policy | vs today's `near` (1,014,098) | mean B/instr | sizes 1 / 2 / 3 parcels |
|---|---|---|---|---|---|---|
| **A16** | **1,013,598** | **-6.48%** | 943,812 | -6.93% | 2.993 | 207,755 / 93,539 / 37,322 |
| B16 (profile-tuned) | 1,012,556 | -6.58% | 942,808 | -7.03% | 2.988 | |
| **C16** (A16-style + 4 fusions, profile-tuned) | **979,192** | **-9.66%** | 909,464 | -10.32% | 3.049 | |
| **A32** | **1,040,280** | **-4.02%** (-3.39% vs the 1,076,780 hypothetical) | 970,316 | -4.32% | 3.110 | 186,389 / 110,543 / 37,555 |
| A32r | 1,039,442 | -4.10% | 969,530 | | | 187,205 / 109,561 / 37,798 |
| C32 | 1,007,172 | -7.08% | 937,266 | -7.58% | 3.178 | |
| A32 vs A16 (same scheme, 32 vs 16 registers) | +2.63% | | +2.80% | | | |

(With the earlier `fit/` layouts for comparison: the best flat layout was +0.17% to +1.3% over today's.)

**Outlier warning.** One file, `gcc-src_gcc_testsuite_gcc.c-torture_execute_memcpy-a2.c.s`, has 6,144 compare-immediate-and-branch instructions (`cbCC rN,#170` x4,096 and `#88` x2,048) and is **298,034 bytes = 27.5% of today's total**. Re-training and re-measuring without it (`outlier.py`): A16 -5.94% (739,122 vs 785,836 on the remaining 840 files; with the file kept in the measurement the scheme trained without it is still -6.18%); A32 -2.51% vs today's 16-register encoding on the remaining files (766,122 vs 785,836), +3.65% vs A16. So the conclusions hold; the headline is 0.5 point flattered by one synthetic file.

Where A16's saving comes from (bytes against today, per class): `cbCC rN,#imm,label` -38,410 (27,931 sites: widths chosen from the measured distributions instead of 5-bit-immediate/11-bit-offset), `movq #imm,r` -10,618, `lea d(r),r` -4,970, `call` -3,790 (a 6-byte external stays 6 bytes), 1-parcel `shr/shl #n` -1,834, `br` -1,802, loads and stores -900 to -1,400 each. The classes that **grow** (all small): conditional branches `bcc blt bcs bhi blos bge ble` +4 to +110 bytes each (their 1-parcel slots are given up to bigger families; 6-bit parcel offset), `movw d(r),r` +34, `bis #imm,r` +26, `add (rn)(rx),r` +20, `sub d(r),r` +16. In A32 the classes that grow are the register-register ones: `movq r,r` +3,872 (3.8% of the 50,518 moves involve a register outside the 16 hot ones and need 4 bytes), `movl d(r),r` +2,378, `xor r,r` +1,312, `add r,r` +1,036.

### 6.2 Dynamic: bytes fetched per executed instruction (six programs, 755.8 M executed instructions)

16-register code: per executed instruction of today's encoding, using the profile of `frag-dyn.md`; the new length is that of the same instruction in the new scheme. Today's number reproduces the 3.129 of the earlier fragments.

| | today | A16 | B16 (in-sample) | C16 (in-sample) | A32 (estimate) | A32r (estimate) | C32 (estimate) |
|---|---|---|---|---|---|---|---|
| pooled `max` | 3.129 | **2.822 (-9.8%)** | 2.754 | 2.743 | 2.980 | 2.879 | 2.936 |
| vs A16 | | | | | +5.6% | **+2.0%** | |
| pooled `near` | 3.115 | 2.808 | 2.740 | 2.730 | 2.966 | 2.865 | 2.922 |
| executed hardware instructions / original | 1.0001 | 1.0001 | 1.0001 | 0.9888 | 0.9511 | 0.9511 | 0.9472 |

Per program, bytes per executed instruction (`max`):

| program | executed (M) | today | A16 | A32 est. | A32r est. | executed-instruction ratio 32/16 (est.) |
|---|---|---|---|---|---|---|
| lz4 | 139.7 | 2.853 | 2.614 | 2.657 | 2.589 | 0.962 |
| zlib | 172.9 | 2.841 | 2.715 | 2.967 | 2.904 | 0.955 |
| bearssl hashes | 65.3 | 2.998 | 2.857 | 3.329 | 2.967 | 0.984 |
| bearssl ciphers | 73.6 | 2.662 | 2.511 | 2.914 | 2.765 | 0.961 |
| bearssl curves | 71.1 | 2.779 | 2.617 | 3.000 | 2.807 | 0.936 |
| Lua | 233.3 | 3.799 | 3.177 | 3.099 | 3.068 | 0.934 |

Executed instructions by length under A16: 60.4% two bytes, 38.1% four bytes, 1.5% six bytes, 0.01% eight (an expanded `cbCC`).

**Estimator caveat, repeated.** The 32-register figures use the function-weighted estimator: each function's executed bytes in the 16-register compile, scaled by the ratio of that function's static bytes (new scheme) in the 32-register compile to the 16-register compile. `frag-dyn.md` measured a relative error of about +-50% on the saving of this kind of estimator on a runnable change. The 32-register compile has never been run. Read A32's +5.6% as "about +3% to +8%" and A32r's +2.0% as "about -1% to +5%". Executed instructions fall by 4.9% pooled (-3.8% to -6.6% by program; +-50% on that saving: 0.927 to 0.976).

### 6.3 The profile-tuned schemes do not generalise (leave-one-out, `loo.py`)

B16 and C16 give 2.754 and 2.743, but they were trained on the very profile they are measured on. Training on five programs (weight 3x of the profile) and measuring the sixth: lz4 2.576, zlib 2.714, hashes 2.862, ciphers 2.433, curves 2.618 (all equal or better than A16), but **Lua 3.807 (A16: 3.177)**. Pooled leave-one-out: **3.00, worse than A16's 2.822**. The cause was not isolated (the five other programs, which are compression and cryptography, over-weight a few shapes and starve forms the Lua interpreter needs); the cheapest explanation is that the profile objective trades away generality. **Use A16 (static objective) as the scheme; B16/C16 numbers are in-sample.** The fusion gain of C16 is static and robust (it does not depend on the profile weight).

### 6.4 Fetch and decode consequences

* **Longest instruction: 6 bytes in the corpus; 10 bytes (`MOVQL`, 5 parcels) architecturally.** A 10-byte instruction at the worst 2-aligned offset (6) ends at byte 15, so it never spans more than two aligned 8-byte quads: the two-deep parcel buffer of the current design is enough. Fetch of the stream needs 5 parcels worth of valid bits instead of 3.
* **Where the length is known:** after parcel 0, as today, but from up to 16 bits rather than from 2: a priority-free prefix decode (129 cubes in A16, 151 in A32; the 1-parcel / 2 / 3 / 5 split). Soft rule (priority 4) broken; benefit named: it is the whole 6.5%.
* **Register-read timing:** 81.0% (A16) and 75.9% (A32) of hardware instructions have all register fields at the same bit positions of parcel 0 (`[3:0]`, `[7:4]`; `[4:0]`, `[9:5]` for 5-bit fields), so register ports can be read before the opcode decode finishes. The rest have registers in parcel 1 (the rare groups, the 3-register forms, the 2-parcel base+displacement with the base in `p1[15:12]`) and read after parcel 1 arrives, as today's base register `rm` does. **The hot-register fields are not register numbers but 3-bit (and in A32 4-bit) table indices**, so those forms add a 8-entry (or 16-entry) lookup in front of the read port: a gate delay on 1-parcel hot-register forms. In A16 the hot-8 are `r0 r1 r8 r2 sp r3 r9 r10` (90.8% of register uses); in A32 the hot-16 are `r0 r1 r8 r2 sp r3 r9 r10 r11 r4 r15 r5 r24 r25 r26 r6` (97.7%; `r24`-`r26` are the callee-saved registers of the 32-register compile). **The table must be written into the ABI and the compiler**; with a different allocation the numbers change.
* **Instructions per parcel buffer:** worst case 5 parcels in flight per instruction; the average instruction is 2.99 bytes (today 3.20).
* **Restartability:** the framework introduces no new side effects: each form is one memory operand, one register written in full. The fused instructions are the only exception (section 9).

## 7. Ablation (A16 / A32, static `max`, and the executed bytes per instruction for A16)

| lever removed | A16 bytes | change | A16 dynamic | change |
|---|---|---|---|---|
| none (A16) | 1,013,598 | | 2.822 | |
| 3-bit hot-register one-parcel `d(rn)` load/store | 1,029,886 | +1.6% | 2.879 | +2.0% |
| one-parcel `sp`-relative and `lea sp` | 1,035,244 | +2.1% | 2.888 | +2.3% |
| one-parcel immediates (`movq`, add/sub/and, shifts), `pushm8`, `add #8n,sp` | 1,078,820 | **+6.4%** | 2.982 | +5.7% |
| compare-with-zero-and-branch forms | 1,026,908 | +1.3% | 2.870 | +1.7% |
| compare-with-immediate-and-branch forms (falls to `cmp`+`bcc`) | 1,041,020 | +2.7% | 3.273 | **+16.0%** |
| both of those | 1,056,260 | +4.2% | 3.321 | +17.7% |
| scaled-index forms narrower than the fallback | 1,036,560 | +2.3% | 2.946 | +4.4% |
| narrow PC-relative / absolute / immediate forms | 1,029,602 | +1.6% | 2.843 | +0.7% |
| fewer displacement widths (8,12,16,20,24 only) | 1,022,472 | +0.9% | 2.826 | +0.1% |
| 20% code space free instead of 5% | 1,021,366 | +0.8% | 2.840 | +0.6% |
| 1% free instead of 5% | 1,012,594 | -0.1% | 2.825 | +0.1% |
| (forced fallbacks only, every instruction 3 parcels) | 1,524,200 | | 5.17 | |
| policy `near` | 943,812 | -6.9% | 2.808 | -0.5% |
| profile-tuned (mix 3 / mix 10) | 1,012,556 / 1,015,484 | -0.1% / +0.2% | 2.754 / 2.750 | in-sample |

Fusion (static, A-style objective, round trip verified in each case):

| fused pair | pairs fused (A16) | 16 registers | 32 registers |
|---|---|---|---|
| none | | 1,013,598 | 1,040,280 |
| `popm #mask ; ret` as `popmret`, `pop r ; ret` as `popret` | 4,862 | 1,004,010 (-0.95%) | 1,029,902 (-1.00%) |
| `movq r,r ; call` as `movcall` (4 or 6 bytes; the call keeps its reach) | 11,123 | 991,436 (-2.19%) | 1,015,454 (-2.39%) |
| `movq r,r ; movq r,r` as `mov2` (four 3-bit hot registers, 1 parcel, 2^-4 of code space) | 6,742 | 1,007,370 (-0.61%) | 1,035,104 (-0.50%) |
| all four | 20,428 | 980,288 (-3.29%) | 1,007,172 (-3.18%) |
| evaluated, **not built**: `movq #imm,r ; call` 3,799, `clr r ; br` 3,290, `movq #imm,r ; br` 2,872, `lea d(rn),r ; call` 2,259, `movq r,r ; br` 1,116 | up to 2 bytes each: 13,336 sites, at most 26,672 bytes (2.5%) | | |

32-register ablations (A32 = 1,040,280): no 4-bit hot tables (5-bit everywhere) 1,079,408 (+3.8%); no 3-bit hot one-parcel `d(rn)` 1,052,590 (+1.2%); no one-parcel immediates/shifts/`pushm` 1,094,036 (+5.2%); no compare-and-branch immediates/zero 1,064,776 (+2.4%); no 4-bit hot variants in the two-parcel families 1,032,144 (**-0.8%**, i.e. the optimiser is noisy at that level: the same scheme family with a different candidate set is better); a 5-bit one-parcel register-register form for 8 mnemonics (A32r) 1,039,442 static, **2.879 dynamic against 2.980**.

Levers examined and not built or found not worth it: trailing literals (earlier fragments: worse than inline immediates plus dedicated forms; the framework's wide fields give the same reach); accumulator-style short forms (the register-register forms already carry `rd` as the source); a 3-operand 1-parcel form (needs 12 bits of registers, 2^-4 of code space: the `mov2` pair is the only case that paid); 4-bit shift counts (taken by the solver as 3-bit and 5-bit immediate forms).

## 8. What still does not fit, or costs more than today

* **No single-instruction `cbCC` for 303 sites (A16) and 615 (A32)**: a compare with an immediate beyond 16 bits or a target beyond the widest field; assembled as `cmp` + `bCC`, extra bytes already counted. Today's encoding has a wide three-parcel form for most of them; this one deliberately has none (the code space was spent on narrower forms).
* **Conditional branches and some loads grow** by a few hundred bytes (section 6.1), a consequence of giving the code space to the families that save thousands.
* **Externals are still 6 bytes** under the assembler view (`max`): 33,220 references = 199 KB = 20% of the code. A relaxing linker saves 69.8 KB in both encodings; A16's 4-byte `call` reaches +-2 MB (20-bit parcel offset) against today's +-128 KB; its 4-byte `lea label` reaches +-32 KB, as today's.
* **`R4` has no spare sub-opcode**; the whole `R2`..`R4` family leaves 5.0% of code space free but a further 4-register instruction needs a new group.
* **The 32-register variant pays for the 4-bit-hot / 5-bit-cold split**: 3.8% of register moves become 4 bytes; crypto kernels pay most (+16% per instruction on the hash and cipher programs for A32; +4% with A32r).
* **Register tables in the ABI**: the hot sets above.
* `ATOM` operand placement and `TRAPCC` vector are assumed (section 3.2).
* The compiler (`pcc`) and assembler are untouched; a real assembler would need the form tables (`tables-*.md`) and the choose-shortest-then-relax loop of `scheme.py`.

## 9. Decisions left for the author

1. **Accept a variable-length prefix** (up to 16 bits, 129-151 product terms) instead of the 2-bit `len` field — the whole of the gain depends on it.
2. **Fused instructions** (`movcall`, `popmret`, `popret`, `mov2`): -3.3% size, -1.1% executed instructions; each is a two-µop instruction; a fault in the second part restarts the whole instruction, which is idempotent for `movcall`/`mov2`/`popret`/`popmret` (the first part reads registers it does not change; `popm` is already specified restartable). Costs: new mnemonics, `mov2` uses 2^-4 of the code space and only 8 registers, and one instruction writes two registers (OoO rename width).
3. **The hot-register tables** (section 6.4) and whether the ABI should be shaped so that the 8 (or 16) hottest are the arguments, the scratch and `sp`.
4. **Linker relaxation of external references**: worth 6.9% in both encodings; the encoding is ready for it.
5. **Refusing `SOP #imm`, `mov r,#imm`, `lea #imm`** (22 shapes the assembler currently accepts).
6. **ATOM operand placement** and the shape of `TRAPCC`.
7. **5% of code space left unassigned** (3,277 patterns); the ablation shows spending it is worth only 0.1%.
8. **32 registers**: see below.

## 10. Recommendation

* **Static size: A16** (1,013,598; -6.48%), or **C16** (979,192; -9.66%) if the fused instructions are accepted. **Dynamic bytes fetched: A16** (2.822 per executed instruction, -9.8% against 3.129; the profile-tuned 2.74-2.75 is in-sample and did not survive leave-one-out). **Overall: A16**, with the fusions as an option.
* **Is the encoding "already near-optimal" for 16 registers? No.** Its 6.5% (static) and 9.8% (dynamic) were left on the table by the fixed 2-bit length and 6-bit opcode partition; the entropy accounting says the larger remaining loss (28%) is parcel granularity, which the constraints fix.
* **32 registers are not worth it for code size or fetch.** With the best scheme found for each: static +2.6% bytes (A32 against A16), dynamic +5.6% (+2.0% with A32r) against a 4.9% reduction in executed instructions; the estimate's error (+-50% on the instruction saving; +-50% on the byte saving) leaves a possible break-even on the dynamic side only for the Lua-like interpreter (3.07 against 3.18 per instruction, where 32 registers do win: -3.4%) and loses everywhere else. Against *today's* encoding of the 16-register code the 32-register scheme is better (-4.0% static, -4.8% dynamic estimate), so adding registers is not the problem, the encoding of today's 16-register code is. If 32 registers are wanted for other reasons (spills in crypto kernels, out-of-order depth), take A32r (1-parcel 5-bit forms for `movq movl add sub xor and bis shl`) and C32 for fusion; do not expect them to shrink code.

## 11. Caveats and what is incomplete

* The optimiser is a heuristic (greedy; +-1% noise). A32 has not been tuned by the profile (there is no 32-register profile).
* The 16-register profile programs are different compiles from the 841-file corpus; A16/A32 were trained on the corpus, not on the profile. B16/C16 were trained on both.
* The `max`/`near` pair brackets the linker question; the true value depends on the final image sizes (the six linked programs are well inside ±2 MB).
* Not built into the round trip: the six fusion candidates listed as "evaluated, not built"; trailing 32-bit immediate literals ("same trick for 32-bit immediates"); a second fused-pair pass after the first; a hardware-realistic estimate of the gates (only product-term counts are given).
* The leave-one-out Lua result (3.807, equal to today's 3.799) is unexplained and was not debugged.
* Files: `enc.py` (framework), `cat.py` (forms and candidate pool), `solve.py` (optimiser), `scheme.py` (selection, relaxation, round trip), `proof.py` (decodability, boundary tests, probe coverage), `final.py` (runs everything; `final.json`, `final.log`), `abl.py` (`abl.json`), `fuse.py`, `fuse_abl.py`, `loo.py`, `outlier.py`, `a32r.py`, `dyn3.py` (profile), `entropy.py`, `analysis.py`, `tables.py`, `fam.py`, `bytes_rt.py`, `fusion.py`.

## 12. The study repeated on the new compiler's output: why pdp64/32 reached less, and the `cbCC` reach (2026-11-04)

Sections 0-11 were measured on the output of the old compiler. The compiler of `pcc-enc` (branch under development; the **committed** state `abacdf17`, built by `arch/pdp64/test/build-ccom.sh`) emits for both encodings
the fused pairs, a switch dispatch by halves, a forwarded value and `lea` folding (`pcc-enc/doc/PDP64-OPT.md`). The 841 files were compiled again (`ccom -m pdp64/16`, `ccom32 -m pdp64/32`), the optimiser trained on that
output (`docs/codegen-data/encoding/export_forms.py`, `reopt.py`), the grammars rewritten (`spec/`), the real `as64`, `ld64` and `sim64` rebuilt, and the six programs run again. All figures below are from the real toolchain unless
a row says *model*. The tools are in `codegen-data/encoding/`: `cbreach.py` (every `cbCC` site: distance, form that reaches it or the substitution), `cbforms.py`, `distances.py`, `reopt.py`, `loo_cb.py`.

### 12.1 Diagnosis (the grammars of sections 0-11 on the new compiler's code)

| | pdp64/16 | pdp64/32 |
|---|---|---|
| `cbCC` sites in the 841 files | 34,387 (1 parcel 7,839, 2 parcels 26,220) | 34,524 (1 parcel 6,269, 2 parcels 27,389) |
| no form reaches: assembled as `cmp` + `bCC` | **328** (0.95%) | **866** (2.51%) |
| ... of which the immediate needs more than 12 bits | 284 | 682 |
| ... of which a form with that immediate exists but its pc field is too short | 44 | 168 hot-register sites + 16 cold |
| ... of which the target is within 256 bytes (the immediate is the only reason) | 95 | 505 |
| first parcels the `cbCC` leaves take (of 65,536) | 19,314 (29.5%) | 6,144 (9.4%) |
| ... of which two-parcel forms with an immediate | 15,842 | 3,496 |
| executed pairs in the six programs (instructions executed in the pair, `sim64 -P`) | 3,958,721 = 0.61% of 647.1 M | 6,233,099 = 1.02% of 611.4 M |
| ... Lua's share | 3,957,360 | 6,128,801 |

Distance of the target (bytes, absolute) of all sites / of the substituted ones, and the sites by project (the grammars of sections 0-11):

| distance | <=16 | <=32 | <=64 | <=128 | <=256 | <=512 | <=1 K | <=2 K | <=4 K | <=8 K | <=16 K |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pdp64/16 all | 14,796 | 10,473 | 3,062 | 2,277 | 1,628 | 975 | 527 | 360 | 200 | 73 | 16 |
| pdp64/16 substituted | 25 | 24 | 28 | 10 | 8 | 27 | 48 | 114 | 34 | 6 | 4 |
| pdp64/32 all | 14,615 | 10,380 | 3,235 | 2,363 | 1,670 | 1,003 | 572 | 386 | 215 | 74 | 11 |
| pdp64/32 substituted | 142 | 126 | 99 | 67 | 71 | 72 | 43 | 151 | 44 | 42 | 9 |

| project | sites 16 / 32 | substituted 16 | substituted 32 |
|---|---|---|---|
| mbedtls | 11,288 / 11,348 | 220 | 583 |
| zlib | 1,345 / 1,348 | 54 | 116 |
| lua | 3,243 / 3,247 | 11 | 74 |
| bearssl | 2,039 / 2,076 | 23 | 45 |
| chibicc | 1,576 / 1,576 | 8 | 21 |
| lz4 | 843 / 875 | 9 | 18 |
| gcc-torture | 13,032 / 13,032 | 1 | 4 |
| c-testsuite, cjson | 335 + 686 / 335 + 687 | 1 + 1 | 3 + 2 |

The executed `cbCC` of the six programs are 10.5% of the instructions (67.7 M, 3.50 bytes each) in pdp64/16 and 10.7% (65.5 M, 3.51 bytes) in pdp64/32; after the re-optimisation 11.1% (71.7 M, 3.75 bytes: 18.3 M of one parcel,
43.9 M of two, 9.4 M of three) and 11.8% (71.7 M, 3.99 bytes: 9.9 M, 52.1 M, 9.7 M): the pairs became single `cbCC`s, the far ones three parcels long.

* **Why the 32-register encoding reaches less.** The mechanism is arithmetic, not a bug. A two-parcel `cbCC` has 32 bits to share between the prefix and sub-opcode, the register (4 bits in pdp64/16; 5 bits, or 4 bits
  if both registers are in the 16-entry hot table, in pdp64/32), the immediate and the pc field. A leaf takes 2^-(32-bits of operands) of the first parcels, so one more bit of register field halves the (immediate, pc) combinations a
  given share of the code space buys, and in pdp64/32 every combination exists twice (hot and any register) when it is wanted for both. The optimiser spent the same 95% budget; the loads, stores and moves of
  pdp64/32 won it from the `cbCC`, 9.4% of the space against 29.5%. The widest immediate of a pdp64/32 `cbCC` was 12 bits (`cbeq`, `cbne`, class `c` and the signed comparisons only with an 8-bit pc field), of a pdp64/16 `cbCC` 16 bits for `cbeq` and `cbne` alone; the wide
  error-code constants of `mbedtls` and `zlib` (`cbne r,#16640`) are the 682 of the 866 (284 of the 328). It is the immediate, not the distance: 58% of the 866 (29% of the 328) are within 256 bytes.
* **What the old numbers were.** The 38.8 M extra executed instructions of Lua in section 5 of the phase-2 report (68 static sites in a chain of `cbeq r0,#N,far`) are gone with the new compiler's switch dispatch by halves: 6.1 M
  executed pairs remain in Lua under the old grammar, 3.96 M in pdp64/16. They come from one function, `luaV_execute`: `cbhi r0,#41,L` ... a binary search on the opcode whose targets are the handlers, far inside a large function, one site
  executed 2.05 M times. The class-`c` conditions (`cbhi`, `cbcs`...) with an immediate of 7 bits or more had an 8-bit pc field (+-256 bytes) in the old pdp64/32, and the `cbeq` chain beyond +-4 KB had none.
* **The model's 99-byte credit.** `solve.py` credited a `cbCC` form with the difference between 99 bytes and its own size for each site the form made encodable: a `cbCC` that no form reached counted as "unencodable". The real
  cost is what `as64` does: `cmp` (2 to 4 bytes) + `bCC` (2 to 4), the same bytes as a two-parcel `cbCC`, plus an executed instruction and the flags. Priced that way (below) the byte objective *gives away* reach: the same corpus
  size is reached with 1,436 substitutions in pdp64/32 as with 17.

### 12.2 What the optimiser does now, and the ablation (pdp64/32 and pdp64/16, *model* bytes of the corpus, 841 files)

`export_forms.py` options: the corpus of each encoding is the compiled assembly (`PDP64_CORPUS_DIR_<TAG>`); the distances fitted are those of the previous round's layout by the encoding being designed (the original
used the old encoding's lengths); a `cbCC` that no form reaches costs the `cmp` and the `bCC` as the previous round sizes them plus `lam` bytes for the extra instruction; three-parcel `cbCC` candidates (`--cb3`; immediate of
4 to 32 bits, pc field of 12 to 28 bits, registers with a pc field of 16 to 28 bits); a local search after the greedy selection (`--refine`: drop the leaf whose removal costs least per unit of code space, refill, keep if
smaller; it gained 36 bytes: the greedy is not far from a local optimum); the hot tables are fixed to the grammar's (`--keep-hot`, they are the ABI and the corpus agrees: the same 8 and 16 registers, a different order of the last four).

| configuration | pdp64/32: bytes | substituted sites | pdp64/16: bytes | substituted sites |
|---|---|---|---|---|
| the grammars of sections 0-11 (trained on the old compiler's code) | 985,082 | 866 | 951,212 | 328 |
| retrained, 99-byte credit, old distances | 991,546 | 791 | 951,462 | 329 |
| retrained, 99-byte credit, own distances (3 rounds) | 991,736 | 805 | | |
| price of the extra instruction 0 bytes (bytes only) | 978,284 | 1,453 | 945,530 | 1,099 |
| 2 bytes (one parcel) | 978,304 | 1,436 | 945,434 | 921 |
| 4 bytes | 980,086 | 1,308 | | |
| 2 bytes + three-parcel `cbCC` | 976,114 | 17 | | |
| **2 bytes + three-parcel `cbCC` + local search (chosen)** | **976,078** (as64: 976,000) | **17** | **944,672** (as64: 944,600) | **4** |
| ... with finer two-parcel candidates (pc 9, 11, 13 parcels; immediates of 7 and 14 bits) | 976,128 | 17 | | |

* The retraining with the old cost model gives *worse* code than the committed grammar (+0.66% in pdp64/32): the greedy selection is sensitive to the weights at the percent level (section 11 said +-1%), and the committed
  grammar had the luck of its corpus. The prices below that are what moved the result; the three-parcel `cbCC` is what removes the substitutions at no cost in bytes (-0.2%).
* Without the three-parcel forms there is no setting that both keeps the bytes and the reach: the 14-bit pc field of a two-parcel form needs 4 + 3..10 + 14 bits and the prefix of the leaf at most 16.
* Chosen forms (pdp64/32): `CB3I16_12H/b,c` and `CB3I16_12/a` (a 16-bit immediate, a 12-bit pc field = +-4 KB), `CB3I8_20H/a`, `CB3I8_20/b` (+-2 MB), `CB3I12_16/c`, `CB3R24H/a,b,c` (two hot registers, +-32 MB);
  pdp64/16: `CB3I16_12/a,b,c`, `CB3I8_20/a,b,c`, `CB3R24/a,b,c`. They take 3.2% (pdp64/32) and 10.4% (pdp64/16) of the first parcels, three times less than the two-parcel forms of the old grammars took, and the rest went to loads, stores and
  immediates: corpus bytes -0.69% (pdp64/16) and -0.92% (pdp64/32).
* The one-parcel `cbCC` with 0 shrank: `CBZ1_5/a` (5-bit pc, +-64 bytes) became `CBZ1_4/a` (+-32 bytes) in pdp64/32; pdp64/16 has `CBZ1_4,5,7/a` (it had `_5`, `_6`). Static one-parcel `cbCC` sites in pdp64/32: 6,269 -> 4,037 (pdp64/16: 7,839 -> 8,968); executed one-parcel
  `cbCC` in lz4: 3.07 M -> 0.90 M in pdp64/32 (3.12 M -> 4.14 M in pdp64/16): 2.17 M `cbCC` that grew by 2 bytes are 4.3 M of the 4.1 M bytes lz4 fetches more in pdp64/32 (section 12.4). The static objective does not see loops; weighting backward branches was not tried.
* A profile-tuned variant was **not** tried (the task asked for corpus training; the in-sample variant would need the profile weights `dynkeys.pkl`, which were not kept).

### 12.3 Reaches measured, and chosen (the layout of the new grammar; field widths in parcels: a field of w bits reaches +-2^w bytes)

Share of the sites each pc-field width reaches (`distances.py`; sites resolved inside the file; the 841 files are compiled one by one, so a call or `lea` of another file is *external*: 14,136 calls, 12,787 `lea`, 6,556 `movcall` in
pdp64/32, which need the 32-bit field until the linker relaxes them):

| class | sites (external) pdp64/32 | 6 | 7 | 8 | 9 | 10 | 12 | 14 | 16 | widest form chosen: 1 / 2 / 3 parcels (pdp64/16 and /32) |
|---|---|---|---|---|---|---|---|---|---|---|
| `cbCC` | 34,524 (0) | 81.6 | 88.7 | 93.5 | 96.4 | 98.1 | 99.8 | 100 | 100 | 7 or 4 / 14 / 24 bits |
| `bCC`, `br` | 18,613 (0) | 71.4 | 81.1 | 88.6 | 93.7 | 96.5 | 99.7 | 99.9 | 100 | 9 / 16 / 32 |
| `call`, `jmp` | 6,830 (14,136) | 7.6 | 13.8 | 21.4 | 30.0 | 39.9 | 56.8 | 69.9 | 77.1 | - / 18 / 32 |
| `movcall` | 4,960 (6,556) | 5.4 | 12.4 | 23.5 | 37.6 | 53.8 | 83.3 | 99.2 | 100 | - / 16 / 32 |
| `lea d(pc)` | 7,176 (12,787) | 4.0 | 6.5 | 9.8 | 14.6 | 23.2 | 47.2 | 91.8 | 100 | - / 16 / 32 |

(pdp64/16 is within 0.5 points in every cell; its sites are 34,387 / 18,773 / 7,137 / 4,658 / 7,176.) Reading: `bCC` and `cbCC` are short-range (93% within +-256 bytes, 98% within 1 KB), so their two-parcel
forms with 8 to 14 bits and the one-parcel forms with 4 to 9 bits are chosen from the data; `call`, `movcall` and `lea` are long-range, and the field widths the optimiser chose (16 to 20 bits for two parcels) reach +-128 KB to +-2 MB,
more than any of the six programs needs (the largest, Lua, is 85 KB of text). The call, `lea` and `bCC` reaches changed by one or two bits from the old grammars (`call` 2-parcel 20 -> 18 bits, `bCC` 1-parcel 8 -> 9 in pdp64/32);
the data do not favour more.

### 12.4 Measurements with the real toolchain (`pcc-enc abacdf17`, `as64`/`ld64`/`sim64` of this tree; before = the grammars of sections 0-11, after = the grammars of `spec/` now)

Static, 841 files, instruction bytes (`as64 --stats`):

| | before | after | change |
|---|---|---|---|
| pdp64/16 | 951,144 | **944,600** | -0.69%; substituted `cbCC` 328 -> 4 |
| pdp64/32 | 985,082 | **976,000** | -0.92%; 866 -> 17 |
| pdp64/32 over pdp64/16 | +3.57% | **+3.32%** | |
| ... without the outlier file `memcpy-a2.c` (27% of the bytes, 6,144 `cbCC rN,#170/#88`) | 723,894 vs 693,028 = +4.45% | 717,884 vs 686,484 = **+4.57%** | |
| the 16-register code assembled as pdp64/32 (identical compiler output, only the register fields differ) | 993,680 (+4.47%) | **984,554 (+4.23%)** | |

Six programs (`sim64 -P`, all code: crt, stand-in libc, program; stdout identical to the host's in all 12 runs, before and after; recipe `scratchpad/cb/progs.py`, `dynstats.py`):

| | executed instructions | executed bytes | bytes / instruction | executed `cmp`+`bCC` pairs | linked text, bytes |
|---|---|---|---|---|---|
| pdp64/16 before | 647,148,318 | 1,760,855,344 | 2.721 | 3,958,721 | 165,860 |
| pdp64/16 after | 643,191,916 | **1,723,608,600** (-2.12%) | 2.680 | 133 | 164,014 |
| pdp64/32 before | 611,383,541 | 1,785,556,760 | 2.921 | 6,233,099 | 171,854 |
| pdp64/32 after | 605,235,949 | **1,779,890,292** (-0.32%) | 2.941 | 80,027 | 170,448 |
| the 16-register code run as pdp64/32 | 643,194,549 | 1,908,917,398 | 2.968 | 133 | 174,326 |

| pdp64/32 against pdp64/16 (after) | instructions | executed bytes | adjusted for the pairs |
|---|---|---|---|
| lua | -6.36% | +3.90% | the same |
| lz4 | -6.62% | +0.26% | |
| zlib | -9.45% | -4.64% | -9.50% / -4.71% |
| bs_hash | -0.20% | +1.50% | |
| bs_sym | -3.59% | +14.72% | |
| bs_ec | -3.21% | +16.51% | |
| **all six** | **-5.90%** | **+3.27%** | -5.91% / +3.25% |

(Before: instructions -5.53% raw, -5.91% adjusted; bytes +1.40% raw, +0.89% adjusted.) Frame loads + stores (`sim64 -P` categories): 66.59 M in pdp64/16, 24.32 M in pdp64/32 (-63.5%), unchanged by the re-optimisation.

### 12.5 Is pdp64/32 still worse than pdp64/16 in fetched bytes and size? Yes: +3.3% in both.

* **Fetched bytes: +3.27% (1,779.9 M against 1,723.6 M)** for 5.90% fewer instructions and 63.5% fewer frame accesses. Before the re-optimisation the gap was +1.40%: the `cbCC` fix paid pdp64/16 more (-2.12% bytes) than pdp64/32 (-0.32%),
  because pdp64/16 gained in the kernels (lz4 -4.6%, `bs_sym` -2.6%, `bs_ec` -2.9%) from its one-parcel `cbCC` forms, while pdp64/32's one-parcel form got shorter, and pdp64/32's fetch is dominated by what a 5-bit field costs on the crypto kernels (`bs_sym` +14.7%, `bs_ec` +16.5%).
* **Where the bytes go.** The same 16-register code, assembled as pdp64/32, fetches **+10.75%** more bytes (1,908.9 M against 1,723.6 M) and is +4.23% larger statically; the 32-register compile of the same programs then fetches 6.76% less than that
  (fewer instructions, fewer frame accesses) and is 0.9% smaller statically. So the price of the wider field is 10.75% on the fetch side, and the register file repays about two thirds of it.
* **Size: +3.32% statically** (+4.57% without the outlier file); the linked text of the six programs is 170,448 bytes against 164,014 = **+3.92%**.
* **The `cbCC` substitution is no longer a cause of anything**: 0.0% of the executed instructions of pdp64/16 and 0.013% of pdp64/32 (80,027 pairs, 78,000 of them at one site in zlib). The Lua +12.4% of phase 2 is gone: Lua executes 6.4% fewer instructions in pdp64/32.
* Not a reason to change the verdict of section 10 (the 32-register encoding is not worth it for size or fetch alone), but the instruction-count and frame-traffic advantage is now measured without the `cbCC` artefact.

### 12.6 Checks

* **Round trip**: every instruction the new compiler emits for the corpus encodes and decodes: 301,258 hardware instructions (pdp64/32) and 306,022 (pdp64/16) through the model with 0 mismatches and 0 unencodable; boundary vectors of every
  form (15,642 and 15,846) 0 failures; the C codec against the model on 19,073 and 18,856 vectors and 57,101 and 38,730 decoder patterns 0 mismatches (`tools/check-enc.sh`); hbnf's generated decoder against the codec on 262,144 parcel sequences per
  encoding, 0 disagreements (`tools/check-grammar-enc.sh`).
* **The real assembler against the model on the whole corpus** (`asm_vs_model.py`): pdp64/16 839 of 841 files identical, 304,054 instructions compared parcel by parcel, 0 differ, decoded back 0 differ; pdp64/32 the same
  839 files, 299,350 instructions, 0 differ. The two files (`chibicc hashmap.c`, `lz4 xxhash.c`) differ in the model's pseudo-distance for a literal-pool load (as before; as64 knows the pool): model 944,672 and 976,078 bytes against as64's 944,600 and 976,000.
* **Leave-projects-out** (`loo_cb.py`, model bytes): trained without `lua`, `lz4`, `zlib` and `bearssl` (348 files, the sources of the six programs) and measured on them, pdp64/32: 306,564 bytes with 126 substitutions, against 305,024 and 17 for the grammar
  trained on everything and 307,812 and 253 for the grammars of sections 0-11. About half of the gain (-0.40% of -0.91%) is out of sample; the reach of the three-parcel forms is not fully (126 substitutions where the chosen set meets a register
  pair or a constant it was not trained on). pdp64/16 on the same 348 files: 296,568 bytes and 73 substitutions trained without them, 293,880 and 4 trained on everything, 297,128 and 97 for the grammar of sections 0-11 (-0.19% of -1.09% is out of sample).
* `tools/check-all.sh` green. Not measured: timing, energy, the gate count of the wider `cbCC` decode (the three-parcel `cbCC` has three formats that read a register pair, an immediate and a 12 to 24-bit pc field).
