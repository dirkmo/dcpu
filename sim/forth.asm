.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
# wire [7:0] status = { 4'd0, fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty };
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1

.equ SIM_END $be00


# Hint how to inc/dec dsp:  a:r r d+



rj 0


_fetch:     # (addr -- n)
            .cstr "@"
            .word 0
_fetch_body:
            a:mem t [ret]


_store:     # (d addr -- )
            .cstr "!"
            .word _fetch_body
_store_body:
            a:n mem d-
            a:r r d- [ret]


_drop:      .cstr "drop"
            .word _store_body
_drop_body:
            a:r r d- [ret]


_dup:       # (a -- a a)
            .cstr "dup"
            .word _drop_body
_dup_body:
            a:t t d+ [ret]


_swap:      # (a b -- b a)
            .cstr "swap"
            .word _dup_body
_swap_body:
            a:t r d- r+    # (a b -- a r:b)
            a:t t d+       # (a r:b -- a a r:b)
            a:r t d- r-    # (a a r:b -- b a)
            a:r r d+ [ret] # (b a -- b a)


_over:      # (a b -- a b a)
            .cstr "over"
            .word _swap_body
_over_body:
            a:n t d+ [ret]


_rot:       # (a b c -- b c a)
            .cstr "rot"
            .word _over_body
_rot_body:  # todo


_nip:       # (a b -- b)
            .cstr "nip"
            .word _rot_body
_nip_body:  
            a:n t d- [ret]


_tuck:      # (a b -- b a b)
            .cstr "tuck"
            .word _nip_body
_tuck_body: 
            call _swap_body # ( a b -- b a)
            call _over_body # ( b a -- b a b)
            a:t t [ret]


_wait_uart_tx_can_send: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_TX_FULL
            a:and t d-
            rj.nz _wait_uart_tx_can_send
            a:t t [ret]


_emit:      # (c --)
            .cstr "emit"
            .word _tuck_body
_emit_body:
            call _wait_uart_tx_can_send
            lit ADDR_UART_TX
            call _store_body
            a:r r [ret]


_wait_uart_rx_has_data: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_RX_EMPTY
            a:and t d-
            rj.z _wait_uart_rx_has_data
            a:t t [ret]


_key:       # ( -- key)
            .cstr "key"
            .word _emit_body
_key_body:
            call _wait_uart_rx_has_data
            lit ADDR_UART_RX
            a:mem t [ret]
