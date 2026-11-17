/* The seven kernels of the hand-written vec forms (docs/encoding-work/vec-forms.md): the inner loop of each, as the project writes it. */
#include <stdint.h>
#include <stddef.h>
float expf(float);
int abs(int);

/* dav1d src/mc_tmpl.c prep_c, 8 bits: tmp[x] = (src[x] << intermediate_bits) - PREP_BIAS, with intermediate_bits 4 and PREP_BIAS 0 */
void k_prep8(int16_t *tmp, const uint8_t *src, int w)
{
    for (int x = 0; x < w; x++)
        tmp[x] = (src[x] << 4);
}

/* dav1d put_8tap_c, horizontal only, 8 bits: DAV1D_FILTER_8TAP_CLIP(src, x, fh, 1, 6) */
void k_put8h(uint8_t *dst, const uint8_t *src, int w, const int8_t *F)
{
    for (int x = 0; x < w; x++) {
        int s = F[0] * src[x - 3] + F[1] * src[x - 2] + F[2] * src[x - 1] + F[3] * src[x + 0] +
                F[4] * src[x + 1] + F[5] * src[x + 2] + F[6] * src[x + 3] + F[7] * src[x + 4];
        s = (s + 32) >> 6;
        dst[x] = s < 0 ? 0 : s > 255 ? 255 : s;
    }
}

/* dav1d ipred_tmpl.c dc_gen_top and splat_dc (the 8-bit generic form, one byte at a time): a reduction and a fill */
unsigned k_dctop_sum(const uint8_t *top, int width)
{
    unsigned dc = width >> 1;
    for (int i = 0; i < width; i++)
        dc += top[i];
    return dc >> __builtin_ctz(width);
}
void k_dctop_fill(uint8_t *dst, ptrdiff_t stride, int width, int height, int dc)
{
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++)
            dst[x] = dc;
        dst += stride;
    }
}

/* FFmpeg libavutil/float_dsp.c vector_fmac_scalar_c */
void k_fmac(float *dst, const float *src, float mul, int len)
{
    for (int i = 0; i < len; i++)
        dst[i] += src[i] * mul;
}

/* FFmpeg libavutil/pixelutils.c pixel_sad_c: the sum of absolute differences of two blocks (a row loop and the reduction) */
int k_sad(const uint8_t *a, ptrdiff_t as, const uint8_t *b, ptrdiff_t bs, int w, int h)
{
    int sum = 0;
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++)
            sum += abs(a[x] - b[x]);
        a += as;
        b += bs;
    }
    return sum;
}

/* LightGBM src/io/dense_bin.hpp ConstructHistogramInner<USE_INDICES, false, USE_HESSIAN>, uint8 bins: a gather of the bin, a scatter-add of two sums */
void k_hist(const uint8_t *data, const int *idx, int start, int end, const float *g, const float *h, double *out)
{
    for (int i = start; i < end; i++) {
        uint32_t ti = (uint32_t)data[idx[i]] << 1;
        out[ti] += g[i];
        out[ti + 1] += h[i];
    }
}

/* mamba.c (kroggen) forward_layer, the selective scan of one row d of the state, fused: dA = exp(dt*A), dB = dt*B,
 * state = state*dA + x*dB, y = sum over n of state*C (broadcast_multiply, outer_product, elementwise_multiply_and_add, rowwise_dot_product) */
void k_ssm(float *state, float dt, const float *A, const float *B, const float *C, float x, float *y, int n)
{
    float acc = 0.0f;
    for (int j = 0; j < n; j++) {
        float dA = expf(dt * A[j]);
        float dB = dt * B[j];
        float s = state[j] * dA + x * dB;
        state[j] = s;
        acc += s * C[j];
    }
    *y = acc;
}
