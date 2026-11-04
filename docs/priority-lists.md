# The priority lists, with commentary

For the author's annotations. Each list gives its source, whose words it is, and a short commentary. The last section is empty, for the definitive list.

The lists are collected from `README.md`, `docs/decisions-pending.md` (Part 0), `docs/manual/01-introduction.md` (1.4), `docs/pdp64-isa.md` (section 1), `docs/errata.md` (42 and 68) and the device-chat export `c64stuff.txt`.

---

## List 1. The principles (2026-10-22)

*Source:* README "Design principles", `decisions-pending.md` Part 0, manual 1.4.1. *Whose:* the author's. The repository records the list but not the author's own words.

1. **Code size.** Bytes of kernel and user code, including hot-path length and the code spent on error handling.
2. **Easy recoverability, meaning less recovery code.** Fewer possible errors, and an easier recovery path.
3. **Speed and efficiency through fewer gates and tighter hot loops,** by careful choice of instructions.

*Commentary.* This is the list the documents currently treat as the ranking, and it is the list the option-by-option decisions in Part 0 are scored against. Gate count has no place of its own: it is folded into item 3 with speed. "Pleasant in assembler" and "good compiler target" do not appear at all (they were items 3 and 4 of list 5), so the question is whether you still want them as goals or whether they are served by code size and recoverability.

*Your annotations:*

what I mean is, less code means less memory access, and that is the slowest part of modern day cpu, is memory fetch, so fewer instructions in the code, doesn't mean fewer opcodes.  an opcode that coallesces several calls is great. however, error recovery takes up a lot of cycles and instructions, so any design decisions that reduce the need for, and cost of, error recovery are top priority, but it is a special case of the "less code" not "less opcodes".  but there is a sweet spot too, so fewer opcodes means less silicon; fewer addressing modes, flags, potential error conditions, all means less logic gates, which means less heat, which means higher clock speeds are possible, etc.

&nbsp;

---

## List 2. The tie-break order between two designs that both work

*Source:* `pdp64-isa.md` section 1.2, manual 1.4.3. *Whose:* the author's, from the first ISA chat. The chat message (c64stuff.txt, line 6999) reads: "just make it efficient in this order: no wierd side effects, no bumping other opcodes in a way that makes code size increase.... and don't increase transistor count too much ockam. don't multiply entities without benefit."

1. **No strange side effects.** An instruction does what its name says and nothing else.
2. **Do not displace an instruction into a longer encoding** (weighted by frequency: moving something common from two bytes to four is a regression; moving something rare is noise).
3. **Occam: do not multiply entities without benefit.** One instruction covering three cases beats three; a sub-opcode in an existing group beats a new top-level opcode; an assembler alias beats an instruction. Count gates and verification surface.

*Commentary.* This reads as list 1 at a finer scale: rule 2 is code size, rule 1 is recoverability (an instruction with a side effect is a source of surprises), rule 3 is the gate count. The one real difference is the **order**: here "no strange side effects" comes before code size, whereas list 1 puts code size first. The two are consistent only if you read list 2 as applying after a design has already been shown to satisfy list 1 (a tie-break between acceptable options, not a ranking of goals). If you intend side effects to outrank code size in general, list 1 has to change.

*Your annotations:*

this is the same as before; no wierd side effects is another way of saying reduce the need for, and cost of, error recovery.
longer encodings for instructions that are used more rarely is a way of reducing memory fetches, memory fetch being the bottleneck we are optimizing for.  occam isn't a priority, it is a principle that applies no matter what it is orthoganal to the hierarchy and priority levels.  principle of least surprise is about human cognitive load, makes it easier for humans to reason about code (and thus, llm too) predictability makes coding easier, means less defensive coding is needed, which means fewer instructions are needed.  but also security/safety is also a fundamental principle, so the "no wierd surprises" "easy error DETECTION and recovery" are top of the pile for priority, then opcode choice, then opcode encoding, then everything else.  an error that can never arise is the ideal state for error recovery.
&nbsp;

---

## List 3. Two further principles (2026-10-23)

*Source:* errata 68, manual 1.4.4 and 1.4.5. *Whose:* the author's, quoted: "although the first implementations will be in-order, we have to make the decision safe for out of order implementations"; "a rarely used instruction can still pull its weight if its used inside a critical tight hot loop".

- **Safe for in-order and out-of-order.** Nothing is specified that is safe only because the core does not speculate or reorder.
- **Hot-loop weight.** An instruction is judged by executions multiplied by what it saves, not by how rarely it appears.

*Commentary.* These are constraints and a measure, not ranked goals. The first one is currently contradicted by text in `pdp64-isa.md` (section 17, "pdp64 is in-order and non-speculative"), which I annotated but did not rewrite. The second changes how list 1's item 1 and item 3 are measured.

