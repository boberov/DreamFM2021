;Uwaga tryb SPI, dla niskich predkosci wszystkie karty dzialaja wtrybie 3
;dla wysokich niektore musza miec koniecznie tryb 0! (SDHC 8GB class4 to bez roznicy)

.dseg
;.org 128

.exit
;--------------------------------------------------------------------------
.CSEG

init:
		ldi r16,low(RAMEND)				;stos 
		out SPL,r16
		ldi r16,high(RAMEND)
		out SPH,r16


;-------------------------------------------------------------------------
;-----------------timer1 config cahnnel L output----------------------------------------------------------------
		ldi r16,0B10100001	;COM1A1 COM1A0 COM1B1 COM1B0 FOC1A FOC1B WGM11 WGM10 
		out Tccr1a,r16 		;clear on compare match, fast pwm 8bit 
		ldi r16,0B00001001 	;CNC1 ICES1 – WGM13 WGM12 CS12 CS11 CS10
		out Tccr1b,r16 
;-----------------timer0 config CH R msb----------------------------------------
		ldi r16,0B01101001			;FOC0 WGM00 COM01 COM00 WGM01 CS02 CS01 CS00
		out Tccr0,r16				;fast pwm clear on compare match
;-----------------timer2 config CH R lsb----------------------------------------
		ldi r16,0B01101001			;FOC2 WGM20 COM21 COM20 WGM21 CS22 CS21 CS20 
		out Tccr2,r16				;fast pwm clear on compare match
;-----------------------------usart config---------------------------



rjmp fastpwm
;-----------------timer1 config cahnnel L output----------------------------------------------------------------
;PWM/2	-	Phase correct
		ldi r16,0B10100001	;COM1A1 COM1A0 COM1B1 COM1B0 FOC1A FOC1B WGM11 WGM10 
		out Tccr1a,r16 		;clear on compare match, fast pwm 8bit 
		ldi r16,0B00000001 	;CNC1 ICES1 – WGM13 WGM12 CS12 CS11 CS10
		out Tccr1b,r16 
;-----------------timer0 config CH R msb----------------------------------------
		ldi r16,0B01100001			;FOC0 WGM00 COM01 COM00 WGM01 CS02 CS01 CS00
		out Tccr0,r16				;fast pwm clear on compare match
;-----------------timer2 config CH R lsb----------------------------------------
		ldi r16,0B01100001			;FOC2 WGM20 COM21 COM20 WGM21 CS22 CS21 CS20 
		out Tccr2,r16				;fast pwm clear on compare match
;-----------------------------usart config---------------------------
fastpwm:


;35MHz=19 dla 115.2kb

;25MHz=38 dla 38.4
;16MHz=12 dla 38.4kb
;----------------------USART config for debug----------------------------
		ldi  r16,0B00000000		;UBRR11:8: USART Baud Rate Register (4MSbit)
		out  UBRRh,r16
		ldi  r16,38 			;31dec UBRR7:0  USART Baud Rate Register (8LSbit)
		out  UBRRl,r16
		ldi  r16,0B00000000		;
		out  UcsRa,r16			;RXC TXC UDRE FE DOR PE U2X MPCM
		ldi  r16,0B00011000		;
		out  UcsRb,r16			;RXCIE TXCIE UDRIE RXEN TXEN UCSZ2 RXB8 TXB8
		ldi  r16,0B10000110
		out  UcsRc,r16			;URSEL UMSEL UPM1 UPM0 USBS UCSZ1 UCSZ0 UCPOL


;-----------------------------port ddr----------------------------
		ldi R16,0b10111000
		out ddrd,r16
		ldi R16,0b11110100
		out portd,r16

		ldi R16,0b00000000			
		out ddrc,r16
		ldi R16,0b11111000
		out portc,r16

		ldi R16,0b00000001			;porta 
		out ddra,r16
		ldi R16,0b00000001
		out porta,r16
;-----------------------------------------------------------------
		ldi R16,0b10111111			;.2=CS .5 DI .6 DO .7 sck .3ocrout
		out ddrb,r16				;.1=dac WS
		ldi R16,0b11010110
		out portb,r16
		;ldi r16,255
		;out osccal,r16

start:
ldi r16,'!'
rcall usartsendch
;rcall spimasterinit


