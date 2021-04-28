# ZADANIE 2
# Program przetwarza plik tekstowy zwierający definicje symboli-nazw i inny tekst,
# zawierający zdefiniowane symbole. Definicja rozpoczyna się w pierwszej kolumnie tekstu i
# składa się z nazwy, po której następuje znak dwukropka i ciągu znaków, rozpoczynającego
# się od pierwszego znaku nie będącego odstępem i kończącego ostatnim znakiem nie
# będącym odstępem w wierszu definicji.Program tworzy plik wyjściowy nie zawierający definicji symboli,
# w którym w pozostałym tekście zastąpiono zdefiniowane symbole ich rozwinięciami

# program może przechowywać 50 etykiet
# max. rozmiar etykiety to 48B (23B na nazwę etykiety + 1B na ':', 22B na rozwinięcie + 2B na znaki odstępu)

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
	la	$a0, prompt			# wyświetl komunikat
	li	$v0, 4
	syscall
	
	li	$v0, 8				# wczytaj nazwę pliku wejściowego
	la 	$a0, fname
	li	$a1, 64
	syscall
					
	la 	$t0, fname
	la	$t2, good_fname
prepare_fname:					# usuń '\n' z konca fname
	lbu 	$t1, ($t0)
	bleu 	$t1, '\n', allocate_memory
	sb	$t1, ($t2)
	addiu	$t0, $t0, 1
	addiu	$t2, $t2, 1
	b prepare_fname
	
allocate_memory:				# przydziel pamięć dla  definicji etykiet
	sb	$zero, ($t2)
	li	$v0, 9				# numer funkcji sbrk
	li	$a0, LABELS_SIZE		# załaduj liczbę bajtów do alokacji
	syscall					
	la	$s1, labels_pointer		# załaduj adres labels_pointer
	sw	$v0, ($s1)			# zapisz adres zaalokowanej pamięci
open_files:
	li 	$v0, 13       			# otwórz plik wejściowy
	la	$a0, good_fname			
	li	$a1, 0				# ustaw flagę do odczytu
  	syscall          			# uchwyt do pliku zwrócony w $v0
  	la	$t0, ifile_descriptor
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# jeśli wystąpił błąd skocz do open_file_err
	
	li 	$v0, 13       			# analogicznie otwórz plik do zapisu wyników
	la	$a0, output_fname		
	li	$a1, 1				# flaga do zapisu
  	syscall          			
  	la	$t0, ofile_descriptor		
  	sw	$v0, ($t0) 			# zapisz uchwyt do pliku
	bltz	$v0, open_file_err		# jeśli wystąpił błąd skocz do open_file_err
	
						
	la	$t0, putc_buf			
	sw	$t0, putc_buf_pointer		# ustaw wskaźnik na pierwszy znak putc_buf( przygotowane na przyszłe wywołania putc)
process_file:
	jal	replace_labels			# znajdź definicje etykiet, zastąp etykiety w tekście, zapisz zmieniony tekst do pliku
	jal	flush_buffer			# zapisz pozostałe w putc_buf znaki do pliku
close_files:
	la	$a0, ifile_descriptor
	lw	$a0, ($a0)	
	li	$v0, 16				# zamknj plik wejściowy	
	syscall					
	
	la	$a0, ofile_descriptor 		
	lw	$a0, ($a0)			
	li	$v0, 16				# zamknj plik wyjściowy
	syscall					
exit:
	li 	$v0, 10				# zakończ program
  	syscall					
open_file_err:
	la	$a0, error_txt
	li	$v0, 4				# wyświelt error_txt
	syscall					
	j	close_files
  	
#========================================================================================================================== 	
# replace_labels - funkcja zastępuje zdefiniowane symbole w tekście ich rozwinięciami
# plik wyjściowy nie zawiera definicji symboli
# argumenty: brak
# zmienne:
# $s0 - wskaźnik na wolne miejsce w labels
# $s1 - analizowany bajt pliku wejściowego
# $s2 - wskaźnik na word_buf
# $s3 - flaga stanu: 1 jeśli program jest w trakcie analizy definicji (wystąpił ':' i nie było znaku końca linii)
#       2 gdy wystąpi '\r' w wierszu definicji, 0 - analiza zwykłego tekst
# procedura nic nie zwraca
replace_labels:
	subiu	$sp, $sp, 20			
	sw	$ra, 16($sp)			
	sw	$s0, 12($sp)			
	sw	$s1, 8($sp)			
	sw	$s2, 4($sp)
	sw	$s3, 0($sp)			
	
	li	$s3, 0				# ustaw flagę na 0	
	lw	$s0, labels_pointer		
	la	$s2, word_buf			
