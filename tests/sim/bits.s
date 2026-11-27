; count, byte-swap, rotate, abs/min/max, and the block operations
	.text
	.globl	_start
_start:
	mov	$0xF0, r1
	clz	r1, r2
	cbne r2, $56, fail1
	ctz	r1, r2
	cbne r2, $4, fail2
	popcnt	r1, r2
	cbne r2, $4, fail3
	mov	$0, r1
	clz	r1, r2
	cbne r2, $64, fail4
	ctz	r1, r2
	cbne r2, $64, fail5
	mov	$-1, r1
	popcnt	r1, r2
	cbne r2, $64, fail6
	clo	r1, r2
	cbne r2, $64, fail7
	mov	$0xFF, r1
	cto	r1, r2
	cbne r2, $8, fail8
	mov	$0x0102, r1
	bswap	r1, r2
	mov	$0x0201, r3
	shl	$48, r3
	cbne r2, r3, fail9
	bswap.u16	r1, r2
	cbne r2, $513, fail10
	mov	$1, r1
	bitrev	r1, r2
	shr	$63, r2
	cbne r2, $1, fail11
	mov	$1, r1
	ror	r1, $1, r1
	shr	$63, r1
	cbne r1, $1, fail12
	mov	$-5, r1
	abs	r1, r2
	cbne r2, $5, fail13
	mov	$5, r1
	abs	r1, r2
	cbne r2, $5, fail14
	mov	$-3, r1
	mov	$2, r2
	min	r1, r2, r3
	cbne r3, $-3, fail15
	max	r1, r2, r3
	cbne r3, $2, fail16
	min.u64	r1, r2, r3
	cbne r3, $2, fail17
	max.u64	r1, r2, r3
	cbne r3, $-3, fail18
	lea	src, r1
	lea	dst, r2
	mov	$13, r3
	mcpy	r2, r1, r3
	cbne r3, $0, fail19
	lea	dst, r4
	sub	r4, r2
	cbne r2, $13, fail20
	mov.s8	dst+7, r5
	cbne r5, $119, fail21
	lea	src, r1
	lea	dst, r2
	mov	$13, r3
	mcmp	r2, r1, r3
	cbne r3, $0, fail22		; equal blocks: the count left is 0
	lea	dst, r2
	mov	$88, r5
	mov.s8	r5, dst+4
	lea	src, r1
	mov	$13, r3
	mcmp	r2, r1, r3
	cbeq r3, $0, fail23		; a difference: the count left is not 0
	cbne r3, $9, fail24
	lea	dst, r2
	mov	$120, r1
	mov	$5, r3
	mset	r2, r1, r3
	mov.u8	dst+4, r5
	cbne r5, $120, fail25
	mov.u8	dst+5, r5
	cbne r5, $44, fail26
	lea	src, r2
	mov	$44, r1
	mov	$13, r3
	mscn	r2, r1, r3
	lea	src, r4
	sub	r4, r2
	cbne r2, $5, fail27
	lea	pat, r2
	mov	$97, r1
	mov	$5, r3
	mscnn	r2, r1, r3
	lea	pat, r4
	sub	r4, r2
	cbne r2, $4, fail28
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
fail25:	mov	$25, r0
	trap	$0
fail26:	mov	$26, r0
	trap	$0
fail27:	mov	$27, r0
	trap	$0
fail28:	mov	$28, r0
	trap	$0
	.data
	.even
src:	.ascii	"hello, world"
	.byte	0
	.even
dst:	.quad	0, 0, 0
pat:	.ascii	"aaaab"
	.byte	0
