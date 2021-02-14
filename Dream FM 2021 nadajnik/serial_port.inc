;===========================================================
;===================== Icebox 2020 =========================
;=================== serial_port.inc =======================
;===========================================================

;-----------------------------------------------------------
;-----------------usart wyswietlanie------------------------
convin16bindec:
		sts 	conv_in+0,r16
		sts 	conv_in+1,r17
		sts 	conv_in+2,r15
		sts 	conv_in+3,r15
		call 	bindec
ret
usartsend_hex:	
;cli
		push 	r16											;wysyla bajt w hex na usart (R16)
		push 	r17
		usart_bcd_MSD r16
		pop 	r17
		pop 	r16
		push 	r16
		push 	r17
		usart_bcd_LSD r16
		pop 	r17
		pop 	r16
;sei
ret
usartsendDecT8:
		push 	r16
		push 	r17
		push	r18
		mov 	r17,r16
		clr 	r18
minust11:
		cpi		r17,10
		brlo 	mnm10t1
		subi 	r17,10
		inc 	r18
		rjmp 	minust11
mnm10t1:	
		ldi		r16,'0'
		add		r16,r18										;dziesiatki
		cpi		r18,0
		breq	pc+2										;jesli dziesiatki 0 to niewyswietlaj
		rcall	usartsend
		ldi		r16,'0'
		add		r16,r17										;jednosci
		rcall	usartsend
		clc
dataPresent1:
		pop		r18
		pop 	r17
		pop 	r16

ret
															
;-----------------------------------------------------------
;====wyswietlanie temperatury int8 tlyko -99C - +99C R16
;znaki specjalne dla wartosci poza zakresem
;-----------------------------------------------------------
usartsendTempe:
		push 	r16
		push 	r17
		push	r18
		mov 	r17,r16
;------overrange----------
		cpi		r17,TEMPER_OVERR_CODE
		brne	no_overrange
overang_e:
		ldi		r16,'O'
		rcall	usartsend
		ldi		r16,'V'
		rcall	usartsend
		ldi		r16,'R'
		rcall	usartsend
		sec
		rjmp	dataPresent
;-------------------------
no_overrange:
;------overrange----------
		cpi		r17,TEMPER_EMPTY_CODE
		brne	no_emptyTbyte
		ldi		r16,'-'
		rcall	usartsend
		ldi		r16,'-'
		rcall	usartsend
		ldi		r16,'-'
		rcall	usartsend
		sec
		rjmp	dataPresent
;-------------------------
no_emptyTbyte:
;------errorByte----------
		cpi		r17,TEMPER_ERROR_CODE
		brne	no_errorTbyte
		ldi		r16,'E'
		rcall	usartsend
		ldi		r16,'R'
		rcall	usartsend
		ldi		r16,'R'
		rcall	usartsend
		sec
		rjmp	dataPresent
;-------------------------
no_errorTbyte:
		clr		r18
		mov		r16,r17
		call	overTempTestT								;test na przekroczenie zakresu -55 do +99, jesli true to skok do overang_e
		brcs	overang_e	
		tst 	r17
		brpl	plusTemp
		neg		r17
		ldi		r16,'-'
		rjmp	minustemp
plustemp:
		cpi		r17,0
		ldi		r16,' '
		breq	minustemp
		ldi		r16,'+'
minustemp:
		rcall	usartsend
minust1:
		cpi		r17,10
		brlo 	mnm10t
		subi 	r17,10
		inc 	r18
		rjmp 	minust1
mnm10t:	
		ldi		r16,'0'
		add		r16,r18										;dziesiatki
		rcall	usartsend
		ldi		r16,'0'
		add		r16,r17										;jednosci
		rcall	usartsend
		clc
dataPresent:
		pop		r18
		pop 	r17
		pop 	r16
ret															
;===========================================================
;-temperatura z int 16 z rozdzielczoscia do 0.125C----------
;-----------------------------------------------------------
usartsendTempePrec:
		push	r16
		push	r17
		clt
		cp	 	r16,zero
		cpc		r17,zero
		brpl	plusTempP
		com 	r17
		com		r16
		add		r16,one
		adc		r17,zero
		set
plusTempP:		
		push 	r16	
		push 	r17
	
		cpi		r16,0
		cpc		r17,zero
		brne	no0ValTprec
		ldi		r16,' '
		rjmp	minust1b
