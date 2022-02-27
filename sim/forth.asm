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
call _find_body


.word SIM_END

wort1: .cstr "gibtsnicht"

# ----------------------------------------------------

# variables
state: .word 0          # 0: interpreting, -1: compiling
ntib: .word 0           # number of chars in tib
tib: .space TIB_WORD_COUNT

to_in: .word 0          # current char idx in tib
base: .word 10
latest: .word _number   # last word in dictionary
dp: .word dp_init       # first free cell after dict

cstrscratch: .space 33

str1: .space 2 # for idx/addr pair of a string
str2: .space 2 # for idx/addr pair of a string

# dictionary

_here:      # (-- n)
            # here returns the address of the first free cell in the data space
            .word 0
            .cstr "here"
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
            .word _here
            .cstr ","
_comma_body:
            call _here_body     # (w -- w a)
            call _store_body    # (w a -- )
            lit 1               # ( -- 1)
            call _here_add      # (1 --)
            a:nop t r- [ret]


_create:    # ( "word-name" -- ) ; Parsing word, takes word from input buffer
            # and creates new dictionary entry
            .word _comma
            .cstr "create"
_create_body:
            # first, save "here". This the start address of the new word,
            # will be written to "latest" later on.
            call _here_body         # ( -- nwa) ; nwa: new-word-address
            # get word name from input buffer
            call _parse_name_body   # (nwa -- nwa ci cl) ; char-idx, char-len
            a:t r r+                # (nwa cp cl -- nwa cp cl r:cl)
            rj.z _create_error_no_name # (nwa cp cl -- nwa cp r:cl)

            # set count of c-str of word name
            a:r t d+                # (nwa cp r:cl -- nwa cp cl r:cl)
            call _comma_body        # (nwa cp cl r:cl -- nwa cp r:cl)

            # initialize idx/pair of dictionary entry for writing
            lit 0 # idx
            call _here_body # addr
            call _str_init_body
            lit str2

            # reserve space for string, add 1 to char-len for rounding up,
            # then divide by two for word-count of string
            a:r t d+                # (nwa cp r:cl -- nwa cp cl r:cl)
            lit 1
            a:add t d-              # (nwa cp cl 1 -- nwa cp cl+1)
            a:sr t                  # (nwa cp cl -- nwa cp wl)
            call _allot_body        # (nwa cp wl -- nwa cp)

            # initialize idx/pair of tib for reading
            lit tib                 # (nwa cp -- nwa cp tib)
            lit str1                # (nwa cp tib -- nwa cp tib a)
            call _str_init_body     # (nwa cp tib a -- nwa)

_create_cp_loop: # (nwa r:cl)
            # get char from str1
            lit str1                 # (nwa  -- nwa a)
            call _str_read_next_body # (nwa a -- nwa c)

            # store char to str2
            lit str2                # (nwa c -- nwa c a)
            call _str_append_body   # (nwa c a -- nwa)

            # decrement counter cl on rstack
            a:r t d+ r-             # (nwa r:cl -- nwa cl)
            lit 1
            a:sub t d-              # (nwa cl 1 -- nwa cl-1)
            a:t r r+                # (nwa cl -- nwa cl r:cl)
            rj.nz _create_cp_loop   # (nwa cl -- nwa)
            a:nop t r-              # (nwa r:cl -- nwa)

            # now add pointer to previous word
            call _latest_body       # (nwa -- nwa latest)
            call _comma_body        # (nwa latest -- nwa)

            lit latest              # (nwa -- nwa latest-addr)
            call _store_body        # (nwa latest-addr -- )
            a:nop t r- [ret]

_create_error_no_name: # (nwa cp r:cl)
            a:nop t d- r-
            a:nop t d- r- [ret]


_allot:     # (n -- )
            .word _create
            .cstr "allot"
_allot_body:
            call _here_add      # (n -- )
            a:nop t r- [ret]


_add1:      # (n -- n+1)
            .word _allot
            .cstr "+1"
_add1_body:
            lit 1            # (n -- n 1)
            a:add t d- r- [ret] # (n 1 -- n+1)


_plus_store: # (n addr --)
             # add n to variable at addr
            .word _add1
            .cstr "+!"
_plus_store_body:
            a:mem r r+          # (n a -- n a r:w) ; fetch into r
            call _swap_body     # (n a r:w -- a n r:w)
            a:r t d+ r-         # (a n r:w -- a n w)
            a:add t d-          # (a n w -- a n+w)
            call _swap_body     # (a n+w -- n+w a)
            a:n mem d-          # (n+w a -- n+w)
            a:nop t d- r- [ret] # (n+w -- )


