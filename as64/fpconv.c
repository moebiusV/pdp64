/* fpconv.c: the floating-point constants f16(x), f32(x) and f64(x) of the assembler (included by asmp.c; plain C, nothing else).
   x is a decimal literal: [-] digits [. digits] [e [+|-] digits], or an integer in the number syntax (0x, 0o, 0b).  The result is the bit pattern of x rounded to nearest, ties to even,
   to binary16, binary32 or binary64, zero-extended.  A value that rounds to infinity, a non-zero literal that rounds to zero, and anything that is not a literal are refused.
   Denormals are accepted.  inf and nan (with an optional sign) are keywords of this form only: inf is the exponent all ones and a zero fraction, nan the quiet NaN (the top fraction bit set); other NaNs are written as bits.

   How each width is rounded exactly once, from the decimal and not from a rounding of it:
   - binary64: strtod.  glibc's strtod is correctly rounded (it works in exact multi-precision arithmetic).
   - binary32: strtof, which glibc also rounds once, from the decimal (rounding to a double first would be a double rounding: 1.00000017881393432617187499 is just below the middle of
     0x3f800001 and 0x3f800002, a double cannot tell it from the middle itself, and the tie would go to the even 0x3f800002).
   - binary16: strtod gives the double d nearest the decimal D.  No middle of two binary16 numbers lies between D and d (the middles are doubles), so rounding d gives the right answer, except when
     d is itself a middle: then D is compared with d in exact integer arithmetic (a small bignum), and the tie goes to even only when D equals d.
   An integer in the number syntax is turned into its decimal digits first, so it takes the same road. */
#include <errno.h>
#include <math.h>		/* isinf only: a macro, no library */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* a bignum, little endian base 2^32, for the one exact comparison of the binary16 road */
struct fp_big { uint32_t *w; int n, cap; };
static void fpb_init(struct fp_big *b) { b->cap = 8; b->n = 0; b->w = calloc(b->cap, 4); }
static void fpb_muladd(struct fp_big *b, uint32_t f, uint32_t add)
{
	uint64_t c = add;
	for (int i = 0; i < b->n; i++) { c += (uint64_t)b->w[i] * f; b->w[i] = (uint32_t)c; c >>= 32; }
	if (c) {
		if (b->n == b->cap) { b->cap *= 2; b->w = realloc(b->w, b->cap * 4); }
		b->w[b->n++] = (uint32_t)c;
	}
}
static int fpb_cmp(const struct fp_big *a, const struct fp_big *b)
{
	if (a->n != b->n) return a->n < b->n ? -1 : 1;
	for (int i = a->n - 1; i >= 0; i--)
		if (a->w[i] != b->w[i]) return a->w[i] < b->w[i] ? -1 : 1;
	return 0;
}

/* The sign of (m * 10^e10) - (k * 2^j), m a string of decimal digits and k a 64-bit integer: both sides are multiplied up to integers. */
static int fp_cmp_exact(const char *m, int nm, long e10, uint64_t k, int j)
{
	struct fp_big L, R;
	fpb_init(&L); fpb_init(&R);
	for (int i = 0; i < nm; i++) fpb_muladd(&L, 10, (uint32_t)(m[i] - '0'));
	fpb_muladd(&R, 1, (uint32_t)k);			/* k is below 2^13 here (a middle of binary16) */
	for (long i = 0; i < (e10 > 0 ? e10 : 0); i++) fpb_muladd(&L, 10, 0);
	for (long i = 0; i < (e10 < 0 ? -e10 : 0); i++) fpb_muladd(&R, 10, 0);
	for (int i = 0; i < (j < 0 ? -j : 0); i++) fpb_muladd(&L, 2, 0);
	for (int i = 0; i < (j > 0 ? j : 0); i++) fpb_muladd(&R, 2, 0);
	/* a number with no limbs is zero: normalise both so that the comparison of lengths is right */
	while (L.n && !L.w[L.n - 1]) L.n--;
	while (R.n && !R.w[R.n - 1]) R.n--;
	int c = fpb_cmp(&L, &R);
	free(L.w); free(R.w);
	return c;
}

