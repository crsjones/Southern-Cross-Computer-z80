;--------------------
; SC-APU Demo Program
;--------------------
; 
#include "SCM18_Include.asm"
;
; a simple demo of the AM9511A APU arithmetic functions and square root
; uses the Lawrence Livermore Laboratories Flaoting point library to do
; the input and output.
; 
; Craig Jones 2023-06-10
;
;AM9511A APU port address
;
APUSTATUS	.EQU	0FFH	;read status
APUCOMAND	.EQU	0FFH	;write commands
APUDATA	.EQU	0FEH	;read and write Top of Stack
;
; APU status register
;
BUSY	.EQU	80H	;currently executing a command
SGN	.EQU	40H	;the value on the top of the stack is negative
ZERO	.EQU	20H	;the value on the top of the stack is zero
ERRORCODE	.EQU	1EH	;indicates the validity of the previous operation
CARRY	.EQU	01H	;the previous operation resulted in a carry/borrow
;
;APU Commands
;
FADD	.equ	90H
FSUB	.equ	91H
FMUL	.equ	92H
FDIV	.equ	93H
FSQRT	.equ	81H
;------------
; ASCII CODES
;------------
ESC	.EQU	1BH
CR	.EQU	0DH
LF	.EQU	0AH

	.org	2000H
main
	ld	c,PRNTSZ
	rst	30h
	.db  "AM9511A Example Code",CR,LF,0

main1
; display the message
	ld	c,PRNTSZ
	rst	30h
	.db	CR,LF,"s,r,+,-,/,x,t,c,h for help"
	.db	CR,LF,0
;display the prompt
	ld	a,'?'
	ld	c,TXDATA
	rst	30h

main2
	ld	c,RXDATA	;wait for a serial character
	rst	30h
	ld	hl,cmds
	ld	c,MENU	;execute the selected subroutine
	rst	30h
	jp	main1

cmds
	.db	9
	.DB	'r','s','+','-'
	.DB	'/','x','t','c'
	.DB 'h'
	.DW	ClrSvreq,SetSvreq,APUadd,APUsub
	.DW	APUdiv,APUmul,APUsqrt,convert
	.DW help

; echo the accepted command and do a CR,LF
cecho	ld	c,TXDATA
	rst	30h	;echo
	call	CRLF
	ret
;
;send a carriage return line feed
;
CRLF
	ld	a,CR
	ld	c,TXDATA
	rst	30h
	ld	a,LF
	ld	c,TXDATA
	rst 30h
	ret
;
; help print help message
;	
help	call cecho
	ld	c,PRNTSZ
	rst	30h
	.db	CR,LF," FLOATING POINT OPERATIONS",CR,LF
	.db	"r = turn on SVREG LED",CR,LF
	.db	"s = turn off SVREG LED",CR,LF
	.db	"+ = Addition",CR,LF
	.db	"- = Subtraction",CR,LF
	.db	"/ = Division",CR,LF
	.db	"x = Multiplication",CR,LF
	.db	"t = Square root",CR,LF
	.db	"c = Convert to float in scientific notation",CR,LF,CR,LF
	.db	" CAPITAL E for exponent i.e. 31.4159E-01"
	.db	CR,LF,0
	ret
;-----------------------------------------------------------------
; turn on and off SVREG LED
; the APU NOP command can be used to turn the SVREG LED on and off
;-----------------------------------------------------------------
;
; turn off SVREG LED
;
ClrSvreq
	call	cecho
svoff	call	apubusy
	ld	a,00H	;send NOP, bit 7=0 turns off SVREG LED
	out	(APUCOMAND),a
	call	apubusy
	ret
;
; turn on SVREG LED
;
SetSvreq
	call	cecho
svon	call	apubusy
	ld	a,80H	;send NOP bit 7=1 turns on SVREG LED
	out	(APUCOMAND),a
	call	apubusy
	ret
;------------------------
; floating point addition
; sum = addend1 + addend2
;------------------------
APUadd
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"sum = addend1 + addend2",CR,LF
	.db	"Enter Addend 1 ",0
	call	getop1
	ld	c,PRNTSZ
	rst	30h
	.db	"Enter Addend 2 ",0
	call	getop2

	ld	c,PRNTSZ
	rst	30h
	.db	"Sum = ",0

	call	apubusy
	ld	h,SCRPG
	call	push32OP1	;write the operand to the APU
	ld	h,SCRPG
	call	push32OP2	;write the operand to the APU
;
; issue FADD command
;
	call	apubusy
	ld	a,FADD	; bit 7 of the command is set to turn on SVREG LED
	out	(APUCOMAND),a	;give the APU the ADD command
	call	apubusy
	call svoff	;command finished turn off SVREG LED
	ld	h,SCRPG
	ld	l,OP1
	call	pop32
	call	putop1
	ret
;---------------------------------
; floating point subtraction
;difference = minuend - subtrahend
;---------------------------------
APUsub
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"difference = minuend - subtrahend",CR,LF
	.db	"Enter Minuend ",0
	call	getop1
	ld	c,PRNTSZ
	rst	30h
	.db	"Enter Subtrahend ",0
	call	getop2

	ld	c,PRNTSZ
	rst	30h
	.db	"Difference = ",0

	call	apubusy
	ld	h,SCRPG
	call	push32OP1
	ld	h,SCRPG
	call	push32OP2
;
; issue FSUB command
;
	call	apubusy
	ld	a,FSUB
	out	(APUCOMAND),a
	call	apubusy
	call svoff
	ld	h,SCRPG
	ld	l,OP1
	call	pop32
	call	putop1
	ret
