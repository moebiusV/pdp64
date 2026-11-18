/* expect: 2780  vec: 6 */
/* maps over bytes and words: dav1d prep_c (u8 << 4 into int16), 255 - x, an unsigned saturating add (clamped in C), a fill (dc_fill), a copy */
unsigned char src[300], dst[300];
short tmp[300];
__attribute__((noinline)) void k_prep8(short *tmp, const unsigned char *src, int w) { for (int x = 0; x < w; x++) tmp[x] = (short)(src[x] << 4); }
__attribute__((noinline)) void k_inv(unsigned char *d, const unsigned char *s, int n) { for (int i = 0; i < n; i++) d[i] = (unsigned char)(255 - s[i]); }
__attribute__((noinline)) void k_adds(unsigned char *d, const unsigned char *s, int n, int k)
{
    for (int i = 0; i < n; i++) { int t = s[i] + k; d[i] = t > 255 ? 255 : (unsigned char)t; }
}
__attribute__((noinline)) void k_fill(unsigned char *d, int w, int dc) { for (int x = 0; x < w; x++) d[x] = (unsigned char)dc; }
__attribute__((noinline)) void k_copy(unsigned char *d, const unsigned char *s, int n) { for (int i = 0; i < n; i++) d[i] = s[i]; }
int test(void)
{
    static const int ns[] = { 0, 1, 7, 8, 15, 16, 17, 31, 33, 100, 255 };
    long sum = 0;
    for (int i = 0; i < 300; i++) src[i] = (unsigned char)(i * 29 + 5);
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { dst[i] = 77; tmp[i] = 5; }
        k_prep8(tmp + 1, src + 1, n);
        for (int i = 0; i < 270; i++) sum += tmp[i] * (i % 11 + 1);
        k_inv(dst + 3, src + 1, n);
        for (int i = 0; i < 270; i++) sum += dst[i] * (i % 13 + 1);
        k_adds(dst + 1, src, n, 100);
        for (int i = 0; i < 270; i++) sum += dst[i] * (i % 7 + 1);
        k_fill(dst + 2, n, 200 + k);
        for (int i = 0; i < 270; i++) sum += dst[i] * (i % 5 + 1);
        k_copy(dst + 1, src + 2, n);
        for (int i = 0; i < 270; i++) sum += dst[i] * (i % 3 + 1);
    }
    return (int)(sum % 100003);
}
