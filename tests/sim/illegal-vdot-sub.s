; the word vdotsu.b is not an instruction: its encoding (the sub-opcode of a three-vector lane word that no word uses) is an illegal instruction, as every other unassigned
; pattern is (exit 139).  It is written as two parcels and sits in a vec block that has run its loads, so that nothing but the encoding can refuse it.
	.text
	.globl _start
_start:
	lea buf, r1
	lea buf+96, r2
	vec r1, r2
	vld.b v0, (r1)+
	vld.b v1, (r1)+
	.word 0xD25E, 0xE201
	vend
	clr r0
	halt
	.data
	.align 8
buf:	.space 128
