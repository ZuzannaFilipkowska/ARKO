# ZADANIE 2
# Program przetwarza plik tekstowy zwieraj�cy definicje symboli-nazw i inny tekst,
# zawieraj�cy zdefiniowane symbole. Definicja rozpoczyna si� w pierwszej kolumnie tekstu i
# sk�ada si� z nazwy, po kt�rej nast�puje znak dwukropka i ci�gu znak�w, rozpoczynaj�cego
# si� od pierwszego znaku nie b�d�cego odst�pem i ko�cz�cego ostatnim znakiem nie
# b�d�cym odst�pem w wierszu definicji.Program tworzy plik wyj�ciowy nie zawieraj�cy definicji symboli,
# w kt�rym w pozosta�ym tek�cie zast�piono zdefiniowane symbole ich rozwini�ciami

# program mo�e przechowywa� 50 etykiet
# max. rozmiar etykiety to 48B (23B na nazw� etykiety + 1B na ':', 22B na rozwini�cie + 2B na znaki odst�pu)

	.eqv	BUF_LEN 512			
	.eqv	WORD_BUF_LEN 24			
	.eqv	LABELS_SIZE 2400

        .data  
getc_buf: 		.space 	BUF_LEN
putc_buf: 		.space 	BUF_LEN
fname:			.space 	64
good_fname:		.space 	64
word_buf:		.space 	WORD_BUF_LEN
getc_chars_left:	.half 	0
putc_chars_left:	.half 	BUF_LEN
getc_buf_pointer:	.space 	4
putc_buf_pointer:	.space 	4
ifile_descriptor:	.space 	4
ofile_descriptor:	.space 	4
labels_pointer:		.space 	4

output_fname:		.asciiz "output.txt"
error_txt:		.asciiz	"Error while opening the file."
prompt:			.asciiz "Enter file name: "

        .text
        .globl	main
main:
	la	$a0, prompt			# wy�wietl komunikat
	li	$v0, 4
	syscall
	
	li	$v0, 8				# wczytaj nazw� pliku wej�ciowego
	la 	$a0, fname
	li	$a1, 64
	syscall
					
	la 	$t0, fname
	la	$t2, good_fname
prepare_fname:					# usu� '\n' z konca fname
	lbu 	$t1, ($t0)
	bleu 	$t1, '\n', allocate_memory
	sb	$t1, ($t2)
	addiu	$t0, $t0, 1
	addiu	$t2, $t2, 1
	b prepare_fname
	
allocate_memory:				# przydziel pami�� dla  definicji etykiet
	sb	$zero, ($t2)
	li	$v0, 9				# numer funkcji sbrk
	li	$a0, LABELS_SIZE		# za�aduj liczb� bajt�w do alokacji
	syscall					
	la	$s1, labels_pointer		# za�aduj adres labels_pointer
	sw	$v0, ($s1)			# zapisz adres zaalokowanej pami�ci
open_files:
	li 	$v0, 13       			# otw�rz plik wej�ciowy
	la	$a0, good_fname			
	li	$a1, 0				# ustaw flag� do odczytu
  	syscall          			# uchwyt do pliku zwr�cony w $v0
  	la	$t0, ifile_descriptor
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# je�li wyst�pi� b��d skocz do open_file_err
	
	li 	$v0, 13       			# analogicznie otw�rz plik do zapisu wynik�w
	la	$a0, output_fname		
	li	$a1, 1				# flaga do zapisu
  	syscall          			
  	la	$t0, ofile_descriptor		
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# je�li wyst�pi� b��d skocz do open_file_err
	
						
	la	$t0, putc_buf			
	sw	$t0, putc_buf_pointer		# ustaw wska�nik na pierwszy znak putc_buf( przygotowane na przysz�e wywo�ania putc)
process_file:
	jal	replace_labels			# znajd� definicje etykiet, zast�p etykiety w tek�cie, zapisz zmieniony tekst do pliku
	jal	flush_buffer			# zapisz pozosta�e w putc_buf znaki do pliku
