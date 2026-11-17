/* Kernels of games and of language-model inference on a CPU, as plain loops (docs/encoding-work/vec-cost-benefit.md). */
#include <stdint.h>
#include <stddef.h>
float expf(float);
float sqrtf(float);

/* llama.cpp-style q8_0 dot product, the inner loop of a quantized layer: n int8 weights against n int8 activations, int32 accumulation */
int k_q8dot(const int8_t *w, const int8_t *x, int n)
{
    int s = 0;
    for (int i = 0; i < n; i++) s += w[i] * x[i];
    return s;
}

/* q4_0: two 4-bit weights in a byte, the low and the high nibble minus 8, against int8 activations (the first half of the block against the low nibbles, the second against the high) */
int k_q4dot(const uint8_t *w, const int8_t *x, int n)
{
    int s = 0;
    for (int i = 0; i < n; i++) {
        s += ((w[i] & 15) - 8) * x[i];
        s += ((w[i] >> 4) - 8) * x[i + n];
    }
    return s;
}

/* RMS norm of a vector: the sum of squares (a reduction), then the scale (a map) */
void k_rmsnorm(float *o, const float *x, const float *wt, int n)
{
    float ss = 0.0f;
    for (int i = 0; i < n; i++) ss += x[i] * x[i];
    ss = 1.0f / sqrtf(ss / n + 1e-5f);
    for (int i = 0; i < n; i++) o[i] = wt[i] * (ss * x[i]);
}

/* softmax of n scores: the maximum, the exponentials and their sum, the scale */
void k_softmax(float *x, int n)
{
    float m = x[0], s = 0.0f;
    for (int i = 1; i < n; i++) if (x[i] > m) m = x[i];
    for (int i = 0; i < n; i++) { x[i] = expf(x[i] - m); s += x[i]; }
    for (int i = 0; i < n; i++) x[i] /= s;
}

/* alpha blend of a row of 8-bit channels: dst = (src*a + dst*(255-a) + 127) / 255 with a division by 255 as (t + 1 + (t >> 8)) >> 8 */
void k_blend(uint8_t *dst, const uint8_t *src, const uint8_t *alpha, int n)
{
    for (int i = 0; i < n; i++) {
        unsigned a = alpha[i];
        unsigned t = src[i] * a + dst[i] * (255 - a) + 128;
        dst[i] = (uint8_t)((t + (t >> 8)) >> 8);
    }
}

/* audio mix: the saturating sum of two 16-bit streams */
void k_mix16(int16_t *o, const int16_t *a, const int16_t *b, int n)
{
    for (int i = 0; i < n; i++) {
        int s = a[i] + b[i];
        o[i] = s > 32767 ? 32767 : s < -32768 ? -32768 : s;
    }
}

/* vertex transform: n vertices of four floats (x y z w, structure of arrays: the four are separate streams) by a 4x4 matrix, the position and the w divide left out */
void k_vtx(float *ox, float *oy, float *oz, const float *x, const float *y, const float *z, const float *m, int n)
{
    for (int i = 0; i < n; i++) {
        ox[i] = m[0] * x[i] + m[1] * y[i] + m[2] * z[i] + m[3];
        oy[i] = m[4] * x[i] + m[5] * y[i] + m[6] * z[i] + m[7];
        oz[i] = m[8] * x[i] + m[9] * y[i] + m[10] * z[i] + m[11];
    }
}
