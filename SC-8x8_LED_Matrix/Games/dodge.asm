        .ORG  2000H

;------------------------------------------------
; I/O port addresses
;------------------------------------------------
IO0     .EQU  80H            ;IO port 0
IO1     .EQU  81H            ;IO port 1
IO2     .EQU  82H            ;IO port 2
IO3     .EQU  83H            ;IO port 3
DISPLY  .EQU  84H            ;display latch
SCAN    .EQU  85H            ;display scan latch
KEYBUF  .EQU  86H            ;keyboard buffer
IO7     .EQU  87H            ;spare IO address

;------------------------------------------------
; tunables
;------------------------------------------------
KEY_LEFT        .EQU  04H            ;key 4 = move left
KEY_RIGHT       .EQU  06H            ;key 6 = move right
START_LIVES     .EQU  3
START_SPEED     .EQU  900            ;display frames between falls (bigger = slower)
MIN_SPEED       .EQU  300            ;fastest the game gets
SPEED_STEP      .EQU  30             ;speed up by this much every 10 points
FLASH_TIME      .EQU  1000           ;display frames the hit flash lasts

START
        JP    START1

MATRIX_BUF      .DS   8              ;8x8 display frame buffer (row 0..7)
SEGMENT_BUFFER  .DS   8              ;7-seg buffer (bytes 2..7 are the 6 visible digits)
ON_TIME         .DS   1              ;display on time delay
KEY_DOWN        .DS   1              ;non-zero while a key is being held
PLAYER          .DS   1              ;player pixel mask in row 7 (80H = left, 01H = right)
LIVES           .DS   1
SCORE_LO        .DS   1              ;BCD score
SCORE_HI        .DS   1
FALL_DELAY      .DS   2              ;frames per fall step (current speed)
FALL_CNT        .DS   2              ;frames until the next fall step
SPAWN_TOG       .DS   1              ;alternates so every second row is blank
OBST            .DS   8              ;obstacle rows, 0 = top, 7 = player row

START1
        LD    A,08H
        LD    (ON_TIME),A            ;display on time

;------------------------------------------------
; set up a new game
;------------------------------------------------
NEW_GAME
        CALL  CLEAR_DISPLAY
        CALL  CLEAR_OBST
        LD    A,START_LIVES
        LD    (LIVES),A
        XOR   A
        LD    (SCORE_LO),A
        LD    (SCORE_HI),A
        LD    (SPAWN_TOG),A
        LD    (KEY_DOWN),A
        LD    A,10H                  ;start near the middle
        LD    (PLAYER),A
        LD    HL,START_SPEED
        LD    (FALL_DELAY),HL
        LD    (FALL_CNT),HL
        CALL  DRAW
        CALL  UPDATE_SEG

;------------------------------------------------
; main game loop, one pass = one display refresh
;------------------------------------------------
GAME_LOOP
        CALL  DISPLAY_SCAN

        IN    A,(KEYBUF)             ;read hardware encoder
        AND   3FH                    ;strip unused bits
        BIT   5,A                    ;DA high = key pressed
        JR    Z,NO_KEY

        LD    B,A
        LD    A,(KEY_DOWN)
        OR    A
        JR    NZ,TIMER               ;same press still held, ignore
        LD    A,1
        LD    (KEY_DOWN),A           ;new press

        LD    A,B
        AND   1FH                    ;key code
        CP    KEY_LEFT
        JR    Z,MOVE_LEFT
        CP    KEY_RIGHT
        JR    Z,MOVE_RIGHT
        JR    TIMER

NO_KEY
        XOR   A
        LD    (KEY_DOWN),A           ;released, arm for the next press

TIMER
        LD    HL,(FALL_CNT)
        DEC   HL
        LD    (FALL_CNT),HL
        LD    A,H
        OR    L
        JP    NZ,GAME_LOOP           ;not time to fall yet

;--- fall step
        LD    HL,(FALL_DELAY)
        LD    (FALL_CNT),HL          ;reload the counter
        CALL  STEP                   ;scroll obstacles down, add new row
        CALL  DRAW
        CALL  CHECK_HIT
        JP    NZ,DO_HIT
        CALL  ADD_SCORE              ;survived a step
        CALL  UPDATE_SEG
        JP    GAME_LOOP

;--- player movement
MOVE_LEFT
        LD    A,(PLAYER)
        CP    80H
        JR    Z,TIMER                ;already at left edge
        RLCA
        LD    (PLAYER),A
        JR    AFTER_MOVE

MOVE_RIGHT
        LD    A,(PLAYER)
        CP    01H
        JR    Z,TIMER                ;already at right edge
        RRCA
        LD    (PLAYER),A

