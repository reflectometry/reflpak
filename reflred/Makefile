OS = $(shell uname -s)
CFLAGS=-O3  -Wall
ifeq ($(OS), IRIX64) 
  DEFS=-DNEED_BASENAME
  LDFLAGS=-L/usr/freeware/lib32
  CFLAGS=-O2
endif
LIBS=-lz -lm
all: reflbin

reflbin: reflbin.c
	$(CC) $(CFLAGS) $(DEFS) reflbin.c -o reflbin $(LDFLAGS) $(LIBS)

clean: ; rm reflbin
