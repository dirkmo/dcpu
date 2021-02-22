.equ UART_ST $FFE0
.equ UART_TX $FFE2
.equ UART_RX $FFE2

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
base:   .res 2 # base for numbers (8, 10, 16, ...)


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

buildin_lit: # ( -- n )
    push u   # -- u
    push 2   # u -- u 2
    add      # u 2 -- u+2
    setu     # u+2 -- u
    fetch t  # u -- (u)
    jp next_word

buildin_stop:
    .byte $ff

wait_rx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 1 # bit 0: flag received
    and # sets zero flag if nothing received
    pop
    jz wait_rx
    ret

wait_tx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 2 # bit 1: flag sending
    and # sets zero flag if sending done
    pop
    jz wait_tx
    ret

buildin_key: # ( -- c )
    bra wait_rx
    push 0
    fetch UART_RX
    jp next_word

buildin_emit: # ( c -- )
    bra wait_tx
    store UART_TX
    jp next_word

align: # ( a -- a' )
    # adds 1 if a is odd
    push t      # a -- a a
    push $1     # a a -- a a 1
    and         # a a 1 -- a a&1
    add         # a a&1 -- a'
    ret

wordaftercstring: # ( a -- a )
    push t   # a -- a a
    fetch t  # a -- a (a)  ; (a) is count and first char
    push $ff # a (a) -- a (a) $ff
    and      # a (a) $ff -- a c  ; c = count
    push 1   # a c -- a c 1
    add      # a c 1 -- a c+1
    add      # a c+1 -- a+c+1  ; note: this addr might not be word aligned
    bra align # a+c+1 -- a'
    ret

buildin_cfa: # ( a -- a)
    # on stack: addr of word
    push 2   # a -- a 2
    add      # a 2 -- a+2
    # now t is addr of word name (counted string), eg. .byte 3, "dup"
    bra wordaftercstring # a+2 -- a'
    jp next_word

buildin_find:
    jp next_word

.org $1000
dict:

d_exit:
    .word 0 # first word
    .byte 4, "exit"
    .align
exit:
    .word buildin_exit

d_lit:
    .word d_exit
    .byte 3, "lit"
    .align
lit:
    .word buildin_lit

d_key:
    .word d_lit
    .byte 3, "key"
    .align
key:
    .word buildin_key

d_emit:
    .word d_key
    .byte 4, "emit"
emit:
    .word buildin_emit

d_plus: # ( n n -- n )
    .word d_emit
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

d_stop:
    .word d_quad
    .byte 4, "stop"
    .align
stop:
    .word buildin_stop

d_cfa:
    .word d_stop
    .byte 4, ">cfa"
cfa:
    .word buildin_cfa

d_find:
    .word d_cfa
    .byte 4, "find"
find:
    .word buildin_find

forth:
    .word docol
    .word lit
    .word $abcd
#    .word quad
    .word stop

