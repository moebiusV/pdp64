/* expect: 53718  vec: 3  lv: 3  flags: -ffast-math -ffp-contract=fast */
/* the maximum of floats (softmax's first loop: vmaxacc, the same rule as the select), a scale by a scalar, and the rmsnorm sum of squares and map */
float x[300], o[300], wt[300];
__attribute__((noinline)) float k_max(const float *x, int n) { float m = x[0]; for (int i = 1; i < n; i++) if (x[i] > m) m = x[i]; return m; }
__attribute__((noinline)) float k_ss(const float *x, int n) { float ss = 0.0f; for (int i = 0; i < n; i++) ss += x[i] * x[i]; return ss; }
__attribute__((noinline)) void k_scale(float *o, const float *x, const float *wt, float s, int n) { for (int i = 0; i < n; i++) o[i] = wt[i] * (s * x[i]); }
int test(void)
{
    static const int ns[] = { 1, 2, 5, 8, 9, 16, 17, 100, 257 };
    long sum = 0;
    for (int i = 0; i < 300; i++) { x[i] = (float)((i * 37) % 101 - 50); wt[i] = (float)(i % 5 + 1); o[i] = 0; }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        sum += (long)k_max(x + 1, n) + (long)k_ss(x, n);
        k_scale(o + 1, x, wt, 0.5f, n);
        for (int i = 0; i < 270; i++) sum += (long)(o[i] * 2.0f) * (i % 7 + 1);
    }
    return (int)(sum % 100003);
}
