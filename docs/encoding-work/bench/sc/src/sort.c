/* quicksort of 16384 64-bit words (128 KB), then a checksum */
#define N 16384
static long a[N];
static unsigned long seed = 12345;
static unsigned long rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return seed >> 33; }
static void qs(long lo, long hi)
{
	while (lo < hi) {
		long p = a[(lo + hi) >> 1], i = lo, j = hi, t;
		while (i <= j) {
			while (a[i] < p) i++;
			while (a[j] > p) j--;
			if (i <= j) { t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
		}
		if (j - lo < hi - i) { qs(lo, j); lo = i; } else { qs(i, hi); hi = j; }
	}
}
int test(void)
{
	long i, s = 0;
	for (i = 0; i < N; i++) a[i] = rnd() & 0xfffff;
	qs(0, N - 1);
	for (i = 1; i < N; i++) if (a[i - 1] > a[i]) return -1;
	for (i = 0; i < N; i += 97) s += a[i];
	return (int)(s & 0x7fffffff);
}
