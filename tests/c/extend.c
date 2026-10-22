/* expect: 1 -- sign and zero extension in C: conversions between widths, narrow loads, comparisons, shifts, division, unsigned wrap */
unsigned char ub[2] = { 0x80, 0xFF };
signed char sb[2] = { -128, -1 };
short ss[2] = { -32768, -1 };
unsigned short us[2] = { 32768, 65535 };
int is[2] = { -2147483647 - 1, -1 };
unsigned int un[2] = { 2147483648u, 4294967295u };

static int fail(int n) { return n; }

int test(void)
{
	volatile int vi = -1;
	volatile unsigned vu = 4294967295u;
	volatile signed char vc = -1;
	volatile unsigned char vuc = 255;
	volatile short vs = -2;
	int i; unsigned u; long l; unsigned long ul;

	if ((int)ub[0] != 128) return fail(2);				/* unsigned char zero-extends */
	if ((int)sb[0] != -128) return fail(3);				/* signed char sign-extends */
	if ((int)ss[0] != -32768) return fail(4);
	if ((int)us[0] != 32768) return fail(5);
	if ((long)is[0] != -2147483648L) return fail(6);
	if ((long)un[0] != 2147483648L) return fail(7);			/* unsigned int to long zero-extends */
	if ((unsigned)vc != 4294967295u) return fail(8);			/* signed char -1 to unsigned: 0xFFFFFFFF */
	if ((unsigned long)vc != 18446744073709551615UL) return fail(9);
	if ((unsigned long)vi != 18446744073709551615UL) return fail(10);	/* int -1 to unsigned long */
	if ((unsigned long)vu != 4294967295UL) return fail(11);		/* unsigned -1 to unsigned long */
	if ((unsigned char)vi != 255) return fail(12);
	if ((unsigned short)vi != 65535) return fail(13);
	if ((short)(vi * 65536 + 0x8000) == 0) return fail(14);
	l = 0x18000; if ((short)l != -32768) return fail(15);		/* truncation to short keeps the low 16 bits, sign-extended */
	l = 0x1FF; if ((signed char)l != -1) return fail(16);
	l = 0x1FF; if ((unsigned char)l != 255) return fail(17);
	u = 2147483647u; u += 1;
	if (u != 2147483648u) return fail(18);				/* unsigned add wraps at 32 bits */
	if ((long)(int)u != -2147483648L) return fail(19);		/* and the same bits as a signed int are negative */
	u = 4294967295u; u += 1;
	if (u != 0) return fail(20);
	if ((long)u != 0) return fail(21);
	u = 3000000000u; u = u * 2;
	if (u != 1705032704u) return fail(22);				/* 6000000000 mod 2^32 */
	i = vi; if (!(i < 0)) return fail(23);
	if (!(vuc > 0)) return fail(24);
	if (!(vc < 0)) return fail(25);
	if (!(vu > 0)) return fail(26);					/* 0xFFFFFFFF unsigned is greater than zero */
	if (!(is[0] < is[1])) return fail(27);				/* -2^31 < -1 signed */
	if (!(un[0] < un[1])) return fail(28);				/* 2^31 < 2^32-1 unsigned */
	if (((int)0x80000000u >> 31) != -1) { i = (int)un[0]; if ((i >> 31) != -1) return fail(29); }
	if ((un[0] >> 31) != 1) return fail(30);			/* logical shift of an unsigned */
	if ((is[0] >> 31) != -1) return fail(31);			/* arithmetic shift of a signed */
	if ((vi / 2) != 0) return fail(32);				/* -1 / 2 = 0, toward zero */
	i = -7; if (i / 2 != -3 || i % 2 != -1) return fail(33);
	u = vu; if (u / 2 != 2147483647u) return fail(34);		/* 0xFFFFFFFF / 2 */
	if ((vs * vs) != 4) return fail(35);				/* short operands promote to int */
	if (((short)(vs - 32767)) != 32767) return fail(36);		/* -2 - 32767 = -32769 wraps to 32767 */
	ul = (unsigned long)(unsigned)vi; if (ul != 4294967295UL) return fail(37);
	l = (long)(unsigned char)vc; if (l != 255) return fail(38);
	l = (long)(signed char)vuc; if (l != -1) return fail(39);
	return 1;
}
