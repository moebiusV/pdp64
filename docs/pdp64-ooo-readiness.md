# Out-of-order readiness: what the ISA costs a large out-of-order core, and what to decide now

[← pdp64 index](../README.md)

**Status: written 2026-10-22 at the author's request (errata 38).** The decision behind it: the FPGA and ASIC implementations are small in-order, non-speculative cores, and the architecture is to be kept ready for a large out-of-order one (register renaming, a reorder buffer, speculation, wide fetch and decode, a sequentially consistent memory system with load replay). This review walks the ISA looking for anything that costs an in-order core nothing and costs an out-of-order core a great deal, so that it can be fixed while changing the ISA is still cheap. It deepens [`pdp64-in-order-and-out-of-order.md`](pdp64-in-order-and-out-of-order.md) and says in section 10 where it differs from it.

**Terms, once.** *Renaming* (giving every new value of a register a fresh physical register, so that only true data dependences remain). *Reorder buffer, ROB* (the in-order list of instructions in flight; results become architectural only when the oldest one *commits*, that is, retires). *Micro-operation, µop* (one simple internal step; a complex instruction is *cracked*, split, into several). *Serializing* (an instruction that must wait until everything older has committed, and holds everything younger back). *Context-synchronizing* (serializing, and in addition everything younger is refetched, because it may have been fetched or translated under the old state). *Replay* (executing a load again, at commit, because another processor wrote its line after the load ran early).

