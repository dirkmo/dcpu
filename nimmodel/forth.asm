.equ ADDR_INPBUF_LEN    $900
.equ ADDR_INPBUF        $902
.equ ADDR_DICT          $1000
.equ ADDR_DS            $F200
.equ ADDR_AS            $F000

.org 0
# basic forth variables
latest: .res 2 # pointer to last dict entry
next:   .res 2 # interpreter pointer in word beeing executed
here:   .res 2  # pointer for adding stuff to dict
state:  .word 0 # 0: interpret, 1: compile


.org $100
    push ADDR_DS
    setdsp # dsp set, no push necessary
    push ADDR_AS
    setasp pop

    push forth
    setu
    jp next_word

docol:
    # save u on as
    push u   # -- u
    apush    # -- u ; as: -- u
    fetch t  # u -- (t)
    setu     # (t) -- u
    pop
    # jp next_word *fallthrough*

next_word: # ( -- )
    # u = u + 2
    push u  # -- u
    push 2  # u -- u 2
    add     # u 2 -- u+2
    setu    # u -- u
    # indirect jump t
    fetch t # u -- (t)
    fetch t # (t) -- ((t))
    jp t    # ((t)) --


buildin_plus: # ( n n -- n )
    add
    jp next_word

buildin_dup: # ( n -- n n )
    push t
    jp next_word

buildin_drop: # ( n -- )
    pop
    jp next_word

buildin_exit:
    # restore u from as
    push a # -- a
    apop   # a -- a; as: a --
    setu   # u -- u
    pop    # --
    jp next_word

.org $1000
dict:

d_exit:
    .word 0 # first word
    .byte 4, "exit"
    .align
exit:
    .word buildin_exit

d_plus: # ( n n -- n )
    .word d_exit
    .byte 4, "plus"
    .align
plus:
    .word buildin_plus

d_dup: # ( n -- n n )
    .word d_plus # previous word
    .byte 3, "dup"
    .align
dup:
    .word buildin_dup

d_drop: # ( n -- )
    .word d_dup # previous word
    .byte 4, "drop"
    .align
drop:
    .word buildin_drop

d_double: # ( n -- n)
    .word d_drop # previous word
    .byte 6, "double"
    .align
double:
    .word docol
    .word dup
    .word plus
    .word exit

d_quad: # ( n -- n )
    .word d_double
    .byte 5, "quad"
    .align
quad:
    .word docol
    .word double
    .word dup
    .word exit

forth:
    .word docol
    .word quad

simstop:
    .byte $ff