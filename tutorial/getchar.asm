;
;   Title:   getchar.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   24 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;   Descr:   input characters and echo them to console.
;            Stop when <enter> is pressed.  
;            Uses HBIOS calls.
;


.ORG $0100

start:
   CALL  getCh          ; get a character into A
   CP    13             ; if it's <enter> key
   RET   Z              ; then quit
   CALL  printCh        ; otherwise, print char in A
   JR    start          ; and get next character

getCh:
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

