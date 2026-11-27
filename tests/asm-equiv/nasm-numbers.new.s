; NASM's number suffixes next to the local labels (errata 162): `1b` with a label 1 before it is the label (br 1b), `101b` with none is the binary number 5
	.text
1:	nop
	br	1b
	mov	#101b, r1
	mov	#0A5h, r2
	mov	#0ffh, r3
	mov	#377q, r4
	mov	#255d, r5
	mov	#1010b, r6
	mov	#A6h, r7
	mov	#1001b, r8
10:	br	10b
