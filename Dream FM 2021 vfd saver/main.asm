;=================================================================
;================== Dream FM 2021 VFD saver ======================
;========================= main.asm ==============================
;=================================================================
;fuses: 16MHz, MCK BOD 3.3V
;AS7 project	
/*
  Prorgam steruje jasnoscia wyswietlacza VFD oraz podswietlanai LED
  wysylanie danych przez usart jest buforowane (pol ramu zjada bufor)
  program odbiera rozkazy i ustawia prady parametrem z rozkazu
*/
;-----------------------------------------------------------------

#define	LF_ENDSTR
#define MULMASTER											;po wyslaniu odlaczane wyjscie TX

.equ		MCK_FREQ			=	16000000/2					;zegar domyslny 8MHz
.equ		USART_TRX_BAUD		=	19200
.equ		USART_SPEED			=	(64*MCK_FREQ)/(16*USART_TRX_BAUD)

.equ 	LF_CHAR				=	0x0A							;znak konca linii dla usart RX (LF 0x0A) (CR 0x0D tylko do tetow)
.equ 	LF_Tout				=	5							;timeout bufora usart 200 =~2s
.equ		RXB_SIZE			= 	16							;bufor odbiodnika RX
.equ		TXB_SIZE			=	64							;rozmair bufora nadawczego usart
.equ		PARAM_SIZE			=	8							;bufor parametru rozkazu
;---------------------port config----------------------------------
;do portow io mozna dostac sie na dwa rodzaje rejestrow
;porty virtualne znajduja sie w przestrzeni obslugiwanej przez sbi/cbi
.equ		TRO_PORT_OUT		=	PORTA_OUT
.equ		TRO_PORT_OUTSET		=	PORTA_OUTSET
.equ		TRO_PORT_OUTCLR		=	PORTA_OUTCLR
	
.equ		TRO_VIN				=	VPORTA_IN
.equ		TRO_VOUT			=	VPORTA_OUT
.equ		TRO_VDIR			=	VPORTA_DIR
.equ		TRO_VINTFLAGS		=	VPORTA_INTFLAGS	
;numery pinow jedynego portu komunikacj A	
.equ		TX_PIN				=	1
.equ		RX_PIN				=	2
.equ		LED_PIN				=	3
;--------------------config---------------------------------------						
.def		zero				=	R15
.def		one					=	R14
	

.def		SFLAGS				=	R25							;szybkie flagi	
.equ		sec1_f				=	0							;Flaga 1Hz
.equ		msec_f				=	1							;flaga 17kHz

.def		DACDisPrescalerL	=	R12
.def		DACDisPrescalerH	=	R13							;preskaler czasu dla wylaczania daca aby lagodnie zjechac do napiecia zero w przeciwnym razie rozblysk vfd z przeladowania kondesnatora
.def		URXtoutCl			=	R22							;timeout usartRX
.def		URXtoutCh			=	R23
.def		URXtprescaler		=	R24
;-----------------------------------------------------------------	
														
;-----------------------------------------------------------------	
;---------------------- data segment -----------------------------
;-----------------------------------------------------------------	
.dseg
vbat:			.Byte	1									;napiecie adc
vfdVoltage:		.Byte	1									;naliecie dla VFD 
ledVoltage:		.BYte	1									;napeicie dla led
;-----------------------------------------------------------------

;----------------- usart TX RAM ----------------------------------
.dseg
UTXbuffer:		.Byte	TXB_SIZE							;bufor usart
UTXpRD:			.Byte	1									;wskanziki ramki usart
UTXpWR:			.Byte	1

;----------------- usart RX RAM ----------------------------------
URXbuffer:		.Byte	RXB_SIZE							;bufor usart
URXpWR:			.Byte	1									;wskaznik bufora zapisu
URXpRD:			.Byte	1									;wskaznik bufora odczytu
URXparam:		.Byte	PARAM_SIZE							;obszar na odczyt parametru rozkazu
;-----------------------------------------------------------------	
.cseg	
;=================================================================
;---------------------- code segment -----------------------------
;=================================================================
#include "macro.inc"
#include "irq_vect.asm"
#include "init.asm"
#include "usartTX.asm"
#include "usartRX.asm"
;#include "dbg_screen.asm"

;------------------------ etykiety -------------------------------
.cseg
_welcome_b:
.db 27,91,72,"Dream FM 2021 VFD saver V1.0",0
_defatr_b:
.db 27,91,0,59,'2',59,'3','7','m',0
_home_b:
.db 27,91,72,0
_cls_b:
.db 27,91,'2','J',0,0
;-----------------------------------------------------------------
main_start:
		wdr
	ldi r25,109
	ser r22
	ser r23
	ser r24 
	mov	r12,r24
	mov	r13,r23


		CLR		zero
		CLR		one
		INC		one
		OTI		CPU_SPL, low(RAMEND)
		OTI		CPU_SPH, high(RAMEND)
;=================================================================

ramclearR19:
;----------------------- ramclear --------------------------------
;kasuje od max pozycji-2 ram w dol (kasuje stos !)
ser r16
		ldiw	r19,r20,(SRAM_START)						;jesli UTXpWR bedzie mial przypadkowa wartosc to katastrofa ;)
		ldi		r30,low(RAMEND-2)
		ldi		r31,high(RAMEND-2)
ramclearloop:
		st 		-z,zero
		cp	 	r30,r19		
		cpc		r31,r20		
		brne 	ramclearloop
;-----------------------------------------------------------------
		rcall	init_0
		clear	URXpWR
;-----------------------------------------------------------------
		sei
		rcall	WELCOME_B
		rcall 	NL_0_B
mainloop_0:
wdr
		sbrc 	SFLAGS,sec1_f
		rcall	sec_func

		sbrc 	SFLAGS,msec_f
		rcall	msec_func

rjmp		mainloop_0
;=================================================================
msec_func:
		cbr 		SFLAGS,1<<msec_f

		;dec		URXtprescaler
		;brne		retu_0
		;ldi		URXtprescaler,8
		rcall	usart_rx_buffer
retu_0:
ret
;-----------------------------------------------------------------
sec_func:
		cbr		SFLAGS,1<<sec1_f				
		;rcall	consoleScreen_		
ret

;-----------------------------------------------------------------
.exit
;-----------------------------------------------------------------
delayr:
		dec			r16
		brne 	delayr
		dec			r17
		brne 	delayr
ret		
;-----------------------------------------------------------------
