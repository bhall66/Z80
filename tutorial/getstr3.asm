;
;   Title:   getstr3.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   24 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;   Descr:   input characters and echo them to console.
;            Stops when <enter> is pressed.  
;            Adds <backspace> handling to getstr2
;            Uses HBIOS calls.


.ORG $0100

maxLen  .equ  80        ; string length limit

start:
   CALL  crlf           ; start on new line
   LD    HL, buffer     ; point to input string buffer
   CALL  getStr         ; and get string from user
   
   CALL  crlf           ; start on new line
   LD    HL, buffer     ; point to input string buffer
   CALL  printStr       ; and echo string to console
   RET

getStr:
   LD    B, 0           ; B contains character count
gs0:
   CALL  getCh          ; get a character into A
   CP    13             ; if it's <enter> key
   JR    Z, gs1         ; then quit
   CP    8              ; is it <backspace>
   JR    NZ, gs2        ; no, so add it to buffer
   RL    B              
   RR    B              ; is char count 0?
   JR    Z, gs0         ; yes, dont do anything           
   CALL  printCh        ; move cursor back one
   LD    A, ' '         ; and print a space
   CALL  printCh        ; to erase last character
   LD    A, 8           ; now print <backspace> again 
   CALL  printCh        ; to move cursor back
   DEC   HL             ; decrement buffer pointer
   DEC   B              ; decrement character counter
   JR    gs0            ; and get next character
gs2:
   LD    (HL), A        ; save character to buffer
   INC   HL             ; increment buffer pointer
   CALL  printCh        ; echo input to console
   INC   B              ; increment character counter
   LD    A, B
   CP    maxLen-1       ; reached max size yet?
   JR    C, gs0         ; no, so keep going 
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
   CALL printChar       ; otherwise, display it
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

crlf:
   LD   A, 13
   CALL printCh
   LD   A, 10
   CALL printCh
   RET

buffer:
   .FILL maxLen,0      ; reserve <maxLen> bytes for input string

.END

