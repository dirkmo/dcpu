start: ret
jp r0
loop:
.org $100
MSG: .asciiz "hallo"
.ascii "hallo"
.word 123, $ff12
ld r0, 1
ld.l r0, 2
ld.h r0, 3
jp start
jp 123 #comment
and r1, r2

jz r2
jnz start
.equ UART_RX, $fff0
ret
push r0
