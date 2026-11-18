; expect: 319397326  -- a pointer that moves by the size of each access: (rN)+ loads and stores, -(rN) pre-decrement, for 8, 4, 2 and 1 bytes
@src = global [16 x i64] [i64 1, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7, i64 8, i64 9, i64 10, i64 11, i64 12, i64 13, i64 14, i64 15, i64 16]
@dst = global [16 x i64] zeroinitializer
@bytes = global [8 x i8] c"\01\02\03\04\05\06\07\08"
@words = global [8 x i16] [i16 1, i16 -2, i16 3, i16 -4, i16 5, i16 -6, i16 7, i16 -8]
define i64 @copy(ptr %s, ptr %d, ptr %end) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %s, %entry ], [ %pn, %loop ]
  %q = phi ptr [ %d, %entry ], [ %qn, %loop ]
  %v = load i64, ptr %p
  %w = mul i64 %v, 3
  store i64 %w, ptr %q
  %pn = getelementptr i64, ptr %p, i64 1
  %qn = getelementptr i64, ptr %q, i64 1
  %c = icmp ult ptr %pn, %end
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %w
}
define i64 @sumb(ptr %s, ptr %end) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %s, %entry ], [ %pn, %loop ]
  %a = phi i64 [ 0, %entry ], [ %an, %loop ]
  %v = load i8, ptr %p
  %z = zext i8 %v to i64
  %an = add i64 %a, %z
  %pn = getelementptr i8, ptr %p, i64 1
  %c = icmp ult ptr %pn, %end
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %an
}
define i64 @sumw(ptr %s, ptr %end) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %s, %entry ], [ %pn, %loop ]
  %a = phi i64 [ 0, %entry ], [ %an, %loop ]
  %v = load i16, ptr %p
  %z = sext i16 %v to i64
  %an = add i64 %a, %z
  %pn = getelementptr i16, ptr %p, i64 1
  %c = icmp ult ptr %pn, %end
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %an
}
define i64 @rev(ptr %s, ptr %start) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %s, %entry ], [ %pn, %loop ]
  %a = phi i64 [ 0, %entry ], [ %an, %loop ]
  %pn = getelementptr i64, ptr %p, i64 -1
  %v = load i64, ptr %pn
  %m = mul i64 %a, 31
  %an = add i64 %m, %v
  %c = icmp ugt ptr %pn, %start
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %an
}
define i32 @test() {
  %e = getelementptr [16 x i64], ptr @src, i64 0, i64 16
  %r1 = call i64 @copy(ptr @src, ptr @dst, ptr %e)
  %e2 = getelementptr [8 x i8], ptr @bytes, i64 0, i64 8
  %r2 = call i64 @sumb(ptr @bytes, ptr %e2)
  %e3 = getelementptr [8 x i16], ptr @words, i64 0, i64 8
  %r3 = call i64 @sumw(ptr @words, ptr %e3)
  %r4 = call i64 @rev(ptr %e, ptr @src)
  %d9 = getelementptr [16 x i64], ptr @dst, i64 0, i64 9
  %v9 = load i64, ptr %d9
  %s1 = add i64 %r1, %r2
  %s2 = mul i64 %s1, 7
  %s3 = add i64 %s2, %r3
  %s4 = xor i64 %s3, %r4
  %s5 = add i64 %s4, %v9
  %t = trunc i64 %s5 to i32
  ret i32 %t
}