_latest:    # ( -- addr)
            .word _plus_store
            .cstr "latest"
_latest_body:
            lit latest
            a:mem t r- [ret]


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


_tibcstore: # (c --)
            # store char in tib at idx >in
            .word _tibcfetch
            .cstr "tibc!"
_tibcstore_body:
            call _to_in_body # (c -- c a)
            call _fetch_body # (c a -- c idx)
            call _tib_body   # (c idx -- c idx a)
            call _strcstore_body # (c idx a -- )
            a:nop t r- [ret]


_base:      # ( -- addr)
            .word _tibcstore
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


_2drop:     # ( n n -- )
            .word _drop
            .cstr "2drop"
_2drop_body:
            a:nop t d-
            a:nop t d- r- [ret]


_dup:       # (a -- a a)
            .word _2drop
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
            .word _over
            .cstr "rot"
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


_min:       # (n1 n2 -- min)
            .word _tuck
            .cstr "min"
_min_body:
            a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.nz _min__1   # (n1 n2 lt -- n1 n2)
            call _nip_body  # (n1 n2 -- n2)
            rj _min__2
_min__1:    call _drop_body # (n1 n2 -- n1)
_min__2:    a:nop t r- [ret]


_max:       # (n1 n2 -- min)
            .word _min
            .cstr "max"
_max_body:
            a:lts t d+      # (n1 n2 -- n1 n2 lt)
            rj.z _max__1    # (n1 n2 lt -- n1 n2)
            call _nip_body  # (n1 n2 -- n2)
            rj _max__2
_max__1:    call _drop_body # (n1 n2 -- n1)
_max__2:    a:nop t r- [ret]


_to_r:      # (n -- r:n)
            .word _max
            .cstr ">r"
_to_r_body: a:r t d+ r-      # (n r:a -- n a)
            call _swap_body  # (n a -- a n)
            a:t r d- r+      # (a n -- a r:n)
            a:t pc d-        # (a r:n -- r:n)


_r_from:    # (r:n -- n)
            .word _to_r
            .cstr "r>"
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
            rj.nz _wait_uart_rx_has_data
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
            call _add1_body       # (ci ca -- ci ca+1)
            call _strcfetch_body  # (ci ca+1 -- c)
            a:nop t r- [ret]


_strcstore: # (char char-idx str-addr -- )
            .word _cscfetch
            .cstr "sc!"
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
            .word _strcstore
            .cstr "cstr-append"
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
            .word _cstr_append
            .cstr "cstr-pop"
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
            .word _cstrpop
            .cstr "move"
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
            .word _move
            .cstr "cstrcpy"
_cstrcpy_body:
            call _over_body      # (ca1 ca2 -- ca1 ca2 ca1)
            call _fetch_body     # (ca1 ca2 ca1 -- ca1 ca2 char-cnt)
            lit 3
            a:add t d-          # (ca1 ca2 char-cnt+3)
            a:sr t              # (ca1 ca2 word-cnt)
            call _move_body     # (ca1 ca2 cnt -- )
            a:nop t r- [ret]


_parse_skip: # (del -- )
             # advance >in as long as tib[>in] is a delimiter
            .word _cstrcpy
            .cstr "parse-skip"
_parse_skip_body:
            call _tib_eob
            rj.z _parse_skip_exit
            call _tibcfetch_body    # (del -- del c)
            call _over_body         # (del c -- del c del)
            # is char == delimiter?
            a:sub t d-              # (del c del -- del f)
            rj.nz _parse_skip_exit  # (del f -- del)
            call _to_in_plus1
            rj _parse_skip_body
_parse_skip_exit:
            a:nop t d- r- [ret]


_parse:     # ( del "ccc<xdel>" – idx clen)
            # Parse ccc, delimited by del, in the parse area.
            # idx is start char pos in tib, clen is char count of word.
            # If the parse area was empty, clen is 0.
            .word _parse_skip
            .cstr "parse"
_parse_body:
            call _tib_eob           # (del -- del f)
            rj.nz _parse__1         # (del f -- del)
            # tib is empty, return 0 0
            call _drop_body         # (del -- )
            lit 0                   # ( -- 0)
            lit 0 [ret]             # ( -- 0 0)
_parse__1:  call _to_in_body        # (del -- del a)
            call _fetch_body        # (del -- del ci) ; ci: start char idx in tib
            a:t r d- r+             # (del ci -- del r:ci)
