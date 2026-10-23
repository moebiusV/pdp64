# Resume note for the kernel pain-points research

(Written 2026-10-23 for whoever continues; not a design document.)

## What is done

* `docs/kernel-pain-points.md`: chapters 1-16, 14A (round 1 statements), 14B (round 2 statements by area, including a boot and firmware table), 14C (counts), Appendices A-C.
* `docs/hardware-vulnerabilities.md`: catalogue, constant-time analysis (4, 4.1), rules C1-C16.
* `docs/openbsd-mitigations.md`: 14 mitigations, vendor asks, improvement ideas.
* Data: `counts.csv`, `totals.csv`, `structural.csv`, `trees.csv` (current-source greps), `msgs-*` (commit-message mining), `reading-list.tsv` (round 1), `round2-index.tsv` (every page fetched in round 2 with area, query, URL, author, date and whether it is cited).
* Round 2 fetched about 290 pages from lore.kernel.org, marc.info (OpenBSD), mail-index.netbsd.org, lists.freebsd.org, lkml.iu.edu, reference sites and 8 archived LWN pages. Many are successive versions of one series; `round2-index.tsv` has the column `kind` (cited statement / routine / failed).

## Where the working files are (outside the repository, lost on a /tmp clean)

* Page cache of round 2: `/tmp/claude-1000/corpus/doc*.txt`, `pg*.txt`, index `/tmp/claude-1000/corpus/index.tsv`; the raw fetch files are in `~/claude/browse-output/` (`*_fetch_*.txt`, `nav_*.txt`).
* Query lists: `/tmp/claude-1000/queries.txt`, `queries2.txt`, `queries3.txt`, `wayback.txt`, `pages.txt`; drivers `driver.py` (lore, one fetch at a time, stops on block pages), `driver3.py`..`driver7.py`; helper `lk.py`; document pieces in `/tmp/claude-1000/doc/` (`part1.md`, `part2*.md`, `part3.md`, `appb.md`, `appc.md`, `assemble.py`). If `/tmp` is gone, the document `docs/kernel-pain-points.md` is the surviving result; the pieces can be rebuilt from it.

## Updates at the end of 2026-10-23 01:00-02:15

