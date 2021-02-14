;===========================================================
;===================== Icebox 2020 =========================
;===================== softuart.inc ========================
;===========================================================

;R16,R17,R18,R19
										
.macro ubd													;soft uart bit delay
uartbitdelay:					
		ldi 	r19,susartbitrate
uartdelay:
		dec 	r19
		brne 	uartdelay
.endm 
usartspace_DBG:
		ldi 	r16,' '
usartSend_DBG:
		push 	r16
		push 	r17
		push 	r18
		push 	r19

;-----debug uart tx emulator (r16)-------------------------- 
;Uzywane R16-R18,data=R16
;wersja wyrownana czasowo dla kazdej predkosci		
;r16 pozostaje niezmienione ror 9 razy
		ldi 	r17,9										;bitow do wyslania
		in 		r18,portuartTX	
;----start+8bit data-------------
		clc													;b.8=0 (start bit=L)
		ror 	r16
data1:
		ubd
		bst 	r16,7										;1ck
		bld 	r18,pinTX									;1ck
		ror 	r16											;1ck
		out 	portuartTX,r18								;1ck
bitjeden:
	;	rcall uartbitdelay
		dec 	r17											;1ck
		brne 	data1										;2ck=true 1ck=false
;-------------------------------
		ubd
		nop
		rjmp 	st0p										;2xnop ten rjmp nie zajmuje 2 cykli tylko jeden !!
st0p:
;-------------stop-------------
		sbr 	r18,1<<pinTX								;1ck
		out 	portuartTX,r18								;1ck
;		sbi 	portuart,uartport							;2ck stopbit (hi)
;-------------------
		ubd
		;rcall 	uartbitdelay								;Xck mozna pominac jesli program glowny nie wywola zbyt szybko tego programu
;---stop-----------------------
		sbi 	portuartTX,pinTX							;powrot do stanu spoczynku H
		pop 	r19
		pop 	r18
		pop 	r17
		pop 	r16
;sei
ret	

;---------zamiast podprogramu mozna uzyc makra -------------
;---UBD kosztem rozmiaru kodu mozna przyspieszyc uart-------
usartSend_DBG_hex:											;wysyla dwa znaki na usart (r16 w hex)
cli
		push 	r16
		swap 	r16
		rcall 	hexD_0
		pop 	r16
		rcall 	hexD_0
sei
ret

usartSend_DBG_hex_Irq:											;wysyla dwa znaki na usart (r16 w hex)
		push 	r16
		swap 	r16
		rcall 	hexD_0
		pop 	r16
		rcall 	hexD_0
ret

hexD_0:
		mov 	r17,r16
		andi 	r17,0b00001111
		cpi 	r17,10										;if >9 + 7chr to output (A=10dec)
		brlo 	disp_bcd00_0
		subi 	r17,256-7
disp_bcd00_0:
		subi 	r17,256-48
		mov 	r16,r17
		rcall 	usartSend_DBG
ret

CLSS_0:		
		ldi 	r16,27		
		rcall 	usartSend_DBG								;Escape 
		ldi 	r16,91; 
		rcall 	usartSend_DBG								;Opening bracket
		ldi 	r16,'2'; 
		rcall 	usartSend_DBG
		ldi 	r16,'J'; 
		RJMP 	usartSend_DBG
labelf_0:
		push 	r17
		push 	r30
		push 	r31
nextendfind_0:
		subi 	r17,1
		brcc 	nextendsearch_0
		call 	usartstrin
;--------------------copy bytes-------------------
usartstrin_0:												;wysylanie stringow na usart
sendstrloop_0:
		lpm 	r16,z+
		cpi 	r16,255
		breq 	endstring_0
		rcall 	usartSend_DBG
		rjmp 	sendstrloop_0
endstring_0:
;------------------------------------------------
		pop 	r31
		pop 	r30
		pop 	r17
		ret
nextendsearch_0:
		lpm 	r16,z+1
		cpi 	r16,255
		brne 	nextendsearch_0
repeatskip_0:
		lpm 	r16,z+1										;test na kilka 255 po sobie traktowane jako jeden separator
		cpi 	r16,255
		breq 	repeatskip_0
		sbiw 	r30,1										;cofnij 1 bajt
