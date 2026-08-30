;
;   Title:   vbar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   28 Aug 2026
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Show animated vertical bars on a 20x4 character LCD module.
;  verical bars can be up to 4 rows x 8 units/row = 32 units in height
;

cmdPort	      .equ	  $DA	 ; port for SIO Channel A cmd/status
dataPort	  .equ	  $DB	 ; port for SIO Channel A data  

; HD44780 Controller Commands 
;
CLEAR_DISPLAY .equ    $01    ; clear screen command
LOAD_SYMBOL   .equ    $40    ; set CG-RAM address
SET_CURSOR    .equ    $80    ; set display RAM address

; program constants
;
LMARGIN       .equ 4         ; starting column for vertical bars
NUMBARS       .equ 16        ; number of vertical bars to show
SPEED         .equ 12        ; animation speed (in mS)

.ORG $0100

Start:
    CALL LoadIcons           ; load icons needed for vbars
    CALL ClearScreen
L03:
    LD   HL,values           ; first bar value
    LD   E,0                 ; first bar (E is bar counter)
L02:
    LD   D,(HL)              ; load current bar value
L01:
    LD   A,R                 ; get random #
    AND  $1F                 ; mask upper3 bits (max value 31)
    LD   (newValue),A        ; use it as new value
    CP   D                   ; is it same as current?
    JR   Z,L01               ; if so, pick again
    CALL GetSign 
    CALL AnimateVBar
    LD   (HL),D              ; save bar value               
    CALL ExitOnKeypress      ; see if user wants to quit
    INC  HL                  ; point to value of next bar
    INC  E                   ; bump bar counter
    LD   A,NUMBARS                 
    CP   E                   ; done with last bar yet? 
    JR   NZ,L02              ; no, go to next bar
    LD   BC,1000
    CALL DELAY_BC            ; 1 second delay before repeating
    JP   L03                 ; go back to first bar
                             ; and loop until keypress

LoadIcons:
    LD   A,LOAD_SYMBOL     
    CALL SendCommand         ; send "set CGRAM address=0" cmd
    LD   HL,VBAR0            ; point to icons to be loaded
    LD   B,64                ; sending 40 bytes = 5 icons
li0:
    LD   A,(HL)              ; get icon data byte
    Call SendChar            ; send it
    INC  HL                  ; point to next byte
    DJNZ li0                 ; loop until all sent
    RET 

; call with D=bar height, newValue=final value, sign=-1,+1
; each loop with incr/decr D according to sign
; on exit, D=new bar height (D=newValue)
;
AnimateVBar:
    LD   A,LMARGIN           ; left margin
    ADD  A,E                 ; add in bar counter
    LD   B,A                 ; to use as column #
    LD   A,3                 ; start vbar on bottom row                             
    CALL GotoRC
    LD   C,D
    CALL DrawVBar            ; draw the bar
    PUSH BC 
    LD   BC,SPEED           
    CALL DELAY_BC            ; animation delay
    POP  BC 
    LD   A,(sign)
    ADD  A,D                 ; incr/decr width by 1 bar
    LD   D,A                 ; update bar width
    LD   A,(newValue)        
    CP   D                   ; compare with new value
    JR   NZ,AnimateVBar      ; loop until NV reached
    RET

; call with current value in D, new value in newValue
; return with sign in A
GetSign:
    LD   A,(newValue)
    SUB  D
    JR   Z,GS2
    JR   C,GS1
    LD   A,1
    JR   GS3 
GS1:
    LD   A,$FF
    JR   GS3
GS2: 
    LD   A,0
GS3:
    LD   (sign),A
    RET 

DrawVBar:
    PUSH AF                  ; save A=row on stack
    LD   A,C                 ; look at current value
    SUB  8                   ; remove 8 from it
    LD   C,A                 ; save result
    JR   C,dvb0              ; skip if less than 8
    LD   A,$FF                 
    CALL SendChar            ; draw full 8 bars
    POP  AF                  ; restore row
    DEC  A                   ; go up one row
    CALL GotoRC              ; and set cursor there
    JR   DrawVBar
dvb0:                        ; get here when remainder <8
    ADD  A,8                 ; undo last subract
    CALL SendChar            ; print it as 1-7 bars
    POP  AF                  ; restore row
    RET

ExitOnKeypress:
    PUSH BC
    PUSH DE 
    PUSH HL
    LD  C,$80                ; for current console.
    LD  B,$02                ; check char input buffer
    RST 08                   ; call the HBIOS routine
    POP HL
    POP DE
    POP BC 
    RET Z                    ; nothing waiting, so return
    CALL ClearScreen
    JP  0                    ; return to CP/M

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


; DELAY ROUTINES
;
; THESE ROUTINES ARE BASED ON A Z-80 CPU CLOCK OF 7.3728 MHz
; At that frequency, each T-state takes 0.1356 uS.
; 1 millisecond delay requires 7373 T-states.

; DELAY_INNER:
; Desired length = 7348T, slightly shorter than 1mS
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

VBAR0     .DB $00,$00,$00,$00,$00,$00,$00,$00
VBAR1     .DB $00,$00,$00,$00,$00,$00,$00,$1F
VBAR2     .DB $00,$00,$00,$00,$00,$00,$1F,$1F
VBAR3     .DB $00,$00,$00,$00,$00,$1F,$1F,$1F
VBAR4     .DB $00,$00,$00,$00,$1F,$1F,$1F,$1F
VBAR5     .DB $00,$00,$00,$1F,$1F,$1F,$1F,$1F
VBAR6     .DB $00,$00,$1F,$1F,$1F,$1F,$1F,$1F
VBAR7     .DB $00,$1F,$1F,$1F,$1F,$1F,$1F,$1F

LINEDAT   .DB $00,$40,$14,$54

;=============================================================
;
;   PROGRAM VARIABLES
;

sign      .DB 0
newValue  .DB 0
values    .DB 0,0,0,0, 0,0,0,0
          .DB 0,0,0,0, 0,0,0,0

.END

