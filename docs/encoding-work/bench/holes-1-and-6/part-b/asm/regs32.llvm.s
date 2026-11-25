	.text
	.globl	id                              ; -- Begin function id
	.align	2
id:                                     ; @id
; %bb.0:
	ret
                                        ; -- End function
	.globl	pressure                        ; -- Begin function pressure
	.align	2
pressure:                               ; @pressure
; %bb.0:
	lea 16(r0), r1
	movq r0, r2
	mul #119, r2
	movq r0, r3
	add r1, r3
	shl #4, r1
	add r3, r1
	lea 0(r1)(r0*2), r0
	add r2, r0
	lea 1241(r0), r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	ret
                                        ; -- End function
