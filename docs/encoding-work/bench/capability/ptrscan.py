#!/usr/bin/env python3
"""ptrscan.py CMD...: run CMD as a child, stop it after DELAY seconds (env, default 2), read its writable private mappings from /proc/PID/mem and count the
8-byte-aligned words that look like pointers: the value lies inside a mapped region of the process (any mapping), is not tiny.  Zero words are counted apart
(a null pointer cannot be told from the integer 0, so the pointer fraction is a LOWER bound).  Output: words, zero words, pointer words, pointer fraction of all words
and of non-zero words.  Host: Linux x86-64 LP64 = the pdp64's data model (LP64, 8-byte pointers) as a proxy for the layout of real programs' memory."""
import os, sys, time, signal, subprocess, re, struct, json
def maps(pid):
    r = []
    for l in open('/proc/%d/maps' % pid):
        m = re.match(r'([0-9a-f]+)-([0-9a-f]+) (\S+) \S+ \S+ \S+\s*(.*)', l)
        r.append((int(m.group(1), 16), int(m.group(2), 16), m.group(3), m.group(4)))
    return r
def scan(pid):
    mp = maps(pid); regions = [(a, b) for a, b, p, n in mp]
    import bisect
    starts = [a for a, b in regions]
    def mapped(v):
        i = bisect.bisect_right(starts, v) - 1
        return i >= 0 and v < regions[i][1]
    tot = zero = ptr = 0; byk = {}
    with open('/proc/%d/mem' % pid, 'rb', 0) as f:
        for a, b, p, n in mp:
            if not (p.startswith('rw') and p[3] == 'p') or n in ('[vvar]', '[vsyscall]', '[vdso]') or n.startswith('/dev'): continue
            kind = 'heap' if n == '[heap]' else 'stack' if n == '[stack]' else 'file-data' if n else 'anon'
            try:
                f.seek(a); buf = f.read(b - a)
            except Exception: continue
            n8 = len(buf) // 8
            ws = struct.unpack('<%dQ' % n8, buf[:n8 * 8])
            z = ws.count(0); pc = sum(1 for v in ws if v > 0xffff and mapped(v))
            tot += n8; zero += z; ptr += pc
            k = byk.setdefault(kind, [0, 0, 0]); k[0] += n8; k[1] += z; k[2] += pc
    return tot, zero, ptr, byk
if __name__ == '__main__':
    p = subprocess.Popen(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    time.sleep(float(os.environ.get('DELAY', '2')))
    if p.poll() is not None: sys.exit('exited before the scan')
    os.kill(p.pid, signal.SIGSTOP); time.sleep(0.1)
    tot, zero, ptr, byk = scan(p.pid)
    p.kill()
    print(json.dumps(dict(cmd=' '.join(sys.argv[1:])[:70], words=tot, zero=zero, ptr=ptr, ptr_frac=round(ptr / tot, 4), ptr_of_nonzero=round(ptr / max(1, tot - zero), 4), bykind={k: v for k, v in byk.items()})))
