import re, sys, os, json, collections
sys.dont_write_bytecode=True
REG=r'(?:r\d+|sp|fp)'
rreg=re.compile('^'+REG+'$')
base_re=re.compile(r'^(-?\d+)?\(('+REG+r')\)$')
index_re=re.compile(r'^(-?\d+)?\(('+REG+r')\)\(('+REG+r')(?:\*(\d))?\)$')
postinc=re.compile(r'^\(('+REG+r')\)\+(-?\d+)?$')
predec=re.compile(r'^-\(('+REG+r')\)$|^\(('+REG+r')\)-(\d+)$')
SIZE={'movq':8,'movl':4,'movw':2,'movb':1,'movzl':4,'movzw':2,'movzb':1,'lea':1,'jmp':1,'call':1}
MOVS=('movq','movl','movw','movb','movzl','movzw','movzb')
def sg(v,b): return -(1<<(b-1))<=v<(1<<(b-1))
def litb(v):
    for b in (2,4,6,8):
        if sg(v,8*b): return b
    return 8
ESC4=set('clz ctz clo cto popcnt bswap bswapw bswapl bitrev utf8len utf8dec utf8enc ror xnorpop clmull clmulh rori rori32 mcpy mmov mset mcmp mscn mscnn mval div divu mod modu mulhu abs min minu max maxu set fdiv fsqrt fadd32 fsub32 fmul32 fdiv32 fsqrt32 fcmp32 fneg fabs fcopysign fmin fmax fclass fclass32 frint frintz frintm frintp frinta fcvtdq fcvtqd fcvtds fcvtsd fcvtsl fcvtls fcvtdqu fcvtqud fsflags fadd16 fsub16 fmul16 fdiv16 fsqrt16 fcmp16 fclass16 fcvtsh fcvths fcvtdh fcvthd fcvthl fcvtlh fmadd fmsub fnmadd fnmsub fmadd32 fmsub32 fnmadd32 fnmsub32 fmadd16 fmsub16 fnmadd16 fnmsub16 prober probew mfsr mtsr trapl'.split())
BF6=set('dshr extb extzb insb'.split())
def kind(o):
    if rreg.match(o): return 'reg'
    if o.startswith('#'): return 'imm'
    if o.startswith('@'): return 'abs'
    if index_re.match(o): return 'index'
    if base_re.match(o): return 'base'
    if postinc.match(o): return 'postinc'
    if predec.match(o): return 'predec'
    return 'pcrel'
def isbr(mn): return mn=='br' or (mn.startswith('b') and mn not in('bic','bit','bis','btag','bntag') and len(mn)<=4)
def splitops(s):
    out,depth,cur=[],0,''
    for ch in s:
        if ch=='(':depth+=1
        elif ch==')':depth-=1
        if ch==',' and depth==0: out.append(cur);cur=''
        else: cur+=ch
    if cur.strip(): out.append(cur)
    return [x.strip() for x in out]
def parse(path):
    """events: ('L',name) ('D',w,ops) ('I',rec)"""
    ev=[]; sec='text'; func=None; recs=[]
    for line in open(path,errors='replace'):
        line=line.split(';')[0].strip()
        while True:
            m=re.match(r'^("[^"]*"|[A-Za-z_.$][\w.$]*|\d+):\s*(.*)$',line)
            if not m: break
            lab=m.group(1); line=m.group(2).strip()
            if sec=='text':
                ev.append(('L',lab))
                if not lab.startswith('.L') and not lab.isdigit(): func=lab
        if not line: continue
        if line.startswith('.'):
            w=line.split()[0]; rest=line[len(w):].strip()
            if sec=='text' and w in('.byte','.word','.long','.quad','.space','.even','.align','.ascii'):
                ev.append(('D',w,splitops(rest) if rest else [])); continue
            if w=='.text': sec='text'
            elif w in('.data','.bss'): sec='data'
            elif w=='.section': sec='text' if '.text' in line else 'data'
            continue
        if sec!='text': continue
        w=line.split(None,1); mn=w[0]; ops=splitops(w[1]) if len(w)>1 else []
        k=[kind(o) for o in ops]
        r=dict(mn=mn,ops=ops,k=k,func=func,lab=None)
        r['off']=0; r['pool']=False
        for i,o in enumerate(ops):
            if k[i]=='pcrel':
                if o.startswith('='): r['pool']=True
                else:
                    mm=re.match(r'^(.*?)([+-]\d+)?$',o)
                    r['lab']=mm.group(1); r['off']=int(mm.group(2) or 0)
        recs.append(r); ev.append(('I',r))
    return ev,recs
def _adv(pos,e):
    w,ops=e[1],e[2]
    if w=='.even': return pos+(pos&1)
    if w=='.align': return pos+(-pos)%int(ops[0])
    if w=='.space': return pos+int(ops[0])
    if w=='.ascii': return pos+sum(len(bytes(x.strip().strip('"'),'utf-8').decode('unicode_escape')) for x in ops)
    return pos+{'.byte':1,'.word':2,'.long':4,'.quad':8}[w]*len(ops)
def layout(ev,lenfun):
    labset={e[1] for e in ev if e[0]=='L'}
    recs=[e[1] for e in ev if e[0]=='I']
    for r in recs: r['len']=lenfun(r,0 if r['lab'] in labset else None)
    while True:
        pos=0; labels={}; ch=False
        for e in ev:
            if e[0]=='L': labels[e[1]]=pos
            elif e[0]=='D': pos=_adv(pos,e)
            else: e[1]['pos']=pos; pos+=e[1]['len']
        for r in recs:
            d=labels[r['lab']]-r['pos']+r['off'] if r['lab'] in labset else None
            r['dist']=d
            n=lenfun(r,d)
            if n>r['len']: r['len']=n; ch=True
        if not ch: break
    return sum(r['len'] for r in recs)
