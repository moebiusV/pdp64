; count, byte-swap, rotate, abs/min/max, and the block operations
	.text
	.globl	_start
_start:
	mov	#0xF0, r1
	clz	r1, r2
	cbne r2, #56, f1
	ctz	r1, r2
	cbne r2, #4, f2
	popcnt	r1, r2
	cbne r2, #4, f3
	mov	#0, r1
	clz	r1, r2
	cbne r2, #64, f4
	ctz	r1, r2
	cbne r2, #64, f5
	mov	#-1, r1
	popcnt	r1, r2
	cbne r2, #64, f6
	clo	r1, r2
	cbne r2, #64, f7
	mov	#0xFF, r1
	cto	r1, r2
	cbne r2, #8, f8
	mov	#0x0102, r1
	bswap	r1, r2
	mov	#0x0201, r3
	shl	#48, r3
	cbne r2, r3, f9
	bswap.u16	r1, r2
	cbne r2, #513, f10
	mov	#1, r1
	bitrev	r1, r2
	shr	#63, r2
	cbne r2, #1, f11
	mov	#1, r1
	ror	r1, #1, r1
	shr	#63, r1
	cbne r1, #1, f12
	mov	#-5, r1
	abs	r1, r2
	cbne r2, #5, f13
	mov	#5, r1
	abs	r1, r2
	cbne r2, #5, f14
	mov	#-3, r1
	mov	#2, r2
	min	r1, r2, r3
	cbne r3, #-3, f15
	max	r1, r2, r3
	cbne r3, #2, f16
	min.u64	r1, r2, r3
	cbne r3, #2, f17
	max.u64	r1, r2, r3
	cbne r3, #-3, f18
	lea	src, r1
	lea	dst, r2
	mov	#13, r3
	mcpy	r2, r1, r3
	cbne r3, #0, f19
	lea	dst, r4
	sub	r4, r2
	cbne r2, #13, f20
	mov.s8	dst+7, r5
	cbne r5, #119, f21
	lea	src, r1
	lea	dst, r2
	mov	#13, r3
	mcmp	r2, r1, r3
	cbne r3, #0, f22		; equal blocks: the count left is 0
	lea	dst, r2
	mov	#88, r5
	mov.s8	r5, dst+4
	lea	src, r1
	mov	#13, r3
	mcmp	r2, r1, r3
	cbeq r3, #0, f23		; a difference: the count left is not 0
	cbne r3, #9, f24
	lea	dst, r2
	mov	#120, r1
	mov	#5, r3
	mset	r2, r1, r3
	mov.u8	dst+4, r5
	cbne r5, #120, f25
	mov.u8	dst+5, r5
	cbne r5, #44, f26
	lea	src, r2
	mov	#44, r1
	mov	#13, r3
	mscn	r2, r1, r3
	lea	src, r4
	sub	r4, r2
	cbne r2, #5, f27
	lea	pat, r2
	mov	#97, r1
	mov	#5, r3
	mscnn	r2, r1, r3
	lea	pat, r4
	sub	r4, r2
	cbne r2, #4, f28
	mov	#0, r0
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
f11:	mov	#11, r0
	trap	#0
f12:	mov	#12, r0
	trap	#0
f13:	mov	#13, r0
	trap	#0
f14:	mov	#14, r0
	trap	#0
f15:	mov	#15, r0
	trap	#0
f16:	mov	#16, r0
	trap	#0
f17:	mov	#17, r0
	trap	#0
f18:	mov	#18, r0
	trap	#0
f19:	mov	#19, r0
	trap	#0
f20:	mov	#20, r0
	trap	#0
f21:	mov	#21, r0
	trap	#0
f22:	mov	#22, r0
	trap	#0
f23:	mov	#23, r0
	trap	#0
f24:	mov	#24, r0
	trap	#0
f25:	mov	#25, r0
	trap	#0
f26:	mov	#26, r0
	trap	#0
f27:	mov	#27, r0
	trap	#0
f28:	mov	#28, r0
	trap	#0
	.data
	.even
src:	.ascii	"hello, world"
	.byte	0
	.even
dst:	.quad	0, 0, 0
pat:	.ascii	"aaaab"
	.byte	0
