# The flags measurement, repeated by `tools/measure-flags.sh`

Generated; do not edit.  The numbers are in `results-final.txt`; the manual cites that file.  "base" is the compiler and tools before the flags were removed, "now" the flag-free ones.

## Pins

* base pdp64 commit: 8d8d07f694970305653e5600d96f0f2829b807e5
* base pcc commit: 82d5006b802be863368844c118747f067dfe63ec
* base pcc build: 32 registers (-DPDP64_REGS32), run with -m pdp64/32
* now pdp64 commit: 713cc73f333a4720fb515ffd90486ad081908c3e
* now pcc commit: 1ceec537082b806bc79e2bf1d160e39a6cc78df8
* openbsd sources: c402c876540
* subset: 0
* gcc: gcc (Debian 14.2.0-19) 14.2.0
* python: Python 3.13.5
* host: Linux x86_64

## Verdict

| measure | base | now | change |
|---|---:|---:|---:|
| files compiled by both sides (of 1104 listed, 1104 tried) | | | 624 |
| static instructions | 165978 | 165705 | -0.16% |
| static bytes (as64 plain) | 493854 | 495926 | +0.42% |
| static bytes after ld64 relaxation | 474820 | 476940 | +0.45% |
| programs run on both sides (outputs equal) | | | 36 (36) |
| instructions executed | 65856420 | 65796388 | -0.09% |
| bytes fetched | 192491168 | 195729170 | +1.68% |
| cycles, scalar | 94033900 | 91836722 | -2.34% |
| cycles, dual | 75283982 | 69215116 | -8.06% |
| cycles, scalar-c | 109669871 | 106978652 | -2.45% |
| cycles, dual-c | 91210465 | 84699288 | -7.14% |
Control: 12 programs have the same compiled code on both sides (the assembly text of their sources is identical); their cycles differ by -1.77% (scalar) and -5.88% (dual) between the two simulators, which is the change of the timing model and of the linked layout, not of the code.  Read the cycle rows with that in mind; the instruction counts do not have this effect.

## Static count of each kind of compare, branch and flag instruction (the 624 files)

| kind | base | now |
|---|---:|---:|
| cmp | 1138 | 0 |
| tst | 74 | 0 |
| flag branch | 1862 | 0 |
| SET (flags) | 175 | 0 |
| setCC (compare into register) | 0 | 212 |
| FCMP | 201 | 0 |
| compare-and-branch (cbCC) | 12661 | 14283 |
| FP compare-and-branch (fcbCC) | 0 | 343 |
| br/jmp | 6295 | 6279 |
| all instructions (mnemonic count) | 165972 | 165705 |

## By group (plain bytes)

