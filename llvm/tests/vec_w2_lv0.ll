; expect: 25009  -- wave 2: compare + select (int, unsigned, float with NaN, -0.0), conversions; the vector IR of vec_w2_lv.ll legalised to scalar code (-pdp64-vecblock=0: the correctness fallback of the lowering)
; noasm: ^[[:space:]]+vec[[:space:]]
; llc: -pdp64-vecblock=0

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
define dso_local void @s_gt(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
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
  %broadcast.splatinsert = insertelement <8 x i32> poison, i32 %t, i64 0
  %broadcast.splat = shufflevector <8 x i32> %broadcast.splatinsert, <8 x i32> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %1, align 4
  %2 = icmp sgt <8 x i32> %wide.load, %broadcast.splat
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 100), <8 x i32> splat (i32 7)
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
  %cmp1 = icmp sgt i32 %6, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_le(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
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
  %broadcast.splatinsert = insertelement <8 x i32> poison, i32 %t, i64 0
  %broadcast.splat = shufflevector <8 x i32> %broadcast.splatinsert, <8 x i32> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %1, align 4
  %2 = icmp sgt <8 x i32> %wide.load, %broadcast.splat
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 7), <8 x i32> splat (i32 100)
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
  %cmp1.not = icmp sgt i32 %6, %t
  %cond = select i1 %cmp1.not, i32 7, i32 100
  %arrayidx3 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_eq(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
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
  %broadcast.splatinsert = insertelement <8 x i32> poison, i32 %t, i64 0
  %broadcast.splat = shufflevector <8 x i32> %broadcast.splatinsert, <8 x i32> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %1, align 4
  %2 = icmp eq <8 x i32> %wide.load, %broadcast.splat
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 100), <8 x i32> splat (i32 7)
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
  %cmp1 = icmp eq i32 %6, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @s_lt(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b10 = ptrtoint ptr %b to i64
  %a9 = ptrtoint ptr %a to i64
  %c8 = ptrtoint ptr %c to i64
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader13, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c8, %a9
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c8, %b10
  %diff.check11 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check11
  br i1 %conflict.rdx, label %for.body.preheader13, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %2, align 4
  %3 = getelementptr inbounds nuw i32, ptr %b, i64 %index
  %wide.load12 = load <8 x i32>, ptr %3, align 4
  %4 = icmp slt <8 x i32> %wide.load, %wide.load12
  %5 = select <8 x i1> %4, <8 x i32> splat (i32 1), <8 x i32> splat (i32 2)
  %6 = getelementptr inbounds nuw i32, ptr %c, i64 %index
  store <8 x i32> %5, ptr %6, align 4
  %index.next = add nuw i64 %index, 8
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

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
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %8 = load i32, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw i32, ptr %b, i64 %indvars.iv
  %9 = load i32, ptr %arrayidx2, align 4
  %cmp3 = icmp slt i32 %8, %9
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @u_gt(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #0 {
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
  %broadcast.splatinsert = insertelement <8 x i32> poison, i32 %t, i64 0
  %broadcast.splat = shufflevector <8 x i32> %broadcast.splatinsert, <8 x i32> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %1, align 4
  %2 = icmp ugt <8 x i32> %wide.load, %broadcast.splat
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 100), <8 x i32> splat (i32 7)
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
  %cmp1 = icmp ugt i32 %6, %t
  %cond = select i1 %cmp1, i32 100, i32 7
  %arrayidx3 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @h_gt(ptr noundef writeonly %c, ptr noundef readonly %a, i16 noundef signext %t, i32 noundef %n) local_unnamed_addr #0 {
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
  %broadcast.splatinsert = insertelement <16 x i16> poison, i16 %t, i64 0
  %broadcast.splat = shufflevector <16 x i16> %broadcast.splatinsert, <16 x i16> poison, <16 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i16, ptr %a, i64 %index
  %wide.load = load <16 x i16>, ptr %1, align 2
  %2 = icmp sgt <16 x i16> %wide.load, %broadcast.splat
  %3 = select <16 x i1> %2, <16 x i16> splat (i16 1000), <16 x i16> splat (i16 -7)
  %4 = getelementptr inbounds nuw i16, ptr %c, i64 %index
  store <16 x i16> %3, ptr %4, align 2
  %index.next = add nuw i64 %index, 16
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
  %arrayidx = getelementptr inbounds nuw i16, ptr %a, i64 %indvars.iv
  %6 = load i16, ptr %arrayidx, align 2
  %cmp2 = icmp sgt i16 %6, %t
  %conv4 = select i1 %cmp2, i16 1000, i16 -7
  %arrayidx6 = getelementptr inbounds nuw i16, ptr %c, i64 %indvars.iv
  store i16 %conv4, ptr %arrayidx6, align 2
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b_ugt(ptr noundef writeonly %c, ptr noundef readonly %a, i8 noundef zeroext %t, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %c7 = ptrtoint ptr %c to i64
  %a8 = ptrtoint ptr %a to i64
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 32
  %0 = sub i64 %c7, %a8
  %diff.check = icmp ult i64 %0, 32
  %or.cond = or i1 %min.iters.check, %diff.check
  br i1 %or.cond, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483616
  %broadcast.splatinsert = insertelement <32 x i8> poison, i8 %t, i64 0
  %broadcast.splat = shufflevector <32 x i8> %broadcast.splatinsert, <32 x i8> poison, <32 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <32 x i8>, ptr %1, align 1
  %2 = icmp ugt <32 x i8> %wide.load, %broadcast.splat
  %3 = select <32 x i1> %2, <32 x i8> splat (i8 -56), <32 x i8> splat (i8 7)
  %4 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <32 x i8> %3, ptr %4, align 1
  %index.next = add nuw i64 %index, 32
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
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %6 = load i8, ptr %arrayidx, align 1
  %cmp2 = icmp ugt i8 %6, %t
  %conv4 = select i1 %cmp2, i8 -56, i8 7
  %arrayidx6 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %conv4, ptr %arrayidx6, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b_ult(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
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
  %3 = getelementptr inbounds nuw i8, ptr %b, i64 %index
  %wide.load12 = load <16 x i8>, ptr %3, align 1
  %4 = icmp ult <16 x i8> %wide.load, %wide.load12
  %5 = select <16 x i1> %4, <16 x i8> splat (i8 -56), <16 x i8> splat (i8 7)
  %6 = getelementptr inbounds nuw i8, ptr %c, i64 %index
  store <16 x i8> %5, ptr %6, align 1
  %index.next = add nuw i64 %index, 16
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

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
  %8 = load i8, ptr %arrayidx, align 1
  %arrayidx2 = getelementptr inbounds nuw i8, ptr %b, i64 %indvars.iv
  %9 = load i8, ptr %arrayidx2, align 1
  %cmp4 = icmp ult i8 %8, %9
  %conv6 = select i1 %cmp4, i8 -56, i8 7
  %arrayidx8 = getelementptr inbounds nuw i8, ptr %c, i64 %indvars.iv
  store i8 %conv6, ptr %arrayidx8, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: read)
define dso_local i32 @count(ptr noundef readonly %a, i32 noundef %t, i32 noundef %n) local_unnamed_addr #1 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader8, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  %broadcast.splatinsert = insertelement <8 x i32> poison, i32 %t, i64 0
  %broadcast.splat = shufflevector <8 x i32> %broadcast.splatinsert, <8 x i32> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x i32> [ zeroinitializer, %vector.ph ], [ %3, %vector.body ]
  %0 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %0, align 4
  %1 = icmp sgt <8 x i32> %wide.load, %broadcast.splat
  %2 = zext <8 x i1> %1 to <8 x i32>
  %3 = add <8 x i32> %vec.phi, %2
  %index.next = add nuw i64 %index, 8
  %4 = icmp eq i64 %index.next, %n.vec
  br i1 %4, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %5 = tail call i32 @llvm.vector.reduce.add.v8i32(<8 x i32> %3)
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader8

for.body.preheader8:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  %s.05.ph = phi i32 [ 0, %for.body.preheader ], [ %5, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  %s.0.lcssa = phi i32 [ 0, %entry ], [ %5, %middle.block ], [ %add, %for.body ]
  ret i32 %s.0.lcssa

for.body:                                         ; preds = %for.body.preheader8, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader8 ]
  %s.05 = phi i32 [ %add, %for.body ], [ %s.05.ph, %for.body.preheader8 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %6 = load i32, ptr %arrayidx, align 4
  %cmp1 = icmp sgt i32 %6, %t
  %conv = zext i1 %cmp1 to i32
  %add = add nuw nsw i32 %s.05, %conv
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_lt(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %0, align 4
  %1 = getelementptr inbounds nuw float, ptr %b, i64 %index
  %wide.load8 = load <8 x float>, ptr %1, align 4
  %2 = fcmp olt <8 x float> %wide.load, %wide.load8
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 1), <8 x i32> splat (i32 2)
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
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %6 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw float, ptr %b, i64 %indvars.iv
  %7 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp olt float %6, %7
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_nge(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %0, align 4
  %1 = getelementptr inbounds nuw float, ptr %b, i64 %index
  %wide.load8 = load <8 x float>, ptr %1, align 4
  %2 = fcmp ult <8 x float> %wide.load, %wide.load8
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 1), <8 x i32> splat (i32 2)
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
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %6 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw float, ptr %b, i64 %indvars.iv
  %7 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp ult float %6, %7
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_eq(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp5 = icmp sgt i32 %n, 0
  br i1 %cmp5, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader9, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %0, align 4
  %1 = getelementptr inbounds nuw float, ptr %b, i64 %index
  %wide.load8 = load <8 x float>, ptr %1, align 4
  %2 = fcmp oeq <8 x float> %wide.load, %wide.load8
  %3 = select <8 x i1> %2, <8 x i32> splat (i32 1), <8 x i32> splat (i32 2)
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
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %6 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw float, ptr %b, i64 %indvars.iv
  %7 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp oeq float %6, %7
  %cond = select i1 %cmp3, i32 1, i32 2
  %arrayidx5 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx5, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f_max(ptr noundef writeonly %c, ptr noundef readonly %a, ptr noundef readonly %b, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %b15 = ptrtoint ptr %b to i64
  %a14 = ptrtoint ptr %a to i64
  %c13 = ptrtoint ptr %c to i64
  %cmp10 = icmp sgt i32 %n, 0
  br i1 %cmp10, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader18, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = sub i64 %c13, %a14
  %diff.check = icmp ult i64 %0, 32
  %1 = sub i64 %c13, %b15
  %diff.check16 = icmp ult i64 %1, 32
  %conflict.rdx = or i1 %diff.check, %diff.check16
  br i1 %conflict.rdx, label %for.body.preheader18, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %2 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %2, align 4
  %3 = getelementptr inbounds nuw float, ptr %b, i64 %index
  %wide.load17 = load <8 x float>, ptr %3, align 4
  %4 = fcmp ogt <8 x float> %wide.load, %wide.load17
  %5 = select <8 x i1> %4, <8 x float> %wide.load, <8 x float> %wide.load17
  %6 = getelementptr inbounds nuw float, ptr %c, i64 %index
  store <8 x float> %5, ptr %6, align 4
  %index.next = add nuw i64 %index, 8
  %7 = icmp eq i64 %index.next, %n.vec
  br i1 %7, label %middle.block, label %vector.body

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
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %8 = load float, ptr %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds nuw float, ptr %b, i64 %indvars.iv
  %9 = load float, ptr %arrayidx2, align 4
  %cmp3 = fcmp ogt float %8, %9
  %. = select i1 %cmp3, float %8, float %9
  %arrayidx9 = getelementptr inbounds nuw float, ptr %c, i64 %indvars.iv
  store float %., ptr %arrayidx9, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @i2f(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader7, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %0, align 4
  %1 = sitofp <8 x i32> %wide.load to <8 x float>
  %2 = getelementptr inbounds nuw float, ptr %c, i64 %index
  store <8 x float> %1, ptr %2, align 4
  %index.next = add nuw i64 %index, 8
  %3 = icmp eq i64 %index.next, %n.vec
  br i1 %3, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader7

for.body.preheader7:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader7, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader7 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %4 = load i32, ptr %arrayidx, align 4
  %conv = sitofp i32 %4 to float
  %arrayidx2 = getelementptr inbounds nuw float, ptr %c, i64 %indvars.iv
  store float %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @u2f(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader7, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw i32, ptr %a, i64 %index
  %wide.load = load <8 x i32>, ptr %0, align 4
  %1 = uitofp <8 x i32> %wide.load to <8 x float>
  %2 = getelementptr inbounds nuw float, ptr %c, i64 %index
  store <8 x float> %1, ptr %2, align 4
  %index.next = add nuw i64 %index, 8
  %3 = icmp eq i64 %index.next, %n.vec
  br i1 %3, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader7

for.body.preheader7:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader7, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader7 ]
  %arrayidx = getelementptr inbounds nuw i32, ptr %a, i64 %indvars.iv
  %4 = load i32, ptr %arrayidx, align 4
  %conv = uitofp i32 %4 to float
  %arrayidx2 = getelementptr inbounds nuw float, ptr %c, i64 %indvars.iv
  store float %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f2i(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader7, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %0, align 4
  %1 = fptosi <8 x float> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i32, ptr %c, i64 %index
  store <8 x i32> %1, ptr %2, align 4
  %index.next = add nuw i64 %index, 8
  %3 = icmp eq i64 %index.next, %n.vec
  br i1 %3, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader7

for.body.preheader7:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader7, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader7 ]
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %4 = load float, ptr %arrayidx, align 4
  %conv = fptosi float %4 to i32
  %arrayidx2 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @f2u(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader7, label %vector.ph

vector.ph:                                        ; preds = %for.body.preheader
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %0 = getelementptr inbounds nuw float, ptr %a, i64 %index
  %wide.load = load <8 x float>, ptr %0, align 4
  %1 = fptoui <8 x float> %wide.load to <8 x i32>
  %2 = getelementptr inbounds nuw i32, ptr %c, i64 %index
  store <8 x i32> %1, ptr %2, align 4
  %index.next = add nuw i64 %index, 8
  %3 = icmp eq i64 %index.next, %n.vec
  br i1 %3, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader7

for.body.preheader7:                              ; preds = %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader7, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader7 ]
  %arrayidx = getelementptr inbounds nuw float, ptr %a, i64 %indvars.iv
  %4 = load float, ptr %arrayidx, align 4
  %conv = fptoui float %4 to i32
  %arrayidx2 = getelementptr inbounds nuw i32, ptr %c, i64 %indvars.iv
  store i32 %conv, ptr %arrayidx2, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(argmem: readwrite)
define dso_local void @b2f(ptr noundef writeonly %c, ptr noundef readonly %a, i32 noundef %n) local_unnamed_addr #0 {
entry:
  %cmp4 = icmp sgt i32 %n, 0
  br i1 %cmp4, label %for.body.preheader, label %for.cond.cleanup

for.body.preheader:                               ; preds = %entry
  %wide.trip.count = zext i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 32
  br i1 %min.iters.check, label %for.body.preheader8, label %vector.memcheck

vector.memcheck:                                  ; preds = %for.body.preheader
  %0 = shl nuw nsw i64 %wide.trip.count, 2
  %scevgep = getelementptr i8, ptr %c, i64 %0
  %scevgep7 = getelementptr i8, ptr %a, i64 %wide.trip.count
  %bound0 = icmp ult ptr %c, %scevgep7
  %bound1 = icmp ult ptr %a, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %for.body.preheader8, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %wide.trip.count, 2147483616
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %1 = getelementptr inbounds nuw i8, ptr %a, i64 %index
  %wide.load = load <32 x i8>, ptr %1, align 1
  %2 = uitofp <32 x i8> %wide.load to <32 x float>
  %3 = fmul <32 x float> %2, splat (float 0x3F70101020000000)
  %4 = getelementptr inbounds nuw float, ptr %c, i64 %index
  store <32 x float> %3, ptr %4, align 4
  %index.next = add nuw i64 %index, 32
  %5 = icmp eq i64 %index.next, %n.vec
  br i1 %5, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %n.vec, %wide.trip.count
  br i1 %cmp.n, label %for.cond.cleanup, label %for.body.preheader8

for.body.preheader8:                              ; preds = %vector.memcheck, %for.body.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %for.body.preheader ], [ %n.vec, %middle.block ]
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %middle.block, %entry
  ret void

for.body:                                         ; preds = %for.body.preheader8, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ %indvars.iv.ph, %for.body.preheader8 ]
  %arrayidx = getelementptr inbounds nuw i8, ptr %a, i64 %indvars.iv
  %6 = load i8, ptr %arrayidx, align 1
  %conv1 = uitofp i8 %6 to float
  %mul = fmul float %conv1, 0x3F70101020000000
  %arrayidx3 = getelementptr inbounds nuw float, ptr %c, i64 %indvars.iv
  store float %mul, ptr %arrayidx3, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, %wide.trip.count
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Function Attrs: nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none)
define dso_local i32 @test() local_unnamed_addr #2 {
entry:
  %lcg.promoted = load i32, ptr @lcg, align 4
  br label %for.body

for.cond68.preheader:                             ; preds = %cond.end64
  store i32 %add.i, ptr @lcg, align 4
  br label %for.body72

for.body:                                         ; preds = %entry, %cond.end64
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %cond.end64 ]
  %add.i238239 = phi i32 [ %lcg.promoted, %entry ], [ %add.i, %cond.end64 ]
  %mul.i = mul i32 %add.i238239, 1103515245
  %add.i = add i32 %mul.i, 12345
  %shr.i = lshr i32 %add.i, 8
  %rem = urem i32 %shr.i, 21
  %sub = add nsw i32 %rem, -10
  %arrayidx = getelementptr inbounds nuw [96 x i32], ptr @ia, i64 0, i64 %indvars.iv
  store i32 %sub, ptr %arrayidx, align 4
  %rem1.lhs.trunc = trunc i64 %indvars.iv to i8
  %rem1236 = urem i8 %rem1.lhs.trunc, 3
  %cmp2 = icmp eq i8 %rem1236, 0
  %.pre = lshr i32 %add.i, 13
  br i1 %cmp2, label %cond.end, label %cond.false

cond.false:                                       ; preds = %for.body
  %rem5 = urem i32 %.pre, 21
  %sub6 = add nsw i32 %rem5, -10
  br label %cond.end

cond.end:                                         ; preds = %for.body, %cond.false
  %cond = phi i32 [ %sub6, %cond.false ], [ %sub, %for.body ]
  %extract.t = trunc i32 %.pre to i8
  %arrayidx8 = getelementptr inbounds nuw [96 x i32], ptr @ib, i64 0, i64 %indvars.iv
  store i32 %cond, ptr %arrayidx8, align 4
  %mul = mul nsw i32 %sub, 70000
  %arrayidx12 = getelementptr inbounds nuw [96 x i32], ptr @ua, i64 0, i64 %indvars.iv
  store i32 %mul, ptr %arrayidx12, align 4
  %0 = trunc i32 %sub to i16
  %conv = mul nsw i16 %0, 3000
  %arrayidx17 = getelementptr inbounds nuw [96 x i16], ptr @sa, i64 0, i64 %indvars.iv
  store i16 %conv, ptr %arrayidx17, align 2
  %rem18261 = and i64 %indvars.iv, 3
  %cmp19 = icmp eq i64 %rem18261, 0
  %1 = trunc i32 %shr.i to i8
  %conv27 = select i1 %cmp19, i8 -1, i8 %1
  %arrayidx29 = getelementptr inbounds nuw [96 x i8], ptr @ba, i64 0, i64 %indvars.iv
  store i8 %conv27, ptr %arrayidx29, align 1
  %cond42.off0 = select i1 %cmp2, i8 %conv27, i8 %extract.t
  %arrayidx45 = getelementptr inbounds nuw [96 x i8], ptr @bb, i64 0, i64 %indvars.iv
  store i8 %cond42.off0, ptr %arrayidx45, align 1
  %rem46 = and i32 %shr.i, 7
  %idxprom47 = zext i32 %rem46 to i64
  %arrayidx48 = getelementptr inbounds nuw [8 x i32], ptr @test.tab, i64 0, i64 %idxprom47
  %2 = load float, ptr %arrayidx48, align 4
  %arrayidx51 = getelementptr inbounds nuw [96 x float], ptr @fa, i64 0, i64 %indvars.iv
  store float %2, ptr %arrayidx51, align 4
  br i1 %cmp19, label %cond.end64, label %cond.false58

cond.false58:                                     ; preds = %cond.end
  %shr59 = lshr i32 %add.i, 14
  %rem60 = and i32 %shr59, 7
  %idxprom61 = zext i32 %rem60 to i64
  %arrayidx62 = getelementptr inbounds nuw [8 x i32], ptr @test.tab, i64 0, i64 %idxprom61
  %3 = load float, ptr %arrayidx62, align 4
  br label %cond.end64

cond.end64:                                       ; preds = %cond.end, %cond.false58
  %cond65 = phi float [ %3, %cond.false58 ], [ %2, %cond.end ]
  %arrayidx67 = getelementptr inbounds nuw [96 x float], ptr @fb, i64 0, i64 %indvars.iv
  store float %cond65, ptr %arrayidx67, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 96
  br i1 %exitcond.not, label %for.cond68.preheader, label %for.body

for.body72:                                       ; preds = %for.cond68.preheader, %cs.exit215
  %indvars.iv252 = phi i64 [ 0, %for.cond68.preheader ], [ %indvars.iv.next253, %cs.exit215 ]
  %sum.0243 = phi i64 [ 0, %for.cond68.preheader ], [ %add141, %cs.exit215 ]
  %arrayidx74 = getelementptr inbounds nuw [7 x i32], ptr @test.ns, i64 0, i64 %indvars.iv252
  %4 = load i32, ptr %arrayidx74, align 4
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %for.body72
  %index = phi i64 [ 0, %for.body72 ], [ %index.next, %vector.body ]
  %5 = getelementptr inbounds nuw [96 x i32], ptr @io, i64 0, i64 %index
  store <32 x i32> splat (i32 55), ptr %5, align 16
  %6 = getelementptr inbounds nuw [96 x i32], ptr @uo, i64 0, i64 %index
  store <32 x i32> splat (i32 66), ptr %6, align 16
  %7 = getelementptr inbounds nuw [96 x i16], ptr @so, i64 0, i64 %index
  store <32 x i16> splat (i16 77), ptr %7, align 16
  %8 = getelementptr inbounds nuw [96 x i8], ptr @bo, i64 0, i64 %index
  store <32 x i8> splat (i8 88), ptr %8, align 16
  %9 = getelementptr inbounds nuw [96 x float], ptr @fo, i64 0, i64 %index
  store <32 x float> splat (float 1.500000e+00), ptr %9, align 16
  %index.next = add nuw i64 %index, 32
  %10 = icmp eq i64 %index.next, 96
  br i1 %10, label %for.cond.cleanup79, label %vector.body

for.cond.cleanup79:                               ; preds = %vector.body
  tail call void @s_gt(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef 2, i32 noundef %4) #4
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i, %for.cond.cleanup79
  %indvars.iv.i = phi i64 [ 0, %for.cond.cleanup79 ], [ %indvars.iv.next.i, %for.body.i ]
  %h.04.i = phi i64 [ 7, %for.cond.cleanup79 ], [ %add.i75, %for.body.i ]
  %mul.i74 = mul i64 %h.04.i, 31
  %arrayidx.i = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i
  %11 = load i8, ptr %arrayidx.i, align 1
  %conv.i = zext i8 %11 to i64
  %add.i75 = add i64 %mul.i74, %conv.i
  %indvars.iv.next.i = add nuw nsw i64 %indvars.iv.i, 1
  %exitcond.not.i = icmp eq i64 %indvars.iv.next.i, 384
  br i1 %exitcond.not.i, label %cs.exit, label %for.body.i

cs.exit:                                          ; preds = %for.body.i
  tail call void @s_le(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef -3, i32 noundef %4) #4
  br label %for.body.i76

for.body.i76:                                     ; preds = %for.body.i76, %cs.exit
  %indvars.iv.i77 = phi i64 [ 0, %cs.exit ], [ %indvars.iv.next.i83, %for.body.i76 ]
  %h.04.i78 = phi i64 [ 7, %cs.exit ], [ %add.i82, %for.body.i76 ]
  %mul.i79 = mul i64 %h.04.i78, 31
  %arrayidx.i80 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i77
  %12 = load i8, ptr %arrayidx.i80, align 1
  %conv.i81 = zext i8 %12 to i64
  %add.i82 = add i64 %mul.i79, %conv.i81
  %indvars.iv.next.i83 = add nuw nsw i64 %indvars.iv.i77, 1
  %exitcond.not.i84 = icmp eq i64 %indvars.iv.next.i83, 384
  br i1 %exitcond.not.i84, label %cs.exit85, label %for.body.i76

cs.exit85:                                        ; preds = %for.body.i76
  tail call void @s_eq(ptr noundef nonnull @io, ptr noundef nonnull @ia, i32 noundef 0, i32 noundef %4) #4
  br label %for.body.i86

for.body.i86:                                     ; preds = %for.body.i86, %cs.exit85
  %indvars.iv.i87 = phi i64 [ 0, %cs.exit85 ], [ %indvars.iv.next.i93, %for.body.i86 ]
  %h.04.i88 = phi i64 [ 7, %cs.exit85 ], [ %add.i92, %for.body.i86 ]
  %mul.i89 = mul i64 %h.04.i88, 31
  %arrayidx.i90 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i87
  %13 = load i8, ptr %arrayidx.i90, align 1
  %conv.i91 = zext i8 %13 to i64
  %add.i92 = add i64 %mul.i89, %conv.i91
  %indvars.iv.next.i93 = add nuw nsw i64 %indvars.iv.i87, 1
  %exitcond.not.i94 = icmp eq i64 %indvars.iv.next.i93, 384
  br i1 %exitcond.not.i94, label %cs.exit95, label %for.body.i86

cs.exit95:                                        ; preds = %for.body.i86
  tail call void @s_lt(ptr noundef nonnull @io, ptr noundef nonnull @ia, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @ib, i64 4), i32 noundef %4) #4
  br label %for.body.i96

for.body.i96:                                     ; preds = %for.body.i96, %cs.exit95
  %indvars.iv.i97 = phi i64 [ 0, %cs.exit95 ], [ %indvars.iv.next.i103, %for.body.i96 ]
  %h.04.i98 = phi i64 [ 7, %cs.exit95 ], [ %add.i102, %for.body.i96 ]
  %mul.i99 = mul i64 %h.04.i98, 31
  %arrayidx.i100 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i97
  %14 = load i8, ptr %arrayidx.i100, align 1
  %conv.i101 = zext i8 %14 to i64
  %add.i102 = add i64 %mul.i99, %conv.i101
  %indvars.iv.next.i103 = add nuw nsw i64 %indvars.iv.i97, 1
  %exitcond.not.i104 = icmp eq i64 %indvars.iv.next.i103, 384
  br i1 %exitcond.not.i104, label %cs.exit105, label %for.body.i96

cs.exit105:                                       ; preds = %for.body.i96
  tail call void @u_gt(ptr noundef nonnull @uo, ptr noundef nonnull @ua, i32 noundef -2147483648, i32 noundef %4) #4
  br label %for.body.i106

for.body.i106:                                    ; preds = %for.body.i106, %cs.exit105
  %indvars.iv.i107 = phi i64 [ 0, %cs.exit105 ], [ %indvars.iv.next.i113, %for.body.i106 ]
  %h.04.i108 = phi i64 [ 7, %cs.exit105 ], [ %add.i112, %for.body.i106 ]
  %mul.i109 = mul i64 %h.04.i108, 31
  %arrayidx.i110 = getelementptr inbounds nuw i8, ptr @uo, i64 %indvars.iv.i107
  %15 = load i8, ptr %arrayidx.i110, align 1
  %conv.i111 = zext i8 %15 to i64
  %add.i112 = add i64 %mul.i109, %conv.i111
  %indvars.iv.next.i113 = add nuw nsw i64 %indvars.iv.i107, 1
  %exitcond.not.i114 = icmp eq i64 %indvars.iv.next.i113, 384
  br i1 %exitcond.not.i114, label %cs.exit115, label %for.body.i106

cs.exit115:                                       ; preds = %for.body.i106
  tail call void @h_gt(ptr noundef nonnull @so, ptr noundef nonnull @sa, i16 noundef signext 3, i32 noundef %4) #4
  br label %for.body.i116

for.body.i116:                                    ; preds = %for.body.i116, %cs.exit115
  %indvars.iv.i117 = phi i64 [ 0, %cs.exit115 ], [ %indvars.iv.next.i123, %for.body.i116 ]
  %h.04.i118 = phi i64 [ 7, %cs.exit115 ], [ %add.i122, %for.body.i116 ]
  %mul.i119 = mul i64 %h.04.i118, 31
  %arrayidx.i120 = getelementptr inbounds nuw i8, ptr @so, i64 %indvars.iv.i117
  %16 = load i8, ptr %arrayidx.i120, align 1
  %conv.i121 = zext i8 %16 to i64
  %add.i122 = add i64 %mul.i119, %conv.i121
  %indvars.iv.next.i123 = add nuw nsw i64 %indvars.iv.i117, 1
  %exitcond.not.i124 = icmp eq i64 %indvars.iv.next.i123, 192
  br i1 %exitcond.not.i124, label %cs.exit125, label %for.body.i116

cs.exit125:                                       ; preds = %for.body.i116
  tail call void @b_ugt(ptr noundef nonnull @bo, ptr noundef nonnull @ba, i8 noundef zeroext -2, i32 noundef %4) #4
  br label %for.body.i126

for.body.i126:                                    ; preds = %for.body.i126, %cs.exit125
  %indvars.iv.i127 = phi i64 [ 0, %cs.exit125 ], [ %indvars.iv.next.i133, %for.body.i126 ]
  %h.04.i128 = phi i64 [ 7, %cs.exit125 ], [ %add.i132, %for.body.i126 ]
  %mul.i129 = mul i64 %h.04.i128, 31
  %arrayidx.i130 = getelementptr inbounds nuw i8, ptr @bo, i64 %indvars.iv.i127
  %17 = load i8, ptr %arrayidx.i130, align 1
  %conv.i131 = zext i8 %17 to i64
  %add.i132 = add i64 %mul.i129, %conv.i131
  %indvars.iv.next.i133 = add nuw nsw i64 %indvars.iv.i127, 1
  %exitcond.not.i134 = icmp eq i64 %indvars.iv.next.i133, 96
  br i1 %exitcond.not.i134, label %cs.exit135, label %for.body.i126

cs.exit135:                                       ; preds = %for.body.i126
  tail call void @b_ult(ptr noundef nonnull @bo, ptr noundef nonnull @ba, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @bb, i64 1), i32 noundef %4) #4
  br label %for.body.i136

