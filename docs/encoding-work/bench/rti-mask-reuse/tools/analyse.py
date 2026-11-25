#!/usr/bin/env python3
"""analyse.py NAME [SCR]: for every executed RTI to a less privileged mode and every executed GENTER of a traced run, the registers that must survive the return and the registers that
hold the kernel's (or the hypervisor's) own values at that moment.  Writes a table to stdout (tab separated) and a summary line to stderr.
Columns: n, kind (rti|genter), site (source line of the program after preprocessing), text, resume (u: the code resumes at a user address, bit 31 set; k: at a kernel or guest-kernel
address), live (registers the resumed code reads before it writes them, tools/prog.py), dirty (registers written by the kernel or hypervisor code that ran since it was entered and
that a return should not give away).
How 'since it was entered' is decided: for a return to user mode, since the last instruction executed at a user address; for GENTER, since the last instruction executed in guest code
(REGIONS below says which labels delimit the guest code of each program)."""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prog, events
# guest code, as intervals of labels [from, to): instructions at or after `from` and before `to` run in the guest.  Programs with no entry have no guest code (a native kernel).
REGIONS = {
 'hv-first': [('gk', None)],
 'hv-timer': [('loop', 'back1')],
 'hv-vtimer': [('guest', 'xh')],
 'hv-stage2': [('g1', 'xh'), ('gh', None)],
 'sec-hv-reset-mmuctl': [('g9', 'xh'), ('gh', None)],
 'sec-hv-reset-inplace': [('g9', 'xh'), ('gh', None)],
}
# user processes: instructions between the labels belong to process 0 and 1 (only the two-process kernel has more than one)
PIDS = {'twoproc': [('userA', 'userB'), ('userB', 'bad')]}
def pid_map(P, name):
    m = {}
    for pid, (a, b) in enumerate(PIDS.get(name, [])):
        for k in P.order:
            if P.labs[a] <= k < P.labs[b]: m[k] = pid
    return m
def region_set(P, name):
    guest = set()
    for a, b in REGIONS.get(name, []):
        ka = P.labs[a]; kb = P.labs[b] if b else max(P.order) + 1
        guest |= {k for k in P.order if ka <= k < kb}
    return guest
def analyse(name, scr):
    P = prog.Prog(name, scr)
    ins, seq, raw = events.load(name, scr)
    guest = region_set(P, name); P.guest_halts = {k for k in guest if P.ins[k][0] == 'halt'}; P.liveness(); pids = pid_map(P, name); last_pid = None
    cum_h = set(); gw = set(); pend = None; held = {}; cum_at = {}
    uw = {}; pop_since = set(); raw_u = set(); raw_g = set(); last_gk = None
    since_u = set(); since_g = set(); rows = []; n = 0
    first_kernel_seen = False
    for i, k in enumerate(seq):
        if k not in P.ins: continue
        mn = P.ins[k][0]; pc = raw[i]
        user_here = bool(pc & 0x80000000)
        if user_here:
            since_u = set(); raw_u = set(); pop_since = set(); last_pid = pids.get(k, last_pid)
            if k in pids: uw.setdefault(pids[k], set()).update(P.rw[k][1])
        if k in guest: since_g = set(); raw_g = set(); last_gk = k
        elif not user_here:
            since_g |= P.rw[k][1]; raw_g |= P.rw[k][1]
        if not user_here and (not guest or k in guest): since_u |= P.rw[k][1]; raw_u |= P.rw[k][1]
        if guest:
            if k in guest:
                gw |= P.rw[k][1]
            elif not user_here:
                if pend is not None:
                    held[pend] = frozenset((P.livein[k] & cum_at[pend]) - gw - {14}); pend = None
                cum_h |= P.rw[k][1]
        if mn in ('popm', 'pop'):     # a register popped is put back to the value it had when it was pushed: it holds nothing of the kernel's
            m = int(P.ins[k][1][0].lstrip('#'), 0) if mn == 'popm' else 1 << prog.regno(P.ins[k][1][0])
            back = {j for j in range(32) if m >> j & 1}; since_u -= back; since_g -= back; pop_since |= back
        if mn in ('rti', 'genter'):
            nx = seq[i + 1] if i + 1 < len(seq) else 0
            res_user = bool(raw[i + 1] & 0x80000000) if i + 1 < len(raw) else False
            live = P.livein.get(nx, frozenset())
            dirty = (since_u if mn == 'rti' else since_g) - {14}
            if mn == 'rti' and res_user and not user_here and pids.get(nx) is not None and pids.get(nx) != last_pid and last_pid is not None:
                dirty = dirty | (uw.get(last_pid, set()) - pop_since)       # a switch: the registers still hold the values of the process that was running
            n += 1
            if mn == 'genter': pend = n; cum_at[n] = frozenset(cum_h); gw = set()
            rows.append((n, mn, P.ins[k][2], P.ins[k][3], 'u' if res_user else 'k', live, frozenset(dirty), 'lesser' if (mn == 'genter' or (res_user and not user_here)) else 'same', pids.get(nx), last_pid, frozenset((raw_u if mn == 'rti' else raw_g) - {14}), nx, last_gk, P.order[P.order.index(last_gk) + 1] if last_gk in P.ins and P.order.index(last_gk) + 1 < len(P.order) else None, n))
            if mn == 'genter': since_g = set(); raw_g = set()
            if mn == 'rti': since_u = set(); raw_u = set()
    return [r[:-1] + (held.get(r[-1], frozenset()),) for r in rows]
if __name__ == '__main__':
    name = sys.argv[1]; scr = sys.argv[2] if len(sys.argv) > 2 else os.environ.get('SCR', '/tmp/rti-mask-reuse')
    rows = analyse(name, scr)
    print('n\tkind\tlevel\tsite\ttext\tresume\tlive\tdirty\tpid\tprev_pid')
    for n, mn, ln, txt, res, live, dirty, lvl, pid, ppid, rawd, nx, lgk, lgn, hh in rows:
        print('%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s' % (n, mn, lvl, ln, txt, res, prog.fmt(live), prog.fmt(dirty), '' if pid is None else pid, '' if ppid is None else ppid))
    print('%s: %d events' % (name, len(rows)), file=sys.stderr)
