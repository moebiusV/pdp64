	.text
	.globl	m3                              ; -- Begin function m3
	.align	2
m3:                                     ; @m3
; %bb.0:
	mul #3, r0
	ret
                                        ; -- End function
	.globl	m5                              ; -- Begin function m5
	.align	2
m5:                                     ; @m5
; %bb.0:
	mul #5, r0
	ret
                                        ; -- End function
	.globl	m9                              ; -- Begin function m9
	.align	2
m9:                                     ; @m9
; %bb.0:
	mul #9, r0
	ret
                                        ; -- End function
	.globl	m3a                             ; -- Begin function m3a
	.align	2
m3a:                                    ; @m3a
; %bb.0:
	mul #3, r0
	lea 7(r0), r0
	ret
                                        ; -- End function
	.globl	m5a                             ; -- Begin function m5a
	.align	2
m5a:                                    ; @m5a
; %bb.0:
	mul #5, r0
	lea -100(r0), r0
	ret
                                        ; -- End function
	.globl	m9a                             ; -- Begin function m9a
	.align	2
m9a:                                    ; @m9a
; %bb.0:
	mul #9, r0
	lea 100000(r0), r0
	ret
                                        ; -- End function
	.globl	im5                             ; -- Begin function im5
	.align	2
im5:                                    ; @im5
; %bb.0:
	mul #5, r0
	lea 1(r0), r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	idx                             ; -- Begin function idx
	.align	2
idx:                                    ; @idx
; %bb.0:
	mul #40, r1
	add r0, r1
	movq 16(r1), r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	movq r14, r0
	lea -160(r0), r0
	and #-16, r0
	movq r0, r14
	clr r1
	clr r2
.LBB8_1:                                ; =>This Inner Loop Header: Depth=1
	movq r1, 0(r0)(r2*8)
	lea 1(r2), r2
	lea 100(r1), r1
	cbne r2, #20, .LBB8_1
; %bb.2:
	movq 136(r0), r1
	movq 16(r0), r2
	clr r0
	cbeq r2, #200, .LBB8_4
; %bb.3:
	movq #8, r0
.LBB8_4:
	cbeq r1, #1700, .LBB8_6
; %bb.5:
	movq #8, r0
.LBB8_6:
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
