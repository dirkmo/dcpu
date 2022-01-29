.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00



.word SIM_END

# variables
state: .word 0 # 0: interpreting, -1: compiling
ntib: .word 9   # number of chars in tib
tib: .ascii "drop dup "

base: .word 10

latest: .word 0 # last word in dictionary
dp: .word 0 # first free cell after dict

# dictionary

_latest:    # ( -- addr)
            .word 0
            .cstr "latest"
_latest_body:
            lit latest [ret]


_tib:       # ( -- addr)
            .word _latest
            .cstr "tib"
_tib_body:
            lit tib [ret]


_to_in:     # ( -- n )
            .word _tib
            .cstr ">in"
_to_in_body:
            lit ntib [ret]


_base:      # ( -- addr)
            .word _to_in
            .cstr "base"
_base_body:
            lit base [ret]


_fetch:     # (addr -- n)
            .word _base
            .cstr "@"
_fetch_body:
            a:mem t [ret]


_store:     # (d addr -- )
            .word _fetch
            .cstr "!"
_store_body:
            a:n mem d-
            a:nop r d- [ret]


_drop:      ( n -- )
            .word _store
            .cstr "drop"
_drop_body:
            a:nop t d- [ret]


_dup:       # (a -- a a)
            .word _drop
            .cstr "dup"
_dup_body:
            a:t t d+ [ret]


_swap:      # (a b -- b a)
            .word _dup
            .cstr "swap"
_swap_body:
            a:t r d- r+      # (a b -- a r:b)
            a:t t d+         # (a r:b -- a a r:b)
            a:r t d- r-      # (a a r:b -- b a)
            a:nop t d+ [ret] # (b a -- b a)


_over:      # (a b -- a b a)
            .word _swap
            .cstr "over"
_over_body:
            a:n t d+ [ret]


_rot:       # (a b c -- b c a)
            .cstr "rot"
            .word _over
_rot_body:  # todo


_nip:       # (a b -- b)
            .word _rot_body
            .cstr "nip"
_nip_body:  
            a:t t d- [ret]


_tuck:      # (a b -- b a b)
            .word _nip
            .cstr "tuck"
_tuck_body: 
            call _swap_body # ( a b -- b a)
            call _over_body # ( b a -- b a b)
            a:nop t [ret]


_wait_uart_tx_can_send: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_TX_FULL
            a:and t d-
            rj.nz _wait_uart_tx_can_send
            a:nop t [ret]


_emit:      # (c --)
            .word _tuck
            .cstr "emit"
_emit_body: call _wait_uart_tx_can_send
            lit ADDR_UART_TX
            call _store_body
            a:nop t [ret]


_wait_uart_rx_has_data: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_RX_EMPTY
            a:and t d-
            rj.z _wait_uart_rx_has_data
            a:nop t [ret]


_key:       # ( -- key)
            .word _emit
            .cstr "key"
_key_body:
            call _wait_uart_rx_has_data
            lit ADDR_UART_RX
            a:mem t [ret]


_word:      # ( delimiter -- addr-cstr)
            .word _key
            .cstr "word"
_word_body:
            call _tib_body
            call _fetch_body
            call _to_in_body
