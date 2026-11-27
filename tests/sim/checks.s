; the check instructions that do not trap (errata 152, 159): every check below passes, so the program runs to its end.
	.text
	.globl	_start
_start:
	mov	#5, r1
	mov	#10, r2
	mov	#0, r3
	mov	#7, r4
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
	mov	#-3, r6
	chk2	r1, r3, r2		; 0 <= 5 < 10
	chk2	r6, r6, r3		; -3 <= -3 < 0
	mov	#0, r0
	trap	#0
f1:	mov	#1, r0
	trap	#0
f2:	mov	#2, r0
	trap	#0
