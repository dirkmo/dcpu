.PHONY: all clean sim wave

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I../verilog -I../verilog/uart -I/usr/share/verilator/include -I../include

VFLAGS = -CFLAGS -std=c++11 -Wall -trace -cc --exe $(INCDIR) --Mdir $(VERILATOR_OUTPUTDIR)
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CFLAGS=-Wall -std=c++11

all: regfile

verilator: regfile
	verilator $(VFLAGS) ../regfile.v regfile.cpp


regfile: verilator
	make -C $(VERILATOR_OUTPUTDIR) -j4 -f Vregfile.mk

sim: regfile
	$(VERILATOR_OUTPUTDIR)/Vtop -d -t

wave: sim
	gtkwave trace.vcd &

clean:
	rm $(OBJFILES)
	rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)
