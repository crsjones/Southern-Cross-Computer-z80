;----------------------------------------------
; S O U T H E R N   C R O S S   C O M P U T E R
;----------------------------------------------
;
; WRITTEN BY CRAIG JONES, MELBOURNE, AUSTRALIA
; 
;
; HEADER FILE - CONTAINS ALL MONITOR DEFINITIONS
; ==============================================

;-----------------
; SYSTEM VARIABLES
;-----------------
;RAMSRT  EQU     2000H   ;START OF USER RAM
;RAMEND  EQU     3BFFH   ;END OF USER RAM
;SYSTEM  EQU     3F00H   ;SYSTEM POINTER
;
; BAUD RATE CONSTANTS
;
;B300    EQU     0220H   ;300 BAUD
;B1200   EQU     0080H   ;1200 BAUD
;B2400   EQU     003FH   ;2400 BAUD
;B4800   EQU     001BH   ;4800 BAUD
;B9600   EQU     000BH   ;9600 BAUD
;
; I/O PORT ADDRESSES
;
;IO0     EQU     80H     ;IO PORT 0
;IO1     EQU     81H     ;IO PORT 1
;IO2     EQU     82H     ;IO PORT 2
;IO3     EQU     83H     ;IO PORT 3
DISPLY  EQU     84H     ;DISPLAY LATCH
SCAN    EQU     85H     ;DISPLAY SCAN LATCH
KEYBUF  EQU     86H     ;KEYBOARD BUFFER
IO7     EQU     87H     ;SPARE IO ADDRESS
;-------------------------
; MONITOR GLOBAL VARIABLES
;-------------------------
;SYSFLG	EQU	    3FB3H	;SYSTEM FLAGS BIT 0=KEYBOARD FLAG
;FUNTBL  EQU     3FB4H   ;FN TABLE ADDRESS
;
; DALLAS SMARTWATCH REGISTERS
;
;CALMDE  EQU     3FB6H   ;CALENDAR MODE
;SWREG0  EQU     3FB8H   ;10THS, 100THS
;SWREG1  EQU     3FB9H   ;SECONDS
;SWREG2  EQU     3FBAH   ;MINUTES
;SWREG3  EQU     3FBBH   ;HOURS
;SWREG4  EQU     3FBCH   ;DAY
;SWREG5  EQU     3FBDH   ;DATE
;SWREG6  EQU     3FBEH   ;MONTH
;SWREG7  EQU     3FBFH   ;YEAR
;
BAUD    EQU     3FC0H   ;BAUD RATE
;KEYTIM  EQU     3FC2H   ;BEEP DELAY
;SPTEMP  EQU     3FC4H   ;TEMP SYSTEM CALL SP
;
; BLOCK FUNCTIONS
;
;COUNT   EQU     3FC6H   ;NUMBER OF BYTES TO MOVE
;BLKSRT  EQU     3FC8H   ;BLOCK START ADDRESS
;BLKEND  EQU     3FCAH   ;BLOCK END ADDRESS
;BLKDST  EQU     3FCCH   ;DESTINATION ADDRESS
;
;FUNJMP  EQU     3FCEH   ;FN FN KEY JUMP ADDRESS
;
; DISPLAY SCAN REGISTERS
;
;DISBUF  EQU     3FD0H   ;DISPLAY BUFFER
;ONTIM   EQU     3FD6H   ;DISPLAY SCAN ON TIME
;OFTIM   EQU     3FD7H   ;DISPLAY SCAN OFF TIME
;
; MONITOR VARIABLES
;
;MODE    EQU     3FD8H   ;DISPLAY MODE
;ADRESS  EQU     3FDAH   ;USER ADDRESS
;KEYDEL  EQU     3FDCH   ;AUTO INCREMENT DELAY
;
; TEMPORARY REGISTER STORAGE
;
;REGPNT  EQU     3FDEH   ;REGISTER POINTER
PC_REG  EQU     3FE0H   ;PROGRAM COUNTER
AF_REG  EQU     3FE2H   ;ACCUMULATOR,FLAG
BC_REG  EQU     3FE4H   ;BC REGISTER PAIR
DE_REG  EQU     3FE6H   ;DE REGISTER PAIR
HL_REG  EQU     3FE8H   ;HL REGISTER PAIR
IX_REG  EQU     3FEAH   ;INDEX REGISTER X
IY_REG  EQU     3FECH   ;INDEX REGISTER Y
SP_REG  EQU     3FEEH   ;STACK POINTER
;
; RESTART JUMP TABLE AND HARWARE TEST
;
;RST08   EQU     3FF0H   ;RESTART 08H JUMP
;RST10   EQU     3FF2H   ;RESTART 10H JUMP
;RST18   EQU     3FF4H   ;RESTART 18H JUMP
;RST20   EQU     3FF6H   ;RESTART 20H JUMP
;RST28   EQU     3FF8H   ;RESTART 28H JUMP
RST38   EQU     3FFAH   ;INT INTERRUPT JUMP
;RST66   EQU     3FFCH   ;NMI INTERRUPT JUMP
;RAMSUM  EQU     3FFEH   ;USER RAM CHECKSUM
;DALLAS  EQU     3FFFH   ;RAM TEST LOCATION
;--------------------
; SYSTEM CALL NUMBERS
;--------------------
; 
; MONITOR 1.4 ADDED SCANKEY,INTELH 
;
;  LD   C,SYSTEM CALL NUMBER
;  RST  30H
;
MAIN    EQU     00H     ;RESTART MONITOR
;VERS    EQU     01H     ;GET MONITOR VERSION
;DISADD  EQU     02H     ;ADDRESS -> DISPLAY BUFFER
;DISBYT  EQU     03H     ;DATA -> DISPLAY BUFFER
;CLRBUF  EQU     04H     ;CLEAR DISPLAY BUFFER
;SCAND   EQU     05H     ;SCAN DISPLAY
;CONBYT  EQU     06H     ;BYTE -> DISPLAY CODE
;CONVHI  EQU     07H     ;HI NYBBLE -> DISPLAY CODE
;CONVLO  EQU     08H     ;LO NYBBLE - > DISPLAY CODE
;SKEYIN  EQU     09H     ;SCAN DISPLAY UNTIL KEY PRESS
;SKEYRL  EQU     0AH     ;SCAN DISPLAY UNTIL KEY RELEASE
;KEYIN   EQU     0BH     ;WAIT FOR KEY PRESS
;KEYREL  EQU     0CH     ;WAIT FOR KEY RELEASE
MENU    EQU     0DH     ;SELECT ENTRY FROM MENU
;CHKSUM  EQU     0EH     ;CALCULATE CHECKSUM
;MUL16   EQU     0FH     ;16 BIT MULTIPLY
;RAND    EQU     10H     ;GENERATE RANDOM NUMBER
;INDEXB  EQU     11H     ;INDEX INTO BYTE TABLE
;INDEXW  EQU     12H     ;INDEX INTO WORD TABLE
;MUSIC   EQU     13H     ;PLAY MUSIC TABLE
;TONE    EQU     14H     ;PLAY A NOTE
;BEEP    EQU     15H     ;KEY ENTRY BEEP
;SKATE   EQU     16H     ;SCAN 8X8 DISPLAY
TXDATA  EQU     17H     ;TRANSMIT SERIAL BYTE
RXDATA  EQU     18H     ;RECEIVE SERIAL BYTE
;ASCHEX  EQU     19H     ;ASCII CODE -> HEX
;WWATCH  EQU     1AH     ;WRITE TO SMART WATCH
;RWATCH  EQU     1BH     ;READ FROM SMART WATCH
;ONESEC  EQU     1CH     ;ONE SECOND DELAY USING SMARTWATCH
;RLSTEP  EQU     1DH     ;RELAY SEQUENCER
DELONE  EQU     1EH     ;ONE SECOND DELAY LOOP
;SCANKEY EQU     1FH     ;SCAN THE KEYBOARD
INTELH  EQU     20H     ;RECEIVE INTEL HEX FILE
;-------------------
; SOUTHERN CROSS BUG
;-------------------
; USES SCM 1.4  SYSTEM CALLS;
;
;MAIN
;MENU
;TXDATA
;RXDATA
;DELONE
;INTELH
;
; ASCII CODES
ESC    EQU   0x1B 
CR     EQU   0x0D
LF     EQU   0x0A
;
; RAM VARIABLES
;
;ISTACK  EQU    3C00H     ;SAVE THE INITIAL STACK POINTER    
;ADDR    EQU    3C02H     ;THE ADDRESS  
;DATA    EQU    3C04H     ;THE DATA
;MSGBUF  EQU    3C05H     ;THE STRING TO DISPLAY
;
; USE A BIT OF RAM AT THE TOP OF THE SC RAM
;
       ORG    3C00H
