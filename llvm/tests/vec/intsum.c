/* expect: -1211  vec: 4   lv: 4 */
/* integer reductions: the sum of bytes (dav1d dc_gen_top, zero-extended load), of int32 and of int16 (sign-extended into 64 bits), the maximum and minimum of int32 */
unsigned char b[300];
int a[300];
short h[300];
__attribute__((noinline)) unsigned k_dctop_sum(const unsigned char *top, int width)
{
    unsigned dc = width >> 1;
    for (int i = 0; i < width; i++) dc += top[i];
    return dc;
}
__attribute__((noinline)) int k_sum32(const int *p, int n) { int s = 0; for (int i = 0; i < n; i++) s += p[i]; return s; }
__attribute__((noinline)) long k_sum16(const short *p, int n) { long s = 0; for (int i = 0; i < n; i++) s += p[i]; return s; }
__attribute__((noinline)) int k_max32(const int *p, int n) { int m = -2000000000; for (int i = 0; i < n; i++) m = p[i] > m ? p[i] : m; return m; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 5, 8, 9, 16, 17, 100, 255 };
    long sum = 0;
    for (int i = 0; i < 300; i++) { b[i] = (unsigned char)(i * 37 + 11); a[i] = (i * 7919) % 10007 - 5000; h[i] = (short)(i * 311 - 20000); }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        sum += k_dctop_sum(b + 1, n) + k_sum32(a + 1, n) + k_sum16(h + 1, n) + 3L * k_max32(a, n);
    }
    return (int)(sum % 100003);
}
