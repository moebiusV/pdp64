/* The driver of tools/gates/run-2d.sh (docs/encoding-work/vec-2d.md): fills the planes of a tile benchmark from a fixed generator, calls one tile kernel (K_<name>; K_none for the set-up alone, which the
 * runner subtracts), and writes the result and the destination plane to standard output so that every form of the kernel can be compared byte for byte.  W, H: the tile (bytes of the first stream's row, rows). */
#include <stdint.h>
long write(int, const void *, long);
long t_sad(const uint8_t *, long, const uint8_t *, long, long, long);
void t_avg(uint8_t *, const uint8_t *, const uint8_t *, long, long, long);
void t_mblend(uint8_t *, const uint8_t *, const uint8_t *, long, long, long);
void t_blend(uint8_t *, const uint8_t *, const uint8_t *, long, long, long);
void t_put8h(uint8_t *, long, const uint8_t *, long, long, long);
void t_gray(uint8_t *, long, const uint8_t *, long, long, long);
void t_thresh(uint8_t *, long, const uint8_t *, long, long, long);
void t_quant(int8_t *, long, const float *, long, long, long);
#ifdef K_sad_chk
long t_sad_chk(const uint8_t *, long, const uint8_t *, long, long, long);
#endif
#ifdef K_mblend_chk
void t_mblend_chk(uint8_t *, const uint8_t *, const uint8_t *, long, long, long);
#endif
#define P (W + 64)
#define SZ (P * H + 512)
#define OFF 128
uint8_t g_mask[SZ];
int8_t g_coef[8] = { -1, 3, -10, 58, 17, -5, 1, 0 };
uint64_t g_bnd[4], g_bnd4[8];
void *g_sink[4];			/* the planes' addresses escape, so that the driver without the call (the baseline that is subtracted) still fills every plane */
#if defined(K_gray)
#define SA (4 * P * H + 1024)
#else
#define SA (SZ + 16 * H)
#endif
static uint8_t pa[SA], pb[SZ + 16 * H], pd[SZ];
static float pf[(4 * P * H + 512) / 4 + 4 * H];
static uint64_t seed = 88172645463325252ULL;
static uint32_t rnd(void) { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return (uint32_t)(seed >> 11); }

int main(void)
{
	long r = 0;
	for (long i = 0; i < SA; i++) pa[i] = (uint8_t)rnd();
	for (long i = 0; i < SZ + 16 * H; i++) pb[i] = (uint8_t)rnd();
	for (long i = 0; i < SZ; i++) { pd[i] = (uint8_t)rnd(); g_mask[i] = (uint8_t)rnd(); }
#if defined(K_quant)
	for (long i = 0; i < (long)(sizeof pf / 4); i++) pf[i] = (float)((int)(rnd() & 1023) - 512) * 0.5f;
#endif
	g_sink[0] = pa; g_sink[1] = pb; g_sink[2] = pd;
#if defined(K_quant)
	g_sink[3] = pf;
#endif
	g_bnd[0] = (uint64_t)pa; g_bnd[1] = (uint64_t)pa + SZ + 16 * H; g_bnd[2] = (uint64_t)pb; g_bnd[3] = (uint64_t)pb + SZ + 16 * H;
	g_bnd4[0] = (uint64_t)pd; g_bnd4[1] = (uint64_t)pd + SZ; g_bnd4[2] = g_bnd[0]; g_bnd4[3] = g_bnd[1]; g_bnd4[4] = g_bnd[2]; g_bnd4[5] = g_bnd[3];
	g_bnd4[6] = (uint64_t)g_mask; g_bnd4[7] = (uint64_t)g_mask + SZ;
#ifndef NOCALL
#if defined(K_sad)
	r = t_sad(pa + OFF, P, pb + OFF, P + 16, W, H);
#elif defined(K_sad_chk)
	r = t_sad_chk(pa + OFF, P, pb + OFF, P + 16, W, H);
#elif defined(K_avg)
	t_avg(pd + OFF, pa + OFF, pb + OFF, P, W, H);
#elif defined(K_mblend)
	t_mblend(pd + OFF, pa + OFF, pb + OFF, P, W, H);
#elif defined(K_mblend_chk)
	t_mblend_chk(pd + OFF, pa + OFF, pb + OFF, P, W, H);
#elif defined(K_blend)
	t_blend(pd + OFF, pa + OFF, pb + OFF, P, W, H);
#elif defined(K_put8h)
	t_put8h(pd + OFF, P, pa + OFF, P, W, H);
#elif defined(K_gray)
	t_gray(pd + OFF, P, pa + OFF, 4 * W + 64, W, H);
#elif defined(K_thresh)
	t_thresh(pd + OFF, P, pa + OFF, P, W, H);
#elif defined(K_quant)
	t_quant((int8_t *)pd + OFF, P, pf + OFF / 4, 4 * W + 64, W, H);
#endif
#endif
	write(1, &r, 8);
	write(1, pd, SZ);
	return 0;
}
