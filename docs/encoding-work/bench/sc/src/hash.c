/* open-addressing hash table of 32768 slots (256 KB): 24000 inserts then 24000 lookups */
#define SLOTS 32768
static unsigned long key[SLOTS];
static unsigned long val[SLOTS];
static unsigned long seed = 99;
static unsigned long rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return seed >> 20; }
int test(void)
{
	long i, s = 0;
	unsigned long k, h;
	for (i = 0; i < 24000; i++) {
		k = rnd() | 1;
		h = (k * 0x9e3779b97f4a7c15UL) >> 49;
		while (key[h & (SLOTS - 1)] != 0) h++;
		key[h & (SLOTS - 1)] = k;
		val[h & (SLOTS - 1)] = i;
	}
	seed = 99;
	for (i = 0; i < 24000; i++) {
		k = rnd() | 1;
		h = (k * 0x9e3779b97f4a7c15UL) >> 49;
		while (key[h & (SLOTS - 1)] != k) h++;
		s += val[h & (SLOTS - 1)];
	}
	return (int)(s & 0x7fffffff);
}
