# Code generation and instruction use: what compiled C says about the ISA

[← pdp64 index](../README.md)

**Status: draft, 2026-10-22.** This document reports what the pcc back end for pdp64 produces on real C, how that compares with gcc and clang on amd64,
and what the instruction mix says about the instruction set. Every number says how it was measured. The measurements are *static* (they count instructions in
the compiler's output, not instructions executed), so they say how much code a program takes and which instructions the compiler chooses, not how fast it runs.

The machine-readable data behind the tables is in [`codegen-data/`](codegen-data/) (CSV, one file per table, and `analysis.json`).

## 1. How it was measured

| item | what was done |
|---|---|
| Corpus | The "fair corpus": 827 C files from nine projects (bearssl 294, c-testsuite 213, gcc-torture 158, mbedtls 101, lua 34, zlib 12, chibicc 8, lz4 5, cjson 2) that every compiler below compiled. Fourteen more files (zlib 3, gcc-torture 11) are accepted by our pcc back ends but not by gcc or clang with these flags, and are left out of every column. The file list, the include directories and the defines are those of `tools/corpus.py` in the v7unix-toolchain repository. |
| Preprocessing | Each file is preprocessed once per header set with the host `gcc -E` against musl headers: pdp64 gets the AArch64 musl set (LP64, little-endian, signed char, the same text as our aarch64 build); the three amd64 columns get the x86-64 musl set. |
| pdp64 | pcc `ccom` from `../pcc` (commit named in section 2) with `-xdmr -xtemps -xdeljumps -xinline -xdce`, then `as64`. |
| pcc amd64 | our own amd64 pcc back end with the same flags plus `-xabs`, for continuity with earlier reports. |
| gcc -Os | `gcc -m64 -fno-pie -fcf-protection=none -std=gnu99 -w -fno-asynchronous-unwind-tables -fno-unwind-tables -Os` (the amd64 entry of `corpus.py`), once with `-S` and once with `-c`. |
| clang -Os | `clang --target=x86_64-linux-gnu -fno-pic -fcf-protection=none`, the same common flags and `-Os`. |
| Instructions | The number of instruction lines of the compiler's `-S` output (for pdp64 the `.s` that `as64` accepts): lines that are not directives, labels or comments. Padding the assembler adds (`.even` no-ops) is not counted. |
| Bytes | text + read-only data + data, no bss, as GNU `size` prints for the x86 objects (text includes `.rodata`); for pdp64 the sizes of `.text`, `.data` and `.rodata` read from the ELF section headers. pdp64 keeps strings and constants in `.text` (so that references to them are 4 bytes), which is why the comparison uses the sum and not `.text` alone. |
| Lengths | pdp64: the `len` bits (15..14) of each instruction's first parcel, walking `.text`; x86: `objdump -d`, bytes between instruction starts (alignment no-ops that gcc and clang insert are included and some assembler lines are not instructions, so the totals differ from the line counts by under 3%). |
| Caveats | The corpus is not representative everywhere. `memcpy-a2.c` alone is 96% of the pdp64 image of gcc-torture (503 KB, against gcc's 390 KB for the file); the c-testsuite and gcc-torture files are small test programs that gcc folds to almost nothing; a few sources repeat the same compare-and-abort test thousands of times, which inflates the call and compare counts. Section 2 therefore also gives the totals without `memcpy-a2.c` and for the seven libraries alone. |

Tools: `tools/pdp64size.sh` is the measurement (`tools/pdp64size.sh --set fair --arch pdp64,amd64,gcc-Os,clang-Os --out DIR --keep DIR/s`); the scripts in `tools/codegen/` turn its `results.json` and the kept `.s` files into the tables below (`analyze.py`, `candidates.py`, `never.py`, `mdtables.py`, `fill.py` with `doc_template.md`; they read and write under `/tmp/p64opt`).

## 2. Code size against gcc and clang

All 827 files, per corpus (instructions are line counts of the compiler output; bytes are text + read-only data + data):

{{totals}}

Summary, pdp64 against the references (same files):

| set | files | instructions / gcc -Os | bytes / gcc -Os | instructions / clang -Os | bytes / clang -Os |
|---|---|---|---|---|---|
| all | 827 | {{r_all_gi}} | {{r_all_gb}} | {{r_all_ci}} | {{r_all_cb}} |
| without `memcpy-a2.c` | 826 | {{r_nm_gi}} | {{r_nm_gb}} | {{r_nm_ci}} | {{r_nm_cb}} |
| the seven libraries only (no c-testsuite, no gcc-torture) | 456 | {{r_lib_gi}} | {{r_lib_gb}} | {{r_lib_ci}} | {{r_lib_cb}} |

The goal set for every pcc target is code within 5% of `gcc -Os` in bytes. On the libraries pdp64 is at {{r_lib_gb}} of gcc and {{r_lib_cb}} of clang; on the whole corpus the figure is
{{r_all_gb}} of gcc, because gcc is far better on the small test programs (it evaluates them at compile time) and on code with data kept in a struct (it keeps the members in registers; pcc keeps them in the
frame). The instruction count is higher than either ({{r_all_gi}} of gcc, {{r_all_ci}} of clang) and the average instruction is shorter (section 3), so the two roughly cancel in bytes.

### How the figure moved in this round

The same 827 files, pdp64 only, one row per compiler change (`../pcc`, `arch/pdp64`); a row's figures include the earlier rows:

| step | commit | instructions | bytes | bytes / gcc -Os | bytes / clang -Os |
|---|---|---|---|---|---|
| start of the round | a0693fb9 | 402912 | 1753184 | 1.167 | 1.088 |
| no frame pointer with `-xdmr` (`pushm`, `sub`, sp-relative locals); signed `int` results are not re-extended (signed overflow is undefined; `<<` and unsigned still are); `int`/`unsigned` conversions no longer retype the operation under them | 0a6f4ed8 | 381032 | 1709620 | 1.138 | 1.061 |
| demand analysis in `peep.h`: an extension (`movl r,r`) after which only the low 32 bits are looked at is removed; `ret` reads `r1` only for a struct pair | 953d6b0c | 374301 | 1696136 | 1.129 | 1.053 |
| `push`/`pop` for one saved register; `call f; ret` becomes `jmp f` when no address of the frame can have been passed | 71ea1721 | 373589 | 1683998 | 1.121 | 1.045 |
| an address of the frame written fp-minus-constant does not force a frame; `movq sp,rN` for `lea 0(sp),rN` | 6ebbea4c | 370940 | 1674494 | 1.114 | 1.040 |
| `rol` for 64-bit rotates by constants | 9907b902 | {{final_ins}} | {{final_bytes}} | {{final_gb}} | {{final_cb}} |

Changes measured and not adopted: re-extending signed `int` results too (`-mwrap`) costs 2.3% of the instructions and 1.0% of the bytes; `-xssa` (a pass-2 option, not a back-end choice) makes the code 0.4% smaller and 1.2% longer in instructions.

The frame-pointer change is a policy change: with `-xdmr` a function that does not take the address of the frame (`__builtin_frame_address`) has no frame pointer, as gcc's default; without `-xdmr`, and in every variadic function, there still is one.
The re-extension policy is explained in section 8.

## 3. Instruction length

pdp64 instructions are 2, 4, 6 or 8 bytes. Counts over the 827 files, from the ELF `.text` of each object ({{len_total_pdp64}} instructions, {{len_bytes_pdp64}} bytes):

{{len_pdp64}}

The average is **{{len_avg_pdp64}} bytes per instruction**. For comparison the x86-64 output of the same files (`objdump -d`), average **{{len_avg_gcc}}** (gcc -Os) and **{{len_avg_clang}}** (clang -Os):

| bytes | gcc -Os instructions | share | clang -Os instructions | share |
|---|---|---|---|---|
{{len_x86_rows}}

pdp64 has 43% two-byte instructions; x86 has 28-31% one- and two-byte ones. 88% of the six-byte pdp64 instructions are pc-relative operands that reach another section or an external symbol (section 5). The distribution answers the question the ISA document leaves open (section 12 there): a short form for the common memory operand would pay, see section 9.

## 4. Which instructions the compiler uses

{{used_count}} of the 213 mnemonics appear in the output; the other {{unused_count}} never do. The 25 most frequent, as a share of all instructions (static count; the x86 columns fold size suffixes, `movl`/`movq` are `mov`, and count `callq`/`retq` as written by clang):

{{mnem}}

Observations:

* `movq` and `movl` together are 32% of pdp64's instructions, against 33-35% for `mov` on x86; pdp64 splits them because narrow values need the sized forms (`movq` 25.2%, `movl` 7.0%). `lea` is 11.4% on pdp64 against 4.2% (gcc) and 3.0% (clang): it is how pdp64 adds a constant to a register without clobbering it, how it takes the address of a symbol or a local, and the way it indexes.
* The first 14 pdp64 mnemonics make up 85% of the code, the first 25 make up 96%. {{used_count}} of the 213 are used at all.
* gcc and clang use `push`/`pop` for 8.2-8.5% of their instructions (saving callee-saved registers one at a time); pdp64 uses `pushm`/`popm` once per function (1.3% of the instructions) and `push`/`pop` for 1.5%.
* x86 compares with `test`/`cmp` (9-11% together) and branches with `je`/`jne` and friends (10-12%); pdp64 has `cmp`/`tst` at 8.7% and conditional branches at {{condbr_pct}} (it has no fused compare-and-branch; section 9).
* `xor reg,reg` is 4.2% of gcc's code (zeroing a register); pdp64 has `clr` for that (2.9%), two bytes.
* The multiply, divide and shift families are small on every machine (under 3% together), which is what the ISA argues.

### Instructions that are used (static counts, 827 files)

{{used}}

### Instructions that are never emitted, and why

{{unused_count}} of the 213 mnemonics do not occur in the output. This is what C compiled by this back end looks like, not what the machine can do: most of the zeros are instructions a compiler emits only from an intrinsic, a library call, system code or an idiom pass that is not written.

{{never}}

## 5. Operand forms and addressing modes

Every operand of every instruction, by form (static count; "pcrel" includes the target of every branch and call as well as pc-relative data; "index" is `d(rb)(rx*s)`):

{{shapes_pdp64}}

For x86 (AT&T operands of the same files; "target" is a branch or call target, "rip" is `sym(%rip)`):

| form | gcc -Os operands | share | clang -Os operands | share |
|---|---|---|---|---|
{{shapes_x86_rows}}

* Register operands are 58% of pdp64's operands and 60-61% of x86's; immediates are 9.5% against 11.5%; memory operands (base + index) are 15% on both.
* Post-increment and pre-decrement are **never** used: the compiler does not emit them (the `AUTOINC` path of pcc is not enabled for pdp64; in an earlier output of the same compiler about 440 of the 10,500 `lea n(rX),rX` sat next to a dereference through the same register, so at most 0.1% of the code would change).
* Absolute addressing (`@n`) appears once. `d(dp)` and `d(pc)` as a base register of data are used only as pc-relative references.
* The 6-byte instructions: {{six_pcrel}} of the {{six_all}} are a pc-relative operand to another section or an external symbol (`call` {{six_call}}, `lea sym,r` {{six_lea}}).

The 6- and 8-byte forms, by mnemonic and operand form:

{{longs}}

## 6. Instruction pairs and triples

The 20 most frequent mnemonic-and-operand-form pairs in pdp64 output (static count; x86 for comparison below):

{{pairs}}

The same for gcc -Os on amd64:

{{pairs_gcc}}

The most frequent adjacent instructions in the pdp64 output (labels between instructions are ignored, so a pair can straddle a basic block boundary; calls to the same function repeated thousands of times in a few test files inflate several rows):

{{bigrams}}

and the most frequent three in a row:

{{trigrams}}

What the pairs suggest (the sections after this one price them):

* **Compare and branch** (`cmp`/`tst` followed by a conditional branch) is {{cmpbr}} pairs, {{cmpbr_pct}} of all instructions. There is no fused instruction.
* **Argument set-up** (`movq reg,reg ; call`, `lea ... ; call`) is the largest group after that: a call is often preceded by one to three moves of arguments into `r0`-`r5`.
* **A narrow load followed by a compare with a constant** (`movzb ...; cmp r,#n`): {{narrowcmp}} sites. The compare cannot take the narrow operand because ALU operands in memory are always 64-bit (decision, errata 28) and an instruction has at most one memory operand, which would also have to hold the constant.
* **`lea sym,r ; movq r,r`** and **`movq imm,r`** are address and constant materialisation: the cost of a machine with no 64-bit immediate and with pc-relative data.

## 7. Where the bytes go

Every instruction of the 827 files in one cost centre (static; "frame" is `push fp`/`movq sp,fp`/`pushm`/`popm`/`sub`/`add` on `sp` and the other frame set-up; "constant" is `clr r` and `movq #n,r`; "address-of-symbol-N" is `lea sym,r` in an N-byte encoding, 6 when the symbol is in another section; "re-extension" is `movl r,r` and the like on the same register; "call-external" is a 6-byte `call`, i.e. to another section or an undefined symbol):

{{cost}}

Reading the table:

* **Cross-section references.** `call-external` plus the 6-byte `address-of-symbol` and `global-access` forms are {{xsec_n}} instructions and cost {{xsec_extra}} bytes more than the 4-byte forms would ({{xsec_pct}} of the image). `as64` resolves a pc-relative reference inside a section itself (4 bytes) but must emit a 32-bit relocation for anything else (6 bytes); the compiler already keeps strings and constants in `.text` for this reason (that change alone cut the 6-byte `lea` count by a third), but cannot do anything about external functions and writable data.
* **Frame and return** are {{frame_pct}} of the instruction bytes. With no frame pointer a function that saves callee-saved registers costs `pushm` + `sub` + `add` + `popm` + `ret` = 18 bytes; with a frame pointer it was 24.
* **Re-extension** (`movl r,r`) is {{reext_pct}} of the bytes. Before this round's policy change it was 4.3% of the instructions.
* **Constants** are {{const_pct}} of the instruction bytes: `movq #n,r` is 4 bytes for 16-bit values and 6 or 8 above, and there is no shorter form.
* **Compare** (`cmp`/`tst`) {{cmp_pct}}, **branch** {{br_pct}}: together a fifth of the bytes.
* **Block moves** are negligible in C: {{block_n}} `mcpy` in the whole corpus (the compiler uses it only for struct copies of three or more words).
* The loads and stores are the largest group, {{ldst_pct}} of the instruction bytes, and nearly all are 4 bytes: any memory operand costs a second parcel, which is the encoding's central trade (section 9 prices a short form).

### Where the image is not code

The image is {{img_total}} bytes in the 827 files; the instructions are {{len_bytes_pdp64}} of them ({{code_pct}}). The rest is data and read-only data, which is the same for the three ISAs apart from alignment and the width of pointers (64 bits in all three).

## 8. Compiler conventions that shape the numbers

* **Re-extension.** A 32-bit `int` or `unsigned` is kept sign-extended in a 64-bit register, because the ALU is 64-bit only (decision, errata 28: no sized ALU operations). A signed `int` result needs no re-extension, since signed overflow is undefined; an unsigned result does (it wraps at 32 bits), and so does a left shift, which pass 1 uses to read bit-fields. `peep.h` then removes an extension whose register is read only through its low 32 bits: the demand analysis follows a value through `add`, `sub`, `and`, `bis`, `xor`, `mul`, `shl`, moves and narrow stores. The tests that pin the policy are `tests/c/extend.c` and the `a64tests` set (all 498 runs pass).
* **Frame.** With `-xdmr` the frame has no frame pointer: the callee-saved registers are saved with `pushm` (`push` for one), locals and the outgoing argument area are addressed from `sp`, and nothing is pushed or popped around a call because the arguments beyond the sixth are stored into a preallocated area at `0(sp)`. A tail call (`call f; ret`) becomes `jmp f` when no address of the frame may have been passed.
* **Constants and strings** are in `.text` (a pc-relative reference within a section is 4 bytes). Odd-sized read-only objects go to `.data`.
* **Calls** to a function defined in the same file are 4 bytes; every other call is 6.
* **Comparisons as values** become compare, branch, load 1, branch, clear. pdp64's `set cc,rd` is not used because pass 1 turns the comparison into branches before pass 2 sees it.

## 9. What the instruction set could gain, priced

Each item is the count of sites in the 827 files where the pattern occurs in the *actual* pdp64 output, times the bytes a hypothetical instruction would save. They are static estimates of image size, assuming the new instruction does exactly the job described and the encoding is as stated; none is an instruction proposal by itself.

{{cand}}

and from the operand statistics:

| idea | evidence (static count in the output) | estimated saving |
|---|---|---|
| A 2-byte load/store with a register-deferred operand `(rN)` (PDP-11 mode 1) | {{ds_d0}} loads and stores use `0(rN)` as the whole operand | 2 bytes each = {{ds_d0_bytes}} bytes, {{ds_d0_pct}} of the image |
| A 2-byte load/store of a quad at a small multiple of 8 from `sp` (the d6(sp) form the ISA mentions) | {{ds_sp}} quad loads and stores at `d(sp)` with 0 <= d < 512 and d a multiple of 8 | 2 bytes each = {{ds_sp_bytes}} bytes, {{ds_sp_pct}} |
| Compare-register-with-5-bit-immediate-and-branch in 4 bytes | {{cb_total}} `cmp r,#imm ; bCC` pairs, of which {{cb_small}} have the immediate in -16..15 and {{cb_med}} in -128..127 | 2 bytes and 1 instruction each for the first group = {{cb_small_bytes}} bytes ({{cb_small_pct}}) |
| `tst r ; bCC` fused (compare with zero and branch) | {{tst_br}} pairs | 1 instruction each; the bytes are equal (2 + 2) |
| 32-bit rotate by a constant (`rol32 rs,#n,rd`) | {{rot32}} rotates in the output, each now 5 instructions and about 14 bytes (`mov`, `shl`, `movzl`, `shr`, `bis`) | about 10 bytes and 4 instructions each = {{rot32_bytes}} bytes ({{rot32_pct}}); the SHA-1, MD5, SHA-256 and RIPEMD-160 files, the worst in the corpus (1.7-2.3x gcc), spend a third of their code on these |
| Linker relaxation or a 16-bit section-relative relocation, so that an external `call` or `lea sym` is 4 bytes when it is in range | {{xsec_n}} six-byte pc-relative forms | 2 bytes each = {{xsec_extra}} bytes, {{xsec_pct}}. By far the largest single item |
| Sized ALU memory operands (the decision of errata 28 refuses these) | `movl mem,r ; op` {{ld32op}} sites; `narrow load ; cmp r,#imm` {{narrowcmp}} sites (these need two operands in memory/immediate and would not fit anyway) | about 2 bytes each for the first group = {{ld32op_bytes}} bytes ({{ld32op_pct}}): supports the decision |

## 10. Conclusions

What the data supports:

1. **The instruction set is dense.** pdp64 averages {{len_avg_pdp64}} bytes per instruction against {{len_avg_gcc}} (gcc) and {{len_avg_clang}} (clang) on x86-64, with 43% of instructions in 2 bytes. It needs more instructions than x86 for the same C ({{r_all_gi}} of gcc, {{r_all_ci}} of clang), mostly because it has no fused compare-and-branch, no sized ALU operands, no 64-bit immediate and no auto-increment in use, and takes 6 bytes for external references. The two effects nearly cancel: the code is {{r_lib_cb}} of clang's and {{r_lib_gb}} of gcc's size on the libraries.
2. **Instructions that earn their slot** (high static counts, no substitute): `movq`, `lea`, `call`, `movl`, `cmp`, the conditional branches and `br`, `movzb`/`movzl`/`movzw`, `clr`, `tst`, `add`, `sub`, `and`, `bis`, `xor`, `shl`, `shr`, `mul`, `ret`, `pushm`/`popm`, `inc`/`dec`, `asl`/`asr`, `neg`/`com`, `mcpy`, `div`/`mod`. `lea` alone is a tenth of the code.
3. **Instructions that the compiler does not need but that the system does**: the system, atomic and TLB words (system code); `clz`, `ctz`, `popcnt`, `bswap`, `ror` (idioms and intrinsics); the string and block words (libc); the UTF-8 and carry-less multiply words (intrinsics). Their absence from compiled C is expected and says nothing about their value; the claim in the README that dedicated `abs`, `min` and `max` are worth under a tenth of a percent of code is supported ({{minmax_sites}} sites for `min`/`max` and {{abs_sites}} for `abs` in 827 files).
4. **`set cc,rd` is worth little** in code size: {{set_sites}} sites, about {{set_bytes}} bytes ({{set_pct}}). Its value is the instruction count of the `x = a < b` idiom (5 instructions become 2), not bytes.
5. **Auto-increment** (`(rN)+`, `-(rN)`) has almost no sites in compiled C here (the pcc front end rarely forms them; at most 0.1% of the code): on this evidence its place in the instruction set is for assembly and for loops over arrays in hand-written code.
6. **`addm`/`subm`/`bicm`/`bism`** (MESC): {{addm_sites}} sites of 64-bit read-modify-write of memory in 827 files, about {{addm_bytes}} bytes. The `int` case (32-bit), which is the common one in C, is {{rmw32}} sites and cannot use them.
7. **What the data suggests adding or changing**, in order of size: (a) a linker or assembler mechanism for 4-byte external references ({{xsec_pct}} of the image); (b) a 2-byte `(rN)` load/store ({{ds_d0_pct}}); (c) a 2-byte small-offset `sp` load/store ({{ds_sp_pct}}); (d) a 32-bit rotate ({{rot32_pct}} overall, much more in hash code); (e) a fused compare-immediate-and-branch ({{cb_small_pct}} for the short immediates). Items (b) to (e) each need encoding space, which the ISA's reserved opcodes (`0x28`-`0x2F`) can supply.
8. **What compiler work (not ISA work) would help most**: keeping struct members in registers (the worst files are those whose local state is a struct that pcc leaves in memory); a 32-bit-rotate pattern; `inc`/`dec` and `set` once the shared pass-1 hook exists; the frame-less leaf is already done.

## 11. Reproducing

```
tools/build-pcc.sh                      # build/pcc/ccom from ../pcc
tools/pdp64size.sh --set fair --arch pdp64,amd64,gcc-Os,clang-Os --out DIR --keep DIR/s
# tables: DIR/results.json holds every figure above per file; docs/codegen-data/ holds the aggregated CSV files;
# tools/codegen/*.py rebuild them (see the list in section 1)
```

The static counts of the candidate sequences (section 9) come from regular-expression scans of the kept `.s` files, so a site is counted only if the instructions are literally adjacent in the output.
