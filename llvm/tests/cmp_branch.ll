; expect: 5466596  -- compare-and-branch with immediates of every size (5, 16 bits and larger), unsigned and signed, zero tests, extremes
define i32 @f(i64 %x) {
entry:
  %c0 = icmp eq i64 %x, 0
  br i1 %c0, label %z, label %n0
z: ret i32 1
n0:
  %c1 = icmp eq i64 %x, 5
  br i1 %c1, label %five, label %n1
five: ret i32 2
n1:
  %c2 = icmp slt i64 %x, -3
  br i1 %c2, label %neg3, label %n2
neg3: ret i32 3
n2:
  %c3 = icmp ugt i64 %x, 40000
  br i1 %c3, label %big, label %n3
big:
  %c4 = icmp sgt i64 %x, 1000000
  br i1 %c4, label %huge, label %n4
huge:
  %c5 = icmp ult i64 %x, 5000000000
  br i1 %c5, label %mid, label %n5
mid: ret i32 4
n5: ret i32 5
n4: ret i32 6
n3:
  %c6 = icmp sge i64 %x, 300
  br i1 %c6, label %ge300, label %n6
ge300: ret i32 7
n6:
  %c7 = icmp ule i64 %x, 17
  br i1 %c7, label %le17, label %n7
le17: ret i32 8
n7: ret i32 9
}
define i32 @test() {
  %a = call i32 @f(i64 0)
  %b = call i32 @f(i64 5)
  %c = call i32 @f(i64 -4)
  %d = call i32 @f(i64 -1)
  %e = call i32 @f(i64 50000)
  %f = call i32 @f(i64 2000000)
  %g = call i32 @f(i64 9000000000)
  %h = call i32 @f(i64 12345)
  %i = call i32 @f(i64 300)
  %j = call i32 @f(i64 10)
  %k = call i32 @f(i64 100)
  %s1 = mul i32 %a, 1
  %s2 = mul i32 %b, 10
  %s3 = mul i32 %c, 100
  %s4 = mul i32 %d, 1000
  %s5 = mul i32 %e, 10000
  %s6 = mul i32 %f, 100000
  %s7 = mul i32 %g, 1000000
  %s8 = mul i32 %h, 3
  %s9 = mul i32 %i, 7
  %s10 = mul i32 %j, 11
  %s11 = mul i32 %k, 13
  %t1 = add i32 %s1, %s2
  %t2 = add i32 %t1, %s3
  %t3 = add i32 %t2, %s4
  %t4 = add i32 %t3, %s5
  %t5 = add i32 %t4, %s6
  %t6 = add i32 %t5, %s7
  %t7 = add i32 %t6, %s8
  %t8 = add i32 %t7, %s9
  %t9 = add i32 %t8, %s10
  %t10 = add i32 %t9, %s11
  ret i32 %t10
}