ISTACK .DS   2           ;SAVE THE INITIAL STACK POINTER    
ADDR   .DS   2           ;THE ADDRESS  
DATA   .DS   1           ;THE DATA
MSGBUF .DS   80          ;THE STRING TO DISPLAY
; 
;  WHERE DO WE WANT THE CODE TO RESIDE?
; 
       ORG   1000H       ;PUT IT AFTER THE MONITOR IN THE EEPROM
;        ORG    2800H     ;PUT IT IN SC RAM TO DEBUG IT

START  LD    A,0x40
       OUT   (SCAN),A    ;TURN OFF THE DISPLAY MAKE SERIAL TX HIGH
;
; START UP THE MONITOR
;          
COLD   LD    (ISTACK),SP ;SAVE STACK POINTER
       LD    HL,SSSTEP
       LD    (RST38),HL ;HIJACK THE SINGLE STEPPER
       LD    C,DELONE
       RST   0x30       ;WAIT A SEC SO THE HOST SEES TX HIGH   
       LD    HL,INITSZ  ;VT100 TERMINAL COMMANDS FOR CLEAR SCREEN,CURSOR HOME
       CALL  SNDMSG     ;INITIALISE THE TERMINAL
       LD    HL,SIGNON
       CALL  SNDMSG     ;SEND THE SIGNON
