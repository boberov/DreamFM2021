;=================================================================
;================== Dream FM 2021 VFD saver ======================
;======================= irq_vect.asm ============================
;=================================================================
															
start:	
.org		$000								;wektory przerwan
		rjmp 	main_start	
; RTC 	
.org 	RTC_CNT_vect
		reti
.org 	RTC_PIT_vect
		rjmp 	rtc_pti_irq
; TCA0
.org 	TCA0_OVF_vect
		rjmp 	tca_ovf_irq
.org 	TCA0_CMP1_vect
		rjmp		tca_cmp1_irq
.org 	TCA0_CMP2_vect
		rjmp		tca_cmp2_irq
; USART
.org 	USART0_RXC_vect
		rjmp 	USART0RXC_IRQ
.org 	USART0_DRE_vect
		rjmp 	USART0DREIE_IRQ
.org 	USART0_TXC_vect
		rjmp 	USART0TXC_IRQ


;================================================================	
;krotkie programy przerwan tutaj, dlugie w plikach modulow								
;================================================================	

;----------------------- TCA irq ---------------------------------
;na tym przerwaniu jest zrealizowany pwmowy dac ~ 31kHz
;komparator 0 steruje pwmem dla LED podswietlajacej
;napiecie daca jest modulowane pwmem z wypelnianiem 50%
;jesli wartosc dla fvd >0 to generowane napiecie jest zwiekszane
;od napiecia VREF 4.3V aby wlaczyc tranzystor od przekaznika
;dla max wartosci napiecie modulujace wynosi 4.3VPP
;-----------------------------------------------------------------
tca_ovf_irq:
		;STI		TCA0_SINGLE_INTFLAGS,	TCA_SINGLE_OVF_bm			;- CMP2 CMP1 CMP0 - - - OVF
reti
tca_cmp1_irq:
		in		r2,CPU_SREG
		push		r16
		STI		TCA0_SINGLE_INTFLAGS,	TCA_SINGLE_CMP1_bm	;- CMP2 CMP1 CMP0 - - - OVF
		sbr		SFLAGS,1<<msec_f
;----------------- led ------------------------
		lds		r16,ledVoltage								;16bit acces
		STS		TCA0_SINGLE_CMP0BUF+1,zero					;MSB first
		STS		TCA0_SINGLE_CMP0BUF,R16	
;----------------------------------------------

		lds		r16,vfdVoltage
		cpi		r16,0
		breq		disabled_dacpwm0							;jesli 0 dacpwm nie bedzie generowal stanu wysokiego dla przekaznika
		ldi		r16,0xFF
		sts		DAC0_DATA,	r16
 disabled_dacpwm0:
		pop		r16
		out		CPU_SREG,r2
reti

tca_cmp2_irq:
		in		r2,CPU_SREG
		push		r16
		push		r17
		STI		TCA0_SINGLE_INTFLAGS,TCA_SINGLE_CMP2_bm		;- CMP2 CMP1 CMP0 - - - OVF

		lds		r16,vfdVoltage
		cpi		r16,0		
		brne		enabled_dacpwm1								;jesli 0 dacpwm nie bedzie generowal stanu wysokiego dla przekaznika
		lds		r16,  DAC0_DATA
		cpi		r16,0
		breq		not_valid
		dec		DACDisPrescalerL
		brne		not_valid
		add		DACDisPrescalerH,one
		brhc		not_valid
		clr		DACDisPrescalerH
		dec		r16
		rjmp		not_valid0
enabled_dacpwm1:	
		com		r16
not_valid0:
		sts		DAC0_DATA,	r16
not_valid:
		pop		r17
		pop		r16
		out		CPU_SREG,r2
reti
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;--------------------- rtc pit irq -------------------------------
;timer asynchroniczny z generoatora 32kHz dla duzych interwalow
;-----------------------------------------------------------------
rtc_pti_irq:
		in		r2,CPU_SREG
		push		r16
		STI		RTC_PITINTFLAGS,RTC_PI_bm					;flaga przerwania
		sbr		SFLAGS,1<<sec1_f
		pop		r16
		out		CPU_SREG,r2
reti
;-----------------------------------------------------------------
													