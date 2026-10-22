; count, byte-swap, rotate, abs/min/max, and the block operations
	.text
	.globl	_start
_start:
	movq	#0xF0, r1
	clz	r1, r2
	cmp	r2, #56
	bne	f1
	ctz	r1, r2
	cmp	r2, #4
	bne	f2
	popcnt	r1, r2
	cmp	r2, #4
	bne	f3
	movq	#0, r1
	clz	r1, r2
	cmp	r2, #64		; clz of zero
	bne	f4
	ctz	r1, r2
	cmp	r2, #64		; ctz of zero
	bne	f5
	movq	#-1, r1
	popcnt	r1, r2
	cmp	r2, #64
	bne	f6
	clo	r1, r2
	cmp	r2, #64
	bne	f7
	movq	#0xFF, r1
	cto	r1, r2
	cmp	r2, #8
	bne	f8
	movq	#0x0102, r1
	bswap	r1, r2
	movq	#0x0201, r3
	shl	#48, r3
	cmp	r2, r3		; byte swap of 0x0102 is 0x0201 << 48
	bne	f9
	bswapw	r1, r2
	cmp	r2, #513		; bswapw swaps the low 16 bits
	bne	f10
	movq	#1, r1
	bitrev	r1, r2
	shr	#63, r2
	cmp	r2, #1		; bit 0 goes to bit 63
	bne	f11
	movq	#1, r1
	rori	r1, #1, r1
	shr	#63, r1
	cmp	r1, #1		; rotate right by 1 puts bit 0 at bit 63
	bne	f12
	movq	#-5, r1
	abs	r1, r2
	cmp	r2, #5
	bne	f13
	movq	#5, r1
	abs	r1, r2
	cmp	r2, #5
	bne	f14
	movq	#-3, r1
	movq	#2, r2
	min	r1, r2, r3
	cmp	r3, #-3
	bne	f15
	max	r1, r2, r3
	cmp	r3, #2
	bne	f16
	minu	r1, r2, r3
	cmp	r3, #2		; unsigned: -3 is huge
	bne	f17
	maxu	r1, r2, r3
	cmp	r3, #-3
	bne	f18
	lea	src, r1
	lea	dst, r2
	movq	#13, r3
	mcpy	r2, r1, r3
	cmp	r3, #0		; count is zero at the end
	bne	f19
	lea	dst, r4
	sub	r4, r2
	cmp	r2, #13		; dest pointer one past the end
	bne	f20
	movb	dst+7, r5
	cmp	r5, #119
	bne	f21
	lea	src, r1
	lea	dst, r2
	movq	#13, r3
	mcmp	r2, r1, r3
	set	eq, r6
	cmp	r6, #1		; equal buffers
	bne	f22
	lea	dst, r2
	movq	#88, r5
	movb	r5, dst+4
	lea	src, r1
	movq	#13, r3
	mcmp	r2, r1, r3
	set	ne, r6
	cmp	r6, #1		; differ at byte 4
	bne	f23
	cmp	r3, #9		; count left when it stopped
	bne	f24
	lea	dst, r2
	movq	#120, r1
	movq	#5, r3
	mset	r2, r1, r3
	movzb	dst+4, r5
	cmp	r5, #120
	bne	f25
	movzb	dst+5, r5
	cmp	r5, #44
	bne	f26
	lea	src, r2
	movq	#44, r1
	movq	#13, r3
	mscn	r2, r1, r3
	lea	src, r4
	sub	r4, r2
	cmp	r2, #5		; scan stops at the comma
	bne	f27
	lea	pat, r2
	movq	#97, r1
	movq	#5, r3
	mscnn	r2, r1, r3
	lea	pat, r4
	sub	r4, r2
	cmp	r2, #4		; first byte that is not a
	bne	f28
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f3:	movq	#3, r0
	trap	#0
f4:	movq	#4, r0
	trap	#0
f5:	movq	#5, r0
	trap	#0
f6:	movq	#6, r0
	trap	#0
f7:	movq	#7, r0
	trap	#0
f8:	movq	#8, r0
	trap	#0
f9:	movq	#9, r0
	trap	#0
f10:	movq	#10, r0
	trap	#0
f11:	movq	#11, r0
	trap	#0
f12:	movq	#12, r0
	trap	#0
f13:	movq	#13, r0
	trap	#0
f14:	movq	#14, r0
	trap	#0
f15:	movq	#15, r0
	trap	#0
f16:	movq	#16, r0
	trap	#0
f17:	movq	#17, r0
	trap	#0
f18:	movq	#18, r0
	trap	#0
f19:	movq	#19, r0
	trap	#0
f20:	movq	#20, r0
	trap	#0
f21:	movq	#21, r0
	trap	#0
f22:	movq	#22, r0
	trap	#0
f23:	movq	#23, r0
	trap	#0
f24:	movq	#24, r0
	trap	#0
f25:	movq	#25, r0
	trap	#0
f26:	movq	#26, r0
	trap	#0
f27:	movq	#27, r0
	trap	#0
f28:	movq	#28, r0
	trap	#0
	.data
	.even
src:	.ascii	"hello, world"
	.byte	0
	.even
dst:	.quad	0, 0, 0
pat:	.ascii	"aaaab"
	.byte	0
