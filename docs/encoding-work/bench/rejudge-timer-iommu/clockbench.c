#define _GNU_SOURCE
#include <time.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e9+t.tv_nsec;}
int main(void){
  struct timespec t; int N=2000000; double a,b;
  a=now(); for(int i=0;i<N;i++) clock_gettime(CLOCK_MONOTONIC,&t); b=now();
  printf("vdso  clock_gettime: %.1f ns/call\n",(b-a)/N);
  N=500000;
  a=now(); for(int i=0;i<N;i++) syscall(SYS_clock_gettime,CLOCK_MONOTONIC,&t); b=now();
  printf("syscall clock_gettime: %.1f ns/call\n",(b-a)/N);
  a=now(); for(int i=0;i<N;i++) syscall(SYS_getppid); b=now();
  printf("syscall getppid: %.1f ns/call\n",(b-a)/N);
  return 0;}
