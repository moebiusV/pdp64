# Capability pointers: the measurements behind `capability-pointers-measured.md`

Written 2026-11-27. Nothing here changes a tracked file; all runs were made in scratch copies. Results are in `results/`.

| file | what it does | result file |
|---|---|---|
| `ptrscan.py` | runs a program, stops it, reads its writable memory from `/proc/PID/mem`, counts 8-byte words that point into a mapped region (a LOWER bound: a null pointer looks like zero) | `results/ptrscan.jsonl` |
| `ptrir.py` | compiles OpenBSD C sources (`../openbsd-src`) to LLVM IR for x86_64 (LP64, the pdp64's data model), counts pointer loads and stores (also weighted by LLVM's static block frequency), struct layouts with 8- and 16-byte pointers, escaping stack objects | `results/ptrir.json` |
| `ptrgrow.c` | pointer-chasing programs (tree, shuffled list, chained hash) with 8-byte and with 16-byte aligned pointer slots, timed on the host (AMD Ryzen 5 7600) over 2^10 to 2^23 nodes; a no-pointer control | `results/ptrgrow-host.txt` (two runs of each, core pinned) |
| `scratch-in/` | the inputs of `ptrscan.py` (an interpreter heap, a Perl hash, an awk array, a SQL table, a C++ compile) | |

Rerun: `SCR=<dir with inc/> TOOLS=<dir with opt> python3 ptrir.py out.json usr.bin/sed ...` (`$SCR/inc` is a directory of symlinks to the OpenBSD `include/` plus `sys` -> `sys/sys`, `machine` -> `sys/arch/amd64/include`; the compile line is in the script); `cc -O2 -DP=8 ptrgrow.c`, `-DP=16`; `DELAY=5 python3 ptrscan.py CMD...`.

What these are NOT: no pdp64 binary of OpenBSD or Debian exists on this computer, so every figure is a proxy on a host with the same data model; the host has no capability hardware, so `ptrgrow.c` models only the SIZE of a pointer (one 8-byte load still loads the address, and the check is not modelled: it is free in the access on a real machine).
