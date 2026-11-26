; the vec block (docs/encoding-work/vec-isa.md): a float multiply-add over a region that is not a multiple of the strip (the last strip is short), a widening integer
; map with a saturating narrow, a reduction into a register, and a block with an accumulator and its epilogue (vfin).  Every check is a scalar computation of the same thing; a failed check n exits with n.
	.text
	.globl	_start
_start:
	; ---- 1. dst[i] += src[i] * 2.0 for 19 floats (strips of 8: 8, 8, 3)   (k_fmac of the hand-written kernels)
	lea	src, r1
	lea	dst, r0
	movq	#19, r2
	movq	#0x40000000, r3		; 2.0f
	lea	(r0)(r2*4), r4
	vec	r0, r4
	vld.f	v0, (r1)+
	vld.f	v1, (r0)
	vfma.f	v1, v0, r3
	vst.f	v1, (r0)+
	vend
	lea	dst, r0
	lea	want, r1
	movq	#19, r2
	movq	#1, r9
1:	mov	(r0)+.32, r5
	mov	(r1)+.32, r6
	cbne	r5, r6, fail
	sob	r2, 1b
	; ---- 2. bytes widened to words, 255 - x, narrowed with saturation back to bytes (200 bytes)
	lea	bsrc, r1
	lea	bdst, r0
	movq	#200, r2
	lea	(r1)(r2*1), r4
	vec	r1, r4
	vld.bu.w v0, (r1)+
	vsubr.w	v1, v0, #255
	vadds.w	v1, v1, #0
	vsts.w.bu v1, (r0)+
	vend
	lea	bsrc, r1
	lea	bdst, r0
	movq	#200, r2
	movq	#2, r9
2:	mov	(r1)+.u8, r5
	movq	#255, r6
	sub	r5, r6
	mov	(r0)+.u8, r7
	cbne	r6, r7, fail
	sob	r2, 2b
	; ---- 3. the sum and the maximum of 21 words into registers
	lea	wsrc, r1
	movq	#21, r2
	lea	(r1)(r2*2), r4
	movq	#0, r10
	movq	#-32768, r11
	vec	r1, r4
	vld.w	v0, (r1)+
	vacc.w.l r10, v0
	vmaxacc.w r11, v0
	vend
	movq	#3, r9
	movq	#-32768, r6
	movq	#0, r5
	lea	wsrc, r1
	movq	#21, r2
3:	mov	(r1)+.16, r7
	add	r7, r5
	cble r7, r6, 4f
	movq	r7, r6
4:	sob	r2, 3b
	cbne	r10, r5, fail
	cbne	r11, r6, fail
	; ---- 4. a block with an accumulator and a vfin (errata 173): the lanes of vl add up the 21 words by lane (strips of 16 bytes: 4 lanes), the epilogue sums the lanes once after the last strip
	movq	#4, r9
	movq	r10, r6				; the sum of test 3, from the registers
	lea	wsrc, r1
	movq	#21, r2
	lea	(r1)(r2*2), r4
	movq	#0, r12
	vec	r1, r4
	vclr.l	v4, #1
	vld.w.l	v0, (r1)+
	vadd.l	v4, v4, v0
	vfin
	vacc.l.q r12, v4
	vend
	cbne	r12, r6, fail
	; ---- 5. a strided load: every 3rd byte of 60 bytes (20 elements, strips of 16 and 4) widened and summed
	movq	#5, r9
	lea	bsrc, r1
	movq	#60, r2
	lea	(r1)(r2*1), r4
	movq	#0, r10
	vec	r1, r4
	vldt.bu.w v0, (r1)+, #3
	vacc.w.l r10, v0
	vend
	movq	#570, r11			; 0 + 3 + 6 + ... + 57
	cbne	r10, r11, fail
	; ---- 6. sums of bytes straight from byte lanes, with no widening load (errata 168): unsigned (vacc.bu.l) and signed (vacc.b.l) over the 200 bytes 0..199, strips of 32
	movq	#6, r9
	lea	bsrc, r1
	movq	#200, r2
	lea	(r1)(r2*1), r4
	movq	#0, r10
	movq	#0, r12
	vec	r1, r4
	vld.bu	v0, (r1)+
	vacc.bu.l r10, v0
	vend
	lea	bsrc, r1
	vec	r1, r4
	vld.b	v0, (r1)+
	vacc.b.l r12, v0
	vend
	movq	#19900, r11			; 0 + 1 + ... + 199
	cbne	r10, r11, fail
	movq	#1468, r11			; the same with the 72 bytes from 128 on read as negative: 19900 - 72 * 256
	cbne	r12, r11, fail
	movq	#0, r0
	trap	#0
fail:	movq	r9, r0
	trap	#0

	.data
	.align	4
src:	.long	0x3f800000, 0x40000000, 0x40400000, 0x40800000, 0x40a00000, 0x40c00000, 0x40e00000, 0x41000000
	.long	0x41100000, 0x41200000, 0x41300000, 0x41400000, 0x41500000, 0x41600000, 0x41700000, 0x41800000
	.long	0x41880000, 0x41900000, 0x41980000
dst:	.long	0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000
	.long	0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000
	.long	0x3f800000, 0x3f800000, 0x3f800000
; 1 + 2 * (1 .. 19)
want:	.long	0x40400000, 0x40a00000, 0x40e00000, 0x41100000, 0x41300000, 0x41500000, 0x41700000, 0x41880000
	.long	0x41980000, 0x41a80000, 0x41b80000, 0x41c80000, 0x41d80000, 0x41e80000, 0x41f80000, 0x42040000
	.long	0x420c0000, 0x42140000, 0x421c0000
bsrc:	.byte	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
	.byte	32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
	.byte	64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	.byte	96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127
	.byte	128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159
	.byte	160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191
	.byte	192, 193, 194, 195, 196, 197, 198, 199
bdst:	.space	200
	.align	2
wsrc:	.word	1, -2, 300, -400, 5, 6000, -7, 8, 9, -10, 11, 12, 13, -14, 15, 16, 17, 18, -19, 20, 21
