.equ UART_TX $fff0
.equ UART_ST $fff1
.org 0
    ldi r0, 123
    ldi r0, msg
    ld r0, (r0)
    ld r0, (r0+4)


uart_byte_tx:
    # send char in r0 lsb
    push r1
    ldi r1, UART_ST
    ld r1, (r1)

    pop r1
    ret

ende:
    and r1, r2
    jp ende

.org 16
msg: .asciiz "Hallo Welt!"
