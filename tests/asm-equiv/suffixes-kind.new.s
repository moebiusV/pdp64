	.text
	; where the kind means nothing (a store, a byte swap, the store-conditional) the unsigned spelling is the same word as the signed one
	mov.u8 r1, (r2)
	mov.u16 r1, 4(r2)
	mov.u32 r1, 8(r2)
	mov.u8 r1, 4(r2)(r3*2)
	mov.user.u8 r1, (r2)
	mov.user.u16 r1, 4(r2)
	mov.user.u32 r1, 8(r2)
	bswap.u32 r1, r2
	bswap.u16 r1, r2
	sc.u32 r1, (r2), r3
