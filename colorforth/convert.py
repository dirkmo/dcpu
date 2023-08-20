#!/usr/bin/env python3

import os
import sys

if len(sys.argv) < 2:
    sys.stderr.write("Missing filename\n")
    exit(1)

fn = sys.argv[1]

with open(fn,"r") as f:
    lines = [line.strip() for line in f.readlines()]

#print(lines)

for line in lines:
    print(line.split(" "))
