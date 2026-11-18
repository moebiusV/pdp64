/* expect: -7998  vec: 2   lv: 2 */
/* llama.cpp q8_0 dot (int8 x int8 into int32: sign-extending loads, multiply, reduction) and FFmpeg pixel_sad_c (the row is a block with a reduction, the rows stay scalar) */
signed char w[300], x[300];
unsigned char a[400], b[400];
__attribute__((noinline)) int k_q8dot(const signed char *w, const signed char *x, int n)
{
    int s = 0;
    for (int i = 0; i < n; i++) s += w[i] * x[i];
    return s;
}
__attribute__((noinline)) int k_sad(const unsigned char *a, long as, const unsigned char *b, long bs, int w, int h)
{
    int sum = 0;
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) sum += __builtin_abs(a[x] - b[x]);
        a += as; b += bs;
    }
    return sum;
}
int test(void)
{
    static const int ns[] = { 0, 1, 7, 8, 9, 31, 32, 33, 255 };
    long sum = 0;
    for (int i = 0; i < 300; i++) { w[i] = (signed char)(i * 7 - 100); x[i] = (signed char)(90 - i * 3); }
    for (int i = 0; i < 400; i++) { a[i] = (unsigned char)(i * 13); b[i] = (unsigned char)(i * 17 + 3); }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        sum += k_q8dot(w + 1, x, n) + k_sad(a, 20, b + 1, 24, n % 20, 5) + k_sad(a, 20, b, 20, n % 16, 3);
    }
    return (int)(sum % 100003);
}
