	.text
	.globl	a1                              ; -- Begin function a1
	.align	2
a1:                                     ; @a1
; %bb.0:
	mul #3, r0
	lea 3(r0), r0
	ret
                                        ; -- End function
	.globl	a2                              ; -- Begin function a2
	.align	2
a2:                                     ; @a2
; %bb.0:
	cbgt r0, #0, .LBB1_1
; %bb.2:
	clr r0
	ret
.LBB1_1:
	shl #3, r0
	ret
                                        ; -- End function
	.globl	a3                              ; -- Begin function a3
	.align	2
a3:                                     ; @a3
; %bb.0:
	movq #11, r0
	ret
                                        ; -- End function
	.globl	a4                              ; -- Begin function a4
	.align	2
a4:                                     ; @a4
; %bb.0:
	lea 20(r0), r0
	ret
                                        ; -- End function
	.globl	a5                              ; -- Begin function a5
	.align	2
a5:                                     ; @a5
; %bb.0:
	movq r0, r1
	movq #7, r0
	cbgt r1, #5, .LBB4_2
; %bb.1:
	movq #9, r0
.LBB4_2:
	ret
                                        ; -- End function
	.globl	a6                              ; -- Begin function a6
	.align	2
a6:                                     ; @a6
; %bb.0:
	movq #15, r0
	ret
                                        ; -- End function
	.globl	a7                              ; -- Begin function a7
	.align	2
a7:                                     ; @a7
; %bb.0:
	movq #-56, r0
	ret
                                        ; -- End function
	.globl	a8                              ; -- Begin function a8
	.align	2
a8:                                     ; @a8
; %bb.0:
	movq #4, r0
	ret
                                        ; -- End function
	.globl	a9                              ; -- Begin function a9
	.align	2
a9:                                     ; @a9
; %bb.0:
	movq #5, r0
	ret
                                        ; -- End function
	.globl	a10                             ; -- Begin function a10
	.align	2
a10:                                    ; @a10
; %bb.0:
	ret
                                        ; -- End function
	.globl	a11                             ; -- Begin function a11
	.align	2
a11:                                    ; @a11
; %bb.0:
	lea 16(r0), r0
	ret
                                        ; -- End function
	.globl	a12                             ; -- Begin function a12
	.align	2
a12:                                    ; @a12
; %bb.0:
	lea -1(r0), r1
	br .LBB11_1
.LBB11_3:                               ;   in Loop: Header=BB11_1 Depth=1
	cbge r1, #4, .LBB11_4
.LBB11_1:                               ; =>This Inner Loop Header: Depth=1
	lea 1(r1), r1
	movq #1, r0
	cblt r1, #4, .LBB11_3
; %bb.2:                                ;   in Loop: Header=BB11_1 Depth=1
	clr r0
	br .LBB11_3
.LBB11_4:
	add r1, r0
	ret
                                        ; -- End function
	.globl	a13                             ; -- Begin function a13
	.align	2
a13:                                    ; @a13
; %bb.0:
	movq #12, r0
	ret
                                        ; -- End function
	.globl	a14                             ; -- Begin function a14
	.align	2
a14:                                    ; @a14
; %bb.0:
	movq #-5, r0
	ret
                                        ; -- End function
	.globl	a15                             ; -- Begin function a15
	.align	2
a15:                                    ; @a15
; %bb.0:
	movq r0, r1
	movq #1, r0
	cbeq r1, #0, .LBB14_2
; %bb.1:
	movq #2, r0
.LBB14_2:
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	ret
                                        ; -- End function
	.bss
	.globl	zero                            ; @zero
	.align	8
zero:
	.quad	0                               ; 0x0

