52 programs of tests/sim, each run at 4 strips (the 3 tests that look at the strip are run a second time with those checks switched off); 52 runs gave the same exit status and standard output at all four strips, 3 runs differ; the programs that are not in the table below gave the expected exit status and the same output at all four.

Patched copy of vec-basic switches off: check 4: vlen.b is 32 (1).

Patched copy of vec-restart switches off: every check of the rows of the kernels kern17 kern48 kern49 kern51, the blocks of which store lanes that depend on the strip (a register-form vtbl.b, or a vclr accumulator stored or reduced inside the block; the expected states are the strip-32 ones; the rows of all other kernels run all checks); checks 5 to 11: the registers and the memory the handler sees at a fault (the progress at the strip it stopped in) (7).

Patched copy of vec-wave1 switches off: check 63: vtbl.b with a table register, the result of lanes 16 and above depends on the strip (1).

| test | patched | expected exit | exit at strip 8, 16, 32, 64 | stdout identical at all four | verdict |
|---|---|---:|---|---|---|
| vec-basic | no | 0 | 4 4 0 4 | yes | DIFFERS |
| vec-basic | yes | 0 | 0 0 0 0 | yes | same |
| vec-restart | no | 0 | 5 5 0 5 | yes | DIFFERS |
| vec-restart | yes | 0 | 0 0 0 0 | yes | same |
| vec-wave1 | no | 0 | 63 63 0 63 | yes | DIFFERS |
| vec-wave1 | yes | 0 | 0 0 0 0 | yes | same |

vacc.f of 1000 binary32 values (seeded random, mixed sign, 10^-3 to 10^3), the result as binary32 bits by strip: 8: 0xc602a2a3, 16: 0xc602a2a0, 32: 0xc602a2a1, 64: 0xc602a2a1 (they differ: a floating-point sum depends on the strip)

llvm/check.sh (rc and the lines "ok"/"FAIL", the .ll tests, the C programs through two pipelines and the vector kernels, four variants each):

* strip 8: 197 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 84 passed, 0 failed
* strip 16: 197 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 84 passed, 0 failed
* strip 32: 197 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 84 passed, 0 failed
* strip 64: 197 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 84 passed, 0 failed

Lines that differ between strip 32 and strip 8 (0):
    none

Lines that differ between strip 32 and strip 16 (0):
    none

Lines that differ between strip 32 and strip 64 (0):
    none
