;
;   Title:   clock6.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   28 Aug 2026
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Display a large, 6-digit clock on the front panel LCD
;

cmdPort	      .equ	  $DA	 ; port for HD44780 command register
dataPort	  .equ	  $DB	 ; port for HD44780 data register 

; HD44780 Controller Commands 
;
CLEAR_DISPLAY .equ    $01    ; clear screen command
LOAD_SYMBOL   .equ    $40    ; set CG-RAM address
SET_CURSOR    .equ    $80    ; set display RAM address


.ORG $0100

Start:
    CALL ClearScreen
    CALL LoadIcons           ; load big digit icons
j0:
    CALL ExitOnKeypress
    CALL DisplayTimeHMS      ; alternate: DisplayTimeHM
    CALL WaitOneSecond
    CALL AdvanceTime
    JP   j0 

ExitOnKeypress:
    LD   C,$80               ; for current console.
    LD   B,$02               ; check char input buffer
    RST  08                  ; call the HBIOS routine
    RET  Z                   ; nothing waiting, so return
    CALL ClearScreen         ; erase clock display
    JP  0                    ; & return to CP/M

LoadIcons:
    LD   A,LOAD_SYMBOL     
    CALL SendCommand         ; send "set CGRAM address=0" cmd
    LD   HL,BD_ICONS         ; point to icons to be loaded
    LD   B,64                ; sending 64 bytes = 8 icons
li0:
    LD   A,(HL)              ; get icon data byte
    Call SendChar            ; send it
    INC  HL                  ; point to next byte
    DJNZ li0                 ; loop until all sent
    RET 


;=============================================================
;
;   CLOCK ROUTINES
;

DisplayTimeHMS:              ; display time as "HH:MM:SS"
    LD   C,0                 ; left margin = column 0
    LD   A,(hours)           ; get current hour
    CALL ShowTwoDigits       ; and show it
    CALL ShowColon           ; ':'
    LD   A,(minutes)         ; get current minutes
    CALL ShowTwoDigits       ; and show it
    CALL ShowColon           ; ':'
    LD   A,(seconds)         ; get current seconds
    CALL ShowTwoDigits       ; and show it
    RET

AdvanceTime:
    LD   A,(seconds)
    INC  A                   ; advance seconds
    CP   60                  ; 60 seconds yet?
    LD   (seconds),A
    RET  NZ 
    LD   A,0                 ; start new minute
    LD   (seconds),A 
    LD   A,(minutes)    
    INC  A                   ; advance minutes
    CP   60                  ; 60 minutes yet?
    LD  (minutes),A 
    RET NZ
    LD  A,0                  ; start new hour
    LD  (minutes),A          
    LD  A,(hours)
    INC A                    ; advance hour
    LD  (hours),A 
    CP  13                   ; 13th hour yet?
    RET NZ 
    LD  A,1             
    LD  (hours),A            ; reset to 01:00
    RET 

