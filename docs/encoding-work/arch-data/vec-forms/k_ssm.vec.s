; k_ssm (mamba.c selective scan, one row, fused): dA = exp(dt*A[j]); dB = dt*B[j]; s = state[j]*dA + x*dB; state[j] = s; acc += s*C[j]; *y = acc.
; r0 = state, r1 = dt, r2 = A, r3 = B, r4 = C, r5 = x (floats in general registers), r6 = y, r7 = n.
; vexp.f is not in the decided set (an implementation could instead call a vector library routine per strip).
k_ssm:
	clr	r8			; acc
	lea	(r2)(r7*4),r9
	vec	r2,r9
	vld.f	v0,(r2)+		; A[j]
	vmul.f	v0,v0,r1		; dt * A[j]
	vexp.f	v0,v0			; dA
	vld.f	v1,(r3)+		; B[j]
	vmul.f	v1,v1,r1		; dB = dt * B[j]
	vmul.f	v1,v1,r5		; x * dB
	vld.f	v2,(r0)			; state[j]
	vfma.f	v1,v2,v0		; s = state[j] * dA + x * dB
	vst.f	v1,(r0)+
	vld.f	v3,(r4)+		; C[j]
	vmul.f	v1,v1,v3
	vacc.f	r8,v1			; acc += the sum of the lanes
	vend
	movl	r8,(r6)
	ret
