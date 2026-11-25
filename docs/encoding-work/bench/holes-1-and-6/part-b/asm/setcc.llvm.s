	.text
	.globl	lt                              ; -- Begin function lt
	.align	2
lt:                                     ; @lt
; %bb.0:
	movq r0, r2
	movq #1, r0
	cblt r2, r1, .LBB0_2
; %bb.1:
	clr r0
.LBB0_2:
	ret
                                        ; -- End function
	.globl	le                              ; -- Begin function le
	.align	2
le:                                     ; @le
; %bb.0:
	movq r0, r2
	movq #1, r0
	cble r2, r1, .LBB1_2
; %bb.1:
	clr r0
.LBB1_2:
	ret
                                        ; -- End function
	.globl	gt                              ; -- Begin function gt
	.align	2
gt:                                     ; @gt
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbgt r2, r1, .LBB2_2
; %bb.1:
	clr r0
.LBB2_2:
	ret
                                        ; -- End function
	.globl	ge                              ; -- Begin function ge
	.align	2
ge:                                     ; @ge
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbge r2, r1, .LBB3_2
; %bb.1:
	clr r0
.LBB3_2:
	ret
                                        ; -- End function
	.globl	eq                              ; -- Begin function eq
	.align	2
eq:                                     ; @eq
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbeq r2, r1, .LBB4_2
; %bb.1:
	clr r0
.LBB4_2:
	ret
                                        ; -- End function
	.globl	ne                              ; -- Begin function ne
	.align	2
ne:                                     ; @ne
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbne r2, r1, .LBB5_2
; %bb.1:
	clr r0
.LBB5_2:
	ret
                                        ; -- End function
	.globl	ult                             ; -- Begin function ult
	.align	2
ult:                                    ; @ult
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbcs r2, r1, .LBB6_2
; %bb.1:
	clr r0
.LBB6_2:
	ret
                                        ; -- End function
	.globl	ule                             ; -- Begin function ule
	.align	2
ule:                                    ; @ule
; %bb.0:
	movq r0, r2
	movq #1, r0
	cblos r2, r1, .LBB7_2
; %bb.1:
	clr r0
.LBB7_2:
	ret
                                        ; -- End function
	.globl	ugt                             ; -- Begin function ugt
	.align	2
ugt:                                    ; @ugt
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbhi r2, r1, .LBB8_2
; %bb.1:
	clr r0
.LBB8_2:
	ret
                                        ; -- End function
	.globl	uge                             ; -- Begin function uge
	.align	2
uge:                                    ; @uge
; %bb.0:
	movq r0, r2
	movq #1, r0
	cbcc r2, r1, .LBB9_2
; %bb.1:
	clr r0
.LBB9_2:
	ret
                                        ; -- End function
	.globl	lt0                             ; -- Begin function lt0
	.align	2
lt0:                                    ; @lt0
; %bb.0:
	shr #63, r0
	ret
                                        ; -- End function
	.globl	eq0                             ; -- Begin function eq0
	.align	2
eq0:                                    ; @eq0
; %bb.0:
	movq r0, r1
	movq #1, r0
	cbeq r1, #0, .LBB11_2
; %bb.1:
	clr r0
.LBB11_2:
	ret
                                        ; -- End function
	.globl	gt5                             ; -- Begin function gt5
	.align	2
gt5:                                    ; @gt5
; %bb.0:
	movq r0, r1
	movq #1, r0
	cbgt r1, #5, .LBB12_2
; %bb.1:
	clr r0
.LBB12_2:
	ret
                                        ; -- End function
	.globl	ne7                             ; -- Begin function ne7
	.align	2
ne7:                                    ; @ne7
; %bb.0:
	movq r0, r1
	movq #1, r0
	cbne r1, #7, .LBB13_2
; %bb.1:
	clr r0
.LBB13_2:
	ret
                                        ; -- End function
	.globl	ilt                             ; -- Begin function ilt
	.align	2
