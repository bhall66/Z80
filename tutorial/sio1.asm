;
;   Title:   sio1.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   12 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler
;
;  Description:  initializes the SIO, then write a string via the SIO.  
;


sioCmd	.equ	$80	    ; port for SIO Channel A cmd/status
sioDat	.equ	$81	    ; port for SIO Channel A data


.ORG $0100

    CALL sioInit        ; initialize SIO channel A
    LD   HL, lambStr    ; point to the string
    CALL printStr       ; display the string
    RET                 ; and return

printStr:
    LD   A, (HL)        ; get character in the string
    OR   A              ; is it zero?
    RET  Z              ; if it is, we are done.
    CALL printCh        ; otherwise, display it
    INC  HL             ; move to next character
    JR   printStr       ; and loop until done

printCh:
    PUSH AF             ; temp save character
pcloop:
    IN   A, (sioCmd)    ; get SIO status (RR0)
    AND  $04            ; check Tx-buffer-empty bit
    JR   Z, pcloop      ; wait until buffer empty
    POP  AF             ; retrieve char to send
    OUT  (sioDat), A    ; write char to display
    RET     

sioInit:
	LD   C, sioCmd		; SIO command port, channel A
	LD	 HL, initRegs	; point to table of register values
	LD	 B, +10     	; count of bytes to write
	OTIR				; write all values to SIO cmd port
	RET       

lambStr:
    .db  27,"[96m"      ; set foreground color to cyan
    .db  13,10
    .db  13,10,"    Mary had a little lamb"
    .db  13,10,"    It's fleece was white as snow."
    .db  13,10,"    And everywhere that Mary went"
    .db  13,10,"    The lamb was sure to go."
    .db  13,10
    .db  13,10
    .db  27,"[39m"      ; restore default FG color
    .db  0              ; end-of-string marker

; Table for SIO register initialization.  
; Assuming a system clock of 7.3728 MHz, this will
; result in a baud rate of 115200.
;
initRegs:
	.db	$00, $18		; wr0: reset the channel
	.db	$04, $C4		; wr4: baud=115200, no parity, 1 stop bit
	.db	$01, $18		; wr1: no interrupts=$00, on received chars=$18
	.db	$03, $E1		; wr3: Rx 8 bits, Rx enabled, cts/dcd auto
	.db	$05, $EA		; wr5: Tx 8 bits, Tx enabled, dtr&rts ($E8 no RTS)

.END

