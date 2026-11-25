	.text
	.globl	add3                            ; -- Begin function add3
	.align	2
add3:                                   ; @add3
; %bb.0:
	mul #100, r0
	mul #10, r1
	add r1, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	direct                          ; -- Begin function direct
	.align	2
direct:                                 ; @direct
; %bb.0:
	mul #100, r0
	mul #10, r1
	add r0, r1
	lea 7(r1), r0
	ret
                                        ; -- End function
	.globl	indirect                        ; -- Begin function indirect
	.align	2
indirect:                               ; @indirect
; %bb.0:
	movq r1, r4
	movq r0, r3
	lea 1(r4), r1
	lea 2(r4), r2
	movq r4, r0
	call (r3)
	ret
                                        ; -- End function
	.globl	global                          ; -- Begin function global
	.align	2
global:                                 ; @global
; %bb.0:
	lea "fp", r1
	movq 0(r1), r3
	movq #1, r1
	movq #2, r2
	call (r3)
	ret
                                        ; -- End function
	.globl	method                          ; -- Begin function method
	.align	2
method:                                 ; @method
; %bb.0:
	movq 0(r0), r2
	call (r2)
	ret
                                        ; -- End function
	.globl	saved                           ; -- Begin function saved
	.align	2
saved:                                  ; @saved
; %bb.0:
	movq r0, r2
	mul #100, r2
	movq r1, r3
	mul #10, r3
	add r2, r3
	bis #1, r3
	movq =5270498306774157605, r2
	mulh r3, r2
	movq r2, r4
	shr #63, r4
	shr #1, r2
	add r4, r2
	mul #7, r2
	sub r2, r3
	mul #100, r3
	mul #10, r0
	add r1, r0
	add r3, r0
	ret
                                        ; -- End function
	.globl	viareg                          ; -- Begin function viareg
	.align	2
viareg:                                 ; @viareg
; %bb.0:
	movq r1, r3
	movq r0, r1
	mul #111, r0
	movq =7378697629483820647, r2
	mulh r0, r2
	movq r2, r4
	shr #63, r4
	sar #1, r2
	add r4, r2
	mul #5, r2
	sub r2, r0
	movq #3, r2
	call (r3)
	ret
                                        ; -- End function
	.globl	sink                            ; -- Begin function sink
	.align	2
sink:                                   ; @sink
; %bb.0:
	movq 0(r0), r1
	movq 8(r0), r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	local                           ; -- Begin function local
	.align	2
local:                                  ; @local
; %bb.0:
	mul #3, r0
	ret
                                        ; -- End function
	.globl	sum                             ; -- Begin function sum
	.align	2
sum:                                    ; @sum
; %bb.0:
	cbeq r0, #0, .LBB9_3
.LBB9_2:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r0), r2
	add r0, r1
	movq r2, r0
	cbne r0, #0, .LBB9_2
.LBB9_3:
	movq r1, r0
	ret
                                        ; -- End function
	.globl	cond                            ; -- Begin function cond
	.align	2
cond:                                   ; @cond
; %bb.0:
	cble r0, #0, .LBB10_2
; %bb.1:
	mul #111, r0
.LBB10_2:
	ret
                                        ; -- End function
	.globl	many                            ; -- Begin function many
	.align	2
many:                                   ; @many
; %bb.0:
	push fp
	movq sp, fp
	movq 16(r13), r6
	add r1, r0
	add r2, r0
	add r3, r0
	add r4, r0
	add r5, r0
	add r6, r0
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.globl	stackarg                        ; -- Begin function stackarg
	.align	2
stackarg:                               ; @stackarg
; %bb.0:
	lea 21(r0), r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #24, sp
	movq r8, -8(r13)                        ; 8-byte Folded Spill
	lea viaops, r0
	movq r0, -24(r13)
	movq #100, r0
	movq r0, -16(r13)
	lea "fp", r0
	movq 0(r0), r3
	movq #3, r0
	movq #1, r1
	movq #2, r2
	call (r3)
	clr r8
	cbeq r0, #312, .LBB13_2
; %bb.1:
	movq #4, r8
.LBB13_2:
	movq -24(r13), r2
	lea -24(r13), r0
	movq #5, r1
	call (r2)
	cbeq r0, #105, .LBB13_4
; %bb.3:
	bis #8, r8
.LBB13_4:
	movq #100, r0
	clr r1
	call sum
	cbeq r0, #5050, .LBB13_6
; %bb.5:
	bis #128, r8
.LBB13_6:
	movq r8, r0
	movq -8(r13), r8                        ; 8-byte Folded Reload
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.align	2                               ; -- Begin function viaops
viaops:                                 ; @viaops
; %bb.0:
	movq 8(r0), r0
	add r1, r0
	ret
                                        ; -- End function
	.data
	.globl	"fp"                            ; @fp
	.align	8
"fp":
	.quad	add3