for.body.i136:                                    ; preds = %for.body.i136, %cs.exit135
  %indvars.iv.i137 = phi i64 [ 0, %cs.exit135 ], [ %indvars.iv.next.i143, %for.body.i136 ]
  %h.04.i138 = phi i64 [ 7, %cs.exit135 ], [ %add.i142, %for.body.i136 ]
  %mul.i139 = mul i64 %h.04.i138, 31
  %arrayidx.i140 = getelementptr inbounds nuw i8, ptr @bo, i64 %indvars.iv.i137
  %18 = load i8, ptr %arrayidx.i140, align 1
  %conv.i141 = zext i8 %18 to i64
  %add.i142 = add i64 %mul.i139, %conv.i141
  %indvars.iv.next.i143 = add nuw nsw i64 %indvars.iv.i137, 1
  %exitcond.not.i144 = icmp eq i64 %indvars.iv.next.i143, 96
  br i1 %exitcond.not.i144, label %cs.exit145, label %for.body.i136

cs.exit145:                                       ; preds = %for.body.i136
  %call118 = tail call i32 @count(ptr noundef nonnull @ia, i32 noundef 1, i32 noundef %4) #4
  tail call void @f_lt(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @fb, i64 4), i32 noundef %4) #4
  br label %for.body.i146

