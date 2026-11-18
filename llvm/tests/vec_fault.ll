; expect: fault:unmapped memory
; llc:
; llc: -pdp64-vecloop
; llc: -pdp64-vecloop -pdp64-vecloop-strip
; asm-vec: ^[[:space:]]*vec[[:space:]]
; a vec block that runs off the end of the mapped memory (4M floats from a 16-float array): the strip that touches the unmapped page faults, as the scalar loop does (sim64 without -K: the message and status 139)
@A = internal global [16 x float] zeroinitializer
@N = global i64 4194304
define internal void @fill(ptr %d, float %v, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %p = getelementptr float, ptr %d, i64 %i
  store float %v, ptr %p
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}
define i32 @test() {
entry:
  %n = load volatile i64, ptr @N
  call void @fill(ptr @A, float 1.0, i64 %n)
  ret i32 5
}
