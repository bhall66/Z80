;
;   Title:   fpdemo.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   30 Aug 2026
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Exercise the front panel switches and 20x4 char LCD display
;  The demo is selected by console keypress
;
;  Keypress        Demo
;      0           Switch positions shown on LEDs and LCD
;      1           Multi-line text & random characters
;      2           Animated battery icon
;      3           Large 4-digit clock
;      4           Large 6-digit clock
;      5           Animated sine wave
;      6           Animated vertical bar graph
;      7           Animated horizontal bar graph
;      8           Blinkenlights
;      9           Larson Scanner
;      A           Binary Counting - Increment
;      B           Binary Counting - Decrement
; 
;  Press any other key to stop the demo.
;

cmdPort	      .equ	  $DA	 ; port for HD44780 command register
dataPort	  .equ	  $DB	 ; port for HD44780 data register 

; HD44780 Controller Commands 
;
CLEAR_DISPLAY .equ    $01    ; clear screen command
CURSOR_HOME   .equ    $02    ; home the cursor
DISPLAY_OFF   .equ    $08    ; turn display off
DISPLAY_ON    .equ    $0C    ; display on with no cursor
CURSOR_ON     .equ    $0E    ; display on with underline cursor
CURSOR_BLINK  .equ    $0F    ; display on with blinking block cursor
CURSOR_LEFT   .equ    $10    ; move cursor left
CURSOR_RIGHT  .equ    $14    ; move cursor right
DISP_INIT4    .equ    $28    ; initialize display for 4-bit input
DISP_INIT8    .equ    $38    ; initialize display for 8-bit input
LOAD_SYMBOL   .equ    $40    ; set CG-RAM address
SET_CURSOR    .equ    $80    ; set display RAM address

; program constants
;
LMARGIN       .equ 5         ; starting column for vertical bars
NUMBARS       .equ 15        ; number of vertical bars to show
SPEED         .equ 12        ; animation speed (in mS)

.ORG $0100

Start:
    LD   HL,introMsg         ; point to text
st0:
    CALL PrintStr            ; Print a string
    CALL CRLF                ; Print CRLF (new line)
    INC  HL                  ; Advance to next string
    LD   A,(HL)              ; Look at next character
    CP   '$'                 ; end-of-message marker?
    JR   NZ,st0              ; loop until marker found
                             ; done, fall to Switch demo below

SwitchDemo:
    LD   HL,SWITCH2          ; point to first switch icon
    LD   B,16                ; 16 bytes = 2 icons
    CALL LoadIcons           ; load both icons
    LD   HL,switchMsg
    CALL LabelDemo
dn1:
    CALL HandleUser          ; allow user break
    IN   A,(0)               ; get switch input
    CP   D                   ; still the same?
    JR   Z,dn1               ; loop until different
    LD   D,A                 ; save result 
    OUT  (0),A               ; show result on FP leds
    LD   A,2
    LD   B,10
    CALL GotoRC              ; position cursor 
    LD   B,8                 ; prepare to write 8 chars
dn2:
    XOR  A                   ; assume icon 0
    RL   D                   ; roll bit into carry
    JR   NC,dn3              ; nc = bit is 0
    INC  A                   ; set icon 1
dn3:
    CALL SendChar            ; show the switch icon 
    DJNZ dn2                 ; loop for all 8 bits
    JR   dn1                 ; loop forever


; Check for console input.  Return if no console input waiting.
; Otherwise, attempt to convert keypress to hex digit 0-F and jump to the 
; corresponding demo routine
;
HandleUser:
    CALL CheckKeypress       ; look for console input
    RET  Z                   ; return if no keypress waiting
    OUT  (0),A               ; show result on FP leds
    LD   HL,selection
    CP   (HL)                ; did selection change?
    RET  Z                   ; return if no change
    LD  (HL),A               ; save selection
    POP  BC                  ; remove caller from stack  

    ; At this point, A contains the selected user program, 0-F.
    ; use this value to index into a table of addresses, then jump to
    ; the desired routine.

    LD   HL,vectTable        ; point to the jump table
    SLA  A                   ; A x 2
    LD   D,0 
    LD   E,A                 ; DE = 2A
    ADD  HL,DE               ; HL = jumpTable + 2A
    LD   A,(HL)              ; get LSB
    INC  HL 
    LD   H,(HL)              ; get MSB
    LD   L,A                 ; HL = MSB,LSB
    JP   (HL)                ; go!


;=============================================================
;
;   LED ANIMATION ROUTINES
;

BlinkDemo:
    LD   HL,blinkMsg
    CALL LabelDemo
bl0:
    CALL HandleUser          ; check for user break
    CALL Random              ; A = random number
    OUT  (0),A               ; show it on LEDs
    LD   BC,200
    CALL DELAY_BC            ; animation delay
    JR   bl0                 ; do it forever

