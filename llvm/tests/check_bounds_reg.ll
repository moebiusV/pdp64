; expect: 10  -- a bounds check against a length in a register (ctcc rs, rb), the trap arm falling through (the condition is inverted), and an immediate too wide for the 12 bits of the immediate form (5000: loaded into a register first)
; asm: cthi r[0-9]+, r[0-9]+|ctcc r[0-9]+, r[0-9]+
; asm: movq #4999, r[0-9]+
; asm: \.chk	1,
@a = internal global [8 x i32] [i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 0, i32 0]
declare void @llvm.ubsantrap(i8 immarg)

define internal i32 @get(i64 %i, i64 %n) noinline {
entry:
  %c = icmp ult i64 %i, %n
  br i1 %c, label %ok, label %bad
ok:
  %p = getelementptr [8 x i32], ptr @a, i64 0, i64 %i
  %v = load i32, ptr %p
  ret i32 %v
bad:
  call void @llvm.ubsantrap(i8 18)
  unreachable
}
define internal i32 @big(i64 %i) noinline {
entry:
  %c = icmp ult i64 %i, 5000
  br i1 %c, label %ok, label %bad
ok:
  %t = trunc i64 %i to i32
  ret i32 %t
bad:
  call void @llvm.ubsantrap(i8 18)
  unreachable
}

define i32 @test() {
entry:
  %a = call i32 @get(i64 0, i64 6)
  %b = call i32 @get(i64 5, i64 6)
  %c = call i32 @get(i64 2, i64 3)
  %d = call i32 @big(i64 4999)
  %e = call i32 @big(i64 0)
  %s1 = add i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = add i32 %s2, %e
  %big = icmp eq i32 %d, 4999
  %r = select i1 %big, i32 %s3, i32 0
  ret i32 %r
}
