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
#include <fstream>


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

#define MSGAREA_W 40

VerilatedVcdC *pTrace = NULL;
Vtop *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;
bool run = false;

uint16_t mem[0x10000];

vector<uint16_t> vBreakPoints;
vector<string> vSourceList;
vector<string> vMessages;
string sUserInput;


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

int source_load(const char *fn) {
    ifstream in(fn);
    string s;
    while(getline(in, s)) {
        if (s.size() > 0) {
            vSourceList.push_back(s);
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

#include <sstream>
void breakpoint_set(uint16_t addr) {
    auto it = find(vBreakPoints.begin(), vBreakPoints.end(), addr);
    stringstream ss;
    ss << hex << addr;
    if (it == vBreakPoints.end()) {
        vBreakPoints.push_back(addr);
        vMessages.push_back(string("Set breakpoint at $") + ss.str());
    } else {
        vBreakPoints.erase(it);
        vMessages.push_back(string("Breakpoint deleted at $") + ss.str());
    }
}

void breakpoint_list(void) {
    vMessages.push_back("Breakpoints:");
    for (auto it: vBreakPoints) {
        stringstream ss;
        ss << hex << it;
        vMessages.push_back(string("$") + ss.str());
    }
}

bool pc_on_breakpoint(uint16_t pc) {
    auto it = find(vBreakPoints.begin(), vBreakPoints.end(), pc);
    return it != vBreakPoints.end();
}

int user_interaction(void) {
    int key = getch();
    switch(key) {
        case 4: // fall-through
        case 27: return -1;
        case KEY_F(5): run = true; return 0;
        case KEY_F(6): /*un-/set breakpoint */ return 0;
        case KEY_DOWN: /*step over*/ return 0;
        case KEY_LEFT: /*step into*/ return 0;
        case KEY_BACKSPACE: // fall-through
        case 127: if (sUserInput.size()>0) sUserInput.pop_back(); return 0;
        case 10: // fall-through
        case KEY_ENTER: break;
        case KEY_RESIZE: return 0; // window resize
        default:
            sUserInput += (char)key;
            return 0;
    }

    uint32_t val;
    if (sUserInput.size() == 0) {
        return 1;
    } else if (sUserInput == "run") {
        run = true;
    } else if (sscanf(sUserInput.c_str(), "break %x", &val) == 1) {
        breakpoint_set(val);
    } else if (sUserInput == "list") {
        breakpoint_list();
    } else if (sUserInput == "reset") {

    }
    sUserInput = "";
    return 0;
}

void the_end(void) {
    endwin();
}

uint16_t pc_from_simline(string s) {
    uint16_t pc = stoi(s.substr(0, 4), nullptr, 16);
    return pc;
}

void print_source(int y, int x, int h, int w, uint16_t pc) {
    char buf[16];
    sprintf(buf, "%04x", pc);
    string sPc(buf);
    int i = 0;
    int start = -1;
    int end = -1;
    for (auto it: vSourceList) {
        if (it.compare(0, 4, buf) == 0) {
            if (start == -1) {
                start = i;
            }
            end = i;
        } else {
            if (end != -1) {
                break;
            }
        }
        i++;
    }
    
    int mid = start + (end - start) / 2;
    int tl = mid - h/2;
    int y1 = max(tl, 0);
    if (y1 + h >= vSourceList.size()) {
        if (y1+h-vSourceList.size() >= 0) {
            y1 = vSourceList.size() - h;
        }
    }
    for (i = 0; i < h; i++) {
        if (y1+i < vSourceList.size()) {
            string s = vSourceList[y1+i].substr(0, w-1);
            bool bpline = pc_on_breakpoint(pc_from_simline(vSourceList[y1+i]));
            if (y1+i >= start && y1+i <= end) {
                // PC here
                attron(COLOR_PAIR(bpline ? 4 : 2));
            } else {
                attron(COLOR_PAIR(bpline ? 3 : 1));
            }
            mvprintw(y+i, x, s.c_str());
        }
    }
    attron(COLOR_PAIR(1));
}

void print_messages(int y1, int x1, int h, int w) {
    for (int i = 0; i < h; i++) {
        if (i >= vMessages.size()) {
            break;
        }
        string s = vMessages[vMessages.size()-i-1];
        mvprintw(y1+h-1-i, x1, s.substr(0,w-1).c_str());
    }
}

void print_screen(void) {
    erase();
    box(stdscr, 0, 0);
    mvprintw(0, 2, " dcpu simulator ");
    print_source(1, 2, LINES-7-1, COLS-MSGAREA_W, pCore->top->cpu0->r_pc);
    
    for (int y = 1; y < LINES-7; y++) {
        mvprintw(y, COLS-MSGAREA_W, "|");
    }
    print_messages(1, COLS-MSGAREA_W+2, LINES-1-7, MSGAREA_W-2);
    print_cpustate(LINES-6, 2, pCore);
    for (int x = 1; x < COLS-2; x++) {
        mvprintw(LINES-7, x, "-");
        mvprintw(LINES-3, x, "-");
    }
    string s = "> " + sUserInput;
    mvprintw(LINES-2, 2, s.c_str());
    refresh();
}

int main(int argc, char *argv[]) {
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
        fprintf(stderr, "ERROR: Failed to load sim file '%s'\n", argv[2]);
        return -3;
    }

    Verilated::traceEverOn(true);
    pCore = new Vtop();

    int uart_tick = pCore->top->uart0->SYS_FREQ / pCore->top->uart0->BAUDRATE;
    uart_init(&pCore->i_uart_rx, &pCore->o_uart_tx, &pCore->i_clk, uart_tick);

    opentrace("trace.vcd");

    reset();

    initscr();
    atexit(the_end);
    start_color();
    init_pair(1, COLOR_WHITE, COLOR_BLACK);
    init_pair(2, COLOR_BLACK, COLOR_WHITE);
    init_pair(3, COLOR_RED, COLOR_BLACK);
    init_pair(4, COLOR_RED, COLOR_WHITE);
    attron(COLOR_PAIR(1));
    keypad(stdscr, TRUE);
    noecho();

    vMessages.push_back("Welcome to DCPU Simulator");

    run = false;
    int rxbyte;
    int step = 0;
    while(1) {
        if(handle(pCore)) {
            break;
        }
        if (uart_handle(&rxbyte)) {
            printw(GREEN "UART-RX: " NORMAL "%c\n", rxbyte);
        }
        if (pCore->top->cpu0->w_sim_next) {
            print_screen();
            if (pc_on_breakpoint(pCore->top->cpu0->r_pc)) {
                vMessages.push_back("Stopped on breakpoint\n");
                run = false;
            }
            while (!run) {
                int ret = user_interaction();
                print_screen();
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