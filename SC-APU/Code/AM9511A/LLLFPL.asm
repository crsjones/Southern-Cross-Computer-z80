; original LLL code restored Herb Johnson Feb 2015
;
; original LLL code from "Floating Point Package for
; Intel 8008 and 8080 Microprocessors" by Maples Oct 24 1975
; URCL-51940 publication from Lawrence Livermore Laboratory
; 171286.PDF 
;
; fixes:
; 0) many lines had space in column 1! labels become operands!
; 1) added LLL square root routine
; 2) added missing "CALL SIGN" in CVRT routine
; 3) replaced ERR routine with one from LLL document
; 4) commented out "ORA A" at end of SAVEN
;
; ###S
; MODIFIED BY TONY GOLD FOR NON-MACRO ASSEMBLER
; CHANGES WITHIN ;###S AND ;###E LINES
; ALL ORIGINAL CODE RETAINED AS COMMENTS
; ###E
;
; //// FLOATING POINT PACKAGE FOR THE MCS8
; //// BY DAVID MEAD
; //// MODIFIED BY HAL BRAND 9/6/74
; //// MODIFIED FOR 24 BIT MANTISSAS
; //// PLUS ADDED I/O CONVERSION ROUTINES
; //// MODIFIED BY FRANK OLKEN 6/28/75
;
;
; Transcribed to Z80 mnemonics by the z88dk/support/8080/toZ80.awk tool.
; gawk -f toZ80.awk < 80_lllf.asm > z80_lllf.asm
;
; Modified to run on the RC2014 and the YAZ180 by
; Phillip Stevens @feilipu https://feilipu.me
; February / March 2017
;
; Converted to z88dk z80asm for RC2014 and YAZ180 by
; Phillip Stevens @feilipu https://feilipu.me
; August 2017
;
;
;

;DEFC    MINCH   =   $C0 ;300Q   ;MINIMUM EXPONENT WITH SIGN EXTENDED
MINCH:    .EQU   $C0

;DEFC    MAXCH   =   $3F ;077Q   ;MAXIMUM EXPONENT WITH SIGN EXTENDED
MAXCH:    .EQU  $3F
;
;******************************************************
;       //// PUBLIC FUNCTIONS
;******************************************************
;
;PUBLIC  INPUT, CVRT
;PUBLIC  LADD, LSUB, LMUL, LDIV, DSQRT

;******************************************************
;       //// LIBRARY ORIGIN
;******************************************************
;
;SECTION     apu_library         ;LIBRARY ORIGIN
;

SCRPG:   .equ       $34         ; SCRATCH PAGE IS 3400H  UP FROM   2800H
OP1:     .equ       $00         ; STARTING LOCATION OF OPERAND 1
OP2:     .equ       OP1+$04     ; STARTING LOCATION OF OPERAND 2
RSULT:   .equ       OP2+$04     ; STARTING LOCATION OF RESULT
SCR      .equ       RSULT+$04   ; STARTING LOCATION OF SCRATCH AREA

;SCM System Calls 
;TXDATA  .equ  23
;RXDATA  .equ  24

;******************************************************
;       //// OUTPUT SUBROUTINE
;******************************************************
;
; OUTR OUTPUT FROM CVRT INTO TX0 OUTPUT BUFFER
; ALL REG'S MAINTAINED
;
OUTR:   push    bc
        AND     7FH             ;CLEAR HIGH BIT
        ld      c,TXDATA
        rst     30h
        pop     bc
        RET
;
;
;******************************************************
;       //// INPUT SUBROUTINES
;******************************************************
;

; ROUTINE TO INPUT CHAR FROM INPUT BUFFER
; RST 10H LOOPS TILL A CHARACTER IS AVAILABLE
; INP RETURNS CHARACTER WITH HIGH BIT SET
; IN REGISTER A.
;
; ROUTINE PASSES SPACE IF THE INPUT IS NOT A NUMBER.
; NUMERICAL CHARACTERS INCLUDE 0 - 9, +, -, AND E.
;
; ROUTINE ECHOS THE CHARACTERS FORWARDED
;
INP:    push    bc
        ld      c,RXDATA
        RST     30h
		pop     bc
        CP      '+'             ;+?
        JP      Z,INP_DONE
        CP      '-'             ;-?
        JP      Z,INP_DONE
        CP      '.'             ;DEC. PNT.?           
        JP      Z,INP_DONE
        CP      'E'             ;E?
        JP      Z,INP_DONE
        CP      '0'             ;ASCII CNTRL.?
        JP      M,SPACE
        CP      ':'             ;DECIMAL NUMBER?
        JP      M,INP_DONE
SPACE:
        LD      A,' '           ;SEND A SPACE
INP_DONE:
        PUSH    AF
        CALL    OUTR
        POP     AF
        OR      80H             ;SET HIGH BIT
        RET
;
;
;******************************************************
;       //// DIVIDE SUBROUTINE
;******************************************************
;
LDIV:
        CALL    CSIGN           ;COMPUTE SIGN OF RESULT
        CALL    ZCHK            ;CHECK IF DIVIDEND = ZERO
        JP      NZ,DTST2        ;IF DIVIDEND .NE. 0 CHECK DIVISOR
        CALL    BCHK            ;CHECK FOR ZERO/ZERO
        JP      Z,INDFC         ;ZERO/ZERO = INDEFINITE
        JP      WZERC           ;ZERO/NONZERO = ZERO

DTST2:
        CALL    BCHK            ;COME HERE IF DIVIDEND .NE. 0
        JP      Z,OFLWC         ;NONZERO/ZERO = OVERFLOW
                                ;IF WE GET HERE, THINGS LOOK OKAY
        LD      E,L             ;SAVE BASE IN E
        LD      L,C             ;BASE 6 TO L
        CALL    DCLR            ;CLEAR QUOTIENT MANTISSA SLOT
        LD      L,E             ;RESTORE BASE IN L
        CALL    ENT1            ;DO FIRST CYCLE
        LD      L,C             ;BASE 6 TO L
        CALL    DLST            ;MOVE QUOTIENT OVER ONE PLACE
        LD      D,23            ;NUMBER OF ITERATIONS TO D
REP3:
        LD      L,E
        CALL    ENT2
        DEC     D               ;DEC D
        JP      Z,GOON
        LD      A,L
        LD      L,C             ;BASE 6 TO L
        LD      C,A
        CALL    DLST            ;MOVE QUOTIENT MANT OVER
        LD      A,L             ;CPTR TO A
        LD      E,C             ;LPTR TO E
        LD      C,A             ;CPTR TO C
        JP      REP3

GOON:
        CALL    AORS            ;CHECK IF RESULT IS NORMALIZED
        JP      M,CRIN
        LD      A,L             ;LPTR TO A
        LD      L,C             ;CPTR TO L
        LD      C,A             ;LPTR TO C
        CALL    DLST            ;SHIFT QUOTIENT LEFT
        LD      C,L
        LD      L,E
        CALL    LDCP            ;COMPUTE THE EXPONENT OF RESULT
        RET

CRIN:
        CALL    CFCHE           ;GET A=CHAR(H,L), E=CHAR(H,B)
        SUB     E               ;NEW CHAR = CHAR(DIVIDEND) - CHAR(DVISIOR)
        CP      $7F  ;177Q      ;CHECK MAX POSITIVE NUMBER
        JP      Z,OFLWC         ;JUMP ON OVERFLOW
        ADD     A,1             ;ADD 1 SINCE WE DID NOT LEFTSHIFT
        CALL    CCHK            ;CHECK AND STORE EXPONENT
        RET                     ;RETURN
