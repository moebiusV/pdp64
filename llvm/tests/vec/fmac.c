/* expect: 26326  vec: 1  lv: 1  flags: -ffp-contract=fast */
/* FFmpeg vector_fmac_scalar_c: dst[i] += src[i] * mul.  Trip counts 0, 1, ... 33 (not multiples of the strip, 8 floats), dst at an offset, and one overlapping call (the run-time test sends it to the scalar loop). */
float dst[80], src[80];
__attribute__((noinline)) void k_fmac(float *dst, const float *src, float mul, int len)
{
    for (int i = 0; i < len; i++)
        dst[i] += src[i] * mul;
}
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 33, 40 };
    long sum = 0;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 80; i++) { dst[i] = (float)i; src[i] = (float)(2 * i + 1); }
        k_fmac(dst + 1, src, 3.0f, n);
        for (int i = 0; i < 42; i++) sum += (long)dst[i] * (i + 1);
    }
    for (int i = 0; i < 80; i++) { dst[i] = (float)(i & 7); src[i] = 0; }
    k_fmac(dst + 1, dst, 2.0f, 12);      /* overlapping: each element reads the one before it */
    for (int i = 0; i < 16; i++) sum += (long)dst[i] * (i + 3);
    return (int)(sum % 100003);
}
