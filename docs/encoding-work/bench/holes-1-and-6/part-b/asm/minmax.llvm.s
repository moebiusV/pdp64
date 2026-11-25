	.text
	.globl	mx                              ; -- Begin function mx
	.align	2
mx:                                     ; @mx
; %bb.0:
	cbgt r0, r1, .LBB0_2
; %bb.1:
	movq r1, r0
.LBB0_2:
	ret
                                        ; -- End function
	.globl	mn                              ; -- Begin function mn
	.align	2
mn:                                     ; @mn
; %bb.0:
	cblt r0, r1, .LBB1_2
; %bb.1:
	movq r1, r0
.LBB1_2:
	ret
                                        ; -- End function
	.globl	umx                             ; -- Begin function umx
	.align	2
umx:                                    ; @umx
; %bb.0:
	cbhi r0, r1, .LBB2_2
; %bb.1:
	movq r1, r0
.LBB2_2:
	ret
                                        ; -- End function
	.globl	umn                             ; -- Begin function umn
	.align	2
umn:                                    ; @umn
; %bb.0:
	cbcs r0, r1, .LBB3_2
; %bb.1:
	movq r1, r0
.LBB3_2:
	ret
                                        ; -- End function
	.globl	ab                              ; -- Begin function ab
	.align	2
ab:                                     ; @ab
; %bb.0:
	movq r0, r1
	sar #63, r1
	xor r1, r0
	sub r1, r0
	ret
                                        ; -- End function
	.globl	iab                             ; -- Begin function iab
	.align	2
iab:                                    ; @iab
; %bb.0:
	movl r0, r1
	sar #31, r1
	xor r1, r0
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	clamp                           ; -- Begin function clamp
	.align	2
clamp:                                  ; @clamp
; %bb.0:
	cble r0, r1, .LBB6_1
; %bb.2:
	cbge r0, r2, .LBB6_3
.LBB6_4:
	ret
.LBB6_1:
	movq r1, r0
	cblt r0, r2, .LBB6_4
.LBB6_3:
	movq r2, r0
	ret
                                        ; -- End function
	.globl	maxof                           ; -- Begin function maxof
	.align	2
maxof:                                  ; @maxof
; %bb.0:
	movq 0(r0), r3
	cblt r1, #2, .LBB7_5
; %bb.1:                                ; %.preheader
	lea -1(r1), r1
	lea 8(r0), r2
	br .LBB7_3
.LBB7_2:                                ;   in Loop: Header=BB7_3 Depth=1
	lea -1(r1), r1
	movq r0, r3
	cbeq r1, #0, .LBB7_6
.LBB7_3:                                ; =>This Inner Loop Header: Depth=1
	movq (r2)+, r0
	cbgt r0, r3, .LBB7_2
; %bb.4:                                ;   in Loop: Header=BB7_3 Depth=1
	movq r3, r0
	br .LBB7_2
.LBB7_5:
	movq r3, r0
.LBB7_6:
	ret
                                        ; -- End function
	.globl	umaxof                          ; -- Begin function umaxof
	.align	2
umaxof:                                 ; @umaxof
; %bb.0:
	movq 0(r0), r3
	cblt r1, #2, .LBB8_5
; %bb.1:                                ; %.preheader
	lea -1(r1), r1
	lea 8(r0), r2
	br .LBB8_3
.LBB8_2:                                ;   in Loop: Header=BB8_3 Depth=1
	lea -1(r1), r1
	movq r0, r3
	cbeq r1, #0, .LBB8_6
.LBB8_3:                                ; =>This Inner Loop Header: Depth=1
	movq (r2)+, r0
	cbhi r0, r3, .LBB8_2
; %bb.4:                                ;   in Loop: Header=BB8_3 Depth=1
	movq r3, r0
	br .LBB8_2
.LBB8_5:
	movq r3, r0
.LBB8_6:
	ret
                                        ; -- End function
	.globl	minof                           ; -- Begin function minof
	.align	2
minof:                                  ; @minof
; %bb.0:
	movq 0(r0), r3
	cblt r1, #2, .LBB9_5
; %bb.1:                                ; %.preheader
	lea -1(r1), r1
	lea 8(r0), r2
	br .LBB9_3
.LBB9_2:                                ;   in Loop: Header=BB9_3 Depth=1
	lea -1(r1), r1
	movq r0, r3
	cbeq r1, #0, .LBB9_6
