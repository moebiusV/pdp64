#!/usr/bin/env python3
"""replay.py [--out DIR] NAME...: play the executed returns of traced runs against the two designs and count.
For every executed RTI to a less privileged mode and every executed GENTER (tools/analyse.py) a mask is chosen in two ways (a mask is a set of registers that KEEP their values):
  K1  'the complement of what the code dirtied': all registers except those the kernel or hypervisor code wrote and did not put back (r0 is kept at a system call: it is the result).
  K2  'the system-call convention': a system call returns with r0 and the callee-saved registers only (r8-r11, r13, r15, r24-r31), a fresh start returns with nothing, an interrupt, a
      fault or a switch with K1.
and, as a reference that no kernel can use, O: exactly the registers the resumed code reads before writing them.
Designs:
  B   RTI #mask, the mask in the instruction (decided).  No state.  Every return is correct by construction; cost: 4 bytes a site.
  A1  RTI without immediate, GENTER #mask latches, RTI in the guest's run uses the latched mask (no way to change it but the next GENTER).  A native kernel: the reset value of the latch.
  A2  RTI without immediate uses a latch that the last return set; a return that needs another mask first executes one setter instruction (RTIMASK #m, 6 bytes, assumed) which sets it.
      Latch domains: core (one latch), level (one latch for the code that runs GENTER, one for the code that runs RTI), process (the level latch is saved and restored with the process).
A hit is a return whose mask equals the latch.  A miss under A2 costs one setter; under A1 it is a wrong mask.  What a wrong mask does is counted against the same return: LEAK = a register
the latch keeps that holds a value the kernel or hypervisor wrote (r0 at a system call excepted); LOSS = a register the resumed code reads that the latch clears.
usage: replay.py [--out DIR] NAME...   (SCR as for tools/analyse.py)"""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse, prog
ALL = frozenset(range(32)) - {14}
CS = frozenset({8, 9, 10, 11, 13, 15} | set(range(24, 32)))
S_ABI = frozenset({0}) | CS
# the kind of return, by program and source line of the RTI / GENTER in the preprocessed program (tools/sites.py numbering is by line of the .pp.s file)
CLASS = {
 'mini-kernel': {56: 'start', 79: 'syscall', 104: 'fault', 117: 'interrupt'},
 'twoproc': {58: 'start', 117: 'start', 81: 'syscall', 107: 'interrupt'},
 'hv-first': {202: 'start', 213: 'syscall', 224: 'interrupt'},
}
def classify(name, rows):
    """class of every event: start / syscall / fault / interrupt for RTI; g-start, g-after (resumes after the instruction that exited), g-retry (the instruction that exited is run again),
    g-new (a different entry point) for GENTER"""
    out = []; last_guest_pc = None
    for r in rows:
        n, mn, ln, txt, res, live, dirty, lvl, pid, ppid, rawd, nx, lgk, lgn, hh = r
        if mn == 'rti':
            out.append(CLASS.get(name, {}).get(ln, 'interrupt')); continue
        if not any(o.startswith('g-') for o in out): out.append('g-start')
        elif nx == lgk: out.append('g-retry')            # the instruction that caused the exit runs again
        elif nx == lgn: out.append('g-after')            # the guest goes on after the instruction that caused the exit
        else: out.append('g-new')                        # the hypervisor chose another entry point: a new run
    return out
def kmasks(rows, cls):
    """K1 and K2 for every event; the dirty set of a site is the union over the executions of the site (the static dirty set of its handler)"""
    site_d = collections.defaultdict(set); site_r = collections.defaultdict(set)
    for r, c in zip(rows, cls):
        site_d[(r[1], r[2])] |= r[6]; site_r[(r[1], r[2])] |= r[10]
    k1, k2 = [], []
    for r, c in zip(rows, cls):
        D = set(site_d[(r[1], r[2])])
        if c == 'syscall': D.discard(0)
        m1 = ALL - D
        if c in ('start', 'g-start', 'g-new'): m2 = frozenset()
        elif c == 'syscall': m2 = S_ABI
        else: m2 = m1
        k1.append(frozenset(m1)); k2.append(frozenset(m2))
    return k1, k2
def dirty_of(pname, r, c):
    """what the kernel or hypervisor left in registers at this return.  K1: the code as it is written.  K2: a kernel that has dropped the PUSHM/POPM around a system call because the
    return clears the convention's scratch registers (the registers it wrote are then all dirty)."""
    d = set(r[10]) if (pname == 'K2' and c == 'syscall') else set(r[6])
    if c == 'syscall': d.discard(0)
    return d
