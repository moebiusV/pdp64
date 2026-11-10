"""Writes the assembled-program tests of the prefix-coded encodings: tests/asm (NAME.s, NAME.words).

The expected parcels are not as64's: they come from the Python prototype of the encoding (enc.py, scheme.py: choose the shortest form, relax against real
distances, pack the bits), built from spec/pdp64-NN/pdp64-NN.hbnf, applied to the parser of the prototype (fit/m2.py).  Unresolved externals are 0 in the
object (the linker fills them).  Run it after a change to the forms; the result is checked in.

    python3 mk_asm_tests.py
"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from variants import *
import enc
from enc import *
import importlib.util
spec = importlib.util.spec_from_file_location('chk', os.path.join(HERE, '..', '..', '..', 'tools', 'check-enc.py'))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
ROOT = os.path.join(HERE, '..', '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import encgram
FZ = ('movcall', 'popmret', 'popret', 'mov2')

COMMON = {
'basic': ('', """\t.text
start:\tmovq r1,r2
\tmovq #5,r3
\tmovq #300,r4
\tmovq #70000,r5
\tmovq 8(sp),r6
\tmovq r6,16(sp)
\tmovq (r2),r3
\tmovl 4(r3),r1
\tmovb r1,(r2)
\tmovzb 1(r8),r2
\tlea 32(sp),r1
\tlea start,r2
\tadd r1,r2
\tsub #1,r2
\tand #255,r3
\tshl #3,r4
\txor r8,r9
\tcmp r1,r2
\tcmp r5,#7
\tpush r2
\tpop r3
\tinc r1
\tclr r2
\ttst r3
\tneg r4
\tadd #16,sp
\tsub #4096,sp
\tmovq 100000(r1),r2
\tmovl r2,-20(r3)
\tret
"""),
'branch': ('', """\t.text
a:\tcbeq r1,#0,z
\tcbne r1,r2,a
\tcblt r3,#100,z
\tcbge r1,#-3,a
\tcbhi r2,#5000,z
\tcbeq r1,#40000,z
\tcbcc r1,#7,a
\tbeq a
\tbne z
\tbr z
\tbcs a
\tbge z
\t.space 300
\tbcs a
\tbr a
z:\tret
"""),
'far': ('', """\t.text
a:\tcbeq r1,#0,z
\tcbne r1,r2,z
\tcbeq r1,#100000,z
\tcbpl r1,#0,z
\tbr z
\tbeq z
\t.space 70000
z:\tret
"""),
'extern': ('', """\t.text
\tcall printf
\tbr printf
\tlea buf,r1
\tmovq buf,r2
\tmovq r1,buf
\tmovq @1000,r3
\tmovq @abs,r3
\tcall printf
\tcbeq r1,#0,printf
\tret
"""),
'modes': ('', """\t.text
\tmovq 8(r1)(r2*8),r3
\tmovq (r1)(r2),r3
\tmovq r3,16(r1)(r2*4)
\tmovq (r4)+,r5
\tmovq r5,-(r4)
\tmovb (r6)+1,r2
\tadd d,r1
\tmovq r1,d
\tjmp (r3)
\tjmp r4
\tcall r5
\tcalli 8(r2)
\tjtag 8(r1)(r2*8)
\tjmp lab
lab:\tret
d:\t.quad 1
"""),
'misc': ('', """\t.text
\tmovql #0x123456789abcdef0,r1
\trori32 r1,#5,r2
\trol r1,#3,r2
\tclz r1,r2
\tdiv r1,r2,r3
\tfmadd r1,r2,r3,r4
\textb r1,#4,#8,r2
\tdshr r1,r2,#3,r4
\txadd r1,r2,r3
\tcas r1,r2,r3,r4
\tmaskeqz r1,r2,r3
\tbsel r1,r2,r3,r4
\taesks1 r1,#3,r2
\tnop
\thalt
\tpushm #0x8F00
\tpopm #0x0100
\tsob r1,lb
lb:\tbtag r1,#2,lb
\tmovub 8(r3),r2
\taddm r1,16(r2)
\tmovq.u 8(r1),r2
\tmovb.d (r3),r4
\tfcmp r1,r2
\tfadd r2,r3
\tmul #6,r1
\tshr #40,r2
\tsar r3,r4
\tmulh r1,r2
\tret
"""),
'fused': ('', """\t.text
f:\tmovcall r1,r2,g
\tadd r1,r2
\tmovcall r8,r3,f
\tmov2 r1,r2,r3,r8
\tmov2 r9,r10,r0,r2
\tmov2 r3,r2,r9,r10
\tpopm #0x0300
\tpopmret #0x0300
\tpopret r3
g:\tpopret r12
\tmovcall r5,r6,printf
\tret
""")
}
EXTRA32 = {
'regs32': ('', """\t.text
\tmovq r17,r20
\tadd r31,r30
\tmovq 8(r24),r25
\tmovq r26,16(sp)
\tmovq (r16)(r31*8),r18
\tpushm #0xFF000000
\tpopm #-16740608
\tlea 8(r28),r29
\tcbeq r19,#0,x
\tcbne r30,r31,x
\txor r27,r26
x:\tret
"""),
}

def run(which):
    d = encgram.load(ROOT)
    forms = [Form(f['name'], f['n'], f['mns'], [chk.mkspec(s) for s in f['specs']], xbits=f['xbits']) for f in d['forms']]
    sc = Scheme(forms)
    enc.RELOC = 'max'
    outdir = os.path.join(ROOT, 'tests', 'asm')
    progs = dict(COMMON)
    if which == '32': progs.update(EXTRA32)
    for name, (flags, src) in sorted(progs.items()):
        fn = os.path.join(outdir, name + '.s')
        open(fn, 'w').write(src)
        ev, recs = __import__('m2').parse(fn)
        total = layout(ev, sc.lenfun)
        words = []
        for e in ev:
            if e[0] == 'D':
                assert e[1] == '.space' or e[1] == '.quad', e
                if e[1] == '.space': words += [0] * (int(e[2][0]) // 2)
                continue
            if e[0] != 'I': continue
            r = e[1]
            mn, ops = inst_of(r, r['dist'])
            p = sc.plan(mn, ops)
            assert p is not None, (name, mn, ops)
            for m, o in p:
                f, vals = sc.choose(m, o)
                o0 = tuple((x[0], 0) + x[2:] if (x[0] in ('PC', 'A') and x[1] is None) else x for x in o)
                v0 = f.fit(m, o0)
                lf = next(l for l in sc.code.leaves if l.form is f and m in l.mns)
                words += words_of(build_word(lf, m, v0), f.n)
        # data (.quad) in the text is not modelled: the `modes` program ends with it
        if name == 'modes': words += [1, 0, 0, 0]
        txt = ['%04x' % w for w in words]
        # a long run of zero parcels is written `...`, and the number of parcels is NAME.total
        i = 0; out = []; longrun = None
        while i < len(txt):
            j = i
            while j < len(txt) and txt[j] == '0000': j += 1
            if j - i >= 64 and longrun is None: longrun = (i, j); out.append('...'); i = j
            else: out.append(txt[i]); i += 1
        open(os.path.join(outdir, name + '.words'), 'w').write(' '.join(out) + '\n')
        if longrun: open(os.path.join(outdir, name + '.total'), 'w').write('%d\n' % len(txt))
        elif os.path.exists(os.path.join(outdir, name + '.total')): os.remove(os.path.join(outdir, name + '.total'))
        print(which, name, len(words), 'parcels')
run('32')