;-----------------SD power on---------------------------
;After supply voltage reached 2.2 volts, wait for a millisecond at least. 
;Set SPI clock rate between 100kHz and 400kHz. Set DI and CS high 
;and apply 74 or more clock pulses to SCLK. The card will enter its
;native operating mode and go ready to accept native commands.
;Voltage of power ramp up should be monotonic as much as possible. 
;The minimum ramp up time should be 0.1ms. 
;The maximum ramp up time should be 35ms for 2.7-3.6V power supply. 
rcall spi_off
;		rcall spimasterinit_lowspeed
		;cbi sd_ddr,SD_vcc
		sbi sd_port,SD_VCC		;apply power to sd card
		ldi r17,200				; dla niektorych kart jest to zbyteczne
		rcall delayr			;niektorych niezbedne
		;ldi r17,200			;wg specyfikacji "supply ramp" jest konieczny
		;rcall delayr
		;ldi r17,200			
		;rcall delayr
;-------------------startowanie karty - zegar w trybie low speed-----------
;-------------------oraz przelaczanie w tryb spi---------------------------
		sbi sd_port,SD_CS		;CS HI
		ldi r17,10				;10x8=80clk to CLK
		ser r16
		sdinitloop:
		;rcall spibyter16		;send via spi 1 byte (8clk)
		spibyter16

		dec r17
		brne sdinitloop

ldi r16,'@'
rcall usartsendch
;rcall spimasterinit_lowspeed
;--------------SD soft reset-----------------------------
		;Send a CMD0 with CS low to reset the card. 
lol:
		cbi sd_port,SD_CS		;CS L
		clr r16
		;sts sdcmd+5,r16
		sts sdcmd+4,r16
		sts sdcmd+3,r16
		sts sdcmd+2,r16
		sts sdcmd+1,r16
		ldi r16,0b01000000
		sts sdcmd+5,r16			;command zapisz do bajtu MSB cmd0
		ldi r16,0x95
		sts sdcmd+0,r16			;bez waznego crc karta nie zareaguje na rozkaz 
		rcall sdsend			;najpierw CMD00
		rcall sdrec				;tutaj 8bitow niewaznych
		rcall sdrec				;tutaj r16 zwraca 1 jesli prawidlowa reakcja karty
		rcall usartsend
		rcall sdrec				;totaj niedokumentowane 8 bitow dodatkowe
								;bez nich niektore karty nie zwracaja danych prawidlowo
;rjmp lol
;=============Try first SD V2 initialisation flow=====================
;---------------------CMD8 +CRC +4B trailer-------------------------------
;Receipt of CMD8 makes the cards realize that the host supports the Physical Layer Version 2.00 or 
;later and the card can enable new functions. 


		ldi r16,0b01001000
		sts sdcmd+5,r16			;command zapisz do bajtu 5 CMD8

		ldi r16,0x01			;check pattern
		sts sdcmd+2,r16			;zapisz do bajtu 2 0X01
		ldi r16,0xAA			;check pattern
		sts sdcmd+1,r16			;zapisz do bajtu 1 0XAA
		ldi r16,0x87
		sts sdcmd+0,r16			;crc
		rcall sdsend			;wysyla rozkaz
		rcall sdrec
		rcall sdrec
		rcall usartsend			

		rcall sdrec

		rcall usartsend			;jesli karta rozpoznaje cmd8
		rcall sdrec				;to zwroci tutaj 4 wyslane bajty
		rcall usartsend			;000001AA
		rcall sdrec
		rcall usartsend
		rcall sdrec
		rcall usartsend
		rcall sdrec

;---wszystkie karty zwracaja 5 na cmd 8 jesli nie bylo dodatkowych 8 bitow zegara po R1------------

		ldi r16,'*'
		rcall usartsendch
