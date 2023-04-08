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
MEM_SIZE tcells allocate throw constant TMEM ( Target memory )
DS_SIZE  tcells allocate throw constant DS DS DS_SIZE tcells erase ( data stack )
RS_SIZE  tcells allocate throw constant RS RS RS_SIZE tcells erase ( return stack )

\ memory access

\ fetch word at word address
: tw@ ( wa -- w ) 2 * TMEM + w@ ;

\ store word at word address
: tw! ( w wa -- ) 2 * TMEM + w! ;

\ processor registers
variable pc ( program counter )
variable dsp ( data stack pointer )
variable rsp ( return stack pointer )
variable carry

: pc@ pc @ ;
: pc! pc ! ;
: pc? pc@ . ;
: dsp@ dsp @ ;
: dsp! dsp ! ;
: dsp? dsp@ . ;
: rsp@ rsp @ ;
: rsp! rsp ! ;
: rsp? rsp@ . ;
: carry@ carry @ ;
: carry! carry ! ;
: set-carry if 1 else 0 then carry! ;

: cpu-reset 0 pc! 0 rsp! 0 dsp! 0 carry! ;

: cpu-fetch pc@ tw@ ;

: ds! dsp@ tcells DS + w! ;
: rs! rsp@ tcells RS + w! ;

: T@ dsp@ tcells DS + w@ ;
: N@ dsp@ 1- DS_SIZE and tcells DS + w@ ; \ next on data stack
: R@ rsp@ tcells RS + w@ ;


: T? T@ . ;
: N? N@ . ;
: R? R@ . ;

: dsp++ dsp@ 1+ DS_SIZE mod dsp! ;
: rsp++ rsp@ 1+ RS_SIZE mod rsp! ;

: dsp-- dsp@ 1- DS_SIZE mod dsp! ;
: rsp-- rsp@ 1- RS_SIZE mod rsp! ;

: ds-dump DS DS_SIZE tcells dump ;
: rs-dump RS RS_SIZE tcells dump ;

: info  ." PC: " pc? ." T: " T? ." N: " N? ." R: " R?
        CR ." DSP: " dsp? ds-dump
        ." RSP: " rsp? rs-dump
;

\ rshift-mask is used to extract bitfields
: rshift-mask ( value shift mask -- value )
    >r rshift r> and ;

: case?   ( n1 n2 -- n1 ff | tf )
    over = dup IF nip THEN
;

\ pop value from RS to PC, and decrement rsp
: rs>pc         R@ pc! ;

\ push PC to RS
: pc>rs         pc@ rs! ;

\ --------------------------------------------------------
\ 0 <addr:15> call
: is-call? ( opcode -- flag )       0x8000 and 0= ;
: call-addr ( opcode -- addr )      0x7fff and ;
: cpu-call ( opcode -- )            call-addr pc! ;

\ --------------------------------------------------------
\ 1 00 <imm:13> lit.l
: is-litl? ( opcode -- flag)        0xe000 and 0x8000 = ;
: litl-value ( opcode -- value )    0x1fff and ;
: cpu-litl ( opcode -- )            dsp++ litl-value ds! ;

\ --------------------------------------------------------
\ 1 01 <unused:4> <return:1> <imm:8> lit.h
: is-lith? ( opcode -- flag )       0xe000 and 0xa000 = ;
: lith-value ( opcode -- value )    0xff and ;
: lith-ret ( opcode -- ret )        0x100 and 0<> ;
: cpu-lith ( opcode -- )            dup
                                    lith-value 8 lshift \ get value, shift to upper byte
                                    T@ 0x00ff and      \ clear upper byte of TOS
                                    or ds!              \ OR values put result back to TOS
                                    lith-ret if rsp-- rs>pc then ;

\ --------------------------------------------------------
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
                                    #Z     case? if T@ 0= exit then
                                    #NZ    case? if T@ 0<> exit then
                                    #N     case? if T@ 0x8000 and 0<> exit then
                                    #NN    case? if T@ 0x8000 and 0= exit then
                                drop 0 ;
: sign-extend-10bit ( val -- val )  dup 0x200 and if 0xfc00 or then ;
: reljp ( opcode -- )               rjp-reladdr sign-extend-10bit pc@ + 0xffff and pc! ;
: cpu-rjp ( opcode -- )             dup rjp-cond-true? if reljp exit then drop ;

