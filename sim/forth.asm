# Forth for DCPU

# This file implements a Forth-like language for the DCPU stack machine.
# https://github.com/dirkmo/dcpu

# ----------------------------------------------------

# Notes

# https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/String-Formats.html
# c-addr can have two meanings:
# (c-addr)   address of c-str, pointing on count, followed by chars. I will call these c-str
# (c-addr u) c-addr: address of first char of string, u: char count
#            I will call these a/n-str

# ----------------------------------------------------
# some defines

.equ SIM_END $be00
.equ TIB_SIZE 64
.equ UART_ST 0xfffe
.equ UART_RX 0xffff
.equ UART_TX 0xffff


# ----------------------------------------------------
# Reset and IRQ Vectors

# Reset vector at address 0
reset: rj _quit

# IRQ vector at address 1
isr: .word SIM_END


# ----------------------------------------------------
# variables

state: .word 0 # 0: interpreting, -1: compiling
base: .word 10
dp: .word dp_init # first free cell after dictionaries ("here")

## input buffer
# number of words currently in TIB
tib_num: .word 0
# the input buffer itself
tib: .space TIB_SIZE
tib_end: .word 13 # TIB delimiter
# offset into input buffer, 0: first char of TIB
in: .word 0


# ----------------------------------------------------
# regular (non-immediate words) dictionary

_plus_header:
            # (n1 n2 -- n3)
            # add two numbers
            .word 0
            .cstr "+"
_plus:
            a:add t d- r- [ret]


_minus_header:
            # (n1 n2 -- n3)
            # subtract two numbers
            .word _plus_header
            .cstr "-"
_minus:
            a:sub t d- r- [ret]


_base_header:
            # ( -- a)
            # return address BASE
            .word _minus_header
            .cstr "base"
_base:
            lit base [ret]


_inc_header:
            # increment TOS by 1
            # (n -- n+1)
            .word _base_header
            .cstr "1+"
_inc:
            lit 1
            a:add t d- r- [ret]


_dec_header:
            # decrement TOS by 1
            # (n -- n-1)
            .word _inc_header
            .cstr "1-"
_dec:
            lit 1
            a:sub t d- r- [ret]


_is_zero_header: # (n -- 0|-1)
            # returns -1 if zero
            # return ´s 0 if not zero
            .word _dec_header
            .cstr "0="
_is_zero:
            rj.z _is_zero_yes
            lit 0 [ret]
_is_zero_yes:
            lit -1 [ret]


_is_equal_header: # (n1 n2 -- 0|-1)
            # return -1 if n1 and n2 are equal
            # return 0 if not equal
            .word _is_zero_header
            .cstr "="
_is_equal:
            a:sub t d-
            rj _is_zero


_plus_store_header: # (n a -- )
            # increase word at a by n
            .word _is_equal_header
            .cstr "+!"
_plus_store:
            a:t r r+        # (n a -- n a r:a)
            call _fetch     # (n a -- n w r:a)
            a:add t d-      # (n w -- n+w r:a)
            a:r t d+ r-     # (n -- n a)
            rj _store       # (n a -- )


_quit_header:
            .word _plus_store_header
            .cstr "quit"
_quit:      # receive up to TIB_SIZE chars from keyboard
            call _tib
            lit TIB_SIZE
            call _accept    # (a n1 -- n2)
            # store number of chars received
            lit tib_num
            call _store
            # set >in to start of TIB
            call _tib
            call _to_in
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


_tib_num_header:
            # ( -- n)
            # put number of words in TIB on stack
            .word _tib_header
            .cstr "tib-num"
_tib_num:
            lit tib_num
            a:mem t r- [ret]


_tib_num_left_header:
            # ( -- n)
            # put number of words left in TIB, starting from >in
            .word _tib_num_header
            .cstr "tib-num-left"
_tib_num_left:
            call _tib_num       # ( -- n)
            call _to_in         # (n -- n a)
            call _fetch         # (n a -- n >in)
            call _tib           # (n >in -- n >in TIB)
            a:sub t d-          # (n >in TIB -- n >in-TIB)
            a:sub t d- r- [ret] # ( n >in-TIB -- n->in-TIB)


