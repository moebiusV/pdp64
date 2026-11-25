#!/usr/bin/env python3
"""Trace-driven replay of the ways to keep a guest's cached translations from going stale (hole 1).

usage: replay.py [--tlb N] [--dir N] [--json] trace...

Trace format (written by the scratch hook in the QEMU model, see README.md):
  H h gtbr          h=0: entry into a guest (GENTER); h=1: exit to the hypervisor (and the reset state).  gtbr: the guest register, tag = bits 48..63
  W name value      the hypervisor wrote a translation register (GTBR, PTBR, ASID, MMUCTL)
  F op addr gtbr    a translation-cache operation of the architecture: op 0 TLBI page, 1 TLBIA / write of PTBR, ASID, MMUCTL, 2 sync, 3 GTBR root change (addr=new GTBR)
  T tag asid idx vpn type hit prot nr k:pa ...   a guest translation request (first touch of a page after the host's own buffer was emptied);
                    hit=1: served by the model's cache; nr reads of table entries: k=1 stage-1 entry, k=2 stage-2 entry; pa: physical address of the entry
  TH ...            the same for the hypervisor's own translation (not a guest translation: only used for the set of table pages)
  S pa size h       a store (pa physical address after translation, size bytes, h=1 by the hypervisor, h=0 by the guest)
"""
import sys, json, argparse
from collections import OrderedDict

RULES = ['today', 'flush-bit', 'every-entry', 'arena', 'directory']

class Entry:
    __slots__ = ('key', 'reads', 'pages', 'words', 'stale', 'prot', 'vpn')
    def __init__(s, key, reads, prot):
        s.key = key; s.reads = reads; s.prot = prot; s.vpn = key[3]
        s.pages = frozenset(pa >> 12 for k, pa in reads)
        s.words = frozenset(pa >> 3 for k, pa in reads)
        s.stale = False       # some table word it read was stored to after the fill

NEED = {0: 1, 1: 2, 2: 4}      # type: load, store, fetch -> PAGE_READ=1, PAGE_WRITE=2, PAGE_EXEC=4

def parse(fn):
    ev = []
    for l in open(fn):
        p = l.split()
        if not p: continue
        if p[0] in ('T', 'TH'):
            nr = int(p[8]); reads = []
            for x in p[9:9 + nr]:
                k, pa = x.split(':'); reads.append((int(k), int(pa, 16)))
            ev.append(('T' if p[0] == 'T' else 'TH', int(p[1]), int(p[2]), int(p[3]), int(p[4], 16), int(p[5]), int(p[6]), int(p[7]), reads))
        elif p[0] == 'S':
            ev.append(('S', int(p[1], 16), int(p[2]), int(p[3])))
        elif p[0] == 'H':
            ev.append(('H', int(p[1]), int(p[2], 16)))
        elif p[0] == 'W':
            ev.append(('W', p[1], int(p[2], 16)))
        elif p[0] == 'F':
            ev.append(('F', int(p[1]), int(p[2], 16), int(p[3], 16)))
    return ev

def tag_of(g): return (g >> 48) & 0xffff

def table_pages(ev):
    s1, s2 = set(), set()
    for e in ev:
        if e[0] in ('T', 'TH'):
            for k, pa in e[8]:
                (s1 if k == 1 else s2).add(pa >> 12)
    return s1, s2

