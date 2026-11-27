; System v1 console: receive (one character polled, the rest of the line by interrupts at level 4, vector 33), echo by polling, then transmit by interrupts (vector 34).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	=MAP_CONSOLE, r13
	lea	buf, r12
	mov	#0, r8
	mov	#0, r7
	; polled: wait for the first character and store it
1:	mov	CONSOLE_REG_RXCS(r13), r3
	and	#(1<<CONSOLE_CSR_READY), r3
	cbeq	r3, #0, 1b
	mov	CONSOLE_REG_RXDB(r13), r2
	mov.s8	r2, (r12)+
	; interrupt driven: the handler stores the rest of the line; at priority 0 the level-4 request is taken
	mov	#(1<<CONSOLE_CSR_IE), r2
	mov	r2, CONSOLE_REG_RXCS(r13)
	spl	#0
2:	cbeq r8, #0, 2b
	spl	#7
	mov	#0, r2
	mov	r2, CONSOLE_REG_RXCS(r13)
	; echo the buffer, polled
	lea	buf, r1
3:	mov.s8	(r1)+, r2
	cbeq r2, #0, 4f
	call	putc
	br	3b
	; output driven by interrupts: the handler sends the next character of msg2 while TXCS IE is set
4:	lea	msg2, r10
	mov	#(1<<CONSOLE_CSR_IE), r2
	mov	r2, CONSOLE_REG_TXCS(r13)
	spl	#0
5:	cbeq r7, #0, 5b
	mov	#0, r0
	halt
putc:	mov	CONSOLE_REG_TXCS(r13), r3
	and	#(1<<CONSOLE_CSR_READY), r3
	cbeq	r3, #0, putc
	mov	r2, CONSOLE_REG_TXDB(r13)
	ret
h_rx:	mov	CONSOLE_REG_RXDB(r13), r9
	mov.s8	r9, (r12)+
	cbne r9, #10, 1f
	mov	#1, r8
1:	rti	#RTIMASK_ALL
h_tx:	mov.s8	(r10)+, r9
	cbne r9, #0, 1f
	mov	#0, r9
	mov	r9, CONSOLE_REG_TXCS(r13)
	mov	#1, r7
	rti	#RTIMASK_ALL
1:	mov	r9, CONSOLE_REG_TXDB(r13)
	rti	#RTIMASK_ALL
	.data
	.align	8
vtab:
	.space	264
	.quad	h_rx
	.quad	h_tx
	.space	3816
msg2:	.ascii	"tx-irq\n\0"
buf:	.space	64
