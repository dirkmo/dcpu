.PHONY: all sim-regfile sim-fetcher fetcher

all: regfile fetcher

regfile:
	verilator -Wall -trace -cc regfile.v --exe --Mdir regfile regfiletest.cpp
	cd regfile/ && make -j4 -f Vregfile.mk

fetcher:
	verilator -Wall -trace -cc fetcher.v --exe --Mdir fetcher fetchertest.cpp
	cd fetcher/ && make -j4 -f Vfetcher.mk
	
sim-regfile: regfile
	regfile/Vregisterfile

sim-fetcher: fetcher
	fetcher/Vfetcher

wave:
	gtkwave trace.vcd &

clean:
	rm -rf regfile/ fetcher/
