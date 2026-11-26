# sim64: the reference emulator

[← pdp64 index](../README.md)

`sim64 [-t] [-r] [-k | -K] [-i N:LEVEL:VECTOR] [-x LO:HI] [-V] [-S bytes] [--vport=n] [--vcommit=n] [--vrow=n] [--latency=fpga|asic|file] [--vpipe=n] [--vmemlat=n] [--vmix] [-n steps] [-P file] [--timing=SPEC]... program` loads an ELF executable written by `ld64`, decodes each instruction with the decoder generated from
the table codec (`common/pdp64enc.c`, with the tables generated from `spec/pdp64/pdp64.hbnf`) and runs it in user mode. It is the executable statement of what each instruction does (of the reference implementation: what it does not implement yet is listed below and in [implementation-status.md](implementation-status.md)), and the instruction numbers are the generated names in `build/pdp64-consts.h`, so nothing is typed twice.

| option | meaning |
|---|---|
| `-t` | one line per instruction on standard error: address and the parcels |
| `-r` | print the registers, `fpsr` and the status word when the program stops |
| `-k` | run in kernel mode: the privileged `mfsr` and `mtsr` are allowed (default: user mode, where they fault as "privileged instruction in user mode") |
| `-n N` | stop after N instructions (default 200 million) |
| `-K` | kernel mode with exceptions delivered through the vectors (an unimplemented word raises the illegal-instruction exception) |
| `-i N:LEVEL:VECTOR` | raise interrupt LEVEL (1 to 7) at VECTOR after N instructions |
| `-x LO:HI` | (a test facility, with `-K`) the pages of `[LO, HI)` (page aligned) are mapped and zero filled, but the first access to each page faults once, a load fault (vector 7) or a store fault (vector 8), and then succeeds: the stand-in for "the handler maps the page" in a machine without an MMU; `tests/sim/vec-restart.S` uses it (on QEMU the same program uses real page tables) |
| `-V` | print the vector counters to standard error at exit: blocks run, strips run, vector instructions executed (one for each strip), elements they worked on; `-P` also writes them as a `#vec` line; and a second line with the cycle model (below) |
| `-S BYTES` | the strip of the vector unit: 16, 32 (default) or 64 bytes; 8 is **outside the architecture** (the least strip is 16 bytes: [vec-isa.md](encoding-work/vec-isa.md) section 8) and is kept for the cycle study, with a warning on standard error (the environment variable `PDP64_VSTRIP` is the default of `-S`, for scripts such as `llvm/check.sh` that give no options). The strip is the implementation's choice: VL is the strip over the widest lane type of the block, so the number of strips and the cycle model change, and **a program's results do not** (errata 173 to 175; a block with accumulators or a `vfmab` has a strip of 16 bytes at every `-S`) |
| `--vrow=CYCLES` | the cost of the row advance of a 2D block (`vec2`, errata 176, `docs/encoding-work/vec-2d.md`), added in both models between the last strip of a row and the first of the next (default 1: an assumption; 0 and 2 are the sensitivities); each `vskip` and the `vend` take one decode slot once per block; with a `vec2` block `-V` prints a line `vec2 blocks, rows, vskips, row-cost` |
| `--vport=BYTES`, `--vcommit=CYCLES` | the parameters of the cycle model of the vec blocks (below): the memory port in bytes a cycle (default 16), the commit cost of a strip (default 1) |
| `--latency=fpga\|asic\|FILE`, `--vpipe=N`, `--vmemlat=N`, `--vmix` | the parameters of the second cycle model (below): the latency table (the built-in `fpga`, the default, or `asic`, or a text file of lines `class latency interval`; the files `sim64/latency-fpga.txt` and `latency-asic.txt` are the built-in tables), the strips in flight (1 to 16, default 1: no overlap), the memory's load-to-use latency (default 4 cycles); `--vmix` adds a line with the number of vector instructions run in each class |
| `-P file` | profile: count the executed instructions per pc and write them at exit (see below) |
| `--timing=SPEC` | a cycle estimate from a trace-driven in-order timing model (repeatable); `--timing-out=FILE`, `--timing-pc=FILE`, `--timing-help`: [timing-model.md](timing-model.md) |

