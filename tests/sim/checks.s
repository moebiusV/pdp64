; the check instructions that do not trap (errata 152, 159): every check below passes, so the program runs to its end; the flags are neither read nor written
; (a compare before the checks is still in effect after them: the program tests Z at the end).
	.text
	.globl	_start
_start:
	movq	#5, r1
	movq	#10, r2
	movq	#0, r3
	movq	#7, r4
	cmp	r1, r1			; Z set
	ctcc	r1, #16			; 5 < 16 unsigned: no trap
	ctcc	r1, r2			; 5 < 10
	cthi	r1, #5			; not 5 > 5
	cteq	r1, #6			; 5 != 6
	ctne	r1, #5			; 5 == 5
	cteq	r4			; 7 != 0
	ctne	r3			; 0 == 0
	ctcs	r2, r1			; not 10 < 5 unsigned
	ctge	r1, r2			; not 5 >= 10 signed
	ctlt	r2, r1			; not 10 < 5 signed
	bne	f1
	movq	#-3, r6
	chk2	r1, r3, r2		; 0 <= 5 < 10
	chk2	r6, r6, r3		; -3 <= -3 < 0
	bne	f2
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
