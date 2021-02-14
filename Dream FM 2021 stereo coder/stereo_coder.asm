;===========================================================
;================== Dream FM 2021 =========================
;================== coder_stereo.asm =======================
;===========================================================
;MCU - 90s2313 (przedpotopowy :) mozna uzyc tiny 2313 )
;ale gdybym mial dzisiaj wybrac avr, to Tiny212 powinien
;obsluzyc wszystko co potrzeba + ma wbudowany DAC 
;
;XTAL - 6004kHz
;3.3V 9.5mA (5V 15mA)
;V1 -2010 tlyko podstawowa funkcja generatora i strojenie
;V2 -2021 refaktoring kodu + poprawka bledu 1 probki 1 lsb + 
;sygnalizacja stanu przez led + zapis fazy w pamieci lustrzanej
;+ sterowanie przez usart 19.2kb (rozkaz SCctlXX, SCphaXX) 
;powerdown + mono mode, poprawiony problem z uszkadzaniem eeprom 
;dodany auto naprawialny eeprom oraz predelay ~1 sekunda
;
;na tym HW jest jeden stabilizator 3.3V do zasilnia wszystkiego
;===========================================================

/*
	Program do kodera stereo, generowanie sinus 19kHz 7bit DDS
	oraz 38kHz na OC1 timerem1, synchroniczne do napiecia z DACa
	regulacja przesuniecia fazy pilota, krok okolo 2 stopnie ~166ns na CK
	PHASE = 0 = zgodne zbocze narastajace 19kHz & 38kHz (po strojeniu offset wynosil ~ +1.8us i taki jest domyslnie zapisany)

	Sygnalizacja stanu przez LED:
	LED miga powoli jesli zablokowane klawisze i wszysto ok (prad zmniejszony jasnosc mniejsza). Identyczne zachowanie, gdy dostanie wartosc fazy rozkazem z usartu
	LED miga bardzo szybko jesli blad eeprom i brak poprawnej wartosci fazy pilota (tryb DETUNE_PROTECT)
	LED miga srednio gdy odblokowane klawisze i tryb strojenia
	LED miga szybciej gdy nieuzywany tryb DETUNE_PROTECT a wartosc fazy domyslna (np po uszkodzeniu eeprom)
	LED ma wypelnianie ~3/4 w trybie mono lub Auto mono

	Sterowanie:
	Regulacji fazy dokonuje sie przez porty int0 int1, kazda zmiana zapisywana do eeprom
	Jeeli int0 oraz int1 zwarte do masy, to strojenie portami jest zablokowane (LED przygaszony)
	Zmiane fazy mozna tezuzyskac popzrez wyslanie esc codes kursorow lewo prawo. Wartosc nie zapisywana do eeprom
	Odebranie usartem rozkazu 'SCphaXX' ustawia wartosc fazy z parametru XX hexadecymalnie (rozkaz konczy znak 0x0D LF lub timeout)
	Odebranie rozkazu 'SCstaXX' ustawia rejestr z flagami bitowymi (statusF: mono, Amono, power)

	Znane niedogodnosci:
	Podczas odbioru znakow usartem faza pilota ulega przesunieciu
	na krotka chwile do czasu ponownego zsynchronizowania (nie mozna nic na to poradzic, brak zasobow)
	EEprom podatny na uszkodzenia, ale po dodaniu predelay i czekaniu na flagi zapsiu eeprom jest juz ok
*/

.include 	"2313def.inc"
.include 	"macro.inc"
.include 	"sinus_table.inc"

;#define DETUNE_PROTECT										;jesli nowy nvram to nie uruchamiaj kodera (wymuszenie strojenia), po dodaniu mozliwosc ladowania PH usartem nie ma sensu tego wlaczac
#define 	LF_ENDSTR 										;znak LF za potwierdzeniem OK https://www.loginradius.com/blog/async/eol-end-of-line-or-newline-characters/
.equ	PHASE_STEPS =	158									;ilosc krokow tablicy sinusa
.equ	PHASE_DEF =		11									;domyslna wartosc przesuniecia fazy na +
.equ	PHASE0_TUNE =	61									;wartosc przesuniecia cykli zegara przy starcie, dobrana aby zbocza narastajace sygnalu 38kHz z OC1 oraz b.7 Daca R2R byly zgodne dla zmiennej glownej phase = 0
.equ 	UBRR_VAL=		18									;predkosc usartu 19.200kb/s

