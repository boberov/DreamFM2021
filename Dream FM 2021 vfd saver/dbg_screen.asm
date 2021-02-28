;=================================================================
;================== Dream FM 2021 VFD saver ======================
;=================== dbg_screen.asm ========================
;===========================================================

consoleScreen_:		
	lds		r16,ADC0_RESL
	lds		r17,ADC0_RESH

	lsr		r17
	ror		r16
		
	lsr		r17
	ror		r16
	
	lsr		r17
	ror		r16
	
	lsr		r17
	ror		r16
	
	lsr		r17
	ror		r16
	
	sts		vbat,r16

	rcall 	NL_0_B

	ldi		r16, 'V'
	rcall	usartsend
	ldi		r16, 'B'
	rcall	usartsend
	ldi		r16, ':'
	rcall	usartsend
	ldi		r16, ' '
	rcall	usartsend
	
	lds 	r16,vbat+0
	rcall	usartsend_hex	
	
ret
;--------------------------------eof--------------------------------------------	