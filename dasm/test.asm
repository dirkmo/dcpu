ret
jp r0
br r1
jz r2
bc r3
bnc r5
.equ UART_RX, $fff0
.org $100
.asciiz "hallo"
