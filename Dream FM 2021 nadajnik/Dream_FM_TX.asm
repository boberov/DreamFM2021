;===========================================================
;==================== Dream FM 2021  =======================
;=================== Dream_FM_TX.asm =======================
/*==========================================================
AT90S2313 XTAL 4MHz	
przerwanie OVF0 i flaga F30Hz_f 30Hz
czestotliwosc zlicza counter1  (wejscie licznika wspoldzielone z CK microwire syntezera)
============================================================*/

/*
Algorytm sledzenia
Rozpoznawane sa dwa rodzaje zachowanie sie sledzonej czestotliwosci
1. Rozpoznawanie czestotliwosci stabilnej - po okreslonym czasie braku zmian czetotliwosci zmierzonej - podejmowana akcja ustawienie pll na te czestotliwosc bez offsetu oraz wyslanie tej wartosci przez usart
2. Rozpoznawanie strojenia czestotliwosci w gore lub w dol - w fm 915 np po nacisnieciu automatycznego skanowania
	Dla rozpoznania takiej akcji dzieja sie nastepujace rzeczy
- po pierwszym rozpoznaniu zmian monotonicznych 3 czestotliwosci jest ustawiana czestotliwosc LMXA na zmierzona wartosc + offset 
- w przypadku ciaglego strojenia przez okreslony czas nie jest zmieniana czestotliwsc nadajnika (trwa oczekiwania na dogonienie tej F przez skaner odbiornika)
	jezeli po tym czasie nadal trwa strojenie odbiornika to znowu jest ustaiana F nadajnika z offsetem (oczywiscie offset jest + lub - zaleznie od kierunku strojenia)
*/

/*
	Obslugiwane rozkazy:
	Odebranie usartem rozkazu 'TXon' zalacza nadajnik (po starcie jest domyslnie wylaczony)
	Rozkaz 'TXoff' wylacza nadajnik (zasilanie LDO)
	Rozkaz 'TXshd'	usypia calkowicie procek (generator kwarcowy wylaczony, wszystkie zasilania odlaczone)

	Rozkaz z parametrem 'TXpowXX' zmienia moc nadajnika X=00 - 03 (hex)
	Rozkaz z parametrem 'TXdimXX' zmienia wartosc PWM X=00 - 80 (hex)
	Rozkaz z parametrem 'TXfrq107.8'	ustawia czestotliwosc 107.8MHz
	Rozkaz z parametrem 'TXfrq87.7'		ustawia czestotliwosc 87.7MHz
	Rozkaz z parametrem 'TXfrq087.7'	ustawia czestotliwosc 87.7MHz


V1.1
bramkowanie czestosiomierza zwiekszone do ~30Hz i wyrownana z podzialem dwojkowym, lsb w mierniku sa odrzucane (bezuzyteczne z owodu jitteru)
odbior znakow usartem przerwaniowy (pomiar odrzucany jesli wystapilo przerwanie usartu)
parametry dla mocy i dim w hex 8bit
soft pwm do regulacji jasnosci vfd w przrwaniu timera f ~61Hz
V1.2 
obsluga multi master usart, na wypadek kolizji, nie wysyla danych o freq na zadany czas po odebraniu danych nie do siebie, oraz odlacza portTX gdy nie nadaje (jak halfduplex)
zmiany w czasach detekcji zmian czestotliwosci i dla skanowania
pll err ino odlaczone bo nie zmiescilo sie juz
*/
#define	DEFAULT_TXON
#define MULMASTER						;odlacza TX po wyslaniu danych na czas MULMASTER_TXTO oraz uduchamia blokowanie nadawania asynchronicznego na czas MULMASTER_RXTO
;#define	PLL_ERROR_DET					;wysylanie asynchroniczne info ze PLL niezlapalo juz dlugi czas
#define	MULMASTER_TXTO	10				;100 = ~10ms
#define MULMASTER_RXTO 	6				;6 = ~100ms

