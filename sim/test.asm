.equ UART_ST $fffe
.equ UART_RX $ffff
.equ UART_TX $ffff

lit $44 # 'D'
lit UART_TX
a:t mem
