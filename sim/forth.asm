.equ ADDR_UART_ST $fffe
.equ ADDR_UART_RX $ffff
.equ ADDR_UART_TX $ffff
.equ MASK_UART_TX_FULL 8
.equ MASK_UART_TX_EMPTY 4
.equ MASK_UART_RX_FULL 2
.equ MASK_UART_RX_EMPTY 1
.equ SIM_END $be00
.equ TIB_WORD_COUNT 32


lit wort1
lit ntib
call _cstrcpy_body

call _create_body

.word SIM_END

wort1: .word 5
.ascii "test "

# ----------------------------------------------------

# variables
state: .word 0          # 0: interpreting, -1: compiling
ntib: .word 0           # number of chars in tib
tib: .space TIB_WORD_COUNT
.word 13

to_in: .word 0          # current char idx in tib
base: .word 10
latest: .word _find     # last word in dictionary
dp: .word dp_init      # first free cell after dict

cstrscratch: .space 33

# dictionary

_here:      # (-- n)
            # here returns the address of the first free cell in the data space
            .cstr "here"
            .word 0
_here_body:
            lit dp
            a:mem t r- [ret]


_here_add:  # (n -- )
            # helper function, not a word
            call _here_body     # (n -- n a)
            a:add t d-          # (n a -- n+a)
            lit dp              # (a -- a dp)
            call _store_body    # (a dp -- )
            a:nop t r- [ret]


_comma:     # (w --)
            # comma puts a word into the cell pointed to by here
            # and increments the data space pointer (value returned by here)
            .cstr ","
            .word _here
_comma_body:
            call _here_body     # (w -- w a)
            call _store_body    # (w a -- )
            lit 1               # ( -- 1)
            call _here_add      # (1 --)
            a:nop t r- [ret]


_create:    # ( "word-name" -- ) ; Parsing word, takes word from input buffer
            # and creates new dictionary entry
            .cstr "create"
            .word _comma
_create_body:
            # get word name from input buffer
            lit 32 # space          # ( -- del)
            call _word_body         # (del -- )
            lit cstrscratch         # ( -- ca)
            call _dup_body          # (ca -- ca ca)
            rj.z _create_error      # (ca ca -- ca) ; if not word found, jump to error
            # word found, put into dictionary
            a:mem r r+              # (ca -- ca r:cnt)
_create_cp_loop:
            a:r t d+ r-             # (ca r:cnt -- ca cnt)
            call _dup_body          # (ca cnt -- ca cnt cnt)
            rj.z _create_cp_done    # (ca cnt cnt -- ca cnt)
            lit 1                   # (ca cnt -- ca cnt 1)
            a:sub r d- r+           # (ca cnt 1 -- ca cnt r:cnt+1)
            call _drop_body         # (ca cnt r:cnt -- ca r:cnt)
            a:mem t d+              # (ca r:cnt -- ca w r:cnt)
            call _comma_body        # (ca w r:cnt -- ca r:cnt)
            lit 1                   # (ca r:cnt -- ca 1 r:cnt)
            a:add t d-              # (ca 1 r:cnt -- ca+1 r:cnt)
            rj _create_cp_loop
_create_cp_done:
_create_error: #(ca)
            a:nop t d- r- [ret]


_allot:     # (n -- )
            .cstr "allot"
            .word _create
_allot_body:
            call _here_add      # (n -- )
            a:nop t r- [ret]


_add1:      # (n -- n+1)
            .cstr "+1"
            .word _allot
_add1_body:
            lit 1            # (n -- n 1)
            a:add t d- r- [ret] # (n 1 -- n+1)


_plus_store: # (n addr --)
             # add n to variable at addr
            .cstr "+!"
            .word _add1
_plus_store_body:
            a:mem r r+          # (n a -- n a r:w) ; fetch into r
            call _swap_body     # (n a r:w -- a n r:w)
            a:r t d+ r-         # (a n r:w -- a n w)
            a:add t d-          # (a n w -- a n+w)
            call _swap_body     # (a n+w -- n+w a)
            a:n mem d-          # (n+w a -- n+w)
            a:nop t d- r- [ret] # (n+w -- )


