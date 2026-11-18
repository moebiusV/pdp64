; expect: -1571221691  -- count leading and trailing zeros, population count, byte swap, bit reverse, rotates by constants and by variables
declare i64 @llvm.ctlz.i64(i64, i1)
declare i64 @llvm.cttz.i64(i64, i1)
declare i64 @llvm.ctpop.i64(i64)
declare i64 @llvm.bswap.i64(i64)
declare i32 @llvm.bswap.i32(i32)
declare i64 @llvm.bitreverse.i64(i64)
declare i64 @llvm.fshl.i64(i64, i64, i64)
declare i64 @llvm.fshr.i64(i64, i64, i64)
declare i32 @llvm.fshl.i32(i32, i32, i32)
declare i32 @llvm.ctlz.i32(i32, i1)
declare i32 @llvm.ctpop.i32(i32)
define i64 @f(i64 %x, i64 %n) {
  %a = call i64 @llvm.ctlz.i64(i64 %x, i1 false)
  %b = call i64 @llvm.cttz.i64(i64 %x, i1 false)
  %c = call i64 @llvm.ctpop.i64(i64 %x)
  %d = call i64 @llvm.bswap.i64(i64 %x)
  %e = call i64 @llvm.bitreverse.i64(i64 %x)
  %f = call i64 @llvm.fshl.i64(i64 %x, i64 %x, i64 13)
  %g = call i64 @llvm.fshr.i64(i64 %x, i64 %x, i64 7)
  %h = call i64 @llvm.fshl.i64(i64 %x, i64 %x, i64 %n)
  %s1 = add i64 %a, %b
  %s2 = add i64 %s1, %c
  %s3 = xor i64 %s2, %d
  %s4 = add i64 %s3, %e
  %s5 = xor i64 %s4, %f
  %s6 = add i64 %s5, %g
  %s7 = xor i64 %s6, %h
  ret i64 %s7
}
define i32 @test() {
  %a = call i64 @f(i64 1311768467294899695, i64 21)
  %b = call i64 @f(i64 0, i64 3)
  %c = call i64 @f(i64 -1, i64 64)
  %d = call i64 @f(i64 4096, i64 63)
  %x32 = call i32 @llvm.bswap.i32(i32 305419896)
  %y32 = call i32 @llvm.ctlz.i32(i32 1000, i1 false)
  %z32 = call i32 @llvm.ctpop.i32(i32 -1)
  %r32 = call i32 @llvm.fshl.i32(i32 -2023406815, i32 -2023406815, i32 9)
  %s1 = xor i64 %a, %b
  %s2 = add i64 %s1, %c
  %s3 = xor i64 %s2, %d
  %t = trunc i64 %s3 to i32
  %u = add i32 %t, %x32
  %v = add i32 %u, %y32
  %w = xor i32 %v, %z32
  %q = add i32 %w, %r32
  ret i32 %q
}