class Sim:
    def __init__(s, rule, ev, tlb_cap=None, dir_cap=None, arena=None, fallback=False):
        s.fallback = fallback; s.rule = rule; s.tlb_cap = tlb_cap; s.dir_cap = dir_cap; s.arena = arena
        s.tlb = OrderedDict()                 # key -> Entry (LRU order)
        s.words = {}                          # word -> set of keys
        s.dirref = OrderedDict()              # table page -> refcount (LRU order of walks)
        s.flag = True                         # arena: the tables-changed flag (set at reset: safe)
        s.h = 1
        s.m = dict(requests=0, hits=0, walks=0, reads=0, disc_rule=0, disc_rule_false=0, disc_rule_true=0, disc_sw=0, disc_cap=0,
                   reads_full=0, stale_hits=0, stale_left=0, dir_evict=0, dir_evict_disc=0, entries=0, max_dir=0, max_tlb=0)
    # ---- entry bookkeeping
    def _remove(s, key, why):
        e = s.tlb.pop(key, None)
        if e is None: return
        for w in e.words:
            ks = s.words.get(w)
            if ks: ks.discard(key)
        if s.rule == 'directory':
            for pg in e.pages:
                if pg in s.dirref:
                    s.dirref[pg] -= 1
                    if s.dirref[pg] <= 0: del s.dirref[pg]
        if why == 'rule':
            s.m['disc_rule'] += 1
            s.m['disc_rule_true' if e.stale else 'disc_rule_false'] += 1
        elif why == 'sw': s.m['disc_sw'] += 1
        elif why == 'cap': s.m['disc_cap'] += 1
    def _install(s, e):
        if s.rule == 'directory':
            if s.dir_cap is not None and len(e.pages) > s.dir_cap:
                s.m['too_big'] = s.m.get('too_big', 0) + 1      # a walk that touches more distinct table pages than the directory holds cannot be cached at all
                return
            need = [p for p in e.pages]
            for pg in need:
                if pg not in s.dirref:
                    if s.dir_cap is not None and s.fallback and len(s.dirref) >= s.dir_cap:
                        # the directory is full: instead of dropping one page and what depends on it, drop everything (the rule of every entry), once
                        s.m['dir_overflow'] = s.m.get('dir_overflow', 0) + 1
                        for k in list(s.tlb): s._remove(k, 'rule')
                        s.dirref.clear()
                    if s.dir_cap is not None:
                        while len(s.dirref) >= s.dir_cap:
                            # evict the least recently walked page: discard what depended on it (must, or the entry would go unwatched)
                            victim = next(iter(s.dirref))
                            s.m['dir_evict'] += 1
                            for k in [k for k, x in s.tlb.items() if victim in x.pages]:
                                s.m['dir_evict_disc'] += 1
                                s._remove(k, 'rule')
                            s.dirref.pop(victim, None)
                    s.dirref[pg] = 0
                s.dirref[pg] += 1
                s.dirref.move_to_end(pg)
            s.m['max_dir'] = max(s.m['max_dir'], len(s.dirref))
        if s.tlb_cap is not None:
            while len(s.tlb) >= s.tlb_cap:
                s._remove(next(iter(s.tlb)), 'cap')
        s.tlb[e.key] = e
        for w in e.words: s.words.setdefault(w, set()).add(e.key)
        s.m['max_tlb'] = max(s.m['max_tlb'], len(s.tlb))
    # ---- events
    def run(s, ev):
        for e in ev:
            t = e[0]
            if t == 'H':
                if e[1] == 0:
                    s.m['entries'] += 1
                    if s.rule == 'every-entry':
                        for k in list(s.tlb): s._remove(k, 'rule')
                    elif s.rule == 'arena' and s.flag:
                        s.m['arena_flushes'] = s.m.get('arena_flushes', 0) + 1
                        if not s.tlb: s.m['arena_flush_empty'] = s.m.get('arena_flush_empty', 0) + 1
                        for k in list(s.tlb): s._remove(k, 'rule')
                        s.flag = False
                s.h = e[1]
            elif t == 'W':
                if s.rule == 'arena' and s.h == 1: s.flag = True
            elif t == 'F':
                op, addr, g = e[1], e[2], e[3]
                if op == 2: continue
                tg = tag_of(addr) if op == 3 else tag_of(g)
                for k in [k for k in s.tlb if k[0] == tg and (op != 0 or k[3] == addr >> 12)]:
                    s._remove(k, 'sw')
            elif t == 'S':
                pa, size = e[1], e[2]
                w0, w1 = pa >> 3, (pa + size - 1) >> 3
                for w in range(w0, w1 + 1):
                    for k in s.words.get(w, ()):
                        s.tlb[k].stale = True
                if s.rule == 'arena' and s.arena and s.arena[0] <= (pa >> 12) <= s.arena[1]:
                    s.flag = True
                if s.rule == 'directory':
                    pg0, pg1 = pa >> 12, (pa + size - 1) >> 12
                    for k in [k for k, x in s.tlb.items() if pg0 in x.pages or pg1 in x.pages]:
                        s._remove(k, 'rule')
            elif t == 'T':
                _, tag, asid, idx, vpn, typ, hit, prot, reads = e
                s.m['requests'] += 1
                key = (tag, asid, idx, vpn)
                need = NEED[typ]
                ent = s.tlb.get(key)
                if ent is not None and (ent.prot & need):
                    s.m['hits'] += 1
                    s.tlb.move_to_end(key)
                    if ent.stale: s.m['stale_hits'] += 1
                    continue
                s.m['walks'] += 1; s.m['reads'] += len(reads); s.m['reads_full'] += 3 if idx == 4 else 15
                if prot < 0:      # the walk failed in the trace: it reads and installs nothing
                    continue
                if ent is not None: s._remove(key, 'cap')
                s._install(Entry(key, reads, prot))
        s.m['stale_left'] = sum(1 for x in s.tlb.values() if x.stale)
        return s.m

def analyse(fn, tlb_cap=None, dir_cap=None):
    ev = parse(fn)
    s1, s2 = table_pages(ev)
    arena = (min(s2), max(s2)) if s2 else None
    out = {'file': fn, 'stage1_table_pages': len(s1), 'stage2_table_pages': len(s2), 'all_table_pages': len(s1 | s2),
           'arena': arena, 'arena_pages': (arena[1] - arena[0] + 1) if arena else 0,
           'entries': sum(1 for e in ev if e[0] == 'H' and e[1] == 0),
           'guest_requests': sum(1 for e in ev if e[0] == 'T'),
           'log_walks': sum(1 for e in ev if e[0] == 'T' and not e[6]),
           'stores': sum(1 for e in ev if e[0] == 'S'),
           'stores_by_hyp': sum(1 for e in ev if e[0] == 'S' and e[3] == 1),
           'stores_to_walked_table_pages': sum(1 for e in ev if e[0] == 'S' and (e[1] >> 12) in (s1 | s2)),
           'rules': {}}
    for r in ['today', 'every-entry', 'arena', 'directory']:
        sim = Sim(r, ev, tlb_cap, dir_cap, arena)
        out['rules'][r] = sim.run(ev)
    return out

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--tlb', type=int); ap.add_argument('--dir', type=int); ap.add_argument('--json', action='store_true')
    ap.add_argument('files', nargs='+'); a = ap.parse_args()
    for f in a.files:
        o = analyse(f, a.tlb, a.dir)
        if a.json: print(json.dumps(o))
        else:
            print(f, {k: v for k, v in o.items() if k != 'rules'})
            for r, m in o['rules'].items(): print('  ', r, m)
