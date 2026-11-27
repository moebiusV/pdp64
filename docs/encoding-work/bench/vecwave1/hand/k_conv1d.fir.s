; conv1d, y[i] = sum_{k<8} w[k]*x[i+k], one vfir (sliding window of 8 taps held in r16..r23; r13 and r14 are fp and sp).  r0 = x, r1 = w, r2 = y, r3 = n.
; vfir's centre is 3: lane i = sum_k R(16+k) * x'[i+k-3], so x' = x + 3 gives x[i+k].
k_conv1d:
	mov.s32	0(r1),r16
	mov.s32	4(r1),r17
	mov.s32	8(r1),r18
	mov.s32	12(r1),r19
	mov.s32	16(r1),r20
	mov.s32	20(r1),r21
	mov.s32	24(r1),r22
	mov.s32	28(r1),r23
	lea	12(r0),r0
	lea	(r0)(r3*4),r9
	vec	r0,r9
	vld.f	v0,(r0)+
	vfir.f	v1,v0,r16,#8
	vst.f	v1,(r2)+
	vend
	ret
