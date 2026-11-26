# The tag check, benchmarked

The question: a pointer whose low three bits hold a type tag used to be checked for free, because an access through a mis-tagged pointer was a misaligned
access and faulted. A plain access now works at any address, so the check is explicit. What does that cost, and is there something better?

`bench.py` writes each workload as assembly for each scheme, runs it on `build/sim64` with three timing models (`--timing`, [timing-model.md](../../../timing-model.md);
ideal memory, bimodal predictor) and reports one iteration as the difference of a run of 2000 and a run of 1000 (start-up and exit drop out). `results.txt` is the raw output
(`python3 docs/encoding-work/bench/tagcheck/bench.py build > results.txt`). The models: `scalar` one instruction a cycle, fetch 8 bytes; `dual` two a cycle, fetch 16, a branch
target buffer; `wide` one a cycle with a 64-byte fetch (results close to `scalar`; in the raw file).

## The schemes

* **a, old**: no check instruction; the access at `k-T(Rn)` faults when the tag is not `T`. Modelled by counting: the hot path is the access alone (the old executor is not
  rebuilt: a faulting access costs one precise fault and nothing else). Its failing path is a trap, at least the 20 cycles that the model charges `trap` (`sys=20`) plus the handler.
* **b, explicit**: `BNTAG Rn, #T, slow` (4 bytes, no flag, a not-taken branch) and then the access at `k-T(Rn)`. This is the shortest correct sequence in the instruction set.
  Variants: *naive* a check before every access; *once* one check for all the accesses through the same pointer; *merged* the check is also the loop's test (`BTAG` loops while the
  `cdr` is a cons; the fall-through tests for nil), so nothing is added.
* **c, alternatives**: *trapcheck* `AND #7` then `CTNE` (existing words, a copy of the pointer is needed); *test* `BIT #7` and `BNE`; *hoisted* the check before a loop in which the pointer does not change.
* **d, a one-parcel `CTAG Rn, #T`** (trap if the low three bits differ; two bytes: an 8-bit prefix, 5 bits of register, 3 of tag): not built; `CTEQ Rn` (also two bytes, one issue slot, no branch, never traps on a non-zero pointer) stands in for it, so the instruction count, bytes and cycles are those of the proposed word.
* **e, an alignment-trap mode bit** (the x86 AC flag, or a page attribute): its hot path is that of scheme a; not built (below).

## The table (per iteration)

Instructions and bytes are the same in every model; cycles are `scalar` / `dual`.

| workload (iteration) | scheme | insns | bytes | cycles (scalar / dual) |
|---|---|---|---|---|
| list sum (car + cdr, 2 accesses) | a old (also e) | 4 | 18 | 8 / 6 |
| | b naive (2 checks) | 6 | 26 | 10 / 8 |
| | b once (1 check per cell) | 5 | 22 | 9 / 7 |
| | b merged (check = nil test) | 4 | 18 | 8 / 6 |
| car of a pointer from an array (1 access) | a old (also e) | 4 | 16 | 8 / 7 |
| | b `BNTAG` | 5 | 20 | 9 / 7 |
| | c `AND`+`CTNE` | 7 | 24 | 11 / 9 |
| | d `CTAG` (stand-in) | 5 | 18 | 9 / 7 |
| vector-ref with a bounds check in a loop | a old (also e) | 7 | 24 | 11 / 8 |
| | b `BNTAG` each time | 8 | 28 | 12 / 9 |
| | c hoisted out of the loop | 7 | 24 | 11 / 8 |
| | d `CTAG` (stand-in) | 8 | 26 | 12 / 9 |
| method call on a tagged object (header, `CALLI`, field) | a old (also e) | 8 | 34 | 15 / 14 |
| | b `BNTAG` at the call | 9 | 38 | 16 / 14 |
| add of two tagged fixnums (check both, `ADDV`) | a = b (the alignment fault cannot test an operand) | 8 | 26 | 10 / 7 |
| add of a tagged fixnum and a constant | b `BNTAG` | 5 | 18 | 7 / 5 |
| | c the two-operand add checked with `BIT #7` + `BNE` (against 8 insns for `BIS` + `BNTAG`) | 9 | 28 | 11 / 8 |
| the failing path (every check fails; a two-instruction stub repairs the tag) | b `BNTAG` taken | 7 | 26 | 13 / 8 (against 9 / 7 when it passes) |
| the same | a old: one precise fault | | | at least 20 plus the handler |

