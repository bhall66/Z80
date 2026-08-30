;
;   Title:   LCDFILL.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   27 Aug 2026
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Get a single character from the command tail
;  and paint the front panel LCD with it.
;

cmdPort	      .equ	  $DA	 ; port for HD44780 command register
dataPort	  .equ	  $DB	 ; port for HD44780 data register 

; HD44780 Controller Commands 
;
CLEAR_SCREEN  .equ    $01    ; clear screen command
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


.ORG $0100

Start:   
    CALL ClearScreen                    
    LD   A,($0082)           ; get 1st char of command tail
    LD   C,A                 ; save char in C        
    LD   B,80                ; count 80 characters
j0:           
    LD   A,C                 ; retrieve char
    CALL SendChar            ; send it to the LCD
    DJNZ j0                  ; repeat until all sent
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
    LD   A,CLEAR_SCREEN
    CALL SendCommand
    RET 

SendString:
	LD	A,(HL)			     ; next character to send
	OR	A			         ; set flags
	RET	Z			         ; done on null
	CALL SendChar            ; send the character
	INC	HL			         ; point to next char
	JR	SendString    	     ; and loop until done

.END