#define	DEFAULT_POWER	1										
#define LF_ENDSTR						;https://www.loginradius.com/blog/async/eol-end-of-line-or-newline-characters/
#define UBRR_VAL		12				;19200 (raspi ma cos skopane i nie obsluguje 250kb, a pozniej najwieksza predkosc z malym bledem do 19200) i tak jest dramatycznie niska predkosc maksymalna 250kb/s dla 4MHz zegara
#define FREQ_INTERM		-107			;posrednia w 100kHz o jaka trzeba przesunac czestotliwosc dla zgodnosci wskazan
#define	BAND_LOW_MHZ	875
#define	BAND_HIGH_MHZ	1080

#define	BAND_LOW_FRAW	0x0F			;surowa wartosc MSB z czestosciomierza do okreslenia czy pomiary sa sprawne - trzeba zmienic jesli posrednia sie zmieni
#define	BAND_HIG_FRAW	0x12


;#define OVER_BAND_RETU					;jesli skanowanie i blisko granicy to ustawia szybciej nadajnik na drugim koncu pasma
;#define FREQ_DBG						;wysylanie na usart aktualnie zmierzonej czestotliwosci (surowizna z jitterem duzym)
;#define	SYM_HYST					;jesli histereza symetryczna wyniku pomiaru
#define SCAN_F_SHIFT	1				;x100kHz przesuniecie instalacji nadajnika
#define SCAN_REATEMPT	80				;co jaki czas ponowic ustawienie czetotliwosci TX
#define STAB_FREQ		80				;po jakim czasie uznac zmierzona F za stabilna (30=1sek)
#define	LOCK_TIMEOUT	10				;czas w sekundach po jakim blad pll jesli nie wykryl choc chwile 1 na wyjsciu FO/LD


.include 	"2313def.inc"				;definicje rejestrow
.include 	"macro.inc"					;makra
.include 	"dataSeg.inc"				;zmienne w RAM
.include 	"irqVec.inc"				;vektory przerwan
.include	"LMX2306.asm"				;driver syntezera
.include	"usartTX.asm"				;procedury wysylania usart
.include	"usartRX.asm"				;procedury odbiornka usart
;.include	"IR_remote.asm"				;obsluga zdalnego sterowania odbiornikiem
;.include	"eepReal90s.asm"			;ten avr bez dobrego resetu uwielbia psuc eeprom

.def	one= 		R14
.def 	zero= 		R15
.def	SysFlags=	R25					;flagi systemowe
.def	softPWmC=	r10					;licznik pwm
.def	softPWmV=	r11					;wartosc pwm
.def	prescTim0=	r12					;licznik pomocniczy odmierzania czasu przerania cnt0
.def	lockPresc=	R13					;preskaler czasu bledu pll

;-----bity SysFlags-----
.equ	F30Hz_f			=	7			;flaga 30Hz ustawiana w przerwaniu timera
.equ	F15kHz_f		=	6			;flaga 32kHz ustawiana w przerwaniu
.equ	MeasReady_f		=	1			;pomiar czestotliwosci gotowy
.equ	MeasCancel_f	=	2			;pomiar pomijany (wspoldzielone clk i transmisja po uwire)

.equ	PWM_port=		portb
.equ	PWM_ddr=		ddrb
.equ	PWM_portNr=		3

.equ	UTRX_port=		portd
.equ	UTRX_ddr=		ddrd
.equ	URX_portNr=		0
.equ	UTX_portNr=		1
.cseg
welcome_version:
.db	"Dream FM 2021 Transmitter V1.2",0,0



;======================== main =============================
Init:
		wdr
;		oti 	wdtcr,0b00011000							;wlacza wdt ~50ms
		oti 	SPL,low(RAMEND)
		clr 	zero
		clr 	one
		inc		one
		oti		ucr, 1<<TXEN | 1<<RXEN | 1<<RXCIE			;RXCIE TXCIE UDRIE RXEN TXEN CHR9 RXB8 TXB8 
		oti		ubrr,UBRR_VAL 			
		sti		TXpower,DEFAULT_POWER						;default power
		clear	freqStabilC									;bez skasowania zmiennej czasowej po starcie moze niezauwazyc aktualnej czestotliwosci zmierzonej
