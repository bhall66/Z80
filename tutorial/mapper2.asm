;
;   Title:   mapper2.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   16 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler
;
;   Descr:   Displays a ROM/RAM memory map.
;            Assumes that RAM and a stack are present.
;            Uses subroutines.
;            Assumes MMU/SIO initialized
;

sioCmd	 .equ	$80	    ; port for SIO Channel A cmd/status
sioDat	 .equ	$81	    ; port for SIO Channel A data

.ORG $0100


ramTest:
    LD   HL, stMapper   ; "Memory Mapper..."
    CALL printStr      
    LD   DE, $0800      ; page size of 2K
    LD   B, 32          ; eval 32 pages of memory (64K)
    LD   HL, $0000      ; starting at $0000
rt01:
    LD   A, H           ; look at H register
    AND  $1F            ; are we on an 8K boundary?
    JR   NZ, rt02       ; if not, continue
    LD   A, ' '         ; otherwise, print space
    CALL printCh
rt02:
    LD   C, (HL)        ; temp save memory contents
    LD   A, $DC         ; use test byte $DC
    LD   (HL), A        ; try saving the byte
    CP   (HL)           ; then read it back & compare 
    LD   (HL), C        ; restore memory contents
    JR   Z, foundRAM    ; if same, RAM was written correctly
foundROM:
    LD   A, 'r'         ; ROM found, so print 'R'
    JR   rt03
foundRAM:
    LD   A, 'W'         ; RAM found, so print 'W'
rt03:
    CALL printCh        ; print result 
    ADD  HL, DE         ; point to next memory page
    DJNZ rt01           ; and loop until done
    LD   HL, stEndmap   ; finish output
    CALL printStr
    RET

printCh:
    PUSH AF
pc01:
    IN   A, (sioCmd)    ; get SIO status (RR0)
    AND  $04            ; check Tx-buffer-empty bit
    JR   Z, pc01        ; wait until buffer empty
    POP  AF
    OUT  (sioDat), A    ; write char to display
    RET

printStr:
    LD   A, (HL)        ; get character in the string
    OR   A              ; is it zero?
    RET  Z              ; if it is, we are done.
    CALL printCh        ; otherwise, display it
    INC  HL             ; move to next character
    JR   printStr       ; and loop until done


stMapper:
    .db 13,10
    .db "  Z80 Memory Mapper         r=ROM, W=RAM"   ,13,10,13,10
    .db "+-----------------------------------------+",13,10
    .db "| 0    8    16   24   32   40   48   56K  |",13,10
    .db "+-----------------------------------------+",13,10
    .db "|",0
stEndmap:
    .db " |",13,10
    .db "+-----------------------------------------+",13,10
    .db 13,10,0

.END