;
; DISPLAY THE PROMPT AND WAIT FOR COMMANDS
;
START2 LD    A,'>'
       CALL  OUTCH       ;DISPLAY THE PROMPT
START3 CALL  INCH        ;GET A CHARACTER FROM THE CONSOLE
;
; IF THE COMMAND IS NOT IN THE COMMAND LIST REJECT IT
;
       LD    HL,MONMENU 
       LD    B,(HL) ;NUMBER OF COMMANDS
       INC   HL
START4 CP    A,(HL)      ;IN THE LIST?
       JR    Z,START5    ;OK DO IT
       INC   HL
       DJNZ  START4      ;KEEP LOOKING
       JR    START3
START5 CALL  OUTCH       ;ECHO 
       LD    HL,MONMENU  ;USE THE MENU HANDLER 
       LD    C,MENU      ;KEY IN A, EXECUTE MENU
       RST   30H
;      
; THE MENU FUNCTION CALL LEAVES THE RETURN ADDRESS OF THE MENU CALL
; ON THE STACK SO ANY CALLED SUBROUTINES CAN COME BACK HERE WITH A RET.
;           
WARM   CALL  TXCRLF     ;START ON A NEW LINE
       JP    START2
;
; SCBUG MONITOR COMMANDS
;
MONMENU     .DB 6
            .DB 'D','T','M','G','I','X'

            .DW DSPLAY,SSTOGL,MODIFY
            .DW GOJUMP,INTEL,EXIT
;-----------------------------
; GET A BYTE FROM THE TERMINAL
;-----------------------------
GETBYT CALL  INCH
       CP    ESC
       JR    Z,GETOUT
       LD    B,A                ;SAVE TO ECHO      
       CALL  ASCHEX
       JR    NC,GETBYT          ;REJECT NON HEX CHARS    
       LD    HL,DATA
       LD    (HL),A 
       LD    A,B         
       CALL  OUTCH             ;ECHO VALID HEX
       
GETNYB CALL  INCH
       CP    ESC
       JR    Z,GETOUT
       LD    B,A               ;SAVE TO ECHO
       CALL  ASCHEX
       JR    NC,GETNYB         ;REJECT NON HEX CHARS
       RLD
       LD    A,B
       CALL  OUTCH             ;ECHO VALID HEX
       LD    A,(HL)
       CALL  GETOUT            ;MAKE SURE WE CLEAR THE CARRY BY SETTING IT,
       CCF                    ;AND THEN COMPLEMENTING IT
       RET   
