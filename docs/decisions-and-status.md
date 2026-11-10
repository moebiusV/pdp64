# The pdp64: decisions and status

## About this ledger

- What it is: for each design and implementation choice the author made about pdp64 over time, where it stands now against the current docs and code: what is done, what is left to do, what was rejected, and what is left in the air.
- Precedence (the author's rule): more recent decisions have greater precedence; each subject's status follows its latest standing line.
- Each subject: `Status`, `Decided` (the latest standing line with its source `[thread#message]`), `Evidence` (file, line, quote or commit) or `not found: searched ...`, `Doc differs` where a doc or code says something else, `Left` for what remains.
- Checked, not guessed: a status of DONE needs evidence; what could not be checked is IN THE AIR and says why.
- `Rationale` is why he chose it, in his own words; `Precedent` is a system, language, standard or design named as a referent, with whether his choice follows it (chosen), he turned it down (rejected) or it was only compared (considered), and who named it (the author, or the assistant and he accepted it or did not take it up). Only what the messages say: nothing is added from outside. The precedents are indexed by name near the end.
- The chains behind it are in the decision log of the same project; the evidence is as of the repositories read on 2026-11-10.
- pdp64/32 is the decided pdp64 (author, 2026-11-10); r20 and pdp64/16 are tested alternatives, no longer part of it. The repository still carries them. Checked against the working tree of this repository, a fresh pcc clone (commit 41e5c36, 2026-11-07) and the toolchain repository.

## Contents

- [Summary](#summary)
- [Left to do (21)](#left-to-do-21)
- [Left in the air (34)](#left-in-the-air-34)
- [Rejected or replaced (7)](#rejected-or-replaced-7)
- [Done (142)](#done-142)
- [Precedents, by name](#precedents-by-name)
- [Where the current docs or code differ from the decisions (42)](#where-the-current-docs-or-code-differ-from-the-decisions-42)

# Summary

- Left to do: 21 of 204 subjects
- Left in the air: 34 of 204 subjects
- Rejected or replaced: 7 of 204 subjects
- Done: 142 of 204 subjects

# Left to do (21)

- Decided, and not yet in the current code or docs (or only partly).

## 01 Principles and priorities

### The pdp64 family
- Status: TO DO — the repository still carries the family of three (latest decision 2026-11-10 \[1882:j4575#1\])
- Decided: 2026-11-10 changed: "r20 and pdp64/16 are gone, there is no family"; "pdp64/32 is the decided upon pdp64" \[1882:j4575#1\]
- Rationale and precedent: none stated in the sources
- Evidence: README.md:13 "The architecture is a family, pdp64. It has three members"; docs/manual/ still has pdp64-r20, pdp64-16 and pdp64-32; spec/pdp64-16 present; errata.md:243 entry 93
- Doc differs: docs/errata.md entry 93 says "there is one manual for each CPU of the family"
- Left: remove r20 and pdp64/16 (manuals, spec, -m options, README text) and make pdp64/32 the only pdp64

## 02 Bus

### Bus update to virtio-only
- Status: TO DO — approved on 2026-11-09, not applied (latest decision 2026-11-09 \[592:15#4\])
- Decided: 2026-11-09 approved-proposal: "i like all your recommendations, go ahead and update the bus chapter." \[592:15#4\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[592:15\]
- Precedent: native 8-register devices (rejected; named by author): "gone" \[592:15\]
- Evidence: not found: searched docs/manual-src/02-bus.md, docs/errata.md (ends at 93), docs/decisions-pending.md for a virtio-only statement; 02-bus.md:5 still says "every device is a handful of memory locations"
- Left: rewrite chapter 2 (and 5) for virtio across the board and add the errata entry

## 05 Drivers and devices

### Device register model: native 8-register devices to virtio
- Status: TO DO — the 2026-11-09 reversal is not in the docs (latest decision 2026-11-09 \[592:15#1\])
- Decided: 2026-11-09 changed: "forget the native 8 register devices. gone. virtio across the board." \[592:15#1\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[592:15\]
- Precedent: native 8-register devices (rejected; named by author): "forget the native 8 register devices. gone." \[592:15\]
- Precedent: PCIe/NVMe/USB (chosen; named by author): standardizing on the latest buses \[592:13\]
- Precedent: 12 register + dma (considered; named by author): compared with virtio devices \[592:13\]
- Evidence: docs/manual-src/05-drivers.md:5 and :23 "\*\*5.2.1\*\* Each device is at least eight memory-mapped registers"; docs/errata.md:107 entry 29 and :211 entry 61 not marked superseded
- Doc differs: docs/errata.md entry 29 says "devices are eight memory-mapped registers plus DMA"
- Left: supersede errata 29, 49 and 61, rewrite 5.2, and answer the syntactic-sugar question (potential 592:13#2)

## 06 Kernel, modes and memory management

### Page-table levels
- Status: TO DO — the manual still has three levels only, with no runtime discovery (latest decision 2026-11-09 \[592:27#2\])
- Decided: 2026-11-09 decided: Questions why the chapter says a 3 level tlb is not supported; 3-level is supported. \[592:27#2\]
- Rationale: "3 4 and 5 is good, as long as this info is discoverable easily at runtime." \[592:17\]
- Precedent: Loongson 5-level TLB (considered; named by author): asked what is affected "if we have 5 level tlb like loongson" \[592:15\]
- Evidence: docs/manual-src/06-kernel.md:86 "\*\*6.4.1\*\* Virtual addresses are 39 bits, translated by three levels of nine bits"; :163 "\*\*6.8.4\*\*"; not found: 3, 4, 5 levels (39, 48, 57 bits) or a discovery register in 06-kernel.md or errata.md
- Doc differs: docs/decisions-pending.md:734 "3 levels, 39-bit (current)" and lists 4 levels as a rejected-by-default option
- Left: write the 3/4/5-level support with a runtime-discoverable level count (592:17#1) and fix the "not supported" text the author questioned

## 12 Documentation and process

### History import from silentpc
- Status: TO DO — the silentpc prompts are imported into the imp72 and hbnf decision-log inputs but not into the pdp64 inputs (latest decision 2026-11-10 \[1882:443#1\])
- Decided: 2026-11-10 decided: Lost history from silentpc, but the prompts typed are still there, so "import those at least". \[1882:443#1\]
- Rationale and precedent: none stated in the sources
- Evidence: tools/declog/extract.py:106 \`--history LABEL=FILE\` (imports prompts of sessions whose files are gone as history-only threads); docs/decision-log/data/imp72 and docs/decision-log/data/hbnf contain "hist-silentpc" ids (imp72 3775 "history only" hits, hbnf 39 files); not found: "hist-silentpc" in docs/decision-log/data/pdp64 or data/shared (0 files), nor "history only" in pdp64/threads.json
- Left: run the history import for the pdp64 scope (or confirm that no silentpc history prompt is relevant to pdp64)

## Documentation and process

### Bus chapter
- Status: TO DO — the decision is dated after the last change to the chapter; the chapter has no history wording but the recent discussion is not shown in it (latest decision 2026-11-09 \[592:27#1\])
- Decided: 2026-11-09 decided: Update bus chapter with all recent discussion; "remove all reference to previous versions and things being removed ... just document what it is currently." \[592:27#1\]
- Rationale: "why does it say that 3 level tlb isn't supported?"; wants it to "just document what it is currently" \[592:27\]
- Evidence: docs/manual-src/02-bus.md last changed in 2f5a15a (2026-11-04); repository HEAD ef2847a is 2026-11-07 and git status shows no change to the chapter; grep "previous version\|was removed\|no longer\|formerly" finds no history wording
- Left: fold the 2026-11-09 discussion into the chapter and remove any reference to previous versions

### Decision log
- Status: TO DO — log is being built locally; imp72 and hbnf logs partly present, silentpc archives not confirmed (latest decision 2026-11-10 \[1882:j4779#1\])
- Decided: 2026-11-10 decided: Fetch the silentpc archives with "just ssh and scp" \[1882:j4779#1\]
- Rationale: wants "not only the current decisions, but the chain of decisions that led there" \[1882:381\]
- Rationale: single-line point form for now; "later we can expand fully on things when i annotate it" \[1882:j4554\]
- Evidence: docs/decision-log/ has decision-log.md/.html/.pdf, imp72-decision-log.md, imp72-plan.md, build/ (buildabook config), data/{hbnf,imp72,pdp64}; .gitignore excludes docs/decision-log/ (untracked, as approved at 1882:j4541#2); tools/declog/ untracked
- Left: hbnf log (1882:j4687#1) not found as a built output; whether the silentpc .claude and .claude-opusplan archives were fetched is not checked; the ledger step (this file) is in progress

### Document tarball, test-harness doc and changes document
- Status: TO DO — changes document done; test-harness doc and the tarball not found (latest decision 2026-10-21 \[1889:1810#1\])
- Decided: 2026-10-21 decided: Write a comprehensive md of all changes since the tar: "the decisions we made, why we made them", dropped or changed opcodes, clarifications, design errors fixed. \[1889:1810#1\]
- Rationale: Wants "a nice written changes document": "the decisions we made, why we made them", dropped opcodes, clarified items, design errors fixed. \[1889:1810\]
- Rationale: Tarball is "for me to upload", after checking the documents are consistent with each other. \[533:123\]
- Evidence: docs/CHANGES-SINCE-R20.md ('every decision, correction, clarification and dropped or changed opcode made since'); not found: a test-harness doc (grep 'test harness' in README, handoff, docs/encoding-work) or a pdp64-docs tar.gz in the repo
- Left: test-harness doc and tarball; CHANGES-SINCE-R20.md is r20-centred and stops before the pdp64/32-only decision

### Documentation style rules
- Status: TO DO — manuals are clean but README keeps an absolute-style path (latest decision 2026-10-24 \[1889:3007#1\])
- Decided: 2026-10-24 approved-proposal: "good": proceed with batch 2 rewrite of listed documents under the rules (no absolute paths, no tool mentions, no process-failure narratives). \[1889:3007#1\]
- Rationale: "i don't want the docs to record any of claudes fuckups like the lwn.net blockages"; "lwn.net coverage was limited" is enough \[1889:2995\]
- Evidence: docs/manual-src has no /home/david or ~/claude (grep); README.md:71 has '~/claude/pcc-enc'; docs/smp-decisions.md:24,60-62 contain kernel-src paths; 'claude' appears in docs/c64-devices-from-chat.md, decisions-pending.md, retire-stage-candidates.md, security-proposals.md, spill-experiment.md, study-proposals.md
- Left: remove absolute paths and 'claude' mentions from README.md, docs/smp-decisions.md and the six other docs

### Instruction dictionary and entries
- Status: TO DO — dictionary generated from grammar with charts; page-break rule not found in tools (latest decision 2026-11-05 \[1882:327#1\])
- Decided: 2026-11-05 decided: Rule: "a new entry must have a couple lines of text underneath its title and layout charts, otherwise it should start at the top of the next page." \[1882:327#1\]
- Rationale: "this is the full reference manual, don't skip on the instruction set dictionary!" \[1889:2728\]
- Rationale: every instruction "should have the story of why it was chosen to be in the isa" \[1889:2769\]
- Evidence: docs/manual/pdp64-32/dictionary/ (by-mnemonic.md, by-encoding.md) and figures/\*.svg; errata 93 charts from the grammar; commit 02a39ff 'one entry per mnemonic with a chart of each of its layout forms ... books keep an entry's title and charts with its text'; not found: a rule for starting thin entries on the next page (grep in tools/\*.py and book/template.typ)
- Left: the page-start rule is only approximated by 'keep title and charts with text'; the 7 'Cf.' lines in manual-src/09-isa.md follow 1889:j83810#1 (pointers allowed); open question 1882:323#1 on category sections is answered by commit 02a39ff (category sections of chapter 9)

### Manual purpose, style and notation
- Status: TO DO — aphorism and commentary style done; binary values and utf8 pseudocode only partly (latest decision 2026-10-23 \[1889:2979#1\])
- Decided: 2026-10-23 decided: "masks should be in binary too". \[1889:2979#1\]
- Rationale: "this cpu designer thinks all isa are equivalent; this is to show him how wrong he is" \[1889:j79272\]
- Rationale: sections "explain every decision in light of how it impacts efficient kernel, efficient compilation, and efficient hardware layout" \[1889:j79292\]
- Rationale: commentary covers "the historical precedents, the tradeoffs, the improvements, the benefits, and the modern comparables" \[1889:j78927\]
- Precedent: old Sanskrit books (aphorism plus commentary) (chosen; named by author): style: aphorism followed by commentary \[1889:j78927\]
- Precedent: Mishnah and Gemara (chosen; named by author): same aphorism-then-commentary structure \[1889:j78927\]
- Precedent: PowerPC 601 (chosen; named by author): "an excellent example of a cpu manual" \[1889:j78947\]
- Evidence: docs/manual-src/00-index.md 'Each section is a few numbered aphorisms followed by a commentary'; pseudocode in docs/manual/pdp64-32/09-isa.md uses ← (221 uses) and still 2 '\<-'; not found: any 'bbbb (H)' value or binary mask in 09-isa.md (grep for 0b/bit strings: none)
- Doc differs: docs/manual-src/09-isa.md:75 "the mask is 32 bits" gives no binary form
- Left: values and masks in binary with hex in brackets (1889:j83889#1, 1889:2979#1); the two remaining '\<-'

### Old forms and long long libc documentation
- Status: TO DO — OLD-K&R-FORMS.md exists but the "to fix" mark for the long long libc on the v7 side is not in the toolchain docs (latest decision 2026-10-17 \[1889:j24667#1\])
- Decided: 2026-10-17 decided: "the documentation should be done last, after vax and pdp11 are fully optimized as far as correctness allows" \[1889:j24667#1\]
- Rationale: "the documentation should be done last, after vax and pdp11 are fully optimized as far as correctness allows." \[1889:j24667\]
- Rationale: Wants "what regressions from c99 would it cause" documented for each old form. \[1889:j24650\]
- Precedent: V7 and 32V old K&R forms (considered; named by author): forms pcc doesn't support; cost of supporting them \[1889:j24650\]
- Precedent: C99 (considered; named by author): regressions from C99 if old forms were supported \[1889:j24650\]
- Evidence: v7unix-toolchain:OLD-K&R-FORMS.md exists; not found: a "to fix" mark for long long in README.md, TODO, UPSTREAM-PLAN.md, PORTING.md or OPTIMIZATION-TRICKS.md of facetlang/pdp11/v7unix-toolchain (HEAD 2bbff8c, 2026-10-21); README.md:118 states only that the VAX has long long helpers "which 32V's libc lacks"; status-check/pcc (HEAD 41e5c36) doc/SIZE-NOTES.md:38 describes the 64-bit long long without a mark
- Left: add the "to fix" mark on the v7 side (the decision defers all documentation to the end)

### PCC contributors
- Status: TO DO — a contributor file exists elsewhere but the pcc repo README does not name contributors (latest decision 2026-10-13 \[1889:j7147#1\])
- Decided: 2026-10-13 decided: Name all contributors from commit messages, "most recent contributor first, least recent contributor last" \[1889:j7147#1\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:PCC-CONTRIBUTORS.txt exists; pcc-enc:README.md has no contributors list (grep 'contributor' hit only LICENSE.md boilerplate)
- Left: pcc is missing (only pcc-enc, pcc-pr worktrees); order and completeness of PCC-CONTRIBUTORS.txt not checked: not checked: file not read in full

### README
- Status: TO DO — README is rich but its own stale statements and absolute path remain (latest decision 2026-10-23 \[1889:3003#2\])
- Decided: 2026-10-23 decided: "fix the readme!!!!" \[1889:3003#2\]
- Rationale: The pdp-11 and vax-11 "were famous for being pleasant and fun to program in assembly language"; this project updates them "with all the lessons learned in the last 50 years". \[1889:2028\]
- Rationale: Design chosen "to have less possibility for error, fewer footguns, fewer surprises". \[1889:2028\]
- Rationale: Headings may address history, "especially when discussing how this design was conceived and developed from historical precedent". \[1889:3003\]
- Precedent: PDP-11 (chosen; named by author): pleasant, fun assembly language; updated with 50 years of lessons \[1889:2028\]
- Precedent: VAX-11 (chosen; named by author): same: famous for being pleasant to program in assembly \[1889:2028\]
- Precedent: PDP-11 (chosen; named by author): "update and refresh of the pdp-11 instruction set and architecture" \[1889:1956\]
- Evidence: README.md has the title, first paragraph, principles, layers (lines 1-30)
- Doc differs: README.md:13 says "The manual (docs/manual/) still describes pdp64/r20 only"; README.md:6 and :13 present r20, 16 and 32 as three members
- Left: README.md:71 has "~/claude/pcc-enc" (style rule says no ~/claude); stale "still describes r20 only" claim contradicts the three generated manuals; family text must become pdp64/32 only

### Variant testing document
- Status: TO DO — comparison reports exist but no document states /32 chosen for performance (latest decision 2026-11-10 \[1882:j4575#2\])
- Decided: 2026-11-10 decided: Document "the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons" \[1882:j4575#2\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/encoding-work/integration.md and timing.md report measured comparisons of the three; not found: a statement that pdp64/32 was chosen for performance (grep 'chosen for performance' in docs/ and handoff.md: none)
- Doc differs: README.md:13 still presents r20, pdp64/16 and pdp64/32 as three members of a family
- Left: write the document; record the choice of pdp64/32 and retire r20 and pdp64/16 text in README, handoff, manual

## Instruction set: encoding

### Why pdp64/32 (r20 and pdp64/16 tested against it)
- Status: TO DO — the comparison is documented, but the repository still builds, documents and publishes the family (latest decision 2026-11-10 \[1882#j4575\])
- Decided: 2026-11-10 decided: "pdp64/32 is the decided upon pdp64", "r20 and pdp64/16 are gone, there is no family"; "it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons. follows our principles of check, don't guess." \[1882#j4575\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/encoding-work/integration.md (the measured r20 / /16 / /32 comparison, section 4) \| spec/pdp64-16/pdp64-16.hbnf and docs/manual/pdp64-r20, pdp64-16, pdp64-32 still present
- Doc differs: README.md:13 says "The architecture is a family, pdp64. It has three members"; README.md:6 lists three manuals and three PDFs; handoff.md:48 says "the members pdp64/r20 (the original encoding), pdp64/16 and pdp64/32"
- Left: remove (or archive as tested alternatives) r20 and /16 from README, manuals, PDFs, -m options, spec/pdp64-16, tests; make the testing against them a stated section of the pdp64/32 documentation

## Instruction set: instruction groups

### Constant-time execution
- Status: TO DO — decided in principle; the mechanism is still a proposal (P17) and nothing is in the ISA or simulator (latest decision 2026-11-04 \[1882:j1465#1\])
- Decided: 2026-11-04 decided: Add and div need not take the same time as each other; "only they are timing independent of their data" \[1882:j1465#1\]
- Rationale: "no hammer-row, no spectre, no timing channel attacks"; "for non-sensitive things, constant time isn't a priority" \[1889:2605\]
- Rationale: only that add and div need not match: "only they are timing independent of their data" \[1882:j1465\]
- Precedent: Spectre (rejected; named by author): design must not repeat it \[1889:2605\]
- Precedent: Rowhammer (rejected; named by author): written as "hammer-row"; design must not repeat it \[1889:2605\]
- Evidence: not found: searched docs/pdp64-isa.md, docs/errata.md and sim64/, common/ for DIT or a constant-time rule; docs/decisions-pending.md:584 "P17 ... PROPOSED, not decided"
- Doc differs: docs/decisions-pending.md:124 says "proposed: option 3 (a core set always constant-time plus a DIT bit"
- Left: adopt option 3 or another; state the core set in the ISA; DIT bit and fast-path disable in the spec and simulator

## Instruction set: registers

### Register count (16 or 32)
- Status: TO DO — 32 registers is implemented as pdp64/32, but the repository still presents 16- and 32-register members as official (latest decision 2026-11-09 \[592:38#1\])
- Decided: 2026-11-09 decided: "only the 32 register pdp64 is official, the other two are cancelled." \[592:38#1\]
- Precedent: RISC-V (considered; named by author): compared with pdp64 as a 32-register design; only the 32-register pdp64 official \[592:38\]
- Evidence: spec/pdp64-32/pdp64-32.hbnf (32 registers); docs/encoding-work/integration.md section 4 (the measured case for 32)
- Doc differs: docs/errata.md item 87 says "the architecture is pdp64 and its two members are pdp64/16 (16 registers, 4-bit register fields"; docs/pdp64-isa.md:80 "Sixteen registers"; README.md:13 family of three
- Left: make /32 the only official state: ISA text, README, manuals, handoff.md, -m default (docs still describe r20 as default); remove cancelled members

## toolchain

### Gap to gcc -Os on pdp11 and vax
- Status: TO DO — the gap is 8.0% (PDP-11 corpus), 14.7% (VAX), 16.6% on one fair set; target is 5% (latest decision 2026-10-21 \[1889:j64711#1\])
- Decided: 2026-10-21 decided: "take the worst 10% of c files and just use them until they are within the 5%, then do the whole corpus again, and repeat" \[1889:j64711#1\]
- Rationale: "if we get pdp11 and vax to within 5% of gcc -Os we'll consider that good enough" \[1889:j64431\]
- Rationale: "you should be testing on a much smaller corpus"; worst 10% of files until within 5%, then whole corpus again \[1889:j64711\]
- Rationale: "long long is almost never used by anyone" \[1889:1438\]
- Precedent: gcc -Os (chosen; named by author): target: within 5% of it on pdp11 and vax \[1889:j64431\]
- Evidence: pcc:doc/SIZE-REPORT.md:91 "pdp11 ... +8.0%" against gcc; commit 285188d "PDP-11 gap to gcc 16.6%"
- Left: the worst-10% loop to reach 5%

### QEMU and LLVM targets
- Status: TO DO — QEMU is built, the LLVM back end is only at milestone M1 (latest decision 2026-10-22 \[1889:2202#1\])
- Decided: 2026-10-22 decided: "if we build llvm, we'll move over to a machine with more memory". \[1889:2202#1\]
- Rationale: "if we build llvm, we'll move over to a machine with more memory" \[1889:2202\]
- Precedent: OpenBSD (considered; named by author): "how does openbsd bring up a new architecture?" vs going straight to 3bsd \[1889:2199\]
- Precedent: 3BSD (considered; named by author): premise of his question: going straight to 3bsd \[1889:2199\]
- Precedent: LLVM target sources under llvm/ in pdp64 repo (considered; named by assistant, not taken up): assistant proposal, not a GitHub fork; he answered only about machine \[1889:2202\]
- Precedent: QEMU (chosen; named by author): wants a plan for a qemu backend for the pdp64 \[1889:j68877\]
- Evidence: llvm/README.md "Milestone M1 ... There is no code generator yet (llc and clang are later milestones)"; qemu/README.md exists
- Doc differs: handoff.md: the build machine has 3.9 GB RAM, the move to a bigger machine is not recorded
- Left: Left: LLVM code generator, the larger machine

### aarch64 against clang -Os
- Status: TO DO — aarch64 is still 13% to 20% larger than clang -Os (latest decision 2026-10-18 \[1889:1122#1\])
- Decided: 2026-10-18 decided: "find out where the remaining 5% comes from" \[1889:1122#1\]
- Precedent: clang -Os (considered; named by author): asked why pcc is 20% bigger than clang \[1889:1120\]
- Precedent: clang -Os (considered; named by author): asked if -xdmr beats clang -Os on aarch64 \[1889:1114\]
- Evidence: pcc:doc/SIZE-REPORT.md "fork is 17.3% smaller than stock and 13.4% larger than clang -Os; ... 19.5% larger than clang"
- Left: Left: the remaining gap to clang is not closed

# Left in the air (34)

- Only ideas, open questions, conflicting decisions, or points the record and the repository do not settle.

## 01 Principles and priorities

### C64 in spirit, not the hardware
- Status: IN THE AIR — a principle of the separate newlisp C64-spirit machine; the pdp64 docs neither state nor contradict it (latest decision 2026-06-25 \[1058:12#1\])
- Decided: 2026-06-25 decided: "the c64 hardware itself isn't the point"; rejects the C64 keyboard as "shitty"; "the rpi500 keyboard is adequate". \[1058:12#1\]
- Rationale: "the c64 hardware itself isn't the point; i don't want to be stuck with that shitty keyboard." \[1058:12\]
- Precedent: Commodore 64 (rejected; named by author): "the c64 hardware itself isn't the point" \[1058:12\]
- Precedent: RPi 500 keyboard (chosen; named by author): "adequate" \[1058:12\]
- Evidence: docs/manual-src/03-graphics.md:5 C64 devices deferred in favor of standard devices (errata 78); README.md:4 successor of the PDP-11, not of the C64
- Left: confirm whether this applies to pdp64; other 2026-06-25 records \[1058:3#1, 1058:9#1\] concern the newlisp C64-spirit machine, not pdp64

### Learning from LoongArch
- Status: IN THE AIR — only a potential; nothing adopted by decision (latest 2026-10-20 \[533:36#4\])
- Decided: no standing decision (only potential decisions)
- Precedent: LoongArch64 (considered; named by author): asked how it handles the PC \[533:36\]
- Precedent: AArch64 (considered; named by author): asked if LoongArch handles PC the same \[533:36\]
- Evidence: docs/manual-update-plan.md:29 lists a planned "9.20 LoongArch" section; no errata entry
- Left: decide what to adopt from LoongArch, or drop

## 03 Graphics and the C64 devices

### C64 console (c64x), the earlier SDL console
- Status: IN THE AIR — a separate pre-pdp64 project (newlisp/SDL console); not a pdp64 design item (latest decision 2026-06-18 \[397:44#1\])
- Decided: 2026-06-18 decided: Goal: a terminal interface on all major platforms that also runs unix tty programs "while being as sweet and usable as the C64", with newlisp as driver. \[397:44#1\]
- Rationale: a terminal interface that runs unix tty programs "while being as sweet and usable as the C64", with "the nice stuff of newlisp as the driver". \[397:44\]
- Precedent: Commodore 64 (chosen; named by author): "as sweet and usable as the C64" \[397:44\]
- Precedent: newLISP (chosen; named by author): as driver of the console \[397:44\]
- Precedent: MS-DOS console font (considered; named by author): font "reminiscent of the old Commodore 64 font, or the old MSDOS console font" \[2224:0\]
- Evidence: not found: searched pdp64 docs and README.md for c64x, newlisp or SDL console; the records are 2025-07-23 \[2224:0#1\], 2025-09-22 \[2446:0#1, 2446:4#1\], 2026-05-13 \[311:34#1\], 2026-06-18 \[397:3#1, 397:9#1, 397:12#1, 397:12#2, 397:24#1\]
- Left: lives in another repository; if it is meant to be the terminal for pdp64, say so

### C64 console font and 9p interface
- Status: IN THE AIR — "9p all the way" decided for the console, "9p server" and font-query protocol are potentials, all outside this repository (latest decision 2026-06-18 \[397:12#3\])
- Decided: 2026-06-18 decided: "9p means 9p all the way. no mix and match." \[397:12#3\]
- Rationale: "9p means 9p all the way. no mix and match. it works or it doesn't." \[397:12\]
- Precedent: 9P (chosen; named by author): "9p all the way"; also a 9p server for window info \[397:9\] \[397:12\]
- Precedent: kitty (considered; named by author): c64x is much the same "but with peek/poke instead of byte stream" \[397:9\]
- Precedent: xterm-256color subset shim (chosen; named by author): "we'll have a shim that implements xterm-256color subset" \[397:9\]
- Precedent: vsock (considered; named by assistant, not taken up): he "didn't understand" the vsock question \[397:12\]
- Evidence: not found: searched pdp64 docs for 9p, font-query protocol; related potentials \[397:9#2\] and \[311:22#1\]
- Left: same repository question as the C64 console

### SID chip variants
- Status: IN THE AIR — a question only (latest 2025-09-22 \[2446:21#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/c64-devices-from-chat.md and manual 3.1.3 discuss SID-64X, not which original SID variant; not found: an answer to which variant was most common
- Left: author's question about the SID models is unanswered in the docs

### Velinsky link between C64 and DEC
- Status: IN THE AIR — only the author's hypothesis, recorded as such (latest 2026-11-08 \[1882:367#1\])
- Decided: no standing decision (only potential decisions)
- Rationale: "velinsky shows interchange of personelle between dec and commodore"; "similarity too great to be chance" \[1882:367\]
- Rationale: "no design carried over is false given all the commonalities we found between the c64 and the pdp11" \[1882:365\]
- Precedent: Velinsky (DEC Rainbow and Commodore designer) (considered; named by assistant, accepted): common designer as link between DEC and Commodore \[1882:363\]
- Precedent: C64 and PDP-11 similarities (considered; named by author): commonalities found, cited as evidence \[1882:365\]
- Evidence: commits fc6cf2e and c3eceb6 "Velinsky link recorded as prediction, confirmation and the author's hypothesis (P)"; docs/c64-devices-from-chat.md section 8
- Left: the evidence still wanted, as the docs themselves say

## 04 Boot

### Device initialization protocol
- Status: IN THE AIR — only a potential (latest 2026-10-22 \[1889:2614#2\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/manual-src/04-boot.md and docs/boot.md for a "poke a register to initialize" rule or a firmware-blob register
- Left: decide whether the bus gives a device-initialize register; PCI Express (errata 80) now supplies its own reset and init

## 05 Drivers and devices

### Crypto and random-number devices
- Status: IN THE AIR — chain has only potentials; the repository records later replies (latest 2026-11-04 \[1882:69#5\])
- Decided: no standing decision (only potential decisions)
- Rationale: "guys suffered from bad rng in the past"; optimizing their rng algorithms "is ok". \[1882:69\]
- Evidence: docs/errata.md:235 entry 85 "Random numbers (P9): the pool is one device shared by all cores"; docs/crypto-secure-core.md
- Doc differs: errata 85 records decisions the chain shows only as potentials
- Left: the chain and errata dates (11-03 versus 11-04) do not settle whether the OpenBSD-rng line was adopted as written

## 06 Kernel, modes and memory management

### Realtime V7 with QNX ideas
- Status: IN THE AIR — only a potential (latest 2026-08-29 \[531:2#1\])
- Decided: no standing decision (only potential decisions)
- Precedent: QNX/QUNIX (considered; named by author): fold its design decisions into V7 for realtime guarantees \[531:2\]
- Precedent: V7 Unix (chosen; named by author): "assume v7 source code as the base" \[531:2\]
- Evidence: not found: searched docs/\*.md and manual-src for a QNX or realtime-kernel decision; qnx appears only in docs/c64-devices-from-chat.md; first OS is OpenBSD (errata 41)
- Left: probably dropped by the OpenBSD decision; the author has not said so

### mmap devices (Multics idea)
- Status: IN THE AIR — only a question (latest 2026-06-19 \[402:0#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:209 entry 59 adopts memory-mapped devices for vectors and graphics, but not Multics as a basis; not found: a Multics decision
- Left: author has not decided on Multics

## 07 Multiple processors

### CPU in DRAM
- Status: IN THE AIR — only a question (latest 2026-10-20 \[533:110#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/\*.md for a CPU-in-DRAM design; only passing mentions in docs/kernel-pain-points.md
- Left: author has not decided

### Dedicated core classes
- Status: IN THE AIR — the chain says decided, the repository calls it a proposal (latest decision 2026-11-04 \[1882:j541#1\])
- Decided: 2026-11-04 decided: "also one core for audio processing, doing midi, dsp, etc." \[1882:j541#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:226 entry 76 "PROPOSAL (the author's recommendation"; docs/manual-src/07-smp.md:110 "\*\*7.8.7\*\* ... \*(P)\*"
- Doc differs: docs/smp-decisions.md:12 "The dedicated-core proposal (graphics, network, audio) is a proposal"
- Left: author to say whether "we recommend" is a decision

## 11 Toolchain

### newlisp environment
- Status: IN THE AIR — design of a separate newlisp front end, outside this repository (latest decision 2026-06-25 \[1058:18#2\])
- Decided: 2026-06-25 decided: "list" gives a code browser showing all contexts and their contents, in a "very nice c64 TUI mode"; incorporates some of vim and smalltalk. \[1058:18#2\]
- Rationale: environment made "more c64 like" with "tcl and smalltalk idioms"; bare function name at line start, "mccarthy would be happy". \[1058:18\]
- Precedent: newLISP (chosen; named by author): "we'll be newlisp" \[1058:18\]
- Precedent: original Lisp (chosen; named by author): bare function name at beginning of a line \[1058:18\]
- Precedent: Tcl (chosen; named by author): some idioms incorporated \[1058:18\]
- Precedent: Smalltalk (chosen; named by author): idioms and code browser, but showing all contexts \[1058:18\]
- Precedent: vim (chosen; named by author): "incorporate some of vim" into the environment \[1058:18\]
- Evidence: not found: searched pdp64 docs, tools/ and README.md for newlisp; other record \[1058:18#1\]
- Left: lives in another project

## 12 Documentation and process

### Grant evaluation
- Status: IN THE AIR — only a request to evaluate (latest 2026-10-23 \[632:0#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/ and README.md for darpa or grant

### Wrapping for pdp64 and papers
- Status: IN THE AIR — referent not visible (latest 2026-11-06 \[silentpc-opusplan:e3c27aa1:j893#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not checked: the meaning of "wrapping" is not known, so nothing to compare
- Left: ask the author what "wrapping" meant

## Documentation and process

### Agent workflow
- Status: IN THE AIR — working rule for the session, nothing to implement (latest decision 2026-10-22 \[1889:2315#2\])
- Decided: 2026-10-22 decided: "only run one agent at a time, stop eating up memory". \[1889:2315#2\]
- Rationale: "only run one agent at a time, stop eating up memory" \[1889:2315\]
- Evidence: not checked: a process rule for agent runs, no repository artifact

### Browser use, politeness and site bans
- Status: IN THE AIR — working rules for the browser; no artifact states them (latest decision 2026-10-23 \[1882:j82932#1\])
- Decided: 2026-10-23 changed: "you can remove the archiv and lwn bans, just be polite" \[1882:j82932#1\]
- Rationale: "avoid lwn.net somehow it triggered spammer code" \[1889:2542\]
- Rationale: "you can remove the archiv and lwn bans, just be polite" \[1889:j82932\]
- Rationale: "next time tell me first, i closed it." \[1889:2242\]
- Precedent: lwn.net (rejected; named by author): avoided after it triggered spammer code; later ban removed \[1889:j82932\] \[1889:2542\]
- Precedent: lwn.net (considered; named by author): use archives elsewhere if they exist \[1889:2545\]
- Evidence: not checked: rules govern agent behaviour (the browser skill and browse.py live outside the pdp64 repo); not found: 'lwn' in docs/manual-src or README.md
- Left: whether browser skill politeness settings (10 s between clicks, retry on a timer) are implemented outside the repo

### Other
- Status: IN THE AIR — no standing decision, only an unclear record (latest decision 2026-10-23 \[1889:j83726#1\])
- Decided: Now: no standing decision (only unclear or rejected records)
- Rationale and precedent: none stated in the sources
- Evidence: not checked: the text to be placed is not visible in the record
- Left: unclear record 1889:j83726#1 cannot be placed

### Standing optimization rules
- Status: IN THE AIR — process rules for compiler work; no artifact in the pdp64 repo states them (latest decision 2026-10-21 \[1889:1647#2\])
- Decided: 2026-10-21 decided: Standing rule: "always prefer optimizations that benefit multiple backends" \[1889:1647#2\]
- Rationale and precedent: none stated in the sources
- Evidence: not found: grep 'multiple backends' and 'worst 10' in docs/\*.md, README.md, handoff.md
- Left: not checked: pcc-enc docs state the rule; rules are working practice, not a document

## Instruction set: alignment and memory model

### R7 as a view of the PC
- Status: IN THE AIR — only a potential idea, though the ISA text already answers no (latest decision 2026-10-20 \[533:36#2\])
- Decided: no standing decision (only potential decisions)
- Precedent: PDP-11 (considered; named by author): asked whether R7 was the PC on PDP-11 and about a read-only view \[533:36\]
- Precedent: LoongArch64 / AArch64 (considered; named by author): asked how they handle the PC \[533:36\]
- Evidence: docs/pdp64-isa.md:1333 "9.3 The PC is not a register, and R7 is not a read-only view of it"
- Doc differs: docs/pdp64-isa.md:1333 says R7 is not a view of the PC, with no recorded decision of the author for it
- Left: the author never ruled on it in the records; the ISA text takes the rejecting side by default

### Stack alignment
- Status: IN THE AIR — a question only; the ABI keeps 8 (latest decision 2026-10-21 \[1889:1712#3\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/abi.md:10 "the stack pointer is a multiple of 8 at all times"
- Doc differs: docs/abi.md:10 says multiple of 8, not 2
- Left: the author asked "why not 2 bytes instead of 8?" and no answer or ruling is recorded

## Instruction set: encoding

### Combining group opcodes
- Status: IN THE AIR — only a potential idea; the repository keeps the groups separate (latest decision 2026-11-04 \[1882:170#1\])
- Decided: no standing decision (only potential decisions)
- Rationale: combining sop and sys covers all their sub-instructions, "which means 39 instructions reduce to 1" \[1882:170\]
- Evidence: spec/pdp64-32/pdp64-32.hbnf catalogue still has separate leaf-SYS0, leaf-SYSR, leaf-SYSI, leaf-SOPR forms; docs/encoding-proposal.md:87 lists SYS0 (36) and others as separate groups
- Left: no record of a decision to merge sop and sys; nothing implemented

### Grammar as source of truth (hbnf)
- Status: IN THE AIR — the chain's latest line says skip hbnf, but the repository is built on hbnf grammars after the author's later correction that the chain does not carry (latest decision 2026-10-21 \[1889:1712#2\])
- Decided: 2026-10-21 decided: "skip hbnf for now" \[1889:1712#2\]
- Rationale: accepted from the assistant: the bit-level hbnf grammar cannot be tested until GNAT 15 is available (he answered "skip hbnf for now") \[1889:1712\]
- Evidence: spec/pdp64-32/pdp64-32.hbnf and spec/README.md:20 "toolchain is written from one source of truth, a set of hbnf grammars"; docs/errata.md item 89
- Doc differs: docs/errata.md item 89 quotes the author (2026-11-04): "i said grammar is the source of truth; undo your pivot to python. use latest hbnf."
- Left: the 2026-11-04 instruction is the later decision but is not in this chain; the three open questions (hbnf for opcode layout, json spec, 0b enums) are unanswered in the records

### Opcode field and parcel layout (6-bit opcode)
- Status: IN THE AIR — only potential ideas; the decided pdp64/32 uses a variable prefix, not a fixed 6-bit opcode (latest decision 2026-11-04 \[1882:j1591#1\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: spec/pdp64-32/pdp64-32.hbnf header "207 forms, 268 leaves" (prefix-coded leaves); docs/encoding-proposal.md:27 "Prefix at the top of parcel 0 (1 to 16 bits)"
- Doc differs: docs/encoding-proposal.md:27 prefix of 1 to 16 bits, not opcode(6)
- Left: the chain records no ruling on the 6-bit opcode design; the prefix-coded work (decided 2026-11-04 as an encoding that minimizes size) covers the same ground in another way

## Instruction set: instruction groups

### Integer abs/min/max and conditional select
- Status: IN THE AIR — the chain says aliases on top of a select, the repository has them as native opcodes (latest decision 2026-10-21 \[1889:j71358#2\])
- Decided: 2026-10-21 decided: "happy for abs/min/max to be aliases on top of it in the assembler" \[1889:j71358#2\]
- Rationale: "surely other cpus have these opcodes and could benefit from them? who knows how much of an optimization this might bring us" \[1889:1856\]
- Precedent: cmov/csel/fsel (considered; named by author): wants to know more; abs/min/max as assembler aliases on top \[1889:j71358\]
- Precedent: ARM csel family (considered; named by assistant, not taken up): select variants nearly free once the first exists \[1889:1865\]
- Evidence: docs/pdp64-isa.md:857 "MIN, MINU, MAX, MAXU Ra, Rb, Rd" and :982 AESC sub-opcodes ABS 0x08, MIN 0x10..; spec/pdp64-32/pdp64-32.hbnf:153,164 "abs" "min" "max" as sub-opcodes; spec/pdp64-enc.hbnf:171 "bsel" "maskeqz" exist
- Doc differs: docs/errata.md item 23 says "AESC sub-opcodes 0x08 (abs rs, rd) and 0x10-0x13 (min, minu, max, maxu" (real opcodes, not assembler aliases)
- Left: the decision's relation is marked unclear: either abs/min/max become assembler aliases of a select (not done) or the native opcodes stand; the cmov/csel/fsel question was answered by maskeqz/masknez/bsel only

### Kernel assembly survey
- Status: IN THE AIR — only a potential idea, though a kernel assembly survey document exists (latest decision 2026-10-22 \[1889:2258#2\])
- Decided: no standing decision (only potential decisions)
- Rationale: compile the corpus with each clang backend "to check and see if there are any instructions we should adopt, or sequences we should coalesce" \[1889:2258\]
- Precedent: Linux and BSD kernel assembly (considered; named by author): survey for instructions like popx/pushx that compilers never emit \[1889:2258\]
- Precedent: clang backends (considered; named by author): compile the corpus with each to find instructions to adopt \[1889:2258\]
- Evidence: docs/kernel-asm-survey.md:28 "the hand-written assembly of a kernel a precise inventory of what an instruction set must offer"; docs/kernel-asm-survey.md:2181 pdp64 row
- Left: the records give no decision to survey Linux and BSD for instructions compilers never emit; whether the existing survey covers that is not stated

### Memory-to-memory moves and block operations
- Status: IN THE AIR — only potential ideas in the chain, but the ISA already has MCPY, MMOV and MSET (latest decision 2026-10-20 \[533:36#7\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:631 "MCPY Rd, Rs, Rn"; :632 MMOV; :633 "MSET"; :657 "MSET with Rv = 0 is the range-zeroing instruction"
- Left: no decision records the block-move instructions; plain memory-to-memory mov (the first idea) is not in the ISA

### Three added instructions (unclear)
- Status: IN THE AIR — the three items were never identified in the records (latest decision 2026-10-21 \[1889:1847#1\])
- Decided: no standing decision (status unclear)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/errata.md items 16-25 and docs/pdp64-isa.md; the likely candidates (exception flags item 17, abs/min/max item 23, set item 25) are recorded under their own decisions
- Left: identify the three things; the chain cannot say

### UTF-8 operations
- Status: IN THE AIR — only a potential idea in the chain, but the ISA already has UTF8LEN/DEC/ENC and MVAL (latest decision 2026-10-20 \[533:61#2\])
- Decided: no standing decision (only potential decisions)
- Rationale: "if utf8 is already 3 or 4 parcels, it's ok"; "validating an entire utf8 string sounds nice" \[533:61\]
- Evidence: docs/pdp64-isa.md:552 "4.6.1 UTF-8" (UTF8LEN, UTF8DEC, UTF8ENC); :637 "MVAL Rd, Rn validate Rn bytes as UTF-8"; handoff.md:137 lists UTF-8 instructions and MVAL as known gaps (not in the simulator)
- Left: no recorded decision; whole-string validation exists in the spec (MVAL) but handoff.md:137 says it is not implemented in the tools

## toolchain

### \-xdmr flag and default PDP-11 output
- Status: IN THE AIR — the record says the ungated change stays; the clone README says -xdmr gates the size tricks and -O turns it on (latest decision 2026-10-17 \[1889:642#1\])
- Decided: 2026-10-17 decided: "keep it": the ungated change to default PDP-11 output stays; push and look at qsort \[1889:642#1\]
- Precedent: dmr cc (considered; named by author): asked whether -xdmr output is faster/smaller than the original dmr cc \[1889:j13908\]
- Evidence: pcc:cc/cc/cc.c:2003 "-O here has always meant dmr-cc's code"; README.md "which -O turns on for the PDP-11 and AArch64"; commit 777517d "pdp11 (-xdmr): the low word of a long xor ..."
- Doc differs: README.md says "Without -xdmr the generated code differs from stock only through the bug fixes below"
- Left: whether any change to default PDP-11 output is ungated is not settled by the log; the "faster/smaller than dmr cc" question is answered by doc/SIZE-REPORT.md -3.2%/-4.2%

### Book toolchain, build image and aports
- Status: IN THE AIR — the ada-on-alpine repo and image are not here (latest decision 2026-10-23 \[1889:2987#1\])
- Decided: 2026-10-23 decided: Drop the local ada-on-alpine changes unless substantively better; then rebase on head and include the new/better stuff. \[1889:2987#1\]
- Rationale: "you are supposed to use the alpine docker image with hbnf and buildabook installed already NOT go about reimplementing stuff!" \[1889:2744\]
- Rationale: drop local ada-on-alpine changes "unless you did something substantively better" \[1889:2987\]
- Precedent: alpine:edge docker with ada-on-alpine (chosen; named by author): build and install all the aports on it \[1889:2796\]
- Precedent: buildabook (chosen; named by author): replace mkbook.py and push buildabook \[1889:2828\]
- Precedent: mkbook.py (rejected; named by author): reimplementing what buildabook does \[1889:2744\]
- Evidence: packaging repo: status-check/ada-on-alpine (HEAD 77daf37, 2026-11-07) has one linear history by the author (no merges) with 4a4ff58/aa4cc00 of 2026-10-23 "build git HEAD, not releases" and tools/build-hbnf.sh takes its .apk files, consistent with but not proof of the rebase (which local changes were dropped is not recorded); older note: only ada-on-alpine.tgz exists; buildabook commit d78be68 and tools/mkbook.sh (no mkbook.py) show the replacement
- Left: Left: confirm the rebase

### The four open items
- Status: IN THE AIR — the four items are not named in the chain (latest decision 2026-10-13 \[1889:506#1\])
- Decided: 2026-10-13 approved-proposal: "continue doing those 4 open items in order" \[1889:506#1\]
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched the git log of status-check/pcc for a list of open items
- Left: identify the four items

### as32v in the v7unix-toolchain repo and tool naming
- Status: IN THE AIR — the chain says 32vas next to v7as; the repo has as32v and -v7 suffixes (latest decision 2026-10-18 \[1889:j41256#1\])
- Decided: 2026-10-18 decided: "i think you need to use v7yacc for that" \[1889:j41256#1\]
- Rationale: port the 32V as to v7unix-toolchain: "would be useful" \[1889:j41047\]
- Rationale: rename to asv7 ccv7 cppv7 "then we can do as32v etc" \[1889:j41544\]
- Precedent: 32V assembler (chosen; named by author): port it into the v7unix-toolchain project \[1889:j41047\]
- Precedent: yacc (chosen; named by author): use it for the old-yacc grammar \[1889:j41256\]
- Precedent: v7as / v7cc prefix naming (rejected; named by author): change policy to asv7, ccv7, cppv7 suffixes \[1889:j41544\]
- Evidence: toolchain commit 7c56942 "v7-prefixed command names become -v7 suffixes (ccv7, asv7, ldv7)"; Makefile.am:38 as32v
- Doc differs: the record "it will install as 32vas alongside v7as" differs: the repo installs as32v beside asv7
- Left: Left: naming policy; use of v7yacc not checked

### hbnf fixes and upstreaming
- Status: IN THE AIR — hbnf fix lives in the hbnf repo, outside those checked (latest decision 2026-10-21 \[1889:1802#1\])
- Decided: 2026-10-21 approved-proposal: "yes, push it when the suite passes" (the hbnf single-character-literal fix). \[1889:1802#1\]
- Rationale: "that's insane, it should work with string literals too! fix hbnf" \[1889:1796\]
- Rationale: "a number is a number, it should handle all number formats" \[1889:j69533\]
- Evidence: commits ca4cf63 "hbnf has the numbers change upstream (c99c7cc); drop the local patch"; the single-character-literal push not checked: no hbnf repo among those named
- Left: Left: confirm the push

# Rejected or replaced (7)

- Rejected, reversed, or replaced by a later decision (the later one has precedence).

## 01 Principles and priorities

### C64 keyboard
- Status: REJECTED — the original C64 keyboard is refused (latest decision 2026-06-25 \[1058:12#2\])
- Decided: 2026-06-25 rejected: Rejects the original C64 keyboard: "i don't want to be stuck with that shitty keyboard". \[1058:12#2\]
- Rationale: "i don't want to be stuck with that shitty keyboard." \[1058:12\]
- Precedent: Commodore 64 (rejected; named by author): "shitty keyboard" \[1058:12\]
- Precedent: RPi 500 keyboard (chosen; named by author): "the rpi500 keyboard is adequate" \[1058:12\]
- Evidence: not found: searched pdp64 docs for the C64 keyboard as a requirement; the repository does not carry it (not stale)

## Documentation and process

### Manual location and split
- Status: REJECTED — three separate manuals were replaced by pdp64/32 as the one decided pdp64; the repository is stale (latest decision 2026-11-05 \[1882:j3626#2\])
- Decided: 2026-11-05 approved-proposal: "docs/manual/ becomes a landing page; manuals in pdp64-r20, pdp64-16, pdp64-32 subfolders (Recommended)" \[1882:j3626#2\]
- Rationale: "are separate manuals because they are different cpus" \[1882:295\]
- Evidence: docs/manual/00-index.md still has the r20/16/32 table; docs/manual/pdp64-r20, pdp64-16, pdp64-32 and book/pdp64-{r20,16,32}.pdf all exist (commit c48e8c0); the replacing decision (pdp64/32 only) is stated by the task, no dated record in this chain
- Doc differs: docs/manual/00-index.md says "The pdp64 is a family of three CPUs, and each has its own manual"; errata 93 says the same
- Left: stale: docs/manual/pdp64-r20 and pdp64-16, manual-src member blocks \[\[r20 16: ...\]\], three book builds; collapse to a single pdp64/32 manual

## Instruction set: encoding

### Prefix-coded encodings, 16-register and 32-register grammars
- Status: REJECTED — the two-grammar split was cancelled by the 32-register-only decision; spec/pdp64-16 is stale (latest decision 2026-11-09 \[592:38#1\])
- Decided: not in force (reversed 2026-11-09): the two-grammar split of 16 and 32 registers was cancelled by 592:38 (see Register count)
- Rationale: goal for the encoding: "minimizes code size and fits them all in with 32 reg and with 16 reg" \[1882:172\]
- Precedent: RISC-V (considered; named by author): faulted for no comparison of opcode counts or bit layouts with pdp64 \[592:38\]
- Evidence: later decision 2026-11-09 \[592:38#1\]; stale state: spec/pdp64-16/pdp64-16.hbnf and spec/README.md:10 still list pdp64/16
- Doc differs: docs/errata.md item 87 says "the architecture is pdp64 and its two members are pdp64/16 (16 registers, 4-bit register fields"

## Instruction set: instruction groups

### CRC instructions
- Status: REJECTED — CRC32/CRC32C withdrawn in favour of carry-less multiply; the repository agrees (latest decision 2026-10-21 \[1889:1851#1\])
- Decided: not in force (rejected 2026-10-21): "we have carryless mul no need for either crc". \[1889:1851#1\]
- Rationale: "we have carryless mul no need for either crc" \[1889:1851\]
- Precedent: carry-less multiply (chosen; named by author): replaces both CRC variants \[1889:1851\]
- Evidence: docs/pdp64-isa.md:600 "There are no CRC32 or CRC32C instructions"; docs/errata.md item 20; repository not stale

### Opcode usage, instruction count and pruning
- Status: REJECTED — cutting to about 70 instructions was rejected; the repository does not cut (latest decision 2026-10-21 \[1889:1845#1\])
- Decided: 2026-10-21 rejected: Rejects cutting the instruction set to about 70: "no, we beat the ppc601 we're doing good". \[1889:1845#1\]
- Rationale: "no, we beat the ppc601 we're doing good" \[1889:1845\]
- Rationale: "a rarely used instruction can still pull its weight if its used inside a critical tight hot loop" \[1889:2969\]
- Rationale: wants usage counts "so if we need to restructure, we can" \[1889:j71202\]
- Precedent: PowerPC 601 (considered; named by author): cited as the measure pdp64 already beats; against cutting to about 70 \[1889:1845\]
- Evidence: docs/errata.md item 68 (instructions judged by hot-loop weight); docs/pdp64-isa.md:19 the hot-loop standing constraint; spec/pdp64-32/pdp64-32.hbnf keeps 207 forms; repository not stale

### Resume-mov opcode
- Status: REJECTED — single move with progress in registers, no resume opcode; the repository agrees (latest decision 2026-11-09 \[592:21#1\])
- Decided: not in force (rejected 2026-11-09): "good" to keeping the single move instruction with progress in registers and no resume opcode. \[592:21#1\]
- Rationale: accepted from the assistant ("good"): a separate resummov would multiply entities without benefit and need a different instruction after a fault \[592:21\]
- Precedent: virtio (considered; named by assistant, accepted): progress lives in memory rings; same principle as progress in registers \[592:21\]
- Evidence: docs/pdp64-isa.md:1250 "An MBLK instruction is interruptible. At every point ... Rd, Rs/Rv and Rn hold state consistent with byte-at-a-time progress"; repository not stale

## Instruction set: registers

### Register names (r16)
- Status: REJECTED — replaced by the 32-register pdp64/32 where r16-r31 are defined (latest decision 2026-11-09 \[592:38#1\])
- Decided: 2026-10-21 decided: "r16 should be an assembler error. only r0 .. r15 are defined, plus aliases" \[1889:j70992#1\]
- Rationale and precedent: none stated in the sources
- Evidence: spec/pdp64-32/pdp64-32.hbnf regs list r0..r31; later decision 2026-11-09 \[592:38#1\]; stale: docs/pdp64-isa.md:80 "Sixteen registers, R0-R15"
- Doc differs: docs/errata.md item 87: "r16-r31 exist only in pdp64/32"

# Done (142)

- Implemented in the current code or stated in the current docs, with the evidence.

## 01 Principles and priorities

### Architecture scope includes the bus
- Status: DONE — the bus has its own chapter and document (latest decision 2026-10-22 \[1889:2048#1\])
- Decided: 2026-10-22 decided: "even the bus design is an important part of the architecture not just the instruction set". \[1889:2048#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/02-bus.md; docs/pdp64-q64-bus.md; README.md bus sentence (commit chain "start the bus document and the README sentence")

### CPU vulnerability avoidance
- Status: DONE — documented (latest decision 2026-10-22 \[1889:2605#1\])
- Decided: 2026-10-22 decided: "all the cpu bugs that needed mitigations" documented "so we don't repeat them"; "no hammer-row, no spectre, no timing channel attacks" \[1889:2605#1\]
- Rationale: document all the CPU bugs needing mitigations "so we don't repeat them" \[1889:2605\]
- Precedent: Rowhammer (rejected; named by author): "no hammer-row" \[1889:2605\]
- Precedent: Spectre (rejected; named by author): "no spectre" \[1889:2605\]
- Precedent: timing channel attacks (rejected; named by author): wants a constant-time flag so instructions take equal time \[1889:2605\]
- Evidence: docs/hardware-vulnerabilities.md (Rowhammer, Spectre, Hertzbleed in section 12); docs/openbsd-mitigations.md

### Design philosophy and optimization layers
- Status: DONE — the layers and the hindsight point are in the principles and the introduction commentary (latest decision 2026-10-23 \[1889:j78988#1\])
- Decided: 2026-10-23 decided: "in hindsight" the design is "even more minimal than the vax and pdp11"; hindsight shows "which theoretical completeness we could trade for more power" \[1889:j78988#1\]
- Rationale: the design was chosen "to have less possibility for error, fewer footguns, fewer surprises"; code size reduced at every level, instructions with "the most bang for buck" \[1889:2028\]
- Rationale: hindsight showed "which theoretical completeness we could trade for more power" \[1889:j78988\]
- Rationale: "my top priorities are code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[1889:2506\]
- Rationale: "fewer possible errors means less recovery code. easier recovery path means less recovery code." \[1889:j77559\]
- Precedent: PDP-11 and VAX-11 (chosen; named by author): famous for being pleasant and fun to program in assembly; project updates them \[1889:2028\]
- Precedent: VAX and PDP-11 (minimality) (considered; named by author): pdp64 is "even more minimal" in hindsight \[1889:j78988\]
- Evidence: docs/manual-src/01-introduction.md:55 commentary on the PDP-11/VAX completeness; docs/manual-src/01-introduction.md:59 section 1.4 priorities
- Left: the 2026-11-04 potential on -xssa (a larger instruction in a tight loop) is open, not recorded as a decision

### Design priority list
- Status: DONE — the definitive list replaced the old one (latest decision 2026-11-04 \[1882:69#2\])
- Decided: 2026-11-04 decided: "recovery and restart go together". \[1882:69#2\]
- Rationale: "my top priorities are code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[1889:2506\]
- Rationale: "4 and 5 are essentially the same thing. recovery and restart go together." \[1882:69\]
- Evidence: docs/manual-src/01-introduction.md:59 "\*\*1.4.1\*\* ... restart and recovery go together"; docs/errata.md:233 entry 83; docs/priority-lists.md:118 "The definitive list"
- Doc differs: docs/priority-lists.md:120 still says "(For you to write. ...)" above the author's annotations

### Efficiency order for PIE
- Status: DONE — the order and the entity rule are in the manual (latest decision 2026-10-21 \[533:117#1\])
- Decided: 2026-10-21 changed: Same order, adding "don't increase transistor count too much ockam. don't multiply entities without benefit" \[533:117#1\]
- Rationale: efficient in this order: "no wierd side effects, no bumping other opcodes in a way that makes code size increase" \[533:117\]
- Rationale: "don't increase transistor count too much ockam. don't multiply entities without benefit" \[533:117\]
- Precedent: Ockham ("ockam") (chosen; named by author): entity-multiplication rule \[533:117\]
- Evidence: docs/manual-src/01-introduction.md:63 "\*\*1.4.3\*\* ... do not multiply entities without benefit"

### In-order and out-of-order design
- Status: DONE — stated in the manual and errata (latest decision 2026-10-23 \[1889:2971#1\])
- Decided: 2026-10-23 decided: The official docs must also say "designed to be efficient with in-order and out-of-order execution implementations". \[1889:2971#1\]
- Rationale: "although the first implementations will be in-order, we have to make the decision safe for out of order implementations" \[1889:2967\]
- Evidence: docs/manual-src/01-introduction.md:65 "\*\*1.4.4\*\* The architecture is designed to be efficient with in-order and out-of-order implementations"; docs/errata.md:174,218 entries 38, 68

### Keeping only part of the PDP-11 instruction set
- Status: DONE — instructions have been dropped (latest decision 2026-10-20 \[533:93#2\])
- Decided: 2026-10-20 decided: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[533:93#2\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[533:93\]
- Precedent: PDP-11 (chosen; named by author): kept in part; unneeded instructions dropped \[533:93\]
- Precedent: ror over rol (chosen; named by author): accepted the case for ror \[533:93\]
- Evidence: docs/errata.md:48 "16. \*\*DECISION: \`FRECPED\` and \`FRSQRTED\` dropped.\*\*"; docs/errata.md:121 entry 31 removes the fourth parcel

### MMU and FP units included
- Status: DONE — MMU and floating point are in the base architecture (latest decision 2026-08-30 \[533:2#3\])
- Decided: 2026-08-30 decided: "fp and mmu would be included by default" \[533:2#3\]
- Precedent: M8502 and x86 (chosen; named by author): adopt what is needed from them, low transistor count \[533:2\]
- Precedent: Strecker VAX-11/780 paper (considered; named by assistant, not taken up): DEC considered extending the PDP-11 and gave reasons against \[533:2\]
- Evidence: docs/manual-src/06-kernel.md:75 "\`MMUCTL\` ... memory-management control"; docs/manual-src/01-introduction.md:51 "no separate floating-point register file" (FP shares the general registers)

### Mashup of PDP-11 with C64 / M8502
- Status: DONE — the pdp64 is the PDP-11 widened, with the C64 as a device and an 8502 island, not two chips side by side (latest decision 2026-08-29 \[531:6#1\])
- Decided: 2026-08-29 changed: Mashup means "not necessarily two chips operating simultaneously, but taking the best isa/architecture and improving it with the good stuff of the other one" \[531:6#1\]
- Rationale: "taking the best isa/architecture and improving it with the good stuff of the other one" \[531:6\]
- Rationale: "i think c64 is superior to blit terminal in many ways" \[531:0\]
- Rationale: m8502 and PDP-11 "seem much closer to each other" \[531:4\]
- Precedent: PDP-11 (chosen; named by author): "use pdp-11 as the base" \[788:0\]
- Precedent: m8502 (chosen; named by author): "we should mash that up instead of the c64" \[531:4\]
- Precedent: SID (chosen; named by author): fold in the good parts of the C64 \[531:0\]
- Precedent: Blit (considered; named by author): C64 judged superior; could the Blit be made C64-adjacent \[531:0\]
- Precedent: QNX/QUNIX (considered; named by author): fold design decisions into V7 for realtime guarantees \[531:2\]
- Evidence: README.md:4 "A 64-bit successor to the PDP-11 instruction set and architecture."; docs/c64-devices-from-chat.md:109 "A soft 8502 (not a socketed 6510)"; docs/manual-src/03-graphics.md:7 graphics built on the C64 and the Blit
- Doc differs: none found

### Mode bits and the "no mode bits" rule
- Status: DONE — the rule is dropped and the freebie is stated (latest decision 2026-11-04 \[1882:69#8\])
- Decided: 2026-11-04 decided: Modes in bits that are saved anyway are "a freebie. no brainer". \[1882:69#8\]
- Rationale: mode bits in bits saved anyway: "a freebie. no brainer."; modes "should be visible, not hidden state" \[1882:69\]
- Rationale: "the no mode bits rule is a very soft rule"; "where mode bits outweigh the costs, we take them" \[1889:2500\]
- Precedent: PDP-11 SR0 / VAX MAPEN (considered; named by assistant, not taken up): translation on/off switch, called the heritage choice by the assistant \[1889:2500\]
- Evidence: docs/manual-src/01-introduction.md:63 "a bit in a register that is saved anyway costs nothing extra"; docs/errata.md:233 entry 83 "the 'no mode bits' rule is dropped"

### Optimizer placement (optim2.c)
- Status: DONE — machine-independent optimizations live in mip/optim2.c and serve every back end (latest decision 2026-10-17 \[1889:601#1\])
- Decided: 2026-10-17 decided: "i love putting whatever possible into optim2.c for benefitt across all arches" \[1889:601#1\]
- Rationale: "for benefitt across all arches" \[1889:601\]
- Precedent: optim2.c (chosen; named by author): put whatever possible there \[1889:601\]
- Evidence: pcc clone status-check/pcc (HEAD 41e5c36): doc/PDP64-OPT.md:50 "\`-xccp\` ... (\`mip/optim2.c\` \`ccp\`, written in this phase)", :120 "c2's jump optimizer ... (\`deljumps\`, \`mip/optim2.c\`) ... MI", :162 "Machine-independent changes made in this phase: \`ccp\` (\`mip/optim2.c\`)", :146 \`bic\` for \`x & ~y\` ("\`AND\` made \`~R & L\` in \`optim2\`"); mip/optim2.c exists

### Project goal and deliverables
- Status: DONE — recorded as decisions and the manual is built (latest decision 2026-10-23 \[1889:j78776#1\])
- Decided: 2026-10-23 decided: "the manual for the arch (not only the isa) is the primary deliverable, but the as/ld/cc/emu are also important." \[1889:j78776#1\]
- Rationale: "the important part is the design and docs is most important, the as/ld/cc/emu parts are advanced as needed to do the docs" \[1889:2661\]
- Precedent: LLVM (chosen; named by author): final goal includes assembler, linker, compiler backend (llvm), emulator \[1889:2656\]
- Precedent: OpenBSD (chosen; named by author): port of openbsd we can ssh into \[1889:2656\]
- Evidence: docs/errata.md:202-204 entries 52, 53, 54; docs/manual/ and book/ PDFs (commit c48e8c0 "the three manuals as PDFs")

### Soft rules and principle exceptions
- Status: DONE — stated as a principle and recorded (latest decision 2026-10-22 \[1889:j77517#1\])
- Decided: 2026-10-22 decided: "all the rules are soft rules." \[1889:j77517#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/01-introduction.md:61 "\*\*1.4.2\*\* All the rules are soft rules"; docs/errata.md:191 entry 42

### Widening the PDP-11 to 64 bits
- Status: DONE — the architecture is a 64-bit PDP-11 successor with 32-bit forms (latest decision 2026-08-30 \[533:10#1\])
- Decided: 2026-08-30 decided: "basically upgrade pdp-11 straight to 64 bit" \[533:10#1\]
- Rationale: keeping "some of its nice properties" while adopting from m8502 and x86 "to keep transistor count down while still being reasonably nice to program in assembler" \[533:2\]
- Precedent: VAX-11 (considered; named by assistant, not taken up): widened PDP-11 pleasant to write and target \[533:2\]
- Precedent: M8502 and x86 (chosen; named by author): sources for what the widened PDP-11 needs \[533:2\]
- Evidence: docs/manual-src/01-introduction.md:5 "The pdp64 is a 64-bit successor to the PDP-11"; docs/manual-src/01-introduction.md:33 "The VAX-11 widened the PDP-11 to 32 bits"

### Work-order priorities (what to do next)
- Status: DONE — the LLVM backend, assembler, linker and simulator exist and instruction counts are measured (latest decision 2026-10-21 \[1889:j70991#1\])
- Decided: 2026-10-21 decided: "before we do the emulator i want the backend started so i can start looking at instruction counts." \[1889:j70991#1\]
- Rationale: "so i can start looking at instruction counts" \[1889:j70991\]
- Evidence: llvm/ (target, build.sh); README.md:83 "six large programs execute 19% and 24% fewer instructions"; qemu/ and sim64/ exist
- Doc differs: none; the "once the bugs on powerpc are fixed" line is an unclear referent and needs no action here

## 02 Bus

### Bus enumeration and attached buses
- Status: DONE — the bus is a device that enumerates; arbitrary buses attach (latest decision 2026-10-23 \[1889:2941#1\])
- Decided: 2026-10-23 decided: "just as usb is unuerated over a pcie bus, our q64 bus will allow arbitrary buses to be connected to it and enumerated" \[1889:2941#1\]
- Precedent: USB enumerated over PCIe (chosen; named by author): model for q64 enumerating arbitrary attached buses \[1889:2941\]
- Evidence: docs/errata.md:199,217 entries 49, 67; docs/manual-src/02-bus.md:77 STATUS register, section 2.6

### Bus hotplug
- Status: DONE — arrival and departure raise an event (latest decision 2026-10-22 \[1889:2625#3\])
- Decided: 2026-10-22 decided: "we do need some way for the bus to alert us when a device enters or leaves the bus" \[1889:2625#3\]
- Rationale: queued work of a departed device left in memory "so it can be read, saved, resent" \[1889:2641\]
- Evidence: docs/manual-src/02-bus.md:86 "\*\*2.6.4\*\* An arrival or departure puts an event in a small queue and raises an interrupt"; :90 "\*\*2.6.6\*\* The queued work of a departed device stays in memory ... \*(P)\*"
- Left: the resend-after-departure question is still tagged (P), a proposal

### Physical address bit that selects device space
- Status: DONE — bit 39 selects the space (latest decision 2026-11-09 \[592:15#2\])
- Decided: 2026-11-09 decided: "the whole bit 39 decides if memory or dma should go away"; "if we are going to mmap petabytes, we need those bits." \[592:15#2\]
- Rationale: "if we are going to mmap petabytes, we need those bits." \[592:15\]
- Precedent: Loongson 5-level TLB (considered; named by author): asked what else is affected if pdp64 had it \[592:15\]
- Precedent: VAX I/O space (considered; named by assistant, not taken up): VAX kept moving its I/O base; single fixed bit avoids that \[1889:2713\]
- Precedent: SCSI/ATA/SATA/NVMe (considered; named by author): all follow the same device pattern, not limited to 8-register mmio \[1889:2713\]
- Evidence: docs/manual-src/02-bus.md:21 "\*\*2.1.6\*\* The top bit of the 40-bit physical address (bit 39) selects the space"; docs/decisions-pending.md:123 P19 DECIDED
- Doc differs: docs/errata.md:210 entry 60 still headed "PROPOSAL ... bit 40"
- Left: the "mmap petabytes" remark may widen the physical address beyond 40 bits; no record says so

### Q64 bus: DMA design, document and PCI Express base
- Status: DONE — Q64 is PCI Express with mitigations, extensions announced only if a card takes part (latest decision 2026-11-04 \[1882:51#1\])
- Decided: 2026-11-04 decided: Extensions "depends on the mitigations; if they don't affect the cards, the cards don't need to know". \[1882:51#1\]
- Rationale: "whatever is the most standard, secure, easy to support nic and gpu and audio interfaces will be standardized for iteration one" \[1882:23\]
- Rationale: "backward compatible with extra convenience/security circuitry added" \[1882:49\]
- Rationale: extensions: "if they don't affect the cards, the cards don't need to know" \[1882:51\]
- Precedent: PCI Express (chosen; named by author): pcie for the q64 bus, with pain points solved or mitigated \[1882:23\]
- Precedent: NVMe (chosen; named by author): storage on the q64 bus \[1882:23\]
- Precedent: USB (chosen; named by author): on the q64 bus \[1882:23\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[592:15\]
- Precedent: native 8-register devices (rejected; named by author): "forget the native 8 register devices. gone." \[592:15\]
- Precedent: IOMMU mapping of C64/C128 (considered; named by author): "i think we should, but that is extraneous" \[1882:23\]
- Evidence: docs/errata.md:225,230,231 entries 75, 80, 81; docs/decisions-pending.md:1593 "F29 ... Decided (errata 81)"; docs/manual-src/02-bus.md:9 PCI Express note
- Doc differs: docs/manual-src/02-bus.md:9 says "its full rewrite waits"; docs/pdp64-q64-bus.md:25 "the transaction definitions (widths, bursts, ...) are not written"
- Left: chapter body still describes the pre-PCIe model (see "Bus update to virtio-only")

## 03 Graphics and the C64 devices

### Blit and C64 as the terminal model
- Status: DONE — chapter 3 names both (latest decision 2026-10-23 \[1889:2935#1\])
- Decided: 2026-10-23 decided: The design is based "not only on the c64, but also on the blit terminal" \[1889:2935#1\]
- Rationale: "i think c64 is superior to blit terminal in many ways... could we revamp the blit to be c64 adjacent" \[531:0\]
- Rationale: "i like the blit model" \[1882:23\]
- Precedent: Blit (chosen; named by author): design based "not only on the c64, but also on the blit terminal" \[1889:2935\]
- Precedent: Commodore 64 (chosen; named by author): pdp-11 base with c64 graphics and audio \[531:0\]
- Precedent: Commodore 128 (considered; named by author): asked what advances it had over the c64 \[531:2\]
- Evidence: docs/manual-src/03-graphics.md:11 "\*\*3.1.1\*\* The graphics terminal is based on two machines, not one"; docs/errata.md:216 entry 66
- Left: the potentials (blit as modernized C64, plan9 /draw, "i like the blit model") are open

### C128 as a bus device
- Status: DONE — recorded (latest decision 2026-11-04 \[1882:34#1\])
- Decided: 2026-11-04 decided: "the c128 will just be another device on the bus; not part of the pdp64 standard". \[1882:34#1\]
- Precedent: Commodore 128 (chosen; named by author): "just another device on the bus", not in the standard \[1882:34\]
- Evidence: docs/errata.md:227 entry 77
- Left: the iommu mapping of c64/c128 is a potential, open

### C64 island: 8502 registers readable from outside
- Status: DONE — recorded as a design point of the 8502 island (latest decision 2026-08-29 \[531:24#1\])
- Decided: 2026-08-29 decided: "we can make all registers readable from outside. writeable too. just hold the rdy pin." \[531:24#1\]
- Rationale: "if we're implementing the 8502 in fpga we can make all registers readable from outside. writeable too. just hold the rdy pin." \[531:24\]
- Precedent: 8502 RDY pin hold (chosen; named by author): freeze the CPU to read and write registers \[531:24\]
- Evidence: docs/c64-devices-from-chat.md:38 "Island access"; :109 "In fabric, A, X, Y, S, P and PC are readable at any cycle"
- Doc differs: the C64 devices are deferred (errata 78), so the island is not in the manual

### C64-derived devices (VIC, SID, BLT, 12-register devices)
- Status: DONE — deferred to iteration two, as stated (latest decision 2026-11-04 \[1882:38#1\])
- Decided: 2026-11-04 decided: "the vic-64x, sid-64x, blt64 are deferred for now". \[1882:38#1\]
- Rationale: "for now we will have a standard pcie set of audio/video devices" \[1882:38\]
- Evidence: docs/manual-src/03-graphics.md:5 "Iteration two. The devices of this chapter ... are planned for the future"; docs/errata.md:225,228 entries 75, 78

### Pixel and audio sample width
- Status: DONE — 48-bit pixels and samples are specified for the future devices (latest decision 2026-11-04 \[1882:j456#1\])
- Decided: 2026-11-04 decided: "48 bit pixels, 48 bit audio samples.... for the future, same time as the 12 register devices" \[1882:j456#1\]
- Precedent: SID (considered; named by author): "i want 48 bit sound as well, not just the sid" \[1882:20\]
- Evidence: docs/manual-src/03-graphics.md:13,15 "48-bit pixels", "audio samples are 48 bit"; docs/errata.md:223,224 entries 73, 74

### Standard GPU, NIC and audio interfaces
- Status: DONE — virtio-net, virtio-gpu and virtio-snd are the standard (latest decision 2026-11-04 \[1882:38#2\])
- Decided: 2026-11-04 decided: Standard pcie audio/video devices, "the ones that are the simplest to program while still being efficient", so there is no bullshit supporting many device drivers. \[1882:38#2\]
- Rationale: "i want a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers"; pick "the simplest to program while still being efficient" \[1882:38\]
- Rationale: "if we can plug a regular card into the bus, why not?" \[1889:2704\]
- Precedent: PCI Express (chosen; named by author): standard set; any device MAY be attached \[1882:38\]
- Precedent: HDMI, SATA, USB (considered; named by author): "standard kit", our interface goes through mmio \[1889:2704\]
- Evidence: docs/errata.md:228,229 entries 78, 79; docs/manual-src/02-bus.md:9 "virtio-net, virtio-gpu and virtio-snd"

### Video output (HDMI)
- Status: DONE — recorded in the device-chat summary and the FRAMEPOL register (latest decision 2026-08-29 \[531:29#2\])
- Decided: 2026-08-29 decided: "in general we should be able to drive the hdmi however we want; not limited to 16 colors, not limited in font size or rows and columns" \[531:29#2\]
- Rationale: "not limited to 16 colors, not limited in font size or rows and columns" \[531:29\]
- Rationale: "since the soc will have hdmi, pal/ntsc isn't too relevant except for backwards compat" \[531:24\]
- Precedent: HDMI (chosen; named by author): drive it however we want \[531:29\]
- Precedent: PAL/NTSC (considered; named by author): 50 fps only for legacy code, backwards compat \[531:29\]
- Evidence: docs/c64-devices-from-chat.md:37 "i prefer to drive the hdmi at 50 fps"; :100 "\`ROWS\`, \`COLS\`, \`CELLW\`, \`CELLH\` are 16-bit registers"
- Doc differs: the standard video device is now virtio-gpu (errata 79), so HDMI timing is not in the manual body

## 04 Boot

### Boot process, BIOS and open firmware
- Status: DONE — open source boot software is part of the spec; BIOS covered in the boot chapter (latest decision 2026-10-22 \[1889:2620#1\])
- Decided: 2026-10-22 decided: "we'll have an open source boot sector boot loader as part of the spec; that is part of the spec that the boot loader/bios is open source" \[1889:2620#1\]
- Rationale: "for such a simple arch" a controller must boot the others; wants "load 512 byte block 0 then jmp 0" \[1889:2614\]
- Precedent: PDP-11 (chosen; named by author): load 512-byte block 0 then jump to 0 \[1889:2614\]
- Precedent: UEFI (considered; named by author): asked to look into it \[1889:2614\]
- Precedent: OpenBSD disk partitioning (considered; named by author): asked where it originated and how it differs \[1889:2620\]
- Precedent: V7 Unix (considered; named by author): values in an assembler file, kernel recompiled \[1889:2620\]
- Precedent: GPT (considered; named by author): asked how it plays into boot \[1889:2620\]
- Evidence: docs/manual-src/04-boot.md:13 "\*\*4.1.2\*\* The boot software is open source and part of the specification"; docs/errata.md:197 entry 47; docs/boot.md
- Left: the review of SMP boot and UEFI is a potential only

### Disk label and boot block
- Status: DONE — GPT wrapper and majority offsets (latest decision 2026-10-22 \[1889:j78553#1\])
- Decided: 2026-10-22 decided: "follow the majority as far as boot block offset" \[1889:j78553#1\]
- Precedent: GPT (chosen; named by author): "we will have the gpt wrapper for the disk label" \[1889:2631\]
- Precedent: majority boot block offset (chosen; named by author): "follow the majority as far as boot block offset" \[1889:j78553\]
- Evidence: docs/manual-src/04-boot.md:31 "## 4.3 The disk: a GPT around the BSD label"; docs/errata.md:200,201 entries 50, 51

## 05 Drivers and devices

### Modern I/O hardware (USB, NVMe)
- Status: DONE — USB and NVMe are the standard storage and input (latest decision 2026-08-29 \[531:0#5\])
- Decided: 2026-08-29 decided: "modern usb keyboard, mouse, and nvme hard drive", plus usb hard drive \[531:0#5\]
- Precedent: USB (chosen; named by author): modern usb keyboard, mouse and hard drive \[531:0\]
- Precedent: NVMe (chosen; named by author): "nvme hard drive" \[531:0\]
- Precedent: Raspberry Pi SD-card storage (considered; named by author): asked how those little SanDisk drives interface with rpi \[531:0\]
- Evidence: docs/errata.md:225 entry 75 "built on PCI Express, NVMe and USB"; docs/manual-src/05-drivers.md:25 storage interfaces including NVMe

## 06 Kernel, modes and memory management

### Exception and interrupt entry
- Status: DONE — priority 7 on entry with EPC and EPSW (latest decision 2026-10-22 \[1889:2361#1\])
- Decided: 2026-10-22 decided: "go with priority 7 on entry and document its throwback to pdp-11 design." \[1889:2361#1\]
- Precedent: PDP-11 (chosen; named by author): priority loaded on trap; "document its throwback to pdp-11 design" \[1889:2361\]
- Evidence: docs/manual-src/06-kernel.md:27 "\*\*6.2.2\*\* The new status word has ... priority 7"; docs/errata.md:159,185 entries 36, 40
- Doc differs: docs/decisions-pending.md says "I extended it to interrupts, which you did not explicitly say" (flagged for the author to confirm)

### First operating system port
- Status: DONE — OpenBSD first, 32V fallback, 3BSD dropped (latest decision 2026-10-22 \[1889:2401#1\])
- Decided: 2026-10-22 decided: "forget 3bsd we'll do 32v port if openbsd proves too hard"; suspects OpenBSD "is doable". \[1889:2401#1\]
- Rationale: "actually we'll port 32v unix since it has demand paging already" \[1889:j73728\]
- Rationale: "if we are going straight to 3bsd why not openbsd"; later "i suspect it is doable" \[1889:2199\]
- Precedent: OpenBSD (chosen; named by author): first port; "i suspect it is doable" \[1889:2401\]
- Precedent: Unix/32V (chosen; named by author): fallback "if openbsd proves too hard"; has demand paging \[1889:2401\]
- Precedent: 3BSD (rejected; named by author): "forget 3bsd"; earlier considered as first with virtual memory \[1889:2401\]
- Precedent: V7 Unix (considered; named by author): "initially we port v7 unix"; replaced by 32V \[1889:j73710\]
- Evidence: docs/manual-src/06-kernel.md:126 "\*\*6.6.3\*\* The first operating system is OpenBSD, with Unix/32V as the fallback"; docs/errata.md:188 entry 41
- Doc differs: docs/errata.md:114 entry 30 and :165 entry 30a keep the older text as history (marked superseded by 41)

### MMUCTL
- Status: DONE — (latest decision 2026-10-22 \[1889:2497#2\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P10" (MMUCTL). \[1889:2497#2\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:194 entry 44; docs/manual-src/06-kernel.md:75 \`MMUCTL\` row

### Memory safety from OpenBSD mitigations
- Status: DONE — the study exists and its proposals were answered (latest decision 2026-10-22 \[1889:j78280#1\])
- Decided: 2026-10-22 decided: "looking at the openbsd mitigations for memory safety, make that soft and easy, if you can't even think of improvements that theo would love." \[1889:j78280#1\]
- Precedent: OpenBSD mitigations (chosen; named by author): make memory-safety mitigations "soft and easy"; improvements "theo would love" \[1889:j78280\]
- Evidence: docs/openbsd-mitigations.md "what would make them soft and easy"; docs/errata.md:235,236 entries 85, 86

### Page-table accessed and dirty bits
- Status: DONE — software-managed (latest decision 2026-10-22 \[1889:j74765#2\])
- Decided: 2026-10-22 approved-proposal: Page-table accessed (A) and dirty (D) bits set by="Software (Recommended)" \[1889:j74765#2\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:159 entry 36 "software-managed accessed and dirty bits"

### Paging support work
- Status: DONE — MFSR/MTSR and the paging instructions are in the docs and QEMU has the MMU (latest decision 2026-10-22 \[1889:2193#1\])
- Decided: 2026-10-22 decided: "start on the qemu mmu and privileged mode". \[1889:2193#1\]
- Rationale: "didn't you notice some missing instructions that a paging os needs?" \[1889:2138\]
- Evidence: docs/errata.md:129 entry 32 "system-register moves \`MFSR\` and \`MTSR\`"; qemu/README.md:76 "QEMU's TLB is per MMU index"
- Left: none known

### Precise exceptions
- Status: DONE — the candidate list was written and annotated, though the chain shows only a potential (latest 2026-11-04 \[1882:69#6\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/retire-stage-candidates.md:1 "Candidate features that precise exceptions and out-of-order execution make cheap"; docs/errata.md:234 entry 84 "the nineteen retire-stage candidates"

### System architecture section
- Status: DONE — drafted (latest decision 2026-10-22 \[1889:2073#1\])
- Decided: 2026-10-22 approved-proposal: "draft the system architecture section" (PSW, exception entry, interrupt controller, timer). \[1889:2073#1\]
- Rationale: "whatever is undefined, say in the docs so we can design it later." \[1889:2073\]
- Evidence: docs/pdp64-system-architecture.md (398 lines); docs/manual-src/06-kernel.md

### User-memory guard
- Status: DONE — (latest decision 2026-10-22 \[1889:2497#1\])
- Decided: 2026-10-22 approved-proposal: "write the errata for P2" (user-memory guard). \[1889:2497#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:192 entry 43 "a user-memory guard, \`UA\`"; docs/manual-src/06-kernel.md:115 "\*\*6.5.4\*\* ... \`.U\`"

### WFE wake on pending interrupt
- Status: DONE — (latest decision 2026-10-22 \[1889:j76720#1\])
- Decided: 2026-10-22 approved-proposal: WFE idle wait wakes on pending interrupt even if masked="Yes, wake on pending (Recommended)" \[1889:j76720#1\]
- Rationale: accepted from the assistant: lower-then-sleep misses an interrupt landing between the two instructions, and sleeping at priority 7 never wakes. \[1889:j76720\]
- Evidence: docs/manual-src/07-smp.md:78 "\*\*7.6.2\*\* \`WFE\` ends its sleep when an interrupt is pending even if the priority masks it"

## 07 Multiple processors

### Atomics
- Status: DONE — (latest decision 2026-10-22 \[1889:2497#3\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P11" (atomics). \[1889:2497#3\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:195 entry 45 "atomics are defined on a monitor (reservation), not a bus lock"

### Core counts
- Status: DONE — (latest decision 2026-11-04 \[1882:258#1\])
- Decided: 2026-11-04 decided: "for initial device 4 cores is enough hopefully that fits on the fpga". \[1882:258#1\]
- Rationale: "for initial device 4 cores is enough hopefully that fits on the fpga" \[1882:258\]
- Evidence: docs/manual-src/07-smp.md:90 "\*\*7.7.3\*\* ... sixteen or more is the preferred ceiling ... the initial device has four cores"; docs/smp-decisions.md:9-10; docs/errata.md:242 entry 92

### Mixed in-order and out-of-order cores
- Status: DONE — (latest decision 2026-11-04 \[1882:256#1\])
- Decided: 2026-11-04 decided: "its ok to have in order and out of order cores on the same die as long as we can tell which is which". \[1882:256#1\]
- Rationale: accepted condition: in-order and out-of-order cores are fine "as long as we can tell which is which". \[1882:256\]
- Evidence: docs/manual-src/07-smp.md:106 "\*\*7.8.5\*\* In-order and out-of-order cores may share a die if software can tell which is which"; docs/smp-decisions.md:11

### SMP and its decisions document
- Status: DONE — written, with Part C in decisions-pending.md (latest decision 2026-10-22 \[1889:2426#1\])
- Decided: 2026-10-22 approved-proposal: Add Part C covering smp, dma and virtualization gaps: "same style, 5 options, survey of what all major modern os and cpu do, plus vax/pdp". \[1889:2426#1\]
- Precedent: VAX/PDP (considered; named by author): survey "what all major modern os and cpu do, plus vax/pdp" \[1889:2426\]
- Evidence: docs/decisions-pending.md:1064 "## Part C. The gaps: several cores, DMA devices and virtualization"; docs/smp-decisions.md Parts A and B
- Left: the SMP requirements question (potential 533:61#3) is answered by smp-decisions.md

## 08 Vector work and accelerators

### GPU and accelerator meaning, helper chips
- Status: DONE — accelerators are memory-mapped devices sharing RAM (latest decision 2026-10-20 \[533:51#1\])
- Decided: 2026-10-20 decided: "gpu" means "a helper/accelerator that uses the same ram, does dma, etc", with "the simd/avax stuff" \[533:51#1\]
- Precedent: GPU (considered; named by author): meant as "a helper/accelerator that uses the same ram, does dma" \[533:51\]
- Precedent: SIMD/AVX (considered; named by author): helps like a GPU's, "the simd/avax stuff" \[533:51\]
- Precedent: Samsung LittleBit-2 (considered; named by author): a GPU optimized purely for its encoding \[533:51\]
- Evidence: docs/manual-src/08-vectors.md:5 "done by memory-mapped devices with their own memory"; docs/pdp64-lb64-accelerator.md
- Left: the littlebit-2 GPU and the utf8 helper chip are potentials only

### LLM training and inference focus
- Status: DONE — inference is the target (latest decision 2026-10-20 \[533:107#2\])
- Decided: 2026-10-20 decided: "just optimize inference whether in cpu or gpu whatever makes most sense" \[533:107#2\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/08-vectors.md:31 "## 8.3 AI and large-language-model inference"; docs/pdp64-lb64-accelerator.md

### SIMD and vector work
- Status: DONE — memory-mapped device route, no SIMD in the CPU, APL/K noted (latest decision 2026-10-23 \[1889:j79318#2\])
- Decided: 2026-10-23 decided: "we should go the mmap device arm style route" for SIMD/AVX2-type vector work \[1889:j79318#2\]
- Rationale: vector work "is about graphics and ai/llm stuff"; "apl/k" make vector languages "easier to support and more efficient". \[1889:j79318\]
- Precedent: ARM-style memory-mapped device (chosen; named by author): "mmap device arm style route" for SIMD/AVX2 vector work \[1889:j79318\]
- Precedent: AVX2 (considered; named by author): the SIMD work the chapter covers \[1889:j79318\]
- Precedent: APL/K (chosen; named by author): mention as making vector languages easier to support \[1889:j79318\]
- Evidence: docs/manual-src/08-vectors.md:9 "\*\*8.1.1\*\* The processor has no vector register file and no SIMD instruction set"; :45 "## 8.4 Array languages: APL and K"; docs/errata.md:209 entry 59

## 12 Documentation and process

### c64stuff extraction
- Status: DONE — the file exists and was compared with the docs (latest decision 2026-10-24 \[1888:33#1\])
- Decided: 2026-10-24 decided: Find conversations mentioning "pdp-11, vax, blit terminal, or c64" and extract them into "~/claude/pdp64/c64stuff.txt". \[1888:33#1\]
- Rationale and precedent: none stated in the sources
- Evidence: c64stuff.txt exists (untracked); docs/errata.md:222 entry 72 "\`c64stuff.txt\` ... was compared with the documents"

## Documentation and process

### Architecture recommendations and open proposals
- Status: DONE — the stale marks were re-marked and Part F carries the new requirements; the P9/P17/P18/F25 replies are recorded (latest decision 2026-11-04 \[1882:45#1\])
- Decided: 2026-11-04 approved-proposal: "yes": re-mark the stale kernel-pain-points status marks and add the new requirements to Part F. \[1882:45#1\]
- Rationale: "4 and 5 are essentially the same thing. recovery and restart go together" \[1882:69\]
- Rationale: mode bits "should be visible, not hidden state"; modes in bits "that are saved anyway sounds like a freebie" \[1882:69\]
- Precedent: Plan 9 draw(3)/devdraw (considered; named by assistant, not taken up): compared with ring-based command encoding for BLT64 \[1889:2962\]
- Evidence: commit 833afc9 (2026-11-03) "docs: re-mark pain-points rows for PCI Express; Part F F24-F28"; docs/kernel-pain-points.md:111 "Re-marked 2026-11-03 (errata 75, PCI Express)"; docs/decisions-pending.md:1595-1598 F24 to F27; docs/errata.md:85 "replies to the second round of security proposals" (P9, P17, P18, F25); docs/crypto-secure-core.md (P17 proposal); docs/study-proposals.md and docs/study-round2.md

### Author authority and source precedence
- Status: DONE — the rule is applied by the errata 'DECISION (the author's ...)' convention (latest decision 2026-10-23 \[1889:j79154#1\])
- Decided: 2026-10-23 decided: "my statements supersede yours unless i later agreed with you" \[1889:j79154#1\]
- Rationale: "doesn't matter if the docs mention it I mention it now therefore it is true and if the docs contradict me you must show why or how." \[1889:2041\]
- Rationale: "my statements supersede yours unless i later agreed with you." \[1889:j79154\]
- Rationale: "more recent stuff is considered more accurate than old stuff." \[1889:j79153\]
- Evidence: docs/errata.md:198, :243 mark author decisions with his words and 'What was assumed first and replaced'

### Benchmark and size reports
- Status: DONE — size report in the readme and linked (latest decision 2026-10-19 \[1889:j53715#1\])
- Decided: 2026-10-19 decided: "document all this make sure it is in the readme and pushed, show how the apparent size differences are due to things not being implemented and so the code is buggy" \[1889:j53715#1\]
- Rationale: "show how the apparent size differences are due to things not being implemented and so the code is buggy" \[1889:j53715\]
- Rationale: "i want a nice written report in md format at the end, linked into the readme" \[1889:j40663\]
- Rationale: "the report should call the 32v cc pcc. 32v pcc, v7 dmr-cc" \[1889:j44109\]
- Precedent: gcc -Os (considered; named by assistant, accepted): size gap explained as GCC deleting undefined-behaviour code \[1889:j53715\]
- Precedent: clang -Os (considered; named by assistant, not taken up): pcc about 20% larger; docs claiming 11% smaller corrected \[1889:1116\]
- Precedent: dmr cc (considered; named by author): named in report as v7 dmr-cc \[1889:j44109\]
- Precedent: 32V pcc (considered; named by author): name to use for the 32V cc \[1889:j44109\]
- Precedent: pcc (considered; named by author): compared with our pcc, opti and unopti, vax and pdp11 \[1889:j40664\]
- Evidence: pcc-enc:README.md:27 links doc/SIZE-REPORT.md; SIZE-REPORT.md 'compares stock pcc, this fork, clang, gcc, V7 dmr cc and 32V pcc'; pdp64 README.md 'same size as gcc -Os and 7% smaller than clang -Os'

### Decisions document
- Status: DONE — decisions document exists with errata inside and P15 (latest decision 2026-10-22 \[1889:2506#2\])
- Decided: 2026-10-22 decided: Errata should be in the decisions document; revise the open decisions document "in light of the rule change". \[1889:2506#2\]
- Rationale: my top priorities are "code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[1889:2506\]
- Rationale: wants previous decisions written up too "in case i want to change them" \[1889:2417\]
- Rationale: asked errata be in the decisions document "so i can read up on them" \[1889:2506\]
- Precedent: unix on PDP-11 and VAX-11 (considered; named by author): asked to compare decisions with what they used to do, and tradeoffs \[1889:2413\]
- Precedent: AArch64 ldtr/sttr and m68k moves (considered; named by assistant, not taken up): option B: separate access-as-user load and store forms \[1889:2406\]
- Precedent: x86, ARM and RISC-V kernels (incl. OpenBSD) (considered; named by assistant, not taken up): assistant's reason for recommending option A \[1889:2406\]
- Evidence: docs/decisions-pending.md (P1 to P15, 'Part 0 ... the rule change', 'Already decided'); docs/errata.md numbers decisions
- Doc differs: docs/errata.md is a separate file, not inside decisions-pending.md; decisions-pending.md is not linked from README text of rule 'don't link it' (README does link it at the principles section)

### Documenting bugs and defects
- Status: DONE — defects chapter exists in the tricks doc (latest decision 2026-10-18 \[1889:1075#1\])
- Decided: 2026-10-18 decided: "build the pushed commit and verify; document all the bugs you fixed that were pre-existing"; asks whether VAX is affected too, not only pdp11 \[1889:1075#1\]
- Rationale: "but the bugs we introduced ourselves and fixed, don't mention" \[1889:543\]
- Rationale: Separate "the bugs in the original unix code, and then the bugs in ragges pcc". \[1889:543\]
- Rationale: "document all the bugs you fixed that were pre-existing" \[1889:1075\]
- Rationale: "make sure you explain why i386 leal pie is ok too in the doc" \[1889:545\]
- Precedent: original Unix code (dmr) (considered; named by author): "note any dmr errors in the docs" \[1889:j16765\]
- Precedent: pcc (considered; named by author): upstream bugs documented separately from the originals \[1889:543\]
- Precedent: PDP-11 and VAX-11 (considered; named by author): asks whether pre-existing bugs are only pdp11 or vax too \[1889:1075\]
- Evidence: OPTIMIZATION-TRICKS.md:1226 '## Defects in the originals and in upstream pcc'; pcc-enc:doc/SIZE-REPORT.md 'What this run found'

### Fact-checking
- Status: DONE — fact-check record exists (latest decision 2026-10-22 \[1889:2467#1\])
- Decided: 2026-10-22 decided: Agent should look at whatever pages he sends it "even if it isn't a page it chose". \[1889:2467#1\]
- Rationale: "you're doing a lot from memory, i want you to check all the statements you've made today." \[1889:2236\]
- Rationale: "go through the document and verify all the "from memory" claims" \[1889:2431\]
- Rationale: "many of the manuals are hard to access; easier to look at the kernel source code?" \[1889:2484\]
- Rationale: "btw, the complete tuhs source is already here on this box no need to download it" \[1889:2456\]
- Precedent: TUHS source (chosen; named by author): already on the box, no download needed \[1889:2456\]
- Precedent: kernel source code (considered; named by author): suggested instead of hard-to-access manuals \[1889:2484\]
- Evidence: docs/fact-check-2026-10-22.md; docs/codegen-data/verification/claims.csv (cited in docs/decisions-pending.md)

### Git history, merging and pushing
- Status: DONE — push and merge rules are stated and followed; main carries the work (latest decision 2026-10-22 \[1889:2645#1\])
- Decided: 2026-10-22 decided: "push everything when the agent reports" \[1889:2645#1\]
- Rationale: "unless the md file commits are merged to main, htey don't show up on github" \[1889:j43239\]
- Rationale: accepted from the assistant: do not rewrite the pushed branch; build a squashed copy, one commit per feature, after long long lands. \[1889:1077\]
- Evidence: handoff.md section 1 'Push rules the author set: pdp64 goes to origin main ... one commit per feature'; git branch: feature branches enc-\*/man-\* merged into main (commit 39ea17b)
- Doc differs: git status: untracked c64stuff.txt, chat02.txt, tools/declog/ and modified .gitignore are not pushed (decision-log is deliberately local)

### ISA comparison table
- Status: DONE — side-by-side table with encodings is in the ISA text (latest decision 2026-10-20 \[533:36#9\])
- Decided: 2026-10-20 decided: "update the docs accordingly." \[533:36#9\]
- Precedent: PDP-11 (considered; named by author): asks whether R7 was the PC and about a read-only view \[533:36\]
- Precedent: LoongArch64 (considered; named by author): asked how they handle the PC \[533:36\]
- Precedent: PDP-11 (considered; named by author): asked how call/ret differs from it \[533:36\]
- Evidence: docs/pdp64-isa.md:1663 '## 13. Side by side: PDP-11, VAX, pdp64' with 13.2 encodings

### Kernel assembly survey document
- Status: DONE — own document with narrative and tables, linked in README (latest decision 2026-10-22 \[1889:2277#1\])
- Decided: 2026-10-22 decided: Wants both narrative and full table dumps: "table dumps really make the narrative come alive". \[1889:2277#1\]
- Rationale: "table dumps really make the narrative come alive, you know? want both." \[1889:2277\]
- Rationale: "should be its own document, do a good writeup, this will be a juicy topic" \[1889:2274\]
- Precedent: Linux and BSD kernel assembly (chosen; named by author): comparison from Linux to BSD as its own document \[1889:2274\]
- Precedent: VAX svpctx/ldpctx (considered; named by assistant, not taken up): hardware context switch sidebar \[1889:2277\]
- Evidence: docs/kernel-asm-survey.md; README.md 'What to read' item 5 and architecture text

### LLVM doc
- Status: DONE — one LLVM document: section 14 of the system architecture document was expanded, no second doc (latest decision 2026-10-22 \[1889:j75734#1\])
- Decided: 2026-10-22 decided: "the llvm rebuild was to expand and update the original doc, not to make a second doc" \[1889:j75734#1\]
- Rationale: "since the isa has changed since the last llvm check was done." \[1889:j75734\]
- Precedent: LLVM (considered; named by author): expand and update the original LLVM doc, not a second one \[1889:j75734\]
- Evidence: commit 94ce20e "docs: one LLVM document: section 14 of the system architecture document now holds the design, results, awkward spots, next steps"; docs/pdp64-system-architecture.md:219 "## 14. The LLVM back end, and OpenBSD" (14.1 to 14.3); llvm/README.md is the build note; no llvm-named doc in docs/

### License
- Status: DONE — BSD 2-clause COPYING in place (latest decision 2026-10-22 \[1889:j78490#1\])
- Decided: 2026-10-22 decided: "yes, bsd license for everything." \[1889:j78490#1\]
- Rationale and precedent: none stated in the sources
- Evidence: COPYING 'BSD 2-Clause License, Copyright (c) 2026, David Walther'; README.md:89; errata 48

### Links and navigation between docs
- Status: DONE — docs interlink with back links; README lists the pages (latest decision 2026-10-22 \[1889:j73028#1\])
- Decided: 2026-10-22 decided: "make the pages all interlink nicely"; "only the main readme needs to list the other pages, that is enough, backbutton works" \[1889:j73028#1\]
- Rationale: "make the pages all interlink nicely for pleasant navigation" \[1889:j73028\]
- Rationale: "only the main readme needs to list the other pages, that is enough, backbutton works" \[1889:j73028\]
- Rationale: Original documents stay as they are, but readme links go "to the updated versions of those docs (in a different directory)". \[1889:1974\]
- Precedent: manpage-style SEE ALSO section (chosen; named by author): wants "a manpage style section at the bottom" listing repos and docs \[1889:1969\]
- Evidence: every doc starts with '\[← pdp64 index\](../README.md)'; README.md section 'What to read' lists the documents; docs/manual/00-index.md

### Man pages for 32V
- Status: DONE — the 32V assembler page lives in the v7unix man section (latest decision 2026-10-18 \[1889:j41635#1\])
- Decided: 2026-10-18 decided: "32v is just v7 ported to vax, so 32v man pages can live in the v7unix section" \[1889:j41635#1\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:man/Makefile.am:19 "as32v.1" and :31 \`.so v7unix/man1/as32v.1\`; man/as32v.1 ".TH AS32V 1  VAX"; the toolchain has no other 32V-only page (adb, as, cc, ld, lex, make, yacc are shared)

### Manual PDF and build
- Status: DONE — buildabook builds the PDF, tracked and linked (latest decision 2026-11-05 \[1882:j3581#1\])
- Decided: 2026-11-05 decided: Names the tool to use: "moebiusV/buildabook" \[1882:j3581#1\]
- Rationale: "why wouldn't the agent rebuild the pdf? I never made that rule" \[1882:290\]
- Precedent: buildabook (chosen; named by author): "use buildabook for the manual" \[1882:j3566\]
- Evidence: book/README.md 'Needs buildabook'; tools/mkbook.sh; book/pdp64-32.pdf tracked (commit c48e8c0); handoff.md commit 149d91e 'the PDF is built with buildabook by the working session'
- Doc differs: book/ builds three PDFs (r20, 16, 32), not one; single pdp64/32 book is all that is now wanted

### Manual: deliverable and chapter order
- Status: DONE — chapters follow the final order with atomics in smp and system material in kernel (latest decision 2026-10-23 \[1889:j80033#1\])
- Decided: 2026-10-23 decided: "atomics belongs in the smp chapter"; "system instructions, faults and memory management belong in the kernel chapter" \[1889:j80033#1\]
- Rationale: "let's make it very easy and pleasant for him" (the cpu designer reader) \[1889:2668\]
- Precedent: PDP-10, PDP-11 and VAX-11 (chosen; named by author): manual to cover what was so great about programming them \[1889:2668\]
- Evidence: docs/manual-src/00-index.md contents: 02 bus, 03 graphics, 04 boot, 05 drivers, 06 kernel, 07 smp, 08 vectors, 09 isa, 10 conclusion; appendices A (improvements) and B (decisions pending)
- Doc differs: order bus, graphics, boot, drivers (index) differs from the 'boot, device driver, graphics' of 1889:j79425#1 and 'bus, blitter, boot' of 1889:j79473#1; the later j79473 is the one followed

### Optimization tricks document and optimization docs
- Status: DONE — tricks doc is comprehensive and pdp64 optimization doc is current (latest decision 2026-10-18 \[1889:j29953#1\])
- Decided: 2026-10-18 decided: "of course update the docs coprehensively" \[1889:j29953#1\]
- Rationale: "for all the dmr and vax "tricks" make a comprehensive md file documenting them, how thet worked, and how they can be brought over to x86 and other backends" \[1889:434\]
- Rationale: "a win is a win, take it." \[1889:434\]
- Rationale: "the docs should give enough info to implement the other arches later on." \[1889:j17625\]
- Rationale: "as long as we document which optims we tried and dropped, and why." \[1889:j24755\]
- Precedent: dmr cc (chosen; named by author): document them and bring them to x86 and other backends \[1889:434\]
- Precedent: VAX pcc / 32V (considered; named by author): "about as good as dmr was on pdp11" \[1889:434\]
- Precedent: x86, then VAX (chosen; named by author): "do the x86 ones first, then vax" \[1889:434\]
- Precedent: pdp11/vax/x86 backends only (chosen; named by author): other backends left alone for now \[1889:j17625\]
- Evidence: v7unix-toolchain:OPTIMIZATION-TRICKS.md (37+ numbered tricks, status section); pcc-enc:doc/PDP64-OPT.md ('Left out, and why' at line 216)

### PCC README
- Status: DONE — README states what differs from the main version (latest decision 2026-10-18 \[1889:j43784#1\])
- Decided: 2026-10-18 decided: "then update and push all docs right?" \[1889:j43784#1\]
- Rationale: "express what differs from the main version; our dce work, dmr optimizations, bug fixes, updates to vax and pdp11 etc" \[1889:j40548\]
- Precedent: pcc (considered; named by author): README says what differs from it \[1889:j40548\]
- Evidence: pcc-enc:README.md:110 '## How This Differs From The Historic PCC'; -xdmr, -xdce described at lines 11-15

### Pain-points research
- Status: DONE — rounds 1 to 7 are in the pain-points document (latest decision 2026-10-23 \[1889:2985#1\])
- Decided: 2026-10-23 decided: "as long as you verify what you write, you don't have to invent more stuff"; if an area is already fine "don't go hunting anymore"; just ensure all essentials are in the document. \[1889:2985#1\]
- Rationale: "as long as you verify what you write, you don't have to invent more stuff"; if an area is fine "don't go hunting anymore". \[1889:2985\]
- Rationale: "didn't need full history, just the current vesion of the linux and bsd kernels" \[1889:2519\]
- Rationale: "love to include the list of what openbsd (and linux security) people have asked hardware vendors for" \[1889:2612\]
- Rationale: Blit: "lots of material online about the blit"; wants round 6 to find a way to read the manual. \[1889:2956\]
- Precedent: OpenBSD (chosen; named by author): list of what its people asked hardware vendors for \[1889:2612\]
- Precedent: Linux security (chosen; named by author): same list from its people \[1889:2612\]
- Precedent: Linux and BSD current kernel source (chosen; named by author): current version only, not full history \[1889:2519\]
- Precedent: mailing lists (chosen; named by author): expected pain points from mailing lists, not only source \[1889:2526\]
- Precedent: Blit (considered; named by author): wants its manual read; round 6 \[1889:2956\]
- Evidence: docs/kernel-pain-points.md sections 14B to 14M (round 5 bus design and GPU at 14F, round 6 Blit/Research Unix/Plan 9 at 14I, round 7 at 14L-14M)

### Project name
- Status: DONE — named pdp64 in docs, errata 12 (latest decision 2026-10-21 \[1889:j69082#1\])
- Decided: 2026-10-21 decided: "the name isn't 11/64W it is pdp64" \[1889:j69082#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:38 '12. The machine\\'s name is pdp64'; README.md title 'DEC PDP-64'

### Repository and docs layout
- Status: DONE — docs/ flat, originals in docs/orig, toolchain in repo (latest decision 2026-10-22 \[1889:j72870#1\])
- Decided: 2026-10-22 decided: "we're already in pdp64/ so docs/pdp64/ doesn't make sense, fix it. you may put old versions of documents in docs/orig or docs/old or docs/Attic" \[1889:j72870#1\]
- Rationale: "we're already in pdp64/ so docs/pdp64/ doesn't make sense" \[1889:j72870\]
- Rationale: "you should have left toolchain alone; the as64 and ld64 should live in pdp64/ repo" \[1889:1944\]
- Evidence: docs/orig/ holds 11-64W-\*.md; as64/, ld64/, sim64/ at repo root; no docs/pdp64/ directory

### Spec revisions and write-up
- Status: DONE — the spec exists and is current in grammars and ISA text (latest decision 2026-10-21 \[1889:1706#4\])
- Decided: 2026-10-21 decided: "start with the spec" \[1889:1706#4\]
- Rationale: "could even use hbnf to help with the opcode layout. good test case for it." \[1889:1706\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed." \[1889:1706\]
- Rationale: "only 2 byte memory alignment; don't put 8 byte memory alignment constraints that would be horrible" \[533:14\]
- Rationale: "since the soc will have hdmi, pal/ntsc isn't too relevant except for backwards compat." \[531:24\]
- Precedent: ELF64 output (widen ld.c) (chosen; named by assistant, accepted): said "yes to all" to the assistant's proposal \[1889:1706\]
- Precedent: V7 a.out 64-bit variant (considered; named by assistant, not taken up): offered as the smaller change \[1889:1706\]
- Precedent: 8502/6502 compatibility in FPGA (considered; named by author): all registers readable by holding the rdy pin \[531:24\]
- Precedent: PDP-11 (considered; named by author): asked how it handled them before the write-up \[533:4\]
- Precedent: AArch64 (considered; named by assistant, not taken up): holds both rules at once; cited for partial writes \[533:14\]
- Evidence: spec/pdp64-32/pdp64-32.hbnf; docs/pdp64-isa.md; docs/errata.md (rev 6/r10 offers superseded by the prefix-coded grammars, commit a71f491 Merge enc-int)

### System doc
- Status: DONE — system doc exists with the caveat, linked from README (latest decision 2026-10-22 \[1889:2215#2\])
- Decided: 2026-10-22 decided: Add the caveat to the system doc: a simple memory model does not make an atomic implementation simple by itself; coherence, ordering, interrupts still need design. \[1889:2215#2\]
- Rationale: Wants "what the main options were compared to the major operating systems and architectures" and how choices fit minimal design and fewer fetches. \[1889:2207\]
- Rationale: Wants to "see what we can learn from the other arches, compiled to assembler on the fair corpus". \[1889:2207\]
- Rationale: "i don't remember ever ruling \[out of order\] out"; asks the cost of refusing it and the gain in "reduced error handling, reduced opcodes/silicon". \[1889:2215\]
- Rationale: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[1889:2236\]
- Precedent: out-of-order design (considered; named by author): asks what supporting it needs and what refusing it costs \[1889:2215\]
- Precedent: major operating systems and architectures (considered; named by author): options compared with them \[1889:2207\]
- Precedent: gcc cross-compilers on other arches (considered; named by author): asks what cross-compile infrastructure exists \[1889:2207\]
- Evidence: docs/pdp64-system-architecture.md:153 'Caveat: a simple memory model does not make an atomic implementation simple by itself'; README.md 'What to read' item 2

### Undefined items
- Status: DONE — stubs and (S) tags mark what is undefined (latest decision 2026-10-22 \[1889:2073#2\])
- Decided: 2026-10-22 decided: "whatever is undefined, say in the docs so we can design it later" \[1889:2073#2\]
- Rationale: "whatever is undefined, say in the docs so we can design it later" \[1889:2073\]
- Precedent: LLVM (considered; named by author): asks how hard one would be \[1889:2073\]
- Precedent: Linux port (GCC or LLVM back end) (considered; named by assistant, not taken up): a BSD or V7-style Unix is closer to the toolchain \[1889:2073\]
- Evidence: docs/manual-src/00-index.md 'Each aphorism carries a status ... (S) means a stub'; appendix-b-decisions-pending.md

### Velinsky link
- Status: DONE — recorded in manual 1.1 commentary and c64 doc section 8 (latest decision 2026-11-08 \[1882:375#1\])
- Decided: 2026-11-08 approved-proposal: "add it": record his prediction and hypothesis (P) in manual 1.1 commentary and section 8, sourced claim separated from his observation. \[1882:375#1\]
- Rationale and precedent: none stated in the sources
- Evidence: commit c3eceb6 'Velinsky link recorded as prediction, confirmation and the author's hypothesis (P)'; docs/c64-devices-from-chat.md:150 'Confirmation. Ira Velinsky ...' and table row 7; docs/manual-src/01-introduction.md:17

## FPGA and silicon

### FPGA target and clock
- Status: DONE — an SoC FPGA plan exists; its clock estimates are lower than the stated 200-300 MHz (latest decision 2026-08-30 \[533:22#1\])
- Decided: 2026-08-29 decided: "200-300MHz is fine" \[531:4#2\]
- Rationale: "modern fpga so insane high clock specs" \[531:0\]
- Rationale: "300Mhz for a 1Mhz chip is insane. in a good way." \[531:4\]
- Rationale: "we go full little endian, none of this middle endian stuff" \[531:4\]
- Precedent: PDP-11 (chosen; named by author): used as the base of the mashup \[531:0\]
- Precedent: SID (chosen; named by author): fold in the good parts of c64 \[531:0\]
- Precedent: m8502 (chosen; named by author): mash it up with the PDP-11 instead of the c64, they seem closer \[531:4\]
- Precedent: PDP-11 (rejected; named by author): go full little endian, fixed right now \[531:4\]
- Precedent: IEEE 754 floating point (chosen; named by author): new FP unit compatible with modern ieee representation \[531:4\]
- Precedent: Blit (considered; named by author): revamp it to be c64 adjacent \[531:0\]
- Evidence: docs/pdp64-fpga-plan.md:1 "SoC FPGA Implementation Plan"; :13 "The pdp64 assumes a SoC FPGA"
- Doc differs: docs/pdp64-fpga-plan.md:97-99 estimates 50-80 MHz (Cyclone V), 90-130 MHz (Zynq 7020), 180-250 MHz (UltraScale+), and :110 "Do not chase frequency in phase 1"

### In-order cores, ready for out-of-order
- Status: DONE — stated in the ISA constraints, errata 38 and the readiness documents (latest decision 2026-10-22 \[1889:2236#3\])
- Decided: 2026-10-22 decided: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[1889:2236#3\]
- Rationale: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[1889:2236\]
- Evidence: docs/pdp64-isa.md:27 "Ready for out-of-order execution from the start"; docs/errata.md item 38; docs/pdp64-ooo-readiness.md; docs/pdp64-in-order-and-out-of-order.md

## Instruction set: addressing modes

### Wide immediates
- Status: DONE — literal pool written with an explicit =, nothing pooled silently (latest decision 2026-10-22 \[1889:j74351#1\])
- Decided: 2026-10-22 decided: "i am ok with some syntactic sugar to make compiler pools look like a single instruction, but the sugar should be done in a way it is immediately obvious that is what it is." \[1889:j74351#1\]
- Rationale: "i am ok with some syntactic sugar to make compiler pools look like a single instruction, but the sugar should be done in a way it is immediately obvious that is what it is" \[1889:j74351\]
- Evidence: docs/asm-syntax.md:32 "Literal pool: =expr" and :34 "a bare #K that does not fit ... is an error"; docs/errata.md item 33

## Instruction set: alignment and memory model

### Address space (VAX I/O space)
- Status: DONE — the VAX I/O space is noted in the manual (latest decision 2026-10-23 \[1889:j79495#1\])
- Decided: 2026-10-23 decided: "it should be noted in the book how the vax does this io space idea"; he had not known of it \[1889:j79495#1\]
- Precedent: VAX I/O space (considered; named by assistant, accepted): memory low, I/O above; to be noted in the book \[1889:j79495\]
- Evidence: docs/manual-src/02-bus.md:25 "The VAX-11/780 divided its physical address space in two: memory in the low half and the I/O space above 0x20000000"

### Data alignment
- Status: DONE — natural alignment with byte access and wide transfers (latest decision 2026-11-04 \[1882:60#2\])
- Decided: 2026-11-04 decided: "as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits (or more) at a time". \[1882:60#2\]
- Rationale: "as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits (or more) at a time" \[1882:60\]
- Rationale: "don't put 8 byte memory alignment constraints that would be horrible" \[533:14\]
- Evidence: docs/errata.md item 82; docs/pdp64-isa.md:56 "Natural alignment for quad accesses (§7.4)"; docs/abi.md:10 "natural"; instructions stay 2-byte aligned (docs/pdp64-isa.md:206)

### Endianness
- Status: DONE — little-endian for data and instructions (latest decision 2026-08-29 \[531:4#3\])
- Decided: 2026-08-29 decided: "we go full little endian, none of this middle endian stuff, that gets fixed right now" \[531:4#3\]
- Rationale: "6502 was 8bit so word order didn't matter; we go full little endian, none of this middle endian stuff" \[531:4\]
- Precedent: middle-endian longword order (rejected; named by author): "none of this middle endian stuff, that gets fixed right now" \[531:4\]
- Precedent: 6502 (considered; named by author): 8-bit, so word order did not matter there \[531:4\]
- Evidence: docs/pdp64-isa.md:208 "Byte order is little-endian, for data and for instructions"

### Instruction alignment after odd data in .text
- Status: DONE — as64 errors on an instruction at an odd address (latest decision 2026-10-22 \[1889:j71596#1\])
- Decided: 2026-10-22 approved-proposal: Instruction after odd data bytes in .text, what as64 should do="Error (Recommended)" \[1889:j71596#1\]
- Rationale and precedent: none stated in the sources
- Evidence: as64/as64.c:1148 "an instruction at an odd address (%lld): put .even before it"

### Tagged pointers
- Status: DONE — low pointer bits reserved to software, alignment abort as the tag check (latest decision 2026-08-30 \[533:20#1\])
- Decided: 2026-08-30 approved-proposal: "fold it" (reserve low pointer bits to software, alignment abort as tag-mismatch signal, into r11) \[533:20#1\]
- Rationale: "since we address at 2 byte boundaries, we can use the bottom bit as a tag for tagged pointers" \[533:18\]
- Rationale: accepted from the assistant: the alignment abort is the tag check, which section 7.4 already gives "approximately for free" \[533:20\]
- Precedent: Lisp machine (chosen; named by author): tagged pointers; hardware tag checking on dereference not added \[533:18\]
- Evidence: docs/pdp64-isa.md:1129 "6.2 Low pointer bits are reserved to software"; :1149 "The alignment abort is the tag check"
- Doc differs: docs/pdp64-isa.md:1137 says the three bits come from data alignment, not instruction alignment (the "bottom bit" idea was replaced)

## Instruction set: encoding

### Backward compatibility
- Status: DONE — no binary compatibility; PDP-11 mnemonic flavour kept as a priority (latest decision 2026-08-30 \[533:2#2\])
- Decided: 2026-08-30 decided: "no need to be backward compatible"; "assembler mnemonics be nice if those were backward compatible" \[533:2#2\]
- Rationale: wants to keep "some of its nice properties" and keep "transistor count down while still being reasonably nice to program in assembler"; "assembler mnemonics be nice if those were backward compatible" \[533:2\]
- Precedent: PDP-11 (chosen; named by author): upgrade it to 32/64 bit keeping nice properties; mnemonics compatible, binary not \[533:2\]
- Precedent: m8502 (chosen; named by author): adopt what is needed from it to keep transistor count down \[533:2\]
- Precedent: x86 (chosen; named by author): adopt what is needed from it to keep transistor count down \[533:2\]
- Precedent: Strecker VAX-11/780 paper (considered; named by assistant, not taken up): DEC considered extending PDP-11; opcode-space exhaustion was the reason \[533:2\]
- Evidence: docs/pdp64-isa.md:19 "A PDP-11 programmer should recognize the language" (priority 6); the encoding is not PDP-11 (docs/pdp64-isa.md:145 parcels of 16 bits, new opcodes); docs/pdp64-isa.md:437 SOB restored with the PDP-11 name

### ISA revision r12
- Status: DONE — rolled and passed long ago; the current text is revision 20 with the len invariant stated (latest decision 2026-10-20 \[533:26#1\])
- Decided: 2026-10-20 approved-proposal: "yes, roll r12" (wording fixed, len invariant restated) \[533:26#1\]
- Rationale: accepted from the assistant: "length is len + 1" is unprovable-because-trivial; the property to prove is that no escape sub-opcode needs more parcels than len declares \[533:26\]
- Evidence: docs/pdp64-isa.md:158-160 len field as the number of extension parcels (the invariant); docs/errata.md:1 "Errata and decisions against ISA r20"

### Instruction length (parcels)
- Status: DONE — maximum is three parcels, stated and implemented (latest decision 2026-10-22 \[1889:2092#1\])
- Decided: 2026-10-22 approved-proposal: "yes, write it up as an open design item" (3-parcel maximum length). \[1889:2092#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:145 "Instructions are 1 to 3 16-bit parcels"; docs/errata.md item 31 (fourth parcel removed); docs/pdp64-isa.md:187 six-byte longest

### One-parcel forms
- Status: DONE — page 2 (len=11) of one-parcel abbreviations is in the ISA (latest decision 2026-10-22 \[1889:2109#1\])
- Decided: 2026-10-22 decided: Go ahead and "update the isa with all those new 1 parcel forms". \[1889:2109#1\]
- Rationale: accepted from the assistant: the (rN) and sp-offset candidates are together "about 3% of code", worth folding into the open one-parcel item \[1889:2102\]
- Precedent: gcc -Os x86-64 / clang -Os (considered; named by assistant, not taken up): pdp64 averages 3.36 bytes per instruction against 3.66 and 3.78 \[1889:2102\]
- Evidence: docs/pdp64-isa.md:202 "its own 64-entry opcode map (45 defined), given in §4.18"; docs/errata.md item 31; docs/errata.md item 37 page-2 pushx/popx

### Opcode map grouping
- Status: DONE — rare opcodes sit in wide groups with sub-opcodes, thematic runs (latest decision 2026-10-21 \[533:120#1\])
- Decided: 2026-10-21 decided: "regroup the opcodes, rare ones are bigger ones", and "keep them grouped by theme" \[533:120#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:406 "Everything else is a contiguous run of one kind"; docs/encoding-proposal.md:30 "Rare instructions share a few wide groups with a sub-opcode field"

### Trailing literals
- Status: DONE — the allocation model was rerun with trailing literals and the result recorded; not adopted (latest decision 2026-11-04 \[1882:166#1\])
- Decided: 2026-11-04 approved-proposal: "yes, and do the compilation too": rerun the allocation model with trailing literals. \[1882:166#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/layout-size-variants.md:1 "The 32-register layout with trailing literals: sizes"; docs/encoding-proposal.md:225 "trailing literals (earlier fragments: worse than inline immediates plus dedicated forms...)"

### Word size
- Status: DONE — words are 16 bits, longs 32, quads 64 (latest decision 2026-08-30 \[533:8#2\])
- Decided: 2026-08-30 decided: "we can keep 16 bit word size"; "16bit is enough and utf8 showed the way encoding can be done" \[533:8#2\]
- Rationale: "16bit is enough and utf8 showed the way encoding can be done" \[533:8\]
- Precedent: UTF-8 (chosen; named by author): showed how the length-first encoding can be done \[533:8\]
- Precedent: ARM32 LDRD / MIPS32 FP pairs (considered; named by assistant, not taken up): register-pair cost of 32-bit FP, in the case against a 32-bit version \[533:8\]
- Evidence: docs/pdp64-isa.md:9 "Words are 16 bits. Longs are 32. Quads are 64."; docs/pdp64-isa.md:147 UTF-8 as the model for the length-first encoding

## Instruction set: fused pairs and compiler idioms

### Compare-and-branch
- Status: DONE — register-register and wide cbCC exist (latest decision 2026-10-22 \[1889:2181#1\])
- Decided: 2026-10-22 decided: "do the register-register compare-and-branch". \[1889:2181#1\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md items 34 and 35; docs/pdp64-isa.md:445 "4.4.1 CBCC"; spec/pdp64-32/pdp64-32.hbnf leaves CBR8, CBDR, CB3R24H, CB3I16

### Comparison with other architectures
- Status: DONE — the fair corpus was compared across architectures (latest decision 2026-10-22 \[1889:2258#1\])
- Decided: 2026-10-22 decided: Compile the fair corpus "with each clang backend that we have" to find instructions to adopt or sequences to coalesce. \[1889:2258#1\]
- Rationale: "so we can check and see if there are any instructions we should adopt, or sequences we shoudl coallesce" \[1889:2258\]
- Rationale: wants to see what we can learn from other arches on the fair corpus "to reduce instsruction count" \[1889:2207\]
- Precedent: each clang backend that we have (chosen; named by author): compile the fair corpus with each to find instructions to adopt \[1889:2258\]
- Precedent: Linux and BSD kernel assembly (chosen; named by author): review for instructions like popx/pushx that compilers never emit \[1889:2258\]
- Precedent: major operating systems and architectures (considered; named by author): asked how the options compared against them \[1889:2207\]
- Evidence: tools/archcmp.py, tools/archcmp-gccx.sh; docs/codegen-data/archcmp/archcmp-classes.csv; docs/CHANGES-SINCE-R20.md:418 "841-file fair corpus"

### Fused pairs
- Status: DONE — the assembler never fuses; the compiler emits movcall, popret, popmret, mov2 (latest decision 2026-11-04 \[1882:199#1\])
- Decided: 2026-11-04 decided: "leave fusing to the compiler". \[1882:199#1\]
- Rationale: "then we will see how well the optimizer does" \[1882:187\]
- Rationale: accepted from the assistant: the assembler cannot see liveness, the compiler can, so the compiler finds at least as many pairs \[1882:199\]
- Evidence: spec/pdp64-32/pdp64-32.hbnf "fused = movcall \| popmret \| popret \| mov2" with the comment "the assembler never fuses ... chosen by the compiler"

### rori32 sign extension
- Status: DONE — rori32 sign-extends (latest decision 2026-10-22 \[1889:2167#1\])
- Decided: 2026-10-22 decided: "make rori32 sign-extend like the rest". \[1889:2167#1\]
- Rationale: "make rori32 sign-extend like the rest" \[1889:2167\]
- Rationale: accepted from the assistant: it zero-extends "while the compiler keeps unsigned values sign-extended" \[1889:2167\]
- Evidence: docs/pdp64-isa.md:543 "rd \<- sign-extend(ror32(rs\[31:0\], n mod 32))"; docs/errata.md item 34

## Instruction set: instruction groups

### 16-bit and narrow integers
- Status: DONE — arithmetic is 64-bit only, with proper zero and sign extension (latest decision 2026-10-22 \[1889:j73130#1\])
- Decided: 2026-10-22 decided: "just make sure zero extend and sign extend happen properly" \[1889:j73130#1\]
- Rationale: "if things are 0 extended, then i can see how your arithmetic is 64bit only. and that is fine" \[1889:j73112\]
- Evidence: docs/errata.md item 28 "integer arithmetic stays 64-bit; there are no sized ALU operations"; docs/pdp64-isa.md:543 RORI32 sign-extends

### FP exception flags
- Status: DONE — sticky five-bit FPSR with FSFLAGS (latest decision 2026-10-21 \[1889:j71247#1\])
- Decided: 2026-10-21 approved-proposal: "yes, fix the missing exception flags, we have to be able to implement ieee floating point" \[1889:j71247#1\]
- Rationale: "we have to be able to implement ieee floating point" \[1889:j71247\]
- Precedent: IEEE 754 floating point (chosen; named by author): needs the five exception flags \[1889:j71247\]
- Evidence: docs/pdp64-isa.md:768 "a sticky five-bit re..."; docs/errata.md item 17 "FSFLAGS rs, rd (FESC sub-opcode 0x40)"

### FP reciprocal estimates
- Status: DONE — frecped and frsqrted removed (latest decision 2026-10-21 \[1889:1807#1\])
- Decided: 2026-10-21 approved-proposal: "yes, drop them": the two FP reciprocal-estimate words (frecped, frsqrted) removed from the spec. \[1889:1807#1\]
- Rationale: accepted from the assistant: no named customer, and two implementations would give different bits; "yes, drop them" \[1889:1807\]
- Evidence: docs/pdp64-isa.md:764 "There are no reciprocal or reciprocal-square-root estimate instructions"; docs/errata.md item 16

### FP rounding variants
- Status: DONE — frint family kept (latest decision 2026-10-21 \[1889:1847#2\])
- Decided: 2026-10-21 decided: "i like having the rounding variants" (keep the FP rounding variants). \[1889:1847#2\]
- Rationale: "i like having the rounding variants" \[1889:1847\]
- Precedent: C round() / libm (chosen; named by assistant, accepted): ties-away-from-zero rounding added as a qualifier \[1889:1847\]
- Evidence: docs/errata.md item 24 lists "frint (nearest even), frintz, frintm, frintp, frinta"; docs/pdp64-isa.md:746 FRINT

### FP16 support
- Status: DONE — seventeen binary16 words in FESC (latest decision 2026-10-22 \[1889:1981#1\])
- Decided: 2026-10-22 decided: "add fp16 conversions and arithmetic". \[1889:1981#1\]
- Rationale: "would be a shame if a descendant of the pdp-11 didn't have native 16 bit support" \[1889:j72933\]
- Evidence: docs/pdp64-isa.md:761 "binary16 (half precision): seventeen FESC words in the block 0x50-0x65: FADD16 ..."
- Doc differs: docs/errata.md item 24 says "\`fadd16\` binary16 when half-precision arrives" (stale wording)

### Floating-point format
- Status: DONE — IEEE 754 binary32/64/16 with flags and canonical NaN (latest decision 2026-08-29 \[531:4#1\])
- Decided: 2026-08-29 decided: "assume a new refreshed redesigned fp unit, probably compatible with modern ieee floating point representation" \[531:4#1\]
- Rationale: "assume a new refreshed redesigned fp unit, probably compatible with modern ieee floating point representation" \[531:4\]
- Precedent: IEEE 754 floating point (chosen; named by author): new FP unit compatible with the modern representation \[531:4\]
- Precedent: PDP-11 (rejected; named by author): cited as "done horribly" \[531:4\]
- Evidence: docs/pdp64-isa.md:768 "IEEE 754 requires five status flags ... The machine has a sticky five-bit"; :782 canonical quiet NaN for binary64/32/16

### PUSHX and POPX
- Status: DONE — instructions added and the null-system-call measurement exists (latest decision 2026-10-22 \[1889:2236#1\])
- Decided: 2026-10-22 approved-proposal: "yes, add the measurement" of null system call with and without pushx/popx. \[1889:2236#1\]
- Rationale: accepted from the assistant: nested entry and exit is "roughly 11 fewer instructions and 28 fewer bytes", so fewer instruction fetches \[1889:2236\]
- Rationale: wants "to be ready for the out of order large scale design" \[1889:2236\]
- Precedent: ARM32 SRS/RFE (considered; named by assistant, not taken up): same idea; assistant said from memory, unchecked \[1889:2236\]
- Evidence: docs/pdp64-isa.md:811 "PUSHX and POPX save and restore the exception state"; tests/sim/sys-roundtrip.S:1 "a null system call round trip, two ways"; docs/errata.md item 37

### Rotates and ASL flags
- Status: DONE — rotates write no flags, ASL V = N xor C (latest decision 2026-10-22 \[1889:2315#1\])
- Decided: 2026-10-22 approved-proposal: "go with your recommendation on rotates and ASL": rotates flag-free, ASL keeps V = N xor C, ISA text corrected. \[1889:2315#1\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones. you made a good case for ror over rol" \[533:93\]
- Precedent: PDP-11 (considered; named by author): not kept slavishly; ror over rol, assembler may map rol to ror \[533:93\]
- Evidence: docs/pdp64-isa.md:356 "ASL ... N xor C (the PDP-11 rule: set if the sign changed)"; :358 ROR, RORI, RORI32 "(no flags are written)"; docs/errata.md item 10

### Set on condition
- Status: DONE — SET cc, Rd with the condition as an operand (latest decision 2026-10-21 \[1889:1867#1\])
- Decided: 2026-10-21 changed: "set eq intead of seteq": condition as an operand, not a suffix mnemonic. \[1889:1867#1\]
- Precedent: PDP-11 (rejected; named by assistant, not taken up): assistant proposed suffix spelling; he wanted the condition as an operand \[1889:1867\]
- Precedent: ARM csel family (considered; named by assistant, not taken up): extra variants almost free once the first exists \[1889:1865\]
- Evidence: docs/pdp64-isa.md:858 "SET cc, Rd"; :862 "SET EQ, R1"; docs/errata.md item 25

## Instruction set: registers

### Register width
- Status: DONE — registers are 64 bits, no 32-bit version (latest decision 2026-08-30 \[533:8#1\])
- Decided: 2026-08-30 changed: "skip 32 bit version and go straight to 64bit. no need to horn 32 bit support in there" \[533:8#1\]
- Rationale: "no need to horn 32 bit support in there" \[533:8\]
- Precedent: x86 ah/al (considered; named by author): asked for 64-bit registers addressable as two 32-bit halves, sort of like ah/al \[533:6\]
- Precedent: ARM32 LDRD / MIPS32 FP pairs (considered; named by assistant, not taken up): pair-register cost of a 32-bit FP version \[533:8\]
- Evidence: docs/pdp64-isa.md:80 "64 bits each"; docs/pdp64-isa.md:9 quads are 64 bits; no 32-bit mode in spec/pdp64-32/pdp64-32.hbnf

### SP and FP registers
- Status: DONE — sp and fp are aliases of r14 and r13 in the grammar and docs (latest decision 2026-10-21 \[1889:1818#2\])
- Decided: 2026-10-21 decided: sp and fp should already be aliases in the grammar: "you don't need a third header for that". \[1889:1818#2\]
- Rationale: "make sp r14 and fp r13 to match the vax" \[533:61\]
- Rationale: sp and fp as aliases: "you don't need a third header for that" \[1889:1818\]
- Precedent: VAX-11 (chosen; named by author): SP is R14 and FP is R13 to match it \[533:61\]
- Evidence: docs/pdp64-isa.md:89 "SP is R14 and FP is R13, matching VAX"; spec/pdp64-32/pdp64-32.hbnf hot3/hot4 name "sp"

## toolchain

### Assembler syntax and names
- Status: DONE — numbers, labels, UTF-8 and ELF names as decided (latest decision 2026-10-21 \[1889:1765#1\])
- Decided: 2026-10-21 decided: "the bareword with : terminal fully qualifies it" (digit-leading name followed by a colon is a label). \[1889:1765#1\] (changes 2026-10-21 'Asks whether some labels start with digits')
- Rationale: "don't be TOO strict; we don't need to copy asv7 warts or anachronisms" \[1889:1745\]
- Rationale: "numbers default to decimal, the 0x 0b 0o notation is for when we want it" \[1889:j69889\]
- Rationale: "names/labels just have to follow ELF syntax. and make it utf8 clean" \[1889:1757\]
- Rationale: "/ is div, not a comment. \<\> is not a string, numbers and strings are in C syntax" \[1889:1753\]
- Precedent: asv7 (V7 as) (rejected; named by author): not to copy its warts or anachronisms \[1889:1745\]
- Precedent: V7 octal-default numbers (rejected; named by author): numbers default to decimal \[1889:j69889\]
- Precedent: modern ELF symbol names (chosen; named by author): names and labels follow it \[1889:1757\]
- Precedent: C syntax for numbers and strings (chosen; named by author): instead of V7 \<...\> strings and comment slash \[1889:1753\]
- Evidence: docs/asm-syntax.md:19 "decimal by default (010 is ten), 0x, 0b or 0o"; :16 "UTF-8"; :15 "a bareword of digits only is a numeric local label"
- Doc differs: asm-syntax.md:15 says a bareword of digits only is a local label; the Now line says digit-leading name with a colon

### Benchmark freeze and fixes against stock
- Status: DONE — the stock comparison was re-measured after the fixes (latest decision 2026-10-18 \[1889:j44538#1\])
- Decided: 2026-10-18 decided: "fix the 1 2 3 places where ours is worse than stock!"; inline "is a hint, not a command" \[1889:j44538#1\] (changes 2026-10-18 'no new fixes until we are done our benchmarking')
- Rationale: "these tests are just to a) compare apples to apples and b) show what compiles and what doesn't" \[1889:j43156\]
- Rationale: "fix the 1 2 3 places where ours is worse than stock! they sound easy enough" \[1889:j44538\]
- Rationale: "in modern c, inline is a hint, not a command" \[1889:j44538\]
- Precedent: pcc (chosen; named by author): comparison baseline; fix places where ours is worse \[1889:j44538\]
- Precedent: modern C inline semantics (considered; named by author): inline is a hint, not a command \[1889:j44538\]
- Evidence: commits b118ccc "re-measured after merging upstream; the fork now contains the stock it is compared with", 285188d "fair-set numbers on aarch64, amd64, i386, pdp11 and vax"

### Benchmark report and corpus
- Status: DONE — report generator is incremental and compares stock, ours, gcc, clang (latest decision 2026-10-19 \[1889:j45238#1\])
- Decided: 2026-10-19 decided: "no need to do redundant work" \[1889:j45238#1\]
- Rationale: "no need to do redundant work" \[1889:j45238\]
- Rationale: pdp11 and vax on the same corpus: "that way it is apples to apples" \[1889:j40931\]
- Rationale: stock pcc built "so we can see how much difference our dmr changes made for all platforms" \[1889:j40301\]
- Precedent: Lua and SQLite (chosen; named by author): fetch them as test corpora, use for each arch \[1889:1124\]
- Precedent: pcc (chosen; named by author): baseline to measure the dmr changes against \[1889:j40301\]
- Precedent: clang (considered; named by author): asked which backends pcc and clang share; test all \[1889:1135\]
- Evidence: toolchain commit 0b8c513 "corpus tools: incremental results"; tools/corpus-report.py; doc/SIZE-REPORT.md

### Dead-code elimination (dce)
- Status: DONE — dmr finished, then dce stages done (latest decision 2026-10-17 \[1889:j17657#1\])
- Decided: 2026-10-17 changed: "we should finish dmr before dce; dmr is done when the only files larger are because of more correct code" \[1889:j17657#1\] (changes 2026-10-17 'actually your dce plan looked pretty solid')
- Rationale: "dmr is done when the only files larger are because of more correct code" \[1889:j17657\]
- Precedent: dmr cc (chosen; named by author): finish matching it before dce work \[1889:j17657\]
- Evidence: pcc:README.md "-xdce (mip/regs.c, cc/ccom): dead assignments and unreachable blocks are removed on the flow graph"
- Left: Left (potential): const substitution for #ifdef is not recorded as done

### Dual-encoding toolchain, mnemonics and integration
- Status: DONE — integrated branch merged into main (latest decision 2026-11-04 \[1882:273#1\])
- Decided: 2026-11-04 decided: "i meant merge also": merge the integrated branch into main. \[1882:273#1\]
- Rationale: approved fused pairs for 16 and 32 reg versions: "then we will see how well the optimizer does" \[1882:187\]
- Rationale: sj optimizations "should have been folded into -xdmr flag, they are the vax optimizations from steve johnson pcc" \[1882:j2662\]
- Precedent: Steve Johnson pcc VAX optimizations (chosen; named by author): fold into the -xdmr flag \[1882:j2662\]
- Evidence: commit a71f491 "Merge enc-int: the pdp64/16 and pdp64/32 encodings"; errata 87, 88, 90

### Fair corpus and compiler comparison
- Status: DONE — sjpcc and dmr cc are in the fair comparison (latest decision 2026-10-19 \[1889:j57024#1\])
- Decided: 2026-10-19 decided: "on vax and pdp11 we should also be including sjpcc and dmrcc in the evaluation/comparison" \[1889:j57024#1\]
- Rationale: "the 'fair' corpus should also eliminate the things that gcc and stock can't compile at all" \[1889:j55479\]
- Precedent: sjpcc (chosen; named by author): include in the evaluation on vax and pdp11 \[1889:j57024\]
- Precedent: dmr cc (chosen; named by author): include in the evaluation on vax and pdp11 \[1889:j57024\]
- Precedent: gcc (chosen; named by author): files gcc cannot compile excluded from the fair corpus \[1889:j55479\]
- Precedent: pcc (chosen; named by author): files stock cannot compile excluded from the fair corpus \[1889:j55479\]
- Evidence: v7unix-toolchain:tools/corpus-report.py:98 ORIG = pdp11 dmr-O, vax sjpcc-O; doc/SIZE-REPORT.md "compared ... V7 dmr cc and 32V pcc"

### Grammar as the single source of truth
- Status: DONE — grammars are the source; python pivot undone (latest decision 2026-11-04 \[1882:j2701#1\])
- Decided: 2026-11-04 decided: "grammar is the source of truth; undo your pivot to python" \[1882:j2701#1\] (changes: undoes an earlier pivot to python, not a record in this batch)
- Rationale: "one change to the grammar, and nothing drifts downstream" \[1889:j70736\]
- Rationale: "i said grammar is the source of truth; undo your pivot to python" \[1882:j2701\]
- Rationale: "would be good to use the headers the grammar generates" for the hand-written pcc templates \[1889:1815\]
- Rationale: ld, as and emulator "with hbnf grammars that share as much of a common core as they can" \[1889:j69795\]
- Precedent: hbnf (chosen; named by author): source of truth for the tools \[1882:j2701\]
- Precedent: Python pivot (rejected; named by author): "undo your pivot to python" \[1882:j2701\]
- Evidence: docs/errata.md:239 "89. The grammars are the source of truth of pdp64/16 and pdp64/32"; commit 127d475 "generate the codec tables ... from the hbnf grammars; forms.json is gone"
- Left: Left (potential): use of generated headers for the hand-written pcc templates not recorded

### Long long support and libc helpers
- Status: DONE — long long helpers are in pcc (latest decision 2026-10-19 \[1889:1442#1\])
- Decided: 2026-10-19 approved-proposal: "yes, go ahead with both fixes": constant-shift inlining and emit-on-use helpers \[1889:1442#1\]
- Rationale: "if it can be fixed in pcc, then we fix it in pcc" \[1889:j29925\]
- Precedent: V7/32V libc side (rejected; named by author): asked to do longlong helpers on pcc side instead \[1889:j29864\]
- Evidence: pcc:arch/pdp11/ll.c, lowerll.c, genll.py; README.md "long long is a 64-bit memory object operated on by helper calls"; toolchain commit ebbef60

### Mnemonic and width spelling
- Status: DONE — assembler kept as is; width spelling fixed by the grammar (latest decision 2026-10-21 \[1889:1875#1\])
- Decided: 2026-10-21 decided: "let's keep the asm as it is for now we will revisit it later." \[1889:1875#1\] (relation unclear)
- Rationale: "add.d16 is ugly. we need some other way to flag bit width etc." \[1889:j71476\]
- Rationale: "putting f in front for floating point ops is ok, fadd and I guess fadd16 for 16 bit ops is fine" \[1889:1872\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[533:93\]
- Rationale: "i want our assembler to follow that pattern in general" \[1889:j71461\]
- Precedent: PDP-11 (considered; named by author): not slavishly kept; unneeded instructions can be dropped \[533:93\]
- Precedent: ror over rol (chosen; named by author): assistant made the case; assembler could map rol to ror \[533:93\]
- Evidence: spec/pdp64-mnemonics.hbnf:196 "fadd16"; docs/asm-syntax.md unchanged style
- Left: Left (potential): add.d16 spelling and rol-to-ror mapping not decided

### Optimization rules (net win, correctness, speed, inlining)
- Status: DONE — small cheap gains are kept in the doc, each with an ablation switch (latest decision 2026-10-19 \[1889:j57282#1\])
- Decided: 2026-10-19 changed: "that rule of 'drop if gain is less than 1%' is wrong. any gain is welcome, as long as it doesn't require too many lines of code or slow the compiler down unacceptably" \[1889:j57282#1\] (changes: replaces an earlier rule 'drop if gain is less than 1%', not a line in this batch)
- Rationale: "any gain is welcome, as long as it doesn't require too many lines of code or slow the compiler down unacceptably" \[1889:j57282\]
- Evidence: pcc:doc/PDP64-OPT.md lists many small passes (-xno-minmax, -xno-mullea, -xno-bic); no 1% cutoff found

### Other
- Status: DONE — listed items mostly present; the musl question is open (latest decision 2026-10-13 \[1889:341#1\])
- Decided: 2026-10-13 decided: "put the fuzz and audit scripts into tools" \[1889:341#1\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:tools/pccfuzz.py, pccaudit.py (fuzz and audit scripts); commit 6f22473 "GNU case ranges"; status-check/pcc/doc/PDP64-OPT.md "-xno-minmax"
- Doc differs: The chain has no Now line for this group; the latest line (2026-10-21) is the abs/min/max one

### PDP-11 size against the dmr compiler
- Status: DONE — PDP-11 size work done (doscan not individually verified) (latest decision 2026-10-18 \[1889:1065#1\])
- Decided: 2026-10-18 decided: "fix doscan's last 4 bytes" \[1889:1065#1\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:README.md PDP-11 paragraph; doc/SIZE-REPORT.md "-3.2% / -4.2%" against V7 dmr cc; toolchain commit ebbef60 "VAX doscan fixed"

### Push requests
- Status: DONE — the pushed clone holds the work (latest decision 2026-10-19 \[1889:1391#1\])
- Decided: 2026-10-19 decided: "push everything once the report finishes" \[1889:1391#1\]
- Rationale and precedent: none stated in the sources
- Evidence: status-check/pcc master 41e5c36 (2026-11-07) holds the dmr, aarch64, long long and pdp64 commits (27bd244, 0f618dc, 866061c); toolchain repo is main...origin/main with nothing unpushed

### Root-cause fixes, no workarounds
- Status: DONE — crashes fixed as policy; fixes listed (latest decision 2026-10-17 \[1889:j25209#1\])
- Decided: 2026-10-17 changed: "no.... don't try and drop. fix it!" \[1889:j25209#1\] (changes: replaces 1889:j24755#1, not a record in this batch)
- Rationale: "stop disabling shit. fix it" \[1889:j24316\]
- Rationale: "worth fixing rather than reverting" \[1889:j21788\]
- Rationale: "I'm ok with using 32 bit instead of 64 bit indexes, as long as it all stays correct" \[1889:j24378\]
- Evidence: pcc:README.md "Bug fixes found along the way" ("compiler crashes on register x \>\>= n and \*\*p++ = 0")
- Doc differs: Toolchain commit 6f22473 and others add regression tests; the open question of synthesizing a register afterward is a potential only

### SSA and pcc optimizations alongside dmr
- Status: DONE — spill-slot sharing is in; -xssa itself is off by default (latest decision 2026-10-13 \[1889:365#1\])
- Decided: 2026-10-13 approved-proposal: "try the spill-slot sharing for ssa first" \[1889:365#1\]
- Rationale: "if modern ssa can optimize dmr code even further, it should have a chance" \[1889:j968\]
- Rationale: drop -xssa "until we fix the getnum bug" but run the others "after we already do the dmr opti" \[1889:44\]
- Precedent: dmr optimization pass (chosen; named by author): other optimizations should run after it \[1889:44\]
- Precedent: modern pcc SSA optimizations (considered; named by author): allowed alongside dmr; dropped meanwhile for getnum bug \[1889:j968\]
- Evidence: pcc:README.md "spill-slot sharing sized from the temporaries' real types"; doc/PDP64-OPT.md:48 "-xssa ... slower and bigger ... off by default"

### Slot overlap fix
- Status: DONE — spill slots are sized from the real types and a long-lived temporary gets its own slot (latest decision 2026-10-13 \[1889:j12188#1\])
- Decided: 2026-10-13 decided: Reminds that he said to "fix amd64 overlapping slots instead of excluding it" \[1889:j12188#1\]
- Rationale: "instead of restricting hte optimization, how about just fix the slot overlap?" \[1889:j11066\]
- Rationale: "fix amd64 overlapping slots instead of excluding it" \[1889:j12188\]
- Evidence: commit 463988f "regs: a long-lived temporary spilled while rewriting a short one gets its own slot"; pcc:README.md "spill-slot sharing sized from the temporaries' real types"

### Squashed branch and git history
- Status: DONE — only master remains and the work is in feature commits (latest decision 2026-10-18 \[1889:1244#1\])
- Decided: 2026-10-18 decided: "delete the fix branch too" \[1889:1244#1\]
- Rationale: "hopefully you were squashing feature commits so our mis-steps aren't visible?" \[1889:j32329\]
- Evidence: git branch -a in status-check/pcc lists only master and origin/master; commit 27bd244 "long long: 64 bits on the pdp11 (helpers, lowering) and helpers on the vax"

### Upstream PortableCC
- Status: DONE — the upstream plan was written (latest decision 2026-10-19 \[1889:j46712#1\])
- Decided: 2026-10-19 decided: "look at the complete upstream git history for a pattern to what ragge accepts"; prepare a plan for "a series of pr" for him to merge, "one feature, one bugfix at a time" \[1889:j46712#1\]
- Rationale: "no need to do duplicate work" \[1889:j46323\]
- Rationale: prepare PRs "one feature, one bugfix at a time", using a "pattern to what ragge accepts" \[1889:j46712\]
- Precedent: pcc (chosen; named by author): keep tree up to date with it; keep upstream's fix \[1889:j7146\]
- Precedent: upstream git history (chosen; named by author): source for the pattern of what ragge accepts \[1889:j46712\]
- Evidence: v7unix-toolchain:UPSTREAM-PLAN.md "Written from the whole upstream history (5,481 non-merge commits ...)"; pcc-pr has branch fix-pdp11-relational-cmp pushed to remote mine
- Left: Left (beyond the Now line): the series of PRs themselves is not shown as submitted; not checked on GitHub

### VAX backend and VAX code size against 32V cc
- Status: DONE — VAX is smaller than 32V pcc -O (latest decision 2026-10-17 \[1889:864#1\])
- Decided: 2026-10-17 approved-proposal: "push, then do the VAX files" \[1889:864#1\]
- Rationale: "i think we should at least match the 32v cc in code size if not better it" \[1889:j9831\]
- Precedent: 32V cc (chosen; named by author): code-size baseline to match or beat \[1889:j9831\]
- Evidence: pcc:README.md "-O ... PDP-11 and VAX output is smaller than the original Unix compilers'"; toolchain commit 1d2afa3 "VAX numbers after ... casel liveness"

### VAX output for the 32V assembler
- Status: DONE — as32v built and installed; not labelled bsd (latest decision 2026-10-13 \[1889:j8014#1\])
- Decided: 2026-10-13 decided: "32v as output shouldn't be labelled as bsd" \[1889:j8014#1\]
- Rationale: "you will need to look at the original 32v source code since I'm not sure its pcc emitted the same as as the dmr compiler did" \[1889:j7880\]
- Precedent: 32V assembler (chosen; named by author): flag so the vax backend emits what 32v as accepts \[1889:j7879\]
- Precedent: dmr cc (considered; named by author): unsure the 32v pcc emitted the same \[1889:j7880\]
- Evidence: toolchain commit 7c56942 "as32v: the 32V VAX assembler built for the host, installed beside asv7"; Makefile.am:38 as32v

### aarch64 PR 47 reconciliation
- Status: DONE — Debian path, Mach-O variadics and GOT are in (latest decision 2026-10-19 \[1889:1410#1\])
- Decided: 2026-10-19 approved-proposal: "yes, do both": Debian include path and Mach-O variadic calls \[1889:1410#1\]
- Rationale: "this binary128 stub gives me pause" \[1889:1398\]
- Rationale: "maybe all our aarch64 stuff can be submitted to the pr47 guy so our branch is just bugfixes and the dmr optimizations" \[1889:j49086\]
- Rationale: accepted from the assistant: Mach-O variadics are the real gap, since our Mach-O output uses the Linux convention \[1889:1410\]
- Precedent: PR #47 aarch64 backend (chosen; named by author): compare ours with it and fold in anything good \[1889:1346\]
- Precedent: Debian multiarch include path (chosen; named by assistant, accepted): /usr/include/aarch64-linux-gnu \[1889:1410\]
- Precedent: Apple Mach-O variadic convention (chosen; named by assistant, accepted): fix variadic calls for Mach-O \[1889:1410\]
- Evidence: commits b43f91e "aarch64 looks in /usr/include/aarch64-linux-gnu too (Debian multiarch)", 0041a94 "Apple's variable arguments on Mach-O", 4ffc68a "Mach-O ... GOT", 1017f82 "AArch64 against PR #47"

### aarch64 and dmr optimizations
- Status: DONE — aarch64 fixed and dmr optimizations ported (latest decision 2026-10-18 \[1889:1086#1\])
- Decided: 2026-10-18 decided: "yes, fix aarch64 first, then port the dmr optimizations" \[1889:1086#1\]
- Precedent: dmr optimization pass (chosen; named by author): port whatever can be ported to aarch64 once it works \[1889:j32700\]
- Evidence: pcc:README.md "AArch64 ... A new AAPCS64 LP64 back end ... a text optimizer under -xdmr"; arch/aarch64/peep.h

### aarch64 binary128 support
- Status: DONE — stages 1 to 3 are in (latest decision 2026-10-19 \[1889:1421#1\])
- Decided: 2026-10-19 decided: "yes, go ahead with stage 3" \[1889:1421#1\]
- Rationale: "this binary128 stub gives me pause" \[1889:1398\]
- Precedent: libgcc \_\_addtf3 family (chosen; named by assistant, accepted): stage 3: arithmetic and conversions through library calls \[1889:1421\]
- Evidence: commits f442f70 (storage, constants, ABI), 0f618dc (arithmetic as libgcc calls), 668072b (softfloat binary128); toolchain 698d4ad, 0b84f01

### aarch64 long double default (A64QUAD)
- Status: DONE — A64QUAD stays opt-in (latest decision 2026-10-19 \[1889:1431#1\])
- Decided: 2026-10-19 changed: "3": keep long double off by default, A64QUAD stays opt-in until the runtime question is settled \[1889:1431#1\] (changes 2026-10-19 'make A64QUAD the default')
- Rationale: accepted from the assistant: keep long double off by default, A64QUAD opt-in until the runtime question is settled \[1889:1431\]
- Precedent: GNU libgcc runtime (considered; named by assistant, not taken up): option 1; depends on GCC being installed \[1889:1431\]
- Precedent: own runtime tools/a64quad/tf.c (considered; named by assistant, not taken up): option 2; assistant's recommendation, not chosen \[1889:1431\]
- Evidence: v7unix-toolchain:AARCH64.md:31 "done and off by default: build the compiler with -DA64QUAD"; "A64QUAD stays opt-in"

### c2 pass and IR optimizer (optim2)
- Status: DONE — tree-form passes and c2 inside ccom exist (latest decision 2026-10-17 \[1889:596#1\])
- Decided: 2026-10-17 approved-proposal: "push and resume": push, then deferred addressing next \[1889:596#1\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:mip/optim2.c (tailmerge, looprot); README.md "cross-jumping and tail merging"; cc2/ and common/c2run.h hold the V7 c2 and the 32V c2 port
- Left: Left (potentials only): whether the remaining c2 tricks should move to optim2 or the templates stays unsettled

### dmr optimizations on other targets
- Status: DONE — porting study done and applied to x86 and aarch64 (latest decision 2026-10-13 \[1889:j8522#1\])
- Decided: 2026-10-13 decided: If 32v cc has such optimizations, "see if ant of them port to pdp11 and x86" \[1889:j8522#1\]
- Rationale: wants to see if the original 32v cc has optimizations "that aren't already part of the dmr package" \[1889:j8486\]
- Rationale: test on i386/amd64 by compiling pcc with them twice and verifying "output is byte identical" \[1889:j8084\]
- Precedent: 32V cc (chosen; named by author): original cc, checked for optimizations beyond dmr package \[1889:j8486\]
- Precedent: VAX and x86 platforms (chosen; named by author): final step after the pdp-11 backend is complete \[1889:j5862\]
- Precedent: dmr optimization pass (chosen; named by author): see if any port to pdp11 and x86 \[1889:j8522\]
- Evidence: v7unix-toolchain:DMR-OPTIMIZATIONS-OTHER-TARGETS.md "Which dmr-cc optimizations carry over to the VAX and x86 backends"; status-check/pcc README.md "-xdmr ... x86targets get common/x86peep.h"

### dmr optimizations: goal and scope
- Status: DONE — PDP-11 reached dmr size and the VAX work followed (latest decision 2026-10-17 \[1889:j24151#1\])
- Decided: 2026-10-17 decided: "once the vax code is correct go back and finish off the pdp11" \[1889:j24151#1\]
- Rationale: "i want us to d all his optimization AND BETTER" \[1889:j3853\]
- Rationale: "we don't have to be byte identical to dmr"; wants only "dmr byte count not necessarily byte order" \[1889:j968\]
- Rationale: "if modern ssa can optimize dmr code even further, it should have a chance" \[1889:j968\]
- Precedent: dmr cc (chosen; named by author): make the modern pcc pdp11 backend emit identical code, including optimizer \[1889:0\]
- Precedent: modern pcc -xssa (chosen; named by author): run in parallel with dmr optimizations \[1889:j968\]
- Evidence: pcc:README.md "Brought to V7 dmr cc's size or below on V7's libc and commands"; doc/SIZE-REPORT.md "this fork's -O is -3.2% / -4.2%" against V7 dmr cc (pcc clone status-check/pcc, master 41e5c36)

### gcc cross-build and gcc comparison
- Status: DONE — gcc cross-built for pdp11 and vax and compared (latest decision 2026-10-19 \[1889:1436#1\])
- Decided: 2026-10-19 decided: "regenerate the report when the pdp11 run finishes" \[1889:1436#1\]
- Rationale: accepted from the assistant: restart make with -O1 -g0, objects kept, probably 2 to 3 times faster \[1889:1291\]
- Rationale: accepted from the assistant: PDP-11 build in parallel finishes both about as soon as VAX alone \[1889:1281\]
- Precedent: GCC 4.7 or older (plain C) (considered; named by assistant, not taken up): would avoid C++ host build; judged not worth the trouble \[1889:1291\]
- Precedent: gcc cross-compilers for pdp11 and vax (chosen; named by author): built and measured as comparison reference \[1889:1436\]
- Evidence: pcc:doc/SIZE-REPORT.md "gcc 14.2 is built as a cross-compiler for them (pdp11-aout, vax-netbsdelf)"; toolchain tools/corpus-gcc-cross.sh

### hbnf layout grammar and templates
- Status: DONE — mustache templates are gone from the manual chain (latest decision 2026-11-05 \[1882:307#1\])
- Decided: 2026-11-05 decided: With rewrite rules etc, "the mustache templates are going away"; asks whether hbnf already uses its own built-in mustache. \[1882:307#1\]
- Rationale: "this is the type of application where "rewrite rules" and "text transforms" come into their own in hbnf." \[1882:304\]
- Rationale: One grammar matches "the opcodes and the bit layouts", but what is emitted can be "either the assembler/linker or the svg charts". \[1882:299\]
- Precedent: Mustache (rejected; named by author): "the mustache templates are going away" once rewrite rules exist \[1882:307\]
- Precedent: hbnf %emit{} %action{} with prologue/epilogue (considered; named by author): asks if C code in the grammar can do the job until rewrite rules land \[1882:329\]
- Precedent: hbnf C, Ada, Rust and Zig backends (considered; named by assistant, not taken up): chart backend would sit alongside them \[1882:304\]
- Precedent: Python chart generator (considered; named by assistant, not taken up): interim, behind one layout model \[1882:304\]
- Evidence: spec/pdp64-layout.hbnf; errata 93; grep of tools, spec and docs/manual-src finds mustache only in tools/build-hbnf.sh (a comment on the alpine image)
- Left: Left (potentials): one hbnf grammar that emits charts and assembler; hbnf rewrite rules

### hbnf version
- Status: DONE — latest hbnf in use (latest decision 2026-11-04 \[1882:j2701#2\])
- Decided: 2026-11-04 decided: "use latest hbnf" \[1882:j2701#2\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:239 "builds hbnf dd34982 (origin/main, 2026-11-03)"; tools/build-hbnf.sh; buildabook commit d78be68 "update to the latest hbnf"

### ld64 relaxation
- Status: DONE — relaxation is default, done in as64 and ld64 (latest decision 2026-11-04 \[1882:228#1\])
- Decided: 2026-11-04 approved-proposal: "yes do relax by default": pcc driver passes --relax for pdp64/16 and pdp64/32; plain assembler stays off. \[1882:228#1\]
- Rationale and precedent: none stated in the sources
- Evidence: commit 93a0dc7 "relaxation is the default for pdp64/16 and pdp64/32"; errata 91
- Doc differs: errata 91 says "no tool needs a flag"; the pcc driver is not built for pdp64 (doc/PDP64-OPT.md "cc/cc ... is not built for pdp64")

### m68k backend
- Status: DONE — m68k left as it was (latest decision 2026-10-13 \[1889:396#1\])
- Decided: 2026-10-13 changed: "leave m68k as-is, move on to the others, i86 etc"; simh is "a good enough proxy" for pdp11 testing \[1889:396#1\] (changes 2026-10-13 'do m68k next')
- Rationale: simh is "a good enough proxy" for pdp11 testing \[1889:396\]
- Rationale: "check that these space optimizations don't run into speed pessimizations" \[1889:392\]
- Precedent: SIMH (chosen; named by author): proxy for pdp11 testing instead of building m68k backend \[1889:396\]
- Evidence: pcc:doc/SIZE-REPORT.md "The other back ends (arm, m68k, mips, mips64, sparc64) compile only part of the corpus"

### mips backend
- Status: DONE — mips paused as decided (latest decision 2026-10-13 \[1889:406#1\])
- Decided: 2026-10-13 changed: "pause the mips backend, let's make vax run sweet" \[1889:406#1\] (changes 2026-10-13 'fix mips first, then leaf frames')
- Rationale: "let's make vax run sweet" \[1889:406\]
- Precedent: VAX backend (chosen; named by author): prioritised over mips \[1889:406\]
- Precedent: nova second pass in pcc (considered; named by author): if pcc ships it, bring the dmr c2 pass in too \[1889:406\]
- Evidence: pcc:doc/SIZE-REPORT.md "other back ends ... compile only part of the corpus"

### pcc work items approved in the first dmr session
- Status: DONE — the byte-increment, label and register-variable items are in; PDP-11 matches dmr (latest decision 2026-10-12 \[1889:j3887#1\])
- Decided: 2026-10-12 decided: "do the inch folding of course" \[1889:j3887#1\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:arch/pdp11/local2.c incb/decb (6 hits), table.c (2); README.md PDP-11 paragraph

### pdp64 ABI and long double
- Status: DONE — errata 46 written (latest decision 2026-10-22 \[1889:2497#4\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P13" (long double ABI). \[1889:2497#4\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed" \[1889:1706\]
- Rationale: accepted from the assistant: long double same as double, "There is no hardware for more" \[1889:1712\]
- Rationale: accepted from the assistant: char signed, matching the PDP-11 and x86 tradition, MOVZB for unsigned \[1889:1712\]
- Precedent: PDP-11 and x86 signed char (chosen; named by assistant, accepted): signed char matches their tradition \[1889:1712\]
- Precedent: modern ELF symbol names (no underscore) (chosen; named by assistant, accepted): instead of V7 leading underscore \[1889:1712\]
- Precedent: software 128-bit long double (considered; named by assistant, not taken up): alternative to same-as-double \[1889:1712\]
- Evidence: docs/errata.md:196 "46. DECISION (the author's pick, 2026-10-22; decisions-pending P13): long double stays the same as double"

### pdp64 measurement against clang and gcc
- Status: DONE — fair corpus measured with the pdp64 tools (latest decision 2026-10-22 \[1889:2131#1\])
- Decided: 2026-10-22 decided: gcc -Os and clang -Os figures exist, so "we only need to rerun the fair corpus with the pdp64 backend to compare". \[1889:2131#1\]
- Rationale: gcc -Os and clang -Os figures exist: "we only need to rerun the fair corpus with the pdp64 backend" \[1889:2131\]
- Rationale: "we already beat amd64 on the same code for size and are approaching parity in instructions" \[1889:j75313\]
- Rationale: "how little work went into optimizing the pdp64 backend that result against amd64 is pretty good" \[592:58\]
- Precedent: gcc -Os (chosen; named by author): comparable for the pdp64 backend \[1889:2062\]
- Precedent: clang -Os (chosen; named by author): comparable for the pdp64 backend \[1889:2062\]
- Precedent: other backends with -Os (considered; named by author): asked how pdp64 compares with them \[1889:j75313\]
- Precedent: gcc -Os (considered; named by assistant, not taken up): suggested comparison column for RV64 \[592:58\]
- Evidence: tools/pdp64size.py; commit 98d0ce2 "pdp64size measures gcc -Os and clang -Os for amd64 on the same preprocessed files"
- Left: Left (potential): riscv64 gcc -Os not found in pdp64size.py

### pdp64 pcc optimizations (dmr and sj)
- Status: DONE — dmr and sj optimizations are one family under -xdmr (latest decision 2026-11-04 \[1882:j2691#1\])
- Decided: 2026-11-04 decided: "as with dmr, the sj optims were sometimes specific to the backend, but sometimes applied to all backends" \[1882:j2691#1\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:doc/PDP64-OPT.md:106 "Johnson ('sj') optimizations belong with -xdmr"; section "### Johnson" line 127

### pdp64 toolchain elements and build plan
- Status: DONE — as64, ld64, sim64, backend and qemu exist (latest decision 2026-10-22 \[1889:j72572#1\])
- Decided: 2026-10-22 unclear: "also the sim64, qemu support, etc."; apparently also to be moved along with toolchain commits, details not visible \[1889:j72572#1\] (relation unclear)
- Rationale: "could even use hbnf to help with the opcode layout. good test case for it" \[1889:1706\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed" \[1889:1706\]
- Rationale: "why aren't sp and fp already in as aliases? you don't need a third header for that" \[1889:1818\]
- Precedent: ELF (chosen; named by author): "actually.... elf linker is ok" \[1889:j68834\]
- Precedent: asv7 and ldv7 (chosen; named by author): port them to assemble and link pdp64 \[1889:1699\]
- Precedent: V7 a.out with 64-bit variant (considered; named by assistant, not taken up): assistant's alternative to ELF64 output \[1889:1706\]
- Precedent: GNU ld / lld (considered; named by assistant, not taken up): no back end for this ISA; judged more work \[1889:1706\]
- Evidence: as64/as64.c, ld64/ld64.c, sim64/sim64.c, qemu/README.md "qemu-system-pdp64 -M pdp64-virt", pcc:arch/pdp64/
- Left: The Now line is itself marked unclear; the elements it names are present

### simh testing
- Status: DONE — simh/V7 testing tools exist (latest decision 2026-10-13 \[1889:j7762#1\])
- Decided: 2026-10-13 decided: "you should test the pdp11 output on simh too using the v7 disk image" \[1889:j7762#1\]
- Precedent: SIMH (chosen; named by author): test pdp11 output on it \[1889:j7762\]
- Precedent: V7 disk image (chosen; named by author): used for the simh tests \[1889:j7762\]
- Evidence: v7unix-toolchain:tools/dmrtest.sh and corpus.py mention simh; tools/emutest.py

### softfloat mknormal fix
- Status: DONE — the subnormal rounding fix is in (latest decision 2026-10-19 \[1889:1421#2\])
- Decided: 2026-10-19 decided: "do the mknormal fix" \[1889:1421#2\]
- Rationale: accepted from the assistant: smallest subnormal doubles come out as zero (4.94e-324 should give 1), a candidate small fix \[1889:1421\]
- Evidence: commit 23a14d3 (2026-10-19) "softfloat: a decimal constant in the subnormal range is rounded once" (common/softfloat.c)

### x86 backend changes
- Status: DONE — x86 changes are in (latest decision 2026-10-13 \[1889:434#1\])
- Decided: 2026-10-13 decided: "do the x86 ones first, then vax" \[1889:434#1\] (relation unclear)
- Rationale: "a win is a win, take it." \[1889:434\]
- Precedent: dmr and VAX tricks (chosen; named by author): document how they worked and bring them to x86 and other backends \[1889:434\]
- Precedent: VAX pcc as good as dmr on PDP-11 (considered; named by author): remarked it sounds like VAX pcc was about as good \[1889:434\]
- Evidence: pcc:arch/amd64/local2.c:968 "testl \$m,x"; README.md "common/x86peep.h (redundant tests, loop rotation)"

# Precedents, by name

- The systems, languages, standards and designs named as referents, with the subjects they shaped; chosen = his choice follows it, rejected = he turned it down, considered = compared or cited.

- PDP-11: chosen in Backward compatibility; FPGA target and clock; README; Mashup of PDP-11 with C64 / M8502; Keeping only part of the PDP-11 instruction set; Boot process, BIOS and open firmware and 1 more, rejected in Floating-point format; Set on condition; FPGA target and clock, considered in R7 as a view of the PC; Rotates and ASL flags; Mnemonic and width spelling; Spec revisions and write-up; ISA comparison table
- dmr cc: chosen in dmr optimizations: goal and scope; Dead-code elimination (dce); Fair corpus and compiler comparison; Optimization tricks document and optimization docs, considered in \-xdmr flag and default PDP-11 output; VAX output for the 32V assembler; Benchmark and size reports
- pcc: chosen in Upstream PortableCC; Benchmark report and corpus; Benchmark freeze and fixes against stock; Fair corpus and compiler comparison, considered in Documenting bugs and defects; Benchmark and size reports; PCC README
- Blit: chosen in Blit and C64 as the terminal model, considered in FPGA target and clock; Pain-points research; Mashup of PDP-11 with C64 / M8502
- clang -Os: chosen in pdp64 measurement against clang and gcc, considered in aarch64 against clang -Os; Benchmark and size reports
- Commodore 64: chosen in Blit and C64 as the terminal model; C64 console (c64x), the earlier SDL console, rejected in C64 in spirit, not the hardware; C64 keyboard
- gcc -Os: chosen in Gap to gcc -Os on pdp11 and vax; pdp64 measurement against clang and gcc, considered in pdp64 measurement against clang and gcc; Benchmark and size reports
- OpenBSD: chosen in Pain-points research; Project goal and deliverables; First operating system port, considered in QEMU and LLVM targets
- virtio: chosen in Q64 bus: DMA design, document and PCI Express base; Bus update to virtio-only; Device register model: native 8-register devices to virtio, considered in Resume-mov opcode
- dmr optimization pass: chosen in SSA and pcc optimizations alongside dmr; dmr optimizations on other targets; aarch64 and dmr optimizations
- IEEE 754 floating point: chosen in Floating-point format; FP exception flags; FPGA target and clock
- Linux and BSD kernel assembly: chosen in Comparison with other architectures; Kernel assembly survey document, considered in Kernel assembly survey
- LLVM: chosen in Project goal and deliverables, considered in Undefined items; LLVM doc
- m8502: chosen in Backward compatibility; FPGA target and clock; Mashup of PDP-11 with C64 / M8502
- native 8-register devices: rejected in Q64 bus: DMA design, document and PCI Express base; Bus update to virtio-only; Device register model: native 8-register devices to virtio
- SID: chosen in FPGA target and clock; Mashup of PDP-11 with C64 / M8502, considered in Pixel and audio sample width
- V7 Unix: chosen in Realtime V7 with QNX ideas, considered in Boot process, BIOS and open firmware; First operating system port
- VAX-11: chosen in SP and FP registers; README, considered in Widening the PDP-11 to 64 bits
- 32V assembler: chosen in VAX output for the 32V assembler; as32v in the v7unix-toolchain repo and tool naming
- 32V cc: chosen in dmr optimizations on other targets; VAX backend and VAX code size against 32V cc
- 3BSD: rejected in First operating system port, considered in QEMU and LLVM targets
- AArch64: considered in Spec revisions and write-up; Learning from LoongArch
- ARM csel family: considered in Integer abs/min/max and conditional select; Set on condition
- ARM32 LDRD / MIPS32 FP pairs: considered in Word size; Register width
- buildabook: chosen in Book toolchain, build image and aports; Manual PDF and build
- Commodore 128: chosen in C128 as a bus device, considered in Blit and C64 as the terminal model
- GPT: chosen in Disk label and boot block, considered in Boot process, BIOS and open firmware
- LoongArch64: considered in ISA comparison table; Learning from LoongArch
- Loongson 5-level TLB: considered in Physical address bit that selects device space; Page-table levels
- lwn.net: rejected in Browser use, politeness and site bans, considered in Browser use, politeness and site bans
- M8502 and x86: chosen in MMU and FP units included; Widening the PDP-11 to 64 bits
- major operating systems and architectures: considered in Comparison with other architectures; System doc
- newLISP: chosen in C64 console (c64x), the earlier SDL console; newlisp environment
- NVMe: chosen in Q64 bus: DMA design, document and PCI Express base; Modern I/O hardware (USB, NVMe)
- PCI Express: chosen in Q64 bus: DMA design, document and PCI Express base; Standard GPU, NIC and audio interfaces
- PDP-11 and VAX-11: chosen in Design philosophy and optimization layers, considered in Documenting bugs and defects
- PowerPC 601: chosen in Manual purpose, style and notation, considered in Opcode usage, instruction count and pruning
- QNX/QUNIX: considered in Mashup of PDP-11 with C64 / M8502; Realtime V7 with QNX ideas
- RISC-V: considered in Prefix-coded encodings, 16-register and 32-register grammars; Register count (16 or 32)
- ror over rol: chosen in Mnemonic and width spelling; Keeping only part of the PDP-11 instruction set
- Rowhammer: rejected in Constant-time execution; CPU vulnerability avoidance
- RPi 500 keyboard: chosen in C64 in spirit, not the hardware; C64 keyboard
- SIMH: chosen in m68k backend; simh testing
- Spectre: rejected in Constant-time execution; CPU vulnerability avoidance
- Strecker VAX-11/780 paper: considered in Backward compatibility; MMU and FP units included
- USB: chosen in Q64 bus: DMA design, document and PCI Express base; Modern I/O hardware (USB, NVMe)
- VAX I/O space: considered in Address space (VAX I/O space); Physical address bit that selects device space
- 12 register + dma: considered in Device register model: native 8-register devices to virtio
- 32V pcc: considered in Benchmark and size reports
- 6502: considered in Endianness
- 8502/6502 compatibility in FPGA: considered in Spec revisions and write-up
- 8502 RDY pin hold: chosen in C64 island: 8502 registers readable from outside
- 9P: chosen in C64 console font and 9p interface
- AArch64 ldtr/sttr and m68k moves: considered in Decisions document
- alpine:edge docker with ada-on-alpine: chosen in Book toolchain, build image and aports
- APL/K: chosen in SIMD and vector work
- Apple Mach-O variadic convention: chosen in aarch64 PR 47 reconciliation
- ARM-style memory-mapped device: chosen in SIMD and vector work
- ARM32 SRS/RFE: considered in PUSHX and POPX
- asv7 and ldv7: chosen in pdp64 toolchain elements and build plan
- asv7 (V7 as): rejected in Assembler syntax and names
- AVX2: considered in SIMD and vector work
- C round() / libm: chosen in FP rounding variants
- C syntax for numbers and strings: chosen in Assembler syntax and names
- C64 and PDP-11 similarities: considered in Velinsky link between C64 and DEC
- C99: considered in Old forms and long long libc documentation
- carry-less multiply: chosen in CRC instructions
- clang: considered in Benchmark report and corpus
- clang backends: considered in Kernel assembly survey
- cmov/csel/fsel: considered in Integer abs/min/max and conditional select
- Debian multiarch include path: chosen in aarch64 PR 47 reconciliation
- dmr and VAX tricks: chosen in x86 backend changes
- each clang backend that we have: chosen in Comparison with other architectures
- ELF: chosen in pdp64 toolchain elements and build plan
- ELF64 output (widen ld.c): chosen in Spec revisions and write-up
- gcc: chosen in Fair corpus and compiler comparison
- GCC 4.7 or older (plain C): considered in gcc cross-build and gcc comparison
- gcc cross-compilers for pdp11 and vax: chosen in gcc cross-build and gcc comparison
- gcc cross-compilers on other arches: considered in System doc
- gcc -Os x86-64 / clang -Os: considered in One-parcel forms
- GNU ld / lld: considered in pdp64 toolchain elements and build plan
- GNU libgcc runtime: considered in aarch64 long double default (A64QUAD)
- GPU: considered in GPU and accelerator meaning, helper chips
- hbnf: chosen in Grammar as the single source of truth
- hbnf C, Ada, Rust and Zig backends: considered in hbnf layout grammar and templates
- hbnf %emit{} %action{} with prologue/epilogue: considered in hbnf layout grammar and templates
- HDMI: chosen in Video output (HDMI)
- HDMI, SATA, USB: considered in Standard GPU, NIC and audio interfaces
- IOMMU mapping of C64/C128: considered in Q64 bus: DMA design, document and PCI Express base
- kernel source code: considered in Fact-checking
- kitty: considered in C64 console font and 9p interface
- libgcc \_\_addtf3 family: chosen in aarch64 binary128 support
- Linux and BSD current kernel source: chosen in Pain-points research
- Linux port (GCC or LLVM back end): considered in Undefined items
- Linux security: chosen in Pain-points research
- Lisp machine: chosen in Tagged pointers
- LLVM target sources under llvm/ in pdp64 repo: considered in QEMU and LLVM targets
- LoongArch64 / AArch64: considered in R7 as a view of the PC
- Lua and SQLite: chosen in Benchmark report and corpus
- mailing lists: chosen in Pain-points research
- majority boot block offset: chosen in Disk label and boot block
- manpage-style SEE ALSO section: chosen in Links and navigation between docs
- middle-endian longword order: rejected in Endianness
- Mishnah and Gemara: chosen in Manual purpose, style and notation
- mkbook.py: rejected in Book toolchain, build image and aports
- modern C inline semantics: considered in Benchmark freeze and fixes against stock
- modern ELF symbol names: chosen in Assembler syntax and names
- modern ELF symbol names (no underscore): chosen in pdp64 ABI and long double
- modern pcc SSA optimizations: considered in SSA and pcc optimizations alongside dmr
- modern pcc -xssa: chosen in dmr optimizations: goal and scope
- MS-DOS console font: considered in C64 console (c64x), the earlier SDL console
- Mustache: rejected in hbnf layout grammar and templates
- nova second pass in pcc: considered in mips backend
- Ockham ("ockam"): chosen in Efficiency order for PIE
- old Sanskrit books (aphorism plus commentary): chosen in Manual purpose, style and notation
- OpenBSD disk partitioning: considered in Boot process, BIOS and open firmware
- OpenBSD mitigations: chosen in Memory safety from OpenBSD mitigations
- optim2.c: chosen in Optimizer placement (optim2.c)
- original Lisp: chosen in newlisp environment
- original Unix code (dmr): considered in Documenting bugs and defects
- other backends with -Os: considered in pdp64 measurement against clang and gcc
- out-of-order design: considered in System doc
- own runtime tools/a64quad/tf.c: considered in aarch64 long double default (A64QUAD)
- PAL/NTSC: considered in Video output (HDMI)
- PCIe/NVMe/USB: chosen in Device register model: native 8-register devices to virtio
- PDP-10, PDP-11 and VAX-11: chosen in Manual: deliverable and chapter order
- PDP-11 and x86 signed char: chosen in pdp64 ABI and long double
- PDP-11 SR0 / VAX MAPEN: considered in Mode bits and the "no mode bits" rule
- pdp11/vax/x86 backends only: chosen in Optimization tricks document and optimization docs
- Plan 9 draw(3)/devdraw: considered in Architecture recommendations and open proposals
- PR #47 aarch64 backend: chosen in aarch64 PR 47 reconciliation
- Python chart generator: considered in hbnf layout grammar and templates
- Python pivot: rejected in Grammar as the single source of truth
- QEMU: chosen in QEMU and LLVM targets
- Raspberry Pi SD-card storage: considered in Modern I/O hardware (USB, NVMe)
- Samsung LittleBit-2: considered in GPU and accelerator meaning, helper chips
- SCSI/ATA/SATA/NVMe: considered in Physical address bit that selects device space
- SIMD/AVX: considered in GPU and accelerator meaning, helper chips
- sjpcc: chosen in Fair corpus and compiler comparison
- Smalltalk: chosen in newlisp environment
- software 128-bit long double: considered in pdp64 ABI and long double
- Steve Johnson pcc VAX optimizations: chosen in Dual-encoding toolchain, mnemonics and integration
- Tcl: chosen in newlisp environment
- timing channel attacks: rejected in CPU vulnerability avoidance
- TUHS source: chosen in Fact-checking
- UEFI: considered in Boot process, BIOS and open firmware
- Unix/32V: chosen in First operating system port
- unix on PDP-11 and VAX-11: considered in Decisions document
- upstream git history: chosen in Upstream PortableCC
- USB enumerated over PCIe: chosen in Bus enumeration and attached buses
- UTF-8: chosen in Word size
- V7/32V libc side: rejected in Long long support and libc helpers
- V7 a.out 64-bit variant: considered in Spec revisions and write-up
- V7 a.out with 64-bit variant: considered in pdp64 toolchain elements and build plan
- V7 and 32V old K&R forms: considered in Old forms and long long libc documentation
- V7 disk image: chosen in simh testing
- V7 octal-default numbers: rejected in Assembler syntax and names
- v7as / v7cc prefix naming: rejected in as32v in the v7unix-toolchain repo and tool naming
- VAX and PDP-11 (minimality): considered in Design philosophy and optimization layers
- VAX and x86 platforms: chosen in dmr optimizations on other targets
- VAX backend: chosen in mips backend
- VAX pcc / 32V: considered in Optimization tricks document and optimization docs
- VAX pcc as good as dmr on PDP-11: considered in x86 backend changes
- VAX/PDP: considered in SMP and its decisions document
- VAX svpctx/ldpctx: considered in Kernel assembly survey document
- Velinsky (DEC Rainbow and Commodore designer): considered in Velinsky link between C64 and DEC
- vim: chosen in newlisp environment
- vsock: considered in C64 console font and 9p interface
- x86: chosen in Backward compatibility
- x86 ah/al: considered in Register width
- x86, ARM and RISC-V kernels (incl. OpenBSD): considered in Decisions document
- x86, then VAX: chosen in Optimization tricks document and optimization docs
- xterm-256color subset shim: chosen in C64 console font and 9p interface
- yacc: chosen in as32v in the v7unix-toolchain repo and tool naming

# Where the current docs or code differ from the decisions (42)

- Why pdp64/32 (r20 and pdp64/16 tested against it): README.md:13 says "The architecture is a family, pdp64. It has three members"; README.md:6 lists three manuals and three PDFs; handoff.md:48 says "the members pdp64/r20 (the original encoding), pdp64/16 and pdp64/32"
- Grammar as source of truth (hbnf): docs/errata.md item 89 quotes the author (2026-11-04): "i said grammar is the source of truth; undo your pivot to python. use latest hbnf."
- Opcode field and parcel layout (6-bit opcode): docs/encoding-proposal.md:27 prefix of 1 to 16 bits, not opcode(6)
- Prefix-coded encodings, 16-register and 32-register grammars: docs/errata.md item 87 says "the architecture is pdp64 and its two members are pdp64/16 (16 registers, 4-bit register fields"
- Register names (r16): docs/errata.md item 87: "r16-r31 exist only in pdp64/32"
- Register count (16 or 32): docs/errata.md item 87 says "the architecture is pdp64 and its two members are pdp64/16 (16 registers, 4-bit register fields"; docs/pdp64-isa.md:80 "Sixteen registers"; README.md:13 family of three
- Tagged pointers: docs/pdp64-isa.md:1137 says the three bits come from data alignment, not instruction alignment (the "bottom bit" idea was replaced)
- R7 as a view of the PC: docs/pdp64-isa.md:1333 says R7 is not a view of the PC, with no recorded decision of the author for it
- Stack alignment: docs/abi.md:10 says multiple of 8, not 2
- Integer abs/min/max and conditional select: docs/errata.md item 23 says "AESC sub-opcodes 0x08 (abs rs, rd) and 0x10-0x13 (min, minu, max, maxu" (real opcodes, not assembler aliases)
- FP16 support: docs/errata.md item 24 says "\`fadd16\` binary16 when half-precision arrives" (stale wording)
- Constant-time execution: docs/decisions-pending.md:124 says "proposed: option 3 (a core set always constant-time plus a DIT bit"
- FPGA target and clock: docs/pdp64-fpga-plan.md:97-99 estimates 50-80 MHz (Cyclone V), 90-130 MHz (Zynq 7020), 180-250 MHz (UltraScale+), and :110 "Do not chase frequency in phase 1"
- Root-cause fixes, no workarounds: Toolchain commit 6f22473 and others add regression tests; the open question of synthesizing a register afterward is a potential only
- \-xdmr flag and default PDP-11 output: README.md says "Without -xdmr the generated code differs from stock only through the bug fixes below"
- as32v in the v7unix-toolchain repo and tool naming: the record "it will install as 32vas alongside v7as" differs: the repo installs as32v beside asv7
- QEMU and LLVM targets: handoff.md: the build machine has 3.9 GB RAM, the move to a bigger machine is not recorded
- Assembler syntax and names: asm-syntax.md:15 says a bareword of digits only is a local label; the Now line says digit-leading name with a colon
- ld64 relaxation: errata 91 says "no tool needs a flag"; the pcc driver is not built for pdp64 (doc/PDP64-OPT.md "cc/cc ... is not built for pdp64")
- Other: The chain has no Now line for this group; the latest line (2026-10-21) is the abs/min/max one
- Git history, merging and pushing: git status: untracked c64stuff.txt, chat02.txt, tools/declog/ and modified .gitignore are not pushed (decision-log is deliberately local)
- README: README.md:13 says "The manual (docs/manual/) still describes pdp64/r20 only"; README.md:6 and :13 present r20, 16 and 32 as three members
- Decisions document: docs/errata.md is a separate file, not inside decisions-pending.md; decisions-pending.md is not linked from README text of rule 'don't link it' (README does link it at the principles section)
- Manual: deliverable and chapter order: order bus, graphics, boot, drivers (index) differs from the 'boot, device driver, graphics' of 1889:j79425#1 and 'bus, blitter, boot' of 1889:j79473#1; the later j79473 is the one followed
- Manual location and split: docs/manual/00-index.md says "The pdp64 is a family of three CPUs, and each has its own manual"; errata 93 says the same
- Manual purpose, style and notation: docs/manual-src/09-isa.md:75 "the mask is 32 bits" gives no binary form
- Manual PDF and build: book/ builds three PDFs (r20, 16, 32), not one; single pdp64/32 book is all that is now wanted
- Variant testing document: README.md:13 still presents r20, pdp64/16 and pdp64/32 as three members of a family
- Mashup of PDP-11 with C64 / M8502: none found
- Work-order priorities (what to do next): none; the "once the bugs on powerpc are fixed" line is an unclear referent and needs no action here
- Design priority list: docs/priority-lists.md:120 still says "(For you to write. ...)" above the author's annotations
- The pdp64 family: docs/errata.md entry 93 says "there is one manual for each CPU of the family"
- Q64 bus: DMA design, document and PCI Express base: docs/manual-src/02-bus.md:9 says "its full rewrite waits"; docs/pdp64-q64-bus.md:25 "the transaction definitions (widths, bursts, ...) are not written"
- Physical address bit that selects device space: docs/errata.md:210 entry 60 still headed "PROPOSAL ... bit 40"
- C64 island: 8502 registers readable from outside: the C64 devices are deferred (errata 78), so the island is not in the manual
- Video output (HDMI): the standard video device is now virtio-gpu (errata 79), so HDMI timing is not in the manual body
- Device register model: native 8-register devices to virtio: docs/errata.md entry 29 says "devices are eight memory-mapped registers plus DMA"
- Crypto and random-number devices: errata 85 records decisions the chain shows only as potentials
- First operating system port: docs/errata.md:114 entry 30 and :165 entry 30a keep the older text as history (marked superseded by 41)
- Exception and interrupt entry: docs/decisions-pending.md says "I extended it to interrupts, which you did not explicitly say" (flagged for the author to confirm)
- Page-table levels: docs/decisions-pending.md:734 "3 levels, 39-bit (current)" and lists 4 levels as a rejected-by-default option
- Dedicated core classes: docs/smp-decisions.md:12 "The dedicated-core proposal (graphics, network, audio) is a proposal"
