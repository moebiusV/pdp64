/* cdrv.c: the kernels of the inference study in plain C, for the LLVM back end (what llc produces, and what it costs): -DK_name selects one */
typedef unsigned short u16; typedef unsigned int u32; typedef signed char s8; typedef unsigned char u8; typedef unsigned long u64;
long write(int, const void *, unsigned long);
#define N 4096
u16 A[N], B[N]; s8 Wq[N], Xq[N]; float F[N], G[N]; u16 H[N];
static inline float bf2f(u16 h) { union { u32 u; float f; } c; c.u = (u32)h << 16; return c.f; }
static inline u16 f2bf(float f) { union { float f; u32 u; } c; c.f = f; u32 u = c.u; if ((u & 0x7fffffff) > 0x7f800000) return (u >> 16) | 0x40; return (u + 0x7fff + ((u >> 16) & 1)) >> 16; }
__attribute__((noinline)) float k_bfdot(const u16 *a, const u16 *b, int n) { float s = 0; for (int i = 0; i < n; i++) s += bf2f(a[i]) * bf2f(b[i]); return s; }
__attribute__((noinline)) int k_i8dot(const s8 *a, const s8 *b, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
__attribute__((noinline)) void k_f2bf(const float *x, u16 *y, int n) { for (int i = 0; i < n; i++) y[i] = f2bf(x[i]); }
__attribute__((noinline)) void k_bf2f(const u16 *x, float *y, int n) { for (int i = 0; i < n; i++) y[i] = bf2f(x[i]); }
__attribute__((noinline)) void k_dq(const s8 *w, float *y, float sc, int n) { for (int i = 0; i < n; i++) y[i] = (float)w[i] * sc; }
__attribute__((noinline)) float k_dotf(const float *a, const float *b, int n) { float s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s; }
/* a register-blocked 4x4 bf16 tile: C[4][4] += A[4][K] B[4][K]^T (bf16 inputs) */
__attribute__((noinline)) void k_tile(const u16 *a, const u16 *b, float *c, int K) {
    float acc[4][4] = {{0}};
    for (int k = 0; k < K; k++) for (int i = 0; i < 4; i++) { float x = bf2f(a[i * K + k]); for (int j = 0; j < 4; j++) acc[i][j] += x * bf2f(b[j * K + k]); }
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) c[i * 4 + j] = acc[i][j];
}
/* scalar expf, degree-5 polynomial after the usual reduction */
__attribute__((noinline)) float k_expf(float x) {
    if (x < -87.f) x = -87.f; if (x > 88.f) x = 88.f;
    float t = x * 1.4426950408889634f; float nr = (float)(int)(t + (t < 0 ? -0.5f : 0.5f)); float f = t - nr;
    float p = 1.5403530e-4f; p = p * f + 1.3333558e-3f; p = p * f + 9.6181291e-3f; p = p * f + 5.5504109e-2f; p = p * f + 2.4022651e-1f; p = p * f + 6.9314718e-1f; p = p * f + 1.0f;
    union { u32 u; float f; } s; s.u = (u32)((int)nr + 127) << 23; return p * s.f;
}
__attribute__((noinline)) void k_softmax(const float *x, float *y, int n) {
    float m = x[0]; for (int i = 1; i < n; i++) if (x[i] > m) m = x[i];
    float s = 0; for (int i = 0; i < n; i++) { float e = k_expf(x[i] - m); y[i] = e; s += e; }
    float r = 1.f / s; for (int i = 0; i < n; i++) y[i] *= r;
}
unsigned long R;
int main(void) {
    for (int i = 0; i < N; i++) { A[i] = (u16)(0x3f00 + (i * 37 & 0xff)); B[i] = (u16)(0x3e80 + (i * 91 & 0xff)); Wq[i] = (s8)(i * 7); Xq[i] = (s8)(i * 13); F[i] = (float)((i & 63) - 32) * 0.125f; H[i] = A[i]; }
#ifdef K_bfdot
    union { float f; u32 u; } c; c.f = k_bfdot(A, B, N); R = c.u;
#elif defined K_i8dot
    R = k_i8dot(Wq, Xq, N);
#elif defined K_f2bf
    k_f2bf(F, H, N); R = H[5] + H[N - 1];
#elif defined K_bf2f
    k_bf2f(A, G, N); R = (u32)G[5];
#elif defined K_dq
    k_dq(Wq, G, 0.0123f, N); R = (u32)G[7];
#elif defined K_dotf
    union { float f; u32 u; } c; c.f = k_dotf(F, G, N); R = c.u;
#elif defined K_tile
    k_tile(A, B, G, 256); R = (u32)G[3];
#elif defined K_softmax
    k_softmax(F, G, 1024); R = (u32)(G[3] * 1e6f);
#endif
    write(1, &R, 8); return 0;
}
