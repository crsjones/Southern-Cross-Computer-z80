;-----------------------
; Southern Cross SBC
; Compact Flash routines
;-----------------------
;
; Copyright (C) 2025 Craig RS Jones
;
; This program is free software: you can redistribute it and/or modify it under the 
; terms of the GNU General Public License as published by the Free Software Foundation,
; either version 3 of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
; See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with this program. 
; If not, see <https://www.gnu.org/licenses/>.
;
;

;LBA28 temporary registers
LBA0    .DS 1   ;(LBA) 7..0
LBA1    .DS 1   ;(LBA) 15..8
LBA2    .DS 1   ;(LBA) 23..16
LBA3    .DS 1   ;(LBA) 27..24 (bits 3..0)

CFPORT  .ds   1            ;CF register file port
CFDRV   .ds   1            ;primary or secondary drive

; Compact Flash Card task file
CFBASE  .EQU    10H       ;task file base address
CFDATA  .EQU    CFBASE+0  ; byte data register
CFEROR  .EQU    CFBASE+1  ;(read) error register
CFFEAT  .EQU    CFBASE+1  ;(write) feature register
CFSCNT  .EQU    CFBASE+2  ;sector count
CFLBA0  .EQU    CFBASE+3  ;(LBA) 7..0
CFLBA1  .EQU    CFBASE+4  ;(LBA) 15..8
CFLBA2  .EQU    CFBASE+5  ;(LBA) 23..16
CFLBA3  .EQU    CFBASE+6  ;(LBA) select card/27..24 (LBA bits 3..0)
CFSTAT  .EQU    CFBASE+7  ;(read) status
CFCMD   .EQU    CFBASE+7  ;(write) command
 
; CF card commands
CMDSRD  .EQU    20H      ;read sector
CMDSWR  .EQU    30H      ;write sector
CMDSF   .EQU    0EFH     ;set feature
CMDID   .EQU    0ECH     ;identify card
CMDDD   .EQU    90H      ;drive diagnostic

; status register bits
BITBSY  .EQU    7        ;card busy
BITRDY  .EQU    6        ;card ready to accept commands
BITWRF  .EQU    5        ;write fault
BITDSC  .EQU    4        ;card ready to accept new command
BITDRQ  .EQU    3        ;data request
BITERC  .EQU    2        ;data error corrected
;
BITERR  .EQU    0        ;command has an error
;-------------------------------------------
;initialise CF card
; CFDRV = drive number 00h=drive 0, 10h=drive 1
;
; returns
; a=ffh NZ drive initialised
; a=0 Z drive not ready
;-------------------------------------------
CFINIT
        LD    A,(CFDRV)
        AND   10H
        OUT  (CFLBA3),A      ;set the drive

        CALL  CFRDY
        JR    Z,CFINIT2    ;drive not ready

        LD    A,01H       ;enable 8-bit transfers
        OUT   (CFFEAT),A
        LD    A,CMDSF
        OUT   (CFCMD),A   ;set feature command

        CALL  CFBSY

        LD    A,82H       ;disable write cache
        OUT   (CFFEAT),A
        LD    A,CMDSF
        OUT   (CFCMD),A   ;set feature command

        CALL  CFBSY

        LD    A,0FFH
        OR    A           ;a=ffh NZ
CFINIT2
        RET
;---------------------------------------------
; wait until CF card is ready
; the ready bit is cleared at power up going high 
; when the CF card is ready to accept commands
;
; returns a= cfstat, NZ drive is ready
;         a= 0, Z drive not ready
;---------------------------------------------
CFRDY
        LD    HL,500        ;maximum wait time 500ms
CFRDY1
        LD    B,1
        CALL  PWRDLY        ;delay 1ms
        IN    A,(CFSTAT)    ;read card status
;
;test busy bit, no other bit in the status register is valid if
;the busy bit is high.
        BIT   BITBSY,A      ;busy?
        JR    NZ,CFRDY2     ;busy is high
;
;test ready bit, ready bit is low at power up
;and goes high when the drive is ready for a command
        BIT   BITRDY,A      ;ready?
        JR    NZ,CFRDY3     ;ready is high
CFRDY2  DEC   HL
        LD    A,H
        OR    L             ;timer finished?
        JR    NZ,CFRDY1
CFRDY3  RET
;-------------------------------
; wait until CF card is not busy
; return a=cfstat Z CF drive not busy
;-------------------------------
CFBSY
        IN    A,(CFSTAT)    ;read card status
        BIT   BITBSY,A      ;ready?
        JP    NZ,CFBSY
        RET
;-------------------------------------------
; identify drive
;
; CFDRV = C/D/H (LBA3) register
;     set drive B4 = 0  drive 0
;               B4 = 1  drive 1
; (HL) = where to put 256 bytes of data
;
;-------------------------------------------
CFINFO
        LD    A,(CFDRV)
        AND   10H
        OUT  (CFLBA3),A

        CALL  CFBSY

