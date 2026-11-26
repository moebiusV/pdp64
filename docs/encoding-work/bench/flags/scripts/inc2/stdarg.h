#ifndef _STDARG_H
#define _STDARG_H
typedef __builtin_va_list va_list;
#define va_start(a,b) __builtin_va_start(a,b)
#define va_arg(a,t) __builtin_va_arg(a,t)
#define va_end(a) __builtin_va_end(a)
#define va_copy(a,b) __builtin_va_copy(a,b)
#endif
