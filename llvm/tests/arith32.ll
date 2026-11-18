; expect: -134180863  -- i32 wraparound: results are re-extended where the sign matters
define i32 @test() {
  %a = add i32 2147483647, 10
  %b = mul i32 %a, 65537
  %c = sub i32 %b, -5
  %d = ashr i32 %c, 3
  %e = icmp slt i32 %a, 0
  %f = zext i1 %e to i32
  %g = add i32 %d, %f
  %h = sext i32 %g to i64
  %i = ashr i64 %h, 1
  %j = trunc i64 %i to i32
  ret i32 %j
}
