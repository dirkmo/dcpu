import parseutils, strutils

## Hexfile format:
# : COUNT ADDRESS TYPE DATA CHKSUM

proc getByteFromHexline(hexline: string, idx: int): int =
    var val: int
    discard parseHex(hexline[1+idx*2..2+idx*2], val)
    val

proc readHexfile*(filename: string, memory: var openarray[uint16]) : bool =
    try:
        for l in lines filename:
            let len = getByteFromHexline(l, 0)
            let ahi = getByteFromHexline(l, 1)
            let alo = getByteFromHexline(l, 2)
            let adr = (ahi shl 8) or alo
            let typ = getByteFromHexline(l, 3)
            var sum = len + alo + ahi + typ
            for i in 0 ..< len:
                let val = getByteFromHexline(l, 4+i)
                sum += val
                memory[adr+i] = uint16(val)
            let chksum = getByteFromHexline(l, 4+len)
            if ((sum + chksum) and 255) != 0:
                return false
    except:
        return false
    return true
