import lark

l = lark.Lark('''
start: expr

expr: "(" expr ")"
    | plus
    | minus
    | mul
    | div
    | NUMBER
    | id

mul: expr "*" expr
div: expr "/" expr
plus: expr "+" expr
minus: expr "-" expr

SIGNED_INT: ["+"|"-"] INT
HEX: "$" HEXDIGIT+
NUMBER: SIGNED_INT | HEX
id: CNAME

%import common.WS
%import common.NEWLINE
%import common.SH_COMMENT
%import common.CNAME
%import common.DIGIT
%import common.HEXDIGIT
%import common.INT

%ignore WS
%ignore NEWLINE

''')

prog = "(1+3*2-3)/2"

t = l.parse(prog)

print(t.pretty())

class MyTransformer(lark.Transformer):
    def mul(self, op):
        try:
            return int(op[0].children[0]) * int(op[1].children[0])
        except:
            return op
    def div(self, op):
        try:
            return int(op[0].children[0]) // int(op[1].children[0])
        except:
            return op
    def plus(self, op):
        try:
            return int(op[0].children[0]) + int(op[1].children[0])
        except:
            return op
    def minus(self, op):
        try:
            return int(op[0].children[0]) - int(op[1].children[0])
        except:
            return op
 

n = MyTransformer().transform(t)

print(n.pretty())