_parse_loop:
            call _tibcfetch_body    # (del -- del c)
            call _over_body         # (del c -- del c del)
            a:sub t d-              # (del c del -- del f)
            rj.z _parse_end         # (del f -- del)
            call _to_in_plus1
            call _tib_eob           # (del -- del f) ; f=0 if eob
            rj.nz _parse_loop       # (del f -- del)
_parse_end: # (del r:cnt)
            call _drop_body         # (del -- )
            a:r t d+                # (r:ci -- ci r:ci)
            call _to_in_body        # (ci -- ci a)
            call _fetch_body        # (ci a -- ci >in)
            a:r t d+ r-             # (ci >in r:ci -- ci >in ci)
            a:sub t d- r- [ret]     # (ci >in ci -- ci u)


_parse_name: #("name" – pos len) gforth “parse-name”
            # Get the next word from the input buffer
            # return char position (pos) and count (len) in TIB buffer
            .word _parse
            .cstr "parse-name"
_parse_name_body:
            lit 32 # delimiter      # ( -- del)
            call _parse_skip_body   # (del -- )
            lit 32 # delimiter      # ( -- del)
            call _parse_body        # (del -- c-addr u)
            a:nop t r- [ret]


_cstrcmp:   # (a1 a2 -- f)
            .word _parse_name
            .cstr "cstrcmp"
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
        # search for c-str at address c-addr in dictionary, starting at "latest"
        # if successful, returns xt of word (address of *_body) and flag=1
        # if not found, returns leaves c-addr on stack and flag=0
        .word _cstrcmp
        .cstr "find"
_find_body:
        call _latest_body   # (wa -- wa it)
        a:t r r+            # (wa it -- wa it r:it)
_find__1: # (wa it r:it)
        call _dup_body      # (wa it -- wa it it)
        rj.z _find_not_found # (wa it it -- wa it)
        call _add1_body     # (wa it -- wa it+1)
        call _2dup_body     # (wa it -- wa it wa it)
        call _cstrcmp_body  # (wa it wa it -- wa it f)
        call _nip_body      # (wa it f -- wa f)
        rj.nz _find_found   # (wa f -- wa r:it)
        a:r t d+ r-         # (wa r:it -- wa it)
        a:mem t             # (wa it -- wa next-it)
        a:t r r+            # (wa it -- wa it r:it)
        rj _find__1         # (wa it -- wa it r:it)
_find_found: # (wa r:it)
        # word found
        a:r t r-            # (wa r:it -- it)
        call _add1_body     # (it -- it+1)
        a:mem t d+          # (it -- it cnt)
        lit 3
        a:add t d-
        a:sr t              # (it cnt -- it n)
        a:add t d-          # (it n -- xt)
        lit 1 [ret]         # (xt -- xt 1)
_find_not_found: # (wa it r:it)
        a:nop t d- r-       # (wa it r:it -- wa)
        lit 0 [ret]         # (wa -- wa 0)


_accept: # (c-addr u1 -- u2)
         # receive string until CR, put string as c-string at c-addr
         # u1 is max char count that should be received
         # u2 is number of chars received, excluding CR
        .word _find
        .cstr "accept"
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


_str_get: # (a -- idx addr)
        # get idx/addr
        # a: address of idx/addr pair
        .word _accept
        .cstr "str-get"
_str_get_body:
        call _dup_body      # (a -- a a)
        call _fetch_body    # (a a -- a idx)
        call _swap_body     # (a idx -- idx a)
        lit 1
        a:add t d-          # (idx a 1 -- idx a+1)
        call _fetch_body    # (idx a -- idx addr)
        a:nop t r- [ret]


_str_init: # (idx addr a -- )
        # initialize idx/addr pair at a
        # a[0] = idx (char-idx)
        # a[1] = addr (addr of str)
        .word _str_get
        .cstr "str-init"
_str_init_body:
        a:t r r+            # (idx addr a -- idx addr a r:a)
        lit 1
        a:add t d-          # (idx addr a 1 -- idx addr a+1)
        call _store_body    # (idx addr a+1 -- idx r:a)
        a:r t d+ r-         # (idx r:a -- idx a)
        call _store_body
        a:nop t r- [ret]


_str_advance: # (a --)
        .word _str_init
        .cstr "str-advance"
_str_advance_body:
        call _dup_body      # (a -- a a)
        call _fetch_body    # (a a -- a w)
        lit 1               # (a w -- a w 1)
        a:add t d-          # (a w 1 -- a w+1)
        call _swap_body     # (a w -- w a)
        call _store_body    # (w a -- )
        a:nop t r- [ret]


_str_append: # (c a -- )
        # append char c to string defined by idx/addr pair at address a
        .word _str_advance
        .cstr "str-append"
