;===========================================================
;===================== Icebox 2020 =========================
;====================== macro.inc ==========================
;===========================================================
.macro usartstring

		ldi r30,low(@0*2)
		ldi r31,high(@0*2)
		call usartstrin
	
.endm

.macro usartstringDBG

		ldi r30,low(@0*2)
		ldi r31,high(@0*2)
		call usartstring_DBG
	
.endm


.macro usartstring0safe
		push r16
		push r30
		push r31
		ldi r30,low(@0*2)
		ldi r31,high(@0*2)
		rcall usartstrin
		pop r31
		pop r30	
		pop r16	
.endm
;-----------------------usart debug-----------------------------------------
.macro usart_bcd_LSD
		mov r17,@0
		andi r17,0b00001111
		cpi r17,10						;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		mov r16,r17
		rcall usartsend
.endm
.macro usart_bcd_MSD
		mov r17,@0
		andi r17,0b11110000
		swap r17
		cpi r17,10						;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r17,256-7
disp_bcd0:
		subi r17,256-48
		mov r16,r17
		rcall usartsend
.endm


;--------------------------------debug tools---------------------------------------------
.equ markportnr=1
.equ markddr=ddrd
.equ markport=portd
.macro mark_H
		sbi markport,markportnr
		sbi markddr,markportnr
.endm
.macro mark_L
		Cbi markport,markportnr 
		Cbi markddr,markportnr
.endm
.macro mark
		sbi markddr,markportnr
		sbi markport,markportnr 
		cbi markport,markportnr 
.endm

.macro dbg 
		push r16

				in r16,sreg

		push r16

	.if @0>0x3F
		lds	r16,@0
	.elif @0>0x1F
		in	r16,@0
	.else
		mov r16,@0
	.endif
		rcall usartsend_hex
			pop r16

		out sreg,r16

		pop r16
.endm
.macro dbgr 
		push r16
		in r16,sreg

		push r16
		mov r16,@0
		rcall usartsend_hex
		pop r16

		out sreg,r16
		pop r16
.endm

.macro dbgA 
		push r16
		in r16,sreg

		push r16
		ldi r16,@0
		rcall usartsend
		pop r16

		out sreg,r16
		pop r16
.endm


.macro nops ;1-16
	.if @0>1
		nop
		nops @0-1
	.elif @0==1
		nop
	.endif
.endm 


;---------------------------------------------------------------------------------------

.MACRO XCH0									;exchange rs->rd  rd->rs
		eor @0, @1
		eor @1, @0
		eor @0, @1
.ENDM 
;*********************************************************
;*	BIT access anywhere in IO or SRAM
;*	SETB - SET Bit in IO of data space
;*	CLRB - CLeaR Bit in IO of data space
;*********************************************************

.MACRO SETB 		;Arguments: Address, Bit, Register
	.if @1>7
		.message "Only values 0-7 allowed for Bit parameter"
	.endif
	.if @0>0x3F
		lds	@2, @0
		sbr	@2, (1<<@1)
		sts	@0, @2
	.elif @0>0x1F
		in	@2, @0
		sbr	@2, (1<<@1)
		out	@0, @2
	.else
		sbi	@0, @1
	.endif
.ENDMACRO

.MACRO CLRB 		;Arguments: Address, Bit, Register
	.if @1>7
		.message "Only values 0-7 allowed for Bit parameter"
	.endif
	.if @0>0x3F
		lds	@2, @0
		cbr	@2, (1<<@1)
		sts	@0, @2
	.elif @0>0x1F
		in	@2, @0
		cbr	@2, (1<<@1)
		out	@0, @2
	.else
		cbi	@0, @1
	.endif
.ENDMACRO
;-----------------------------------------------------------------------------------

.macro oti;2mck									;polaczene ldi oraz out
		ldi r16,@1
		out @0,r16
.endm

.macro sti;3mck
		ldi r16, @1
		sts @0,r16
.endm

.macro stiw
		ldi r16, high(@1)
		sts @0+1,r16
		ldi r16, low(@1)
		sts @0+0,r16
		
.endm

.macro sbri										;sbr dla niskich rejestrow 
		mov r16, @0
		sbr r16,@1
		mov @0,r16
.endm
.macro cbri										;cbr dla niskich rejestrow 
		mov r16, @0
		cbr r16,@1
		mov @0,r16
.endm