replace_labels_loop:
	jal	getc				# pobierz bajt
	move	$s1, $v0			
	sb	$s1, ($s2)			# zapisz znak w word_buf
	
	beq	$s1, ' ', end_of_word		
	bleu	$s1, '\r', end_of_line
	beq	$s1, ':', new_label		# napotkano koniec symbolu
	bltz	$s1, end_of_line		# jeśli -1 (EOF) sprawdź word_buf i zakończ procedurę
	
	addiu	$s2, $s2, 1			# inkrementacja wskaźnika word_buf
	j	replace_labels_loop		# kolejny obieg pętli
	
new_label:
	sb	$zero, 0($s2)			# zamień ':' na NULL na końcu bufora
	li	$s3, 1 				# koniec nazwy symbolu - ustaw flagę na 1, zaczynamy wczytywać rozwinięcie
	la	$a0, word_buf			
	move	$a1, $s2			# przygotuj argumenty dla funkcji copy
	move	$a2, $s0			
	jal	save_label			# zapisz nazwę symoblu w labels

	addiu	$s0, $s0, 24			# zaktualizuj wskaźnik na wolne miejsce w labels						
	j 	next_word

end_of_line:
	beqz 	$s3, end_of_simple_word 	# jesli $s3 = 0 to koniec lini oznacza koniec słowa
	beq	$s3, 2,end_of_line_after_label 	
	sb	$zero, 0($s2)			# w przeciwnym wypadku skończyła się definicja symbolu i trzeba ją zapisać 
	la	$a0, word_buf			# początek definicji (argument dla copy)
	addiu	$a0, $a0, 1
	move	$a1, $s2			# koniec definicji
	move	$a2, $s0			# miejsce do zapisu ( wolne miejsce w labels)
	jal	save_label
	addiu	$s0, $s0, 24			# zaktualizuj wskaźnik do labels żeby wskazywał na wolne miejsce
	bltz	$s1, replace_labels_ret		# jeśli $s1 < 0 zakończ procedurę
	li	$s3, 2
	j 	next_word
	
end_of_line_after_label:			# jeśli właśnie była definicja symbolu to pomiń znak
	li	$s3, 0				# zaktualizuj $s3 na 0 (koniec lini z definicją symbolu)
	j next_word				# przejdź do analizy kolejnych znaków

end_of_word:
	beq	$s3, 0, end_of_simple_word	# jesli $s3 = 0 to natrafilismy na koniec zwyklego slowa	(nie def)
	addiu	$s2, $s2, 1				# jesli $s3 = 1 to dalej wczytujemy definicję, nie chcemy zerowac word_buf
	j replace_labels_loop			# przechodzimy do początku pętli
	
end_of_simple_word:										
	jal	check_is_word_symbol 		# sprawdzamy czy słowo jest symbolem
	move	$t0, $v0			
	beq	$t0, -1, end_of_word_not_symbol	# jeśli nie to skok do end_of_word_not_symbol
	
end_of_word_symbol:				# jeśli tak to zapisz do pliku rozwinięcie symbolu
	move 	$a0, $t0			# adres początku rozwinięcia				
	jal	put_str				
	move	$a0, $s1			
	jal	putc				# zapisz ostani bajt słowa(LF/spacja)
	bltz	$s1, replace_labels_ret		# jeśli był koniec pliku wejściowego to zakończ procedurę
	j	next_word			# przejdź do analizy kolejnych znaków
				
end_of_word_not_symbol:		
	sb	$zero, 1($s2)			# dopisz NULL na końcu słowa
	la	$a0, word_buf			# zapisz word_buf do pliku
	jal	put_str
	bltz	$s1, replace_labels_ret		# jeśli wystąpił koniec pliku wejściowego to zakończ procedurę
next_word:
	la	$s2, word_buf			# zresetuj wskaźnik na word_buf
	j	replace_labels_loop		# zacznij kolejny obieg pętli
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
# procedura kopiuje tekst ze źródła do wybranego miejsca (symbol/rozwinięcie symbolu do miejsca na labele)
# argumenty:
# $a0 - adres źródłowy (początek)
# $a1 - koniec bufora (nie będzie kopiowany)
# $a2 - adres wolnego miejsca w labels
# zmienne: $t0 - zapisywany znak
# zwraca: brak

