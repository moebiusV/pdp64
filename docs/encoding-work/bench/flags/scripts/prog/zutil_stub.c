typedef unsigned long size_t;
void *calloc(size_t, size_t); void free(void *);
const char * const z_errmsg[10] = { "need dictionary", "stream end", "", "file error", "stream error", "data error", "insufficient memory", "buffer error", "incompatible version", "" };
const char *zlibVersion(void) { return "1.x"; }
void *zcalloc(void *o, unsigned n, unsigned s) { return calloc(n, s); }
void zcfree(void *o, void *p) { free(p); }
