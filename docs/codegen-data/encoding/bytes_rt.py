import sys,struct,collections
sys.path.insert(0,'.')
from variants import *
import scheme
sc,_=build('base16',reloc='max')
corp=corpus('base16'); n=0; bad=0; nbytes=0
for fn,ev,recs in corp:
    layout(ev,sc.lenfun)
    plans=[]; ctr=[0]
    for r in recs:
        mn,ops=inst_of(r,r['dist']); plans+=sc.plan(mn,ops)
    e=scheme.encode_stream(sc,plans,ctr)
    blob=b''.join(struct.pack('<H',w) for mn,o,ws in e for w in ws)
    nbytes+=len(blob)
    # decode purely from the byte string
    off=0; j=0
    while off<len(blob):
        p0=struct.unpack_from('<H',blob,off)[0]
        lf=sc.code.table[p0]; k=lf.form.n
        par=list(struct.unpack_from('<%dH'%k,blob,off))
        d=decode_word(sc.code,par); mn,nops,ws=e[j]
        n+=1
        if d is None or d[0]!=mn or d[1]!=tuple(o[:2] if o[0]=='PC' else o for o in nops): bad+=1
        off+=2*k; j+=1
    assert j==len(e)
print('byte-level (little-endian) decode of',n,'instructions,',nbytes,'bytes; failures',bad)
