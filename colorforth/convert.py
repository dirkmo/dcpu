#!/usr/bin/env python3

import os
import sys

def tokenize(s):
    tokens = []
    t = ""
    space = False
    for c in s:
        o = ord(c)
        if space:
            if ord(c) < 33:
                t += c
            else:
                tokens.append(t)
                t = c
                space = False
        else:
            if ord(c) < 33:
                tokens.append(t)
                space = True
                t = c
            else:
                t += c
    tokens.append(t)
    return tokens


#if len(sys.argv) < 2:
#    sys.stderr.write("Missing filename\n")
#    exit(1)
#
#fn = sys.argv[1]

fn = "colorforth/test.cf"

with open(fn,"r") as f:
    lines = [line.strip() for line in f.readlines()]

tokens = []

for line in lines:
    tokens.extend(tokenize(line))

print(tokens)

D = {}
here = 0

for t in tokens:
    if t[0] == ":" and len(t) > 1:
        name = t[1:]
        D[name] = here
    elif t[0] == "^" and len(t) > 1:
        # execute immediately
        # means: assemble call word (not to dict)
    elif t[0] == "#" and len(t) >1:
        # execute immediately and compile result
        # means: assemble call word (not to dict)
        # and then compile result to dict as literal
    elif t[0] == '"' and len(t) > 2:
        # string literal
    else:
        # compile word