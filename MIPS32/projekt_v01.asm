# ZADANIE 2
# Program przetwarza plik tekstowy zwieraj¹cy definicje symboli-nazw i inny tekst,
# zawieraj¹cy zdefiniowane symbole. Definicja rozpoczyna siê w pierwszej kolumnie tekstu i
# sk³ada siê z nazwy, po której nastêpuje znak dwukropka i ci¹gu znaków, rozpoczynaj¹cego
# siê od pierwszego znaku nie bêd¹cego odstêpem i koñcz¹cego ostatnim znakiem nie
# bêd¹cym odstêpem w wierszu definicji.Program tworzy plik wyjœciowy nie zawieraj¹cy definicji symboli,
# w którym w pozosta³ym tekœcie zast¹piono zdefiniowane symbole ich rozwiniêciami

# program mo¿e przechowywaæ 50 etykiet
# max. rozmiar etykiety to 48B (23B na nazwê etykiety + 1B na ':', 22B na rozwiniêcie + 2B na znaki odstêpu)

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
	la	$a0, prompt			# wyœwietl komunikat
	li	$v0, 4
	syscall
	
	li	$v0, 8				# wczytaj nazwê pliku wejœciowego
	la 	$a0, fname
	li	$a1, 64
	syscall
					
	la 	$t0, fname
	la	$t2, good_fname
prepare_fname:					# usuñ '\n' z konca fname
	lbu 	$t1, ($t0)
	bleu 	$t1, '\n', allocate_memory
	sb	$t1, ($t2)
	addiu	$t0, $t0, 1
	addiu	$t2, $t2, 1
	b prepare_fname
	
allocate_memory:				# przydziel pamiêæ dla  definicji etykiet
	sb	$zero, ($t2)
	li	$v0, 9				# numer funkcji sbrk
	li	$a0, LABELS_SIZE		# za³aduj liczbê bajtów do alokacji
	syscall					
	la	$s1, labels_pointer		# za³aduj adres labels_pointer
	sw	$v0, ($s1)			# zapisz adres zaalokowanej pamiêci
open_files:
	li 	$v0, 13       			# otwórz plik wejœciowy
	la	$a0, good_fname			
	li	$a1, 0				# ustaw flagê do odczytu
  	syscall          			# uchwyt do pliku zwrócony w $v0
  	la	$t0, ifile_descriptor
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# jeœli wyst¹pi³ b³¹d skocz do open_file_err
	
	li 	$v0, 13       			# analogicznie otwórz plik do zapisu wyników
	la	$a0, output_fname		
	li	$a1, 1				# flaga do zapisu
  	syscall          			
  	la	$t0, ofile_descriptor		
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# jeœli wyst¹pi³ b³¹d skocz do open_file_err
	
						
	la	$t0, putc_buf			
	sw	$t0, putc_buf_pointer		# ustaw wskaŸnik na pierwszy znak putc_buf( przygotowane na przysz³e wywo³ania putc)
process_file:
	jal	replace_labels			# znajdŸ definicje etykiet, zast¹p etykiety w tekœcie, zapisz zmieniony tekst do pliku
	jal	flush_buffer			# zapisz pozosta³e w putc_buf znaki do pliku
close_files:
	la	$a0, ifile_descriptor
	lw	$a0, ($a0)	
	li	$v0, 16				# zamknj plik wejœciowy	
	syscall					
	
	la	$a0, ofile_descriptor 		
	lw	$a0, ($a0)			
	li	$v0, 16				# zamknj plik wyjœciowy
	syscall					
exit:
	li 	$v0, 10				# zakoñcz program
  	syscall					
open_file_err:
	la	$a0, error_txt
	li	$v0, 4				# wyœwielt error_txt
	syscall					
	j	close_files
  	
#========================================================================================================================== 	
# replace_labels - funkcja zastêpuje zdefiniowane symbole w tekœcie ich rozwiniêciami
# plik wyjœciowy nie zawiera definicji symboli
# argumenty: brak
# zmienne:
# $s0 - wskaŸnik na wolne miejsce w labels
# $s1 - analizowany bajt pliku wejœciowego
# $s2 - wskaŸnik na word_buf
# $s3 - flaga stanu: 1 jeœli program jest w trakcie analizy definicji (wyst¹pi³ ':' i nie by³o znaku koñca linii)
#       2 gdy wyst¹pi '\r' w wierszu definicji, 0 - analiza zwyk³ego tekst
# procedura nic nie zwraca
replace_labels:
	subiu	$sp, $sp, 20			
	sw	$ra, 16($sp)			
	sw	$s0, 12($sp)			
	sw	$s1, 8($sp)			
	sw	$s2, 4($sp)
	sw	$s3, 0($sp)			
	
	li	$s3, 0				# ustaw flagê na 0	
	lw	$s0, labels_pointer		
	la	$s2, word_buf			
