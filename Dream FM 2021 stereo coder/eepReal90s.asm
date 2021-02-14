;===========================================================
;==================== Dream FM 2021 ========================
;==================== eepReal90s.asm =======================
;===========================================================
;V1b	bieda uc - brak przerwania eeprom, 
;przerobiona wersia V4 reaLeeprom  na nieprzerwaniowa 
;zapis i przywracanie ram do eeprom z korekta przeklaman
;===========================================================

/*
	Procedura umozliwiajaca nezawodne odtworzenie bajtu pamieci 
	w przypadku uszkodzenia jednej z 3 lustrzanych komorek o takiej samej wartosci
	;Testowane 3B pamieci, odtwarzany uszkodzony bajt 
	na podstawie 2 identycznych wartosci
	;jezeli wszystkie 3 bajty rozne, odtworzenie niemozliwe 
	- zapisywane lustra wartosci BB (BAD) oraz flaga T ustawiona
*/


;===========================================================
#define		NVRAMSTART SRAM_START+16						;poczatek ramu kopiowanego
#define 	RELIABLE_ALLSPACE 16							;rozmiar ramu kopiowanego (co taki rozmiar jest tworzone lustro w eeprom)
;#define		AUTOEEPDBG									;debugowanie zapisow

.eseg
RESERVED_EEP_MEMORY:		.Byte	RELIABLE_ALLSPACE*3		

.dseg
;.org 		SRAM_START
;==================EEPROM AUTO WRITE========================
REEPRoM_MIRROR_C:	.Byte	1								;Licznik aktualnie zapisywanej czesci eeprom (lustro 1 z 3)
EEPROMBYTE_P:		.Byte	1								;pending byte - aktualnie zapisywany do eeprom bajt (w 3 lustra)
REEPROM_WC:			.Byte	2								;licznik sprawdzanego bajtu
;===========================================================	
																				
.cseg
.equ RELIABLE_offset=RELIABLE_ALLSPACE						;odleglosc miedzy lustrami w eeprom dla NVRAM uwaga musi sie dzielic/4 bez reszty ! patrz procedura w reliable eeprom
.equ RELIABLE_NVRAMSTART=NVRAMSTART							;start NVRAM

;--------startowanie updateu eeprom z ram-------------------
;startnvramcommit:
NVRAMwrite:	
		;cli
;ldi 	r16, '>'
;rcall 	usartsend
															;blokujaca petla
		sti 	REEPRoM_MIRROR_C,3							;start poprawny to wartosc 3
		stiw	REEPROM_WC,0
NVRAMwr:
		;wdr
		rcall 	AUTOEEPROM
		loadw 	r16,r17,REEPROM_WC
		cpi		r16,low(RELIABLE_ALLSPACE)
		ldi		r16,high(RELIABLE_ALLSPACE)
		cpc		r17,r16
		brne 	NVRAMwr	
	;*@*sbi  	EECR, EERIE									;wlacz przerwanie EEPROM READY automatycznie wylaczane po updejcie eeprom (kopia ram)
retu3:
		;sei

;ldi 	r16, '*'
;rcall 	usartsend
ret

NVRAMrestore:
;----------------COPY EEPROM TO RAM-------------------------
;----------wartosci ladowane z eeprom (niezawodnego)--------
;--kopiowanie eeprom do ram Z->Y /Data-R16 Counter-R26------
;RELIABLEEEPROM ;adres Z, dane r16 max 160B pozniej 2x 
;lustro co RELIABLE_offset
		ldiwy 	RELIABLE_NVRAMSTART							;pierwszy bajt ram user data, adresy w ram musza byc ustawione kolejno jak w eeprom 
		ldiwz 	0x00										;adres eeprom start (user data)
		ldiwx 	RELIABLE_ALLSPACE							;ile adresow kopiowane z eeprom do ram
		clt													;falga domyslnego braku bledu
eepcopyloop:

		rcall 	RELIABLEEEPROM								;dane w eeprom (kopie lustrzane)
		adiw 	z,1											;inkrementacja adresu Z
		st 		y+ ,r16										;autoinkrementacja y po zapisie ram		
		sbiw 	r26,1										;licznik bajtu
		brne 	eepcopyloop									;dopuki nie ostatni bajt
