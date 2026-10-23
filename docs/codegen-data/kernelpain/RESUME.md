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

## What is left, in order

1. LWN articles through the Wayback Machine (29 wanted, listed in `reading-list.tsv`, status "not fetched"); 8 were fetched before the rate limit; several archived 2024 captures are LWN's own "Blocked due to excessive requests" page, so try an earlier year (2019, 2016). Rule: at least 60 s between archive.org requests, one at a time.
2. FreeBSD lists: `lists.freebsd.org/pipermail/<list>/<YYYY-Month>/thread.html` works (the `archives/` month index returned 404); mine 2018 (PTI, PCID, Meltdown), 2012 (PCID), `freebsd-arch` and `freebsd-current`.
3. Pre-2005 Linux lists: `lkml.iu.edu/hypermail/linux/kernel/YYMM.N/index.html` works (by-thread index of one slice of a month); marc.info's search only shows the 30 newest hits, so it cannot reach old mail. Topics: SMP scalability, big kernel lock, O(1) scheduler, 4G/4G, NPTL, Alpha ordering, ARM cache aliasing, DMA API.
4. NetBSD: more `tech-kern` months (2017-12, 2018-01 done in part, 2019-05 MDS), `port-vax`, `port-alpha`, `tech-smp`.
5. OpenBSD: marc.info body search is noisy (returns recent dmesg-quoting posts for "meltdown"); better to take thread links from known posts. Not yet read: Theo's "Mitigations and other real Security Features" and Bluhm's "OpenBSD Attack Mitigations" slides (PDFs gave no text), the release pages 6.x/7.x for what hurt.
6. Papers and talks (unverified until fetched): Meltdown, Spectre, KAISER, Foreshadow, RIDL, ZombieLoad, Retbleed, Downfall, Hertzbleed, GoFetch, Rowhammer family, Drepper, McKenney perfbook, TLB-shootdown literature.
7. lore threads not yet read: the 2017-18 Gleixner PTI series cover, Linus/Dave Hansen per-process KPTI discussion, Skylake RSB thread in full, RISC-V atomics (Zacas), arm64 TLB range cover letter numbers, THP original cover letters, vDSO/TSC reliability posts, MSI/GIC performance posts, `unaligned` policy.

## Pacing state of each site (as of 2026-10-23 01:30 local)

| Host | State | Rule going on |
|---|---|---|
| lwn.net | blocked us on 2026-10-22 (spam protection) | no direct request, ever without the author's word; Wayback copies only |
| archive.org / web.archive.org | returned 429 on the availability API after about 3 requests on 2026-10-22 ~19:02; served pages afterwards at 45 s spacing | at least 60 s between requests; first 429: wait at least 5 minutes, double after each further one |
| marc.info | 504 and 502 on about 7 of 90 pages on 2026-10-22 ~18:30 | 20 s or more; on a 504 repeat, back off 5 minutes and double |
| lore.kernel.org | no block seen in about 300 requests at ~20 s spacing | 20 s |
| mail-index.netbsd.org, lists.freebsd.org, lkml.iu.edu, openbsd.org, man.openbsd.org, intel.com, developer.arm.com, gofetch.fail, hertzbleed.com, bearssl.org, github.com | no block seen | 20 s |

## Half-written or rough

* `kernel-pain-points.md` Appendix A has 53 rows from round 1; the round 2 additions are in a second table "A.2". Chapter text in 3-13 was not rewritten after round 2: read 14B beside them.
* The `kernelpain.py msgs` counts include known noise (see section 16); `mds-l1tf-taa` still matches Ceph "mds".
* `boot.md` (the author's) is cross-referenced from section 14B only; it is not edited.
