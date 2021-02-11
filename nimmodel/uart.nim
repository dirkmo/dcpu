import net, locks, strformat

const
    FLAG_RECEIVED = 1u16
    FLAG_SENDING = 1u16

var
    statusLock: Lock
    status {.guard: statusLock}: uint16
    sendCounterLock: Lock
    sendCounter {.guard: sendCounterLock}: uint
    rec: uint16
    send: uint16
    running = true
    serverThread: Thread[void]
    client {.threadvar.}: Socket


proc startSending(dat: uint16) =
    withLock sendCounterLock:
        send = dat
        sendCounter = 100

proc server() {.thread.} =
    echo "Server started"
    var socket = newSocket()
    socket.bindAddr(Port(7777))
    socket.listen()

    var address = ""
    while running:
        socket.acceptAddr(client, address)
        echo("Client connected from: ", address)
        client.send("Welcome on the Dcpu simulator\n")
        var s = "_"
        while s != "":
            s = client.recv(1, -1)
            if s.len() > 0:
                # stdout.write(&"{int(s[0])} ")
                # stdout.flushFile()
                # client.send(s)
                withLock statusLock:
                    if (status and FLAG_RECEIVED) == 0:
                        status = status or FLAG_RECEIVED
                        rec = uint16(s[0])
        echo "\nClient disconnected."

proc uartRead*(address: uint16): uint16 =
    case address and 0x0003:
    of 0: 
        withLock statusLock:
            return status
    of 2:
        withLock statusLock:
            status = status and not FLAG_RECEIVED
        return rec
    else: discard
    return 0

proc uartWrite*(address: uint16, dat: uint16) =
    case address and 0x0003:
    of 0: discard
    of 2: 
        withLock statusLock:
            if (status and FLAG_SENDING) == 0:
                status = status or FLAG_SENDING
                startSending(dat)
    else: discard

proc uartHandle*() =
    withLock sendCounterLock:
        if sendCounter != 0:
            sendCounter -= 1
            if sendCounter == 0:
                let s = &"{char(send)}"
                client.send(s)
                withLock statusLock:
                    status = status and not FLAG_SENDING

initLock(statusLock)
initLock(sendCounterLock)

createThread[void](serverThread, server)

echo "Waiting"
while true:
    discard
