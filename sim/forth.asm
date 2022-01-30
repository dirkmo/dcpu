.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_BYTE_SIZE 80


lit 32
call _word_body



.word SIM_END

# variables
state: .word 0 # 0: interpreting, -1: compiling
ntib: .word 9   # number of chars in tib
# tib: .space TIB_BYTE_SIZE
tib: .ascii "   drop dup " # input buffer
to_in: .word 0  # current char idx in tib
base: .word 10
latest: .word 0 # last word in dictionary
dp: .word 0 # first free cell after dict
scratch: .space 33

# dictionary

_add1:      # (n -- n+1)
            .word 0
            .cstr "+1"
_add1_body:
            lit 1            # (n -- n 1)
            a:add t d- [ret] # (n 1 -- n+1)


_latest:    # ( -- addr)
            .word _add1
            .cstr "latest"
_latest_body:
            lit latest [ret]


_tib:       # ( -- addr)
            # input area as ascii string
            .word _latest
            .cstr "tib"
_tib_body:
            lit tib [ret]

_ntib:      # ( -- n)
            # number of chars in input area
            .word _tib
            .cstr "#tib"
_ntib_body:
            lit ntib
            a:mem t [ret]


_to_in:     # ( -- n )
            # return addr of index of current char in input buffer
            .word _ntib
            .cstr ">in"
_to_in_body:
            lit to_in [ret]
            


_tibcfetch: # ( -- char)
            # fetch char pointed to by >in from tib
            .word _to_in
            .cstr "tibc@"
_tibcfetch_body:
            call _to_in_body
            call _fetch_body
            call _tib_body
            call _strcfetch_body
            a:nop t [ret]


_base:      # ( -- addr)
            .word _tibcfetch
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


_drop:      # ( n -- )
            .word _store
            .cstr "drop"
_drop_body:
            a:nop t d- [ret]


_dup:       # (a -- a a)
            .word _drop
            .cstr "dup"
_dup_body:
            a:t t d+ [ret]


_2dup:      # (a b -- a b a b)
            .word _dup
            .cstr "2dup"
_2dup_body:
            a:n t d+
            a:n t d+ [ret]


_swap:      # (a b -- b a)
            .word _2dup
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
            .word _rot
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


_strcfetch: # (char-idx str-addr -- c)
            # fetch char at index from str
            .word _key
            .cstr "sc@" # "string char fetch"
_strcfetch_body:
            call _over_body       # ( ci ca -- ci ca ci)
            # divide index by 2
            a:sr t                # (ci ca ci -- ci ca i)
            # get addr of word containing char
            a:add t d-            # (ci ca i -- ci ca+i)
            call _fetch_body      # (ci ca+i -- ci w)
            call _swap_body       # (ci w -- w ci)
            lit 1                 # (w ci -- w ci 1)
            a:and t d-            # (w ci 1 -- w ci&1)
            # endianess is handled here:
            rj.nz _strcf1         # (w ci&1 -- w) ; .nz oder .z ??
            a:srw t               # (w -- w>>8)
_strcf1:    lit $ff               # (w -- w $ff)
            a:and t d- [ret]      # (w -- w&$ff)


_cscfetch:  # (char-idx cstr-addr -- char)
            # fetch char at index from cstr
            .word _strcfetch
            .cstr "csc@" # "counted string char fetch"
_cscfetch_body:
            # add 1 because counted string
            call _add1_body       # (ci ca i -- ci ca i+1)
            call _strcfetch_body  # (ci ca i+1 -- c)
            a:nop t [ret]


_tib_eob:   # (-- flag)
            # if >in reached end of buffer return 0
            call _to_in_body
            call _fetch_body
            lit TIB_BYTE_SIZE
            a:sub t d- [ret]


_to_in_plus1: # (--)
            # inc >in
            call _to_in_body
            call _fetch_body
            call _add1_body
            call _to_in_body
            call _store_body
            a:nop t [ret]


_word:      # (delimiter -- count addr-str)
            # skip delimiters
            # take idx of first non-delimiter
            # 
            .word _cscfetch
            .cstr "word"
_word_body:
            lit 0 # (del -- del c) ; helper
_wb_del_loop:
            call _drop_body      # (del c -- del) ; drop c from branching to _wb_del_loop
            # reached eob?
            call _tib_eob
            rj.z _word_eob
            
            call _tibcfetch_body # (del -- del c)
            call _to_in_plus1    # (del c -- del c)
            call _2dup_body      # (del c -- del c del c)
            # is char == delimiter?
            a:sub t d-           # (del c del c -- del c f)
            rj.z _wb_del_loop    # (del c f -- del c) ; note: c needs to be dropped if branch is taken

            # now c is first non-delimiter char
            # put this into scratch area


_word_eob:  lit 0 [ret] # end of buffer, return 0
