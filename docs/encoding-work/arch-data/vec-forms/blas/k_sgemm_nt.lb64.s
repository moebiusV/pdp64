; k_sgemm_nt, form 4: the whole GEMM as one instruction of the lb64 unit (errata 139: the unit is always present at a fixed memory page and handles its own caching,
; packing and memory loading; the 3-parcel opcodes are free for the GEMM operations).  The operands are named by a descriptor in memory, which also holds the progress,
; so a fault leaves the descriptor at the first tile not done and the instruction restarts (as the block moves keep theirs in registers).
; r0 = X, r1 = W, r2 = Y, r3 = M, r4 = K, r5 = N.  Y = 1.0 * X . W^T + 0.0 * Y.
k_sgemm_nt:
	sub	#64,sp
	movq	r0,0(sp)		; A
	movq	r1,8(sp)		; B
	movq	r2,16(sp)		; C
	movl	r3,24(sp)		; M
	movl	r5,28(sp)		; N
	movl	r4,32(sp)		; K
	movl	r4,36(sp)		; lda = K
	movl	r4,40(sp)		; ldb = K
	movl	r5,44(sp)		; ldc = N
	movl	#0x3f800000,48(sp)	; alpha = 1.0
	clrl	52(sp)			; beta = 0.0
	movl	#0x02,56(sp)		; flags: A not transposed, B transposed, float
	movq	sp,r6
	gemm.f	r6			; run until the descriptor says done
	add	#64,sp
	ret
