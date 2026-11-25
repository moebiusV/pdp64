	addq	%rsi, %rdi
	movq	(%rdx), %rcx
	movq	8(%rdx), %rcx
	cmpq	%rsi, %rdi
	je	1f
1:	movq	$5, %rax