## The strip and the cycle model of the vec blocks

The vec block runs a region strip by strip. The strip is `-S` bytes (default 32; 16 and 64 allowed, 8 outside the architecture) and VL, the elements of a strip, is the strip over the widest lane type that the block names; the last strip is shorter. The strip is a property of the implementation; the registers v0..v15 are 64 bytes of storage whatever the strip. **The program cannot see the strip** (errata 173 to 175, `vec-isa.md` section 8): there is no `vlen`, a floating-point sum is in a canonical order of 16-byte chunks, a block with accumulators or a `vfmab` has a strip of exactly 16 bytes (and, after a `vfin`, an epilogue that runs once after the last strip), and a fault reports EPC, EVA and ECAUSE exactly (the accesses of a strip are checked in the order of the elements before it runs) while the pointers and the scalar result a handler reads are opaque.

`-V` prints, besides the counters, a line `vec model strip S port P commit C: scalar N vector V (compute X memory Y memory-bound strips Z) total T`. **It is a cycle model with stated parameters, not a measurement of hardware.** The model, for an in-order implementation whose strip pipeline issues one vector instruction a cycle:

* scalar instructions (the `-P` count, a `vec` among them as its set-up) cost 1 cycle each: `N` = the instructions started;
* each `vend` costs 1 cycle;
* a strip costs `max(compute, memory) + commit`. compute = one cycle for each vector instruction of the block (a `vfir` one for each tap; a floating-point sum `vacc.f`, `.f.d`, `.d` one for each 16-byte chunk of its strip, the chunks being added to the register one after the other; a `vclr` in a block only in the first strip; the epilogue after a `vfin` is one more strip). memory = for each load or store instruction the bytes it moves (elements x fields x element size; for a strided one the elements x the element size; a 16-byte table of `vtbl` from memory) over the port width, rounded up, summed over the instructions of the strip (one port, one instruction at a time). commit = `--vcommit` (default 1);
* `V` = the vends and the strips' cycles; `X`, `Y` are the sums of the strips' compute and memory cycles, `Z` the strips where memory is greater; `T = N + V`.

