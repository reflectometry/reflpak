OS = $(shell uname -s)
ifeq ($(OS), IRIX64) 
  DEFS=-DNEED_BASENAME
  LDFLAGS=-L/usr/freeware/lib32
endif
CFLAGS=-O3
LIBS=-lz -lm
all: reflbin

reflbin: reflbin.c
	$(CC) $(CFLAGS) $(DEFS) reflbin.c -o reflbin $(LDFLAGS) $(LIBS)

