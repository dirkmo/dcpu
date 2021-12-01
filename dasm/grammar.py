grammar = '''
start: _line*

_line: label? [_op | _dir] _COMMENT? _NL

_op: ldimm
    | op0
    | op1
    | op2
    | ld
    | st
    | reljmp_label
    | reljmp_offset

label: CNAME ":"

op0: RET

op1:  PUSH REG
    | POP REG
    | JP REG
    | JZ REG
    | JNZ REG
    | JC REG
    | JNC REG
    | BR REG
    | BZ REG
    | BNZ REG
    | BC REG
    | BNC REG
    
op2:  ADD REG "," REG
    | SUB REG "," REG
    | AND REG "," REG
    | OR REG "," REG
    | XOR REG "," REG
    | CMP REG "," REG

st:   ST "(" REG ")" ","  REG
    | ST "(" REG OFFSET ")" ","  REG -> stoffset

ld:   LD REG "," "(" REG ")"
ldoffset: LD REG "," "(" REG OFFSET ")"

ldimm: LDI  REG "," NUMBER -> ldimm
     | LDIL REG "," NUMBER -> ldimml
     | LDIH REG "," NUMBER -> ldimmh

reljmp_label: JP CNAME
    | JZ CNAME
    | JNZ CNAME
    | JC CNAME
    | JNC CNAME

reljmp_offset: JP NUMBER
    | JZ NUMBER
    | JNZ NUMBER
    | JC NUMBER
    | JNC NUMBER

_dir: equ
    | org
    | asciiz
    | ascii
    | word

equ: EQU CNAME "," NUMBER
org: ORG NUMBER
asciiz: ASCIIZ STRING
ascii: ASCII STRING
word: WORD NUMBER ("," NUMBER)*

REG:  "r1"i "0".."5"
    | "r"i "0".."9"
    | "pc"i
    | "st"i
    | "sp"i

PUSH: "push"i
POP:  "pop"i
JP:   "jp"i
JZ:   "jz"i
JNZ:  "jnz"i
JC:   "jc"i
JNC:  "jnc"i
BR:   "br"i
BZ:   "bz"i
BNZ:  "bnz"i
BC:   "bc"i
BNC:  "bnc"i
RET:  "ret"i
LD:   "ld"i
LDI:  "ldi"i
LDIL: "ldi.l"i
LDIH: "ldi.h"i
ST:   "st"i
ADD:  "add"i
SUB:  "sub"i
AND:  "and"i
OR:   "or"i
XOR:  "xor"i
CMP:  "cmp"i
SHL:  "shl"i
SHR:  "shr"i
SHLW: "shl.w"i
SHRW: "shr.w"i
EQU:  ".equ"i
ORG:  ".org"i
WORD: ".word"i
ASCII: ".ascii"i
ASCIIZ: ".asciiz"i



SIGNED_INT: ["+"|"-"] INT
HEX: "$" HEXDIGIT+
SIGNED_HEX: ["+"|"-"] HEX

OFFSET: ("+"|"-")(HEX|INT)

NUMBER: SIGNED_INT | SIGNED_HEX
CHAR: "'" /./ "'"

_COMMENT: SH_COMMENT | CPP_COMMENT

_NL: NEWLINE

// see common.lark
%import common.WS
%import common.NEWLINE
%import common.SH_COMMENT
%import common.CPP_COMMENT
%import common.CNAME
%import common.DIGIT
%import common.HEXDIGIT
%import common.INT
%import common.ESCAPED_STRING -> STRING

%ignore WS
%ignore NEWLINE

'''