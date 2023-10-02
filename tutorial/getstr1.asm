;
;   Title:   getStr1.asm
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

maxLen  .equ  80        ; string length limit

start:
   LD    HL, buffer     ; point to input string buffer
   CALL  getStr         ; and get string from user
   
   LD    HL, buffer     ; point to input string buffer
   CALL  printStr       ; and echo string to console
   RET

getStr:
   CALL  getCh          ; get a character into A
   CP    13             ; if it's <enter> key
   JR    Z, gs1         ; then quit
   LD    (HL), A        ; save character to buffer
   INC   HL             ; increment buffer pointer
   CALL  printCh        ; echo input to console
   JR    getStr         ; and get next character
gs1:
   XOR   A              ; terminate the string
   LD   (HL), A         ; with null character
   RET                  ; and quit

getCh: 
	PUSH BC              ; save current registers
   PUSH DE
   PUSH HL
   LD   B, $00          ; HBIOS function $00 = CHARACTER INPUT
   LD   C, $80          ; device $80 = current console
   RST  08              ; call the HBIOS routine
   LD   A, E            ; put character in A
   POP  HL              ; restore registers after HBIOS call
   POP  DE
   POP  BC
   RET

printStr:
   LD   A, (HL)         ; get character in the string
   OR   A               ; is it zero?
   RET  Z               ; if it is, we are done.
   CALL printCh         ; otherwise, display it
   INC  HL              ; move to next character
   JR   printStr        ; and loop until done

printCh:
   PUSH BC              ; save current registers
   PUSH DE 
   PUSH HL
   LD   B, $01          ; HBIOS function $01 = CHARACTER OUTPUT (CIOOUT)
   LD   C, $80          ; Device Number $80 = current console
   LD   E, A            ; load E with character to be displayed
   RST  08              ; call the HBIOS routine
   POP  HL              ; restore registers after HBIOS call
   POP  DE
   POP  BC
   RET  


buffer:
   .FILL maxLen,0      ; reserve <maxLen> bytes for input string

.END

