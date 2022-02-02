.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_BYTE_SIZE 80


call _tibcfetch_body



.word SIM_END

# variables
state: .word 0 # 0: interpreting, -1: compiling
ntib: .word 9   # number of chars in tib
# tib: .space TIB_BYTE_SIZE
tib: .ascii "drop dup " # input buffer
to_in: .word 3  # current char idx in tib
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
            a:add t d- r- [ret] # (n 1 -- n+1)


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
            a:mem t r- [ret]


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
            a:nop t r- [ret]


_base:      # ( -- addr)
            .word _tibcfetch
            .cstr "base"
_base_body:
            lit base [ret]


_fetch:     # (addr -- n)
            .word _base
            .cstr "@"
_fetch_body:
            a:mem t r- [ret]


_store:     # (d addr -- )
            .word _fetch
            .cstr "!"
_store_body:
            a:n mem d-
            a:nop r d- r- [ret]


_drop:      # ( n -- )
            .word _store
            .cstr "drop"
_drop_body:
            a:nop t d- r- [ret]


_dup:       # (a -- a a)
            .word _drop
            .cstr "dup"
_dup_body:
            a:t t d+ r- [ret]


_2dup:      # (a b -- a b a b)
            .word _dup
            .cstr "2dup"
_2dup_body:
            a:n t d+
            a:n t d+ r- [ret]


_swap:      # (a b -- b a)
            .word _2dup
            .cstr "swap"
_swap_body:
            a:t r d- r+      # (a b -- a r:b)
            a:t t d+         # (a r:b -- a a r:b)
            a:r t d- r-      # (a a r:b -- b a)
            a:nop t d+ r- [ret] # (b a -- b a)


_over:      # (a b -- a b a)
            .word _swap
            .cstr "over"
_over_body:
            a:n t d+ r- [ret]


_rot:       # (a b c -- b c a)
            .cstr "rot"
            .word _over
_rot_body:  # todo


_nip:       # (a b -- b)
            .word _rot
            .cstr "nip"
_nip_body:  
            a:t t d- r- [ret]


_tuck:      # (a b -- b a b)
            .word _nip
            .cstr "tuck"
_tuck_body: 
            call _swap_body # ( a b -- b a)
            call _over_body # ( b a -- b a b)
            a:nop t r- [ret]

_to_r:      # (n -- r:n)
            .word _tuck
            .cstr ">r"
_to_r_body: a:t r d- r+ [ret]


_r_from:    # (r:n -- n)
            .word _to_r
            .cstr "r>"
_r_from_body:
            a:r t d+ r- [ret]


_wait_uart_tx_can_send: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_TX_FULL
            a:and t d-
            rj.nz _wait_uart_tx_can_send
            a:nop t r- [ret]


_emit:      # (c --)
            .word _r_from
            .cstr "emit"
_emit_body: call _wait_uart_tx_can_send
            lit ADDR_UART_TX
            call _store_body
            a:nop t r- [ret]


_wait_uart_rx_has_data: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_RX_EMPTY
            a:and t d-
            rj.z _wait_uart_rx_has_data
            a:nop t r- [ret]


_key:       # ( -- key)
            .word _emit
            .cstr "key"
_key_body:
            call _wait_uart_rx_has_data
            lit ADDR_UART_RX
            a:mem t r- [ret]


_charidxwordaddr:  # (str-addr char-idx -- wa)
            # fetch word which contains char at char-idx
            # divide index by 2
            a:sr t                # (sa ci -- sa i)
            # get addr of word containing char
            a:add t d- r- [ret]   # (sa i -- sa+i)


_strcfetch: # (char-idx str-addr -- c)
            # fetch char at index from str
            .word _key
            .cstr "sc@" # "string char fetch"
_strcfetch_body:
            call _over_body       # (ci sa -- ci sa ci)
            call _charidxwordaddr # (ci sa ci -- ci wa)
            call _fetch_body      # (ci wa -- ci w)
            call _swap_body       # (ci w -- w ci)
            lit 1                 # (w ci -- w ci 1)
            a:and t d-            # (w ci 1 -- w ci&1)
            # endianess is handled here:
            rj.nz _strcf1         # (w ci&1 -- w)
            a:srw t               # (w -- w>>8)
_strcf1:    lit $ff               # (w -- w $ff)
            a:and t d- r- [ret]      # (w -- w&$ff)


_cscfetch:  # (char-idx cstr-addr -- char)
            # fetch char at index from cstr
            .word _strcfetch
            .cstr "csc@" # "counted string char fetch"
_cscfetch_body:
            # add 1 because counted string
            call _add1_body       # (ci ca i -- ci ca i+1)
            call _strcfetch_body  # (ci ca i+1 -- c)
            a:nop t r- [ret]


_strcstore: # (char char-idx str-addr -- )
            .word _cscfetch
            .cstr "sc!"
_strcstore_body:
            call _swap_body         # (c ci sa         -- c sa ci)
            call _over_body         # (c sa ci         -- c sa ci ci)
            call _charidxwordaddr   # (c ci sa ci      -- c ci wa)
            a:t r r+                # (c ci wa         -- c ci wa    R:wa)
            call _fetch_body        # (c ci wa    R:wa -- c ci w     R:wa)
            # for better readability, don't mention the R stack until it is used again
            call _swap_body         # (c ci w      -- c w ci)
            lit 1                   # (c w ci      -- c w ci 1)
            a:and t d-              # (c w ci 1    -- c w ci&1)
            # if t=0, put char in upper byte of w
            # if t=1, put char in lower byte of w
            rj.nz _strcs1           # (c w ci&1  -- c w)
            # put char in lower byte
            lit $ff00               # (c w       -- c w $ff00)
            a:and t d-              # (c w $ff00 -- c wu)
            call _swap_body         # (c wu      -- wu c)
            rj _strcs2
_strcs1:    # put char in upper byte
            lit $ff                 # (c w     -- c w $ff)
            a:and t d-              # (c w $ff -- c wl)
            call _swap_body         # (c wl    -- wl c)
            a:slw t                 # (wl c    -- wl c<<8)
_strcs2:
            a:or t d-               # (wu/wl c      -- W   R:wa)
            call _r_from_body       # (W    R:wa -- W wa)
            call _store_body        # (W wa      -- )
            a:nop t r- [ret]




_tib_eob:   # (-- flag)
            # if >in reached end of buffer return 0
            call _to_in_body
            call _fetch_body
            lit TIB_BYTE_SIZE
            a:sub t d- r- [ret]


_to_in_plus1: # (--)
            # inc >in
            call _to_in_body
            call _fetch_body
            call _add1_body
            call _to_in_body
            call _store_body
            a:nop t r- [ret]


_word:      # (delimiter -- count addr-str)
            # skip delimiters
            # take idx of first non-delimiter
            # 
            .word _strcstore
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

            # initialize char count to 0
            lit 0
            lit ntib # number of chars in tib
            call _store_body





_word_eob:  lit 0 [ret] # end of buffer, return 0
