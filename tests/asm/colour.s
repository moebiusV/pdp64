; granule colours: ldcol, mcol, mcolrd and mcolwr (R2 and R3 words), and the aliases colset and colstrip (insb and extb with fixed fields).
; The words in colour.words were worked by hand from spec/grammars.d/20-enc-forms.hbnf, not copied from the assembler, and tools/check-enc.py gives the same parcels for the
; five encodings of tests/enc/vectors.txt.
	.text
	ldcol	r1, r2			; R2: 110100000100, o1 (5), o2 (5), subop 68
	ldcol	r31, r30
	mcol	r2, r1, r3		; R3: 1100101000, subop 30
	mcolrd	r4, r5, r6		; subop 31
	mcolwr	r4, r5, r6		; subop 32
	mcolwr	r31, r30, r29
	colset	r1, r2			; insb r1, $60, $4, r2
	colset	$5, r3			; mov $5, r12 ; insb r12, $60, $4, r3
	colset	$15, r3
	colstrip r1, r2			; extb r1, $0, $60, r2
	colstrip r7			; extb r7, $0, $60, r7
