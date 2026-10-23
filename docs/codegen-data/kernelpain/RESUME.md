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
