MKOCTFILE ?= mkoctfile

all: server.oct

server.oct: server.cc
	$(MKOCTFILE) server.cc
clean:
	-rm *.oct *.o *~
