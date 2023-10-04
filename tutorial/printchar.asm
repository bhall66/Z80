;
;   Title:   printchar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   10 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  Description:  repackage "onechar.asm" into an easy-to-use routine
;  What does it do?  It writes a single character to the terminal console.
;
;  Call "printChar" with character to be displayed in register A
;  All other registers are preserved. 
;
;  Compile it with tasm as follows:
;  "tasm -80 printchar.asm"
;
;  Transfer the onechar.obj (Intel Hex) output to the RC2014 using the debug 
;  monitor Load "L" command.  Then run the program which resides at 0100 by "R 100".
;
;  This program uses a RomWBW HBIOS function, therefore RomWBW must be present.
;


.ORG $0100

    LD   A, '~'        ; display a tilde
    CALL printCh       ; do it
    RET                ; and return

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

.END

