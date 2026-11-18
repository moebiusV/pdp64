; expect: 75
; the words of as64 as globals of a C program: dd db dw dq and v3 t5 are plain symbols (errata 169), a name that is a valid number (ch, ah, deadh: hexadecimal digits
; and an h) or a register (r16, sp) is written in double quotes
; asm: lea dd\+8
; noasm: "dd"
; noasm: "v3"
; asm: lea "ch"
; asm: "ah"
; asm: "deadh"
; asm: "r16"
@dd = global [4 x i32] [i32 1, i32 2, i32 3, i32 4]
@db = global i32 10
@dw = global i32 20
@dq = global i32 0
@v3 = global i32 30
@t5 = global i32 -5
@v16 = global i32 7
@ch = global i32 1
@ah = global i32 2
@r16 = global i32 0
@deadh = global i32 3
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
  %i = load i32, ptr @ah
  %j = load i32, ptr @deadh
  %s1 = add i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = add i32 %s2, %d
  %s4 = add i32 %s3, %e
  %s5 = add i32 %s4, %f
  %s6 = add i32 %s5, %g
  %s7 = add i32 %s6, %h
  %s8 = add i32 %s7, %i
  %s9 = add i32 %s8, %j
  ret i32 %s9
}