;-----------------------------
; floating point division
;quotient = dividend / divisor
;-----------------------------
APUdiv
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"quotient = dividend / divisor",CR,LF
	.db	"Enter dividend ",0
	call	getop1
	ld	c,PRNTSZ
	rst	30h
	.db	"Enter divisor ",0
	call	getop2

	ld	c,PRNTSZ
	rst	30h
	.db	"quotient = ",0

	call	apubusy
	ld	h,SCRPG
	call	push32OP1
	ld	h,SCRPG
	call	push32OP2
;
; issue FDIV command
;
	call	apubusy
	ld	a,FDIV
	out	(APUCOMAND),a
	call	apubusy
	call	svoff
	ld	h,SCRPG
	ld	l,OP1
	call	pop32
	call	putop1
	ret
;------------------------------
; floating point multiplication
; product = factor1 x factor2
;------------------------------
APUmul
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"product = factor1 x factor2",CR,LF
	.db	"Enter factor1 ",0
	call	getop1
	ld	c,PRNTSZ
	rst	30h
	.db	"Enter factor2 ",0
	call	getop2

	ld	c,PRNTSZ
	rst	30h
	.db	"product = ",0

	call	apubusy
	ld	h,SCRPG
	call	push32OP1
	ld	h,SCRPG
	call	push32OP2
;
; issue FMUL command
;
	call	apubusy
	ld	a,FMUL
	out	(APUCOMAND),a
	call	apubusy
	call	svoff
	ld	h,SCRPG
	ld	l,OP1
	call	pop32
	call	putop1
	ret
;---------------------------
; floating point square root
;---------------------------
APUsqrt
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"Enter Square",CR,LF,0
	call	getop1
	ld	c,PRNTSZ
	rst	30h
	.db	"Square Root = ",0
;
; issue FSQRT command
;
	call	apubusy
	ld	h,SCRPG
	call	push32OP1
	call	apubusy
	ld	a,FSQRT
	out	(APUCOMAND),a
	call	apubusy
	call	svoff
	ld	h,SCRPG
	ld	l,OP1
	call	pop32
	call	putop1
	ret	
;-------------------------------------------------------
; convert a string to floating point scientific notation
;-------------------------------------------------------
;
; uses the LLL library routine INPUT to get an input string and 
; CVRT to convert an input string to floating point in
; scientific notation
;
convert
	call	cecho
	ld	c,PRNTSZ
	rst	30h
	.db	"Convert to FP scientific notation ",0
	call	getop1	;uses LLL code INPUT to get input string
;
	ld	c,PRNTSZ
	rst	30h
	.db	"FP Scientific Notation = ",0 
	call	putop1 ; uses LLL code CVRT to convert to FP scientific notation
	ret

;get operand 1
getop1:
        LD      H,SCRPG         ;SET H REGISTER TO RAM SCRATCH PAGE
        LD      L,OP1           ;POINTER TO OPERAND 1
        LD      C,SCR           ;SCRATCH AREA
        CALL    INPUT           ;INPUT OPERAND 1 FROM TERMINAL
        CALL    CRLF
        RET
;get operand 2
getop2:
       LD      H,SCRPG         ;SET H REGISTER TO RAM SCRATCH PAGE
       LD      L,OP2           ;POINTER TO OPERAND 2
       LD      C,SCR           ;SCRATCH AREA
       CALL    INPUT           ;INPUT OPERAND 1 FROM TERMINAL
       CALL    CRLF
       RET

putop1:
        LD H,SCRPG             ;SET H REGISTER TO RAM SCRATCH PAGE
        LD L,OP1
        LD C,SCR               ;SCRATCH AREA
        call CVRT              ;OUTPUT NUMBER STARTING IN LOCATION OP1 TO TERMINAL
        CALL  CRLF
        RET

putrsult:
        LD H,SCRPG             ;SET H REGISTER TO RAM SCRATCH PAGE
        LD L,RSULT
        LD C,SCR               ;SCRATCH AREA
        call CVRT              ;OUTPUT NUMBER STARTING IN LOCATION OP1 TO TERMINAL
        CALL  CRLF
        RET
;
; is the APU busy?
;
apubusy	in	a,(APUSTATUS)
	and	BUSY
	jr	nz,apubusy
	ret
	
;index to bytes within operands OP1 and OP2, 32 bit floats
OP10:    .equ       0
OP11:    .equ       1
OP12:    .equ       2
OP13:    .equ       3

OP20:    .equ       4
OP21:    .equ       5
OP22:    .equ       6
OP23:    .equ       7

;
; push 32 bit fp operand 1 onto the APU stack
;
push32OP1
	ld	l,OP12
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP11
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP10
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP13
	ld	a,(hl)
	out	(APUDATA),a
	ret
;
; push 32 bit fp operand 2 onto the APU stack
;
push32OP2
	ld	l,OP22
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP21
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP20
	ld	a,(hl)
	out	(APUDATA),a
	ld	l,OP23
	ld	a,(hl)
	out	(APUDATA),a
	ret
;
; pop 32 bit fp result from APU stack into operand 1
;
pop32:
	ld	l,OP13
	in	a,(APUDATA)
	ld	(hl),a
	ld	l,OP10
	in	a,(APUDATA)
	ld	(hl),a
	ld	l,OP11
	in	a,(APUDATA)
	ld	(hl),a
	ld	l,OP12
	in	a,(APUDATA)
	ld	(hl),a
	ret
	.end

#include "LLLFPL.asm"
