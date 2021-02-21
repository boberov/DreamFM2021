;===========================================================
;==================== Dream FM 2021  =======================
;====================== usart.asm ==========================
;===========================================================

usartsend_hex:	
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
ret

dispFreq:
		rcall	usart_nl
		;zmierzona czestotliwosc hexalnie
		ldi 	r16,'>'
		rcall	usartsend
		lds		r16, freqRX+1
		rcall	usartsend_hex 
		lds		r16, freqRX+0
		rcall	usartsend_hex 
		ldi 	r16,' '
		rcall	usartsend
		loadw	r16,r17,freqRX		
		rcall 	freqMeasRaw_ToBIN							;r16 r17 zwraca wartosc wyliczona
rjmp	display_freq_R16R17

ok_string:
		ldi 	r16,'O'
		rcall	usartsend
		ldi 	r16,'K'
		rcall	usartsend
		rjmp	lf_print
												
;===========================================================
;wysylanie ciagu znakow z czestotliwoscia na usart, 
;decpoint przedostatni
;===========================================================
display_freq_R16R17:
		rcall	FbinTo_string	
		ldiwz	FREQstring+4

		ldi 	r16,'F'
		rcall	usartsend
		ldi 	r16,'='
		rcall	usartsend
		ld		r16,-z
		rcall	usartsend
		ld		r16,-z
		rcall	usartsend
		ld		r16,-z
		rcall	usartsend
		ldi 	r16,'.'
		rcall	usartsend
		ld		r16,-z
		rcall	usartsend

		ldi 	r16,'M'
		rcall	usartsend
		ldi 	r16,'H'
		rcall	usartsend
		ldi 	r16,'z'
		rcall	usartsend
lf_print:
#ifdef LF_ENDSTR
		ldi 	r16,10										;LF (line feed rozpoznawany jako koniec lniii przez readline w pytonie)
		rcall	usartsend
#endif
	ret
															
;===========================================================
;prymitywny przeliczacz z 16b bin na 4 znakowy string
;wejscie R16:R17 wyjscie FREQstring 4B
;-----------------------------------------------------------
FbinTo_string:
		;ldiwy	USARTstr
		mov 	r30,r16
		mov		r31,r17
		ldi		r16,'0'
		sts	 	FREQstring +0,r16
		sts	 	FREQstring +1,r16
		sts	 	FREQstring +2,r16
		sts	 	FREQstring +3,r16
tys2:
		ldi 	r16,byte2(1000)	
		cpi 	R30,byte1(1000)
		cpc 	R31,r16
		brlo 	sto2
		incr 	FREQstring+3

		ldi 	r17,10		
petla1000:
		sbiw 	r30,50
		sbiw 	r30,50
		dec 	r17
		brne 	petla1000	
		rjmp 	tys2

sto2:
		ldi 	r18,100
		cp 		R30,r18
		cpc 	R31,zero
		brlo 	dec10
		incr 	FREQstring+2

		sbiw 	r30,50
		sbiw 	r30,50
		rjmp 	sto2
dec10:
		ldi 	r18,10
		cp 		R30,r18
		cpc 	R31,zero
		brlo 	mniej12
		incr 	FREQstring+1
		sbiw 	r30,10
		rjmp 	dec10

mniej12:	
		lds		r16,FREQstring+0
		add		r16,r30
		sts 	FREQstring,r16
ret
;===========================================================
usart_romstring:
		lpm
		mov		r16,r0
		cpi		r16,0
		breq	end_string
		rcall	usartsend
		add		r30,one
		adc		r31,zero
		rjmp	usart_romstring
end_string:
ret
;===========================================================
;--------------------- usart TX ----------------------------
;===========================================================
usart_nl:
		push 	r16
		ldi 	r16,13										;enter (return)
		rcall 	usartsend
		ldi 	r16,11										;vertical TAB
		rcall 	usartsend
		pop 	r16
ret

usart_space:
		push 	r16
		push 	r17
		ldi 	r16,' '
		rjmp	USARTbus
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
.exit

dispFreqLast:
		loadw	r16,r17,freqRXLast
rjmp	display_freq_R16R17


dispFreq_decff:
		push	r16
//czesc MHz to pomiar przesuniete bajty o 7bit w prawo
		bst	 	r16,7
		lsl 	r17
		bld 	r17,0										;from t flag
		mov		r16,r17
;czesc 100kHz
		pop		r16
		swap	r16
		andi	r16,0x0F
		;lsr		r16
		ldiwz	kHz_part*2
		add		r30,r16
		adc		r31,zero
		lpm		
		mov		r16,r0
		;rcall 	usartsend
//czesc ulamkowa to 25kHz na lsb jesli przesunac o4b w prawo
ret

			
