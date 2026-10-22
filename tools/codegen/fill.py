import json, csv, re, glob, collections, os, shutil
A='/tmp/p64opt/analysis/'
T=json.load(open('/tmp/p64opt/mdtables.json'))
J=json.load(open('/tmp/p64opt/analysis.json'))
res=json.load(open('/tmp/p64opt/final/results.json'))
by=collections.defaultdict(dict)
for x in res:
    if 'ins' in x: by[x['src']][x['arch']]=x
fair={s:v for s,v in by.items() if all(a in v for a in ('pdp64','amd64','gcc-Os','clang-Os'))}
def tot(f):
    ss=[s for s in fair if f(s)]
    return {a:(sum(fair[s][a]['ins'] for s in ss),sum(fair[s][a]['image'] for s in ss)) for a in ('pdp64','amd64','gcc-Os','clang-Os')}
V={}
def ratios(prefix,t):
    p=t['pdp64']
    V[prefix+'_gi']='%.2f'%(p[0]/t['gcc-Os'][0]); V[prefix+'_gb']='%.2f'%(p[1]/t['gcc-Os'][1])
    V[prefix+'_ci']='%.2f'%(p[0]/t['clang-Os'][0]); V[prefix+'_cb']='%.2f'%(p[1]/t['clang-Os'][1])
ratios('r_all',tot(lambda s:True))
ratios('r_nm',tot(lambda s:'memcpy-a2' not in s))
ratios('r_lib',tot(lambda s:fair[s]['pdp64']['corp'] not in('c-testsuite','gcc-torture')))
t=tot(lambda s:True)
V['final_ins']=t['pdp64'][0]; V['final_bytes']=t['pdp64'][1]
V['final_gb']='%.3f'%(t['pdp64'][1]/t['gcc-Os'][1]); V['final_cb']='%.3f'%(t['pdp64'][1]/t['clang-Os'][1])
img_total=t['pdp64'][1]
# lengths
H=J['pdp64_len']; V['len_total_pdp64']=H['n']; V['len_bytes_pdp64']=H['bytes']; V['len_avg_pdp64']='%.2f'%H['avg']
V['len_avg_gcc']='%.2f'%J['gcc-Os_len']['avg']; V['len_avg_clang']='%.2f'%J['clang-Os_len']['avg']
G=J['gcc-Os_len']; K=J['clang-Os_len']
rows=''
for b in range(1,13):
    g=G['hist'].get(str(b),0); k=K['hist'].get(str(b),0)
    rows+='| %d | %d | %.1f%% | %d | %.1f%% |\n'%(b,g,100*g/G['n'],k,100*k/K['n'])
V['len_x86_rows']=rows.rstrip('\n')
V['len_pdp64']=T['len_pdp64']
U=list(csv.reader(open(A+'instructions_used.csv')))[1:]
used=[r for r in U if int(r[2])>0]
V['used_count']=len(used); V['unused_count']=len(U)-len(used)
for k in ('totals','mnem','shapes_pdp64','pairs','pairs_gcc','bigrams','trigrams','longs','cost','cand','used','never'):
    V[k]=T[k]
V['mnem']=T['mnem']
# shapes x86 rows
def rd(n): return list(csv.reader(open(A+n+'.csv')))[1:]
g=dict((r[0],r) for r in rd('shapes_gcc-Os')); k=dict((r[0],r) for r in rd('shapes_clang-Os'))
rows=''
for f in ('reg','imm','mem-base','mem-index','rip','target','sym'):
    gr=g.get(f,[f,0,'0']); kr=k.get(f,[f,0,'0'])
    rows+='| %s | %s | %s%% | %s | %s%% |\n'%(f,gr[1],gr[2],kr[1],kr[2])
V['shapes_x86_rows']=rows.rstrip('\n')
# pdp64 six-byte numbers
S=dict((r[0],r) for r in rd('shapes_pdp64'))
six_pcrel=int(S['pcrel'][4]); six_all=H['hist']['6']
L=dict((r[0].replace('"','').split(' ',1)[0]+' '+r[0].replace('"','').split(' ',1)[1] if ' ' in r[0] else r[0], int(r[1])) for r in rd('long_forms_pdp64'))
def lg(prefix):
    return sum(int(r[1]) for r in rd('long_forms_pdp64') if r[0].replace('"','').split()[:2]==prefix)
V['six_pcrel']=six_pcrel; V['six_all']=six_all
V['six_call']=sum(int(r[1]) for r in rd('long_forms_pdp64') if r[0].replace('"','').startswith('6 call'))
V['six_lea']=sum(int(r[1]) for r in rd('long_forms_pdp64') if r[0].replace('"','').startswith('6 lea pcrel'))
V['xsec_n']=six_pcrel; V['xsec_extra']=2*six_pcrel; V['xsec_pct']='%.1f%%'%(100*2*six_pcrel/img_total)
# cost centre
C={r[0]:r for r in rd('costcentres_pdp64')}
V['frame_pct']='%.1f%%'%(float(C['frame'][4])+float(C['ret'][4]))
V['reext_pct']='%.1f%%'%float(C['re-extension'][4])
V['const_pct']='%.1f%%'%float(C['constant'][4]); V['cmp_pct']='%.1f%%'%float(C['compare'][4]); V['br_pct']='%.1f%%'%float(C['branch'][4])
V['ldst_pct']='%.1f%%'%float(C['load-store'][4]); V['block_n']=C['block-move'][1]
V['img_total']=img_total; V['code_pct']='%.0f%%'%(100*H['bytes']/img_total)
# candidates
cand={r[0]:r for r in rd('candidates')}
def cs(k,col=1):
    for kk,r in cand.items():
        if kk.startswith(k): return int(r[col]) if r[col] else 0
    return 0
