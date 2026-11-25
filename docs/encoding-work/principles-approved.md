# The complete set of design principles of the pdp64, in order of priority (approved by the owner on 2026-11-25)

This is every principle the owner has given, from three sources: the definitive list of 2026-11-03, the restatement of 2026-11-19, and the ten added on 2026-11-25 with the owner's corrections. The owner approved the whole set, with his edits, on 2026-11-25. Every design decision is judged by it.

Each item says where it comes from: **[you]** is your own list or words, **[ten]** is one of the ten approved on 2026-11-25, **[mine]** is my placement, which you should correct.

## Part 1. The goals, in priority order

**1. Safety and security, by the ladder.** [you: 2026-11-03 item 1; ladder 2026-11-25] Go down this ladder and stop at the first rung that works:
 (a) prevent by construction, in hardware; (b) prevent by idiom, in software; (c) mitigate the side effects; (d) minimize the cost of failure and recovery (precise exceptions, restart without hidden state; recovery and restart go together).
 Included in item 1: no strange side effects (an instruction does what its name says and nothing else; "as if we were the NSA"); hardware, not discipline: where hardware can close a hole cheaply, it does, so that nothing depends on a kernel remembering a duty [ten]; every hole and every information bleed is prevented, and each has a test in the assembler corpus [you: 2026-11-19].
 Also included in item 1: **make it easy and low cost to be correct, that is, to write correct code** [you: 2026-11-25; "maybe stated in different ways, but good to state clearly"]: the safe way is also the shortest, cheapest and most obvious way to write it, in instructions, in bytes and in effort for the programmer, so that correctness needs no extra work.
 Also included in item 1: **hardware that encourages software flaws is changed** [you: 2026-11-25]. The easy, obvious way to use an instruction, a register or a default must be the safe way; a duty that software can forget is a defect of the hardware. Cases already decided by this rule: the stale-translation flush bit the hypervisor could forget (dropped), the registers a kernel leaves behind on return (`RTI #mask`), an IOMMU that lets a device write system registers (refused by default), an unprivileged `MFCPUID` (now privileged), and `MTPS` and `SPL` silently ignored in user mode (the PDP-11 habit that made a guest kernel hard to catch).

**2. Speed, measured by actual run time, and power.** [you: 2026-11-19, corrected 2026-11-25] Low gate count serves speed and power ("4 and 5 are essentially the same thing", 2026-11-03): fewer gates make out-of-order and speculation cheaper, memory faster, and room for more cores. Transistor count is desirable but below error prevention, detection and recovery, and below the efficiency of the instruction set.

**3. Fewer instructions executed, and fewer fetches.** [you: 2026-11-03 item 2; 2026-11-25] These are strong proxies for speed and only proxies: where the measured run time and a proxy disagree, run time wins. Not fewer opcodes: an opcode that coalesces several operations is good.

**4. Dense encoding: common instructions short, rare ones longer.** [you: 2026-11-03 item 3] A rare instruction can still earn its place in a tight hot loop (hot-loop weight, below).

**5. A good compiler target.** [you: 2026-11-03 item 5] [mine: placement above coherence and pleasure, from your order of 2026-11-03.]

**6. Pleasant in assembler, which is the same thing as a coherent set a programmer can keep in their head, like the PDP-11.** [you: 2026-11-03 item 6; 2026-11-19 "as the final principle after the others are met"; 2026-11-25: "pleasant in assembler and coherent set are the same thing"] Memory-mapped everything, boilerplate sugared away, readable assembler, peek-and-poke simplicity and pleasure (the C64 and PDP-11 heritage); an instruction set small enough in its ideas to hold in the head. It is the last principle, met after the others.

## Part 2. The standing constraints and measures (they apply whatever the order; not goals)

