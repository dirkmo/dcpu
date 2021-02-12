.equ UART_ST $FFE0
.EQU UART_TX $FFE2

.org $100

    push 65
    store UART_TX

    push 66
    bra wait_tx
    store UART_TX

    push 67
    bra wait_tx
    store UART_TX


.byte $ff


wait_tx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 2
    and
    jpnz wait_tx
    pop
    ret
