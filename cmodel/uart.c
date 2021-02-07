#include "uart.h"
#include <stdbool.h>
#include <sys/types.h>
#include <sys/socket.h>

#define UART_ST 0
#define UART_RX 2
#define UART_TX 2
#define FLAG_RX 1 // if set: char received
#define FLAG_TX 2 // if set: uart sending

static uint16_t status = 0;
static uint16_t rec = 0;
static uint16_t send = 0;

void mod_status(uint16_t flag, bool en) {
    if (en) {
        status |= flag;
    } else {
        status &= ~flag;
    }
}

uint16_t read_status(void) {
    return status;
}

uint16_t uart_bus(uint16_t addr, uint16_t dat, int rw) {
    if (rw) {
        // read
        switch(addr) {
            case UART_ST: return read_status();
            case UART_RX: {
                uint16_t r = rec;
                rec = 0;
                mod_status(FLAG_RX, false);
                return r;
            }
            default:;
        }
    } else {
        // write
        switch(addr) {
            case UART_TX: {
                if ((read_status() & FLAG_TX) == 0) {
                    send = dat;
                    mod_status(FLAG_TX, true);
                }
            }
            default:;
        }
    }
    return 0;
}

void uart_handle(void) {
    static int fd = -1;
    if (fd == -1) {
        fd = socket(AF_INET, int type, int protocol);
    }
}