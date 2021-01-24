.org $100
.byte 100, 200, "Hallo", <ziel
.word 1000
.res $100
.equ UART_TX $F000

ziel:

add
sub
and
or
xor
lsr
cpr

push t
push a
push n
push usp
push $ffff
push status
push dsp
push asp
push pc
push ziel

fetch t
fetch a
fetch u+$100
fetch $ffff
fetch ziel

store t
store a
store u+$f00
store $423a
store ziel

jmp t
jmp a
jmp $1000
jmp ziel

bra t
bra a
bra $1000
bra ziel

jpc t
jpc a
jpc $1000
jpc ziel

jpnc t
jpnc a
jpnc $1000
jpnc ziel

jpz t
jpz a
jpz $1000
jpz ziel

jpnz t
jpnz a
jpnz $1000
jpnz ziel

pop
apop
ret

setstatus
setdsp
setasp
setusp
seta

apush

push (ziel+5)*4