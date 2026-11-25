# {{#annex-template}} The template of an entry

This file is the template. Copy it, give the entry a name that starts with `annex-`, and fill each part. Aim at up to about 1,000 words of prose and code together (the owner: 1,000 words is fine); aim at 300 to 600 words of prose and one to three snippets. Delete these instructions in the copy.

---

## {{#annex-NAME}} Title: the pattern, in a few plain words

**The decision.** One sentence, in the first person plural or singular: "I keep ...", "the hardware does ...".

**The problem.** The story first. Where the problem showed itself (a PDP-11 kernel, a VAX, an Alpha, an x86, an Arm), what a programmer saw, what it cost. Define each simple term at its first use in a sentence or two, as for a first-year student of the 1970s who knows a little PDP-11 assembly. The more recent the topic, the fuller the explanation.

### Before and after

**Before** (the sequence without the decision; name the machine and the source):

```
        the original code, real: quoted from a named source or assembled here
```

*(N instructions, B bytes; how it was obtained.)*

**After** (the pdp64, assembled with `build/as64`; the file is in `snippets/`):

```
        the pdp64 code
```

*(N instructions, B bytes.)*

If the decision removes the thing altogether, show only the before and say: "On the pdp64 this is no longer needed."

### What it enables

The patterns that a programmer can now write. One short paragraph and, where one makes the point, one short snippet in pdp64 assembly for each pattern.

### What it saves us from

The real past flaws, one short paragraph each: processor errata, kernel and hypervisor bugs, exploits, standard workarounds. **Only those verified in a source the repository holds, or in a primary source fetched and quoted briefly with its address and date.** Name the source after each. Mark nothing as fact that I cannot verify; leave it out.

### What it costs

Honest and brief: gates, bytes, cycles where they were measured; where they were not measured, say so in a few words.

### What it puts off limits

What a programmer can no longer do, and what to do instead.

### Where the manual states it

`{{r:name-of-the-statement}}` (and the other statements that carry it).

---

## The rules of an entry, in one list

* First person; plain words; story first.
* No reference to an erratum or to a decision-register row.
* No status mark; nothing undecided.
* Every foreign snippet is real and checked (a source named, or assembled here); where it cannot be checked, use a pdp64 or PDP-11 "before". Good sources of old code: the TOPS-10 and TOPS-20 sources, the ITS sources, and the ancient Unix archive (the Unix Heritage Society's archive of the Research Unix editions, V1 to V7 and the BSDs); name the file, the edition and the address, and quote only what you read; assemble or check it where a tool exists (SIMH may be available), and say in the pilot notes how each was obtained.
* Every pdp64 snippet is assembled with `build/as64` where the instructions exist; one that cannot be assembled yet is listed in `PILOT-NOTES.md`, not marked in the text.
* A number that appears in the text (instructions, bytes, gates, cycles) is counted, measured or quoted; say which in a few words.