replace_labels_loop:
	jal	getc				# pobierz bajt
	move	$s1, $v0			
	sb	$s1, ($s2)			# zapisz znak w word_buf
	
	beq	$s1, ' ', end_of_word		
	bleu	$s1, '\r', end_of_line
	beq	$s1, ':', new_label		# napotkano koniec symbolu
	bltz	$s1, end_of_line		# jeœli -1 (EOF) sprawdŸ word_buf i zakoñcz procedurê
	
	addiu	$s2, $s2, 1			# inkrementacja wskaŸnika word_buf
	j	replace_labels_loop		# kolejny obieg pêtli
	
new_label:
	sb	$zero, 0($s2)			# zamieñ ':' na NULL na koñcu bufora
	li	$s3, 1 				# koniec nazwy symbolu - ustaw flagê na 1, zaczynamy wczytywaæ rozwiniêcie
	la	$a0, word_buf			
	move	$a1, $s2			# przygotuj argumenty dla funkcji copy
	move	$a2, $s0			
	jal	save_label			# zapisz nazwê symoblu w labels

	addiu	$s0, $s0, 24			# zaktualizuj wskaŸnik na wolne miejsce w labels						
	j 	next_word

end_of_line:
	beqz 	$s3, end_of_simple_word 	# jesli $s3 = 0 to koniec lini oznacza koniec s³owa
	beq	$s3, 2,end_of_line_after_label 	
	sb	$zero, 0($s2)			# w przeciwnym wypadku skoñczy³a siê definicja symbolu i trzeba j¹ zapisaæ 
	la	$a0, word_buf			# pocz¹tek definicji (argument dla copy)
	addiu	$a0, $a0, 1
	move	$a1, $s2			# koniec definicji
	move	$a2, $s0			# miejsce do zapisu ( wolne miejsce w labels)
	jal	save_label
	addiu	$s0, $s0, 24			# zaktualizuj wskaŸnik do labels ¿eby wskazywa³ na wolne miejsce
	bltz	$s1, replace_labels_ret		# jeœli $s1 < 0 zakoñcz procedurê
	li	$s3, 2
	j 	next_word
	
end_of_line_after_label:			# jeœli w³aœnie by³a definicja symbolu to pomiñ znak
	li	$s3, 0				# zaktualizuj $s3 na 0 (koniec lini z definicj¹ symbolu)
	j next_word				# przejdŸ do analizy kolejnych znaków

end_of_word:
	beq	$s3, 0, end_of_simple_word	# jesli $s3 = 0 to natrafilismy na koniec zwyklego slowa	(nie def)
	addiu	$s2, $s2, 1				# jesli $s3 = 1 to dalej wczytujemy definicjê, nie chcemy zerowac word_buf
	j replace_labels_loop			# przechodzimy do pocz¹tku pêtli
	
end_of_simple_word:										
	jal	check_is_word_symbol 		# sprawdzamy czy s³owo jest symbolem
	move	$t0, $v0			
	beq	$t0, -1, end_of_word_not_symbol	# jeœli nie to skok do end_of_word_not_symbol
	
end_of_word_symbol:				# jeœli tak to zapisz do pliku rozwiniêcie symbolu
	move 	$a0, $t0			# adres pocz¹tku rozwiniêcia				
	jal	put_str				
	move	$a0, $s1			
	jal	putc				# zapisz ostani bajt s³owa(LF/spacja)
	bltz	$s1, replace_labels_ret		# jeœli by³ koniec pliku wejœciowego to zakoñcz procedurê
	j	next_word			# przejdŸ do analizy kolejnych znaków
				
end_of_word_not_symbol:		
	sb	$zero, 1($s2)			# dopisz NULL na koñcu s³owa
	la	$a0, word_buf			# zapisz word_buf do pliku
	jal	put_str
	bltz	$s1, replace_labels_ret		# jeœli wyst¹pi³ koniec pliku wejœciowego to zakoñcz procedurê
next_word:
	la	$s2, word_buf			# zresetuj wskaŸnik na word_buf
	j	replace_labels_loop		# zacznij kolejny obieg pêtli
replace_labels_ret:
	lw	$s3, 0($sp)			
	lw	$s2, 4($sp)
	lw	$s1, 8($sp)			
	lw	$s0, 12($sp)			
	lw	$ra, 16($sp)				
	addiu	$sp, $sp, 20

	jr	$ra				# powrót

# =======================================================================================================
# save_label
# procedura kopiuje tekst ze Ÿród³a do wybranego miejsca (symbol/rozwiniêcie symbolu do miejsca na labele)
# argumenty:
# $a0 - adres Ÿród³owy (pocz¹tek)
# $a1 - koniec bufora (nie bêdzie kopiowany)
# $a2 - adres wolnego miejsca w labels
# zmienne: $t0 - zapisywany znak
# zwraca: brak