\ --------------------------------------------------------
\ 1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>  alu

\ create "call table" for all possible alu ops
0x20 cells allocate throw constant alu-table
\ clear alu-table
alu-table 0x20 cells erase

\ bind puts xt into call table at op-idx
: bind ( xt op-idx -- )  cells alu-table + ! ;

\ alu fetches xt at op-idx from alu-table and executes it
: alu ( op-idx -- )      cells alu-table + @ ?dup-if execute else ." Invalid ALU OP" then ;

\ alu bit field decoding
: is-alu? ( opcode -- flag )    0xe000 and 0xc000 = ;
: alu-op  ( opcode -- op-idx )  0x7 rshift 0x1f and ;
: alu-ret ( opcode -- ret )     0x6 rshift 0x1 and ;
: alu-dst ( opcode -- dst )     0x4 rshift 0x3 and ;
: alu-dsp ( opcode -- dsp )     0x2 rshift 0x3 and ;
: alu-rsp ( opcode -- rsp )     0x3 and ;

1 ( 01 ) constant DSP+1
2 ( 10 ) constant DSP-1

1 ( 01 ) constant RSP+1
2 ( 10 ) constant RSP-1
3 ( 11 ) constant RPC

0 ( 00 ) constant DT
1 ( 01 ) constant DR
2 ( 10 ) constant DPC
3 ( 11 ) constant DMEMT

variable alu-result
: alu-result! dup 0xffff > set-carry
    0xffff and alu-result ! ;

: do-alu-dsp ( opcode -- opcode )
    dup alu-dsp
    DSP+1 case? if dsp++ ." dsp++" exit then
    DSP-1 case? if dsp-- ." dsp--" exit then
    drop ;

: do-alu-rsp ( opcode -- opcode )
    dup alu-rsp
    RSP+1 case? if rsp++ exit then
    RPC   case? if rsp++ exit then
    RSP-1 case? if rsp-- exit then
    drop ;

: do-alu-ret ( opcode -- opcode )
    dup alu-ret if rs>pc then ; \ hint: dsp-- is done in do-alu-rsp

: do-alu-write ( opcode -- )
    alu-dst
    DT    case? if alu-result @ ds! exit then
    DR    case? if alu-result @ rs! exit then
    DPC   case? if exit then
    DMEMT case? if N@ T@ tw! exit then \ addr in T, data in N
    drop ;

\ setup alu-table
:noname ." A:T " T@ alu-result! ;   0x00 bind
:noname ." A:N"  N@ alu-result! ;   0x01 bind
:noname ." A:R"  R@ alu-result! ;   0x02 bind
:noname ." MEM" N@ T@ tw@ ; 0x03 bind
:noname ." +" N@ T@ + alu-result! ;   0x04 bind
:noname ." -" N@ T@ - alu-result! ;   0x05 bind
:noname ." NOP" ; 0x06 bind
:noname ." AND" N@ T@ and alu-result! ; 0x07 bind
:noname ." OR" N@ T@ or alu-result! ;  0x08 bind
:noname ." XOR" N@ T@ xor alu-result! ; 0x09 bind
:noname ." LTS"  N@ T@ < alu-result! ; 0x0a bind
:noname ." LT" N@ T@ < alu-result! ;  0x0b bind
:noname ." >>1" T@ 1 rshift alu-result! ; 0x0c bind
:noname ." >>8" T@ 8 rshift alu-result! ; 0x0d bind
:noname ." <<1" T@ 1 lshift alu-result! ; 0x0e bind
:noname ." <<8" T@ 8 lshift alu-result! ; 0x0f bind
:noname ." JZ" ;  0x10 bind
:noname ." JNZ" ; 0x11 bind
:noname ." carry" carry@ alu-result! ; 0x12 bind
:noname ." ~T" T@ invert 0xffff and alu-result! ; 0x13 bind
:noname ." MUL-LO" T@ N@ * 0xffff and alu-result! ; 0x14 bind
:noname ." MUL_HI" T@ N@ * 16 rshift 0xffff and alu-result! ; 0x15 bind

: cpu-alu
            dup alu-op alu
            do-alu-dsp
            do-alu-rsp
            do-alu-ret
            do-alu-write
            ;
