#!/usr/bin/env python3
# scratch: the same block over cold pages (sim64 -K -x: the first access to each page faults once, the handler returns), vector cycles with and without the faults
import subprocess, re
B='/home/matthew/claude/pdp64/build'
VF='/home/matthew/claude/pdp64/docs/encoding-work/arch-data/vec-forms'
def run(src,name,flags):
    open(name+'.s','w').write(src)
    subprocess.run([B+'/as64','-o',name+'.o',name+'.s'],check=True)
    subprocess.run([B+'/ld64','-o',name+'.x',name+'.o'],check=True)
    r=subprocess.run([B+'/sim64','-V','-K',*flags,name+'.x'],capture_output=True,text=True)
    m=re.search(r'vector (\d+)',r.stderr); 
    return int(m.group(1)), r.returncode
VT="""	.data
	.align	8
vtab:
	.space	56
	.quad	hf
	.quad	hf
	.space	3900
	.text
hf:	rti
"""
def prog(body,setup):
    return f"""	.text
	.globl	_start
_start:
	lea	vtab,r1
	mtsr	vbr,r1
{setup}
	call	k
	halt
{body}
"""+VT
ukr=open(VF+'/blas/k_sgemm_nt.ukr.s').read().replace('k_ukr:','k:')
dotf="""k:	clr	r4
	lea	(r0)(r2*4),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vmul.f	v0,v0,v1
	vacc.f	r4,v0
	vend
	ret
"""
dotacc="""k:	clr	r4
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
for name,body,mk in (('ukr',ukr,lambda K:(f"	movq	#0x800000,r0\n	movq	#0x900000,r1\n	movq	#0xa00000,r2\n	movq	#{K},r3\n	movq	#64,r4",32*K+16*K)),
                     ('dotacc',dotacc,lambda n:(f"	movq	#0x800000,r0\n	movq	#0x900000,r1\n	movq	#{n},r2",8*n)),
                     ('dotf',dotf,lambda n:(f"	movq	#0x800000,r0\n	movq	#0x900000,r1\n	movq	#{n},r2",8*n))):
    for n in ((64,256,1024) if name=='ukr' else (4096,16384,65536)):
        setup,bytes_=mk(n)
        warm,rc0=run(prog(body,setup),'f_'+name,['-x','0x2000000:0x2001000'])   # a window nobody touches: no faults
        cold,rc1=run(prog(body,setup),'f_'+name,['-x','0x800000:0xb00000'])
        print(name,n,'pages(approx, 4 KB)',bytes_//4096,'cycles no faults',warm,'cycles with faults',cold,'ratio %.2f'%(cold/warm),'rc',rc0,rc1,flush=True)