save_label:
	lbu	$t0, ($a0)			# skopiuj bajt z bufora
	sb	$t0, ($a2)			# zapisz bajt w miejscu docelowym
	addiu	$a0, $a0, 1			# zinkrementuj wskaŸniki
	addiu	$a2, $a2, 1			
	
	bne	$a0, $a1, save_label		# jeœli to nie koniec bufora - kolejny obieg pêtli

	jr	$ra				# powrót

# ==============================================================================================================
# check_is_word_symbol 
# procedura sprawdza czy s³owo jest symbolem, jeœli tak to zwraca rozwiniêcie symbolu, jeœli nie to zwraca -1
# argumenty: brak
# zmienne:
# $t0 - labels_pointer
# $t1 - wskaŸnik na kolejny znak etykiety address
# $t2 - adres word_buf
# $t3 - porównywany znak etykiety
# $t4 - porównywany znak s³owa
# $t5 - flaga = 1 jeœli etykieta siê skoñczy³a
# $t6 - flaga = 1 jeœli s³owo siê skoñczy³o 
# $t7 - przechowyje wynik operacji and/or
# zwraca: $v0 - adres pierwszego bajtu rozwiniêcia lub -1 jeœli s³owo nie jest symbolem
check_is_word_symbol :
	lw	$t0, labels_pointer		
	la	$t2, word_buf			
check_is_word_symbol_loop:
	move	$t1, $t0			# adres pocz¹tku etykiety
	lbu	$t3, ($t1)			# za³aduj kolejny bajt etykiety
	beqz	$t3, symbol_not_found		# NULL na pierwszym bajcie = brak etykiety, zakoñcz szukanie
compare:
	lbu	$t4, ($t2)			# za³aduj bajt word_buf
	lbu	$t3, ($t1)			# za³aduj bajt etykiety

	seq	$t5, $t3, $zero			# ustaw $t5=1 jeœli etykieta sie skoñczy³a
	sleu	$t6, $t4, ' '			# ustaw $t6=1 jeœli s³owo siê skoñczy³o
	and	$t7, $t5, $t6			
	bnez	$t7, symbol_found		# jeœli oba na raz siê skoñczy³y - symbol_found
	or	$t7, $t5, $t6 
	bnez	$t7, word_not_equal		# jeœli jedno z nich siê skoñczy³o porównaj z kolejn¹ etykiet¹
	
	addiu	$t1, $t1, 1			# zinkrementuj wskaŸniki
	addiu	$t2, $t2, 1			
	beq	$t3, $t4, compare		# porównaj znaki, jeœli takie same, porównaj kolejne znaki
word_not_equal:
	addiu	$t0, $t0, 48			# ustaw wskaŸnik na kolejn¹ etykietê
	la	$t2, word_buf			# ustaw wskaŸnik na pocz¹tek s³owa
	j 	check_is_word_symbol_loop
symbol_not_found:
	li	$v0, -1				# ustaw $v0=-1 - s³owo nie jest symbolem
	j 	check_is_word_symbol_ret
symbol_found:
	addiu	$t0, $t0, 24			# zapisz w $v0 adres rozwiniêcia etykiety
	move	$v0, $t0
check_is_word_symbol_ret:
	jr 	$ra				# powrót
	
# ====================================================================================================
# getc
# procedura zwraca kolejny znak z bufora, jeœli bufor jest pusty to najpierw odczutuje znaki z pliku
# argumenty: brak
# zmienne:
# $t0 - liczba bajtów w putc_buf
# $t1 - wskaŸnik na kolejny bajt
# $t2 - kolejny znak z getc_buf
# zwraca: $v0 - znak lub jeœli wyst¹pi³ koniec pliku 
getc:
	lhu	$t0, getc_chars_left		# liczba pozosta³ych znaków w getc_buf
	lw	$t1, getc_buf_pointer		# wskaŸnik do bufora
	bnez	$t0, get_char			# jeœli s¹ jeszcze znaki to przejdŸ do get_char
refresh_buf:
	li 	$v0, 14       			# pobierz z pliku kolejn¹ porcjê danych (512B)
	lw	$a0, ifile_descriptor		
  	la 	$a1, getc_buf   		# za³aduj adres getc_bupf
  	li 	$a2, BUF_LEN       		# BUF_LEN = 512
  	syscall          			
  	
  	move	$t0, $v0			# zapisz liczbê odczytanych znaków
  	sh	$v0, getc_chars_left		# zaktualizuj getc_chars_left
  	beqz	$t0, getc_eof			# jeœli nast¹pi³ koniec pliku (odczytano 0) to idŸ do getc_eof
  	la	$t1, getc_buf			# adres do bufora odczytanych znaków
  	sw	$t1, getc_buf_pointer		# ustaw wskaŸnik na pocz¹tek bufora
