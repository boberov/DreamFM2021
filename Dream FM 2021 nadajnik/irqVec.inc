;===========================================================
;==================== Dream FM 2021  =======================
;===================== irqVec.inc ==========================
;===========================================================

.cseg
.org 	0x00												;wektory przerwan
		rjmp 	Init 										;Reset Handler

.org OVF0addr
		rjmp	fmeas_irq	
.org URXCaddr
		rjmp	URX_irq		

fmeas_irq:
		in		r2,sreg
		sbr 	SysFlags,1<<F62kHz_f
;--------------------- soft pwm ----------------------------;dla 4MHz /64 244Hz 8bit
		inc		softPWmC
		cp		softPWmC,softPWmV
		brlo	pc+2
		sbi		PWM_port,PWM_portNr
		brsh	pc+2
		cbi		PWM_port,PWM_portNr
;-----------------------------------------------------------

		dec		prescTim0
		brne	ret00	
fmeasure:
		push 	r16
		push 	r17		

		ldi		r16,0x08									;reload prescalera
		mov		prescTim0,r16

		sbrc	SysFlags, MeasCancel_f
		rjmp	meas_invalid
		
		in 		r16,tcnt1l
		in		r17,tcnt1h
		lsr		r17											;odrzucenie lsb wynik zliczania podzielony przez 2
		ror 	r16

		storew	freqRX+0,r16,r17
		sbr 	SysFlags, 1<<MeasReady_f
meas_invalid:
		oti		tcnt1h,0									;zapis 16b jest atomowy jesli h pierwszy
		oti		tcnt1l,2+2									;korekta cykli
		
		oti		tifr, 1<<tov1								;kasuj flage jesli aktywna

		;oti		tcnt0,0x80									;skrocenie czasu do przerwania tcnt0
	
		cbr		SysFlags, 1<<MeasCancel_f					;kasuj flage niewaznego pomiaru
		sbr 	SysFlags, 1<<F30Hz_f						;flaga przerwania cnt0
		pop		r17
		pop		r16
ret00:
		out		sreg,r2

reti

;===========================================================












.exit

;---------------INT1_IRQ------------------------------------
int1_irq:
;-----------------------------------------------------------
		sei													;to przerwanie moze byc wywlaszczalne min ze wzgledu na blokujacy delay (w przypadku rekurencji nie powinno byc problemow)
															;bez wywlaszczania w najgorszym razie nastapi przeklamanie transferu 1wire
		push 	r16
		in 		r16,sreg	
		push 	r16
		push	r17
															



		pop		r17
		pop 	r16
		out 	sreg,r16
		pop		r16
reti
;-----------------------------------------------------------
;--------------opoznienie precyzyjne us-----------------------
delayPrec:

delaypr1:
;		nops 1
		cpi 	r16,0
		brne 	delaypr2
		cpi 	r17,0
		brne 	delaypr3
ret
delaypr3:
		;nops 1
		dec 	r17
		dec 	r16
		rjmp	delaypr1
delaypr2:
		nops 2
		dec 	r16
		rjmp	delaypr1

;--------------opoznienie standardowe------------------------
delayr:
		dec 	r16
		brne 	delayr
		dec 	r17
		brne 	delayr
ret
;------------------------------------------------------------

;to jest eksperymentalny program do wyswietlania aktualnego adresu programu 
;poprzez wyswietlenie adresu odkladanego na stos w moemencie wystapienia tego przerwania
;mialo to sluzyc poszukiwaniu buga modyfikujacego rejestr
;zeby to uzyc trzeba wlaczyc przerwanie i wymusic stan niski na INT0  eimsk,	1<<INT0	
ext_dbg:
reti

		in 		r2,sreg
	
		cpi		r24,0										;testowany zmieniany rejestr
		brne 	noerrr

		push 	r16											;uzywane rejestry
		push 	r17
		push 	r30
		push 	r31

		call	nl_DBG										;nowa linia

		in 		r30,spl										;wskaznik stosu
		in 		r31,sph

		adiw	z,4+1										;przesuniecie adresu o wyphane rejestry
		ld 		r16,z+

		push 	r16
		swap 	r16
		call 	hexD_0
		pop 	r16
		call 	hexD_0

		ld r16,z+
		push 	r16
		swap 	r16
		call 	hexD_0
		pop 	r16
		call 	hexD_0

		pop 	r31
		pop 	r30
		pop 	r17
		pop 	r16		
		;rjmp pc-2											;zatrzymanie
noerrr:
		out 	sreg,r2
reti
