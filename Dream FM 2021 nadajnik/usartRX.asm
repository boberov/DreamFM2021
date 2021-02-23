;===========================================================
;==================== Dream FM 2021  =======================
;===================== usartRX.asm =========================
;===========================================================
;parsowanie danych z usartu i wykonywanie rozkazow
;===========================================================

.equ LF_CHAR			=13
.equ LF_Tout			=int(30*2)						
.equ FTAB_SIZE 			=6 									;ilosc wpisow w tablicy

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
.db "TXshd",0x00									
.dw tx_shdwn
.db "TXoff",0x00									
.dw tx_disable
.db "TXon",0x00,0x00										
.dw tx_enable
.db "TXpow",0x01											;odczytywany parametr na koncu ciagu o dlugosci od 1B
.dw tx_power
.db "TXfrq",0x01											;parametr moze miec 4 lub 5B 					
.dw tx_freq
.db "TXdim",0x01
.dw tx_dimmer
default_ret:
ret


;------------------USART0_RX_IRQ----------------------------
;--zapis odebranych bajtow do bufora kolowego---------------
;normalnie to jest przerwanie URX:
URX_irq:

		sbr		SysFlags, 1<<MeasCancel_f
		in		r2,sreg
		push 	r16
		push 	r30
		push 	r31
;		in	 	r16,USR
;		sbrs 	r16,RXC
;		rjmp 	USART_no_CharRX
		clear	URXtoutC									;timeot odbioru danych

		ldiwz	URXbuffer									;bufor danych
		
		lds		r16,URXpWR									;wskaznik zapisu
	
		add		r30,r16
		adc		r31,zero

		in	 	r16,UDR
	
		cpi		r16,LF_CHAR									;line feed wymusza przeparsowanie linii
		brne	no_lineend									;uwaga bajt konca linii nie jest wpisywany do bufora
		sti		URXtoutC,LF_Tout-1
		;rcall	usart_rx_buffer
		rjmp	USART_no_CharRX		
no_lineend:	
		st		z,r16
		lds		r16,URXpWR
		inc		r16
		andi	r16,RXB_SIZE-1
		sts		URXpWR,r16
USART_no_CharRX:
		pop 	r31
		pop 	r30
		pop 	r16
		out		sreg,r2

reti
;-----------------------------------------------------------

usart_rx_buffer:
;-------------------timeout--------------------------------
		lds		r16,URXtoutC
		cpi		r16,LF_Tout									;timeout z URXtoutC
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

	
		ldiwz	code_table*2								;tablica stringow i adresow funkcji
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
		cpi		r21,FTAB_SIZE
		breq	pc+2
		rjmp	compcirqbuf0
 		clz
ret



;-----------------------------------------------------------
;============== wykonywanie rozkazow =======================
;-----------------------------------------------------------
tx_shdwn:
		;rcall	RFTX_disable
		rcall 	usart_nl
		rcall	ok_string
		rjmp 	powerdown_loop
;-----------------------------------------------------------
tx_disable:
		rcall	RFTX_disable
		rcall 	usart_nl
		rjmp	ok_string
ret

tx_enable:
		sbic	LMX_port,RF_ENABLE							;jesli tx wlaczony nie wlaczaj ponownie
		rjmp	ret2

		rcall	RFTX_enable
		rcall 	usart_nl
		rjmp	ok_string
ret
tx_power:
		rcall	load_B
		rcall 	usart_nl
		sts		txpower,r16
		rcall	tx_powerset
		rjmp	ok_string

tx_freq:
		rcall 	usart_nl
		ldiwx	URXparam
		ld		r16,x+
		cpi		r16,5+1										;dwa znaki asci na waartosc hex
		brsh	bad_param									;nieprawidlowa dlugosc parametru
		cpi		r16,3+1
		brlo	bad_param		
		rcall	paramto_txfreq

		cpiw	r30,r31,BAND_LOW_MHZ
		brlo	bad_param
		
		cpiw	r30,r31,BAND_HIGH_MHZ+1
		brsh	bad_param


		storew	LMXfreqMHz10,r30,r31
		sti		LMXfreqMHz10+2,0
		rcall	LMX2306_TuneOnly
		ldiwx	TMPdata
		rjmp	ok_string
bad_param:
ret

tx_dimmer:													;program uzywany do zmiany soft pwm po odebraniu rozkazu TXdimX
		rcall	load_B
		rcall 	usart_nl
		mov		softPWmV,r16
		rjmp	ok_string												
paramto_txfreq:
		ldiwz	0
;------x1000--------
		ld		r17,x+	
		cpi		r17,'0'
		breq	MSD_zero
		cpi		r17,'1'
		breq	MSD_one
		rjmp	no_1000x
MSD_one:
		ldiwz	1000
MSD_zero:
;-------x100--------
		ld		r17,x+	
no_1000x:													;jesli pierwsza cyfra to nie zero ani jeden wtedy jest uwazana zacyfre 10xMHz
		subi	r17,'0'
		ldi		r21,100
		rcall	mul_sbstR17R21
		add		r30,r0
		adc		r31,r1
;-------x10---------
		ld		r17,x+										;Pozycja MHz
		subi	r17,'0'
		ldi		r21,10
		rcall	mul_sbstR17R21
		add		r30,r0
		adc		r31,r1
;-------------------
		ld		r17,x+										;separator '.' (lub cokolwiek innego)
;-------x1----------
		ld		r17,x+										;setki kHz
		subi	r17,'0'
		add		r30,r17
		adc		r31,zero
ret
;-----------------------------------------------------------
;pobieranie bajtu z parametru w hex
load_B:
		ldiwx	URXparam+1	
		ld		r16,x+										;MSN starsze nibble
		rcall	hex_To_bin
		mov		r17,r16
		ld		r16,x+	
		rcall	hex_To_bin
		swap 	r17
		or		r16,r17
ret
hex_To_bin:
		cpi		r16,':'
		brlo	numbers_msb
		subi 	r16,'A'-0x0A
		rjmp	lett_msb
numbers_msb:
		subi 	R16,'0'
lett_msb:
		andi	r16,0x0F
ret	

/*
dd_loop:
	ld		r16,x+
	rcall	usartsend_hex
	dec		r17
	brne	dd_loop
	rjmp	ok_string
*/
