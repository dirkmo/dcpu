.equ UART_ST $fffe
.equ UART_RX $ffff
.equ UART_TX $ffff
# wire [7:0] status = { 4'd0, fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty };
.equ UART_TX_FULL 8
.equ UART_TX_EMPTY 4
.equ UART_RX_FULL 2
.equ UART_RX_EMPTY 1

.equ SIM_END $be00

rj 0

_fetch:
    .cstr "@"
    .word 0
    a:t mem [ret]

_store:
    .cstr "!"
    .word _fetch
    a:n mem d-
    a:t t d- [ret]

_drop:
    .cstr "drop"
    .word _store
    a:t t d- [ret]

_dup:
    .cstr "dup"
    .word _drop
    a:t t d+ [ret]

_swap:
    .cstr "swap"
    .word _dup
    a:n r d- r+
    a:t t d+
    a:r t d- r-
    a:t t d+ [ret]

_over:
    .cstr "over"
    .word _swap
    a:n t d+ [ret]

_rot:
    .cstr "rot"
    .word _over
    # n1 n2 n3 -- n2 n3 n1
    # todo

_wait_uart_tx_can_send:
    lit UART_ST
    a:mem t 
    lit UART_TX_FULL
    a:and
    rj.nz _wait_uart_tx_can_send d-