| group | files | base insns | now insns | % | base bytes | now bytes | % |
|---|---:|---:|---:|---:|---:|---:|---:|
| libz | 15 | 12784 | 12769 | -0.12 | 38364 | 38448 | +0.22 |
| libc-string | 71 | 2874 | 2874 | +0.00 | 7748 | 7774 | +0.34 |
| libc-stdlib | 52 | 7564 | 7558 | -0.08 | 22340 | 22378 | +0.17 |
| libc-gen | 89 | 17572 | 17533 | -0.22 | 50832 | 50934 | +0.20 |
| libc-stdio | 33 | 2516 | 2511 | -0.20 | 6950 | 6940 | -0.14 |
| libc-net | 40 | 6483 | 6485 | +0.03 | 18950 | 18968 | +0.09 |
| libc-hash | 3 | 3826 | 3824 | -0.05 | 9744 | 9740 | -0.04 |
| sys-crypto | 24 | 27655 | 27648 | -0.03 | 73596 | 73588 | -0.01 |
| libc-regex | 4 | 5241 | 5239 | -0.04 | 16080 | 16532 | +2.81 |
| libc-db | 28 | 10059 | 10068 | +0.09 | 29882 | 30040 | +0.53 |
| libc-time | 7 | 5680 | 5664 | -0.28 | 17210 | 17242 | +0.19 |
| libc-crypt | 5 | 3109 | 3107 | -0.06 | 8448 | 8446 | -0.02 |
| libc-locale | 32 | 4156 | 4147 | -0.22 | 12558 | 12540 | -0.14 |
| libedit | 3 | 1981 | 1978 | -0.15 | 5954 | 5968 | +0.24 |
| libm | 145 | 22586 | 22566 | -0.09 | 66814 | 67964 | +1.72 |
| ub-lex | 2 | 6 | 6 | +0.00 | 16 | 16 | +0.00 |
| ub-yacc | 12 | 9574 | 9555 | -0.20 | 36266 | 36234 | -0.09 |
| ub-sort | 7 | 6017 | 5970 | -0.78 | 18912 | 18956 | +0.23 |
| ub-diff | 4 | 3535 | 3530 | -0.14 | 12172 | 12208 | +0.30 |
| ub-sed | 4 | 3698 | 3697 | -0.03 | 12622 | 12652 | +0.24 |
| ub-m4 | 5 | 2999 | 2995 | -0.13 | 10324 | 10340 | +0.15 |
| ub-cmp | 4 | 718 | 717 | -0.14 | 2142 | 2160 | +0.84 |
| libcrypto | 2 | 1 | 1 | +0.00 | 6 | 6 | +0.00 |
| tests-c | 5 | 799 | 780 | -2.38 | 2394 | 2402 | +0.33 |
| tests-c-new | 20 | 3883 | 3825 | -1.49 | 11342 | 11240 | -0.90 |
| bench-sc | 8 | 662 | 658 | -0.60 | 2188 | 2210 | +1.01 |

## Programs