;------------ port config ----------------------------------
		sbi		PWM_port,PWM_portNr
		sbi		PWM_ddr,PWM_portNr
		sbi		UTRX_port,UTX_portNr						;pullup gdy wylaczony TX
;------------ counter 0 ------------------------------------
		oti		tccr0,0<<CS00|0<<CS01|1<<CS02				;presc 256 (/256 = 61.03515625hz)
		;oti		tccr0,1<<CS00|0<<CS01|1<<CS02				;presc 1024 (licznik T0 skracany w przerwaniu)
		;oti		tccr0,1<<CS00|1<<CS01|0<<CS02				;presc 64 irq =62.5kHz

;------------ counter 1 ------------------------------------
		oti		tccr1a,0
		oti		tccr1b,1<<CS10|1<<CS11|1<<CS12				;ext clock input T1
;-----------------------------------------------------------
		oti 	timsk,0<<TOIE1|1<<TOIE0						;overflow interrupt
		oti		mcucr,1<<ISC00|1<<ISC01						;narastajace zbocze int0 ustawi flage

		rcall	usart_nl
		ldiwz 	welcome_version*2
		rcall 	usart_romstring
#ifdef DEFAULT_TXON
		rcall	RFTX_enable
#endif
		sei
mainloop:
;---------------------- main loop --------------------------	
		wdr
		sbrc 	SysFlags, F15kHz_f
		rcall	proc_15kHz	
		sbrc 	SysFlags, F30Hz_f
		rcall	proc_32Hz									;zadania cykliczne xxHz
		sbrc 	SysFlags, MeasReady_f 
		rcall	freqAnalise									;analiza pomiaru czestotliwosci


	;sbr		SysFlags, 1<<MeasCancel_f
;		rcall	usart_rx_write								;zapis danych do bufora (bez przerwaniowy)
		;ldi		r16, '1'
;		sbis	LMX_pin,LMX_FOLD
;		ldi 	r16,'0'
;		rcall usartsend
;-----------------------------------------------------------
rjmp mainloop
;==================== main end =============================



;-----------------------------------------------------------
;zadania cykliczne
;-----------------------------------------------------------
proc_15kHz:													;(15.625kHz)
		cbr 	SysFlags, 1<<F15kHz_f
;-------------------- usart RX -----------------------------
		rcall	usart_rx_buffer								;odbior danych z bufora usartu i wykonywanie zadania
#ifdef MULMASTER
		rcall	usart_mulmasterTout							;automatyczne odlaczania nadajnika
#endif
ret
proc_32Hz:
		cbr 	SysFlags, 1<<F30Hz_f

;------- zbuforowanie F zmierzonej w przerwnaniu -----------	
		loadw 	r30,r31,freqRXub
		storew	freqRX, r30,r31
;-----------------------------------------------------------	
		decrs	ScanActWaitC								;odlicza do zera czas
		incrs	URXtoutC									;timeout usartRX inkrementuje do max

#ifdef MULMASTER
		decrs	MULmastTOtxinh								;czas blokowania wysylania asynchronicznego (blokuje cala procedure sprawdzania pomiarow czestotliwosci)
#endif

#ifdef PLL_ERROR_DET

;-------------- pll error detector -------------------------
		in 		r16,GIFR									;rozpoznawanie pll lock flaga przerwania (lesze od poolingu bo sie zatrzaskuje)
		sbrs	r16,INTF0 
		rjmp	FO_LF_0
		sts		LOCKtimeC,zero								;jesli wykryto zbocze w jakims momencie (asynchronicznie)
		ldi		r16, 1<<INTF0								;skasowanie flagi 
		out		GIFR,r16
FO_LF_0:
		sbic	LMX_pin,LMX_FOLD
		sts		LOCKtimeC,zero								;kasowanie flagi jesli stan wysoki pinu (flaga przerwania reaguje tylko na zbocze)
;-----------------------------------------------------------