.macro eventlog
		ldi r16, @0
		rcall writeevent
.endm
.macro STOP
		a:
		wdr
		rjmp a
.endm

.macro LDIWr16
		LDI r16,low(@0)
		LDI r17,high(@0)
.endm
.macro LDIWr18
		LDI r18,low(@0)
		LDI r19,high(@0)
.endm

.macro LDIWX
		LDI r26,low(@0)
		LDI r27,high(@0)
.endm

.macro LDIWY
		LDI r28,low(@0)
		LDI r29,high(@0)
.endm
.macro LDIWZ
		LDI r30,low(@0)
		LDI r31,high(@0)
.endm
.macro LDIW
		LDI @0,low(@2)
		LDI @1 ,high(@2)
.endm


.macro load4R16
		LDS R16,@0+0
		LDS R17,@0+1
		LDS R18,@0+2
		LDS R19,@0+3
.endm

.macro store4R16
		sts @0+0,r16
		sts @0+1,r17
		sts @0+2,r18
		sts @0+3,r19
.endm



.macro loadWR16
		LDS R16,@0+0
		LDS R17,@0+1
.endm
.macro loadWR18
		LDS R18,@0+0
		LDS R19,@0+1
.endm
.macro loadWR20
		LDS R20,@0+0
		LDS R21,@0+1
.endm
.macro loadWZ
		LDS R30,@0+0
		LDS R31,@0+1
.endm
.macro load3B18
		LDS R18,@0+0
		LDS R19,@0+1
		LDS R20,@0+2
.endm

.macro storewz
		sts @0,zl
		sts @0+1,zh
.endm

.macro storeWR16
		sts @0+1,r17
		sts @0+0,r16
		
.endm
.macro storeWR18
		sts @0+0,r18
		sts @0+1,r19
.endm
.macro store3B18
		sts @0+0,r18
		sts @0+1,r19
		sts @0+2,r20
.endm
.macro storeWR28
		sts @0+0,r28
		sts @0+1,r29
.endm

.macro loadW
		LDS @0,@2+0
		LDS @1,@2+1
.endm

.macro storeW;4mck
		sts @0,@1
		sts @0+1,@2
.endm

.macro cpiW
		ldi	r16,low(@2)
		cp	@0,r16
		ldi	r16,high(@2)
		cpc @1,r16
.endm
.macro cpiW_
		ldi	r31,low(@2)
		cp	@0,r31
		ldi	r31,high(@2)
		cpc @1,r31
.endm

.macro cpW
		cp	@0,@2
		cpc @1,@3
.endm


.macro saveR16R17
		sts r16,@0+0
		sts r17,@0+1
.endm

.macro saveWZ
		sts @0+0,R30
		sts @0+1,R31
.endm

.macro SETBIT
		lds r16,@0
		sbr r16,@1
		sts @0,r16
.endm
.macro CLRBIT
		lds r16,@0
		Cbr r16,@1
		sts @0,r16
.endm

.macro SETBITP
		in r16,@0
		sbr r16,@1
		out @0,r16
.endm
.macro CLRBITP
		in r16,@0
		Cbr r16,@1
		out @0,r16
.endm


.macro INCRTO			;inkrementuje tylko do parametru @1 bez przewiniecia
		lds r16,@0
		inc r16
		cpi r16,@1-1
		brsh nosts
		sts @0,r16
nosts:
.endm

.macro INCRS			;inkrementuje tylko do 255 bez przewiniecia
		lds r16,@0
		inc r16
		breq nosts
		sts @0,r16
nosts:
.endm
.macro DECRS			;dekrementuje do 0 bez przewiniecia
		lds r16,@0
		subi r16,1
		brcs nost
		sts @0,r16
nost:
.endm

;specjalne makra do strojenia oscylatora tylko w dolnej polowce (jest niemonotoniczny na przedzile 127 128)
.macro decrs_OsccalL
		lds r16,osccal
		andi r16,0x7F
		subi r16,1
		brcs nosts
		sts osccal,r16
nosts:
.endm

.macro incrs_OsccalL
		lds r16,osccal
		andi r16,0x7F
		subi r16,-1
		brmi nosts
		sts osccal,r16
nosts:
.endm
.macro CLEARDW 
		sts @0+0,r15
		sts @0+1,r15
		sts @0+2,r15
		sts @0+3,r15
.endm