close_files:
	la	$a0, ifile_descriptor
	lw	$a0, ($a0)	
	li	$v0, 16				# zamknj plik wej�ciowy	
	syscall					
	
	la	$a0, ofile_descriptor 		
	lw	$a0, ($a0)			
	li	$v0, 16				# zamknj plik wyj�ciowy
	syscall					
exit:
	li 	$v0, 10				# zako�cz program
  	syscall					
open_file_err:
	la	$a0, error_txt
	li	$v0, 4				# wy�wielt error_txt
	syscall					
	j	close_files
  	
#========================================================================================================================== 	
# replace_labels - funkcja zast�puje zdefiniowane symbole w tek�cie ich rozwini�ciami
# plik wyj�ciowy nie zawiera definicji symboli
# argumenty: brak
# zmienne:
# $s0 - wska�nik na wolne miejsce w labels
# $s1 - analizowany bajt pliku wej�ciowego
# $s2 - wska�nik na word_buf
# $s3 - flaga stanu: 1 je�li program jest w trakcie analizy definicji (wyst�pi� ':' i nie by�o znaku ko�ca linii)
#       2 gdy wyst�pi '\r' w wierszu definicji, 0 - analiza zwyk�ego tekst
# procedura nic nie zwraca
replace_labels:
	subiu	$sp, $sp, 20			
	sw	$ra, 16($sp)			
	sw	$s0, 12($sp)			
	sw	$s1, 8($sp)			
	sw	$s2, 4($sp)
	sw	$s3, 0($sp)			
	
	li	$s3, 0				# ustaw flag� na 0	
	lw	$s0, labels_pointer		
	la	$s2, word_buf			
replace_labels_loop:
	jal	getc				# pobierz bajt
	move	$s1, $v0			
	sb	$s1, ($s2)			# zapisz znak w word_buf
	
	beq	$s1, ' ', end_of_word		
	bleu	$s1, '\r', end_of_line
	beq	$s1, ':', new_label		# napotkano koniec symbolu
	bltz	$s1, end_of_line		# je�li -1 (EOF) sprawd� word_buf i zako�cz procedur�
	
	addiu	$s2, $s2, 1			# inkrementacja wska�nika word_buf
	j	replace_labels_loop		# kolejny obieg p�tli
	
new_label:
	sb	$zero, 0($s2)			# zamie� ':' na NULL na ko�cu bufora
	li	$s3, 1 				# koniec nazwy symbolu - ustaw flag� na 1, zaczynamy wczytywa� rozwini�cie
	la	$a0, word_buf			
	move	$a1, $s2			# przygotuj argumenty dla funkcji copy
	move	$a2, $s0			
	jal	save_label			# zapisz nazw� symoblu w labels

	addiu	$s0, $s0, 24			# zaktualizuj wska�nik na wolne miejsce w labels						
	j 	next_word

end_of_line:
	beqz 	$s3, end_of_simple_word 	# jesli $s3 = 0 to koniec lini oznacza koniec s�owa
	beq	$s3, 2,end_of_line_after_label 	
	sb	$zero, 0($s2)			# w przeciwnym wypadku sko�czy�a si� definicja symbolu i trzeba j� zapisa� 
	la	$a0, word_buf			# pocz�tek definicji (argument dla copy)
	addiu	$a0, $a0, 1
	move	$a1, $s2			# koniec definicji
	move	$a2, $s0			# miejsce do zapisu ( wolne miejsce w labels)
	jal	save_label
	addiu	$s0, $s0, 24			# zaktualizuj wska�nik do labels �eby wskazywa� na wolne miejsce
	bltz	$s1, replace_labels_ret		# je�li $s1 < 0 zako�cz procedur�
	li	$s3, 2
	j 	next_word
	
end_of_line_after_label:			# je�li w�a�nie by�a definicja symbolu to pomi� znak
	li	$s3, 0				# zaktualizuj $s3 na 0 (koniec lini z definicj� symbolu)
	j next_word				# przejd� do analizy kolejnych znak�w