for.body.i146:                                    ; preds = %for.body.i146, %cs.exit145
  %indvars.iv.i147 = phi i64 [ 0, %cs.exit145 ], [ %indvars.iv.next.i153, %for.body.i146 ]
  %h.04.i148 = phi i64 [ 7, %cs.exit145 ], [ %add.i152, %for.body.i146 ]
  %mul.i149 = mul i64 %h.04.i148, 31
  %arrayidx.i150 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i147
  %19 = load i8, ptr %arrayidx.i150, align 1
  %conv.i151 = zext i8 %19 to i64
  %add.i152 = add i64 %mul.i149, %conv.i151
  %indvars.iv.next.i153 = add nuw nsw i64 %indvars.iv.i147, 1
  %exitcond.not.i154 = icmp eq i64 %indvars.iv.next.i153, 384
  br i1 %exitcond.not.i154, label %cs.exit155, label %for.body.i146

cs.exit155:                                       ; preds = %for.body.i146
  tail call void @f_nge(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @fb, i64 4), i32 noundef %4) #4
  br label %for.body.i156

for.body.i156:                                    ; preds = %for.body.i156, %cs.exit155
  %indvars.iv.i157 = phi i64 [ 0, %cs.exit155 ], [ %indvars.iv.next.i163, %for.body.i156 ]
  %h.04.i158 = phi i64 [ 7, %cs.exit155 ], [ %add.i162, %for.body.i156 ]
  %mul.i159 = mul i64 %h.04.i158, 31
  %arrayidx.i160 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i157
  %20 = load i8, ptr %arrayidx.i160, align 1
  %conv.i161 = zext i8 %20 to i64
  %add.i162 = add i64 %mul.i159, %conv.i161
  %indvars.iv.next.i163 = add nuw nsw i64 %indvars.iv.i157, 1
  %exitcond.not.i164 = icmp eq i64 %indvars.iv.next.i163, 384
  br i1 %exitcond.not.i164, label %cs.exit165, label %for.body.i156

