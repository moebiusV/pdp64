# 11/64W — a 64-bit PDP-11

Three documents, consistent as of 2026-10-21. All cross-references between
them resolve; the companions are written against ISA revision 20.

| File | What it is |
|---|---|
| `11-64W-isa-r20.md` | The architecture. Revision 20, superseding 1–19. |
| `11-64W-fpga-plan.md` | Implementation plan: boards, resource budget, phase order, verification, display path. |
| `11-64W-lb64-accelerator.md` | LB64 — a Q64 accelerator for sub-1-bit (LittleBit / LittleBit-2) inference, plus training, scaling and processing-in-memory analysis. |

## Where to start

The ISA's §1.1 and §1.2 state the rules that decide everything else: when a
principle may be broken, and the order in which competing designs are judged.
§4.3 explains why the opcode space is laid out as it is. §13 compares the
result with the PDP-11 and VAX at the encoding level, and §14 inventories
which idioms were lost, restored or replaced.

For the implementation, the plan's §4 (the machine-readable spec as the single
source of truth) and §5 (phase order) are the load-bearing parts.

For the accelerator, LB64's §2 derives the kernel and §12 profiles where
inference time actually goes — which is not where the earlier sections
assumed.

## Status

Paper design. Nothing here has been synthesized, measured or taped out. The
transistor and LUT estimates are estimates, labelled as such. Each document
ends with open items; the ones that would change a decision rather than
refine it are the ISA's items 4, 5 and 11, and the plan's risks 1 and 2.
