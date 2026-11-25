	.text
	.globl	bump                            ; -- Begin function bump
	.align	2
bump:                                   ; @bump
; %bb.0:
	lea calls, r0
	movl 0(r0), r1
	lea 1(r1), r1
	movl r1, 0(r0)
	lea g1, r0
	movl 0(r0), r1
	lea 100(r1), r1
	movl r1, 0(r0)
	movl r1, r0
	ret
                                        ; -- End function
	.globl	twice                           ; -- Begin function twice
	.align	2
twice:                                  ; @twice
; %bb.0:
	movl 0(r0), r0
	shl #1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	between                         ; -- Begin function between
	.align	2
between:                                ; @between
; %bb.0:
	movl 0(r0), r2
	movq #9, r3
	movl r3, 0(r1)
	movl 0(r0), r0
	mul #1000, r2
	add r0, r2
	movl r2, r0
	ret
                                        ; -- End function
	.globl	acall                           ; -- Begin function acall
	.align	2
acall:                                  ; @acall
; %bb.0:
	lea g1, r0
	movl 0(r0), r1
	lea calls, r2
	movl 0(r2), r3
	lea 1(r3), r3
	movl r3, 0(r2)
	lea 100(r1), r1
	movl r1, 0(r0)
	movq #100, r0
	ret
                                        ; -- End function
	.globl	vtwice                          ; -- Begin function vtwice
	.align	2
vtwice:                                 ; @vtwice
; %bb.0:
	lea vol, r0
	movl 0(r0), r1
	movl 0(r0), r0
	add r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	narrow                          ; -- Begin function narrow
	.align	2
narrow:                                 ; @narrow
; %bb.0:
	movq =-5000004814, r0
	ret
                                        ; -- End function
	.globl	fwd                             ; -- Begin function fwd
	.align	2
fwd:                                    ; @fwd
; %bb.0:
	shl #1, r0
	bis #1, r0
	ret
                                        ; -- End function
	.globl	cloop                           ; -- Begin function cloop
	.align	2
cloop:                                  ; @cloop
; %bb.0:
	movl r0, r1
	cbgt r1, #0, .LBB7_1
; %bb.2:
	clr r1
	movl r1, r0
	ret
.LBB7_1:
	lea g1, r1
	movl 0(r1), r1
	mul r0, r1
	movl r1, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	lea g1, r0
	lea calls, r1
	movl 0(r1), r2
	lea 1(r2), r2
	movl r2, 0(r1)
	lea vol, r1
	movq #6, r2
	movl r2, 0(r1)
	movl 0(r1), r2
	movl 0(r1), r1
	add r2, r1
	movzl r1, r1
	movq #3, r2
	movl r2, 0(r0)
	clr r0
	cbeq r1, #12, .LBB8_2
; %bb.1:
	movq #8, r0
.LBB8_2:
	ret
                                        ; -- End function
	.data
	.globl	g1                              ; @g1
	.align	4
g1:
	.long	5                               ; 0x5

	.globl	g2                              ; @g2
	.align	8
g2:
	.quad	7                               ; 0x7

	.align	4                               ; @calls
calls:
	.long	0                               ; 0x0

	.bss
	.globl	vol                             ; @vol
	.align	4
vol:
	.long	0                               ; 0x0

