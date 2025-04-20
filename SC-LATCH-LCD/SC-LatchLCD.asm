#include "scm18_include.asm"
;
; 4 bit LCD Driver  seven segment display replacement/addition
;

;16 x 2 columns,rows
cols     .equ    16
rows     .equ    2
;20 x 4 columns,rows
;cols     .equ    20
;rows     .equ    4

;latch bitfield
RSEL     .equ    4     ;lcd register select bit
ECLK     .equ    5     ;lcd e clock bit
BLIGHT   .equ    6     ;lcd backlight control bit

; ascii codes
ESC     .equ   1bh
CR      .equ   0dh
LF      .equ   0ah

         .org  2000h

         jp    start

LCDPORT  .block  1      ;use this latch I/o address


test     .block  1
var1     .block  1
var2     .block  1
backlight .block 1     ;backlight state


start   call   LCDinit
        ld     b,2
        call   delae

        ld     a,80h
        ld     (MODE),a     ;start off in address mode
        ld     c,PCBTYP
        rst    30h          ;get the board type from the monitor
        call   LCDprint
        ld     hl,signon
        call   LCDprint
        ld     c,VERS
        rst    30h          ;get the monitor version
        call   LCDprint
;
; show the signon for 2 seconds
;
        ld     B,2
L1      ld     c,DELONE
        rst    30h
        djnz   L1
;
; clear the display and home the cursor
;
L3      call   LCDclear
        call   LCDhome
;
;put the address in the buffer
;
L2      ld     de,(ADDR)
        ld     hl,VARIDX     ;build up the row 1 display in this buffer
        ld     c,WRDASC
        rst    30h           ;convert the addr to ASCII into buffer
;
; display the address or data sign
;
        ld     a,(MODE)
        bit    7,a           ;ADDR or DATA mode?
        jp     z,L9          ;In ADDR mode
; DATA mode
        ld     a,'>'
        call   inbuf
        jp     L10
L9      ld     a,'<'
        call   inbuf
;
; put four bytes of data in
; the buffer starting at the displayed address
;
L10     ld     de,(ADDR)
        ld     a,(de)
        ld     c,BYTASC
        rst    30h
        call   spcbuf
        inc    de
        ld     a,(de)
        ld     c,BYTASC
        rst    30h
        call   spcbuf
        inc    de
        ld     a,(de)
        ld     c,BYTASC
        rst    30h
        call   spcbuf
        inc    de
        LD     a,(de)
        ld     c,BYTASC
        rst    30h
;
; the string is ready for the display
; put a zero terminator on it
;and put it on the display
;
        xor    a             ;terminate string
        ld     (hl),a
        ld     hl,VARIDX
        call   LCDprint      ;display string
;
; may as well send it out the serial port too...
;
        ld     hl,VARIDX
        ld     c,SNDMSG
        RST    30h
        call   txcrlf
;
;get a key
;
L5      ld     c,SCANKEY
        rst    30h
        bit    5,a
        jr     Z,L5        ;no key press
        and    1Fh         ;strip unused bits
        ld     hl,keytbl
        ld     c,MENU
        rst    30h
        ld     c,KEYREL
        rst    30h         ;wait for key release
        jp     L3
;
; main menu key table
;
keytbl  .db 20
    .db 00h,01h,02h,03h,04h,05h,06h,07h
    .db 08h,09h,0ah,0bh,0ch,0dh,0eh,0fh
    .db 10h,11h,12h,13h
    .dw hexkey,hexkey,hexkey,hexkey
    .dw hexkey,hexkey,hexkey,hexkey
    .dw hexkey,hexkey,hexkey,hexkey
    .dw hexkey,hexkey,hexkey,hexkey
    .dw funkey,addkey,inckey,deckey ;sc-1 keys  fn  ad  +  -
;
;handle hex key presses
;
hexkey
        ld     hl,MODE
        bit    7,(hl)      ;addr or data mode?
        jp     z,hexky2    ;in addr mode
; data mode
hexky1  ld     hl,(ADDR)
        sla   (hl)         ;from the current
        sla   (hl)         ;address,move the
        sla   (hl)         ;lsn to the msn.
        sla   (hl)         ;put the key in
        or    (hl)         ;the new data back at
        ld    (hl),a       ;the current address
        ret
; address mode
hexky2  ld     hl,(ADDR)
        sla    l           ;current address
        rl     h           ;and do a 16 bit
        sla    l           ;left shift 4 times
        rl     h           ;to make room
        sla    l           ;for the new key
        rl     h
        sla    l
        rl     h
        or     l           ;it in the least
        ld     l,a         ;significant nybble
        ld     (ADDR),hl   ;save current address
        ret
;
; function key handler
;
funkey  ret
;
; toggle addr/data mode
;
addkey  ld     a,(MODE)
        xor    80h         ;toggle mode
        ld     (MODE),a
        ret
;
; handle plus key
;
inckey  ld     hl,(ADDR)
        inc    hl
        ld     (ADDR),hl   ;increment the address
        ret
;
; handle minus key
;
deckey  ld     hl,(ADDR)
        dec    hl
        ld     (ADDR),hl
        ret
;
; put a space in the buffer
;
spcbuf  ld     a,' '
inbuf   ld     (hl),a
        inc    hl
        ret
;
; send CR,LF to serial port
;
txcrlf
    ld  a,CR
    ld  c,TXDATA
    rst  30h
    ld  a,LF
    ld  c,TXDATA
    rst  30h
    ret
;sign on message
signon  .db    " SCMON V",00H

