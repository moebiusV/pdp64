#include "pdp64-parser.c"
struct tv { const char *what; int n; uint8_t b[8]; };
static const struct tv T[] = {
 {"ADD R1,R2",              2, {0x16,0x21}},
 {"MOVQ 8(R5),R3",          4, {0x40,0x30,0x50,0x08}},
 {"MOVQ #-5,R3",            4, {0x40,0x34,0xFF,0xFB}},
 {"BNE -3",                 2, {0x31,0xFD}},
 {"BR +65536 (len2)",       6, {0xB0,0x00,0x00,0x01,0x00,0x00}},
 {"CLZ R2,R1",              4, {0x4C,0x12,0x00,0x00}},
 {"MOVQ 4(R1)(R2*8),R0",    4, {0x40,0x01,0x12,0xC4}},
 {"ADD #0x123456789ABC,R4", 8, {0xD6,0x44,0x12,0x34,0x56,0x78,0x9A,0xBC}},
 {"ADDM R3,16(R5)",         4, {0x4F,0x30,0x85,0x10}},
 {"RET",                    2, {0x14,0x03}},
 {"SOB R2,-4 (len1)",       4, {0x7F,0x20,0xFF,0xFC}},
};
int main(void){
  int bad=0;
  for(unsigned k=0;k<sizeof T/sizeof *T;k++){
    insn_t i; char err[200]; size_t at; uint8_t out[16]; size_t n;
    if(!parse_bytes(T[k].b,T[k].n,&i,err,sizeof err,&at)){printf("PARSE FAIL %-24s %s\n",T[k].what,err);bad++;continue;}
    if(!emit_bytes(&i,out,sizeof out,&n,err,sizeof err)){printf("EMIT FAIL  %-24s %s\n",T[k].what,err);bad++;continue;}
    int same=(n==(size_t)T[k].n&&!memcmp(out,T[k].b,n));
    printf("%s %-24s len=%d opc=0x%02x reg=%d low=%d alt=%d\n",same?"ok  ":"DIFF",T[k].what,i.len,i.opc,i.reg,i.low,i.body.kind);
    if(!same)bad++;
  }
  return bad!=0;}
