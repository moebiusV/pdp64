#include "pdp64-parser.c"
#include "fmt.h"
struct tv { const char *what; int n; uint8_t b[8]; int shape; };
static const struct tv T[] = {
 {"ADD R1,R2",              2, {0x16,0x21}, FS_MEM0},
 {"MOVQ 8(R5),R3",          4, {0x40,0x30,0x50,0x08}, FS_BASE},
 {"MOVQ #-5,R3",            4, {0x40,0x34,0xFF,0xFB}, FS_WIDE},
 {"BNE -3",                 2, {0x31,0xFD}, FS_BR0},
 {"BR +65536 (len2)",       6, {0xB0,0x00,0x00,0x01,0x00,0x00}, FS_D},
 {"CLZ R2,R1",              4, {0x4C,0x12,0x00,0x00}, FS_REGESC},
 {"MOVQ 4(R1)(R2*8),R0",    4, {0x40,0x01,0x12,0xC4}, FS_INDEX},
 {"ADD #0x123456789ABC,R4", 8, {0xD6,0x44,0x12,0x34,0x56,0x78,0x9A,0xBC}, FS_WIDE},
 {"ADDM R3,16(R5)",         4, {0x4F,0x30,0x85,0x10}, FS_MEMESC},
 {"RET",                    2, {0x14,0x03}, FS_SYS0},
 {"BTAG R1,#3 (len1)",       4, {0x55,0x1B,0x00,0x05}, FS_D},
 {"RORI R1,#5,R2",          4, {0x4C,0x21,0x11,0x05}, FS_COUNT},
 {"DSHR (len2)",            6, {0x8C,0x31,0x20,0x20,0x05,0x00}, FS_FIELD},
 {"PROBER R1,R2",           4, {0x54,0xD2,0x10,0x00}, FS_SYSRD},
 {"TRAPL #200",             4, {0x54,0xF0,0xC8,0x00}, FS_SYSN},
 {"SOB R2,-4 (len1)",       4, {0x7F,0x20,0xFF,0xFC}, FS_D},
};
int main(void){
  int bad=0;
  for(unsigned k=0;k<sizeof T/sizeof *T;k++){
    insn_t i; char err[200]; size_t at; uint8_t out[16]; size_t n;
    if(!parse_bytes(T[k].b,T[k].n,&i,err,sizeof err,&at)){printf("PARSE FAIL %-24s %s\n",T[k].what,err);bad++;continue;}
    if(!emit_bytes(&i,out,sizeof out,&n,err,sizeof err)){printf("EMIT FAIL  %-24s %s\n",T[k].what,err);bad++;continue;}
    int same=(n==(size_t)T[k].n&&!memcmp(out,T[k].b,n)) && i.body.kind==T[k].shape;
    printf("%s %-24s len=%d opc=0x%02x reg=%d low=%d alt=%d want=%d\n",same?"ok  ":"DIFF",T[k].what,i.len,i.opc,i.reg,i.low,i.body.kind,T[k].shape);
    if(!same)bad++;
  }
  return bad!=0;}
