; expect: 68840  -- the lane operations that the C kernels do not reach (vsub, vor, vmax, vmin, vminu, vmaxu, vsubs, vaddsu, vsubsu, a vector minus a vector of doubles' neighbour), run as scalar loops and as vec blocks
; asm-vec: vsubs\.w
; asm-vec: vaddsu\.b
; asm-vec: vsubsu\.b
; asm-vec: vmax\.l
; asm-vec: vminu\.l
; asm-vec: vmaxu\.w
; asm-vec: vmin\.w
; asm-vec: vsub\.q
; asm-vec: vor\.l
; asm-vec: vsub\.f
; llc:
; llc: -pdp64-vecloop
; llc: -pdp64-vecloop -pdp64-vecloop-strip
declare i16 @llvm.ssub.sat.i16(i16, i16)
declare i8 @llvm.uadd.sat.i8(i8, i8)
declare i8 @llvm.usub.sat.i8(i8, i8)
declare i32 @llvm.smax.i32(i32, i32)
declare i32 @llvm.umin.i32(i32, i32)
declare i16 @llvm.umax.i16(i16, i16)
declare i16 @llvm.smin.i16(i16, i16)
@A = internal global [64 x i64] zeroinitializer
@B = internal global [64 x i64] zeroinitializer
@D = internal global [64 x i64] zeroinitializer

define internal void @f_ssub(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i16, ptr %a, i64 %i
  %pb = getelementptr i16, ptr %b, i64 %i
  %pd = getelementptr i16, ptr %d, i64 %i
  %x = load i16, ptr %pa
  %y = load i16, ptr %pb
  %z = call i16 @llvm.ssub.sat.i16(i16 %x, i16 %y)
  store i16 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_uadd(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i8, ptr %a, i64 %i
  %pb = getelementptr i8, ptr %b, i64 %i
  %pd = getelementptr i8, ptr %d, i64 %i
  %x = load i8, ptr %pa
  %y = load i8, ptr %pb
  %z = call i8 @llvm.uadd.sat.i8(i8 %x, i8 %y)
  store i8 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_usub(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i8, ptr %a, i64 %i
  %pb = getelementptr i8, ptr %b, i64 %i
  %pd = getelementptr i8, ptr %d, i64 %i
  %x = load i8, ptr %pa
  %y = load i8, ptr %pb
  %z = call i8 @llvm.usub.sat.i8(i8 %x, i8 %y)
  store i8 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_smax(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i32, ptr %a, i64 %i
  %pb = getelementptr i32, ptr %b, i64 %i
  %pd = getelementptr i32, ptr %d, i64 %i
  %x = load i32, ptr %pa
  %y = load i32, ptr %pb
  %z = call i32 @llvm.smax.i32(i32 %x, i32 %y)
  store i32 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_umin(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i32, ptr %a, i64 %i
  %pb = getelementptr i32, ptr %b, i64 %i
  %pd = getelementptr i32, ptr %d, i64 %i
  %x = load i32, ptr %pa
  %y = load i32, ptr %pb
  %z = call i32 @llvm.umin.i32(i32 %x, i32 %y)
  store i32 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_umax(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i16, ptr %a, i64 %i
  %pb = getelementptr i16, ptr %b, i64 %i
  %pd = getelementptr i16, ptr %d, i64 %i
  %x = load i16, ptr %pa
  %y = load i16, ptr %pb
  %z = call i16 @llvm.umax.i16(i16 %x, i16 %y)
  store i16 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_smin(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i16, ptr %a, i64 %i
  %pb = getelementptr i16, ptr %b, i64 %i
  %pd = getelementptr i16, ptr %d, i64 %i
  %x = load i16, ptr %pa
  %y = load i16, ptr %pb
  %z = call i16 @llvm.smin.i16(i16 %x, i16 %y)
  store i16 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_sub(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i64, ptr %a, i64 %i
  %pb = getelementptr i64, ptr %b, i64 %i
  %pd = getelementptr i64, ptr %d, i64 %i
  %x = load i64, ptr %pa
  %y = load i64, ptr %pb
  %z = sub i64 %x, %y
  store i64 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_or(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr i32, ptr %a, i64 %i
  %pb = getelementptr i32, ptr %b, i64 %i
  %pd = getelementptr i32, ptr %d, i64 %i
  %x = load i32, ptr %pa
  %y = load i32, ptr %pb
  %z = or i32 %x, %y
  store i32 %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define internal void @f_fsub(ptr noalias %d, ptr %a, ptr %b, i64 %n) noinline {
entry:
  %c0 = icmp sgt i64 %n, 0
  br i1 %c0, label %body, label %exit
body:
  %i = phi i64 [ 0, %entry ], [ %in, %body ]
  %pa = getelementptr float, ptr %a, i64 %i
  %pb = getelementptr float, ptr %b, i64 %i
  %pd = getelementptr float, ptr %d, i64 %i
  %x = load float, ptr %pa
  %y = load float, ptr %pb
  %z = fsub float %x, %y
  store float %z, ptr %pd
  %in = add nuw nsw i64 %i, 1
  %cm = icmp eq i64 %in, %n
  br i1 %cm, label %exit, label %body
exit:
  ret void
}

define i32 @test() {
entry:
  br label %init
init:
  %i = phi i64 [ 0, %entry ], [ %in, %init ]
  %pa = getelementptr i64, ptr @A, i64 %i
  %pb = getelementptr i64, ptr @B, i64 %i
  %m1 = mul i64 %i, 6364136223846793005
  %m2 = mul i64 %i, 1442695040888963407
  %va = xor i64 %m1, -4611686018427387904
  %vb = add i64 %m2, 99
  store volatile i64 %va, ptr %pa
  store volatile i64 %vb, ptr %pb
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, 64
  br i1 %c, label %init, label %run
run:
  call void @f_ssub(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_ssub(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 1)
  call void @f_ssub(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 9)
  call void @f_ssub(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 17)
  %ff_ssub = call i64 @fold()
  call void @f_uadd(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_uadd(ptr getelementptr (i8, ptr @D, i64 2), ptr getelementptr (i8, ptr @A, i64 1), ptr getelementptr (i8, ptr @B, i64 3), i64 1)
  call void @f_uadd(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 9)
  call void @f_uadd(ptr getelementptr (i8, ptr @D, i64 2), ptr getelementptr (i8, ptr @A, i64 1), ptr getelementptr (i8, ptr @B, i64 3), i64 17)
  %ff_uadd = call i64 @fold()
  call void @f_usub(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_usub(ptr getelementptr (i8, ptr @D, i64 2), ptr getelementptr (i8, ptr @A, i64 1), ptr getelementptr (i8, ptr @B, i64 3), i64 1)
  call void @f_usub(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 9)
  call void @f_usub(ptr getelementptr (i8, ptr @D, i64 2), ptr getelementptr (i8, ptr @A, i64 1), ptr getelementptr (i8, ptr @B, i64 3), i64 17)
  %ff_usub = call i64 @fold()
  call void @f_smax(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_smax(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 1)
  call void @f_smax(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 9)
  call void @f_smax(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 17)
  %ff_smax = call i64 @fold()
  call void @f_umin(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_umin(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 1)
  call void @f_umin(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 9)
  call void @f_umin(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 17)
  %ff_umin = call i64 @fold()
  call void @f_umax(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_umax(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 1)
  call void @f_umax(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 9)
  call void @f_umax(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 17)
  %ff_umax = call i64 @fold()
  call void @f_smin(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_smin(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 1)
  call void @f_smin(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 9)
  call void @f_smin(ptr getelementptr (i8, ptr @D, i64 4), ptr getelementptr (i8, ptr @A, i64 2), ptr getelementptr (i8, ptr @B, i64 6), i64 17)
  %ff_smin = call i64 @fold()
  call void @f_sub(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_sub(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 1)
  call void @f_sub(ptr getelementptr (i8, ptr @D, i64 32), ptr getelementptr (i8, ptr @A, i64 16), ptr getelementptr (i8, ptr @B, i64 48), i64 9)
  call void @f_sub(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 17)
  %ff_sub = call i64 @fold()
  call void @f_or(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_or(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 1)
  call void @f_or(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 9)
  call void @f_or(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 17)
  %ff_or = call i64 @fold()
  call void @f_fsub(ptr getelementptr (i8, ptr @D, i64 0), ptr getelementptr (i8, ptr @A, i64 0), ptr getelementptr (i8, ptr @B, i64 0), i64 0)
  call void @f_fsub(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 1)
  call void @f_fsub(ptr getelementptr (i8, ptr @D, i64 16), ptr getelementptr (i8, ptr @A, i64 8), ptr getelementptr (i8, ptr @B, i64 24), i64 9)
  call void @f_fsub(ptr getelementptr (i8, ptr @D, i64 8), ptr getelementptr (i8, ptr @A, i64 4), ptr getelementptr (i8, ptr @B, i64 12), i64 17)
  %ff_fsub = call i64 @fold()
  %s0 = add i64 0, 0
  %s1 = add i64 %s0, %ff_ssub
  %s2 = add i64 %s1, %ff_uadd
  %s3 = add i64 %s2, %ff_usub
  %s4 = add i64 %s3, %ff_smax
  %s5 = add i64 %s4, %ff_umin
  %s6 = add i64 %s5, %ff_umax
  %s7 = add i64 %s6, %ff_smin
  %s8 = add i64 %s7, %ff_sub
  %s9 = add i64 %s8, %ff_or
  %s10 = add i64 %s9, %ff_fsub
  %r = urem i64 %s10, 100003
  %rr = trunc i64 %r to i32
  ret i32 %rr
}
define internal i64 @fold() noinline {
entry:
  br label %l
l:
  %i = phi i64 [ 0, %entry ], [ %in, %l ]
  %s = phi i64 [ 0, %entry ], [ %sn, %l ]
  %p = getelementptr i64, ptr @D, i64 %i
  %v = load volatile i64, ptr %p
    %sn = add i64 %s, %v
  store volatile i64 0, ptr %p
  %in = add i64 %i, 1
  %in1 = add i64 %i, 3
  %c = icmp ult i64 %in, 64
  br i1 %c, label %l, label %x
x:
  ret i64 %sn
}
