;=================================================================
;================== Dream FM 2021 VFD saver ======================
;======================= usartTX.asm =============================
;=================================================================

;---------------------- TX irq handler ---------------------------
USART0DREIE_IRQ:
		push		r16
		push 	r17
		in 		r16,CPU_sreg	
		push 	r16
		push		zl
		push		zh
	
		ldiwz	UTXbuffer
		lds		r17,UTXpRD									;wskaznik odczytu
		lds		r16,UTXpWR									;wskaznik zapisu
		cp		r16,r17
		breq		wait_forTXirqDIS							;wskazniki rowne mozna wylaczyc przerwanie
#ifdef MULMASTER
		sbi		TRO_VDIR,		TX_PIN		
#endif
		add		zl,r17
		adc		zh,zero
		ld		r16,z
		STs		USART0_TXDATAL, r16
		inc		r17
		andi		r17,TXB_SIZE-1
		sts		UTXpRD, r17
	
retIRQ_DREIE:
		STI		USART0_STATUS,	USART_DREIF_bm				;RXCIF TXCIF DREIF RXSIF ISFIF BDF WFB
		pop		zh
		pop		zl
		pop		r16
		out		CPU_sreg,r16
		pop		r17
		pop 		r16
	reti
wait_forTXirqDIS:	
	CLRBIT 	USART0_CTRLA, 	USART_DREIF_bm 					;RXCIE TXCIE DREIE RXSIE LBME ABEIE RS485[1:0]

	rjmp 	retIRQ_DREIE
reti

USART0TXC_IRQ:
		push 	r16
		in 		r16,CPU_sreg	
		push 	r16
		STI		USART0_STATUS,	USART_TXCIF_bm
#ifdef MULMASTER
		cbi		TRO_VDIR,		TX_PIN	
#endif
		pop		r16
		out		CPU_sreg,r16
		pop		r16
reti
;-----------------------------------------------------------------
												

NL:		;nowa linia (nie LF line feed)
push r16
		ldi		r16,13;enter (return)
		rcall	USARTSEND
		ldi		r16,11;vertical TAB
		rcall	USARTSEND
pop r16
ret
usart2791:
		ldi		r16,27
		rcall	USARTSEND
		ldi		r16,91
		RJMP		USARTSEND
CLSS:		
		rcall	usart2791
		ldi		r16,'2'
		rcall	USARTSEND
		ldi		r16,'J'; 
		RJMP		USARTSEND	
home:
		rcall	usart2791
		ldi		r16,72
		RJMP		USARTSEND
usartspace:
		ldi		r16,' '

usartsend_0_B:	
usartsend:						
		push 	r17
		push		r30
		push 	r31
USARTSENDx0:
;ta funkcja pisze do bufora, nie do sprzetu

		ldiwz	UTXbuffer
		lds		r17,UTXpWR
		
		add		zl,r17
		adc		zh,zero
		st		z,r16
		
		inc 		r17
		andi 	r17,TXB_SIZE-1
		sts 		UTXpWR,r17
		
		SETBIT 		USART0_CTRLA, 	0b00100000 				;RXCIE TXCIE DREIE RXSIE LBME ABEIE RS485[1:0]

wait_forRXpoint:
		pop		r31
		pop		r30
		pop		r17
ret



usartsend_hex:												;wysyla dwa znaki na usart (r16 w hex)
		push		r17
		push 	r16
		swap 	r16
		rcall 	hexD_0_B
		pop 		r16
		push 	r16
		rcall 	hexD_0_B
		pop		r16
		pop		r17
ret
hexD_0_B:
		mov		r17,r16
		andi 	r17,0b00001111
		cpi 		r17,10										;if >9 + 7chr to output (A=10dec)
		brlo 	disp_bcd00_0_B
		subi 	r17,256-7
disp_bcd00_0_B:
		subi 	r17,256-48
		mov 		r16,r17
		rcall 	usartsend_0_B
ret
NL_0_B:		;nowa linia
		ldi 		r16,13										;enter (return)
		rcall 	usartsend_0_B
		ldi 		r16,11										;vertical TAB
		rcall 	usartsend_0_B
ret
HOME_0:														;kursor do poczatku terminala
		ldiwz	_home_b*2
		rjmp		usartsend_b
CLS_0_B:		
		ldiwz	_cls_b*2
		rjmp		usartsend_b
DEFATR_0_B:
		ldiwz 	_defatr_b*2
		rjmp		usartsend_b
WELCOME_B:
		ldiwz 	_welcome_b*2
		rjmp		usartsend_b

usartsend_bin:
		push 	r18
		push 	r17
		push 	r16
		
		ldi 		r17,8
no0bitA:		
		rol		r16
		
		ldi		r18, '0'
		brcc 	no0bitB
		ldi		r18, '1'		
no0bitB:
		push 	r16
		mov 		r16,r18
		rcall 	usartsend
		pop		r16
		
		dec		r17
		brne		no0bitA
		
		pop		r16
		pop 		r17
		pop		r18
ret


usartsend_b:
nextendfind_0_B:

;--------------- copy bytes ---------------------
											;wysylanie stringow na usart
sendstrloop_0_B:
		lpm 		r16,z+
		cpi 		r16,0
		breq 	endstring_0_B
		rcall 	usartsend_0_B
		rjmp 	sendstrloop_0_B
endstring_0_B:
		ret
nextendsearch_0_B:
		lpm 		r16,z+1
		cpi			r16,0
		brne 	nextendsearch_0_B
repeatskip_0_B:
		lpm		r16,z+1						;test na kilka 0 po sobie traktowane jako jeden separator
		cpi 		r16,0
		breq 	repeatskip_0_B
		sbiw 	r30,1						;cofnij 1 bajt
rjmp nextendfind_0_B
;-----------------------------------------------
lf_print:
#ifdef LF_ENDSTR
	ldi		r16,10							;LF (line feed rozpoznawany jako koniec lniii przez readline w pytonie)
	rcall	usartsend
#endif
	ret	
;-------------------eof--------------------------