;-------------- pll error detektor -------------------------
		ldi		r16,30
		inc		lockPresc
		cp		lockPresc,r16
		brlo	wait_presc
		clr		lockPresc

		sbis	LMX_port,RF_ENABLE							;jesli tx wylaczony niewysylaj bledu
		rjmp	ret2


		incrs	LOCKtimeC	
		cpi		r16,LOCK_TIMEOUT
		brlo	wait_presc
		clear	LOCKtimeC

		rcall 	usart_nl

		ldi 	r16,'P'
		rcall	usartsend
		ldi 	r16,'L'
		rcall	usartsend
		ldi 	r16,'L'
		rcall	usartsend
		ldi 	r16,'!'
		rcall	usartsend
		rcall	lf_print
wait_presc:
ret2:
;-----------------------------------------------------------
#endif
updwAcion_inProgr:
ret

;===========================================================
; 		 *** rozpoznawanie stanu odbiornika ****
;===========================================================
;wykryte przeszukiwanie, ustaw nadajnik na f z wyprzedzeniem
upScan_Detected:
		rcall 	usart_nl
		ldi 	r16,'U'
		rcall	usartsend
		ldi 	r16,'P'
		rcall	usartsend
		ldi 	r16,'>'
		rcall	usartsend
		lds		r16,ScanActWaitC							;flagolicznik
		cpi		r16,0
		brne	updwAcion_inProgr

#ifdef OVER_BAND_RETU
;---
		loadw	r16,r17,freqRXLast							;pobierana odfiltrowana czestotliwosc zmierzona
		rcall 	freqMeasRaw_ToBIN							;r16 r17 zwraca wartosc wyliczona
		cpiw_	r16,r17,BAND_HIGH_MHZ+1+SCAN_F_SHIFT
		brlo	no_over_bandH
		rcall 	usart_nl
		ldi 	r16,'O'										;over band przeskok na dol -
		rcall	usartsend
		ldi 	r16,'B'
		rcall	usartsend
		ldi 	r16,'-'
		rcall	usartsend
		ldiwr16	BAND_LOW_MHZ+10								;przeskok na drugi koniec pasma (tak jak dziala skaner w odbiorniku) plus offset wynikly z tego ze w odbiorniku przestrajanie dziala szybciej niz w andajniku (niestety kompromis zwiazany z filtrem pll, trzeba by sprzetowo odpinac kondziora 470uF na czas fastlock pewnie da sie to zrobic)
		ldiwy	0x0000
		rjmp	tun_offs0
no_over_bandH:
#endif
;---
		LDIWY 	SCAN_F_SHIFT
		rjmp	tun_offs0
		;rcall	tune_offset
		;sti		ScanActWaitC,SCAN_REATEMPT					;czas na zatrzymanie skanowania	

dwScan_Detected:
		rcall 	usart_nl
		ldi 	r16,'D'
		rcall	usartsend
		ldi 	r16,'W'
		rcall	usartsend
		ldi 	r16,'>'
		rcall	usartsend	
		lds		r16,ScanActWaitC							;flagolicznik
		cpi		r16,0
		brne	updwAcion_inProgr
#ifdef OVER_BAND_RETU
;----
		loadw	r16,r17,freqRXLast							;pobierana odfiltrowana czestotliwosc zmierzona
		rcall 	freqMeasRaw_ToBIN							;r16 r17 zwraca wartosc wyliczona

		cpiw_	r16,r17,BAND_LOW_MHZ+SCAN_F_SHIFT
		brsh	no_over_bandL
		rcall 	usart_nl
		ldi 	r16,'O'
		rcall	usartsend
		ldi 	r16,'B'
		rcall	usartsend
		ldi 	r16,'+'
		rcall	usartsend
		ldiwr16	BAND_HIGH_MHZ-10
		ldiwy	0x0000
		rjmp	tun_offs0
no_over_bandL:
;----
#endif

		LDIWY 	-SCAN_F_SHIFT
tun_offs0:
		rcall	tune_offset
		sti		ScanActWaitC,SCAN_REATEMPT
ret