;		rjmp pc
;rjmp SDV1FLOW
;Wartosc bloku we wszystkich kartach ma domyslna wartosc 512B, nie bedzie zmieniane
;-----------------------------ACMD41---------------------------------------
;S
;1 7 8 1 1 1 1 6 1 1
;1 xxxxxxx 0000000 x 0 x 0 101001 1 0
;00 07-01 15-08 36 37 38 39 45-40 46 47
;3
;000
;Reserved
;27-25
;35-33
;1
;x
;S18R
;24
;32
;16
;xxxxh
;OCR 
;23-08
;31-16
;E CRC7 Reserved
;07-00
;XPC
;28
;(FB)
;29
;HCS
;30
;Busy
;31
;Index D S
;1 7 8 1 1 1 1 6 1 1
;1 xxxxxxx 0000000 x 0 x 0 101001 1 0
;;00 07-01 15-08 36 37 38 39 45-40 46 47
;Host Capacity Support
;0b: SDSC Only Host
;1b: SDHC or SDXC Supported
;S18R : Switching to 1.8V Request
;0b: Use current signal voltage
;1b: Switch to 1.8V signal voltage
;SDXC Power Control
;0b: Power Saving
;1b: Maximum Performance
acmd41:
		ldi r16,0b01110111		;Wejscie w tryb ACMD przez CMD55
		sts sdcmd+5,r16			;command zapisz do bajtu 5 cmd55
		sts sdcmd+4,r16
		sts sdcmd+3,r16
		sts sdcmd+2,r16
		sts sdcmd+1,r16
		sts sdcmd+0,r16

		rcall sdsend			;6 bajtow wysyla
		rcall sdrec				;3 bajty odbiera (nieistotne)
		rcall sdrec
		rcall sdrec
;--------------------------------------------------------------------------
		ldi r16,0b01101001
		sts sdcmd+5,r16			;command zapisz do bajtu 5 ACMD41

		ldi r16,0b01000000		;HCS bit30  (jesli nie ustawiony - host nie zglasza obslugi SDHC)
		sts sdcmd+4,r16			

		rcall sdsend			;wysyla 6 bajtow command
		rcall sdrec				;niewazne 8 bitow
		rcall sdrec				;8 bitow odpowiedzi
		push r16
		cpi r16,2				;jesli na acmd41 zwrocone >1 karta nie rozpoznaje lub zglasza blad
		brlo SDv2ok				;trzeba probowac inicjalizacji karty przez CMD01
		rjmp SDV1FLOW
SDV2ok:							;nie oznacza to ze karta jest V2,
;sundisk 64MB inicjalizuje sie przez ACMD41, nie odpowiada na CMD8 (r1 resp=05) ani CMD10 
;inicjalizuje sie rowniez poprawnie przez cmd01 =SD V1
		rcall usartsend

		rcall sdrec				;nie wazne 8bitow zegara
		pop r16
		cpi r16,0
		brne acmd41
;rjmp acmd41
;-----------jezeli jest ustawiony bit HCS, to zwracane jest 0 po czasie
;Jesli HCS=0 a karta SDHC, to karta nie wyjdzie z idle-zwracane 1

ldi r16,'&'
rcall usartsendch

;---------------------CMD58 4byte R3 response-------------------------------
;Spardzenie CCS - cy karta SDHC czy SDXC

		ldi r16,0b01111010
		sts sdcmd+5,r16			;command zapisz do bajtu 5 CMD58
		ldi r16,255	
		sts sdcmd+4,r16	
		sts sdcmd+3,r16	
		sts sdcmd+2,r16			
		sts sdcmd+1,r16			
		sts sdcmd+0,r16			;crc
		rcall sdsend
		rcall sdrec
		rcall sdrec
		rcall usartsend			;zwraca zero
								;4 bajty R3 response c0ff80
		rcall sdrec				;zwraca 80 lub C0 dla HC (bit30)
		sbrs r16,6
		rjmp SDXC				;Rozpoznano SDXC
		;rozpoznano SDHC
push r16
ldi r16,'='
rcall usartsendch
ldi r16,'H'
rcall usartsendch
ldi r16,'C'
rcall usartsendch
ldi r16,' '
rcall usartsendch
pop r16
SDXC:
		rcall usartsend			;return OCR (napiecie i typ adreswoania karty blokowy bajtowy)
		rcall sdrec				;
		rcall usartsend			;Zwraca FF
		rcall sdrec				
		rcall usartsend			;Zwraca 80
		rcall sdrec				
		rcall usartsend			;Zwraca 00
		rcall sdrec	
		;rcall sdrec			
;rjmp pc

ldi r16,'%'
rcall usartsendch
;sbi sd_port,SD_CS
ldi r17,200
rcall delayr
cbi sd_port,SD_CS
rjmp SDV1FLOW_end

