grammar = '''
start: line*

line: op [SH_COMMENT]
    | label [SH_COMMENT]
    | dir [SH_COMMENT]

label: CNAME ":"

dir: equ  -> dir_equ
   | res  -> dir_res
   | byte -> dir_byte
   | word -> dir_word
   | org  -> dir_org

equ: ".equ"i CNAME expr NEWLINE
res: ".res"i expr NEWLINE
byte: ".byte" expr ["," expr]* NEWLINE
word: ".word" expr ["," expr]* NEWLINE
org: ".org" NUMBER NEWLINE

op: OPA [ NUMBER | REG | CNAME | REL ]
  | OP

expr: NUMBER -> number
    | CNAME  -> cname
    | ESCAPED_STRING   -> string

OP: "ADD"i | "SUB"i | "and"i | "or"i | "xor"i | "lsr"i | "cpr"i
  | "pop"i | "apop"i | "ret"i | "setstatus"i | "setdsp"i | "setasp"i
  | "setusp"i | "seta"i | "apush"i

OPA: "push"i | "fetch"i | "store"i | "jmp"i | "bra"i | "jpc"
   | "jpnc"i | "jpz"i | "jpnz"i

REG: "t"i | "a"i | "n"i | "usp"i | "status"i | "dsp"i
   | "asp"i | "pc"i

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
