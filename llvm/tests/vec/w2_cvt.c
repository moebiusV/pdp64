/* expect: 44754  vec: 15  lv: 15  words: vcvt.l.f vcvt.lu.f vcvt.f.l vcvt.f.lu  flags: */
/* Wave 2, conversions of 32-bit lanes: sitofp (vcvt.l.f), uitofp (vcvt.lu.f), fptosi (vcvt.f.l), fptoui (vcvt.f.lu), also of bytes and halfwords (loaded as 32-bit lanes with
   vld.bu.l and so on, then converted) and a conversion with a clamped, narrowed store (the activation quantisation).  The values are in range (a float to integer conversion of
   a value out of range is poison in C and IR; w2_cvt_sat.c tests what the word does there): int to float rounds to nearest even (2^24+1, the tie 2^24+3, 0xffffffff), float to
   integer truncates toward zero (2.9 gives 2, -2.9 gives -2, 0.9 gives 0, -0.0 gives 0).  Trip counts 0, 1 and not multiples of the strip (8 lanes). */
int ia[300], io[300];
unsigned ua[300], uo[300];
float fa[300], fo[300];
short sa[300];
unsigned short ha[300];
signed char ca[300], co[300];
unsigned char ba[300], bo[300];
#define N __attribute__((noinline))
N void i2f(float *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }
N void u2f(float *c, const unsigned *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }
N void f2i(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)a[i]; }
N void f2u(unsigned *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (unsigned)a[i]; }
N void b2f(float *c, const unsigned char *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * (1.0f / 255.0f); }
N void sb2f(float *c, const signed char *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }
N void h2f(float *c, const unsigned short *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i] * 0.5f; }
N void sh2f(float *c, const short *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)a[i]; }
N void f2b(signed char *c, const float *a, float s, int n) { for (int i = 0; i < n; i++) { int t = (int)(a[i] * s); c[i] = t < -128 ? -128 : t > 127 ? 127 : t; } }
N void f2ub(unsigned char *c, const float *a, float s, int n) { for (int i = 0; i < n; i++) { int t = (int)(a[i] * s); c[i] = t < 0 ? 0 : t > 255 ? 255 : t; } }
N void rt(float *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (float)(int)a[i]; }
N void i2f_sum(float *c, const int *a, const int *b, int n) { for (int i = 0; i < n; i++) c[i] = (float)(int)((unsigned)a[i] + (unsigned)b[i]) * 0.25f; }
N void f2i_lane(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = (int)a[i] + (int)b[i]; }
static unsigned lcg = 31u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
static unsigned long cs(const void *p, int bytes) { const unsigned char *q = p; unsigned long h = 7; for (int i = 0; i < bytes; i++) h = h * 31 + q[i]; return h; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 65, 100, 290 };
    static const int ie[] = { 0, 1, -1, 16777216, 16777217, 16777219, 16777215, -16777217, -16777219, 2147483647, -2147483647 - 1, 2147483583, 255, -255, 65537 };
    static const unsigned ue[] = { 0u, 1u, 16777216u, 16777217u, 16777219u, 0xffffffffu, 0x80000000u, 0x7fffffffu, 0xfffffe80u, 4294967040u, 255u, 65537u, 3u };
    static const float fe[] = { 0.0f, -0.0f, 0.5f, -0.5f, 0.9f, -0.9f, 1.0f, -1.0f, 2.9f, -2.9f, 100.7f, -100.7f, 255.5f, -255.5f, 16777215.0f, 1073741824.0f, -1073741824.0f, 2147483520.0f, -2147483648.0f, 4294967040.0f, 3000000000.0f };
    unsigned long sum = 0;
    for (int i = 0; i < 300; i++) {
        unsigned r = rnd();
        ia[i] = (i % 2) ? ie[r % 15] : (int)r;
        ua[i] = (i % 2) ? ue[r % 13] : r;
        sa[i] = (short)((i % 5 == 0) ? -32768 : (i % 7 == 0) ? 32767 : (short)r); ha[i] = (unsigned short)((i % 5 == 0) ? 65535 : (i % 3 == 0) ? 0 : r);
        ca[i] = (signed char)((i % 5 == 0) ? -128 : (i % 7 == 0) ? 127 : r); ba[i] = (unsigned char)((i % 5 == 0) ? 255 : (i % 3 == 0) ? 0 : r);
        fa[i] = (i % 2) ? fe[r % 14] : (float)((int)(r % 2000) - 1000) * 0.37f;     /* |x| < 300: x * 100 is still in the range of int (the unsigned ones use fe's non-negative entries below) */
    }
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { io[i] = 31337; uo[i] = 4242; fo[i] = 1.25f; co[i] = 61; bo[i] = 71; }
        i2f(fo + 1, ia + 2, n);   sum = sum * 3 + cs(fo, sizeof fo);
        u2f(fo + 1, ua + 2, n);   sum = sum * 3 + cs(fo, sizeof fo);
        f2i(io + 1, fa + 2, n);   sum = sum * 3 + cs(io, sizeof io);
        b2f(fo + 1, ba + 2, n);   sum = sum * 3 + cs(fo, sizeof fo);
        sb2f(fo + 1, ca + 2, n);  sum = sum * 3 + cs(fo, sizeof fo);
        h2f(fo + 1, ha + 2, n);   sum = sum * 3 + cs(fo, sizeof fo);
        sh2f(fo + 1, sa + 2, n);  sum = sum * 3 + cs(fo, sizeof fo);
        f2b(co + 1, fa + 2, 0.5f, n);   sum = sum * 3 + cs(co, sizeof co);
        f2b(co + 1, fa + 2, 100.0f, n); sum = sum * 3 + cs(co, sizeof co);
        f2ub(bo + 1, fa + 2, 0.25f, n); sum = sum * 3 + cs(bo, sizeof bo);
        f2ub(bo + 1, fa + 2, 3.0f, n);  sum = sum * 3 + cs(bo, sizeof bo);
        rt(fo + 1, fa + 2, n);    sum = sum * 3 + cs(fo, sizeof fo);
        i2f_sum(fo + 1, ia + 2, ia + 3, n); sum = sum * 3 + cs(fo, sizeof fo);
        f2i_lane(io + 1, fa + 2, fa + 5, n); sum = sum * 3 + cs(io, sizeof io);
    }
    /* unsigned float to integer: the non-negative values only (negative is out of range) */
    for (int i = 0; i < 300; i++) fa[i] = (i % 2) ? (fe[i % 21] < 0.0f ? -fe[i % 21] : fe[i % 21]) : (float)(i * 1234567u % 4000000000u);
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) uo[i] = 4242;
        f2u(uo + 1, fa + 2, n);   sum = sum * 3 + cs(uo, sizeof uo);
    }
    return (int)(sum % 100003);
}