cs.exit165:                                       ; preds = %for.body.i156
  tail call void @f_eq(ptr noundef nonnull @io, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @fb, i64 4), i32 noundef %4) #4
  br label %for.body.i166

for.body.i166:                                    ; preds = %for.body.i166, %cs.exit165
  %indvars.iv.i167 = phi i64 [ 0, %cs.exit165 ], [ %indvars.iv.next.i173, %for.body.i166 ]
  %h.04.i168 = phi i64 [ 7, %cs.exit165 ], [ %add.i172, %for.body.i166 ]
  %mul.i169 = mul i64 %h.04.i168, 31
  %arrayidx.i170 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i167
  %21 = load i8, ptr %arrayidx.i170, align 1
  %conv.i171 = zext i8 %21 to i64
  %add.i172 = add i64 %mul.i169, %conv.i171
  %indvars.iv.next.i173 = add nuw nsw i64 %indvars.iv.i167, 1
  %exitcond.not.i174 = icmp eq i64 %indvars.iv.next.i173, 384
  br i1 %exitcond.not.i174, label %cs.exit175, label %for.body.i166

cs.exit175:                                       ; preds = %for.body.i166
  tail call void @f_max(ptr noundef nonnull @fo, ptr noundef nonnull @fa, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @fb, i64 4), i32 noundef %4) #4
  br label %for.body.i176

