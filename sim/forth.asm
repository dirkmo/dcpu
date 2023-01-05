.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_SIZE 64


lit num
lit 1
a:add t d-
call _number # (a -- n f)

.word SIM_END

# ----------------------------------------------------
num: .cstr "-$123 "

str1: .cstr "herea"

tupel1: .space 3
tupel2: .space 3

# variables
state: .word 0          # 0: interpreting, -1: compiling

base: .word 10
latest: .word _number_header   # last word in dictionary
dp: .word dp_init       # first free cell after dict

tib: .space TIB_SIZE


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


_base_header:      # ( -- addr)
            .word _latest_header
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


_copy_header: # ( a-from a-to count -- )
            # copy count words from a-from to a-to
            .word _key_header
            .cstr "move"
_copy:
            a:t r d- r+         # (a1 a2 cnt -- a1 a2 r:cnt)
            call _over          # (a1 a2 -- a1 a2 a1)
            call _fetch         # (a1 a2 a1 -- a1 a2 w)
            call _over          # (a1 a2 w -- a1 a2 w a2)
            call _store         # (a1 a2 w a2 -- a1 a2)
            # a1++
            lit 1               # (a1 a2 -- a1 a2 1)
            a:add t d-          # (a1 a2 1 -- a1 a2+1)
            a:t r d- r+         # (a1 a2 -- a1 r:cnt a2)
            # a2++
            lit 1               # (a1 r:cnt a2 -- a1 1 r:cnt a2)
            a:add t d-          # (a1 1 r:cnt a2 -- a1+1 r:cnt a2)
            a:r t d+ r-         # (a1 r:cnt a2 -- a1 a2 r:cnt)
            # cnt--
            a:r t d+ r-         # (a1 a2 r:cnt -- a1 a2 cnt)
            lit 1
            a:sub t d-          # (a1 a2 cnt 1 -- a1 a2 cnt-1)
            call _dup           # (a1 a2 cnt -- a1 a2 cnt cnt)
            rj.nz _copy         # (a1 a2 cnt cnt -- a1 a2 cnt)
_copy_done:
            call _2drop
            a:nop t d- r- [ret]


_upchar_header: # (c -- C)
        # convert char to upper case
        .word _copy_header
        .cstr "upchar"
_upchar:
        call _dup       # (c -- c c)
        lit 32          # ( c c -- c c 32)
        a:sub t d-      # ( c c 32 -- c c-32)
        call _dup       # ( c C -- c C C)
        lit 65 # 'A'    # ( c C C -- c C C 65)
        a:lt t d-       # ( c C C 65 -- c C f)
        rj.nz _upchar_1 # ( c C f -- c C)
        call _dup       # ( c C -- c C C)
        lit 91 # 90='Z' # ( c C C -- c C C 91)
        a:lt t d-       # ( c C C 91 -- c C f)
        rj.z _upchar_1  # ( c C f -- c C)
        call _nip       # ( c C -- C)
_upchar_done:
        a:nop t r- [ret]    # (c -- c)
_upchar_1: # (c C)
        a:nop t d- r- [ret] # (c C -- c)


_digit2number_header:  # (c -- n f) TODO only base16 ATM
        # convert hexchar to int n
        # f=0 on error, f=1 on success
        .word _upchar_header
        .cstr "digit>num"
_digit2number:
        call _upchar            # (c -- C)
        lit 48                  # (c -- c '0')
        a:sub t d-              # (c '0' -- n)
        call _dup               # (n -- n n)
        rj.n _digit2number_error    # (n n -- n)
        lit 10                  # (n -- n 10)
        a:sub t                 # (n 10 -- n n-10)
        # if T < 0: number 0-9
        rj.nn _digit2number_hex # (n f -- n)
        lit 1 [ret]             # (n - n 1)
_digit2number_hex: # (n)
        lit 7                   # (n -- n 7)
        a:sub t d-              # (n 7 -- n-7)
        call _dup               # (n -- n n)
        lit 16                  # (n n -- n n 16)
        a:sub t d-              # (n n 16 -- n n-16)
        rj.nn _digit2number_error # (n f -- n)
        lit 1 [ret]             # (n -- n 1)
_digit2number_error:            # (n)
        lit 0 [ret]             # (n -- n 0)


_str_getc_next_header: # (a -- a+1 c)
        # get char at a
        # increment a
        .word _digit2number_header
        .cstr "str_getc_next"
