;===========================================================
;==================== Dream FM 2021  =======================
;===================== usartTX.asm =========================
;===========================================================

usart_nl:
		push 	r16
		ldi 	r16,13										;enter (return)
		rcall 	usartsend
		ldi 	r16,11										;vertical TAB
		rcall 	usartsend
		pop 	r16
ret
/*
usart_space:
		push 	r16
		push 	r17
		ldi 	r16,' '
		rjmp	USARTbus
*/
lf_print:
#ifdef LF_ENDSTR
		ldi 	r16,10										;LF (line feed rozpoznawany jako koniec lniii przez readline w pytonie)
		#else
		ret	
#endif
	
usartsend:
		push 	r16
		push 	r17
USARTbus:
		in	 	r17, USR
		sbrs 	r17,UDRE
		rjmp 	USARTbus
		out 	udr,r16
		pop 	r17
		pop 	r16
ret
;===========================================================
.macro usart_bcd_LSD
		mov r17,@0
		andi r17,0b00001111
		cpi r17,10											;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		mov r16,r17
		rcall usartsend
.endm
.macro usart_bcd_MSD
		mov r17,@0
		andi r17,0b11110000
		swap r17
		cpi r17,10
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		mov r16,r17
		rcall usartsend
.endm

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

usart_romstring:
		wdr
usart_romstring0:
		lpm
		mov		r16,r0
		cpi		r16,0
		breq	end_string
		rcall	usartsend
		add		r30,one
		adc		r31,zero
		rjmp	usart_romstring0
end_string:
ret
			
;===========================================================
