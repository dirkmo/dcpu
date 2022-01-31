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
#include <algorithm>
#include <ncurses.h>
#include <iostream>

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

vector<uint16_t> m_breakpoints;
vector<string> m_sourceList;

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

#include <fstream>
int source_load(const char *fn) {
    ifstream in(fn);
    string s;
    while(getline(in, s)) {
        if (s.size() > 0) {
            m_sourceList.push_back(s);
        }
    }
    return 0;
}

void print_cpustate(int y, int x, Vtop *pCore) {
    uint16_t pc = pCore->top->cpu0->r_pc;
    mvprintw(y, x, "D(%d):", pCore->top->cpu0->r_dsp+1);
    if (pCore->top->cpu0->r_dsp < 15) {
        for (int i = 0; i <= pCore->top->cpu0->r_dsp; i++) {
            printw(" %x", pCore->top->cpu0->r_dstack[i]);
        }
    }
    mvprintw(y+1, x, "R(%d):", pCore->top->cpu0->r_rsp+1);
    if (pCore->top->cpu0->r_rsp < 15) {
        for (int i = 0; i <= pCore->top->cpu0->r_rsp; i++) {
            printw(" %x", pCore->top->cpu0->r_rstack[i]);
        }
    }
    mvprintw(y+2, x, "PC %04x: %s", pc, dcpu_disasm(mem[pc]));
}

void breakpoint_set(uint16_t addr) {
    auto it = find(m_breakpoints.begin(), m_breakpoints.end(), addr);
    if (it == m_breakpoints.end()) {
        printf("set breakpoint at $%04x\n", addr);
        m_breakpoints.push_back(addr);
    } else {
        printf("there is already a breakpoint at $%04x\n", addr);
    }
}

void breakpoint_delete(uint16_t addr) {
    auto it = find(m_breakpoints.begin(), m_breakpoints.end(), addr);
    if (it != m_breakpoints.end()) {
        m_breakpoints.erase(it);
        printf("Breakpoint deleted at $%04x\n", addr);
    } else {
        printf("No breakpoint set at $%04x\n", addr);
    }
}

void breakpoint_list(void) {
    printf("Breakpoints:\n");
    for (auto it: m_breakpoints) {
        printf("%04x\n", it);
    }
}

bool pc_on_breakpoint(uint16_t pc) {
    auto it = find(m_breakpoints.begin(), m_breakpoints.end(), pc);
    return it != m_breakpoints.end();
}

int user_interaction(void) {
    //char *input = readline("> ");
    getch();
    char *input = "";
    if (input == NULL) {
        return -1;
    }

    uint32_t val;
    if (strcmp(input, "run") == 0) {
        run = true;
    } else if (sscanf(input, "break %x", &val) == 1) {
        breakpoint_set(val);
    } else if (sscanf(input, "del %x", &val) == 1) {
        breakpoint_delete(val);
    } else if (strcmp(input, "list") == 0) {
        breakpoint_list();
    } else if (strlen(input) == 0) {
        return 1;
    }
    return 0;
}

void the_end(void) {
    endwin();
}

void print_source(int y, int x, int h, int w) {

}

void print_screen(void) {
    erase();
    box(stdscr, 0, 0);
    mvprintw(0, 2, " dcpu simulator ");
    print_cpustate(LINES-6, 2, pCore);
    print_source(2, 2, LINES-6-2, COLS-4);
    refresh();
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vtop();

    int uart_tick = pCore->top->uart0->SYS_FREQ / pCore->top->uart0->BAUDRATE;
    uart_init(&pCore->i_uart_rx, &pCore->o_uart_tx, &pCore->i_clk, uart_tick);

    opentrace("trace.vcd");

    printf("dcpu simulator\n\n");
    if (argc < 3) {
        fprintf(stderr, "Missing file names\n");
        return -1;
    }
    
    if (program_load(argv[1], 0)) {
        fprintf(stderr, "ERROR: Failed to load file '%s'\n", argv[1]);
        return -2;
    }

    if (source_load(argv[2])) {
        fprintf(stderr, "ERROR: Failed to sim file '%s'\n", argv[2]);
        return -3;
    }

    reset();

    initscr();
    atexit(the_end);

    run = false;
    int rxbyte;
    int step = 0;
    while(step < 500 && !Verilated::gotFinish()) {
        if(handle(pCore)) {
            break;
        }
        if (uart_handle(&rxbyte)) {
            printw(GREEN "UART-RX: " NORMAL "%c\n", rxbyte);
        }
        if (pCore->top->cpu0->w_sim_next) {
            print_screen();
            if (pc_on_breakpoint(pCore->top->cpu0->r_pc)) {
                printw("Stopped on breakpoint\n");
                run = false;
            }
            while (!run) {
                int ret = user_interaction();
                if (ret == -1) {
                    goto finish;
                } else if (ret == 1) {
                    break;
                }
            }
        }
        tick(3);
        step++;
    }

finish:
    if(Verilated::gotFinish()) {
        printw("Simulation finished\n");
    }

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }
    return 0;
}