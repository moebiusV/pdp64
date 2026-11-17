; k_sgemm_nt, form 4: the whole GEMM as one instruction of a GEMM unit, restarting from the start of a tile (rewritten 2026-11-17, third version: the first kept the
; progress in the descriptor, the second a K offset in a register; see gemm-forms.md section 5a for why neither).
;
; The constants of the operation are in a descriptor in memory (twelve fields: too many for registers).  The progress is two ordinary registers, the row and the column
; (in elements) of the next output tile to compute, as a block move keeps its address and count in registers.  The program sets them to zero; the unit advances them
; past each tile it has finished; when the instruction is finished r8 = N.
;
; The unit of restart is one output tile: C[tile] = alpha * (A rows . B rows over ALL of K) + beta * C[tile], computed in the unit's own registers and written ONCE.
; Before the tile is computed the pages of the C tile are checked for writing; the write-back of the tile and the advance of r7 and r8 are one step that is not
; interrupted.  So an interrupt or a fault before that step discards the tile (the accumulators are only a cache) and the instruction, run again, redoes that tile from
; the start; an interrupt after it leaves the registers at the next tile.  C in memory never holds a half-finished tile, so beta = 1 (accumulating in place, as the
; backward pass of cngpt does) is correct.  The work lost to an interrupt is at most one tile (about 2 microseconds at K = 768).  Nothing is saved at a context switch
; beyond the ordinary registers; the unit's internal state may be dropped at any time.  The translation buffer must hold the pages of one tile (about 48 at K = 768).
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
	clr	r7			; progress: row of the next tile
	clr	r8			; progress: column of the next tile
	gemm.f	r6,r7,r8		; runs until r8 = N; may be cut off by a fault or an interrupt and be run again as it stands
	add	#64,sp
	ret
