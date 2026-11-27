	.text
	mov $f64(2.5), r1
	mov $f32(2.5), r2
	cbeq r1, $f32(0.0), 1f
	.quad f64(1.5)
	.long f32(1.5)
	.word f16(1.5)
	.quad f64(1.5).s64
	.quad f64(1.5).f64
	.quad f64(1.5) + 1
	.quad f64(-0.5)
	.long f32(nan(0x400000)), f32(nan), f32(inf)
1:
