; a mark after a number or a constant symbol says how many bits it has and how to read them
	.text
big = 0x1ff
	mov	$0xff.s8, r1
	mov	$0xff.u8, r2
	mov	$-1.u8, r3
	mov	$200.s8, r4
	mov	$0x80.s8, r5
	mov	$0xffff.s16, r6
	mov	$0xffffffff.s32, r7
	mov	$big.s16, r8
	mov	$big.u16, r9
	mov	$0xff.f8, r10
	cbeq	r1, $0x7f.s8, 1f
	cbeq	r1, $0xff.s8, 1f
1:	nop
	.data
	.byte	0xff.s8, 0xff.u8, -1.u8, 200.s8, -128.u8
	.word	0xffff.s16, 65535.u16, big.s16
	.long	0xffffffff.s32, 0xffffffff.u32
	.quad	-1.u64, 0xffffffffffffffff.s64
