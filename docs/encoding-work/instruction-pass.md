# A pass over the whole instruction list: what an existing guarantee or instruction already covers

Status: a proposal and a measurement record by the assistant, 2026-11-25, for the owner to accept, change or refuse. Nothing here is in the grammar, the assembler, the manual or the compiler. The files I read are named in each section; the files I wrote are only this one.

## 0. Why I did this, and how to read it

When the atomics lost their twenty `DB` forms, the reason was that one decision (memory is sequentially consistent, which means every core sees all memory accesses in one single order) already gave what those forms were for. I looked for the same thing everywhere: an instruction, a form or a whole class that something already decided makes unnecessary, or nearly so, or not worth the encoding space it holds. I also looked the other way: a missing promise that makes the compiler or the programmer write many instructions.

Some words, for a reader who knows a little PDP-11 assembly:

* **Parcel**: a 16-bit unit of an instruction. Every instruction is one, two or three parcels (two, four or six bytes), and the **first parcel** alone says which instruction it is and how long it is.
* **Prefix, leaf, sub-opcode**: the first parcel starts with a few bits (the prefix) that pick a group of related instructions (a leaf); a few more bits (the sub-opcode) pick one instruction inside the group. A short prefix takes a big share of all the 65,536 possible first parcels. I quote the cost of an instruction as the **share of the first-parcel space** it holds: a leaf with an `n`-bit prefix holds 1 in 2^n of the patterns. This is my estimate from the leaf prefixes in `spec/grammars.d/20-enc-forms.hbnf`; the encoding optimiser would repack the leaves after any removal, so read it as a size, not a promise. About 5.0% of the first parcels are illegal today (the manual's count), so the free space is small and every percentage point below is real.
* **Flags**: the four condition bits N, Z, V, C that the PDP-11 also had (negative, zero, overflow, carry). Most ALU instructions set them, and the conditional branches read them.
* **Compare-and-branch** (`CBxx`): one instruction that compares a register with an immediate or another register and branches, setting no flags.
* **Trap**: the processor's forced jump to the operating system. **Poison**: a mark on a register that says "the load that filled me faulted"; it must be remembered somewhere until something reads the register.
* **Bytes executed, instructions executed**: the two cheap stand-ins for speed. Where I had a run time I say so; mostly I did not (section 5).

Method and data, so that the numbers can be checked or redone:

| What | Where it comes from |
|---|---|
| The instruction list | `spec/grammars.d/30-mn-core.hbnf`, `35-mn-numbers`, `40-mn-system`, `54-mn-tlbx`, `57-enc-atomic`, `80-mn-ext` and `20-enc-forms.hbnf`: 729 words in the three mnemonic groups, 365 of them in the vector family and 364 outside it (aliases counted); the manual's own count is 685 instruction words |
| **pcc, static, 841 files** (the corpus of the earlier studies, compiler as of 2026-11) | `docs/codegen-data/mnemonics_pdp64.csv` (370,115 instructions), `shapes_pdp64.csv`, `bigrams_pdp64.csv`, `instructions_used.csv` (which also says why each zero-use word is zero). The corpus machinery lives in a repository that is not on this machine, so I could not rebuild this corpus |
| **LLVM, static, my own corpus** | 205 files of OpenBSD source (libz, libc string, stdlib, stdio and gen, `sys/crypto`, parts of libcrypto, awk, lex, yacc and some utilities) compiled by the host clang to LLVM IR and by `llc -mtriple=pdp64-unknown-elf -O2` to assembly, then assembled by `build/as64`: **64,266 instructions, 59 distinct mnemonics**, 170,776 bytes (2.66 bytes an instruction as `as64 --stats` counts it). Files that need variadic calls or headers the OpenBSD tree could not give were left out (about one in six of the files tried). Scratch only; the recipe is in section 5 |
| **Dynamic, on sim64** | three programs, run with `sim64 -P` and read back with `tools/encdis.c` (`encdis -k`), which turns a profile into a count for each mnemonic. (a) zlib 1.x deflate and inflate of 50 KB of text plus a sort of 3,000 integers, compiled by LLVM: 14,512,150 instructions executed. (b) SHA-256, SHA-512, MD5, SHA-1 and Blowfish over 64 KB, compiled by LLVM: 12,884,333 executed. (c) the same crypto program with the four crypto files compiled by pcc instead (the driver is LLVM's): 12,173,630 executed. (b) and (c) print the same checksum, 7021. The `-V` cycle model of sim64 is for vector blocks only, so I used instruction counts, not cycles |
| Atomics in real kernels | `docs/encoding-work/bench/rejudge-timer-iommu/atomics-corpus-result.txt`: every locked instruction in the 4,225 x86-64 kernel modules of Linux 6.12 on this machine (37,566 of them), static |
| Vector words in compiled kernels | `../llvm-pdp64/vector-usage.md` (31 kernels, two builds) and `docs/encoding-work/vec-isa.md` |
| Other architectures | the repository's own studies (`docs/encoding-work/best-of-breed-*.md`, `bounds-check-isas.md`, `check-instructions.md`, `arch-comparison.md`). Anything I say about another machine that is not in those, I mark *from memory, not verified*, as the rule asks |

A fact about the data that matters for everything below: **the two compilers disagree about what the machine is.** pcc compiles a comparison as `CMP` followed by a flag branch (18.5% of all its static instructions are `CMP`, `TST` or a flag branch). The LLVM back end emits `CMP` and `TST` **zero** times in 64,266 instructions and uses compare-and-branch for every decision (8.1% of its instructions). Neither compiler emits several families at all. So "zero use" alone proves little; I say which compiler, and I give the covering instruction for each.

## 1. The table

Counts: 5 to remove, 5 to merge, 7 that need a measurement before anyone decides, 9 to keep (the keeps are the ones I checked and could not fault). The twenty-six lines are in the order of the sections below. "Payoff" is what the owner gets if the recommendation is taken: first-parcel space, words, state that no longer has to be built, specified and tested, or instructions saved.

| # | Candidate | What covers it | Recommendation | Payoff |
|---|---|---|---|---|
| C1 | The deferred-fault loads `MOVx.D` and `MOVx.UD` (14 words) | an ordinary load; a guard in software; an out-of-order core speculates by itself | **remove** | 5.1% of the first-parcel space; a poison state in every saved register set; the reference executor does not run them; no compiler or hand-written test uses them |
| C2 | `TRAPCC.cc`, fourteen one-parcel words | the compare-and-trap family `CTcc`, and `ADDV`, `SUBV`, `MULV` | **remove** | 14 words; a second trap path (a trap, where the check family is a fault); a trap that depends on flags |
| C3 | `CBPL`, `CBMI`, `CBVC`, `CBVS` (4 words, 8 forms) | `CBGE`/`CBLT` (the same unless the subtraction overflowed); `ADDV`/`SUBV` for overflow | **remove** | 0.59% of the first-parcel space; four words no program can use meaningfully |
| C4 | `MTDMW` and the windows `DMW0`, `DMW1` (and the guest copies) | nothing: they are stored and do nothing | **remove** until a window has a format | 1 word, 4 system registers, one "always exit" rule of the hypervisor, their tests |
| C5 | Stale names: the alias `WAIT`, the placeholder words `SYSPG0` to `SYSPG5` | `WFE`; nothing | **remove** the names | 7 names; the manual says `WAIT` is refused and the grammar accepts it |
| C6 | `MFCPUID`, `MTASID`, `MFASID` | `MFSR rd, cpuid`, `MTSR asid, rs`, `MFSR rd, asid` | **merge** into `MFSR` and `MTSR` | 3 words; each of the three is spelled two ways and each way has its own privilege and hypervisor rule |
| C7 | `FMSUB` and `FNMADD` in three widths (6 words) | `FMADD` and `FNMSUB`, plus an exact `FNEG` | **merge** | 6 words; makes the scalar set the same two operations as the vector set already is (`vfma`, `vfnma`); about 0.2% of the first parcels |
| C8 | `binary16` arithmetic (11 words: add, sub, mul, div, sqrt, compare, class, four fused multiply-adds) | the six conversions plus the `binary32` operation | **merge** into conversion-only if the inference users agree | 11 words and a half-width multiplier, divider and adder; costs two instructions per half-precision operation |
| C9 | `STUA`/`CLUA` and the `UA` status bit, beside `.U` | `.U` on every kernel access to user memory | **merge**: keep one mechanism | 2 words, a status bit, and a rule that two mechanisms must agree; but see the block copy |
| C10 | The explicit unaligned moves `MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ` (4 words, 8 forms) | plain loads and stores if the hardware guarantees misaligned access | **merge** (a hardware guarantee, section 4) | 4.1% of the first-parcel space; the alignment fault |
| C11 | The whole flags class (`CMP`, `TST`, 14 flag branches, `SET`, flag-reading traps, `FCMP` writing flags) | `CBxx` and compare-into-register | **needs measurement** (one experiment, below) | up to 18.5% of pcc's static instructions touch it; LLVM uses none; gates and state in every context switch |
| C12 | (a missing form) three-register integer ALU | `MOVQ` then the two-register op | **needs measurement** | up to 5.3% of LLVM's static instructions (3,421 of 64,266) are such pairs |
| C13 | `PROBER`, `PROBEW` | `.U` loads with a fixup table | **needs measurement** (does the port use them?) | 2 words; a check-then-use pattern that has a known race; one hypervisor rule |
| C14 | Absolute address mode (the `A32` leaves) | PC-relative, base+displacement, `LEA` | **needs measurement** (kernel and driver code) | 2.0% of the first-parcel space; pcc emits it once in 370,115 instructions, LLVM never |
| C15 | `BTAG`, `BNTAG`, `JTAG` | `AND` into a scratch register then `CBEQ` | **needs measurement** (a Lisp or Python runtime) | 3 words; about 0.1% of the first parcels |
| C16 | `MASKEQZ`, `MASKNEZ`, `BSEL`, `SET` | compare-and-branch around a move | **needs measurement** (a compiler job first) | 5 words; both compilers emit none, so I cannot say whether they are worth their space |
| C17 | The vector family: 12 base mnemonics (40 words) that no compiled kernel uses, and the widening and narrowing memory words (175 words, 34 used) | a lane-type field in the block header plus a separate convert | **needs measurement** | up to 40 words at once; the memory words are 48% of the family |
| C18 | The atomics (24 words) | nothing covers them | **keep** | they hold 16 first-parcel patterns, 0.02% |
| C19 | `ADC`, `SBC` | `ADD` then `SET cs` then `ADD` | **keep** | multi-word arithmetic in one instruction per word; zero use is a fact about C, not about bignums |
| C20 | `SOB` | `DEC` plus `CBNE` (same bytes, one more instruction) | **keep**, and teach the compilers | one instruction a loop; the compilers do not emit it |
| C21 | `ABS`, `MIN`, `MAX`, `MINU`, `MAXU` | compare, branch, move | **keep**, and fix the manual (it calls them aliases; the grammar has them as real four-byte words) | one instruction against three |
| C22 | `BIT`, `BIC` | `AND` into a copy | **keep** | saves the copy when the value is still needed; no compiler uses `BIT` |
| C23 | `ASL`, `ASR` | `SHL #1`, `SAR #1` | **keep** | the register forms duplicate a two-byte `SHL #1`; the memory forms do not; 0.1% of the first parcels at most |
| C24 | `FENCE`, `WFE`, `SEV` | nothing yet (but see section 4) | **keep** | `FENCE` goes if device stores are ordered (section 4) |
| C25 | `MOVQL` (ten bytes) | the literal pool | **keep** | measured earlier: none executed in 6.5 M instructions; ten bytes is paid once per hoisted constant |
| C26 | `SPL` beside `MTPS` | read-modify-write of the status word | **keep** | one instruction that cannot clobber the flags |

**Top five by payoff**, if the owner takes my recommendations: (1) C1, the deferred-fault loads; (2) C11, the flags class, as a measured experiment (largest if it wins, uncertain); (3) C12, the three-register ALU (the biggest saving in instructions executed that I found); (4) C10, the unaligned moves, through a hardware promise; (5) C9, one user-memory mechanism, together with C1 (the user-qualified loads and the deferred loads between them hold 9.8% of the first-parcel space; with C1 gone and `.U` moved to longer prefixes the whole group can shrink from 9.8% to about 3 to 5%).

## 2. One short argument for each candidate

### C1. The deferred-fault loads (`MOVx.D`, `MOVx.UD`): remove

*What it is.* Seven loads (`MOVQ.D` ... `MOVZB.D`) and seven more that are also user-qualified (`.UD`), in three addressing forms, in 4 and 6 bytes. A `.D` load that faults does not stop the program: the kernel marks the register poisoned *in the saved state* and goes on, and the fault is taken later, at the instruction that writes the flags from a poisoned source. The idea is to let a compiler hoist a load above the test that guards it.

*Why it is doubtful.*
1. **Nothing uses it.** pcc and LLVM never emit it; no test in the repository needs it; the reference executor refuses it (`docs/sim64.md` lists `movX.d` and `movX.ud` as unimplemented). It is not a measured want; it came from a study proposal.
2. **It adds hidden state**, which the design says it refuses: a poison mark per register that has to survive a context switch, a rule for every instruction that reads a poisoned register, and a rule for the flags. "The machine has no hidden instruction state a program can see" is the opening rule of the instruction-set chapter; this is a counter-example waiting to be specified.
3. **The job it does is done by the core.** A core that wants to run a load early does so itself and cancels the fault if the branch goes the other way; an in-order core has nothing to hoist. A *compiler-visible* speculative load exists for in-order machines that cannot speculate by themselves. *From memory, not verified:* Itanium had exactly this (a "not a thing" bit on each register, set by a speculative load) and it is generally counted among the reasons its compilers were hard; I would read the Itanium manuals before the owner reads this line as a verdict.
4. **It is a security surface**: a poisoned value that flows into an address is a new way to carry a secret out of a failed access, and it would need its own test in the security corpus.

*Before and after.* There is no "before" in compiled code. A hand-written guard is `CBEQ rp, #0, skip ; MOVQ (rp), rd`; with `.D` it is `MOVQ.D (rp), rd` and a later flags-writing use. The `.D` form saves one branch in a loop only if the branch is unpredictable and the core cannot speculate, which is the one case that the principle of "one binary on every implementation" says not to design for.

*What it costs to remove.* No bytes, no instructions executed, no run time (zero uses). *Space freed:* the three load leaves that carry `.D` and `.UD` hold 9.8% of the first-parcel space together with the `.U` forms (prefix 5, 6 and 8, 10 bits); with only the seven `.U` words left the same leaves need about 4.7%, so removal frees **about 5.1%**, which is as much as the whole free space today.

*Other architectures.* Itanium (above, from memory). x86 and AArch64 have no such load; they speculate in hardware. RISC-V has none.

*Safety effect.* Removes a hidden-state rule and a side-channel surface; nothing it protected exists.

*Recommendation.* **Remove.**

### C2. `TRAPCC.cc`: remove, the compare-and-trap family replaces it

*What it is.* Fourteen two-byte words, one for each condition, that enter the kernel (vector 16, "check") when the flags satisfy the condition. It is a **trap**: the instruction completes and the saved address is the next instruction.

*What covers it.* Two later families. `CTcc rs, rb` (fourteen conditions) and `CTcc rs, #imm12` compare and trap in one instruction without touching flags and without reading them; `CTEQ rs` and `CTNE rs` are the trap-if-zero; `CHK2` is the two-bound check. `ADDV`, `SUBV` and `MULV` are the add, subtract and multiply that trap on signed overflow. The saved address of a `CT` is the instruction itself (a fault), so the handler finds the site in the table of check sites (`docs/encoding-work/check-instructions.md` section 4); `TRAPCC` has no table and the next-instruction address.

*Before and after.* Index check: `CMP r1, #100 ; TRAPCC.HS` (two instructions, four bytes, flags overwritten) against `CTHIS r1, #100` (one instruction, four bytes, flags untouched). Overflow check: `ADD r2, r1 ; TRAPCC.VS` against `ADDV r2, r1`.

*Cost of removing.* None measured: pcc does not emit `TRAPCC` and LLVM's check pass uses the `ct` words (`PDP64CheckFold.cpp` in the LLVM tree). What TRAPCC alone does is trap on flags set by an instruction that is not an add, subtract or multiply (a flag set by a shift, by `FCMP`, by `TST`): a hand-written assert after a floating-point compare. That is `CBxx` over a `BPT`, one more instruction in a rare place.

*Space.* 14 × 2^-16 = 0.02% of the first parcels: small. The payoff is that there is one way to trap on a condition, one vector, one rule on whether the saved address is the instruction or the next one, and no instruction that reads the flags to decide to enter the kernel (a flag-reading trap is an extra way for a stale flag to matter).

*Other architectures.* x86 has `INTO` (trap if overflow) and AArch64/RISC-V have nothing like it for flags; compare-and-trap exists on MIPS (`TEQ`, `TNE`, `TGE`, `TLT`...) and POWER (`TW`, `TD`), *from memory, not verified*. The repository's own study (`bounds-check-isas.md`) read LoongArch's `ASRT`.

*Recommendation.* **Remove** (keep `BPT`).

### C3. `CBPL`, `CBMI`, `CBVC`, `CBVS`: remove

*What it is.* Four of the fourteen conditions of compare-and-branch, in the two-register and register-immediate leaves (8 forms, 4 and 6 bytes).

*Why it is redundant.* After the subtraction `a - b`, "plus" and "minus" test the sign bit of the difference and "no overflow" and "overflow" test the V flag. For a *branch on a comparison*, the sign of the difference differs from "greater or equal" and "less than" only when the subtraction overflowed, so `CBPL`/`CBMI` are `CBGE`/`CBLT` with a bug in the rare case. The flag branches `BPL` and `BMI` have a real use (after `TST` and after floating-point compares, which write N and V by their own rule: `docs/codegen-data/instructions_used.csv` says `bpl` is "used only after floating-point compares"), but compare-and-branch never follows a floating-point compare, because it compares integer registers only. `CBVC`/`CBVS` branch on overflow of a subtraction, which `SUBV` traps on, and nobody branches on it.

*Data.* pcc emits none, LLVM emits none (it uses `cbeq cbne cblt cbge cbgt cble cbhi cbcs cbcc cblos`: the ten of the fourteen that carry meaning). The four are in the grammar only because the condition numbers of `SET` were reused for the branch.

*Cost of removing.* Nothing: no program, no byte. *Space:* the two leaves that hold them are 0.59% of the first parcels together.

*Safety.* A branch that is "less than, unless it overflowed" is an attractive mistake, and the safe spelling is the only one left.

*Recommendation.* **Remove** the four words; keep them in the *flag* branches where they have a use.

### C4. `MTDMW` and the direct-mapping windows: remove until they exist

*What it is.* An instruction that writes a window register, and two system registers `DMW0`, `DMW1` (plus the guest's copies `GDMW0`, `GDMW1`). The manual says in four places that the windows are "stored and have no effect on translation", and that their format is deferred until a kernel needs one.

*Why it is doubtful.* It is a register that does nothing, with an instruction to write it, a privilege rule, a hypervisor rule ("always exits, exit code 12": no trap bit turns it off) and four more registers for the guest. The principle "an instruction does what its name says and nothing else" is met trivially, but "nothing" is not a feature, and a rule that takes a hypervisor exit for a write that has no effect is cost with no benefit.

*Cost of removing.* None; nothing can have used it. The numbers stay reserved so that a later version can define them (a read of an unassigned system register is already an illegal instruction).

*Space.* One slot of `SYSR-1` (0.05%); the four registers and the exit rule are the real saving.

*Recommendation.* **Remove** `MTDMW`, `DMW0`, `DMW1`, `GDMW0`, `GDMW1` from the instruction set and the register list; define them when the first kernel needs a window, with the format in the same change.

### C5. Stale names

* `WAIT` is an assembler alias of `WFE`. The chapter on what is refused lists the PDP-11 `WAIT` among the instructions the machine refuses. One of the two is wrong; removing the alias makes the chapter true, and an alias that means a different instruction from the one the student remembers is a trap for exactly the reader the manual is written for.
* `SYSPG0` to `SYSPG5` are named placeholders for unassigned first parcels (they sit in the list of words that only the prefix-coded encodings have). `SYSPG2` is the word that `GENTER` uses (the manual says so in a comment). A reserved pattern needs no name; a name makes it a thing to be listed, checked and tested.

*Recommendation.* **Remove** both. Also note two spellings that are harmless but double the words: the old floating-point names (`FADDD`, `FADDS`, `FMADDD`, ... about 40 aliases of `FADD`, `FADD32`, `FMADD`, ...) and `MULU` (an alias of `MUL`, in a manual that says a distinct unsigned low multiply is refused). I leave those to the owner; "mnemonics are cheap", but each is a line the manual and tests carry.

### C6. `MFCPUID`, `MTASID`, `MFASID`: merge into `MFSR` and `MTSR`

*What it is.* Three one-parcel privileged words, each the short spelling of a system-register move that exists anyway: `CPUID` is system register 12 and `ASID` is system register 11, and the manual says `MTASID`, `MFASID`, `MTSR` and `MFSR` of `ASID` all do the same.

*Why it is redundant.* The two spellings multiply the rules: each is listed as privileged, each has its place in the hypervisor's trap-control table (the table counts the register "by `MTASID`, `MFASID`, `MFSR` or `MTSR`"), each needs its own test. `MFCPUID` is read once per core at start-up (the entry itself says "the kernel reads it once and keeps it"), and `MTASID` once per process switch.

*Before and after.* `MTASID r3` (2 bytes, 1 instruction) becomes `MTSR asid, r3` (4 bytes, 1 instruction): two more bytes and no more instructions, once per context switch. `MFCPUID r1` becomes `MFSR r1, cpuid`: two bytes once per boot.

*Space.* 3 × 0.049% = 0.15% of the first parcels; the rest of the saving is four paths becoming two in the hypervisor text.

*Recommendation.* **Merge.** (`MTDP`/`MFDP` and `MTPS`/`MFPS` are *not* in this group: the thread pointer and the flags are used by user code, and system registers are privileged.)

### C7. `FMSUB`, `FNMADD`: merge into `FMADD` and `FNMSUB`

*What it is.* The four fused multiply-add words in each of three widths (12 words): `a*b+c`, `a*b-c`, `-(a*b)-c`, `-(a*b)+c`, each rounded once. The vector family has only two (`vfma`: `d += a*b`, `vfnma`: `d -= a*b`).

*Why it is redundant.* `a*b-c` is `a*b+(-c)`: negating an operand is exact, so `FMSUB(a,b,c)` is `FMADD(a,b,-c)` bit for bit, at the price of one `FNEG` when `c` is still needed. `-(a*b)-c` is `-(a*b+c)`: the same with the negation on the result, apart from the sign of an exact zero (and a NaN, which is the canonical one anyway); I have *not* checked the sign-of-zero case against the rule in the manual, and that is the one thing to settle first. The two forms that earn their place are `a*b+c` and `c-a*b`, the update step of every dot product and every elimination loop (`y -= a*x`), and they are exactly the vector pair.

*Data.* No compiled code uses any of them (pcc does not contract `a*b+c`; LLVM's pdp64 programs in my corpus have no fused operation), and the vector words that LLVM does emit use `vfma` 33 times and `vfnma` twice in 31 kernels.

*Cost.* One extra instruction in the rare `a*b-c` or `-(a*b)-c`; none otherwise. ARM and RISC-V keep all four (*from memory*; the repository's own best-of-breed documents list the integer and atomic sets, not the FMA set); x86 has three orderings of three operands (*from memory*).

*Recommendation.* **Merge** to `FMADD` and `FNMSUB`; needs the sign-of-zero check and a count of `a*b-c` in some floating-point program first (I had none). About 0.2% of the first parcels.

### C8. `binary16` arithmetic: merge into convert-only

*What it is.* Seventeen words for the 16-bit float: add, subtract, multiply, divide, square root, compare, classify, four fused multiply-adds (11 arithmetic words) and six conversions (to and from `binary32`, `binary64` and the 32-bit integer).

*Why it is doubtful.* The scalar half-precision arithmetic has no user in the repository. No compiler here accepts a 16-bit float type (`instructions_used.csv`: "no C type for it"), the vector family has no half lane arithmetic (`vec` has `.f` and `.d`), and in machine learning the half is a *storage* format that is widened, computed in 32 bits and narrowed.

*What covers it.* Every value of `binary16` fits exactly in `binary32`. For add, subtract, multiply, divide and square root, computing in `binary32` and rounding once to half gives the correctly rounded half result: double rounding is harmless when the wide format has at least 2p+2 bits (24 against 11 here: 24 ≥ 24). *This is a known theorem (Figueroa, 1995); I am quoting it from memory and have not read the paper here.* For compare and classify, widen and use the 32-bit word (exact). The fused multiply-add is *not* covered by the same theorem and needs a wider format or its own word.

*Before and after.* `FMUL16 r2, r1` is `FCVTHS r1, r1 ; FCVTHS r2, r2 ; FMUL32 r2, r1 ; FCVTSH r1, r1`: four instructions for one, if the values are not kept wide. A loop that works on half-precision data keeps the values wide for the whole loop and pays only the conversions at the loads and stores, which the vector family already does for its integer widths.

*What it costs.* Hardware verification and gates removed: a half-width multiplier, divider and adder (small units, but each is another corner for the exception flags). Run time: a tight half-precision scalar loop gets longer, and none exists here to measure.

*Other architectures.* RISC-V has a conversion-only half extension and a full one (`Zfhmin`, `Zfh`); AArch64 has the full set from v8.2; x86 has conversion-only (`F16C`) until the recent AVX-512 FP16 (*all from memory, not verified here*). The existence of the conversion-only RISC-V profile says someone else judged the same split reasonable.

*Recommendation.* **Merge** to conversion-only unless the owner has a half-precision loop in mind; the measurement that would reverse it is a scalar `binary16` kernel that the vector words cannot take.

### C9. `STUA`/`CLUA` beside `.U`: choose one way to touch user memory

*What it is.* Two mechanisms for one need, a kernel reading or writing a user address. (a) `STUA`/`CLUA` set and clear a bit `UA` of the status word that opens the user pages to every kernel access; a copy is a `STUA`, the copy, a `CLUA`. (b) the `.U` qualifier makes one load or store behave as a user-mode access, so that the permission cannot outlive the instruction or leak through an interrupt. The entry for `.U` says the two are kept until the OpenBSD port confirms which one it needs.

*Why it is doubtful.* One mechanism is enough, and two mechanisms must be specified, tested, trapped in the hypervisor and kept from disagreeing (an interrupt arriving while `UA` is set, the saved status word, `RTI`, `ECAUSE` bit 15). (b) is the stronger design by the safety ladder: the guard cannot be left open. What stops dropping (a) today is the **block operations**: `MCPY`, which is how a copy-in or copy-out is done, has no user-qualified form, so a copy needs the guard open.

*What it would take.* Either a user-qualified block copy (a way to say "this pointer is a user pointer" to `MCPY`; `MCPY.U` as a second word, or a status-word bit that lives for one instruction), after which `STUA`/`CLUA` and the `UA` bit go; or keep (a) and drop (b), which frees about 4.7% of the first-parcel space (the `.U` leaves) but gives up the leak-proof property.

*Other architectures.* x86 has `STAC`/`CLAC` (SMAP), AArch64 has `PAN` with the unprivileged loads `LDTR`/`STTR` (both, which is where this design came from; *from memory*, and the repository's study is `docs/study-proposals.md` item 18).

*Recommendation.* **Merge**: keep `.U`, add the user-qualified block copy, remove `STUA`, `CLUA` and `UA`. This needs the kernel port's `copyin` to be written both ways once; it is not a decision I can make from data.

### C10. The explicit unaligned moves (`MOVUB`, `MOVUW`, `MOVUL`, `MOVUQ`): merge by promise

*What it is.* Four words, in both directions, that read or write a value at an address that is not a multiple of its size, as two accesses in a defined order. The ordinary moves fault on a misaligned address.

*Cost today.* 4.1% of the first-parcel space (the third and fourth load leaves in each addressing mode, and half of the store leaves), the largest single hole in the base set. Zero use: pcc copies packed structures a byte at a time, LLVM does not emit them, and no test needs them beyond their own.

*What would cover it.* One promise in hardware: **a plain load or store at any address works**, as it does on x86 and, in normal memory, on AArch64 (*from memory*). The compiler then loads a packed field in one instruction; the explicit forms disappear; the alignment fault disappears from the ordinary moves. The cost is hardware: an access that crosses a cache line or a page needs two cache accesses and, at a page, two translations, and the fault on the second half must still leave the first half unwritten (a store that faults must be precise); the rule that an aligned access is atomic stays and the misaligned access is "two accesses, not atomic", which is what `MOVU*` says today. RISC-V leaves misaligned access optional (a core may trap and let software do it), which is the opposite of "one binary on every implementation"; I read that as a warning about *not* promising, not as a precedent for promising.

*Why this is a decision for the owner and not a measurement.* The packed-struct and network-header case wants the promise; the in-order core's gate count and the page-crossing rule want the refusal. The atomics already refuse a misaligned address on purpose (a split atomic is a known performance and security flaw), and I keep that: the promise is for plain moves only.

*Recommendation.* **Merge** into plain moves if the owner accepts the hardware promise; otherwise **keep**, and move the four words to longer prefixes, since no code uses them.

### C11. The flags class: a single experiment

*What it is.* `CMP` (15 forms), `TST` (10 forms), the 14 flag branches (three leaf families), `SET` (compare into a register), `TRAPCC` (C2), the flag-writing forms of the ALU, and `FCMP` which writes N, Z and V. Plus the flag state itself: in the status word, in every saved context, in the hypervisor's world switch, and, in a faster core, a hazard (the PDP-11's flags are written by almost every instruction).

*The numbers.*

| | pcc static (370,115) | LLVM static (64,266) | zlib, LLVM (14.5 M) | crypto, LLVM (12.9 M) | crypto, pcc (12.2 M) |
|---|---|---|---|---|---|
| `CMP` + `TST` | 32,427 (8.76%) | 0 | 18,418 (0.13%) | 0 | 0 |
| flag branches | 36,034 (9.74%) | 4 | 18,418 (0.13%) | 0 | 0 |
| compare-and-branch | 0 | 5,217 (8.12%) | 2,678,578 (18.46%) | 152,031 (1.18%) | 245,375 (2.02%) |

(The 18,418 `CMP` and flag-branch pairs in the zlib run are the assembler's fallback for a compare-and-branch that no form reaches; 0.13% of the run.) pcc's dynamic profile of the crypto program has no flag branch at all, because the crypto code is straight-line; I have no dynamic profile of pcc on a branchy program (section 5).

*What it says.* The LLVM back end shows that the machine can be programmed with no flag instruction at all: no `CMP`, no `TST`, no flag branch. pcc keeps flags because the earlier decisions kept them and because they are the PDP-11's. The cost of compare-and-branch is bytes: a one-parcel `CBEQ`/`CBNE` against zero (two bytes) is as short as `TST` plus a branch is not, but a compare against a register or a wide immediate is four to six bytes, against `CMP` (two bytes) plus a branch (two) = four. Both compilers are valid, and one of them is the standard target the project has named (the LLVM back end).

*What removal would take away.* The 18.5% of pcc's instruction set that touches flags, a state variable in the context switch and in the hypervisor, `SET`'s dependence on flags, and the question "which instructions write which flag" that every future implementation has to answer. It would add: a compare into a register (`SLT`-style) for the floating-point compare, a branch-on-carry or a carry-out idiom for `ADC`/`SBC` and the add-with-overflow tests, and wider compare-and-branch reaches.

*The experiment, not a guess.* Make pcc form a compare-and-branch for **every** comparison (it already has the path and falls back to `CMP`+`Bxx` when no form reaches), assemble the same corpus, and count bytes and instructions; then run the three dynamic programs and the six large ones. If the corpus grows by under about 1% in bytes and shrinks in instructions executed, flags are a feature kept for heritage alone; if it grows by several percent, they are earning their place. `docs/codegen-data/pdp64-after-errata39.csv` records an earlier cousin of this experiment (sites that relied on flags left by an earlier instruction: 2,908 before a change, 3 after).

*Recommendation.* **Needs measurement**, as above. This is the biggest class in the instruction set and the one where the owner's own principles (fewer instructions, density) and the owner's heritage point in different directions; I would not remove it without the numbers.

### C12. Three-register integer ALU (a missing form)

*What it is.* The integer ALU is two-operand: `ADD rm, rd` computes `rd = rd + rm`. To compute `x = a + b` with both still live, the compiler writes `MOVQ a, x ; ADD b, x`. (Only `LEA` with an index and a few words in the four-byte `R3` leaf are three-operand.)

*The numbers.* In my LLVM corpus **8,411 of 64,266 instructions (13.1%) are register-to-register `MOVQ`**, and **3,421 (5.3%) are a `MOVQ a, b` immediately followed by an ALU operation on `b`** (`AND` 1,147, `SHR` 862, `SHL` 420, `XOR` 336, `ADD` 227, `SUB` 170, `MUL` 168, `BIS` 60, `BIC` 21, `SAR` 10). pcc has the same pressure: `MOVQ reg,reg` is 12.5% of its static instructions, and the pair "move then call" (3.0%) is already fused into `MOVCALL`. Bytes would not change: the pair is `MOVQ` (2) + op (2), the three-register word (`R3`) is 4. What changes is **3,421 fewer instructions fetched, decoded and executed** (5.3% of this corpus, as an upper bound: a move that is a call argument or a phi copy is not removable).

*What it would take.* A 4-byte leaf of the shape of `R3` for `AND`, `BIS`, `XOR`, `ADD`, `SUB`, `SHL`, `SHR`, `SAR`, `MUL` (nine sub-opcodes): the optimiser would price it; I estimate a prefix of 10 to 12 bits, 0.1% to 0.4% of the first parcels. A shift with an immediate (`SHR rd, rs, #k`: 862 of the pairs) is a different leaf with a 6-bit immediate.

*Other architectures.* RISC-V and AArch64 are three-operand, x86 is two-operand with a separate `LEA`, x86's own VEX forms added three-operand versions of the vector ALU for this reason (*from memory*). The repository's comparison against other machines, `arch-comparison.md`, measures static size only.

*Recommendation.* **Needs measurement:** run the pair counter on pcc's output and on the large programs (I did only the LLVM static corpus), and ask the compiler to use the three-register word; if more than a few percent of executed instructions go, it is the largest instruction-count win available.

### C13. `PROBER`, `PROBEW`

*What it is.* Two words from the VAX: "is this user address readable or writable? write 1 or 0, take no fault". The manual says they replace the `nofault` global in the copy routines.

*Why it is doubtful.* With `.U` loads and stores and a table of fixup addresses (the design for user copies), a copy tries the access and the handler repairs or rejects it. Probe-then-access has a gap between the probe and the access in which another core can unmap the page (check, then use), which is the reason fixup tables replaced it in modern kernels (*from memory: Linux uses range checks and exception tables*). Two more hypervisor rules go with it (a stage-2 miss during a probe always exits).

*Recommendation.* **Needs measurement**: whether the OpenBSD port's `copyin` and `copyout` and a debugger's memory read use a probe at all. If they do not, remove; if they do, keep and write down that a probe is advice, not permission.

### C14. The absolute address mode

*What it is.* The `A32` leaves: an operand that is a 32-bit absolute address, six bytes, in loads, stores, compares and single-operand ops.

*Data.* `docs/codegen-data/shapes_pdp64.csv`: **one** absolute operand in 370,115 instructions of pcc (against 107,102 PC-relative ones); none in LLVM's output; the position-independence rule makes every access to code or data in the same module PC-relative.

*Space.* 2.0% of the first parcels (0.78% + 0.39% + 0.10% + 0.05% for loads, 0.59% for stores, 0.10% compare, 0.02% single-operand). Large for a mode compiled code does not emit.

*Why it may still be right.* The C64 and PDP-11 heritage is "peek and poke": a driver writes a device register at a fixed address, and device registers are far from the code. But the register-mapped devices of this machine are reached through a base register (the bus chapter), and `LEA` plus a base reaches anywhere.

*Recommendation.* **Needs measurement:** count the absolute operands in the OpenBSD port's drivers and in the hand-written assembly of the kernel survey (`docs/codegen-data/kernelasm/`, which covers other machines only). If they are rare, move the mode to a longer prefix (it would cost a few hundredths of a percent) instead of removing it.

### C15. The tag branches `BTAG`, `BNTAG`, `JTAG`

*What it is.* Branch if the low three bits of a register equal a tag, branch if they do not, and dispatch through a table indexed by the tag. For a Lisp, Python or OCaml runtime.

*Data.* Zero in every corpus (none is a C program with tagged pointers). The first parcel space is small (about 0.11%).

*What covers it.* `AND` into a scratch register and `CBEQ` against the tag: three instructions where `BTAG` is one (copy, mask, branch).

*Other architectures.* SPARC had tagged arithmetic instructions in V8 and deprecated them in V9 (*from memory, not verified*); no mainstream ISA has a tag branch. The manual's own list of refused features names "hardware tag checking", and `BTAG` is its small cousin.

*Recommendation.* **Needs measurement**: an interpreter's dispatch loop on pcc, with and without. Without a user it is a word kept for a runtime that does not exist yet.

### C16. `MASKEQZ`, `MASKNEZ`, `BSEL`, `SET`

*What it is.* The select family: a result that is zero unless a condition on a register holds, a bit-by-bit select under a mask, and the compare into a register. They give branch-free selection, which a constant-time cryptographic routine needs.

*Data.* Neither compiler emits `MASKEQZ`, `MASKNEZ` or `BSEL` in any corpus (my SHA-256 and SHA-512 compile with shifts and `AND`/`BIS` where `BSEL` would do `Ch` and `Maj` in one instruction each); `SET` is zero in LLVM and appears in pcc's tests only.

*Recommendation.* **Needs measurement, and a compiler job first.** `BSEL` is obviously right for SHA and I would keep it; the others should wait for a user.

### C17. The vector family

*Data* (`vector-usage.md`, 31 kernels, 365 words, 65 base mnemonics): **12 base mnemonics (40 words) are never emitted** by either build: `vec2`, `vskip`, `vfin`, `vlseg3` (22 words), `vabdu` (2), `vfmab` (2), `vdot`, `vdotu`, `vdotsu` (4), `vtbl`, `vfir` (3), `vclr` (3). Some are used by hand-written kernels (`vfir`, `vclr`); the kernels were written by the same study that chose the words, so "used" is biased upwards. The **memory words** (`vld`, `vst`, `vldt`, `vstt`, `vlseg2`, `vlseg3`, `vlseg4`, `vsseg2`, `vsseg3`, `vsseg4`) are 175 of the 365 words, and the kernels use 34 of them (19%).

*What multiplies the words.* Each memory word is the product of an element width, a signedness and a widening or narrowing target (`vld.bu.l`: load unsigned bytes, widen to 32 bits), and again for each of three segment counts. The same effect with one lane-type field in the block header and the existing `vcvt` words would make most of the 175 disappear.

*Recommendation.* **Needs measurement:** a second study of the family after the vectoriser has seen real programs, not only the study's kernels; I would not remove words on this evidence, but I would read the 22-word `vlseg3` before it is implemented again. The wave-1 decisions already removed the tile and whole-GEMM forms; this is the next candidate list.

### The ones I checked and keep

* **C18. The atomics (24 words).** They hold 16 first-parcel patterns in all (11 used), so removal buys no space. The census of the 4,225 kernel modules says what the family is for: `or` 7,822, `xadd` 7,602, `inc` and `dec` 7,076, `and` 5,022, bit set/reset/complement 5,899, `cmpxchg` 1,970, `add`/`sub` 2,155, implicit exchange 51, and `xor` **20** (0.05%): `XXOR` is the least-used word and it costs a sub-opcode and nothing else. There is no x86 count for `max` and `min` (x86 has no such instruction); RISC-V and AArch64 do, and the repository's best-of-breed study chose the RISC-V list. Keep; nothing to merge, and the `LL`/`SC` pair is what makes the others redundant on an LL/SC machine, not the other way round.
* **C19. `ADC`, `SBC`.** Zero in all corpora because C has no carry. A multi-word add loop is one `ADC` a word if `SOB`/`INC`/`DEC` leave the carry alone (they do: `C` is unchanged); without `ADC` it is `ADD`, `SET cs`, `ADD`, a handful of instructions a word. Keep; measure on a bignum routine to be sure it is not a clean loss.
* **C20. `SOB`.** Four bytes, like `DEC` plus a one-parcel `CBNE` against zero, with one instruction fewer. Neither compiler emits it (the instructions-used list says so for pcc; LLVM has no pattern). The saving is one instruction a loop iteration, which is exactly what the principle on instruction count asks for; the work is in the compilers.
* **C21. `ABS`, `MIN`, `MAX`, `MINU`, `MAXU`.** One four-byte instruction against compare, branch and move. The manual calls them "assembler aliases, not native instructions"; the grammar has `abs` in the two-register leaf and the other four in the three-register leaf as real words. One of the two statements is wrong and the manual is the one that needs the fix. Zero in my corpora (LLVM does not select them; pcc has a test for them).
* **C22. `BIT`, `BIC`.** `BIT` is `AND` that does not write its result. With two-operand ALU forms a test `(x & mask) != 0` needs a copy of `x` (`MOVQ`, `AND`, branch) unless `BIT` is used (`BIT mask, x`, branch), so it saves one instruction exactly where `x` stays live. Neither compiler emits it (pcc: "idiom"). The compiler gap is the finding.
* **C23. `ASL`, `ASR`.** For a register they duplicate a two-byte `SHL #1` or `SAR #1` (and set `V` where `SHL` clears it); their memory forms are the only shifts that work on a memory operand. 653 static uses in pcc, none in LLVM, none dynamically. 0.1% of the first parcels; not worth the argument.
* **C24. `FENCE`, `WFE`, `SEV`.** `FENCE` orders device accesses (cores need nothing: memory is sequentially consistent). See section 4 for how to make it unnecessary.
* **C25. `MOVQL`.** Measured earlier: 0 executed in 6.47 M instructions of 26 programs; 44 static sites in 9,955 instructions (0.44%). The literal pool covers the rest. Keep.
* **C26. `SPL`.** Raises or lowers the interrupt priority without clobbering the flags; the alternative is read, mask, write the status word (four instructions).

## 3. What the core looks like after

If the owner accepts C1 to C10 as recommended, the instruction list loses about 66 words (14 + 14 + 4 + 1 + 7 + 3 + 6 + 11 + 2 + 4, where C5 counts seven names) and about 10% of the first parcels come back (5.1 for C1, 4.1 for C10, 0.6 for C3, 0.2 for C7, and a few hundredths each for the `TRAPCC`, `DMW` and `SYSR` slots); `.U` moved to a longer prefix would add up to 3 more. What stays is a set a student can hold:

* **Moves**: `MOVQ MOVL MOVW MOVB` (loads sign-extend, stores truncate), `MOVZL MOVZW MOVZB`, `LEA`, `MOVQL`, the pool; the one-parcel hot forms; `PUSH POP PUSHM POPM`.
* **ALU**: `ADD SUB AND BIC BIS BIT XOR CMP MUL MULH MULHU`, the shifts and rotates, `COM NEG INC DEC CLR TST ADC SBC ASL ASR`, `DIV DIVU MOD MODU`, `ABS MIN MAX MINU MAXU`, `SET`.
* **Control**: `BR`, the flag branches, the ten compare-and-branch conditions, `SOB`, `JMP CALL RET`, `JMPI CALLI`, `TRAP TRAPL RTI RTT`, the four fused pairs, `ADDV SUBV MULV`, the `CT` family.
* **Memory system**: all the atomics (`CAS`, `SWAP`, the fetch-and-operate words, `LL`/`SC`), `FENCE`, `WFE`, `SEV`, the block operations, `TLBI` family, `ICINV`, `.U`.
* **Floating point**: `binary32` and `binary64` arithmetic, compare, class, the roundings, `FMADD`, `FNMSUB`, `FNEG`, `FABS`, `FMIN`, `FMAX`, `FCOPYSIGN`, the conversions, six half conversions.
* **Bit and text**: `CLZ CTZ CLO CTO POPCNT BSWAP* BITREV ROR RORI RORI32 EXTB EXTZB INSB DSHR XNORPOP CLMUL* UTF8* BSEL` and the AES and SHA words (the secure-mode set).
* **Vector blocks**, unchanged until the second study.

What is clearly solid (used by every program, or the thing that makes a class of bugs impossible): `MOVQ`, `MOVL`, `MOVZB`, `MOVZL`, `LEA`, `ADD`, `SUB`, `AND`, `BIS`, `XOR`, the shifts, `CLR`, `PUSH`/`POP`/`PUSHM`/`POPM`, `CALL`, `RET`, `BR`, the compare-and-branch family, `MUL`; the fused pairs (pcc executes 91,435 of them in the crypto program, 0.75% of its instructions, saving two bytes each); `RORI`, `RORI32` and `BSWAP` (the hash and cipher programs use them: pcc executes `RORI32` 918,400 times, 7.5% of the crypto program); `MCPY` and its kin (libc); the system words a kernel cannot do without; and the safety instructions (`CT*`, `ADDV`, `LPAD`, `PROBE` pending C13).

A data point on the compiler side that the owner will want, because it is the biggest difference I measured between the two back ends: on the crypto program **pcc executes 12.17 M instructions and LLVM 12.88 M** (LLVM 5.8% more), and the reason is `RORI32`: pcc emits it 918,400 times and LLVM, which has no pattern for it, writes the rotate as `SHL`, `SHR`, `BIS` (three instructions, or four with a copy). That is a compiler gap, not an instruction-set question; it is the sign that a zero in the LLVM column does not by itself condemn an instruction.

## 4. Guarantees that would remove more instructions (the hardware side)

Each is a promise the hardware keeps so that software has less to do, in the same spirit as the sequential-consistency decision. I give the class it removes, the cost, and the state of my evidence.

| # | Promise | Removes | Cost | Evidence |
|---|---|---|---|---|
| G1 | A plain load or store at any address works (an access that crosses a line or a page is two accesses, not atomic; atomics still require alignment) | `MOVUB`..`MOVUQ` (C10), the alignment fault, the byte-copy code for packed structs | two cache accesses and, at a page, two translations and a precise fault for each half | the words are unused here; the cost is not measured (no gates) |
| G2 | **Instruction fetch sees every store** (the instruction cache is kept coherent with data stores, as on x86) | `ICINV`, `ICINVA`, the user `ISYNC` duty, and the whole "forgot to flush after writing code" class of bug in JIT compilers and dynamic loaders | a compare of every store address against the instruction cache's tags, a snoop port; zero for the in-order first core if the instruction cache is small | none; *from memory:* x86 and s390 do it, ARM and RISC-V leave it to software |
| G3 | **A store to device memory first waits for all earlier stores to be visible** (device memory is strongly ordered, with the DMA hand-off included) | `FENCE`, and the driver bug "set the go bit before the descriptor was written" | a device store drains the store buffer, which makes device writes slower; memory-mapped I/O is rarely hot | the manual says `FENCE` is owed to devices only, one before each doorbell write. *From memory, not verified:* Linux's `writel` already contains the barrier on each architecture and a `writel_relaxed` is the exception, which is this promise made in software |
| G4 | **`TLBI` finishes before it returns**: every core has dropped the entry when the instruction retires | `TLBSYNC`, and the bug "changed a page table, forgot to wait" | the issuing core stalls for each invalidate; today a run of `TLBI` followed by one `TLBSYNC` pays the wait once (batching). The alternative is to wait implicitly at `RTI`/`RTT`/`MTSR PTBR`/`ISYNC`, which keeps the batching and removes the duty | no measurement; the shootdown cost would have to be measured on a multi-core model |
| G5 | `MCPY` is safe for overlapping regions (always a memmove) | `MMOV` (1 word) and the C undefined-behaviour bug class of `memcpy` on overlapping buffers | a direction decision (one pointer compare) and a backward path in the block sequencer; the forward path unchanged | the sequencer is "three counters and a byte-lane selector, about 1,500 transistors" (manual); the backward path is not counted |
| G6 | Every 32-bit result is held sign-extended (or zero-extended) in the register, as RISC-V does with its `W` instructions | the conversion instructions after 32-bit arithmetic: `MOVL reg,reg` and `MOVZL reg,reg` are 8,031 of pcc's 370,115 static instructions (2.2%) | `W`-width ALU words (more words, not fewer: the opposite of the other rows) | static only; the dynamic share is not measured. The single-width ALU is a standing decision; I list this to show its price |
| G7 | The ALU is three-register for the commonest operations (C12) | the move before an ALU operation: up to 5.3% of instructions | one prefix of 10 to 12 bits | measured above (LLVM static) |
| G8 | Condition codes do not exist (C11) | `CMP`, `TST`, the flag branches, `SET`, `TRAPCC`, the flag state in every context | wider compare-and-branch reaches; a compare into a register for `FCMP`; a carry idiom for `ADC` | measured above for what the two compilers use; the size of the effect on one compiler not measured |

The first four are the same pattern as the sequential-consistency decision: *a duty software can forget* (flush, fence, wait) becomes *a thing hardware does*, so that a class of bugs and a class of instructions go together. They are the principle "hardware that encourages software flaws is changed" applied to the four maintenance instructions that remain. G2 and G3 are the cheapest on the first core; G4 is a choice between a stall and an implicit wait.

## 5. What I could not measure

* **No dynamic data for pcc beyond one 12 M-instruction crypto program.** The six large programs of the earlier dynamic study (lz4, zlib, Lua, three BearSSL groups) are not on this machine and the corpus tooling (`tools/pdp64size.py` needs the `v7unix-toolchain` repository) is not either. What I ran: zlib and the crypto set under LLVM, and the crypto set under pcc. A branchy program under pcc would settle C11 and C12 on the compiler that actually uses flags.
* **No floating-point program.** No `FMSUB`, `FNMADD`, half-precision or rounding count exists; C7 and C8 rest on the semantics and the zero-use lists, not on a kernel.
* **No operating-system kernel built for the pdp64.** C9, C13 and C14 need the OpenBSD port's `copyin`, `copyout`, probes and driver assembly; the kernel-assembly survey (`docs/kernel-asm-survey.md`) has other machines only.
* **No dynamic atomic counts anywhere**; the x86 census is static and on another architecture (which the earlier study says too).
* **No gate counts for G1 to G5**; the existing tools count units, not these changes.
* **No run time.** Everything above is instructions, bytes and first-parcel space; the cycle model of `sim64` (`-V`) is for vector blocks. Where a saving is "one instruction fewer", the run time is not shown to follow (principle 2 says run time wins over the proxy).
* **A bug in the toolchain I met, not fixed:** `llc` writes a string with three-digit octal escapes followed by a digit (`"R\tj\32506..."` in Rijndael's S-box) and `as64` refuses the line ("expected one of strch ... found end of input"); I left Rijndael out. It is an LLVM-printer and `as64` disagreement, not an instruction-set matter, but anyone compiling table-driven ciphers with LLVM will meet it.
* **About my LLVM corpus:** it is a sample (205 of about 270 files tried), chosen because the headers happened to compile on the host; it has no floating-point code worth the name, no vectoriser (I turned it off: `-fno-vectorize`), and no variadic calls (the back end refuses them at this stage). It over-represents crypto and string routines against, say, a database or an interpreter.
* **Other machines:** every statement about x86, ARM, RISC-V, SPARC, Itanium, MIPS and POWER above that is not in a document of the repository is marked *from memory*; I did not fetch a primary source for any of them, and C1, C2, C8, C10, G2 and G3 lean on them.

### The recipe, for anyone who wants to redo the corpus

1. Make a directory `inc/` with `machine` linked to `openbsd-src/sys/arch/amd64/include` and `sys` linked to `openbsd-src/sys/sys`.
2. For each C file: `clang -S -emit-llvm -O2 -m64 -fno-builtin -ffreestanding -fno-stack-protector -mlong-double-64 -mno-sse -mno-mmx -fno-vectorize -fno-slp-vectorize -fno-unroll-loops -w -I<its directory> -Iinc -I openbsd-src/sys -isystem openbsd-src/include -idirafter openbsd-src/lib/libc/include (and a few more `-idirafter` for libcrypto) f.c`, then delete the lines `target datalayout`, `target triple` and the `target-cpu`, `target-features`, `tune-cpu` attributes (the same `sed` as `llvm-pdp64/check.sh`), then `llc -mtriple=pdp64-unknown-elf -O2`.
3. Count the first word of every instruction line of the `.s` files; `as64 --stats` gives instruction and byte totals.
4. For the dynamic programs: assemble `.s` to `.o`, link with `ld64` against the five-routine runtime of `tools/pdp64test.sh` (`_start`, `write`, and `memcpy`, `memmove`, `memset` as the block instructions) and a driver that supplies a bump allocator, run `sim64 -P prof prog.x`, and read the profile with `encdis -k prof prog.x` (built from `tools/encdis.c`, `common/pdp64enc.c` and `build/pdp64-tab.c`).
