#!/usr/bin/env python3
"""oqappendix.py: assemble the decision-briefing appendix of each project from docs/decision-log/data/shared/oq/*.md
into docs/decision-log/data/<project>/oq-appendix.md, which status.py appends to the status document."""
import os, re
D = 'docs/decision-log/data'
def brief(letter):
    t = open('%s/shared/oq/%s.md' % (D, letter)).read().rstrip('\n').split('\n')
    first = t[0]
    title = re.sub(r'^#+\s*', '', first)
    title = re.sub(r'^(Decision briefing|Briefing)\s+', 'Briefing ', title)
    return ['## ' + title] + t[1:] + ['']
INTRO = {
 'pdp64': ["# Decision briefing: open questions and decisions under review", "",
  "- Each item gives where things stand, the referents you named or liked (feature, source system, your words), 5 or 6 options with rationale, costs and precedents, and a recommendation that is the briefing agent's, not a decision",
  "- Items marked QUESTION are open; items marked REVIEW are decisions you already made (the CURRENT option is flagged), listed so you can change them",
  "- Precedents are marked verified (a path on this machine) or unverified (general knowledge, not checked); `(your referent [id])` marks a precedent that you named or accepted yourself",
  "- Byte and instruction counts in the instruction-set items are estimates unless the text says measured", ""],
 'hbnf': ["# Decision briefing: open notation questions", "",
  "- Each item gives where things stand, the referents you named or liked, options with rationale and precedents, and a recommendation that is the briefing agent's, not a decision",
  "- Precedents are marked verified (checked in the clone or on disk) or unverified (general knowledge); `(your referent [id])` marks one you named yourself", ""],
}
POST = ["## Decisions recorded after this ledger was built (2026-11-09 and 2026-11-10)", "",
 "- These supersede the rows above where they differ; each is in docs/errata.md",
 "- Errata 94: pdp64/32 is the pdp64; r20 and pdp64/16 stay as the documented comparison, nothing removed",
 "- Errata 95: virtio across the board (supersedes errata 29, the eight-register part of 49, and 61)",
 "- Errata 96: page tables of 3, 4 or 5 levels (39, 48, 57 bits), level count discoverable at runtime",
 "- Errata 97: no physical-address bit selects device space",
 "- Errata 98: abs, min, minu, max, maxu are assembler aliases; expansion and the select are open; the build still encodes them natively",
 "- Errata 99: the FPGA clock target is 200 to 300 MHz; the per-board estimates stay estimates",
 "- Errata 100: R7 is not a view of the program counter",
 "- Errata 101: the disk is virtio-blk",
 "- Errata 102: physical address of at least 40 and up to 64 bits, devices anywhere except the first few pages; open: how many pages, width discovery, the page-table entry",
 ""]
out = {'pdp64': INTRO['pdp64'] + POST, 'hbnf': list(INTRO['hbnf'])}
for l in 'ABCDF': out['pdp64'] += brief(l)
out['hbnf'] += brief('E')
for p, L in out.items():
    os.makedirs('%s/%s' % (D, p), exist_ok=True)
    open('%s/%s/oq-appendix.md' % (D, p), 'w').write('\n'.join(L) + '\n')
    print(p, len(L), 'lines')