.macro CLEARW 
		sts @0+0,r15
		sts @0+1,r15
.endm

.macro CLEAR 
		sts @0,r15
.endm
.macro INCR
		lds r16,@0
		inc r16
		sts @0,r16
.endm
.macro DECR 
		lds r16,@0
		dec r16
		sts @0,r16
.endm

.macro INCRW
		lds r16,@0+0
		add r16,r14
		sts @0+0,r16
		lds r16,@0+1
		adc r16,r15			
		sts @0+1,r16
.endm
.macro DECRW 
		lds r16,@0+0
		sub r16,r14
		sts @0+0,r16
		lds r16,@0+1
		sbc r16,r15			
		sts @0+1,r16
.endm

.macro INCRWS
		lds r16,@0+0
		push r16
		add r16,r14
		sts @0+0,r16
		lds r16,@0+1
		push r16
		adc r16,r15			
		sts @0+1,r16
		pop	r16
		brcc pc+3
		sts @0+1,r16
		pop r16
		brcc pc+3
		sts @0+0,r16
.endm


.macro Logevent
		lds r16,@0+logbuffers
		inc r16
		breq nowrite
		sts @0+logbuffers,r16
nowrite:
.endm

.macro addw 
		add @0,@2
		adc @1,@3
.endm
;---------------------cbr / sbr dla niskich rejestrow-------------------
.macro cbr_
		ldi r16,255-@1;!@1						;poprawiony blad
		and @0,r16
.endm
.macro sbr_
		ldi r16,@1
		or @0,r16
.endm
;-----------------------------------------------------------------------

;===========================FREQ_METER816_macro.inc====================================
.macro disp_bin
;---------------------------binary 010101011-----
		sec
		rjmp bitdisploop+1
bitdisploop:
		clc
		ldi r16,'-'
		sbrc @0,7
		ldi r16,'*'
		rol @0
		call datasendtolcd	
		tst @0
		brne bitdisploop
;-------------------------------------------------
.endm


.macro disp_bcd_LSD
		mov r16,@0
		andi r16,0b00001111
		cpi r16,10					;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r16,256-7
disp_bcd0:
		call datasendtolcd48plus
.endm

.macro disp_bcd_MSD
		mov r16,@0
		andi r16,0b11110000
		swap r16
		cpi r16,10					;if >9 + 7chr to output (A=10dec)
		brlo disp_bcd0
		subi r16,256-7
disp_bcd0:
		call datasendtolcd48plus
.endm

.macro decrto0					;downcount to zero & then stop
		lds r16,@0
		subi r16,1
		brcc notzero
		inc r16
notzero:
		sts @0,r16
.endm

;--------------------------------lcd data display macros---------------------

.macro disp_pos
ldi xl,low(lcdram+@0)
ldi xh,high(lcdram+@0)
.endm

.macro stringROMnoused
		ldi zl,low(@0*2)
		ldi zh,high(@0*2)
Str_ROM:

		lpm		r16, z+
		cpi		r16, 255
		breq	exit
		subi r16,31
		push zl
		push zh
		rcall	charbuf
		pop zh
		pop zl
		rjmp	Str_ROM
exit:
.endm


;program wyswietlania stringa z ram convout w 3 wersji zrobil sie neico zawily (poprawione wygaszanie kropek)
;w parametrach nalezy podac odpowiednie wartosci, program
;najpierw umieszcza bajt konca ciagu 255dec, pozniej umieszcza wartosc
;ilosc wyswietlanych znakow w z (start+ile znakow wyswietlic)
;pozniej jest pobierany bajt danych, oraz bajt danych po nim
;rownoczesnie sprawdzane liczniki odpowiedzialne za wygaszanie zer
;oraz przecinki
;form conv_out directly to LCD&usart! no lcd buffer
;@0=digits to display (1-20)
;@1=decpoint parameter1 (number digits to first decpoint)
;@2=decpoint parameter2 (number digits between next decpoints)
;@3=number blank left zeros to clear
;@4=div by 10 (shift right one decay)

