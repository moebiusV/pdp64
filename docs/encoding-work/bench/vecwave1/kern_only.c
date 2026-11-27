/* the kernels of the wave-1 re-judgement: plain C (see driver.c for the data and main) */
#include <stdint.h>
/* ---- inference ---- */
void k_sgemm(const float *X, const float *W, float *Y, int M, int K, int N)
{ for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) { float s = 0; for (int k = 0; k < K; k++) s += X[i*K+k] * W[j*K+k]; Y[i*N+j] = s; } }
int k_q8dot(const int8_t *w, const int8_t *x, int n)
{ int s = 0; for (int i = 0; i < n; i++) s += w[i] * x[i]; return s; }
void k_q8matvec(const int8_t *w, const int8_t *x, int *y, int rows, int cols)
{ for (int r = 0; r < rows; r++) { int s = 0; for (int i = 0; i < cols; i++) s += w[r*cols+i] * x[i]; y[r] = s; } }
void k_conv1d(const float *x, const float *w, float *y, int n)
{ for (int i = 0; i < n; i++) { float s = 0; for (int k = 0; k < 8; k++) s += w[k] * x[i+k]; y[i] = s; } }
void k_conv3x3(const float *in, float *out, int h, int w)   /* in, out: w-wide rows; out interior */
{ for (int y = 1; y < h-1; y++) for (int x = 1; x < w-1; x++) {
    out[y*w+x] = 0.0625f*in[(y-1)*w+x-1] + 0.125f*in[(y-1)*w+x] + 0.0625f*in[(y-1)*w+x+1]
               + 0.125f *in[y*w+x-1]     + 0.25f *in[y*w+x]     + 0.125f *in[y*w+x+1]
               + 0.0625f*in[(y+1)*w+x-1] + 0.125f*in[(y+1)*w+x] + 0.0625f*in[(y+1)*w+x+1]; } }
/* ---- sparse ---- */
void k_spmv(const float *val, const int *col, const int *rp, const float *x, float *y, int nr)
{ for (int r = 0; r < nr; r++) { float s = 0; for (int j = rp[r]; j < rp[r+1]; j++) s += val[j] * x[col[j]]; y[r] = s; } }
void k_lut256(const uint8_t *t, const uint8_t *in, uint8_t *out, int n)
{ for (int i = 0; i < n; i++) out[i] = t[in[i]]; }

