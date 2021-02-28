;=================================================================
;================== Dream FM 2021 VFD saver ======================
;========================= macro.inc =============================
;=================================================================

.macro mode 
		ldi		r16,@0
		mov		modeR,r16
.endm

.macro nops ;1-16
	.if @0>1
		nop
		nops @0-1
	.elif @0==1
		nop
	.endif
.endm 

.macro nops2x ;1-16
	.if @0>1
		lds superTemp,TMP
		nops2x @0-1
	.elif @0==1
		lds superTemp,TMP
	.endif
.endm 


.macro MAIN_REGS_clear
		clr 	r31
		ldi 	r30,29
regclearloop:
		st 		z,r31
		subi 	r30,1
		brcc 	regclearloop
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
												
.macro oti;mck									;polaczene ldi oraz out
		ldi r16,@1
		out @0,r16
.endm

.macro sti;3mck
		ldi r16, @1
		sts @0,r16
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
		LDI @1,high(@2)
.endm
.macro LDIW_
		LDI r16,low(@2)
		MOV @0,r16
		LDI r16,high(@2)
		MOV @1,r16
.endm

.macro STIW;new
		LDI R16,low(@1)
		STS @0+0,R16
		LDI R16,high(@1)
		STS @0+1,R16
.endm
.macro STSW;new
		STS @0+0,@1
		STS @0+1,@2
.endm
.macro LDSW;new		
		LDS @1,@2+1
		LDS @0,@2+0
.endm
.macro CPIW;new
		CPI @0,low(@2)
		LDI R16,high(@2)
		CPC @1,R16
.endm
.macro CPW;new
		LDI R16,low(@2)
		CP @0,r16
		LDI R16,high(@2)
		CPC @1,R16
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

.macro storeWR16
		sts @0+0,r16
		sts @0+1,r17
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

.macro INCRWC
		lds r16,@0+0
		adc r16,r15
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
.macro DECRWC 
		lds r16,@0+0
		sbc r16,r15
		sts @0+0,r16
		lds r16,@0+1
		sbc r16,r15			
		sts @0+1,r16
.endm

;---------------------cbr / sbr dla niskich rejestrow-------------------
.macro cbr_
		ldi r16,255-@1
		and @0,r16
.endm
.macro sbr_
		ldi r16,@1
		or @0,r16
.endm
;-----------------------------------------------------------------------
.macro ldi_
		ldi r16,@1
		mov @0,r16
.endm
//T10
.macro CCP_IOREG
	ldi		r16,CPU_CCP_IOREG_gc
	out 	CPU_CCP,r16 
.endm

