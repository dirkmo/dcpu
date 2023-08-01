.equ SIM_END $be00
.equ TIB_SIZE 64
.equ UART_ST 0xfffe
.equ UART_RX 0xffff
.equ UART_TX 0xffff

# code entry

rj _quit


.word SIM_END

# ----------------------------------------------------

# variables
state: .word 0          # 0: interpreting, -1: compiling

base: .word 10
latest: .word _tuck_header   # last word in forth dictionary
latest_imm: .word 0   # last word in immediate dictionary
dp: .word dp_init       # first free cell after dict

## input buffer
# number of words currently in TIB
tib_num: .word 0
# the input buffer itself
tib: .space TIB_SIZE
tib_end: .word 13 # TIB delimiter
# offset into input buffer, 0: first char of TIB
in: .word 0



# ----------------------------------------------------

# dictionary

# https://www.complang.tuwien.ac.at/forth/gforth/Docs-html/String-Formats.html
# c-addr can have two meanings:
# (c-addr) address of c-str, pointing on count
# (c-addr u) c-addr: address of first char of string, u: char count


_inc_header:
            # increment TOS by 1
            # (n -- n+1)
            .word 0
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
            call _is_zero
            a:nop t r- [ret]


_quit_header:
            .word _is_equal_header
            .cstr "quit"
_quit:      # receive up to TIB_SIZE chars from keyboard
            call _tib
            lit TIB_SIZE
            call _accept    # (a n1 -- n2)
            # store number of chars received
            lit tib_num
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
            call _fetch
            a:nop t r- [ret]


_to_in_inc_header: # (--)
            .word _to_in_fetch_header
            .cstr ">in++"
_to_in_inc:
            call _to_in
            call _fetch
            call _inc
            call _to_in
            call _store
            a:nop t r- [ret]


_count_header:
            # (a1 -- a2 n)
            # make addr+len pair from c-str address
            .word _to_in_inc_header
            .cstr "count"
_count:
            a:mem t d+      # (a1 -- a1 n)
            call _swap      # (a1 n -- n a1)
            call _inc       # (n a1 -- n a1+1)
            call _swap      # (n a2 -- a2 n)
            a:nop t r- [ret]


_advance_str_header:
            # (a n -- a n)
            # will increment address and decrement count of a c-str
            # but only if count is greater 0
            .word _count_header
            .cstr "advance-str"
_advance_str:
            call _dup       # (a n -- a n n)
            rj.z _advance_str_exit # (a n n -- a n)
_advance_str_exit:
            call _dec       # (a n -- a n-1)
            call _swap      # (a n -- n a)
            call _inc
            call _swap
            a:nop t r- [ret]


_scan_header: # (a1 l af -- a2 0|-1)
            # goes through memory range [a1,a1+l) and calls function at af
            # until function af returns non-zero or end-of-range is reached.
            # return values:
            #   e-o-r reached: (-- a2 0)
            #   af returns non-zero: (-- a2 -1)
            # Function af: (a -- 0|-1)
            #   Takes address a, does something and returns 0 or -1.
            .word _advance_str_header
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
            call _advance_str   # (a1 l -- a1 l)
            rj _scan_loop
_scan_found: # (a2 l r:af)
            a:nop t d- r-         # (a2 l r:af -- a2)
            lit -1 [ret]         # (a2 -- a2 1)
_scan_eorr: # (a2 l r:af)
            a:nop t d- r-         # (a2 l r:af -- a2)
            lit 0 [ret]         # (a2 -- a2 0)


_word_header: # (-- a-cstr)
            # copy next word from TIB to temp area (here) as c-str (addr)
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
            a:sub t d-          # (a a2 a -- a n)
            # copy word to here without moving here pointer
            call _here          # (a n -- a n here)
            # reserve a word for string len
            call _inc
            # copy word to temp area
            call _swap          # (a n here -- a here n)
            a:t r r+            # (a here n -- a here n r:n)
            call _move          # (a here n -- r:n)
            # store count in front of string
            call _here          # ( -- here r:n)
            a:r t d+ r-         # (here r:n -- here n)
            call _swap          # (here n -- n here)
            call _store         # (--)
            call _here          # ( -- here)
            a:nop t r- [ret]
_word_nothing: # (a)
            call _drop
            lit 0 [ret]


_interpret_header: # ( -- )
            .word _word_header
            .cstr "interpret"
_interpret:
            # set >in to start of TIB
            call _tib
            call _to_in
            call _store
            # get word
            call _word          # (-- a-cstr)
            # search word in dict
            call _dup           # (a -- a a)
            lit latest
            call _fetch         # (a a latest -- a a a-dict)
            call _find          # (a a a-dict -- a aw)
            call _dup
            rj.z _interpret_number # (a aw aw -- a aw)
            call _get_xt        # (a aw -- a xt)
            lit state
            call _fetch
            rj.nz _interpret_compile # (a xt f -- a xt)
            # call (interpret/execute) word xt
            a:t pc d- r+pc      # (a xt -- a)
            a:nop t d- r- [ret] # (a --)
_interpret_compile:
            # TODO compile word
_interpret_number:
            call _drop          # (a aw -- a)
            # TODO try to convert into number
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
            .word _key_avail_header
            .cstr "emit"
_emit:
            lit UART_TX
            a:t mem d- r- [ret]


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


_swap_header: # (a b -- b a)
            .word _2drop_header
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


_is_space_header:
            # (a -- 0|-1)
            # returns -1 if word at addr a is 32
            .word _comma_header
            .cstr "space?"
_is_space:
            call _fetch         # (a -- w)
            lit 32              # (w -- w 32)
            call _is_equal      # (w 32 -- f)
            a:nop t r- [ret]


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
            call _store
            a:nop t r- [ret]


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
            call _drop
            a:nop t r- [ret]


_find_header:
            # (a-str a-dict -- a-word|0)
            # search word in dictionary
            # a-str: address of cstr, the word to search for
            # a-dict: address of dictionary
            # a-word: address of word, 0 if not found
            .word _move_header
            .cstr "find"
_find:
            call _2dup
            call _inc # move to word name
            call _cstr_equal        # (as ad as ad -- as ad f)
            rj.nz _find_exit
            call _fetch             # (as ad -- as ad-next)
            call _dup
            rj.z _find_exit
            rj _find
_find_exit:
            call _nip               # (as ad -- ad)
            a:nop t r- [ret]


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
            call _str_equal
            a:nop t r- [ret]


_rot_header:
            # (n1 n2 n3 -- n2 n3 n1)
            .word _cstr_equal_header
            .cstr "rot"
_rot:
            a:t r d- r+         # (n1 n2 n3 -- n1 n2 r:n3)
            call _swap          # (n1 n2 -- n2 n1)
            a:r t d+ r-         # (n2 n1 r:n3 -- n2 n1 n3)
            call _swap          # (n2 n1 n3 -- n2 n3 n1)
            a:nop t r- [ret]


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
            call _over          # (n2 n1 -- n2 n1 n2)
            a:nop t r- [ret]


_get_xt_header:
            # (a -- xt)
            # a points to header of a word, eg. _tuck_header
            # returns xt, eg. address of _tuck
_get_xt:
            call _inc           # (a -- a)
            call _dup           # (a -- a a)
            call _fetch         # (a -- a n)
            a:add t d-          # (a n -- a)
            call _inc
            a:nop t r- [ret]


dp_init: # this needs to be last in the file. Used to initialize dp, which is the
         # value that "here" returns