end_of_word:
	beq	$s3, 0, end_of_simple_word	# jesli $s3 = 0 to natrafilismy na koniec zwyklego slowa	(nie def)
	addiu	$s2, $s2, 1				# jesli $s3 = 1 to dalej wczytujemy definicj�, nie chcemy zerowac word_buf
	j replace_labels_loop			# przechodzimy do pocz�tku p�tli
	
end_of_simple_word:										
	jal	check_is_word_symbol 		# sprawdzamy czy s�owo jest symbolem
	move	$t0, $v0			
	beq	$t0, -1, end_of_word_not_symbol	# je�li nie to skok do end_of_word_not_symbol
	
end_of_word_symbol:				# je�li tak to zapisz do pliku rozwini�cie symbolu
	move 	$a0, $t0			# adres pocz�tku rozwini�cia				
	jal	put_str				
	move	$a0, $s1			
	jal	putc				# zapisz ostani bajt s�owa(LF/spacja)
	bltz	$s1, replace_labels_ret		# je�li by� koniec pliku wej�ciowego to zako�cz procedur�
	j	next_word			# przejd� do analizy kolejnych znak�w
				
end_of_word_not_symbol:		
	sb	$zero, 1($s2)			# dopisz NULL na ko�cu s�owa
	la	$a0, word_buf			# zapisz word_buf do pliku
	jal	put_str
	bltz	$s1, replace_labels_ret		# je�li wyst�pi� koniec pliku wej�ciowego to zako�cz procedur�
next_word:
	la	$s2, word_buf			# zresetuj wska�nik na word_buf
	j	replace_labels_loop		# zacznij kolejny obieg p�tli
replace_labels_ret:
	lw	$s3, 0($sp)			
	lw	$s2, 4($sp)
	lw	$s1, 8($sp)			
	lw	$s0, 12($sp)			
	lw	$ra, 16($sp)				
	addiu	$sp, $sp, 20

	jr	$ra				# powr�t

# =======================================================================================================
# save_label
# procedura kopiuje tekst ze �r�d�a do wybranego miejsca (symbol/rozwini�cie symbolu do miejsca na labele)
# argumenty:
# $a0 - adres �r�d�owy (pocz�tek)
# $a1 - koniec bufora (nie b�dzie kopiowany)
# $a2 - adres wolnego miejsca w labels
# zmienne: $t0 - zapisywany znak
# zwraca: brak

save_label:
	lbu	$t0, ($a0)			# skopiuj bajt z bufora
	sb	$t0, ($a2)			# zapisz bajt w miejscu docelowym
	addiu	$a0, $a0, 1			# zinkrementuj wska�niki
	addiu	$a2, $a2, 1			
	
	bne	$a0, $a1, save_label		# je�li to nie koniec bufora - kolejny obieg p�tli

	jr	$ra				# powr�t

# ==============================================================================================================
# check_is_word_symbol 
# procedura sprawdza czy s�owo jest symbolem, je�li tak to zwraca rozwini�cie symbolu, je�li nie to zwraca -1
# argumenty: brak
# zmienne:
# $t0 - labels_pointer
# $t1 - wska�nik na kolejny znak etykiety address
# $t2 - adres word_buf
# $t3 - por�wnywany znak etykiety
# $t4 - por�wnywany znak s�owa
# $t5 - flaga = 1 je�li etykieta si� sko�czy�a
# $t6 - flaga = 1 je�li s�owo si� sko�czy�o 
# $t7 - przechowyje wynik operacji and/or
# zwraca: $v0 - adres pierwszego bajtu rozwini�cia lub -1 je�li s�owo nie jest symbolem
check_is_word_symbol :
	lw	$t0, labels_pointer		
	la	$t2, word_buf			
check_is_word_symbol_loop:
	move	$t1, $t0			# adres pocz�tku etykiety
	lbu	$t3, ($t1)			# za�aduj kolejny bajt etykiety
	beqz	$t3, symbol_not_found		# NULL na pierwszym bajcie = brak etykiety, zako�cz szukanie
