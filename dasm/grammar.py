grammar = '''
start: _line*

_line: label? [_op | _dir] _COMMENT? _NL

_op: ld_imm
    | op0
    | op1_jpbr
    | op1
    | op2
    | ld
    | st
    | reljmp

label: CNAME ":"

op0: RET
   | RETI

op1:  PUSH REG
    | POP REG

op1_jpbr: JP REG
    | JZ REG
    | JNZ REG
    | JC REG
    | JNC REG
    | BR REG
    | BZ REG
    | BNZ REG
    | BC REG
    | BNC REG

op2:  LD REG "," REG
    | ADD REG "," REG
    | SUB REG "," REG
    | AND REG "," REG
    | OR REG "," REG
    | XOR REG "," REG
    | CMP REG "," REG
    | SL REG "," REG
    | SR REG "," REG
    | SLW REG "," REG
    | SRW REG "," REG

st: ST "(" REG OFFSET? ")" ","  REG

ld: LD REG "," "(" REG OFFSET? ")"

ld_imm: LDI  REG "," (NUMBER | CNAME)
     |  LDIL REG "," (NUMBER | CNAME)
     |  LDIH REG "," (NUMBER | CNAME)

reljmp: JP (CNAME | NUMBER)
    |   JZ (CNAME | NUMBER)
    |  JNZ (CNAME | NUMBER)
    |   JC (CNAME | NUMBER)
    |  JNC (CNAME | NUMBER)

_dir: equ
    | org
    | ascii
    | word

equ: EQU CNAME NUMBER
org: ORG NUMBER
ascii: (ASCII|ASCIIZ) STRING
word: WORD [NUMBER|CNAME] ("," [NUMBER|CNAME])*

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
RETI: "reti"i
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
SL:  "sl"i
SR:  "sr"i
SLW: "slw"i
SRW: "srw"i
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