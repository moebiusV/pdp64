/* Kernels of interleaved data (arrays of structures): where a segment load (de-interleave n fields into n vectors) matters. */
#include <stdint.h>
#include <stddef.h>

/* RGBA bytes to a gray byte: three of the four fields used */
void k_gray(uint8_t *g, const uint8_t *rgba, int n)
{
    for (int i = 0; i < n; i++)
        g[i] = (uint8_t)((77 * rgba[4 * i] + 150 * rgba[4 * i + 1] + 29 * rgba[4 * i + 2]) >> 8);
}

/* stereo 16-bit audio split into two streams: two fields */
void k_split(int16_t *l, int16_t *r, const int16_t *s, int n)
{
    for (int i = 0; i < n; i++) { l[i] = s[2 * i]; r[i] = s[2 * i + 1]; }
}

/* vertices as (x y z w) floats, one structure each, by a 4x4 matrix (rows 0 to 2 only): four fields in, three out, interleaved */
void k_vtxaos(float *o, const float *v, const float *m, int n)
{
    for (int i = 0; i < n; i++) {
        float x = v[4 * i], y = v[4 * i + 1], z = v[4 * i + 2];
        o[4 * i]     = m[0] * x + m[1] * y + m[2] * z + m[3];
        o[4 * i + 1] = m[4] * x + m[5] * y + m[6] * z + m[7];
        o[4 * i + 2] = m[8] * x + m[9] * y + m[10] * z + m[11];
        o[4 * i + 3] = v[4 * i + 3];
    }
}

/* complex multiply of arrays of (re, im) pairs: two fields in, two out */
void k_cmul(float *c, const float *a, const float *b, int n)
{
    for (int i = 0; i < n; i++) {
        float ar = a[2 * i], ai = a[2 * i + 1], br = b[2 * i], bi = b[2 * i + 1];
        c[2 * i] = ar * br - ai * bi;
        c[2 * i + 1] = ar * bi + ai * br;
    }
}