GETOUT SCF                    ;SET THE CARRY FLAG TO EXIT BACK TO MENU
       RET
;---------------
; OUTPUT A SPACE
;---------------
OUTSP  LD    A,20H
       CALL  OUTCH
       RET
;-------------      
; OUTPUT CRLF
;------------
TXCRLF LD   A,CR
       CALL OUTCH   
       LD   A,LF
;-----------------------------------
; OUTPUT A CHARACTER TO THE TERMINAL
;-----------------------------------       
OUTCH  LD    C,TXDATA
       RST   30H
       RET
;------------------------------------
; INPUT A CHARACTER FROM THE TERMINAL
;------------------------------------
INCH   LD    C,RXDATA
       RST   30H
       RET
;------------------------------
; GO <ADDR>
; TRANSFERS EXECUTION TO <ADDR>
;------------------------------
GOJUMP CALL  OUTSP       
       CALL  GETBYT      ;GET ADDRESS HIGH BYTE
       RET   C
       LD    (ADDR+1),A  ;SAVE ADDRESS HIGH
       CALL  GETBYT      ;GET ADDRESS LOW BYTE
       RET   C
       LD    (ADDR),A    ;SAVE ADDRESS LOW 
;
; WAIT FOR A CR OR ESC
;       
GOJMP1 CALL  INCH
       CP    ESC         ;ESC KEY?
       RET   Z
       CP    CR
       JR    NZ,GOJMP1
       CALL  TXCRLF
       POP   HL          ;POP THE UNUSED MENU RETURN ADDRESS FROM THE STACK
       LD    HL,(ADDR)
       JP    (HL)        ;GOOD LUCK WITH THAT!
;-----------------------------------------------
; T COMMAND TOGGLE SINGLE STEPPER (IF INSTALLED)
;-----------------------------------------------
; CAN'T TELL IF THE SINGLE STEPPER IS ON OR OFF
; SO WE WILL JUST TOGGLE THE FLIP FLOP.
;
SSTOGL LD    HL,TOGGLE
       CALL  SNDMSG  
       OUT   (IO7),A               ;TOGGLE
       RET
;----------------------------
; M DISPLAY AND MODIFY MEMORY
;----------------------------
MODIFY CALL  OUTSP
;
;GET THE ADDRESS        
;
       CALL  GETBYT 
       RET   C        
       LD    (ADDR+1),A  ;SAVE ADDRESS HIGH
       CALL  GETBYT
       RET   C
       LD    (ADDR),A    ;SAVE ADDRESS LOW 
;
; DISPLAY ON A NEW LINE
;       
MDIFY1 CALL  TXCRLF       
       LD    DE,(ADDR)    
       LD    HL,MSGBUF   
       CALL  WRDASC      ;CONVERT ADDRESS IN DE TO ASCII
       LD    HL,MSGBUF
       CALL  WRDOUT      ;OUTPUT THE ADDRESS
       CALL  OUTSP    
;      
;GET THE DATA AT THE ADDRESS        
;
        LD   HL,(ADDR)       
        LD   A,(HL)
;
; DISPLAY THE DATA
;        
       LD    HL,MSGBUF
       CALL  BYTASC     ;CONVERT THE DATA BYTE IN A TO ASCII
       LD    HL,MSGBUF
       CALL  BYTOUT      ;OUTPUT THE BYTE
       CALL  OUTSP
;
; GET NEW DATA,EXIT OR CONTINUE
;
       CALL  GETBYT
       RET   C
       LD    B,A         ;SAVE IT FOR LATER
       LD    HL,(ADDR)
       LD    (HL),A      ;PUT THE BYTE AT THE CURRENT ADDRESS
       LD    A,B
       CP    (HL)
       JR    Z,MDIFY2
       LD    A,'?'
       CALL  OUTCH       ;NOT THE SAME DATA, PROBABLY NO RAM THERE      
;
; INCREMENT THE ADDRESS
;
MDIFY2 INC   HL
       LD    (ADDR),HL
       JP    MDIFY1      
