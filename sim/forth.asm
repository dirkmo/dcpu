.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_WORD_COUNT 32
.equ TIB_CHAR_COUNT 64

lit str1
lit tupel1
call _str_init_cstr

lit tupel1
call _find

.word SIM_END

# ----------------------------------------------------

str1: .cstr "herea"

tupel1: .space 3
tupel2: .space 3

# variables
state: .word 0          # 0: interpreting, -1: compiling

base: .word 10
latest: .word _find_header   # last word in dictionary
dp: .word dp_init       # first free cell after dict
tibtuple: .word 0, tib, TIB_CHAR_COUNT

tib: .space TIB_WORD_COUNT

cstrscratch: .space 33


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


_str_init_header: # (si sa sc a -- )
        # create tuple si/sa/sc at address a
        # si: string char index
        # sa: string address
        # sc: string char count
        # a: address of new str-tuple
        .word _copy_header
        .cstr "str-init"
_str_init:
        a:t r r+           # (si sa sc a -- si sa sc a r:a)
        lit 2
        a:add t d-         # (si sa sc a -- si sa sc a+2)
        call _store        # (si sa sc a -- si sa r:a)
        a:r t d+           # (si sa r:a -- si sa a r:a)
        lit 1
        a:add t d-         # (si sa a -- si sa a+1)
        call _store        # (si sa a -- si r:a)
        a:r t d+ r-        # (si r:a -- si a)
        call _store        # (si a -- )
        a:nop t r- [ret]


_str_init_cstr_header: # (cstr tstr -- )
        .word _str_init_header
        .cstr "str-init-cstr"
        # initialize tstr from cstr
_str_init_cstr:
        a:t r d- r+     # (cstr tstr -- cstr r:tstr)
        call _dup       # (cstr -- cstr cstr)
        a:mem t         # (cstr cstr -- cstr sc)
        a:r t d+        # (cstr sc -- cstr sc tstr)
        call _str_set_cnt # (cstr sc tstr -- cstr)
        lit 0
        a:r t d+        # (cstr 0 -- cstr 0 tstr)
        call _str_set_idx # (cstr 0 tstr -- cstr)
        call _add1      # (cstr -- cstr+1 r:tstr)
        a:r t d+ r-     # (sa r:tstr -- sa tstr)
        call _str_set_addr # (sa tstr -- )
        a:nop t r- [ret]


_str_clear_header: # (a -- )
        # set si and sc of string tuple (si sa sc) to zero
        .word _str_init_cstr_header
        .cstr "str-clear"
_str_clear:
        lit 0
        call _swap      # (a 0 -- 0 a)
        call _2dup      # (0 a -- 0 a)
        call _str_set_idx # (0 a 0 a -- 0 a)
        call _str_set_cnt # (0 a -- )
        a:nop t r- [ret]


_str_idx_header: # (a -- idx)
        # get current char idx of string tuple (si sa sc) at address a
        .word _str_clear_header
        .cstr "str-idx"
_str_idx:
        a:mem t r- [ret]


_str_set_idx_header: # (new-si a -- )
        # set si of string tuple (si sa sc) to new-si
        .word _str_idx_header
        .cstr "str-set-idx"
_str_set_idx:
        call _store
        a:nop t r- [ret]


_str_addr_header: # (a -- sa)
        # get base address sa of string tuple (si sa sc) at address a
        .word _str_set_idx_header
        .cstr "str-addr"
_str_addr:
        lit 1
        a:add t d-
        a:mem t r- [ret]


_str_set_addr_header: # (new-sa a -- )
        # set sa of string tuple (si sa sc) to new-sa
        .word _str_addr_header
        .cstr "str-set-addr"
_str_set_addr:
        lit 1
        a:add t d-  # (new-sa a 1 -- new-sa a+1)
        call _store # (new-sa a -- )
        a:nop t r- [ret]


_str_cnt_header: # (a -- sc)
        # get char count sc of string tuple (si sa sc) at address a
        .word _str_set_addr_header
        .cstr "str-cnt"
_str_cnt:
        lit 2
        a:add t d-
        a:mem t r- [ret]