_latest:    # ( -- addr)
            .cstr "latest"
            .word _plus_store
_latest_body:
            lit latest
            a:mem t r- [ret]


_tib:       # ( -- addr)
            # input area as ascii string
            .cstr "tib"
            .word _latest
_tib_body:
            lit tib [ret]


_ntib:      # ( -- n)
            # number of chars in input area
            .cstr "#tib"
            .word _tib
_ntib_body:
            lit ntib
            a:mem t r- [ret]


_to_in:     # ( -- n )
            # return addr of index of current char in input buffer
            .cstr ">in"
            .word _ntib
_to_in_body:
            lit to_in [ret]


_tibcfetch: # ( -- char)
            # fetch char pointed to by >in from tib
            .cstr "tibc@"
            .word _to_in
_tibcfetch_body:
            call _to_in_body
            call _fetch_body
            call _tib_body
            call _strcfetch_body
            a:nop t r- [ret]


_tibcstore: # (c --)
            # store char in tib at idx >in
            .cstr "tibc!"
            .word _tibcfetch
_tibcstore_body:
            call _to_in_body # (c -- c a)
            call _fetch_body # (c a -- c idx)
            call _tib_body   # (c idx -- c idx a)
            call _strcstore_body # (c idx a -- )
            a:nop t r- [ret]


_base:      # ( -- addr)
            .cstr "base"
            .word _tibcstore
_base_body:
            lit base [ret]


_fetch:     # (addr -- n)
            .cstr "@"
            .word _base
_fetch_body:
            a:mem t r- [ret]


_store:     # (d addr -- )
            .cstr "!"
            .word _fetch
_store_body:
            a:n mem d-
            a:nop r d- r- [ret]


_drop:      # ( n -- )
            .cstr "drop"
            .word _store
_drop_body:
            a:nop t d- r- [ret]


_2drop:     # ( n n -- )
            .cstr "2drop"
            .word _drop
_2drop_body:
            a:nop t d-
            a:nop t d- r- [ret]


_dup:       # (a -- a a)
            .cstr "dup"
            .word _2drop
_dup_body:
            a:t t d+ r- [ret]


_2dup:      # (a b -- a b a b)
            .cstr "2dup"
            .word _dup
_2dup_body:
            a:n t d+
            a:n t d+ r- [ret]


_swap:      # (a b -- b a)
            .cstr "swap"
            .word _2dup
_swap_body:
            a:t r d- r+      # (a b -- a r:b)
            a:t t d+         # (a r:b -- a a r:b)
            a:r t d- r-      # (a a r:b -- b a)
            a:nop t d+ r- [ret] # (b a -- b a)


_over:      # (a b -- a b a)
            .cstr "over"
            .word _swap
_over_body:
            a:n t d+ r- [ret]


_rot:       # (a b c -- b c a)
            .cstr "rot"
            .word _over
_rot_body:  # todo


_nip:       # (a b -- b)
            .cstr "nip"
            .word _rot
_nip_body:  
            a:t t d- r- [ret]


_tuck:      # (a b -- b a b)
            .cstr "tuck"
            .word _nip
_tuck_body: 
            call _swap_body # ( a b -- b a)
            call _over_body # ( b a -- b a b)
            a:nop t r- [ret]


_min:       # (n1 n2 -- min)
            .cstr "min"
            .word _tuck
_min_body:
            a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.nz _min__1   # (n1 n2 lt -- n1 n2)
            call _nip_body  # (n1 n2 -- n2)
            rj _min__2
_min__1:    call _drop_body # (n1 n2 -- n1)
_min__2:    a:nop t r- [ret]


_max:       # (n1 n2 -- min)
            .cstr "max"
            .word _min
_max_body:
            a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.z _max__1    # (n1 n2 lt -- n1 n2)
            call _nip_body  # (n1 n2 -- n2)
            rj _max__2
_max__1:    call _drop_body # (n1 n2 -- n1)
_max__2:    a:nop t r- [ret]


