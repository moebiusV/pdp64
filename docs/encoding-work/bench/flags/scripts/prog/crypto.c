typedef unsigned long size_t;
typedef unsigned char u8; typedef unsigned int u32;
struct ctx { char b[8192]; };
void MD5Init(void *); void MD5Update(void *, const void *, size_t); void MD5Final(u8 *, void *);
void SHA1Init(void *); void SHA1Update(void *, const void *, unsigned); void SHA1Final(u8 *, void *);
void SHA256Init(void *); void SHA256Update(void *, const void *, size_t); void SHA256Final(u8 *, void *);
void SHA512Init(void *); void SHA512Update(void *, const void *, size_t); void SHA512Final(u8 *, void *);
void RMD160Init(void *); void RMD160Update(void *, const void *, u32); void RMD160Final(u8 *, void *);
void blf_key(void *, const u8 *, unsigned short); void blf_ecb_encrypt(void *, u8 *, u32);
void poly1305_init(void *, const u8 *); void poly1305_update(void *, const u8 *, size_t); void poly1305_finish(void *, u8 *);
static u8 buf[65536];
static u8 out[64];
static unsigned sum(const u8 *p, int n) { unsigned s = 0; while (n--) s = s * 31 + *p++; return s; }
int test(void)
{
	static struct ctx c;
	unsigned long i, t = 0;
	for (i = 0; i < sizeof buf; i++) buf[i] = (u8)(i * 7 + (i >> 8));
	MD5Init(&c); MD5Update(&c, buf, sizeof buf); MD5Final(out, &c); t += sum(out, 16);
	SHA1Init(&c); SHA1Update(&c, buf, sizeof buf); SHA1Final(out, &c); t += sum(out, 20);
	SHA256Init(&c); SHA256Update(&c, buf, sizeof buf); SHA256Final(out, &c); t += sum(out, 32);
	SHA512Init(&c); SHA512Update(&c, buf, sizeof buf); SHA512Final(out, &c); t += sum(out, 64);
	RMD160Init(&c); RMD160Update(&c, buf, sizeof buf); RMD160Final(out, &c); t += sum(out, 20);
	blf_key(&c, buf, 16); blf_ecb_encrypt(&c, buf, 32768); t += sum(buf, 4096);
	poly1305_init(&c, buf + 100); poly1305_update(&c, buf, 30000); poly1305_finish(&c, out); t += sum(out, 16);
	return (int)(t & 0x7fffffff);
}
