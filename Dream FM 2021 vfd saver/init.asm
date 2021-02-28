;=================================================================
;================== Dream FM 2021 VFD saver ======================
;======================== init.asm ===============================
;=================================================================														

init_0:

;-----------------------------------------------------------------
;---------------- TCA - 16-bit Timer/Counter Type A --------------
;-----------------------------------------------------------------
		STI		TCA0_SINGLE_CTRLB,		0b00010011			;- CMP2EN CMP1EN CMP0EN ALUPD WGMODE[2:0]
		STI		TCA0_SINGLE_CTRLC,		0b00000000			;- - - - - CMP2OV CMP1OV CMP0OV
		STI		TCA0_SINGLE_CTRLD,		0b00000000			;- - - - - - - SPLITM
		STI		TCA0_SINGLE_CTRLECLR,	0b00000000			; - - - - CMD[1:0] LUPD DIR
		STI		TCA0_SINGLE_CTRLESET,	0b00000000			; - - - - CMD[1:0] LUPD DIR
		STI		TCA0_SINGLE_CTRLFCLR,	0b00000000			; - - - -CMP2BV CMP1BV CMP0BV PERBV
		STI		TCA0_SINGLE_CTRLFSET,	0b00000000			; - - - -CMP2BV CMP1BV CMP0BV PERBV
		STIW	TCA0_SINGLE_PER,		255					;to jest rejestr ktory wyznacza TOP
		STIW	TCA0_SINGLE_CMP0,		1 					;comparator
		STIW	TCA0_SINGLE_CMP1,		0 					;comparator
		STIW	TCA0_SINGLE_CMP2,		127	
		STI		TCA0_SINGLE_INTCTRL,	0b01100000			;- CMP2 CMP1 CMP0 - - - OVF
		STI		TCA0_SINGLE_INTFLAGS,	0b01100000			;- CMP2 CMP1 CMP0 - - - OVF
		STI		TCA0_SINGLE_CTRLA,		0b00000001			;- - - - CLKSEL[2:0] ENABLE
;-----------------------------------------------------------------
		sti		vfdVoltage,0xC0								;(20V)
		sti		ledVoltage,0x20
;-----------------------------------------------------------------
;-------------------- RTC - 16-bit Timer -------------------------
;-----------------------------------------------------------------
;RTC domyslnie konfigurowany na wewnetrzny zegar RC 32kHz
		STI		RTC_CTRLA,		RTC_PRESCALER_DIV2_gc|RTC_RTCEN_bm
		STI		RTC_PITCTRLA,	RTC_PERIOD_CYC32768_gc|RTC_PITEN_bm	;RUNSTDBY PRESCALER[3:0] - - - RTCEN
;		STI		RTC_INTCTRL,		0x00					
;		STI		RTC_INTFLAGS,		0x00
		STI		RTC_CLKSEL,		RTC_CLKSEL_INT32K_gc										
		STIW	RTC_PER,		0xFFFF	
		STI		RTC_PITINTCTRL,	RTC_PI_bm					;wlacza przerwanie PIT
		STI		RTC_PITINTFLAGS,RTC_PI_bm
;-----------------------------------------------------------------															

;-----------------------------------------------------------------
;--------------------- MCLK & OSC config -------------------------
;-----------------------------------------------------------------
;		CCP_IOREG	
;		sti		CLKCTRL_MCLKCTRLA, 0x00						;CLKOUT - - - - - - CLKSEL[1:0] (rc clock hsi)

		CCP_IOREG
		sti		CLKCTRL_MCLKCTRLB, CLKCTRL_PEN_bm | 0x00<<CLKCTRL_PDIV_gp;- - - - PDIV[3:0] PEN (MCK prescaler)

waitforMCK_:	
		lds		r16,CLKCTRL_MCLKSTATUS						;EXTS XOSC32KS OSC32KS OSC20MS - - - SOSC
		sbrs		r16,CLKCTRL_OSC20MS_bp
		rjmp		waitforMCK_
waitfor32k_:	
		lds		r16,CLKCTRL_MCLKSTATUS						;EXTS XOSC32KS OSC32KS OSC20MS - - - SOSC (The status bit will only be available if the source is requested as the main clock or by another module. If the oscillators RUNSTDBY bit is set but the oscillator is unused/not requested this bit will be 0.)
		sbrs		r16,CLKCTRL_OSC32KS_bp
		rjmp		waitfor32k_
;-----------------------------------------------------------------
														
