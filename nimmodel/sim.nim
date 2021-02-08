import
    os, strformat,
    hexfile, dcpu

var mem: array[0..0xffff, uint8]

proc read(adr: uint16): uint16 =
    let wordaddr = adr and 0xfffe
    let w = mem[wordaddr] or (uint16(mem[wordaddr+1]) shl 8)
    return w

proc write(adr, dat: uint16) =
    let wordaddr = adr and 0xfffe
    mem[wordaddr] = uint8(dat)
    mem[wordaddr+1] = uint8(dat shr 8)

proc handleParams =
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

proc main =
    handleParams()
    
    var cpu = Dcpu()

    cpu.setcallbacks(read, write)

    while true:
        if not cpu.statemachine():
            break



main()