ret
RELIABLEEEPROM:
		push 	r30
		push 	r31

		rcall 	avreepromread
		mov 	r17,r16
		rcall 	plusoffset									;dodaj offset jednego lustra
		rcall 	avreepromread
		mov 	r18,r16

		rcall 	plusoffset
		rcall 	avreepromread

		cp 		r17,r18
		brne 	pairanyfail									;jedna z 3 par niezgadza sie
		cp 		r18,r16
		brne 	pairanyfail
		cp 		r16,r17
		brne 	pairanyfail									;jesli wszystkie bajty takie same data ok
		rjmp 	retelia										;normalny powrot w r16 (oraz r17 r18) odczytany bajt
pairanyfail:
		cp 		r17,r18
		brne 	pair1fail
		mov 	r16,r17										;jesli wszystkie bajty takie same data ok
		rjmp 	eepromdatarepair
pair1fail:
		cp 		r18,r16
		brne 	pair2fail
		rjmp 	eepromdatarepair
pair2fail:
		cp 		r16,r17
		brne 	pair3fail
		rjmp 	eepromdatarepair
pair3fail:													;niemozliwe odczytanie wiekszosci poprawnych bajtow
		ldi 	r16,0xBB									;bad komorki odtwarzane z wartosia Bb (zeby nie logowalo po kilka razy nieprawidlowych wartosci luster)
		set													;T=error
		;incrs32	eepromError								;licznik bledow
		rjmp 	eepromdatarepairimposible
retelia:
		pop 	r31
		pop 	r30
	
ret

;---------zapis 3 bajtow RELIABLE EEPROM--------------------
;odtworzenie bledow jesli jakis bajt uszkodzony 
;ale mozna odzyskac z poprawnej pary
eepromdatarepair:

eepromdatarepairimposible:
		rcall 	minus2offset
		rcall 	minus2offset
		rcall 	avreepromwrite								;zapis 3 tychsamych bajtow
		rcall 	plusoffset
		rcall 	avreepromwrite
		rcall 	plusoffset
		rcall 	avreepromwrite
;push r16
;ldi 	r16, 'R'
;rcall 	usartsend
;pop r16
rjmp retelia


plusoffset:
		adiw	z,RELIABLE_offset
		ret
minus2offset:
		sbiw	z,RELIABLE_offset
		ret



;******************AUTOEEPROM**************AUTOEEPROM*******
;====automatyczne backupowanie danych z ram do eeprom=======
;Program porownuje wartosci pamieci ram oraz eeprom (z uzyciem RELIABLEEEPROM)
;w przypadku roznic zapisywana aktualna wartosc ram do eeprom (3x lustro)
;pierwszy start trzeba zainicjalizowac. pozniej kazde przerwanie uruchamia automatycznie kolejny bajt sprawdzany i zapisywany jesli trzeba
;o ile odczyt i porownanie jednego bajtu w jednym wywolaniu, o tyle zapis jednego bajtu przebiega w 3 kolejnych wywolaniach przerwania (zapis 3 luster)
;REEPRoM_MIRROR_C - zmienna w stanie spoczynku=3(max wartosc lustra) w przypadku zapisu luster zmienna ma kolejno wartosci 1,2,3 
;REEPRoM_WC - zmienna zawiera numer porownywanego  bajtu w spoczynku max wartosc bajtu lustra
;EEPROMBYTE_P - przechowywana tymczasowo wartosc bajtu z ram zapisywana do luster w eeprom
AUTOEEPROM:	
		lds 	r16,REEPRoM_MIRROR_C						;licznik zapisywanego lustra (test czy zapis luster w trakcie)

		cpi 	r16,3
		brsh 	testnextbyte								;jesli wszystkie lustra zapisane bajtem
		rjmp 	eeprommirrorwrite							;jesli zapis luster trwa
testnextbyte:

		lds 	r16,REEPRoM_WC+0
		lds 	r17,REEPRoM_WC+1
		ldi		r18,low(RELIABLE_ALLSPACE)	
		cp		r16,r18										;wazny test na osiagniecie calego zakresu*
		ldi		r18,high(RELIABLE_ALLSPACE)
		cpc		r17,r18										;wazny test na osiagniecie calego zakresu*
		brne 	pc+2
		rjmp 	byteeepmax
