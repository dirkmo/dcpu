import threadpool

type
    InputReader = object
        hasData: bool
        data: FlowVar[string]

var
    input: InputReader

proc hasLine*(): bool =
    return input.data.isReady()

proc getLine*(): string =
    let s = ^input.data
    input.data = spawn stdin.readLine()
    return s

input.data = spawn stdin.readLine()