get_char:
	lbu	$t2, ($t1)			# za³aduj znak
	addiu	$t1, $t1, 1			# zaktualizuj wskaŸnik
	sw	$t1, getc_buf_pointer		# zapisz zaktualizowany wskaŸnik do getc_buf_pointer
	addiu	$t0, $t0, -1			# zmniejsz liczbê pozosta³ych znaków
	sh	$t0, getc_chars_left		# zaktualizuj getc_chars_left
	move	$v0, $t2			# zwróæ pobrany znak w $v0
	j	getc_return			
getc_eof:
	li	$v0, -1				# wyst¹pi³ koniec pliku (zwróæ -1)
getc_return:
	jr	$ra	

# ==================================================================================================
# putc
# procedura zapisuje znak do putc_buf, jeœli bufor siê zape³ni³ 
# to najpierw zapisuje jego zawartoœæ do pliku
# argumenty: $a0 - znak do zapisania
# zmienne:
# $s0 - znak do zapisania
# $s1 - liczba bajtów w buforze putc_buf
# $s2 - wskaŸnik na kolejny bajt bufora
putc:
	subiu	$sp, $sp, 16
	sw	$ra, 12($sp)			
	sw	$s0, 8($sp)			
	sw 	$s1, 4($sp)			
	sw 	$s2, 0($sp)			
	
	move 	$s0, $a0			# zapisz znak do zapisania
	lhu	$s1, putc_chars_left		# zaladuj liczbê pozosta³ych bajtów w buforze
	bnez	$s1, put_char			# jeœli bufor nie jest pe³ny skocz do putc_char
	jal	flush_buffer			# flush buffer
	lhu	$s1, putc_chars_left		# zaktualizuj
put_char:
	lw	$s2, putc_buf_pointer		# za³aduj wskaŸnik na kolejny znak bufora
	sb	$s0, ($s2)			# zapisz znak
	addiu	$s2, $s2, 1			
	sw	$s2, putc_buf_pointer		# zaktualizuj putc_buf_pointer
	addiu	$s1, $s1, -1			
	sh	$s1, putc_chars_left		# zaktualizuj licznik pozosta³ych do zapisania bajtów
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
# argumenty: $a0 - adres s³owa do zapisania
# zmienne:
# $s0 - wskaŸnik na kolejny bajt s³owa
# $s1 - aktualnie zapisywany bajt
put_str:
	subiu	$sp, $sp, 12
	sw	$ra, 8($sp)			
	sw	$s0, 4($sp)			
	sw 	$s1, 0($sp)					
	
	move	$s0, $a0			# przenieœ adres napisu do $s0
	lbu	$s1, ($s0)			# za³aduj kolejny znak napisu
put_str_loop:
	move	$a0, $s1			# przygotuj argument dla putc
	jal	putc				# funkcja zapisuj¹ca bajt
	addiu	$s0, $s0, 1			# zwiêksz wskaŸnik
	lbu	$s1, ($s0)			# za³aduj kolejny znak
	bnez	$s1, put_str_loop		# jeœli napis siê nie skoñczy³ powtórz pêtlê
put_str_return:					
	lw	$s1, 0($sp)					
	lw	$s0, 4($sp)						
	lw	$ra, 8($sp)						
	addiu	$sp, $sp, 12
	
	jr	$ra				# powrót
# =================================================================================================
# flush_buffer
# procedura zapisuje zawartoœæ putc_buf do pliku wyjœciowego
# argumenty: brak
# zmienne:
# $t0 - zawartoœæ BUF_LEN
# $t1 - zawartoœæ putc_chars_left
# $t2 - wskaŸnik na putc_buf
flush_buffer:
	li	$t0, BUF_LEN			# 512
	lhu	$t1, putc_chars_left		# liczba pozosta³ych bajtów do zapisania w putc_buf
	
	lw	$a0, ofile_descriptor		
  	la 	$a1, putc_buf   		# adres bufora, z którego chcemy zapisaæ
  	subu	$a2, $t0, $t1			# oblicz ile znaków bêdzie zapisywanych
  	li 	$v0, 15       			# numer funkcji zapisu do pliku
  	syscall  
  	      			
  	sh	$t0, putc_chars_left		# zaktualizuj putc_chars_left na 512
  	la	$t2, putc_buf			# za³aduj adres putc_buf
  	sw	$t2, putc_buf_pointer		# ustaw wskaŸnik na pocz¹tek bufora (reset bufora)
  	
  	jr	$ra
