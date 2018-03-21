.PHONY: all sim-regfile sim-fetcher fetcher

UNAME := $(shell uname -s)

VFLAGS = -Wall -trace -cc --exe --Mdir $@
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

all: regfile fetcher

regfile:
	verilator $(VFLAGS) regfile.v regfiletest.cpp
	cd regfile/ && make -j4 -f Vregfile.mk

fetcher:
	verilator $(VFLAGS) fetcher.v fetchertest.cpp
	cd fetcher/ && make -j4 -f Vfetcher.mk
	
sim-regfile: regfile
	regfile/Vregisterfile

sim-fetcher: fetcher
	fetcher/Vfetcher

wave: sim-fetcher
	$(GTKWAVE) trace.vcd &

clean:
	rm -rf regfile/ fetcher/
