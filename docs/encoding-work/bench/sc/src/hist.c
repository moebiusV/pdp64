/* byte histogram and a prefix sum over 96 KB: the stores go to a few hot lines */
static unsigned char buf[98304];
static long cnt[256], pre[256];
int test(void)
{
	long i, r, s = 0;
	unsigned long seed = 3;
	for (i = 0; i < 98304; i++) { seed = seed * 1103515245UL + 12345UL; buf[i] = (unsigned char)(seed >> 16); }
	for (r = 0; r < 3; r++) for (i = 0; i < 98304; i++) cnt[buf[i]]++;
	for (i = 1; i < 256; i++) pre[i] = pre[i - 1] + cnt[i - 1];
	for (i = 0; i < 256; i++) s += pre[i];
	return (int)(s & 0x7fffffff);
}