;-----------------------
; RECEIVE INTEL HEX FILE
;-----------------------       
INTEL  LD    HL,TXFILE
       CALL  SNDMSG      ;SEND FILE
       LD    C,INTELH
       RST   30H
       JR    NZ,INTEL1       
       LD    HL,FILEOK
       CALL  SNDMSG      ;GOT FILE OK
       RET
INTEL1 LD    HL,CSUMERR
       CALL  SNDMSG      ;CHECKSUM ERROR
       RET    
;------------------------
; EXIT BACK TO SC MONITOR
;------------------------       
EXIT   LD    HL,BYE
       CALL  SNDMSG       
       LD    C,MAIN      ;STACK IS RESET TO TOP OF RAM IN MAIN   
       RST   30H           
;----------------------------------------
; CONVERT ASCII CHARACTER INTO HEX NYBBLE
;----------------------------------------
; THIS ROUTINE IS FOR MASKING OUT KEYBOARD
; ENTRY OTHER THAN HEXADECIMAL KEYS
;
;CONVERTS ASCII 0-9,A-F INTO HEX LSN
;ENTRY : A= ASCII 0-9,A-F
;EXIT  : CARRY =  1
;          A= HEX 0-F IN LSN    
;      : CARRY = 0
;          A= OUT OF RANGE CHARACTER & 0x7F
; A AND F REGISTERS MODIFIED
;
ASCHEX AND   0x7F        ;STRIP OUT PARITY
       CP    0x30
       JR    C,ACHEX3    ;LESS THAN 0
       CP    0x3A
       JR    NC,ACHEX2   ;MORE THAN 9
ACHEX1 SCF               ;SET THE CARRY - IS HEX
       RET
;     
ACHEX2 CP    0x41
       JR    C,ACHEX3    ;LESS THAN A
       CP    0x47
       JR    NC,ACHEX3   ;MORE THAN F
       SUB   0x07        ;CONVERT TO NYBBLE
       JR    ACHEX1  
ACHEX3 AND   0xFF        ;RESET THE CARRY - NOT HEX
       RET
;--------------------------
; D DISPLAY MEMORY LOCATION
;--------------------------
DSPLAY CALL  OUTSP       ;A SPACE
       CALL  GETBYT
       RET   C         
       LD    (ADDR+1),A  ;SAVE ADDRESS HIGH
       CALL  GETBYT
       RET   C
       LD    (ADDR),A    ;SAVE ADDRESS LOW 
;
; WAIT FOR CR OR ESC
;
DPLAY1 CALL  INCH
       CP    ESC
       RET   Z
       CP    CR
       JR    NZ,DPLAY1          
       CALL  TXCRLF      ;NEWLINE
;
; DISPLAY THE LINE
;
DPLAY2 CALL  DPLINE
       LD    (ADDR),DE   ;SAVE THE NEW ADDRESS
;
; DISPLAY MORE LINES OR EXIT
;       
DPLAY3 CALL  INCH
       JR    C,DPLAY3   
       CP    0x20        ;SPACE DISPLAYS THE NEXT LINE
       JR    Z,DPLAY2
       CP    ESC         ;ESC EXITS
       JR    NZ,DPLAY3     
       RET   
;-------------------------
; DISPLAY A LINE OF MEMORY
;-------------------------      
DPLINE LD    DE,(ADDR)   ;ADDRESS TO BE DISPLAYED
       LD    HL,MSGBUF   ;HL POINTS TO WHERE THE OUTPUT STRING GOES
;
; DISPLAY THE ADDRESS
;         
       CALL  WRDASC     ;CONVERT ADDRESS IN DE TO ASCII
       CALL  SPCBUF        
;
; DISPLAY 16 BYTES
;
       LD    B,16
DLINE1 LD    A,(DE)
       CALL  BYTASC
       CALL  SPCBUF
       INC   DE        
       DJNZ  DLINE1
       CALL  SPCBUF
;
; NOW DISPLAY THE ASCII CHARACTER
; IF YOU ARE DISPLAYING NON-MEMORY AREAS THE BYTES READ AND THE ASCII COULD
; BE DIFFERENT BETWEEN THE TWO PASSES!
;
       LD    DE,(ADDR)    
       LD    B,16
