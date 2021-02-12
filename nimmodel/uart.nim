import asyncnet, asyncdispatch, strformat

const
    FLAG_RECEIVED = 1u16
    FLAG_SENDING = 2u16

    TICKS_PER_CHAR = 20

var
    dataToSend: uint16
    recBuf: seq[char]
    client: AsyncSocket
    sendCounter: uint
    init: bool = false

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
            stdout.write(line[i])
            stdout.flushFile()
    echo &"Client from disconnected."

proc sendToClient() {.async.} =
    if sendCounter > 0:
        sendCounter -= 1
        if sendCounter == 0:
            let s = &"{char(dataToSend)}"
            await client.send(s)

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
            dataToSend = dat
            sendCounter = TICKS_PER_CHAR
    else: discard

proc uartHandle*() =
    if not init:
        asyncCheck server()
        init = true
    poll(0)

proc loop() =
    if sendCounter > 0:
        asyncCheck sendToClient()
    poll()

asyncCheck server()

while true:
    loop()