AFTER_MOVE
        CALL  DRAW
        CALL  CHECK_HIT              ;stepping into an obstacle counts
        JP    NZ,DO_HIT
        JR    TIMER

;------------------------------------------------
; lose a life, flash the display, restart the field
;------------------------------------------------
DO_HIT
        LD    A,(LIVES)
        DEC   A
        LD    (LIVES),A
        CALL  UPDATE_SEG

        LD    HL,MATRIX_BUF          ;fill the matrix
        LD    B,8
FLASH_FILL
        LD    (HL),0FFH
        INC   HL
        DJNZ  FLASH_FILL

        LD    DE,FLASH_TIME
FLASH_LOOP
        CALL  DISPLAY_SCAN
        DEC   DE
        LD    A,D
        OR    E
        JR    NZ,FLASH_LOOP

        CALL  CLEAR_OBST
        LD    HL,START_SPEED
        LD    (FALL_DELAY),HL        ;back to the slowest speed
        LD    (FALL_CNT),HL
        CALL  DRAW
        LD    A,(LIVES)
        OR    A
        JP    NZ,GAME_LOOP

;------------------------------------------------
; game over: show a cross, wait for any key
;------------------------------------------------
GAME_OVER
        LD    HL,CROSS
        LD    DE,MATRIX_BUF
        LD    BC,8
        LDIR
WAIT_REL
        CALL  DISPLAY_SCAN           ;wait for key release first
        IN    A,(KEYBUF)
        BIT   5,A
        JR    NZ,WAIT_REL
WAIT_PRESS
        CALL  DISPLAY_SCAN
        IN    A,(KEYBUF)
        BIT   5,A
        JR    Z,WAIT_PRESS
        JP    NEW_GAME

CROSS
        .BYTE 81H,42H,24H,18H,18H,24H,42H,81H

;------------------------------------------------
; scroll obstacles down one row and add a new top row
; every second new row is blank so there is always room to dodge
;------------------------------------------------
STEP
        LD    HL,OBST+6
        LD    DE,OBST+7
        LD    BC,7
        LDDR                         ;rows 6..0 move to 7..1

        LD    A,(SPAWN_TOG)
        XOR   1
        LD    (SPAWN_TOG),A
        JR    Z,BLANK_ROW

        CALL  RAND                   ;HL = random word
        LD    A,L
        AND   H                      ;~25% of pixels set
        LD    (OBST),A
        RET
BLANK_ROW
        XOR   A
        LD    (OBST),A
        RET

;------------------------------------------------
; exit : Z = no collision, NZ = player hit
;------------------------------------------------
CHECK_HIT
        LD    A,(OBST+7)
        LD    B,A
        LD    A,(PLAYER)
        AND   B
        RET

;------------------------------------------------
; build the frame: obstacles plus player on row 7
;------------------------------------------------
DRAW
        LD    HL,OBST
        LD    DE,MATRIX_BUF
        LD    BC,8
        LDIR
        LD    A,(MATRIX_BUF+7)
        LD    HL,PLAYER
        OR    (HL)
        LD    (MATRIX_BUF+7),A
        RET

CLEAR_OBST
        LD    HL,OBST
        LD    B,8
        XOR   A
CO1
        LD    (HL),A
        INC   HL
        DJNZ  CO1
        RET

;------------------------------------------------
; score + 1 (BCD). Every 10 points the game speeds up
;------------------------------------------------
ADD_SCORE
        LD    A,(SCORE_LO)
        ADD   A,1
        DAA
        LD    (SCORE_LO),A
        LD    A,(SCORE_HI)
        ADC   A,0
        DAA
        LD    (SCORE_HI),A

        LD    A,(SCORE_LO)
        AND   0FH
        RET   NZ                     ;only on multiples of 10

        LD    HL,(FALL_DELAY)
        LD    DE,SPEED_STEP
        OR    A
        SBC   HL,DE                  ;faster
        LD    DE,MIN_SPEED
        PUSH  HL
        OR    A
        SBC   HL,DE
        POP   HL                     ;POP leaves the carry alone
        JR    NC,SPEED_OK
        LD    HL,MIN_SPEED           ;clamp
SPEED_OK
        LD    (FALL_DELAY),HL
        RET

;------------------------------------------------
; lives on digit 2, score on digits 4..7
;------------------------------------------------
UPDATE_SEG
        LD    A,(LIVES)
        CALL  CONVERT_TO_7SEG
        LD    (SEGMENT_BUFFER+2),A
        LD    BC,SEGMENT_BUFFER+4
        LD    A,(SCORE_HI)
        CALL  BCD_TO_SEG
        LD    A,(SCORE_LO)
        CALL  BCD_TO_SEG
        RET