.equ 	LF_CHAR	=		0x0A								;znak konca linii dla usart RX (LF 0x0A) (CR 0x0D tylko do tetow)
.equ 	LF_Tout	=		2									;timeout bufora usart (19kHz /256/256	~2.5s max timeout)
.equ	AUTO_MONOTO =	50									;timeout dla automono 50 = ~1s
.equ	RXB_SIZE = 		32									;bufor odbiodnika RX
.equ	PARAM_SIZE=		8									;bufor parametru rozkazu

.def 	Led_Cl = 		R21
.def 	Led_Ch = 		R22
.def 	status = 		R23									
.equ	statusF_mono = 	0									;b.0 = mono - pilot wylaczony
.equ	statusF_Amono = 1									;b.1 = automono - pilot wylaczany automatycznie na krotki czas gdy faza zaburzona
.equ	statusF_power = 7									;b.7 = power down - sleep procesora
.def	autoMonoPRS = 	R11									;preskaler czasu automatycznego wylaczenia pilota gdy transfer usart (i tak jest faza wtedy zla)
.def 	phase  = 		R12
.def 	keyLock= 		r13
.def 	one	=			R14
.def 	zero=			R15
.def	URXtoutCl = 	R24									;timeout 16bit dla odbioru linii znakow z usartu
.def	URXtoutCH = 	R25

.dseg
;-------------------- data RAM -----------------------------
.org	SRAM_START		+16									;NVRAMSTART
nvramData:
phaseRam:		.Byte	8									;2 x 4 kopie
dummy:			.Byte	8
autoMonTO:		.Byte	2
;-----------------------------------------------------------

.cseg
;===========================================================
.include	"irqVect.asm"									;wektory przerwan i programy wolane z tamtad
.include	"eepReal90s.asm"								;eeprom ram copy
.include 	"usartTX.asm"									;usart tx
.include 	"usartRX.asm"									;usart rx
;===========================================================

;-----------------------------------------------------------
welcome_version:
.db	"Dream FM 2021 Stereo Coder V0.2",0
phase_str:
.db "Phase:",0,0
VT100_init:
.db 27,'[', '?' ,'2','5', 'l',0,0
;-----------------------------------------------------------

;===========================================================
;--------------------- main --------------------------------
;===========================================================
init:
		wdr
		;oti 	wdtcr,0b00011010							;60-200ms
		oti 	wdtcr,0b00011000							;~50ms
		ldi 	r16, 0b00001001 							;ICNC1 ICES1 ––CTC1 CS12 CS11 CS10
		out 	tccr1b,r16									;start timer1 oc1out
		ldi		r29, 4
delay_loop:
;-------------- preset portow ------------------------------
		ldi 	r16,255										;konfiguracja portow in/out
		out 	ddrb,r16									
		ldi 	r16,0b00000010
		out 	ddrd,r16
		ldi 	r16,255
		
		bst 	r29,0										;pre miganie led
		bld 	r16,6			
		out 	portd,r16
;---------------- pre delay --------------------------------;opoznienie startu zabezpeicza eeprom
		wdr
		sbiw	z,1
		brne	delay_loop
		dec		r29
		brne	delay_loop
;-----------------------------------------------------------
start:
;-----------------------------------------------------------
;		clr 	r0											;zerowanie rejestrow (nie ram, bo nieuzywany byl nawet)
;		clr 	r31
;		ldi 	r30,29
;regclear:
;		st 		-z,r0
;		cpi 	r30,0
;		brne 	regclear
;-----------------------------------------------------------
;---------------- usart ------------------------------------
		oti		ucr, 1<<TXEN | 0<<RXEN | 0<<RXCIE			;RXCIE TXCIE UDRIE RXEN TXEN CHR9 RXB8 TXB8 
		oti		ubrr,UBRR_VAL 				
;-----------------------------------------------------------		

		ldi 	r16,low(RAMEND)								;stos
		out 	SPL,r16										;ustawia wskaznik stosu
		
		clr		status										;zawsze kasowane flagi statusowe
		clr		zero
		clr		one
		inc		one

		ldi		r16,3
		mov		keyLock,r16
		sbis	pind,3										;jesli portD.3 oraz d.2=0 strojenie niemozliwe (nie moze byc or, poniewaz po aktywnosci jest reset i sprawdzanie na blokade klawiszy)
		dec		keyLock
		sbis	pind,2
		dec		keyLock
		cp		keyLock,one
		breq	keys_locked
		sbi 	ddrd,6
		oti 	gimsk,0b11000000							;enable int0,int1
