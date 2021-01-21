.PHONY: all clean sim wave

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I../verilog -I/usr/share/verilator/include -I../include

VFLAGS = -CFLAGS -std=c++11 -Wall -trace -cc --exe $(INCDIR) --Mdir $(VERILATOR_OUTPUTDIR)
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CFLAGS=-Wall -std=c++11

all: dcpu

verilator: dcpusim.cpp ../verilog/dcpu.v
	verilator $(VFLAGS) ../verilog/dcpu.v dcpusim.cpp

dcpu: verilator
	make -C $(VERILATOR_OUTPUTDIR) -j -f Vdcpu.mk

sim: dcpu
	$(VERILATOR_OUTPUTDIR)/Vdcpu -d -t

wave: sim
	gtkwave dcpu.gtkw &

clean:
	rm -f trace.vcd
	rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)
