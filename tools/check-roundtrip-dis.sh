#!/bin/sh
# One word names the operation, and the disassembler prints the operation, never the length: the text of tools/encdis -a, assembled again, is the same bytes.
# For the .text of every test program (tests/asm, tests/sim, tests/qemu, tests/ld and the snippets of the hypervisor text): assemble (as64 --no-relax), write the parcels of the
# .text as source with `encdis -a -r`, assemble that, and compare.  An instruction that no spelling reproduces (the second encoding of trap, `set`, `mfsr`, `mtsr`,
# data in the text) is a `.word`; the totals are printed, and a difference in the bytes fails.
set -u
cd "$(dirname "$0")/.."
B=${BUILD:-build}
tools/build-as64.sh > /dev/null; tools/build-sim64.sh > /dev/null
gcc -w -Icommon -I"$B" -o "$B/encdis" tools/encdis.c common/pdp64enc.c "$B/pdp64-tab.c" || exit 1
W=$B/rtdis; mkdir -p "$W"
python3 - "$@" <<'PY'
import glob, os, struct, subprocess, sys
B = os.environ.get('BUILD', 'build'); W = B + '/rtdis'
def text(obj):
    d = open(obj, 'rb').read()
    if struct.unpack_from('<H', d, 0x10)[0] == 2:				# a linked program: the executable segment
        phoff = struct.unpack_from('<Q', d, 0x20)[0]; phnum = struct.unpack_from('<H', d, 0x38)[0]
        for i in range(phnum):
            typ, fl, off, va, pa, fsz = struct.unpack_from('<IIQQQQ', d, phoff + 56 * i)
            if typ == 1 and fl & 1: return d[off:off + fsz]
        return b''
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
    return d[off:off + size]
def text_obj(obj):
    d = open(obj, 'rb').read()
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    off, size = struct.unpack_from('<QQ', d, shoff + 64 + 24)
    return d[off:off + size]
srcs = sorted(glob.glob('tests/asm/*.s') + glob.glob('tests/sim/*.s') + glob.glob('tests/sim/*.S') + glob.glob('tests/qemu/*.s') + glob.glob('tests/qemu/*.S') +
              glob.glob('tests/ld/*.s') + glob.glob('docs/encoding-work/hypervisor-text-v3-snippets/*.S') + glob.glob('docs/encoding-work/colour-snippets/*.S'))
n = ok = skipped = 0; tot = [0, 0, 0]; bad = []
for s in srcs:
    src = s
    if s.endswith('.S'):
        src = W + '/pp.s'
        if subprocess.run(['tools/pp-asm.sh', s, src], capture_output=True).returncode: skipped += 1; continue
    r = subprocess.run([B + '/as64', '--no-relax', '-o', W + '/a.o', src], capture_output=True)
    if r.returncode: skipped += 1; continue
    obj = W + '/a.o'
    if subprocess.run([B + '/ld64', '--no-relax', '-o', W + '/a.x', W + '/a.o'], capture_output=True).returncode == 0: obj = W + '/a.x'
    t = text(obj)
    if not t: continue
    open(W + '/a.bin', 'wb').write(t)
    r = subprocess.run([B + '/encdis', '-a', '-r', W + '/a.bin'], capture_output=True, text=True)
    open(W + '/b.s', 'w').write(r.stdout)
    for tok, i in zip(('instructions', 'written with', 'as'), range(3)):
        pass
    import re
    m = re.search(r'(\d+) instructions, (\d+) written with .encode, (\d+) as .word', r.stderr)
    if m: tot = [a + int(b) for a, b in zip(tot, m.groups())]
    r2 = subprocess.run([B + '/as64', '--no-relax', '-o', W + '/b.o', W + '/b.s'], capture_output=True, text=True)
    n += 1
    u = text(W + '/b.o') if r2.returncode == 0 else None
    if obj.endswith('.x'): u = text_obj(W + '/b.o') if r2.returncode == 0 else None
    if r2.returncode or u != t:
        bad.append((s, (r2.stderr.strip().split('\n') or [''])[0])); continue
    ok += 1
for s, e in bad: print('DIFF %s: %s' % (s, e))
print('roundtrip-dis: %d programs, %d reproduced from the disassembly; %d instructions, %d written with .encode, %d as .word; %d not assembled (skipped)' % (n, ok, tot[0], tot[1], tot[2], skipped))
sys.exit(1 if bad else 0)
PY