## What it says

* One unshared check costs one instruction, four bytes and, on a one-issue in-order core, one cycle (8 to 9 for the car, 11 to 12 for the vector-ref, 15 to 16 for the call:
  7 to 12% of the loop); on a two-issue core with a branch target buffer it is often free (car 7 / 7, call 14 / 14) and at most one cycle (vector-ref 8 / 9).
* The compiler (or the programmer of a Lisp or of a dynamic runtime) takes most of it back: one check for all the accesses through a pointer (a cons read for `car` and `cdr`: 4 + 1 instructions
  against 4, not 4 + 2); a check hoisted out of a loop (vector-ref: exactly the old cost); and `BTAG` as the loop test of a list walk (exactly the old cost, because the old loop also had
  to test for nil: the cdr's tag is tested instead of its value). These are the cases of a dynamic runtime that matter, and in them the check is free.
* The fixnum add and the check of an operand of arithmetic were never free: the alignment fault does not see an arithmetic operand, so a dynamic runtime already paid `BIS`+`BNTAG` (two instructions)
  for it, and the tag-0 fixnum add is the same code under every scheme.
* The failing path is faster than before: a mis-tagged pointer takes a branch to a stub (4 cycles scalar, 1 dual) instead of a precise fault and its handler (at least 20 model cycles). In a
  runtime where a failing check is a normal case (a generic add that falls to a bignum, a dispatch on the type) that is the whole point; it is rare only for `car`.
* `AND`+`CTNE` is worse than `BNTAG` (7 against 5 instructions): the mask destroys a register and needs a copy. `BIT #7` + `BNE` is worse than `BIS` + `BNTAG`.
* A two-byte `CTAG` would save 2 bytes a check against `BNTAG` (the check 4 bytes to 2), and the same issue slot; no cycle on this model (the branch unit is not the bottleneck at one or two issue slots). Worth an opcode only
  if the owner values 2 bytes per unshared check; it needs an 8-bit prefix in the first parcel (0.4% of the patterns; 12.66% are free) and the `__bug_table` record of the check family.

## The choice

**Scheme b with the compiler's techniques (once, merged, hoisted); `BNTAG` followed by the access at `k-T`.** It costs no opcode, keeps the one rule that a plain access works at any address (no mode
that software can set and so mis-set; the C library's `memcpy` on an unaligned buffer works in a Lisp process), makes the failing path a branch, and costs at the most one cycle on a one-issue core
and nothing in the loops that count.

**The alignment-trap bit (e) is not built.** It would win one instruction and 4 bytes on the unshared access and nothing elsewhere (the shared, merged and hoisted cases are already free), at the cost
of an architectural mode: a PSW bit (the x86 AC) would make every plain access in the process fault when unaligned, including the C library's, which is exactly what the merge of `MOVU` into the plain
move removed; a per-page attribute (a PTE bit that makes an 8-byte access to an address with a non-zero low three bits fault, set by the kernel for a tagged heap) is a defined behaviour that user software cannot mis-set,
costs about ten gates in the address check (three address bits, the size, one attribute bit, an OR and an AND) beside the translation, one PTE bit, one cause and the kernel's interface for setting it, and fits the one-binary rule; but the margin
(0 to 1 cycle on the unshared access; zero on the merged and hoisted ones, which a runtime that cares uses) is not clear, and it gives the same instruction two meanings by page. Proposed, not built.

## Files

`bench.py` (the generator and runner), `results.txt` (the raw table, all three models, and the failing path).
