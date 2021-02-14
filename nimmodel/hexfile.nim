import parseutils #, strutils, strformat

## Hexfile format:
# : COUNT ADDRESS TYPE DATA CHKSUM

proc getByteFromHexline(hexline: string, idx: uint8): uint8 =
    var value: int
    discard parseHex(hexline[1+idx*2..2+idx*2], value)
    return uint8(value)

proc readHexfile*(filename: string, memory: var openarray[uint8]) : bool =
    try:
        for l in lines filename:
            let len = getByteFromHexline(l, 0)
            let ahi = getByteFromHexline(l, 1)
            let alo = getByteFromHexline(l, 2)
            let adr = (uint16(ahi) shl 8) or alo
            let typ = getByteFromHexline(l, 3)
            let chksum = getByteFromHexline(l, 4+len)
            var sum = len + alo + ahi + typ + chksum
            for i in 0u8 ..< len:
                let val = getByteFromHexline(l, 4+i)
                sum += val
                memory[adr+i] = val
                # echo fmt"mem[{adr+i:04x}] = {val : x}"
            if sum != 0:
                return false
    except:
        return false
    return true
