.equ UART_ST $FFE0
.equ UART_TX $FFE2
.equ UART_RX $FFE2

.org $100
    push $F000
    setdsp pop
    push $F100
    setasp pop
    push msg
    bra sendzstr

.byte $ff # sim stop


wait_tx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 2 # bit 1: flag sending
    and # sets zero flag if sending done
    pop pop
    jpnz wait_tx
    ret

sendc: # ( c -- c )
    bra wait_tx
    store UART_TX
    ret

wait_rx: # busy wait ( -- )
    push 0
    fetch UART_ST
    push 1 # bit 0: flag received
    and # sets zero flag if nothing received
    pop pop
    jpz wait_rx
    ret

key: # ( -- c )
    bra wait_rx
    push 0
    fetch UART_RX
    ret

# get low byte of word
lobyte: # ( w -- lo )
    push $ff # w $ff
    and      # w lo
    swap     # lo w
    pop      # lo
    ret

# get high byte of word
hibyte: # ( w -- hi )
    push 8 # w 8
    lsr    # w hi
    swap   # hi w
    pop    # hi
    ret

# send zero-terminated string
sendzstr: # ( a -- )
    push 0           # a 0
    fetch n          # a [a]
    bra lobyte       # a lo
    jpz sendzstr_end
    bra sendc        # a lo
    fetch n          # a [a]
    bra hibyte       # a hi
    jpz sendzstr_end
    bra sendc
    pop              # a
    push 1           # a 1
    add              # a (a+1)
    swap pop         # (a+1)
    jmp sendzstr
sendzstr_end:
    ret


msg: .byte "Hallo Welt!", 0
