	.text
	.globl	off1                            ; -- Begin function off1
	.align	2
off1:                                   ; @off1
; %bb.0:
	movq 40(r0), r1
	movq 800(r0), r2
	add r1, r2
	movq -24(r0), r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	off2                            ; -- Begin function off2
	.align	2
off2:                                   ; @off2
; %bb.0:
	movq 8(r0), r1
	movq 56(r0), r2
	add r1, r2
	movl 4(r0), r1
	add r2, r1
	movb 0(r0), r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	addr                            ; -- Begin function addr
	.align	2
addr:                                   ; @addr
; %bb.0:
	lea 4000(r0), r0
	ret
                                        ; -- End function
	.globl	diff                            ; -- Begin function diff
	.align	2
diff:                                   ; @diff
; %bb.0:
	sub r0, r1
	sar #3, r1
	movq r1, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	movq r14, r0
	lea -1600(r0), r0
	and #-16, r0
	movq r0, r14
	clr r1
	clr r2
.LBB4_1:                                ; =>This Inner Loop Header: Depth=1
	movq r1, 0(r0)(r2*8)
	lea 1(r2), r2
	lea 3(r1), r1
	cbne r2, #200, .LBB4_1
; %bb.2:
	movq 120(r0), r1
	movq 880(r0), r2
	add r1, r2
	movq 56(r0), r1
	add r2, r1
	movq #1, r0
	cbne r1, #396, .LBB4_4
; %bb.3:
	clr r0
.LBB4_4:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