noACfaulttest:
;-----------------------------------------------------------
		clr 	r30											;w Z adres odczytu EEPROM
		clr 	r31 
 		ldiwz 	0x00										;adres eeprom start (user data)

		add 	r30,r16										;dodaj do adresu licznik WC 
		adc 	r31,r17
		rcall 	RELIABLEEEPROM								;zaladuj bajt z eeprom do r16 (Z wraca niezmienione)

		
		ldi 	r17,low(RELIABLE_NVRAMSTART)				;ramstart pierwszego adresu0
		add 	r30,r17
		ldi 	r17,high(RELIABLE_NVRAMSTART)				;adres ram pierwszegio bajtu dla kopii eeprom od (RELIABLE_RAMSTART)
		adc 	r31,r17
		LD 		r18,Z										;wartosc z ram do r18	
;-------------mozna porownac ram z eeprom-------------------
		CP 		R18,R16										;porownanie ram oraz eeprom lustro0
		brne 	notestnextbyte
		incrw 	REEPRoM_WC									;wartosci ram eeprom byly takiesame mozna sprawdzic kolejny bajt
rjmp testnextbyte

notestnextbyte:
		sts 	EEPROMBYTE_P,R18							;zapamietaj w ram bajt ktory zaisywany 3 razy
		clear 	REEPRoM_MIRROR_C							;wyzeruj flagolicznik zapisywanego lustra - kolejne wywolanie tego przerwania spowoduje skok do procedury zapisu 3 luster, dopiero po akonczeniu zapisu testowany bedzie kolejny bajt danych
		;incrs32	eepromWrite;wr counter
byteeepmax:
nobyteeepmax:
ret

eeprommirrorwrite:
		loadw 	r30,r31,REEPRoM_WC
		cpi 	r16,0										;poniewaz zapis mirror0 r16=0
		breq 	mirrorzero
eeprommirrorwrite1:
		rcall 	plusoffset									;dodaje do Z offset jednego lustra
		dec 	r16											;w R16 wartosc z REEPRoM_mirror_c jesli zapisywane lustro 1+
		brne 	eeprommirrorwrite1
mirrorzero:
		lds 	r16,EEPROMBYTE_P	

;----------wartosci rozne zupdejtuj eeprom------------------		
;------zapis do eeprom bez czekania na flage----------------
		rcall	avreepromwrite
;-----------------------------------------------------------
		incr 	REEPRoM_MIRROR_C							;bajt numeru lustra inkrementowany
		cpi 	r16,3
		brlo 	lastmirrorsaved
		incrw 	REEPRoM_WC									;przy wyjsciu inkrementuj licznik bajtu sprawdzanego
lastmirrorsaved:
#ifdef AUTOEEPDBG
push 	r17
rcall	usart_nl
ldi 	r16,'W'
rcall	usartSend
mov		r16,r31
rcall 	usartSend_hex
mov		r16,r30
rcall 	usartSend_hex
ldi 	r16,'='
rcall	usartSend
pop 	r16
rcall 	usartSend_hex
ldi 	r16,' '
rcall	usartSend
#endif
rjmp nobyteeepmax											;koniec programu przerwania									
;===========================================================
avreepromwrite: 
		rcall	eepavrreadywait								;*R*to jest bardzo wazne (jesli glicze zasilania lub zegara bez tego bledne odczyty i uszkodzony eeprom)
		out 	eear,r30
		;out 	eearh,r31
		out 	eedr,r16
		sbi  	EECR, EEMWE;EEMPE
		sbi  	EECR, EEWE;EEPE 							;*R* czekanie na falge po zapisie musi byc tez								;po zapisie tez oczekwianie na skonczenie zapisu ze wgledu na bledy gdy glicze vcc i zegara
eepavrreadywait:											;*R*
		wdr													;koniecznie po zapisie nie przed (problem w edytorze bo szybko odczyt podczas trwania zapisu i bledne dane odczytywane z eeprom)
		sbic 	EECR,EEWE;EEPE								;Wait for completion of previous write
		rjmp 	eepavrreadywait
ret
avreepromread:
		rcall	eepavrreadywait								;*R*
		out 	eearl,r30									;wskaznik bajtow eeprom 
		;out 	eearh,r31
		sbi 	EECR, EERE									;odczyt eeprom
		in		r16,eedr
;rcall 	usartSend_hex
ret