V['narrowcmp']=cs('narrow load; cmp'); V['ld32op']=cs('movl mem,r; op'); V['ld32op_bytes']=2*V['ld32op']; V['ld32op_pct']='%.1f%%'%(100*V['ld32op_bytes']/img_total)
V['set_sites']=cs('set cc'); V['set_bytes']=cs('set cc',2); V['set_pct']='%.2f%%'%(100*V['set_bytes']/img_total)
V['minmax_sites']=cs('min/max'); V['abs_sites']=cs('abs')
V['addm_sites']=cs('addm'); V['addm_bytes']=cs('addm',2); V['rmw32']=cs('read-modify-write of a 32-bit')
# patterns computed from the .s files
C2=collections.Counter()
files=[s for s in fair]
for s in files:
    p='/tmp/p64opt/final/s/'+s.replace('/','_')+'.s'
    if not os.path.exists(p): continue
    Lx=[l.strip() for l in open(p) if l.strip() and not l.startswith('\t;')]
    for l in Lx:
        m=re.match(r'(mov[qlwb]|movz[lwb]|lea|add|sub|cmp|and|bis|xor|mul)\s+(.*)$',l)
        if not m: continue
        mn,ops=m.groups()
        for op in re.split(r',(?![^()]*\))',ops):
            mm=re.fullmatch(r'(-?\d*)\((r\d+|sp|fp)\)',op.strip())
            if mm and mn.startswith('mov'):
                d=int(mm.group(1) or 0); b=mm.group(2)
                if d==0: C2['d0']+=1
                if b=='sp' and mn=='movq' and 0<=d<512 and d%8==0: C2['sp']+=1
    for i in range(len(Lx)-1):
        m=re.match(r'cmp (r\d+),#(-?\d+)$',Lx[i])
        if m and re.match(r'b(eq|ne|lt|ge|gt|le|cs|cc|hi|los) ',Lx[i+1]):
            v=int(m.group(2)); C2['cb']+=1
            if -16<=v<16: C2['cbs']+=1
            if -128<=v<128: C2['cbm']+=1
        if re.match(r'tst r\d+$',Lx[i]) and re.match(r'b(eq|ne|lt|ge|gt|le|mi|pl) ',Lx[i+1]): C2['tst']+=1
        if re.match(r'cmp r\d+,(r\d+|-?\d*\([^)]*\))$',Lx[i]) and re.match(r'b(eq|ne|lt|ge|gt|le|cs|cc|hi|los) ',Lx[i+1]): C2['cbr']+=1
        ma=re.match(r'shl #(\d+),(r\d+)$',Lx[i])
        if ma:
            for k2 in range(1,6):
                if i+k2<len(Lx):
                    mb=re.match(r'shr #(\d+),(r\d+)$',Lx[i+k2])
                    if mb:
                        if int(ma.group(1))+int(mb.group(1))==32: C2['rot32']+=1
                        break
V['ds_d0']=C2['d0']; V['ds_d0_bytes']=2*C2['d0']; V['ds_d0_pct']='%.1f%%'%(100*2*C2['d0']/img_total)
V['ds_sp']=C2['sp']; V['ds_sp_bytes']=2*C2['sp']; V['ds_sp_pct']='%.1f%%'%(100*2*C2['sp']/img_total)
V['cb_total']=C2['cb']; V['cb_small']=C2['cbs']; V['cb_med']=C2['cbm']; V['cb_small_bytes']=2*C2['cbs']; V['cb_small_pct']='%.1f%%'%(100*2*C2['cbs']/img_total)
V['tst_br']=C2['tst']
V['rot32']=C2['rot32']; V['rot32_bytes']=10*C2['rot32']; V['rot32_pct']='%.1f%%'%(100*10*C2['rot32']/img_total)
# compare+branch pair totals and conditional branch share
MN=J['pdp64_mn']; totin=sum(MN.values())
condbr=sum(v for k,v in MN.items() if re.fullmatch(r'b(eq|ne|lt|ge|gt|le|cs|cc|hi|los|mi|pl|vc|vs)',k))
V['condbr_pct']='%.1f%%'%(100*condbr/totin)
BG=collections.Counter()
for s in fair: BG.update(fair[s]['pdp64']['bigram'])
cmpbr=sum(v for k,v in BG.items() if re.match(r'(cmp|tst|bit) ',k) and re.search(r'; (beq|bne|blt|bge|bgt|ble|bcs|bcc|bhi|blos|bmi|bpl) pcrel',k))
V['cmpbr']=cmpbr; V['cmpbr_pct']='%.1f%%'%(100*cmpbr/totin)
s=open('/tmp/p64opt/doc_template.md').read()
miss=[]
def sub(m):
    k=m.group(1)
    if k not in V: miss.append(k); return m.group(0)
    return str(V[k])
s=re.sub(r'\{\{(\w+)\}\}',sub,s)
print('missing:',miss)
out=os.path.expanduser('~/claude/pdp64/docs/codegen-analysis.md')
open(out,'w').write(s)
os.makedirs(os.path.expanduser('~/claude/pdp64/docs/codegen-data'),exist_ok=True)
for f in glob.glob(A+'*.csv'): shutil.copy(f,os.path.expanduser('~/claude/pdp64/docs/codegen-data/'))
shutil.copy('/tmp/p64opt/analysis.json',os.path.expanduser('~/claude/pdp64/docs/codegen-data/analysis.json'))
print({k:V[k] for k in ('r_all_gb','r_lib_gb','r_lib_cb','r_nm_gb','len_avg_pdp64','len_avg_gcc','len_avg_clang','xsec_pct','rot32','rot32_pct','ds_d0_pct','ds_sp_pct','cb_small_pct','cmpbr','cmpbr_pct','condbr_pct','frame_pct','reext_pct')})