_str_set_cnt_header: # (new-sc a -- )
        # set sc of string tuple (si sa sc) to new-sc
        .word _str_cnt_header
        .cstr "str-set-cnt"
_str_set_cnt:
        lit 2
        a:add t d-      # (new-sc a 2 -- new-sc a+2)
        call _store     # (new-sc a -- )
        a:nop t r- [ret]


_str_wa_header: # (a -- swa)
        # return address of word (wa), which contains
        # char addressed by string tuple (si sa sc)
        .word _str_set_cnt_header
        .cstr "str-wa"
_str_wa:
        call _dup       # (a -- a a)
        call _str_idx   # (a a -- a si)
        a:sr t          # (a si -- a wi)
        call _swap      # (a si -- si a)
        call _str_addr  # (si a -- si wa)
        a:add t d- r- [ret]


_str_len_header: # (a1 -- len)
        # determine length (char count) of t-str
        .word _str_wa_header
        .cstr "str-len"
_str_len:
        call _dup       # (a1 -- a1 a1)
        call _str_cnt   # (a1 a1 -- a1 sc)
        call _swap      # (a1 sc -- sc a1)
        call _str_idx   # (sc a1 -- sc si)
        a:sub t d- r- [ret] # (sc si -- len)


_str_cmp_header: # (a1 a2 -- f)
        # compare t-str a1 to t-str a2
        # f=0: strings are equal
        # f=$ffff: strings are different
        .word _str_len_header
        .cstr "str-cmp"
_str_cmp:
        a:t r r+        # (a1 a2 -- a1 a2 r:a2)
        call _str_idx   # (a1 a2 -- a1 si2 r:a2)
        call _swap      # (a1 si2 -- si2 a1 r:a2)
        a:t r r+        # (si2 a1 -- si2 a1 r:a2 a1)
        call _str_idx   # (si2 a1 -- si2 si1 r:a2 a1)
        a:r t d+ r-     # (si2 si1 -- si2 si1 a1 r:a2)
        a:r t d+        # (si2 si1 a1 r:a2 -- si2 si1 a1 a2 r:a2)
        # first, compare lengths
        call _str_len   # (si2 si1 a1 a2 -- si2 si1 a1 l2)
        call _over      # (si2 si1 a1 l2 -- si2 si1 a1 l2 a1)
        call _str_len   # (si2 si1 a1 l2 a1 -- si2 si1 a1 l2 l1)
        a:sub t d-      # (si2 si1 a1 l2 l1 -- si2 si1 a1 l2-l1)
        rj.nz _str_cmp_ne # (si2 si1 a1 n -- si2 si1 a1)
        # len is equal, compare chars
_str_cmp_loop: # (si2 si1 a1 r:a2)
        call _dup       # (si2 si1 a1 -- si2 si1 a1 a1)
        call _str_eos   # (si2 si1 a1 a1 -- si2 si1 a1 ~eos)
        rj.z _str_cmp_eq # (si2 si1 a1 ~eos -- )
        call _dup       # (si2 si1 a1 -- si2 si1 a1 a1)
        call _str_getc_next # (si2 si1 a1 a1 -- si2 si1 a1 c1)
        a:r t d+        # (si2 si1 a1 c1 -- si2 si1 a1 c1 a2)
        call _str_getc_next # (si2 si1 a1 c1 a2 -- si2 si1 a1 c1 c2)
        a:sub t d-      # (si2 si1 a1 c1 c2 -- si2 si1 a1 c1-c2)
        rj.z _str_cmp_loop # (si2 si1 a1 f -- si2 si1 a1 r:a2)
_str_cmp_ne: # (si2 si1 a1 r:a2)
        lit $ffff
        rj _str_cmp_ret # (si2 si1 a1 f r:a2)
_str_cmp_eq: # (si2 si1 a1 r:a2)
        lit 0
_str_cmp_ret: # (si2 si1 a1 f r:a2)
        a:t r d- r+     # (si2 si1 a1 f -- si2 si1 a1 r:a2 f)
        call _str_set_idx # (si2 si1 a1 -- si2 r:a2 f)
        a:r t d+ r-     # (si2 -- si2 f r:a2)
        call _swap      # (si2 f -- f si2 r:a2)
        a:r t d+ r-     # (f si2 -- f si2 a2)
        call _str_set_idx # (f si2 a2 -- f)
        a:nop t r- [ret]


