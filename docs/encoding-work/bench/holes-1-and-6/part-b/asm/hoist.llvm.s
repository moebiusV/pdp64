	.text
	.globl	id                              ; -- Begin function id
	.align	2
id:                                     ; @id
; %bb.0:
	ret
                                        ; -- End function
	.globl	many                            ; -- Begin function many
	.align	2
many:                                   ; @many
; %bb.0:
	push fp
	movq sp, fp
	movq r0, r6
	movq 32(r13), r16
	movq 24(r13), r7
	movq 16(r13), r0
	add r7, r0
	cblt r16, #1, .LBB1_1
; %bb.2:
	movq r2, r7
	add r5, r7
	movq r4, r17
	add r1, r17
	sub r7, r17
	clr r7
	clr r18
.LBB1_3:                                ; =>This Inner Loop Header: Depth=1
	lea 1(r18), r19
	and #3, r18
	mul r3, r18
	add r17, r18
	xor r0, r18
	add r18, r7
	add r6, r17
	movq r19, r18
	cbne r16, r19, .LBB1_3
	br .LBB1_4
.LBB1_1:
	clr r7
.LBB1_4:
	add r6, r0
	add r1, r0
	add r2, r0
	add r3, r0
	add r4, r0
	add r5, r0
	add r7, r0
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.globl	stores                          ; -- Begin function stores
	.align	2
stores:                                 ; @stores
; %bb.0:
	cblt r5, #1, .LBB2_1
; %bb.2:
	add r1, r2
	add r4, r2
	clr r1
	clr r4
.LBB2_3:                                ; =>This Inner Loop Header: Depth=1
	movq r2, r6
	add r3, r6
	add r0, r6
	add r6, r1
	add r4, r0
	lea 1(r4), r6
	and #1, r4
	sub r4, r3
	movq r6, r4
	cbne r5, r6, .LBB2_3
	br .LBB2_4
.LBB2_1:
	clr r1
.LBB2_4:
	add r0, r3
	add r1, r3
	movq r3, r0
	ret
                                        ; -- End function
	.globl	nested                          ; -- Begin function nested
	.align	2
nested:                                 ; @nested
; %bb.0:
	push fp
	movq sp, fp
	movq 16(r13), r6
	cblt r1, #1, .LBB3_1
; %bb.2:
	movq r4, r16
	sub r5, r16
	add r6, r16
	clr r17
	clr r7
	br .LBB3_3
.LBB3_6:                                ;   in Loop: Header=BB3_3 Depth=1
	lea 1(r17), r17
	cbeq r17, r1, .LBB3_7
.LBB3_3:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB3_5 Depth 2
	cblt r2, #1, .LBB3_6
; %bb.4:                                ;   in Loop: Header=BB3_3 Depth=1
	movq r16, r18
	add r17, r18
	movq r0, r19
	movq r2, r20
.LBB3_5:                                ;   Parent Loop BB3_3 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq (r19)+, r21
	mul r3, r21
	add r18, r7
	add r21, r7
	lea -1(r20), r20
	cbne r20, #0, .LBB3_5
	br .LBB3_6
.LBB3_1:
	clr r7
.LBB3_7:
	add r3, r4
	add r5, r4
	add r6, r4
	add r7, r4
	movq r4, r0
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	movq r14, r0
	lea -48(r0), r0
	and #-16, r0
	movq r0, r14
	movq r0, r1
	bis #8, r1
	movq #1, r2
	movq r2, 0(r0)
	movq #2, r2
	movq r2, 0(r1)
	movq #3, r1
	movq r1, 16(r0)
	movq #4, r1
	movq r1, 24(r0)
	movq #5, r1
	movq r1, 32(r0)
	movq #6, r1
	movq r1, 40(r0)
	clr r2
	clr r1
.LBB4_1:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB4_2 Depth 2
	lea 4(r2), r3
	clr r4
.LBB4_2:                                ;   Parent Loop BB4_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq 0(r0)(r4*8), r5
	add r3, r1
	lea 0(r1)(r5*2), r1
	lea 1(r4), r4
	cbne r4, #4, .LBB4_2
; %bb.3:                                ;   in Loop: Header=BB4_1 Depth=1
	lea 1(r2), r2
	cbne r2, #3, .LBB4_1
; %bb.4:                                ; %.preheader
	clr r3
	clr r2
.LBB4_5:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB4_6 Depth 2
	lea 4(r3), r4
	clr r5
.LBB4_6:                                ;   Parent Loop BB4_5 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq 0(r0)(r5*8), r6
	add r4, r2
	lea 0(r2)(r6*2), r2
	lea 1(r5), r5
	cbne r5, #4, .LBB4_6
; %bb.7:                                ;   in Loop: Header=BB4_5 Depth=1
	lea 1(r3), r3
	cbne r3, #3, .LBB4_5
; %bb.8:
	clr r0
	cbeq r2, r1, .LBB4_10
; %bb.9:
	movq #4, r0
.LBB4_10:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
