	.text
café:	ret
ループ:	bne	ループ
"odd name!":	jmp "odd name!"
	.globl	café, "odd name!"
	.data
s:	.byte	"é✓", 'é', 'é', "é\U0001F600", "\xc3\xa9", 0