IncDemo:
    LD   HL,binUpMsg
    CALL LabelDemo
ld0:  
    CALL HandleUser          ; check for user break
    LD   A,D                 ; D = counter
    OUT (0),A                ; show counter on LEDs
    LD   BC,200
    CALL DELAY_BC            ; animation delay
    INC  D                   ; increment the counter
    JR   ld0                 ; loop forever

DecDemo:
    LD   HL,binDnMsg
    CALL LabelDemo
ld1:  
    CALL HandleUser          ; check for user break
    LD   A,D                 ; D = counter
    OUT (0),A                ; show counter on LEDs
    LD  BC,200
    CALL DELAY_BC            ; animation delay
    DEC D                    ; decrement counter
    JR  ld1                  ; loop forever

CylonDemo:
    LD   HL,cylonMsg
    CALL LabelDemo
ld5:
    LD   A,1 
ld3:
    OUT  (0),A 
    LD   BC,100
    CALL DELAY_BC
    RL   A                   ; rotate left through carry
    JR   NC,ld3 
    RR   A                   ; undo last rotate, 1->b7
ld4:
    OUT  (0),A 
    LD   BC,100
    CALL DELAY_BC
    RR   A                   ; rotate right through carry
    JR   NC,ld4 
    RL   A                   ; undo last rotate, 1->b0
    CALL HandleUser          ; check for user break
    JR   ld5                 ; loop forever


;=============================================================
;
;   BATTERY ANIMATION ROUTINES
;
DoBattery:
    LD   HL,BATT0            ; point to first battery icon
    LD   B,48                ; 48 bytes to load
    CALL LoadIcons           ; load all 6 icons
    LD   HL,iconMsg
    CALL LabelIt             ; "ICON DEMO"
db0:
    LD   D,0                 ; D = icon counter
db1:
    LD   A,1
    LD   B,8
    CALL GotoRC              ; set cursor
    LD   A,D                 ; get icon #
    CALL SendChar            ; and display it
    LD   BC,250
    CALL DELAY_BC            ; animation delay
    CALL HandleUser
    INC  D                   ; advance to next icon
    LD   A,D 
    CP   6                   ; done?
    JR   NZ,db1              ; loop for all icons
    JR   db0                 ; back to first icon


;=============================================================
;
;   SINE WAVE ROUTINES
;
DoWave:
    LD   HL,signMsg
    CALL LabelIt             ; display "Sine Test"
    CALL LoadVBarIcons       ; load icons needed for vbars
    LD   D,0                 ; D is the phase counter
L03:
    LD   E,0                 ; first bar (E is bar counter)
L02:
    LD   A,E 
    ADD  A,D                 ; add in phase offset
    LD   B,15                ; use modulo fn
    CALL IntDiv              ; to force 0-14 range
    CALL GetSine             ; A = 15*sin(A*24)+16
    LD   C,A                 ; save result in C
    LD   A,E 
    ADD  A,LMARGIN           ; left margin
    LD   B,A                 ; to use as column #
    CALL EraseVBar
    CALL DrawVBar            ; show the bar            
    INC  HL                  ; point to value of next bar
    INC  E                   ; bump bar counter
    LD   A,NUMBARS                 
    CP   E                   ; done with last bar yet? 
    JR   NZ,L02              ; no, go to next bar
    INC  D                   ; go to next phase
    CALL HandleUser       ; see if user wants to quit
    LD   BC,200
    CALL DELAY_BC            ; 1 second delay before repeating
    JP   L03                 ; go back to first bar
                             ; and loop until keypress 

LoadVBarIcons:
    LD   HL,VBAR0            ; point to first vbar icon
    LD   B,64                ; load 64 bytes (8 icons)
    CALL LoadIcons
    RET 

; draw a vertical bar with B=column & C=height(0-32)
DrawVBar:
    LD   A,3
    CALL GotoRC              ; position @ bottom of column
DVB2:
    PUSH AF                  ; save A=row on stack
    LD   A,C                 ; look at current value
    SUB  8                   ; remove 8 from it
    LD   C,A                 ; save result
    JR   C,DVB1              ; skip if less than 8
    LD   A,$FF                 
    CALL SendChar            ; draw full 8 bars
    POP  AF                  ; restore row
    DEC  A                   ; go up one row
    CALL GotoRC              ; and set cursor there
    JR   DVB2
DVB1:                        ; get here when remainder <8
    ADD  A,8                 ; undo last subract
    CALL SendChar            ; print it as 1-7 bars
    POP  AF                  ; restore row
    RET

; call with B=col# of the vbar to erase
EraseVBar:
    PUSH BC
    LD   A,3 