keys_locked:
;------------ welcome --------------------------------------


		ldiwz 	VT100_init*2
		rcall 	usart_romstring
		rcall	NVRAMrestore
		rcall	phase_read
		rcall	usart_nl
		ldiwz 	welcome_version*2
		rcall 	usart_romstring
		rcall	usart_nl
		ldiwz 	phase_str*2
		
		rcall 	usart_romstring
		mov		r16,phase
		rcall	usartsend_hex

;----------- wskaznik stosu resetowany ---------------------
mode_select:
		wdr
		clt	
		sbrs 	status,statusF_Amono						;chwilowy tryb mono po odczycie danych usartem (nie dodtyczy strojenia pinami procesora)
		rjmp	no_Amonomode
		lds		r16,autoMonTO
		cp		r16,zero
		brne	pc+2
		set													;t ustawione tylko gdy swiezo po odebraniu znaku i timeout wynosi 0 (w innym razie nie bedzie wchodzil w Automono loop)
no_Amonomode:
		sbrc 	status,statusF_power
		rjmp	powerdown_loop								;powerdown
		oti		ucr, 1<<TXEN | 1<<RXEN | 1<<RXCIE			;odbiornik wlaczany dopiero tutaj, bo nie ma powrotu z przerwania URX przez reti


;===========================================================
;-------------- synchronizer  ------------------------------
;===========================================================		
		oti		tccr1a,0b01000000
		oti 	tccr1b,0
		
		oti		tcnt1h,0
		oti		tcnt1l,50
		
		oti		ocr1ah,0
		oti		ocr1al,79-1
		
		oti 	tccr1b,0b00001001
wait_state:		
		sbic	pinb,3
		rjmp	wait_state
wait_state1:		
		sbis	pinb,3
		rjmp	wait_state1

		oti		tcnt1h,0
		oti		tcnt1l,PHASE0_TUNE							;kompensacja czasu (0 przesuniecia fazy dla phase = 0)

		ldi 	r16,low(RAMEND)								;stos
		out 	SPL,r16										;ustawia wskaznik stosu

		sei
		brtc	pc+2
		rjmp	mono_loop									;jesli tryb amono i czas timeout nie uplynal
		sbrc 	status,statusF_mono
		rjmp	mono_loop									;tryb mono (tylko pilot wylaczony)
;-----------------------------------------------------------	
;6004/19=316:2clk=158 probek na caly okres sinus 1probka =2clk
;krok 250ns(4MHz)
;program przygotowuje rejestr Z oraz R18 dla generacji 
;opoznienia cykli zegara rownej Phase					
;-----------------------------------------------------------
		mov 	r17,Phase									;Phase=przesuniecie fazy		
		mov 	r18,Phase
		ldi 	r30,byte1(ijmpvector)
		ldi 	r31,byte2(ijmpvector)
		andi 	r17,0b00000011								;tylko 0-3 dwa najmlodsze bity wplywaja na skok ijmp w programie 'delay'
		sub 	r30,r17										;od adresu ivector odejmij dwa najmlodsze bity wartosci opoznienia
		
		lsr 	r18
		lsr 	r18											;6 najstarszych bitow wartosc opoznienia w petli delay
		inc 	r18											;dla 0= 4clk opoznienia 

		ldi 	r16, 0b00001001								;ICNC1 ICES1 ––CTC1 CS12 CS11 CS10
		out 	tccr1b,r16									;start timer1 oc1out
delay:														;jedna 'petla' =4clk opoznienia
		dec 	r18											;opoznienie cykli zegara zalezne od r18
		nop
		brne 	delay										;w rejestrze Z wartosc delay dla ijmp
		ijmp												;opoznienie dodatkowych taktow zegara w celu precyzyjnej regulacji zaleznowsci fazowej pomiedzy oc1 a DDS w petli programu
		nop													;+3clk
		nop													;+2clk
		nop													;+1clk
ijmpvector:													;0clk
;-----------------------------------------------------------
;===========================================================


