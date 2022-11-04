;------------------------------------------------
; Southern Cross Monitor version 1.7 demo program
;------------------------------------------------
;
#include "SCM17_Include.asm"

	.org	2000H

count	ld	c,CLRBUF	;clear the display buffer
	rst	30h

	ld	hl,0000h	;clear the counter
;
count1	ld	c,DISADD	;convert hl to 7 segment code
	rst 30h		;and put in display buffer
;scan the display b times
	ld	b,0ffh
loop	ld	c,SCAND	;scan the display
	rst	30h
	djnz	loop
; increment the count and display again
	inc	hl
	jr	count1
	.end