ev1:
    CALL GotoRC 
    LD   C,A  
    LD   A,$20
    CALL SendChar
    LD   A,C 
    DEC  A 
    JP   P,ev1
    POP  BC 
    RET 

; return A = 15*sin(24*A)+16, where A is 0-14
; uses HL
GetSine:
    PUSH DE
    LD   D,0
    LD   E,A                 ; DE = A
    LD   HL,sine             ; point to table       
    ADD  HL,DE               ; point to table value
    LD   A,(HL)              ; get table value
    POP  DE
    RET 


;=============================================================
;
;   HBAR ROUTINES

DoHBar:
    LD   HL,HBAR0            ; point to first hbar icon
    LD   B,48                ; load 48 bytes (5 icons)
    CALL LoadIcons
    LD   HL,hbarMsg
    CALL LabelIt             ; display "HBar test"
hb3:
    LD   HL,values
    LD   E,0                 ; row counter
hb2:
    LD   D,(HL)              ; load current bar value
hb1:
    LD   A,R                 ; get random #
    AND  $3F                 ; mask upper2 bits (max value 63)
    LD   (newValue),A        ; use it as new value
    CP   D                   ; is it same as current?
    JR   Z,hb1               ; if so, pick again
    CALL GetSign 
    CALL AnimateHBar
    LD   (HL),D              ; save bar value
    INC  HL                  ; point to value of next row
    INC  E                   ; bump row counter
    LD   A,4                 
    CP   E                   ; get to 4th row yet? 
    JR   NZ,hb2              ; no, go to next row
    CALL HandleUser
    LD   BC,500
    CALL DELAY_BC            ; short delay before repeating
    JP   hb3                 ; go back to row 0
                             ; and loop until keypress

; call with D=bar height, newValue=final value, sign=-1,+1
; each loop with incr/decr D according to sign
; on exit, D=new bar height (D=newValue)
;
AnimateHBar:
    LD   A,E                 ; reset cursor location
    LD   B,LMARGIN               
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

DrawHBar:
    LD   A,C                 ; look at current value
    SUB  5                   ; remove 5 from it
    LD   C,A                 ; save result
    JR   C,dhb0              ; skip if less than 5
    LD   A,5                 
    CALL SendChar            ; draw full 5 bars
    JR   DrawHBar
dhb0:                        ; get here when remainder <5
    RET  Z                   ; if 0, no need to print more
    ADD  A,5                 ; undo last subract
    CALL SendChar            ; print it as 1-4 bars
    RET


;=============================================================
; 
;   VBAR ROUTINES
;

DoVBar:
    LD   HL,vbarMsg
    CALL LabelIt             ; display "VBar Test"
    CALL LoadVBarIcons       ; load icons needed for vbars
vb3:
    LD   HL,values           ; first bar value
    LD   E,0                 ; first bar (E is bar counter)
vb2
    LD   D,(HL)              ; load current bar value
vb1
    LD   A,R                 ; get random #
    AND  $1F                 ; mask upper3 bits (max value 31)
    LD   (newValue),A        ; use it as new value
    CP   D                   ; is it same as current?
    JR   Z,vb1               ; if so, pick again
    CALL GetSign 
    CALL AnimateVBar
    LD   (HL),D              ; save bar value               
    INC  HL                  ; point to value of next bar
    INC  E                   ; bump bar counter
    LD   A,NUMBARS                 
    CP   E                   ; done with last bar yet? 
    JR   NZ,vb2              ; no, go to next bar
    CALL HandleUser       ; see if user wants to quit
    LD   BC,1000
    CALL DELAY_BC            ; 1 second delay before repeating
    JP   vb3                 ; loop forever


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


;=============================================================
;
;   CLOCK ROUTINES
;

Clock1:
    CALL ClearScreen
    CALL LoadDigitIcons      ; load big digit icons
clk1
    CALL DisplayTimeHM
    CALL WaitOneSecond
    CALL AdvanceTime
    CALL HandleUser
    JP   clk1

Clock2:
    CALL ClearScreen
    CALL LoadDigitIcons      ; load big digit icons
clk2:
    CALL DisplayTimeHMS
    CALL WaitOneSecond
    CALL AdvanceTime
    CALL HandleUser
    JP   clk2 

DisplayTimeHM:
    LD   C,0
    LD   A,(hours)
    CALL ShowTwoDigits
    CALL ShowColon
    LD   A,(minutes)
    CALL ShowTwoDigits
    CALL DisplaySeconds
    RET 

DisplayTimeHMS:
    LD   C,0
    LD   A,(hours)
    CALL ShowTwoDigits2
    CALL ShowColon
    LD   A,(minutes)
    CALL ShowTwoDigits2
    CALL ShowColon
    LD   A,(seconds)
    CALL ShowTwoDigits2
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
; displays the number as two large digits

