#!/usr/bin/env python3
"""trace.py TRACE...: replay malloc traces made by mtrace.so (see mtrace.c) under size-class rules and report, per trace:
  allocations, bytes requested, the shape by size band,
  the SLOT each rule would give (internal fragmentation): sum of slots over sum of requests, over all allocations, and at the peak of live memory of the busiest process,
  and the SLACK (slot minus request) of the power-of-two rule: the number of bytes an object placed at the start of its slot could be overrun before it leaves the slot.
Rules: base16 (round up to 16, the baseline, a malloc's own granule), pow2 (next power of two, at least 16), pow2p1 (next power of two of size+1, so that the
one-past-the-end address is still inside the slot), q4 (four classes a doubling, a general allocator's classes, for reference: NOT usable for the same-slot
check), pow2pg (pow2 for sizes below a page; from a page up the slot is virtual and only the pages of the object are mapped: round up to 4096).
Every number is a replay of a host trace (glibc, LP64): the program's requests, not an OpenBSD or pdp64 run."""
import sys, struct, collections
def nxt(n):
    p = 16
    while p < n: p <<= 1
    return p
def q4(n):
    if n <= 16: return 16
    p = nxt(n) >> 1                      # power of two below n (>= 16..)
    if p < 16: p = 16
    step = p // 4
    return p + (((n - p) + step - 1) // step) * step if n > p else p
RULES = {'base16': lambda n: max(16, (n + 15) & ~15), 'pow2': lambda n: nxt(max(n, 1)), 'pow2p1': lambda n: nxt(n + 1),
         'q4': q4, 'pow2pg': lambda n: nxt(n) if n < 4096 else (n + 4095) & ~4095}
BANDS = [(16, '<=16'), (64, '17-64'), (256, '65-256'), (4096, '257-4096'), (1 << 62, '>4096')]
def band(n):
    for hi, nm in BANDS:
        if n <= hi: return nm
def run(path):
    data = open(path, 'rb').read(); n = len(data) // 24
    live = collections.defaultdict(dict)                   # pid -> {ptr: size}
    cur = collections.defaultdict(lambda: {r: 0 for r in RULES}); curreq = collections.defaultdict(int)
    peak = collections.defaultdict(lambda: (0, None, 0))   # pid -> (req at peak, {rule: slot sum at peak}, req)
    tot = {r: 0 for r in RULES}; totreq = 0; cnt = 0
    bc = collections.Counter(); bb = collections.Counter(); sl = collections.Counter(); slb = collections.Counter()
    for op, pid, size, ptr in struct.iter_unpack('<IIQQ', data):
        L = live[pid]
        if op == 1:
            if ptr in L:                                    # a missed free: drop the old
                o = L.pop(ptr); curreq[pid] -= o
                for r, f in RULES.items(): cur[pid][r] -= f(o)
            L[ptr] = size; cnt += 1; totreq += size; curreq[pid] += size
            for r, f in RULES.items(): s = f(size); tot[r] += s; cur[pid][r] += s
            b = band(size); bc[b] += 1; bb[b] += size
            s2 = RULES['pow2'](max(size, 1)) - size
            k = '0-15' if s2 <= 15 else '16-63' if s2 <= 63 else '64-255' if s2 <= 255 else '256-4095' if s2 <= 4095 else '>=4096'
            sl[k] += 1; slb[k] += size
            if curreq[pid] > peak[pid][0]: peak[pid] = (curreq[pid], dict(cur[pid]), curreq[pid])
        elif op == 2:
            o = L.pop(ptr, None)
            if o is not None:
                curreq[pid] -= o
                for r, f in RULES.items(): cur[pid][r] -= f(o)
    bp = max(peak, key=lambda p: peak[p][0]) if peak else None
    return dict(path=path, allocs=cnt, bytes=totreq, tot=tot, bands=dict(bc), bandbytes=dict(bb), slack=dict(sl), slackbytes=dict(slb),
                peakreq=peak[bp][0] if bp else 0, peak=peak[bp][1] if bp else None)
if __name__ == '__main__':
    out = []
    for p in sys.argv[1:]:
        r = run(p); out.append(r)
        name = p.split('tr-')[-1]
        print('== %s: %d allocations, %d bytes requested (mean %.0f)' % (name, r['allocs'], r['bytes'], r['bytes'] / max(1, r['allocs'])))
        print('   bands (count share / bytes share): ' + ', '.join('%s %.1f%%/%.1f%%' % (nm, 100 * r['bands'].get(nm, 0) / max(1, r['allocs']), 100 * r['bandbytes'].get(nm, 0) / max(1, r['bytes'])) for _, nm in BANDS))
        b16 = r['tot']['base16']
        print('   slots over requests, all allocations: ' + ', '.join('%s %.2f' % (k, v / max(1, r['bytes'])) for k, v in r['tot'].items()) + '   (pow2 over base16: %.2f, pow2pg over base16 %.2f)' % (r['tot']['pow2'] / b16, r['tot']['pow2pg'] / b16))
        if r['peak']:
            pk = r['peak']; print('   at the peak of live memory (%d bytes requested): ' % r['peakreq'] + ', '.join('%s %.2f' % (k, v / max(1, r['peakreq'])) for k, v in pk.items()) + '   (pow2 over base16: %.2f, pow2pg over base16 %.2f)' % (pk['pow2'] / pk['base16'], pk['pow2pg'] / pk['base16']))
        print('   slack of pow2 (allocations / bytes): ' + ', '.join('%s %.1f%%/%.1f%%' % (k, 100 * r['slack'].get(k, 0) / max(1, r['allocs']), 100 * r['slackbytes'].get(k, 0) / max(1, r['bytes'])) for k in ('0-15', '16-63', '64-255', '256-4095', '>=4096')))