rjmp nextendfind_0


usartstring_DBG:											;wysylanie stringow na usart
sendstrloop_1:
		lpm 	r16,z+
		cpi 	r16,255
		breq 	endstring_1
		rcall 	usartSend_DBG
		rjmp 	sendstrloop_1
endstring_1:
ret


NL_DBG:		;nowa linia
		push 	r16
		ldi 	r16,13										;enter (return)
		rcall 	usartSend_DBG
		ldi 	r16,11										;vertical TAB
		rcall 	usartSend_DBG
		pop 	r16
ret

CLSS_DBG:		
		push 	r16
		ldi 	r16,27
		rcall 	usartSend_DBG								;Escape
		ldi 	r16,91
		rcall 	usartSend_DBG								;Opening bracket
		ldi 	r16,'2'
		rcall 	usartSend_DBG 
		ldi 	r16,'J'
		rcall 	usartSend_DBG	
		pop 	r16
ret



;----------przerwanie pcint sof USART RX--------------------
pcint:
		in 		r2,sreg
		push 	r16
		push 	r17
		push 	r19
;---------UART RX-------------------------------------------
;maksymalna dlugosc wykonywania programu to czas 8bit + start. przerwanie wywolywane bit po bicie
;kompatybilnosc czasowa z usarttx 7MCK+UBD
;uartRX:
;SURX_D-data -odpowiednik hw rejestru z danymi
;SURX_S-status - jak statusowy hw
		sbic 	pinuartRX,pinRX								;jesli przerwanie wyzwolone bo stan wysoki na magistrali nie przetwarzaj
		rjmp 	endrx0
waitHloop1:
;--------------------start bit delay------------------------
		ubd
;-----------------------------------------------------------
		clr 	r16
		ldi 	r17,8
;-------------petla probkujaca 8 bitow----------------------
		;zdjecie stanu portu 
RX8bitloop:
		sec													;1ck
		sbis 	pinuartRX,pinRX								;1ck
		clc													;1ck
		ror 	r16											;1ck
		ubd													;ubdCK
		dec 	r17											;1ck
		brne 	RX8bitloop									;2ck
;-----------------------------------------------------------
		sts 	SURX_D,r16									;zapis 8bit danch do ram
		sti 	SURX_S,1<<RXC0								;flaga odebrania danych nowych 
endrx0:
		pop 	r19
		pop 	r17
		pop 	r16
		out 	sreg,r2
reti

										
onRXpcint:
;out spcr,zero ;spi off

		sbi 	ddruartTX,pinTX
		sbi 	portuartTX,pinTX

		cbi 	ddruartRX,pinRX								;rx pullup
		sbi 	portuartRX,pinRX

pcintON:
.if portuartRX 	== portb
		sti 	pcicr,0b00000001							;– – – – – PCIE2 PCIE1 PCIE0
		lds 	r16,pcmsk0
		ori 	r16,1<<pinRX								;bity portow wlaczjace pcint
		sts 	pcmsk0,r16
.endif


.if portuartRX 	== portc
		sti 	pcicr,0b00000010
		lds 	r16,pcmsk1
		ori 	r16,1<<pinRX
		sts 	pcmsk1,r16
.endif

.if portuartRX	== portd
		sti 	pcicr,0b00000100
		lds 	r16,pcmsk2
		ori 	r16,1<<pinRX
		sts 	pcmsk2,r16
.endif

ret
pcintOFF:

.if portuartRX	== portb
		sti 	pcicr,0b00000001							;– – – – – PCIE2 PCIE1 PCIE0
		lds 	r16,pcmsk0
		cbr 	r16,1<<pinRX								;bity portow wylaczjace pcint
		sts 	pcmsk0,r16
.endif


.if portuartRX	==portc
		sti 	pcicr,0b00000010
		lds 	r16,pcmsk1
		cbr 	r16,1<<pinRX
		sts 	pcmsk1,r16
.endif

.if portuartRX	==portd
		sti 	pcicr,0b00000100
		lds 	r16,pcmsk2
		cbr 	r16,1<<pinRX
		sts 	pcmsk2,r16
.endif

ret
