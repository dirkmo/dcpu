#ifndef _UART_H
#define _UART_H

#include <stdint.h>

int uart_handle(int *rxbyte);
void uart_send(int channel, const char *dat);
void uart_init(uint8_t *rx, uint8_t *tx, uint8_t *clk, int tick);

#endif