for.body.i176:                                    ; preds = %for.body.i176, %cs.exit175
  %indvars.iv.i177 = phi i64 [ 0, %cs.exit175 ], [ %indvars.iv.next.i183, %for.body.i176 ]
  %h.04.i178 = phi i64 [ 7, %cs.exit175 ], [ %add.i182, %for.body.i176 ]
  %mul.i179 = mul i64 %h.04.i178, 31
  %arrayidx.i180 = getelementptr inbounds nuw i8, ptr @fo, i64 %indvars.iv.i177
  %22 = load i8, ptr %arrayidx.i180, align 1
  %conv.i181 = zext i8 %22 to i64
  %add.i182 = add i64 %mul.i179, %conv.i181
  %indvars.iv.next.i183 = add nuw nsw i64 %indvars.iv.i177, 1
  %exitcond.not.i184 = icmp eq i64 %indvars.iv.next.i183, 384
  br i1 %exitcond.not.i184, label %cs.exit185, label %for.body.i176

cs.exit185:                                       ; preds = %for.body.i176
  tail call void @i2f(ptr noundef nonnull @fo, ptr noundef nonnull @ia, i32 noundef %4) #4
  br label %for.body.i186

for.body.i186:                                    ; preds = %for.body.i186, %cs.exit185
  %indvars.iv.i187 = phi i64 [ 0, %cs.exit185 ], [ %indvars.iv.next.i193, %for.body.i186 ]
  %h.04.i188 = phi i64 [ 7, %cs.exit185 ], [ %add.i192, %for.body.i186 ]
  %mul.i189 = mul i64 %h.04.i188, 31
  %arrayidx.i190 = getelementptr inbounds nuw i8, ptr @fo, i64 %indvars.iv.i187
  %23 = load i8, ptr %arrayidx.i190, align 1
  %conv.i191 = zext i8 %23 to i64
  %add.i192 = add i64 %mul.i189, %conv.i191
  %indvars.iv.next.i193 = add nuw nsw i64 %indvars.iv.i187, 1
  %exitcond.not.i194 = icmp eq i64 %indvars.iv.next.i193, 384
  br i1 %exitcond.not.i194, label %cs.exit195, label %for.body.i186

