typedef unsigned long size_t;
int compress2(unsigned char *, unsigned long *, const unsigned char *, unsigned long, int);
int uncompress(unsigned char *, unsigned long *, const unsigned char *, unsigned long);
static unsigned char src[50000], cmp[70000], dst[50000];
static unsigned long seed = 99;
static unsigned rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return seed >> 40; }
int test(void)
{
	static const char *w[] = { "the ", "quick ", "brown ", "fox ", "jumps ", "over ", "lazy ", "dog ", "and ", "runs ", "away\n", "pdp ", "machine ", "flags " };
	unsigned long i = 0, cl = sizeof cmp, dl = sizeof dst, s = 0, k;
	while (i < sizeof src - 12) { const char *p = w[rnd() % 14]; while (*p && i < sizeof src) src[i++] = *p++; if (rnd() % 17 == 0) src[i++] = 'A' + rnd() % 26; }
	for (; i < sizeof src; i++) src[i] = ' ';
	if (compress2(cmp, &cl, src, sizeof src, 6) != 0) return -1;
	if (uncompress(dst, &dl, cmp, cl) != 0) return -2;
	if (dl != sizeof src) return -3;
	for (k = 0; k < dl; k++) if (dst[k] != src[k]) return -4;
	for (k = 0; k < cl; k++) s = s * 131 + cmp[k];
	return (int)((s ^ cl) & 0x7fffffff);
}