_char_to_word_header: # (c wa f -- )
        # put char c into word at address wa.
        # if f is even: *wa = (*wa & 0x00ff) | (c << 8)
        # if f is odd:  *wa = (*wa & 0xff00) | c
        .word _str_cmp_header
        .cstr "char>word"
_char_to_word:
        lit 1
        a:and t d-      # (c wa f 1 -- c wa f&1)
        rj.z _char_to_word_lower # (c wa f -- c wa)
        call _swap      # (c wa -- wa c)
        a:slw t         # (wa c -- wa c<<8)
        call _over      # (wa c' -- wa c' wa)
        a:mem t         # (wa c' wa -- wa c' w)
        lit $ff00
        a:and t d-      # (wa c' w $ff00 -- wa c' w&$ff00)
        rj _char_to_word__1
_char_to_word_lower:    # (c wa)
        a:mem t d+      # (c wa -- c wa w)
        lit $ff
        a:and t d-      # (c wa w $ff -- c wa w&$ff)
_char_to_word__1: # (wa c' w)
        a:or t d-       # (wa c' w -- wa (c'|w) )
        call _swap      # (wa w -- w wa)
        call _store     # (w wa -- )
        a:nop t r- [ret]


_str_getc_header: # (a -- c)
        # get char of string at idx defined by tuple si/sa/sc
        .word _char_to_word_header
        .cstr "str-getc"
_str_getc:
        a:t r r+        # (a -- a r:a)
        call _str_wa    # (a -- wa r:a)
        a:mem t         # (wa -- w r:a)
        a:r t d+ r-     # (w r:a -- w a)
        call _str_idx   # (w a -- w si)
        lit 1
        a:and t d-      # (w si 1 -- w si&1)
        rj.z _str_getc_upperbyte # (w f -- w)
        # lower byte
        lit $ff
        a:and t d- r- [ret] # (w $ff00 -- c)
_str_getc_upperbyte: # (w)
        a:srw t r- [ret]


_str_putc_header: # (c a -- )
        # put char c into string tuple (si sa sc) at address a
        # c is written to char idx si, does not change char count sc
        .word _str_getc_header
        .cstr "str-putc"
_str_putc:
        a:t r r+        # (c a -- c a r:a)
        call _str_wa    # (c a -- c wa)
        a:mem t d+      # (c wa -- c wa w)
        a:r t d+ r-     # (c wa w r:a -- c wa w a)
        call _str_idx   # (c wa w a -- c wa w idx)
        lit 1
        a:and t d-      # (c wa w idx 1 -- c wa w idx&1)
        rj.z _str_putc_upperbyte # (c wa w f -- c wa w)
        # odd idx --> put char into lower byte of *wa
        lit $ff00
        a:and t d-      # (c wa w $ff00 -- c wa w&$ff00)
        call _rot       # (c wa h -- wa h c)
        a:or t d-       # (wa h c -- wa w)
        rj _str_putc__1
_str_putc_upperbyte: # (c wa w)
        # even idx --> put char into upper byte of *wa
        lit $ff
        a:and t d-      # (c wa w $ff -- c wa w&$ff)
        call _rot       # (c wa l -- wa l c)
        a:slw t         # (wa l c -- wa l c<<8)
        a:or t d-       # (wa l h -- wa w)
_str_putc__1: # (wa w)
        call _swap      # (wa w -- w wa)
        call _store     # (w wa -- )
        a:nop t r- [ret]


_str_next_header: # (a -- )
        # increase char index si of tuple si/sa/sc to next char
        # does not care about string length
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


_str_append_header: # (c a -- )
        # append char c to string tuple (si sa sc) at address a
        # si will point after last char (si == sc)
        # sc will be incremented
        .word _str_eos_header
        .cstr "str-append"
