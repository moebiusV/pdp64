**A.4.2** (moved from appendix A) Return-address authentication is deferred (errata 84, item 7). *(D)*

**A.5.2** (moved from appendix A) Bounds for the valid-pointer tag are deferred (errata 86, study item 3): the tag per register and per 8-byte word is kept and the bounds of a capability are not part of it.

### A.8 Two-byte forms of the user-memory guard instructions (moved from appendix A)

**A.8.1** `STUA` and `CLUA` are one-parcel system words of this CPU (they took two of the reserved system words); the user-access moves (section 6.10.4) may make them unnecessary, and they are kept until the OpenBSD port confirms them (A.8.1).

*Commentary.* **Trade-offs.** It is not worth deciding until a kernel exists to count the copy routines. **Benefits.** Smaller and faster user copies. **Verdict.** Decide when the kernel exists. **Impact.** *Kernel:* Each user copy routine is four bytes smaller. *Compiler:* None. *Hardware:* One more system word.