DLINE2 LD    A,(DE)   
       CP    0x20
       JR    C,DOT
       CP    0x7F
       JR    NC,DOT
       JP    NDOT
DOT    LD    A,'.'
NDOT   CALL  INBUF
       INC   DE       
       DJNZ  DLINE2
;         
;TERMINATE AND DISPLAY STRING
;       
       CALL  BCRLF
       LD    A,0x00
       LD    (HL),A
       LD    HL,MSGBUF
       CALL  SNDMSG
       RET
;
; PUT A SPACE IN THE BUFFER
;
SPCBUF LD    A,0x20
INBUF  LD    (HL),A
       INC   HL
       RET
;
; PUT A CR LF IN THE BUFFER
;        
BCRLF  LD    A,CR  
       CALL  INBUF
       LD    A,LF
       CALL  INBUF
       RET
;----------------------     
; SEND ASCII HEX VALUES        
;----------------------
;
; OUTPUT THE 4 BYTE, WRDOUT
; THE 2 BYTE, BYTOUT
; OR THE SINGLE BYTE, NYBOUT
; ASCII STRING AT HL TO THE SERIAL PORT
;
WRDOUT CALL  BYTOUT
BYTOUT CALL  NYBOUT
NYBOUT LD    A,(HL)
       CALL  OUTCH
       INC   HL
       RET       
;----------------
;CONVERT TO ASCII 
;----------------
;
; CONVERT A WORD,A BYTE OR A NYBBLE TO ASCII
;
;         ENTRY :  A = BINARY TO CONVERT
;                  HL = CHARACTER BUFFER ADDRESS   
;        EXIT   :  HL = POINTS TO LAST CHARACTER+1
;   
;        MODIFIES : DE

WRDASC LD    A,D         ;CONVERT AND
       CALL  BYTASC      ;OUTPUT D
       LD    A,E         ;THEN E
;
;CONVERT A BYTE TO ASCII 
;
BYTASC PUSH  AF          ;SAVE A FOR SECOND NYBBLE 
       RRCA              ;SHIFT HIGH NYBBLE ACROSS
       RRCA
       RRCA
       RRCA
       CALL NYBASC       ;CALL NYBBLE CONVERTER 
       POP AF            ;RESTORE LOW NYBBLE
;           
; CONVERT A NYBBLE TO ASCII
;
NYBASC AND   0FH         ;MASK OFF HIGH NYBBLE 
       ADD   A,90H       ;CONVERT TO
       DAA               ;ASCII
       ADC   A,40H
       DAA
;            
; SAVE IN STRING
;
INSBUF LD    (HL),A
       INC   HL 
       RET 
;------------------------------------------------------
; CONVERT A BYTE INTO A STRING OF ASCII ONES AND ZEROES
;------------------------------------------------------
;       
;        DESCRIPTION : CONVERTS A BYTE, STARTING AT BIT 7,
;                      INTO A STRING OF ASCII
;                      ONES AND ZEROES.
;
;           ENTRY :  A = BINARY TO CONVERT
;                   HL = CHARACTER BUFFER ADDRESS   
;           EXIT :  HL = POINTS TO LAST CHARACTER+1
;   
;        MODIFIES : NONE
;
;
BITASC PUSH  BC
       LD    B,08H       ;LOOK AT ALL 8 BITS
BTASC1 BIT   7,A         ;A 1 OR A 0?
       JR    NZ,BTASC3
       LD    C,30H       ;IT'S A ZERO
BTASC2 LD    (HL),C
       JR    BTASC4
            
BTASC3 LD    C,31H       ;IT'S A ONE
       LD    (HL),C
            
BTASC4 INC   HL
       RLA
       DJNZ  BTASC1      ;NEXT BIT
       POP   BC
       RET
;-----------------------------------------
; SEND AN ASCII STRING OUT THE SERIAL PORT
;-----------------------------------------
; 
; SENDS A ZERO TERMINATED STRING OR 
; 80 CHARACTERS MAX. OUT THE SERIAL PORT
;
;      ENTRY : HL = POINTER TO 0x00 TERMINATED STRING
;      EXIT  : NONE
;
;       MODIFIES : A,B,C
;          
SNDMSG LD    B,80
SDMSG1 LD    A,(HL)
       CP    0x00
       JR    Z,SDMSG2   
       CALL  OUTCH
       INC   HL
       DJNZ  SDMSG1       
