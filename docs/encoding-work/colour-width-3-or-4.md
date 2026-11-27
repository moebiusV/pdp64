# Three colour bits or four: what the measurement says

[← encoding work](README.md) · errata 239, 240, 243 · R562, R565 · design: `colouring-and-taint-design.md` · tools: `bench/colouring/gen3.c`, `gen3-table.py`, `colour3.v`, `gates3.sh`; results in `bench/colouring/results/gen3-w0.txt`, `gen3-w16.txt`, `gates3.tsv`

Written 2026-11-27. Nothing in the grammar, the assembler, the executor, the tests or the manual is changed; the four-bit specification of errata 240 stands until you decide. Every number is labelled **measured** (I ran it here, in the slab model, on the 18 host malloc traces: glibc on x86-64, not an OpenBSD or pdp64 run, and the model is mine), **counted** (arithmetic or a gate count), **assumed** or **unverified**.

## The recommendation, headline first

**Keep four bits.** If you want three, it is a sound design only if the allocator chooses colours by looking at its neighbours, not by slot parity; and even then it costs real safety margin for a small gain.

1. Three bits do close overflow into the neighbouring object, use after free while the slot is free, and double free while the slot is free, exactly as four bits do (counted and measured: zero neighbour violations in 18 traces, every policy that looks at the neighbours).
2. What three bits shorten is the number of reuses of a slot for which a stale pointer is still caught: slot-parity colouring with 3 generations is caught for **2** reuses against **5** with six generations (measured, and it is **5**, not the six the note and errata 240 say: see section 1). A stale pointer that is used after the slot was reused three times passes. That happens to **21 percent of frees (median of 18 traces; mean 34 percent)** against 4.8 percent (mean 26) with six generations (measured).
3. If the stale pointer is used after a random number of reuses of mean one (assumed), the share of such uses that pass is **1.4 percent (median; mean 2.4) with parity and three generations, 0.04 percent (mean 0.2) with parity and six** (a factor of 37 at the median, measured under the assumed distance). A neighbour-aware free choice with six colours (3 bits) gets back most of it: **0.20 percent (mean 0.41)**, caught for 3 reuses; with fourteen colours (4 bits) the same policy is caught for **11** reuses and passes about **0.000 percent (mean 0.001)**.
4. The hardware gets smaller, not worse, in logic (comparator 17 against 24 NAND2, counted); the storage gets worse to lay out. 3 bits do not divide a byte, a power-of-two tag-cache line or a DDR side-band width; the 0.78 percentage points of memory (counted: 32 MB in 4 GB) can be taken only with 8 granules per 3 bytes and an address multiply by 3 in the tag path, or in the in-line side band not at all (the DRAM device count does not change: assumed, unverified).
5. By your principles in order (safety first, the number of generations is the safety margin) four bits win; the answer would change if the allocator is allowed to be neighbour-aware (then 3 bits give 3 reuses, a little less than parity with 4 bits' 5), if stale use is known to be quick (within one or two reuses), or if the DRAM side band is a custom width where 12 bits per line is free.

## 1. The window of use after free, counted and measured

**What the window is.** The pointer keeps the colour its object had. Memory shows 7 (or 15) while the slot is free, so every use through the old pointer faults, always. After the slot is allocated again the stale pointer faults only if the new occupant has another colour. With parity times G generations, rotating, occupant n and occupant n+G have the same colour: a stale pointer is caught for **G - 1** reuses and **passes at the G-th** (counted; the model shows the first recurrence at reuse 6 for G = 6 and at reuse 3 for G = 3, on every trace). So errata 240 and the design note, which say "six reuses", should say **five**; the 94 percent "within six" figure is the share of slot reuses that are the first to sixth, and the exposed ones are those from the sixth on. (Counted; I note it because it is a small error in text you approved.)

**How I measured it.** `bench/colouring/gen3.c` is the slab model of `slab.py` (the same page, chunk and free-slot rules; first 2.5 M records of each trace; C for speed, so the random slot choices differ from `slab.py` but not the distributions) with the colour of every occupant recorded, for six policies:

| name | rule | live colours | bits |
|---|---|---|---|
| A6 | parity x 6 generations (errata 240) | 12 | 4 |
| A3 | parity x 3 generations | 6 | 3 |
| F14 | free choice: not equal to either live neighbouring slot, then the colour this slot used least recently | 14 | 4 |
| F6 | the same | 6 | 3 |
| F14b, F6b | the same, but a page's first slot draws from the lower half of the colours and its last slot from the upper half, so that two slab pages side by side need no look across the boundary | 14, 6 | 4, 3 |
| E6, E3 | the "middle option": generation rotated per slab page (parity x page epoch mod G; a slot reused twice in one epoch bumps the epoch) | 12, 6 | 4, 3 |

**Table 1, measured, W = 0 (a freed slot is at once free).** Small chunks freed (up to 2,048 bytes; the colour-bearing ones). Columns: share of those frees whose slot is reused at least k more times before its page drains or the trace ends. A stale pointer from such a free **passes at the G-th reuse**, so the k = 3 column is the parity-with-3-generations exposure and the k = 6 column the parity-with-6 exposure. (This is exact: the allocation that is the k-th reuse or later is, one for one, a free whose stale pointer has come back round.)

```
trace       frees     >=1    >=2    >=3    >=6        percent of small frees
awk        279453    99.5   58.5   34.6    7.6
clang     1109202    75.9   67.6   62.3   51.7
diff        25666     0.8    0.3    0.1    0.0
find       204316    75.4   73.5   72.2   69.7
gawk2      709894    99.6   39.5   15.5    0.8
gcc       1134376    84.5   80.1   77.5   71.8
git         4320    87.8   76.8   70.1   56.0
gitlog   1152192    29.2   27.7   26.5   24.4
grep          569    46.4   15.1    5.6    0.9
ls           6266    82.4   67.4   56.5   34.6
make          409    70.7   24.7   10.5    1.7
perl       877024    11.4    3.9    1.3    0.1
python       2603    22.7   11.0    6.4    2.0
sed         75147    99.2   98.4   97.7   96.0
sort          372    53.8   19.9    9.4    1.9
sqlite        498    24.7    7.6    3.4    1.0
ssh          6244    19.5    4.9    1.4    0.1
tar          3358    87.5   72.5   63.7   46.9
median               73.0   33.6   21.0    4.8
mean                 59.5   41.6   34.2   26.0
```

With a FIFO delay of 16 frees before a slot is free (`gen3-w16.txt`; closer to OpenBSD's delayed chunks) the medians are 73.7, 33.6, **21.0**, **4.6** (same). So **3 generations leave 21 percent of frees (median) exposed to a stale pointer that outlives three reuses, against 5 percent for six**. The programs that matter most for this are the allocation-heavy ones (gcc 78 against 72 percent, clang 62 against 52, sed 98 against 96, find 72 against 70): there the slot is reused so often that six generations also run out, and the extra margin of six is small. In the programs that reuse little (perl, ssh, python) both are good.

**The chance that a stale pointer is still used that late: assumed.** I fetched no use-after-free study, so I cite none and give a range. Model (assumed): the stale pointer is used after j reuses of its slot, j geometric with mean 0.5, 1, 2 or 4 (j = 0, the slot still free, is caught). Table 2, measured counts under that assumption: the share of such stale uses that pass, percent, **median over 18 traces / mean** (all 18 rows in `gen3-w0.txt`):

| mean j | A6 (4 bit, parity x 6) | A3 (3 bit, parity x 3) | F6 (3 bit, neighbour-aware) | F14 (4 bit, neighbour-aware) | F6b | E3 (page epoch) |
|---|---|---|---|---|---|---|
| 0.5 | 0.004 / 0.024 | 0.53 / 0.87 | 0.043 / 0.077 | 0.000 / 0.000 | 0.076 / 0.143 | 4.3 / 4.1 |
| 1 | 0.038 / 0.21 | 1.43 / 2.36 | 0.20 / 0.41 | 0.000 / 0.001 | 0.27 / 0.55 | 6.0 / 6.1 |
| 2 | 0.14 / 0.81 | 2.58 / 4.39 | 0.46 / 1.25 | 0.001 / 0.03 | 0.56 / 1.46 | 6.2 / 7.7 |
| 4 | 0.26 / 1.64 | 2.82 / 5.86 | 0.63 / 2.22 | 0.003 / 0.20 | 0.73 / 2.46 | 6.0 / 8.2 |

The worst single trace at mean 1: sed, A3 7.0 percent, A6 0.76 percent, F6 1.4 percent. What this means in words: if a use after free happens, with parity and three generations about 1 in 70 (median; worst 1 in 14) slips through the colour check; with six generations about 1 in 2,600 (worst 1 in 130). **Against an attacker** who can allocate and free at will, both windows are short (the allocator picks a random slot among the free ones, so the attacker needs many cycles; I did not model the attacker): the difference between 3 and 6 matters for bugs, much less for exploits.

## 2. The neighbour property: is it deterministic with 6 live colours?

**Yes, and it needs only 3 colours; the other three buy history.** The argument, in my words:

* Live objects, in address order, form a line. Each object touches at most two objects (the one before and the one after): the conflict graph of "must differ" is a **path**. A path is 2-colourable if you colour it all at once (alternate). **Online** that is not enough: an object is allocated into a gap between a live A and a live B that already have different colours, and the new object must differ from both, so it needs a **third**. With degree at most 2, a greedy choice always succeeds with 3 colours (degree + 1). Two live colours therefore fail (the "A _ B" case of the note); three never do. Three live colours need 0 and 7 reserved: five values, so 3 bits is the least that can work.
* **When an object is freed**, its slot becomes 7 and it stops constraining anyone. Its neighbours keep their colours (nobody recolours a live object), so the line stays valid. A later allocation in that gap picks a colour different from both *current* neighbours (at most 2 excluded) **and** from the colours its previous occupants had (the history). With L live colours this is possible whenever L - 2 - k >= 1, so the stale-pointer window is **k = L - 3 reuses**. L = 6: 3 reuses. L = 14: 11 reuses. The model agrees exactly (Table 3 of `gen3-w0.txt`, measured): F6 caught for 3, F14 caught for 11, **zero** neighbour violations in 18 traces (parity policies are zero by construction).
* **Slab pages (OpenBSD `malloc`).** Slots are adjacent in a page; parity (the low colour bit) makes neighbours differ with no look at all, which is why A3 and A6 cost nothing. At a page's ends: the chunk sizes are multiples of 16 and the page is 4,096, so the leftover at the end is either 0 (the chunk size divides 4,096, so the slot count is a power of two: even, the last slot has parity 1 and the next page's first slot parity 0) or at least one whole granule left uncoloured (colour 0, faults for any coloured pointer): both ends are separated (counted over all 128 size buckets: no bucket has an odd slot count with no leftover). Large objects (over 2,048 bytes) take whole pages with a guard page and no colour (colour 0): overflow into them faults for a coloured pointer.
* **A general (non-slab) allocator** knows the neighbours from its boundary tags or free list; the rule above is a handful of instructions (two `LDCOL`, a history word kept in the freed chunk's first word through the colour-7 pointer the allocator alone builds). Touching objects are the only constraint: a free gap between two objects (colour 7 or 0) faults on its own.
* **A neighbour-aware slab policy** (F6, F14) must look across a page boundary, or restrict the first and last slot (F6b, F14b). The restriction costs: **F6b caught only for 1 reuse at the end slots (guaranteed window 1 overall), F14b for 5**, and the pass probability goes from 0.20 to 0.27 percent (F6, mean j 1, median) and 0.000 to 0.001 (F14): small, because only 2 of the slots of a page are ends. But half the size classes (64 of 128) have 3 slots or fewer, so ends are the common case there.
* **What no colouring closes**, 3 bits or 4: an overflow that skips an object (it can land on the same colour), an overflow of less than the 16 bytes left in the last granule (median 73 percent of allocations are not a multiple of 16 bytes: counted in `summary.txt`), and a stale pointer used after its colour came round.

## 3. The middle option: generation rotated per slab page

I built it (E3, E6) and it **does not work**. If the generation is a page-wide epoch (bumped only when a slot would be used twice in the same epoch), two occupants of the same slot differ by one or more epochs, and the epoch also advances whenever any other slot is reused twice, so the difference can be exactly G after a single reuse: the colour repeats at reuse 1 in some traces (Table 3: "caught for 0 reuses"), so nothing is guaranteed. Measured pass probability at mean j of 1: **6.0 percent (E3) and 2.0 percent (E6)** against 1.4 and 0.04 for the per-slot generation. The state saved is one counter per page against one word per slot, and it costs all determinism. What helps the window is the opposite: more state per slot (a history word), which is the neighbour-aware choice above, and it gives 3 reuses with 3 bits, not the 2 of parity.

## 4. The cost side

**Memory (counted).** 3 bits per 16 bytes = 3/128 = **2.344 percent**; 4 bits = **3.125 percent**; the difference is 0.78 percentage points: 32 MB in 4 GB (96 MB against 128 MB), 96 bytes against 128 per 4 KB page, 12 against 16 bits per 64-byte line (3.1 to 2.3 percent more cache SRAM, assumed 64-byte lines).

**Packing (counted; hardware effects assumed or unverified).**

| place | 4 bits | 3 bits | what 3 bits do to it |
|---|---|---|---|
| side band in the line and in the DRAM line (ECC style) | 16 bits per 64-byte line | 12 bits per line | the cache needs 12 bits per line: any SRAM width does. DRAM side bands come in whole devices (x4 or x8): **3 bits save no DRAM** unless the width is custom (assumed; unverified for the target boards) |
| carve-out in RAM with a tag cache | 1 KB of data is 64 granules = 32 bytes: a power of two, a 32-byte tag-cache line, tag address = pa >> 5 | 64 granules = 24 bytes; 8 granules (128 bytes of data) = 3 bytes; tag address = (pa >> 7) x 3 (a shift and an add) | a 24-byte tag-cache line in a 32-byte SRAM slot (the SRAM waste is only the small cache: 25 percent of 16 KB); in DRAM 24-byte segments straddle 64-byte bursts: of the eight segments of a 192-byte period, 2 do (counted), so **25 percent of tag fills need two bursts**, unless layout is padded to 48 of 64 bytes (back to 4-bit density) or divides by 21 (21 groups of 3 bytes in 64) |
| `mcol`, `mcolrd`, `mcolwr` (errata 240 packs two granules per byte) | two granules a byte, aligned, 8 granules a 32-bit word | one granule per byte wastes 5 of 8 bits; 8 granules in 3 bytes is unaligned and an odd transfer size for a register; 10 granules in 30 bits of a 32-bit word (10.67 per word) is the nearest fit; a page is 96 bytes, which is not a power of two | the privileged read/write of a page's colours (128 bytes for 4 KB) becomes 96 bytes; the register form needs a specified granule count (8 in 24 bits, or 10 in 30) instead of the two-per-byte packing |
| 64-byte-line-aligned coherence | colours of a line change together with the line | same | none |

**Logic (counted with the repository's flow, `bench/colouring/gates3.sh`, results `results/gates3.tsv`; no timing, no wiring):**

| block | 4 bits | 3 bits |
|---|---|---|
| compare pointer colour with granule colour, plus freed fault | 24 NAND2 | **17** |
| the same for an access touching two granules | 49 | **32** |
| pick one granule out of a 64-byte line's colours | 37 | **28** |
| pick one granule out of a 128-byte pair (8 granules: 24 bits against 32) | 85 | **64** |
| canonical-address check over the three modes (colour field skipped) | 77 | 81 (one more bit to compare) |
| unsigned pointer compare ignoring the colour (60 against 61 bits) | 432 | 438 |

The comparator and the selection are smaller with 3 bits; the net is a few dozen NAND2 either way, against a core of thousands (the gates are so few that this does not decide anything). The cost of 3 bits is the awkward address arithmetic and the tag-fill straddle, not the logic.

**The pointer.** With 3 colour bits in 63 to 61, bit 60 is free; the manual's canonical rule becomes "bits 60 down to the top translated bit repeat it" (against "bits 59 down" with four). In the 57-bit form there are 7 bits above bit 56 (63 to 57): 3 colour bits leave **4** (60 to 57) that must repeat bit 56, against 3 with four colour bits. The freed bit has no use I can show a need for: more generations are bounded by the memory (a fourth bit in memory is the 4-bit design), not by the pointer, and eight generations with parity would need 16 colours plus two reserved: 5 bits, 3.9 percent of memory. A fourth bit in the pointer without a fourth bit in memory could be a "colour was stripped" or a "tag-ignore" hint, but I would leave it a sign copy: it keeps the canonical rule to one line and keeps four bits one edit away. A bigger field in the 57-bit form is limited to 7 colour bits anyway. **Whether eight generations could matter:** with the measured exposure (Table 1) six generations already leave 4.8 percent (median) of frees exposed to a stale pointer that outlives six reuses, and 26 percent in the mean; eight would leave 2.0 percent (median; mean 23.3; measured: the share of frees with at least 8 later reuses). So more generations help the allocation-heavy programs only slowly; the neighbour-aware choice (F14: 11 reuses with the same 4 bits) is the better lever.

## 5. The recommendation, by the principles in order

1. **Safety (the ladder, generations as the margin).** Four bits give five caught reuses with parity (measured), eleven with a neighbour-aware choice, and the fourteen live colours of which parity-with-six uses only twelve. Three bits give two (parity) or three (neighbour-aware). The owner's reason ("we can always colour a granule differently from the one before and after it") is **right and is exactly what makes 3 bits the minimum** (section 2); the stale pointer is the cost: **21 against 4.8 percent of frees (median) exposed after three or six reuses**, and a pass rate 11 to 130 times higher at the median (mean j 4 to 0.5) when a stale use does happen (assumed distance). Four bits win on the first principle.
2. **Speed.** The check is a comparator on the access path either way and there is no run-time difference (assumed). The tag-fill with 3 bits straddles 25 percent of the time in a packed carve-out (counted), which is up to 25 percent more tag traffic in that arrangement (assumed: the tag traffic measured in the design note is 2.4 to 4.3 percent of DRAM bytes, so this would be a fraction of a percent of total bytes: unverified). Four bits are no slower.
3. **Fewer instructions.** Parity costs the same either way. The neighbour-aware policy costs two `LDCOL` and a history word more per `malloc` than parity (assumed: a few instructions) and is needed to get 3 bits to a window of 3.
4. **Coherence of the set.** Four bits are two granules to a byte, a power-of-two tag line and a page of 128 bytes; three bits are none of those.

**What would change the answer to three bits:** (a) the target boards have a custom side-band width where a 12-bit line field is free and the 0.78 percentage points of RAM matter more than 3 extra reuses of margin; (b) a study shows stale pointers are used within one or two reuses of their free (then the windows 2 and 5 are both enough and the pass rate at mean j 0.5 of 0.5 percent for 3 bits against 0.004 percent is acceptable); (c) the allocator is committed to be neighbour-aware (window 3 with 3 bits against 5 with parity and 4 bits; F6 at j mean 1 passes 0.20 percent, close to A6's 0.04).

**If you want to keep an eye on the four-bit gain for later:** the 4-bit hardware is **richer than errata 240 uses**: parity times six generations uses 12 of the 14 live colours, and a neighbour-aware choice with all 14 gives 11 reuses (measured, F14) against 5, for two `LDCOL` and a history word in `malloc` and no hardware change. That is the better use of the fourth bit than a 0.78-point saving.

## What I assumed, and what I did not measure

* The traces are host glibc runs of 18 programs (x86-64), the first 2.5 M records of each; the allocator is **my model** of OpenBSD `malloc` as read before (4,096-byte pages, random free slot, no delay in W = 0, a FIFO delay of 16 in W = 16), not OpenBSD's own run and not the pdp64's.
* The distance between a free and a stale use is **assumed** (geometric over reuses, mean 0.5 to 4). I fetched no use-after-free study, so none is cited; a real distribution is the one number that would move the recommendation most.
* The attacker (who can allocate and free in a loop) is not modelled.
* Neighbour-aware policies are measured inside a page; across pages F6 and F14 are not guaranteed (F6b and F14b are, at the shorter window noted).
* Pass probabilities count recurrence up to 16 reuses back (D = 16): the tail beyond that is truncated; it only lowers the A3/A6 numbers by what falls beyond 16 (small at mean j <= 2; about 2 percent of the weight at mean 4).
* The hardware packing and the DRAM side-band statements (device widths, straddle fraction, burst size) are counted from arithmetic or assumed; there is no tag cache or DRAM model for 3 bits in `sim64`. The gate counts have no timing and no wiring.
* "Frees" are those of chunks up to 2,048 bytes that the model frees; chunks never freed in the trace are not counted.
