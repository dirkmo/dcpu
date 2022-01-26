grammar = '''
start: _line*

_line: label? [_op | _dir] _COMMENT? _NL

label: CNAME ":"

_op:  call
    | litl
    | lith
    | lit
    | rj
    | alu

_dir: equ
    | org
    | ascii
    | word
    | cstr

call: CALL (CNAME | UNSIGNED_NUMBER)
litl: LITL UNSIGNED_NUMBER
lith: LITH UNSIGNED_NUMBER RETBIT?
lit:  LIT (CNAME | SIGNED_NUMBER) RETBIT?
rj: (RJP | RJZ | RJNZ | RJN | RJNN ) (CNAME | SIGNED_NUMBER)
alu: "a:"i _aluop _dst _dsp? _rsp? RETBIT?

_aluop: ALU_T
    | ALU_N
    | ALU_R
    | ALU_MEM
    | ADD
    | SUB
    | MUL
    | AND
    | OR
    | XOR
    | LT
    | LTS
    | SL
    | SLW
    | SR
    | SRW
    | JZ
    | JNZ
    | CARRY
    | INV
    | NOP

_dst: DST_T | DST_R | DST_MEM | DST_PC
_dsp: DP | DM
_rsp: RP | RM | RPC

equ: EQU CNAME SIGNED_NUMBER
org: ORG UNSIGNED_NUMBER
ascii: (ASCII|ASCIIZ) STRING
word: WORD [SIGNED_NUMBER|CNAME] ("," [SIGNED_NUMBER|CNAME])*
cstr: CSTR STRING

RETBIT: "[ret]"i

CALL: "call"i
LITL: "litl"i
LITH: "lith"i
LIT:  "lit"i
RJP:  "rj"i
RJZ:  "rj.z"i
RJNZ: "rj.nz"i
RJN:  "rj.n"i
RJNN: "rj.nn"i

DST_T: "t"i
DST_R: "r"i
DST_PC: "pc"i
DST_MEM: "mem"i
DP: "d+"i
DM: "d-"i
RP: "r+"i
RM: "r-"i
RPC: "r+pc"i

ALU_T: "t"i
ALU_N: "n"i
ALU_R: "r"i
ALU_MEM: "mem"i
ADD:  "add"i
SUB:  "sub"i
MUL:  "mul"i
AND:  "and"i
OR:   "or"i
XOR:  "xor"i
LT:   "lt"i
LTS:  "lts"i
SR:   "sr"i
SRW:  "srw"i
SL:   "sl"i
SLW:  "slw"i
JZ:   "jz"i
JNZ:  "jnz"i
CARRY: "c"i
INV:  "inv"i
NOP:  "nop"i

EQU:  ".equ"i
ORG:  ".org"i
WORD: ".word"i
ASCII: ".ascii"i
ASCIIZ: ".asciiz"i
CSTR: ".cstr"i


SIGNED_INT: ["+"|"-"] INT
HEX: ("$" | "0x"i) HEXDIGIT+
SIGNED_HEX: ["+"|"-"] HEX

OFFSET: ("+"|"-")(HEX|INT)

SIGNED_NUMBER: SIGNED_INT | SIGNED_HEX
UNSIGNED_NUMBER: INT | HEX
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