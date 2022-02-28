.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_WORD_COUNT 32


lit 0
lit wort1
lit 10
call _str_init


.word SIM_END

wort1: .cstr "gibtsnicht"

# ----------------------------------------------------

# variables
state: .word 0          # 0: interpreting, -1: compiling
ntib: .word 0           # number of chars in tib
tib: .space TIB_WORD_COUNT

to_in: .word 0          # current char idx in tib
base: .word 10
latest: .word _str_eos_header   # last word in dictionary
dp: .word dp_init       # first free cell after dict

cstrscratch: .space 33

str1: .space 3 # for idx/addr/len tuple of a string
str2: .space 3 # for idx/addr/len tuple of a string

# dictionary

_here_header:      # (-- n)
            # here returns the address of the first free cell in the data space
            .word 0
            .cstr "here"
_here:
            lit dp
            a:mem t r- [ret]


_here_add:  # (n -- )
            # helper function, not a word
            call _here     # (n -- n a)
            a:add t d-          # (n a -- n+a)
            lit dp              # (a -- a dp)
            call _store    # (a dp -- )
            a:nop t r- [ret]


_comma_header:     # (w --)
            # comma puts a word into the cell pointed to by here
            # and increments the data space pointer (value returned by here)
            .word _here_header
            .cstr ","
_comma:
            call _here     # (w -- w a)
            call _store    # (w a -- )
            lit 1               # ( -- 1)
            call _here_add      # (1 --)
            a:nop t r- [ret]


_allot_header:     # (n -- )
            .word _comma_header
            .cstr "allot"
_allot:
            call _here_add      # (n -- )
            a:nop t r- [ret]


_add1_header:      # (n -- n+1)
            .word _allot_header
            .cstr "+1"
_add1:
            lit 1            # (n -- n 1)
            a:add t d- r- [ret] # (n 1 -- n+1)


_plus_store_header: # (n addr --)
             # add n to variable at addr
            .word _add1_header
            .cstr "+!"
_plus_store:
            a:mem r r+          # (n a -- n a r:w) ; fetch into r
            call _swap     # (n a r:w -- a n r:w)
            a:r t d+ r-         # (a n r:w -- a n w)
            a:add t d-          # (a n w -- a n+w)
            call _swap     # (a n+w -- n+w a)
            a:n mem d-          # (n+w a -- n+w)
            a:nop t d- r- [ret] # (n+w -- )


_latest_header:    # ( -- addr)
            .word _plus_store_header
            .cstr "latest"
_latest:
            lit latest
            a:mem t r- [ret]


_tib_header:       # ( -- addr)
            # input area as ascii string
            .word _latest_header
            .cstr "tib"
_tib:
            lit tib [ret]


_ntib_header:      # ( -- n)
            # number of chars in input area
            .word _tib_header
            .cstr "#tib"
_ntib:
            lit ntib
            a:mem t r- [ret]


_to_in_header:     # ( -- n )
            # return addr of index of current char in input buffer
            .word _ntib_header
            .cstr ">in"
_tio_in:
            lit to_in [ret]


_base_header:      # ( -- addr)
            .word _to_in_header
            .cstr "base"
_base:
            lit base [ret]


_fetch_header:     # (addr -- n)
            .word _base_header
            .cstr "@"
_fetch:
            a:mem t r- [ret]


_store_header:     # (d addr -- )
            .word _fetch_header
            .cstr "!"
_store:
            a:n mem d-
            a:nop r d- r- [ret]


_drop_header:      # ( n -- )
            .word _store_header
            .cstr "drop"
_drop:
            a:nop t d- r- [ret]


_2drop_header:     # ( n n -- )
            .word _drop_header
            .cstr "2drop"
_2drop:
            a:nop t d-
            a:nop t d- r- [ret]


_dup_header:       # (a -- a a)
            .word _2drop_header
            .cstr "dup"
_dup:
            a:t t d+ r- [ret]


