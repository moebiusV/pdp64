/* Syscall-like handlers written for the study of hole 6: the kinds of function a small kernel runs between the entry and the return.
   Freestanding C, no library; each takes the arguments in the order the ABI gives (r0..r5) and returns a long. */
typedef unsigned char u8; typedef unsigned short u16; typedef unsigned int u32; typedef unsigned long u64;

/* the user's address space is modelled as ordinary memory; a bound check stands in for the check of the user range */
#define USER_LO 0x1000UL
#define USER_HI 0x7fffffffffUL
static int user_ok(const void *p, u64 n) { u64 a = (u64)p; return a >= USER_LO && n <= USER_HI && a + n <= USER_HI; }

long sys_null(void) { return 0; }

long sys_getpid(long *proc) { return proc[3]; }

/* copy-in: bytes, with the range check; returns the count or -14 */
long copyin_bytes(void *dst, const void *usrc, u64 n)
{
	u8 *d = dst; const u8 *s = usrc;
	if (!user_ok(usrc, n)) return -14;
	for (u64 i = 0; i < n; i++) d[i] = s[i];
	return n;
}
/* copy-out in words: the length is a multiple of 8 */
long copyout_words(void *udst, const void *src, u64 n)
{
	u64 *d = udst; const u64 *s = src;
	if (!user_ok(udst, n) || (n & 7)) return -14;
	for (u64 i = 0; i < n / 8; i++) d[i] = s[i];
	return n;
}
/* a descriptor-table lookup with a bounds check and a reference count */
struct file { long ref; long off; long flags; long vnode; };
struct file *fdtab[64];
long sys_dup(long fd)
{
	if ((u64)fd >= 64) return -9;
	struct file *f = fdtab[fd];
	if (!f) return -9;
	f->ref++;
	return f->vnode;
}
/* a hash lookup in an open-addressed table of 256 slots */
struct ent { u64 key; u64 val; };
struct ent htab[256];
long hash_lookup(u64 key)
{
	u64 h = key * 0x9E3779B97F4A7C15UL;
	u32 i = (u32)(h >> 56);
	for (int n = 0; n < 256; n++, i = (i + 1) & 255) {
		if (htab[i].key == key) return htab[i].val;
		if (htab[i].key == 0) return -2;
	}
	return -2;
}
/* the internet checksum of a buffer */
long checksum(const u8 *p, u64 n)
{
	u64 s = 0;
	while (n > 1) { s += (u64)p[0] | (u64)p[1] << 8; p += 2; n -= 2; }
	if (n) s += p[0];
	while (s >> 16) s = (s & 0xffff) + (s >> 16);
	return (~s) & 0xffff;
}
/* bitwise CRC-32 */
long crc32(const u8 *p, u64 n)
{
	u32 c = 0xffffffffU;
	for (u64 i = 0; i < n; i++) {
		c ^= p[i];
		for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320U & -(c & 1));
	}
	return ~c;
}
/* a small crypto routine: ChaCha20 quarter rounds, ten double rounds over a 16-word state, the result is the sum of the words */
#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
#define QR(a, b, c, d) a += b; d ^= a; d = ROTL(d, 16); c += d; b ^= c; b = ROTL(b, 12); a += b; d ^= a; d = ROTL(d, 8); c += d; b ^= c; b = ROTL(b, 7);
long chacha_block(u32 *st)
{
	u32 x[16];
	for (int i = 0; i < 16; i++) x[i] = st[i];
	for (int i = 0; i < 10; i++) {
		QR(x[0], x[4], x[8], x[12]) QR(x[1], x[5], x[9], x[13]) QR(x[2], x[6], x[10], x[14]) QR(x[3], x[7], x[11], x[15])
		QR(x[0], x[5], x[10], x[15]) QR(x[1], x[6], x[11], x[12]) QR(x[2], x[7], x[8], x[13]) QR(x[3], x[4], x[9], x[14])
	}
	u32 s = 0;
	for (int i = 0; i < 16; i++) s += x[i] + st[i];
	return s;
}
/* a system-call dispatcher: a switch over the number that calls the handlers above (the callees are in the same file) */
long dispatch(long n, long a, long b, long c)
{
	switch (n) {
	case 0: return sys_null();
	case 1: return sys_getpid((long *)a);
	case 2: return sys_dup(a);
	case 3: return hash_lookup((u64)a);
	case 4: return checksum((const u8 *)a, (u64)b);
	case 5: return copyin_bytes((void *)a, (const void *)b, (u64)c);
	default: return -38;
	}
}
