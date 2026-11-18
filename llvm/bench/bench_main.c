/* The driver of llvm/bench/bench.py: one kernel (-DK_name) on fixed data, or none (-DK_none: the cost of the set-up, subtracted by the script) */
#include <stdint.h>
#include <stddef.h>
float expf(float x) { return x; }      /* stubs: the kernels that call them are measured, not checked */
float sqrtf(float x) { return x; }
void k_prep8(int16_t *tmp, const uint8_t *src, int w);
void k_put8h(uint8_t *dst, const uint8_t *src, int w, const int8_t *F);
unsigned k_dctop_sum(const uint8_t *top, int width);
void k_dctop_fill(uint8_t *dst, ptrdiff_t stride, int width, int height, int g_dc);
void k_fmac(float *dst, const float *src, float mul, int len);
int k_sad(const uint8_t *a, ptrdiff_t as, const uint8_t *b, ptrdiff_t bs, int w, int h);
void k_hist(const uint8_t *data, const int *idx, int start, int end, const float *g, const float *h, double *out);
void k_ssm(float *state, float dt, const float *A, const float *B, const float *C, float x, float *y, int n);
int k_q8dot(const int8_t *w, const int8_t *x, int n);
int k_q4dot(const uint8_t *w, const int8_t *x, int n);
void k_rmsnorm(float *o, const float *x, const float *wt, int n);
void k_softmax(float *x, int n);
void k_blend(uint8_t *dst, const uint8_t *src, const uint8_t *alpha, int n);
void k_mix16(int16_t *o, const int16_t *a, const int16_t *b, int n);
void k_vtx(float *ox, float *oy, float *oz, const float *x, const float *y, const float *z, const float *m, int n);
double k_ddot(const double *x, const double *y, int n);
void k_daxpy(double *y, const double *x, double a, int n);
void k_dscal(double *x, double a, int n);
void k_dgemv_n(const double *W, const double *x, double *y, int nout, int nin);
void k_dgemv_t(const double *W, const double *gy, double *gx, int nout, int nin);
void k_dger(double *gW, const double *gy, const double *x, int nout, int nin);
void k_sgemm_nt(const float *X, const float *W, float *Y, int M, int K, int N);
void k_gray(uint8_t *g, const uint8_t *rgba, int n);
void k_split(int16_t *l, int16_t *r, const int16_t *s, int n);
void k_vtxaos(float *o, const float *v, const float *m, int n);
void k_cmul(float *c, const float *a, const float *b, int n);
void k_saxpy(float *y, const float *x, float a, int n);
float k_sdot(const float *x, const float *y, int n);
int k_isum(const int *x, int n);
void k_bytemap(uint8_t *d, const uint8_t *s, int n);
void k_copy16(int16_t *d, const int16_t *s, int n);

#define N 1000
float g_fa[4096], g_fb[4096], g_fc[4096], g_fd[4096];
double g_da[4096], g_db[4096], g_dc[4096];
uint8_t g_ba[8192], g_bb[8192], g_bc[8192];
int16_t g_ha[4096], g_hb[4096], g_hc[4096];
int g_ia[4096], g_ib[4096];
static double g_hist[600];
static float g_mtx[16] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
static int8_t g_taps[8] = { -1, 3, -10, 57, 18, -6, 2, -1 };

int main(void)
{
    for (int i = 0; i < 4096; i++) {
        g_fa[i] = (float)(i % 17); g_fb[i] = (float)(i % 13); g_fc[i] = 0; g_fd[i] = 1;
        g_da[i] = (double)(i % 17); g_db[i] = (double)(i % 13); g_dc[i] = 0;
        g_ha[i] = (int16_t)(i * 7); g_hb[i] = (int16_t)(i * 5); g_hc[i] = 0;
        g_ia[i] = i; g_ib[i] = i % 1000;
    }
    for (int i = 0; i < 8192; i++) { g_ba[i] = (uint8_t)(i * 3); g_bb[i] = (uint8_t)(i * 7); g_bc[i] = 0; }
    int r = 0;
#ifdef K_k_prep8
    k_prep8(g_hc, g_ba, N);
#endif
#ifdef K_k_put8h
    k_put8h(g_bc, g_ba + 8, N, g_taps);
#endif
#ifdef K_k_dctop_sum
    r = (int)k_dctop_sum(g_ba, N);
#endif
#ifdef K_k_dctop_fill
    k_dctop_fill(g_bc, 128, 64, 16, 17);
#endif
#ifdef K_k_fmac
    k_fmac(g_fc, g_fa, 2.0f, N);
#endif
#ifdef K_k_sad
    r = k_sad(g_ba, 128, g_bb, 128, 64, 16);
#endif
#ifdef K_k_hist
    k_hist(g_bb, g_ib, 0, N, g_fa, g_fb, g_hist);
#endif
#ifdef K_k_ssm
    { float y; k_ssm(g_fc, 0.5f, g_fa, g_fb, g_fd, 2.0f, &y, N); }
#endif
#ifdef K_k_q8dot
    r = k_q8dot((const int8_t *)g_ba, (const int8_t *)g_bb, N);
#endif
#ifdef K_k_q4dot
    r = k_q4dot(g_ba, (const int8_t *)g_bb, N / 2);
#endif
#ifdef K_k_rmsnorm
    k_rmsnorm(g_fc, g_fa, g_fb, N);
#endif
#ifdef K_k_softmax
    k_softmax(g_fc, 256);
#endif
#ifdef K_k_blend
    k_blend(g_bc, g_ba, g_bb, N);
#endif
#ifdef K_k_mix16
    k_mix16(g_hc, g_ha, g_hb, N);
#endif
#ifdef K_k_vtx
    k_vtx(g_fc, g_fd, g_fb + 2048, g_fa, g_fa + 1024, g_fb, g_mtx, N);
#endif
#ifdef K_k_ddot
    r = (int)k_ddot(g_da, g_db, N);
#endif
#ifdef K_k_daxpy
    k_daxpy(g_dc, g_da, 2.0, N);
#endif
#ifdef K_k_dscal
    k_dscal(g_da, 3.0, N);
#endif
#ifdef K_k_dgemv_n
    k_dgemv_n(g_da, g_db, g_dc, 32, 64);
#endif
#ifdef K_k_dgemv_t
    k_dgemv_t(g_da, g_db, g_dc, 32, 64);
#endif
#ifdef K_k_dger
    k_dger(g_dc, g_da, g_db, 32, 64);
#endif
#ifdef K_k_sgemm_nt
    k_sgemm_nt(g_fa, g_fb, g_fc, 8, 64, 8);
#endif
#ifdef K_k_gray
    k_gray(g_bc, g_ba, N);
#endif
#ifdef K_k_split
    k_split(g_hc, g_hb, g_ha, N);
#endif
#ifdef K_k_vtxaos
    k_vtxaos(g_fc, g_fa, g_mtx, N / 4);
#endif
#ifdef K_k_cmul
    k_cmul(g_fc, g_fa, g_fb, N / 2);
#endif
#ifdef K_k_saxpy
    k_saxpy(g_fc, g_fa, 2.0f, N);
#endif
#ifdef K_k_sdot
    r = (int)k_sdot(g_fa, g_fb, N);
#endif
#ifdef K_k_isum
    r = k_isum(g_ia, N);
#endif
#ifdef K_k_bytemap
    k_bytemap(g_bc, g_ba, N);
#endif
#ifdef K_k_copy16
    k_copy16(g_hc, g_ha, N);
#endif
    return (r + (int)g_fc[7] + g_bc[5] + g_hc[3] + (int)g_dc[9]) & 127;
}
