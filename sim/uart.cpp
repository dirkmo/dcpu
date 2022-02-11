#include <queue>
#include <stdio.h>
#include "verilated.h"
#include <verilated_vcd_c.h>
#include "Vtop_UartMasterSlave.h"
#include "uart.h"

using namespace std;

queue<uint8_t> fifo_send_to_fpga;
queue<uint8_t> fifo_receive_from_fpga;

static uint8_t *TX;
static uint8_t *RX;
static uint8_t *CLK;
static int TICK;

static int handle_uart_rx() {
    static int lastClk = 0;
    static int tick_count = 0;
    static int rxbyte = 0;
    static enum State {
        BIT0 = 0,
        STOPBIT = 8,
        IDLE = 9,
        STARTBIT = 10,
    } state = IDLE;

    int rx = *TX;
    if (1 || lastClk != *CLK) {
        lastClk = *CLK;
        if (*CLK) { // posedge
            tick_count++;
            switch( state ) {
                case IDLE:
                    if (rx == 0) {
                        tick_count = 0;
                        state = STARTBIT;
                    }
                break;
                case STARTBIT:
                    if ((tick_count > TICK/2) && (rx == 0)) {
                        rxbyte = 0;
                        tick_count = 0;
                        state = BIT0;
                    }
                break;
                case BIT0:
                default:
                    if (tick_count > TICK) {
                        rxbyte = (rxbyte >> 1) | (rx << 7);
                        tick_count = 0;
                        state = State((int)state + 1);
                    }
                break;
                case STOPBIT:
                    if (tick_count > TICK) {
                        tick_count = 0;
                        state = IDLE;
                        if (rx == 1) {
                            // byte received
                            return rxbyte;
                        } else {
                            // stopbit failure
                            return -2;
                        }
                    }
                break;
            }
        }
    }
    return -1;
}

static void handle_uart_tx(void) {
    static int lastClk = 0;
    static int tick_count = 0;
    static enum State {
        BIT0 = 0,
        STOPBIT = 8,
        IDLE = 9,
        STARTBIT = 10,
    } state = IDLE;
    if (1 || lastClk != *CLK) {
        lastClk = *CLK;
        if (*CLK) { // posedge
            tick_count++;
            switch( state ) {
                case IDLE:
                    *RX = 1;
                    if(!fifo_send_to_fpga.empty()) {
                        state = STARTBIT;
                        tick_count = 0;
                    }
                break;
                case STARTBIT:
                    *RX = 0;
                    if (tick_count > TICK) {
                        state = BIT0;
                        tick_count = 0;
                    }
                break;
                case BIT0:
                default: {
                    int dat = fifo_send_to_fpga.front();
                    *RX = (dat >> ((int)state)) & 1;
                    if (tick_count > TICK) {
                        state = (State)((int)state + 1);
                        tick_count = 0;
                    }
                }
                break;
                case STOPBIT:
                    *RX = 1;
                    if (tick_count > TICK) {
                        state = IDLE;
                        tick_count = 0;
                        fifo_send_to_fpga.pop();
                    }
                break;
            }
        }
    }
}

int uart_handle(int *rxbyte) {
    handle_uart_tx();
    int c = handle_uart_rx();
    if (c >= 0 && rxbyte) {
        *rxbyte = c;
        fifo_receive_from_fpga.push(c);
        return 1;
    }
    return 0;
}

void uart_send(int channel, const char *dat) {
    while(*dat) {
        char c = *dat | ((!!channel) << 7);
        fifo_send_to_fpga.push(c);
        dat++;
    }
}

void uart_init(uint8_t *rx, uint8_t *tx, uint8_t *clk, int tick) {
    RX = rx;
    TX = tx;
    CLK = clk;
    TICK = tick;
}