; uncomment the first 4 instructions to enable colon flash
;
ShowColon:
    ;LD   A,(seconds)
    ;RR   A                   ; rotate bit0 into carry
    ;LD   D,6                 ; open colons on odd seconds           
    ;JR   C,sc1               ; carry = odd second
    LD   D,7                 ; closed colons (icon#7) on even seconds
sc1:
    LD   A,1
    LD   B,C
    CALL GotoRC              ; position top colon
    LD   A,D                 ; get colon char
    CALL SendChar            ; and display it
    LD   A,2
    LD   B,C
    CALL GotoRC              ; position bottom colon
    LD   A,D                 ; get colon char
    CALL SendChar            ; and display it
    INC  C                   ; update cursor
    RET 


; call with A=a two digit number, C=left margin
; displays the number as two large digits (close together)

ShowTwoDigits:
    PUSH BC 
    CALL TwoDigit             ; break into tens/ones
    POP  BC                   ; restore margin
    LD   A,(tens)             ; get tens digit
    CALL ShowBigDigit         ; and display it
    LD   A,C                  ; tens digit margin
    ADD  A,3                  ; move over 3 spaces
    LD   C,A                  ; for 2nd digit
    LD   A,(ones)             ; get ones digit
    CALL ShowBigDigit         ; and display it
    LD   A,C                  ; get cursor
    ADD  A,3                  ; move over 3 spaces
    LD   C,A                  ; update cursor
    RET 

; Call with A = a two-digit number
; Returns with tens-digit in (tens) and ones-digit in (ones)
; Uses HL and C
TwoDigit:
    LD   C,10
    LD   HL,ones
    LD   (HL),0
    LD   HL,tens
    LD   (HL),0
j06:
    INC  (HL) 
    SUB  C 
    JR   NC,j06
    DEC  (HL)
    ADD  A,C 
    LD   (ones),A
    RET   

WaitOneSecond:
    PUSH BC 
    LD   BC,1000              ; wait 1 second
    CALL DELAY_BC
    POP  BC 
    RET 

; call with A=digit value and C=column offset
;
ShowBigDigit:
    LD   E,12                ; DE = size of each digit defn
    LD   D,0                        
    LD   HL,BIGDIGITS        ; point to digit definitions
    OR   A                   ; is A=0?
    JR   Z,sbd2              ; for digit zero, we are done
    LD   B,A                 ; set up digit counter in B 
sbd1:
    ADD  HL,DE               ; point to next digit defn
    DJNZ sbd1                ; until desired digit reached
sbd2:                        ; now HL = HL + (12*digit)
    LD   DE,digitXY          ; point to icon location array
    LD   B,12                ; each digit is 3x4=12 icons big
sbd3:
    LD   A,(DE)              ; get icon position
    ADD  A,C                 ; add in column offset
    ADD  A,SET_CURSOR        ; make it a command
    CALL SendCommand         ; set icon position
    LD   A,(HL)              ; get icon to display
    CALL SendChar            ; display it
    INC  DE                  ; goto next position
    INC  HL                  ; goto next icon
    DJNZ sbd3                ; loop for all 12 positions
    RET 


;=============================================================
;
;   LCD ROUTINES
;

SendCommand:
    OUT (cmdPort),A          ; send the command
    IN A,(cmdPort)           ; check LCD status (bit 7 = busy)
    RLCA                     ; move status bit to carry 
    JR  C,$-3                ; wait until ready
    RET

SendChar:
    OUT (dataPort),A         ; send a character to LCD
    IN A,(cmdPort)           ; check LCD status (bit 7 = busy)
    RLCA                     ; move status bit to carry 
    JR  C,$-3                ; wait until ready
    RET

ClearScreen:
    LD   A,CLEAR_DISPLAY
    CALL SendCommand
    RET 

; MOVE LCD CURSOR TO A=ROW(0-3), B=COLUMN(0-19)
;
GotoRC:
    PUSH AF
    PUSH DE 
    PUSH HL 
    LD   HL,LINEDAT          ; point to line offset table
    LD   E,A               
    LD   D,0                 ; DE = row
    ADD  HL,DE               ; point to desired line offset
    LD   A,(HL)              ; A now = addr of line start
    ADD  A,B                 ; add in column
    OR   SET_CURSOR          ; add "set DDRAM address"  
    CALL SendCommand         ; send the command
    POP  HL 
    POP  DE
    POP  AF
    RET


;=============================================================
;
;   DELAY ROUTINES
;

; DELAY_INNER:
; This is a helper routine for DELAY_BC.
;
; The desired length = 7348T, slightly shorter than 1mS
; The call itself takes 17T, leaving 7331T in the routine.
; Saving/restoring registers,loading BC and returning takes 41T,
; leaving 7290T for the delay loop.  This is done with
; 303 loops of 24T, plus 18T padding at the end.
; 
DELAY_INNER:
    PUSH BC                 ; 11T
    LD  BC,303              ; 10T
J03:                        ; Loop = 24*bc = 7272T
    DEC BC                  ; 6T
    LD  A,B                 ; 4T
    OR  C                   ; 4T
    JP  NZ,J03              ; 10T 
    INC BC                  ; add +18T padding
    INC BC
    INC BC
    POP BC                  ; 10T
    RET                     ; 10T

; DELAY_BC is called with BC= desired delay in milliseconds
; when finished, BC=0.
;
; Actual Time Delay, in T-states:
; loading BC & calling DELAY_BC:  27T
; DELAY_BC itself:  7372*BC + 31T
; TOTAL = 7372*BC + 58
; For example, 1 second: 7372*1000 + 58 = 7,372,058T (999.9mS)
; 
DELAY_BC:
    PUSH AF                 ; 11T
J04:                        ; bc * 7372T
    CALL DELAY_INNER        ; 7348T
    DEC BC                  ; 6T
    LD  A,B                 ; 4T
    OR  C                   ; 4T
    JP  NZ,J04              ; 10T 
    POP AF                  ; 10T
    RET                     ; 10T 


;=============================================================
;
;   PROGRAM CONSTANTS
;

BD_ICONS  .DB $01,$03,$03,$07,$07,$0F,$0F,$1F  ; lower-rt triangle 
          .DB $10,$18,$18,$1C,$1C,$1E,$1E,$1F  ; lower-lf triangle 
          .DB $1F,$0F,$0F,$07,$07,$03,$03,$01  ; upper-rt triangle 
          .DB $1F,$1E,$1E,$1C,$1C,$18,$18,$10  ; upper-lf triangle 
          .DB $00,$00,$00,$00,$1F,$1F,$1F,$1F  ; lower horiz bar 
          .DB $1F,$1F,$1F,$1F,$00,$00,$00,$00  ; upper horiz bar 
          .DB $00,$0e,$11,$11,$11,$0e,$00,$00  ; open dot 
          .DB $00,$0E,$1f,$1f,$1f,$0e,$00,$00  ; closed dot 

BIGDIGITS .DB $00,$FF,$01,$FF,$20,$FF,$FF,$20,$FF,$02,$FF,$03   ; #0 
          .DB $00,$FF,$20,$20,$FF,$20,$20,$FF,$20,$20,$FF,$20   ; #1 
          .DB $00,$FF,$01,$20,$00,$03,$00,$03,$20,$FF,$FF,$FF   ; #2 
          .DB $00,$FF,$01,$20,$20,$FF,$20,$05,$FF,$02,$FF,$03   ; #3 
          .DB $FF,$20,$FF,$FF,$FF,$FF,$20,$20,$FF,$20,$20,$FF   ; #4 
          .DB $FF,$FF,$FF,$FF,$04,$04,$20,$20,$FF,$FF,$FF,$03   ; #5 
          .DB $00,$FF,$01,$FF,$20,$20,$FF,$05,$01,$02,$FF,$03   ; #6 
          .DB $FF,$FF,$FF,$20,$20,$FF,$20,$20,$FF,$20,$20,$FF   ; #7 
          .DB $00,$FF,$01,$FF,$20,$FF,$FF,$05,$FF,$02,$FF,$03   ; #8 
          .DB $00,$FF,$01,$02,$04,$FF,$20,$20,$FF,$20,$20,$FF   ; #9 

digitXY   .DB $00,$01,$02,$40,$41,$42,$14,$15,$16,$54,$55,$56
LINEDAT   .DB $00,$40,$14,$54

;=============================================================
;
;   PROGRAM VARIABLES
;

tens      .DB 0
ones      .DB 0
seconds   .DB 0
minutes   .DB 34
hours     .DB 12

.END