;f stabilna sprawdz czy poprawna jest ustawiona f nadajnika
;jesli nie to popraw
freqStabil_Detected:
		rcall 	usart_nl
		ldi 	r16,'F'
		rcall	usartsend
		ldi 	r16,'C'
		rcall	usartsend
		ldi 	r16,'>'
		rcall	usartsend
		LDIWY 	0x0000										;offset czestotliwosci zerowy jesli nie tryb skanowania tylko powolnej zmiany czestotliwosci
		rcall	tune_offset
ret

;-----------------------------------------------------------														
;jesli offset jest zerowy, to w przypadku przekroczonych granic 
;nie ustawia drugiego konca pasma
tune_offset:
		loadw	r16,r17,freqRXLast							;pobierana odfiltrowana czestotliwosc zmierzona
		rcall 	freqMeasRaw_ToBIN							;r16 r17 zwraca wartosc wyliczona
		rcall freqBinAddIM_freq								;dodanie posrednie jczetotliwosci
		
		add		r16,r28										;dodaj offset
		adc		r17,r29

		push 	r16
		push 	r17

		storew	LMXfreqMHz10,r16,r17
		rcall	LMX2306_TuneOnly							;uwtaw nadajnik
	
		pop 	r17
		pop 	r16
rjmp	display_freq_R16R17	

;-----------------------------------------------------------
;czestotliwosczmierzona poza zakresem
out_of_freq:
		cpi		r17,0
		breq	freqm_detached								;jesli niepodlaczony wogole czestosciomierz to wartosc zerowa pomiaru
		inc		R7											;zeby niezasypac konsoli 
		brne	freqm_detached
		ldi 	r16,'F'
		rcall	usartsend
		ldi 	r16,'R'
		rcall	usartsend
		ldi 	r16,'Q'
		rcall	usartsend
		ldi 	r16,'!'
		rcall	usartsend
		rcall	lf_print
		clr 	r16
		rcall	tx_powersetr16								;w razie bledu zmniejsz moc jesli byla duza
freqm_detached:
ret
;-----------------------------------------------------------
;---- analiza czestotliwosci i wysylka pomiaru na usart ----
noFreq_changes:
		incrs 	freqStabilC									;licznik stablinej czestotliwosci
ret
freqAnalise:		
		cbr 	SysFlags, 1<<MeasReady_f 

#ifdef FREQ_DBG
		rcall	dispFreq									;surowa czestotliwosc do dbg
		;rcall	freqStabil_Detected
#endif
;ret
#ifdef	MULMASTER
		lds		r16,MULmastTOtxinh
		cpi		r16,0
		brne	freqm_detached
#endif
		lds		r16,freqStabilC
		cpi		r16,STAB_FREQ								;czas stabilnej czestotliwosci
		brne	pc+2
		rcall	freqStabil_Detected

;- odczyt ostatnio zmierzonej czestotliwosci i antyjitter --
;trzeba wyeliminowac jitter pomiaru 2lsb (max20kHz zmiany)
;-----------------------------------------------------------
		loadW 	r16,r17,freqRX
;---- czy zmiezona czestotliwosc w zakresie ----------------
		cpi		r17,	BAND_HIG_FRAW+1	 					;tylko starsza czesc testowana (zgrubnesprawdzenie czy pomiar czestotliwosci jest poprawny)
		brsh	out_of_freq
		cpi		r17,	BAND_LOW_FRAW
		brlo	out_of_freq
;-----------------------------------------------------------
		loadW	r18,r19,freqRXLast

		cpw		r16,r17,r18,r19
		breq	noFreq_changes								;dwa ostatnie odczyty te same nie ma co zapisywac do bufora

;----------- jesli histereza niesymetryczna ----------------
#ifndef SYM_HYST
		brsh	only_MinTest
		brlo	only_PlusTest
#endif
;-----------------------------------------------------------		
		add		r16,one
		adc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2
		rjmp	noFreq_changes							
		add		r16,one
		adc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2
		rjmp	noFreq_changes	

		subi	r16,2
		sbc		r17,zero

