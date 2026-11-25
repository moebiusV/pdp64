exec(open('fault.py').read().split("for name,body,mk in")[0])
for n in (4096,16384):
    setup=f"	movq	#0x800000,r0\n	movq	#0x900000,r1\n	movq	#{n},r2"
    cold,rc=run(prog(dotf,setup),'f_dotf',['-x','0x800000:0xb00000'])
    print('dotf cold n',n,'cycles with faults',cold,'rc',rc)
