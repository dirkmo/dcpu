start:

call 1234
call start

litl 123
lith 80

rj start
rj -4
rj.z 5
rj.nz 5
rj.n 5
rj.nn 5

a:t mem ret d+ r-
a:JZ pc r+pc


.cstr "Hallo"
.word 123, $ff, start
.org $200
.equ Name 123
.asciiz "Hallo"
.ascii "ohne null"
