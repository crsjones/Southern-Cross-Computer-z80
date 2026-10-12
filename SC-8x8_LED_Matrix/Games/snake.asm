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
KEY_UP          .EQU  01H            ;direction keys, a diamond around key 5
KEY_DOWN        .EQU  09H
KEY_LEFT        .EQU  04H
KEY_RIGHT       .EQU  06H
START_LIVES     .EQU  3
START_SPEED     .EQU  700            ;display frames per move (bigger = slower)
MIN_SPEED       .EQU  200            ;fastest the snake gets
SPEED_STEP      .EQU  20             ;speed up by this much for every food eaten
BLINK_RATE      .EQU  400            ;display frames between food blinks
FLASH_TIME      .EQU  1000           ;display frames for the flash
NOKEY           .EQU  0FFH           ;marks an empty slot in the key queue

;
; A cell is a single byte, y*8+x, where x = 0..7 from the left (bit 7 of a
; row byte) and y = 0..7 from the top.
; Directions: 0 = up, 1 = right, 2 = down, 3 = left (XOR 2 = the opposite)
;
START
        JP    START1

MATRIX_BUF      .DS   8              ;8x8 display frame buffer (row 0..7)
SEGMENT_BUFFER  .DS   8              ;7-seg buffer (bytes 2..7 are the 6 visible digits)
ON_TIME         .DS   1              ;display on time delay
LAST_KEY        .DS   1              ;key seen on the last pass, 0 = none held
CUR_DIR         .DS   1              ;direction of the last move
KEYQ0           .DS   1              ;next queued turn (NOKEY = empty)
KEYQ1           .DS   1              ;the one after that
STARTED         .DS   1              ;0 = waiting for the first key press
HEAD            .DS   1              ;index of the head in SNAKE
TAIL            .DS   1              ;index of the tail in SNAKE
LEN             .DS   1              ;snake length
NEWPOS          .DS   1              ;cell the head is moving into
EATEN           .DS   1              ;1 = this move eats the food
FOOD_POS        .DS   1              ;cell holding the food
FOOD_ON         .DS   1              ;blink state of the food
LIVES           .DS   1
SCORE_LO        .DS   1              ;BCD score
SCORE_HI        .DS   1
MOVE_DELAY      .DS   2              ;frames per move (current speed)
MOVE_CNT        .DS   2              ;frames until the next move
BLINK_CNT       .DS   2              ;frames until the food blinks
BODY            .DS   8              ;bitmap of the cells the snake occupies
SNAKE           .DS   64             ;circular queue of body cells, tail to head

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
        LD    (LAST_KEY),A
        LD    HL,START_SPEED
        LD    (MOVE_DELAY),HL
        LD    HL,BLINK_RATE
        LD    (BLINK_CNT),HL
        CALL  NEW_SNAKE
        CALL  UPDATE_SEG

;------------------------------------------------
; main game loop, one pass = one display refresh
;------------------------------------------------
GAME_LOOP
        CALL  DISPLAY_SCAN

;--- blink the food so it can be told from the body
        LD    HL,(BLINK_CNT)
        DEC   HL
        LD    (BLINK_CNT),HL
        LD    A,H
        OR    L
        JR    NZ,READ_KEY
        LD    HL,BLINK_RATE
        LD    (BLINK_CNT),HL
        LD    A,(FOOD_ON)
        XOR   1
        LD    (FOOD_ON),A
        CALL  DRAW

;--- keys: a press is new if the key code differs from the last pass
READ_KEY
        IN    A,(KEYBUF)             ;read hardware encoder
        AND   3FH                    ;strip unused bits
        BIT   5,A                    ;DA high = key pressed
        JR    Z,NO_KEY

        LD    B,A
        LD    A,(LAST_KEY)
        CP    B
        JR    Z,TIMER                ;same key still held
        LD    A,B
        LD    (LAST_KEY),A           ;a new press
        AND   1FH                    ;key code
        LD    B,0                    ;B = direction number
        CP    KEY_UP
        JR    Z,KEY_DIR
        INC   B
        CP    KEY_RIGHT
        JR    Z,KEY_DIR
        INC   B
        CP    KEY_DOWN
        JR    Z,KEY_DIR
        INC   B
        CP    KEY_LEFT
        JR    Z,KEY_DIR
        JR    TIMER                  ;not a direction key

KEY_DIR
        LD    A,1
        LD    (STARTED),A            ;the first key press starts the snake
        LD    A,B
        CALL  ENQUEUE
        JR    TIMER

NO_KEY
        XOR   A
        LD    (LAST_KEY),A           ;released, the next press is new

