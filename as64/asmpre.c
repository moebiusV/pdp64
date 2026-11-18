/* asmpre.c: the macro layer of as64, included by as64.c.  It runs on the source text before the generated parser sees it, as a C
   preprocessor does, and what it writes is ordinary assembly source that spec/pdp64-asm.hbnf describes.  It knows four directives,
   all at the start of a line:

       .macro NAME [p1[, p2 ...]]  ...  .endm      a macro of positional parameters, used by writing NAME and its arguments as a statement
       .rept N  ...  .endr                         N copies of the lines between (N a number: decimal, 0x, 0b, 0o)

   In a macro body \p is the argument for the parameter p (empty if the call gave fewer), and \@ is a number that is new for each
   expansion, to make labels of one's own.  Macros may use macros and .rept, to a depth of 32.  `.if`, `.else` and `.endif` are not
   here: the assembler does them in its passes, where the symbols are.  A line of the output keeps the number of the source line it
   came from (pre_map), so an error in an expansion names the line of the call.  Not done, on purpose: string processing,
   default arguments, local label generation beyond \@ (the macro engines of MACRO-10 and MASM).

   The layer also handles the check instructions of errata 152, which the encoding now has (errata 159):

       ct<cc> rs, rb | #imm       trap if rs compared with the bound satisfies the condition (the conditions of cb<cc>; cthis = ctcc, ctlo = ctcs)
       cteq rs, ctne rs           trap if rs is zero, if it is not zero (the trap-if-zero)
       chk2 rs, rlo, rhi          trap unless rlo <= rs < rhi, signed
       .chk KIND, "file", LINE    the place of the next check instruction, for the table (KIND 1 bounds, 2 null, 3 range, 4 assertion)

   The instruction is written as it is (the aliases by their names), with a label, and a record of the table of check sites (`.bugrec`, in the section
   __bug_table) names the label, the file and line and the kind in bits 5 to 7 of the flags.  Without a `.chk` the record has kind 0, the source file and the
   line of the assembly.  (Before the encoding had them, the layer wrote a compare-and-branch over a `bpt`: errata 152.) */
#include <ctype.h>

static int pre_errors;

struct pmacro { char *name; int np, nb; char **par, **body; int *bline; };
static struct pmacro *pmacs;
static int npmacs;

struct pbuf { char *p; size_t n, cap; };

static void pre_err(int line, const char *fmt, ...)
{
	va_list ap;
	fprintf(stderr, "%s:%d: ", srcname, line);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
	pre_errors++;
}

static char *pdup(const char *s, size_t n)
{
	char *r = malloc(n + 1);
	memcpy(r, s, n);
	r[n] = 0;
	return r;
}

static const char *psp(const char *s) { while (*s == ' ' || *s == '\t') s++; return s; }
static int pidc(int c) { return isalnum((unsigned char)c) || c == '_' || c == '.' || c == '$' || (unsigned char)c >= 0x80; }

/* the directive d (without the dot) at the start of the line, followed by a space, the end or a comment: a pointer past it, else NULL */
static const char *pdir(const char *line, const char *d)
{
	const char *t = psp(line);
	size_t n = strlen(d);
	if (t[0] != '.' || strncmp(t + 1, d, n)) return NULL;
	t += 1 + n;
	return (*t == 0 || *t == ' ' || *t == '\t' || *t == ';' || (t[0] == '/' && t[1] == '/')) ? t : NULL;
}

static void pout(struct pbuf *o, const char *s, int srcline)
{
	size_t n = strlen(s);
	if (o->n + n + 2 > o->cap) { o->cap = (o->cap + n + 2) * 2; o->p = realloc(o->p, o->cap); }
	memcpy(o->p + o->n, s, n);
	o->p[o->n + n] = '\n';
	o->n += n + 1;
	if (pre_n % 1024 == 0) pre_map = realloc(pre_map, (pre_n + 1024) * sizeof *pre_map);
	pre_map[pre_n++] = srcline;
}

/* the arguments of a call: the text after the macro's name, cut at a comment outside quotes, split at the commas that are not inside quotes or brackets */
static int pargs(const char *s, char ***out)
{
	int n = 0, depth = 0, q = 0;
	const char *a = psp(s), *p;
	char **v = NULL;
	if (*a == 0 || *a == ';' || (a[0] == '/' && a[1] == '/')) { *out = NULL; return 0; }
	for (p = a;; p++) {
		int end = *p == 0 || (!q && (*p == ';' || (p[0] == '/' && p[1] == '/')));
		if (!end && q) { if (*p == '\\' && p[1]) p++; else if (*p == q) q = 0; continue; }
		if (!end && (*p == '"' || *p == '\'')) { q = *p; continue; }
		if (!end && (*p == '(' || *p == '[')) depth++;
		if (!end && (*p == ')' || *p == ']')) depth--;
		if (end || (*p == ',' && depth == 0)) {
			const char *b = psp(a), *e = p;
			while (e > b && (e[-1] == ' ' || e[-1] == '\t')) e--;
			v = realloc(v, (n + 1) * sizeof *v);
			v[n++] = pdup(b, (size_t)(e - b));
			if (end) break;
			a = p + 1;
		}
	}
	*out = v;
	return n;
}

