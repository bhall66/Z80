;
;   Title:   printstr.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   10 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Description:  print a string to the terminal console
;  Call "printStr" with HL pointing a null-terminated string
;  Registers A & HL are used.  All other registers are preserved. 
;
;  Compile it with tasm as follows:
;  "tasm -80 printstr.asm"
;
;  Transfer the object file (Intel Hex) to the RC2014 using the debug 
;  monitor Load "L" command.  Then run the program which resides at 0100 by "R 100".
;
;  This program uses a RomWBW HBIOS function, therefore RomWBW must be present.
;


.ORG $0100

    LD   HL, str       ; point to the string
    CALL printStr      ; display the string
    RET                ; and return

printStr:
    LD   A, (HL)       ; get character in the string
    OR   A             ; is it zero?
    RET  Z             ; if it is, we are done.
    CALL printCh       ; otherwise, display it
    INC  HL            ; move to next character
    JR   printStr      ; and loop until done

printCh:
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

str:
    .db  13,10,"Hello, RC2014!",0

.END