**Model 1 ignores**: the latency of a vector instruction (they are assumed to issue back to back, and a strip's result is available at once), dependences between instructions, bank conflicts, cache misses, a strided access taking more than its bytes of bandwidth, the overlap of a strip with the next, the scalar instructions' own timing (the `--timing` models of [timing-model.md](timing-model.md) cover those, and do not know the vec blocks). `tools/strip-bench.py` runs it on the kernels of `llvm/bench` ([vec-strip.md](encoding-work/vec-strip.md)).

### The second model: latencies from logic depth

`-V` prints a second line, `vec model2 latency T strip S port P commit C vpipe N vmemlat M: scalar X vector Y (blocks with a hidden accumulator H, with a scalar dependence D) total Z`; model 1's line is unchanged. **It is a latency model whose latencies are assumptions**: the logic depth of each instruction class was measured with yosys (`ltp` and a weighted path analysis), and converted to cycles under an assumed delay per level, clock period and register overhead ([vec-latency.md](encoding-work/vec-latency.md): the method, the tables and the limits). Per vec block, from cycle 0 of the block:

* vector instructions issue **in order, one a cycle** (a `vfir` one for each tap); an instruction issues when its source registers are ready: a scoreboard on v0..v15, a result ready `latency` cycles after issue, **no chaining** (no forwarding between stages beyond the latency); an instruction that writes a register waits so that it completes after an older pending write; the unit of its class accepts an instruction every `interval` cycles (1 in the tables: all classes are pipelined);
* the instruction classes (`alu cmp bsl shift narrow mul8 mul16 mulh16 mul32 mul64 dot dacc sad acc mmacc fir tbl lseg sseg cvt fma fma64 ld st misc`) have a latency from the table (`--latency`); the table has values for each strip of 8, 16 and 32 bytes (a strip of 64 uses the 32 values), because the depth of a tree or an interleave network depends on the strip. A file replaces the classes it names (a line `class@16 ...` for one strip); the rest stays as `fpga`. `ld` and `st` are the alignment and merge stages on top of the memory;
* memory: the same single port as model 1 (a load or store holds it for bytes / port cycles, rounded up; the model's `--vport`); a load's data is ready `--vmemlat` cycles (default 4, the load-to-use latency of a first-level cache) + the `ld` class (+ `lseg` for a segment load) after the last beat of the port; a store reads its register at issue and is done after the merge (`st`, and `narrow` for `vsts`, `sseg` for a segment store); a `vtbl` with a table in memory waits for it. A scalar element that `vfmab` loads is not counted (as in model 1);
* a reduction (`vacc vdacc vsad vmaxacc vminacc`) adds into its scalar register when its tree is done, one cycle after the same register's add of the previous strip (a floating-point sum: for each chunk after the first of its strip one more latency of the `fma` class, the chain through the register); the block's scalar registers are not otherwise tracked: **a block that reads a scalar register that one of its reductions writes** (counted as `D`) cannot start a strip before the previous strip has ended; this is rare (none of the benchmark kernels do);
* a strip ends when its last result and store are done, plus the commit cost (`--vcommit`, default 1). **`--vpipe=N`** strips may be in flight: strip k + N starts issuing when strip k has ended; N = 1 (default) has no overlap, strips run one after the other and every dependence latency of the strip is exposed; with N = 2 or 4 the tail of a strip overlaps the next strip's start. The registers that `vclr` made accumulators (a hidden accumulator, counted as `H`; `vfmab`, `vmla`, `vdot` on them) keep their ready times from strip to strip, so the loop-carried dependence through them exposes the latency whatever N says; the other registers are taken as renamed for each strip (for N > 1 that means a register file for each strip in flight, which the area figures of [vec-strip.md](encoding-work/vec-strip.md) do not contain);
* scalar instructions cost 1 cycle each (the `vec` is one of them), a `vend` 1 cycle, **as in model 1**: neither model has the latency of the scalar multiplier, the divider or loads, so the scalar part of the two totals is the same number and the difference between them is the vector part only.

**Model 2 ignores**: scalar instruction latencies, cache misses and bank conflicts (the load latency is a parameter, the same for every access), the register file's ports (three reads and one write a cycle are assumed to be available to every issue), the cost of the renaming that vpipe > 1 needs, restart of a fault (the model counts the strips that were run), and everything that the logic depth does not say (wire delay of a wide strip, clock gating, the instruction fetch of a block). Model 1 and 2 count only: they do not change what a program computes (`tools/lat-bench.py` checks that the results of the kernels are the same with and without them).

## The instruction set

The executor decodes with the table codec `common/pdp64enc.c` (the prefix-coded encoding of the grammar `spec/pdp64/pdp64.hbnf`). The instructions of the groups of the mnemonic numbering (`spec/pdp64-mnemonics.hbnf`) are turned into one decoded structure and run by the same code
(`common/pdp64exec.c`, `exec_fmt`), so their meaning is written once; the decoder and the instructions that have no such group are in `common/pdp64exec_enc.inc`: the fused instructions
(`movcall popmret popret mov2`, a fault in the second half restarts the whole instruction, which the saved state at the start of the instruction makes exact), `maskeqz masknez bsel`,
`addv subv mulv` (the two-register form of the tables, `rd <- rd op rs`;
overflow is an abort at the instruction, no register written), the MESC words `addm subm bicm bism`
(each does what the ALU operation does to the memory operand and writes nothing else), `utf8len`, `fclass32`, the user-qualified moves `movX.u` and the user-qualified block copies `mcpy.ur` and `mcpy.uw` (in a simulator without an MMU they are the ordinary moves and the ordinary copy). A plain load or store works at any address in `sim64` (a store that crosses a page checks both pages before it writes). The register file has 32 registers; `pushm`/`popm`
take a 32-bit mask; r16 to r31 exist. A word that is in the tables but not in the reference executor traps as
`unimplemented instruction NAME` (exit 139, or the illegal-instruction exception with `-K`): the AES and SHA words (`aeses aesesm aesds aesdsm aesks1 aesks2 aesim sha256* sha512* msha256 msha512 maesctr`),
`utf8dec`, `utf8enc` and `mval`. The list is the code's (`common/pdp64exec_enc.inc`).

## Profile

`-P file` writes, when the program exits: `#encoding` (pdp64, the one CPU), `#instructions` (executed, a block instruction such as `mcpy` is one), `#bytes` (the length of the executed instructions),
`#category NAME COUNT` for each category (`other frame_load frame_store regmove pushpop memref branch call_ret_jmp block fused lea`), and one line
`pc count bytes category` (hex, decimal, decimal, the index of the category) for every pc that ran. An instruction that is restarted after an exception (`-K`) counts each time it is started.

## System interface (a stand-in for an operating system)

`trap #n`, arguments in `r0`..`r2`: `0` exit (status `r0`), `1` write(fd `r0`, buffer `r1`, length `r2`; count returned in `r0`), `2` read (same
registers). `halt` stops with the status in `r0`. The emulator's exit status is the program's. A fault (misaligned data, unmapped address,
unimplemented instruction, divide by zero) prints a message and the registers and exits with 139.

## Memory

Text at `0x10000`, data on the next page, stack top at `0x7ffffff000` (grows down), as `ld64` lays out the file; anything else is unmapped.

## Floating point

Values are bits in the general registers. Flags accumulate in the sticky `fpsr` (NX UF OF DZ NV = bits 0..4; `fsflags rs, rd` swaps) and never trap.
Any NaN result is the canonical quiet NaN.

## Tests

A test may have an optional `tests/sim/NAME.flags` file with extra `sim64` arguments (for example `-k`) and a `NAME.strips` file with the strips (`-S`, bytes) at which `tools/check-sim64.sh` runs the same program again with the same expectations: `vec-basic`, `vec-wave1`, `vec-wave2`, `vec-restart` and `vec-strip` list `16 32 64` (the strip is invisible: errata 173), and `tools/strip-equiv.py` runs the whole suite and `llvm/check.sh` at those strips. `tools/check-qemu.sh` skips such tests, because the QEMU machine has no kernel mode yet.

`tools/check-sim64.sh` assembles, links and runs every `tests/sim/NAME.s`. Each program checks its own results against values worked out by hand
from the ISA and exits with the number of the first check that failed (0 = all passed); `NAME.exit` and `NAME.out` give an expected status or output
for the cases that want one. The programs are generated by a script, so a check that did not fail would be a check that did not run: each was
verified by changing one expected value and seeing a non-zero exit.

Covered: add/sub/logic/shifts (counts 0, 1, 63, 64 and more)/multiply/divide/modulo (including `INT64_MIN / -1`), the results of every kind of
operation compared with `setcc`, every addressing mode and width with sign and zero extension, all compare-and-branch conditions on three operand pairs, `sob`,
`call`/`ret`, `push`/`pop`, `pushm`/`popm` ordering, `jmpi`/`calli`, bit counts and byte/bit reversal, integer `abs`/`min`/`max`, block copy/compare/fill/scan,
binary64 arithmetic, comparison, conversion and the five exception flags.

Not covered by the original tests: `btag`/`bntag`, the binary32 forms, `ATOM`, privileged instructions.

Every test of `tests/sim` runs twice, with the plain objects (`as64 --no-relax`) and relaxed (the default); `newops.s`, `newops32.s` and `fused.s` are generated by `tests/sim/gen_newops.py` (expectations computed there), the `unimpl-*` programs check the words that the reference executor does not implement, and `tools/check-exec-enc.sh` runs every first parcel of the table through the executor.
