	.text
	.globl	rl7                             ; -- Begin function rl7
	.align	2
rl7:                                    ; @rl7
; %bb.0:
	movq =4261412864, r1
	and r0, r1
	shr #25, r1
	shl #7, r0
	bis r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	rr3                             ; -- Begin function rr3
	.align	2
rr3:                                    ; @rr3
; %bb.0:
	movq =4294967288, r1
	and r0, r1
	shr #3, r1
	shl #29, r0
	bis r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	mix                             ; -- Begin function mix
	.align	2
mix:                                    ; @mix
; %bb.0:
	movq =4160749568, r2
	and r0, r2
	shr #27, r2
	shl #5, r0
	bis r2, r0
	add r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	less                            ; -- Begin function less
	.align	2
less:                                   ; @less
; %bb.0:
	movq =4292870144, r2
	and r0, r2
	movzl r1, r1
	shr #21, r2
	shl #11, r0
	bis r2, r0
	movzl r0, r2
	movq #1, r0
	cbcs r2, r1, .LBB3_2
; %bb.1:
	clr r0
.LBB3_2:
	ret
                                        ; -- End function
	.globl	wide                            ; -- Begin function wide
	.align	2
wide:                                   ; @wide
; %bb.0:
	movq =2147483648, r1
	and r0, r1
	shr #31, r1
	shl #1, r0
	bis r1, r0
	movzl r0, r0
	ret
                                        ; -- End function
	.globl	store                           ; -- Begin function store
	.align	2
store:                                  ; @store
; %bb.0:
	movzl r0, r1
	movq r0, r2
	shl #16, r2
	movq r1, r3
	shr #16, r3
	bis r2, r3
	lea st, r2
	movl r3, 0(r2)
	shl #24, r0
	shr #8, r1
	bis r0, r1
	lea st+4, r0
	movl r1, 0(r0)
	ret
                                        ; -- End function
	.globl	top                             ; -- Begin function top
	.align	2
top:                                    ; @top
; %bb.0:
	movq =4026531840, r1
	and r0, r1
	shr #28, r1
	shl #4, r0
	bis r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	topcmp                          ; -- Begin function topcmp
	.align	2
topcmp:                                 ; @topcmp
; %bb.0:
	shr #27, r0
	and #1, r0
	ret
                                        ; -- End function
	.globl	topwide                         ; -- Begin function topwide
	.align	2
topwide:                                ; @topwide
; %bb.0:
	movq =4026531840, r1
	and r0, r1
	shr #28, r1
	shl #4, r0
	bis r1, r0
	movzl r0, r0
	ret
                                        ; -- End function
	.globl	topshr                          ; -- Begin function topshr
	.align	2
topshr:                                 ; @topshr
; %bb.0:
	movq =3758096384, r1
	and r0, r1
	shr #28, r1
	shl #4, r0
	bis r1, r0
	movq =4294967294, r1
	and r1, r0
	shr #1, r0
	ret
                                        ; -- End function
	.globl	topdiv                          ; -- Begin function topdiv
	.align	2
topdiv:                                 ; @topdiv
; %bb.0:
	movq =4026531840, r1
	and r0, r1
	shr #28, r1
	shl #4, r0
	bis r1, r0
	movzl r0, r1
	movq =2863311531, r0
	mul r1, r0
	shr #33, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	lea st, r0
	movq #1450709556, r1
	movl r1, 0(r0)
	lea st+4, r0
	movq #2014458966, r1
	movl r1, 0(r0)
	movq #1, r0
	ret
                                        ; -- End function
	.bss
	.globl	st                              ; @st
	.align	4
st:
	.space	8