cs.exit195:                                       ; preds = %for.body.i186
  tail call void @u2f(ptr noundef nonnull @fo, ptr noundef nonnull @ua, i32 noundef %4) #4
  br label %for.body.i196

for.body.i196:                                    ; preds = %for.body.i196, %cs.exit195
  %indvars.iv.i197 = phi i64 [ 0, %cs.exit195 ], [ %indvars.iv.next.i203, %for.body.i196 ]
  %h.04.i198 = phi i64 [ 7, %cs.exit195 ], [ %add.i202, %for.body.i196 ]
  %mul.i199 = mul i64 %h.04.i198, 31
  %arrayidx.i200 = getelementptr inbounds nuw i8, ptr @fo, i64 %indvars.iv.i197
  %24 = load i8, ptr %arrayidx.i200, align 1
  %conv.i201 = zext i8 %24 to i64
  %add.i202 = add i64 %mul.i199, %conv.i201
  %indvars.iv.next.i203 = add nuw nsw i64 %indvars.iv.i197, 1
  %exitcond.not.i204 = icmp eq i64 %indvars.iv.next.i203, 384
  br i1 %exitcond.not.i204, label %cs.exit205, label %for.body.i196

cs.exit205:                                       ; preds = %for.body.i196
  tail call void @b2f(ptr noundef nonnull @fo, ptr noundef nonnull @ba, i32 noundef %4) #4
  br label %for.body.i206

