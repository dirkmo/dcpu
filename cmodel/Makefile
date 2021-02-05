.PHONY: all clean

CFLAGS=-Wall -g -Wno-unused-function -Wfatal-errors
INC=

SRCS=$(wildcard *.c)
OBJS=$(SRCS:.c=.o)

BIN=sim
TEST=test

$(BIN): dcpu.o sim.o
	gcc $^ -o $(BIN)

%.o: %.c
	gcc $(CFLAGS) $(INC) -c $< -o $@

clean:
	rm -f *.o $(BIN) $(TEST)

$(TEST): dcpu.o tests.o
	gcc $^ -o $(TEST)
