#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vdcpu.h"
#include "Vdcpu_dcpu.h"
#include "dcpu.h"
#include <vector>
#include <list>
#include <algorithm>
#include <ncurses.h>
#include <iostream>
#include <fstream>
#include <sstream>


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

enum user_action {
    UA_NONE,
    UA_QUIT,
    UA_STEP,
};

VerilatedVcdC *pTrace = NULL;
Vdcpu *pCore;

uint64_t tickcount = 0;
uint64_t clockcycle_ps = 10000; // clock cycle length in ps
bool run = false;

uint16_t mem[0x10000];

vector<uint16_t> vBreakPoints;
vector<uint16_t> vSilentBreakPoints;
vector<string> vSourceList;
vector<string> vMessages;
string sUserInput;

list<char> l_sim2dcpu;
list<char> l_dcpu2sim;

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    pCore->i_clk = !pCore->i_clk;
    tickcount += clockcycle_ps / 2;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void reset() {
    pCore->i_reset = 1;
    pCore->i_dat = 0;
    pCore->i_ack = 0;
    pCore->i_clk = 1;
    tick();
    tick();
    pCore->i_reset = 0;
}

int handle(Vdcpu *pCore) {
    static uint16_t last_addr = 0xffff;
    if (pCore->o_cs) {
        if (pCore->o_addr < 0xfffe) {
            // memory
            pCore->i_dat = mem[pCore->o_addr];
            if (pCore->o_we && pCore->i_clk) {
                mem[pCore->o_addr] = pCore->o_dat;
                char s[32];
                sprintf(s, "write [%04x] <- %04x", pCore->o_addr, pCore->o_dat);
                vMessages.push_back(string(s));
            }
        } else {
            // pseudo-uart
            if (pCore->o_we) {
                if (pCore->o_addr == 0xffff) {
                    l_dcpu2sim.push_back(pCore->o_dat);
                    printw(GREEN "UART-RX: " NORMAL "%c\n", pCore->o_dat);
                }
            } else {
                switch(pCore->o_addr) {
                    case 0xffff: { // rx/tx reg
                        if (!l_sim2dcpu.empty()) {
                            if (last_addr != pCore->o_addr) {
                                pCore->i_dat = l_sim2dcpu.front();
                                l_sim2dcpu.pop_front();
                            }
                        }
                    }
                    break;
                    case 0xfffe: // status reg
                        pCore->i_dat = !l_sim2dcpu.empty();
                        break;
                    default: break;
                }
            }
        }

    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
    last_addr = pCore->o_addr;
    return pCore->dcpu->w_op_sim_end != 0;
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

void print_cpustate(int y, int x, Vdcpu *pCore) {
    uint16_t pc = pCore->dcpu->r_pc;
    mvprintw(y, x, "D(%d):", pCore->dcpu->r_dsp+1);
    if (pCore->dcpu->r_dsp < 15) {
        for (int i = 0; i <= pCore->dcpu->r_dsp; i++) {
            printw(" %x", pCore->dcpu->r_dstack[i]);
        }
    }
    mvprintw(y+1, x, "R(%d):", pCore->dcpu->r_rsp+1);
    if (pCore->dcpu->r_rsp < 15) {
        for (int i = 0; i <= pCore->dcpu->r_rsp; i++) {
            printw(" %x", pCore->dcpu->r_rstack[i]);
        }
    }
    mvprintw(y+2, x, "PC %04x: %s", pc, dcpu_disasm(mem[pc]));
}

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

bool pc_on_silent_breakpoint(uint16_t pc) {
    auto it = find(vSilentBreakPoints.begin(), vSilentBreakPoints.end(), pc);
    bool onbp = it != vSilentBreakPoints.end();
    if (onbp) vSilentBreakPoints.erase(it);
    return onbp;
}

void step_over(void) {
    const uint16_t pc = pCore->dcpu->r_pc;
    const uint16_t opcode = mem[pc];
    const uint16_t mask = 0xe000 | DST(3);
    const uint16_t value = OP_ALU | DST(DST_PC);
    bool isCall = ((opcode & 0x8000) == OP_CALL);
    isCall |= (opcode & mask) == value; // call via alu
    if (isCall) {
        vSilentBreakPoints.push_back(pc+1);
        run = true;
    }
}

char printable(char c) {
    return (isprint(c)) ? c : '.';
}

void dump(uint16_t addr, int len) {
    char s[MSGAREA_W+1];
    char ss[16];
    memset(s, 0, sizeof(s));
    memset(ss, 0, sizeof(ss));
    int i;
    for (i = 0; i < len; i++) {
        if ((i%4) == 0) {
            sprintf(s+(i%4)*5, "%04x: ", addr+i);
        }
        sprintf(s+(i%4)*5+6, "%04x ", mem[addr+i]);
        sprintf(ss+(i*2%8), "%c%c", printable(mem[addr+i] >> 8), printable(mem[addr+i] & 0xff) );
        if ((i%4) == 3) {
            vMessages.push_back(string(s) + string(ss));
            memset(s, 0, sizeof(s));
            memset(ss, 0, sizeof(ss));
        }
    }
    if (strlen(s) > 0) {
        vMessages.push_back(string(s) + string(ss));
    }
}

void send_via_uart(string s) {
    int p1 = s.find("\"");
    if (p1 == string::npos) {
        return;
    }
    int p2 = s.find("\"", p1+1);
    if (p2 == string::npos) {
        return;
    }
    s = s.substr(p1+1, p2-p1-1);
    vMessages.push_back(string("uart-tx: ") + "'" + s + "'");
    for (char c : s) {
        l_sim2dcpu.push_back(c);
    }
    l_sim2dcpu.push_back('\r');
}

enum user_action user_interaction(void) {
    int key = getch();
    switch(key) {
        case 4: // fall-through
        case 27: return UA_QUIT;
        case KEY_F(5): run = true; return UA_NONE;
        case KEY_F(6): breakpoint_set(pCore->dcpu->r_pc); return UA_NONE;
        case KEY_DOWN: step_over(); return UA_STEP;
        case KEY_RIGHT: /*step into*/ return UA_STEP;
        case KEY_BACKSPACE: // fall-through
        case 127: if (sUserInput.size()>0) sUserInput.pop_back(); return UA_NONE;
        case 10: // fall-through
        case KEY_ENTER: break;
        case KEY_RESIZE: return UA_NONE; // window resize
        default:
            sUserInput += (char)key;
            return UA_NONE;
    }

    uint32_t val, val2 = 0xffffffff;
    if (sUserInput.size() == 0) {
        return UA_STEP; // step into
    } else if (sUserInput == "run") {
        run = true;
    } else if (sscanf(sUserInput.c_str(), "break %x", &val) == 1) {
        breakpoint_set(val);
    } else if (sUserInput == "list") {
        breakpoint_list();
    } else if (sUserInput == "reset") {
        reset();
    } else if (sscanf(sUserInput.c_str(), "dump %x %d", &val, &val2) > 0) {
        if (val2 > 256) {
            val2 = 16;
        }
        dump(val, val2);
    } else if (strstr(sUserInput.c_str(), "uart") != NULL) {
        send_via_uart(sUserInput);
    }
    sUserInput = "";
    return UA_NONE;
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
        mvprintw(y1+h-1-i, x1, s.substr(0,w).c_str());
    }
}

void print_screen(void) {
    erase();
    box(stdscr, 0, 0);
    mvprintw(0, 2, " dcpu simulator ");
    print_source(1, 2, LINES-7-1, COLS-MSGAREA_W, pCore->dcpu->r_pc);

    for (int y = 1; y < LINES-7; y++) {
        mvprintw(y, COLS-MSGAREA_W, "|");
    }
    print_messages(1, COLS-MSGAREA_W+2, LINES-1-7, MSGAREA_W-3);
    print_cpustate(LINES-6, 2, pCore);
    for (int x = 1; x < COLS-2; x++) {
        mvprintw(LINES-7, x, "-");
        mvprintw(LINES-3, x, "-");
    }
    string s = "> " + sUserInput;
    mvprintw(LINES-2, 2, s.c_str());
    refresh();
}

int kbhit(void) {
    nodelay(stdscr, TRUE);
    int ch = getch();
    if (ch != ERR) {
        ungetch(ch);
    }
    nodelay(stdscr, FALSE);
    return (ch != ERR);
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
    pCore = new Vdcpu();

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

    for (auto c: string("-$123\r")) {
        l_sim2dcpu.push_back(c);
    }

    run = false;
    int rxbyte;
    uint16_t pc = 0;
    while(1) {
        if(handle(pCore)) {
            vMessages.push_back("Simulation ended.");
            run = false;
        }
        pc = pCore->dcpu->r_pc;
        if (pCore->dcpu->w_sim_next && pCore->i_clk) {
            print_screen();
            if (pc_on_breakpoint(pc)) {
                vMessages.push_back("Stopped on breakpoint");
                run = false;
            }
            if (pc_on_silent_breakpoint(pc) || kbhit()) {
                run = false;
            }
            while (!run) {
                print_screen();
                enum user_action ret = user_interaction();
                print_screen();
                if (ret == UA_QUIT) {
                    goto finish;
                } else if (ret == UA_STEP) {
                    break;
                }
            }
        }
        tick();
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