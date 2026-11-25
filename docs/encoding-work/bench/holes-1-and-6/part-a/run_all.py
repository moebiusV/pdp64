#!/usr/bin/env python3
"""Run the replay over the recorded traces and the synthetic ones; write the tables used by the study.  usage: run_all.py TRACE_DIR OUT_DIR"""
import sys, os, json, subprocess, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import replay
tdir, odir = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(odir, exist_ok=True)
progs = ['hv-first', 'hv-stage2', 'hv-timer', 'hv-vtimer', 'sec-hv-reset-inplace', 'sec-hv-reset-mmuctl']
out = open(os.path.join(odir, 'recorded.txt'), 'w')
def P(*a):
    print(*a); print(*a, file=out)
raw = {}
for tlb in (None, 32):
    P('=== recorded traces; hardware buffer: %s ===' % ('unbounded (as the model\'s own cache)' if tlb is None else '%d entries, least recently used out' % tlb))
    for p in progs:
        ev = replay.parse(os.path.join(tdir, p + '.trace'))
        s1, s2 = replay.table_pages(ev)
        arena = (min(s2), max(s2)) if s2 else None
        P('-- %s: entries %d, guest translation requests %d, walks in the model %d, stores %d (hypervisor %d), table pages walked: stage 1 %d, stage 2 %d, together %d; arena %s (%d pages)' % (
            p, sum(1 for e in ev if e[0]=='H' and e[1]==0), sum(1 for e in ev if e[0]=='T'), sum(1 for e in ev if e[0]=='T' and not e[6]),
            sum(1 for e in ev if e[0]=='S'), sum(1 for e in ev if e[0]=='S' and e[3]==1), len(s1), len(s2), len(s1|s2), arena, (arena[1]-arena[0]+1) if arena else 0))
        P('   %-22s %5s %5s %6s %6s %7s %6s %6s %6s %6s' % ('rule', 'walks', 'hits', 'reads', 'rd15', 'stale', 'dTrue', 'dFalse', 'dSoft', 'dEvict'))
        for name, rule, dcap in (('today', 'today', None), ('every entry', 'every-entry', None), ('arena', 'arena', None), ('directory unbounded', 'directory', None),
                                 ('directory 32', 'directory', 32), ('directory 16', 'directory', 16), ('directory 8', 'directory', 8), ('directory 4', 'directory', 4), ('directory 4 + overflow flush', 'directory-fb', 4)):
            m = replay.Sim('directory' if rule == 'directory-fb' else rule, ev, tlb, dcap, arena, fallback=(rule == 'directory-fb')).run(ev)
            raw[(p, tlb, name)] = m
            P('   %-22s %5d %5d %6d %6d %7d %6d %6d %6d %6d' % (name, m['walks'], m['hits'], m['reads'], m['reads_full'], m['stale_hits'], m['disc_rule_true'], m['disc_rule_false'], m['disc_sw'], m['dir_evict_disc']))
        ma = raw[(p, tlb, 'arena')]; P('   arena flag flushed at %d of the entries (%d of them with nothing to discard)' % (ma.get('arena_flushes', 0), ma.get('arena_flush_empty', 0)))
        P()
P('columns: walks = translation requests that missed and walked; reads = table entries read as logged (superpage leaves read fewer); rd15 = the same walks charged the full nested count of the manual (15 reads for three levels in each stage, 3 for stage 2 alone); stale = translations served after a table entry they were made from had been stored to; dTrue / dFalse = translations discarded by the rule because a table entry they read had / had not been stored to (dFalse: a store elsewhere in the same table page, or a flush of everything); dSoft = discarded by the program\'s own TLBI / TLBIA / register writes; dEvict = discarded because the directory had to drop a table page')
out.close()
json.dump({'|'.join(map(str, k)): v for k, v in raw.items()}, open(os.path.join(odir, 'recorded.json'), 'w'), indent=1)

# synthetic
out = open(os.path.join(odir, 'synthetic.txt'), 'w')
def PS(*a):
    print(*a); print(*a, file=out)
PS('=== synthetic guest that churns its stage-2 tables: 48 pages, 20 touches per entry, 1000 entries, hardware buffer 64 entries; the hypervisor stores one word into a stage-2 leaf table page of a random region before every K-th entry ===')
PS('%-3s %-4s | %-30s | %-30s | %-34s' % ('R', 'K', 'correct software (TLBIA after each edit)', 'arena', 'directory D=8 / 16 / 32 / 64, then D=8 / 16 with flush-all on overflow'))
PS('%-3s %-4s | %-30s | %-30s | %-34s' % ('', '', 'walks   reads(rd15)', 'walks   reads   falseDisc', 'walks (false+evict disc)'))
tmp = os.path.join(odir, 'tmp.trace')
for R in (4, 8, 16, 32, 64):
    for K in (1, 10, 100, 0):
        res = {}
        for fl in (True, False):
            subprocess.check_call([sys.executable, os.path.join(here, 'synth.py'), tmp, '--pages', '48', '--regions', str(R), '--touches', '20', '--entries', '1000', '--edit-every', str(K)] + (['--sw-flush'] if fl else []))
            ev = replay.parse(tmp); s1, s2 = replay.table_pages(ev); arena = (min(s2), max(s2))
            if fl: res['soft'] = replay.Sim('today', ev, 64, None, arena).run(ev)
            else:
                res['arena'] = replay.Sim('arena', ev, 64, None, arena).run(ev)
                res['today_noflush'] = replay.Sim('today', ev, 64, None, arena).run(ev)
                res['dir'] = {d: replay.Sim('directory', ev, 64, d, arena).run(ev) for d in (8, 16, 32, 64)}
                res['fb'] = {d: replay.Sim('directory', ev, 64, d, arena, fallback=True).run(ev) for d in (8, 16)}
                res['pages'] = len(s1 | s2)
        a = res['arena']; so = res['soft']
        PS('%-3d %-4s | %5d %9d %-14s| %5d %9d %6d     | %s | table pages %d, stale uses with no flush at all: %d' % (R, K if K else 'never', so['walks'], so['reads_full'], '', a['walks'], a['reads_full'], a['disc_rule_false'],
            ' / '.join('%d (%d+%d)' % (res['dir'][d]['walks'], res['dir'][d]['disc_rule_false'], res['dir'][d]['dir_evict_disc']) for d in (8, 16, 32, 64)) + ' ; fb ' + ' / '.join('%d' % res['fb'][d]['walks'] for d in (8, 16)), res['pages'], res['today_noflush']['stale_hits']))
        raw[('syn', R, K)] = {'soft': so, 'arena': a, 'dir': {str(d): v for d, v in res['dir'].items()}, 'fb': {str(d): v for d, v in res['fb'].items()}, 'noflush': res['today_noflush']}
os.remove(tmp)
out.close()
json.dump({'|'.join(map(str, k)): v for k, v in raw.items() if k[0] == 'syn'}, open(os.path.join(odir, 'synthetic.json'), 'w'), indent=1)
