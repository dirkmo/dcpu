import
    os, strformat, strutils, asyncdispatch,
    hexfile, dcpu, uart, inputreader

var
    mem: array[0..0xffff, uint8]
    simrun: bool = false
    cpu = Dcpu()

proc read(adr: uint16): uint16 =
    let wordaddr = adr and 0xfffe
    var w: uint16
    case wordaddr:
    of 0xffe0, 0xffe2:
        w = uartRead(wordaddr)
    else:
        w = uint16(mem[wordaddr])
        w = w or (uint16(mem[wordaddr+1]) shl 8)
    return w

proc write(adr, dat: uint16) =
    let wordaddr = adr and 0xfffe
    case wordaddr:
    of 0xffe0, 0xffe2:
        uartWrite(wordaddr, dat)
    else:
        mem[wordaddr] = uint8(dat)
        mem[wordaddr+1] = uint8(dat shr 8)

proc handleParams =
    let params = commandLineParams()
    if params.len() < 1:
        return
    let hexfn = params[0]
    logTerminal fmt"Reading {hexfn}", llInfo
    let success = readHexfile(hexfn, mem)
    if not success:
        logTerminal &"Failed to read {hexfn}", llError

proc loadHexfile(params: seq[string]) =
    if params.len > 1:
        let fn = params[1]
        if readHexfile(fn, mem):
            logTerminal &"Loaded {fn}", llInfo
        else:
            logTerminal &"Failed to load {fn}", llError

proc setLogLevel(params: seq[string]) =
    if params.len > 1:
        case params[1].toUpper:
        of "DEBUG": loglevel = llDebug
        of "VERBOSE": loglevel = llVerbose
        of "INFO": loglevel = llInfo
        of "ERROR": loglevel = llError
        else:
            logTerminal "Unknown loglevel", llError
    else:
        echo &"{loglevel}"
    discard

proc handleInput() =
    if not hasLine():
        return
    let input = getLine()
    let parts = input.split()
    case parts[0].toUpper():
    of "LOAD": loadHexfile(parts)
    of "QUIT", "EXIT": quit(0)
    of "RUN": simrun = true
    of "RESET": cpu.reset()
    of "LOG": setLogLevel(parts)
    else:
        if simrun:
            simrun = false
            logTerminal &"{cpu.disassemble()}", llInfo
            logTerminal "CPU stopped.", llInfo

proc main =
    handleParams()
    
    cpu.setcallbacks(read, write)
    var laststate = dsFetch
    while true:
        if simrun:
            let state = cpu.statemachine()
            if state == dsFinish:
                simrun = false
            if laststate == dsExecute:
                logTerminal cpu.dumpRegisters() & "\n", llDebug

            laststate = state
            
        handleInput()

        handleUart()

        poll(0)
        

main()
