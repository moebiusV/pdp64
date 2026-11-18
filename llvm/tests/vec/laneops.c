/* expect: 73994  vec: 10   lv: 9 */
/* the lane operations that the other kernels do not reach: sub, or, signed and unsigned min and max, saturating subtract and unsigned saturating add and subtract, negate, the minimum reduction, a shift by a scalar, a scalar minus a vector */
short a[300], b[300], r[300];
unsigned char u[300], v[300], w[300];
float f[300], g[300];
int ia[300];
__attribute__((noinline)) void k_sub_or(short *r, const short *a, const short *b, int n) { for (int i = 0; i < n; i++) r[i] = (short)((a[i] - b[i]) | 3); }
__attribute__((noinline)) void k_maxmin(short *r, const short *a, const short *b, int n)
{
    for (int i = 0; i < n; i++) { short x = a[i], y = b[i]; short mx = x > y ? x : y; short mn = x < y ? x : y; r[i] = (short)(mx - mn); }
}
__attribute__((noinline)) void k_umaxmin(unsigned char *r, const unsigned char *a, const unsigned char *b, int n)
{
    for (int i = 0; i < n; i++) { unsigned char x = a[i], y = b[i]; unsigned char mx = x > y ? x : y; unsigned char mn = x < y ? x : y; r[i] = (unsigned char)(mx + mn); }
}
__attribute__((noinline)) void k_ssub(short *r, const short *a, const short *b, int n) { for (int i = 0; i < n; i++) r[i] = __builtin_elementwise_sub_sat(a[i], b[i]); }
__attribute__((noinline)) void k_uadd(unsigned char *r, const unsigned char *a, const unsigned char *b, int n) { for (int i = 0; i < n; i++) r[i] = __builtin_elementwise_add_sat(a[i], b[i]); }
__attribute__((noinline)) void k_usub(unsigned char *r, const unsigned char *a, const unsigned char *b, int n) { for (int i = 0; i < n; i++) r[i] = __builtin_elementwise_sub_sat(a[i], b[i]); }
__attribute__((noinline)) void k_neg(float *r, const float *a, int n) { for (int i = 0; i < n; i++) r[i] = -a[i]; }
__attribute__((noinline)) int k_min(const int *a, int n) { int m = 2000000000; for (int i = 0; i < n; i++) m = a[i] < m ? a[i] : m; return m; }
__attribute__((noinline)) void k_shift(int *r, const int *a, int n, int s) { for (int i = 0; i < n; i++) r[i] = (a[i] << s) - 1000 + (100 - a[i]); }
int test(void)
{
    static const int ns[] = { 0, 1, 7, 8, 9, 17, 100 };
    long sum = 0;
    for (int i = 0; i < 300; i++) { a[i] = (short)(i * 311 - 20000); b[i] = (short)(15000 - i * 197); u[i] = (unsigned char)(i * 29 + 5); v[i] = (unsigned char)(i * 43 + 200); f[i] = (float)(i - 50); ia[i] = (i * 7919) % 10007 - 5000; }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { r[i] = 9; w[i] = 9; g[i] = 1; }
        k_sub_or(r + 1, a + 1, b, n); for (int i = 0; i < 120; i++) sum += r[i] * (i % 7 + 1);
        k_maxmin(r + 2, a, b + 1, n); for (int i = 0; i < 120; i++) sum += r[i] * (i % 5 + 1);
        k_umaxmin(w + 1, u, v + 1, n); for (int i = 0; i < 120; i++) sum += w[i] * (i % 11 + 1);
        k_ssub(r + 1, a, b, n); for (int i = 0; i < 120; i++) sum += r[i] * (i % 13 + 1);
        k_uadd(w + 3, u, v, n); for (int i = 0; i < 120; i++) sum += w[i] * (i % 3 + 1);
        k_usub(w + 1, v, u, n); for (int i = 0; i < 120; i++) sum += w[i] * (i % 17 + 1);
        k_neg(g + 1, f, n); for (int i = 0; i < 120; i++) sum += (long)g[i] * (i % 9 + 1);
        sum += k_min(ia + 1, n);
        k_shift((int *)r, ia, n, 3); sum += ((int *)r)[0] + ((int *)r)[n > 0 ? n - 1 : 0];
    }
    return (int)(sum % 100003);
}
