# The pdp64: decisions and status

## About this ledger

- What it is: for each design and implementation choice the author made about pdp64 over time, where it stands now against the current docs and code: what is done, what is left to do, what was rejected, and what is left in the air.
- Precedence (the author's rule): more recent decisions have greater precedence; each subject's status follows its latest standing line.
- Each subject: `Status`, `Decided` (the latest standing line with its source `[R<n>]`, a row of the decision register), `Evidence` (file, line, quote or commit) or `not found: searched ...`, `Doc differs` where a doc or code says something else, `Left` for what remains.
- The decision register: each of the author's messages cited here is a numbered row [R<n>] of the append-only [decision register](decision-register.md) (the date, the kind, his words, the subjects, and what a later row replaced); numbers are never reused, a replaced row points forward.
- Checked, not guessed: a status of DONE needs evidence; what could not be checked is IN THE AIR and says why.
- `Rationale` is why he chose it, in his own words; `Precedent` is a system, language, standard or design named as a referent, with whether his choice follows it (chosen), he turned it down (rejected) or it was only compared (considered), and who named it (the author, or the assistant and he accepted it or did not take it up). Only what the messages say: nothing is added from outside. The precedents are indexed by name near the end.
- The chains behind it are in the decision log of the same project; the evidence is as of the repositories read on 2026-11-10.
- pdp64/32 is the decided pdp64 (author, 2026-11-10); r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and removed as code (tags pre-single-cpu and pre-code-removal keep them). Checked against the working tree of this repository at commit b10f52b, a fresh pcc clone (commit 41e5c36, 2026-11-07) and the toolchain repository.

## Contents

- [Summary](#summary)
- [Left to do (38)](#left-to-do-38)
- [Left in the air (20)](#left-in-the-air-20)
- [Rejected or replaced (8)](#rejected-or-replaced-8)
- [Done (164)](#done-164)
- [Precedents, by name](#precedents-by-name)
- [Where the current docs or code differ from the decisions (41)](#where-the-current-docs-or-code-differ-from-the-decisions-41)
- [Decision briefing: open questions and decisions under review](#decision-briefing-open-questions-and-decisions-under-review)
- [Decisions recorded after this ledger was built (2026-11-09 and 2026-11-10)](#decisions-recorded-after-this-ledger-was-built-2026-11-09-and-2026-11-10)
- [Briefing A: the physical address, the page table and how software learns them](#briefing-a-the-physical-address-the-page-table-and-how-software-learns-them)
- [Q1 The first few pages (QUESTION)](#q1-the-first-few-pages-question)
- [Q2 Discovering the implemented widths (QUESTION)](#q2-discovering-the-implemented-widths-question)
- [Q3 The page-table entry for wide physical addresses (QUESTION)](#q3-the-page-table-entry-for-wide-physical-addresses-question)
- [Q4 Locating devices without a selecting bit (QUESTION)](#q4-locating-devices-without-a-selecting-bit-question)
- [D1 The physical address width: at least 40 bits, up to 64 (REVIEW)](#d1-the-physical-address-width-at-least-40-bits-up-to-64-review)
- [D2 Page tables of 3, 4 or 5 levels, discoverable (REVIEW)](#d2-page-tables-of-3-4-or-5-levels-discoverable-review)
- [Briefing B: the deferred native devices, console/timer/entropy, interrupt delivery, the bus controller](#briefing-b-the-deferred-native-devices-consoletimerentropy-interrupt-delivery-the-bus-controller)
- [Q5 The deferred native devices (QUESTION)](#q5-the-deferred-native-devices-question)
- [Q6 Console, timer and entropy under virtio (QUESTION)](#q6-console-timer-and-entropy-under-virtio-question)
- [Q7 Interrupt delivery and vector numbers (decision R1) (QUESTION)](#q7-interrupt-delivery-and-vector-numbers-decision-r1-question)
- [Q8 The bus controller of errata 49 (QUESTION)](#q8-the-bus-controller-of-errata-49-question)
- [Q9 The conditional select and the expansions of abs, min, minu, max, maxu (QUESTION)](#q9-the-conditional-select-and-the-expansions-of-abs-min-minu-max-maxu-question)
- [D3 abs, min and max as assembler aliases (REVIEW)](#d3-abs-min-and-max-as-assembler-aliases-review)
- [Q10 Stack alignment (QUESTION)](#q10-stack-alignment-question)
- [Q11 Constant-time execution (QUESTION)](#q11-constant-time-execution-question)
- [Briefing D: the testing record, the priority list, the toolchain wording, the repository's fate (Q12 to Q16)](#briefing-d-the-testing-record-the-priority-list-the-toolchain-wording-the-repositorys-fate-q12-to-q16)
- [Q12 The testing against r20 and pdp64/16 (QUESTION)](#q12-the-testing-against-r20-and-pdp6416-question)
- [Q13 The priority list (QUESTION)](#q13-the-priority-list-question)
- [Q14 The relaxation wording (QUESTION)](#q14-the-relaxation-wording-question)
- [Q15 The ungated change under -xdmr (QUESTION)](#q15-the-ungated-change-under--xdmr-question)
- [Q16 What becomes of r20 and pdp64/16 in the repository (QUESTION)](#q16-what-becomes-of-r20-and-pdp6416-in-the-repository-question)
- [Briefing F: five REVIEW items the author has decided (D4 to D8)](#briefing-f-five-review-items-the-author-has-decided-d4-to-d8)
- [D4 The FPGA clock: 200 to 300 MHz (REVIEW)](#d4-the-fpga-clock-200-to-300-mhz-review)
- [D5 R7 is an ordinary register, not a view of the program counter (REVIEW)](#d5-r7-is-an-ordinary-register-not-a-view-of-the-program-counter-review)
- [D6 The disk is virtio-blk (REVIEW)](#d6-the-disk-is-virtio-blk-review)
- [D7 Virtio across the board (REVIEW)](#d7-virtio-across-the-board-review)
- [D8 pdp64/32 is the pdp64 (REVIEW)](#d8-pdp6432-is-the-pdp64-review)

# Summary

- Left to do: 38 of 230 subjects
- Left in the air: 20 of 230 subjects
- Rejected or replaced: 8 of 230 subjects
- Done: 164 of 230 subjects

# Left to do (38)

- Decided, and not yet in the current code or docs (or only partly).

## 02 Bus

### Access to a departed device's windows
- Status: TO DO — decided, details to be determined (latest decision 2026-10-22 \[R262\])
- Decided: 2026-10-22 decided: "your bus design looks excellent, let's wait for pain points to land before settling it, but it looks good." \[R262\]; placed in the manual by the approval rule \[errata 121\]
- Evidence: docs/manual-src/02-bus.md:226 "\*\*2.4.9\*\* When a device leaves, an access to its windows is at once a precise bus fault, not a read of all ones ... \*(D)\* Details to be determined."; docs/errata.md:287 entry 121 ("2.4.9 ... decided, with details to be determined, on the strength of R262")
- Left: the details of the fault, the dropped-and-counted posted write and the aborts (marked "to be determined"); the author's wait for the pain points, which is his stated condition for settling the bus design

### Device windows on page boundaries
- Status: TO DO — decided, details to be determined (latest decision 2026-10-22 \[R262\])
- Decided: 2026-10-22 decided: "your bus design looks excellent ... but it looks good." \[R262\]; placed in the manual by the approval rule \[errata 121\]
- Evidence: docs/manual-src/02-bus.md:130 "\*\*2.3.6\*\* The windows of a device ... start on 4 KB page boundaries and are a whole number of pages, so that one device can be mapped to one protection domain. \*(D)\* Details to be determined."; docs/errata.md:287 entry 121
- Left: the details of the window rule (to be determined)

### Interrupts as memory writes (MSI-X)
- Status: TO DO — decided, details pending (latest decision 2026-11-09 \[R360\])
- Decided: 2026-11-09 approved-proposal: "i like all your recommendations, go ahead and update the bus chapter" \[R360\]; the manual marks MSI-X decided with details pending \[errata 121\]
- Evidence: docs/manual-src/02-bus.md:283 "\*\*2.6.1\*\* A device interrupts by a message-signalled write (MSI-X)", docs/manual-src/05-drivers.md:294 "\*\*5.9.1\*\*"; docs/errata.md:287 entry 121 ("MSI-X (2.6.1, 5.9.1) is marked decided with details pending (J.6.3)")
- Left: interrupt delivery to a core, the vector count and numbering, moving an interrupt between cores (J.6.3); the errata do not name the author's own message that approves MSI-X, so the approval rests on his blanket "i like all your recommendations"

## 03 Graphics and the C64 devices

### Anti-tearing conveniences
- Status: TO DO — decided, details pending (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "we want to put in nice architectural sugar to avoid 'tearing' and all those other issues graphics programmers had to use double buffering to fix." \[errata 105\]
- Evidence: docs/manual-src/03-graphics.md:392 "\*\*3.15.1\*\* The architecture offers conveniences, \\"nice architectural sugar\\", that avoid tearing ... \*(D)\* Details pending (J.3.8)"; docs/errata.md:256 entry 105 item (2) (wanted, not designed, tagged (P))
- Left: which conveniences, and whether a tear-free flip is worth hardware when the display is variable-refresh (J.3.8); a write-combining memory type for the framebuffer (J.3.10)

### C64 mode (a C128 on the die)
- Status: TO DO — decided, details pending (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "we will have a c64 mode, where a c128 is built onto the die with sid etc, so a bit of code loaded into its address space by pcie dma will let it act as a terminal the way the blit and vt55 did"; "the mode is just enabling/disabling the c128 as a pcie device so it takes over the graphics and audio output... or sends them to a compositor" \[errata 105\]
- Evidence: docs/manual-src/03-graphics.md:396 "\*\*3.16.1\*\* The pdp64 has a \*\*c64 mode\*\* ... \*(D)\* ... Details pending (J.3.11)", :398 "\*\*3.16.2\*\*"; docs/errata.md:256 entry 105 (written there as a proposed design idea, tagged (P); the manual now tags it (D) under the approval rule of errata 121)
- Left: which core (hard, soft, emulated, or none), whether unmodified C64 software runs, how the core and the host talk, how the loaded image is contained (J.3.11); the tension with "virtio across the board" (errata 78, 95) is stated in errata 105 and not resolved; the author's "vt55" is not in the repository (the VT52 is)

### Compositor path
- Status: TO DO — preference stated, details pending (latest decision 2026-11-10 \[errata 106\])
- Decided: 2026-11-10 decided: of the five compositor paths, "c128 drawing into a buffer makes most sense" \[errata 106\]
- Evidence: docs/manual-src/03-graphics.md:400 "\*\*3.16.3\*\* Of the paths to a compositor, the C128 draws into a buffer that the host's compositor treats as a surface ... Details pending (J.3.12)"; docs/errata.md:258 entry 106 item (2) (recorded there as a preference, tagged (P))
- Left: how the compositor learns that the buffer is the core's, who owns the memory, frame timing, the audio form (J.3.12)

### Graphics programming made simple
- Status: TO DO — decided as a goal and a measure, details pending (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "basically, anything that made graphics programming annoying or cumbersome or boiler platey, we want to sugar away to almost nothing."; "graphics programming should be as simple and pleasurable as the c64 was." \[errata 105\]
- Evidence: docs/manual-src/03-graphics.md:257 "\*\*3.14.1\*\*", :259 "\*\*3.14.2\*\* ... \*(D)\* ... Details pending (J.3.9)"; docs/errata.md:256 entry 105 (the goal tagged (P) there)
- Left: which sugar (J.3.9); only the coherence rule and the shadowed-register frame latch are decided designs

### Simplicity of rio and NeWS
- Status: TO DO — decided as a goal, details pending (latest decision 2026-11-10 \[errata 106\])
- Decided: 2026-11-10 decided: "it should mention blit terminal was inspiration for the rio and NeWS windowing systems, and we'd like to bring over what we can of that simplicity also" \[errata 106\]
- Evidence: docs/manual-src/03-graphics.md:457 "\*\*3.18.1\*\* The pdp64 brings over what it can of the simplicity of rio and NeWS ... \*(D)\* Details pending (J.3.14)"; docs/errata.md:258 entry 106 item (1); the claim that the Blit inspired NeWS is the author's and no source read makes it
- Left: which simplicities and in what form (J.3.14)

### The form of the terminal device
- Status: TO DO — the properties are decided, the form of the device is open (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "our virtio-console device is an attempt to bring the nice properties of the blit terminal and c64 for doing simple and easy peek poke style display of text and also doing graphics, but with modern color depths and screen sizes, and with glyph maps we can even have a ttf engine generate glyphs and they will go into their memory slots for use" \[errata 105\]
- Evidence: docs/manual-src/03-graphics.md:181 "\*\*3.9.1\*\* The pdp64's terminal brings the nice properties of the Blit terminal and the C64 ... a \*\*glyph map\*\* ... \*(D)\* Details pending (J.3.2)"; docs/errata.md:256 entry 105 item (4): the virtio-console of the virtio specification is a serial text device, so the author's device is none of virtio-console, virtio-gpu 2D or a native device
- Left: what the device is (four readings listed in J.3.2), glyph slots against character codes (J.3.4), sprites and a hardware cursor (J.3.5)

## 04 Boot

### Device initialization protocol
- Status: TO DO — decided in principle, details pending (latest decision 2026-10-22 \[R256\])
- Decided: 2026-10-22 decided: "the init protocol should mostly happen behind the bus, poke a register to tell the device \\"initialize yourself\\" and possibly have another register populated with values or a binary firmware blob for the device to load" \[R256\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/04-boot.md:264 "\*\*4.8.1\*\* A device is initialised by a write to a register of the device that tells it to initialise itself ... \*(D)\*"; docs/manual-src/05-drivers.md:340 (virtio has no firmware operation; the \`device\_status\` handshake is the descendant of \`INIT\` and \`READY\`); docs/errata.md:283 entry 119 (4.8 states \`INIT\` and \`READY\` are the PDP-11 start of a device)
- Doc differs: docs/manual-src/04-boot.md:264 states the register write in the words of the eight-register devices that errata 95 withdrew
- Left: whether the bus gives a device-initialize register under virtio and how firmware is delivered (J.4.5, J.5.3)

## 05 Drivers and devices

### Crypto and random-number devices
- Status: TO DO — the author said "we'll go along those lines" of OpenBSD's recommendations; details pending (latest decision 2026-11-04 \[R323\])
- Decided: 2026-11-04 decided: "not sure random number in hardware is a good idea, but pull all the openbsd recommendations in that department, see what they prefer and like, we'll go along those lines." \[R323\]; "perhaps common crypto algorithms should be on their own devices on the pci bus" stays a potential
- Rationale: "guys suffered from bad rng in the past"; optimizing their rng algorithms "is ok". \[R323\]
- Evidence: docs/errata.md:235 entry 85 "Random numbers (P9): the pool is one device shared by all cores"; docs/manual-src/05-drivers.md:270 "\*\*5.7.2\*\* The entropy source is one pool shared by all cores ... \*(D)\* Details pending (J.5.1)"; docs/crypto-secure-core.md
- Doc differs: errata 85 records decisions that the chain shows only as the "we'll go along those lines" approval of OpenBSD's recommendations, not each item
- Left: whether a physical source stands behind the pool and how the pool is reached (J.5.1); the crypto-on-their-own-devices idea is open

### Virtio devices supported in silicon
- Status: TO DO — decided, details pending (latest decision 2026-11-09 \[R359\])
- Decided: 2026-11-09 decided: "the decision that we will support all the virtio devices in silicon (the ones it makes sense to support, that is) and also that we are standardizing on the latest usb/nvme/pcie buses" \[R359\]
- Evidence: docs/manual-src/05-drivers.md:98 "\*\*5.2.1\*\* The pdp64 supports in silicon the virtio devices that it makes sense to support, and it standardises on the latest buses, USB, NVMe and PCI Express. \*(D)\* ... Details pending (J.5.6)"
- Left: which virtio devices count, and what the syntactic sugar is (J.5.6); the features that the pdp64 accepts (J.5.2)

## 06 Kernel, modes and memory management

### Page-table levels
- Status: TO DO — three, four and five levels are in the manual; the way software discovers the level count is details pending (latest decision 2026-11-09 \[R361\])
- Decided: 2026-11-09 decided: "i'm ok with allowing 3 level tlb, 3 4 and 5 is good, as long as this info is discoverable easily at runtime. so, 39, 48, 57 bit is all fine. good thing we already had dmw in the design!" \[R361\]; and "why does it say that 3 level tlb isn't supported?" \[R364\]; "how about we allow 4 levels" \[R360\]
- Rationale: "3 4 and 5 is good, as long as this info is discoverable easily at runtime." \[R361\]
- Precedent: Loongson 5-level TLB (considered; named by author): asked what is affected "if we have 5 level tlb like loongson" \[R360\]
- Evidence: docs/manual-src/06-kernel.md:246 "\*\*6.6.1\*\* Virtual addresses are translated by three, four or five levels of nine bits over 4 KB pages, which gives virtual addresses of 39, 48 or 57 bits ... \*(D)\*", :248 "The number of levels is readable by software at runtime ... Details pending: the register or field that reports them (J.6.1)", :250 "\*\*6.6.2\*\*"; docs/errata.md:246 entry 96
- Doc differs: docs/decisions-pending.md:734 "3 levels, 39-bit (current)" and its listing of four levels as a rejected-by-default option (errata 96: the question stays there as the record of the options); the QEMU walker, the simulator and the emulator implement three levels only (docs/implementation-status.md)
- Left: the register or field that reports the level count and the physical width (J.6.1); the page-table entry for wide physical addresses (J.6.2)

## 07 Multiple processors

### Dedicated core classes
- Status: TO DO — decided as the author's recommendation, details pending (latest decision 2026-11-04 \[R313\])
- Decided: 2026-11-04 decided: "we recommend one core dedicated to the gpu/graphics device, one core dedicated to the nic, running the full tcp/ip stack, then a bunch of other cores for general processing."; "and also one core for audio processing, doing midi, dsp, etc." \[R313\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/07-smp.md:110 "\*\*7.8.6\*\* The machine has one core dedicated to the graphics device, one dedicated to the network interface ..., one dedicated to audio ... \*(D)\* Details pending (J.7.5)"; docs/manual-src/03-graphics.md:175 "\*\*3.8.2\*\* One core is dedicated to the graphics device"; docs/errata.md:226 entry 76
- Doc differs: docs/errata.md:226 entry 76 is still headed "PROPOSAL (the author's recommendation" and records it as a proposal; docs/smp-decisions.md:12 "The dedicated-core proposal (graphics, network, audio) is a proposal"; the manual now tags it (D) under the approval rule of errata 121
- Left: how many dedicated cores, how they share memory with the others, what they run (J.7.5; decisions-pending.md F16 to F21)

## 12 Documentation and process

### History import from the other machine
- Status: TO DO — the the other machine prompts are imported into the imp72 and hbnf decision-log inputs but not into the pdp64 inputs (latest decision 2026-11-10 \[R373\])
- Decided: 2026-11-10 decided: Lost history from the other machine, but the prompts typed are still there, so "import those at least". \[R373\]
- Rationale and precedent: none stated in the sources
- Evidence: tools/declog/extract.py:106 \`--history LABEL=FILE\` (imports prompts of sessions whose files are gone as history-only threads); docs/decision-log/data/imp72 and docs/decision-log/data/hbnf contain "history-only" ids (imp72 3775 "history only" hits, hbnf 39 files); not found: "history-only" in docs/decision-log/data/pdp64 or data/shared (0 files), nor "history only" in pdp64/threads.json
- Left: run the history import for the pdp64 scope (or confirm that no the other machine history prompt is relevant to pdp64)

## Documentation and process

### Decision log
- Status: TO DO — logs and status documents are built for the three projects; the ledger step is in progress (latest decision 2026-11-10 \[R372\])
- Decided: 2026-11-10 decided: Fetch the the other machine archives with "just ssh and scp" \[R372\]
- Rationale: wants "not only the current decisions, but the chain of decisions that led there" \[R367\]
- Rationale: single-line point form for now; "later we can expand fully on things when i annotate it" \[R369\]
- Evidence: docs/decision-log/ has decision-log.md/.html/.pdf, imp72-decision-log.md, imp72-plan.md, imp72-status.md, hbnf-status.md, pdp64-status.md (each also .html and .pdf), build\*/ (buildabook configs), data/{hbnf,imp72,pdp64,shared}; docs/decision-log/ is excluded by .gitignore (commit 8cb79b7, approved at R368); tools/declog/ untracked; the other machine's archive/ holds the two settings folders of the assistant tool and imp72-repo (2.0 GB, fetched 2026-11-09)
- Left: no hbnf plan document (only hbnf-status.md; R371); the ledger step (this file) is in progress; whether the the other machine prompts are imported: see "History import from the other machine"

### Document tarball, test-harness doc and changes document
- Status: TO DO — changes document done; test-harness doc and the tarball not found (latest decision 2026-10-21 \[R165\])
- Decided: 2026-10-21 decided: Write a comprehensive md of all changes since the tar: "the decisions we made, why we made them", dropped or changed opcodes, clarifications, design errors fixed. \[R165\]
- Rationale: Wants "a nice written changes document": "the decisions we made, why we made them", dropped opcodes, clarified items, design errors fixed. \[R165\]
- Rationale: Tarball is "for me to upload", after checking the documents are consistent with each other. \[R147\]
- Evidence: docs/CHANGES-SINCE-R20.md ('every decision, correction, clarification and dropped or changed opcode made since'); not found: a test-harness doc (grep 'test harness' in README, handoff, docs/encoding-work) or a pdp64-docs tar.gz in the repo
- Left: test-harness doc and tarball; CHANGES-SINCE-R20.md is r20-centred and stops before the pdp64/32-only decision

### Documentation style rules
- Status: TO DO — the style rules are not met: the rewritten chapters, README and other documents carry absolute paths (latest decision 2026-10-24 \[R308\])
- Decided: 2026-10-24 approved-proposal: "good": proceed with batch 2 rewrite of listed documents under the rules (no absolute paths, no tool mentions, no process-failure narratives). \[R308\]
- Rationale: "i don't want the docs to record any of \[assistant\]'s fuckups like the lwn.net blockages"; "lwn.net coverage was limited" is enough \[R306\]
- Evidence: grep for home-directory paths: docs/manual-src/02-bus.md (2 lines: :493, :494), 03-graphics.md (2: :462, :463), 04-boot.md (4: :279, :333 and two more), 05-drivers.md (2: :350, :363), 06-kernel.md (2), appendix-parts/04-proposed.md (1), README.md:74, docs/smp-decisions.md:24, :60-63, :71 and about ten more, docs/retire-stage-candidates.md:482, docs/spill-experiment.md:9-10; the assistant's name appears in c64-devices-from-chat.md, decisions-pending.md, retire-stage-candidates.md, security-proposals.md, spill-experiment.md, study-proposals.md
- Doc differs: the "What was checked" sections of manual chapters 2 to 6 cite ... source trees (qemu-src, facetlang/unixtree, kernel-src), added by errata 111 to 119 after this rule
- Left: replace the absolute paths by the name of the source tree (e.g. "the 2.11BSD sources") in the chapters, README.md, smp-decisions.md and the six other documents

### Instruction dictionary and entries
- Status: TO DO — dictionary generated from grammar with charts; page-break rule not found in tools (latest decision 2026-11-05 \[R349\])
- Decided: 2026-11-05 decided: Rule: "a new entry must have a couple lines of text underneath its title and layout charts, otherwise it should start at the top of the next page." \[R349\]
- Rationale: "this is the full reference manual, don't skip on the instruction set dictionary!" \[R283\]
- Rationale: every instruction "should have the story of why it was chosen to be in the isa" \[R286\]
- Evidence: docs/manual/dictionary/ (by-mnemonic.md, by-encoding.md) and figures/\*.svg; errata 93 charts from the grammar; commit 02a39ff 'one entry per mnemonic with a chart of each of its layout forms ... books keep an entry's title and charts with its text'; not found: a rule for starting thin entries on the next page (grep in tools/\*.py and book/template.typ)
- Left: the page-start rule is only approximated by 'keep title and charts with text' (book/template.typ:53 non-breakable images); the 7 'Cf.' lines in manual-src/09-isa.md (:210, :241, :302 and four more) follow R301 (pointers allowed); open question R348 on category sections is answered by commit 02a39ff (category sections of chapter 9)

### Manual purpose, style and notation
- Status: TO DO — aphorism and commentary style done; binary values and utf8 pseudocode only partly (latest decision 2026-10-23 \[R303\])
- Decided: 2026-10-23 decided: "masks should be in binary too". \[R303\]
- Rationale: "this cpu designer thinks all isa are equivalent; this is to show him how wrong he is" \[R275\]
- Rationale: sections "explain every decision in light of how it impacts efficient kernel, efficient compilation, and efficient hardware layout" \[R276\]
- Rationale: commentary covers "the historical precedents, the tradeoffs, the improvements, the benefits, and the modern comparables" \[R269\]
- Precedent: old Sanskrit books (aphorism plus commentary) (chosen; named by author): style: aphorism followed by commentary \[R269\]
- Precedent: Mishnah and Gemara (chosen; named by author): same aphorism-then-commentary structure \[R269\]
- Precedent: PowerPC 601 (chosen; named by author): "an excellent example of a cpu manual" \[R270\]
- Evidence: docs/manual-src/00-index.md:35 'Each section is a few numbered aphorisms followed by a commentary'; pseudocode in docs/manual/09-isa.md uses ← (169 uses) and still 2 '\<-' (line 2174 and 2359); not found: a binary mask with its hex in brackets in 09-isa.md (instruction figures show prefixes in binary, e.g. "prefix 11010001")
- Doc differs: docs/manual-src/09-isa.md:104 (9.3.8) "the mask is 32 bits" and :340 (9.11.1) give no binary form
- Left: values and masks in binary with hex in brackets (R302, R303); the two remaining '\<-'

### Manual readers and the rewrite of the chapters
- Status: TO DO — details pending: chapters 2 to 6 are rewritten for the two readers; chapters 1, 7, 8, 9, 10 and the appendices are not yet (latest decision 2026-11-10 \[errata 103\])
- Decided: 2026-11-10 decided: "the manual should be written as if a first year compsci student OR an experienced pdp11 assembly programmer were reading it; both don't know about anything that happened in computer architecture since the 1970's" \[errata 103\]; then chapter by chapter: "now do the graphics chapter from the same point of view" \[errata 105\], "do the kernel chapter next from the same point of view" \[errata 107\], "do the boot chapter next from the same point of view" \[errata 108\], "do the drivers chapter next" \[errata 115\]
- Evidence: docs/manual-src/02-bus.md:11 (2.1 "What you already know: the Unibus"), 03-graphics.md:21 (3.1 "The teletype"), 04-boot.md:9 (4.1 "starting a PDP-11"), 05-drivers.md:11 (5.1 "a PDP-11 driver"), 06-kernel.md:9 (6.1 "the kernel of a PDP-11"); commits adde39b (bus), 4b5a058 (graphics), 6ab2253 (kernel), ade1a6d (boot), 5abf284 (drivers)
- Left: chapters 1, 7 (smp), 8 (vectors), 9 (instruction set), 10 (conclusion) and the appendices are "to follow" (errata 107, 108, 115 say nothing yet on whether, how or in what order); the manual-src files of 07 and 08 last changed 2026-11-04

### Old forms and long long libc documentation
- Status: TO DO — OLD-K&R-FORMS.md exists but the "to fix" mark for the long long libc on the v7 side is not in the toolchain docs (latest decision 2026-10-17 \[R77\])
- Decided: 2026-10-17 decided: "the documentation should be done last, after vax and pdp11 are fully optimized as far as correctness allows" \[R77\]
- Rationale: "the documentation should be done last, after vax and pdp11 are fully optimized as far as correctness allows." \[R77\]
- Rationale: Wants "what regressions from c99 would it cause" documented for each old form. \[R76\]
- Precedent: V7 and 32V old K&R forms (considered; named by author): forms pcc doesn't support; cost of supporting them \[R76\]
- Precedent: C99 (considered; named by author): regressions from C99 if old forms were supported \[R76\]
- Evidence: v7unix-toolchain:OLD-K&R-FORMS.md exists; not found: a "to fix" mark for long long in README.md, TODO, UPSTREAM-PLAN.md, PORTING.md or OPTIMIZATION-TRICKS.md of facetlang/pdp11/v7unix-toolchain (HEAD 2bbff8c, 2026-10-21); README.md:118 states only that the VAX has long long helpers "which 32V's libc lacks"; status-check/pcc (HEAD 41e5c36) doc/SIZE-NOTES.md:38 describes the 64-bit long long without a mark
- Left: add the "to fix" mark on the v7 side (the decision defers all documentation to the end)

### PCC contributors
- Status: TO DO — a contributor file exists elsewhere but the pcc repo README does not name contributors (latest decision 2026-10-13 \[R48\])
- Decided: 2026-10-13 decided: Name all contributors from commit messages, "most recent contributor first, least recent contributor last" \[R48\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:PCC-CONTRIBUTORS.txt exists (169 lines; header "Newest first, by date of the latest commit"); status-check/pcc (HEAD 41e5c36, 2026-11-07) README.md has no contributors list (grep 'contributors' hit only LICENSE.md boilerplate); pcc-enc:README.md likewise
- Left: the list is not in the pcc repository itself (pcc is a broken worktree link; pcc-enc and pcc-pr remain); completeness of PCC-CONTRIBUTORS.txt not checked: file not read in full

### README
- Status: TO DO — README now says pdp64/32 is the pdp64 and links the manuals, but its appendix list and one build command are stale (latest decision 2026-10-23 \[R307\])
- Decided: 2026-10-23 decided: "fix the readme!!!!" \[R307\]
- Rationale: The pdp-11 and vax-11 "were famous for being pleasant and fun to program in assembly language"; this project updates them "with all the lessons learned in the last 50 years". \[R197\]
- Rationale: Design chosen "to have less possibility for error, fewer footguns, fewer surprises". \[R197\]
- Rationale: Headings may address history, "especially when discussing how this design was conceived and developed from historical precedent". \[R307\]
- Precedent: PDP-11 (chosen; named by author): pleasant, fun assembly language; updated with 50 years of lessons \[R197\]
- Precedent: VAX-11 (chosen; named by author): same: famous for being pleasant to program in assembly \[R197\]
- Precedent: PDP-11 (chosen; named by author): "update and refresh of the pdp-11 instruction set and architecture" \[R187\]
- Evidence: README.md:15 'There is one CPU, and the tools call it \`pdp64\`'; the sentence "still describes r20 only" is gone; README.md:8 links the pdp64/32 manual and book
- Doc differs: README.md:8 appendix list (see Left)
- Left: README.md:8 lists the appendices as "improvements, pending decisions, a glossary, the ABI and the assembly language" and omits the evidence, evolution, proposed, deferred and open-items appendices (the manual has A to J)

### Rules for editing the chapters
- Status: TO DO — details pending: applied to chapters 2 to 6 (errata 111 to 119); not yet to the other chapters (latest decision 2026-11-10 \[errata 115\])
- Decided: 2026-11-10 decided: "remove all ai slop, verify everything, and structure it nicely with good flow"; "make sure each chapter flows from pdp11 to pdp64 with relevant precedents in between"; "where the structure and flow is already good, keep it of course"; "not everything needs a source, just they are nice to have"; "just because you don't have a source, search for sources before removing things" \[errata 115, 111, 113\]
- Evidence: docs/errata.md:268-283 (errata 111 to 119: the edit passes, claims restored with sources); 06-kernel.md has one Lineage paragraph per section (9 uses); 02-bus.md 2.1 route table (PDP-11, VAX, PCI, PCI Express, virtio) and a Chain in each commentary; each of chapters 2 to 6 ends with "What was checked, and what was not"
- Left: the same pass for chapters 1, 7 to 10 and the appendices; the author has not said when

### Standing optimization rules
- Status: TO DO — the rule is decided and followed in the pcc work, but no document states it as a standing rule (latest decision 2026-10-21 \[R143\])
- Decided: 2026-10-21 decided: Standing rule: "always prefer optimizations that benefit multiple backends" \[R143\]
- Rationale and precedent: none stated in the sources
- Evidence: practised: pcc-enc:doc/SIZE-NOTES.md:115 and :140 ("each is an -xdce change in the shared front end, so every target gets it"; "on every target"), :186; not found: the rule or "worst 10" stated as a rule in docs/\*.md, README.md, handoff.md or the pcc-enc docs
- Left: state the rule in the pcc docs (PDP64-OPT.md or SIZE-NOTES.md) and in handoff.md

### Status document as the source of truth
- Status: TO DO — the status document exists and is linked; the docs and manuals do not yet all follow it (latest decision 2026-11-10 \[errata 115\])
- Decided: 2026-11-10 decided: "the whole point of doing the status and decisions document is so we have a source of truth, all docs and manuals must follow it as authoritative" \[errata 115\]
- Evidence: docs/decisions-and-status.md (README.md:50 item 7 links it); docs/decision-log/pdp64-status.md is the rebuilt version; docs/decision-log/docfix-reports/ holds the per-document corrections
- Doc differs: every Doc differs line of the ledger files lists a document that does not yet follow it
- Left: reconcile the docs and manual chapters with the rebuilt status document; publish the rebuilt docs/decisions-and-status.md

## Instruction set: alignment and memory model

### Physical address width and device windows
- Status: TO DO — decided and stated in the manual and the ISA; details pending: how many pages "the first few" are, how software discovers the width, the page-table entry for a 64-bit physical address (latest decision 2026-11-10, errata 102)
- Decided: 2026-11-10 decided: "physical address: minimum 24 bit, up to full 64 bit. mapping can be anywhere except the first few pages where the boot stuff is loaded." then "fine, minimum 40 bits." (errata 102; the 24 of the first message was replaced by 40 the same day); completes 2026-11-09 errata 97, "if we are going to mmap petabytes, we need those bits"
- Evidence: docs/errata.md items 97 and 102; docs/manual-src/02-bus.md:124 "2.3.5 No bit of the physical address selects device space ... the physical address is at least 40 bits and at most 64"; docs/pdp64-isa.md:1127 "The physical address is 40 to 64 bits (errata 102, (D)"; open items J.4.1 (the first few pages), J.6.1 (discovering the implemented widths), J.6.2 (the page-table entry for wide physical addresses) in docs/manual-src/appendix-parts/
- Doc differs: the simulator, QEMU and spec/pdp64-system.hbnf map 40 bits and put the devices from 0x8000000000 (docs/implementation-status.md, chapter 6, 6.6.2 and 6.7.1); the 40-bit width is the minimum, so the rule is met
- Left: details pending: the number of pages kept for the boot code (J.4.1); the register or field that reports the physical width (J.6.1); the page-table entry layout for a page number of 52 bits (J.6.2); devices' placement in the simulator and QEMU

## Instruction set: instruction groups

### Constant-time execution
- Status: TO DO — decided in principle; details pending: the DIT bit is stated in manual 9.3.7 but the core set and the bit's position are open (J.9.2), and nothing is in the ISA text or the simulator (latest decision 2026-11-04 \[R324\])
- Decided: 2026-11-04 decided: Add and div need not take the same time as each other; "only they are timing independent of their data" \[R324\]; 2026-10-22 "there should be constant time flag or something so instructions always take an equal amount of time no matter the input" \[R253\]
- Rationale: "no hammer-row, no spectre, no timing channel attacks"; "for non-sensitive things, constant time isn't a priority" \[R253\]
- Rationale: only that add and div need not match: "only they are timing independent of their data" \[R324\]
- Precedent: Spectre (rejected; named by author): design must not repeat it \[R253\]
- Precedent: Rowhammer (rejected; named by author): written as "hammer-row"; design must not repeat it \[R253\]
- Evidence: docs/manual-src/09-isa.md:101 "9.3.7 A bit DIT in the status word promises data-independent timing" (D), with "Open: the position of the bit ... and which instructions take constant time while it is clear (J.9.2)"; docs/manual-src/appendix-parts/09-open.md J.9.2; not found in docs/pdp64-isa.md, sim64/ or common/ (a search for DIT finds only EDITPC); docs/decisions-pending.md:584 "P17 ... PROPOSED, not decided"
- Doc differs: docs/decisions-pending.md:124 says "proposed: option 3 (a core set always constant-time plus a DIT bit"; docs/pdp64-isa.md has no DIT
- Left: details pending: the core set that is always constant-time (J.9.2 option 2 to 4), the position of DIT (bit 13 proposed), the DIT bit and the fast-path disable in the ISA text, the grammars and the simulator

### Integer abs/min/max and conditional select
- Status: TO DO — decided: aliases in the assembler over a conditional select; details pending: the select and so the expansions are not defined, and the present build still encodes them as native sub-opcodes (latest decision 2026-11-10, errata 98)
- Decided: 2026-11-10 decided: "abs/min/max are aliases, and their entries in the manual show the alias." (errata 98); 2026-10-21 "happy for abs/min/max to be aliases on top of it in the assembler" \[R177\]
- Rationale: "surely other cpus have these opcodes and could benefit from them? who knows how much of an optimization this might bring us" \[R176\]
- Precedent: cmov/csel/fsel (considered; named by author): wants to know more; abs/min/max as assembler aliases on top \[R177\]
- Precedent: ARM csel family (considered; named by assistant, not taken up): select variants nearly free once the first exists \[R178\]
- Evidence: docs/errata.md item 98; docs/pdp64-isa.md:860 "assembler aliases, not native instructions" and :982 AESC sub-opcodes ABS 0x08, MIN 0x10.. ("the present build"); docs/manual-src/09-isa.md:253 "9.7.6 ABS, MIN, MINU, MAX and MAXU are assembler aliases"; spec/pdp64/pdp64.hbnf:153,164 "abs" "min" "max" still sub-opcodes; open item J.9.1 (docs/manual-src/appendix-parts/09-open.md); docs/implementation-status.md "Chapter 9, ABS, MIN, MINU, MAX, MAXU (errata 98)"
- Doc differs: docs/errata.md item 23 says AESC sub-opcodes 0x08 and 0x10-0x13 (native; marked superseded by errata 98); the grammars (spec/pdp64-mnemonics.hbnf, the encoding grammars), as64, sim64, pcc, QEMU and LLVM still treat the five words as native until the expansion is decided
- Left: details pending: define the conditional select (ISA section 12 item 15 keeps it on hold) or choose the expansion over SET, MASKEQZ, MASKNEZ (J.9.1); then change the grammars and tools; the flags of the native words are the behaviour the alias must keep

## toolchain

### \-xdmr flag and default PDP-11 output
- Status: TO DO — details pending: the author said keep it, the clone README says -xdmr gates the size tricks and -O turns it on (latest decision 2026-10-17 \[R67\])
- Decided: 2026-10-17 decided: "keep it": the ungated change to default PDP-11 output stays; push and look at qsort \[R67\]
- Precedent: dmr cc (considered; named by author): asked whether -xdmr output is faster/smaller than the original dmr cc \[R64\]
- Evidence: pcc:cc/cc/cc.c:2003 "-O here has always meant dmr-cc's code"; README.md "which -O turns on for the PDP-11 and AArch64"; commit 777517d "pdp11 (-xdmr): the low word of a long xor ..."
- Doc differs: README.md:168 says "Without -xdmr the generated code differs from stock only through the bug fixes below"
- Left: details pending: which change to default PDP-11 output is ungated is not named by the log; the "faster/smaller than dmr cc" question is answered by doc/SIZE-REPORT.md -3.2%/-4.2%

### Book toolchain, build image and aports
- Status: TO DO — details pending: the rebase is consistent with the ada-on-alpine history but which local changes were dropped is not recorded (latest decision 2026-10-23 \[R305\])
- Decided: 2026-10-23 decided: Drop the local ada-on-alpine changes unless substantively better; then rebase on head and include the new/better stuff. \[R305\]
- Rationale: "you are supposed to use the alpine docker image with hbnf and buildabook installed already NOT go about reimplementing stuff!" \[R285\]
- Rationale: drop local ada-on-alpine changes "unless you did something substantively better" \[R305\]
- Precedent: alpine:edge docker with ada-on-alpine (chosen; named by author): build and install all the aports on it \[R288\]
- Precedent: buildabook (chosen; named by author): replace mkbook.py and push buildabook \[R289\]
- Precedent: mkbook.py (rejected; named by author): reimplementing what buildabook does \[R285\]
- Evidence: packaging repo: status-check/ada-on-alpine (HEAD 77daf37, 2026-11-07) has one linear history by the author (no merges) with 4a4ff58/aa4cc00 of 2026-10-23 "build git HEAD, not releases" and tools/build-hbnf.sh takes its .apk files, consistent with but not proof of the rebase (which local changes were dropped is not recorded); older note: only ada-on-alpine.tgz exists; buildabook commit d78be68 and tools/mkbook.sh (no mkbook.py) show the replacement
- Left: details pending: confirm the rebase and which local changes were dropped

### Gap to gcc -Os on pdp11 and vax
- Status: TO DO — the gap is 8.0% (PDP-11 corpus), 14.7% (VAX), 16.6% on one fair set; target is 5% (latest decision 2026-10-21 \[R142\])
- Decided: 2026-10-21 decided: "take the worst 10% of c files and just use them until they are within the 5%, then do the whole corpus again, and repeat" \[R142\]
- Rationale: "if we get pdp11 and vax to within 5% of gcc -Os we'll consider that good enough" \[R141\]
- Rationale: "you should be testing on a much smaller corpus"; worst 10% of files until within 5%, then whole corpus again \[R142\]
- Rationale: "long long is almost never used by anyone" \[R128\]
- Precedent: gcc -Os (chosen; named by author): target: within 5% of it on pdp11 and vax \[R141\]
- Evidence: pcc:doc/SIZE-REPORT.md:91 "pdp11 ... +8.0%" against gcc; commit 285188d "PDP-11 gap to gcc 16.6%"
- Left: the worst-10% loop to reach 5%

### QEMU and LLVM targets
- Status: TO DO — QEMU is built (it decodes with the table codec of the single encoding); the LLVM back end is only at milestone M1 and frozen on the old encoding, its port or deletion not decided (details pending) (latest decision 2026-10-22 \[R217\])
- Decided: 2026-10-22 decided: "if we build llvm, we'll move over to a machine with more memory". \[R217\]
- Rationale: "if we build llvm, we'll move over to a machine with more memory" \[R217\]
- Precedent: OpenBSD (considered; named by author): "how does openbsd bring up a new architecture?" vs going straight to 3bsd \[R216\]
- Precedent: 3BSD (considered; named by author): premise of his question: going straight to 3bsd \[R216\]
- Precedent: LLVM target sources under llvm/ in pdp64 repo (considered; named by assistant, not taken up): assistant proposal, not a GitHub fork; he answered only about machine \[R217\]
- Precedent: QEMU (chosen; named by author): wants a plan for a qemu backend for the pdp64 \[R151\]
- Evidence: llvm/README.md "Milestone M1 ... There is no code generator yet (llc and clang are later milestones)"; qemu/README.md:3 "qemu-system-pdp64 -M pdp64-virt -kernel prog"; docs/implementation-status.md (1.5.3 QEMU does not yet execute the pdp64/16 and pdp64/32 encodings; chapter 10.4.3 llvm-mc checked against as64 on 62 programs and 6,304 instruction forms)
- Doc differs: handoff.md:6 and :113: the build machine has 3.9 GB RAM, the move to a bigger machine is not recorded
- Doc differs: qemu/README.md:41-51 memory map still has device space behind bit 39 of the physical address (timer 0x8000000000, console 0x8000001000), against errata 97 (no address bit selects device space) and errata 102 (40 to 64 bits); the QEMU walker has three levels only, against errata 96
- Doc differs: the QEMU machine has no virtio device and no PCI Express root complex (docs/implementation-status.md, chapter 5.14), against errata 95 (virtio across the board)
- Doc differs: llvm/README.md (a status note, errata 122): the LLVM back end is frozen; its machine-code layer (about 5,000 lines) encodes the original r20 encoding (parcel 0 = len:2 opc:6 reg:4 low:4, sixteen registers, page 2) throughout, while as64 now produces only the prefix-coded encoding of spec/pdp64/pdp64.hbnf, so llvm-mc and as64 no longer agree, and the checks that compared them (llvm/check.sh, oracle.py, forms.py, negative.py, runsim.py, tools/gen-llvm-td.py) were removed (errata 123 \[R375\]); the body of the README still describes milestone M1 and an oracle that is gone
- Left: LLVM code generator, the larger machine; what becomes of llvm/ (a port to the prefix-coded encoding, or deletion) is not decided (errata 123)

### The four open items
- Status: TO DO — details pending: the four items are not named in the chain (latest decision 2026-10-13 \[R60\])
- Decided: 2026-10-13 approved-proposal: "continue doing those 4 open items in order" \[R60\]
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched the git log of status-check/pcc for a list of open items
- Left: details pending: identify the four items

### aarch64 against clang -Os
- Status: TO DO — aarch64 is still 13% to 20% larger than clang -Os (latest decision 2026-10-18 \[R92\])
- Decided: 2026-10-18 decided: "find out where the remaining 5% comes from" \[R92\]
- Precedent: clang -Os (considered; named by author): asked why pcc is 20% bigger than clang \[R91\]
- Precedent: clang -Os (considered; named by author): asked if -xdmr beats clang -Os on aarch64 \[R89\]
- Evidence: pcc:doc/SIZE-REPORT.md "fork is 17.3% smaller than stock and 13.4% larger than clang -Os; ... 19.5% larger than clang"
- Left: Left: the remaining gap to clang is not closed

### hbnf fixes and upstreaming
- Status: TO DO — details pending: the hbnf fix lives in the hbnf repo and its push is not shown (latest decision 2026-10-21 \[R163\])
- Decided: 2026-10-21 approved-proposal: "yes, push it when the suite passes" (the hbnf single-character-literal fix). \[R163\]
- Rationale: "that's insane, it should work with string literals too! fix hbnf" \[R162\]
- Rationale: "a number is a number, it should handle all number formats" \[R155\]
- Evidence: commits ca4cf63 "hbnf has the numbers change upstream (c99c7cc); drop the local patch"; the hbnf repo status-check/hbnf (main = origin/main, HEAD 5224390, 2026-11-09) has c99c7cc (2026-10-21) "A number is a number: decimal, 0x, 0b and 0o wherever one is taken" but no commit that names the single-character-literal fix
- Left: details pending: which commit is the single-character-literal fix and whether it was pushed

### pcc: the single-pdp64 branch
- Status: TO DO — the branch \`single-pdp64\` of pcc builds only the pdp64 and is pushed (commit 2dbf4f7); pcc master is unchanged (41e5c36, still three targets and \`ccom32\`), so the merge into master is open (details pending; the author decides)
- Decided: 2026-11-10 decided: "remove the code too, tag first" \[R375\]; the pcc side of it is the branch \`single-pdp64\` (errata 123)
- Evidence: pcc origin heads: \`single-pdp64\` 2dbf4f7 "pdp64: drop pdp64-limits.h, which nothing uses", \`master\` 41e5c36; handoff.md:44 and :50 ("the pcc branch \`single-pdp64\` is not merged into pcc's master"); README.md:74 "the pcc branch single-pdp64; -m pdp64"; tools/build-pcc.sh of this repository needs that branch
- Left: details pending: merging \`single-pdp64\` into pcc's master, or keeping it as the pdp64 branch (not decided)

# Left in the air (20)

- Only ideas, open questions, conflicting decisions, or points the record and the repository do not settle.

## 01 Principles and priorities

### C64 in spirit, not the hardware
- Status: IN THE AIR — a principle of the separate newlisp C64-spirit machine; the pdp64 docs neither state nor contradict it (latest decision 2026-06-25 \[R15\])
- Decided: 2026-06-25 decided: "the c64 hardware itself isn't the point"; rejects the C64 keyboard as "shitty"; "the rpi500 keyboard is adequate". \[R15\]
- Rationale: "the c64 hardware itself isn't the point; i don't want to be stuck with that shitty keyboard." \[R15\]
- Precedent: Commodore 64 (rejected; named by author): "the c64 hardware itself isn't the point" \[R15\]
- Precedent: RPi 500 keyboard (chosen; named by author): "adequate" \[R15\]
- Evidence: docs/manual-src/03-graphics.md:5 "its standard video device is virtio-gpu" and the C64 devices are deferred (errata 78); README.md:6 successor of the PDP-11, not of the C64; docs/manual-src/03-graphics.md:396 "\*\*3.16.1\*\*" keeps a C128 core as a c64 mode
- Left: confirm whether this applies to pdp64; other 2026-06-25 records \[R13, R14\] concern the newlisp C64-spirit machine, not pdp64

### Learning from LoongArch
- Status: IN THE AIR — only a potential; nothing adopted by decision (latest 2026-10-20 \[R135\])
- Decided: no standing decision (only potential decisions)
- Precedent: LoongArch64 (considered; named by author): asked how it handles the PC \[R135\]
- Precedent: AArch64 (considered; named by author): asked if LoongArch handles PC the same \[R135\]
- Evidence: docs/manual-update-plan.md:27 lists a planned "9.20 LoongArch" section; no errata entry; the direct-mapping windows (\`DMW0\`, \`DMW1\`, docs/manual-src/06-kernel.md:326 "\*\*6.9.2\*\*", errata 44) are LoongArch's idea and the author said "good thing we already had dmw" (errata 96, \[R361\]), which records that one feature was already in, not a decision to adopt more
- Left: decide what else to adopt from LoongArch, or drop; the author's words are a question ("what can we learn from them and adopt")

## 03 Graphics and the C64 devices

### Audio mixing
- Status: IN THE AIR — a question only (latest 2026-11-10 \[errata 106\])
- Decided: no standing decision (only a question: "what is the audio equivalent, what do those mixers do to combine multiple programs audio?")
- Evidence: docs/manual-src/03-graphics.md:405 "## 3.17 The audio path: samples, mixers and the pdp64", :445 "Open: where the pdp64's mixer lives ... (J.3.13)"; docs/errata.md:258 entry 106 item (3): virtio-snd says nothing about who mixes several programs and the pdp64 has no host
- Left: where the mixer lives (kernel, library or device) and who drives it (J.3.13); the author stated no preference for audio

### C64 console (c64x), the earlier SDL console
- Status: IN THE AIR — a separate pre-pdp64 project (newlisp/SDL console); not a pdp64 design item (latest decision 2026-06-18 \[R11\])
- Decided: 2026-06-18 decided: Goal: a terminal interface on all major platforms that also runs unix tty programs "while being as sweet and usable as the C64", with newlisp as driver. \[R11\]
- Rationale: a terminal interface that runs unix tty programs "while being as sweet and usable as the C64", with "the nice stuff of newlisp as the driver". \[R11\]
- Precedent: Commodore 64 (chosen; named by author): "as sweet and usable as the C64" \[R11\]
- Precedent: newLISP (chosen; named by author): as driver of the console \[R11\]
- Precedent: MS-DOS console font (considered; named by author): font "reminiscent of the old Commodore 64 font, or the old MSDOS console font" \[R1\]
- Evidence: docs/c64-devices-from-chat.md:123 "## 6. The c64x terminal chat (2026-06-18)" records the chat as history (per-cell colours, peek and poke, the newLISP-style cell) and no pdp64 document makes it a requirement; the records are 2025-07-23 \[R1\], 2025-09-22 \[R2, R3\], 2026-05-13 \[R6\], 2026-06-18 \[R7, R8, R9, R10\]
- Left: lives in another repository; if it is meant to be the terminal for pdp64, say so

### C64 console font and 9p interface
- Status: IN THE AIR — "9p all the way" decided for the console, "9p server" and font-query protocol are potentials, all outside this repository (latest decision 2026-06-18 \[R9\])
- Decided: 2026-06-18 decided: "9p means 9p all the way. no mix and match." \[R9\]
- Rationale: "9p means 9p all the way. no mix and match. it works or it doesn't." \[R9\]
- Precedent: 9P (chosen; named by author): "9p all the way"; also a 9p server for window info \[R8\] \[R9\]
- Precedent: kitty (considered; named by author): c64x is much the same "but with peek/poke instead of byte stream" \[R8\]
- Precedent: xterm-256color subset shim (chosen; named by author): "we'll have a shim that implements xterm-256color subset" \[R8\]
- Precedent: vsock (considered; named by assistant, not taken up): he "didn't understand" the vsock question \[R9\]
- Evidence: docs/c64-devices-from-chat.md:128 "the 9p tree is \\"JUST a representation of underlying newlisp reality\\"" and :51 (the c64x 9p interface) record it as chat history; not found: a 9p or font-query decision in the manual or errata; related potentials \[R8\] and \[R5\]
- Left: same repository question as the C64 console

### SID chip variants
- Status: IN THE AIR — a question only (latest 2025-09-22 \[R4\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/c64-devices-from-chat.md:81 discusses the SID-64X revisions, not which original SID variant; the manual body no longer names the SID (errata 120); not found: an answer to which variant was most common
- Left: author's question about the SID models is unanswered in the docs

### The mashup of GPU, video memory, C64 and Blit
- Status: IN THE AIR — the author said it is still being worked out (latest 2026-11-10 \[errata 105\])
- Decided: no standing decision (his words: "we're still figuring it out, what would a mashup of gpu, vram, c64 and blit look like.")
- Evidence: docs/manual-src/03-graphics.md:187 "Open: how text, pixels and sprites are composed on the display ... (J.3.3)"; docs/errata.md:256 entry 105 item (6): four sketches, all tagged (P), none decided
- Left: which sketch or combination (J.3.3)

### Velinsky link between C64 and DEC
- Status: IN THE AIR — only the author's hypothesis, recorded as such (latest 2026-11-08 \[R357\])
- Decided: no standing decision (only potential decisions)
- Rationale: "velinsky shows interchange of personelle between dec and commodore"; "similarity too great to be chance" \[R357\]
- Rationale: "no design carried over is false given all the commonalities we found between the c64 and the pdp11" \[R356\]
- Precedent: Velinsky (DEC Rainbow and Commodore designer) (considered; named by assistant, accepted): common designer as link between DEC and Commodore \[R355\]
- Precedent: C64 and PDP-11 similarities (considered; named by author): commonalities found, cited as evidence \[R356\]
- Evidence: commits c85387f and 5b2837c "Velinsky link recorded as prediction, confirmation and the author's hypothesis (P) with the evidence still wanted"; docs/c64-devices-from-chat.md:146 section 8; docs/manual-src/appendix-parts/01-proposed.md:1 "\*\*1.1.5\*\* (moved from chapter 1, from the commentary of 1.1) \*(P)\* A thread between the two lineages"
- Left: the evidence still wanted, as the docs themselves say

## 06 Kernel, modes and memory management

### Realtime V7 with QNX ideas
- Status: IN THE AIR — only a potential (latest 2026-08-29 \[R21\])
- Decided: no standing decision (only potential decisions)
- Precedent: QNX/QUNIX (considered; named by author): fold its design decisions into V7 for realtime guarantees \[R21\]
- Precedent: V7 Unix (chosen; named by author): "assume v7 source code as the base" \[R21\]
- Evidence: not found: searched docs/\*.md and docs/manual-src for a QNX or realtime-kernel decision; qnx appears only in docs/c64-devices-from-chat.md; first OS is OpenBSD (errata 41)
- Left: probably dropped by the OpenBSD decision; the author has not said so

### mmap devices (Multics idea)
- Status: IN THE AIR — only a question (latest 2026-06-19 \[R12\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:209 entry 59 adopts memory-mapped devices for vectors and graphics, but not Multics as a basis; docs/c64-devices-from-chat.md:131 records the Multics chat of 2026-06-19 ("devices as memory-mapped regions, peek and poke ... \`mmap\` as the primary I/O"); not found: a Multics decision
- Left: author has not decided on Multics

## 07 Multiple processors

### CPU in DRAM
- Status: IN THE AIR — only a question (latest 2026-10-20 \[R140\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/\*.md for a CPU-in-DRAM design; only passing mentions in docs/kernel-pain-points.md
- Left: author has not decided

## 11 Toolchain

### newlisp environment
- Status: IN THE AIR — design of a separate newlisp front end, outside this repository (latest decision 2026-06-25 \[R16\])
- Decided: 2026-06-25 decided: "list" gives a code browser showing all contexts and their contents, in a "very nice c64 TUI mode"; incorporates some of vim and smalltalk. \[R16\]
- Rationale: environment made "more c64 like" with "tcl and smalltalk idioms"; bare function name at line start, "mccarthy would be happy". \[R16\]
- Precedent: newLISP (chosen; named by author): "we'll be newlisp" \[R16\]
- Precedent: original Lisp (chosen; named by author): bare function name at beginning of a line \[R16\]
- Precedent: Tcl (chosen; named by author): some idioms incorporated \[R16\]
- Precedent: Smalltalk (chosen; named by author): idioms and code browser, but showing all contexts \[R16\]
- Precedent: vim (chosen; named by author): "incorporate some of vim" into the environment \[R16\]
- Evidence: not found: searched pdp64 docs, tools/ and README.md for newlisp; other record \[R16\]
- Left: lives in another project

## 12 Documentation and process

### Grant evaluation
- Status: IN THE AIR — only a request to evaluate (latest 2026-10-23 \[R287\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: not found: searched docs/ and README.md for darpa or grant

### Wrapping for pdp64 and papers
- Status: IN THE AIR — a question and an expectation about wrapping Markdown for Pages (latest 2026-11-06 \[R353\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: the referent is the Jekyll and Liquid wrapping of Markdown for GitHub Pages in the same session (\[R353\] is followed by "the md files that buildabook processes are NOT meant to be processed by liquid" \[R354\]); docs/roadmap.md:1 and :117 carry a \`{% raw %}\` wrapper; the author's words about pdp64 and papers are an expectation ("I'd expect not much"), not a decision
- Left: whether pdp64 needs more wrapping than the raw comment of docs/roadmap.md, in the author's words

## Documentation and process

### Other
- Status: IN THE AIR — no standing decision, only an unclear record (latest decision 2026-10-23 \[R298\])
- Decided: Now: no standing decision (only unclear or rejected records)
- Rationale and precedent: none stated in the sources
- Evidence: not checked: the text to be placed is not visible in the record
- Left: unclear record R298 cannot be placed

## Instruction set: alignment and memory model

### Stack alignment
- Status: IN THE AIR — a question only; the ABI keeps 8, and the open item is J.D.1 (latest decision 2026-10-21 \[R154\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/abi.md:10 and docs/manual-src/appendix-d-abi.md:13 "the stack pointer is a multiple of 8 at all times"; docs/manual-src/appendix-parts/d-open.md J.D.1 "Stack alignment" (the author's question, six options, the assistant's analysis)
- Doc differs: docs/abi.md:10 and appendix D (D.1) say multiple of 8, not 2
- Left: the author asked "why not 2 bytes instead of 8?" and no ruling is recorded; J.D.1 lays out the options (8, 2, 4, 16) for him

## Instruction set: encoding

### Combining group opcodes
- Status: IN THE AIR — only a potential idea; the repository keeps the groups separate (latest decision 2026-11-04 \[R327\])
- Decided: no standing decision (only potential decisions)
- Rationale: combining sop and sys covers all their sub-instructions, "which means 39 instructions reduce to 1" \[R327\]
- Evidence: spec/pdp64/pdp64.hbnf catalogue still has separate leaf-SYS0, leaf-SYSR, leaf-SYSI, leaf-SOPR forms; docs/encoding-proposal.md:87 lists SYS0 (36) and others as separate groups
- Left: no record of a decision to merge sop and sys; nothing implemented

### Opcode field and parcel layout (6-bit opcode)
- Status: IN THE AIR — only potential ideas; the decided pdp64/32 uses a variable prefix, not a fixed 6-bit opcode (latest decision 2026-11-04 \[R325\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: spec/pdp64/pdp64.hbnf:1 "207 forms, 268 leaves" (prefix-coded leaves); docs/encoding-proposal.md:27 "Prefix at the top of parcel 0 (1 to 16 bits)"; the 6-bit opcode field (opc:6) is the r20 layout only (spec/README.md:9)
- Doc differs: docs/encoding-proposal.md:27 prefix of 1 to 16 bits, not opcode(6)
- Left: the chain records no ruling on the 6-bit opcode design (only potential ideas); pdp64/32, the decided architecture, uses a prefix code instead (errata 94), so the idea is moot unless the author says otherwise

## Instruction set: instruction groups

### Memory-to-memory moves and block operations
- Status: IN THE AIR — only potential ideas in the chain, but the ISA already has MCPY, MMOV and MSET (latest decision 2026-10-20 \[R135\])
- Decided: no standing decision (only potential decisions)
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:631 "MCPY Rd, Rs, Rn"; :632 MMOV; :633 "MSET"; :657 "MSET with Rv = 0 is the range-zeroing instruction"
- Left: no decision records the block-move instructions; plain memory-to-memory mov (the first idea) is not in the ISA

### UTF-8 operations
- Status: IN THE AIR — only a potential idea in the chain, but the ISA already has UTF8LEN/DEC/ENC and MVAL (latest decision 2026-10-20 \[R137\])
- Decided: no standing decision (only potential decisions)
- Rationale: "if utf8 is already 3 or 4 parcels, it's ok"; "validating an entire utf8 string sounds nice" \[R137\]
- Evidence: docs/pdp64-isa.md:552 "4.6.1 UTF-8" (UTF8LEN, UTF8DEC, UTF8ENC); :659 "4.7.1 MVAL" (MVAL Rd, Rn validate Rn bytes as UTF-8); handoff.md:137 lists UTF-8 instructions and MVAL as known gaps (not in the executor)
- Left: no recorded decision; whole-string validation exists in the spec (MVAL) but handoff.md:137 says it is not implemented in the tools

# Rejected or replaced (8)

- Rejected, reversed, or replaced by a later decision (the later one has precedence).

## 01 Principles and priorities

### C64 keyboard
- Status: REJECTED — the original C64 keyboard is refused (latest decision 2026-06-25 \[R15\])
- Decided: 2026-06-25 rejected: Rejects the original C64 keyboard: "i don't want to be stuck with that shitty keyboard". \[R15\]
- Rationale: "i don't want to be stuck with that shitty keyboard." \[R15\]
- Precedent: Commodore 64 (rejected; named by author): "shitty keyboard" \[R15\]
- Precedent: RPi 500 keyboard (chosen; named by author): "the rpi500 keyboard is adequate" \[R15\]
- Evidence: not found: searched pdp64 docs for the C64 keyboard as a requirement; the repository does not carry it (not stale)

## Documentation and process

### Manual location and split
- Status: REJECTED — the three manuals of a family are replaced by one manual of the pdp64 (latest decision 2026-11-10 \[R374\], errata 122)
- Decided: 2026-11-10 decided: "r20 and pdp64/16 are gone, there is no family pdp64/32 is the decided upon pdp64" \[R370\]; "r20 and 64/16 are gone as cpus with manuals etc" \[R374\]; supersedes the approved-proposal of 2026-11-05: "docs/manual/ becomes a landing page; manuals in pdp64-r20, pdp64-16, pdp64-32 subfolders (Recommended)" \[R344\]
- Rationale: "are separate manuals because they are different cpus" \[R343\]
- Evidence: docs/manual/00-index.md is the one manual (it was docs/manual/pdp64-32/); docs/manual/pdp64-r20 and pdp64-16 and book/pdp64-{r20,16}.pdf are removed; README.md:8 and :15; docs/errata.md items 122 and 123

## Instruction set: alignment and memory model

### R7 as a view of the PC
- Status: REJECTED — R7 is an ordinary general register, not a view of the PC; ISA 9.3 and manual 9.3.2 state it (latest decision 2026-11-10, errata 100)
- Decided: not in force (rejected 2026-11-10): "r7 is not a view of the pc" (errata 100, answering the open question about R7)
- Precedent: PDP-11 (considered; named by author): asked whether R7 was the PC on PDP-11 and about a read-only view \[R135\]
- Precedent: LoongArch64 / AArch64 (considered; named by author): asked how they handle the PC \[R135\]
- Evidence: docs/errata.md item 100; docs/pdp64-isa.md:1333 "9.3 The PC is not a register, and R7 is not a read-only view of it"; docs/manual-src/09-isa.md:87 "9.3.2 The program counter is not a general register, and R7 is an ordinary general register"; repository not stale

## Instruction set: encoding

### Prefix-coded encodings, 16-register and 32-register grammars
- Status: REJECTED — the two-grammar split was cancelled by the 32-register-only decision, and the 16-register grammar and its tests were removed (latest decision 2026-11-09 \[R365\]; done 2026-11-10, errata 123 \[R375\])
- Decided: not in force (reversed 2026-11-09): the two-grammar split of 16 and 32 registers was cancelled by R365 (see Register count) and by errata 94 (pdp64/32 is the pdp64); 2026-11-10 "remove the code too, tag first" \[R375\]
- Rationale: goal for the encoding: "minimizes code size and fits them all in with 32 reg and with 16 reg" \[R328\]
- Precedent: RISC-V (considered; named by author): faulted for no comparison of opcode counts or bit layouts with pdp64 \[R365\]
- Evidence: later decision 2026-11-09 \[R365\]; docs/errata.md items 94, 122 and 123; spec/ now holds one grammar, spec/pdp64/pdp64.hbnf (spec/README.md:3 "The pdp64 has one CPU"); spec/pdp64-16/ is gone (git tag \`pre-code-removal\`)

## Instruction set: instruction groups

### CRC instructions
- Status: REJECTED — CRC32/CRC32C withdrawn in favour of carry-less multiply; the repository agrees (latest decision 2026-10-21 \[R175\])
- Decided: not in force (rejected 2026-10-21): "we have carryless mul no need for either crc". \[R175\]
- Rationale: "we have carryless mul no need for either crc" \[R175\]
- Precedent: carry-less multiply (chosen; named by author): replaces both CRC variants \[R175\]
- Evidence: docs/pdp64-isa.md:600 "There are no CRC32 or CRC32C instructions"; docs/errata.md item 20; repository not stale

### Opcode usage, instruction count and pruning
- Status: REJECTED — cutting to about 70 instructions was rejected; the repository does not cut (latest decision 2026-10-21 \[R172\])
- Decided: 2026-10-21 rejected: Rejects cutting the instruction set to about 70: "no, we beat the ppc601 we're doing good". \[R172\]
- Rationale: "no, we beat the ppc601 we're doing good" \[R172\]
- Rationale: "a rarely used instruction can still pull its weight if its used inside a critical tight hot loop" \[R296\]
- Rationale: wants usage counts "so if we need to restructure, we can" \[R171\]
- Precedent: PowerPC 601 (considered; named by author): cited as the measure pdp64 already beats; against cutting to about 70 \[R172\]
- Evidence: docs/errata.md item 68 (instructions judged by hot-loop weight); docs/pdp64-isa.md:30 the hot-loop standing constraint; spec/pdp64/pdp64.hbnf keeps 207 forms; repository not stale

### Resume-mov opcode
- Status: REJECTED — single move with progress in registers, no resume opcode; the repository agrees (latest decision 2026-11-09 \[R362\])
- Decided: not in force (rejected 2026-11-09): "good" to keeping the single move instruction with progress in registers and no resume opcode. \[R362\]
- Rationale: accepted from the assistant ("good"): a separate resummov would multiply entities without benefit and need a different instruction after a fault \[R362\]
- Precedent: virtio (considered; named by assistant, accepted): progress lives in memory rings; same principle as progress in registers \[R362\]
- Evidence: docs/pdp64-isa.md:1250 "An MBLK instruction is interruptible. At every point ... Rd, Rs/Rv and Rn hold state consistent with byte-at-a-time progress"; repository not stale

## Instruction set: registers

### Register names (r16)
- Status: REJECTED — replaced by the 32-register pdp64 where r16-r31 are defined (latest decision 2026-11-09 \[R365\]; one CPU since 2026-11-10, errata 122 \[R374\])
- Decided: 2026-10-21 decided: "r16 should be an assembler error. only r0 .. r15 are defined, plus aliases" \[R170\]
- Rationale and precedent: none stated in the sources
- Evidence: spec/pdp64/pdp64.hbnf regs list r0..r31; later decision 2026-11-09 \[R365\]; docs/errata.md item 94 (r0-r31); stale: docs/pdp64-isa.md:80 "Sixteen registers, R0-R15" (the r20 text, declared at :7)
- Doc differs: docs/pdp64-isa.md:80 says "Sixteen registers"; its header (:7) says the register file below is that of pdp64/r20

# Done (164)

- Implemented in the current code or stated in the current docs, with the evidence.

## 01 Principles and priorities

### Architecture scope includes the bus
- Status: DONE — the bus has its own chapter and document (latest decision 2026-10-22 \[R201\])
- Decided: 2026-10-22 decided: "even the bus design is an important part of the architecture not just the instruction set". \[R201\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/02-bus.md (chapter 2, rewritten by errata 103); docs/pdp64-q64-bus.md section 1 "Why the bus is part of the architecture"; README.md:38 "The bus is PCI Express, backward compatible, with security and convenience circuitry added"

### CPU vulnerability avoidance
- Status: DONE — documented (latest decision 2026-10-22 \[R253\])
- Decided: 2026-10-22 decided: "all the cpu bugs that needed mitigations" documented "so we don't repeat them"; "no hammer-row, no spectre, no timing channel attacks" \[R253\]
- Rationale: document all the CPU bugs needing mitigations "so we don't repeat them" \[R253\]
- Precedent: Rowhammer (rejected; named by author): "no hammer-row" \[R253\]
- Precedent: Spectre (rejected; named by author): "no spectre" \[R253\]
- Precedent: timing channel attacks (rejected; named by author): wants a constant-time flag so instructions take equal time \[R253\]
- Evidence: docs/hardware-vulnerabilities.md (Rowhammer, Spectre, Hertzbleed in section 12); docs/openbsd-mitigations.md

### Design philosophy and optimization layers
- Status: DONE — the layers and the hindsight point are in the principles and the introduction commentary (latest decision 2026-10-23 \[R272\])
- Decided: 2026-10-23 decided: "in hindsight" the design is "even more minimal than the vax and pdp11"; hindsight shows "which theoretical completeness we could trade for more power" \[R272\]
- Rationale: the design was chosen "to have less possibility for error, fewer footguns, fewer surprises"; code size reduced at every level, instructions with "the most bang for buck" \[R197\]
- Rationale: hindsight showed "which theoretical completeness we could trade for more power" \[R272\]
- Rationale: "my top priorities are code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[R243\]
- Rationale: "fewer possible errors means less recovery code. easier recovery path means less recovery code." \[R244\]
- Precedent: PDP-11 and VAX-11 (chosen; named by author): famous for being pleasant and fun to program in assembly; project updates them \[R197\]
- Precedent: VAX and PDP-11 (minimality) (considered; named by author): pdp64 is "even more minimal" in hindsight \[R272\]
- Evidence: docs/manual-src/01-introduction.md:39 "\*\*1.3.1\*\* In several ways the pdp64 is more minimal than the PDP-11 and the VAX-11: it gives up theoretical completeness where fifty years of use showed the completeness was never exercised"; :55 commentary on the PDP-11/VAX completeness; :59 section 1.4 priorities; :67 "\*\*1.4.5\*\* An instruction is judged by its weight in the loops where it is used"
- Left: the 2026-11-04 potential on -xssa (a larger instruction in a tight loop) is open, not recorded as a decision

### Design priority list
- Status: DONE — the definitive list replaced the old one (latest decision 2026-11-04 \[R323\])
- Decided: 2026-11-04 decided: "recovery and restart go together". \[R323\]
- Rationale: "my top priorities are code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[R243\]
- Rationale: "4 and 5 are essentially the same thing. recovery and restart go together." \[R323\]
- Evidence: docs/manual-src/01-introduction.md:59 "\*\*1.4.1\*\* ... restart and recovery go together"; docs/errata.md:233 entry 83; docs/priority-lists.md:118 "The definitive list"
- Doc differs: docs/priority-lists.md:120 still says "(For you to write. ...)" above the author's annotations

### Efficiency order for PIE
- Status: DONE — the order and the entity rule are in the manual (latest decision 2026-10-21 \[R145\])
- Decided: 2026-10-21 changed: Same order, adding "don't increase transistor count too much ockam. don't multiply entities without benefit" \[R145\]
- Rationale: efficient in this order: "no wierd side effects, no bumping other opcodes in a way that makes code size increase" \[R145\]
- Rationale: "don't increase transistor count too much ockam. don't multiply entities without benefit" \[R145\]
- Precedent: Ockham ("ockam") (chosen; named by author): entity-multiplication rule \[R145\]
- Evidence: docs/manual-src/01-introduction.md:63 "\*\*1.4.3\*\* ... Beside the ranking, at every level, do not multiply entities without benefit"

### In-order and out-of-order design
- Status: DONE — stated in the manual and errata (latest decision 2026-10-23 \[R297\])
- Decided: 2026-10-23 decided: The official docs must also say "designed to be efficient with in-order and out-of-order execution implementations". \[R297\]
- Rationale: "although the first implementations will be in-order, we have to make the decision safe for out of order implementations" \[R295\]
- Evidence: docs/manual-src/01-introduction.md:65 "\*\*1.4.4\*\* The architecture is designed to be efficient with in-order and out-of-order implementations"; README.md:13 "designed to be efficient with in-order and out-of-order implementations"; docs/errata.md:174,218 entries 38, 68

### Keeping only part of the PDP-11 instruction set
- Status: DONE — instructions have been dropped (latest decision 2026-10-20 \[R138\])
- Decided: 2026-10-20 decided: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[R138\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[R138\]
- Precedent: PDP-11 (chosen; named by author): kept in part; unneeded instructions dropped \[R138\]
- Precedent: ror over rol (chosen; named by author): accepted the case for ror \[R138\]
- Evidence: docs/errata.md:48 "16. \*\*DECISION: \`FRECPED\` and \`FRSQRTED\` dropped.\*\*"; docs/errata.md:121 entry 31 removes the fourth parcel

### MMU and FP units included
- Status: DONE — MMU and floating point are in the base architecture (latest decision 2026-08-30 \[R26\])
- Decided: 2026-08-30 decided: "fp and mmu would be included by default" \[R26\]
- Precedent: M8502 and x86 (chosen; named by author): adopt what is needed from them, low transistor count \[R26\]
- Precedent: Strecker VAX-11/780 paper (considered; named by assistant, not taken up): DEC considered extending the PDP-11 and gave reasons against \[R26\]
- Evidence: docs/manual-src/06-kernel.md:198 "\`MMUCTL\` ... memory-management control (bit 0 enables translation)"; docs/manual-src/01-introduction.md:51 "\*\*1.3.7\*\* ... no separate floating-point register file" (FP shares the general registers); docs/manual-src/08-vectors.md:51 "\*\*8.5.1\*\* The processor handles \`binary64\`, \`binary32\` and \`binary16\` as scalar floating point"

### Mashup of PDP-11 with C64 / M8502
- Status: DONE — the pdp64 is the PDP-11 widened, with the C64 as a device and an 8502 island, not two chips side by side (latest decision 2026-08-29 \[R23\])
- Decided: 2026-08-29 changed: Mashup means "not necessarily two chips operating simultaneously, but taking the best isa/architecture and improving it with the good stuff of the other one" \[R23\]
- Rationale: "taking the best isa/architecture and improving it with the good stuff of the other one" \[R23\]
- Rationale: "i think c64 is superior to blit terminal in many ways" \[R20\]
- Rationale: m8502 and PDP-11 "seem much closer to each other" \[R22\]
- Precedent: PDP-11 (chosen; named by author): "use pdp-11 as the base" \[R19\]
- Precedent: m8502 (chosen; named by author): "we should mash that up instead of the c64" \[R22\]
- Precedent: SID (chosen; named by author): fold in the good parts of the C64 \[R20\]
- Precedent: Blit (considered; named by author): C64 judged superior; could the Blit be made C64-adjacent \[R20\]
- Precedent: QNX/QUNIX (considered; named by author): fold design decisions into V7 for realtime guarantees \[R21\]
- Evidence: README.md:6 "A 64-bit successor to the PDP-11 instruction set and architecture."; docs/c64-devices-from-chat.md:109 "A soft 8502 (not a socketed 6510)"; docs/manual-src/03-graphics.md:173 "\*\*3.8.1\*\* The graphics terminal is based on two machines, not one"; :402 "\*\*3.16.4\*\* The Commodore 128 is another device on the PCI Express bus"
- Doc differs: none found

### Mode bits and the "no mode bits" rule
- Status: DONE — the rule is dropped and the freebie is stated (latest decision 2026-11-04 \[R323\])
- Decided: 2026-11-04 decided: Modes in bits that are saved anyway are "a freebie. no brainer". \[R323\]
- Rationale: mode bits in bits saved anyway: "a freebie. no brainer."; modes "should be visible, not hidden state" \[R323\]
- Rationale: "the no mode bits rule is a very soft rule"; "where mode bits outweigh the costs, we take them" \[R241\]
- Precedent: PDP-11 SR0 / VAX MAPEN (considered; named by assistant, not taken up): translation on/off switch, called the heritage choice by the assistant \[R241\]
- Evidence: docs/manual-src/01-introduction.md:63 "\*\*1.4.3\*\* ... Mode bits are decided case by case: by default a mode is visible state, and a bit in a register that is saved anyway costs nothing extra"; docs/errata.md:233 entry 83 "the 'no mode bits' rule is dropped"

### Optimizer placement (optim2.c)
- Status: DONE — machine-independent optimizations live in mip/optim2.c and serve every back end (latest decision 2026-10-17 \[R66\])
- Decided: 2026-10-17 decided: "i love putting whatever possible into optim2.c for benefitt across all arches" \[R66\]
- Rationale: "for benefitt across all arches" \[R66\]
- Precedent: optim2.c (chosen; named by author): put whatever possible there \[R66\]
- Evidence: pcc clone status-check/pcc (HEAD 41e5c36): doc/PDP64-OPT.md:50 "\`-xccp\` ... (\`mip/optim2.c\` \`ccp\`, written in this phase)", :120 "c2's jump optimizer ... (\`deljumps\`, \`mip/optim2.c\`) ... MI", :162 "Machine-independent changes made in this phase: \`ccp\` (\`mip/optim2.c\`)", :146 \`bic\` for \`x & ~y\` ("\`AND\` made \`~R & L\` in \`optim2\`"); mip/optim2.c exists

### Project goal and deliverables
- Status: DONE — recorded as decisions and the manual is built (latest decision 2026-10-23 \[R267\])
- Decided: 2026-10-23 decided: "the manual for the arch (not only the isa) is the primary deliverable, but the as/ld/cc/emu are also important." \[R267\]
- Rationale: "the important part is the design and docs is most important, the as/ld/cc/emu parts are advanced as needed to do the docs" \[R266\]
- Precedent: LLVM (chosen; named by author): final goal includes assembler, linker, compiler backend (llvm), emulator \[R265\]
- Precedent: OpenBSD (chosen; named by author): port of openbsd we can ssh into \[R265\]
- Evidence: docs/errata.md:202-204 entries 52, 53, 54; docs/manual/ and book/ PDFs (commit c48e8c0 "the three manuals as PDFs")

### Soft rules and principle exceptions
- Status: DONE — stated as a principle and recorded (latest decision 2026-10-22 \[R242\])
- Decided: 2026-10-22 decided: "all the rules are soft rules." \[R242\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/01-introduction.md:61 "\*\*1.4.2\*\* All the rules are soft rules: a rule gives way when breaking it is worth more than it costs"; docs/errata.md:191 entry 42

### The pdp64 family
- Status: DONE — there is no family: pdp64/32 is the pdp64, the only CPU; r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and as code (latest decision 2026-11-10 \[R374, R375\])
- Decided: 2026-11-10 changed: "r20 and pdp64/16 are gone, there is no family"; "pdp64/32 is the decided upon pdp64" \[R370\]; earlier, 2026-11-09: "only the 32 register pdp64 is official, the other two are cancelled." \[R365\]; then "r20 and 64/16 are gone as cpus with manuals etc; they are previous iterations that were superseded by 64/32 which is now the official pdp64" \[R374\]; "remove the code too, tag first" \[R375\]
- Rationale and precedent: none stated in the sources
- Evidence: README.md:15 "There is one CPU, and the tools call it \`pdp64\`"; spec/README.md:3 "The pdp64 has one CPU"; docs/manual-src/01-introduction.md:119 "\*\*1.8.1\*\* The pdp64 has thirty-two registers ...", :121 "\*\*1.8.2\*\* Two earlier iterations were built and measured against it and were superseded"; docs/errata.md items 122 and 123 (items 87, 93 and 94 are marked superseded); the manual is docs/manual/ (one manual) and the book is book/pdp64.pdf
- Left: nothing

### Widening the PDP-11 to 64 bits
- Status: DONE — the architecture is a 64-bit PDP-11 successor with 32-bit forms (latest decision 2026-08-30 \[R30\])
- Decided: 2026-08-30 decided: "basically upgrade pdp-11 straight to 64 bit" \[R30\]
- Rationale: keeping "some of its nice properties" while adopting from m8502 and x86 "to keep transistor count down while still being reasonably nice to program in assembler" \[R26\]
- Precedent: VAX-11 (considered; named by assistant, not taken up): widened PDP-11 pleasant to write and target \[R26\]
- Precedent: M8502 and x86 (chosen; named by author): sources for what the widened PDP-11 needs \[R26\]
- Evidence: docs/manual-src/01-introduction.md:5 "The pdp64 is a 64-bit successor to the PDP-11"; docs/manual-src/01-introduction.md:33 "\*\*1.2.7\*\* The VAX-11 widened the PDP-11 to 32 bits"

### Work-order priorities (what to do next)
- Status: DONE — the back end is started (the LLVM machine-code layer; no code generator yet), and the instruction counts are measured on the pcc compiler's output (latest decision 2026-10-21 \[R169\])
- Decided: 2026-10-21 decided: "before we do the emulator i want the backend started so i can start looking at instruction counts." \[R169\]
- Rationale: "so i can start looking at instruction counts" \[R169\]
- Evidence: llvm/README.md "Milestone M1 (this directory): the machine-code layer ... There is no code generator yet"; README.md:86 "the six large programs execute 19% and 24% fewer instructions" (the compiler is pcc); README.md:87 "LLVM back end: the machine-code layer ...; no code generator yet"; qemu/ and sim64/ exist
- Left: the LLVM code generator (\`llc\`, \`clang\`) is a later milestone; the "once the bugs on powerpc are fixed" line is an unclear referent and needs no action here

## 02 Bus

### Bus enumeration and attached buses
- Status: DONE — enumeration is PCI Express's own, and arbitrary buses attach behind bridges (latest decision 2026-10-23 \[R292\])
- Decided: 2026-10-23 decided: "just as usb is unuerated over a pcie bus, our q64 bus will allow arbitrary buses to be connected to it and enumerated" \[R292\]
- Precedent: USB enumerated over PCIe (chosen; named by author): model for q64 enumerating arbitrary attached buses \[R292\]
- Evidence: docs/errata.md:199,217 entries 49 (eight registers superseded by 95), 67; docs/manual-src/02-bus.md:204 "\*\*2.4.1\*\* The processor finds the devices by PCI Express enumeration", :208 "\*\*2.4.3\*\* A function may itself be a bus ... any bus can be attached to the bus and its devices enumerated, to any depth"
- Left: where the configuration space and the windows sit in the physical address space is open (J.2.1); the bus controller as a device (errata 49) is open under virtio (J.2.2)

### Bus hotplug
- Status: DONE — arrival and departure raise an interrupt and the kernel rescans (latest decision 2026-10-22 \[R258\])
- Decided: 2026-10-22 decided: "we do need some way for the bus to alert us when a device enters or leaves the bus" \[R258\]; 2026-10-22 asked and stated: "when a device leaves, the queued up stuff is left in memory so it can be read, saved, resent?" \[R262\], placed in the manual as decided with details to be determined \[errata 121\]
- Rationale: queued work of a departed device left in memory "so it can be read, saved, resent" \[R262\]
- Evidence: docs/manual-src/02-bus.md:210 "\*\*2.4.4\*\* The bus alerts the processor when a device enters or leaves, by an interrupt; the kernel then rescans the bus"; :214 "\*\*2.4.5\*\* The queued work of a departed device stays in memory untouched ... \*(D)\* Details to be determined."
- Left: the mechanism of the alert and its report for a device behind a bridge (J.2.2); the resend-after-departure rules (2.4.5, J.5.4)

### Bus update to virtio-only
- Status: DONE — chapter 2 is rewritten for PCI Express and virtio (latest decision 2026-11-09 \[R360\])
- Decided: 2026-11-09 approved-proposal: "i like all your recommendations, go ahead and update the bus chapter." \[R360\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[R360\]
- Precedent: native 8-register devices (rejected; named by author): "gone" \[R360\]
- Evidence: docs/manual-src/02-bus.md:5 "every standard device is a virtio device (the disk is virtio-blk) or a USB controller"; :206 "\*\*2.4.2\*\* A function is a virtio device when its configuration space says so"; docs/errata.md:245 entry 95, :254 entry 103 (the rewrite); docs/errata.md:107 entry 29, :199 entry 49 and :211 entry 61 marked superseded by 95
- Doc differs: docs/decisions-pending.md:659 row Q10 and :908 "Q10. Devices are eight memory-mapped registers plus DMA" are not marked superseded; docs/c64-devices-from-chat.md:62 and docs/CHANGES-SINCE-R20.md:754 still say eight registers
- Left: the open items of the rewritten chapter are J.2.1 to J.2.5

### Physical address bit that selects device space
- Status: DONE — no physical-address bit selects device space (latest decision 2026-11-09 \[R360\])
- Decided: 2026-11-09 decided: "the whole bit 39 decides if memory or dma should go away"; "if we are going to mmap petabytes, we need those bits." \[R360\]
- Rationale: "if we are going to mmap petabytes, we need those bits." \[R360\]
- Precedent: Loongson 5-level TLB (considered; named by author): asked what else is affected if pdp64 had it \[R360\]
- Precedent: VAX I/O space (considered; named by assistant, not taken up): VAX kept moving its I/O base; single fixed bit avoids that \[R282\]
- Precedent: SCSI/ATA/SATA/NVMe (considered; named by author): all follow the same device pattern, not limited to 8-register mmio \[R282\]
- Evidence: docs/manual-src/02-bus.md:124 "\*\*2.3.5\*\* No bit of the physical address selects device space: a device window is an ordinary range of physical addresses, found by enumeration"; docs/errata.md:248 entry 97, :210 entry 60 marked "superseded by errata 97"; docs/pdp64-system-architecture.md:108 "Decided (errata 97 and 102): no physical-address bit selects device space"
- Doc differs: docs/decisions-pending.md:123 P19 row still reads "\*\*DECIDED\*\* (the author, 2026-10-22: \\"bit 39 is right\\", errata 60)" with no superseded mark; qemu/README.md:7, :51 and :75 and the QEMU memory map (qemu/hw-pdp64/virt.c) still use bit 39 (listed in docs/implementation-status.md:9)
- Left: the QEMU and simulator memory map still uses the bit (an implementation gap, docs/implementation-status.md); the width of the physical address and the window placement (errata 102) are in ledger A, "Physical address width and device windows"

### Q64 bus: DMA design, document and PCI Express base
- Status: DONE — the bus is PCI Express with mitigations, extensions announced only if a card takes part (latest decision 2026-11-04 \[R319\])
- Decided: 2026-11-04 decided: Extensions "depends on the mitigations; if they don't affect the cards, the cards don't need to know". \[R319\]
- Rationale: "whatever is the most standard, secure, easy to support nic and gpu and audio interfaces will be standardized for iteration one" \[R311\]
- Rationale: "backward compatible with extra convenience/security circuitry added" \[R318\]
- Rationale: extensions: "if they don't affect the cards, the cards don't need to know" \[R319\]
- Precedent: PCI Express (chosen; named by author): pcie for the q64 bus, with pain points solved or mitigated \[R311\]
- Precedent: NVMe (chosen; named by author): storage on the q64 bus \[R311\]
- Precedent: USB (chosen; named by author): on the q64 bus \[R311\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[R360\]
- Precedent: native 8-register devices (rejected; named by author): "forget the native 8 register devices. gone." \[R360\]
- Precedent: IOMMU mapping of C64/C128 (considered; named by author): "i think we should, but that is extraneous" \[R311\]
- Evidence: docs/errata.md:225,230,231 entries 75, 80, 81; docs/decisions-pending.md:1595 "F29 ... Decided (errata 81)"; docs/manual-src/02-bus.md:5 "The processor reaches the world through one bus, PCI Express", :114 "\*\*2.3.1\*\*", :120 "\*\*2.3.4\*\* ... An extension is announced to a card, through a PCI Express extended capability, only if the card must take part in it"
- Doc differs: docs/pdp64-q64-bus.md:25 "the transaction definitions (widths, bursts, arbitration, timing) are not written anywhere in this repository" while the manual body now defers to PCI Express's own transactions (2.3.4)
- Left: the detail of the pdp64's additions to PCI Express is open, J.2.5 (the root complex's own registers and the additions); the name Q64 is kept out of the manual until they are decided (ledger C: "Names kept out of the manual")

### Read of an absent configuration position
- Status: DONE — the read returns all ones and the root complex records the miss in a sticky bit (latest decision 2026-11-10 \[errata 104\])
- Decided: 2026-11-10 decided: "i'd assume all ones, bus faults are spendy."; "yes, all ones; don't we already have a status register and mode flags, can't you use a bit in one of those or add a bit?"; "agree root complex bit" \[errata 104\]
- Evidence: docs/manual-src/02-bus.md:220 "\*\*2.4.7\*\* A read of a configuration position that never held a function completes normally and returns all ones", :222 "\*\*2.4.8\*\* The root complex records such a miss in a sticky bit of its own status register"; docs/errata.md:255 entry 104
- Left: where the root complex's status register sits is open (J.2.5)

## 03 Graphics and the C64 devices

### Blit and C64 as the terminal model
- Status: DONE — chapter 3 names both and the author approved the Blit model (latest decision 2026-11-04 \[R311\])
- Decided: 2026-11-04 decided: "i like the blit model" \[R311\]; before that, 2026-10-23 decided: The design is based "not only on the c64, but also on the blit terminal" \[R291\]
- Rationale: "i think c64 is superior to blit terminal in many ways... could we revamp the blit to be c64 adjacent" \[R20\]
- Rationale: "i like the blit model" \[R311\]
- Precedent: Blit (chosen; named by author): design based "not only on the c64, but also on the blit terminal" \[R291\]
- Precedent: Commodore 64 (chosen; named by author): pdp-11 base with c64 graphics and audio \[R20\]
- Precedent: Commodore 128 (considered; named by author): asked what advances it had over the c64 \[R21\]
- Evidence: docs/manual-src/03-graphics.md:173 "\*\*3.8.1\*\* The graphics terminal is based on two machines, not one: the \*\*Commodore 64\*\* ... and the \*\*Blit terminal\*\*"; docs/errata.md:216 entry 66
- Left: the potentials (the Blit as a modernized C64, plan9 /draw) are open

### C128 as a bus device
- Status: DONE — the C128 is another device on the bus, optional, reached through the IOMMU (latest decision 2026-11-04 \[R314\])
- Decided: 2026-11-04 decided: "the c128 will just be another device on the bus; not part of the pdp64 standard". \[R314\]; also "iommu will allow us to map in c64/c128 and i think we should, but that is extraneous" \[R311\]
- Precedent: Commodore 128 (chosen; named by author): "just another device on the bus", not in the standard \[R314\]
- Evidence: docs/errata.md:227 entry 77; docs/manual-src/03-graphics.md:402 "\*\*3.16.4\*\* The Commodore 128 is another device on the PCI Express bus and is not part of the pdp64 standard ... an optional device reached through the IOMMU window"
- Left: which core it is, and whether unmodified C64 software runs (J.3.11)

### C64 island: 8502 registers readable from outside
- Status: DONE — recorded as a design point of the 8502 island (latest decision 2026-08-29 \[R24\])
- Decided: 2026-08-29 decided: "we can make all registers readable from outside. writeable too. just hold the rdy pin." \[R24\]
- Rationale: "if we're implementing the 8502 in fpga we can make all registers readable from outside. writeable too. just hold the rdy pin." \[R24\]
- Precedent: 8502 RDY pin hold (chosen; named by author): freeze the CPU to read and write registers \[R24\]
- Evidence: docs/c64-devices-from-chat.md:38 "Island access"; :109 "In fabric, A, X, Y, S, P and PC are readable at any cycle"
- Doc differs: the C128 with its 8502 and compatibility island is an optional device on the bus (docs/manual-src/03-graphics.md:402 "\*\*3.16.4\*\*"), so the island's register access is not in the manual body

### C64-derived devices (VIC, SID, BLT, 12-register devices)
- Status: DONE — deferred to iteration two; the body of the manual does not mention them (latest decision 2026-11-04 \[R315\])
- Decided: 2026-11-04 decided: "the vic-64x, sid-64x, blt64 are deferred for now". \[R315\]
- Rationale: "for now we will have a standard pcie set of audio/video devices" \[R315\]
- Evidence: docs/manual-src/appendix-parts/03-deferred.md:1 "The author deferred (errata 78, 2026-11-03) a native video device, a native sound path and a bit-block-transfer assist"; docs/manual-src/appendix-i-deferred.md; docs/errata.md:228 entry 78, :278 entry 116
- Left: whether to keep or remove the deferred native-device material is open, J.3.1; the rule that the manual does not name the three devices (errata 120) is in ledger C, "Names kept out of the manual"

### Pixel and audio sample width
- Status: DONE — 48-bit pixels and samples are specified for the future devices, kept in appendix I (latest decision 2026-11-04 \[R312\])
- Decided: 2026-11-04 decided: "48 bit pixels, 48 bit audio samples.... for the future, same time as the 12 register devices" \[R312\]
- Precedent: SID (considered; named by author): "i want 48 bit sound as well, not just the sid" \[R310\]
- Evidence: docs/manual-src/appendix-parts/03-deferred.md:5,:7 "\*\*3.8.2\*\*", "\*\*3.8.3\*\* (moved from chapter 3) ... audio samples are 48 bits"; docs/errata.md:223,224 entries 73, 74
- Left: the 48-bit pixel against the 32-bit formats of virtio-gpu is open (docs/manual-src/03-graphics.md:241, J.3.6)

### Standard GPU, NIC and audio interfaces
- Status: DONE — virtio-net, virtio-gpu and virtio-snd are the standard (latest decision 2026-11-04 \[R315\])
- Decided: 2026-11-04 decided: Standard pcie audio/video devices, "the ones that are the simplest to program while still being efficient", so there is no bullshit supporting many device drivers. \[R315\]
- Rationale: "i want a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers"; pick "the simplest to program while still being efficient" \[R315\]
- Rationale: "if we can plug a regular card into the bus, why not?" \[R278\]
- Precedent: PCI Express (chosen; named by author): standard set; any device MAY be attached \[R315\]
- Precedent: HDMI, SATA, USB (considered; named by author): "standard kit", our interface goes through mmio \[R278\]
- Evidence: docs/errata.md:228,229 entries 78, 79; docs/manual-src/03-graphics.md:237 "\*\*3.12.1\*\* The standard graphics device is virtio-gpu in 2D mode", :247 "\*\*3.13.1\*\* A PCI Express graphics card may be attached", :443 "\*\*3.17.1\*\* The standard audio device is virtio-snd"; docs/manual-src/05-drivers.md:117 "\*\*5.3.1\*\*"
- Left: the virtio feature subset and the OpenBSD drivers (J.3.7)

### Video output (HDMI)
- Status: DONE — the output is HDMI or another standard graphics output (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "it is agreed that output is hdmi or some other standard graphics output" \[errata 105\]; earlier, 2026-08-29: "in general we should be able to drive the hdmi however we want; not limited to 16 colors, not limited in font size or rows and columns" \[R25\]
- Rationale: "not limited to 16 colors, not limited in font size or rows and columns" \[R25\]
- Rationale: "since the soc will have hdmi, pal/ntsc isn't too relevant except for backwards compat" \[R24\]
- Precedent: HDMI (chosen; named by author): drive it however we want \[R25\]
- Precedent: PAL/NTSC (considered; named by author): 50 fps only for legacy code, backwards compat \[R25\]
- Evidence: docs/manual-src/03-graphics.md:191 "\*\*3.10.1\*\* The display connector is standard kit: HDMI ...", :193 "\*\*3.10.2\*\* The output is HDMI or some other standard graphics output ... (errata 105 ...)"; docs/c64-devices-from-chat.md:37 "i prefer to drive the hdmi at 50 fps", :100 "\`ROWS\`, \`COLS\`, \`CELLW\`, \`CELLH\` are 16-bit registers"
- Left: the 50 fps and cell-size registers belong to the deferred native device (appendix I), not to virtio-gpu

## 04 Boot

### Block 0 and UEFI
- Status: DONE — the pdp64 boots by the block-0 route; UEFI firmware is not part of the specification and is not built; a shim stays possible (latest decision 2026-11-10 \[errata 109\])
- Decided: 2026-11-10 decided: "option 2, block 0 with a shim possible"; then "I guess leaving the door open to uefe support but having the classic mbr fallback, gpt wrapper is a good choice then." \[errata 109, 110\]; earlier, 2026-10-22: "can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0? (not precisely true, but directionally true)" \[R256\]
- Evidence: docs/manual-src/04-boot.md:270 "\*\*4.9.1\*\* The pdp64 does not use UEFI ... \*(D)\*", :272 "\*\*4.9.2\*\* The hand-off and the second stage are kept simple enough that a UEFI shim could be written", :158 "\*\*4.4.1\*\* At reset the ROM ... reads block 0"; docs/errata.md:264 entry 109, :266 entry 110
- Left: the loader's path, which services a shim offers, the machine-type number and whether a shim is ever built (errata 109, not decided); the boot media order (decisions-pending.md F10)

### Boot process, BIOS and open firmware
- Status: DONE — open source boot software is part of the spec; the boot chapter covers the BIOS role (latest decision 2026-10-22 \[R257\])
- Decided: 2026-10-22 decided: "we'll have an open source boot sector boot loader as part of the spec; that is part of the spec that the boot loader/bios is open source" \[R257\]
- Rationale: "for such a simple arch" a controller must boot the others; wants "load 512 byte block 0 then jmp 0" \[R256\]
- Precedent: PDP-11 (chosen; named by author): load 512-byte block 0 then jump to 0 \[R256\]
- Precedent: UEFI (considered; named by author): asked to look into it \[R256\]
- Precedent: OpenBSD disk partitioning (considered; named by author): asked where it originated and how it differs \[R257\]
- Precedent: V7 Unix (considered; named by author): values in an assembler file, kernel recompiled \[R257\]
- Precedent: GPT (considered; named by author): asked how it plays into boot \[R257\]
- Evidence: docs/manual-src/04-boot.md:142 "\*\*4.3.2\*\* The boot software is open source and part of the specification", :140 "\*\*4.3.1\*\* The pdp64's \\"BIOS\\" is the controller chip's boot ROM and its monitor"; docs/errata.md:197 entry 47; docs/boot.md
- Left: how the other cores start is open (J.4.6); the review of SMP boot is a potential only

### Disk label and boot block
- Status: DONE — GPT wrapper and majority offsets (latest decision 2026-10-22 \[R261\])
- Decided: 2026-10-22 decided: "follow the majority as far as boot block offset" \[R261\]
- Precedent: GPT (chosen; named by author): "we will have the gpt wrapper for the disk label" \[R260\]
- Precedent: majority boot block offset (chosen; named by author): "follow the majority as far as boot block offset" \[R261\]
- Evidence: docs/manual-src/04-boot.md:181 "## 4.5 The disk: a GPT around the BSD label", :189 "\*\*4.5.1\*\*", :203 "\*\*4.5.3\*\*"; docs/errata.md:200,201 entries 50, 51
- Left: where the second stage lies and whether there is a dedicated boot partition (J.4.8)

## 05 Drivers and devices

### Device register model: native 8-register devices to virtio
- Status: DONE — the native eight-register model is gone and every standard device is virtio (latest decision 2026-11-09 \[R360\])
- Decided: 2026-11-09 changed: "forget the native 8 register devices. gone. virtio across the board." \[R360\]
- Precedent: virtio (chosen; named by author): "virtio across the board" \[R360\]
- Precedent: native 8-register devices (rejected; named by author): "forget the native 8 register devices. gone." \[R360\]
- Precedent: PCIe/NVMe/USB (chosen; named by author): standardizing on the latest buses \[R359\]
- Precedent: 12 register + dma (considered; named by author): compared with virtio devices \[R359\]
- Evidence: docs/manual-src/05-drivers.md:117 "\*\*5.3.1\*\* Every standard device is a virtio device or a USB controller"; docs/manual-src/02-bus.md:5; docs/errata.md:245 entry 95, :107 entry 29 and :211 entry 61 marked "superseded by errata 95", :199 entry 49 "the eight registers superseded by errata 95"
- Doc differs: docs/decisions-pending.md:659 row Q10 and :908 "Q10. Devices are eight memory-mapped registers plus DMA" are not marked superseded; docs/CHANGES-SINCE-R20.md:754 and docs/c64-devices-from-chat.md:62 still say eight registers
- Left: the syntactic sugar over devices (potential R359) is open, J.5.6

### Modern I/O hardware (USB, NVMe)
- Status: DONE — USB and PCI Express are the standard buses; NVMe is attachable but no longer the standard disk (latest decision 2026-11-10 \[errata 101\])
- Decided: 2026-11-10 changed: "disk is virtio-blk" \[errata 101\]; earlier, 2026-08-29 decided: "modern usb keyboard, mouse, and nvme hard drive", plus usb hard drive \[R20\]
- Precedent: USB (chosen; named by author): modern usb keyboard, mouse and hard drive \[R20\]
- Precedent: NVMe (chosen; named by author): "nvme hard drive" \[R20\]
- Precedent: Raspberry Pi SD-card storage (considered; named by author): asked how those little SanDisk drives interface with rpi \[R20\]
- Evidence: docs/manual-src/05-drivers.md:98 "\*\*5.2.1\*\* ... it standardises on the latest buses, USB, NVMe and PCI Express"; :288 "\*\*5.8.3\*\* USB is a standard device"; docs/errata.md:225 entry 75, :252 entry 101 ("an NVMe device may still be attached ... it is not the standard disk")
- Left: the USB controller interface and the class drivers (J.5.7)

### The disk is virtio-blk
- Status: DONE — the standard disk is virtio-blk; NVMe may still be attached as any PCI Express device (latest decision 2026-11-10 \[errata 101\])
- Decided: 2026-11-10 decided: "disk is virtio-blk" \[errata 101\]
- Evidence: docs/manual-src/05-drivers.md:209 "\*\*5.6.2\*\* The \*\*disk\*\* is virtio-blk (the author's decision of 2026-11-10, errata 101)", :211 "\*\*5.6.3\*\*"; docs/errata.md:252 entry 101, :225 entry 75 marked "the NVMe disk superseded by errata 101"; README.md (commit 0f37ddc "README: the disk is virtio-blk")
- Left: the feature subset of virtio-blk and the block-0 read through a virtqueue (J.5.2, J.4.2); the boot-media order (decisions-pending.md F10, decided in part)

## 06 Kernel, modes and memory management

### Exception and interrupt entry
- Status: DONE — priority 7 on entry with EPC and EPSW (latest decision 2026-10-22 \[R229\])
- Decided: 2026-10-22 decided: "go with priority 7 on entry and document its throwback to pdp-11 design." \[R229\]
- Precedent: PDP-11 (chosen; named by author): priority loaded on trap; "document its throwback to pdp-11 design" \[R229\]
- Evidence: docs/manual-src/06-kernel.md:111 "\*\*6.3.2\*\* The new status word has the current mode kernel, the previous mode the old current mode, priority 7", :529 "\*\*6.13.4\*\* Entry sets the priority to 7 for every exception and every interrupt"; docs/errata.md:159,185 entries 36, 40
- Doc differs: docs/decisions-pending.md:508 says "I extended it to interrupts, which you did not explicitly say" (flagged for the author to confirm)

### First operating system port
- Status: DONE — OpenBSD first, 32V fallback, 3BSD dropped (latest decision 2026-10-22 \[R230\])
- Decided: 2026-10-22 decided: "forget 3bsd we'll do 32v port if openbsd proves too hard"; suspects OpenBSD "is doable". \[R230\]
- Rationale: "actually we'll port 32v unix since it has demand paging already" \[R205\]
- Rationale: "if we are going straight to 3bsd why not openbsd"; later "i suspect it is doable" \[R216\]
- Precedent: OpenBSD (chosen; named by author): first port; "i suspect it is doable" \[R230\]
- Precedent: Unix/32V (chosen; named by author): fallback "if openbsd proves too hard"; has demand paging \[R230\]
- Precedent: 3BSD (rejected; named by author): "forget 3bsd"; earlier considered as first with virtual memory \[R230\]
- Precedent: V7 Unix (considered; named by author): "initially we port v7 unix"; replaced by 32V \[R204\]
- Evidence: docs/manual-src/06-kernel.md:496 "\*\*6.12.2\*\* The first operating system is OpenBSD, with Unix/32V as the fallback if OpenBSD proves too hard. \*(D)\*"; docs/errata.md:188 entry 41
- Doc differs: docs/errata.md:114 entry 30 and :165 entry 30a keep the older text as history (marked superseded by 41)

### MMUCTL
- Status: DONE — (latest decision 2026-10-22 \[R240\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P10" (MMUCTL). \[R240\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:194 entry 44; docs/manual-src/06-kernel.md:198 \`MMUCTL\` row, :306 "\*\*6.8.2\*\* Translation is off at reset (\`MMUCTL\` is zero ...) and is enabled by bit 0 of \`MMUCTL\`"
- Left: enabling translation safely is open (J.6.6)

### Memory safety from OpenBSD mitigations
- Status: DONE — the study exists and its proposals were answered (latest decision 2026-10-22 \[R254\])
- Decided: 2026-10-22 decided: "looking at the openbsd mitigations for memory safety, make that soft and easy, if you can't even think of improvements that theo would love." \[R254\]
- Precedent: OpenBSD mitigations (chosen; named by author): make memory-safety mitigations "soft and easy"; improvements "theo would love" \[R254\]
- Evidence: docs/openbsd-mitigations.md "what would make them soft and easy"; docs/errata.md:235,236 entries 85, 86

### Page-table accessed and dirty bits
- Status: DONE — software-managed (latest decision 2026-10-22 \[R215\])
- Decided: 2026-10-22 approved-proposal: Page-table accessed (A) and dirty (D) bits set by="Software (Recommended)" \[R215\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:159 entry 36 "software-managed accessed and dirty bits"; docs/manual-src/06-kernel.md:288 "\*\*6.8.1\*\* The accessed and dirty bits are managed by software"

### Paging support work
- Status: DONE — MFSR/MTSR and the paging instructions are in the docs and QEMU has the MMU (latest decision 2026-10-22 \[R214\])
- Decided: 2026-10-22 decided: "start on the qemu mmu and privileged mode". \[R214\]
- Rationale: "didn't you notice some missing instructions that a paging os needs?" \[R210\]
- Evidence: docs/errata.md:129 entry 32 "system-register moves \`MFSR\` and \`MTSR\`"; docs/manual-src/06-kernel.md:186 "\*\*6.5.1\*\* The system registers are reached by \`MFSR\` and \`MTSR\`"; qemu/README.md:76 "QEMU's TLB is per MMU index"
- Left: the QEMU walker implements three levels only (docs/implementation-status.md)

### Precise exceptions
- Status: DONE — the candidate list was written and annotated (latest decision 2026-11-04 \[R323\])
- Decided: 2026-11-04 approved-proposal: "precise exceptions.... yes, write the list of candidates." \[R323\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/retire-stage-candidates.md:1 "Candidate features that precise exceptions and out-of-order execution make cheap"; docs/errata.md:234 entry 84 "the nineteen retire-stage candidates"; docs/manual-src/06-kernel.md:146 "## 6.4 Faults and restart: what \\"precise\\" means"

### System architecture section
- Status: DONE — drafted (latest decision 2026-10-22 \[R203\])
- Decided: 2026-10-22 approved-proposal: "draft the system architecture section" (PSW, exception entry, interrupt controller, timer). \[R203\]
- Rationale: "whatever is undefined, say in the docs so we can design it later." \[R203\]
- Evidence: docs/pdp64-system-architecture.md (398 lines); docs/manual-src/06-kernel.md (rewritten by errata 107, 111, 117)

### User-memory guard
- Status: DONE — (latest decision 2026-10-22 \[R240\])
- Decided: 2026-10-22 approved-proposal: "write the errata for P2" (user-memory guard). \[R240\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:192 entry 43 "a user-memory guard, \`UA\`"; docs/manual-src/06-kernel.md:344 "\*\*6.10.1\*\* With the guard bit \`UA\` clear, a kernel-mode data access to a user page faults", :355 "\*\*6.10.4\*\* A move with the qualifier \`.U\`"
- Left: the simulator's status word has no \`UA\` bit yet (docs/implementation-status.md); recovering from a failed user copy is open (J.6.12)

### WFE wake on pending interrupt
- Status: DONE — (latest decision 2026-10-22 \[R231\])
- Decided: 2026-10-22 approved-proposal: WFE idle wait wakes on pending interrupt even if masked="Yes, wake on pending (Recommended)" \[R231\]
- Rationale: accepted from the assistant: lower-then-sleep misses an interrupt landing between the two instructions, and sleeping at priority 7 never wakes. \[R231\]
- Evidence: docs/manual-src/07-smp.md:80 "\*\*7.6.2\*\* \`WFE\` ends its sleep when an interrupt is pending, even if the priority masks it"
- Left: the wake rule and the idle loop have a J entry, J.7.1

## 07 Multiple processors

### Atomics
- Status: DONE — (latest decision 2026-10-22 \[R240\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P11" (atomics). \[R240\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:195 entry 45 "atomics are defined on a monitor (reservation), not a bus lock"; docs/manual-src/07-smp.md:42 "\*\*7.3.1\*\* \`LL\` takes a reservation on a granule of memory", docs/manual-src/02-bus.md:470 "\*\*2.10.1\*\*"
- Left: the operands of the atomic instructions (J.7.3); atomics on uncached and device memory (J.7.4)

### Core counts
- Status: DONE — (latest decision 2026-11-04 \[R338\])
- Decided: 2026-11-04 decided: "for initial device 4 cores is enough hopefully that fits on the fpga". \[R338\]
- Rationale: "for initial device 4 cores is enough hopefully that fits on the fpga" \[R338\]
- Evidence: docs/manual-src/07-smp.md:92 "\*\*7.7.3\*\* The design supports at least four cores; sixteen or more is the preferred ceiling ...; the initial device has four cores"; docs/smp-decisions.md:9-10; docs/errata.md:242 entry 92

### Mixed in-order and out-of-order cores
- Status: DONE — (latest decision 2026-11-04 \[R337\])
- Decided: 2026-11-04 decided: "its ok to have in order and out of order cores on the same die as long as we can tell which is which". \[R337\]
- Rationale: accepted condition: in-order and out-of-order cores are fine "as long as we can tell which is which". \[R337\]
- Evidence: docs/manual-src/07-smp.md:106 "\*\*7.8.4\*\* In-order and out-of-order cores may share a die if software can tell which is which"; docs/smp-decisions.md:11

### SMP and its decisions document
- Status: DONE — written, with Part C in decisions-pending.md (latest decision 2026-10-22 \[R235\])
- Decided: 2026-10-22 approved-proposal: Add Part C covering smp, dma and virtualization gaps: "same style, 5 options, survey of what all major modern os and cpu do, plus vax/pdp". \[R235\]
- Precedent: VAX/PDP (considered; named by author): survey "what all major modern os and cpu do, plus vax/pdp" \[R235\]
- Evidence: docs/decisions-pending.md:1066 "## Part C. The gaps: several cores, DMA devices and virtualization"; docs/smp-decisions.md Parts A and B
- Left: the SMP requirements question (potential R137) is answered by smp-decisions.md

## 08 Vector work and accelerators

### GPU and accelerator meaning, helper chips
- Status: DONE — accelerators are memory-mapped devices sharing RAM (latest decision 2026-10-20 \[R136\])
- Decided: 2026-10-20 decided: "gpu" means "a helper/accelerator that uses the same ram, does dma, etc", with "the simd/avax stuff" \[R136\]
- Precedent: GPU (considered; named by author): meant as "a helper/accelerator that uses the same ram, does dma" \[R136\]
- Precedent: SIMD/AVX (considered; named by author): helps like a GPU's, "the simd/avax stuff" \[R136\]
- Precedent: Samsung LittleBit-2 (considered; named by author): a GPU optimized purely for its encoding \[R136\]
- Evidence: docs/manual-src/08-vectors.md:5 "done by memory-mapped devices with their own memory", :15 "\*\*8.1.4\*\* Such a device is a helper or accelerator that uses the same RAM as the processor and does DMA; this is what \\"GPU\\" means in this manual"; docs/pdp64-lb64-accelerator.md
- Left: the littlebit-2 GPU and the utf8 helper chip are potentials only; the operations, number formats and descriptors of the vector device are open (J.8.1, J.8.2)

### LLM training and inference focus
- Status: DONE — inference is the target (latest decision 2026-10-20 \[R139\])
- Decided: 2026-10-20 decided: "just optimize inference whether in cpu or gpu whatever makes most sense" \[R139\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/08-vectors.md:31 "## 8.3 AI and large-language-model inference"; docs/pdp64-lb64-accelerator.md

### SIMD and vector work
- Status: DONE — memory-mapped device route, no SIMD in the CPU, APL/K noted (latest decision 2026-10-23 \[R277\])
- Decided: 2026-10-23 decided: "we should go the mmap device arm style route" for SIMD/AVX2-type vector work \[R277\]
- Rationale: vector work "is about graphics and ai/llm stuff"; "apl/k" make vector languages "easier to support and more efficient". \[R277\]
- Precedent: ARM-style memory-mapped device (chosen; named by author): "mmap device arm style route" for SIMD/AVX2 vector work \[R277\]
- Precedent: AVX2 (considered; named by author): the SIMD work the chapter covers \[R277\]
- Precedent: APL/K (chosen; named by author): mention as making vector languages easier to support \[R277\]
- Evidence: docs/manual-src/08-vectors.md:9 "\*\*8.1.1\*\* The processor has no vector register file and no SIMD instruction set"; :37 "## 8.4 Array languages: APL and K"; docs/errata.md:209 entry 59
- Left: packed integer lanes in the ordinary registers are open (J.8.3)

## 12 Documentation and process

### c64stuff extraction
- Status: DONE — the file exists and was compared with the docs (latest decision 2026-10-24 \[R309\])
- Decided: 2026-10-24 decided: Find conversations mentioning "pdp-11, vax, blit terminal, or c64" and extract them into "c64stuff.txt". \[R309\]
- Rationale and precedent: none stated in the sources
- Evidence: c64stuff.txt exists (untracked); docs/errata.md:222 entry 72 "\`c64stuff.txt\` ... was compared with the documents"

## Documentation and process

### Agent workflow
- Status: DONE — the rule is written in the handoff (latest decision 2026-10-22 \[R227\])
- Decided: 2026-10-22 decided: "only run one agent at a time, stop eating up memory". \[R227\]
- Rationale: "only run one agent at a time, stop eating up memory" \[R227\]
- Evidence: handoff.md:113 'Agents: one agent at a time on this machine (3.9 GB); stop an agent that eats memory'

### Approval words are decisions
- Status: DONE — the rule is written in errata 121 and in the project instructions (latest decision 2026-11-10 \[errata 121\])
- Decided: 2026-11-10 decided: "when I say 'looks good' and 'I like it' that is a decision in favor of." \[errata 121\]; "just because we don't have the details hammered out, doesn't mean they aren't full fledged decisions" (the project instructions file, 'Decisions and their details')
- Evidence: docs/errata.md:287 (errata 121; it restored 2.3.5 and 2.4.7, the MSI-X statements 2.6.1 and 5.9.1 marked decided with details pending (J.6.3), on R262 "your bus design looks excellent ... but it looks good"); the project instructions file section 'Decisions and their details'
- Left: the rule applies to every document and project; the ledgers, errata and READMEs are being brought in line (this ledger step)

### Architecture recommendations and open proposals
- Status: DONE — the stale marks were re-marked and Part F carries the new requirements; the P9/P17/P18/F25 replies are recorded (latest decision 2026-11-04 \[R316\])
- Decided: 2026-11-04 approved-proposal: "yes": re-mark the stale kernel-pain-points status marks and add the new requirements to Part F. \[R316\]
- Rationale: "4 and 5 are essentially the same thing. recovery and restart go together" \[R323\]
- Rationale: mode bits "should be visible, not hidden state"; modes in bits "that are saved anyway sounds like a freebie" \[R323\]
- Precedent: Plan 9 draw(3)/devdraw (considered; named by assistant, not taken up): compared with ring-based command encoding for BLT64 \[R294\]
- Evidence: commit 833afc9 (2026-11-03) "docs: re-mark pain-points rows for PCI Express; Part F F24-F28"; docs/kernel-pain-points.md "Re-marked 2026-11-03 (errata 75, PCI Express)"; docs/decisions-pending.md:1597-1600 F24 to F27; docs/errata.md:235 (errata 85) "replies to the second round of security proposals" (P9, P17, P18, F25); docs/crypto-secure-core.md (P17 proposal); docs/study-proposals.md and docs/study-round2.md

### Author authority and source precedence
- Status: DONE — the rule is applied by the errata 'DECISION (the author's ...)' convention (latest decision 2026-10-23 \[R274\])
- Decided: 2026-10-23 decided: "my statements supersede yours unless i later agreed with you" \[R274\]
- Rationale: "doesn't matter if the docs mention it I mention it now therefore it is true and if the docs contradict me you must show why or how." \[R199\]
- Rationale: "my statements supersede yours unless i later agreed with you." \[R274\]
- Rationale: "more recent stuff is considered more accurate than old stuff." \[R273\]
- Evidence: docs/errata.md:198 (errata 48) and :244 (errata 94, which "Supersedes" errata 93 and 87) mark author decisions with his words and what they replace; docs/decisions-and-status.md states the precedence rule

### Benchmark and size reports
- Status: DONE — size report in the readme and linked (latest decision 2026-10-19 \[R130\])
- Decided: 2026-10-19 decided: "document all this make sure it is in the readme and pushed, show how the apparent size differences are due to things not being implemented and so the code is buggy" \[R130\]
- Rationale: "show how the apparent size differences are due to things not being implemented and so the code is buggy" \[R130\]
- Rationale: "i want a nice written report in md format at the end, linked into the readme" \[R98\]
- Rationale: "the report should call the 32v cc pcc. 32v pcc, v7 dmr-cc" \[R111\]
- Precedent: gcc -Os (considered; named by assistant, accepted): size gap explained as GCC deleting undefined-behaviour code \[R130\]
- Precedent: clang -Os (considered; named by assistant, not taken up): pcc about 20% larger; docs claiming 11% smaller corrected \[R90\]
- Precedent: dmr cc (considered; named by author): named in report as v7 dmr-cc \[R111\]
- Precedent: 32V pcc (considered; named by author): name to use for the 32V cc \[R111\]
- Precedent: pcc (considered; named by author): compared with our pcc, opti and unopti, vax and pdp11 \[R99\]
- Evidence: pcc-enc:README.md:27 links doc/SIZE-REPORT.md; SIZE-REPORT.md 'compares stock pcc, this fork, clang, gcc, V7 dmr cc and 32V pcc'; pdp64 README.md 'same size as gcc -Os and 7% smaller than clang -Os'

### Boot chapter: five boots compared
- Status: DONE — section 4.11 compares the five boots (latest decision 2026-11-10 \[errata 110\])
- Decided: 2026-11-10 decided: "also boot would compare pdp11 boot, vax boot, c64 boot, the x86 bios boot with mbr, then finally the gpt/uefi" \[errata 110\]; "I guess leaving the door open to uefe support but having the classic mbr fallback, gpt wrapper is a good choice then." \[errata 110\]
- Evidence: docs/manual-src/04-boot.md:307 (4.11 "Five boots side by side"), :268 (4.9 "Why UEFI is not used"), :58 (4.2 the VAX, the C64, the PC with a BIOS, the GPT with UEFI); commits ade1a6d, 9ec2c91
- Left: the C64 boot, the VAX console and VMB, the x86 reset vector and the UEFI boot manager are marked unverified in errata 110; the shim is a possibility, no shim exists

### Browser use, politeness and site bans
- Status: DONE — the politeness rules are written in the handoff; no ban is kept (latest decision 2026-10-23 \[R290\])
- Decided: 2026-10-23 changed: "you can remove the archiv and lwn bans, just be polite" \[R290\]
- Rationale: "avoid lwn.net somehow it triggered spammer code" \[R250\]
- Rationale: "you can remove the archiv and lwn bans, just be polite" \[R290\]
- Rationale: "next time tell me first, i closed it." \[R221\]
- Precedent: lwn.net (rejected; named by author): avoided after it triggered spammer code; later ban removed \[R290\] \[R250\]
- Precedent: lwn.net (considered; named by author): use archives elsewhere if they exist \[R251\]
- Evidence: handoff.md:114 'Politeness: at least 10 seconds between page loads on any host (more on lwn.net and archive.org) ... back off and retry on a timer with a growing delay'; handoff.md:96 web research only through the browser skill; no ban on lwn.net or archive.org is stated in the repository
- Left: whether the browser skill outside the repository (the browser skill file) enforces the 10-second gap: not checked beyond a grep finding no lwn or archive ban there

### Bus chapter
- Status: DONE — the chapter was rewritten and edited with the recent discussion and holds no history wording (latest decision 2026-11-09 \[R364\], errata 103, 113, 118)
- Decided: 2026-11-09 decided: Update bus chapter with all recent discussion; "remove all reference to previous versions and things being removed ... just document what it is currently." \[R364\]
- Rationale: "why does it say that 3 level tlb isn't supported?"; wants it to "just document what it is currently" \[R364\]
- Evidence: docs/manual-src/02-bus.md (commits adde39b, 804c980, 8325603, 0e6542d, f5bba67): 2.3.5 "No bit of the physical address selects device space" (errata 97, 102), virtio throughout (errata 95), 2.6 MSI and MSI-X before 2.7 virtio (errata 118); grep "previous version\|was removed\|no longer\|formerly" finds no history wording

### Decisions document
- Status: DONE — decisions document exists with errata inside and P15 (latest decision 2026-10-22 \[R243\])
- Decided: 2026-10-22 decided: Errata should be in the decisions document; revise the open decisions document "in light of the rule change". \[R243\]
- Rationale: my top priorities are "code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops" \[R243\]
- Rationale: wants previous decisions written up too "in case i want to change them" \[R234\]
- Rationale: asked errata be in the decisions document "so i can read up on them" \[R243\]
- Precedent: unix on PDP-11 and VAX-11 (considered; named by author): asked to compare decisions with what they used to do, and tradeoffs \[R233\]
- Precedent: AArch64 ldtr/sttr and m68k moves (considered; named by assistant, not taken up): option B: separate access-as-user load and store forms \[R232\]
- Precedent: x86, ARM and RISC-V kernels (incl. OpenBSD) (considered; named by assistant, not taken up): assistant's reason for recommending option A \[R232\]
- Evidence: docs/decisions-pending.md (P1 to P15, 'Part 0 ... the rule change', 'Already decided'); docs/errata.md numbers decisions
- Doc differs: docs/errata.md is a separate file, not inside decisions-pending.md; decisions-pending.md is not linked from README text of rule 'don't link it' (README does link it at the principles section)

### Documenting bugs and defects
- Status: DONE — defects chapter exists in the tricks doc (latest decision 2026-10-18 \[R84\])
- Decided: 2026-10-18 decided: "build the pushed commit and verify; document all the bugs you fixed that were pre-existing"; asks whether VAX is affected too, not only pdp11 \[R84\]
- Rationale: "but the bugs we introduced ourselves and fixed, don't mention" \[R62\]
- Rationale: Separate "the bugs in the original unix code, and then the bugs in ragges pcc". \[R62\]
- Rationale: "document all the bugs you fixed that were pre-existing" \[R84\]
- Rationale: "make sure you explain why i386 leal pie is ok too in the doc" \[R63\]
- Precedent: original Unix code (dmr) (considered; named by author): "note any dmr errors in the docs" \[R68\]
- Precedent: pcc (considered; named by author): upstream bugs documented separately from the originals \[R62\]
- Precedent: PDP-11 and VAX-11 (considered; named by author): asks whether pre-existing bugs are only pdp11 or vax too \[R84\]
- Evidence: OPTIMIZATION-TRICKS.md:1226 '## Defects in the originals and in upstream pcc'; pcc-enc:doc/SIZE-REPORT.md 'What this run found'

### Fact-checking
- Status: DONE — fact-check record exists (latest decision 2026-10-22 \[R238\])
- Decided: 2026-10-22 decided: Agent should look at whatever pages he sends it "even if it isn't a page it chose". \[R238\]
- Rationale: "you're doing a lot from memory, i want you to check all the statements you've made today." \[R220\]
- Rationale: "go through the document and verify all the "from memory" claims" \[R236\]
- Rationale: "many of the manuals are hard to access; easier to look at the kernel source code?" \[R239\]
- Rationale: "btw, the complete tuhs source is already here on this box no need to download it" \[R237\]
- Precedent: TUHS source (chosen; named by author): already on the box, no download needed \[R237\]
- Precedent: kernel source code (considered; named by author): suggested instead of hard-to-access manuals \[R239\]
- Evidence: docs/fact-check-2026-10-22.md; docs/codegen-data/verification/claims.csv (cited in docs/decisions-pending.md)

### Git history, merging and pushing
- Status: DONE — push and merge rules are stated and followed; main carries the work (latest decision 2026-10-22 \[R263\])
- Decided: 2026-10-22 decided: "push everything when the agent reports" \[R263\]
- Rationale: "unless the md file commits are merged to main, htey don't show up on github" \[R109\]
- Rationale: accepted from the assistant: do not rewrite the pushed branch; build a squashed copy, one commit per feature, after long long lands. \[R86\]
- Evidence: handoff.md:17 (section 1) 'Push rules the author set: pdp64 goes to origin main ... one commit per feature'; git branch: feature branches enc-\*/man-\* merged into main (commit 39ea17b); HEAD 155b851 (2026-11-10) on main
- Doc differs: git status: untracked c64stuff.txt, chat02.txt and tools/declog/ are not pushed; docs/decision-log/ is deliberately local (.gitignore, commit 8cb79b7)

### Graphics chapter as a history
- Status: DONE — chapter 3 runs from the teletype to the pdp64 terminal; the form of the terminal is an open item (latest decision 2026-11-10 \[errata 105\])
- Decided: 2026-11-10 decided: "now do the graphics chapter from the same point of view; pdp11 had a tty that did one line at a time, then there was the vt55 terminal with escape codes, but then came the blit and c64 ..."; "conclude the graphics chapter: we're still figuring it out, what would a mashup of gpu, vram, c64 and blit look like"; "oh, it is agreed that output is hdmi or some other standard graphics output" \[errata 105\]
- Evidence: docs/manual-src/03-graphics.md headings 3.1 teletype, 3.2 glass teletype, 3.3 Blit, 3.4 Commodore 64, 3.5 VGA, SVGA, VESA, 3.6 GPU, 3.7 why a terminal emulator uses the GPU, 3.8 the pdp64 terminal, 3.10 HDMI, 3.14 what made graphics programming annoying, 3.15 scanout and tearing; :187 "Open: how text, pixels and sprites are composed ... (J.3.3)"; commit 4b5a058
- Left: the form of the terminal device (J.3.3, the author's "mashup of a GPU, video memory, the C64 and the Blit") is open; the architectural sugar against tearing and boilerplate is a goal, not yet a design

### ISA comparison table
- Status: DONE — side-by-side table with encodings is in the ISA text (latest decision 2026-10-20 \[R135\])
- Decided: 2026-10-20 decided: "update the docs accordingly." \[R135\]
- Precedent: PDP-11 (considered; named by author): asks whether R7 was the PC and about a read-only view \[R135\]
- Precedent: LoongArch64 (considered; named by author): asked how they handle the PC \[R135\]
- Precedent: PDP-11 (considered; named by author): asked how call/ret differs from it \[R135\]
- Evidence: docs/pdp64-isa.md:1663 '## 13. Side by side: PDP-11, VAX, pdp64' with 13.2 encodings

### Kernel assembly survey document
- Status: DONE — own document with narrative and tables, linked in README (latest decision 2026-10-22 \[R225\])
- Decided: 2026-10-22 decided: Wants both narrative and full table dumps: "table dumps really make the narrative come alive". \[R225\]
- Rationale: "table dumps really make the narrative come alive, you know? want both." \[R225\]
- Rationale: "should be its own document, do a good writeup, this will be a juicy topic" \[R224\]
- Precedent: Linux and BSD kernel assembly (chosen; named by author): comparison from Linux to BSD as its own document \[R224\]
- Precedent: VAX svpctx/ldpctx (considered; named by assistant, not taken up): hardware context switch sidebar \[R225\]
- Evidence: docs/kernel-asm-survey.md; README.md 'What to read' item 5 and architecture text

### LLVM doc
- Status: DONE — one LLVM document: section 14 of the system architecture document was expanded, no second doc (latest decision 2026-10-22 \[R226\])
- Decided: 2026-10-22 decided: "the llvm rebuild was to expand and update the original doc, not to make a second doc" \[R226\]
- Rationale: "since the isa has changed since the last llvm check was done." \[R226\]
- Precedent: LLVM (considered; named by author): expand and update the original LLVM doc, not a second one \[R226\]
- Evidence: commit 94ce20e "docs: one LLVM document: section 14 of the system architecture document now holds the design, results, awkward spots, next steps"; docs/pdp64-system-architecture.md:219 "## 14. The LLVM back end, and OpenBSD" (14.1 to 14.3); llvm/README.md is the build note; no llvm-named doc in docs/

### License
- Status: DONE — BSD 2-clause COPYING in place (latest decision 2026-10-22 \[R259\])
- Decided: 2026-10-22 decided: "yes, bsd license for everything." \[R259\]
- Rationale and precedent: none stated in the sources
- Evidence: COPYING 'BSD 2-Clause License, Copyright (c) 2026, David Walther'; README.md:92; errata 48 (docs/errata.md:198)

### Links and navigation between docs
- Status: DONE — docs interlink with back links; README lists the pages (latest decision 2026-10-22 \[R193\])
- Decided: 2026-10-22 decided: "make the pages all interlink nicely"; "only the main readme needs to list the other pages, that is enough, backbutton works" \[R193\]
- Rationale: "make the pages all interlink nicely for pleasant navigation" \[R193\]
- Rationale: "only the main readme needs to list the other pages, that is enough, backbutton works" \[R193\]
- Rationale: Original documents stay as they are, but readme links go "to the updated versions of those docs (in a different directory)". \[R189\]
- Precedent: manpage-style SEE ALSO section (chosen; named by author): wants "a manpage style section at the bottom" listing repos and docs \[R188\]
- Evidence: every doc starts with '\[← pdp64 index\](../README.md)'; README.md section 'What to read' lists the documents; docs/manual/00-index.md

### Man pages for 32V
- Status: DONE — the 32V assembler page lives in the v7unix man section (latest decision 2026-10-18 \[R105\])
- Decided: 2026-10-18 decided: "32v is just v7 ported to vax, so 32v man pages can live in the v7unix section" \[R105\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:man/Makefile.am:19 "as32v.1" and :31 \`.so v7unix/man1/as32v.1\`; man/as32v.1 ".TH AS32V 1  VAX"; the toolchain has no other 32V-only page (adb, as, cc, ld, lex, make, yacc are shared)

### Manual PDF and build
- Status: DONE — buildabook builds the PDF, tracked and linked (latest decision 2026-11-05 \[R342\])
- Decided: 2026-11-05 decided: Names the tool to use: "moebiusV/buildabook" \[R342\]
- Rationale: "why wouldn't the agent rebuild the pdf? I never made that rule" \[R340\]
- Precedent: buildabook (chosen; named by author): "use buildabook for the manual" \[R341\]
- Evidence: book/README.md 'Needs buildabook'; tools/mkbook.sh; book/pdp64.pdf tracked (commit c48e8c0); book/outline.txt lists the appendices H, I and J (ids 03008 to 03010); handoff.md commit 149d91e 'the PDF is built with buildabook by the working session'

### Manual body and the appendices Proposed, Deferred and Open items
- Status: DONE — body holds decided material only; appendices H, I and J exist (latest decision 2026-11-10 \[errata 120\])
- Decided: 2026-11-10 decided: "the manual is about the arch as it is to be, not as it is right now."; "'deferred' stuff shouldn't be in the manual, nor should 'proposed' stuff, except maybe in an appendix, one for proposed, one for deferred."; "an 'open items' appendix is where each open item gets a fair discussion of pros and cons of each option" \[errata 120\]
- Evidence: docs/manual/appendix-h-proposed.md, appendix-i-deferred.md, appendix-j-open.md (entries J.n.k, e.g. J.2.1, J.2.2); docs/manual-src/00-index.md items 19 to 21; book/outline.txt ids 03008 to 03010; grep of chapters 1 to 10 for tags (P) and (S): none; open items in the body read "Open: ... (J.n.k)" or "Details pending: ... (J.6.9)"; commits 0e6542d, f5bba67
- Doc differs: docs/manual-src/appendix-j-open.md holds only "There are no open items" (the entries are assembled from appendix-parts/\*-open.md into docs/manual/\*/appendix-j-open.md)

### Manual: deliverable and chapter order
- Status: DONE — chapters follow the final order with atomics in smp and system material in kernel (latest decision 2026-10-23 \[R284\])
- Decided: 2026-10-23 decided: "atomics belongs in the smp chapter"; "system instructions, faults and memory management belong in the kernel chapter" \[R284\]
- Rationale: "let's make it very easy and pleasant for him" (the cpu designer reader) \[R268\]
- Precedent: PDP-10, PDP-11 and VAX-11 (chosen; named by author): manual to cover what was so great about programming them \[R268\]
- Evidence: docs/manual-src/00-index.md contents: 1 introduction, 2 bus, 3 graphics, 4 boot, 5 drivers, 6 kernel, 7 smp, 8 vectors, 9 isa, 10 conclusion, 11 reference tables, appendices A (improvements), B (decisions pending), C to G and H Proposed, I Deferred, J Open items; atomics on the bus in 2.10 and in chapter 7, system instructions in 6.13
- Doc differs: order bus, graphics, boot, drivers (index) differs from the 'boot, device driver, graphics' of R279 and 'bus, blitter, boot' of R280; the later j79473 is the one followed

### Names kept out of the manual: Q64 and the three native device names
- Status: DONE — none of the four names is in the manual or the README (latest decision 2026-11-10 \[errata 120\])
- Decided: 2026-11-10 decided: "instead of retagging, blt64 vic-64x and sid-64x they shouldn't be mentioned at all until I decide on them"; on Q64: "until we have some substantive improvements or sugar over pcie, maybe best to just remove mention of it", and later "well if we DO add things to pcie, then that is q64 bus." \[errata 120\]
- Evidence: grep 'Q64\|BLT64\|VIC-64X\|SID-64X' in docs/manual-src, docs/manual/0\*.md and README.md: no hits (commits 8325603, 0e6542d)
- Doc differs: docs/pdp64-q64-bus.md and docs/c64-devices-from-chat.md still use the names Q64 and BLT64, VIC-64X, SID-64X; the decision names the manual only
- Left: the name Q64 returns for the bus if and when the author decides additions to PCI Express

### Optimization tricks document and optimization docs
- Status: DONE — tricks doc is comprehensive and pdp64 optimization doc is current (latest decision 2026-10-18 \[R83\])
- Decided: 2026-10-18 decided: "of course update the docs coprehensively" \[R83\]
- Rationale: "for all the dmr and vax "tricks" make a comprehensive md file documenting them, how thet worked, and how they can be brought over to x86 and other backends" \[R57\]
- Rationale: "a win is a win, take it." \[R57\]
- Rationale: "the docs should give enough info to implement the other arches later on." \[R69\]
- Rationale: "as long as we document which optims we tried and dropped, and why." \[R78\]
- Precedent: dmr cc (chosen; named by author): document them and bring them to x86 and other backends \[R57\]
- Precedent: VAX pcc / 32V (considered; named by author): "about as good as dmr was on pdp11" \[R57\]
- Precedent: x86, then VAX (chosen; named by author): "do the x86 ones first, then vax" \[R57\]
- Precedent: pdp11/vax/x86 backends only (chosen; named by author): other backends left alone for now \[R69\]
- Evidence: v7unix-toolchain:OPTIMIZATION-TRICKS.md (37+ numbered tricks, status section); pcc-enc:doc/PDP64-OPT.md ('Left out, and why' at line 216)

### PCC README
- Status: DONE — README states what differs from the main version (latest decision 2026-10-18 \[R110\])
- Decided: 2026-10-18 decided: "then update and push all docs right?" \[R110\]
- Rationale: "express what differs from the main version; our dce work, dmr optimizations, bug fixes, updates to vax and pdp11 etc" \[R97\]
- Precedent: pcc (considered; named by author): README says what differs from it \[R97\]
- Evidence: pcc-enc:README.md:110 '## How This Differs From The Historic PCC'; -xdmr, -xdce described at lines 11-15

### Pain-points research
- Status: DONE — rounds 1 to 7 are in the pain-points document (latest decision 2026-10-23 \[R304\])
- Decided: 2026-10-23 decided: "as long as you verify what you write, you don't have to invent more stuff"; if an area is already fine "don't go hunting anymore"; just ensure all essentials are in the document. \[R304\]
- Rationale: "as long as you verify what you write, you don't have to invent more stuff"; if an area is fine "don't go hunting anymore". \[R304\]
- Rationale: "didn't need full history, just the current vesion of the linux and bsd kernels" \[R246\]
- Rationale: "love to include the list of what openbsd (and linux security) people have asked hardware vendors for" \[R255\]
- Rationale: Blit: "lots of material online about the blit"; wants round 6 to find a way to read the manual. \[R293\]
- Precedent: OpenBSD (chosen; named by author): list of what its people asked hardware vendors for \[R255\]
- Precedent: Linux security (chosen; named by author): same list from its people \[R255\]
- Precedent: Linux and BSD current kernel source (chosen; named by author): current version only, not full history \[R246\]
- Precedent: mailing lists (chosen; named by author): expected pain points from mailing lists, not only source \[R247\]
- Precedent: Blit (considered; named by author): wants its manual read; round 6 \[R293\]
- Evidence: docs/kernel-pain-points.md sections 14B to 14M (round 5 bus design and GPU at 14F, round 6 Blit/Research Unix/Plan 9 at 14I, round 7 at 14L-14M)

### Project name
- Status: DONE — named pdp64 in docs, errata 12 (latest decision 2026-10-21 \[R153\])
- Decided: 2026-10-21 decided: "the name isn't 11/64W it is pdp64" \[R153\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:38 '12. The machine\\'s name is pdp64'; README.md title 'DEC PDP-64'

### Repository and docs layout
- Status: DONE — docs/ flat, originals in docs/orig, toolchain in repo (latest decision 2026-10-22 \[R191\])
- Decided: 2026-10-22 decided: "we're already in pdp64/ so docs/pdp64/ doesn't make sense, fix it. you may put old versions of documents in docs/orig or docs/old or docs/Attic" \[R191\]
- Rationale: "we're already in pdp64/ so docs/pdp64/ doesn't make sense" \[R191\]
- Rationale: "you should have left toolchain alone; the as64 and ld64 should live in pdp64/ repo" \[R185\]
- Evidence: docs/orig/ holds 11-64W-\*.md; as64/, ld64/, sim64/ at repo root; no docs/pdp64/ directory

### Spec revisions and write-up
- Status: DONE — the spec exists and is current in grammars and ISA text (latest decision 2026-10-21 \[R152\])
- Decided: 2026-10-21 decided: "start with the spec" \[R152\]
- Rationale: "could even use hbnf to help with the opcode layout. good test case for it." \[R152\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed." \[R152\]
- Rationale: "only 2 byte memory alignment; don't put 8 byte memory alignment constraints that would be horrible" \[R32\]
- Rationale: "since the soc will have hdmi, pal/ntsc isn't too relevant except for backwards compat." \[R24\]
- Precedent: ELF64 output (widen ld.c) (chosen; named by assistant, accepted): said "yes to all" to the assistant's proposal \[R152\]
- Precedent: V7 a.out 64-bit variant (considered; named by assistant, not taken up): offered as the smaller change \[R152\]
- Precedent: 8502/6502 compatibility in FPGA (considered; named by author): all registers readable by holding the rdy pin \[R24\]
- Precedent: PDP-11 (considered; named by author): asked how it handled them before the write-up \[R27\]
- Precedent: AArch64 (considered; named by assistant, not taken up): holds both rules at once; cited for partial writes \[R32\]
- Evidence: spec/pdp64/pdp64.hbnf; docs/pdp64-isa.md; docs/errata.md (rev 6/r10 offers superseded by the prefix-coded grammars, commit a71f491 Merge enc-int)

### System doc
- Status: DONE — system doc exists with the caveat, linked from README (latest decision 2026-10-22 \[R219\])
- Decided: 2026-10-22 decided: Add the caveat to the system doc: a simple memory model does not make an atomic implementation simple by itself; coherence, ordering, interrupts still need design. \[R219\]
- Rationale: Wants "what the main options were compared to the major operating systems and architectures" and how choices fit minimal design and fewer fetches. \[R218\]
- Rationale: Wants to "see what we can learn from the other arches, compiled to assembler on the fair corpus". \[R218\]
- Rationale: "i don't remember ever ruling \[out of order\] out"; asks the cost of refusing it and the gain in "reduced error handling, reduced opcodes/silicon". \[R219\]
- Rationale: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[R220\]
- Precedent: out-of-order design (considered; named by author): asks what supporting it needs and what refusing it costs \[R219\]
- Precedent: major operating systems and architectures (considered; named by author): options compared with them \[R218\]
- Precedent: gcc cross-compilers on other arches (considered; named by author): asks what cross-compile infrastructure exists \[R218\]
- Evidence: docs/pdp64-system-architecture.md:153 'Caveat: a simple memory model does not make an atomic implementation simple by itself'; README.md 'What to read' item 2

### Undefined items
- Status: DONE — details-pending marks in the chapters and open items in appendix J say what is undefined (latest decision 2026-10-22 \[R203\])
- Decided: 2026-10-22 decided: "whatever is undefined, say in the docs so we can design it later" \[R203\]
- Rationale: "whatever is undefined, say in the docs so we can design it later" \[R203\]
- Precedent: LLVM (considered; named by author): asks how hard one would be \[R203\]
- Precedent: Linux port (GCC or LLVM back end) (considered; named by assistant, not taken up): a BSD or V7-style Unix is closer to the toolchain \[R203\]
- Evidence: docs/manual-src/00-index.md:37 'Each aphorism may carry a status ... (D)' and "where a decision's details are not yet worked out, the aphorism ends with" a details-pending line (e.g. docs/manual-src/06-kernel.md:79 "Details pending: ... (J.6.9)", :140 (J.6.3)); docs/manual/appendix-j-open.md (entries J.n.k, tag (S)); appendix-b-decisions-pending.md still exists

### Variant testing document
- Status: DONE — the testing against r20 and pdp64/16 is documented and states pdp64/32 was chosen for performance; the history stays as history (latest decision 2026-11-10 \[R370\]; errata 122 \[R374\])
- Decided: 2026-11-10 decided: Document "the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons" \[R370\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/manual-src/01-introduction.md:117 (1.8 "How the encoding was chosen"; 1.8.5 "pdp64/32 was chosen for performance, by testing against the other two on the same programs" with the instruction counts); docs/encoding-work/integration.md (section 4) and timing.md; appendix G of the manual; errata 122 item (3) (the history stays); the earlier code is in the git tags \`pre-single-cpu\` and \`pre-code-removal\`

### Velinsky link
- Status: DONE — recorded in the c64 doc section 8 and, as the author's hypothesis, in appendix H (latest decision 2026-11-08 \[R358\])
- Decided: 2026-11-08 approved-proposal: "add it": record his prediction and hypothesis (P) in manual 1.1 commentary and section 8, sourced claim separated from his observation. \[R358\]
- Rationale and precedent: none stated in the sources
- Evidence: commit c3eceb6 'Velinsky link recorded as prediction, confirmation and the author's hypothesis (P)'; docs/c64-devices-from-chat.md:150 'Confirmation. Ira Velinsky ...' and table row 7 (:170); docs/manual-src/appendix-parts/01-proposed.md:1 (1.1.5, tag (P), "A thread between the two lineages"); docs/manual-src/appendix-g-evolution.md:33
- Doc differs: manual 1.1 commentary no longer carries it: errata 120 moved it to appendix H, since the manual body holds decided material only

## FPGA and silicon

### FPGA target and clock
- Status: DONE — the plan states the 200 to 300 MHz target and keeps the lower per-board estimates as estimates (latest decision 2026-11-10, errata 99)
- Decided: 2026-11-10 decided: "the FPGA clock is 200-300 MHz" (errata 99); 2026-08-29 "200-300MHz is fine; still much faster than pdp-11 no?" \[R22\]
- Rationale: "modern fpga so insane high clock specs" \[R20\]
- Rationale: "300Mhz for a 1Mhz chip is insane. in a good way." \[R22\]
- Rationale: "we go full little endian, none of this middle endian stuff" \[R22\]
- Precedent: PDP-11 (chosen; named by author): used as the base of the mashup \[R20\]
- Precedent: SID (chosen; named by author): fold in the good parts of c64 \[R20\]
- Precedent: m8502 (chosen; named by author): mash it up with the PDP-11 instead of the c64, they seem closer \[R22\]
- Precedent: PDP-11 (rejected; named by author): go full little endian, fixed right now \[R22\]
- Precedent: IEEE 754 floating point (chosen; named by author): new FP unit compatible with modern ieee representation \[R22\]
- Precedent: Blit (considered; named by author): revamp it to be c64 adjacent \[R20\]
- Evidence: docs/errata.md item 99; docs/pdp64-fpga-plan.md:1 "SoC FPGA Implementation Plan"; :13 "The pdp64 assumes a SoC FPGA"; :93 "The target is 200 to 300 MHz (D), the author's decision (errata 99)"; :97-101 the estimates (E), each below or at the edge of the target
- Left: a closure plan for the chosen board (pipeline-stage boundaries in the RTL from phase 1, plan risk 2 at :281); no Fmax is measured because no RTL exists

### In-order cores, ready for out-of-order
- Status: DONE — stated in the ISA constraints, errata 38 and the readiness documents (latest decision 2026-10-22 \[R220\])
- Decided: 2026-10-22 decided: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[R220\]
- Rationale: "i'm ok with the fpga/asic being in order, but want to be ready for the out of order large scale design." \[R220\]
- Evidence: docs/pdp64-isa.md:28 "Ready for out-of-order execution from the start"; docs/errata.md item 38; docs/pdp64-ooo-readiness.md; docs/pdp64-in-order-and-out-of-order.md

## Instruction set: addressing modes

### Wide immediates
- Status: DONE — literal pool written with an explicit =, nothing pooled silently (latest decision 2026-10-22 \[R211\])
- Decided: 2026-10-22 decided: "i am ok with some syntactic sugar to make compiler pools look like a single instruction, but the sugar should be done in a way it is immediately obvious that is what it is." \[R211\]
- Rationale: "i am ok with some syntactic sugar to make compiler pools look like a single instruction, but the sugar should be done in a way it is immediately obvious that is what it is" \[R211\]
- Evidence: docs/asm-syntax.md:32 "Literal pool: =expr" and :34 "a bare #K that does not fit ... is an error"; docs/errata.md item 33

## Instruction set: alignment and memory model

### Address space (VAX I/O space)
- Status: DONE — the VAX I/O space is noted in the manual (latest decision 2026-10-23 \[R281\])
- Decided: 2026-10-23 decided: "it should be noted in the book how the vax does this io space idea"; he had not known of it \[R281\]
- Precedent: VAX I/O space (considered; named by assistant, accepted): memory low, I/O above; to be noted in the book \[R281\]
- Evidence: docs/manual-src/02-bus.md:132 "The VAX-11/780 put them in nexus space from 0x20000000, one 8 KB window (NEXSIZE 0x2000) per slot" (commentary on 2.3.5); docs/manual-src/02-bus.md:78 (VAX-11/780 row of the comparison table)

### Data alignment
- Status: DONE — natural alignment with byte access and wide transfers (latest decision 2026-11-04 \[R321\])
- Decided: 2026-11-04 decided: "as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits (or more) at a time". \[R321\]
- Rationale: "as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits (or more) at a time" \[R321\]
- Rationale: "don't put 8 byte memory alignment constraints that would be horrible" \[R32\]
- Evidence: docs/errata.md item 82; docs/pdp64-isa.md:56 "Natural alignment for quad accesses (§7.4)"; docs/abi.md:10 "natural"; instructions stay 2-byte aligned (docs/pdp64-isa.md:206)

### Endianness
- Status: DONE — little-endian for data and instructions (latest decision 2026-08-29 \[R22\])
- Decided: 2026-08-29 decided: "we go full little endian, none of this middle endian stuff, that gets fixed right now" \[R22\]
- Rationale: "6502 was 8bit so word order didn't matter; we go full little endian, none of this middle endian stuff" \[R22\]
- Precedent: middle-endian longword order (rejected; named by author): "none of this middle endian stuff, that gets fixed right now" \[R22\]
- Precedent: 6502 (considered; named by author): 8-bit, so word order did not matter there \[R22\]
- Evidence: docs/pdp64-isa.md:208 "Byte order is little-endian, for data and for instructions"

### Instruction alignment after odd data in .text
- Status: DONE — as64 errors on an instruction at an odd address (latest decision 2026-10-22 \[R184\])
- Decided: 2026-10-22 approved-proposal: Instruction after odd data bytes in .text, what as64 should do="Error (Recommended)" \[R184\]
- Rationale and precedent: none stated in the sources
- Evidence: as64/as64.c:1148 "an instruction at an odd address (%lld): put .even before it"

### Tagged pointers
- Status: DONE — low pointer bits reserved to software, alignment abort as the tag check (latest decision 2026-08-30 \[R34\])
- Decided: 2026-08-30 approved-proposal: "fold it" (reserve low pointer bits to software, alignment abort as tag-mismatch signal, into r11) \[R34\]
- Rationale: "since we address at 2 byte boundaries, we can use the bottom bit as a tag for tagged pointers" \[R33\]
- Rationale: accepted from the assistant: the alignment abort is the tag check, which section 7.4 already gives "approximately for free" \[R34\]
- Precedent: Lisp machine (chosen; named by author): tagged pointers; hardware tag checking on dereference not added \[R33\]
- Evidence: docs/pdp64-isa.md:1129 "6.2 Low pointer bits are reserved to software"; :1149 "The alignment abort is the tag check"
- Doc differs: docs/pdp64-isa.md:1137 says the three bits come from data alignment, not instruction alignment (the "bottom bit" idea was replaced)

## Instruction set: encoding

### Backward compatibility
- Status: DONE — no binary compatibility; PDP-11 mnemonic flavour kept as a priority (latest decision 2026-08-30 \[R26\])
- Decided: 2026-08-30 decided: "no need to be backward compatible"; "assembler mnemonics be nice if those were backward compatible" \[R26\]
- Rationale: wants to keep "some of its nice properties" and keep "transistor count down while still being reasonably nice to program in assembler"; "assembler mnemonics be nice if those were backward compatible" \[R26\]
- Precedent: PDP-11 (chosen; named by author): upgrade it to 32/64 bit keeping nice properties; mnemonics compatible, binary not \[R26\]
- Precedent: m8502 (chosen; named by author): adopt what is needed from it to keep transistor count down \[R26\]
- Precedent: x86 (chosen; named by author): adopt what is needed from it to keep transistor count down \[R26\]
- Precedent: Strecker VAX-11/780 paper (considered; named by assistant, not taken up): DEC considered extending PDP-11; opcode-space exhaustion was the reason \[R26\]
- Evidence: docs/pdp64-isa.md:24 "A PDP-11 programmer should recognize the language" (priority 6); the encoding is not PDP-11 (docs/pdp64-isa.md:145 parcels of 16 bits, new opcodes); docs/pdp64-isa.md:437 SOB restored with the PDP-11 name

### Grammar as source of truth (hbnf)
- Status: DONE — the repository is built on hbnf grammars as the source of truth; the chain's "skip hbnf for now" was overridden by the author's correction of 2026-11-04 (latest decision 2026-11-04 \[R335\])
- Decided: 2026-11-04 decided: "i said grammar is the source of truth; undo your pivot to python. use latest hbnf" \[R335\]; supersedes 2026-10-21 "skip hbnf for now" \[R154\]
- Rationale: accepted from the assistant: the bit-level hbnf grammar cannot be tested until GNAT 15 is available (he answered "skip hbnf for now") \[R154\]
- Evidence: spec/pdp64/pdp64.hbnf and spec/README.md:20 "toolchain is written from one source of truth, a set of hbnf grammars"; README.md:17 same sentence; docs/errata.md item 89; handoff.md:49 "the grammars are the source of truth"
- Left: none; the three open questions of the old chain (hbnf for opcode layout, json spec, 0b enums) were overtaken by the 2026-11-04 instruction

### ISA revision r12
- Status: DONE — rolled and passed long ago; the current text is revision 20 with the len invariant stated (latest decision 2026-10-20 \[R134\])
- Decided: 2026-10-20 approved-proposal: "yes, roll r12" (wording fixed, len invariant restated) \[R134\]
- Rationale: accepted from the assistant: "length is len + 1" is unprovable-because-trivial; the property to prove is that no escape sub-opcode needs more parcels than len declares \[R134\]
- Evidence: docs/pdp64-isa.md:158-160 len field as the number of extension parcels (the invariant); docs/errata.md:1 "Errata and decisions against ISA r20"

### Instruction length (parcels)
- Status: DONE — maximum is three parcels, stated and implemented (latest decision 2026-10-22 \[R206\])
- Decided: 2026-10-22 approved-proposal: "yes, write it up as an open design item" (3-parcel maximum length). \[R206\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:145 "Instructions are 1 to 3 16-bit parcels"; docs/errata.md item 31 (fourth parcel removed); docs/pdp64-isa.md:187 six-byte longest

### One-parcel forms
- Status: DONE — page 2 (len=11) of one-parcel abbreviations is in the ISA (latest decision 2026-10-22 \[R208\])
- Decided: 2026-10-22 decided: Go ahead and "update the isa with all those new 1 parcel forms". \[R208\]
- Rationale: accepted from the assistant: the (rN) and sp-offset candidates are together "about 3% of code", worth folding into the open one-parcel item \[R207\]
- Precedent: gcc -Os x86-64 / clang -Os (considered; named by assistant, not taken up): pdp64 averages 3.36 bytes per instruction against 3.66 and 3.78 \[R207\]
- Evidence: docs/pdp64-isa.md:202 "its own 64-entry opcode map (45 defined), given in §4.18"; docs/errata.md item 31; docs/errata.md item 37 page-2 pushx/popx

### Opcode map grouping
- Status: DONE — rare opcodes sit in wide groups with sub-opcodes, thematic runs (latest decision 2026-10-21 \[R146\])
- Decided: 2026-10-21 decided: "regroup the opcodes, rare ones are bigger ones", and "keep them grouped by theme" \[R146\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/pdp64-isa.md:406 "Everything else is a contiguous run of one kind"; docs/encoding-proposal.md:30 "Rare instructions share a few wide groups with a sub-opcode field"

### Single target: the pdp64
- Status: DONE — the repository states one target, \`pdp64\`: one grammar, one manual, one set of tools with no \`-m\` choice (latest decision 2026-11-10 \[R374, R375\])
- Decided: 2026-11-10 decided: "r20 and 64/16 are gone as cpus with manuals etc; they are previous iterations that were superseded by 64/32 which is now the official pdp64" \[R374\]; "remove the code too, tag first" \[R375\]
- Evidence: docs/errata.md item 123 (the grammar is spec/pdp64/pdp64.hbnf, the tables build/pdp64-tab.c and spec/pdp64/tables.md, the encoding name "pdp64"; as64, sim64 and ccom accept \`-m pdp64\` and no other value; the low four bits of e\_flags hold EF\_PDP64\_ISA, and ld64 and sim64 refuse an object that names another instruction set; the tags \`pre-single-cpu\` and \`pre-code-removal\` were pushed); README.md:15; spec/README.md:3; handoff.md:46; the counts of tools/check-all.sh before and after in errata 123 (only r20 and pdp64/16 tests are gone)
- Left: nothing; what becomes of the frozen llvm/ is under "QEMU and LLVM targets"

### Trailing literals
- Status: DONE — the allocation model was rerun with trailing literals and the result recorded; not adopted (latest decision 2026-11-04 \[R326\])
- Decided: 2026-11-04 approved-proposal: "yes, and do the compilation too": rerun the allocation model with trailing literals. \[R326\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/layout-size-variants.md:1 "The 32-register layout with trailing literals: sizes"; docs/encoding-proposal.md:225 "trailing literals (earlier fragments: worse than inline immediates plus dedicated forms...)"

### Why pdp64/32 (r20 and pdp64/16 tested against it)
- Status: DONE — decided and stated: pdp64/32 is the pdp64, chosen for performance by testing against the two earlier iterations; r20 and pdp64/16 are gone as CPUs with manuals and as code, and the testing is documented (latest decision 2026-11-10 \[R374, R375\])
- Decided: 2026-11-10 decided: "pdp64/32 is the decided upon pdp64", "r20 and pdp64/16 are gone, there is no family"; "it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons. follows our principles of check, don't guess." \[R370\]; then (errata 122) "r20 and 64/16 are gone as cpus with manuals etc; they are previous iterations that were superseded by 64/32 which is now the official pdp64" \[R374\]; and (errata 123) "remove the code too, tag first" \[R375\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md items 122 (the decision, the manuals) and 123 (the code, data and tests removed; tags \`pre-single-cpu\` and \`pre-code-removal\` pushed); README.md:15 "There is one CPU, and the tools call it \`pdp64\`. Two earlier iterations of the design ... were built and measured against it and superseded"; spec/README.md:3 "The pdp64 has one CPU: 32 registers (\`r0\`-\`r31\`) and a prefix-coded instruction encoding"; handoff.md:46 "The architecture (decided 2026-11-10)"; docs/manual-src/01-introduction.md:117 "## 1.8 How the encoding was chosen" (1.8.2 the two earlier iterations, superseded; 1.8.5 the performance case); docs/encoding-work/integration.md section 4 (the measured r20 / /16 / /32 comparison, kept as history); spec/pdp64-16/ and docs/manual/pdp64-r20, docs/manual/pdp64-16 no longer exist in the tree
- Left: nothing for this decision; the history of the choice stays in docs/encoding-work/ and in the two tags

### Word size
- Status: DONE — words are 16 bits, longs 32, quads 64 (latest decision 2026-08-30 \[R29\])
- Decided: 2026-08-30 decided: "we can keep 16 bit word size"; "16bit is enough and utf8 showed the way encoding can be done" \[R29\]
- Rationale: "16bit is enough and utf8 showed the way encoding can be done" \[R29\]
- Precedent: UTF-8 (chosen; named by author): showed how the length-first encoding can be done \[R29\]
- Precedent: ARM32 LDRD / MIPS32 FP pairs (considered; named by assistant, not taken up): register-pair cost of 32-bit FP, in the case against a 32-bit version \[R29\]
- Evidence: docs/pdp64-isa.md:9 "Words are 16 bits. Longs are 32. Quads are 64."; docs/pdp64-isa.md:147 UTF-8 as the model for the length-first encoding

## Instruction set: fused pairs and compiler idioms

### Compare-and-branch
- Status: DONE — register-register and wide cbCC exist (latest decision 2026-10-22 \[R213\])
- Decided: 2026-10-22 decided: "do the register-register compare-and-branch". \[R213\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md items 34 and 35; docs/pdp64-isa.md:445 "4.4.1 CBCC"; spec/pdp64/pdp64.hbnf leaves CBR8, CBDR, CB3R24H, CB3I16

### Comparison with other architectures
- Status: DONE — the fair corpus was compared across architectures (latest decision 2026-10-22 \[R222\])
- Decided: 2026-10-22 decided: Compile the fair corpus "with each clang backend that we have" to find instructions to adopt or sequences to coalesce. \[R222\]
- Rationale: "so we can check and see if there are any instructions we should adopt, or sequences we shoudl coallesce" \[R222\]
- Rationale: wants to see what we can learn from other arches on the fair corpus "to reduce instsruction count" \[R218\]
- Precedent: each clang backend that we have (chosen; named by author): compile the fair corpus with each to find instructions to adopt \[R222\]
- Precedent: Linux and BSD kernel assembly (chosen; named by author): review for instructions like popx/pushx that compilers never emit \[R222\]
- Precedent: major operating systems and architectures (considered; named by author): asked how the options compared against them \[R218\]
- Evidence: tools/archcmp.py, tools/archcmp-gccx.sh; docs/codegen-data/archcmp/archcmp-classes.csv; docs/CHANGES-SINCE-R20.md:418 "841-file fair corpus"; docs/encoding-work/arch-comparison.md and tools/arch-compare/ (static size of the 841-file corpus for pdp64/32 against pcc amd64 and i386 and clang for RISC-V, AArch64, x86, Arm, MIPS64; commits f075669, 155b851)

### Fused pairs
- Status: DONE — the assembler never fuses; the compiler emits movcall, popret, popmret, mov2 (latest decision 2026-11-04 \[R332\])
- Decided: 2026-11-04 decided: "leave fusing to the compiler". \[R332\]
- Rationale: "then we will see how well the optimizer does" \[R329\]
- Rationale: accepted from the assistant: the assembler cannot see liveness, the compiler can, so the compiler finds at least as many pairs \[R332\]
- Evidence: spec/pdp64/pdp64.hbnf "fused = movcall \| popmret \| popret \| mov2" with the comment "the assembler never fuses ... chosen by the compiler"

### rori32 sign extension
- Status: DONE — rori32 sign-extends (latest decision 2026-10-22 \[R212\])
- Decided: 2026-10-22 decided: "make rori32 sign-extend like the rest". \[R212\]
- Rationale: "make rori32 sign-extend like the rest" \[R212\]
- Rationale: accepted from the assistant: it zero-extends "while the compiler keeps unsigned values sign-extended" \[R212\]
- Evidence: docs/pdp64-isa.md:543 "rd ← sign-extend(ror32(rs\[31:0\], n mod 32))"; docs/errata.md item 34

## Instruction set: instruction groups

### 16-bit and narrow integers
- Status: DONE — arithmetic is 64-bit only, with proper zero and sign extension (latest decision 2026-10-22 \[R195\])
- Decided: 2026-10-22 decided: "just make sure zero extend and sign extend happen properly" \[R195\]
- Rationale: "if things are 0 extended, then i can see how your arithmetic is 64bit only. and that is fine" \[R194\]
- Evidence: docs/errata.md item 28 "integer arithmetic stays 64-bit; there are no sized ALU operations"; docs/pdp64-isa.md:543 RORI32 sign-extends

### FP exception flags
- Status: DONE — sticky five-bit FPSR with FSFLAGS (latest decision 2026-10-21 \[R174\])
- Decided: 2026-10-21 approved-proposal: "yes, fix the missing exception flags, we have to be able to implement ieee floating point" \[R174\]
- Rationale: "we have to be able to implement ieee floating point" \[R174\]
- Precedent: IEEE 754 floating point (chosen; named by author): needs the five exception flags \[R174\]
- Evidence: docs/pdp64-isa.md:768 "a sticky five-bit re..."; docs/errata.md item 17 "FSFLAGS rs, rd (FESC sub-opcode 0x40)"

### FP reciprocal estimates
- Status: DONE — frecped and frsqrted removed (latest decision 2026-10-21 \[R164\])
- Decided: 2026-10-21 approved-proposal: "yes, drop them": the two FP reciprocal-estimate words (frecped, frsqrted) removed from the spec. \[R164\]
- Rationale: accepted from the assistant: no named customer, and two implementations would give different bits; "yes, drop them" \[R164\]
- Evidence: docs/pdp64-isa.md:764 "There are no reciprocal or reciprocal-square-root estimate instructions"; docs/errata.md item 16

### FP rounding variants
- Status: DONE — frint family kept (latest decision 2026-10-21 \[R173\])
- Decided: 2026-10-21 decided: "i like having the rounding variants" (keep the FP rounding variants). \[R173\]
- Rationale: "i like having the rounding variants" \[R173\]
- Precedent: C round() / libm (chosen; named by assistant, accepted): ties-away-from-zero rounding added as a qualifier \[R173\]
- Evidence: docs/errata.md item 24 lists "frint (nearest even), frintz, frintm, frintp, frinta"; docs/pdp64-isa.md:746 FRINT

### FP16 support
- Status: DONE — seventeen binary16 words in FESC (latest decision 2026-10-22 \[R190\])
- Decided: 2026-10-22 decided: "add fp16 conversions and arithmetic". \[R190\]
- Rationale: "would be a shame if a descendant of the pdp-11 didn't have native 16 bit support" \[R192\]
- Evidence: docs/pdp64-isa.md:761 "binary16 (half precision): seventeen FESC words in the block 0x50-0x65: FADD16 ..."

### Floating-point format
- Status: DONE — IEEE 754 binary32/64/16 with flags and canonical NaN (latest decision 2026-08-29 \[R22\])
- Decided: 2026-08-29 decided: "assume a new refreshed redesigned fp unit, probably compatible with modern ieee floating point representation" \[R22\]
- Rationale: "assume a new refreshed redesigned fp unit, probably compatible with modern ieee floating point representation" \[R22\]
- Precedent: IEEE 754 floating point (chosen; named by author): new FP unit compatible with the modern representation \[R22\]
- Precedent: PDP-11 (rejected; named by author): cited as "done horribly" \[R22\]
- Evidence: docs/pdp64-isa.md:768 "IEEE 754 requires five status flags ... The machine has a sticky five-bit"; :782 canonical quiet NaN for binary64/32/16

### Kernel assembly survey
- Status: DONE — the survey of the kernels' hand-written assembly exists, including PUSHX and POPX (latest decision 2026-10-22 \[R222\])
- Decided: 2026-10-22 decided: "it would be good to review linux and the bsd kernels in their assembly files their handwritten assembly to see if they are using any instructions like popx/pushx that compilers don't support or ever emit." \[R222\]
- Rationale: compile the corpus with each clang backend "to check and see if there are any instructions we should adopt, or sequences we should coalesce" \[R222\]
- Precedent: Linux and BSD kernel assembly (considered; named by author): survey for instructions like popx/pushx that compilers never emit \[R222\]
- Precedent: clang backends (considered; named by author): compile the corpus with each to find instructions to adopt \[R222\]
- Evidence: docs/kernel-asm-survey.md:28 "the hand-written assembly of a kernel a precise inventory of what an instruction set must offer"; docs/kernel-asm-survey.md:2181 pdp64 row; docs/codegen-data/kernelasm/

### PUSHX and POPX
- Status: DONE — instructions added and the null-system-call measurement exists (latest decision 2026-10-22 \[R220\])
- Decided: 2026-10-22 approved-proposal: "yes, add the measurement" of null system call with and without pushx/popx. \[R220\]
- Rationale: accepted from the assistant: nested entry and exit is "roughly 11 fewer instructions and 28 fewer bytes", so fewer instruction fetches \[R220\]
- Rationale: wants "to be ready for the out of order large scale design" \[R220\]
- Precedent: ARM32 SRS/RFE (considered; named by assistant, not taken up): same idea; assistant said from memory, unchecked \[R220\]
- Evidence: docs/pdp64-isa.md:811 "PUSHX and POPX save and restore the exception state"; tests/sim/sys-roundtrip.S:1 "a null system call round trip, two ways"; docs/errata.md item 37

### Rotates and ASL flags
- Status: DONE — rotates write no flags, ASL V = N xor C (latest decision 2026-10-22 \[R227\])
- Decided: 2026-10-22 approved-proposal: "go with your recommendation on rotates and ASL": rotates flag-free, ASL keeps V = N xor C, ISA text corrected. \[R227\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones. you made a good case for ror over rol" \[R138\]
- Precedent: PDP-11 (considered; named by author): not kept slavishly; ror over rol, assembler may map rol to ror \[R138\]
- Evidence: docs/pdp64-isa.md:356 "ASL ... N xor C (the PDP-11 rule: set if the sign changed)"; :358 ROR, RORI, RORI32 "(no flags are written)"; docs/errata.md item 10

### Set on condition
- Status: DONE — SET cc, Rd with the condition as an operand (latest decision 2026-10-21 \[R179\])
- Decided: 2026-10-21 changed: "set eq intead of seteq": condition as an operand, not a suffix mnemonic. \[R179\]
- Precedent: PDP-11 (rejected; named by assistant, not taken up): assistant proposed suffix spelling; he wanted the condition as an operand \[R179\]
- Precedent: ARM csel family (considered; named by assistant, not taken up): extra variants almost free once the first exists \[R178\]
- Evidence: docs/pdp64-isa.md:858 "SET cc, Rd"; :862 "SET EQ, R1"; docs/errata.md item 25

### Three added instructions (unclear)
- Status: DONE — the three floating-point additions were made the same day: exception flags, unsigned conversions, round half away (latest decision 2026-10-21 \[R173\])
- Decided: 2026-10-21 decided: "add those 3 things" (the three floating-point operations he had just asked about, \[R172\] "what were the floating point ops? any we may want to include?") \[R173\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md items 17 (FSFLAGS and the exception flags), 18 (FCVTDQU, FCVTQUD) and 19 (FRINTDA), all of 2026-10-21; docs/pdp64-isa.md:760 conversions, :766 "4.10.1 Exception flags", :918 FRINTDA; identification of the three by date and content, not by the author's list
- Left: ambiguous: the assistant's list of three is not in the records; the identification as errata 17 to 19 is an inference for the author to confirm

## Instruction set: registers

### Register count (16 or 32)
- Status: DONE — 32 registers is the pdp64 and the only CPU: README.md, spec/README.md, the manual 1.8, the grammar and the tools state it (latest decision 2026-11-09 \[R365\]; one CPU since 2026-11-10, errata 122 and 123 \[R374, R375\])
- Decided: 2026-11-09 decided: "only the 32 register pdp64 is official, the other two are cancelled." \[R365\]; 2026-11-10 "pdp64/32 is the decided upon pdp64" \[R370\]; "r20 and 64/16 are gone as cpus with manuals etc" \[R374\]; errata 94, 122
- Precedent: RISC-V (considered; named by author): compared with pdp64 as a 32-register design; only the 32-register pdp64 official \[R365\]
- Evidence: spec/pdp64/pdp64.hbnf (32 registers); docs/encoding-work/integration.md section 4 (the measured case for 32); README.md:15 "The pdp64 has 32 registers (\`r0\`-\`r31\`)"; spec/README.md:3; docs/manual-src/01-introduction.md:119 (1.8.1); the \`-m\` option now accepts only \`pdp64\` (as64/as64.c usage "\[-m pdp64\]")
- Doc differs: docs/pdp64-isa.md:80 "Sixteen registers" (the instruction-set text of the original encoding r20, declared at :7 as such, one of the two earlier iterations; not rewritten for 32 registers)
- Left: whether docs/pdp64-isa.md is rewritten for the 32-register pdp64 or kept as the record of the r20 text is not decided

### Register width
- Status: DONE — registers are 64 bits, no 32-bit version (latest decision 2026-08-30 \[R29\])
- Decided: 2026-08-30 changed: "skip 32 bit version and go straight to 64bit. no need to horn 32 bit support in there" \[R29\]
- Rationale: "no need to horn 32 bit support in there" \[R29\]
- Precedent: x86 ah/al (considered; named by author): asked for 64-bit registers addressable as two 32-bit halves, sort of like ah/al \[R28\]
- Precedent: ARM32 LDRD / MIPS32 FP pairs (considered; named by assistant, not taken up): pair-register cost of a 32-bit FP version \[R29\]
- Evidence: docs/pdp64-isa.md:80 "64 bits each"; docs/pdp64-isa.md:9 quads are 64 bits; no 32-bit mode in spec/pdp64/pdp64.hbnf

### SP and FP registers
- Status: DONE — sp and fp are aliases of r14 and r13 in the grammar and docs (latest decision 2026-10-21 \[R168\])
- Decided: 2026-10-21 decided: sp and fp should already be aliases in the grammar: "you don't need a third header for that". \[R168\]
- Rationale: "make sp r14 and fp r13 to match the vax" \[R137\]
- Rationale: sp and fp as aliases: "you don't need a third header for that" \[R168\]
- Precedent: VAX-11 (chosen; named by author): SP is R14 and FP is R13 to match it \[R137\]
- Evidence: docs/pdp64-isa.md:89 "SP is R14 and FP is R13, matching VAX"; spec/pdp64/pdp64.hbnf hot3/hot4 name "sp"

## toolchain

### Assembler syntax and names
- Status: DONE — numbers, labels, UTF-8 and ELF names as decided (latest decision 2026-10-21 \[R161\])
- Decided: 2026-10-21 decided: "the bareword with : terminal fully qualifies it" (digit-leading name followed by a colon is a label). \[R161\] (changes 2026-10-21 'Asks whether some labels start with digits')
- Rationale: "don't be TOO strict; we don't need to copy asv7 warts or anachronisms" \[R157\]
- Rationale: "numbers default to decimal, the 0x 0b 0o notation is for when we want it" \[R158\]
- Rationale: "names/labels just have to follow ELF syntax. and make it utf8 clean" \[R160\]
- Rationale: "/ is div, not a comment. \<\> is not a string, numbers and strings are in C syntax" \[R159\]
- Precedent: asv7 (V7 as) (rejected; named by author): not to copy its warts or anachronisms \[R157\]
- Precedent: V7 octal-default numbers (rejected; named by author): numbers default to decimal \[R158\]
- Precedent: modern ELF symbol names (chosen; named by author): names and labels follow it \[R160\]
- Precedent: C syntax for numbers and strings (chosen; named by author): instead of V7 \<...\> strings and comment slash \[R159\]
- Evidence: docs/asm-syntax.md:19 "decimal by default (010 is ten), 0x, 0b or 0o"; :16 "UTF-8"; :14 "a name may start with a digit as long as the whole bareword is not a number (\`3dfx:\` is a label ...)"; :15 "a bareword of digits only, defined with a colon, is a numeric local label"
- Doc differs: docs/implementation-status.md (appendix E, the LLVM assembler): llvm-mc has no names that start with a digit, no non-ASCII names and no literal pool, which asm-syntax.md allows

### Benchmark freeze and fixes against stock
- Status: DONE — the stock comparison was re-measured after the fixes (latest decision 2026-10-18 \[R113\])
- Decided: 2026-10-18 decided: "fix the 1 2 3 places where ours is worse than stock!"; inline "is a hint, not a command" \[R113\] (changes 2026-10-18 'no new fixes until we are done our benchmarking')
- Rationale: "these tests are just to a) compare apples to apples and b) show what compiles and what doesn't" \[R106\]
- Rationale: "fix the 1 2 3 places where ours is worse than stock! they sound easy enough" \[R113\]
- Rationale: "in modern c, inline is a hint, not a command" \[R113\]
- Precedent: pcc (chosen; named by author): comparison baseline; fix places where ours is worse \[R113\]
- Precedent: modern C inline semantics (considered; named by author): inline is a hint, not a command \[R113\]
- Evidence: commits b118ccc "re-measured after merging upstream; the fork now contains the stock it is compared with", 285188d "fair-set numbers on aarch64, amd64, i386, pdp11 and vax"

### Benchmark report and corpus
- Status: DONE — report generator is incremental and compares stock, ours, gcc, clang (latest decision 2026-10-19 \[R114\])
- Decided: 2026-10-19 decided: "no need to do redundant work" \[R114\]
- Rationale: "no need to do redundant work" \[R114\]
- Rationale: pdp11 and vax on the same corpus: "that way it is apples to apples" \[R100\]
- Rationale: stock pcc built "so we can see how much difference our dmr changes made for all platforms" \[R95\]
- Precedent: Lua and SQLite (chosen; named by author): fetch them as test corpora, use for each arch \[R93\]
- Precedent: pcc (chosen; named by author): baseline to measure the dmr changes against \[R95\]
- Precedent: clang (considered; named by author): asked which backends pcc and clang share; test all \[R94\]
- Evidence: toolchain commit 0b8c513 "corpus tools: incremental results"; tools/corpus-report.py; doc/SIZE-REPORT.md

### Dead-code elimination (dce)
- Status: DONE — dmr finished, then dce stages done (latest decision 2026-10-17 \[R70\])
- Decided: 2026-10-17 changed: "we should finish dmr before dce; dmr is done when the only files larger are because of more correct code" \[R70\] (changes 2026-10-17 'actually your dce plan looked pretty solid')
- Rationale: "dmr is done when the only files larger are because of more correct code" \[R70\]
- Precedent: dmr cc (chosen; named by author): finish matching it before dce work \[R70\]
- Evidence: pcc:README.md "-xdce (mip/regs.c, cc/ccom): dead assignments and unreachable blocks are removed on the flow graph"
- Left: Left (potential): const substitution for #ifdef is not recorded as done

### Dual-encoding toolchain, mnemonics and integration
- Status: DONE — integrated branch merged into main (latest decision 2026-11-04 \[R339\])
- Decided: 2026-11-04 decided: "i meant merge also": merge the integrated branch into main. \[R339\]
- Rationale: approved fused pairs for 16 and 32 reg versions: "then we will see how well the optimizer does" \[R329\]
- Rationale: sj optimizations "should have been folded into -xdmr flag, they are the vax optimizations from steve johnson pcc" \[R333\]
- Precedent: Steve Johnson pcc VAX optimizations (chosen; named by author): fold into the -xdmr flag \[R333\]
- Evidence: commit a71f491 "Merge enc-int: the pdp64/16 and pdp64/32 encodings"; errata 87, 88, 90 (87 superseded by 94, and 94 in part by 122 and 123: the dual-encoding code is removed and one encoding remains; the merge stays as history in the tag \`pre-code-removal\`)

### Fair corpus and compiler comparison
- Status: DONE — sjpcc and dmr cc are in the fair comparison (latest decision 2026-10-19 \[R132\])
- Decided: 2026-10-19 decided: "on vax and pdp11 we should also be including sjpcc and dmrcc in the evaluation/comparison" \[R132\]
- Rationale: "the 'fair' corpus should also eliminate the things that gcc and stock can't compile at all" \[R131\]
- Precedent: sjpcc (chosen; named by author): include in the evaluation on vax and pdp11 \[R132\]
- Precedent: dmr cc (chosen; named by author): include in the evaluation on vax and pdp11 \[R132\]
- Precedent: gcc (chosen; named by author): files gcc cannot compile excluded from the fair corpus \[R131\]
- Precedent: pcc (chosen; named by author): files stock cannot compile excluded from the fair corpus \[R131\]
- Evidence: v7unix-toolchain:tools/corpus-report.py:98 ORIG = pdp11 dmr-O, vax sjpcc-O; doc/SIZE-REPORT.md "compared ... V7 dmr cc and 32V pcc"

### Grammar as the single source of truth
- Status: DONE — grammars are the source; python pivot undone (latest decision 2026-11-04 \[R335\])
- Decided: 2026-11-04 decided: "grammar is the source of truth; undo your pivot to python" \[R335\] (changes: undoes an earlier pivot to python, not a record in this batch)
- Rationale: "one change to the grammar, and nothing drifts downstream" \[R166\]
- Rationale: "i said grammar is the source of truth; undo your pivot to python" \[R335\]
- Rationale: "would be good to use the headers the grammar generates" for the hand-written pcc templates \[R167\]
- Rationale: ld, as and emulator "with hbnf grammars that share as much of a common core as they can" \[R156\]
- Precedent: hbnf (chosen; named by author): source of truth for the tools \[R335\]
- Precedent: Python pivot (rejected; named by author): "undo your pivot to python" \[R335\]
- Evidence: docs/errata.md:239 "89. The grammars are the source of truth of pdp64/16 and pdp64/32" (errata 94 keeps the source of truth for pdp64/32, spec/pdp64/pdp64.hbnf); commit 127d475 "generate the codec tables ... from the hbnf grammars; forms.json is gone"
- Left: Left (potential): use of generated headers for the hand-written pcc templates not recorded

### Long long support and libc helpers
- Status: DONE — long long helpers are in pcc (latest decision 2026-10-19 \[R129\])
- Decided: 2026-10-19 approved-proposal: "yes, go ahead with both fixes": constant-shift inlining and emit-on-use helpers \[R129\]
- Rationale: "if it can be fixed in pcc, then we fix it in pcc" \[R82\]
- Precedent: V7/32V libc side (rejected; named by author): asked to do longlong helpers on pcc side instead \[R81\]
- Evidence: pcc:arch/pdp11/ll.c, lowerll.c, genll.py; README.md "long long is a 64-bit memory object operated on by helper calls"; toolchain commit ebbef60

### Mnemonic and width spelling
- Status: DONE — assembler kept as is; width spelling fixed by the grammar (latest decision 2026-10-21 \[R183\])
- Decided: 2026-10-21 decided: "let's keep the asm as it is for now we will revisit it later." \[R183\] (relation unclear)
- Rationale: "add.d16 is ugly. we need some other way to flag bit width etc." \[R181\]
- Rationale: "putting f in front for floating point ops is ok, fadd and I guess fadd16 for 16 bit ops is fine" \[R182\]
- Rationale: "we aren't slavishly keeping the whole pdp-11 instruction set, we can drop unneeded ones" \[R138\]
- Rationale: "i want our assembler to follow that pattern in general" \[R180\]
- Precedent: PDP-11 (considered; named by author): not slavishly kept; unneeded instructions can be dropped \[R138\]
- Precedent: ror over rol (chosen; named by author): assistant made the case; assembler could map rol to ror \[R138\]
- Evidence: spec/pdp64-mnemonics.hbnf:196 "fadd16"; docs/asm-syntax.md unchanged style
- Left: Left (potential): add.d16 spelling and rol-to-ror mapping not decided

### Optimization rules (net win, correctness, speed, inlining)
- Status: DONE — small cheap gains are kept in the doc, each with an ablation switch (latest decision 2026-10-19 \[R133\])
- Decided: 2026-10-19 changed: "that rule of 'drop if gain is less than 1%' is wrong. any gain is welcome, as long as it doesn't require too many lines of code or slow the compiler down unacceptably" \[R133\] (changes: replaces an earlier rule 'drop if gain is less than 1%', not a line in this batch)
- Rationale: "any gain is welcome, as long as it doesn't require too many lines of code or slow the compiler down unacceptably" \[R133\]
- Evidence: pcc:doc/PDP64-OPT.md lists many small passes (-xno-minmax, -xno-mullea, -xno-bic); no 1% cutoff found

### Other
- Status: DONE — listed items mostly present; the musl question is open (latest decision 2026-10-13 \[R40\])
- Decided: 2026-10-13 decided: "put the fuzz and audit scripts into tools" \[R40\]
- Rationale and precedent: none stated in the sources
- Evidence: v7unix-toolchain:tools/pccfuzz.py, pccaudit.py (fuzz and audit scripts); commit 6f22473 "GNU case ranges"; status-check/pcc/doc/PDP64-OPT.md "-xno-minmax"
- Doc differs: The chain has no Now line for this group; the latest line (2026-10-21) is the abs/min/max one

### PDP-11 size against the dmr compiler
- Status: DONE — PDP-11 size work done (doscan not individually verified) (latest decision 2026-10-18 \[R80\])
- Decided: 2026-10-18 decided: "fix doscan's last 4 bytes" \[R80\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:README.md PDP-11 paragraph; doc/SIZE-REPORT.md "-3.2% / -4.2%" against V7 dmr cc; toolchain commit ebbef60 "VAX doscan fixed"

### Push requests
- Status: DONE — the pushed clone holds the work (latest decision 2026-10-19 \[R120\])
- Decided: 2026-10-19 decided: "push everything once the report finishes" \[R120\]
- Rationale and precedent: none stated in the sources
- Evidence: status-check/pcc master 41e5c36 (2026-11-07) holds the dmr, aarch64, long long and pdp64 commits (27bd244, 0f618dc, 866061c); toolchain repo is main...origin/main with nothing unpushed

### Root-cause fixes, no workarounds
- Status: DONE — crashes fixed as policy; fixes listed (latest decision 2026-10-17 \[R79\])
- Decided: 2026-10-17 changed: "no.... don't try and drop. fix it!" \[R79\] (changes: replaces R78, not a record in this batch)
- Rationale: "stop disabling shit. fix it" \[R74\]
- Rationale: "worth fixing rather than reverting" \[R71\]
- Rationale: "I'm ok with using 32 bit instead of 64 bit indexes, as long as it all stays correct" \[R75\]
- Evidence: pcc:README.md "Bug fixes found along the way" ("compiler crashes on register x \>\>= n and \*\*p++ = 0")
- Doc differs: Toolchain commit 6f22473 and others add regression tests; the open question of synthesizing a register afterward is a potential only

### SSA and pcc optimizations alongside dmr
- Status: DONE — spill-slot sharing is in; -xssa itself is off by default (latest decision 2026-10-13 \[R42\])
- Decided: 2026-10-13 approved-proposal: "try the spill-slot sharing for ssa first" \[R42\]
- Rationale: "if modern ssa can optimize dmr code even further, it should have a chance" \[R36\]
- Rationale: drop -xssa "until we fix the getnum bug" but run the others "after we already do the dmr opti" \[R37\]
- Precedent: dmr optimization pass (chosen; named by author): other optimizations should run after it \[R37\]
- Precedent: modern pcc SSA optimizations (considered; named by author): allowed alongside dmr; dropped meanwhile for getnum bug \[R36\]
- Evidence: pcc:README.md "spill-slot sharing sized from the temporaries' real types"; doc/PDP64-OPT.md:48 "slower and bigger on every program, both targets: off by default"

### Slot overlap fix
- Status: DONE — spill slots are sized from the real types and a long-lived temporary gets its own slot (latest decision 2026-10-13 \[R61\])
- Decided: 2026-10-13 decided: Reminds that he said to "fix amd64 overlapping slots instead of excluding it" \[R61\]
- Rationale: "instead of restricting hte optimization, how about just fix the slot overlap?" \[R59\]
- Rationale: "fix amd64 overlapping slots instead of excluding it" \[R61\]
- Evidence: commit 463988f "regs: a long-lived temporary spilled while rewriting a short one gets its own slot"; pcc:README.md "spill-slot sharing sized from the temporaries' real types"

### Squashed branch and git history
- Status: DONE — only master remains and the work is in feature commits (latest decision 2026-10-18 \[R112\])
- Decided: 2026-10-18 decided: "delete the fix branch too" \[R112\]
- Rationale: "hopefully you were squashing feature commits so our mis-steps aren't visible?" \[R85\]
- Evidence: git branch -a in status-check/pcc lists only master and origin/master; commit 27bd244 "long long: 64 bits on the pdp11 (helpers, lowering) and helpers on the vax"

### Upstream PortableCC
- Status: DONE — the upstream plan was written (latest decision 2026-10-19 \[R118\])
- Decided: 2026-10-19 decided: "look at the complete upstream git history for a pattern to what ragge accepts"; prepare a plan for "a series of pr" for him to merge, "one feature, one bugfix at a time" \[R118\]
- Rationale: "no need to do duplicate work" \[R117\]
- Rationale: prepare PRs "one feature, one bugfix at a time", using a "pattern to what ragge accepts" \[R118\]
- Precedent: pcc (chosen; named by author): keep tree up to date with it; keep upstream's fix \[R47\]
- Precedent: upstream git history (chosen; named by author): source for the pattern of what ragge accepts \[R118\]
- Evidence: v7unix-toolchain:UPSTREAM-PLAN.md "Written from the whole upstream history (5,481 non-merge commits ...)"; pcc-pr has branch fix-pdp11-relational-cmp pushed to remote mine
- Left: Left (beyond the Now line): the series of PRs themselves is not shown as submitted; not checked on GitHub

### VAX backend and VAX code size against 32V cc
- Status: DONE — VAX is smaller than 32V pcc -O (latest decision 2026-10-17 \[R72\])
- Decided: 2026-10-17 approved-proposal: "push, then do the VAX files" \[R72\]
- Rationale: "i think we should at least match the 32v cc in code size if not better it" \[R58\]
- Precedent: 32V cc (chosen; named by author): code-size baseline to match or beat \[R58\]
- Evidence: pcc:README.md "-O ... PDP-11 and VAX output is smaller than the original Unix compilers'"; toolchain commit 1d2afa3 "VAX numbers after ... casel liveness"

### VAX output for the 32V assembler
- Status: DONE — as32v built and installed; not labelled bsd (latest decision 2026-10-13 \[R53\])
- Decided: 2026-10-13 decided: "32v as output shouldn't be labelled as bsd" \[R53\]
- Rationale: "you will need to look at the original 32v source code since I'm not sure its pcc emitted the same as as the dmr compiler did" \[R52\]
- Precedent: 32V assembler (chosen; named by author): flag so the vax backend emits what 32v as accepts \[R51\]
- Precedent: dmr cc (considered; named by author): unsure the 32v pcc emitted the same \[R52\]
- Evidence: toolchain commit 7c56942 "as32v: the 32V VAX assembler built for the host, installed beside asv7"; Makefile.am:38 as32v

### aarch64 PR 47 reconciliation
- Status: DONE — Debian path, Mach-O variadics and GOT are in (latest decision 2026-10-19 \[R123\])
- Decided: 2026-10-19 approved-proposal: "yes, do both": Debian include path and Mach-O variadic calls \[R123\]
- Rationale: "this binary128 stub gives me pause" \[R122\]
- Rationale: "maybe all our aarch64 stuff can be submitted to the pr47 guy so our branch is just bugfixes and the dmr optimizations" \[R121\]
- Rationale: accepted from the assistant: Mach-O variadics are the real gap, since our Mach-O output uses the Linux convention \[R123\]
- Precedent: PR #47 aarch64 backend (chosen; named by author): compare ours with it and fold in anything good \[R119\]
- Precedent: Debian multiarch include path (chosen; named by assistant, accepted): /usr/include/aarch64-linux-gnu \[R123\]
- Precedent: Apple Mach-O variadic convention (chosen; named by assistant, accepted): fix variadic calls for Mach-O \[R123\]
- Evidence: commits b43f91e "aarch64 looks in /usr/include/aarch64-linux-gnu too (Debian multiarch)", 0041a94 "Apple's variable arguments on Mach-O", 4ffc68a "Mach-O ... GOT", 1017f82 "AArch64 against PR #47"

### aarch64 and dmr optimizations
- Status: DONE — aarch64 fixed and dmr optimizations ported (latest decision 2026-10-18 \[R88\])
- Decided: 2026-10-18 decided: "yes, fix aarch64 first, then port the dmr optimizations" \[R88\]
- Precedent: dmr optimization pass (chosen; named by author): port whatever can be ported to aarch64 once it works \[R87\]
- Evidence: pcc:README.md "AArch64 ... A new AAPCS64 LP64 back end ... a text optimizer under -xdmr"; arch/aarch64/peep.h

### aarch64 binary128 support
- Status: DONE — stages 1 to 3 are in (latest decision 2026-10-19 \[R124\])
- Decided: 2026-10-19 decided: "yes, go ahead with stage 3" \[R124\]
- Rationale: "this binary128 stub gives me pause" \[R122\]
- Precedent: libgcc \_\_addtf3 family (chosen; named by assistant, accepted): stage 3: arithmetic and conversions through library calls \[R124\]
- Evidence: commits f442f70 (storage, constants, ABI), 0f618dc (arithmetic as libgcc calls), 668072b (softfloat binary128); toolchain 698d4ad, 0b84f01

### aarch64 long double default (A64QUAD)
- Status: DONE — A64QUAD stays opt-in (latest decision 2026-10-19 \[R126\])
- Decided: 2026-10-19 changed: "3": keep long double off by default, A64QUAD stays opt-in until the runtime question is settled \[R126\] (changes 2026-10-19 'make A64QUAD the default')
- Rationale: accepted from the assistant: keep long double off by default, A64QUAD opt-in until the runtime question is settled \[R126\]
- Precedent: GNU libgcc runtime (considered; named by assistant, not taken up): option 1; depends on GCC being installed \[R126\]
- Precedent: own runtime tools/a64quad/tf.c (considered; named by assistant, not taken up): option 2; assistant's recommendation, not chosen \[R126\]
- Evidence: v7unix-toolchain:AARCH64.md:31 "done and off by default: build the compiler with -DA64QUAD"; "A64QUAD stays opt-in"

### as32v in the v7unix-toolchain repo and tool naming
- Status: DONE — as32v and the -v7 suffixes are in; the use of v7yacc is not checked (latest decision 2026-10-18 \[R104\])
- Decided: 2026-10-18 decided: "i think you need to use v7yacc for that" \[R103\]; changes his "it will install as 32vas alongside v7as" \[R102\]: "maybe v7unix-toolchain should change policy, instead of install v7as v7cc etc it should be asv7 ccv7 cppv7 etc, then we can do as32v etc" \[R104\]
- Rationale: port the 32V as to v7unix-toolchain: "would be useful" \[R101\]
- Rationale: rename to asv7 ccv7 cppv7 "then we can do as32v etc" \[R104\]
- Precedent: 32V assembler (chosen; named by author): port it into the v7unix-toolchain project \[R101\]
- Precedent: yacc (chosen; named by author): use it for the old-yacc grammar \[R103\]
- Precedent: v7as / v7cc prefix naming (rejected; named by author): change policy to asv7, ccv7, cppv7 suffixes \[R104\]
- Evidence: toolchain commit 7c56942 "v7-prefixed command names become -v7 suffixes (ccv7, asv7, ldv7)"; Makefile.am:38 as32v
- Left: use of v7yacc (j41256) not checked

### c2 pass and IR optimizer (optim2)
- Status: DONE — tree-form passes and c2 inside ccom exist (latest decision 2026-10-17 \[R65\])
- Decided: 2026-10-17 approved-proposal: "push and resume": push, then deferred addressing next \[R65\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:mip/optim2.c (tailmerge, looprot); README.md "cross-jumping and tail merging"; cc2/ and common/c2run.h hold the V7 c2 and the 32V c2 port
- Left: Left (potentials only): whether the remaining c2 tricks should move to optim2 or the templates stays unsettled

### dmr optimizations on other targets
- Status: DONE — porting study done and applied to x86 and aarch64 (latest decision 2026-10-13 \[R56\])
- Decided: 2026-10-13 decided: If 32v cc has such optimizations, "see if ant of them port to pdp11 and x86" \[R56\]
- Rationale: wants to see if the original 32v cc has optimizations "that aren't already part of the dmr package" \[R55\]
- Rationale: test on i386/amd64 by compiling pcc with them twice and verifying "output is byte identical" \[R54\]
- Precedent: 32V cc (chosen; named by author): original cc, checked for optimizations beyond dmr package \[R55\]
- Precedent: VAX and x86 platforms (chosen; named by author): final step after the pdp-11 backend is complete \[R41\]
- Precedent: dmr optimization pass (chosen; named by author): see if any port to pdp11 and x86 \[R56\]
- Evidence: v7unix-toolchain:DMR-OPTIMIZATIONS-OTHER-TARGETS.md "Which dmr-cc optimizations carry over to the VAX and x86 backends"; status-check/pcc README.md "-xdmr ... x86targets get common/x86peep.h"

### dmr optimizations: goal and scope
- Status: DONE — PDP-11 reached dmr size and the VAX work followed (latest decision 2026-10-17 \[R73\])
- Decided: 2026-10-17 decided: "once the vax code is correct go back and finish off the pdp11" \[R73\]
- Rationale: "i want us to d all his optimization AND BETTER" \[R38\]
- Rationale: "we don't have to be byte identical to dmr"; wants only "dmr byte count not necessarily byte order" \[R36\]
- Rationale: "if modern ssa can optimize dmr code even further, it should have a chance" \[R36\]
- Precedent: dmr cc (chosen; named by author): make the modern pcc pdp11 backend emit identical code, including optimizer \[R35\]
- Precedent: modern pcc -xssa (chosen; named by author): run in parallel with dmr optimizations \[R36\]
- Evidence: pcc:README.md "Brought to V7 dmr cc's size or below on V7's libc and commands"; doc/SIZE-REPORT.md "this fork's -O is -3.2% / -4.2%" against V7 dmr cc (pcc clone status-check/pcc, master 41e5c36)

### gcc cross-build and gcc comparison
- Status: DONE — gcc cross-built for pdp11 and vax and compared (latest decision 2026-10-19 \[R127\])
- Decided: 2026-10-19 decided: "regenerate the report when the pdp11 run finishes" \[R127\]
- Rationale: accepted from the assistant: restart make with -O1 -g0, objects kept, probably 2 to 3 times faster \[R116\]
- Rationale: accepted from the assistant: PDP-11 build in parallel finishes both about as soon as VAX alone \[R115\]
- Precedent: GCC 4.7 or older (plain C) (considered; named by assistant, not taken up): would avoid C++ host build; judged not worth the trouble \[R116\]
- Precedent: gcc cross-compilers for pdp11 and vax (chosen; named by author): built and measured as comparison reference \[R127\]
- Evidence: pcc:doc/SIZE-REPORT.md "gcc 14.2 is built as a cross-compiler for them (pdp11-aout, vax-netbsdelf)"; toolchain tools/corpus-gcc-cross.sh

### hbnf layout grammar and templates
- Status: DONE — mustache templates are gone from the manual chain (latest decision 2026-11-05 \[R347\])
- Decided: 2026-11-05 decided: With rewrite rules etc, "the mustache templates are going away"; asks whether hbnf already uses its own built-in mustache. \[R347\]
- Rationale: "this is the type of application where "rewrite rules" and "text transforms" come into their own in hbnf." \[R346\]
- Rationale: One grammar matches "the opcodes and the bit layouts", but what is emitted can be "either the assembler/linker or the svg charts". \[R345\]
- Precedent: Mustache (rejected; named by author): "the mustache templates are going away" once rewrite rules exist \[R347\]
- Precedent: hbnf %emit{} %action{} with prologue/epilogue (considered; named by author): asks if C code in the grammar can do the job until rewrite rules land \[R350\]
- Precedent: hbnf C, Ada, Rust and Zig backends (considered; named by assistant, not taken up): chart backend would sit alongside them \[R346\]
- Precedent: Python chart generator (considered; named by assistant, not taken up): interim, behind one layout model \[R346\]
- Evidence: spec/pdp64-layout.hbnf; errata 93; grep of tools, spec and docs/manual-src finds mustache only in tools/build-hbnf.sh:4 (a comment on the alpine image), tools/declog/publish.py:12 (a path label) and docs/manual-src/appendix-g-evolution.md:212 (the record of this rejection); errata 94 supersedes the three manuals of errata 93 and keeps the chart generation from the grammar
- Doc differs: the hbnf repo's own design documents (commit 1133cf1, 2026-11-09) keep a built-in Mustache-style template renderer (HBNF\_Template); only the pdp64's own mustache templates are gone
- Left: Left (potentials): one hbnf grammar that emits charts and assembler; hbnf rewrite rules

### hbnf version
- Status: DONE — latest hbnf in use (latest decision 2026-11-04 \[R335\])
- Decided: 2026-11-04 decided: "use latest hbnf" \[R335\]
- Rationale and precedent: none stated in the sources
- Evidence: docs/errata.md:239 "builds hbnf dd34982 (origin/main, 2026-11-03)"; tools/build-hbnf.sh; buildabook commit d78be68 "update to the latest hbnf"

### ld64 relaxation
- Status: DONE — relaxation is default, done in as64 and ld64 (latest decision 2026-11-04 \[R336\])
- Decided: 2026-11-04 approved-proposal: "yes do relax by default": pcc driver passes --relax for pdp64/16 and pdp64/32; plain assembler stays off. \[R336\]
- Rationale and precedent: none stated in the sources
- Evidence: commit 93a0dc7 "relaxation is the default for pdp64/16 and pdp64/32"; errata 91
- Doc differs: errata 91 says "no tool needs a flag"; the pcc driver is not built for pdp64 (doc/PDP64-OPT.md:20 "cc/cc, the pcc driver, is not built for pdp64")

### m68k backend
- Status: DONE — m68k left as it was (latest decision 2026-10-13 \[R45\])
- Decided: 2026-10-13 changed: "leave m68k as-is, move on to the others, i86 etc"; simh is "a good enough proxy" for pdp11 testing \[R45\] (changes 2026-10-13 'do m68k next')
- Rationale: simh is "a good enough proxy" for pdp11 testing \[R45\]
- Rationale: "check that these space optimizations don't run into speed pessimizations" \[R44\]
- Precedent: SIMH (chosen; named by author): proxy for pdp11 testing instead of building m68k backend \[R45\]
- Evidence: pcc:doc/SIZE-REPORT.md "The other back ends (arm, m68k, mips, mips64, sparc64) compile only part of the corpus"

### mips backend
- Status: DONE — mips paused as decided (latest decision 2026-10-13 \[R49\])
- Decided: 2026-10-13 changed: "pause the mips backend, let's make vax run sweet" \[R49\] (changes 2026-10-13 'fix mips first, then leaf frames')
- Rationale: "let's make vax run sweet" \[R49\]
- Precedent: VAX backend (chosen; named by author): prioritised over mips \[R49\]
- Precedent: nova second pass in pcc (considered; named by author): if pcc ships it, bring the dmr c2 pass in too \[R49\]
- Evidence: pcc:doc/SIZE-REPORT.md "other back ends ... compile only part of the corpus"

### pcc work items approved in the first dmr session
- Status: DONE — the byte-increment, label and register-variable items are in; PDP-11 matches dmr (latest decision 2026-10-12 \[R39\])
- Decided: 2026-10-12 decided: "do the inch folding of course" \[R39\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:arch/pdp11/local2.c incb/decb (6 hits), table.c (2); README.md PDP-11 paragraph

### pdp64 ABI and long double
- Status: DONE — errata 46 written (latest decision 2026-10-22 \[R240\])
- Decided: 2026-10-22 approved-proposal: "write the errata for ... P13" (long double ABI). \[R240\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed" \[R152\]
- Rationale: accepted from the assistant: long double same as double, "There is no hardware for more" \[R154\]
- Rationale: accepted from the assistant: char signed, matching the PDP-11 and x86 tradition, MOVZB for unsigned \[R154\]
- Precedent: PDP-11 and x86 signed char (chosen; named by assistant, accepted): signed char matches their tradition \[R154\]
- Precedent: modern ELF symbol names (no underscore) (chosen; named by assistant, accepted): instead of V7 leading underscore \[R154\]
- Precedent: software 128-bit long double (considered; named by assistant, not taken up): alternative to same-as-double \[R154\]
- Evidence: docs/errata.md:196 "46. DECISION (the author's pick, 2026-10-22; decisions-pending P13): long double stays the same as double"; docs/abi.md:9 and docs/manual-src/appendix-d-abi.md:12 "long double is double"
- Left: the open ABI items J.D.1 (stack alignment) and J.D.2 (binding, landing pads and the PLT stub after version 1) of appendix J

### pdp64 measurement against clang and gcc
- Status: DONE — fair corpus measured with the pdp64 tools (latest decision 2026-10-22 \[R209\])
- Decided: 2026-10-22 decided: gcc -Os and clang -Os figures exist, so "we only need to rerun the fair corpus with the pdp64 backend to compare". \[R209\]
- Rationale: gcc -Os and clang -Os figures exist: "we only need to rerun the fair corpus with the pdp64 backend" \[R209\]
- Rationale: "we already beat amd64 on the same code for size and are approaching parity in instructions" \[R223\]
- Rationale: "how little work went into optimizing the pdp64 backend that result against amd64 is pretty good" \[R366\]
- Precedent: gcc -Os (chosen; named by author): comparable for the pdp64 backend \[R202\]
- Precedent: clang -Os (chosen; named by author): comparable for the pdp64 backend \[R202\]
- Precedent: other backends with -Os (considered; named by author): asked how pdp64 compares with them \[R223\]
- Precedent: gcc -Os (considered; named by assistant, not taken up): suggested comparison column for RV64 \[R366\]
- Evidence: tools/pdp64size.py; commit 98d0ce2 "pdp64size measures gcc -Os and clang -Os for amd64 on the same preprocessed files"; tools/arch-compare/ (commit f075669 "static size of the 841-file corpus for pdp64/32 against pcc amd64 and i386 and clang for RISC-V, AArch64, x86, Arm, MIPS64"; 384b5ac "GCC rows dropped")
- Left: Left (potential): the GCC rows were dropped from tools/arch-compare, and riscv64 gcc -Os is not in pdp64size.py

### pdp64 pcc optimizations (dmr and sj)
- Status: DONE — dmr and sj optimizations are one family under -xdmr (latest decision 2026-11-04 \[R334\])
- Decided: 2026-11-04 decided: "as with dmr, the sj optims were sometimes specific to the backend, but sometimes applied to all backends" \[R334\]
- Rationale and precedent: none stated in the sources
- Evidence: pcc:doc/PDP64-OPT.md:106 "Johnson ('sj') optimizations belong with -xdmr"; section "### Johnson" line 127

### pdp64 toolchain elements and build plan
- Status: DONE — as64, ld64, sim64, backend and qemu exist (latest decision 2026-10-22 \[R186\])
- Decided: 2026-10-22 unclear: "also the sim64, qemu support, etc."; apparently also to be moved along with toolchain commits, details not visible \[R186\] (relation unclear)
- Rationale: "could even use hbnf to help with the opcode layout. good test case for it" \[R152\]
- Rationale: "of course floats go in general registers that is the way the pdp64 is designed" \[R152\]
- Rationale: "why aren't sp and fp already in as aliases? you don't need a third header for that" \[R168\]
- Precedent: ELF (chosen; named by author): "actually.... elf linker is ok" \[R149\]
- Precedent: asv7 and ldv7 (chosen; named by author): port them to assemble and link pdp64 \[R148\]
- Precedent: V7 a.out with 64-bit variant (considered; named by assistant, not taken up): assistant's alternative to ELF64 output \[R152\]
- Precedent: GNU ld / lld (considered; named by assistant, not taken up): no back end for this ISA; judged more work \[R152\]
- Evidence: as64, ld64 and sim64 accept \`-m pdp64\` only (as64/as64.c usage); as64/as64.c, ld64/ld64.c, sim64/sim64.c, qemu/README.md "qemu-system-pdp64 -M pdp64-virt", pcc:arch/pdp64/
- Left: The Now line is itself marked unclear; the elements it names are present

### simh testing
- Status: DONE — simh/V7 testing tools exist (latest decision 2026-10-13 \[R50\])
- Decided: 2026-10-13 decided: "you should test the pdp11 output on simh too using the v7 disk image" \[R50\]
- Precedent: SIMH (chosen; named by author): test pdp11 output on it \[R50\]
- Precedent: V7 disk image (chosen; named by author): used for the simh tests \[R50\]
- Evidence: v7unix-toolchain:tools/dmrtest.sh and corpus.py mention simh; tools/emutest.py

### softfloat mknormal fix
- Status: DONE — the subnormal rounding fix is in (latest decision 2026-10-19 \[R124\])
- Decided: 2026-10-19 decided: "do the mknormal fix" \[R124\]
- Rationale: accepted from the assistant: smallest subnormal doubles come out as zero (4.94e-324 should give 1), a candidate small fix \[R124\]
- Evidence: commit 23a14d3 (2026-10-19) "softfloat: a decimal constant in the subnormal range is rounded once" (common/softfloat.c)

### x86 backend changes
- Status: DONE — x86 changes are in (latest decision 2026-10-13 \[R57\])
- Decided: 2026-10-13 decided: "do the x86 ones first, then vax" \[R57\] (relation unclear)
- Rationale: "a win is a win, take it." \[R57\]
- Precedent: dmr and VAX tricks (chosen; named by author): document how they worked and bring them to x86 and other backends \[R57\]
- Precedent: VAX pcc as good as dmr on PDP-11 (considered; named by author): remarked it sounds like VAX pcc was about as good \[R57\]
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

# Where the current docs or code differ from the decisions (41)

- Opcode field and parcel layout (6-bit opcode): docs/encoding-proposal.md:27 prefix of 1 to 16 bits, not opcode(6)
- Register names (r16): docs/pdp64-isa.md:80 says "Sixteen registers"; its header (:7) says the register file below is that of pdp64/r20
- Register count (16 or 32): docs/pdp64-isa.md:80 "Sixteen registers" (the instruction-set text of the original encoding r20, declared at :7 as such, one of the two earlier iterations; not rewritten for 32 registers)
- Tagged pointers: docs/pdp64-isa.md:1137 says the three bits come from data alignment, not instruction alignment (the "bottom bit" idea was replaced)
- Stack alignment: docs/abi.md:10 and appendix D (D.1) say multiple of 8, not 2
- Physical address width and device windows: the simulator, QEMU and spec/pdp64-system.hbnf map 40 bits and put the devices from 0x8000000000 (docs/implementation-status.md, chapter 6, 6.6.2 and 6.7.1); the 40-bit width is the minimum, so the rule is met
- Integer abs/min/max and conditional select: docs/errata.md item 23 says AESC sub-opcodes 0x08 and 0x10-0x13 (native; marked superseded by errata 98); the grammars (spec/pdp64-mnemonics.hbnf, the encoding grammars), as64, sim64, pcc, QEMU and LLVM still treat the five words as native until the expansion is decided
- Constant-time execution: docs/decisions-pending.md:124 says "proposed: option 3 (a core set always constant-time plus a DIT bit"; docs/pdp64-isa.md has no DIT
- Root-cause fixes, no workarounds: Toolchain commit 6f22473 and others add regression tests; the open question of synthesizing a register afterward is a potential only
- \-xdmr flag and default PDP-11 output: README.md:168 says "Without -xdmr the generated code differs from stock only through the bug fixes below"
- QEMU and LLVM targets: handoff.md:6 and :113: the build machine has 3.9 GB RAM, the move to a bigger machine is not recorded
- QEMU and LLVM targets: qemu/README.md:41-51 memory map still has device space behind bit 39 of the physical address (timer 0x8000000000, console 0x8000001000), against errata 97 (no address bit selects device space) and errata 102 (40 to 64 bits); the QEMU walker has three levels only, against errata 96
- QEMU and LLVM targets: the QEMU machine has no virtio device and no PCI Express root complex (docs/implementation-status.md, chapter 5.14), against errata 95 (virtio across the board)
- QEMU and LLVM targets: llvm/README.md (a status note, errata 122): the LLVM back end is frozen; its machine-code layer (about 5,000 lines) encodes the original r20 encoding (parcel 0 = len:2 opc:6 reg:4 low:4, sixteen registers, page 2) throughout, while as64 now produces only the prefix-coded encoding of spec/pdp64/pdp64.hbnf, so llvm-mc and as64 no longer agree, and the checks that compared them (llvm/check.sh, oracle.py, forms.py, negative.py, runsim.py, tools/gen-llvm-td.py) were removed (errata 123 \[R375\]); the body of the README still describes milestone M1 and an oracle that is gone
- Assembler syntax and names: docs/implementation-status.md (appendix E, the LLVM assembler): llvm-mc has no names that start with a digit, no non-ASCII names and no literal pool, which asm-syntax.md allows
- ld64 relaxation: errata 91 says "no tool needs a flag"; the pcc driver is not built for pdp64 (doc/PDP64-OPT.md:20 "cc/cc, the pcc driver, is not built for pdp64")
- hbnf layout grammar and templates: the hbnf repo's own design documents (commit 1133cf1, 2026-11-09) keep a built-in Mustache-style template renderer (HBNF\_Template); only the pdp64's own mustache templates are gone
- Other: The chain has no Now line for this group; the latest line (2026-10-21) is the abs/min/max one
- Git history, merging and pushing: git status: untracked c64stuff.txt, chat02.txt and tools/declog/ are not pushed; docs/decision-log/ is deliberately local (.gitignore, commit 8cb79b7)
- README: README.md:8 appendix list (see Left)
- Decisions document: docs/errata.md is a separate file, not inside decisions-pending.md; decisions-pending.md is not linked from README text of rule 'don't link it' (README does link it at the principles section)
- Manual: deliverable and chapter order: order bus, graphics, boot, drivers (index) differs from the 'boot, device driver, graphics' of R279 and 'bus, blitter, boot' of R280; the later j79473 is the one followed
- Manual purpose, style and notation: docs/manual-src/09-isa.md:104 (9.3.8) "the mask is 32 bits" and :340 (9.11.1) give no binary form
- Documentation style rules: the "What was checked" sections of manual chapters 2 to 6 cite ... source trees (qemu-src, facetlang/unixtree, kernel-src), added by errata 111 to 119 after this rule
- Velinsky link: manual 1.1 commentary no longer carries it: errata 120 moved it to appendix H, since the manual body holds decided material only
- Manual body and the appendices Proposed, Deferred and Open items: docs/manual-src/appendix-j-open.md holds only "There are no open items" (the entries are assembled from appendix-parts/\*-open.md into docs/manual/\*/appendix-j-open.md)
- Names kept out of the manual: Q64 and the three native device names: docs/pdp64-q64-bus.md and docs/c64-devices-from-chat.md still use the names Q64 and BLT64, VIC-64X, SID-64X; the decision names the manual only
- Status document as the source of truth: every Doc differs line of the ledger files lists a document that does not yet follow it
- Mashup of PDP-11 with C64 / M8502: none found
- Design priority list: docs/priority-lists.md:120 still says "(For you to write. ...)" above the author's annotations
- Q64 bus: DMA design, document and PCI Express base: docs/pdp64-q64-bus.md:25 "the transaction definitions (widths, bursts, arbitration, timing) are not written anywhere in this repository" while the manual body now defers to PCI Express's own transactions (2.3.4)
- Physical address bit that selects device space: docs/decisions-pending.md:123 P19 row still reads "\*\*DECIDED\*\* (the author, 2026-10-22: \\"bit 39 is right\\", errata 60)" with no superseded mark; qemu/README.md:7, :51 and :75 and the QEMU memory map (qemu/hw-pdp64/virt.c) still use bit 39 (listed in docs/implementation-status.md:9)
- Bus update to virtio-only: docs/decisions-pending.md:659 row Q10 and :908 "Q10. Devices are eight memory-mapped registers plus DMA" are not marked superseded; docs/c64-devices-from-chat.md:62 and docs/CHANGES-SINCE-R20.md:754 still say eight registers
- C64 island: 8502 registers readable from outside: the C128 with its 8502 and compatibility island is an optional device on the bus (docs/manual-src/03-graphics.md:402 "\*\*3.16.4\*\*"), so the island's register access is not in the manual body
- Device initialization protocol: docs/manual-src/04-boot.md:264 states the register write in the words of the eight-register devices that errata 95 withdrew
- Device register model: native 8-register devices to virtio: docs/decisions-pending.md:659 row Q10 and :908 "Q10. Devices are eight memory-mapped registers plus DMA" are not marked superseded; docs/CHANGES-SINCE-R20.md:754 and docs/c64-devices-from-chat.md:62 still say eight registers
- Crypto and random-number devices: errata 85 records decisions that the chain shows only as the "we'll go along those lines" approval of OpenBSD's recommendations, not each item
- First operating system port: docs/errata.md:114 entry 30 and :165 entry 30a keep the older text as history (marked superseded by 41)
- Exception and interrupt entry: docs/decisions-pending.md:508 says "I extended it to interrupts, which you did not explicitly say" (flagged for the author to confirm)
- Page-table levels: docs/decisions-pending.md:734 "3 levels, 39-bit (current)" and its listing of four levels as a rejected-by-default option (errata 96: the question stays there as the record of the options); the QEMU walker, the simulator and the emulator implement three levels only (docs/implementation-status.md)
- Dedicated core classes: docs/errata.md:226 entry 76 is still headed "PROPOSAL (the author's recommendation" and records it as a proposal; docs/smp-decisions.md:12 "The dedicated-core proposal (graphics, network, audio) is a proposal"; the manual now tags it (D) under the approval rule of errata 121

# Decision briefing: open questions and decisions under review

- Each item gives where things stand, the referents you named or liked (feature, source system, your words), 5 or 6 options with rationale, costs and precedents, and a recommendation that is the briefing agent's, not a decision
- Items marked QUESTION are open; items marked REVIEW are decisions you already made (the CURRENT option is flagged), listed so you can change them
- Precedents are marked verified (a path on this machine) or unverified (general knowledge, not checked); `(your referent [id])` marks a precedent that you named or accepted yourself
- Byte and instruction counts in the instruction-set items are estimates unless the text says measured

## Decisions recorded after this ledger was built (2026-11-09 and 2026-11-10)

- These supersede the rows above where they differ; each is in docs/errata.md
- Errata 94: pdp64/32 is the pdp64; r20 and pdp64/16 stay as the documented comparison, nothing removed (superseded in part by errata 122 and 123 below)
- Errata 95: virtio across the board (supersedes errata 29, the eight-register part of 49, and 61)
- Errata 96: page tables of 3, 4 or 5 levels (39, 48, 57 bits), level count discoverable at runtime
- Errata 97: no physical-address bit selects device space
- Errata 98: abs, min, minu, max, maxu are assembler aliases; expansion and the select are open; the build still encodes them natively
- Errata 99: the FPGA clock target is 200 to 300 MHz; the per-board estimates stay estimates
- Errata 100: R7 is not a view of the program counter
- Errata 101: the disk is virtio-blk
- Errata 122 [R374]: r20 and pdp64/16 are previous iterations, no longer CPUs with manuals; pdp64/32 is the pdp64; there is one manual (2026-11-10)
- Errata 123 [R375]: the code, data and tests of r20 and pdp64/16 are removed after the tags pre-single-cpu and pre-code-removal; there is one target, pdp64 (2026-11-10)
- Errata 102: physical address of at least 40 and up to 64 bits, devices anywhere except the first few pages; open: how many pages, width discovery, the page-table entry

## Briefing A: the physical address, the page table and how software learns them

Common facts used by every item below (all read in this repository unless marked):
- The page-table entry today: bit 0 V, bits 1-5 R W X U G, bits 6-7 A D, bits 8-9 MT (memory type), bits 10-11 and 40-63 reserved and must be zero (a set reserved bit is a page fault), physical page number (PPN) in bits 12-39, 28 bits, which is a 40-bit physical address (docs/manual-src/06-kernel.md:90; qemu/target-pdp64/gen/pdp64-consts.h:420-421; qemu/target-pdp64/mmu.c:24 `PTE_RESERVED`).
- Walk: 9 bits per level over 4 KB pages; 3, 4 or 5 levels give 39, 48, 57-bit virtual addresses; PTBR holds the physical address of the top table; leaves map 1 GB / 2 MB / 4 KB at levels 2/1/0 and 512 GB / 256 TB at levels 3/4 (06-kernel.md:86, :92).
- The vector table is 512 entries of 8 bytes = exactly 4096 bytes, at physical address VBR + 8 x vector, and VBR is zero at reset (06-kernel.md:29, :35; 04-boot.md:23). So the vector table alone is one page at address 0 until the kernel moves VBR.
- Block 0 (512 bytes) is read to "physical address 0x1000 (an address to be chosen)" (docs/boot.md:276); r1 points to the boot-information block, r14 is the top of the first 64 KB (04-boot.md:23). The boot-information block "names the memory ranges, the core count, the address of the root complex" (04-boot.md:52).
- Devices are found by PCI Express enumeration; "where the configuration space and the windows of the functions sit ... is unspecified" (02-bus.md:65, :79). The simulator, QEMU and spec/pdp64-system.hbnf:92-98 still put devices at 0x8000000000 and still check the memory type of a page against bit 39 (common/pdp64exec.h:60 `pdp64_pte_space_ok`; qemu/target-pdp64/mmu.c:~89).
- System registers 0-12 are defined; "13 and up: reserved (feature and identification registers are proposed here)" (06-kernel.md:77-78). No register reports levels or width (06-kernel.md:88 `6.4.1a`, "not specified").
- Verified precedents on this machine, in the QEMU source at qemu-src (called QEMU below): RISC-V Sv39/48/57 = satp modes 8/9/10 (target/riscv/cpu_bits.h:721-726), PPN at PTE bit 10, mask 0x3FFFFFFFFFFC00 = bits 10-53 (cpu_bits.h:745-748), flags N and PBMT in bits 63-61, reserved 60-54 (cpu_bits.h:738), default reset vector 0x1000 (cpu_bits.h:753); an unsupported satp mode write leaves satp unchanged (target/riscv/tcg/csr.c:1951-1990 `validate_vm`, `legalize_xatp`); QEMU's riscv virt board: debug 0x0, boot ROM 0x1000, CLINT 0x2000000, UART 0x10000000, virtio 0x10001000, PCIe ECAM 0x30000000, PCIe MMIO 0x40000000, DRAM 0x80000000 (hw/riscv/virt.c:86-106). x86: CPUID leaf 0x80000008 returns physical bits in EAX[7:0] and virtual bits in EAX[15:8] (target/i386/cpu.c:9204-9208), 57-bit virtual if CPUID.7.0:ECX LA57 else 48 (cpu.c:8602-8609), PTE address mask bits 51:12 (target/i386/cpu.h:340). AArch64: ID_AA64MMFR0 PARANGE field in bits 3:0 (target/arm/cpu-features.h:295), the table of physical sizes 32, 36, 40, 42, 44, 48, 52 (target/arm/ptw.c:112-119), with 52 bits (PS=6) putting address bits 51:48 elsewhere in the descriptor (ptw.c:2110 comment). LoongArch: CPUCFG1 fields PALEN (bits 11:4) and VALEN (bits 19:12) (target/loongarch/cpu.h:113-114) and a page-walk control register PWCL with a base and width per directory level (target/loongarch/cpu-csr.h:95-102). Tags: "(verified: QEMU file:line)" below means these.
- Numbers computed here: 2^50 bytes = 1 PiB, 2^52 = 4 PiB, 2^57 = 128 PiB, 2^64 = 16 EiB. A 64-bit physical address needs a 52-bit page number (bits 12-63); the author's word was "petabytes" (errata 97), which 52 bits already covers four times over.

---

### Q1 The first few pages (QUESTION)
- What it is: the author's rule (2026-11-10, errata 102) is that device windows can go anywhere in physical space "except the first few pages where the boot stuff is loaded"; the number of pages and the contents are not fixed (02-bus.md:19, 04-boot.md:23).
- What it is: it is a reservation (a range of physical addresses that no device window may overlap, so the boot ROM and the first stage can assume plain memory there).
- Why it matters: kernel - the vector table, the boot-information block and the early stack must live somewhere known before translation is on; compiler - none; hardware - the root complex must refuse to decode a window below the limit, and the boot ROM's load address and the reset VBR are wired to it; manual - 2.1.6, 4.2.3 and boot.md all say "not decided".
- Where things stand: author, errata 102 (2026-11-10): "mapping can be anywhere except the first few pages where the boot stuff is loaded." Block 0 at 0x1000 "to be chosen" (boot.md:276); vector table is 4096 bytes at VBR=0 (06-kernel.md:35); r14 = top of the first 64 KB (04-boot.md:23); boot-information block size not specified (04-boot.md:52, boot.md:161 lists its fields: memory ranges, boot device, console, core count, device table, command line, ABI version, checksum). The simulator and QEMU have RAM at 0 and devices at 0x8000000000 so they meet any choice.
- Referents you named or liked:
  - PDP-11 boot, from PDP-11: "can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0? (not precisely true, but directionally true)" [R256]; stance: chosen
  - boot block offset, source system not named: "and follow the majority as far as boot block offset" [R261]; stance: chosen
  - I/O space (memory low, I/O above), from VAX: "it should be noted in the book how the vax does this io space idea" [R281]; stance: considered
  - UEFI boot, from UEFI: "then look into uefi; is it worth it at all?" [R256]; stance: considered
  - disk label, from GPT: "we will have the gpt wrapper for the disk label" [R260]; stance: chosen
- Option 1 - Two pages (8 KB): page 0 is the vector table, page 1 holds block 0 at 0x1000 and the boot-information block follows it.
  - Rationale: the smallest reservation that holds what the documents already name; a window can start at 0x2000.
  - Precedent: PDP-11 kept its trap vectors in the first 0-0377 octal bytes of memory, with the boot ROMs elsewhere (unverified: general knowledge); RISC-V QEMU virt keeps the debug region at 0x0 and the boot ROM at 0x1000, 0xf000 long, devices from 0x2000000 (verified: QEMU hw/riscv/virt.c:86-92). (your referent [R26])
  - Cost and risk: a 512-byte block 0 plus a boot-information block of a few hundred bytes plus a stack can overflow 8 KB once the table of devices grows; moving the limit later breaks every board that placed a window at 0x2000.
  - Fit: priority 4 (decoder compare is one constant); weak on 1 (little slack for error handling).
- Option 2 - 64 KB (16 pages), matching the r14 rule: everything below the top of the first 64 KB is boot territory.
  - Rationale: reuses a number the reset state already defines (04-boot.md:23, boot.md:277), so the reservation, the initial stack top and the load area agree; room for vectors, block 0, boot-information, a first stack and the second-stage loader.
  - Precedent: the PC reserves the first 1 MB of real mode for vectors, BIOS data and the boot sector loaded at 0x7C00 (unverified: general knowledge); the VAX console passes a boot block and a restart parameter block (RPB) that lives in low memory (unverified: general knowledge).
  - Cost and risk: costs 64 KB of address space, which is nothing at 40 bits or more; a board with RAM not starting at 0 would waste the rule.
  - Fit: strong on 1 (one rule, slack, errors cannot overlap); neutral on 4; Occam: no new number invented.
- Option 3 - 1 MiB (256 pages), the PC-style low megabyte.
  - Rationale: generous: room for a second-stage loader, a kernel image's first segment, a framebuffer handoff area and the SMP start pages.
  - Precedent: x86 real-mode megabyte and the legacy VGA window (unverified: general knowledge).
  - Cost and risk: wastes the low megabyte of a small-RAM FPGA board (memory is scarce there, boards have tens of MB); encourages sloppy use.
  - Fit: neutral; against Occam.
- Option 4 - Nothing fixed by the architecture: the platform states the limit in the boot-information block (or reads it from the root complex), the architecture says only that the first page is never a device window.
  - Rationale: "all rules are soft"; each board picks; the minimum of one page is enough for the vector table at VBR 0.
  - Precedent: RISC-V leaves the reset vector and memory map to the platform; QEMU virt uses 0x1000 as an implementation default (verified: QEMU target/riscv/cpu_bits.h:753) (platform choice, general knowledge).
  - Cost and risk: a loader and a kernel cannot assume anything about low memory: they must parse the block first, and r1 itself points into the reserved area; documents lose a number to point at.
  - Fit: weak on 1 (more cases to get wrong); good on 4.
- Option 5 - Move the boot area to the top of physical memory (or the top of the implemented space) rather than the bottom.
  - Rationale: leaves address 0 as an unmapped trap page (null pointers in physical mode are caught); the reservation moves with the implemented width, so no device ever collides with low RAM.
  - Precedent: the PDP-11 I/O page sat at the very top of its address space (verified in repository text: 02-bus.md:21 commentary; "constant in that page", from V7 drivers); x86 resets at 0xFFFFFFF0 at the top of the 4 GB (unverified: general knowledge). (your referent [R26])
  - Cost and risk: VBR = 0 at reset would have to change; every reset-state sentence (r14, block 0 address) is rewritten; the top depends on the width, which is open (Q2).
  - Fit: neutral; large documentation change for little gain.
- Option 6 - Reserve by type instead of by count: the root complex refuses windows only over pages the boot-information memory map marks as RAM or reserved (an address-map list like a BIOS memory map), with no "first few pages" at all.
  - Rationale: "a window anywhere" becomes true literally; boot data is wherever the map says.
  - Precedent: the PC BIOS E820 map and UEFI memory map list each range with a type (unverified: general knowledge); the pdp64 boot-information block already names memory ranges (04-boot.md:52). (your referent [R256])
  - Cost and risk: the enumerating software needs the map before it can place any window; the very first window decisions are made by the same code that reads the block; more code than a constant.
  - Fit: good on 1 only if the map is trusted; bad on Occam.
- Recommendation: MINE (P): Option 2, 64 KB, because the reset state already defines the first 64 KB through r14, so no new number is added (Occam), the vector table (one page) and block 0 (0x1000) fit with room, and the cost is nothing at 40 bits. Would change my mind: a board whose RAM does not start at 0, or a boot-information block over 8 KB (then Option 3 or 4).
- Would help you decide: the author's size for the boot-information block and the second-stage loader; whether the vector table stays at 0 after boot (VBR is relocatable). Cheap measurement: `grep -n "r14\|first 64" docs/boot.md` for the places to update.

### Q2 Discovering the implemented widths (QUESTION)
- What it is: how software finds out the physical address width (40 to 64) and the number of page-table levels (3, 4 or 5) the machine implements; the author wants it "discoverable easily at runtime" (R361).
- What it is: a feature register (a read-only register whose fields describe the hardware) or a probe (write a value and read back what stuck).
- Why it matters: kernel - it must choose the walk depth and the width of every PPN it writes without a build option (errata 96); compiler - none, except that user code that tags pointers needs to know which high bits are free (the canonical test bit is 38, 47 or 56, appendix C glossary, line 44); hardware - the register is a few flip-flops; manual - 6.4.1a and 2.1.6 both say "not specified"; the register table already holds "13 and up reserved: feature and identification registers are proposed here" (06-kernel.md:78).
- Where things stand: author, R361: "3 4 and 5 is good, as long as this info is discoverable easily at runtime. so, 39, 48, 57 bit is all fine. good thing we already had dmw in the design!"; errata 96 lists "the register or field that reports the level count" as still to do; errata 102 (b) says no register or field is defined for the physical width. Nothing exists in sim64, QEMU or spec.
- Referents you named or liked:
  - discovery register, source system not named: "as long as this info is discoverable easily at runtime" [R361]; stance: chosen
  - dmw, source system not named: "good thing we already had dmw in the design!" [R361]; stance: chosen
  - 5-level TLB, from Loongson: "what other parts of the design are effected if we have 5 level tlb like loongso[n]" [R360]; stance: considered
  - PC handling and pragmatism, from LoongArch64: "looking at loongarch64, they are pragmatic; what can we learn from them and adopt" [R135]; stance: considered
  - table levels and largest RAM, from any CPU: "what is the largest physical ram supported right now by any cpu? how many table levels?" [R352]; stance: considered
- Option 1 - A read-only feature register by `MFSR` (number 13): fields for physical bits, maximum levels, the set of levels supported.
  - Rationale: the cleanest answer to "easily": one instruction, one place, no side effects, no mode change; room for later feature bits; reading is always safe (priority 1).
  - Precedent: x86 CPUID leaf 0x80000008 and LA57 bit (verified: QEMU target/i386/cpu.c:9204-9208, :8602-8609); AArch64 ID_AA64MMFR0 PARange (verified: QEMU target/arm/cpu-features.h:295); LoongArch CPUCFG1 PALEN and VALEN (verified: QEMU target/loongarch/cpu.h:113-114). (your referent [R135])
  - Cost and risk: one system register number and a few gates; privileged only (user code that needs the canonical rule must ask the kernel, or see Option 5); a forever-fixed layout once code depends on it.
  - Fit: strong on 1 (cannot be wrong, nothing to probe), good on 6 (assembler: `mfsr r0,mmucfg`).
- Option 2 - Probe by write and read back (WARL, write-any-read-legal): the kernel writes the wanted level count into a field of `MMUCTL` (or the top of `PTBR`) and reads back; an unsupported value leaves the old one. Physical width: write all ones to a PPN-mask-bearing register and read what sticks.
  - Rationale: no new register, no new instruction; the hardware only masks.
  - Precedent: RISC-V satp: unsupported mode write is ignored (verified: QEMU target/riscv/tcg/csr.c:1951-1990); the privileged spec says the same (unverified: general knowledge); the width probe by writing ones is how a RISC-V pmpaddr or PPN width has been discovered (unverified: general knowledge).
  - Cost and risk: a write with a side effect (changes translation mode, needs `ISYNC`, can crash if translation is on); the probe code is longer than one `MFSR`; width probe needs a writable field of the right width, which may not exist.
  - Fit: weaker on 1 (a probe is a place for error); saves a register (Occam).
- Option 3 - Both: a read-only register reports the maximum and the supported set (a bit mask, one bit per level count), and a writable field in `MMUCTL` selects the current number, legal only if its bit is set.
  - Rationale: one read to learn what exists, one write to choose (the kernel may run 3 levels on a 5-level machine, for compatibility or to save walk cost); a bad write is detectable: the mask says no.
  - Precedent: RISC-V keeps a bitmask of supported modes in the platform and legalizes the satp write against it (verified: QEMU target/riscv/cpu.c:512-529 `get_satp_mode_supported` and csr.c:1951); x86 enables 5-level by setting CR4.LA57 only when CPUID reports it (unverified: general knowledge, the CPUID bit is verified: cpu.c:8604).
  - Cost and risk: a register plus a field: the most state of the options; whether an implementation must support all lower level counts is a new rule (3 on every machine is the author's "System v1 form", errata 96, so the mask can be: 3 always, 4 and 5 optional).
  - Fit: strong on 1; hot-loop neutral; Occam: two entities for two jobs, both needed if software chooses.
- Option 4 - The boot ROM puts the widths in the boot-information block and nothing in the processor.
  - Rationale: the block already lists memory ranges and the root complex address (04-boot.md:52); early kernel reads it with the rest; the processor stays unchanged.
  - Precedent: Linux on RISC-V and ARM learns the MMU mode and addresses from the device tree the loader passes (the pdp64 block is the analogue); QEMU virt writes a device tree (unverified for the specific properties: general knowledge); the VAX RPB and Alpha HWRPB carry the machine parameters (named in boot.md:161).
  - Cost and risk: the facts are not from the hardware itself; a stale or wrong block gives wrong widths (error not detectable); useless for a second-stage loader run by hand or a bare-metal program with no block.
  - Fit: weak on 1; no hardware cost.
  - Note: you said "as long as this info is discoverable easily at runtime": [R361]
- Option 5 - Unprivileged read-only register or instruction (a CPUID analogue readable in user mode).
  - Rationale: user code, a JIT or a pointer-tagging runtime can learn the canonical bit without a system call; the information is harmless (not secret).
  - Precedent: x86 CPUID is unprivileged (unverified: general knowledge, the leaf is verified: QEMU target/i386/cpu.c:9204); the Linux AArch64 kernel emulates user reads of some ID registers (unverified: general knowledge).
  - Cost and risk: a new user-visible instruction or an exception to the "system registers are privileged" rule (`MFSR` is privileged, 06-kernel.md:17); a virtualiser or a sandbox cannot hide it; fingerprinting.
  - Fit: good on 5 (compiler), neutral elsewhere; adds an entity (against Occam) unless it is a user-readable alias of Option 1.
- Option 6 - A profile number instead of fields: one read-only ID register says "profile 1 = 3 levels, 40 bits; profile 2 = 4 levels, 48 ...", and the manual defines each profile.
  - Rationale: a few well-tested combinations, not 3 x 25 combinations to verify; the author already has "System v1".
  - Precedent: RISC-V profiles (RVA20, RVA22, RVA23) define sets of mandatory extensions (unverified: general knowledge); Alpha and MIPS used an implementation-version register (unverified: general knowledge).
  - Cost and risk: every new width forces a new profile; the "40 to 64 anywhere" freedom of errata 102 is lost; the kernel needs a table.
  - Fit: good on 1 (few combinations); poor on the author's "implementation chooses its width" rule.
- Recommendation: MINE (P): Option 3's read side, Option 1 first (a read-only `MMUCFG` at system register 13 with physical bits, supported-level mask and virtual bits), and add the writable level selector only if the author wants a kernel to run fewer levels than the maximum; because it needs no probe, a bad value cannot arise (priority 1), and the number 13 is already reserved for it. Would change my mind: the author wanting no new register (then Option 2), or a need for user-mode reading (then Option 5 as a user-readable copy).
- Would help you decide: whether the kernel may choose a smaller level count than the implementation's maximum; whether 3 levels are mandatory on every machine (errata 96: "System v1 form"); whether user code needs the canonical bit. Cheap check: `grep -n "canonical" docs/manual-src/*.md` for what user code is promised.

### Q3 The page-table entry for wide physical addresses (QUESTION)
- What it is: the entry is 64 bits with the physical page number in bits 12-39 (28 bits = 40-bit address); a 64-bit physical address needs 52 bits of page number, bits 12-63, which leaves no bit for any flag above bit 11 (06-kernel.md:90; errata 102 (c)).
- What it is: the choice is where the page number sits, how wide it may be, and where spare flag bits go.
- Why it matters: kernel - the PTE layout is written by every `fork`, `mmap` and fault handler, so the page number position is shift-and-mask code in the hot path; compiler - none; hardware - the TLB entry width and the physical tag width of every cache grow with the page number (a 52-bit page number instead of 28: 24 more bits per TLB entry; a 32 KB, 64-byte-line cache has 512 lines, 24 more tag bits each, roughly 12 000 flip-flops (E, my arithmetic, not measured)); manual - 6.4.2 and the system architecture document.
- Where things stand: reserved bits 10-11 and 40-63 fault if set (qemu/target-pdp64/mmu.c:24); MT is two bits (8-9) and its extension has nowhere to go; the space-bit check `pdp64_pte_space_ok` (common/pdp64exec.h:60) reads PTE bit 39 + 12 and must go with errata 97; author's words: none on the format ("is the author's question", errata 102).
- Referents you named or liked:
  - wide physical address bits, source system not named: "if we are going to mmap petabytes, we need those bits" [R360]; stance: chosen
  - dmw, source system not named: "good thing we already had dmw in the design!" [R361]; he also asked "what are dmw registers? part of pcie?" [R360]; stance: chosen
  - 5-level TLB, from Loongson: "what other parts of the design are effected if we have 5 level tlb like loongso[n]" [R360]; stance: considered
- Option 1 - PPN in place, bits 12-63 (the layout extended).
  - Rationale: no change for the 40-bit machine (bits 12-39 stay); the present text is a subset; the hardware extracts the same field.
  - Precedent: none exact; x86's address mask is bits 51:12 in place with flags above (NX in bit 63) (verified: QEMU target/i386/cpu.h:340 for the mask; NX bit unverified: general knowledge).
  - Cost and risk: zero spare bits: no future flag (no-execute extension, memory type extension, protection key, software bits), a 64-bit physical address then means a PTE that is all page number; any later flag forces a new format.
  - Fit: weak on 1 and on the "ready for later" principle; cheapest hardware.
- Option 2 - Cap the page number at 40 bits (physical address 52), PPN in place bits 12-51, bits 52-63 for flags and software.
  - Rationale: twelve spare bits (e.g. a memory-type extension, a protection key, a no-execute-like bit, software bits) and 4 PiB of reach, which already covers "petabytes".
  - Precedent: x86-64 PTE bits 51:12 address, bit 63 NX, upper bits for protection keys (verified for the mask: QEMU target/i386/cpu.h:340; the rest unverified: general knowledge); AArch64 LPA caps at 52 bits (verified: QEMU target/arm/ptw.c:112-119, table ends at 52).
  - Cost and risk: contradicts "up to full 64 bit" (errata 102), which becomes "40 to 52 in page tables"; a device mapped above 2^52 cannot go through a page table (see Option 5).
  - Fit: strong on 1 (room for protection), good on 4; breaks the author's maximum.
- Option 3 - Move the page number down to bit 10 and use bits 62-63 for flags (RISC-V's shape): PPN bits 10-61 (52 bits), bits 10-11 gain no flag, bits 62-63 free.
  - Rationale: a 64-bit physical address fits (52-bit page number at bits 10-61) and two bits remain at the top; the shift is 2 instead of 12 minus 12.
  - Precedent: RISC-V puts the PPN at bit 10 with up to 44 bits (bits 10-53), the N and PBMT fields at 63-61, reserved bits 60-54 (verified: QEMU target/riscv/cpu_bits.h:738-748).
  - Cost and risk: PA = (pte >> 10) << 12 is one extra shift step in the walker and the kernel; every existing PTE (the simulator's, QEMU's, `spec/pdp64-system.hbnf`, the kernel's) is rewritten; only two spare bits, and a PTE with 62 and 63 set cannot be a 64-bit address, so a 64-bit device address still uses all of them.
  - Fit: neutral on 1 (two bits), a change of format for no gain over Option 2 in reach if Option 2's cap is accepted.
- Option 4 - Keep the 64-bit entry but make the page-number width equal the implemented physical width; bits above it are reserved and must be zero, and the spare bits are defined only as "the bits above PABITS" (flags can live there in implementations that need them).
  - Rationale: a 40-bit machine keeps bits 40-63 for future flags; a 64-bit machine has none; one format, varying free space.
  - Precedent: x86 reserved bits above MAXPHYADDR must be zero and cause a page fault (unverified: general knowledge); AArch64 output address bits above PARange are res0 (unverified: general knowledge).
  - Cost and risk: flag positions would depend on the implementation (code that uses a spare bit works on 40-bit machines and not on 64-bit ones); a reserved-bit fault is a good detection (priority 1) but only above the implemented width.
  - Fit: good on 1 (detect), bad on portability (soft rule broken).
- Option 5 - Page tables reach 52 bits (Option 2), and anything above bit 51 is reached by the direct-mapping windows (`DMW0`, `DMW1`) whose PhysicalBase is a full 64-bit field.
  - Rationale: "good thing we already had dmw in the design!" (R361); a window needs no PTE, so a kernel maps a petabyte-scale device or a huge memory with one window; the PTE keeps its spare bits.
  - Precedent: LoongArch DMW windows (named in the ISA text, docs/pdp64-isa.md:1297, :1309), MIPS KSEG0 (named at :1309; behaviour unverified here); the window format is deferred (06-kernel.md:71, :179). (your referent [R361])
  - Cost and risk: two windows only; user processes cannot map above 2^52 (kernel only, "Permission is kernel-only", isa.md:1308); the DMW format must be designed now and it is "stored but without effect".
  - Fit: good on 1 and 4 (no PTE bits); depends on the DMW design.
- Option 6 - A 16-byte entry (128 bits) with room for everything.
  - Rationale: no cramping: full 64-bit address, memory type, protection key, 40 free bits.
  - Precedent: none for the common MMUs; IBM z/Architecture region and segment tables are other shapes (unverified: general knowledge).
  - Cost and risk: 256 entries per 4 KB table (8 bits per level) so 3 levels cover only 36 bits and 5 levels 60: the whole 39/48/57 design (errata 96) changes; twice the memory per walk step, one extra bus beat; larger TLB entries.
  - Fit: poor on 4 and on Occam; breaks decisions of 2026-11-09.
- Recommendation: MINE (P): Option 2 for page tables with Option 5 for the rest, that is a 40-bit page number (52-bit physical address through page tables, 4 PiB) and the windows for anything above, because a 64-bit physical page number consumes the whole entry and every later need (protection, memory type, no-execute-style bits) would force a new format, whereas 2^52 already covers the author's "petabytes". Would change my mind: the author insisting that user processes map above 2^52, then Option 3 (shift to bit 10) and accept two spare bits.
- Would help you decide: the largest physical address the author actually wants user processes to map; which flags are wanted next (protection key, no-execute separate from X, wider MT). Cheap check: `grep -n "PTE_RESERVED\|PTE_WIDTH_PPN" qemu/target-pdp64/mmu.c qemu/target-pdp64/gen/pdp64-consts.h` lists every place the format is wired.

### Q4 Locating devices without a selecting bit (QUESTION)
- What it is: errata 97 removed bit 39 as the bit that tells device space from memory; how does software find each device's window and how is its place chosen.
- What it is: the main ways are enumeration (software reads each device and assigns windows), a table handed over at boot, or fixed addresses written in the architecture.
- Why it matters: kernel - the driver needs a base address and a memory type; without a bit, a mapping's memory type is the only marker (02-bus.md:19); compiler - none; hardware - the root complex decodes windows it has assigned and must refuse DMA into device windows without the bit (errata 85 IOMMU); manual - 2.6.8 says where the configuration space and windows sit "is unspecified".
- Where things stand: author, 2026-11-09 [R360]: "the whole 'bit 39 decides if memory or dma' should go away, if we are going to mmap petabytes, we need those bits"; errata 102: "mapping can be anywhere except the first few pages". The boot-information block already carries "the address of the root complex" (04-boot.md:52). 2.6.1: the processor reads each function's configuration space through the root complex and assigns windows. Simulator and QEMU keep the bit-39 layout (spec/pdp64-system.hbnf:92-98, qemu/hw-pdp64/virt.c:3-6).
- Referents you named or liked:
  - no bit 39 to select device space, source system not named: "the whole 'bit 39 decides if memory or dma' should go away, if we are going to mmap petabytes, we need those bits" [R360]; stance: chosen (it replaced his earlier "yes, bit 39 is right" [R282])
  - enumeration, from PCI Express and USB: "just as usb is unuerated over a pcie bus, our q64 bus will allow arbitrary buses to be connected to it and enumerated" [R292]; stance: chosen
  - devices as virtio, from virtio: "forget the native 8 register devices. gone. virtio across the board" [R360]; stance: chosen
  - I/O space (memory low, I/O above), from VAX: "it should be noted in the book how the vax does this io space idea" [R281]; stance: considered
  - large mmio windows, source system not named: "mmio allows larger windows as needed" [R282]; stance: chosen
  - PCI Express base for the q64 bus, from PCI Express: "pcie for the q64 bus" [R311]; stance: chosen
- Option 1 - PCI Express enumeration with the root complex address in the boot-information block; the kernel assigns the BARs in a window range the block also gives (the window pool).
  - Rationale: one mechanism for everything on the bus (2.6.1-2.6.3); only two numbers are passed (ECAM base and the window pool); the platform moves them freely, nothing is fixed in the architecture.
  - Precedent: QEMU virt boards for RISC-V give ECAM at 0x30000000 and PCIe MMIO at 0x40000000 and describe them to the kernel (verified: QEMU hw/riscv/virt.c:104-105, :731-753); x86 ACPI MCFG table gives ECAM base (unverified: general knowledge).
  - Cost and risk: the kernel must trust the pool; a block that overlaps RAM is an error that can only be detected by comparing ranges; early console before enumeration needs a separate base.
  - Fit: strong on 5 and 6 (drivers learn base from BAR), good on Occam (no new table); matches the existing text (P).
- Option 2 - A device table in the boot-information block (kind, base, size, interrupt), with no enumeration for platform devices.
  - Rationale: the block already lists the console and video base (04-boot.md:56) and boot.md:161 lists "a table of devices (kind, base address, interrupt level and vector)".
  - Precedent: VAX RPB and Alpha HWRPB (named in boot.md:161); device tree on ARM and RISC-V platform devices (unverified: general knowledge).
  - Cost and risk: duplicates what enumeration finds (two mechanisms, against Occam); hot-plug devices are not in the table.
  - Fit: good for devices that are not PCI Express (the timer and console of the simulator).
  - Note: you said "forget the native 8 register devices. gone. virtio across the board": [R360]
- Option 3 - A fixed platform map written in the architecture: the root complex and a window range at fixed addresses (the VAX nexus space at 0x20000000, the PDP-11 I/O page at the top).
  - Rationale: no table to trust, no early-boot problem; trivially simple for a small FPGA board.
  - Precedent: VAX-11/780 I/O space above 0x20000000 with one 8 KB window per adaptor slot, changing from model to model (verified: docs/manual-src/02-bus.md:21 commentary, citing 4.3BSD `nexus.h`); PDP-11 I/O page at the top of the 16-, 18- or 22-bit space (verified in repository text: 02-bus.md:21; the 18 and 22-bit extensions unverified: general knowledge). (your referent [R281])
  - Cost and risk: fixes an address below 2^40 (the lowest width) and so reintroduces the upper-half habit the author dropped; a wider machine cannot put petabytes there; the VAX shows that a fixed map is changed model by model.
  - Fit: good on 4; bad on the author's freedom ("anywhere").
  - Note: you said "the whole 'bit 39 decides if memory or dma' should go away, if we are going to mmap petabytes, we need those bits": [R360]
- Option 4 - Top-down placement: the root complex window ends at the top of the implemented physical address space (2^PABITS), so it moves with the width the processor reports (depends on Q2).
  - Rationale: never collides with RAM that grows from 0; one rule for 40 and 64 bits; the kernel computes the base from the width register.
  - Precedent: the PDP-11 I/O page at the top (verified in repository text: 02-bus.md:21); x86 PCI hole just under 4 GB (unverified: general knowledge). (your referent [R26])
  - Cost and risk: a program that assumes a width gets the wrong address; depends on the width being discoverable; memory sizes near the top collide.
  - Fit: neutral; depends on Q2.
- Option 5 - An address-map list handed over at boot (each range with a type: RAM, device, reserved), and the memory type of a page is the only runtime marker.
  - Rationale: one place says what every range is; a window can be anywhere; the kernel refuses mappings of RAM as device and vice versa (errata 65's check re-derived from the list).
  - Precedent: the PC BIOS E820 map and UEFI memory map (unverified: general knowledge); the pdp64 block already has memory ranges (04-boot.md:52).
  - Cost and risk: the list can be wrong; a write of the wrong memory type to a device page is not detected by hardware (previously caught by the bit: common/pdp64exec.h:60 and errata 65); more kernel code.
  - Fit: weak on 1 (loses the old safety net).
- Option 6 - The root complex answers a self-describing "window map" register block at a single fixed low address (just above the first pages); everything else is found through it.
  - Rationale: only one address is architectural, small, in the reserved boot area; the map says where the ECAM and each window are; no block needed.
  - Precedent: the ARM GIC and a RISC-V CLINT are found from the device tree, not from a single self-describing block (unverified: general knowledge); the VAX nexus status registers self-describe by slot (verified: 02-bus.md:81 commentary). (your referent [R281])
  - Cost and risk: a new device and a new fixed address; the "first few pages" rule would have to reserve its page.
  - Fit: good on 1 (single source); one new entity (Occam).
- Recommendation: MINE (P): Option 1, with the memory type of the page as the safety check and errata 65's check kept as "device types only on enumerated windows" in the kernel; it is the text the manual already has (2.6, 4.4.2), adds no table, and works at 40 to 64 bits. Would change my mind: the author wanting platform devices without PCI Express (timer, console, interrupt controller): then add Option 2's table for those only.
- Would help you decide: where the interrupt controller and timer live; whether the simulator should move its devices off bit 39. Cheap check: `grep -n "0x8000000000" -r spec qemu/hw-pdp64 sim64` lists what changes.

### D1 The physical address width: at least 40 bits, up to 64 (REVIEW)
- What it is: how many bits of physical address the machine has; today an implementation chooses between 40 and 64.
- What it is: it sets the size of the physical page number everywhere (PTE, TLB, tags, bus).
- Why it matters: kernel - the width decides PTE format and any size assumption; compiler - none (virtual addresses are the compiler's); hardware - address wires, TLB and tag width and every cache line's tag; manual - 2.1.6, 6.4.2, 6.8.4, 9.2.10 all say 40 to 64.
- Where things stand: CURRENT (errata 102, 2026-11-10): the author said "physical address: minimum 24 bit, up to full 64 bit. mapping can be anywhere except the first few pages where the boot stuff is loaded.", then "fine, minimum 40 bits."; before that the design was a fixed 40-bit address with bit 39 selecting device space (errata 60, 2026-10-22, "bit 39 is right"; superseded by 97); the simulator and QEMU map 40 bits (spec/pdp64-system.hbnf:92).
- Referents you named or liked:
  - wide physical address, source system not named: "if we are going to mmap petabytes, we need those bits" [R360]; stance: chosen
  - largest physical RAM, from amd64 and loongson64: "how much ram can amd64 theoretically support and loongson64" [R351]; stance: considered
  - largest physical RAM, from any CPU: "what is the largest physical ram supported right now by any cpu?" [R352]; stance: considered
  - dmw, source system not named: "good thing we already had dmw in the design!" [R361]; stance: chosen
- Option 1 - CURRENT: 40 to 64 bits, implementation chooses.
  - Rationale: one architecture from an FPGA (needs only 40) to a petabyte-scale server; the width is a property of the implementation.
  - Precedent: x86-64 MAXPHYADDR is implementation-defined up to 52 and reported by CPUID (verified: QEMU target/i386/cpu.c:9204; the 52 limit: verified by PTE mask cpu.h:340); AArch64 PARange picks from 32 to 52 (verified: QEMU target/arm/ptw.c:112-119); LoongArch PALEN field (verified: QEMU target/loongarch/cpu.h:113). (your referent [R135])
  - Cost and risk: needs discovery (Q2) and a PTE for 64 bits (Q3); more cases to test; every document that says "40 bits" says "40 to 64".
  - Fit: good on 4 (small machines stay small); open items cost effort (priority 3).
- Option 2 - The state before: a fixed 40-bit physical address (1 TB).
  - Rationale: the simplest: no discovery, PTE already fits (28-bit PPN), the simulator and QEMU are already this.
  - Precedent: early x86-64 implementations had 40 bits (unverified: general knowledge); the PDP-11/70 and the VAX had 22 and 30 bits (unverified: general knowledge). (your referent [R26])
  - Cost and risk: 1 TB may be small for a "mmap petabytes" machine (the author's words); the author withdrew it in errata 97.
  - Fit: good on 1 and 4; contradicts the author's stated need.
  - Note: you said "if we are going to mmap petabytes, we need those bits": [R360]
- Option 3 - Fixed 52 bits (4 PiB).
  - Rationale: matches the maximum of x86-64 and AArch64 LPA and fits a 40-bit page number with 12 spare PTE bits (Q3 Option 2); one number, no discovery.
  - Precedent: x86-64 architectural limit 52 (verified: QEMU target/i386/cpu.h:340); AArch64 LPA 52 bits (verified: QEMU target/arm/ptw.c:112-119).
  - Cost and risk: a small FPGA pays for 52-bit wires, TLB and tags it never uses; unused bits above the memory still fault or alias.
  - Fit: good on 1 (one case), weak on 4.
- Option 4 - 40 to 52 bits, implementation chooses (the x86 and ARM range).
  - Rationale: keeps the freedom and leaves spare PTE bits; reach 4 PiB is above "petabytes"; discovery still needed.
  - Precedent: x86-64 MAXPHYADDR 36 to 52 in practice (unverified: general knowledge for the lower end; upper verified: cpu.h:340); AArch64 PARange table ends at 52 (verified: ptw.c:112-119).
  - Cost and risk: contradicts "up to full 64 bit".
  - Fit: strong on 1 and 4.
- Option 5 - Fixed 64 bits for every implementation.
  - Rationale: pointers are 64 bits already; no discovery, no PTE question: any address works; no "is this bit wired" case.
  - Precedent: IBM z/Architecture has 64-bit addressing with no physical width field exposed (unverified: general knowledge; QEMU s390x reports 64-bit virtual space: verified: QEMU target/s390x/cpu-param.h:12).
  - Cost and risk: a 64-bit page number in every TLB entry and tag on a small board; the PTE has no flag bits (Q3 Option 1).
  - Fit: bad on 4; simple on 1.
- Option 6 - 24 to 64 bits (the author's first words, 2026-11-10).
  - Rationale: a very small embedded profile (16 MB) on the same ISA; the author said it first, then replaced it by 40.
  - Precedent: the PDP-11 had 16 then 18 then 22 bit physical addresses on one ISA (unverified: general knowledge); RISC-V Sv32 has a 34-bit physical address and a 32-bit one for RV32 (unverified: general knowledge). (your referent [R26])
  - Cost and risk: the manual's DMW, boot and first-pages reasoning all assumed at least 40 (e.g. devices above the first few pages need room); 24 bits leaves no space for a PCI Express configuration space (ECAM needs 256 MB for 256 buses).
  - Fit: good on 4 for tiny cores, bad on 1 (more cases).
- Recommendation: MINE (P): keep Option 1 (CURRENT); add a decision on the discovery register (Q2) and a page-table cap (Q3 Option 2), because the author chose the freedom and the sim already meets the minimum. Would change my mind: the author deciding that no user process maps above 2^52 and wants one fixed number: then Option 3.
- Would help you decide: the largest RAM plus device space of any board planned; the cost of 24 more tag bits in the FPGA design. Cheap check: `grep -rn "40 bits\|40-bit" docs/manual-src | wc -l` shows how many sentences change.

### D2 Page tables of 3, 4 or 5 levels, discoverable (REVIEW)
- What it is: the number of table levels the walker uses: 3 (39-bit virtual addresses), 4 (48) or 5 (57); the machine says which.
- What it is: fewer levels walk faster; more levels reach more virtual space.
- Why it matters: kernel - one build must run on all three (no build option), and the user's canonical bit (38, 47 or 56) differs; compiler - pointer tagging and address-size assumptions; hardware - the walker is one loop with a depth, and a TLB miss costs one memory access per level (3 versus 5, E, my arithmetic: no cache effects included); manual - 6.4.1, 6.4.1a, 6.4.3 and glossary line 44.
- Where things stand: CURRENT (errata 96, 2026-11-09, R361): "3 4 and 5 is good, as long as this info is discoverable easily at runtime. so, 39, 48, 57 bit is all fine. good thing we already had dmw in the design!"; the author earlier asked "how about we allow 4 levels" and about Loongson 5 levels [R360]; the state before: three levels, 39 bits only (decisions-pending.md:734, errata 96 "supersedes"). Manual text says 3, 4, 5 now (06-kernel.md:86); simulator and QEMU implement 3 (06-kernel.md:88); the register that reports it is "not specified".
- Referents you named or liked:
  - 3, 4 and 5 levels, source system not named: "3 4 and 5 is good, as long as this info is discoverable easily at runtime. so, 39, 48, 57 bit is all fine" [R361]; stance: chosen
  - 4 levels, source system not named: "how about we allow 4 levels" [R360]; stance: chosen
  - 5-level TLB, from Loongson: "what other parts of the design are effected if we have 5 level tlb like loongso[n]" [R360]; stance: considered
  - dmw, source system not named: "good thing we already had dmw in the design!" [R361]; stance: chosen
  - PC handling and pragmatism, from LoongArch64: "looking at loongarch64, they are pragmatic; what can we learn from them and adopt" [R135]; stance: considered
- Option 1 - CURRENT: 3, 4 or 5 levels, discoverable.
  - Rationale: one design from an FPGA (3 levels: shortest walk, least TLB work) to a machine with 128 PiB of virtual space; the kernel adapts.
  - Precedent: RISC-V Sv39, Sv48, Sv57 with satp modes 8, 9, 10 (verified: QEMU target/riscv/cpu_bits.h:721-726); x86-64 4-level and 5-level (LA57) (verified: QEMU target/i386/cpu.c:8602-8609); Loongson/LoongArch walker is configurable by directory base and width (verified: QEMU target/loongarch/cpu-csr.h:95-102). (your referent [R360])
  - Cost and risk: three walkers' worth of test cases; the discovery register (Q2); the user's canonical bit varies, so tagged-pointer code needs to know it (glossary line 44).
  - Fit: good on 4 (small machines stay on 3), neutral on 1 if discovery is a register; Occam: the same walker loop with a depth.
- Option 2 - The state before: three levels only (39 bits).
  - Rationale: the smallest design; no discovery; same as RISC-V Sv39, which is enough for 512 GB virtual (decisions-pending.md:734).
  - Precedent: RISC-V Sv39 alone on small Linux systems (unverified: general knowledge); the walk shape checked in the repository: docs/pdp64-system-architecture.md:116 ("same shape as RISC-V's Sv39", verified against QEMU).
  - Cost and risk: 512 GB is small for the "petabyte" mmap intent of errata 97; the author withdrew it.
  - Fit: good on 1 and 4; contradicts the author's wish.
  - Note: you said "3 4 and 5 is good, as long as this info is discoverable easily at runtime": [R361]
- Option 3 - Three or four levels only (39 or 48 bits).
  - Rationale: the 4th level is the one the author first asked for ("how about we allow 4 levels", errata 97); covers 256 TB virtual; skips the rare 5th.
  - Precedent: x86-64 and AArch64 default to 48-bit virtual (4 levels) in common use (unverified: general knowledge; the x86 default verified: QEMU cpu.c:8607).
  - Cost and risk: a machine with more than 256 TB of physical memory cannot map it all at once; 57 bits would have to be added later by another discovery rule.
  - Fit: good on 4; a smaller test matrix.
  - Note: you said "3 4 and 5 is good, as long as this info is discoverable easily at runtime": [R361]
- Option 4 - Four levels only (48 bits), fixed.
  - Rationale: one walker, no discovery; the mainstream shape for desktops and servers.
  - Precedent: x86-64 before LA57 and AArch64 with 4 KB pages and 48-bit (unverified: general knowledge).
  - Cost and risk: a small FPGA walks four levels for a few MB; the 39-bit System v1 form (errata 96) is gone.
  - Fit: good on 1 (one case); bad on 4 for small machines.
  - Note: you said "3 4 and 5 is good, as long as this info is discoverable easily at runtime": [R361]
- Option 5 - A configurable walk (LoongArch style): control registers say the base bit and width of each directory level, so any number of levels and any width is possible.
  - Rationale: one mechanism covers 3, 4, 5 and odd sizes (and huge pages); the kernel designs the table shape.
  - Precedent: LoongArch PWCL fields PTBASE, PTWIDTH, DIR1_BASE, DIR1_WIDTH, DIR2_BASE, DIR2_WIDTH, PTEWIDTH (verified: QEMU target/loongarch/cpu-csr.h:95-102). (your referent [R135])
  - Cost and risk: more registers and the generality is a bug surface (illegal combinations); the canonical rule is no longer a simple function of the level count.
  - Fit: weak on 1 and Occam; flexible for the kernel.
- Option 6 - Three levels of virtual space plus the direct-mapping windows for the rest: user space 39 bits, kernel reaches anything through `DMW0` and `DMW1`.
  - Rationale: the author noted "good thing we already had dmw"; the kernel's own physical map needs no page table (isa.md:1311-1313); the user side is simple and fast.
  - Precedent: MIPS KSEG0 and KSEG1 unmapped segments, LoongArch DMW (named at docs/pdp64-isa.md:1309; behaviour unverified here). (your referent [R361])
  - Cost and risk: user processes are limited to 512 GB; the DMW format must be designed (06-kernel.md:71 "format unspecified"); only two windows.
  - Fit: good on 1 and 4; limits user address space.
- Recommendation: MINE (P): keep Option 1 (CURRENT), tie it to Q2's feature register, because it follows the author's words, the walker is one loop with a depth, and the cost is a register and a test matrix; keep Option 6's idea (windows for the kernel) as an available extra. Would change my mind: measuring that no board is planned above 48 bits (then Option 3), or the author wanting a single fixed shape (Option 4).
- Would help you decide: the miss cost per level on the FPGA target (cycles per memory access); whether any user program needs more than 512 GB. Cheap check: `grep -n "levels" docs/manual-src/06-kernel.md` shows where the text is committed.

## Briefing B: the deferred native devices, console/timer/entropy, interrupt delivery, the bus controller

Prepared by briefing-B for the author. Items Q5 to Q8, in that order. Nothing here is decided; each block ends with my proposal (P), not a decision. Source ids are errata numbers of docs/errata.md (errata 94 onward are the 2026-11-09 and 2026-11-10 decisions and override older text). Paths are relative to docs unless absolute. "Local tree" means kernel-src (openbsd, linux, freebsd, netbsd; sparse: the OpenBSD `sys/dev/pv` directory is NOT on disk, so claims about `viornd`, `viocon`, `viogpu` rest on the fetched listing recorded in `security-proposals.md`, which I mark as such).

Facts the four items share, read once here:
- Errata 95 (errata.md:245), the author, 2026-11-09: "forget the native 8 register devices. gone. virtio across the board."; supersedes errata 29, 49 (eight-register bus controller; "that the bus enumerates, maps and alerts is not changed") and 61.
- Errata 75 (errata.md:225): PCI Express base; "our 12 register nic and sound card and graphics card are planned for the future; i like the blit model"; errata 78 (:228): VIC-64X, SID-64X and BLT64 "are deferred for now"; "i want a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers, although as a pcie bus any device MAY be attached"; errata 79 (:229): "yeah, virtio is fine" (virtio-net, virtio-gpu 2D, virtio-snd); errata 80 (:230) and 81 (:231): Q64 is PCI Express, an extension is announced to a card only if the card must take part; errata 101 (:252) disk is virtio-blk; errata 102 (:253) physical address 40 to 64 bits, windows anywhere but the first few pages.
- The current implementation (sim64, QEMU) has a KL11-style console and a counter/compare timer at fixed addresses with fixed vectors: `spec/pdp64-system.hbnf:45-47` (vectors 32 timer, 33 console-in, 34 console-out), `:84-85` (levels timer 6, console 4), `:92-94` (timer at 0x8000000000, console at 0x8000001000), `:97-117` (register layouts). It carries bit 39 as the space bit, which errata 97 abolished as architecture.
- The vector table is 512 entries, `ECAUSE` = vector number; entries 32 to 63 are interrupts, 64 to 255 are "reserved (device interrupts are message-signalled, section 5.7)", 256+n are `TRAP #n` (`manual-src/06-kernel.md:35,53-55`). So only 224 entries (32 to 255) are free for interrupts.

---

### Q5 The deferred native devices (QUESTION)
- What it is: chapter 3 of the manual describes the VIC-64X video chip (a C64 VIC-II extended, 48-bit RGBA pixel, errata 73), the SID-64X sound chip (voices plus a general path, 48-bit samples, errata 74), the BLT64 blitter (a bit-block-transfer engine, the Blit model) and the "eight-register face" they share, plus a stub of register-level specs (`manual-src/03-graphics.md:11-37`); errata 78 deferred them to "iteration two" and errata 95 deleted the eight-register device model on which they were defined.
- What it is: the chapter also holds material that does not depend on those chips and survives any answer: HDMI through a transmitter chip fed a pixel stream (3.3, the DE10-Nano's ADV7513), the framebuffer and memory budget (3.4: 1920x1080 at 32 bits is 8.3 MB, at 48 bits 12.4 MB, so the frame lives in main memory and block RAM holds only a scan-out line buffer), and the shadowed frame-boundary registers of 3.1.9 (errata 71).
- What it is: the question is what the manual, the repository and the author's design should say about these three devices now: keep as a future appendix, remove, redefine over virtio, or something else.
- Why it matters: kernel: a standard driver per class (virtio-gpu, virtio-snd) versus board-specific drivers is exactly what errata 78 wanted to avoid; any native device is one more driver the OpenBSD port must carry.
- Why it matters: compiler: none directly (no instruction depends on them); the 48-bit pixel and sample do touch data types only if a software renderer uses them.
- Why it matters: hardware: virtio-gpu is a protocol, not a scan-out engine; on the FPGA somebody must still build the scan-out line buffer, the pixel clock and the ADV7513 feed (3.3, 3.4.2), so choosing virtio does not remove the video hardware, it changes its programming interface; the audio side likewise needs an I2S or HDMI-audio path (3.3.4).
- Why it matters: manual: chapter 3 is a full chapter (73 lines of statements) whose banner (line 5) and body still say "each with the eight-register face of chapter 5" (line 7), which chapter 5 no longer defines; `docs/c64-devices-from-chat.md` and decisions E1 to E11 of `decisions-pending.md` also assume it.
- Where things stand: the banner at `manual-src/03-graphics.md:5` says the devices "are planned for the future, together with the author's 12-register network, sound and graphics cards (errata 75)" and that iteration one uses "the most standard, secure and easy-to-support" interfaces; 3.1.5 still says each is "a device in a slot" with a 4 KB page (slots no longer exist); 3.2.2 says they "follow the eight-register convention in the terminal's slots"; 3.5 discusses a PCI Express card as an alternative that is now the standard path.
- Where things stand: author: errata 75 "our 12 register nic and sound card and graphics card are planned for the future; i like the blit model" and "48 bit pixels, 48 bit audio samples.... for the future, same time as the 12 register devices"; errata 77 "the c128 will just be another device on the bus; not part of the pdp64 standard" (and its open question: are VIC-64X, SID-64X and BLT64 standard in iteration two or optional like the C128; errata.md:227); errata 78 "pick the ones that are the simplest to program while still being efficient"; errata 95 "gone".
- Where things stand: errata 95 says that "the question of the syntactic sugar that the 12-register-plus-DMA idea raised" is still to do (errata.md:245); I could not find in the repository what that sugar is beyond that sentence.
- Referents you named or liked:
  - Blit model, from the Blit terminal: "i like the blit model" [R311]; "we are basing the design not only on the c64, but also on the blit terminal" [R291]; stance: chosen
  - C64 graphics and audio, from the Commodore 64 and its SID: "all the c64 graphics and audio goodies" [R20]; "i want 48 bit sound as well, not just the sid" [R310]; stance: chosen
  - the 12-register nic, sound and graphics cards, from your own earlier design (no source system named): "our 12 register nic and sound card and graphics card are planned for the future" [R311]; stance: considered
  - standard audio/video over PCI Express, from PCI Express: "i want a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers, although as a pcie bus any device MAY be attached" [R315]; stance: chosen
  - Commodore 128 as an optional device, from the Commodore 128: "the c128 will just be another device on the bus; not part of the pdp64 standard" [R314]; stance: chosen
  - 48-bit pixels and audio samples (no source system named): "modern 48 bit audio and 48 bit pixels" [R278]; stance: considered
  - HDMI as standard kit, from HDMI: "hdmi, like sata and usb, is standard kit, just our interface goes through a very sweet set of mmio" [R278]; stance: considered
  - native 8-register devices (no source system named): "forget the native 8 register devices. gone." [R360]; stance: rejected
- Option 1 - Keep as a marked future appendix: move chapter 3 to an appendix "Native devices (iteration two)", keep every statement and tag, rewrite the eight-register and slot wording as "to be redefined over the then-current interface", state plainly that nothing in the standard depends on it.
  - Rationale: preserves the author's work and the 48-bit pixel and sample decisions (errata 73, 74) at the lowest cost; the author said "planned for the future", not "dropped"; nothing is lost if he returns to the "12 register" cards.
  - Precedent: the repository already does this for pdp64/r20 and pdp64/16: errata 94 keeps the alternatives "as that documented comparison" without removing them (verified: errata.md:244); the C128 is kept as a documented optional device outside the standard (verified: errata.md:227). (your referent [R314])
  - Cost and risk: a document of statements nobody implements; the stubs (3.2) and phrases such as "slot" and "eight-register face" become false and need a header caveat or a rewrite; risk of the old text being read as current (it contains tagged (D) statements).
  - Fit: priority 1 neutral; priority 6 neutral; Occam: does not multiply entities in the standard because it is outside it, but keeps entities on file.
- Option 2 - Remove chapter 3 from the manual: delete the chapter; keep errata 73, 74 and 75 to 78 as history and `docs/c64-devices-from-chat.md` as the chat-era record; replace chapter 3 with a short chapter "Graphics and audio" saying virtio-gpu and virtio-snd, HDMI and the framebuffer memory type.
  - Rationale: Occam; the manual stops carrying a spec for devices that are not built and whose base model (eight registers) is abolished; one fewer source of contradiction.
  - Precedent: the pdp64 manual dropped the Q-bus eight-register bus chapter content when errata 95 superseded it (chapter 2 was rewritten, verified: manual-src/02-bus.md:5); the VAX and PDP-11 handbooks list only shipping options (unverified: general knowledge).
  - Cost and risk: loses the Blit and C64 design record from the manual (it stays in the repository files); if the author later wants the 12-register devices he restarts from the chat extract; the 48-bit pixel decision (errata 73) loses its home.
  - Fit: priority 1 good (no dead specification); Occam strongest; priority 6 neutral.
    - Note: you said "i like the blit model" [R311] and "planned for the future" [R311]; removing chapter 3 drops that record from the manual.
- Option 3 - Redefine as virtio devices: treat virtio-gpu (2D) and virtio-snd as the whole graphics and sound interface; carry the author's extras as virtio feature bits or formats on those same devices (a 48-bit pixel format, a 48-bit sample format) and implement them in the QEMU, `sim64` and FPGA models, so one transport driver serves everything and the old VIC, SID and BLT64 become documented personalities of an ordinary virtio device.
  - Rationale: errata 78 and 79 asked for one standard interface per class; a 48-bit format is a feature negotiation, not a new device; the same device runs in QEMU, `sim64` and the FPGA.
  - Precedent: virtio devices negotiate features per device type, and the virtio specification names device types console, rng, gpu, snd, blk, net (unverified: general knowledge; my recollection is that virtio-gpu 2D formats are 8-bit-per-channel orderings and virtio-snd formats stop at 32 and 64 bit integers and floats, with no 48-bit format: check the specification). OpenBSD has `viogpu` by the fetched listing (verified: security-proposals.md:129, listing of `sys/dev/pv`); whether it has a virtio-snd driver is open (verified: errata.md:229 "whether OpenBSD has a virtio-snd driver (if not, one is written)"). (your referent [R360])
  - Cost and risk: a 48-bit format is not in the standard, so every unmodified driver and host (including QEMU) would ignore or reject it; to use it you fork the device (see Option 6) or lose compatibility with stock QEMU; the OpenBSD `viogpu` would need patching; none of the C64 sprite, raster-interrupt or SID voice behaviour survives, which was the point of those chips.
  - Fit: priority 1 good (one tested interface); priority 4 gates only in the scan-out; priority 5 neutral; Occam good.
    - Note: you said "i want 48 bit sound as well, not just the sid" [R310]; virtio-snd formats may lack 48-bit (the option's own caveat), and you said "no bullshit with supporting a bunch of device drivers" [R315].
- Option 4 - Native devices as an optional PCI Express card, outside the standard (the C128 pattern): publish VIC-64X, SID-64X and BLT64 as the specification of an optional "pdp64 retro card", an ordinary PCI Express function with its own driver, defined from scratch with PCI Express configuration space and message-signalled interrupts instead of slots and eight registers; the standard remains virtio.
  - Rationale: errata 77 already says the C128 is "just another device on the bus, not part of the pdp64 standard" and errata 78 says "as a pcie bus any device MAY be attached and supported"; the author's "i like the blit model" and his C64 designs are kept as real hardware that someone may build, without burdening the standard.
  - Precedent: PCI cards that expose a legacy VGA register set plus a native one (the VGA-compatible class) are the usual way to add a retro programming model to a modern bus (unverified: general knowledge); the Amiga's custom chips (Agnus, Denise, Paula) were a fixed chipset rather than cards, so they are a precedent for the design but not for the packaging (unverified: general knowledge).
  - Cost and risk: a full register-level specification must finally be written (3.2.1 says it is a stub: only the BLT64 registers of 3.1.4 are specified); an FPGA implementation that also needs a PCI Express block, which the first boards lack (3.5.2: Cyclone V and Zynq 7020 have none); the OpenBSD port gets drivers only if someone writes them.
  - Fit: priority 1 neutral (outside the standard, so no effect); priority 6 good for the assembler programmer who wants poked registers; Occam fair (new entities, but optional).
- Option 5 - Keep the Blit model as software on a graphics core over virtio-gpu: drop VIC-64X, SID-64X and BLT64 as hardware; keep from chapter 3 the Blit ideas (framebuffer in the address space, the four primitives bitblt, texture, segment, point, half-open rectangles, layers) as a software library run by the dedicated graphics core of errata 76, drawing into a virtio-gpu 2D resource and flushing rectangles.
  - Rationale: errata 75 says "i like the blit model" and errata 76 proposes "one core dedicated to the gpu/graphics device"; the Blit itself had "no pixel-moving hardware" and did everything in software (Pike, Locanthi and Reiser, 1985, quoted in the chapter's commentary), so the model does not need a blitter chip; it also reuses cores that exist, in line with Occam.
  - Precedent: the Blit terminal (Motorola 68000, 8 MHz, drew every pixel itself) (verified: manual-src/03-graphics.md:29 commentary); Plan 9's draw device and the Blit-derived `libdraw` keep the same primitives in software (unverified: general knowledge). (your referent [R291])
  - Cost and risk: a software blit is slow on one core for 1920x1080 at 48 bits (12.4 MB a frame, 3.4.2) unless the core is wide or has vector instructions; depends on errata 76, which is still a proposal (P); the C64 and SID personalities disappear completely.
  - Fit: priority 2 mixed (more instructions executed than a hardware blitter); priority 1 good (software on an ordinary core, nothing new to fail); Occam good; ready for out-of-order: neutral.
- Option 6 - A pdp64 blit and sprite extension as its own virtio device type: define a pdp64-specific virtio device (or a feature of virtio-gpu) whose virtqueue carries blit commands (source, destination, strides, rectangle, raster operation) and C64-style sprite and raster-interrupt services, so the "12 registers plus DMA" idea becomes a command queue and BLT64 becomes a queue personality; this is the reading of the "syntactic sugar" left open in errata 95.
  - Rationale: errata 95's closing question about the sugar the 12-register-plus-DMA idea raised; a command queue is the virtio way to carry what registers carried; keeps the author's blit and sprite design while using the standard transport and feature negotiation.
  - Precedent: virtio-gpu already carries all its commands as structures in a control virtqueue, and its 2D commands include resource creation, transfer of a rectangle to the host and flush (unverified: general knowledge; whether the 2D command set has a resource-to-resource blit I do not know: check); NVMe and xHCI also command through queues in memory (verified: manual-src/05-drivers.md:58 for NVMe's queue shape). (your referent [R360])
  - Cost and risk: a new device ID or private feature means no stock host (QEMU) implements it, so the pdp64 must write the device model, the FPGA hardware and the OpenBSD driver: exactly the "bunch of device drivers" errata 78 refused; the standard virtio device-ID registry is shared, so choosing an ID needs care (unverified: general knowledge).
  - Fit: priority 1 neutral to poor (one more device to specify and test); Occam poor (new entity); priority 4 pushes gates into a command processor.
    - Note: you said "i want a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers" [R315]; a pdp64-specific device type is one more driver.
- Recommendation: MINE (P). Option 1 now, with Option 5 as the intended direction, and with an immediate rewrite of the chapter's header and of 3.1.5, 3.2.2 and 3.5 so they stop saying "slot" and "eight-register": move the iteration-two devices to an appendix; keep 3.3 (HDMI) and 3.4 (framebuffer, memory type, budget) as the live part of chapter 3, now about virtio-gpu and virtio-snd. Reason: the author said "planned for the future" and "i like the blit model" (errata 75), so deletion (Option 2) contradicts his words; Options 3 and 6 need a 48-bit format or a new device that no stock host implements, which is the cost errata 78 refused; Option 4 is available at any time later because errata 78 already permits any PCI Express device. What would change my mind: the author saying the 48-bit pixel and sample are required in iteration one (then Option 3 or 6); his saying he will not build them (then Option 2); a measurement that a virtio-gpu scan-out on the DE10-Nano cannot reach 1080p (then a native device for the FPGA alone, Option 4).
- Would help you decide: whether the 48-bit pixel and sample (errata 73, 74) stay in iteration one at all; whether the first board's video comes from a hardware virtio-gpu model built in fabric or from the host; the virtio specification's current pixel and sample format lists (read them to confirm my recollection that 48-bit is absent); cheap measurement: `grep -c "" docs/manual-src/03-graphics.md` and `grep -n "slot\|eight-register" docs/manual-src/03-graphics.md` list what the rewrite touches.

---

### Q6 Console, timer and entropy under virtio (QUESTION)
- What it is: with every standard device virtio, what carries the console (text in and out, boot messages, the panic path), a timer (a tick or one-shot interrupt and a time counter), and a source of random numbers; the three are the only standard devices the manual still calls "not specified" (`manual-src/05-drivers.md:98`, statement 5.5.5, and 5.9 line 138).
- What it is: virtio has a console device and an entropy device (virtio-console, virtio-rng); to my knowledge it has no standard timer device (a virtio real-time-clock device has been proposed; unverified: general knowledge); a timer can instead be architectural (counter and compare in the core's system registers, as in the ARM generic timer and RISC-V `time` and Sstc) or a small memory-mapped block (mtime and mtimecmp, HPET).
- What it is: the author's doubt on entropy: "not sure random number in hardware is a good idea" (his annotation in `security-proposals.md`, section 1; I found this exact phrase only as the decision-log text given in my assignment, the file's own annotation reads "how about a separate 256 or 512 byte register that absorbs all randomness but is not readable... reading it gets a new bit of randomness from it", `security-proposals.md:111`); errata 85 (errata.md:235): the pool "is one device shared by all cores; no per-process pool; no version register and no updatable firmware... it is an assistant to the operating system's own generator, which absorbs into it and squeezes from it".
- Why it matters: kernel: the console must work before enumeration (boot ROM, panic, crash with a broken bus) and the timer must work before any driver; a virtio console needs a virtqueue set up by the boot code, a fixed UART needs two registers; OpenBSD's `arc4random` must work from the first call ("early use is encouraged", `rnd.c:44-48`, security-proposals.md:38).
- Why it matters: compiler: none for console and entropy; a timer in system registers adds `MTSR`/`MFSR` registers and possibly `RDTIME` (P3 of `decisions-pending.md`) to the instruction set and ABI documents, a memory-mapped timer adds none.
- Why it matters: hardware: a fixed UART or timer is tens of gates; a virtio-console is a virtqueue engine; an entropy source is a physical circuit (ring oscillators and a conditioner) whose quality the standard would promise; per-core timer comparators scale with core count (a 64-bit comparator per core, `smp-decisions.md` section 4).
- Why it matters: manual: five statements (5.5.5, 5.9, 2.7, the boot hand-off in `docs/boot.md` B3, and 6.2.6's vector table with "32 timer, 33 console input, 34 console output") depend on the answer.
- Where things stand: author: errata 85 and 86 as above; errata 86 "ticks: the secure core takes no periodic timer tick" and "main cores tickless" (`smp-decisions.md` section 4); errata 79 virtio-net, gpu, snd only, so console, timer and entropy were left out; errata 95 "virtio across the board".
- Where things stand: repository: `security-proposals.md:13` leans to "a software generator that works from the first call (OpenBSD's structure), a boot seed from firmware, and virtio-rng in front of a hardware source; no RNG instruction and no system register for it"; its lean at :98 is options 1 + 4 + 3 together (software gathering, boot seed, virtio-rng) with the instruction option 5 declined. `smp-decisions.md` section 4 leans to one global constant-rate counter and a one-shot compare register per core (its option 1), "equivalent in shape to RISC-V Sstc and ARM's generic timer"; `decisions-pending.md` F12 leans to "a small device tree for these (timer, interrupt controller, UART), PCI Express enumeration for the rest" (verified: decisions-pending.md:1585).
- Where things stand: implementation: console and timer are fixed memory-mapped devices in sim64 and QEMU (spec/pdp64-system.hbnf:84-117, verified); there is no entropy device (grep finds no RNG register in the ISA, security-proposals.md:34).
- Referents you named or liked:
  - virtio across the board, from virtio: "forget the native 8 register devices. gone. virtio across the board." [R360]; stance: chosen
  - boot from block 0, from the PDP-11 (bears on the boot console): "can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0?" [R256]; stance: considered
  - no console, timer or entropy referent from another system recorded in your messages for this item
- Option 1 - Fixed memory-mapped console and timer, virtio-rng for entropy (the implementation's present shape): keep the KL11-style console and the counter/compare timer as fixed devices found by the small device tree or the boot block; entropy by virtio-rng fronting a physical source.
  - Rationale: matches `sim64`, QEMU and the decisions-pending F12 lean; both fixed devices work with no enumeration and no virtqueue, so boot ROM and panic code stay tiny; only the entropy source takes a virtio driver, and the security document already recommends it.
  - Precedent: QEMU's `virt` machines for ARM and RISC-V place a PL011 or 16550 UART and (on RISC-V) a CLINT timer at fixed addresses described by a device tree, with virtio devices beside them (unverified: general knowledge); OpenBSD `viornd` asks for 16 bytes at boot and every 15 seconds times a power of two (verified by listing only: security-proposals.md:47, fetched).
  - Cost and risk: fixed devices remain "devices that are not virtio and not PCI Express", so the manual keeps two device models (a violation of "virtio across the board" the author may not intend); a fixed timer shared by all cores forces a lock or per-core windows; needs the wired-line converter of Q7.
  - Fit: priority 1 good for console and timer; priority 4 smallest; Occam fair (two kinds of device).
    - Note: you said "forget the native 8 register devices. gone. virtio across the board." [R360]; a fixed memory-mapped console and timer is a non-virtio device (the option itself flags this).
- Option 2 - Architectural timer in the core; fixed UART; virtio-rng: move the timer into the core as a shared constant-rate counter plus a per-core one-shot compare in system registers (`RDTIME`, a compare write), keep a minimal fixed UART for the boot and panic console, entropy by virtio-rng.
  - Rationale: `smp-decisions.md` section 4 option 1: the timer cannot fire on the wrong core, tickless is one write, the secure core simply never writes its compare, and the kernel interface is exactly what OpenBSD's `clockintr` needs (read the counter, set a one-shot compare, take the interrupt).
  - Precedent: the RISC-V `stimecmp` write when the Sstc extension is present, else an SBI call (verified: kernel-src/openbsd/sys/arch/riscv64/riscv64/clock.c:63-70); OpenBSD's riscv64 backend of the clock is 175 lines (verified: wc of that file); the ARM generic timer has a shared system counter and a per-core compare (unverified: general knowledge); x86's TSC-deadline mode with the invariant TSC (verified: kernel-src/linux/arch/x86/kernel/tsc.c exists, 1,596 lines; Gleixner's remark that "the stupid hardware is not reliable" is quoted in kernel-pain-points.md:729).
  - Cost and risk: adds system registers and probably `RDTIME` to the ISA (its side-channel enable, P3); the counter must be distributed with a stated skew bound on many cores; the architecture, not only the platform, then defines the timer, so QEMU and `sim64` must change.
  - Fit: priority 1 good (no unsynchronised clock); priority 2 good (one instruction); priority 4 plus; out-of-order readiness: `RDTIME` needs an ordering rule (`smp-decisions.md` section 4).
    - Note: you said "virtio across the board" [R360]; the fixed UART kept in this option is a non-virtio device.
- Option 3 - Everything enumerated: virtio-console and virtio-rng, timer architectural: console through virtio-console found by enumeration (the boot ROM carries a tiny polled virtio driver, or a ROM-private console), entropy through virtio-rng, timer as in Option 2.
  - Rationale: the strictest reading of "virtio across the board": the only non-virtio device is the core itself; one transport driver and one enumeration walk cover console, entropy, disk, network, graphics and audio; OpenBSD has virtio drivers for console and entropy by the fetched listing.
  - Precedent: Firecracker and QEMU microvm use virtio devices for console where a UART is not wanted (unverified: general knowledge); OpenBSD `viocon` and `viornd` exist in `sys/dev/pv` (verified by listing only: security-proposals.md:129).
  - Cost and risk: the console cannot work before the bus does: if the virtqueue, the IOMMU mapping or the root complex is wrong, nothing prints, so debugging the earliest boot is hardest exactly where it is needed; a panic path that first needs a descriptor in uncached memory and a doorbell is longer than a store to a data register; priority 1 asks that failure be easy to detect and this removes the simplest channel.
  - Fit: priority 1 poor for the early-boot case, good elsewhere; Occam good (one device model); priority 4 a virtqueue engine in hardware just for text.
- Option 4 - The author's absorb-and-squeeze pool as a fixed device (the errata 85 form, restated): a write modifies a 256 or 512 byte pool and a read returns a fresh value, one device shared by all cores, no version register and no firmware, console and timer as Option 1 or 2.
  - Rationale: the author's own proposal, accepted in errata 85 ("a read with a known and wanted effect is not a strange side effect"); it feeds OpenBSD's generator without replacing it; hardware cost is a small pool and mixer.
  - Precedent: OpenBSD's own generator absorbs into a pool and squeezes ChaCha20 output from it (`enqueue_randomness`, ChaCha20 rekeying, verified: security-proposals.md:38-39, quoting `sys/dev/rnd.c`); Intel `rdrand` and `rdseed` and AArch64 `RNDR` are hardware sources OpenBSD reads and mixes (verified: kernel-src/openbsd/sys/arch/amd64/amd64/cpu.c:1379-1417, arm64/arm64/cpu.c:873-874 and 1536); RISC-V Zkr is a `seed` register of raw bits for the OS to condition (unverified: general knowledge, per security-proposals.md:76).
  - Cost and risk: the author noted it "would break if openbsd changed their randomness algorithm" (security-proposals.md:111); it is a read with an effect, a shared-buffer risk (the SRBDS lesson, kernel-pain-points.md:806); the device is now non-virtio and non-standard: it needs a PCI Express function or a fixed window; his own doubt "not sure random number in hardware is a good idea" argues against putting more in silicon than a physical source.
  - Fit: priority 1 mixed (known effect, but shared state and a device to trust); priority 2 no opcode; Occam poor (a new device where virtio-rng exists).
    - Note: you said "virtio across the board" [R360]; this pool is a non-virtio device.
- Option 5 - No entropy hardware: software gathering and a boot seed only; console and timer as Option 1 or 2: port OpenBSD's `rnd.c` as is: interrupt, disk, network and clock timing through `enqueue_randomness`, plus a boot seed file and the "good seed" flag; no virtio-rng.
  - Rationale: answers the doubt "not sure random number in hardware is a good idea" with no hardware to trust; zero gates; OpenBSD's design assumes "weak seeding is expected and designed for" (verified: security-proposals.md:68, commit 618bc41b).
  - Precedent: OpenBSD on machines with no hardware generator runs this path, with the boot loader reading `/etc/random.seed` and the `.openbsd.randomdata` section (verified: security-proposals.md:38,53-54); RC4 then ChaCha20 as the generator (verified: security-proposals.md:65).
  - Cost and risk: first boot with no good seed is weak (the case `RB_GOODRANDOM` exists to flag); the main cores are tickless by the author's rule, so fewer timer interrupts feed `rnd.c` (security-proposals.md:86); cloned disks repeat the seed (security-proposals.md:67); ASLR and KARL spend entropy and the address space is small (security-proposals.md:84).
  - Fit: priority 1 poor on first boot and a virtual machine clone, good otherwise; no opcode; no gates; Occam strongest.
- Recommendation: MINE (P). Entropy: Option 5 plus virtio-rng as an optional device (that is `security-proposals.md`'s own lean, options 1 + 4 + 3), no instruction, no register, and the absorb-and-squeeze pool of Option 4 left for the author to revive only if virtio-rng proves too slow. Timer: Option 2 (counter and compare in the core). Console: a minimal fixed UART kept for the boot ROM and panic, and virtio-console optional for ordinary use. Reason: the earliest boot and the panic path are priority 1 (detect errors easily), and a text register the boot ROM can write in one store works before any queue exists; the timer in the core removes a device and a lock and matches the author's tickless rule; the entropy doubt is respected by keeping the physical source behind virtio-rng and mixing it, never alone. What would change my mind: a decision that the manual allows no non-virtio device at all (then Option 3, accepting a harder first boot); a decision that the secure core needs a hardware source for key generation (then a hardware seed register of raw bits, Zkr-style); the FPGA board having no cheap TRNG (then the boot seed carries more).
- Would help you decide: whether the boot ROM may carry a ROM-private console (then Option 3 loses its main cost); whether `RDTIME` and the compare register are accepted into the ISA (decision P3, `decisions-pending.md`); how much weight the first-boot seed deserves (does the FPGA have persistent storage for `random.seed`?); cheap measurements: `wc -l kernel-src/openbsd/sys/arch/riscv64/riscv64/clock.c` (175) and `grep -n "enqueue_randomness" kernel-src/openbsd/sys/kern/kern_tc.c` show the kernel's side.

---

### Q7 Interrupt delivery and vector numbers (decision R1) (QUESTION)
- What it is: how a device's interrupt reaches one of the cores, how many vectors there are, how they are numbered and prioritised, and how an interrupt is moved from one core to another; the old bus made this trivial because each slot had a number and the vector was derived from it (the author's decisions of errata 29, 49 and 75 retired "the slot enumeration and slot-derived vectors"; errata.md:225), while PCI Express devices do not have slots in that sense.
- What it is: the PCI Express answer is MSI-X (message-signalled interrupts: the device does an ordinary memory write whose address and data say which core and which vector; the write itself is the interrupt, no wire); every virtio device carries an MSI-X vector for its configuration change and one for each queue (`manual-src/05-drivers.md:116`, 5.7.1; and the common configuration fields at lines 31 and 37).
- What it is: what is missing is the thing that receives the write: an interrupt controller on the processor side that turns the write into "core N takes vector V at level L", and how the 224 free vector numbers (32 to 255) are laid out.
- Why it matters: kernel: OpenBSD needs an interrupt controller driver and a number of vectors; Linux's complaint is 256 vectors per CPU on x86 shared by all device classes (kernel-pain-points.md:104, quoted in `smp-decisions.md` R1); an NVMe-like or virtio-net device wants one vector per queue per core.
- Why it matters: compiler: none (vectors are numbers in `ECAUSE`).
- Why it matters: hardware: per-core pending state, a write-reception path, optional remapping table; the "priority 7 on entry" rule (errata 40, errata.md:185) and `WFE`-wakeup (7.6.2) must agree.
- Why it matters: manual: statements 5.7.1 to 5.7.4, 7.8.2, 7.8.3 (routing "device-side and unspecified") and the vector table of 6.2.6 all wait on it; 6.2.7 (eight priority levels) is decided.
- Where things stand: `smp-decisions.md:418-480` (R1) leans to a message-only per-core interrupt file with an IOMMU remapping table (its Option 3): 256 vectors per core, 3-bit priority level per vector, the vector delivered in `ECAUSE`, wired lines converted at the edge, no NMI with stop-and-drain as the external stop; it asks the author five questions (a to e) which are still open.
- Where things stand: a conflict the R1 text does not note: 256 vectors per core do not fit in the 224 free entries of the 512-entry vector table (32 to 255; 256 to 511 are `TRAP #n`) (verified: manual-src/06-kernel.md:35,53-55); so the numbering needs a decision: a smaller per-core file, a remapped file index, or a larger table.
- Where things stand: author: errata 75 "an iommu", errata 80 "backward compatible", errata 81 "if they don't affect the cards, the cards don't need to know" (so a processor-side controller and a remapping table are invisible to cards); errata 71 (2.4.4, 5.7.4: the interrupt write cannot overtake the data writes before it; a moved target is masked and read back or written atomically); errata 40 (priority 7 on entry); errata 36 (`ECAUSE` holds the vector).
- Where things stand: IPIs: 7.8.2 (P) "an inter-processor interrupt is a write to a per-core register in the interrupt controller; no APIC-like machinery is needed"; the secure core is "stopped and preempted by an inter-processor interrupt" (7.8.6, errata 86).
- Referents you named or liked:
  - priority 7 on entry, from the PDP-11: "go with priority 7 on entry and document its throwback to pdp-11 design" [R229]; stance: chosen
  - deferring interrupts for one instruction at exception entry (no source system named): "what if all interrupts were suspended/defered for one instruction giving time for that spl #7" [R228]; stance: considered
  - IOMMU, from PCI Express: "iommu will allow us to map in c64/c128" [R311]; stance: considered
  - PDP-11 and VAX survey: "survey of what all major modern os and cpu do, plus vax/pdp" [R235]; stance: considered
  - virtio across the board, from virtio: "virtio across the board" [R360]; stance: chosen
- Option 1 - A per-core interrupt file, messages only (R1 Option 2): each core has a 4 KB page in the controller at `base + 4096*core`; an MSI-X write of a vector number sets that vector's pending bit in that core's file; each vector has a 3-bit level and an enable bit; the core takes the highest pending enabled vector above the PSW level and puts the number in `ECAUSE`. Numbering: vector n of a core's file maps to a table entry in the interrupt range (so the file is 224 vectors, 32 to 255, or entries are remapped).
  - Rationale: scales to any core count; the same store is the IPI; no claim read (one memory fetch fewer than PLIC or GIC, priority 2); the PSW level stays the only threshold (smp-decisions.md R1 Option 2).
  - Precedent: RISC-V AIA's IMSIC, an interrupt file per hart with enable, pending and threshold (EIDELIVERY, EITHRESHOLD, EIP, EIE) in OpenBSD's `imsic.c`, 375 lines, which keeps a threshold table per priority level (verified: kernel-src/openbsd/sys/arch/riscv64/dev/imsic.c:34-39 and struct at 49-57, wc 375); Linux has the same driver in files of 308, 390 and 977 lines plus a header (verified: wc of kernel-src/linux/drivers/irqchip/irq-riscv-imsic-*.c).
  - Cost and risk: about 1,300 bits of state per core in the R1 estimate (a few hundred LUTs or a small RAM, from smp-decisions.md); a legacy wired source needs a converter; a device's write can reach the wrong core if a device is hostile, so on its own this lacks protection (that is Option 2).
  - Fit: priority 1 good if the ordering rule holds; priority 2 good; priority 4 small; out-of-order readiness good (pending file outside the pipeline); soft rules: fine.
- Option 2 - Option 1 plus an IOMMU interrupt-remapping table (R1 Option 3, the repository's lean): the device's MSI-X write carries a table index, not a core number; the IOMMU maps the index to (core, vector, level) in a 64-bit entry; retargeting is one atomic 64-bit store; a hostile device can reach only the table entries the kernel gave it. Numbering: the kernel owns the vector number space per core; devices see only indices.
  - Rationale: meets all three requirements of F24 (many vectors, atomic retarget, mask during change) by construction, and is the "error that can never arise" of priority 1 for forged interrupts; invisible to cards (errata 81); an IOMMU already exists for DMA (errata 85, F25 L6).
  - Precedent: Intel VT-d interrupt remapping (a table between the device's message and the destination) (unverified: general knowledge, per smp-decisions.md R1 "what other systems do"); ARM's GICv3 ITS translates a device-id and event-id to an interrupt through tables (verified: kernel-src/linux/drivers/irqchip/irq-gic-v3-its.c exists, 5,903 lines; the table-translation behaviour itself unverified: general knowledge).
  - Cost and risk: a table walker or entry cache on every interrupt write, another structure to size (about 1,024 entries of 8 bytes per device range for iteration one, R1); the IOMMU becomes a dependency of interrupts, so a broken IOMMU silences them.
  - Fit: priority 1 best; priority 4 costs gates; out-of-order neutral; the author must decide whether remapping is iteration one (R1 question c).
- Option 3 - A GIC-style distributor with an ITS (R1 Option 4): a central block holds all state, a distributor forwards to per-core interfaces, an ITS translates messages; 16 software-generated interrupts per core serve as IPIs.
  - Rationale: matches ARM software, mature and well tested; the port could reuse design knowledge; full affinity control from one place.
  - Precedent: the ARM GIC with GICv3 redistributors and the ITS, in OpenBSD `agintc.c`, 2,166 lines (verified: kernel-src/openbsd/sys/arch/arm64/dev/agintc.c, wc 2166) and in Linux's `irq-gic-v3-its.c`, 5,903 lines (verified: wc).
  - Cost and risk: the largest block and the largest driver by far (2,166 lines against 375 plus 228 for IMSIC and APLIC); "no benefit over Option 2 for a design with no legacy" (smp-decisions.md R1); more state to get wrong.
  - Fit: priority 1 fair; Occam poor; priority 4 poor.
- Option 4 - Wired lines to core 0 with a per-line target register (the earlier revised R1 lean, kept for the three fixed devices): one wire per device into a small controller whose per-line target register names a core; messages added later.
  - Rationale: the smallest (PDP-11 style: BR4 to BR7 request lines, the device supplies its own vector); adequate for a four-core iteration-one machine with a UART, a timer and a few virtio devices; vector number can still be 32+line.
  - Precedent: the PDP-11 bus-request lines and device-supplied vectors (verified: manual-src/05-drivers.md:124 commentary and smp-decisions.md R1 history); RISC-V PLIC: wired sources, a priority and threshold per context (OpenBSD `plic.c`, 737 lines, verified: wc), which is the same shape and a larger driver than IMSIC. (your referent [R229])
  - Cost and risk: virtio-pci devices raise messages, not wires, so it needs an adapter anyway; sixteen cores take every interrupt through one front door; a per-queue vector cannot have its own target; shared level lines have the "nobody cared" storms recorded in kernel-pain-points.md:98.
  - Fit: priority 1 poor (legacy hazards); priority 4 smallest; out-of-order neutral. R1 already rejects it except for the fixed devices.
- Option 5 - Interrupts as events in a per-core memory ring (XIVE-like), one doorbell per core: the controller appends (device, queue, level) to a ring in the core's memory and raises one wake signal; the kernel reads the ring in the handler; the vector is the single doorbell number and the ring entry says what happened.
  - Rationale: consistent with the progress-in-memory design the author chose for virtio (5.2.4: "Progress is therefore in memory, not in the device"); one hardware vector per core, so the 224-entry problem disappears; priority is a ring per level (eight rings) or a field; a handler reads memory it was going to read anyway (the used ring).
  - Precedent: POWER's XIVE uses event queues with per-queue notification (names verified as listed in decisions-pending.md:1101, behaviour unverified: general knowledge); NVMe completion queues and virtio used rings are the same shape for completions (verified: manual-src/05-drivers.md:58 and 52).
  - Cost and risk: a memory write per interrupt by the controller (a bus master of its own, so it needs the IOMMU treatment); the ring can overflow and the overflow rule is new; hardware priority arbitration is replaced by software ring ordering; no ready OpenBSD driver exists to copy.
  - Fit: priority 1 mixed (overflow is a new failure mode but entries can be re-derived from the used rings); priority 2 fewer fetches only if the handler needs them anyway; Occam fair (reuses the queue idea).
- Option 6 - Polled devices on dedicated cores; interrupts only for IPI, timer and errors: the graphics, network and audio cores of errata 76 poll their virtio queues (the driver may mask interrupts and poll, 5.7.2, decided D); general cores take only IPIs, the timer and device-error interrupts; a fixed small vector set (for example 32 timer, 33 IPI, 34 error, 35 hot-plug alert).
  - Rationale: removes most interrupt work from the cores that run the kernel; uses 5.7.2, which is already decided; vector numbers stay a handful, which fits the table and makes numbering trivial; avoids the controller for most devices.
  - Precedent: polled-mode network and storage stacks in user space (DPDK, SPDK) (unverified: general knowledge); the ADV7513 and the first FPGA board have no MSI-X source anyway; Linux's NAPI switches interrupts off under load (unverified: general knowledge).
  - Cost and risk: needs dedicated cores (errata 76 is still a proposal (P)); power: a polling core burns power that `WFE` and interrupts would save (priority 4); latency for the disk and the console on a general core still needs some interrupt; it hides rather than answers the delivery question for any device a general core drives.
  - Fit: priority 1 good (fewer mechanisms); priority 4 poor on power; Occam good; compatible with Option 1 or 2 as a front end.
- Recommendation: MINE (P). Option 2 (the repository's lean) as the end state, built in two steps: step one is Option 1 (the per-core file) in iteration one, since a four-core machine with virtio devices gains little from remapping; step two adds the remapping table before sixteen cores or untrusted devices. Numbering: let the file's vector number be 8 bits as proposed, deliver it in `ECAUSE` at a fixed offset (entry 32 + n for n 0 to 223, with entries 224 to 255 of the file unused), or move the `TRAP` range; this is the decision the author has not seen and it should be put to him with the 224-entry fact. The fixed devices (timer, UART) enter through a small wired-to-message converter (as RISC-V's APLIC does, `aplic.c`, 228 lines, verified: wc). What would change my mind: a four-core iteration one that never exceeds a dozen vectors (then Option 6 as a stand-in); the author wanting software-compatible ARM behaviour (Option 3); the OpenBSD port finding that a per-core threshold register is needed (then an IMSIC-style threshold added to Option 1).
- Would help you decide: his answers to R1 (a) to (e) in `smp-decisions.md` (single delivery path; 256 or fewer vectors; remapping in iteration one or two; NMI or none; priority 7 on entry); whether the table may grow (a 1,024-entry table changes `VBR` size, 6.2.3); how many vectors one device really needs (queue count of virtio-net and virtio-blk at the chosen core count); cheap measurement: `wc -l kernel-src/openbsd/sys/arch/riscv64/dev/{imsic,aplic,plic}.c kernel-src/openbsd/sys/arch/arm64/dev/agintc.c` shows 375, 228, 737 and 2,166 lines.

---

### Q8 The bus controller of errata 49 (QUESTION)
- What it is: errata 49 (2026-10-22): "the bus itself is another device with its own set of mmap registers so we can detect what is on it and request it to map a device to a particular address range; we do need some way for the bus to alert us when a device enters or leaves the bus"; it decided the bus controller is a device with eight memory-mapped registers that enumerates, maps and alerts. Errata 95 removed the eight registers but said "that the bus enumerates, maps and alerts is not changed by this entry; how it is done under virtio is part of the rewrite" (errata.md:245).
- What it is: under PCI Express the three jobs already have standard mechanisms: enumeration (reading each function's configuration space through the root complex), mapping (sizing and assigning base-address registers) and alerts (PCI Express hot-plug events and the root complex's own interrupt); the manual's present text (2.6.1 to 2.6.8) assumes exactly that, with extras proposed.
- What it is: the question: which of the controller's jobs are done by standard PCI Express and virtio, which need a pdp64-specific piece, and what is the "bus controller device" now (if anything).
- Why it matters: kernel: one recursive enumeration walk (2.6.3) and one recovery routine for departures (5.6.3); the OpenBSD `pci` autoconfiguration is large and mature, a native controller means a new bus driver.
- Why it matters: compiler: none.
- Why it matters: hardware: a PCI Express root complex is a large block and the first boards have none (Cyclone V and Zynq 7020 lack a hard block, a Zynq UltraScale+ has one: `manual-src/03-graphics.md` 3.5.2, a statement tagged D); a native controller is a small custom block; the 40 to 64-bit address and the "first few pages" rule (errata 102) must place the configuration space and windows.
- Why it matters: manual: chapter 2 (2.6) and the bus document; statements 2.6.4 to 2.6.6 (alert, precise fault on departure, queued work stays) are proposals (P), 2.6.8 (where configuration space and windows sit, how a hot-plug event behind a bridge is reported) is unspecified (S), 2.3.4 says a bus reset is "a write to a register of the root complex".
- Where things stand: `manual-src/02-bus.md:65-79`: 2.6.1 (enumeration through the root complex, D), 2.6.2 (virtio recognised by identifiers and capabilities, D), 2.6.3 (a function may be a bridge, recursive, D), 2.6.4 (alert by an interrupt then rescan, P), 2.6.5 (a departed device's window gives a precise bus fault, writes dropped and counted, P), 2.6.6 (queued work stays in memory, P), 2.6.7 (a bus reset produces no removal events, D), 2.6.8 (S). `pdp64-q64-bus.md` section 13 (lines 124-148) holds the same in proposal form; errata 67 (errata.md:217) decided "arbitrary buses are enumerated through Q64".
- Where things stand: `decisions-pending.md` F13 (where configuration space and windows sit) and F23 (hot-plug scope: lean "USB hot-plug in iteration one; PCI Express slot hot-plug as software only (the fault and event rules) until a board has slot hardware", verified: decisions-pending.md:1589 and 1614); `kernel-pain-points.md:112` (about 30 `pci=` boot options: bus numbers, BAR assignment, MMCONFIG) and :940 (hot-plug windows are guesses: defaults of 256 bytes of I/O and 2 MB of memory).
- Referents you named or liked:
  - bus as a device (no source system named): "the bus itself is another device with its own set of mmap registers so we can detect what is on it and request it to map a device to a particular address range, we do need some way for the bus to alert us when a device enters or leaves the bus" [R258]; stance: chosen, then the eight registers rejected by [R360]
  - enumeration of attached buses, from USB over PCI Express: "just as usb is unuerated over a pcie bus, our q64 bus will allow arbitrary buses to be connected to it and enumerated" [R292]; stance: chosen
  - PCI Express base, from PCI Express: "we're goinge with pcie and nvme and usb for our q64 bus" [R311]; stance: chosen
  - hot swap, from PCI Express: "didn't we talk about hot swap? does pcie allow hotswap now?" [R315]; stance: considered
  - native 8-register devices (no source system named): "forget the native 8 register devices. gone." [R360]; stance: rejected
- Option 1 - Pure PCI Express: the root complex is the bus controller: no pdp64-specific device; enumeration, base-address assignment, hot-plug and error reporting are standard PCI Express (configuration space, slot status, MSI, advanced error reporting); the pdp64's own rules (precise fault, bus reset) live in how the processor treats the root complex.
  - Rationale: errata 80 "backward compatible", errata 81 "if they don't affect the cards, the cards don't need to know"; least new design; OpenBSD already enumerates PCI Express; one standard answer to "bus as a device": the root complex is the device.
  - Precedent: the usual arrangement on x86, ARM and RISC-V servers: configuration space reached by a memory-mapped window (ECAM, an enhanced configuration access mechanism) and hot-plug by the PCI Express slot capability and its interrupt (unverified: general knowledge); PCI itself sizes windows by writing all ones to the base registers (not confirmed in the repository's sources, as pdp64-q64-bus.md:134 says). (your referent [R311])
  - Cost and risk: needs a PCI Express root complex (a hard block the cheap boards lack); the pain points of PCI configuration (kernel-pain-points.md:112, :940) come with it; the "all ones" read of a removed device is standard PCI behaviour, the opposite of 2.6.5, so the precise fault would be extra circuitry in the root complex anyway.
  - Fit: priority 1 mixed (a large standard block, and the all-ones convention the author's chapter avoids); priority 4 large; Occam good (no new entity).
- Option 2 - PCI Express plus a pdp64 root-complex function (the manual's present shape, CURRENT): standard enumeration and hot-plug as in Option 1, plus a small set of processor-side registers and rules in the root complex: a bus reset write (2.3.4), the departure alert interrupt (2.6.4), the precise bus fault and drop-and-count for a departed window (2.6.5), the queued work left in memory (2.6.6) and a reset that produces no removal events (2.6.7); these stay invisible to cards (errata 81).
  - Rationale: this is what chapter 2 already says, as D and P statements; it keeps errata 49's three verbs (enumerate, map, alert) and gives them to standard mechanisms, while the pdp64's convenience and security circuitry (errata 80) lives on the processor side.
  - Precedent: the VAX scanned its interconnect with a bus-adapter device on the nexus: `probenexi()` in 4.3BSD reads each slot's status register and the Unibus adapter's own registers hold the map registers (verified: manual-src/02-bus.md:81-83 commentary, reading the 4.3BSD sources `vaxuba/ubareg.h` and `vax/autoconf.c`); Amiga AutoConfig lets each board announce itself and be told where to live (unverified: general knowledge, "not confirmed" in the bus document).
  - Cost and risk: still needs the root complex; the extras are "(P)" and unspecified in detail (2.1.5 "The detail of the extensions is not specified"); a departed device's precise-fault rule requires the root complex to track presence per function, which standard PCI Express provides only for hot-plug slots.
  - Fit: priority 1 good (departure is detected and recoverable); Occam fair; priority 4 modest.
- Option 3 - virtio-mmio devices behind a native pdp64 bus controller (errata 49 as written, devices now virtio): drop PCI Express enumeration; the bus controller is a small memory-mapped device with a table of present devices (type, base, size, interrupt) and an alert register; each device is a virtio-mmio transport at a window the controller assigned; the transport is virtio's non-PCI form.
  - Rationale: no root complex, so the first boards (no PCI Express block) work without a soft PCIe core; it gives the author's errata 49 exactly: enumerate, map and alert, in registers; the virtio device model above the transport is unchanged, so class drivers are the same.
  - Precedent: virtio-mmio is the transport QEMU's `virt` and microVM machines use where PCI is absent (unverified: general knowledge); Amiga AutoConfig and the VAX nexus table are native controller precedents (verified for VAX: manual-src/02-bus.md:81, 4.3BSD `probenexi`).
  - Cost and risk: abandons "backward compatible with PCI Express" (errata 80) and the USB-controller-as-PCI-function plan (5.5.4), unless a bridge function appears; a real card (NIC, GPU, NVMe, USB controller) cannot be attached; two transports (virtio-pci for hosts, virtio-mmio for FPGA) in the drivers; reverses errata 75 and 80, which the author decided on 2026-11-03.
  - Fit: priority 1 good (small, simple); priority 4 smallest; Occam fair (new bus controller device, but removes PCI Express); the OpenBSD port gets a new bus.
    - Note: you said "we're goinge with pcie and nvme and usb for our q64 bus" [R311]; this option drops PCI Express enumeration (the option itself says it reverses that).
- Option 4 - A soft host-bridge facade: PCI Express in the software model, anything underneath in hardware: the processor always sees an ECAM-style configuration space and virtio-pci functions, but on the FPGA a small fabric block presents virtio-mmio-like devices as PCI functions (a configuration-space emulator in fabric, no PCI Express link); on silicon, a real root complex.
  - Rationale: keeps errata 80 and 95 as seen by software on every board, and avoids a PCI Express hard block on the first boards; one transport driver, one enumeration walk.
  - Precedent: QEMU's emulated PCI bus and its virtio-pci devices exist without any physical link (unverified: general knowledge); a PCI-compatible host bridge in an FPGA without a transceiver is a configuration-space emulator of a few hundred registers (unverified: general knowledge, I did not find a specific design).
  - Cost and risk: the facade is custom RTL that must emulate enough of the configuration space for OpenBSD's `pci` code to accept it (capability lists, base-address sizing, MSI-X table); a bug there hides as a driver bug; cannot attach a real card on that board; one more block to test.
  - Fit: priority 1 mixed; priority 4 small-to-moderate; Occam fair.
- Option 5 - Static description for the fixed machine; hot-plug only for USB (the F23 lean, made the whole story): the boot block or a small device tree lists the PCI Express root complex and every fixed device; the kernel enumerates once at boot; only the USB host controller reports arrivals and departures; PCI Express slot hot-plug is software only (the fault and event rules, no slot hardware) until a board has slots.
  - Rationale: errata 49's wish for "some way for the bus to alert us" is met where devices really come and go (USB); the bus controller stops being a device and becomes boot data; the departure fault of 2.6.5 stays for the rare surprise removal; fewest moving parts.
  - Precedent: ARM and RISC-V boards describe fixed devices in a device tree and enumerate only PCI below the root port (unverified: general knowledge); the decisions-pending lean F12 and F23 say the same (verified: decisions-pending.md:1585,1614); the pdp64's own boot design makes the hand-off name "the address of the root complex and the identity of the boot device and console" (verified: pdp64-q64-bus.md section 13, "Effects on the other documents", boot bullet).
  - Cost and risk: no hot-plug for anything but USB (a card cannot be added or removed live); a device tree is another artifact the boot ROM must carry and keep in step with the hardware; a manual statement (2.6.4, "the bus alerts the processor when a device enters or leaves") would shrink to USB.
  - Fit: priority 1 good (fewer mechanisms); priority 4 smallest; Occam strongest; compatible with Option 1 or 2 underneath.
- Recommendation: MINE (P). Option 2 as written, with Option 5's scoping of hot-plug (USB live, PCI Express software-only), and with the two missing decisions put to the author: where the configuration space and windows sit (2.6.8, after errata 102: for example a fixed base outside the first few pages) and the controller's registers listed as a short table (reset, departure alert, presence). Reason: it delivers errata 49's three verbs with standard mechanisms, matches 2.3.4 and 2.6.4 to 2.6.7 as already written, and costs only a few registers beyond what PCI Express has. What would change my mind: the first board having no PCI Express block and no budget for a soft core (then Option 4 or Option 3); the author deciding that PCI Express is more than iteration one needs (then Option 3, reversing errata 80); a finding that the departure fault of 2.6.5 cannot be built on PCI Express root-port hardware (then a presence register per function in the root complex).
- Would help you decide: which board is the first target and whether it has a PCI Express hard block (3.5.2 says Cyclone V and Zynq 7020 do not, Zynq UltraScale+ does); whether the author still wants hot-plug beyond USB in iteration one (F23); whether "all ones" for a removed device is acceptable if the precise fault proves too costly; cheap measurement: `grep -n "2.6\." docs/manual-src/02-bus.md` lists the statements affected, and `grep -n "pci" kernel-src/openbsd/sys/arch/riscv64/dev/pci_machdep.c | head` shows how a port of OpenBSD reaches PCI configuration space on a small machine.

## Q9 The conditional select and the expansions of abs, min, minu, max, maxu (QUESTION)
- What it is: a conditional select (an instruction that picks one of two values by a condition, with no branch; CMOV, CSEL) does not exist in pdp64 except as the pair `MASKEQZ`/`MASKNEZ` (a register-tested mask: rd = rc==0 ? 0 : ra, and the opposite), plus `SET cc, rd` (turns a flag condition into 0 or 1).
- What it is: the author decided (2026-11-10, errata 98) that `abs`, `min`, `minu`, `max`, `maxu` are assembler aliases (words the assembler expands into other instructions) and the manual entry shows the alias; on 2026-10-21 he said "am happy for abs/min/max to be aliases on top of it in the assembler", "it" being the select (`cmov`, `csel`, `fsel`). Nothing yet says which select, or what each alias expands to.
- What it is: the flags the five words must keep (or the decision must say it changes them): `abs` sets N and Z from the result, V when the operand is the most negative number, leaves C; `min`, `minu`, `max`, `maxu` set N and Z from the result, clear V, leave C. Any expansion that begins with `CMP` or `SUB` overwrites C, so C cannot be kept without saving it: the real choice is "change the flags, and say so" or "spend an extra instruction (`TST` result restores N, Z, clears V, but not C)".
- Why it matters (kernel): kernel code uses clamp and min/max in size computations, and a constant-time select is wanted for MAC checks and key handling (crypto-secure-core.md:188 "Constant-time select, d = c ? a : b: 3 instructions, 10 bytes").
- Why it matters (compiler): pass 1 of pcc turns a comparison used as a value into branches before the back end sees it (docs/pdp64-isa.md:1861), so no choice here pays until that is fixed; a select the optimizer may not turn back into a branch needs a rule in abi.md (crypto-secure-core.md:219).
- Why it matters (hardware): a flag-reading select needs the flag file read at the select (in an out-of-order core, flag renaming read by a data instruction); `MASKEQZ` reads only registers (crypto-secure-core.md:180 "no flag dependence to analyze"). Estimated cost of a 64-bit select: 100 LUTs for the mask pair (crypto-secure-core.md:219); native abs/min/max estimated 150-250 LUTs (pdp64-isa.md:860).
- Why it matters (manual): the entries for the five words show the alias and, if the select is undefined, they cannot (pdp64-isa.md:860 says the expansion is open).
- Where things stand: pdp64-isa.md:860 (section 4.12: aliases decided, expansion not decided, the build still encodes native `AESC` sub-opcodes 0x08 and 0x10-0x13); pdp64-isa.md:1653 (section 12 item 15: select on hold "until there is a speed model", "size-neutral and pays only in speed"); errata.md:249 (errata 98); errata.md:235 (errata 85: "the branch-free select (`MASKEQZ`) is adopted"); crypto-secure-core.md:28 (a flag-based `CSEL cc, ra, rb, rd` reserved at `AESC` 0x23, "not recommended now") and :17 (`BSEL rm, ra, rb, rd`, bitwise select, in the proposal); spec/pdp64-32/pdp64-32.hbnf:153,164,172 (abs in group R2, min, minu, max, maxu, maskeqz, masknez in group R3, bsel in a further group; R2 and R3 are 32-bit forms: leaf-R2-1 and leaf-R3-1 are 12+5+5+10 and 10+1+5+6+5+5 bits).
- Where things stand: measured use, amd64 -Os on the corpus: abs 18 sites, absu 5, min 171, max 52 over 95 files, "under 0.1% of code" (pdp64-isa.md:1856); 783 cmov and 673 set<cc> in 284,641 instructions (pdp64-isa.md:1861); gcc/clang emit cmov at 0.28% of instructions.
- Where things stand: the author's words: "am happy for abs/min/max to be aliases on top of it in the assembler" (2026-10-21); "abs/min/max are aliases, and their entries in the manual show the alias" (2026-11-10, errata 98); "the branch-free select (`MASKEQZ`) is adopted" (errata 85, 2026-11-03).
- Referents you named or liked:
  - cmov/csel/fsel, source system not named by you: "I am interested in the cmov/csel/fsel need to know more about it, am happy for abs/min/max to be aliases on top of it in the assembler" [R177]; stance: considered
  - abs/min/max as opcodes, source system not named: "add them. and if we have to teach the front end about abs/min/max nodes that is fine.... surely other cpus have these opcodes" [R176]; "why do them as single opcodes insted of as an opcode that takes a flag?" [R178]; stance: considered
  - Ockham rule, no source system: "ockam. don't multiply entities without benefit" and "no wierd side effects, no bumping other opcodes in a way that makes code size increase" [R145]; stance: chosen
  - floats in the general registers, no source system: "of course floats go in general registers that is the way the pdp64 is designed" [R152]; stance: chosen
  - ROL as an alias of ROR, from the PDP-11 instruction set: "you made a good case for ror over rol, althought the assembler could take rol and map it  to ror" [R138]; stance: chosen
  - timing channels, no source system: "no timing channel attacks; there should be constant time flag or something" [R253]; stance: rejected (the attacks)
- Counting convention below (estimates, to be checked against the assembler): `CMP`, `MOVQ`, `BIS`, `NEG` register-register 2 bytes, `SET cc` 4 bytes (AESC 0x20), `MASKEQZ`, `MASKNEZ`, `BSEL`, any new `CSEL` 4 bytes (crypto-secure-core.md:176, 195, 258). Native `min`, `abs` etc. in the pdp64/32 grammar: 1 instruction, 4 bytes.
- Option 1 - Flag-based CSEL (CSEL cc, ra, rb, rd): one new 4-byte instruction that reads N, Z, C, V and picks ra or rb.
  - Rationale: the natural select for a machine with flags; `min` is 2 instructions and 6 bytes (`CMP a,b` ; `CSEL lt,a,b,d`); `abs` is 2-3 instructions (`NEG a,t` ; `CSEL mi,a,t,d`: after NEG, N set means a was positive and not the minimum, so d = N ? a : t; V is then exactly "operand was most negative", Z matches, but N and C do not describe d); one select also serves float values, which live in the general registers (pdp64-isa.md:1653). Condition field: 15 words of the 7-bit sub-opcode space of R3 (51 of 128 used), as `SET cc` does with its own slot.
  - Precedent: ARM64 CSEL, CSINC, CSINV, CSNEG select by flags and Arm's DIT guarantee lists conditional select among the data-independent instructions (verified: docs/hardware-vulnerabilities.md:137); x86 CMOVcc, SPARC V9 MOVcc, s390x LOCR, Alpha CMOVxx (unverified: general knowledge); the repository itself already reserves it (verified: docs/crypto-secure-core.md:28). (your referent [R177])
  - Cost and risk: flags for `min`/`max`: N and Z would describe the compare, not the result, V and C are the compare's (so V is not cleared and C is changed): the flag rule of errata 98 is broken unless a `TST d` is added (3 instructions, 8 bytes); needs a flag read on the select unit; a flag-reading select on a secret is only constant-time if the flags came from a constant-time compare (they do: `CMP` is fixed-latency); 250 LUTs or less (estimate) and a sub-opcode block; effort: assembler, sim64, pcc, QEMU, LLVM, two manuals.
  - Fit: priority 2 best of the real options (2 instructions); priority 1 neutral; in-order and out-of-order both fine but adds a flag consumer; adds one entity (CSEL) beside `MASKEQZ`, which Occam counts against it.
- Option 2 - SET plus MASKEQZ/MASKNEZ sequences, no new instruction: the aliases expand over what errata 85 already adopted.
  - Rationale: no new opcode, no flag reader, one select for everything, constant time by construction (crypto-secure-core.md:310 lists `MIN`, `MAX`, `ABS`, `MASKEQZ` in the always-constant set).
  - Precedent: LoongArch `maskeqz`/`masknez` and RISC-V Zicond `czero.eqz`/`czero.nez` are exactly this pair and RISC-V base has no select at all (unverified: general knowledge; crypto-secure-core.md:176 also says "from memory"); RISC-V Zbb has native `min`, `minu`, `max`, `maxu` and no `abs` (unverified: general knowledge).
  - Cost and risk: `min a,b,d` = `CMP a,b ; SET lt,c ; MASKEQZ a,c,t ; MASKNEZ b,c,d ; BIS t,d` = 5 instructions, 16 bytes, two scratch registers, against 1 and 4 now (+4 instructions, +12 bytes per site); `abs` has no need of a select: `ASR a,#63,m ; XOR m,a,d ; SUB m,d` = 3 instructions, about 6 bytes (the shift and the register-register forms need checking) with V not set at the minimum; over the 223 min/max sites in the corpus that is about +890 instructions and +2.7 KB (about 0.3% of instructions, estimate from the corpus counts above, not a pdp64 measurement); C is changed; the assembler needs scratch registers (nothing is reserved except `R12`, which is the linker's) so an alias that silently uses a register is a strange side effect (priority 1).
  - Fit: priority 1 good (no new hidden state; but silent scratch use is bad); priority 2 worst (5 instructions in hot min/max loops, hot-loop weight); priority 4 best (no gates); priority 6 poor (aliases hide five instructions).
- Option 3 - A register-conditioned select, three operands (SELECT rc, ra, rb, rd: rd = rc != 0 ? ra : rb): the select reads a register, not flags, and does both halves in one instruction.
  - Rationale: constant-time select in 1 instruction instead of 3 (crypto-secure-core.md:188); no flag read; the condition comes from `SET cc` (2 instructions for the whole compare-and-select: `CMP a,b ; SET lt,c ; SELECT c,a,b,d` = 3 instructions, 10 bytes); the `MASK` pair stays as the primitive or is dropped (Occam: one instruction replaces two, `MASKEQZ(a,c)` is `SELECT c,a,zero`).
  - Precedent: MIPS MOVN and MOVZ (rd = rs if rt != 0, or == 0) and Alpha CMOVxx (tests a register against zero) are register-conditioned selects (unverified: general knowledge); RISC-V Zicond is the two-input form of the same idea (unverified).
  - Cost and risk: a third read port is not new (the grammar has `fmadd` with four register fields, group R4); needs a four-register 4-byte form, which exists (form R4: `o1 o2 o3 o4`, spec/pdp64-32/pdp64-32.hbnf:169-171); `min` = 4 instructions, 12 bytes (`CMP`, `SET`, `SELECT` and the compare of the flags is still lost); the author already adopted `MASKEQZ` (errata 85), so this reopens a decision of 2026-11-03 or sits beside it as a third entity.
  - Fit: priority 2 middle (3 vs 5 vs 2); priority 1 good (no flags); priority 4 about the same as the mask pair; Occam: replaces two entities by one, or adds one.
- Option 4 - Bit select BSEL (BSEL rm, ra, rb, rd: rd = (rm & ra) | (~rm & rb)) as the only select, with the mask made from the condition.
  - Rationale: BSEL is already proposed for crypto (Ch and Maj of SHA-2, constant-time swap) and does a mask-controlled select in 1 instruction; with a mask `m = -c` computed from `SET` it selects any width, any bit pattern.
  - Precedent: ARM NEON `BSL`/`BIT`/`BIF` and the x86 ternary-logic instruction (VPTERNLOG) (unverified: general knowledge); in the repository: crypto-secure-core.md:17 and :252 (verified, proposed).
  - Cost and risk: `min a,b,d` = `CMP a,b ; SET lt,c ; NEG c,m ; BSEL m,a,b,d` = 4 instructions, about 14 bytes; the compare is two instructions plus the negate; the swap case is cheap (about 25 against 50 instructions in X25519, crypto-secure-core.md:213), the scalar select case is not; the file itself says `BSEL` is the one to drop if entities must fall (crypto-secure-core.md:258).
  - Fit: priority 2 modest; priority 3 neutral (a four-register 4-byte form); Occam neutral (replaces `MASK*` use in crypto, still needs the mask).
- Option 5 - A two-operand flag-reading conditional move (CMOVcc rs, rd, 2 bytes, destructive; the x86 shape):
  - Rationale: a 2-byte form beats every 4-byte select in code size; `min a,b,d` = `MOVQ a,d ; CMP d,b ; CMOVgt b,d` = 3 instructions, 6 bytes, no scratch register, and it is the shape that hardware branch-over-a-move fusion also produces (see below).
  - Precedent: x86 CMOVcc (conditionals: dest register read-modify-write), SPARC V9 MOVcc, s390x LOCR (unverified: general knowledge). (your referent [R177])
  - Cost and risk: needs a 2-byte slot: the file records that the last spare ALU slot is 0x23 and "a two-byte form would write flags; not worth the last spare slot for a crypto-only instruction" (crypto-secure-core.md:182, verified); a read-modify-write destination is a dependence that out-of-order machines dislike (the instruction depends on the old rd even when not taken); the select of a secret is constant-time only if the core promises it.
  - Fit: priority 3 best (two bytes); priority 2 good (3 instructions); priority 1 neutral; priority 5 acceptable (compilers know the shape); consumes the last spare slot.
- Option 6 - No select instruction: aliases expand to a compare and a short branch over a move (MOVQ a,d ; CMP d,b ; Bgt over ; MOVQ b,d), optionally fused by hardware into one micro-op.
  - Rationale: nothing new at all in the architecture; the alias costs 3 or 4 instructions; the hardware may fuse a forward branch over one instruction into a predicated micro-op, as short-forward-branch implementations do, so the expansion costs nothing on cores that fuse and nothing is promised on cores that do not.
  - Precedent: the PDP-11 and the VAX have no select at all and compilers emit a branch (unverified: general knowledge); RISC-V base has no select and a few high-performance cores fuse a short forward branch with a following instruction (unverified: general knowledge).
  - Cost and risk: not constant time (a branch on data), so `min`, `max` and `abs` must be taken out of the always-constant list (crypto-secure-core.md:43 and :310 list them), which contradicts the secure-core promise and the "no timing channel" decision; a data-dependent branch mispredicts at a rate depending on the data; the flags after the sequence are those of the compare.
  - Fit: priority 1 worst (a hidden branch in an alias; errors on timing channels); priority 2 middle; priority 4 best; priority 6 poor.
  - Note: you said "no timing channel attacks; there should be constant time flag or something so instructions always take an equal amount of time no matter the input": [R253]
- Recommendation: MINE, a proposal (P), not a decision: Option 2 for the architecture (`MASKEQZ`/`MASKNEZ` stay the one select, errata 85) with `abs` expanded without a select (`ASR`/`XOR`/`SUB`), and the manual states plainly that the five words change C and may use no scratch register the program can see (so the assembler needs a reserved temporary, `R12` is the linker's); if `min` and `max` in hot loops matter (they are 0.1% by count, but hot-loop weight applies), add Option 1 in the same R3 sub-opcode block as a later, measured step and keep the same aliases (the alias then shrinks from 5 instructions to 2 without anyone rewriting source). What would change my mind: a pdp64 compile that shows min or max inside hot loops (a sorting or clamping kernel), or the author preferring that the alias be as short as the native form (then Option 1 now), or the author reading D3 below as "native again".
- Would help you decide: dynamic counts of min, max, abs executed in the benchmark loops under `sim64` (the static corpus counts are above and are amd64); whether `CMP` and `ASR` have 2-byte register-register forms in pdp64/32 (the byte counts above assume it); a decision on what the flags are after an alias (the choice of Option 1 or 2 depends on it).

### D3 abs, min and max as assembler aliases (REVIEW)
- What it is: his decision of 2026-11-10 (errata 98): the five words are not instructions, only names the assembler expands, and the manual shows the expansion. This reverses errata 23, where they were `AESC` sub-opcodes (0x08 abs; 0x10-0x13 min, minu, max, maxu) added at his request; the pdp64/32 grammar still has them native (spec/pdp64-32/pdp64-32.hbnf:153 `abs` in R2; :164 `min` `minu` `max` `maxu` in R3).
- What it is: saves and costs, said plainly. Saves: opcode space (five sub-opcodes in the arithmetic escape; in the pdp64/32 grammar R2 and R3 sub-opcode slots: 1 of 67 and 4 of 51 used for these), hardware (native estimated 150-250 LUTs, pdp64-isa.md:860, reusing the negate path and the compare of `SUB`/`CMP` with a 64-bit select), verification surface (five words with flags), the manual (no five entries of semantics). Costs: instructions executed (1 becomes 2 to 5 depending on Q9), bytes (4 becomes 6 to 16), the flag guarantee (N, Z, V, C), the constant-time promise unless the expansion is branch-free, and the compiler (idiom recognition must see the expansion or emit it).
- Why it matters (compiler): pcc and LLVM must recognise `?:` and `max()` idioms and emit either the alias or the sequence; with a native word that is one pattern; with an alias it is a sequence the optimizer can break (or turn into a branch).
- Why it matters (hardware): fewer gates (estimated saving 150-250 LUTs, less if a select of the same width is added by Q9, 100 LUTs for the mask pair); out-of-order: no flag consumer if the select is register-conditioned.
- Why it matters (kernel and manual): hot loops in the kernel (clamps, sizes) pay the extra instructions; the manual gets five alias entries that show an expansion with a scratch register.
- Where things stand: errata.md:249 (errata 98); errata.md:75 (errata 23, history); pdp64-isa.md:860 (section 4.12), :1511 (the group "adds no operation by the folding rule"), :1856 (18 abs, 5 absu, 171 min, 52 max sites over 95 files, "under 0.1% of code; the case is clarity and the idiom, not size"); the build still encodes them native (pdp64-isa.md:860).
- Where things stand: the author's words: "abs/min/max are aliases, and their entries in the manual show the alias." (2026-11-10).
- Referents you named or liked:
  - cmov/csel/fsel, source system not named by you: "am happy for abs/min/max to be aliases on top of it in the assembler" [R177]; stance: considered
  - ROL as an alias of ROR, from the PDP-11 instruction set: "the assembler could take rol and map it  to ror" [R138]; stance: chosen
  - Ockham rule, no source system: "ockam. don't multiply entities without benefit" [R145]; stance: chosen
  - abs/min/max as opcodes (the earlier request, errata 23), source system not named: "add them. and if we have to teach the front end about abs/min/max nodes that is fine.... who knows how much of an optimization this might bring us" [R176]; "do we have abs opcode?" [R173]; stance: considered (reversed by errata 98)
  - native FP ops in general registers, no source system: "of course floats go in general registers" [R152]; stance: chosen
- Option 1 - CURRENT: aliases over the conditional select (errata 98).
  - Rationale: Occam ("an assembler alias beats an instruction", priority-lists.md list 2, item 3); the select is useful beyond the five words (any `?:`), the five words cost no opcode.
  - Precedent: RISC-V base has neither min/max nor abs and Zbb adds native min, minu, max, maxu (unverified: general knowledge); ARM64 has native ABS (FEAT_CSSC) in recent versions and had it as `CSNEG` alias before: `abs` is a documented alias of `CMP`+`CSNEG` (unverified: general knowledge, version not known); ROL is an alias in this repository (verified: docs/pdp64-isa.md:1855 area, "`ROL` survives as an assembler alias"). (your referent [R138])
  - Cost and risk: 223 min/max sites + 23 abs sites: +1 to +4 instructions and +2 to +12 bytes per site (estimate; see Q9) which is up to 0.3% of instructions on the corpus; flag guarantee lost unless a `TST` is added; depends on Q9, and until Q9 the grammar, `as64`, `sim64`, pcc, QEMU, LLVM, the manual disagree (pdp64-isa.md:860).
  - Fit: priority 1 neutral (flag change must be written down); priority 2 worse than native; priority 4 better (fewer gates); priority 6 hides code.
- Option 2 - Before: native sub-opcodes of the arithmetic escape (errata 23), the state of the grammar and every tool today.
  - Rationale: 1 instruction, 4 bytes, flags exactly as specified (abs: N, Z, V; min/max: N, Z, V cleared, C untouched), constant time by construction, no scratch register, no dependence on Q9.
  - Precedent: RISC-V Zbb min, minu, max, maxu (native); x86 has none before SSE4/AVX and AVX-512 `VPMINSQ` and a scalar-code idiom uses `cmp`+`cmov` (unverified: general knowledge); FMIN, FMAX, FABS in this repository are native (verified: spec/pdp64-32/pdp64-32.hbnf:164 `fmin`, `fmax`, `fabs` at :154).
  - Cost and risk: five sub-opcodes and 150-250 LUTs (estimate); five more words to specify and test; the author reversed it for Occam, so it reverses the reason he gave.
  - Fit: priority 2 best; priority 1 best (flags exact); priority 4 worse; Occam worse.
- Option 3 - Hybrid: `abs` an alias with a select-free expansion (`ASR a,#63,m ; XOR m,a,d ; SUB m,d`, 3 instructions), `min`, `minu`, `max`, `maxu` stay native (4 sub-opcodes, the hot ones).
  - Rationale: 223 of the 246 sites are min and max, and `abs` is the one whose alias needs no select and no scratch beyond one register; opcode space saved is 1 of 5, but the hot-loop cost falls on the rare word.
  - Precedent: RISC-V Zbb has min/max native and no abs (the compiler emits the shift, xor, sub form) (unverified: general knowledge); gcc and clang expand `abs` to such a sequence on RISC-V (unverified).
  - Cost and risk: a half-and-half rule is harder to explain in the manual; V is not set for the most negative number; min/max still need a native compare-select unit.
  - Fit: priority 2 good; priority 1 good; Occam slightly better than Option 2.
- Option 4 - Alias over a flag-based select, with hardware fusion of the pair: the assembler emits `CMP` + `CSEL` and the decoder fuses the adjacent pair into one micro-operation that behaves as the native instruction.
  - Rationale: the architecture stays without the five opcodes, yet the speed and the flags of the native instruction return on cores that fuse; on cores that do not, the pair costs 2 instructions, 6 bytes.
  - Precedent: macro-op fusion of compare and branch on x86 and ARM cores is documented practice (unverified: general knowledge); RISC-V explicitly lists fusion pairs as an optimisation, not as architecture (unverified).
  - Cost and risk: fusion is a micro-architecture feature that must be made safe for out-of-order (priority 1: no strange timing: a fused pair on one core and not another differ in time, so the constant-time promise must be made per list, not per fusion); needs Q9 option 1 first; spends the gates saved on the decoder.
  - Fit: priority 2 near native; priority 4 not better; "ready for out-of-order from the start" good.
- Option 5 - Neither: remove the five words and keep only the idioms in the compiler (no alias, no instruction).
  - Rationale: Occam at its limit; 246 sites in 284,641 instructions (about 0.09% of instructions) do not justify manual entries; the select sequence is the documentation.
  - Precedent: the PDP-11 and the VAX have no min or max (VAX has `MNEGx` and `ABS` as `ABSx`? not sure: do not rely); RISC-V base has none (unverified: general knowledge).
  - Cost and risk: priority 6 (assembler pleasant) and clarity lost, which pdp64-isa.md:1856 says is the case for them; hand-written assembly repeats 3-5 line idioms that go wrong (the most negative `abs`, signed against unsigned `min`).
  - Fit: priority 1 worse (hand idioms err); priority 2 same as Option 1; Occam best.
  - Note: you said "add them. and if we have to teach the front end about abs/min/max nodes that is fine" [R176] and later "am happy for abs/min/max to be aliases" [R177]: removing them outright is neither
- Recommendation: MINE, a proposal (P), not a decision: keep CURRENT (Option 1) but resolve it with Q9 and write the flag change into errata 98: the alias leaves C changed and N and Z described by the sequence, because that is what a select without flags can do; for `abs` use the select-free three-instruction form; if hot-loop measurements later show min and max matter, Option 3 or 4 recovers speed without reversing the author's rule. What would change my mind: a compile of hot loops with min, max and abs showing the extra instructions in the critical path, or the author deciding that "the flags are exactly as before" is a requirement (then Option 2 or 3).
- Would help you decide: the dynamic counts of the five words in the benchmark loops (`sim64` with the five words native and again with the expansion: instructions executed and code size); the LUT estimate of the select unit versus the native five; whether the secure-core promise must list `min` and `max` (crypto-secure-core.md:43).

### Q10 Stack alignment (QUESTION)
- What it is: the stack pointer (R14) must be kept at some multiple, so that pushes and locals land at addresses a quad (8-byte) load can use; docs/abi.md:10 says "the stack pointer is a multiple of 8 at all times".
- What it is: on 2026-10-21 the author asked "accept the abi, skip hbnf for now, keep going but stack aligbnent why not 2 bytes instead of 8?" (thread 1889, message 1712); no answer or ruling is recorded (docs/decision-log/pdp64-status.md:432, "Left: ... no answer or ruling is recorded"). The decision-log Decided line says "no standing decision".
- What it is: the short answer to his question: 2 is the right number only when the machine pushes 16-bit words, as the PDP-11 does. In pdp64 a push, a return address and an argument slot are each 8 bytes (abi.md:12, 8-byte slots; `CALL` pushes the return address), and a quad access to an address not a multiple of 8 aborts with `ALIGN` (pdp64-isa.md:1233, "this rule may not be relaxed"); so an SP of 2 mod 8 would make the first push abort. 2 would be possible only if quads were pushed with the explicit unaligned `MOVU*` forms, which cost two accesses.
- Why it matters (hardware): the rule is checked by the existing `ALIGN` abort (no new gates); a stricter rule (16) can be checked at the write of SP or left to the first access.
- Why it matters (compiler): frame layout, `alloca`, variable-length arrays and spill slots must keep the alignment; the compiler can assume it or must re-align the stack in a prologue for types that need more.
- Why it matters (kernel): the exception and signal frame start on a stack of the same alignment; context switch saves SP unchanged; `setjmp`/`longjmp` save and restore SP and so preserve whatever alignment it has.
- Why it matters (ABI and C): C's `max_align_t` is 8 here (long double is double, no type wider than a quad: abi.md:10); `malloc` alignment and stack alignment follow it; a larger stack alignment is wanted only for a type with larger alignment (a 128-bit type or a SIMD vector, none planned: "Wide data-parallel work goes in a Q64", pdp64-isa.md:1893 area).
- Where things stand: abi.md:10 (8 at all times, "No 16-byte alignment: no type or register is wider than a quad"); abi.md:12 (arguments in 8-byte slots), :20-24 (variadic: the prologue pops the return address, pushes `r5`..`r0` and pushes the return address again, so the register save area sits directly below the stack arguments and `va_list` is a pointer that runs on into them; 6 slots = 48 bytes); pdp64-isa.md:1231-1242 (section 7.4: natural alignment of quad access required, a tagged-pointer contract and "this rule may not be relaxed"); the registers `R13` frame pointer is "optional" (abi.md:14).
- Referents you named or liked:
  - PDP-11 stack and word alignment: his base for the design, "update and refresh of the pdp-11 instruction set and architecture" [R187]; "upgrade it to 32/64 bit keeping nice properties" [R26]; stance: chosen (as base; no stack-alignment statement of his about it)
  - 2-byte memory alignment, no source system: "do r10 but only 2 byte memory alignment; don't put 8 byte memory alignment constraints that would be horrible" [R32]; stance: considered (later: "align 64 bit values the natural way; as long as we have circuitry to access individual bytes i'm ok with loading in 64 bits" [R321]; stance: chosen)
  - stack alignment, source system not named: "accept the abi, skip hbnf for now, keep going but stack aligbnent why not 2 bytes instead of 8?" [R154]; stance: considered
  - VAX-11 register roles, from the VAX-11: "SP is R14 and FP is R13 to match it" [R137]; stance: chosen
  - Ockham rule, no source system: "don't multiply entities without benefit" [R145]; stance: chosen
- Option 1 - CURRENT: 8 at all times, checked by the quad `ALIGN` abort.
  - Rationale: it is the smallest number every push and spill obeys, it costs no padding beyond rounding frames to 8, and a violation is detected by the first quad access (priority 1: error easy to detect).
  - Precedent: the ABI of version 1 itself (verified: docs/abi.md:10); the PDP-11 kept SP even (word) and trapped on an odd SP (unverified: general knowledge); VAX stack pointer is longword aligned by convention (unverified). (your referent [R26])
  - Cost and risk: a future 128-bit type or vector needs a declared re-alignment (Option 6) or an ABI version change; setjmp and varargs unchanged.
  - Fit: priority 1 good (detected, no cost); priority 2 best (no padding instructions); priority 5 good.
  - Note: you said "do r10 but only 2 byte memory alignment; don't put 8 byte memory alignment constraints that would be horrible" [R32] (later "align 64 bit values the natural way" [R321]): a stack at 8 at all times is an 8-byte constraint on SP
- Option 2 - 2 (what the author asked): SP only a multiple of 2, so a byte-size local is not rounded up to 8.
  - Rationale: the stack saves the average of 4 bytes per frame in a tiny-memory machine (the PDP-11 reason); 2 is the minimum for an even PC-and-parcel world (instruction parcels are 2 bytes).
  - Precedent: the PDP-11 pushes 16-bit words, the stack is even (unverified: general knowledge). (your referent [R26])
  - Cost and risk: pushes of quads would then land at misaligned addresses and abort: the push itself would have to be 2 accesses (`MOVUQ`) or the compiler would round at every frame anyway (so nothing saved); `PUSHM`, `CALL`, exception entry would be unaligned stores; the tag trick of pdp64-isa.md:1131 depends on quad alignment; for a 64-bit machine no frame with a quad local could keep the data alignment without rounding anyway.
  - Fit: priority 1 worse (detection lost or a new unaligned push path); priority 2 worse; priority 4 worse (dual access).
- Option 3 - 4 (long alignment): SP a multiple of 4.
  - Rationale: a halfway number matching `int`; no padding for a 32-bit-only frame.
  - Precedent: 32-bit ARM before EABI and early i386 ABIs used 4 (unverified: general knowledge).
  - Cost and risk: same problem as Option 2 for every quad push; the register save area (6 quads) stays 8-aligned only by luck; no gain since any quad local needs 8.
  - Fit: priority 1 and 2 worse than Option 1; no merit over 8.
- Option 4 - 16 at all times (the usual hardware-friendly number).
  - Rationale: leaves room for a 128-bit pair (`R0:R1`) and future vectors without an ABI change; matches the three most used ABIs, so ported code and compilers (gcc, clang) assume it.
  - Precedent: x86-64 System V ABI: 16 at a call; AArch64 AAPCS64: 16 enforced by hardware at SP-based accesses if enabled; RISC-V psABI: 16 (all unverified: general knowledge).
  - Cost and risk: average 8 bytes padding per frame, about one extra instruction in some prologues (round SP), and a 6-slot register save area for varargs (48 bytes) plus return address (8) needs 8 padding bytes so that `va_list` stays contiguous with the stack arguments (abi.md:20-24 would change); `setjmp` unchanged; every exception frame must round.
  - Fit: priority 1 neutral; priority 2 worse (padding instructions, hot-loop frames); priority 4 neutral; priority 5 good only if a wider type exists.
  - Note: you said "don't put 8 byte memory alignment constraints that would be horrible" [R32]: a 16-byte rule is a stronger constraint than the one you called horrible
- Option 5 - 8 at all times, 16 at calls only (aligned only at call boundaries, the System V x86-64 rule: the caller guarantees 16 when it executes the call and the callee may move SP by pushes).
  - Rationale: only functions that use a 16-aligned object pay; leaf frames and the push-heavy code keep 8-byte steps.
  - Precedent: x86-64 System V: 16-byte aligned at the call instruction, 8 after the return address is pushed (unverified: general knowledge).
  - Cost and risk: SP alignment at an arbitrary point is not known to a callee unless the ABI says (so every callee that wants 16 must compute it from the known parity of its own pushes), signal and interrupt handlers have no guarantee; hand assembly is harder.
  - Fit: priority 1 neutral; priority 2 middle; adds a rule (hidden state in SP parity).
- Option 6 - Per function declared: 8 is the ABI and a function needing more (a 16-byte object) declares it, and its prologue realigns SP and keeps the old one in the frame pointer.
  - Rationale: pay only where needed; the default ABI does not change and a future vector type adds the attribute without an ABI version.
  - Precedent: gcc `-mstackrealign` and `__attribute__((force_align_arg_pointer))`, and the `AND SP,#-16` prologue that follows (unverified: general knowledge).
  - Cost and risk: makes `R13` (optional today) mandatory in those functions and breaks `alloca`/unwinding unless the unwinder knows; the exception and `setjmp` interplay (SP restored to the saved value) is correct because `longjmp` restores SP whole.
  - Fit: priority 2 best for the common function; priority 1 good (declared, detectable); Occam good (no ABI number change); adds a compiler feature only used once something wider exists.
- Recommendation: MINE, a proposal (P), not a decision: Option 1 (keep 8), and answer the author's question in the ABI text: 2 would only be right if the push were a 16-bit word; every push here is a quad and misaligned quad access aborts. Reserve Option 6 for the first type that needs more. What would change my mind: a decision to put a 128-bit type, a SIMD vector or `long double` of 128 bits into the language ABI, or a wish to run unmodified third-party code that assumes 16.
- Would help you decide: whether a hardware check on writes to `R14` (an `ALIGN` abort at the write, rather than at the first access) is wanted (it detects the error earlier, a priority 1 gain); how many frames in the corpus contain only sub-quad locals (the padding saved by 2 or 4 is at most 7 bytes per such frame); a statement of whether `PUSH` ever pushes less than a quad.

### Q11 Constant-time execution (QUESTION)
- What it is: a timing channel (a leak through how long an instruction takes) exists if an instruction's latency depends on its operand values; "constant-time" means the architecture promises which instructions take the same time whatever the data (data-independent timing, the property crypto code needs). It is necessary and not sufficient: a secret-dependent branch, address or table index still leaks through the predictor and the cache (decisions-pending.md:590).
- What it is: the author, 2026-10-22: "there should be constant time flag or something so instructions always take an equal amount of time no matter the input"; on 2026-11-04 he decided that add and div need not take the same time as each other, "only they are timing independent of their data"; and "for non-sensitive things, constant time isn't a priority" (docs/decision-log/pdp64-status.md:191-193).
- What it is: errata 85 (2026-11-03) already decided one thing: at least one secure core has every timing channel removed (all instructions and all cache fetches take fixed time), keeps its timer ticks, and gets constant-time AES and SHA instructions; "any of these protections that cost no performance on the other cores are enabled there too" (docs/errata.md:235). What is open is the mechanism for the general cores.
- Why it matters (hardware): fast paths (divide early-out, `mscn` early exit, an early-out multiplier) are gates and speed; a fixed-latency multiplier is smaller than an early-out one (decisions-pending.md:600).
- Why it matters (kernel): `RDTIME` lets every user program measure (decisions-pending.md:588); a mode bit must be saved and restored with the `PSW`, and Linux enables DIT globally on arm64 "to be cautious" (verified: docs/hardware-vulnerabilities.md:135).
- Why it matters (compiler and manual): the compiler must not reorder, replace or turn into branches the instructions in the published list (crypto-secure-core.md:310), and the manual must list them; no instruction timing is stated in the ISA today (decisions-pending.md:592).
- Where things stand: nothing is in the ISA or simulator (pdp64-status.md:197 "not found: searched docs/pdp64-isa.md, docs/errata.md and sim64/ for DIT or a constant-time rule"); decisions-pending.md:124 and :584-:620 (P17: "proposed: option 3, a core set always constant-time plus a `DIT` bit"); crypto-secure-core.md:37-:155 (the secure class: `PSW.DIT` reads 1 and cannot be cleared on it, class register with `FIXLAT`, a reserved bus slot, a private window), :310 (the list: add, sub, logic, shifts and rotates, `MUL`, `MULH`, `MULHU`, `CLMUL`, `POPCNT`, `CLZ`, `BSWAP`, `BITREV`, `SET`, `MIN`, `MAX`, `ABS`, `MASKEQZ`, `MASKNEZ`, `BSEL`, the AES and SHA instructions; left to `DIT`: `DIV`, `MOD`, floating point, `MCMP`, `MSCN`, `MSCNN`, `MVAL`, block crypto); errata.md:233 (errata 83: "mode bits are case by case, but in general should be visible, not hidden state. putting modes in bits that are saved anyway sounds like a freebie").
- Where things stand: measured cost: compiled corpus of 827 files, 370,115 instructions: divide 149 (0.040%), block copy 154, FP divide 10, multiply 2,204 (0.595%), `mscn` none (decisions-pending.md:618); the roughly 1% slowdown for always-constant divide is an estimate with assumed 64-cycle worst and 30-cycle average, not run-time data.
- Referents you named or liked:
  - timing channels, Spectre and Rowhammer, as the failures to avoid: "no hammer-row, no spectre, no timing channel attacks; there should be constant time flag or something so instructions always take an equal amount of time no matter the input" [R253]; stance: rejected (the attacks), a constant-time flag wanted
  - constant time cost, no source system: "I wonder how much that would slow a processor down... for non-sensitive things, constant time isn't a priority" [R264]; stance: considered
  - timing independent of data, no source system: add and div "need not take the same time as each other, only they are timing independent of their data" [R324]; stance: chosen
  - mode bits saved with existing state, no source system: "mode bits are case by case, but in general should be visible, not hidden state. putting modes in bits that are saved anyway sounds like a freebie. no brainer." [R323]; stance: chosen
  - crypto on separate devices, from the PCI bus (PCI Express): "perhaps common crypto algorithms should be on their own devices on the pci bus and they can pay the price of constant time computing and serial execution, etc, while the main cores are tickless" [R323]; stance: considered
  - OpenBSD RNG advice: "pull all the openbsd recommendations in that department, see what they prefer and like, we'll go along those lines" [R323]; stance: chosen (about RNG, not timing)
  - Ockham rule, no source system: "don't multiply entities without benefit" [R145]; stance: chosen
- Option 1 - A data-independent-timing mode bit (PSW.DIT, set by the program): while set, a defined list of instructions takes time independent of operands; while clear, fast paths are allowed.
  - Rationale: fast paths stay for normal code, crypto turns it on only where needed, and the bit is saved with the `PSW`, so nothing extra to switch (errata 83: "saved anyway" is a freebie).
  - Precedent: Arm's DIT bit of PSTATE, which Linux/arm64 enables in the kernel (verified: docs/hardware-vulnerabilities.md:135 and :137); Intel's DOITM, "Intel does not recommend enabling this mode globally", with the kernel posts saying the mode is best left on (verified: docs/hardware-vulnerabilities.md:133 and :136, dated 2026-07).
  - Cost and risk: every fast path needs a disable (gates, verification: two behaviours of divide); software forgets to set it (a hidden default of "insecure"), which the 2026 kernel post calls "unacceptable"; OoO implementations must hold the promise through prefetchers and predictors (rule C8 in crypto-secure-core.md:149).
  - Fit: priority 1 fair (opt-in); priority 4 fair (gates for disable); mode bit allowed by errata 83.
- Option 2 - A core set that is always constant-time, no flag (the declared-subset form): the architecture lists the instructions that always take data-independent time; `DIV`, floating point, `mscn` explicitly excluded.
  - Rationale: no state, no flag, no gates (a fixed multiplier is smaller); the list is a design rule and the easiest to test; software may rely on it on every core.
  - Precedent: RISC-V scalar crypto Zkt: an implementer declares a subset "guaranteed ... latency independent of the data values", a promise, not a mode (verified: docs/hardware-vulnerabilities.md:138).
  - Cost and risk: divide and floating point have no safe form (crypto that needs a modular reduction by divide must avoid it); the list must be maintained as instructions are added (each of `min`, `max`, `abs`, `MASK*`, `BSEL` must stay on it: any Q9 expansion that uses a branch drops out).
  - Fit: priority 1 good for the listed set; priority 4 best (no logic); priority 2 neutral.
- Option 3 - The core set always plus a DIT bit for the rest (the current proposal P17 option 3).
  - Rationale: common case free, rare instructions covered when asked; the author's "for non-sensitive things, constant time isn't a priority" favours it (decisions-pending.md:622).
  - Precedent: Arm and Intel: a list of instructions that are constant-time always on the older parts and the mode bit for the new fast paths (verified: docs/hardware-vulnerabilities.md:133-137, the Intel guidance lists instructions already constant-time).
  - Cost and risk: two things to specify; the bit still needs fast-path disable on `DIV`, `mscn`, `MCMP` and floating point; one extra test dimension.
  - Fit: priority 1 good; priority 4 fair; consistent with errata 83's mode-bit rule.
- Option 4 - Everything integer is always constant-time, a prohibition list of exceptions, no flag (P17 option 4): `DIV` always takes its worst-case time, `mscn` always scans the whole range; floating point and `mscn` named as variable-time.
  - Rationale: the simplest to specify and verify; no flag, no fast-path logic (fewest gates); matches priorities 2 and 3 on a small in-order core.
  - Precedent: small cryptographic microcontrollers with fixed-cycle multiplier and divider (for example Cortex-M0+ single-cycle multiplier option) (unverified: general knowledge); Zkt for the listed subset only (verified: docs/hardware-vulnerabilities.md:138).
  - Cost and risk: an average divide is slower: a rough estimate of about 1% over a whole program (decisions-pending.md:618, estimate, loops that divide each iteration could weigh many times more); `mscn` loses its early exit; out-of-order cores with a big divider lose the speed that divides give.
  - Fit: priority 1 best; priority 2 and 4 acceptable on a small core; contradicts the author's "not a priority" for non-sensitive code.
- Option 5 - The constant-time core class (errata 85 widened): the promise lives on a class of core (secure), identified by the class register (`FIXLAT`), not on the instruction set: every instruction is fixed, caches private, speculation absent; other cores promise nothing beyond the Option 2 list.
  - Rationale: the strongest guarantee in the place that needs it (the whole core including cache and bus, which a mode bit cannot reach), with the general cores unchanged and fast; matches what errata 85 decided; "a separate constant-time instruction set" is the same idea at the opcode level and is not needed: the instruction set is one (crypto-secure-core.md:308).
  - Precedent: secure-element and crypto cores in smartcards; Apple's and Intel's choice to expose DIT/DOITM on general cores instead (verified: docs/hardware-vulnerabilities.md:133-140 for the vendors' general-core modes); the repository's secure class (verified: docs/crypto-secure-core.md:35-:155).
  - Cost and risk: a second core design to build and verify; general cores that run secrets have no promise beyond the list; scheduling by affinity.
  - Fit: priority 1 best for secrets; priority 4 worst (a core); out-of-order readiness unaffected.
- Option 6 - Software only: no architectural promise; each implementation publishes a safe list, libraries test with tools (P17 option 5).
  - Rationale: nothing to specify, no gates, no mode.
  - Precedent: x86 before DOITM, where Intel published a guidance list and later found AES-NI and ADD/XOR varied on Ice Lake and later (verified: docs/hardware-vulnerabilities.md:133-134); the drift is the precedent.
  - Cost and risk: the safe list drifts per implementation; the chip that leaks is the one nobody listed; contradicts errata 85 on the secure core.
  - Fit: priority 1 worst; priority 2 and 4 best (nothing).
- Recommendation: MINE, a proposal (P), not a decision: Option 3 (already the proposal), with errata 85's secure class as the strong form, and the published list written into the ISA and the manual now (the list of crypto-secure-core.md:310 exactly, including `min`, `max`, `abs`, `MASKEQZ`, `MASKNEZ`, `BSEL`, the AES and SHA instructions). Say that `PSW.DIT` is saved with the PSW (a visible, saved mode bit, errata 83) and that the compiler treats the list as untouchable. What would change my mind: a cycle measurement showing divide in hot loops (then Option 3 stays and Option 4 is dropped), or hardware that cannot cheaply disable the divide fast path (then Option 4 for divide only).
- Would help you decide: the dynamic count of `DIV`/`MOD` in the benchmark loops under `sim64` with a cycle model (static count is 149 of 370,115); the vendors' published cost of DIT and DOITM (the repository has none: "'too high' is the only qualifier", hardware-vulnerabilities.md:136); whether `DIV` has an early-out in the planned implementation (if the divider is a fixed-iteration sequencer, Option 4 costs nothing).

## Briefing D: the testing record, the priority list, the toolchain wording, the repository's fate (Q12 to Q16)

Conventions: file:line are in pdp64 unless a path is given. "pcc clone" is status-check/pcc (branch master, head 41e5c36 of 2026-11-07; it has `arch/pdp64` but its README does not mention pdp64). "pcc-enc" is pcc-enc (a worktree whose gitdir points at pcc/.git/worktrees/pcc-enc, which does not exist, so `git` fails there; the files are readable). The author's decisions of 2026-11-09 and 2026-11-10 are errata 94 (docs/errata.md:244).

Facts found while reading that bear on several items (all checked):
- The raw measurement scripts named by integration.md are NOT in any repository: docs/encoding-work/integration.md:4 names `scratchpad/int/` (`corp.py`, `corpus.py`, `build6.py`, `runtm.py`, `norelax.py`, `runsmall.py`, `final.py`); `pdp64-enc-int/scratchpad` does not exist and a search of the machine for `runtm.py`, `norelax.py`, `corp.py`, `build6.py` found nothing. Only `docs/codegen-data/encoding/final.py`, `final.json`, `final.log` and `tests/timing/{check_timing,dynrun,run16}.py` are tracked. The tables of integration.md section 4 (207 lines, 4.1 corpus bytes, 4.2 six programs, 4.3 timing, 4.4 predictions against measurements) are therefore a record of numbers, not a reproducible run.
- What can reproduce part of it today: `tools/pdp64size.sh` (code size), `tools/pdp64test-all.sh -m pdp64/NN` (README:56: 963, 602, 963 runs), `sim64 -P` (profile), `sim64 --timing=SPEC` and `tools/timing.py` (tools/ lists `timing.py`, `mk-exec-tm.py`, `check-timing.sh`), `as64 --stats`. The compiler for r20 and /16 is the 16-register build `build/pcc/ccom` (README:55), /32 is `ccom32`; both need `PCC=the pcc tree`.
- Sizes on disk (git ls-files): docs/manual/pdp64-r20 993 files (5.7 MB), pdp64-16 1,469 files (7.9 MB), pdp64-32 1,472 files (8.0 MB); book/ 8 tracked files including the three PDFs (6.9, 7.2, 7.4 MB); spec/pdp64-16 and spec/pdp64-32 2 files each (132 KB, 148 KB); the repository tracks 4,830 files, of which 2,462 are in the two comparison manuals (993 + 1,469). No git tag exists (`git tag` is empty). Local branches `enc-cb enc-hb enc-int enc-ld enc-prefix enc-tm man-gen man-hand` exist, each with a worktree (`git branch -a`), so the history of the work is already on branches.
- The `-m` option is in as64 (as64/as64.c:1324 usage string, `[-m pdp64/r20|pdp64/16|pdp64/32]`), ld64 (reads e_flags), sim64, the three ccom builds, and about 141 tracked non-manual files mention `pdp64/16`, `pdp64/r20`, `pdp64-16` or `pdp64-r20`. tools/check-all.sh (32 lines) runs the encodings through check-enc.sh, check-grammar-enc.sh, check-exec-enc.sh, check-sim64.sh (loops over `r20 16 32 16r 32r`, check-sim64.sh:17), check-ld64.sh (`$e`), check-relax.sh, check-p2.sh, check-timing.sh; the integration clean-checkout run gave rc 0 in 2 min 1 s (integration.md:206).
- Published pages: _config.yml is a plain GitHub Pages/Jekyll file (10 lines) that excludes only tools/codegen/doc_template.md; the whole docs/manual tree is published, and README:5 links the pdp64/r20 and pdp64/16 manuals and PDFs from the front page.

---

### Q12 The testing against r20 and pdp64/16 (QUESTION)

- Resolved on 2026-11-10 (errata 122 [R374] and 123 [R375]): r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and removed as code (tags pre-single-cpu and pre-code-removal keep them); the options below are history
- What it is: the author wants the testing of the original encoding (r20) and the 16-register prefix-coded encoding (pdp64/16) against the chosen pdp64/32 documented ("it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons. follows our principles of check, don't guess", errata 94, 2026-11-10); the open point is the form of the document.
- What it is: the evidence already exists in four places: integration.md section 4 (final table: corpus bytes 1,083,870 r20 / 934,470 /16 / 964,158 /32; six programs 755.8 M / 609.8 M / 572.8 M instructions executed; timing; predictions against measurements 4.4), timing.md (19 lines, the partial timing agent report), phase1 to phase3 and cbreach.md/ldrelax.md, and one sentence in README (the Status bullet "13.8% (pdp64/16) and 11.0% (pdp64/32) smaller than pdp64/r20 ... 19% and 24% fewer instructions").
- What it is: "check, don't guess" means the document should let a reader repeat the check; today the raw scripts are lost (see the facts above), so the claim "chosen for performance" rests on a report whose method is described but not reproducible end to end.
- Why it matters: kernel, none directly (the kernel will target /32 only); compiler, the report is the only place that says what "the old compiler on r20" means (output byte-identical to pcc-enc `-m pdp64/r20` on all 841 files, integration.md section 4 intro) and that no "r20 with the new compiler" column exists; hardware, it justifies the 32-register file and the prefix-coded encoding to anyone implementing it, with the honest limits (in-order toy timing model, ideal memory, `integration.md:196`); manual, the manual of the pdp64 can cite one stable place instead of three.
- Where things stand: docs/encoding-work/ is described as "a record" that is not edited when overturned (docs/encoding-work/README.md:3-5); integration.md is 207 lines, its header still says "Branch `enc-int` ... Nothing was merged into `main`" (integration.md:3) although it now lives on main, and its section 5 first bullet says the manual is not updated (integration.md:191), which errata 93/94 have overtaken; the docfix agent asked the author exactly this question ("Is a dedicated document of the testing ... wanted? (a) integration.md serves, (b) a short docs/why-pdp64-32.md", docs/decision-log/docfix-reports/pdp64-P1.md, question 1) and made README state the comparison with a pointer to integration.md; errata 94 names `integration.md` section 4 and `timing.md` as the documentation (docs/errata.md:244).
- Referents you named or liked:
  - check, don't guess (the test of the document), from your own principles: "it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons. follows our principles of check, don't guess." [R370]; stance: chosen
  - checking statements rather than memory, no source system named: "you're doing a lot from memory, i want you to check all the statements you've made today" [R220]; stance: chosen
  - 16 to 32 registers, measured: "my switch from 16 to 32 registers was the right move, instructions went down even while bytes increased 2%" [R363]; stance: chosen
  - RISC-V, comparison of ISAs: "you didn't compare the riscv and pdp64 isa even to the extent of comparing how many opcodes or operator bit layouts there are" [R365]; stance: considered
  - manual as the main deliverable, no source system named: "the manual for the arch (not only the isa) is the primary deliverable" [R267]; stance: chosen
- Option 1 - CURRENT in practice: keep docs/encoding-work/integration.md as it is, with README and errata 94 pointing to it: no new file.
  - Rationale: zero effort, the file is already accurate about numbers and limits, and the encoding-work folder's own rule is that records are not edited.
  - Precedent: this repository's own practice for records (verified: docs/encoding-work/README.md:3-5, "the earlier file is not edited; the table at the end lists what was overturned"); errata keep superseded text "as the history" (verified: docs/errata.md:244).
  - Cost and risk: nothing to build, but a reader must read 207 lines of a merge report to find the 4 tables; the header (branch enc-int, "nothing merged") and section 5 are stale; the method is spread over six scripts that are lost, so nothing can be re-run.
  - Fit: priority 1 (check, don't guess) is weakly served: the numbers are checked but not repeatable; constraints neutral; Occam favours it (no new entity).
- Option 2 - a dedicated manual chapter or appendix: an appendix of the pdp64-32 manual ("Why 32 registers and this encoding") with the method and the final tables, generated from docs/manual-src like the rest.
  - Rationale: the manual is the book people read; the decision "pdp64/32 chosen for performance" is then part of the architecture's own account and survives even if the encoding-work folder is moved or removed.
  - Precedent: RISC-V ratified specifications carry a rationale or "history" chapter inside the manual volume itself (unverified: general knowledge; the privileged and unprivileged volumes have a "History and Acknowledgments" chapter); the repository's manual already carries decision rationale in section 1.4 (verified: docs/manual-src/01-introduction.md). (your referent [R365])
  - Cost and risk: tools/mkmanual.py, check-manual-src.py and the book (tools/mkbook.sh) must accept a new file; the member-block mechanism (`<!-- member: 16 32 -->`) would put the appendix in all three generated manuals unless marked for 32 only, and errata 94 is about to remove two of them; numbers inside the manual go stale when the compiler changes, with no check tying them to measurement (a check script would be needed).
  - Fit: priority 1 (visible, findable) good; constraints: Occam mixed (manual grows by one chapter, and the checks gain a case).
- Option 3 - a standalone report with the method and the raw numbers: one file (for example docs/why-pdp64-32.md or docs/testing-r20-pdp64-16.md) of 3 to 6 pages: question, three encodings, compilers, corpora, commands, tables, limits, answer, with the raw logs (final.log, final.json) beside it.
  - Rationale: a short document that a reader can quote, written for the question the author asked; integration.md stays the unedited record and the new file replaces the "why" that today is spread out; this is option (b) offered in pdp64-P1 question 1.
  - Precedent: SPEC CPU publishes a result page per run with the full configuration file and raw log beside the summary (unverified: general knowledge); Linux commit messages and merge-window cover letters carry benchmark tables with the commands used (unverified: general knowledge); this repository's own docs/fact-check-2026-10-22.md and docs/codegen-analysis.md are standalone reports with a method section (verified: docs/ directory listing; fact-check line 5 "Sources used").
  - Cost and risk: one new document (about a day, mostly condensing tables already written), a risk of the two documents drifting (state in the new file that integration.md is the source of the numbers); the raw scripts are still lost unless Option 4 is also done.
  - Fit: priority 1 good (check, don't guess is the title of the file); constraints: Occam slightly against (one more document) but it replaces the question rather than adding an entity.
- Option 4 - a reproducible script set with its output committed: a directory (for example tools/compare/ with `run-all.sh`, a Makefile target `make compare`) that rebuilds the three compilers, runs the 841-file size study, the six programs under `sim64 -P` and the timing sweep, and writes the tables; the committed output (final.json, final.log style) is checked by a `check` that re-runs a small subset.
  - Rationale: it is the literal reading of "check, don't guess": the claim is a command, not a report; it also protects against the loss that already happened to the scratchpad scripts.
  - Precedent: Phoronix Test Suite and SPEC CPU ship the harness and a config so any reader re-runs the result (unverified: general knowledge); this repository's own tools/check-all.sh is a one-command verification of every other claim (verified: tools/check-all.sh, integration.md:206); tools/pdp64size.sh, tools/pdp64test-all.sh and tools/timing.py are the pieces that already exist (verified: tools/ listing).
  - Cost and risk: the largest effort (the six programs need the stand-in libc and crt of `scratchpad/dyn/rt` which is also gone, and the 841-file corpus is outside the repository: corpora, v7unix-toolchain); the run takes long (the timing sweep ran about 35 ns per instruction per model per integration.md/timing.md), so it cannot be part of check-all.sh; scripts rot once r20 and /16 are removed from the tools (ties to Q16); the numbers can differ slightly because the compiler moved.
  - Fit: priority 1 best; but the effort competes with priority work on the architecture; hot-loop weight and the other constraints are untouched.
- Option 5 - a table in the README (plus the errata pointer): promote the two or three headline tables (corpus bytes, executed instructions, bytes fetched, frame loads and stores, cycles at W4/issue 1) into README "Status" or a new "Why pdp64/32" section, each number with the command that produces it and a link to integration.md.
  - Rationale: the README is what visitors see first (README:5 links the comparison manuals from the front page) and the author's question is one of public credibility; a six-line table with links answers it at once.
  - Precedent: the RISC-V and OpenBSD project pages put one summary table on the front page and link to the detailed record (unverified: general knowledge); this repository's README already states the 13.8% and 11.0% figures in one sentence (verified: README Status bullet "Compiler"). (your referent [R365])
  - Cost and risk: cheap (an hour); numbers in a README go stale and have no check (tools/check-all.sh does not compare README figures with integration.md); README is already long (116 lines) and the style is prose, not tables; it does not carry the method.
  - Fit: priority 1 moderate (findable, not repeatable); Occam fine (no new entity).
- Option 6 - a paper-style write-up: a 6 to 12 page paper (question, related work, method, results, threats to validity, conclusion) built into the book directory as its own PDF, possibly for submission.
  - Rationale: the strongest form of "check, don't guess": it states the threats (toy timing model, corpus-trained cbCC forms, the compiler tuned for the new targets only), which integration.md lists in section 5 but nobody reads; and it can be cited from outside.
  - Precedent: the Patterson and Waterman RISC-V papers and the Thumb-2 and compressed-instruction papers publish the density and instruction-count comparison as a paper (unverified: general knowledge, titles and venues not checked); this repository already has a paper-publishing project, papers-for-publication (verified: directory exists; contents not read). (your referent [R365])
  - Cost and risk: a week or more; peer-review style claims need numbers that can be re-run (so Option 4 is a prerequisite); a paper about alternatives that were cancelled before a single gate was built may read as premature; the lost scripts make it weakest exactly where a paper must be strongest.
  - Fit: priority 1 high, but cost against priorities 2 to 4 of actual design work is high; Occam: a paper is a new entity.
- Recommendation: MINE (P), not a decision: Option 3 now, with the first half of Option 4 (re-create the three or four lost scripts as tools/compare/*.sh and commit final-style output) as the follow-up, and Option 1 kept as the record underneath. The new file should be short, say the question, the three encodings, the compilers (and that "r20 with the new compiler" does not exist), the commands, the five or six numbers that decided it (corpus bytes, executed instructions, fetched bytes +2.92% for /32 over /16, frame loads and stores -62.8%, cycles at W4), the limits from integration.md section 5, and the answer. What would change my mind: if the author wants the reasoning inside the book that outlives the repository, take Option 2 instead; if he wants to submit, take Option 6 after Option 4.
- Would help you decide: whether the reader he has in mind is a hardware implementer (Option 2), a visitor (Option 5), or a reviewer who will re-run it (Option 4); and how soon the r20 and /16 tool support goes (Q16), because a reproducible set must run before the removal. Cheap checks: `grep -n 'scratchpad' docs/encoding-work/integration.md` (the lost-script references); `tools/pdp64size.sh` and `tools/pdp64test-all.sh -m pdp64/32` show which part re-runs today.

---

### Q13 The priority list (QUESTION)
- What it is: docs/priority-lists.md collects five priority lists with the author's annotations; its last section, "The definitive list", still contains the placeholder "(For you to write. When it is final I will replace the ranking in `pdp64-isa.md` section 1 with it and make the README, the manual's 1.4 and Part 0 of `decisions-pending.md` say the same.)" above the author's four answers.
- What it is: the definitive list itself was recorded by errata 83 (2026-11-03): (1) security and safety, (2) opcode choice, (3) opcode encoding, (4) speed and power served by low gate count, (5) good compiler target, (6) pleasant in assembler; standing constraints beside it: out-of-order readiness, the soft-rule test, hot-loop weight, Occam; dropped: "no mode bits".
- What it is: the open point is only the file: a reader of priority-lists.md sees a placeholder and not the answer, and the file's own promise (replace ISA section 1, README, manual 1.4, Part 0) has been kept elsewhere.
- Why it matters: kernel and compiler, every option elsewhere is scored against this list, so a stale or ambiguous copy lets a later agent score against the wrong one (list 5 of this very file puts transistor count first); hardware, the one real ambiguity, gate count, is stated once as "lower than speed" (priority-lists.md:123) and once as "4 and 5 are essentially the same thing" (errata 83), which an implementer reads as one rung; manual, 1.4 is the public statement.
- Where things stand: docs/priority-lists.md has 126 lines, the heading at :118 and the placeholder at :120; the author's four answers at :121-124 ("out of order safety and soft rule test are stanading constraints beside, no priorities. / no strange side effects is above code size. / gate count is lower than speed / pleasant in assembler and good compiler target never went away. htey are lower priorities."); the list is already propagated: README:21 "In order of priority", docs/pdp64-isa.md:15 "## 1. Design priorities", docs/decisions-pending.md Part 0 (heading :44, "Your priorities (definitive list, 2026-11-03, errata 83)") and its line 1551 "Decided (the author, errata 83)", docs/manual-src/01-introduction.md (contains "Security and safety"); errata 83 (docs/errata.md:233) records it and says it closes E9; the docfix agent asked "replace it with the author's list as final and update the ranking in pdp64-isa.md section 1, or leave?" (pdp64-P1.md, question 3) and found the ISA section already updated (the grep above shows it).
- Referents you named or liked:
  - your priority order, no source system named: "my top priorities are code size, easy recoverability, and speed/efficiency through fewer gates and tighter hot loops (by careful instruction choices)" [R243]; stance: chosen
  - the list in the README, no source system named: "the paragraph itself should just list my principles, in order" [R245]; stance: chosen
  - the definitive list: "yes, use that list and update the docs; 4-7 are in the right order; 4 and 5 are essentially the same thing. recovery and restart go together." [R323]; stance: chosen
  - the file of lists: "save the set of priority lists with your commentary as md ... i will edit it with my annotations" [R322]; "what is my part 0 order? show all the different priority lists i made, i'll give you the definitive one then" [R320]; stance: chosen
  - soft rules, no source system named: "all the rules are soft rules." [R242]; "the no mode bits rule is a very soft rule" [R241]; stance: chosen
  - hot loop weight and out-of-order readiness, no source system named: "a rarely used instruction can still pull its weight if its used inside a critical tight hot loop" [R296]; "we have to make the decision safe for out of order implementations" [R295]; stance: chosen
  - Ockham's razor (entity multiplication): "don't multiply entities without benefit" [R145]; stance: chosen
- Option 1 - CURRENT: leave docs/priority-lists.md untouched as the author's annotated input and rely on errata 83 and the four propagated copies.
  - Rationale: the file is a record of the author's own words, which the lists' annotations preserve; errata 83 is the definitive statement and is already written.
  - Precedent: the repository's rule that earlier records are not rewritten (verified: docs/encoding-work/README.md:3-5; errata text kept "as the history", errata.md:244).
  - Cost and risk: free; the placeholder reads as unfinished work forever, and a new agent opening only this file gets the wrong impression that the list is not decided.
  - Fit: priority 1 weak (a predictable, findable record is part of safety of the process); Occam good.
- Option 2 - promote the annotations as the list: replace the placeholder section with a "The definitive list" built from the author's annotations plus errata 83's six items, keeping his four sentences verbatim as the source.
  - Rationale: the file then answers its own question; the author's words remain, the numbered result sits next to them.
  - Precedent: the IETF process document and ISO standards keep an annotated draft separate from the published text, but the final "Status of this memo" replaces the draft banner (unverified: general knowledge); this repository's errata 83 already did exactly this synthesis (verified: docs/errata.md:233).
  - Cost and risk: low (a dozen lines); the synthesis is the assistant's, so it must be labelled as derived from errata 83 and checked by the author; two copies of the list now exist (this and errata 83) and can drift.
  - Fit: priority 1 good; Occam neutral.
- Option 3 - rewrite the file as a single numbered list: delete the five annotated lists and keep only the final list with the constraints.
  - Rationale: one source, no history to misread; the shortest document.
  - Precedent: the Linux kernel's Documentation/process files state the rule and leave the argument to the mailing list archive (unverified: general knowledge).
  - Cost and risk: destroys the author's annotated words from this file (they survive in git history and in errata 83's quotes, errata.md:233), which conflicts with this project's habit of keeping his words; the commentary that explains why r20's ranking was wrong (list 5) would be lost.
  - Fit: priority 1 weak for traceability; Occam best.
  - Note: you said you would annotate the saved set of lists with your own words ("save the set of priority lists with your commentary as md ... i will edit it with my annotations"): [R322]; deleting the annotated lists removes that file
- Option 4 - put the list in README, manual 1.4 and Part 0 of decisions-pending and nowhere else: finish the propagation the placeholder promised and mark priority-lists.md as superseded by those.
  - Rationale: the placeholder promised exactly this; in fact it is already done (README:21, ISA section 1, decisions-pending Part 0 and 1551, manual 1.4), so this is only the verification that all four say the same.
  - Precedent: this repository's own checks, such as tools/check-manual-src.py and check-drift.py, compare generated and source files (verified: tools/ listing); no check compares the priority list across files.
  - Cost and risk: a small script (grep the six items in each of the five files) would catch drift; without it the four copies can diverge as text is edited (the older ISA section 1 ranking already did once); small.
  - Fit: priority 1 good; Occam neutral (no new entity, a check).
- Option 5 - keep the file as a dated record and link: add a header ("2026-11-03: the definitive list is errata 83; this file keeps the author's annotations as the record"), replace the placeholder by a link to errata 83 and the four sentences, and change nothing else.
  - Rationale: the smallest change that removes the false impression; leaves his words and the history untouched.
  - Precedent: Git's own Documentation/technical notes and RFCs carry "Obsoleted by" headers pointing to the successor (unverified: general knowledge); this repository's errata headings carry "superseded by errata 94" (verified: docs/errata.md:243).
  - Cost and risk: two lines; nothing wrong can happen except the link rotting if errata is renumbered (errata 91 and 92 were renumbered once, errata.md:242).
  - Fit: priority 1 good; Occam good.
- Option 6 - split priorities from standing constraints: write two sections: the ordered six priorities, and the four standing constraints ("not priorities", orthogonal) as a separate list with the author's words ("orthoganal to the hierarchy", priority-lists.md:44 and :84), and say what "soft rule" means (errata 42).
  - Rationale: the author insisted twice that the constraints are not rungs (priority-lists.md, lists 2 and 3 annotations, and the placeholder answers); the README says it in one paragraph ("Four constraints stand beside the ranking"), the manual and Part 0 do too, so a structural split in the source file prevents a future reader flattening them into a ten-item list.
  - Precedent: the IETF "BCP" documents separate requirements from principles; the C++ Core Guidelines separate "philosophy" from rules (unverified: general knowledge); this repository's ISA section 1 already has "Standing constraints" apart from the ranking (verified: docs/pdp64-isa.md:29 shows the list refers to the constraints separately).
  - Cost and risk: low; it matters only if the author wants the file to be authoritative, because it then duplicates ISA section 1; also resolves the gate count ambiguity if it states "4 and 5 are essentially the same thing" explicitly.
  - Fit: priority 1 good; Occam good if it replaces rather than adds a copy.
- Recommendation: MINE (P), not a decision: Option 5 plus Option 6's one sentence on gate count, and add the small cross-file check of Option 4 to tools/check-all.sh only if the author wants drift prevented. The file is a record of his words; the list is errata 83; the placeholder is the only defect. What would change my mind: if the author wants a single canonical file, Option 2 (and then errata 83 cites it).
- Would help you decide: whether you want the six items to live in one canonical place (errata 83 today, five copies). Command: `grep -n 'Security and safety' README.md docs/pdp64-isa.md docs/decisions-pending.md docs/manual-src/01-introduction.md docs/errata.md` lists the copies to compare; and say whether "gate count lower than speed" and "4 and 5 are the same" are one statement.

---

### Q14 The relaxation wording (QUESTION)
- What it is: errata 91 says, of linker relaxation (the linker replaces long forms of `call` and `lea` by their shorter 4-byte forms once it knows the distance): "no tool needs a flag". The docfix agent pointed out that the pcc driver (`cc`, the program that runs the preprocessor, compiler, assembler and linker in turn) is not built for pdp64, so the sentence needs to say which tools it means.
- What it is: the sentence is about flags to as64 and ld64 (`--no-relax`, `--relax`), not about the compiler; relaxation is the default for pdp64/16 and pdp64/32 since 2026-11-04 ("yes do relax by default", errata 91) and r20 is untouched; with errata 94 the surviving target is /32.
- Why it matters: compiler, a build script that assembles and links must not need to know about relaxation, but must still pass `--no-relax` to get the long forms for tests; kernel, the kernel build does the same through the Makefile; hardware, none; manual, the sentence is a promise to the toolchain user.
- Where things stand: docs/errata.md:241 (errata 91, item (1)) says "...`ld64 --no-relax` links a relaxation object as the assembler laid it out, byte for byte as the plain object would link; no tool needs a flag". docs/relaxation.md:241 (section 7.5) already says it better: "A tool that assembles and links needs no flag (`tools/pdp64test*.sh` and `pdp64size.py`, which call `ccom`, `as64` and `ld64` themselves, work unchanged; the pcc driver `cc` is not built for pdp64); it must pass `--no-relax` only to get the long forms." The pcc doc agrees: "`cc/cc`, the pcc driver, is not built for pdp64 ... so every tool calls `ccom` itself" (pcc:doc/PDP64-OPT.md:20). The docfix agent for toolchain files reported "Errata 91 'no tool needs a flag' belongs to another agent" (pdp64-P3.md) and the one for errata asked (pdp64-P1.md question 4). Tools that do pass flags on purpose: tools/check-ld64.sh:36,37,55 (`as64 --no-relax`), tools/check-sim64.sh:17,37,64 (`--relax` and `--no-relax` for the plain and relaxed variants), tools/check-relax.sh:19,30 (`ld64 --no-relax`). as64.c:1324 and ld64.c:585-589 define the flags.
- Referents you named or liked:
  - relaxation by default, from your decision on the assembler and linker (no earlier system named): "yes do relax by default" [R336]; stance: chosen
  - jump relaxation, from 2BSD as (the 2BSD assembler): "so 2bsd as implemented jmp relaxing by default?  I guess we should put it in as then, take it out of cc2" [R18]; stance: considered
  - jump relaxation placement, no source system named: "add jmp relaxation to the optimizer so assembler just does straight assembling, no funky under the covers changing stuff from the plain text" [R17]; stance: considered (an earlier view, 2026-08-25; later pdp64 relaxation is in the tools)
  - check, don't guess, applied to wording: "i want you to check all the statements you've made today" [R220]; stance: chosen
- Option 1 - CURRENT: leave errata 91 as written ("no tool needs a flag") and rely on relaxation.md 7.5 for the detail.
  - Rationale: errata entries are a dated record of what the author decided; the detail is one click away.
  - Precedent: this repository's errata convention keeps old wording and appends a numbered correction (verified: docs/errata.md:243-244 "superseded by errata 94", text stays).
  - Cost and risk: free; the sentence is over-broad (it reads as if the pcc driver too needed none) and the docfix agents flagged it twice.
  - Fit: priority 1 (a precise statement is part of "no strange surprises") weak; Occam fine.
- Option 2 - reword to name the tools that call as64 and ld64: "no tool that assembles and links needs a flag: `tools/pdp64test.sh`, `pdp64test-all.sh`, `pdp64size.py` and the checks call `ccom`, `as64` and `ld64` themselves"; the pcc driver is not built for pdp64.
  - Rationale: it is the sentence relaxation.md 7.5 already uses, so the two documents agree word for word.
  - Precedent: the same repository (verified: docs/relaxation.md:241).
  - Cost and risk: one edit in errata.md:241 (an entry the author wrote the decision for; the implementer's assumption part, in italics, is the implementer's text, so an edit there is allowed as a clarification, but mark it "worded 2026-11-10"); no risk beyond renumbering.
  - Fit: priority 1 good.
- Option 3 - say who it is for: "a user of `as64` and `ld64` needs no flag; the pcc driver is not built for pdp64, so every tool calls `ccom`, `as64`, `ld64` directly" and list the only flags that remain: `--no-relax` (long forms, tests), `--relax` (as64: request the relaxation object explicitly for r20-style tests).
  - Rationale: a flag-by-flag statement removes any doubt about which tools and which flags.
  - Precedent: GNU ld's documentation lists `--relax` and `--no-relax` with their defaults per target (unverified: general knowledge; defaults vary by target) and the GNU Coding Standards ask for a clear statement of defaults.
  - Cost and risk: needs checking against code (as64.c:1352 `--no-relax`; ld64.c:585-586 both flags; `--relax` exists in as64 because tools/check-sim64.sh:17 passes it); with /32 as the only target, `--relax` in tests of `16r` disappears with Q16 anyway.
  - Fit: priority 1 good.
- Option 4 - reword and make it checkable: Option 2 and add a check that a program built with the plain tools (no flags) equals the explicitly relaxed build (tools/check-relax.sh does this for tests/sim and generated programs, relaxation.md section 6) and name it in the entry.
  - Rationale: "check, don't guess" for the sentence itself: the claim "no tool needs a flag" is then a test result.
  - Precedent: this repository's own check-relax.sh with seven mutants of ld64 (verified: docs/errata.md:241 "seven mutants"; integration.md:206).
  - Cost and risk: the check exists; the cost is one pointer in the entry; no new code.
  - Fit: priority 1 good; Occam fine.
- Option 5 - drop the sentence: errata 91 gives the decision and the mechanism; the user-facing statement lives only in relaxation.md 7.5 and the as64 usage text.
  - Rationale: Occam: one statement in one place; the errata is for decisions, not usage.
  - Precedent: GNU standards put usage in the program's `--help` and manpage, not the ChangeLog (unverified: general knowledge); the project instructions file of the project requires manpages for every program (verified: the project instructions file "Manpages for every program").
  - Cost and risk: loses a sentence the author may have read as a decision; the manpages of as64 and ld64 must then say it (check: do they? not looked at).
  - Fit: priority 1 neutral; Occam best.
- Option 6 - rewrite the whole item (1) of errata 91 now that r20 and /16 are cancelled: "relaxation is the default for pdp64 (that is /32); `as64 --no-relax` and `ld64 --no-relax` give the long forms; no other tool needs a flag", and move the r20 and /16 words behind the Q16 decision.
  - Rationale: errata 94 changes what "default for pdp64/16 and pdp64/32" means (there is one pdp64), so the sentence ages even if its tool list is right.
  - Precedent: errata 94 itself supersedes errata 87 and 93 by marking headings, text kept (verified: docs/errata.md:243-244).
  - Cost and risk: an edit in several documents (relaxation.md still speaks of members, per pdp64-P1.md question 5); a partial update leaves "members" in 3 files.
  - Fit: priority 1 good; do together with Q16.
- Recommendation: MINE (P), not a decision: Option 2 now (the sentence of relaxation.md 7.5), and Option 6's "members" rewording only after Q16 is decided. What would change my mind: if the manpages of as64 and ld64 already say it, Option 5.
- Would help you decide: which tools you meant. My reading: as64 and ld64 (and the scripts that call them), because the author's words "yes do relax by default" are about the assembler and linker. Check: `grep -n 'relax' as64/as64.c ld64/ld64.c | grep argv`; see whether man pages exist for as64 and ld64 (`ls docs/man* 2>/dev/null`; not checked).

---

### Q15 The ungated change under -xdmr (QUESTION)
- What it is: `-xdmr` is the pcc compiler flag that turns on the size optimisations modelled on Dennis Ritchie's V7 compiler; the pcc README says "Without `-xdmr` the generated code differs from stock only through the bug fixes below" (README.md:167-169 of the pcc clone). On 2026-10-17 the assistant reported one change to default PDP-11 output that is NOT behind `-xdmr` and asked "Should it stay as it is, or do you want me to find a way to gate it?" and the author answered "keep it, push, and look at qsort" (R67, 2026-10-17T10:17).
- What it is: the ungated change is found (checked): a table rule for PLUS in the PDP-11 back end: "A sum may leave its result in the register of its right operand" (arch/pdp11/table.c:488-493 in the pcc clone, comment "An addend in a register of its own: add to it, whatever the other is", `RRIGHT|RESCC`, `add AL,AR`). The assistant's words: "`p + (n << 1)` took four instructions because `p` was copied into the result register before the shifted index was computed. dmr takes three ... a table rule ... has no flag to test ... It only changes which register holds the sum, but it does change default PDP-11 output". The toolchain repository's own list records it: "PLUS leaves its result in the right operand's register | table rule | qsort, malloc" (v7unix-toolchain:BIGGER-THAN-ORIGINAL.md:56).
- What it is: a similar later rule is the OR rule (arch/pdp11/table.c:1169-1174, "OR into the register of the right operand: bis AL,AR", from commit 475529b of 2026-10-18); that one is the same kind (a table rule with no flag) and the README sentence is equally affected.
- Why it matters: compiler, the README makes a testable claim (stock-equal without `-xdmr`); a table rule makes it false for any PDP-11 program with `p + (n << 1)`; kernel and hardware, none (this is the PDP-11 back end of pcc, not the pdp64 one); manual, none; the repository relevance is the author's "check, don't guess".
- Where things stand: the Decided line is in docs/decision-log/pdp64-status.md:511 and the log says "whether any change to default PDP-11 output is ungated is not settled by the log" (:513) because the docfix agent could not tell which change from the code without a built compiler (pdp64-P3.md, first row: options (a) name the ungated change, (b) the sentence stays because the ungated change is a bug fix, (c) gate it). The 2026-10-18 squash commit 96ddd3a gated the other PDP-11 items (the `mov x,x` dropper at arch/pdp11/code.c:494 is gated by `if (!xdmr || xnoframeless)`; `byterw`, `wordrw`, `longrw`, `fwdauto`, `parmprop`, `inctree` at order.c:61; `bittest`) so, in the clone, the PLUS and OR table rules are the PDP-11 changes without a gate that I found; I did not diff the whole PDP-11 back end against stock, so other ungated changes are possible (bug fixes such as 253742a "the no-op long to long conversion is RLEFT" are meant by the README sentence). The README is at status-check/pcc/README.md:167-169 (the clone; pcc-enc/README.md:165-166 has the same text).
- Referents you named or liked:
  - the ungated change itself: "keep it, push, and look at qsort" [R67]; stance: chosen
  - -xdmr as the switch for dmr-inspired optimizations, from dmr cc (the V7 compiler): "all dmr inspired optimizations can take -xdmr for any platform that has them" [R43]; stance: chosen
  - -xdmr output against the original dmr cc: "with -xdmr we are producing faster/smaller code than the original dmr cc right?" [R64]; stance: considered
  - stock pcc (the upstream PortableCC) as the baseline: "i want stock pcc to compare against our, i mean github PortableCC repo" [R96]; "fix the 1 2 3 places where ours is worse than stock" [R113]; stance: chosen
  - upstream pcc (ragge), one change at a time: "a series of pr for him to merge, one feature, one bugfix at a time" [R118]; stance: chosen
  - fixes already made: "if the fix was already done, then keep it. just, no new fixes until we are done our benchmarking" [R107]; stance: chosen
  - emitting dmr's code from the modern pcc backend: "update the modern pcc compiler backend for pdp11 so it emits code identical to the dmr compiler, including the optimization pass" [R35]; stance: chosen
  - Steve Johnson's pcc VAX optimizations, folded under the flag: "the sj optimizations should have been folded into -xdmr flag" [R333]; stance: chosen
- Option 1 - CURRENT: keep the change ungated ("keep it", R67) and leave the README sentence as it is.
  - Rationale: the author decided; the change is small, it is a pure register-choice improvement, and the output is correct.
  - Precedent: pcc's own matcher change "a register already in place ... ranks cheaper" (commit 475529b in the clone) is also ungated (verified: git log of the clone); it is common in compilers that a table improvement has no flag.
  - Cost and risk: free; the README then says something untrue ("differs from stock only through the bug fixes"), which a reader who diffs against stock will catch, against the project's "check, don't guess".
  - Fit: priority 1 weak for the documentation; constraints: Occam good.
- Option 2 - name the change in the README: "Without `-xdmr` the generated code differs from stock through the bug fixes below and through one table rule, which lets a sum or an OR leave its result in the register of its right operand (`arch/pdp11/table.c`), kept ungated because a table rule has no flag".
  - Rationale: states the truth, with a pointer; it is what the docfix agent asked (a).
  - Precedent: the toolchain repository already lists it by name in BIGGER-THAN-ORIGINAL.md:56 (verified); GCC documents flags that change code ("-fno-...") and says which optimisations are always on (unverified: general knowledge).
  - Cost and risk: one README edit; verifies by building and diffing default PDP-11 output against stock on the 841-file corpus (a script exists in the toolchain repository's SIZE-REPORT process, pcc doc/SIZE-REPORT.md in the clone; not run by me).
  - Fit: priority 1 good (truth in documentation); Occam neutral.
- Option 3 - restate the rule as "only the bug fixes and the kept change": "Without `-xdmr` the generated code differs from stock only through the bug fixes below and the register choice of PLUS and OR (kept, decided 2026-10-17)".
  - Rationale: shortest honest restatement; records the author's decision in the README itself.
  - Precedent: the pcc README already keeps a log of such items in "Bug fixes found along the way" (verified: README.md:205); this adds one line of the same kind.
  - Cost and risk: low; the wording "the kept change" is opaque to a new reader without the name (so combine with Option 2).
  - Fit: priority 1 good.
- Option 4 - gate it behind a flag: wrap the two table rules in a condition (the table has no flag test, so the rule becomes a function in `order.c` or `local2.c` that refuses the shape without `-xdmr`, or the rule is put in a second table selected by `xdmr`).
  - Rationale: restores the invariant "no `-xdmr`, stock output", which makes stock comparison and upstream pull requests clean; the author's own plan was "one feature, one bugfix at a time" for ragge (pool.json: "a series of pr ... one feature, one bugfix at a time", R118).
  - Precedent: the assistant's own 2026-10-17 message says a special-shape workaround "would hide the operand from the register allocator" (the record at a local session record 2026-10-17T10:16:19); the author declined it.
  - Cost and risk: the author already answered "keep it" against this; a gate in a table-driven matcher is awkward and risks worse code; but it is a day of work.
  - Fit: neutral for the pdp64 priorities (the PDP-11 back end is not the pdp64); Occam against (a new condition).
  - Note: you said "keep it, push, and look at qsort": [R67]
- Option 5 - drop the change: revert the two table rules.
  - Rationale: the invariant of the README returns at no cost in code; malloc and qsort grow by a few bytes (+12 and +18 in the 2026-10-17 report: malloc was +36 before the rule, +12 after).
  - Precedent: none needed; it is a revert in the pcc history.
  - Cost and risk: contradicts the author's "keep it"; loses the size win (libc 17022 to 16986 bytes with the two fixes, -2.1% to dmr, from the 2026-10-17 report) which supports the fork's claim to be smaller than dmr cc.
  - Fit: neutral; it undoes a decision, so it needs his word.
  - Note: you said "keep it, push, and look at qsort": [R67]
- Option 6 - make it a named flag that is on by default: introduce `-xno-pluslr` (the pdp64 side already has the `-xno-NAME` convention: "every optimization of this document has an `-xno-NAME`", pcc doc/PDP64-OPT.md:59) and keep it ungated by default.
  - Rationale: "keep it" is honoured (default output unchanged) and a reader who wants stock output can switch it off; README can say exactly this.
  - Precedent: the pdp64 back end's convention (verified: doc/PDP64-OPT.md:57-59, `-xno-NAME` for each optimisation, on by default for the new targets).
  - Cost and risk: a new flag per ungated rule invites a flag per change (Occam: entities multiply), and the table has no flag test.
  - Fit: Occam against; the rest neutral.
- Recommendation: MINE (P), not a decision: Option 2 (name the change in the README, with the two rules and a sentence that they are kept ungated by the author's decision of 2026-10-17), after a measurement that default output equals stock plus those rules: build stock pcc and the fork without `-xdmr`, compile the 841-file corpus for the PDP-11, diff the assembly and list the files that differ. What would change my mind: if the diff shows further ungated differences than PLUS and OR, restate the rule as Option 3 and name each.
- Would help you decide: whether you meant the PLUS rule (the assistant's own decision text and BIGGER-THAN-ORIGINAL.md:56 say it) and whether the OR rule of 2026-10-18 counts too; the diff above; `cd status-check/pcc && git log --format='%h %ad %s' --date=short -S'RRIGHT|RESCC' -- arch/pdp11/table.c` for the commits.

---

### Q16 What becomes of r20 and pdp64/16 in the repository (QUESTION)

- Resolved on 2026-11-10 (errata 122 [R374] and 123 [R375]): r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and removed as code (tags pre-single-cpu and pre-code-removal keep them); the options below are history
- What it is: errata 94 keeps the grammars, manuals, books, test runs and `-m` options of pdp64/r20 and pdp64/16 "as that documented comparison", says "their removal is not done, and no file or tool has been removed", and lists "the removal of the two alternatives from the tools and the repository, if the author asks for it" as still to do (docs/errata.md:244). The docfix agent asked whether to keep listing removal as to do (pdp64-P1.md, question 5).
- What it is: the author says "only the 32 register pdp64 is official, the other two are cancelled", "r20 and pdp64/16 are gone, there is no family", and also "it is good to document the testing" (errata 94); these two wishes pull in different directions: gone from the architecture, kept as evidence.
- What it is: so the question is what physical form the evidence takes: files on main, a branch, a tag, an archive directory, or a report only.
- Why it matters: kernel, the kernel and any future operating system port target only /32; the loader and the sim must not accept a binary of another encoding (today `e_flags` selects the encoding, and that is a hidden-state surface on a 64-bit machine: a binary of the wrong member running silently, relevant to priority 1); compiler, pcc keeps three target names and a 16-register and a 32-register build (PDP64-OPT.md:5-16), with r20's output frozen "byte-identical to the compiler before" (PDP64-OPT.md:80), which constrains every optimisation; hardware, none, but the QEMU executor copy is built without `PDP64_ENC` (integration.md:195) so QEMU runs only r20 and the hardware-facing reference is split; manual, three generated manuals and three PDFs exist today, and the front page links the two comparison manuals.
- Where things stand: counts in the facts above. Additionally: pcc's `-m pdp64/r20` build is the 16-register `ccom` (PDP64-OPT.md:7); the 963/602/963 test runs of README:56 cover the three encodings; check-all.sh loops over `r20 16 32 16r 32r` (check-sim64.sh:17); the grammar for each encoding is in spec/pdp64-16 and spec/pdp64-32 and spec/pdp64.hbnf.in (r20 fields); `tools/mkmanual.py` generates the three manuals from docs/manual-src with member blocks (`<!-- member: 16 32 -->`, errata 93); the three PDFs are 6.9, 7.2 and 7.4 MB; the author's research documents mention the removal precedents (docs/kernel-asm-survey.md:1020, docs/kernel-pain-points.md:71).
- Referents you named or liked:
  - only /32 official: "r20 and pdp64/16 are gone, there is no family pdp64/32 is the decided upon pdp64" [R370]; stance: chosen
  - the other two cancelled: "only the 32 register pdp64 is official, the other two are cancelled" [R365]; stance: chosen
  - keeping the testing as evidence: "it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons" [R370]; stance: chosen
  - separate manuals per variant (earlier view): "the manuals for /16 /32 and /r20 are separate manuals because they are different cpus" [R343]; stance: rejected (by the later decision above)
  - RISC-V, comparison: faulted for no comparison of opcode counts or bit layouts with pdp64 [R365]; stance: considered
  - 16 to 32 registers: "my switch from 16 to 32 registers was the right move" [R363]; stance: chosen
  - both grammars: "do it as 2 grammars, the 16 reg and 32 reg ones" [R330]; stance: chosen (earlier, before the cancellation)
- Option 1 - CURRENT: keep everything as is (grammars, manuals, books, tools options, tests, published pages).
  - Rationale: errata 94 decided it; nothing breaks; the comparison remains reproducible as long as the tools run.
  - Precedent: Unix V7 and the old BSD distributions kept their historical ports in tree for years as the distribution's record (unverified: general knowledge); GCC lists obsolete targets with a switch rather than deleting at once (verified: corpora/gcc-src/gcc/config.gcc:272-285, "Configuration ... is obsolete ... Specify --enable-obsolete to build it anyway ... Support will be REMOVED in the next major release of GCC, unless a maintainer comes forward"; version 17.0.0 from gcc/BASE-VER).
  - Cost and risk: no effort; the repository stays at 2,462 comparison manual files (about 13.6 MB of the pages) and three PDFs (21.5 MB), every check keeps running five variants (`r20 16 32 16r 32r`) so check-all.sh stays slow, and the "there is no family" decision is contradicted by the front page and the tools (`-m pdp64/16`); a user can still assemble a pdp64/16 binary and believe it is a pdp64 (priority 1: hidden state).
  - Fit: priority 1 weak (a second and third encoding selectable by a flag), Occam against (three entities for one architecture), constraint "all rules are soft" neutral.
  - Note: you said "r20 and pdp64/16 are gone, there is no family" and "the other two are cancelled": [R370] [R365]
- Option 2 - keep the data and results, hide the options behind a build flag: the comparison grammars, manuals, books and measurement outputs stay; as64, ld64, sim64 and ccom accept `-m pdp64/16|r20` only when built with `--enable-comparison` (an `enable-obsolete`-style switch); default build is /32 only; check-all.sh runs the comparison checks only when the flag is on.
  - Rationale: the architecture is one, the tools default to it, and the experiment remains re-runnable by whoever builds the flag; this is the GNU packaging convention the project already follows (the project instructions file requires `configure`).
  - Precedent: GCC's `--enable-obsolete` (verified: config.gcc:272-285); the GNU configure convention of `--enable-FEATURE` for retired options (unverified: general knowledge); GCC also has an "Unsupported targets" list for configurations refused at configure time, which includes `pdp11-*-bsd` and `vax-*-vms*` in this tree (verified: config.gcc:308 and :329, in the list opened at :296-306).
  - Cost and risk: the build gains one switch and conditional code in four programs (the `-m` parsing in as64.c:1324 and ld64, sim64, ccom, the `PDP64_ENC` executor builds); the manuals and PDFs stay in the published pages, so the "published" side is unchanged; the code paths of r20 and /16 stay compiled in the comparison build and can rot unless that build is run by check-all.sh in a separate target.
  - Fit: priority 1 good (the default cannot select the wrong encoding), priority 5 neutral; Occam middle (the code remains, hidden); this keeps the evidence reproducible, which Q12 Option 4 needs.
- Option 3 - move to an archive directory: `archive/pdp64-comparison/` takes spec/pdp64-16, the r20 field grammar, docs/manual/pdp64-r20 and pdp64-16, their PDFs and build trees, docs/encoding-work, the measurement scripts and the output; the tools keep only /32; the archive has its own README and a frozen copy of the tools needed to rebuild it.
  - Rationale: main contains one architecture; the evidence is still in the tree, browsable and published at a stable path; no history surgery.
  - Precedent: Linux keeps removed architectures only in git history, not in an archive directory (unverified: general knowledge); the BSDs keep `attic` areas in CVS repositories (unverified: general knowledge, NetBSD and OpenBSD CVS attic); V7 Unix tree preserved by the TUHS archive as a separate tree (unverified: general knowledge). In this repository the same idea is already in docs/encoding-work, "a record" folder (verified: docs/encoding-work/README.md:3).
  - Cost and risk: moves about 2,500 tracked files (links in README:5, the manual front page, errata and about 141 documents must change; the published URLs of the comparison manuals change, so any outside link breaks); the frozen tools copy duplicates code (as64, ld64, sim64) and rots; `tools/check-all.sh` must stop running r20 and /16 (the check scripts lose their loops) and a separate check of the archive is needed or its content becomes unverified claims.
  - Fit: priority 1 good for the main tree; Occam good for main, bad for the duplicate tools; compatibility, the archive stops tracking the tools.
- Option 4 - move to a tagged branch and delete from main: tag the present commit `comparison-r20-16` (or keep branch `enc-int`, which exists), then delete the two comparison manuals, their PDFs and build trees, the two comparison grammars and their tool options from main; the report (Q12) says "to reproduce, check out the tag".
  - Rationale: main shows only the architecture; the full evidence, including a working toolchain for all three encodings, is frozen in one immutable commit; the manuals' 2,462 files and the 21.5 MB of PDFs leave the tree and the published pages.
  - Precedent: Linux removes an architecture in one series and says "see git history"; the removed ia64 code is in tags such as v6.6 and earlier (unverified: general knowledge; this repository's own survey records "Itanium dropped after 6.6 LTS", docs/kernel-pain-points.md:71, verified as the document's statement and not against kernel sources). OpenBSD no longer has the VAX port (verified: docs/kernel-asm-survey.md:1020, "the `sys/arch/vax` directory does not exist in the checkout"). LLVM and GCC remove backends and rely on release tags (unverified: general knowledge). In this repository the history is already on branches (verified: git branch -a: `enc-int`, `enc-prefix` and others) and no tag exists yet (verified: `git tag` empty).
  - Cost and risk: effort is moderate (delete about 2,500 files and edit the tools and about 141 documents); the check suite shrinks by the r20 and /16 variants (the clean-checkout run was 2 min 1 s with five variants); the comparison is reproducible only by checking out the tag (a README must say so), and the published pages lose the comparison manuals; the risk is that a tag or the local branches are not pushed (there are no tags and the worktrees are local: `git push --tags` and a push of `enc-*` are needed, and the handoff must say so); the front page links (README:5) must be rewritten to point to the tag.
  - Fit: priority 1 best (nothing can select another encoding), priority 5 good (the compiler loses the frozen r20 and the 16-register build); Occam best; the evidence is as strong as the tag is durable.
- Option 5 - keep only the grammars and the measurement scripts: delete the two manuals, the PDFs and the tool options; keep spec/pdp64-16 and the r20 fields, the pcc `-m` targets (needed to rerun), and the scripts and outputs of Q12 Option 4; the report (Q12 Option 3) is the narrative.
  - Rationale: the comparison's reproducibility needs the grammars and a compiler, not the 2,462 pages of manual and the 21.5 MB of PDFs; this keeps the evidence and removes the bulk and the "family" appearance of three manuals.
  - Precedent: SPEC and Phoronix-style reproducible benchmarking keep the harness and the results and not the products being compared (unverified: general knowledge); RISC-V's ratified-spec history keeps the older versions' text and the ratification process records, not parallel implementations (unverified: general knowledge). (your referent [R365])
  - Cost and risk: the tools must still parse `-m` for the three encodings (so the code stays), which keeps the hidden-state surface of Option 1; the book build loses two variants; whether the old manuals' text is ever needed again (they are generated from docs/manual-src, so they can be regenerated: `tools/mkmanual.py`) is the safety net.
  - Fit: priority 1 weak (the tools still select); Occam middle; keeps Q12 Option 4 viable.
- Option 6 - delete everything and keep the report: remove the grammars, manuals, PDFs, tool options, tests and measurement scripts; the Q12 report (the tables, method and limits, and the git history) is the only record.
  - Rationale: "there is no family": the repository is one architecture; the report states what was tested and the git history holds the rest; the simplest tree and the fastest checks.
  - Precedent: Linux and the BSDs delete an architecture and leave the history and a commit message (unverified: general knowledge; this repository's survey confirms OpenBSD has no VAX tree, verified: kernel-asm-survey.md:1020); in this repository, errata 94's "Supersedes ... their text stays as the history" is the opposite habit (verified: errata.md:244).
  - Cost and risk: the claim "chosen for performance" can no longer be repeated, which is what the author wants documented and "check, don't guess" demands; the history stays only if nobody rewrites it and the branches and a tag are pushed; r20's frozen-output constraint on the compiler disappears (a gain for priority 5) but so does the comparison baseline.
  - Fit: priority 1 best for the tree, weakest for the evidence; Occam best; it conflicts with the author's own sentence of 2026-11-10.
  - Note: you said "it is good to document the testing against the original r20 and pdp64/16 variants": [R370]
- Recommendation: MINE (P), not a decision: Option 4 (a tag and a branch, then delete from main), preceded by Q12 Option 3 and the reproducible subset of Option 4 there, and by pushing the tag; if the author wants the evidence visible in the tree, Option 3. Option 2 only as an interim step. Reasons: errata 94 says there is no family, and a tool that accepts `-m pdp64/16` keeps a hidden second encoding alive; a tag keeps a complete working toolchain at no cost in main; the repository's own precedent (docs/kernel-asm-survey.md:1020, OpenBSD without VAX; GCC's obsolete mechanism at config.gcc:272-285 for the transitional stage) supports delete-with-record. What would change my mind: if the author wants outsiders to be able to read the two comparison manuals on the published site (README:5 links them today), Option 3; if the lost scripts cannot be reconstructed, keep Option 1 until the report is written.
- Would help you decide: what each does to the pieces: tools (Option 4 removes the `-m` alternatives in as64.c, ld64, sim64, ccom and the pcc `pdp64/r20` build; Option 2 hides them), the three manuals (Options 3 and 4 move or drop two; Option 1 keeps three), the PDFs (the two comparison PDFs are 14.1 MB), the tests (check-all.sh loops, check-sim64.sh:17, check-ld64.sh, the 963/602/963 runs of README:56 shrink to /32 only), the published pages (Option 4 removes about 13.6 MB of pages and the two links of README:5). Commands: `git ls-files docs/manual/pdp64-r20 docs/manual/pdp64-16 book | wc -l` (2,470); `git tag` (empty: nothing is yet tagged); `grep -rln 'pdp64/16\|pdp64/r20\|pdp64-16\|pdp64-r20' . | grep -v '^./docs/manual/\|^./book/build\|^./.git/' | wc -l` (141 files to edit); `time tools/check-all.sh` before and after.

## Briefing F: five REVIEW items the author has decided (D4 to D8)

- Reading note: every item is a REVIEW. The author decided these on 2026-08-29, 2026-11-09 and 2026-11-10 and asked for the alternatives "in case i should change it". The CURRENT option is marked in each item.
- Sources used throughout: docs/errata.md entries 83, 94, 95, 97, 99, 100, 101, 102 (lines 233, 244, 245, 248, 250, 251, 252, 253), docs/pdp64-fpga-plan.md, docs/encoding-work/integration.md and timing.md, docs/manual-src/02-bus.md and 05-drivers.md, docs/pdp64-isa.md section 9.3, docs/decision-log/pdp64-status.md, docs/priority-lists.md. QEMU source at qemu-src was used to verify virtio and device-model precedents.
- Priority order used for "Fit": 1 security and safety, 2 fewer instructions executed, 3 opcode encoding, 4 speed and power (gate count), 5 compiler target, 6 assembler; constraints: ready for out-of-order, soft rules, hot-loop weight, Occam.

### D4 The FPGA clock: 200 to 300 MHz (REVIEW)
- What it is: the clock frequency the design aims at when it is built in an FPGA (a chip of reconfigurable logic) is 200 to 300 MHz; the target is a design goal for the pipeline, not a measurement (no RTL, the register-transfer description of the hardware, exists yet).
- What it is: the plan's own estimates of the highest clock the single-issue core can reach (Fmax, the speed at which the slowest path still fits in one cycle) are 50 to 80 MHz on a Cyclone V, 90 to 130 MHz on an Artix-7/Zynq 7020, 180 to 250 MHz on an UltraScale+; only the UltraScale+ reaches the target, and only in the top of its range (docs/pdp64-fpga-plan.md:97-103).
- Why it matters (hardware): the target decides how many pipeline stages the design needs; the plan says reaching it means "shortening that path with pipeline stages" and leaves stage boundaries in the RTL from phase 1 (fpga-plan:103, 114, 281); a pipelined machine with memory operands and precise faults is "not a small change" to retrofit (fpga-plan:281).
- Why it matters (kernel and compiler): none directly; the architecture promises nothing about a clock. Indirectly, deeper pipelines raise load-use and branch latency, which is what the compiler's scheduling and the instruction fusion pay for (timing model: execute-wait is 25 to 39% of cycles, load-use dominant, integration.md:section 4.3).
- Why it matters (manual): the manual states no frequency; the figure lives in the FPGA plan and errata 99 only.
- Where things stand: the author, 2026-08-29: "200-300MHz is fine; still much faster than pdp-11 no?" (status log R22, pdp64-status.md:1240); rationale "modern fpga so insane high clock specs" (R20) and "300Mhz for a 1Mhz chip is insane. in a good way." (R22); again 2026-11-10: "the FPGA clock is 200-300 MHz" (errata 99, errata.md:250).
- Where things stand: errata 99 supersedes, as the target, the estimates and the plan's old advice not to chase frequency in phase 1; the estimates stay as estimates (E); "no estimate of Fmax has been measured, because no RTL exists" (errata.md:250). fpga-plan:114: "a correct machine at a lower clock still comes before a fast broken one"; phase 1 on the DE10-Nano (50 to 80 MHz estimated) is "a correctness milestone".
- Where things stand: the plan starts on the DE10-Nano (fpga-plan:24, the MiSTer ecosystem) and says to move to a Zybo Z7-20 or KV260 "when timing closure becomes the limiting factor" (fpga-plan:26). The expected critical path is register read, address adder, TLB lookup, cache tag compare, way select; the alternative is ALU, flags, branch condition, next-PC mux (fpga-plan:105-110).
- Where things stand: what 200 to 300 MHz buys, from the integration cycle counts (ideal memory, in-order toy model, so a lower bound on time not a prediction): pdp64/32, six programs, 842,065,005 cycles at issue 1, fetch 4 bytes (integration.md:4.3, A.i1.W4); at 65 MHz that is 12.9 s, at 100 MHz 8.4 s, at 200 MHz 4.2 s, at 300 MHz 2.8 s (arithmetic of this briefing).
- Referents you named or liked:
  - clock of 200-300 MHz, against the 1 MHz C64 chip (m8502) and the PDP-11: "300Mhz for a 1Mhz chip is insane. in a good way." and "200-300MHz is fine; still much faster than pdp-11 no? also faster than c64, right?" [R22]; stance: chosen
  - high FPGA clock, from modern FPGAs (no particular board or core named): "modern fpga so insane high clock specs" [R20]; stance: chosen
  - PDP-11 as the base, from the PDP-11: "use pdp-11 as the base, fold in the good parts of c64" [R20]; stance: chosen
  - m8502 mashed up with the PDP-11, from the C64's 6502-family chip: "we should mash that up instead of the c64" [R22]; stance: chosen
- Option 1 - CURRENT, a single target of 200 to 300 MHz: the design is built to this range on every board and the board is picked to fit it.
  - Rationale: the author wants a machine that is visibly fast ("300Mhz for a 1Mhz chip is insane"); a target drives the right structure early (split branch resolution from the ALU, a virtually-indexed physically-tagged L1 so the TLB leaves the serial path, fpga-plan:108-112).
  - Precedent: soft cores of the high-frequency kind are built around the clock from the start: VexRiscv is parametrised by pipeline stage count and its published figures on an Artix-7 are in the 300 MHz class for small configurations (unverified: general knowledge, figures recalled not checked).
  - Precedent: MiSTer cores of old machines run the FPGA at a much higher clock than the original and gate it with clock enables (unverified: general knowledge); the DE10-Nano and MiSTer are the plan's own first board (verified: docs/pdp64-fpga-plan.md:19, 24).
  - Cost and risk: by the plan's own numbers two of three boards cannot reach it (fpga-plan:97-103), so phase 1 runs at a quarter to two thirds of the target; deeper pipelines cost registers, forwarding paths and flush logic (gates, priority 4) and complicate precise faults (priority 1); the risk is a design shaped by the clock that pays in cycles per instruction (a deeper pipeline raises load-use and branch penalties).
  - Fit: priority 4 yes, priority 1 neutral if precise-fault rules are held; costs no opcode; out-of-order readiness is helped by early stage boundaries; a target without a measurement is itself a soft rule (the plan says so, fpga-plan:114).
- Option 2 - A lower first target such as 100 MHz, raised in later phases: phase 1 to 3 aim at 100 MHz (inside the Zynq 7020 estimate of 90 to 130 MHz, fpga-plan:100), the 200 to 300 MHz goal is kept for the UltraScale+ phase.
  - Rationale: a target you can meet on the cheap board gives a measured Fmax early and avoids designing deep pipelines before the ISA's real critical path is known; the plan itself ranks correctness before frequency (fpga-plan:114).
  - Precedent: the repository's own earlier plan advised not to chase frequency in phase 1 (verified: errata.md:250 says errata 99 superseded that advice).
  - Precedent: RISC-V cores such as Rocket and BOOM are usually run on FPGA at tens of MHz while the same RTL is targeted much higher in silicon (unverified: general knowledge, no figures given).
  - Cost and risk: a retrofit later costs the "not a small change" pipelining work (fpga-plan:281) unless stage boundaries are kept anyway, in which case this option is the same RTL as Option 1 with a looser number; the risk is that 100 MHz becomes the habit.
  - Fit: priority 1 helped (simpler, fewer stages, fewer corner cases); priority 4 neutral; the author's stated pleasure in the high number is lost.
  - Note: you said "300Mhz for a 1Mhz chip is insane. in a good way." and "200-300MHz is fine": [R22]
- Option 3 - A per-board target: the target for each board is the plan's estimate for it (50 to 80, 90 to 130, 180 to 250 MHz) and 200 to 300 MHz is the silicon goal only.
  - Rationale: honest about the technology: a Cyclone V carry chain and block RAM are slow and a target of 200 MHz there is not reachable by any effort short of redesign (fpga-plan:237).
  - Precedent: vendor soft cores publish a different Fmax for each device family (unverified: general knowledge, for example Nios II and MicroBlaze data sheets).
  - Cost and risk: three timing-closure efforts if all three boards are built; the numbers are estimates at "roughly +-40%" for area and unverified for frequency (fpga-plan:34, errata.md:250), so per-board targets could be wrong in both directions.
  - Fit: neutral on all priorities; the closest to "check, don't guess" because the number is replaced by a measurement per board once RTL exists.
- Option 4 - As fast as timing closes: no target number; the design is pipelined where it is cheap, Fmax is reported from every timing run and recorded, and the number is an output.
  - Rationale: a measured quantity beats a guessed one; this is the project's own principle (errata 94 quotes "follows our principles of check, don't guess").
  - Precedent: open soft-core projects publish the achieved Fmax per release rather than promise one (unverified: general knowledge, for example the VexRiscv README tables and the Rocket/BOOM FPGA reports).
  - Cost and risk: no early pressure to keep the critical path short, so the stage boundaries may be skipped and the late fix is the expensive one (fpga-plan:281); the author would lose the goal figure he said he liked.
  - Fit: priority 1 and 4 neutral; honest; weakest as a driver of structure.
  - Note: you said "300Mhz for a 1Mhz chip is insane. in a good way." [R22], and "modern fpga so insane high clock specs" [R20]
- Option 5 - Separate clocks for the core and the bus: the core runs at its own Fmax and the Q64 bus (PCI Express, the memory controller and the virtio devices) at the clock the bridge and the DDR need, joined by asynchronous FIFOs (queues that carry data safely between two clocks).
  - Rationale: the core's clock then does not depend on the AXI bridge, the HDMI or the DDR controller; in the plan the HPS (the hard ARM cores) and the fabric already cross clock domains through bridges (fpga-plan:195-201).
  - Precedent: the SoC FPGAs of the plan have the hard ARM subsystem on its own clock with bridges to the fabric (verified: docs/pdp64-fpga-plan.md:13, 195-201); QEMU's virt machines have no clock domain at all, so it gives no precedent (verified: hw/riscv/virt.c has none).
  - Cost and risk: every domain crossing is a place where a metastability or ordering error can hide, which is the kind of failure priority 1 wants never to arise; the memory ordering rules of the bus chapter (FENCE then doorbell, errata 95 and manual 2.2.2) must hold across the crossing; more constraints files and verification.
  - Fit: priority 4 positive, priority 1 negative unless the crossing is verified formally; the plan expects the bus to be AXI anyway.
- Option 6 - A multi-clock design inside the core: a fast clock for the core and a divided clock (half or third rate) for slow units such as the multiplier, the divider, the CLMUL and the block-move sequencer, with multicycle constraints.
  - Rationale: the slow blocks do not bound the core's Fmax; the plan already lists the divider as 32 sequential cycles and the multiplier as iterative (fpga-plan:36-45).
  - Precedent: multi-cycle paths and clock enables are the standard FPGA idiom for slow functional units (unverified: general knowledge); a divided clock with enables rather than a second clock is the usual safe form.
  - Cost and risk: real extra clocks on an FPGA are costly in routing and verification; the safe variant (one clock, multicycle paths marked in the constraints, a ready signal from the unit) is the same as Option 1 and costs nothing structural; an out-of-order core issues to such units through a scoreboard, which already tolerates variable latency.
  - Fit: priority 4 positive; it is an implementation technique rather than an alternative target and can be combined with Options 1 to 4.
- Recommendation: MINE (P): keep Option 1 as the goal and add the measurement of Option 4 and the per-board estimate of Option 3 to it in the documents: say "goal 200 to 300 MHz, expected 50 to 250 MHz by board, measured value to be recorded"; this changes no decision and removes the one contradiction in the repository (every estimate but one is below the target). Keep the stage boundaries in the RTL from phase 1 (already planned). Use Option 6 in its safe form (one clock, multicycle units). Would change my mind: a synthesis of the first RTL on the Cyclone V that lands below 40 MHz (then Option 2 or the board change of fpga-plan:26 becomes the plan), or a decision that the KV260 is the first board (then Option 1 stands as is).
- Would help you decide: which board is bought first; a synthesis run of even a 64-bit adder, register file (LUTRAM) and a 4-way TLB on the chosen device for a first Fmax; the critical-path ranking of fpga-plan:105 checked in a timing report; no repository command measures this today (no RTL). The cycle counts for any clock are `sim64 --timing` (docs/timing-model.md, integration.md:4.3).

### D5 R7 is an ordinary register, not a view of the program counter (REVIEW)
- What it is: in the PDP-11 the register R7 was the program counter (PC, the address of the next instruction), so that immediate values, PC-relative addressing and absolute addresses were just the ordinary autoincrement and index modes applied to R7; the pdp64 decided that R7 is a general register and the PC is not a register.
- What it is: the pdp64 reads the PC with `LEA 0(PC), Rn` (mode `0010`, a displacement relative to the first parcel of the instruction) and keeps the PDP-11 spelling (`MOV #5, R0`, `MOV foo(PC), R0`, `MOV @#addr, R0`) as assembler syntax (docs/pdp64-isa.md:1360, errata.md:251).
- Why it matters (hardware): a writable PC in the register file makes every register write a possible branch, forces hazard checks of every destination against R7 and a special case in every specifier decode (isa:1337-1342); this is exactly the cost an out-of-order core pays most (every instruction may redirect fetch).
- Why it matters (encoding): without R7 as PC the immediate, PC-relative and absolute forms need their own mode (mode `0010` and the immediate/absolute modes), so "encoding uniformity" is lost (isa:1360).
- Why it matters (compiler): PC-relative data addresses become one `lea`, and the linker relaxation shrinks them: in the corpus 12,787 data `lea` sites save 1,802 bytes and PC-relative loads save 1,588 bytes in /16, similar in /32 (integration.md:4.1).
- Why it matters (kernel, ABI): R7 is then an ordinary caller-saved register in the ABI (isa:93 lists R0 to R7 as caller-saved); position-independent code and calls take their return address from the call instruction, not from R7; the manual's statement 9.3.2 already says the PC is not a general register (isa:1333-1360).
- Where things stand: the author, 2026-11-10: "r7 is not a view of the pc" (errata 100, errata.md:251). Before: no earlier ruling; "the records held no earlier ruling that R7 might be the program counter" (errata.md:251); the author had asked on 2026-10-20 whether R7 was the PC on the PDP-11 and about a read-only view (status log R135, pdp64-status.md:423-430, 1091), and the ISA text had answered no as the assistant's argument.
- Where things stand: ISA section 9.3 rejects the read-only view because reading the PC forces a permanent choice of which PC (ARM32's PC+8 leaked a pipeline depth); it notes AArch64, LoongArch64 and RISC-V all keep the PC out of the general registers (isa:1346-1362, 1592, 1670, verified).
- Referents you named or liked:
  - R7 as the program counter, from the PDP-11: "wasn't R7 the PC on PDP-11?" [R135]; stance: considered
  - R7 as a read-only view of the PC, no source system named: "what if R7 was a read-only view of the PC?" [R135]; stance: considered
  - handling of the PC, from LoongArch64 and AArch64: "how does loongarch64 handle the PC? same as aarch64?" [R135]; stance: considered
  - programmer-visible PC, no source system named: "why is SP in the reg file but not PC? what is the problem with letting programmers read and modify PC directly?" [R135]; stance: considered
  - mnemonic compatibility without binary compatibility, from the PDP-11: "upgrade it to 32/64 bit keeping nice properties; mnemonics compatible, binary not" [R26]; stance: chosen
  - SP is R14 and FP is R13, from the VAX-11: "to match it" [R137]; he did not name the VAX's R15 as the PC; stance: chosen
- Option 1 - The PDP-11 way: R7 is the PC with all its modes and is writable.
  - Rationale: the most uniform design: immediates, PC-relative, absolute, jump (`MOV x, R7`), return (`MOV (SP)+, R7`) and even computed jumps are ordinary instructions; zero extra instructions or modes; the assembler is the simplest (priority 6).
  - Precedent: PDP-11, R7 is the PC and `MOV #n,Rn` is `MOV (R7)+,Rn`; VAX R15 is the PC, writable (verified: docs/pdp64-isa.md:1670-1671). (your referent [R135])
  - Precedent: ARM32 R15 is the PC, readable as PC+8 and writable, a known source of hazard logic and the PC+8 oddity (verified in the repository text: docs/pdp64-isa.md:1346-1350, 1592; AArch64 dropped it, unverified here beyond that text).
  - Cost and risk: every register write may be a branch, the write port must go to the next-PC mux, branch prediction cannot see jumps in the decode, all of it hurting an out-of-order core and the rule of priority 1 (a stray write to R7 is a jump, a failure that is hard to detect); the source size cost is none but the "more entities" cost (Occam) is in the hardware.
  - Fit: priority 6 best; priority 1 and 4 worst; the out-of-order constraint argues against.
- Option 2 - R7 as a read-only view of the PC: reading R7 returns the PC; writing is reserved or faults.
  - Rationale: cheap in hardware (a mux on the read path, the PC is already a flop); keeps `MOV R7, Rn` as a PC read and most PDP-11 immediates as modes on R7; no write hazard.
  - Precedent: ARM32's readable PC gives the PC+8 definition that every later implementation has to reproduce (verified in repository text: docs/pdp64-isa.md:1348-1350, 1592).
  - Cost and risk: commits the architecture to a definition of which PC (this instruction or the next, which depends on length; isa:1350), forever; costs one register (R7 can never hold data); the encoding needs a decision about whether an autoincrement on R7 is legal.
  - Fit: priority 1 neutral (a defined constant instead of a failure); priority 4 positive; weaker than the current on the "no implementation detail promoted to the architecture" principle.
- Option 3 - CURRENT, a separate PC; R7 an ordinary register; PC-relative as an addressing mode and `LEA 0(PC), Rn`: the PC is reached only through mode `0010` and `LEA`.
  - Rationale: a clean register file, one more general register, no number specified in perpetuity; the decision follows AArch64's `ADR`/`ADRP`, RISC-V's `AUIPC` and LoongArch's `PCADDI` (isa:1362); at `len = 10` `LEA` forms any address within +-2 GB (isa:1358).
  - Precedent: x86-64 uses RIP-relative addressing as an addressing mode and makes RIP unreadable as a register (unverified: general knowledge; the repository cites the AArch64, RISC-V and LoongArch cases, verified at docs/pdp64-isa.md:1362).
  - Precedent: RISC-V keeps the PC outside the registers and builds PC-relative with `AUIPC` (verified in repository text: docs/pdp64-isa.md:1362; the instruction details not checked against the RISC-V manual).
  - Cost and risk: the encoding is not uniform (the immediate, absolute and PC-relative forms each need a mode); the mnemonic syntax is kept but PDP-11 binaries and hand-written code that uses R7 as PC do not run (the requirement is mnemonic, not binary, compatibility, isa:1360); the measurements show the compiler's PC-relative traffic is already common (12,787 data lea sites in the /16 corpus, integration.md:4.1).
  - Fit: priority 1 best (no write-to-PC failure class, no hidden constant); priority 2 neutral (the `lea` is one instruction); priority 4 positive; priority 6 slightly worse (no uniformity); matches the out-of-order constraint.
- Option 4 - The PC readable through a dedicated instruction only (no PC-relative addressing mode): a single `GETPC Rn` (or an `AUIPC`-like add of a displacement to the PC) is the only instruction that sees the PC; loads from PC-relative constants take two instructions.
  - Rationale: removes a whole mode from every specifier decode and from the encoding; the PC reaches the datapath by one instruction.
  - Precedent: RISC-V reads the PC only through `AUIPC` and has no PC-relative load (the load is `AUIPC` then `LD`); AArch64 has `ADR`/`ADRP` plus PC-relative literal loads, a mixed case (unverified: general knowledge, both). (your referent [R135])
  - Cost and risk: against priority 2 (fewer instructions executed): every PC-relative load or jump table access costs two instructions where the mode form costs one, and the compiler's `lea`, pc-relative loads and call forms (integration.md:4.1 counts 12,787 data `lea` sites and 20,333 external calls in the /16 corpus) all become pairs; fusion would be needed to win it back.
  - Fit: priority 2 negative, priority 3 mixed (a mode disappears, the pair is longer), priority 4 neutral; contradicts the author's weighting of instruction count.
- Option 5 - The PC as a base-register only in memory modes (a register number or mode bit that means "the PC" in base position, R7 otherwise an ordinary register): `0(R7)` as a base means PC-relative, `MOV R7, Rn` as a data operand means R7.
  - Rationale: keeps the PDP-11 encoding look (`foo(R7)` is `foo(PC)`) without the writable-PC hazard; assembler syntax stays; PC-relative needs no separate mode field.
  - Precedent: x86-64's ModRM encoding reuses an otherwise-meaningless field (`mod=00, r/m=101`) to mean RIP-relative (unverified: general knowledge); AArch64 uses register 31 as SP in some positions and as the zero register in others, the pattern of one number meaning two things by position (unverified: general knowledge).
  - Cost and risk: R7 is half a register (it cannot be a base register for ordinary memory access), which is a hidden special case in the decoder and for the compiler's register allocation and breaks the orthogonality the author asked for; a visible cousin of the "mode bits should be visible, not hidden state" statement (errata 83, errata.md:233).
  - Fit: priority 6 best after Option 1; priority 5 worse (a register that cannot be a base); Occam: a special case where the current option has a mode.
- Recommendation: MINE (P): keep Option 3 (CURRENT); the cost it carries (one mode and `LEA` instead of uniformity) is paid once in the encoding and the measurements show the compiler's use is steady. What would change my mind: a count showing that mode `0010` costs encoding bits in the hottest forms (the grammar is the source of truth, spec/pdp64-32/pdp64-32.hbnf) that Option 4's pair would save in fused form, or a gate-level result that the mode `0010` path through the address adder lengthens the critical path of D4.
- Would help you decide: the fraction of executed instructions that use mode `0010` or `LEA 0(PC)` in the six programs (the simulator prints per-opcode counts with `sim64 -P`, integration.md:4.2); the length of the PC-relative encodings in /32 (`spec/pdp64-32/tables.md`); whether the timing agent's `--timing-pc` per-pc output (timing.md) shows PC-relative loads in hot loops.

### D6 The disk is virtio-blk (REVIEW)
- What it is: the standard disk (the block device the machine boots from and keeps files on) is a virtio-blk device (a standardised paravirtual block device whose requests are descriptors in a queue in memory) on the virtio PCI Express transport.
- What it is: before, the author's bus decision of 2026-11-03/04 had NVMe (the PCI Express flash-storage interface) as the storage interface: "we're going with pcie and nvme and usb for our q64 bus" (errata 75, cited in errata.md:252). An NVMe device may still be attached as any PCI Express device may; it is not the standard disk.
- Why it matters (kernel): the disk driver is a thin class driver on the one virtio transport (manual 5.2.1 to 5.2.7, 05-drivers.md:21-58); NVMe would be a separate driver with admin queue, I/O queues and its own command set.
- Why it matters (hardware): a virtio-blk device on the FPGA is a function that walks a descriptor chain (16 bytes each) and sets a used-ring entry (05-drivers.md:44-54); an NVMe controller in the fabric would be a larger design, with admin and I/O queue pairs and doorbells (05-drivers.md:60).
- Why it matters (boot ROM): the boot ROM must read block 0 through a virtqueue (errata.md:252 "still to do"); with NVMe it must also create an I/O queue pair through the admin queue first.
- Why it matters (manual): chapter 5 section 5.2.7 states virtio-blk as the disk and NVMe as an optional attached device (05-drivers.md:58); the feature subset (flush, block size, the platform-ordering feature) is not specified (05-drivers.md:54).
- Where things stand: the author, 2026-11-10: "disk is virtio-blk" (errata 101, errata.md:252), answering whether the disk is NVMe alone or also virtio-blk. Before: 2026-08-29 "modern usb keyboard, mouse, and nvme hard drive" (status log R20, pdp64-status.md:875-881), "storage on the q64 bus" NVMe (R311, pdp64-status.md:784).
- Where things stand: the Raspberry Pi SD-card storage was considered earlier (pdp64-status.md:1963).
- Referents you named or liked:
  - NVMe hard drive, no source system named: "modern usb keyboard, mouse, and nvme hard drive" [R20]; stance: chosen (before errata 101)
  - NVMe on the Q64 bus, no source system named: "we're goinge with pcie and nvme and usb for our q64 bus" [R311]; stance: chosen (before errata 101)
  - SCSI/ATA/SATA/NVMe, no source system named: "scsi/ata/sata/nvme all follow the same device pattern, and not limited to 8 reg mmio" [R282]; stance: considered
  - virtio, from the virtio standard: "virtio across the board" [R360] and "yeah, virtio is fine" [R317]; stance: chosen
  - native 8-register devices, from his own earlier design: "forget the native 8 register devices. gone." [R360]; stance: rejected
  - newest buses: "we are standardizing on the latest usb/nvme/pcie buses" [R359]; stance: chosen
  - boot from block 0, from the PDP-11: "can't we do what pdp11 used to do, load 512 byte block 0 then jmp 0?" [R256]; stance: chosen
  - SD-card storage, from the Raspberry Pi: asked how "those little SanDisk drives" interface with the rpi [R20]; stance: considered
- Option 1 - NVMe only: the standard disk is an NVMe controller and virtio is for the other devices (the state before).
  - Rationale: NVMe is the real storage interface of every modern flash drive; a real SSD in a PCI Express slot would work with its driver; one real device class, no emulation.
  - Precedent: QEMU implements an NVMe controller (hw/nvme/ctrl.c) beside virtio-blk (verified: qemu-src/hw/nvme/ctrl.c, hw/virtio/virtio-blk.c exist). (your referent [R311])
  - Precedent: public clouds present network storage to guests as NVMe on at least some platforms (unverified: general knowledge, no platform or date named).
  - Cost and risk: the real driver is larger (admin queue, identify, queue creation, namespaces, a long and optional feature list); the boot ROM grows; an FPGA NVMe controller in fabric is a big block to build while a real SSD needs real PCI Express hard blocks that only the UltraScale+ class provides (fpga-plan:295 says the KV260 has a hard PCIe root complex); a mismatch with "virtio across the board".
  - Fit: priority 1 weaker (more complex driver, more places for errors); priority 4 neutral; fewer entities (Occam) is lost.
- Option 2 - CURRENT, virtio-blk only (as the standard; NVMe attachable as any PCI Express device).
  - Rationale: one transport driver, one queue model for disk, network, display and sound (05-drivers.md:21); the same devices run in QEMU, `sim64` and the FPGA; progress lives in memory rings (manual 5.2.4).
  - Precedent: QEMU's `virt` machines for both RISC-V and ARM carry virtio devices as the default peripherals, on virtio-mmio and on a PCI Express host (verified: qemu-src/hw/riscv/virt.c:1477 `virtio-mmio`, :56 and :1036 the generic PCIe host; hw/arm/virt.c:214 `VIRT_MMIO`). (your referent [R360])
  - Precedent: Firecracker, a microVM monitor, offers virtio-blk and virtio-net as its devices (unverified: general knowledge). (your referent [R360])
  - Cost and risk: real SSDs are not usable by this driver; the virtio specification's own detail (the platform-ordering feature, the transitional/legacy interfaces) has to be chosen (05-drivers.md:54); a virtio-blk on the FPGA must be written as hardware (a descriptor walker, DMA) or served by the HPS (D7 option 6); depends on the virtio standard, which the author does not control.
  - Fit: priority 1 strong (a small standard interface, one tested path); priority 4 positive (fewer gates than an NVMe controller); Occam: one device model.
  - Note: you said "nvme hard drive" [R20] and "we're goinge with pcie and nvme and usb for our q64 bus" [R311]; the narrowing to virtio-blk is your 2026-11-10 answer (errata 101)
- Option 3 - Both with one standard: virtio-blk and NVMe are both required, the boot ROM and the kernel support both, and the manual states both as the standard.
  - Rationale: removes the "which disk" question for hardware that has one or the other and keeps the real-SSD path alive.
  - Precedent: general-purpose operating systems (Linux, OpenBSD) ship drivers for both NVMe and virtio-blk (unverified: general knowledge; OpenBSD has `nvme(4)` and `vioblk(4)`). (your referent [R230])
  - Cost and risk: two drivers and two boot paths in a boot ROM; against Occam ("do not multiply entities") and against the author's 2026-11-10 narrowing; more test surface for the same security argument.
  - Fit: priority 1 negative (two code paths); priority 5 neutral.
- Option 4 - An SD or MMC style simple block device (SDHCI, the SD host controller interface; or SPI-mode SD): a small register interface, with the card on the board.
  - Rationale: the simplest hardware of all: a few registers, no queues; the MiSTer ecosystem the plan starts from already has SD cards solved (fpga-plan:24); the Raspberry Pi boots from one.
  - Precedent: QEMU models SD and SDHCI host controllers (verified: qemu-src/hw/sd/sdhci.c, hw/sd/sd.c); the DE10-Nano/MiSTer boot from an SD card (the plan lists SD under the MiSTer ecosystem, verified: docs/pdp64-fpga-plan.md:24).
  - Cost and risk: another register model after the author dropped native register devices ("forget the native 8 register devices. gone.", errata 95); slow, and without queue-based asynchrony the driver polls or takes an interrupt per block; a second driver beside virtio.
  - Fit: priority 4 best at the gate level; priority 1 neutral; conflicts with "virtio across the board".
  - Note: you said "forget the native 8 register devices. gone." [R360]
- Option 5 - AHCI or SATA: the PCI Express attached SATA controller (a command list and a receive area in memory).
  - Rationale: widely supported by real hardware, QEMU and every older OS; simpler than NVMe in some respects.
  - Precedent: QEMU implements AHCI (verified: qemu-src/hw/ide/ahci.c, ahci-sysbus.c exist). (your referent [R282])
  - Cost and risk: a legacy interface with ATA command baggage; an old technology next to a decision "standardizing on the latest buses" (status log R359, pdp64-status.md:58-62); larger driver than virtio-blk.
  - Fit: priority 1 weaker; no advantage over Option 1 except legacy hardware.
- Option 6 - A block device of the author's own, paravirtual but not virtio: one queue, a three-field request (sector, buffer address, length) and a done flag in memory, designed for the pdp64's memory model.
  - Rationale: the smallest possible interface, with the safety properties the author wants designed in (no strange side effects, a completion that is visible in memory).
  - Precedent: Xen's block front/back rings and the DEUNA/RK11-style devices of the manual's own commentary (05-drivers.md:60, verified in the repository for the DEUNA ring; Xen unverified: general knowledge).
  - Cost and risk: gives up every existing driver and emulated device that virtio gives (the manual's own trade-off in 05-drivers.md:60); a new standard to document and test; the opposite of the author's "virtio across the board".
  - Fit: priority 1 good in principle, practically weaker; Occam: a new entity where a standard one exists.
- Recommendation: MINE (P): keep Option 2 (CURRENT). Fix the open items that go with it: the feature subset (flush, block size, the platform-ordering feature) and the boot read of block 0 through a virtqueue. Keep the statement that an NVMe device may be attached. What would change my mind: a requirement to boot from a real SSD without a virtio shim on the KV260, or a finding that the boot ROM's virtqueue code is larger than a minimal NVMe path (it should not be).
- Would help you decide: the size in instructions of a minimal virtio-blk boot read versus an NVMe boot read (QEMU can run both against the same disk image: `-device virtio-blk-pci` and `-device nvme`, both present in qemu-src); which board and whether it has a real SSD slot; the status of the platform-ordering feature for the pdp64.

### D7 Virtio across the board (REVIEW)
- What it is: every standard device (disk, network, display, sound) is a virtio device or a USB controller on one PCI Express bus (Q64) discovered by PCI Express enumeration (configuration space read by the processor); the earlier model of devices as eight memory-mapped registers plus DMA (direct memory access, the device moving data without the processor) is dropped (errata 95, errata.md:245; manual 05-drivers.md:21).
- What it is: a transfer is a chain of 16-byte descriptors in a queue (virtqueue) in host memory; the driver publishes it, runs `FENCE` and writes a notification address; the device writes the used ring (05-drivers.md:44-54).
- Why it matters (kernel): one transport driver plus a thin class driver per device (05-drivers.md:5); no per-device register layout to learn; the five driver steps are the same for every device (05-drivers.md:64-76).
- Why it matters (hardware): each device must implement the virtio queue engine (descriptor walk, used ring, interrupt message) in hardware or be served by something else; the processor owes the bus only a memory type per page, `FENCE` and atomics that reach device memory (02-bus.md:2.2.1).
- Why it matters (compiler): none directly; all device access is ordinary loads and stores to mapped windows (05-drivers.md:5.1.2).
- Why it matters (manual): chapters 2 and 5 were rewritten for virtio (02-bus.md:5, 05-drivers.md:5); `docs/pdp64-q64-bus.md` still carries parts of the old model (errata.md:245 "still to do").
- Where things stand: the author, 2026-11-09: "forget the native 8 register devices. gone. virtio across the board." and "i like all your recommendations, go ahead and update the bus chapter." (errata 95, errata.md:245; status log R360 and #4, pdp64-status.md:46-62). Before: errata 29 "devices are eight memory-mapped registers plus DMA" (errata.md:107), errata 49 (the eight-register bus controller) and errata 61; the author had also compared "12 register + dma" with virtio devices (status log R359, pdp64-status.md:62).
- Where things stand: errata 101 keeps the transport as the virtio PCI Express transport (errata.md:252); manual 2.6.2 says a function is a virtio device when its configuration space says so and one transport driver serves all (02-bus.md:67).
- Referents you named or liked:
  - virtio, from the virtio standard: "forget the native 8 register devices. gone. virtio across the board." [R360] and "yeah, virtio is fine" [R317]; stance: chosen
  - native 8-register devices, from his own earlier design (an ethernet card using "8 memory addresses as registers" [R20]): "gone" [R360]; stance: rejected
  - 12 register + dma, from his own earlier design: asked how the "12 register + dma thing" compares with virtio devices [R359]; stance: considered
  - PCI Express, from PCIe: "we're goinge with pcie and nvme and usb for our q64 bus; if there are any improvements or niceties we can make with overlays or convenience registers/functions we will" [R311]; stance: chosen
  - USB enumerated over PCIe, from USB-over-PCIe: model for the Q64 enumerating arbitrary attached buses [R292]; stance: chosen
  - HDMI, SATA and USB as "standard kit", with "our interface goes through mmio" [R278]; stance: considered
  - C64 graphics and audio, from the Commodore 64: "pdp-11 base with c64 graphics and audio" [R20]; stance: chosen
  - PDP-11 as the base, from the PDP-11 (its Q-bus register model): "use pdp-11 as the base" [R20]; stance: chosen
- Option 1 - Native registers only (the state before): every device is a handful of memory-mapped registers plus a DMA engine, as errata 29 had it.
  - Rationale: the simplest hardware per device; the programming model of the PDP-11 Q-bus, which the manual quotes (V7 `rk.c` is six registers, 05-drivers.md:17); full control of the layout, safety properties designed in (progress in architectural registers).
  - Precedent: PDP-11 RK11 (six registers and DMA) and the 4.3BSD DEUNA (four registers plus rings) (verified: docs/manual-src/05-drivers.md:17, :60). (your referent [R20])
  - Cost and risk: every device needs a new driver, a new emulator model in QEMU and in `sim64`, and every future card has to be built for the pdp64; no ecosystem; the author already dropped it.
  - Fit: priority 4 best for the smallest devices; priority 1 neutral; priority 5 neutral; Occam weak (one register layout per device).
  - Note: you said "forget the native 8 register devices. gone. virtio across the board." [R360]
- Option 2 - CURRENT, virtio across the board over the PCI Express transport.
  - Rationale: one standard for every device, drivers and emulated devices already exist (the manual's own trade-off, 05-drivers.md:60); QEMU, `sim64` and the FPGA run the same devices.
  - Precedent: QEMU virt machines use virtio as default devices (verified: qemu-src/hw/riscv/virt.c:1477, hw/arm/virt.c:214); Linux ships `linux/virtio_pci.h` and `linux/virtio_mmio.h` for both transports (verified: /usr/include/linux/virtio_pci.h, virtio_mmio.h). (your referent [R360])
  - Cost and risk: each virtio device is a queue engine in hardware (a larger design than eight registers for a UART); depends on a standard the author does not control; the feature subsets and the platform-ordering feature are open (05-drivers.md:54); virtio assumes a coherent view of memory unless the platform-ordering feature is used, which the manual handles by uncached queues (05-drivers.md:5.4.1).
  - Fit: priority 1 good (one tested path, progress in memory, restartable after reset); priority 4 neutral to worse on tiny devices; Occam strong.
- Option 3 - Virtio for slow devices and native for fast ones: the disk, network and sound are virtio; the display and anything with a framebuffer or a real-time requirement is a native register device.
  - Rationale: a framebuffer (the VIC-64X of the fpga plan, fpga-plan:79) wants direct memory and a fixed layout more than a queue; a native register device suits the c64-flavoured parts.
  - Precedent: QEMU's machines carry both kinds side by side: real device models (SDHCI, AHCI, NVMe, a UART) beside virtio devices (verified: hw/sd, hw/ide, hw/nvme exist in qemu-src, hw/virtio exists).
  - Cost and risk: two device models (the 8-register model the author removed); the second model has to be maintained in the manual, the drivers chapter and every emulator; the author's removal ("gone") argues against.
  - Fit: priority 4 better for a framebuffer; priority 1 neutral; Occam negative.
  - Note: you said "forget the native 8 register devices. gone. virtio across the board." [R360]
- Option 4 - Virtio over MMIO transports instead of PCI Express: each virtio device is a memory-mapped block of registers at a fixed or listed address (virtio-mmio), found by a table, not by PCI Express enumeration.
  - Rationale: no PCI Express enumeration to build or verify; a much smaller hardware transport; QEMU's virt machines use it for exactly this purpose.
  - Precedent: QEMU virt machines carry sixteen virtio-mmio transport slots on ARM and RISC-V, spaced 0x200 apart on ARM (verified: hw/arm/virt.c:214, :271, :1715-1746; hw/riscv/virt.c:700, :1476); Firecracker uses virtio-mmio devices (unverified: general knowledge).
  - Cost and risk: the author's bus is PCI Express ("PCI Express with convenience and security circuitry", manual 2.1.1, 02-bus.md:9) and any other PCI Express device "MAY be attached"; an MMIO transport gives up hot-plug, enumeration of bridges and USB behind a PCI function (02-bus.md:2.6.3); a second path in the kernel unless MMIO is the only one.
  - Fit: priority 4 positive (a smaller transport); priority 1 weaker (no enumeration, fixed addresses, a table that must be right); conflicts with errata 75 and 101.
  - Note: you said "we're goinge with pcie and nvme and usb for our q64 bus" [R311] and wanted USB enumerated over PCIe [R292]
- Option 5 - A mixed model with a native fast path: virtio as the standard, plus a pdp64 extension (an extended PCI Express capability announced to a card) that gives a faster doorbell or a ring in a fixed layout for the hot devices.
  - Rationale: the manual already allows convenience circuitry announced through an extended capability (02-bus.md:2.1.5), so the fast path costs the cards that don't take part nothing; a doorbell and used-ring read are the cost of every request.
  - Precedent: virtio itself has had optional fast paths (indirect descriptors, event index, packed rings) negotiated through feature bits (unverified: general knowledge; the INDIRECT flag is in the manual, verified: 05-drivers.md:44-46).
  - Cost and risk: a second entity to specify and to verify, against Occam; a feature is exercised only by the pdp64's own drivers; a measured need has not been shown (no measurement of queue overhead exists).
  - Fit: priority 4 positive if the need is measured; priority 1 neutral; priority 5 neutral.
- Option 6 - Vhost-style offload: the device side of a virtio function is served by something other than a fabric state machine: the hard ARM cores of the SoC (the plan's HPS), a host process (as in QEMU), or an accelerator, while the pdp64 sees only the virtio PCI Express function.
  - Rationale: the FPGA does not have to hold a queue engine for every device; the plan's HPS is already the bring-up harness (fpga-plan:195-201) and the DE10-Nano board has the DDR on the HPS side (fpga-plan:19).
  - Precedent: QEMU's vhost-user and vDPA variants of virtio devices (verified: qemu-src/hw/virtio/vhost-user-blk-pci.c, vdpa-dev-pci.c, vhost-kernel.c exist); the vhost idea (the data path outside the emulator) is real, details of the Linux vhost interface unverified: general knowledge.
  - Cost and risk: an extra processor in the data path and an ARM-side program to write and secure (priority 1: the HPS is a trusted component that the pdp64's security argument now includes); a performance and latency ceiling set by the bridge between HPS and fabric; no use on a board without hard cores (the ULX3S has none, fpga-plan:22).
  - Fit: priority 4 positive in gates, negative in security surface; not an alternative to virtio but a way to realise it, so it combines with Options 2 and 4.
- Recommendation: MINE (P): keep Option 2 (CURRENT). Use Option 6 as an implementation route on the DE10-Nano (the HPS serves the devices behind virtio functions), and decide Option 5 only after measuring the queue overhead of a real driver in the simulator. What would change my mind: a framebuffer or audio device whose queue model cannot meet its timing in the FPGA (then Option 3 for that one device, argued as an exception), or a result that PCI Express enumeration is the largest block of the first FPGA design (then Option 4 for the bring-up phases).
- Would help you decide: the count of LUTs for a queue engine in the plan's units (the plan has an estimate table, fpga-plan:34-45, with no entry for virtio); the instruction count of a virtio-blk driver in `sim64` against the old eight-register one; a prototype of the sound or display device as virtio against QEMU's own (`-device virtio-gpu-pci`, `-device virtio-snd-pci` in qemu-src).

### D8 pdp64/32 is the pdp64 (REVIEW)

- Resolved on 2026-11-10 (errata 122 [R374] and 123 [R375]): r20 and pdp64/16 are previous iterations, gone as CPUs with manuals and removed as code (tags pre-single-cpu and pre-code-removal keep them); the options below are history
- What it is: the architecture is the 32-register, prefix-coded one (pdp64/32, registers `r0` to `r31`, grammar `spec/pdp64-32/pdp64-32.hbnf`); the original encoding (pdp64/r20) and the 16-register prefix-coded one (pdp64/16) were built and measured against it and are not part of an architecture; there is no family (errata 94, errata.md:244).
- What it is: prefix-coded (instruction length and form chosen by a code of leading bits, so common forms are short) differs from r20 by a denser encoding; the register file of /32 is twice the size of /16's (the plan estimates a 16 x 64 file at about 250 LUTs, 2R1W, fpga-plan:38; a 32-entry file is about twice that, an estimate of this briefing).
- Why it matters (kernel and compiler): 32 registers remove most frame (stack local) traffic in compiled code: frame loads and stores executed are -62.77% against /16 (24,276,195 against 65,203,703, integration.md:4.2); the ABI's register roles (isa:93) are written for 16 registers.
- Why it matters (hardware): the register file doubles (a rename table and physical register count for an out-of-order core grow with it); the register field costs one more bit in each specifier: bytes fetched +2.92% against /16 and linked text +3.37% (integration.md:4.2).
- Why it matters (manual): one manual (`docs/manual/pdp64-32/`) instead of three; the other two are generated from the same source and stay as the comparison (errata.md:244).
- Where things stand: the author, 2026-11-09: "only the 32 register pdp64 is official, the other two are cancelled."; 2026-11-10: "pdp64/32 is the decided upon pdp64", "r20 and pdp64/16 are gone, there is no family", "it is good to document the testing against the original r20 and pdp64/16 variants, /32 chosen for performance reasons. follows our principles of check, don't guess." (errata 94, errata.md:244; status log R370, pdp64-status.md:38, 182). Before: errata 87 "the architecture is pdp64 and its two members are pdp64/16 and pdp64/32" and errata 93, three manuals, one for each CPU of the family (errata.md:244 cites both).
- Where things stand (measurements, six programs, same compiler and tools, integration.md:4.2): instructions executed 755,816,022 (r20), 609,755,229 (/16, -19.32%), 572,801,956 (/32, -24.21%); bytes fetched 2,365,226,284, 1,633,050,156 (-30.96%), 1,680,662,586 (-28.94%); frame loads and stores 68,936,548, 65,203,703, 24,276,195; linked text 226,606, 196,772, 203,404 bytes; corpus instruction bytes (841 files) 1,083,870, 934,470 (-13.78%), 964,158 (-11.04%).
- Where things stand (cycles, toy model): /32 against /16, same conditions: -6.9% to -9.5% cycles at fetch width 4 bytes/cycle and up (-7.95% at W4 issue 1; -8.43% at W16 issue 2; -9.24% and -9.51% with the wide reference); at W=2 -0.5% (issue 1) and +1.13% (issue 2), where fetched bytes decide; per program (W4, issue 1): lz4 -9.1%, zlib -13.1%, Lua -6.8%, bs_hash -0.3%, bs_sym -7.3%, bs_ec -1.8% (integration.md:4.3).
- Where things stand (caveats stated in the report): the timing model is an in-order toy, ideal memory, no BTB, no wrong path, no store forwarding, and out-of-order is not modelled; it "validates that the code implements the stated pipeline, not that the pipeline resembles hardware" (timing.md, integration.md:4.3); the six programs are lz4, zlib, Lua and three BearSSL kernels; most of the executed-instruction saving against r20 is the new compiler, not the encoding, and the Lua gain of both prefix-coded members is the switch dispatch (integration.md:4.3, 4.5); there is no "r20 with the new compiler" column (integration.md:5); the three-parcel `cbCC` and other forms were trained on the corpus only (integration.md:5); QEMU does not run /16 or /32 (integration.md:5); `lz4` is the one program where /16 is slower than r20 (+1.3% to +1.7%, cause not analysed); the register-count estimate had a band of -1.0% to +9.5% instructions and measured -6.06% (integration.md:4.4); no gate or timing cost of a 32-entry file was measured.
- Referents you named or liked:
  - 32-register pdp64 only, no source system named: "only the 32 register pdp64 is official, the other two are cancelled" [R365]; stance: chosen
  - 16 to 32 registers, no source system named: "my switch from 16 to 32 registers was the right move, instructions went down even while bytes increased 2%" [R363]; stance: chosen
  - no family, no source system named: "r20 and pdp64/16 are gone, there is no family pdp64/32 is the decided upon pdp64, but it is good to document the testing against the original r20 and pdp64/16 variants" [R370]; stance: chosen
  - RISC-V as a comparison, from RISC-V: "you didn't compare the riscv and pdp64 isa even to the extent of comparing how many opcodes or operator bit layouts there are" [R365]; stance: considered
  - 16 registers as a sweet spot, no source system named: "did we determine that 16 registers are a sweet spot for some reason?" [R196]; stance: considered
  - two grammars, no source system named: "do it as 2 grammars, the 16 reg and 32 reg ones" [R330] and "the pdp64 now has children, the pdp64/32 and pdp64/16" [R331] (both superseded by [R370]); stance: rejected
- Option 1 - CURRENT, pdp64/32 is the pdp64: one 32-register architecture; /16 and r20 stay as documented comparisons.
  - Rationale: priority 2 (fewer instructions executed): -6.06% against /16, -24.21% against r20; fewer frame accesses mean fewer memory operations, the slowest part of a modern processor (errata 83); -6.9% to -9.5% cycles in the model; one thing to build and teach (Occam).
  - Precedent: AArch64, MIPS and RISC-V have 32 integer registers; x86-64 has 16 and Intel's APX extension adds 16 more through a prefix (unverified: general knowledge; the APX motivation is fewer spills and loads); the repository's own table gives PDP-11 8, VAX 16, pdp64 16 as the prior designs (verified: docs/pdp64-isa.md:1670). (your referent [R365])
  - Cost and risk: +2.92% bytes fetched and +3.37% linked text against /16 (integration.md:4.2); a wider register file and a larger rename structure in an out-of-order core; the register-count argument rests on a toy in-order model; a wider specifier field everywhere.
  - Fit: priority 2 best; priority 3 slightly worse (more bytes); priority 4 negative at the register file, positive at the cache; priority 5 best (fewer spills); out-of-order readiness unchanged.
- Option 2 - Keep a two-member family: pdp64/16 and pdp64/32 are both official (the state of errata 87 and 93, three manuals).
  - Rationale: a small implementation can use 16 registers and a large one 32, one compiler targets both (the compiler already builds `ccom` and `ccom32`, integration.md:2); each fits a niche.
  - Precedent: the 68000 family had 16 registers (8 data, 8 address) and its successors kept them (unverified: general knowledge; the repository records the 68000 at docs/pdp64-isa.md:1535); ARM kept Thumb and ARM state as two instruction sets for years (the repository mentions the Thumb `BX` bit-0 case, verified: docs/pdp64-isa.md:1153, 1612).
  - Cost and risk: the author called it "no family" and "gone" (errata 94); two ABIs, two manuals, two tool modes, double the test surface (602, 963 and 963 harness tests, integration.md:3.1), and one binary does not run on both; against Occam; the family's whole cost buys 3% of fetched bytes.
  - Fit: priority 1 worse (two encodings, more places for errors); priority 2 and 3 split; Occam negative.
  - Note: you said "r20 and pdp64/16 are gone, there is no family" [R370] and "the other two are cancelled" [R365]
- Option 3 - Make pdp64/16 the pdp64 for density: the 16-register encoding is official; /32 and r20 are comparisons.
  - Rationale: priority 3 (dense encoding): 2.92% fewer fetched bytes than /32, 3.37% less text, 3.1% fewer corpus bytes (934,470 against 964,158); at 2 bytes per cycle of fetch /16 is as fast as or faster than /32 (+1.13% for /32 at issue 2, integration.md:4.3), so a small, cache-poor or narrow-fetch implementation prefers it; a smaller register file.
  - Precedent: RV32E halves the register file of RV32I to 16 for small cores (unverified: general knowledge); ARM Thumb has 16 registers of which the 16-bit forms reach eight (unverified: general knowledge). (your referent [R365])
  - Cost and risk: against priority 2: +6.06% instructions and +169% frame accesses (65.2M against 24.3M) and 7 to 9% more cycles at W>=4 in the model; a compiler that spills more; a decision that picks the lower of two measured performance figures; the measured byte saving is small.
  - Fit: priority 3 slightly better; priority 2 worse; priority 4 positive at the file, negative in the cycles; priority 5 worse.
  - Note: you said "only the 32 register pdp64 is official, the other two are cancelled" [R365] and "my switch from 16 to 32 registers was the right move" [R363]
- Option 4 - Keep r20, the original encoding: the original encoding and its ABI stay official.
  - Rationale: the original encoding is the simplest to decode (length-decode latency 0, the `ldecp` 1 cycle of the prefix codes does not apply, timing.md:model); its fetch-wait share is 1.6 to 1.7% against 5 to 9% for the prefix-coded ones (integration.md:4.3); a mature design with fewer unknowns.
  - Precedent: the PDP-11 and VAX byte-aligned decoders were simple in the same way (verified: docs/pdp64-isa.md:1670); no other precedent is needed. (your referent [R26])
  - Cost and risk: against priorities 2 and 3: +24.2% more instructions executed than /32 (compiler and encoding together) and the compiler's new optimisations exist only for the new targets by design (integration.md:4); 1,083,870 corpus bytes against 964,158; the new compiler's gains would be lost or re-done.
  - Fit: priority 2 and 3 worst; priority 4 positive (simplest decode); priority 5 worst.
  - Note: you said "r20 and pdp64/16 are gone, there is no family" [R370]
- Option 5 - A 32-register encoding with denser /16 forms as an option (a profile): the architecture has 32 registers, and a set of shorter forms that name only `r0` to `r15` (the RISC-V "C" or Thumb idea) is an optional extension; code can choose.
  - Rationale: gets most of /16's fetch density where registers are few and /32's register count where they matter; one register file and one ABI; the compressed forms are an implementation option (code density without a second architecture).
  - Precedent: RISC-V's C extension adds 16-bit forms over the 32-register base, limited to eight registers in many forms (unverified: general knowledge); ARM Thumb-2 mixes 16- and 32-bit forms (the decisions document lists "16/32-bit mix (RISC-V C, Thumb-2)... the compressed forms limit register choice", verified: docs/decisions-pending.md:868). (your referent [R365])
  - Cost and risk: two decoders, a compiler that has to choose forms and the measured information to do it (the grammar, `cbCC` and relaxation work was trained on the corpus only, integration.md:5); a new decision about the prefix grammar that is already prefix-coded (the prefix codes already give short forms to common cases, so the gain may be small: unmeasured).
  - Fit: priority 3 better; priority 2 neutral; priority 1 worse (more forms, more verifier surface); Occam negative (two entities for one gain).
- Option 6 - A subset profile for embedded use (register-file profile, RV32E style): the architecture and encoding are /32, a legal profile for small cores uses only `r0` to `r15` with a reduced ABI and a trap or illegal on `r16` to `r31`.
  - Rationale: a small implementation gets a half-size file without a second encoding; one toolchain, one manual with a profile section; code for the subset runs on the full machine.
  - Precedent: RISC-V RV32E and RV64E are the 16-register subsets of the base ISA, with a smaller ABI (unverified: general knowledge); the manual's own treatment of rules as soft rules (errata 42, cited errata.md:233) fits a profile that can be dropped. (your referent [R365])
  - Cost and risk: a profile is a second ABI and a second set of libraries; a binary built for the subset is not smaller than /32 code with the same instructions (the encoding still has the wider field), so it saves hardware, not code; whether any user of a subset exists is unknown.
  - Fit: priority 4 positive for small cores; priority 1 neutral if the trap on `r16` and above is precise; Occam: an option instead of an entity if kept as a documented profile only.
- Recommendation: MINE (P): keep Option 1 (CURRENT) and add one sentence in the manual that a 16-register subset is possible as a documented profile (Option 6) without being built. The re-decision after the out-of-order model exists is a good gate and should be written as a condition, not a promise: re-open if the model shows the 32-entry rename or file cost cancels the 6 to 9% gain. What would change my mind: a timing run with the model's wide out-of-order version, or an FPGA synthesis, that shows the 32-register file or its read ports on the critical path of D4; or a corpus where bytes fetched dominate (a narrow or slow code memory), when /16's 2.9% fewer fetched bytes would count.
- Would help you decide: the register-file cost on the chosen FPGA (a synthesis of a 32 x 64, 2R1W file in LUTRAM against a 16 x 64 one); the out-of-order timing model, when it exists, at the same six programs (`tools/timing.py -p scalar -p dual -s W=2,4,8,16`, timing.md); per-program frame traffic (integration.md:4.2) and lz4's cause of the /16 slowdown (timing.md says not analysed); the share of instructions that use `r16` to `r31` in the six programs (a count from `sim64 -P`).
