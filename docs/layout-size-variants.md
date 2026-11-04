# The 32-register layout with trailing literals: sizes

[← pdp64 index](../README.md)

For the author's annotation. Follows [`layout-fit-analysis.md`](layout-fit-analysis.md) and section 5 of [`register-file-options.md`](register-file-options.md). The title of the first section below is the report's own.

## The 32-register layout with trailing literals: allocation, size and fetch model

This reruns the allocation and size model of `frag-fit.md` with the trailing-literal rule of `register-file-options.md` section 5, on the 16-register compile (`spill/asm-base16`) and on the 32-register compile (`spill/asm-r32`, 841 files each). It is a **size model, not an assembler**: nothing here was assembled or run in the new layout.

### 1. Validation first

The model has two parts: a model of the **current** encoding and a model of the new layout. Both do their own branch relaxation (an instruction's length is recomputed from the real distance to its label until no length changes; lengths only grow).

* **Current encoding, 16-register code: the model gives 1,083,870 bytes, the assembler's own total, with 0 mismatching records out of 338,313** (`fit/valcur.py`). It reproduces every page-2 choice, every branch and `cbCC` length, the literal-pool loads (`=K`, always 4 bytes) and `sym+off` labels. This validates the parser, the relaxation, the operand classification and the label distances, which the new-layout model shares.
* The new-layout model is **not** validated against anything: no encoder exists for it. Its confidence rests on the shared machinery above and on the rules being simple counting rules (field widths). Expect errors of a few thousand bytes (0.1% to 0.3%) from things the model leaves out: pool references are charged 6 bytes, `cbCC` wide forms beyond reach are charged 8, a few `SOP`/`XFER` memory forms with unusual modes use the generic rule.

### 2. Variants and sizes (static)

Baseline (i) is today's encoding of the 16-register code: **1,083,870**. Column (ii) is the new layout on the 16-register code, (iii) the new layout on the 32-register code. Shares are against (i). "Slots": one-parcel / two-parcel / three-parcel opcodes used (of 62 / 64 / 64); the one-parcel map is always full: 30 mandatory slots (24 register-register, `SOP`, `SYS`, 4 short-branch) and 32 optional ones filled greedily by bytes saved.

| Variant | (ii) 16-reg code | share | (iii) 32-reg code | share | (iii) vs (ii) | Slots 1/2/3 | Modes | Literal-bearing instr. (static, 16-reg code) |
|---|---|---|---|---|---|---|---|---|
| V0 as drawn: inline immediates, 11-bit PC-relative, 1 `cbCC` condition slot | 1,130,530 | +4.30% | 1,123,320 | +3.64% | -7,210 | 62/60/53 | 13 | 0 |
| V1 V0 + dedicated `CALL label`, `LEA label` | 1,107,102 | +2.14% | 1,099,948 | +1.48% | -7,154 | 62/61/54 | 13 | 0 |
| V1b V1 + 2 `cbCC` slots | 1,102,786 | +1.75% | 1,095,720 | +1.09% | -7,066 | 62/63/57 | 13 | 0 |
| V1c V1 + 4 `cbCC` slots | 1,099,940 | +1.48% | 1,092,936 | +0.84% | -7,004 | 62/67 (3 over)/63 | 13 | 0 |
| **a** trailing immediates; one-parcel base only where a slot exists today; other immediate-takers two-parcel base + literal (strict) | 1,110,650 | +2.47% | 1,103,556 | +1.82% | -7,094 | 62/61/54 | 11 | 17,762 |
| a2 as a, but a two-parcel immediate of 11 bits stays inline | 1,106,364 | +2.08% | 1,099,148 | +1.41% | -7,216 | 62/61/54 | 12 | 15,631 |
| a3 as a, inline field signed -8..7 (the rule says 0..15) | 1,107,668 | +2.20% | 1,100,614 | +1.54% | -7,054 | 62/61/54 | 11 | 16,290 |
| **b** one-parcel base for every immediate-taking instruction | 1,108,396 | +2.26% | 1,101,094 | +1.59% | -7,302 | 62/61/54 | 11 | 17,504 |
| b3 as b, signed field | 1,105,296 | +1.98% | 1,098,020 | +1.31% | -7,276 | 62/61/54 | 11 | 15,974 |
| **c** trailing displacement for `CALL`/`LEA` label (one-parcel base each) | 1,116,614 | +3.02% | 1,109,536 | +2.37% | -7,078 | 62/60/53 | 10 | 124,770 |
| d1 a + 2 `cbCC` slots | 1,106,334 | +2.07% | 1,099,316 | +1.43% | -7,018 | 62/63/57 | 11 | 17,762 |
| d2 a + 4 `cbCC` slots | 1,103,446 | +1.81% | 1,096,490 | +1.16% | -6,956 | 62/67 (3 over)/63 | 11 | 17,762 |
| **e** a + stack form with 128 entries (4 banks) | 1,110,368 | +2.44% | 1,103,414 | +1.80% | -6,954 | 62/61/54 | 11 | 17,762 |
| **X1** best combination: trailing immediates, signed field, inline 11-bit kept, all immediate-takers one-parcel, dedicated `CALL`/`LEA`, 2 `cbCC` slots | **1,097,800** | **+1.29%** | **1,090,612** | **+0.62%** | -7,188 | 62/63/57 | 12 | 14,332 |
| X2 X1 with 4 `cbCC` slots | 1,094,920 | +1.02% | 1,087,798 | +0.36% | -7,122 | 62/67 (3 over)/63 | 12 | 14,332 |
| X3 X1 with the `PUSHM` window following the callee-saved set | 1,097,800 | +1.29% | **1,085,718** | **+0.17%** | -12,082 | 62/63/57 | 12 | 14,332 |

How to read the variants:

* **(c) cbCC trailing displacement:** a two-parcel base with the displacement in the field when it fits and a 16-bit trailing displacement otherwise is 4 or 6 bytes, the same bytes as the three-parcel form, so the table does not list it separately. It only saves the three-parcel `cbCC` slots (3 per condition slot) and shortens nothing.
* **(c) memory operands beyond the 6-bit field:** a 16-bit trailing displacement after a two-parcel base is 6 bytes, the same as the 22-bit three-parcel form; no byte change, only reach (the third-parcel form reaches further). Not run separately.
* **`CALL`/`LEA` as one-parcel bases with a trailing displacement (variant c)** costs 5,964 bytes against (a), which has the same immediates with dedicated opcodes: two one-parcel slots are taken from cheaper forms, and every call and `lea` gets a literal (local ones 4 bytes as today, external ones 6 as today, but the generic PC-relative loads pay 4 + literal). **The dedicated two-parcel opcodes of `frag-fit.md` section 3 are better.**
* **4 `cbCC` slots overflow the two-parcel map by 3** (67 of 64): they need the 12 `MESC` forms moved to three parcels or the condition carried in a trailing field.
* **Stack form with 128 entries (e)** gains 282 bytes over (a): the banks use 12 slots that otherwise hold fixed-offset and `(Rn)` forms worth about as much. Not worth it.

**One-parcel slot arithmetic (b against a).** In (a) the optional slots keep `MOVQ`, `ADD`, `AND`, `SHL`, `SHR`, `SAR`, `BIS` immediates and drop `xor` and six `(Rn)` abbreviations (`ld.b` 586, `ldz.w` 538, `ldz.l` 312, `st.w` 208, `ld.w` 58 bytes, and `xor` immediate 458). (b) needs `CMP` (saves 2,540), `MUL` (932) and `SUB` (264) immediate slots; the greedy fill takes `CMP` and `MUL` and drops `fix:stq1` (654), `fix:ldl3` (604) and the same low `(Rn)` forms: **net 2,254 bytes saved (1,108,396 against 1,110,650) for two slots moved.** Taking the slots from the six page-2 abbreviations is the same trade: the abbreviations dropped in both variants are worth 2,154 bytes together.

### 3. Findings from the variants

1. **The trailing-literal rule does not by itself save code.** Strict (a) is 3,548 bytes **worse** than inline immediates plus dedicated opcodes (V1, 1,107,102): a small negative immediate costs 2 bytes more as a literal than as an inline field, and instructions without a one-parcel base pay 4 + literal where the inline 11-bit mode costs 4. The rule pays when combined with an inline field that is signed, the 11-bit mode kept for two-parcel bases, and one-parcel bases for every common immediate-taker (X1: -9,302 bytes against V1).
2. **What it fixes is reach, not bytes:** 1,204 immediates beyond 27 bits (6 or 8 bytes, as the four-parcel repair), `MOVQL #imm64` (10 bytes, not in the corpus), PC-relative and absolute fields of 16/32/48 bits. The mode field falls from 13 to 10 to 12 modes depending on what stays inline.
3. **The 32-register code is 7,000 to 12,000 bytes smaller than the 16-register code in the same layout** (0.65% to 1.1%): (iii) against (ii). It is 12,082 with a `PUSHM` window that follows the callee-saved set (X3) because the 32-register compile pushes masks above bit 18 (`pushm #0x1008F00` and similar: 231 + 145 sites in the 2,374 `pushm`) which cost 6 bytes with a fixed window.
4. **Net against today's 16-register encoding (iii vs i): the best variant is still larger.** X2 +0.36%, X1 +0.62%, X3 +0.17% (needs the window = callee-saved set). The earlier estimate in `register-file-options.md` section 5 ("0.4% gain to 0.2% cost") is not reproduced; the measured range is **+0.17% to +1.3% for variants that fit the opcode maps**.

### 4. Dynamic: bytes fetched (executed instruction bytes)

Six programs, 755.8 M executed instructions (`dyn/work/x/*.prof`, per-PC counts mapped to the instructions of the 16-register compile, as in `frag-dyn.md`). For each executed instruction the new-layout length is taken from the layout of its unit. The 32-register figure uses the function-weighted method: the executed bytes of each function in the new layout (16-register code) scaled by the ratio of that function's static new-layout bytes in the 32-register compile to the 16-register compile; executed instructions scale by the function's static instruction ratio (the "uniform" estimator A of `frag-dyn.md`, 4.89% fewer instructions pooled). The estimate inherits the +/-50% relative error that `frag-dyn.md` measured for estimator B on a runnable change; the 32-register code has never run.

**Pooled, bytes per executed instruction** (current encoding, 16-register: 3.129, measured):

| Variant | new, 16-reg code | change in bytes fetched | new, 32-reg code (est.) | change in bytes fetched | literal-bearing, % of executed |
|---|---|---|---|---|---|
| V1 dedicated `CALL`/`LEA`, inline immediates | 3.458 | **+10.49%** | 3.420 per instruction | **+3.94%** | 0 |
| a trailing immediates (strict) | 3.499 | +11.80% | 3.465 | +5.32% | 4.06% |
| X1 best | **3.411** | **+9.01%** | **3.378** | **+2.65%** | 2.69% |

Per program, X1, change in bytes fetched, 16-reg code / 32-reg estimate: lz4 +2.20% / -2.06%; zlib +9.03% / +6.08%; bearssl hashes +2.24% / +0.49%; bearssl ciphers +1.91% / -3.65%; bearssl curves +0.88% / -2.65%; **Lua +16.94% / +5.93%**. Bytes per executed instruction (X1, 16-reg code): lz4 2.916, zlib 3.098, hashes 3.065, ciphers 2.713, curves 2.803, Lua 4.443. Executed instructions saved by 32 registers (estimator A): 3.85%, 4.48%, 1.59%, 3.87%, 6.38%, 6.62%.

Why the dynamic cost exceeds the static one: the executed code concentrates where the 6-bit scaled displacement, the 5-bit immediates and the 11-bit PC-relative reach overflow (Lua's interpreter loop addresses fields at offsets beyond 31 entries and loads constants; zlib's match loop likewise), while the static corpus is dominated by cold code. A literal is an extra fetch group for 2.7% (X1) to 4.1% (a) of executed instructions.

### 5. Answer

* **Does the 32-register layout reduce static code size relative to today's 16-register encoding? No.** The best variants that fit the opcode maps are +0.6% (X1) and +0.36% (X2, which overflows the two-parcel map by 3); +0.17% (X3) if the `PUSHM` window follows the callee-saved set. The extra registers themselves save about 0.65% to 1.1% (iii vs ii); the narrowing of displacements, immediates and `cbCC` reach costs 1.3% to 1.7%.
* **Does it reduce bytes fetched? No.** Pooled +2.65% (X1; range -3.7% to +6.1% by program) although 4.9% fewer instructions execute. With +/-50% on the saving of instructions the pooled byte change stays positive (about +1% to +4%); Lua dominates (+5.9%).
* **Remaining misfits (unchanged by trailing literals):** the 6-bit scaled displacement (+10,906 + 942 bytes inside every figure above); the unscaled mode for tagged pointers; the mode budget (`.U`, deferred loads: 12 modes used, 4 free, 5 to 8 wanted); `cbCC` wide beyond reach (58 sites with 2 condition slots, 8 with 4); the `EPSW` masks (96 bits) and the saved-state frame; the ABI split of `R16` to `R31` (decides the `PUSHM` window, worth 4,894 bytes); 4-slot `cbCC` does not fit the two-parcel map; the fused multiply-add words need three parcels.

### 6. Assumptions and what is not modelled

* Static counts, 16-register pcc output; the 32-register compile is pcc's and was never assembled or run.
* Immediate rule as stated: `s=0` gives 0..15 unsigned (a3, b3, X1 use a signed -8..7 field: not the author's text); the literal holds the smallest of 16/32/48/64 bits that contains the value.
* Pool constants (`=K`) are charged 6 bytes in the new layout (assumed within the 16-bit trailing reach); the pool data is not counted in either layout.
* Page-2 abbreviations that lose their slot become two-parcel forms; the selection of optional one-parcel forms is by static bytes saved, made separately for each corpus.
* `cbCC` with an immediate beyond 5 bits is the three-parcel wide form; a 32-bit literal there (which trailing literals would allow) is not modelled because the compiler already emitted `CMP` and `Bcc` for those.
* Not modelled: the `EPSW`/`PUSHX` frame, `MESC`, `ATOM`, `TRAPL`, `SYSX` forms (absent from the corpus), alignment padding changes, and the fetch-buffer effect of literals (longest instruction in the corpus under the model: 8 bytes; by design a three-parcel base plus a 64-bit literal is 14 bytes, a three-deep fetch buffer).
* Scripts and data: `fit/m2.py` (parser and relaxation), `fit/cur.py` and `fit/valcur.py` (current encoding and validation), `fit/newm.py` (new layout), `fit/runv.py` (variants), `fit/slots.py` (slot arithmetic), `fit/dyn2.py` (dynamic), results `fit/res_base16_all.json`, `fit/res_r32_all.json`, `fit/dyn_out.json`.
