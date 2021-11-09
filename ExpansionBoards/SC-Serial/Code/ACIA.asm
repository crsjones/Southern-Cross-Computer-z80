;---------------------------
; Southern Cross 6850 Serial
;---------------------------
;
;  Craig Jones  August 2021
;  Version 1
;
; SC-Serial Add-on board for Southern Cross Z80 SBC 
;                           using  Southern Cross Monitor SCM V1.5 
; 
; $2000 blink
; The blink routine at $2000  toggles the RTS output of the 6850,
; connect a high efficiency LED and series 2k2 resistor between RTS and 5V to check that you have
; the board connected properly with the default IO address.
;
; $2030 connect the ACIA to the serial monitor
; substitute the ACIA transmit and receive routines for the bit banged serial routines in the serial monitor. 
;
; monitor V1.5 vectors
;
PUTCH   .EQU $3faa   ;output a serial character
GETCH   .EQU $3fac   ;get a serial character
RST38   .EQU $3ffa   ;interrupt vector
;
;monitor V1.5 entry points
;
WARM    .EQU $0f8c   ;serial monitor warm entry point
;
; 6850 ACIA registers
;----------------------
CONTROL         .EQU      $80   ;(write) 
STATUS          .EQU      $80   ;(read)
TDR             .EQU      $81   ;(write)
RDR             .EQU      $81   ;(read)
;
; control register bits
;----------------------
;
;clock divisor
;
MRESET  .EQU  $03        ;master reset the ACIA
DIV0    .EQU  $00        ;CLOCK/1
DIV16   .EQU  $01        ;CLOCK/16
DIV64   .EQU  $02        ;CLOCK/64
;
; format select
;
F7E2    .EQU   $00        ;7 data bits, EVEN parity, 2 stop bits (1+7+1+2= 11 bits)
F7O2    .EQU   $04        ;7 data bits, ODD parity, 2 stop bits (1+7+1+2= 11 bits)
F7E1    .EQU   $08        ;7 data bits, EVEN parity, 1 stop bit (1+7+1+1= 10 bits)
F7O1    .EQU   $0C        ;7 data bits, ODD parity, 1 stop bit (1+7+1+1= 10 bits)
F8N2    .EQU   $10        ;8 data bits, NO parity, 2 stop bits (1+8+0+2= 11 bits)
F8N1    .EQU   $14        ;8 data bits, NO parity, 1 stop bit (1+8+0+1= 10 bits)
F8E1    .EQU   $18        ;8 data bits, EVEN parity, 1 stop bit (1+8+1+1= 11 bits)
F8O1    .EQU   $1C        ;8 data bits, ODD parity,1 stop bit (1+8+1+1= 11 bits)
;
; transmitter control
;
RTSLID .EQU   $00        ;RTS LOW, transmit interrupt disabled
RTSLIE .EQU   $20        ;RTS LOW, transmit interrupt enabled
RTSHID .EQU   $40        ;RTS HIGH, transmit interrupt disabled
RTSLIDB .EQU  $60        ;RTS LOW, transmit interrupt disabled and 'break' transmitted
;
; receiver interrupt
;
RIE    .EQU   $80        ;receiver interrupt enabled
;
; status register bits
;---------------------
RDRF   .EQU   0          ;receive data register full
TDRE   .EQU   1          ;transmit data register empty
DCD    .EQU   2          ;data carrier detect
CTS    .EQU   3          ;clear to send
FE     .EQU   4          ;framing error
OVRN   .EQU   5          ;overrun
PE     .EQU   6          ;parity error
IRQ    .EQU   7          ;interrupt request
;
; blink
;-----------
; toggles the RTS output of the ACIA
      .org    $2000
blink: ld    a,MRESET
       out   (CONTROL),a           ;reset the ACIA
       ld    d,20
blink1: 
       ld   a,RTSLID               ;make RTS low to turn LED on
       out   (CONTROL),a
       ld    b,200
       call  delae
       ld     a,RTSHID             ;make RTS high to turn LED off
       out   (CONTROL),a
       ld    b,200
       call  delae
       dec   d
       jr    nz,blink1              ;done enough?
       jp    WARM                   ;exit to the serial monitor
;
; approx. b x 1mS delay @ 4MHz
;-----------------------------
delae       push   bc           ;11T
            ld    b,233         ;7T
delae1      nop                 ;4T
            djnz  delae1        ;NZ=13T,Z=8T
            pop   bc            ;10T
            djnz  delae         ;NZ=13T,Z=8T
            ret                 ;10T
;
; Connect the ACIA to the Serial Monitor
;----------------------------------------
;
; initialise the ACIA and use it instead of the bit banged serial routines for the 
; serial monitor.
;
       .org   $2030
start: ld    a,MRESET
       out   (CONTROL),a           ;reset the ACIA
       ld     a,RTSLID+F8N2+DIV64
       out   (CONTROL),a           ;initialise ACIA  8 bit word, No parity 2 stop divide by 64 for 115200 baud
;point to our new transmit routine
       ld    hl,TxChar
       ld    (PUTCH),hl
;point to our new receive routine
       ld    hl,RxChar
       ld    (GETCH),hl
; jump (back) into the serial monitor, the prompt '>' will be displayed on 
; the terminal connected to the ACIA, remember that the ACIA communicates at 115200! (with a 7.3728MHz crystal oscillator)
       jp    WARM
;
; transmit a character in a
;--------------------------
TxChar:  ld    b,a                   ;save the character  for later
TxChar1: in    a,(STATUS)            ;get the ACIA status 
         bit   TDRE,a                ;is the TDRE bit high?
         jr    z,TxChar1             ;no, the TDR is not empty
         ld    a,b                   ;yes, get the character
         out   (TDR),a               ;and put it in the TDR
         ret
;
; receive  a character in a
;---------------------------------
RxChar:  in    a,(STATUS)         ;get the ACIA status
         bit   RDRF,a             ;is the RDRF bit high?
         jr    z,RxChar           ;no, the RDR is empty
         in    a,(RDR)            ;yes, read the received char
         ret
       .end
