/* expect: 0  vec: 4  lv: 4  scalar: 255030233  words: vcvt.f.l vcvt.f.lu  flags: */
/* Wave 2: what float to integer does out of range, the rule of the word (vec-isa.md section 7): truncates toward zero and SATURATES; a NaN gives the largest value.  Signed (vcvt.f.l):
   >= 2^31 gives 0x7fffffff, < -2^31 gives 0x80000000, NaN gives 0x7fffffff, -0.0 gives 0.  Unsigned (vcvt.f.lu): <= -1.0 gives 0 (and -0.5, -0.0), NaN and >= 2^32 give 0xffffffff.
   LLVM's fptosi / fptoui are poison out of range, so this is a legal refinement of the IR, and it is also what the scalar instruction does (the three builds agree).  The result is the
   NUMBER OF LANES THAT DIFFER from the reference below, as b1 * 10^6 + b2 * 10^3 + b3 (expect 0).  The SCALAR build is not the reference: llc's `(int)x` is fcvtsd + fcvtdq (a 64-bit
   conversion, low 32 bits: wraps out of range) and `scalar:` in the first line is what it gives (255, 30 and 233 lanes; a missed `fcvtsl`).  NOT a host test: x86's cvttss2si gives 0x80000000
   for all of these (the host check is expected to disagree). */
float fa[300];
int io[300];
unsigned uo[300];
#define N __attribute__((noinline))
N void f2i(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)a[i]; }
N void f2u(unsigned *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (unsigned)a[i]; }
N void f2i_neg(int *c, const float *a, int n) { for (int i = 0; i < n; i++) c[i] = (int)(-a[i]); }
static float bits(unsigned u) { union { unsigned u; float f; } x; x.u = u; return x.f; }
static int ref_i(float x)
{
    if (x != x) return 0x7fffffff;
    if (x >= 2147483648.0f) return 0x7fffffff;
    if (x < -2147483648.0f) return (int)0x80000000;
    return (int)x;   /* in range: the truncation */
}
static unsigned ref_u(float x)
{
    if (x != x) return 0xffffffffu;
    if (x >= 4294967296.0f) return 0xffffffffu;
    if (x <= -1.0f) return 0u;
    if (x < 0.0f) return 0u;
    return (unsigned)x;
}
int test(void)
{
    static const unsigned tab[] = { 0x7fc00000u, 0xffc00000u, 0x7f800000u, 0xff800000u, 0x4f000000u, 0xcf000000u, 0x4efffffeu, 0xcf000001u, 0x4f800000u, 0x4f7fffffu, 0x4f800001u, 0x7f7fffffu,
                                    0xff7fffffu, 0x80000000u, 0x00000000u, 0xbf000000u, 0xbf800000u, 0xbf7fffffu, 0xbfc00000u, 0x3f000000u, 0x3f7fffffu, 0x40100000u, 0xc0100000u, 0x00000001u, 0x80000001u,
                                    0x4effffffu, 0xcefffffeu };
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 65, 100, 290 };
    int b1 = 0, b2 = 0, b3 = 0;
    int nt = sizeof tab / sizeof *tab;
    for (int i = 0; i < 300; i++) fa[i] = bits(tab[(i * 7 + i / 3) % nt]);
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { io[i] = 31337; uo[i] = 4242; }
        f2i(io + 1, fa + 2, n);
        for (int i = 0; i < 300; i++) b1 += io[i] != ((i >= 1 && i < 1 + n) ? ref_i(fa[i + 1]) : 31337);
        f2u(uo + 1, fa + 2, n);
        for (int i = 0; i < 300; i++) b2 += uo[i] != ((i >= 1 && i < 1 + n) ? ref_u(fa[i + 1]) : 4242u);
        f2i_neg(io + 1, fa + 2, n);
        for (int i = 0; i < 300; i++) b3 += io[i] != ((i >= 1 && i < 1 + n) ? ref_i(-fa[i + 1]) : 31337);
    }
    return b1 * 1000000 + b2 * 1000 + b3;   /* the lanes that differ from the reference: signed, unsigned, negated signed */
}
