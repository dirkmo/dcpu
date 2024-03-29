( Forth assembler )
( How Forth assemblers work: https://www.bradrodriguez.com/papers/tcjassem.txt )
( Forth crossassembler for J1: https://github.com/jamesbowman/j1 )

: clear-up s" dasm-marker" find-name ?dup if name>int execute then ;
clear-up

marker dasm-marker

: update s" dasm.fs" included ;
: edit s" vim dasm.fs" system update ;


\ DCPU cannot address single bytes, only word accesses. Thus, "there" returns a "word address".


\ target memory (64k words = 128k bytes)
0x20000 constant tmemory-size
tmemory-size allocate throw constant tmemory
tmemory tmemory-size 0 fill

0x1000 allocate throw constant scratch

\ target dp
variable tdp 0 tdp !

\ Inspiration from colorforth:
\ Two dictionaries, one for "normal" words, one for immediate words
\ Convention: Words from the immediate dictionary are prefixed with $


\ The "normal" dictionary
\ target latest
variable tlatest 0 tlatest !

\ The immediate words dictionary
variable $tlatest 0 $tlatest !


\ target here (word address!)
: there tdp @ ;


\ swap low and high byte of w1
: swap-bytes ( w1 -- w2 )
    dup  8 rshift 0x000000ff and
    swap 8 lshift 0x0000ff00 and
    or
;

\ tw! ( w offs -- )
\ store word (16-bits) into target memory
\ offs is word address
: tw!
    2 * \ make byte address from word address
    tmemory +
    swap swap-bytes swap
    w!
   ;

\ tw@ ( offs -- w )
: tw@
    2 * \ make byte address from word address
    tmemory +
    uw@
    swap-bytes
    ;

\ tw, ( w -- )
\ store w in tmemory and inc tdp
: tw, there tw! 1 tdp +! ;

\ for dev/debug
: tmemory-dump tmemory there 2 * dump ;



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
    create 0xc000 or ,
    does> @ or or or or tw, ;

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


\ alu       110 <unused:1> <alu:5> <ret:1> <dst:2> <dsp:2> <rsp:2>

\           RET DST D+ R+
: dup,      0   DT  D+  0  A:T, ;
: dup-ret,  RET DT  D+  0  A:T, ;
: drop,     0   DT  D-  0  A:T, ;
: drop-ret, RET DT  D-  0  A:T, ;

: swap,     0   DR  0  R+  A:N, \ N->R
            0   DT  D-  0  A:T, \ T->N
            0   DT  D+ R-  A:R, ; \ R->T

: swap-ret, 0   DR  0  R+  A:N, \ N->R
            0   DT  D-  0  A:T, \ T->N
            0   DT  D+ R-  A:R, \ R->T
            RET DT  0  R-  A:NOP, ; \ ret

: +,        0   DT  D-  0  A:ADD, ;
: +-ret     RET DT  D-  R- A:ADD, ;
: -         0   DT  D-  0  A:SUB, ;
: --ret     RET DT  D-  R- A:SUB, ;
: @,        0   DT  D-  0  A:MEMT, ;
: @-ret,    RET DT  D-  R- A:MEMT, ;
: !,        0   DM  D-  0  A:N,
            0   DT  D-  0  A:NOP, ;
: !-ret,    0   DM  D-  0  A:N,
            RET DT  D-  R- A:NOP, ;

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
    drop
    ;

\ create new dictionary entry "new-word"
\ a: latest of dict, eg tlatest or $tlatest
: target-create ( "new-word" a -- )
    \ tlatest @ tw, \ pointer to prev word
    \ there 1- tlatest ! \ set to new word
    dup @ tw, \ pointer to prev word
    there 1- swap ! \ set to new word
    parse-name \ get next word from input buffer
    append-name
    ;

: tcreate ( "new-word" )
    tlatest target-create ;

: $tcreate ( "new-word" )
    $tlatest target-create ;

\ copy c-str with 16-bit chars from tdict
\ to host memory with 8-bit chars
\ tc-addr: c-address in tmemory, pointing to count
: copy-cstr-from-tdict-to-scratch ( tc-addr -- )
    dup tw@ 1+ \ fetch count
    0 ?do
        dup tw@ \ fetch char
        scratch i + c! \ put to scratch memory
        1+
    loop drop ;


\ put name of word as c-str on stack
\ input a: addr of entry in tdict
\ a: prev-word address
\ a+1: count
\ a+2: first char of str
: tword-name ( ta -- c-addr u)
    1+ \ advance ta to point to count of c-str
    copy-cstr-from-tdict-to-scratch
    scratch 1+ scratch c@
    ;

\ get next word from tdict
\ ta is address in tdict (word addressed)
: tword-next ( ta -- ta )
    tw@ ;

\ find word in target dict
\ a: latest of dict (tlatest or $tlatest)
\ twp means word-pointer in tdict, points to entry found
\ f=0: not found, f=-1: found
: target-find ( a c-addr u -- twp f )
    @               ( ca u -- ca u twp )
    begin                   ( ca u twp )
        >r 2dup             ( ca u twp -- ca u ca u         ; R: -- twp )
        r@ tword-name       ( ca u ca u -- ca u ca u ca2 u2 ; R: twp -- twp )
        compare 0= if       ( ca u ca u ca2 u2 -- ca u      ; R: twp -- twp )
            \ found!
            2drop r> -1 exit ( ca u -- twp -1               ; R: twp -- )
        then
        r> tword-next       ( ca u -- ca u twp              ; R: twp -- )
        dup 0=              ( ca u twp -- ca u twp twp=0?   ; R: -- )
    until                   ( ca u twp f -- ca u twp )
    nip nip 0
    ;

: tfind ( c-addr u -- twp f ) tlatest target-find ;
: $tfind ( c-addr u -- twp f) $tlatest target-find ;

\ save target memory to binary file
: target-save-binary ( "filename" -- )
    parse-name w/o create-file abort" Cannot create file" ( fid )
    dup tmemory tmemory-size rot write-file abort" Failed to write file" ( fid -- )
    close-file
;


( DCPU Forth implementation )

\ ALU:          <ret:1> <dst:2>  <dsp:2> <rsp:2>

\ :: dup          0       DT       D+      0      A:T, ;
\ :: drop         0       DT       D-      0      A:NOP, ;
\ :: call                                         call, ;

clearstacks

: dasm-open-file ( ca u -- fid )
    r/o open-file throw ;

\ read line from file fid
\ c-a: addr of data read
\ num: num of bytes read
\ f: -1 success
: dasm-read-line ( fid -- c-a num f )
    scratch 1024 rot read-line throw
    scratch -rot
    ;

s" test.fs" dasm-open-file constant file

\ dasm-read-line

tcreate dup     dup-ret,
tcreate drop    drop-ret,
tcreate swap    swap-ret,
tcreate @       @-ret,
tcreate !       !-ret,