.LBB9_3:                                ; =>This Inner Loop Header: Depth=1
	movq (r2)+, r0
	cblt r0, r3, .LBB9_2
; %bb.4:                                ;   in Loop: Header=BB9_3 Depth=1
	movq r3, r0
	br .LBB9_2
.LBB9_5:
	movq r3, r0
.LBB9_6:
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	lea test.v, r1
	movq #1, r2
	clr r6
	clr r3
	br .LBB10_1
.LBB10_26:                              ;   in Loop: Header=BB10_1 Depth=1
	lea 1(r3), r3
	cbeq r3, #8, .LBB10_27
.LBB10_1:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB10_8 Depth 2
	movq 0(r1)(r3*8), r4
	movq r4, r7
	cbcc r3, #3, .LBB10_3
; %bb.2:                                ;   in Loop: Header=BB10_1 Depth=1
	neg r7
.LBB10_3:                               ;   in Loop: Header=BB10_1 Depth=1
	movq r4, r5
	sar #63, r5
	movq r4, r17
	xor r5, r17
	sub r5, r17
	clr r5
	movq #1, r16
	cbne r17, r7, .LBB10_5
; %bb.4:                                ;   in Loop: Header=BB10_1 Depth=1
	clr r16
.LBB10_5:                               ;   in Loop: Header=BB10_1 Depth=1
	movq r4, r7
	cbgt r4, #-50, .LBB10_7
; %bb.6:                                ;   in Loop: Header=BB10_1 Depth=1
	movq #-50, r7
.LBB10_7:                               ;   in Loop: Header=BB10_1 Depth=1
	bis r16, r6
	br .LBB10_8
.LBB10_25:                              ;   in Loop: Header=BB10_8 Depth=2
	lea 1(r5), r5
	cbeq r5, #8, .LBB10_26
.LBB10_8:                               ;   Parent Loop BB10_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	cbne r0, #0, .LBB10_10
; %bb.9:                                ;   in Loop: Header=BB10_8 Depth=2
	cbne r2, #0, .LBB10_11
.LBB10_10:                              ;   in Loop: Header=BB10_8 Depth=2
	bis #4, r6
.LBB10_11:                              ;   in Loop: Header=BB10_8 Depth=2
	cbne r0, #0, .LBB10_13
; %bb.12:                               ;   in Loop: Header=BB10_8 Depth=2
	cbne r2, #0, .LBB10_14
.LBB10_13:                              ;   in Loop: Header=BB10_8 Depth=2
	bis #8, r6
.LBB10_14:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r6, r16
	movq 0(r1)(r5*8), r17
	movq r7, r6
	cbge r7, r17, .LBB10_15
; %bb.16:                               ;   in Loop: Header=BB10_8 Depth=2
	movq r4, r18
	cbge r4, r17, .LBB10_17
.LBB10_18:                              ;   in Loop: Header=BB10_8 Depth=2
	movq #-50, r17
	cbcc r3, #2, .LBB10_19
.LBB10_20:                              ;   in Loop: Header=BB10_8 Depth=2
	cbne r6, r17, .LBB10_21
.LBB10_22:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r16, r6
	cbhi r5, #1, .LBB10_25
	br .LBB10_24
.LBB10_15:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r17, r6
	movq r4, r18
	cblt r4, r17, .LBB10_18
.LBB10_17:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r17, r18
	movq #-50, r17
	cbcs r3, #2, .LBB10_20
.LBB10_19:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r18, r17
	cbeq r6, r17, .LBB10_22
.LBB10_21:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r16, r6
	bis #16, r6
	cbhi r5, #1, .LBB10_25
.LBB10_24:                              ;   in Loop: Header=BB10_8 Depth=2
	movq r16, r6
	br .LBB10_25
.LBB10_27:
	movl r6, r0
	ret
                                        ; -- End function
	.data
	.align	16                              ; @test.v
test.v:
	.quad	-9223372036854775808            ; 0x8000000000000000
	.quad	-100                            ; 0xffffffffffffff9c
	.quad	-1                              ; 0xffffffffffffffff
	.quad	0                               ; 0x0
	.quad	1                               ; 0x1
	.quad	7                               ; 0x7
	.quad	100                             ; 0x64
	.quad	9223372036854775807             ; 0x7fffffffffffffff

