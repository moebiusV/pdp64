/* ecmain.c -- the main of the elliptic-curve profile program of BearSSL: scalar multiplications on P-256 and Curve25519 (the 31-bit constant-time implementations); prints a checksum. */
#include "bearssl.h"
long write(int, const char *, long);
static unsigned long seed = 7;
static unsigned rnd(void) { seed = seed * 6364136223846793005UL + 1442695040888963407UL; return (unsigned)(seed >> 33); }
static void put(unsigned long v)
{
	char b[24], *p = b + 24;
	*--p = '\n';
	do { *--p = '0' + v % 10; v /= 10; } while (v);
	write(1, p, b + 24 - p);
}
static unsigned long fold(const unsigned char *p, int n) { unsigned long s = 0; while (n--) s = s * 131 + *p++; return s; }
int main(void)
{
	unsigned char k[32], pt[128]; unsigned long sum = 0; int i, r;
	for (r = 0; r < 3; r++) {
		size_t len;
		for (i = 0; i < 32; i++) k[i] = rnd();
		k[0] &= 0x7f;
		len = br_ec_p256_m31.mulgen(pt, k, 32, BR_EC_secp256r1);
		sum += fold(pt, len);
		br_ec_p256_m31.mul(pt, len, k, 32, BR_EC_secp256r1);
		sum += fold(pt, len);
		len = br_ec_c25519_m31.mulgen(pt, k, 32, BR_EC_curve25519);
		sum += fold(pt, len);
		br_ec_c25519_m31.mul(pt, len, k, 32, BR_EC_curve25519);
		sum += fold(pt, len);
	}
	put(sum);
	return 0;
}
