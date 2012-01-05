all: server.oct

server.oct: server.cc listencanfork.c stringmatch.c
	mkoctfile server.cc listencanfork.c stringmatch.c
clean:
	-rm *.oct *.o *~