;****Wersja 5 dla GPSsync wyrzuca dane do softuart rcall usartsend
;R20 zwraca wartosc wygaszonych kropek (dla obslugi zmiany wyswietlanej jednostki)
;uzywane r16-r20
;kolejna odslona makra formatujacego string liczbowy
;tymrazem justowanie do lewej strony
;zamieniony rejestr x z y, z powodou lepszego dopasowania do pozostalby procedur
.macro stringdigJ
		clr r20						;licznik wygaszonych kropek
		clr r17						;domyslnie wygaszone kropki
		ldi xl,low(conv_out+0)		;adres wejscia	
		ldi xh,high(conv_out+0)
		adiw x,@4					;od ktorego bajtu ram zaczac przetwarzanie (od najmlodszego) >0 skutkuje podzielm przez 10, bez przesuwania przecinkow 
		ldi r16,255
		st x+,r16					;zapisz bajt konca ciagu 
		adiw x,@0					;wskaznik na najstarsza wyswietlana cyfre
		ldi r18,@1+1+@4				;w ktorym momencie wyswietlic kropke
		clr r19						;r19 licznik /ile zer od lewej wygasic/ clear blank zeros counter
Str_RAM:
;---------------------wygaszanie kropek---------------------------
		cpi r19,@3					;sprawdza ktore skolei (warunek czy wygaszac czy nie)
		brlo prezero
		ser r17						;zaswieca kropki (zwiazane z wygaszanymi zerami z lewej, jesli nei wygaszane kropki tez musza zostac zaswiecone
		ld	r16, x					;cyfra jedna pozycje wczesniej
		cpi r16,0
		breq prezero
		ser r17						;zero wygasza kropke ser zaaswieca
prezero:
;-------------------wygaszanie kropek end-------------------------------
		ld		r16, -x				;laduje z ram (conv_out) bajt
		cpi		r16, 255			;sprawdza czy nie koniec ciagu
		breq	exit
		cpi r16,0					;spradza czy wartosc cyfry=0
		brne nozero
									;jesli zero
		cpi r19,@3					;sprawdza ktore skolei (warunek czy wygaszac czy nie)
		brsh nozero
	
		ldi r16,' '-48				;load space" " if blankzero

		inc r19						;blankzerocounter
		
		brtc zer0					;flaga T wlacza justowanie do lewej
		rjmp Str_RAM				;-}-
nozero:
		ser r19		
zer0:
		push r16
		dec r18
		brne Str_R
		subi r18,256-@2				;add r18,@2
		cpi r17,0
		breq wygaskropke
		ldi r16,'.'					;decpoint	
		rjmp niewygaskropki
wygaskropke:
		inc r20
		ldi r16,' '
niewygaskropki:
		;st y+,r16					;zapisuje znak pojedynczy
		call usartsend
str_r:
;-----------------zapisuje cyfre z convout-------------------------
		pop r16
dsd:
		subi r16, 256-48			;dodaj 48,bo cyfry w convout 0-9
		;st y+,r16		
		call usartsend
		rjmp Str_RAM				;petla
exit:
.endm
;------------------------------------------------------------------

.macro clearconvout
		ldi zl,low (conv_out+1)
		ldi zh,high(conv_out+1)
		ldi r16,convoutmax
zeruj:
		st z+,r15
		dec r16
		brne zeruj
.endm

.macro clearconvin
;@0=bits to clear x8 ;4for 32bit 8 for 64bit
		ldi zl,low (conv_in)
		ldi zh,high(conv_in)
		ldi r16,@0					;4for 32bit 8 for 64bit
zeruj:
		st z+,r15
		dec r16
		brne zeruj
.endm

.macro vport_set
		lds r16,vport
		sbr r16,@0
		sts vport,r16
.endm

.macro vport_clr
		lds r16,vport
		cbr r16,@0
		sts vport,r16
.endm
.macro EVENTcount4Bfast
		push r16
		lds r16,@0+0
		add r16,r14		;r14=1
		sts @0+0,r16
		lds r16,@0+1
		adc r16,r15
		sts @0+1,r16
		lds r16,@0+2
		adc r16,r15
		sts @0+2,r16
		lds r16,@0+3
		adc r16,r15
		sts @0+3,r16
		pop r16
.endm
;inkrementacja ram w z 32bity
;uwaga modyfikuje duzo rejestow r16-r19,z
.macro	incr32
	ldiwz @0
	call	incrZ32
.endm
.macro	incrs32
	ldiwz @0
	call	incrsZ32
.endm
.macro	decr32
	ldiwz @0
	call	decrZ32
.endm
.macro decrs32
	ldiwz @0
	call	decrsZ32
.endm