only_MinTest:

		subi	r16,1
		sbc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2 
		rjmp	noFreq_changes								
		subi	r16,1
		sbc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2 
		rjmp	noFreq_changes											
		rjmp 	test_end
		

only_PlusTest:
		add		r16,one
		adc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2
		rjmp	noFreq_changes									
		add		r16,one
		adc		r17,zero
		cpw		r16,r17,r18,r19
		brne	pc+2
		rjmp	noFreq_changes	

test_end:
;****
;rcall	dispFreq
		clear	freqStabilC									;czas po jakim sygnalizacja stabilnej czestotliwosci
cli
		loadW 	r16,r17,freqRX
		storew 	freqRXLast,	r16,r17							;zapamietanie ostatniej zmierzonej wartosci czestotliwsoci
		sbr		SysFlags, 1<<MeasCancel_f					;nie brany pomiar pod uwage bo cli sei zaburza timing

sei																
;----zapis zmierzonej czestotliwosci do bufora kolowego-----

;	ldi r16,'W';
;	rcall	usartsend		

		ldiwz	FREQbuffer
		lds		r20,FREQpWR
		lsl 	r20
		add		r30,r20
		adc		r31,zero
		lsr 	r20
		st		z+,r16
		st		z,r17

		inc		r20											;postinkrementacja
		andi	r20,(FREQB_SIZE>>1)-1						;1/2 bufora ze wzgledu na lsl r20
		sts		FREQpWR,r20
;-----------------------------------------------------------
;--------- analiza probek rozpoznawanie zmian --------------
;-----------------------------------------------------------
;to nie dziala jak planowano
;		lds 	r16,freqStabilC
;		cpi		r16,8
;		brsh	toLow_freq									;skanowanie nie rozpatrywane bo zbyt powolne zmiany czestotliwosci

		sts		FREQpRD,r20									;tymczasowo wskaznik odczyt jak zapisu-1
		
		rcall	readFreq_DW									;ostatni pomiar n-0 LSB
		mov 	r4,r16
		mov 	r5,r17

		rcall	readFreq_DW									;pomiar n-1
		mov 	r6,r16
		mov 	r7,r17

		rcall	readFreq_DW									;pomiar n-2
		mov 	r8,r16
		mov 	r9,r17
	
		cpw		r4,r5,r6,r7									;sprawdzanie monotonicznosci 3 probek czestotliwosci
		breq	noUp_scan
		brlo	noUp_scan
		cpw		r6,r7,r8,r9
		breq	noUp_scan
		brlo	noUp_scan
		rcall	upScan_Detected
	;rjmp	noDw_scan
noUp_scan:

		cpw		r4,r5,r6,r7	
		brsh	noDw_scan
		cpw		r6,r7,r8,r9
		brsh	noDw_scan
		rcall	dwScan_Detected
noDw_scan:
	;ret
;odczyt 16b czestotliwosci z bufora kolowego
readFreq_DW:
		ldiwz	FREQbuffer
		lds		r20,FREQpRD			
		dec		r20											;predekrementacja
		andi	r20,(FREQB_SIZE>>1)-1						;maska bufora
		sts		FREQpRD,r20
					
		lsl		r20											;16b na wpis
		add		r30,r20
		adc		r31,zero
		lsr		r20		

		ld		r16,z										;lsb first
		add		r30,one						
		adc		r31,zero
		ld		r17,z
toLow_freq:
ret

												
;zerowanie 16b czestotliwosci z bufora kolowego
ZeroFreq_DW:
		ldiwz	FREQbuffer
		lds		r20,FREQpWR			
		dec		r20											;predekrementacja
		andi	r20,(FREQB_SIZE>>1)-1						;maska bufora
		sts		FREQpWR,r20
				
		lsl		r20											;16b na wpis
		add		r30,r20
		adc		r31,zero
		lsr		r20		

		st		z,zero										;lsb first
		add		r30,one						
		adc		r31,zero
		st		z,zero
ret

;dodanie czestotliwosci posredniej
freqBinAddIM_freq:
		ldiwx	FREQ_INTERM
		addw	r16,r17,r26,r27
