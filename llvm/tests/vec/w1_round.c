/* expect: 15657  vec: 12  lv: 12  strip: 23  words: vsarr.w vsarr.l vshrr.w vsts.l.b vsts.l.bu vsts.l.w vmla.w vmla.l  flags: */
/* Wave 1: the shift that rounds (vsarr / vshrr: (x + 2^(s-1)) >> s, arithmetic and logical, halfword and word lanes), the store that rounds and clamps (vsts #sh: the activation
   quantisation (x + 2^(s-1)) >> s clamped to the stored type) and the multiply-add of vectors (vmla.w, vmla.l: acc + a * b).  Corners: ties (x + half is a multiple of 2^s),
   negative ties, values at the clamp edges, 0 and the largest values whose sum does not overflow (the C code has no overflow: the IR carries nsw / nuw). */
short sa[400], sd[400];
unsigned short ha[400], hd[400];
int ia[400], ib[400], id[400], io[400];
unsigned ua[400], ud[400];
signed char c8[400];
unsigned char u8[400];
__attribute__((noinline)) void k_rsh16(short *c, const short *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 8) >> 4; }
__attribute__((noinline)) void k_rsh32(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 32) >> 6; }
__attribute__((noinline)) void k_rshu32(unsigned *c, const unsigned *a, int n) { for (unsigned i = 0; i < (unsigned)n; i++) c[i] = (a[i] + 128u) >> 8; }
__attribute__((noinline)) void k_rshu16(unsigned short *c, const unsigned short *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 4) >> 3; }
__attribute__((noinline)) void k_rsh1(int *c, const int *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + 1) >> 1; }
__attribute__((noinline)) void k_q8(signed char *c, const int *a, int n) { for (int i = 0; i < n; i++) { int t = (a[i] + 128) >> 8; c[i] = t < -128 ? -128 : t > 127 ? 127 : t; } }
__attribute__((noinline)) void k_qu8(unsigned char *c, const int *a, int n) { for (int i = 0; i < n; i++) { int t = (a[i] + 32) >> 6; c[i] = t < 0 ? 0 : t > 255 ? 255 : t; } }
__attribute__((noinline)) void k_q16(short *c, const int *a, int n) { for (int i = 0; i < n; i++) { int t = (a[i] + 2048) >> 12; c[i] = t < -32768 ? -32768 : t > 32767 ? 32767 : t; } }
__attribute__((noinline)) void k_qmul(signed char *c, const short *a, int sc, int n) { for (int i = 0; i < n; i++) { int t = (a[i] * sc + 8192) >> 14; c[i] = t < -128 ? -128 : t > 127 ? 127 : t; } }
__attribute__((noinline)) void k_mla32(unsigned *c, const unsigned *a, const unsigned *b, const unsigned *d, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * b[i] + d[i]; }
__attribute__((noinline)) void k_mla16(unsigned short *c, const unsigned short *a, const unsigned short *b, const unsigned short *d, int n) { for (int i = 0; i < n; i++) c[i] = (unsigned short)(a[i] * b[i] + d[i]); }
__attribute__((noinline)) void k_mlak(unsigned *c, const unsigned *a, unsigned k, const unsigned *d, int n) { for (int i = 0; i < n; i++) c[i] = a[i] * k + d[i]; }
static unsigned lcg = 4242u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
static unsigned long cs(const void *p, int bytes) { const unsigned char *q = p; unsigned long h = 7; for (int i = 0; i < bytes; i++) h = h * 31 + q[i]; return h; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 65, 100, 300 };
    static const int tie[] = { 0, 1, 7, 8, 9, 15, 16, 23, 24, -1, -7, -8, -9, -24, 32760, -32768, 32767 };
    unsigned long sum = 0;
    for (int i = 0; i < 400; i++) {
        unsigned r = rnd();
        sa[i] = (i % 3 == 0) ? (short)(tie[r % 17] * (i % 2 ? 1 : 1)) : (short)(r % 32000 - 16000);
        if (sa[i] > 32759) sa[i] = 32759;     /* x + 8 must not overflow */
        ha[i] = (i % 3 == 0) ? (unsigned short)(r % 65500) : (unsigned short)(r);
        if (ha[i] > 65530) ha[i] = 65530;
        ia[i] = (i % 3 == 0) ? tie[r % 17] * 4096 + (int)(r % 5) - 2 : (int)(r % 2000000) - 1000000;
        ib[i] = (int)(r % 2001) - 1000;
        id[i] = (int)(r >> 3) % 1000 - 500;
        ua[i] = (i % 3 == 0) ? (unsigned)tie[r % 17] * 256u + (r % 3) : r;
        if (ua[i] > 0xfffffff0u) ua[i] = 0xfffffff0u;
    }
    ia[3] = 2147483647 - 4096; ia[4] = -2147483647 - 1 + 2; ia[5] = 127 * 256 + 128 - 1; ia[6] = 127 * 256 + 128; ia[7] = -128 * 256 - 128; ia[8] = -128 * 256 - 129;
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 400; i++) { sd[i] = 4444; hd[i] = 5555; io[i] = 666; ud[i] = 777; c8[i] = 55; u8[i] = 66; }
        k_rsh16(sd + 1, sa + 2, n);   sum = sum * 5 + cs(sd, sizeof sd);
        k_rshu16(hd + 1, ha + 2, n);  sum = sum * 5 + cs(hd, sizeof hd);
        k_rsh32(io + 1, ia + 2, n);   sum = sum * 5 + cs(io, sizeof io);
        k_rshu32(ud + 1, ua + 2, n);  sum = sum * 5 + cs(ud, sizeof ud);
        k_rsh1(io + 1, ib + 2, n);    sum = sum * 5 + cs(io, sizeof io);
        k_q8(c8 + 1, ia + 2, n);      sum = sum * 5 + cs(c8, sizeof c8);
        k_qu8(u8 + 1, ia + 2, n);     sum = sum * 5 + cs(u8, sizeof u8);
        k_q16(sd + 1, ia + 2, n);     sum = sum * 5 + cs(sd, sizeof sd);
        k_qmul(c8 + 1, sa + 2, 12000, n); sum = sum * 5 + cs(c8, sizeof c8);
        k_qmul(c8 + 1, sa + 2, -3, n);    sum = sum * 5 + cs(c8, sizeof c8);
        k_mla32((unsigned *)io + 1, (unsigned *)ia + 2, (unsigned *)ib + 3, (unsigned *)id + 1, n); sum = sum * 5 + cs(io, sizeof io);
        k_mlak((unsigned *)io + 1, (unsigned *)ib + 2, 77, (unsigned *)id + 1, n);     sum = sum * 5 + cs(io, sizeof io);
        k_mla16(hd + 1, ha + 2, ha + 3, hd + 7, n);         sum = sum * 5 + cs(hd, sizeof hd);
    }
    return (int)(sum % 100003);
}
