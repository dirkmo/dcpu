.equ UART_TX $fff0
.equ UART_ST $fff1

    ldi r0, 123
    ldi r0, msg
    ld r0, (r0)


uart_byte_tx:
    # send char in r0 lsb
    push r1
    ldi r1, UART_ST
    ld r1, (r1)

    pop r1
    ret

ende:
    jp ende

msg: .asciiz "Hallo Welt!"
