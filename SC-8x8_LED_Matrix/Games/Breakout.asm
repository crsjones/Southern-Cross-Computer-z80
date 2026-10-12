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
KEY_LEFT        .EQU  04H            ;key 4 = paddle left
KEY_RIGHT       .EQU  06H            ;key 6 = paddle right
KEY_SERVE       .EQU  05H            ;key 5 = launch the ball
START_LIVES     .EQU  3
START_SPEED     .EQU  500            ;display frames per ball step (bigger = slower)
MIN_SPEED       .EQU  150            ;fastest the ball gets
SPEED_STEP      .EQU  25             ;speed up by this much every 4 bricks
REP_RATE        .EQU  60             ;frames between paddle moves while a key is held
FLASH_TIME      .EQU  1000           ;display frames for the flash
RACK_BONUS      .EQU  5              ;points for clearing every brick

;
; Coordinates: x = 0..7 from the left (bit 7 of a row byte), y = 0..7 from the top.
; The paddle is 3 pixels wide on row 7, PADX = its leftmost pixel (0..5).
; Ball direction: DX = 00H/01H/FFH (0/+1/-1), DY = 01H (down) / FFH (up).
;
START
        JP    START1

MATRIX_BUF      .DS   8              ;8x8 display frame buffer (row 0..7)
SEGMENT_BUFFER  .DS   8              ;7-seg buffer (bytes 2..7 are the 6 visible digits)
ON_TIME         .DS   1              ;display on time delay
REP_CNT         .DS   1              ;key repeat counter (0 = ready to act)
PADX            .DS   1              ;paddle left pixel, 0..5
BX              .DS   1              ;ball x
BY              .DS   1              ;ball y
DX              .DS   1              ;ball x direction
DY              .DS   1              ;ball y direction
SERVING         .DS   1              ;non-zero while the ball sits on the paddle
LIVES           .DS   1
SCORE_LO        .DS   1              ;BCD score
SCORE_HI        .DS   1
HITS            .DS   1              ;bricks hit since the speed was last reset
BALL_DELAY      .DS   2              ;frames per ball step (current speed)
BALL_CNT        .DS   2              ;frames until the next ball step
BRICKS          .DS   8              ;brick rows, 0 = top, bit set = brick

START1
        LD    A,08H
        LD    (ON_TIME),A            ;display on time

;------------------------------------------------
; set up a new game
;------------------------------------------------
NEW_GAME
        CALL  CLEAR_DISPLAY
        LD    A,START_LIVES
        LD    (LIVES),A
        XOR   A
        LD    (SCORE_LO),A
        LD    (SCORE_HI),A
        LD    (HITS),A
        LD    (REP_CNT),A
        LD    A,02H
        LD    (PADX),A               ;paddle near the middle
        LD    HL,START_SPEED
        LD    (BALL_DELAY),HL
        CALL  NEW_RACK
        CALL  SERVE_SETUP
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

        LD    B,A                    ;key code is valid, DA is high
        LD    A,(REP_CNT)
        OR    A
        JR    Z,KEY_ACT              ;ready to act on the key
        DEC   A
        LD    (REP_CNT),A            ;held: count down to the next repeat
        JR    TIMER

KEY_ACT
        LD    A,REP_RATE
        LD    (REP_CNT),A
        LD    A,B
        AND   1FH                    ;key code
        CP    KEY_LEFT
        JR    Z,MOVE_LEFT
        CP    KEY_RIGHT
        JR    Z,MOVE_RIGHT
        CP    KEY_SERVE
        JP    Z,DO_SERVE
        JP    TIMER

NO_KEY
        XOR   A
        LD    (REP_CNT),A            ;released, the next press acts at once

TIMER
        LD    A,(SERVING)
        OR    A
        JP    NZ,GAME_LOOP           ;ball is waiting on the paddle

        LD    HL,(BALL_CNT)
        DEC   HL
        LD    (BALL_CNT),HL
        LD    A,H
        OR    L
        JP    NZ,GAME_LOOP           ;not time to move the ball yet

        LD    HL,(BALL_DELAY)
        LD    (BALL_CNT),HL          ;reload the counter
        CALL  BALL_STEP              ;carry set = ball missed the paddle
        JR    C,MISSED
        CALL  DRAW
        CALL  ALL_CLEAR
        JP    NZ,GAME_LOOP           ;bricks remain