SDV1FLOW:						;jesli inicjalizacja dla V2 zawiedzie testuj na cmd1
		ldi r16,'V'
		rcall usartsendch
		ldi r16,'1'
		rcall usartsendch
		ldi r16,' '
		rcall usartsendch
		ldi r16,0b01000001
		sts sdcmd+5,r16			;command zapisz do bajtu 5 cmd1
		sts sdcmd+4,r16	
		sts sdcmd+3,r16	
		sts sdcmd+2,r16			
		sts sdcmd+1,r16			
		sts sdcmd+0,r16			;crc
	
		rcall sdsend			;wysyla 6 bajtow command
		rcall sdrec				;niewazne 8 bitow
		rcall sdrec				;8 bitow odpowiedzi
		push r16
		rcall usartsend

		rcall sdrec				;nie wazne 8bitow zegara
		pop r16
		cpi r16,0
		brne SDV1FLOW

SDV1FLOW_end:


;---------------------CMD10 4byte R1 response-------------------------------
;Unlike the SD Memory Card protocol (where the register contents is sent as a command response), 
;reading the contents of the CSD and CID registers in SPI mode is a simple read-block transaction. The 
;card will respond with a standard response token (see Figure 7-3) followed by a data block of 16 bytes 
;suffixed with a 16-bit CRC. 
; przykladowo co karta zwraca
; 00 R1 response (nie zawesze 0 czasem FF)
; fe Start of singel block read 
; 02 Manufacturer ID (MID) 
; 54 4d (ASCII)OEM/Application ID (OID) 
; 53 44 32 35 36 = "SD256" Product Name (PNM) 
; 07 Product Revision (PRV) 
; 73 e1 f7 2b Serial Number (PSN) 
; 0 Reserved 
; 0 4b (2004 November???)Manufacture Date Code (MDT) 
; df upper 7 bits CRC7 checksum (CRC) bit 0 Not used, always â€~1â€™ 
; fb 9c CRC16

		ldi r16,0b01001010
		sts sdcmd+5,r16			;command zapisz do bajtu 5 CMD10
		ldi r16,255	
		sts sdcmd+4,r16
		sts sdcmd+3,r16			
		sts sdcmd+2,r16			
		sts sdcmd+1,r16			
		sts sdcmd+0,r16			;crc
		rcall sdsend
		rcall sdrec
		rcall sdrec
		rcall usartsend			;R1 response dla SPI ? dla roznych kart rozna odpowiedz
		rcall sdrec
		;Dla roznych kart rozna ilosc cykli po jakich zwracany CID
		;najlepiej testowac zwrocony bajt na zanik FF lub oczekiwac FE
	;	rcall sdrec
		ldi r19,255				;countout
czekajnabrakFF:
		rcall sdrec
		cpi r16,255
		brne waznybajt0
		dec r19
		brne czekajnabrakFF
waznybajt0:
		ldi r19,18				;18 bajtow do odczytu
		;rcall usartsend		;FE nas nie interesuje
czytajcid:						;Cid ma 18bajtow 128 bit +16bit crc 
		rcall sdrec				;
		rcall usartsend			;
		dec r19
brne czytajcid
		rcall sdrec				;koniecznie dodatkowe niewazne 8clk
		;rcall usartsend			;

;rjmp pc
;-------------------------------------------------------------------------

ldi r16,'+'
rcall usartsendch
ldi r16,' '
rcall usartsendch
ldi r16,'+'
rcall usartsendch
rcall spimasterinit_hispeed

rjmp ile								;nie jest konieczne cmd25 do odczytywania kolejnych blokow
;---------------------CMD25 4byte R1 response-------------------------------
		ldi r16,0b01010111
		sts sdcmd+5,r16					;ile blokow do odczytania dla cmd17
		ldi r16,0
		sts sdcmd+4,r16	
		sts sdcmd+3,r16	
		sts sdcmd+2,r16			
	
		sts sdcmd+1,r16			
		ldi r16,0
		sts sdcmd+0,r16
		rcall sdsend
		rcall sdrec
		rcall sdrec
		rcall usartsend					;zwrocilo 0X60 lub x20 ?
		rcall sdrec						;4 bajty R3 response
ile:

;rcall spimasterinit_hispeed				;przelacz na szybszy transfer
;sbi SD_port,SD_CS
nop
nop
nop
	