ShowTwoDigits:
    PUSH BC 
    CALL TwoDigit             ; break into tens/ones
    POP  BC                   ; restore margin
    LD   A,(tens)             ; get tens digit
    CALL ShowBigDigit         ; and display it
    LD   A,C                  ; get cursor
    ADD  A,4                  ; move over 4 spaces
    LD   C,A                  ; update cursor
    LD   A,(ones)             ; get ones digit
    CALL ShowBigDigit         ; and display it
    LD   A,C                  ; get cursor
    ADD  A,4                  ; advance 4 spaces
    LD   C,A                  ; update cursor   
    RET 

; call with A=a two digit number, C=left margin
; displays the number as two large digits (close together)

ShowTwoDigits2:
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

DisplaySeconds:
    LD   A,0
    LD   B,18
    CALL GotoRC               ; position seconds
    LD   A,(seconds)          ; get seconds
    CALL TwoDigit             ; split into 2 digits
    LD   A,(tens)             ; get tens digit
    ADD  A,'0'                ; convert it to ASCII
    CALL SendChar             ; and display it
    LD   A,(ones)             ; get the ones digit
    ADD  A,'0'                ; conver it to ASCII
    CALL SendChar             ; and display it
    RET 

WaitOneSecond:
    PUSH BC 
    LD   BC,1000              ; wait 1 second
    CALL DELAY_BC
    POP  BC 
    RET 

LoadDigitIcons:
    LD   HL,BDIGIT0          ; point to first digit icon
    LD   B,64                ; load 64 bytes (8 icons)
    CALL LoadIcons
    RET 

; call with A=digit value and C=column offset
;
ShowBigDigit:
    LD   E,12                ; DE = size of each digit defn
    LD   D,0                        
    LD   HL,bigDigits        ; point to digit definitions
    OR   A                   ; is A=0?
    JR   Z,sbd2              ; for digit zero, we are done
    LD   B,A                 
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


;============================================================
;
;    CHARACTER ROUTINES
;

RandomFill:    
    CALL DoText              ; show some text first
    LD   BC,2000
    CALL DELAY_BC
    LD   HL,charMsg
    CALL LabelIt             ; display "Char Test"
rf0:               
    CALL Random              ; get random position
    PUSH AF 
    SRL  A                   ; /2 (0-127)
    SRL  A                   ; /2 (0-63)
    SRL  A                   ; /2 (0-31)
    SRL  A                   ; /2 (0-15)
    ADD  A,LMARGIN           ; add left margin
    CP   20
    JR   NC,rf0              ; limit column to 0-19
    LD   B,A                 ; save column in B 
    POP  AF 
    AND  $03                 ; row = b1/b0
    CALL GotoRC              ; position the cursor     
rf1:
    CALL Random              ; get random character
    ;CP  $A0 
    ;JR  NC,rf3              ; $A0 and above OK to print
    CP  $80
    JR  NC,rf1               ; $80-$9F are nonprintable
    CP  $20
    JR  C,rf1                ; ignore chars below $20
    CALL SendChar            ; and display it
    LD   BC,25
    CALL DELAY_BC            ; 25mS dwell/character
    CALL HandleUser          ; look for user break
    JR   rf0                 ; otherwise, loop forever


DoText:
    CALL ClearScreen
    LD   HL,textMsg
    LD   E,0
dt0:
    LD   A,E                 ; get character counter
    LD   B,15               
    CALL IntDiv  
    ADD  A,LMARGIN           ; col = count%15 + LMARGIN
    LD   B,A            
    LD   A,C                 ; row = count\15
    CALL GotoRC              ; set cursor position
    LD   BC,60
    CALL DELAY_BC            ; animation delay
    LD   A,(HL)              ; get next char in string
    OR   A                   ; set zero flag
    RET  Z                   ; stop on nul
    CALL SendChar            ; otherwise display it
    INC  HL                  ; point to next char
    INC  E                   ; advance char counter
    JR   dt0                 ; loop


RandFill2:
    CALL Random              ; get a random value
    CP  $A0 
    JR  NC,rf2               ; $A0 and above OK to print
    CP  $80
    JR  NC,RandFill2         ; $80-$9F are nonprintable
    CP  $20
    JR  C,RandFill2          ; $0-$20 are nonprintable
rf2:
    CALL FillChar            ; fill screen with random char
    LD   BC,800
    CALL DELAY_BC            ; dwell for a bit
    CALL HandleUser          ; check for user input
    JR   RandFill2           ; infinite loop


;=============================================================
;
;   CONSOLE ROUTINES
;

