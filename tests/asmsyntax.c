#include "pdp64-asm-parser.c"
static int try(const char *what, const char *text, int want){
  struct asm_list l; char err[300]; size_t ln=0, col=0;
  bool ok = parse_text(text, &l, err, sizeof err, &ln, &col);
  int n=0; for(struct asm_s *p=l.head;p;p=p->_link) n++;
  printf("%s %-28s %s (%d lines)%s%s\n", ok==want?"ok  ":"BAD ", what, ok?"parsed":"rejected", n, ok?"":" : ", ok?"":err);
  return ok!=want;
}
int main(void){
  int bad=0;
  bad+=try("move load",        "movq 8(r5), r3\n", 1);
  bad+=try("alu reg,reg",      "add r1, r2\n", 1);
  bad+=try("label + branch",   "loop:\tbne loop\n", 1);
  bad+=try("immediate, comment","movq #-5, r3 / five\n", 1);
  bad+=try("indexed",          "movq 4(r1)(r2*8), r0\n", 1);
  bad+=try("postinc / predec", "movq (sp)+, r0\nmovq r0, -(sp)\nmovq r0, (sp)-16\n", 1);
  bad+=try("pc and dp",        "movq tab(pc), r1\nmovq 16(dp), r2\n", 1);
  bad+=try("absolute",         "movq @0x1000, r1\n", 1);
  bad+=try("directives",       ".text\n.globl start\nstart: .quad 1, 2\n.byte <hello>, 0\n.comm buf, 64\n", 1);
  bad+=try("numeric labels",   "1: sob r2, 1b\nbr 2f\n2: halt\n", 1);
  bad+=try("two per line",     "clr r1; inc r1\n", 1);
  bad+=try("assignment",       "N = 4*8+1\n", 1);
  bad+=try("escapes",          "besc_bad r1\n", 0);
  bad+=try("unknown mnemonic", "frobnicate r1, r2\n", 0);
  bad+=try("bad register",     "add r16, r2\n", 0);
  return bad!=0;}