_to_in_fetch_header: # ( -- c)
            # get char from TIB at pos in
            .word _tib_num_left_header
            .cstr ">in@"
_to_in_fetch:
            call _to_in
            rj _fetch


_to_in_inc_header: # (--)
            .word _to_in_fetch_header
            .cstr ">in++"
_to_in_inc:
            call _to_in
            call _fetch
            call _inc
            call _to_in
            rj _store


_count_header:
            # (a1 -- a2 n)
            # make a/n-str from c-str address
            .word _to_in_inc_header
            .cstr "count"
_count:
            a:mem t d+      # (a1 -- a1 n)
            call _swap      # (a1 n -- n a1)
            call _inc       # (n a1 -- n a1+1)
            rj _swap        # (n a2 -- a2 n)


_str_first_header:
            # (a n -- w)
            # return first word of a/n-string
            # if n=0, w=0
            .word _count_header
            .cstr "str-first"
_str_first:
            rj.z _str_first_empty   # (a n -- a)
            a:mem t r- [ret]        # (a -- w)
_str_first_empty:
            call _drop
            lit 0 [ret]


_str_first_nd_header:
            # (a n -- a n w)
            # return first word of a/n-string
            # if n=0, w=0
            # this will not drop a/n from stack
            .word _str_first_header
            .cstr "str-first-nd"
_str_first_nd:
            call _2dup
            rj _str_first


_str_next_header:
            # (a n -- a n)
            # will increment address and decrement count of a a/n-string
            # but only if count is greater 0
            .word _str_first_nd_header
            .cstr "advance-str"
_str_next:
            call _dup       # (a n -- a n n)
            rj.z _str_next  # (a n n -- a n)
_str_next:
            call _dec       # (a n -- a n-1)
            call _swap      # (a n -- n a)
            call _inc
            rj _swap


_scan_header: # (a1 l af -- a2 0|-1)
            # goes through memory range [a1,a1+l) and calls function at af
            # until function af returns non-zero or end-of-range is reached.
            # return values:
            #   e-o-r reached: (-- a2 0)
            #   af returns non-zero: (-- a2 -1)
            # Function af: (a -- 0|-1)
            #   Takes address a, does something and returns 0 or -1.
            .word _str_next_header
            .cstr "scan"
_scan: # (a1 l af)
            a:t r d- r+         # (a1 l af -- a1 l r:af)
_scan_loop: # (a1 l r:af)
            # if end-of-range reached then exit with (a2 0)
            a:t t d+            # (a1 l -- a1 l l r:af)
            rj.z _scan_eorr # (a1 l l -- a1 l r:af)
            call _over          # (a1 l -- a1 l a1 r:af)
            # call function af
            a:r pc r+pc         # (a1 l a1 r:af -- a1 l f r:af)
            rj.nz _scan_found # (a1 l f -- a1 l r:af)
            call _str_next   # (a1 l -- a1 l)
            rj _scan_loop
_scan_found: # (a2 l r:af)
            a:nop t d- r-         # (a2 l r:af -- a2)
            lit -1 [ret]         # (a2 -- a2 1)
_scan_eorr: # (a2 l r:af)
            a:nop t d- r-         # (a2 l r:af -- a2)
            lit 0 [ret]         # (a2 -- a2 0)


_word_header: # (-- a n)
            # copy next word from TIB to temp area (here) as a/n-string
            # word delimited by chars <= 32
            # moves >in pointer
            # if no word found, returns (0)
            .word _scan_header
            .cstr "word"
_word:
            # first, enforce delimiter after TIB area
            lit 13
            lit tib_end
            call _store
            # skip spaces, no bounds checking
            call _to_in_fetch   # (-- a)
            call _tib_num_left  # (a -- a n)
            lit _is_not_ws      # (a n -- a n af)
            call _scan          # (a n af -- a f)
            rj.z _word_nothing  # (a f -- a)
            # a points to first non-whitespace in TIB
            # move >in pointer
            call _dup
            call _to_in
            call _store
            # now search next white space
            call _dup           # (a -- a a)
            call _tib_num_left  # (a a -- a a n)
            lit _is_ws          # (a a n -- a a n af)
            call _scan          # (a a n af -- a a2 f)
            call _drop          # (a a2 f -- a a2)
            # move >in pointer
            call _dup
            call _to_in
            call _store
            # calculate length of word
            call _over          # (a a2 -- a a2 a)
            #a:sub t d-          # (a a2 a -- a n)
            a:sub t d- r- [ret] # (a a2 a -- a n)