**A. One binary on every implementation.** [you: 2026-10-23; "out of order readiness is authoritative"] Nothing is specified that is safe only because a core is in order, narrow, or small; sizes and widths are discoverable at run time or invisible. It acts as a veto.
**B. Measure, do not guess.** [ten: "check, don't guess"; "no stone unturned"] Gates and cycles, measured, decide; where a measurement is possible, make it. This is the method of every decision.
**C. Hot-loop weight.** [you: 2026-10-23] An instruction is judged by how often it executes times what it saves, not by how rarely it appears.
**D. Rules are soft.** [you: 2026-10-22] Every rule and default gives way to a named, concrete benefit with a bounded cost (and the mechanism that made the rule necessary absent from the exception). "A default is just a default."
**E. Occam: do not multiply entities without benefit.** [you: 2026-11-03; "orthogonal to the hierarchy"] A sub-opcode, an alias, a prefix, or a compiler job before a new instruction; count gates and verification surface. Mnemonics and generator runs are cheap, so Occam never stops a separate mnemonic that is correct and safe.
**F. Prior work and the effort of a change are never a reason.** [you: 2026-11-25] Not for or against an option: not what is already built, not the tests that exist, not the work to implement or to document.

## Part 3. The method

**G. Best of breed first.** [you: 2026-11-19] Start from what other architectures do, verified in their own documents; amend minimally so that the hole closes by construction (the OpenBSD way); make a bold change only for a measured big win. A departure from the standard is welcome when it serves the principles above. **Do not be afraid to revive ideas and practices from the past, even from the 1960s** [you: 2026-11-25]: the best design to start from is often an old one that the industry dropped for reasons that no longer hold.
**H. Learn from the past's flaws and mistakes, in hardware and software, and design to dodge them all.** [you: 2026-11-25] Every known flaw is studied before we design the same thing: processor errata and vulnerabilities (speculation and side channels, translation-buffer and cache coherence bugs, privilege-escalation bugs, interrupt and DMA holes), operating-system and hypervisor bugs and their fixes (the OpenBSD mitigations, the kernel pain points, the Linux hypervisor bugs), and our own earlier mistakes. Each flaw found becomes a design rule and a test in the corpus. This is the other half of best of breed: the best designs to start from, and the worst failures to avoid. Where we have already collected them: `docs/hardware-vulnerabilities.md`, `docs/openbsd-mitigations.md`, `docs/kernel-pain-points.md`, `docs/security-corpus.md`.
**I. One source of truth, generated.** [ten] The grammar and the status and decisions document are authoritative; everything else is generated from or checked against them, so nothing drifts.
**J. Standard at the edges.** [ten] PCIe, virtio, USB, HDMI and real operating systems; be the standard thing plus the sugar and security that cost the cards nothing; no invented peripherals. No wrapper without a justification.
**K. Verify before you state.** [you: 2026-11-10 onward] A claim about another machine is checked in a primary source or left out.

## Part 4. How we work together (not design principles; kept so they are not lost)

* Write for a first-year computer science student of the 1970s, perhaps taking an introductory course at MIT (Scheme-style programming), playing with ITS and TOPS-10, who has learned some PDP-11 assembly and likes it. He has not met anything newer than that. Define each simple term the first time it appears, in one or two sentences (a trap is the processor's forced jump to the operating system when a program does something it may not); do not assume more than that; do not write a textbook. The more recent a topic is, the better it must be explained: what the student could have met in the 1970s gets a sentence or two, and what came after (virtual machines in hardware, two-stage translation, translation-buffer tags, speculation and side channels, the IOMMU, virtio, message-signalled interrupts, atomics and memory models) gets a full explanation with an example. Short snippets of assembler code are excellent teaching aids and are used liberally: a few lines of PDP-11 or pdp64 assembly beside the prose, each one correct (assembled with as64 and, where it can run, run on sim64) and each explained line by line only where a line is new. Explain in plain words; the story first, then the mechanism, then the detail; one question at a time; each question says what it closes and what we lose.
* The manual describes the chip as it will be once implemented: it never says "not yet implemented", "not yet runnable", "planned" or "today the simulator does"; implementation status lives outside the manual.
* The manual is first person, states what is, has no marks, no errata references, no leanings and no undecided matters in the chapters (open items are in the design notes); a few benchmark tables are rationale; detailed gate counts wait for real Verilog.
* Do not overwrite before the replacement is verified; save every benchmark and every answer; push only when told.
* The manual is built with buildabook, so that cross references stay proper: every change to it is followed by the three checks, and a check that is skipped counts as a failure.

## Checked by the owner on 2026-11-25

* The placement of the compiler target and of pleasant-and-coherent last: yes.
* Low transistor count folded into speed and power: yes.
* Missing: make it easy and low cost to be correct, that is, to write correct code (added to item 1).
