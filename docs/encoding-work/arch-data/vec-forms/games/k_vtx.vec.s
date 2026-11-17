; k_vtx: n vertices by a 4x4 matrix (three output rows; structure of arrays).  r0 = ox, r1 = oy, r2 = oz, r3 = x, r4 = y, r5 = z, r6 = m (12 floats), r7 = n.
; The twelve matrix elements are loaded into scalar registers once; each output is three multiply-adds and the translation.
k_vtx:
	movl	0(r6),r10
	movl	4(r6),r11
	movl	8(r6),r12
	movl	12(r6),r13
	movl	16(r6),r14
	movl	20(r6),r15
	movl	24(r6),r16
	movl	28(r6),r17
	movl	32(r6),r18
	movl	36(r6),r19
	movl	40(r6),r20
	movl	44(r6),r21
	lea	(r3)(r7*4),r8
	vec	r3,r8
	vld.f	v0,(r3)+		; x
	vld.f	v1,(r4)+		; y
	vld.f	v2,(r5)+		; z
	vmul.f	v3,v0,r10
	vfma.f	v3,v1,r11
	vfma.f	v3,v2,r12
	vadd.f	v3,v3,r13
	vst.f	v3,(r0)+
	vmul.f	v3,v0,r14
	vfma.f	v3,v1,r15
	vfma.f	v3,v2,r16
	vadd.f	v3,v3,r17
	vst.f	v3,(r1)+
	vmul.f	v3,v0,r18
	vfma.f	v3,v1,r19
	vfma.f	v3,v2,r20
	vadd.f	v3,v3,r21
	vst.f	v3,(r2)+
	vend
	ret
