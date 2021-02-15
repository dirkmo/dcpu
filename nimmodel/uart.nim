import asyncnet, asyncdispatch, strformat, terminal

const
    FLAG_RECEIVED = 1u16
    FLAG_SENDING = 2u16

    TICKS_PER_CHAR = 10

var
    dataToSend: uint8
    recBuf: seq[char]
    client: AsyncSocket
    sendCounter: uint

proc coloredWrite(s: string, fg: ForegroundColor = fgDefault, bg: BackgroundColor =bgDefault) =
    setForegroundColor(fg)
    setBackgroundColor(bg)
    stdout.write(s)
    resetAttributes()

proc getStatus(): uint16 =
    let flagReceived: uint16 = if recBuf.len > 0: FLAG_RECEIVED else: 0
    let flagSending: uint16 = if sendCounter > 0: FLAG_SENDING else: 0
    return flagReceived or flagSending

proc receiveFromClient() {.async.} =
    let (inetAddr, port) = client.getPeerAddr()
    echo &"Client connected from {inetAddr}:{uint(port)}"
    while true:
        let line = await client.recvLine()
        if line.len == 0: break
        for i in 0 ..< line.len:
            recBuf.add(line[i])
        coloredWrite(line, fgMagenta)
        stdout.flushFile()
    echo &"Client disconnected."

proc sendToClient() =
    if sendCounter > 0:
        sendCounter -= 1
        if sendCounter == 0:
            let s = &"{char(dataToSend)}"
            if client != nil:
                discard client.send(s)
            else:
                coloredWrite(s, fgMagenta)
                stdout.flushFile()

proc server() {.async.} =
    echo "Server started"
    var serverSocket = newAsyncSocket()
    serverSocket.setSockOpt(OptReuseAddr, true)
    serverSocket.bindAddr(Port(7777))
    serverSocket.listen()
    while true:
        client = await serverSocket.accept()
        asyncCheck receiveFromClient()

proc uartRead*(address: uint16): uint16 =
    case address and 0x0003:
    of 0: return getStatus()
    of 2: # return received char
        if recBuf.len > 0:
            let rec = uint16(recBuf[0])
            recBuf.delete(0)
            return rec
    else: discard
    return 0

proc uartWrite*(address: uint16, dat: uint16) =
    case address and 0x0003:
    of 0: discard # status not writable
    of 2:  # start sending char if idle
        if sendCounter == 0:
            dataToSend = uint8(dat)
            sendCounter = TICKS_PER_CHAR
            # echo &"Sending: {char(dat)}"
        else:
            echo &"Cannot send {char(dat)}"
    else: discard

proc handleUart*() =
    sendToClient()

asyncCheck server()

system.addQuitProc(resetAttributes)