static void pexpand(char **ls, int *ln, int n, int depth, struct pbuf *o, int *uniq);

/* ---- the check instructions: the opposite compare-and-branch of each condition ---- */
static const struct { const char *ct, *canon; } pct[] = {
	{ "ctcc", "ctcc" }, { "ctcs", "ctcs" }, { "cthis", "ctcc" }, { "ctlo", "ctcs" }, { "cthi", "cthi" }, { "ctlos", "ctlos" },
	{ "cteq", "cteq" }, { "ctne", "ctne" }, { "ctge", "ctge" }, { "ctlt", "ctlt" }, { "ctgt", "ctgt" }, { "ctle", "ctle" },
	{ "ctpl", "ctpl" }, { "ctmi", "ctmi" }, { "ctvc", "ctvc" }, { "ctvs", "ctvs" },
};
static struct { int have, kind, line; char *file; } pchk;			/* the .chk that waits for its instruction */
static char **pfiles; static int npfiles, pchkn;				/* the file names that have a string in this object, and the count of checks */

/* the check mnemonic at w (length n): its index in pct, 100 for chk2, else -1 */
static int pcheck_mn(const char *w, size_t n)
{
	if (n == 4 && !strncmp(w, "chk2", 4)) return 100;
	if (n < 4 || n > 5 || w[0] != 'c' || w[1] != 't') return -1;
	for (size_t i = 0; i < sizeof pct / sizeof *pct; i++)
		if (strlen(pct[i].ct) == n && !strncmp(pct[i].ct, w, n)) return (int)i;
	return -1;
}

/* does the text hold a check instruction or a .chk?  (so that pre_expand does not copy a text that has none) */
static int pre_has_check(const char *text)
{
	for (const char *l = text; l && *l; l = strchr(l, '\n') ? strchr(l, '\n') + 1 : NULL) {
		const char *w = psp(l);
		for (;;) {
			const char *e = w;
			while (pidc(*e)) e++;
			if (e > w && *e == ':') { w = psp(e + 1); continue; }
			break;
		}
		const char *e = w;
		while (pidc(*e)) e++;
		if (pcheck_mn(w, (size_t)(e - w)) >= 0) return 1;
		if (pdir(w, "chk")) return 1;
	}
	return 0;
}

/* a string of this object that holds the name of a file: its label, made on first use, in .data */
static void pfilelab(const char *name, struct pbuf *o, int srcline, char *lab, size_t labn)
{
	int k;
	for (k = 0; k < npfiles; k++) if (!strcmp(pfiles[k], name)) break;
	snprintf(lab, labn, ".Lchkf%d", k);
	if (k < npfiles) return;
	pfiles = realloc(pfiles, (npfiles + 1) * sizeof *pfiles);
	pfiles[npfiles++] = pdup(name, strlen(name));
	char esc[1024]; size_t n = 0;
	for (const char *s = name; *s && n + 3 < sizeof esc; s++) { if (*s == '"' || *s == '\\') esc[n++] = '\\'; esc[n++] = *s; }
	esc[n] = 0;
	char b[1200];
	snprintf(b, sizeof b, "\t.data"); pout(o, b, srcline);
	snprintf(b, sizeof b, "%s:", lab); pout(o, b, srcline);
	snprintf(b, sizeof b, "\t.byte \"%s\", 0", esc); pout(o, b, srcline);
	snprintf(b, sizeof b, "\t.text"); pout(o, b, srcline);
}

/* expand the check instruction at w (kind: the index of pct, or 100 for chk2), operands from e */
static void pcheck(const char *w, const char *e, int mn, int srcline, struct pbuf *o)
{
	char **av; int na = pargs(e, &av);
	char b[1400], file[1024]; int line = srcline, kind = 0, id = ++pchkn;
	if (mn == 100 ? na != 3 : (mn == 6 || mn == 7) ? (na != 1 && na != 2) : na != 2) {
		pre_err(srcline, "%.*s takes %s", (int)(e - w), w, mn == 100 ? "rs, rlo, rhi" : (mn == 6 || mn == 7) ? "rs, or rs and a bound" : "rs and a bound");
		for (int k = 0; k < na; k++) free(av[k]);
		free(av);
		return;
	}
	if (pchk.have) { kind = pchk.kind; line = pchk.line; snprintf(file, sizeof file, "%s", pchk.file); free(pchk.file); pchk.file = NULL; pchk.have = 0; }
	else snprintf(file, sizeof file, "%s", srcname);
	char lab[64]; pfilelab(file, o, srcline, lab, sizeof lab);
	{
		char ops[1000]; size_t n = 0;
		ops[0] = 0;
		for (int k = 0; k < na; k++) n += (size_t)snprintf(ops + n, sizeof ops - n, "%s%s", k ? ", " : "", av[k]);
		snprintf(b, sizeof b, ".Lbug%d:\t%s %s", id, mn == 100 ? "chk2" : pct[mn].canon, ops); pout(o, b, srcline);
	}
	snprintf(b, sizeof b, "\t.bugrec .Lbug%d, %s, %d, %d", id, lab, line, kind << 5); pout(o, b, srcline);
	for (int k = 0; k < na; k++) free(av[k]);
	free(av);
}

