; every addressing mode, widths, sign and zero extension
	.text
	.globl	_start
_start:
	mov	buf, r1
	cbne r1, $11, fail1
	lea	buf, r2
	mov	8(r2), r3
	cbne r3, $22, fail2
	mov	(r2)+, r4
	cbne r4, $11, fail3
	lea	buf, r5
	add	$8, r5
	cbne r2, r5, fail4
	mov	(r2)+, r6
	cbne r6, $22, fail5
	mov	-(r2), r7
	cbne r7, $22, fail6
	lea	buf, r2
	mov	$2, r8
	mov	(r2)(r8*8), r9
	cbne r9, $33, fail7
	mov	8(r2)(r8*8), r9
	cbne r9, $44, fail8
	lea	(r2)(r8*8), r3
	sub	r2, r3
	cbne r3, $16, fail9
	mov.s32	32(r2), r1
	cbne r1, $5, fail10
	mov.s16	36(r2), r1
	cbne r1, $6, fail11
	mov.s8	38(r2), r1
	cbne r1, $7, fail12
	mov.s8	39(r2), r1
	cbne r1, $-1, fail13
	mov.u8	39(r2), r1
	cbne r1, $255, fail14
	mov.s16	40(r2), r1
	cbne r1, $-1, fail15
	mov.u16	40(r2), r1
	mov	=65535, r13
	cbne	r1, r13, fail16
	mov.s32	44(r2), r1
	cbne r1, $-1, fail17
	mov.u32	44(r2), r1
	mov	$65535, r12
	shl	$16, r12
	bis	$65535, r12
	cbne r1, r12, fail18
	mov	$77, r1
	mov	r1, 8(r2)
	mov	8(r2), r3
	cbne r3, $77, fail19
	mov	$0x1FF, r1
	mov.s8	r1, 48(r2)
	mov.u8	48(r2), r3
	cbne r3, $255, fail20
	mov	$-1, r1
	mov	r1, 48(r2)
	mov	$0, r1
	mov.s32	r1, 48(r2)
	mov	48(r2), r3
	mov	$-1, r12
	shl	$32, r12
	cbne r3, r12, fail21
	mtdp	r2
	mov	8(dp), r3
	cbne r3, $77, fail22
	mov	$-5, r1
	cbne r1, $-5, fail23
	mov	$0x1234, r1		; a 48-bit value built from pieces: an immediate is 32 bits
	shl	$32, r1
	bis	$0x56789ABC, r1
	mov	$0x1234, r12
	shl	$32, r12
	mov	$0x56789ABC, r11
	bis	r11, r12
	cbne r1, r12, fail24
	mov	$0, r0
	trap	$0
fail1:	mov	$1, r0
	trap	$0
fail2:	mov	$2, r0
	trap	$0
fail3:	mov	$3, r0
	trap	$0
fail4:	mov	$4, r0
	trap	$0
fail5:	mov	$5, r0
	trap	$0
fail6:	mov	$6, r0
	trap	$0
fail7:	mov	$7, r0
	trap	$0
fail8:	mov	$8, r0
	trap	$0
fail9:	mov	$9, r0
	trap	$0
fail10:	mov	$10, r0
	trap	$0
fail11:	mov	$11, r0
	trap	$0
fail12:	mov	$12, r0
	trap	$0
fail13:	mov	$13, r0
	trap	$0
fail14:	mov	$14, r0
	trap	$0
fail15:	mov	$15, r0
	trap	$0
fail16:	mov	$16, r0
	trap	$0
fail17:	mov	$17, r0
	trap	$0
fail18:	mov	$18, r0
	trap	$0
fail19:	mov	$19, r0
	trap	$0
fail20:	mov	$20, r0
	trap	$0
fail21:	mov	$21, r0
	trap	$0
fail22:	mov	$22, r0
	trap	$0
fail23:	mov	$23, r0
	trap	$0
fail24:	mov	$24, r0
	trap	$0
	.data
	.even
buf:	.quad	11, 22, 33, 44
	.long	5
	.word	6
	.byte	7, -1
	.word	-1
	.word	0
	.long	-1
	.quad	0
