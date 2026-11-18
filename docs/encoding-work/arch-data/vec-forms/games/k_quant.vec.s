; k_quant (wave 2, errata 171): y[i] = clamp(trunc(x[i] * id), -128, 127), the quantisation of activations of an LLM loop (llama.cpp quantize_row_q8_0 rounds with roundf; this
; truncates toward zero, as the scalar FCVTSL and as a C cast do: a round-to-nearest would need a vector rounding word that is not in the family).  r0 = y (bytes), r1 = x (floats),
; r2 = id (a float in a general register), r3 = n.  Float to int32 in the lane (saturating), then the saturating narrowing store.  Without the conversion the loop is scalar.
k_quant:
	lea	(r1)(r3*4),r4
	vec	r1,r4
	vld.f	v0,(r1)+		; x
	vmul.f	v0,v0,r2		; x * id
	vcvt.f.l v1,v0			; int32, truncated, saturated
	vsts.l.b v1,(r0)+		; clamp to -128..127 and store bytes
	vend
	ret
