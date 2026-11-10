# The sim64 timing model

[← sim64](sim64.md) · [pdp64 index](../README.md)

A trace-driven, in-order timing model inside `sim64`. The program runs functionally as always; for every executed instruction the model is told its
address, length, the registers and flags it read and wrote (in order), its memory accesses, and where control went next, and it computes how many cycles
a small in-order core would need. It exists to compare **implementations** (different widths and latencies, instruction bytes against the fetch width, the length decode) and
**compiler options** (instruction counts and sizes) by estimated cycles, and to say when a program is **fetch-bound** (the core waits for instruction
bytes) and when it is **execute-bound** (it waits for operands, loads, multiply/divide, branch resolution).

It is a toy: no real implementation is modelled (section 7). Everything below is the model's definition; every parameter is exposed.

## 1. Use

```
build/sim64 [--timing=SPEC]... [--timing-out=FILE] [--timing-pc=FILE] [-P profile] image.x
build/sim64 --timing-help                       # every parameter with its default
tools/timing.py [-p PRESET | -c SPEC]... [-s KEY=V1,V2,..]... [--base SPEC] [--cols ...] [--csv] image.x...
tools/check-timing.sh                           # the validation microbenchmarks (also part of tools/check-all.sh)
```

`SPEC` is `name=LABEL,key=value,...` (comma separated; later keys override earlier). `--timing` may be repeated (up to 32): **one run of the program
feeds all the models at once**, each with its own state, so a sweep costs one functional run. The result is one line per model, on standard error (or appended
to `--timing-out`):

```
tm name=LABEL prog=image.x enc=pdp64 insns=... bytes=... cycles=... ipc=... bpc=... cpi=... active=... fe_start=... fe_seq=... fe_imiss=... fe_taken=...
   fe_misp=... fe_dec=... fe_queue=... ex_alu=... ex_load=... ex_dmiss=... ex_mul=... ex_div=... ex_fp=... ex_block=... ex_struct=... occ_blk=... occ_sys=... occ_mem=...
   fe=... ex=... branches=... cond=... taken=... mispred=... rets=... retmiss=... ind=... indmiss=... btbhit=... fused=... [iacc= imiss=] [dacc= dmiss=]
```

`--timing-pc=FILE` writes, for every model, the per-pc cycles to `FILE.NAME` (`pc count cycles fe_idle ex_idle`, one line per pc that ran; cycles are the issue-gap cycles charged to the instruction), for finding tight loops.
`tools/timing.py` runs the models over images and prints a table (columns `image enc name insns bytes cycles cpi bpc fe% ex% misp%`, others with
`--cols`); `-p` names presets (`--presets`), `-s W=2,4,8,16` sweeps a parameter, `--base` adds parameters to every set. The encoding is the one in the
ELF `e_flags` (or `-m`). Not usable with `-K`.

## 2. The machine

```
 fetch unit            prefetch buffer       decode          queue          issue                 execute
 W bytes/cycle   -->   N bytes, back   -->   iw instrs/ -->  dq instrs  --> iw instrs/cycle  --> latencies by class,
 aligned window        pressure              cycle, decw     (decode can     scoreboard, mp mem    D-cache, divider,
 I-cache (opt.)        (flushed on a         bytes/cycle,    run ahead of    accesses/cycle,       branch resolution
 BTB (opt.)            misprediction)        +ldec cycles    issue)          1 branch/cycle
```

* **Fetch.** One aligned window of `W` bytes is requested per cycle, in order along the dynamic path. A request made in cycle *q* delivers its bytes into the buffer in cycle
  *q + fl* (a cache hit). The next window is not requested until the buffer has room: window *k* waits until every instruction up to `N` bytes before its end has been decoded (back
  pressure: a stalled back end stops the fetch unit). `N` is raised to `W + 9` (an instruction is at most 10 bytes, so a smaller buffer could deadlock). An instruction whose bytes
  lie in several windows is ready when the last of them has arrived (so a long instruction costs extra cycles when `W` is small, and nothing when the next window is already buffered).
  After a taken branch the first window is the one that holds the target; the bytes before the target in it are not used.
* **I-cache** (`ic=1`): size/line/ways/LRU, one lookup per window request, miss penalty `imiss`; a miss blocks the fetch unit until the line is there (`ipf=1`: next-line prefetch). `ic=0`: every fetch hits.
* **Decode.** `iw` instructions and `decw` bytes per cycle (an instruction longer than `decw` takes several cycles). It happens `ldec` cycles after the bytes arrive: `ldec` is the **length-decode latency**
  (the length of an instruction is a table of its first parcel; the default is 1, `ldec=N` sets N; `ldec0` and `ldecp`, which gave the earlier iterations different defaults, are gone).
  Decode takes the bytes out of the buffer (this is what frees space for the fetch unit). Between decode and issue are `dl` cycles and a queue: decode may run at most `dq` instructions ahead of issue.
