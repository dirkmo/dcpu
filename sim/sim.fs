: update s" sim.fs" included ;
: edit s" vim sim.fs" system update ;

hex

\ definitions
2 constant tcell \ target cell size 2 bytes
: tcells tcell * ;
0x10000 constant MEM_SIZE \ memory 64k*16b words = 128kbyte
0x10    constant DS_SIZE
0x10    constant RS_SIZE

\ CPU memories (RAM, stacks)
MEM_SIZE tcells allocate throw constant TMEM
DS_SIZE  tcells allocate throw constant DS DS DS_SIZE erase
RS_SIZE  tcells allocate throw constant RS RS RS_SIZE erase

\ memory access

\ fetch word at word address
: tw@ ( wa -- w ) 2 * TMEM + w@ ;

\ store word at word address
: tw! ( w wa -- ) 2 * TMEM + w! ;

\ processor registers
variable pc
variable dsp
variable rsp
variable carry

: pc@ pc @ ;
: pc! pc ! ;
: pc? pc@ . ;
: dsp@ dsp @ ;
: dsp! dsp ! ;
: rsp@ rsp @ ;
: rsp! rsp ! ;
: carry@ carry @ ;
: carry! carry ! ;

: cpu-reset 0 pc! 0 rsp! 0 dsp! 0 carry! ;

: cpu-fetch pc@ tw@ ;

: ds! dsp@ tcells DS + w! ;
: rs! rsp@ tcells RS + w! ;

: ds@ dsp@ tcells DS + w@ ;
: rs@ rsp@ tcells RS + w@ ;

: ds? ds@ . ;
: rs? rs@ . ;

: dsp++ dsp@ 1+ DS_SIZE mod dsp! ;
: rsp++ rsp@ 1+ RS_SIZE mod rsp! ;

: dsp-- dsp@ 1- DS_SIZE mod dsp! ;
: rsp-- rsp@ 1- RS_SIZE mod rsp! ;

: ds-dump DS DS_SIZE tcells dump ;
: rs-dump RS RS_SIZE tcells dump ;

\ rshift-mask is used to extract bitfields
: rshift-mask ( value shift mask -- value )
    >r rshift r> and ;


\ new magic by "Poor Man's Case" (Klaus Schleisik)
\ see: https://youtu.be/m9zw_I7x_iI?t=7342
: case?   ( n1 n2 -- n1 ff | tf )
    over = dup IF nip THEN
;

\ pop value from RS to PC, and decrement rsp
: rs>pc         rs@ pc! ;

\ push PC to RS
: pc>rs         pc@ rs! ;


\ 0 <addr:15> call
: is-call? ( opcode -- flag ) 0x8000 and 0= ;
: call-addr ( opcode -- addr ) 0x7fff and ;
: cpu-call ( opcode -- ) call-addr pc! ;

\ 1 00 <imm:13> lit.l
: is-litl? ( opcode -- flag) 0xe000 and 0x8000 = ;
: litl-value ( opcode -- value ) 0x1fff and ;
: cpu-litl ( opcode -- ) dsp++ litl-value ds! ;

\ 1 01 <unused:4> <return:1> <imm:8> lit.h
: is-lith? ( opcode -- flag ) 0xe000 and 0xa000 = ;
: lith-value ( opcode -- value ) 0xff and ;
: lith-ret ( opcode -- ret ) 0x100 and 0<> ;
: cpu-lith ( opcode -- )
                dup
                lith-value 8 lshift \ get value, shift to upper byte
                ds@ 0x00ff and      \ clear upper byte of TOS
                or ds!              \ OR values put result back to TOS
                lith-ret if rsp++ rs>pc then
             ;

\ 1 11 <cond:3> <imm:10> rjp
\ conditions codes
0 ( 000 ) constant ALWAYS
4 ( 100 ) constant #Z
5 ( 101 ) constant #NZ
6 ( 110 ) constant #N
7 ( 111 ) constant #NN
: is-rjp? ( opcode -- flag )        0xe000 and 0xe000 = ;
: rjp-reladdr ( opcode -- reladdr ) 0x3ff and ;
: rjp-cond ( opcode -- cond )       0xa rshift 0x7 and ;
: rjp-cond-true? ( opcode -- flag )
                                rjp-cond
                                    ALWAYS case? if -1 exit then
                                    #Z     case? if ds@ 0= exit then
                                    #NZ    case? if ds@ 0<> exit then
                                    #N     case? if ds@ 0x8000 and 0<> exit then
                                    #NN    case? if ds@ 0x8000 and 0= exit then
                                drop 0 ;
: sign-extend-10bit ( val -- val )  dup 0x200 and if 0xfc00 or then ;
: reljp ( opcode -- )               rjp-reladdr sign-extend-10bit pc@ + 0xffff and pc! ;
: cpu-rjp ( opcode -- )             dup rjp-cond-true? if reljp exit then drop ;

\ 1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>  alu
: is-alu? 0xe000 and 0xc000 = ;
: cpu-alu ." alu" cr ;
