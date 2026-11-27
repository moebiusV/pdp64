	.text
	; where the kind means nothing (a store, a byte swap, the store-conditional) the unsigned spelling is the same word as the signed one
	mov.s8 r1, (r2)
	mov.s16 r1, 4(r2)
	mov.s32 r1, 8(r2)
	mov.s8 r1, 4(r2)(r3*2)
	mov.user.s8 r1, (r2)
	mov.user.s16 r1, 4(r2)
	mov.user.s32 r1, 8(r2)
	bswap.s32 r1, r2
	bswap.s16 r1, r2
	sc.s32 r1, (r2), r3
