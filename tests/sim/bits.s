; count, byte-swap, rotate, abs/min/max, and the block operations
	.text
	.globl	_start
_start:
	movq	#0xF0, r1
	clz	r1, r2
	cbne r2, #56, f1
	ctz	r1, r2
	cbne r2, #4, f2
	popcnt	r1, r2
	cbne r2, #4, f3
	movq	#0, r1
	clz	r1, r2
	cbne r2, #64, f4
	ctz	r1, r2
	cbne r2, #64, f5
	movq	#-1, r1
	popcnt	r1, r2
	cbne r2, #64, f6
	clo	r1, r2
	cbne r2, #64, f7
	movq	#0xFF, r1
	cto	r1, r2
	cbne r2, #8, f8
	movq	#0x0102, r1
	bswap	r1, r2
	movq	#0x0201, r3
	shl	#48, r3
	cbne r2, r3, f9
	bswap	r1.16, r2
	cbne r2, #513, f10
	movq	#1, r1
	bitrev	r1, r2
	shr	#63, r2
	cbne r2, #1, f11
	movq	#1, r1
	ror	r1, #1, r1
	shr	#63, r1
	cbne r1, #1, f12
	movq	#-5, r1
	abs	r1, r2
	cbne r2, #5, f13
	movq	#5, r1
	abs	r1, r2
	cbne r2, #5, f14
	movq	#-3, r1
	movq	#2, r2
	min	r1, r2, r3
	cbne r3, #-3, f15
	max	r1, r2, r3
	cbne r3, #2, f16
	minu	r1, r2, r3
	cbne r3, #2, f17
	maxu	r1, r2, r3
	cbne r3, #-3, f18
	lea	src, r1
	lea	dst, r2
	movq	#13, r3
	mcpy	r2, r1, r3
	cbne r3, #0, f19
	lea	dst, r4
	sub	r4, r2
	cbne r2, #13, f20
	mov	dst+7.8, r5
	cbne r5, #119, f21
	lea	src, r1
	lea	dst, r2
	movq	#13, r3
	mcmp	r2, r1, r3
	cbne r3, #0, f22		; equal blocks: the count left is 0
	lea	dst, r2
	movq	#88, r5
	mov	r5, dst+4.8
	lea	src, r1
	movq	#13, r3
	mcmp	r2, r1, r3
	cbeq r3, #0, f23		; a difference: the count left is not 0
	cbne r3, #9, f24
	lea	dst, r2
	movq	#120, r1
	movq	#5, r3
	mset	r2, r1, r3
	mov	dst+4.u8, r5
	cbne r5, #120, f25
	mov	dst+5.u8, r5
	cbne r5, #44, f26
	lea	src, r2
	movq	#44, r1
	movq	#13, r3
	mscn	r2, r1, r3
	lea	src, r4
	sub	r4, r2
	cbne r2, #5, f27
	lea	pat, r2
	movq	#97, r1
	movq	#5, r3
	mscnn	r2, r1, r3
	lea	pat, r4
	sub	r4, r2
	cbne r2, #4, f28
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
