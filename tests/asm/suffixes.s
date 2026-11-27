; the integer words with a width suffix that the other suffix tests do not have: .s8 .u8 .s16 .u16 .s32 .u32 (8, 16, 32 bits, signed and unsigned), the user moves, the byte swaps, the explicit 64-bit atomics.
; The encodings are those worked out by hand in suffixes.words.
	.text
	mov.s8 r1,r2
	mov.s16 r3,r4
	mov.s32 r5,r6
	mov r7,r8
	mov.u8 r1,r2
	mov.u16 r3,r4
	mov.u32 r5,r6
	mov.s16 (r3),r4
	mov.s16 r4,(r3)
	mov.u16 (r3),r4
	mov.u32 8(r3),r4
	mov.s32 (r1)(r2*4),r3
	mov.user (r1),r2
	mov.user.s32 (r1),r2
	mov.user.s16 2(r1),r2
	mov.user.s8 (r1),r2
	mov.user.u32 (r1),r2
	mov.user.u16 (r1),r2
	mov.user.u8 (r1),r2
	bswap.u16 r1,r2
	bswap.u32 r3,r4
	cas r1,(r2),r3
	cas r1,(r2),r3
	aadd r4,(r5),r6
	ll (r7),r8
	sc r1,(r2),r3
	ror.s32 r1,#5,r2