_word_nothing: # (a)
            lit 0 [ret]


_interpret_header: # ( -- )
            .word _word_header
            .cstr "interpret"
_interpret:
            # get word
            call _word              # ( -- a n)
            call _dup               # (a n -- a n n)
            rj.z _interpret_exit
            # search word in immediate dict
            call _2dup              # (a n -- a n a n)
            lit latest_imm
            call _fetch             # (a n a n latest -- a n a n a-dict)
            call _find              # (a n a n a-dict -- a n aw)
            call _dup
            rj.nz _interpret_execute
            call _drop              # (a n aw -- a n)
            # search word in regular dict
            call _2dup              # (a n -- a n a n)
            lit latest
            call _fetch             # (a n a n latest -- a n a n a-dict)
            call _find              # (a n a n a-dict -- a n aw)
            call _dup
            rj.z _interpret_number # (a n aw aw -- a n aw)
            lit state
            call _fetch
            rj.nz _interpret_compile # (a n aw f -- a n aw)
_interpret_execute: # (a n aw)
            # drop (a n)
            a:t r d- r+
            call _2drop
            a:r t d+ r-
            call _get_xt            # (aw -- xt)
            # call (interpret/execute) word xt
            a:t pc d- r+pc          # (xt -- )
            rj _interpret
_interpret_compile: # (a n xt)
            # drop (a n)
            a:t r d- r+
            call _2drop
            a:r t d+ r-
            call _get_xt
            call _compile           # (xt -- )
            rj _interpret
_interpret_number:
            call _drop              # (a n aw -- a n)
            call _to_number         # (a n -- a n N)
            # drop (a n)
            a:t r d- r+             # (a n N -- a n r:N)
            call _2drop             # (a n r:N-- r:N)
            a:r t d+ r-             # (r:N -- N)
            # in compile mode?
            lit state
            call _fetch
            rj.z _interpret
            # always use 2 words for literal to be predictable
            call _lit2_comma        # (N -- )
            rj _interpret
_interpret_exit: # (a n)
            rj _2drop


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
            .word _key_avail_header
            .cstr "emit"
_emit:
            lit UART_TX
            rj _store


_dup_header: # (n -- n n)
            .word _emit_header
            .cstr "dup"
_dup:
            a:t t d+ r- [ret]


_2dup_header: # (n1 n2 -- n1 n2 n1 n2)
            .word _dup_header
            .cstr "2dup"
_2dup:
            call _over
            rj _over


_drop_header: # ( n -- )
            .word _2dup_header
            .cstr "drop"
_drop:
            a:nop t d- r- [ret]


_2drop_header:
            .word _drop_header
            .cstr "2drop"
_2drop:
            a:nop t d-
            a:nop t d- r- [ret]


_rdrop_header:
            .word _2drop_header
            .cstr "rdrop"
_rdrop:
            a:r t d+ r-     # save return address
            a:t pc d- r-    # pop data from rstack and return


_swap_header: # (a b -- b a)
            .word _rdrop_header
            .cstr "swap"
_swap:
            a:t r d- r+      # (a b -- a r:b)
            a:t t d+         # (a r:b -- a a r:b)
            a:r t d- r-      # (a a r:b -- b a)
            a:nop t d+ r- [ret] # (b a -- b a)


_over_header: # (a b -- a b a)
            .word _swap_header
            .cstr "over"
_over:
            a:n t d+ r- [ret]


_allot_header: # (n -- )
            .word _over_header
            .cstr "allot"
_allot:
            # helper function, not a word
            call _here      # (n -- n a)
            a:add t d-      # (n a -- n+a)
            lit dp          # (a -- a dp)
            call _store     # (a dp -- )
            a:nop t r- [ret]


_here_header: # ( -- a)
            .word _allot_header
            .cstr "here"
_here:
            lit dp
            rj _fetch