compare:
	lbu	$t4, ($t2)			# za�aduj bajt word_buf
	lbu	$t3, ($t1)			# za�aduj bajt etykiety

	seq	$t5, $t3, $zero			# ustaw $t5=1 je�li etykieta sie sko�czy�a
	sleu	$t6, $t4, ' '			# ustaw $t6=1 je�li s�owo si� sko�czy�o
	and	$t7, $t5, $t6			
	bnez	$t7, symbol_found		# je�li oba na raz si� sko�czy�y - symbol_found
	or	$t7, $t5, $t6 
	bnez	$t7, word_not_equal		# je�li jedno z nich si� sko�czy�o por�wnaj z kolejn� etykiet�
	
	addiu	$t1, $t1, 1			# zinkrementuj wska�niki
	addiu	$t2, $t2, 1			
	beq	$t3, $t4, compare		# por�wnaj znaki, je�li takie same, por�wnaj kolejne znaki
word_not_equal:
	addiu	$t0, $t0, 48			# ustaw wska�nik na kolejn� etykiet�
	la	$t2, word_buf			# ustaw wska�nik na pocz�tek s�owa
	j 	check_is_word_symbol_loop
symbol_not_found:
	li	$v0, -1				# ustaw $v0=-1 - s�owo nie jest symbolem
	j 	check_is_word_symbol_ret
symbol_found:
	addiu	$t0, $t0, 24			# zapisz w $v0 adres rozwini�cia etykiety
	move	$v0, $t0
check_is_word_symbol_ret:
	jr 	$ra				# powr�t
	
# ====================================================================================================
# getc
# procedura zwraca kolejny znak z bufora, je�li bufor jest pusty to najpierw odczutuje znaki z pliku
# argumenty: brak
# zmienne:
# $t0 - liczba bajt�w w putc_buf
# $t1 - wska�nik na kolejny bajt
# $t2 - kolejny znak z getc_buf
# zwraca: $v0 - znak lub je�li wyst�pi� koniec pliku 
getc:
	lhu	$t0, getc_chars_left		# liczba pozosta�ych znak�w w getc_buf
	lw	$t1, getc_buf_pointer		# wska�nik do bufora
	bnez	$t0, get_char			# je�li s� jeszcze znaki to przejd� do get_char
refresh_buf:
	li 	$v0, 14       			# pobierz z pliku kolejn� porcj� danych (512B)
	lw	$a0, ifile_descriptor		
  	la 	$a1, getc_buf   		# za�aduj adres getc_bupf
  	li 	$a2, BUF_LEN       		# BUF_LEN = 512
  	syscall          			
  	
  	move	$t0, $v0			# zapisz liczb� odczytanych znak�w
  	sh	$v0, getc_chars_left		# zaktualizuj getc_chars_left
  	beqz	$t0, getc_eof			# je�li nast�pi� koniec pliku (odczytano 0) to id� do getc_eof
  	la	$t1, getc_buf			# adres do bufora odczytanych znak�w
  	sw	$t1, getc_buf_pointer		# ustaw wska�nik na pocz�tek bufora
get_char:
	lbu	$t2, ($t1)			# za�aduj znak
	addiu	$t1, $t1, 1			# zaktualizuj wska�nik
	sw	$t1, getc_buf_pointer		# zapisz zaktualizowany wska�nik do getc_buf_pointer
	addiu	$t0, $t0, -1			# zmniejsz liczb� pozosta�ych znak�w
	sh	$t0, getc_chars_left		# zaktualizuj getc_chars_left
	move	$v0, $t2			# zwr�� pobrany znak w $v0
	j	getc_return			
getc_eof:
	li	$v0, -1				# wyst�pi� koniec pliku (zwr�� -1)
getc_return:
	jr	$ra	

