/* zlibmain.c -- the main of the zlib profile program: compress and uncompress a pseudo-random text-like buffer with compress() and uncompress() and print a checksum. */
#include "zlib.h"
long write(int, const char *, long);
#define N 40000
static unsigned char in[N], out[N + 1024], back[N];
static unsigned long seed = 4242;
static unsigned rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return (unsigned)(seed >> 33); }
static void put(unsigned long v)
{
	char b[24], *p = b + 24;
	*--p = '\n';
	do { *--p = '0' + v % 10; v /= 10; } while (v);
	write(1, p, b + 24 - p);
}
int main(void)
{
	static const char *words[] = { "alpha ", "beta ", "gamma ", "delta ", "epsilon ", "zeta ", "eta ", "theta ", "iota ", "kappa ", "lambda ", "mu " };
	int i, n = 0, round;
	unsigned long sum = 0;
	while (n < N - 12) { const char *w = words[rnd() % 12]; while (*w && n < N) in[n++] = *w++; if (rnd() % 5 == 0) in[n++] = '0' + rnd() % 10; }
	for (round = 0; round < 2; round++) {
		uLongf c = sizeof out, r = N;
		if (compress2(out, &c, in, n, 6 + round) != Z_OK) return 1;
		if (uncompress(back, &r, out, c) != Z_OK || r != (uLongf)n) return 2;
		for (i = 0; i < n; i++) if (in[i] != back[i]) return 3;
		sum = sum * 31 + c + crc32(0, in, n) % 1000 + adler32(1, back, n) % 1000;
	}
	put(sum);
	return 0;
}
