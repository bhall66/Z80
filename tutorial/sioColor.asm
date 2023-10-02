;
;   Title:   sioColor.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   12 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Description:  write a colorful string to console via the SIO chip.  
;  Assumes that SIO has already been initialized.
;


sioCmd	.equ	$80	    ; port for SIO Channel A cmd/status
sioDat	.equ	$81	    ; port for SIO Channel A data


.ORG $0100

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

.END

