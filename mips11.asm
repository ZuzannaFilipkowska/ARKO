#again zad 1
#zastepowanie cyfr ich dopelnieniem do 9

	.data
buf:	.space 256

	.text
main:
	la	$a0, buf	#wczytanie lancucha
	li	$a1, 256
	li	$v0, 8	
	syscall	
	
	li	$t1, 57		#tu bedzie roznica	
	
nextchar:
	lb	$t0, ($a0)
	beq	$t0, '\0', end
	blt	$t0, '0', next
	bgt	$t0, '9', next
	
	subu	$t0, $t1, $t0 
	add 	$t0, $t0, 48
	sb	$t0, ($a0)
	add	$a0, $a0, 1
	j nextchar
end:
	la	$a0, buf
	li	$v0, 4
	syscall
	
	li 	$v0, 10
	syscall
next:
	add $a0, $a0, 1
	j nextchar
	
	