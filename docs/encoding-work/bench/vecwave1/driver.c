/* Driver of the kernels in kern_only.c; Kernels of the wave-1 / strip re-judgement (docs/encoding-work/vector-strip-and-wave1-measured.md).
   Every kernel is plain C; the harness (run.py) compiles it scalar and with LoopVectorize, and runs it under sim64 -V.
   Sizes are small so a run takes seconds in the simulator; the cycle models are per kernel call (the driver's set-up is subtracted). */
#include <stdint.h>
#define M_ 16
#define N_ 16
#define K_ 64
#define NQ 4096
#define ROWS 64
#define COLS 256
#define NC 2048
#define W2 34
#ifndef NNZ_ROW
#define NNZ_ROW 16
#endif
#define NR 256
#define XN 1024
#define LUTN 4096

float g_a[M_*K_], g_b[N_*K_], g_c[M_*N_];                /* sgemm */
int8_t g_w8[ROWS*COLS], g_x8[COLS], g_q8a[NQ], g_q8b[NQ]; /* q8 dot, q8 matvec */
int g_y32[ROWS];
float g_cx[NC+8], g_cw[8], g_cy[NC];                     /* conv1d */
float g_img[W2*W2], g_img_o[W2*W2];                      /* conv2d */
float g_val[NR*NNZ_ROW], g_xv[XN], g_yv[NR]; int g_col[NR*NNZ_ROW], g_rp[NR+1]; /* spmv */
uint8_t g_lut[256], g_lin[LUTN], g_lout[LUTN];           /* byte table lookup */
volatile int g_sink;
float g_pa[M_*K_], g_pb[N_*K_];                          /* packed panels for the micro-kernel form */
void k_ukr(const float *pa, const float *pb, float *c, int K, int ldc_bytes);
static void pack_panels(void)
{ for (int p = 0; p < M_/8; p++) for (int k = 0; k < K_; k++) for (int r = 0; r < 8; r++) g_pa[p*8*K_ + k*8 + r] = g_a[(8*p+r)*K_ + k];
  for (int q = 0; q < N_/4; q++) for (int k = 0; k < K_; k++) for (int c = 0; c < 4; c++) g_pb[q*4*K_ + k*4 + c] = g_b[(4*q+c)*K_ + k]; }

void k_sgemm(const float *X, const float *W, float *Y, int M, int K, int N);
int k_q8dot(const int8_t *w, const int8_t *x, int n);
void k_q8matvec(const int8_t *w, const int8_t *x, int *y, int rows, int cols);
void k_conv1d(const float *x, const float *w, float *y, int n);
void k_conv3x3(const float *in, float *out, int h, int w);
void k_spmv(const float *val, const int *col, const int *rp, const float *x, float *y, int nr);
void k_lut256(const uint8_t *t, const uint8_t *in, uint8_t *out, int n);
#ifdef K_none
#define CALL(x)
#else
#define CALL(x) x
#endif
static uint32_t rs = 12345; static uint32_t rnd(void) { rs = rs*1103515245u + 12345u; return rs >> 8; }
static uint64_t H = 1469598103934665603ULL;
static void hb(const void *p, unsigned long n) { const uint8_t *q = p; for (unsigned long i = 0; i < n; i++) { H ^= q[i]; H *= 1099511628211ULL; } }
long write(int, const void *, unsigned long);
int main(void)
{
    for (int i = 0; i < M_*K_; i++) g_a[i] = (int)(rnd() % 17) - 8;
    for (int i = 0; i < N_*K_; i++) g_b[i] = (int)(rnd() % 13) - 6;
    for (int i = 0; i < ROWS*COLS; i++) g_w8[i] = (int)(rnd() % 255) - 127;
    for (int i = 0; i < COLS; i++) g_x8[i] = (int)(rnd() % 255) - 127;
    for (int i = 0; i < NQ; i++) { g_q8a[i] = (int)(rnd() % 255) - 127; g_q8b[i] = (int)(rnd() % 255) - 127; }
    for (int i = 0; i < NC+8; i++) g_cx[i] = (int)(rnd() % 9) - 4;
    for (int i = 0; i < 8; i++) g_cw[i] = (int)(rnd() % 5) - 2;
    for (int i = 0; i < W2*W2; i++) g_img[i] = (int)(rnd() % 16);
    for (int i = 0; i < XN; i++) g_xv[i] = (int)(rnd() % 9) - 4;
    for (int r = 0; r <= NR; r++) g_rp[r] = r * NNZ_ROW;
    for (int j = 0; j < NR*NNZ_ROW; j++) { g_col[j] = rnd() % XN; g_val[j] = (int)(rnd() % 7) - 3; }
    for (int i = 0; i < 256; i++) g_lut[i] = (i * 37 + 11) & 255;
    for (int i = 0; i < LUTN; i++) g_lin[i] = rnd() & 255;
    int r = 0;
#ifdef K_k_sgemm
    k_sgemm(g_a, g_b, g_c, M_, K_, N_);
#endif
#ifdef K_k_ukr_pack          /* packing only: the cost of the layout the micro-kernel needs */
    pack_panels();
#endif
#ifdef K_k_ukr              /* packing is done too; run.py subtracts k_ukr_pack to isolate the micro-kernel calls */
    pack_panels();
    for (int p = 0; p < M_/8; p++) for (int q = 0; q < N_/4; q++) k_ukr(g_pa + p*8*K_, g_pb + q*4*K_, g_c + 8*p*N_ + 4*q, K_, N_*4);
   
#endif
#ifdef K_k_q8dot
    r = k_q8dot(g_q8a, g_q8b, NQ);
#endif
#ifdef K_k_q8matvec
    k_q8matvec(g_w8, g_x8, g_y32, ROWS, COLS);
#endif
#ifdef K_k_conv1d
    k_conv1d(g_cx, g_cw, g_cy, NC);
#endif
#ifdef K_k_conv3x3
    k_conv3x3(g_img, g_img_o, W2, W2);
#endif
#ifdef K_k_spmv
    k_spmv(g_val, g_col, g_rp, g_xv, g_yv, NR);
#endif
#ifdef K_k_lut256
    k_lut256(g_lut, g_lin, g_lout, LUTN);
#endif
    /* every output buffer is hashed for every kernel (and for none), so the hashing cost is the same in all runs and cancels */
    hb(g_c, sizeof g_c); hb(g_y32, sizeof g_y32); hb(g_cy, sizeof g_cy); hb(g_img_o, sizeof g_img_o); hb(g_yv, sizeof g_yv); hb(g_lout, sizeof g_lout);
    H ^= (uint64_t)(unsigned)r; H *= 1099511628211ULL;
    write(1, &H, 8);
    return 0;
}