save_label:
	lbu	$t0, ($a0)			# skopiuj bajt z bufora
	sb	$t0, ($a2)			# zapisz bajt w miejscu docelowym
	addiu	$a0, $a0, 1			# zinkrementuj wskaźniki
	addiu	$a2, $a2, 1			
	
	bne	$a0, $a1, save_label		# jeśli to nie koniec bufora - kolejny obieg pętli

	jr	$ra				# powrót

# ==============================================================================================================
# check_is_word_symbol 
# procedura sprawdza czy słowo jest symbolem, jeśli tak to zwraca rozwinięcie symbolu, jeśli nie to zwraca -1
# argumenty: brak
# zmienne:
# $t0 - labels_pointer
# $t1 - wskaźnik na kolejny znak etykiety address
# $t2 - adres word_buf
# $t3 - porównywany znak etykiety
# $t4 - porównywany znak słowa
# $t5 - flaga = 1 jeśli etykieta się skończyła
# $t6 - flaga = 1 jeśli słowo się skończyło 
# $t7 - przechowyje wynik operacji and/or
# zwraca: $v0 - adres pierwszego bajtu rozwinięcia lub -1 jeśli słowo nie jest symbolem
check_is_word_symbol :
	lw	$t0, labels_pointer		
	la	$t2, word_buf			
check_is_word_symbol_loop:
	move	$t1, $t0			# adres początku etykiety
	lbu	$t3, ($t1)			# załaduj kolejny bajt etykiety
	beqz	$t3, symbol_not_found		# NULL na pierwszym bajcie = brak etykiety, zakończ szukanie
compare:
	lbu	$t4, ($t2)			# załaduj bajt word_buf
	lbu	$t3, ($t1)			# załaduj bajt etykiety

	seq	$t5, $t3, $zero			# ustaw $t5=1 jeśli etykieta sie skończyła
	sleu	$t6, $t4, ' '			# ustaw $t6=1 jeśli słowo się skończyło
	and	$t7, $t5, $t6			
	bnez	$t7, symbol_found		# jeśli oba na raz się skończyły - symbol_found
	or	$t7, $t5, $t6 
	bnez	$t7, word_not_equal		# jeśli jedno z nich się skończyło porównaj z kolejną etykietą
	
	addiu	$t1, $t1, 1			# zinkrementuj wskaźniki
	addiu	$t2, $t2, 1			
	beq	$t3, $t4, compare		# porównaj znaki, jeśli takie same, porównaj kolejne znaki
word_not_equal:
	addiu	$t0, $t0, 48			# ustaw wskaźnik na kolejną etykietę
	la	$t2, word_buf			# ustaw wskaźnik na początek słowa
	j 	check_is_word_symbol_loop
symbol_not_found:
	li	$v0, -1				# ustaw $v0=-1 - słowo nie jest symbolem
	j 	check_is_word_symbol_ret
symbol_found:
	addiu	$t0, $t0, 24			# zapisz w $v0 adres rozwinięcia etykiety
	move	$v0, $t0
check_is_word_symbol_ret:
	jr 	$ra				# powrót
	
# ====================================================================================================
# getc
# procedura zwraca kolejny znak z bufora, jeśli bufor jest pusty to najpierw odczutuje znaki z pliku
# argumenty: brak
# zmienne:
# $t0 - liczba bajtów w putc_buf
# $t1 - wskaźnik na kolejny bajt
# $t2 - kolejny znak z getc_buf
# zwraca: $v0 - znak lub jeśli wystąpił koniec pliku 
getc:
	lhu	$t0, getc_chars_left		# liczba pozostałych znaków w getc_buf
	lw	$t1, getc_buf_pointer		# wskaźnik do bufora
	bnez	$t0, get_char			# jeśli są jeszcze znaki to przejdź do get_char
refresh_buf:
	li 	$v0, 14       			# pobierz z pliku kolejną porcję danych (512B)
	lw	$a0, ifile_descriptor		
  	la 	$a1, getc_buf   		# załaduj adres getc_bupf
  	li 	$a2, BUF_LEN       		# BUF_LEN = 512
  	syscall          			
  	
  	move	$t0, $v0			# zapisz liczbę odczytanych znaków
  	sh	$v0, getc_chars_left		# zaktualizuj getc_chars_left
  	beqz	$t0, getc_eof			# jeśli nastąpił koniec pliku (odczytano 0) to idź do getc_eof
  	la	$t1, getc_buf			# adres do bufora odczytanych znaków
  	sw	$t1, getc_buf_pointer		# ustaw wskaźnik na początek bufora
