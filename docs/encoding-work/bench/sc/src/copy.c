/* copy a 128 KB array to another with a loop, four times, then clear a third: streaming stores to cold lines */
#define N 16384
static long src[N], dst[N], tmp[N];
int test(void)
{
	long i, r, s = 0;
	for (i = 0; i < N; i++) src[i] = i * 3;
	for (r = 0; r < 4; r++) {
		for (i = 0; i < N; i++) dst[i] = src[i] + r;
		for (i = 0; i < N; i++) tmp[i] = 0;
	}
	for (i = 0; i < N; i += 61) s += dst[i];
	return (int)(s & 0x7fffffff);
}
