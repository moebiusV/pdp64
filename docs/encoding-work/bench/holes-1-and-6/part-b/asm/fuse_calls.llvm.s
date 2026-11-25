	.text
	.globl	id3                             ; -- Begin function id3
	.align	2
id3:                                    ; @id3
; %bb.0:
	mul #100, r0
	mul #10, r1
	add r1, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	swap2                           ; -- Begin function swap2
	.align	2
swap2:                                  ; @swap2
; %bb.0:
	movq r0, r2
	mul #10, r2
	sub r1, r0
	mul #100, r1
	add r2, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	keep                            ; -- Begin function keep
	.align	2
keep:                                   ; @keep
; %bb.0:
	movq r1, r3
	sub r0, r3
	mul #10, r3
	sub r2, r0
	mul #100, r0
	sub r1, r2
	add r2, r3
	add r3, r0
	ret
                                        ; -- End function
	.globl	many                            ; -- Begin function many
	.align	2
many:                                   ; @many
; %bb.0:
	push fp
	movq sp, fp
	movq 24(r13), r6
	movq 16(r13), r7
	lea 0(r0)(r1*2), r0
	mul #3, r2
	add r0, r2
	lea 0(r2)(r3*4), r0
	mul #5, r4
	add r0, r4
	mul #6, r5
	add r4, r5
	mul #7, r7
	add r5, r7
	lea 0(r7)(r6*8), r0
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.globl	chain                           ; -- Begin function chain
	.align	2
chain:                                  ; @chain
; %bb.0:
	mul #13, r1
	mul #9, r0
	add r2, r0
	mul #13, r2
	add r1, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	leafone                         ; -- Begin function leafone
	.align	2
leafone:                                ; @leafone
; %bb.0:
	lea 1(r0), r0
	ret
                                        ; -- End function
	.globl	deep                            ; -- Begin function deep
	.align	2
deep:                                   ; @deep
; %bb.0:
	movq r0, r1
	clr r0
	cbeq r1, #0, .LBB6_3
.LBB6_2:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r1), r2
	add r1, r0
	movq r2, r1
	cbne r1, #0, .LBB6_2
.LBB6_3:
	ret
                                        ; -- End function
	.globl	tail                            ; -- Begin function tail
	.align	2
tail:                                   ; @tail
; %bb.0:
	mul #110, r1
	add r1, r0
	ret
                                        ; -- End function
	.globl	regs                            ; -- Begin function regs
	.align	2
regs:                                   ; @regs
; %bb.0:
	movq r3, r5
	add r1, r5
	movq r5, r6
	add r4, r6
	mul #10, r6
	add r0, r1
	add r3, r1
	mul #100, r1
	add r0, r2
	add r4, r2
	add r5, r1
	add r6, r1
	lea 0(r1)(r2*2), r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	movq #10, r0
	call deep
	movq r0, r1
	clr r0
	cbeq r1, #55, .LBB9_2
; %bb.1:
	movq #16, r0
.LBB9_2:
	ret
                                        ; -- End function