;
;
;******************************************************
;       //// ADDITION SUBROUTINE
;******************************************************
;
;
LADD:
        XOR     A               ;/***SET UP TO ADD
        JP      LADS            ;NOW DO IT
;
;
;******************************************************
;       //// SUBTRACTION SUBROUTINE
;******************************************************
;
;       SUBROUTINE LADS
;
;       FLOATING POINT ADD OR SUB
;       A 128 ON ENTRY SUB
;       A 0 ON ENTRY ADD
;       F-S F,FIRST OPER DESTROYED
;       BASE 11 USED FOR SCRATCH
;
LSUB:
        LD      A,$80  ;200Q    ;/****SET UP TO SUBTRACT
;
LADS:
        CALL    ACPR            ;SAVE ENTRY PNT AT BASE 6
        CALL    BCHK            ;CHECK ADDEND/SUBTRAHEND = ZERO
        RET     Z               ;IF SO, RESULT=ARG SO RETURN
                                ;THIS WILL PREVENT UNDERFLOW INDICATION ON
                                ;ZERO + OR - ZERO
        CALL    CCMP
        JP      Z,EQ02          ;IF EQUAL, GO ON
        LD      D,A             ;SAVE LPTR CHAR IN D
        JP      C,LLTB
        SUB     E               ;L.GT.B IF HERE
        AND     127
        LD      D,A             ;DIFFERENCE TO D
        LD      E,L             ;SAVE BASE IN E
        LD      L,C             ;C PTR TO L
        INC     L               ;C PTR 1 TO L
        LD      (HL),E          ;SAVE BASE IN C PTR\1
        LD      L,B             ;B PTR TO L
        JP      NCHK

LLTB:
        LD      A,E             ;L.LT.B IF HERE,BPTR TO A
        SUB     D               ;SUBTRACT LPTR CHAR FROM BPTR CHAR
        AND     127
        LD      D,A             ;DIFFERENCE TO D
NCHK:
        LD      A,24
        CP      D
        JP      NC,SH10
        LD      D,24
SH10:
        OR      A
        CALL    DRST
        DEC     D
        JP      NZ,SH10
EQUL:
        LD      A,L
        CP      B
        JP      NZ,EQ02         ;F.GT.S IF L.NE.B
        LD      L,C             ;C PTR TO L
        INC     L               ;C PTR\1 TO L
        LD      L,(HL)          ;RESTORE L
EQ02:
        CALL    LASD            ;CHECK WHAT TO
        CALL    ACPR            ;SAVE ANSWER
        CP      2               ;TEST FOR ZERO ANSWER
        JP      NZ,NOT0
        JP      WZER            ;WRITE FLOATING ZERO AND RETURN

NOT0:
        LD      D,1             ;WILL TEST FOR SUB
        AND     D
        JP      Z,ADDZ          ;LSB 1 IMPLIES SUB
        CALL    TSTR            ;CHECK NORMAL/REVERSE
        JP      Z,SUBZ          ;IF NORMAL,GO SUBZ
        LD      A,L             ;OTHERWISE REVERSE
        LD      L,B             ;ROLES
        LD      B,A             ;OF L AND B
SUBZ:
        CALL    DSUB            ;SUBTRACT SMALLER FROM BIGGER
        CALL    MANT            ;SET UP SIGN OF RESULT
        CALL    TSTR            ;SEE IF WE NEED TO INTERCHANGE
                                ;BPTR AND LPTR
        JP      Z,NORM          ;NO INTERCHANGE NECESSARY, SO NORMALIZE
                                ;AND RETURN
        LD      A,L             ;INTERCHANGE
        LD      L,B             ;L
        LD      B,A             ;AND B
        LD      A,C             ;CPTR  TO A
        LD      C,B             ;BPTR TO C
        LD      E,L             ;LPTR TO E
        LD      B,A             ;CPTR TO B
        CALL    LXFR            ;MOVE BPTR> TO LPTR>
        LD      A,B
        LD      B,C
        LD      C,A
        LD      L,E
        JP      NORM            ;NORMALIZE RESULT AND RETURN
;
;   COPY THE LARGER EXPONENT TO THE RESULT
;
ADDZ:
        CALL    CCMP            ;COMPARE THE CHARACTERISTICS
        JP      NC,ADD2         ;IF CHAR(H,L) .GE. CHAR(H,B) CONTINUE
        CALL    BCTL            ;IF CHAR(H,L) .LT. CHAR(H,B) THE COPY
                                ;CHAR(H,B) TO CHAR(H,L)
ADD2:
        CALL    MANT            ;COMPUTE SIGN OF RESULT
        CALL    DADD            ;ADD MANTISSAS
        JP      NC,SCCFG        ;IF THERE IS NO OVFLW - DONE
        CALL    DRST            ;IF OVERFLOW SHIFT RIGHT
        CALL    INCR            ;AND INCREMENT EXPONENT
        RET                     ;ALL DONE, SO RETURN
;
;   THIS ROUTINE STORES THE MANTISSA SIGN IN THE RESULT
;   THE SIGN HAS PREVIOUSLY BEEN COMPUTED BY LASD.
;
MANT:
        LD      E,L             ;SAVE L PTR
        LD      L,C             ;C PTR TO L
        LD      A,(HL)             ;LOAD INDEX WORD
        AND     128             ;SCARF SIGN
        LD      L,E             ;RESTORE L PTR
        INC     L               ;L PTR 2
        INC     L
        INC     L               ;TO L
        LD      E,A             ;SAVE SIGN IN E
        LD      A,(HL)
        AND     127             ;SCARF CHAR
        ADD     A,E               ;ADD SIGN
        LD      (HL),A             ;STORE IT
        DEC     L               ;RESTORE
        DEC     L
        DEC     L               ;L PTR
        RET
;
;
;   SUBROUTINE LASD
;
;       UTILITY ROUTINE FOR LADS
;       CALCULATES TRUE OPER AND SGN
;       RETURNS ANSWER IN
;
LASD:
        CALL    MSFH            ;FETCH MANT SIGNS, F IN A,D
        CP      E               ;COMPARE SIGNS
        JP      C,ABCH          ;F\,S- MEANS GO TO A BRANCH
        JP      NZ,BBCH         ;F- S\ MEANS GO TO B BRANCH
        ADD     A,E             ;SAME SIGN IF HERE, ADD SIGNS
        JP      C,BMIN          ;IF BOTH MINUS, WILL OVERFLOW
        CALL    AORS            ;BOTH POS IF HERE
        JP      P,L000          ;IF AN ADD, LOAD 0

COM1:
        CALL    DCMP            ;COMPARE F WITH S
        JP      C,L131          ;S.GT.F,SO LOAD 131
        JP      NZ,L001         ;F.GT.S,SO LOAD 1
L002:
        LD      A,2             ;ERROR CONDITION, ZERO ANSWER
        RET

BMIN:
        CALL    AORS            ;CHECK FOR ADD OR SUB
        JP      P,L128          ;ADD, SO LOAD 128

COM2:
        CALL    DCMP            ;COMPARE F WITH S
        JP      C,L003          ;S.GT.F,SO LOAD 3
        JP      NZ,L129         ;FGT.S.SO LOAD 129
        JP     L002            ;ERROR

ABCH:
        CALL    AORS            ;FT,S- SO TEST FOR A/S
        JP      M,L000          ;SUBTRACT, SO LOAD 0
        JP      COM1            ;ADD, SO GO TO DCMP

BBCH:
        CALL    AORS            ;F-,S\,SO TEST FOR A/S
        JP      M,L128          ;SUB
        JP      COM2            ;ADD

L000: 
        XOR     A
        RET

L001:
        LD      A,1
        RET

L003:
        LD      A,3
        RET

L128:
        LD      A,128
        RET

L129:
        LD      A,129
        RET

L131:
        LD      A,131
        RET
;
;       SUBROUTINE LMCM
;       COMPARES THE MAGNITUDE OF
;       TWO FLOATING PNT NUMBERS
;       Z[1 IF [,C[1 IF F.LT.S.
;
LMCM:
        CALL    CCMP            ;CHECK CHARS
        RET     NZ              ;RETURN IF NOT EQUAL
        CALL    DCMP            ;IF EQUAL, CHECK MANTS
        RET
;
;
;
;***************************************************
;       //// MULTIPLY SUBROUTINE
;***************************************************
;
;   SUBROUTINE LMUL
;
;       FLOATING POINT MULTIPLY
;       L PTR X B PTR TO C PTR
;
LMUL:
        CALL    CSIGN           ;COMPUTE SIGN OF RESULT AND STORE IT
        CALL    ZCHK            ;CHECK FIRST OPERAND FOR ZERO
        JP      Z,WZERC         ;ZERO * ANYTHING = ZERO
        CALL    BCHK            ;CHECK SECOND OPERAND FOR ZERO
        JP      Z,WZERC         ;ANYTHING * ZERO = ZERO
        LD      E,L             ;SAVE L PTR
        LD      L,C             ;C PTR TO L
        CALL    DCLR            ;CLR PRODUCT MANT LOCS
        LD      L,E             ;L PTR TO L
        LD      D,24            ;LOAD NUMBER ITERATIONS
KPGO:
        CALL    DRST            ;SHIFT L PTR RIGHT
        JP      C,MADD          ;WILL ADD B PTR IF C[1
        LD      A,L             ;INTERCHANGE
        LD      L,C             ;L AND
        LD      C,A             ;C PTRS
INTR:
        CALL    DRST            ;SHIFT PRODUCT OVER
        LD      A,L             ;INTERCHANGE
        LD      L,C             ;L AND C PTRS_BACK TO
        LD      C,A             ;ORIGINAL>
        DEC     D
        JP      NZ,KPGO         ;MORE CYCLES IF Z[0
        CALL    AORS            ;TEST IF RESULT IS NORMALIZED
        JP      M,LMCP          ;IF NORMALIZED GO COMPUTE CHAR
        LD      E,L             ;SAVE LPTR IN E
        LD      L,C             ;SET L=CPTR
        CALL    DLST            ;LEFT SHIFT RESULT TO NORMALIZE
        LD      L,E             ;RESTORE LPTR
        CALL    CFCHE           ;OTHERWISE SET A=CHAR(H,L), E=CHAR(H,B)
        ADD     A,E             ;CHAR(RESULT) = CHAR(H,L) + CHAR(H,B)
        CP      $80  ;200Q      ;CHECK FOR SMALLEST NEGATIVE NUMBER
        JP      Z,UFLWC         ;IF SO THEN UNDERFLOW
        SUB     1               ;SUBTRACT 1 TO COMPENSATE FOR NORMALIZE
        CALL    CCHK            ;CHECK EXPONENT AND STORE IT
        RET                     ;RETURN

MADD:
        LD      A,L             ;INTERCHANGE
        LD      L,C             ;L AND
        LD      C,A             ;C PTRS
        CALL    DADD            ;ACCUMULATE PRODUCT
        JP      INTR
;
;   SUBROUTINE NORM
;
;       THIS SUBROUTINE WILL NORMALIZE A FLOATING POINT
;       NUMBER, PRESERVING ITS ORIGINAL SIGN.
;       WE CHECK FOR UNDERFLOW AND SET THE CONDITION
;       FLAG APPROPRIATELY.  (SEE ERROR RETURNS).
;       THERE IS AN ENTRY POINT TO FLOAT A SIGNED INTEGER
;       (FLOAT) AND AN ENTRY POINT TO FLOAT AN UNSIGNED
;       INTEGER.
;
;   ENTRY POINTS:
;
;       NORM  - NORMALIZE FLOATING PT NUMBER AT (H,L)
;       FLOAT - FLOAT TRIPLE PRECISION INTEGER AT (H,L)
;               PRESERVING SIGN BIT IN (H,L)+3
;       DFXL  - FLOAT UNSIGNED (POSITIVE) TRIPLE PRECISION
;               AT (H,L)
;
;   REGISTERS ON EXIT:
;
;       A = CONDITION FLAG (SEE ERROR RETURNS)
;       D,E = GARBAGE
;       B,C,H,L = SAME AS ON ENTRY
;
NORM:
        LD      E,L             ;SAVE L IN E
NORM1:
        CALL    GCHAR           ;GET CHAR(H,L) IN A WITH SIGN EXTENDED
        LD      D,A             ;SAVE CHAR IN D
FXL1:
        LD      L,E             ;RESTORE L
FXL2:
        CALL    ZMCHK           ;CHECK FOR ZERO MANTISSA
        JP      Z,WZER          ;IF ZERO MANTISSA THEN ZERO RESULT
REP6:
        LD      A,(HL)          ;GET MOST SIGNIFICANT BYTE OF
                                ;MANTISSA
        OR      A               ;SET FLAGS
        JP      M,SCHAR           ;IF MOST SIGNIFICANT BIT = 1 THEN
                                ;NUMBER IS NORMALIZED AND WE GO TO
                                ;STORE THE EXPONENT
        LD      A,D             ;OTHERWISE CHECK FOR UNDERFLOW
        CP      MINCH           ;COMPARE WITH MINIMUM CHAR
        JP      Z,WUND          ;IF EQUAL THEN UNDERFLOW
        CALL    DLST            ;SHIFT MANTISSA LEFT
        DEC     D               ;DECREMENT EXPONENT
        JP      REP6            ;LOOP AN TEST NEXT BIT

SCHAR:
        JP      INCR3           ;STORE THE EXPONENT USING
                                ;THE SAME CODE AS THE INCREMENT

DFXL:
        LD      E,L             ;ENTER HERE TO FLOAT UNSIGNED
                                ;INTEGER
                                ;FIRST SAVE L IN E
        INC     L               ;MAKE (H,L) POINT TO CHAR
        INC     L               ;MAKE (H,L) POINT TO CHAR
        INC     L               ;MAKE (H,L) POINT TO CHAR
        XOR     A               ;ZERO ACCUMULATOR
        LD      (HL),A          ;STORE A PLUS (+) SIGN
        LD      L,E             ;RESTORE L
FLOAT:
        LD      D,24            ;ENTER HERE TO FLOAT INTEGER
                                ;PRESERVING ORIGINAL SIGN IN (H,L)+3
                                ;SET UP EXPONENT
        JP     FXL2             ;GO FLOAT THE NUMBER
;
;
;
;
;   SUBROUTINE ZCHK
;
;       THIS ROUTINE SETS THE ZERO FLAG IF IT DETECTS
;       A FLOATING ZERO AT (H,L).
;
;   SUBROUTINE ZMCHK
;
;       THIS ROUTINE SETS THE ZERO FLAG IF IT DETECTS A
;       ZERO MANTISSA AT (H,L)
;
ZCHK:
ZMCHK:
        INC     L               ;SET L TO POINT LAST BYTE OF MANTISSA
        INC     L               ;SET L TO POINT TO LAST BYTE OF MANTISSA
        LD      A,(HL)          ;LOAD LEAST SIGNIFICANT BYTE
        DEC     L               ;L POINTS TO MIDDLE BYTE
        OR      (HL)            ;OR WITH LEAST SIGNIFICANT BYTE
        DEC     L               ;L POINTS TO MOST SIGNIFICANT BYTE
                                ;OF MANTISSA (ORIGINAL VALUE)
        OR      (HL)            ;OR IN MOST SIGNIFICANT BYTE
        RET                     ;RETURNS WITH ZERO FLAG SET APPROPRIATELY
;
;  SUBROUTINE BCHK
;
;       THIS ROUTINE CHECKS (H,B) FOR FLOATING PT ZERO
;
BCHK:
        LD      E,L             ;SAVE LPTR IN E
        LD      L,B             ;SET L=BPTR
        CALL    ZCHK            ;CHECK FOR ZERO
        LD      L,E             ;RESTORE L=LPTR
        RET                     ;RETURN
;
;
;   SUBROUTINE DLST
;
;       SHIFTS DBL WORD ONE PLACE LF
DLST:
        INC     L
        INC     L               ;/***TP
        LD      A,(HL)          ;LOAD IT
        OR      A               ;KILL CARRY
        RLA                     ;SHIFT IT LEFT
        LD      (HL),A          ;STORE IT
        DEC     L
        LD      A,(HL)          ;LOAD IT
        RLA                     ;SHIFT IT LEFT
;       IF CARRY SET BY FIRST SHIFT
;       IT WILL BE IN LSB OF SECOND
        LD      (HL),A
        DEC     L               ;/***TP EXTENSION
        LD      A,(HL)
        RLA
        LD      (HL),A          ;/***ALL DONE TP
        RET
;
;
;   SUBROUTINE DRST
;
;       SHIFTS DOUBLE WORD ONE PLACE
;       TO THE RIGHT
;           DOES NOT AFFECT D
;
DRST:
        LD      E,L             ;/***TP MODIFIED RIGHT SHIFT TP
        LD      A,(HL)          ;LOAD FIRST WORD
        RRA                     ;ROTATE IT RIGHT
        LD      (HL),A          ;STORE IT
        INC     L               ;/*** TP
        LD      A,(HL)          ;LOAD SECOND WORD
        RRA                     ;SHIFT IT RIGHT
        LD      (HL),A          ;STORE IT
        INC     L               ;/*** TP EXTENSION
        LD      A,(HL)
        RRA
        LD      (HL),A
        LD      L,E             ;/***TP - ALL DONE TP
        RET
;
;
;   SUBROUTINE DADD
;
;       ADDS TWO DOUBLE PRECISION
;       WORDS, C=1 IF THERE IS OVRFLW
;
DADD:
        LD      E,L             ;SAVE BASE IN E
        LD      L,B             ;BASE \3 TO L
        INC     L               ;BASE \4 TO L
        INC     L               ;/***TP
        LD      A,(HL)          ;LOAD S MANTB
        LD      L,E             ;BASE TO L
        INC     L               ;BASE \1 TO L
        INC     L               ;/***TP
        ADD     A,(HL)          ;ADD TWO MANTB]S
        LD      (HL),A          ;STORE ANSWER
        LD      L,B             ;/***TP EXTENSION
        INC     L
        LD      A,(HL)
        LD      L,E
        INC     L
        ADC     A,(HL)
        LD      (HL),A          ;/***TP - ALL DONE
        LD      L,B             ;BASE \3 TO L
        LD      A,(HL)          ;MANTA OF S TO A
        LD      L,E             ;BASE TO L
        ADC     A,(HL)          ;ADD WITH CARRY
        LD      (HL),A          ;STORE ANSWER
        RET
;
;
;   SUBROUTINE DCLR
;
;       CLEARS TWO SUCCESSIVE
;       LOCATIONS OF MEMORY
;
DCLR:
        XOR     A
        LD      (HL),A
        INC     L
        LD      (HL),A
        INC     L               ;/***TP EXTENSION
        LD      (HL),A          ;/***TP ZERO 3
        DEC     L               ;/***TP - ALL DONE
        DEC     L
        RET
;
;
;       /*****ALL NEW DSUB - SHORTER***
;
;   SUBROUTINE DSUB
;
;       DOUBLE PRECISION SUBTRACT
;
DSUB:
        LD      E,L             ;SAVE BASE IN E
        INC     L               ;/***TP EXTENSION
        INC     L               ;/START WITH LOWS
        LD      A,(HL)          ;/GET ARG
        LD      L,B             ;/NOW SET UP TO SUB
        INC     L
        INC     L
        SUB     (HL)            ;/NOW DO IT
        LD      L,E             ;/NOW MUST PUT IT BACK
        INC     L
        INC     L
        LD      (HL),A          ;/PUT BACK
        DEC     L               ;/***TP - ALL DONE
        LD      A,(HL)          ;/GET LOW OF LOP
        LD      L,B             ;/SET TO BOP
        INC     L               ;/SET TO BOP LOW
        SBC     A,(HL)          ;/GET DIFF. OF LOWS
        LD      L,E             ;/SAVE IN LOP LOW
        INC     L               ;/TO LOP LOW
        LD      (HL),A          ;/INTO RAM
        DEC     L               ;/BACK UP TO LOP HIGH
        LD      A,(HL)          ;/GET LOP HIGH
        LD      L,B             ;/SET TO BOP HIGH
        SBC     A,(HL)          ;/SUB. WITH CARRY
        LD      L,E             ;/SAVE IN LOP HIGH
        LD      (HL),A          ;/INTO RAM
        RET                     ;/ALL DONE - MUCH SHORTER
;
;   SUBROUTINE GCHAR
;
;       THIS SUBROUTINE RETURNS THE EXPONENT OF
;       THE FLOATING POINT NUMBER POINTED TO BY (H,L)
;       IN THE A REGISTER WITH ITS SIGN EXTENDED INTO THE
;       LEFTMOST BIT.
;
;   REGISTERS ON EXIT:
;
;       A = EXPONENT OF (H,L) WITH SIGN EXTENDED
;       L = (ORIGINAL L) + 3
;       B,C,D,E,H = SAME AS ON ENTRY
;
GCHAR:
        INC     L               ;MAKE (H,L) POINT TO CHAR
        INC     L               ;MAKE (H,L) POINT TO CHAR
        INC     L               ;MAKE (H,L) POINT TO CHAR
        LD      A,(HL)          ;SET A=CHAR + MANTISSA SIGN
        AND     $7F  ;177Q      ;GET RID OF MANTISSA SIGN BIT
        ADD     A,$40  ;100Q    ;PROPAGATE CHAR SIGN INTO LEFTMOST BIT
        XOR     $40  ;100Q      ;RESTORE ORIGINAL CHAR SIGN BIT
        RET                     ;RETURN WITH (H,L) POINTING TO THE
                                ;CHAR = ORIGINAL (H,L)+3
                                ;SOMEONE ELSE WILL CLEAN UP
;
;
;   SUBROUTINE CFCHE
;
;       THIS SUBROUTINE RETURNS THE CHARACTERISTICS OF THE
;       FLOATING POINT NUMBERS POINTED TO BY (H,L) AND
;       (H,B) IN THE A AND E REGISTERS RESPECTIVELY,
;       WITH THEIR SIGNS EXTENDED INTO THE LEFTMOST BIT.
;
;   REGISTERS ON EXIT:
;
;       A = EXPONENT OF (H,L) WITH SIGN EXTENDED
;       E = EXPONENT OF (H,B) WITH SIGN EXTENDED
;       B,C,H,L = SAME AS ON ENTRY
;       D = A
;
CFCHE:
        LD      E,L             ;SAVE LPTR IN E
        LD      L,B             ;SET L = BPTR
        CALL    GCHAR           ;GET CHAR(H,B) WITH SIGN EXTENDED IN A
        LD      L,E             ;RESTORE L = LPTR
        LD      E,A             ;SET E=CHAR(H,B) WITH SIGN EXTENDED
        CALL    GCHAR           ;SET A=CHAR(H,L) WITH SIGN EXTENDED
        DEC     L               ;RESTORE L = LPTR
        DEC     L               ;RESTORE L = LPTR
        DEC     L               ;RESTORE L = LPTR
        LD      D,A             ;SET D=A=CHAR(H,L) WITH SIGN EXTENDED
        RET
;
;
;   SUBROUTINE CCMP
;
;       THIS SUBROUTINE COMPARES THE CHARACTERISTICS OF
;       FLOATING POINT NUMBERS POINTED TO BY (H,L) AND (H,B).
;       THE ZERO FLIP-FLOP IS SET IF CHAR(H,L) EQUALS
;       CHAR(H,B).  IF CHAR(H,L) IS LESS THAN CHAR(H,B) THEN
;       THE CARRY BIT WILL BE SET.
;
;   REGISTERS ON EXIT:
;
;       A = EXPONENT OF (H,L) WITH SIGN EXTENDED
;       E = EXPONENT OF (H,B) WITH SIGN EXTENDED
;       D = A
;       B,C,H,L = SAME AS ON ENTRY
;
CCMP:
        CALL    CFCHE           ;FETCH CHARACTERISTICS WITH SIGN EXTENDED
                                ;INTO A (CHAR(H,L)) AND E (CHAR(H,B)) REGISTERS
        LD      D,A             ;SAVE CHAR (H,L)
        SUB     E               ;SUBTRACT E (CHAR(H,B))
        RLA                     ;ROTATE SIGN BIT INTO CARRY BIT
        LD      A,D             ;RESTORE A=CHAR(H,L)
        RET                     ;RETURN
;
;   ERROR RETURNS
;
;       THE FOLLOWING CODE IS USED TO RETURN VARIOUS
;       ERROR CONDITIONS.  IN EACH CASE A FLOATING POINT
;       NUMBER IS STORED IN  THE 4 WORDS POINTED TO BY (H,L)
;       AND A FLAG IS STORED IN THE ACCUMULATOR.
;
;       CONDITION   FLAG   RESULT (+)        RESULT (-)
;
;       UNDERFLOW    377   000 000 000 100   000 000 000 300
;       OVERFLOW     177   377 377 377 077   377 377 377 277
;       INDEFINITE   077   377 377 377 077   377 377 377 277
;       NORMAL       000   XXX XXX XXX XXX   XXX XXX XXX XXX
;       NORMAL ZERO  000   000 000 000 100   (ALWAYS RETURNS +0)
;
;   ENTRY POINTS:
;
;       WUND - WRITE UNDERFLOW
;       WOVR - WRITE OVERFLOW
;       WIND - WRITE INDEFINITE
;       WZER - WRITE NORMAL ZERO
;

WUND:
        LD      D,$40  ;100Q    ;LOAD EXPONENT INTO D REGISTER
        CALL    WCHAR           ;WRITE EXPONENT
UFLW1:
        LD      A,0             ;LOAD MANTISSA VALUE
                                ;WE ASSUME HERE THAT ALL BYTES OF MANTISSA
                                ;ARE THE SAME
        CALL    WMANT           ;WRITE THE MANTISSA
        LD      A,$FF  ;377Q    ;SET ACCUMULATOR TO FLAG
        OR      A               ;SET FLAGS PROPERLY
        RET                     ;RETURN (WMANT RESTORED (H,L))

WOVR:
        LD      D,$3F  ;77Q     ;LOAD EXPONENT INTO D REGISTER
        CALL    WCHAR           ;WRITE EXPONENT
OFLW1:
        LD      A,$FF  ;377Q    ;LOAD MANTISSA VALUE
                                ;WE ASSUME HERE THAT ALL BYTES OF MANTISSA
                                ;ARE THE SAME
        CALL    WMANT           ;WRITE THE MANTISSA
        LD      A,$7F  ;177Q    ;SET ACCUMULATOR TO FLAG
        OR      A               ;SET FLAGS PROPERLY
        RET                     ;RETURN (WMANT RESTORED (H,L))

WIND:
        LD      D,$3F  ;77Q     ;LOAD EXPONENT INTO D REGISTER
        CALL    WCHAR           ;WRITE EXPONENT
INDF1:
        LD      A,$FF  ;377Q    ;LOAD MANTISSA VALUE
                                ;WE ASSUME HERE THAT ALL BYTES OF MANTISSA
                                ;ARE THE SAME
        CALL    WMANT           ;WRITE THE MANTISSA
        LD      A,$3F  ;77Q     ;SET ACCUMULATOR TO FLAG
        OR      A               ;SET FLAGS PROPERLY
        RET                     ;RETURN (WMANT RESTORED (H,L))

WZER:
        INC     L               ;WRITE NORMAL ZERO
        INC     L               ;
        INC     L               ;
        LD      (HL),$40  ;100Q ;STORE EXPONENT FOR ZERO
        XOR     A               ;ZERO ACCUMULATOR
        CALL    WMANT           ;STORE ZERO MANTISSA
        OR      A               ;SET FLAGS PROPERLY
        RET                     ;RETURN
;
; ROUTINE TO WRITE MANTISSA FOR ERROR RETURNS
;
WMANT:
        DEC     L               ;POINT LEAST SIGNIFICANT BYTE
                                ;OF MANTISSA
        LD      (HL),A          ;STORE LSBYTE OF MANTISSA
        DEC     L               ;POINT TO NEXT LEAST SIGNIFICANT BYTE
                                ;OF MANTISSA
        LD      (HL),A          ;STORE NLSBYTE OF MANTISSA
        DEC     L               ;POINT TO MOST SIGNIFICANT BYTE
                                ;OF MANTISSA
        LD      (HL),A          ;STORE MSBYTE OF MANTISSA
        RET                     ;RETURN (H,L) POINTS TO BEGINNING OF
                                ;FLOATING POINT RESULT
;
; ROUTINE TO WRITE EXPONENT FOR ERROR RETURNS
; NOTE:  WE PRESERVE ORIGINAL MANTISSA SIGN
; ON ENTRY D CONTAINS NEW EXPONENT TO BE STORED.
;
WCHAR:
        INC     L               ;SET (H,L) TO POINT TO EXPONENT
        INC     L               ;PART OF ABOVE
        INC     L               ;PART OF ABOVE
        LD      A,(HL)          ;LOAD EXPONENT A
                                ;AND MANTISSA SIGN
        AND     $80  ;200Q      ;JUST KEEP MANTISSA SIGN
        OR      D               ;OR IN NEW EXPONENT
        LD      (HL),A          ;STORE IT BACK
        RET                     ;RETURN WITH (H,L) POINT TO EXPONENT
                                ;OF RESULT
                                ;SOMEONE ELSE WILL FIX UP (H,L)
;
;   SUBROUTINE INDFC
;
;       THIS ROUTINE WRITES A FLOATING INDEFINITE, SETS
;       THIS WRITES WRITES A FLOATING POINT INDEFINITE
;       AT (H,C), SETS THE CONDITION FLAG AND RETURNS
;
;
INDFC:
        LD      E,L             ;SAVE LPTR IN E
        LD      L,C             ;SET L=CPTR SO (H,L)-ADDR OF RESULT
        CALL    WIND            ;WRITE INDEFINITE
        LD      L,E             ;RESTORE L=LPTR
        RET                     ;RETURN
;
;
;   SUBROUTINE WZERC
;
;       THIS ROUTINE WRITES A NORMAL FLOATING POINT ZERO
;       AT (H,C), SETS THE CONDITION FLAG AND RETURNS
;
WZERC:
        LD      E,L             ;SAVE LPTR IN E
        LD      L,C             ;SETL=CPTR SO (H,L)=ADDR OF RESULT
        CALL    WZER            ;WRITE NORMAL ZERO
        LD      L,E             ;RESTORE L=LPTR
        RET                     ;RETURN
;
;   SUBROUTINE INCR
;
;       THIS SUBROUTINE INCREMENTS THE EXPONENT
;       OF THE FLOATING POINT NUMBER POINTED TO BY (H,L).
;       WE TEST FOR OVERFLOW AND SET APPROPRIATE FLAG.
;       (SEE ERROR RETURNS).
;
;   REGISTERS ON EXIT:
;
;        A = CONDITION FLAG (SEE ERROR RETURNS)
;        D = CLOBBERED
;        B,C,H,L = SAME AS ON ENTRY
;
INCR:
        CALL    GCHAR           ;GET CHAR WITH SIGN EXTENDED
        CP      MAXCH           ;COMPARE WITH MAX CHAR PERMITTED
        JP      Z,OFLW1         ;INCREMENT WOULD CAUSE OVERFLOW
        LD      D,A             ;SAVE IT IN D
        INC     D               ;INCREMENT IT
        JP      INCR2           ;JUMP AROUND ALTERNATE ENTRY POINT

INCR3:
        INC     L               ;COME HERE TO STORE EXPONENT
        INC     L               ;POINT (H,L) TO CHAR
        INC     L               ;POINT (H,L) TO CHAR
INCR2:
        LD      A,$7F  ;177Q
        AND     D               ;KILL SIGN BIT
        LD      D,A             ;BACK TO D
        LD      A,(HL)          ;NOW SIGN IT
        AND     $80  ;200Q      ;GET MANTISSA SIGN
        OR      D               ;PUT TOGETHER
        LD      (HL),A          ;STORE IT BACK
        DEC     L               ;NOW BACK TO BASE
        DEC     L               ;/***TP
        DEC     L
SCCFG:
        XOR     A               ;SET SUCCESS FLAG
        RET
;
;   SUBROUTINE DECR
;
;       THIS SUBROUTINE DECREMENTS THE EXPONENT
;       OF THE FLOATING POINT NUMBER POINTED TO BY (H,L).
;       WE TEST FOR UNDERFLOW AND SET APPROPRIATE FLAG.
;       (SEE ERROR RETURNS).
;
;   REGISTERS ON EXIT:
;
;        A = CONDITION FLAG (SEE ERROR RETURNS)
;        D = CLOBBERED
;        B,C,H,L = SAME AS ON ENTRY
;
DECR:
        CALL    GCHAR           ;GET CHAR WITH SIGN EXTENDED
        CP      MINCH           ;COMPARE WITH MIN CHAR PERMITTED
        JP      Z,UFLW1         ;DECREMENT WOULD CAUSE UNDERFLOW
        LD      D,A             ;SAVE EXPONENT IN D
        DEC     D               ;DECREMENT EXPONENT
        JP      INCR2           ;GO STORE IT BACK
;
;   SUBROUTINE AORS
;
;       RETURN S=1 IF BASE 6
;       HAS A 1 IN MSB
;
AORS:
        LD      E,L             ;SAVE BASE
        LD      L,C             ;BASE 6 TO L
        LD      A,(HL)          ;LOAD IT
        OR      A               ;SET FLAGS
        LD      L,E             ;RESTORE BASE
        RET
;
;
;   SUBROUTINE TSTR
;
;       CHECKS C PTR TO SEE IF
;       NLSB !
;       RETURNS Z=1 IF NOT
;       DESTROYS E,D
;
TSTR:
        LD      E,L             ;SAVE BASE
        LD      L,C             ;C PTR TO L
        LD      D,2             ;MASK TO D
        LD      A,(HL)          ;LOAD VALUE
        LD      L,E             ;RESTORE BASE
        AND     D               ;AND VALUE WITH MASK
        RET
;
;
;   SUBROUTINE ACPR
;
;       STORES A IN LOCATION OF CPTR
;       LPTR IN E
;
ACPR:
        LD      E,L             ;SAVE LPTR
        LD      L,C             ;CPTR TO L
        LD      (HL),A          ;STORE A
        LD      L,E             ;RESTORE BASE
        RET
;
;
;   SUBROUTINE DCMP
;
;       COMPARES TWO DOUBLE LENGTH
;       WORDS
;
DCMP:
        LD      A,(HL)          ;NUM MANTA TO A
        LD      E,L             ;SAVE BASE IN E
        LD      L,B             ;BASE 3 TO L
        CP      (HL)            ;COMPARE WITH DEN MANTA
        LD      L,E             ;RETURN BASE TO L
        RET     NZ              ;RETURN IF NOT THE SAME
        INC     L               ;L TO NUM MANTB
        LD      A,(HL)          ;LOAD IT
        LD      L,B             ;DEN MANTB ADD TO L
        INC     L               ;BASE 4 TO L
        CP      (HL)
        LD      L,E
        RET     NZ              ;/***TP EXTENSION
        INC     L               ;NOW CHECK BYTE 3
        INC     L
        LD      A,(HL)          ;GET FOR COMPARE
        LD      L,B
        INC     L
        INC     L               ;BYTE 3 NOW
        CP      (HL)            ;COMPARE
        LD      L,E             ;/***TP - ALL DONE
        RET
;
;
;   SUBROUTINE DIVC
;
;       PERFORMS ONE CYCLE OF DOUBLE
;       PRECISION FLOATING PT DIVIDE
;       ENTER AT ENT1 ON FIRST CYCLE
;       ENTER AT ENT2 ALL THEREAFTER
;
ENT2:
        CALL    DLST            ;SHIFT MOVING DIVIDEND
        JP      C,OVER          ;IF CARRY=1,NUM.GT.D
ENT1:
        CALL    DCMP            ;COMPARE NUM WITH DEN
        JP      NC,OVER         ;IF CARRY NOT SET,NUM.GE.DEN
        RET
OVER:
        CALL    DSUB            ;CALL DOUBLE SUBTRACT
        LD      E,L             ;SAVE BASE IN E
        LD      L,C             ;BASE 6 TO L
        INC     L               ;BASE 7 TO L
        INC     L               ;/***TP
        LD      A,(HL)
        ADD     A,1             ;ADD 1
        LD      (HL),A          ;PUT IT BACK
        LD      L,E             ;RESTORE BASE TO L
        RET
;
;
;   SUBROUTINE LXFR
;
;       MOVES CPTR TO EPTR
;       MOVES 3 WORDS IF ENTER AT LXFR
;
LXFR:
        LD      D,4             ;MOVE 4 WORDS
REP5:
        LD      L,C             ;CPTR TO L
        LD      A,(HL)             ;CPTR> TO A
        LD      L,E             ;EPTR TO L
        LD      (HL),A
        INC     C               ;INCREMENT C
        INC     E               ;INCREMENT E TO NEXT
        DEC     D               ;TEST FOR DONE
        JP      NZ,REP5         ;GO FOR FOR TILL D=0
        LD      A,E             ;NOW RESET C AND E
        SUB     4               ;RESET BACK BY 4
        LD      E,A             ;PUT BACK IN E
        LD      A,C             ;NOW RESET C
        SUB     4               ;BY 4
        LD      C,A             ;BACK TO C
        RET                     ;DONE
;
;   SUBROUTINE LDCP
;
;       THIS SUBROUTINE COMPUTES THE EXPONENT
;       FOR THE FLOATING DIVIDE ROUTINE
;
;   REGISTERS ON EXIT:
;
;       A = CONDITION FLAG (SEE ERROR RETURNS)
;       D,E = GARBAGE
;       B,C,H,L = SAME AS ON ENTRY
;
;   REGISTERS ON ENTRY:
;
;       (H,B) = ADDRESS OFF DIVISOR
;       (H,C) = ADDRESS OF QUOTIENT
;       (H,L) = ADDRESS OF DIVIDEND
;
LDCP:
        CALL    CFCHE           ;SET E=CHAR(H,B), A=CHAR(H,L)
        SUB     E               ;SUBTRACT TO GET NEW EXPONENT
        JP      CCHK            ;GO CHECK FOR OVER/UNDERFLOW
                                ;AND STORE EXPONENT
;
;
;   SUBROUTINE LMCP
;
;       THIS SUBROUTINE COMPUTES THE EXPONENT
;       FOR THE FLOATING MULTIPLY ROUTINE.
;
;   REGISTERS ON EXIT:
;
;       A = CONDITION FLAG (SEE ERROR RETURNS)
;       D,E = GARBAGE
;       B,C,H,L = SAME AS ON ENTRY
;
;   REGISTERS ON ENTRY:
;
;       (H,B) = ADDRESS OFF MULTIPLICAND
;       (H,C) = ADDRESS OF PRODUCT
;       (H,L) = ADDRESS OF MULTIPLIER
;
LMCP:
        CALL    CFCHE           ;SET E=CHAR(H,B), A=CHAR(H,L)
        ADD     A,E             ;ADD TO GET NEW EXPONENT
                                ;NOW FALL INTO THE ROUTINE
                                ;WHICH CHECKS FOR OVER/UNDERFLOW
                                ;AND STORE EXPONENT
;
;
;   SUBROUTINE CCHK
;
;       THIS SUBROUTINE CHECKS A EXPONENT IN
;       THE ACCUMULATOR FOR OVERFLOW OR UNDERFLOW.
;       IT THEN STORES THE EXPONENT, PRESERVING
;       THE PREVIOUSLY COMPUTED MANTISSA SIGN.
;
;  REGISTERS ON ENTRY:
;
;       (H,L) = ADDRESS OF ONE OPERAND
;       (H,B) = ADDRESS OF OTHER OPERAND
;       (H,C) = ADDRESS OF RESULT
;       A     = NEW EXPONENT OF  RESULT
;
;   REGISTERS ON EXIT:
;
;       A = CONDITION FLAG (SEE ERROR RETURNS)
;       D,E = GARBAGE
;       B,C,H,L = SAME AS ON ENTRY
;
CCHK:                           ;ENTER HERE TO CHECK EXPONENT
        CP      $40  ;100Q      ;CHECK FOR 0 TO +63
        JP      C,STORC         ;JUMP IF OKAY
        CP      $80  ;200Q      ;CHECK FOR +64 TO +127
        JP      C,OFLWC         ;JUMP IF OVERFLOW
        CP      $C0  ;300Q      ;CHECK FOR -128 TO -65
        JP      C,UFLWC         ;JUMP IF UNDERFLOW
STORC:
        LD      E,L             ;SAVE L IN E
        LD      L,C             ;LET L POINT TO RESULT
        LD      D,A             ;SAVE EXPONENT IN D
        CALL    INCR3           ;STORE EXPONENT
        LD      L,E             ;RESTORE L
        RET                     ;RETURN
;
;   SUBROUTINE OFLWC
;
;       THIS ROUTINE WRITES A FLOATING POINT OVERFLOW AT (H,C)
;       SETS THE CONDITION FLAG, AND RETURNS.
;
OFLWC:
        LD      E,L             ;SAVE L IN E
        LD      L,C             ;SET L=CPTR, SO (H,L)=ADDR OF RESULT
        CALL    WOVR            ;WRITE OUT OVERFLOW
        LD      L,E             ;RESTORE L
        RET                     ;RETURN
;
;   SUBROUTINE UFLWC
;
;       THIS ROUTINE WRITES A FLOATING POINT UNDERFLOW AT (H,C)
;       SETS THE CONDITION FLAG, AND RETURNS.
;
UFLWC:
        LD      E,L             ;SAVE L IN E
        LD      L,C             ;SET L=CPTR, SO (H,L)=ADDR OF RESULT
        CALL    WUND            ;WRITE OUT UNDERFLOW
        LD      L,E             ;RESTORE L
        RET                     ;RETURN
;
;
;   SUBROUTINE CSIGN
;
;       THIS SUBROUTINE COMPUTES AND STORE THE MANTISSA
;       SIGN FOR THE FLOATING MULTIPLY AND DIVIDE ROUTINES
;
;   REGISTERS ON ENTRY:
;
;       (H,L) = ADDRESS OF ONE OPERAND
;       (H,B) = ADDRESS OF OTHER OPERAND
;       (H,C) = ADDRESS OF RESULT
;
;   REGISTERS ON EXIT:
;
;       A,D,E = GARBAGE
;       B,C,H,L = SAME AS ON ENTRY
;
;
CSIGN:
        CALL    MSFH            ;SET A=SIGN(H,L), E=SIGN(H,B)
        XOR     E               ;EXCLUSIVE OR SIGNS TO GET NEW SIGN
        CALL    CSTR            ;STORE SIGN INTO RESULT
        RET                     ;RETURN
;
;
;   SUBROUTINE CSTR
;
;       STORES VALUE IN A IN
;       CPTR 2
;       PUTS LPTR IN E
;
CSTR:
        LD      E,L             ;SAVE LPTR IN E
        LD      L,C             ;CPTR TO L
        INC     L               ;CPTR\2
        INC     L               ;TO L
        INC     L               ;/***TP
        LD      (HL),A          ;STORE ANSWER
        LD      L,E             ;LPTR BACK TO L
        RET
;
;   SUBROUTINE MSFH
;
;       THIS SUBROUTINE FETCHES THE SIGNS OF THE MANTISSAS
;       OF THE FLOATING POINT NUMBERS POINTED TO BY (H,L)
;       AND (H,B) INTO THE A AND E REGISTERS RESPECTIVELY.
;
;   REGISTERS ON EXIT:
;
;       A = SIGN  OF MANTISSA OF (H,L)
;       E = SIGN OF MANTISSA OF (H,B)
;       B,C,D,H,L = SAME AS ON ENTRY
;
MSFH:
        LD      E,L             ;SAVE LPTR
        LD      L,B             ;BPTR TO L
        INC     L               ;BPTR\2
        INC     L               ;/***TP
        INC     L               ;TO L
        LD      A,(HL)          ;BPTR 2>TO A
        AND     128             ;SAVE MANT SIGN
        LD      L,E             ;LPTR BACK TO L
        LD      E,A             ;STORE BPTR MANT SIGN
        INC     L               ;LPTR\2
        INC     L               ;/***TP
        INC     L               ;TO L
        LD      A,(HL)          ;LPTR\2>TO A
        AND     128             ;SAVE LPTR MANT SIGN
        DEC     L               ;LPTR BACK
        DEC     L               ;TO L
        DEC     L               ;/***TP
        RET
;
;
;   SUBROUTINE BCTL
;
;           MOVES BPTR CHAR TO LPTR CHAR
;           DESTROYS E
;
BCTL:
        LD      E,L             ;LPTR TO E
        LD      L,B             ;BPTR TO L
        INC     L               ;BPTR 2
        INC     L               ;/***TP
        INC     L               ;TO L
        LD      A,(HL)          ;BPTR CHAR TO A
        LD      L,E             ;LPTR TO L
        INC     L               ;LPTR 2
        INC     L               ;TO L
        INC     L               ;/***TP
        LD      (HL),A          ;STORE BPTR CHAR IN LPTR CHAR
        LD      L,E             ;LPTR TO L
        RET
;
;HRJ for some reason the square root routine was not included
;
;
;       SUBROUTINE DSQRT
;
;       THE L REG PTS TO THE    TO BE
;       OPERATED ON.
;       THE B REG PTS TO THE LOC WHERE
;       THE RESULT IS TO BE STORED
;       THE C REG PTS TO 17(10) SCRATCH 
;       AREA.
;       WHERE:
;       C = ITERATION COUNT
;       C+1 = L REG
;       C+2 = B REG
;       C+3 TO C+6 = INTRL REG 1
;       C+7 TO C+10 = INTRL REG 2
;       C+11 TO C+14 = INTRL REG 3
;       C+15 = 
;
DSQRT:
        LD      A,L             ;STORE L IN
        LD      L,C             ;2ND WRD SCRATCH
        LD      (HL),0          ;INITIALIZE ITER COUNT
        INC     L
        LD      (HL),A
        INC     L               ;STR B IN 3RD
        LD      (HL),B          ;WRD OF SCRATCH
        INC     L               ;SET C TO INTRL
        LD      C,L             ;REG I
        LD      L,A             ;SET L PRT AT
        LD      A,H             ;SET REGS FOR COPY
        CALL    COPY            ;COPY TC INTRL REG1
        CALL    GCHR            ;PUT CHR IN A
        LD      B,A             ;MAKE COPY
        AND     $80  ;200Q      ;OK NEG
        JP      NZ,ERSQ
        LD      A,B
        AND     $40  ;100Q      ;OK NEG EXP
        LD      A,B
        JP      Z,EPOS
        RRA                     ;DIV BY 2
        AND     $7F  ;177Q
        OR      $40  ;100Q      ;SET SIGN BIT
        LD      (HL),A          ;SAVE 1ST APPROX
        JP      AGN4

EPOS:
        RRA                     ;DIV BY 2
        AND     $7F  ;177Q
        LD      (HL),A          ;SAVE 1ST APPROX
AGN4:
        LD      L,C             ;SET REGS
        LD      A,C             ;TO COPY 1ST
        ADD     A,4             ;APPROX
        LD      C,A             ;INTO INTRL REG 2
        LD      A,H             ;FRM INTRL REG1
        CALL    COPY
        LD      A,C
        SUB     4               ;MULTIPLY INTRL REG 1
        LD      L,A
        LD      B,C             ;TIME INTRL REG2
        ADD     A,$8  ;10Q      ;PLACE RESULT IN
        LD      C,A             ;INMTRL REG 3
        CALL    LMUL
        LD      A,C
        SUB     $8  ;10Q        ;COPY ORG INTO
        LD      C,A             ;INTRL REG 1
        SUB     2
        LD      L,A
        LD      L,(HL)
        LD      A,H
        CALL    COPY
        LD      A,C
        ADD     A,$8  ;10Q      ;ADD INTRL
        LD      L,A             ;REG3 OT
        LD      B,C             ;INTRL REG1
        ADD     A,4             ;ANS TO INTRL
        LD      C,A             ;REG3
        CALL    LADD
        LD      A,L
        SUB     4               ;DIV INTRL REG 3
        LD      B,A             ;BY INTRL REG 2
        SUB     4               ;PUT ANSR IN INTRL
        LD      C,A             ;REG1
        CALL    LDIV
        CALL    GCHR
        SUB     1
        AND     $7F  ;177Q
        LD      (HL),A
        LD      A,C
        SUB     3               ;C PTS TO INTRL REG 1
        LD      L,A             ;GET INTR
        LD      B,(HL)             ;COUNT NOW INCR
        INC     B
        LD      (HL),B
        LD      A,B
        CP      5               ;IF = 5 RTN ANS
        JP      NZ,AGN4         ;OTHERWISE CONT
        LD      L,C
ALDN:
        DEC     L               ;COPY ANS INTO
        LD      C,(HL)          ;LOC REQUESTED
        INC     L
        LD      A,H
        CALL    COPY
        RET

ERSQ:
        LD      L,C
        CALL    WZER            ;WRITE A FLOATING ZERO
        JP      ALDN
;                        ; C+1 = L REG
;
;******************************************************
;       //// 5 DIGIT FLOATING PT. OUTPUT
;******************************************************
;
;
;       ROUTINE TO CONVERT FLOATING PT.
;       NUMBERS TO ASCII AND OUTPUT THEM VIA A SUBROUTINE
;       CALLED OUTR  -  NOTE: THIS IS CURRENTLY SET
;       TO ODT'S OUTPUT ROUTINE
;
CVRT:
        CALL    ZCHK            ;CHECK FOR NEW ZERO
        JP      NZ,NNZRO        ;NOT ZERO
        INC     C               ;IT WAS, OFFSET C BY 2
        INC     C
        LD      L,C
        CALL    WZER            ;WRITE ZERO
        CALL    SIGN            ;SEND SPACE ON POS ZERO [HRJ: was missing]
        INC     L               ;PNT TO DECIMAL EXPONENT
        INC     L
        INC     L
        INC     L
        XOR     A               ;SET IT TO ZERO
        LD      (HL),A
        JP      MDSKP           ;OUTPUT IT

NNZRO:
        LD      D,(HL)          ;GET THE NUMBER TO CONVERT
        INC     L
        LD      B,(HL)
        INC     L
        LD      E,(HL)
        INC     L               ;4 WORD***TP
        LD      A,(HL)          ;/***TP
        INC     C               ;OFFSET SCRATCH POINTER BY 2
        INC     C
        LD      L,C             ;L NOT NEEDED ANY MORE
        LD      (HL),D          ;SAVE NUMBER IN SCRATCH
        INC     L
        LD      (HL),B
        INC     L
        LD      (HL),E          ;/***TP
        INC     L               ;/***TP
        LD      B,A             ;SAVE COPY OF CHAR & SIGN
        AND     $7F  ;177Q      ;GET ONLY CHAR.
        LD      (HL),A          ;SAVE ABS(NUMBER)
        CP      $40  ;100Q      ;CK FOR ZERO
        JP      Z,NZRO
        SUB     1               ;GET SIGN OF DEC. EXP
        AND     $40  ;100Q      ;GET SIGN OF CHAR.
NZRO:
        RLCA                    ;MOVE IT TO SIGN POSITION
        INC     L               ;MOVE TO DECIMAL EXP.
        LD      (HL),A          ;SAVE SIGN OF EXP.
        LD      A,B             ;GET MANT. SIGH BACK
        CALL    SIGN            ;OUTPUT SIGN
        LD      L,TEN5 & $FF  ;377Q  ;TRY MULT. OR DIV. BY 100000 FIRST
        CALL    COPT            ;MAKE A COPY IN RAM
TST8:
        CALL    GCHR            ;GET CHAR. OF NUMBER
        LD      B,A             ;SAVE A COPY
        AND     $40  ;100Q      ;GET ABSOLUTE VALUE OF CHAR
        LD      A,B             ;IN CASE PLUS
        JP      Z,GOTV          ;ALREADY PLUS
        LD      A,$80  ;200Q    ;MAKE MINUS INTO PLUS
        SUB     B               ;PLUS=200B-CHAR
GOTV:
        CP      $12  ;22Q       ;TEST FOR USE OF 100000
        JP      M,TRY1          ;WONT GO
        CALL    MORD            ;WILL GO SO DO IT
        ADD     A,5             ;INCREMENT DEC. EXPONENT BY 5
        LD      (HL),A          ;UPDATE MEM
        JP     TST8             ;GO TRY AGAIN

TRY1:
        LD      L,TEN & $FF  ;377Q  ;NOW USE JUST TEN
        CALL    COPT            ;PUT IT IN RAM
TST1:
        CALL    GCHR            ;GET EXPONENT
        CP     1                ;MUST GET IN RANGE 1 TO 6
        JP      P,OK1           ;AT LEAST ITS 1 OR BIGGER

MDGN:
        CALL    MORD            ;MUST MUL OF DIV BY 10
        ADD     A,1             ;INCREMENT DECIMAL EXP.
        LD      (HL),A          ;UPDATE MEM
        JP      TST1            ;NOW TRY AGAIN

OK1:
        CP     7                ;TEST FOR LESS THAN 7
        JP      P,MDGN          ;NOPE - 7 OR GREATER

MDSKP:
        LD      L,C             ;SET UP DIGIT COUNT
        DEC     L
        DEC     L               ;IN 1ST WORD OF SCRATCH
        LD      (HL),5          ;5 DIGITS
        LD      E,A             ;SAVE CHAR. AS LEFT SHIFT COUNT
        CALL    LSFT            ;SHIFT LEFT PROPER NUMBER
        CP      $0A  ;12Q       ;TEST FOR 2 DIGITS HERE
        JP      P,TWOD          ;JMP IF 2 DIGITS TO OUTPUT
        CALL    DIGO            ;OUTPUT FIRST DIGIT
POPD:
        CALL    MULTT           ;MULTIPLY THE NUMBER BY 10
INPOP:
        CALL    DIGO            ;PRINT DIGIT IN A
        JP      NZ,POPD         ;MORE DIGITS?
        LD      A,$C5  ;305Q    ;NO SO PRINT E
        CALL    OUTR            ;BASIC CALL TO OUTPUT
        CALL    GETEX           ;GET DECIMAL EXP
        LD      B,A             ;SAVE A COPY
        CALL    SIGN            ;OUTPUT SIGN
        LD      A,B             ;GET EXP BACK
        AND     $3F  ;77Q       ;GET GOOD BITS
        CALL    CTWO            ;GO CONVERT 2 DIGITS
DIGO:
        ADD     A,$B0  ;260Q    ;MAKE A INTO ASCII
        CALL    OUTR            ;OUTPUT DIGIT
        LD      L,C             ;GET DIGIT COUNT
        DEC     L               ;BACK UP TO DIGIT COUNT
        DEC     L
        LD      A,(HL)          ;TEST FOR DECIMAL PT
        CP      5               ;PRINT . AFTER 1ST DIGIT
        LD      A,$AE  ;256Q    ;JUST IN CASE
        CALL	Z,OUTR          ;OUTPUT . IF 1ST DIGIT
        LD      D,(HL)          ;NOW DECREMENT DIGIT COUNT
        DEC     D
        LD      (HL),D          ;UPDATE MEM AND LEAVE FLOPS SET
        RET                     ;SERVES AS TERM FOR DIGO & CVRT

MULTT:
        LD      E,1             ;MULT. BY 10 (START WITH X2)
        CALL    LSFT            ;LEFT SHIFT 1 = X2
        LD      L,C             ;SAVE X2 IN "RESULT"
        DEC     L               ;SET TO TOP OF NUMBER
        LD      A,C             ;SET C TO RESULT
        ADD     A,$09  ;11Q
        LD      C,A             ;NOW C SET RIGHT
        LD      A,H             ;SHOW RAM TO RAM TRANSFER
        CALL    COPY            ;SAVE X2 FINALLY
        LD      A,C             ;MUST RESET C
        SUB     $09  ;11Q       ;BACK TO NORMAL
        LD      C,A
        LD      E,2             ;NOW GET (X2)X4=X8
        LD      L,C             ;BUT MUST SAVE OVERFLOW
        DEC     L
        CALL    TLP2            ;GET X8
        LD      L,C             ;SET UP TO CALL DADD
        LD      A,C             ;SET B TO X2
        ADD     A,$0A  ;12Q     ;TO X2
        LD      B,A
        CALL    DADD            ;ADD TWO LOW WORDS
        DEC     L               ;BACK UP TO OVERFLOW
        LD      A,(HL)          ;GET IT
        LD      L,B             ;NOW SET TO X2 OVERFLOW
        DEC     L               ;ITS AT B-1
        ADC     A,(HL)          ;ADD WITH CARRY - CARRY WAS PRESERVED
        RET                     ;ALL DONE, RETURN OVERFLOW IN A

LSFT:
        LD      L,C             ;SET PTR FOR LEFT SHIFT OF NUMBER
        DEC     L               ;BACK UP TO OVERFLOW
        XOR     A               ;OVERFLOW=0 1ST TIME
TLOOP:
        LD      (HL),A          ;SAVE OVERFLOW
TLP2:
        DEC     E               ;TEST FOR DONE
        RET	M                   ;DONE WHEN E MINUS
        INC     L               ;MOVE TO LOW
        INC     L
        INC     L               ;/***TP EXTENSION
        LD      A,(HL)          ;SHIFT LEFT 4 BYTES
        RLA
        LD      (HL),A          ;PUT BACK
        DEC     L               ;/***TP - ALL DONE
        LD      A,(HL)          ;GET LOW
        RLA                     ;SHIFT LEFT 1
        LD      (HL),A          ;RESTORE IT
        DEC     L               ;BACK UP TO HIGH
        LD      A,(HL)          ;GET HIGH
        RLA                     ;SHIFT IT LEFT WITH CARRY
        LD      (HL),A          ;PUT IT BACK
        DEC     L               ;BACK UP TO OVERFLOW
        LD      A,(HL)          ;GET OVERFLOW
        RLA                     ;SHIFT IT LEFT
        JP     TLOOP            ;GO FOR MORE

SIGN:
        AND     $80  ;200Q      ;GET SIGN BIT
        LD      A,$A0  ;240Q    ;SPACE INSTEAD OF PLUS
        JP      Z,PLSV          ;TEST FOR +
        LD      A,$AD  ;255Q    ;NEGATIVE
PLSV:
        CALL    OUTR            ;OUTPUT SIGN
        RET

GCHR:
        LD      L,C             ;GET EXPONENT
GETA:
        INC     L               ;MOVE TO IT
        INC     L
        INC     L               ;/***TP
        LD      A,(HL)             ;FETCH INTO A
        RET                     ;DONE

MORD:
        CALL    GETEX           ;MUL OR DIV DEPENDING ON EXP
        LD      E,A             ;SAVE DECIMAL EXP
        LD      B,L             ;SET UP TO MULT OR DIV
        INC     B               ;NOW BOP POINTER SET
        LD      L,C             ;L POINTS TO NUMBER TO CONVERT
        LD      A,C             ;POINT C AT "RESULT" AREA
        ADD     A,$09  ;11Q     ;IN SCRATCH
        LD      C,A             ;NOW C SET RIGHT
        LD      A,E             ;NOW TEST FOR MUL
        AND     $80  ;200Q      ;TEST NEGATIVE DEC. EXP.
        JP      Z,DIVIT         ;IF EXP IS + THEN DIVIDE
        CALL    LMUL            ;MULT.
FINUP:
        LD      A,C             ;SAVE LOC. OF RESULT
        LD      C,L             ;C=LOC OF NUMBER (IT WAS DESTROYED)
        LD      L,A             ;SET L TO LOC. OF RESULT
        LD      A,H             ;SHOW RAM TO RAM TRANSFER
        CALL    COPY            ;MOVE RESULT TO NUMBER
GETEX:
        LD      L,C             ;NOW GET DECIMAL EXP
        INC     L
        JP     GETA            ;USE PART OF GCHR

DIVIT:
        CALL    LDIV            ;DIVIDE
        JP     FINUP

TWOD:
        CALL    CTWO            ;CONVERT TO 2 DIGITS
        LD      B,A             ;SAVE ONES DIGIT
        CALL    GETEX           ;GET DECIMAL EXP
        LD      E,A             ;SAVE A COPY
        AND     $80  ;200Q      ;TEST FOR NEGATIVE
        JP      Z,ADD1          ;BUMP EXP BY 1 SINCE 2 DIGITS
        DEC     E               ;DECREMENT NEGATIVE EXP SINCE 2 DIGITS
FINIT:
        LD      (HL),E          ;RESTORE EXP WITH NEW VALUE
        LD      A,B             ;NOW DO 2ND DIGIT
        JP      INPOP           ;GO OUT 2ND AND REST OF DIGITS

ADD1:
        INC     E               ;COMPENSATE FOR 2 DIGITS
        JP     FINIT

CTWO:
        LD      E,$FF  ;377Q    ;CONVERT 2 DIGIT BIN TO BCD
LOOP:
        INC     E               ;ADD UP TENS DIGIT
        SUB     $0A  ;12Q       ;SUBTRACT 10
        JP      P,LOOP          ;TILL NEGATIVE RESULT
        ADD     A,$0A  ;12Q     ;RESTORE ONES DIGIT
        LD      B,A             ;SAVE ONES DIGIT
        LD      A,E             ;GET TENS DIGIT
        CALL    DIGO            ;OUTPUT IT
        LD      A,B             ;SET A TO 2ND DIGIT
        RET

COPT:
        LD      A,C             ;COPY FROM 10N TO RAM
        ADD     A,5
        LD      C,A             ;SET C TO PLACE TO PUT
        LD      A,TEN5/256
        CALL    COPY            ;COPY IT
        LD      A,C             ;NOW RESET C
        SUB     5
        LD      C,A             ;ITS RESET
        RET

COPY:
        LD      B,H             ;SAVE RAM H
        LD      H,A             ;SET TO SOURCE H
        LD      A,(HL)          ;GET 4 WORDS INTO THE REGS.
        INC     L
        LD      D,(HL)
        INC     L
        LD      E,(HL)
        INC     L
        LD      L,(HL)          ;LAST ONE ERASES L
        LD      H,B             ;SET TO DESTINATION RAM
        LD      B,L             ;SAVE 4TH WORD IN B
        LD      L,C             ;SET TO DESTINATION
        LD      (HL),A          ;SAVE FIRST WORD
        INC     L
        LD      A,(HL)          ;SAVE THIS WORD IN A (INPUT SAVES C HERE
        LD      (HL),D          ;NOW PUT 2ND WORD
        INC     L
        LD      (HL),E
        INC     L
        LD      (HL),B          ;ALL 4  COPIED NOW
        RET                     ;ALL DONE

;SECTION     apu_data

;TEN5:  .DB     303Q,120Q,0Q,21Q    ;303240(8) = 100000.
;TEN:   .DB     240Q,0Q,0Q,4Q       ;12(8) = 10

;TEN5:   DEFB    $C3,$50,$00,$11 ;303240(8) = 100000.
;TEN:    DEFB    $A0,$00,$00,$04 ;12(8) = 10

TEN5:   .DB    $C3,$50,$00,$11 ;303240(8) = 100000.
TEN:    .DB    $A0,$00,$00,$04 ;12(8) = 10



;SECTION     apu_library         ;LIBRARY ORIGIN

;
;       SCRATCH MAP FOR I/O CONVERSION ROUTINES
;
;       RELATIVE TO (C+2)USE
;       C-2             DIGIT COUNT
;       C-1             OVERFLOW
;       C               HIGH NUMBER - MANTISSA
;       C+1             LOW NUMBER
;       C+2             EXPONENT
;       C+3             DECIMAL EXPONENT (SIGN & MAG.)
;       C+4             TEN**N
;       C+5             TEN**N
;       C+6             TEN**N
;       C+7             RESULT OF MULT & DIV
;       C+8             AND TEMP FOR X2
;       C+9             "       "
;       C+10            L FOR NUMBER TO GO INTO (INPUT ONLY)
;       C+11            DIGIT JUST INPUT (INPUT ONLY)
;
;
;       /*****BEGIN INPUT*************
;
;
;HRJ was:
;ERR:
;       STC                     ;ERROR FLAG
;       RET                     ;AND RETURN
; replaced with code in (PDF) document HRJ

;
;
;   SUBROUTINE ERR
;
ERR:
        LD      A,$BF  ;277Q    ;ERROR IN INPUT
        CALL    OUTR            ;SEND A ?(SPACE)
        LD      A,$A0  ;240Q    ;
        CALL    OUTR            ;OUTPUT SPACE
        JP      PRMT            ;GO PROMPT USER AND RESTART
;HRJ  end replacing code
;
;********************************************************
;       //// 4 1/2 DIGIT INPUT ROUTINE
;*******************************************************
;
;
;       /L POINTS TO WHERE TO PUT INPUT NUMBER
;       /C POINTS TO 13(10) WORDS OF SCRATCH
;
INPUT:
        LD      B,L             ;SAVE ADDRESS WHERE DATA IS TO GO
        LD      A,C             ;IN SCRATCH
        ADD     A,$0F  ;17Q     ;COMPUTE LOC. IN SCRATCH
        LD      L,A
        LD      (HL),B          ;PUT IT
        INC     C               ;OFFSET SCRATCH POINTER
        INC     C               ;BY 2
PRMT:
        LD      A,$BA  ;272Q    ;PROMPT USER WITH :
        CALL    OUTR            ;OUTPUT :
        CALL    ZROIT           ;ZERO NUMBER
        INC     L               ;AND ZERO
        LD      (HL),A          ;DECIMAL EXPONENT
        CALL    GNUM            ;GET INTEGER PART OF NUM
        CP      $FE  ;376Q      ;TERM=.?
        JP      Z,DECPT         ;YES
TSTEX:
        CP      $15  ;25Q       ;TEST FOR E
        JP      Z,INEXP         ;YES - HANDLE EXP
        CP      $F0  ;360Q      ;TEST FOR SPACE TERM (240B-260B)
        JP      NZ,ERR          ;NOT LEGAL TERM
        CALL    FLTSGN          ;FLOAT # AND SIGN IT
SCALE:
        CALL    GETEX           ;GET DECIMAL EXP
        AND     $7F  ;177Q      ;GET GOOD BITS
        LD      E,A             ;SAVE COPY
        AND     $40  ;100Q      ;GET SIGN OF EXP
        RLCA                    ;INTO SIGN BIT
        OR      A               ;SET FLOPS
        LD      B,A             ;SAVE SIGN
        LD      A,E             ;GET EXP BACK
        JP      Z,APLS          ;JMP IS +
        LD      A,$80  ;200Q    ;MAKE MINUS +
        SUB     E               ;NOW ITS +
APLS:
        ADD     A,B             ;SIGN NUMBER
        LD      (HL),A          ;SAVE EXP (SIGN & MAG.)
        LD      L,TEN5 & $FF    ;377Q  ;TRY MORD WITH 10**5 FIRST
        CALL    COPT            ;TRANSFER TO RAM
        CALL    GETEX           ;GET DECIMAL EXP
INT5:
        AND     $3F  ;77Q       ;GET MAG. OF EXP
        CP      $05  ;5Q        ;TEST FOR USE OF 10**5
        JP      M,TRYTN         ;WONT GO - TRY 10
        CALL    MORD            ;WILL GO SO DO IT
        SUB     $05  ;5Q        ;MAG = MAG -5
        LD      (HL),A          ;UPDATE DEC. EXP IN MEM
        JP      INT5            ;GO TRY AGAIN

TRYTN:
        LD      L,TEN & $FF     ;377Q  ;PUT TEN IN RAM
        CALL    COPT
        CALL    GETEX           ;SET UP FOR LOOP
INT1:
        AND     $3F  ;77Q       ;GET MAGNITUDE
        OR      A               ;TEST FOR 0
        JP      Z,SAVEN         ;DONE, MOVE NUM OUT AND GET OUT
        CALL    MORD            ;NOT DONE - DO 10
        SUB     $01  ;1Q        ;EXP = EXP -1
        LD      (HL),A          ;UPDATE MEM
        JP      INT1            ;TRY AGAIN

DECPT:
        LD      L,C             ;ZERO DIGIT COUNT
        DEC     L               ;SINCE ITS NECESSARY
        DEC     L               ;TO COMPUTE EXP.
        LD      (HL),0          ;ZEROED
        CALL    EP1             ;GNUM IN MIDDLE
        LD      E,A             ;SAVE TERMINATOR
        LD      L,C             ;MOVE DIGIT COUNT TO EXP
        DEC     L               ;BACK UP TO DIGIT COUNT
        DEC     L
        LD      B,(HL)          ;GOT DIGIT COUNT
        CALL    GETEX           ;SET L TO DEC. EXP
        LD      (HL),B          ;PUT EXP
        LD      A,E             ;TERM BACK TO A
        JP      TSTEX           ;TEST FOR E+OR-XX

INEXP:
        CALL    FLTSGN          ;FLOAT AND SIGN NUMBER
        CALL    SAVEN           ;SAVE NUMBER IN (L) TEMP
        CALL    ZROIT           ;ZERO OUT NUM. FOR INPUTTING EXP
        CALL    GNUM            ;NOW INPUT EXPONENT
        CP      $F0  ;360Q      ;TEST FOR SPACE TERM.
        JP      NZ,ERR          ;NOT LEGAL - TRY AGAIN
        LD      L,C             ;GET EXP OUT OF MEM
        INC     L               ;/***TP
        INC     L               ;EXP LIMITED TO 5 BITS
        LD      A,(HL)          ;GET LOWEST 8 BITS
        AND     $1F  ;37Q       ;GET GOOD BITS
        LD      B,A             ;SAVE THEM
        INC     L               ;GET SIGN OF EXP
        LD      A,(HL)          ;INTO A
        OR      A               ;SET FLOPS
        LD      A,B             ;IN CASE NOTHING TO DO
        JP      M,USEIT         ;IF NEG. USE AS +
        LD      A,$00  ;0Q      ;IF + MAKE -
        SUB     B               ;0-X = -X
USEIT:
        INC     L               ;POINT AT EXP
        ADD     A,(HL)          ;GET REAL DEC. EXP
        LD      (HL),A          ;PUT IN MEM
        LD      A,C             ;NOW GET NUMBER BACK
        ADD     A,$0D  ;15Q     ;GET ADD OF L
        LD      L,A             ;L POINTS TO L OF NUMBER
        LD      L,(HL)          ;NOW L POINTS TO NUMBER
        LD      A,H             ;RAM TO RAM COPY
        CALL    COPY            ;COPY IT BACK
        JP      SCALE           ;NOW ADJUST FOR EXP

GNUM:
        CALL    INP             ;GET A CHAR
        CP      $A0  ;240Q      ;IGNORE LEADING SPACES
        JP      Z,GNUM
        CP      $AD  ;255Q      ;TEST FOR -
        JP      NZ,TRYP         ;NOT MINUS
        LD      L,C             ;MINUS SO SET SIGN
        INC     L               ;IN CHAR LOC.
        INC     L               ;/***TP
        INC     L
        LD      (HL),$80  ;200Q ;SET - SIGN
        JP      GNUM

TRYP:
        CP      $AB  ;253Q      ;IGNORE +
        JP      Z,GNUM
TSTN:
        SUB     $B0  ;260Q      ;STRIP ASCII
        RET     M               ;RETURN IF TERM
        CP      $0A  ;12Q       ;TEST FOR NUMBER
        RET     P               ;ILLEGAL
        LD      E,A             ;SAVE DIGIT
        CALL    GETN            ;LOC. OF DIGIT STORAGE TO L
        LD      (HL),E          ;SAVE DIGIT
        CALL    MULTT           ;MULT NUMBER BY 10
        OR      A               ;TEST FOR TOO MANY DIGITS
        RET     NZ              ;TOO MANY DIGITS
        CALL    GETN            ;GET DIGIT
        LD      L,C             ;SET L TO NUMBER
        INC     L
        INC     L               ;/***TP
        ADD     A,(HL)          ;ADD IN THE DIGIT
        LD      (HL),A          ;PUT RESULT BACK
        DEC     L               ;NOW DO HIGH
        LD      A,(HL)          ;GET HIGH TO ADD IN CARRY
        ADC     A,$00  ;0Q      ;ADD IN CARRY
        LD      (HL),A          ;UPDATE HIGH
        DEC     L               ;/***TP EXTENSION
        LD      A,(HL)
        ADC     A,$00  ;0Q      ;ADD IN CARRY
        LD      (HL),A          ;/***TP ALL DONE
        RET     C               ;OVERFLOW ERROR
        DEC     L               ;BUMP DIGIT COUNT NOW
        DEC     L
        LD      B,(HL)          ;GET DIGIT COUNT
        INC     B               ;BUMP DIGIT COUNT
        LD      (HL),B          ;UPDATE DIGIT COUNT
EP1:
        CALL    INP             ;GET NEXT CHAR
        JP      TSTN            ;MUST BE NUM. OR TERM

FLTSGN:
        LD      L,C             ;POINT L AT NUMBER TO FLOAT
        JP      FLOAT           ;GO FLOAT IT

SAVEN:
        LD      A,C             ;PUT NUMBER IN (L)
        ADD     A,$0D  ;15Q     ;GET ADD OF L
        LD      L,A
        LD      E,(HL)          ;GET L OF RESULT
        LD      L,E             ;POINT L AT (L)
        INC     L               ;SET TO 2ND WORD TO SAVE C
        LD      (HL),C          ;SAVE C IN (L) +1 SINCE IT WILL BE DESTROYED
        LD      L,C             ;SET UP TO CALL COPY
        LD      C,E             ;NOW L&C SET
        LD      A,H             ;RAM TO RAM COPY
        CALL    COPY            ;COPY TO L
        LD      C,A             ;(L)+1 RETURNED HERE SO SET AS C
        ;ORA    A               ;MAKE SURE CY=0 (NO ERROR) 
                                ;HRJ ORA above not in LLL document
        RET                     ;NOW EVERYTHING HUNKY-DORRY

GETN:
        LD      A,C             ;GET DIGIT
        ADD     A,$0E  ;16Q     ;LAST LOC. IN SCRATCH
        LD      L,A             ;PUT IN L
        LD      A,(HL)          ;GET DIGIT
        RET

ZROIT:
        LD      L,C             ;ZERO NUMBER
        XOR     A
        LD      (HL),A          ;/***TP
        INC     L               ;/***TP
        LD      (HL),A
        INC     L
        LD      (HL),A
        INC     L               ;NOW SET SIGN TO +
        LD      (HL),A
        RET                     ;DONE

;
; END of code from LLNL PDF document
;
        .END
