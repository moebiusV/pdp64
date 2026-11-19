61 programs of tests/sim, each run unmodified at the strips 16, 32 and 64 bytes (no check switched off, no test patched): **61 gave the expected exit status and the same standard output at all three, 0 did not**.  At the strip of 8 bytes, which is outside the architecture, 2 of them differ from the strip-32 run.  The table lists the vec tests and any that failed.

| test | expected exit | exit at strip 16, 32, 64 | stdout identical | verdict | strip 8 (outside the architecture) |
|---|---:|---|---|---|---|
| vec-2d | 0 | 0 0 0 | yes | same | exit 0, same output |
| vec-basic | 0 | 0 0 0 | yes | same | exit 0, same output |
| vec-clear | 0 | 0 0 0 | yes | same | exit 0, same output |
| vec-lane | 0 | 0 0 0 | yes | same | exit 0, same output |
| vec-restart | 0 | 0 0 0 | yes | same | exit 10, same output |
| vec-strip | 0 | 0 0 0 | yes | same | exit 1, same output |
| vec-wave1 | 0 | 0 0 0 | yes | same | exit 0, same output |
| vec-wave2 | 0 | 0 0 0 | yes | same | exit 0, same output |

The probe: a floating-point sum over 1000 values (seeded, mixed sign, 10^-8 to 10^8, with exact cancellations: the order of the additions changes the result), the register as bits by strip, and the model of the canonical order:

| word | model | strip 16 | strip 32 | strip 64 | strip 8 | verdict |
|---|---|---|---|---|---|---|
| vacc.f | 0x4df180fd | 0x4df180fd | 0x4df180fd | 0x4df180fd | 0x4df180fb | same, equal to the model |
| vacc.d | 0x41be301fcd7e4243 | 0x41be301fcd7e4243 | 0x41be301fcd7e4243 | 0x41be301fcd7e4243 | 0x41be301fcd7e4244 | same, equal to the model |
| vacc.f.d | 0x41be301fcd7e240f | 0x41be301fcd7e240f | 0x41be301fcd7e240f | 0x41be301fcd7e240f | 0x41be301fcd7e2413 | same, equal to the model |

llvm/check.sh (rc and the lines "ok"/"FAIL", the .ll tests, the C programs through two pipelines and the vector kernels, four variants each):

* strip 16: 201 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 88 passed, 0 failed
* strip 32: 201 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 88 passed, 0 failed
* strip 64: 201 ok, 0 FAIL; llvm tests: 61 passed, 0 failed (a test with several `; llc:` variants counts once for each) | C programs (tests/c) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new) through clang + llc: 21 passed, 0 failed | C programs (tests/c, lv pipeline) through clang + llc: 5 passed, 0 failed | C programs (tests/c-new, lv pipeline) through clang + llc: 21 passed, 0 failed | vector kernels (tests/vec) scalar, -pdp64-vecloop, -pdp64-vecloop-strip and lv (LoopVectorize): 88 passed, 0 failed

Lines that differ between strip 32 and strip 16 (0):
    none

Lines that differ between strip 32 and strip 64 (0):
    none