;===========================================================
;=========== Tryb streo generator 19kHz ====================
;===========================================================
_19kHzDDSLOOP:
		ldi 	r16,SIN3
		out 	portb,r16
		ldi 	r16,SIN4
		out 	portb,r16
		ldi 	r16,SIN5
		out 	portb,r16
		ldi 	r16,SIN6
		out 	portb,r16
		ldi 	r16,SIN7
		out 	portb,r16
		ldi 	r16,SIN8
		out 	portb,r16
		ldi 	r16,SIN9
		out 	portb,r16
		ldi 	r16,SIN10
		out 	portb,r16
		ldi 	r16,SIN11
		out 	portb,r16
		ldi 	r16,SIN12
		out 	portb,r16
		ldi 	r16,SIN13
		out 	portb,r16
		ldi 	r16,SIN14
		out 	portb,r16
		ldi 	r16,SIN15
		out 	portb,r16
		ldi 	r16,SIN16
		out 	portb,r16
		ldi 	r16,SIN17
		out 	portb,r16
		ldi 	r16,SIN18
		out 	portb,r16
		ldi 	r16,SIN19
		out 	portb,r16
		ldi 	r16,SIN20
		out 	portb,r16
		ldi 	r16,SIN21
		out 	portb,r16
		ldi 	r16,SIN22
		out 	portb,r16
		ldi 	r16,SIN23
		out 	portb,r16
		ldi 	r16,SIN24
		out 	portb,r16
		ldi 	r16,SIN25
		out 	portb,r16
		ldi 	r16,SIN26
		out 	portb,r16
		ldi 	r16,SIN27
		out 	portb,r16
		ldi 	r16,SIN28
		out 	portb,r16
		ldi 	r16,SIN29
		out 	portb,r16
		ldi 	r16,SIN30
		out 	portb,r16
		ldi 	r16,SIN31
		out 	portb,r16
		ldi 	r16,SIN32
		out 	portb,r16
		ldi 	r16,SIN33
		out 	portb,r16
		ldi 	r16,SIN34
		out 	portb,r16
		ldi 	r16,SIN35
		out 	portb,r16
		ldi 	r16,SIN36
		out 	portb,r16
		ldi 	r16,SIN37
		out 	portb,r16
		ldi 	r16,SIN38
		out 	portb,r16
		ldi 	r16,SIN39
		out 	portb,r16
		ldi 	r16,SIN40
		out 	portb,r16
		ldi 	r16,SIN41
		out 	portb,r16
		ldi 	r16,SIN42
		out 	portb,r16
		ldi 	r16,SIN43
		out 	portb,r16
		ldi 	r16,SIN44
		out 	portb,r16
		ldi 	r16,SIN45
		out 	portb,r16
		ldi 	r16,SIN46
		out 	portb,r16
		ldi 	r16,SIN47
		out 	portb,r16
		ldi 	r16,SIN48
		out 	portb,r16
		ldi 	r16,SIN49
		out 	portb,r16
		ldi 	r16,SIN50
		out 	portb,r16
		ldi 	r16,SIN51
		out 	portb,r16
		ldi 	r16,SIN52
		out 	portb,r16
		ldi 	r16,SIN53
		out 	portb,r16
		ldi 	r16,SIN54
		out 	portb,r16
		ldi 	r16,SIN55
		out 	portb,r16
		ldi 	r16,SIN56
		out 	portb,r16
		ldi 	r16,SIN57
		out 	portb,r16
		ldi 	r16,SIN58
		out 	portb,r16
		ldi 	r16,SIN59
		out 	portb,r16
		ldi 	r16,SIN60
		out 	portb,r16
		ldi 	r16,SIN61
		out 	portb,r16
		ldi 	r16,SIN62
		out 	portb,r16
		ldi 	r16,SIN63
		out 	portb,r16
		ldi 	r16,SIN64
		out 	portb,r16
		ldi 	r16,SIN65
		out 	portb,r16
		ldi 	r16,SIN66
		out 	portb,r16
		ldi 	r16,SIN67
		out 	portb,r16
		ldi 	r16,SIN68
		out 	portb,r16
		ldi 	r16,SIN69
		out 	portb,r16
		ldi 	r16,SIN70
		out 	portb,r16
		ldi 	r16,SIN71
		out 	portb,r16
		ldi 	r16,SIN72
		out 	portb,r16
		ldi 	r16,SIN73
		out 	portb,r16
		ldi 	r16,SIN74
		out 	portb,r16
		ldi 	r16,SIN75
		out 	portb,r16
		ldi 	r16,SIN76
		out 	portb,r16
		;ldi 	r16,SIN77
		;out 	portb,r16
		;ldi 	r16,SIN78
		;out 	portb,r16
		;ldi 	r16,SIN79
		;out 	portb,r16
		;ldi 	r16,SIN80
		;out 	portb,r16
		;ldi 	r16,SIN81
		;out 	portb,r16
		;mozliwe 10 cykli zegara do zagospodarowania
