; expect: -2147483618  -- smin, smax, umin, umax, abs on i64 and i32; the min and max instructions of the rare group
declare i64 @llvm.smin.i64(i64, i64)
declare i64 @llvm.smax.i64(i64, i64)
declare i64 @llvm.umin.i64(i64, i64)
declare i64 @llvm.umax.i64(i64, i64)
declare i64 @llvm.abs.i64(i64, i1)
declare i32 @llvm.smin.i32(i32, i32)
declare i32 @llvm.umax.i32(i32, i32)
declare i32 @llvm.abs.i32(i32, i1)
define i64 @f(i64 %a, i64 %b) {
  %x = call i64 @llvm.smin.i64(i64 %a, i64 %b)
  %y = call i64 @llvm.smax.i64(i64 %a, i64 %b)
  %z = call i64 @llvm.umin.i64(i64 %a, i64 %b)
  %w = call i64 @llvm.umax.i64(i64 %a, i64 %b)
  %v = call i64 @llvm.abs.i64(i64 %a, i1 false)
  %s1 = add i64 %x, %y
  %s2 = xor i64 %s1, %z
  %s3 = add i64 %s2, %w
  %s4 = xor i64 %s3, %v
  ret i64 %s4
}
define i32 @test() {
  %a = call i64 @f(i64 -5, i64 3)
  %b = call i64 @f(i64 9223372036854775807, i64 -9223372036854775808)
  %c = call i64 @f(i64 12, i64 12)
  %d = call i32 @llvm.smin.i32(i32 -2147483648, i32 5)
  %e = call i32 @llvm.umax.i32(i32 -1, i32 5)
  %g = call i32 @llvm.abs.i32(i32 -77, i1 false)
  %s1 = xor i64 %a, %b
  %s2 = add i64 %s1, %c
  %t = trunc i64 %s2 to i32
  %u = add i32 %t, %d
  %v = xor i32 %u, %e
  %w = add i32 %v, %g
  ret i32 %w
}