_comma_header: # (w --)
            # comma puts a word into the cell pointed to by here
            # and increments the data space pointer (value returned by here)
            .word _here_header
            .cstr ","
_comma:
            call _here          # (w -- w a)
            call _store         # (w a -- )
            lit 1               # ( -- 1)
            rj _allot           # (1 --)


_is_space_header:
            # (a -- 0|-1)
            # returns -1 if word at addr a is 32
            .word _comma_header
            .cstr "space?"
_is_space:
            call _fetch         # (a -- w)
            lit 32              # (w -- w 32)
            rj _is_equal        # (w 32 -- f)


_is_not_space_header:
            # (a -- 0|-1)
            # returns -1 if word at addr a is not 32
            .word _is_space_header
            .cstr "notspace?"
_is_not_space:
            call _is_space
            a:inv t r- [ret]


_is_ws_header:
            # (a -- 0|-1)
            # returns -1 if word at addr a is <33
            .word _is_not_space_header
            .cstr "ws?"
_is_ws:
            call _fetch         # (a -- w)
            lit 33              # (w -- w 33)
            a:sub t d-
            rj.n _is_ws_yes
            lit 0 [ret]
_is_ws_yes:
            lit -1 [ret]


_is_not_ws_header:
            # (a -- 0|-1)
            # returns -1 if word at addr a is >=33
            .word _is_ws_header
            .cstr "notws?"
_is_not_ws:
            call _is_ws
            a:inv t r- [ret]


_move_word_header:
            # (as ad -- )
            # copy word from address as to address ad
            .word _is_not_ws_header
            .cstr "move-word"
_move_word:
            call _swap
            call _fetch
            call _swap
            rj _store


_move_header:
            # (as ad n -- )
            # copy n words from as to ad
            .word _move_word_header
            .cstr "move"
_move:
            # check if words left to copy
            call _dup           # (as ad n -- as ad n n)
            rj.z _move_end      # (as ad n n -- as ad n)
            a:t r d- r+         # (as ad n -- as ad r:n)
            call _2dup
            # copy single word
            call _move_word
            # increment
            call _inc
            call _swap
            call _inc
            call _swap
            a:r t d+ r-         # (as ad r:n -- as ad n)
            call _dec
            rj _move
_move_end:
            call _2drop
            rj _drop


_find_header:
            # (a1 n1 a-dict -- a2)
            # search word in dictionary
            # a1/n1: a/n-str, the word to search for
            # a-dict: address of dictionary
            # a2: address of word header, 0 if not found
            .word _move_header
            .cstr "find"
_find:
            # end of dict reached?
            call _dup           # (a1 n1 ad -- a1 n1 ad ad)
            rj.z _find_not_found
            a:t r d- r+         # (a1 n1 -- a1 n1 r:ad)
            call _2dup          # (a1 n1 -- a1 n1 a1 n1 r:ad)
            a:r t d+            # (a1 n1 a1 n1 -- a1 n1 a1 n1 ad r:ad)
            # move to name of dict entry
            call _inc           # (a1 n1 a1 n1 ad -- a1 n1 a1 n1 s r:ad)
            call _count         # (a1 n1 a1 n1 s -- a1 n1 a1 n1 a2 n2 r:ad)
            # compare names
            call _str_equal     # (a1 n1 a1 n1 a2 n2 -- a1 n1 f r:ad)
            rj.nz _find_found   # (a1 n1 f -- a1 n1 r:ad)
            # names aren't equal, move to next entry
            a:r t d+ r-         # (a1 n1 -- a1 n1 ad)
            call _fetch         # (a1 n1 ad -- a1 n1 ad-next)
            rj _find
_find_found: # (a1 n1 r:ad)
            call _drop
            a:r t r-
            a:nop t r- [ret]
_find_not_found: # (a1 n1 ad)
            call _2drop
            call _drop
            lit 0 [ret]


_str_equal_header:
            # (a1 n1 a2 n2 -- f)
            # returns -1 if strings are equal, else 0
            .word _find_header
            .cstr "str="