_str_append:
        a:t r r+            # (c a -- c a r:a)
        call _dup           # (c a -- c a a)
        call _str_cnt       # (c a a -- c a cnt)
        call _dup           # (c a cnt -- c a cnt cnt)
        lit 1
        a:add t d-          # (c a cnt cnt 1 -- c a cnt cnt+1)
        a:r t d+            # (c a cnt cnt+1 r:a -- c a cnt cnt+1 a)
        call _str_set_cnt   # (c a cnt cnt+1 a -- c a cnt)
        call _swap          # (c a cnt -- c cnt a)
        call _str_set_idx   # (c cnt a -- c)
        a:r t d+            # (c r:a -- c a r:a)
        call _str_putc      # (c a -- )
        a:r t d+ r-         # (r:a -- a)
        call _str_next
        a:nop t r- [ret]


_str_pop_header: # (a -- )
        # delete last char from string tuple (si sa sc) at address a
        # by decrementing count sc
        # will not change si
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


_str_dup_header: # (a1 a2 -- )
        # duplicate string tuple a1 into a2
        # Copies the tuple a1 to a2, not the string itself
        .word _str_pop_header
        .cstr "str-dup"
_str_dup:
        lit 3
        call _copy
        a:nop t r- [ret]


_upchar_header: # (c -- C)
        # convert char to upper case
        .word _str_dup_header
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


_digit2number_header:  # (c -- n f)
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


_number_header: # (a -- n f)
         # convert string tuple (si sa sc) at a to number n.
         # It starts parsing at index si and stops at si==sc.
         # White space (chars with ascii value < 33) is considered as end-of-number.
         # f is 0 on error, else -1 on success
        .word _digit2number_header
        .cstr "number"
_number:
        # save current base
        call _base
        call _fetch
        a:t r d- r+             # (a base -- a r:base)
        # is first char minus sign (45)?
        # if yes, push minus? == 0 on rstack
        # if no,  push minus? != 0 on rstack
        call _dup               # (a -- a a)
        call _str_getc_next     # (a a -- a c)
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
        call _dup               # (a -- a a)
        # skip dollar sign
        call _str_getc_next     # (a a -- a c)
_number__2: # (a c r:base minus?)
        # now, minus '-' and/or dollar '$' are processed. Now the digit parsing starts.
        # first, push res=0 on rstack
        lit 0
        a:t r d- r+             # (a c 0 -- a c r:base minus? res)
_number_loop: # (a c r:base minus? res)
        # is end-of-string?
        call _over              # (a c -- a c a)
        call _str_eos           # (a c a -- a c eos?) # eos=0 if end of string
        rj.z _number_done       # (a c eos? -- a c r:base minus? res)
        # is c white space? if yes, stop parsing
        lit 33                  # (a c -- a c 33)
        a:lt t                  # (a c 32 -- a c f)
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
        call _dup               # (a -- a a)
        call _str_getc_next     # (a a -- a c)
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


_parse_skip_header: # (del a -- )
        # skip white space in string tuple si/sa/sc at address a
        # this increases si until char is not equal to delimiter <del>
        # or until end-of-string
        .word _number_header
        .cstr "parse-skip"
_parse_skip:
        a:t r r+        # (del a -- del a r:a)
_parse_skip_loop:
        call _str_eos   # (del a -- del f)
        rj.z _parse_skip_done # (del f -- del)
        a:r t d+        # (del r:a -- del a r:a)
        call _str_getc  # (del a -- del c r:a)
        a:sub t         # (del c -- del f r:a)
        rj.nz _parse_skip_done # (del f -- del r:a)
        a:r t d+        # (del r:a -- del a r:a)
        a:r t d+        # (del a r:a -- del a a r:a)
        call _str_next  # (del a a -- del a r:a)
        rj _parse_skip_loop
_parse_skip_done: # (del r:a)
        a:nop t d- r-   # (del r:a -- )
        a:nop t r- [ret]


_parse_header: # (del a1 -- a2)
        # Parse word delimited by del in string tuple at address a1.
        # Put parsed word to string tuple a2.
        # advance a1.si to first delimeter after word
        # note that a2 uses the same memory for every call to parse
        .word _parse_skip_header
        .cstr "parse"
