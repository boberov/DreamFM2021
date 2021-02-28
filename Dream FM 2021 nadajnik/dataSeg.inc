;=======================================
;========== Dream FM 2021  =============
;=========== dataSeg.inc ===============
;=======================================
.equ	RXB_SIZE = 		16				;bufor odbiodnika RX
.equ	FREQB_SIZE = 	16				;bufor pomiarow czestotliwosci	
.equ	PARAM_SIZE=		8

.dseg
;-------------dbg-----------------------
.org SRAM_START				
;-------------- system -----------------
ScanDetectC:	.Byte		1			;licznik miernika predkosci skanowania
freqStabilC:	.Byte		1			;licznik czasu niezmiennej czetotliwosci	
ScanActWaitC:	.byte		1			;licznik czasu pomiedzy ustawianiami czestotliwosci (z offsetem) gdy wykryty tryb scan

;------------ usart TRX ----------------
URXtoutC:		.BYte		1			;licznik timeout do sprawnego dekodowania esc codes
URXpWR:			.Byte		1			;wskaznik bufora zapisu
URXpRD:			.Byte		1			;wskaznik bufora odczytu
URXbuffer:		.Byte		RXB_SIZE	;bufor usart
URXparam:		.Byte		PARAM_SIZE	;obszar na odczyt parametru rozkazu
TMPdata:		.Byte		8			;bufor tymczasowy
MULmastTOtxoff: .Byte		1			;timeout odlaczenia nadajnika od linii
MULmastTOtxinh: .Byte		1			;czas po odebraniu czegos RX w jakim nie mozna nadawac chyba ze poprawnie odebrany rozkaz
;------------ freq meter ---------------
FREQpWR:		.Byte		1			;wskaznik zapisu
FREQpRD:		.Byte		1			;wskaznik odczytu
FREQbuffer:		.Byte		FREQB_SIZE	;bufor pomiarow
;-------------- LMX --------------------
lmxDataBuf:		.byte		4			;przesylane bajtow do procedury wsysylki microwire
lmxStatusreg:	.byte		1
freqRXub:		.byte		2			;16b niezbuforowana czestotliwosc z przerwania pomiarowego
freqRX:			.Byte		2			;16b zmierzona aktualna czestotliwosc
freqRXLast:		.Byte		2			;16b zmierzona odfiltrowana (jitter i te sprawy)
LMXfreqMHz10:	.Byte		2			;czestotliwosc MHz/10	
LOCKtimeC:		.Byte		1			;licznik do rozpoznawania problemu z lock petli pll
TXpower:		.Byte		1			;domyslna moc
;----------- string usart --------------
FREQstring:		.Byte	 	4
