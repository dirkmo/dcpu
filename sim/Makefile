.PHONY: all clean sim wave iverilog

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd

DEFINES=+define+SIM=1

#VFLAGS = -O0 --cc -CFLAGS "$(CXXFLAGS)" -LDFLAGS "$(LDFLAGS)" --trace $(INCDIR) --exe --Mdir $(VERILATOR_OUTPUTDIR) $(DEFINES)
VFLAGS = --cc -O0 -CFLAGS "$(CXXFLAGS)" -LDFLAGS "$(LDFLAGS)" --trace $(INCDIR) --exe --Mdir $(VERILATOR_OUTPUTDIR) $(DEFINES)
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CXXFLAGS=-g -Wall -O0  # -DVL_USER_STOP
LDFLAGS=-lncurses

CPPSRC=sim.cpp dcpu.cpp
VERILOGSRC=../rtl/dcpu.v

all: top

verilator: $(VERILOGSRC) $(CPPSRC)
	verilator $(VFLAGS) $(VERILOGSRC) $(CPPSRC)

top: verilator
	make OPT_FAST="" -C $(VERILATOR_OUTPUTDIR) -j -f Vdcpu.mk
	../dasm/dasm.py -i forth.asm -o forth

sim: top
	$(VERILATOR_OUTPUTDIR)/Vdcpu forth.bin forth.sim

wave: sim
	gtkwave sim.gtkw &

iverilog:
	iverilog -Wall $(VERILOGSRC)

yosys:
	yosys -Wall -p "synth_ice40 -dsp" $(VERILOGSRC)

clean:
	rm -f trace.vcd a.out
	rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)
	rm -f a.out
