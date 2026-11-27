#!/usr/bin/env python3
"""alloc.py TRACE...: the allocator side of granule colouring, replayed over malloc traces made by ../sizeclass/mtrace.c (host glibc, x86-64 LP64: NOT an OpenBSD or pdp64 run).
Per trace (the first CAP records of each trace, a cap so that the sorted-live-set parts run in reasonable time; the counts say how many records were read):
  colour writes: granules (16 B) set at malloc and again at free; 64-byte lines; those in allocations of a page or more (a per-page colour would replace them);
  the slack: allocations whose size is not a multiple of 16, the bytes in the last granule that an overflow or over-read can touch unseen;
  reuse: how many allocations land on an address freed before, the generations per address (a rotating colour sequence of N colours is deterministic against stale
         pointers of fewer than N generations back), the allocations between a free and its reuse;
  quarantine: FIFO of freed blocks held until their bytes exceed Q times the live bytes: the peak of (live + held) over the peak of live, for Q = 0.1, 0.25, 1;
  neighbours: at each allocation the live blocks just below and above by address, and how many are adjacent (gap <= 32 bytes): where a colour-different-from-both-neighbours rule matters.
"""
import sys, struct, collections, bisect
CAP = 3_000_000
def run(path):
    data = open(path, 'rb').read()[:CAP * 24]
    live = {}; order = []           # ptr -> size ; sorted list of live ptrs
    freed_at = {}                   # ptr -> alloc counter at free
    gen = collections.Counter()
    r = dict(path=path, recs=len(data) // 24, allocs=0, frees=0, req=0, gran_a=0, gran_f=0, lines_a=0, gran_big=0, notmul16=0, slackbytes=0, slackbytes_big=0, reuse=0,
             reuse_dist=[], adj_pred=0, adj_succ=0, adj_any=0, nbr_sampled=0)
    livebytes = 0; peak_live = 0
    qs = [0.1, 0.25, 1.0]; quar = {q: collections.deque() for q in qs}; qbytes = {q: 0 for q in qs}; peak_with = {q: 0 for q in qs}
    ac = 0
    for op, pid, size, ptr in struct.iter_unpack('<IIQQ', data):
        if pid != 0 and False: pass
        if op == 1:
            ac += 1; r['allocs'] += 1; r['req'] += size
            g = (size + 15) // 16 if size else 1
            r['gran_a'] += g; r['lines_a'] += (size + 63) // 64 if size else 1
            if size >= 4096: r['gran_big'] += g
            s = (-size) % 16
            if size % 16: r['notmul16'] += 1; r['slackbytes'] += s
            if ptr in freed_at: r['reuse'] += 1; r['reuse_dist'].append(ac - freed_at.pop(ptr))
            gen[ptr] += 1
            if ptr not in live:
                i = bisect.bisect_left(order, ptr)
                pred = order[i - 1] if i > 0 else None; succ = order[i] if i < len(order) else None
                if pred is not None and live[pred] + 16 >= 0 and ptr - (pred + live[pred]) <= 32: r['adj_pred'] += 1
                if succ is not None and succ - (ptr + size) <= 32: r['adj_succ'] += 1
                if (pred is not None and ptr - (pred + live[pred]) <= 32) or (succ is not None and succ - (ptr + size) <= 32): r['adj_any'] += 1
                r['nbr_sampled'] += 1
                order.insert(i, ptr)
            else: livebytes -= live[ptr]
            live[ptr] = size; livebytes += size
            if livebytes > peak_live: peak_live = livebytes
            for q in qs:
                while quar[q] and qbytes[q] > q * livebytes:
                    b = quar[q].popleft(); qbytes[q] -= b
                if livebytes + qbytes[q] > peak_with[q]: peak_with[q] = livebytes + qbytes[q]
        elif op == 2:
            sz = live.pop(ptr, None)
            if sz is None: continue
            r['frees'] += 1; r['gran_f'] += (sz + 15) // 16 if sz else 1
            i = bisect.bisect_left(order, ptr)
            if i < len(order) and order[i] == ptr: order.pop(i)
            livebytes -= sz; freed_at[ptr] = ac
            for q in qs:
                quar[q].append(sz); qbytes[q] += sz
                while quar[q] and qbytes[q] > q * livebytes + 0:
                    b = quar[q].popleft(); qbytes[q] -= b
    r['peak_live'] = peak_live; r['peak_with'] = peak_with
    gens = list(gen.values()); r['addrs'] = len(gens); r['gen_ge14'] = sum(1 for x in gens if x >= 14); r['gen_ge2'] = sum(1 for x in gens if x >= 2)
    r['allocs_on_gen_ge14'] = sum(x - 13 for x in gens if x > 13); r['maxgen'] = max(gens) if gens else 0
    d = sorted(r['reuse_dist']); r['reuse_med'] = d[len(d) // 2] if d else 0; r['reuse_le1'] = sum(1 for x in d if x <= 1); r['reuse_le64'] = sum(1 for x in d if x <= 64)
    del r['reuse_dist']
    return r
def show(r):
    n = max(1, r['allocs']); name = r['path'].split('tr-')[-1]
    print('%-7s recs %8d allocs %8d frees %8d | gran/alloc at malloc %6.1f, at free %6.1f, in allocs>=4KB %4.1f%% | size%%16!=0: %4.1f%% of allocs, mean slack %4.1f B (%.2f%% of requested bytes) | reuse of a freed address %4.1f%% (median %d allocs after the free, <=1: %4.1f%%) addresses %d, with >=14 generations %d (%.2f%% of allocs beyond the 13th) maxgen %d | adjacent live neighbour: %4.1f%% below, %4.1f%% above, %4.1f%% either | quarantine peak/live: %s'
          % (name, r['recs'], r['allocs'], r['frees'], r['gran_a'] / n, r['gran_f'] / max(1, r['frees']), 100.0 * r['gran_big'] / max(1, r['gran_a']),
             100.0 * r['notmul16'] / n, r['slackbytes'] / n, 100.0 * r['slackbytes'] / max(1, r['req']), 100.0 * r['reuse'] / n, r['reuse_med'], 100.0 * r['reuse_le1'] / max(1, r['reuse']),
             r['addrs'], r['gen_ge14'], 100.0 * r['allocs_on_gen_ge14'] / n, r['maxgen'],
             100.0 * r['adj_pred'] / max(1, r['nbr_sampled']), 100.0 * r['adj_succ'] / max(1, r['nbr_sampled']), 100.0 * r['adj_any'] / max(1, r['nbr_sampled']),
             ' '.join('Q%.2f:%.3f' % (q, r['peak_with'][q] / max(1, r['peak_live'])) for q in r['peak_with'])))
if __name__ == '__main__':
    from multiprocessing import Pool
    with Pool(6) as p:
        for r in p.map(run, sys.argv[1:]): show(r)
