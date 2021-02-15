.equ UART_ST $FFE0
.equ UART_TX $FFE2
.equ UART_RX $FFE2

.org $100

    push 65
    store UART_TX

    push 66
    bra wait_tx
    store UART_TX

    push 67
    bra wait_tx
    store UART_TX


.byte $ff # sim stop


wait_tx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 2 # bit 1: flag sending
    and # sets zero flag if sending done
    pop pop
    jpnz wait_tx
    ret

wait_rx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 1 # bit 0: flag received
    and # sets zero flag if nothing received
    pop pop
    jpz wait_tx
    ret

key: # ( -- c )
    bra wait_rx
    push 0
    fetch UART_RX
