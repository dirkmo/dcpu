.equ UART_ST $FFE0
.equ UART_TX $FFE2
.equ UART_RX $FFE2

    .org 0
# pseudo registers
r0: .res 2
r1: .res 2
r2: .res 2
r3: .res 2

    .org $100
    
    push $f000
    setdsp
    push $f100
    setasp pop

    push 0
    store ibcount
    pop

loop:
    bra word
    .byte $ff

word:
    bra buildin_key   # ( -- keycode )
    push t # ( k -- k k )
    bra iswhitespace  # ( -- k b)
    jz wc
    bra appendChar
    jp word
wc:
    ret

appendChar: # ( c -- )
    push 0        # ( c -- c 0 )
    fetch ibcount # ( c 0 -- c n )
    # write to lower or upper byte of word?
    push 1        # ( c n -- c n 1 )
    and           # ( c n 1 -- c n&1 )
    pop           # ( c n&1 -- c )
    # define mask to clear byte, store in r0
    push $ff      # ( c -- c $ff )
    store r0
    pop           # (c $ff -- c )
    jnz appendChar2 # if zero then write to low byte
    # write to high byte -> shift char to upper byte
    push $ff00    # ( c -- c $ff00 )
    store r0
    pop           # ( c $ff00 -- c )
    push 8        # ( c -- c 8 )
    lsl           # ( c 8 -- (c<<8) )
appendChar2:
    # get addr of word where to put char
    push 0        # ( c -- c 0 )
    fetch ibcount # ( c 0 -- c n )
    push ibuf     # ( c n -- c n a )
    add           # ( c n a -- c n+a )
    # now t is addr of word where to put char
    push t        # ( c a -- c a a )
    fetch t       # ( c a a -- c a w )
    # clear byte before or'ing, mask is in r0
    push 0        # ( c a w -- c a w 0 )
    fetch r0      # ( c a w 0 -- c a w mask)
    and           # ( c a w mask -- c a w' )
    apush         # ( c a w -- c a w ), as: ( --  w )
    pop           # ( c a w -- c a ),   as: ( w --  w )
    swap          # ( c a ) -- a c ),   as: ( w --  w )
    push a        # ( a c -- a c w ),   as: ( w -- w )#
    apop          # ( a c w -- a c w ), as: ( w -- )
    or            # ( a c w -- a c|w )
    swap          # ( a w -- w a )
    store t       # ( w a -- w a )
    pop pop
    # ibcount++
    push 0        # ( -- 0 )
    fetch ibcount # ( 0 -- n )
    push 1        # ( n -- n 1 )
    add           # ( n 1 -- n+1 )
    store ibcount # ( n -- n )
    pop
    ret
    


iswhitespace: # ( c -- ),
    # sets zero-flag if whitespace
    push $20
    sub pop
    ret

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
    ret


.align
ibcount: .res 2
ibuf: .res 32
