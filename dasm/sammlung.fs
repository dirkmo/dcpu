( Forth Sammlung )


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
\ allot alloziert Dict-Speicher (100 cells = 800 Bytes)
variable my-array 100 cells allot \ array mit 101 cells
123 my-array 30 cells + ! \ my-array[30] = 123
my-array 30 cells + @ \ fetch
my-array 30 cells + ? \ print

\ create new-word
\ Fügt new-word zum Dict hinzu. Wird new-word ausgeführt, wird als erstes
\ der Data Space Pointer (HERE zum Zeitpunkt des Erzeugens) des Wortes auf
\ den Stack gelegt
create my-array 100 cells allot \ array mit 100 cells
\ Erzeugt Wort my-array. Hinter my-array werden 100 Zellen reserviert (HERE+100).
\ Wird my-array ausgeführt, so pusht es die Adresse der ersten Zelle auf den Stack.

\ allocate ( u -- addr wior )
\ Speicherallozierung per malloc(), kann wieder freigegeben werden (free())
\ wior: result (0 success);


\ pad
pad \ ( -- c-addr)
Address of a transient region that can be used as temporary data
storage. At least 84 characters of space is available.


\ dp
dp
Pointer auf here

\ here
\ dp @ = here
here
Adresse der nächsten freien Speicherzelle

\ dump ( addr u -- )
my-addr 16 dump

\ type ( c-addr u -- )
\ String ausgeben

: print-ascii-char
    dup 32 < if drop bl then emit ;

: print-ascii-table
    256 0 u+do
        i 8 mod 0= if cr then
        i 4 u.r bl emit
        i print-ascii-char
    loop ;


\ pad ( -- c-addr )
\ transient mem region

\ Eingabe:
pad 20 accept pad swap type


( Line parser and executor --> )

: is-space ( ca -- f )
    c@ bl = ;

: str-next-char ( ca u -- ca u )
    dup if swap 1+ swap 1- then ;

: skip-spaces ( ca u -- ca u )
    begin
        over is-space 0= if exit then
        str-next-char
    dup 0= until
    ;

: skip-non-spaces ( ca u -- ca u )
    begin
        over is-space 0<> if exit then
        str-next-char
    dup 0= until
    ;

\ increase ca / decrease u until next word begins
: str-next-word ( ca u -- ca u )
    skip-spaces
    \ dup 0= if exit then
    skip-non-spaces
    \ dup 0= if exit then
    skip-spaces
    ;

\ reduce char count to only include non-spaces (the first word)
: str-word-limit ( ca u -- ca u )
    2dup skip-non-spaces
    nip -
    ;

: executor ( ca u -- )
    skip-spaces ( ca u -- ca u )
    begin
        2dup 2>r ( ca u -- ca u ; R: -- ca u )
        str-word-limit ( ca u -- ca u )
        2dup cr type
        evaluate ( ca u -- )
        2r> str-next-word
    dup 0= until
    2drop
;

: str s" 1 2 3 .s" ;


( <-- Line parser and executor )

( wordlist stuff --> )

wordlist constant target-wordlist

\ :: adds word to target-wordlist
: :: get-current >r target-wordlist set-current : r> set-current ;

\ add wordlist to search order
: >order ( wid -- )
        >r get-order r> swap 1+ set-order ;

\ drop the first searched wordlist from search order
: previous ( -- )
        get-order nip 1- set-order ;

\ now select DCPU forth wordlist
target-wordlist >order

( <-- wordlist stuff )

