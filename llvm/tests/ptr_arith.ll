; expect: 457  -- pointer arithmetic: gep with variable, negative and scaled offsets, ptrtoint/inttoptr, pointer comparison and difference, array of structs
%P = type { i32, i32, i64 }
@arr = global [5 x %P] [%P { i32 1, i32 2, i64 3 }, %P { i32 4, i32 5, i64 6 }, %P { i32 7, i32 8, i64 9 }, %P { i32 10, i32 11, i64 12 }, %P { i32 13, i32 14, i64 15 }]
define i64 @f(ptr %p, i64 %n) {
entry:
  %end = getelementptr %P, ptr %p, i64 %n
  br label %loop
loop:
  %q = phi ptr [ %p, %entry ], [ %qn, %loop ]
  %s = phi i64 [ 0, %entry ], [ %sn, %loop ]
  %f0 = getelementptr %P, ptr %q, i32 0, i32 0
  %f1 = getelementptr %P, ptr %q, i32 0, i32 1
  %f2 = getelementptr %P, ptr %q, i32 0, i32 2
  %a = load i32, ptr %f0
  %b = load i32, ptr %f1
  %c = load i64, ptr %f2
  %ab = mul i32 %a, %b
  %ab64 = sext i32 %ab to i64
  %t = add i64 %ab64, %c
  %sn = add i64 %s, %t
  %qn = getelementptr %P, ptr %q, i64 1
  %done = icmp eq ptr %qn, %end
  br i1 %done, label %exit, label %loop
exit:
  ret i64 %sn
}
define i32 @test() {
  %r = call i64 @f(ptr @arr, i64 5)
  %last = getelementptr %P, ptr @arr, i64 4
  %mid = getelementptr %P, ptr %last, i64 -2
  %mi = ptrtoint ptr %mid to i64
  %li = ptrtoint ptr %last to i64
  %diff = sub i64 %li, %mi
  %back = inttoptr i64 %mi to ptr
  %f2 = getelementptr %P, ptr %back, i32 0, i32 2
  %v = load i64, ptr %f2
  %lt = icmp ult ptr %mid, %last
  %ltz = zext i1 %lt to i64
  %s1 = add i64 %r, %diff
  %s2 = add i64 %s1, %v
  %s3 = add i64 %s2, %ltz
  %t = trunc i64 %s3 to i32
  ret i32 %t
}
