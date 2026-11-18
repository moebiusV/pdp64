; expect: 70
; the names that as64 reads as words (db dw dd dq, v0-v15, t0-t7, and r<n>, sp, fp, ch) as globals of a C program: written in double quotes
; asm: "dd"
; asm: "v3"
; asm: "t5"
@dd = global [4 x i32] [i32 1, i32 2, i32 3, i32 4]
@db = global i32 10
@dw = global i32 20
@dq = global i32 0
@v3 = global i32 30
@t5 = global i32 -5
@v16 = global i32 7
@ch = global i32 1
define i32 @test() {
  %p = getelementptr [4 x i32], ptr @dd, i32 0, i32 2
  %a = load i32, ptr %p
  %b = load i32, ptr @db
  %c = load i32, ptr @dw
  %d = load i32, ptr @v3
  %e = load i32, ptr @t5
  %f = load i32, ptr @v16
  %g = load i32, ptr @ch
  store i32 4, ptr @dq
  %h = load i32, ptr @dq
  %s1 = add i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = add i32 %s2, %d
  %s4 = add i32 %s3, %e
  %s5 = add i32 %s4, %f
  %s6 = add i32 %s5, %g
  %s7 = add i32 %s6, %h
  ret i32 %s7
}
