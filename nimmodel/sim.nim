import
    os, strformat,
    hexfile, dcpu


var mem: array[0..0xffff, uint16]

let params = commandLineParams()

if params.len() < 1:
    echo "Usage: sim <hexfile>"
    quit(1)

let hexfn = params[0]

echo fmt"Reading {hexfn}"
let success = readHexfile(hexfn, mem)

if not success:
    echo fmt"Failed to read {hexfn}"
    quit(1)

var cpu = new Dcpu

cpu.reset()

