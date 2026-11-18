/* expect: 79838  vec: 27  lv: 27  words: vcgt.f vbsl  flags: -ffast-math */
/* The same compares and selects with -ffast-math (nnan: the unordered predicates are the ordered ones, <= and >= are the negation of the other ordering: one compare, no vor) and no NaN, infinity,
   negative zero or denormal in the data (fast-math: the sign of a zero and denormals are not preserved).  Result: the same program as w2_fcmp.c, on finite values.  Trip counts 0, 1 and not multiples of the strip. */
float fa[300], fb[300], fo[300], fx[300];
int io[300];
unsigned char bo[300];
#define N __attribute__((noinline))
N void f_lt(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < b[i] ? 1 : 2; }
N void f_le(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] <= b[i] ? 1 : 2; }
N void f_gt(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > b[i] ? 1 : 2; }
N void f_ge(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] >= b[i] ? 1 : 2; }
N void f_eq(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] == b[i] ? 1 : 2; }
N void f_ne(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] != b[i] ? 1 : 2; }
N void f_nlt(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = !(a[i] < b[i]) ? 1 : 2; }
N void f_nle(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = !(a[i] <= b[i]) ? 1 : 2; }
N void f_ngt(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = !(a[i] > b[i]) ? 1 : 2; }
N void f_nge(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = !(a[i] >= b[i]) ? 1 : 2; }
N void f_one(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = ((a[i] < b[i]) | (a[i] > b[i])) ? 1 : 2; }
N void f_ueq(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = !((a[i] < b[i]) | (a[i] > b[i])) ? 1 : 2; }
N void f_ord(int *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = ((a[i] == a[i]) & (b[i] == b[i])) ? 1 : 2; }
N void k_lt(int *c, const float *a, float t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < t ? 1 : 2; }
N void k_ge(int *c, const float *a, float t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] >= t ? 1 : 2; }
N void k_ne(int *c, const float *a, float t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] != t ? 1 : 2; }
N void k_eq(int *c, const float *a, float t, int n) { for (int i = 0; i < n; i++) c[i] = a[i] == t ? 1 : 2; }
N void k_gt0(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > 0.0f ? 1 : 2; }
N void k_le0(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] <= 0.0f ? 1 : 2; }
N void a_max(float *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > b[i] ? a[i] : b[i]; }
N void a_min(float *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < b[i] ? a[i] : b[i]; }
N void a_thr(float *c, const float *a, float t, float lo, float hi, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > t ? hi : lo; }
N void a_relu(float *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = a[i] > 0.0f ? a[i] : 0.0f; }
N void a_leaky(float *c, const float *a, float s, int n) { for (int i = 0; i < n; i++) { float v = a[i]; float w = v * s; c[i] = v > 0.0f ? v : w; } }
N void a_mask(unsigned char *c, const float *a, const float *b, int n) { for (int i = 0; i < n; i++) c[i] = a[i] < b[i]; }
N int a_count(const float *a, float t, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i] > t; return s; }
static unsigned lcg = 77u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
static float bits(unsigned u) { union { unsigned u; float f; } x; x.u = u; return x.f; }
static unsigned long cs(const void *p, int bytes) { const unsigned char *q = p; unsigned long h = 7; for (int i = 0; i < bytes; i++) h = h * 31 + q[i]; return h; }
int test(void)
{
    static const unsigned tab[] = { 0x00000000u, 0x3f800000u, 0xbf800000u, 0x40200000u, 0x3e800000u, 0xbe800000u, 0x3f800000u, 0xc0200000u, 0x42c80000u, 0xc2c80000u, 0x3f800000u, 0x40000000u, 0x00000000u };
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 65, 100, 290 };
    unsigned long sum = 0;
    for (int i = 0; i < 300; i++) fx[i] = (float)(i % 11 - 5) * 0.75f;   /* finite: the leaky ReLU multiplies (a NaN's payload after arithmetic is not the same on every machine) */
    for (int i = 0; i < 300; i++) { unsigned r = rnd(); fa[i] = bits(tab[r % 13]); fb[i] = (i % 4 == 0) ? fa[i] : bits(tab[(r >> 6) % 13]); }
    static const float ts[] = { 0.0f, 0.25f, 1.0f, -1.0f };
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        #define R() for (int i = 0; i < 300; i++) { io[i] = 31337; fo[i] = bits(0x12345678u); bo[i] = 71; }
        R()
        f_lt(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_le(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_gt(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_ge(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_eq(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_ne(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_nlt(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_nle(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_ngt(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_nge(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_one(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_ueq(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        f_ord(io + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(io, sizeof io);
        for (int j = 0; j < 4; j++) {
            k_lt(io + 1, fa + 2, ts[j], n); sum = sum * 3 + cs(io, sizeof io);
            k_ge(io + 1, fa + 2, ts[j], n); sum = sum * 3 + cs(io, sizeof io);
            k_ne(io + 1, fa + 2, ts[j], n); sum = sum * 3 + cs(io, sizeof io);
            k_eq(io + 1, fa + 2, ts[j], n); sum = sum * 3 + cs(io, sizeof io);
            a_count(fa + 1, ts[j], n);
            sum = sum * 3 + (unsigned)a_count(fa + 1, ts[j], n);
            a_thr(fo + 1, fa + 2, ts[j], 5.5f, -7.25f, n); sum = sum * 3 + cs(fo, sizeof fo);
        }
        k_lt(io + 1, fa + 2, 0.5f, n); sum = sum * 3 + cs(io, sizeof io);
        k_ne(io + 1, fa + 2, 0.5f, n); sum = sum * 3 + cs(io, sizeof io);
        k_ge(io + 1, fa + 2, 1000.0f, n); sum = sum * 3 + cs(io, sizeof io);
        k_gt0(io + 1, fa + 2, n); sum = sum * 3 + cs(io, sizeof io);
        k_le0(io + 1, fa + 2, n); sum = sum * 3 + cs(io, sizeof io);
        a_max(fo + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(fo, sizeof fo);
        a_min(fo + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(fo, sizeof fo);
        a_relu(fo + 1, fa + 2, n); sum = sum * 3 + cs(fo, sizeof fo);
        a_leaky(fo + 1, fx + 2, 0.5f, n); sum = sum * 3 + cs(fo, sizeof fo);
        a_mask(bo + 1, fa + 2, fb + 3, n); sum = sum * 3 + cs(bo, sizeof bo);
    }
    return (int)(sum % 100003);
}
