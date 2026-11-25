long add_seq_cst(long *p) { return __atomic_fetch_add(p, 1, __ATOMIC_SEQ_CST); }
struct __attribute__((packed)) rec { char c; int n; };
int add_packed(struct rec *r) { return __atomic_fetch_add(&r->n, 1, __ATOMIC_SEQ_CST); }
