; NASM's number suffixes next to the local labels (errata 162): `1b` with a label 1 before it is the label (br 1b), `101b` with none is the binary number 5
	.text
1:	nop
	br	1b
	movq	#101b, r1
	movq	#0A5h, r2
	movq	#0ffh, r3
	movq	#377q, r4
	movq	#255d, r5
	movq	#1010b, r6
	movq	#A6h, r7
	movq	#1001b, r8
10:	br	10b
beadh:	nop
	br	beadh
	br	fadeh
fadeh:	nop
