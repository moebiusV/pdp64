; expect: -1917086  -- many values live across calls (more than the caller-saved registers hold: callee-saved registers are used and restored)
define i64 @f(i64 %a) {
  %b = mul i64 %a, 3
  %c = add i64 %a, 17
  %d = xor i64 %a, 255
  %e = sub i64 %a, 99
  %f = shl i64 %a, 2
  %g = lshr i64 %a, 1
  %h = or i64 %a, 4096
  %i = add i64 %b, %c
  %j = mul i64 %d, 7
  %k = add i64 %e, %f
  %l = sub i64 %g, %h
  %m = xor i64 %i, %j
  %n = add i64 %k, %l
  %x1 = call i64 @id(i64 %b)
  %x2 = call i64 @id(i64 %c)
  %x3 = call i64 @id(i64 %d)
  %x4 = call i64 @id(i64 %e)
  %s1 = add i64 %x1, %x2
  %s2 = add i64 %s1, %x3
  %s3 = add i64 %s2, %x4
  %s4 = add i64 %s3, %f
  %s5 = add i64 %s4, %g
  %s6 = add i64 %s5, %h
  %s7 = add i64 %s6, %i
  %s8 = add i64 %s7, %j
  %s9 = add i64 %s8, %k
  %s10 = add i64 %s9, %l
  %s11 = add i64 %s10, %m
  %s12 = add i64 %s11, %n
  %s13 = add i64 %s12, %a
  %s14 = add i64 %s13, %b
  %s15 = add i64 %s14, %c
  %s16 = add i64 %s15, %d
  %s17 = add i64 %s16, %e
  ret i64 %s17
}
define i64 @id(i64 %x) {
  ret i64 %x
}
define i32 @test() {
  %a = call i64 @f(i64 1000)
  %b = call i64 @f(i64 %a)
  %c = call i64 @f(i64 -77)
  %s = xor i64 %b, %c
  %t = trunc i64 %s to i32
  ret i32 %t
}
