# The principles of the pdp64

[← the pdp64](../README.md)

Every design decision of the pdp64 is judged by these principles, in this order. When two of them disagree, the one higher on the list wins, except where a rule below says otherwise. Each principle has the reason I hold it, and an example of a decision it made.

## The goals, in order

**1. Safety and security.** An error that can never arise is better than one that is easy to detect, and that is better than one that is cheap to recover from. I go down this ladder and stop at the first rung that works:

1. *Prevent by construction, in hardware.*
2. *Prevent by idiom, in software.*
3. *Mitigate the side effects.*
4. *Minimize the cost of failure and recovery:* precise exceptions, restart without hidden state. Restart and recovery go together.

Four things are part of this principle:

* **No strange side effects.** An instruction does what its name says and nothing else.
* **Hardware, not discipline.** Where hardware can close a hole cheaply it does, so that nothing depends on a kernel or a hypervisor remembering a duty. *Example:* `RTI` takes a mask naming the registers that keep their values, and the hardware clears the rest, so a kernel that forgets a register leaks nothing.
* **Every hole and every information bleed is prevented, and each has a test** in the assembler corpus, even where the test only shows that the implementation does not have the hole.
* **It is easy and cheap to be correct.** The safe way to write something is also the shortest, cheapest and most obvious way, so that correctness needs no extra work. Hardware that encourages software flaws is changed. *Example:* a flush bit that a hypervisor could forget to set was dropped, and the hardware closes the stale-translation hole itself.

**2. Speed, measured as actual run time, and power.** Speed is what a program experiences: operations per cycle. A low gate count serves it, because fewer gates make speculation cheaper, memory faster and room for more cores. I want safety, but the machine cannot be slow as a dog: where safety costs speed, I look for the mechanism that keeps the cost small, and I measure it.

**3. Fewer instructions executed, and fewer fetches.** These are strong proxies for speed, and only proxies. Where a measured run time disagrees with a count, run time wins. I reduce instruction counts first, then byte counts, but always in service of fewer clock cycles: fewer bytes mean less fetch, and fewer instructions, if they are constructed right, mean fewer cycles. I never put extra cycles into one instruction unless it saves a lot of fetch, and the gap between a fetch and a cycle is so large that this is unlikely. The fused operations are the cases where I found it to be true: an operation that takes more cycles but saves a lot of fetch and of decode, because one fetched and decoded instruction does the work of two or more. This is not the same as fewer opcodes: an opcode that does the work of several is good.

**4. Dense encoding.** Common instructions are short and rare ones longer, because fetching is the bottleneck. A rare instruction can still earn its place in a tight hot loop.

**5. A good compiler target.**

**6. Pleasant in assembler, which is the same thing as a coherent set a programmer can keep in their head,** as the PDP-11 could be kept. Memory-mapped everything, boilerplate sugared away, readable assembly. *Example:* the mnemonic names the operation, not the length of its encoding: where the operands make it obvious, one mnemonic is written and the assembler picks the two-, four- or six-byte form. Mnemonics are cheap: if a mnemonic makes sense to a programmer (a negate for a single-precision float, say), it exists, and the assembler maps it onto an instruction that is already there. A sensible name does not need a new opcode, and the set stays pleasurable to use without growing.

## The constraints that hold whatever the order

These are not goals. They apply to every decision.

* **One binary on every implementation.** Nothing is specified that is safe only because a core is in order, narrow or small. Sizes and widths are discoverable at run time, or invisible. This acts as a veto: a faster core that is weaker must still look the same to software. *Example:* a core may speculate, but software always sees sequential consistency.
* **Measure, do not guess.** Gates and cycles, measured, decide. Where a measurement is possible, make it.
* **Hot-loop weight.** An instruction is judged by how often it executes times what it saves, not by how rarely it appears.
* **Rules are soft.** Every rule and default gives way to a named, concrete benefit with a bounded cost. A default is just a default.
* **Occam: do not multiply entities without benefit.** A sub-opcode, an alias, a prefix or a compiler job before a new instruction. *Example:* keeping sequential consistency made the whole family of barrier forms of the atomic instructions unnecessary, and they were removed.
* **Prior work and the effort of a change are never a reason.** Not what is already built, not the tests that exist, not the work to implement or to document. An option is judged on its merits.

## The method

* **Best of breed first.** I start from what other architectures do, verified in their own documents, and amend minimally so that the hole closes by construction, in the way OpenBSD does. I make a bold change only for a measured big win. I am not afraid to revive ideas and practices from the past, even from the 1960s.
* **Learn from the past's flaws and mistakes,** in hardware and software, and design to dodge them all: processor errata and vulnerabilities, kernel and hypervisor bugs and their fixes, and my own earlier mistakes. Each flaw found becomes a design rule and a test.
* **One source of truth, generated.** The grammar and the status and decisions document are authoritative. Everything else is generated from them or checked against them, so that nothing drifts.
* **Standard at the edges.** PCIe, virtio, USB, HDMI and real operating systems: the standard thing, plus the sugar and the security that cost the cards nothing. No invented peripherals, and no wrapper without a justification.
* **Verify before I state.** A claim about another machine is checked in a primary source, or left out.

## How I write about it

* The manual says what the chip is, as it will be once built: first person, no marks, no undecided matters, no history of how a decision was reached. The reasons and the patterns each decision enables or avoids are in a separate annex, and the undecided matters and the proposals are in the [design notes](design/).
* I write for a first-year computer science student of the 1970s who has learned some PDP-11 assembly and likes it. Each simple term is defined where it first appears, in a sentence or two; the more recent a topic, the fuller the explanation; short assembler examples are used liberally, showing the code with the decision and, where it makes the point, without it.
* The manual is built with [buildabook](https://github.com/moebiusV/buildabook), so that its numbers and cross-references are computed, never typed.
* I do not overwrite anything until its replacement has been verified, and I save every benchmark and every answer.
