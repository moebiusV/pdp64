# The check instructions: names, operand forms, the table of check sites (proposed)

**Status: the assistant's proposal, 2026-11-17, for the author to accept, change or refuse.** Errata 144 and 145 decided that the pdp64 gets a **trap-if-zero**, a **two-bound check** and a **compare-and-trap with a table of check sites**, and left "the names, operand forms and encodings", the conditions, what the trap reports, the format of the table and where the kind of check is carried *to be determined*. This record proposes those details so that pcc (decided first, errata 144) has something to emit. Nothing here is in the grammar, the assembler or the compiler; everything below that is not marked as data is a proposal.

## 1. The data that fixes the operand forms

`tools/arch-compare/checksites.py` reads the assembly that pcc's `-xchecks` makes for the 841-file corpus (6,929 checks after the provable ones are dropped, errata 148; the script finds 6,923 of them): `arch-data/pdp64-checksites.txt`.

* **Every check is `cbcs i, #bound, ok`**: an unsigned compare of an index against an array's length, passing when the index is lower. The check that traps is its negation, *trap if higher or same*. There is no other condition in the data, because `-xchecks` checks subscripts of arrays of known size and nothing else.
* **Every bound is an immediate (6,923 of 6,923); none is a register.** 6.2% fit 5 bits (0 to 31), **98.3% fit 8 bits, 100% fit 12 bits** (the largest is 2,484). So the immediate of a compare-and-trap must be wider than the 5 bits of the short compare-and-branch leaves, and 12 bits (the immediate of `CMP`, leaf `CMI12/a`) is enough for everything seen.
* The census is lopsided: 6,144 of the checks (89%) are against one bound, 88, in one project; there are 72 distinct bounds in 142 files. Without that project the other 779 checks are the same kind of site. A language that checks every subscript (Ada, Rust, Go) would add register bounds (a slice's length is a variable); the C corpus has none.

## 2. The instructions (names and operand forms)

The family is named like the compare-and-branch family it mirrors (`cbcc`, `cbcs`, `cbeq`...): `ct` for *compare and trap*, with the same condition names, and the trap happens when the condition holds (as `trapcc.cc` does, and as `BUG_ON` does).

| form | meaning | size | opcode cost (from the prices of J.9.13) |
|---|---|---:|---|
| `ctcc rs, #imm12` (alias **`cthis`**), `cthi rs, #imm12`, `cteq rs, #imm12`, `ctne rs, #imm12` | trap if `rs` compared with the immediate (unsigned for `cc` and `hi`) satisfies the condition. `cthis i, #n` is the bounds check `i >= n`; `cthi i, #n` is `i > n` (an inclusive limit) | 4 bytes | one leaf of the shape of `CMI12/a` with a 2-bit sub-opcode: prefix 13, **8 patterns** (0.012% of the first parcels) |
| `ct<cc> rs, rb`, all fourteen conditions (`cc cs hi los eq ne ge lt gt le pl mi vc vs`; aliases `cthis` = `ctcc`, `ctlo` = `ctcs`) | the same against a register bound | 4 bytes | the register-register group `R2`: **0 patterns** (14 of its free sub-opcodes) |
| **`cteq rs`, `ctne rs`** | **the trap-if-zero of errata 144**: trap if `rs` is zero (the null check), or not zero (`BUG_ON`); the one-parcel shape of `cbeq rs, label` without the label | 2 bytes | a one-parcel leaf with a 1-bit sub-opcode and a 5-bit register: prefix 10, **64 patterns** (0.10%); with a hot register, 32 |
| **`chk2 rs, rlo, rhi`** | **the two-bound check of errata 144**: trap unless `rlo <= rs < rhi`, signed | 4 bytes | the three-register group `R3`: **0 patterns** (51 of its 128 sub-opcodes are used) |

Rules common to all: **no flags are read or written** (so a check can sit between a compare and the branch that uses it); no result; the operands are only read; the compare is unsigned for `cc cs hi los` and signed for `ge lt gt le`; an immediate is zero-extended for the unsigned conditions and sign-extended for the signed ones. Total new first-parcel patterns: about **72** (0.11%); the words in `R2` and `R3` cost none.

*Why these choices.* **`ct` on the `cb` model**: the assembly reads the same, the conditions are already learned, and the one-parcel zero form is the `cbeq`/`cbne` shape (CBZ leaves, 9.10.4). **The trap-if-zero is `cteq rs`, not a separate family**: it is the compare against zero of the same family, in the one-parcel shape that `cbeq` has. **Immediates up to 12 bits, registers for the rest**: the data above. **Immediates only for four conditions**: the corpus needs one (`cthis`); `cthi` (inclusive upper limit), `cteq` and `ctne` (an assertion against a constant) are the other uses seen in the kernel's `BUG_ON` and in Ada's checks; the other ten conditions are available with a register bound at no opcode cost. **`chk2` half-open and signed**: `rlo <= i < rhi` is what pcc's `__builtin_chk2(i, lo, hi)` already means (it compiles to `lea` and `cbcs`), what a C array slice or a Rust range means, and what a loop `for i in lo..hi` means; Ada's inclusive upper bound is a constant adjustment by the compiler (`hi + 1`, which for a constant bound costs nothing). Signed, because an Ada subscript type may have a negative lower bound; an unsigned range with both bounds below 2^63 works with the same word. **Registers for the bounds of `chk2`**: a bound is usually loop-invariant (an array's descriptor) and hoisted; a form with immediates (two 12-bit constants in three parcels, 32 patterns) can be added when the data asks for it, and the corpus has no `chk2` site yet (`-xchecks` makes none).

## 3. The trap

* **A new vector, `check`, number 16** (`spec/pdp64-system.hbnf` lists 0 to 15 and 32 upward; 16 to 31 are unassigned); `ECAUSE` equals the vector number, as for all of them. It is a **fault**, not an abort: precise, the instruction annulled, no state to undo.
* **`EPC` is the address of the check instruction**, not the next one, so that the handler finds the site in the table by address and the check can be re-run or skipped (a warning, as `WARN_ON` in Linux, resumes after it).
* **The length of the instruction** (2, 4 or 6 bytes) is needed to skip it. Two ways: the handler decodes the first parcel (the prefix code gives the length), or the table carries it. The linker relaxes branches and shortens code (`docs/relaxation.md`), which could change a length after the assembler recorded it, so the proposal is that **the handler decodes it**; the table does not carry the length. Open.
* `ctne`, `cteq`, `cthis` and the rest differ only in the condition; the handler does not need to know it (the table's `kind` says what the check meant).

## 4. The table of check sites

The decision (errata 145): the assembler writes a record for every compare-and-trap into a section, so that the handler finds which check failed and the compiler needs no stub. **Proposed format: the 12-byte record of Linux's `struct bug_entry`** (`include/asm-generic/bug.h` with `CONFIG_DEBUG_BUGVERBOSE` and relative pointers, read on this machine in the kernel source: `bug_addr`, `file`, `line`, `flags`), so that the kernel's `report_bug()` finds the sites with no new code:

    .long  site  - .          ; the address of the check instruction, relative to this word (32 bits)
    .long  file  - .          ; the address of the file name string, relative (32 bits)
    .short line               ; the source line
    .short flags              ; as in Linux (WARNING 1, ONCE 2, DONE 4, NO_CUT_HERE 8, ARGS 16, the taint in bits 8 and up); the kind of check in bits 5 to 7, which Linux leaves unused

* **The section** is `__bug_table` (the name Linux's `report_bug()` looks for), read-only, allocated, outside the text; the linker concatenates the sections of its inputs in the order of the instructions, so the table is sorted by address within a module. Linux's `find_bug()` scans it linearly; a handler of the pdp64's own may binary-search it. *A point to settle:* errata 145 says the table is "a section that is not loaded". Linux's `__bug_table` is loaded (the handler reads it). I read the decision as "kept out of the instruction stream and out of the hot memory"; a stripped or unprivileged-only build can drop it. Open.
* **The kind** is in the table, not in the instruction: it costs no opcode bits, the assembler knows it from the directive below, and the kind is not derivable from the instruction (`cthis rs, #n` may be a bounds check or an assertion). The kinds are those of the built-ins (`__chk_fail`'s first argument): 1 bounds, 2 null, 3 range, 4 an assertion.
* **How the assembler learns the file, the line and the kind**: a directive that precedes the instruction and applies to the next `ct`/`chk2`: `.chk KIND, "file.c", LINE`. pcc emits it from the same tree that carries `ftitle` and the line today. Without a directive the record has kind 0 and the line of the assembly source (`.loc`), so hand-written assembly still works.

## 5. Making it work before the encoding changes

The order of errata 144 is that pcc learns first and the instructions are added to the encoding after. For pcc's output to be assembled and measured meanwhile, **the assembler can expand the new mnemonics** (the macro layer of `as64`, `asmpre.c`, is outside the grammar) into what the existing instructions do: `cthis rs, #n` becomes `cbcs rs, #n, .Lok`, then `bpt`, then the label `.Lok:`, with the table record for the address of the `bpt` (the existing vector 15 `bpt` already traps). `cteq rs` becomes `cbne rs, .Lok`, `bpt`. `chk2 rs, rlo, rhi` becomes a subtraction of `rlo` from the value and from `rhi` and an unsigned compare (`cbcs`) then `bpt`, which needs two scratch registers that the expansion must name and costs 5 or 6 instructions with registers (with the constants of `__builtin_chk2` it is the `lea` and `cbcs` of today): a reason for `chk2` to be a real instruction. That is 2 instructions and 6 bytes for a check (against 1 and 4 for the real one, and against the 6 or 7 and about 26 of today's call-and-stub: errata 147), with no stub and a table. The kernel and the loader are exercised on the table before the hardware has the instruction. This needs `as64` to accept the mnemonics (an assembler change in `spec/pdp64-asm.hbnf` and `asmpre.c`, proposed here and not made).

## 6. What pcc would emit

`__builtin_chk(i, n)` and the `-xchecks` subscript check: `cthis i, #n` (or `cthis i, rn` for a variable length); `__builtin_chkz(p)`: `cteq p`; `__builtin_chk2(i, lo, hi)`: `chk2 i, rlo, rhi`; each preceded by `.chk KIND, "file", line`. `__chk_fail` stays as the software form for a target without the instructions. The failure path disappears from the function: no argument set-up, no call, no stub. From errata 147: 7.0 instructions and 26.2 bytes for each check today, 1 instruction of 4 bytes with `cthis`: on the 6,929 checks that is **about 42,000 fewer instructions and 154,000 fewer bytes** than the call-and-stub form (the checked corpus adds 49,049 instructions and 182,008 bytes, 7.1 and 26.3 for each check; one instruction of 4 bytes for each would add 6,929 and 27,716); the measured +16.6% of instructions and +19.0% of bytes would fall to **+2.3% and +2.9%** (the figures of errata 147 for one instruction a check). Not measured with the instruction, which does not exist yet.

## 7. What the author is asked to decide

1. The family: `ct<cc>` on the model of `cb<cc>`, with `cthis`/`ctlo` as aliases; the trap-if-zero as `cteq`/`ctne rs` (one parcel); the two-bound check as `chk2`.
2. `chk2`: signed, half-open `rlo <= rs < rhi`, registers for the bounds first.
3. The immediate: 12 bits, for four conditions (`cc`, `hi`, `eq`, `ne`); registers for all fourteen.
4. The trap: vector 16 `check`, `EPC` the address of the instruction, the length decoded by the handler.
5. The table: the 12-byte `bug_entry` record in `__bug_table`, the kind in bits 5 to 7 of the flags, the directive `.chk KIND, "file", LINE`; and what "not loaded" meant.
6. Whether `as64` expands the mnemonics to `cb..`/`bpt` now (section 5), so that the compiler path and the kernel's handler can be tried before the encoding changes.

Until the author answers, the details stay "to be determined" (errata 144, 145), and what is written here stays *proposed*.
