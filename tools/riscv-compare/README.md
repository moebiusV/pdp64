# riscv-compare

Measurement scripts for `docs/encoding-work/riscv-comparison.md`: the static size of the 841-file corpus of `docs/encoding-work/integration.md`
for pdp64/32 and pdp64/16 (pcc), pcc amd64 and i386, and GCC and clang for RISC-V (rv64gc, rv64g), AArch64, x86-64, i386, Arm and MIPS64 at
-O0, -O1, -O2, -O3 and -Os.  Not a GNU-packaged project: a folder of scripts.

## What has to exist

* the pdp64 tools of the repository: `build/as64` (`tools/build-as64.sh`);
* the pcc tree that built the pdp64 numbers: `PCCENC=~/claude/pcc-enc` (the enc-prefix tree of `integration.md`; it is a copy of the files, not a git
  repository any more; `build-ccoms.sh` builds from a scratch copy and leaves the tree alone);
* the corpora under `~/claude/corpora` (with `sysroot/<arch>/include`, the musl headers) and the v7unix-toolchain repository
  (`~/claude/facetlang/pdp11/v7unix-toolchain`, `TOOLCHAIN=` to move it): `prep.py` imports its `tools/corpus.py` for the per-corpus include directories and defines,
  exactly as `tools/pdp64size.py` does;
* `clang` (21) with the RISC-V, AArch64, ARM, MIPS and x86 targets, `llvm-objdump-21`, host `gcc` (x86-64 and -m32);
* No GCC rows (dropped); the diagnosis probes of `diag-riscv-backend.sh` need GNU `as` and `ld` for RISC-V (binutils 2.43.1 configured `--target=riscv64-unknown-elf`) in `WORK/gccx/prefix/bin`.

## Files

| file | what |
|---|---|
| `fair.txt` | the 841 files: corpus, path under `~/claude/corpora` (the `fair` set of `tools/pdp64size.py`: what the aarch64, amd64 and i386 builds of corpus.py all compile with `ours -O`, from `/tmp/co-final/results.jsonl`) |
| `prep.py ARCH OUT` | preprocess the 841 files for ARCH (`aarch64` is the text pdp64 gets) into `OUT/NNN.i`, `OUT/index.tsv` |
| `build-ccoms.sh TREE DIR` | build ccom for pdp64 (16 and 32 registers), amd64, i386 and (for the diagnosis) riscv64 from scratch copies of TREE |
| `pdp64-static.py` | `ccom -m pdp64/NN`, `as64 -m pdp64/NN --stats`: instructions, instruction bytes and `.text` bytes per file |
| `pcc-static.py` | the same for a pcc back end whose output is assembled by the host assembler (amd64, i386) |
| `ref-static.py`, `run-refs.py` | GCC and clang objects for the matrix of architectures and levels |
| `objstat.py` | instruction count, instruction bytes, padding and `.text` size of an object, from `llvm-objdump -d` |
| `summarize.py WORK OUT` | merge: `static-wide.csv`, `static-summary.md` (the tables of the report) |
| `pcc-compile.py` | compile the preprocessed corpus with a given ccom and list the failures (used for the RISC-V back end diagnosis) |
| `diag-riscv-backend.sh WORK` | the probes of the report's section on pcc's RISC-V back end |
| `Makefile` | `make WORK=/scratch/dir` runs everything in order |

## Commands

    make WORK=/scratch/rv prep ccoms          # preprocess, build the compilers
    make WORK=/scratch/rv pdp64 pccx86        # pdp64/32, /16, pcc amd64, i386 (two flag sets each)
    python3 run-refs.py /scratch/rv           # the GCC/clang matrix (about 40 configurations, each 1 to 4 minutes on two idle cores)
    python3 summarize.py /scratch/rv ../../docs/encoding-work/riscv-data

Each `static.csv` has one row per file: `file,status,ins,ibytes,text,data_in_text,pad_ins,pad_bytes,msg` (`pdp64-static.py` has `cbcc_expanded` in
place of the padding columns, and `ins`, `ibytes` come from the assembler's statistics line).