_parse:
        # set a2.si = a1.si
        call _dup           # (del a1 -- del a1 a1)
        call _str_idx       # (del a1 a1 -- del a1 si)
        lit _parse_retval   # (del a1 si -- del a1 si a2)
        call _str_set_idx   # (del a1 si a2 -- del a1)
        call _dup           # (del a1 -- del a1 a1)
        call _str_eos       # (del a1 a1 -- del a1 f)
        rj.z _parse_eos     # (del a1 f -- del a1)
_parse_loop: # (del a1)
        # a2.sc ist 1 zu klein bei eos
        a:t r r+            # (del a1 -- del a1 a1)
        call _str_getc      # (del a1 -- del c a1)
        a:sub t             # (del c -- del f a1)
        rj.z _parse_delimiter # (del f -- del a1)
        a:r t d+            # (del -- del a1 a1)
        call _str_next      # (del a1 -- del a1)
        a:r t d+ r-         # (del -- del a1)
        call _dup           # (del a1 -- del a1 a1)
        call _str_eos       # (del a1 a1 -- del a1 f)
        rj.z _parse_eos     # (del a1 f -- del a1)
        rj _parse_loop
_parse_delimiter: # (del r:a1)
        a:r t d+ r-         # (del r:a1 -- del a1)
_parse_eos: # (del a1)
        call _nip           # (del a1 -- a1)
        call _dup           # (a1 -- a1 a1)
        call _str_addr      # (a1 a1 -- a1 sa)
        lit _parse_retval   # (a1 sa -- a1 sa a2)
        call _str_set_addr  # (a1 sa a2 -- a1)
        call _str_idx       # (a1 -- si1)
        lit _parse_retval   # (si1 -- si1 a2)
        call _str_set_cnt   # ( -- )
        lit _parse_retval [ret] # ( -- a2)
_parse_retval: .space 3 # this is a2


_parse_name_header: # (a1 -- a2 f)
        # skip spaces and parse word.
        # put found word into a2
        # f=0xffff if word parsed successfully
        # f=0 if parsing failed
        .word _parse_header
        .cstr "parse-name"
_parse_name:
        lit 32
        call _over          # (a1 32 -- a1 32 a1)
        call _parse_skip    # (a1 32 a1 -- a1)
        lit 32
        call _swap          # (a1 32 -- 32 a1)
        call _parse         # (32 a1 -- a2)
        call _dup           # (a2 -- a2 a2)
        call _str_eos       # (a2 a2 -- a2 f)
        a:nop t r- [ret]


_find_header: # (a -- a 0 | xt 1)
        # search for t-str (si/sa/sc) a in dictionary, starting at "latest"
        # if found, returns xt of word and flag=0
        # if not found, leaves a on stack and flag=$ffff
        .word _parse_name_header
        .cstr "find"
_find:
        call _latest        # (a -- a it)
        a:t r d- r+         # (a it -- a r:it)
_find_loop: # (a r:it)
        a:r t d+            # (a r:it -- a it r:it)
        rj.z _find_not_found # (a it -- a r:it) ; end of dict reached
        call _dup           # (a -- a a r:it)
        a:r t d+            # (a a r:it -- a a it r:it)
        call _add1          # (a a it -- a a it+1 r:it)
        lit _find_tstr      # (a a cstr -- a a cstr tstr)
        call _str_init_cstr # (a a cstr tstr -- a a)
        lit _find_tstr      # (a a -- a a tstr r:it)
        call _str_cmp       # (a a tstr -- a f r:it)
        rj.z _find_found    # (a f -- a r:it)
        a:r t d+ r-         # (a r:it -- a it)
        a:mem t             # (a it -- a next-it)
        a:t r d- r+         # (a it -- a r:it)
        rj _find_loop
_find_found: # (a r:it)
        a:r t r-            # (a r:it -- it)
        call _add1          # (it -- it+1)
        a:mem t d+          # (a cstr -- a cnt)
        lit 3
        a:add t d-          # (a cnt 3 -- a cnt+3)
        a:sr t              # (a cnt -- a cnt/2)
        a:add t d-          # (a n -- a+n)
        lit 0 [ret]         # (xt -- xt 0)
_find_not_found: # (a r:it)
        a:nop t r-          # (a r:it -- a)
        lit $ffff [ret]     # (a -- a $ffff)
_find_tstr: .space 3

dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
