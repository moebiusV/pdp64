; System v1 console: receive (one character polled, the rest of the line by interrupts at level 4, vector 33), echo by polling, then transmit by interrupts (vector 34).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	=MAP_CONSOLE, r13
	lea	buf, r12
	movq	#0, r8
	movq	#0, r7
	; polled: wait for the first character and store it
1:	movq	CONSOLE_REG_RXCS(r13), r3
	and	#(1<<CONSOLE_CSR_READY), r3
	beq	1b
	movq	CONSOLE_REG_RXDB(r13), r2
	movb	r2, (r12)+
	; interrupt driven: the handler stores the rest of the line; at priority 0 the level-4 request is taken
	movq	#(1<<CONSOLE_CSR_IE), r2
	movq	r2, CONSOLE_REG_RXCS(r13)
	spl	#0
2:	cmp	r8, #0
	beq	2b
	spl	#7
	movq	#0, r2
	movq	r2, CONSOLE_REG_RXCS(r13)
	; echo the buffer, polled
	lea	buf, r1
3:	movb	(r1)+, r2
	cmp	r2, #0
	beq	4f
	call	putc
	br	3b
	; output driven by interrupts: the handler sends the next character of msg2 while TXCS IE is set
4:	lea	msg2, r10
	movq	#(1<<CONSOLE_CSR_IE), r2
	movq	r2, CONSOLE_REG_TXCS(r13)
	spl	#0
5:	cmp	r7, #0
	beq	5b
	movq	#0, r0
	halt
putc:	movq	CONSOLE_REG_TXCS(r13), r3
	and	#(1<<CONSOLE_CSR_READY), r3
	beq	putc
	movq	r2, CONSOLE_REG_TXDB(r13)
	ret
h_rx:	movq	CONSOLE_REG_RXDB(r13), r9
	movb	r9, (r12)+
	cmp	r9, #10
	bne	1f
	movq	#1, r8
1:	rti
h_tx:	movb	(r10)+, r9
	cmp	r9, #0
	bne	1f
	movq	#0, r9
	movq	r9, CONSOLE_REG_TXCS(r13)
	movq	#1, r7
	rti
1:	movq	r9, CONSOLE_REG_TXDB(r13)
	rti
	.data
	.align	8
vtab:
	.space	264
	.quad	h_rx
	.quad	h_tx
	.space	3816
msg2:	.ascii	"tx-irq\n\0"
buf:	.space	64
