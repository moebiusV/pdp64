	.text
	.globl	rl                              ; -- Begin function rl
	.align	2
rl:                                     ; @rl
; %bb.0:
	rol r0, #13, r0
	ret
                                        ; -- End function
	.globl	rr                              ; -- Begin function rr
	.align	2
rr:                                     ; @rr
; %bb.0:
	rol r0, #57, r0
	ret
                                        ; -- End function
	.globl	rs                              ; -- Begin function rs
	.align	2
rs:                                     ; @rs
; %bb.0:
	rol r0, #1, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	movq #1, r0
	ret
                                        ; -- End function
