.equ UART_ST $fffe
.equ UART_RX $ffff
.equ UART_TX $ffff
.equ SIM_END $be00

lit $44 # 'D'
lit UART_TX
a:t mem

.word SIM_END