;--- every brick gone: bonus, new rack
        LD    B,RACK_BONUS
BONUS1
        CALL  ADD_SCORE
        DJNZ  BONUS1
        CALL  UPDATE_SEG
        CALL  FLASH
        CALL  NEW_RACK
        CALL  SERVE_SETUP
        JP    GAME_LOOP

;--- ball missed the paddle
MISSED
        LD    A,(LIVES)
        DEC   A
        LD    (LIVES),A
        CALL  UPDATE_SEG
        CALL  FLASH
        LD    HL,START_SPEED
        LD    (BALL_DELAY),HL        ;back to the slowest speed
        XOR   A
        LD    (HITS),A
        LD    A,(LIVES)
        OR    A
        JR    Z,GAME_OVER
        CALL  SERVE_SETUP
        JP    GAME_LOOP

;--- paddle movement
MOVE_LEFT
        LD    A,(PADX)
        OR    A
        JP    Z,TIMER                ;already at left edge
        DEC   A
        LD    (PADX),A
        JR    AFTER_MOVE

MOVE_RIGHT
        LD    A,(PADX)
        CP    5
        JP    Z,TIMER                ;already at right edge
        INC   A
        LD    (PADX),A

AFTER_MOVE
        CALL  DRAW
        JP    TIMER

;--- launch the ball in a random diagonal
DO_SERVE
        LD    A,(SERVING)
        OR    A
        JP    Z,TIMER                ;already in play
        XOR   A
        LD    (SERVING),A
        CALL  RAND
        LD    A,L
        AND   1
        LD    A,1                    ;LD leaves the flags alone
        JR    NZ,SERVE_DX
        LD    A,0FFH
SERVE_DX
        LD    (DX),A
        JP    TIMER

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
; move the ball one step
;
; Rules (these were simulated against every brick pattern):
;   side wall : reverse DX and move inward, as in a normal bounce
;   ceiling   : reverse DY and stay in the top row for the step
;   brick     : remove it, reverse DY, the ball does not move
;   paddle    : (ball about to enter row 7) the part of the paddle it
;               lands on sets DX, the ball rebounds up to row 5
;
; exit : carry set = missed the paddle, carry clear = ball still in play
;------------------------------------------------
BALL_STEP
        LD    A,(BX)
        LD    B,A                    ;B = ball x
        LD    A,(DX)
        ADD   A,B                    ;A = next x
        CP    8
        JR    C,NX_OK                ;0..7 is inside the field
        LD    A,(DX)                 ;side wall: reverse and move inward
        NEG
        LD    (DX),A
        ADD   A,B                    ;next x = x + new DX
NX_OK
        LD    C,A                    ;C = next x

        LD    A,(BY)
        LD    D,A                    ;D = ball y
        LD    A,(DY)
        ADD   A,D                    ;A = next y
        CP    8
        JR    C,NY_OK                ;0..7 is inside the field
        LD    A,1                    ;ceiling: now heading down, stay in this row
        LD    (DY),A
        LD    A,D
NY_OK
        LD    E,A                    ;E = next y
        CP    7
        JR    Z,PADDLE_ROW           ;next step is the paddle row

;--- is there a brick at (C,E)?
        LD    HL,COLMASK
        LD    A,C
        ADD   A,L
        LD    L,A
        JR    NC,BK1
        INC   H
BK1
        LD    B,(HL)                 ;B = pixel mask for column C
        LD    HL,BRICKS
        LD    A,E
        ADD   A,L
        LD    L,A
        JR    NC,BK2
        INC   H
BK2
        LD    A,(HL)                 ;brick row
        AND   B
        JR    Z,MOVE_BALL            ;empty, so move there

        LD    A,B
        CPL
        AND   (HL)
        LD    (HL),A                 ;remove the brick
        LD    A,(DY)
        NEG
        LD    (DY),A                 ;bounce, the ball stays where it is
        CALL  BRICK_SCORE
        OR    A                      ;clear carry
        RET

MOVE_BALL
        LD    A,C
        LD    (BX),A
        LD    A,E
        LD    (BY),A
        OR    A                      ;clear carry
        RET