;cbi SD_port,SD_CS	
;rjmp pc
;-----------------------CMD17 multi Block Read----------------------------------
.equ	sector=280;280
		ldi r16,0b01010010
		sts sdcmd+5,r16			;command zapisz do bajtu 5 CMD17
		ldi r16,0
		ldi r17,47;47
		sts sdcmd+4,r17
		ldi r17,high(sector*2)	;
		sts sdcmd+3,r17
		ldi r17,low(sector*2)	;64 sektor
		sts sdcmd+2,r17
		sts sdcmd+1,r16			;numer bajtu zawsze 0
		sts sdcmd+0,r16			;crc
rjmp sd11					;jesli nie sdhc przeskocz

;---------------adresowanie dla karty SDHC (blokowe nie bajtowe)
.equ	sectorHC=0x0076b0;
		ldi r16,0
		ldi r17,0x17;00;76
		sts sdcmd+3,r17
		ldi r17,0x76
		sts sdcmd+2,r17
		ldi r17,0xb0
		sts sdcmd+1,r17
		sts sdcmd+4,r16			;
		sts sdcmd+0,r16			;crc

sd11:
		rcall sdsend

;Uwaga karta SDHC po CMD17 potrzebuje duuzo czasu
;na odpowiedz FE, dlatego pierwsza petla oczekujaca jest z
;dodatkowym opoznieniem (chocby rcall usart)
;(rowniez R1 response jest opoznione po zaadresowaniu -odczytywane w ponizszej petli i pomijane)
;normalna petla jak w programie odtwarzajacym jest tutaj zbyt krotka		



;--------------------------------------------------
czekajFE_0:
		ldi r19,250				;countout
czekajnaFE_0:
		rcall sdrec
		cpi r16,0xFE			;FE=Data TOKEN cmd17 cmd18 cmd24
		breq waznybajt			
		rcall usartsend
		dec r19
		brne czekajnaFE_0
		rjmp countout
;--------------------------------------------------
czekajFE:
		ldi r19,250				;countout
czekajnaFE:
		rcall sdrec
		cpi r16,0xFE			;FE=Data TOKEN cmd17 cmd18 cmd24
		breq waznybajt			
		
	;	rcall usartsend
		dec r19
		brne czekajnaFE
		rjmp countout			;blad przekroczenia "czasu" oczekiwania na datatoken FE
								;rowniez w przypadku odczytania ostatniego fizycznego bloku danych
waznybajt:
		clr	r19					;zeruj licznik nr probki (L P)

;uwaga ! w kazdym odczytanym pakiecie dodatkowe 3 bajty do pobrania
;na starcie data token FE, na koncu 16bit crc

		ldi r25,0				;zeruj licznik bajtow bloku
		rjmp niecrc ;odrazu odczyt bloku (data token odczytany)
czytaj:		
;		cbi SD_port,SD_CS		;sd spi SELECT

		inc r19
		inc r25					;licznik bajtu
		cpi r25,0				;po 512Bajtach odbierz Crc
		brne niecrc
;po odebranych 512 bajtach danych nastepuje crc ora czekanie na FE
;czekajFE:
		rcall sdrec				;dwa bajty CRC na koncu pakietu
		rcall sdrec
;		ldi r16,' '
;		rcall usartsendch
;		ldi r16,'-'
;		rcall usartsendch
;		ldi r16,' '
;		rcall usartsendch
		rjmp czekajFE			;czekaj na kolejny pakiet /blok danych
niecrc:
;.macro SDRX						;wysyla 255 i odbiera bajt z spi
;		ser r16					;przy odczycie wysylaj tylko jedynki
;		out spdr,r16
;Wait_Trans:						; Wait for transmission complete
;		sbis spsr,7
;		rjmp Wait_Trans
;		in r16,spdr
;.endm

	;	rcall sdrec				;Najlpierw LSB w pliku wave (litle endian)
		sdRx					;macro zeby nie marnowac czasu na rcall
;	rcall sdrec
		mov r17,r16
;	rcall sdrec
		sdRx

;--------------convert data sample & set pwm-----------------------
		subi r16,128				;Dodaj do MSB probki 128

		cpi r19,1					;jesli pierwsze dwa bajty 
		brne nie1					;kopiuj tylko do innych rejetrow
		movw r20,r16
		rjmp czytaj
