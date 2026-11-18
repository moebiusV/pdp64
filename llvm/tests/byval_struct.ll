; expect: 21016  -- a structure passed by value (byval, copied to the stack) and a structure returned through a hidden pointer (sret)
%B = type { i64, i64, i64, i32 }
define i64 @sumb(ptr byval(%B) align 8 %p, i64 %k) {
  %f0 = getelementptr %B, ptr %p, i32 0, i32 0
  %f1 = getelementptr %B, ptr %p, i32 0, i32 1
  %f2 = getelementptr %B, ptr %p, i32 0, i32 2
  %f3 = getelementptr %B, ptr %p, i32 0, i32 3
  %a = load i64, ptr %f0
  %b = load i64, ptr %f1
  %c = load i64, ptr %f2
  %d = load i32, ptr %f3
  %d64 = sext i32 %d to i64
  %s1 = add i64 %a, %b
  %s2 = mul i64 %s1, %c
  %s3 = add i64 %s2, %d64
  %s4 = add i64 %s3, %k
  ret i64 %s4
}
define void @mk(ptr sret(%B) align 8 %out, i64 %x) {
  %f0 = getelementptr %B, ptr %out, i32 0, i32 0
  %f1 = getelementptr %B, ptr %out, i32 0, i32 1
  %f2 = getelementptr %B, ptr %out, i32 0, i32 2
  %f3 = getelementptr %B, ptr %out, i32 0, i32 3
  %a = add i64 %x, 1
  %b = add i64 %x, 2
  %c = add i64 %x, 3
  %d = trunc i64 %x to i32
  store i64 %a, ptr %f0
  store i64 %b, ptr %f1
  store i64 %c, ptr %f2
  store i32 %d, ptr %f3
  ret void
}
define i32 @test() {
  %t = alloca %B, align 8
  call void @mk(ptr sret(%B) align 8 %t, i64 100)
  %r = call i64 @sumb(ptr byval(%B) align 8 %t, i64 7)
  %u = alloca %B, align 8
  call void @mk(ptr sret(%B) align 8 %u, i64 -5)
  %r2 = call i64 @sumb(ptr byval(%B) align 8 %u, i64 -9)
  %s = add i64 %r, %r2
  %x = trunc i64 %s to i32
  ret i32 %x
}
