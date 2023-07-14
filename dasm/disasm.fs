: clear-up s" dasm-marker" find-name ?dup if name>int execute then ;
clear-up
clearstack

marker dasm-marker


: update s" disasm.fs" included ;
: edit s" vim disasm.fs" system update ;

\ "poor mans case"
: case?   ( n1 n2 -- n1 ff | tf )
    over = dup IF nip THEN
;

variable pos 0 pos ! \ byte position in buf
variable buf
variable #buf

: load-file     slurp-file #buf ! buf ! ;

: var+1         dup @ 1+ swap ! ;
: pos++         pos var+1 ;
: next-byte     buf @ pos @ + c@ pos++ ;
: next-word     next-byte 8 lshift next-byte or ;
: reached-end   pos @ #buf @ = ;

: dump-file     hex begin next-byte hex. reached-end until decimal ;

: h16.          0 \ make double number
                base @ >r hex
                <<# # # # # #> #>> type
                r> base ! ;

\ 0 <addr:15> call
: disasm-call   dup 0x8000 and if exit then
                h16. ."  call" 0 ;
\ Bsp: 0x1234

\ 1 00 <imm:13> lit.l
: disasm-lit.l  dup 0xe000 and 0x8000 <> if exit then
                0x1ff and h16. ."  lit.l" 0 ;
\ Bsp: 0x8123

\ 1 01 <unused:4> <return:1> <imm:8>      lit.h
: disasm-lit.h  dup 0xe000 and 0xa000 <> if exit then
                dup 0xff and h16. ."  lit.h"
                0x100 and if ." r" then 0 ;
\ Bsp: 0xa0ff, 0xa1ff (ret)


\ 1 11 <cond:3> <imm:10> rjp
\ 000 always, 100 z, 101 nz, 110 n, 111 nn
: disasm-rjp    dup 0xe000 and 0xe000 <> if exit then
                dup 0x03ff and h16.
                ."  rjp"
                0x1c00 and
                case
                    0x1000 of ." .z" endof
                    0x1400 of ." .nz" endof
                    0x1800 of ." .n" endof
                    0x1c00 of ." .nn" endof
                endcase
                0 ;
\ Bsp:  0xe100 rjp
\       0xf100 rjp.z
\       0xf500 rjp.nz
\       0xf900 rjp.n
\       0xfd00 rjp.nn

\ 1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>  alu
: alu-op.       dup 0xf80 and 8 rshift case
                   0x0 of ." A:T" endof
                   0x1 of ." A:N" endof
                   0x2 of ." A:R" endof
                   0x3 of ." A:M" endof
                   0x4 of ." A:ADD" endof
                   0x5 of ." A:SUB" endof
                   0x6 of ." A:NOP" endof
                   0x7 of ." A:AND" endof
                   0x8 of ." A:OR" endof
                   0x9 of ." A:XOR" endof
                   0xa of ." A:LTS" endof
                   0xb of ." A:LT" endof
                   0xc of ." A:SR" endof
                   0xd of ." A:SRW" endof
                   0xe of ." A:SL" endof
                   0xf of ." A:SLW" endof
                   0x10 of ." A:JZ" endof
                   0x11 of ." A:JNZ" endof
                   0x12 of ." A:CARRY" endof
                   0x13 of ." A:INV" endof
                   0x14 of ." A:MULL" endof
                   0x15 of ." A:MULH" endof
                   ." UNKNOWN"
                endcase ;
: alu-ret.      dup 0x40 and if ." RET " then ;
: alu-dst.      dup 0x30 and case
                    0x00 of ." T " endof
                    0x10 of ." R " endof
                    0x20 of ." PC " endof
                    0x30 of ." M " endof
                endcase ;
: alu-dsp.      dup 0xc and case
                    0x4 of ." D+ " endof
                    0x8 of ." D- " endof
                    0xc of ." D? " endof
                endcase ;

: alu-rsp.      dup 0x3 and case
                    1 of ." R+ " endof
                    2 of ." R- " endof
                    3 of ." R+C " endof
                endcase ;

: disasm-alu    dup 0xe000 and 0xc000 <> if exit then
                alu-ret. alu-dsp. alu-rsp. alu-dst. alu-op.
                drop 0 ;

: disasm-word ( w -- )
                disasm-call  ?dup-0=-if exit then
                disasm-lit.l ?dup-0=-if exit then
                disasm-lit.h ?dup-0=-if exit then
                disasm-rjp ?dup-0=-if exit then
                disasm-alu ?dup-0=-if exit then
                h16.
                ;

: disassemble
                begin
                    pos @ h16. ." : "
                    next-word dup h16. ."   "
                    disasm-word cr
                    reached-end
                until
                ;

s" ../sim/forth.bin" load-file

disassemble