/* an integer literal (decimal, 0x, 0o, 0b; lower case) in s[0..n): its value, or the message */
static const char *fp_uint(const char *s, size_t n, uint64_t *out)
{
	int base = 10;
	size_t k = 0;
	uint64_t v = 0;
	if (!n) return "an integer is wanted here";
	if (n > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'o' || s[1] == 'b')) { base = s[1] == 'x' ? 16 : s[1] == 'o' ? 8 : 2; k = 2; }
	else if (n > 1 && s[0] == '0') return "a number with a leading zero: write 0o for octal, or the decimal without the zero";
	for (; k < n; k++) {
		int d = s[k] >= '0' && s[k] <= '9' ? s[k] - '0' : s[k] >= 'a' && s[k] <= 'f' ? s[k] - 'a' + 10 : 99;
		if (d >= base) return "an integer literal is wanted (decimal, or with the prefix 0x, 0o or 0b)";
		if (v > (UINT64_MAX - d) / base) return "an integer too large: it must be below 2^64";
		v = v * base + d;
	}
	*out = v;
	return NULL;
}

/* the literal: sign, the digits of the integer part and of the fraction, the exponent.  Returns NULL, or the message that says what is wrong. */
struct fp_lit { uint64_t payload; int special; /* 1 inf, 2 nan, 3 nan(p) */ int neg; char *digits; int nd; long e10; int zero; char *dec; };	/* dec: the whole literal as a C decimal string for strtod; digits, nd, e10: the value is digits * 10^e10 */

