# State of the kernel pain-points research

Seven rounds are done (round 1 local sources and lists; rounds 2 to 7 sources, papers, verification). This note says what exists and what is left; it is not a design document.

## What exists

* `docs/kernel-pain-points.md`: chapter 0 (the overview of the major pain points by area), chapters 1 to 16, sections 14A to 14M (statement tables by round and area; 14F bus, GPU and display; 14G the UNIX-HATERS Handbook; 14I the Blit and Plan 9; 14J, 14L corrections and clarifications), Appendices A to A.7 (catalogue rows 1 to 242), B and C.
* `docs/hardware-vulnerabilities.md`: the catalogue, the constant-time analysis, rules C1 to C16 and N1 to N11, round 7 papers (section 12).
* `docs/openbsd-mitigations.md`: the mitigations, what OpenBSD asks of vendors, round 7 slides (section 13).
* `docs/architecture-recommendations.md`: proposals for the instruction set, modes and devices drawn from the evidence; section 6 is the round 7 update.
* Data in this directory: `counts.csv`, `totals.csv`, `structural.csv`, `trees.csv` (greps of the current source trees), `msgs-*` (commit-message mining), `reading-list.tsv` (round 1), `round2-index.tsv` to `round7-index.tsv` (every source read in each round, with area, URL, author, date and whether it is cited), `coverage-matrix.tsv` (99 topics; 79 covered well, 20 thin and marked "not pursued: not essential", none missing) and `verification-ledger.tsv` (240 rows; 170 verified, 41 corrected, 13 clarified, 16 still unverified, each with a reason).

## Evidence labels

**[D]** developer statement, **[D-local]** text of a file in a local source tree, **[S]** secondary report, **[P]** primary paper or project page. Quotations are exact text of a source that was read; paraphrase, skimmed and inferred statements are marked as such.

## Limits to remember

* lwn.net coverage was limited; the LWN citations come from archived copies and a few direct pages.
* The local Linux tree has no `drivers/` except `iommu` and `irqchip`, and the BSD trees only the `sys` core; graphics, PCI, USB, ATA and virtio rows rest on text in other places.
* The Torvalds AVX-512 post and the NVIDIA talk were not obtained as primary text.
* The UNIX-HATERS Handbook chapters other than 2 were read with a keyword pass, not word by word; only hardware-rooted complaints are in the document.

## What remains

* The 16 unverified ledger rows (`verification-ledger.tsv`): the Wayland and rmap authorship, the Wikipedia Blit page, Pike's 2019 recollections, KFD/ROCm, five attack papers not read, and three that are not sourced claims.
* The 20 thin matrix rows, not pursued because they are not essential for the pdp64 design.
* The recommendations in `docs/architecture-recommendations.md` await the author's decisions; the eight manual edits of 14M.8 are applied (errata 71).
