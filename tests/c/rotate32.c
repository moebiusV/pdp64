/* expect: 1 -- rotates of a 32-bit unsigned value by constants (rori32), left and right, results used in arithmetic, compares and stores; the result is kept sign-extended */
unsigned rl7(unsigned x) { return (x << 7) | (x >> 25); }
unsigned rr3(unsigned x) { return (x >> 3) | (x << 29); }
unsigned mix(unsigned a, unsigned b) { return ((a << 5) | (a >> 27)) + b; }
int less(unsigned x, unsigned y) { unsigned r = (x << 11) | (x >> 21); return r < y; }
long wide(unsigned x) { return (long)((x << 1) | (x >> 31)); }
unsigned st[2];
void store(unsigned x) { st[0] = (x << 16) | (x >> 16); st[1] = (x >> 8) | (x << 24); }
int test(void)
{
	unsigned v = 0x80000001u;
	if (rl7(v) != 0x000000c0u) return 2;
	if (rr3(v) != 0x30000000u) return 3;
	if (mix(0x12345678u, 1u) != ((0x12345678u << 5) | (0x12345678u >> 27)) + 1u) return 4;
	if (!less(v, 0xffffffffu)) return 5;
	if (less(0xffffffffu, 5u)) return 6;
	if (wide(0xC0000000u) != 0x80000001L) return 7;
	if (wide(0x80000000u) != 1L) return 8;
	store(0x12345678u);
	if (st[0] != 0x56781234u || st[1] != 0x78123456u) return 9;
	if (rl7(0u) != 0u || rr3(0xffffffffu) != 0xffffffffu) return 10;
	return 1;
}
