import
    os, strformat, strutils, asyncdispatch, sequtils,
    hexfile, dcpu, uart, inputreader

type
    RunModes = enum
        rmStop, rmRun, rmStep

var
    mem: array[0..0xffff, uint8]
    breakpoints: seq[uint16]
    cpu = Dcpu()
    runMode: RunModes = rmStop

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

proc breakpoint(params: seq[string]) =
    case params.len():
    of 1: # list break points
        echo "Breakpoints:"
        for idx,b in breakpoints:
            echo &"{idx}: ${b:04x}"
    of 2: # set breakpoint if address
        if params[1].toUpper == "CLEAR":
            breakpoints.delete(0, breakpoints.len()-1)
            echo "Breakpoints clear"
        else:
            try:
                let a = uint16(parseHexInt(params[1]))
                breakpoints.add(a)
                echo &"Added breakpoint at ${a:04x}"
            except:
                echo "Invalid hex address"
    of 3:
        if params[1].toUpper() == "DEL":
            try:
                let idx = parseInt(params[2])
                breakpoints.del(idx)
                echo &"Breakpoint {idx} deleted."
            except:
                echo "Invalid index"
        else: echo "Error."
    else:
        echo "Too many arguments"
    echo ""

proc dumpRegisters(cpu: Dcpu): string =
    let s = &"pc={cpu.pc:04x} t={cpu.t:04x} n={cpu.n:04x} a={cpu.a:04x} dsp={cpu.dsp:04x} asp={cpu.asp:04x} usp={cpu.usp:04x} status={cpu.status:02x}"
    return s

proc dumpMem(params: seq[string]) =
    var a, l: uint16
    var error = true
    case params.len():
    of 2,3:
        try:
            a = uint16(params[1].parseHexInt())
            error = false
        except: discard
        try: l = uint16(params[2].parseHexInt())
        except: l = 16
    else: discard

    if error:
        echo "Usage: dump <addr> [len]  ; numbers are in hex"
    else:
        for ad in a..(a+l-1):
            if (ad mod 16) == (a mod 16):
                stdout.write(&"{ad:04x}: ")
            stdout.write(&"{mem[ad]:02x} ")
            if (ad mod 16) == ((a+15) mod 16):
                stdout.write("\n")    
    echo ""

proc step(): DcpuState =
    var state = dsReset
    while true:
        state = cpu.statemachine()
        case state:
        of dsReset: discard
        of dsFetch: discard
        of dsExecute:
            logTerminal cpu.dumpRegisters() & "\n", llInfo
            break
        of dsFinish:
            runMode = rmStop
            logTerminal &"Simulator stop at ${cpu.pc:04x}", llInfo
            break
        of dsError:
            runMode = rmStop
            break

    return state


proc handleInput() =
    if not hasLine():
        return
    let input = getLine()
    if input == "": # convenience: step on enter
        discard step()
    let parts = input.split()
    case parts[0].toUpper():
    of "LOAD": loadHexfile(parts)
    of "QUIT", "EXIT": quit(0)
    of "RUN": runMode = rmRun
    of "RESET": cpu.reset()
    of "LOG": setLogLevel(parts)
    of "STEP": discard step()
    of "BREAK": breakpoint(parts)
    of "REGS": echo cpu.dumpRegisters()
    of "DUMP": dumpMem(parts)
    else:
        if runMode == rmRun:
            runMode = rmStop
            logTerminal &"{cpu.disassemble()}", llInfo
            logTerminal "CPU stopped.", llInfo
    
    stdout.write(&"${cpu.lastPc():04X}: {cpu.disassemble()}\n> ")
    stdout.flushFile()


proc main =
    handleParams()
    
    cpu.setcallbacks(read, write)

    while true:
        if runMode == rmRun:
            if cpu.lastPc() in breakpoints:
                echo "Stopped at breakpoint"
                runMode = rmStop
            else:
                discard step()
            
        handleInput()

        handleUart()
        poll(if runMode == rmRun: 0 else: 100)
        

main()
