;===========================================================
;==================== Dream FM 2021  =======================
;===================== LMX2306.asm =========================
;===========================================================
/*
fvco = [(P x B) + A] x fosc/R
f vco : Output frequency of external voltage controlled oscillator (VCO)
B: Preset divide ratio of binary 13-bit programmable counter (3 to 8191)
A: Preset divide ratio of binary 5-bit swallow counter (0 = A = 31; A = B for LMX2316/26)
or (0 = A = 7, A = B for LMX2306)
f osc : Output frequency of the external reference frequency oscillator
R: Preset divide ratio of binary 14-bit programmable reference counter (3 to 16383)
P: Preset modulus of dual modulus prescaler
for the LMX2306; P = 8 for the LMX2316/26; P = 32
*/
/*
Sterowanie jest dosyc proste, przesyla sie 21 bitow przez microwire (jak spi TX only)
LSB 0	1 	2 	3 4 5 6 7 8 9 ... 19,20 MSB
	C1 	C2	Data ...

bity C1 C2 wybieraja przeznaczenie danych, a moga to byc 3 rejestry:
0 	14-bit R Counter
1 	18-bit N Counter
2 	18-bit Function Latch
3	init

 	C1 	C2
	0 	0 	R Counter
	1 	0 	N Counter
	0 	1 	Function Latch
	1 	1 	Initialization
szczegoly sa w DS
*/

#define		R_DIVIDER_DEF	40								;100kHz dla 4Mhz zegara 4MHz/ (40) =100kHz

#define 	LMX_R_CNT  		0
#define 	LMX_N_CNT  		1
#define 	LMX_FUNCT  		2
#define 	LMX_INIT 		3

;-----bity rejestru funkcyjnego----
#define 	LMX_CNT_RESET 	0
#define 	LMX_POWERDOWN 	1
#define 	LMX_FOLD_b0		2
#define 	LMX_PHA_POL		5
#define 	LMX_CP_TRI		6
#define 	LMX_FL_MD_b0	7
#define 	LMX_FL_TO_b0	10
#define 	LMX_TEST_b0		14
#define 	LMX_PD_MODE		17
#define 	LMX_TEST_MOD	18
;-----------------------------------------------------------

;------------ porty daca -----------------------
.EQU		DAC_port=		portb
.EQU		DAC_pin=		pinb
.EQU		DAC_ddr=		ddrb

.EQU		DAC_B2=			1		;bez rezystora
.EQU		DAC_B1=			4		;47k
.EQU		DAC_B0=			2		;680k

;===========================================================
;------------ porty lmxa i microwire -----------------------
.EQU		LMX_port=		portd
.EQU		LMX_pin=		pind
.EQU		LMX_ddr=		ddrd

.EQU		LMX_DAI=		4
.EQU		LMX_DAT=		4	;miso
.EQU		LMX_CLK=		5	;clk wspoldzielony z pomiarem freq
.EQU		LMX_LE=			3	;load enable act HI
.equ		LMX_FOLD = 		2	;FO/LD
.equ		RF_ENABLE =		6
;-----------------------------------------------------------


tx_powerset:
		lds		r16,TXpower
		;subi	r16,'0'
		andi	r16,0x03
		rcall	usartsend_hex

		cbi		DAC_port,DAC_B0;moc
		cbi		DAC_port,DAC_B1
		cbi		DAC_port,DAC_B2
		cbi		DAC_ddr,DAC_B0
		cbi		DAC_ddr,DAC_B1
		cbi		DAC_ddr,DAC_B2
		
		ldiwz	power0
		lsl		r16					;x4
		lsl		r16
		addw	r30,r31,r16,zero
		icall	
		rcall	ok_string
ret
power0:
		nops	1
		sbi		DAC_port,DAC_B0
		sbi		DAC_ddr,DAC_B0
		ret
power1:
		nops	1
		sbi		DAC_port,DAC_B1
		sbi		DAC_ddr,DAC_B1	
		ret
power2:
		nops	1
		cbi		DAC_port,DAC_B2
		sbi		DAC_ddr,DAC_B2
		ret
power3:
		nops	1
		sbi		DAC_port,DAC_B0;moc
		sbi		DAC_port,DAC_B1
		sbi		DAC_port,DAC_B2
		sbi		DAC_ddr,DAC_B0
		sbi		DAC_ddr,DAC_B1
		sbi		DAC_ddr,DAC_B2

		;sbi		DAC_port,DAC_B2
		;sbi		DAC_ddr,DAC_B2
		ret
;-----------------------------------------------------------

RFTX_enable:
		sbi		LMX_ddr,RF_ENABLE
		sbi		LMX_port,RF_ENABLE
		sbi		LMX_ddr,LMX_CLK
		sbi 	LMX_ddr,LMX_DAT
		sbi 	LMX_ddr,LMX_LE
ret
RFTX_disable:
		cbi		LMX_port,RF_ENABLE
