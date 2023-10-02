;
;   Title:   mapper.asm
;  Author:   Bruce E. Hall, w8bh
;    Date:   15 Sep 2023
;      HW:   RC2014 Zed with 512K RAM/ROM module
;      SW:   TASM compiler
;
;   Descr:   Configure the MMU, test memory, then display a map
;            of ROM/RAM.   All without using a stack!
;                 
;  Burn it to ROM and run; this code does not use or need HBIOS.
;  But it is does require the SIO and MMU chips.
;


sioCmd	 .equ	$80	    ; port for SIO Channel A cmd/status
sioDat	 .equ	$81	    ; port for SIO Channel A data
mmuReg0  .equ   $78     ; port for mmu register0 (0000-3FFF)
mmuReg1  .equ   $79     ; port for mmu register1 (4000-7FFF)
mmuReg2  .equ   $7A     ; port for mmu register2 (8000-BFFF)
mmuReg3  .equ   $7B     ; port for mmu register3 (C000-FFFF)
mmuEnbl  .equ   $7C     ; port for mmu enable
ROM0     .equ   $00     ; ROM page 0  (Each page is 16K)
ROM1     .equ   $01     ; ROM page 1
RAM0     .equ   $20     ; RAM page 0
RAM1     .equ   $21     ; RAM page 1
RAM2     .equ   $22     ; RAM page 2

.ORG $0000

initSIO:
	LD   C, sioCmd		; SIO command port, channel A
	LD	 HL, initRegs	; point to table of register values
	LD	 B, +10   		; count of bytes to write
	OTIR				; write all values to SIO cmd port

configMMU:
    LD   A, ROM0 
    OUT  (mmuReg0), A   ; Memory $0000-$3FFF = ROM page 0
    LD   A, ROM1
    OUT  (mmuReg1), A   ; Memory $4000-$7FFF = ROM page 1
    LD   A, RAM0
    OUT  (mmuReg2), A   ; Memory $8000-$BFFF = RAM page 0
    LD   A, RAM1
    OUT  (mmuReg3), A   ; Memory $C000-$FFFF = RAM page 1
    LD   A, 1
    OUT  (mmuEnbl), A   ; Enable MMU

ramTest:
    LD   DE, $0800      ; page size of 2K
    LD   B, 32          ; eval 32 pages of memory (64K)
    LD   HL, $0000      ; starting at $0000
rtLoop:
    IN   A, (sioCmd)    ; get SIO status (RR0)
    AND  $04            ; check Tx-buffer-empty bit
    JR   Z, rtLoop      ; wait until buffer empty

    LD   C, (HL)        ; temp save memory contents
    LD   A, $DC         ; use test byte $DC
    LD   (HL), A        ; try saving the byte
    CP   (HL)           ; then read it back & compare 
    LD   (HL), C        ; restore memory contents
    JR   Z, foundRAM     ; if same, RAM was written correctly
foundROM:
    LD   A, 'r'         ; ROM found, so print 'r'
    JR   printCh
foundRAM:
    LD   A, 'W'         ; RAM found, so print 'W'
printCh:
    OUT  (sioDat), A    ; write char to display

    ADD  HL, DE         ; point to next memory page
    DJNZ rtLoop         ; and loop until done
    HALT


; Table for SIO register initialization.  
; Assuming a system clock of 7.3728 MHz, this will
; result in a baud rate of 115200.
;
initRegs:
	.db	$00, $18		; wr0: reset the channel
	.db	$04, $C4		; wr4: baud=115200, no parity, 1 stop bit
	.db	$01, $00		; wr1: no interrupts=$00, on received chars=$18
	.db	$03, $E1		; wr3: Rx 8 bits, Rx enabled, cts/dcd auto
	.db	$05, $EA		; wr5: Tx 8 bits, Tx enabled, dtr&rts ($E8 no RTS)

.END