;------------
;LCD routines
;------------
;basic functions
;LCDinit        initialise LCD*
;LCDclear       clear display*
;LCDhome        set cursor to top left*
;LCDsetCursor   set cursor to col,row
;LCDwrite       write a byte to the display*
;LCDprint       print a string on the display*
;LCDcursor      cursor on*
;LCDnoCursor    cursor off*
;LCDblink       blink cursor*
;LCDnoBlink     don't blink the cursor*
;LCDdisplay     turn on the display*
;LCDnoDisplay   turn off the display*
;LCDcreateChar  make a bitmapped character

LCDdisplay
        ld   a,0ch       ;turn on the display
        jr   cmd
LCDnoDisplay             ;turn off the display
        ld   a,08h
        jr   cmd
LCDblink                 ;blink the cursor
        ld   a,0fh
        jr   cmd
LCDnoBLink               ;don't blink the cursor
        ld   a,0eh
        jr   cmd
LCDnoCursor              ;turn off the cursor
        ld   a,0ch
        jr   cmd
LCDcursor                ;turn on the cursor
        ld   a,0eh
        jr   cmd
LCDclear                 ;clear the LCD
        ld   a,01h
        jr   cmd
LCDhome                  ;set the cursor to the top left position
        ld   a,02h
cmd     call writecmd
        ld   b,1
        call delae
        ret
;
; set cursor column,row
;
;map sequential display address to ddram address
;
;rows 0 to 3  (4)
;columns 0 to 19 (20)
;LCDsetCursor
;rowtbl   .db  00h,

;
; print a string on the LCD
;
LCDprint 
        ld    b,16
LCDpr1  ld    a,(hl)
        cp    00h         ;zero terminator, we are done.
        jr    z,LCDpr2 
        call  writedata
        inc   hl
        djnz  LCDpr1
LCDpr2  ret
;
; write a character
;
LCDwrite
        call   writedata
        ret
;
; backlight on
;
LCDblight
        xor   a
        set    BLIGHT,a
        ld     (backlight),a
        out    (IO3),a
        ret
;
; backlight off
;
LCDnoBlight
        xor    a
        ld     (backlight),a
        out    (IO3),a
        ret
;-------------------
; initialise the LCD
;-------------------
; initialise the LCD for a 4 bit interface
; this initialisation is based on 
; https://web.alfredstate.edu/faculty/weimandn/index.html
; refer to the "Initialization by instruction - 4-bit data interface" found here

LCDinit
       xor   a
       out   (IO3),a        ;make E low
       LD    b,100
       call  delae          ;initial 100ms power on delay
;
;special case of function set - lower four bits are not written
;
       ld    b,5            ;>4.1ms delay
       call  sfnset
;
;special case of function set - lower four bits are not written
;
       ld    b,1            ;> 100us delay
       call  sfnset
;
;special case of function set - lower four bits are not written
;
       ld    b,1            ;> 100us delay
       call  sfnset
;
; initial Function Set to change interface
;
       ld    b,1             ;>100us delay
       ld    a,02h           ;DL=0  4-bit data
       call  sfnseta         ;change interface to 4 bit
;
; now in four bit mode, write commands as two 4-bit nybbles
;
       ld    a,28h           ;Function Set N=1 2 rows, F=0 5x7 dots
       call  writecmd
       ld    b,1             ;>53us delay
       call  delae

       ld    a,08h           ;display switch D=0,C=0,B=0 
       call  writecmd
       ld    b,1
       call  delae

       ld    a,01h
       call  writecmd        ;clear display
       ld    b,3
       call  delae

       ld    a,06h           ;entry mode set I/D=1, S=1
       call  writecmd
       ld    b,1
       call  delae

       ld    a,0ch           ;display switch D=1,C=0,B=0
       call  writecmd
       ld    b,1
       call  delae
       ret
;
; ;special case of function set - lower four bits are not written 
;
sfnset  ld    a,03h
sfnseta set    ECLK,a
        out    (IO3),a        ;make E high 
        res    ECLK,a
        out    (IO3),a        ;make E low
        xor    a
        out    (IO3),a
        call   delae
        ret
;-------------------------------------------------
;write the command register in two four bit writes
;-------------------------------------------------
writecmd
       push   af
;
;write the high nybble
;
       and    0f0h          ;strip the low nybble
       rr     a
       rr     a
       rr     a
       rr     a           ;shift into the low nyblle to write
       set    ECLK,a      ;or     20h make E high
       out    (IO3),a
       res    ECLK,a      ;and    0dfh make E low
       out    (IO3),a
       xor    a
       out    (IO3),a
;
;write the low nybble
;
       pop    af
       and    0fh         ;strip the high nybble
       set    ECLK,a      ;or     20h make E high
       out    (IO3),a
       res    ECLK,a      ;and    0dfh make E low
       out    (IO3),a
       xor    a
       out    (IO3),a
       ret
;----------------------------------------------
;write the data register in two four bit writes
;----------------------------------------------
writedata
       push   af
;
;write the high nybble
;
       and    0f0h       ;strip the low nybble
       rr     a
       rr     a
       rr     a
       rr     a
       or     30h        ;make E and RS high to select data register
       out    (IO3),a    ;write the high nybble
       res    ECLK,a     ;make E low
       out    (IO3),a
       and    10h        ;make E low and keep RS high
       out    (IO3),a
;
;write the low nybble
;
       pop    af
       and    0fh        ;strip the high nybble
       or     30h        ;make E high and keep RS high
       out    (IO3),a    ;write the low nybble
       res    ECLK,a     ;make E low
       out    (IO3),a
       xor    a
       out    (IO3),a
       ret
;--------------------------
; approx. 1mS Delay @ 4MHz
;--------------------------
delae  push   bc           ;11t
       ld    b,233         ;7t
delae2 nop                 ;4t
       djnz  delae2        ;nz=13t,z=8t
       pop   bc            ;10t
       djnz  delae         ;nz=13t,z=8t
       ret                 ;10t
       .end