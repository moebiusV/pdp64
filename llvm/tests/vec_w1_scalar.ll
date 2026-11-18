; expect: 50007  -- wave 1: avg, mulh, mulhr (Q15 saturating), vdacc, vsad, rounding shifts and stores, vmla; scalar loops IR (clang -O2 -fno-vectorize)
; asm-vec: vavgu\.b
; asm-vec: vavg\.b
; asm-vec: vavg\.w
; asm-vec: vmulh\.w
; asm-vec: vmulhu\.w
; asm-vec: vmulhr\.w
; asm-vec: vdacc\.b
; asm-vec: vdacc\.bu
; asm-vec: vdacc\.bsu
; asm-vec: vdacc\.w
; asm-vec: vsad\.bu
; asm-vec: vsarr\.w
; asm-vec: vsarr\.l
; asm-vec: vshrr\.w
; asm-vec: vsts\.l\.b
; asm-vec: vsts\.l\.bu
; asm-vec: vmla\.l
; asm-vec: vmla\.w
; llc:
; llc: -pdp64-vecloop
; llc: -pdp64-vecloop -pdp64-vecloop-strip

@ua = dso_local global [96 x i8] zeroinitializer, align 16
@ub = dso_local global [96 x i8] zeroinitializer, align 16
@sa8 = dso_local global [96 x i8] zeroinitializer, align 16
@sb8 = dso_local global [96 x i8] zeroinitializer, align 16
@ha = dso_local global [96 x i16] zeroinitializer, align 16
@hb = dso_local global [96 x i16] zeroinitializer, align 16
@sa = dso_local global [96 x i16] zeroinitializer, align 16
@sb = dso_local global [96 x i16] zeroinitializer, align 16
@ia = dso_local global [96 x i32] zeroinitializer, align 16
@test.ns = internal unnamed_addr constant [7 x i32] [i32 0, i32 1, i32 7, i32 31, i32 32, i32 33, i32 90], align 16
@uc = dso_local global [96 x i8] zeroinitializer, align 16
@sc8 = dso_local global [96 x i8] zeroinitializer, align 16
@sc = dso_local global [96 x i16] zeroinitializer, align 16
@hc = dso_local global [96 x i16] zeroinitializer, align 16
@ic = dso_local global [96 x i32] zeroinitializer, align 16
@ob = dso_local global [96 x i8] zeroinitializer, align 16
@lcg = internal unnamed_addr global i32 3, align 4

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @avgu(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp12 = icmp sgt i32 %n, 0
  br i1 %cmp12, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %0 to i16
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %1 to i16
  %add = add nuw nsw i16 %conv, 1
  %add4 = add nuw nsw i16 %add, %conv3
  %shr = lshr i16 %add4, 1
  %conv5 = trunc nuw i16 %shr to i8
  %arrayidx7 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv5, ptr %arrayidx7, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @avgs(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp12 = icmp sgt i32 %n, 0
  br i1 %cmp12, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %0 to i16
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = sext i8 %1 to i16
  %add = add nsw i16 %conv, 1
  %add4 = add nsw i16 %add, %conv3
  %shr = lshr i16 %add4, 1
  %conv5 = trunc i16 %shr to i8
  %arrayidx7 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv5, ptr %arrayidx7, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @avgsw(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp12 = icmp sgt i32 %n, 0
  br i1 %cmp12, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %0 to i32
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %1 to i32
  %add = add nsw i32 %conv, 1
  %add4 = add nsw i32 %add, %conv3
  %shr = lshr i32 %add4, 1
  %conv5 = trunc i32 %shr to i16
  %arrayidx7 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv5, ptr %arrayidx7, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mulh(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp11 = icmp sgt i32 %n, 0
  br i1 %cmp11, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %0 to i32
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %1 to i32
  %mul = mul nsw i32 %conv3, %conv
  %shr = lshr i32 %mul, 16
  %conv4 = trunc nuw i32 %shr to i16
  %arrayidx6 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mulhu(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp11 = icmp sgt i32 %n, 0
  br i1 %cmp11, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = zext i16 %0 to i32
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %conv3 = zext i16 %1 to i32
  %mul = mul nuw i32 %conv3, %conv
  %shr = lshr i32 %mul, 16
  %conv4 = trunc nuw i32 %shr to i16
  %arrayidx6 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @q15(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp14 = icmp sgt i32 %n, 0
  br i1 %cmp14, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %0 to i32
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %1 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, 16384
  %shr = ashr i32 %add, 15
  %cond = tail call i32 @llvm.smin.i32(i32 %shr, i32 32767)
  %conv6 = trunc nsw i32 %cond to i16
  %arrayidx8 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv6, ptr %arrayidx8, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8(ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.09 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %0 to i32
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = sext i8 %1 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.09
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8u(ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.09 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %0 to i32
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %1 to i32
  %mul = mul nuw nsw i32 %conv3, %conv
  %add = add i32 %mul, %s.09
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8su(ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.09 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %0 to i32
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %1 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.09
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot16(ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.09 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %0 to i32
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %1 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.09
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @sad(ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %s.09 = phi i32 [ 0, %for.body.preheader ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i8, ptr %a, i64 %indvars.iv
  %0 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %0 to i32
  %arrayidx2 = getelementptr inbounds i8, ptr %b, i64 %indvars.iv
  %1 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %1 to i32
  %sub = sub nsw i32 %conv, %conv3
  %2 = tail call i32 @llvm.abs.i32(i32 %sub, i1 true)
  %add = add i32 %2, %s.09
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.abs.i32(i32, i1 immarg) #2

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rsh16(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
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
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %0 to i32
  %add = add nsw i32 %conv, 8
  %shr = lshr i32 %add, 4
  %conv1 = trunc i32 %shr to i16
  %arrayidx3 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv1, ptr %arrayidx3, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rshu16(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
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
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %conv = zext i16 %0 to i32
  %add = add nuw nsw i32 %conv, 4
  %shr = lshr i32 %add, 3
  %conv1 = trunc nuw nsw i32 %shr to i16
  %arrayidx3 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %conv1, ptr %arrayidx3, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rsh32(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
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
  %add = add nsw i32 %0, 32
  %shr = ashr i32 %add, 6
  %arrayidx2 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %shr, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @qs8(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp14 = icmp sgt i32 %n, 0
  br i1 %cmp14, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %add = add nsw i32 %0, 128
  %shr = ashr i32 %add, 8
  %cond = tail call i32 @llvm.smin.i32(i32 %shr, i32 127)
  %cond6 = tail call i32 @llvm.smax.i32(i32 %cond, i32 -128)
  %conv = trunc nsw i32 %cond6 to i8
  %arrayidx8 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @qu8(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp14 = icmp sgt i32 %n, 0
  br i1 %cmp14, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %add = add nsw i32 %0, 32
  %shr = ashr i32 %add, 6
  %cond = tail call i32 @llvm.smin.i32(i32 %shr, i32 255)
  %cond6 = tail call i32 @llvm.smax.i32(i32 %cond, i32 0)
  %conv = trunc nuw i32 %cond6 to i8
  %arrayidx8 = getelementptr inbounds i8, ptr %c, i64 %indvars.iv
  store i8 %conv, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mla(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, ptr nocapture noundef readonly %d, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp12 = icmp sgt i32 %n, 0
  br i1 %cmp12, label %for.body.preheader, label %for.cond.cleanup

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
  %mul = mul i32 %1, %0
  %arrayidx4 = getelementptr inbounds i32, ptr %d, i64 %indvars.iv
  %2 = load i32, ptr %arrayidx4, align 4
  %add = add i32 %mul, %2
  %arrayidx6 = getelementptr inbounds i32, ptr %c, i64 %indvars.iv
  store i32 %add, ptr %arrayidx6, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mlaw(ptr nocapture noundef writeonly %c, ptr nocapture noundef readonly %a, ptr nocapture noundef readonly %b, ptr nocapture noundef readonly %d, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp15 = icmp sgt i32 %n, 0
  br i1 %cmp15, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext nneg i32 %n to i64
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ 0, %for.body.preheader ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i16, ptr %a, i64 %indvars.iv
  %0 = load i16, ptr %arrayidx, align 2
  %arrayidx2 = getelementptr inbounds i16, ptr %b, i64 %indvars.iv
  %1 = load i16, ptr %arrayidx2, align 2
  %mul = mul i16 %1, %0
  %arrayidx5 = getelementptr inbounds i16, ptr %d, i64 %indvars.iv
  %2 = load i16, ptr %arrayidx5, align 2
  %add = add i16 %mul, %2
  %arrayidx9 = getelementptr inbounds i16, ptr %c, i64 %indvars.iv
  store i16 %add, ptr %arrayidx9, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none)
define dso_local range(i32 0, 100003) i32 @test() local_unnamed_addr #3 {
entry:
  %lcg.promoted = load i32, ptr @lcg, align 4
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  store i32 %add.i, ptr @lcg, align 4
  store i16 -6, ptr getelementptr inbounds (i8, ptr @ha, i64 18), align 2
  store i16 32759, ptr getelementptr inbounds (i8, ptr @sa, i64 16), align 16
  br label %for.body98

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %add.i341342 = phi i32 [ %lcg.promoted, %entry ], [ %add.i, %for.body ]
  %mul.i = mul i32 %add.i341342, 1103515245
  %add.i = add i32 %mul.i, 12345
  %shr.i = lshr i32 %add.i, 8
  %rem351 = and i64 %indvars.iv, 3
  %cmp1 = icmp eq i64 %rem351, 0
  %0 = trunc i32 %shr.i to i8
  %conv3 = select i1 %cmp1, i8 -1, i8 %0
  %arrayidx = getelementptr inbounds [96 x i8], ptr @ua, i64 0, i64 %indvars.iv
  store i8 %conv3, ptr %arrayidx, align 1
  %rem4.lhs.trunc = trunc i64 %indvars.iv to i8
  %rem4340 = urem i8 %rem4.lhs.trunc, 3
  %cmp5 = icmp eq i8 %rem4340, 0
  %shr = lshr i32 %add.i, 13
  %1 = trunc i32 %shr to i8
  %conv13 = select i1 %cmp5, i8 0, i8 %1
  %arrayidx15 = getelementptr inbounds [96 x i8], ptr @ub, i64 0, i64 %indvars.iv
  store i8 %conv13, ptr %arrayidx15, align 1
  %conv25 = select i1 %cmp1, i8 127, i8 %0
  %arrayidx27 = getelementptr inbounds [96 x i8], ptr @sa8, i64 0, i64 %indvars.iv
  store i8 %conv25, ptr %arrayidx27, align 1
  %conv38 = select i1 %cmp5, i8 -128, i8 %1
  %arrayidx40 = getelementptr inbounds [96 x i8], ptr @sb8, i64 0, i64 %indvars.iv
  store i8 %conv38, ptr %arrayidx40, align 1
  %2 = trunc i32 %shr.i to i16
  %conv50 = select i1 %cmp1, i16 -1, i16 %2
  %arrayidx52 = getelementptr inbounds [96 x i16], ptr @ha, i64 0, i64 %indvars.iv
  store i16 %conv50, ptr %arrayidx52, align 2
  %3 = trunc i32 %shr to i16
  %conv63 = select i1 %cmp5, i16 1, i16 %3
  %arrayidx65 = getelementptr inbounds [96 x i16], ptr @hb, i64 0, i64 %indvars.iv
  store i16 %conv63, ptr %arrayidx65, align 2
  %conv75 = select i1 %cmp1, i16 -32768, i16 %2
  %arrayidx77 = getelementptr inbounds [96 x i16], ptr @sa, i64 0, i64 %indvars.iv
  store i16 %conv75, ptr %arrayidx77, align 2
  %4 = lshr i32 %add.i, 11
  %5 = trunc i32 %4 to i16
  %conv88 = select i1 %cmp5, i16 -32768, i16 %5
  %arrayidx90 = getelementptr inbounds [96 x i16], ptr @sb, i64 0, i64 %indvars.iv
  store i16 %conv88, ptr %arrayidx90, align 2
  %rem91 = urem i32 %shr.i, 100000
  %sub = add nsw i32 %rem91, -50000
  %arrayidx93 = getelementptr inbounds [96 x i32], ptr @ia, i64 0, i64 %indvars.iv
  store i32 %sub, ptr %arrayidx93, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 96
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body

for.cond.cleanup97:                               ; preds = %cs.exit339
  %rem157 = urem i64 %add153, 100003
  %conv158 = trunc nuw nsw i64 %rem157 to i32
  ret i32 %conv158

for.body98:                                       ; preds = %for.cond.cleanup, %cs.exit339
  %indvars.iv347 = phi i64 [ 0, %for.cond.cleanup ], [ %indvars.iv.next348, %cs.exit339 ]
  %sum.0345 = phi i64 [ 0, %for.cond.cleanup ], [ %add153, %cs.exit339 ]
  %arrayidx100 = getelementptr inbounds [7 x i32], ptr @test.ns, i64 0, i64 %indvars.iv347
  %6 = load i32, ptr %arrayidx100, align 4
  tail call void @avgu(ptr noundef nonnull @uc, ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds (i8, ptr @ub, i64 1), i32 noundef %6) #5
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i, %for.body98
  %indvars.iv.i = phi i64 [ 0, %for.body98 ], [ %indvars.iv.next.i, %for.body.i ]
  %h.05.i = phi i64 [ 7, %for.body98 ], [ %add.i219, %for.body.i ]
  %mul.i218 = mul i64 %h.05.i, 31
  %arrayidx.i = getelementptr inbounds i8, ptr @uc, i64 %indvars.iv.i
  %7 = load i8, ptr %arrayidx.i, align 1
  %conv.i = zext i8 %7 to i64
  %add.i219 = add i64 %mul.i218, %conv.i
  %indvars.iv.next.i = add nuw nsw i64 %indvars.iv.i, 1
  %exitcond.not.i = icmp eq i64 %indvars.iv.next.i, 96
  br i1 %exitcond.not.i, label %cs.exit, label %for.body.i

cs.exit:                                          ; preds = %for.body.i
  %mul = mul i64 %sum.0345, 3
  tail call void @avgs(ptr noundef nonnull @sc8, ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb8, i64 1), i32 noundef %6) #5
  br label %for.body.i220

for.body.i220:                                    ; preds = %for.body.i220, %cs.exit
  %indvars.iv.i221 = phi i64 [ 0, %cs.exit ], [ %indvars.iv.next.i227, %for.body.i220 ]
  %h.05.i222 = phi i64 [ 7, %cs.exit ], [ %add.i226, %for.body.i220 ]
  %mul.i223 = mul i64 %h.05.i222, 31
  %arrayidx.i224 = getelementptr inbounds i8, ptr @sc8, i64 %indvars.iv.i221
  %8 = load i8, ptr %arrayidx.i224, align 1
  %conv.i225 = zext i8 %8 to i64
  %add.i226 = add i64 %mul.i223, %conv.i225
  %indvars.iv.next.i227 = add nuw nsw i64 %indvars.iv.i221, 1
  %exitcond.not.i228 = icmp eq i64 %indvars.iv.next.i227, 96
  br i1 %exitcond.not.i228, label %cs.exit229, label %for.body.i220

cs.exit229:                                       ; preds = %for.body.i220
  %add = add i64 %add.i219, %mul
  %mul102 = mul i64 %add, 3
  tail call void @avgsw(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i230

for.body.i230:                                    ; preds = %for.body.i230, %cs.exit229
  %indvars.iv.i231 = phi i64 [ 0, %cs.exit229 ], [ %indvars.iv.next.i237, %for.body.i230 ]
  %h.05.i232 = phi i64 [ 7, %cs.exit229 ], [ %add.i236, %for.body.i230 ]
  %mul.i233 = mul i64 %h.05.i232, 31
  %arrayidx.i234 = getelementptr inbounds i8, ptr @sc, i64 %indvars.iv.i231
  %9 = load i8, ptr %arrayidx.i234, align 1
  %conv.i235 = zext i8 %9 to i64
  %add.i236 = add i64 %mul.i233, %conv.i235
  %indvars.iv.next.i237 = add nuw nsw i64 %indvars.iv.i231, 1
  %exitcond.not.i238 = icmp eq i64 %indvars.iv.next.i237, 192
  br i1 %exitcond.not.i238, label %cs.exit239, label %for.body.i230

cs.exit239:                                       ; preds = %for.body.i230
  %add104 = add i64 %add.i226, %mul102
  %mul105 = mul i64 %add104, 3
  tail call void @mulh(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i240

for.body.i240:                                    ; preds = %for.body.i240, %cs.exit239
  %indvars.iv.i241 = phi i64 [ 0, %cs.exit239 ], [ %indvars.iv.next.i247, %for.body.i240 ]
  %h.05.i242 = phi i64 [ 7, %cs.exit239 ], [ %add.i246, %for.body.i240 ]
  %mul.i243 = mul i64 %h.05.i242, 31
  %arrayidx.i244 = getelementptr inbounds i8, ptr @sc, i64 %indvars.iv.i241
  %10 = load i8, ptr %arrayidx.i244, align 1
  %conv.i245 = zext i8 %10 to i64
  %add.i246 = add i64 %mul.i243, %conv.i245
  %indvars.iv.next.i247 = add nuw nsw i64 %indvars.iv.i241, 1
  %exitcond.not.i248 = icmp eq i64 %indvars.iv.next.i247, 192
  br i1 %exitcond.not.i248, label %cs.exit249, label %for.body.i240

cs.exit249:                                       ; preds = %for.body.i240
  %add107 = add i64 %add.i236, %mul105
  %mul108 = mul i64 %add107, 3
  tail call void @mulhu(ptr noundef nonnull @hc, ptr noundef nonnull @ha, ptr noundef nonnull getelementptr inbounds (i8, ptr @hb, i64 2), i32 noundef %6) #5
  br label %for.body.i250

for.body.i250:                                    ; preds = %for.body.i250, %cs.exit249
  %indvars.iv.i251 = phi i64 [ 0, %cs.exit249 ], [ %indvars.iv.next.i257, %for.body.i250 ]
  %h.05.i252 = phi i64 [ 7, %cs.exit249 ], [ %add.i256, %for.body.i250 ]
  %mul.i253 = mul i64 %h.05.i252, 31
  %arrayidx.i254 = getelementptr inbounds i8, ptr @hc, i64 %indvars.iv.i251
  %11 = load i8, ptr %arrayidx.i254, align 1
  %conv.i255 = zext i8 %11 to i64
  %add.i256 = add i64 %mul.i253, %conv.i255
  %indvars.iv.next.i257 = add nuw nsw i64 %indvars.iv.i251, 1
  %exitcond.not.i258 = icmp eq i64 %indvars.iv.next.i257, 192
  br i1 %exitcond.not.i258, label %cs.exit259, label %for.body.i250

cs.exit259:                                       ; preds = %for.body.i250
  %add110 = add i64 %add.i246, %mul108
  %mul111 = mul i64 %add110, 3
  tail call void @q15(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i260

for.body.i260:                                    ; preds = %for.body.i260, %cs.exit259
  %indvars.iv.i261 = phi i64 [ 0, %cs.exit259 ], [ %indvars.iv.next.i267, %for.body.i260 ]
  %h.05.i262 = phi i64 [ 7, %cs.exit259 ], [ %add.i266, %for.body.i260 ]
  %mul.i263 = mul i64 %h.05.i262, 31
  %arrayidx.i264 = getelementptr inbounds i8, ptr @sc, i64 %indvars.iv.i261
  %12 = load i8, ptr %arrayidx.i264, align 1
  %conv.i265 = zext i8 %12 to i64
  %add.i266 = add i64 %mul.i263, %conv.i265
  %indvars.iv.next.i267 = add nuw nsw i64 %indvars.iv.i261, 1
  %exitcond.not.i268 = icmp eq i64 %indvars.iv.next.i267, 192
  br i1 %exitcond.not.i268, label %cs.exit269, label %for.body.i260

cs.exit269:                                       ; preds = %for.body.i260
  %add113 = add i64 %add.i256, %mul111
  %mul114 = mul i64 %add113, 3
  %add116 = add i64 %add.i266, %mul114
  %call118 = tail call i32 @dot8(ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb8, i64 1), i32 noundef %6) #5
  %conv119 = zext i32 %call118 to i64
  %call121 = tail call i32 @dot8u(ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds (i8, ptr @ub, i64 1), i32 noundef %6) #5
  %conv122 = zext i32 %call121 to i64
  %call124 = tail call i32 @dot8su(ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds (i8, ptr @ub, i64 1), i32 noundef %6) #5
  %conv125 = zext i32 %call124 to i64
  %call127 = tail call i32 @dot16(ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds (i8, ptr @sb, i64 2), i32 noundef %6) #5
  %conv128 = zext i32 %call127 to i64
  %call130 = tail call i32 @sad(ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds (i8, ptr @ub, i64 1), i32 noundef %6) #5
  %conv131 = zext i32 %call130 to i64
  tail call void @rsh16(ptr noundef nonnull @sc, ptr noundef nonnull @sa, i32 noundef %6) #5
  br label %for.body.i270

for.body.i270:                                    ; preds = %for.body.i270, %cs.exit269
  %indvars.iv.i271 = phi i64 [ 0, %cs.exit269 ], [ %indvars.iv.next.i277, %for.body.i270 ]
  %h.05.i272 = phi i64 [ 7, %cs.exit269 ], [ %add.i276, %for.body.i270 ]
  %mul.i273 = mul i64 %h.05.i272, 31
  %arrayidx.i274 = getelementptr inbounds i8, ptr @sc, i64 %indvars.iv.i271
  %13 = load i8, ptr %arrayidx.i274, align 1
  %conv.i275 = zext i8 %13 to i64
  %add.i276 = add i64 %mul.i273, %conv.i275
  %indvars.iv.next.i277 = add nuw nsw i64 %indvars.iv.i271, 1
  %exitcond.not.i278 = icmp eq i64 %indvars.iv.next.i277, 192
  br i1 %exitcond.not.i278, label %cs.exit279, label %for.body.i270

cs.exit279:                                       ; preds = %for.body.i270
  %mul117 = mul i64 %add116, 3
  %add120 = add i64 %mul117, %conv119
  %add123 = add i64 %add120, %conv122
  %add126 = add i64 %add123, %conv125
  %add129 = add i64 %add126, %conv128
  %add132 = add i64 %add129, %conv131
  %mul133 = mul i64 %add132, 3
  tail call void @rshu16(ptr noundef nonnull @hc, ptr noundef nonnull @ha, i32 noundef %6) #5
  br label %for.body.i280

for.body.i280:                                    ; preds = %for.body.i280, %cs.exit279
  %indvars.iv.i281 = phi i64 [ 0, %cs.exit279 ], [ %indvars.iv.next.i287, %for.body.i280 ]
  %h.05.i282 = phi i64 [ 7, %cs.exit279 ], [ %add.i286, %for.body.i280 ]
  %mul.i283 = mul i64 %h.05.i282, 31
  %arrayidx.i284 = getelementptr inbounds i8, ptr @hc, i64 %indvars.iv.i281
  %14 = load i8, ptr %arrayidx.i284, align 1
  %conv.i285 = zext i8 %14 to i64
  %add.i286 = add i64 %mul.i283, %conv.i285
  %indvars.iv.next.i287 = add nuw nsw i64 %indvars.iv.i281, 1
  %exitcond.not.i288 = icmp eq i64 %indvars.iv.next.i287, 192
  br i1 %exitcond.not.i288, label %cs.exit289, label %for.body.i280

cs.exit289:                                       ; preds = %for.body.i280
  %add135 = add i64 %add.i276, %mul133
  %mul136 = mul i64 %add135, 3
  tail call void @rsh32(ptr noundef nonnull @ic, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i290

for.body.i290:                                    ; preds = %for.body.i290, %cs.exit289
  %indvars.iv.i291 = phi i64 [ 0, %cs.exit289 ], [ %indvars.iv.next.i297, %for.body.i290 ]
  %h.05.i292 = phi i64 [ 7, %cs.exit289 ], [ %add.i296, %for.body.i290 ]
  %mul.i293 = mul i64 %h.05.i292, 31
  %arrayidx.i294 = getelementptr inbounds i8, ptr @ic, i64 %indvars.iv.i291
  %15 = load i8, ptr %arrayidx.i294, align 1
  %conv.i295 = zext i8 %15 to i64
  %add.i296 = add i64 %mul.i293, %conv.i295
  %indvars.iv.next.i297 = add nuw nsw i64 %indvars.iv.i291, 1
  %exitcond.not.i298 = icmp eq i64 %indvars.iv.next.i297, 384
  br i1 %exitcond.not.i298, label %cs.exit299, label %for.body.i290

cs.exit299:                                       ; preds = %for.body.i290
  %add138 = add i64 %add.i286, %mul136
  %mul139 = mul i64 %add138, 3
  tail call void @qs8(ptr noundef nonnull @sc8, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i300

for.body.i300:                                    ; preds = %for.body.i300, %cs.exit299
  %indvars.iv.i301 = phi i64 [ 0, %cs.exit299 ], [ %indvars.iv.next.i307, %for.body.i300 ]
  %h.05.i302 = phi i64 [ 7, %cs.exit299 ], [ %add.i306, %for.body.i300 ]
  %mul.i303 = mul i64 %h.05.i302, 31
  %arrayidx.i304 = getelementptr inbounds i8, ptr @sc8, i64 %indvars.iv.i301
  %16 = load i8, ptr %arrayidx.i304, align 1
  %conv.i305 = zext i8 %16 to i64
  %add.i306 = add i64 %mul.i303, %conv.i305
  %indvars.iv.next.i307 = add nuw nsw i64 %indvars.iv.i301, 1
  %exitcond.not.i308 = icmp eq i64 %indvars.iv.next.i307, 96
  br i1 %exitcond.not.i308, label %cs.exit309, label %for.body.i300

cs.exit309:                                       ; preds = %for.body.i300
  %add141 = add i64 %add.i296, %mul139
  %mul142 = mul i64 %add141, 3
  tail call void @qu8(ptr noundef nonnull @ob, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i310

for.body.i310:                                    ; preds = %for.body.i310, %cs.exit309
  %indvars.iv.i311 = phi i64 [ 0, %cs.exit309 ], [ %indvars.iv.next.i317, %for.body.i310 ]
  %h.05.i312 = phi i64 [ 7, %cs.exit309 ], [ %add.i316, %for.body.i310 ]
  %mul.i313 = mul i64 %h.05.i312, 31
  %arrayidx.i314 = getelementptr inbounds i8, ptr @ob, i64 %indvars.iv.i311
  %17 = load i8, ptr %arrayidx.i314, align 1
  %conv.i315 = zext i8 %17 to i64
  %add.i316 = add i64 %mul.i313, %conv.i315
  %indvars.iv.next.i317 = add nuw nsw i64 %indvars.iv.i311, 1
  %exitcond.not.i318 = icmp eq i64 %indvars.iv.next.i317, 96
  br i1 %exitcond.not.i318, label %cs.exit319, label %for.body.i310

cs.exit319:                                       ; preds = %for.body.i310
  %add144 = add i64 %add.i306, %mul142
  %mul145 = mul i64 %add144, 3
  tail call void @mla(ptr noundef nonnull @ic, ptr noundef nonnull @ia, ptr noundef nonnull getelementptr inbounds (i8, ptr @ia, i64 4), ptr noundef nonnull getelementptr inbounds (i8, ptr @ia, i64 8), i32 noundef %6) #5
  br label %for.body.i320

for.body.i320:                                    ; preds = %for.body.i320, %cs.exit319
  %indvars.iv.i321 = phi i64 [ 0, %cs.exit319 ], [ %indvars.iv.next.i327, %for.body.i320 ]
  %h.05.i322 = phi i64 [ 7, %cs.exit319 ], [ %add.i326, %for.body.i320 ]
  %mul.i323 = mul i64 %h.05.i322, 31
  %arrayidx.i324 = getelementptr inbounds i8, ptr @ic, i64 %indvars.iv.i321
  %18 = load i8, ptr %arrayidx.i324, align 1
  %conv.i325 = zext i8 %18 to i64
  %add.i326 = add i64 %mul.i323, %conv.i325
  %indvars.iv.next.i327 = add nuw nsw i64 %indvars.iv.i321, 1
  %exitcond.not.i328 = icmp eq i64 %indvars.iv.next.i327, 384
  br i1 %exitcond.not.i328, label %cs.exit329, label %for.body.i320

cs.exit329:                                       ; preds = %for.body.i320
  %add147 = add i64 %add.i316, %mul145
  %mul148 = mul i64 %add147, 3
  tail call void @mlaw(ptr noundef nonnull @hc, ptr noundef nonnull @ha, ptr noundef nonnull getelementptr inbounds (i8, ptr @hb, i64 2), ptr noundef nonnull getelementptr inbounds (i8, ptr @ha, i64 4), i32 noundef %6) #5
  br label %for.body.i330

for.body.i330:                                    ; preds = %for.body.i330, %cs.exit329
  %indvars.iv.i331 = phi i64 [ 0, %cs.exit329 ], [ %indvars.iv.next.i337, %for.body.i330 ]
  %h.05.i332 = phi i64 [ 7, %cs.exit329 ], [ %add.i336, %for.body.i330 ]
  %mul.i333 = mul i64 %h.05.i332, 31
  %arrayidx.i334 = getelementptr inbounds i8, ptr @hc, i64 %indvars.iv.i331
  %19 = load i8, ptr %arrayidx.i334, align 1
  %conv.i335 = zext i8 %19 to i64
  %add.i336 = add i64 %mul.i333, %conv.i335
  %indvars.iv.next.i337 = add nuw nsw i64 %indvars.iv.i331, 1
  %exitcond.not.i338 = icmp eq i64 %indvars.iv.next.i337, 192
  br i1 %exitcond.not.i338, label %cs.exit339, label %for.body.i330

cs.exit339:                                       ; preds = %for.body.i330
  %add150 = add i64 %add.i326, %mul148
  %mul151 = mul i64 %add150, 3
  %add153 = add i64 %add.i336, %mul151
  %indvars.iv.next348 = add nuw nsw i64 %indvars.iv347, 1
  %exitcond350.not = icmp eq i64 %indvars.iv.next348, 7
  br i1 %exitcond350.not, label %for.cond.cleanup97, label %for.body98
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smax.i32(i32, i32) #4

attributes #0 = { nofree noinline norecurse nosync nounwind memory(argmem: readwrite) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #1 = { nofree noinline norecurse nosync nounwind memory(argmem: read) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #2 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8"    }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nobuiltin "no-builtins" }

