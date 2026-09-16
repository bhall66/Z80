20 REM
30 REM   SWITCH.BAS
40 REM   by Bruce E. Hall, 25 Aug 2026
50 REM
60 REM   Reads the front panel switches,
70 REM   displays their value on the LEDs,
80 REM   and prints their value on the console.
90 REM
100 A=0:B=0
110 A=INP(0)
130 OUT 0,A
140 IF A=B GOTO 110
150 B=A
160 PRINT "The switch value is ";A
170 GOTO 110
