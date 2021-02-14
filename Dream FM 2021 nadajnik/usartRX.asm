;===========================================================
;==================== Dream FM 2021  =======================
;===================== usartRX.asm =========================
;===========================================================
;parsowanie danych z usartu i wykonywanie zadan

.equ LF_CHAR			=10
.equ LF_Tout			=int(61*1)						
.equ ASC_TAB_MAX 		=3 								;ilosc wpisow w tablicy

code_table:
/*
.db 0x1B,0x5B,0x44,0x00,0x00,0x00							;curLeft
.dw curLeft_key												;callback					
.db 0x1B,0x5B,0x43,0x00,0x00,0x00							;curRight
.dw curRight_key	
.db 0x1B,0x5B,0x42,0x00,0x00,0x00							;curUp
.dw curDown_key 	
.db 0x1B,0x5B,0x41,0x00,0x00,0x00							;curDown
.dw curUp_key	
.db 0x1B,0x5B,0x31,0x31,0x7E,0x00							;F1
.dw f1_key
.db 0x1B,0x5B,0x31,0x32,0x7E,0x00							;F2
.dw f2_key	
.db 0x1B,0x5B,0x31,0x33,0x7E,0x00							;F3
.dw f3_key	
.db 0x1B,0x5B,0x31,0x34,0x7E,0x00							;F4
.dw f4_key	
.db 0x1B,0x5B,0x31,0x35,0x7E,0x00							;F5
.dw f5_key		
.db 0x1B,0x5B,0x32,0x30,0x7E,0x00							;F9
.dw f9_key
.db 0x1B,0x5B,0x32,0x33,0x7E,0x00							;F11
.dw default_ret	
.db 0x1B,0x5B,0x32,0x34,0x7E,0x00							;F12
.dw default_ret
*/

;pamietaj 6B+2B adresu na index
.db "TXoff",0x00									
.dw tx_disable
.db "TXon",0x00,0x00										
.dw tx_enable
.db "TXpow",0x01											;odczytywany parametr na koncu ciagu o dlugosci od 1 do 7B
.dw tx_power

default_ret:
ret


;------------------USART0_RX_IRQ----------------------------
;--zapis odebranych bajtow do bufora kolowego---------------
;normalnie to jest przerwanie URX:
usart_rx_write:		
		in	 	r16,USR
		sbrs 	r16,RXC
		rjmp 	USART_no_CharRX
		clear	URXtoutC									;timeot odbioru danych

		ldiwz	URXbuffer									;bufor danych
		
		lds		r16,URXpWR									;wskaznik zapisu
	
		add		r30,r16
		adc		r31,zero

		in	 	r16,UDR
	

		cpi		r16,LF_CHAR									;line feed wymusza przeparsowanie linii
		brne	no_lineend									;uwaga bajt konca linii nie jest wpisywany do bufora
		sti		URXtoutC,LF_Tout-1
		ret		
no_lineend:	
		st		z,r16
		lds		r16,URXpWR
		inc		r16
		andi	r16,RXB_SIZE-1
		sts		URXpWR,r16
USART_no_CharRX:
ret
;-----------------------------------------------------------

usart_rx_buffer:
;-------------------timeout--------------------------------
		incrs	URXtoutC
		cpi		r16,LF_Tout										;timeout z URXtoutC
		brne	nochar_in_buf								;po odebraniu bajtu usartem czekany czas timeout zanim sciagany bufor
;----------------odbior klawiszy----------------------------															
		lds		r19,URXpWR
		lds		r20,URXpRD

		cp		r19,r20
		breq	nochar_in_buf	
		rcall	compare_string_buf							;tu jest ladowany adres do Z dla ijmp
		brne	noma										;sprawdzany sreg, czy rozpoznany string z bufora
		sts		URXpRD,r19
nothesame_key:
		icall	
		ret
noma:														;wszystko wyciagnieto z bufora
		sts		URXpRD,r19									;wskaznik bufora odczytu = bufora zapisu
nochar_in_buf:
ret
;-----------------------------------------------------------

;-----------------------------------------------------------
;porownywanie ciagow na buforze kolowym
;zwracanie numeru wpisu oraz adresu callbacka z tablicy
;dodatnkowo obsluga 7B parametru dla wybranych rozkazow
;-----------------------------------------------------------
compare_string_buf:
	
		clr		r4											;licznik ilosci bajtow parametru
															;pamietac nalezy, ze dluzsze ciagi o takim samym poczatku jak krotkie musza byc porownywane wczesniej aby zostaly rozpoznane
		ldi 	r21,0 										;nr indexu porownywanego stringu											
compcirqbuf0:
		ldiwx	URXparam+PARAM_SIZE
		ldi		r17,8
clrParam_loop:
		st 		-x,zero
		dec		r17
		brne	clrParam_loop
		adiw	x,1											;bajt0 zmiennej parameter zawiera ilosc zapisanych bajtow - max7

	
		ldiwz	code_table*2							;tablica stringow i adresow funkcji
		lds		r20,URXpRD

		ldi		r17,6+2										;offset wpisu w tablice (3B cursor, 5B klawisze F1 F2...)

		rcall	mul_sbstR17R21
		
		add		zl,r0
		adc		zh,r1
compcirqbufcomp:
		ldiwy	URXbuffer									;bufor w ram
		add		r28,r20										;adres + wskaznik
		adc		r29,zero
		ld		r17,y

		lpm
	
		inc		r20											;kolejny bajt
		andi	r20,RXB_SIZE-1

