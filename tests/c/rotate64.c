/* expect: 1 -- rotates of a 64-bit value by constants: rol (the assembler turns it into rori), left and right, in a register that is also an operand */
unsigned long rl(unsigned long x) { return (x << 13) | (x >> 51); }
unsigned long rr(unsigned long x) { return (x >> 7) | (x << 57); }
long rs(long x) { return (long)(((unsigned long)x << 1) | ((unsigned long)x >> 63)); }
int test(void)
{
	unsigned long v = 0x8000000000000001UL;
	if (rl(v) != 0x0000000000003000UL) return 2;
	if (rr(v) != 0x0300000000000000UL) return 3;
	if (rl(1UL) != 0x2000UL) return 4;
	if (rr(1UL) != 0x0200000000000000UL) return 5;
	if (rs(-1L) != -1L) return 6;
	if (rs(0x4000000000000000L) != (long)0x8000000000000000UL) return 7;
	if (rl(rl(v)) != ((v << 26) | (v >> 38))) return 8;
	return 1;
}
