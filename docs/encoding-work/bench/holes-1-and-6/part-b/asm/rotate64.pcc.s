	.text
	.even
	.globl rl
rl:
.L251:
.L255:
	rol r0,#13,r0
	; ret:one,out=0
	ret
	.even
	.globl rr
rr:
.L259:
.L263:
	rol r0,#57,r0
	; ret:one,out=0
	ret
	.even
	.globl rs
rs:
.L267:
.L271:
	rol r0,#1,r0
	; ret:one,out=0
	ret
	.even
	.globl test
test:
.L275:
.L279:
	movq =-9223372036854775807,r0
	call rl
	cbeq r0,#12288,.L281
	movq #2,r0
	ret
.L281:
	movq =-9223372036854775807,r0
	call rr
	cmp r0,=216172782113783808
	beq .L283
	movq #3,r0
	ret
.L283:
	movq #1,r0
	call rl
	cbeq r0,#8192,.L285
	movq #4,r0
	ret
.L285:
	movq #1,r0
	call rr
	cmp r0,=144115188075855872
	beq .L287
	movq #5,r0
	ret
.L287:
	movq #-1,r0
	call rs
	cbeq r0,#-1,.L289
	movq #6,r0
	ret
.L289:
	movq =4611686018427387904,r0
	call rs
	cmp r0,=-9223372036854775808
	beq .L291
	movq #7,r0
	ret
.L291:
	movq =-9223372036854775807,r0
	call rl
	call rl
	movq =-9223372036854775807,r1
	rol r1,#26,r1
	cbeq r0,r1,.L293
	movq #8,r0
	ret
.L293:
	movq #1,r0
.L277:
	; ret:one,out=0
	ret