_str_equal:
            call _rot           # (a1 n1 a2 n2 -- a1 a2 n2 n1)
            call _over          # (a1 a2 n2 n1 -- a1 a2 n2 n1 n2)
            call _is_equal      # (a1 a2 n2 n1 n2 -- a1 a2 n2 f)
            rj.z _str_equal_no  # (a1 a2 n2 f -- a1 a2 n2)
_str_equal_loop: # (a1 a2 n)
            call _dup
            rj.z _str_equal_yes
            a:t r d- r+         # (a1 a2 n -- a1 a2 r:n)
            call _over
            call _fetch
            call _over
            call _fetch
            call _is_equal      # (a1 a2 w1 w2 -- a1 a2 f r:n)
            a:r t d+ r-         # (a1 a2 f r:n -- a1 a2 f n)
            call _swap          # (a1 a2 f n -- a1 a2 n f)
            rj.z _str_equal_no  # (a1 a2 n f -- a1 a2 n)
            call _dec # n--
            a:t r d- r+         # (a1 a2 n -- a1 a2 r:n)
            call _inc # a2++
            call _swap # since both strings have same length, swapping doesn't matter
            call _inc # a1++
            a:r t d+ r-         # (a1 a2 r:n -- a1 a2 n)
            rj _str_equal_loop
_str_equal_yes: # (a1 a2 n2)
            call _2drop
            call _drop
            lit -1 [ret]
_str_equal_no: # (a1 a2 n2)
            call _2drop
            call _drop
            lit 0 [ret]


_cstr_equal_header:
            # (a1 a2 -- f)
            # compare c-strings
            .word _str_equal_header
            .cstr "cstr="
_cstr_equal:
            a:t r d- r+
            call _count
            a:r t d+ r-
            call _count
            rj _str_equal


_rot_header:
            # (n1 n2 n3 -- n2 n3 n1)
            .word _cstr_equal_header
            .cstr "rot"
_rot:
            a:t r d- r+         # (n1 n2 n3 -- n1 n2 r:n3)
            call _swap          # (n1 n2 -- n2 n1)
            a:r t d+ r-         # (n2 n1 r:n3 -- n2 n1 n3)
            rj _swap          # (n2 n1 n3 -- n2 n3 n1)


_nip_header:
            # (n1 n2 -- n2)
            .word _rot_header
            .cstr "nip"
_nip:
            a:t t d- r- [ret]


_tuck_header:
            # (n1 n2 -- n2 n1 n2)
            .word _nip_header
            .cstr "tuck"
_tuck:
            call _swap          # (n1 n2 -- n2 n1)
            rj _over            # (n2 n1 -- n2 n1 n2)



_get_xt_header:
            # (a -- xt)
            # a points to header of a word, eg. _tuck_header
            # returns xt, eg. address of _tuck
            .word _tuck_header
            .cstr "get-xt"
_get_xt:
            call _inc           # (a -- a)
            call _dup           # (a -- a a)
            call _fetch         # (a -- a n)
            a:add t d-          # (a n -- a)
            call _inc
            a:nop t r- [ret] # Optimieren ????


_upchar_header: # (c -- C)
        # convert char to upper case
        .word _get_xt_header
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
        # f=0 on error, f=-1 on success
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
        lit -1 [ret]             # (n - n 1)
_digit2number_hex: # (n)
        lit 7                   # (n -- n 7)
        a:sub t d-              # (n 7 -- n-7)
        call _dup               # (n -- n n)
        call _base
        call _fetch             # (n n -- n n base)
        a:sub t d-              # (n n base -- n n-base)
        rj.nn _digit2number_error # (n n-base -- n)
        lit -1 [ret]            # (n -- n 1)
_digit2number_error:            # (n)
        lit 0 [ret]             # (n -- n 0)


_to_number_header:
            # (a1 n1 -- a2 n2 N)
            # Convert string a/n to number with respect to BASE.
            # Format: [-][$][0-9a-z]+
            #         '$' will temporarily use base 16
            #  accumulator, will be added to result
            # a1/n1: address/len
            # a2/n2: unconverted string
            # N: result of conversion
            .word _digit2number_header
            .cstr ">number"
