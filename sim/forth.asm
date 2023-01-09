.equ SIM_END $be00
.equ TIB_SIZE 64
.equ UART_ST 0xfffe
.equ UART_RX 0xffff
.equ UART_TX 0xffff

# code entry

call _quit



.word SIM_END

# ----------------------------------------------------

# variables
state: .word 0          # 0: interpreting, -1: compiling

base: .word 10
latest: .word _comma_header   # last word in dictionary
dp: .word dp_init       # first free cell after dict

## input buffer
# available space in input buffer
tib_size: .word TIB_SIZE
# the input buffer itself
tib: .space TIB_SIZE
.word 13 # TIB delimiter
# offset into input buffer, 0: first char of TIB
in: .word 0



# ----------------------------------------------------

# dictionary

# https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/String-Formats.html
# c-addr can have two meanings:
# (c-addr) address of c-str, pointing on count
# (c-addr u) c-addr: address of first char of string, u: char count


_quit_header:
            .word 0
            .cstr "quit"
_quit:      # receive up to TIB_SIZE chars from keyboard
            call _tib
            lit TIB_SIZE
            call _accept    # (a n1 -- n2)
            # store number of chars received into var "tib_size"
            call _tib_size
            call _store
            # interpret what's in TIB
            call _interpret
            rj _quit


_to_in_header:
            # ( -- a)
            # puts address of "in" on stack
            .word _quit_header
            .cstr ">in"
_to_in:
            lit in [ret]


_tib_header:
            # ( -- a)
            # put address of TIB on stack
            .word _to_in_header
            .cstr "tib"
_tib:
            lit tib [ret]


_to_in_fetch_header: # ( -- c)
            # get char from TIB
            .word _tib_header
            .cstr ">in@"
_to_in_fetch:
            call _tib
            call _to_in
            a:add t d-
            call _fetch
            a:nop t r- [ret]


_to_in_inc_header: # (--)
            .word _to_in_fetch_header
            .cstr ">in++"
_to_in_inc:
            call _to_in
            call _fetch
            lit 1
            a:add t d-
            call _to_in
            call _store
            a:nop t r- [ret]

_tib_size_header:
            # ( -- n)
            # put size of TIB on stack
            .word _to_in_inc_header
            .cstr "#tib"
_tib_size:
            lit tib_size [ret]


_word_header: # (c -- )
            # copy next word from TIB to temp area (here) as c-str
            # word delimited by char c
            .word _to_in_header
            .cstr "word"
_word:
            # skip space
            call _to_in_fetch   # (del -- del c)
            # TODO
            # copy word to here (don't use comma, because it moves "here" pointer)
            a:nop t r- [ret]


_interpret_header: # ( -- )
            .word _word_header
            .cstr "interpret"
_interpret:
            # #TIB = 0
            lit 0
            call _to_in
            call _store
            # get word
            call _word
            a:nop t r- [ret]


_fetch_header:     # (addr -- n)
            .word _interpret_header
            .cstr "@"
_fetch:
            a:mem t r- [ret]


_store_header:     # (d addr -- )
            .word _fetch_header
            .cstr "!"
_store:
            a:n mem d-
            a:nop r d- r- [ret]


_accept_header: # (c-addr u1 -- u2)
            # receive up to u1 chars and store them at c-addr
            # u2: number of chars received
            # "return" char indicates end of input
            .word _store_header
            .cstr "accept"
_accept:
            a:t r d- r+     # (c-addr u1 -- c-addr r:u1)
            # push u2 (char cnt) on RS
            lit 0
            a:t r d- r+     # (c-addr 0 -- c-addr r:u1 u2)
_accept_loop: # (c-addr r:u1 u2)
            # TODO: check if TIB is full
            call _key       # (c-addr r:u1 -- c-addr c r:u1)
            lit 13
            a:sub t         # (c-addr c 13 -- c-addr c f r:u1 u2)
            # when f=0, c='\r' (return char)
            rj.z _accept_done # (c-addr c f -- c-addr c r:u1 u2)
            # put c in TIB
            call _over      # (ca c -- ca c ca r:u1 u2)
            call _store     # (ca c ca -- ca r:u1 u2)
            # u2++
            a:r t d+ r-
            lit 1
            a:add t d-      # (ca u2 1 -- ca u2+1 r:u1)
            # TIB full?
            a:r t d+        # (ca u2 -- ca u2 u1 r:u1)
            a:sub t         # (ca u2 u1 -- ca u2 f r:u1)
            rj.z _accept_full # (ca u2 f r:u1 -- ca u2 r:u1)
            a:t r d- r+     # (ca u2 -- ca r:u1 u2)
            # inc c-addr
            lit 1
            a:add t d-
            rj _accept_loop
_accept_full:
            # error, TIB is full
            rj _quit
_accept_done: # (c-addr c r:u1 u2)
            # append space (13)
            call _drop      # (ca c -- ca r:u1 u2)
            lit 13
            call _swap      # (ca 13 -- 13 ca r:u1 u2)
            call _store     # (13 ca -- r:u1 u2)
            a:r t d+ r-     # (r:u1 u2 -- u2 r:u1)
            a:nop t r-      # (u2 r:u1 -- u2)
            a:nop t r- [ret]


_key_header: # ( -- c)
            # receive char, blocking
            .word _accept_header
            .cstr "key"
_key:
            call _key_avail
            rj.z _key
            lit UART_RX
            a:mem t r- [ret]


_key_avail_header: # ( -- f)
            # return 1 if key available
            .word _key_header
            .cstr "key?"
_key_avail:
            lit UART_ST
            a:mem t r- [ret]


_emit_header: # (c --)
            # send char
            .word _key_avail
            .cstr "emit"
_emit:
            lit UART_TX
            a:t mem d- r- [ret]


_dup_header:       # (a -- a a)
            .word _emit_header
            .cstr "dup"
_dup:
            a:t t d+ r- [ret]


_drop_header:      # ( n -- )
            .word _dup_header
            .cstr "drop"
_drop:
            a:nop t d- r- [ret]


_swap_header:      # (a b -- b a)
            .word _drop_header
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


_here_add:  # (n -- )
            # helper function, not a word
            call _here      # (n -- n a)
            a:add t d-      # (n a -- n+a)
            lit dp          # (a -- a dp)
            call _store     # (a dp -- )
            a:nop t r- [ret]


_here_header: # ( -- a)
            .word _over_header
            .cstr "here"
_here:
            lit dp
            call _fetch
            a:nop t r- [ret]


_comma_header:     # (w --)
            # comma puts a word into the cell pointed to by here
            # and increments the data space pointer (value returned by here)
            .word _here_header
            .cstr ","
_comma:
            call _here          # (w -- w a)
            call _store         # (w a -- )
            lit 1               # ( -- 1)
            call _here_add      # (1 --)
            a:nop t r- [ret]


dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
