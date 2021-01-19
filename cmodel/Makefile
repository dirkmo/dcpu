.PHONY: all clean

CFLAGS=-Wall -g -Wno-unused-function -Wfatal-errors
INC=

SRCS=$(wildcard *.c)
OBJS=$(SRCS:.c=.o)

BIN=dcpu

all: $(OBJS)
	gcc $(OBJS) -o $(BIN)

%.o: %.c
	gcc $(CFLAGS) $(INC) -c $< -o $@

clean:
	rm -f $(OBJS) $(BIN)
