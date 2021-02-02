grammar = '''
start: _line*

_line: op+ [SH_COMMENT] NEWLINE
    | opa [SH_COMMENT] NEWLINE
    | label [SH_COMMENT]
    | _dir [SH_COMMENT]

label: CNAME ":"

_dir: equ
   | res
   | byte
   | word
   | org

equ: ".equ"i ID _expr
res: ".res"i NUMBER
byte: ".byte"i (_expr|ESCAPED_STRING) ["," (_expr|ESCAPED_STRING)]*
word: ".word"i _expr ["," _expr]*
org: ".org"i NUMBER

op: OP

opa: OPA [ REG | REL | _expr ]

_expr: "(" _expr ")"
    | plus
    | minus
    | mul
    | div
    | NUMBER | ID
//| idlo | idhi

mul: _expr "*" _expr
div: _expr "/" _expr
plus: _expr "+" _expr
minus: _expr "-" _expr

ID: CNAME
//idlo: "<" CNAME
//idhi: ">" CNAME

OP: "add"i | "sub"i | "and"i | "or"i | "xor"i | "lsr"i | "cpr"i
  | "pop"i | "apop"i | "ret"i | "setstatus"i | "setdsp"i | "setasp"i
  | "setusp"i | "seta"i | "apush"i | "int"i

OPA: "push"i | "fetch"i | "store"i | "jmp"i | "bra"i | "jpc"i
   | "jpnc"i | "jpz"i | "jpnz"i

REG: "asp"i | "t"i | "a"i | "n"i | "usp"i | "status"i | "dsp"i | "pc"i

REL: "u+"i NUMBER

SIGNED_INT: ["+"|"-"] INT
HEX: "$" HEXDIGIT+

NUMBER: SIGNED_INT | HEX
CHAR: "'" /./ "'"

%import common.WS
%import common.NEWLINE
%import common.SH_COMMENT
%import common.CNAME
%import common.DIGIT
%import common.HEXDIGIT
%import common.INT
%import common.ESCAPED_STRING

%ignore WS
'''
