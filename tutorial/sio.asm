;
;   Title:   sio.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   17 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Description:  write a string to console via the SIO chip.  
;  Assumes that the SIO has already been initialized.
;


sioCmd	.equ	$80	    ; port for SIO Channel A cmd/status
sioDat	.equ	$81	    ; port for SIO Channel A data


.ORG $0100

    LD   HL, str        ; point to the string
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

str:
    .db  13,10,"Hello, RC2014!",13,10,0

.END

