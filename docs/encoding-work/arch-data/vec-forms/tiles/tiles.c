/* The tile kernels of docs/encoding-work/vec-2d.md (errata 176): the scalar C of each graphics-shaped kernel over a w x h tile, the reference that the hand-written assembly (k_NAME.vecrows.s: a scalar row loop
 * around a 1D vec block; k_NAME.vec2d.s: one vec2 block) is checked against, and the no-vectorisation baseline (clang -O2 with the vectoriser off, llc), and the LoopVectorize build (`lv`).
 * Strides are in bytes.  Every kernel has at most six arguments (the register ABI); a mask or a coefficient table is a global of the driver (tile-main.c). */
#include <stdint.h>
extern uint8_t g_mask[];
extern int8_t g_coef[8];
extern uint8_t g_lo[], g_hi[];

long t_sad(const uint8_t *a, long sa, const uint8_t *b, long sb, long w, long h)
{
	long s = 0;
	for (long y = 0; y < h; y++, a += sa, b += sb)
		for (long x = 0; x < w; x++) { int d = a[x] - b[x]; s += d < 0 ? -d : d; }
	return s;
}
void t_avg(uint8_t *d, const uint8_t *a, const uint8_t *b, long p, long w, long h)
{
	for (long y = 0; y < h; y++, d += p, a += p, b += p)
		for (long x = 0; x < w; x++) d[x] = (uint8_t)((a[x] + b[x] + 1) >> 1);
}
void t_mblend(uint8_t *d, const uint8_t *a, const uint8_t *b, long p, long w, long h)
{
	const uint8_t *m = g_mask;
	for (long y = 0; y < h; y++, d += p, a += p, b += p, m += p)
		for (long x = 0; x < w; x++) d[x] = (uint8_t)((a[x] & m[x]) | (b[x] & ~m[x]));
}
void t_blend(uint8_t *d, const uint8_t *s, const uint8_t *al, long p, long w, long h)
{
	for (long y = 0; y < h; y++, d += p, s += p, al += p)
		for (long x = 0; x < w; x++) {
			int t = s[x] * al[x] + d[x] * (255 - al[x]) + 128;
			d[x] = (uint8_t)((t + (t >> 8)) >> 8);
		}
}
void t_put8h(uint8_t *d, long sd, const uint8_t *s, long ss, long w, long h)
{
	for (long y = 0; y < h; y++, d += sd, s += ss)
		for (long x = 0; x < w; x++) {
			int t = 32;
			for (int k = 0; k < 8; k++) t += g_coef[k] * s[x + k - 3];
			t >>= 6;
			d[x] = (uint8_t)(t < 0 ? 0 : t > 255 ? 255 : t);
		}
}
void t_gray(uint8_t *g, long sg, const uint8_t *p, long sp, long w, long h)
{
	for (long y = 0; y < h; y++, g += sg, p += sp)
		for (long x = 0; x < w; x++) g[x] = (uint8_t)((77 * p[4 * x] + 150 * p[4 * x + 1] + 29 * p[4 * x + 2]) >> 8);
}
void t_thresh(uint8_t *d, long sd, const uint8_t *s, long ss, long w, long h)
{
	for (long y = 0; y < h; y++, d += sd, s += ss)
		for (long x = 0; x < w; x++) d[x] = s[x] > 128 ? 255 : 0;
}
void t_quant(int8_t *d, long sd, const float *s, long ss, long w, long h)
{
	for (long y = 0; y < h; y++, d += sd, s = (const float *)((const char *)s + ss))
		for (long x = 0; x < w; x++) {
			int v = (int)(s[x] * 0.375f);
			d[x] = (int8_t)(v > 127 ? 127 : v < -128 ? -128 : v);
		}
}
