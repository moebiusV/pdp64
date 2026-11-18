; expect: 49341  -- i8 and i16 arithmetic, sign and zero extension, truncation
define i32 @test() {
  %a = add i8 120, 20
  %b = zext i8 %a to i32
  %c = sext i8 %a to i32
  %d = mul i16 300, 300
  %e = zext i16 %d to i32
  %f = sext i16 %d to i32
  %g = sub i8 3, 10
  %h = zext i8 %g to i32
  %i = and i32 %b, 255
  %s1 = add i32 %b, %c
  %s2 = add i32 %e, %f
  %s3 = add i32 %s1, %s2
  %s4 = add i32 %s3, %h
  %s5 = add i32 %s4, %i
  ret i32 %s5
}