;-------------------- usart RX -----------------------------
;'rcall	usart_rx_buffer										;odbior danych z bufora usartu i wykonywanie zadania
;rcall	usart_rx_write	
		usartRXproc											;macro 9CK when standby

		nop;
;		nop
;		nop
/*
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		*/
		ldi 	r16,SIN82
		out 	portb,r16
		ldi 	r16,SIN83
		out 	portb,r16
		ldi 	r16,SIN84
		out 	portb,r16
		ldi 	r16,SIN85
		out 	portb,r16
		ldi 	r16,SIN86
		out 	portb,r16
		ldi 	r16,SIN87
		out 	portb,r16
		ldi 	r16,SIN88
		out 	portb,r16
		ldi 	r16,SIN89
		out 	portb,r16
		ldi 	r16,SIN90
		out 	portb,r16
		ldi 	r16,SIN91
		out 	portb,r16
		ldi 	r16,SIN92
		out 	portb,r16
		ldi 	r16,SIN93
		out 	portb,r16
		ldi 	r16,SIN94
		out 	portb,r16
		ldi 	r16,SIN95
		out 	portb,r16
		ldi 	r16,SIN96
		out 	portb,r16
		ldi 	r16,SIN97
		out 	portb,r16
		ldi 	r16,SIN98
		out 	portb,r16
		ldi 	r16,SIN99
		out 	portb,r16
		ldi 	r16,SIN100
		out 	portb,r16
		ldi 	r16,SIN101
		out 	portb,r16
		ldi 	r16,SIN102
		out 	portb,r16
		ldi 	r16,SIN103
		out 	portb,r16
		ldi 	r16,SIN104
		out 	portb,r16
		ldi 	r16,SIN105
		out 	portb,r16
		ldi 	r16,SIN106
		out 	portb,r16
		ldi 	r16,SIN107
		out 	portb,r16
		ldi 	r16,SIN108
		out 	portb,r16
		ldi 	r16,SIN109
		out 	portb,r16
		ldi 	r16,SIN110
		out 	portb,r16
		ldi 	r16,SIN111
		out 	portb,r16
		ldi 	r16,SIN112
		out 	portb,r16
		ldi 	r16,SIN113
		out 	portb,r16
		ldi 	r16,SIN114
		out 	portb,r16
		ldi 	r16,SIN115
		out 	portb,r16
		ldi 	r16,SIN116
		out 	portb,r16
		ldi 	r16,SIN117
		out 	portb,r16
		ldi 	r16,SIN118
		out 	portb,r16
		ldi 	r16,SIN119
		out 	portb,r16
		ldi 	r16,SIN120
		out 	portb,r16
		ldi 	r16,SIN121
		out 	portb,r16
		ldi 	r16,SIN122
		out 	portb,r16
		ldi 	r16,SIN123
		out 	portb,r16
		ldi 	r16,SIN124
		out 	portb,r16
		ldi 	r16,SIN125
		out 	portb,r16
		ldi 	r16,SIN126
		out 	portb,r16
		ldi 	r16,SIN127
		out 	portb,r16
		ldi 	r16,SIN128
		out 	portb,r16
		ldi 	r16,SIN129
		out 	portb,r16
		ldi 	r16,SIN130
		out 	portb,r16
		ldi 	r16,SIN131
		out 	portb,r16
		ldi 	r16,SIN132
		out 	portb,r16
		ldi 	r16,SIN133
		out 	portb,r16
		ldi 	r16,SIN134
		out 	portb,r16
		ldi 	r16,SIN135
		out 	portb,r16
		ldi 	r16,SIN136
		out 	portb,r16
		ldi 	r16,SIN137
		out 	portb,r16
		ldi 	r16,SIN138
		out 	portb,r16
		ldi 	r16,SIN139
		out 	portb,r16
		ldi 	r16,SIN140
		out 	portb,r16
		ldi 	r16,SIN141
		out 	portb,r16
		ldi 	r16,SIN142
		out 	portb,r16
		ldi 	r16,SIN143
		out 	portb,r16
		ldi 	r16,SIN144
		out 	portb,r16
		ldi 	r16,SIN145
		out 	portb,r16
		ldi 	r16,SIN146
		out 	portb,r16
		ldi 	r16,SIN147
		out 	portb,r16
		ldi 	r16,SIN148
		out 	portb,r16
		ldi 	r16,SIN149
		out 	portb,r16
		ldi 	r16,SIN150
		out 	portb,r16
		ldi 	r16,SIN151
		out 	portb,r16
		ldi 	r16,SIN152	;jak 151 
		out 	portb,r16
		ldi 	r16,SIN153
		out 	portb,r16
		ldi 	r16,SIN154	;jak 153
		out 	portb,r16
		ldi 	r16,SIN155
		out 	portb,r16
		;przez kolejne 10 cykli zegara nie zmieniana wartosc probki,
		;wiec mozna zrobic tu ... miganie dioda :)
		;ldi 	r16,SIN156
		;out 	portb,r16
		;ldi 	r16,SIN157
		;out 	portb,r16
		;ldi 	r16,SIN0
		;out 	portb,r16
		;ldi 	r16,SIN1
		;out 	portb,r16
		;ldi 	r16,SIN2
		;out 	portb,r16

