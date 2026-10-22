/* expect: 1 -- compare registers and branch (cbCC ra,rb,label): signed and unsigned, equal, less, greater, the smallest and largest 64-bit values in both register orders */
long lt(long a, long b)  { if (a < b) return 1; return 0; }
long le(long a, long b)  { if (a <= b) return 1; return 0; }
long gt(long a, long b)  { if (a > b) return 1; return 0; }
long ge(long a, long b)  { if (a >= b) return 1; return 0; }
long eq(long a, long b)  { if (a == b) return 1; return 0; }
long ne(long a, long b)  { if (a != b) return 1; return 0; }
long ult(unsigned long a, unsigned long b) { if (a < b) return 1; return 0; }
long ule(unsigned long a, unsigned long b) { if (a <= b) return 1; return 0; }
long ugt(unsigned long a, unsigned long b) { if (a > b) return 1; return 0; }
long uge(unsigned long a, unsigned long b) { if (a >= b) return 1; return 0; }
long ilt(int a, int b)   { if (a < b) return 1; return 0; }
long ult32(unsigned a, unsigned b) { if (a < b) return 1; return 0; }
/* the flags are used after the branch: a second test on the same compare */
long three(long a, long b) { if (a == b) return 0; if (a < b) return -1; return 1; }
long loop(long n) { long i, s = 0; for (i = 0; i < n; i++) s += i; return s; }

int test(void)
{
	long min = -9223372036854775807L - 1, max = 9223372036854775807L;
	unsigned long umax = ~0UL;
	if (lt(1, 2) != 1 || lt(2, 1) != 0 || lt(1, 1) != 0) return 2;
	if (lt(min, max) != 1 || lt(max, min) != 0 || lt(min, min) != 0) return 3;
	if (le(min, max) != 1 || le(max, min) != 0 || le(max, max) != 1) return 4;
	if (gt(max, min) != 1 || gt(min, max) != 0 || gt(0, -1) != 1) return 5;
	if (ge(min, max) != 0 || ge(max, min) != 1 || ge(min, min) != 1) return 6;
	if (eq(min, min) != 1 || eq(min, max) != 0 || ne(min, max) != 1 || ne(max, max) != 0) return 7;
	if (ult(1, 2) != 1 || ult(umax, 0) != 0 || ult(0, umax) != 1 || ult(umax, umax) != 0) return 8;
	if (ule(umax, umax) != 1 || ule(umax, 0) != 0 || ule(0, umax) != 1) return 9;
	if (ugt(umax, 0) != 1 || ugt(0, umax) != 0 || ugt(5, 5) != 0) return 10;
	if (uge(0, umax) != 0 || uge(umax, 0) != 1 || uge(7, 7) != 1) return 11;
	if (ult(0x8000000000000000UL, 1) != 0 || ult(1, 0x8000000000000000UL) != 1) return 12;
	if (ilt(-2147483647 - 1, 2147483647) != 1 || ilt(2147483647, -2147483647 - 1) != 0) return 13;
	if (ult32(0x80000000u, 1u) != 0 || ult32(1u, 0xffffffffu) != 1 || ult32(0xffffffffu, 0xffffffffu) != 0) return 14;
	if (three(1, 1) != 0 || three(1, 2) != -1 || three(2, 1) != 1 || three(min, max) != -1 || three(max, min) != 1) return 15;
	if (loop(10) != 45 || loop(0) != 0) return 16;
	return 1;
}
