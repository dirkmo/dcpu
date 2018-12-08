.PHONY: all clean sim wave

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I/usr/share/verilator/include

VFLAGS = -CFLAGS -std=c++11 -Wall -trace -cc --exe $(INCDIR) --Mdir $(VERILATOR_OUTPUTDIR)
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

verilator: top.v sim.cpp
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
