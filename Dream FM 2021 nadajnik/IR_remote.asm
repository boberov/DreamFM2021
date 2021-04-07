;===========================================================
;===================  Dream FM 2021  =======================
;==================== IR_remote.asm ========================
;===========================================================														
;wysylanie danych w standardzie NECa na wybrany port
;
.equ 	REMport=portb
.equ 	REMddr=ddrb
.equ	REMpinr =5 ;(mosi)
;-----------------------------------------------------------
;------- dane pobierane z pod X command/data0/data1 --------
;
;1T=562.5us
IR_Send:
		sbi	REMddr,REMpinr

;cli

;ldiwx URXparam
;sti URXparam,0xAA
;sti URXparam+1,0xFF
;sti URXparam+2,0

;		cbi 	REMport,REMpinr
;		rcall	IR_1Tdelay
;		sbi 	REMport,REMpinr
;		rcall	IR_1Tdelay


;		ret
;header 16T delay data = 1 (low)  9ms
		ldi 	r20,16										;parametr opoznienia w bitach 562us
		cbi 	REMport,REMpinr
		rcall	IR_Tdelay
;header 8T delay data = 0 (hi)   4.5ms
		ldi 	r20,8
		sbi 	REMport,REMpinr
		rcall	IR_Tdelay
;-------data shift 32b-------------
		ld		r16,x+
		rcall	ir8bitshift
		ld		r16,x+
		rcall	ir8bitshift
		ld		r16,x
		rcall	ir8bitshift
		ld		r16,x
		com		r16
		rcall	ir8bitshift
		cbi 	REMport,REMpinr
		rcall	IR_1Tdelay									;tail 1b
		sbi 	REMport,REMpinr
sbi 	REMport,REMpinr
ldi	r20,50
rcall	IR_Tdelay

		cbi	REMddr,REMpinr
ret
;-----------------------------------------------------------
ret
;wysylanie 8 bitow danych
ir8bitshift:
		ldi 	r19,8
ir8bitshift0:
		lsl		r16
		brcs	one_bit
		cbi 	REMport,REMpinr
		rcall	IR_1Tdelay
		sbi 	REMport,REMpinr
		rcall	IR_1Tdelay
		rjmp	zero_bit
one_bit:
		cbi 	REMport,REMpinr
		rcall	IR_1Tdelay
		sbi 	REMport,REMpinr
		ldi 	r20,3;3T
		rcall	IR_Tdelay
															
zero_bit:
		dec		r19
		brne	ir8bitshift0
ret
;-------------------------------------
;precyzyjne opoznienie wyznaczane parametrem dla 4MHz zegara
;czas dla 1T ma zajac 562.5us
;22.5 = 56.25us
;2.25 = 5.625us
;10= 22.5us
;4MHz ck = 1us/4 = 0.25us
;1.25us/0.25 = 5MCK na mikropetle 225 * 1.25us mikropetla = 0.5T
;stad parametr mnozony x2 aby dopasowac
IR_1Tdelay:
		ldi		r20,1					;1T
IR_Tdelay:								;T w prametrze R20
		lsl		r20						;mnozenie x2
		ldi		r21,225-(2+2)			;kompensacja opoznien skokow wywolan
start0_loop:
		wdr
		nop
		dec		r21
		brne	start0_loop				;petla MCK = 1.25us
		ldi		r21,225-3				;kompensacja cykli warunku petli zewnetrznej
		dec 	r20
		brne	start0_loop				;petla 225*1.25us = 0.5T 562.5us
;-----------------------------------------------------------
ret



.exit
Sendir:
'For R3 = 0 To 1
'START HEAD          'generowanie impulsu start 16T+7.5T
'1T=560uS
Ddrb.0 = 1                                                  'wlacz port wyjsciowy
'Portb.0 = 0                                                 ' w stanie powerdown port sciagany do masy (sterowanie tranzystora)
Tccr0a = &B01000010                                         'com01=1 wlaczone wyjscie pwm
'16T Delay
For R = 0 To 15
Gosub Wait1t
Next R
Tccr0a = &B00000010                                         'com01=0 wylaczone wyjscie pwm
'7.5T Delay
For R = 0 To 6
Gosub Wait1t
Next R
Waitus 250
Command(4) = Not Command(3)                                 'ostatni bajt zawsze rowny zanegowanemu przedostatniemu
R1 = 1
Czytajdane:
R2 = Command(r1)
For R = 0 To 7
If R2 > 127 Then
          Tccr0a = &B01000010 L                              'generowanie jedynki
          'czekaj  czas 1T
          Gosub Wait1t
          Tccr0a = &B00000010 H
          'czekaj czas 3T
          Gosub Wait1t
          Gosub Wait1t
          Gosub Wait1t
          Else
          Tccr0a = &B01000010                               'generowanie zera
          'czekaj  czas 1T
          Gosub Wait1t
          Tccr0a = &B00000010
          'czekaj czas 1T
          Gosub Wait1t
End If
Shift R2 , Left , 1
Next R
Incr R1                                                     'po wyslaniu 8 bitow zwieksz nr bajtu wysylanego
If R1 < 5 Then
        Goto Czytajdane
End If
'po wyslaniu bajtow kodu, na zakonczenie dodatkowy impuls (tail)
Tccr0a = &B01000010
Gosub Wait1t
Tccr0a = &B00000010
Ddrb.0 = 0                                                  ' pozostaje aktywny tylko pullup
Return
