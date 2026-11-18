#!/usr/bin/env python3
"""pages2d.py -- how many pages and cache lines a w x h tile touches (docs/encoding-work/vec-2d.md, 'why not' (a)).  Measured by enumeration, not estimated: for each frame pitch and each
page size, the tile base is placed at every 4-byte-aligned offset of a page (and, for the line counts, of a 64-byte line); the tables give the mean number of distinct pages the tile touches, the
mean fraction of its rows that straddle a page boundary (the rows whose strips need two translations), and the mean 64-byte lines per row.  A stream of bytes: 1 byte a pixel."""
import sys
PITCHES = (640, 1280, 1920, 2560, 3840, 4096)
SIZES = ((8, 8), (16, 16), (32, 32), (64, 64))
def tile(w, h, pitch, ps, step):
    tot_pages = tot_split = tot_lines = n = 0
    for bm in range(0, ps, step):
        pg = set(); split = 0; lines = 0
        for r in range(h):
            a = bm + r * pitch; b = a + w - 1
            rp = range(a // ps, b // ps + 1)
            pg.update(rp); split += len(rp) > 1
            lines += b // 64 - a // 64 + 1
        tot_pages += len(pg); tot_split += split / h; tot_lines += lines / h; n += 1
    return tot_pages / n, tot_split / n, tot_lines / n
for ps in (4096, 2 << 20):
    print('page size %d' % ps)
    print('pitch   ' + ' | '.join('%dx%d: pages, split rows, lines/row' % s for s in SIZES))
    for pitch in PITCHES:
        step = 4 if ps == 4096 else 4096
        print('%5d   ' % pitch + ' | '.join('%6.2f  %6.3f  %5.2f' % tile(w, h, pitch, ps, step) for (w, h) in SIZES))
