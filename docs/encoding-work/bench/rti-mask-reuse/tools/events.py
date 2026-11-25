#!/usr/bin/env python3
"""events.py NAME [SCR]: the executed return and entry instructions of a traced run, in order, each with the instruction that ran next.
Reads SCR/NAME.map, NAME.s.ins and NAME.trace (tools/run_trace.sh).  One output line per executed RTI, GENTER, TRAP or HALT:   kind  k  source-line  next_k
(k: the instruction's number from tools/sites.py; next_k: the number of the instruction executed after it, 0 at the end; an address with bit 31 set, the user alias, is matched with
its kernel address)."""
import sys, re, os
def load(n, scr):
    addr = {}
    for l in open('%s/%s.map' % (scr, n)):
        m = re.match(r'0x([0-9a-f]+) __I_(\d+)$', l.strip())
        if m: addr[int(m.group(1), 16)] = int(m.group(2))
    ins = {}
    for l in open('%s/%s.s.ins' % (scr, n)):
        k, ln, txt = l.rstrip('\n').split('\t', 2); ins[int(k)] = (int(ln), txt)
    seq = []; raw = []; import bisect; keys = sorted(addr)
    for l in open('%s/%s.trace' % (scr, n)):
        m = re.match(r'Trace 0: 0x[0-9a-f]+ \[[0-9a-f]+/([0-9a-f]+)/', l)
        if not m: continue
        pc = int(m.group(1), 16); raw.append(pc)
        for p in (pc, pc & 0x7fffffff, pc & 0xffffffff):
            if p in addr: seq.append(addr[p]); break
        else:
            # an address between two labels (padding that the linker put in front of an instruction): the next instruction
            q = pc & 0x7fffffff; j = bisect.bisect_left(keys, q)
            seq.append(addr[keys[j]] if j < len(keys) and keys[j] - q < 8 else -1)
    return ins, seq, raw
if __name__ == '__main__':
    n = sys.argv[1]; scr = sys.argv[2] if len(sys.argv) > 2 else os.environ.get('SCR', '/tmp/rti-mask-reuse')
    ins, seq, raw = load(n, scr)
    for i, k in enumerate(seq):
        if k in ins:
            mn = ins[k][1].split()[0]
            if mn in ('rti', 'genter', 'trap', 'halt'):
                print(mn, k, ins[k][0], seq[i + 1] if i + 1 < len(seq) else 0)
