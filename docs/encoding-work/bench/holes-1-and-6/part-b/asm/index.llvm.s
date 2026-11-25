	.text
	.globl	f1                              ; -- Begin function f1
	.align	2
f1:                                     ; @f1
; %bb.0:
	lea 0(r0)(r1*4), r0
	movl 4(r0), r0
	ret
                                        ; -- End function
	.globl	f2                              ; -- Begin function f2
	.align	2
f2:                                     ; @f2
; %bb.0:
	lea 0(r0)(r1*4), r0
	movl -4(r0), r0
	ret
                                        ; -- End function
	.globl	f3                              ; -- Begin function f3
	.align	2
f3:                                     ; @f3
; %bb.0:
	lea 0(r0)(r1*8), r0
	movq 24(r0), r0
	ret
                                        ; -- End function
	.globl	f4                              ; -- Begin function f4
	.align	2
f4:                                     ; @f4
; %bb.0:
	lea 0(r0)(r1*2), r0
	movzw 4(r0), r0
	ret
                                        ; -- End function
	.globl	f5                              ; -- Begin function f5
	.align	2
f5:                                     ; @f5
; %bb.0:
	add r1, r0
	movzb 5(r0), r0
	ret
                                        ; -- End function
	.globl	f6                              ; -- Begin function f6
	.align	2
f6:                                     ; @f6
; %bb.0:
	shl #4, r1
	movq r0, r2
	add r1, r2
	movq 24(r2), r2
	movl 0(r0)(r1*1), r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	st                              ; -- Begin function st
	.align	2
st:                                     ; @st
; %bb.0:
	lea 0(r0)(r1*4), r3
	movl r2, 8(r3)
	lea 1(r2), r2
	movl r2, 0(r0)(r1*4)
	ret
                                        ; -- End function
	.globl	f7                              ; -- Begin function f7
	.align	2
f7:                                     ; @f7
; %bb.0:
	shl #4, r1
	add r0, r1
	lea 0(r1)(r2*4), r0
	movl 20(r0), r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	movq r14, r0
	lea -96(r0), r0
	and #-16, r0
	movq r0, r14
	clr r1
	movq #8, r2
.LBB8_1:                                ; =>This Inner Loop Header: Depth=1
	movq r0, r3
	add r2, r3
	movl r1, -8(r3)
	lea 100(r1), r3
	movq r3, 0(r0)(r2*1)
	lea 16(r2), r2
	lea 1(r1), r1
	cbne r1, #6, .LBB8_1
; %bb.2:
	movq 56(r0), r1
	movl 32(r0), r2
	add r1, r2
	clr r0
	cbeq r2, #105, .LBB8_4
; %bb.3:
	movq #16, r0
.LBB8_4:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
