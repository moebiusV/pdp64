; expect: 5255  -- alloca of a variable size (the stack pointer moves; calls from such a function use the frame pointer)
declare ptr @llvm.stacksave.p0()
declare void @llvm.stackrestore.p0(ptr)
define i64 @fill(i64 %n) {
  %buf = alloca i64, i64 %n, align 8
  br label %loop
loop:
  %i = phi i64 [ 0, %0 ], [ %in, %loop ]
  %p = getelementptr i64, ptr %buf, i64 %i
  %v = mul i64 %i, %i
  store i64 %v, ptr %p
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, %n
  br i1 %c, label %loop, label %sum
sum:
  br label %sl
sl:
  %j = phi i64 [ 0, %sum ], [ %jn, %sl ]
  %s = phi i64 [ 0, %sum ], [ %sn, %sl ]
  %q = getelementptr i64, ptr %buf, i64 %j
  %w = load i64, ptr %q
  %sn = add i64 %s, %w
  %jn = add i64 %j, 1
  %cc = icmp ult i64 %jn, %n
  br i1 %cc, label %sl, label %done
done:
  ret i64 %sn
}
define i64 @outer(i64 %n) {
  %a = call i64 @fill(i64 %n)
  %b = alloca i8, i64 %n
  store i8 5, ptr %b
  %c = call i64 @fill(i64 5)
  %d = load i8, ptr %b
  %e = zext i8 %d to i64
  %s = add i64 %a, %c
  %t = add i64 %s, %e
  ret i64 %t
}
define i32 @test() {
  %a = call i64 @outer(i64 10)
  %b = call i64 @outer(i64 25)
  %s = add i64 %a, %b
  %t = trunc i64 %s to i32
  ret i32 %t
}
