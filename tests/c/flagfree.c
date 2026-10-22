/* expect: 1 -- code that must not depend on flags left by moves, loads, stores, cbCC or a shift by a zero count (errata 39): same result under both rules */
long g[4] = { 0, 5, -3, 0 };
long ld(long *p, int i) { long v = p[i]; if (v) return 1; return 0; }
long ldneg(long *p, int i) { long v = p[i]; if (v < 0) return -1; if (v > 0) return 1; return 0; }
long sh(long a, int n) { long r = a << n; if (r == 0) return 0; if (r < 0) return -1; return 1; }
long shr(unsigned long a, int n) { unsigned long r = a >> n; if (r) return 1; return 0; }
long three(long a, long b) { if (a == b) return 0; if (a < b) return -1; return 1; }
long chain(long x) { if (x == 1) return 10; if (x < 1) return 20; if (x > 7) return 30; return 40; }
long ext(unsigned char *p) { unsigned c = p[0]; if (c == 0) return 0; return 1; }
long usub(unsigned a, unsigned b) { unsigned d = a - b; if (d == 0) return 0; return 1; }

int test(void)
{
	unsigned char b[2] = { 0, 9 };
	if (ld(g, 0) != 0 || ld(g, 1) != 1 || ld(g, 2) != 1 || ld(g, 3) != 0) return 2;
	if (ldneg(g, 0) != 0 || ldneg(g, 1) != 1 || ldneg(g, 2) != -1) return 3;
	if (sh(0, 0) != 0 || sh(-4, 0) != -1 || sh(4, 0) != 1 || sh(1, 63) != -1 || sh(1, 1) != 1) return 4;
	if (shr(0, 0) != 0 || shr(8, 0) != 1 || shr(8, 4) != 0 || shr(8, 3) != 1) return 5;
	if (three(4, 4) != 0 || three(3, 4) != -1 || three(5, 4) != 1) return 6;
	if (chain(1) != 10 || chain(0) != 20 || chain(8) != 30 || chain(5) != 40) return 7;
	if (ext(b) != 0 || ext(b + 1) != 1) return 8;
	if (usub(5, 5) != 0 || usub(5, 4) != 1 || usub(0, 1) != 1) return 9;
	return 1;
}
