#!/usr/bin/env python3
"""slab.py TRACE...: replays the allocation requests of malloc traces (../sizeclass/mtrace.c; host programs, glibc, x86-64: NOT an OpenBSD or pdp64 run) through a MODEL of
OpenBSD's malloc (lib/libc/stdlib/malloc.c, read: requests up to MALLOC_MAXCHUNK = half a page are chunks of a multiple of 16 bytes, MALLOC_MINSIZE 16, in a page per
size bucket with a bitmap of free chunks kept apart from the page (struct chunk_info), the slot chosen at random among the free ones of the first page with room; larger
requests are whole pages; frees go through a delay of 16 random slots (delayed_chunks)).  The page size is 4096 and each pid has its own heap.
It measures what the colour designs need:
  slots reused while the slab page still holds a live chunk (the hole that a retired virtual page cannot close, and that parity colouring cannot close) versus pages that drain
  (every chunk freed: with retirement the page's virtual address is never handed out again);
  reuses of the same slot (generations per slot), and how many fall in the first 1, 6 and 13 reuses;
  the footprint in pages at the peak, with no extra, with a 16-byte red zone per chunk, with a FIFO quarantine of W frees;
  the virtual bytes retired (every drained slab page and every freed run of pages) and the number of unmaps.
Cap: the first CAP records of each trace."""
import sys, struct, random, collections
CAP = 2_500_000; PG = 4096; MAXC = 2048
def run(arg):
    path, rz, W = arg; NR = (W == -1)
    random.seed(1)
    data = open(path, 'rb').read()[:CAP * 24]
    heaps = {}                          # pid -> state
    st = dict(allocs=0, small=0, large=0, reuse_live=0, reuse_total=0, first=0, drains=0, retired_bytes=0, unmaps=0, gen_hist=collections.Counter(), live_req=0, peak_req=0, peak_foot=0, foot=0,
              redzone_extra=0, hole=0, closed_drain=0, pending_end=0, large_frees=0)
    live = {}; objs = {}; oid = [0]     # (pid,ptr) -> object id ; id -> (kind, page, slot, size, csz)
    class Heap: pass
    def heap(pid):
        h = heaps.get(pid)
        if h is None:
            h = Heap(); h.partial = collections.defaultdict(list); h.pages = {}; h.nextpage = 0; h.delay = collections.deque(); heaps[pid] = h
        return h
    def release(h, o):
        kind, pg, slot, size, rsz = objs.pop(o)
        if kind == 'L':
            st['foot'] -= pg * PG; st['retired_bytes'] += pg * PG; st['unmaps'] += 1; st['live_req'] -= size; st['large_frees'] += 1; return
        p = h.pages[pg]; st['live_req'] -= size; p['live'] -= 1
        if NR:                                   # one-time slots: a freed chunk's slot is not handed out again; the page goes back (and its address is retired) when no chunk of it is live
            if p['live'] == 0:
                del h.pages[pg]; h.partial[p['b']] = [x for x in h.partial[p['b']] if x != pg]
                st['drains'] += 1; st['retired_bytes'] += PG; st['unmaps'] += 1; st['foot'] -= PG
            return
        p['free'][slot] = True; p['nfree'] += 1; p['pending'].add(slot)
        if p['nfree'] == p['total']:
            st['closed_drain'] += len(p['pending']); del h.pages[pg]; h.partial[p['b']] = [x for x in h.partial[p['b']] if x != pg]
            st['drains'] += 1; st['retired_bytes'] += PG; st['unmaps'] += 1; st['foot'] -= PG
        elif p['nfree'] == 1: h.partial[p['b']].append(pg)
    for op, pid, size, ptr in struct.iter_unpack('<IIQQ', data):
        h = heap(pid); key = (pid, ptr)
        if op == 1:
            if key in live: release(h, live.pop(key))
            st['allocs'] += 1; sz = max(size, 1); need = sz + rz
            if need <= MAXC:
                b = (need + 15) // 16; csz = b * 16; nslots = PG // csz
                lst = h.partial[b]
                if not lst:
                    pg = h.nextpage; h.nextpage += 1
                    h.pages[pg] = dict(b=b, total=nslots, nfree=nslots, free=[True] * nslots, used=[0] * nslots, pending=set(), live=0); lst.append(pg); st['foot'] += PG
                pg = lst[0]; p = h.pages[pg]
                cand = [i for i, f in enumerate(p['free']) if f]; slot = random.choice(cand)
                p['free'][slot] = False; p['nfree'] -= 1; p['live'] += 1
                if p['nfree'] == 0: lst.pop(0)
                st['small'] += 1
                p['pending'].discard(slot)
                if p['used'][slot]:
                    st['hole'] += 1
                    st['reuse_total'] += 1
                    if p['nfree'] + 1 < p['total']: st['reuse_live'] += 1       # some other chunk of the page was live when this slot came back
                    st['gen_hist'][p['used'][slot]] += 1
                else: st['first'] += 1
                p['used'][slot] += 1
                oid[0] += 1; objs[oid[0]] = ('S', pg, slot, size, csz); live[key] = oid[0]
            else:
                npg = (need + PG - 1) // PG; st['large'] += 1; st['foot'] += npg * PG
                oid[0] += 1; objs[oid[0]] = ('L', npg, 0, size, 0); live[key] = oid[0]
            st['live_req'] += size
            if st['live_req'] > st['peak_req']: st['peak_req'] = st['live_req']
            if st['foot'] > st['peak_foot']: st['peak_foot'] = st['foot']
        elif op == 2:
            if key not in live: continue
            o = live.pop(key)
            if W == 0: release(h, o)
            else:
                h.delay.append(o)                          # FIFO quarantine of W frees (the chunk stays allocated: its slot is not reused)
                if len(h.delay) > W: release(h, h.delay.popleft())
    # note: with W>0 the quarantined chunks stay in the footprint, which is the cost; live_req counts them until released
    for h in heaps.values():
        for p in h.pages.values(): st['pending_end'] += len(p['pending'])
    return path, rz, W, st
