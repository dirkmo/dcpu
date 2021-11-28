grammar = '''
start: _line*

_line: _op
    | _dir
    | _COMMENT

_NL: NEWLINE

_op: op0
    | op1
    | op2

op0: OP0 _NL

op1: OP1 REG _NL

op2: OP1 REG "," REG _NL

_dir: equ
    | org
    | assciz

equ: ".equ"i CNAME "," NUMBER _NL
org: ".org"i NUMBER _NL
assciz: ".asciiz"i ESCAPED_STRING _NL

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
%import common.ESCAPED_STRING

%ignore WS
%ignore NEWLINE

'''