grammar = '''
?start: _line*

_line: LABEL? [_op | _dir | _COMMENT]

_NL: NEWLINE

_op: ldimm
    | reljmp
    | op0
    | op1
    | op2

op0: OP0 _NL

op1: OP1 REG _NL

op2: OP2 REG "," REG _NL

ldimm: "ld.l"i REG "," NUMBER _NL
    | "ld.h"i REG "," NUMBER _NL
    | "ld"i REG "," NUMBER _NL

reljmp: "j" ["p"|"z"|"nz"|"c"|"nc"] [CNAME|NUMBER] _NL

_dir: equ
    | org
    | asciiz
    | ascii
    | word

equ: ".equ"i CNAME "," NUMBER _NL
org: ".org"i NUMBER _NL
asciiz: ".asciiz"i STRING _NL
ascii: ".ascii"i STRING _NL
word: ".word"i NUMBER ("," NUMBER)* _NL

REG:  "r1"i "0".."5"
    | "r"i "0".."9"
    | "pc"i
    | "st"i
    | "sp"i

OP0: "ret"i

OP1:  "push"i
    | "pop"i
    | "sl"i
    | "sr"i
    | "nsl"i
    | "nsr"i
    | "j" ["p"|"z"|"nz"|"c"|"nc"]
    | "b" ["r"|"z"|"nz"|"c"|"nc"]

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