_to_number:
            call _dup
            rj.z _to_number_exit0   # (a1 n1 n1 -- a1 n1)
            # save sign (0: means there is a '-' sign)
            call _str_first_nd      # (a1 n1 -- a1 n1 c)
            lit 45 # '-'
            a:sub t d-              # (a1 n1 c -- a1 n1 sign?)
            a:t r r+                # (a1 n1 sign? -- a1 n1 sign? r:sign?)
            rj.nz _number_save_base # (a1 n1 sign? r:sign? -- a1 n1 r:sign?)
            call _str_next          # (a1 n1 -- a1 n1 r:sign?)
            call _dup
            rj.z _to_number_exit1   # (a1 n1 n1 -- a1 n1 r:sign?)
_number_save_base:
            call _base              # (a1 n1 -- a1 n1 a-base r:sign?)
            a:mem r d- r+           # (a1 n1 a-base -- a1 n1 r:sign? base)
            # check if next char is dollar ($) for hex numbers, put result on r-stack
            # 0 if dollar, else: not dollar
            call _str_first_nd      # (a1 n1 -- a1 n1 c)
            lit 36 # '$'
            a:sub t d-              # (a1 n1 c 36 -- a1 n1 dollar?)
            rj.nz _number_init      # (a1 n1 dollar? -- a1 n1 r:sign? base)
            # yes, dollar: set base to 16
            lit 16
            call _base
            call _store
            # move to next char
            call _str_next
            call _dup
            rj.z _to_number_exit2   # (a1 n1 n1 -- a1 n1)
_number_init: # (a1 n1)
            lit 0 # accumulator N
            a:t r d- r+             # (a1 n1 N -- a1 n1 r:sign? base N)
_number_loop: # (a1 n1 r:sign? base N)
            # the loop that converts and adds all the digits begins here
            call _str_first_nd      # (a1 n1 -- a1 n1 c r:sign? base N)
            call _digit2number      # (a1 n1 c -- a1 n1 u f r:sign? base N)
            rj.z _to_number_exit3   # (a1 n1 u f -- a1 n1 u r:sign? base N)
            # Multiply accumulator with BASE
            a:r t d+ r-             # (a1 n1 u r:sign? base N -- a1 n1 u N r:sign? base)
            call _base
            call _fetch             # (a1 n1 u N -- a1 n1 u N BASE r:sign? base)
            a:mull t d-             # (a1 n1 u N BASE -- a1 n1 u N r:sign? base)
            a:add r d- r+           # (a1 n1 u N -- a1 n1 u r:sign? base N)
            call _drop              # (a1 n1 u -- a1 n1 r:sign? base N)
            call _str_next
            call _dup
            rj.nz _number_loop      # (a1 n1 n1 -- a1 n1 r:sign? base N)
            # conversion done, unwind r-stack
            a:r t d+ r-             # (a1 n1 r:sign? base N -- a1 n1 N r:sign? base)
            # restore base
            a:r t d+ r-             # (a1 n1 N r:sign? base -- a1 n1 N base r:sign?)
            call _base
            call _store             # (a1 n1 N base a-base r:sign? -- a1 n1 N r:sign?)
            # apply sign
            a:r t d+ r-             # (a1 n1 N r:sign? -- a1 n1 N sign?)
            rj.nz _to_number_done   # (a1 n1 N sign? -- a1 n1 N)
            lit 0
            call _swap
            a:sub t d-
_to_number_done: # (a1 n1 N)
            a:nop t r- [ret]
_to_number_exit3: # (a1 n1 u r:sign? base N)
            a:r t r-                # (a1 n1 u r:sign? base N -- a1 n1 N r:sign? base)
            call _rdrop             # (a1 n1 N r:sign? base -- a1 n1 N r:sign?)
            call _rdrop             # (a1 n1 N r:sign? -- a1 n1 N)
            rj _to_number_done
_to_number_exit2: # (a1 n1 r:sign? base)
            call _rdrop # ( ... -- a1 n1 r:sign?)
_to_number_exit1: # (a1 n1 r:sign?)
            call _rdrop # ( ... -- a1 n1)
_to_number_exit0: # (a1 n1)
            lit 0 [ret]             # (a1 n1 -- a1 n1 0)


_lit_comma_header:
            # (n -- )
            # create opcode(s) to push literal on stack
            # and append them to dict
            # omits lit.h if possible
            .word _to_number_header
            .cstr "lit,"