no0ValTprec:	
		ldi		r16,'+'
		brtc	pc+2
		ldi		r16,'-'
minust1b:
		rcall	usartsend

		pop 	r17
		pop		r16
		push 	r16
		call	asr12to8
		clr 	r18
		mov		r17,r16
minust1a:

		cpi		r17,10
		brlo 	mnm10ta
		subi 	r17,10
		inc 	r18
		rjmp 	minust1a
mnm10ta:	
		ldi		r16,'0'
		add		r16,r18										;dziesiatki
		rcall	usartsend
		ldi		r16,'0'
		add		r16,r17										;jednosci
		rcall	usartsend

		ldi		r16,'.'										;decpoint
		rcall	usartsend

		ldiwz	decValTable*2
		pop 	r16
		lsr		r16											;najmlodszy bit niebrany pod uwage
		andi	r16,0x07
		add		zl,r16
		adc		zh,zero
		lpm		r16,z
		rcall	usartsend
		pop		r17
		pop		r16
ret											


;-----------------------------------------------------------
	;wysyla bajt zamieniajac na dziesietne 3 znaki asci
;-----------------------------------------------------------
usartsenddec:						
;clt
;cli
;ldi r16,131
		push 	r16											;wysyla bajt w hex na usart (R16)
		push 	r17
		clr 	r17
mnm100:
		cpi 	r16,100
		brlo 	mnm10
		subi 	r16,100
		inc 	r17											;licznik setek
		rjmp 	mnm100
mnm10:
		push 	r16
		subi 	r17,256-'0'									;dodaj poczatek znakow asci
		mov 	r16,r17

;brts 	niewygaszera
		rcall 	softuarttx0									;wysylaj ilosc setek
		rjmp 	pc+2
niewygaszera:
		rcall 	usartsend
		pop 	r16
		clr 	r17
mnm10a:

		cpi 	r16,10
		brlo 	mnm1
		subi 	r16,10	
		inc 	r17											;licznik 10tek
		rjmp 	mnm10a
mnm1:
		push 	r16
		subi 	r17,256-'0'									;dodaj poczatek znakow asci
		mov 	r16,r17
		rcall 	usartsend									;wysylaj ilosc 10tek
		pop 	r16
		;clr r17

		subi 	r16,256-'0'
		rcall 	usartsend									;pozostala liczba jednostek
		pop 	r17
		pop 	r16
;sei
ret
softuarttx0:												;test zera jesli zero daj spacje
		cpi 	r16,'0'
		brne 	no0ok
		ldi 	r16,' '
no0ok:
		rcall 	usartsend
ret
usartsendasc:												;tylko znaki asci inaczej spacja
		cpi 	r16,32
		brlo 	nieasc
		cpi 	r16,123
		brsh 	nieasc
		rjmp 	usartsendch
nieasc:
		push 	r16
		ldi 	r16,' '
		rcall 	usartsend
		pop 	r16
ret
usartsendch:												;wysyla surowy bajt na usart (R16)
		push 	r16
		rcall 	usartsend
		pop 	r16
ret
usartsendram5:
		rcall usartsend48LDZ								;wartosc wyswietlona dzisietnie
usartsendram4:
		rcall usartsend48LDZ
usartsendram3:
		rcall usartsend48LDZ
		rcall usartsend48LDZ
;		rcall usartsend48LDZ

usartsend48LDZ:
		ld 		r16,-z
usartsend48:
		subi 	r16,-'0'
		rjmp 	usartsend
usartspace8:
		rcall 	usartspace
usartspace7:
		rcall 	usartspace
usartspace6:
		rcall 	usartspace
usartspace5:
		rcall 	usartspace
usartspace4:
		rcall 	usartspace
usartspace3:
		rcall 	usartspace
usartspace2:
		rcall 	usartspace
;		rcall 	usartspace
usartspace:
		push 	r16
		ldi 	r16,' '
usart0:
		push 	r17
USARTbus:
		lds 	r17, UCSR0A
		sbrs 	r17,UDRE0
		rjmp 	USARTbus
		sts 	udr0,r16
		pop 	r17
		pop 	r16
ret
usartsend:
push r16
rjmp usart0

