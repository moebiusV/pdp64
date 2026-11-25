	.text
	.globl	f1                              ; -- Begin function f1
	.align	2
f1:                                     ; @f1
; %bb.0:
	movl r2, r2
	movl r1, r3
	movl r0, r4
	movq #1, r1
	movq #1, r0
	cbge r4, r3, .LBB0_1
; %bb.2:
	cbge r3, r2, .LBB0_3
.LBB0_4:
	and r1, r0
	ret
.LBB0_1:
	clr r0
	cblt r3, r2, .LBB0_4
.LBB0_3:
	clr r1
	and r1, r0
	ret
                                        ; -- End function
	.globl	f2                              ; -- Begin function f2
	.align	2
f2:                                     ; @f2
; %bb.0:
	movl r2, r2
	movl r1, r3
	movl r0, r4
	movq #1, r1
	movq #1, r0
	cblt r4, r3, .LBB1_1
; %bb.2:
	cblt r3, r2, .LBB1_3
.LBB1_4:
	and r1, r0
	ret
.LBB1_1:
	clr r0
	cbge r3, r2, .LBB1_4
.LBB1_3:
	clr r1
	and r1, r0
	ret
                                        ; -- End function
	.globl	f3                              ; -- Begin function f3
	.align	2
f3:                                     ; @f3
; %bb.0:
	movzl r0, r0
	movl r1, r3
	movq #1, r2
	cbgt r3, #3, .LBB2_2
; %bb.1:
	clr r2
.LBB2_2:
	cbeq r0, #0, .LBB2_3
; %bb.4:
	movq r2, r1
	movq #20, r0
	cbne r1, #0, .LBB2_6
	br .LBB2_7
.LBB2_3:
	movq =2147483648, r0
	and r0, r1
	shr #31, r1
	movq #20, r0
	cbeq r1, #0, .LBB2_7
.LBB2_6:
	movq #10, r0
.LBB2_7:
	ret
                                        ; -- End function
	.globl	f4                              ; -- Begin function f4
	.align	2
f4:                                     ; @f4
; %bb.0:
	movq r0, r1
	cblt r1, #1, .LBB3_1
; %bb.2:                                ; %.preheader
	clr r0
	clr r2
	br .LBB3_3
.LBB3_5:                                ;   in Loop: Header=BB3_3 Depth=1
	add r2, r0
	lea 1(r2), r2
	cbeq r1, r2, .LBB3_6
.LBB3_3:                                ; =>This Inner Loop Header: Depth=1
	cbne r2, #4, .LBB3_5
; %bb.4:                                ;   in Loop: Header=BB3_3 Depth=1
	cblos r0, #1, .LBB3_5
	br .LBB3_7
.LBB3_1:
	clr r0
	ret
.LBB3_6:
	movq r1, r2
.LBB3_7:
	mul #100, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	f5                              ; -- Begin function f5
	.align	2
f5:                                     ; @f5
; %bb.0:
	movzl r1, r1
	movzl r0, r2
	movq #1, r0
	cbcs r2, r1, .LBB4_2
; %bb.1:
	clr r0
.LBB4_2:
	ret
                                        ; -- End function
	.globl	f6                              ; -- Begin function f6
	.align	2
f6:                                     ; @f6
; %bb.0:
	movl r1, r2
	cblt r2, #1, .LBB5_1
; %bb.2:
	movzl r1, r3
	clr r2
.LBB5_3:                                ; =>This Inner Loop Header: Depth=1
	movzl 0(r0)(r2*4), r4
	cbeq r4, #0, .LBB5_6
; %bb.4:                                ;   in Loop: Header=BB5_3 Depth=1
	lea 1(r2), r2
	cbne r3, r2, .LBB5_3
; %bb.5:
	movq r1, r2
.LBB5_6:
	movl r2, r0
	ret
.LBB5_1:
	clr r2
	movl r2, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	clr r1
	br .LBB6_1
.LBB6_3:                                ;   in Loop: Header=BB6_1 Depth=1
	add r1, r0
	lea 1(r1), r1
	cbeq r1, #10, .LBB6_4
.LBB6_1:                                ; =>This Inner Loop Header: Depth=1
	cbne r1, #4, .LBB6_3
; %bb.2:                                ;   in Loop: Header=BB6_1 Depth=1
	cblos r0, #1, .LBB6_3
	br .LBB6_5
.LBB6_4:
	movq #45, r0
	movq #10, r1
.LBB6_5:
	mul #100, r0
	add r1, r0
	clr r2
	cbeq r0, #604, .LBB6_18
; %bb.6:                                ; %.preheader
	clr r0
	clr r1
	br .LBB6_7
.LBB6_9:                                ;   in Loop: Header=BB6_7 Depth=1
	add r1, r0
	lea 1(r1), r1
	cbeq r1, #10, .LBB6_10
.LBB6_7:                                ; =>This Inner Loop Header: Depth=1
	cbne r1, #4, .LBB6_9
; %bb.8:                                ;   in Loop: Header=BB6_7 Depth=1
	cblos r0, #1, .LBB6_9
	br .LBB6_11
.LBB6_10:
	movq #45, r0
	movq #10, r1
.LBB6_11:
	mul #100, r0
	add r1, r0
	clr r1
	clr r2
	br .LBB6_12
.LBB6_14:                               ;   in Loop: Header=BB6_12 Depth=1
	add r2, r1
	lea 1(r2), r2
	cbeq r2, #10, .LBB6_15
.LBB6_12:                               ; =>This Inner Loop Header: Depth=1
	cbne r2, #4, .LBB6_14
; %bb.13:                               ;   in Loop: Header=BB6_12 Depth=1
	cblos r1, #1, .LBB6_14
	br .LBB6_16
.LBB6_15:
	movq #45, r1
	movq #10, r2
.LBB6_16:
	mul #100, r1
	add r2, r1
	clr r2
	cbeq r0, r1, .LBB6_18
; %bb.17:
	movq #8, r2
.LBB6_18:
	movl r2, r0
	ret
                                        ; -- End function
