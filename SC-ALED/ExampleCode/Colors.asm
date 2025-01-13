;---------------------------------------
; Southern Cross ALED WS2812B ARGB board 
;---------------------------------------
;
; Craig RS Jones Dec 2024
;
; steps through four colours on a single ARGB
;
shifter	.equ	10h	;ALED board I/O Address

	.org	2000h

	jp	init
green	.block	1
red	.block	1
blue	.block	1

;blue
init	ld	a,0fh
	ld	(green),a
	ld	a,00h
	ld	(red),a
	ld	a,1ah
	ld	(blue),a
	call	show
	call ResetDelay
	ld	b,1
	call	sdelay
	
;red
	ld	a,00h
	ld	(green),a
	ld	a,20h
	ld	(red),a
	ld	a,00h
	ld	(blue),a
	call	show
	call ResetDelay
	ld	b,1
	call	sdelay

;yellow
	ld	a,18h
	ld	(green),a
	ld	a,1eh
	ld	(red),a
	ld	a,00h
	ld	(blue),a
	call	show
	call ResetDelay
	ld	b,1
	call	sdelay

;green
	ld	a,1eh
	ld	(green),a
	ld	a,00h
	ld	(red),a
	ld	a,00h
	ld	(blue),a
	call	show
	call ResetDelay
	ld	b,1
	call	sdelay
	jp	init

;
; update the WS2812B
;
show
	ld	a,(green)
	out	(shifter),a	;output green data
	inc	hl
	nop
	nop
	nop
	nop
	nop

	ld	a,(red)
	out	(shifter),a	;output red data
	inc	hl
	nop
	nop
	nop
	nop
	nop

	ld	a,(blue)
	out	(shifter),a	;output blue data
	inc	hl
	nop
	nop
	nop
	nop
	nop
	call	ResetDelay	;no more data
	ret
;-----------------------
; end the light sequence
;-----------------------
ResetDelay
	ld	b,$10
ResetDelay1	nop
	djnz	ResetDelay1
	ret
;-------------
; second delay
;-------------
; one second delay
;
; entry : b = 1 to 255 seconds
; exit  : b = 0
;
sdelay
sdelay1	push	bc
	ld	b,10
sdelay2	push	bc
	ld	b,100
	call	msdelay
	pop	bc
	djnz	sdelay2
	pop	bc
	djnz	sdelay1
	ret

;------------------
; millisecond delay
;------------------
; approx. 1 millisecond delay
; 
; entry : b = 1 to 255 milliseconds
; exit  : b = 0
;
msdelay	push	bc	;11t
	ld	b,233	;7t
msdel1	nop	;4t
	djnz	msdel1	;nz=13t,z=8t
	pop	bc	;10t
	djnz	msdelay	;nz=13t,z=8t
	ret	;10t
	.end
