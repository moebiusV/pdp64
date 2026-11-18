; expect: 15297  -- global scalars and arrays: pc-relative loads and stores, an array indexed by a variable, address of a global, a pointer stored in a global
@counter = global i64 10
@table = global [10 x i64] [i64 5, i64 4, i64 3, i64 2, i64 1, i64 0, i64 -1, i64 -2, i64 -3, i64 -4]
@ptr = global ptr @table
@bss = global [16 x i32] zeroinitializer
@str = constant [6 x i8] c"hello\00"
define void @bump(i64 %by) {
  %v = load i64, ptr @counter
  %n = add i64 %v, %by
  store i64 %n, ptr @counter
  ret void
}
define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %in, %loop ]
  %p = getelementptr [10 x i64], ptr @table, i64 0, i64 %i
  %v = load i64, ptr %p
  call void @bump(i64 %v)
  %q = getelementptr [16 x i32], ptr @bss, i64 0, i64 %i
  %t = trunc i64 %v to i32
  store i32 %t, ptr %q
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, 10
  br i1 %c, label %loop, label %exit
exit:
  %cnt = load i64, ptr @counter
  %tp = load ptr, ptr @ptr
  %e = getelementptr i64, ptr %tp, i64 3
  %ev = load i64, ptr %e
  %b9 = getelementptr [16 x i32], ptr @bss, i64 0, i64 9
  %b9v = load i32, ptr %b9
  %s1 = getelementptr [6 x i8], ptr @str, i64 0, i64 1
  %s1v = load i8, ptr %s1
  %s1x = zext i8 %s1v to i64
  %a = mul i64 %cnt, 1000
  %b = mul i64 %ev, 100
  %b9x = sext i32 %b9v to i64
  %c1 = add i64 %a, %b
  %c2 = add i64 %c1, %b9x
  %c3 = add i64 %c2, %s1x
  %r = trunc i64 %c3 to i32
  ret i32 %r
}
