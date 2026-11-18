/* expect: 3344  vec: 5  flags: -ffp-contract=fast */
/* the vertex transform (structure of arrays: six float streams and twelve matrix scalars in registers) and the horizontal 8-tap filter of dav1d (eight shifted byte streams, int8 taps, round, shift, clamp to 0..255) */
float ox[100], oy[100], oz[100], X[100], Y[100], Z[100];
unsigned char dst[300], src[320];
signed char F[8];
__attribute__((noinline)) void k_vtx(float *ox, float *oy, float *oz, const float *x, const float *y, const float *z, const float *m, int n)
{
    for (int i = 0; i < n; i++) {
        ox[i] = m[0] * x[i] + m[1] * y[i] + m[2] * z[i] + m[3];
        oy[i] = m[4] * x[i] + m[5] * y[i] + m[6] * z[i] + m[7];
        oz[i] = m[8] * x[i] + m[9] * y[i] + m[10] * z[i] + m[11];
    }
}
__attribute__((noinline)) void k_put8h(unsigned char *dst, const unsigned char *src, int w, const signed char *F)
{
    for (int x = 0; x < w; x++) {
        int s = F[0] * src[x - 3] + F[1] * src[x - 2] + F[2] * src[x - 1] + F[3] * src[x + 0] +
                F[4] * src[x + 1] + F[5] * src[x + 2] + F[6] * src[x + 3] + F[7] * src[x + 4];
        s = (s + 32) >> 6;
        dst[x] = s < 0 ? 0 : s > 255 ? 255 : s;
    }
}
int test(void)
{
    static const int ns[] = { 0, 1, 7, 8, 9, 33, 80 };
    static const float m[12] = { 1, 2, 3, 4, -1, 2, -3, 5, 2, 0, 1, -7 };
    long sum = 0;
    for (int i = 0; i < 100; i++) { X[i] = (float)(i % 9); Y[i] = (float)(i % 5 - 2); Z[i] = (float)(7 - i % 11); }
    for (int i = 0; i < 320; i++) src[i] = (unsigned char)(i * 23 + 9);
    F[0] = -1; F[1] = 3; F[2] = -10; F[3] = 57; F[4] = 18; F[5] = -6; F[6] = 2; F[7] = -1;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 100; i++) { ox[i] = oy[i] = oz[i] = 0; }
        k_vtx(ox + 1, oy, oz + 2, X, Y + 1, Z, m, n);
        for (int i = 0; i < 90; i++) sum += (long)(ox[i] + 3 * oy[i] + 5 * oz[i]) * (i + 1);
        for (int i = 0; i < 300; i++) dst[i] = 1;
        k_put8h(dst + 1, src + 8, n, F);
        for (int i = 0; i < 100; i++) sum += dst[i] * (i % 17 + 1);
    }
    return (int)(sum % 100003);
}