get_char:
	lbu	$t2, ($t1)			# załaduj znak
	addiu	$t1, $t1, 1			# zaktualizuj wskaźnik
	sw	$t1, getc_buf_pointer		# zapisz zaktualizowany wskaźnik do getc_buf_pointer
	addiu	$t0, $t0, -1			# zmniejsz liczbę pozostałych znaków
	sh	$t0, getc_chars_left		# zaktualizuj getc_chars_left
	move	$v0, $t2			# zwróć pobrany znak w $v0
	j	getc_return			
getc_eof:
	li	$v0, -1				# wystąpił koniec pliku (zwróć -1)
getc_return:
	jr	$ra	

# ==================================================================================================
# putc
# procedura zapisuje znak do putc_buf, jeśli bufor się zapełnił 
# to najpierw zapisuje jego zawartość do pliku
# argumenty: $a0 - znak do zapisania
# zmienne:
# $s0 - znak do zapisania
# $s1 - liczba bajtów w buforze putc_buf
# $s2 - wskaźnik na kolejny bajt bufora
putc:
	subiu	$sp, $sp, 16
	sw	$ra, 12($sp)			
	sw	$s0, 8($sp)			
	sw 	$s1, 4($sp)			
	sw 	$s2, 0($sp)			
	
	move 	$s0, $a0			# zapisz znak do zapisania
	lhu	$s1, putc_chars_left		# zaladuj liczbę pozostałych bajtów w buforze
	bnez	$s1, put_char			# jeśli bufor nie jest pełny skocz do putc_char
	jal	flush_buffer			# flush buffer
	lhu	$s1, putc_chars_left		# zaktualizuj
put_char:
	lw	$s2, putc_buf_pointer		# załaduj wskaźnik na kolejny znak bufora
	sb	$s0, ($s2)			# zapisz znak
	addiu	$s2, $s2, 1			
	sw	$s2, putc_buf_pointer		# zaktualizuj putc_buf_pointer
	addiu	$s1, $s1, -1			
	sh	$s1, putc_chars_left		# zaktualizuj licznik pozostałych do zapisania bajtów
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
# argumenty: $a0 - adres słowa do zapisania
# zmienne:
# $s0 - wskaźnik na kolejny bajt słowa
# $s1 - aktualnie zapisywany bajt
put_str:
	subiu	$sp, $sp, 12
	sw	$ra, 8($sp)			
	sw	$s0, 4($sp)			
	sw 	$s1, 0($sp)					
	
	move	$s0, $a0			# przenieś adres napisu do $s0
	lbu	$s1, ($s0)			# załaduj kolejny znak napisu
put_str_loop:
	move	$a0, $s1			# przygotuj argument dla putc
	jal	putc				# funkcja zapisująca bajt
	addiu	$s0, $s0, 1			# zwiększ wskaźnik
	lbu	$s1, ($s0)			# załaduj kolejny znak
	bnez	$s1, put_str_loop		# jeśli napis się nie skończył powtórz pętlę
put_str_return:					
	lw	$s1, 0($sp)					
	lw	$s0, 4($sp)						
	lw	$ra, 8($sp)						
	addiu	$sp, $sp, 12
	
	jr	$ra				# powrót
# =================================================================================================
# flush_buffer
# procedura zapisuje zawartość putc_buf do pliku wyjściowego
# argumenty: brak
# zmienne:
# $t0 - zawartość BUF_LEN
# $t1 - zawartość putc_chars_left
# $t2 - wskaźnik na putc_buf
flush_buffer:
	li	$t0, BUF_LEN			# 512
	lhu	$t1, putc_chars_left		# liczba pozostałych bajtów do zapisania w putc_buf
	
	lw	$a0, ofile_descriptor		
  	la 	$a1, putc_buf   		# adres bufora, z którego chcemy zapisać
  	subu	$a2, $t0, $t1			# oblicz ile znaków będzie zapisywanych
  	li 	$v0, 15       			# numer funkcji zapisu do pliku
  	syscall  
  	      			
  	sh	$t0, putc_chars_left		# zaktualizuj putc_chars_left na 512
  	la	$t2, putc_buf			# załaduj adres putc_buf
  	sw	$t2, putc_buf_pointer		# ustaw wskaźnik na początek bufora (reset bufora)
  	
  	jr	$ra