| program | insns base | insns now | % | bytes fetched base | % | scalar cycles base | % | dual cycles base | % | output |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| zlib | 16093452 | 16079027 | -0.09 | 47347324 | +0.65 | 23578211 | -3.57 | 20541031 | -7.90 | equal |
| crypto | 16383157 | 16366756 | -0.10 | 43770056 | +0.45 | 19565001 | -0.10 | 15063361 | -0.11 | equal |
| libc-sort-string | 4964234 | 5034346 | +1.41 | 15003552 | +1.00 | 8931624 | +0.87 | 6783640 | -3.11 | equal |
| bench-sc/copy | 820401 | 820400 | -0.00 | 3380854 | -0.00 | 1198175 | -6.81 | 689962 | -9.54 | equal |
| bench-sc/hash | 1436749 | 1436748 | -0.00 | 5189678 | -0.00 | 2689197 | -2.27 | 2284692 | -8.40 | equal |
| bench-sc/hist | 3542132 | 3542131 | -0.00 | 12008246 | +13.10 | 5215252 | -9.43 | 4329708 | -20.45 | equal |
| bench-sc/list | 492117 | 492116 | -0.00 | 1632314 | -0.00 | 912555 | -0.00 | 744526 | -1.61 | equal |
| bench-sc/lz | 5135318 | 5086117 | -0.96 | 15878736 | +5.75 | 7645657 | -2.41 | 5824487 | -8.63 | equal |
| bench-sc/matmul | 2185197 | 2185196 | -0.00 | 6408022 | -0.00 | 3214000 | -0.00 | 2731706 | -4.05 | equal |
| bench-sc/sha | 5901446 | 5851269 | -0.85 | 16275890 | +0.40 | 7253581 | -0.71 | 5379642 | -0.89 | equal |
| bench-sc/sort | 2431075 | 2431074 | -0.00 | 8547894 | +0.38 | 4280212 | -4.01 | 3445733 | -6.42 | equal |
| c/cbr (small) | 379 | 339 | -10.55 | 1088 | -7.35 | 803 | -3.99 | 667 | -5.40 | equal |
| c/extend (small) | 122 | 121 | -0.82 | 382 | +4.19 | 393 | -2.54 | 380 | -3.95 | equal |
| c/flagfree (small) | 267 | 256 | -4.12 | 746 | -2.95 | 604 | -1.16 | 506 | -0.99 | equal |
| c/rotate32 (small) | 164 | 159 | -3.05 | 534 | +2.25 | 453 | -0.44 | 399 | -3.26 | equal |
| c/rotate64 (small) | 77 | 76 | -1.30 | 226 | +1.77 | 250 | -2.00 | 231 | -0.87 | equal |
| c-new/autoinc (small) | 583 | 582 | -0.17 | 1876 | -0.11 | 1110 | -0.27 | 875 | -7.89 | equal |
| c-new/avail_chase (small) | 169 | 166 | -1.78 | 476 | -1.26 | 350 | -0.86 | 303 | -1.65 | equal |
| c-new/avail_volatile (small) | 143 | 142 | -0.70 | 402 | +0.00 | 336 | -0.89 | 298 | -3.02 | equal |
| c-new/ccp (small) | 234 | 233 | -0.43 | 626 | -0.32 | 572 | -0.70 | 487 | -8.42 | equal |
| c-new/ccp_signedness (small) | 34 | 33 | -2.94 | 86 | -2.33 | 132 | -0.76 | 124 | -1.61 | equal |
| c-new/divmagic | 6425676 | 6428675 | +0.05 | 16918024 | +0.04 | 9466083 | -3.91 | 7401834 | -29.43 | equal |
| c-new/divp2 (small) | 18056 | 18055 | -0.01 | 49092 | -0.00 | 33082 | -0.10 | 28169 | -1.73 | equal |
| c-new/fields (small) | 577 | 576 | -0.17 | 1776 | +0.34 | 1114 | -0.27 | 889 | -1.69 | equal |
| c-new/fuse_calls (small) | 258 | 257 | -0.39 | 658 | -0.30 | 532 | +2.44 | 407 | -1.47 | equal |
| c-new/hoist (small) | 855 | 854 | -0.12 | 2092 | +0.67 | 1429 | -1.54 | 1212 | -3.30 | equal |
| c-new/index (small) | 443 | 442 | -0.23 | 1446 | +0.00 | 742 | -0.13 | 594 | -0.84 | equal |
| c-new/jtab (small) | 1494 | 1401 | -6.22 | 4654 | -4.00 | 3125 | -3.58 | 2357 | -6.58 | equal |
| c-new/leaf_lea (small) | 1080 | 1079 | -0.09 | 4224 | -0.05 | 1626 | -0.06 | 1205 | -0.17 | equal |
| c-new/minmax (small) | 3691 | 3698 | +0.19 | 11168 | +0.16 | 7169 | +2.22 | 4104 | -7.65 | equal |
| c-new/modes (small) | 686 | 685 | -0.15 | 2092 | +0.10 | 1388 | -2.59 | 1107 | -5.15 | equal |
| c-new/mullea (small) | 716 | 715 | -0.14 | 2232 | -0.09 | 1254 | -0.08 | 788 | -2.54 | equal |
| c-new/regs32 (small) | 227 | 225 | -0.88 | 574 | -0.70 | 429 | -0.93 | 359 | -5.85 | equal |
| c-new/setcc (small) | 14093 | 11329 | -19.61 | 41134 | -12.91 | 24654 | -10.82 | 16297 | -15.95 | equal |
| c-new/tailcall (small) | 820 | 819 | -0.12 | 2196 | -0.09 | 2153 | -4.09 | 1362 | -0.07 | equal |
| c-new/thread_bool (small) | 298 | 291 | -2.35 | 798 | -1.75 | 652 | -3.22 | 540 | -5.74 | equal |

Over the 12 programs of 100,000 instructions or more: instructions -0.09%, cycles scalar -2.34%, dual -8.06%.

Programs that did not build or run: base: c-new/switch_tree (switch_tree.c: as64 $WORK/runout/base/switch_tree.s:262: 1:1:0: expected one of something other than); now: none

