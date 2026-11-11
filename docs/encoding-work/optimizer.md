# The prefix-encoding optimiser: what the Python did, and `encopt`, its exact replacement in C

2026-11-10. The author asked for "the python script that went over all the mnemonics and figured out the optimal prefix encoding for pdp64 to fit the most used opcodes into
the smallest number of 16 bit packets" to be translated into C with optimal algorithms, to be re-run when the decisions on the opcodes and the mnemonics are made.
This page says which program that is, what it computes (inputs, constraints, objective, outputs, what is exact and what is heuristic, the gap), and how `encopt`
(`tools/encopt/`) replaces it. The Python stays in `docs/codegen-data/encoding/` as history; nothing in `spec/` or any generated output was touched.

**Update, same day (encopt 1.1), after the author's answers**: the code space is now all of it, no reserve (section 9); the corpus reader is corrected, so the 342 `set` instructions
count (section 10); the objective is a choice of three, with a profile collector and a table of how they pull against one another (section 11). Sections 1 to 8 stay as written
on the first run (95% budget, the reader's bug, the statistics of the first compile: 296,069 instructions); the figures of sections 9 to 11 are on the statistics of the compile
of the same afternoon with the pcc branch `single-pdp64` (293,448 instructions: the compiler had moved on), so they are not comparable with section 5's numbers digit for digit, only
as a pattern.

## 1. Which program

The optimiser is **`docs/codegen-data/encoding/solve.py`, function `solve()`**, driven by `variants.build()` (the design loop `export_forms.py`, which produced the grammars of
`spec/` with `--rounds 2 --lam 2 --keep-hot --refine 6 --cb3`). It works on top of:

| file | role |
|---|---|
| `load.py`, `m2.py`, `norm.py` | read the compiled assembly of the corpus and normalise operands (`('R',n)`, `('B',disp,base)`, `('X',..)`, `('PC',dist)`, `('I',v)` ...) |
| `enc.py` | the model: a *form* = (parcels, mnemonics, operand specs); `Form.Lleaf = 16*parcels - operand bits - sub-opcode bits`; `Spec.fit()` says whether an operand fits a field; `Code` splits a mnemonic list into binary-aligned *leaves* and assigns the prefixes (`Code._assign`) |
| `cat.py` | the forms: `mk()` the forced ones (rare groups `R2 R3 R4 RRI`, fallbacks with 22 to 32-bit fields, `SYS0`...), `cands()` the 2,193 optional ones, `fused_forms()` |
| `solve.py` | `build_keys` (the corpus as weighted instruction classes), `hot_tables`, **`solve`** (the selection) |
| `scheme.py` | encoder, decoder, `cbCC` expansion, layout with branch relaxation: the instrument that measures a selection |

Not the optimiser, each a measurement on its results: `entropy.py` (an entropy bound of 13.9 bits per instruction, 17.2 with external references, section 2 of `docs/encoding-proposal.md`),
`final.py`, `abl.py`, `fuse_abl.py`, `loo.py`, `reopt.py`, `loo_cb.py` (ablations and leave-out checks), `fusion.py`, `fam.py`, `tables.py`, `cur.py` (today's `r20` layout as a model),
`write_hbnf.py` and `export_forms.py` (write the grammar from the chosen forms: they are the output stage), `dyn3.py`, `dynrun.py` (dynamic estimates; the profile `dynkeys.pkl` was not kept).
The two-grammar period (16 and 32 registers) is over (errata 122, 123): the numbers here are the 32-register compile only.

## 2. What the Python computes

**Inputs.** The compiled assembly of the 841-file corpus (`ccom -m pdp64/32`, the recipe of `tools/arch-compare`: `prep.py aarch64`, `build-ccoms.sh`; one `.s` per source file).
Each instruction is a *key* `(mnemonic, normalised operands)`; operand values matter (register number, displacement, immediate, scale, the distance of a pc-relative operand
from the layout of the previous scheme; an unresolved external reference is `None` and needs a 32-bit field). The study does **not** use a histogram of mnemonics or of
operand classes: it uses the full distribution of keys (50,399 distinct keys, 296,069 instructions for the corpus compiled today), because whether a form *fits* depends on the values.
Besides: the hot-register tables (the 8 and 16 registers used most, exact by count; kept equal to the grammar's with `--keep-hot` because they are ABI), the four fused pairs (their forms are forced; the
compiler emits them), and for a `cbCC` that no form reaches the price `cmp` + `bCC` + `lam` (2 bytes for the extra instruction). Weights are **static counts**; a dynamic weight
(`mix`) exists in `variants.build` but its data is gone.

**Constraints.** Parcel 16 bits; the length is a function of parcel 0 alone (1, 2, 3 or 5 parcels); each *leaf* has a prefix of 1 to 16 bits; Kraft's inequality
(`sum 2^-L <= 1`, the exact condition for a prefix-free assignment); a form of `n` parcels whose operands need `b` bits has prefix length `16n - b` (no pad bits: every bit
is prefix, sub-opcode or operand); a group of `m` mnemonics takes `m * 2^(16-L)` of the 65,536 first-parcel patterns (the mnemonic list is split into aligned power-of-two groups, so the cost is exact);
a **budget** of 95% of the patterns (5% kept free as illegal-instruction space: a policy, not a law). The forced forms take 47,454 patterns (72.4%) on the current data, leaving
**14,805 patterns (22.6%) for the candidates**. The candidates are (form, mnemonic class) pairs generated by hand in `cat.py` (field widths, hot or full register fields,
signed or unsigned, scaled or not, per class of mnemonics `a b c d`): 1,660 of the 2,193 shorten at least one instruction. The register field layout and the position of each field are not
decided by the search: `Code._layouts` places them by fixed rules (prefix at the top, registers from bit 0 upward, the widest field last).

**Objective.** Static instruction bytes of the corpus: sum over keys of `count * 2 * parcels of the shortest chosen or forced form that fits the key`; a key that no form
reaches is credited 99 bytes (or the `cmp + bCC + lam` price for a `cbCC`), i.e. every candidate is credited with what it makes encodable. Branches are relaxed against the
distances of the layout of the previous round (`--rounds`; the fixed point is reached in two rounds, section 6).

**Algorithm (solve.py).** Greedy: repeatedly take the candidate with the largest `bytes saved / patterns^alpha` that still fits the budget, for `alpha` in {0.8, 0.9, 1.0, 1.1, 1.25}; keep the best
alpha; then `refine` rounds of local search (remove the one of the 12 chosen candidates whose loss per pattern is smallest, refill greedily, keep the change if the total fell). It takes the whole
candidate set at once (a lazy heap makes it fast). The prefixes are then assigned canonically (`Code._assign`: sort the leaves by prefix length, place each at the next multiple of
its size; exact and constructive, it succeeds whenever Kraft's sum is at most 1).

**Output.** A list of forms; `export_forms.py` + `write_hbnf.py` write them as the grammar (`spec/pdp64/pdp64.hbnf`: catalogue of forms, one `leaf-FORM-k` per leaf with its prefix bits, field
positions, mnemonic lists), and `export` runs the decodability and boundary tests (`proof.py`). The assembler, the codec and the manual tables are generated from the grammar, not
from the Python.

**Time.** `solve.solve` on the current data: 20 s (plus 4 s to read the corpus, 4 s to compute which candidate fits which key). The whole `export_forms.py` run (two grammars in the
two-grammar period, rounds, round-trip and boundary tests) took minutes.

**Exact and heuristic.** Exact: the fit of an operand to a field, the form sizes and the code-space cost of a leaf, the canonical prefix assignment, the encoder/decoder and the
layout with relaxation (verified against the real assembler on 839 of 841 files, `docs/encoding-proposal.md` 12.6). **Heuristic: the selection of the candidates**, the only combinatorial
decision, with no bound and no gap reported; its documented sensitivity is "differences under about 1% between variants are optimiser noise" (`encoding-proposal.md` section 1) and
"the retraining with the old cost model gives *worse* code than the committed grammar (+0.66%)" (12.2). The candidate set (what forms are offered) is a human restriction of the
true space; no search over it.

**Optimality gap (measured, section 5).** On the current data the study's selection is **0.90% above the optimum** in the objective it optimises (996,444 against 987,524) and
**0.97% above in the bytes of the corpus with real layout and relaxation** (965,280 against 955,956). The committed grammar is 1.0% above (965,602). The greedy loses because it
takes whole, expensive one-parcel leaves by ratio and cannot see that a set of cheap two-parcel leaves covers the same instructions for a tenth of the code space.

## 3. The problem, stated exactly

Given forced forms (code space `F`), candidates `i` with code space `c_i` (patterns), length `b_i` bytes, and instruction classes `d` (weight `w_d`, base bytes `base_d`, the set `A_d` of
candidates that could cover it), choose `S` with `F + sum c_i <= budget` minimising `sum_d w_d * min(base_d, min over i in S∩A_d of b_i)`. This is a **budgeted facility-location problem**
(NP-hard in general); the prefix code itself adds nothing hard (Kraft is the capacity, and the assignment is constructive). It is *not* a Huffman-type problem: the prefix length
of a form is fixed by its operand bits, it is not chosen from frequencies, so unconstrained Huffman, Hu-Tucker (alphabetic) and package-merge (length-limited) do not apply; the free
choice is which forms exist and with which field widths, which is what the candidates enumerate (`dw` = 4, 6, ... 22 and so on). Widths are therefore *inputs* (more candidates = a larger
space searched exactly), not unknowns solved for; adding a width costs nothing but time.

## 4. `encopt`

`tools/encopt/` (C99, libc and libm only; GNU packaging: `configure`, `Makefile` with `all install uninstall clean distclean check dist`, `DESTDIR`, `prefix`; `encopt.1`, `encopt.5`, `README`,
`COPYING`, `AUTHORS`, `NEWS`, `ChangeLog`, `INSTALL`; `check.sh`; `tests/`). Library `encopt.c`/`encopt.h`, program `main.c`, exporter `export.py` (**Python on purpose**: it reads the corpus with the study's own
reader and operand model, the only place that knows how a form fits an operand; when the compiler's corpus tool writes the same file it is not needed).

**Input** (`encopt.5`): `budget`, `form NAME forced|cand PARCELS L XBITS MNEMONICS...`, `demand STATIC DYNAMIC BASE OPS K CAND...` (format 2 of encopt 1.1; format 1 was `demand WEIGHT BASE K CAND...`; instruction classes with identical base, operations and candidate set summed:
50,000 distinct instructions become about 830 lines, 240 KB for the whole corpus), optionally `committed NAME` (the grammar in force, in catalogue order), `require`/`forbid`. The two weights are the static count and the dynamic (executed) count; the option `-O` of `encopt` says which is minimised (section 11). **Output**: `status`, objective, bound, gap, patterns, a `compare` line for each of committed / greedy / greedy-refined / encopt,
the `chosen` candidates and the `leaf` lines (form, prefix length, prefix bits, mnemonics) in assignment order; no times, so equal inputs give equal bytes.

**Proof status**: `optimal` (the search finished: optimal for the model of the input, i.e. for the candidates offered and the budget), `optimal-within-constraint-set` (the same with `-r`/`-x`
constraints), `best-found` with `lower-bound-credit` and `gap-credit` (a time or node limit stopped it).

**Algorithms, per subproblem.**

| subproblem | method | exact? |
|---|---|---|
| prefix feasibility and assignment | Kraft's inequality; canonical assignment (shortest prefix first, aligned to its size); leaves of a form = binary-aligned chunks of the mnemonic list (as `enc.Code`) | exact, constructive; reproduces the 268 leaves of `spec/pdp64/pdp64.hbnf` bit for bit |
| search-space reductions | candidates dearer than the budget dropped; **dominance** (a candidate that covers a subset, is not longer and not dearer than another is dropped; bit-set test, ties by number); instruction classes that no candidate shortens are constants; **components** (union-find over shared classes) | exact (cannot lose the optimum): 1,660 candidates become 660 in 40 independent components of at most 66 |
| one component, one budget | branch and bound; node bound = **Lagrangian relaxation of the budget** with a per-node multiplier search and **Erlenkotter's dual ascent** for the remaining uncapacitated problem; atoms that shorten nothing or no longer fit are fixed out; ends when the incumbent meets a known lower bound | exact |
| one component, all budgets | the efficient frontier (cost, value) by solving for the largest budget, then for one less than the cost found, and so on | exact |
| components together | **multiple-choice knapsack**, dynamic programme over the budget in units of one pattern, O(budget x frontier points) | exact |
| keeping the frontiers small | hulls of the dual-ascent bounds give, for each component and budget, a lower bound on any solution containing that budget; only budgets whose bound is at most a threshold are solved; the threshold grows from the root bound until the DP finds a solution at or below it (then it is optimal) or reaches the incumbent (then the incumbent is optimal) | exact (a pruning rule with proof) |
| incumbent | the study's greedy rule (five exponents) in C, a local search of the same kind, coordinate descent over components | heuristic, used only for pruning |

Everything is deterministic (stable tie-breaking: lowest candidate number; the frontier point of least cost among equal values). Floating point enters only in bounds (a bound is compared with a safety margin
of 1e-6; values are integers).

## 5. Results on the current statistics (2026-11-10)

Input: the 841-file corpus compiled with the compiler of `pcc-enc` (`-m pdp64/32`, the recipe above): 296,069 instructions, 50,399 distinct keys, distances from the layout of the committed grammar
(the first round of the design loop). All figures are the model's (`encopt` objective, or `export.py --verify`: the Python model with real layout, branch relaxation and a round trip of every instruction:
295,747 instructions encoded and decoded, 0 mismatches, 0 illegal).

| selection | forms (chosen candidates) | objective, with credit | corpus bytes, static model | corpus bytes, real layout and relaxation | vs committed |
|---|---|---|---|---|---|
| committed grammar `spec/pdp64/pdp64.hbnf` (207 forms, 268 leaves) | 140 | 996,750 | 962,892 | 965,602 | |
| the study's `solve.solve`, refine 6, on the same data (Python, 20 s) | 117 | 996,444 | 962,586 | 965,280 | -0.03% |
| the study's greedy, five exponents (C port, `compare greedy`) | | 996,490 | 962,632 | | -0.03% |
| greedy + my local search (C, `compare greedy-refined`) | | 992,022 | 958,164 | | -0.49% |
| **`encopt`, proved optimal (3.4 s on an idle core; two rounds: the same selection)** | **81** | **987,524** | **953,666** | **955,956** (148 forms, 203 leaves) | **-9,646 = -1.00%** |

Round 2 (`export.py --prev`: distances from the layout of the optimum itself) gives credit objective 987,118 for the **same selection**: the design loop is at its fixed point after two rounds.
`unencodable` 342 in every row is a property of the study's reader, not of the encoding: the 342 `set eq,r0` instructions (`set cc,rd`, form `SETF`) have their condition name read as a label by `m2.py`, so no
form fits; it is a constant of all rows and does not affect the comparison (credited 99 bytes in the objective, left out of the byte columns).

What the optimum does differently. The committed selection contains **47 leaves whose removal changes the objective by nothing** (2,374 patterns, 16% of the 14,805 the candidates may use):
leaves shadowed by a wider leaf of the same chain and length (`BR1_6/a`, `BR1_7/a`, `BR1_8/a` under `BR1_9/a`; `IMMh43/a`, `IMMh45/a` under `IMMh47/a`; `SHIh43/a` under `SHIh44/a`;
`LDHHH1/a` under `LDHHH3/a`) and two-parcel leaves covered by another (`LDBu8H/*`, `LDBu10H/a`, `CBI3_8/*` ...). The greedy takes a narrow leaf early (best ratio) and never takes it back when a
wider one arrives; the local search only swaps one leaf at a time. The optimum has none of these (0 redundant leaves), so the freed space buys other leaves: one-parcel
`LDSPh5/a`, `LEASPh5/a`, `STHHH2/a`, `CBZ1_5/a` (the committed grammar has the 4-bit variants), and the same total of 62,259 of 65,536 patterns is used. It chooses 81 candidates against 140 (203 leaves
against 268); 12,672 patterns go to one-parcel candidates (committed 12,224), 2,105 to two-parcel (2,540).

**Caveats the author should weigh.** (1) The objective is *static bytes*. `encoding-proposal.md` 12.4 showed that static size and executed bytes can disagree (pdp64/32 +3.3% fetched while -0.9% static,
`cbCC` one-parcel forms mattering in loops). `encopt` takes any weights (section 11 measures them: static, fetch and exec, with a profile of five programs rebuilt on this machine). The optimum above is the static optimum. (2) The optimum is for the candidate set and the budget offered; a wider candidate list (more widths, new classes) can lower it, never raise it.
(3) The hot-register tables, field layout rules and form lists of `cat.py` are inputs; changing mnemonics or opcodes means changing `cat.py`'s lists (`MOV7`, `ALUS`, `LDC`...) and re-exporting. (4) the 342 `set` instructions above (a reader limitation: corrected, section 10).

## 6. Speed and tests

* `encopt tests/current.encopt`: 3.4 s idle (about 7 s on a busy machine), 62,000 search nodes, proof included. The first version (one branch and bound over everything) did not finish in 5 minutes
  (gap 0.2%); the decomposition into frontiers is what made it exact and fast. `export.py`: 4 s of corpus reading plus 4 s for the fits, 25 s with `--verify`.
* `tools/encopt/check.sh` (13 s; in `tools/check-all.sh`): (a) 150 random instances (4 to 14 candidates, demands, budgets, forbid/require constraints) against brute force over all subsets: 0
  disagreements (a further 8,000 instances: 0; in 3% of them the study's greedy is suboptimal, so they are not trivial); the chosen set's prefix assignment is checked for Kraft and for overlap; (b) a hand-made instance
  with the expected output committed, cross-checked by an independent brute force in Python; (c) the whole pipeline on `tests/current.encopt` (the exported statistics, committed): the
  committed selection gets **268 leaves identical to those of `spec/pdp64/pdp64.hbnf`** (form, prefix length, prefix bits, mnemonic list; `export.py --compare-leaves`), the optimum is proved and its output is
  byte-identical to `tests/current.optimum`. If the grammar changes later, the comparison prints a note (the snapshot is stale: re-export) and does not fail the build.

## 7. Re-running it when the decisions are made

1. Settle the mnemonics (`spec/pdp64-mnemonics.hbnf`) and the forms' lists: `cat.py` still defines the forced forms and the candidate classes by mnemonic lists; a renamed or new mnemonic must be put there (until the
   compiler's corpus tool writes `demand`/`form` lines itself).
2. Compile the corpus: `tools/arch-compare` (`make WORK=... prep ccoms`, then `ccom -m pdp64/32 N.i N.s` for each file; 10 s for the 841 files on two cores).
3. `python3 tools/encopt/export.py --corpus DIR --out stats.encopt` (add `--prev result.out` for the next round; `--budget` (default 1.0: no reserve), `--lam`, `--no-cb3`; `--weights PROFILE` for a profile, section 11).
4. `encopt stats.encopt -o result.out` (`-O fetch` or `-O exec` with a profile); repeat 3-4 with `--prev result.out` until the selection stops changing (two rounds today).
5. `python3 tools/encopt/export.py --corpus DIR --verify result.out`: real layout, relaxation and round trip of every instruction with the chosen forms.
6. The result is a list of forms and `leaf` lines; turning it into the grammar is the job of `write_hbnf.py`'s output stage (it takes a scheme: `export_forms.py` builds one from `solve.solve`; to use `encopt`'s choice
   replace that call by the forms named in the `chosen` lines, as `export.py --verify` does). That wiring was not done here: the task was the optimiser and the exporter, and `spec/` must not change yet.

## 8. Questions for the author (answered 2026-11-10)

* The profile weights: the author asked for the three priorities to be shown side by side (static byte size, bytes fetched, operations executed): section 11. The profile of the six programs was rebuilt as far as it could be (five of them): section 11.
* The 5% free code space: "no reserve": section 9.
* The Python reader (`m2.py`) did not know `set cc,rd`: "good", fix it in the new tool: section 10.

## 9. No reserve (the author's answer, 2026-11-10)

"No reserve" about the 5% of code space that the study kept free. **Precisely**: the free-space policy is zero. The budget of the model is the whole first-parcel space,
**65,536 patterns minus the forced forms**; what the grammar must keep forbidden or forced is the only thing outside the choice, and nothing else is held back.

* *How the old budget was made.* `export.py` wrote `budget int(0.95 * 65536)` = 62,259 patterns; `encopt` checks `forced patterns + chosen candidates' patterns <= budget`
  (`eo_forced_patterns`, `eo_cost`). The **forced forms** are the ones the instruction set cannot do without: the rare groups, the full-width fallbacks, the four fused pairs, `RR5`
  (`cat.mk`, `variants.setup`). They are always present and always counted: 47,454 patterns (72.4%). A form takes `mnemonics * 2^(16-L)` patterns, or `2^(16-L)` if it has an
  extended sub-opcode (the whole leaf, its unassigned sub-opcodes inside it as illegal instructions). The candidates got the rest of the budget: 62,259 - 47,454 = 14,805.
* *What no reserve changes.* `export.py --budget` defaults to **1.0**: the line `budget 65536 65536`; the candidates get 65,536 - 47,454 = **18,082 patterns** (+22%). The old figure
  is `--budget 0.95`. Nothing is forbidden besides what the forced forms occupy: a first-parcel pattern that no leaf takes is an illegal instruction (the spec says so,
  `spec/README.md`), and those patterns exist only if the optimum leaves some over. `encopt` does not keep any in reserve; if the author later wants, say, one all-zero or all-ones parcel
  illegal, that is a forbidden leaf of the grammar, to be added as a forced form of its size (it costs the aligned block it sits in, at least the smallest leaf in use), not a percentage.
  The budget stays a parameter of the input (`budget B N` line, `--budget F` of the exporter).
* *The optimum.* On the statistics of the afternoon (293,448 instructions, 49,968 distinct, the corrected reader of section 10): proved optimal, objective **939,688 bytes** (static model), **-16,554 bytes =
  -1.73% against the committed grammar** (956,242), 89 candidates, 65,535 of the 65,536 patterns used (one is left: no leaf of the candidates is that small), `status optimal`, gap 0,
  61,095 search nodes, **4.5 s** (7.6 s when the machine is busy; the 95% run takes 2.3 s). The same statistics at 95%: 947,084 (-0.96%); so the reserve was worth 0.78% of the corpus.
  Real layout with branch relaxation and a round trip of every instruction (`export.py --verify`): 939,222 bytes against the committed grammar's 956,216 (-1.78%), 156 forms, 212 leaves,
  293,455 instructions encoded and decoded, 0 mismatches, 0 illegal, 0 unencodable (7 `cbCC` expanded to `cmp`+`bCC`; the committed grammar has 13).
  On the statistics of the first run (296,069 instructions, the reader's bug still in, 342 `set` counted as unencodable) the same budget gave 980,060 credit = 946,202 bytes against 962,892 (-1.73%), proved in 8.4 s.

## 10. The corpus reader, corrected

`tools/encopt/corpusfix.py` wraps the study's reader for the exporter; the history scripts are not edited (`docs/codegen-data/encoding/m2.py` still has the bug, by design). `m2.kind()` calls a word that is
no register, number or memory form a label, so the operand of `set eq,r0` was a pc-relative one and `SETF` (condition as a 4-bit number, register) did not fit. The assembler's operand kinds
(`spec/pdp64-asm.hbnf`) show that exactly two statement forms take a word of their own: `condinsn = mn-cond ccw "," operand ...` (`set` is the only `mn-cond`; `ccw` is a condition `ne eq pl mi vc vs cc cs ge lt gt le hi los`, the aliases `hs lo`, or `al`) and
`srinsn = mn-sysreg ...` (`mfsr rd, sreg`, `mtsr sreg, rs`: the system register by name). The conditions of `trapcc.CC` and of the `cbCC` family are in the mnemonic (no operand), `cbCC` has a label as its last operand and
no condition word, no cmov-like form exists, and nothing else takes a word. So the same bug had a second member, the system-register moves (the compiler emits none: 0 in the corpus), and nothing else.
The wrapper replaces the word by its number as an immediate (the `cc` numbers of `spec/pdp64-mnemonics.hbnf`: `ne` 1, `eq` 2 ... `los` 14, `al` 0; the `sysreg` numbers), which is what `SETF`'s field takes.

* Counts: **337** `set` instructions in the corpus of the afternoon (`set eq,r0` is 57 of them, `set ne,r0` 89) read as having a label before; 342 in the first compile. The unencodable count of every selection goes **from 350 to 13**: the 13 are `cbCC` with two registers
  whose distance no `cbCC` form of the committed grammar reaches (the assembler expands them to `cmp`+`bCC`; priced by the fallback), not reader errors; the optimum encodes them all except 7 expanded.
* The statistics changed: 49,968 distinct instructions (14 more: the `set` conditions and registers are now distinct instructions), the objective of every selection includes the 337 `set` as 4 bytes (`SETF` is a forced two-parcel form).
* Test: `tools/encopt/tests/test_reader.py` (in `check.sh`) reads `tests/corpus/words.s` with the study's reader (the 10 word instructions have a label operand, no form: the bug is demonstrated) and with the corrected one (numbers, all 10 encodable by the forced forms, the numbers those
  of the grammar); the weights-file notation is tested with it, and `tests/profile.weights` is read in full.

## 11. The three priorities

The author's words: "show the options for static, fetch, and live priorities: static byte size, bytes fetched, and actual operations executed". `encopt -O static|fetch|exec`:

| objective | weight of an instruction class | what each instruction costs | notes |
|---|---|---|---|
| `static` | static count (the corpus) | its bytes | the earlier objective; an instruction that is never executed counts as much as a hot one |
| `fetch` | dynamic count (the profile) | its bytes | bytes fetched when the programs run: each distinct instruction weighted by its execution count times its size; an instruction the profile never ran weighs 0, so the optimum encodes the profile and leaves the rest to the forced forms |
| `exec` | dynamic count | `k * operations + bytes`, `k` = 4096 (`-k`) | operations executed. An instruction is one operation; a `cbCC` that no form reaches is two (`cmp` + `bCC`); an instruction that nothing encodes counts 99. The operations come first, the bytes fetched break ties (`k` is far above any instruction's size) |

**What `exec` can and cannot be.** Operations executed is a number that the encoding changes only through the two cases above: an encoding does not execute fewer instructions by being denser. The fused pairs, the autoincrement forms and the rest that change the instruction
count are decisions of the compiler and of the forced forms, fixed here. If the objective were operations alone, almost every selection would tie; a pure "parcels fetched per executed operation" is bytes fetched divided by a constant and has the optimum of `fetch`. So `exec` is defined as above, lexicographic in effect:
first the operations (so that any `cbCC` that the profile runs gets a reaching form), then the bytes fetched. The measured result (below) is that on this profile the committed grammar already reaches every executed `cbCC`, so the operations are the same in all selections but the `fetch` optimum (+42 operations of 135 million), and `exec`
is `fetch` with that guarantee.

**The profile.** `tools/encopt/profile.py` runs programs under `sim64 -P` (the existing profile: executed instructions per pc; nothing in `sim64/` or `common/` was changed or needed) and `encdis -k` (a mode of `tools/encdis.c`, which decodes with the codec of the repository the instruction at every counted pc)
turns it into a weights file (`encopt.5`, "weight dynamic COUNT instruction"); `export.py --weights` joins it with the corpus statistics by the distinct-instruction key, adding the keys the corpus does not have with the static count 0. The totals of the weights equal the instructions that `sim64 -P` reports
(checked in `profile.py`). The programs of the earlier study's profile (`dynkeys.pkl`: lua lz4 zlib bs_hash bs_sym bs_ec) were looked for: the sources are in `~/claude/corpora` (lz4, zlib, bearssl, lua-5.4.7), the earlier mains and stand-in libc are not on this machine. **I rebuilt five**, with new mains and a small stand-in libc (`tools/encopt/programs/`,
`make-profile.sh`; compiled with the repository's own `build/pcc/ccom` from the sources preprocessed by `tools/arch-compare/prep.py`), and each checked against the host: the checksum of the output under `sim64` equals the one of the same main compiled with gcc on the host (lz4 28819839, zlib 293329, bs_hash 725528908380846452, bs_sym 3567240991110834917, bs_ec 2843755488877783253).
**Lua was not built**: it needs a real C library (setjmp/longjmp, strtod, printf, stdio) that does not exist for the pdp64 yet. The five are *not* the earlier programs: different mains (lz4 and zlib compress and decompress a pseudo-random text-like buffer; bs_hash is MD5, SHA-1, SHA-256, SHA-512 and HMAC; bs_sym AES-128 CBC and CTR, ChaCha20; bs_ec scalar multiplication on P-256 and Curve25519), different inputs, different libc.
Executed instructions: lz4 12,395,207; zlib 27,911,218; bs_hash 11,630,870; bs_sym 30,805,202; bs_ec 52,435,232; total **135,177,729** (5,069 distinct instructions; 402.5 million bytes fetched under the committed grammar, 2.98 per instruction). The weights file is `tools/encopt/tests/profile.weights`.

**The table** (no reserve; statistics of the afternoon, 293,448 static instructions; profile of the five programs; every figure the model's, measured under each selection with `encopt`'s `metrics` lines; each optimum proved, gap 0; times on a busy machine):

| selection | static: corpus bytes | fetch: bytes fetched | exec: operations executed | candidates chosen | proof and time |
|---|---|---|---|---|---|
| committed grammar (207 forms, 268 leaves) | 956,242 | 402,546,512 | 135,177,729 | 140 | |
| **static optimum** (`-O static`) | **939,688 (-1.73%)** | 389,433,134 (-3.26%) | 135,177,729 (0.00%) | 89 | optimal, 7.6 s |
| **fetch optimum** (`-O fetch`) | 1,007,216 (+5.33%) | **385,350,750 (-4.27%)** | 135,177,771 (+0.00003%) | 58 | optimal, 3.8 s |
| **exec optimum** (`-O exec`, k = 4096) | 1,006,762 (+5.28%) | 385,378,982 (-4.26%) | **135,177,729 (0.00%)** | 58 | optimal, 3.5 s |

(For reference, the study's greedy rule and its local search on the same data: static objective 949,036 and 945,438 bytes; fetch objective 387,877,970 and 385,975,454 bytes.) Real layout and relaxation (`export.py --verify`, static bytes of the 841 files; round trip of every instruction: 0 mismatches, 0 illegal, 0 unencodable): committed 956,216; static
optimum 939,222; fetch optimum 1,007,102 (608 `cbCC` expanded: the corpus has many that the profile never runs); exec optimum 1,007,260 (33 expanded).

How the priorities pull against one another: **the static optimum is also better for fetching** (-3.3%), and takes the whole of the static gain. Optimising for fetch buys a further -1.0% of fetched bytes (385.4 against 389.4 million) and pays +7.2% in static size against the static optimum (+5.3% against the committed grammar): it spends the code space on the 5,069 instructions
the programs run and leaves the rest of the corpus to the long forms. Operations executed do not distinguish the encodings but for 42 executions of a `cbCC` in the fetch optimum.

**Caveats, important.**
1. *The fetch and exec optima are fitted to the profile and do not carry over.* `tools/encopt/leave-one-out.py` trains the fetch optimum on four programs and measures the fifth (committed grammar / seen = trained on all five / unseen = trained on the other four): bs_ec 167,120,846 / -8.31% / **+0.12%**; bs_hash 33,771,408 / -0.73% / **+0.97%**; bs_sym 82,994,740 / -2.68% / **+1.13%**;
   lz4 36,461,800 / -0.70% / **+5.52%**; zlib 82,197,718 / -0.70% / **+8.45%** (bytes fetched). On a program it has not seen, the fetch optimum is worse than the committed grammar. The -4.3% above is the in-sample figure; most of it is bs_ec (two fifths of the instructions, -8.3% in sample, the only program that gains much). The static optimum is trained on the 841-file corpus, which contains these libraries' sources, so it has the same in-sample flatter (lz4, zlib and BearSSL are in the corpus), but the corpus is large and not tuned to one run.
   A priority of fetch needs a profile of many programs, and a blend with the static weight (a re-export with `weight static` lines) is the usual cure; I did not tune one.
2. The profile is five programs of two kinds of code (compression and constant-time cryptography), 135 million instructions, mains written for this study, a stand-in libc, no Lua; the earlier six-program profile was not recoverable. The operand values of a profile instruction are the linker's (pc-relative distance, absolute address) while the corpus's are the assembler's: the key is the same notation, the values differ, so a few instructions appear in both with different keys.
3. The encoding that is optimal for fetching is not necessarily fast: no timing model is in the objective (one fetch of 4 bytes against two of 2, an instruction cache, the decode width) and `exec` counts operations, not cycles.
4. All of it is for the candidate set offered (the hand-made classes of `cat.py`), the hot-register tables of the grammar, the layout rules of `Code._layouts`, and the distances of the corpus from the committed layout (the first round; section 5 showed the fixed point is reached in two rounds for the static objective, not re-checked for the others).

A smaller profile, the 107 C programs of the repository's tests (`tests/c`, `tests/c-new`, the toolchain's `a64tests`; 6.6 million executed instructions, 5,806 distinct instructions), gives the pattern in the extreme: committed 17,380,572 bytes fetched, the static optimum 17,376,344 (-0.02%), the fetch optimum **14,952,004 (-14.0%)** at static +8.4%: with so few distinct instructions the optimum simply encodes each in its shortest form, which says nothing about other programs.
It was run as a check of the collector (`profile.py --tests DIR ...`); the numbers above are the five programs.

**Re-running.** `sh tools/encopt/programs/make-profile.sh PREP profile.weights` (PREP: `tools/arch-compare/prep.py aarch64` output), `python3 tools/encopt/export.py --corpus DIR --weights profile.weights --out stats.encopt`, `encopt -O static|fetch|exec stats.encopt`;
`tools/encopt/tests/current.encopt` is that input as exported today and `tests/current.{optimum,fetch,exec}` the three results (`check.sh` re-runs them and compares bytes).