static const char *fp_scan(const char *s, size_t n, struct fp_lit *L)
{
	size_t i = 0;
	memset(L, 0, sizeof *L);
	while (n > 0 && (*s == ' ' || *s == '\t')) { s++; n--; }
	while (n > 0 && (s[n - 1] == ' ' || s[n - 1] == '\t')) n--;
	if (!n) return "empty parentheses: a floating-point constant is a literal number, as f64(1.5)";
	if (s[0] == '-') { L->neg = 1; i = 1; }
	if (i >= n) return "a floating-point constant is a decimal literal (f64(1.5), f64(-2), f64(1e3), f64(inf)): a sign alone is not one";
	if (n - i == 3 && !memcmp(s + i, "inf", 3)) { L->special = 1; return NULL; }
	if (n - i == 3 && !memcmp(s + i, "nan", 3)) { L->special = 2; return NULL; }
	if (n - i > 4 && !memcmp(s + i, "nan(", 4)) {
		if (s[n - 1] != ')') return "nan( is closed by a parenthesis: nan(1)";
		const char *m = fp_uint(s + i + 4, n - i - 5, &L->payload);
		if (m) return m;
		L->special = 3;
		return NULL;
	}
	if (n - i == 4 && !memcmp(s + i, "nan(", 4)) return "nan( is closed by a parenthesis, with the fraction between: nan(1)";
	{
		char c = s[i];
		if (!((c >= '0' && c <= '9') || c == '.')) return "a floating-point constant is a literal (f64(1.5), or inf or nan), not a symbol or an expression: a name has no value when the line is read";
	}
	if (s[i] == '.') return "a number does not begin with a point: write 0.5 for .5";
	/* an integer in the number syntax: 0x.. 0o.. 0b.. (lower case, as everywhere) */
	if (s[i] == '0' && i + 1 < n && (s[i + 1] == 'x' || s[i + 1] == 'o' || s[i + 1] == 'b')) {
		int base = s[i + 1] == 'x' ? 16 : s[i + 1] == 'o' ? 8 : 2;
		uint64_t v = 0;
		size_t k = i + 2;
		if (k >= n) return "an integer with a prefix and no digits";
		for (; k < n; k++) {
			int d = s[k] >= '0' && s[k] <= '9' ? s[k] - '0' : s[k] >= 'a' && s[k] <= 'f' ? s[k] - 'a' + 10 : 99;
			if (d >= base) return base == 16 && (s[k] == '.' || s[k] == 'p') ? "a hexadecimal floating-point literal is not accepted: write the decimal (f64(12.0)), or the bits (0x4028000000000000.f64)" : "not a number of that base";
			if (v > (UINT64_MAX - d) / base) return "an integer too large: a floating-point constant takes an integer below 2^64";
			v = v * base + d;
		}
		L->dec = malloc(40);
		snprintf(L->dec, 40, "%s%llu", L->neg ? "-" : "", (unsigned long long)v);
		L->digits = malloc(24); L->nd = snprintf(L->digits, 24, "%llu", (unsigned long long)v); L->e10 = 0;
		L->zero = v == 0;
		return NULL;
	}
	{
		size_t a = i, ib, fb = 0, fe = 0;
		long ex = 0;
		while (i < n && s[i] >= '0' && s[i] <= '9') i++;
		ib = i - a;
		if (!ib) return "not a decimal literal";
		if (ib > 1 && s[a] == '0') return "a number with a leading zero: write 0o for octal, or the decimal without the zero";
		if (i < n && s[i] == '.') {
			i++; fb = i;
			while (i < n && s[i] >= '0' && s[i] <= '9') i++;
			fe = i;
			if (fe == fb) return "a decimal point needs digits after it: write 1.0 for 1.";
		}
		if (i < n && (s[i] == 'e' || s[i] == 'E')) {
			if (s[i] == 'E') return "the exponent is written with a lower case e (1e3)";
			size_t q = i + 1;
			int eneg = 0;
			if (q < n && (s[q] == '+' || s[q] == '-')) { eneg = s[q] == '-'; q++; }
			if (q >= n || s[q] < '0' || s[q] > '9') return "an exponent needs digits (1e3, 1.5e-3)";
			while (q < n && s[q] >= '0' && s[q] <= '9') { if (ex < 100000) ex = ex * 10 + (s[q] - '0'); q++; }
			if (eneg) ex = -ex;
			i = q;
		}
		if (i < n) return "not a decimal literal: a floating-point constant is digits, an optional point and digits, an optional exponent (1.5, 1e3, 1.5e-3, 3)";
		L->digits = malloc(n + 1);
		memcpy(L->digits, s + a, ib); L->nd = (int)ib;
		if (fb) { memcpy(L->digits + L->nd, s + fb, fe - fb); L->nd += (int)(fe - fb); }
		L->digits[L->nd] = 0;
		L->e10 = ex - (long)(fe - fb);
		L->dec = malloc(n + 1);
		memcpy(L->dec, s, n); L->dec[n] = 0;
		L->zero = 1;
		for (int d = 0; d < L->nd; d++) if (L->digits[d] != '0') L->zero = 0;
		/* strip the leading zeros of the digits (the bignum has no use for them) */
		{
			int z = 0;
			while (z < L->nd - 1 && L->digits[z] == '0') z++;
			if (z) { memmove(L->digits, L->digits + z, L->nd - z + 1); L->nd -= z; }
		}
		return NULL;
	}
}

static void fp_free(struct fp_lit *L) { free(L->digits); free(L->dec); }