SDMSG2 RET
;----------------------
; SERIAL SINGLE STEPPER
;----------------------
SSSTEP POP   HL          ;GET HL BACK
       PUSH  AF          ;SAVE AF FOR LATER  
       LD    (HL_REG),HL
       LD    (DE_REG),DE
       LD    (BC_REG),BC
       LD    (IX_REG),IX
       LD    (IY_REG),IY ;SAVE REGISTERS
       POP   HL          ;GET AF BACK
       LD    (AF_REG),HL ;SAVE AF
       POP   HL          ;GET PC RETURN ADDRESS
       LD    (PC_REG),HL ;SAVE PC
       LD    (SP_REG),SP ;SAVE STACK POINTER
;            
;DISPLAY THE REGISTERS HEADING          
;          
       LD    HL,REGS
       CALL  SNDMSG
;
; DISPLAY THE REGISTERS
;            
       LD	 B,08H
       LD    HL,MSGBUF
       LD    IX,PC_REG
DISREG LD    A,(IX+1)
       CALL  BYTASC
       LD    A,(IX+0)
       CALL  BYTASC
       INC   IX
       INC   IX
       LD    A,' '
       LD    (HL),A
       INC   HL
       DJNZ  DISREG       
;
; DISPLAY THE FLAGS 
;          
       LD    A,(AF_REG)  ;GET THE FLAGS AND      
       CALL  BITASC      ;SHOW THEM AS BITS 

SZCRLF CALL  BCRLF
       LD    A,0x00
       LD    (HL),A      ;TERMINATE THE STRING
;        
; DISPLAY THE REGISTERS
;        
       LD    HL,MSGBUF
       CALL  SNDMSG
;
; SPACE KEY CONTINUES
;
LOOP1  CALL  INCH
       JR    C,LOOP1      
       CP    0x20        ;IS IT SPACE
       JR    Z,RETPGM
       CP    ESC         ;ESC QUITS
       JR    NZ,LOOP1
;       
; RETURN TO MONITOR
; 
       LD    SP,(ISTACK) ;RESTORE THE STACK POINTER
       EI                ;RE-ENABLE INTERRUPTS      
       JP    WARM        ;EXIT THE INTERRUPT ROUTINE
;
; RETURN TO PROGRAM
;
RETPGM LD    SP,(SP_REG) ;PUT STACK POINTER BACK
       LD    HL,(PC_REG) ;PUT RETURN
       PUSH  HL          ;ADDRESS BACK ON STACK
       LD    HL,(AF_REG)
       PUSH  HL          ;SAVE AF REG FOR LATER
       LD    IY,(IY_REG)
       LD    IX,(IX_REG)
       LD    BC,(BC_REG)
       LD    DE,(DE_REG) ;RESTORE REGISTERS
       POP   AF          ;RESTORE AF
       LD    HL,(HL_REG) ;RESTORE HL
       EI                ;RE-ENABLE INTERRUPTS
       RET               ;AND RETURN TO PROGRAM  
;
; STRING CONSTANTS
;
CRLF        .DB     CR,LF,0x00
SIGNON      .DB     "SCBUG 1.0",CR,LF,0x00
REGS        .DB     CR,LF,"PC   AF   BC   DE   HL   IX   IY   SP   SZ-H-VNC",CR,LF,0x00
TOGGLE      .DB     CR,LF,"SINGLE STEP TOGGLE",CR,LF,0x00
TXFILE      .DB     CR,LF,"SEND INTEL HEX FILE...",0x00
FILEOK      .DB     CR,LF,"FILE RECEIVED OK",CR,LF,0x00
CSUMERR     .DB     CR,LF,"CHECKSUM ERROR",CR,LF,0x00
BYE         .DB     CR,LF,"BYE...",CR,LF,0x00
;
;VT100 TERMINAL COMMANDS FOR CLEAR SCREEN,CURSOR HOME
;
INITSZ      .DB     27,"[H",27,"[2J",0x00
            END