def run(name, scr, out):
    rows = analyse.analyse(name, scr)
    rows = [r for r in rows if r[7] == 'lesser']          # returns to a less privileged mode and guest entries
    cls = classify(name, rows)
    k1, k2 = kmasks(rows, cls)
    res = collections.OrderedDict(); res['program'] = name; res['events'] = len(rows)
    res['by_class'] = dict(collections.Counter(cls))
    all_rows = analyse.analyse(name, scr); res['same_mode_returns'] = sum(1 for r in all_rows if r[7] == 'same')
    for pname, mk in (('K1', k1), ('K2', k2), ('O', [r[5] for r in rows])):
        d = collections.OrderedDict()
        # is the mask of an RTI to a lesser mode the mask of the GENTER that started the guest's run (the first GENTER) / the most recent GENTER?
        rt = [i for i, r in enumerate(rows) if r[1] == 'rti']
        gi = [i for i, r in enumerate(rows) if r[1] == 'genter']
        eq_first = eq_last = 0
        for i in rt:
            prior = [j for j in gi if j < i]
            if prior:
                eq_first += mk[i] == mk[prior[0]]; eq_last += mk[i] == mk[prior[-1]]
        d['rti_in_guest_run'] = sum(1 for i in rt if any(j < i for j in gi))
        d['rti_equal_first_genter'] = eq_first; d['rti_equal_latest_genter'] = eq_last
        d['distinct_masks'] = len({m for m in mk})
        # A2 with a latch per domain; a domain function gives the latch an event uses
        def dom_core(i, r): return 0
        def dom_level(i, r): return 1 if r[1] == 'genter' else 0
        def dom_process(i, r): return ('G' if r[1] == 'genter' else 'P%s' % (r[8] if r[8] is not None else r[9]))
        def dom_kind(i, r): return 'G' if r[1] == 'genter' else cls[i]        # one latch for each kind of return: start, system call, fault, interrupt, GENTER
        for dn, dom in (('core', dom_core), ('level', dom_level), ('kind', dom_kind)) + ((('process', dom_process),) if name == 'twoproc' else ()):
            L = {}; hits = misses = 0; sites = collections.defaultdict(lambda: [0, 0]); sites2 = collections.defaultdict(lambda: [0, 0]); leak = loss = 0; first = True; cold = [0]; bk = collections.defaultdict(lambda: [0, 0])
            for i, r in enumerate(rows):
                dm = dom(i, r); cur = L.get(dm)
                hit = cur == mk[i]
                sites[(r[1], r[2])][0 if hit else 1] += 1
                bk[cls[i]][0 if hit else 1] += 1
                if cur is not None: sites2[(r[1], r[2])][0 if hit else 1] += 1       # the first return of a latch finds nothing in it: set at boot, not counted
                else: sites2[(r[1], r[2])]; cold[0] += 1
                if hit: hits += 1
                else:
                    misses += 1
                    if cur is not None:     # what the stale latch would have done at this return
                        keepers = cur
                        dirt = dirty_of(pname, r, cls[i])
                        if keepers & dirt: leak += 1
                        if r[5] - keepers: loss += 1
                L[dm] = mk[i]
            safe = sum(1 for s, (h, m) in sites.items() if m == 0 or (h and m == 0))
            d['A2_' + dn] = {'hits': hits, 'misses': misses, 'hit_rate': round(hits / max(1, len(rows)), 3), 'sites': len(sites),
                             'sites_all_hit': sum(1 for s, (h, m) in sites.items() if m == 0 and h > 0), 'cold_first_use': cold[0], 'sites_steady': sum(1 for s, (h, m) in sites2.items() if m == 0 and h > 0), 'stale_leak_if_short': leak, 'stale_loss_if_short': loss, 'hits_by_class': {c: v[0] for c, v in sorted(bk.items())}, 'events_by_class': {c: v[0] + v[1] for c, v in sorted(bk.items())}, 'sites_by_kind': {k: sum(1 for s in sites if s[0] == k) for k in ('rti', 'genter')}, 'sites_all_hit_by_kind': {k: sum(1 for s, (h, m) in sites.items() if s[0] == k and m == 0 and h > 0) for k in ('rti', 'genter')}}
        # A1: the latch is set by GENTER only; native kernels: reset value ALL (no clearing) or 0 (clear everything)
        a1 = collections.OrderedDict()
        for rv_name, rv in (('reset_all', ALL), ('reset_zero', frozenset())):
            L = rv; leak = loss = wrong = 0; n = 0
            for i, r in enumerate(rows):
                if r[1] == 'genter': L = mk[i]; continue
                n += 1
                dirt = dirty_of(pname, r, cls[i])
                lk = bool(L & dirt); ls = bool(r[5] - L)
                leak += lk; loss += ls; wrong += (L != mk[i])
            a1[rv_name] = {'rti_events': n, 'mask_differs_from_needed': wrong, 'leak': leak, 'loss': loss}
        d['A1'] = a1
        res[pname] = d
    return res, rows, cls, k1, k2
if __name__ == '__main__':
    args = sys.argv[1:]; outdir = None
    if args and args[0] == '--out': outdir = args[1]; args = args[2:]
    scr = os.environ.get('SCR', '/tmp/rti-mask-reuse')
    allres = []
    for name in args:
        res, rows, cls, k1, k2 = run(name, scr, outdir)
        allres.append(res)
        if outdir:
            os.makedirs(outdir, exist_ok=True)
            with open('%s/events-%s.tsv' % (outdir, name), 'w') as f:
                f.write('n\tkind\tclass\tsite\tresume\tpid\tprev_pid\tlive(O)\tdirty\tK1\tK2\n')
                for i, r in enumerate(rows):
                    f.write('%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' % (i + 1, r[1], cls[i], r[2], r[4], '' if r[8] is None else r[8], '' if r[9] is None else r[9],
                            prog.fmt(r[5]), prog.fmt(r[6]), '0x%08x' % prog.mask(k1[i]), '0x%08x' % prog.mask(k2[i])))
    print(json.dumps(allres, indent=1))
    if outdir:
        json.dump(allres, open(outdir + '/replay.json', 'w'), indent=1)
