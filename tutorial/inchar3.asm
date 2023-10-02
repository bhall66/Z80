;
;   Title:   inchar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   23 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Description:  input a character and echo it back.  
;  Uses HBIOS calls.
;


.ORG $0100

    LD   HL, str1       ; "Enter a character"
    CALL printStr       ; display the string
    CALL getChar        ; get user input in A
    PUSH AF             ; save it
    LD   HL, str2       ; "You entered: "
    CALL printStr       ; display the string
    POP  AF             ; retrieve input char
    CALL printChar      ; and print it.
    LD   HL, str3       ; newline
    CALL printStr
    RET

getChar:
	PUSH BC             ; save current registers
    PUSH DE
    PUSH HL
    LD   B, $00         ; HBIOS function $00 = CHARACTER INPUT
    LD   C, $80         ; device $80 = current console
    RST  08             ; call the HBIOS routine
    LD   A, E           ; put character in A
    POP  HL             ; restore registers after HBIOS call
    POP  DE
    POP  BC
    RET

printStr:
    LD   A, (HL)        ; get character in the string
    OR   A              ; is it zero?
    RET  Z              ; if it is, we are done.
    CALL printChar      ; otherwise, display it
    INC  HL             ; move to next character
    JR   printStr       ; and loop until done

printChar:
    PUSH BC            ; save current registers
    PUSH DE 
    PUSH HL
    LD   B, $01        ; HBIOS function $01 = CHARACTER OUTPUT (CIOOUT)
    LD   C, $80        ; Device Number $80 = current console
    LD   E, A          ; load E with character to be displayed
    RST  08            ; call the HBIOS routine
    POP  HL            ; restore registers after HBIOS call
    POP  DE
    POP  BC
    RET  
      
str1:
    .db 13,10,13,10,"  Enter a character...",0
str2:
    .db 13,10,"  You entered: ",0
str3:
    .db 13,10,13,10,0

.END

