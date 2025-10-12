CC=gcc
CFLAGS=$(shell cat compile_flags.txt)

test: src/test.c
	$(CC) -o test $(CFLAGS) src/test.c -limgz -lz -lm
	./test
	rm test
