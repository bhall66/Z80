;
;   Title:   onechar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   09 Sep 2023
;      HW:   RC2014Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;  This is my first assembler program for Z80 on the RC2014 Zed.
;  What does it do?  It writes a single '~' character to the terminal console.
;
;  Compile it with tasm as follows:
;  "tasm -80 onechar.asm"
;
;  Transfer the onechar.obj (Intel Hex) output to the RC2014 using the debug 
;  monitor Load "L" command.  Then run the program which resides at 0100 by "R 100".
;
;  This program uses a RomWBW HBIOS function, therefore RomWBW must be present.
;


.ORG $0100

    LD  b, $01        ; HBIOS function $01 = CHARACTER OUTPUT (CIOOUT)
    LD  c, $80        ; Device Number $80 = current console
    LD  e, '~'        ; character to be sent to console
    RST 08            ; call the HBIOS routine
    RET 

.END