/* binary16 of the (finite, non-negative) double d for the decimal L; -1 on overflow, -2 on underflow of a non-zero literal */
static long fp_half(const struct fp_lit *L, double d)
{
	if (d == 0) return L->zero ? 0 : -2;
	if (d < 0x1p-25) return -2;				/* below the middle of 0 and the smallest denormal: monotonic, so D is below it too */
	if (d >= 0x1p16) return -1;
	uint64_t b;
	memcpy(&b, &d, 8);
	int e = (int)((b >> 52) & 0x7ff) - 1023;		/* d is a normal double here: d = mant * 2^(e - 52) */
	uint64_t mant = (b & (((uint64_t)1 << 52) - 1)) | ((uint64_t)1 << 52);
	int qe = (e < -14 ? -14 : e) - 10;			/* the weight of the last bit of the result */
	int sh = qe - (e - 52);					/* the bits of mant below it: 42, or more for a denormal result */
	long q = (long)(mant >> sh);
	uint64_t rem = mant & (((uint64_t)1 << sh) - 1), half = (uint64_t)1 << (sh - 1);
	if (rem > half) q++;
	else if (rem == half) {					/* d is a middle: only the decimal itself says on which side it is */
		int c = fp_cmp_exact(L->digits, L->nd, L->e10, (uint64_t)(2 * q + 1), qe - 1);
		if (c > 0 || (c == 0 && (q & 1))) q++;
	}
	long code = e < -14 ? q : (((long)e + 15) << 10) + (q - 1024);
	if (code >= 0x7c00) return -1;
	if (code == 0) return -2;
	return code;
}

/* The constant of a literal in `lit` (the text between the parentheses) in a format of `width` bits (16, 32, 64).  Returns 0 and the bits in *bits, or -1 and a message in *why. */
static int fp_const(int width, const char *lit, size_t n, uint64_t *bits, const char **why)
{
	struct fp_lit L;
	const char *m = fp_scan(lit, n, &L);
	uint64_t sign;
	if (m) { *why = m; return -1; }
	sign = L.neg ? 1 : 0;
	int rc = 0;
	errno = 0;
	if (L.special) {					/* inf: exponent all ones, fraction 0; nan: the quiet NaN, the top fraction bit set */
		int eb = width == 64 ? 11 : width == 32 ? 8 : 5, fb = width - 1 - eb;
		uint64_t b = (((uint64_t)1 << eb) - 1) << fb;
		if (L.special == 2) b |= (uint64_t)1 << (fb - 1);
		if (L.special == 3) {				/* nan(p): the fraction field is p, the quiet bit among it */
			if (L.payload == 0) { *why = "nan(0) is the infinity: write inf"; fp_free(&L); return -1; }
			if (L.payload >> fb) { *why = fb == 52 ? "the payload does not fit the fraction of binary64 (52 bits)" : fb == 23 ? "the payload does not fit the fraction of binary32 (23 bits)" : "the payload does not fit the fraction of binary16 (10 bits)"; fp_free(&L); return -1; }
			b |= L.payload;
		}
		*bits = b | (sign << (width - 1));
	} else if (width == 64) {
		double d = strtod(L.dec, NULL);
		uint64_t b;
		if (isinf(d)) { *why = "the value is too large for binary64 (the largest is about 1.7976931348623157e308); write f64(inf) if infinity is meant"; rc = -1; }
		else if (d == 0 && !L.zero) { *why = "the value is too small for binary64: it rounds to zero (the smallest is 4.9406564584124654e-324)"; rc = -1; }
		else { memcpy(&b, &d, 8); *bits = b; }
	} else if (width == 32) {
		float f = strtof(L.dec, NULL);
		uint32_t b;
		if (isinf(f)) { *why = "the value is too large for binary32 (the largest is 3.4028235e38); write f32(inf) if infinity is meant"; rc = -1; }
		else if (f == 0 && !L.zero) { *why = "the value is too small for binary32: it rounds to zero (the smallest is 1e-45, written 1.4e-45)"; rc = -1; }
		else { memcpy(&b, &f, 4); *bits = b; }
	} else {
		double d = strtod(L.dec, NULL);
		long c = fp_half(&L, d < 0 ? -d : d);
		if (isinf(d) || c == -1) { *why = "the value is too large for binary16 (the largest is 65504); write f16(inf) if infinity is meant"; rc = -1; }
		else if (c == -2) { *why = "the value is too small for binary16: it rounds to zero (the smallest is about 6e-8)"; rc = -1; }
		else *bits = (uint64_t)c | (sign << 15);
	}
	fp_free(&L);
	return rc;
}
