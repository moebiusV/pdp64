#include <string.h>
#include "pdp64-asm-parser.c"
static int try(const char *what, const char *text, int want){
  asm_t l; char err[300]; size_t ln=0, col=0;
  /* the parser reads one line: a multi-line source is fed line by line, as as64 does */
  bool ok = 1; int n=0; char *buf=strdup(text), *q=buf;
  while (ok && *q) { char *e=strchr(q,'\n'); if(e)*e=0; ok = parse_text(q,&l,err,sizeof err,&ln,&col); n++; if(!e)break; q=e+1; }
  if(!ok) n--;
  printf("%s %-28s %s (%d lines)%s%s\n", ok==want?"ok  ":"BAD ", what, ok?"parsed":"rejected", n, ok?"":" : ", ok?"":err);
  return ok!=want;
}
int main(void){
  int bad=0;
  bad+=try("move load",        "movq 8(r5), r3\n", 1);
  bad+=try("alu reg,reg",      "add r1, r2\n", 1);
  bad+=try("label + branch",   "loop:\tbr loop\n", 1);
  bad+=try("immediate, comment","movq #-5, r3 ; five\n", 1);
  bad+=try("indexed",          "movq 4(r1)(r2*8), r0\n", 1);
  bad+=try("postinc / predec", "movq (sp)+, r0\nmovq r0, -(sp)\nmovq r0, (sp)-16\n", 1);
  bad+=try("pc and dp",        "movq tab(pc), r1\nmovq 16(dp), r2\n", 1);
  bad+=try("absolute",         "movq @0x1000, r1\n", 1);
  bad+=try("directives",       ".text\n.globl start\nstart: .quad 1, 2\n.byte \"hello\\n\", 'a', '\\n', 0x41, 0b101, 0o17, 0\n.comm buf, 64\n", 1);
  bad+=try(".encode",          ".encode 3\nmovq #5, r1\n.encode 0\n.encode\n", 1);
  bad+=try("numeric labels",   "1: sob r2, 1b\nbr 2f\n2: halt\n", 1);
  bad+=try("comment only",     "; nothing here\nclr r1 ; and a comment\n", 1);
  bad+=try("division",         "N = 100/7*2\nmovq #N/2, r1\n", 1);
  bad+=try("string escapes",   ".ascii \"a\\tb\\x41\\101\\0\"\n", 1);
  bad+=try("old strings gone", ".byte <hello>\n", 0);
  bad+=try("two per line gone","clr r1; inc r1 \n", 1);
  bad+=try("assignment",       "N = 4*8+1\n", 1);
  bad+=try("utf8 label",       "caf\xc3\xa9: ret\n", 1);
  bad+=try("cjk label and use","\xe3\x83\xab\xe3\x83\xbc\xe3\x83\x97: br \xe3\x83\xab\xe3\x83\xbc\xe3\x83\x97\n", 1);
  bad+=try("quoted name",      "\"odd name!\": ret\n", 1);
  bad+=try("utf8 string/char", ".ascii \"h\xc3\xa9llo\"\nmovq #'\xc3\xa9', r1 ; \xe2\x9c\x93\n", 1);
  bad+=try("\\u escapes",      ".ascii \"\\u00e9\\U0001F600\"\n", 1);
  bad+=try("invalid byte",     "caf\xff: ret\n", 0);
  bad+=try("truncated utf8",   ".ascii \"\xc3\"\n", 0);
  bad+=try("overlong utf8",    ".ascii \"\xc0\x80\"\n", 0);
  bad+=try("surrogate",        ".ascii \"\xed\xa0\x80\"\n", 0);
  bad+=try("bad utf8 comment", "ret ; \xff\n", 0);
  bad+=try("digit-led label",  "3dfx: ret\nbr 3dfx\n", 1);
  bad+=try("numbers stay numbers","1: sob r2, 1b\nmovq #0x3d, r1\nmovq #0b101, r2\nmovq #10, r3\nbr 2f\n2: ret\n", 1);
  bad+=try("0x alone is a name","0x: ret\n", 1);
  bad+=try("no displacement",  "movq (r1), r2\nmovq (r1)(r2*4), r3\njmpi (sp)\n", 1);
  bad+=try("expr in parens",   "movq #(1+2)*3, r2\n", 1);
  bad+=try("; in a string",   ".byte \"a;b c\", ';', 0 ; comment\n", 1);
  bad+=try("space in a string", ".ascii \"hello world\"\n", 1);
  bad+=try("space splits a name", "br foo bar\n", 0);
  bad+=try("space in a label", "a b: ret\n", 0);
  bad+=try("space in a number", "movq #1 2, r1\n", 0);
  bad+=try("escapes",          "besc_bad r1\n", 0);
  bad+=try("unknown mnemonic", "frobnicate r1, r2\n", 0);
  bad+=try("r32 is no register","add r32, r2\n", 0);
  bad+=try("r31 is a register", "add r31, r16\n", 1);
  bad+=try("r32 is no label",   "r32: ret\n", 0);
  bad+=try("r2d2 is a name",    "r2d2: ret\nbr r2d2\n", 1);
  bad+=try("r15 and sp work",   "add r15, sp\nmovq (fp)+, r0\n", 1);
  /* the spellings added by errata 139 */
  bad+=try("// comment",       "clr r1 // and a comment\n// nothing here\n", 1);
  bad+=try("// in a string",   ".ascii \"a//b\"\n", 1);
  bad+=try("$ immediate",      "movq $5, r1\nadd $[1+2], r2\n", 1);
  bad+=try("% before a register","movq %r1, %sp\nmovq (%r1), r2\n", 1);
  bad+=try("r32 with %",       "add %r32, r2\n", 0);
  bad+=try("AT&T indexed",     "movq (%r1,%r2,4), r3\nmovq 8(%r1,%r2), r3\n", 1);
  bad+=try("AT&T bad scale",   "movq (%r1,%r2,3), r3\n", 0);
  bad+=try("base plus disp",   "movq r5+8, r1\nmovq r5 - 8, r1\nmovq sp+x, r1\n", 1);
  bad+=try("equ",              "N equ 4\nM = N*2\n", 1);
  bad+=try("db and dw",        "db 1, 2, \"ab\"\ndw 1000\nlab: db 0\n", 1);
  bad+=try("proc and endp",    "f proc\nret\nf endp\nendp\n", 1);
  bad+=try("[ ] and ! operators","N = [1+2]*3\nM = 5 ! 1\n", 1);
  bad+=try("< > byte operators","movq #<0x1234, r1\nmovq #>0x1234, r2\n", 1);
  bad+=try(".if .else .endif", ".if 1\n.else\n.endif\n", 1);
  bad+=try("registers keep names","r5: ret\n", 0);
  return bad!=0;}