def main():
    from multiprocessing import Pool
    paths = sys.argv[1:]
    jobs = [(p, rz, W) for p in paths for (rz, W) in [(0, 0), (16, 0), (0, 16), (0, 256), (0, 4096), (0, -1)]]
    out = collections.defaultdict(dict)
    with Pool(6) as pool:
        for path, rz, W, st in pool.imap_unordered(run, jobs): out[path][(rz, W)] = st
    for path in sorted(out):
        o = out[path]; b = o[(0, 0)]; nm = path.split('tr-')[-1]
        rt = max(1, b['reuse_total']); sm = max(1, b['small'])
        g = b['gen_hist']; tot = sum(g.values()) or 1
        small_frees = max(1, b['hole'] + b['closed_drain'] + b['pending_end'])
        print('%-7s freed small chunks: slot reused in a live page %.1f%%, page drained first %.1f%%, still free at the end %.1f%%; large frees %d |' % (nm, 100.0 * b['hole'] / small_frees, 100.0 * b['closed_drain'] / small_frees, 100.0 * b['pending_end'] / small_frees, b['large_frees']))
        print('        allocs %8d small(<=2048-ish) %5.1f%% | slot reuse %5.1f%% of small allocs; of reuses %5.1f%% land in a page that still has a live chunk | drained pages %d (%.1f MB of virtual address retired, %d unmaps incl. large) | reuse generation: <=1 %.1f%% <=6 %.1f%% <=13 %.1f%% max %d | peak foot/peak live %.3f; +16B red zone %.3f; quarantine 16 frees %.3f, 256 %.3f, 4096 %.3f; one-time slots (never reuse a slot while its page is live) %.3f, retiring %.1f MB of address in %d unmaps'
              % (b['allocs'], 100.0 * b['small'] / max(1, b['allocs']), 100.0 * b['reuse_total'] / sm, 100.0 * b['reuse_live'] / rt, b['drains'], b['retired_bytes'] / 1e6, b['unmaps'],
                 100.0 * sum(v for k, v in g.items() if k <= 1) / tot, 100.0 * sum(v for k, v in g.items() if k <= 6) / tot, 100.0 * sum(v for k, v in g.items() if k <= 13) / tot, max(g) if g else 0,
                 b['peak_foot'] / max(1, b['peak_req']), o[(16, 0)]['peak_foot'] / max(1, o[(16, 0)]['peak_req']), o[(0, 16)]['peak_foot'] / max(1, b['peak_req']), o[(0, 256)]['peak_foot'] / max(1, b['peak_req']), o[(0, 4096)]['peak_foot'] / max(1, b['peak_req']), o[(0, -1)]['peak_foot'] / max(1, b['peak_req']), o[(0, -1)]['retired_bytes'] / 1e6, o[(0, -1)]['unmaps']))
if __name__ == '__main__': main()
