; expect: 50007  -- wave 1: avg, mulh, mulhr (Q15 saturating), vdacc, vsad, rounding shifts and stores, vmla; the vector IR of vec_w1_lv.ll legalised to scalar code (-pdp64-vecblock=0: the correctness fallback of the lowering)
; noasm: ^[[:space:]]+vec[[:space:]]
; llc: -pdp64-vecblock=0

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
define dso_local void @avgu(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 16
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 16
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <16 x i8>, ptr %2, align 1
  %3 = zext <16 x i8> %wide.load to <16 x i16>
  %4 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load12 = load <16 x i8>, ptr %4, align 1
  %5 = zext <16 x i8> %wide.load12 to <16 x i16>
  %6 = add nuw nsw <16 x i16> %3, splat (i16 1)
  %7 = add nuw nsw <16 x i16> %6, %5
  %8 = lshr <16 x i16> %7, splat (i16 1)
  %9 = trunc <16 x i16> %8 to <16 x i8>
  %10 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <16 x i8> %9, ptr %10, align 1
  %index.next = add nuw i64 %index, 16
  %11 = icmp eq i64 %index.next, %n.vec
  br i1 %11, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader13

for.body.preheader13:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader13, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader13 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %12 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %12 to i16
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %13 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %13 to i16
  %add = add nuw nsw i16 %conv, 1
  %add4 = add nuw nsw i16 %add, %conv3
  %shr = lshr i16 %add4, 1
  %conv5 = trunc i16 %shr to i8
  %arrayidx7 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %conv5, ptr %arrayidx7, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @avgs(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 16
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 16
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <16 x i8>, ptr %2, align 1
  %3 = sext <16 x i8> %wide.load to <16 x i16>
  %4 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load12 = load <16 x i8>, ptr %4, align 1
  %5 = sext <16 x i8> %wide.load12 to <16 x i16>
  %6 = add nsw <16 x i16> %3, splat (i16 1)
  %7 = add nsw <16 x i16> %6, %5
  %8 = lshr <16 x i16> %7, splat (i16 1)
  %9 = trunc <16 x i16> %8 to <16 x i8>
  %10 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <16 x i8> %9, ptr %10, align 1
  %index.next = add nuw i64 %index, 16
  %11 = icmp eq i64 %index.next, %n.vec
  br i1 %11, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader13

for.body.preheader13:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader13, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader13 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %12 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %12 to i16
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %13 = load i8, ptr %arrayidx2, align 1
  %conv3 = sext i8 %13 to i16
  %add = add nsw i16 %conv, 1
  %add4 = add nsw i16 %add, %conv3
  %shr = lshr i16 %add4, 1
  %conv5 = trunc i16 %shr to i8
  %arrayidx7 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %conv5, ptr %arrayidx7, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @avgsw(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %2, align 2
  %3 = sext <16 x i16> %wide.load to <16 x i32>
  %4 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load12 = load <16 x i16>, ptr %4, align 2
  %5 = sext <16 x i16> %wide.load12 to <16 x i32>
  %6 = add nsw <16 x i32> %3, splat (i32 1)
  %7 = add nsw <16 x i32> %6, %5
  %8 = lshr <16 x i32> %7, splat (i32 1)
  %9 = trunc <16 x i32> %8 to <16 x i16>
  %10 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %9, ptr %10, align 2
  %index.next = add nuw i64 %index, 16
  %11 = icmp eq i64 %index.next, %n.vec
  br i1 %11, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader13

for.body.preheader13:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader13, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader13 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %12 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %12 to i32
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %13 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %13 to i32
  %add = add nsw i32 %conv, 1
  %add4 = add nsw i32 %add, %conv3
  %shr = lshr i32 %add4, 1
  %conv5 = trunc i32 %shr to i16
  %arrayidx7 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv5, ptr %arrayidx7, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mulh(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %2, align 2
  %3 = sext <16 x i16> %wide.load to <16 x i32>
  %4 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load12 = load <16 x i16>, ptr %4, align 2
  %5 = sext <16 x i16> %wide.load12 to <16 x i32>
  %6 = mul nsw <16 x i32> %5, %3
  %7 = lshr <16 x i32> %6, splat (i32 16)
  %8 = trunc <16 x i32> %7 to <16 x i16>
  %9 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %8, ptr %9, align 2
  %index.next = add nuw i64 %index, 16
  %10 = icmp eq i64 %index.next, %n.vec
  br i1 %10, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader13

for.body.preheader13:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader13, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader13 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %11 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %11 to i32
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %12 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %12 to i32
  %mul = mul nsw i32 %conv3, %conv
  %shr = lshr i32 %mul, 16
  %conv4 = trunc i32 %shr to i16
  %arrayidx6 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mulhu(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %2, align 2
  %3 = zext <16 x i16> %wide.load to <16 x i32>
  %4 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load12 = load <16 x i16>, ptr %4, align 2
  %5 = zext <16 x i16> %wide.load12 to <16 x i32>
  %6 = mul nuw <16 x i32> %5, %3
  %7 = lshr <16 x i32> %6, splat (i32 16)
  %8 = trunc <16 x i32> %7 to <16 x i16>
  %9 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %8, ptr %9, align 2
  %index.next = add nuw i64 %index, 16
  %10 = icmp eq i64 %index.next, %n.vec
  br i1 %10, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader13

for.body.preheader13:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader13, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader13 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %11 = load i16, ptr %arrayidx, align 2
  %conv = zext i16 %11 to i32
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %12 = load i16, ptr %arrayidx2, align 2
  %conv3 = zext i16 %12 to i32
  %mul = mul nuw i32 %conv3, %conv
  %shr = lshr i32 %mul, 16
  %conv4 = trunc i32 %shr to i16
  %arrayidx6 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @q15(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b11 = ptrtoint ptr %b to i64
  %a10 = ptrtoint ptr %a to i64
  %c9 = ptrtoint ptr %c to i64
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader14, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c9, %a10
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c9, %b11
  %diff.check12 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check12
  br i1 %conflict.rdx, label %for.body.preheader14, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %2, align 2
  %3 = sext <16 x i16> %wide.load to <16 x i32>
  %4 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load13 = load <16 x i16>, ptr %4, align 2
  %5 = sext <16 x i16> %wide.load13 to <16 x i32>
  %6 = mul nsw <16 x i32> %5, %3
  %7 = add nsw <16 x i32> %6, splat (i32 16384)
  %8 = ashr <16 x i32> %7, splat (i32 15)
  %9 = tail call <16 x i32> @llvm.smin.v16i32(<16 x i32> %8, <16 x i32> splat (i32 32767))
  %10 = trunc <16 x i32> %9 to <16 x i16>
  %11 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %10, ptr %11, align 2
  %index.next = add nuw i64 %index, 16
  %12 = icmp eq i64 %index.next, %n.vec
  br i1 %12, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader14

for.body.preheader14:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader14, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader14 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %13 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %13 to i32
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %14 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %14 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, 16384
  %shr = ashr i32 %add, 15
  %cond = tail call i32 @llvm.smin.i32(i32 %shr, i32 32767)
  %conv6 = trunc i32 %cond to i16
  %arrayidx8 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv6, ptr %arrayidx8, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8(ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader10, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %5, %vector.body ]
  %0 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <8 x i8>, ptr %0, align 1
  %1 = sext <8 x i8> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load9 = load <8 x i8>, ptr %2, align 1
  %3 = sext <8 x i8> %wide.load9 to <8 x i32>
  %4 = mul nsw <8 x i32> %3, %1
  %5 = add <8 x i32> %4, %vec.phi
  %index.next = add nuw i64 %index, 8
  %6 = icmp eq i64 %index.next, %n.vec
  br i1 %6, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %7 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %5)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader10

for.body.preheader10:                             ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.06.ph = phi i32 [ 0, %for.body.preheader ], [ %7, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %7, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader10, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader10 ]
  %s.06 = phi i32 [ %add, %for.body ], [ %s.06.ph, %for.body.preheader10 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %8 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %8 to i32
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %9 = load i8, ptr %arrayidx2, align 1
  %conv3 = sext i8 %9 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.06
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8u(ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader10, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %5, %vector.body ]
  %0 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <8 x i8>, ptr %0, align 1
  %1 = zext <8 x i8> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load9 = load <8 x i8>, ptr %2, align 1
  %3 = zext <8 x i8> %wide.load9 to <8 x i32>
  %4 = mul nuw nsw <8 x i32> %3, %1
  %5 = add <8 x i32> %4, %vec.phi
  %index.next = add nuw i64 %index, 8
  %6 = icmp eq i64 %index.next, %n.vec
  br i1 %6, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %7 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %5)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader10

for.body.preheader10:                             ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.06.ph = phi i32 [ 0, %for.body.preheader ], [ %7, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %7, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader10, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader10 ]
  %s.06 = phi i32 [ %add, %for.body ], [ %s.06.ph, %for.body.preheader10 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %8 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %8 to i32
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %9 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %9 to i32
  %mul = mul nuw nsw i32 %conv3, %conv
  %add = add i32 %mul, %s.06
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot8su(ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader10, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %5, %vector.body ]
  %0 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <8 x i8>, ptr %0, align 1
  %1 = sext <8 x i8> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load9 = load <8 x i8>, ptr %2, align 1
  %3 = zext <8 x i8> %wide.load9 to <8 x i32>
  %4 = mul nsw <8 x i32> %3, %1
  %5 = add <8 x i32> %4, %vec.phi
  %index.next = add nuw i64 %index, 8
  %6 = icmp eq i64 %index.next, %n.vec
  br i1 %6, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %7 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %5)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader10

for.body.preheader10:                             ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.06.ph = phi i32 [ 0, %for.body.preheader ], [ %7, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %7, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader10, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader10 ]
  %s.06 = phi i32 [ %add, %for.body ], [ %s.06.ph, %for.body.preheader10 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %8 = load i8, ptr %arrayidx, align 1
  %conv = sext i8 %8 to i32
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %9 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %9 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.06
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @dot16(ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader10, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %5, %vector.body ]
  %0 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <8 x i16>, ptr %0, align 2
  %1 = sext <8 x i16> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load9 = load <8 x i16>, ptr %2, align 2
  %3 = sext <8 x i16> %wide.load9 to <8 x i32>
  %4 = mul nsw <8 x i32> %3, %1
  %5 = add <8 x i32> %4, %vec.phi
  %index.next = add nuw i64 %index, 8
  %6 = icmp eq i64 %index.next, %n.vec
  br i1 %6, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %7 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %5)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader10

for.body.preheader10:                             ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.06.ph = phi i32 [ 0, %for.body.preheader ], [ %7, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %7, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader10, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader10 ]
  %s.06 = phi i32 [ %add, %for.body ], [ %s.06.ph, %for.body.preheader10 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %8 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %8 to i32
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %9 = load i16, ptr %arrayidx2, align 2
  %conv3 = sext i16 %9 to i32
  %mul = mul nsw i32 %conv3, %conv
  %add = add nsw i32 %mul, %s.06
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @sad(ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader10, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %6, %vector.body ]
  %0 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <8 x i8>, ptr %0, align 1
  %1 = zext <8 x i8> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load9 = load <8 x i8>, ptr %2, align 1
  %3 = zext <8 x i8> %wide.load9 to <8 x i32>
  %4 = sub nsw <8 x i32> %1, %3
  %5 = tail call <8 x i32> @llvm.abs.v8i32(<8 x i32> %4, i1 true)
  %6 = add <8 x i32> %5, %vec.phi
  %index.next = add nuw i64 %index, 8
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %8 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %6)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader10

for.body.preheader10:                             ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.06.ph = phi i32 [ 0, %for.body.preheader ], [ %8, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %8, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader10, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader10 ]
  %s.06 = phi i32 [ %add, %for.body ], [ %s.06.ph, %for.body.preheader10 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %9 = load i8, ptr %arrayidx, align 1
  %conv = zext i8 %9 to i32
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %10 = load i8, ptr %arrayidx2, align 1
  %conv3 = zext i8 %10 to i32
  %sub = sub nsw i32 %conv, %conv3
  %11 = tail call i32 @llvm.abs.i32(i32 %sub, i1 true)
  %add = add i32 %11, %s.06
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.abs.i32(i32, i1 immarg) #2

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rsh16(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %c7 = ptrtoint ptr %c to i64
  %a8 = ptrtoint ptr %a to i64
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  %0 = sub i64 %c7, %a8
  %diff.check = icmp ult i64 %0, 32
  %or.cond = or i1 %min.iters.check, %diff.check
  br i1 %or.cond, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %1, align 2
  %2 = sext <16 x i16> %wide.load to <16 x i32>
  %3 = add nsw <16 x i32> %2, splat (i32 8)
  %4 = lshr <16 x i32> %3, splat (i32 4)
  %5 = trunc <16 x i32> %4 to <16 x i16>
  %6 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %5, ptr %6, align 2
  %index.next = add nuw i64 %index, 16
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader9

for.body.preheader9:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader9, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader9 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %8 = load i16, ptr %arrayidx, align 2
  %conv = sext i16 %8 to i32
  %add = add nsw i32 %conv, 8
  %shr = lshr i32 %add, 4
  %conv1 = trunc i32 %shr to i16
  %arrayidx3 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv1, ptr %arrayidx3, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rshu16(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %c7 = ptrtoint ptr %c to i64
  %a8 = ptrtoint ptr %a to i64
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  %0 = sub i64 %c7, %a8
  %diff.check = icmp ult i64 %0, 32
  %or.cond = or i1 %min.iters.check, %diff.check
  br i1 %or.cond, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %1, align 2
  %2 = zext <16 x i16> %wide.load to <16 x i32>
  %3 = add nuw nsw <16 x i32> %2, splat (i32 4)
  %4 = lshr <16 x i32> %3, splat (i32 3)
  %5 = trunc <16 x i32> %4 to <16 x i16>
  %6 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %5, ptr %6, align 2
  %index.next = add nuw i64 %index, 16
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader9

for.body.preheader9:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader9, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader9 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %8 = load i16, ptr %arrayidx, align 2
  %conv = zext i16 %8 to i32
  %add = add nuw nsw i32 %conv, 4
  %shr = lshr i32 %add, 3
  %conv1 = trunc i32 %shr to i16
  %arrayidx3 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv1, ptr %arrayidx3, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @rsh32(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %c7 = ptrtoint ptr %c to i64
  %a8 = ptrtoint ptr %a to i64
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  %0 = sub i64 %c7, %a8
  %diff.check = icmp ult i64 %0, 32
  %or.cond = or i1 %min.iters.check, %diff.check
  br i1 %or.cond, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %1, align 4
  %2 = add nsw <8 x i32> %wide.load, splat (i32 32)
  %3 = ashr <8 x i32> %2, splat (i32 6)
  %4 = getelementptr inbounds nuw i32, ptr %c, i64 %index
  store <8 x i32> %3, ptr %4, align 4
  %index.next = add nuw i64 %index, 8
  %5 = icmp eq i64 %index.next, %n.vec
  br i1 %5, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader9

for.body.preheader9:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader9, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader9 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %6 = load i32, ptr %arrayidx, align 4
  %add = add nsw i32 %6, 32
  %shr = ashr i32 %add, 6
  %arrayidx2 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %shr, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @qs8(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 32
  br i1 %min.iters.check, label %for.body.preheader11, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %scevgep = getelementptr i8, ptr %c, i64 %wide.trip.count
  %0 = shl nuw nsw i64 %wide.trip.count, 2
  %scevgep10 = getelementptr i8, ptr %a, i64 %0
  %bound0 = icmp ult ptr %c, %scevgep10
  %bound1 = icmp ult ptr %a, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %for.body.preheader11, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483616
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <32 x i32>, ptr %1, align 4
  %2 = add nsw <32 x i32> %wide.load, splat (i32 128)
  %3 = ashr <32 x i32> %2, splat (i32 8)
  %4 = tail call <32 x i32> @llvm.smax.v32i32(<32 x i32> %3, <32 x i32> splat (i32 -128))
  %5 = tail call <32 x i32> @llvm.smin.v32i32(<32 x i32> %4, <32 x i32> splat (i32 127))
  %6 = trunc <32 x i32> %5 to <32 x i8>
  %7 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <32 x i8> %6, ptr %7, align 1
  %index.next = add nuw i64 %index, 32
  %8 = icmp eq i64 %index.next, %n.vec
  br i1 %8, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader11

for.body.preheader11:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader11, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader11 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %9 = load i32, ptr %arrayidx, align 4
  %add = add nsw i32 %9, 128
  %shr = ashr i32 %add, 8
  %10 = tail call i32 @llvm.smax.i32(i32 %shr, i32 -128)
  %cond6.off06 = tail call i32 @llvm.smin.i32(i32 %10, i32 127)
  %cond6.off0 = trunc i32 %cond6.off06 to i8
  %arrayidx8 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %cond6.off0, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @qu8(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp7 = icmp sgt i32 %n, 0
  br i1 %cmp7, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 32
  br i1 %min.iters.check, label %for.body.preheader11, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %scevgep = getelementptr i8, ptr %c, i64 %wide.trip.count
  %0 = shl nuw nsw i64 %wide.trip.count, 2
  %scevgep10 = getelementptr i8, ptr %a, i64 %0
  %bound0 = icmp ult ptr %c, %scevgep10
  %bound1 = icmp ult ptr %a, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %for.body.preheader11, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483616
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <32 x i32>, ptr %1, align 4
  %2 = add nsw <32 x i32> %wide.load, splat (i32 32)
  %3 = ashr <32 x i32> %2, splat (i32 6)
  %4 = tail call <32 x i32> @llvm.smax.v32i32(<32 x i32> %3, <32 x i32> zeroinitializer)
  %5 = tail call <32 x i32> @llvm.umin.v32i32(<32 x i32> %4, <32 x i32> splat (i32 255))
  %6 = trunc <32 x i32> %5 to <32 x i8>
  %7 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <32 x i8> %6, ptr %7, align 1
  %index.next = add nuw i64 %index, 32
  %8 = icmp eq i64 %index.next, %n.vec
  br i1 %8, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader11

for.body.preheader11:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader11, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader11 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %9 = load i32, ptr %arrayidx, align 4
  %add = add nsw i32 %9, 32
  %shr = ashr i32 %add, 6
  %10 = tail call i32 @llvm.smax.i32(i32 %shr, i32 0)
  %11 = tail call i32 @llvm.umin.i32(i32 %10, i32 255)
  %cond6.off0 = trunc i32 %11 to i8
  %arrayidx8 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %cond6.off0, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mla(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, ptr noundef readonly %d, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %d13 = ptrtoint ptr %d to i64
  %b11 = ptrtoint ptr %b to i64
  %a10 = ptrtoint ptr %a to i64
  %c9 = ptrtoint ptr %c to i64
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader18, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c9, %a10
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c9, %b11
  %diff.check12 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check12
  %2 = sub i64 %c9, %d13
  %diff.check14 = icmp ult i64 %2, 32
  %conflict.rdx15 = or i1 %conflict.rdx, %diff.check14
  br i1 %conflict.rdx15, label %for.body.preheader18, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %3 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %3, align 4
  %4 = getelementptr inbounds nuw i32, ptr %b, i64 %index
  %wide.load16 = load <8 x i32>, ptr %4, align 4
  %5 = mul <8 x i32> %wide.load16, %wide.load
  %6 = getelementptr inbounds nuw i32, ptr %d, i64 %index
  %wide.load17 = load <8 x i32>, ptr %6, align 4
  %7 = add <8 x i32> %5, %wide.load17
  %8 = getelementptr inbounds nuw i32, ptr %c, i64 %index
  store <8 x i32> %7, ptr %8, align 4
  %index.next = add nuw i64 %index, 8
  %9 = icmp eq i64 %index.next, %n.vec
  br i1 %9, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader18

for.body.preheader18:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader18, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader18 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %10 = load i32, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw i32, ptr %b, i64 %indvars.iv
  %11 = load i32, ptr %arrayidx2, align 4
  %mul = mul i32 %11, %10
  %arrayidx4 = getelementptr inbounds nuw i32, ptr %d, i64 %indvars.iv
  %12 = load i32, ptr %arrayidx4, align 4
  %add = add i32 %mul, %12
  %arrayidx6 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %add, ptr %arrayidx6, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @mlaw(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, ptr noundef readonly %d, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %d13 = ptrtoint ptr %d to i64
  %b11 = ptrtoint ptr %b to i64
  %a10 = ptrtoint ptr %a to i64
  %c9 = ptrtoint ptr %c to i64
  %cmp6 = icmp sgt i32 %n, 0
  br i1 %cmp6, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 16
  br i1 %min.iters.check, label %for.body.preheader18, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c9, %a10
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c9, %b11
  %diff.check12 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check12
  %2 = sub i64 %c9, %d13
  %diff.check14 = icmp ult i64 %2, 32
  %conflict.rdx15 = or i1 %conflict.rdx, %diff.check14
  br i1 %conflict.rdx15, label %for.body.preheader18, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483632
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %3 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %3, align 2
  %4 = getelementptr inbounds nuw i16, ptr %b, i64 %index
  %wide.load16 = load <16 x i16>, ptr %4, align 2
  %5 = mul <16 x i16> %wide.load16, %wide.load
  %6 = getelementptr inbounds nuw i16, ptr %d, i64 %index
  %wide.load17 = load <16 x i16>, ptr %6, align 2
  %7 = add <16 x i16> %5, %wide.load17
  %8 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %7, ptr %8, align 2
  %index.next = add nuw i64 %index, 16
  %9 = icmp eq i64 %index.next, %n.vec
  br i1 %9, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader18

for.body.preheader18:                             ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader18, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader18 ]
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %10 = load i16, ptr %arrayidx, align 2
  %arrayidx2 = getelementptr inbounds nuw i16, ptr %b, i64 %indvars.iv
  %11 = load i16, ptr %arrayidx2, align 2
  %mul = mul i16 %11, %10
  %arrayidx5 = getelementptr inbounds nuw i16, ptr %d, i64 %indvars.iv
  %12 = load i16, ptr %arrayidx5, align 2
  %add = add i16 %mul, %12
  %arrayidx9 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %add, ptr %arrayidx9, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none)
define dso_local i32 @test() local_unnamed_addr #3 {
entry:
  %lcg.promoted = load i32, ptr @lcg, align 4
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  store i32 %add.i, ptr @lcg, align 4
  store i16 -6, ptr getelementptr inbounds nuw (i8, ptr @ha, i64 18), align 2
  store i16 32759, ptr getelementptr inbounds nuw (i8, ptr @sa, i64 16), align 16
  br label %for.body98

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %add.i183184 = phi i32 [ %lcg.promoted, %entry ], [ %add.i, %for.body ]
  %mul.i = mul i32 %add.i183184, 1103515245
  %add.i = add i32 %mul.i, 12345
  %shr.i = lshr i32 %add.i, 8
  %rem193 = and i64 %indvars.iv, 3
  %cmp1 = icmp eq i64 %rem193, 0
  %0 = trunc i32 %shr.i to i8
  %conv3 = select i1 %cmp1, i8 -1, i8 %0
  %arrayidx = getelementptr inbounds nuw [96 x i8], ptr @ua, i64 0, i64 %indvars.iv
  store i8 %conv3, ptr %arrayidx, align 1
  %rem4.lhs.trunc = trunc i64 %indvars.iv to i8
  %rem4182 = urem i8 %rem4.lhs.trunc, 3
  %cmp5 = icmp eq i8 %rem4182, 0
  %shr = lshr i32 %add.i, 13
  %1 = trunc i32 %shr to i8
  %conv13 = select i1 %cmp5, i8 0, i8 %1
  %arrayidx15 = getelementptr inbounds nuw [96 x i8], ptr @ub, i64 0, i64 %indvars.iv
  store i8 %conv13, ptr %arrayidx15, align 1
  %conv25 = select i1 %cmp1, i8 127, i8 %0
  %arrayidx27 = getelementptr inbounds nuw [96 x i8], ptr @sa8, i64 0, i64 %indvars.iv
  store i8 %conv25, ptr %arrayidx27, align 1
  %conv38 = select i1 %cmp5, i8 -128, i8 %1
  %arrayidx40 = getelementptr inbounds nuw [96 x i8], ptr @sb8, i64 0, i64 %indvars.iv
  store i8 %conv38, ptr %arrayidx40, align 1
  %2 = trunc i32 %shr.i to i16
  %conv50 = select i1 %cmp1, i16 -1, i16 %2
  %arrayidx52 = getelementptr inbounds nuw [96 x i16], ptr @ha, i64 0, i64 %indvars.iv
  store i16 %conv50, ptr %arrayidx52, align 2
  %3 = trunc i32 %shr to i16
  %conv63 = select i1 %cmp5, i16 1, i16 %3
  %arrayidx65 = getelementptr inbounds nuw [96 x i16], ptr @hb, i64 0, i64 %indvars.iv
  store i16 %conv63, ptr %arrayidx65, align 2
  %conv75 = select i1 %cmp1, i16 -32768, i16 %2
  %arrayidx77 = getelementptr inbounds nuw [96 x i16], ptr @sa, i64 0, i64 %indvars.iv
  store i16 %conv75, ptr %arrayidx77, align 2
  %4 = lshr i32 %add.i, 11
  %5 = trunc i32 %4 to i16
  %conv88 = select i1 %cmp5, i16 -32768, i16 %5
  %arrayidx90 = getelementptr inbounds nuw [96 x i16], ptr @sb, i64 0, i64 %indvars.iv
  store i16 %conv88, ptr %arrayidx90, align 2
  %rem91 = urem i32 %shr.i, 100000
  %sub = add nsw i32 %rem91, -50000
  %arrayidx93 = getelementptr inbounds nuw [96 x i32], ptr @ia, i64 0, i64 %indvars.iv
  store i32 %sub, ptr %arrayidx93, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 96
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body

for.cond.cleanup97:                               ; preds = %cs.exit181
  %rem157 = urem i64 %add153, 100003
  %conv158 = trunc i64 %rem157 to i32
  ret i32 %conv158

for.body98:                                       ; preds = %for.cond.cleanup, %cs.exit181
  %indvars.iv189 = phi i64 [ 0, %for.cond.cleanup ], [ %indvars.iv.next190, %cs.exit181 ]
  %sum.0187 = phi i64 [ 0, %for.cond.cleanup ], [ %add153, %cs.exit181 ]
  %arrayidx100 = getelementptr inbounds nuw [7 x i32], ptr @test.ns, i64 0, i64 %indvars.iv189
  %6 = load i32, ptr %arrayidx100, align 4
  tail call void @avgu(ptr noundef nonnull @uc, ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ub, i64 1), i32 noundef %6) #5
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i, %for.body98
  %indvars.iv.i = phi i64 [ 0, %for.body98 ], [ %indvars.iv.next.i, %for.body.i ]
  %h.04.i = phi i64 [ 7, %for.body98 ], [ %add.i61, %for.body.i ]
  %mul.i60 = mul i64 %h.04.i, 31
  %arrayidx.i = getelementptr inbounds nuw i8, ptr @uc, i64 %indvars.iv.i
  %7 = load i8, ptr %arrayidx.i, align 1
  %conv.i = zext i8 %7 to i64
  %add.i61 = add i64 %mul.i60, %conv.i
  %indvars.iv.next.i = add nuw nsw i64 %indvars.iv.i, 1
  %exitcond.not.i = icmp eq i64 %indvars.iv.next.i, 96
  br i1 %exitcond.not.i, label %cs.exit, label %for.body.i

cs.exit:                                          ; preds = %for.body.i
  tail call void @avgs(ptr noundef nonnull @sc8, ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb8, i64 1), i32 noundef %6) #5
  br label %for.body.i62

for.body.i62:                                     ; preds = %for.body.i62, %cs.exit
  %indvars.iv.i63 = phi i64 [ 0, %cs.exit ], [ %indvars.iv.next.i69, %for.body.i62 ]
  %h.04.i64 = phi i64 [ 7, %cs.exit ], [ %add.i68, %for.body.i62 ]
  %mul.i65 = mul i64 %h.04.i64, 31
  %arrayidx.i66 = getelementptr inbounds nuw i8, ptr @sc8, i64 %indvars.iv.i63
  %8 = load i8, ptr %arrayidx.i66, align 1
  %conv.i67 = zext i8 %8 to i64
  %add.i68 = add i64 %mul.i65, %conv.i67
  %indvars.iv.next.i69 = add nuw nsw i64 %indvars.iv.i63, 1
  %exitcond.not.i70 = icmp eq i64 %indvars.iv.next.i69, 96
  br i1 %exitcond.not.i70, label %cs.exit71, label %for.body.i62

cs.exit71:                                        ; preds = %for.body.i62
  tail call void @avgsw(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i72

for.body.i72:                                     ; preds = %for.body.i72, %cs.exit71
  %indvars.iv.i73 = phi i64 [ 0, %cs.exit71 ], [ %indvars.iv.next.i79, %for.body.i72 ]
  %h.04.i74 = phi i64 [ 7, %cs.exit71 ], [ %add.i78, %for.body.i72 ]
  %mul.i75 = mul i64 %h.04.i74, 31
  %arrayidx.i76 = getelementptr inbounds nuw i8, ptr @sc, i64 %indvars.iv.i73
  %9 = load i8, ptr %arrayidx.i76, align 1
  %conv.i77 = zext i8 %9 to i64
  %add.i78 = add i64 %mul.i75, %conv.i77
  %indvars.iv.next.i79 = add nuw nsw i64 %indvars.iv.i73, 1
  %exitcond.not.i80 = icmp eq i64 %indvars.iv.next.i79, 192
  br i1 %exitcond.not.i80, label %cs.exit81, label %for.body.i72

cs.exit81:                                        ; preds = %for.body.i72
  tail call void @mulh(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i82

for.body.i82:                                     ; preds = %for.body.i82, %cs.exit81
  %indvars.iv.i83 = phi i64 [ 0, %cs.exit81 ], [ %indvars.iv.next.i89, %for.body.i82 ]
  %h.04.i84 = phi i64 [ 7, %cs.exit81 ], [ %add.i88, %for.body.i82 ]
  %mul.i85 = mul i64 %h.04.i84, 31
  %arrayidx.i86 = getelementptr inbounds nuw i8, ptr @sc, i64 %indvars.iv.i83
  %10 = load i8, ptr %arrayidx.i86, align 1
  %conv.i87 = zext i8 %10 to i64
  %add.i88 = add i64 %mul.i85, %conv.i87
  %indvars.iv.next.i89 = add nuw nsw i64 %indvars.iv.i83, 1
  %exitcond.not.i90 = icmp eq i64 %indvars.iv.next.i89, 192
  br i1 %exitcond.not.i90, label %cs.exit91, label %for.body.i82

cs.exit91:                                        ; preds = %for.body.i82
  tail call void @mulhu(ptr noundef nonnull @hc, ptr noundef nonnull @ha, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @hb, i64 2), i32 noundef %6) #5
  br label %for.body.i92

for.body.i92:                                     ; preds = %for.body.i92, %cs.exit91
  %indvars.iv.i93 = phi i64 [ 0, %cs.exit91 ], [ %indvars.iv.next.i99, %for.body.i92 ]
  %h.04.i94 = phi i64 [ 7, %cs.exit91 ], [ %add.i98, %for.body.i92 ]
  %mul.i95 = mul i64 %h.04.i94, 31
  %arrayidx.i96 = getelementptr inbounds nuw i8, ptr @hc, i64 %indvars.iv.i93
  %11 = load i8, ptr %arrayidx.i96, align 1
  %conv.i97 = zext i8 %11 to i64
  %add.i98 = add i64 %mul.i95, %conv.i97
  %indvars.iv.next.i99 = add nuw nsw i64 %indvars.iv.i93, 1
  %exitcond.not.i100 = icmp eq i64 %indvars.iv.next.i99, 192
  br i1 %exitcond.not.i100, label %cs.exit101, label %for.body.i92

cs.exit101:                                       ; preds = %for.body.i92
  tail call void @q15(ptr noundef nonnull @sc, ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb, i64 2), i32 noundef %6) #5
  br label %for.body.i102

for.body.i102:                                    ; preds = %for.body.i102, %cs.exit101
  %indvars.iv.i103 = phi i64 [ 0, %cs.exit101 ], [ %indvars.iv.next.i109, %for.body.i102 ]
  %h.04.i104 = phi i64 [ 7, %cs.exit101 ], [ %add.i108, %for.body.i102 ]
  %mul.i105 = mul i64 %h.04.i104, 31
  %arrayidx.i106 = getelementptr inbounds nuw i8, ptr @sc, i64 %indvars.iv.i103
  %12 = load i8, ptr %arrayidx.i106, align 1
  %conv.i107 = zext i8 %12 to i64
  %add.i108 = add i64 %mul.i105, %conv.i107
  %indvars.iv.next.i109 = add nuw nsw i64 %indvars.iv.i103, 1
  %exitcond.not.i110 = icmp eq i64 %indvars.iv.next.i109, 192
  br i1 %exitcond.not.i110, label %cs.exit111, label %for.body.i102

cs.exit111:                                       ; preds = %for.body.i102
  %call118 = tail call i32 @dot8(ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb8, i64 1), i32 noundef %6) #5
  %call121 = tail call i32 @dot8u(ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ub, i64 1), i32 noundef %6) #5
  %call124 = tail call i32 @dot8su(ptr noundef nonnull @sa8, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ub, i64 1), i32 noundef %6) #5
  %call127 = tail call i32 @dot16(ptr noundef nonnull @sa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @sb, i64 2), i32 noundef %6) #5
  %call130 = tail call i32 @sad(ptr noundef nonnull @ua, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ub, i64 1), i32 noundef %6) #5
  tail call void @rsh16(ptr noundef nonnull @sc, ptr noundef nonnull @sa, i32 noundef %6) #5
  br label %for.body.i112

for.body.i112:                                    ; preds = %for.body.i112, %cs.exit111
  %indvars.iv.i113 = phi i64 [ 0, %cs.exit111 ], [ %indvars.iv.next.i119, %for.body.i112 ]
  %h.04.i114 = phi i64 [ 7, %cs.exit111 ], [ %add.i118, %for.body.i112 ]
  %mul.i115 = mul i64 %h.04.i114, 31
  %arrayidx.i116 = getelementptr inbounds nuw i8, ptr @sc, i64 %indvars.iv.i113
  %13 = load i8, ptr %arrayidx.i116, align 1
  %conv.i117 = zext i8 %13 to i64
  %add.i118 = add i64 %mul.i115, %conv.i117
  %indvars.iv.next.i119 = add nuw nsw i64 %indvars.iv.i113, 1
  %exitcond.not.i120 = icmp eq i64 %indvars.iv.next.i119, 192
  br i1 %exitcond.not.i120, label %cs.exit121, label %for.body.i112

cs.exit121:                                       ; preds = %for.body.i112
  tail call void @rshu16(ptr noundef nonnull @hc, ptr noundef nonnull @ha, i32 noundef %6) #5
  br label %for.body.i122

for.body.i122:                                    ; preds = %for.body.i122, %cs.exit121
  %indvars.iv.i123 = phi i64 [ 0, %cs.exit121 ], [ %indvars.iv.next.i129, %for.body.i122 ]
  %h.04.i124 = phi i64 [ 7, %cs.exit121 ], [ %add.i128, %for.body.i122 ]
  %mul.i125 = mul i64 %h.04.i124, 31
  %arrayidx.i126 = getelementptr inbounds nuw i8, ptr @hc, i64 %indvars.iv.i123
  %14 = load i8, ptr %arrayidx.i126, align 1
  %conv.i127 = zext i8 %14 to i64
  %add.i128 = add i64 %mul.i125, %conv.i127
  %indvars.iv.next.i129 = add nuw nsw i64 %indvars.iv.i123, 1
  %exitcond.not.i130 = icmp eq i64 %indvars.iv.next.i129, 192
  br i1 %exitcond.not.i130, label %cs.exit131, label %for.body.i122

cs.exit131:                                       ; preds = %for.body.i122
  tail call void @rsh32(ptr noundef nonnull @ic, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i132

for.body.i132:                                    ; preds = %for.body.i132, %cs.exit131
  %indvars.iv.i133 = phi i64 [ 0, %cs.exit131 ], [ %indvars.iv.next.i139, %for.body.i132 ]
  %h.04.i134 = phi i64 [ 7, %cs.exit131 ], [ %add.i138, %for.body.i132 ]
  %mul.i135 = mul i64 %h.04.i134, 31
  %arrayidx.i136 = getelementptr inbounds nuw i8, ptr @ic, i64 %indvars.iv.i133
  %15 = load i8, ptr %arrayidx.i136, align 1
  %conv.i137 = zext i8 %15 to i64
  %add.i138 = add i64 %mul.i135, %conv.i137
  %indvars.iv.next.i139 = add nuw nsw i64 %indvars.iv.i133, 1
  %exitcond.not.i140 = icmp eq i64 %indvars.iv.next.i139, 384
  br i1 %exitcond.not.i140, label %cs.exit141, label %for.body.i132

cs.exit141:                                       ; preds = %for.body.i132
  tail call void @qs8(ptr noundef nonnull @sc8, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i142

for.body.i142:                                    ; preds = %for.body.i142, %cs.exit141
  %indvars.iv.i143 = phi i64 [ 0, %cs.exit141 ], [ %indvars.iv.next.i149, %for.body.i142 ]
  %h.04.i144 = phi i64 [ 7, %cs.exit141 ], [ %add.i148, %for.body.i142 ]
  %mul.i145 = mul i64 %h.04.i144, 31
  %arrayidx.i146 = getelementptr inbounds nuw i8, ptr @sc8, i64 %indvars.iv.i143
  %16 = load i8, ptr %arrayidx.i146, align 1
  %conv.i147 = zext i8 %16 to i64
  %add.i148 = add i64 %mul.i145, %conv.i147
  %indvars.iv.next.i149 = add nuw nsw i64 %indvars.iv.i143, 1
  %exitcond.not.i150 = icmp eq i64 %indvars.iv.next.i149, 96
  br i1 %exitcond.not.i150, label %cs.exit151, label %for.body.i142

cs.exit151:                                       ; preds = %for.body.i142
  tail call void @qu8(ptr noundef nonnull @ob, ptr noundef nonnull @ia, i32 noundef %6) #5
  br label %for.body.i152

for.body.i152:                                    ; preds = %for.body.i152, %cs.exit151
  %indvars.iv.i153 = phi i64 [ 0, %cs.exit151 ], [ %indvars.iv.next.i159, %for.body.i152 ]
  %h.04.i154 = phi i64 [ 7, %cs.exit151 ], [ %add.i158, %for.body.i152 ]
  %mul.i155 = mul i64 %h.04.i154, 31
  %arrayidx.i156 = getelementptr inbounds nuw i8, ptr @ob, i64 %indvars.iv.i153
  %17 = load i8, ptr %arrayidx.i156, align 1
  %conv.i157 = zext i8 %17 to i64
  %add.i158 = add i64 %mul.i155, %conv.i157
  %indvars.iv.next.i159 = add nuw nsw i64 %indvars.iv.i153, 1
  %exitcond.not.i160 = icmp eq i64 %indvars.iv.next.i159, 96
  br i1 %exitcond.not.i160, label %cs.exit161, label %for.body.i152

cs.exit161:                                       ; preds = %for.body.i152
  tail call void @mla(ptr noundef nonnull @ic, ptr noundef nonnull @ia, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ia, i64 4), ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ia, i64 8), i32 noundef %6) #5
  br label %for.body.i162

for.body.i162:                                    ; preds = %for.body.i162, %cs.exit161
  %indvars.iv.i163 = phi i64 [ 0, %cs.exit161 ], [ %indvars.iv.next.i169, %for.body.i162 ]
  %h.04.i164 = phi i64 [ 7, %cs.exit161 ], [ %add.i168, %for.body.i162 ]
  %mul.i165 = mul i64 %h.04.i164, 31
  %arrayidx.i166 = getelementptr inbounds nuw i8, ptr @ic, i64 %indvars.iv.i163
  %18 = load i8, ptr %arrayidx.i166, align 1
  %conv.i167 = zext i8 %18 to i64
  %add.i168 = add i64 %mul.i165, %conv.i167
  %indvars.iv.next.i169 = add nuw nsw i64 %indvars.iv.i163, 1
  %exitcond.not.i170 = icmp eq i64 %indvars.iv.next.i169, 384
  br i1 %exitcond.not.i170, label %cs.exit171, label %for.body.i162

cs.exit171:                                       ; preds = %for.body.i162
  tail call void @mlaw(ptr noundef nonnull @hc, ptr noundef nonnull @ha, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @hb, i64 2), ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ha, i64 4), i32 noundef %6) #5
  br label %for.body.i172

for.body.i172:                                    ; preds = %for.body.i172, %cs.exit171
  %indvars.iv.i173 = phi i64 [ 0, %cs.exit171 ], [ %indvars.iv.next.i179, %for.body.i172 ]
  %h.04.i174 = phi i64 [ 7, %cs.exit171 ], [ %add.i178, %for.body.i172 ]
  %mul.i175 = mul i64 %h.04.i174, 31
  %arrayidx.i176 = getelementptr inbounds nuw i8, ptr @hc, i64 %indvars.iv.i173
  %19 = load i8, ptr %arrayidx.i176, align 1
  %conv.i177 = zext i8 %19 to i64
  %add.i178 = add i64 %mul.i175, %conv.i177
  %indvars.iv.next.i179 = add nuw nsw i64 %indvars.iv.i173, 1
  %exitcond.not.i180 = icmp eq i64 %indvars.iv.next.i179, 192
  br i1 %exitcond.not.i180, label %cs.exit181, label %for.body.i172

cs.exit181:                                       ; preds = %for.body.i172
  %mul = mul i64 %sum.0187, 3
  %add = add i64 %add.i61, %mul
  %mul102 = mul i64 %add, 3
  %add104 = add i64 %add.i68, %mul102
  %mul105 = mul i64 %add104, 3
  %add107 = add i64 %add.i78, %mul105
  %mul108 = mul i64 %add107, 3
  %add110 = add i64 %add.i88, %mul108
  %mul111 = mul i64 %add110, 3
  %add113 = add i64 %add.i98, %mul111
  %mul114 = mul i64 %add113, 3
  %add116 = add i64 %add.i108, %mul114
  %mul117 = mul i64 %add116, 3
  %conv119 = zext i32 %call118 to i64
  %add120 = add i64 %mul117, %conv119
  %conv122 = zext i32 %call121 to i64
  %add123 = add i64 %add120, %conv122
  %conv125 = zext i32 %call124 to i64
  %add126 = add i64 %add123, %conv125
  %conv128 = zext i32 %call127 to i64
  %add129 = add i64 %add126, %conv128
  %conv131 = zext i32 %call130 to i64
  %add132 = add i64 %add129, %conv131
  %mul133 = mul i64 %add132, 3
  %add135 = add i64 %add.i118, %mul133
  %mul136 = mul i64 %add135, 3
  %add138 = add i64 %add.i128, %mul136
  %mul139 = mul i64 %add138, 3
  %add141 = add i64 %add.i138, %mul139
  %mul142 = mul i64 %add141, 3
  %add144 = add i64 %add.i148, %mul142
  %mul145 = mul i64 %add144, 3
  %add147 = add i64 %add.i158, %mul145
  %mul148 = mul i64 %add147, 3
  %add150 = add i64 %add.i168, %mul148
  %mul151 = mul i64 %add150, 3
  %add153 = add i64 %add.i178, %mul151
  %indvars.iv.next190 = add nuw nsw i64 %indvars.iv189, 1
  %exitcond192.not = icmp eq i64 %indvars.iv.next190, 7
  br i1 %exitcond192.not, label %for.cond.cleanup97, label %for.body98
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smax.i32(i32, i32) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.umin.i32(i32, i32) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <16 x i32> @llvm.smin.v16i32(<16 x i32>, <16 x i32>) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.vector.reduce.add.v8i32(<8 x i32>) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <8 x i32> @llvm.abs.v8i32(<8 x i32>, i1 immarg) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <32 x i32> @llvm.smax.v32i32(<32 x i32>, <32 x i32>) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <32 x i32> @llvm.smin.v32i32(<32 x i32>, <32 x i32>) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <32 x i32> @llvm.umin.v32i32(<32 x i32>, <32 x i32>) #4

attributes #0 = { nofree noinline norecurse nosync nounwind memory(argmem: readwrite) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nofree noinline norecurse nosync nounwind memory(argmem: read) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nobuiltin "no-builtins" }

