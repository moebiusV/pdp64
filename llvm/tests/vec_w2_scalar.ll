; expect: 25009  -- wave 2: compare + select (int, unsigned, float with NaN, -0.0), conversions; scalar loops IR (clang -O2 -fno-vectorize)
; asm-vec: vcgt\.l
; asm-vec: vcgtu\.l
; asm-vec: vceq\.l
; asm-vec: vcgt\.w
; asm-vec: vcgtu\.b
; asm-vec: vcgt\.f
; asm-vec: vceq\.f
; asm-vec: vbsl
; asm-vec: vcvt\.l\.f
; asm-vec: vcvt\.lu\.f
; asm-vec: vcvt\.f\.l
; asm-vec: vcvt\.f\.lu
; asm-vec: vand\.l
; llc:
; llc: -pdp64-vecloop
; llc: -pdp64-vecloop -pdp64-vecloop-strip

@test.tab = internal unnamed_addr constant [8 x i32] [i32 2143289344, i32 0, i32 -2147483648, i32 1065353216, i32 -1082130432, i32 1075838976, i32 2139095040, i32 -8388608], align 16
@ia = dso_local global [96 x i32] zeroinitializer, align 16
@ib = dso_local global [96 x i32] zeroinitializer, align 16
@ua = dso_local global [96 x i32] zeroinitializer, align 16
@sa = dso_local global [96 x i16] zeroinitializer, align 16
@ba = dso_local global [96 x i8] zeroinitializer, align 16
@bb = dso_local global [96 x i8] zeroinitializer, align 16
@fa = dso_local global [96 x float] zeroinitializer, align 16
@fb = dso_local global [96 x float] zeroinitializer, align 16
@test.ns = internal unnamed_addr constant [7 x i32] [i32 0, i32 1, i32 7, i32 31, i32 32, i32 33, i32 90], align 16
@io = dso_local global [96 x i32] zeroinitializer, align 16
@uo = dso_local global [96 x i32] zeroinitializer, align 16
@so = dso_local global [96 x i16] zeroinitializer, align 16
@bo = dso_local global [96 x i8] zeroinitializer, align 16
@fo = dso_local global [96 x float] zeroinitializer, align 16
@lcg = internal unnamed_addr global i32 3, align 4

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_gt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1 = icmp sgt i32 %0, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_le(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp sgt i32 %0, %t
  %cond = select i1 %cmp1.not, i32 7, i32 100
  %arrayidx3 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_eq(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1 = icmp eq i32 %0, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_lt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds i32, ptr %b, i64 %indvars.iv
  %1 = load i32, ptr %arrayidx2, align 4
  %cmp3 = icmp slt i32 %0, %1
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @u_gt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1 = icmp ugt i32 %0, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @h_gt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i16 noundef signext %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %cmp2 = icmp sgt i16 %0, %t
  %conv4 = select i1 %cmp2, i16 1000, i16 -7
  %arrayidx6 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b_ugt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i8 noundef zeroext %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %cmp2 = icmp ugt i8 %0, %t
  %conv4 = select i1 %cmp2, i8 -56, i8 7
  %arrayidx6 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv4, ptr %arrayidx6, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b_ult(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp13 = icmp sgt i32 %n, 0
  br i1 %cmp13, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %cmp4 = icmp ult i8 %0, %1
  %conv6 = select i1 %cmp4, i8 -56, i8 7
  %arrayidx8 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv6, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @count(ptr nocapture noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.06 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1 = icmp sgt i32 %0, %t
  %conv = zext i1 %cmp1 to i32
  %add = add nuw nsw i32 %s.06, %conv
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_lt(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds float, ptr %b, i64 %indvars.iv
  %1 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp olt float %0, %1
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_nge(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds float, ptr %b, i64 %indvars.iv
  %1 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp ult float %0, %1
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_eq(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds float, ptr %b, i64 %indvars.iv
  %1 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp oeq float %0, %1
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_max(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp19 = icmp sgt i32 %n, 0
  br i1 %cmp19, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds float, ptr %b, i64 %indvars.iv
  %1 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp ogt float %0, %1
  %. = select i1 %cmp3, float %0, float %1
  %arrayidx9 = getelementptr inbounds float, ptr %c, i64 %indvars.iv
  store float %., ptr %arrayidx9, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @i2f(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %conv = sitofp i32 %0 to float
  %arrayidx2 = getelementptr inbounds float, ptr %c, i64 %indvars.iv
  store float %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @u2f(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %conv = uitofp i32 %0 to float
  %arrayidx2 = getelementptr inbounds float, ptr %c, i64 %indvars.iv
  store float %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f2i(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %conv = fptosi float %0 to i32
  %arrayidx2 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f2u(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds float, ptr %a, i64 %indvars.iv
  %0 = load float, ptr %arrayidx, align 4
  %conv = fptoui float %0 to i32
  %arrayidx2 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b2f(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv1 = uitofp i8 %0 to float
  %mul = fmul float %conv1, 0x3F70101020000000
  %arrayidx3 = getelementptr inbounds float, ptr %c, i64 %indvars.iv
  store float %mul, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none)
define dso_local range(i32 0, 100003) i32 @test() local_unnamed_addr #2 {
entry:
  %lcg.promoted = load i32, ptr @lcg, align 4
  br label %for.body

for.cond68.preheader:                             ; preds = %cond.end64
  store i32 %add.i, ptr @lcg, align 4
  br label %for.body72

for.body:                                         ; preds = %entry, %cond.end64
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %cond.end64 ]
  %add.i420421 = phi i32 [ %lcg.promoted, %entry ], [ %add.i, %cond.end64 ]
  %mul.i = mul i32 %add.i420421, 1103515245
  %add.i = add i32 %mul.i, 12345
  %shr.i = lshr i32 %add.i, 8
  %rem = urem i32 %shr.i, 21
  %sub = add nsw i32 %rem, -10
  %arrayidx = getelementptr inbounds [96 x i32], ptr @ia, i64 0, i64 %indvars.iv
  store i32 %sub, ptr %arrayidx, align 4
  %rem1.lhs.trunc = trunc i64 %indvars.iv to i8
  %rem1418 = urem i8 %rem1.lhs.trunc, 3
  %cmp2 = icmp eq i8 %rem1418, 0
  %.pre = lshr i32 %add.i, 13
  br i1 %cmp2, label %cond.end, label %cond.false

cond.false:                                       ; preds = %for.body
  %rem5 = urem i32 %.pre, 21
  %sub6 = add nsw i32 %rem5, -10
  br label %cond.end

cond.end:                                         ; preds = %for.body, %cond.false
  %cond = phi i32 [ %sub6, %cond.false ], [ %sub, %for.body ]
  %arrayidx8 = getelementptr inbounds [96 x i32], ptr @ib, i64 0, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx8, align 4
  %mul = mul nsw i32 %sub, 70000
  %arrayidx12 = getelementptr inbounds [96 x i32], ptr @ua, i64 0, i64 %indvars.iv
  store i32 %mul, ptr %arrayidx12, align 4
  %0 = trunc nsw i32 %sub to i16
  %conv = mul nsw i16 %0, 3000
  %arrayidx17 = getelementptr inbounds [96 x i16], ptr @sa, i64 0, i64 %indvars.iv
  store i16 %conv, ptr %arrayidx17, align 2
  %rem18442 = and i64 %indvars.iv, 3
  %cmp19 = icmp eq i64 %rem18442, 0
  %1 = trunc i32 %shr.i to i8
  %conv27 = select i1 %cmp19, i8 -1, i8 %1
  %arrayidx29 = getelementptr inbounds [96 x i8], ptr @ba, i64 0, i64 %indvars.iv
  store i8 %conv27, ptr %arrayidx29, align 1
  %conv36 = zext i8 %conv27 to i32
  %cond42 = select i1 %cmp2, i32 %conv36, i32 %.pre
  %conv43 = trunc i32 %cond42 to i8
  %arrayidx45 = getelementptr inbounds [96 x i8], ptr @bb, i64 0, i64 %indvars.iv
  store i8 %conv43, ptr %arrayidx45, align 1
  %rem46 = and i32 %shr.i, 7
  %idxprom47 = zext nneg i32 %rem46 to i64
  %arrayidx48 = getelementptr inbounds [8 x i32], ptr @test.tab, i64 0, i64 %idxprom47
  %2 = load float, ptr %arrayidx48, align 4
  %arrayidx51 = getelementptr inbounds [96 x float], ptr @fa, i64 0, i64 %indvars.iv
  store float %2, ptr %arrayidx51, align 4
  br i1 %cmp19, label %cond.end64, label %cond.false58

cond.false58:                                     ; preds = %cond.end
  %shr59 = lshr i32 %add.i, 14
  %rem60 = and i32 %shr59, 7
  %idxprom61 = zext nneg i32 %rem60 to i64
  %arrayidx62 = getelementptr inbounds [8 x i32], ptr @test.tab, i64 0, i64 %idxprom61
  %3 = load float, ptr %arrayidx62, align 4
  br label %cond.end64

cond.end64:                                       ; preds = %cond.end, %cond.false58
  %cond65 = phi float [ %3, %cond.false58 ], [ %2, %cond.end ]
  %arrayidx67 = getelementptr inbounds [96 x float], ptr @fb, i64 0, i64 %indvars.iv
  store float %cond65, ptr %arrayidx67, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 96
  br i1 %exitcond.not, label %for.cond68.preheader, label %for.body

for.body72:                                       ; preds = %for.cond68.preheader, %cs.exit397
  %indvars.iv434 = phi i64 [ 0, %for.cond68.preheader ], [ %indvars.iv.next435, %cs.exit397 ]
  %sum.0425 = phi i64 [ 0, %for.cond68.preheader ], [ %add141, %cs.exit397 ]
  %arrayidx74 = getelementptr inbounds [7 x i32], ptr @test.ns, i64 0, i64 %indvars.iv434
  %4 = load i32, ptr %arrayidx74, align 4
  br label %for.body80

for.cond.cleanup79:                               ; preds = %for.body80
  tail call void @s_gt(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef 2, i32 noundef %4) #3
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i, %for.cond.cleanup79
  %indvars.iv.i = phi i64 [ 0, %for.cond.cleanup79 ], [ %indvars.iv.next.i, %for.body.i ]
  %h.05.i = phi i64 [ 7, %for.cond.cleanup79 ], [ %add.i257, %for.body.i ]
  %mul.i256 = mul i64 %h.05.i, 31
  %arrayidx.i = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i
  %5 = load i8, ptr %arrayidx.i, align 1
  %conv.i = zext i8 %5 to i64
  %add.i257 = add i64 %mul.i256, %conv.i
  %indvars.iv.next.i = add nuw nsw i64 %indvars.iv.i, 1
  %exitcond.not.i = icmp eq i64 %indvars.iv.next.i, 384
  br i1 %exitcond.not.i, label %cs.exit, label %for.body.i

cs.exit:                                          ; preds = %for.body.i
  %mul94 = mul i64 %sum.0425, 3
  tail call void @s_le(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef -3, i32 noundef %4) #3
  br label %for.body.i258

for.body.i258:                                    ; preds = %for.body.i258, %cs.exit
  %indvars.iv.i259 = phi i64 [ 0, %cs.exit ], [ %indvars.iv.next.i265, %for.body.i258 ]
  %h.05.i260 = phi i64 [ 7, %cs.exit ], [ %add.i264, %for.body.i258 ]
  %mul.i261 = mul i64 %h.05.i260, 31
  %arrayidx.i262 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i259
  %6 = load i8, ptr %arrayidx.i262, align 1
  %conv.i263 = zext i8 %6 to i64
  %add.i264 = add i64 %mul.i261, %conv.i263
  %indvars.iv.next.i265 = add nuw nsw i64 %indvars.iv.i259, 1
  %exitcond.not.i266 = icmp eq i64 %indvars.iv.next.i265, 384
  br i1 %exitcond.not.i266, label %cs.exit267, label %for.body.i258

cs.exit267:                                       ; preds = %for.body.i258
  %add = add i64 %add.i257, %mul94
  %mul96 = mul i64 %add, 3
  tail call void @s_eq(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef 0, i32 noundef %4) #3
  br label %for.body.i268

for.body.i268:                                    ; preds = %for.body.i268, %cs.exit267
  %indvars.iv.i269 = phi i64 [ 0, %cs.exit267 ], [ %indvars.iv.next.i275, %for.body.i268 ]
  %h.05.i270 = phi i64 [ 7, %cs.exit267 ], [ %add.i274, %for.body.i268 ]
  %mul.i271 = mul i64 %h.05.i270, 31
  %arrayidx.i272 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i269
  %7 = load i8, ptr %arrayidx.i272, align 1
  %conv.i273 = zext i8 %7 to i64
  %add.i274 = add i64 %mul.i271, %conv.i273
  %indvars.iv.next.i275 = add nuw nsw i64 %indvars.iv.i269, 1
  %exitcond.not.i276 = icmp eq i64 %indvars.iv.next.i275, 384
  br i1 %exitcond.not.i276, label %cs.exit277, label %for.body.i268

cs.exit277:                                       ; preds = %for.body.i268
  %add98 = add i64 %add.i264, %mul96
  %mul99 = mul i64 %add98, 3
  tail call void @s_lt(ptr noundef nonnull @io, ptr noundef nonnull @ia, ptr noundef nonnull getelementptr inbounds (i8, ptr @ib, i64 4), i32 noundef %4) #3
  br label %for.body.i278

for.body.i278:                                    ; preds = %for.body.i278, %cs.exit277
  %indvars.iv.i279 = phi i64 [ 0, %cs.exit277 ], [ %indvars.iv.next.i285, %for.body.i278 ]
  %h.05.i280 = phi i64 [ 7, %cs.exit277 ], [ %add.i284, %for.body.i278 ]
  %mul.i281 = mul i64 %h.05.i280, 31
  %arrayidx.i282 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i279
  %8 = load i8, ptr %arrayidx.i282, align 1
  %conv.i283 = zext i8 %8 to i64
  %add.i284 = add i64 %mul.i281, %conv.i283
  %indvars.iv.next.i285 = add nuw nsw i64 %indvars.iv.i279, 1
  %exitcond.not.i286 = icmp eq i64 %indvars.iv.next.i285, 384
  br i1 %exitcond.not.i286, label %cs.exit287, label %for.body.i278

cs.exit287:                                       ; preds = %for.body.i278
  %add101 = add i64 %add.i274, %mul99
  %mul102 = mul i64 %add101, 3
  tail call void @u_gt(ptr noundef nonnull @uo, ptr noundef nonnull @ua, i32 noundef -2147483648, i32 noundef %4) #3
  br label %for.body.i288

for.body.i288:                                    ; preds = %for.body.i288, %cs.exit287
  %indvars.iv.i289 = phi i64 [ 0, %cs.exit287 ], [ %indvars.iv.next.i295, %for.body.i288 ]
  %h.05.i290 = phi i64 [ 7, %cs.exit287 ], [ %add.i294, %for.body.i288 ]
  %mul.i291 = mul i64 %h.05.i290, 31
  %arrayidx.i292 = getelementptr inbounds i8, ptr @uo, i64 %indvars.iv.i289
  %9 = load i8, ptr %arrayidx.i292, align 1
  %conv.i293 = zext i8 %9 to i64
  %add.i294 = add i64 %mul.i291, %conv.i293
  %indvars.iv.next.i295 = add nuw nsw i64 %indvars.iv.i289, 1
  %exitcond.not.i296 = icmp eq i64 %indvars.iv.next.i295, 384
  br i1 %exitcond.not.i296, label %cs.exit297, label %for.body.i288

cs.exit297:                                       ; preds = %for.body.i288
  %add104 = add i64 %add.i284, %mul102
  %mul105 = mul i64 %add104, 3
  tail call void @h_gt(ptr noundef nonnull @so, ptr noundef nonnull @sa, i16 noundef signext 3, i32 noundef %4) #3
  br label %for.body.i298

for.body.i298:                                    ; preds = %for.body.i298, %cs.exit297
  %indvars.iv.i299 = phi i64 [ 0, %cs.exit297 ], [ %indvars.iv.next.i305, %for.body.i298 ]
  %h.05.i300 = phi i64 [ 7, %cs.exit297 ], [ %add.i304, %for.body.i298 ]
  %mul.i301 = mul i64 %h.05.i300, 31
  %arrayidx.i302 = getelementptr inbounds i8, ptr @so, i64 %indvars.iv.i299
  %10 = load i8, ptr %arrayidx.i302, align 1
  %conv.i303 = zext i8 %10 to i64
  %add.i304 = add i64 %mul.i301, %conv.i303
  %indvars.iv.next.i305 = add nuw nsw i64 %indvars.iv.i299, 1
  %exitcond.not.i306 = icmp eq i64 %indvars.iv.next.i305, 192
  br i1 %exitcond.not.i306, label %cs.exit307, label %for.body.i298

cs.exit307:                                       ; preds = %for.body.i298
  %add107 = add i64 %add.i294, %mul105
  %mul108 = mul i64 %add107, 3
  tail call void @b_ugt(ptr noundef nonnull @bo, ptr noundef nonnull @ba, i8 noundef zeroext -2, i32 noundef %4) #3
  br label %for.body.i308

for.body.i308:                                    ; preds = %for.body.i308, %cs.exit307
  %indvars.iv.i309 = phi i64 [ 0, %cs.exit307 ], [ %indvars.iv.next.i315, %for.body.i308 ]
  %h.05.i310 = phi i64 [ 7, %cs.exit307 ], [ %add.i314, %for.body.i308 ]
  %mul.i311 = mul i64 %h.05.i310, 31
  %arrayidx.i312 = getelementptr inbounds i8, ptr @bo, i64 %indvars.iv.i309
  %11 = load i8, ptr %arrayidx.i312, align 1
  %conv.i313 = zext i8 %11 to i64
  %add.i314 = add i64 %mul.i311, %conv.i313
  %indvars.iv.next.i315 = add nuw nsw i64 %indvars.iv.i309, 1
  %exitcond.not.i316 = icmp eq i64 %indvars.iv.next.i315, 96
  br i1 %exitcond.not.i316, label %cs.exit317, label %for.body.i308

cs.exit317:                                       ; preds = %for.body.i308
  %add110 = add i64 %add.i304, %mul108
  %mul111 = mul i64 %add110, 3
  tail call void @b_ult(ptr noundef nonnull @bo, ptr noundef nonnull @ba, ptr noundef nonnull getelementptr inbounds (i8, ptr @bb, i64 1), i32 noundef %4) #3
  br label %for.body.i318

for.body.i318:                                    ; preds = %for.body.i318, %cs.exit317
  %indvars.iv.i319 = phi i64 [ 0, %cs.exit317 ], [ %indvars.iv.next.i325, %for.body.i318 ]
  %h.05.i320 = phi i64 [ 7, %cs.exit317 ], [ %add.i324, %for.body.i318 ]
  %mul.i321 = mul i64 %h.05.i320, 31
  %arrayidx.i322 = getelementptr inbounds i8, ptr @bo, i64 %indvars.iv.i319
  %12 = load i8, ptr %arrayidx.i322, align 1
  %conv.i323 = zext i8 %12 to i64
  %add.i324 = add i64 %mul.i321, %conv.i323
  %indvars.iv.next.i325 = add nuw nsw i64 %indvars.iv.i319, 1
  %exitcond.not.i326 = icmp eq i64 %indvars.iv.next.i325, 96
  br i1 %exitcond.not.i326, label %cs.exit327, label %for.body.i318

cs.exit327:                                       ; preds = %for.body.i318
  %add113 = add i64 %add.i314, %mul111
  %mul114 = mul i64 %add113, 3
  %add116 = add i64 %add.i324, %mul114
  %call118 = tail call i32 @count(ptr noundef nonnull @ia, i32 noundef 1, i32 noundef %4) #3
  %conv119 = zext i32 %call118 to i64
  tail call void @f_lt(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds (i8, ptr @fb, i64 4), i32 noundef %4) #3
  br label %for.body.i328

for.body.i328:                                    ; preds = %for.body.i328, %cs.exit327
  %indvars.iv.i329 = phi i64 [ 0, %cs.exit327 ], [ %indvars.iv.next.i335, %for.body.i328 ]
  %h.05.i330 = phi i64 [ 7, %cs.exit327 ], [ %add.i334, %for.body.i328 ]
  %mul.i331 = mul i64 %h.05.i330, 31
  %arrayidx.i332 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i329
  %13 = load i8, ptr %arrayidx.i332, align 1
  %conv.i333 = zext i8 %13 to i64
  %add.i334 = add i64 %mul.i331, %conv.i333
  %indvars.iv.next.i335 = add nuw nsw i64 %indvars.iv.i329, 1
  %exitcond.not.i336 = icmp eq i64 %indvars.iv.next.i335, 384
  br i1 %exitcond.not.i336, label %cs.exit337, label %for.body.i328

cs.exit337:                                       ; preds = %for.body.i328
  %mul117 = mul i64 %add116, 3
  %add120 = add i64 %mul117, %conv119
  %mul121 = mul i64 %add120, 3
  tail call void @f_nge(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds (i8, ptr @fb, i64 4), i32 noundef %4) #3
  br label %for.body.i338

for.body.i338:                                    ; preds = %for.body.i338, %cs.exit337
  %indvars.iv.i339 = phi i64 [ 0, %cs.exit337 ], [ %indvars.iv.next.i345, %for.body.i338 ]
  %h.05.i340 = phi i64 [ 7, %cs.exit337 ], [ %add.i344, %for.body.i338 ]
  %mul.i341 = mul i64 %h.05.i340, 31
  %arrayidx.i342 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i339
  %14 = load i8, ptr %arrayidx.i342, align 1
  %conv.i343 = zext i8 %14 to i64
  %add.i344 = add i64 %mul.i341, %conv.i343
  %indvars.iv.next.i345 = add nuw nsw i64 %indvars.iv.i339, 1
  %exitcond.not.i346 = icmp eq i64 %indvars.iv.next.i345, 384
  br i1 %exitcond.not.i346, label %cs.exit347, label %for.body.i338

cs.exit347:                                       ; preds = %for.body.i338
  %add123 = add i64 %add.i334, %mul121
  %mul124 = mul i64 %add123, 3
  tail call void @f_eq(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds (i8, ptr @fb, i64 4), i32 noundef %4) #3
  br label %for.body.i348

for.body.i348:                                    ; preds = %for.body.i348, %cs.exit347
  %indvars.iv.i349 = phi i64 [ 0, %cs.exit347 ], [ %indvars.iv.next.i355, %for.body.i348 ]
  %h.05.i350 = phi i64 [ 7, %cs.exit347 ], [ %add.i354, %for.body.i348 ]
  %mul.i351 = mul i64 %h.05.i350, 31
  %arrayidx.i352 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i349
  %15 = load i8, ptr %arrayidx.i352, align 1
  %conv.i353 = zext i8 %15 to i64
  %add.i354 = add i64 %mul.i351, %conv.i353
  %indvars.iv.next.i355 = add nuw nsw i64 %indvars.iv.i349, 1
  %exitcond.not.i356 = icmp eq i64 %indvars.iv.next.i355, 384
  br i1 %exitcond.not.i356, label %cs.exit357, label %for.body.i348

cs.exit357:                                       ; preds = %for.body.i348
  %add126 = add i64 %add.i344, %mul124
  %mul127 = mul i64 %add126, 3
  tail call void @f_max(ptr noundef nonnull @fo, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds (i8, ptr @fb, i64 4), i32 noundef %4) #3
  br label %for.body.i358

for.body.i358:                                    ; preds = %for.body.i358, %cs.exit357
  %indvars.iv.i359 = phi i64 [ 0, %cs.exit357 ], [ %indvars.iv.next.i365, %for.body.i358 ]
  %h.05.i360 = phi i64 [ 7, %cs.exit357 ], [ %add.i364, %for.body.i358 ]
  %mul.i361 = mul i64 %h.05.i360, 31
  %arrayidx.i362 = getelementptr inbounds i8, ptr @fo, i64 %indvars.iv.i359
  %16 = load i8, ptr %arrayidx.i362, align 1
  %conv.i363 = zext i8 %16 to i64
  %add.i364 = add i64 %mul.i361, %conv.i363
  %indvars.iv.next.i365 = add nuw nsw i64 %indvars.iv.i359, 1
  %exitcond.not.i366 = icmp eq i64 %indvars.iv.next.i365, 384
  br i1 %exitcond.not.i366, label %cs.exit367, label %for.body.i358

cs.exit367:                                       ; preds = %for.body.i358
  %add129 = add i64 %add.i354, %mul127
  %mul130 = mul i64 %add129, 3
  tail call void @i2f(ptr noundef nonnull @fo, ptr noundef nonnull @ia, i32 noundef %4) #3
  br label %for.body.i368

for.body.i368:                                    ; preds = %for.body.i368, %cs.exit367
  %indvars.iv.i369 = phi i64 [ 0, %cs.exit367 ], [ %indvars.iv.next.i375, %for.body.i368 ]
  %h.05.i370 = phi i64 [ 7, %cs.exit367 ], [ %add.i374, %for.body.i368 ]
  %mul.i371 = mul i64 %h.05.i370, 31
  %arrayidx.i372 = getelementptr inbounds i8, ptr @fo, i64 %indvars.iv.i369
  %17 = load i8, ptr %arrayidx.i372, align 1
  %conv.i373 = zext i8 %17 to i64
  %add.i374 = add i64 %mul.i371, %conv.i373
  %indvars.iv.next.i375 = add nuw nsw i64 %indvars.iv.i369, 1
  %exitcond.not.i376 = icmp eq i64 %indvars.iv.next.i375, 384
  br i1 %exitcond.not.i376, label %cs.exit377, label %for.body.i368

cs.exit377:                                       ; preds = %for.body.i368
  %add132 = add i64 %add.i364, %mul130
  %mul133 = mul i64 %add132, 3
  tail call void @u2f(ptr noundef nonnull @fo, ptr noundef nonnull @ua, i32 noundef %4) #3
  br label %for.body.i378

for.body.i378:                                    ; preds = %for.body.i378, %cs.exit377
  %indvars.iv.i379 = phi i64 [ 0, %cs.exit377 ], [ %indvars.iv.next.i385, %for.body.i378 ]
  %h.05.i380 = phi i64 [ 7, %cs.exit377 ], [ %add.i384, %for.body.i378 ]
  %mul.i381 = mul i64 %h.05.i380, 31
  %arrayidx.i382 = getelementptr inbounds i8, ptr @fo, i64 %indvars.iv.i379
  %18 = load i8, ptr %arrayidx.i382, align 1
  %conv.i383 = zext i8 %18 to i64
  %add.i384 = add i64 %mul.i381, %conv.i383
  %indvars.iv.next.i385 = add nuw nsw i64 %indvars.iv.i379, 1
  %exitcond.not.i386 = icmp eq i64 %indvars.iv.next.i385, 384
  br i1 %exitcond.not.i386, label %cs.exit387, label %for.body.i378

cs.exit387:                                       ; preds = %for.body.i378
  %add135 = add i64 %add.i374, %mul133
  %mul136 = mul i64 %add135, 3
  tail call void @b2f(ptr noundef nonnull @fo, ptr noundef nonnull @ba, i32 noundef %4) #3
  br label %for.body.i388

for.body.i388:                                    ; preds = %for.body.i388, %cs.exit387
  %indvars.iv.i389 = phi i64 [ 0, %cs.exit387 ], [ %indvars.iv.next.i395, %for.body.i388 ]
  %h.05.i390 = phi i64 [ 7, %cs.exit387 ], [ %add.i394, %for.body.i388 ]
  %mul.i391 = mul i64 %h.05.i390, 31
  %arrayidx.i392 = getelementptr inbounds i8, ptr @fo, i64 %indvars.iv.i389
  %19 = load i8, ptr %arrayidx.i392, align 1
  %conv.i393 = zext i8 %19 to i64
  %add.i394 = add i64 %mul.i391, %conv.i393
  %indvars.iv.next.i395 = add nuw nsw i64 %indvars.iv.i389, 1
  %exitcond.not.i396 = icmp eq i64 %indvars.iv.next.i395, 384
  br i1 %exitcond.not.i396, label %cs.exit397, label %for.body.i388

cs.exit397:                                       ; preds = %for.body.i388
  %add138 = add i64 %add.i384, %mul136
  %mul139 = mul i64 %add138, 3
  %add141 = add i64 %add.i394, %mul139
  %indvars.iv.next435 = add nuw nsw i64 %indvars.iv434, 1
  %exitcond437.not = icmp eq i64 %indvars.iv.next435, 7
  br i1 %exitcond437.not, label %for.body150, label %for.body72

for.body80:                                       ; preds = %for.body72, %for.body80
  %indvars.iv430 = phi i64 [ 0, %for.body72 ], [ %indvars.iv.next431, %for.body80 ]
  %arrayidx82 = getelementptr inbounds [96 x i32], ptr @io, i64 0, i64 %indvars.iv430
  store i32 55, ptr %arrayidx82, align 4
  %arrayidx84 = getelementptr inbounds [96 x i32], ptr @uo, i64 0, i64 %indvars.iv430
  store i32 66, ptr %arrayidx84, align 4
  %arrayidx86 = getelementptr inbounds [96 x i16], ptr @so, i64 0, i64 %indvars.iv430
  store i16 77, ptr %arrayidx86, align 2
  %arrayidx88 = getelementptr inbounds [96 x i8], ptr @bo, i64 0, i64 %indvars.iv430
  store i8 88, ptr %arrayidx88, align 1
  %arrayidx90 = getelementptr inbounds [96 x float], ptr @fo, i64 0, i64 %indvars.iv430
  store float 1.500000e+00, ptr %arrayidx90, align 4
  %indvars.iv.next431 = add nuw nsw i64 %indvars.iv430, 1
  %exitcond433.not = icmp eq i64 %indvars.iv.next431, 96
  br i1 %exitcond433.not, label %for.cond.cleanup79, label %for.body80

for.body150:                                      ; preds = %cs.exit397, %for.body150
  %indvars.iv438 = phi i64 [ %indvars.iv.next439, %for.body150 ], [ 0, %cs.exit397 ]
  %20 = trunc i64 %indvars.iv438 to i16
  %rem152.lhs.trunc = mul nuw nsw i16 %20, 37
  %rem152419 = urem i16 %rem152.lhs.trunc, 200
  %rem152.zext = zext nneg i16 %rem152419 to i32
  %sub153 = add nsw i32 %rem152.zext, -100
  %conv154 = sitofp i32 %sub153 to float
  %mul155 = fmul float %conv154, 0x3FF4CCCCC0000000
  %arrayidx157 = getelementptr inbounds [96 x float], ptr @fa, i64 0, i64 %indvars.iv438
  store float %mul155, ptr %arrayidx157, align 4
  %conv160 = uitofp nneg i16 %rem152419 to float
  %mul161 = fmul float %conv160, 0x3FF4CCCCC0000000
  %arrayidx163 = getelementptr inbounds [96 x float], ptr @fb, i64 0, i64 %indvars.iv438
  store float %mul161, ptr %arrayidx163, align 4
  %indvars.iv.next439 = add nuw nsw i64 %indvars.iv438, 1
  %exitcond441.not = icmp eq i64 %indvars.iv.next439, 96
  br i1 %exitcond441.not, label %for.body172, label %for.body150

for.cond.cleanup171:                              ; preds = %cs.exit417
  %rem182 = urem i64 %add178, 100003
  %conv183 = trunc nuw nsw i64 %rem182 to i32
  ret i32 %conv183

for.body172:                                      ; preds = %for.body150, %cs.exit417
  %n167.0428 = phi i32 [ %add180, %cs.exit417 ], [ 0, %for.body150 ]
  %sum.1427 = phi i64 [ %add178, %cs.exit417 ], [ %add141, %for.body150 ]
  tail call void @f2i(ptr noundef nonnull @io, ptr noundef nonnull @fa, i32 noundef %n167.0428) #3
  br label %for.body.i398

for.body.i398:                                    ; preds = %for.body.i398, %for.body172
  %indvars.iv.i399 = phi i64 [ 0, %for.body172 ], [ %indvars.iv.next.i405, %for.body.i398 ]
  %h.05.i400 = phi i64 [ 7, %for.body172 ], [ %add.i404, %for.body.i398 ]
  %mul.i401 = mul i64 %h.05.i400, 31
  %arrayidx.i402 = getelementptr inbounds i8, ptr @io, i64 %indvars.iv.i399
  %21 = load i8, ptr %arrayidx.i402, align 1
  %conv.i403 = zext i8 %21 to i64
  %add.i404 = add i64 %mul.i401, %conv.i403
  %indvars.iv.next.i405 = add nuw nsw i64 %indvars.iv.i399, 1
  %exitcond.not.i406 = icmp eq i64 %indvars.iv.next.i405, 384
  br i1 %exitcond.not.i406, label %cs.exit407, label %for.body.i398

cs.exit407:                                       ; preds = %for.body.i398
  %mul173 = mul i64 %sum.1427, 3
  tail call void @f2u(ptr noundef nonnull @uo, ptr noundef nonnull getelementptr inbounds (i8, ptr @fb, i64 160), i32 noundef %n167.0428) #3
  br label %for.body.i408

for.body.i408:                                    ; preds = %for.body.i408, %cs.exit407
  %indvars.iv.i409 = phi i64 [ 0, %cs.exit407 ], [ %indvars.iv.next.i415, %for.body.i408 ]
  %h.05.i410 = phi i64 [ 7, %cs.exit407 ], [ %add.i414, %for.body.i408 ]
  %mul.i411 = mul i64 %h.05.i410, 31
  %arrayidx.i412 = getelementptr inbounds i8, ptr @uo, i64 %indvars.iv.i409
  %22 = load i8, ptr %arrayidx.i412, align 1
  %conv.i413 = zext i8 %22 to i64
  %add.i414 = add i64 %mul.i411, %conv.i413
  %indvars.iv.next.i415 = add nuw nsw i64 %indvars.iv.i409, 1
  %exitcond.not.i416 = icmp eq i64 %indvars.iv.next.i415, 384
  br i1 %exitcond.not.i416, label %cs.exit417, label %for.body.i408

cs.exit417:                                       ; preds = %for.body.i408
  %add175 = add i64 %add.i404, %mul173
  %mul176 = mul i64 %add175, 3
  %add178 = add i64 %add.i414, %mul176
  %add180 = add nuw nsw i32 %n167.0428, 13
  %cmp169 = icmp ult i32 %n167.0428, 27
  br i1 %cmp169, label %for.body172, label %for.cond.cleanup171
}

attributes #0 = { nofree noinline norecurse nosync nounwind memory(argmem: readwrite) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #1 = { nofree noinline norecurse nosync nounwind memory(argmem: read) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #2 = { nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #3 = { nobuiltin "no-builtins" }