for.body.i206:                                    ; preds = %for.body.i206, %cs.exit205
  %indvars.iv.i207 = phi i64 [ 0, %cs.exit205 ], [ %indvars.iv.next.i213, %for.body.i206 ]
  %h.04.i208 = phi i64 [ 7, %cs.exit205 ], [ %add.i212, %for.body.i206 ]
  %mul.i209 = mul i64 %h.04.i208, 31
  %arrayidx.i210 = getelementptr inbounds nuw i8, ptr @fo, i64 %indvars.iv.i207
  %25 = load i8, ptr %arrayidx.i210, align 1
  %conv.i211 = zext i8 %25 to i64
  %add.i212 = add i64 %mul.i209, %conv.i211
  %indvars.iv.next.i213 = add nuw nsw i64 %indvars.iv.i207, 1
  %exitcond.not.i214 = icmp eq i64 %indvars.iv.next.i213, 384
  br i1 %exitcond.not.i214, label %cs.exit215, label %for.body.i206

cs.exit215:                                       ; preds = %for.body.i206
  %mul94 = mul i64 %sum.0243, 3
  %add = add i64 %add.i75, %mul94
  %mul96 = mul i64 %add, 3
  %add98 = add i64 %add.i82, %mul96
  %mul99 = mul i64 %add98, 3
  %add101 = add i64 %add.i92, %mul99
  %mul102 = mul i64 %add101, 3
  %add104 = add i64 %add.i102, %mul102
  %mul105 = mul i64 %add104, 3
  %add107 = add i64 %add.i112, %mul105
  %mul108 = mul i64 %add107, 3
  %add110 = add i64 %add.i122, %mul108
  %mul111 = mul i64 %add110, 3
  %add113 = add i64 %add.i132, %mul111
  %mul114 = mul i64 %add113, 3
  %add116 = add i64 %add.i142, %mul114
  %mul117 = mul i64 %add116, 3
  %conv119 = zext i32 %call118 to i64
  %add120 = add i64 %mul117, %conv119
  %mul121 = mul i64 %add120, 3
  %add123 = add i64 %add.i152, %mul121
  %mul124 = mul i64 %add123, 3
  %add126 = add i64 %add.i162, %mul124
  %mul127 = mul i64 %add126, 3
  %add129 = add i64 %add.i172, %mul127
  %mul130 = mul i64 %add129, 3
  %add132 = add i64 %add.i182, %mul130
  %mul133 = mul i64 %add132, 3
  %add135 = add i64 %add.i192, %mul133
  %mul136 = mul i64 %add135, 3
  %add138 = add i64 %add.i202, %mul136
  %mul139 = mul i64 %add138, 3
  %add141 = add i64 %add.i212, %mul139
  %indvars.iv.next253 = add nuw nsw i64 %indvars.iv252, 1
  %exitcond255.not = icmp eq i64 %indvars.iv.next253, 7
  br i1 %exitcond255.not, label %for.body150, label %for.body72