;issue identify drive command
        LD   A,CMDID
        OUT  (CFCMD),A

; read data into buffer
CINFO1
        CALL  CFBSY
        IN    A,(CFSTAT)
        BIT   BITDRQ,A
        RET   Z
        IN    A,(CFDATA)
        LD    (HL),A
        INC   HL
        JR    CINFO1
;-------------------------------------------
; drive diagnostic
;
; returns  A
; 01h = no error detected
; 02h = formatter device error
; 03h = sector buffer error
; 04h = ecc circuitry error
; 05h = controlling microprocessor error
; 8xh = slave failed
;
;-------------------------------------------
CFDIAG
        CALL  CFBSY
        XOR   A             ;command has no valid parameters
        OUT  (CFLBA3),A

; issue the drive diagnostic command
        LD   A,CMDDD
        OUT  (CFCMD),A
;
        CALL  CFBSY
        LD   A,CFEROR       ;get diagnostic codes
        RET
;-------------
;increment LBA
;-------------
; increment the 28 bit LBA 
;
INCLBA  XOR   A                ;clear carry
        LD    A,(LBA0)         ;get the least significaNT LBA
        INC   A                ;increment and
        LD    (LBA0),A         ;save
;
        LD    A,(LBA1)         ;propogate the carry...
        ADC   A,00H
        LD    (LBA1),A
;
        LD    A,(LBA2)
        ADC   A,00H
        LD    (LBA2),A
;
        LD    A,(LBA3)
        ADC   A,00H
        AND   0FH              ;ensure it doesn't overrun
        LD    (LBA3),A
        RET
;-------------------------------------------
; READ
; Entry - 
;         (HL) = Memory Buffer Address
;   LBA3..LBA0 = Logical Block Address
;        CFDRV = primary or secondary drive
;-------------------------------------------
READ
        LD    A,(LBA0)
        OUT   (CFLBA0),A
        LD    A,(LBA1)
        OUT   (CFLBA1),A
        LD    A,(LBA2)
        OUT   (CFLBA2),A
        LD    A,(LBA3)    ;get the high order LBA
        LD    B,A
        LD    A,(CFDRV)   ;get the drive
        OR    B
        OR    0E0H        ;B7=1 B6=1 LBA B5=1 B4= DRIVE HS3-HS0=0
        OUT   (CFLBA3),A
        LD    A,1            ;number of sectors to read
        OUT   (CFSCNT),A

; issue the read command
        LD    A,CMDSRD
        OUT   (CFCMD),A

;read the data from the sector into memory
READ1
        IN    A,(CFSTAT)     ;wait until the 
        BIT   BITBSY,A       ;CF card gets the data... 
        JR    NZ,READ1       ;CF card is still busy

; read in the 512 byte sector data 
        BIT   BITDRQ,A       ;does the CF card have a data byte?
        RET   Z              ;return if done
        IN    A,(CFDATA)     ;read from card,
        LD    (HL),A         ;write to memory,
        INC   HL             ;and inc the ptr
        JR    READ1          ;ready for the next byte
;-------------------------------------------
; Write Sector
; Entry - (HL) = Sector Buffer Address
;   LBA3..LBA0 = Logical Block Address
;        CFDRV = primary or secondary drive
;-------------------------------------------
WRITE
        LD    A,(LBA0)
        OUT   (CFLBA0),A
        LD    A,(LBA1)
        OUT   (CFLBA1),A
        LD    A,(LBA2)
        OUT   (CFLBA2),A
        LD    A,(LBA3)    ;get the high order LBA
        LD    B,A
        LD    A,(CFDRV)   ;get the drive
        OR    B
        OR    0E0H        ;B7=1 B6=1 LBA B5=1 B4= DRIVE HS3-HS0=0
        OUT   (CFLBA3),A
        LD    A,1            ;number of sectors to write
        OUT   (CFSCNT),A

; issue the write command
        LD    A,CMDSWR
        OUT   (CFCMD),A

;write the data from memory to the sector
WRITE1
        IN    A,(CFSTAT)     ;wait until the 
        BIT   BITBSY,A       ;CF card is ready for the data...
        JR    NZ,WRITE1      ;CF card is busy

;write the 512 byte sector data
        BIT   BITDRQ,A       ;does CF card want a data byte?
        RET   Z              ;return if done
        LD    A,(HL)         ;read from memory,
        OUT   (CFDATA),A     ;write to card,
        INC   HL             ;and inc the ptr
        JR    WRITE1         ;ready for the next byte
;
;power up delay
PWRDLY  PUSH  BC       ;11T
        LD    B,233    ;7T
PWRDLY1 NOP            ;4T
        DJNZ  PWRDLY1   ;NZ=13T,Z=8T
        POP   BC       ;10T
        DJNZ  PWRDLY  ;NZ=13T,Z=8T
        RET            ;10T
        .END