_str_getc_next:
        call _dup               # (a -- a a)
        call _add1              # (a a -- a a+1)
        call _swap              # (a a+1 -- a+1 a)
        a:mem t r- [ret]        # (a+1 a -- a+1 c)


_is_ws_header: # (c -- f)
        # is c white space?
        # f=1 if white space
        .word _str_getc_next_header
        .cstr "ws?"
_is_ws:
        lit 33                  # (c -- c 33)
        a:lt t d- r- [ret]      # (c 33 -- f)


_number_header: # (a -- n f)
         # convert string tuple (si sa sc) at a to number n.
         # It starts parsing at index si and stops at si==sc.
         # White space (chars with ascii value < 33) is considered as end-of-number.
         # f is 0 on error, else -1 on success
        .word _is_ws_header
        .cstr "number"
_number:
        # save current base
        call _base
        call _fetch
        a:t r d- r+             # (a base -- a r:base)
        # is first char minus sign (45)?
        # if yes, push minus? == 0 on rstack
        # if no,  push minus? != 0 on rstack
        call _str_getc_next          # (a -- a c)
        lit 45 # '-'
        a:sub t                 # (a c 45 -- a c minus?)
        a:t r r+                # (a c minus? -- a c minus? r:base minus?)
        rj.nz _number__1        # (a c minus? -- a c r:base minus?)
        # c is minus-sign, skip it
        call _drop              # (a c -- a)
        call _dup               # (a -- a a)
        call _str_getc_next     # (a a -- a c)
_number__1: # (a c r:base minus?)
        # is char dollar sign (36)?
        lit 36 # '$'
        a:sub t                 # (a c 36 -- a c dollar?)
        rj.nz _number__2        # (a c dollar? -- a c)
        # c is is dollar --> change base to 16
        lit 16
        call _base
        call _store
        call _drop              # (a c -- a)
        # skip dollar sign
        call _str_getc_next     # (a -- a c)
_number__2: # (a c r:base minus?)
        # now, minus '-' and/or dollar '$' are processed. Now the digit parsing starts.
        # first, push res=0 on rstack
        lit 0
        a:t r d- r+             # (a c 0 -- a c r:base minus? res)
_number_loop: # (a c r:base minus? res)
        # is end-of-string (white space)?
        call _dup               # (a c -- a c c r:base minus? res)
        call _is_ws             # (a c c -- a c f r:base minus? res)
        rj.nz _number_done      # (a c f -- a c r:base minus? res)
        call _digit2number      # (a c -- a n f)
        rj.z _number_error2     # (a n f -- a n r:base minus? res) # f=0: conversion failed
        # is number valid in current base? Means: (n < base) must be true
        call _dup               # (a n -- a n n)
        call _base
        call _fetch
        a:lt t d-               # (a n n base -- a n numvalid?)
        rj.z _number_error2     # (a n numvalid? -- a n r:base minus? res)
        # yes, n is a valid digit.
        # now get res from rstack, multiply with base and add n
        call _base
        call _fetch             # (a n a-base -- a n base)
        a:r t d+ r-             # (a n base r:base minus? res -- a n base res r:base minus?)
        a:mull t d-             # (a n base res -- a n base*res)
        a:add t d-              # (a n res -- a n+res)
        a:t r d- r+             # (a res -- a r:base minus? res)
        call _str_getc_next     # (a -- a c)
        rj _number_loop
_number_done: # (a c r:base minus? res)
        # white space encountered. Parsing is done.
        a:r t d- r-             # (a c r:base minus? res -- res r:base minus?)
        a:r t d+ r-             # (res r:base minus? -- res minus? r:base)
        rj.nz _number_positive  # (res minus? -- res r:base) ; minus?=0 if negative number
        lit 0
        call _swap              # (res 0 r:base -- 0 res r:base)
        a:sub t d-              # (0 res r:base -- 0-res r:base)
_number_positive:
        lit -1                  # (res -- res f r:base) ; -1 for success
        rj _number_exit
_number_error2: # (a n r:base minus? res)
        a:nop t d- r-               # (a n r:base minus? res -- a r:base minus?)
        a:nop t r-                  # (a r:base minus? -- a r:base)
        lit 0                       # (a r:base -- a 0 r:base)
_number_exit: # (w r:base)
        # restore base
        a:r t d+ r-
        call _base
        call _store
        a:nop t r- [ret]




dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
