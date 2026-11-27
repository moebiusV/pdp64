#!/usr/bin/env python3
"""sizesum.py sizeir.json: print the totals of sizeir.py."""
import json, sys
d = json.load(open(sys.argv[1])); T = {}; sz = []
for k, r in d.items():
    for f, v in r.items():
        if f == 'esc_sizes': sz += v
        else: T[f] = T.get(f, 0) + v
sz.sort(); n = len(sz)
def pw(x):
    p = 1
    while p < x: p <<= 1
    return p
print(T); print('escaping static-size stack objects', n, ' dynamic', T['esc_dyn'], ' allocas', T['alloca'])
for t in (8, 16, 32, 64, 256, 1024, 4096): print('  size <=%d: %.1f%%' % (t, 100 * sum(1 for s in sz if s <= t) / n))
big = [s for s in sz if s > 16]
print('objects >16 bytes: %d (%.1f%% of escaping), bytes %d, pow2 slots %d, ratio %.2f; all escaping: bytes %d pow2 %d ratio %.2f' % (len(big), 100 * len(big) / n, sum(big), sum(pw(s) for s in big), sum(pw(s) for s in big) / sum(big), sum(sz), sum(pw(max(s, 1)) for s in sz), sum(pw(max(s, 1)) for s in sz) / sum(sz)))
print('median %d p90 %d max %d' % (sz[n // 2], sz[int(n * .9)], sz[-1]))
print('IR instructions (-O2) %d: escaping objects per 1000 instructions %.1f ; with size>16: %.1f' % (T['instrs'], 1000 * (n + T['esc_dyn']) / T['instrs'], 1000 * len(big) / T['instrs']))
print('functions %d, with an escaping object %d, with one >16 bytes %d' % (T['funcs'], T['funcs_esc'], T['funcs_big']))
print('allocator calls %d, constant size %d (%.1f%%)' % (T['alloc_calls'], T['alloc_const'], 100 * T['alloc_const'] / max(1, T['alloc_calls'])))
print('-O0: ptrtoint %d, inttoptr %d, in %d IR instructions: %.2f per 1000' % (T['ptrtoint'], T['inttoptr'], T['instrs0'], 1000 * (T['ptrtoint'] + T['inttoptr']) / T['instrs0']))
print('-O0 pointer compares: relational %d, equality %d (per 1000 IR instructions: %.2f, %.2f)' % (T['ptr_rel'], T['ptr_eq'], 1000 * T['ptr_rel'] / T['instrs0'], 1000 * T['ptr_eq'] / T['instrs0']))
