	.text
	.globl	ld                              ; -- Begin function ld
	.align	2
ld:                                     ; @ld
; %bb.0:
	movl r1, r1
	movq 0(r0)(r1*8), r1
	movq #1, r0
	cbne r1, #0, .LBB0_2
; %bb.1:
	clr r0
.LBB0_2:
	ret
                                        ; -- End function
	.globl	ldneg                           ; -- Begin function ldneg
	.align	2
ldneg:                                  ; @ldneg
; %bb.0:
	movl r1, r1
	movq 0(r0)(r1*8), r1
	movq #1, r0
	cbeq r1, #0, .LBB1_1
; %bb.2:
	cble r1, #-1, .LBB1_3
.LBB1_4:
	ret
.LBB1_1:
	clr r0
	cbgt r1, #-1, .LBB1_4
.LBB1_3:
	movq #-1, r0
	ret
                                        ; -- End function
	.globl	sh                              ; -- Begin function sh
	.align	2
sh:                                     ; @sh
; %bb.0:
	movzl r1, r1
	shl r1, r0
	movq #1, r2
	cble r0, #-1, .LBB2_1
; %bb.2:
	clr r1
	cbne r0, #0, .LBB2_3
.LBB2_4:
	movq r1, r0
	ret
.LBB2_1:
	movq #-1, r2
	clr r1
	cbeq r0, #0, .LBB2_4
.LBB2_3:
	movq r2, r1
	movq r1, r0
	ret
                                        ; -- End function
	.globl	shr                             ; -- Begin function shr
	.align	2
shr:                                    ; @shr
; %bb.0:
	movq r0, r2
	movzl r1, r0
	shr r0, r2
	movq #1, r0
	cbne r2, #0, .LBB3_2
; %bb.1:
	clr r0
.LBB3_2:
	ret
                                        ; -- End function
	.globl	three                           ; -- Begin function three
	.align	2
three:                                  ; @three
; %bb.0:
	movq #-1, r3
	cbge r0, r1, .LBB4_1
; %bb.2:
	clr r2
	cbne r0, r1, .LBB4_3
.LBB4_4:
	movq r2, r0
	ret
.LBB4_1:
	movq #1, r3
	clr r2
	cbeq r0, r1, .LBB4_4
.LBB4_3:
	movq r3, r2
	movq r2, r0
	ret
                                        ; -- End function
	.globl	chain                           ; -- Begin function chain
	.align	2
chain:                                  ; @chain
; %bb.0:
	movq r0, r1
	movq #10, r0
	cbeq r1, #1, .LBB5_5
; %bb.1:
	cblt r1, #1, .LBB5_2
; %bb.3:
	movq #30, r0
	cbgt r1, #7, .LBB5_5
; %bb.4:
	movq #40, r0
.LBB5_5:
	ret
.LBB5_2:
	movq #20, r0
	ret
                                        ; -- End function
	.globl	ext                             ; -- Begin function ext
	.align	2
ext:                                    ; @ext
; %bb.0:
	movzb 0(r0), r1
	movq #1, r0
	cbne r1, #0, .LBB6_2
; %bb.1:
	clr r0
.LBB6_2:
	ret
                                        ; -- End function
	.globl	usub                            ; -- Begin function usub
	.align	2
usub:                                   ; @usub
; %bb.0:
	movzl r1, r1
	movzl r0, r2
	movq #1, r0
	cbne r2, r1, .LBB7_2
; %bb.1:
	clr r0
.LBB7_2:
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	lea g, r0
	movq 0(r0), r3
	movq #2, r1
	cbeq r3, #0, .LBB8_1
.LBB8_13:
	movl r1, r0
	ret
.LBB8_1:
	lea g+8, r0
	movq 0(r0), r0
	cbeq r0, #0, .LBB8_13
; %bb.2:
	lea g+16, r1
	movq 0(r1), r2
	movq #1, r1
	movq #1, r4
	cbeq r2, #0, .LBB8_4
; %bb.3:
	clr r4
.LBB8_4:
	lea g+24, r5
	movq 0(r5), r5
	cbne r5, #0, .LBB8_6
; %bb.5:
	clr r1
.LBB8_6:
	bis r1, r4
	movq #2, r1
	cbne r4, #0, .LBB8_8
; %bb.7:
	movq #3, r1
.LBB8_8:
	cbne r3, #0, .LBB8_13
; %bb.9:
	and #1, r4
	cbne r4, #0, .LBB8_13
; %bb.10:
	cblt r0, #1, .LBB8_12
; %bb.11:
	movq #1, r1
	cblt r2, #0, .LBB8_13
.LBB8_12:
	movq #3, r1
	movl r1, r0
	ret
                                        ; -- End function
	.data
	.globl	g                               ; @g
	.align	16
g:
	.quad	0                               ; 0x0
	.quad	5                               ; 0x5
	.quad	-3                              ; 0xfffffffffffffffd
	.quad	0                               ; 0x0