* **Issue** is in order. An instruction issues when it has been decoded, its source registers (and flags) are ready, the registers it writes are free (a write after write waits for the older result),
  an issue slot is free (`iw` per cycle), memory ports are free (`mp` accesses per cycle; an instruction with more accesses than ports, `pushm`, `popm`, `popmret`, holds the stage for the extra cycles)
  and at most one branch per cycle. A divide waits for the (non-pipelined) divider.
* **Execute latencies** (issue to use): ALU `alu` (1); a load `ld` (3) on a hit, `ld + dmiss` on a D-cache miss (`dc=1`; a second access to a line still being filled waits for the fill); a pure move or load result: `movq rs,rd` 1, a loaded value
  at load latency; `add rd,mem` is load latency + `alu`; multiply `mul` (3, pipelined); divide `div` (20, not pipelined); FP add/convert `fadd` (4), multiply and fused multiply-add `fmul` (4), divide and square root `fdiv` (20, not pipelined).
  Stores cost an issue slot and a memory port and have no result. The address update of `(rn)+`, `-(rn)`, push and pop (and the stack pointer in `call`/`ret`) takes `alu`, not the load latency.
  **A fused instruction is one decode and one issue slot**; the model walks its register and memory accesses in order, so a dependence inside it (the second half of `mov2` reads what the first wrote) adds the
  dependent latencies, and independent halves (`movcall`: the move and the call; `popret`: the pop and the return) overlap.
  `mcpy`, `mset`... are **count-based**: `blkb + ceil(bytes / blkw)` cycles, holding the pipeline (the D-cache sees the accessed lines, no miss penalty is charged). `trap`/`halt` hold it `sys` cycles.
* **Branches.** Conditional branches (`bCC cbCC sob btag bntag`) are predicted by `pred`: `none` (always not taken), `static` (backward taken), `bimodal` (table of 2-bit counters, `bht` entries, first encounter static), `perfect`, `taken`.
  Direct `br`, `jmp`, `call` and `movcall` are always predicted correctly (the target is in the instruction). Indirect `jmp`, `calli`, `jmpi`, `jtag` use a table of the last target (`ibtb` entries);
  `ret`, `popret`, `popmret` a return stack of `ras` entries (`ras=0`: the indirect table). A correctly predicted taken transfer redirects the fetch unit `tkb` cycles after the branch is **decoded**
  (request of the target window in cycle *d + tkb*), or with no bubble if it hits the BTB (`btb` entries, direct mapped, filled by taken transfers): the next request follows the branch window's request. A misprediction
  redirects when the branch resolves: `brlat` cycles after it issues (for a `ret` through the stack, after the loaded address arrives) plus `mpx`; the wrong path is not fetched or charged. All the penalties are therefore the
  *length of the pipeline* (`fl + ldec + dl + brlat`), not constants: a longer length decode makes every misprediction and every taken-branch bubble longer.
* **Cycles** = (the cycle of the last issue) + 1; the exit `trap #0` is the last instruction (with `sys=1` it adds nothing).

## 3. Where the cycles go

Every cycle in which nothing issues is charged to one cause, following the instruction that is waiting at the head:

* **fetch-wait** (the instruction has not come through decode yet) – `fe_start` (program start), `fe_seq` (waiting for the next window: bandwidth/latency), `fe_imiss` (I-cache miss), `fe_taken` (the bubble after a predicted-taken transfer), `fe_misp`
  (refill after a misprediction: from the cycle after the branch issues until the target is ready), `fe_dec` (decode bandwidth), `fe_queue` (counted as execute-wait);
* **execute-wait** (it is decoded but its operands or a unit are not ready) – by the producer of the operand: `ex_alu`, `ex_load`, `ex_dmiss`, `ex_mul`, `ex_div`, `ex_fp`, `ex_block`, `ex_struct` (divider busy), and the extra
  holding cycles of multi-cycle instructions `occ_blk`, `occ_sys`, `occ_mem`.

`active` = cycles in which at least one instruction issued. `cycles = active + Σfe + Σex + Σocc` (checked by the tool). **Fetch-bound** = the share of fetch-wait; **execute-bound** = the share of execute-wait. The misprediction recovery
is reported in its own column (`misp%`, inside `fe%`) because it is partly the branch resolving (execution) and partly the front end refilling (fetch), and the refill part grows with `ldec`.
`bpc` is bytes of executed instructions per cycle: "the bytes per cycle the code consumes at this speed"; the fetch width needed is read from a run with a wide fetch (`W=64`).

