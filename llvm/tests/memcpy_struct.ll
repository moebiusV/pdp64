; expect: 5636  -- llvm.memcpy and llvm.memset: small constant sizes (inline loads/stores) and a variable size (a call of memcpy/memset in the crt)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)
declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)
%T = type { i64, i64, i32, i8, i8, i16 }
define i64 @sumbytes(ptr %p, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %in, %loop ]
  %s = phi i64 [ 0, %entry ], [ %sn, %loop ]
  %q = getelementptr i8, ptr %p, i64 %i
  %v = load i8, ptr %q
  %z = zext i8 %v to i64
  %sn = add i64 %s, %z
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %sn
}
define i32 @test() {
  %a = alloca %T, align 8
  %b = alloca %T, align 8
  %big = alloca [100 x i8], align 8
  %big2 = alloca [100 x i8], align 8
  %f0 = getelementptr %T, ptr %a, i32 0, i32 0
  %f1 = getelementptr %T, ptr %a, i32 0, i32 1
  %f2 = getelementptr %T, ptr %a, i32 0, i32 2
  %f3 = getelementptr %T, ptr %a, i32 0, i32 3
  %f5 = getelementptr %T, ptr %a, i32 0, i32 5
  store i64 1234567890123, ptr %f0
  store i64 -42, ptr %f1
  store i32 777, ptr %f2
  store i8 -3, ptr %f3
  store i16 4321, ptr %f5
  call void @llvm.memcpy.p0.p0.i64(ptr %b, ptr %a, i64 32, i1 false)
  %g1 = getelementptr %T, ptr %b, i32 0, i32 1
  %g2 = getelementptr %T, ptr %b, i32 0, i32 2
  %g5 = getelementptr %T, ptr %b, i32 0, i32 5
  %v1 = load i64, ptr %g1
  %v2 = load i32, ptr %g2
  %v5 = load i16, ptr %g5
  call void @llvm.memset.p0.i64(ptr %big, i8 7, i64 100, i1 false)
  %p10 = getelementptr i8, ptr %big, i64 10
  call void @llvm.memset.p0.i64(ptr %p10, i8 1, i64 20, i1 false)
  call void @llvm.memcpy.p0.p0.i64(ptr %big2, ptr %big, i64 100, i1 false)
  %sum = call i64 @sumbytes(ptr %big2, i64 100)
  %v2x = sext i32 %v2 to i64
  %v5x = zext i16 %v5 to i64
  %s1 = add i64 %sum, %v1
  %s2 = add i64 %s1, %v2x
  %s3 = add i64 %s2, %v5x
  %t = trunc i64 %s3 to i32
  ret i32 %t
}