_2dup_header:      # (a b -- a b a b)
            .word _dup_header
            .cstr "2dup"
_2dup:
            a:n t d+
            a:n t d+ r- [ret]


_swap_header:      # (a b -- b a)
            .word _2dup_header
            .cstr "swap"
_swap:
            a:t r d- r+      # (a b -- a r:b)
            a:t t d+         # (a r:b -- a a r:b)
            a:r t d- r-      # (a a r:b -- b a)
            a:nop t d+ r- [ret] # (b a -- b a)


_over_header:      # (a b -- a b a)
            .word _swap_header
            .cstr "over"
_over:
            a:n t d+ r- [ret]


_rot_header:       # (a b c -- b c a)
            .word _over_header
            .cstr "rot"
_rot:
            a:t r d- r+     # (a b c -- a b r:c)
            call _swap      # (a b r:c -- b a r:c)
            a:r t d+ r-     # (b a r:c -- b a c)
            call _swap      # (b a c -- b c a)
            a:nop t r- [ret]


_nip_header:       # (a b -- b)
            .word _rot_header
            .cstr "nip"
_nip:
            a:t t d- r- [ret]


_tuck_header:      # (a b -- b a b)
            .word _nip_header
            .cstr "tuck"
_tuck:      call _swap # ( a b -- b a)
            call _over # ( b a -- b a b)
            a:nop t r- [ret]


_min_header:       # (n1 n2 -- min)
            .word _tuck_header
            .cstr "min"
_min:       a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.nz _min__1   # (n1 n2 lt -- n1 n2)
            call _nip  # (n1 n2 -- n2)
            rj _min__2
_min__1:    call _drop # (n1 n2 -- n1)
_min__2:    a:nop t r- [ret]


_max_header:       # (n1 n2 -- min)
            .word _min_header
            .cstr "max"
_max:       a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.z _max__1    # (n1 n2 lt -- n1 n2)
            call _nip  # (n1 n2 -- n2)
            rj _max__2
_max__1:    call _drop # (n1 n2 -- n1)
_max__2:    a:nop t r- [ret]


_to_r_header:      # (n -- r:n)
            .word _max_header
            .cstr ">r"
_to_r:      a:r t d+ r-      # (n r:a -- n a)
            call _swap  # (n a -- a n)
            a:t r d- r+      # (a n -- a r:n)
            a:t pc d-        # (a r:n -- r:n)


_r_from_header:    # (r:n -- n)
            .word _to_r_header
            .cstr "r>"
_r_from:    a:r t d+ r-       # (r:n a -- a r:n) ; rpop return address
            a:r t d+ r-       # (a r:n -- a n)   ; pop value to retrieve
            call _swap   # (a n -- n a)
            a:t pc d-         # (n a -- n)


_wait_uart_tx_can_send: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_TX_FULL
            a:and t d-
            rj.nz _wait_uart_tx_can_send
            a:nop t r- [ret]


_emit_header:      # (c --)
            .word _r_from_header
            .cstr "emit"
_emit:      call _wait_uart_tx_can_send
            lit ADDR_UART_TX
            call _store
            a:nop t r- [ret]


_wait_uart_rx_has_data: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_RX_EMPTY
            a:and t d-
            rj.nz _wait_uart_rx_has_data
            a:nop t r- [ret]


_key_header:       # ( -- key)
            .word _emit_header
            .cstr "key"
_key:
            call _wait_uart_rx_has_data
            lit ADDR_UART_RX
            a:mem t r- [ret]


_str_init_header: # (si sa sc a -- )
        # create tuple si/sa/sc at address a
        # si: string char index
        # sa: string address
        # sc: string char count
        # a: address of new str-tuple
        .word _key_header
        .cstr "str-init"
