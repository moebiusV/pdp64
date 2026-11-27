/* mtrace.c: an LD_PRELOAD malloc tracer for the host (glibc, x86-64 LP64): writes a 24-byte record for every malloc, calloc, realloc, free,
 * memalign and posix_memalign to the file named by $MTRACE (opened lazily, appended), so that a program's allocation sizes and lifetimes can be
 * replayed under other size-class rules by trace.py.  record: u32 op (1 alloc, 2 free, 3 realloc), u32 pid, u64 size, u64 ptr (for realloc: the NEW ptr, size
 * the new size, and a second record op 2 for the old pointer comes first).  cc -O2 -shared -fPIC -o mtrace.so mtrace.c */
#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/syscall.h>
extern void *__libc_malloc(size_t), *__libc_calloc(size_t, size_t), *__libc_realloc(void *, size_t), *__libc_memalign(size_t, size_t);
extern void __libc_free(void *);
typedef struct { uint32_t op, pid; uint64_t size, ptr; } rec;
#define N 8192
static rec buf[N]; static int n; static volatile int lock; static int fd = -2; static pid_t fdpid;
static void flush(void) {
  pid_t p = getpid();
  if (fd == -2 || fdpid != p) {
    const char *f = getenv("MTRACE"); fd = f ? open(f, O_WRONLY | O_CREAT | O_APPEND, 0644) : -1; fdpid = p;
  }
  if (fd >= 0) { char *b = (char *)buf; size_t left = n * sizeof(rec); while (left) { ssize_t w = write(fd, b, left); if (w <= 0) break; b += w; left -= w; } }
  n = 0;
}
static void put(uint32_t op, uint64_t size, void *ptr) {
  while (__sync_lock_test_and_set(&lock, 1)) ;
  buf[n].op = op; buf[n].pid = getpid(); buf[n].size = size; buf[n].ptr = (uint64_t)ptr; if (++n == N) flush();
  __sync_lock_release(&lock);
}
__attribute__((destructor)) static void done(void) { while (__sync_lock_test_and_set(&lock, 1)) ; flush(); __sync_lock_release(&lock); }
void *malloc(size_t s) { void *p = __libc_malloc(s); if (p) put(1, s, p); return p; }
void *calloc(size_t a, size_t b) { void *p = __libc_calloc(a, b); if (p) put(1, a * b, p); return p; }
void free(void *p) { if (p) put(2, 0, p); __libc_free(p); }
void *realloc(void *o, size_t s) {
  void *p = __libc_realloc(o, s);
  if (p || s == 0) { if (o) put(2, 0, o); if (p) put(1, s, p); }
  return p;
}
void *memalign(size_t al, size_t s) { void *p = __libc_memalign(al, s); if (p) put(1, s, p); return p; }
int posix_memalign(void **r, size_t al, size_t s) { void *p = __libc_memalign(al, s); if (!p) return ENOMEM; *r = p; put(1, s, p); return 0; }
void *aligned_alloc(size_t al, size_t s) { return memalign(al, s); }
