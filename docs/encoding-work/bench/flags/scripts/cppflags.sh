# source this: sets OB, CPPF (pcc preprocessing)
OB=/home/matthew/claude/openbsd-src
W=/tmp/flags-work
CPPF="-E -P -undef -nostdinc -D__pcc__ -D__LP64__ -D_LP64 -I$W/inc -I$OB/sys -isystem $OB/include -idirafter $OB/lib/libc/include -idirafter $OB/lib/libc/hidden -idirafter $OB/sys/lib/libkern -idirafter $W/inc2 -include $W/prelude.h -w"
