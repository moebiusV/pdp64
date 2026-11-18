/* newk.c -- kernels for the words of waves 1 and 2 (errata 170, 171), as plain loops, in the style of docs/encoding-work/arch-data/vec-forms/games/games.c: each is the loop of a real
   program (FFmpeg's pixel averages and SAD, audio and DSP fixed point, llama.cpp's quantised dot product with its scales, image clamps and thresholds, activation functions and
   quantisation) that the new words are meant for.  bench.py compiles this file like the others (clang -O2 -ffast-math, and for the lv variant through opt -O2 -mtriple=pdp64). */
#include <stdint.h>
#include <stddef.h>
int abs(int);

/* FFmpeg avg_pixels: the rounding average of two rows of 8-bit pixels (vavgu.b) */
void k_avg8(uint8_t *d, const uint8_t *a, const uint8_t *b, int n)
{
    for (int i = 0; i < n; i++) d[i] = (a[i] + b[i] + 1) >> 1;
}

/* audio gain in Q15: o = sat16((a * b + 2^14) >> 15) (vmulhr.w; -32768 x -32768 saturates) */
void k_q15mul(int16_t *o, const int16_t *a, const int16_t *b, int n)
{
    for (int i = 0; i < n; i++) { int t = (a[i] * b[i] + 16384) >> 15; o[i] = t > 32767 ? 32767 : t; }
}

/* llama.cpp q8_0 x q8_0: nb blocks of 32 int8 pairs, the int sum of each block times its two float scales (the inner loop is vdacc.b, the outer one has no block of its own) */
float k_q8blk(const int8_t *w, const int8_t *x, const float *ws, const float *xs, int nb)
{
    float sum = 0.0f;
    for (int b = 0; b < nb; b++) {
        int s = 0;
        for (int i = 0; i < 32; i++) s += w[b * 32 + i] * x[b * 32 + i];
        sum += (float)s * ws[b] * xs[b];
    }
    return sum;
}

/* sum of absolute differences of a row of 8-bit pixels (vsad.bu) */
int k_sadrow(const uint8_t *a, const uint8_t *b, int n)
{
    int s = 0;
    for (int i = 0; i < n; i++) s += abs(a[i] - b[i]);
    return s;
}

/* x > t ? a : b on 16-bit values (a vectorised `if`: vcgt.w, vbsl).  Both arms are loaded before the choice: with `x[i] > t ? a[i] : b[i]` the loads are conditional, and a vector
   loop would need masked loads (gaps.c: g_thresh_cond) */
void k_thresh(int16_t *d, const int16_t *x, const int16_t *a, const int16_t *b, int t, int n)
{
    for (int i = 0; i < n; i++) { int16_t va = a[i], vb = b[i]; d[i] = x[i] > t ? va : vb; }
}

/* a byte mask chooses between two rows: m != 0 ? a : b (vceq.b, vbsl with the arms swapped) */
void k_maskblend(uint8_t *d, const uint8_t *m, const uint8_t *a, const uint8_t *b, int n)
{
    for (int i = 0; i < n; i++) { uint8_t va = a[i], vb = b[i]; d[i] = m[i] ? va : vb; }
}

/* a 32-bit intermediate back to 8-bit pixels: clamp(x, 0, 255) (vsts.l.bu, no rounding) */
void k_clamp8(uint8_t *d, const int32_t *s, int n)
{
    for (int i = 0; i < n; i++) d[i] = s[i] < 0 ? 0 : s[i] > 255 ? 255 : s[i];
}

/* the same with the fixed-point rounding of a filter's last stage: clamp((x + 128) >> 8, 0, 255) (vsts.l.bu with #8) */
void k_clampr(uint8_t *d, const int32_t *s, int n)
{
    for (int i = 0; i < n; i++) { int t = (s[i] + 128) >> 8; d[i] = t < 0 ? 0 : t > 255 ? 255 : t; }
}

/* int32 to float with a scale (vcvt.l.f, vmul.f) */
void k_i2f(float *o, const int32_t *a, int n)
{
    for (int i = 0; i < n; i++) o[i] = (float)a[i] * 0.5f;
}

/* 8-bit pixels to floats in 0..1 (vld.bu.l, vcvt.l.f) */
void k_dequant(float *o, const uint8_t *a, int n)
{
    for (int i = 0; i < n; i++) o[i] = a[i] * (1.0f / 255.0f);
}

/* activation quantisation (llama.cpp quantize_row_q8_0 without the rounding): clamp(trunc(x * id), -128, 127) as int8 (vmul.f, vcvt.f.l, vsts.l.b) */
void k_quant(int8_t *y, const float *x, float id, int n)
{
    for (int i = 0; i < n; i++) { int t = (int)(x[i] * id); y[i] = t < -128 ? -128 : t > 127 ? 127 : t; }
}

/* ReLU: x > 0 ? x : 0 (vcgt.f, vbsl; an ordered compare, so NaN gives 0 as the C does) */
void k_relu(float *o, const float *x, int n)
{
    for (int i = 0; i < n; i++) o[i] = x[i] > 0.0f ? x[i] : 0.0f;
}

/* a multiply-add of integer vectors: o = a * b + c (vmla.l) */
void k_mla32(int32_t *o, const int32_t *a, const int32_t *b, const int32_t *c, int n)
{
    for (int i = 0; i < n; i++) o[i] = a[i] * b[i] + c[i];
}

/* the high half of a 16 x 16 product: fixed-point scaling (vmulh.w) */
void k_mulh16(int16_t *o, const int16_t *a, const int16_t *b, int n)
{
    for (int i = 0; i < n; i++) o[i] = (int16_t)((a[i] * b[i]) >> 16);
}

/* a dot product of 16-bit samples into a 64-bit sum (a filter or a correlation: vdacc.w) */
int64_t k_dot16(const int16_t *a, const int16_t *b, int n)
{
    int64_t s = 0;
    for (int i = 0; i < n; i++) s += (int64_t)a[i] * b[i];
    return s;
}
