**D.1** (moved from appendix D, the Registers row) `R16` to `R23` are caller-saved and `R24` to `R31` callee-saved. *(P)*

**D.4.2** (moved from appendix D) The compiler treats `R16` to `R23` as clobbered by a call and `R24` to `R31` as saved by the callee, and the stand-in runtime of the six large programs saves `R24` to `R31` in `setjmp` and `longjmp`. `docs/abi.md` calls this split a draft. *(P)*
