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
  bad+=try("immediate, comment","movq #-5, r3 ; five\n", 1);
  bad+=try("indexed",          "movq 4(r1)(r2*8), r0\n", 1);
  bad+=try("postinc / predec", "movq (sp)+, r0\nmovq r0, -(sp)\nmovq r0, (sp)-16\n", 1);
  bad+=try("pc and dp",        "movq tab(pc), r1\nmovq 16(dp), r2\n", 1);
  bad+=try("absolute",         "movq @0x1000, r1\n", 1);
  bad+=try("directives",       ".text\n.globl start\nstart: .quad 1, 2\n.byte \"hello\\n\", 'a', '\\n', 0x41, 0b101, 0o17, 0\n.comm buf, 64\n", 1);
  bad+=try("numeric labels",   "1: sob r2, 1b\nbr 2f\n2: halt\n", 1);
  bad+=try("comment only",     "; nothing here\nclr r1 ; and a comment\n", 1);
  bad+=try("division",         "N = 100/7*2\nmovq #N/2, r1\n", 1);
  bad+=try("string escapes",   ".ascii \"a\\tb\\x41\\101\\0\"\n", 1);
  bad+=try("old strings gone", ".byte <hello>\n", 0);
  bad+=try("two per line gone","clr r1; inc r1 \n", 1);
  bad+=try("assignment",       "N = 4*8+1\n", 1);
  bad+=try("utf8 label",       "caf\xc3\xa9: ret\n", 1);
  bad+=try("cjk label and use","\xe3\x83\xab\xe3\x83\xbc\xe3\x83\x97: bne \xe3\x83\xab\xe3\x83\xbc\xe3\x83\x97\n", 1);
  bad+=try("quoted name",      "\"odd name!\": ret\n", 1);
  bad+=try("utf8 string/char", ".ascii \"h\xc3\xa9llo\"\nmovq #'\xc3\xa9', r1 ; \xe2\x9c\x93\n", 1);
  bad+=try("\\u escapes",      ".ascii \"\\u00e9\\U0001F600\"\n", 1);
  bad+=try("invalid byte",     "caf\xff: ret\n", 0);
  bad+=try("truncated utf8",   ".ascii \"\xc3\"\n", 0);
  bad+=try("overlong utf8",    ".ascii \"\xc0\x80\"\n", 0);
  bad+=try("surrogate",        ".ascii \"\xed\xa0\x80\"\n", 0);
  bad+=try("bad utf8 comment", "ret ; \xff\n", 0);
  bad+=try("digit-led label",  "3dfx: ret\nbne 3dfx\n", 1);
  bad+=try("numbers stay numbers","1: sob r2, 1b\nmovq #0x3d, r1\nmovq #0b101, r2\nmovq #10, r3\nbr 2f\n2: ret\n", 1);
  bad+=try("0x alone is a name","0x: ret\n", 1);
  bad+=try("escapes",          "besc_bad r1\n", 0);
  bad+=try("unknown mnemonic", "frobnicate r1, r2\n", 0);
  bad+=try("bad register",     "add r16, r2\n", 0);
  return bad!=0;}