## 4. Parameters

`build/sim64 --timing-help` prints the table below (defaults). Presets of `tools/timing.py`: `scalar` (iw 1, W 8, N 32), `dual` (iw 2, W 16, N 48, dq 6, BTB 64), `scalar-c`, `dual-c` (the same with 16 KB I- and D-caches),
`w2` (W 2), `wide` (W 64, BTB 4096, tkb 0: never fetch-bound).

| | default | |
|---|---|---|
| `iw` `decw` `dq` | 1 16 4 | issue/decode width, decode bytes per cycle, decode-to-issue queue |
| `W` `N` `fl` `dl` | 8 32 1 1 | fetch width, prefetch buffer, fetch latency, decode-to-issue latency |
| `ldec` | 1 | length-decode latency (`ldec=N`) |
| `pred` `bht` `btb` `tkb` `ras` `ibtb` `brlat` `mpx` | bimodal 2048 0 1 16 64 1 0 | branches |
| `ic` `isz` `iline` `iways` `imiss` `ipf` | 0 16384 32 2 20 0 | I-cache |
| `dc` `dsz` `dline` `dways` `dmiss` | 0 16384 32 2 20 | D-cache |
| `alu` `ld` `mul` `div` `fadd` `fmul` `fdiv` `mp` `blkb` `blkw` `sys` | 1 3 3 20 4 4 20 1 2 8 20 | execution |

## 5. Validation

`tools/check-timing.sh` (`tests/timing/check_timing.py`): hand-derived cycle counts, exact, for a dependent chain of adds (ALU latency 1, 2, 3, 5), independent adds at issue width 1 and 2, a load-use chain
(load latency 2, 3, 4, 6), a multiply chain, a non-pipelined divider, a loop with a predicted-taken branch for several fetch/decode latencies, the same loop with every taken branch mispredicted (several
resolution latencies, extra penalties, length-decode latencies), a straight-line stream that is limited by fetch for `W` = 2, 4, 8, 16 (expected cycles computed from the real instruction addresses), and a two-instruction loop at
issue width 2 with and without a BTB (one iteration per cycle). (44 checks). What this validates is that the code implements the stated pipeline; it cannot validate that the pipeline resembles hardware (section 7).

## 6. How it is built

`common/timing.c` is the model; `common/timing.h` the record of an instruction. The register accesses come from `build/pdp64exec_tm.c`, which `tools/mk-exec-tm.py` generates from the shared `common/pdp64exec.c` and `pdp64exec_enc.inc`
(left unchanged for QEMU): every `r[..]`, flag and `dp` access is replaced by a call that logs it and returns the same value, so the semantics are identical (all of `tools/check-sim64.sh` runs through the generated copy). The classes
(ALU, move, multiply...) come from the mnemonic, and for the instructions run through `exec_fmt` from the decoded fields. The memory accesses are logged by the host hooks of `sim64`.

## 7. Assumptions and limits (errata-style)

1. **An in-order toy.** One pipeline, no real core is implemented. The numbers are for comparing variants of the same program on the same assumed machine, not predictions of any silicon. Absolute cycles depend on the
   defaults (`ld` 3, `div` 20, `tkb` 1, ...), which are plausible but arbitrary.
2. No wrong-path fetch or execution; no I-cache or BTB pollution by it. A mispredicted branch costs its resolution plus the refill; nothing else is disturbed.
3. No memory dependences or store forwarding: a load after a store to the same address costs a normal load. No write buffer limit; a store never stalls (a store miss allocates, no penalty). Block instructions touch the D-cache
   but pay no miss penalty. Unaligned `movu*` cost as ordinary accesses.
4. Fused instructions are one decode/issue slot and use the sequential walk of their accesses for latency; real hardware may crack them into micro-operations (the model's answer is the optimistic one).
5. The register reads of the shared executor are logged where it reads them: a few rare instructions read an operand field they do not use (FP and bit-manipulation escapes), which can add a spurious dependence. The common
   instructions are exact.
6. The L2/memory system is a single penalty; no TLB; no interrupts; `trap` is a flat cost; system calls are free (the stand-in OS runs on the host).
7. **Out-of-order is not modelled.** With out-of-order issue the back end tolerates load latency and operand waits, so the execute-wait share falls and the program becomes limited by fetch/decode width and by
   mispredictions: the denser encodings' advantage (bytes) and their length-decode penalty (refill) both matter more, and the benefit of fusing (fewer slots) shows less on latency chains, more on width. The numbers here
   for fetch-bound versus execute-bound should be read as the in-order case.