* Done since the first version of this note: FreeBSD `pipermail` 2018-January/February for `freebsd-arch` and `freebsd-current` (4 messages read); `lkml.iu.edu` thread indexes for 12 slices from 1997 to 2004 (36 messages read); NetBSD tech-kern 2018/02 and 2018/03 (5 messages); 8 LWN articles through the Wayback Machine; the browser was quit with `browsectl quit` and nothing from it was left running.
* Not done: the other 21 Wayback LWN copies (stopped on the author's instruction; later allowed again at 60 s spacing).

## Round 3 (2026-10-23, about 02:10-03:45 local): what was done

* 105 pages fetched one at a time with the browser, plus one fetch with no address (`round3-index.tsv` has 106 lines: area, query, URL, title, author, date, kind; 63 "cited statement", 38 context, 5 failed). Page text cache: `/tmp/claude-1000/corpus3/doc0001..doc0106.txt` (may be lost); fetcher `/tmp/claude-1000/r3.py` (calls `~/claude/browse-output/politewait.py` before every fetch; archive.org 65 s, others 20 s); notes `/tmp/claude-1000/r3notes.txt`; the document section pieces `/tmp/claude-1000/doc3/s14d.md`.
* Done from the queue: (1) all 21 remaining LWN articles through Wayback (2019 and 2023 captures; none blocked); (2) FreeBSD `freebsd-hackers` 2018-January and 2018-February (5 messages read, 3 of them on topic; months before 2018 not reached); (3) `lkml.iu.edu` slices 0101.0, 0110.0, 0305.0 (5 messages); (4) lore: Gleixner PTI cover and 3 replies, the PCID RFC and v5 cover, Skylake RSB commit and 5 replies, RISC-V Zacas cover and one reply, arm64 TLBI RANGE (v2 cover has no timings), THP benchmark post, Hansen global-pages cover, Linus on IBRS and unaligned access, Alpha LL/SC emulation, RCU on Alpha 2008; (5) NetBSD: `tech-kern` 2019/05 XSAVE RFC (port-vax, tech-smp, port-alpha yielded only indexes); (6) OpenBSD: one Theo post (SMT default) found by a marc.info subject search; (7) papers: Meltdown and Spectre (ar5iv HTML), ZombieLoad (ar5iv), project pages for Retbleed, Downfall, Foreshadow, RIDL/Fallout, and the Project Zero Rowhammer post.
* Documents changed: `docs/kernel-pain-points.md` (new section 14D with 53 rows, Appendix A.3 rows 83-112, a correction to the 14B row on uncacheable memory), `docs/hardware-vulnerabilities.md` (new section 9), `docs/openbsd-mitigations.md` (new section 10).
* **Pace slip:** the first two archive.org requests were 29 s apart (the coordinator stopped the run and added `politewait.py`); no block, 429, 503 or captcha was seen in round 3. The browser family exceeded 1.5 GB once (about 2.3 GB by `ps` rss sum) and was restarted with `browsectl quit` at 03:05.

## What is left, in order

1. FreeBSD lists before 2018 (`pipermail/<list>/<YYYY-Month>/thread.html` works; PCID work 2012 and 2017 not found yet); more `freebsd-hackers`/`freebsd-arch` months in 2018 for PTI and PCID.
2. Pre-2005 Linux lists: more `lkml.iu.edu` slices (ARM cache aliasing, 4G/4G, NPTL, big kernel lock); the index grep by keyword is cheap, most hits are routine.
3. lore: the per-process KPTI discussion (Linus and Hansen, Dec 2017/Jan 2018: not found by subject), vDSO/TSC reliability posts, MSI/GIC performance posts, the split-lock cover letter itself (searches by `f:torvalds` found nothing), the arm64 TLBI cover letter timings (RFC v1 to v3, early 2020), the rest of the Skylake RSB thread (about 30 messages in the listing).
4. NetBSD: `port-vax` and `port-alpha` message pages (list indexes are tiny; pick months by hand), `tech-smp` 2007 messages (month index lists three messages: link extraction failed, fetch by guessing the msg number), `tech-kern` 2019-05 XSAVE thread replies.
5. OpenBSD: Theo's "Mitigations and other real Security Features" and Bluhm's slides (PDF only). marc.info subject searches show only the newest 30 hits and are noisy; use thread links from known posts.
6. Papers: the originals of KAISER, Hertzbleed, GoFetch, Rowhammer (Kim et al.): only project pages or secondary posts were read; Intel and AMD advisories not read (DOIT, `VERW`).

## Pacing state of each site (as of 2026-10-23 03:40 local; times are the machine clock)

| Host | State | Rule going on |
|---|---|---|
| lwn.net | blocked us on 2026-10-22; **the author lifted the ban on 2026-10-23** ("just be polite"); no direct request yet since the block | may be requested again, politely: 30 s or more between requests (a precaution: it blocked us once), growing back-off after any block page |
| archive.org / web.archive.org | 21 pages served in round 3 at 65 s or more spacing; no 429 | 65 s between requests via `politewait.py archive.org 65`; first 429: wait at least 5 minutes, double after each further one |
| marc.info | 4 pages, no error | 20 s or more |
| lore.kernel.org | 43 pages at 20 s or more, no block | 20 s |
| mail-index.netbsd.org, lists.freebsd.org, lkml.iu.edu, openbsd.org, ar5iv.labs.arxiv.org, comsec.ethz.ch, downfall.page, foreshadowattack.eu, mdsattacks.com, googleprojectzero.blogspot.com | no block seen | 20 s |

## Half-written or rough

* `kernel-pain-points.md` Appendix A has 53 rows from round 1, a table "A.2" (rows 54-82) from round 2, and "A.3" (rows 83-112) from round 3. Chapter text in 3-13 was not rewritten after rounds 2 and 3: read 14B and 14D beside them.
* The `kernelpain.py msgs` counts include known noise (see section 16); `mds-l1tf-taa` still matches Ceph "mds".
* `boot.md` (the author's) is cross-referenced from section 14B only; it is not edited.
* Round 3 row 1 of the index (LWN 768418) has no separate title in the saved text; `kind` for each page is a judgement made while reading, and a few pages marked "cited statement" were read only in part (the Foreshadow-style project pages were read as FAQ pages; the FreeBSD stale-memory thread was read only at its start; the RIDL page's long timeline was skimmed).

## Round 4 (2026-10-23, about 10:40-12:00 local): what was done

* 53 pages fetched one at a time (`round4-index.tsv` has 53 lines: 29 "cited statement", 18 context, 6 failed), plus one Google `#search` that returned only a redirect page. Page text cache `/tmp/claude-1000/corpus4/doc0001..doc0053.txt` (may be lost); fetcher `/tmp/claude-1000/r4.py` (calls `politewait.py` before every fetch, 20 s); notes with the exact quotations `/tmp/claude-1000/notes4.txt`; section pieces `/tmp/claude-1000/s14e.md`, `a4.md`.
* Done from the queue: (1) FreeBSD: 2017-December `freebsd-arch` index (nothing on topic), svn r338715 (ifunc context switch), EN-26:10 (INVLPGB), wiki page blocked by Anubis; (2) lkml.iu.edu: 4G/4G announcement (July 2003); (3) lore: whole threads for the Skylake RSB commit (20 messages), split lock v10 (145), `lockref` on arm64 (74), `barrier_nospec()` (54), plus single posts (VIVT, 256-bit IO); (4) NetBSD: tech-smp 1999, 2000, 2001; port-vax 2024 and 2025; port-alpha 2020; (6) Intel documents (DOITM, MDS/VERW, SWAPGS, JCC, SRBDS, FSGSBASE, frequency, timing guide, mitigation guide), AMD-SB-1010 and 7005, Hertzbleed, GoFetch (headline only), TRRespass; local kernel `hw-vuln` documents.
* Documents changed: `docs/kernel-pain-points.md` (new 14E with 34 rows, Appendix A.4 rows 113-139, contents entry), `docs/hardware-vulnerabilities.md` (section 10, new rule suggestions N1-N7), `docs/openbsd-mitigations.md` (section 11; no new OpenBSD source), `round4-index.tsv`.
* No earlier claim was found wrong; one nuance added (the Skylake RSB commit comment was called incorrect by Kleen on 9 Mar 2018).
* **Pace slip:** one lore search went through `lk.py` without `politewait.py` (53 s after the previous lore request, so the 20 s floor held). No 429, 503, captcha or block. Walls: wiki.freebsd.org (Anubis page), Google search (script redirect). Browser quit with `browsectl quit`; nothing from it was left running.

## What is left after round 4, in order

1. PDF-only papers (KAISER, Rowhammer by Kim et al., GoFetch, Hertzbleed, mixed-size atomics POPL 2017): the browser gives no text from PDFs; look for HTML or arXiv versions (ar5iv) or give up on them.
2. lore: per-process KPTI discussion (Dec 2017), vDSO/TSC, MSI/GIC, arm64 TLBI RANGE cover timings; follow the thread `T/` flat view (it holds every message; 300-500 KB loads fine) from a message already known, as that worked for four threads in round 4.
3. NetBSD `port-vax` by month needs a search engine to pick months (DuckDuckGo HTML page `html.duckduckgo.com/html/?q=site:mail-index.netbsd.org/<list>+...` worked and gives direct URLs); 1990s months unread; `tech-smp` 2003 (buffer cache locking) and 2001-11 (dual Athlon, BIOS interrupt setting) found but not read.
4. Intel pages not fetched: retpoline, L1TF, gather data sampling, branch history injection, TSX asynchronous abort, load value injection, MMIO stale data (all listed at `.../topic-technology/software-security-guidance/advisory-guidance.html`); AMD bulletins for Zenbleed, Retbleed, TSA.
5. FreeBSD months before 2018 for PCID work; FreeBSD wiki pages need a way past Anubis (not attempted).
6. OpenBSD: nothing new; slides are PDF.
7. lkml.iu.edu: NPTL, BKL slices of 2002-2003 (the `0307.1` index is cached in doc0046 and lists 4G/4G replies by Bligh, Hansen, Kirill Korotaev, Russell King, Andi Kleen, Petr Vandrovec that were not read).

## Pacing state of each host after round 4 (machine clock about 11:30 local)

| Host | State | Rule going on |
|---|---|---|
| lwn.net | not requested in round 4; **the author lifted the ban on 2026-10-23** | may be requested directly again, politely: 30 s or more between requests (a precaution), growing back-off after any block page; Wayback copies remain an option |
| archive.org / web.archive.org | not requested in round 4; **the author lifted the ban on 2026-10-23** (it had blocked us for excessive requests on 2026-10-23) | politely: at least 60 s via `politewait.py archive.org 65`, growing back-off after any 429 or block |
| lore.kernel.org | 14 pages at 20 s or more, no block | 20 s |
| mail-index.netbsd.org | 9 pages, no block | 20 s |
| lists.freebsd.org, www.freebsd.org | 3 pages, no block | 20 s |
| wiki.freebsd.org | Anubis proof-of-work page, not retried | needs a human or a different route |
| www.intel.com | 12 pages at 20 s or more, no block (one wrong URL) | 20 s |
| www.amd.com, hertzbleed.com, gofetch.fail, vusec.net, lkml.iu.edu, gruss.cc | no block | 20 s |
| html.duckduckgo.com | 5 result pages, no block | 20 s |
| www.google.com `#search` | returned a script-redirect page; not retried | avoid |

## Round 5 (2026-10-23, about 11:20 onward): state at first checkpoint

* Files: `coverage-matrix.tsv` (95 topics, generated by `/tmp/claude-1000/r5w/matrix_a.py` + `matrix_b.py` + `build_matrix.py`; if /tmp is gone, edit the TSV directly), `round5-index.tsv` (63 requests), `docs/kernel-pain-points.md` section 14F and Appendix A.5 (rows 140-187), `hardware-vulnerabilities.md` section 11 (rules N8-N11), `openbsd-mitigations.md` section 12.
* Page cache: `/tmp/claude-1000/corpus5/doc0001..doc0061.txt`; fetcher `/tmp/claude-1000/r5.py` (calls politewait.py; waits for a new file in browse-output), `ddg.py` for DuckDuckGo result pages; notes with exact quotations `/tmp/claude-1000/notes5.txt`.
* The author then asked for (a) a GPU/display/HDMI/remote-display group (done in 14F as far as sources allowed), (b) NO time limit, a COMPREHENSIVE OVERVIEW chapter before chapter 1 (not yet written), (c) a section tying the UNIX-HATERS Handbook complaints to hardware/ISA/bus causes (not yet done). See the end of this file for the state when the run stopped.
* Still missing in the matrix (11): hash MMUs, IRQ affinity, HPET, palette pain, racing the beam, link training, HDCP/CEC, HDMI audio, MST/DSC, deep colour, Blit/NeWS texts.
* Browser: restarted once during the round (driver timeout after the RealWorldTech fetch, family 1.45 GB). Hosts used: lwn.net (8), lore.kernel.org, lkml.org, lists.freedesktop.org, arstechnica.com, heise.de, keithp.com, usenix.org, nouveau.freedesktop.org, blog.trailofbits.com, thunderclap.io, wayland.freedesktop.org, freebsd.org, man.openbsd.org, collabora.com, semiengineering.com, html.duckduckgo.com: no block, 429, 503 or captcha. Failed (page never finished loading): phoronix.com, realworldtech.com. docslib.org returned 137 bytes.

## Round 5 state at checkpoint 3 (updated after the author's three further requests)

* Done and committed: coverage-matrix.tsv (95 topics + 15 UNIX-HATERS reading-log lines), round5-index.tsv (66 requests; 32 cited-statement pages), kernel-pain-points.md: **chapter 0 (overview by area)**, section 14F (bus, GPU, old graphics, HDMI, remote display, chapter-3 decision table), **section 14G (UNIX-HATERS Handbook: only hardware-rooted complaints, 7 rows)**, Appendix A.5 rows 140-187; hardware-vulnerabilities.md section 11 (N8-N11); openbsd-mitigations.md section 12.
* The author's rules added mid-round: no time limit ("even 10 hours"); the Handbook section must contain ONLY complaints with a hardware/ISA/bus cause (pure software complaints are listed only in coverage-matrix.tsv as a reading log); chapter numbers stay stable (the overview is chapter 0).
* The Handbook text: `/tmp/claude-1000/corpus5/doc0064.txt` (OCR, 585 KB, from archive.org `ugh_djvu.txt`). Read in part (see the reading-log rows); chapters 2-5, 8, 9, 10 only skimmed.
* Streamlined chapter 3 was revised by the author during the round (section numbers: 3.1.2 video device, 3.1.4 BLT64, 3.1.5 slots; 3.3.1 HDMI; 3.4 framebuffer; 3.5 PCI Express card). 14F/A.5/chapter 0 were renumbered to match.
* Matrix still missing or thin: see the last column of coverage-matrix.tsv ("verdict after"); missing: hash MMUs, IRQ affinity, HPET, palette pain, racing the beam, DP link training, HDCP/CEC, HDMI audio, MST/DSC, deep colour, Blit/NeWS primary texts. Thin: NUMA, big.LITTLE, CPU hotplug, PAT/MTRR (docs only), software TLB, register windows (comments only), x32, Itanium (one source), AMD TLB errata, level/edge, virtio, AHCI, USB, ASPM/PCIe hot-plug, small BAR/ReBAR, VGA arbiter, Panfrost (one source), simplefb.
* Next steps for a fresh agent, in order: (1) fetch primary sources for the missing/thin matrix rows (lore threads, LWN, local Documentation first); each new row goes into 14F (or a new 14H), A.5 (rows from 188), the matrix (edit TSV), round5-index.tsv; (2) update the counts in 14F ("Coverage summary", "Counts for round 5": 66 requests now, not 63; the chapter 0 table should gain the new entries); (3) end: `./browsectl quit`, check `pgrep -af 'chrome|browse.py|uc_driver'`.
* Browser: running as of this checkpoint (restarted once). Hosts used since the last note: archive.org (2 requests, 65 s apart, no block). Rule reminder: politewait.py before each fetch (r5.py does it); 20 s ordinary, 30 s lwn.net, 65 s archive.org.


## Round 5 final state (end of this run)

* Matrix (`coverage-matrix.tsv`): 95 topics; before 13 covered well / 25 thin / 57 missing; after 52 / 40 / 3. Still missing: racing the beam (driver developers' writing), HDMI audio, DisplayPort MST and DSC. Thin items and what would lift them are in the last two columns. 15 further lines are the UNIX-HATERS reading log (working file only).
* Document changes: chapter 0 (overview by area), 14F, 14G (Handbook, hardware-rooted only), 14H, Appendix A.5 rows 140-196, hardware-vulnerabilities 11 (N8-N11), openbsd-mitigations 12. `round5-index.tsv`: 74 requests (37 cited statement pages, 27 searches, 6 context, 4 failed).
* Quotation audit: `/tmp/claude-1000/r5w/myquote.py ff8045a` (my stricter checker: normalised, punctuation-insensitive, searches the saved pages, the Handbook OCR with hyphenation repaired, the local kernel trees, the 4.3BSD source and the manual) gave 22 unmatched of 264 before the audit and 1 after (a quotation interrupted by a page header in the OCR, verified by hand). The coordinator's `quotecheck2.py` is slow (several minutes).
* Next steps for a continuation: fill thin rows from the lists (NUMA, big.LITTLE, CPU hotplug, level/edge, virtio, ASPM/PCIe hot-plug, USB host controller design posts, AMD TLB errata, F00F/HLT list posts, Torvalds on AVX-512 [RealWorldTech timed out], KFD/ROCm, OpenBSD drm port, simplefb); read the Handbook chapters that were only skimmed if the author wants them excluded explicitly; the Blit paper itself (PDF, no text).
* Browser: quit at the end of the run with `browsectl quit`. No 429, 503, captcha or block at any host; two hosts' pages never finished loading (phoronix.com, realworldtech.com). archive.org: 2 requests, 65 s apart, accepted.


## Round 6 (2026-10-23, from about 13:00 local): what was done

* **The Blit.** Method that worked, and why round 5 failed: PDFs and PostScript can be read by fetching a normal page on the same host and then running `./browsectl js` with a synchronous XMLHttpRequest that base64-encodes the file into the page body, then `./browsectl save`, decode, `pdftotext -layout` (PDF) or `gunzip` and `ps2ascii` (PostScript). Helper `/tmp/claude-1000/getpdf.py` (may be lost; the recipe is in section 14I of `kernel-pain-points.md`). Sources: doc.cat-v.org (Blit 1983, Transparent 1988, Concurrent 1989, 8½ 1991, Plan 9 paper, rio notes), www.cs.tufts.edu (Layers 1983), 9p.io (Tradeoffs 1985: `/cm/cs/doc/87/archtr.ps.gz`), man.cat-v.org (rio, draw, mux, 32ld), TUHS Dec 2019 thread, Wikipedia. Failed: archive.org journal scan (401), Tufts `blit-tradeoffs.pdf` (403, file permission), 9p.io `83/archtr.ps.gz` (404, wrong path).
* **Verdict on the manual's Blit account (14I.7):** 68000, serial link and downloaded code confirmed; "pixels" contradicted (the terminal drew everything); "bit-block-transfer engine" contradicted (the Blit had none); X11 and NeWS as successors unconfirmed. Proposed edits to `03-graphics.md` are in 14I.9 (not made).
* **Verification ledger** `verification-ledger.tsv` (228 rows: 102 verified, 11 corrected, 1 clarified, 114 still unverified) and **section 14J** (corrections). Largest finding: `thunderclap.io` now carries altered text (a betting company named as supporting the research platform), so round 5's quotations from it were replaced by the NDSS paper.
* Files: `round6-index.tsv` (47 lines, plus the later verification fetches listed below), `coverage-matrix.tsv` (97 topics: 56 covered well, 38 thin, 3 missing; 14K worked level/edge and BSD graphics), A.6 rows 197-206, chapter 0.6 row 12.
* Page text of round 6: `/tmp/claude-1000/corpus6/doc*.txt`, `/tmp/claude-1000/pdf6/*.txt` (may be lost). Quote checker `/tmp/claude-1000/r5w/myquote.py` (now includes corpus6, pdf6 and all of `docs/*.md`); attribution checker `/tmp/claude-1000/r6w/attrib2.py`.
* Not done: the 40 thin rows of the matrix (Goal 2) were not worked in round 6; see 14J "Still unverified".
* Browser: quit at the end with `browsectl quit`. No 429, 503, captcha or block page at any host.


## Round 7 (2026-10-24): state at checkpoint 1

* **Done and committed at this point:** the four original PDFs (KAISER, Kim et al., Hertzbleed, GoFetch) read from text and written up in `hardware-vulnerabilities.md` section 12; the POPL 2017 mixed-size paper (read in part); the two OpenBSD slide decks (`openbsd-mitigations.md` section 13); `kernel-pain-points.md` sections 14L (corrections, era checks) and 14M (graphics, display, bus, interrupts, atomics, memory and CPU rows, proposals), Appendix A.7 rows 207-240, chapter 0 rows; Appendix C.1 and C.2 status columns corrected; `round7-index.tsv` (64 lines); `coverage-matrix.tsv` (two new columns, 99 topics: 79 covered well, 20 thin, 0 missing after round 7; many "covered well" now rest on kernel source comments); `verification-ledger.tsv` (new columns `round 7 status`, `round 7 note`; 236 rows).
* **Method that worked:** (1) single files from the pinned Linux commit with `git show 7be4bc52fd9e0e55dc9a2e0232b89427d2c4b614:<path>` inside the blobless clone `~/claude/kernel-src/linux` (sequential, 1-15 s each; script `/tmp/claude-1000/r7w/kfetch.sh`, files in `/tmp/claude-1000/r7w/k/`): the sparse tree has no `drivers/gpu`, `drivers/pci`, `drivers/usb`, `drivers/ata`, `drivers/virtio`; (2) the PDF recipe of round 6 with `/tmp/claude-1000/r7w/getpdf7.py HOST PATH OUT` (politewait plus a per-host stamp; current tab must be on HOST); (3) `/tmp/claude-1000/r7w/r7.py URL area query` for pages (cache `/tmp/claude-1000/corpus7`); (4) quote gate `/tmp/claude-1000/r7w/myquote7.py <base-commit>` (base for round 7: `b20753d`; with a working-tree diff it needs no second argument).
* **Files outside the repository that the gate needs** (may be lost): `/tmp/claude-1000/corpus7/`, `/tmp/claude-1000/pdf7/`, `/tmp/claude-1000/r7w/k/`, `/tmp/claude-1000/corpus5/doc0064.txt` (Handbook OCR).

## Round 7 final state (2026-10-24)

* Scope was narrowed by the author mid-round: verify and completeness pass, no hunting of thin rows. Done: ledger pass (240 rows: 170 verified, 41 corrected, 13 clarified, 16 still unverified, each with a reason), essentials check by area (`kernel-pain-points.md` 14M.9; two essentials added: A.7 241 performance counters, 242 x86 real-mode trampoline), matrix (99 topics: 79 covered well, 20 thin with "not pursued: not essential", 0 missing), corrections in 14L (C10-C18; C18 is the Retbleed cost attribution), `architecture-recommendations.md` section 6, `openbsd-mitigations.md` 13, `hardware-vulnerabilities.md` 12.
* Papers read in round 7: KAISER, Kim et al., Hertzbleed, GoFetch, Retbleed (part), Thunderclap (rest), Flur et al. mixed-size (part), two OpenBSD slide decks; Downfall PDF only checked for two figures.
* Not done, by instruction: hunting for further sources on thin rows. Browser: quit at the end with `browsectl quit`.
