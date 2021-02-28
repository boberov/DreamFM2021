;=================================================================
;================== Dream FM 2021 VFD saver ======================
;======================= usartRX.asm =============================
;=================================================================

;parsowanie danych z usartu i wykonywanie zadan

;-----------------------------------------------------------
.equ 	ASC_TAB_MAX 	=2									;ilosc wpisow w tablicy
code_table:
/*
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
.db "VSvfd",0x01									
.dw vfd_level
.db "VSled",0x01									
.dw led_level
;.db 0x1B,0x5B,0x44,0x00,0x00,0x00								;curLeft
;.dw curLeft_key												;callback					
;.db 0x1B,0x5B,0x43,0x00,0x00,0x00								;curRight
;.dw curRight_key	
																				
;------------------USART0_RX_IRQ----------------------------
;--zapis odebranych bajtow do bufora kolowego---------------------
;-----------------------------------------------------------
USART0RXC_IRQ:
;usart_rx_write:		
		in		r2,CPU_SREG
		push		r16
		push 	r30
		push 	r31
		clr		URXtoutCh	
		clr		URXtoutCl									;timeot odbioru danych

		ldiwz	URXbuffer									;bufor danych
		
		lds		r16,URXpWR									;wskaznik zapisu
	
		add		r30,r16
		adc		r31,zero

		lds	 	r16,USART0_RXDATAL
	

		cpi		r16,LF_CHAR									;line feed wymusza przeparsowanie linii
		brne		no_lineend									;uwaga bajt konca linii nie jest wpisywany do bufora
		ldi		r16,LF_Tout-1
		mov		URXtoutCh,r16
		rjmp		retur_0		
no_lineend:	
		st		z,r16
		lds		r16,URXpWR
		inc		r16
		andi		r16,RXB_SIZE-1
		sts		URXpWR,r16
retur_0:
		pop		r31
		pop		r30
USART_no_CharRX:
		STI		USART0_STATUS, USART_RXSIF_bm				;kasowanie flagi
		pop 		r16
		out		CPU_SREG,r2
reti
;-----------------------------------------------------------
usart_rx_buffer:
		add		URXtoutCl,one						
		adc		URXtoutCh,zero							
		brcc 	pc+2									
		dec		URXtoutCh								

		brcc 	pc+2										
		dec		URXtoutCl								

		cpi		URXtoutCh,LF_Tout							;1CK timeout z URXtoutC
		brne		nochar_in_buf								;2CK po odebraniu bajtu usartem czekany czas timeout zanim sciagany bufor
;-----------------------------------------------------------

;----------------odbior klawiszy----------------------------															
		lds		r19,URXpWR
		lds		r20,URXpRD

		cp		r19,r20
		breq		noma	
		rcall	compare_string_buf							;tu jest ladowany adres do Z dla ijmp
		brne		noma										;sprawdzany sreg, czy rozpoznany string z bufora
		sts		URXpRD,r19
nothesame_key:
		ijmp	
noma:														;wszystko wyciagnieto z bufora
		sts		URXpRD,r19									;wskaznik bufora odczytu = bufora zapisu
nochar_in_buf:
ret
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;porownywanie ciagow na buforze kolowym
;zwracanie numeru wpisu oraz adresu callbacka z tablicy
;dodatnkowo obsluga 7B parametru dla wybranych rozkazow
;-----------------------------------------------------------------
compare_string_buf:
	
		clr		r4											;licznik ilosci bajtow parametru
															;pamietac nalezy, ze dluzsze ciagi o takim samym poczatku jak krotkie musza byc porownywane wczesniej aby zostaly rozpoznane
		ldi 	r21,0 											;nr indexu porownywanego stringu											
compcirqbuf0:
		ldiwx	URXparam+PARAM_SIZE
		ldi		r17,8
clrParam_loop:
		st 		-x,zero
		dec		r17
		brne	clrParam_loop
		adiw	x,1												;bajt0 zmiennej parameter zawiera ilosc zapisanych bajtow - max7

	
		ldiwz	code_table*2									;tablica rozkazow i adresow funkcji
		lds		r20,URXpRD

		ldi		r17,6+2										;offset wpisu w tablice (3B cursor, 5B klawisze F1 F2...)
		mul		r17,r21
		
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
		cpi 	r16,PARAM_SIZE									;zabezpiecza ram
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
		brne	unequal											;niezgodny bajt porownaj kolejny wpis
			
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
		mul		r17,r21

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
;-----------------------------------------------------------------

;-----------------------------------------------------------
;============== wykonywanie rozkazow =======================
;-----------------------------------------------------------

vfd_level:
		set													;flaga t rorzonia pomiedzy zapisem fazy lub statusu
		rjmp 	rw_param	
led_level:
		clt
rw_param:
		ldiwx	URXparam
		ld		r16,x+
		cpi		r16,2										;dwa znaki asci na waartosc hex
		brne		bad_param									;nieprawidlowa dlugosc parametru
		ld		r16,x+										;MSN starsze nibble
		rcall	hex_To_bin
		mov		r17,r16
		ld		r16,x+										;MSN starsze nibble
		rcall	hex_To_bin
		swap 	r17
		or		r16,r17
		
		brts		pc+3
		sts		ledVoltage,r16
		brtc		pc+3
		sts		vfdVoltage,r16

		rcall	usartsend_hex
		rcall	ok_string
bad_param:
ret

;-----------------------------------------------------------	
;zamiana nibble asci Hex na bin :R16 -> R16
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
							
ok_string:
		ldi		r16,'O'
		rcall	usartsend
		ldi 		r16,'K'
		rcall	usartsend
		rjmp		lf_print
;-----------------------------------------------------------