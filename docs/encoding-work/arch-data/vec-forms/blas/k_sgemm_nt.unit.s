; k_sgemm_nt, form 4: the whole GEMM as one instruction of a GEMM unit, with its progress in ordinary registers (rewritten 2026-11-17; the first version kept the progress in the
; descriptor, which the decision of errata 139 does not say).
;
; The constants of the operation are in a descriptor in memory (twelve fields: too many for registers).  The progress is in three ordinary registers, the row, column and K offset
; of the piece the unit is working on, as a block move keeps its address and count in registers: the program sets them to zero, the unit advances them as it commits work, and
; when the instruction finishes they say so (r8 = N).  After a fault or an interrupt the instruction is run again and goes on from the registers; the operating system saves
; and restores them like any others, and nothing else of the unit's state need be saved.
;
; The rule that makes the restart exact: the unit adds a K-block of a tile into C only when the whole K-block is computed, with the pages of the C tile checked for writing
; first, and the write-back of a tile is not interrupted; then r9 (the K offset) advances.  So C in memory always holds the sum of the K-blocks before r9, and a restart at
; r9 repeats at most one K-block.  Beta is applied by the unit when r9 = 0 and not otherwise.
;
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
	movq	sp,r6			; the descriptor
	clr	r7			; progress: row of the tile
	clr	r8			; progress: column of the tile
	clr	r9			; progress: K offset
	gemm.f	r6,r7,r8,r9		; runs until r8 = N; may stop at a fault or an interrupt and be run again as it stands
	add	#64,sp
	ret