_to_r:      # (n -- r:n)
            .cstr ">r"
            .word _max
_to_r_body: a:r t d+ r-      # (n r:a -- n a)
            call _swap_body  # (n a -- a n)
            a:t r d- r+      # (a n -- a r:n)
            a:t pc d-        # (a r:n -- r:n)


_r_from:    # (r:n -- n)
            .cstr "r>"
            .word _to_r
_r_from_body:
            a:r t d+ r-       # (r:n a -- a r:n) ; rpop return address
            a:r t d+ r-       # (a r:n -- a n)   ; pop value to retrieve
            call _swap_body   # (a n -- n a)
            a:t pc d-         # (n a -- n)


_wait_uart_tx_can_send: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_TX_FULL
            a:and t d-
            rj.nz _wait_uart_tx_can_send
            a:nop t r- [ret]


_emit:      # (c --)
            .cstr "emit"
            .word _r_from
_emit_body: call _wait_uart_tx_can_send
            lit ADDR_UART_TX
            call _store_body
            a:nop t r- [ret]


_wait_uart_rx_has_data: # ( -- )
            lit ADDR_UART_ST
            a:mem t
            lit MASK_UART_RX_EMPTY
            a:and t d-
            rj.nz _wait_uart_rx_has_data
            a:nop t r- [ret]


_key:       # ( -- key)
            .cstr "key"
            .word _emit
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
            .cstr "sc@" # "string char fetch"
            .word _key
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
            .cstr "csc@" # "counted string char fetch"
            .word _strcfetch
_cscfetch_body:
            # add 1 because counted string
            call _add1_body       # (ci ca -- ci ca+1)
            call _strcfetch_body  # (ci ca+1 -- c)
            a:nop t r- [ret]


_strcstore: # (char char-idx str-addr -- )
            .cstr "sc!"
            .word _cscfetch
_strcstore_body:
            call _over_body         # (c ci sa         -- c ci sa ci)
            call _charidxwordaddr   # (c ci sa ci      -- c ci wa)
            a:t r r+                # (c ci wa         -- c ci wa    R:wa)
            call _fetch_body        # (c ci wa    R:wa -- c ci w     R:wa)
            # for better readability, don't mention the R stack until it is used again
            call _swap_body         # (c ci w      -- c w ci)
            lit 1                   # (c w ci      -- c w ci 1)
            a:and t d-              # (c w ci 1    -- c w ci&1)
            # if t=0, put char in upper byte of w
            # if t=1, put char in lower byte of w
            rj.z _strcs1            # (c w ci&1  -- c w)
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


_cstr_append: # ( char cstr-addr --)
            .cstr "cstr-append"
            .word _strcstore
_cstr_append_body:
            call _dup_body        # (c sa -- c sa sa)
            a:t r r+              # (c sa sa -- c sa sa r:sa)
            # get cstring count
            call _fetch_body      # (c sa sa -- c sa count r:sa)
            call _swap_body       # (c sa count r:sa -- c count sa r:sa)
            call _add1_body       # (c count sa r:sa -- c count sa r:sa)
            call _strcstore_body  # (c count sa r:sa -- r:sa)
            lit 1                 # (r:sa -- 1 r:sa)
            a:r t d+ r-           # (1 r:sa -- 1 sa)
            call _plus_store_body # (1 sa --)
            a:nop t r- [ret]


_cstrpop:  # (c-addr --)
            # delete last char of c-str
            .cstr "cstr-pop"
            .word _cstr_append
_cstr_pop_body:
            call _dup_body      # (ca -- ca ca)
            call _fetch_body    # (ca ca -- ca w)
            call _dup_body      # (ca w -- ca w w)
            # has c-str already zero length?
            rj.z _cstr_pop__1   # (ca w w -- ca w)
            lit 1               # (ca w -- ca w 1)
            a:sub t d-          # (ca w 1 -- ca w-1)
            call _swap_body     # (ca w -- w ca)
            call _store_body    # (w ca --)
            a:nop t r- [ret]    # (--)
