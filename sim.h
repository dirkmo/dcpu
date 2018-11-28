#ifndef __SIM_H
#define __SIM_H

#include <algorithm>
#include <sstream>
#include <vector>
#include <set>
#include <cstdint>
#include <cstdio>
#include <cassert>

#include "Vtop.h"
#include "verilated.h"
#include "testbench.h"


class sim : public TESTBENCH<Vtop> {
public:

    sim() {
    }

    uint16_t getPC() const { return m_core->top__DOT__cpu0__DOT__pc; }

    uint16_t getMem(uint16_t addr) const {
        return m_core->top__DOT__blkmem0__DOT__mem[addr];
    }

    void setMem(uint16_t addr, uint16_t dat ) {
        m_core->top__DOT__blkmem0__DOT__mem[addr] = dat;
    }

    uint16_t getIR() const { return m_core->top__DOT__cpu0__DOT__ir; }

};

#endif