; Print a null-terminated string to the console
; Call with HL pointing to the string
; Returns with HL pointing to the null-character
;
PrintStr:
    LD   A,(HL)              ; load next character
    OR   A                   ; is it nul?
    RET  Z                   ; yes, done
    CALL PrintCh             ; no, print the char
    INC  HL                  ; point to next char
    JR   PrintStr            ; and loop until done

; Issue a carriage-return & line-feed to the console
;
CRLF:
    PUSH AF 
    LD   A,13                ; carriage return
    CALL PrintCh             ; send it
    LD   A,10                ; line feed
    CALL PrintCh             ; send it
    POP  AF 
    RET 

; Print a character to the console using BDOS
; Call with A=character to print
;
PrintCh:
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL 
    LD   E,A                 ; E = char to print
    LD   C,2                 ; BDOS function #2
    CALL 5                   ; Do it!
    POP  HL
    POP  DE
    POP  BC
    POP  AF 
    RET 


;=============================================================
;
;   LCD ROUTINES
;

; Send a command to the HD44780 LCD controller
; Call with command in Reg A
;
SendCommand:
    OUT (cmdPort),A          ; send the command
    IN A,(cmdPort)           ; check LCD status (bit 7 = busy)
    RLCA                     ; move status bit to carry 
    JR  C,$-3                ; wait until ready
    RET


; Send a character to the LCD at the current cursor position
; Call with character in Reg A
;
SendChar:
    OUT (dataPort),A         ; send a character to LCD
    IN A,(cmdPort)           ; check LCD status (bit 7 = busy)
    RLCA                     ; move status bit to carry 
    JR  C,$-3                ; wait until ready
    RET


; Clear the LCD screen
;
ClearScreen:
    LD   A,CLEAR_DISPLAY
    CALL SendCommand
    RET 


; Send a string to the LCD at the current cursor position
; Call with HL pointing to the null-terminated string
;
SendString:
	LD	A,(HL)			     ; next character to send
	OR	A			         ; set flags
	RET	Z			         ; done on null
	CALL SendChar            ; send the character
	INC	HL			         ; point to next char
	JR	SendString    	     ; and loop until done


; Load a set of graphic icons into the HD44780 character 
; generator (CG) RAM.  Each icon is 8 bytes in length.
;
; Call with HL = address of first icon to load
;            B = number of bytes to load
;
LoadIcons:
    LD   A,LOAD_SYMBOL     
    CALL SendCommand         ; send "set CGRAM address=0" cmd
li0:
    LD   A,(HL)              ; get icon data byte
    Call SendChar            ; send it
    INC  HL                  ; point to next byte
    DJNZ li0                 ; loop until all sent
    RET 


; Position the LCD cursor at (row,column). 
; Call with A=row (0-3) and B=column (0-19)
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


; Fill the LCD screen with a single character
; Call with character in A
;
FillChar:                    ; call with char to fill in A
    PUSH BC
    LD   C,A                 ; save char in C        
    LD   A, CURSOR_HOME       
    CALL SendCommand         ; home the cursor
    LD   B,80                ; count 80 characters
fc0:           
    LD   A,C                 ; retrieve char
    CALL SendChar            ; send it to display
    DJNZ fc0                 ; repeat until all sent
    POP  BC
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
; For an exact 1mS delay, the call should take 7373 T-states.
; The call itself takes 17T, leaving 7356T in the routine.
; Saving/restoring registers,loading BC and returning takes 62T,
; leaving 7294T for the delay loop.

DELAY_MS:
DELAY_1MS:
    PUSH AF                 ; 11T
    PUSH BC                 ; 11T
    LD  BC,304              ; 10T
J01:                        ; Loop = 24*bc = 7296T
    DEC BC                  ; 6T
    LD  A,B                 ; 4T
    OR  C                   ; 4T
    JP  NZ,J01              ; 10T 
    POP BC                  ; 10T
    POP AF                  ; 10T
    RET                     ; 10T

; For an exact 10mS delay, the call should take 73,728 T-states.
; The call itself takes 17T, leaving 73,711T in the routine.
; Saving/restoring registers,loading BC and returning takes 62T,
; leaving 73,649T for the delay loop.  To achieve this, the loop
; uses 73,632T and 18T of padding is added at the end.
; 
DELAY_10MS:                 ; 73,712T + 17(call) = 73,729T
    PUSH AF                 ; 11T
    PUSH BC                 ; 11T
    LD  BC,3068             ; 10T
J02:                        ; Loop = 24*bc = 73,632T
    DEC BC                  ; 6T
    LD  A,B                 ; 4T
    OR  C                   ; 4T
    JP  NZ,J02              ; 10T 
    INC BC                  ; pad 6T
    INC BC                  ; pad 6T
    INC BC                  ; pad 6T
    POP BC                  ; 10T
    POP AF                  ; 10T
    RET  


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
;   MISC ROUTINES
;

