/* expect: 94738  vec: 2  flags: -ffp-contract=fast -ffast-math */
/* OpenBLAS daxpy and ddot: a multiply-add map on doubles, and a reduction (reassociated: -ffast-math) */
double x[70], y[70];
__attribute__((noinline)) void k_daxpy(int n, double a, const double *x, double *y)
{
    for (int i = 0; i < n; i++) y[i] += a * x[i];
}
__attribute__((noinline)) double k_ddot(int n, const double *x, const double *y)
{
    double s = 0;
    for (int i = 0; i < n; i++) s += x[i] * y[i];
    return s;
}
int test(void)
{
    static const int ns[] = { 0, 1, 3, 4, 5, 8, 11, 33, 64 };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 70; i++) { x[i] = (double)(i % 13); y[i] = (double)(i % 7 - 3); }
        k_daxpy(n, 2.0, x + 1, y);
        sum += (long)k_ddot(n, x, y) + 7 * (long)k_ddot(n, y, y);
        for (int i = 0; i < 66; i++) sum += (long)y[i] * i;
    }
    return (int)(sum % 100003);
}
