#!/usr/bin/env python3
"""vecreport.py FREQ.TSV -- the class shares of vsurvey-class.py as a markdown table, one column for each (ISA, project, kind) group."""
import sys, collections
sys.path.insert(0, __import__('os').path.dirname(__file__))
import importlib; V = importlib.import_module("vsurvey-class")
rows = V.classify(V.load(sys.argv[1]))
GROUPS = [
 ('x86 asm: dav1d', lambda i,p,k: (i,p,k)==('x86','dav1d','asm')),
 ('x86 asm: FFmpeg', lambda i,p,k: (i,p,k)==('x86','FFmpeg','asm')),
 ('x86 asm: jpeg-turbo', lambda i,p,k: (i,p,k)==('x86','libjpeg-turbo','asm')),
 ('x86 intr: ggml', lambda i,p,k: (i,p,k)==('x86','ggml','intr')),
 ('x86 intr: libyuv', lambda i,p,k: (i,p,k)==('x86','libyuv','intr')),
 ('x86 intr: OpenBLAS', lambda i,p,k: (i,p,k)==('x86','OpenBLAS','intr')),
 ('NEON asm: dav1d', lambda i,p,k: (i,p,k)==('neon','dav1d','asm')),
 ('NEON asm: FFmpeg', lambda i,p,k: (i,p,k)==('neon','FFmpeg','asm')),
 ('NEON asm: OpenBLAS', lambda i,p,k: (i,p,k)==('neon','OpenBLAS','asm')),
 ('NEON intr: ggml', lambda i,p,k: (i,p,k)==('neon','ggml','intr')),
 ('NEON intr: libyuv', lambda i,p,k: (i,p,k)==('neon','libyuv','intr')),
 ('NEON intr: jpeg-turbo', lambda i,p,k: (i,p,k)==('neon','libjpeg-turbo','intr')),
 ('RVV asm: dav1d', lambda i,p,k: (i,p,k)==('rvv','dav1d','asm')),
 ('RVV asm: FFmpeg', lambda i,p,k: (i,p,k)==('rvv','FFmpeg','asm')),
 ('RVV intr: OpenBLAS', lambda i,p,k: (i,p,k)==('rvv','OpenBLAS','intr')),
 ('RVV intr: ggml', lambda i,p,k: (i,p,k)==('rvv','ggml','intr')),
 ('LSX/LASX asm: dav1d', lambda i,p,k: (i,p,k)==('lsx','dav1d','asm')),
 ('LSX/LASX asm: FFmpeg', lambda i,p,k: (i,p,k)==('lsx','FFmpeg','asm')),
 ('LSX/LASX intr: FFmpeg', lambda i,p,k: i in('lsx','lasx') and p=='FFmpeg' and k=='intr'),
 ('MSA intr: FFmpeg', lambda i,p,k: (i,p,k)==('msa','FFmpeg','intr')),
 ('VSX intr: FFmpeg', lambda i,p,k: (i,p,k)==('ppc','FFmpeg','intr')),
 ('VSX intr: OpenBLAS', lambda i,p,k: (i,p,k)==('ppc','OpenBLAS','intr')),
]
CL = ['ld','seg','gath','mv','add','sat','avg','abd','sad','mm','mul','mulh','mulw','madd','mac','macw','dot','fma','fp','sh','shr','shn','nar','wid','wadd','logic','sel','cmp','mask','perm','tbl','red','bits','cvt','mma','cfg','oth']
tab = {}
for name, f in GROUPS:
    c = collections.Counter()
    for i,p,k,t,n,fl,cl in rows:
        if f(i,p,k) and cl not in ('scalar','free'):
            c[cl] += n
    tab[name] = c
pm = '--pm' in sys.argv
print('| class | ' + ' | '.join(g[0] for g in GROUPS) + ' |')
print('|---|' + '---:|' * len(GROUPS))
tot = {g: sum(tab[g].values()) for g, _ in GROUPS}
print('| **vector instructions counted** | ' + ' | '.join('%d' % tot[g] for g, _ in GROUPS) + ' |')
for cl in CL:
    print('| %s | ' % cl + ' | '.join(('%.1f' % (100.0 * tab[g][cl] / tot[g]) if tot[g] else '') for g, _ in GROUPS) + ' |')