**Labels on every number.** **[M]** a static count (instruction lines, not weighted by how often they run) made by `tools/ooo-readiness.py` over the kept pdp64 assembly of the fair corpus in `/tmp/p64opt/r1/s`: 841 files, 823 of which contain instructions (18 are data-only), **336,408 instructions**, produced by `tools/pdp64size.sh` on 2026-10-22 (the compiler output before the assembler picks page-2 forms; lengths are from that run's `report.md`). **[S]** read from the executable semantics `common/pdp64exec.c`, which is authoritative where the prose of the ISA disagrees (section 10 lists the disagreements). **[D]** stated by a pdp64 document, cited. **[C]** computed from [M] numbers with the assumption written beside it. **[G]** general knowledge about other machines, **unverified** (a separate fact-check of the existing in-order/out-of-order document is running; treat every [G] as "to verify"). Nothing here is measured on hardware: there is none; nor is anything weighted by execution counts, which the project does not have.

**Classes.** **HELPFUL**: the feature makes an out-of-order core simpler or faster than the alternatives. **NEUTRAL**: it costs what it costs on any ISA. **AWKWARD**: a known technique handles it, at a price in logic, µops or verification. **HOSTILE**: it forces special machinery into every out-of-order design, or a performance cliff, and a cheap ISA change removes it.

## 1. The verdict

The ISA is closer to out-of-order-ready than its in-order design point suggests: length-first decoding, fixed field positions, no partial-register writes, aligned accesses, precise exceptions with no journal, a software-managed accessed/dirty walker, a fused compare-and-branch and a flag-free `lea` are all things an out-of-order core wants. **Nothing in it makes an out-of-order implementation impossible.**

The one structural problem is the **condition codes**, and it is bigger than the existing document says. The shift-by-zero rule is the only *data-dependent* partial flag update, but [M] **68.2% of all compiled instructions write at least one flag** (229,389 of 336,408), 52.8% write a register *and* flags (two results each), and the writers include things that no other mainstream ISA gives a flag output: every load, every store, every register move (141,835, 42.2%) and every fused compare-and-branch (31,456, 9.4%). Against that, [M] only **4,999 instructions (1.5%) read a flag at all**, every one of them is the instruction immediately after its writer, and none reads a flag across a label or a call. The flag outputs are almost all waste, and on an out-of-order core waste has a price: rename bandwidth, a tag to track, and a block on move elimination. Removing them from moves, loads, stores and `cbCC` costs the in-order core nothing, costs the compiler **zero extra instructions** and between 0 and 4 bytes at each of 2,908 sites (section 4.4), and cuts the flag-writing population from 68.2% to 16.7% [M, C].

The other findings are mostly **text the architecture owes an out-of-order implementer and does not yet contain**: what makes a write to `PTBR`/`ASID`/`MMUCTL` or an `ICINV` take effect, the `LL`/`SC` reservation rules, what the `_DB` atomics add under sequential consistency, the order of the accesses inside a block copy, that a speculative load must not touch a device register, and that reserved encodings are not the only available "hint" space. These cost an in-order core nothing, and each is irreversible once software depends on the opposite.

## 2. Decisions to make now, ranked

"Now" means: while the ISA has no hardware implementation and the kernel is not written. The principle behind the ranking: **promise less than the in-order core happens to give**. Weakening a guarantee later breaks software; strengthening it later is free.

| # | Decision | Population or reason | Cost to an in-order core | Cost elsewhere | Recommendation |
|---|---|---|---|---|---|
| 1 | **`cbCC` (all three encodings) writes no flag** (it computes its own comparison and keeps the flags as they were) | 31,456 instructions, 9.4% [M]; no compiled flag reader reads from one [M] | none; saves a flag write-enable on 9.4% of instructions | core 2 lines; `tests/sim/cbr.s` (40 sites), `cbrori.s` (3), `cbw.s` (3) read flags after a `cbCC` and need rewriting; ISA §4.4.1, errata 34, 35, CHANGES §12 wording; no compiler or assembler change | **decide now** |
| 2 | **Moves, loads, stores and zero/sign-extending moves (`movq movl movw movb movzl movzw movzb`, every page-2 form) write no flag**; `lea` already writes none | 141,835 instructions, 42.2% [M]; 2,908 compiled branches read flags a move left [M] | none or negative (fewer write-enables) | core 2 lines; `tests/sim/extend.s` (6 sites); compiler: delete the "tst after a move or a load" peephole (`pcc/arch/pdp64/peep.h`, near line 828), the neighbouring rule already turns `tst rX; bCC` into `cbCC rX,#0`: **0 extra instructions; +2 to +4 bytes at each of 2,908 sites where the old branch was two bytes, so at most 11.6 KB = 0.77% of 1,507,476 bytes, probably about half that** [C]; docs ISA §4.4, errata 14 and 38 | **decide now** |
| 3 | **A shift (`shl shr sar`) writes the same flags whatever the count**: for a count of 0, `N` and `Z` from the unchanged operand, `V` and `C` cleared | 6,289 shifts (584 with a register count) [M]; the only data-dependent flag write | none (a mux input changes; the zero-count detect leaves the write-enable path) | core 1 line (`pdp64exec.c` line 433); `tests/sim/flags.s` line 131 (the zero-shift/`set cs` test) rewritten; compiler `table.c` line 590 "a count of 0 would leave it so, hence ZY" fix-up can go; ISA §4.2.1 first rule reversed | **decide now** |
| 4 | **`mscn`/`mscnn` write all four flags** (`Z` as now, `N V C` cleared), so that no instruction writes part of `{N,Z,V}`; state the invariant | 0 uses in the corpus [M]; today the only static partial writer of the `NZV` group [S] | none | core 2 lines (lines 686, 689); `tests/sim/bits.s` lines 118, 126 recheck; ISA §4.7 | **decide now** |
| 5 | **`ISYNC`, a context-synchronizing instruction, and a list of what needs it**: writes to `PTBR`, `ASID`, `MMUCTL`, `VBR`, `DMW0/1`, and `ICINV`/`ICINVA` take effect at the next `ISYNC` or exception return, not "for the next instruction"; an in-order core may make them immediate | System v1 says "takes effect for the next instruction" [D]; there is no `ISYNC` or equivalent | `ISYNC` decodes as a no-op; kernel pays 2 bytes per use | a `SYSX` sub-opcode (254 free) with a page-2 form; ISA §4.11, system architecture §15; kernel code adds `isync` after those writes | **decide now** |
| 6 | **A hint space that executes as a no-op**: one page-2 opcode `HINT kind,rn`, defined as a no-op for every `kind` until implemented; kinds reserved for prefetch, speculation barrier, spin-wait pause | reserved encodings are an illegal-instruction abort today [D], so software cannot use a barrier or prefetch on an in-order core that lacks it | one decode pattern, no state | page 2 has 21 free opcodes [D]; ISA §4.18, §1.2 rule 3 note | **decide now** |
| 7 | **Specify `LL`/`SC` and `ATOM`**: reservation granule, what cancels it, a forward-progress guarantee for a constrained loop, the register result of `SC`, which registers each atomic reads and writes, and what `_DB` adds | the ISA gives names only [D]; the core does not implement `ATOM` [S] | none | ISA §4.11 text; bus document §8 | **decide now** (text) |
| 8 | **Speculation and device memory**: a load from an `MT = 10/11` page is performed only when it cannot be on a wrong path or behind a fault; an instruction fetch never has a side effect on a device page (a speculative fetch there is dropped, not faulted) | KL11-style receive-data registers pop a FIFO when read [D, errata 29 and system architecture §15] | none | ISA §8.2, §16; Q64 document §5 | **decide now** (text) |
| 9 | **Say what the multi-access instructions guarantee to other observers**: the accesses inside `MBLK` are unordered with respect to one another (only the final memory and the register progress are defined); `PUSHM`/`POPM` with `R14` in the mask, and any auto-modified mode whose data register is its base, are reserved (illegal instruction) | `MBLK` may "move more than a byte per step" [D §4.7] against "SC, not revisited" [D §17.1]; the core lets the load win a base/data tie [S] | none | ISA §4.5, §4.7, §5, §17.1; core would need an explicit check | **decide now** (text, plus 2 core checks) |
| 10 | **Page-table-entry visibility**: a store to a PTE is seen by later walks only after `TLBI` (or `ISYNC`); a faulting translation is never cached | System v1 is silent [D] | none | system architecture §15 text; kernel executes `tlbi` after raising permission | **decide now** (text) |
| 11 | **Frame adjust as `lea`**: page-2 `0x20`/`0x21` become abbreviations of `LEA -8n(SP),SP` / `LEA 8n(SP),SP` (no flags) instead of `SUB`/`ADD` | explicit `add`/`sub` on `sp`: 3,620 (1.1%) [M]; they write four flags and so cannot be folded by a stack engine | none | page-2 table, `p2.c`/`p2diff`, `tests/sim/page2.s`; compiler emits `lea -N(sp),sp` | decide now **if** page 2 is still being changed; else later |
| 12 | **Fix the ISA text where it disagrees with the core** (section 10): rotates and `DSHR` flags, `ASL`'s `V`, "every ALU operation writes all four uniformly" | | none | ISA §4.2.1, §4.4 | do now (editing only) |

Smaller items and the things to **leave**, **do later**, or **never add** are in sections 8 and 9.

## 3. The flag table, complete, from the core

Rows are what `common/pdp64exec.c` does [S]. A page-2 form has the flags of the long form it abbreviates [D §4.18].

| Instruction(s) | N | Z | V | C | Reads | Notes |
|---|---|---|---|---|---|---|
| `add` `sub` `cmp` `neg` | result | result | signed overflow | carry out / borrow | none | `C` on a borrow for `sub`/`cmp`/`neg`; `neg` is `0 - x` |
| `adc` `sbc` | result | result | overflow | carry/borrow | **C** | not emitted by the compiler [M: 0] |
| `cbCC`, wide `cbCC`, register `cbCC` | as `cmp` | as `cmp` | as `cmp` | as `cmp` | none (computes its own) | **writes all four** as `cmp` does (lines 456, 462) |
| `fcmp` `fcmp32` `fcmp16` | `a<b` | `a==b` | unordered | 0 | none | all four, from a floating-point comparison |
| `clr` | 0 | 1 | 0 | 0 | none | constants; on a memory operand a store plus the same constants |
| `tst` | operand | operand | 0 | 0 | none | |
| `com` | result | result | 0 | **set to 1** | none | |
| `asl` (by one) | result | result | `N xor C` | bit 63 out | none | the ISA table says `V` is cleared (section 10) |
| `asr` (by one) | result | result | 0 | bit 0 out | none | |
| `shl` `shr` `sar`, register or immediate count | result | result | 0 | last bit out | none | **a count of 0 changes no flag at all** (line 433): the data-dependent write |
| `inc` `dec` | result | result | as `add`/`sub` of 1 | **kept** | none | line 484 saves and restores `C` |
| `mul` | result | result | high half is not the sign extension | **kept** | none | |
| `mulh` | result | result | 0 | kept | none | |
| `and` `bic` `bis` `xor` `bit` | result | result | 0 | **kept** | none | `bit` writes no register |
| `movq/l/w/b` load, store, register move, immediate; `movzl/w/b` | the value loaded or stored | same | 0 | **kept** | none | **stores write flags too**, from the value stored (lines 407, 410) |
| `abs` | result | result | operand is the most negative | kept | none | |
| `min` `minu` `max` `maxu` | result | result | 0 | kept | none | |
| `mcmp` | as `sub` of the first differing bytes | | | | none | equal (or count 0): `N=0 Z=1 V=0 C=0` |
| `mscn` `mscnn` | kept | **hit** | kept | kept | none | **writes `Z` only** (lines 686, 689) |
| `mtps`, `rti`, `rtt` | from the PSW word | | | | none | user-mode `mtps` writes only the four flags |
| `mfps` | | | | | **N Z V C** | |
| `bCC` (`beq bne bpl bmi bvc bvs bcc bcs bhi blos bge blt bgt ble`), `set cc` | | | | | the flags the condition needs (below) | `br` reads none |
| `lea`, `sob`, `btag`, `bntag`, `jtag`, `jmp`, `call`, `ret`, `calli`, `push`, `pop`, `pushm`, `popm`, `pushx`, `popx`, `set` | | | | | | write none |
| `div` `divu` `mod` `modu` `mulhu` | | | | | | write none; a zero divisor aborts |
| all of `BESC`: `clz ctz clo cto popcnt bswap* bitrev ror rori rori32 dshr extb extzb insb xnorpop clmull clmulh` | | | | | | **write none** [S]; the ISA's §4.2.1 table gives `ror`, `rori`, `dshr` flags (section 10) |
| `mcpy mmov mset`; all floating point except `fcmp*`; `fsflags` | | | | | | write no integer flag (`fsflags` swaps `FPSR`) |
| exception entry | 0 | 0 | 0 | 0 | | the new PSW has the flags cleared (system architecture §15) |

**Condition needs.** `eq ne`: Z. `pl mi`: N. `vc vs`: V. `cc/hs cs/lo`: C. `ge lt`: N, V. `gt le`: Z, N, V. `hi los`: C, Z. The unconditional `br` reads nothing.

**Which instructions read `C`.** Only `bcc bcs bhi blos` (and their aliases), `adc`, `sbc`, and `mfps`. `rori` does not [S]; `set` reads whatever its condition names; the fused `cbCC` reads none of the flags. In the corpus [M] the only `C` readers are **486 branches** (`bcc` 164, `bcs` 136, `blos` 116, `bhi` 70), 0.14% of instructions and 9.7% of the 4,999 flag-reading branches; `adc`, `sbc` and `set` occur **0 times**.

**Population by flag behaviour [M].**

| Behaviour | Instructions | Share | Main members |
|---|---|---|---|
| writes `N Z`, clears `V`, keeps `C` | 151,199 | 44.9% | `movq` 93,180; `movl` 25,463; `movzb` 13,093; `movzl` 4,588; `and` 4,039; `xor` 3,124 |
| writes all four | 59,971 | 17.8% | `cbCC` 31,456; `add` 10,842; `clr` 10,707; `sub` 4,161; `asl` 576 |
| writes `N Z V`, keeps `C` | 11,930 | 3.5% | `inc` 8,828; `mul` 2,206; `dec` 896 |
| shifts: all four, or none when the count is 0 | 6,289 | 1.9% | `shl` 3,335; `shr` 2,492; `sar` 462 |
| writes `Z` only | 0 | 0% | (`mscn`) |
| writes no flag | 107,019 | 31.8% | `lea` 32,476; `call` 31,877; `br` 16,206; `ret` 8,071; `push` 2,911; `pop` 2,755 |
| **writes at least one flag** | **229,389** | **68.2%** | |
| **writes only some flags (`C` kept) or by count** | **169,418** | **50.4%** | the partial-update population |
| writes flags and a register (two results) | 177,670 | 52.8% | |
| writes flags only (`cmp`, `cbCC`, stores, `clr` to memory, `fcmp`, `bit`) | 51,719 | 15.4% | |

## 4. The flags, in depth

### 4.1 What an out-of-order core has to do

An out-of-order core treats the flags as a hidden register: every flag writer is given a fresh *flag tag*, a rename table maps "the current flags" to the newest tag, and a flag reader waits for it. Three costs follow from how pdp64 writes them.

1. **Rename bandwidth: one more result for most instructions.** A rename stage that handles four to eight instructions a cycle must allocate, and write into a table, a flag tag for every flag writer in the group. With 68.2% of instructions writing flags [M], the flag tag is a second destination on two instructions in three; on mainstream x86 the corresponding population is the arithmetic and logic instructions, but not loads, moves or stores (to verify [G]). The ISA's own estimate that flags "become expensive only under register renaming, which is not this design point" (§4.4) is right, and this is the price.
2. **Partial writes: a merge.** An instruction that writes only some bits of a renamed register must also read the old value to fill in the rest. If the whole flag word were one renamed register, the 169,418 instructions that keep `C` (50.4%) would each need the old flags as an extra input, one more source and a longer dependence chain through every flag writer. The standard remedy is to split the flags into **independently renamed groups** (x86 renames the carry flag apart from the rest, to verify [G]): here `{C}` and `{N,Z,V}`. With two groups, an instruction that writes the `NZV` group completely and leaves `C` alone has nothing to merge. The architecture's job is to keep that remedy sufficient: **no instruction may write part of a group, or write a group conditionally.** Today two do: the shifts by a zero count (conditional, both groups) and `mscn`/`mscnn` (`Z` alone). Those are decisions 3 and 4.
3. **Move elimination is blocked.** A register-to-register move can be done at rename by pointing the destination at the source's physical register, with no execution at all (to verify [G]). Here `movq reg,reg` (46,177, 13.7% [M]) must also produce `N` and `Z` of the value, which needs the value, which defeats the point; 89.9% of those moves' flags are provably overwritten unread in the same block [M], but hardware cannot know that. A workaround exists ("lazy flags": the flag tag says "derived from physical register 37, kind move", evaluated only if a reader appears), but it is machinery that every out-of-order implementation would have to build to recover what decision 2 gives for free.

### 4.2 What the flags are actually used for [M]

* 4,999 flag readers, all `bCC`; **0 `set`, 0 `adc`, 0 `sbc`.**
* **All 4,999 are the instruction right after the writer** (0 instructions between in every case) and **none obtains a flag from a predecessor block** (across a label) or from before a call. A flag value lives for exactly one instruction in compiled code.
* What wrote the flag that was read: a **move, load or store 2,908 (58.2%)**; a `cmp` 1,290 (25.8%); a logic operation (`and`, `bis`, ...) 678 (13.6%); `fcmp` 106 (2.1%); an add/sub/inc/mul 17 (0.3%); **a `cbCC` 0**.
* Fate of the 229,389 flag writes: consumed 4,999 (2.2%); overwritten unread in the same block 141,720 (61.8%); followed by a `call`/`ret` before any read 42,002 (18.3%, assuming, as the ABI does, that a callee clobbers the flags); leaving the block through a label or `br` 40,668 (17.7%), of which, by the previous bullet, none was ever read.
* Register-count shifts 584 (0.17%), immediate shifts 5,705 (1.7%): **no shift of either kind has its flags read** in the same block [M].

So the flag writes of moves are *used* 2,908 times out of 141,835, and of `cbCC` 0 times out of 31,456.

### 4.3 The design space, and where pdp64 sits

| Design | Who | What an out-of-order core pays | What it costs the programmer |
|---|---|---|---|
| no flags; compare-and-branch and set-less-than | RISC-V | nothing | multi-word carry needs explicit compares; no `adc` |
| flags written only by compares and by instructions with the `S` suffix | ARM | flag rename only for the `S` instructions; the shifter-carry and variable-shift-by-zero cases merge the old `C` (to verify [G]) | one bit in the encoding |
| flags written by most arithmetic and logic, not by moves or loads; groups renamed separately | x86 | the flag-group split; partial-flag stalls were a known cost on older cores (to verify [G]) | none |
| eight condition-register fields, instructions name which one | POWER | renamed fields; no false dependence between independent compares | a field in every compare |
| **flags written by nearly every instruction, including loads and stores, with a kept `C`** | **pdp64 today** | a flag tag on 68.2% of instructions, a merge on 50.4% unless split, no move elimination | none: the PDP-11 rule |

The pdp64 encoding has no spare bit for an `S` suffix, so ARM's way is closed. RISC-V's way is closed by the PDP-11 heritage and by `adc`/`sbc`. The way that fits is **x86's, tightened**: flags are written by the instructions that compute a comparison or an arithmetic or logic result, never by a data movement, and the architecture states the two-group invariant.

### 4.4 The proposed rule, exactly

> **Flag rule F.** The flags are two independent groups, `C` and `{N,Z,V}`. An instruction writes both groups, writes only `{N,Z,V}`, or writes neither; never part of `{N,Z,V}`, and never conditionally on a data value. Moves, loads, stores, extending moves, `lea`, `sob`, every branch (the fused `cbCC` included), `set`, the block operations other than `mcmp`, `mscn` and `mscnn`, and all of `BESC` write no flag. `mcmp`, `mscn` and `mscnn` write all four. `shl shr sar` with any count (zero included) write `N Z` from the result, clear `V`, and set `C` to the last bit shifted out, or to 0 for a count of zero; rotates write none. `add sub cmp neg adc sbc fcmp asl asr clr tst com` write all four; `inc dec mul mulh and bic bis xor bit abs min max` write `{N,Z,V}` and keep `C`.

What it changes against today [M, S]:

| Population | Today | After rule F | Change |
|---|---|---|---|
| instructions writing any flag | 229,389 (68.2%) | 56,098 (16.7%) | -173,291 |
| of which `cbCC` | 31,456 | 0 | |
| of which moves, loads, stores, extends | 141,835 | 0 | |
| instructions with `C` kept | 163,129 | 21,294 (6.3%) | logic 9,364; `inc`/`dec` 9,724; `mul` 2,206 |
| data-dependent writers | 6,289 (584 by register count) | 0 | |
| `movq reg,reg` blocked from elimination | 46,177 | 0 | |

**Cost to the compiler [M, C].** The 2,908 branches that read a flag left by a move or load become `cbCC rX,#0,L` (the rule at `pcc/arch/pdp64/peep.h`, near line 851, already turns `tst rX; bCC` into that): the same number of instructions, a four-byte fused branch (six bytes if the target is beyond 2 KB) where a two-byte `bCC` was, so +2 or +4 bytes each, or 0 to +2 where the old branch was four bytes. The bound is 4 x 2,908 = 11.6 KB, 0.77% of the 1,507,476 bytes of text and data [C]; the target distances are not in the kept assembly, so the expected figure is not measured (most branch targets are near, which puts it at the low end). The 678 logic-operation readers (`and #24,r0; beq`) keep working, because logic operations still write `N Z`. The 135 `movq rX,rX` the compiler uses as a test of a register [M] become `cbeq rX,#0,L` the same way.

**Cost to an in-order core.** Fewer flag write-enables (negative), and the zero-count detect (a six-input NOR on the shift count gating the flag write) leaves the shift path. No instruction is added, none lengthened.

**Does not need to change: the split itself.** Keeping `C` in inc/dec/logic/mul is PDP-11 behaviour that multi-word arithmetic loops can use (`add; adc` around a bookkeeping instruction), although the compiler emits no `adc` [M] and `sob` and `lea` already count and step without touching a flag. A single-group alternative, "every flag writer writes all four, with `C` defined (0 for logic, the carry for `inc`/`dec`)", removes the need for two rename groups and costs no gates either, but changes visible `C` behaviour that hand-written loops may use. Recommendation: **leave `C`-keeping**, state the two-group invariant, and revisit only if an out-of-order design finds the second group too expensive; after rule F only 6.3% of instructions are in it.

**FPSR and `fsflags`.** [S, D §4.10.1] Floating-point exception flags are sticky bits OR-ed in by every floating-point operation that can raise one, and never trap. An out-of-order core must not let a wrong-path operation set a bit, so it carries each operation's five bits in its ROB entry and ORs them into the architectural `FPSR` **at commit** (RISC-V does this, to verify [G]); no rename and no recovery. `fsflags` (`rd <- FPSR; FPSR <- rs & 31`) is then a **commit-time read-modify-write**: it executes when it is the oldest instruction and nothing is in flight to disturb. That is a serialization point, cheap because it is rare (the corpus has 0 uses [M]); the existing document's phrase "need no precise recovery" is true of traps, not of speculation (section 10). `fcmp` writing integer flags is no longer a problem once flags are renamed, and removes open item 7's complaint about serialization.

## 5. The classification, feature by feature

Rows marked * are expanded in section 6 (what an out-of-order core must do, the cheap ISA change if any, what it costs, what breaks).

| Feature | Class | Mechanism that suffers or helps |
|---|---|---|
| Condition codes written by most instructions* | **HOSTILE** | rename bandwidth, move elimination, store data path; section 4 |
| Partial flag updates (`C` kept; shifts by count; `mscn`)* | AWKWARD | flag-group renaming, merge µop; fixed by rule F |
| Flag readers, `bCC` and `set` | NEUTRAL | one or two flag-group sources; all 4,999 are adjacent to their writer [M], so macro-fusion is trivial |
| `cbCC` (three encodings) and `btag`/`bntag` | HELPFUL (after rule F) | one µop, two register sources or one plus an immediate, a direct target, no flag |
| `sob` | NEUTRAL | register result plus redirect (two results); 0 uses [M] |
| `set cc, rd` | NEUTRAL | a flag reader with a register result; no select instruction means mispredicted branches stay branches (open item 15) |
| FPSR sticky bits, `fsflags`* | NEUTRAL | accumulate at commit; swap is a commit-time read-modify-write |
| PSW writes: `mtps`, `spl`, `rti`/`rtt`, the `T` bit* | AWKWARD | serializing; mode change swaps the visible `r14` and `DP`; `T` forces a flush per instruction |
| Implicit `sp` (push, pop, call, ret, pushm, popm, calli, pushx, popx): 54,521 = 16.2% [M] | NEUTRAL | a stack engine tracks `sp` at decode; helped by one-parcel forms, hurt by explicit `add`/`sub #n,sp` writing flags (decision 11) |
| Other implicit operands: `DP` in mode `0011`, `PC`, the current mode (banked `r14`, `DP`), `EPC`/`EPSW`/`VBR` in entry and return | NEUTRAL | `DP` and the mode are extra rename inputs; `mtdp` and mode changes serialize. `r12` is an ABI scratch register, not a hardware operand: **there is no other implicit register operand** |
| Two register results: `popm` (3.70 registers on average, 2 to 5 [M]) plus `sp`; `pop`; `call`/`ret`; `mcpy` (3 registers); auto-modify modes* | AWKWARD | several destinations per instruction means several rename ports or cracking; none of the cheap ones is bad |
| Memory-operand ALU instructions, read-modify-write memory (`addm`, `inc mem`)* | AWKWARD | load + op (+ store) cracking; 1,924 load-ops (0.57%) and **0 memory read-modify-writes** [M] (`clr mem` 1,002 is a store) |
| Variable access counts: `mcpy`/`mmov`/`mset`/`mcmp`/`mscn`, `pushm`/`popm`* | AWKWARD | µop count known only at execute (block ops) or at decode from a mask (`pushm`); 154 block ops and 4,836 `pushm`/`popm` [M] |
| Indirect transfers: `jmp reg`, `jmpi`, `calli`, `jtag`, `ret` | NEUTRAL | target predictor and return-address stack; `ret` loads its target and checks the prediction; 483 + 8,071 [M] |
| Direct branches and calls (PC-relative, from the instruction's first parcel) | HELPFUL | target computed in predecode from the instruction's own address, independent of its length |
| `rti`, exception entry, traps | NEUTRAL | serializing by nature; entry writes registers only |
| `wfe`/`sev`/`fence`/`icinv`/`icinva`/`tlbi`/`tlbia`/`tlbsync`/`prober`/`probew`/`mfsr`/`mtsr`* | AWKWARD | serializing or commit-time; effects on younger speculative work unspecified (decisions 5, 10) |
| Atomics, `_DB` forms, `ll`/`sc`* | AWKWARD | execute at commit; reservation under speculation; the semantics are not written (decision 7) |
| Sequential consistency* | AWKWARD | speculative loads with snoop-and-replay, in-order store release; known cost, defined; two spec holes (decisions 8, 9) |
| Precise exceptions, abort with no architectural effect, `(rN)+` undo | HELPFUL | the ROB discards; the register-update buffer of §7.2 is the rename map restore |
| Interrupts between instructions, the `T` bit | NEUTRAL | taken at commit; trace is a per-instruction flush |
| Self-modifying code, `icinv`* | AWKWARD | fetched-but-uncommitted instructions may be stale; no synchronizing instruction defined (decision 5) |
| Page-table walker, software accessed/dirty | HELPFUL | a wrong-path walk changes only the TLB; the walker never writes |
| Variable-length encoding, 2/4/6 bytes, length in two bits | HELPFUL | instruction boundaries are a 16-way prefix chain on two bits per parcel; section 6.1 |
| Page-2 one-parcel forms | NEUTRAL | exact abbreviations: one decode path; they raise the instructions per fetch block, 55.5% are two bytes [M] |
| Floating point in the integer registers | NEUTRAL | one physical register file and one rename pool; fused multiply-add reads three sources; no cross-file move |
| Division and square root | NEUTRAL | unpipelined variable-latency unit; precise abort for a zero divisor is detected late; 239 divisions (0.07%) [M] |
| Alignment rules (natural alignment aborts) | HELPFUL | no line-splitting access in the load/store queue; store-to-load forwarding by address bits; natural atomicity |
| Unaligned `movu*` (in `MESC`) | AWKWARD | two accesses in one instruction, possibly two pages and two lines; rare |
| `lea` writes no flags | HELPFUL | an address-generation µop with a flag-free result; 32,476 (9.7%) [M] |
| `movq reg,reg` and move elimination* | HOSTILE today, HELPFUL after rule F | blocked by the flag write |
| Literal pool, PC-relative loads | NEUTRAL | pool lines are read by the data cache and fetched by the instruction cache; 207 pool loads, 985 symbolic loads [M]; wrong-path fetch past a `ret` runs into the pool and must decode garbage harmlessly |
| `call`/`ret` through a pushed return address | NEUTRAL | return-address stack plus a verifying load; 31,877 calls and 8,071 returns [M] |
| Reserved encodings abort | AWKWARD | no way to add a barrier or prefetch that older cores ignore (decision 6) |

## 6. The awkward and hostile items

### 6.1 Wide fetch and decode (HELPFUL, with numbers)

An instruction's length is a function of the two top bits of its first parcel alone (§3.1), and the register fields sit at fixed bit positions in parcel 0 for every form that takes registers. A fetch block of 32 bytes is 16 parcels; the set of parcels that start an instruction is found by a prefix chain with at most 16 two-bit steps, or by 4 stages of pointer-jumping (to verify [G]); there are no prefixes, no length-dependent second pass, and no ambiguity about where an instruction starts once a branch target (always an instruction start) is known. The mix measured [M] is 2 bytes 55.5%, 4 bytes 28.7%, 6 bytes 15.7%, average 3.204 bytes, so a 32-byte block holds **10.0** instructions on average and a six-wide decoder consumes about 19 bytes a cycle [C: 6 × 3.204]. With instructions starting on any 2-byte boundary, assuming uniformly distributed alignment, **3.8% of instructions straddle a 32-byte block boundary and 0.03% a 4 KiB page boundary** [C from the measured length mix: the straddle probability is (parcels - 1)/16 and (parcels - 1)/2048]. A straddling instruction costs one cycle of buffer logic; the page crossing needs two translations before decode and is rare. The only decode-width pressure specific to pdp64 is that 15.7% of instructions are cracked into several µops (next paragraph).

**Cracking [M].** Instructions that need two or more µops: `call` 31,877, `ret` 8,071, `push` 2,911, `pop` 2,755, `pushm`/`popm` 4,836 (3.70 registers each, so about 17,900 loads and stores plus the `sp` updates [C]), `calli` 451, load-op 1,924, block operations 154: **52,979, 15.7%**. This is the same population every ISA with a hardware call stack has; it is acceptable, and the `pushm`/`popm` mask is in the instruction, so the µop count is known at decode, which is the easy case.

### 6.2 Condition codes written by moves, loads, stores, `cbCC` (HOSTILE)

*What an out-of-order core must do:* give every one of 173,291 additional instructions a flag tag [M], make a store carry an arithmetic result (the flags of the stored value), and give up move elimination, or build lazy flags. *Cheap ISA change:* decisions 1 and 2. *Cost to in-order:* none. *Breaks:* section 2, rows 1 and 2. *Recommendation:* **decide now**; this is the largest single item in the review.

### 6.3 Partial flag updates (AWKWARD)

*What it must do:* split the flags into `C` and `{N,Z,V}`, and add a merge for any data-dependent writer. *Cheap change:* decisions 3 and 4, rule F. *Cost to in-order:* none. *Breaks:* `flags.s` line 131, `bits.s` lines 118 and 126, core lines 433, 686, 689; the compiler's `ZY` fix-up after variable shifts. *Recommendation:* **decide now.**

### 6.4 PSW writes, `rti`, the `T` bit, banked registers (AWKWARD)

*What it must do:* `mtps` in kernel mode can change the current mode, which swaps the architecturally visible `r14` and `DP` (the core swaps them in `pdp64_set_psw`); the rename table must therefore hold a copy of each, or the mode change must serialize and the banked values move in the free list. Serializing is the simple answer and the instructions are rare: `mtps`, `rti`, `rtt`, exception entry and return only. `spl` changes the priority that decides whether an interrupt is taken, and interrupts are taken at commit, so `spl` just has to commit before the next interrupt check. User-mode `mtps` writes only the flags and is an ordinary flag writer. The `T` bit makes the PSW an input to every commit: with `T` set, every instruction ends in a trap, so the pipeline flushes after each (rare, debugger only). *Cheap change:* none needed. *Recommendation:* **leave**; list these as serializing in the text (decision 5).

### 6.5 Two results and auto-modify modes (AWKWARD, low cost)

[M] **0 uses** of `(rN)+` or `-(rN)` in 336,408 instructions; push and pop are their own instructions. The modes give a load or store a second destination (the base) with a defined order (the pre-decrement happens before the access, the post-increment after; the core lets the loaded value win if the data register is also the base [S]). An out-of-order core cracks them into the access and an add. *Cheap change:* decision 9 (reserve the data-register-equals-base case). Removing the modes outright would free two of the eight addressing modes and erase the dual-destination case; it breaks `tests/sim/modes.s`, the assembler and the ISA's strided-autoincrement section and gains nothing the 0-use count does not already say. *Recommendation:* **leave**, reserve the tie. Other two-result instructions are already ordinary (`pop`, `call`, `ret` write `sp` and one other thing, which a stack engine absorbs).

### 6.6 Memory-operand and read-modify-write instructions (AWKWARD)

Load-op (`add 24(r8),r0`) cracks into a load and an ALU µop that can be fused on the way in; read-modify-write memory (`addm`, `inc mem`, `neg mem`) into load, op and store. The corpus [M] has 1,924 load-ops and no memory read-modify-write: the compiler never emits one. An out-of-order core pays for them in verification, not performance. *Recommendation:* **leave**. Note for the specification: a memory read-modify-write is not atomic and is not ordered with other cores any more strongly than its load and store separately (it is not `xadd`).

### 6.7 Block operations and `pushm`/`popm` (AWKWARD)

`mcpy`, `mmov`, `mset`, `mcmp`, `mscn`, `mscnn`, `mval` take their operands from registers and are *progress-restartable*: an interrupt or fault leaves the registers consistent with byte-at-a-time progress (§7.5). On an out-of-order core the µop count depends on a register value known only at execute, so the instruction is a microcoded loop that issues chunks (as x86 fast-string instructions do, to verify [G]) and commits the three registers per chunk. The corpus [M] has 154, all `mcpy`. Two specification gaps: (a) §4.7 lets an implementation "move more than a byte per step", while §17.1 promises sequential consistency; a second core can observe a 64-byte-per-step copy in an order no byte-at-a-time copy produces, so the text must say the accesses inside a block operation are **unordered with respect to one another** (decision 9). (b) `pushm`/`popm` push or pop registers one at a time through `sp`; if `R14` is in the mask the ISA is silent, and the core pushes the current value of `sp` (and `popm` replaces `sp` in the middle of its own sequence): reserve it (decision 9). An abort in the middle of `pushm` leaves the earlier words written below `sp` (the core stores as it goes and restores only registers); that stack memory is dead, the text of §7.1 ("annulled, no architectural effect") is not literally true of it, and an out-of-order core, which releases stores only at commit, does not show the difference. *Recommendation:* **leave the design, fix the text.**

### 6.8 Serializing and system instructions (AWKWARD, mostly text)

| Instruction | What an out-of-order core must do |
|---|---|
| `mtsr`/`mtasid` writing `PTBR`, `ASID`, `MMUCTL`, `VBR`; `mtdmw` | wait for older instructions, change translation, refetch younger ones (instruction fetch itself uses the translation). System v1 says the write "takes effect for the next instruction" [D]; promising less (take effect at the next `ISYNC` or exception return) costs an in-order core nothing and an out-of-order core a flush it would have taken anyway, but only if the weaker rule is stated now |
| `tlbi`, `tlbia`, `tlbsync` (broadcast) | younger speculative translations must be discarded or replayed; `tlbsync` must wait for the other cores to complete or squash older accesses that used the old translation. The ISA does not say which |
| `icinv`, `icinva` | the instruction cache is not coherent and the pipeline holds fetched instructions: the architecture has no instruction that makes younger instructions come from the new bytes (ARM needs `IC IVAU; DSB; ISB`, to verify [G]). `ICINV` as written cannot be implemented correctly on a core with an instruction queue without an unwritten rule |
| `fence` | for normal memory under SC it orders nothing; its job is device memory and posted writes. Drain the store buffer; not serializing the front end |
| `wfe`, `sev` | `wfe` sleeps until an event or interrupt; commit-time; `sev` is a broadcast |
| `prober`/`probew` | translate without faulting; a read of translation state that older stores to page tables must precede (decision 10) |
| `mfsr` | reads system registers; commit-time if any older instruction can change one |

*Cheap change:* decisions 5 and 10. *Cost to in-order:* an `ISYNC` that decodes as a no-op, and 2 bytes in the kernel after each translation-state write. *Recommendation:* **decide now.**

### 6.9 Atomics, `_DB`, `ll`/`sc` (AWKWARD, mostly a specification gap)

*What an out-of-order core must do.* An atomic read-modify-write cannot be undone, so it executes at the head of the ROB with the store buffer drained, as a full barrier; `cas`, `swap`, `xadd` and the fetch-and-op family are then each one memory transaction on the owned line. `ll` must not set the reservation speculatively (a wrong-path `ll` to another address would cancel the reservation of the right-path one, and a single reservation register cannot tell them apart), so it too executes at commit, or each speculative `ll` keeps its own tag. `sc` reads the reservation at commit.

*What is not specified* [D §4.11, S: not implemented]: the registers each atomic reads and writes (the format has three register fields and the destination); what `sc` returns and where; the reservation granule (the aligned word, the cache line); what cancels it (another core's store to the granule, a context switch, any store by this core between `ll` and `sc`?); whether a bounded loop of `ll ... sc` is guaranteed to make progress; and what `_DB` adds. **Under sequential consistency every access to normal memory is already ordered with every other**, so for cached memory the `_DB` forms and the plain forms are the same instruction; the difference can only be ordering against device memory (`MT = 10/11`) and posted writes. If that is what is meant it must be written; if not, 10 of the 22 `ATOM` sub-opcodes (the `_DB` forms) are duplicates. *Cheap change:* decision 7. *Cost to in-order:* none. *Recommendation:* **decide now** (text).

### 6.10 Sequential consistency (AWKWARD, defined)

What a replay-based SC implementation needs from the ISA, and whether it has it:

| Need | In the ISA? |
|---|---|
| loads may execute early; a load is checked again (or the line is snooped) before commit and replayed if another core wrote it | nothing needed in the ISA |
| stores become visible one at a time in program order, from a FIFO store buffer; loads forward from it | stated (§17.1) |
| every access naturally aligned, so a single access is a single line and atomic | **yes** (§7.4); the explicit `movu*` forms are the exception and their tearing is unspecified |
| one memory access per ordinary instruction, so an instruction's order is its access's order | **yes** (§3.4); the exceptions are `pushm`/`popm`/`pushx`/`popx`, `calli`, `push mem`/`pop mem` (0 in the corpus [M]), the read-modify-writes and the block operations; only the last need a statement (decision 9) |
| loads with side effects execute only when non-speculative | **no**: device pages have a memory type but no rule about speculation (decision 8) |
| instruction fetch has no side effects | **no** (decision 8) |
| translation-state changes order against accesses | partially (decisions 5, 10) |
| atomics and the reservation | text missing (decision 7) |
| a barrier that costs nothing when it is unnecessary | `fence` exists |

The cost of SC itself (a larger load queue with snooping, replays when another core hits an early-executed line, in-order store release) is the largest piece of an out-of-order memory system and is exactly what §17.1 predicted; it needs no ISA change. The existing document's item 4 stands.

### 6.11 Self-modifying code (AWKWARD)

Covered in 6.8: the missing piece is a defined synchronizing instruction, `ISYNC`, and the statement that after `icinv` and `isync` the next instruction fetched sees the new bytes. A store to code in flight needs no hardware check as long as the architecture says only `icinv`+`isync` make it visible (the instruction cache is already non-coherent, §17.5).

### 6.12 Floating point in the general registers (NEUTRAL)

One architectural register file means one rename pool and one physical file: no cross-file transfers, no second set of free lists, and `fabs`/`fneg`/`fcopysign` can run on integer units. The prices: the physical register file must serve both kinds of unit, so the fused multiply-add (three sources) needs a three-read-port path while integer µops need two; a scheduler that wants separate integer and floating-point queues shares the read ports between them; and a floating-point result can feed an integer consumer with no transfer penalty, so one bypass network spans both. The corpus is integer code (287 floating-point instructions, 0.09% [M]), so it says nothing about the effect on floating-point workloads. Rounding mode is in the opcode (§9.8): keep it so. A rounding-mode *register* (the open directed-rounding item 13) would need its own rename or a serialization on every write, a point against option (b) there.

### 6.13 Division (NEUTRAL)

Signed divide of `INT64_MIN` by -1 gives `INT64_MIN` with no trap [S] (x86 traps, to verify [G]); a zero divisor aborts. The 32-cycle sequencer becomes an unpipelined variable-latency unit; the abort is detected when the divide finishes, late but precise (it surfaces at commit). `div`/`mod` are separate instructions with one result each, so there is no two-result division pair. No flags are written. 239 divisions, 0.07% [M]. Nothing to change.

### 6.14 Branches, indirect transfers, landing pads (NEUTRAL, HELPFUL)

Every conditional branch has a PC-relative displacement from the instruction's own first parcel: the target is a predecode addition independent of instruction length. 27.9% of compiled instructions are control transfers [M: `br` 16,206, `cbCC` 31,456, `bCC` 4,999, `call` 31,877, `ret` 8,071, `jmp` 658, `calli` 451]; 10.8% are conditional (36,455). The ISA carries no hint bits and no delay slots; leave it so, and do not define a static prediction rule. `ret` pops its target from memory and the return-address predictor is checked against it; `calli` loads its target, pushes and jumps, in that order [D §4.9.1], which a µop sequence can follow. `jtag` indexes a table by the low three bits of a register, a jump table with a data-dependent index, predicted like any indirect branch (to verify [G]). If landing pads (`lpad`, open item 3) become mandatory, the check is a decode-time test on the target and must be suppressed on wrong paths: a one-bit front-end state that a flush restores. Leave.

## 7. What an out-of-order core needs outside the ISA proper

**Free encoding space [D, S]:** page 1 top-level opcodes `0x2B` to `0x2F` (5) and the spare ALU slot `0x23`; page 2 `0x0F` and `0x2C` to `0x3F` (21); `SYSX` sub-opcodes 2 to 255 (254); `MESC` has 4 spare sub-opcodes; `ATOM` sub-opcodes `0x14`-`0x1F` and `0x22` upward; `BESC` `0x34`-`0x3B`; `mfsr`/`mtsr` register numbers 13 to 255; the condition number 15.

| Need | Where | Notes |
|---|---|---|
| **Speculation barrier** | a `HINT` kind (decision 6) | takes no operand; a no-op on an in-order core. If mitigations ever need a **user-visible** control, it must be a barrier, not a mode bit (§1.1) |
| **Instruction-stream barrier** | `ISYNC`, a `SYSX` sub-opcode with a page-2 form (decision 5) | context-synchronizing |
| **Prefetch hints** | `HINT kind,rn` for `(rn)`; a `MESC` spare sub-opcode (`PFR`, `PFW`) for a displacement or index form | must never fault and must be dropped silently when the address is not translatable; non-temporal variants belong with open item 8 (`MBLK` evicting the cache) |
| **Spin-wait pause** | `HINT` kind | `wfe`/`sev` exist; a pause is cheaper in a short wait |
| **Performance counters** | `mfsr` register numbers 13 and up (cycle, instructions retired, a few events), counted at commit; an unprivileged read-only `rdcycle`/`rdinstret` as `SYSX` sub-opcodes | needed to tune any out-of-order design; none exists now |
| **A branch-hint-free encoding** | already so | no hint bits in `bCC`/`cbCC`; leave it |
| **TLB shootdown ordering** | `tlbi`/`tlbsync` text (decisions 5 and 10) | after `tlbsync` returns, no core may use the old translation, including for accesses already issued speculatively and for instruction fetch |
| **Bus atomics** ([Q64 document](pdp64-q64-bus.md) §8) | decide for the monitor | a **lock** (the Unibus `DATIP`/`DATO` read-modify-write) serializes the bus and defeats an out-of-order memory system; a **monitor** (AXI exclusive access, a reservation in the cache line) is what `ll`/`sc` and `cas` on coherent memory need and lets the core keep the line in a modified state while the operation finishes. Recommendation: monitor for cacheable memory; a lock only for uncached device atomics, if at all. `_DB` meaning follows from decision 7 |
| **Interrupt latency** | open item 5 | an out-of-order `mcpy` commits in chunks; the latency bound is the chunk |

A note on rule 3 of §1.2 (do not fill reserved space): one page-2 opcode for `HINT` with a 4-bit kind and a 4-bit register covers a barrier, two prefetches and a pause, and leaves 20 page-2 opcodes free. Reserved opcodes abort; the hint opcode is the single exception, defined as a no-op, because its point is that software can use it before the hardware does.

## 8. Do later, leave, or never add

| Item | Verdict | Reason |
|---|---|---|
| Conditional select (`csel`) | **do later** (open item 15) | removes mispredicted branches; needs flags as a source or a register condition; decide with a speed model |
| `MESC` prefetch sub-opcodes, non-temporal `MBLK` | do later | after the `HINT` slot |
| Performance counters, unprivileged `rdcycle` | do later | needed before an out-of-order core, not before the first one |
| Single flag group (every writer writes all four) | leave | rule F plus two groups suffices; revisit if the second group is too costly |
| Removing auto-modify modes | leave | 0 uses [M]; costs only a cracked µop; the tie rule is enough |
| `pushm`/`popm`, `calli`, `jtag`, `sob`, load-op, memory read-modify-write | leave | ordinary cracking |
| Variable-length 2/4/6-byte encoding, page 2 | leave | helpful, section 6.1 |
| Banked `r14`/`DP` | leave | serialize at mode change |
| `T` bit and `rtt` | leave | rare |
| **Never add:** a floating-point rounding-mode register; a flags-in-register predication scheme; a branch-hint bit; a mode bit for speculation; hardware-set accessed/dirty bits (they would make a wrong-path walk architectural) | | each costs an out-of-order core a rename or a recovery path the present design does not need |

## 9. What is already well placed

* **Instruction length from two bits** (§3.1) and register fields at fixed positions: wide decode and early register read are cheap.
* **A register is always written in full** (§1, §4.1): there are no partial-register writes, the most expensive surviving x86 legacy (to verify [G]); renaming is one physical register per result.
* **`lea` writes no flag**, and 9.7% of compiled instructions are `lea` [M]: a flag-free address-generation µop already exists.
* **Natural alignment and one memory operand** (§3.4, §7.4): at most one data access per ordinary instruction, no line-split access, no unaligned forwarding case.
* **Exceptions are precise with no journal** (§7.2): the buffered base-register update is exactly what a ROB does for free; entry writes registers only (System v1), so nothing is in flight to unwind.
* **Software-managed accessed and dirty bits**: the walker never writes memory, so a wrong-path walk has no architectural effect.
* **Fused compare-and-branch** (`cbCC` three forms, `btag`): after decision 1, a one-µop branch with no flag, 9.4% of the corpus.
* **No delay slots, no branch hints.**
* **Floating-point flags never trap** and are sticky: accumulate at commit.
* **A defined, strong memory model** (SC) and a fence for devices: the hard part, the choice, is made; an out-of-order implementation then has a specification to meet.
* **Direct branch targets** from the instruction's own address.

## 10. Where this review differs from the existing documents

* **[`pdp64-in-order-and-out-of-order.md`](pdp64-in-order-and-out-of-order.md) §4 item 1 and §5 call the shift-by-zero rule "the one place" to change.** It is the only *data-dependent* flag write, and its fix is decision 3; but the larger flag problem, 42.2% of instructions (moves, loads, stores) and 9.4% (`cbCC`) writing flags at all, is not mentioned there. That document's remark that the fused forms "avoid creating the dependency at all" is true of the reading side only: `cbCC` **writes all four flags** (ISA §4.4.1, core lines 456, 462), so it still creates a flag result.
* **Same document, §4 "already compatible" item 2** says the floating-point flags "need no precise recovery". They need no recovery for traps, since there are none; they do need to be applied at commit so that wrong-path operations leave no trace, and `fsflags` is a commit-time read-modify-write (section 4.4).
* **ISA §4.4**: "every ALU operation writes all four uniformly" is not what the core does (logic, `inc`, `dec`, `mul` keep `C`; moves write `N Z`; `clr`/`tst`/`com` write constants), and "flags are expensive only under register renaming, which is not this design point" is the point errata 38 changes.
* **ISA §4.2.1** gives `ROR`/`RORI` (`C` = the bit rotated in, `N Z` from the result, `V` cleared) and `DSHR` (`N Z` from the result, `V` cleared, `C` unchanged) flag behaviour; the core, which is authoritative, writes **no flag** for any of `BESC`. `ASL` is given `V` cleared; the core gives `N xor C`. One of the two should be corrected; rule F says rotates write none or all, and the simplest is none.
* **ISA §7.1** says the only progress instructions are the `MBLK` group, and §7.3 says an ordinary instruction's operand write cannot fault. `pushm`, `popm`, `pushx` and `popx` make up to 16 stores to the stack, and a store after the first can fault (stack growth); the core aborts correctly (registers restored) but the earlier words stay in memory below `sp`. Harmless, but "no architectural effect" is then not literal.
* **ISA §17.1** ("SC, stated once and not revisited") and §4.7 ("more than a byte per step") disagree about what another core may observe of a block copy (section 6.7).
* **ISA §4.11** justifies the `_DB` atomics by "a lock acquire is one instruction rather than an atomic followed by a `FENCE`", a pair said to be in every critical section; under §17.1's sequential consistency no `FENCE` is needed to order normal memory, so either that justification or the SC claim needs the qualification of section 6.9.
* **Existing document §3 "Opcodes"** says the ISA reserves none for a speculation barrier or prefetch; true today and fixable cheaply (decision 6).

## 11. How the counts were made and checked

`tools/ooo-readiness.py DIR` reads every `*.s` in DIR, treats a tab-led line that begins with a letter as one instruction (a label line starts a new basic block), takes the flag behaviour of each mnemonic from the tables at the top of the script (transcribed from `common/pdp64exec.c`), and prints the tables above. `--samples N --seed S` prints N random matches for every detector, and for every class of flag reader and of flag-write fate.

**Validation done.** Every detector was run with `--samples 10` (seeds 7 and 3) and its ten matches read against the instruction they should have matched: `asl_asr`, `bcc`, `block`, `br`, `call`, `calli`, `cb`, `cb_imm`, `cb_rr`, `clr_reg`, `clrmem`, `div`, `ext_rr`, `fp`, `immshift`, `index_any`, `index_store`, `indirect`, `keeps_c`, `lea`, `load`, `loadop`, `movimm`, `movrr`, `movrr_same`, `pop`, `popm`, `push`, `pushm`, `regshift`, `ret`, `rotate`, `spadj`, `store`, `writes_partial`, `symload`, `pool_or_pcrel_load`, `multi_uop`, `flag_and_reg`, `flag_only`; and ten samples of each reader class (move/load/store, `cmp`, logic, `fcmp`, arithmetic) and of each flag-write fate (consumed, overwritten, killed by call, escaping). No sample was a false match. What the reading and the cross-checks found:

* The kept directory has 841 files but 823 contain instructions; 18 are data-only. The totals are over the instructions, 336,408, which equals the `report.md` figure of that run.
* The class counts sum exactly to the instruction total (59,971 + 151,199 + 11,930 + 6,289 + 107,019 = 336,408), the `bCC` mnemonic counts sum to the 4,999 readers (2,522 `beq`, 1,742 `bne`, 164 `bcc`, 136 `bcs`, 116 `blos`, 76 `ble`, 70 `bhi`, 70 `bge`, 67 `blt`, 20 `bgt`, 16 `bpl`), and the zero counts (`adc`, `sbc`, `set`, `tst`, `addm`, `inc` or `neg` on memory, `(rN)+`, `-(rN)`, `push mem`, `pop mem`) were confirmed with an independent `grep` over the kept files.
* `movq rX,rX` (135 sites) is the compiler's register test; the other `movq` register moves (46,177) are counted separately.
* Run over the test programs, the same backward scan reported two flag readers fed by `movq`, in `tests/qemu/con-rx.S` and `tests/sim/sys-psw.S`; reading them showed one was fed by `mtps` (the scan missed that `mtps` writes flags) and one sat behind a label. They are not counted as test impact. The test impact in section 2 was taken from the lines that remained: `tests/sim/cbr.s` (`cbne r1,r2,f141` then `set ne,r10`, 40 sites), `cbrori.s` line 33, `cbw.s` line 75, `extend.s` (`movb r3,r2` then `set mi,r4`, 6 sites), `flags.s` lines 113 and 131. The scan does not follow flags across labels, so a test that relies on a flag set before a label may exist; `tools/check-all.sh` after the change is the real test.

**Limits.** Static counts only: a hot loop weighs the same as an error path, so no figure estimates run time. "Dead" and "escaping" are conservative and assume a callee clobbers the flags. The corpus is C compiled by the project's first back end; hand-written assembly (the multi-word arithmetic, crypto and kernel code the ISA was designed for) may use `adc`, `set`, memory read-modify-write, auto-modify modes and `fsflags` that this compiler never emits, so a zero count says "the compiler does not use it", not "nobody needs it". The cost figures for an in-order core are judgements about which gates and write-enables change, not synthesis results.

Reproduce:

    tools/pdp64size.sh --arch pdp64 --keep DIR
    tools/ooo-readiness.py DIR
    tools/ooo-readiness.py --samples 10 --seed 7 DIR
