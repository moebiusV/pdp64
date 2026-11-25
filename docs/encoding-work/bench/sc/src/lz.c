/* a small LZ77 compressor: 3-byte hash heads (4096 entries) and a chain array over a 48 KB generated text */
#define N 49152
static unsigned char text[N];
static short head[4096];
static short prev[N];
static unsigned char out[N * 2];
int test(void)
{
	long i, o = 0, j, best, len, cand, tries;
	unsigned long seed = 7, h;
	for (i = 0; i < N; i++) { seed = seed * 1103515245UL + 12345UL; text[i] = "etaoin shrdlu"[(seed >> 16) % 13] + ((i & 1023) == 0); }
	for (i = 0; i < 4096; i++) head[i] = -1;
	i = 0;
	while (i + 3 < N) {
		h = ((text[i] << 8) ^ (text[i+1] << 4) ^ text[i+2]) & 4095;
		cand = head[h]; best = 0; tries = 0;
		while (cand >= 0 && tries < 8) {
			len = 0;
			while (i + len < N && text[cand + len] == text[i + len] && len < 64) len++;
			if (len > best) best = len;
			cand = prev[cand]; tries++;
		}
		prev[i] = head[h]; head[h] = (short)i;
		if (best >= 3) { out[o++] = 0x80 | (best & 63); out[o++] = (unsigned char)(i - cand); i += best; }
		else { out[o++] = text[i]; i++; }
	}
	return (int)o;
}
