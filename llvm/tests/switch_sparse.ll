; expect: 7942  -- a sparse switch on i64 (a compare tree) and a switch on i8
define i64 @g(i64 %x) {
  switch i64 %x, label %def [
    i64 1, label %a
    i64 1000, label %b
    i64 1000000, label %c
    i64 -5, label %d
    i64 4294967296, label %e
  ]
a: ret i64 11
b: ret i64 22
c: ret i64 33
d: ret i64 44
e: ret i64 55
def: ret i64 0
}
define i32 @h(i8 %x) {
  switch i8 %x, label %def [
    i8 -128, label %a
    i8 0, label %b
    i8 127, label %c
  ]
a: ret i32 7
b: ret i32 70
c: ret i32 700
def: ret i32 7000
}
define i32 @test() {
  %a = call i64 @g(i64 1)
  %b = call i64 @g(i64 1000)
  %c = call i64 @g(i64 1000000)
  %d = call i64 @g(i64 -5)
  %e = call i64 @g(i64 4294967296)
  %f = call i64 @g(i64 77)
  %s1 = add i64 %a, %b
  %s2 = add i64 %s1, %c
  %s3 = add i64 %s2, %d
  %s4 = add i64 %s3, %e
  %s5 = add i64 %s4, %f
  %x1 = call i32 @h(i8 -128)
  %x2 = call i32 @h(i8 0)
  %x3 = call i32 @h(i8 127)
  %x4 = call i32 @h(i8 5)
  %y1 = add i32 %x1, %x2
  %y2 = add i32 %y1, %x3
  %y3 = add i32 %y2, %x4
  %t = trunc i64 %s5 to i32
  %r = add i32 %t, %y3
  ret i32 %r
}