_lit_comma:
            # opcode lit.l 0x8000 | n-lo
            lit 0x1fff
            a:and t             # (n -- n n-lo)
            lit 0x8000 # opcode lit.l
            a:or t d-           # (n n-lo 0x8000 -- n op)
            call _comma         # (n op -- n)
            # opcode lit.h 0xa000 | n-hi
            a:srw t             # (n -- n-hi)
            lit 0xe0
            a:and t d-
            call _dup           #(n-hi -- n-hi n-hi)
            rj.z _lit_comma_no_lith
            lit 0xa000 # opcode lit.h
            a:or t d-           # (n-hi -- op)
            call _comma
            a:nop t r- [ret]
_lit_comma_no_lith: # (n-hi)
            a:nop t d- r- [ret]


_lit2_comma_header:
            # (n -- )
            # create two opcodes for lit.l, lit.h to push literal on stack
            # and append them to dict
            # This always uses two words in dict
            .word _lit_comma_header
            .cstr "lit2,"
_lit2_comma:
            # opcode lit.l 0x8000 | n-lo
            lit 0x1fff
            a:and t             # (n -- n n-lo)
            lit 0x8000 # opcode lit.l
            a:or t d-           # (n n-lo 0x8000 -- n op)
            call _comma         # (n op -- n)
            # opcode lit.h 0xa000 | n-hi
            a:srw t             # (n -- n-hi)
            lit 0xe0
            a:and t d-
            lit 0xa000 # opcode lit.h
            a:or t d-           # (n-hi -- op)
            call _comma
            a:nop t r- [ret]


_compile_header:
            # (xt --)
            # compile far call (3 words) to xt to dict
            .word _lit2_comma_header
            .cstr "compile"
_compile:
            # compile far call
            call _lit2_comma
            # opcode a:t pc d- r+pc
            lit 0xc02b
            rj _comma


_close_bracket_header:
            # enter compilation mode
            # the interpreter will compile words to the dictionary
            .word _compile_header
            .cstr "]"
_close_bracket:
            lit -1 # -1: compiling
            lit state
            a:n mem d-
            a:nop t d- r- [ret]


#_create_header:
#            # (a-dict "name" -- )
#            # parsing word
#            # create new dict entry in dictionary
#            # a-latest: address of latest or latest_imm
#            .word _close_bracket_header
#            .cstr "create"
_create:
            a:t r d- r+             # (a-dict -- r:a-dict)
            # get next word from TIB
            call _word              # ( -- a n r:a-dict)
            call _dup               # (a n -- a n n r:a-dict)
            rj.z _create_fail       # (a n n -- a n r:a-dict)
            # put here on stack, this is the header address (ah)
            call _here              # (a n -- a n ah r:a-dict)
            # write address of previous word header
            a:r t d+                # (a n ah -- a n ah a-dict r:a-dcit)
            call _fetch
            call _comma
            # update latest
            a:r t d+ r-             # (a n ah -- a n ah a-dict)
            a:n mem d-              # (a n ah latest -- a n ah)
            call _drop              # (a n ah -- a n)
            ## write c-str of name
            # count
            call _dup
            call _comma
            call _here              # (a n -- a n here)
            call _swap              # (a n here -- a here n)
            a:t r r+                # (a here n -- a here n r:n)
            # copy chars
            call _move              # (a here n -- r:n)
            a:r t d+ r-             # (r:n -- n)
            call _allot             # (n -- )
            ## add opcode that pushes here on stack
            #call _here
            #call _lit_comma         # (here -- )
            a:nop t r- [ret]
_create_fail: # (a n r:a-dict)
            call _rdrop
            rj _2drop


_create_forth_header:
            # ("name" -- )
            # parsing word
            # create new dict entry in standard forth dictionary (non-immediate)
            .word _close_bracket_header
            .cstr "create-f"
_create_forth:
            lit latest
            call _create
            call _here
            rj _lit_comma


_create_immediate_header:
            # ("name" -- )
            # create new dict entry in standard forth dictionary (immediate)
            .word _create_forth_header
            .cstr "create-i"
_create_immediate:
            lit latest_imm
            call _create
            call _here
            rj _lit_comma