_cstr_pop__1:
            call _drop_body     # (ca w -- ca)
            a:nop t d- r- [ret] # (ca -- )


_tib_eob:   # (-- flag)
            # if >in reached end of buffer return 0
            call _to_in_body
            call _fetch_body
            #lit TIB_BYTE_SIZE
            lit ntib
            call _fetch_body
            a:sub t d- r- [ret]


_to_in_plus1: # (--)
            # inc >in
            call _to_in_body
            call _fetch_body
            call _add1_body
            call _to_in_body
            call _store_body
            a:nop t r- [ret]


_move:      # ( a-from a-to count -- )
            # copy count words from a-from to a-to
            .cstr "move"
            .word _cstrpop
_move_body: 
            a:t r d- r+         # (a1 a2 cnt -- a1 a2 r:cnt)
            call _over_body     # (a1 a2 -- a1 a2 a1)
            call _fetch_body    # (a1 a2 a1 -- a1 a2 w)
            call _over_body     # (a1 a2 w -- a1 a2 w a2)
            call _store_body    # (a1 a2 w a2 -- a1 a2)
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
            call _dup_body      # (a1 a2 cnt -- a1 a2 cnt cnt)
            rj.nz _move_body    # (a1 a2 cnt cnt -- a1 a2 cnt)
_move_done:
            call _2drop_body
            a:nop t d- r- [ret]


_cstrcpy:   # ( ca1 ca2 -- )
            # copy c-str at ca1 to ca2
            .cstr "cstrcpy"
            .word _move
_cstrcpy_body:
            call _over_body      # (ca1 ca2 -- ca1 ca2 ca1)
            call _fetch_body     # (ca1 ca2 ca1 -- ca1 ca2 char-cnt)
            lit 3
            a:add t d-          # (ca1 ca2 char-cnt+3)
            a:sr t              # (ca1 ca2 word-cnt)
            call _move_body     # (ca1 ca2 cnt -- )
            a:nop t r- [ret]


_word:      # (delimiter cs-addr -- )
            # skip delimiters
            # copy word to cstrscratch
            .cstr "word"
            .word _cstrcpy
_word_body:
            lit 0 # (del -- del c) ; helper
_wb_del_loop:
            call _drop_body         # (del c -- del) ; drop c from branching to _wb_del_loop
            # reached eob?
            call _tib_eob           # (del -- del f)
            rj.z _word_eob1         # (del f -- del)

            call _tibcfetch_body    # (del -- del c)
            call _to_in_plus1       # (del c -- del c)
            call _2dup_body         # (del c -- del c del c)
            # is char == delimiter?
            a:sub t d-              # (del c del c -- del c f)
            rj.z _wb_del_loop       # (del c f -- del c) ; note: c needs to be dropped if branch is taken

            # now c is first non-delimiter char
            # put this into scratch area

            # initialize char count to 0
            lit 0
            lit cstrscratch
            call _store_body

_wordloop:  # (del c)

            # reached eob?
            # note: this has a problem. c is a valid char here which needs to be appended,
            # but >in is already incremented to point to the next char.
            # c needs to be written before checking for tib_eob
            call _tib_eob   # (del c -- del c f)
            rj.z _word_eob2 # (del c f -- del c) # this triggers one char too early

            lit cstrscratch # (del c -- del c a)
            call _cstr_append_body # (del c a -- del)
            
            # fetch next char from tib
            call _tibcfetch_body # (del -- del c)  # char is fetched
            call _to_in_plus1    # (del c -- del c) # >in is incremented
            call _2dup_body      # (del c -- del c del c)
            # is char == delimiter?
            a:sub t d-           # (del c del c -- del c f)
            rj.nz _wordloop      # (del c f -- del c)

            call _drop_body      # (del c -- del)
            call _drop_body      # (del -- )
            lit cstrscratch [ret] # ( -- a)

_word_eob2: call _drop_body
_word_eob1: call _drop_body
            lit 0 [ret] # end of buffer, return 0