/* `.chk KIND, "file", LINE` */
static void pchkdir(const char *r, int srcline)
{
	char **av; int na = pargs(r, &av);
	char *end;
	if (na != 3 || av[1][0] != '"' || strlen(av[1]) < 2) pre_err(srcline, ".chk KIND, \"file\", LINE");
	else {
		long k = strtol(av[0], &end, 0), ln = strtol(av[2], &end, 0);
		if (k < 0 || k > 7 || ln < 0 || ln > 65535) pre_err(srcline, ".chk: the kind is 0 to 7 and the line 0 to 65535");
		else {
			free(pchk.file);
			pchk.have = 1; pchk.kind = (int)k; pchk.line = (int)ln;
			pchk.file = pdup(av[1] + 1, strlen(av[1]) - 2);
		}
	}
	for (int k = 0; k < na; k++) free(av[k]);
	free(av);
}

/* one line of the source, or of an expansion: output it, or expand the macro it calls */
static void pline(const char *l, int srcline, int depth, struct pbuf *o, int *uniq)
{
	const char *t = psp(l), *w = t;
	for (;;) {					/* skip the labels that begin the line */
		const char *e = w;
		while (pidc(*e)) e++;
		if (e > w && *e == ':') { w = psp(e + 1); continue; }
		break;
	}
	{
		const char *cr = pdir(w, "chk");
		if (cr) {						/* `label: .chk ...` */
			if (w > t) { char *lab = pdup(t, (size_t)(w - t)); pout(o, lab, srcline); free(lab); }
			pchkdir(cr, srcline);
			return;
		}
	}
	const char *e = w;
	while (pidc(*e)) e++;
	if (e > w) {
		int cm = pcheck_mn(w, (size_t)(e - w));
		if (cm >= 0) {
			if (w > t) { char *lab = pdup(t, (size_t)(w - t)); pout(o, lab, srcline); free(lab); }		/* the labels first */
			pcheck(w, e, cm, srcline, o);
			return;
		}
		for (int m = 0; m < npmacs; m++) {
			if (strlen(pmacs[m].name) != (size_t)(e - w) || strncmp(pmacs[m].name, w, (size_t)(e - w))) continue;
			struct pmacro *mc = &pmacs[m];
			char **av, **bl;
			int na = pargs(e, &av), *bn;
			char buf[64];
			if (depth >= 32) { pre_err(srcline, "macros nested too deep (%s calls itself?)", mc->name); return; }
			if (w > t) { char *lab = pdup(t, (size_t)(w - t)); pout(o, lab, srcline); free(lab); }	/* the labels first, on a line of their own */
			bl = malloc((mc->nb + 1) * sizeof *bl);
			bn = malloc((mc->nb + 1) * sizeof *bn);
			(*uniq)++;
			for (int k = 0; k < mc->nb; k++) {
				const char *b = mc->body[k];
				struct pbuf s = { 0, 0, 0 };
				for (; *b; b++) {
					size_t add = 1; const char *ins = b;
					if (*b == '\\' && b[1] == '@') { snprintf(buf, sizeof buf, "%d", *uniq); ins = buf; add = strlen(buf); b++; }
					else if (*b == '\\' && pidc(b[1])) {
						const char *q = b + 1; while (pidc(*q)) q++;
						int hit = -1;
						for (int j = 0; j < mc->np; j++) if (strlen(mc->par[j]) == (size_t)(q - b - 1) && !strncmp(mc->par[j], b + 1, (size_t)(q - b - 1))) hit = j;
						if (hit >= 0) { ins = hit < na ? av[hit] : ""; add = strlen(ins); b = q - 1; }
					}
					if (s.n + add + 1 > s.cap) { s.cap = (s.cap + add + 1) * 2; s.p = realloc(s.p, s.cap); }
					memcpy(s.p + s.n, ins, add); s.n += add;
				}
				if (!s.p) s.p = pdup("", 0); else s.p[s.n] = 0;
				bl[k] = s.p; bn[k] = srcline;
			}
			pexpand(bl, bn, mc->nb, depth + 1, o, uniq);
			for (int k = 0; k < mc->nb; k++) free(bl[k]);
			for (int k = 0; k < na; k++) free(av[k]);
			free(av); free(bl); free(bn);
			return;
		}
	}
	pout(o, l, srcline);
}

