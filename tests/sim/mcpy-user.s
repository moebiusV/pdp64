; mcpy.ur and mcpy.uw (the block copy whose read side, or write side, is user memory, 6.10.4): with no MMU (sim64) they copy as mcpy does, the registers end as after mcpy
; (rd and rs advanced by the count, rn zero), a count of zero moves nothing; the user-memory fault is tested on QEMU, tests/qemu/mmu-guard.S.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	lea	src, r8
	lea	dst, r9
	mov	#12, r10
	mcpy.ur	r9, r8, r10
	cbne r10, #0, f1
	lea	dst+12, r2
	cbne r9, r2, f2
	lea	src+12, r2
	cbne r8, r2, f3
	lea	dst, r4
	mov	(r4), r5
	mov	=0x0807060504030201, r6
	cbne r5, r6, f4
	mov.s32	8(r4), r5
	mov	=0x0c0b0a09, r11
	cbne	r5, r11, f5
	lea	src, r8
	lea	dst2, r9
	mov	#9, r10
	mcpy.uw	r9, r8, r10
	cbne r10, #0, f6
	lea	dst2, r4
	mov	(r4), r5
	cbne r5, r6, f7
	mov.u8	8(r4), r5
	cbne r5, #9, f8
	mov.u8	9(r4), r5
	cbne r5, #0, f9
	lea	dst2+16, r9
	lea	src, r8
	mov	#0, r10
	mcpy.ur	r9, r8, r10
	lea	dst2+16, r2
	cbne r9, r2, f10
	clr	r0
	trap	#0
f1:	mov	#1, r0
	trap	#0
f2:	mov	#2, r0
	trap	#0
f3:	mov	#3, r0
	trap	#0
f4:	mov	#4, r0
	trap	#0
f5:	mov	#5, r0
	trap	#0
f6:	mov	#6, r0
	trap	#0
f7:	mov	#7, r0
	trap	#0
f8:	mov	#8, r0
	trap	#0
f9:	mov	#9, r0
	trap	#0
f10:	mov	#10, r0
	trap	#0
	.data
	.align	8
src:	.byte	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
dst:	.space	32
dst2:	.space	32
