; expect: 705026574  -- a struct {i8, i16, i32, i64, double, i8} in memory: field stores and loads of every width
%S = type { i8, i16, i32, i64, double, i8 }
define i64 @sum(ptr %p) {
  %f0 = getelementptr %S, ptr %p, i32 0, i32 0
  %f1 = getelementptr %S, ptr %p, i32 0, i32 1
  %f2 = getelementptr %S, ptr %p, i32 0, i32 2
  %f3 = getelementptr %S, ptr %p, i32 0, i32 3
  %f4 = getelementptr %S, ptr %p, i32 0, i32 4
  %f5 = getelementptr %S, ptr %p, i32 0, i32 5
  %a = load i8, ptr %f0
  %b = load i16, ptr %f1
  %c = load i32, ptr %f2
  %d = load i64, ptr %f3
  %e = load double, ptr %f4
  %g = load i8, ptr %f5
  %a64 = sext i8 %a to i64
  %b64 = zext i16 %b to i64
  %c64 = sext i32 %c to i64
  %e64 = fptosi double %e to i64
  %g64 = zext i8 %g to i64
  %s1 = add i64 %a64, %b64
  %s2 = add i64 %s1, %c64
  %s3 = add i64 %s2, %d
  %s4 = add i64 %s3, %e64
  %s5 = add i64 %s4, %g64
  ret i64 %s5
}
define i32 @test() {
  %s = alloca %S, align 8
  %f0 = getelementptr %S, ptr %s, i32 0, i32 0
  %f1 = getelementptr %S, ptr %s, i32 0, i32 1
  %f2 = getelementptr %S, ptr %s, i32 0, i32 2
  %f3 = getelementptr %S, ptr %s, i32 0, i32 3
  %f4 = getelementptr %S, ptr %s, i32 0, i32 4
  %f5 = getelementptr %S, ptr %s, i32 0, i32 5
  store i8 -100, ptr %f0
  store i16 -3000, ptr %f1
  store i32 -70000, ptr %f2
  store i64 5000000000, ptr %f3
  store double 1234.75, ptr %f4
  store i8 200, ptr %f5
  %r = call i64 @sum(ptr %s)
  %t = trunc i64 %r to i32
  ret i32 %t
}