# ==================================================================================================
# putc
# procedura zapisuje znak do putc_buf, je�li bufor si� zape�ni� 
# to najpierw zapisuje jego zawarto�� do pliku
# argumenty: $a0 - znak do zapisania
# zmienne:
# $s0 - znak do zapisania
# $s1 - liczba bajt�w w buforze putc_buf
# $s2 - wska�nik na kolejny bajt bufora
putc:
	subiu	$sp, $sp, 16
	sw	$ra, 12($sp)			
	sw	$s0, 8($sp)			
	sw 	$s1, 4($sp)			
	sw 	$s2, 0($sp)			
	
	move 	$s0, $a0			# zapisz znak do zapisania
	lhu	$s1, putc_chars_left		# zaladuj liczb� pozosta�ych bajt�w w buforze
	bnez	$s1, put_char			# je�li bufor nie jest pe�ny skocz do putc_char
	jal	flush_buffer			# flush buffer
	lhu	$s1, putc_chars_left		# zaktualizuj
put_char:
	lw	$s2, putc_buf_pointer		# za�aduj wska�nik na kolejny znak bufora
	sb	$s0, ($s2)			# zapisz znak
	addiu	$s2, $s2, 1			
	sw	$s2, putc_buf_pointer		# zaktualizuj putc_buf_pointer
	addiu	$s1, $s1, -1			
	sh	$s1, putc_chars_left		# zaktualizuj licznik pozosta�ych do zapisania bajt�w
putc_return:
	lw	$s2, 0($sp)					
	lw	$s1, 4($sp)						
	lw	$s0, 8($sp)						
	lw	$ra, 12($sp)			
	addiu	$sp, $sp, 16
	jr	$ra
# =======================================================================================================
# put_str
# procedura zapisuje napis do putc_buf
# argumenty: $a0 - adres s�owa do zapisania
# zmienne:
# $s0 - wska�nik na kolejny bajt s�owa
# $s1 - aktualnie zapisywany bajt
put_str:
	subiu	$sp, $sp, 12
	sw	$ra, 8($sp)			
	sw	$s0, 4($sp)			
	sw 	$s1, 0($sp)					
	
	move	$s0, $a0			# przenie� adres napisu do $s0
	lbu	$s1, ($s0)			# za�aduj kolejny znak napisu
put_str_loop:
	move	$a0, $s1			# przygotuj argument dla putc
	jal	putc				# funkcja zapisuj�ca bajt
	addiu	$s0, $s0, 1			# zwi�ksz wska�nik
	lbu	$s1, ($s0)			# za�aduj kolejny znak
	bnez	$s1, put_str_loop		# je�li napis si� nie sko�czy� powt�rz p�tl�
put_str_return:					
	lw	$s1, 0($sp)					
	lw	$s0, 4($sp)						
	lw	$ra, 8($sp)						
	addiu	$sp, $sp, 12
	
	jr	$ra				# powr�t
# =================================================================================================
# flush_buffer
# procedura zapisuje zawarto�� putc_buf do pliku wyj�ciowego
# argumenty: brak
# zmienne:
# $t0 - zawarto�� BUF_LEN
# $t1 - zawarto�� putc_chars_left
# $t2 - wska�nik na putc_buf
flush_buffer:
	li	$t0, BUF_LEN			# 512
	lhu	$t1, putc_chars_left		# liczba pozosta�ych bajt�w do zapisania w putc_buf
	
	lw	$a0, ofile_descriptor		
  	la 	$a1, putc_buf   		# adres bufora, z kt�rego chcemy zapisa�
  	subu	$a2, $t0, $t1			# oblicz ile znak�w b�dzie zapisywanych
  	li 	$v0, 15       			# numer funkcji zapisu do pliku
  	syscall  
  	      			
  	sh	$t0, putc_chars_left		# zaktualizuj putc_chars_left na 512
  	la	$t2, putc_buf			# za�aduj adres putc_buf
  	sw	$t2, putc_buf_pointer		# ustaw wska�nik na pocz�tek bufora (reset bufora)
  	
  	jr	$ra
