
\ if else then
: my-min 2dup < if drop else nip then ;

\ begin again
: my-endless-loop 0 begin dup . 1+ again ;

\ begin while repeat
\ wenn true springt while hinter repeat
\ wenn false zu begin
: my-while-loop 1 begin dup . 1+ dup 10 <= while repeat ;

\ begin until
\ wenn false springt until zu begin
: my-until-loop 1 begin dup . 1+ dup 10 > until ;

\ for loop ( u3 u4 -- ), Range [u4,u3), Inkrement +1  Zähler ist i
: my-for-loop u+do i . loop ;


\ Variables
variable test-var \ legt Variable an
123 test-var ! \ test-var = 123
test-var @ \ fetch test-var
test-var ? \ print test-var, short for @ .
10 test-var +! \ test-var += 10

\ Constants
123 constant test-const \ const test-const = 123
test-const \ legt 123 auf Stack
' test-const \ Dictionaryeintrag von test-const


\ Arrays
\ "cells" multipliziert TOS mit cellsize (8 Bytes)
\ allot alloziert den Speicher (100 cells = 800 Bytes)
variable my-array 100 cells allot \ array mit 100 cells
123 my-array 30 cells + ! \ my-array[30] = 123
my-array 30 cells + @ \ fetch
my-array 30 cells + ? \ print


\ dp
dp
Pointer auf here

\ here
\ dp @ = here
here
Adresse der nächsten freien Speicherzelle