ret
;-----------------------------------------------------------
;ze wzgledu na bramkowanie z czasem  15,625/360 wystarczy  
;przez wielo dwojke dla uzyskania 1000raw = 100.0MHz
;-----------------------------------------------------------
freqMeasRaw_ToBIN:
		lsr r17
		ror r16
		lsr r17
		ror r16
ret

powerdown_loop:
		cli
		in	 	r17, USR
		sbrs 	r17,UDRE
		rjmp 	powerdown_loop

		oti 	wdtcr,0b00011000							;wylaczanie wdt
		oti 	wdtcr,0b00010000

		out		portb,zero
		out		portd,zero
		out		ddrb,zero
		out		ddrd,zero
		oti		mcucr, 1<<SE|1<<SM							;power down mode
		sleep


;-----------------------------------------------------------

;substytut rozkazu mul - kodupozeracz ale za to szybki :)
mul_sbstR17R21:


;***************************************************************************
;*
;* "mpy8u" - 8x8 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two register variables mp8u and mc8u.
;* The result is placed in registers m8uH, m8uL
;*  
;* Number of words	:34 + return
;* Number of cycles	:34 + return
;* Low registers used	:None
;* High registers used  :3 (mc8u,mp8u/m8uL,m8uH)	
;*
;* Note: Result Low byte and the multiplier share the same register.
;* This causes the multiplier to be overwritten by the result.
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	mc8u	=r17	;multiplicand
.def	mp8u	=r21	;multiplier
.def	m8uL	=r21//R0;result Low byte
.def	m8uH	=r1		;result High byte

	push	mc8u
	push	mp8u
;***** Code

mpy8u:	
	clr	m8uH		;clear result High byte
	lsr	mp8u		;shift multiplier
	
	brcc	noad80		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad80:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad81		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad81:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad82		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad82:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad83		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad83:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad84		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad84:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad85		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad85:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc noad86		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad86:	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier

	brcc	noad87		;if carry set
	add	m8uH,mc8u	;    add multiplicand to result High byte
noad87:	
	ror	m8uH		;shift right result High byte 
	ror	m8uL		;rotate right result L byte and multiplier	

;****
	mov		r0,r21
	pop		mp8u
	pop		mc8u
ret
.exit

ramclearR19:
;-------------------ramclear--------------------------------
;kasuje od max pozycji-2 ram w dol (kasuje stos !)
		ldiw	r19,r20,(SRAM_START)
		ldi		r30,low(RAMEND-2)
		ldi		r31,high(RAMEND-2)
ramclearloop:
		st 		-z,r15
		cp	 	r30,r19										;pierwsze 16B niekasowane lub kasowane wszystko
		cpc		r31,r20										;pierwsza strona 256B zarezerowwana na rejestry
		brne 	ramclearloop
ret

/*
		push	r16
		bst	 	r16,7										;czesc calkowita MHz to przesuniete bajty o 7bit w prawo
		lsl 	r17
		bld 	r17,0
		mov		r16,r17

		ldi 	r18,10
		clr 	r24
		clr		r25
mul_loop:
		add 	r24,r17										;r24:R25 mnozone x10
		adc		r25,zero
		dec 	r18
		brne 	mul_loop

		;lds		r16,freqRXlast								;wyciagana bedzie czesc ulamkowa .100kHz
		pop		r16
		lsr		r16
		lsr 	r16
		lsr		r16
		andi	r16,0x0F
		ldiwz	kHz_part*2									;tablica z 16 wartosciami czesci ulamkowej format char 0-9
		add		r30,r16
		adc		r31,zero
		lpm		;do R0 zapisuje		
		mov		r16,r0										;niesamowite ze stare avr-y nie mialy nawet normalnej instrukcji LPM (z wyborem rejestru docelowego)
		subi 	r16,'0'										;konwersjachar na bin
		add 	r24,r16
		adc		r25,zero
															
		mov 	r16,r24
		mov 	r17,r25
ret
*/
