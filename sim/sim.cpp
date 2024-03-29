#include <unistd.h>
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
#include <map>
#include <set>
#include <algorithm>
#include <ncurses.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <readline/readline.h>
#include <readline/history.h>


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

enum mode {
    MODE_SIM = 0,
    MODE_REPL = 1
} mode;

enum user_action {
    UA_NONE,
    UA_QUIT,
    UA_STEP,
    UA_REPL
};

VerilatedVcdC *pTrace = NULL;
Vdcpu *pCore;

uint64_t tickcount = 0;
uint64_t clockcycle_ps = 10000; // clock cycle length in ps
bool run = false;

uint16_t mem[0x10000];

set<uint16_t> setBreakPoints;
set<uint16_t> setSilentBreakPoints;
vector<string> vSourceList;
vector<string> vMessages;
map<string, uint16_t> mapSymbols;
string sUserInput;

uint16_t word_key_address = 0;
list<char> l_sim2dcpu;
string s_dcpu2sim;


void suspend_ncurses(void) {
    def_prog_mode();
    echo();
    endwin();
}

void resume_ncurses(void) {
    reset_prog_mode();
    refresh();
}

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
                if ((pCore->o_addr == 0xffff) && (pCore->o_addr != last_addr)) {
                    s_dcpu2sim += pCore->o_dat;
                    if ((pCore->o_dat == '\r' || pCore->o_dat == '\n')) {
                        vMessages.push_back(s_dcpu2sim);
                        s_dcpu2sim = "";
                    }
                    if(mode == MODE_REPL) {
                        printf("%c", pCore->o_dat);
                    }
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

int source_load(string fn) {
    ifstream in(fn);
    if (!in.good()) {
        return -1;
    }
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
    auto it = find(setBreakPoints.begin(), setBreakPoints.end(), addr);
    stringstream ss;
    ss << hex << addr;
    if (it == setBreakPoints.end()) {
        setBreakPoints.insert(addr);
        vMessages.push_back(string("Set breakpoint at $") + ss.str());
    } else {
        setBreakPoints.erase(it);
        vMessages.push_back(string("Breakpoint deleted at $") + ss.str());
    }
}

int symbol_breakpoint_set(const char *symbol) {
    uint16_t addr;
    if (mapSymbols.find(symbol) != mapSymbols.end()) {
        addr = mapSymbols[symbol];
        breakpoint_set(addr);
        return 0;
    }
    return 1;
}

void breakpoint_list(void) {
    vMessages.push_back("Breakpoints:");
    for (auto it: setBreakPoints) {
        stringstream ss;
        ss << hex << it;
        vMessages.push_back(string("$") + ss.str());
    }
}

bool pc_on_breakpoint(uint16_t pc) {
    auto it = find(setBreakPoints.begin(), setBreakPoints.end(), pc);
    return it != setBreakPoints.end();
}

bool pc_on_silent_breakpoint(uint16_t pc) {
    auto it = find(setSilentBreakPoints.begin(), setSilentBreakPoints.end(), pc);
    bool onbp = it != setSilentBreakPoints.end();
    if (onbp) setSilentBreakPoints.erase(it);
    return onbp;
}

void step_over(void) {
    const uint16_t pc = pCore->dcpu->r_pc;
    const uint16_t opcode = mem[pc];
    const uint16_t mask = 0xe000 | DST(3) | RSP(3);
    const uint16_t value = OP_ALU | DST(DST_PC) | RSP(RSP_RPC);
    bool isCall = ((opcode & 0x8000) == OP_CALL);
    isCall |= (opcode & mask) == value; // call via alu
    if (isCall) {
        setSilentBreakPoints.insert(pc+1);
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
    s = s.substr(1);
    vMessages.push_back(string("uart-tx: ") + "'" + s + "'");
    for (char c : s) {
        l_sim2dcpu.push_back(c);
    }
    l_sim2dcpu.push_back('\r');
}

void displaySymbol(string symbol) {
    if (mapSymbols.find(symbol) != mapSymbols.end()) {
        uint16_t address = mapSymbols[symbol];
        int len = symbol.length() + 32;
        char buf[len];
        sprintf(buf, "%s (address $%x) = $%x", symbol.c_str(), address, mem[address]);
        vMessages.push_back(string(buf));
    }
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
    char buf[128];
    if (sUserInput.size() == 0) {
        return UA_STEP; // step into
    } else if (sUserInput == "run") {
        run = true;
    } else if (sscanf(sUserInput.c_str(), "break %s", buf) == 1) {
        if (symbol_breakpoint_set(buf)) {
            val = strtol(buf, nullptr, 0);
            breakpoint_set(val);
        }
    } else if (sUserInput == "list") {
        breakpoint_list();
    } else if (sUserInput == "reset") {
        reset();
    } else if (sscanf(sUserInput.c_str(), "dump %x %d", &val, &val2) > 0) {
        if (val2 > 256) {
            val2 = 16;
        }
        dump(val, val2);
    } else if (sUserInput[0]=='"') {
        send_via_uart(sUserInput);
    } else if (sUserInput == "repl") {
        suspend_ncurses();
        mode = MODE_REPL;
        sUserInput = "";
        return UA_REPL;
    } else {
        // Try to find symbol, fetch and show value
        displaySymbol(sUserInput);
    }
    sUserInput = "";
    return UA_NONE;
}

void the_end(void) {
    if (mode == MODE_SIM) {
        endwin();
    }
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

string getbasename(string asm_fn) {
    int pos = asm_fn.rfind(".");
    return asm_fn.substr(0, pos);
}

int symbols_load(string sym_fn) {
    ifstream in(sym_fn);
    if (!in.good()) {
        return -1;
    }
    string s;

    while(getline(in, s)) {
        if (s.size() > 0) {
            int pos = s.find(" ");
            string name = s.substr(0, pos);
            uint16_t value = stoi(s.substr(pos+1), nullptr, 0);
            mapSymbols[name] = value;
        }
    }
    if (mapSymbols.find("_key") != mapSymbols.end()) {
        word_key_address = mapSymbols["_key"];
    }
    return 0;
}

int forth_waits_for_input(void) {
    if ((mode != MODE_REPL) || (word_key_address == 0) || (word_key_address != pCore->dcpu->r_pc)) {
        return 0;
    }
    return l_sim2dcpu.empty();
}

string repl_prompt(void) {
    constexpr int stacksize = (1 << pCore->dcpu->DSS);
    char buf[64];
    string s;
    // the repl waits for input when the Forth is on the start address of the _key function.
    // At that time, the top stack element is a TIB address, used by _accept, which is hidden here.
    // Below that element is the user data.
    constexpr int n = 3;
    for (int i = 0; i < n; i++) {
        int idx = (pCore->dcpu->r_dsp-n+i) % stacksize;
        sprintf(buf, "%x ", pCore->dcpu->r_dstack[idx]);
        s += buf;
    }
    return s + ">";
}

int parse_cmdline(int argc, char *argv[]) {
    int c;
    mode = MODE_SIM;
    bool loaded = false;
    while ((c = getopt(argc, argv, "i:b:r")) != -1) {
        switch (c) {
            case 'i': {
                printf("Load image '%s'\n", optarg);
                if (program_load(optarg, 0)) {
                    fprintf(stderr, "ERROR: Failed to load file '%s'\n", optarg);
                    return -1;
                }
                string basename = getbasename(optarg);
                string sim_fn = basename + ".sim";
                string sym_fn = basename + ".symbols";
                printf("Load sim file '%s'\n", sim_fn.c_str());
                if (source_load(sim_fn)) {
                    fprintf(stderr, "ERROR: Failed to load sim file '%s'\n", sim_fn.c_str());
                    return -2;
                }
                printf("Load symbol file '%s'\n", sym_fn.c_str());
                if (symbols_load(sym_fn)) {
                    fprintf(stderr, "ERROR: Failed to load sym file '%s'\n", sym_fn.c_str());
                    return -3;
                }
                loaded = true;
                break;
            }
            case 'b':
                printf("Set breakpoint at symbol '%s'\n", optarg);
                symbol_breakpoint_set(optarg);
                break;
            case 'r': // repl mode
                mode = MODE_REPL;
                break;
            default: ;
        }
    }
    return !loaded;
}

int main(int argc, char *argv[]) {
    printf("dcpu simulator\n\n");

    if (parse_cmdline(argc, argv)) {
        fprintf(stderr, "%s <-i image> [-b symbol] [-repl]\n", argv[0]);
        fprintf(stderr, "  -i <image>      path to image (.bin)\n");
        fprintf(stderr, "  -b <symbol>     sets breakpoint at symbol\n");
        fprintf(stderr, "  -r              start in repl mode\n");
        return -1;
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

    if (mode == MODE_REPL) {
        suspend_ncurses();
    }

    //for (auto c: string("[ 255\r")) {
        //l_sim2dcpu.push_back(c);
    //}

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
            if (mode == MODE_SIM) {
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
                    if (ret == UA_REPL) {
                        break;
                    }
                    print_screen();
                    if (ret == UA_QUIT) {
                        goto finish;
                    } else if (ret == UA_STEP) {
                        break;
                    }
                }
            } else { // MODE_REPL
                if (forth_waits_for_input()) {
                    char *line = readline(repl_prompt().c_str());
                    if (line) {
                        string s(line);
                        s += '\r';
                        for (auto c: s) {
                            l_sim2dcpu.push_back(c);
                        }
                        free(line);
                    } else {
                        mode = MODE_SIM;
                        resume_ncurses();
                    }
                } else if (kbhit()) {
                    mode = MODE_SIM;
                    resume_ncurses();
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