*Your annotations:*
so, the value of an instruction is not only about it reducing code size, but it making code execution faster. and yes, these are constraints and a measure, not priority levels.  again, orthoganal to the priority levels in the isa design.  this principle that we must be "out of order" ready is a change from the original design, but it is authoritatie and supersedes the old design.  initial implementations may be in order, but the design must have out of order planned for prepared for from the beginning; anything that can fit our error prevention, detection, and recovery priorities in out of order execution is something to look at extremely seriously, let's put in the features and design principles no other cpu has up to now.

&nbsp;

---

## List 4. How rules may be broken (2026-10-22)

*Source:* errata 42, `pdp64-isa.md` section 1.1, manual 1.4.2. *Whose:* the author's, quoted: "all the rules are soft rules."

A rule gives way when (a) the benefit is named and concrete, (b) the cost is bounded and written down, and (c) the mechanism that made the rule necessary is absent from the exception.

*Commentary.* Not a priority list, but it decides how strictly any list above binds. Clause (c) is the working part: it is what admitted `MBLK` without reopening the one-memory-operand rule. The two strongest defaults are no mode bits and natural alignment (the latter confirmed in errata 82).

*Your annotations:*
this is correct. all rules are soft rules in service of our priorities and design principles. also the no mode bits flag i don't even know where that came from, where is the benefit of that, and what alternatives are there to it? a default is just a default.  as we discussed with instructions, our instructions fall on 16 bit boundaries, and this doesn't conflict with natural alignment; natural alignment can even be done in the underlying implemention with shifts and masks if we are loading at byte or short or word addresses.

&nbsp;

---

## List 5. The ranking in `pdp64-isa.md` section 1

*Source:* `pdp64-isa.md` section 1 (and the original r20 document). *Whose:* **not the author's.** It is the first ISA chat's own text, which the repository kept unedited.

1. Low transistor count.
2. Bounded fault surface: every instruction restartable with O(1) recorded state.
3. Pleasant in assembler.
4. Good compiler target.
5. Code density.

"Where they disagree, 1 wins."

*Commentary.* This contradicts lists 1 and 2: it puts transistor count first and code density last, the reverse of the author's list 1 on the two ends. It is the ranking `decisions-pending.md` E9 flags. Items 2 and 3 survive in list 1 (recoverability) and as an open question (pleasant in assembler). I recommend replacing it with whatever you decide is definitive.

*Your annotations:*
This is stale; low transistor count is desirable but lower priority than error prevention, detection and recovery, and efficiency of the instruction set.  low transistor count is about the sweet spot for code speed and power usage by having fewer gates, which makes out of order and speculation less costly to implement, which lets memory access come faster, which allows more cores on one chip, etc.  the pleasant in assembler means fewer opcodes, fewer addressing modes, and be as consistent as we reasonably can about behavior, let related instructions behave in related, similar ways.  things that allow efficient compiler output and tight kernel code are valued.  code density means how many instructions pack into a given bit of memory; this is about reducing memory fetch bottleneck, and fewer instructions doing more work has that same effect of saving memory fetches.  the bounded fault surface again, is 1) security, our top priority, as if we were the NSA, and 2) efficiency by eliminating or reducing possible errors and making detection and recovery as easy and cost efficient as possible.  so.... putting low transistor count as the number 1 priority is wrong.  it is a priority, but 2 or 3 steps down.  pleasant in assembler may even be lower priority than it.  good compiler target just means fairly easy to put out optimized code because of consistency, if you have too many wierd edge cases optimization gets very tricky and lots of meat gets left on the table.  so, our choice to have fewer addressing modes than the pdp11 serves that "pleasant in assembler" but if a choice suddenly means we need a lot more instructions to do the same job, then that wouldn't be such a good choice without extreme benefits in all the other areas.


&nbsp;

---

## Where the lists stand against each other

| Goal | List 1 | List 2 | List 5 |
|---|---|---|---|
| Code size | 1 | 2 | 5 |
| Recoverability (restartable, fewer errors) | 2 | 1 (as "no side effects") | 2 |
| Gate count | 3 (with speed) | 3 | 1 |
| Hot-loop speed | 3 | | |
| Pleasant in assembler | | | 3 |
| Good compiler target | | | 4 |

The open choices for the definitive list:

1. Does "no strange side effects" sit above code size, or under it?
2. Where does gate count go: alone, with speed (as now), or low?
3. Do "pleasant in assembler" and "good compiler target" come back as goals?
4. Are out-of-order safety (list 3) and the soft-rule test (list 4) part of the list, or standing constraints beside it?

---

## The definitive list

*(For you to write. When it is final I will replace the ranking in `pdp64-isa.md` section 1 with it and make the README, the manual's 1.4 and Part 0 of `decisions-pending.md` say the same.)*

out of order safety and soft rule test are stanading constraints beside, no priorities.
no strange side effects is above code size.
gate count is lower than speed
pleasant in assembler and good compiler target never went away. htey are lower priorities.
&nbsp;