; XOR-SHIFT random number generator
; returns reg A = 8-bit result
Random: 
    PUSH HL
    PUSH DE
    LD   HL,$A280
    LD   DE,$C0DE
    LD   a,h         
    add  a,a
    xor  h
    LD   h,l        
    LD   l,d        
    LD   d,e        
    LD   e,a
    rra            
    xor  e
    LD   e,a
    LD   a,d        
    add  a,a
    add  a,a
    add  a,a
    xor  d
    xor  e
    LD   e,a
    LD   (Random+3),HL
    LD   (Random+6),DE
    POP  DE
    POP  HL 
    RET


; INTEGER DIVISION: A/B
;   return A= A mod B
;   return C= A div B
;
IntDiv:
    LD   C,0
id1:
    INC  C
    SUB  B
    JR   NC,id1
    DEC  C 
    ADD  A,B
    RET  


; Print "<msg> DEMO"
; Call with HL = address of 4-character message
;
LabelIt:
    CALL ClearScreen         ; clear the display
    LD   A,1
    LD   B,0
    CALL GotoRC              ; goto row1,col0          
    CALL SendString          ; print 1st msg
    LD   A,2
    LD   B,0
    CALL GotoRC              ; goto row2,col0
    LD   HL,testMsg
    CALL SendString          ; print 2nd msg
    RET 

; call with HL pointing to name of the demo
;
LabelDemo:
    CALL ClearScreen;
    LD   A,2
    LD   B,0
    CALL GotoRC              ; goto row1,col0          
    CALL SendString          ; print 1st msg
    LD   A,0
    LD   B,0
    CALL GotoRC              ; goto row2,col0
    LD   HL,msg0
    CALL SendString          ; print 2nd msg
    RET    

; Looks for keyboard input
; Returns zero flag set if no input
; Returns A=0 to 15 for hex input
; Closes app on non-hex input
;
CheckKeypress
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
    LD   C,$80               ; for current console.
    LD   B,0                 ; get waiting character
    RST  08                  ; call the HBIOS routine
    LD   A,E                 ; A = received character
    CALL HexToBin            ; try to convert it to binary
    CP   $FF                 ; was it hex input?
    RET  NZ                  ; yes, return with it
    XOR  A                   ; no it wasn't; shut down
    OUT  (0),A               ; turn off the lights!
    CALL ClearScreen         ; clear the screen
    LD   HL,msg0
    CALL SendString          ; Restore ownership string
    JP   0                   ; & return to CP/M


HexToBin:
    CP   '0'                 ; Compare with '0'
    JR   C,invalid           ; If less, invalid
    CP   '9'+1
    JR   C,digit             ; If <= '9', it's a decimal digit
    CP   'A'                 ; Compare with 'A'
    JR   C,invalid           ; If less, invalid
    CP   'F'+1
    JR   C,ucAlpha           ; If <= 'F', uppercase alpha
    CP   'a'                 ; Compare with 'a'
    JR   C,invalid           ; If less, invalid
    CP   'f'+1
    JR   C,lcAlpha           ; If <= 'f', lowercase alpha
    JR   invalid             ; Anything else is invalid
digit:                       ; convert digits '0'–'9
    SUB  '0'                 ; Subtract ASCII '0'
    RET
ucAlpha:                     ;  convert uppercase 'A'–'F'
    SUB  'A'-10              ; 'A' → 10
    RET 
lcAlpha:                     ;  convert Lowercase 'a'–'f'
    SUB  'a'-10              ; 'a' → 10
    RET
invalid:
    LD   A, $FF              ; set A to 0xFF for error code
    RET 


;=============================================================
;
;   PROGRAM CONSTANTS
;

vectTable:
    .DW SwitchDemo          ; 0
    .DW RandomFill          ; 1
    .DW DoBattery           ; 2
    .DW Clock1              ; 3
    .DW Clock2              ; 4
    .DW DoWave              ; 5
    .DW DoVBar              ; 6
    .DW DoHBar              ; 7
    .DW BlinkDemo           ; 8
    .DW CylonDemo           ; 9
    .DW IncDemo             ; A
    .DW DecDemo             ; B
    .DW 0                   ; C
    .DW 0                   ; D
    .DW 0                   ; E
    .DW 0                   ; F