ret
;===========================================================
;------------------ microwire 21bit TX ---------------------
;===========================================================
;dane ladowane spod Z, 21 bitow wysylane MSB first
.macro microwireTX21Z										;soft "spi" msb first
.equ	BASE_BIT = 	3										;poniewaz dane sa wyrownane do lsb dlatego z bajtu MSB tylko 5bit bedzie odczytane	
		push 	r16
		push 	r17
		adiw	z,2

;pierwszy bajt MSB wstepnietrzeba przesunac do rolowania 0 3bity (wysylka 5 bitow tylko)
		ld		r16, z
		lsl		r16
		lsl		r16
		lsl		r16
		ldi 	r17,3										;5b tyko z z MSB do wyslania
		rjmp	bit_TX

byte_LD:
		ld		r16,-z										;msb first
bit_TX:
		lsl 	r16					
		cbi 	LMX_port,LMX_CLK
		brcc 	datazero									;testuje carry / ustawia port 	
		sbi 	LMX_port,LMX_DAT					
		rjmp 	datajeden
datazero:
		cbi 	LMX_port,LMX_DAT
datajeden:													;probkowanie przed narastajacym zboczem zegara
		inc 	r17
		sbi 	LMX_port,LMX_CLK							;przesuwanie danych w LMX po narastajacym zboczu zegara

		cpi		r17,0x08
		breq	byte_LD

		cpi		r17,0x10
		breq	byte_LD

		cpi		r17,0x18									;wysylanie bitow do osiagnieca 21 bitu
		brlo 	bit_TX
		
		sbi		LMX_port,LMX_LE
		pop 	r17
		pop 	r16
		nops	10
		cbi		LMX_port,LMX_LE
.endm
;===========================================================


.cseg
;======== przygotowanie 3B danych do transmisji ============
LMX2306_loadData:
		ldiwz lmxDataBuf
		adiw	z,3	
	;	ld		r16,z+
	;	ld		r17,z+
	;	ld		r18,z+
		lsl		r16											;miejsce na CC
		rol		r17
		rol		r18
		lsl		r16											;miejsce na CC	
		rol		r17
		rol		r18
		or		r16,r19										;wstawienie bitow CC
		st		-z,r18
		st		-z,r17
		st		-z,r16										;gotowe dane wyjustowane do lsb
cli		
		sbr		SysFlags, 1<<MeasCancel_f					;pomiary nie beda updejtowane gdy transmisja uwire
		sbi		LMX_ddr,LMX_CLK								;poprawny kierunek
		microwireTX21Z										;Z wskaznik na dane do wyslania			
		cbi		LMX_ddr,LMX_CLK								;kierunek dla freqmeter
;		cbr		SysFlags, 1<<MeasCancel_f
sei
ret

; parametr R16-R18
LMX2306_Function:
		ldi		r19,LMX_FUNCT
		rcall	LMX2306_loadData
ret
;The N counter consists of the 5-bit swallow counter 
;(A counter) and the 13-bit programmable counter
;For the LMX2306 the maximum N value is 65535 
;and the minimum N value is 56
;ostatni 19bit to "gobit" 
;parametr R16,R17,R18
LMX2306_Ndivider:
		ldi		r19,LMX_N_CNT
		rcall	LMX2306_loadData
ret
;14b rozmiaru, na 19 bicie LD precision 
;pozostale testowe maja miec 0
; parametr R16,R17
LMX2306_Rdivider:
		ldi		r19,LMX_R_CNT
		rcall	LMX2306_loadData
ret


;===========================================================
;--- ustawienie wstepne rejestrow i parametrow syntezera ---
;===========================================================
LMX2306_Init:
		ldi		r16, 1<<LMX_PHA_POL|0x01<<LMX_FOLD_b0 		;polaryzacja dodatnia detekcji, digital lock detect na FO/LD
		ldi		r17, 0x0F<<(LMX_FL_TO_b0-8) | 0x0F<LMX_FL_MD_b0
		ldi		r18, 0<<(LMX_PD_MODE-16)|0<<(LMX_TEST_MOD-16)
		rcall 	LMX2306_Function
		ldiw 	r16,r17,R_DIVIDER_DEF
		rcall	LMX2306_Rdivider	
		rcall	LMX2306_TuneOnly
ret

;===========================================================
;---- ustawienie czestotliwosci zgodnie z LMXfreqMHz10 -----
;===========================================================
LMX2306_TuneOnly:
;uzywany jest swallow counter co umozliwia prace komparatora na 100kHz
		loadw	r16,r17,LMXfreqMHz10						;zadana czestotliwosc 100kHz na lsb
		lds		r18,LMXfreqMHz10+2
		ldi		r20,2
shift_loop:
		lsl		r16
		rol		r17
		rol		r18
		dec		r20
		brne 	shift_loop
		andi	r16,0b11100000

		lds		r20,LMXfreqMHz10
		andi	r20,0x1F									;swallow counter 5b lsb na zero
		or		r16,r20

		rcall	LMX2306_Ndivider
ret
;===========================================================
