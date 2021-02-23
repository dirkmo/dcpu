ASMFILE=test2.asm
HEXFILE=$(ASMFILE:.asm=.hex)
all: asm sim
	../nimmodel/sim $(HEXFILE)

asm: $(ASMFILE)
	../dasm/dasm.py $(ASMFILE) $(HEXFILE)

sim:
	cd ../nimmodel && nim c --threads:on sim.nim
