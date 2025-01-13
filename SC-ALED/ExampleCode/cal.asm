;-------------------------------------------
; Southern Cross ALED Addressable LED board 
;-------------------------------------------
;
; Craig RS Jones Dec 2024
;
; Calibrate output pulse widths
; 

shifter	.equ	10h	;ALED board I/O Address

	.org	2000h
;
; Set each LED to full brightness to 
; produce the colour white and output only
; the 'high' pulse width.
; adjust the P2 trimpot for white.
; you made need to turn the P1 trimpot down first!.
CalHiPulse

;first WS2812B data

	ld	a,0ffh
	out	(shifter),a	;output green data
	nop
	nop
	nop
	nop
	nop

	ld	a,0ffh
	out	(shifter),a	;output red data
	nop
	nop
	nop
	nop
	nop

	ld	a,0ffh
	out	(shifter),a	;output blue data
	nop
	nop
	nop
	nop
	nop

; If you have a CRO, look at the regenerated data
; coming out of the first ARGB
;
;second WS2812B data
;
	ld	a,0ffh
	out	(shifter),a	;output green data
	nop
	nop
	nop
	nop
	nop

	ld	a,0ffh
	out	(shifter),a	;output red data
	nop
	nop
	nop
	nop
	nop

	ld	a,0ffh
	out	(shifter),a	;output blue data
	nop
	nop
	nop
	nop
	nop

	call	ResetDelay
	jp		CalHiPulse

;
; set the green LED to full brightness and
; the red and blue off to produce mostly the
; 'low' pulse width.
; Adjust P1 for green.

	.org	2100h

CalLoPulse


;first WS2812 data


	ld	a,0ffh

	out	(shifter),a	;output green data
	nop
	nop
	nop
	nop
	nop
	ld	a,00h

	out	(shifter),a	;output red data
	nop
	nop
	nop
	nop
	nop
	ld	a,00h

	out	(shifter),a	;output blue data
	nop
	nop
	nop
	nop
	nop
; If you have a CRO, look at the regenerated data
; coming out of the first ARGB
;second WS2812B data

	ld	a,0ffh

	out	(shifter),a	;output green data
	nop
	nop
	nop
	nop
	nop
	ld	a,00h

	out	(shifter),a	;output red data
	nop
	nop
	nop
	nop
	nop
	ld	a,00h

	out	(shifter),a	;output blue data
	nop
	nop
	nop
	nop
	nop

	call	ResetDelay
	jp		CalLoPulse


	.org	2200h

; output 6 bytes 

onebyte
	ld	b,6
obyte1	ld	a,0aah
	out	(shifter),a	;output data
	nop
	nop
	nop
	nop
	djnz	obyte1

	call	ResetDelay

	ld	b,25
	call	msdelay
	jp	onebyte

; reset the light sequence

ResetDelay
	ld	b,$10
ResetDelay1	nop
	djnz	ResetDelay1
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