/* find the end of a block that began with `open` (.macro or .rept) at line i: the index of its .endm or .endr, or -1 */
static int pend(char **ls, int n, int i, const char *open, const char *close)
{
	int d = 1;
	for (int k = i + 1; k < n; k++) {
		if (pdir(ls[k], open)) d++;
		else if (pdir(ls[k], close) && --d == 0) return k;
	}
	return -1;
}

static void pexpand(char **ls, int *ln, int n, int depth, struct pbuf *o, int *uniq)
{
	for (int i = 0; i < n; i++) {
		const char *r;
		if ((r = pdir(ls[i], "macro"))) {
			int e = pend(ls, n, i, "macro", "endm");
			const char *nm = psp(r), *q = nm;
			struct pmacro mc;
			while (pidc(*q)) q++;
			if (e < 0) { pre_err(ln[i], ".macro without .endm"); return; }
			if (q == nm) { pre_err(ln[i], ".macro needs a name"); i = e; continue; }
			memset(&mc, 0, sizeof mc);
			mc.name = pdup(nm, (size_t)(q - nm));
			{							/* the parameter names: after the name, separated by commas or spaces */
				const char *p = q;
				for (;;) {
					while (*p == ' ' || *p == '\t' || *p == ',') p++;
					if (!pidc(*p)) break;
					const char *s = p;
					while (pidc(*p)) p++;
					mc.par = realloc(mc.par, (mc.np + 1) * sizeof *mc.par);
					mc.par[mc.np++] = pdup(s, (size_t)(p - s));
				}
			}
			mc.nb = e - i - 1;
			mc.body = malloc((mc.nb + 1) * sizeof *mc.body);
			mc.bline = malloc((mc.nb + 1) * sizeof *mc.bline);
			for (int k = 0; k < mc.nb; k++) { mc.body[k] = pdup(ls[i + 1 + k], strlen(ls[i + 1 + k])); mc.bline[k] = ln[i + 1 + k]; }
			for (int m = 0; m < npmacs; m++) if (!strcmp(pmacs[m].name, mc.name)) { pmacs[m] = mc; goto defined; }
			pmacs = realloc(pmacs, (npmacs + 1) * sizeof *pmacs);
			pmacs[npmacs++] = mc;
defined:
			i = e;
		} else if ((r = pdir(ls[i], "rept"))) {
			int e = pend(ls, n, i, "rept", "endr");
			char *end;
			long long cnt = strtoll(psp(r), &end, 0);
			if (e < 0) { pre_err(ln[i], ".rept without .endr"); return; }
			end = (char *)psp(end);
			if (end == psp(r) || (*end && *end != ';' && !(end[0] == '/' && end[1] == '/')) || cnt < 0 || cnt > 1000000) {
				pre_err(ln[i], ".rept takes a number, 0 to 1000000");
				i = e;
				continue;
			}
			if (depth >= 32) { pre_err(ln[i], ".rept nested too deep"); return; }
			for (long long c = 0; c < cnt && pre_n < 20000000; c++)
				pexpand(ls + i + 1, ln + i + 1, e - i - 1, depth + 1, o, uniq);
			i = e;
		} else if ((r = pdir(ls[i], "chk"))) {
			pchkdir(r, ln[i]);
		} else if (pdir(ls[i], "endm")) {
			pre_err(ln[i], ".endm without .macro");
		} else if (pdir(ls[i], "endr")) {
			pre_err(ln[i], ".endr without .rept");
		} else {
			pline(ls[i], ln[i], depth, o, uniq);
		}
	}
}

/* The source text after the macro layer.  The text is returned as it is when it holds no .macro or .rept (the usual case). */
static char *pre_expand(char *text)
{
	if (!strstr(text, ".macro") && !strstr(text, ".rept") && !pre_has_check(text)) return text;
	char **ls = NULL; int *ln = NULL, n = 0, uniq = 0;
	struct pbuf o = { 0, 0, 0 };
	for (char *p = text;;) {
		char *e = strchr(p, '\n');
		ls = realloc(ls, (n + 1) * sizeof *ls);
		ln = realloc(ln, (n + 1) * sizeof *ln);
		ls[n] = pdup(p, e ? (size_t)(e - p) : strlen(p));
		ln[n] = n + 1;
		n++;
		if (!e) break;
		p = e + 1;
	}
	pexpand(ls, ln, n, 0, &o, &uniq);
	if (!o.p) o.p = pdup("", 0); else o.p[o.n] = 0;
	return o.p;
}
