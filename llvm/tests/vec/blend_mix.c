/* expect: 10793  vec: 2 */
/* an alpha blend of 8-bit channels (three byte streams widened to 32-bit lanes, multiplies, a division by 255 as shifts, a narrowing store) and the saturating audio mix of two 16-bit streams (a clamp that is one vsts) */
unsigned char d[300], s[300], al[300];
short o[300], p[300], q[300];
__attribute__((noinline)) void k_blend(unsigned char *dst, const unsigned char *src, const unsigned char *alpha, int n)
{
    for (int i = 0; i < n; i++) {
        unsigned a = alpha[i];
        unsigned t = src[i] * a + dst[i] * (255 - a) + 128;
        dst[i] = (unsigned char)((t + (t >> 8)) >> 8);
    }
}
__attribute__((noinline)) void k_mix16(short *o, const short *a, const short *b, int n)
{
    for (int i = 0; i < n; i++) {
        int sm = a[i] + b[i];
        o[i] = sm > 32767 ? 32767 : sm < -32768 ? -32768 : sm;
    }
}
int test(void)
{
    static const int ns[] = { 0, 1, 5, 8, 9, 16, 33, 100, 257 };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { d[i] = (unsigned char)(i * 3); s[i] = (unsigned char)(i * 5 + 1); al[i] = (unsigned char)(i * 11); }
        k_blend(d + 1, s, al + 2, n);
        for (int i = 0; i < 290; i++) sum += d[i] * (i % 9 + 1);
        for (int i = 0; i < 300; i++) { p[i] = (short)(i * 211 - 30000); q[i] = (short)(30000 - i * 97); o[i] = 1; }
        k_mix16(o + 1, p + 1, q, n);
        for (int i = 0; i < 290; i++) sum += o[i] * (i % 7 + 1);
    }
    return (int)(sum % 100003);
}
