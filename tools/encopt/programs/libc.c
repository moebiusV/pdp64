/* libc.c -- the stand-in C library of the profile programs: a bump allocator and the string functions they need (memcpy, memmove and memset are the block instructions of profile.py's crt).
   Written for the profile of encopt; it is not a C library. */
typedef unsigned long size_t;
static char heap[8 << 20];
static size_t hp;
void *malloc(size_t n) { void *p; n = (n + 15) & ~15UL; if (hp + n > sizeof heap) return 0; p = heap + hp; hp += n; return p; }
void *calloc(size_t a, size_t b) { return malloc(a * b); }     /* the heap is zero and never reused */
void free(void *p) { (void)p; }
int memcmp(const void *a, const void *b, size_t n)
{
	const unsigned char *x = a, *y = b;
	while (n--) { if (*x != *y) return *x - *y; x++; y++; }
	return 0;
}
size_t strlen(const char *s) { const char *p = s; while (*p) p++; return p - s; }
int strcmp(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return (unsigned char)*a - (unsigned char)*b; }
void abort(void) { for (;;) ; }