_colon_header:
            # ("name" -- entry)
            # parsing word
            # create new dict entry and enter compilation mode
            # entry: address of new dict entry
            .word _create_immediate_header
            .cstr ":"
_colon:
            call _create_forth
            rj _close_bracket


_colon_i_header:
            # ("name" -- entry)
            # parsing word
            # create new dict entry and enter compilation mode
            # entry: address of new dict entry
            .word _colon_header
            .cstr ":i"
_colon_i:
            call _create_immediate
            rj _close_bracket


_type_header:
            # (a n -- )
            # display a/n-string
            .word _colon_i_header
            .cstr "type"
_type:
            call _dup
            rj.z _type_end
            call _dec               # (a n -- a n)
            a:t r d- r+             # (a n -- a r:n)
            call _dup
            call _fetch
            call _emit
            call _inc
            a:r t d+ r-             # (a r:n -- a n)
            rj _type
_type_end:
            call _drop
            a:nop t d- r- [ret]


_print_header:
            .word _type_header
            .cstr "print"
_print:
            lit teststr
            call _count
            call _type
            a:nop t r- [ret]


_tick_header: # ("name" -- xt)
            .word _print_header
            .cstr "'"
_tick:
            call _word              # ( -- a n)
            call _2dup
            lit latest_imm
            call _find              # (a n a n a-dict -- a n nt)
            # TODO


_bracket_tick_header: # ()
            .word _tick_header
            .cstr "[']"
_bracket_tick:
            call _tick
            # TODO



teststr: .cstr "Test", 10, "Hallo", 10, "Ende", 10

welcome: .cstr "Forth for DCPU", 13, 10

latest: .word _bracket_tick_header # last word in forth dictionary

# ----------------------------------------------------
# immediate dictionary words

_open_bracket_header:
            # leave compilation mode, enter immediate/execution mode
            # the interpreter will execute words
            .word 0
            .cstr "["
_open_bracket:
            lit 0 # 0: interpreting
            lit state
            call _store
            a:nop t r- [ret]

_semicolon_header:
            # (entry -- )
            # end compilation mode, update "latest" pointer
            .word _open_bracket_header
            .cstr ";"
_semicolon:
            lit 0xc342 # opcode for a:nop r- [ret]
            call _comma
            call _open_bracket
            a:nop t r- [ret]


_s_quote_header: # parse a string and append to dictionary
            # parsing word
            # This immediate word will compile the following instructions to dictionary:
            # [litstring] [c-str] [type]
            .word _semicolon_header
            .cstr "s\""
_s_quote:
            # placeholder for literal c-str address
            call _here          # ( -- a1)
            lit 3
            a:add t d-          # (a1 3 -- c-str)
            call _lit2_comma    # (c-str -- )
            # placeholder for rj "behind" cstr
            call _here          # ( -- a2)
            lit 0
            call _comma
            call _here          # ( -- a2 a3)
            # placeholder for count of c-str
            lit 0
            call _comma
_s_quote_loop: # (a2 a3)
            call _to_in_fetch   # (a2 a3 -- a2 a3 w)
            lit 0x22 # quote char "
            a:sub t             # (a2 a3 w 0x22 -- a2 a3 w f)
            rj.z _s_quote_loop_done # (a2 a3 w f -- a2 a3 w)
            # store in dict
            call _comma         # (a2 a3 w -- a2 a3)
            # inc count
            lit 1
            call _over
            call _plus_store    # (a2 a3 1 a3 -- a2 a3)
            rj _s_quote_loop
_s_quote_loop_done: # (a2 a3 w)
            call _2drop         # (a2 a3 w -- a2)
            call _here          # (a2 -- a2 a4)
            call _swap          # (a2 a4 -- a4 a2)
            a:sub t d+          # (a4 a2 -- a4 a2 offset)
            lit 0xe000 # rj opcode
            a:or t d-           # (a4 a2 offset 0xe000 -- a4 a2 opcode)
            call _swap
            call _store         # (a4 a2 opcode -- a4)
            call _drop          # (a4 -- )
            a:nop t r- [ret]



latest_imm: .word _semicolon_header # last word in immediate dictionary

# ----------------------------------------------------

dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