nie1:
;sbi SD_port,SD_CS					;deselect SD


		out ocr1al,r16;R20			;MSB L
  		out ocr1bl,r17;R19			;LSB L
		out ocr2,R20				;MSB R
		out ocr0,R21				;LSB R
		clr r19
;sdrx;8bit po cs hi
;sdrx

.macro DACTX 					;wysyla 255 i odbiera bajt z spi				;przy odczycie wysylaj tylko jedynki
		out spdr,@0
Wait_Trans:						; Wait for transmission complete
		sbis spsr,7
		rjmp Wait_Trans
.endm
;--------------------------DAC send-----------------------------

;rjmp klk
;cbi DAC_PORT,DAC_WS				;DAC "SELECT"
;DACTX r16		;MSBL
;DACTX r17
;DACTX R20
;DACTX R21		;LSBR
;sbi DAC_PORT,DAC_WS
klk:
;---delay-----
;opoznienie zmienne w zaleznosci od taktowania procesora dla SR wave 44100kHz
									;240 dla 35MHz
		ldi r20,150					;150 dla 25MHz 
									;50		 12MHz
delay:								;15	 	 8MHz
		dec r20
		brne delay
		;-------------
		rjmp czytaj					;petla odtwarzania wave

countout:							;ERROR
		ldi r16,'E'
		rcall usartsendch
		ldi r16,'R'
		rcall usartsendch
		ldi r16,'R'
		rcall usartsendch
rjmp pc


;-----------------------------END-----------------------------------------
SDsend:
		ldi r18,6
		ldi r30,low(sdcmd+6)
		ldi r31,high(sdcmd+6)		;zaladowanie do Z adresu ram sdcmd
first6B:
		ld r16,-z
;		out spdr,r16
;Wait_Transm:						; Wait for transmission complete
;		sbis spsr,7
;		rjmp Wait_Transm


spibyter16



		dec r18
		brne first6b
ret
sdrec:								;tosamo co sdrx
		ser r16						;przy odczycie wysylaj tylko jedynki
;		out spdr,r16
;Wait_Trans:							; Wait for transmission complete
;		sbis spsr,7
;		rjmp Wait_Trans
;		in r16,spdr

spibyter16


ret
spimasterinit_hispeed:				;SPI initialisation MODE 0!
		ldi r16, 0b00000001			;SPIF WCOL – – – – – SPI2X  4MHz= 1/2Mclk
		out spsr,r16
		ldi r16, 0b01010000			;SPIE SPE DORD MSTR CPOL CPHA SPR1 SPR0
		out spcr,r16				;SPI MODE0
ret
spimasterinit_lowspeed:				;SPI initialisation MODE 3! clk/128speed
		ldi r16, 0b00000000			;SPIF WCOL – – – – – SPI2X  
		out spsr,r16
		ldi r16, 0b01011110			;SPIE SPE DORD MSTR CPOL CPHA SPR1 SPR0
		out spcr,r16				;cpol cpha 00 mode 0 11 SPI mode3
ret

;spibyter16:						;sending R16 by spi HW spi
;		out spdr,r16
;Wait_Transmit:						; Wait for transmission complete
;		sbis spsr,7
;		rjmp Wait_Transmit
;ret









spi_off:
		ldi r17,(0<<SPE)|(0<<MSTR)|(0<<SPR0)		;spi disable
		out SPCR,r17
ret

delayr:				;delay routine
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		dec r16
		brne delayr
		dec r17
		brne delayr
ret



;-----------------------tylko do debug----------------------------------
.macro usart_bcd_LSD
		mov r17,@0
		andi r17,0b00001111
		cpi r17,10					;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		out udr,r17
		rcall USARTbusy
.endm
.macro usart_bcd_MSD
		mov r17,@0
		andi r17,0b11110000
		swap r17
		cpi r17,10					;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		out udr,r17
		rcall USARTbusy
.endm

usartsend:
;ldi r16,32
		usart_bcd_MSD r16
		usart_bcd_LSD r16
		ldi r16,'_'
usartsendch:
		out udr,r16
USARTbusy:
		; Wait for empty transmit buffer
		sbis UCSRA,UDRE
		rjmp USARTbusy
ret