;----odczyt parametru do RAM z X------
		cp		r0,zero
		breq	no_param
		
		ldi		r16,0x04
		cp		r0,r16
		brsh	no_param	


		mov		r16,r4
		cpi 	r16,PARAM_SIZE								;zabezpiecza ram
		brsh	unequal	
		
		st		x+,r17
		inc		r4
		sts		URXparam+0,r4								;pierwszy bajt parametru zawiera ilosc bajtow danych parametru	
		cp		r19, r20									;sprawdzanie na rownosc wskaznikow
		brne	compcirqbufcomp	
		rjmp	exit_param
no_param:
;--------------------------
		adiw 	z,1	

		cp		r17,r0										;porownuje bufor ram z ciagiem w rom
		brne	unequal										;niezgodny bajt porownaj kolejny wpis
			
		cp		r19, r20									;
		brne	compcirqbufcomp	

		lpm
		adiw 	z,1	
		cp		r0,zero										;jesli wszystkie bajty z tablicy porownane ostatni =0,lepiej bylo by tu porownac rzeczywista ilosc odczytanych bajtow
		brne	unequal
exit_param:
;------odczyt adresu funkcji-----------
		ldiwz	code_table*2

		ldi		r17,6+2										;offset wpisu w tablice (3B cursor, 5B klawisze F1 F2...)
		rcall	mul_sbstR17R21

		add		zl,r0
		adc		zh,r1
		adiw 	z,6											;offset B stringu

		lpm
		mov		r28,r0
		adiw 	z,1	
		lpm
		mov		r30,r28
		mov		r31,r0
		sez
ret
unequal:
		inc		r21
		cpi		r21,ASC_TAB_MAX
		breq	pc+2
		rjmp	compcirqbuf0
 		clz
ret
;-----------------------------------------------------------

;-----------------------------------------------------------
tx_disable:
	rcall	RFTX_disable
		rcall 	usart_nl
	rjmp	ok_string
ret

tx_enable:
		sbic	LMX_port,RF_ENABLE							;jesli tx wylaczony niewlaczaj ponownie
		rjmp	ret2

		rcall	RFTX_enable
		rcall 	usart_nl
		rjmp	ok_string
ret
tx_power:
	;w r19 wskaznik odczytu
	ldiwx	URXparam									;bufor w ram
	ld		r17,x+
	;cpi 	r17,0
	;brne	dd_loop
	;ret
		rcall 	usart_nl

		ldi 	r16,'P'
		rcall	usartsend
		ldi 	r16,'O'
		rcall	usartsend
		ldi 	r16,'W'
		rcall	usartsend

	ld		r16,x
	subi	r16,'0'
	sts		txpower,r16
	rcall	tx_powerset
ret

dd_loop:
	ld		r16,x+
	rcall	usartsend_hex
	dec		r17
	brne	dd_loop
	rjmp	ok_string

ok_string:
	ldi 	r16,'O'
	rcall	usartsend
	ldi 	r16,'K'
	rcall	usartsend
	rjmp	lf_print
;-----------------------------------------------------------


;substytut rozkazu mul
mul_sbstR17R21:


;***************************************************************************
;*
;* "mpy8u" - 8x8 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two register variables mp8u and mc8u.
;* The result is placed in registers m8uH, m8uL
;*  
;* Number of words	:34 + return
;* Number of cycles	:34 + return
;* Low registers used	:None
;* High registers used  :3 (mc8u,mp8u/m8uL,m8uH)	
;*
;* Note: Result Low byte and the multiplier share the same register.
;* This causes the multiplier to be overwritten by the result.
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	mc8u	=r17	;multiplicand
.def	mp8u	=r21	;multiplier
.def	m8uL	=r21	;result Low byte
.def	m8uH	=r1		;result High byte

	push	mc8u
	push	mp8u
;***** Code

mpy8u:	
	clr	m8uH		;clear result High byte
	lsr	mp8u		;shift multiplier
	
	brcc	noad80		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad80:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad81		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad81:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad82		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad82:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad83		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad83:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad84		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad84:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad85		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad85:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc noad86		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad86:	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad87		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad87:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier	

;****
	mov		r0,r21
	pop		mp8u
	pop		mc8u
ret

.exit
;------przyspieszacz gdy trzymany guzik--------------------
;nie jest to idealne jesli pomiar czasu 1 na sekunde
;ale nie ma potrzeby zeby ten mechanizm dzialal precyzyjniej
long_pressKey:
		lds		r16,repKeyHz
		cpi		r16,10										;ile powtorzen odebranych w cagu sekundy
		brlo	noConti_press

		lds		r16,repkeyC
		ldi		r17,1										;itteracja x1
		cpi 	r16,2
		brlo	pc+2
		ldi		r17,10										;itteracja x10 po 3s
		cpi		r16,5							
		brlo	pc+2
		ldi		r17,100										;itteracja x100 po 6 sekundach

		inc		r16
		brne	pc+2
		dec		r16
		sts 	repkeyC,r16									;licznik pomocniczy
		sts		repkeyD,r17									;mnoznik -szybkosc zmian (symulacja pokretla dial)
		clear	repKeyHz									;licznik czestotliwosci przychodzacego klawisza
		ret
noConti_press:
		clear	repKeyHz
		clear	repkeyC
		sti		repkeyD,1
ret
;-----------------------------------------------------------
