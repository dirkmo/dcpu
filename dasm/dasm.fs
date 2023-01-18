( Forth assembler )
( How Forth assemblers work: https://www.bradrodriguez.com/papers/tcjassem.txt )
( Forth crossassembler for J1: https://github.com/jamesbowman/j1 )



\ DCPU cannot address single bytes, only word accesses. Thus, "there" returns a "word address".


\ target memory (64k words = 128k bytes)
0x10000 allocate throw constant tmemory
tmemory 0x10000 0 fill

\ target dp
variable tdp 0 tdp !

\ target latest
variable tlatest 0 tlatest !

\ target here (word address!)
: there tdp @ ;

\ tw! ( w offs -- )
\ store word (16-bits) into target memory
\ offs is word address
: tw!
    2 * \ make byte address from word address
    tmemory +
    w!
    ;

\ tw, ( w -- )
\ store w in tmemory and inc tdp
: tw, there tw! 1 tdp +! ;

\ for dev/debug
: tmemory-dump tmemory there 2 * dump ;
: update s" dasm.fs" included ;



( mnemonics )

\ call      0 <addr:15>
: call,     dup 0x8000 and abort" ERROR: call address out of range (0-0x7fff)"
            tw, ;

\ lit.l     100 <imm:13>
: lit.l,    dup 0x1fff > abort" ERROR: lit.l value out of range (0-0x3fff)"
            0x8000 or tw, ;

\ lit.h     101 <unused:4> <ret:1> <imm:8>
\ TODO: [ret] not supported yet
: lit.h,    dup 0xff > abort" ERROR: lit.h value out of range (0-0xff)"
            0xa000 or tw, ;

: lit,      dup 0x1fff and lit.l,
            dup 0x1fff > if 8 rshift lit.h, else drop then ;

\ alu       110 <unused:1> <alu:5> <ret:1> <dst:2> <dsp:2> <rsp:2>

0x001 constant R+
0x002 constant R-
0x003 constant RCALL
0x004 constant D+
0x008 constant D-

0x000 constant DT ( dst T)
0x100 constant DR ( dst R)
0x200 constant DP ( dst PC)
0x300 constant DM ( dst MEM)
0x400 constant RET

: alu-op ( op -- )
    create ,
    does> @ 0xc000 or or or or or tw, ;

0   7 lshift alu-op     A:T,
1   7 lshift alu-op     A:N,
2   7 lshift alu-op     A:R,
3   7 lshift alu-op     A:MEMT,
4   7 lshift alu-op     A:ADD,
5   7 lshift alu-op     A:SUB,
6   7 lshift alu-op     A:NOP,
7   7 lshift alu-op     A:AND,
8   7 lshift alu-op     A:OR,
9   7 lshift alu-op     A:XOR,
10  7 lshift alu-op     A:LTS,
11  7 lshift alu-op     A:LT,
12  7 lshift alu-op     A:SR,
13  7 lshift alu-op     A:SRW,
14  7 lshift alu-op     A:SL,
15  7 lshift alu-op     A:SLW,
16  7 lshift alu-op     A:JZ,
17  7 lshift alu-op     A:JNZ,
18  7 lshift alu-op     A:CARRY,
19  7 lshift alu-op     A:INV,
20  7 lshift alu-op     A:MULL,
21  7 lshift alu-op     A:MULH,


\ rjp       111 <cond:3> <imm:10>

0x000 constant rjp-always
0x400 constant rjp-zero
0x500 constant rjp-notzero
0x600 constant rjp-negative
0x700 constant rjp-notnegative

: rjp-op
    create  ( cond -- )
            0xe000 or ,
    does>   ( addr -- )
    @ swap
    there - \ make relative address
    dup abs 0x3ff > abort" ERROR: rjp-op address out of range"
    0x7ff and or tw,
    ;

rjp-always          rjp-op      rj,
rjp-zero            rjp-op      rjz,
rjp-notzero         rjp-op      rjnz,
rjp-negative        rjp-op      rjn,
rjp-notnegative     rjp-op      rjnn,


0xcafe constant BEGINGUARD
0xcaff constant IFGUARD


: begin, ( -- a )
        there BEGINGUARD ;

: again, ( a -- )
        BEGINGUARD <> abort" ERROR: No BEGINGUARD on top of stack"
        rj, ;

: until, ( a -- )
        BEGINGUARD <> abort" ERROR: No BEGINGUARD on top of stack"
        rjz, ;

: while, ( a -- )
        BEGINGUARD <> abort" ERROR: No BEGINGUARD on top of stack"
        rjnz, ;

: if,   ( -- a )
        IFGUARD
        there \ save current location on stack
        0 tw, \ reserve space for rjz in tmemory
        ;

: then, ( a -- )
        IFGUARD <> abort" ERROR: No IFGUARD on top of stack"
        0xe400 there or \ rjz = 0xe400
        swap tw! ;

: else, ( a -- )
        \ TODO
        ;

\ : iftest val? if ." ja" else ." nein" then ;


( Labels )

: label
    create there ,
    does> @
    ;

( Forth stuff )

\ append c-str to dict
: append-name ( c-addr u -- )
    dup tw, \ append count to dict
    0 ?do
        dup c@ tw, \ append char to dict
        1+ \ increment c-addr
    loop
    ;

\ create new dictionary entry
: create,
    tlatest @ tw, \ pointer to prev word
    there 1- tlatest ! \ set to new word
    parse-name \ get next word from input buffer
    append-name
    ;
