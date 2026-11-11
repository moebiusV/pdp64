/* lz4main.c -- the main of the lz4 profile program: compress and decompress a pseudo-random text-like buffer with LZ4_compress_default and LZ4_decompress_safe and print a checksum. */
int LZ4_compress_default(const char *src, char *dst, int srcSize, int dstCapacity);
int LZ4_decompress_safe(const char *src, char *dst, int compressedSize, int dstCapacity);
long write(int, const char *, long);
#define N 60000
static char in[N], out[N + N / 100 + 64], back[N];
static unsigned long seed = 12345;
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
	static const char *words[] = { "the ", "quick ", "brown ", "fox ", "jumps ", "over ", "lazy ", "dog ", "pdp64 ", "parcel ", "prefix ", "encoding " };
	int i, n = 0, r, round;
	unsigned long sum = 0;
	while (n < N - 12) { const char *w = words[rnd() % 12]; while (*w && n < N) in[n++] = *w++; if (rnd() % 7 == 0) in[n++] = '0' + rnd() % 10; }
	for (round = 0; round < 3; round++) {
		int c = LZ4_compress_default(in, out, n, sizeof out);
		if (c <= 0) return 1;
		r = LZ4_decompress_safe(out, back, c, N);
		if (r != n) return 2;
		for (i = 0; i < n; i++) if (in[i] != back[i]) return 3;
		sum = sum * 31 + c;
	}
	put(sum);
	return 0;
}
