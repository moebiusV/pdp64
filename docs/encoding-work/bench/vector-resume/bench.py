#!/usr/bin/env python3
# scratch bench: block cycles (sim64 -V model 1, port 16, commit 1) of kernel shapes by size
import subprocess, re, sys, os, json
B='/home/matthew/claude/pdp64/build'
VF='/home/matthew/claude/pdp64/docs/encoding-work/arch-data/vec-forms'
def run(src, name, flags=()):
    open(name+'.s','w').write(src)
    subprocess.run([B+'/as64','-o',name+'.o',name+'.s'],check=True)
    subprocess.run([B+'/ld64','-o',name+'.x',name+'.o'],check=True)
    r=subprocess.run([B+'/sim64','-V',*flags,name+'.x'],capture_output=True,text=True)
    m=re.search(r'vec model strip (\d+) port (\d+) commit (\d+): scalar (\d+) vector (\d+).*?total (\d+)',r.stderr)
    return dict(scalar=int(m.group(4)),vector=int(m.group(5)),total=int(m.group(6)),raw=r.stderr.strip().splitlines())
def drv(call, data, setup):
    return f"""	.text
	.globl	_start
_start:
{setup}
	call	k
	halt
"""+call+"\n\t.data\n\t.align\t64\n"+data
def ukr(K): 
    body=open(VF+'/blas/k_sgemm_nt.ukr.s').read().replace('k_ukr:','k:')
    setup=f"	lea	pa,r0\n	lea	pb,r1\n	lea	pc,r2\n	movq	#{K},r3\n	movq	#64,r4"
    return drv(body,f"pa:\t.space {32*K}\npb:\t.space {16*K}\npc:\t.space 1024\n",setup)
def dotf(n):  # no accumulators: the shape k_sdot (vmul.f + vacc.f)
    body="""k:	clr	r4
	lea	(r0)(r2*4),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vmul.f	v0,v0,v1
	vacc.f	r4,v0
	vend
	ret
"""
    setup=f"	lea	px,r0\n	lea	py,r1\n	movq	#{n},r2"
    return drv(body,f"px:\t.space {4*n}\npy:\t.space {4*n}\n",setup)
def dotacc(n): # the same dot product written with a vclr accumulator (hidden state), lanes summed once after vfin
    body="""k:	clr	r4
	lea	(r0)(r2*4),r3
	vec	r0,r3
	vclr.f	v4,#1
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vfma.f	v4,v0,v1
	vfin
	vacc.f	r4,v4
	vend
	ret
"""
    setup=f"	lea	px,r0\n	lea	py,r1\n	movq	#{n},r2"
    return drv(body,f"px:\t.space {4*n}\npy:\t.space {4*n}\n",setup)
def q8(n):
    body=open(VF+'/games/k_q8dot.vec.s').read().replace('k_q8dot:','k:')
    setup=f"	lea	px,r0\n	lea	py,r1\n	movq	#{n},r2"
    return drv(body,f"px:\t.space {n}\npy:\t.space {n}\n",setup)
def q8acc(n):  # int8 dot with a vdot accumulator (hidden), vfin, one vacc
    body="""k:	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v4,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v4,v0,v1
	vfin
	vacc.l.q	r4,v4
	vend
	movq	r4,r0
	ret
"""
    setup=f"	lea	px,r0\n	lea	py,r1\n	movq	#{n},r2"
    return drv(body,f"px:\t.space {n}\npy:\t.space {n}\n",setup)
def tile(w,h):
    body=open(VF+'/tiles/k_avg.vec2d.s').read().replace('k_avg:','k:')
    pitch=w+64
    setup=f"	lea	pd,r0\n	lea	pa,r1\n	lea	pb,r2\n	movq	#{pitch},r3\n	movq	#{w},r4\n	movq	#{h},r5"
    return drv(body,f"pd:\t.space {pitch*h}\npa:\t.space {pitch*h}\npb:\t.space {pitch*h}\n",setup)
if __name__=='__main__':
    out={}
    def go(label,gen,sizes,key):
        for s in sizes:
            args=s if isinstance(s,tuple) else (s,)
            r=run(gen(*args),'t_'+label)
            out.setdefault(label,[]).append((s,r['vector'],r['raw'][-3:] if False else ''))
            print(label,s,'vector cycles',r['vector'],flush=True)
    go('ukr',ukr,[16,64,256,1024,4096],0)
    go('dotf',dotf,[1024,16384,262144],0)
    go('dotacc',dotacc,[1024,16384,262144],0)
    go('q8',q8,[4096,65536,1048576],0)
    go('q8acc',q8acc,[4096,65536,1048576],0)
    go('tile',tile,[(16,16),(64,64),(256,256)],0)
