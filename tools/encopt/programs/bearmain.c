/* bearmain.c -- the main of the BearSSL profile programs: hashes (MD5, SHA-1, SHA-256, SHA-512), HMAC-SHA256, AES-128 CBC and CTR (constant-time), ChaCha20 over pseudo-random buffers; prints a checksum.
   The program is the hashes and the symmetric ciphers: the standard `bs_hash` and `bs_sym` of the earlier study were of this kind, the elliptic curves are not here. */
#include "bearssl.h"
long write(int, const char *, long);
#define N 8192
static unsigned char buf[N], out[N], tmp[64];
static unsigned long seed = 99;
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
	unsigned long sum = 0; int i, round;
	for (i = 0; i < N; i++) buf[i] = rnd();
#ifdef BS_HASH
	for (round = 0; round < 6; round++) {
		br_md5_context m5; br_sha1_context s1; br_sha256_context s256; br_sha512_context s512; br_hmac_key_context hk; br_hmac_context hc;
		br_md5_init(&m5); br_md5_update(&m5, buf, N); br_md5_out(&m5, tmp); sum += fold(tmp, 16);
		br_sha1_init(&s1); br_sha1_update(&s1, buf, N); br_sha1_out(&s1, tmp); sum += fold(tmp, 20);
		br_sha256_init(&s256); br_sha256_update(&s256, buf, N); br_sha256_out(&s256, tmp); sum += fold(tmp, 32);
		br_sha512_init(&s512); br_sha512_update(&s512, buf, N); br_sha512_out(&s512, tmp); sum += fold(tmp, 64);
		br_hmac_key_init(&hk, &br_sha256_vtable, buf, 32);
		br_hmac_init(&hc, &hk, 0); br_hmac_update(&hc, buf + 64, N - 64); br_hmac_out(&hc, tmp); sum += fold(tmp, 32);
		buf[round] ^= 0x5a;
	}
#else
	for (round = 0; round < 4; round++) {
		br_aes_ct_cbcenc_keys ce; br_aes_ct_cbcdec_keys cd; br_aes_ct_ctr_keys cr; unsigned char iv[16], iv2[16]; int j;
		for (j = 0; j < 16; j++) iv[j] = iv2[j] = j * 7 + round;
		br_aes_ct_cbcenc_init(&ce, buf, 16);
		for (j = 0; j < N; j++) out[j] = buf[j];
		br_aes_ct_cbcenc_run(&ce, iv, out, N); sum += fold(out, N);
		br_aes_ct_cbcdec_init(&cd, buf, 16);
		br_aes_ct_cbcdec_run(&cd, iv2, out, N);
		for (j = 0; j < N; j++) if (out[j] != buf[j]) return 3;
		br_aes_ct_ctr_init(&cr, buf, 16);
		br_aes_ct_ctr_run(&cr, iv, round, out, N); sum += fold(out, N);
		br_chacha20_ct_run(buf, iv, round, out, N); sum += fold(out, N);
	}
#endif
	put(sum);
	return 0;
}
