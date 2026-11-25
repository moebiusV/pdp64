	.text
	.even
	.globl add3
add3:
.L251:
.L255:
	mul #100,r0
	mul #10,r1
	add r1,r0
	add r2,r0
	; ret:one,out=0
	ret
	.data
	.align 8
	.globl "fp"
"fp":
	.quad add3
	.text
	.even
viaops:
.L261:
	mov2 r0,r2,r1,r0
.L265:
	add 8(r2),r0
	; ret:one,out=0
	ret
	.even
	.globl direct
direct:
.L269:
.L273:
	movq #7,r2
	; ret:one,out=0
	jmp add3
	.even
	.globl indirect
indirect:
.L277:
	mov2 r0,r3,r1,r0
.L281:
	lea 1(r0),r1
	lea 2(r0),r2
	; ret:one,out=0
	jmp (r3)
	.even
	.globl global
global:
.L285:
.L289:
	movq #2,r2
	movq #1,r1
	; ret:one,out=0
	jmpi "fp"
	.even
	.globl method
method:
.L293:
	movq r0,r2
.L297:
	; ret:one,out=0
	jmpi (r2)
	.even
	.globl saved
saved:
	pushm #768
.L301:
	mov2 r0,r9,r1,r8
.L305:
	movq #1,r2
	call add3
	movq #7,r1
	mod r0,r1,r0
	mov2 r8,r2,r9,r1
	popm #768
	; ret:one,out=0
	jmp add3
	.even
	.globl viareg
viareg:
	pushm #768
.L309:
	mov2 r0,r9,r1,r8
.L313:
	mov2 r9,r2,r9,r1
	call add3
	movq #5,r1
	mod r0,r1,r0
	movq #3,r2
	movq r9,r1
	call (r8)
	popmret #768
	; ret:one,out=0
	.even
	.globl sink
sink:
.L317:
	movq r0,r1
.L321:
	movq (r1),r0
	add 8(r1),r0
	; ret:one,out=0
	ret
	.even
	.globl local
local:
	sub #16,sp
.L325:
.L329:
	movq r0,(sp)
	asl r0
	movq r0,8(sp)
	movcall sp,r0,sink
	add #16,sp
	; ret:one,out=0
	ret
	.even
	.globl sum
sum:
.L333:
	movq r0,r2
.L337:
	cbne r2,#0,.L339
	movq r1,r0
	ret
.L339:
	lea -1(r2),r0
	add r2,r1
	call sum
.L335:
	; ret:one,out=0
	ret
	.even
	.globl cond
cond:
.L343:
.L347:
	cble r0,#0,.L349
	mov2 r0,r2,r0,r1
	jmp add3
.L349:
	movq r0,r2
	clr r1
	clr r0
	call add3
.L345:
	; ret:one,out=0
	ret
	.even
	.globl many
many:
.L353:
.L357:
	add r1,r0
	add r2,r0
	add r3,r0
	add r4,r0
	add r5,r0
	add 8(sp),r0
	; ret:one,out=0
	ret
	.even
	.globl stackarg
stackarg:
	sub #8,sp
.L361:
.L365:
	movq #6,r1
	movq r1,(sp)
	movq #5,r5
	movq #4,r4
	movq #3,r3
	movq #2,r2
	movq #1,r1
	call many
	add #8,sp
	; ret:one,out=8
	ret
	.even
	.globl test
test:
	pushm #768
	sub #16,sp
.L369:
.L373:
	clr r8
	lea viaops,r0
	movq r0,(sp)
	movq #100,r0
	movq r0,8(sp)
	movq #2,r1
	movq #1,r0
	call direct
	cbeq r0,#127,.L375
	bis #1,r8
.L375:
	movq #1,r1
	lea add3,r0
	call indirect
	cbeq r0,#123,.L377
	bis #2,r8
.L377:
	movq #3,r0
	call global
	cbeq r0,#312,.L379
	bis #4,r8
.L379:
	movq #5,r1
	movcall sp,r0,method
	cbeq r0,#105,.L381
	bis #8,r8
.L381:
	movq #3,r1
	movq #2,r0
	call saved
	movq r0,r9
	movq #3,r2
	movq #2,r1
	clr r0
	call add3
	cbeq r9,r0,.L383
	bis #16,r8
.L383:
	lea add3,r1
	movq #4,r0
	call viareg
	movq r0,r9
	movq #3,r2
	movq #4,r1
	movq #4,r0
	call add3
	cbeq r9,r0,.L385
	bis #32,r8
.L385:
	movq #5,r0
	call local
	cbeq r0,#15,.L387
	bis #64,r8
.L387:
	clr r1
	movq #100,r0
	call sum
	cbeq r0,#5050,.L389
	bis #128,r8
.L389:
	movq #2,r0
	call cond
	cbne r0,#222,.L393
	movq #-3,r0
	call cond
	cbeq r0,#-3,.L391
.L393:
	bis #256,r8
.L391:
	movq #10,r0
	call stackarg
	cbeq r0,#31,.L395
	bis #512,r8
.L395:
	movl r8,r0
	add #16,sp
	popmret #768
	; ret:one,out=0