;--- ball is about to enter the paddle row at column C
PADDLE_ROW
        LD    A,(PADX)
        LD    B,A
        LD    A,C
        SUB   B
        INC   A                      ;A = column - PADX + 1
        CP    5
        JR    NC,MISS                ;0..4 is a catch, includes one pixel
                                     ;beyond each end; negatives wrap high
        LD    B,0FFH                 ;0,1 = left end: up and left
        CP    2
        JR    C,SET_DX
        LD    B,0                    ;2 = centre: straight up
        JR    Z,SET_DX
        LD    B,1                    ;3,4 = right end: up and right
SET_DX
        LD    A,B
        LD    (DX),A
        LD    A,0FFH
        LD    (DY),A                 ;now heading up
        LD    A,C
        LD    (BX),A
        LD    A,5
        LD    (BY),A                 ;rebound to row 5
        OR    A                      ;clear carry
        RET

MISS
        SCF
        RET

;------------------------------------------------
; a brick was hit: score it, speed up every 4th brick
;------------------------------------------------
BRICK_SCORE
        CALL  ADD_SCORE
        CALL  UPDATE_SEG
        LD    A,(HITS)
        INC   A
        LD    (HITS),A
        AND   3
        RET   NZ                     ;only on every 4th brick

        LD    HL,(BALL_DELAY)
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
        LD    (BALL_DELAY),HL
        RET

;------------------------------------------------
; put the ball on the paddle, waiting for the serve key
;------------------------------------------------
SERVE_SETUP
        LD    A,1
        LD    (SERVING),A
        LD    A,0FFH
        LD    (DY),A
        LD    A,6
        LD    (BY),A                 ;DRAW keeps BX centred on the paddle
        LD    HL,(BALL_DELAY)
        LD    (BALL_CNT),HL
        CALL  DRAW
        RET

;------------------------------------------------
; exit : Z = every brick gone
;------------------------------------------------
ALL_CLEAR
        LD    HL,BRICKS
        LD    B,8
        XOR   A
AC1
        OR    (HL)
        INC   HL
        DJNZ  AC1
        RET

NEW_RACK
        LD    HL,RACK
        LD    DE,BRICKS
        LD    BC,8
        LDIR
        RET

; the starting bricks, one byte per row (row 0 first).
; two rows is verified by simulation, 0FFH,0FFH,0FFH,0,0,0,0,0 is three rows
RACK
        .BYTE 0FFH,0FFH,00H,00H,00H,00H,00H,00H

; pixel mask for each column, x = 0 is the left (bit 7)
COLMASK
        .BYTE 80H,40H,20H,10H,08H,04H,02H,01H

;------------------------------------------------
; build the frame: bricks, paddle on row 7, ball
;------------------------------------------------
DRAW
        LD    A,(SERVING)
        OR    A
        JR    Z,DRAW1
        LD    A,(PADX)               ;ball rides in the middle of the paddle
        INC   A
        LD    (BX),A
DRAW1
        LD    HL,BRICKS
        LD    DE,MATRIX_BUF
        LD    BC,8
        LDIR

        LD    A,(PADX)               ;paddle mask = 0E0H shifted right PADX times
        LD    B,A
        INC   B
        LD    A,0E0H
DRAW2
        DEC   B
        JR    Z,DRAW3
        SRL   A
        JR    DRAW2
DRAW3
        LD    HL,MATRIX_BUF+7
        OR    (HL)
        LD    (HL),A

        LD    A,(BX)                 ;ball
        LD    HL,COLMASK
        ADD   A,L
        LD    L,A
        JR    NC,DRAW4
        INC   H
DRAW4
        LD    B,(HL)                 ;B = ball pixel mask
        LD    A,(BY)
        LD    HL,MATRIX_BUF
        ADD   A,L
        LD    L,A
        JR    NC,DRAW5
        INC   H
DRAW5
        LD    A,(HL)
        OR    B
        LD    (HL),A
        RET

;------------------------------------------------
; flash the whole matrix for a moment
;------------------------------------------------
FLASH
        LD    HL,MATRIX_BUF
        LD    B,8
FLASH1
        LD    (HL),0FFH
        INC   HL
        DJNZ  FLASH1
        LD    DE,FLASH_TIME
FLASH2
        CALL  DISPLAY_SCAN
        DEC   DE
        LD    A,D
        OR    E
        JR    NZ,FLASH2
        RET

;------------------------------------------------
; score + 1 (BCD)
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