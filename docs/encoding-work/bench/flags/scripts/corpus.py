#!/usr/bin/env python3
# corpus.py: compile every source with a given compiler variant; write .s files and a result table.
# usage: corpus.py LABEL pcc CCOM | corpus.py LABEL llvm
import os, sys, subprocess, glob, json, re
from concurrent.futures import ThreadPoolExecutor
W = '/tmp/flags-work'
OB = '/home/matthew/claude/openbsd-src'
AS = '/tmp/flags-pdp64/build/as64'
PD = '/tmp/flags-pdp64'
LLC = '/home/matthew/claude/llvm-build-22/bin/llc'
CPPF = ['-E','-P','-undef','-nostdinc','-D__pcc__','-D__LP64__','-D_LP64','-I'+W+'/inc','-I'+OB+'/sys','-isystem',OB+'/include',
        '-idirafter',OB+'/lib/libc/include','-idirafter',OB+'/lib/libc/hidden','-idirafter',OB+'/sys/lib/libkern','-I'+OB+'/lib/libcrypto','-I'+OB+'/lib/libcrypto/bn','-I'+OB+'/lib/libm/src','-I'+OB+'/lib/libc/gdtoa','-idirafter',W+'/inc2','-include',W+'/prelude.h','-w']
CLANGF = ['-std=gnu89', '-DDEF_STRONG(x)=', '-DDEF_WEAK(x)=', '-DDEF_BUILTIN(x)=', '-DDEF_STRONG(x)=', '-S','-emit-llvm','-O2','-m64','-fno-builtin','-ffreestanding','-fno-stack-protector','-mlong-double-64','-mno-sse','-mno-mmx','-fno-vectorize','-fno-slp-vectorize','-fno-unroll-loops','-w',
          '-I'+W+'/inc','-I'+OB+'/sys','-isystem',OB+'/include','-idirafter',OB+'/lib/libc/include','-idirafter',OB+'/lib/libc/hidden','-idirafter',OB+'/sys/lib/libkern','-I'+OB+'/lib/libcrypto','-I'+OB+'/lib/libcrypto/bn','-I'+OB+'/lib/libm/src']

def sources():
    out = []   # (group, path)
    for p in sorted(glob.glob(OB+'/lib/libz/*.c')): out.append(('libz', p))
    for d in ['string','stdlib','gen','stdio','net','hash']:
        for p in sorted(glob.glob(OB+'/lib/libc/%s/*.c' % d)): out.append(('libc-'+d, p))
    for p in sorted(glob.glob(OB+'/sys/crypto/*.c')): out.append(('sys-crypto', p))
    EXT = [('libc-regex','lib/libc/regex'),('libc-db','lib/libc/db/btree'),('libc-db','lib/libc/db/hash'),('libc-db','lib/libc/db/recno'),('libc-db','lib/libc/db/mpool'),
           ('libc-gdtoa','lib/libc/gdtoa'),('libc-time','lib/libc/time'),('libc-crypt','lib/libc/crypt'),('libc-locale','lib/libc/locale'),('libc-quad','lib/libc/quad'),
           ('libc-softfloat','lib/libc/softfloat'),('libedit','lib/libedit'),('libcurses','lib/libcurses/tinfo'),('libm','lib/libm/src'),
           ('ub-awk','usr.bin/awk'),('ub-lex','usr.bin/lex'),('ub-yacc','usr.bin/yacc'),('ub-sort','usr.bin/sort'),('ub-bc','usr.bin/bc'),('ub-dc','usr.bin/dc'),('ub-diff','usr.bin/diff'),
           ('ub-sed','usr.bin/sed'),('ub-grep','usr.bin/grep'),('ub-m4','usr.bin/m4'),('ub-cmp','usr.bin/cmp'),('ub-tsort','usr.bin/tsort'),
           ('libcrypto','lib/libcrypto/aes'),('libcrypto','lib/libcrypto/bn'),('libcrypto','lib/libcrypto/md5'),('libcrypto','lib/libcrypto/sha'),('libcrypto','lib/libcrypto/des'),
           ('libcrypto','lib/libcrypto/bf'),('libcrypto','lib/libcrypto/chacha'),('libcrypto','lib/libcrypto/curve25519'),('libcrypto','lib/libcrypto/rc4')]
    if os.environ.get('CORPUS_EXT', '1') == '1':
        for g, d in EXT:
            for p in sorted(glob.glob(OB + '/' + d + '/*.c')): out.append((g, p))
    for p in sorted(glob.glob(PD+'/tests/c/*.c')): out.append(('tests-c', p))
    for p in sorted(glob.glob(PD+'/tests/c-new/*.c')): out.append(('tests-c-new', p))
    for p in sorted(glob.glob('/home/matthew/claude/pdp64/docs/encoding-work/bench/sc/src/*.c')): out.append(('bench-sc', p))
    return out

