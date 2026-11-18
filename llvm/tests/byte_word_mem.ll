; expect: -261144  -- byte and word arrays in globals: loads sign- and zero-extend, stores truncate, indexed addressing
@b = global [8 x i8] [i8 1, i8 -2, i8 127, i8 -128, i8 255, i8 0, i8 64, i8 -64]
@w = global [6 x i16] [i16 1, i16 -2, i16 32767, i16 -32768, i16 65535, i16 300]
@l = global [4 x i32] [i32 -1, i32 2147483647, i32 -2147483648, i32 100000]
define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %in, %loop ]
  %s = phi i64 [ 0, %entry ], [ %sn, %loop ]
  %pb = getelementptr [8 x i8], ptr @b, i64 0, i64 %i
  %vb = load i8, ptr %pb
  %sb = sext i8 %vb to i64
  %zb = zext i8 %vb to i64
  %t1 = mul i64 %sb, 3
  %t2 = add i64 %t1, %zb
  %j = and i64 %i, 3
  %pw = getelementptr [6 x i16], ptr @w, i64 0, i64 %j
  %vw = load i16, ptr %pw
  %sw = sext i16 %vw to i64
  %zw = zext i16 %vw to i64
  %t3 = xor i64 %sw, %zw
  %pl = getelementptr [4 x i32], ptr @l, i64 0, i64 %j
  %vl = load i32, ptr %pl
  %sl = sext i32 %vl to i64
  %zl = zext i32 %vl to i64
  %t4 = sub i64 %sl, %zl
  %u1 = add i64 %t2, %t3
  %u2 = add i64 %u1, %t4
  %sn = add i64 %s, %u2
  ; store back narrowed
  %nb = trunc i64 %sn to i8
  store i8 %nb, ptr %pb
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, 8
  br i1 %c, label %loop, label %exit
exit:
  %p7 = getelementptr [8 x i8], ptr @b, i64 0, i64 7
  %v7 = load i8, ptr %p7
  %e7 = sext i8 %v7 to i64
  %r = add i64 %sn, %e7
  %t = trunc i64 %r to i32
  ret i32 %t
}
