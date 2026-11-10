# sim64: the reference emulator

[← pdp64 index](../README.md)

`sim64 [-t] [-r] [-k] [-n steps] program` loads an ELF executable written by `ld64`, decodes each instruction with the decoder generated from
the table codec (`common/pdp64enc.c`, with the tables generated from `spec/pdp64/pdp64.hbnf`) and runs it in user mode. It is the executable statement of what each instruction does, and the instruction numbers are the names in `build/pdp64-consts.h`, so nothing is typed twice.

| option | meaning |
|---|---|
| `-t` | one line per instruction on standard error: address and the parcels |
| `-r` | print the registers and flags when the program stops |
| `-k` | run in kernel mode: the privileged `mfsr` and `mtsr` are allowed (default: user mode, where they fault as "privileged instruction in user mode") |
| `-n N` | stop after N instructions (default 200 million) |
| `-m pdp64` | accepted and ignored, for the driver convention of the C compiler: there is one target and no other value is accepted; a program whose `e_flags` name another instruction set is refused |
| `-P file` | profile: count the executed instructions per pc and write them at exit (see below) |
| `--timing=SPEC` | a cycle estimate from a trace-driven in-order timing model (repeatable); `--timing-out=FILE`, `--timing-pc=FILE`, `--timing-help`: [timing-model.md](timing-model.md) |

## The instruction set

The executor decodes with the table codec `common/pdp64enc.c` (the encoding of `spec/README.md`). The instructions of the groups of the mnemonic numbering (`spec/pdp64-mnemonics.hbnf`) are turned into one decoded structure and run by the same code
(`common/pdp64exec.c`, `exec_fmt`), so their meaning is written once; the decoder and the instructions that have no such group are in `common/pdp64exec_enc.inc`: the fused instructions
(`movcall popmret popret mov2`, a fault in the second half restarts the whole instruction, which the saved state at the start of the instruction makes exact), `maskeqz masknez bsel`,
`movql`, `trapcc.CC` (a trap: EPC is the next instruction, EVA the address of the `trapcc`, vector 16), `addv subv mulv` (the two-register form of the tables, `rd <- rd op rs`;
overflow is an abort at the instruction, no register or flag written), the MESC words `movub movuw movul movuq` (unaligned, no alignment fault) and `addm subm bicm bism`
(flags of the ALU operation), `utf8len`, `fclass32`, and the user-qualified moves `movX.u` (in a simulator without an MMU they are the ordinary moves). The register file has 32 registers; `pushm`/`popm`
take a 32-bit mask; r16 to r31 exist. A word that is in the tables but not in the reference executor traps as
`unimplemented instruction NAME` (exit 139, or the illegal-instruction exception with `-K`): the atomic group (`cas swap xadd xand xor_ xxor xmax xmin xmaxu xminu` and their `db` forms, `ll`, `sc`:
the operand placement and the size encoding are not fixed), the AES and SHA words (`aeses aesesm aesds aesdsm aesks1 aesks2 aesim sha256* sha512* msha256 msha512 maesctr`),
`utf8dec`, `utf8enc`, `mval`, the deferred loads `movX.d` and `movX.ud`, and the placeholders `syspg0` to `syspg5`.

## Profile

`-P file` writes, when the program exits: `#encoding` (pdp64), `#instructions` (executed, a block instruction such as `mcpy` is one), `#bytes` (the length of the executed instructions),
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

A test may have an optional `tests/sim/NAME.flags` file with extra `sim64` arguments (for example `-k`). `tools/check-qemu.sh` skips such tests, because the QEMU machine has no kernel mode yet.

`tools/check-sim64.sh` assembles, links and runs every `tests/sim/NAME.s`. Each program checks its own results against values worked out by hand
from the ISA and exits with the number of the first check that failed (0 = all passed); `NAME.exit` and `NAME.out` give an expected status or output
for the cases that want one. The programs are generated by a script, so a check that did not fail would be a check that did not run: each was
verified by changing one expected value and seeing a non-zero exit.

Covered: add/sub/logic/shifts (counts 0, 1, 63, 64 and more)/multiply/divide/modulo (including `INT64_MIN / -1`), flags after every kind of
operation read with `set cc`, every addressing mode and width with sign and zero extension, all branch conditions on three operand pairs, `sob`,
`call`/`ret`, `push`/`pop`, `pushm`/`popm` ordering, `jmpi`/`calli`, bit counts and byte/bit reversal, integer `abs`/`min`/`max`, block copy/compare/fill/scan,
binary64 arithmetic, comparison, conversion and the five exception flags.

Not covered by the original tests: `btag`/`bntag`, the binary32 forms, `ATOM`, privileged instructions.

Every test of `tests/sim` runs twice, with the plain objects (`as64 --no-relax`) and relaxed (the default); `newops.s`, `newops32.s` and `fused.s` are generated by `tests/sim/gen_newops.py` (expectations computed there), the `unimpl-*` programs check the words that the reference executor does not implement, and `tools/check-exec-enc.sh` runs every first parcel of the table through the executor.
