#ifndef _UART_H
#define _UART_H

#include <stdint.h>

uint16_t uart_bus(uint16_t addr, uint16_t dat, int rw);
void uart_handle(void);


#endif
