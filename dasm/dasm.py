import lark

l = lark.Lark('''
start: WORD "," WORD "!"

%import common.WORD   // imports from terminal library
%ignore " "           // Disregard spaces in text

''')

print( l.parse("Hello, World!") )
