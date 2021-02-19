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
    setdsp pop
    push ADDR_AS
    setasp pop

mainloop:
    jp mainloop

docol:
    push u
    apush
    jp next_word


next_word:
    # u = u + 2
    push u  # u
    push 2  # u 2
    add # u+2
    setu # u
    jp t

exit:
    ret

buildin_plus: # ( n n -- n )
    add swap pop
    jp next_word

buildin_dup: # ( n -- n n )
    push t
    jp next_word

buildin_drop: # ( n -- )
    pop
    jp next_word

.org $1000
dict:

plus: # ( n n -- n )
    .word 0 # first word
    .byte 4, "plus"
    .align
    .word buildin_plus

dup: # ( n -- n n )
    .word plus # previous word
    .byte 3, "dup"
    .align
    .word buildin_dup

drop: # ( n -- )
    .word dup # previous word
    .byte 4, "drop"
    .align
    .word buildin_drop

double: # ( n -- n)
    .word drop # previous word
    .byte 6, "double"
    .align
    .word docol
    .word dup
    .word plus
    .word exit
