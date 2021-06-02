    bits    32
    segment .text
    global contrast

contrast:
	; prolog
    push	ebp
    mov  	ebp, esp
    push	ebx
    push	esi
    push 	edi
	mov 	ecx,[ebp+8]		; *img
	mov 	eax,[ebp+12]	; szerokość obrazka
	mov 	edx,[ebp+16]	; wysokość obrazka

	; liczę rozmiar bitmapy
	mul 	edx					; eax = eax * edx (width * height)
	lea		eax, [eax + eax*2]	; eax *= 3

	mov 	edi, eax			; zapamiętuję rozmiar w edi na potem
	xor 	edx, edx			; sprzatam

;		 REJESTRY:
; eax - licznik pętli
; ecx - *img
; edx - dl do porownywania
; ebx - bh=max bl=min
; esi -
; edi - rozmiar

	xor		bh, bh			; początkowo max = 0
	mov 	bl, 255			; min = 255

;szukam min/max składowej
findMinMax:
	mov     dl, [ecx]		; jesli skladowa > max, max = skladowa
	cmp		dl, bh
	jbe		checkIfMin		; skocz jesli bh <= max
	mov		bh, dl			; w przeciwnym razie ustaw max = bh
checkIfMin:
	cmp 	dl, bl			; jesli skladowa < min, min = bajt
	ja		getNext			; skocz jesli bl >= min
	mov 	bl, dl
getNext:
	inc 	ecx					; przejdz do kolejnego bajtu
	dec 	eax					; zmniejsz licznik
	jnz 	findMinMax

; przeskalowanie: val = (val - min)/(max - min) * 256

	sub ecx, edi			; ustaw ecx na poczatek bitmapy
	sub bh, bl				; (bh = max - min), nadpisuje max, ale już nie bedzie potrzebny
	movzx si, bh

;		 REJESTRY:
; eax - nowa wartosc skladowej
; ecx - *img
; edx -
; ebx - bh=max - min, bl=min
; esi - uzywany przy dzieleniu
; edi - licznik petli

countPixVal:
	xor		edx, edx	; zerujemy po poprzednim obiegu
	mov		ah, [ecx]	; ax = val
	sub		ah, bl
	shl		ax, 8
	div		bh
	;sub		al, bl		; val = val - min
	;div		si			; val /= max - min
	;shl		eax, 8		; val *= 256
	cmp 	al, 255	; sprawdz czy składowa > 255
	jbe		nextVal
	mov     al, 255
nextVal:
	mov		[ecx], al
	inc		ecx
	dec		edi
	jnz		countPixVal


; epilog
    pop 	edi
    pop 	esi
    pop 	ebx
    pop 	ebp
    ret
