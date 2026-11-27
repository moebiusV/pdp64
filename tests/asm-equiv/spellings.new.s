// comments of the second kind; ; still works
N equ 4                 // MASM's equ
M = 3                   ; the present assignment
	.text
start proc              // MASM's procedure label
	mov 8(r5), r1
	mov -8(r5), r1
	mov $5, r2          // $ for an immediate
	add $[N+1], r1       // [ ] groups
	mov (r1,r2,4), r3 // AT&T indexed
	mov 4(r1,r2,8), r3
	mov (r1,r2), r3
	mov $[1+2]*3, r4
	mov $M!N, r6        // a ! b is a | ~b
	mov $>0x1234, r7    // the high byte
	mov $<0x1234, r8    // the low byte
	mov r1, r2
	add r3, sp
	.data
	db 1, 2, 3           // db and dw
	dw 1000
	db "ab", 0
start endp