ilt:                                    ; @ilt
; %bb.0:
	movl r1, r1
	movl r0, r2
	movq #1, r0
	cblt r2, r1, .LBB14_2
; %bb.1:
	clr r0
.LBB14_2:
	ret
                                        ; -- End function
	.globl	sgn                             ; -- Begin function sgn
	.align	2
sgn:                                    ; @sgn
; %bb.0:
	movq r0, r1
	sar #63, r0
	movq #1, r2
	cbne r1, #0, .LBB15_2
; %bb.1:
	clr r2
.LBB15_2:
	bis r2, r0
	ret
                                        ; -- End function
	.globl	cnt                             ; -- Begin function cnt
	.align	2
cnt:                                    ; @cnt
; %bb.0:
	movq r0, r3
	clr r0
	cbge r1, #1, .LBB16_1
.LBB16_4:
	ret
.LBB16_3:                               ;   in Loop: Header=BB16_1 Depth=1
	add r4, r0
	lea -1(r1), r1
	cbeq r1, #0, .LBB16_4
.LBB16_1:                               ; =>This Inner Loop Header: Depth=1
	movq (r3)+, r5
	movq #1, r4
	cbgt r5, r2, .LBB16_3
; %bb.2:                                ;   in Loop: Header=BB16_1 Depth=1
	clr r4
	br .LBB16_3
                                        ; -- End function
	.globl	both                            ; -- Begin function both
	.align	2
both:                                   ; @both
; %bb.0:
	movq #1, r3
	cbgt r0, r1, .LBB17_2
; %bb.1:
	clr r3
.LBB17_2:
	movq #10, r2
	cblt r0, r1, .LBB17_4
; %bb.3:
	clr r2
.LBB17_4:
	bis r3, r2
	movq r2, r0
	ret
                                        ; -- End function
	.globl	nest                            ; -- Begin function nest
	.align	2
nest:                                   ; @nest
; %bb.0:
	movq #1, r4
	cblt r0, r1, .LBB18_2
; %bb.1:
	clr r4
.LBB18_2:
	movq #2, r3
	cblt r1, r2, .LBB18_4
; %bb.3:
	clr r3
.LBB18_4:
	bis r4, r3
	movq #4, r1
	cbeq r0, r2, .LBB18_6
; %bb.5:
	clr r1
.LBB18_6:
	bis r1, r3
	movq r3, r0
	ret
                                        ; -- End function
	.globl	st                              ; -- Begin function st
	.align	2
st:                                     ; @st
; %bb.0:
	movq #1, r2
	cblt r1, #3, .LBB19_2
; %bb.1:
	clr r2
.LBB19_2:
	movq r2, 0(r0)
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	movq r14, r0
	lea -72(r0), r0
	and #-16, r0
	movq r0, r14
	clr r1
	br .LBB20_1
.LBB20_3:                               ;   in Loop: Header=BB20_1 Depth=1
	movq r2, 0(r0)(r1*8)
	lea 1(r1), r1
	cbeq r1, #9, .LBB20_4
.LBB20_1:                               ; =>This Inner Loop Header: Depth=1
	movq #1, r2
	cbcs r1, #4, .LBB20_3
; %bb.2:                                ;   in Loop: Header=BB20_1 Depth=1
	clr r2
	br .LBB20_3
.LBB20_4:                               ; %.preheader
	clr r2
	clr r1
	br .LBB20_5
.LBB20_7:                               ;   in Loop: Header=BB20_5 Depth=1
	add r3, r1
	lea 1(r2), r2
	cbeq r2, #9, .LBB20_8
.LBB20_5:                               ; =>This Inner Loop Header: Depth=1
	movq 0(r0)(r2*8), r4
	movq #1, r3
	cbgt r4, #0, .LBB20_7
; %bb.6:                                ;   in Loop: Header=BB20_5 Depth=1
	clr r3
	br .LBB20_7
.LBB20_8:
	clr r0
	cbeq r1, #4, .LBB20_10
; %bb.9:
	movq #256, r0
.LBB20_10:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