_str_append_body:
        a:t r r+               # (c a -- c a r:a)
        call _str_get_body     # (c a -- c ci sa)
        call _strcstore_body   # (c ci sa -- )
        a:r t d+ r-            # (r:a -- a)
        call _str_advance_body # (a --)
        a:nop t r- [ret]


_str_read_next: # (a -- c)
        # read char from str (a is address of idx/addr pair)
        # and increment idx
        .word _str_append
        .cstr "str-read-next"
_str_read_next_body:
        a:t r r+               # (a -- a r:a)
        call _str_get_body     # (a -- ci sa)
        call _strcfetch_body   # (ci sa -- c)
        a:r t d+ r-            # (c -- c a)
        call _str_advance_body # (c a -- c)
        a:nop t r- [ret]


_str_to_cstr: # (sa len csa -- )
            # create counted string with len from a idx/addr pair string
            # sa is address of idx/addr pair
            # csa is address of new c-str
            .word _str_read_next
            .cstr "str>cstr"
_str_to_cstr_body:
            # first: initialize c-str count to zero
            call _dup_body      # (sa len csa -- sa len csa csa)
            lit 0               # (sa len csa csa-- sa len csa csa 0)
            call _swap_body     # (sa len csa csa 0 -- sa len csa 0 csa)
            call _store_body    # (sa len csa 0 csa -- sa len csa)
            a:t r d- r+         # (sa len csa -- sa len r:csa)
_str_to_cstr_loop: # (sa len r:csa)
            # is len==0?
            call _dup_body      # (sa len -- sa len len)
            rj.z _str_to_cstr_done # (sa len len -- sa len)
            call _swap_body     # (sa len -- len sa)
            call _dup_body      # (len sa -- len sa sa)
            call _str_read_next_body # (len sa sa -- len sa c)
            a:r t d+            # (len sa c r:csa -- len sa c csa r:csa)
            call _cstr_append_body # (len sa c csa -- len sa r:csa)
            call _swap_body     # (len sa -- sa len r:csa)
            lit 1
            a:sub t d-          # (sa len 1 -- sa len-1 r:csa)
            rj _str_to_cstr_loop
_str_to_cstr_done: # (sa len r:csa)
            a:nop t d- r-       # (sa len r:csa -- sa)
            a:nop t d- r- [ret] # (sa -- )


_upchar: # (c -- C)
        # convert char to upper case
        .word _str_to_cstr
        .cstr "upchar"
_upchar_body:
        call _dup_body  # (c -- c c)
        lit 32          # ( c c -- c c 32)
        a:sub t d-      # ( c c 32 -- c c-32)
        call _dup_body  # ( c C -- c C C)
        lit 65 # 'A'    # ( c C C -- c C C 65)
        a:lt t d-       # ( c C C 65 -- c C f)
        rj.nz _upchar_1 # ( c C f -- c C)
        call _dup_body  # ( c C -- c C C)
        lit 91 # 90='Z' # ( c C C -- c C C 91)
        a:lt t d-       # ( c C C 91 -- c C f)
        rj.z _upchar_1  # ( c C f -- c C)
        call _nip_body  # ( c C -- C)
_upchar_done:
        a:nop t r- [ret]    # (c -- c)

_upchar_1: # (c C)
        a:nop t d- r- [ret] # (c C -- c)


_digit2number:  # (c -- n f)
                # convert hexchar to int n
                # f=0 on error, f=1 on success
        .word _upchar
        .cstr "digit>num"
_digit2number_body:
        call _upchar_body       # (c -- C)
        lit 48                  # (c -- c '0')
        a:sub t d-              # (c '0' -- n)
        call _dup_body          # (n -- n n)
        rj.n _digit2number_error    # (n n -- n)
        lit 10                  # (n -- n 10)
        a:sub t                 # (n 10 -- n n-10)
        # if T < 0: number 0-9
        rj.nn _digit2number_hex # (n f -- n)
        lit 1 [ret]             # (n - n 1)
_digit2number_hex: # (n)
        lit 7                   # (n -- n 7)
        a:sub t d-              # (n 7 -- n-7)
        call _dup_body          # (n -- n n)
        lit 16                  # (n n -- n n 16)
        a:sub t d-              # (n n 16 -- n n-16)
        rj.nn _digit2number_error # (n f -- n)
        lit 1 [ret]             # (n -- n 1)
_digit2number_error:        # (n)
        lit 0 [ret]         # (n -- n 0)