TIMER
        LD    A,(STARTED)
        OR    A
        JP    Z,GAME_LOOP            ;waiting for the first key

        LD    HL,(MOVE_CNT)
        DEC   HL
        LD    (MOVE_CNT),HL
        LD    A,H
        OR    L
        JP    NZ,GAME_LOOP           ;not time to move yet

        LD    HL,(MOVE_DELAY)
        LD    (MOVE_CNT),HL          ;reload the counter
        CALL  SNAKE_STEP             ;carry set = the snake hit itself
        JP    NC,GAME_LOOP

;--- hit itself: lose a life
HIT
        LD    A,(LIVES)
        DEC   A
        LD    (LIVES),A
        CALL  UPDATE_SEG
        CALL  FLASH
        LD    HL,START_SPEED
        LD    (MOVE_DELAY),HL        ;back to the slowest speed
        LD    A,(LIVES)
        OR    A
        JR    Z,GAME_OVER
        CALL  NEW_SNAKE
        JP    GAME_LOOP

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
WAIT_REL2
        CALL  DISPLAY_SCAN           ;and release again, so that key
        IN    A,(KEYBUF)             ;does not steer the new game
        BIT   5,A
        JR    NZ,WAIT_REL2
        JP    NEW_GAME

CROSS
        .BYTE 81H,42H,24H,18H,18H,24H,42H,81H

;------------------------------------------------
; queue a turn
; Up to two turns are held, one is used per move. A turn is dropped if it
; is the same as, or the reverse of, the direction it follows.
; entry : A = new direction 0..3
;------------------------------------------------
ENQUEUE
        LD    C,A                    ;C = new direction
        LD    A,(KEYQ1)
        CP    NOKEY
        RET   NZ                     ;queue is full
        LD    A,(KEYQ0)
        CP    NOKEY
        JR    NZ,ENQ1                ;one is queued, compare with that
        LD    A,(CUR_DIR)            ;empty, compare with the current direction
ENQ1
        LD    B,A
        LD    A,C
        XOR   B                      ;0 = same, 2 = reverse, odd = a real turn
        AND   1
        RET   Z                      ;same or reverse, ignore it
        LD    A,(KEYQ0)
        CP    NOKEY
        JR    NZ,ENQ2
        LD    A,C
        LD    (KEYQ0),A
        RET
ENQ2
        LD    A,C
        LD    (KEYQ1),A
        RET

;------------------------------------------------
; move the snake one cell
; The self-collision test comes first and the tail cell counts as body, so
; the head may not move into the cell the tail is about to leave.
; When eating, the tail stays.
; exit : carry set = hit the body, carry clear = ok
;------------------------------------------------
SNAKE_STEP
        LD    A,(KEYQ0)              ;apply a queued turn
        CP    NOKEY
        JR    Z,SS1
        LD    (CUR_DIR),A
        LD    A,(KEYQ1)
        LD    (KEYQ0),A
        LD    A,NOKEY
        LD    (KEYQ1),A
SS1
        LD    A,(HEAD)               ;work out the new head cell
        LD    E,A
        LD    D,0
        LD    HL,SNAKE
        ADD   HL,DE
        LD    A,(HL)
        CALL  NEW_HEAD
        LD    (NEWPOS),A

        LD    B,A
        LD    A,(FOOD_POS)
        CP    B
        JR    Z,SS_EAT
        XOR   A
        LD    (EATEN),A
        JR    SS2

SS_EAT
        LD    A,1
        LD    (EATEN),A

;--- does the head hit the body? the tail cell still counts as body
SS2
        LD    A,(NEWPOS)
        LD    HL,BODY
        CALL  CELL_ADDR
        LD    A,(HL)
        AND   B
        JR    Z,SS3
        SCF
        RET                          ;hit the body

SS3
        LD    A,(HL)
        OR    B
        LD    (HL),A                 ;light the new head cell

        LD    A,(EATEN)
        OR    A
        JR    NZ,SS4                 ;eating, the tail stays put

;--- no food: the tail moves on
        LD    A,(TAIL)
        LD    E,A
        LD    D,0
        LD    HL,SNAKE
        ADD   HL,DE
        LD    A,(HL)                 ;A = tail cell
        LD    HL,BODY
        CALL  CELL_ADDR
        LD    A,B
        CPL
        AND   (HL)
        LD    (HL),A                 ;clear the tail pixel
        LD    A,(TAIL)
        INC   A
        AND   3FH
        LD    (TAIL),A

SS4
        LD    A,(HEAD)
        INC   A
        AND   3FH
        LD    (HEAD),A
        LD    E,A
        LD    D,0
        LD    HL,SNAKE
        ADD   HL,DE
        LD    A,(NEWPOS)
        LD    (HL),A                 ;add the head to the queue

        LD    A,(EATEN)
        OR    A
        CALL  NZ,ATE_FOOD
        CALL  DRAW
        OR    A                      ;clear carry
        RET

