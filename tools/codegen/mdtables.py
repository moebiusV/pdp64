import csv, json, sys, collections
A='/tmp/p64opt/analysis/'
def rd(n): return list(csv.reader(open(A+n+'.csv')))
def md(h, rows):
    o='| '+' | '.join(h)+' |\n|'+'---|'*len(h)+'\n'
    for r in rows: o+='| '+' | '.join(str(x) for x in r)+' |\n'
    return o
out={}
# totals
t=rd('totals')[1:]
rows=[]
for r in t:
    c,files=r[0],r[1]; pi,pb,ai,ab,gi,gb,ci,cb=[int(x) for x in r[2:10]]
    rows.append([c if c!='ALL' else '**all**',files,pi,pb,gi,gb,ci,cb,ai,ab,'%.2f'%(pi/gi),'%.2f'%(pb/gb),'%.2f'%(pi/ci),'%.2f'%(pb/cb)])
out['totals']=md(['corpus','files','pdp64 ins','pdp64 bytes','gcc -Os ins','gcc -Os bytes','clang -Os ins','clang -Os bytes','pcc amd64 ins','pcc amd64 bytes','ins / gcc','bytes / gcc','ins / clang','bytes / clang'],rows)
# lengths
L=rd('lengths_pdp64')[1:]; n=sum(int(r[1]) for r in L)
out['len_pdp64']=md(['bytes','instructions','share'],[[r[0],r[1],'%.1f%%'%(100*int(r[1])/n)] for r in L])
for a in ('gcc-Os','clang-Os'):
    L=rd('lengths_'+a)[1:]; n=sum(int(r[1]) for r in L)
    out['len_'+a]=md(['bytes','instructions','share'],[[r[0],r[1],'%.1f%%'%(100*int(r[1])/n)] for r in L])
# mnemonics side by side
P=rd('mnemonics_pdp64')[1:26]; G=rd('mnemonics_gcc-Os')[1:26]; K=rd('mnemonics_clang-Os')[1:26]
rows=[]
for i in range(25):
    rows.append([i+1,'`%s`'%P[i][1],'%s%%'%P[i][3],'%s%%'%P[i][4],'`%s`'%G[i][1],'%s%%'%G[i][3],'%s%%'%G[i][4],'`%s`'%K[i][1],'%s%%'%K[i][3],'%s%%'%K[i][4]])
out['mnem']=md(['rank','pdp64','share','cum.','gcc -Os (x86-64)','share','cum.','clang -Os (x86-64)','share','cum.'],rows)
# shapes
S=rd('shapes_pdp64')[1:]; tot=sum(int(r[1]) for r in S)
out['shapes_pdp64']=md(['operand form','operands','share','in 2-byte instr.','4','6','8'],[[r[0],r[1],'%.1f%%'%(100*int(r[1])/tot),r[2],r[3],r[4],r[5]] for r in S])
for a in ('gcc-Os','clang-Os'):
    S=rd('shapes_'+a)[1:]
    out['shapes_'+a]=md(['operand form','operands','share'],[[r[0],r[1],r[2]+'%'] for r in S])
# pairs
Pr=rd('pairs_pdp64')[1:21]
out['pairs']=md(['rank','mnemonic, operand forms','count','share of instructions'],[[i+1,'`%s`'%r[0].replace('"',''),r[1],r[2]+'%'] for i,r in enumerate(Pr)])
Pg=rd('pairs_gcc-Os')[1:16]
out['pairs_gcc']=md(['rank','mnemonic, operand forms','count','share'],[[i+1,'`%s`'%r[0],r[1],r[2]+'%'] for i,r in enumerate(Pg)])
B=rd('bigrams_pdp64')[1:26]
out['bigrams']=md(['rank','adjacent pair','count','share of instructions'],[[i+1,'`%s`'%r[0].replace('"',''),r[1],r[2]+'%'] for i,r in enumerate(B)])
T=rd('trigrams_pdp64')[1:15]
out['trigrams']=md(['rank','three in a row','count'],[[i+1,'`%s`'%r[0].replace('"',''),r[1]] for i,r in enumerate(T)])
Lg=rd('long_forms_pdp64')[1:16]
out['longs']=md(['rank','bytes, mnemonic, operand forms','count'],[[i+1,'`%s`'%r[0].replace('"',''),r[1]] for i,r in enumerate(Lg)])
C=rd('costcentres_pdp64')[1:]
out['cost']=md(['cost centre','instructions','share','bytes','share of instruction bytes'],[[r[0],r[1],r[2]+'%',r[3],r[4]+'%'] for r in C])
Cd=[r for r in rd('candidates')[1:] if not r[0].startswith('functions with a frame')]
out['cand']=md(['pattern in the pdp64 output','sites','estimated bytes saved'],[[r[0],r[1],r[2] or 'n/a'] for r in Cd])
U=rd('instructions_used')[1:]
used=[r for r in U if int(r[2])>0]
out['used']=md(['mnemonic','group','count'],[[r[0],r[1],r[2]] for r in used])
nev=collections.defaultdict(list)
for r in U:
    if int(r[2])==0: nev[r[3]].append(r[0])
out['never']=md(['why it is not emitted','instructions'],[[k,', '.join('`%s`'%x for x in v)] for k,v in sorted(nev.items(),key=lambda kv:-len(kv[1]))])
json.dump(out,open('/tmp/p64opt/mdtables.json','w'))
for k,v in out.items(): print('=====',k); print(v)
