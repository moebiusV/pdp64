	.text
L:
	faddf r1, r2
	faddd r1, r2
	fadd r1, r2
	faddf r1, r2
	fsubf r1, r2
	fsubd r1, r2
	fsub r1, r2
	fsubf r1, r2
	fmulf r1, r2
	fmuld r1, r2
	fmul r1, r2
	fmulf r1, r2
	fdivf r1, r2
	fdivd r1, r2
	fdiv r1, r2
	fdivf r1, r2
	fsqrtf r1, r2
	fsqrtd r1, r2
	fsqrtd r3, r4
	fclassf r1, r2
	fclassd r1, r2
	fclassd r3, r4
	fabsf r1, r1
	fabsf r1, r2
	fabsd r1, r2
	fnegf r1, r1
	fnegf r1, r2
	fnegd r1, r2
	fmaddf r1, r2, r3, r4
	fmaddd r1, r2, r3, r4
	fnmsubf r1, r2, r3, r4
	fnmsubd r1, r2, r3, r4
	fcbeqf r1, r2, L
	fcbeqd r1, r2, L
	fcbnef r1, r2, L
	fcbned r1, r2, L
	fcbltf r1, r2, L
	fcbltd r1, r2, L
	fcblef r1, r2, L
	fcbled r1, r2, L
	fcbgtf r1, r2, L
	fcbgtd r1, r2, L
	fcbgef r1, r2, L
	fcbged r1, r2, L
	fcborf r1, r2, L
	fcbord r1, r2, L
	fcbuof r1, r2, L
	fcbuod r1, r2, L
	fcvtdf r1, r2
	fcvtfd r1, r2
	fcvtdf r1.64, r2.32
	fcvtfd r1.32, r2.64
