#!/usr/bin/env python3
"""summary.py: the figures of the study in one text, from the traces (SCR) and tools/replay.py.  Writes to stdout."""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse, replay, prog
scr = os.environ.get('SCR', '/tmp/rti-mask-reuse')
PROGS = ['mini-kernel', 'twoproc', 'hv-first', 'hv-timer', 'hv-vtimer', 'hv-stage2', 'sec-hv-reset-mmuctl', 'sec-hv-reset-inplace']
print('== 1. executed returns, by program (RTI to a less privileged mode, GENTER; and RTI to the same mode) ==')
res = {}
for n in PROGS:
    r, rows, cls, k1, k2 = replay.run(n, scr, None); res[n] = (r, rows, cls, k1, k2)
    c = collections.Counter(cls)
    print('%-22s %4d returns %s; same-mode RTI %d' % (n, len(rows), dict(sorted(c.items())), r['same_mode_returns']))
print()
print('== 2. A2 (a latch that the last return set): how often the next return finds its mask already there ==')
print('%-22s %-3s %-8s %6s %6s %7s  %s' % ('program', 'pol', 'latch', 'hits', 'of', 'rate', 'per class (hits/events)'))
for n in PROGS:
    r = res[n][0]
    for p in ('K1', 'K2'):
        for dn in ('core', 'level', 'kind', 'process'):
            v = r[p].get('A2_' + dn)
            if not v: continue
            if n in ('hv-timer', 'hv-vtimer', 'sec-hv-reset-mmuctl', 'sec-hv-reset-inplace'): continue
            print('%-22s %-3s %-8s %6d %6d %6.1f%%  %s' % (n, p, dn, v['hits'], r['events'], 100.0 * v['hit_rate'], ' '.join('%s %d/%d' % (c, v['hits_by_class'][c], v['events_by_class'][c]) for c in v['events_by_class'])))
print()
print('== 3. what a stale latch would do at the returns that miss (if the short form were used there): LEAK = a register the latch keeps holds a value of the kernel or hypervisor; LOSS = a register the resumed code reads is cleared ==')
for n in ('mini-kernel', 'twoproc', 'hv-first', 'hv-stage2'):
    r = res[n][0]
    for p in ('K1', 'K2'):
        v = r[p]['A2_core']
        print('%-12s %-3s core latch: %4d misses of %4d returns: %3d would leak, %3d would lose a live value' % (n, p, v['misses'], r['events'], v['stale_leak_if_short'], v['stale_loss_if_short']))
print()
print('== 4. A1 (the latch is set by GENTER only; every RTI uses it): what a native kernel (no GENTER) gets with each reset value, and what a guest kernel gets ==')
for n in ('mini-kernel', 'twoproc', 'hv-first'):
    r = res[n][0]
    for p in ('K1', 'K2'):
        for rv, v in r[p]['A1'].items():
            print('%-12s %-3s %-10s %4d RTI to a lesser mode: mask differs from the one needed %4d, leaks %4d, loses %4d' % (n, p, rv, v['rti_events'], v['mask_differs_from_needed'], v['leak'], v['loss']))
print()
print('== 5. is the mask of an RTI the mask of the GENTER that started the guest run? (only hv-first has RTI inside a guest run) ==')
r, rows, cls, k1, k2 = res['hv-first']
gi = [i for i, x in enumerate(rows) if x[1] == 'genter']
for i, x in enumerate(rows):
    if x[1] != 'rti': continue
    print('RTI at line %d (%s): K1 %s  K2 %s; first GENTER (line %d) K1 %s K2 %s; latest GENTER before it (line %d) K1 %s K2 %s' % (
        x[2], cls[i], prog.fmt(k1[i]) if False else '0x%08x' % prog.mask(k1[i]), '0x%08x' % prog.mask(k2[i]), rows[gi[0]][2], '0x%08x' % prog.mask(k1[gi[0]]), '0x%08x' % prog.mask(k2[gi[0]]),
        rows[[j for j in gi if j < i][-1]][2], '0x%08x' % prog.mask(k1[[j for j in gi if j < i][-1]]), '0x%08x' % prog.mask(k2[[j for j in gi if j < i][-1]])))
print()
print('== 6. hypervisor values held in registers across a guest run (a GENTER whose mask clears them destroys them) ==')
for n in PROGS:
    rows = [x for x in analyse.analyse(n, scr) if x[1] == 'genter']
    c = collections.Counter(prog.fmt(x[14]) for x in rows)
    print('%-22s %3d GENTER: %s' % (n, len(rows), ', '.join('%s x %d' % (k, v) for k, v in c.items())))
print()
print('== 7. two processes: the returns after a context switch ==')
r, rows, cls, k1, k2 = res['twoproc']
sw = [i for i, x in enumerate(rows) if x[8] is not None and x[9] is not None and x[8] != x[9]]
print('returns to a lesser mode %d; to a different process than the one that last ran in user mode: %d (%s)' % (len(rows), len(sw), dict(collections.Counter(cls[i] for i in sw))))
tot = collections.Counter(cls[i] for i in range(len(rows)))
print('classes: %s' % dict(tot))
for p, mk in (('K1', k1), ('K2', k2)):
    prev = None; hs = ht = 0; hp = {}
    L = {}
    for i, x in enumerate(rows):
        pid = x[8]
        key = pid if p else 0
        hit_core = (prev == mk[i]); 
        if i in sw: ht += 1; hs += hit_core
        prev = mk[i]
    print('%s: of the %d returns after a switch, %d find their mask in the one core latch' % (p, ht, hs))
print()
print('== 8. nested returns (RTI to the same mode: a preempted system call resumed, a nested interrupt) ==')
for n in PROGS:
    print('%-22s %d' % (n, res[n][0]['same_mode_returns']))

print()
print('== 9. static size of the return instructions: sites, and the sites whose mask was found in the latch at every execution except the first use of the latch (which a boot-time setting would cover) ==')
print('%-22s %-3s %-6s %5s %7s %9s %12s' % ('program', 'pol', 'latch', 'sites', 'shortable', 'bytes B', 'bytes A2'))
for n in ('mini-kernel', 'twoproc', 'hv-first', 'hv-stage2'):
    r = res[n][0]
    for p in ('K1', 'K2'):
        for dn in ('core', 'kind'):
            v = r[p]['A2_' + dn]; ns = v['sites']; sh = v['sites_steady']
            print('%-22s %-3s %-6s %5d %7d %9d %12d' % (n, p, dn, ns, sh, 6 * ns, 6 * ns - 4 * sh))