; entry : A = BCD byte, BC -> segment buffer, BC advanced by 2 on exit
BCD_TO_SEG
        PUSH  AF
        RRCA
        RRCA
        RRCA
        RRCA
        AND   0FH
        CALL  CONVERT_TO_7SEG
        LD    (BC),A
        INC   BC
        POP   AF
        AND   0FH
        CALL  CONVERT_TO_7SEG
        LD    (BC),A
        INC   BC
        RET

;------------------------------------
; scan the 7 segment and 8x8 displays
;------------------------------------
DISPLAY_SCAN
        PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    HL,SEGMENT_BUFFER
        LD    DE,MATRIX_BUF
        LD    C,80H                  ;step through the displays

DISPLAY_SCAN1
        LD    A,(HL)
        OUT   (DISPLY),A             ;latch the 7 segment anode data
        LD    A,(DE)
        OUT   (IO0),A                ;latch the 8x8 X data
        LD    A,C
        OUT   (IO2),A                ;latch the 8x8 scan Y data
        AND   3FH                    ;ignore the top two displays
        OR    40H                    ;keep the serial output high
        OUT   (SCAN),A               ;latch the 7 segment cathode data

        LD    A,(ON_TIME)
        LD    B,A
DISPLAY_SCAN2
        DJNZ  DISPLAY_SCAN2          ;keep the display on a little

        XOR   A
        OUT   (IO2),A                ;turn off the 8x8
        OR    40H
        OUT   (SCAN),A               ;turn off the 7-segment, except serial output

        INC   HL                     ;next seven segment display
        INC   DE                     ;next 8x8 row
        RRC   C                      ;next column
        JR    NC,DISPLAY_SCAN1

        POP   HL
        POP   DE
        POP   BC
        POP   AF
        RET

;
; clear both display buffers (16 bytes, they are contiguous)
;
CLEAR_DISPLAY
        PUSH  HL
        PUSH  BC
        LD    HL,MATRIX_BUF
        LD    B,16
CLR1
        LD    (HL),00H
        INC   HL
        DJNZ  CLR1
        POP   BC
        POP   HL
        RET

;
; convert A (LSN) to 7 segment code
;
CONVERT_TO_7SEG
        LD    E,A
        LD    D,0
        LD    HL,SEGMENT_TABLE
        ADD   HL,DE
        LD    A,(HL)
        RET

; SEGMENTS a=b0,b=b1,c=b2,d=b3,e=b4,f=b5,g=b6,dp=b7
SEGMENT_TABLE
        .BYTE 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H
        .BYTE 7FH, 6FH, 77H, 7CH, 39H, 5EH, 79H, 71H

;-------------------------------
; GENERATE A QUASI-RANDOM NUMBER
;-------------------------------
; generate an 16 bit random number
; using linear congruential method.
;
;     Rn+1 = (aRn+c) MOD m
;
; refresh register used for Rn and c
;   entry : none
;   exit  : HL = random word
;   no registers modified
;
RAND    PUSH  AF
        PUSH  BC
        PUSH  DE             ;save registers
;
; calculate aRn
;
        LD    A,R            ;get a random seed from the refresh register
        LD    E,A            ;multiply random number
        LD    D,0            ;(rn) by
        LD    HL,0548H       ;constant (a)
        CALL  MUL16
;
; calculate aRn+c
;
        LD    A,R            ;add it to another
        LD    B,0            ;read of the
        LD    C,A            ;the refresh
        ADD   HL,BC          ;register (c)
        POP   DE
        POP   BC
        POP   AF             ;restore registers
        RET

;----------------------
; 16 BIT MULTIPLICATION
;----------------------
; 16 bit multiply
;  entry : HL = multiplicand (mpd)
;          DE = multiplier (mpr)
;  exit  : HL = result
; from Zaks 'Programming the Z80'
;
MUL16   PUSH  AF
        PUSH  BC
        LD    C,H            ;mpr(H)
        LD    A,L            ;mpr(L)
        LD    B,16           ;bit counter
        LD    HL,0           ;clear result
MULT    SRL   C              ;mpr (H)
        RRA                  ;mpr (L)
        JR    NC,MULT1       ;test carry
        ADD   HL,DE          ;add mpd to result
MULT1   EX    DE,HL
        ADD   HL,HL          ;double -shift mpd left
        EX    DE,HL
        DJNZ  MULT           ;done?
        POP   BC
        POP   AF
        RET

        .END