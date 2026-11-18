; expect: 2147315885  -- select with every integer comparison, signed and unsigned, 32 and 64 bits, and with a constant operand
define i64 @pick(i64 %a, i64 %b) {
  %c0 = icmp eq i64 %a, %b
  %c1 = icmp ne i64 %a, %b
  %c2 = icmp slt i64 %a, %b
  %c3 = icmp sle i64 %a, %b
  %c4 = icmp sgt i64 %a, %b
  %c5 = icmp sge i64 %a, %b
  %c6 = icmp ult i64 %a, %b
  %c7 = icmp ule i64 %a, %b
  %c8 = icmp ugt i64 %a, %b
  %c9 = icmp uge i64 %a, %b
  %s0 = select i1 %c0, i64 1, i64 0
  %s1 = select i1 %c1, i64 2, i64 0
  %s2 = select i1 %c2, i64 4, i64 0
  %s3 = select i1 %c3, i64 8, i64 0
  %s4 = select i1 %c4, i64 16, i64 0
  %s5 = select i1 %c5, i64 32, i64 0
  %s6 = select i1 %c6, i64 64, i64 0
  %s7 = select i1 %c7, i64 128, i64 0
  %s8 = select i1 %c8, i64 256, i64 0
  %s9 = select i1 %c9, i64 512, i64 0
  %t1 = or i64 %s0, %s1
  %t2 = or i64 %t1, %s2
  %t3 = or i64 %t2, %s3
  %t4 = or i64 %t3, %s4
  %t5 = or i64 %t4, %s5
  %t6 = or i64 %t5, %s6
  %t7 = or i64 %t6, %s7
  %t8 = or i64 %t7, %s8
  %t9 = or i64 %t8, %s9
  ret i64 %t9
}
define i32 @pick32(i32 %a, i32 %b) {
  %c2 = icmp slt i32 %a, %b
  %c6 = icmp ult i32 %a, %b
  %s2 = select i1 %c2, i32 1, i32 0
  %s6 = select i1 %c6, i32 2, i32 0
  %s = or i32 %s2, %s6
  %m = select i1 %c2, i32 %a, i32 %b
  %r = add i32 %s, %m
  ret i32 %r
}
define i32 @test() {
  %a = call i64 @pick(i64 5, i64 5)
  %b = call i64 @pick(i64 -1, i64 1)
  %c = call i64 @pick(i64 1, i64 -1)
  %d = call i64 @pick(i64 -9223372036854775808, i64 9223372036854775807)
  %e = call i64 @pick(i64 100, i64 70000)
  %f = call i32 @pick32(i32 -5, i32 3)
  %g = call i32 @pick32(i32 3, i32 -5)
  %h = call i32 @pick32(i32 -2147483648, i32 2147483647)
  %s1 = add i64 %a, %b
  %s2 = mul i64 %s1, 3
  %s3 = add i64 %s2, %c
  %s4 = mul i64 %s3, 5
  %s5 = add i64 %s4, %d
  %s6 = mul i64 %s5, 7
  %s7 = add i64 %s6, %e
  %t = trunc i64 %s7 to i32
  %u = add i32 %t, %f
  %v = xor i32 %u, %g
  %w = add i32 %v, %h
  ret i32 %w
}