SWITCH0   .DB $1E,$12,$12,$12,$12,$1E,$1E,$1E 
SWITCH1   .DB $1E,$1E,$1E,$1E,$12,$12,$12,$1E 
SWITCH2   .DB $1F,$1F,$1F,$1F,$11,$11,$11,$1F 
SWITCH3   .DB $1F,$11,$11,$11,$1F,$1F,$1F,$1F
HEART     .DB $00,$0A,$1F,$1F,$1F,$0E,$04,$00
BELL      .DB $04,$0e,$0e,$0e,$1f,$00,$04,$00
NOTE      .DB $02,$03,$02,$0e,$1e,$0c,$00,$00
CLOCKFACE .DB $00,$0e,$15,$17,$11,$0e,$00,$00
HEART2    .DB $00,$0a,$1f,$1f,$0e,$04,$00,$00
OPENHEART .DB $00,$0a,$15,$11,$0a,$04,$00,$00
DUCK      .DB $00,$0c,$1d,$0f,$0f,$06,$00,$00
CHECK     .DB $00,$01,$03,$16,$1c,$08,$00,$00
CROSS     .DB $00,$1b,$0e,$04,$0e,$1b,$00,$00
SMILE     .DB $00,$0a,$0a,$00,$00,$11,$0e,$00
FROWN:    .DB $00,$00,$0a,$00,$0e,$11,$00,$00
UPARROW   .DB $04,$0e,$1f,$0e,$0e,$0e,$00,$00
RUPARROW  .DB $00,$0f,$03,$05,$09,$10,$00,$00
LUPARROW  .DB $00,$1e,$18,$14,$12,$01,$00,$00
DNARROW   .DB $00,$0e,$0e,$0e,$1f,$0e,$04,$00
RDNARROW  .DB $00,$10,$09,$05,$03,$0f,$00,$00
LDNARROW  .DB $00,$01,$12,$14,$18,$1e,$00,$00
RETARROW  .DB $01,$01,$05,$09,$1f,$08,$04,$00
RETURN    .DB $1E,$01,$05,$09,$1E,$08,$04,$00
HOURGLASS .DB $1f,$11,$0a,$04,$0a,$11,$1f,$00
DEGREE    .DB $06,$09,$09,$06,$00,$00,$00,$00
DEGREEC   .DB $18,$18,$03,$04,$04,$04,$03,$00
DEGREEF   .DB $18,$18,$07,$04,$07,$04,$04,$00
VBAR0     .DB $00,$00,$00,$00,$00,$00,$00,$00
VBAR1     .DB $00,$00,$00,$00,$00,$00,$00,$1F
VBAR2     .DB $00,$00,$00,$00,$00,$00,$1F,$1F
VBAR3     .DB $00,$00,$00,$00,$00,$1F,$1F,$1F
VBAR4     .DB $00,$00,$00,$00,$1F,$1F,$1F,$1F
VBAR5     .DB $00,$00,$00,$1F,$1F,$1F,$1F,$1F
VBAR6     .DB $00,$00,$1F,$1F,$1F,$1F,$1F,$1F
VBAR7     .DB $00,$1F,$1F,$1F,$1F,$1F,$1F,$1F
HBAR0     .DB $00,$00,$00,$00,$00,$00,$00,$00
HBAR1     .DB $10,$10,$10,$10,$10,$10,$10,$10
HBAR2     .DB $18,$18,$18,$18,$18,$18,$18,$18
HBAR3     .DB $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C
HBAR4     .DB $1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E
HBAR5     .DB $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F
DOT0      .DB $00,$0e,$11,$11,$11,$0e,$00,$00
DOT1      .DB $00,$0e,$11,$15,$11,$0e,$00,$00
DOT2      .DB $00,$0e,$1f,$1b,$1f,$0e,$00,$00
DOT3      .DB $00,$0E,$1f,$1f,$1f,$0e,$00,$00
DOT4      .DB $00,$1f,$11,$11,$11,$1f,$00,$00
DOT5      .DB $00,$1f,$11,$15,$11,$1f,$00,$00
DOT6      .DB $00,$1f,$1f,$1f,$1f,$1f,$00,$00
DOT7      .DB $00,$00,$0e,$0a,$0e,$00,$00,$00
DOT8      .DB $00,$00,$0e,$0e,$0e,$00,$00,$00
BOLD0     .DB $0e,$1b,$1b,$1b,$1b,$1b,$0e,$00
BOLD1     .DB $02,$06,$0e,$06,$06,$06,$06,$00
BOLD2     .DB $0e,$1b,$03,$06,$0c,$18,$1f,$00
BOLD3     .DB $0e,$1b,$03,$0e,$03,$1b,$0e,$00
BOLD4     .DB $03,$07,$0f,$1b,$1f,$03,$03,$00
BOLD5     .DB $1f,$18,$1e,$03,$03,$1b,$0e,$00
BOLD6     .DB $0e,$1b,$18,$1e,$1b,$1b,$0e,$00
BOLD7     .DB $1f,$03,$06,$0c,$0c,$0c,$0c,$00
BOLD8     .DB $0e,$1b,$1b,$0e,$1b,$1b,$0e,$00
BOLD9     .DB $0e,$1b,$1b,$0f,$03,$1b,$0e,$00
BOLDA     .DB $0e,$1b,$1b,$1f,$1b,$1b,$1b,$00
BOLDB     .DB $1e,$1b,$1b,$1e,$1b,$1b,$1e,$00
BOLDC     .DB $0e,$1b,$18,$18,$18,$1b,$0e,$00
BOLDD     .DB $1e,$1b,$1b,$1b,$1b,$1b,$1e,$00
BOLDE     .DB $1f,$18,$18,$1e,$18,$18,$1f,$00
BOLDF     .DB $1f,$18,$18,$1e,$18,$18,$18,$00
BOLDG     .DB $0e,$1b,$18,$1b,$1b,$19,$0f,$00
BOLDH     .DB $1b,$1b,$1b,$1f,$1b,$1b,$1b,$00
BATT0     .DB $0E,$1B,$11,$11,$11,$11,$11,$1F
BATT20    .DB $0E,$1B,$11,$11,$11,$11,$1F,$1F 
BATT40    .DB $0E,$1B,$11,$11,$11,$1F,$1F,$1F 
BATT60    .DB $0E,$1B,$11,$11,$1F,$1F,$1F,$1F 
BATT80    .DB $0E,$1B,$11,$1F,$1F,$1F,$1F,$1F 
BATT100   .DB $0E,$1F,$1F,$1F,$1F,$1F,$1F,$1F 
BDIGIT0   .DB $01,$03,$03,$07,$07,$0F,$0F,$1F  ; lower-rt triangle 
BDIGIT1   .DB $10,$18,$18,$1C,$1C,$1E,$1E,$1F  ; lower-lf triangle 
BDIGIT2   .DB $1F,$0F,$0F,$07,$07,$03,$03,$01  ; upper-rt triangle 
BDIGIT3   .DB $1F,$1E,$1E,$1C,$1C,$18,$18,$10  ; upper-lf triangle 
BDIGIT4   .DB $00,$00,$00,$00,$1F,$1F,$1F,$1F  ; lower horiz bar 
BDIGIT5   .DB $1F,$1F,$1F,$1F,$00,$00,$00,$00  ; upper horiz bar 
BDIGIT6   .DB $00,$0e,$11,$11,$11,$0e,$00,$00  ; open dot (same as DOT0)
BDIGIT7   .DB $00,$0E,$1f,$1f,$1f,$0e,$00,$00  ; closed dot (same as DOT3)

