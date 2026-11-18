typedef __UINT8_TYPE__ u8; typedef __INT8_TYPE__ i8; typedef __INT16_TYPE__ i16; typedef __UINT16_TYPE__ u16;
typedef __INT32_TYPE__ i32; typedef __UINT32_TYPE__ u32;
#define R __restrict
/* 1 SAD of bytes */
u32 sad(const u8*R a,const u8*R b,int n){u32 s=0;for(int i=0;i<n;i++){int d=a[i]-b[i];s+=d<0?-d:d;}return s;}
/* 2 int8 dot (q8dot) */
i32 dot_i8(const i8*R a,const i8*R b,int n){i32 s=0;for(int i=0;i<n;i++)s+=a[i]*b[i];return s;}
/* 3 u8*i8 dot (VNNI shape) */
i32 dot_u8i8(const u8*R a,const i8*R b,int n){i32 s=0;for(int i=0;i<n;i++)s+=a[i]*b[i];return s;}
/* 4 shift, clamp, narrow store */
void clipnarrow(u8*R o,const i16*R a,int n){for(int i=0;i<n;i++){int v=a[i]>>4;o[i]=v<0?0:v>255?255:v;}}
/* 5 average */
void avg8(u8*R o,const u8*R a,const u8*R b,int n){for(int i=0;i<n;i++)o[i]=(a[i]+b[i]+1)>>1;}
/* 6 Q15 rounding multiply high */
void mulhrs(i16*R o,const i16*R a,const i16*R b,int n){for(int i=0;i<n;i++)o[i]=((int)a[i]*b[i]+0x4000)>>15;}
/* 7 16x16->32 multiply-accumulate dot */
i32 dot_i16(const i16*R a,const i16*R b,int n){i32 s=0;for(int i=0;i<n;i++)s+=a[i]*b[i];return s;}
/* 8 saturating byte add */
void addsat(u8*R o,const u8*R a,const u8*R b,int n){for(int i=0;i<n;i++){int v=a[i]+b[i];o[i]=v>255?255:v;}}
/* 9 byte sum */
u32 sumb(const u8*R a,int n){u32 s=0;for(int i=0;i<n;i++)s+=a[i];return s;}
/* 10 widening multiply-accumulate into acc[] (i16*i16 -> i32 array) */
void wmac(i32*R acc,const i16*R a,i16 w,int n){for(int i=0;i<n;i++)acc[i]+=a[i]*w;}
/* 11 select */
void blend(u8*R o,const u8*R a,const u8*R b,const u8*R m,int n){for(int i=0;i<n;i++)o[i]=m[i]?a[i]:b[i];}
/* 12 abs diff */
void absdiff(u8*R o,const u8*R a,const u8*R b,int n){for(int i=0;i<n;i++){int d=a[i]-b[i];o[i]=d<0?-d:d;}}
/* 13 widen u8->u16 shift (prep) */
void prep(i16*R o,const u8*R a,int n){for(int i=0;i<n;i++)o[i]=a[i]<<4;}
/* 14 max reduce i16 */
i16 maxr(const i16*R a,int n){i16 m=-32768;for(int i=0;i<n;i++)m=a[i]>m?a[i]:m;return m;}
/* 15 float fma axpy */
void axpy(float*R y,const float*R x,float a,int n){for(int i=0;i<n;i++)y[i]+=a*x[i];}
/* 16 rounding shift right narrow  (x+8)>>4 -> u8 sat */
void rshrn(u8*R o,const u16*R a,int n){for(int i=0;i<n;i++){u32 v=(a[i]+8)>>4;o[i]=v>255?255:v;}}
/* 17 popcount sum */
u32 popc(const u32*R a,int n){u32 s=0;for(int i=0;i<n;i++)s+=__builtin_popcount(a[i]);return s;}
/* 18 stereo deinterleave */
void split(i16*R l,i16*R r,const i16*R a,int n){for(int i=0;i<n;i++){l[i]=a[2*i];r[i]=a[2*i+1];}}
/* 19 convert int->float scale */
void cvt(float*R o,const i32*R a,float s,int n){for(int i=0;i<n;i++)o[i]=a[i]*s;}
/* 20 table lookup bytes (gather from 16-entry LUT) */
void lut16(u8*R o,const u8*R a,const u8*R t,int n){for(int i=0;i<n;i++)o[i]=t[a[i]&15];}
