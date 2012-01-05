MKOCTFILE ?= mkoctfile

all: server.oct

server.oct: server.cc listencanfork.c stringmatch.c
	$(MKOCTFILE) server.cc listencanfork.c stringmatch.c
clean:
	-rm *.oct *.o *~
