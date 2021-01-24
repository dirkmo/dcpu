.org $100
.byte 100, 'c', "hallo"
.word 1000
.long $ffffFFFF
.res $100
.equ UART_TX $F000

label:

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
push label

fetch t
fetch a
fetch u+$100
fetch $ffff
fetch label

store t
store a
store u+$f00
store $423a
store label

jmp t
jmp a
jmp $1000
jmp label

bra t
bra a
bra $1000
bra label

jpc t
jpc a
jpc $1000
jpc label

jpnc t
jpnc a
jpnc $1000
jpnc label

jpz t
jpz a
jpz $1000
jpz label

jpnz t
jpnz a
jpnz $1000
jpnz label

pop
apop
ret

setstatus
setdsp
setasp
setusp
seta

apush