;-----------------------------------------------------------------
;-------------------- watchdog init 8ms---------------------------
;-----------------------------------------------------------------
		CCP_IOREG
		STI		WDT_CTRLA,		WDT_PERIOD_8CLK_gc			;WINDOW[3:0] PERIOD[3:0]
		CCP_IOREG
		STI		WDT_STATUS,		WDT_LOCK_bm
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;----------------------- DAC0 init -------------------------------
;-----------------------------------------------------------------
		;STI 	VREF_CTRLA,VREF_DAC0REFSEL_0V55_gc
		STI 	VREF_CTRLA,		VREF_DAC0REFSEL_4V34_gc
;STI 	VREF_CTRLb,1<<VREF_DAC0REFEN_bp						;WLACZA REF NAWET JESLI PERYFERIUM NIE WYMAGA
		STI 	DAC0_CTRLA,		1<<DAC_ENABLE_bp|1<<DAC_OUTEN_bp
		STI 	DAC0_DATA,		0x00
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;------------------------ ADC0 init ------------------------------
;-----------------------------------------------------------------
;ref adc ustawione na vcc, 16 akumulowanych pomiarow, 
;8bit na pomiar, ASDV=1 freerun, samplen =0x1F
		STI 	ADC0_CTRLA,		0b00000111					;RUNSTBY - - - - RESSEL FREERUN ENABLE
		STI 	ADC0_CTRLB,		0x03							;sampnum usrednianie sprzetowe suma 16 pomiarow
		STI 	ADC0_CTRLC,		0b00010111					;VDD VREF	- SAMPCAP REFSEL[1:0] - PRESC[2:0]
		//ASDV to antyaliasingowa ciekawostka
		STI 	ADC0_CTRLA,		0b10010011					;INITDLY[2:0] ASDV SAMPDLY[3:0]
		STI 	ADC0_SAMPCTRL,	0x1F							;samplen
		STI 	ADC0_MUXPOS,	0x03							;A3 input - - - [4:0]
	;	STI 	ADC0_COMMAND,	0x01							;stconv -start konwersji
;-----------------------------------------------------------------

;-----------------------------------------------------------------		
;----------------------- GPIO init -------------------------------
;-----------------------------------------------------------------
		;STI		PORTA_DIRSET,0xff
		;STI		PORTA_OUTSET,0X00
		oti 	TRO_VDIR,		0xFF & ~(TX_PIN)
		Sbi		TRO_VOUT,		TX_PIN
		cbi		TRO_VDIR,		RX_PIN
;-----------------------------------------------------------------	

;-----------------------------------------------------------------
;--------------------- Usart config ------------------------------
;-----------------------------------------------------------------	
		STI 	USART0_CTRLC, 	0b00000011 					;CMODE[1:0] PMODE[1:0] SBMODE CHSIZE[2:0]	(CHSize - rozmiar znaku)
		STIW	USART0_BAUD,	USART_SPEED 				;(BAUD[15:6]) hold the integer part, while the 6 LSBs (BAUD[5:0]) hold the fractional part.

		STI		USART0_DBGCTRL,	0x00							;.0 DBG_rubn bit
		;		config dla irdy tylko
		STI		USART0_EVCTRL,	0x00							;.0 IREI irda event input bit
		STI		USART0_RXPLCTRL,0x00							;txpulse len
		STI		USART0_TXPLCTRL,0x00							;rxpulse len

		SETBIT	PORTMUX_CTRLB,	0b00000001					;--- TWI0 - SPI0 - USART0 
		STI 	USART0_CTRLA, 	0b11100000 					;RXCIE TXCIE DREIE RXSIE LBME ABEIE RS485[1:0]
		STI		USART0_STATUS,	0b11100000					;RXCIF TXCIF DREIF RXSIF ISFIF BDF WFB
		SETBIT 	USART0_CTRLB, 	0b11000000 					;RXEN TXEN SFDEN ODME RXMODE[1:0] MPCM	
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;------------ ***  CPUINT - Interrupt Controller  *** ------------
;-----------------------------------------------------------------	
/*		
		STI CPUINT_CTRLA,\
		0<<CPUINT_IVSEL_bp|\
		0<<CPUINT_CVT_bp|\
		1<<CPUINT_LVL0RR_bp									;wlacza round robin	(bez wplywu na level1 priority) / w tym avr level 1 ma wyzszy priorytet od level 0							
		;STI		CPUINT_STATUS,                  				;Status
		;STI		CPUINT_LVL0PRI,              					;Interrupt Level 0 Priority - mozna odczytac w jakim przerwaniu sie jest
		STI		CPUINT_LVL1VEC,TCA0_OVF_vect	    				;Select the priority level 1 vector by writing its address to the Interrupt Vector
*/

		ret
;------------------------eof--------------------------------------