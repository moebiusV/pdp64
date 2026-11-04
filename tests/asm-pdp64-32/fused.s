	.text
f:	movcall r1,r2,g
	add r1,r2
	movcall r8,r3,f
	mov2 r1,r2,r3,r8
	mov2 r9,r10,r0,r2
	mov2 r3,r2,r9,r10
	popm #0x0300
	popmret #0x0300
	popret r3
g:	popret r12
	movcall r5,r6,printf
	ret