_number: # (a len -- n f)
         # convert string (a is address of idx/addr pair), len is len of string,
         # to number n. f is 0 on error, else -1
        .word _digit2number
        .cstr "number"
_number_body:
        # save current base
        call _base_body
        call _fetch_body
        a:t r d- r+                 # (a l base -- a l r:base)

        call _swap_body             # (a l -- l a)

        # is first char minus sign (45)?
        # if yes, push minus? == 0 on rstack
        # if no,  push minus? != 0 on rstack
        call _dup_body
        call _str_get_body
        call _strcfetch_body
        lit 45 # '-'
        a:sub t d-
        a:t r r+                # (l a minus? r:base -- l a minus? r:base minus?)
        rj.nz _number__1        # (l a minus? r:base minus? -- l a r:base minus?)
        # is minus sign
        call _dup_body
        call _str_advance_body # skip minus sign
        # l--
        call _swap_body         # (l a -- a l)
        lit 1
        a:sub t d-              # (a l 1 -- a l-1)
        call _dup_body          # (a l -- a l l)
        rj.z _number_error2     # (a l l -- a l)
        call _swap_body         # (a l -- l a)
_number__1: # (l a)
        # is char dollar sign (36)?
        # put 0 on rstack
        call _dup_body
        call _str_get_body
        call _strcfetch_body
        lit 36 # '$'
        a:sub t d-              # (l a c 36 r:base minus? -- l a dollar? r:base minus?)
        rj.nz _number__2        # (l a dollar? r:base minus? -- l a r:base minus?)
        # is dollar, change base to 16
        lit 16
        call _base_body
        call _store_body
        # skip dollar sign
        call _dup_body
        call _str_advance_body # skip dollar sign
        # l--
        call _swap_body         # (l a -- a l)
        lit 1
        a:sub t d-              # (a l 1 -- a l-1)
        call _dup_body          # (a l -- a l l)
        rj.z _number_error2     # (a l l -- a l)
        call _swap_body         # (a l -- l a)
_number__2: # (l a r:base minus?)
        # put res=0 on rstack
        lit 0
        a:t r d- r+             # (l a 0 r:base minus? -- l a r:base minus? 0)

_number_loop: # (l a r:base minus? res)
        call _dup_body              # (l a -- l a a)
        call _str_read_next_body    # (l a a -- l a c)
        call _digit2number_body     # (l a c -- l a n f)
        rj.z _number_error3         # (l a n f -- l a n)
        call _dup_body              # (l a n -- l a n n)
        call _base_body             # (l a n n -- l a n n a-base)
        call _fetch_body            # (l a n n a-base -- l a n n base)
        a:lt t d-                   # (l a n n base -- l a n n<base)
        rj.z _number_error3         # (l a n f -- l a n)
        a:r t d+ r-                 # (l a n r:res -- l a n res)
        call _base_body
        call _fetch_body            # (l a n res a-base -- l a n res base)
        a:mull t d-                 # (l a n res base -- l a n res*base)
        a:add r d- r+               # (l a n res -- l a n+res)
        call _drop_body             # (l a n -- l a)
        # l--
        call _swap_body             # (l a -- a l)
        lit 1
        a:sub t d-                  # (a l 1 -- a l-1)
        call _dup_body              # (a l -- a l l)
        rj.z _number_done           # (a l l -- a l)
        call _swap_body             # (a l -- l a)
        rj _number_loop             # (l a -- l a)
_number_error3: # (w w w r:base minus? res)
        call _drop_body             # (w w w r:base minus? res -- w w r:base minus? res)
_number_error2: # (w w r:base minus? res)
        a:nop t d- r-               # (a l r:base minus? res -- a r:base minus?)
        a:nop t r-                  # (a r:base minus? -- a r:base)
        lit 0                       # (a -- a 0)
        rj _number_exit
_number_done: # (a l r:base minus? res)
        a:nop t d-                  # (a l r:base minus? res -- a r:base minus? res)
        a:r t r-                    # (a r:base minus? res -- res r:base minus?)
        a:r t d+ r-                 # (res r:base minus? -- res minus? r:base)
        rj.nz _number__3            # (res minus? r:base -- res r:base)
        # make 2s complement for negative number
        lit 0                       # (res r:base -- res 0 r:base)
        call _swap_body             # (res 0 r:base -- 0 res r:base)
        a:sub t d-                  # (0 res r:base -- 0-res r:base)
_number__3: # (res r:base)
        lit -1                      # (res r:base -- res f r:base)
_number_exit: # (w f r:base -- w f base)
        # restore base
        a:r t d+ r-
        call _base_body
        call _store_body
        a:nop t r- [ret]


dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