_str_init:
        a:t r r+                # (si sa sc a -- si sa sc a r:a)
        lit 2
        a:add t d-              # (si sa sc a -- si sa sc a+2)
        call _store        # (si sa sc a -- si sa r:a)
        a:r t d+                # (si sa r:a -- si sa a r:a)
        lit 1
        a:add t d-              # (si sa a -- si sa a+1)
        call _store        # (si sa a -- si r:a)
        a:r t d+ r-             # (si r:a -- si a)
        a:t mem d- r- [ret]


_str_idx_header: # (a -- idx)
        # get current char idx of string tuple (si sa sc) at address a
        .word _str_init_header
        .cstr "str-idx"
_str_idx:
        a:mem t r- [ret]


_str_addr_header: # (a -- sa)
        # get base address sa of string tuple (si sa sc) at address a
        .word _str_idx_header
        .cstr "str-addr"
_str_addr:
        lit 1
        a:add t d-
        a:mem t r- [ret]


_str_cnt_header: # (a -- sc)
        # get char count sc of string tuple (si sa sc) at address a
        .word _str_addr_header
        .cstr "str-cnt"
_str_cnt:
        lit 2
        a:add t d-
        a:mem t r- [ret]


_str_getc_header: # (a -- c)
        # get char of string at idx defined by tuple si/sa/sc
        .word _str_cnt_header
        .cstr "str-getc"
_str_getc:
        call _dup      # (a -- a a)
        call _str_idx  # (a a -- a si)
        lit 1
        a:add t d-          # (a si 1 -- a si+1) # add 1 for rounding
        a:sr t              # (a si -- a si/2)
        a:add t d-          # (a i -- a+i)
        a:mem t r- [ret]


_str_putc_header: # (c a -- )
        # put char c into string tuple (si sa sc) at address a
        # c is written to char idx si
        .word _str_getc_header
        .cstr "str-putc"
_str_putc:
        # TODO


_str_next_header: # (a -- )
        # increase char index si of tuple si/sa/sc to next char
        .word _str_putc_header
        .cstr "str-next"
_str_next:
        call _dup      # (a -- a a)
        call _str_idx  # (a -- a si)
        lit 1
        a:add t d-          # (a si -- a si+1)
        call _swap     # (a si -- si a)
        call _store    # (si a -- )
        a:nop t r- [ret]


_str_getc_next_header: # (a -- c)
        # get char of string tuple si/sa/sc and increase index si
        .word _str_next_header
        .cstr "str-get-next"
_str_getc_next:
        call _dup      # (a -- a a)
        call _str_getc # (a a -- a c)
        call _swap     # (a c -- c a)
        call _str_next # (c a -- c)
        a:nop t r- [ret]


_str_eos_header: # (a -- f)
        # return 0 if end-of-string is reached of string tuple si/sa/sc.
        # return $ffff otherwise
        # end-of-string means that si >= sc
        .word _str_getc_next_header
        .cstr "str-eos"
_str_eos:
        call _dup          # (a -- a a)
        call _str_idx      # (a a -- a si)
        call _swap         # (a si -- si a)
        call _str_cnt      # (si a -- si sc)
        a:lt t d- r- [ret] # (si sc -- f)


_str_append_header: # (a c -- )
        # append char c to string tuple (si sa sc) at address a
        .word _str_eos_header
        .cstr "str-append"
_str_append:
        # TODO


_str_pop_header: # (a -- )
        # delete last char from string tuple (si sa sc) at address a
        # by decrementing count sc
        .word _str_append_header
        .cstr "str-pop"
_str_pop:
        lit 2
        a:add t d-      # (a 2 -- a+2)
        call _dup       # (a -- a a)
        a:mem t         # (a a -- a sc)
        call _dup       # (a sc -- a sc sc)
        rj.z _str_pop__1 # (a sc sc -- a sc)
        lit 1
        a:sub t d-      # (a sc 1 -- a sc-1)
        call _swap      # (a sc -- sc a)
        call _store     # (sc a -- )
        a:nop t r- [ret]
_str_pop__1: # (a sc)
        a:nop t d-
        a:nop t d- r- [ret]


dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
