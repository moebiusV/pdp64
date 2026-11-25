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
	.globl	ilt                             ; -- Begin function ilt
	.align	2
ilt:                                    ; @ilt
; %bb.0:
	movl r1, r1
	movl r0, r2
	movq #1, r0
	cblt r2, r1, .LBB10_2
; %bb.1:
	clr r0
.LBB10_2:
	ret
                                        ; -- End function
	.globl	ult32                           ; -- Begin function ult32
	.align	2
ult32:                                  ; @ult32
; %bb.0:
	movzl r1, r1
	movzl r0, r2
	movq #1, r0
	cbcs r2, r1, .LBB11_2
; %bb.1:
	clr r0
.LBB11_2:
	ret
                                        ; -- End function
	.globl	three                           ; -- Begin function three
	.align	2
three:                                  ; @three
; %bb.0:
	movq #-1, r3
	cbge r0, r1, .LBB12_1
; %bb.2:
	clr r2
	cbne r0, r1, .LBB12_3
.LBB12_4:
	movq r2, r0
	ret
.LBB12_1:
	movq #1, r3
	clr r2
	cbeq r0, r1, .LBB12_4
.LBB12_3:
	movq r3, r2
	movq r2, r0
	ret
                                        ; -- End function
	.globl	loop                            ; -- Begin function loop
	.align	2
loop:                                   ; @loop
; %bb.0:
	cblt r0, #1, .LBB13_1
; %bb.2:
	lea -1(r0), r1
	lea -2(r0), r2
	movq r1, r0
	mul r2, r0
	mulhu r1, r2, r2
	shl #63, r2
	shr #1, r0
	bis r2, r0
	add r1, r0
	ret
.LBB13_1:
	clr r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	movq #1, r0
	ret
                                        ; -- End function
