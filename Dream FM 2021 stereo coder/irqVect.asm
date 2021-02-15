;===========================================================
;==================== Dream FM 2021  =======================
;===================== irqVec.inc ==========================
;===========================================================

;==================== irq vect =============================
.org $000
		rjmp 	init		
.org int0addr							
		rjmp 	int0_irq
.org int1addr							
		rjmp 	int1_irq
.org URXCaddr
		rjmp	URX_irq										;usartRX

;===========================================================
;-------------------- tuning  ------------------------------
;===========================================================
int0_irq:													
		rcall	phase_minus
		rcall	phase_write									;zapisz faze do eeprom
key_wait2:
		wdr
		sbis	pind,2
		rjmp	key_wait2
int0_irq_wdt_wait:											;czekaj na reset od wdt
		rjmp	disp_phase									;albo nie czekaj :)
int1_irq:
		rcall	phase_plus
		rcall	phase_write
key_wait3:
		wdr
		sbis	pind,3
		rjmp	key_wait3
		rjmp 	int0_irq_wdt_wait
;-----------------------------------------------------------
phase_minus:
		dec 	Phase										;zmien faze pilota
		ldi		r16,255
		cp		Phase,r16
		brne	no_wr_ph
		ldi		r16, PHASE_STEPS-1
		mov		Phase, r16
no_wr_ph:
ret
phase_plus:
		inc 	Phase
		ldi		r16,PHASE_STEPS
		cp		Phase,r16
		brne	pc+2
		clr		Phase
ret
;===========================================================
;----------------- zapis fazy do eeprom --------------------		
;===========================================================
phase_write:
		clr 	Led_Cl										;zerowanie licznika mrugania diody
		clr 	Led_Ch
		sbi 	portd,6										;H na port diody
		mov		r16, phase
		sts		phaseRam+0,r16
		com		r16
		sts		phaseRam+3,r16
		rcall	NVRAMwrite
ret

phase_read:													;spradzanie 1 kopii na spojnosc danych
		lds		r16,phaseRam+0
		lds		r17,phaseRam+3
		com		r17
		cp 		r16,r17
		breq 	record_ok
		rjmp	fault
		cpi 	r16,PHASE_STEPS
		brsh	fault
record_ok:
		mov 	Phase,r16
ret

fault:	
		sbi 	ddrd,6										;rozjasnij led
		ldi		r16, PHASE_DEF								;ustawienie phase wartoscia domyslna (ale nie zapisanie do eeprom jeszcze)
		mov		Phase,r16
fault0:
#ifdef DETUNE_PROTECT
		rjmp	pc-2										;jesli bledne dane w eeprom to nie startuj nawet dekodera
#else
		ldi		r16,8										;sygnalizacja problemu LED miga szybko
		mov		keyLock,r16
		ret	
#endif
