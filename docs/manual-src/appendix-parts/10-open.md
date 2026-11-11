<a id="j101"></a>
### J.10.1 Which rules keep a faster core from the speculative and timing flaws

**Issue.** The author decided (errata 85; 2026-10-22: "no hammer-row, no spectre, no timing channel attacks") that the architecture does not repeat the flaws of the last decade, and that a secure core has every timing channel removed (10.4.1, 10.4.3). What is not yet chosen is the exact rule set for a future out-of-order core, and the mechanism that makes execution time independent of data.

**Why it matters.** A rule fixed while the specification is being written costs little; one retrofitted after silicon costs a respin.

**Options.**

1. *Rules in the report only.* The rules (for example: no speculation across protection domains; no predictor state shared across a privilege boundary without a flush) stay advice in the hardware-vulnerabilities report. For: nothing to implement now. Against: nothing makes an implementer follow them.
2. *Rules in the architecture text.* They are stated as requirements of the specification, with a declared set of instructions whose timing is independent of operand values. For: testable. Against: the declared set and a data-independent-timing control (a mode bit or a core class) are not chosen (proposal P17).

**Where the body refers to it.** Section 10.4.1.