_cstrcmp:   # (a1 a2 -- f)
            .cstr "cstrcmp"
            .word _word
_cstrcmp_body:
            call _2dup_body     # (a1 a2 -- a1 a2 a1 a2)
            call _fetch_body    # (a1 a2 -- a1 a2 a1 cnt2)
            call _swap_body     # (a1 a2 -- a1 a2 cnt2 a1)
            call _fetch_body    # (a1 a2 -- a1 a2 cnt2 cnt1)
            a:sub t             # (a1 a2 cnt2 cnt1 -- a1 a2 cnt2 f)
            rj.nz _cstrcmp__ne4 # (a1 a2 cnt2 f -- a1 a2 cnt2)
            a:t r d- r+         # (a1 a2 cnt -- a1 a2 r:cnt)  ; move cnt to rstack
            # counts are equal
            # increment addresses
            lit 1               # (a1 a2 r:cnt -- a1 a2 1 r:cnt)
            a:add t d-          # (a1 a2 1 r:cnt -- a1 a2+1 r:cnt)
            call _swap_body     # (a1 a2 r:cnt -- a2 a1 r:cnt)
            lit 1               # (a2 a1 r:cnt -- a2 a1 1 r:cnt)
            a:add t d-          # (a2 a1 1 r:cnt -- a2 a1+1 r:cnt)
_cstrcmp__1:
            # (a1 a2 r:cnt)
            a:r t d+ r-         # (a1 a2 r:cnt -- a1 a2 cnt)

            # cnt--
            lit 1               # (a1 a2 cnt -- a1 a2 cnt 1)
            a:sub t d-          # (a1 a2 cnt -- a1 a2 cnt-1)
            # if cnt < 0 then equal
            call _dup_body      # (a1 a2 cnt -- a1 a2 cnt cnt)
            rj.n _cstrcmp__eq3  # (a1 a2 cnt cnt -- a1 a2 cnt)
            a:t r d- r+         # (a1 a2 cnt -- a1 a2 r:cnt)  ; move cnt to rstack

            # fetch chars
            call _2dup_body      # (a1 a2 r:cnt -- a1 a2 a1 a2 r:cnt)
            a:r t d+             # (a1 a2 a1 a2 r:cnt -- a1 a2 a1 a2 cnt r:cnt)
            call _swap_body      # (a1 a2 a1 a2 cnt r:cnt -- a1 a2 a1 cnt a2 r:cnt)
            call _strcfetch_body # (a1 a2 a1 a2 cnt r:cnt -- a1 a2 a1 c2)
            a:r t d+             # (a1 a2 a1 c2 r:cnt -- a1 a2 a1 c2 cnt r:cnt)
            call _swap_body      # (a1 a2 a1 c2 cnt r:cnt -- a1 a2 a1 cnt c2 r:cnt)
            a:t r d- r+          # (a1 a2 a1 cnt c2 r:cnt -- a1 a2 a1 cnt r:cnt c2)
            call _swap_body      # (a1 a2 a1 cnt r:cnt c2 -- a1 a2 cnt a1 r:cnt c2)
            call _strcfetch_body # (a1 a2 a1 cnt r:cnt c2 -- a1 a2 c1 r:cnt c2)
            a:r t d+ r-          # (a1 a2 c1 r:cnt c2 -- a1 a2 c1 c2 r:cnt)
            a:sub t d-           # (a1 a2 c1 c2 r:cnt -- a1 a2 f r:cnt)
            rj.nz _cstrcmp__ne2  # (a1 a2 f r:cnt -- a1 a2 r:cnt)
            rj _cstrcmp__1       # (a1 a2 r:cnt -- a1 a2 r:cnt)


            # exit for not equal
_cstrcmp__ne4: a:t r r+          # push to rstack to be dropped later
_cstrcmp__ne3: a:nop t d-        # (n n n -- n n)
_cstrcmp__ne2: a:nop t d-        # (n n -- n)
_cstrcmp__ne1: a:nop t d- r-     # (n --)
            lit 0 [ret]

            # exit for equal words
