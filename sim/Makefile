.PHONY: all clean sim wave

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

PWD=$(shell pwd)
INCDIR=-I$(VERILATOR_OUTPUTDIR) -I/usr/share/verilator/include -I$(PWD)/../include

VSRCS=../verilog/top.v ../verilog/syscon.v ../verilog/dcpu.v ../verilog/blkmem.v

VFLAGS = -CFLAGS "-std=c++11 $(INCDIR)" -Wall -trace -cc --exe --Mdir $(VERILATOR_OUTPUTDIR) -y ../verilog
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CFLAGS=-Wall -std=c++11

CPPFILES=
OBJFILES=$(CPPFILES:.cpp=.o)

all: dcpusim

.cpp.o:
	g++ $(CFLAGS) $(INCDIR) -c $< -o $@

verilator: $(VSRCS) sim.cpp
	verilator $(VFLAGS) top.v sim.cpp


dcpusim: verilator $(OBJFILES)
	make -C $(VERILATOR_OUTPUTDIR) -j4 -f Vtop.mk

sim: dcpusim
	$(VERILATOR_OUTPUTDIR)/Vtop -d -t

wave: sim
	gtkwave trace.vcd &

clean:
	rm -f $(OBJFILES)
	-rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)
	rm -f trace.vcd
