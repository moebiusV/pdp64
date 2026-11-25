	.text
	.globl	chase                           ; -- Begin function chase
	.align	2
chase:                                  ; @chase
; %bb.0:
	movq 0(r0), r0
	movq 0(r0), r0
	movq 0(r0), r0
	movq 0(r0), r0
	ret
                                        ; -- End function
	.globl	walk                            ; -- Begin function walk
	.align	2
walk:                                   ; @walk
; %bb.0:
	movzl r1, r2
	cbeq r2, #0, .LBB1_2
.LBB1_1:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r1), r1
	movzl r1, r2
	movq 0(r0), r0
	cbne r2, #0, .LBB1_1
.LBB1_2:
	movq 8(r0), r0
	ret
                                        ; -- End function
	.globl	two                             ; -- Begin function two
	.align	2
two:                                    ; @two
; %bb.0:
	movq 0(r0), r2
	movzb 16(r2), r3
	movq #-1, r0
	cbne r3, #102, .LBB2_4
; %bb.1:
	movq 0(r2), r2
	movq 8(r2), r0
	movzb 16(r2), r2
	movl r1, r3
	movq #1, r1
	cblt r2, r3, .LBB2_3
; %bb.2:
	clr r1
.LBB2_3:
	add r1, r0
.LBB2_4:
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #80, sp
	lea .L__const.test.n3+16, r0
	movq 0(r0), r0
	movq r0, -8(r13)
	lea .L__const.test.n3+8, r0
	movq 0(r0), r0
	movq r0, -16(r13)
	lea .L__const.test.n3, r0
	movq 0(r0), r0
	movq r0, -24(r13)
	lea -24(r13), r0
	movq r0, -48(r13)
	movq #6, r0
	movq r0, -40(r13)
	movq #102, r0
	movb r0, -32(r13)
	lea -48(r13), r0
	movq r0, -72(r13)
	movq #5, r0
	movq r0, -64(r13)
	movq #1, r0
	movb r0, -56(r13)
	lea -72(r13), r0
	movq r0, -80(r13)
	lea -80(r13), r0
	movq #3, r1
.LBB3_1:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r1), r1
	movzl r1, r2
	movq 0(r0), r0
	cbne r2, #0, .LBB3_1
; %bb.2:
	movq 8(r0), r0
	cbne r0, #7, .LBB3_4
; %bb.3:
	movq -80(r13), r0
	movq 8(r0), r1
	clr r0
	cbeq r1, #5, .LBB3_5
.LBB3_4:
	movq #2, r0
.LBB3_5:
	movq -16(r13), r1
	cbne r1, #7, .LBB3_9
; %bb.6:
	movq -16(r13), r1
	movzb -8(r13), r3
	movq #1, r2
	cbcs r3, #9, .LBB3_8
; %bb.7:
	clr r2
.LBB3_8:
	add r2, r1
	cbeq r1, #8, .LBB3_10
.LBB3_9:
	bis #4, r0
.LBB3_10:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.data
	.align	8                               ; @__const.test.n3
.L__const.test.n3:
	.quad	0
	.quad	7                               ; 0x7
	.byte	3                               ; 0x3
	.space	7