_cstrcmp__eq3: a:nop t d-        # (n n n -- n n)
_cstrcmp__eq2: a:nop t d-        # (n n -- n)
_cstrcmp__eq1: a:nop t d-        # (n --)
            lit $ffff [ret]


_find: # ( c-addr -- c-addr 0 | xt 1)
        .cstr "find"
        .word _cstrcmp
_find_body:
        call _latest_body   # (wa -- wa it)
_find__1:
        call _dup_body      # (wa it -- wa it it)
        rj.z _find_not_found # (wa it it -- wa it)
        call _2dup_body     # (wa it -- wa it wa it)
        call _cstrcmp_body  # (wa it wa it -- wa it f)
        rj.nz _find_found   # (wa it f -- wa it)
        a:mem t d+          # (wa it -- wa it cnt)
        call _add1_body     # (wa it cnt -- wa it cnt+1)
        a:sr t              # (wa it cnt+1 -- wa it n)
        a:add t d-          # (wa it n -- wa a)
        call _add1_body     # (wa a -- wa a+1)
        a:mem t             # (wa a -- wa it)
        rj _find__1         # (wa it -- wa it)
_find_found:
        call _nip_body      # (wa it -- it)
        lit 1 [ret]         # (it -- it 1)
_find_not_found:
        call _drop_body     # (wa it -- wa)
        lit 0 [ret]         # (wa -- wa 0)


_accept: # (c-addr u1 -- u2)
         # receive string until CR, put string as c-string at c-addr
         # u1 is max char count that should be received
         # u2 is number of chars received, excluding CR
        .cstr "accept"
        .word _find
_accept_body:
        call _over_body         # (ca u1 -- ca u1 ca)
        lit 0                   # (ca u1 ca -- ca u1 ca 0)
        # clear string at c-addr (ca)
        call _swap_body         # (ca u1 ca 0 -- ca u1 0 ca)
        call _store_body        # (ca u1 0 ca -- ca u1)
        a:t r d- r+             # (ca u1 -- ca r:u1)
_accept_loop:
        call _key_body          # (ca r:u1 -- ca key r:u1)
        # is key CR?
        lit 13 # CR             # (ca key r:u1 -- ca key 13 r:u1)
        a:sub t                 # (ca key 13 r:u1 -- ca key f r:u1)
        rj.z _accept_enter      # (ca key f r:u1 -- ca key r:u1)

        # is key backspace?
        lit 27 # BSP            # (ca key r:u1 -- ca key 27 r:u1)
        a:sub t                 # (ca key 13 r:u1 -- ca key f r:u1)
        rj.nz _accept__1        # (ca key f r:u1 -- ca key r:u1)
        call _drop_body         # (ca key r:u1 -- ca r:u1)
        call _dup_body          # (ca r:u1 -- ca ca r:u1)
        call _cstr_pop_body     # (ca ca r:u1 -- ca r:u1)
        rj _accept_loop

_accept__1:                     # (ca key r:u1)
        a:r t d+ r-             # (ca key r:u1 -- ca key u1)
        # is space left?
        call _dup_body          # (ca key u1 -- ca key u1 u1)
        rj.z _accept_full       # (ca key u1 u1 -- ca key u1)
        # decrement free space counter u1
        lit 1                   # (ca key u1 -- ca key u1 1)
        a:sub t d-              # (ca key u1 1 -- ca key u1-1)
        # append char to c-str
        a:t r d- r+             # (ca key u1 -- ca key r:u1)
        call _over_body         # (ca key r:u1 -- ca key ca r:u1)
        call _cstr_append_body  # (ca key ca r:u1 -- ca r:u1)
        rj _accept_loop

_accept_enter: #(ca key r:u1)
        a:r t r-                # (ca key r:u1 -- ca u1)
        call _drop_body         # (ca u1 -- ca)
        a:mem t r- [ret]        # (ca -- u2)
_accept_full: #(ca key u1)
        call _2drop_body        # (ca key u1 -- ca)
        a:mem t r- [ret]        # (ca -- u2)




dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
