; The driver of llvm/check.sh: prints the value of test() in decimal, then a newline (what tools/pdp64test.sh's main.c does).
declare i64 @write(i32, ptr, i64)
declare i64 @test()

define i32 @main() {
entry:
  %buf = alloca [24 x i8], align 8
  %v = call i64 @test()
  %neg = icmp slt i64 %v, 0
  %nv = sub i64 0, %v
  %u = select i1 %neg, i64 %nv, i64 %v
  %end = getelementptr i8, ptr %buf, i64 24
  %p0 = getelementptr i8, ptr %end, i64 -1
  store i8 10, ptr %p0
  br label %loop

loop:
  %p = phi ptr [ %p0, %entry ], [ %pn, %loop ]
  %x = phi i64 [ %u, %entry ], [ %q, %loop ]
  %pn = getelementptr i8, ptr %p, i64 -1
  %r = urem i64 %x, 10
  %q = udiv i64 %x, 10
  %c = add i64 %r, 48
  %c8 = trunc i64 %c to i8
  store i8 %c8, ptr %pn
  %more = icmp ne i64 %q, 0
  br i1 %more, label %loop, label %done

done:
  %pf = getelementptr i8, ptr %pn, i64 -1
  store i8 45, ptr %pf
  %start = select i1 %neg, ptr %pf, ptr %pn
  %a = ptrtoint ptr %end to i64
  %b = ptrtoint ptr %start to i64
  %len = sub i64 %a, %b
  %w = call i64 @write(i32 1, ptr %start, i64 %len)
  ret i32 0
}
