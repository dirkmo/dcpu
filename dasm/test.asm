.org $0

.equ UART_TX $F000

add
sub
and
or
xor
lsr
cpr
swap


.org $40
ziel:

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
fetch u+$62
fetch u+$f13a
fetch $ffff
fetch ziel
fetch UART_TX

.res 4

store t
store a
store u+$f00
store $423a
store ziel

jmp t
jmp a
jmp $1000
jmp ziel
jmp ende

bra t
bra a
bra $1000
bra ziel
int
bra ende

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

ende:

.byte 1, 2, "Hallo"
.byte 100, $ff
.word 1000+1, 100
.res $100
.word 1000+1, ziel
