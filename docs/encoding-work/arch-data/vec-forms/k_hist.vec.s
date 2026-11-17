; k_hist (LightGBM ConstructHistogramInner, indices, hessian, uint8 bins): ti = data[idx[i]] << 1; out[ti] += g[i]; out[ti+1] += h[i].
; r0 = data, r1 = idx + start, r2 = idx + end (the region), r4 = g, r5 = h, r6 = out (doubles).
; A gather of the bins and two scatter-adds.  The scatter-add applies its lanes in order, so equal bins within a strip are correct; the hardware may serialise.
k_hist:
	vec	r1,r2
	vld.l	v0,(r1)+		; idx[i]
	vldx.bu.l v1,(r0)[v0]		; data[idx[i]]: a gather of bytes, lane i from r0 + v0[i]
	vshl.l	v1,#1			; ti
	vld.f.d	v2,(r4)+		; g[i], float widened to double lanes
	vaddx.d	(r6)[v1*8],v2		; out[ti] += g[i]   (index scaled by 8, a double)
	vld.f.d	v3,(r5)+
	vor.l	v1,#1			; ti + 1
	vaddx.d	(r6)[v1*8],v3		; out[ti+1] += h[i]
	vend
	ret
