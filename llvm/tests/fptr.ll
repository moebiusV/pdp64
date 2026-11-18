; expect: 1974  -- calls through function pointers: a table of functions in a global, a pointer passed as an argument, indirect call of a loaded pointer
@fns = global [3 x ptr] [ptr @inc, ptr @dbl, ptr @neg]
define i64 @inc(i64 %x) {
  %r = add i64 %x, 1
  ret i64 %r
}
define i64 @dbl(i64 %x) {
  %r = shl i64 %x, 1
  ret i64 %r
}
define i64 @neg(i64 %x) {
  %r = sub i64 0, %x
  ret i64 %r
}
define i64 @apply(ptr %f, i64 %x) {
  %r = call i64 %f(i64 %x)
  ret i64 %r
}
define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %in, %loop ]
  %v = phi i64 [ 5, %entry ], [ %vn, %loop ]
  %k = urem i64 %i, 3
  %pp = getelementptr [3 x ptr], ptr @fns, i64 0, i64 %k
  %f = load ptr, ptr %pp
  %w = call i64 @apply(ptr %f, i64 %v)
  %vn = add i64 %w, 3
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, 20
  br i1 %c, label %loop, label %exit
exit:
  %d = call i64 @apply(ptr @dbl, i64 %vn)
  %t = trunc i64 %d to i32
  ret i32 %t
}