for.body150:                                      ; preds = %cs.exit215, %for.body150
  %indvars.iv256 = phi i64 [ %indvars.iv.next257, %for.body150 ], [ 0, %cs.exit215 ]
  %26 = trunc i64 %indvars.iv256 to i16
  %rem152.lhs.trunc = mul nuw nsw i16 %26, 37
  %rem152237 = urem i16 %rem152.lhs.trunc, 200
  %rem152.zext = zext i16 %rem152237 to i32
  %sub153 = add nsw i32 %rem152.zext, -100
  %conv154 = sitofp i32 %sub153 to float
  %mul155 = fmul float %conv154, 0x3FF4CCCCC0000000
  %arrayidx157 = getelementptr inbounds nuw [96 x float], ptr @fa, i64 0, i64 %indvars.iv256
  store float %mul155, ptr %arrayidx157, align 4
  %conv160 = uitofp i16 %rem152237 to float
  %mul161 = fmul float %conv160, 0x3FF4CCCCC0000000
  %arrayidx163 = getelementptr inbounds nuw [96 x float], ptr @fb, i64 0, i64 %indvars.iv256
  store float %mul161, ptr %arrayidx163, align 4
  %indvars.iv.next257 = add nuw nsw i64 %indvars.iv256, 1
  %exitcond259.not = icmp eq i64 %indvars.iv.next257, 96
  br i1 %exitcond259.not, label %for.body172, label %for.body150

for.cond.cleanup171:                              ; preds = %cs.exit235
  %rem182 = urem i64 %add178, 100003
  %conv183 = trunc i64 %rem182 to i32
  ret i32 %conv183

for.body172:                                      ; preds = %for.body150, %cs.exit235
  %n167.0246 = phi i32 [ %add180, %cs.exit235 ], [ 0, %for.body150 ]
  %sum.1245 = phi i64 [ %add178, %cs.exit235 ], [ %add141, %for.body150 ]
  tail call void @f2i(ptr noundef nonnull @io, ptr noundef nonnull @fa, i32 noundef %n167.0246) #4
  br label %for.body.i216

for.body.i216:                                    ; preds = %for.body.i216, %for.body172
  %indvars.iv.i217 = phi i64 [ 0, %for.body172 ], [ %indvars.iv.next.i223, %for.body.i216 ]
  %h.04.i218 = phi i64 [ 7, %for.body172 ], [ %add.i222, %for.body.i216 ]
  %mul.i219 = mul i64 %h.04.i218, 31
  %arrayidx.i220 = getelementptr inbounds nuw i8, ptr @io, i64 %indvars.iv.i217
  %27 = load i8, ptr %arrayidx.i220, align 1
  %conv.i221 = zext i8 %27 to i64
  %add.i222 = add i64 %mul.i219, %conv.i221
  %indvars.iv.next.i223 = add nuw nsw i64 %indvars.iv.i217, 1
  %exitcond.not.i224 = icmp eq i64 %indvars.iv.next.i223, 384
  br i1 %exitcond.not.i224, label %cs.exit225, label %for.body.i216

cs.exit225:                                       ; preds = %for.body.i216
  tail call void @f2u(ptr noundef nonnull @uo, ptr noundef nonnull getelementptr inbounds nuw (i8, ptr @fb, i64 160), i32 noundef %n167.0246) #4
  br label %for.body.i226

for.body.i226:                                    ; preds = %for.body.i226, %cs.exit225
  %indvars.iv.i227 = phi i64 [ 0, %cs.exit225 ], [ %indvars.iv.next.i233, %for.body.i226 ]
  %h.04.i228 = phi i64 [ 7, %cs.exit225 ], [ %add.i232, %for.body.i226 ]
  %mul.i229 = mul i64 %h.04.i228, 31
  %arrayidx.i230 = getelementptr inbounds nuw i8, ptr @uo, i64 %indvars.iv.i227
  %28 = load i8, ptr %arrayidx.i230, align 1
  %conv.i231 = zext i8 %28 to i64
  %add.i232 = add i64 %mul.i229, %conv.i231
  %indvars.iv.next.i233 = add nuw nsw i64 %indvars.iv.i227, 1
  %exitcond.not.i234 = icmp eq i64 %indvars.iv.next.i233, 384
  br i1 %exitcond.not.i234, label %cs.exit235, label %for.body.i226

cs.exit235:                                       ; preds = %for.body.i226
  %mul173 = mul i64 %sum.1245, 3
  %add175 = add i64 %add.i222, %mul173
  %mul176 = mul i64 %add175, 3
  %add178 = add i64 %add.i232, %mul176
  %add180 = add nuw nsw i32 %n167.0246, 13
  %cmp169 = icmp ult i32 %n167.0246, 27
  br i1 %cmp169, label %for.body172, label %for.cond.cleanup171
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.vector.reduce.add.v8i32(<8 x i32>) #3

attributes #0 = { nofree noinline norecurse nosync nounwind memory(argmem: readwrite) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nofree noinline norecurse nosync nounwind memory(argmem: read) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nofree norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none) "min-legal-vector-width"="0" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nobuiltin "no-builtins" }