;------------ 8clk + 2clk ---------------------------------
		wdr
		add 	Led_Cl,keyLock								;16bit counter + zmienna zalezna od blokady klawizy
		brcc 	n1
		inc 	Led_Ch
n1:
		ldi 	r16,0b01111100								;led flasher (19kHz/32768)
		bst 	Led_Ch,6									;kopiuj bit.6 rejestru r22 do flagi T
		bld 	r16,6										;kopiuj z flagi T do  bitu .6 rejestru R29
		out 	portd,r16									;mrugaj dioda jesli wszystko ok
								;mrugaj dioda jesli wszystko ok
		rjmp 	_19kHzDDSLOOP								;2clk
;-----------------------------------------------------------
;===========================================================
;============= Tryb mono bez pilota 19KHz ==================
;===========================================================
mono_loop:
		wdr
		;ldi 	r16,SIN39									;1/2 VPP
		ldi 	r16,SIN76									;0V - wartosc gdzie usart RX wychodzi z petli glownej po analizie orzkazu (wartosc gdy wystapi przerwanie przypadkowa)
		out 	portb,r16

		usartRXproc
		ldi 	r17,64										;dobrane na podobne ooznienie jak przy trybie 19kHz
del_loop:
		dec		r17
		brne	del_loop

;------ dokladnosc czasu tylko dla tout usartu -------------
		nop
		add 	Led_Cl,keyLock								;16bit counter + zmienna zalezna od blokady klawizy
		brcc 	n2
		inc 	Led_Ch
				
n2:
		cpi		Led_Ch,25									;w trybie mono wypelnianie migania led nie wynosi50% tylko  ~85
		brsh	n2a
		cbi		portd,6
		rjmp	n3
n2a:
		ldi 	r29,0b01111100								;led flasher (19kHz/32768)
		out 	portd,r29									;mrugaj dioda jesli wszystko ok
n3:		
		
		inc 	autoMonoPRS									;preskaler czasu
		brne	mono_loop

		sbrs 	status,statusF_Amono						;jesli bit automono to przelacz na stereo po timeoutcie
		rjmp	mono_loopR
		sbrc 	status,statusF_mono							;jesli bit mono to nigdy nie wracaj do trybu stereo
		rjmp	mono_loopR

		incrs 	autoMonTO
		cpi		r16,AUTO_MONOTO
		brlo	mono_loopR
		
		rjmp	mode_select
mono_loopR:
rjmp	mono_loop

;===========================================================
;=============== Zatrzymanie procesora PD ==================
;===========================================================
powerdown_loop:
		cli
		in	 	r17, USR
		sbrs 	r17,UDRE
		rjmp 	powerdown_loop
		ldi 	r16,0b00011000						
		out 	wdtcr,r16									;wylaczanie wdt
		ldi 	r16,0b00010000						
		out 	wdtcr,r16
		out		ddrd,zero
		out		portd,zero
		oti		mcucr, 1<<SE|1<<SM							;power down mode
		sleep
;====================== END ================================

