;
;   Title:   dump.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   28 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler, RomWBW firmware
;
;   Descr:   Memory Dump.
;            Uses HBIOS calls.


.ORG $0100

start:
   CALL  crlf           ; start on new line
   LD    HL, str1       ; "Memory Address: "
   CALL  printStr  
   LD    HL, buffer     ; point to input string buffer
   CALL  getStr         ; and get string from user  
   CALL  crlf           ; start on new line
   LD    DE, buffer
   CALL  str2Hex        ; convert input to hex address
   LD    C, $10         ; print 16 lines (1 memory page)
d01:
   CALL  printHex16     ; print line start address
   LD    A, ':'
   CALL  printCh
   LD    A, ' '
   CALL  printCh
   LD    B, $10         ; put 16 bytes on each line
   PUSH  HL
d02:
   LD    A, (HL)        ; get next memory byte
   CALL  printHex       ; and print it
   LD    A, ' '
   CALL  printCh        ; put space between bytes
   INC   HL             ; point to next byte
   DJNZ  d02            ; loop for all bytes on this line 
   POP   HL             ; reset line address
   CALL  asciiLine      ; print line in ASCII       
   CALL  crlf           ; crlf at end of the line
   DEC   C              ; done with all lines?
   JR    NZ, d01        ; no, so go to next line
   RET

asciiLine:              ; print 16 bytes as ASCII characters
   LD    B, $10         ; 16 characters per line
d03:
   LD    A, (HL)        ; get next character
   CALL  isPrintable    ; if not printable,
   JR    NC, d04
   LD    A, '.'         ; replace with a dot '.'
d04: 
   CALL  printCh        ; print the character
   INC   HL             ; advance to next character
   DJNZ  d03            ; and loop until done
   RET

#INCLUDE "bhUtils.asm"

buffer:
   .FILL 80,0      ; reserve 80 bytes for input string
str1:
   .db " Memory Address: ",0


.END