;------------------------------------------------
; new head cell, wrapping at the edges
; entry : A = head cell, CUR_DIR = direction
; exit  : A = new cell
;------------------------------------------------
NEW_HEAD
        LD    B,A
        LD    A,(CUR_DIR)
        OR    A
        JR    Z,GO_UP
        CP    2
        JR    C,GO_RIGHT
        JR    Z,GO_DOWN
GO_LEFT
        LD    A,B
        DEC   A
        AND   07H
        LD    C,A                    ;new x
        LD    A,B
        AND   38H                    ;same row
        OR    C
        RET
GO_RIGHT
        LD    A,B
        INC   A
        AND   07H
        LD    C,A
        LD    A,B
        AND   38H
        OR    C
        RET
GO_DOWN
        LD    A,B
        ADD   A,8
        AND   3FH
        RET
GO_UP
        LD    A,B
        SUB   8
        AND   3FH
        RET

;------------------------------------------------
; the snake ate the food: grow, score, speed up, new food
;------------------------------------------------
ATE_FOOD
        LD    A,(LEN)
        INC   A
        LD    (LEN),A
        CALL  ADD_SCORE
        CALL  UPDATE_SEG

        LD    HL,(MOVE_DELAY)
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
        LD    (MOVE_DELAY),HL

        LD    A,(LEN)
        CP    64
        JR    Z,BOARD_FULL
        JP    PLACE_FOOD             ;no room left if the snake fills the board
BOARD_FULL
        CALL  FLASH                  ;the whole board is snake, you win
        JP    NEW_SNAKE              ;start again, score and lives are kept

;------------------------------------------------
; put the food on a random free cell
; a random cell is chosen, then the next free one at or after it is used
;------------------------------------------------
PLACE_FOOD
        CALL  RAND
        LD    A,L
        XOR   H
        AND   3FH
PF1
        PUSH  AF
        LD    HL,BODY
        CALL  CELL_ADDR
        LD    A,(HL)
        AND   B
        JR    Z,PF2                  ;free
        POP   AF
        INC   A
        AND   3FH
        JR    PF1
PF2
        POP   AF
        LD    (FOOD_POS),A
        LD    A,1
        LD    (FOOD_ON),A
        RET

;------------------------------------------------
; a new snake of 3 cells on row 4, heading right, waiting for a key
;------------------------------------------------
NEW_SNAKE
        LD    HL,BODY
        LD    B,8
        XOR   A
NS1
        LD    (HL),A
        INC   HL
        DJNZ  NS1
        LD    A,0E0H
        LD    (BODY+4),A             ;x = 0..2 on row 4
        LD    A,32
        LD    (SNAKE),A
        INC   A
        LD    (SNAKE+1),A
        INC   A
        LD    (SNAKE+2),A
        XOR   A
        LD    (TAIL),A
        LD    (STARTED),A
        LD    A,2
        LD    (HEAD),A
        LD    A,3
        LD    (LEN),A
        LD    A,1
        LD    (CUR_DIR),A
        LD    A,NOKEY
        LD    (KEYQ0),A
        LD    (KEYQ1),A
        LD    HL,(MOVE_DELAY)
        LD    (MOVE_CNT),HL
        CALL  PLACE_FOOD
        CALL  DRAW
        RET

;------------------------------------------------
; locate a cell in an 8 byte bitmap
; entry : A = cell (y*8+x), HL -> the bitmap
; exit  : HL -> the row byte, B = pixel mask
;         (A, C, DE destroyed)
;------------------------------------------------
CELL_ADDR
        LD    C,A
        PUSH  HL
        AND   07H
        LD    E,A
        LD    D,0
        LD    HL,COLMASK
        ADD   HL,DE
        LD    B,(HL)                 ;B = pixel mask for the column
        LD    A,C
        RRCA
        RRCA
        RRCA
        AND   07H                    ;A = row
        LD    E,A
        POP   HL
        ADD   HL,DE
        RET

; pixel mask for each column, x = 0 is the left (bit 7)
COLMASK
        .BYTE 80H,40H,20H,10H,08H,04H,02H,01H

;------------------------------------------------
; build the frame: the snake, plus the food when it is blinked on
;------------------------------------------------
DRAW
        LD    HL,BODY
        LD    DE,MATRIX_BUF
        LD    BC,8
        LDIR
        LD    A,(FOOD_ON)
        OR    A
        RET   Z
        LD    A,(FOOD_POS)
        LD    HL,MATRIX_BUF
        CALL  CELL_ADDR
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
