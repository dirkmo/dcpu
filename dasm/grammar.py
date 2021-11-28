grammar = '''
?start: _line*

_line: LABEL? [_op | _dir] _COMMENT? _NL

_op: ldimm
    | reljmp
    | op0
    | op1
    | op2

op0: RET

op1:  "push"i REG  -> push
    | "pop"i REG   -> pop
    | "sl"i REG    -> sl
    | "sr"i REG    -> sr
    | "nsl"i REG   -> nsl
    | "nsr"i REG   -> nsr
    | "j" ["p"|"z"|"nz"|"c"|"nc"]
    | "b" ["r"|"z"|"nz"|"c"|"nc"]

op2: OP2 REG "," REG

ldimm: "ld.l"i REG "," NUMBER -> ldimml
    | "ld.h"i REG "," NUMBER  -> ldimmh
    | "ld"i REG "," NUMBER    -> ldimm

reljmp: "jp" CNAME    -> jp_label
    | "jz" CNAME      -> jpz_label
    | "jnz" CNAME     -> jnz_label
    | "jc" CNAME      -> jc_label
    | "jnc" CNAME     -> jnc_label
    | "jp" NUMBER     -> jp_offset
    | "jz" NUMBER     -> jz_offset
    | "jnz" NUMBER    -> jnz_offset
    | "jc" NUMBER     -> jc_offset
    | "jnc" NUMBER    -> jnc_offset

_dir: equ
    | org
    | asciiz
    | ascii
    | word

equ: ".equ"i CNAME "," NUMBER
org: ".org"i NUMBER
asciiz: ".asciiz"i STRING
ascii: ".ascii"i STRING
word: ".word"i NUMBER ("," NUMBER)*

REG:  "r1"i "0".."5"
    | "r"i "0".."9"
    | "pc"i
    | "st"i
    | "sp"i

RET: "ret"i

OP2: "ld"i 
    | "st"
    | "add"i
    | "sub"i
    | "and"i
    | "or"i
    | "xor"i
    | "cmp"i


LABEL: CNAME ":"

SIGNED_INT: ["+"|"-"] INT
HEX: "$" HEXDIGIT+

NUMBER: SIGNED_INT | HEX
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