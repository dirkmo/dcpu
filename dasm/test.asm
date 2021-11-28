start: ret
jp r0
br r1
jz r2
loop:
    bc r3
bnc r5
.equ UART_RX, $fff0
.org $100
MSG: .asciiz "hallo"
.ascii "hallo"
.word 123, $ff12
ld r0, 1
ld.l r0, 2
ld.h r0, 3
