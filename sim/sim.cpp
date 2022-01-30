#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vtop.h"
#include "Vtop_top.h"
#include "Vtop_dcpu.h"
#include "Vtop_UartMasterSlave.h"
#include "dcpu.h"
#include "uart.h"
#include <vector>
#include <readline/readline.h>

using namespace std;

#define ARRSIZE(a) (sizeof(a) / sizeof(a[0]))
#define BLACK "\033[30m"
#define RED "\033[31m"
#define GREEN "\033[32m"
#define ORANGE "\033[33m"
#define BLUE "\033[34m"
#define PINK "\033[35m"
#define CYAN "\033[36m"
#define GREY "\033[37m"
#define NORMAL "\033[0m"

VerilatedVcdC *pTrace = NULL;
Vtop *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;
bool run = false;

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick(int t = 3) {
    if (t&1) {
        pCore->i_clk = 0;
        pCore->eval();
        if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
        tickcount += ts / 2;
    }
    if (t&2) {
        pCore->i_clk = 1;
        pCore->eval();
        if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
        tickcount += ts / 2;
    }
}

void reset() {
    pCore->i_reset = 1;
    pCore->i_dat = 0;
    pCore->i_ack = 0;
    tick();
    pCore->i_reset = 0;
}

uint16_t mem[0x10000];

int handle(Vtop *pCore) {
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
            printf("write [%04x] <- %04x\n", pCore->o_addr, pCore->o_dat);
        }
        if (pCore->i_dat == 0xffff && (pCore->top->cpu0->r_state == 0)) {
            return 1;
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
    return 0;
}

int program_load(const char *fn, uint16_t offset) {
    for (int i = 0; i < 0x10000; mem[i++] = OP_SIM_END);
    FILE *f = fopen(fn, "rb");
    if (!f) {
        fprintf(stderr, "Failed to open file\n");
        return -1;
    }
    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    if (size % 2) {
        fprintf(stderr, "Odd program size!\n");
        return -2;
    }
    fseek(f, 0, SEEK_SET);
    for (int i = 0; i < size/2; i++) {
        uint16_t word;
        fread(&word, sizeof(uint16_t), 1, f);
        mem[offset+i] = (word >> 8) | ((word & 0xff) << 8);
    }
    fclose(f);
    return 0;
}

void print_cpustate(Vtop *pCore) {
    uint16_t pc = pCore->top->cpu0->r_pc;
    printf("D(%d):", pCore->top->cpu0->r_dsp+1);
    if (pCore->top->cpu0->r_dsp < 15) {
        for (int i = 0; i <= pCore->top->cpu0->r_dsp; i++) {
            printf(" %x", pCore->top->cpu0->r_dstack[i]);
        }
    }
    printf("\n");
    printf("R(%d):", pCore->top->cpu0->r_rsp+1);
    if (pCore->top->cpu0->r_rsp < 15) {
        for (int i = 0; i <= pCore->top->cpu0->r_rsp; i++) {
            printf(" %x", pCore->top->cpu0->r_rstack[i]);
        }
    }
    printf("\n");
    printf("PC %04x: %s\n\n", pc, dcpu_disasm(mem[pc]));
}

int user_interaction(void) {
    char *input = readline("> ");
    if (strcmp(input, "run") == 0) {
        run = true;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vtop();

    int uart_tick = pCore->top->uart0->SYS_FREQ / pCore->top->uart0->BAUDRATE;
    uart_init(&pCore->i_uart_rx, &pCore->o_uart_tx, &pCore->i_clk, uart_tick);

    opentrace("trace.vcd");

    printf("dcpu simulator\n\n");
    if (argc < 2) {
        fprintf(stderr, "Missing file name\n");
        return -1;
    }
    
    if (program_load(argv[1], 0)) {
        fprintf(stderr, "ERROR: Failed to load file '%s'\n", argv[1]);
        return -2;
    }

    reset();
    run = true;
    print_cpustate(pCore);
    int rxbyte;
    int step = 0;
    while(step < 500 && !Verilated::gotFinish()) {
        if (!run) {
            user_interaction();
        }
        if(handle(pCore)) {
            break;
        }
        if (uart_handle(&rxbyte)) {
            printf(GREEN "UART-RX: " NORMAL "%c\n", rxbyte);
        }
        if (pCore->top->cpu0->s_fetch && pCore->top->cpu0->w_state_changed) {
            print_cpustate(pCore);
        }
        tick(3);
        step++;
    }

    if(Verilated::gotFinish()) {
        printf("Simulation finished\n");
    } else {
        printf("Out of steps\n");
    }

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }
    return 0;
}