EXTRA = os.environ.get('CCOM_EXTRA', '').split()
ENV = dict(os.environ)
def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=300, **kw)

def one(args):
    label, kind, ccom, group, path = args
    name = group + '__' + os.path.basename(path)[:-2]
    d = W + '/out/' + label
    s = d + '/' + name + '.s'
    res = dict(name=name, group=group, path=path)
    try:
        if kind == 'pcc':
            r = run(['gcc'] + CPPF + ['-I' + os.path.dirname(path), '-idirafter', os.path.dirname(path) + '/..', path])
            if r.returncode: res['fail'] = 'cpp: ' + r.stderr.strip().split('\n')[0][:150]; return res
            i = d + '/' + name + '.i'
            open(i, 'w').write(r.stdout)
            r = run([ccom, '-m', 'pdp64/32'] + EXTRA + [i, s], env=ENV)
            os.unlink(i)
            if 'NF ' in r.stderr: open(d + '/' + name + '.nflog', 'w').write(''.join(l+'\n' for l in r.stderr.split('\n') if l.startswith('NF ')))
            if r.returncode or not os.path.exists(s) or os.path.getsize(s) == 0:
                res['fail'] = 'ccom: ' + (r.stderr.strip().split('\n')[0][:150] or 'rc%d' % r.returncode); 
                if os.path.exists(s): os.unlink(s)
                return res
        else:
            ll = d + '/' + name + '.ll'
            r = run(['clang'] + CLANGF + ['-I' + os.path.dirname(path), '-idirafter', os.path.dirname(path) + '/..', path, '-o', ll])
            if r.returncode: res['fail'] = 'clang: ' + (r.stderr.strip().split('\n')[0][:150]); return res
            t = open(ll).read()
            t = re.sub(r'^target (datalayout|triple) = .*\n', '', t, flags=re.M)
            t = re.sub(r' "(target-cpu|target-features|tune-cpu)"="[^"]*"', '', t)
            open(ll, 'w').write(t)
            r = run([LLC, '-mtriple=pdp64-unknown-elf', '-O2', ll, '-o', s])
            os.unlink(ll)
            if r.returncode: res['fail'] = 'llc: ' + (r.stderr.strip().split('\n')[0][:150]); return res
        for mode, flag in (('plain', ['--no-relax']), ('relax', [])):
            o = d + '/' + name + '.' + mode + '.o'
            r = run([AS] + flag + ['--stats', '-o', o, s])
            if r.returncode: res['fail'] = 'as64: ' + (r.stderr.strip().split('\n')[0][:150]); return res
            m = re.search(r'(\d+) instructions, (\d+) bytes', r.stdout + r.stderr)
            res[mode + '_insn'] = int(m.group(1)); res[mode + '_bytes'] = int(m.group(2))
            if mode == 'plain': res['stats_text'] = (r.stdout + r.stderr).strip()
        # histogram of mnemonics
        h = {}
        for line in open(s):
            line = line.split(';')[0].rstrip()
            if not line.strip() or line.lstrip().startswith('.'): continue
            if not line or line[0] not in ' \t': 
                m = re.match(r'^[A-Za-z_.$][\w.$]*:\s*(.*)$', line)
                line = m.group(1) if m else ''
            m = re.match(r'^\s*([a-z][a-z0-9.]*)\b', line)
            if m and not line.lstrip().startswith('.'): h[m.group(1)] = h.get(m.group(1), 0) + 1
        res['hist'] = h
    except subprocess.TimeoutExpired:
        res['fail'] = 'timeout'
    return res

if __name__ == '__main__':
    label, kind = sys.argv[1], sys.argv[2]
    ccom = sys.argv[3] if kind == 'pcc' else None
    os.makedirs(W + '/out/' + label, exist_ok=True)
    with ThreadPoolExecutor(10) as ex:
        results = list(ex.map(one, [(label, kind, ccom, g, p) for g, p in sources()]))
    json.dump(results, open(W + '/out/' + label + '.json', 'w'))
    ok = [r for r in results if 'fail' not in r]
    print(label, 'ok', len(ok), 'of', len(results), 'insn', sum(r['plain_insn'] for r in ok), 'bytes', sum(r['plain_bytes'] for r in ok))