BT_reconfig:
;sprawdzenie czy zmienione haslo (aby nie wchodzil w reinit BT po powrocie z bootloadera) 
		lds 	r16,setBTpassword+0
		lds 	r17,BTpasswordOld+0
		cp		r16,r17
		sts		BTpasswordOld+0,r16
		lds 	r16,setBTpassword+1
		lds 	r17,BTpasswordOld+1
		cpc		r16,r17
		sts		BTpasswordOld+1,r16
		lds 	r16,setBTpassword+2
		lds 	r17,BTpasswordOld+2
		cpc		r16,r17
		sts		BTpasswordOld+2,r16
		lds 	r16,setBTpassword+3
		lds 	r17,BTpasswordOld+3
		cpc		r16,r17
		sts		BTpasswordOld+3,r16
		brne 	pc+2
		ret
;rekonfiguracja BT na parametry zadane, mozliwe tylko jesli ma predkosc 9600 115200 lub 230400
.if	EMU_BRD == 0
		cbi		BT_OUTPUT_port,BT_OUTPUT_nr					;disconnect - repower
		call 	longwait
		sbi		BT_OUTPUT_port,BT_OUTPUT_nr

wait_BTon:
		wdr
		sbis	BT_CONN_pin, BT_CONN_nr
		rjmp	wait_BTon
.endif
		sts  	UBRR0h,r15
		ldi  	r16,47										;9600b/s
		sts  	UBRR0l,r16

;		ldi  	r16,high(376)
;		sts  	UBRR0h,r16
;		ldi  	r16,low(376)								;1200b/s
;		sts  	UBRR0l,r16

		usartstring _HC06_230400BAUD						;jesli fabrycznie w 9600 to przelacz na 230400
		call 	longwait
		call 	longwait

		sts  	UBRR0h,r15
		ldi  	r16,3										;115200*1/s
		sts  	UBRR0l,r16
		usartstring _HC06_230400BAUD						;jesli fabrycznie w 115200 to przelacz na 230400
		call 	longwait
		call 	longwait

		sts  	UBRR0h,r15
		ldi  	r16,1										;230400
		sts  	UBRR0l,r16
		usartstring _HC06_230400BAUD						;jesli fabrycznie w 115200 to przelacz na 230400
		call 	longwait
		call 	longwait

usartstring _HC06_NAME
		call 	longwait
		call 	longwait

		usartstring _HC06_PIN
		lds		r16,setBTpassword+3
		call	usartsend
		lds		r16,setBTpassword+2
		call	usartsend
		lds		r16,setBTpassword+1
		call	usartsend
		lds		r16,setBTpassword+0
		call	usartsend
		call 	longwait
		call 	longwait
ret

;dlugie opoznienia potrzebne dla timeoutu wpisujacego config do modulu BT
longwait:
		ldi 	r18,25;50
longwaitloop:
		wdr
		ldi 	r17,250
		call	delayr
		dec 	r18
		brne 	longwaitloop
ret


;------------strings display subroutines---------------------
;te makra zajmuja duzo rom
string8bit:
set
stringdigj 3,3,255,2,0										;ciagnie z convin
ret
string16bit:
set
stringdigj 6,6,255,2,0
ret
string24bit:
set
stringdigj 8,8,255,7,0
ret

;cyfra dzisiatna dekodowana z lsb w r16, uzyte 3 bity 
decValTable:
.db '0','1','2','3','5','6','7','8'

;----------------------config strings-----------------------

;HC-06 config write
_HC06_230400BAUD:
.db	"AT+BAUD9",255,255
_HC06_115200BAUD:
.db	"AT+BAUD8",255,255 										;HC06 ma fabrycznie 9600b/s ! (BAUD4=9600)
_HC06_NAME:
.db	"AT+NAME*IceBox*",255,255								; -konfig BT HC06 nazwa urzadzenia
_HC06_PIN:
.db	"AT+PIN",255,255										; -konfig BT HC06 PIN BT
_HC06_IPSCAN:
;.db "AT+IPSCAN=1024,1,1024,1",255,255						;tylko na to OK, na inne wartosci ignor ... moze w innych wersjach BT dziala dobrze (ma zmniejszac pobor pradu na czuwaniu)
;.db "AT+IPSCAN=1024,512,1024,512",255,255

cursoroff:
.db 27,'[', '?' ,'2','5', 'l',255,255
