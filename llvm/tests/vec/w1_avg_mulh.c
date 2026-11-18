/* expect: 37587  vec: 12  lv: 12  words: vavgu.b vavg.b vavgu.w vavg.w vmulh.w vmulhu.w vmulhr.w  flags: */
/* Wave 1 words made from C: the rounding average (vavg.b, vavgu.b, vavg.w, vavgu.w: (a+b+1)>>1 in a wider type), the high half of a 16 x 16 multiply
   (vmulh.w, vmulhu.w; also with a constant) and the Q15 rounding multiply that saturates (vmulhr.w: (a*b + 2^14) >> 15 clamped to 32767).  Trip counts 0, 1 and not multiples of
   the strip (32 bytes, 16 halfwords); the corners are in the data: 0, 1, 127, 128, 254, 255, -128, 32767, -32768, 65535. */
unsigned char ua[300], ub[300], uc[300];
signed char sa8[300], sb8[300], sc8[300];
unsigned short ha[300], hb[300], hc[300];
short sa[300], sb[300], sc[300];
__attribute__((noinline)) void k_avgu8(unsigned char *c, const unsigned char *a, const unsigned char *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + b[i] + 1) >> 1; }
__attribute__((noinline)) void k_avgs8(signed char *c, const signed char *a, const signed char *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + b[i] + 1) >> 1; }
__attribute__((noinline)) void k_avgu16(unsigned short *c, const unsigned short *a, const unsigned short *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + b[i] + 1) >> 1; }
__attribute__((noinline)) void k_avgs16(short *c, const short *a, const short *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] + b[i] + 1) >> 1; }
__attribute__((noinline)) void k_mulh(short *c, const short *a, const short *b, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] * b[i]) >> 16; }
__attribute__((noinline)) void k_mulhu(unsigned short *c, const unsigned short *a, const unsigned short *b, int n) { for (int i = 0; i < n; i++) c[i] = ((unsigned)a[i] * b[i]) >> 16; }
__attribute__((noinline)) void k_mulhk(short *c, const short *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] * 23170) >> 16; }
__attribute__((noinline)) void k_mulhkn(short *c, const short *a, int n) { for (int i = 0; i < n; i++) c[i] = (a[i] * -9999) >> 16; }
__attribute__((noinline)) void k_mulhuk(unsigned short *c, const unsigned short *a, int n) { for (int i = 0; i < n; i++) c[i] = ((unsigned)a[i] * 50000u) >> 16; }
__attribute__((noinline)) void k_mulhuk2(unsigned short *c, const unsigned short *a, int n) { for (int i = 0; i < n; i++) c[i] = ((unsigned)a[i] * 65535u) >> 16; }
__attribute__((noinline)) void k_q15(short *c, const short *a, const short *b, int n) { for (int i = 0; i < n; i++) { int t = (a[i] * b[i] + 16384) >> 15; c[i] = t > 32767 ? 32767 : t; } }
static unsigned lcg = 12345u;
static unsigned rnd(void) { lcg = lcg * 1103515245u + 12345u; return lcg >> 8; }
static const int edge8[] = { 0, 1, 2, 126, 127, 128, 129, 253, 254, 255 };
static const int edge16[] = { 0, 1, 2, 32766, 32767, 32768, 32769, 65534, 65535, 16384, 16383 };
static void fill(void)
{
    for (int i = 0; i < 300; i++) {
        unsigned r = rnd();
        ua[i] = (i % 3 == 0) ? (unsigned char)edge8[r % 10] : (unsigned char)r;
        ub[i] = (i % 4 == 0) ? (unsigned char)edge8[(r >> 4) % 10] : (unsigned char)(r >> 3);
        sa8[i] = (signed char)ua[i]; sb8[i] = (signed char)ub[i];
        ha[i] = (i % 3 == 0) ? (unsigned short)edge16[r % 11] : (unsigned short)r;
        hb[i] = (i % 4 == 0) ? (unsigned short)edge16[(r >> 4) % 11] : (unsigned short)(r >> 5);
        sa[i] = (short)ha[i]; sb[i] = (short)hb[i];
    }
}
static unsigned long cs8(const unsigned char *p, int n) { unsigned long h = 7; for (int i = 0; i < n; i++) h = h * 31 + p[i]; return h; }
static unsigned long cs16(const unsigned short *p, int n) { unsigned long h = 7; for (int i = 0; i < n; i++) h = h * 31 + p[i]; return h; }
int test(void)
{
    static const int ns[] = { 0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 64, 100, 255 };
    unsigned long sum = 0;
    fill();
    for (unsigned k = 0; k < sizeof ns / sizeof *ns; k++) {
        int n = ns[k];
        for (int i = 0; i < 300; i++) { uc[i] = 77; sc8[i] = 77; hc[i] = 7777; sc[i] = 7777; }
        k_avgu8(uc + 1, ua + 2, ub + 3, n);          sum += cs8(uc, 300);
        k_avgs8(sc8 + 1, sa8 + 2, sb8 + 3, n);       sum += cs8((unsigned char *)sc8, 300);
        k_avgu16(hc + 1, ha + 2, hb + 3, n);         sum += cs16(hc, 300);
        k_avgs16(sc + 1, sa + 2, sb + 3, n);         sum += cs16((unsigned short *)sc, 300);
        k_mulh(sc + 1, sa + 2, sb + 3, n);           sum += cs16((unsigned short *)sc, 300);
        k_mulhu(hc + 1, ha + 2, hb + 3, n);          sum += cs16(hc, 300);
        k_mulhk(sc + 1, sa + 2, n);                  sum += cs16((unsigned short *)sc, 300);
        k_mulhkn(sc + 1, sa + 3, n);                 sum += cs16((unsigned short *)sc, 300);
        k_mulhuk(hc + 1, ha + 2, n);                 sum += cs16(hc, 300);
        k_mulhuk2(hc + 1, ha + 3, n);                sum += cs16(hc, 300);
        k_q15(sc + 1, sa + 2, sb + 3, n);            sum += cs16((unsigned short *)sc, 300);
    }
    /* the one product that saturates: -32768 x -32768 */
    sa[0] = -32768; sb[0] = -32768; sa[1] = -32768; sb[1] = 32767; sa[2] = 32767; sb[2] = 32767;
    k_q15(sc, sa, sb, 3);
    sum += (unsigned long)(sc[0] * 1000 + sc[1] * 10 + sc[2]);
    return (int)(sum % 100003);
}
