;----------------------------------
; Southern Cross ALED - ARGB  board 
;----------------------------------
;
; Craig RS Jones	Dec 2024
;
; 'colorful' sequencer
; 
; this program outputs four colours, blue,red,yellow,green
; shifting the starting colour to the next colour in the list
; for each write to the ARGB string.

shifter	.equ	10h	;ALED board I/O Address

; the number of ARGB's. Less than 255, divisible by four.

LEDs	.equ	96	;number of WS2812B LEDs

	.org	2000h
;
; show a four colour re-circulating colour sequence on the LED strip
;
start
	ld	b,250
	call	msdelay

	ld	hl,seq1	;seq1=blue,red,yellow,green 
	call	show

	ld	b,250
	call	msdelay

	ld	hl,seq2	;seq2=red,yellow,green,blue
	call	show

	ld	b,250
	call	msdelay

	ld	hl,seq3	;seq3=yellow,green,blue,red
	call	show

	ld	b,250
	call	msdelay

	ld	hl,seq4	;seq4=green,blue,red,yellow
	call	show

	jp	start

;fill the strip with one sequence

show	
	ld	d,h
	ld	e,l	;save the sequence pointer
	ld	c,LEDs/4	;No. of leds / 4 LED pattern
show1
	ld	h,d
	ld	l,e	;restore the sequence pointer
	ld	b,4	;show the four colour sequence
show2
	ld	a,(hl)
	out	(shifter),a	;output green data
	inc	hl
	nop
	nop
	nop
	nop
	nop

	ld	a,(hl)
	out	(shifter),a	;output red data
	inc	hl
	nop
	nop
	nop
	nop
	nop

	ld	a,(hl)
	out	(shifter),a	;output blue data
	inc	hl
	nop
	nop
	nop
	nop
	nop
	djnz	show2	;output all four colours?
	dec	c
	jr	nz,show1	;end of the strip?
	call	ResetDelay	;finished the strip
	ret
;-----------------------
; end the light sequence
;-----------------------
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

;seq1=blue,red,yellow,green 
seq1
	.db	$0f,$00,$1a	; blue
;seq2=red,yellow,green,blue
seq2
	.db	$00,$20,$00	; red
	
;seq3=yellow,green,blue,red
seq3
	.db	$18,$1e,$00	; yellow
	
;seq4=green,blue,red,yellow
seq4
	.db	$1e,$00,$00	; green
	.db	$0f,$00,$1a	; blue
	.db	$00,$20,$00	; red
	.db	$18,$1e,$00	; yellow
	.end