bigDigits
          .DB $00,$FF,$01,$FF,$20,$FF,$FF,$20,$FF,$02,$FF,$03   ; #0 
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

msg0      .DB "RC2014 Z80 Computer",0
switchMsg .DB "Switches",0
binUpMsg  .DB "Binary Count Up",0
binDnMsg  .DB "Binary Count Down",0
blinkMsg  .DB "Blinkenlights",0
cylonMsg  .DB "Larson Scanner",0
iconMsg   .DB "Icon",0
signMsg   .DB "Sine",0
testMsg   .DB "Demo",0
vbarMsg   .DB "VBar",0
hbarMsg   .DB "HBar",0
charMsg   .DB "Char",0
textMsg   .DB "This computer  is a Z80-based RC2014 system  running CP/M.",0
introMsg  .DB 0," FPDEMO by Bruce Hall, W8BH",0,0
          .DB " Exercise the RC2014 front panel hardware.",0
          .DB " Choose a demonstration by pressing a key.",0,0
          .DB " Keypress   Demo",0
          .DB "    0       Switch positions shown on LEDs and LCD",0
          .DB "    1       Multi-line text & random characters",0
          .DB "    2       Animated battery icon",0
          .DB "    3       Large 4-digit clock",0
          .DB "    4       Large 6-digit clock",0
          .DB "    5       Animated sine wave",0
          .DB "    6       Animated vertical bar graph",0
          .DB "    7       Animated horizontal bar graph",0
          .DB "    8       Blinkenlights",0
          .DB "    9       Larson Scanner",0
          .DB "    A       Binary Counting - Increment",0
          .DB "    B       Binary Counting - Decrement",0 
          .DB 0
          .DB " Press any other key to stop the demo.",0,
          .DB "$"

; the sine list emulates y = 15*sin(I*24)+16, where I = 0 to 14 
sine      .DB 16,22,27,30,31,29,25,19,13,7,3,1,2,5,10 


;=============================================================
;
;   PROGRAM VARIABLES
;

sign      .DB 0
newValue  .DB 0
values    .DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tens      .DB 0
ones      .DB 0
seconds   .DB 0
minutes   .DB 34
hours     .DB 12
selection .DB 0

.END