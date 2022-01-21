.PHONY: all clean sim wave iverilog

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I/usr/share/verilator/include

DEFINES=+define+SIM=1

VFLAGS = -O0 --cc -CFLAGS "$(CXXFLAGS)" --trace --exe $(INCDIR) --Mdir $(VERILATOR_OUTPUTDIR) $(DEFINES)
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CXXFLAGS=-g -Wall -O0

CPPSRC=sim.cpp
VERILOGSRC=top.v ../rtl/dcpu.v uartmaster/fifo.v uartmaster/UartProtocol.v uartmaster/UartMasterSlave.v uartmaster/uart_tx.v uartmaster/uart_rx.v

all: top

verilator: $(CPPSRC) $(VERILOGSRC)
	verilator $(VFLAGS) $(VERILOGSRC) $(CPPSRC)

top: verilator
	make OPT_FAST="" -C $(VERILATOR_OUTPUTDIR) -j -f Vtop.mk

sim: top
	$(VERILATOR_OUTPUTDIR)/Vtop -t

wave: sim
	gtkwave sim.gtkw &

iverilog:
	iverilog -Wall $(VERILOGSRC)

clean:
	rm -f trace.vcd a.out
	rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)
	rm -f a.out
