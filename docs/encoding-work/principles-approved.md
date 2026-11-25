# The design principles of the pdp64, as approved by the owner on 2026-11-25

These are the principles every design decision is judged by. The first list is the owner's earlier list, the second is the ten added on 2026-11-25 (each with the evidence the owner's own words give). The order is the owner's: "you got the order correct". Prior work already done, and extra work to implement or document a change, are never a reason for or against an option.

## The order (strongest first)

1. **Safety first**, by the ladder below (principles 2 and 3 are its means).
2. **All holes and information bleeds prevented, and each tested** in the assembler corpus.
3. **One binary on every implementation** (a veto, not a rank): nothing is safe only because a core is in order, narrow or small; sizes and widths are discoverable at run time or invisible.
4. **Measure, do not guess:** gates and cycles decide; method for every decision.
5. **Speed, as measured by actual run time.** Fewer instructions executed and fewer bytes fetched are strong proxies for speed, but only proxies: where the measured run time and a proxy disagree, run time wins.
6. **Fewer instructions executed** (not a smaller opcode set), and **fewer fetches** (the proxies).
7. **Frequency-weighted encoding:** common instructions short, judged by executions times savings; hot-loop weight.
8. **Rules are directional, not iron-clad:** any rule gives way to a named, bounded benefit.
9. **One source of truth, generated:** the grammar and the status and decisions document are authoritative; everything else is generated from or checked against them.
10. **Standard at the edges:** PCIe, virtio, USB, HDMI and real operating systems, plus sugar and security that cost the cards nothing.
11. **Occam:** do not multiply entities; an alias, sub-opcode, prefix or compiler job before a new instruction (applies whatever the order).
12. **A coherent set a programmer can keep in their head** like the PDP-11's.
13. **Peek-and-poke simplicity and pleasure** (the C64 and PDP-11 heritage).

**Best of breed is the method, not a rank:** start from what other architectures do (verified in primary sources) and amend minimally so holes close by construction; a bold change only for a measured big win. No wrappers without justification.

## The ladder of safety (the owner's wording, 2026-11-25)

1. **Prevent by construction (hardware).**
2. **Prevent by idiom (software).**
3. **Mitigate side effects.**
4. **Minimize the cost of failure and recovery** (precise exceptions, restart without hidden state, recovery and restart go together).

An option is better the higher on the ladder it closes a failure. "Hardware, not discipline": where hardware can close a hole cheaply, it does, so correctness never depends on a kernel or hypervisor remembering a duty.

## The ten added (with the owner's words)

1. **Prevent, then detect, then recover.** "fewer possible errors means less recovery code. easier recovery path means less recovery code." (2026-10-22)
2. **Hardware, not discipline.** "i love protecting us from careless kernels." (2026-11-20)
3. **One binary on every implementation.** "although the first implementations will be in-order, we have to make the decision safe for out of order implementations" (2026-10-23)
4. **Measure, do not guess.** "follows our principles of check, don't guess." (2026-11-10)
5. **Frequency-weighted encoding and hot-loop weight.** "longer encodings for instructions that are used more rarely is a way of reducing memory fetches, memory fetch being the bottleneck we are optimizing for." (2026-11-03)
6. **Rules are directional, not iron-clad.** "all the rules are soft rules." (2026-10-22)
7. **One source of truth, generated.** "the whole point of using an hbnf grammar is single source of truth, so things don't drift." (2026-10-21)
8. **Occam.** "don't multiply entities without benefit."
9. **Standard at the edges.** "virtio across the board" (2026-11-09)
10. **Peek-and-poke simplicity and pleasure.** "anything that made graphics programming annoying or cumbersome or boiler platey, we want to sugar away to almost nothing." (2026-11-10)

## Conflicts (how the owner trades them)

* Safety against speed: safety wins on the goal; speed picks the cheaper mechanism.
* Coherence against fewer instructions: fewer instructions win while the set stays orthogonal.
* Best of breed against a bold change: the bold change only for a measured big win.
* Reference completeness against clarity at the point of use: complete in the reference, plain where it is used.
* Hardware protection against silicon cost: protection wins when cheap.
