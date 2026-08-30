;
;   Title:   hbar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   28 Aug 2026
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Draw 4 animated horizontal bars on the front panel LCD
;  Press any key to stop the demo.
;

cmdPort	      .equ	  $DA	 ; port for HD44780 command register
dataPort	  .equ	  $DB	 ; port for HD44780 data register 

; HD44780 Controller Commands 
;
CLEAR_DISPLAY .equ    $01    ; clear screen command
LOAD_SYMBOL   .equ    $40    ; set CG-RAM address
SET_CURSOR    .equ    $80    ; set display RAM address

; program constants
;
COL           .equ 4         ; starting column 
SPEED         .equ 12        ; animation speed (in mS)

.ORG $0100

Start:
    CALL LoadIcons
    CALL ClearScreen
hb3:
    LD   HL,values
    LD   E,0                 ; E = current row
hb2:
    LD   D,(HL)              ; D = current bar value
hb1:
    LD   A,R                 ; get random #
    AND  $3F                 ; mask upper2 bits (max value 63)
    LD   (newValue),A        ; use it as new value
    CP   D                   ; is it same as current?
    JR   Z,hb1               ; if so, pick again
    CALL GetSign 
    CALL AnimateHBar
    CALL ExitOnKeypress
    LD   (HL),D              ; save bar value
    INC  HL                  ; point to value of next row
    INC  E                   ; bump row counter
    LD   A,4                 
    CP   E                   ; get to 4th row yet? 
    JR   NZ,hb2              ; no, go to next row
    CALL ExitOnKeypress
    LD   BC,500
    CALL DELAY_BC            ; short delay before repeating
    JP   hb3                 ; go back to row 0
                             ; and loop until keypress

; Draw a horizontal bar
; Call with C=length of bar to be drawn
;
DrawHBar:
    LD   A,C                 ; look at current value
    SUB  5                   ; remove 5 from it
    LD   C,A                 ; save result
    JR   C,dhb0              ; skip if less than 5
    LD   A,$FF                 
    CALL SendChar            ; draw full 5 bars
    JR   DrawHBar
dhb0:                        ; get here when remainder <5
    RET  Z                   ; if 0, no need to print more
    ADD  A,5                 ; undo last subract
    CALL SendChar            ; print it as 1-4 bars
    RET


; Draw an animated bar
; call with D= current bar length, newValue=final value, sign=-1,+1
; with each loop it incr/decr D according to value of sign byte
; on exit, D=new bar height (D=newValue)
;
AnimateHBar:
    LD   A,E                 ; reset cursor location
    LD   B,COL                
    CALL GotoRC
    LD   C,D
    CALL DrawHBar            ; draw the bar
    LD   BC,SPEED           
    CALL DELAY_BC            ; animation delay
    LD   A,(sign)
    ADD  A,D                 ; incr/decr width by 1 bar
    LD   D,A                 ; update bar width
    LD   A,(newValue)        
    CP   D                   ; compare with new value
    JR   NZ,AnimateHBar      ; loop until NV reached
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


ExitOnKeypress:
    PUSH BC
    PUSH DE 
    PUSH HL
    LD   C,$80               ; for current console.
    LD   B,$02               ; check char input buffer
    RST  08                  ; call the HBIOS routine
    POP  HL
    POP  DE
    POP  BC 
    RET  Z                   ; nothing waiting, so return
    CALL ClearScreen         ; clear the screen
    JP  0                    ; & return to CP/M


LoadIcons:
    LD   A,LOAD_SYMBOL     
    CALL SendCommand         ; send "set CGRAM address=0" cmd
    LD   HL,HBAR0            ; point to icons to be loaded
    LD   B,40                ; sending 40 bytes = 5 icons
li0:
    LD   A,(HL)              ; get icon data byte
    Call SendChar            ; send it
    INC  HL                  ; point to next byte
    DJNZ li0                 ; loop until all sent
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

SendString:
	LD	A,(HL)			     ; next character to send
	OR	A			         ; set flags
	RET	Z			         ; done on null
	CALL SendChar            ; send the character
	INC	HL			         ; point to next char
	JR	SendString    	     ; and loop until done


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
;
; THESE ROUTINES ARE BASED ON A Z-80 CPU CLOCK OF 7.3728 MHz
; At that frequency, each T-state takes 0.1356 uS.
; 1 millisecond delay requires 7373 T-states.
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

HBAR0     .DB $00,$00,$00,$00,$00,$00,$00,$00
HBAR1     .DB $10,$10,$10,$10,$10,$10,$10,$10
HBAR2     .DB $18,$18,$18,$18,$18,$18,$18,$18
HBAR3     .DB $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C
HBAR4     .DB $1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E

LINEDAT   .DB $00,$40,$14,$54

;=============================================================
;
;   PROGRAM VARIABLES
;

sign      .DB 0
newValue  .DB 0
values    .DB 0,0,0,0

.END